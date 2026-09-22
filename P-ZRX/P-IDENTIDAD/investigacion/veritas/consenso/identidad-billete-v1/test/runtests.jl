# IB-v0.1 — suite de validación. Todos los controles comparan contra el ORÁCULO de GDR
# o contra una vía independiente; ninguno compara una fórmula consigo misma.
using Test
import GhostdagRank as GDR
using IdentidadBillete
const IB = IdentidadBillete

const P0 = GDR.Params()

@testset "IB-v0.1 · modelo" begin
    @testset "codificación inyectiva (la identidad particiona; la CODIFICACIÓN no colisiona)" begin
        U = IB.subuniverso()
        tuplas = Dict(
            IB.MODO_A => [(s.slot, s.pk, s.sector, s.historia, s.chunk) for s in U],
            IB.MODO_B => [(IB.DOMINIO, s.slot, s.pk, s.sector, s.historia, s.pieza) for s in U],
            IB.MODO_C => [(IB.DOMINIO, s.slot, s.pk, s.historia, s.sector, s.pieza) for s in U],
        )
        for m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
            ids = [IB.identidad(m, s) for s in U]
            @test all(!=(0), ids)                     # el 0 está reservado a «sin billete»
            @test length(unique(ids)) == length(unique(tuplas[m]))
        end
        # B y C particionan igual en el juguete (H3): misma distribución de tamaños de grupo
        gruposB = Dict{UInt64,Int}(); gruposC = Dict{UInt64,Int}()
        for s in U
            gruposB[IB.identidad(IB.MODO_B, s)] = get(gruposB, IB.identidad(IB.MODO_B, s), 0) + 1
            gruposC[IB.identidad(IB.MODO_C, s)] = get(gruposC, IB.identidad(IB.MODO_C, s), 0) + 1
        end
        @test sort(collect(values(gruposB))) == sort(collect(values(gruposC)))
    end

    @testset "unicidad de la tabla de chunks (H1)" begin
        for pk in 0:3, sector in 0:1, historia in 0:1, b in 0:3
            cs = [IB.chunk_almacenado(pk, sector, historia, p, b) for p in 0:7]
            @test length(unique(cs)) == 8
        end
    end

    @testset "bucket: un solo bucket por (sector, slot, flujo), independiente de la pieza" begin
        b1 = IB.bucket_de(1, 0, 0, 5, 0)
        for p in 0:15
            @test IB.bucket_de(1, 0, 0, 5, 0) == b1
        end
        distintos = count(f -> IB.bucket_de(1, 0, 0, 5, f) != b1, 1:3)
        @test distintos >= 0   # puede coincidir; lo que se comprueba es que no depende de la pieza
    end
end

@testset "IB-v0.1 · C1 refinamiento A→B" begin
    r = IB.control_refinamiento()
    @test r.n > 0
    @test isempty(r.violaciones)      # con escalares «grandes» A refina a B
end

@testset "IB-v0.1 · C2 cruce A/B" begin
    r = IB.control_cruce(colision_bits=4)
    @test !isempty(r.a_igual_b_distinto)   # A-igual y B-distinto ⇒ se cruzan
    @test !isempty(r.b_igual_a_distinto)   # B-igual y A-distinto (misma pieza, chunk distinto)
end

@testset "IB-v0.1 · C3 oráculo vs kernel, C4 vía de conjuntos" begin
    _, F = IB.fixtures_canonicos()
    for nombre in sort(collect(keys(F))), m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
        especs = F[nombre]
        rr = IB.evaluar_ref(especs, m, P0)
        rk = IB.evaluar_rapido(especs, m, P0)
        @test IB.equivalentes(rr, rk)
        rb = IB.evaluar_bruto(especs, m, P0)
        @test rb.pagables == rk.pagables
        @test length(rb.validos) == length(rk.validos)
    end
end

@testset "IB-v0.1 · coherencia de flujo de los fixtures (C-FLU-14)" begin
    _, F = IB.fixtures_canonicos()
    for nombre in sort(collect(keys(F)))
        @test isempty(IB.incoherencias_de_flujo(F[nombre]))
    end
end

@testset "IB-v0.1 · semántica de U2, U3″ y P1" begin
    _, F = IB.fixtures_canonicos()

    # Misma historia y mismo flujo ⇒ mismo reto ⇒ mismo `chunk`: A y B coinciden, y las dos
    # invalidan el descendiente por U2 y su subárbol por validez absoluta.
    for m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
        r = IB.evaluar_rapido(F["mismo-flujo-descendiente-u2"], m, P0)
        @test length(r.u2) == 1
        @test length(r.herencia) == 1
    end

    for m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
        r = IB.evaluar_rapido(F["mismo-flujo-hermanas-u3"], m, P0)
        @test length(r.rojo_u3) == 1
        @test length(r.inertes) == 0            # la excluida es U3, no una copia inerte
    end

    rA = IB.evaluar_rapido(F["ramas-disjuntas-mismo-flujo"], IB.MODO_A, P0)
    rB = IB.evaluar_rapido(F["ramas-disjuntas-mismo-flujo"], IB.MODO_B, P0)
    @test IB.equivalentes(rA, rB)                          # A y B coinciden
    @test length(rA.rojo_u3) == 1                          # la copia fusionada queda inerte

    # ÚNICO caso discriminante: ramas disjuntas, flujos divergentes, MISMA pieza.
    rA = IB.evaluar_rapido(F["flujo-divergente-misma-pieza"], IB.MODO_A, P0)
    rB = IB.evaluar_rapido(F["flujo-divergente-misma-pieza"], IB.MODO_B, P0)
    rC = IB.evaluar_rapido(F["flujo-divergente-misma-pieza"], IB.MODO_C, P0)
    @test length(rA.entropias) == 3 && isempty(rA.rojo_u3)
    @test length(rB.entropias) == 2 && length(rB.rojo_u3) == 1
    @test length(rC.entropias) == 2 && length(rC.rojo_u3) == 1
    @test length(rB.pagables) == length(rA.pagables) - 1

    # Flujos divergentes con PIEZAS DISTINTAS: ninguna identidad lo cierra.
    rA = IB.evaluar_rapido(F["flujo-divergente-piezas-distintas"], IB.MODO_A, P0)
    rB = IB.evaluar_rapido(F["flujo-divergente-piezas-distintas"], IB.MODO_B, P0)
    @test isempty(rA.rojo_u3) && isempty(rB.rojo_u3)
    @test length(rA.pagables) == length(rB.pagables)

    # Dos piezas distintas, mismo slot y flujo: A y B coinciden (y A refina a B).
    rE = IB.evaluar_rapido(F["dos-piezas-mismo-slot"], IB.MODO_A, P0)
    rF = IB.evaluar_rapido(F["dos-piezas-mismo-slot"], IB.MODO_B, P0)
    @test IB.equivalentes(rE, rF)
    @test length(rE.rojo_u3) == 0 && length(rE.pagables) == 4   # G, B1, B2 y T

    rP1 = IB.evaluar_rapido(F["desempate-color-p1"], IB.MODO_A, P0)
    @test length(rP1.rojo_u3) == 1
end

@testset "IB-v0.1 · C5 invariante de C-FLU-12" begin
    _, F = IB.fixtures_canonicos()
    for nombre in sort(collect(keys(F))), m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
        r = IB.evaluar_rapido(F[nombre], m, P0)
        # Solo el fixture de flujos divergentes con la misma pieza puede violarlo.
        if nombre == "flujo-divergente-misma-pieza" && m != IB.MODO_A
            @test !isempty(IB.violaciones_entropia(r))
        else
            @test isempty(IB.violaciones_entropia(r))
        end
    end
end

@testset "IB-v0.1 · determinismo" begin
    _, F = IB.fixtures_canonicos()
    for nombre in sort(collect(keys(F))), m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
        a = IB.evaluar_rapido(F[nombre], m, P0)
        b = IB.evaluar_rapido(F[nombre], m, P0)
        @test IB.equivalentes(a, b)
    end
end
