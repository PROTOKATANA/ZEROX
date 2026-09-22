"""
AdelantoV1 — modelo del adelanto adversarial `A(ρ, L, I, W_dec, D, S_max)` con
`pot_output = salida(f, slot + D)` (D-2 = A), bajo las reglas vigentes del SPEC.

Unidades: **slots** (índice de PoT). Un slot nominal es un segundo en el perfil A″
(`research/dag-poas-ancla-de-orden.md:328-336`), pero el núcleo **no mezcla segundos y
slots**: todos los parámetros temporales entran en slots. `τ_nom` no aparece en ninguna
comparación (C-FLU-01, `SPEC.md:1522-1526`).

Reglas citadas, todas leídas en su fuente antes de codificar:

- `C-FLU-01` (`SPEC.md:1507-1543`): `L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`.
  `L` es una **definición**, no un parámetro libre.
- `C-POT-03` (`SPEC.md:1376-1390`): `reto(f,s) = blake3(blake3(salida(f,s)) ‖ LE64(s))`.
  El reto usa la salida **del propio slot**; `D` no entra.
- `C-POT-05` (`SPEC.md:1403-1426`): `pot_output(B) = salida(f, slot(B)+D)`; la justificación
  cubre `(slot(sp)+D, slot(B)+D]` con `d = slot(B) − slot(sp)` portadores.
- `C-FLU-07` (`SPEC.md:1612-1620`): `t_j = slot(I_j) + L`. `D` no entra.
- `R-FIN-14` (a)-(h) (`research/dag-poas-ancla-de-orden.md:258-296`).

Núcleo histórico (SEM-v1, `P-ZRX/P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/src/modelo.jl:90-103`),
que se reproduce **exactamente** como oráculo de regresión:

```text
A_core(ρ,L,I,W_dec) = max(0, (L − 1 − W_dec) + I·(1 − 1/ρ))   ρ > 1
A_core = 0                                                    ρ ≤ 1
```
"""

# ─────────────────────────────────────────────────────────────────────────────
# Constantes de procedencia medida (no son resultados: son entradas documentadas)
# ─────────────────────────────────────────────────────────────────────────────

"""
Coste de **verificar** un slot de PoT, en segundos de CPU, con la ruta
`verify_sequential_avx512f_vaes` de 8 checkpoints.

**Medido** en `research/dag-poas-ancla-de-orden.md:342` (2026-09-08, `cargo bench -p
subspace-proof-of-time`, clon `subspace` @ `f8842d0`, Ryzen 9 9950X3D): `verify` =
**96,1 ms/slot**. La misma fuente da `prove` = 1,561 s/slot, luego la asimetría
`prove/verify ≈ 16,2×`. Ninguno de los dos es un parámetro de consenso.
"""
const COSTE_VERIFY_SLOT_S = 0.0961

"""
Asimetría medida `prove/verify` del PoT (`1,561 s` frente a `96,1 ms`). Se usa como
presupuesto de recomputación, no como resultado de seguridad. Fuente:
`research/dag-poas-ancla-de-orden.md:342`.
"""
const ASIMETRIA_PROVE_VERIFY = 1.561 / 0.0961

# ─────────────────────────────────────────────────────────────────────────────
# Entradas y salidas
# ─────────────────────────────────────────────────────────────────────────────

"""
Entradas del modelo. `struct` inmutable, todos los campos concretos del mismo tipo `T`:
el kernel consume todos sus campos juntos y no hay mutación.

`F_slots`, `L_suelo`, `S_max`, `D`, `I_slots`, `W_dec`, `ρ_max` y `t_obs` entran **como
símbolos**: el encargo prohíbe fijar parámetros de consenso. `L_slots` **no** es un campo:
se deriva con `C-FLU-01`.

`t_obs` es el horizonte desde el génesis, en slots, al que se evalúan las magnitudes de
**transitorio** (el modelo histórico es estacionario y no lo incluye: SEM-v1
`src/modelo.jl:86-88`). Cerca de `ρ = 1` el adelanto **es** transitorio y sin declarar
`t_obs` no está definido.
"""
struct ParametrosAdelanto{T<:AbstractFloat}
    rho::T
    I_slots::T
    W_dec::T
    D::T
    S_max::T
    F_slots::T
    L_suelo::T
    t_obs::T
    rho_max::T
    c_v::T

    function ParametrosAdelanto(
        rho::T, I_slots::T, W_dec::T, D::T, S_max::T, F_slots::T, L_suelo::T,
        t_obs::T, rho_max::T, c_v::T,
    ) where {T<:AbstractFloat}
        rho > zero(T) || throw(ArgumentError("rho debe ser positivo"))
        I_slots > zero(T) || throw(ArgumentError("I_slots debe ser positivo"))
        W_dec >= zero(T) || throw(ArgumentError("W_dec no puede ser negativo"))
        D >= zero(T) || throw(ArgumentError("D no puede ser negativo"))
        S_max >= zero(T) || throw(ArgumentError("S_max no puede ser negativo"))
        F_slots >= zero(T) || throw(ArgumentError("F_slots no puede ser negativo"))
        L_suelo >= zero(T) || throw(ArgumentError("L_suelo no puede ser negativo"))
        t_obs > zero(T) || throw(ArgumentError("t_obs debe ser positivo"))
        rho_max > zero(T) || throw(ArgumentError("rho_max debe ser positivo"))
        c_v > zero(T) || throw(ArgumentError("c_v debe ser positivo"))
        return new{T}(
            rho, I_slots, W_dec, D, S_max, F_slots, L_suelo, t_obs, rho_max, c_v,
        )
    end
end

"""
Salida por fila. Todos los campos `isbits`; el barrido escribe una posición por fila
(`SoA`).
"""
struct ResultadoAdelanto{T<:AbstractFloat}
    L_slots::T
    manda_F::Bool        # true si L = F_slots (primer término de C-FLU-01)
    vivo::Bool           # D ≤ L − W_dec (viabilidad de autoría)
    A_nucleo::T          # A_core, núcleo histórico (D = 0); oráculo de regresión
    A_D::T               # PRIMARIO: generalización de A_core con D (D resta)
    A_frontera::T        # modelo de fronteras independiente, con D y horizonte t_obs
    A_frontera_inf::T    # límite estacionario del anterior (sin transitorio)
    A_con_h::T           # revelación retardada R-FIN-14(h)
    A_con_h_D::T         # (h) con D
    A_add::T             # CONTRAFACTUAL: reto derivado de pot_output (prohibido)
    A_sub::T             # CONTRAFACTUAL: hándicap D solo para el atacante
    rho_transitorio::T   # ρ a partir del cual manda la cota de flujo (no el transitorio)
    rho_estrella::T      # (L+I)/(I+W_dec−1): donde A_con_h se anula
    coste_relativo::T    # 1 + L/I  (multiplicador de verificación por nodo con (h))
    lineas_timekeeper::T # q + 1 = ⌈L/I⌉ + 1
    nucleos_nodo::T      # c_v · (1 + L/I)
    w_nucleo::UInt64
end

# ─────────────────────────────────────────────────────────────────────────────
# L derivada (C-FLU-01)
# ─────────────────────────────────────────────────────────────────────────────

"""
`L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)` — `C-FLU-01`,
`SPEC.md:1515`. Es una **definición**; el modelo la aplica y no acepta `L` libre.
"""
@inline function L_derivada(F_slots::T, L_suelo::T, S_max::T) where {T<:AbstractFloat}
    return max(F_slots, L_suelo, S_max + one(T))
end

# ─────────────────────────────────────────────────────────────────────────────
# 1 · Núcleo histórico — oráculo de regresión contra SEM-v1
# ─────────────────────────────────────────────────────────────────────────────

"""
`A_core` de SEM-v1 / `R-FIN-14(a-g)`. **No** lleva `D` y **no** deriva `L`: es el modelo
histórico tal cual, para la regresión exigida por el encargo §2(a).

El `−1` es la convención de frontera discreta `t_(j+1) − 1`, no un parámetro de consenso
(`P-ZRX/P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/INFORME.md:26-27`).
"""
@inline function adelanto_nucleo(rho::T, L_slots::T, I_slots::T, W_dec::T) where {T<:AbstractFloat}
    rho <= one(T) && return zero(T)
    return max(zero(T), (L_slots - one(T) - W_dec) + I_slots * (one(T) - inv(rho)))
end

"""Número entero conservador de retos futuros completos conocidos (`w` de SEM-v1)."""
@inline function desafios_nucleo(rho::T, L_slots::T, I_slots::T, W_dec::T) where {T<:AbstractFloat}
    a = adelanto_nucleo(rho, L_slots, I_slots, W_dec)
    (a <= zero(T) || a > T(typemax(UInt64))) && return UInt64(0)
    return UInt64(floor(a))
end

# ─────────────────────────────────────────────────────────────────────────────
# 2 · Generalización PRIMARIA con D — la lectura que se defiende
# ─────────────────────────────────────────────────────────────────────────────

"""
**Generalización primaria.** `D` **resta**:

```text
A_D(ρ,L,I,W_dec,D) = max(0, A_core(ρ,L,I,W_dec) − D)      en el régimen estacionario
```

Derivación (detallada en `PROGRESO.md` §2 y en `INFORME.md` §2). Sean las fronteras de
**slots firmables** en el instante de decisión `t`:

```text
Γ(t)      = horizonte de determinación del flujo = t + I + L − W_dec
frontera honesta   h(t) = mín( t ,  Γ(t) − D )      su timekeeper va D por delante
frontera atacante  a(t) = mín( ρ·t , Γ(t) − D )     su timekeeper va D + ρt
A(t) = a(t) − h(t)
```

`Γ(t) − D` aparece **idéntico** en las dos: la exigencia de conocer `salida(f, s+D)`
(`C-POT-05`) es un hándicap común, y por eso en el **transitorio** (donde manda `ρ·t`)
`D` **se cancela**. En el **estacionario** el honesto está limitado por su propio reloj
(`h = t`) y el atacante por el flujo (`a = Γ − D`), luego **`D` resta**. El modelo
histórico es estacionario por declaración propia (SEM-v1 `src/modelo.jl:86-88`), así que la
generalización en su misma moneda es `A_core − D`.

Que `D` **suma** exigiría derivar `reto(f,s)` de `pot_output = salida(f, s+D)`: lo prohíben
`C-POT-03` (`SPEC.md:1383-1386`) y `R-FIN-14(e)`
(`research/dag-poas-ancla-de-orden.md:272-275`). Ver `adelanto_add` (contrafactual).
"""
@inline function adelanto_D(
    rho::T, L_slots::T, I_slots::T, W_dec::T, D::T
) where {T<:AbstractFloat}
    return max(zero(T), adelanto_nucleo(rho, L_slots, I_slots, W_dec) - D)
end

# ─────────────────────────────────────────────────────────────────────────────
# 3 · Modelo de fronteras independiente (no copia la forma del histórico)
# ─────────────────────────────────────────────────────────────────────────────

"""
Horizonte de determinación del flujo en el instante `t`: hasta qué slot están
determinadas las inyecciones. La última época cuyo ancla puede cerrarse es la de umbral
`T_i ≈ t − W_dec`, y su inyección siguiente llega `I + L` slots después:

```text
Γ(t) = t + I_slots + L_slots − W_dec
```

Es la cota de conocimiento de `R-FIN-14` («`L + I − W_dec`»,
`research/scripts/d9-ronda9c/informe.md:255-259`) y la «cota de lookahead `L + I`» de la
ronda 7 (`research/dag-poas-ancla-de-orden.md:249-250`).
"""
@inline function horizonte_flujo(t::T, L_slots::T, I_slots::T, W_dec::T) where {T<:AbstractFloat}
    return t + I_slots + L_slots - W_dec
end

"""
**Modelo de fronteras independiente.** No usa `A_core`; se construye con la contabilidad
de eventos de las fronteras de slots firmables:

```text
A_frontera(ρ,·,D,t) = máx( 0, mín(ρ·t, Γ(t) − D) − mín(t, Γ(t) − D) )
```

Propiedades que el instrumento comprueba y que lo separan del histórico:

- `A_frontera(ρ=1) = 0` **exacto** (continuo en `ρ = 1`; no hay acantilado);
- es **constante en `ρ`** una vez que `ρ·t ≥ Γ(t) − D`, es decir para todo `ρ` por encima
  del umbral de transitorio `ρ_trans = (Γ − D)/t`;
- su límite estacionario (`t → ∞`) es `L + I − W_dec − D`.
"""
@inline function adelanto_frontera(
    rho::T, L_slots::T, I_slots::T, W_dec::T, D::T, t::T
) where {T<:AbstractFloat}
    flujo = horizonte_flujo(t, L_slots, I_slots, W_dec) - D   # máximo slot firmable por flujo
    pot_a = rho * t
    # Forma sin cancelación: `mín(ρt,flujo) − mín(t,flujo)` restando dos números casi
    # iguales pierde dígitos cuando `t ≫ A` (que es justo el régimen representativo).
    if flujo >= pot_a
        return (rho - one(T)) * t          # manda el reloj del atacante (transitorio)
    elseif flujo >= t
        return flujo - t                   # manda el flujo
    else
        return zero(T)                     # manda el reloj del honesto para los dos
    end
end

"""
Límite estacionario del modelo de fronteras: `A_frontera_inf = L + I − W_dec − D`. Es la
cota de conocimiento de la ronda 7 (`L + I`, `research/dag-poas-ancla-de-orden.md:249-250`)
`− W_dec − D`. **No depende de `ρ`**: por encima de `ρ_transitorio` el atacante ya está
limitado por el flujo, no por su reloj.
"""
@inline function adelanto_frontera_inf(
    L_slots::T, I_slots::T, W_dec::T, D::T
) where {T<:AbstractFloat}
    return max(zero(T), L_slots + I_slots - W_dec - D)
end

"""
Umbral de `ρ` a partir del cual manda la cota de flujo y no el transitorio:
`ρ_trans = (Γ(t) − D)/t = 1 + (I + L − W_dec − D)/t`. Para `ρ ≥ ρ_trans` el adelanto del
modelo de fronteras es `Γ − D − t`, **independiente de `ρ`**.
"""
@inline function rho_transitorio(
    L_slots::T, I_slots::T, W_dec::T, D::T, t::T
) where {T<:AbstractFloat}
    return (horizonte_flujo(t, L_slots, I_slots, W_dec) - D) / t
end

# ─────────────────────────────────────────────────────────────────────────────
# 4 · Revelación retardada R-FIN-14(h)
# ─────────────────────────────────────────────────────────────────────────────

"""
**Revelación retardada `R-FIN-14(h)`**, con la corrección de la ronda 10a. La cota de
conocimiento pasa de `L + I − W_dec` a `I`; la ventaja tras `r = 0` anclas propias es
`(L+I)(1 − 1/ρ)` (`research/scripts/d8-ronda10a/informe.md:311-314`, control C2, y
`research/dag-poas-ancla-de-orden.md:281-284`). Restando la ventaja necesaria `L − W_dec`
y la convención `−1`:

```text
A_con_h(ρ) = max(0, (I + W_dec − 1) − (L + I)/ρ)      ρ > 1
```

Se anula en `ρ* = (L+I)/(I+W_dec−1)`, que reproduce los `ρ*` publicados (9,24 con
`I=851, L=2h, W_dec=20`; 8,99 con `W_dec=45`; `research/scripts/d8-ronda10a/informe.md:103-111`
y `:16`). Su límite `ρ → ∞` es `I + W_dec − 1`: el residuo que (h) **no** cierra.
"""
@inline function adelanto_con_h(
    rho::T, L_slots::T, I_slots::T, W_dec::T
) where {T<:AbstractFloat}
    rho <= one(T) && return zero(T)
    return max(zero(T), (I_slots + W_dec - one(T)) - (L_slots + I_slots) / rho)
end

"""
`A_con_h` con `D`: `D` resta por el mismo argumento que en `adelanto_D`, y también aquí
el atacante está limitado por el flujo y el honesto por su reloj.
"""
@inline function adelanto_con_h_D(
    rho::T, L_slots::T, I_slots::T, W_dec::T, D::T
) where {T<:AbstractFloat}
    return max(zero(T), adelanto_con_h(rho, L_slots, I_slots, W_dec) - D)
end

# ─────────────────────────────────────────────────────────────────────────────
# 5 · Contrafactuales de diagnóstico (etiquetados, nunca resultados)
# ─────────────────────────────────────────────────────────────────────────────

"""
**Contrafactual L1 (prohibido):** el reto derivado de `pot_output = salida(f, s+D)`.
`C-POT-03` (`SPEC.md:1383-1386`) y `R-FIN-14(e)` lo prohíben expresamente. Se implementa
solo para **medir la región** que produciría y cuantificar el valor de la prohibición.
"""
@inline function adelanto_add(
    rho::T, L_slots::T, I_slots::T, W_dec::T, D::T
) where {T<:AbstractFloat}
    return adelanto_nucleo(rho, L_slots, I_slots, W_dec) + D
end

"""
**Contrafactual L2 (inconsistente):** el hándicap `D` gravando solo al atacante, con la
frontera honesta sin desplazar. No corresponde a ninguna lectura de las reglas: el
productor honesto también necesita `salida(f, s+D)` (`C-POT-05`). Se implementa para
medir la región.
"""
@inline function adelanto_sub(
    rho::T, L_slots::T, I_slots::T, W_dec::T, D::T
) where {T<:AbstractFloat}
    return max(zero(T), adelanto_nucleo(rho, L_slots, I_slots, W_dec) - D)
end

# ─────────────────────────────────────────────────────────────────────────────
# 6 · Umbrales, coste y viabilidad
# ─────────────────────────────────────────────────────────────────────────────

"""
`ρ*` con la convención discreta del núcleo (`−1`): `(L+I)/(I+W_dec−1)`. Es el `ρ` donde
`A_con_h` se anula. Símbolo: no se fija.
"""
@inline function rho_estrella(L_slots::T, I_slots::T, W_dec::T) where {T<:AbstractFloat}
    den = I_slots + W_dec - one(T)
    den > zero(T) || return T(Inf)
    return (L_slots + I_slots) / den
end

"""
`ρ*` en la forma **continua** del histórico, `(L+I)/(I+W_dec)`. Es la que invierte
`R-FIN-14(h.6)` (`I* = (L − ρ_max·W_dec)/(ρ_max − 1)`) de forma **exacta**; las dos formas
difieren en la convención discreta de un slot. Se publican las dos y no se mezclan.
"""
@inline function rho_estrella_continua(L_slots::T, I_slots::T, W_dec::T) where {T<:AbstractFloat}
    den = I_slots + W_dec
    den > zero(T) || return T(Inf)
    return (L_slots + I_slots) / den
end

"""
`I` que iguala `ρ*` a un `ρ_max` admitido: `I* = (L − ρ_max·W_dec)/(ρ_max − 1)` —
`R-FIN-14(h.6)`, `research/scripts/d8-ronda10a/informe.md:226-227`. Devuelve `Inf` si
`ρ_max ≤ 1`.
"""
@inline function I_estrella(L_slots::T, rho_max::T, W_dec::T) where {T<:AbstractFloat}
    rho_max <= one(T) && return T(Inf)
    return (L_slots - rho_max * W_dec) / (rho_max - one(T))
end

"""`I` mínima de `R-FIN-14(f)`: `I ≥ ρ_max·W_dec` (con `n_eval = ρ·W_dec`)."""
@inline function I_minima_f(rho_max::T, W_dec::T) where {T<:AbstractFloat}
    return rho_max * W_dec
end

"""Líneas de AES simultáneas del timekeeper con (h): `q + 1 = ⌈L/I⌉ + 1`."""
@inline function lineas_timekeeper(L_slots::T, I_slots::T) where {T<:AbstractFloat}
    return ceil(L_slots / I_slots) + one(T)
end

"""
Multiplicador de verificación por nodo con (h): `1 + L/I` —
`research/scripts/d8-ronda10a/informe.md:745-755`. Es el cociente protección/coste:
`ρ* = (1 + L/I)·I/(I + W_dec − 1)`.
"""
@inline function coste_relativo(L_slots::T, I_slots::T) where {T<:AbstractFloat}
    return one(T) + L_slots / I_slots
end

"""
Núcleos continuos por nodo con (h): `nucleos_nodo = c_v · (1 + L/I)`, con `c_v` el coste
**medido** de `verify` por slot (`0,0961 s`, `research/dag-poas-ancla-de-orden.md:342`).
No es un supuesto: es una entrada con procedencia, y entra como argumento.
"""
@inline function nucleos_nodo(L_slots::T, I_slots::T, c_v::T) where {T<:AbstractFloat}
    return c_v * (one(T) + L_slots / I_slots)
end

"""
Viabilidad de autoría: `D ≤ L − W_dec`. Si `D ≥ L_slots` el bloque del slot `s`
necesitaría un ancla **futura** y ningún bloque avanzaría. No es un régimen de seguridad:
es un dominio donde el diseño no produce bloques.
"""
@inline function vivo(L_slots::T, W_dec::T, D::T) where {T<:AbstractFloat}
    return D <= L_slots - W_dec
end

# ─────────────────────────────────────────────────────────────────────────────
# 7 · Núcleo rápido — una fila
# ─────────────────────────────────────────────────────────────────────────────

"""
Evalúa una fila completa. Tipoestable, sin asignaciones, sin globals, sin `@fastmath` y
sin `Any`. No usa `@inbounds` porque no indexa.
"""
@inline function evaluar_fila(p::ParametrosAdelanto{T}) where {T<:AbstractFloat}
    L = L_derivada(p.F_slots, p.L_suelo, p.S_max)
    A_nuc = adelanto_nucleo(p.rho, L, p.I_slots, p.W_dec)
    A_d = adelanto_D(p.rho, L, p.I_slots, p.W_dec, p.D)
    A_fr = adelanto_frontera(p.rho, L, p.I_slots, p.W_dec, p.D, p.t_obs)
    A_fr_inf = adelanto_frontera_inf(L, p.I_slots, p.W_dec, p.D)
    A_h = adelanto_con_h(p.rho, L, p.I_slots, p.W_dec)
    A_h_d = adelanto_con_h_D(p.rho, L, p.I_slots, p.W_dec, p.D)
    A_add = adelanto_add(p.rho, L, p.I_slots, p.W_dec, p.D)
    A_sub = adelanto_sub(p.rho, L, p.I_slots, p.W_dec, p.D)
    rt = rho_transitorio(L, p.I_slots, p.W_dec, p.D, p.t_obs)
    re = rho_estrella(L, p.I_slots, p.W_dec)
    cr = coste_relativo(L, p.I_slots)
    li = lineas_timekeeper(L, p.I_slots)
    nn = nucleos_nodo(L, p.I_slots, p.c_v)
    w = desafios_nucleo(p.rho, L, p.I_slots, p.W_dec)
    v = vivo(L, p.W_dec, p.D)
    manda_f = L == p.F_slots
    return ResultadoAdelanto{T}(
        L, manda_f, v, A_nuc, A_d, A_fr, A_fr_inf, A_h, A_h_d, A_add, A_sub, rt, re,
        cr, li, nn, w,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# 8 · Fase 3 — cotas para las tres herramientas
# ─────────────────────────────────────────────────────────────────────────────

"""
`sup A` sobre la región admitida de `ρ`, **sin** revelación retardada. El atacante elige
la mejor lectura de las implementadas: se toma el máximo de `A_frontera_inf` (que no
depende de `ρ` por encima del transitorio) y de `A_D`. En unidades de slots: es la cota
inferior que la edad `M` de `P-SEMBRADOR` (A1+C1) tiene que superar.
"""
@inline function sup_A_sin_h(
    rho_max::T, L_slots::T, I_slots::T, W_dec::T, D::T, t::T
) where {T<:AbstractFloat}
    a_hist = adelanto_D(rho_max, L_slots, I_slots, W_dec, D)
    a_fr = adelanto_frontera(rho_max, L_slots, I_slots, W_dec, D, t)
    return max(a_hist, a_fr)
end

"""`sup A` con revelación retardada `(h)` sobre `[1, ρ_max]`."""
@inline function sup_A_con_h(
    rho_max::T, L_slots::T, I_slots::T, W_dec::T, D::T
) where {T<:AbstractFloat}
    return max(adelanto_con_h_D(rho_max, L_slots, I_slots, W_dec, D), zero(T))
end

"""
Cota inferior del tiempo de sellado adversarial para que un sellado secuencial sirva: el
candidato elegido tras conocer el reto no llega a tiempo si `T_seal,adv > sup A`. Se
devuelve en slots; el atacante puede acelerar el sellado, así que el número que se publica
es `sup A` y la comparación con su hardware queda como medición pendiente.
"""
@inline function cota_sellado(
    rho_max::T, L_slots::T, I_slots::T, W_dec::T, D::T, t::T
) where {T<:AbstractFloat}
    return sup_A_sin_h(rho_max, L_slots, I_slots, W_dec, D, t)
end
