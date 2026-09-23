#=  rapido.jl — kernel Float64 para el barrido en `c`.

Misma ecuación (39) que `modelo.jl`, resuelta en `Float64` por bisección con horquilla
exponencial. Se usa SÓLO para tablas y barridos; **todo veredicto se certifica con el recinto
`BigFloat`** de `modelo.jl`. La equivalencia kernel↔referencia se comprueba en `validacion.jl`
(`oraculo_kernel`), no se supone.
=#

"Residuo de (39) en Float64."
@inline f39_f64(c::Integer, t::Float64) = -log(-t) - (c - 1) * log(1 - t) + 1 - (c - 1) * t / (1 - t)

"Raíz negativa de (39) en Float64."
function theta_f64(c::Integer)
    c >= 1 || throw(ArgumentError("c ≥ 1"))
    hi = -1.0e-9
    n = 0
    while f39_f64(c, hi) <= 0
        hi /= 2
        n += 1
        (n > 400 || hi == 0.0) && error("sin cota superior (c=$c)")
    end
    lo = -1.0
    n = 0
    while f39_f64(c, lo) >= 0
        lo *= 2
        n += 1
        (n > 4000 || !isfinite(lo)) && error("sin cota inferior (c=$c)")
    end
    for _ in 1:200
        mid = (lo + hi) / 2
        if (f39_f64(c, mid) > 0) == (f39_f64(c, lo) > 0)
            lo = mid
        else
            hi = mid
        end
    end
    return (lo + hi) / 2
end

"`phi_c` en Float64."
function phi_c_f64(c::Integer)
    t = theta_f64(c)
    return -c * t / (log(-t) + (c - 1) * log(1 - t))
end

"`umbral_c = 1/(1+phi_c)` en Float64, retardo nulo."
umbral_c_f64(c::Integer) = 1 / (1 + phi_c_f64(c))

"`umbral_d` en Float64 (`d = D_INF` → 1/2)."
umbral_d_f64(d::Integer) = d == D_INF ? 0.5 : umbral_c_f64(d + 1)
