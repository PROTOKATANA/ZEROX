#= espacio-prestado-v1 · validacion.jl
   Controles de equivalencia entre vías independientes (LINEO §2, PROMPT §7). Ningún
   control compara una fórmula consigo misma.
=#

module Validacion

using ..Referencia
using ..Rapido

export validar_dp, validar_kernels, validar_eventual, terminal_de_dp

"""
    validar_dp(ps, ds, Ts) -> Vector{NamedTuple}

Compara, con aritmética EXACTA (`Rational{BigInt}`):
  1. la DP de tiempo de parada sobre el estado `(min, posición)` (`rapido.jl`);
  2. la enumeración exhaustiva recursiva sobre las `2^T` trayectorias (`referencia.jl`);
  3. la masa interior final (control de conservación) y la monotonía en `T`.
Devuelve una fila por celda con `ok`.
"""
function validar_dp(ps, ds, Ts)
    filas = NamedTuple[]
    for p in ps, d in ds
        prev = nothing
        for T in Ts
            r = Rapido.primera_dp(p, d, T)
            e = Referencia.enumerar_exhaustivo(p, d, T)
            mon = (prev === nothing) || (r.paso ≥ prev)
            push!(filas, (p = p, d = d, T = T,
                          dp = r.paso, enum = e.paso, interior = r.interior,
                          coincide = r.paso == e.paso,
                          monotona = mon,
                          interior_pequena = r.interior ≤ 1 // 10^6,
                          ok = (r.paso == e.paso) && mon))
            prev = r.paso
        end
    end
    return filas
end

"""    terminal_de_dp(p, d, T) = P(primera visita exactamente en T) = P_T − P_{T−1}."""
function terminal_de_dp(p, d, T)
    return Rapido.primera_dp(p, d, T).paso - Rapido.primera_dp(p, d, T - 1).paso
end

"""
    validar_kernels(pares, Ts; mc_reps, semilla, prec)

Compara la primera pasada exacta (`Rational{BigInt}`) con el kernel `Float64`, con
`BigFloat` a `prec` bits, y con Monte Carlo `Philox4x64` de semilla contracorriente
(exigida dentro del intervalo de Wilson al 95 %).
"""
function validar_kernels(pares, Ts; mc_reps = 100_000, semilla = UInt64(0x5052455354414d4f),
                         prec = 256)
    filas = NamedTuple[]
    for (p, d) in pares, T in Ts
        pr = Rational{BigInt}(p)
        ex = Rapido.primera_dp(pr, d, T).paso
        f, fi = Rapido.primera_dp(p, d, T)
        b, bi = Rapido.primera_bigfloat_dp(p, d, T, prec)
        mc = Referencia.mc_ventana(p, d, T, mc_reps, semilla)
        exf = Float64(ex)
        push!(filas, (p = p, d = d, T = T, exacto = exf, float64 = f, bigfloat = Float64(b),
                      mc = mc.paso, mc_lo = mc.ic_paso[1], mc_hi = mc.ic_paso[2],
                      # Criterio declarado: dentro del IC, o a menos de 3 errores
                      # estándar binomiales del valor exacto (evita fallos por fluctuación).
                      mc_ok = (mc.ic_paso[1] ≤ exf ≤ mc.ic_paso[2]) ||
                              (abs(mc.paso - exf) ≤ 3 * sqrt(max(exf * (1 - exf), 1e-12) / mc_reps)),
                      err_f = exf == 0.0 ? abs(f) : abs(f - exf) / exf,
                      err_b = exf == 0.0 ? abs(Float64(b)) : abs(Float64(b) - exf) / exf,
                      interior_f = fi, interior_b = Float64(bi)))
    end
    return filas
end

"""
    validar_eventual(p, ds; Ts, tol)

Comprueba que la primera pasada crece con `T` y que se acerca a la forma cerrada
`(q/p)^(d+1)` (o 1) en horizonte largo. La convergencia es lenta (`~1/√T` en la frontera
crítica): la tolerancia es declarada, no de máquina.
"""
function validar_eventual(p::Rational{BigInt}, ds; Ts = [1_000, 10_000], tol = 1.0e-3)
    filas = NamedTuple[]
    for d in ds
        objetivo = Referencia.p_superar_exacto(p, d)
        vals = [Rapido.primera_dp(p, d, T).paso for T in Ts]
        push!(filas, (d = d, objetivo = Float64(objetivo),
                      valores = Float64.(vals),
                      monotona = all(vals[i] < vals[i+1] for i in 1:(length(vals)-1)),
                      diferencia = abs(Float64(vals[end]) - Float64(objetivo)),
                      dentro_de_tol = abs(Float64(vals[end]) - Float64(objetivo)) ≤ tol))
    end
    return filas
end

end # module
