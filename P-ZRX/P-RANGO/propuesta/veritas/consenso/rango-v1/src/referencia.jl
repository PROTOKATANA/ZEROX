# referencia.jl — oráculo pequeño, transparente y exacto (LINEO §1 y §2 paso 1).
#
# Todo aquí usa BigInt / Rational{BigInt} y bucles explícitos. No se optimiza: es la fuente de
# verdad contra la que se valida el kernel de `rapido.jl`.

"""
    distancia_bidireccional(a, b, m)

Distancia sobre el círculo de `m` puntos, leída del predicado real
(`PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs:332-337`, citado en
PCO-v0.1 `MODELO.md:20-26`): `min(|a−b|, m − |a−b|)`. Prohibida la resta directa con signo.
"""
function distancia_bidireccional(a::Integer, b::Integer, m::Integer)
    d = abs(a - b)
    return min(d, m - d)
end

"""
    A_sr_enumerado(sr, m)

Oráculo **independiente** de `A_sr`: cuenta por fuerza bruta cuántos `d ∈ 0:m-1` cumplen
`distancia_bidireccional(d, 0, m) <= sr ÷ 2`. Para `sr < m` debe coincidir con `A_sr(sr)`.
"""
function A_sr_enumerado(sr::Integer, m::Integer)
    limite = fld(sr, 2)
    n = 0
    for d in 0:(m - 1)
        if distancia_bidireccional(d, 0, m) <= limite
            n += 1
        end
    end
    return n
end

"""
    razon_producto(sr)

Forma «producto» de la tasa, sin usar `razon_ref` (que es idéntica): `A(sr)·w(sr)/2^128` con
`A` y `w` calculados a mano. Sirve para contrastar la forma cerrada.
"""
function razon_producto(sr::Integer)
    a = iseven(sr) ? big(sr) + 1 : big(sr)          # A(sr) escrito a mano
    w = fld(DOS128, big(sr) + 1)
    return (a * w) // DOS128
end

"""
    controlador_ref(r, n, c)

Controlador de rango exacto en `BigInt`, paso a paso y sin atajos. Devuelve
`(rango_siguiente, clamped, r_raw, r_par)`. `n == 0` es la política **Z0**: no-op, no se agenda
propuesta (RCE-v0.1 `ENMIENDA-Z0.md`).
"""
function controlador_ref(r::Integer, n::Integer, c::ConfigControlador)
    n >= 0 || throw(DomainError(n, "N_j negativo"))
    n == 0 && return (big(r), false, big(r), big(r))
    rango = big(r)
    num = rango * ((big(c.ganancia_den) - c.ganancia_num) * n + big(c.ganancia_num) * c.q)
    den = big(c.ganancia_den) * n
    r_raw = divide_round_half_even(num, den)
    r_par = rejilla_par(r_raw)
    lo = cota_par_inferior(rango * c.paso_lo_num, c.paso_lo_den)
    hi = cota_par_superior(rango * c.paso_hi_num, c.paso_hi_den)
    step = clamp(r_par, lo, hi)
    out = clamp(step, big(c.sr_min), big(c.sr_max))
    return (out, out != r_raw, r_raw, r_par)
end

"""
    activacion_ref(corte, sello, c)

Primera frontera estrictamente posterior al corte más el retardo en cohortes, como en RCE-v0.1
`src/controlador.jl:45-48`: `b = (⌊corte/W⌋+1)·W`, `A = b + (D−1)·W`. Si el sello es `>= A`, la
actualización se pierde (`MissedUpdate`) y el rango se mantiene: nunca se activa retroactivamente.
"""
function activacion_ref(corte::Integer, sello::Integer, c::ConfigControlador)
    w = big(c.w_slots)
    b = (fld(corte, w) + 1) * w
    a = b + (big(c.retardos_ventana) - 1) * w
    return a, sello < a
end
