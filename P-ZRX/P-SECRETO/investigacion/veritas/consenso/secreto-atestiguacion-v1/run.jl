# run.jl — CLI reproducible del instrumento secreto-atestiguacion-v1
# Uso: veritas/julia.sh --project=. run.jl --seed 0x5EC5E70 --tarea f1 --tarea f3 --tarea f4
# Sin @fastmath, sin @simd, sin Float32 en fronteras. Aritmética exacta (Rational{BigInt})
# en captura/viveza/fuga; la latencia lognormal se certifica con Arblib y se cruza
# convolución ↔ Monte Carlo (semilla de CLI, semillas no consecutivas por réplica).

using Dates

include("src/modelo.jl")
include("src/referencia.jl")
include("src/rapido.jl")
include("src/validacion.jl")

const RB = Rational{BigInt}

function parse_args(args)::Dict{String,Any}
    d = Dict{String,Any}()
    d["tareas"] = String[]
    d["seed"] = UInt64(0x5EC5E70)
    i = 1
    while i ≤ length(args)
        a = args[i]
        if a == "--seed"
            s = args[i+1]
            d["seed"] = parse(UInt64, startswith(s, "0x") ? s[3:end] : s; base = 16)
            i += 2
        elseif a == "--tarea"
            push!(d["tareas"], args[i+1])
            i += 2
        else
            error("argumento desconocido: $a")
        end
    end
    return d
end

function escribir_tsv(ruta::String, cabecera::Vector{String}, filas::Vector{Vector{String}})
    open(ruta, "w") do io
        println(io, join(cabecera, "\t"))
        for f in filas
            println(io, join(f, "\t"))
        end
    end
end

function encabezado_entorno(seed::UInt64, tareas::Vector{String})::String
    io = IOBuffer()
    println(io, "# corrida secreto-atestiguacion-v1")
    println(io, "# fecha       ", Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
    println(io, "# VERSION     ", VERSION)
    println(io, "# CPU         ", Sys.CPU_NAME)
    println(io, "# hilos       ", Threads.nthreads())
    println(io, "# RAM total   ", Sys.total_memory() ÷ (1024^2), " MiB")
    println(io, "# semilla     ", string(seed, base = 16))
    println(io, "# tareas      ", join(tareas, " "))
    return String(take!(io))
end

function tarea_f1(ruta::String)
    # Control ejecutable de clasificación (§4.1 del PROMPT), con los dos regímenes S2
    atk, d, pub, com = 7, 20, 999, 42
    rama = rama_privada_atacante(atk, d, pub, com)
    honestos = collect(1001:1004)
    B = BloqueF1(150, atk, [com], [pub], [atk])
    # V1: el atacante obtiene firmas de las claves sorteadas sin revelar el bloque
    B_v1 = BloqueF1(150, atk, [com], [pub], vcat([atk], firmas_obtenibles_v1(B, honestos)))
    filas = [
        ["compromiso_previo_intencion", string(cumple_compromiso_previo(rama, com)), "falsificable_en_rama_privada"],
        ["historial_reciente_de_clave", string(cumple_historial_reciente(rama, atk, 5)), "falsificable_en_rama_privada"],
        ["referencia_a_datos_publicos", string(cumple_referencia_publica(rama, pub)), "falsificable_en_rama_privada"],
        ["atestiguacion_sin_firmas_honestas", string(cumple_atestiguacion(B, honestos)), "sin_cooperacion_honesta_NO_se_cumple"],
        ["atestiguacion_regimen_V1_firma_a_ciegas", string(cumple_atestiguacion(B_v1, honestos)), "satisfacible_en_rama_privada_V1"],
        ["atestiguacion_regimen_V2_firma_lo_visto", string(revelado_a_firmantes_v2(B_v1, honestos)), "revela_el_bloque_a_cada_firmante_V2"],
    ]
    escribir_tsv(ruta, ["condicion", "se_satisface", "clasificacion"], filas)
end

function tarea_f3(ruta1::String, ruta2::String, ruta3::String)
    ks = [1, 2, 4, 8, 16, 32]
    αs = [RB(1, 100), RB(1, 10), RB(1, 4), RB(1, 3), RB(2, 5), RB(49, 100)]
    filas = Vector{String}[]
    for k in ks, α in αs
        cap = captura_reemplazo(α, k)
        push!(filas, [string(k), string(Float64(α)),
                      string(round(log10(BigFloat(numerator(cap)) / BigFloat(denominator(cap))), digits = 4)),
                      string(round(Float64(captura_sin_reemplazo(α, max(k, 1000), k)), sigdigits = 6))])
    end
    escribir_tsv(ruta1, ["k", "alpha", "log10_P(captura_un_bloque)_exacta", "P_sin_reemplazo_M=1000"], filas)

    ds = [10, 100, 1000, 7200]
    filas = Vector{String}[]
    for k in ks, d in ds
        α = RB(1, 3)
        p1 = captura_cadena(α, k, d)
        p2 = captura_cadena_sin_reto(α, k, d)
        l1 = log10(BigFloat(numerator(p1)) / BigFloat(denominator(p1)))
        l2 = log10(BigFloat(numerator(p2)) / BigFloat(denominator(p2)))
        push!(filas, [string(k), string(d), string(round(l1, digits = 3)), string(round(l2, digits = 3))])
    end
    escribir_tsv(ruta2, ["k", "d_slots", "log10_P(cadena)_con_reto_exacta_alpha_1_3", "log10_P(cadena)_solo_sorteo"], filas)

    filas = Vector{String}[]
    for k in ks
        push!(filas, [string(k), string(bytes_cabecera_ed25519(k)), string(bytes_cabecera_bls(k)),
                      string(round(bytes_cabecera_ed25519(k) / PRESUPUESTO_Q2_CABECERA, digits = 3)),
                      string(round(bytes_anuales(bytes_cabecera_ed25519(k)) / 1e9, digits = 2)),
                      string(round(bytes_anuales(bytes_cabecera_bls(k)) / 1e9, digits = 3))])
    end
    escribir_tsv(ruta3, ["k", "bytes_Ed25519", "bytes_BLS", "fraccion_presupuesto_Q2_1kB",
                         "GB_anual_Ed25519", "GB_anual_BLS"], filas)
end

function tarea_f4(ruta1::String, ruta2::String, ruta3::String, ruta4::String, ruta5::String;
                  seed::UInt64 = UInt64(0x5EC5E70))
    ks = [1, 2, 4, 8, 16, 32]
    Δs = [0.26, 0.35, 0.45, 0.60]
    τ = 1.0
    t_sign = 0.02
    hs = [1, 2, 3]
    n_mc = 100_000
    # La CDF de la suma de m = 2h enlaces no depende de k ni de Δ: se calcula UNA vez
    # por h y se reutiliza (el coste dominante es la convolución iterada).
    t_max = 6.0
    npts = 4000
    cdfs = Dict{Int,Tuple{Vector{Float64},Vector{Float64}}}()
    for h in hs
        cdfs[h] = cdf_suma_enlaces(2 * h, t_max, npts)
    end
    dx = t_max / npts
    filas = Vector{String}[]
    for k in ks, Δ in Δs, h in hs
        W = τ - Δ
        u = W - t_sign
        u ≤ 0 && continue
        x, F = cdfs[h]
        idx = clamp(round(Int, u / dx), 1, npts)
        p_conv = F[idx]^k
        if h == 3 && k ≤ 16
            p_mc, lo, hi = mc_p_cabe(τ, Δ, k, h, t_sign, n_mc, seed)
        else
            p_mc, lo, hi = NaN, NaN, NaN
        end
        push!(filas, [string(k), string(Δ), string(h), string(round(p_conv, digits = 4)),
                      isnan(p_mc) ? "-" : string(round(p_mc, digits = 4)),
                      isnan(lo) ? "-" : string(round(lo, digits = 4)),
                      isnan(hi) ? "-" : string(round(hi, digits = 4))])
    end
    escribir_tsv(ruta1, ["k", "Delta_s", "h_saltos", "P_cabe_convolucion", "P_cabe_MC",
                         "IC_lo_99", "IC_hi_99"], filas)

    αs = [0.01, 0.10, 0.25, 0.33, 0.40]
    ps = [0.90, 0.99]
    filas = Vector{String}[]
    for k in ks, α in αs, p in ps
        f = fraccion_produce(RB(round(Int, α * 100), 100), RB(round(Int, p * 100), 100), k)
        push!(filas, [string(k), string(α), string(p), string(round(Float64(f), digits = 4)),
                      string(round(1.0 - Float64(f), digits = 3))])
    end
    escribir_tsv(ruta2, ["k", "alpha", "p_disponible", "fraccion_produccion_honesta", "impuesto"], filas)

    xs = [0.10, 0.30, 0.50]
    filas = Vector{String}[]
    for k in ks, x in xs
        f = paro_particion(RB(round(Int, x * 100), 100), k)
        push!(filas, [string(k), string(x), string(round(Float64(f), digits = 4))])
    end
    escribir_tsv(ruta3, ["k", "x_fraccion_lado", "P(ambos_lados_paran)"], filas)

    p_sils = [0.5, 0.1, 0.01]
    ds = [10, 100, 1000, 7200]
    α = 0.33
    filas = Vector{String}[]
    for k in [1, 2, 4, 8], p_sil in p_sils, d in ds
        l = log10_p_no_fuga(α, p_sil, k, d)
        push!(filas, [string(k), string(p_sil), string(d), string(round(Float64(l), digits = 3))])
    end
    escribir_tsv(ruta4, ["k", "p_silencio_firmante", "d_slots", "log10_P(ninguna_fuga_en_la_cadena)"], filas)

    βs = [(RB(1, 10), RB(0)), (RB(1, 5), RB(0)), (RB(3, 10), RB(0)),
          (RB(0), RB(1, 10)), (RB(0), RB(1, 5)), (RB(0), RB(3, 10)), (RB(1, 10), RB(1, 10))]
    filas = Vector{String}[]
    for (β_d, β_x) in βs
        α = alpha_estrella_uno(β_d, β_x)
        g0 = deriva(α, β_d, β_x, RB(1), RB(1))
        push!(filas, [string(Float64(β_d)), string(Float64(β_x)), string(α), string(g0)])
    end
    escribir_tsv(ruta5, ["beta_d", "beta_x", "alpha_estrella", "g_en_alpha_estrella"], filas)
end

function main()
    args = parse_args(ARGS)
    seed = args["seed"]
    tareas = args["tareas"]
    isempty(tareas) && (tareas = ["f1", "f3", "f4"])
    mkpath("resultados")
    open("resultados/CORRIDA.log", "w") do io
        println(io, encabezado_entorno(seed, tareas))
    end
    for t in tareas
        t == "f1" && tarea_f1("resultados/F1-control.tsv")
        t == "f3" && tarea_f3("resultados/F3-captura.tsv", "resultados/F3-cadena.tsv", "resultados/F3-coste.tsv")
        t == "f4" && tarea_f4("resultados/F4-latencia.tsv", "resultados/F4-viveza.tsv",
                              "resultados/F4-particion.tsv", "resultados/F4-soborno.tsv",
                              "resultados/F4-alfa.tsv"; seed = seed)
        (t == "f4" || t == "f3" || t == "f1") || error("tarea desconocida: $t")
    end
    println("tareas completadas: ", join(tareas, " "))
end

main()
