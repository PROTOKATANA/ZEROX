"""
Oráculos de `AdelantoV1`. Tres piezas **independientes** del kernel rápido:

1. `referencia_bigfloat` — evaluación directa de las formas cerradas con 256 bits.
2. `referencia_exacta` — `Rational{BigInt}` para `ρ*`, la viabilidad y los umbrales, sin
   redondeo: criterios de decisión discretos no se deciden en `Float64` (LINEO §5.3).
3. `simular_fronteras` — **Sim-v1**, contabilidad de eventos explícita. No usa ninguna de
   las formas cerradas: construye la lista de épocas e inyecciones, deriva el horizonte de
   determinación del flujo `Γ(t)` de esa lista y calcula las fronteras de slots firmables
   con las dos restricciones (`PoT ≥ s + D` y `flujo determinado hasta s + D`). Es el
   oráculo contra el que se mide `adelanto_frontera`.
"""

# ─────────────────────────────────────────────────────────────────────────────
# 1 · BigFloat
# ─────────────────────────────────────────────────────────────────────────────

"""
Formas cerradas en `BigFloat` con precisión explícita. Es el modo riguroso barato
(LINEO §5.3): no decide nada discreto, solo da el valor real de las funciones.
"""
function referencia_bigfloat(p::ParametrosAdelanto; precision::Int = 256)
    precision >= 128 || throw(ArgumentError("la referencia exige al menos 128 bits"))
    return setprecision(BigFloat, precision) do
        rho = BigFloat(p.rho)
        I = BigFloat(p.I_slots)
        W = BigFloat(p.W_dec)
        D = BigFloat(p.D)
        S = BigFloat(p.S_max)
        F = BigFloat(p.F_slots)
        Ls = BigFloat(p.L_suelo)
        t = BigFloat(p.t_obs)

        L = max(F, Ls, S + 1)

        A_nuc = rho <= 1 ? BigFloat(0) :
            max(BigFloat(0), (L - 1 - W) + I * (1 - inv(rho)))
        A_d = max(BigFloat(0), A_nuc - D)

        Gamma = t + I + L - W
        GD = Gamma - D
        A_fr = max(BigFloat(0), min(rho * t, GD) - min(t, GD))
        A_fr_inf = max(BigFloat(0), L + I - W - D)
        A_h = rho <= 1 ? BigFloat(0) :
            max(BigFloat(0), (I + W - 1) - (L + I) / rho)
        A_h_d = max(BigFloat(0), A_h - D)

        re = I + W - 1 > 0 ? (L + I) / (I + W - 1) : BigFloat(Inf)
        cargo = 1 + L / I
        lineas = ceil(L / I) + 1
        nucleos = BigFloat(p.c_v) * (1 + L / I)
        rt = (Gamma - D) / t
        vivo_bf = D <= L - W

        return (
            L_slots = L,
            A_nucleo = A_nuc,
            A_D = A_d,
            A_frontera = A_fr,
            A_frontera_inf = A_fr_inf,
            A_con_h = A_h,
            A_con_h_D = A_h_d,
            rho_estrella = re,
            coste_relativo = cargo,
            lineas_timekeeper = lineas,
            nucleos_nodo = nucleos,
            rho_transitorio = rt,
            vivo = vivo_bf,
            horizonte_flujo = Gamma,
        )
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 2 · Exacto (Rational{BigInt})
# ─────────────────────────────────────────────────────────────────────────────

"""
Evaluación **exacta** de los umbrales y predicados discretos. `ρ` entra como
`Rational{BigInt}` (`rho_num // rho_den`), y los slots como enteros.

`ρ*` reproduce la forma histórica `(L+I)/(I+W_dec−1)` sin error de redondeo, y la
viabilidad `D ≤ L − W_dec` se decide con enteros: **ningún veredicto discreto depende de
`Float64`** (LINQ §5.3, `veritas/LINEO.md:275`).
"""
function referencia_exacta(
    rho_num::Integer, rho_den::Integer, I::Integer, W_dec::Integer, D::Integer,
    S_max::Integer, F_slots::Integer, L_suelo::Integer,
)
    rho_den > 0 || throw(ArgumentError("rho_den debe ser positivo"))
    rho_num > 0 || throw(ArgumentError("rho_num debe ser positivo"))
    I > 0 || throw(ArgumentError("I debe ser positivo"))
    L = max(F_slots, L_suelo, S_max + 1)

    rho = Rational{BigInt}(rho_num, rho_den)
    A_nuc = rho <= 1 ? Rational{BigInt}(0) :
        max(Rational{BigInt}(0), Rational{BigInt}(L - 1 - W_dec) + I * (1 - inv(rho)))
    A_d = max(Rational{BigInt}(0), A_nuc - D)
    A_h = rho <= 1 ? Rational{BigInt}(0) :
        max(Rational{BigInt}(0), Rational{BigInt}(I + W_dec - 1) - Rational{BigInt}(L + I) / rho)
    re = Rational{BigInt}(L + I, I + W_dec - 1)
    umbral_viabilidad = L - W_dec

    return (
        L_slots = L,
        manda_F = L == F_slots,
        A_nucleo = A_nuc,
        A_D = A_d,
        A_con_h = A_h,
        rho_estrella = re,
        umbral_viabilidad = umbral_viabilidad,
        vivo = D <= umbral_viabilidad,
        rho_es_menor_que_estrella = rho < re,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# 3 · Sim-v1 — contabilidad de eventos explícita
# ─────────────────────────────────────────────────────────────────────────────

"""
Evento de una época en Sim-v1. `s_j` es el slot del ancla, `t_j = s_j + L` la activación,
`d_j = s_j + W_dec` el instante en que la red ha cerrado el ancla.
"""
struct EpocaSim
    j::Int
    T_j::Int
    s_j::Int
end

"""
**Sim-v1 — oráculo independiente.** No evalúa ninguna forma cerrada. Construye el
calendario de épocas, deriva de él la lista de inyecciones, y calcula las fronteras de
slots firmables con las dos restricciones reales del SPEC:

```text
para firmar el slot s en el instante t hacen falta:
  (i)  PoT propio  ≥ s + D          (C-POT-05: la cabecera lleva salida(f, s+D))
  (ii) el flujo está determinado hasta s + D
       (todas las inyecciones con t_i ≤ s + D tienen su ancla cerrada: d_i ≤ t)
```

`Γ(t)` se deriva de la lista de épocas: es `t_{i*+1} − 1`, con `i*` la última época con
`d_i ≤ t`. **No** se usa `t + I + L − W_dec`.

Devuelve `(A_sim, Γ, t_decision, frontera_honesta, frontera_atacante)`.

- `rho` entra como `Rational` para que la aritmética sea exacta.
- `off_j` es el desplazamiento del ancla respecto a su umbral; se pasa como vector para
  poder barrer el peor caso (`off = 0` es el más favorable al atacante dentro de la época,
  `off = S_max − 1` el menos).
"""
function simular_fronteras(
    rho::Rational{<:Integer}, L::Integer, I::Integer, W_dec::Integer, D::Integer,
    n_epocas::Integer; off::AbstractVector{<:Integer} = Int[], j_objetivo::Integer = -1,
)
    I > 0 || throw(ArgumentError("I debe ser positivo"))
    n_epocas >= 2 || throw(ArgumentError("se necesitan al menos 2 épocas"))
    length(off) >= n_epocas || throw(ArgumentError("faltan offsets de ancla"))

    epocas = Vector{EpocaSim}(undef, n_epocas)
    for j in 1:n_epocas
        Tj = (j - 1) * I
        epocas[j] = EpocaSim(j, Tj, Tj + Int(off[j]))
    end

    # Instante de decisión: el del ancla de la época objetivo, más la ventana.
    jb = j_objetivo < 0 ? n_epocas - 1 : Int(j_objetivo)
    t_dec = epocas[jb].s_j + W_dec

    # Γ(t): última inyección determinada por t. i* = última época con d_i ≤ t.
    i_estrella = 0
    for e in epocas
        if e.s_j + W_dec <= t_dec
            i_estrella = e.j
        end
    end
    Gamma = i_estrella + 1 <= n_epocas ? epocas[i_estrella + 1].s_j + L - 1 : typemax(Int)
    Gamma >= 0 || (Gamma = -1)

    # Fronteras de slots firmables.
    # Honesto: PoT = t + D; atacante: PoT = D + rho·t.
    # Firmar el slot s exige (i) PoT ≥ s + D y (ii) flujo determinado hasta s + D, i.e.
    # s + D ≤ Γ. Por tanto la frontera es mín(PoT, Γ) − D: se resta D UNA vez.
    pot_hon = t_dec + D
    pot_adv = D + fld(rho.num * t_dec, rho.den)
    fr_hon = min(pot_hon, Gamma) - D
    fr_adv = min(pot_adv, Gamma) - D

    A_sim = max(0, fr_adv - fr_hon)
    return (A_sim = A_sim, Gamma = Gamma, t_decision = t_dec,
        frontera_honesta = fr_hon, frontera_atacante = fr_adv)
end

"""
Peor caso de `off` para el atacante: `off_j = 0` para todas las épocas maximiza `Γ(t)`
(el ancla llega lo antes posible) y por tanto maximiza el adelanto. `off_j = S_max − 1`
es el otro extremo. Se exponen las dos para que el barrido no elija una sola.
"""
function rejilla_offsets(n::Integer, valor::Integer)
    return fill(Int(valor), Int(n))
end
