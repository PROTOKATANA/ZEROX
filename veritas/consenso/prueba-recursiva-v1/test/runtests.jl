using Test
using Printf

include(joinpath(@__DIR__, "..", "src", "PruebaRecursiva.jl"))
using .PruebaRecursiva

@testset "PRV-v0.1" begin

    @testset "factores citados" begin
        f = P_FACTORES
        @test f.sboxes_por_perm == 80          # 8·3 + 56, halo2_poseidon P128Pow5T3
        @test f.gates_por_sbox_lo <= f.gates_por_sbox_hi
        @test f.ops_campo_1hilo > 0 && f.ops_campo_24hilos > f.ops_campo_1hilo
    end

    @testset "referencia de pasado y mergeset" begin
        # DAG: 1←2←3, 1←4, 3←5, 4←5 (5 fusiona 3 y 4)
        padres = [Int[], [1], [2], [1], [3, 4]]
        past = pasado_estricto(padres)
        @test past[5] == Set([1, 2, 3, 4])
        @test !ancestro(past, 5, 5)
        # con sp=3: mergeset(5) = past(5) \ (past(3) ∪ {3}) = {4}
        @test mergeset_referencia(past, 5, 3) == Set([4])
        # anticono dentro de un blueset explícito
        @test anticono_en(past, 4, Set([3, 4])) == 1   # 3 y 4 incomparables; 4 se cuenta
    end

    @testset "coste: monotónico en W y mayor que lineal" begin
        c = ConteoOperaciones(100, fill(4, 100), fill(1000, 100), fill(0, 100),
                              fill(1, 100), fill(2, 100), fill(5, 100), fill(8, 100))
        r1 = coste_restricciones(c, 1, P_FACTORES).por_bloque
        r10 = coste_restricciones(c, 10, P_FACTORES).por_bloque
        r1000 = coste_restricciones(c, 1000, P_FACTORES).por_bloque
        @test r1 <= r10 <= r1000
        @test r1 > 0
        lin = factor_lineal(c, 1000, P_FACTORES)
        @test lin.factor > 1
        @test pares_anticone(c, 100) == 100 * 4 * 100
        @test pares_anticone(c, 1000) == 100 * 4 * 1000
    end

    @testset "tasa de cierre inversa" begin
        f = P_FACTORES
        @test tasa_cierre(1.0e9, f.ops_campo_1hilo) == 1.0
        @test bloques_por_segundo_que_cierra(1.0e9, f).un_hilo ≈ 1.0
    end

    @testset "selección: dos historias válidas, distinta canónica (GDR-v0.2)" begin
        GDR = incluir_ghostdag()
        v = Base.invokelatest(valida_seleccion, GDR; n=40, seed=UInt64(7))
        @test v.acepta1
        @test v.acepta2
        @test v.distintas
        @test v.bw2 > v.bw1
    end

    @testset "equivalencia conteo rápido vs referencia independiente" begin
        GDR = incluir_ghostdag()
        e = Base.invokelatest(equivalencia_conteos, GDR; nrep=10, nmax=12,
                              seed=UInt64(0x11))
        @test e.fallos == 0
        @test e.comprobaciones > 0
    end
end
