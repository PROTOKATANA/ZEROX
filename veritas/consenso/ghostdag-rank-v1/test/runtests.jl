# Suite GDR-v0.1 — ejecutar con: julia --check-bounds=yes --project=. test/runtests.jl
using Test
using GhostdagRank
using StableRNGs
using JSON3

const W0 = big(2)^128

@testset "GDR-v0.1" begin

@testset "peso: fronteras y equivalencia con BigInt" begin
    for sr in UInt64[0, 1, 2, 3, 2^32, 2^62, 2^61, typemax(UInt64) - 1, typemax(UInt64), 0xdeadbeefcafe1234]
        @test peso(sr) == BW256(peso_big(sr))
        @test BigInt(peso(sr)) == peso_big(sr)
    end
    @test peso(UInt64(0)) == BW256(UInt128(1), UInt128(0))
    @test peso(typemax(UInt64) - 1) == BW256(big(2)^64 + 1)
    @test peso(typemax(UInt64)) == BW256(big(2)^64)
    @test peso(UInt64(1)) == BW256(big(2)^127)
    # w ≥ 2^64 para todo SR de u64 (pieza del lema de compatibilidad causal)
    @test peso(typemax(UInt64) - 1) >= BW256(big(2)^64)
    @test peso(typemax(UInt64)) >= BW256(big(2)^64)
    @test peso(UInt64(0)) >= BW256(big(2)^64)
end

@testset "BW256: aritmética y desbordamiento" begin
    @test BW256(big(2)^128) + BW256(big(2)^128) == BW256(big(2)^129)
    @test BW256(big(2)^129) - BW256(big(2)^128) == BW256(big(2)^128)
    a = BW256(typemax(UInt128), typemax(UInt128))
    @test_throws OverflowError a + BW256(UInt64(1))
    @test bits_necesarios(BW256(big(2)^128)) == 129
    @test bits_necesarios(BW256(big(2)^64)) == 65
    @test bits_necesarios(BW256_CERO) == 0
    @test bits_necesarios(BW256(UInt64(1))) == 1
end

# ---------------------------------------------------------------------------
# Corrección 1, tarea 3.5 — cota de blue_work: bw(B) < n·2^128 (PROPUESTA-SPEC.md §11).
# Comprobada en los DAGs de prueba (no solo demostrada por escrito).
# ---------------------------------------------------------------------------
@testset "cota de blue_work: bw(B) < n·2^128" begin
    params = P_DEFECTO
    rng = StableRNG(0xC07A)
    for t in 1:80
        n = 4 + rand(rng, 0:150)
        especs = generar_dag(rng, n)
        est = entregar(EstadoRapido, params, especs, collect(1:n), "G")
        cota_bits = 128 + (n <= 1 ? 0 : ceil(Int, log2(n)))
        for i in 1:n
            @test bits_necesarios(est.gd[i].bw) <= cota_bits
            @test BigInt(est.gd[i].bw) < BigInt(n) * (big(2)^128)
        end
    end
end

# ---------------------------------------------------------------------------
# D1 — cadena
# ---------------------------------------------------------------------------
@testset "D1 cadena pura, pesos heterogéneos" begin
    params = Params(k=4)
    especs = [BloqueEspec("C1"; padres=[1], slot=1, sr=1),
              BloqueEspec("C2"; padres=[2], slot=2, sr=3),
              BloqueEspec("C3"; padres=[3], slot=3, sr=7),
              BloqueEspec("C4"; padres=[4], slot=4, sr=typemax(UInt64) - 1),
              BloqueEspec("C5"; padres=[5], slot=5, sr=typemax(UInt64)),
              BloqueEspec("C6"; padres=[6], slot=6, sr=0)]
    bws = [big(0), W0, W0 + big(2)^127, W0 + big(2)^127 + big(2)^126,
           W0 + big(2)^127 + big(2)^126 + big(2)^125,
           W0 + big(2)^127 + big(2)^126 + big(2)^125 + big(2)^64 + 1,
           W0 + big(2)^127 + big(2)^126 + big(2)^125 + big(2)^64 + 1 + big(2)^64]
    for T in (EstadoReferencia, EstadoRapido)
        est = T(params, "G")
        est, motivos = construir(est, params, especs)
        @test all(==(:ok), motivos)
        for i in 1:7
            @test GhostdagRank.sp_de(est, i) == (i == 1 ? 0 : i - 1)
            @test GhostdagRank.ms_blues_de(est, i) == (i == 1 ? [1] : [i - 1])
            @test isempty(GhostdagRank.ms_reds_de(est, i))
            @test est.gd[i].blue_score == UInt64(i - 1)
            @test BigInt(est.gd[i].bw) == bws[i]
        end
        @test cadena_seleccionada(est, 7) == [1, 2, 3, 4, 5, 6, 7]
        @test orden_aplicacion(est, params, 7) == [1, 2, 3, 4, 5, 6, 7]
    end
end

# ---------------------------------------------------------------------------
# D2 — diamante, empate de bw entre padres, fork de sp
# ---------------------------------------------------------------------------
@testset "D2 diamante: sp según modo" begin
    # Histórico (v0.1): modos :spec/:python, superados por la regla C (ver D2′ más abajo).
    especs = [BloqueEspec("A"; padres=[1], slot=1, sd=5),
              BloqueEspec("B"; padres=[1], slot=1, sd=3),
              BloqueEspec("D"; padres=[2, 3], slot=2, sd=1)]
    for T in (EstadoReferencia, EstadoRapido)
        pe = Params(k=2, sp_mode=SP_SPEC, merge_mode=MERGE_SPEC)
        est = T(pe, "G")
        construir(est, pe, especs)
        @test GhostdagRank.sp_de(est, 4) == 2            # A, mayor sd
        @test GhostdagRank.ms_blues_de(est, 4) == [2, 3]
        @test BigInt(est.gd[4].bw) == 3 * W0
        @test orden_aplicacion(est, pe, 4) == [1, 2, 3, 4]

        estp = T(Params(k=2, sp_mode=SP_PYTHON, merge_mode=MERGE_PYTHON), "G")
        construir(estp, Params(k=2, sp_mode=SP_PYTHON, merge_mode=MERGE_PYTHON), especs)
        @test GhostdagRank.sp_de(estp, 4) == 3           # B, menor sd
        @test GhostdagRank.ms_blues_de(estp, 4) == [3, 2]
        @test BigInt(estp.gd[4].bw) == 3 * W0
        @test orden_aplicacion(estp, Params(k=2, sp_mode=SP_PYTHON,
                                            merge_mode=MERGE_PYTHON), 4) == [1, 3, 2, 4]
    end
end

# ---------------------------------------------------------------------------
# D3 — anticono mayor que k, tope k+1
# ---------------------------------------------------------------------------
@testset "D3 anticono > k" begin
    # Histórico (v0.1, modo :spec); la regla C no se primó para D3 porque el encargo de
    # Corrección 1 solo pidió D2′/D5′/D6′/D7′ — no es trabajo pedido, se deja anotado.
    especs = [BloqueEspec("S$i"; padres=[1], slot=1, sd=i) for i in 1:7]
    push!(especs, BloqueEspec("M"; padres=[2, 3, 4, 5, 6, 7, 8], slot=2, sd=0))
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=2, sp_mode=SP_SPEC, merge_mode=MERGE_SPEC)
        est = T(params, "G")
        construir(est, params, especs)
        @test GhostdagRank.sp_de(est, 9) == 8                 # S7
        @test GhostdagRank.ms_blues_de(est, 9) == [8, 2, 3]   # S7, S1, S2
        @test GhostdagRank.ms_reds_de(est, 9) == [4, 5, 6, 7] # S3..S6
        @test est.gd[9].blue_score == 4                       # score(S7)=1 + 3 azules
        @test BigInt(est.gd[9].bw) == 4 * W0
        @test orden_aplicacion(est, params, 9) == [1, 8, 2, 3, 4, 5, 6, 7, 9]
    end
end

# ---------------------------------------------------------------------------
# D4 — U3′-filtro vs U3″ dinámica
# ---------------------------------------------------------------------------
@testset "D4 copias de billete: filtro vs dinámica" begin
    especs = [BloqueEspec("A"; padres=[1], slot=1, sd=50, ident=1),
              BloqueEspec("X"; padres=[1], slot=1, sd=0, ident=2),
              BloqueEspec("Y"; padres=[3], slot=2, sd=0, ident=3),
              BloqueEspec("Z"; padres=[4], slot=3, sd=0, ident=4),
              BloqueEspec("Z2"; padres=[5], slot=4, sd=0, ident=5),
              BloqueEspec("A1"; padres=[1], slot=1, sd=1, ident=1),
              BloqueEspec("A2"; padres=[1], slot=1, sd=2, ident=1),
              BloqueEspec("A3"; padres=[1], slot=1, sd=3, ident=1),
              BloqueEspec("A4"; padres=[1], slot=1, sd=4, ident=1),
              BloqueEspec("M"; padres=[2, 7, 8, 9, 10, 6], slot=5, sd=0, ident=0)]
    for T in (EstadoReferencia, EstadoRapido)
        pf = Params(k=30, u3_mode=U3_FILTER)
        est = T(pf, "G")
        construir(est, pf, especs)
        @test GhostdagRank.sp_de(est, 11) == 6
        @test GhostdagRank.ms_blues_de(est, 11) == [6, 7, 8, 9, 10, 2]  # 5 azules T1
        @test isempty(GhostdagRank.ms_reds_de(est, 11))
        @test BigInt(est.gd[11].bw) == 10 * W0

        pd = Params(k=30, u3_mode=U3_DYNAMIC)
        est = T(pd, "G")
        construir(est, pd, especs)
        @test GhostdagRank.ms_blues_de(est, 11) == [6, 7]               # 1 azul T1
        @test GhostdagRank.ms_reds_de(est, 11) == [8, 9, 10, 2]
        @test all(x -> GhostdagRank.es_rojo_u3(est, 11, x), [8, 9, 10, 2])
        @test BigInt(est.gd[11].bw) == 6 * W0
    end
end

# ---------------------------------------------------------------------------
# D5 — empate de bw resuelto por sd: sp y rojo distintos según modo
# ---------------------------------------------------------------------------
@testset "D5 empate bw: sd decide sp y color" begin
    # Histórico (v0.1): modos :spec/:python, superados por la regla C (ver D5′ más abajo).
    especs = [BloqueEspec("P"; padres=[1], slot=1, sd=10),
              BloqueEspec("Q"; padres=[1], slot=1, sd=1),
              BloqueEspec("R"; padres=[1], slot=1, sd=5),
              BloqueEspec("S"; padres=[1], slot=1, sd=3),
              BloqueEspec("M"; padres=[2, 3, 4, 5], slot=2, sd=0)]
    for T in (EstadoReferencia, EstadoRapido)
        p_spec = Params(k=2, sp_mode=SP_SPEC, merge_mode=MERGE_SPEC)
        est = T(p_spec, "G")
        construir(est, p_spec, especs)
        @test GhostdagRank.sp_de(est, 6) == 2                 # P, mayor sd
        @test GhostdagRank.ms_blues_de(est, 6) == [2, 3, 5]   # P, Q, S
        @test GhostdagRank.ms_reds_de(est, 6) == [4]          # R
        @test BigInt(est.gd[6].bw) == 4 * W0
        @test orden_aplicacion(est, p_spec, 6) == [1, 2, 3, 5, 4, 6]

        p_py = Params(k=2, sp_mode=SP_PYTHON, merge_mode=MERGE_PYTHON)
        est = T(p_py, "G")
        construir(est, p_py, especs)
        @test GhostdagRank.sp_de(est, 6) == 3                 # Q, menor sd
        @test GhostdagRank.ms_blues_de(est, 6) == [3, 2, 4]   # Q, P, R (orden por -sd)
        @test GhostdagRank.ms_reds_de(est, 6) == [5]          # S
        @test BigInt(est.gd[6].bw) == 4 * W0
        @test orden_aplicacion(est, p_py, 6) == [1, 3, 2, 4, 5, 6]
    end
end

# ---------------------------------------------------------------------------
# D6 — empate de bw y sd resuelto por id
# ---------------------------------------------------------------------------
@testset "D6 empate total resuelto por id" begin
    # Histórico (v0.1, modo :spec); ver D6′ más abajo bajo la regla C.
    especs = [BloqueEspec("P"; padres=[1], slot=1, sd=7),
              BloqueEspec("Q"; padres=[1], slot=1, sd=7),
              BloqueEspec("M"; padres=[2, 3], slot=2, sd=0)]
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=2, sp_mode=SP_SPEC, merge_mode=MERGE_SPEC)
        est = T(params, "G")
        construir(est, params, especs)
        @test GhostdagRank.sp_de(est, 4) == 3                 # "Q" > "P" en bytes
        @test GhostdagRank.ms_blues_de(est, 4) == [3, 2]
        @test BigInt(est.gd[4].bw) == 3 * W0
        @test orden_aplicacion(est, params, 4) == [1, 3, 2, 4]
    end
end

# ---------------------------------------------------------------------------
# D7 — color contextual: W cambia de color según la punta
# ---------------------------------------------------------------------------
@testset "D7 reorg cambia el color de W" begin
    # Histórico (v0.1, modo :spec); ver D7′ más abajo bajo la regla C.
    especs = [BloqueEspec("W"; padres=[1], slot=1, sd=9, ident=10),
              BloqueEspec("U"; padres=[1], slot=1, sd=1, ident=20),
              BloqueEspec("C1"; padres=[2, 3], slot=2, sd=5, ident=30),
              BloqueEspec("V"; padres=[3], slot=2, sd=1, ident=40),
              BloqueEspec("C2"; padres=[5, 2], slot=3, sd=1, ident=50),
              BloqueEspec("T1"; padres=[4], slot=4, sd=0, ident=60),
              BloqueEspec("T2"; padres=[6], slot=4, sd=0, ident=70)]
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=1, sp_mode=SP_SPEC, merge_mode=MERGE_SPEC)
        est = T(params, "G")
        construir(est, params, especs)
        # W: 2; U: 3; C1: 4; V: 5; C2: 6; T1: 7; T2: 8
        @test GhostdagRank.sp_de(est, 4) == 2
        @test GhostdagRank.ms_blues_de(est, 4) == [2, 3]
        @test GhostdagRank.sp_de(est, 6) == 5
        @test GhostdagRank.ms_blues_de(est, 6) == [5]
        @test GhostdagRank.ms_reds_de(est, 6) == [2]          # W rojo_k
        @test !GhostdagRank.es_rojo_u3(est, 6, 2)
        @test cadena_seleccionada(est, 7) == [1, 2, 4, 7]
        @test cadena_seleccionada(est, 8) == [1, 3, 5, 6, 8]
        @test orden_aplicacion(est, params, 7) == [1, 2, 3, 4, 7]
        @test orden_aplicacion(est, params, 8) == [1, 3, 5, 2, 6, 8]
        @test BigInt(est.gd[4].bw) == 3 * W0
        @test BigInt(est.gd[6].bw) == 3 * W0
    end
end

# ---------------------------------------------------------------------------
# Corrección 1, tarea 3.3(b) — derivaciones bajo la regla C (DECIDIDO POR KATANA,
# TAREAS.md §1.3). Ver DERIVACIONES.md para el cálculo a mano de cada una, con hora
# verificable en resultados/REGISTRO.log ANTES de este test.
# ---------------------------------------------------------------------------
@testset "D2′ diamante bajo la regla C" begin
    especs = [BloqueEspec("A"; padres=[1], slot=1, sd=5),
              BloqueEspec("B"; padres=[1], slot=1, sd=3),
              BloqueEspec("D"; padres=[2, 3], slot=2, sd=1)]
    for T in (EstadoReferencia, EstadoRapido)
        est = T(P_DEFECTO, "G")
        construir(est, P_DEFECTO, especs)
        @test GhostdagRank.sp_de(est, 4) == 3            # B, menor sd (regla C)
        @test GhostdagRank.ms_blues_de(est, 4) == [3, 2]
        @test BigInt(est.gd[4].bw) == 3 * W0
        @test orden_aplicacion(est, P_DEFECTO, 4) == [1, 3, 2, 4]
    end
end

@testset "D5′ empate de bw bajo la regla C" begin
    especs = [BloqueEspec("P"; padres=[1], slot=1, sd=10),
              BloqueEspec("Q"; padres=[1], slot=1, sd=1),
              BloqueEspec("R"; padres=[1], slot=1, sd=5),
              BloqueEspec("S"; padres=[1], slot=1, sd=3),
              BloqueEspec("M"; padres=[2, 3, 4, 5], slot=2, sd=0)]
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=2)   # P_DEFECTO ya es regla C
        est = T(params, "G")
        construir(est, params, especs)
        @test GhostdagRank.sp_de(est, 6) == 3                 # Q, menor sd
        @test GhostdagRank.ms_blues_de(est, 6) == [3, 5, 4]   # Q, S, R
        @test GhostdagRank.ms_reds_de(est, 6) == [2]          # P, rojo_k
        @test BigInt(est.gd[6].bw) == 4 * W0
        @test orden_aplicacion(est, params, 6) == [1, 3, 5, 4, 2, 6]
    end
end

@testset "D6′ empate total bajo la regla C" begin
    especs = [BloqueEspec("P"; padres=[1], slot=1, sd=7),
              BloqueEspec("Q"; padres=[1], slot=1, sd=7),
              BloqueEspec("M"; padres=[2, 3], slot=2, sd=0)]
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=2)
        est = T(params, "G")
        construir(est, params, especs)
        @test GhostdagRank.sp_de(est, 4) == 2                 # P: "P" < "Q", menor id gana
        @test GhostdagRank.ms_blues_de(est, 4) == [2, 3]
        @test BigInt(est.gd[4].bw) == 3 * W0
        @test orden_aplicacion(est, params, 4) == [1, 2, 3, 4]
    end
end

@testset "D7′ color contextual bajo la regla C" begin
    especs = [BloqueEspec("W"; padres=[1], slot=1, sd=9, ident=10),
              BloqueEspec("U"; padres=[1], slot=1, sd=1, ident=20),
              BloqueEspec("C1"; padres=[2, 3], slot=2, sd=5, ident=30),
              BloqueEspec("V"; padres=[3], slot=2, sd=1, ident=40),
              BloqueEspec("C2"; padres=[5, 2], slot=3, sd=1, ident=50),
              BloqueEspec("T1"; padres=[4], slot=4, sd=0, ident=60),
              BloqueEspec("T2"; padres=[6], slot=4, sd=0, ident=70)]
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=1)   # P_DEFECTO ya es regla C
        est = T(params, "G")
        construir(est, params, especs)
        @test GhostdagRank.sp_de(est, 4) == 3                 # C1: sp = U (menor sd), no W
        @test GhostdagRank.ms_blues_de(est, 4) == [3, 2]      # U, W
        @test GhostdagRank.sp_de(est, 6) == 5                 # C2: sp = V (sin empate)
        @test GhostdagRank.ms_reds_de(est, 6) == [2]          # W, rojo_k
        @test !GhostdagRank.es_rojo_u3(est, 6, 2)
        @test cadena_seleccionada(est, 7) == [1, 3, 4, 7]     # G,U,C1,T1
        @test cadena_seleccionada(est, 8) == [1, 3, 5, 6, 8]  # G,U,V,C2,T2
        @test orden_aplicacion(est, params, 7) == [1, 3, 2, 4, 7]
        @test orden_aplicacion(est, params, 8) == [1, 3, 5, 2, 6, 8]
        @test BigInt(est.gd[4].bw) == 3 * W0
        @test BigInt(est.gd[6].bw) == 3 * W0
    end
end

@testset "D8 tres hermanos: el orden relativo no cambia con el contexto" begin
    especs_a = [BloqueEspec("P"; padres=[1], slot=1, sd=5, sr=0),
                BloqueEspec("Q"; padres=[1], slot=1, sd=9, sr=1),
                BloqueEspec("R"; padres=[1], slot=1, sd=1, sr=3),
                BloqueEspec("M"; padres=[2, 3, 4], slot=2, sd=0)]
    especs_b = [BloqueEspec("P"; padres=[1], slot=1, sd=5, sr=0),
                BloqueEspec("Q"; padres=[1], slot=1, sd=9, sr=1),
                BloqueEspec("R"; padres=[1], slot=1, sd=1, sr=3),
                BloqueEspec("Z1"; padres=[1], slot=1, sd=0, sr=0),
                BloqueEspec("Z2"; padres=[5], slot=2, sd=0, sr=0),
                BloqueEspec("Z3"; padres=[6], slot=3, sd=0, sr=0),
                BloqueEspec("N"; padres=[2, 3, 4, 7], slot=4, sd=0)]
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=30)
        # caso (a)
        est = T(params, "G")
        construir(est, params, especs_a)
        @test GhostdagRank.sp_de(est, 5) == 4                     # R, menor sd
        @test GhostdagRank.ms_blues_de(est, 5) == [4, 2, 3]       # R, P, Q
        @test BigInt(est.gd[5].bw) == 2 * W0 + big(2)^127 + big(2)^126
        @test orden_aplicacion(est, params, 5) == [1, 4, 2, 3, 5]
        # caso (b)
        est = T(params, "G")
        construir(est, params, especs_b)
        @test GhostdagRank.sp_de(est, 8) == 7                     # Z3, bw domina
        @test GhostdagRank.ms_blues_de(est, 8) == [7, 4, 2, 3]    # Z3, R, P, Q
        @test BigInt(est.gd[8].bw) == 5 * W0 + big(2)^127 + big(2)^126  # ver enmienda D8 en DERIVACIONES.md
        @test orden_aplicacion(est, params, 8) == [1, 5, 6, 7, 4, 2, 3, 8]
        # el orden relativo entre P(2) y Q(3) es el mismo en (a) y en (b): P antes que Q
        # (ya queda acreditado arriba: ms_blues_de termina en [...,2,3] en ambos casos)
        @test findfirst(==(2), GhostdagRank.ms_blues_de(est, 8)) <
              findfirst(==(3), GhostdagRank.ms_blues_de(est, 8))
    end
end

@testset "D9 dos copias, mismo sd y SR: cuál queda sin colorear" begin
    especs_a = [BloqueEspec("X"; padres=[1], slot=1, sd=4, ident=100),
                BloqueEspec("Y"; padres=[1], slot=1, sd=4, ident=100),
                BloqueEspec("M"; padres=[2, 3], slot=2, sd=0)]
    especs_b = [BloqueEspec("X"; padres=[1], slot=1, sd=4, ident=100),
                BloqueEspec("Y"; padres=[1], slot=1, sd=4, ident=100),
                BloqueEspec("Z1"; padres=[1], slot=1, sd=0),
                BloqueEspec("Z2"; padres=[4], slot=2, sd=0),
                BloqueEspec("Z3"; padres=[5], slot=3, sd=0),
                BloqueEspec("N"; padres=[2, 3, 6], slot=4, sd=0)]
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=30)
        # caso (a): Y queda rojo_U3 vía blue_idents(sp) (X ya es sp Y lleva el billete)
        est = T(params, "G")
        construir(est, params, especs_a)
        @test GhostdagRank.sp_de(est, 4) == 2
        @test GhostdagRank.ms_blues_de(est, 4) == [2]
        @test GhostdagRank.ms_reds_de(est, 4) == [3]
        @test GhostdagRank.es_rojo_u3(est, 4, 3)
        # caso (b): ninguno es sp; Y queda rojo_U3 vía `vistos` (orden del mergeset)
        est = T(params, "G")
        construir(est, params, especs_b)
        @test GhostdagRank.sp_de(est, 7) == 6
        @test GhostdagRank.ms_blues_de(est, 7) == [6, 2]
        @test GhostdagRank.ms_reds_de(est, 7) == [3]
        @test GhostdagRank.es_rojo_u3(est, 7, 3)
    end
end

@testset "D10 tres copias, sd distintos: sobrevive exactamente una" begin
    especs_a = [BloqueEspec("U"; padres=[1], slot=1, sd=3, ident=200),
                BloqueEspec("V"; padres=[1], slot=1, sd=1, ident=200),
                BloqueEspec("W"; padres=[1], slot=1, sd=2, ident=200),
                BloqueEspec("M"; padres=[2, 3, 4], slot=2, sd=0)]
    especs_b = [BloqueEspec("U"; padres=[1], slot=1, sd=3, ident=200),
                BloqueEspec("V"; padres=[1], slot=1, sd=1, ident=200),
                BloqueEspec("W"; padres=[1], slot=1, sd=2, ident=200),
                BloqueEspec("Z1"; padres=[1], slot=1, sd=0),
                BloqueEspec("Z2"; padres=[5], slot=2, sd=0),
                BloqueEspec("Z3"; padres=[6], slot=3, sd=0),
                BloqueEspec("N"; padres=[2, 3, 4, 7], slot=4, sd=0)]
    for T in (EstadoReferencia, EstadoRapido)
        params = Params(k=30)
        est = T(params, "G")
        construir(est, params, especs_a)
        @test GhostdagRank.sp_de(est, 5) == 3                     # V, menor sd
        @test GhostdagRank.ms_blues_de(est, 5) == [3]
        @test GhostdagRank.ms_reds_de(est, 5) == [4, 2]           # W, U (orden del mergeset)
        @test all(x -> GhostdagRank.es_rojo_u3(est, 5, x), [4, 2])
        est = T(params, "G")
        construir(est, params, especs_b)
        @test GhostdagRank.sp_de(est, 8) == 7                     # Z3
        @test GhostdagRank.ms_blues_de(est, 8) == [7, 3]          # Z3, V
        @test GhostdagRank.ms_reds_de(est, 8) == [4, 2]           # W, U
        @test all(x -> GhostdagRank.es_rojo_u3(est, 8, x), [4, 2])
    end
end

@testset "D11 R-FIN-11: 14 azules (FILTER) vs 1 (DYNAMIC)" begin
    copias = [BloqueEspec("C$i"; padres=[1], slot=1, sd=i, ident=300) for i in 1:14]
    especs = vcat(BloqueEspec("H1"; padres=[1], slot=1, sd=0),
                  BloqueEspec("H2"; padres=[2], slot=2, sd=0),
                  copias,
                  BloqueEspec("M"; padres=vcat([3], collect(4:17)), slot=3, sd=0))
    for T in (EstadoReferencia, EstadoRapido)
        pf = Params(k=30, u3_mode=U3_FILTER)
        est = T(pf, "G")
        construir(est, pf, especs)
        @test GhostdagRank.sp_de(est, 18) == 3   # H2
        azules_t3 = count(x -> est.idents[x] == 300, GhostdagRank.ms_blues_de(est, 18))
        @test azules_t3 == 14

        pd = Params(k=30, u3_mode=U3_DYNAMIC)
        est = T(pd, "G")
        construir(est, pd, especs)
        azules_t3d = count(x -> est.idents[x] == 300, GhostdagRank.ms_blues_de(est, 18))
        @test azules_t3d == 1
        @test count(x -> GhostdagRank.es_rojo_u3(est, 18, x), 4:17) == 13
    end
end

# ---------------------------------------------------------------------------
# Vectores oficiales de Kaspa (dag0..dag5)
# ---------------------------------------------------------------------------
@testset "Kaspa dag0..dag5" begin
    base = joinpath(@__DIR__, "..", "fixtures", "kaspa")
    for dag in 0:5
        ruta = joinpath(base, "dag$dag.json")
        obj = JSON3.read(read(ruta, String))
        k = Int(obj["K"])
        gen = String(obj["GenesisID"])
        nombres = String[gen]
        especs = BloqueEspec[]
        for b in obj["Blocks"]
            padres = [findfirst(==(String(p)), nombres) for p in b["Parents"]]
            push!(nombres, String(b["ID"]))
            push!(especs, BloqueEspec(String(b["ID"]); padres=padres, slot=0, sd=0,
                                      sr=typemax(UInt64) - 1, ident=0))
        end
        # 3.2(b): SP_KASPA/MERGE_KASPA explícitos — se declara que esto ejercita la
        # maquinaria GHOSTDAG (ordering.rs:38-42), no el desempate de ZEROX (regla C).
        # sd=0 y SR constante para todos los bloques ya lo hacían coincidir en la
        # práctica; ahora también coincide en la intención declarada del código.
        params = Params(k=k, u2=false, u3_mode=U3_OFF, sp_mode=SP_KASPA, merge_mode=MERGE_KASPA)
        total = 0
        for T in (EstadoReferencia, EstadoRapido)
            est = T(params, gen)
            construir(est, params, especs)
            for (j, b) in enumerate(obj["Blocks"])
                i = 1 + j
                sp_esp = findfirst(==(String(b["ExpectedSelectedParent"])), nombres)
                blues_esp = [findfirst(==(String(x)), nombres) for x in b["ExpectedBlues"]]
                reds_esp = [findfirst(==(String(x)), nombres) for x in b["ExpectedReds"]]
                @test GhostdagRank.sp_de(est, i) == sp_esp
                @test GhostdagRank.ms_blues_de(est, i) == blues_esp
                @test GhostdagRank.ms_reds_de(est, i) == reds_esp
                @test est.gd[i].blue_score == UInt64(b["ExpectedScore"])
                total += 4
            end
        end
        # nota: los "ExpectedReds"/"ExpectedBlues" de nivel superior (virtual) no se
        # comprueban: el propio harness de rusty-kaspa tampoco los comprueba
        # (consensus_integration_tests.rs:309-337 solo afirma datos por bloque).
        @test total == 8 * length(obj["Blocks"])
    end
end

# ---------------------------------------------------------------------------
# Validez estructural
# ---------------------------------------------------------------------------
@testset "validez estructural" begin
    params = P_DEFECTO
    for T in (EstadoReferencia, EstadoRapido)
        # 16 padres → :toomanyparents
        hnos = [BloqueEspec("H$i"; padres=[1], slot=1) for i in 1:16]
        est = T(params, "G")
        _, motivos = construir(est, params, hnos)
        @test all(==(:ok), motivos)
        ok = anadir!(est, params, "X", collect(2:17), UInt64(2), UInt64(0), UInt64(0), UInt64(0))
        @test !ok && est.motivo[end] == :toomanyparents
        # slot no monótono
        est = T(params, "G")
        _, motivos = construir(est, params, [BloqueEspec("A"; padres=[1], slot=5),
                                             BloqueEspec("B"; padres=[2], slot=4)])
        @test motivos[1] == :ok && motivos[2] == :slot_no_monotono
        # salto > S_max (el bloque se rechaza; no se añaden bloques después)
        est = T(params, "G")
        _, motivos = construir(est, params, [BloqueEspec("A"; padres=[1], slot=200)])
        @test motivos[1] == :salto_mayor_smax
        # U2: misma identidad en el pasado
        est = T(params, "G")
        _, motivos = construir(est, params, [BloqueEspec("A"; padres=[1], slot=1, ident=9),
                                             BloqueEspec("B"; padres=[2], slot=2, ident=9)])
        @test motivos[1] == :ok && motivos[2] == :u2
        # copias en anticono NO son U2 (válidas)
        est = T(params, "G")
        _, motivos = construir(est, params, [BloqueEspec("A"; padres=[1], slot=1, ident=9),
                                             BloqueEspec("B"; padres=[1], slot=1, ident=9)])
        @test all(==(:ok), motivos)
    end
    # mergeset > 180 → :mergesettoobig (patrón del t6 del Python histórico)
    hnos190 = [BloqueEspec("S$i"; padres=[1], slot=1) for i in 1:190]
    caps = BloqueEspec[]
    inicio = 2
    while inicio <= 191
        fin = min(inicio + 14, 191)
        push!(caps, BloqueEspec("K$(length(caps) + 1)"; padres=collect(inicio:fin), slot=2))
        inicio = fin + 1
    end
    @test length(caps) == 13
    for T in (EstadoReferencia, EstadoRapido)
        est = T(params, "G")
        _, motivos = construir(est, params, [hnos190; caps])
        @test all(==(:ok), motivos)
        idx_inicio = est.n - 12               # índices de los 13 caps
        ok = anadir!(est, params, "BIG", collect(idx_inicio:est.n), UInt64(3), UInt64(0),
                     UInt64(0), UInt64(0))
        @test !ok && est.motivo[end] == :mergesettoobig
    end
end

# ---------------------------------------------------------------------------
# Oráculo vs kernel: equivalencia exacta en DAGs aleatorios
# ---------------------------------------------------------------------------
@testset "oráculo == kernel (DAGs aleatorios)" begin
    params = P_DEFECTO
    rng = StableRNG(0x0ACAC10)
    for t in 1:500
        n = 4 + rand(rng, 0:36)
        especs = generar_dag(rng, n)
        ref = entregar(EstadoReferencia, params, especs, collect(1:n), "G")
        rap = entregar(EstadoRapido, params, especs, collect(1:n), "G")
        @test equivalencia(ref, rap, params)
    end
    for t in 1:120
        n = 60 + rand(rng, 0:60)
        especs = generar_dag(rng, n)
        ref = entregar(EstadoReferencia, params, especs, collect(1:n), "G")
        rap = entregar(EstadoRapido, params, especs, collect(1:n), "G")
        @test equivalencia(ref, rap, params)
    end
    # también en los modos python y kaspa (los comparadores se ejercitan aparte)
    for modo in ((SP_PYTHON, MERGE_PYTHON), (SP_KASPA, MERGE_KASPA))
        pm = Params(k=8, sp_mode=modo[1], merge_mode=modo[2])
        rng2 = StableRNG(0xBEEF + UInt64(Int(modo[2])))
        for t in 1:60
            n = 4 + rand(rng2, 0:40)
            especs = generar_dag(rng2, n)
            ref = entregar(EstadoReferencia, pm, especs, collect(1:n), "G")
            rap = entregar(EstadoRapido, pm, especs, collect(1:n), "G")
            @test equivalencia(ref, rap, pm)
        end
    end
end

# ---------------------------------------------------------------------------
# Determinismo: ≥ 1 000 órdenes de entrega por familia, resultados idénticos
# ---------------------------------------------------------------------------
@testset "determinismo: 1 000 órdenes por familia" begin
    # params = P_DEFECTO = regla C (SP_ZEROX+MERGE_SPEC) desde Corrección 1 (3.2e).
    params = P_DEFECTO
    # 3.2(e): al menos una familia con ventana <= 6 — la primera (usa el fix de 3.1).
    for (semilla, n, ventana) in ((0x006D61, 120, 6), (0x006D62, 150, typemax(Int)),
                                  (0x006D63, 180, typemax(Int)))
        rng = StableRNG(semilla)
        especs = generar_dag(rng, n; ventana=ventana)
        rng2 = StableRNG(semilla)
        ordenes = ordenes_topologicos(rng2, especs, 1000)
        ref = entregar(EstadoRapido, params, especs, ordenes[1], "G")
        tip = virtual_sp(ref, params)
        base_gd = gd_por_id_abstracto(ref)
        base_orden = proyeccion_orden_por_id(ref, params, tip)
        for orden in ordenes[2:end]
            est = entregar(EstadoRapido, params, especs, orden, "G")
            tip2 = virtual_sp(est, params)
            @test id_a_texto(est.ids[tip2]) == id_a_texto(ref.ids[tip])
            @test gd_por_id_abstracto(est) == base_gd
            @test proyeccion_orden_por_id(est, params, tip2) == base_orden
        end
    end
end

# ---------------------------------------------------------------------------
# rank: totalidad y compatibilidad causal (exhaustivo + aleatorio)
# ---------------------------------------------------------------------------
@testset "rank: totalidad y causalidad" begin
    params = P_DEFECTO
    function verificar_dag(n, lista, sds, srs)
        especs = [BloqueEspec("G", Int[], UInt64(0), UInt64(0), UInt64(0), UInt64(0))]
        for i in 2:n
            push!(especs, BloqueEspec("b$i"; padres=lista[i - 1], slot=i, sd=sds[i - 1],
                                      sr=srs[i - 1]))
        end
        est = entregar(EstadoRapido, params, especs, collect(1:n), "G")
        for i in 2:n, p in lista[i - 1]
            @test es_menor_rank(est, p, i)
            @test !es_menor_rank(est, i, p)
        end
        # 3.4: totalidad exhaustiva sobre TODOS los pares (no solo padre-hijo) — para
        # cada par de bloques distintos se cumple EXACTAMENTE uno de <, > (nunca los
        # dos, nunca ninguno; el id como último componente hace la tupla total).
        for i in 1:n, j in 1:n
            i == j && continue
            a = es_menor_rank(est, i, j)
            b = es_menor_rank(est, j, i)
            @test a != b
        end
        # 3.4(ii), premisa: sp(B) ∈ blues(B) siempre (protocol.rs:138; referencia.jl,
        # rapido.jl). Se comprueba en todos los DAGs de esta enumeración exhaustiva.
        for i in 2:n
            sp = GhostdagRank.sp_de(est, i)
            @test sp in GhostdagRank.ms_blues_de(est, i)
        end
    end
    # enumeración exhaustiva de TODOS los DAGs con n ≤ 6 (padres no vacíos anteriores)
    contador = 0
    for n in 2:6
        salida = Vector{Vector{Vector{Int}}}()
        actual = Vector{Vector{Int}}()
        function rec(i)
            if i > n
                push!(salida, copy(actual))
                return
            end
            for m in 1:(2^(i - 1) - 1)
                padres = [j for j in 1:(i - 1) if ((m >> (j - 1)) & 1) == 1]
                push!(actual, padres)
                rec(i + 1)
                pop!(actual)
            end
        end
        rec(2)
        sds = [UInt64((i * 37) % 100) for i in 2:n]
        srs = [UInt64((i * 101) % 7) for i in 2:n]
        for lista in salida
            verificar_dag(n, lista, sds, srs)
            contador += 1
        end
    end
    @test contador == 1 + 3 + 21 + 315 + 9765
    # aleatorio mediano
    rng = StableRNG(0x1A11)
    for t in 1:50
        especs = generar_dag(rng, 120 + rand(rng, 0:80))
        est = entregar(EstadoRapido, params, especs, collect(1:length(especs)), "G")
        for i in 2:length(especs)
            for p in especs[i].padres
                @test es_menor_rank(est, p, i)
            end
            # 3.4(ii): sp(B) ∈ blues(B), también en los DAGs aleatorios medianos.
            @test GhostdagRank.sp_de(est, i) in GhostdagRank.ms_blues_de(est, i)
        end
    end
end

# ---------------------------------------------------------------------------
# P1: el desempate final por id es redundante con rank = (bw, sd, id)
# ---------------------------------------------------------------------------
@testset "P1: desempate por id redundante" begin
    params = P_DEFECTO
    rng = StableRNG(0x000D1)
    grupos = 0
    empates_bw_sd = 0
    for t in 1:100
        n = 60 + rand(rng, 0:60)
        especs = generar_dag(rng, n)
        est = entregar(EstadoRapido, params, especs, collect(1:n), "G")
        tip = virtual_sp(est, params)
        color = Dict{Int,UInt8}()
        ch = cadena_seleccionada(est, tip)
        for c in ch
            color[c] = 0x00   # los bloques de cadena (incluida la punta) son azules
        end
        for c in ch
            for x in GhostdagRank.ms_blues_de(est, c)
                color[x] = 0x00
            end
            for x in GhostdagRank.ms_reds_de(est, c)
                color[x] = GhostdagRank.es_rojo_u3(est, c, x) ? 0x02 : 0x01
            end
        end
        por_billete = Dict{UInt64,Vector{Int}}()
        for i in 2:n
            id = est.idents[i]
            id == 0 && continue
            # solo bloques de la historia seleccionada (past(tip) ∪ {tip}):
            # el color contextual no existe para bloques fuera de past(tip)
            (i == tip || i in est.anc[tip]) || continue
            push!(get!(por_billete, id, Int[]), i)
        end
        for (_, copias) in por_billete
            eligibles = [x for x in copias if color[x] != 0x02]
            isempty(eligibles) && continue
            grupos += 1
            # (i) la clave P1 completa (color, rank, id) es total: ninguna pareja
            # distinta empata, porque rank ya contiene el id
            for x in eligibles, y in eligibles
                x >= y && continue
                kx = (color[x], (est.gd[x].bw, est.sds[x], est.ids[x]))
                ky = (color[y], (est.gd[y].bw, est.sds[y], est.ids[y]))
                @test kx != ky
                if color[x] == color[y] && est.gd[x].bw == est.gd[y].bw &&
                   est.sds[x] == est.sds[y]
                    empates_bw_sd += 1   # el id dentro del rank sí decide
                end
            end
            # (ii) el ganador por (color, rank) es ÚNICO y coincide con el de
            # (color, rank, id): el id final de P1 nunca rompe un empate
            claves = [(color[x], (est.gd[x].bw, est.sds[x], est.ids[x])) for x in eligibles]
            m = minimum(claves)
            @test count(==(m), claves) == 1
            m2 = minimum([(color[x], (est.gd[x].bw, est.sds[x], est.ids[x]), x)
                          for x in eligibles])
            @test m2[3] == eligibles[findfirst(==(m), claves)]
        end
    end
    @test grupos > 0
    @test empates_bw_sd > 0
end

# ---------------------------------------------------------------------------
# Corrección 1, tarea 3.1 — generar_dag colgaba con ventana < 4 (validacion.jl:57
# original: npadres podía pedir hasta 4 padres distintos con menos de 4 candidatos
# en la ventana). Fix: acotar también por i-lo, sin tocar la secuencia de rand().
# ---------------------------------------------------------------------------
@testset "3.1 generador: fix del cuelgue en ventana chica" begin
    # Prueba 1: para ventana >= 4 el fix es un no-op — comprobado empíricamente
    # revirtiendo temporalmente la línea y comparando sha256 byte a byte contra el
    # código v0.1 (ver PROGRESO-GHOSTDAG.md, Corrección 1); aquí queda fijado como
    # regresión con huellas Base.hash (válidas bajo el Julia pineado en
    # julia-version.toml; si se cambia de versión, recalcular con tmp/pin_hashes.jl).
    function huella_u64(especs)
        h = UInt64(0)
        for e in especs
            h = hash((e.id, e.padres, e.slot, e.sd, e.sr, e.ident), h)
        end
        return h
    end
    esperadas = Dict(
        (UInt64(0x1), 4)  => UInt64(0xf7ee55f9876fbd14),
        (UInt64(0x1), 30) => UInt64(0xa92ca2148b5b3276),
        (UInt64(0x2a), 4) => UInt64(0xb75c8a3f7e419d45),
        (UInt64(0x2a), 30) => UInt64(0x0a6543f6c7a596e9),
    )
    for ((seed, ventana), esperado) in esperadas
        rng = StableRNG(seed)
        especs = GhostdagRank.generar_dag(rng, 50; ventana=ventana)
        @test huella_u64(especs) == esperado
    end

    # Prueba 2 (nueva): con ventana 1, 2 y 3 el generador debe TERMINAR. Antes del
    # fix, esto colgaba (confirmado con timeout de 8 s sobre el código v0.1
    # reconstruido: se quedaba en el `while` de validacion.jl:63 pidiendo un 4º
    # padre distinto a una ventana de tamaño 2).
    for ventana in (1, 2, 3)
        rng = StableRNG(UInt64(0x77))
        especs = GhostdagRank.generar_dag(rng, 200; ventana=ventana)
        @test length(especs) == 200
        # cada padre debe estar dentro de la ventana declarada (o ser el hermano fijado)
        for i in 2:200
            for p in especs[i].padres
                @test p >= max(1, i - ventana) || especs[i].ident == especs[i-1].ident
            end
        end
    end
end

end # testset raíz
