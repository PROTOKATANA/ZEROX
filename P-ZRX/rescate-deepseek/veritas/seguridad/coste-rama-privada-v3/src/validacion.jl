# validacion.jl (v0.3) — utilidades de validación, MC e intervalos.

"Intervalo de Wilson para una proporción (nivel `z`). Sin renormalizar."
function wilson(exitos::Integer, n::Integer, z::Real=1.96)
    n == 0 && return (0.0, 0.0, 1.0)
    p = exitos / n
    den = 1 + z^2 / n
    centro = (p + z^2 / (2n)) / den
    medio = (z / den) * sqrt(p * (1 - p) / n + z^2 / (4n^2))
    return (p, max(0.0, centro - medio), min(1.0, centro + medio))
end

"MC de `P_first_passage(≤T)` para pasos ±1."
function mc_superar(rng, d::Integer, alpha::Real, T::Integer, nrep::Integer)
    p = 1 - alpha; q = alpha
    exitos = 0
    for _ in 1:nrep
        D = d; gano = false
        for _ in 1:T
            D += rand(rng) < p ? 1 : -1
            if D < 0
                gano = true; break
            end
        end
        gano && (exitos += 1)
    end
    phat, lo, hi = wilson(exitos, nrep)
    return (phat, lo, hi, exitos, nrep)
end

"MC de `P_terminal(T)` para pasos ±1 (sin absorción)."
function mc_terminal(rng, d::Integer, alpha::Real, T::Integer, nrep::Integer)
    p = 1 - alpha
    exitos = 0
    for _ in 1:nrep
        D = d
        for _ in 1:T
            D += rand(rng) < p ? 1 : -1
        end
        D < 0 && (exitos += 1)
    end
    phat, lo, hi = wilson(exitos, nrep)
    return (phat, lo, hi, exitos, nrep)
end

"Toy escalar con `S` flujos de suma íntegra: deriva `S·α − (1−α)`, raíz `1/(S+1)`."
function prob_superar_toy_S(::Type{Tnum}, alpha::Real, S::Integer, d::Integer,
                            Thorizonte::Integer; tol::Real=1e-14) where {Tnum<:Real}
    return dp_adaptativa(Tnum, d, 1, -S, 1 - Tnum(alpha), Tnum(alpha), Thorizonte;
                         exito=z -> z <= -1, tol=tol, direccion=:arriba, lo_inicial=-1)
end

"Deriva `g = S·α − (1−α)` del toy escalar."
toy_S_deriva(alpha::Real, S::Integer) = S * alpha - (1 - alpha)

"""
Frontera de deriva del contrafactual aditivo: el factor `S` aparece **solo** aquí,
sustituyendo `c_a·η_a` por `S·c_a·η_a`. Con todo a 1 recupera `α_drift=1/(S+1)`.
"""
function control_escalar_S(alpha::Real, S::Integer; c_h=1.0, c_a=1.0, eta_h=1.0, eta_a=1.0)
    g = S * alpha * c_a * eta_a - (1 - alpha) * c_h * eta_h
    raiz = (c_h * eta_h) / (c_h * eta_h + S * c_a * eta_a)
    return (deriva=g, raiz=raiz, signo=sign(g))
end

"Cotas de unión: `max_i P(E_i) ≤ P(∪E_i) ≤ min(1, Σ_i P(E_i))`."
function cota_union(ps::Vector{Float64})
    isempty(ps) && return (0.0, 0.0)
    return (maximum(ps), min(1.0, sum(ps)))
end

"`S` ramas fijas: cotas de unión a partir de `P_i` por rama."
function ramas_fijas_max(P_i::Vector{Float64})
    lo, hi = cota_union(P_i)
    return (union_inf=lo, union_sup=hi, suma=sum(P_i), S=length(P_i))
end

"`S` ramas aditivas (contrafactual inseguro): masa adversaria total = suma."
ramas_aditivas(alpha::Real, S::Integer) = (cuota_efectiva=S * alpha / (1 - alpha + S * alpha),)

"Conservación de un `ResultadoDP`."
conserva(r::ResultadoDP; tol::Real=1e-12) = abs(r.conservacion) <= tol

"MC directo de `P(max_i(W_i − d) > W_pub)` con `S` ramas iid (±1)."
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

"Identidad `1 − E[F(W_pub+d)^S]` con CDF empírica de `W`."
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
        F = searchsortedlast(W_muestra, Wpub + d) / nmuestra
        acum += F^S
    end
    return 1 - acum / nrep
end

"""
Tasa de rojos calibrada de una réplica v0.3. Un cero observado se publica con límite
unilateral, nunca como fallo.
"""
function tasa_rojos_v3(rng_factory, cfg::ConfigSimV3, nrep::Integer)
    total_roj = 0; total_blo = 0; n_con = 0
    for r in 1:nrep
        res = simular_v3!(cfg, rng_factory(r))
        total_roj += res.rojos
        total_blo += res.total_bloques
        res.rojos > 0 && (n_con += 1)
    end
    phat, lo, hi = wilson(n_con, nrep)
    return (tasa_bloques=total_blo == 0 ? 0.0 : total_roj / total_blo,
            fraccion_reps_con_rojo=phat, ic=(lo, hi), nrep=nrep)
end
