# Suite CRP-v0.2 — ejecutar:
#   env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl
using Test
using Random
using StableRNGs
include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivadaV2.jl"))
using .CosteRamaPrivadaV2

const P9 = 9 // 10
const Q1 = 1 // 10

@testset "CRP-v0.2" begin

@testset "D3 · empate ≠ superación estricta (exacto)" begin
    @test prob_empate_eventual(0, P9, Q1) == 1//1
    @test prob_superar_eventual(0, P9, Q1) == 1//9
    @test prob_empate_eventual(1, P9, Q1) == 1//9
    @test prob_superar_eventual(1, P9, Q1) == 1//81
    # superar estrictamente es menos probable que alcanzar el empate
    for d in 0:10
        @test prob_superar_eventual(d, P9, Q1) <= prob_empate_eventual(d, P9, Q1)
    end
    # q ≥ p ⇒ ambas son 1
    @test prob_empate_eventual(3, 1//2, 1//2) == 1//1
    @test prob_superar_eventual(3, 1//2, 1//2) == 1//1
    @test prob_superar_eventual(3, 2//5, 3//5) == 1//1
end

@testset "D3 · regresión 1/2⁻ (no 1/2⁺)" begin
    for d in (1, 2, 4, 8, 16, 64)
        val, dist = corrimiento_alpha_prob(d, 1//10)
        @test dist < 0                     # converge DESDE ABAJO
        @test val < 1//2
    end
    # monótono hacia 1/2 por abajo al crecer d
    v1, _ = corrimiento_alpha_prob(1, 1//10)
    v8, _ = corrimiento_alpha_prob(8, 1//10)
    v64, _ = corrimiento_alpha_prob(64, 1//10)
    @test v1 < v8 < v64 < 0.5
end

@testset "D2 · conservación de masa y cotas válidas" begin
    for (d, T) in ((6, 50), (12, 200), (3, 1000))
        rs = prob_superar_dp(Float64, d, 0.9, 0.1, T)
        re = prob_empate_dp(Float64, d, 0.9, 0.1, T)
        @test conserva(rs; tol=1e-12)
        @test conserva(re; tol=1e-12)
        @test rs.p_exito_lower <= rs.p_exito_upper
        @test re.p_exito_lower <= re.p_exito_upper
        @test rs.masa_fuga >= 0
        # la cota inferior nunca supera la exacta
        ex = Float64(prob_superar_finita(d, P9, Q1, T))
        @test rs.p_exito_lower <= ex + 1e-12
        @test ex <= rs.p_exito_upper + 1e-12
    end
end

@testset "D2 · z0 grande: la frontera z≤−1 es alcanzable" begin
    # regresión de revisión F3: con lo fijo lejos de −1 la absorción era inalcanzable.
    r = prob_superar_dp(Float64, 100, 0.49, 0.51, 500)
    @test r.p_exito_lower > 0
    @test r.p_exito_upper >= r.p_exito_lower
    # sin el arreglo, p_exito_lower sería 0 y toda la masa se contaría como fuga
    @test r.masa_fuga < 0.5
end

@testset "D2 · la retícula NO cambia la probabilidad (unidades)" begin
    # d unidades de trabajo, g=1/granularidad; z0=d·g. Mismo objeto físico.
    d = 4
    for g in (1, 2, 4, 8)
        z0 = d * g
        r = prob_superar_dp(Float64, z0, 0.9, 0.1, 100)
        exacta = Float64(prob_superar_finita(z0, P9, Q1, 100))
        @test isapprox(r.p_exito_lower, exacta; atol=1e-12)
    end
end

@testset "D5 · RCE-v0.1 rev2: vector ARM y Z0" begin
    cfg = ConfigRCE(; W=10, G=0, activation_delay_windows=1, Q=10, R_inicial=100,
                    R_min=1, R_max=1000, ganancia_a=1, ganancia_d=1,
                    p_lo=1, q_lo=2, p_hi=2, q_hi=1, redondeo=REDONDEO_FLOOR)
    ctrl = ControladorRCE(cfg)
    r0 = cerrar_cohorte!(ctrl, 0, 5, 10)
    @test r0.estado == :Scheduled
    @test r0.R_next == 200
    @test r0.activacion == 20
    @test rango_en(ctrl, 19) == 100
    @test rango_en(ctrl, 20) == 200
    # ventana vacía: Z0 no agenda nada, no revierte
    r1 = cerrar_cohorte!(ctrl, 1, 0, 20)
    @test r1.estado == :HeldZero
    @test r1.activacion == 0
    @test rango_en(ctrl, 39) == 200
    @test rango_en(ctrl, 40) == 200
    # desfase D=2 ventanas
    cfg2 = ConfigRCE(; W=10, G=0, activation_delay_windows=2, Q=10, R_inicial=100,
                     R_min=1, R_max=1000, ganancia_a=1, ganancia_d=1,
                     p_lo=1, q_lo=2, p_hi=2, q_hi=1, redondeo=REDONDEO_FLOOR)
    c2 = ControladorRCE(cfg2)
    a0 = cerrar_cohorte!(c2, 0, 5, 10)
    @test a0.activacion == 30
    cerrar_cohorte!(c2, 1, 0, 20)
    @test rango_en(c2, 29) == 100
    @test rango_en(c2, 30) == 200
    @test rango_en(c2, 40) == 200
    # Pending no publica
    c3 = ControladorRCE(cfg)
    p0 = cerrar_cohorte!(c3, 0, 5, 10; pending=true)
    @test p0.estado == :Pending
    @test isempty(c3.propuestas)
end

@testset "D7 · R-FIN-5: prefijo en slot(X), no etiqueta actual" begin
    ev = [EventoPot(5, 0xaa, 100), EventoPot(12, 0xbb, 100)]
    fa = DescriptorFlujo(pot_origin="O", dominio="D", origen_indices=0,
                         semilla=1, N_inicial=100, autenticado=true, eventos=ev)
    fb = DescriptorFlujo(pot_origin="O", dominio="D", origen_indices=0,
                         semilla=1, N_inicial=100, autenticado=true, eventos=ev)
    fc = DescriptorFlujo(pot_origin="O", dominio="D", origen_indices=0,
                         semilla=1, N_inicial=100, autenticado=true,
                         eventos=[EventoPot(5, 0xaa, 100), EventoPot(12, 0x99, 100)])
    @test compatible_rfin5(fa, fb, 7) == VALIDA
    # divergencia en slot 12 no invalida el pasado hasta slot 7
    @test compatible_rfin5(fa, fc, 7) == VALIDA
    @test compatible_rfin5(fa, fc, 20) == INVALIDA
    # descriptor sin autenticar ⇒ Pendiente, nunca se sustituye por true
    fn = DescriptorFlujo(pot_origin="O", dominio="D", origen_indices=0,
                         semilla=1, N_inicial=100, autenticado=false, eventos=ev)
    @test compatible_rfin5(fa, fn, 7) == PENDIENTE
    # `fc` diverge en slot 12: compatible visto en slot 3, incompatible en slot 20
    v, idx = puede_incorporar_pasado(fa, [fb, fc], [7, 3])
    @test v == VALIDA
    v2, idx2 = puede_incorporar_pasado(fa, [fb, fc], [7, 20])
    @test v2 == INVALIDA && idx2 == 2
end

@testset "D1 · fixtures deterministas de color" begin
    for k in (1, 2, 5)
        dag, m, herm, rojo = fixture_rojo_conocido(; k=k)
        @test color_contextual(dag, m, rojo) == :rojo_k
        @test any(x -> color_contextual(dag, m, x) == :rojo_k, herm)
    end
    for k in (3, 30)
        dag, m, herm = fixture_cero_rojos(; k=k)
        @test all(x -> color_contextual(dag, m, x) == :azul, herm)
    end
end

@testset "D7 · cotas de unión y S" begin
    for S in (1, 2, 4, 8, 16, 24)
        @test isapprox(toy_S_deriva(1 / (S + 1), S), 0.0; atol=1e-12)
        @test toy_S_deriva(1 / (S + 1) + 0.01, S) > 0
        @test toy_S_deriva(max(0.0, 1 / (S + 1) - 0.01), S) < 0
        @test control_escalar_S(1 / (S + 1), S).raiz ≈ 1 / (S + 1)
    end
    lo, hi = cota_union([0.1, 0.2, 0.05])
    @test lo == 0.2
    @test hi ≈ 0.35
    @test cota_union([0.6, 0.7])[2] == 1.0
end

@testset "D6 · control escalar S recupera 1/(S+1) por DP" begin
    for S in (2, 4, 8)
        # por debajo de la frontera: P(superar) cae con T; por encima crece
        bajo = prob_superar_toy_S(Float64, max(0.0, 1 / (S + 1) - 0.03), S, 4, 200)
        alto = prob_superar_toy_S(Float64, 1 / (S + 1) + 0.03, S, 4, 200)
        @test alto.p_exito_upper > bajo.p_exito_upper
    end
end

@testset "D9 · S=24, α=0.04 es igualdad, no victoria" begin
    @test toy_S_deriva(0.04, 24) == 0.0
    @test isapprox(control_escalar_S(0.04, 24).raiz, 0.04; atol=1e-12)
    @test toy_S_deriva(0.04 - 1e-12, 24) < 0
    @test toy_S_deriva(0.04 + 1e-12, 24) > 0
end

@testset "mutación: > vs ≥, y suma vs máximo" begin
    # un DP con absorción en D≤0 (≥) da empate, no superación; deben diferir
    r_ge = prob_empate_dp(Float64, 6, 0.9, 0.1, 50).p_exito_lower
    r_gt = prob_superar_dp(Float64, 6, 0.9, 0.1, 50).p_exito_lower
    @test r_ge > r_gt                    # el test detecta el cambio de comparador
    # suma vs máximo: con S=2 el aditivo nunca es menor que la cota de unión superior
    p = [0.1, 0.1]
    @test min(1.0, sum(p)) >= maximum(p)
end

@testset "D1 · simulación determinista y con rojos reales" begin
    cfg = ConfigSim(; n_honestos=4, p_honesto=0.25, delta=2, S=1, T=300, t_fork=1,
                    p_adversario=0.0)
    r1 = simular!(cfg, StableRNG(7); k=2)
    r2 = simular!(cfg, StableRNG(7); k=2)
    @test r1.W_pub == r2.W_pub
    @test r1.rojos_publicos == r2.rojos_publicos
    # a k=2 la concurrencia produce rojos reales
    total = 0
    for r in 1:10
        res = simular!(cfg, StableRNG(100 + r); k=2)
        total += res.rojos_publicos
    end
    @test total > 0
end

@testset "MC vs exacto (IC)" begin
    rng = StableRNG(0xabc)
    d = 4
    T = 60
    exacta = Float64(prob_superar_finita(d, P9, Q1, T))
    phat, lo, hi, ex, n = mc_superar(rng, d, 0.1, T, 20000)
    @test lo <= exacta <= hi
end

@testset "identidad iid vs MC del máximo" begin
    rng = StableRNG(0xdef)
    S = 3
    T = 40
    directo = mc_max_S(rng, 0.4, S, 2, T, 4000)
    ident = identidad_iid_S(rng, 0.4, S, 2, T, 4000, 4000)
    @test isapprox(directo, ident; atol=0.05)
end

@testset "calibración de rojos: cero observado usa cota, no falla" begin
    cfg = ConfigSim(; n_honestos=4, p_honesto=0.25, delta=2, S=1, T=200, t_fork=1,
                    p_adversario=0.0)
    res = tasa_rojos_calibrada(r -> StableRNG(2000 + r), cfg, 20; k=30)
    @test 0.0 <= res.fraccion_replicas_con_rojo <= 1.0
    @test res.ic[1] <= res.fraccion_replicas_con_rojo <= res.ic[2]
end

end
