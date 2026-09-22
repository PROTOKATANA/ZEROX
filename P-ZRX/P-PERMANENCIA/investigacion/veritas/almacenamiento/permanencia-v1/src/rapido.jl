# rapido.jl — kernel rápido para barridos grandes.
#
# Dos velocidades (LINEO §5.3):
#   - la referencia exacta/rigurosa de `referencia.jl` decide los casos que cambian el veredicto;
#   - este kernel Float64 barre rejillas grandes y se valida contra la referencia.
# Ninguna cifra publicada sale de aquí sin pasar por `validar_kernel_vs_referencia`.

"""Cuantil normal estándar (Acklam). Solo para arrancar barridos, no decide un veredicto."""
function cuantil_normal(p::Float64)
    a = (-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
        1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00)
    b = (-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
        6.680131188771972e+01, -1.328068155288572e+01)
    c = (-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
        -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00)
    d = (7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
        3.754408661907416e+00)
    plow = 0.02425
    phigh = 1 - plow
    if p < plow
        q = sqrt(-2 * log(p))
        return (((((c[1] * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) * q + c[6]) /
               ((((d[1] * q + d[2]) * q + d[3]) * q + d[4]) * q + 1)
    elseif p <= phigh
        q = p - 0.5
        r = q * q
        return (((((a[1] * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * r + a[6]) * q /
               (((((b[1] * r + b[2]) * r + b[3]) * r + b[4]) * r + b[5]) * r + 1)
    else
        q = sqrt(-2 * log(1 - p))
        return -(((((c[1] * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) * q + c[6]) /
               ((((d[1] * q + d[2]) * q + d[3]) * q + d[4]) * q + 1)
    end
end

"""
Cola `P(X ≤ k)` de Poisson por recurrencia relativa a la moda, estable en Float64.
`exp(-λ)` desborda para λ grande; por eso se suma en escala logarítmica relativa al pico.
Solo barrido; la cifra publicada sale de `referencia.jl`.
"""
function poisson_cdf_float(λ::Float64, k::Int)
    k < 0 && return 0.0
    λ == 0 && return 1.0
    L = log(λ)
    m = max(floor(Int, λ), 0)
    lfact_m = 0.0
    for i in 1:m
        lfact_m += log(i)
    end
    pico = -λ + m * L - lfact_m
    s = 0.0
    lf = 0.0
    for j in 0:k
        j > 0 && (lf += log(j))
        s += exp(-λ + j * L - lf - pico)
        # los términos ya son despreciables y estamos por debajo del pico: no seguir perdiendo
        (j > m && s > 1e300) && break
    end
    return min(1.0, exp(pico) * s)
end

"""Umbral de rechazo aproximado (Float64) para barrer."""
function umbral_float(λ::Float64, beta::Float64)
    K = -1
    for k in 0:Int(ceil(λ + 50 * sqrt(λ) + 100))
        if poisson_cdf_float(λ, k) <= beta
            K = k
        else
            break
        end
    end
    return K
end

"""Potencia aproximada contra `Poisson(λc)` con umbral `K`: el test rechaza si `X ≤ K`."""
potencia_float(λc::Float64, K::Int) = poisson_cdf_float(λc, K)

"""Periodos aproximados por fórmula cerrada (normal). Orientativo."""
periodos_aprox(λ::Float64, s::Float64, beta::Float64, gamma::Float64) =
    ((cuantil_normal(1 - beta) + cuantil_normal(1 - gamma) * sqrt(s)) / ((1 - s) * sqrt(λ)))^2

"""
Rejilla de `w` geométrica (log-espaciada) entre `wmin` y `wmax` con `n` puntos, más los
valores fijos. `w` es un símbolo: el instrumento solo la muestrea.
"""
function rejilla_log(wmin::Float64, wmax::Float64, n::Int)
    n <= 1 && return [wmin]
    return exp.(range(log(wmin), log(wmax); length = n))
end

"""
Kernel de barrido E3: para cada `w` de la rejilla y cada `TiB`, coste de fabricación.
Escribe en vectores preasignados. Tipoestable, sin asignaciones en el bucle.
"""
function barrer_e3!(cpu::Vector{Float64}, forzado::Vector{Float64}, tib_por_cpu::Vector{Float64},
        hw::Hardware, ws::Vector{Float64}, N::Float64)
    @inbounds for i in eachindex(ws)
        w = ws[i]
        fab = e3_piezas_fabricables(hw, w)
        cpu[i] = N / (hw.r_cpu_tablas_s * w * TAU_S)
        forzado[i] = 1 - min(1.0, fab / N)
        tib_por_cpu[i] = fab * hw.bytes_pieza_B / BYTES_POR_TiB
    end
    return nothing
end
