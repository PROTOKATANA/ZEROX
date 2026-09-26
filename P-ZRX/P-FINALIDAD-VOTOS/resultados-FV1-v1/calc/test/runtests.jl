using Test
using Random

include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
using .Modelo

@testset "Bloque 1 · quórum" begin
    # Cierre exacto de CONTEXTO.md §5: (1-a)*p >= 2/3
    @test isapprox(Modelo.umbral_pi_teorico(0.25), 8/9; atol=1e-9)
    @test isapprox(Modelo.umbral_pi_teorico(0.30), (2/3)/0.7; atol=1e-9)
    @test isapprox(Modelo.umbral_pi_teorico(0.25) * 100, 88.888888; atol=1e-4)
    @test isapprox(Modelo.umbral_pi_teorico(0.30) * 100, 95.238095; atol=1e-4)

    # Caso homogéneo con muchas claves iguales: el MC debe aproximar el escalón
    # determinista en pi_uptime = umbral_pi_teorico(a), con margen por varianza finita.
    a = 0.25
    rng = Xoshiro(0x1122334455)
    pesos = (1 - a) .* Modelo.pesos_homogeneos(2000)
    umbral_pi = Modelo.umbral_pi_teorico(a)
    p_bajo, _ = Modelo.prob_quorum_mc(rng, pesos, umbral_pi - 0.05, 20_000)
    p_alto, _ = Modelo.prob_quorum_mc(rng, pesos, umbral_pi + 0.05, 20_000)
    @test p_bajo < 0.15
    @test p_alto > 0.85

    # Monotonía en pi_uptime (a fijo, cola fija): más uptime no puede dar menos quórum.
    rng2 = Xoshiro(0x99AABBCCDD)
    pesos2 = (1 - 0.30) .* Modelo.pesos_pareto(rng2, 500, 1e-6, 2.5)
    p1, _ = Modelo.prob_quorum_mc(rng2, pesos2, 0.80, 20_000)
    p2, _ = Modelo.prob_quorum_mc(rng2, pesos2, 0.99, 20_000)
    @test p2 >= p1
end

@testset "Bloque 2 · reproducción cruzada §4.A/§4.D" begin
    # Orden de magnitud publicado en research/dag-poas-capa-finalidad.md §4.A,
    # K=1000: alpha=0.10 -> ~5.0e-90 (>=1/3); alpha=0.33 -> ~6.5e-105 (>=2/3).
    filas = Modelo.reproduce_4A(Ks=(1000,), alphas=(0.10, 0.20, 0.25, 0.30, 0.33))
    f10 = only(filter(x -> x.alpha == 0.10, filas))
    @test 1e-95 < Float64(f10.p_ge_13) < 1e-85
    f33 = only(filter(x -> x.alpha == 0.33, filas))
    @test 1e-115 < Float64(f33.p_ge_23) < 1e-95

    # Monotonía: más alpha => más probable pasar el 1/3 y el 2/3.
    fs = Modelo.reproduce_4A(Ks=(1000,), alphas=(0.10, 0.20, 0.30))
    @test issorted(Float64.(getfield.(fs, :p_ge_13)))
end

@testset "Bloque 3 · certificado" begin
    @test Modelo.tamano_certificado_bytes(0) == 96 + 32 + 64
    @test Modelo.tamano_certificado_bytes(8) == 96 + 32 + 64 + 1
    @test Modelo.tamano_certificado_bytes(3600) == 96 + 32 + 64 + cld(3600, 8)
    # Coste anual escala linealmente con el tamaño e inversamente con el período.
    g1 = Modelo.coste_anual_gb(1000, 30.0)
    g2 = Modelo.coste_anual_gb(2000, 30.0)
    @test isapprox(g2, 2 * g1; rtol=1e-9)
    g3 = Modelo.coste_anual_gb(1000, 60.0)
    @test isapprox(g3, g1 / 2; rtol=1e-9)
end

@testset "Bloque 4 · ventana del doble farmeo" begin
    # Caso optimista (ronda 0, 3 fases, backoff irrelevante): 3*2*Δ = 6Δ.
    @test isapprox(Modelo.latencia_instancia_gossipbft(6.0, 0), 36.0; atol=1e-9)
    # Con backoff, la ronda 1 añade 3*2*Δ*2 = 12Δ más.
    @test isapprox(Modelo.latencia_instancia_gossipbft(6.0, 1), 36.0 + 72.0; atol=1e-9)
    # tiempo_hasta_sello con lookback=1 y ronda 0 = 2 * latencia (una espera + la propia).
    t = Modelo.tiempo_hasta_sello(6.0, 1, 0)
    @test isapprox(t, 2 * 36.0; atol=1e-9)
    # La ventana con GossiPBFT (decenas/centenas de s) debe ser mucho menor que F_slots=7200 s
    # en todo el barrido optimista (ronda_maxima <= 1).
    filas = Modelo.barrido_ventana(rondas=(0, 1))
    @test all(f -> f.t_sello_s < f.F_s, filas)
end

println("Todos los tests de Bloque 1-4 pasaron.")
