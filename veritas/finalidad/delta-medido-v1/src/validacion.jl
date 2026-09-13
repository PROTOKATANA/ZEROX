# validacion.jl — equivalencia referencia/rapido e invariantes del modelo.

"""
    invariantes(llegada, t_creacion) -> Bool

1. Todo nodo recibe todo bloque (red conexa, inundación completa): ninguna entrada Inf.
2. Ningún nodo ve un bloque antes de su creación.
"""
function invariantes(llegada::AbstractMatrix{Float64}, t_creacion::Vector{Float64})
    n, H = size(llegada)
    @inbounds for b in 1:H
        t0 = t_creacion[b]
        for v in 1:n
            isfinite(llegada[v, b]) || return false
            llegada[v, b] >= t0 || return false
        end
    end
    return true
end

"""
    validar_equivalencia(rng, p; n_casos) -> (ok::Bool, detalle::String)

Genera `n_casos` redes aleatorias con `p`, corre referencia y kernel rápido sobre las
mismas entradas y exige igualdad bit a bit de las matrices de llegada más los
invariantes. Devuelve (true, "…") o (false, diagnóstico del caso que falla).
"""
function validar_equivalencia(rng::AbstractRNG, p::ParametrosRed; n_casos::Int = 50)
    for caso in 1:n_casos
        red = construir_red(rng, p)
        t_creacion = calendario_poisson(rng, p.lambda, p.horizonte)
        creador = rand(rng, 1:p.n, length(t_creacion))
        llegada_ref = correr_referencia(red, t_creacion, creador)
        m = MotorRapido(red.g.n; capacidad = 64 + (red.g.n * p.grado + 1) * 16)
        llegada_rapida = correr!(m, red, t_creacion, creador)
        invariantes(llegada_ref, t_creacion) || return false,
            "caso $caso: la referencia viola invariantes"
        invariantes(llegada_rapida, t_creacion) || return false,
            "caso $caso: el kernel rápido viola invariantes"
        llegada_ref == llegada_rapida || return false,
            "caso $caso: matrices de llegada distintas"
        D_ref = deltas_por_bloque(llegada_ref, t_creacion)
        D_rap = deltas_por_bloque(llegada_rapida, t_creacion)
        D_ref == D_rap || return false, "caso $caso: Δ por bloque distintos"
    end
    return true, "equivalencia exacta en $n_casos casos"
end
