"""
Oráculo BigFloat directo. Mantiene separada la fórmula transparente de la evaluación
estable usada por el kernel rápido.
"""
function evaluar_referencia(p::ParametrosMargen; precision::Int = 256)
    precision >= 128 || throw(ArgumentError("la referencia exige al menos 128 bits"))

    return setprecision(BigFloat, precision) do
        rho = BigFloat(p.rho)
        L_slots = BigFloat(p.L_slots)
        I_slots = BigFloat(p.I_slots)
        W_dec_slots = BigFloat(p.W_dec_slots)
        coste = BigFloat(p.coste_intento)
        recompensa = BigFloat(p.recompensa)
        espacio = BigFloat(p.espacio_honesto)

        adelanto = if rho <= 1
            BigFloat(0)
        else
            max(BigFloat(0), (L_slots - 1 - W_dec_slots) + I_slots * (1 - inv(rho)))
        end
        adelanto <= typemax(UInt64) || throw(OverflowError("el adelanto no cabe en UInt64"))
        desafios = UInt64(floor(adelanto))

        probabilidad = if desafios == 0
            BigFloat(0)
        elseif espacio == 1
            BigFloat(1)
        else
            1 - (1 - inv(espacio))^desafios
        end
        soluciones = BigFloat(desafios) / espacio

        if iszero(soluciones)
            infinito = BigFloat(Inf)
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
        coste_bloque = coste * intentos_bloque
        margen = coste_bloque / recompensa
        return ResultadoMargen(
            adelanto,
            desafios,
            probabilidad,
            soluciones,
            intentos_candidato,
            intentos_bloque,
            coste_bloque,
            margen,
            margen < 1,
        )
    end
end
