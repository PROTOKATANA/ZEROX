# Pruebas del oráculo de formatos v0 (ORDEN-W02, LINEO §5.1).
#
# Valida el propio oráculo antes de creerle un solo vector:
#   (a) SHA3-256 del mensaje vacío contra el vector NIST (FIPS 202);
#   (b) reproduce tres `txid` v1 antiguos de los tests de `zx-core` (requisito §9(b));
#   (c) recalcula `CBID_RED_DEV` y `MAGIC_DEV` desde su fórmula (F-12 / C-NET-01).

using Test
using SHA

include(joinpath(@__DIR__, "..", "src", "referencia.jl"))
using .ReferenciaFormatoV0

const R = ReferenciaFormatoV0

@testset "oráculo formato v0" begin
    @testset "(a) SHA3-256 NIST del vacío" begin
        @test bytes2hex(R.sha3_vacio()) == "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"
    end

    @testset "(b) tres txid v1 antiguos" begin
        @test bytes2hex(R.txid(R.tx_antiguo(UInt8(1), 5_000), R.CBID_ANTIGUO)) == R.ANCLA_1
        @test bytes2hex(R.txid(R.tx_antiguo(UInt8(2), 3_000), R.CBID_ANTIGUO)) == R.ANCLA_2
        @test bytes2hex(R.txid(R.tx_ancla_3(), R.CBID_ANTIGUO)) == R.ANCLA_3
    end

    @testset "(c) derivación de red (F-12 / C-NET-01)" begin
        h = SHA.sha3_256(Vector{UInt8}(codeunits("ZEROX hibrido red dev v0")))
        @test h[1:4] == UInt8[0xa7, 0x66, 0xb4, 0xa8]
        @test R.CBID_RED_DEV == 0xa8b466a7
        m = SHA.sha3_256(Vector{UInt8}(codeunits("ZEROX/dev/magic")))
        @test m[1:4] == R.MAGIC_DEV
    end

    @testset "casos nuevos bien formados" begin
        cs = R.casos()
        @test length(cs) >= 12
        nombres = [c.nombre for c in cs]
        @test length(unique(nombres)) == length(nombres)
        for c in cs
            @test !isempty(R.tx_wire(c.tx, c.testigos))
            @test length(R.txid(c.tx, c.cbid)) == 32
            if c.tx.version == 2
                @test length(c.testigos) == length(c.tx.entradas) + 1
                @test length(c.testigos[end]) == 64
                @test length(R.mensaje_aceptacion(c.tx, c.cbid)) == 32
                @test length(R.campos_extra(c.tx)) == 41  # 1 tipo + 32 clave + 8 importe
            elseif c.tx.version == 3
                @test isempty(c.tx.entradas) && isempty(c.tx.salidas) && isempty(c.testigos)
                @test length(R.campos_extra(c.tx)) == 40  # 32 clave + 8 importe
            else
                @test isempty(R.campos_extra(c.tx))
            end
        end
    end
end
