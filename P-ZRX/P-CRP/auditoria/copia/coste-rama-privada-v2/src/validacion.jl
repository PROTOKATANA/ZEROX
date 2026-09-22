# validacion.jl — utilidades de validación, comparación MC y controles.

"Intervalo de Wilson para una proporción (nivel `z`). Sin renormalizar nada."
function wilson(exitos::Integer, n::Integer, z::Real=1.96)
    n == 0 && return (0.0, 0.0, 1.0)
    p = exitos / n
    den = 1 + z^2 / n
    centro = (p + z^2 / (2n)) / den
    medio = (z / den) * sqrt(p * (1 - p) / n + z^2 / (4n^2))
    return (p, max(0.0, centro - medio), min(1.0, centro + medio))
end

"""
MC de la probabilidad de superar estrictamente alguna vez hasta `T` para pasos ±1.
Devuelve `(phat, lo, hi, exitos, n)`; un MC ingenuo no certifica eventos 1e-12.
"""
function mc_superar(rng, d::Integer, alpha::Real, T::Integer, nrep::Integer)
    p = 1 - alpha
    q = alpha
    exitos = 0
    for _ in 1:nrep
        D = d
        gano = false
        for _ in 1:T
            if rand(rng) < p
                D += 1
            else
                D -= 1
            end
            if D < 0
                gano = true
                break
            end
        end
        gano && (exitos += 1)
    end
    phat, lo, hi = wilson(exitos, nrep)
    return (phat, lo, hi, exitos, nrep)
end

"""
Toy escalar con `S` flujos de igual tasa y suma íntegra: cada ronda el lado honesto
aporta `+1` con prob `1−α` y el adversario `−S` con prob `α`. La deriva es
`(1−α) − S·α` y la frontera media es `α_drift = 1/(S+1)`.
"""
function prob_superar_toy_S(::Type{T}, alpha::Real, S::Integer, d::Integer, Thorizonte::Integer;
                            tol::Real=1e-14) where {T<:Real}
    return dp_adaptativa(T, d, 1, -S, 1 - T(alpha), T(alpha), Thorizonte;
                         exito=z -> z <= -1, tol=tol, direccion=:arriba)
end

"Deriva `g = S·α − (1−α)` del toy escalar `S` (positiva ⇒ ventaja adversaria)."
toy_S_deriva(alpha::Real, S::Integer) = S * alpha - (1 - alpha)

"""
Escenario estadístico de concurrencia calibrado: corre `nrep` réplicas y publica la
tasa de rojos con IC. Un cero observado a baja carga NO es fallo: se publica el límite
unilateral superior de Wilson, no se exige rojo donde no corresponde.
"""
function tasa_rojos_calibrada(rng_factory, cfg::ConfigSim, nrep::Integer; k::Integer=30)
    total_roj = 0
    total_blo = 0
    n_con_rojo = 0
    for r in 1:nrep
        rng = rng_factory(r)
        res = simular!(cfg, rng; k=k)
        total_roj += res.rojos_publicos
        total_blo += res.total_bloques
        res.rojos_publicos > 0 && (n_con_rojo += 1)
    end
    phat, lo, hi = wilson(n_con_rojo, nrep)
    # tasa = rojos distintos observados / bloques totales de la réplica.
    return (tasa_bloques=total_blo == 0 ? 0.0 : total_roj / total_blo,
            fraccion_replicas_con_rojo=phat, ic=(lo, hi), nrep=nrep)
end

"Comprueba conservación de masa de un `ResultadoDP` con una tolerancia declarada."
function conserva(r::ResultadoDP; tol::Real=1e-12)
    return abs(r.conservacion) <= tol
end

"MC directo de `P(max_i(W_i − d_i) > W_pub)` con `S` ramas iid (±1)."
function mc_max_S(rng, alpha::Real, S::Integer, d::Integer, T::Integer, nrep::Integer)
    p = 1 - alpha
    exitos = 0
    for _ in 1:nrep
        Wpub = 0
        for _ in 1:T
            Wpub += rand(rng) < p ? 1 : -1
        end
        mejor = typemin(Int)
        for _ in 1:S
            W = -d
            for _ in 1:T
                W += rand(rng) < p ? 1 : -1
            end
            mejor = max(mejor, W)
        end
        mejor > Wpub && (exitos += 1)
    end
    return exitos / nrep
end

"""
Estimador por la identidad `1 − E[F_{W}(W_pub)^S]` con `F` la CDF empírica de `W`
(déficit cero, ramas iid). Contraste independiente del MC directo `mc_max_S`.
"""
function identidad_iid_S(rng, alpha::Real, S::Integer, d::Integer, T::Integer,
                         nrep::Integer, nmuestra::Integer)
    p = 1 - alpha
    W_muestra = Vector{Int}(undef, nmuestra)
    for k in 1:nmuestra
        W = 0
        for _ in 1:T
            W += rand(rng) < p ? 1 : -1
        end
        W_muestra[k] = W
    end
    sort!(W_muestra)
    acum = 0.0
    for _ in 1:nrep
        Wpub = 0
        for _ in 1:T
            Wpub += rand(rng) < p ? 1 : -1
        end
        # P(max_i W_i ≤ Wpub + d) = F_emp(Wpub + d); déficit d por rama
        F = searchsortedlast(W_muestra, Wpub + d) / nmuestra
        acum += F^S
    end
    return 1 - acum / nrep
end
