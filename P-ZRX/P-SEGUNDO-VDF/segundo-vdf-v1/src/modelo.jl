# ─────────────────────────────────────────────────────────────────────────────
# modelo.jl — parámetros, aritmética de calibración/coste y transición del modelo.
#
# Fuentes normativas (leídas, no modificadas):
#   SPEC.md      C-POT-01…08, C-FLU-01, C-FLU-04…16, C-FLU-21/22, C-NET-31…33, C-FIN-01
#   TAREAS.md    §2.1 y §2.9
#   MIGRACION.md parámetros (ρ_max, I, Lrev, F, L_suelo, D, N(s) PENDIENTES)
#   veritas/LINEO.md, P-ZRX/P-REVELACION/investigacion/** (REV-v1.0, control externo)
#
# REGLA DE ESTE INSTRUMENTO: ningún parámetro se adopta. Todos son entradas; las
# fronteras que aquí se calculan se publican como fronteras, no como valores.
# ─────────────────────────────────────────────────────────────────────────────

# ── 0. Entradas medidas (no resultados) ──────────────────────────────────────
#
# `verify` y `prove` son medidas de la primitiva PoT de UN slot en el Ryzen 9
# 9950X3D a N=200_032_000 (research/dag-poas-ancla-de-orden.md:342):
#   verify = 0,096147 s/slot (sd 0,000344) — verificación con 8 carriles
#   prove  = 1,561347 s/slot (sd 0,003265) — producción secuencial
# La asimetría 16,24× es de camino crítico, no de trabajo total (el trabajo AES
# es el mismo: T bloques; la verificación reparte T/16 por carril).
const VERIFY_S_POR_SLOT = 0.096147
const PROVE_S_POR_SLOT = 1.561347
const ASIMETRIA_PROVE_VERIFY = 16.24
const TAU_NOM_S_POR_SLOT = 1          # τ_nom = 1 s/slot (MIGRACION.md:117)
const N_SLOT_NOMINAL = 206_557_520    # supuesto nominal distinto del N de las medidas anteriores
const U32_MAX = 4_294_967_295         # NonZeroU32 de zx-pot::prove/verify

"Convierte segundos a slots con `τ_nom` (C-FLU-01: `F_slots := ⌈F/τ_nom⌉`)."
w_dec_slots(w_dec_s::Real; tau_nom::Real = TAU_NOM_S_POR_SLOT) = w_dec_s / tau_nom

# ── 1. Defecto 1 — calibración (h.6) con unidades y enteros correctos ────────
"""
Umbral de *steering* de la ronda 10a (forma cerrada, REV-v1.0 `referencia.jl:181`):
`ρ* = (Lrev + I)/(I + W_dec)`, todo en **slots**. No es una ventana ni una
probabilidad: es el umbral a partir del cual el atacante puede evaluar ≥ 1
iteración sobre un candidato dentro de la ventana de decisión.
"""
rho_estrella(Lrev::Real, I::Real, W_dec::Real) = (Lrev + I) / (I + W_dec)

"`ρ*` exacto (aritmética racional; para los controles de frontera)."
rho_estrella_exacta(Lrev::Integer, I::Integer, W_dec::Integer) = (Lrev + I) // (I + W_dec)

"""
Frontera **correcta** de la calibración (h.6) derivada aquí, con `Lrev = L − S_max`:

    ρ* ≥ ρ_max  ⇔  (Lrev + I)/(I + W_dec) ≥ ρ_max
                ⇔  I ≤ (Lrev − ρ_max·W_dec)/(ρ_max − 1)      (ρ_max > 1)

Devuelve la frontera **continua** exacta (racional). No es un valor adoptado.
"""
function I_frontera(Lrev::Real, rho_max::Real, W_dec::Real)
    rho_max <= 1 && return Inf
    return (Lrev - rho_max * W_dec) / (rho_max - 1)
end

"Frontera correcta en aritmética exacta: `(Lrev·q − p·W_dec)/(p − q)` con `ρ_max = p/q`."
function I_frontera_exacta(Lrev::Integer, rho_max_num::Integer, rho_max_den::Integer, W_dec::Integer)
    den = rho_max_num - rho_max_den
    den <= 0 && return nothing
    return (Lrev * rho_max_den - rho_max_num * W_dec) // den
end

"""
Frontera **histórica** (d8-ronda10a §A.6, defecto declarado en el encargo §2.1):
usa `L` en el numerador en lugar de `Lrev = L − S_max`.
"""
function I_frontera_historica(L::Real, rho_max::Real, W_dec::Real)
    rho_max <= 1 && return Inf
    return (L - rho_max * W_dec) / (rho_max - 1)
end

"Mayor `I` entero que cumple la frontera: `I_max = ⌊frontera⌋` (redondeo de slots)."
I_frontera_entera(Lrev::Real, rho_max::Real, W_dec::Real) = floor(Int, I_frontera(Lrev, rho_max, W_dec))

"""
Restricciones inferiores vigentes sobre `I` (slots):
  · `I ≥ ρ_max·W_dec`  — R-FIN-14(f) / research/dag-poas-ancla-de-orden.md:277-279
  · `I > S_max`        — C-FLU-09 (SPEC.md:1645-1652)
`I_min = ⌈máx(ρ_max·W_dec, S_max + 1)⌉` (entero; `I` se cuenta en slots).
"""
function I_minima_entera(rho_max::Real, W_dec::Real, S_max::Real)
    return ceil(Int, max(rho_max * W_dec, S_max + 1))
end

"""
Cota superior de `ρ_max` que impone la propia calibración al exigir `I ≥ ρ_max·W_dec`
(la restricción que manda a `ρ_max` grande):

    (Lrev − ρ·W_dec)/(ρ − 1) ≥ ρ·W_dec  ⇔  Lrev ≥ ρ²·W_dec  ⇔  ρ ≤ √(Lrev/W_dec)

Es una cota **derivada de la forma cerrada**; como el `ρ*` simulado es mayor que el
cerrado (REV-v1.0 §1.3), la cota es conservadora (la real no es menor).
"""
rho_max_cota_sqrt(Lrev::Real, W_dec::Real) = sqrt(Lrev / W_dec)

"""
Cota en el primer `I` entero admisible, `I=S_max+1`:

    ρ ≤ (Lrev + S_max + 1)/(W_dec + S_max + 1).
Es una cota **no estricta** del criterio cerrado, no la frontera exacta al
optimizar sobre todos los `I` enteros.
"""
rho_max_cota_cflu09(Lrev::Real, S_max::Real, W_dec::Real) =
    (Lrev + S_max + 1) / (W_dec + S_max + 1)

"Máximo exacto de ρ permitido por `I≥ρ W` y `ρ≤(Lrev+I)/(W+I)`, con I entero."
function rho_max_factible_entero(Lrev::Integer, W::Integer, S_max::Integer)
    W > 0 || throw(ArgumentError("W debe ser positivo"))
    mejor = 0 // 1; mejor_I = 0
    for I in (S_max + 1):Lrev
        rho = min(I // W, (Lrev + I) // (W + I))
        if rho > mejor
            mejor = rho; mejor_I = I
        end
    end
    return (rho = mejor, I = mejor_I)
end

"""
Puntualidad honesta con (h). El timekeeper arranca la revelación en
`base_h = máx(s_j, T_j + W_dec)`, necesita `Lrev` slots de su reloj y debe cruzar
`t_j` en `t_j − lead_h`; el slot `t_j` cuesta uno más.

Discreta, peor caso sobre `off_j ∈ [0, S_max)` (el mínimo se alcanza en `off_j = 0`):

    Lrev ≤ L − W_dec − D − 1

Devuelve la **holgura** `L − W_dec − D − 1 − Lrev`. `≥ 0` ⇒ puntual en el peor caso.
(Nota: REV-v1.0 escribe `Lrev ≤ L − W_dec − D + off_j − 1`; con `off_j = 0` es esta.)
"""
holgura_puntualidad(L::Real, W_dec::Real, D::Real, Lrev::Real) = (L - W_dec - D - 1) - Lrev

"Versión por tramos: holgura para un `off_j` concreto (`eh + 1 ≤ t_j − lead_h`)."
holgura_puntualidad(L::Real, W_dec::Real, D::Real, Lrev::Real, off::Real) =
    (L + off - max(off, W_dec) - D - 1) - Lrev

# ── 2. Coste (defecto 2 y §4 del encargo) ────────────────────────────────────
"Líneas AES secuenciales simultáneas del timekeeper: `q + 1 = ⌈L/I⌉ + 1` (d8 §B.1.5)."
lineas_timekeeper(L::Real, I::Real) = ceil(Int, L / I) + 1

"Núcleos continuos de un nodo **verificador** con (h): `c_v·(1 + Lrev/I)`, `c_v = verify`."
nucleos_verificador(Lrev::Real, I::Real; c_v::Real = VERIFY_S_POR_SLOT) = c_v * (1 + Lrev / I)

"Núcleos continuos por línea del **productor** (timekeeper): `prove` por slot servido."
nucleos_linea_produccion(; c_p::Real = PROVE_S_POR_SLOT) = c_p

"Instantes `t_j` por hora: `3600/I` con `I` en slots de `τ_nom = 1 s` (C-FLU-09)."
instantes_por_hora(I::Real) = 3600 / I

"""
Líneas AES adicionales para sostener el **caudal** de una semilla elegida por
época con llegadas separadas `I/ρ`:

    líneas = ⌈Lrev / I⌉

Una línea a tasa ρ cubre `I` slots de trabajo entre esas llegadas. Es una
cuenta de capacidad bajo ese calendario, no garantía de fin antes de decidir
el ancla. Se suma la línea PoT principal y las variantes de chunk si se
especula. Cada cadena conserva una latencia mínima `Lrev/ρ` desde su semilla.
"""
lineas_revelacion_por_epoca(Lrev::Real, I::Real) = ceil(Int, Lrev / I)

"""
Cuenta hipotética de capacidad para `S_max` slots candidatos, con exactamente
`variantes_chunk` semillas por slot. No acota el número de bloques/chunks del
DAG y tampoco elimina la latencia secuencial de ninguna cadena.
"""
lineas_revelacion_todos_candidatos(Lrev::Real, I::Real, S_max::Real;
                                   variantes_chunk::Int = 1) =
    ceil(Int, ceil(Int, S_max) * variantes_chunk * Lrev / I)

"Coste de ponerse al día verificando `F_slots` slots de un flujo rival (C-FLU-22/C-NET-33)."
function coste_ponerse_al_dia(F_slots::Real; c_v::Real = VERIFY_S_POR_SLOT, nucleos::Real = 1)
    seg = F_slots * c_v
    return (segundos = seg, segundos_paralelo = seg / nucleos)
end

# ── 3. Defecto 5 — expresabilidad de la cadena larga en la primitiva auditada ─
"""
Iteraciones totales de la cadena de revelación de la candidata (h.1):
`T = Lrev · N(slot(I_j))`, con `N` **congelado** en el ancla (h.5).

`zx-pot::prove/verify` aceptan `NonZeroU32` y exigen `T % 16 == 0` (8 checkpoints,
`m = T/8` par). Devuelve `(T, expresable_en_una_llamada)`.
"""
function cadena_larga(Lrev::Real, N_slot::Real)
    T = Lrev * N_slot
    return (T = T, una_llamada = (T <= U32_MAX && T % 16 == 0))
end

"Mayor `Lrev` expresable en una sola llamada con `N = N_slot` y `N % 16 == 0`."
Lrev_max_una_llamada(N_slot::Real) = floor(Int, U32_MAX / N_slot)

# ── 4. Configuración y transición del modelo ────────────────────────────────
"""
Entradas del modelo (todas símbolos; ninguna se adopta aquí).

- `L, I, W_dec, D, S_max, Lrev` en **slots** (τ_nom = 1 s/slot).
- `rho`: reloj AES del atacante / reloj del timekeeper (adimensional).
- `con_h`: segunda cadena de revelación (R-FIN-14(h)).
- `espera`: el atacante espera la decisión del ancla (`+W_dec`); `false` = especula.
- `semilla_futura`: `true` = C-FLU-12 vigente, ingrediente `pot_output(I_j) = salida(f, s_j+D)`;
  `false` = candidata (h.1), ingrediente `salida(f, slot(I_j))`.
- `revelacion_paralela`: `true` = iniciar al conocer la semilla en una de
  `lineas_revelacion` líneas finitas; `false` = esperar la decisión y sumar la
  latencia (control histórico REV-v1.0).
- `revelacion_instantanea`: control contrafáctico que omite los pasos AES.
- `cruce`: cruzar la barrera cuesta `1/ρ` (física) o es gratis (convención histórica).
- `lead_h`: adelanto de la frontera honesta sobre su frontera de bloques (`0` o `D`, C-POT-05).
"""
struct Cfg{T<:Real}
    L::T
    I::T
    W_dec::T
    D::T
    S_max::T
    Lrev::T
    con_h::Bool
    espera::Bool
    semilla_futura::Bool
    revelacion_paralela::Bool
    revelacion_instantanea::Bool
    lineas_revelacion::Int
    cruce::Bool
    lead_h::T
end

function Cfg{T}(; L, I, W_dec, D = zero(T), S_max = zero(T), Lrev = L,
                con_h::Bool = false, espera::Bool = false, semilla_futura::Bool = true,
                revelacion_paralela::Bool = false, cruce::Bool = true,
                revelacion_instantanea::Bool = false, lineas_revelacion::Int = 1,
                lead_h = D) where {T<:Real}
    lineas_revelacion >= 1 || throw(ArgumentError("se necesita al menos una línea"))
    return Cfg{T}(T(L), T(I), T(W_dec), T(D), T(S_max), T(Lrev),
                  con_h, espera, semilla_futura, revelacion_paralela,
                  revelacion_instantanea, lineas_revelacion, cruce, T(lead_h))
end

"Trayectorias por puntos de ruptura de las dos fronteras (buffers preasignados)."
mutable struct Tray{T<:Real}
    tA::Vector{T}
    pA::Vector{T}
    tH::Vector{T}
    pH::Vector{T}
    evt::Vector{T}
    nA::Int
    nH::Int
end

function Tray{T}(J::Int) where {T<:Real}
    cap = 3 * (J + 4) + 8
    return Tray{T}(Vector{T}(undef, cap), Vector{T}(undef, cap),
                   Vector{T}(undef, cap), Vector{T}(undef, cap),
                   Vector{T}(undef, 2 * cap), 0, 0)
end

@inline function _tiempo_paso(t::Vector{T}, p::Vector{T}, n::Int, x::T) where {T<:Real}
    i = n
    @inbounds while i > 1 && p[i-1] >= x
        i -= 1
    end
    i == 1 && return t[1]
    @inbounds if p[i] == p[i-1]
        return t[i]
    end
    @inbounds f = (x - p[i-1]) / (p[i] - p[i-1])
    return t[i-1] + f * (t[i] - t[i-1])
end

"""
Construye las dos trayectorias por época `j = 1…J`:

    T_j = j·I ,  s_j = T_j + off_j ,  t_j = s_j + L

Atacante (recursión de barrera de REV-v1.0, identidad 1):
    a_j   = τ_{j-1} + (t_j − 1 − t_{j-1})/ρ
    e_j   = instante en que dispone de la entropía (ver `Cfg`)
    τ_j   = máx(a_j, e_j) + 1/ρ   (o sin `+1/ρ` si `cruce = false`)

Honesto:
    ea    = σ_{j-1} + (t_j − 1 − t_{j-1})
    eh    = máx(s_j, T_j + W_dec) + (con_h ? Lrev : 0)
    σ_j   = máx(ea, eh) + 1

Devuelve `(nstall)` = épocas en que el honesto se estanca (invariante de puntualidad).
Esto es **transición compartida**; el oráculo independiente vive en `referencia.jl`.
"""
function construir!(tr::Tray{T}, cfg::Cfg{T}, off::AbstractVector{T},
                    propia::AbstractVector{Bool}, rho::T, J::Int;
                    traza::Union{Nothing,Vector} = nothing,
                    chunk_conocido::Union{Nothing,AbstractVector{T}} = nothing,
                    flujo_previo_conocido::Union{Nothing,AbstractVector{T}} = nothing,
                    bloque_recibido::Union{Nothing,AbstractVector{T}} = nothing,
                    ancla_decidida::Union{Nothing,AbstractVector{T}} = nothing) where {T<:Real}
    ir = one(T) / rho
    nA = 1; tr.tA[1] = zero(T); tr.pA[1] = cfg.lead_h
    nH = 1; tr.tH[1] = zero(T); tr.pH[1] = cfg.lead_h
    Apos = cfg.lead_h; tau = zero(T)
    Hpos = cfg.lead_h; sig = zero(T)
    nst = 0
    # Una línea ejecuta una sola cadena secuencial cada vez. Este modelo
    # asigna una candidata seleccionada por época, sin ramas especuladas.
    libres = fill(zero(T), cfg.lineas_revelacion)
    for j in 1:J
        Tj = T(j) * cfg.I
        sj = Tj + off[j]
        tj = sj + cfg.L
        tj1 = tj - one(T)

        # atacante
        gap = (tj1 - Apos) * ir
        a = tau + (gap > zero(T) ? gap : zero(T))
        xbase = cfg.semilla_futura ? sj + cfg.D : sj
        t_ing = xbase <= Apos ? _tiempo_paso(tr.tA, tr.pA, nA, xbase) :
                tau + (min(xbase, tj1) - Apos) * ir
        t_hon = sj <= Apos ? _tiempo_paso(tr.tA, tr.pA, nA, sj) :
                tau + (min(sj, tj1) - Apos) * ir
        t_hon = t_hon > sj ? t_hon : sj
        c = if propia[j]
            t_ing
        else
            cfg.espera ? t_hon + cfg.W_dec : t_hon
        end
        # La semilla solo existe cuando TODOS sus ingredientes están disponibles.
        # Sin vectores externos se usa la hipótesis optimista del escenario.
        r_pot = propia[j] ? t_ing : t_hon
        r_chunk = chunk_conocido === nothing ? r_pot : chunk_conocido[j]
        r_flujo = flujo_previo_conocido === nothing ? zero(T) : flujo_previo_conocido[j]
        r_bloque = propia[j] ? zero(T) :
                   bloque_recibido === nothing ? t_hon : bloque_recibido[j]
        r = max(r_pot, r_chunk, r_flujo, r_bloque)
        c = ancla_decidida === nothing ? c : ancla_decidida[j]
        E = cfg.con_h && cfg.revelacion_instantanea ? max(c, r) : c
        inicio = r; fin = r; k = 0
        if cfg.con_h && !cfg.revelacion_instantanea
            if cfg.revelacion_paralela
                k = 1
                inicio = max(r, libres[1])
                for l in 2:length(libres)
                    inicio_l = max(r, libres[l])
                    if inicio_l < inicio
                        k = l; inicio = inicio_l
                    end
                end
                fin = inicio + cfg.Lrev * ir
                libres[k] = fin
                E = max(c, fin)
            else
                inicio = max(c, r); fin = inicio + cfg.Lrev * ir
                E = fin; k = 1
            end
        end
        if traza !== nothing
            push!(traza, (epoca = j, propia = propia[j], variante_futura = cfg.semilla_futura,
                          pot_conocido = r_pot, chunk_conocido = r_chunk,
                          flujo_conocido = r_flujo, bloque_recibido = r_bloque,
                          semilla_completa = r, decision = c, linea = k,
                          inicio = inicio, fin = fin, barrera = E,
                          instantanea = cfg.revelacion_instantanea))
        end
        tc = a > E ? a : E
        tjn = cfg.cruce ? tc + ir : tc

        if a > tau
            nA += 1; tr.tA[nA] = a; tr.pA[nA] = tj1
        end
        if tc > a
            nA += 1; tr.tA[nA] = tc; tr.pA[nA] = tj1
        end
        nA += 1; tr.tA[nA] = tjn; tr.pA[nA] = tj
        Apos = tj; tau = tjn

        # honesto
        gaph = tj1 - Hpos
        ea = sig + (gaph > zero(T) ? gaph : zero(T))
        base_h = sj > Tj + cfg.W_dec ? sj : Tj + cfg.W_dec
        eh = cfg.con_h ? base_h + cfg.Lrev : base_h
        sc = ea > eh ? ea : eh
        sjn = sc + one(T)
        if eh > ea
            nst += 1
        end
        if ea > sig
            nH += 1; tr.tH[nH] = ea; tr.pH[nH] = tj1
        end
        if sc > ea
            nH += 1; tr.tH[nH] = sc; tr.pH[nH] = tj1
        end
        nH += 1; tr.tH[nH] = sjn; tr.pH[nH] = tj
        Hpos = tj; sig = sjn
    end
    tr.nA = nA; tr.nH = nH
    return nst
end

"""
Máximo y mínimo exactos de `V(t) = Φ_a(t) − Φ_h(t)` y media temporal, sobre
`[t_ini, t_fin]`. En cada tramo entre puntos de ruptura las dos fronteras son
lineales, luego `V` también: el extremo está en los puntos de ruptura.
Devuelve `(vmax, vmin, area, vfin)`.
"""
function extremos!(tr::Tray{T}, t_ini::T, t_fin::T) where {T<:Real}
    tA = tr.tA; pA = tr.pA; tH = tr.tH; pH = tr.pH; evt = tr.evt
    nA = tr.nA; nH = tr.nH
    # fusión ordenada de los dos conjuntos de puntos de ruptura
    nE = 0; ia = 1; ih = 1
    @inbounds while ia <= nA && ih <= nH
        if tA[ia] <= tH[ih]
            nE += 1; evt[nE] = tA[ia]; ia += 1
        else
            nE += 1; evt[nE] = tH[ih]; ih += 1
        end
    end
    @inbounds while ia <= nA
        nE += 1; evt[nE] = tA[ia]; ia += 1
    end
    @inbounds while ih <= nH
        nE += 1; evt[nE] = tH[ih]; ih += 1
    end
    vmax = zero(T); vmin = zero(T); area = zero(T)
    visto = false; pa = 1; ph = 1
    tprev = evt[1]; vprev = pA[1] - pH[1]
    @inbounds for e in 2:nE
        t = evt[e]
        ultimo = false
        if t > t_fin
            t = t_fin; ultimo = true
        end
        while pa < nA && tA[pa+1] <= t
            pa += 1
        end
        while ph < nH && tH[ph+1] <= t
            ph += 1
        end
        va = pa < nA ? pA[pa] + (pA[pa+1] - pA[pa]) * (t - tA[pa]) / (tA[pa+1] - tA[pa]) : pA[pa]
        vh = ph < nH ? pH[ph] + (pH[ph+1] - pH[ph]) * (t - tH[ph]) / (tH[ph+1] - tH[ph]) :
             pH[nH] + (t - tH[nH]) * (pH[nH] - pH[nH-1]) / (tH[nH] - tH[nH-1])
        v = va - vh
        if t >= t_ini
            if !visto
                vmax = v; vmin = v; visto = true
            end
            v > vmax && (vmax = v)
            v < vmin && (vmin = v)
            if tprev < t_ini
                f = (t_ini - tprev) / (t - tprev)
                vprev = vprev + f * (v - vprev)
                tprev = t_ini
            end
            dt = t - tprev
            if dt > zero(T)
                area += (vprev + v) * dt / 2
            end
        end
        tprev = t; vprev = v
        ultimo && break
    end
    Δ = t_fin - t_ini
    return (vmax, vmin, Δ > zero(T) ? area / Δ : zero(T), vprev)
end

"Fin del horizonte estadístico: instante en que el atacante cruza la última barrera."
fin_horizonte(tr::Tray{T}) where {T<:Real} = tr.tA[tr.nA]

# ── 5. Defecto 1 — tablas de calibración (aritmética exacta, sin adopción) ────
"""
Control obligatorio del encargo §2.1: escenario histórico `L = 7200` slots,
`S_max = 150` slots, `W_dec = 20 s` con `τ_nom = 1 s/slot`, `ρ_max = 2,5`.

Devuelve la fila histórica (con `L` en el numerador) y la frontera corregida,
ambas con `ρ*` exacto, más las restricciones inferiores y la puntualidad.
"""
function control_historico_h6(; L = 7200, S_max = 150, W_dec_s = 20, rho_max_num = 5,
                              rho_max_den = 2, D = 4)
    W = Int(w_dec_slots(W_dec_s))                  # 20 slots con τ_nom = 1 s/slot (entero)
    Lrev = L - S_max
    rho_max = rho_max_num // rho_max_den
    I_hist = I_frontera_historica(L, rho_max, W)   # (L − ρ·W)/(ρ−1)
    fr = I_frontera_exacta(Lrev, rho_max_num, rho_max_den, W)
    I_corr = fld(numerator(fr), denominator(fr))   # ⌊·⌋ exacto
    rho_hist = rho_estrella_exacta(Lrev, floor(Int, I_hist), W)
    rho_corr = rho_estrella_exacta(Lrev, I_corr, W)
    return (W_dec_slots = W, Lrev = Lrev, rho_max = Float64(rho_max),
            I_historica = Float64(I_hist), I_historica_entera = floor(Int, I_hist),
            I_historica_redondeada = round(Int, I_hist),
            rho_estrella_historica = rho_hist, cumple_historica = rho_hist >= rho_max,
            rho_estrella_historica_redondeada = rho_estrella_exacta(Lrev, round(Int, I_hist), W),
            frontera_corregida = fr, I_corregida = I_corr, rho_estrella_corregida = rho_corr,
            cumple_corregida = rho_corr >= rho_max,
            deficit_slots = floor(Int, I_hist) - I_corr,
            I_minima = I_minima_entera(rho_max, W, S_max),
            holgura_puntualidad = holgura_puntualidad(L, W, D, Lrev),
            rho_max_cota_sqrt = rho_max_cota_sqrt(Lrev, W),
            rho_max_cota_cflu09 = rho_max_cota_cflu09(Lrev, S_max, W))
end

"""
Tabla de calibración sobre una rejilla de `ρ_max`: frontera correcta frente a la
histórica, intervalo factible de `I` y coste en la frontera. Marca `admisible`.
"""
function tabla_calibracion(; L = 7200.0, W_dec = 20.0, S_max = 150.0, D = 4.0,
                           rhos = (1.2, 1.5, 2.0, 2.5, 3.0, 5.0, 9.0, 12.0, 18.0, 18.77, 19.0))
    Lrev = L - S_max
    filas = NamedTuple[]
    for rho in rhos
        Imin = I_minima_entera(rho, W_dec, S_max)
        Imax = I_frontera_entera(Lrev, rho, W_dec)
        adm = Imax >= Imin
        push!(filas, (rho_max = rho,
                      I_frontera_continua = I_frontera(Lrev, rho, W_dec),
                      I_max = Imax, I_min = Imin, admisible = adm,
                      rho_estrella_en_frontera = adm ? rho_estrella(Lrev, Imax, W_dec) : NaN,
                      lineas = adm ? lineas_timekeeper(L, Imax) : 0,
                      nucleos = adm ? nucleos_verificador(Lrev, Imax) : NaN,
                      inyecciones_h = adm ? instantes_por_hora(Imax) : NaN,
                      linea_sqrt = rho_max_cota_sqrt(Lrev, W_dec),
                      linea_cflu09 = rho_max_cota_cflu09(Lrev, S_max, W_dec)))
    end
    return filas
end
