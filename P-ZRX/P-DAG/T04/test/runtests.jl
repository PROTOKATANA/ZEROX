# runtests.jl — T04: revalidación GDR-v0.2, casos dirigidos y propiedades IE-1…IE-6.
using Test
using EstadoDAG
using EstadoDAG.Transicion
import EstadoDAG.GDR
using StableRNGs
using Random
using Combinatorics

const REPLICAS_TEST = parse(Int, get(ENV, "T04_REPLICAS_TEST", "5"))

@testset "T04" begin
    @testset "revalidación GDR-v0.2" begin
        corpus = "/home/katana/zeo/ZEROX/testdata/ghostdag-rank-v1/corpus-rust.txt"
        nd, nb, disc = revalidar_corpus(corpus)
        @test nd == 28
        @test nb == 2290
        @test isempty(disc)
        nk, disc2 = revalidar_kaspa(joinpath(@__DIR__, "..", "testdata", "kaspa"))
        @test nk == 84
        @test isempty(disc2)
    end

    @testset "casos dirigidos" begin
        pd = ParamsDAG(PARAMS_DAG_BASE[1], 1)

        nombre, A, m = EstadoDAG.caso_doble_gasto(pd)
        S, _, desc = aplicar_historia(A)
        g1 = A.gdr.gd[A.gidx[m.X1]]
        g2 = A.gdr.gd[A.gidx[m.X2]]
        primero = GDR.cmp_orden(A.gdr, A.gidx[m.X1], A.gidx[m.X2]) < 0 ? m.X1 : m.X2
        segundo = primero == m.X1 ? m.X2 : m.X1
        @test length(desc) == 1
        @test desc[1][1] == segundo
        @test desc[1][2] == 2
        @test desc[1][3] == Transicion.ErrDobleGasto
        @test A.validos[primero] && A.validos[segundo]

        nombre, A, m = EstadoDAG.caso_coinbase_recortada(pd)
        g = A.post[m.X].garantias[1]
        @test isempty(g.pendientes)
        @test sum(p.importe for p in g.creditos) == UInt64(4)   # 3 subsidio + 1 tarifa aceptada
        @test length(A.descartes[m.X]) == 1
        @test A.descartes[m.X][1][2] == Transicion.ErrDobleGasto

        nombre, A, m = EstadoDAG.caso_deposito_habilita(pd)
        @test A.validos[m.Z]
        @test !A.validos[m.W]
        @test A.motivos[m.W] == :ErrGarantia

        nombre, A, m = EstadoDAG.caso_garantia_rama(pd)
        @test !A.validos[m.B]
        @test A.motivos[m.B] == :ErrGarantia

        nombre, A, m = EstadoDAG.caso_rojo_u3(pd)
        u3 = u3_virtual(A)
        @test m.X2 in u3
        @test !(m.X2 in orden_aplicacion_virtual(A))
        @test m.X1 in orden_aplicacion_virtual(A)

        nombre, A, m = EstadoDAG.caso_una_vez(pd)
        ord = orden_aplicacion_virtual(A)
        @test count(==(m.X), ord) == 1
        @test length(ord) == length(unique(ord))

        nombre, A, m = EstadoDAG.caso_reorg(pd)
        @test m.tipA == m.A2
        @test m.tipB1 == m.A2
        @test m.tipB3 == m.B3

        nombre, A, m = EstadoDAG.caso_hermanos_transicion(pd)
        @test A.validos[m.Tb1]
        @test A.validos[m.Tb2]
        @test A.por_id[m.Tb1].slot == A.por_id[m.Tb2].slot

        # T04-B (F-15): repetición, orden inverso de nonces y reorg.
        nombre, A, m = EstadoDAG.caso_nonce_repeticion_fusionada(pd)
        S, _, desc = aplicar_historia(A)
        errs = [d for d in desc if d[3] == Transicion.ErrNonce]
        @test A.validos[m.X1] && A.validos[m.X2]
        @test length(errs) == 1
        @test errs[1][1] == m.segundo
        @test errs[1][2] == 2
        @test length(S.garantias[1].en_retirada) == 1
        @test S.garantias[1].nonce_siguiente == m.n + UInt64(1)

        nombre, A, m = EstadoDAG.caso_nonce_orden_inverso(pd)
        S, _, desc = aplicar_historia(A)
        errs = [d for d in desc if d[3] == Transicion.ErrNonce]
        @test length(errs) == 1
        @test errs[1][1] == m.Xa
        @test S.garantias[m.clave].nonce_siguiente == m.n + UInt64(1)
        @test !haskey(S.utxo, m.utxo)

        nombre, A, m = EstadoDAG.caso_nonce_reorg(pd)
        S, _, _ = aplicar_historia(A)
        @test m.tipA1 == m.A1
        @test m.tipB3 == m.B3
        @test m.tipA3 == m.A3
        @test m.retiros_B == 1
        @test S.garantias[1].nonce_siguiente == m.n + UInt64(1)
        @test length(S.garantias[1].en_retirada) == 1

        # T04-C: retiro + liberación + transferencia bajo reorganización.
        nombre, A, m = EstadoDAG.caso_retiro_liberacion_reorg(pd)
        @test m.libA == 1
        @test m.tipB == m.B3
        @test m.tipA == m.A4
        @test m.libSA == 0 && m.outSA == 1 && m.retSA == 0
        @test m.nonceSA == m.n0 + UInt64(2)
        @test m.libSB == 0 && m.outSB == 0 && m.retSB == 1
        @test m.nonceSB == m.n0 + UInt64(1)
        @test m.libSA2 == 0 && m.outSA2 == 1 && m.retSA2 == 0
        @test m.nonceSA2 == m.n0 + UInt64(2)
        @test isempty(verificar_ie1_ie2_ie4(A))

        # T04-C: punto de aplicación (RD-4) de la liberación inmadura en su slot.
        nombre, A, m = EstadoDAG.caso_liberacion_punto_aplicacion(pd)
        @test m.spY == m.Z
        @test m.slotX == 2 && m.slotY == 3
        @test m.libX == 0
        @test m.libY == 1 && m.libY_slot == m.slotY
        @test m.nonceX == m.n0 + UInt64(1)
        @test m.nonceY == m.n0 + UInt64(2)
        @test length(m.descX) == 1
        @test m.descX[1][2] == Transicion.ErrSaldo
        @test isempty(verificar_ie1_ie2_ie4(A))
    end

    @testset "propiedades IE-1…IE-6" begin
        for (pi, k) in PUNTOS_T04
            pd = ParamsDAG(PARAMS_DAG_BASE[pi], k)
            for r in 1:REPLICAS_TEST
                rng = StableRNG(0x5a5a + UInt64(10_000 * pi + r))
                A = generar_dag_aleatorio(rng, pd; npost = EstadoDAG.npost_t04c(r),
                                          pesos = EstadoDAG.PESOS_AJUSTADOS)
                bloques = collect(values(A.por_id))
                @test isempty(verificar_ie1_ie2_ie4(A))
                @test isempty(verificar_ie3(A, bloques; intentos = 8,
                                            semilla = UInt64(1_000 * pi + r)))
                @test isempty(verificar_ie6(A))
                if length(bloques) <= 5
                    @test isempty(verificar_ie3(A, bloques;
                                                ordenes = collect(permutations(1:length(bloques)))))
                end
            end
            # IE-5: cadenas sin fusiones contra T01
            for seed in 1:5
                rng = StableRNG(0xabc + UInt64(100 * pi + seed))
                pow, bps, Efin = generar_cadena_post(rng, pd.P; npost = 4)
                A = Admision(pd, pow[1], pow[1][end].id)
                resolver!(A, bps)
                @test isempty(verificar_ie5(A, bps, Efin))
            end
        end
    end

    @testset "cobertura del generador" begin
        ac = EstadoDAG.AcumuladorCobertura()
        pd = ParamsDAG(PARAMS_DAG_BASE[1], 1)
        for r in 1:120
            rng = StableRNG(0x1234 + UInt64(r))
            A = generar_dag_aleatorio(rng, pd; npost = EstadoDAG.npost_t04c(r),
                                      pesos = EstadoDAG.PESOS_AJUSTADOS)
            EstadoDAG.acumular_caso!(ac, A)
        end
        for t in EstadoDAG.TIPOS_COBERTURA
            @test ac.construidas[t] > 0
        end
        @test ac.aplicadas[Transicion.TxRetiro] > 0
        @test ac.aplicadas[Transicion.TxLiberacion] > 0
    end

    @testset "relectura de vectores" begin
        ruta = joinpath(@__DIR__, "..", "resultados", "vectores-estado-dag-v0.2.txt")
        if isfile(ruta)
            cmd = `$(Base.julia_cmd()) --project=$(dirname(@__DIR__)) $(joinpath(@__DIR__, "..", "src", "lector_vectores.jl")) $ruta`
            p = run(ignorestatus(cmd))
            @test success(p)
        end
    end
end
