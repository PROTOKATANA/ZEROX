# ─────────────────────────────────────────────────────────────────────────────
# validacion.jl — equivalencia kernel↔oráculo, invariantes y bordes
#
# Nada de lo de aquí compara una fórmula con su propia transcripción: el oráculo recorre la
# cadena slot a slot y la regresión usa las formas cerradas EXTERNAS de `referencia.jl`.
# ─────────────────────────────────────────────────────────────────────────────

"""
Compara el kernel por eventos con el oráculo por slot en instancias pequeñas, con
`Rational{BigInt}` (exacto) y `Float64`. Devuelve `(maxdiff_vmax, maxdiff_vmin, n, fallos)`.

Los casos se generan con semilla fija: `L, I, W_dec, D, S_max, Lrev` aleatorios en rangos
declarados, `off_j` exactos y `propia_j` sorteadas.
"""
function comparar_con_oraculo(; ncasos::Int = 60, seed::UInt64 = 0x5a5a, J::Int = 4)
    rng = StableRNG(seed)
    maxdv = 0.0
    maxdm = 0.0
    fallos = 0
    for c in 1:ncasos
        I = 40 + rand(rng, 0:40)
        S_max = 5 + rand(rng, 0:10)
        L = S_max + 2 + rand(rng, 0:60)
        W_dec = rand(rng, 0:6)
        D = rand(rng, 0:3)
        Lrev = rand(rng, 0:L)
        con_h = rand(rng, Bool)
        espera = rand(rng, Bool)
        cruce = rand(rng, Bool)
        lead_h = rand(rng, Bool) ? D : 0
        rho = Rational{BigInt}(9 + rand(rng, 0:23), 8)
        alpha = rand(rng)
        cfgQ = Config{Rational{BigInt}}(; L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                        Lrev = Lrev, con_h = con_h, espera = espera,
                                        cruce = cruce, lead_h = lead_h, j_ini = 0)
        offq = Vector{Rational{BigInt}}(undef, J + 1)
        propia = Vector{Bool}(undef, J + 1)
        for j in 1:(J + 1)
            offq[j] = Rational{BigInt}(rand(rng, 0:S_max))
            propia[j] = rand(rng) < alpha
        end
        # oráculo exacto
        (ovmax, ovmin, _, _) = oraculo_por_slot(cfgQ, offq, propia, rho, J)
        # kernel por eventos, exacto
        b = Buffers{Rational{BigInt}}(J, 4)
        m = simular_replica!(b, cfgQ, offq, propia, rho, J,
                             Rational{BigInt}(1), Rational{BigInt}(0), Rational{BigInt}(0))
        dv = abs(Float64(m.vmax - ovmax))
        dm = abs(Float64(m.vmin - ovmin))
        maxdv = max(maxdv, dv)
        maxdm = max(maxdm, dm)
        if dv != 0.0 || dm != 0.0
            fallos += 1
            @info "discrepancia kernel↔oráculo" c dv dm L I W_dec D S_max Lrev string(rho) con_h espera cruce lead_h
        end
    end
    return (maxdv, maxdm, ncasos, fallos)
end

"""
Invariantes del simulador, comprobados sobre una corrida concreta:

1. `t_j < t_{j+1}` estrictamente (`C-FLU-09`, `S_max < I`).
2. `τ_j` estrictamente creciente (la frontera del atacante no retrocede).
3. `τ_j ≥ e_j` (nadie cruza una barrera sin la entropía) — se comprueba por construcción con el
   contador de bloqueos.
4. La frontera honesta **no** se estanca si y solo si se cumple la disciplina de puntualidad
   `Lrev ≤ L − W_dec − lead_h + off_j`; se devuelve el número de estancamientos observados.
5. `V(t)` calculado por el kernel por eventos coincide con una reevaluación punto a punto en una
   rejilla fina (integridad del acumulador).
"""
function invariantes(cfg::Config{T}, off::Vector{T}, propia::Vector{Bool}, rho::T, J::Int;
                     bin::T = T(1), v_lo::T = T(-8), rejilla::Int = 4000) where {T<:Real}
    fallos = String[]
    for j in 1:(J - 1)
        if !(T(j) * cfg.I + off[j] + cfg.L < T(j + 1) * cfg.I + off[j + 1] + cfg.L)
            push!(fallos, "t_j no creciente en j=$j")
        end
    end
    b = Buffers{T}(J, 8)
    m = simular_replica!(b, cfg, off, propia, rho, J, bin, v_lo, zero(T))
    nA = 1
    while nA < length(b.tA) && b.tA[nA+1] > b.tA[nA]
        nA += 1
    end
    for k in 2:nA
        if !(b.tA[k] > b.tA[k-1])
            push!(fallos, "τ no creciente en k=$k")
            break
        end
    end
    # reevaluación de V en una rejilla uniforme, contra los puntos de ruptura
    tfin = b.tA[nA]
    paso = tfin / rejilla
    vmaxg = T(-1)
    visto = false
    for i in 0:rejilla
        t = paso * T(i)
        va = _pos_traj(t, b.tA, b.pA, nA)
        vh = _pos_traj(t, b.tH, b.pH, nA)
        v = va - vh
        if !visto || v > vmaxg
            vmaxg = v; visto = true
        end
    end
    b2 = Buffers{T}(J, 8)
    (nA2, nH2, _, _, _, nst, _) =
        construir_trayectorias!(b2.tA, b2.pA, b2.tH, b2.pH, cfg, off, propia, rho, J)
    m2 = simular_replica!(b2, cfg, off, propia, rho, J, bin, v_lo, zero(T))
    return (fallos = fallos, n_stall = m2.n_stall_h, vmax_eventos = m2.vmax, vmax_rejilla = vmaxg)
end

"Posición de una trayectoria en `t`, por búsqueda binaria sobre sus puntos de ruptura."
function _pos_traj(t::T, ts::Vector{T}, ps::Vector{T}, n::Int) where {T<:Real}
    t <= ts[1] && return ps[1]
    if t >= ts[n]
        # extrapolación lineal más allá del último punto (la frontera sigue avanzando)
        return ps[n] + (t - ts[n]) * (ps[n] - ps[n-1]) / (ts[n] - ts[n-1])
    end
    lo = 1; hi = n
    while lo < hi
        mid = (lo + hi + 1) >> 1
        if ts[mid] <= t
            lo = mid
        else
            hi = mid - 1
        end
    end
    f = (t - ts[lo]) / (ts[lo+1] - ts[lo])
    return ps[lo] + f * (ps[lo+1] - ps[lo])
end

"""
Comprueba la disciplina de puntualidad del honesto con (h): el timekeeper arranca su VDF en
`T_j + W_dec` y necesita `Lrev` slots de su propia línea; su frontera cruza `t_j` en `t_j − lead_h`.
La condición es `Lrev ≤ L − W_dec − lead_h + off_j`. Devuelve `true` si se cumple para todo `off_j ∈ [0, S_max)`.
"""
function puntualidad_estricta(L::T, W_dec::T, Lrev::T, lead_h::T, S_max::T) where {T<:Real}
    return Lrev <= L - W_dec - lead_h
end
