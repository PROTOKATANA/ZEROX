# run.jl — CLI reproducible de permanencia-v1. Nada de notebook implícito.
#
# Todas las cifras salen de funciones de `src/`. Los símbolos de red y de protocolo
# (N, w, D_a, c, qP, a, s, σ, β, γ, F…) son ENTRADAS: el instrumento no fija ninguno.
# Las cifras de hardware se leen de `mediciones/hardware.tsv` y el instrumento falla si
# falta una clave.

using Dates
using Printf
using PermanenciaV1

const OBLIGATORIOS = ("--hardware", "--w", "--D-a", "--c", "--qP", "--periodo", "--a",
    "--beta", "--gamma", "--s", "--N-h", "--lambda-red", "--sigma")

function uso(io::IO = stderr)
    println(io, "Uso reproducible:")
    println(io, "  run.jl --hardware mediciones/hardware.tsv --w 7175 --D-a 60 --c 1000 \\")
    println(io, "         --qP 1e-4 --periodo 100 --a 0.99 --beta 1e-3 --gamma 1e-3 --s 0.5 \\")
    println(io, "         --N-h 1e9 --lambda-red 1.0 --sigma 0.01 \\")
    println(io, "         [--F-slots 7200] [--t-read-hdd 0.010] [--t-read-ssd 0.0001] \\")
    println(io, "         [--gpu-factor 17] [--b-apertura 112] [--b-compromiso 32] [--k-aperturas 10] \\")
    println(io, "         [--salida-dir resultados]")
    println(io)
    println(io, "`N` se expresa en TiB en las tablas; `qP` es la media de parciales por pieza y")
    println(io, "periodo (símbolo). El instrumento no publica ninguna cifra monetaria.")
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
    conocidos = Set((OBLIGATORIOS..., "--F-slots", "--t-read-hdd", "--t-read-ssd", "--gpu-factor",
        "--b-apertura", "--b-compromiso", "--b-parcial", "--k-aperturas", "--salida-dir"))
    desconocidos = setdiff(Set(keys(valores)), conocidos)
    isempty(desconocidos) || error("argumentos desconocidos: $(join(sort!(collect(desconocidos)), ", "))")
    for campo in OBLIGATORIOS
        haskey(valores, campo) || error("falta el argumento obligatorio $campo")
    end
    return valores
end

num(v, clave, por_defecto) = haskey(v, clave) ? parse(Float64, v[clave]) : por_defecto

esc(v, x) = @sprintf("%.10g", x)
esc3(v, x) = @sprintf("%.4g", x)

function main(args::Vector{String})
    e = parsear(args)
    hw = lectura_hardware(e["--hardware"])

    w = parse(Float64, e["--w"])
    D_a = parse(Float64, e["--D-a"])
    c = parse(Float64, e["--c"])
    qP = parse(Float64, e["--qP"])
    P = parse(Float64, e["--periodo"])
    a = parse(Float64, e["--a"])
    beta = parse(Float64, e["--beta"])
    gamma = parse(Float64, e["--gamma"])
    s = parse(Float64, e["--s"])
    N_h = parse(Float64, e["--N-h"])
    lambda_red = parse(Float64, e["--lambda-red"])
    sigma = parse(Float64, e["--sigma"])
    F_slots = num(e, "--F-slots", hw.w_sin_vdf_slots)
    t_hdd = num(e, "--t-read-hdd", 0.010)
    t_ssd = num(e, "--t-read-ssd", 0.0001)
    gpu = num(e, "--gpu-factor", 17.0)
    b_ap = num(e, "--b-apertura", 112.0)
    b_cp = num(e, "--b-compromiso", 32.0)
    b_parcial = num(e, "--b-parcial", 200.0)
    k_ap = num(e, "--k-aperturas", 10.0)
    dir = get(e, "--salida-dir", normpath(joinpath(@__DIR__, "resultados")))
    mkpath(dir)

    abrir(nombre) = open(joinpath(dir, nombre), "w")
    cabecera(io, titulo) = begin
        println(io, "# permanencia-v1 · ", titulo)
        println(io, "# fecha\t", now())
        println(io, "# julia\t", VERSION)
        println(io, "# hardware\t", e["--hardware"])
        println(io, "# fuente_hardware\t", hw.fuente)
        println(io, "# w_slots\t", w, "\tD_a_s\t", D_a, "\tc\t", c, "\tqP\t", qP,
            "\tperiodo\t", P, "\ta\t", a, "\tbeta\t", beta, "\tgamma\t", gamma,
            "\ts\t", s, "\tN_h\t", N_h, "\tlambda_red\t", lambda_red, "\tsigma\t", sigma,
            "\tF_slots\t", F_slots, "\tgpu_factor\t", gpu)
    end

    # ------------------------------------------------------------------
    # 0 · Validación
    # ------------------------------------------------------------------
    vi = validar_intervalo_vs_exacto()
    vb = validar_poisson_vs_binomial()
    vk = validar_kernel_vs_referencia()
    bordes = comprobar_bordes()
    mon = validar_monotonia_potencia(20.0, 0.5, 1e-3)
    open(joinpath(dir, "VALIDACION.txt"), "w") do io
        println(io, "# permanencia-v1 · validación · ", now(), " · julia ", VERSION)
        println(io, "intervalo_vs_exacto  max_abs=", vi.max_abs, "  max_rel=", vi.max_rel,
            "  contiene=", vi.contiene)
        println(io, "poisson_vs_binomial  max_dif=", vb.max_dif, "  cota_lecam=", vb.cota_max,
            "  dentro=", vb.dentro)
        println(io, "kernel_vs_referencia max_dK=", vk.max_dK, "  max_dP=", vk.max_dP)
        println(io, "potencia_monotona_en_T=", mon)
        println(io, "bordes=", isempty(bordes) ? "OK" : join(bordes, "; "))
    end
    isempty(bordes) || error("bordes fallidos: $(join(bordes, "; "))")
    vi.contiene || error("el intervalo de Poisson no contiene el oráculo exacto")
    vb.dentro || error("la Poisson se sale de la cota de Le Cam frente a la binomial exacta")

    # ------------------------------------------------------------------
    # 1 · E3 · coste de la trampa con ventana (por TiB y por lote)
    # ------------------------------------------------------------------
    N1 = piezas_por_TiB(hw)              # piezas en 1 TiB
    ws = sort(unique(vcat([1.0, 10.0, 100.0, 1000.0, hw.w_con_vdf_rho25_slots, hw.w_sin_vdf_slots,
            10_000.0, 100_000.0, 1_000_000.0], rejilla_log(1.0, 1e6, 40))))
    open(joinpath(dir, "E3-ventana.tsv"), "w") do io
        cabecera(io, "E3 · fabricación por ventana w (CPU medida y escenario GPU)")
        println(io, join(("w_slots", "r_tablas_s", "escenario", "piezas_fabricables",
            "TiB_por_cpu", "cpu_por_TiB", "forzado_1TiB", "forzado_10TiB", "forzado_100TiB",
            "cpu_20TB", "cpu_PiB", "t_regenerar_1TiB_h"), '\t'))
        for (nombre, r) in (("cpu_16_nucleos_medida", hw.r_cpu_tablas_s),
                            ("un_nucleo", 1 / hw.t_tabla_s),
                            ("gpu_17x_documentacion_NO_MEDIDA", hw.r_cpu_tablas_s * gpu))
            hw2 = Hardware(hw.t_tabla_s, hw.t_tabla_paralela_s, r, hw.t_reto_s, hw.t_reto_lote_s,
                hw.t_ganador_s, hw.m_tabla_B, hw.bytes_pieza_B, hw.bytes_mapa_presencia_B,
                hw.num_pruebas_por_pieza, hw.num_s_buckets, hw.o_medido,
                hw.ploteo_sector_1000_piezas_s, hw.w_sin_vdf_slots, hw.w_con_vdf_rho25_slots, hw.fuente)
            for ww in ws
                fab = e3_piezas_fabricables(hw2, ww)
                t_reg = N1 / r / 3600
                println(io, join((esc(io, ww), esc(io, r), nombre, esc(io, fab),
                    esc(io, e3_TiB_por_cpu(hw2, ww)), esc(io, e3_cpu_por_TiB(hw2, ww)),
                    esc(io, e3_almacenamiento_forzado(hw2, N1, ww)),
                    esc(io, e3_almacenamiento_forzado(hw2, 10N1, ww)),
                    esc(io, e3_almacenamiento_forzado(hw2, 100N1, ww)),
                    esc(io, (20.0 * N1) / fab),
                    esc(io, (2.0^50 / hw2.bytes_pieza_B) / fab),
                    esc(io, t_reg)), '\t'))
            end
        end
    end

    # ------------------------------------------------------------------
    # 2 · E2 · aperturas con plazo
    # ------------------------------------------------------------------
    open(joinpath(dir, "E2-plazo.tsv"), "w") do io
        cabecera(io, "E2 · aperturas aleatorias con plazo D_a")
        println(io, join(("c", "D_a_s", "s_guardada", "cpu_sin_ventana",
            "factible_sin_ventana", "cpu_con_ventana_w", "factible_con_ventana_w",
            "max_aperturas_HDD", "max_aperturas_SSD", "bytes_todas", "bytes_muestreo_k",
            "k_aperturas"), '\t'))
        for cc in (10.0, 100.0, 1000.0, 10_000.0, 100_000.0), Da in (1.0, 10.0, 60.0, 600.0),
                ss in (0.0, 0.5, 0.9)
            println(io, join((esc(io, cc), esc(io, Da), esc(io, ss),
                esc(io, e2_cpu_sin_ventana(hw, cc, Da, ss)),
                e2_factible_sin_ventana(hw, cc, Da, ss) ? "si" : "no",
                esc(io, e2_cpu_con_ventana(hw, cc, w, ss)),
                e2_factible_con_ventana(hw, cc, w, ss) ? "si" : "no",
                esc(io, e2_aperturas_honestas(Da, t_hdd)),
                esc(io, e2_aperturas_honestas(Da, t_ssd)),
                esc(io, e2_bytes_todas(cc, b_ap)),
                esc(io, e2_bytes_muestreo(cc, k_ap, b_cp, b_ap)),
                esc(io, k_ap)), '\t'))
        end
    end

    # ------------------------------------------------------------------
    # 3 · E3 · estadística (Poisson exacta) y falso fallo
    # ------------------------------------------------------------------
    open(joinpath(dir, "E3-estadistica.tsv"), "w") do io
        cabecera(io, "E3 · detección estadística del tamaño (Poisson rigurosa)")
        println(io, join(("TiB", "N_piezas", "s_guardada", "lambda_periodo", "K_T",
            "T_periodos", "potencia_garantizada", "falso_fallo_a", "a",
            "error_rel_estimador", "w_min_para_no_detectar_T1"), '\t'))
        for tib in (1.0, 10.0, 100.0)
            N = tib * N1
            λ = N * qP
            for ss in (0.1, 0.25, 0.5, 0.75, 0.9)
                sn = BigInt(round(Int, ss * 1_000_000))
                sd = BigInt(1_000_000)
                λn = BigInt(round(Int, λ * 1_000_000))
                λd = BigInt(1_000_000)
                T, K, pot = periodos_deteccion(λn, λd, sn, sd, beta, gamma; Tmax = 50_000)
                # falso fallo de un honesto con disponibilidad a, con el K del T de detección
                an = BigInt(round(Int, a * 1_000_000))
                ff = K < 0 ? BigFloat(1) : falso_fallo_maximo(λn * BigInt(T) * an, λd * 1_000_000, K)
                err = 1 / sqrt(λ * T)
                # w_min: para que el tramposo pueda fabricar el lote por ventana
                println(io, join((esc(io, tib), esc(io, N), esc(io, ss), esc(io, λ), K,
                    T, esc(io, pot), esc(io, ff), esc(io, a), esc(io, err),
                    esc(io, e3_w_cruce_lote(hw, N))), '\t'))
            end
        end
    end

    # ------------------------------------------------------------------
    # 4 · E3 · agregación en cadena (comprometer y abrir k)
    # ------------------------------------------------------------------
    open(joinpath(dir, "E3-agregacion.tsv"), "w") do io
        cabecera(io, "E3 · muestreo/agregación en cadena: coste del tramposo")
        println(io, join(("lambda_periodo", "N_1TiB", "k_aperturas", "m_sobre_lambda",
            "p_pasar", "intentos_grinding", "mezcla_necesaria", "piezas_escaneadas_1TiB",
            "cpu_agregacion_con_ventana", "bytes_cadena_periodo", "bytes_por_slot"), '\t'))
        for kk in (1.0, 5.0, 10.0, 50.0), frac in (0.01, 0.1, 0.5, 1.0)
            λ = N1 * qP
            mm = frac * λ
            mez = e3_mezcla_necesaria(kk, gamma)
            println(io, join((esc(io, λ), esc(io, N1), esc(io, kk), esc(io, frac),
                esc(io, e3_pasa_muestreo(λ, mm, kk)), esc(io, e3_grinding(λ, mm, kk)),
                esc(io, mez), esc(io, e3_piezas_escaneadas(N1, kk, gamma)),
                esc(io, e3_cpu_agregacion_con_ventana(hw, kk, P, w)),
                esc(io, e3_bytes_cadena(λ, b_parcial)),
                esc(io, e3_bytes_cadena(λ, b_parcial) / P)), '\t'))
        end
    end

    # ------------------------------------------------------------------
    # 5 · E5 · farmear y nada más
    # ------------------------------------------------------------------
    open(joinpath(dir, "E5-deteccion.tsv"), "w") do io
        cabecera(io, "E5 · detección por ausencia de victorias")
        println(io, join(("sigma", "lambda_granjero", "T_deteccion_slots", "T_deteccion_h",
            "retencion_periodos", "P_cero_en_T"), '\t'))
        for sg in (1e-5, 1e-4, 1e-3, 1e-2, 1e-1)
            T = e5_deteccion_slots(sg, lambda_red, beta)
            println(io, join((esc(io, sg), esc(io, e5_lambda_granjero(sg, lambda_red)),
                esc(io, T), esc(io, T / 3600), esc(io, retencion_periodos(F_slots, P, T / P)),
                esc(io, e5_p_cero(sg, lambda_red, T))), '\t'))
        end
    end

    # ------------------------------------------------------------------
    # 6 · E1/E4 · trabajo de compromiso y de sellado por TiB
    # ------------------------------------------------------------------
    open(joinpath(dir, "E1-E4-coste.tsv"), "w") do io
        cabecera(io, "E1/E4 · trabajo de regeneración y de sellado por lote")
        println(io, join(("TiB", "N_piezas", "nucleo_s_regenerar", "cpu_hora_regenerar",
            "w_cruce_lote_slots", "w_cruce_20TB_slots", "w_cruce_PiB_slots",
            "sellado_minimo_slots_igual_ventana"), '\t'))
        for tib in (0.001, 0.1, 1.0, 10.0, 100.0, 1000.0)
            N = tib * N1
            println(io, join((esc(io, tib), esc(io, N), esc(io, e4_trabajo_nucleo_s(hw, N)),
                esc(io, e4_trabajo_nucleo_s(hw, N) / 3600),
                esc(io, e3_w_cruce_lote(hw, N)),
                esc(io, e3_w_cruce_disco(hw, 20.0)),
                esc(io, e3_w_cruce_disco(hw, 1125.899906842624)),
                esc(io, w)), '\t'))
        end
    end

    # ------------------------------------------------------------------
    # 7 · Resumen por consola
    # ------------------------------------------------------------------
    println("permanencia-v1 · resultados en $dir")
    println("  w = ", w, " slots · D_a = ", D_a, " s · c = ", c, " · qP = ", qP,
        " · P = ", P, " · a = ", a, " · beta = ", beta, " · gamma = ", gamma, " · s = ", s)
    println("  validación: intervalo_vs_exacto contiene=", vi.contiene,
        " · poisson_vs_binomial dentro_lecam=", vb.dentro,
        " · max_dK=", vk.max_dK, " · bordes=", isempty(bordes) ? "OK" : "FALLO")
    println()
    println("  E3 · fabricación con la CPU medida (", hw.r_cpu_tablas_s, " tablas/s):")
    for ww in (1.0, 100.0, 1000.0, hw.w_con_vdf_rho25_slots, hw.w_sin_vdf_slots, 1e5, 1e6)
        println("    w=", lpad(esc3(nothing, ww), 10), "  TiB_por_cpu=",
            lpad(esc3(nothing, e3_TiB_por_cpu(hw, ww)), 10), "  cpu_por_TiB=",
            lpad(esc3(nothing, e3_cpu_por_TiB(hw, ww)), 10), "  forzado_1TiB=",
            lpad(esc3(nothing, e3_almacenamiento_forzado(hw, N1, ww)), 8))
    end
    println()
    println("  cruces: w para fabricar 1 TiB = ", round(e3_w_cruce_lote(hw, N1); digits=0),
        " slots;  w para igualar 20 TB = ", round(e3_w_cruce_disco(hw, 20.0); digits=0),
        " slots;  w para igualar 1 PiB = ", round(e3_w_cruce_disco(hw, 1125.9); digits=0), " slots")
    println()
    println("  E2 · c=", c, " D_a=", D_a, ": cpu_sin_ventana=",
        round(e2_cpu_sin_ventana(hw, c, D_a, 0.0); digits=3),
        " · cpu_con_ventana(w)=", round(e2_cpu_con_ventana(hw, c, w, 0.0); sigdigits=4),
        " · max aperturas HDD en D_a=", round(e2_aperturas_honestas(D_a, t_hdd); sigdigits=4))
    return nothing
end

main(ARGS)
