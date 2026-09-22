using Dates
using SembradorV1

const CAMPOS = (
    "--rho",
    "--L",
    "--I",
    "--W-dec",
    "--coste-intento",
    "--recompensa",
    "--espacio-honesto",
)

function uso(io::IO = stderr)
    println(io, "Uso reproducible (todos los valores son obligatorios y admiten listas separadas por coma):")
    println(io, "  run.jl --rho R... --L slots... --I slots... --W-dec slots... \\")
    println(io, "         --coste-intento C... --recompensa R... --espacio-honesto H... [--salida ruta]")
end

function parsear_argumentos(args::Vector{String})
    valores = Dict{String,String}()
    i = 1
    while i <= length(args)
        clave = args[i]
        clave == "--help" && (uso(stdout); exit(0))
        i == length(args) && error("falta valor para $clave")
        haskey(valores, clave) && error("argumento repetido: $clave")
        valores[clave] = args[i + 1]
        i += 2
    end
    permitidos = Set((CAMPOS..., "--salida"))
    desconocidos = setdiff(Set(keys(valores)), permitidos)
    isempty(desconocidos) || error("argumentos desconocidos: $(join(sort!(collect(desconocidos)), ", "))")
    faltantes = filter(campo -> !haskey(valores, campo), CAMPOS)
    isempty(faltantes) || error("faltan argumentos obligatorios: $(join(faltantes, ", "))")
    return valores
end

function lista_numerica(texto::String, nombre::String)
    partes = split(texto, ',')
    isempty(partes) && error("lista vacía para $nombre")
    return [parse(Float64, strip(parte)) for parte in partes]
end

function hash_git()
    raiz = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
    try
        return readchomp(`git -C $raiz rev-parse HEAD`)
    catch
        return "no-disponible"
    end
end

function main(args::Vector{String})
    entrada = parsear_argumentos(args)
    rhos = lista_numerica(entrada["--rho"], "rho")
    Ls = lista_numerica(entrada["--L"], "L")
    Is = lista_numerica(entrada["--I"], "I")
    Wdecs = lista_numerica(entrada["--W-dec"], "W-dec")
    costes = lista_numerica(entrada["--coste-intento"], "coste-intento")
    recompensas = lista_numerica(entrada["--recompensa"], "recompensa")
    espacios = lista_numerica(entrada["--espacio-honesto"], "espacio-honesto")

    filas = prod(length.((rhos, Ls, Is, Wdecs, costes, recompensas, espacios)))
    filas <= 1_000_000 || error("el barrido excede 1 000 000 de filas y el presupuesto de disco")

    parametros = Vector{ParametrosMargen{Float64}}()
    sizehint!(parametros, filas)
    for rho in rhos, L in Ls, I in Is, Wdec in Wdecs, coste in costes,
        recompensa in recompensas, espacio in espacios
        push!(parametros, ParametrosMargen(rho, L, I, Wdec, coste, recompensa, espacio))
    end
    resultados = Vector{ResultadoMargen{Float64}}(undef, length(parametros))
    barrer!(resultados, parametros)

    salida = get(entrada, "--salida", joinpath(@__DIR__, "resultados", "barrido.tsv"))
    mkpath(dirname(abspath(salida)))
    fecha = Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS")
    open(salida, "w") do io
        println(io, "# modelo=sembrador-v1")
        println(io, "# estado=condicional; ningún valor de consenso, precio o hardware se adopta")
        println(io, "# fecha=$fecha")
        println(io, "# git=$(hash_git())")
        println(io, "# julia=$VERSION cpu=$(Sys.CPU_NAME) threads=$(Threads.nthreads(:default))/$(Threads.nthreads(:interactive))")
        println(io, "# argumentos=$(join(args, ' '))")
        println(io, "rho\tL_slots\tI_slots\tW_dec_slots\tcoste_intento\trecompensa\tH_efectivo_Nh_sobre_lambda\tadelanto_slots\tdesafios_futuros\tq_al_menos_un_exito\tsoluciones_esperadas_intento\tintentos_por_candidato_no_vacio\tintentos_por_bloque\tcoste_por_bloque\tmargen_coste_beneficio\tregion")
        for (p, r) in zip(parametros, resultados)
            region = r.desafios_futuros == 0 ? "sin_ventana_dirigida" :
                (r.rentable ? "rentable" : "no_rentable")
            println(
                io,
                join(
                    (
                        p.rho,
                        p.L_slots,
                        p.I_slots,
                        p.W_dec_slots,
                        p.coste_intento,
                        p.recompensa,
                        p.espacio_honesto,
                        r.adelanto_slots,
                        r.desafios_futuros,
                        r.probabilidad_exito_intento,
                        r.soluciones_esperadas_por_intento,
                        r.intentos_esperados_por_candidato,
                        r.intentos_esperados_por_bloque,
                        r.coste_esperado_por_bloque,
                        r.margen_coste_beneficio,
                        region,
                    ),
                    '\t',
                ),
            )
        end
    end

    println("filas=$(length(resultados)) salida=$(abspath(salida))")
    println("rentables=$(count(r -> r.rentable, resultados)) sin_ventana=$(count(r -> r.desafios_futuros == 0, resultados))")
end

try
    main(ARGS)
catch error
    uso()
    rethrow(error)
end
