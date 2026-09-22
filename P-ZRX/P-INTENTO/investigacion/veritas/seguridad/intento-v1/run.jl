using Dates
using IntentoV1

const OBLIGATORIOS = ("--mediciones",)

function uso(io::IO = stderr)
    println(io, "Uso reproducible:")
    println(io, "  run.jl --mediciones RUTA [--salida RUTA]")
    println(io, "         [--rango-solucion R_s] [--N-h piezas] [--alpha a] [--tau-s s]")
    println(io, "         [--pi-DAG p] [--w-fijos 1,10,100,1000,10000]")
    println(io, "         [--w-min 1e2 --w-max 1e5 --pasos 64] [--gpu-r tablas/s]")
    println(io)
    println(io, "Todas las cifras de hardware salen del fichero de medidas del banco Rust.")
    println(io, "`w`, `alpha`, `N_h`, `tau_s`, `pi_DAG` y `R_s` son ENTRADAS: el instrumento no fija")
    println(io, "ninguna y no emite ningún resultado monetario.")
end

function parsear(args::Vector{String})
    valores = Dict{String,String}()
    i = 1
    while i <= length(args)
        clave = args[i]
        if clave == "--help" || clave == "-h"
            uso(stdout)
            exit(0)
        end
        i == length(args) && error("falta valor para $clave")
        haskey(valores, clave) && error("argumento repetido: $clave")
        valores[clave] = args[i+1]
        i += 2
    end
    conocidos = Set((
        "--mediciones", "--salida", "--rango-solucion", "--N-h", "--alpha", "--tau-s",
        "--pi-DAG", "--w-fijos", "--w-min", "--w-max", "--pasos", "--gpu-r",
    ))
    desconocidos = setdiff(Set(keys(valores)), conocidos)
    isempty(desconocidos) || error("argumentos desconocidos: $(join(sort!(collect(desconocidos)), ", "))")
    for campo in OBLIGATORIOS
        haskey(valores, campo) || error("falta el argumento obligatorio $campo")
    end
    return valores
end

num(v, clave, por_defecto) = haskey(v, clave) ? parse(Float64, v[clave]) : por_defecto

function main(args::Vector{String})
    entrada = parsear(args)

    ruta_mediciones = entrada["--mediciones"]
    isfile(ruta_mediciones) || error("no existe el fichero de medidas: $ruta_mediciones")

    m = lectura_mediciones(ruta_mediciones)

    # Entradas del protocolo y de la red: NINGUNA tiene valor por defecto inventado.
    R_s = num(entrada, "--rango-solucion", NaN)
    N_h = num(entrada, "--N-h", NaN)
    alpha = num(entrada, "--alpha", NaN)
    tau = num(entrada, "--tau-s", NaN)
    pi_DAG = num(entrada, "--pi-DAG", NaN)
    isnan(R_s) && error("falta --rango-solucion: no se inventa un parámetro de consenso")
    isnan(N_h) && error("falta --N-h")
    isnan(alpha) && error("falta --alpha")
    isnan(tau) && error("falta --tau-s")
    isnan(pi_DAG) && error("falta --pi-DAG")

    # Máquinas medidas. LINEO manda conservar la configuración que GANE de verdad, no la que usa
    # más hilos: el barrido agregado (M1) da 17,52 tablas/s generando tablas independientes en 24
    # hilos, frente a 8,47 tablas/s con `generate_parallel`. Se publican las dos.
    r_un_hilo = 1 / m.t_tabla_1_hilo_semilla_fresca_s
    # Tres formas medidas con el MISMO arnes. Se conserva la que gana (LINEO §7), no la que usa
    # mas hilos: la anidada (varias llamadas concurrentes a `generate_parallel` sobre una piscina
    # de 24) es la que usa el granjero real y la que mas rinde.
    r_single_24 = m.r_agregado_por_hilos[end]
    r_paralela_24 = 1 / m.t_tabla_paralela_s
    r_anidada = m.r_agregado_anidado
    hilos_anidado = m.hilos_barridos[argmax(r_anidada)]
    r_agregado_24 = maximum(r_anidada)
    hilos_paralelo = m.t_tabla_paralela_hilos

    base = (;
        t_reto_s = m.t_reto_por_bucket_s,
        o = m.o,
        rango_solucion = R_s,
        tau_s = tau,
        N_h = N_h,
        alpha = alpha,
        pi_DAG = pi_DAG,
        t_ganador_s = m.t_ganador_tabla_s + m.t_ganador_resto_s,
        bytes_por_pieza = 1_048_672,   # Piece::SIZE, leído del clon
    )

    maquinas_medidas = [
        ("1_nucleo", r_un_hilo),
        ("cpu_24h_anidado_$(hilos_anidado)_concurrentes_GANADORA", r_agregado_24),
        ("cpu_24h_tablas_independientes", r_single_24),
        ("cpu_24h_generate_parallel_secuencial", r_paralela_24),
    ]

    # `w` es símbolo: los valores fijos los da el encargo, no el instrumento.
    ws_fijos = if haskey(entrada, "--w-fijos")
        [parse(Float64, strip(p)) for p in split(entrada["--w-fijos"], ',')]
    else
        Float64[]
    end
    ws_rejilla = rejilla_w(
        num(entrada, "--w-min", 1.0e2),
        num(entrada, "--w-max", 1.0e5),
        Int(num(entrada, "--pasos", 64.0)),
    )

    directorio = normpath(joinpath(@__DIR__, "resultados"))
    mkpath(directorio)
    ruta_salida = get(entrada, "--salida", joinpath(directorio, "BARRIDO.tsv"))

    open(ruta_salida, "w") do io
        println(io, "# P-INTENTO · intento-v1 · barrido de N_eq(w)")
        println(io, "# fecha\t$(now())")
        println(io, "# julia\t$(VERSION)")
        println(io, "# modelo\tintento-v1")
        println(io, "# medidas\t$ruta_mediciones")
        println(io, "# fuente_medidas\t$(m.fuente)")
        println(io, "# t_tabla_1_hilo_s\t$(m.t_tabla_1_hilo_semilla_fresca_s)")
        println(io, "# t_tabla_paralela_s\t$(m.t_tabla_paralela_s)")
        println(io, "# r_agregado_por_hilos\t$(m.r_agregado_por_hilos)")
        println(io, "# r_agregado_paralelo\t$(m.r_agregado_paralelo)")
        println(io, "# r_agregado_anidado\t$(m.r_agregado_anidado)")
        println(io, "# hilos_anidado_ganador\t$(hilos_anidado)")
        println(io, "# hilos_paralelo\t$(hilos_paralelo)")
        println(io, "# t_reto_por_bucket_s\t$(m.t_reto_por_bucket_s)")
        println(io, "# t_reto_lote_s\t$(m.t_reto_lote_total_s)")
        println(io, "# o_medido\t$(m.o)")
        println(io, "# rango_solucion\t$(R_s)")
        println(io, "# N_h\t$(N_h)")
        println(io, "# alpha\t$(alpha)")
        println(io, "# tau_s\t$(tau)")
        println(io, "# pi_DAG\t$(pi_DAG)")
        println(io, "# bytes_por_pieza\t1048672")
        println(io, "# gpu\t$(haskey(entrada, "--gpu-r") ? entrada["--gpu-r"] : "no medida")")
        println(io, "maquina\tw\tp\tr_efectiva\tn_eq_piezas\tbytes_eq\tTiB_eq\tmaquinas\tn_eq_por_nucleo\tfraccion_una_maquina\tcoste_por_solucion_s\tlatencia_holgada\tw_min_latencia\tw_equilibrio")

        for (nombre, r) in maquinas_medidas
            esc = Escenario(; r = r, base...)
            for w in ws_fijos
                imprime(io, nombre, evaluar(esc, w), r_un_hilo, N_h)
            end
            for w in ws_rejilla
                imprime(io, nombre, evaluar(esc, w), r_un_hilo, N_h)
            end
        end

        # GPU opcional: solo si se midió. Si no, el fichero lo dice y el modelo no la menciona.
        if haskey(entrada, "--gpu-r")
            r_gpu = parse(Float64, entrada["--gpu-r"])
            esc_gpu = Escenario(; r = r_gpu, base...)
            for w in ws_fijos
                imprime(io, "gpu", evaluar(esc_gpu, w), r_un_hilo, N_h)
            end
            for w in ws_rejilla
                imprime(io, "gpu", evaluar(esc_gpu, w), r_un_hilo, N_h)
            end
        end
    end

    # Resumen por consola, sin conclusiones económicas.
    println("Modelo intento-v1 · barrido escrito en $ruta_salida")
    println("  medidas: $(m.fuente)")
    println("  t_tabla 1 hilo               = $(round(m.t_tabla_1_hilo_semilla_fresca_s * 1e3; digits=2)) ms")
    println("  t_tabla CPU $hilos_paralelo hilos (generate_parallel) = $(round(m.t_tabla_paralela_s * 1e3; digits=2)) ms")
    println("  agregado 24 hilos, tablas independientes  = $(round(r_single_24; digits=3)) tablas/s")
    println("  agregado 24 hilos, generate_parallel sec. = $(round(r_paralela_24; digits=3)) tablas/s")
    println("  agregado 24 hilos, anidado ($(hilos_anidado) conc.)  = $(round(r_agregado_24; digits=3)) tablas/s  (GANADORA)")
    println("  t_reto por bucket (w=10^4)   = $(round(m.t_reto_por_bucket_s * 1e6; digits=3)) us")
    println("  t_reto en lote (8 KiB AND)   = $(round(m.t_reto_lote_total_s * 1e9; digits=1)) ns")
    println("  o medido                     = $(m.o)")
    for (nombre, r) in maquinas_medidas
        esc = Escenario(; r = r, base...)
        f = evaluar(esc, 1.0e4)
        println("  [$nombre] r=$(round(r; digits=4)) tablas/s · N_eq(w=10^4)=$(round(f.n_eq; digits=2)) piezas" *
                " · $(round(f.bytes_eq / 2.0^40; digits=4)) TiB")
        println("            w_min_latencia=$(round(f.w_min_latencia; sigdigits=4))" *
                " · w_equilibrio=$(round(f.w_equilibrio; sigdigits=4))" *
                " · coste/solución=$(round(f.coste_por_solucion_s; sigdigits=4)) s")
    end
    return nothing
end

function imprime(io::IO, nombre::String, f::Resultado{Float64}, r_nucleo::Float64, N_h::Float64)
    # `N_eq` por núcleo es independiente de la máquina: r de UN núcleo por w por tau.
    n_eq_nucleo = n_eq(r_nucleo, f.w, 1.0)
    println(
        io,
        join((
            nombre,
            f.w,
            f.p,
            f.r_efectiva,
            f.n_eq,
            f.bytes_eq,
            f.bytes_eq / 2.0^40,
            f.maquinas,
            n_eq_nucleo,
            f.fraccion_una_maquina,
            f.coste_por_solucion_s,
            f.latencia_holgada,
            f.w_min_latencia,
            f.w_equilibrio,
        ), '\t'),
    )
end

main(ARGS)
