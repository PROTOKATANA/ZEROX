#=  runtests.jl — suite de ANR-v0.1.

Ejecutar con comprobación de límites activa:

    ./veritas/julia.sh --project=P-ZRX/P-ANCESTRIA/investigacion/veritas/consenso/ancestria-reto-v1 \
        --check-bounds=yes P-ZRX/P-ANCESTRIA/investigacion/veritas/consenso/ancestria-reto-v1/test/runtests.jl

Cada test contrasta dos rutas independientes o una cifra externa publicada. Un test que compara
una fórmula consigo misma no se escribe.
=#

using Test
include(joinpath(@__DIR__, "..", "src", "ANR.jl"))
using .ANR

@testset "ANR-v0.1" begin

    @testset "control obligatorio d = 0" begin
        ok, _ = ANR.control_d0()
        @test ok
        lo, hi = ANR.umbral_d(0)
        exacto = 1 / (1 + exp(big(1)))
        @test lo <= exacto <= hi
        # y NO es ningún otro número redondo
        @test !(lo <= 0.27 <= hi)          # 0,27 es una aproximación; el valor es 0,26894...
        ok1, ok2 = ANR.phi_1_simbolico()
        @test ok1 && ok2
    end

    @testset "Tabla 3 de BDK+19 (externa)" begin
        ok, _ = ANR.tabla_paper()
        @test ok
    end

    @testset "valores citados en el repositorio (externos)" begin
        ok, _ = ANR.tabla_repo()
        @test ok
    end

    @testset "monotonía y límites" begin
        ok, _ = ANR.monotonia_limites()
        @test ok
        @test ANR.phi_c_f64(10^7) > 1.0
        @test Float64(ANR.umbral_d_medio(ANR.D_INF)) == 0.5
    end

    @testset "oráculo por maximización (ruta distinta)" begin
        ok, _ = ANR.oraculo_maximo()
        @test ok
    end

    @testset "kernel Float64 ↔ referencia BigFloat" begin
        ok, _ = ANR.oraculo_kernel()
        @test ok
    end

    @testset "lema de ventana (exhaustivo)" begin
        ok, _ = ANR.oraculo_ventana()
        @test ok
        @test ANR.ventana_reuso(0) == 1
        @test ANR.ventana_reuso(49) == 50
        @test ANR.ventana_reuso(ANR.D_INF) == typemax(Int)
    end

    @testset "cobertura es complementaria de la ventana" begin
        for d in (0, 1, 9, 49, 99), L in (10, 100, 1000)
            d == ANR.D_INF && continue
            c = ANR.ventana_reuso(d)
            if c >= L
                @test ANR.cobertura_rama(d, L) == 0.0
            else
                @test ANR.cobertura_rama(d, L) ≈ (L - c) / L
            end
        end
    end

    @testset "tipo de cambio: umbral objetivo <-> ventana" begin
        for beta in (0.30, 0.40, 0.45)
            c = ANR.c_para_umbral(beta; cmax=10^5, prec=160)
            @test c !== nothing
            @test ANR.umbral_c_f64(c) >= beta
            @test ANR.umbral_c_f64(c - 1) < beta
            @test c == ANR.ventana_reuso(c - 1)
        end
        # 1/2 no es alcanzable con c finito
        @test ANR.c_para_umbral(1 // 2; cmax=10^4, prec=128) === nothing
    end

    @testset "recinto de theta: signos opuestos certificados" begin
        for c in (1, 2, 7, 50, 1000)
            lo, hi = ANR.recinto_theta(c; prec=160)
            @test lo < hi < 0
            slo = ANR.signo_ec39(c, lo; prec=160)
            shi = ANR.signo_ec39(c, hi; prec=160)
            @test slo * shi < 0
        end
    end
end
