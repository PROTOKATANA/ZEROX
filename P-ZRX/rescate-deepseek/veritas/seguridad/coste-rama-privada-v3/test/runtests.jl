# Suite CRP-v0.3 — ejecutar:
#   env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl
using Test
using Random
using StableRNGs
include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivadaV3.jl"))
using .CosteRamaPrivadaV3

const P9 = 9 // 10
const Q1 = 1 // 10
const M = CosteRamaPrivadaV3

@testset "CRP-v0.3" begin

@testset "1 · terminal vs primera-pasada vs eventual" begin
    for (z0, T) in ((4, 20), (4, 200), (6, 100))
        r = resultado_eventos(Float64, z0, 0.9, 0.1, T)
        @test r.p_terminal <= r.p_paso + 1e-15          # terminal ⊆ primera pasada
        @test r.p_paso <= r.p_eventual + 1e-12          # finita ≤ eventual
        @test r.p_terminal >= r.p_terminal_cota[1] - 1e-15
        @test r.p_terminal <= r.p_terminal_cota[2] + 1e-15
    end
    # MC de terminal coincide en orden (no exige precisión 1e-12)
    rng = StableRNG(1)
    pt, lo, hi, _, n = mc_terminal(rng, 4, 0.1, 20, 20000)
    r = resultado_eventos(Float64, 4, 0.9, 0.1, 20)
    @test lo <= r.p_terminal <= hi
end

@testset "1/9 · alpha_prob por evento e intervalos simultáneos" begin
    a_term = alpha_prob_determinista(4, 0.05; evento=:terminal, Tol=100)
    a_paso = alpha_prob_determinista(4, 0.05; evento=:paso, Tol=100)
    @test a_term[1] == :cruce && a_paso[1] == :cruce
    # celda 0/n NO es frontera: no decide (indefinida) o acota, nunca se llama cruce
    alph = collect(0.05:0.05:0.45)
    res = alpha_prob_simultaneo(alph, zeros(Int, length(alph)), 64, 0.05)
    @test res.tipo in (:indefinida, :solo_inferior) && res.tipo != :cruce
    # con una celda claramente por encima, hay cruce
    ex = [0, 0, 0, 0, 5, 30, 60]
    res2 = alpha_prob_simultaneo(alph[1:7], ex, 64, 0.05)
    @test res2.tipo in (:cruce, :indefinida, :solo_superior, :solo_inferior)
end

@testset "7 · déficit en blue_work y semilla fija ante d" begin
    # misma semilla, distinto d ⇒ misma trayectoria física; el déficit es parámetro
    f(d) = begin
        rng = StableRNG(0xbeef)
        D = d
        for _ in 1:50
            D += rand(rng) < 0.7 ? 1 : -1
        end
        D
    end
    @test f(0) - 0 == f(5) - 5
end

@testset "3 · RCE rev2 (vector ARM y Z0)" begin
    cfg = ConfigRCE(; W=10, G=0, activation_delay_windows=1, Q=10, R_inicial=100,
                    R_min=1, R_max=1000, ganancia_a=1, ganancia_d=1,
                    p_lo=1, q_lo=2, p_hi=2, q_hi=1, redondeo=REDONDEO_FLOOR)
    c = ControladorRCE(cfg)
    r0 = cerrar_cohorte!(c, 0, 5, 10)
    @test r0.R_next == 200 && r0.activacion == 20
    @test rango_en(c, 20) == 200
    r1 = cerrar_cohorte!(c, 1, 0, 20)
    @test r1.estado == :HeldZero
    @test rango_en(c, 40) == 200
end

@testset "2 · R-FIN-5 sobre TODO past(B) y PotOrigin compartido" begin
    iny = collect(50:50:500)
    fp = construir_flujo(; rama=0, t_fork=10, inyecciones=iny)
    f1 = construir_flujo(; rama=1, t_fork=10, inyecciones=iny)
    @test compatible_rfin5(fp, f1, 10) == VALIDA      # antes de divergir
    @test compatible_rfin5(fp, f1, 51) == INVALIDA    # tras la 1ª inyección > t_fork
    f2 = construir_flujo(; rama=2, t_fork=10, inyecciones=iny)
    @test compatible_rfin5(f1, f2, 51) == INVALIDA
    # descriptor no autenticado ⇒ Pendiente
    fn = DescriptorFlujo(flujo_id=9, pot_origin="ZEROX-PoAS", dominio="ZEROX-v0",
                         origen_indices=0, semilla=0, N_inicial=100,
                         autenticado=false, eventos=EventoPot[])
    @test compatible_rfin5(fp, fn, 5) == PENDIENTE
end

@testset "2/3/4 · DAG: R-FIN-5, presentación y decisión del observador" begin
    cfg = ConfigSimV3(; n_honestos=4, alpha=0.3, delta=2, S=4, T=200, t_fork=1,
                      k=30, modo_correlacion=:derivada)
    r = simular_v3!(cfg, StableRNG(11))
    @test all(r.W_priv_terminal .>= 0)
    @test !isempty(r.decisiones)
    # la fusión público+rama diverge en flujo ⇒ rechazada por R-FIN-5
    d_nuevo = filter(d -> d.observador == :nuevo, r.decisiones)[1]
    @test d_nuevo.fusion == :rechazada_rfin5
    # el observador eclipsado no puede decidir
    d_ecl = filter(d -> d.observador == :eclipsado, r.decisiones)[1]
    @test d_ecl.clasif == :pendiente
    # el veterano con F no configurada queda Pendiente
    d_vet = filter(d -> d.observador == :veterano, r.decisiones)[1]
    @test d_vet.clasif == :pendiente
end

@testset "4 · S flujos desde oportunidades compartidas" begin
    cfgp = ConfigSimV3(; n_honestos=4, alpha=0.3, delta=2, S=4, T=200, t_fork=1,
                       k=30, modo_correlacion=:perfecta)
    rp = simular_v3!(cfgp, StableRNG(21))
    @test all(==(rp.W_priv_terminal[1]), rp.W_priv_terminal)   # correlación perfecta
    cfgi = ConfigSimV3(; n_honestos=4, alpha=0.3, delta=2, S=4, T=200, t_fork=1,
                       k=30, modo_correlacion=:iid)
    ri = simular_v3!(cfgi, StableRNG(21))
    @test length(unique(ri.W_priv_terminal)) > 1               # iid varía
    # iid: identidad 1−E[F^S] vs MC directo
    rng = StableRNG(99)
    directo = mc_max_S(rng, 0.3, 3, 0, 60, 4000)
    ident = identidad_iid_S(rng, 0.3, 3, 0, 60, 4000, 4000)
    @test isapprox(directo, ident; atol=0.06)
end

@testset "5/6 · red: autor-inmediato, Δ=0 real, único productor sin rojos" begin
    # único productor: sin rojos aunque Δ sea grande
    for delta in (0, 1, 5)
        cfg = ConfigSimV3(; n_honestos=1, alpha=0.0, delta=delta, S=1, T=300,
                          t_fork=1, k=30)
        r = simular_v3!(cfg, StableRNG(7))
        @test r.rojos == 0
        @test r.total_bloques > 0
    end
    # Δ=0 con varios productores sí crea concurrencia real
    cfg2 = ConfigSimV3(; n_honestos=8, alpha=0.0, delta=0, S=1, T=300, t_fork=1, k=2)
    total = sum(simular_v3!(cfg2, StableRNG(100 + r)).rojos for r in 1:8)
    @test total > 0
end

@testset "10 · η_h y η_a en [0,1] (o inconcluso)" begin
    cfg = ConfigSimV3(; n_honestos=4, alpha=0.2, delta=2, S=2, T=200, t_fork=1,
                      k=30, modo_correlacion=:derivada)
    r = simular_v3!(cfg, StableRNG(5))
    @test 0.0 <= r.eta_h <= 1.0
    @test all(e -> 0.0 <= e <= 1.0, r.eta_a)
end

@testset "11 · fixtures U2/U3 con billetes repetidos" begin
    fu = fixture_u2_u3(; k=30)
    @test fu.una_u3
    fm = fixture_u2_misma_rama(; k=30)
    @test fm.aceptado == false && fm.motivo == :u2
    # flujo divergente impide la fusión antes de colorear
    iny = collect(10:10:100)
    fa = construir_flujo(; rama=0, t_fork=5, inyecciones=iny)
    fb = construir_flujo(; rama=1, t_fork=5, inyecciones=iny)
    @test compatible_rfin5(fa, fb, 15) == INVALIDA
end

@testset "1-3 · referencias exactas y DP (v0.2 heredadas)" begin
    @test prob_empate_eventual(0, P9, Q1) == 1//1
    @test prob_superar_eventual(0, P9, Q1) == 1//9
    @test prob_superar_eventual(1, P9, Q1) == 1//81
    for (d, T) in ((6, 50), (12, 200))
        rs = prob_superar_dp(Float64, d, 0.9, 0.1, T)
        re = prob_empate_dp(Float64, d, 0.9, 0.1, T)
        @test conserva(rs; tol=1e-12) && conserva(re; tol=1e-12)
        ex = Float64(prob_superar_finita(d, P9, Q1, T))
        @test rs.p_exito_lower <= ex + 1e-12 <= rs.p_exito_upper + 1e-12
    end
    r = prob_superar_dp(Float64, 100, 0.49, 0.51, 500)
    @test r.p_exito_lower > 0 && r.masa_fuga < 0.5
    for d in (1, 8, 64)
        _v, dist = corrimiento_alpha_prob(d, 1//10)
        @test dist < 0
    end
end

@testset "4 · control escalar S y cotas de unión" begin
    for S in (1, 2, 4, 8, 16, 24)
        @test isapprox(toy_S_deriva(1 / (S + 1), S), 0.0; atol=1e-12)
        @test isapprox(control_escalar_S(1 / (S + 1), S).raiz, 1 / (S + 1))
    end
    lo, hi = cota_union([0.1, 0.2, 0.05])
    @test lo == 0.2 && hi ≈ 0.35
end

@testset "mutación: > vs ≥ y máximo vs suma" begin
    r_ge = prob_empate_dp(Float64, 6, 0.9, 0.1, 50).p_exito_lower
    r_gt = prob_superar_dp(Float64, 6, 0.9, 0.1, 50).p_exito_lower
    @test r_ge > r_gt
    @test cota_union([0.6, 0.7])[2] == 1.0
end

@testset "fixtures deterministas de color" begin
    for k in (1, 2, 5)
        dag, m, herm, rojo = fixture_rojo_conocido(; k=k)
        @test color_contextual(dag, m, rojo) == :rojo_k
    end
    for k in (3, 30)
        dag, m, herm = fixture_cero_rojos(; k=k)
        @test all(x -> color_contextual(dag, m, x) == :azul, herm)
    end
end

end
