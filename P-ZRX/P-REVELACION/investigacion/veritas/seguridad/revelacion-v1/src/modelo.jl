# ─────────────────────────────────────────────────────────────────────────────
# modelo.jl — tipos, construcción de trayectorias y acumulación temporal
#
# Aquí vive el modelo matemático compartido. NO hay ninguna forma cerrada: la
# referencia (`referencia.jl`) lo reimplementa por slot y el kernel rápido
# (`rapido.jl`) lo acumula en histogramas exactos por tramos lineales.
# ─────────────────────────────────────────────────────────────────────────────

"""
Entradas del modelo. Inmutable, campos concretos del mismo tipo `T`.

- `L`, `I`, `W_dec`, `D`, `S_max`, `Lrev` en **slots**.
- `rho` es adimensional (reloj AES del atacante / reloj del timekeeper).
- `con_h`: opción `R-FIN-14(h)`. La entropía se calcula, no se publica, y cuesta
  `Lrev/ρ` de reloj propio (en la línea de revelación, **en paralelo** con la cadena principal).
- `espera`: `true` = modelo de 9c (el atacante no evalúa el candidato ajeno hasta que la red ha
  decidido el ancla: `+W_dec` sobre la disponibilidad de la entropía); `false` = modelo de la
  ronda 10a (especula sobre todos los candidatos en paralelo, coste cero en entropía).
- `cruce`: `true` = cruzar la barrera cuesta `1/ρ` (el slot `t_j` hay que computarlo);
  `false` = cruce instantáneo, la convención del instrumento histórico (`r10a_lib.py:167`).
- `lead_h`: adelanto de la **frontera de PoT** honesta sobre su frontera de bloques, en slots.
  `0` = frontera honesta en `t` (convención implícita de `r10a_lib.py` y de `A_core`);
  `D` = frontera honesta en `t + D`, que es lo que exige `C-POT-05` para producir un bloque en su
  slot (`pot_output(B) = salida(f, slot(B)+D)`). Es la premisa 6 de ADL-v1.0, aquí como interruptor.
- `j_ini`: primeras `j_ini` épocas fuera de las estadísticas (transitorio).
"""
struct Config{T<:Real}
    L::T
    I::T
    W_dec::T
    D::T
    S_max::T
    Lrev::T
    con_h::Bool
    espera::Bool
    cruce::Bool
    lead_h::T
    j_ini::Int
end

function Config{T}(;
    L, I, W_dec, D = zero(T), S_max = zero(T), Lrev = L,
    con_h::Bool = false, espera::Bool = false, cruce::Bool = true,
    lead_h = D, j_ini::Int = 0,
) where {T<:Real}
    return Config{T}(T(L), T(I), T(W_dec), T(D), T(S_max), T(Lrev),
                     con_h, espera, cruce, T(lead_h), j_ini)
end

"Resultado de una réplica para un `ρ` dado."
struct MetricasReplica{T<:Real}
    vmax::T          # máximo de V(t) = Φ_a(t) − Φ_h(t) en la ventana estadística
    vmin::T          # mínimo
    vmed::T          # media temporal exacta (∫V dt / Δt)
    vfin::T          # V al final del horizonte
    tini::T          # instante en que empieza la ventana estadística
    tfin::T          # instante final
    boot::T          # primer instante con V ≥ boot_ref (NaN si no se alcanza)
    v_barrera::T     # métrica de la ronda 10a: máx_j (t_j − llegada_j)
    n_steer_pro::Int # épocas con n_eval ≥ 1 sobre SU candidato
    n_steer_hon::Int # épocas con n_eval ≥ 1 sobre un candidato ajeno
    n_ep::Int
    n_stall_h::Int   # épocas en que la frontera honesta se estanca (invariante violada)
    nA::Int          # puntos de ruptura de la trayectoria del atacante
    nH::Int          # puntos de ruptura de la trayectoria honesta
end

"Buffers preasignados de una réplica. No se reserva memoria dentro del bucle de `ρ`."
mutable struct Buffers{T<:Real}
    tA::Vector{T}
    pA::Vector{T}
    tH::Vector{T}
    pH::Vector{T}
    evt::Vector{T}
    hist::Vector{Float64}
    bajo::Float64      # tiempo con V por debajo del origen del histograma
    sobre::Float64     # tiempo con V por encima del techo del histograma
    t_total::Float64
end

function Buffers{T}(J::Int, nb::Int) where {T<:Real}
    cap = 3 * (J + 4) + 8
    return Buffers{T}(Vector{T}(undef, cap), Vector{T}(undef, cap),
                      Vector{T}(undef, cap), Vector{T}(undef, cap),
                      Vector{T}(undef, 2 * cap), zeros(Float64, nb), 0.0, 0.0, 0.0)
end

"Reinicia los contadores del histograma (los buffers de trayectoria se sobrescriben)."
function reiniciar!(b::Buffers)
    fill!(b.hist, 0.0)
    b.bajo = 0.0
    b.sobre = 0.0
    b.t_total = 0.0
    return b
end

"""
Instante en que la frontera descrita por `(tA,pA,nA)` alcanzó el slot `x`, con `x ≤ pA[nA]`.
Recorre los puntos de ruptura **hacia atrás** (el tramo buscado está a lo sumo ~`L/ρ` en el tiempo,
es decir pocas épocas) y devuelve `tA[1]` si `x` ya estaba computado al arrancar.
"""
@inline function _tiempo_paso(tA::Vector{T}, pA::Vector{T}, nA::Int, x::T) where {T<:Real}
    i = nA
    @inbounds while i > 1 && pA[i-1] >= x
        i -= 1
    end
    i == 1 && return tA[1]
    @inbounds if pA[i] == pA[i-1]
        return tA[i]
    end
    @inbounds f = (x - pA[i-1]) / (pA[i] - pA[i-1])
    return tA[i-1] + f * (tA[i] - tA[i-1])
end

"""
Construye las trayectorias **pieza a pieza** de la frontera del atacante (`tA`,`pA`) y de la
frontera honesta (`tH`,`pH`), con las barreras `t_j`, y cuenta las épocas con *steering*.

Devuelve `(nA, nH, n_steer_pro, n_steer_hon, n_ep, n_stall_h, v_barrera)`.

Reglas modeladas (todas citadas en el docstring del módulo):

- el atacante avanza a `ρ` slots por slot de pared **solo mientras tiene la entropía**;
- al llegar a `t_j − 1` sin `entropía_j`, **espera**; cuando la obtiene, cruza a `t_j`
  (coste `1/ρ` si `cruce`, instantáneo si no);
- el ancla **propia** no espera a la decisión de la red y no necesita que el bloque exista:
  la semilla es `pot_output(I_j) = salida(f, s_j + D)` (`C-POT-05`), que el atacante conoce en
  cuanto su frontera alcanza `s_j + D`;
- el ancla **ajena** no existe antes de su slot (cota `s_j`) y, en el modelo de 9c (`espera`),
  tampoco está disponible antes de `T_j + W_dec`;
- la frontera honesta cruza `t_j` en `t_j − lead_h` y necesita `entropía_j`, disponible en
  `máx(s_j, T_j + W_dec) + Lrev` a tasa 1. Si llega antes, **se estanca**: eso es una violación de
  la disciplina de puntualidad, se cuenta en `n_stall_h` y no se oculta.
"""
function construir_trayectorias!(
    tA::Vector{T}, pA::Vector{T}, tH::Vector{T}, pH::Vector{T},
    cfg::Config{T}, off::Vector{T}, propia::Vector{Bool}, rho::T, J::Int,
) where {T<:Real}
    ir = one(T) / rho
    nA = 1; tA[1] = zero(T); pA[1] = cfg.lead_h
    nH = 1; tH[1] = zero(T); pH[1] = cfg.lead_h
    A = cfg.lead_h
    tau = zero(T)
    H = cfg.lead_h
    sig = zero(T)
    nsp = 0; nsh = 0; nep = 0; nst = 0
    vbar = zero(T)
    uno = one(T)
    for j in 1:J
        Tj = T(j) * cfg.I
        sj = Tj + off[j]
        tj = sj + cfg.L
        tj1 = tj - uno

        # ── atacante ────────────────────────────────────────────────────────
        ta = tau + (tj1 - A) * ir
        if ta < tau
            ta = tau
        end
        # semilla propia: pot_output(I_j) = salida(f, s_j + D), C-POT-05. El atacante la conoce
        # en cuanto su frontera pasó el slot s_j + D, que puede ser en una época ANTERIOR.
        xpro = sj + cfg.D
        t_pro = xpro <= pA[nA] ? _tiempo_paso(tA, pA, nA, xpro) :
                tau + (min(xpro, tj1) - pA[nA]) * ir
        # semilla ajena: el bloque no existe antes de su slot
        t_hon = sj <= pA[nA] ? _tiempo_paso(tA, pA, nA, sj) :
                tau + ((sj < tj1 ? sj : tj1) - pA[nA]) * ir
        if t_hon < sj
            t_hon = sj
        end
        E_pro = t_pro
        E_hon = t_hon
        if cfg.con_h
            E_pro += cfg.Lrev * ir
            E_hon += cfg.Lrev * ir
        end
        if cfg.espera
            E_hon += cfg.W_dec     # ancla propia: no hay nada que esperar, decide él
        end
        e = propia[j] ? E_pro : E_hon
        tc = ta > e ? ta : e
        tjn = cfg.cruce ? tc + ir : tc

        if ta > tau
            nA += 1; tA[nA] = ta; pA[nA] = tj1
        end
        if tc > ta
            nA += 1; tA[nA] = tc; pA[nA] = tj1
        end
        nA += 1; tA[nA] = tjn; pA[nA] = tj

        # métrica del instrumento histórico: llegada a t_j (cruce gratis) y ventaja t_j − llegada
        lleg10a = tau + (tj - A) * ir
        vv = tj - lleg10a
        if vv > vbar
            vbar = vv
        end

        # ── steering de la época j (ronda 10a §B.1.2) ───────────────────────
        if cfg.W_dec >= zero(T) && j > cfg.j_ini
            Dj = Tj + cfg.W_dec
            Ccom = tau + (tj1 - A) * ir
            mcp = Ccom > E_pro ? Ccom : E_pro
            mch = Ccom > E_hon ? Ccom : E_hon
            dpro = Dj - mcp
            dhon = Dj - mch
            nev_pro = dpro > zero(T) ? min(cfg.I, rho * dpro) : zero(T)
            nev_hon = dhon > zero(T) ? min(cfg.I, rho * dhon) : zero(T)
            if nev_pro >= uno
                nsp += 1
            end
            if nev_hon >= uno
                nsh += 1
            end
        end
        if j > cfg.j_ini
            nep += 1
        end
        A = tj
        tau = tjn

        # ── honesto ─────────────────────────────────────────────────────────
        ea = sig + (tj1 - H)
        if ea < sig
            ea = sig
        end
        # disciplina (i) «esperar al ancla»: arranca en T_j + W_dec; necesita además el bloque
        TjW = Tj + cfg.W_dec
        base_h = sj > TjW ? sj : TjW
        eh = cfg.con_h ? base_h + cfg.Lrev : base_h
        sc = ea > eh ? ea : eh
        sjn = sc + uno
        if eh > ea
            nst += 1
        end
        if ea > sig
            nH += 1; tH[nH] = ea; pH[nH] = tj1
        end
        if sc > ea
            nH += 1; tH[nH] = sc; pH[nH] = tj1
        end
        nH += 1; tH[nH] = sjn; pH[nH] = tj
        H = tj
        sig = sjn
    end
    return (nA, nH, nsp, nsh, nep, nst, vbar)
end

"""
Acumula la distribución temporal de `V(t) = Φ_a(t) − Φ_h(t)` fusionando las dos trayectorias.

**Exacto.** Entre dos puntos de ruptura consecutivos las dos fronteras son lineales, luego `V`
también; el tiempo que `V` pasa dentro de cada bin se calcula en forma cerrada porque en un tramo
lineal la densidad de `V` es uniforme. El histograma cubre `[v_lo, v_lo + nb·bin)`.

`t_ini` es el origen de la ventana estadística: los tramos anteriores se descartan.
Devuelve `(vmax, vmin, area, vfin, boot, tfin)`; `boot` es `NaN` si `V` nunca alcanza `boot_ref`.
"""
function acumular!(
    b::Buffers{T}, cfg::Config{T}, nA::Int, nH::Int,
    bin::T, v_lo::T, t_ini::T, boot_ref::T, tA_fin::T, con_hist::Bool = true,
) where {T<:Real}
    t_fin = tA_fin
    tA = b.tA; pA = b.pA; tH = b.tH; pH = b.pH; evt = b.evt
    nE = 0
    ia = 1; ih = 1
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

    vmax = zero(T); vmin = zero(T)
    visto = false
    area = zero(T)
    boot = T(-1)                       # -1 = umbral de bootstrap no alcanzado (los tiempos son ≥ 0)
    pa = 1; ph = 1
    tprev = evt[1]
    vprev = pA[1] - pH[1]
    @inbounds for e in 2:nE
        t = evt[e]
        ultimo = false
        if t > t_fin
            t = t_fin
            ultimo = true
        end
        while pa < nA && tA[pa+1] <= t
            pa += 1
        end
        while ph < nH && tH[ph+1] <= t
            ph += 1
        end
        va = pa < nA ? pA[pa] + (pA[pa+1] - pA[pa]) * (t - tA[pa]) / (tA[pa+1] - tA[pa]) : pA[pa]
        # más allá de la última barrera las dos fronteras siguen avanzando a su ritmo (ρ y 1):
        # sin esto, con ρ ≤ 1 el tope de la tabla honesta falsearía el mínimo de V
        vh = ph < nH ? pH[ph] + (pH[ph+1] - pH[ph]) * (t - tH[ph]) / (tH[ph+1] - tH[ph]) :
             pH[nH] + (t - tH[nH]) * (pH[nH] - pH[nH-1]) / (tH[nH] - tH[nH-1])
        v = va - vh
        if t >= t_ini
            if !visto
                vmax = v; vmin = v; visto = true
            end
            if v > vmax
                vmax = v
            end
            if v < vmin
                vmin = v
            end
            if boot == T(-1) && v >= boot_ref
                boot = t - t_ini
            end
            if tprev < t_ini
                # tramo que cruza el origen: se recorta en t_ini
                f = (t_ini - tprev) / (t - tprev)
                vprev = vprev + f * (v - vprev)
                tprev = t_ini
            end
            dt = t - tprev
            if dt > zero(T)
                area += (vprev + v) * dt / 2
                if con_hist
                    llenar_rampa!(b, vprev, v, dt, bin, v_lo)
                end
                b.t_total += Float64(dt)
            end
        end
        tprev = t
        vprev = v
        ultimo && break
    end
    return (vmax, vmin, area, vprev, boot, t_fin)
end

"""
Reparte el tiempo `dt` de un tramo lineal de `V` entre bins. Exacto: en un tramo lineal la
densidad de `V` es uniforme, así que el tiempo del bin `k` es
`dt · (longitud de V ∩ [v_lo+k·bin, v_lo+(k+1)·bin)) / |ΔV|`.
"""
@inline function llenar_rampa!(b::Buffers{T}, v0::T, v1::T, dt::T, bin::T, v_lo::T) where {T<:Real}
    hist = b.hist
    nb = length(hist)
    if v0 == v1
        k = floor(Int, (v0 - v_lo) / bin)
        if k < 0
            b.bajo += Float64(dt)
        elseif k >= nb
            b.sobre += Float64(dt)
        else
            @inbounds hist[k+1] += Float64(dt)
        end
        return nothing
    end
    lo = v0 < v1 ? v0 : v1
    hi = v0 < v1 ? v1 : v0
    dv = hi - lo
    k0 = floor(Int, (lo - v_lo) / bin)
    k1 = floor(Int, (hi - v_lo) / bin)
    @inbounds for k in k0:k1
        a = lo > v_lo + T(k) * bin ? lo : v_lo + T(k) * bin
        bb = hi < v_lo + T(k + 1) * bin ? hi : v_lo + T(k + 1) * bin
        w = bb - a
        if w > zero(T)
            tt = Float64(dt * w / dv)
            if k < 0
                b.bajo += tt
            elseif k >= nb
                b.sobre += tt
            else
                hist[k+1] += tt
            end
        end
    end
    return nothing
end
