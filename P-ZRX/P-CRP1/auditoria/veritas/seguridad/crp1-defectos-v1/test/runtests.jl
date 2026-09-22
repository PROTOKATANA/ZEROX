# runtests.jl — suite de validación de la auditoría P-CRP1.
# Ejecutar con: julia --project=. --check-bounds=yes test/runtests.jl
using Test
using StableRNGs

include(joinpath(@__DIR__, "..", "src", "CRP1Defectos.jl"))
using .CRP1Defectos

@testset "CRP1-defectos-v1" begin

    @testset "T1 predicado PoAS: conteo cerrado vs enumeración" begin
        r = validar_conteo_residuos()
        @test r.ok
        @test length(r.filas) == 36
        # bordes del dominio circular
        @test valores_aceptados(0) == 1
        @test valores_aceptados(1) == 1
        @test valores_aceptados(2) == 3
        # sr = 2^64−1 es IMPAR: acepta sr residuos (no sr+1)
        @test valores_aceptados(typemax(UInt64)) == big(2)^64 - 1
        # el PESO sí usa el denominador sr+1: ⌊2^128/(2^64−1+1)⌋ = 2^64
        @test peso_exacto(typemax(UInt64)) == big(2)^64
        @test peso_exacto(0) == big(2)^128
    end

    @testset "T2 ruina ±1: forma cerrada vs sistema racional vs enumeración" begin
        r = validar_ruina_forma_cerrada()
        @test r.ok
        @test prob_empate_reticula(big(4)//big(10), 2) == (big(2)//big(3))^2
        @test prob_empate_reticula(big(6)//big(10), 5) == 1
        @test prob_superar_reticula(big(4)//big(10), 6) == (big(2)//big(3))^7
    end

    @testset "T3 martingala del paseo compuesto: E[z^X] = 1" begin
        for g in (1, 4, 16, 64, 256)
            @test verificar_martingala(0.4, g) < 1e-70
        end
        @test Float64(cota_martingala(big(2)//big(5), 6)) ≈ 0.0877914951989026 atol = 1e-15
    end

    @testset "T4 pmf de Poisson y muestreador independiente" begin
        r = validar_pmf_poisson(n = 100_000)
        @test r.ok
        v = pmf_poisson_vec(60, 5.0)
        @test abs(sum(v) - 1) < 1e-12
    end

    @testset "T5 descomposición exacta del trabajo por ensayo" begin
        r = validar_descomposicion_trabajo()
        @test r.ok
        d1 = descomposicion_trabajo(1)
        @test d1.paridad == big(1)//big(2)               # PCO-v0.1: SR=1 ⇒ déficit 1/2
        d2049 = descomposicion_trabajo(2049)
        @test abs(Float64(d2049.paridad) - 1 / 2050) < 1e-15
    end

    @testset "T6 DP de masa conservada: estable en la ventana y bajo la martingala" begin
        for (α, g, m) in ((big(2)//big(5), 1, 6), (big(2)//big(5), 4, 24), (big(2)//big(5), 16, 96))
            mart = Float64(cota_martingala(α, m))
            dp = alcance_compuesto(0.4, Float64(g), m; ventanas = (m + 200, m + 600, m + 1200))
            @test dp.p <= mart * (1 + 1e-9)
            @test dp.masa_incremento > 0.9999
            # estabilidad frente a la ventana (diferencia relativa < 1e-9)
            @test maximum(abs.(diff(dp.p_ventanas))) / dp.p < 1e-9
        end
    end

    @testset "T7 D3: el evento estricto es menor que el de empate y la razón ≈ q/p" begin
        for (g, m) in ((1, 6), (16, 96))
            a = alcance_compuesto(0.4, Float64(g), m; absorbe_estricto = false, ventanas = (m + 600,))
            b = alcance_compuesto(0.4, Float64(g), m; absorbe_estricto = true, ventanas = (m + 600,))
            @test b.p < a.p
            @test abs(b.p / a.p - 2 / 3) < 0.01
        end
    end

    @testset "T8 α_min: la sucesión converge a 1/2 DESDE ABAJO" begin
        vals = [α_min_empate(d, 0.10) for d in (3, 6, 12, 24, 50, 500, 5000)]
        @test all(vals .< 0.5)
        @test issorted(vals)
        @test α_min_superar(6, 0.10) > α_min_empate(6, 0.10)
        @test α_min_empate(6, 0.10) ≈ 0.405219 atol = 1e-6
    end

    @testset "T9 D5: convolución exacta validada contra MC con semillas no consecutivas" begin
        rv = validar_varianza_exacta_contra_mc(ParametrosVarianza(); n_rep = 20_000)
        @test rv.ok
        # los valores exactos están por debajo del IC superior y por encima del inferior
        for (e, m) in zip(rv.exacto, rv.mc)
            @test e.p_mayor >= m.hoeffding.lo - 1e-12
            @test e.p_mayor <= m.hoeffding.hi + 1e-12
        end
    end

    @testset "T10 D5: el sesgo de semillas consecutivas de StableRNG es real" begin
        rho = autocorrelacion_lag1_consecutivas(20_000)
        @test rho < -0.3      # P-PUERTA reporta ≈ −0,43
    end

    @testset "T11 D6/D7/D9: aritmética de las fórmulas citadas" begin
        @test isapprox(α_rojos_asimetricos(0.2858), 0.4166; atol = 1e-4)
        @test isapprox(α_rojos_asimetricos(0.0), 0.5; atol = 1e-12)
        @test cuota_multistream(0.5, 1) ≈ 0.5
        @test α_min_multistream(3) == 0.25
        @test fld(100000, 4161) == 24          # el «S = 24» citado, no medido
    end

    @testset "T12 Regresión: el corte fijo 0…60 de CRP-v0.1 pierde masa" begin
        # reproducción exacta del corte del instrumento
        for g in (1, 4, 16, 64)
            μh = g * 0.6; μa = g * 0.4
            ph = pmf_poisson_vec(60, μh); pa = pmf_poisson_vec(60, μa)
            @test sum(ph) * sum(pa) > 0.99
        end
        μh = 256 * 0.6; μa = 256 * 0.4
        ph = pmf_poisson_vec(60, μh); pa = pmf_poisson_vec(60, μa)
        @test sum(ph) * sum(pa) < 1e-20        # g=256: colapso de la masa
    end
end
