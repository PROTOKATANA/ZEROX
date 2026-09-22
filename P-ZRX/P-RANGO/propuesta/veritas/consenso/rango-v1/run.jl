# run.jl — CLI reproducible de RNG-v0.1 (LINEO §1). Nada de notebook.
#
#   ./veritas/julia.sh --project=P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1 \
#       P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1/run.jl --seed 0x52414E474F
#
# Los parámetros del controlador que aparecen aquí son VALORES DE ENSAYO para poder comprobar el
# kernel. No son parámetros de consenso: la propuesta P-RANGO no fija ninguno.

include(joinpath(@__DIR__, "src", "RangoV1.jl"))
using .RangoV1
using StableRNGs

const DIR_RES = joinpath(@__DIR__, "resultados")

"""Configuración de ensayo (símbolos con valores SOLO para probar el kernel)."""
function config_ensayo()
    ConfigControlador(w_slots=20, g_slots=20, q=10,
                      ganancia_num=1, ganancia_den=2,
                      paso_lo_num=1, paso_lo_den=2,
                      paso_hi_num=2, paso_hi_den=1,
                      sr_min=2048, sr_max=UInt64(2)^32,
                      r_inicial=UInt64(2)^20, retardos_ventana=2)
end

"""Configuración que SÍ rompe la precondición de 128 bits (para demostrar que se rechaza)."""
function config_fuera_de_u128()
    ConfigControlador(w_slots=20, g_slots=20, q=10,
                      ganancia_num=1, ganancia_den=2,
                      paso_lo_num=1, paso_lo_den=2,
                      paso_hi_num=2, paso_hi_den=1,
                      sr_min=2048, sr_max=typemax(UInt64) - 1,
                      r_inicial=UInt64(2)^20, retardos_ventana=2)
end

function muestra_aleatoria(rng, c, n)
    casos = Tuple{BigInt,BigInt}[]
    for _ in 1:n
        r = c.sr_min + 2 * rand(rng, UInt64(0):((c.sr_max - c.sr_min) ÷ 2))
        m = rand(rng, UInt64(0):UInt64(1_000_000))
        push!(casos, (BigInt(r), BigInt(m)))
    end
    return casos
end

function entorno(seed)
    cpu = try
        Sys.CPU_NAME
    catch
        "desconocido"
    end
    git = try
        strip(read(`git -C /home/katana/zeo/ZEROX rev-parse HEAD`, String))
    catch
        "no disponible"
    end
    return """
    instrumento=rango-v1 (RNG-v0.1)
    fecha_unix=$(round(Int, time()))
    git_head=$git
    julia_version=$VERSION
    cpu_name=$cpu
    cpu_threads_visibles=$(Sys.CPU_THREADS)
    word_size=$(Sys.WORD_SIZE)
    julia_threads_default=$(Threads.nthreads(:default))
    julia_threads_interactive=$(Threads.nthreads(:interactive))
    semilla=$seed
    presupuesto=maximo 4 hilos; 4 GiB RAM; 1 GiB disco temporal; 30 min de pared
    """
end

function main(args)
    seed = UInt64(0x52414E474F)
    i = 1
    while i <= length(args)
        if args[i] == "--seed"
            i < length(args) || error("--seed sin valor")
            seed = parse(UInt64, args[i + 1])
            i += 2
        else
            seed = parse(UInt64, args[i])
            i += 1
        end
    end
    rng = StableRNG(seed)
    c = config_ensayo()
    c_grande = config_fuera_de_u128()
    srs = srs_de_regresion()
    aleatorios = muestra_aleatoria(rng, c, 2000)

    comprobaciones = Comprobacion[
        validar_A_circulo(256),
        validar_A_circulo(1024),
        validar_razon_cerrada(srs),
        validar_paridad(srs),
        validar_dominio(srs),
        validar_controlador(c, srs, aleatorios),
        validar_ancho(c),
        validar_ancho(c_grande),
        validar_activacion(c),
        validar_z0(c),
        validar_deriva(c, srs),
    ]

    salida = IOBuffer()
    println(salida, "modelo=rango-v1 (RNG-v0.1) seed=$seed")
    println(salida, "config_ensayo=$c")
    println(salida, "gamma=$(gamma(c))")
    println(salida, "cabe_en_u256=$(cabe_en_u256(c)) precondicion_u128=$(precondicion_u128(c))")
    println(salida, "precondicion_u128(config_fuera_de_u128)=$(precondicion_u128(c_grande))")
    println(salida, "")
    println(salida, "COMPROBACIONES")
    for k in comprobaciones
        println(salida, (k.ok ? "OK   " : "FALLA"), " | ", k.nombre, " | ", k.detalle)
    end

    # Tabla de paridad: la cifra que justifica la rejilla par.
    println(salida, "")
    println(salida, "PARIDAD (exacto, Rational{BigInt})")
    println(salida, "sr | paridad | razon | deficit")
    for sr in BigInt[2047, 2048, 2049, big(2)^11 + 1, big(2)^20, big(2)^20 + 1,
                    big(2)^32, big(2)^32 + 1, big(2)^63, big(2)^63 + 1,
                    big(2)^64 - 2, big(2)^64 - 1]
        println(salida, sr, " | ", iseven(sr) ? "par" : "impar", " | ", razon_ref(sr), " | ",
                deficit(sr))
    end

    texto = String(take!(salida))
    print(texto)
    mkpath(DIR_RES)
    write(joinpath(DIR_RES, "RUN.txt"), texto)
    write(joinpath(DIR_RES, "ENTORNO.txt"), entorno(seed))

    if !all(k -> k.ok, comprobaciones)
        error("hay comprobaciones que fallan")
    end
    println("RUN_OK")
end

main(ARGS)
