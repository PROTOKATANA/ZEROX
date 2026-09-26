#= SL-2 · test/runtests.jl
   Regresión: casos de MODELO §4 (continuidad con DS-3), equivalencia entre vías (LINEO §7, §10),
   corrección de la región de retención (REVISION-DS3), y la calibración SL-2 (región y bordes).
=#

using Test
using SL2

const SEMILLA = UInt64(0x5a5a)

"Escenario base de prueba (Pareto, vía P1 fiel a DS-3)."
function escenario_prueba(; dist = ParetoDist(1e-8, 2.5, 1e-3), V = 1e4, f = 1.0, qg = 20.0,
                          R = 0.0, eh = 1e-3, fh = 1e-3, via = :P1, P = 1e-3, eps = 0.01)
    Escenario(dist, V, f, qg, 10.0, 1.0, 1.0, 1.0, 1.0, eps, R, 1019.0, P, eh, fh, 0.01, via)
end

@testset "SL-2" begin

@testset "SL-2 · continuidad con DS-3 (MODELO §4)" begin
    # §4.2 ventana
    r = Reparto(0.33, 0.0)
    P = primera_dp(p_de_alpha(r), deficit_entero(r, 1019), 1019).paso
    @test P ≈ 9.75e-108 rtol = 1e-3
    @test deficit_entero(r, 1019) == 346
    # §4.3 retención
    @test exp(-0.36) ≈ 0.69768 atol = 1e-5
    @test p_saldo_cero(1.0, 0.36, Retencion(1.0, 1.0)) == exp(-0.36)
    # §4.4 grieta Pareto (checkpoint de DS-3)
    @test B_par(Pareto(1e-8, 2.2), 0.01 / 3600) ≈ 0.675466 atol = 1e-5
    @test B_par(Pareto(1e-8, 2.2), 0.01 / 100000) ≈ 0.369 atol = 2e-3
    # corrección REVISION-DS3: α*(βd=0.34) = 0.33
    @test alpha_estrella(0.34, 0.0, 1.0, 1.0) ≈ 0.33 atol = 1e-15
    @test beta_cruce(0.33) ≈ 0.34 atol = 1e-15
end

@testset "SL-2 · equivalencia de vías (LINEO §7, §10)" begin
    vp = validar_primera_pasada()
    @test vp.celdas > 200
    @test vp.error_max < 1e-9
    @test vp.celdas_enum > 100
    @test vp.error_enum < 1e-9
    @test validar_alpha().error_max < 1e-14
end

@testset "SL-2 · B(ε): cerrada, exacta y Monte Carlo" begin
    # fórmula cerrada vs cuadratura numérica independiente
    for al in (2.05, 2.5, 3.0)
        x = 0.01 / 3600
        cerrada = B_par(Pareto(1e-8, al), x)
        exacta = B_par_exacta(1e-8, al, x; F_max = Inf)
        @test cerrada ≈ exacta rtol = 1e-3
    end
    # MC contiene a la cerrada (α dócil)
    vb = validar_Bpar(3.0, 0.01 / 3600; m = 50_000, nrep = 100)
    @test vb.err_exacta < 1e-4
    @test vb.dentro
    # régimen truncado (α ≤ 2, el que midió DS-6)
    ct = B_par(Pareto(1e-8, 1.86), 0.01 / 3600)
    et = B_par_exacta(1e-8, 1.86, 0.01 / 3600; F_max = 1.0)
    @test ct ≈ et rtol = 1e-3
end

@testset "SL-2 · B empírico de DS-6 (datos congelados)" begin
    ruta = joinpath(@__DIR__, "..", "datos", "farmers-raw.csv")
    crudos = cargar_farmers(ruta)
    limpios = limpiar_farmers(crudos)
    @test length(limpios) == 2453
    tibs = Float64[g.tib for g in limpios]
    emp = empirica(tibs)
    # valor de DS-6 Corrección A (ε=0.01, Tv=3600)
    @test B_empirico(emp, 0.01 / 3600) ≈ 1.78e-4 rtol = 0.05
    # monótono en x y bootstrap contiene el directo
    vb = validar_Bemp(emp, 0.01 / 3600, SEMILLA; nrep = 3000)
    @test vb.monotono
    @test vb.dentro
end

@testset "SL-2 · región (ρ_ret, T_v): bordes y monotonía" begin
    esc = escenario_prueba()
    # β_d de α=0.33, P*=1e-3 ~ 0.279 (DS-3)
    bm = beta_minimo_para_p(0.33, 1019.0, 1e-3)
    @test 0.25 < bm.βd < 0.30
    # con la vía P1 y q_g=20, la región existe y los bordes son los correctos
    reg = region_tv(esc, bm.βd; ρ_ret = 0.5)
    @test reg.existe
    @test reg.Tv_min >= 1019.0
    @test reg.Tv_max > reg.Tv_min
    @test reg.borde_inf in ("A (disuasión)", "F (viabilidad T_v>F)")
    @test reg.borde_sup == "honesto"
    vr = validar_region(esc, bm.βd, 0.5)
    @test vr.existe && vr.a_en_min && vr.b_en_max
    # κ·q_ev = 0 vacía la región
    esc0 = escenario_prueba()
    esc0 = Escenario(esc0.dist, esc0.V, esc0.f_conf, esc0.q_g, esc0.c_r, esc0.I, esc0.λ, 0.0,
                     esc0.q_ev, esc0.eps_saldo, esc0.R_slots, esc0.F_slots, esc0.P_obj,
                     esc0.eps_h, esc0.f_h, esc0.frac_max, esc0.via_perdida)
    @test !region_tv(esc0, bm.βd; ρ_ret = 0.5).existe
    # V enorme vacía la región por A; ε_h enorme la vacía por honestidad
    @test !region_tv(escenario_prueba(V = 1e15), bm.βd; ρ_ret = 0.5).existe
    @test !region_tv(escenario_prueba(eh = 1e9), bm.βd; ρ_ret = 0.5).existe
    # más ρ_ret ensancha la disuasión (Tv_min baja) y agrava la honestidad (Tv_max baja);
    # puede además vaciar la región por honestidad, así que se comprueba condicionada
    r1 = region_tv(esc, bm.βd; ρ_ret = 0.25)
    r2 = region_tv(esc, bm.βd; ρ_ret = 1.00)
    if r1.existe && r2.existe
        @test r2.Tv_min <= r1.Tv_min + 1e-9
        @test r2.Tv_max <= r1.Tv_max + 1e-9
    else
        @test true
    end
end

@testset "SL-2 · Monte Carlo independiente y reproducible" begin
    dp = primera_dp(1 / 3, 5, 400).paso
    mc_ser = mc_ventana(1 / 3, 5, 400, 20000, SEMILLA; hilos = false)
    mc_par = mc_ventana(1 / 3, 5, 400, 20000, SEMILLA; hilos = true)
    @test mc_ser.p_paso == mc_par.p_paso          # reducción determinista, sin carreras
    @test mc_ser.ic_paso[1] <= dp <= mc_ser.ic_paso[2]

    ex = exp(-0.36)
    mcs = mc_saldo_cero(0.36, 20000, SEMILLA)
    @test mcs.ic[1] <= ex <= mcs.ic[2]

    esc = escenario_prueba()
    mch = mc_honesto(esc, 0.5, 3600.0; nrep = 20000, semilla = SEMILLA)
    cerrada = esc.eps_h * perdida_castigo(esc; ρ_ret = 0.5, Tv = 3600.0)
    @test abs(mch.media - cerrada) / cerrada < 0.05

    @test hash64(SEMILLA, UInt64(1)) != hash64(SEMILLA, UInt64(2))
end

end # @testset SL-2
