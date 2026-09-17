# CLI reproducible del oráculo (H-08a). Escribe `resultados/vectores.txt`.
#
# Línea de ejecución documentada:
#
#   JULIA_DEPOT_PATH=<implementacion-02>/lineo/.depot \
#     env -u LD_LIBRARY_PATH ../julia.sh --project=. run.jl
#
# (o directamente `julia --project=. run.jl` con el depot contenido).

using SHA

include(joinpath(@__DIR__, "src", "referencia.jl"))

function a_hex(b::Vector{UInt8})
    return bytes2hex(b)
end

function main()
    # Ancla de cordura del oráculo: si esto falla, Julia no está usando SHA3-256 FIPS 202.
    vacio = bytes2hex(sha3_256(UInt8[]))
    @assert vacio == "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a" "SHA3-256 vacío incorrecto: $vacio"

    v = vectores()

    # Validaciones estructurales independientes (SPEC §6.1).
    @assert length(v.wire) == 621 "el wire debe medir 621 B para P = 2, mide $(length(v.wire))"
    @assert length(v.txid1) == 32 && length(v.auth1) == 32

    dir = joinpath(@__DIR__, "resultados")
    mkpath(dir)
    ruta = joinpath(dir, "vectores.txt")
    open(ruta, "w") do io
        println(io, "sha3_vacio=", vacio)
        println(io, "txid1=", a_hex(v.txid1))
        println(io, "txid2=", a_hex(v.txid2))
        println(io, "auth1=", a_hex(v.auth1))
        println(io, "auth2=", a_hex(v.auth2))
        println(io, "body_commitment=", a_hex(v.body_commitment))
        println(io, "merkle_root=", a_hex(v.merkle_root))
        println(io, "wire=", a_hex(v.wire))
        println(io, "pre_hash=", a_hex(v.pre_hash))
        println(io, "block_hash=", a_hex(v.block_hash))
    end
    println("escrito ", ruta)
    println("pre_hash=", a_hex(v.pre_hash))
    println("block_hash=", a_hex(v.block_hash))
    println("body_commitment=", a_hex(v.body_commitment))
end

main()
