using Test
using Printf

include(joinpath(@__DIR__, "..", "src", "PodaPost.jl"))
using .PodaPost

@testset "PPP-v0.1" begin

    @testset "umbral y nivel" begin
        @test umbral(UInt64(1000), 1) == 500
        @test umbral(UInt64(1000), 2) == 250
        @test umbral(UInt64(1000), 3) == 125
        @test umbral(UInt64(5), 64) == 0
        @test es_valida(UInt64(500), UInt64(1000))
        @test !es_valida(UInt64(501), UInt64(1000))
        @test nivel(UInt64(500), UInt64(1000)) == 1
        @test nivel(UInt64(250), UInt64(1000)) == 2
        @test nivel(UInt64(249), UInt64(1000)) == 2
        @test nivel(UInt64(125), UInt64(1000)) == 3
        @test nivel(UInt64(501), UInt64(1000)) == 0
    end

    @testset "hipótesis 2^-(L-1)" begin
        @test hipotesis_nivel(1) == 1
        @test hipotesis_nivel(2) == 1 // 2
        @test hipotesis_nivel(5) == 1 // 16
    end

    @testset "fórmula cerrada vs enumeración exhaustiva" begin
        fallos = valida_formula_vs_exhaustiva()
        @test isempty(fallos)
    end

    @testset "exacta ≥ hipótesis (concavidad del mínimo)" begin
        for SR in (UInt64(10), UInt64(1) << 20, UInt64(1) << 45, typemax(UInt64) >> 1),
            C in (1, 2, 8, 64), L in (2, 4, 6)
            r = ratio_exacto(L, SR, C)
            @test r >= 1
        end
        # la corrección por división entera es O(2^L/SR): decrece al crecer SR
        r20 = Float64(ratio_exacto(4, UInt64(1) << 20, 1))
        r40 = Float64(ratio_exacto(4, UInt64(1) << 40, 1))
        @test r20 > 1 && r40 > 1
        @test abs(r40 - 1) < 1e-9          # SR=2^40: corrección ~1e-11
        @test abs(r20 - 1) < 1e-3          # SR=2^20: corrección ~1e-5
    end

    @testset "anclaje independiente de padres" begin
        a = valida_anclaje_independiente(n=500, seed=UInt64(1))
        @test a.discrepancias == 0
        ca, pa, cb, pb = dos_historias_misma_solucion(Solucion(UInt64(7), UInt64(0), UInt64(2)^40),
                                                      UInt64[1], UInt64[2, 3])
        @test ca.bloques[1].nivel == cb.bloques[1].nivel
        @test pa != pb
    end

    @testset "certificado de niveles" begin
        r = certificado_falso_alto(16, 30; ventana=2)
        @test r.aceptado
        # ventana sin ningún bloque de nivel alto ⇒ el verificador la rechaza
        altos = [Solucion(UInt64(s), UInt64(0), typemax(UInt64) >> 1) for s in (0, 1, 2, 3)]
        cert_ok = certificado_de_soluciones(altos)
        @test verifica_certificado_niveles(cert_ok, 2, 1, 2)
        hueco = vcat([Solucion(UInt64(0), UInt64(0), typemax(UInt64) >> 1)],
                     [Solucion(UInt64(s), UInt64(1), UInt64(2)) for s in 1:4],
                     [Solucion(UInt64(5), UInt64(0), typemax(UInt64) >> 1)])
        cert_hueco = certificado_de_soluciones(hueco)
        @test !verifica_certificado_niveles(cert_hueco, 2, 1, 2)
    end

    @testset "Monte Carlo vs exacta" begin
        res = monte_carlo_niveles(UInt64(0x1234), 1, UInt64(1) << 62, 40_000, 4; Lmax=6)
        for f in equivalencia_niveles(res)
            f.cubre === missing && continue
            @test f.cubre
        end
    end

    @testset "crecimiento de cabeceras" begin
        cab, bytes, reach = crecimiento_cabeceras(1.0, 748.0, 180)
        @test isapprox(cab, 31.536e6; rtol=1e-6)
        @test isapprox(bytes / 1e9, 23.6; rtol=0.05)
        @test reach == cab * 180
    end

    @testset "coste de molienda CPU" begin
        @test coste_molido_hash(20, 1e6) ≈ 2.0^20 / 1e6
        # nivel 40 a 1e6 h/s ≈ 12,7 días: el nivel-ligado-a-ancestría no es espacio-tiempo
        @test coste_molido_hash(40, 1e6) > 1e6 / 1e6
    end

    @testset "degradación de SR pequeño (declarada, no silenciosa)" begin
        # SR=0: válido solo si d=0; el nivel queda indefinido/capado. Se documenta, no se oculta.
        @test nivel(UInt64(0), UInt64(0)) == 64
        @test !es_valida(UInt64(1), UInt64(0))
    end
end
