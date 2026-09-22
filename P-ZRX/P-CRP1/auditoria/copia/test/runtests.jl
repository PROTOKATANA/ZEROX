# CRP-v0.1 — suite de validación. Ejecutar con --check-bounds=yes.
using Test
using StableRNGs

include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivada.jl"))
using .CosteRamaPrivada

const P = P_DEFECTO

@testset "CRP-v0.1" begin

    @testset "invariancia exacta sr↔peso" begin
        @test error_invariancia(P.sr0) < 1e-10
        ci = chequear_invariancia_trabajo(P.sr0)
        @test Float64(ci.razon_max_min) < 1 + 1e-10
        # bordes de C-GD-01: sr=0 → 2^128; sr=2^64−1 → 2^64
        @test peso_exacto(0) == big(2)^128
        @test peso_exacto(typemax(UInt64)) == big(2)^64
    end

    @testset "umbral medio" begin
        @test α_estrella_medio(; publica=false) == 0.5
        @test α_estrella_medio(; publica=true) == 1.0
        u = umbral_medio(0.4; publica=false)
        @test u.razon < 1
        u2 = umbral_medio(0.6; publica=false)
        @test u2.razon > 1
    end

    @testset "ruina exacta y difusión" begin
        # (1/2)/(1/2)^... α=0.4, d=2 → (2/3)^2
        @test ruina_exacta(big(4)//big(10), 2) == (big(2)//big(3))^2
        @test ruina_exacta(big(6)//big(10), 5) == 1
        @test prob_alcance_difusion(0.4, 2) ≈ exp(-0.8) atol = 1e-12
        @test prob_alcance_binomial(0.6, 5) == 1.0
    end

    @testset "DP Poisson vs exacta (mismo orden, g=1)" begin
        for d in (6, 12), α in (0.2, 0.3, 0.4)
            ex = Float64(ruina_exacta(Rational{BigInt}(round(Int, α * 1000), 1000), d))
            dp = prob_alcance_dp(α, 1.0, 400; d=d)
            @test dp > 0
            @test 0.05 < dp / ex < 50        # mismo orden de magnitud
        end
        @test prob_alcance_dp(0.6, 1.0, 400; d=6) > 0.99
    end

    @testset "granularidad reduce la cola" begin
        p1 = prob_alcance_dp(0.4, 1.0, 600; d=6)
        p16 = prob_alcance_dp(0.4, 16.0, 600; d=6)
        p64 = prob_alcance_dp(0.4, 64.0, 600; d=6)
        @test p1 > p16 > p64
    end

    @testset "equivalencia de Poisson (dos métodos)" begin
        @test equivalencia_poisson(50_000).ok
    end

    @testset "kernel rápido vs referencia (proceso de trabajo)" begin
        e = equivalencia_trabajo(P; n_rep=4000, n_slots=200)
        @test e.err_fast < 0.02
        @test e.err_ref < 0.02
        @test abs(e.fast - e.ref) / e.objetivo < 0.02
    end

    @testset "varianza elegida por el adversario sube P(superar)" begin
        f = efecto_varianza_sr(P; α=0.45, n_slots=200, factores=(1, 16, 64), n_rep=1500)
        @test f[1][2] <= f[2][2] <= f[3][2]
        @test f[3][2] > f[1][2] + 0.02
    end

    @testset "multistream: α_min=1/(1+S)" begin
        @test cuota_multistream(0.5, 1) ≈ 0.5
        @test 1 / (1 + 3) == 0.25
        @test cuota_multistream(0.2, 5) > 0.5
    end

    @testset "GDR-v0.2: invariancia y U2/U3 contextual" begin
        GDR = incluir_ghostdag()
        for f in experimento_gdr_invariancia(GDR, P; ss=(0.3,), srs=(P.sr0, P.sr0 << 2),
                                             n_slots=250)
            @test abs(f.trabajo_por_slot - f.s) < 0.08
        end
        r = experimento_u2u3(GDR)
        @test r[:dentro_copias_validas]
        @test r[:dentro_azules_ident7] == 1
        @test r[:dentro_rojoU3] == 1
        @test r[:u2_rechaza]
        @test r[:entre_ambas_azules_en_su_rama]
        @test r[:entre_fusion_una_azul_otra_u3]
    end

    @testset "carrera: favorito gana, no-favorito pierde (T grande)" begin
        f = barrido_alpha(P, (0.35, 0.65); n_rep=300, n_slots=400)
        @test f[1][2] < 0.5
        @test f[2][2] > 0.5
    end
end
