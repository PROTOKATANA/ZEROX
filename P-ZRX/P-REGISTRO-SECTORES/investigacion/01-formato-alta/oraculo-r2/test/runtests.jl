# Autorreferencia del oráculo: comprueba la primitiva SHA3-256 contra un vector NIST y que la
# construcción H_d separa dominio. No depende del prototipo Rust.

include(joinpath(@__DIR__, "..", "src", "oraculo.jl"))
using .OraculoS01
using Test
using SHA

@testset "oráculo S01" begin
    @test bytes2hex(sha3_256(codeunits("abc"))) ==
          "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"

    # H_d(tag, m) = SHA3-256(tag ‖ m), y el prefijo cambia el digest.
    m = Vector{UInt8}(codeunits("mensaje"))
    a = OraculoS01.h_d(Vector{UInt8}(codeunits("ZZKSectorHoja___")), m)
    b = OraculoS01.h_d(Vector{UInt8}(codeunits("ZZKSectorNodo___")), m)
    @test a != b
    @test bytes2hex(a) ==
          bytes2hex(sha3_256(vcat(Vector{UInt8}(codeunits("ZZKSectorHoja___")), m)))

    # Relleno hasta potencia de dos: 3 hojas y 4 hojas producen raíces distintas, y la raíz de 4
    # hojas coincide con el cálculo por pares.
    vacio = OraculoS01.h_d(OraculoS01.TAG_VACIO, UInt8[])
    @test length(vacio) == 32
    hojas3 = [OraculoS01.h_d(OraculoS01.TAG_HOJA, UInt8[UInt8(i)]) for i in 1:3]
    @test length(OraculoS01.merkle(hojas3)) == 32
end
