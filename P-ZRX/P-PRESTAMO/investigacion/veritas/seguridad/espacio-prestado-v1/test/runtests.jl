#= espacio-prestado-v1 · runtests.jl
   Controles de corrección. Perfil de referencia: `--check-bounds=yes` (LINEO §7).
=#

using Test
using Random123          # Philox4x64 debe estar en Main: el módulo no lo importa

include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
include(joinpath(@__DIR__, "..", "src", "referencia.jl"))
include(joinpath(@__DIR__, "..", "src", "rapido.jl"))
include(joinpath(@__DIR__, "..", "src", "validacion.jl"))

using .Modelo
using .Referencia
using .Rapido
using .Validacion

const R = Rational{BigInt}

@testset "F1 · deriva y frontera exactas" begin
    for (βd, βx, ηh, ηa) in ((0//1, 0//1, 1//1, 1//1),
                             (1//3, 0//1, 1//1, 1//1),
                             (0//1, 1//4, 1//1, 1//1),
                             (1//4, 1//8, 3//2, 1//1),
                             (1//10, 1//10, 99//100, 1//1))
        αs = alpha_estrella(βd, βx, ηh, ηa)
        @test deriva(Deriva(αs, βd, βx, ηh, ηa)) == 0
        ε = 1//10^9
        @test deriva(Deriva(αs + ε, βd, βx, ηh, ηa)) > 0
        @test deriva(Deriva(αs - ε, βd, βx, ηh, ηa)) < 0
    end
    @test alpha_estrella(0//1, 0//1, 1//1, 1//1) == 1//2
    @test alpha_estrella(1//3, 0//1, 1//1, 1//1) == 1//3
    @test alpha_estrella(1//2, 0//1, 1//1, 1//1) == 1//4
    for α in (0//1, 1//10, 1//3, 2//5, 1//2)
        βc = 1 - 2α
        βc + 1//100 ≤ 1 && @test region_gana(Deriva(α, βc + 1//100, 0//1, 1//1, 1//1))
        βc - 1//100 ≥ 0 && @test !region_gana(Deriva(α, βc - 1//100, 0//1, 1//1, 1//1))
    end
    @test alpha_estrella(0//1, 1//5, 1//1, 1//1) == 3//10
    @test alpha_estrella(1//4, 0//1, 1//1, 1//1) == 3//8
    @test alpha_estrella(0//1, 1//4, 1//1, 1//1) == 1//4
    @test alpha_estrella(1//4, 0//1, 1//1, 1//1) - alpha_estrella(0//1, 1//4, 1//1, 1//1) == 1//8
    @test alpha_estrella(0//1, 1//4, 1//1, 1//1) == alpha_estrella(1//2, 0//1, 1//1, 1//1)
    @test alpha_estrella(1//4, 1//4, 1//1, 1//2) > alpha_estrella(1//4, 1//4, 1//1, 1//1)
    @test alpha_estrella(1//4, 1//4, 2//1, 1//1) > alpha_estrella(1//4, 1//4, 1//1, 1//1)
    @test espacio_valido(Deriva(1//5, 1//5, 1//5, 1//1, 1//1))
    @test !espacio_valido(Deriva(1//2, 1//2, 1//2, 1//1, 1//1))
end

@testset "F2 · puente espacio→tasa y déficit" begin
    for (α, βd, βx) in ((1//10, 0//1, 0//1), (1//3, 1//5, 0//1), (2//5, 0//1, 1//10))
        p = p_de_alpha(α, βd, βx)
        @test isapprox(alpha_de_p(p, βd, βx), Float64(α); atol = 1e-12)
    end
    @test p_de_alpha(alpha_estrella(1//3, 0//1, 1//1, 1//1), 1//3, 0//1, 1//1, 1//1) == 1//2
    @test deficit_esperado(1//10, 0//1, 0//1, 1//1, 1//1, 100) == 80//1
    @test deficit_esperado(1//2, 0//1, 0//1, 1//1, 1//1, 100) == 0//1
    @test deficit_esperado(2//3, 0//1, 0//1, 1//1, 1//1, 100) == -100//3
end

@testset "F2 · DP (mínimo, posición) contra enumeración exhaustiva" begin
    for d in (0, 1, 3, 8), T in 0:d
        r = primera_dp(R(2)//3, d, T)
        @test r.paso == 0
        @test r.interior == 1
    end
    @test primera_dp(R(2)//3, 0, 1).paso == 2//3          # D
    @test primera_dp(R(2)//3, 0, 2).paso == 2//3          # D (una sola visita por clase)
    # Vectores calculados a mano (clases por primera visita y revisitas):
    # (p,d,T)=(1/3,0,3): 5/27 (clase en T=3) + 2/9 (clase en T=2) = 11/27.
    # (2/3,0,3): 8/27 + 16/81 + 20/81 = 22/27.
    @test primera_dp(R(1)//3, 0, 3).paso == 11//27
    @test primera_dp(R(2)//3, 0, 3).paso == 22//27
    @test primera_dp(R(1)//3, 2, 3).paso == 1//27         # DDD
    @test primera_dp(R(2)//5, 3, 4).paso == 16//625       # DDDD
    @test primera_dp(R(2)//5, 3, 5).paso == 16//625       # misma masa: paridad
    filas = Validacion.validar_dp([R(2)//3, R(1)//2, R(2)//5, R(1)//3, R(9)//10, R(1)//10],
                                  [0, 1, 2, 3, 5, 7], [0, 1, 2, 3, 5, 8, 12, 16])
    @test all(f -> f.coincide, filas)
    @test all(f -> f.ok, filas)
    @test Validacion.terminal_de_dp(R(2)//5, 3, 5) == 0
    @test Validacion.terminal_de_dp(R(2)//5, 3, 4) == 16//625
    # Horizonte largo en Float64 (el exacto a T=4.000 es inviable en Rational{BigInt}).
    # p < 1/2 ⇒ P_eventual = 1: la ventana se acerca a 1 y NUNCA lo supera.
    for (p, d) in ((0.4, 2), (1/3, 2))
        @test primera_dp(p, d, 4_000).paso ≤ 1.0
        @test primera_dp(p, d, 4_000).paso > primera_dp(p, d, 200).paso
    end
    @test primera_dp(0.6, 0, 400).paso > 0.999
    # Con el adversario en MINORÍA (q < p) la probabilidad es (q/p)^(d+1), que es
    # EXACTAMENTE la fórmula de BASELINE.md escenario 0. El primer argumento es q (la
    # tasa del ADVERSARIO); con p = 1−q la tasa del honesto, q < p ⟺ q < 1/2.
    @test p_superar_exacto(R(1)//3, 5) == (R(1)//2)^6     # q=1/3, p=2/3 ⇒ (q/p)^6
    @test p_superar_exacto(R(2)//5, 2) == (R(2)//3)^3     # q=2/5, p=3/5 ⇒ (q/p)^3
    @test p_superar_exacto(R(0)//1, 4) == 0               # q=0 ⇒ 0/1 = 0 (no NaN)
    # Con el adversario en MAYORÍA (q ≥ p) la probabilidad de superar es 1 (no (p/q)^k).
    @test p_superar_exacto(R(2)//3, 1) == 1
    @test p_superar_exacto(R(3)//5, 0) == 1
    @test p_superar_exacto(R(1)//2, 3) == 1              # q = p = 1/2
    # Y con el adversario en minoría la probabilidad es < 1: q=1/10 ⇒ (1/9)^(d+1).
    @test p_superar_exacto(R(1)//10, 0) == 1//9
    @test p_superar_exacto(R(1)//10, 2) == (1//9)^3
    # Reconciliación con BASELINE.md, en su convención (p honesto, q adversario):
    # la DP reproduce (q/p)^(d+1) para q < p en toda la rejilla probada.
    for (ph, qa, d) in ((R(2)//3, R(1)//3, 5), (R(3)//5, R(2)//5, 2), (R(2)//3, R(1)//3, 0),
                        (R(4)//5, R(1)//5, 6))
        @test abs(Float64(primera_dp(qa, d, 400).paso) - Float64((qa/ph)^(d+1))) < 1e-6
    end
end

@testset "kernel rápido · Float64 y BigFloat contra exacto" begin
    filas = Validacion.validar_kernels([(0.6, 3), (0.4, 2), (0.5, 4), (0.3, 1)],
                                       [1, 5, 30]; mc_reps = 20_000)
    @test all(f -> f.err_f < 1e-12, filas)
    @test all(f -> f.err_b < 1e-12, filas)
    @test all(f -> f.mc_ok, filas)
    ps = [0.3, 0.4, 0.5, 0.6]
    ds = collect(0:8)
    ser = rejilla_dp(ps, ds, 120)
    par = rejilla_dp_par(ps, ds, 120)
    @test all(ser[i].paso == par[i].paso for i in eachindex(ser))
    # Conservación en el régimen del encargo: interior + paso = 1 (a tolerancia de redondeo).
    for T in (1_019, 3_600)
        r = primera_dp(0.45, 4, T)
        @test 0.0 ≤ r.paso ≤ 1.0
        @test abs((r.paso + r.interior) - 1.0) < 1e-9
    end
end

@testset "Monte Carlo · RNG contracorriente" begin
    for (p, d, T) in ((0.6, 4, 20), (0.4, 2, 20), (0.45, 0, 50))
        ex = primera_dp(R(p), d, T).paso
        mc = mc_ventana(p, d, T, 20_000, UInt64(0x5a5a5a5a))
        @test mc.ic_paso[1] ≤ Float64(ex) ≤ mc.ic_paso[2]
    end
    a = mc_ventana(0.6, 4, 20, 5_000, UInt64(1))
    b = mc_ventana(0.6, 4, 20, 5_000, UInt64(1))
    @test a.paso == b.paso
    # Dos semillas distintas dan estimaciones compatibles con el valor EXACTO (comparar
    # los dos IC entre sí es demasiado estricto para 5.000 réplicas: sus intervalos pueden
    # rozarse por fluctuación, como se observó y se documenta aquí).
    ex = Float64(primera_dp(R(0.6), 4, 20).paso)
    c = mc_ventana(0.6, 4, 20, 5_000, UInt64(2))
    @test abs(c.paso - ex) ≤ 4 * sqrt(ex * (1 - ex) / 5_000)
    @test abs(a.paso - ex) ≤ 4 * sqrt(ex * (1 - ex) / 5_000)
end

@testset "Juego · pérdida del granjero y soborno" begin
    pg = PerdidaGranjero(1//2, 100//1, 10//1, 0//1, 20//1, 1//1)
    @test perdida_total(pg) == 1//2 * 10 * 100 + 0 + 10 * 20
    @test soborno_necesario(pg, 0//1, 1//1) == 0
    @test soborno_necesario(pg, 0//1, 1//1, 5//1) == -5
    @test soborno_necesario(pg, 1//1, 1//1) == perdida_total(pg)
    @test soborno_necesario(pg, 9//10, 1//1) > soborno_necesario(pg, 1//2, 1//1)
    @test soborno_necesario(pg, 1//1, 1//10) < soborno_necesario(pg, 1//1, 1//1)
    rc1 = RegionCastigo(1_000_000//1, 10//1, 3_600//1)
    rc2 = RegionCastigo(1_000_000//1, 100//1, 3_600//1)
    c1 = coste_absoluto(rc1, pg, 1//1, 1//1, 0//1, 1//5)
    c2 = coste_absoluto(rc2, pg, 1//1, 1//1, 0//1, 1//5)
    @test c2.sobornos == 10 * c1.sobornos
    @test c1.total == c1.sobornos + c1.pot
    @test c1.α_propio == 1//5
end
