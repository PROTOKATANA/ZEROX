# rapido.jl — rutas de producción del instrumento: Float64, sin asignaciones en el bucle,
# funciones tipoestables. Su única obligación es NO cambiar ningún veredicto respecto de
# `Referencia`; eso se comprueba en `test/runtests.jl` y en `validacion.jl`.
#
# `veritas/LINEO.md` §3: sin globales mutables, sin `Any`, sin asignaciones en el bucle.
# NO se usa `@fastmath` (§3.3): el redondeo estándar es parte del contrato.

module Rapido



using ..Modelos: Adaptador, Maquina, MAQUINA_REF, U32_MAX, N_MAX_TIPO, Traza, traza_vacia,
                 tau_objetivo

# ================================================================ F1 · frontera, barrido vectorial
#
# La frontera es una CURVA, no un punto: `S_max(ε, K) = ε·K`. Se barre en `ε` y `K` sin asignar
# dentro del bucle (los resultados van a vectores preasignados).

"""
    barrido_frontera!(S, εs, Ks)

Rellena `S[i, j] = εs[i]·Ks[j]`, la dispersión máxima admisible. `S` preasignada.
"""
function barrido_frontera!(S::AbstractMatrix{Float64}, εs::AbstractVector{Float64},
                           Ks::AbstractVector{Int})
    size(S) == (length(εs), length(Ks)) || throw(ArgumentError("tamaño de S incorrecto"))
    @inbounds for j in eachindex(Ks), i in eachindex(εs)
        S[i, j] = εs[i] * Ks[j]
    end
    return S
end

"""
    barrido_rho_max!(R, εs, Ks)

`ρ_max(ε, K) = ε·K`: la dispersión MAXIMA de hardware que el presupuesto admite. `ρ = t_s/t_f` es
cuántas veces más lenta es la máquina más lenta admitida que la más rápida, o sea la MISMA cantidad
que la frontera `S`, no su recíproca. **La frontera es un techo sobre `ρ`, no un suelo.**
"""
function barrido_rho_max!(R::AbstractMatrix{Float64}, εs::AbstractVector{Float64},
                          Ks::AbstractVector{Int})
    size(R) == (length(εs), length(Ks)) || throw(ArgumentError("tamaño de R incorrecto"))
    @inbounds for j in eachindex(Ks), i in eachindex(εs)
        R[i, j] = εs[i] * Ks[j]
    end
    return R
end

# ================================================================ F2 · adaptador sin asignaciones
#
# Igual que `Modelos.simular!` pero sin la comprobación de longitudes por iteración y con acceso
# `@inbounds`. La justificación de `@inbounds` está en `validacion.jl`: los índices están acotados
# por construcción (`idx = max(s - retardo, 1) ≤ s ≤ T`) y hay un test que lo cubre.

function simular_rapido!(t::Traza, hw::Vector{Float64}, p::Adaptador)
    T = length(hw)
    N = p.N_inicial
    tv = t.tv
    @inbounds begin
        t.N[1] = N
        t.hw[1] = hw[1]
        t.tau[1] = Float64(N) * hw[1]
        t.costo[1] = Float64(N) * tv
        t.ajuste[1] = 0
        for s in 2:T
            idx = s - p.retardo
            idx < 1 && (idx = 1)
            tau_obs = Float64(t.N[idx]) * hw[idx]
            e = tau_objetivo(p) / tau_obs - 1.0
            propuesto = Int64(trunc(N * (1.0 + p.ganancia * e)))
            propuesto = (propuesto ÷ 16) * 16
            propuesto < p.N_min && (propuesto = p.N_min)
            propuesto > p.N_max && (propuesto = p.N_max)
            cambio = propuesto != N && abs(propuesto - N) >= p.paso_minimo
            if !cambio
                t.ajuste[s] = 0
            elseif propuesto < N && p.trinquete
                t.ajuste[s] = 0
            elseif propuesto < N && p.caducidad > 0 && (s - idx) > p.caducidad
                t.ajuste[s] = 0
            else
                t.ajuste[s] = propuesto > N ? Int8(1) : Int8(-1)
                N = propuesto
            end
            t.N[s] = N
            t.hw[s] = hw[s]
            t.tau[s] = Float64(N) * hw[s]
            t.costo[s] = Float64(N) * tv
        end
    end
    return t
end

# ================================================================ F3 · estadísticos de la traza

"""
    extremos_ventana(t, desde, hasta) -> (Nmin, Nmax, amplitud, amplitud_rel)

Extremos de `N` en una ventana de la traza. Sin asignar.
"""
function extremos_ventana(t::Traza, desde::Integer, hasta::Integer)
    (1 <= desde <= hasta <= length(t.N)) || throw(ArgumentError("ventana fuera de la traza"))
    lo = typemax(Int64); hi = typemin(Int64)
    @inbounds for i in desde:hasta
        v = t.N[i]
        v < lo && (lo = v)
        v > hi && (hi = v)
    end
    return lo, hi, hi - lo, Float64(hi - lo) / Float64(hi)
end

"""
    costo_verificacion_maximo(t) -> Float64

Máximo del coste de verificación por slot en la traza (segundos). Es la magnitud que paga el
nodo más lento admitido.
"""
function costo_verificacion_maximo(t::Traza)
    m = 0.0
    @inbounds for v in t.costo
        v > m && (m = v)
    end
    return m
end

# ================================================================ F4 · región de manipulación

"""
    barrido_manipulacion!(M, αs, Ws, δ, φ, τ_obs)

Rellena `M[i, j] = factor de N` (el menor, el del ataque hacia abajo) para `α_i` y `W_j`.
"""
function barrido_manipulacion!(M::AbstractMatrix{Float64}, αs::AbstractVector{Float64},
                              Ws::AbstractVector{Int}, δ::Float64, φ::Float64, τ_obs::Float64)
    size(M) == (length(αs), length(Ws)) || throw(ArgumentError("tamaño de M incorrecto"))
    @inbounds for j in eachindex(Ws), i in eachindex(αs)
        W = Ws[j]
        control = floor(Int, αs[i] * W)
        m = W ÷ 2 + 1
        sesgo = control >= m ? -δ : (control > 0 ? -min(Float64(control), δ) : 0.0)
        M[i, j] = τ_obs / (τ_obs + sesgo)
    end
    return M
end

end # module
