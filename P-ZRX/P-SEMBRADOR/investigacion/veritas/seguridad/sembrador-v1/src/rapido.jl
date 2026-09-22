"""
Evalúa el modelo con una forma estable para probabilidades pequeñas.

Cada intento atómico se puede contrastar contra `w` retos futuros. Bajo independencia,
`q = 1 - (1 - 1/H)^w` es la probabilidad de al menos un acierto y
`mu = w/H` es el número esperado de soluciones. La forma
`-expm1(w*log1p(-1/H))` evita la cancelación de `1 - x` cuando `H` es grande.

El margen usa `mu`: una misma unidad puede producir soluciones pagables en más de un
slot. `q` queda como diagnóstico y sería la magnitud económica si una regla futura
limitase el pago a una sola solución por intento y ventana.
"""
function evaluar_margen(p::ParametrosMargen{T}) where {T}
    adelanto = adelanto_nucleo(p)
    desafios = desafios_conocidos(p)

    probabilidad = if desafios == 0
        zero(T)
    elseif p.espacio_honesto == one(T)
        one(T)
    else
        -expm1(T(desafios) * log1p(-inv(p.espacio_honesto)))
    end
    soluciones = T(desafios) / p.espacio_honesto

    if iszero(soluciones)
        infinito = T(Inf)
        return ResultadoMargen(
            adelanto,
            desafios,
            probabilidad,
            soluciones,
            infinito,
            infinito,
            infinito,
            infinito,
            false,
        )
    end

    intentos_candidato = inv(probabilidad)
    intentos_bloque = inv(soluciones)
    coste_bloque = p.coste_intento * intentos_bloque
    margen = coste_bloque / p.recompensa
    return ResultadoMargen(
        adelanto,
        desafios,
        probabilidad,
        soluciones,
        intentos_candidato,
        intentos_bloque,
        coste_bloque,
        margen,
        margen < one(T),
    )
end

"""Kernel preasignado O(n), con una escritura exclusiva por elemento."""
function barrer!(
    salida::Vector{ResultadoMargen{T}},
    parametros::Vector{ParametrosMargen{T}},
) where {T}
    length(salida) == length(parametros) || throw(DimensionMismatch("longitudes distintas"))
    for i in eachindex(salida, parametros)
        salida[i] = evaluar_margen(parametros[i])
    end
    return salida
end
