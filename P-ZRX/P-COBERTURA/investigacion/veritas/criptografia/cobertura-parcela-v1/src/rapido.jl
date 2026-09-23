# rapido.jl — kernel rápido, tipoestable y sin asignaciones.
#
# Diseño para la operación dominante: evaluar la cola hipergeométrica para MUCHOS
# valores de `M` (el barrido en φ) con `N` y `k` fijos. Representación elegida:
#   · tabla de log-factoriales `Vector{Float64}` precalculada una vez (evita `lgamma`
#     repetido y evita `Dict`/`Any`),
#   · bucle interior sobre `j` con acumulador escalar (0 asignaciones),
#   · salida preasignada y escritura por `dest[i]` (una posición exclusiva por celda).
# Esto respeta el orden de columnas y no materializa ninguna matriz.

"""Tabla de log-factoriales `logfact[n+1] = log(n!)`. Inmutable tras construirla."""
struct TablaLogFact
    logfact::Vector{Float64}
    function TablaLogFact(nmax::Integer)
        (nmax >= 1) || throw(ArgumentError("nmax >= 1"))
        v = Vector{Float64}(undef, nmax + 1)
        v[1] = 0.0
        @inbounds for i in 1:nmax
            v[i + 1] = v[i] + log(Float64(i))
        end
        return new(v)
    end
end

"""`log C(n,k)`; `−Inf` fuera de rango. `@inline`, sin asignar."""
@inline function log_binomial(t::TablaLogFact, n::Int, k::Int)
    (k < 0 || k > n) && return -Inf
    @inbounds return t.logfact[n + 1] - t.logfact[k + 1] - t.logfact[n - k + 1]
end

"""
Cola `P(X > B)`, `X ~ Hipergeométrica(N, M, k)`, en `Float64`, para un solo `M`.
Misma fórmula que la referencia exacta; la única diferencia es el redondeo.
"""
function cola_hiper_rapida(t::TablaLogFact, N::Int, M::Int, k::Int, B::Int)
    jmax = min(k, M)
    j0 = max(0, k - (N - M))
    lo = max(B + 1, j0)
    lo > jmax && return 0.0
    logden = log_binomial(t, N, k)
    acc = 0.0
    @inbounds for j in lo:jmax
        lp = log_binomial(t, M, j) + log_binomial(t, N - M, k - j) - logden
        acc += exp(lp)
    end
    # La suma en espacio logarítmico puede exceder 1 en ~1e-8 relativo por redondeo.
    # El valor exacto es una probabilidad ≤ 1: se recorta, y se documenta el supuesto.
    # Un recorte NUNCA cambia un veredicto (no puede convertir 0 en positivo).
    return acc > 1.0 ? 1.0 : acc
end

"""
Barrido vectorizado: evalúa la cola para todos los `M` de `Ms` escribiendo en `dest`.
Preasignado; el bucle interior no asigna. Complejidad `O(length(Ms) · k)`.
"""
function cola_hiper_barrido!(dest::AbstractVector{Float64}, t::TablaLogFact,
                             N::Int, Ms::AbstractVector{Int}, k::Int, B::Int)
    (length(dest) == length(Ms)) || throw(ArgumentError("dest y Ms deben coincidir"))
    logden = log_binomial(t, N, k)
    @inbounds for i in eachindex(Ms)
        M = Ms[i]
        jmax = min(k, M)
        j0 = max(0, k - (N - M))
        lo = max(B + 1, j0)
        if lo > jmax
            dest[i] = 0.0
            continue
        end
        acc = 0.0
        for j in lo:jmax
            lp = log_binomial(t, M, j) + log_binomial(t, N - M, k - j) - logden
            acc += exp(lp)
        end
        dest[i] = acc > 1.0 ? 1.0 : acc
    end
    return dest
end

"""
Barrido en φ: para cada fracción almacenada `phi`, `M = round((1−φ)·N)`.
Escribe la cola exacta-redondeada y, si `Ms` se pide, también los `M` usados.
"""
function barrido_phi!(dest::AbstractVector{Float64}, Ms::AbstractVector{Int},
                      t::TablaLogFact, N::Int, phis::AbstractVector{Float64},
                      k::Int, B::Int)
    (length(dest) == length(phis) == length(Ms)) || throw(ArgumentError("longitudes"))
    @inbounds for i in eachindex(phis)
        Ms[i] = max(0, min(N, round(Int, (1.0 - phis[i]) * N)))
    end
    return cola_hiper_barrido!(dest, t, N, Ms, k, B)
end
