using Test
using AdelantoV1

const I_DEF = 851.0
const W_DEF = 20.0

@testset "ADL-v1 — Adelanto con pot_output = salida(f, s+D)" begin

    @testset "1 · Regresión contra SEM-v1 (encargo §2a)" begin
        r = regresion_semv1()
        @test r.maxdiff_nucleo_vs_literal == 0.0
        @test r.maxdiff_D0_vs_literal == 0.0
        @test r.maxerr_tabla_publicada <= 0.005
        @test r.w_publicados_identicos
        @test r.aceptado
        # La tabla publicada, fila a fila (no solo el máximo).
        for k in eachindex(TABLA_SEMV1.rho)
            a = adelanto_nucleo(TABLA_SEMV1.rho[k], TABLA_SEMV1.L[k], I_DEF, W_DEF)
            @test isapprox(a, TABLA_SEMV1.adelanto[k]; atol = 0.005)
            @test desafios_nucleo(TABLA_SEMV1.rho[k], TABLA_SEMV1.L[k], I_DEF, W_DEF) ==
                TABLA_SEMV1.w[k]
        end
    end

    @testset "2 · Bordes de ρ y el acantilado del histórico" begin
        L = 3600.0
        @test adelanto_nucleo(1.0, L, I_DEF, W_DEF) == 0.0
        @test adelanto_nucleo(0.5, L, I_DEF, W_DEF) == 0.0
        # Acantilado: A_core salta de 0 a ≈ L − W_dec − 1 en ρ = 1⁺.
        a = adelanto_nucleo(1.001, L, I_DEF, W_DEF)
        @test a > 0.99 * (L - W_DEF - 1)
        @test a < (L - W_DEF - 1) + 2.0
        # El modelo de fronteras SÍ es continuo en ρ = 1.
        @test adelanto_frontera(1.0, L, I_DEF, W_DEF, 4.0, 1e6) == 0.0
        @test adelanto_frontera(1.0 + 1e-9, L, I_DEF, W_DEF, 4.0, 1e5) < 1e-3
    end

    @testset "3 · D: las tres lecturas y la viabilidad" begin
        L, D = 7200.0, 4.0
        # (i) la generalización primaria resta D, linealmente y solo cuando cabe
        @test adelanto_D(2.0, L, I_DEF, W_DEF, D) ==
            max(0.0, adelanto_nucleo(2.0, L, I_DEF, W_DEF) - D)
        @test adelanto_D(2.0, L, I_DEF, W_DEF, 0.0) == adelanto_nucleo(2.0, L, I_DEF, W_DEF)
        # saciedad en cero: no hay adelanto negativo
        @test adelanto_D(1.001, 200.0, I_DEF, W_DEF, 1e6) == 0.0
        # (ii) el contrafactual "suma" crece con D (prohibido por C-POT-03)
        @test adelanto_add(2.0, L, I_DEF, W_DEF, D) ==
            adelanto_nucleo(2.0, L, I_DEF, W_DEF) + D
        # (iii) el contrafactual incoherente coincide con (i) por construcción
        @test adelanto_sub(2.0, L, I_DEF, W_DEF, D) == adelanto_D(2.0, L, I_DEF, W_DEF, D)
        # viabilidad
        @test vivo(L, W_DEF, L - W_DEF)
        @test !vivo(L, W_DEF, L - W_DEF + 1e-6)
        @test !vivo(L, W_DEF, L)          # D ≥ L: ningún bloque podría avanzar
    end

    @testset "4 · Transitorio y saturación del modelo de fronteras" begin
        L, D, t = 7200.0, 4.0, 1e5
        rt = rho_transitorio(L, I_DEF, W_DEF, D, t)
        @test rt > 1.0
        # por encima del umbral, A_frontera NO depende de ρ
        @test adelanto_frontera(rt * 2, L, I_DEF, W_DEF, D, t) ==
            adelanto_frontera(rt * 100, L, I_DEF, W_DEF, D, t)
        @test adelanto_frontera(rt * 100, L, I_DEF, W_DEF, D, t) ==
            adelanto_frontera_inf(L, I_DEF, W_DEF, D)
        # por debajo, manda el transitorio y crece con ρ
        @test adelanto_frontera(1.001, L, I_DEF, W_DEF, D, t) <
            adelanto_frontera(1.5, L, I_DEF, W_DEF, D, t)
        # el estacionario NO depende de ρ (hallazgo)
        @test adelanto_frontera_inf(L, I_DEF, W_DEF, D) == L + I_DEF - W_DEF - D
    end

    @testset "5 · Revelación retardada (h): ρ* y su residuo" begin
        L = 7200.0
        re = rho_estrella(L, I_DEF, W_DEF)
        @test isapprox(re, 9.254; atol = 0.01)          # histórico con W_dec=20
        @test isapprox(rho_estrella(L, I_DEF, 45.0), 8.995; atol = 0.01)  # histórico W_dec=45
        @test abs(adelanto_con_h(re, L, I_DEF, W_DEF)) < 1e-9
        @test adelanto_con_h(re * 1.001, L, I_DEF, W_DEF) > 0.0
        @test adelanto_con_h(re * 0.999, L, I_DEF, W_DEF) == 0.0
        @test adelanto_con_h(1.0, L, I_DEF, W_DEF) == 0.0
        # el residuo ρ → ∞ es I + W_dec − 1, NO cero
        @test isapprox(adelanto_con_h(1e9, L, I_DEF, W_DEF), I_DEF + W_DEF - 1; rtol = 1e-6)
    end

    @testset "6 · C-FLU-01: L derivada, y el término que manda" begin
        @test L_derivada(7200.0, 500.0, 150.0) == 7200.0    # manda F
        @test L_derivada(500.0, 7200.0, 150.0) == 7200.0    # manda el suelo
        @test L_derivada(100.0, 50.0, 150.0) == 151.0       # manda S_max + 1
        @test L_derivada(151.0, 151.0, 150.0) == 151.0      # empate
        p = ParametrosAdelanto(2.0, I_DEF, W_DEF, 4.0, 150.0, 7200.0, 0.0, 1e5, 2.5, 0.0961)
        @test evaluar_fila(p).manda_F
        p2 = ParametrosAdelanto(2.0, I_DEF, W_DEF, 4.0, 150.0, 500.0, 7200.0, 1e5, 2.5, 0.0961)
        @test !evaluar_fila(p2).manda_F
        p3 = ParametrosAdelanto(2.0, I_DEF, W_DEF, 4.0, 150.0, 100.0, 50.0, 1e5, 2.5, 0.0961)
        @test !evaluar_fila(p3).manda_F
        @test evaluar_fila(p3).L_slots == 151.0
    end

    @testset "7 · Umbrales y coste" begin
        L, rho_max, W = 7200.0, 2.5, 45.0   # la tabla histórica de (h.6) usa W_dec = 45 s
        Ie = I_estrella(L, rho_max, W)
        @test isapprox(Ie, 4725.0; atol = 1.0)             # tabla histórica ronda 10a §C.5
        # (h.6) invierte EXACTAMENTE la forma continua de ρ*; con la convención −1 queda a
        # menos de un slot, y esa diferencia se publica, no se absorbe.
        @test isapprox(rho_estrella_continua(L, Ie, W), rho_max; rtol = 1e-12)
        @test abs(rho_estrella(L, Ie, W) - rho_max) < 0.01
        @test I_minima_f(rho_max, W) == rho_max * W
        @test lineas_timekeeper(7200.0, I_DEF) == 10.0      # q = 9 ⇒ q+1 = 10
        @test isapprox(coste_relativo(7200.0, I_DEF), 1 + 7200.0 / I_DEF; rtol = 1e-12)
        @test isapprox(nucleos_nodo(7200.0, I_DEF, COSTE_VERIFY_SLOT_S),
            COSTE_VERIFY_SLOT_S * (1 + 7200.0 / I_DEF); rtol = 1e-12)
        # coste relativo y ρ* son la misma cantidad salvo I/(I+W_dec) — el factor que las
        # separa, que es lo que el encargo §4.2 pregunta.
        @test isapprox(rho_estrella_continua(7200.0, I_DEF, W_DEF),
            coste_relativo(7200.0, I_DEF) * I_DEF / (I_DEF + W_DEF); rtol = 1e-12)
    end

    @testset "8 · Kernel contra BigFloat (256 bits)" begin
        filas = Vector{ParametrosAdelanto{Float64}}(undef, 0)
        for rho in (1.0, 1.001, 1.5, 2.5, 9.0), I in (151.0, 851.0, 4725.0),
            W in (5.0, 20.0, 45.0), D in (0.0, 4.0, 45.0), F in (1019.0, 7200.0),
            Lsu in (0.0, 3000.0)
            push!(filas, ParametrosAdelanto(rho, I, W, D, 150.0, F, Lsu, 1e5, 2.5, 0.0961))
        end
        k = kernel_vs_bigfloat(filas)
        @test k.violaciones == 0
        @test k.peor_error_relativo <= 64 * eps(Float64)
    end

    @testset "9 · Modelo de fronteras contra Sim-v1 (oráculo independiente)" begin
        r = frontera_vs_sim()
        @test r.maxdif <= 1.0
        # La diferencia es la convención discreta de un slot (`Γ_sim = t_{i*+1} − 1`), y es
        # exactamente 1 en las filas saturadas (las que no dependen de ρ).
        saturadas = [f.A_sim for f in r.filas if abs(f.A_sim - r.filas[end].A_sim) < 1e-9]
        @test length(saturadas) >= 4
        for f in r.filas
            @test f.A_sim >= 0
            @test f.fr_adv >= f.fr_hon
            if abs(f.A_sim - r.filas[end].A_sim) < 1e-9
                @test isapprox(f.A_cerrada - f.A_sim, 1.0; atol = 1e-9)
            end
        end
    end

    @testset "10 · Invariantes" begin
        inv = invariantes()
        @test inv.aceptado
        @test isempty(inv.fallos)
    end

    @testset "11 · Exactitud de los umbrales discretos" begin
        e = exactitud_umbrales()
        @test e.aceptado
        @test e.discrepancias_manda_F == 0
        @test e.discrepancias_vivo == 0
        @test e.discrepancias_rho == 0
        @test e.peor_error_rel_rho_estrella <= 64 * eps(Float64)
    end

    @testset "12 · Barrido: hilos y serial dan el mismo resultado" begin
        rr = [1.0 + k * 1e-3 for k in 0:20]
        filas = rejilla(rr, [851.0, 4725.0], [20.0, 45.0], [0.0, 4.0], [150.0],
            [1019.0, 7200.0], [0.0], 1e5, 2.5, 0.0961)
        s1 = Vector{ResultadoAdelanto{Float64}}(undef, length(filas))
        s2 = Vector{ResultadoAdelanto{Float64}}(undef, length(filas))
        barrer!(s1, filas)
        barrer_hilos!(s2, filas)
        @test s1 == s2
        # el orden de la rejilla hace variar ρ más rápido (orden de columnas)
        @test filas[1].rho == rr[1]
        @test filas[2].rho == rr[2]
    end

    @testset "13 · Cota de la Fase 3: sup A" begin
        L, D, t = 7200.0, 4.0, 1e6
        s_sin = sup_A_sin_h(2.5, L, I_DEF, W_DEF, D, t)
        s_con = sup_A_con_h(2.5, L, I_DEF, W_DEF, D)
        @test s_sin > 0.0
        @test s_con == 0.0                      # con (h) y ρ_max ≤ ρ*, el adelanto se anula
        @test sup_A_con_h(12.0, L, I_DEF, W_DEF, D) > 0.0
        @test cota_sellado(2.5, L, I_DEF, W_DEF, D, t) == s_sin
    end
end
