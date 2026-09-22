"""
Parámetros del modelo económico mínimo del sembrador.

Unidades:
- `rho`: aceleración del PoT del adversario, adimensional.
- `L_slots`, `I_slots`, `W_dec_slots`: slots (un slot nominal es un segundo en el
  escenario A″, pero el kernel no mezcla segundos y slots).
- `coste_intento`: coste monetario total de fabricar un registro/pieza dirigido y
  probarlo contra los retos futuros conocidos.
- `recompensa`: valor esperado pagable de una solución válida, es decir, probabilidad
  de pago DAG multiplicada por recompensa nominal.
- `espacio_honesto`: espacio atómico efectivo `H = N_h / lambda_sol`, donde `N_h` es
  el número de registros/piezas honestos y `lambda_sol` la tasa esperada de soluciones
  válidas por slot. Así la probabilidad por unidad y slot es `1/H`. No son bytes sin
  convertir primero el formato, la tasa y el rango de solución.
"""
struct ParametrosMargen{T<:AbstractFloat}
    rho::T
    L_slots::T
    I_slots::T
    W_dec_slots::T
    coste_intento::T
    recompensa::T
    espacio_honesto::T

    function ParametrosMargen(
        rho::T,
        L_slots::T,
        I_slots::T,
        W_dec_slots::T,
        coste_intento::T,
        recompensa::T,
        espacio_honesto::T,
    ) where {T<:AbstractFloat}
        valores = (
            rho,
            L_slots,
            I_slots,
            W_dec_slots,
            coste_intento,
            recompensa,
            espacio_honesto,
        )
        all(isfinite, valores) || throw(ArgumentError("todos los parámetros deben ser finitos"))
        rho > zero(T) || throw(ArgumentError("rho debe ser positivo"))
        L_slots >= zero(T) || throw(ArgumentError("L_slots no puede ser negativo"))
        I_slots >= zero(T) || throw(ArgumentError("I_slots no puede ser negativo"))
        W_dec_slots >= zero(T) || throw(ArgumentError("W_dec_slots no puede ser negativo"))
        coste_intento >= zero(T) || throw(ArgumentError("coste_intento no puede ser negativo"))
        recompensa > zero(T) || throw(ArgumentError("recompensa debe ser positiva"))
        espacio_honesto >= one(T) ||
            throw(ArgumentError("espacio_honesto debe ser al menos una unidad atómica"))

        return new{T}(
            rho,
            L_slots,
            I_slots,
            W_dec_slots,
            coste_intento,
            recompensa,
            espacio_honesto,
        )
    end
end

"""
Resultado condicional. `intentos_esperados_por_candidato` usa `1/q`; el rendimiento de
largo plazo `intentos_esperados_por_bloque` usa `1/E[X]`. Un margen mayor que uno
significa ataque no rentable.
"""
struct ResultadoMargen{T<:AbstractFloat}
    adelanto_slots::T
    desafios_futuros::UInt64
    probabilidad_exito_intento::T
    soluciones_esperadas_por_intento::T
    intentos_esperados_por_candidato::T
    intentos_esperados_por_bloque::T
    coste_esperado_por_bloque::T
    margen_coste_beneficio::T
    rentable::Bool
end

"""
Adelanto estacionario del núcleo R-FIN-14(a-g).

El `-1` representa que la frontera termina en el último slot anterior a la próxima
inyección. Para `rho <= 1` el atacante no alcanza la frontera móvil y no conoce retos
futuros. Este es un modelo de régimen; no incluye el tiempo de bootstrap.
"""
function adelanto_nucleo(p::ParametrosMargen{T}) where {T}
    p.rho <= one(T) && return zero(T)
    adelanto = (p.L_slots - one(T) - p.W_dec_slots) +
        p.I_slots * (one(T) - inv(p.rho))
    return max(zero(T), adelanto)
end

"""Número entero conservador de retos futuros completamente conocidos."""
function desafios_conocidos(p::ParametrosMargen)
    adelanto = adelanto_nucleo(p)
    adelanto <= 0 && return UInt64(0)
    adelanto <= typemax(UInt64) || throw(OverflowError("el adelanto no cabe en UInt64"))
    return UInt64(floor(adelanto))
end
