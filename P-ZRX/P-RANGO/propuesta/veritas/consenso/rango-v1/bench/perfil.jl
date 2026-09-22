# perfil.jl — inferencia, diagnósticos, perfil y JET (LINEO §6).
#
#   ./veritas/julia.sh --project=P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1 \
#       P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1/bench/perfil.jl

include(joinpath(@__DIR__, "..", "src", "RangoV1.jl"))
using .RangoV1
using Profile
using InteractiveUtils: code_warntype
using JET

const C = ConfigControlador(w_slots=20, g_slots=20, q=10,
                            ganancia_num=1, ganancia_den=2,
                            paso_lo_num=1, paso_lo_den=2,
                            paso_hi_num=2, paso_hi_den=1,
                            sr_min=2048, sr_max=UInt64(2)^32,
                            r_inicial=UInt64(2)^20, retardos_ventana=2)

function carga(n)
    r = C.r_inicial
    acc = zero(UInt64)
    for i in 1:n
        n_i = UInt64(4 + (i % 17))
        out, _ = controlador_fast(r, n_i, C)
        r = out
        acc += peso_fast(out)
    end
    return acc
end

function main()
    carga(100)                                   # calentamiento
    println("allocated_bytes_controlador=", @allocated controlador_fast(C.r_inicial, UInt64(4), C))
    println("allocated_bytes_peso=", @allocated peso_fast(UInt64(2048)))
    println("tipo_retorno_inferido=", Base.return_types(controlador_fast,
                                                         (UInt64, UInt64, ConfigControlador)))

    io = IOBuffer()
    code_warntype(io, controlador_fast, (UInt64, UInt64, ConfigControlador))
    texto = String(take!(io))
    write(joinpath(@__DIR__, "..", "resultados", "CODEWARNTYPE.txt"), texto)
    # `::Any` es lo que delata inestabilidad real; el literal «Any» también aparece en el
    # `Core.PartialStruct(... Any[...])` interno de `Core.tuple`, que no es una inestabilidad.
    inestables = count(l -> occursin("::Any", l), split(texto, "\n"))
    println("code_warntype_lineas_con_::Any=", inestables)

    Profile.clear()
    @profile carga(200_000)
    perfil = IOBuffer()
    Profile.print(perfil; format=:flat, sortedby=:count, mincount=1)
    println("perfil_lineas=", countlines(IOBuffer(String(take!(perfil)))))

    # JET 0.12.1 por su API de resultados: `report_opt(f, tipos)` + `get_reports`.
    res = JET.report_opt(controlador_fast, Tuple{UInt64, UInt64, ConfigControlador})
    reps = JET.get_reports(res)
    jet_lineas = ["report_opt(controlador_fast, Tuple{UInt64,UInt64,ConfigControlador})",
                  "diagnosticos=$(length(reps))"]
    for r in reps
        push!(jet_lineas, string(typeof(r)))
    end
    res_peso = JET.report_opt(peso_fast, Tuple{UInt64})
    push!(jet_lineas, "report_opt(peso_fast, Tuple{UInt64}) diagnosticos=" *
                      string(length(JET.get_reports(res_peso))))
    write(joinpath(@__DIR__, "..", "resultados", "JET.txt"), join(jet_lineas, "\n") * "\n")
    println("jet_diagnosticos=", length(reps))
    println("PERFIL_OK")
end

main()
