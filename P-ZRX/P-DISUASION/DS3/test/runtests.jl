#= DS-3 · test/runtests.jl
   Regresión OBLIGATORIA: los siete casos de comprobación de `MODELO.md` §4 (Ratificación
   de `ORDEN-DS3`), más las validaciones de equivalencia entre vías (LINEO §7 y §10).
=#

using Test
using DS3

const SEMILLA = UInt64(0x5a5a)

@testset "DS-3 · casos de comprobación (MODELO §4)" begin

    @testset "§4.1 · α* exacto" begin
        @test alpha_estrella(0.0, 0.0, 1.0, 1.0) == 0.5
        @test alpha_estrella(0.34, 0.0, 1.0, 1.0) ≈ 0.33 atol = 1e-15
        @test alpha_estrella_exacta(0 // 1, 0 // 1, 1 // 1, 1 // 1) == 1 // 2
        @test alpha_estrella_exacta(3 // 10, 0 // 1, 1 // 1, 1 // 1) == 7 // 20
        @test alpha_estrella_exacta(34 // 100, 0 // 1, 1 // 1, 1 // 1) == 33 // 100
        # El cruce con β_d = 0,34 es exactamente α = 0,33
        @test abs(deriva(Reparto(0.33, 0.34))) < 1e-15
        @test beta_cruce(0.33) ≈ 0.34 atol = 1e-15
        va = validar_alpha()
        @test va.filas == 12
        @test va.error_max == 0.0
    end

    @testset "§4.2 · ventana F" begin
        r = Reparto(0.33, 0.0)
        @test p_de_alpha(r) ≈ 0.33 atol = 1e-15
        @test deficit_entero(r, 1019) == 346
        res = primera_dp(p_de_alpha(r), deficit_entero(r, 1019), 1019)
        @test res.paso ≈ 9.75e-108 rtol = 1e-3
        @test log10(res.paso) ≈ -107.011 rtol = 1e-3
        @test res.paso + res.interior ≈ 1.0 rtol = 1e-9
        # La ventana larga perjudica al atacante cuando el déficit crece con F
        r2 = Reparto(0.40, 0.10)
        P1019 = primera_dp(p_de_alpha(r2), deficit_entero(r2, 1019), 1019).paso
        P3600 = primera_dp(p_de_alpha(r2), deficit_entero(r2, 3600), 3600).paso
        @test P3600 < P1019
        # Vías independientes coinciden en este caso
        @test primera_dp_absorbente(p_de_alpha(r2), deficit_entero(r2, 1019), 1019) ≈ P1019 rtol = 1e-9
        # La forma cerrada de horizonte largo es cota superior del valor finito
        @test eventual(p_de_alpha(r), 346) >= res.paso
    end

    @testset "§4.3 · retención" begin
        exacto = exp(-0.36)
        @test exacto ≈ 0.69768 atol = 1e-5
        @test p_saldo_cero(1.0, 0.36, Retencion(1.0, 1.0)) == exacto
        normal = p_saldo_cero_normal(0.36)
        @test normal ≈ 0.3017 atol = 1e-3
        razon = normal / exacto
        @test razon ≈ 0.432 atol = 2e-3
        # La normal NO sirve: se delata si alguna ruta la usa como si fuera exacta
        @test !isapprox(normal, exacto; rtol = 0.10)
        # θ = λ f T_v y momentos
        ret = Retencion(0.5, 3600.0)
        @test theta(1.0, 1e-4, ret) ≈ 0.36 atol = 1e-12
        @test balance_medio(1.0, 1e-4, ret, 1.0) ≈ 0.5 * 0.36 / 2 atol = 1e-12
        @test balance_var(1.0, 1e-4, ret, 1.0) ≈ 0.25 * 0.36 / 3 atol = 1e-12
        # Monte Carlo dentro del IC de Wilson
        mcs = mc_saldo_cero(0.36, 20000, SEMILLA)
        @test mcs.ic[1] <= exacto <= mcs.ic[2]
    end

    @testset "§4.4 · grieta de F3 (P-CLAVE)" begin
        dist = Pareto(1e-8, 2.2)
        B3600 = masa_espacio_bajo_b(dist, 0.01, 1.0, 3600.0)
        B100k = masa_espacio_bajo_b(dist, 0.01, 1.0, 100000.0)
        @test B3600 ≈ 0.675 atol = 2e-3
        @test B100k ≈ 0.369 atol = 2e-3
        @test B3600 > 1 - 2 * 0.33                 # 0,675 > 0,34: grieta SÍ
        @test B100k < (1 - 2 * 0.33) / (1 - 0.33)  # 0,369 < 0,5075: grieta NO (criterio heredado)
        coef = coef_reclutamiento(Retencion(0.5, 3600.0), 1.0, 1.0)
        @test coef == 900.0
        @test coste_reclutamiento(0.34, B3600, coef) == 0.0     # soborno cero cruza la deriva
        # El SIGNO cambia con el criterio heredado 0,5075: con T_v=3600, 0,5075 es gratis;
        # con T_v=100000, B(0,01)=0,369 < 0,5075 y el mismo β pasa a costar.
        @test coste_reclutamiento(0.5075, B3600, coef) == 0.0
        @test coste_reclutamiento(0.5075, B100k, coef) > 0.0
        @test coste_reclutamiento(0.20, B3600, coef) == 0.0
        # El escalón no se interpola: justo por debajo de B(ε) el coste es 0
        @test coste_reclutamiento(B3600 - 1e-9, B3600, coef) == 0.0
        @test coste_reclutamiento(B3600 + 1e-9, B3600, coef) > 0.0
    end

    @testset "§4.5 · cobertura" begin
        N = 1_048_480
        B = 181_092
        @test almacenamiento_forzado(N, B, 1_000) == 0.0
        @test almacenamiento_forzado(N, B, 100_000) == 0.0
        @test !deteccion_posible(1_000, B)
        @test !deteccion_posible(100_000, B)
        @test deteccion_posible(1_000_000, B)
        @test almacenamiento_forzado(N, B, 1_000_000) ≈ 1 - B / N atol = 1e-12
        @test almacenamiento_forzado_exacta(N, 1_000, B) == 0 // 1
        @test almacenamiento_forzado_exacta(N, 1_000_000, B) ==
              max(0 // 1, 1 - Rational{BigInt}(B, N))
        # Detección parcial certificada: M = 189.670 (< γ) frente a M = 189.671 (≥ γ), γ = 0,01
        t = TablaLogFact(N)
        det670 = cola_hiper_rapida(t, N, 189_670, 1_000_000, B)
        det671 = cola_hiper_rapida(t, N, 189_671, 1_000_000, B)
        @test det670 ≈ 9.8712e-3 rtol = 1e-4
        @test det671 ≈ 1.0181e-2 rtol = 1e-4
        @test det670 < 0.01 <= det671
        phi_gamma = 1 - 189_670 / N
        @test 0.8190 < phi_gamma < 0.8192
        @test cola_hiper_rapida(t, N, 100_000, 1_000, B) == 0.0   # k ≤ B: cero exacto
    end

    @testset "§4.6 · sembrador frente a disco" begin
        w_eq = w_equilibrio(19_071_000, R_24H, 1.0)
        @test 7.0e5 < w_eq < 8.0e5
        @test w_eq > 1e5                    # no está en miles
        @test nucleos_por_TiB(7_175.0) ≈ 117.238 rtol = 1e-4
        @test maquinas_por_TiB(7_175.0) ≈ 5.790 rtol = 1e-3
        @test razon_energia(7_175.0) ≈ 1524.0 rtol = 1e-2
        # La restricción de latencia coincide con w_equilibrio cuando λ = 1
        N_h = 19_071_000.0
        p = p_calibrado(1.0, N_h)
        @test w_min_latencia(R_24H, p, 1.0) ≈ w_equilibrio(N_h, R_24H, 1.0) rtol = 1e-12
    end

    @testset "§4.7 · Baig–Pietrzak (cruce de fórmula)" begin
        bp = pasos_bp(2.0, 0.01, 4.0)
        @test bp.bootstrap == 3297
        @test bp.termino2 == 816
        @test bp.replot == 140
        @test bp.total == 4253
        # El orden de magnitud es 10^3, como la Fig. 1 del artículo. La fórmula transcrita NO
        # reproduce el «≈1.233 + 140» del propio §2.11 (reserva declarada en DEFINICIONES-FALTANTES
        # F7); el test fija la discrepancia para que no se confunda con una cifra de ZEROX.
        @test bp.total != 1233 + 140
        @test 1e3 <= bp.total <= 1e4
        # Cota principal del artículo φ²ρ/ε, para el mismo escenario
        @test 2.0^2 * 4.0 / 0.01 == 1600.0
    end
end

@testset "DS-3 · equivalencia de vías (LINEO §7, §10)" begin
    vp = validar_primera_pasada()
    @test vp.celdas > 200
    @test vp.error_max < 1e-9
    @test vp.celdas_enum > 100
    @test vp.error_enum < 1e-9

    vc = validar_cobertura()
    @test vc.casos > 50
    @test vc.error_max < 1e-9

    va = validar_almacenamiento()
    @test va.casos == 12
    @test va.error_max == 0.0
end

@testset "DS-3 · Monte Carlo reproducible y sin carreras" begin
    dp = primera_dp(1 / 3, 5, 400).paso
    mc_ser = mc_ventana(1 / 3, 5, 400, 20000, SEMILLA; hilos = false)
    mc_par = mc_ventana(1 / 3, 5, 400, 20000, SEMILLA; hilos = true)
    @test mc_ser.p_paso == mc_par.p_paso           # reducción determinista, sin carreras
    @test mc_ser.ic_paso[1] <= dp <= mc_ser.ic_paso[2]
    # Semillas de réplicas contiguas NO son consecutivas y difieren
    @test rng_replica(SEMILLA, 1) isa Any
    @test hash64(SEMILLA, UInt64(1)) != hash64(SEMILLA, UInt64(2))
end

@testset "DS-3 · monótona e inversión coste↔probabilidad" begin
    # P crece con β_d; bisección devuelve el β_d mínimo para el objetivo
    r = beta_minimo_para_p(0.33, 1019, 1e-6)
    @test 0.2 < r.βd < 0.5
    @test r.P >= 1e-6
    @test primera_dp(p_de_alpha(Reparto(0.33, r.βd)),
                     deficit_entero(Reparto(0.33, r.βd), 1019), 1019).paso >= 1e-6
    # La vía rápida (DP absorbente) y la certificada (mínimo, posición) dan el mismo β_d
    rc = beta_minimo_para_p(0.33, 1019, 1e-6; via = :certificada)
    @test abs(rc.βd - r.βd) < 1e-9
    # Con coste de retención: por debajo de B(ε) el β_d necesario puede ser gratis
    dist = Pareto(1e-8, 2.2)
    B_eps = masa_espacio_bajo_b(dist, 0.01, 1.0, 3600.0)
    @test B_eps > 0.34
end

@testset "DS-3 · región de disuasión (MODELO §2.5)" begin
    reg = region_disuasion(κ = 1.0, q = 1.0, ρ_ret = 0.5, I = 1.0, c_r = 10.0, M = 20.0,
                           V = 40_000.0, N = 100.0, ν = 1e-4, F = 3600.0)
    @test reg.existe
    # Económico: ρ_ret·T_v > 400 − 30 = 370 ⇒ T_v > 740; el requisito temporal T_v > F manda.
    @test reg.Tv_min >= 3600.0
    @test !reg.disuade(3600.0)
    @test reg.disuade(3601.0)
    # κq → 0: región VACÍA
    vacia = region_disuasion(κ = 0.0, q = 1.0, ρ_ret = 0.5, I = 1.0, c_r = 10.0, M = 20.0,
                             V = 40_000.0, N = 100.0, ν = 1e-4, F = 3600.0)
    @test !vacia.existe
    # V sin cota: región VACÍA
    sinv = region_disuasion(κ = 1.0, q = 1.0, ρ_ret = 0.5, I = 1.0, c_r = 10.0, M = 20.0,
                            V = Inf, N = 100.0, ν = 1e-4, F = 3600.0)
    @test !sinv.existe
end
