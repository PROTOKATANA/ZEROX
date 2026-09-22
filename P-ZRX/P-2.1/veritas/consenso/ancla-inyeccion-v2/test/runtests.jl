# ANCLA-v0.2 — suite: equivalencia kernel↔referencia, bordes, invariantes,
# vectores de regresión y criterio de aceptación. Ejecutar con
# ./veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl
using Test
using AnclaInyeccion
using AnclaInyeccion.GhostdagRank

@testset "ANCLA-v0.2" begin
    @testset "GDR reutilizado sin modificar" begin
        pg = GhostdagRank.Params(k=30)
        est = GhostdagRank.EstadoRapido(pg, "G")
        @test est.n == 1
        ok = GhostdagRank.anadir!(est, pg, "b0000001", [1], UInt64(1), UInt64(5),
                                  UInt64(2)^50, UInt64(2))
        @test ok
        @test est.gd[2].sp == 1
    end

    @testset "equivalencia kernel↔referencia (mundo pequeño honesto)" begin
        for r in 1:8
            m = mundo_pequeno(r)
            @test validar_pequeno(m)
        end
    end

    @testset "equivalencia con adversario pequeño (V1 y A3)" begin
        for via in (:v1, :a3)
            pr = Params4A(α=0.33, Δ=2.0, via=via, n_obs=3, W0=30, H=320, paso_T=30,
                          L_def=40, d_calma=40)
            for r in 1:3
                plan = plan_replica(pr, r, 0xBEEF)
                es = escenarios(pr, plan)
                for e in es[1:min(4, end)]
                    m = Mundo(pr, plan, e)
                    correr!(m)
                    validar_heap_tips(m)
                    for T in m.T
                        T + pr.L_def + 150 <= pr.H || continue
                        validar_contra_referencia(m, T, pr.L_def)
                    end
                end
            end
        end
    end

    @testset "vector de regresión: vista completa ≠ restringida" begin
        c, r = vector_artefacto_vista_completa()
        @test c != r
    end

    @testset "R-FIN-1a y cierre bajo ancestros (invariantes del mundo)" begin
        m = mundo_pequeno(3)
        for tr in Iterators.flatten((m.obs, (m.zl,)))
            est = tr.est
            for i in 2:est.n
                @test est.slots[est.gd[i].sp] <= est.slots[i]
                @test est.slots[i] - est.slots[est.gd[i].sp] <= 150
                for p in est.padres[i]
                    @test tr.t_insert[p] <= tr.t_insert[i]   # cierre bajo ancestros
                end
            end
        end
    end

    @testset "punto fijo del ancla definitiva: fijo, vacío y sanidad" begin
        m = mundo_pequeno(4)
        for (j, T) in enumerate(m.T)
            D, f = ancla_definitiva(m, j)
            @test f == :fijo || f == :vacio
            if f == :fijo
                @test T <= m.slot[Int(D)] <= T + 150 + 40
            end
        end
    end

    @testset "criterio de aceptación: G cambia con α" begin
        m0, m1 = criterio_alfa(40, 0xC0FE)
        @test m1 > m0
        println("  criterio α: G(0) medio=$(round(m0, digits=2)) < G(0,45) medio=$(round(m1, digits=2))")
    end

    @testset "4.0: puerta (exacto)" begin
        # Skellam: normalización y media
        μ = 1.0
        p = [skellam_pmf(μ, μ, 10.0, k) for k in -60:60]
        @test isapprox(sum(p), 1.0; atol=1e-10)
        media = sum(k*p[i] for (i, k) in enumerate(-60:60))
        @test isapprox(media, 0.0; atol=1e-8)
        # deriva cero con retarget para todo c; contrafactual con s1=1 (todo 1−c en un flujo)
        for c in (0.0, 0.5, 1.0)
            _, d_sin, t_r, t_s = deriva_absorcion(c, 1.0)
            @test t_r == Inf
            if c < 1.0
                @test isapprox(t_s, 100/(1-c); rtol=1e-9)
            else
                @test t_s == Inf
            end
        end
        # S_max racional: 4 TiB -> 24, 20 TiB -> 4-5
        S = s_max_racional([4.0, 20.0])
        @test S[1] == 24
        @test S[2] == 4
        # φ de referencia: p_cambio_lider ∈ [0,1] y crece con τ (τ pequeños, antes de saturar)
        a = p_cambio_lider(1.0, 1.0, 0.5)
        b = p_cambio_lider(1.0, 1.0, 5.0)
        @test 0 <= a <= 1
        @test b > a
    end
end
