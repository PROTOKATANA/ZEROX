# run.jl — CLI reproducible de cobertura-parcela-v1. Nada de notebook implícito.
#
# TODOS los símbolos del encargo son ENTRADAS y quedan en la línea de comandos:
#   N, k, w, D_a, R (r_maquina), maquinas, φ, γ, β. Ninguno es un parámetro de
#   consenso fijado por el instrumento.
#
# Las cifras de hardware/formato se leen de `mediciones/hardware.tsv` (entradas
# congeladas de P-COBERTURA §1.3) y el instrumento falla si falta una clave.

using Dates
using Printf
using CoberturaParcela
const CP = CoberturaParcela

const OBLIGATORIOS = ("--hardware",)
const OPCIONALES = ("--w", "--D-a", "--k", "--maquinas", "--gamma", "--beta",
                    "--replicas", "--salida-dir")
# w medidos (P-REVELACION) y tope histórico (P-ADELANTO), en slots
const W_ESCENARIOS = (("sin_vdf", 7175.0), ("con_vdf_rho2.5", 4830.6),
                      ("tope_hist", 8030.0), ("w_1", 1.0))

function uso(io::IO = stderr)
    println(io, "Uso reproducible:")
    println(io, "  run.jl --hardware mediciones/hardware.tsv \\")
    println(io, "         [--w 7175] [--D-a 60] [--k 1000] [--maquinas 1] \\")
    println(io, "         [--gamma 1e-2] [--beta 1e-3] [--replicas 20000] \\")
    println(io, "         [--salida-dir resultados]")
end

function leer_hardware(ruta::AbstractString)
    d = Dict{String,Tuple{Float64,String}}()
    isfile(ruta) || error("no existe el fichero de hardware: $ruta")
    for l in eachline(ruta)
        (startswith(l, "#") || isempty(strip(l))) && continue
        c = split(l, '\t')
        length(c) >= 4 || continue
        d[String(c[1])] = (parse(Float64, c[2]), String(c[4]))
    end
    return d
end

function exigir(d, clave)
    haskey(d, clave) || error("falta la clave '$clave' en el fichero de hardware")
    return d[clave][1]
end

"""Mínimo `M` (unidades omitidas) con `P(X>B) ≥ γ`. La cola es no decreciente en `M`."""
function M_para_gamma(t::TablaLogFact, N::Int, k::Int, B::Int, gamma::Float64)
    cola_hiper_rapida(t, N, 0, k, B) >= gamma && return 0
    cola_hiper_rapida(t, N, N, k, B) < gamma && return N
    lo, hi = 0, N
    while hi - lo > 1
        med = (lo + hi) >>> 1
        if cola_hiper_rapida(t, N, med, k, B) >= gamma
            hi = med
        else
            lo = med
        end
    end
    return hi
end

"""T auditorías para detección acumulada ≥ 1−β con probabilidad por auditoría `p`."""
T_acumulada(p::Float64, beta::Float64) = (p <= 0) ? typemax(Int) :
    (p >= 1) ? 1 : ceil(Int, log(beta) / log1p(-p))

function main(args)
    for a in OBLIGATORIOS
        (a in args) || (uso(); error("falta $a"))
    end
    hw = leer_hardware(args[findfirst(==("--hardware"), args)+1])

    t_unidad = exigir(hw, "t_tabla_s")
    r_maquina = exigir(hw, "r_maquina_s")
    bytes_pieza = exigir(hw, "bytes_pieza_B")
    tau = exigir(hw, "tau_s")
    gpu = exigir(hw, "gpu_factor")
    precio_ratio = exigir(hw, "precio_nucleo_sobre_TiB")

    leer(clave, def) = begin
        i = findfirst(==(clave), args)
        i === nothing ? def : (clave == "--salida-dir" ? args[i+1] : parse(Float64, args[i+1]))
    end

    w_cmd = leer("--w", 7175.0)
    D_a = leer("--D-a", 60.0)
    k_cmd = Int(leer("--k", 1000.0))
    maquinas = leer("--maquinas", 1.0)
    gamma = leer("--gamma", 1e-2)
    beta = leer("--beta", 1e-3)
    replicas = Int(leer("--replicas", 20000.0))
    dir = leer("--salida-dir", "resultados")
    mkpath(dir)

    N1 = piezas_por_TiB(bytes_pieza)          # unidades por TiB
    e = Entrada(N = round(Int, N1), k = k_cmd, w_slots = w_cmd, D_a_s = D_a,
                t_unidad_s = t_unidad, r_maquina_s = r_maquina,
                maquinas = maquinas, tau_s = tau)
    t = TablaLogFact(e.N)

    cabecera(io, titulo) = begin
        println(io, "# cobertura-parcela-v1 · ", titulo)
        println(io, "# fecha\t", Dates.now())
        println(io, "# julia\t", VERSION, "\thilos\t", Threads.nthreads(:default))
        println(io, "# cpu\t", Sys.CPU_NAME, "\tuptime\t", strip(read(`uptime`, String)))
        println(io, "# hardware\t", args[findfirst(==("--hardware"), args)+1])
        println(io, "# t_unidad_s\t", t_unidad, "\tr_maquina_s\t", r_maquina,
                "\tbytes_pieza_B\t", bytes_pieza, "\ttau_s\t", tau)
        println(io, "# w_slots\t", w_cmd, "\tD_a_s\t", D_a, "\tk\t", k_cmd,
                "\tmaquinas\t", maquinas, "\tgamma\t", gamma, "\tbeta\t", beta)
    end

    # ── 1 · Frontera φ*(N,B) y detección practicable por γ ───────────────────
    open(joinpath(dir, "F4-frontera.tsv"), "w") do io
        cabecera(io, "F4 · frontera exacta y detección practicable")
        println(io, join(("escenario", "w_slots", "D_a_s", "k", "maquinas",
                          "B_unidades", "deteccion_posible", "almacenamiento_forzado",
                          "ahorro_maximo", "M_gamma", "phi_gamma", "p_por_auditoria_en_phi_gamma",
                          "T_auditorias_beta"), '\t'))
        for (nombre, w) in W_ESCENARIOS
            for kk in unique((k_cmd, 10^5, 10^6, e.N))
                ee = Entrada(N = e.N, k = kk, w_slots = w, D_a_s = D_a,
                             t_unidad_s = t_unidad, r_maquina_s = r_maquina,
                             maquinas = maquinas, tau_s = tau)
                B = B_entero(ee)
                pos = deteccion_posible(kk, B)
                af = almacenamiento_forzado(e.N, B)
                ah = ahorro_maximo(e.N, B)
                if pos
                    Mg = M_para_gamma(t, e.N, kk, B, gamma)
                    pg = cola_hiper_rapida(t, e.N, Mg, kk, B)
                    phig = 1.0 - Mg / e.N
                    Ta = T_acumulada(pg, beta)
                else
                    Mg = e.N; pg = 0.0; phig = 0.0; Ta = typemax(Int)
                end
                println(io, join((nombre, @sprintf("%.4f", w), @sprintf("%.1f", D_a),
                                  kk, @sprintf("%.1f", maquinas), B, pos,
                                  @sprintf("%.10f", af), @sprintf("%.10f", ah), Mg,
                                  @sprintf("%.10f", phig), @sprintf("%.3e", pg), Ta), '\t'))
            end
        end
    end

    # ── 2 · Reconciliación 235,6 h·núcleo/TiB ↔ 5,84 «CPU»/TiB ───────────────
    open(joinpath(dir, "F4-reconciliacion.tsv"), "w") do io
        cabecera(io, "F4 · reconciliación de las dos cifras de coste publicadas")
        println(io, join(("magnitud", "valor", "unidad", "definicion"), '\t'))
        trabajo_s = trabajo_nucleo_s_por_TiB(e, bytes_pieza)
        println(io, join(("trabajo_nucleo_s_por_TiB", @sprintf("%.6f", trabajo_s),
                          "s·nucleo/TiB", "N_TiB · t_unidad"), '\t'))
        println(io, join(("trabajo_nucleo_h_por_TiB", @sprintf("%.7f", trabajo_s / 3600),
                          "h·nucleo/TiB", "trabajo total, una pasada"), '\t'))
        println(io, join(("maquinas_por_TiB_w_only", @sprintf("%.9f", piezas_por_TiB(bytes_pieza) / (r_maquina * w_cmd * tau)),
                          "maquinas/TiB", "N/(r·w): regenerar 1 vez por ventana"), '\t'))
        println(io, join(("maquinas_por_TiB_ventana_completa", @sprintf("%.9f", maquinas_por_TiB(e, bytes_pieza)),
                          "maquinas/TiB", "N/(r·(w+D_a))"), '\t'))
        println(io, join(("nucleos_por_TiB", @sprintf("%.9f", nucleos_por_TiB(e, bytes_pieza)),
                          "nucleos/TiB", "N·t/(w+D_a)"), '\t'))
        println(io, join(("nucleos_equivalentes_por_maquina", @sprintf("%.9f", nucleos_equivalentes_por_maquina(e)),
                          "nucleos/maquina", "r·t: FACTOR EXACTO de la reconciliación"), '\t'))
        println(io, join(("factor_ingenuo_235.6/5.84", @sprintf("%.9f", (trabajo_s / 3600) / (piezas_por_TiB(bytes_pieza) / (r_maquina * w_cmd * tau))),
                          "adimensional", "cociente con unidades mezcladas"), '\t'))
        println(io, join(("eficiencia_paralela", @sprintf("%.6f", r_maquina / (24 * (1 / t_unidad))),
                          "adimensional", "r / (24 · 1/t): 24 hilos del banco"), '\t'))
        println(io, join(("E3_medido_sobre_E1_ideal", @sprintf("%.6f", (piezas_por_TiB(bytes_pieza) / r_maquina * 24 / 3600) / (trabajo_s / 3600)),
                          "adimensional", "24 / (r·t)"), '\t'))
        println(io, join(("tiempo_pared_1_maquina_por_TiB", @sprintf("%.6f", (piezas_por_TiB(bytes_pieza) / r_maquina) / 3600),
                          "h", "independiente de w"), '\t'))
    end

    # ── 3 · Coste absoluto del tramposo por TiB ──────────────────────────────
    open(joinpath(dir, "F4-coste.tsv"), "w") do io
        cabecera(io, "F4 · coste absoluto del tramposo por TiB")
        println(io, join(("modo", "magnitud", "valor", "unidad", "etiqueta"), '\t'))
        println(io, join(("farmear_regenera_lote", "nucleos_por_TiB",
                          @sprintf("%.6f", nucleos_por_TiB(e, bytes_pieza)), "nucleos/TiB", "derivado"), '\t'))
        println(io, join(("farmear_regenera_lote", "maquinas_por_TiB",
                          @sprintf("%.6f", maquinas_por_TiB(e, bytes_pieza)), "maquinas/TiB", "derivado"), '\t'))
        println(io, join(("farmear_regenera_lote", "gpu_por_TiB_hipotesis17x",
                          @sprintf("%.6f", nucleos_por_TiB(e, bytes_pieza) / gpu), "GPU/TiB", "hipotesis NO medida"), '\t'))
        println(io, join(("farmear_regenera_lote", "energia_kWh_por_TiB_ventana",
                          @sprintf("%.6f", energia_kWh_por_TiB(e)), "kWh/TiB/ventana", "hipotesis 65 W/nucleo"), '\t'))
        println(io, join(("almacenar", "energia_kWh_por_TiB_ventana",
                          @sprintf("%.6f", energia_kWh_almacenar(e)), "kWh/TiB/ventana", "hipotesis 5 W/TiB"), '\t'))
        println(io, join(("almacenar", "ratio_energia_regenerar_sobre_almacenar",
                          @sprintf("%.2f", energia_kWh_por_TiB(e) / energia_kWh_almacenar(e)), "adimensional", "derivado"), '\t'))
        println(io, join(("solo_auditorias", "nucleo_s_por_auditoria",
                          @sprintf("%.6f", k_cmd * t_unidad), "s·nucleo/auditoria",
                          "k·t_unidad; INDEPENDIENTE de N y de TiB ahorrado"), '\t'))
        for ratio in (0.1, 0.5, 1.0, 2.0)
            println(io, join(("cruce_disco", "w_cruce_ratio_$(ratio)",
                              @sprintf("%.1f", w_cruce_disco_slots(e; razon_precio = ratio, factor_gpu = 1.0, bytes_pieza = bytes_pieza)),
                              "slots", "derivado + hipotesis de precio"), '\t'))
            println(io, join(("cruce_disco", "w_cruce_ratio_$(ratio)_gpu17x",
                              @sprintf("%.1f", w_cruce_disco_slots(e; razon_precio = ratio, factor_gpu = gpu, bytes_pieza = bytes_pieza)),
                              "slots", "hipotesis 17x NO medida"), '\t'))
        end
    end

    # ── 4 · Detección: exacta (N pequeño), encierro, rápido y Monte Carlo ────
    semilla = UInt64(0x5A5A)
    open(joinpath(dir, "F3-exacto-racional.tsv"), "w") do io
        cabecera(io, "F3 · colas exactas en Rational{BigInt} (evidencia sin redondear)")
        println(io, join(("N", "k", "B", "phi", "M", "p_exacta_racional"), '\t'))
        for phi in (0.0, 0.5, 0.9, 0.99, 0.997, 0.9975, 0.999, 0.9999)
            M = max(0, min(2000, round(Int, (1 - phi) * 2000)))
            println(io, join((2000, 100, 5, @sprintf("%.6f", phi), M,
                              string(cola_hiper_exacta(2000, M, 100, 5))), '\t'))
        end
    end

    open(joinpath(dir, "F3-deteccion.tsv"), "w") do io
        cabecera(io, "F3 · detección por auditoría: exacta, encierro, kernel y MC")
        println(io, join(("bloque", "N", "k", "B", "phi", "M", "p_exacta",
                          "p_intervalo_lo", "p_intervalo_hi", "p_float",
                          "p_mc", "mc_lo", "mc_hi", "mc_replicas"), '\t'))

        # bloque exacto pequeño (Rational{BigInt} factible)
        Np, kp, Bp = 2000, 100, 5
        tp = TablaLogFact(Np)
        for phi in (0.0, 0.5, 0.9, 0.99, 0.997, 0.9975, 0.999, 0.9999)
            M = max(0, min(Np, round(Int, (1 - phi) * Np)))
            ex = cola_hiper_exacta(Np, M, kp, Bp)
            lo, hi = cola_hiper_intervalo(Np, M, kp, Bp; bits = 256)
            fl = cola_hiper_rapida(tp, Np, M, kp, Bp)
            pm, exs, rep = p_deteccion_mc(semilla, Np, M, kp, Bp, replicas)
            mlo, mhi = clopper_pearson(exs, rep)
            println(io, join(("exacto_pequeno", Np, kp, Bp, @sprintf("%.6f", phi), M,
                              @sprintf("%.10e", Float64(ex)),
                              @sprintf("%.10e", Float64(lo)), @sprintf("%.10e", Float64(hi)),
                              @sprintf("%.10e", fl), @sprintf("%.10e", pm),
                              @sprintf("%.10e", mlo), @sprintf("%.10e", mhi), rep), '\t'))
        end

        # bloque grande (1 TiB) con k > B: el caso en que la detección es posible
        Ng, kg, Bg = e.N, 1000, 25
        for phi in (0.9, 0.98, 0.99, 0.995, 0.9975, 0.999, 0.9999, 0.99999)
            M = max(0, min(Ng, round(Int, (1 - phi) * Ng)))
            lo, hi = cola_hiper_intervalo(Ng, M, kg, Bg; bits = 256)
            fl = cola_hiper_rapida(t, Ng, M, kg, Bg)
            pm, exs, rep = p_deteccion_mc(semilla, Ng, M, kg, Bg, replicas)
            mlo, mhi = clopper_pearson(exs, rep)
            println(io, join(("grande_1TiB", Ng, kg, Bg, @sprintf("%.6f", phi), M,
                              "n/a",
                              @sprintf("%.10e", Float64(lo)), @sprintf("%.10e", Float64(hi)),
                              @sprintf("%.10e", fl), @sprintf("%.10e", pm),
                              @sprintf("%.10e", mlo), @sprintf("%.10e", mhi), rep), '\t'))
        end
    end

    # ── 5 · Certificado de las DECISIONES (no del valor de paso) ─────────────
    # Se certifica lo que decide: ¿deja el encierre a 256 bits `p` del mismo lado de
    # γ que el kernel rápido? Si el intervalo cruza γ, la celda es INCONCLUSA.
    open(joinpath(dir, "certificado.tsv"), "w") do io
        cabecera(io, "certificado · encierre riguroso de las decisiones p ≷ γ")
        println(io, join(("N", "k", "B", "phi", "M", "gamma", "lo_256", "hi_256",
                          "p_float", "decision", "certificada", "ancho_relativo"), '\t'))
        # celdas elegidas para cubrir los dos lados de γ y la frontera misma
        celdas = Any[]
        for (N, k, B) in ((2000, 100, 5), (e.N, 1000, 25), (e.N, 10^6, 181_092))
            for phi in (0.5, 0.99, 0.999, 0.9999, 0.99999)
                push!(celdas, (N, k, B, phi))
            end
        end
        # frontera real del caso grande: M tal que p ≈ γ (obtenida por bisección)
        Mg = M_para_gamma(t, e.N, 10^6, 181_092, gamma)
        for M in (Mg - 1, Mg, Mg + 1)
            push!(celdas, (e.N, 10^6, 181_092, 1.0 - M / e.N))
        end
        for (N, k, B, phi) in celdas
            M = max(0, min(N, round(Int, (1 - phi) * N)))
            lo, hi = cola_hiper_intervalo(N, M, k, B; bits = 256)
            fl = cola_hiper_rapida(TablaLogFact(N), N, M, k, B)
            dec = fl >= gamma
            cert = (Float64(lo) >= gamma) || (Float64(hi) < gamma)
            anc = Float64((hi - lo) / max(hi, BigFloat("1e-300")))
            println(io, join((N, k, B, @sprintf("%.6f", phi), M, @sprintf("%.1e", gamma),
                              @sprintf("%.10e", Float64(lo)), @sprintf("%.10e", Float64(hi)),
                              @sprintf("%.10e", fl), dec ? "p>=gamma" : "p<gamma",
                              cert ? "si" : "INCONCLUSA", @sprintf("%.3e", anc)), '\t'))
        end
    end


    # ── 6 · F5 · coste del registro y caducidad pseudoaleatoria ──────────────
    # `kappa` (segmentos/slot) y `h` (history_size) son ENTRADAS, no parámetros fijados.
    open(joinpath(dir, "F5-registro.tsv"), "w") do io
        cabecera(io, "F5 · coste del registro, estado y tasa de altas por caducidad")
        println(io, join(("piezas_lote", "TiB", "kappa_seg_slot", "h_segmentos",
                          "sectores", "vida_segmentos", "vida_slots", "altas_por_dia",
                          "estado_MB", "estado_MB_por_TiB", "fraccion_capacidad_inactiva_por_M",
                          "M_slots", "bytes_alta_B"), '\t'))
        for kap in (1e-3, 1e-2, 1e-1), h in (1e4, 1e5, 1e6)
            c = coste_registro(piezas = e.N, kappa_seg_slot = kap, h_segmentos = h,
                               bytes_alta = 200.0, M_slots = w_cmd)
            println(io, join((e.N, @sprintf("%.4f", e.N / piezas_por_TiB(bytes_pieza)),
                              @sprintf("%.1e", kap), @sprintf("%.1e", h), c.sectores,
                              @sprintf("%.1f", c.vida_segmentos), @sprintf("%.1f", c.vida_slots),
                              @sprintf("%.2f", c.altas_por_dia), @sprintf("%.4f", c.estado_B / 1e6),
                              @sprintf("%.4f", c.estado_B_por_TiB / 1e6),
                              @sprintf("%.6f", c.fraccion_inactiva_por_M), w_cmd, 200.0), '\t'))
        end
    end

    println("escrito en ", abspath(dir))
    for f in sort(readdir(dir))
        endswith(f, ".tsv") && println("  ", f)
    end
    return nothing
end

main(ARGS)
