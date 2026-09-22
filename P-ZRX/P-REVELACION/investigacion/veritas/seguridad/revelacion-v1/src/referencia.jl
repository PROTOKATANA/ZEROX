# ─────────────────────────────────────────────────────────────────────────────
# referencia.jl — oráculo exacto por slot y formas cerradas EXTERNAS
#
# El oráculo NO usa la recursión por eventos del kernel: recorre la cadena de PoT
# **slot a slot** y guarda el instante en que cada frontera completa cada slot.
# Es la fuente de verdad en instancias pequeñas. Con `Rational{BigInt}` el
# resultado es exacto, así que la comparación kernel-vs-oráculo es una igualdad
# comprobable, no una tolerancia.
#
# Las formas cerradas de este fichero son **transcripciones de fuentes externas**
# (9c §E.1, ronda 7, ronda 10a, SEM-v1), no resultados de este instrumento: se usan
# como control. Cada una lleva su cita.
# ─────────────────────────────────────────────────────────────────────────────
"""
Oráculo **independiente**: simula la cadena de PoT **slot a slot**.

`Tt[x+1]` = instante en que la frontera del atacante completa el slot `x` (posición `x`);
`Ht[x+1]` = lo mismo para la frontera honesta. Las posiciones `0…lead_h` ya están computadas en
`t = 0`, porque la frontera arranca alineada con la del honesto (ventaja nula). En un slot de
barrera `t_j` hay que esperar `entropía_j`:

```text
Tt[t_j + 1] = max( Tt[t_j] , e_j ) + 1/ρ      (cruce con coste)   ·  sin coste si cfg.cruce=false
Tt[x + 1]   = Tt[x] + 1/ρ                     en otro caso
```

`V` es lineal entre puntos de ruptura consecutivos de las dos fronteras, y todo punto de ruptura es
una completación o el tope `t_j − 1` de una barrera (que ya está en la tabla como completación del
slot `t_j − 1`). Por eso el máximo y el mínimo exactos se obtienen evaluando `V` en la unión de
`{Tt[x]} ∪ {Ht[x]}`. Devuelve `(vmax, vmin, Xmax, n_stall_h)`, en aritmética exacta del tipo `T`.
"""
function oraculo_por_slot(
    cfg::Config{T}, off::Vector{T}, propia::Vector{Bool}, rho::T, J::Int,
) where {T<:Real}
    ir = one(T) / rho
    uno = one(T)
    x0 = Int(cfg.lead_h)              # posiciones ya computadas en t = 0
    barr = Vector{T}(undef, J)
    for j in 1:J
        barr[j] = T(j) * cfg.I + off[j] + cfg.L
    end
    Xmax = Int(ceil(Float64(barr[J]))) + 2
    Tt = fill(zero(T), Xmax + 1)
    Ht = fill(zero(T), Xmax + 1)
    esbA = falses(Xmax + 1)
    esbH = falses(Xmax + 1)
    nst = 0
    jb = 1
    eventos = Vector{T}(undef, 2 * (Xmax + 1))
    nev = 0
    for x in (x0 + 1):Xmax
        while jb <= J && barr[jb] < T(x)
            jb += 1
        end
        esb = jb <= J && barr[jb] == T(x)
        if esb
            j = jb
            esbA[x+1] = true
            esbH[x+1] = true
            sj = T(j) * cfg.I + off[j]
            if propia[j]
                t_pro = Tt[Int(sj + cfg.D) + 1]
            else
                t_hon = Tt[Int(sj)+1]
                t_hon = t_hon > sj ? t_hon : sj
            end
            e = propia[j] ? t_pro : t_hon
            if cfg.con_h
                e += cfg.Lrev * ir
            end
            if cfg.espera && !propia[j]
                e += cfg.W_dec
            end
            Tx = Tt[x] > e ? Tt[x] : e
            if cfg.cruce
                Tx += ir
            end
            base_h = sj > T(j) * cfg.I + cfg.W_dec ? sj : T(j) * cfg.I + cfg.W_dec
            eh = cfg.con_h ? base_h + cfg.Lrev : base_h
            Hx = Ht[x] > eh ? Ht[x] : eh
            Hx += uno
            if eh > Ht[x]
                nst += 1
            end
            jb += 1
        else
            Tx = Tt[x] + ir
            Hx = Ht[x] + uno
        end
        Tt[x+1] = Tx
        Ht[x+1] = Hx
    end
    # horizonte comparable con el del kernel por eventos: hasta la última barrera
    t_fin = Tt[Int(barr[J])+1]
    for x in 0:Xmax
        Tt[x+1] > t_fin && break
        nev += 1; eventos[nev] = Tt[x+1]
        if Ht[x+1] <= t_fin
            nev += 1; eventos[nev] = Ht[x+1]
        end
    end
    vmax = zero(T); vmin = zero(T)
    visto = false
    for k in 1:nev
        t = eventos[k]
        va = _pos_en(t, Tt, esbA, ir, cfg.cruce, T(x0))
        vh = _pos_en(t, Ht, esbH, uno, true, T(x0))
        v = va - vh
        if !visto
            vmax = v; vmin = v; visto = true
        end
        if v > vmax
            vmax = v
        end
        if v < vmin
            vmin = v
        end
    end
    return (vmax, vmin, Xmax, nst)
end

"""
Posición de una frontera en el instante `t`, dada su tabla de tiempos por slot y la marca de qué
slots son barrera.

`ts[x+1]` es el instante en que se completa el slot `x`; las posiciones `0…lead` están completas en
`t = 0`. En el tramo `[ts[i], ts[i+1]]` la posición es `i−1` **estancada** si el slot `i` es una
barrera cuya entropía aún no había llegado (`ts[i+1]` supera la llegada libre); en otro caso avanza
a razón `1/ir`.
"""
function _pos_en(t::T, ts::Vector{T}, esb::BitVector, ir::T, cruce::Bool, lead::T) where {T<:Real}
    n = length(ts) - 1
    i = searchsortedlast(ts, t)
    i <= 0 && return lead
    i >= n + 1 && return T(n) + (t - ts[n+1]) * (T(n) - T(n-1)) / (ts[n+1] - ts[n])
    x = i - 1
    libre = cruce ? ts[i] + ir : ts[i]
    if esb[i+1] && ts[i+1] > libre
        # barrera con espera: estancado en el tope `x` hasta que llega la entropía; después
        # queda el tramo de cruce (coste `ir` si `cruce`), no todo el intervalo estancado
        if cruce
            te = ts[i+1] - ir
            t <= te && return T(x)
            return T(x) + (t - te) / ir
        end
        return T(x)
    end
    return T(x) + (t - ts[i]) / ir
end

"""
`A_core` histórico de SEM-v1 / `R-FIN-14(a-g)`, **sin `D`**:
`max(0, (L − 1 − W_dec) + I(1 − 1/ρ))`, cero para `ρ ≤ 1`.

Fuente: `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md:86` y
`P-ZRX/P-ADELANTO/investigacion/veritas/seguridad/adelanto-v1/src/modelo.jl:148-151`.
El `−1` es la convención de frontera discreta `t_{j+1} − 1`, no un parámetro de consenso.
"""
function a_core_semv1(rho::T, L::T, I::T, W_dec::T) where {T<:Real}
    rho <= one(T) && return zero(T)
    return max(zero(T), (L - one(T) - W_dec) + I * (one(T) - one(T) / rho))
end

"""
Ventaja de la **ronda 7** en la convención del instrumento histórico
(`research/scripts/d8-ronda10a/r10a_lib.py:248-262`): `L + I(1 − 1/ρ)` sin (h) y
`(Lrev + I)(1 − 1/ρ)` con (h). Es el mismo objeto que `vent_pico` de ese instrumento.
"""
function ventaja_barrera_10a(rho::T, L::T, I::T, con_h::Bool, Lrev::T) where {T<:Real}
    if rho <= zero(T)
        return zero(T)
    end
    tope = con_h ? L - Lrev / rho : L
    return max(zero(T), tope) + I * (one(T) - one(T) / rho)
end

"""
Umbral de *steering* de la ronda 10a, forma cerrada: `ρ* = (Lrev + I)/(I + W_dec)`
(`research/scripts/d8-ronda10a/informe.md:270-276`, condiciones (1)-(3)).
"""
rho_estrella_10a(L::T, I::T, W_dec::T, Lrev::T = L) where {T<:Real} =
    (Lrev + I) / (I + W_dec)

"""
La forma con (h) que usa ADL-v1.0 como si fuera ventana:
`A_con_h(ρ) = max(0, (I + W_dec − 1) − (L + I)/ρ)`
(`P-ZRX/P-ADELANTO/investigacion/veritas/seguridad/adelanto-v1/src/modelo.jl:292-301`).
Es la **holgura de la carrera de steering**, no la ventana de PoT.
"""
function rho_estrella_continua(L::T, I::T, W_dec::T) where {T<:Real}
    return (L + I) / (I + W_dec)
end

"""
Número mínimo de anclas propias consecutivas para que la ventaja alcance el umbral de steering
`L − W_dec + off` (ronda 10a §B.1.3, `r10a_lib.py:265-279`):

```text
ventaja tras r anclas propias = (L + (r+1)·I)(1 − 1/ρ)
n* = max(1, ⌈((L − W_dec + off)·ρ/(ρ−1) − L)/I⌉)
```
"""
function n_rachas(L::T, I::T, rho::T, W_dec::T, off::T = zero(T)) where {T<:Real}
    rho <= one(T) && return typemax(Int)
    x = ((L - W_dec + off) * rho / (rho - one(T)) - L) / I
    return max(1, Int(ceil(Float64(x))))
end

"Tasa de épocas con steering por rachas: `α^(n*−1)` (ronda 10a §B.1.3)."
function tasa_rachas(L::T, I::T, rho::T, alpha::T, W_dec::T, off::T = zero(T)) where {T<:Real}
    alpha <= zero(T) && return zero(T)
    n = n_rachas(L, I, rho, W_dec, off)
    n == typemax(Int) && return zero(T)
    return alpha^(n - 1)
end

# ── coste (entradas medidas, no resultados) ──────────────────────────────────

"""
Líneas de AES simultáneas del timekeeper: `q + 1 = ⌈L/I⌉ + 1`
(ronda 10a §B.1.5 y `r10a_lib.py`; ADL `modelo.jl:377-384`).
"""
lineas_timekeeper(L::T, I::T) where {T<:Real} = ceil(Int, Float64(L / I)) + 1

"""
Núcleos continuos por nodo del PoT con (h): `c_v·(1 + L/I)` con `c_v = 0.0961 s/slot`
**medido** en `research/dag-poas-ancla-de-orden.md:342` (Ryzen 9 9950X3D, `verify` 96,1 ms/slot).
"""
function nucleos_nodo(L::T, I::T, c_v::T = T(0.0961)) where {T<:Real}
    return c_v * (one(T) + L / I)
end

"Núcleos continuos de la cadena principal sola (`c_v` por slot)."
nucleos_cadena(c_v::T = 0.0961) where {T<:Real} = c_v

"""
`I*` de la calibración (h.6): `I ≤ (L − ρ_max·W_dec)/(ρ_max − 1)`
(`research/scripts/d8-ronda10a/informe.md:226-227`).
"""
function I_estrella(L::T, rho_max::T, W_dec::T) where {T<:Real}
    rho_max <= one(T) && return typemax(T)
    return (L - rho_max * W_dec) / (rho_max - one(T))
end

"""
Restricciones inferiores de `I`: `I ≥ ρ_max·W_dec` (`R-FIN-14(f)`,
`research/dag-poas-ancla-de-orden.md:277-279`) e `I > S_max` (`C-FLU-09`, `SPEC.md:1630-1632`).
"""
function I_minima(rho_max::T, W_dec::T, S_max::T) where {T<:Real}
    return rho_max * W_dec > S_max + one(T) ? rho_max * W_dec : S_max + one(T)
end

"""
Segundos de CPU de verificación de PoT por época con el multiplicador `1 + L/I`, con
`verify = 96,1 ms/slot` y `prove = 1,561 s/slot` **medidos** en
`research/dag-poas-ancla-de-orden.md:342`.
"""
function coste_verificacion(L::T, I::T; verify::T = T(0.0961), prove::T = T(1.561)) where {T<:Real}
    return (verify * (L + I), prove * (L + I))
end

"Instantes de inyección por hora: `3600/I` con `I` en slots de 1 s nominales (`C-FLU-09`)."
instantes_por_hora(I::T) where {T<:Real} = 3600 / I
