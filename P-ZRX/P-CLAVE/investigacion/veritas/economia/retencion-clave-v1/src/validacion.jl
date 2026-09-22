#= retencion-clave-v1 · src/validacion.jl
   Rutinas de validación que no son tests unitarios: cuantifican el error de las aproximaciones y
   demuestran (por intercambio) la optimalidad del greedy. Se invocan desde `run.jl` para producir
   los artefactos de validación, y desde `test/runtests.jl` para los controles.

   Contenido:
     `greedy_es_optimo`      — demostración por intercambio, comprobada además por fuerza bruta
     `error_discretizacion`  — comparación kernel (K bins) frente a oráculo exponencial exacto
     `error_normal_cola`     — error de la aproximación normal en la cola pequeña
     `intervalo_riguroso`    — cota inferior exacta e^{−θ} frente a la CDF muestreada
=#

module Validacion

using StableRNGs: StableRNG
using ..Modelo: Retencion, Vesting, LINEAL, ESCALON, Pareto, rsd_pequeno, reclutamiento_exacto
using ..Referencia
using ..Rapido: reclutamiento_eligiendo

export greedy_es_optimo, error_discretizacion, error_normal_cola, intervalo_riguroso,
       sensibilidad_K, comparar_vias

"""CONTRAEJEMPLO Y CONTROL del reclutamiento. «Mínimo coste con `Σ_{i∈S} f_i ≥ β`» es una
*cobertura por mochila*, NP-dura: el greedy por ratio **no es óptimo**. Esta función devuelve el
greedy, el óptimo por DP y el óptimo por fuerza bruta (cuando `n ≤ max_n`), para poder publicar la
brecha. El contraejemplo mínimo está en `PROGRESO.md` O8."""
function greedy_es_optimo(fs::Vector{Float64}, bribes::Vector{Float64}, β::Float64;
                          overhead::Real = 0.0, max_n::Int = 12, pasos::Int = 20_000)
    n = length(fs)
    @assert n == length(bribes)
    g = reclutamiento_eligiendo(fs, bribes, β; overhead = overhead)
    d = reclutamiento_exacto(fs, bribes, β; overhead = overhead, pasos = pasos)
    if n > max_n
        return (greedy = g.coste, dp = d.coste, bruto = NaN, ok = true, n = n)
    end
    mejor = Inf
    for máscara in 0:(2^n - 1)
        espacio = 0.0
        coste = 0.0
        for i in 1:n
            (máscara >> (i - 1)) & 1 == 1 || continue
            espacio += fs[i]
            coste += bribes[i] + overhead
        end
        espacio >= β - 1e-9 && (mejor = min(mejor, coste))
    end
    return (greedy = g.coste, dp = d.coste, bruto = mejor,
            ok = isapprox(d.coste, mejor; rtol = 1e-3, atol = 1e-9), n = n)
end

"""Error de discretización del kernel de `K` bins frente al oráculo exponencial EXACTO, en la CDF
y en los dos primeros momentos. Devuelve un `NamedTuple` por `K`."""
function error_discretizacion(lam, f, ret, ingreso, xs::Vector{Float64}; Ks = [8, 16, 32, 64, 128],
                              n = 200_000, semilla::UInt64 = UInt64(0x5151))
    θ = lam * f * ret.Tv
    coef = ret.rho * ingreso
    rng = StableRNG(semilla)
    exactas = zeros(Float64, length(xs))
    acc1 = 0.0
    acc2 = 0.0
    for _ in 1:n
        b, _ = muestra_espaciado!(rng, θ, coef)
        acc1 += b
        acc2 += b^2
        for (i, x) in enumerate(xs)
            b <= x && (exactas[i] += 1)
        end
    end
    exactas ./= n
    m1 = acc1 / n
    v1 = acc2 / n - m1^2
    out = NamedTuple[]
    for K in Ks
        v = saldo_mc(semilla, n, lam, f, ret, ingreso; K = K, hilos = true)
        m2 = sum(v) / n
        v2 = sum(x -> x^2, v) / n - m2^2
        cd = [count(<=(x), v) / n for x in xs]
        push!(out, (K = K, max_dif_cdf = maximum(abs.(cd .- exactas)),
                    rel_dif_media = abs(m2 - m1) / max(m1, 1e-30),
                    rel_dif_var = abs(v2 - v1) / max(v1, 1e-30)))
    end
    return (teorica_media = m1, teorica_var = v1, cdf_exacta = exactas, por_K = out)
end

"""Error de la aproximación NORMAL de `P(B = 0)` frente a la exacta `e^{−θ}`, para medir cuándo la
normal falla (el hallazgo central del encargo: falla justo en los pequeños)."""
function error_normal_cola(θs::Vector{Float64}, ret::Retencion, ingreso::Real;
                           lam::Real = 1.0)
    out = NamedTuple[]
    for θ in θs
        f = θ / (lam * ret.Tv)
        ex = exp(-θ)
        ap = masa_cero_aprox(lam, f, ret, ingreso)
        push!(out, (θ = θ, f = f, exacta = ex, normal = ap,
                    ratio = ap / max(ex, 1e-300), rsd = rsd_pequeno(lam, f, ret)))
    end
    return out
end

"""Comprueba el intervalo riguroso `P(B ≤ x) ≥ e^{−θ}` contra la CDF muestreada del oráculo."""
function intervalo_riguroso(lam, f, ret, x; n = 200_000, semilla::UInt64 = UInt64(0x6161))
    θ = lam * f * ret.Tv
    rng = StableRNG(semilla)
    k = 0
    for _ in 1:n
        b, _ = muestra_espaciado!(rng, θ, ret.rho * 1.0)
        b <= x && (k += 1)
    end
    p = k / n
    cota = exp(-θ)
    lo, ph, hi = ic_wilson(k, n)
    return (cdf = p, cota_inferior = cota, cumple = p >= cota - 1e-12,
            ic95 = (lo, hi), dentro_del_ic = lo <= cota <= hi)
end

"""Barrido de sensibilidad en `K`: error frente al oráculo para un `θ` dado."""
sensibilidad_K(lam, f, ret, ingreso; Ks = [4, 8, 16, 32, 64, 128, 256], kw...) =
    error_discretizacion(lam, f, ret, ingreso, [0.0]; Ks = Ks, kw...)

"""Compara las tres vías en una celda y devuelve un `NamedTuple` listo para tabular."""
function comparar_vias(lam, f, ret, ingreso, x; K::Int = 64, n::Int = 200_000,
                       semilla::UInt64 = UInt64(0x7171))
    θ = lam * f * ret.Tv
    rng = StableRNG(semilla)
    k = 0
    for _ in 1:n
        b, _ = muestra_espaciado!(rng, θ, ret.rho * ingreso)
        b <= x && (k += 1)
    end
    v = saldo_mc(semilla, n, lam, f, ret, ingreso; K = K, hilos = true)
    kk = count(<=(x), v)
    ap, mu, va = cola_aproximada(lam, f, ret, ingreso, x; K = K)
    return (x = x, oraculo = k / n, kernel = kk / n, normal = ap,
            teorica_media = media_teorica(lam, f, ret, ingreso),
            teorica_var = varianza_teorica(lam, f, ret, ingreso),
            cota_rigurosa = exp(-θ))
end

end # module Validacion
