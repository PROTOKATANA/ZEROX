# ─────────────────────────────────────────────────────────────────────────────
# referencia.jl — oráculo independiente y exacto para trazas pequeñas.
#
# Dos piezas, deliberadamente distintas del kernel de `rapido.jl`:
#   1. `tau_maxplus`: forma cerrada max-plus de la recursión de barrera, resuelta
#      por iteración de punto fijo monotona en `Rational{BigInt}`. No recorre los
#      puntos de ruptura: desenrolla la recursión como un máximo sobre épocas.
#   2. `ventana_exacta` / `tiempo_bajo_exacto` / `cuantil_exacto`: integración
#      exacta por tramos lineales en `Rational{BigInt}` (sin bins).
# ─────────────────────────────────────────────────────────────────────────────

"""
Forma cerrada max-plus de la recursión de barrera, **sin** recorrer puntos de ruptura.

Con `τ_j = máx(τ_{j-1} + (t_j − 1 − t_{j-1})/ρ, e_j) + 1/ρ` y frontera inicial en
`lead_h` a tiempo 0 (`t_0 := lead_h`, `τ_0 := 0`):

    τ_j = máx( (t_j − lead_h)/ρ ,
               máx_{1≤k≤j} [ e_k + (t_j − t_k)/ρ + 1/ρ ] )

(el `−1` discreto y el `1/ρ` del cruce se cancelan en el tramo libre: recorrer una
época cuesta `(t_j − t_{j−1})/ρ`). Sin coste de cruce (`cruce = false`) el `−1` de
cada barrera intermedia sí acumula:

    τ_j = máx( (t_j − j − lead_h)/ρ , máx_k [ e_k + (t_j − t_k − (j − k))/ρ ] )
`e_k` depende de la trayectoria, así que se resuelve por **punto fijo monotono**:
se arranca de `e_k = cota inferior` y se itera hasta que `τ` no cambia. Devuelve el
vector de instantes de cruce `τ_1…τ_J` (exacto).
"""
function tau_maxplus(cfg::Cfg{Rational{BigInt}}, off::AbstractVector, propia::AbstractVector{Bool},
                     rho::Rational{BigInt}, J::Int)
    R = Rational{BigInt}
    ir = 1 // rho
    tbar = Vector{R}(undef, J)                                      # tbar[j] = t_j (época j)
    for j in 1:J
        tbar[j] = R(j) * R(cfg.I) + R(off[j]) + R(cfg.L)
    end
    # cota inferior inicial de e_k: el ancla no existe antes de s_k
    e = R[propia[k] ? R(0) : R(k) * R(cfg.I) + R(off[k]) + (cfg.espera ? R(cfg.W_dec) : R(0))
          for k in 1:J]
    tau = fill(R(0), J)
    for _ in 1:(4J + 16)
        # τ_j por la forma cerrada max-plus, con los e actuales
        for j in 1:J
            m = cfg.cruce ? (tbar[j] - R(cfg.lead_h)) * ir :
                            (tbar[j] - R(j) - R(cfg.lead_h)) * ir
            for k in 1:j
                v = e[k] + (tbar[j] - tbar[k]) * ir
                v += cfg.cruce ? ir : R(-(j - k)) * ir
                v > m && (m = v)
            end
            tau[j] = m
        end
        # recomputar e_k a partir de la trayectoria τ (tiempo de paso por s_k + D o s_k)
        cambiado = false
        libres = fill(R(0), cfg.lineas_revelacion)
        for k in 1:J
            sk = R(k) * R(cfg.I) + R(off[k])
            x = propia[k] ? (cfg.semilla_futura ? sk + R(cfg.D) : sk) : sk
            tp = _tiempo_paso_ref(tbar, tau, cfg, rho, x)
            if !propia[k] && tp < sk
                tp = sk          # el bloque de un ancla ajena no existe antes de su slot
            end
            decision = tp + ((!propia[k] && cfg.espera) ? R(cfg.W_dec) : R(0))
            e_new = cfg.con_h && cfg.revelacion_instantanea ? max(decision, tp) : decision
            if cfg.con_h && !cfg.revelacion_instantanea
                if cfg.revelacion_paralela
                    linea = 1
                    comienzo = max(tp, libres[1])
                    for l in 2:length(libres)
                        candidato = max(tp, libres[l])
                        if candidato < comienzo
                            linea = l
                            comienzo = candidato
                        end
                    end
                    fin = comienzo + R(cfg.Lrev) * ir
                    libres[linea] = fin
                    e_new = max(decision, fin)
                else
                    e_new = max(decision, tp) + R(cfg.Lrev) * ir
                end
            end
            if e_new > e[k]
                e[k] = e_new
                cambiado = true
            end
        end
        cambiado || break
    end
    return tau
end

"""
Tiempo en que la frontera del atacante (dada por `tbar`/`tau`) pasó el slot `x`,
en exacto. Dentro de la época `k` la frontera avanza a tasa `ρ` desde `t_{k-1}` en
`τ_{k-1}`; si `x` cae en un tramo de espera (posición constante), se devuelve el
instante de reanudación.
"""
function _tiempo_paso_ref(tbar::Vector{R}, tau::Vector{R}, cfg::Cfg{R}, rho::R, x::R) where {R}
    ir = 1 // rho
    lead = R(cfg.lead_h)
    if x <= lead
        return R(0)
    end
    J = length(tbar)
    for k in 1:J
        if x <= tbar[k]
            x_lo = k == 1 ? lead : tbar[k-1]
            tau_prev = k == 1 ? R(0) : tau[k-1]
            if x <= tbar[k] - 1
                return tau_prev + (x - x_lo) * ir
            else
                # slot de barrera: cruza en tau[k] (o τ_{k-1} + (t_k−1−x_lo)/ρ si esperó)
                return tau[k]
            end
        end
    end
    return tau[J] + (x - tbar[J]) * ir
end

"Ventana exacta (`vmax`, `vmin`, media temporal, `vfin`) con `Rational{BigInt}`."
function ventana_exacta(cfg::Cfg{Rational{BigInt}}, off::AbstractVector, propia::AbstractVector{Bool},
                        rho::Rational{BigInt}, J::Int; j_ini::Int = 0)
    R = Rational{BigInt}
    tr = Tray{R}(J)
    construir!(tr, cfg, off, propia, rho, J)
    t_ini = R(j_ini) * R(cfg.I)
    t_fin = tr.tA[tr.nA]
    return extremos!(tr, t_ini, t_fin)
end

"""
Tiempo exacto (en slots) con `V(t) ≤ v` dentro de `[t_ini, t_fin]`, por tramos
lineales. Es la función monótona con la que se obtienen cuantiles **exactos**.
"""
function tiempo_bajo_exacto(tr::Tray{R}, v::R, t_ini::R, t_fin::R) where {R<:Real}
    tA = tr.tA; pA = tr.pA; tH = tr.tH; pH = tr.pH; evt = tr.evt
    nA = tr.nA; nH = tr.nH
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
    total = zero(R); pa = 1; ph = 1
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
        vv = va - vh
        if t >= t_ini
            if tprev < t_ini
                f = (t_ini - tprev) / (t - tprev)
                vprev = vprev + f * (vv - vprev)
                tprev = t_ini
            end
            dt = t - tprev
            if dt > zero(R)
                total += _tiempo_rampa_bajo(vprev, vv, dt, v)
            end
        end
        tprev = t; vprev = vv
        ultimo && break
    end
    return total
end

"Tiempo de un tramo lineal donde `V ∈ [v0, v1]` que cae por debajo de `v` (exacto)."
@inline function _tiempo_rampa_bajo(v0::R, v1::R, dt::R, v::R) where {R<:Real}
    if v0 == v1
        return v0 <= v ? dt : zero(R)
    end
    lo = v0 < v1 ? v0 : v1
    hi = v0 < v1 ? v1 : v0
    lo > v && return zero(R)
    hi <= v && return dt
    # fracción del tramo con V ≤ v (V monótona en el tramo)
    frac = (v - lo) / (hi - lo)
    return dt * frac
end

"""
Cuantil exacto `q` de la masa de tiempo de `V` en `[t_ini, t_fin]` por bisección
sobre `tiempo_bajo_exacto`. Devuelve el menor `v` (en la rejilla racional de la
bisección) con `tiempo_bajo ≥ q·Δ`. `iter` controla la precisión.
"""
function cuantil_exacto(tr::Tray{R}, q::Float64, t_ini::R, t_fin::R, lo::R, hi::R;
                        iter::Int = 60) where {R<:Real}
    Δ = t_fin - t_ini
    for _ in 1:iter
        mid = (lo + hi) / 2
        if tiempo_bajo_exacto(tr, mid, t_ini, t_fin) >= R(q) * Δ
            hi = mid
        else
            lo = mid
        end
    end
    return hi
end
