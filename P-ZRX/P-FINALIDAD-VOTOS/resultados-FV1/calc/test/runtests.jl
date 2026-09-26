using Test
include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
using .ModeloFV1

@testset "Reproduccion exacta de CONTEXTO.md §3.6 / ORDEN §3.6 (a=0,25, esperanzas)" begin
    a = 0.25
    # tabla "Atacante, con 80% de honestos encendidos"
    @test isapprox(q_atacante(a, 1.0, 0.8), 0.250; atol=1e-3)
    @test isapprox(q_atacante(a, 2.0, 0.8), 0.270; atol=1e-3)
    @test isapprox(q_atacante(a, 4.0, 0.8), 0.282; atol=1e-3)
    @test isapprox(q_atacante(a, 10.0, 0.8), 0.289; atol=1e-3)
    # limite b->inf (solo los encendidos): a/(a+(1-a)p)
    lim_binf = a/(a+(1-a)*0.8)
    @test isapprox(lim_binf, 0.294; atol=1e-3)

    # tabla "Atacante si censura todas las pruebas honestas" (p=0)
    @test isapprox(q_atacante(a, 1.0, 0.0), 0.250; atol=1e-3)
    @test isapprox(q_atacante(a, 2.0, 0.0), 0.400; atol=1e-3)
    @test isapprox(q_atacante(a, 4.0, 0.0), 0.571; atol=1e-3)
    @test isapprox(q_atacante(a, 10.0, 0.0), 0.769; atol=1e-3)
    @test isapprox(a*1e9/(a*1e9+1-a), 1.0; atol=1e-6)  # b->inf, p=0 -> 1

    # "¿Sella con 80%?" (frac_honesto_firmable >= 2/3)
    @test frac_honesto_firmable(a, 1.0, 0.8) < 2/3
    @test frac_honesto_firmable(a, 2.0, 0.8) < 2/3
    @test frac_honesto_firmable(a, 4.0, 0.8) >= 2/3
    @test frac_honesto_firmable(a, 10.0, 0.8) >= 2/3

    # "no llega a 2/3 mientras b < 6" (a=0,25)
    @test q_atacante(a, 5.999, 0.0) < 2/3
    @test q_atacante(a, 6.0, 0.0) ≈ 2/3 atol=1e-6
    @test q_atacante(a, 6.001, 0.0) > 2/3
end

@testset "p_necesaria reproduce los dos extremos citados" begin
    a = 0.25
    @test isapprox(p_necesaria(a, 1.0), (2/3)/(1-a); atol=1e-9)     # "votan todos": 88,9%
    @test isapprox(p_necesaria(a, 1e9), 2*a/(1-a); atol=1e-6)        # "solo los encendidos": 66,7%
end

@testset "Umbrales de pausa y de ruptura por censura total (nuevo, D)" begin
    # b=1: sin distorsion, ambos coinciden con el umbral clasico de la finalidad ponderada
    @test isapprox(a_pausa(1.0), 1/3; atol=1e-9)
    @test isapprox(a_rompe(1.0), 2/3; atol=1e-9)
    # b=4 (prima "moderada" recomendada en CONTEXTO §3.6): a_rompe coincide con 1/3
    @test isapprox(a_rompe(4.0), 1/3; atol=1e-9)
    # y el umbral de pausa ya cae por debajo de 1/3
    @test a_pausa(4.0) < 1/3
    @test isapprox(a_pausa(4.0), 1/9; atol=1e-9)
end

@testset "Cola binomial exacta: casos de control" begin
    # Binomial(10, 0.5): P(X>=5) = 0.623046875 (exacto, tabla de libro)
    @test isapprox(sf_binom(5, 10, 0.5), 0.623046875; atol=1e-9)
    # P(X>=0) = 1 ; P(X>=n+1) = 0
    @test sf_binom(0, 10, 0.5) == 1.0
    @test sf_binom(11, 10, 0.5) == 0.0
    # Reproduce verif_sorteo.py fila K=1000, a=0.33 (referencia historica, sin auditar,
    # solo para cruce de orden de magnitud, no como fuente de verdad)
    p13 = p_para_al_menos(0.33, 1000, 1/3)
    @test 1e-2 < p13 < 1.0   # d8-ronda anterior citaba 4,1e-01 para a=0,33
end

@testset "coste_certificado_bytes: BLS << Ed25519 a K grande" begin
    @test coste_certificado_bytes(4000; esquema=:ed25519) > 100*coste_certificado_bytes(4000; esquema=:bls)
end

println("OK: todos los tests de modelo.jl pasaron.")
