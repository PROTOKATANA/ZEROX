# validacion.jl — equivalencia, invariantes y bordes. Todo lo que se publica pasa por aquí.

"""
Valida el intervalo riguroso de Poisson contra el término polinómico EXACTO
(`Rational{BigInt}`) multiplicado por un `exp(-λ)` con precisión doble de trabajo.
Devuelve `(max_err_abs, max_err_rel)` y comprueba que el intervalo CONTIENE el valor exacto.
"""
function validar_intervalo_vs_exacto(; prec::Int = 256, casos = nothing)
    if casos === nothing
        casos = [(BigInt(1), BigInt(1000), k) for k in (0, 1, 2, 5, 20, 50)] ∪
                [(BigInt(1), BigInt(10), k) for k in 0:15] ∪
                [(BigInt(37), BigInt(5), k) for k in (0, 1, 3, 10, 40)] ∪
                [(BigInt(0), BigInt(1), k) for k in (0, 1, 5)]
    end
    max_abs = BigFloat(0)
    max_rel = BigFloat(0)
    contiene = true
    for (λn, λd, k) in casos
        lo, hi = poisson_cdf_intervalo(λn, λd, k; prec = prec)
        # valor de referencia con precisión doble y suma exacta del polinomio
        s = suma_poisson_exacta(λn, λd, k)
        ref = setprecision(BigFloat, 2 * prec) do
            λb = setrounding(BigFloat, RoundNearest) do
                BigFloat(λn) / BigFloat(λd)
            end
            e = exp(-λb)
            setrounding(BigFloat, RoundNearest) do
                BigFloat(numerator(s)) / BigFloat(denominator(s)) * e
            end
        end
        abs_err = max(abs(lo - ref), abs(hi - ref))
        rel_err = ref == 0 ? abs_err : abs_err / ref
        max_abs = max(max_abs, abs_err)
        max_rel = max(max_rel, rel_err)
        (lo - ref > 0 || hi - ref < 0) && (contiene = false)
    end
    return (; max_abs, max_rel, contiene)
end

"""
Valida la Poisson contra la binomial EXACTA en lotes pequeños: con `n` piezas, probabilidad
`a/b` por pieza, la media es `λ = n·a/b`. **La Poisson es una aproximación**, así que aquí no
se exige contención: se mide la discrepancia y se compara con la cota de Le Cam para
Bernoulli independientes, `2·n·p²` (total variation). Devuelve `(max_dif, cota, dentro)`.
Esto es justo el aviso del encargo: en lotes pequeños la Poisson NO es la referencia.
"""
function validar_poisson_vs_binomial(; prec::Int = 256)
    max_dif = BigFloat(0)
    cota_max = BigFloat(0)
    dentro = true
    for (n, a, b) in ((10, 1, 100), (50, 1, 100), (100, 1, 1000), (200, 1, 100), (1000, 1, 1000))
        λn = BigInt(n * a)
        λd = BigInt(b)
        cota = min(BigFloat(1), 2 * BigFloat(n) * BigFloat(a)^2 / BigFloat(b)^2)
        for k in 0:min(n, 40)
            exacta = binomial_cdf_exacta(n, a, b, k)
            lo, hi = poisson_cdf_intervalo(λn, λd, k; prec = prec)
            ref = setprecision(BigFloat, 2 * prec) do
                BigFloat(numerator(exacta)) / BigFloat(denominator(exacta))
            end
            d = max(abs(ref - lo), abs(hi - ref))
            max_dif = max(max_dif, d)
            cota_max = max(cota_max, cota)
        end
    end
    dentro = max_dif <= cota_max + BigFloat("1e-12")
    return (; max_dif, cota_max, dentro)
end

"""
Invariante: la potencia garantizada es no decreciente en `T` (salvo ruido de redondeo dirigido
por debajo de `tol`), y el umbral `K` es no decreciente. La búsqueda por duplicación+bisección
de `periodos_deteccion` depende de ello; si la potencia bajara de forma apreciable, la búsqueda
no sería válida y el test lo detecta.
"""
function validar_monotonia_potencia(λ::Float64, s::Float64, beta::Float64; Tmax::Int = 64,
        tol::Float64 = 1e-9)
    λn = BigInt(round(Int, λ * 1000))
    λd = BigInt(1000)
    s_num = BigInt(round(Int, s * 1000))
    s_den = BigInt(1000)
    anterior = BigFloat(-1)
    Kanterior = -1
    monótona = true
    for T in 1:Tmax
        K, pot, _ = _potencia_y_umbral(λn, λd, T, s_num, s_den, beta; prec = 128)
        K < 0 && continue
        pot < anterior - BigFloat(tol) && (monótona = false)
        K < Kanterior && (monótona = false)
        anterior = max(anterior, pot)
        Kanterior = K
    end
    return monótona
end

"""
Valida el kernel rápido Float64 contra la referencia rigurosa en una rejilla:
devuelve la mayor diferencia de umbral (`K`) y de potencia.
"""
function validar_kernel_vs_referencia(; prec::Int = 128)
    max_dK = 0
    max_dP = 0.0
    for λ in (1.0, 5.0, 20.0, 100.0, 1000.0), beta in (1e-2, 1e-3, 1e-4)
        Kf = umbral_float(λ, beta)
        λn = BigInt(round(Int, λ * 1000))
        λd = BigInt(1000)
        Kr, ok = umbral_rechazo(λn, λd, beta; prec = prec)
        ok || continue
        max_dK = max(max_dK, abs(Kf - Kr))
        for s in (0.25, 0.5, 0.9)
            pf = potencia_float(λ * s, Kf)
            pr = potencia_garantizada(λn * BigInt(round(Int, s * 1000)), λd * 1000, Kr; prec = prec)
            max_dP = max(max_dP, abs(pf - Float64(pr)))
        end
    end
    return (; max_dK, max_dP)
end

"""
Bordes obligatorios:
- `λ = 0` (no hay parciales) ⇒ no hay test;
- `k = -1` (cola vacía) ⇒ 0;
- `s = 1` (no hay nada que detectar) ⇒ potencia ≤ 1-β, nunca 1-γ;
- `w = 0` ⇒ coste infinito, no cero.
"""
function comprobar_bordes()
    fallos = String[]
    lo, hi = poisson_cdf_intervalo(0, 1, 0)
    (lo == 1 && hi == 1) || push!(fallos, "λ=0 debe dar CDF(0)=1")
    lo, hi = poisson_cdf_intervalo(1, 1, -1)
    (lo == 0 && hi == 0) || push!(fallos, "k=-1 debe dar 0")
    K, ok = umbral_rechazo(0, 1, 1e-3)
    (K == -1) || push!(fallos, "λ=0 no admite umbral (debe ser -1)")
    # s=1 no se distingue: la potencia contra el honesto no puede superar el falso fallo β
    λn, λd = BigInt(100), BigInt(1)
    K1, _ = umbral_rechazo(λn, λd, 1e-3; prec = 128)
    pot = potencia_garantizada(λn, λd, K1; prec = 128)
    pot <= BigFloat(1e-3) + BigFloat("1e-20") || push!(fallos, "s=1 no puede superar el falso fallo β")
    # w=0 ⇒ infinito
    hw = Hardware(0.809, 0.11805, 25.03, 4.9e-7, 1.404e-5, 0.023, 5251072, 1048672, 8192,
        32768, 65536, 0.5, 83.608, 7175.0, 4830.6, "prueba")
    isinf(e3_cpu_regeneracion(hw, 1000.0, 0.0, 100.0)) || push!(fallos, "w=0 debe dar coste infinito")
    # monotonicidad del coste en w
    (e3_cpu_regeneracion(hw, 1000.0, 10.0, 100.0) > e3_cpu_regeneracion(hw, 1000.0, 1000.0, 100.0)) ||
        push!(fallos, "el coste debe bajar al crecer w")
    return fallos
end
