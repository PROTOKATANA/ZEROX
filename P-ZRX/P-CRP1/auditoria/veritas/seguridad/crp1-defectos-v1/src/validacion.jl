# validacion.jl — equivalencia referencia/kernel, invariantes y bordes (LINEO §5).

"""
Valida `valores_aceptados` contra el conteo por ENUMERACIÓN exhaustiva del dominio circular
para tamaños pequeños. Devuelve `(ok, filas)`.
"""
function validar_conteo_residuos(; Ms = (16, 64, 129, 1024), srs = 0:8)
    filas = NamedTuple[]
    ok = true
    for M in Ms, sr in srs
        sr <= M - 1 || continue
        brute = conteo_residuos_por_enumeracion(M, sr)
        cerrado = Int(valores_aceptados(sr))
        ok &= (brute == cerrado)
        push!(filas, (M = M, sr = sr, enumeracion = brute, cerrado = cerrado,
                      coincide = brute == cerrado))
    end
    return (ok = ok, filas = filas)
end

"""
Valida la forma cerrada `(q/p)^z` contra dos métodos independientes: resolución exacta del
sistema racional y enumeración exacta de caminos. Devuelve `(ok, filas)`.
"""
function validar_ruina_forma_cerrada(; αs = (big(2)//big(5), big(3)//big(10)),
                                     ms = (1, 2, 3, 6), N = 60)
    filas = NamedTuple[]
    ok = true
    for α in αs, m in ms
        cerrado = prob_empate_reticula(α, m)
        sistema = ruina_unitaria_sistema_racional(α, m, N)
        enum = ruina_unitaria_enumeracion(α, m, 4000, m + 300).exito
        c1 = abs(Float64(cerrado) - Float64(sistema)) / Float64(cerrado) < 1e-8
        c2 = abs(Float64(cerrado) - Float64(enum)) / Float64(cerrado) < 1e-9
        ok &= c1 && c2
        push!(filas, (α = Float64(α), m = m, cerrado = Float64(cerrado),
                      sistema = Float64(sistema), enumeracion = Float64(enum),
                      ok_sistema = c1, ok_enumeracion = c2))
    end
    return (ok = ok, filas = filas)
end

"""
Comprueba que la DP de masa conservada queda DENTRO del intervalo certificado
`[cota inferior de horizonte finito, cota de martingala]` y que ambas son rigurosas.
Devuelve `(ok, filas)`.
"""
function validar_dp_contra_cotas(; casos = ((big(2)//big(5), 1, 6), (big(2)//big(5), 4, 24),
                                           (big(2)//big(5), 16, 96), (big(3)//big(10), 1, 3)),
                                 ns = (2, 4, 8, 16, 32, 64, 128, 256))
    filas = NamedTuple[]
    ok = true
    for (α, g, m) in casos
        mart = Float64(cota_martingala(α, m))
        infer = mejor_cota_inferior_horizonte(Float64(α), Float64(g), m, ns)
        dp = alcance_compuesto(Float64(α), Float64(g), m; ventanas = (m + 200, m + 600))
        dentro = (dp.p <= mart * (1 + 1e-9)) && (infer.p <= dp.p * (1 + 1e-6))
        ok &= dentro
        push!(filas, (α = Float64(α), g = g, m = m, dp = dp.p, cota_inf = infer.p,
                      n_inf = infer.n, martingala = mart,
                      dp_sobre_martingala = dp.p > mart * (1 + 1e-9),
                      inf_sobre_dp = infer.p > dp.p * (1 + 1e-6)))
    end
    return (ok = ok, filas = filas)
end

"""
Valida `varianza_exacta` contra Monte Carlo con semillas no consecutivas: el valor exacto debe
caer dentro del IC de Hoeffding 99,9 % (y del de Wilson).
"""
function validar_varianza_exacta_contra_mc(p::ParametrosVarianza; n_rep::Int = 40_000,
                                           semilla::UInt64 = UInt64(0x5A71A))
    ex = varianza_exacta(p)
    mc = mc_varianza(p; n_rep = n_rep, semilla = semilla, modo = :hashed, δ = 0.001)
    filas = NamedTuple[]
    ok = true
    for (e, m) in zip(ex, mc)
        dentro = (e.p_mayor >= m.hoeffding.lo) && (e.p_mayor <= m.hoeffding.hi)
        ok &= dentro
        push!(filas, (K = e.K, exacto = e.p_mayor, mc = m.p, n_rep = m.n_rep,
                      hoeff = (m.hoeffding.lo, m.hoeffding.hi),
                      wilson = (m.wilson.lo, m.wilson.hi),
                      exacto_en_IC = dentro))
    end
    return (ok = ok, filas = filas, exacto = ex, mc = mc)
end

"""
Valida la descomposición en forma cerrada del trabajo por ensayo contra el cálculo directo.
"""
function validar_descomposicion_trabajo(; srs = (1, 2, 3, 2048, 2049, big(2)^50, big(2)^50 - 1))
    filas = NamedTuple[]
    ok = true
    for sr in srs
        d = descomposicion_trabajo(sr)
        directo = trabajo_por_ensayo(sr) // DOS64
        c = abs(Float64(BigFloat(d.valor) - BigFloat(directo))) / Float64(BigFloat(directo))
        ok &= (c < 1e-30)
        push!(filas, (sr = sr, forma_cerrada = Float64(BigFloat(d.valor)),
                      directo = Float64(BigFloat(directo)),
                      deficit_paridad = Float64(BigFloat(d.paridad)),
                      deficit_suelo = Float64(BigFloat(d.suelo)),
                      rel_err = c))
    end
    return (ok = ok, filas = filas)
end

"""
Valida la pmf de Poisson implementada contra un oráculo de doble precisión independiente
(producto iterativo) y contra la frecuencia empírica del muestreador por transformada inversa.
"""
function validar_pmf_poisson(; μs = (0.1, 0.55, 5.0, 153.6), n = 400_000,
                             semilla::UInt64 = UInt64(0xC0FFEE))
    filas = NamedTuple[]
    ok = true
    for μ in μs
        v = pmf_poisson_vec(200, μ)
        # oráculo: producto iterativo
        p = exp(-μ)
        oracle = Float64[]
        push!(oracle, p)
        for k in 1:200
            p *= μ / k
            push!(oracle, p)
        end
        err = maximum(abs.(v .- oracle) ./ max.(oracle, 1e-300))
        ok &= (err < 1e-12)
        push!(filas, (μ = μ, err_rel_max = err, masa = sum(oracle)))
    end
    # contraste empírico con el muestreador por transformada inversa
    rng = StableRNG(semilla)
    μ = 5.0
    conteo = zeros(Int, 30)
    for _ in 1:n
        k = poisson_inversa(rng, μ)
        k < 30 && (conteo[k + 1] += 1)
    end
    teo = pmf_poisson_vec(29, μ)
    emp = conteo ./ n
    errEmp = maximum(abs.(emp .- teo))
    ok &= (errEmp < 5 * sqrt(μ / n))
    return (ok = ok, filas = filas, err_emp = errEmp, μ_emp = μ, n_emp = n)
end
