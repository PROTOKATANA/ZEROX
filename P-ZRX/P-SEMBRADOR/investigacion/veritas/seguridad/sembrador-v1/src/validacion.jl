"""Compara el kernel Float64 con el oráculo BigFloat en una rejilla determinista."""
function validar_referencia(parametros::Vector{ParametrosMargen{Float64}})
    max_error_relativo = 0.0
    campos = (
        :adelanto_slots,
        :probabilidad_exito_intento,
        :soluciones_esperadas_por_intento,
        :intentos_esperados_por_candidato,
        :intentos_esperados_por_bloque,
        :coste_esperado_por_bloque,
        :margen_coste_beneficio,
    )
    for p in parametros
        rapido = evaluar_margen(p)
        referencia = evaluar_referencia(p)

        rapido.desafios_futuros == referencia.desafios_futuros || return false, Inf
        rapido.rentable == referencia.rentable || return false, Inf
        for campo in campos
            valor = getproperty(rapido, campo)
            ref = Float64(getproperty(referencia, campo))
            if isfinite(valor) && isfinite(ref)
                error = abs(valor - ref) / max(abs(ref), eps(Float64))
                max_error_relativo = max(max_error_relativo, error)
            elseif !(isinf(valor) && isinf(ref) && signbit(valor) == signbit(ref))
                return false, Inf
            end
        end
    end
    return max_error_relativo <= 64eps(Float64), max_error_relativo
end
