# CLI reproducible del oráculo de formatos v0.1 (ORDEN-W02b, LINEO §1).
#
# Genera `testdata/formato-v0.1/vectores.txt` a partir de `src/referencia.jl`. No hay aleatoriedad:
# el cálculo es determinista y la semilla se acepta y se registra (V4) para que la línea de
# ejecución publicada sea la de LINEO.

using SHA

include(joinpath(@__DIR__, "src", "referencia.jl"))
using .ReferenciaFormatoV0

const R = ReferenciaFormatoV0

function parse_args(args)
    semilla = UInt64(0x5a5a)
    salida = joinpath(@__DIR__, "testdata", "formato-v0.1", "vectores.txt")
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--seed"
            i += 1
            i <= length(args) || error("--seed necesita un valor")
            semilla = parse(UInt64, replace(args[i], "0x" => ""; count = 1); base = 16)
        elseif a == "--out"
            i += 1
            i <= length(args) || error("--out necesita una ruta")
            salida = args[i]
        else
            error("argumento no reconocido: $a (usa --seed y --out)")
        end
        i += 1
    end
    return semilla, salida
end

function main()
    semilla, salida = parse_args(ARGS)
    mkpath(dirname(salida))
    open(salida, "w") do io
        println(io, "# ORDEN-W02b — vectores de formato v0.1 (ZEROX híbrido) generados por el oráculo")
        println(io, "# Julia independiente. NO editar a mano: regenerar con run.jl.")
        println(io, "# semilla=0x", string(semilla, base = 16), " julia=", VERSION)
        println(io, "# Formato: 'clave valor...' separado por espacios. Las líneas 'caso' son:")
        println(io, "#   caso <nombre> <version> <cbid_hex8> <tipo|-> <wire_hex> <txid_hex> <mensaje|->")
        println(io, "sha3_vacio ", bytes2hex(R.sha3_vacio()))
        println(io, "txid_v1_antiguo_1 ", R.ANCLA_1)
        println(io, "txid_v1_antiguo_2 ", R.ANCLA_2)
        println(io, "txid_v1_antiguo_3 ", R.ANCLA_3)
        println(io, "cbid_red_dev ", string(R.CBID_RED_DEV, base = 16, pad = 8))
        println(io, "magic_dev ", bytes2hex(R.MAGIC_DEV))
        for c in R.casos()
            tipo = c.tx.tipo === nothing ? "-" : string(c.tx.tipo)
            msg = c.tx.version == 2 ? bytes2hex(R.mensaje_aceptacion(c.tx, c.cbid)) : "-"
            wire = bytes2hex(R.tx_wire(c.tx, c.testigos))
            tid = bytes2hex(R.txid(c.tx, c.cbid))
            fields = ["caso", c.nombre, string(c.tx.version),
                      string(c.cbid, base = 16, pad = 8), tipo, wire, tid, msg]
            println(io, join(fields, " "))
        end
    end
    println("vectores escritos en $salida (semilla=0x", string(semilla, base = 16), ", julia=$VERSION)")
end

main()
