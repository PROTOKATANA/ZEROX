#!/usr/bin/env julia
# run.jl — CLI reproducible de sellado-rama-v1.
#
# Todos los símbolos son ENTRADAS y se pasan por línea de comandos:
#   --lambda, --tau, --delta, --delta-medio, --s-max, --ramas, --objeto,
#   --replicas, --mc-h, --seed, --tarea.
# Uso:
#   julia --project=. run.jl --tarea todo --seed 0x5E110A1A --replicas 48 --mc-h 3000

using Printf
using Random
using StableRNGs
using SelladoRama
const S = SelladoRama
const RB = S.RB

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
function parse_args(args::Vector{String})
    op = Dict{String,Vector{String}}()
    i = 1
    while i <= length(args)
        a = args[i]
        startswith(a, "--") || error("argumento no reconocido: $a")
        clave = a[3:end]
        if i == length(args) || startswith(args[i+1], "--")
            haskey(op, clave) ? push!(op[clave], "true") : (op[clave] = ["true"])
            i += 1
        else
            haskey(op, clave) ? push!(op[clave], args[i+1]) : (op[clave] = [args[i+1]])
            i += 2
        end
    end
    return op
end

uno(op, k, def) = haskey(op, k) ? op[k][1] : def
todos(op, k) = haskey(op, k) ? op[k] : String[]

function carga_hardware(ruta::String)
    t = 0.0; r = 0.0; h = 0; pb = 0
    for ln in eachline(ruta)
        (isempty(strip(ln)) || startswith(strip(ln), "#")) && continue
        campos = split(ln, '\t')
        length(campos) < 2 && continue
        clave = strip(campos[1]); val = strip(campos[2])
        if clave == "t_tabla_s"
            t = parse(Float64, val)
        elseif clave == "r_tablas_s"
            r = parse(Float64, val)
        elseif clave == "hilos"
            h = parse(Int, val)
        elseif clave == "piece_bytes"
            pb = parse(Int, val)
        end
    end
    (t > 0 && r > 0 && h > 0 && pb > 0) ||
        error("hardware.tsv incompleto en $ruta (t=$t r=$r h=$h bytes=$pb)")
    return S.Hardware(t_tabla_s = t, r_tablas_s = r, hilos = h, piece_bytes = pb)
end

fmt_rb(x::RB) = string(numerator(x), "/", denominator(x))

function abre(ruta::String)
    return open(ruta, "w")
end

# ---------------------------------------------------------------------------
# Tarea F2 — tasa de re-ligadura y presupuesto temporal (§2.2)
# ---------------------------------------------------------------------------
function tarea_f2(io_out, hw::S.Hardware; λ::Float64, τ::Float64,
                  deltas::Vector{Float64}, delta_medios::Vector{Float64})
    println(io_out, "# F2-religadura · λ=$λ τ=$τ · hardware t_tabla=$(hw.t_tabla_s) r=$(hw.r_tablas_s)")
    println(io_out, join(["Delta_s", "lambda_bps", "tau_s", "n_puntas", "padres_medios",
                          "tasa_religadura_s", "W_honesto_s", "tablas_presupuesto",
                          "fraccion_TiB_presupuesto", "T_religar_TiB_s", "veces_TiB_sobre_W"],
                         '\t'))
    N_TiB = S.piezas_por_TiB(hw)
    for Δ in deltas
        for np in (1.0, S.puntas_concurrentes(λ, Δ))
            p = S.presupuesto_honesto(λ, τ, Δ; n_puntas = np)
            tablas = hw.r_tablas_s * p.W_s
            T_TiB = S.segundos_materializar(hw, N_TiB)
            @printf(io_out, "%.6f\t%.4f\t%.4f\t%.6f\t%.6f\t%.6f\t%.9f\t%.6f\t%.3e\t%.3f\t%.3e\n",
                    Δ, λ, τ, np, S.padres(λ, Δ), p.tasa_religadura, p.W_s,
                    tablas, tablas / N_TiB, T_TiB, T_TiB / p.W_s)
        end
    end
    println(io_out, "#")
    println(io_out, "# F2-materializacion · fracción del objeto que cabe en W (Δ de la rejilla p99)")
    println(io_out, join(["Delta_s", "W_s", "objeto", "S_piezas", "delta_max_piezas",
                          "fraccion_materializable", "veces_presupuesto",
                          "T_materializar_s", "T_materializar_h"], '\t'))
    objetos = [("1 GiB", 1024.0), ("1 TiB", N_TiB), ("1 PiB", 1024.0 * N_TiB)]
    for Δ in deltas
        p = S.presupuesto_honesto(λ, τ, Δ; n_puntas = 1.0)
        for (etiq, Sp) in objetos
            frac = S.fraccion_materializable(hw, p.W_s, Sp)
            T = S.segundos_materializar(hw, Sp)
            @printf(io_out, "%.6f\t%.9f\t%s\t%.6f\t%.6f\t%.3e\t%.3e\t%.3f\t%.3f\n",
                    Δ, p.W_s, etiq, Sp, S.delta_max_piezas(hw, p.W_s), frac,
                    S.veces_presupuesto(hw, p.W_s, Sp), T, T / 3600)
        end
    end
    println(io_out, "#")
    println(io_out, "# F2-profundo · atado a un ancestro a profundidad d: la re-ligadura cambia a tasa λ igual")
    println(io_out, join(["lambda_bps", "d_bloques", "tasa_religadura_s", "rivalidad_vs_fork_superficial"],
                         '\t'))
    for d in (0, 1, 2, 4, 8, 16, 32)
        @printf(io_out, "%.4f\t%d\t%.6f\t%s\n", λ, d, λ,
                d == 0 ? "solo_d=0" : "el_atacante_bifurca_a_profundidad_<=d_y_comparte")
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Tarea F4 — coste del honesto
# ---------------------------------------------------------------------------
function tarea_f4(io_out, hw::S.Hardware; λ::Float64, τ::Float64, Δ::Float64,
                  ramas::Vector{Float64})
    N_TiB = S.piezas_por_TiB(hw)
    println(io_out, "# F4-honesto · λ=$λ τ=$τ Δ=$Δ · objeto = 1 TiB")
    println(io_out, join(["ramas", "espacio_extra_rel", "espacio_extra_TiB",
                          "T_bajo_max_s", "rebind_por_slot", "carga_cpu_frac_max",
                          "horas_TiB_extra_1nucleo"], '\t'))
    for k in ramas
        p = S.presupuesto_honesto(λ, τ, Δ; n_puntas = k)
        extra = k - 1.0
        carga = S.carga_religadura(p, p.W_s)
        @printf(io_out, "%.6f\t%.6f\t%.6f\t%.9f\t%.6f\t%.6f\t%.3f\n",
                k, extra, extra, p.W_s, k * λ, carga,
                extra * S.horas_TiB_1nucleo(hw))
    end
    println(io_out, "#")
    println(io_out, "# F4-espacio-propio · para que dos objetos cuenten como espacio PROPIO")
    println(io_out, join(["Delta_s", "W_s", "delta_max_piezas", "delta_max_MiB",
                          "S_TiB", "delta_sobre_S", "veces_que_W_cuesta_el_objeto_entero"], '\t'))
    for Δv in (0.26, 0.45, 0.60)
        p = S.presupuesto_honesto(λ, τ, Δv; n_puntas = 1.0)
        d = S.delta_max_piezas(hw, p.W_s)
        @printf(io_out, "%.6f\t%.9f\t%.6f\t%.6f\t%.1f\t%.3e\t%.3e\n",
                Δv, p.W_s, d, d * hw.piece_bytes / 2^20, 1.0, d / N_TiB,
                S.veces_presupuesto(hw, p.W_s, N_TiB))
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Tarea F5 — superficie α* y efecto perverso β_d → β_x
# ---------------------------------------------------------------------------
function tarea_f5(io_out; η_h::RB, η_a::RB)
    println(io_out, "# F5-alfa · α* exacta en Rational{BigInt} · η_h=$(fmt_rb(η_h)) η_a=$(fmt_rb(η_a))")
    println(io_out, join(["beta_d", "beta_x", "alpha_estrella", "alpha_decimal",
                          "g_en_alpha", "etiqueta"], '\t'))
    betas = [RB(0), RB(1, 10), RB(1, 5), RB(3, 10), RB(2, 5), RB(1, 2)]
    for bd in betas, bx in betas
        bd + bx <= 1 || continue
        α = S.alpha_estrella_exacta(η_h, η_a, bd, bx)
        g = S.g_exacta(α, η_h, η_a, bd, bx)
        et = α < 0 ? "atacante_ya_gana_deriva" :
             (bd == 0 && bx == 0) ? "sin_trampa" :
             (bx == 0 ? "solo_beta_d" : (bd == 0 ? "solo_beta_x" : "ambos"))
        @printf(io_out, "%s\t%s\t%s\t%.6f\t%s\t%s\n",
                fmt_rb(bd), fmt_rb(bx), fmt_rb(α), Float64(α), fmt_rb(g), et)
    end
    println(io_out, "#")
    println(io_out, "# F5-sustitucion · todo el espacio tramposo s en β_d o en β_x (aritmética exacta)")
    println(io_out, join(["s", "alpha_todo_bd", "alpha_todo_bx", "gap", "gap_decimal"], '\t'))
    for s in (RB(1, 10), RB(1, 5), RB(3, 10), RB(2, 5))
        a_bd = S.alpha_estrella_exacta(η_h, η_a, s, RB(0))
        a_bx = S.alpha_estrella_exacta(η_h, η_a, RB(0), s)
        @printf(io_out, "%s\t%s\t%s\t%s\t%.6f\n", fmt_rb(s), fmt_rb(a_bd), fmt_rb(a_bx),
                fmt_rb(a_bd - a_bx), Float64(a_bd - a_bx))
    end
    println(io_out, "#")
    println(io_out, "# F5-umbral · preferencia marginal del atacante (c_x = 1, c_d = φ)")
    println(io_out, join(["phi_cd_sobre_cx", "dano_bd_por_coste", "dano_bx_por_coste",
                          "ventaja_bx", "prefiere", "veredicto_dispositivo"], '\t'))
    for φ in (RB(1, 10), RB(1, 4), RB(2, 5), RB(1, 2), RB(3, 5), RB(1), RB(2))
        d = S.dano_por_coste(φ, RB(1))
        v = S.ventaja_bx_sobre_bd(φ, RB(1))
        prefiere = d.bx > d.bd ? "bx" : (d.bx < d.bd ? "bd" : "indiferente")
        ver = φ < RB(1) // 2 ? "no_backfire" :
              (φ > RB(1) // 2 ? "backfire_bx" : "frontera_exacta")
        @printf(io_out, "%s\t%s\t%s\t%s\t%s\t%s\n",
                fmt_rb(φ), fmt_rb(d.bd), fmt_rb(d.bx), fmt_rb(v), prefiere, ver)
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Tarea certificado — encierre exacto de α* por bisección
# ---------------------------------------------------------------------------
function tarea_certificado(io_out; η_h::RB, η_a::RB)
    println(io_out, "# certificado · bracket exacto por bisección (256 iteraciones) e residuo")
    println(io_out, join(["beta_d", "beta_x", "alpha_exacta", "lo", "hi", "ancho",
                          "g_lo", "g_hi", "g_alpha_exacta", "alpha_en_bracket"], '\t'))
    casos = [(RB(0), RB(0)), (RB(1, 5), RB(0)), (RB(0), RB(1, 5)),
             (RB(1, 5), RB(1, 5)), (RB(3, 10), RB(3, 10)), (RB(17, 50), RB(17, 100))]
    for (bd, bx) in casos
        α = S.alpha_estrella_exacta(η_h, η_a, bd, bx)
        lo, hi = S.biseccion_raiz(η_h, η_a, bd, bx; iter = 256)
        g_lo = S.g_exacta(lo, η_h, η_a, bd, bx)
        g_hi = S.g_exacta(hi, η_h, η_a, bd, bx)
        ga = S.g_exacta(α, η_h, η_a, bd, bx)
        @printf(io_out, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                fmt_rb(bd), fmt_rb(bx), fmt_rb(α), fmt_rb(lo), fmt_rb(hi),
                fmt_rb(hi - lo), fmt_rb(g_lo), fmt_rb(g_hi), fmt_rb(ga),
                string(lo <= α <= hi))
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Tarea MC — modelo de punta
# ---------------------------------------------------------------------------
function tarea_mc(io_out, hw::S.Hardware; λ::Float64, delta_medios::Vector{Float64},
                  replicas::Int, H::Float64, maestra::UInt64)
    println(io_out, "# F2-mc-puntas · modelo H-RECEP · replicas=$replicas H=$H seed=$(@sprintf("%#x", maestra))")
    println(io_out, join(["Delta_medio_s", "lambda_bps", "padres_cerrado",
                          "padres_mc_StableRNG", "padres_mc_Philox", "puntas_MC",
                          "desv_rel_StableRNG", "desv_rel_Philox"], '\t'))
    for Δm in delta_medios
        ps, pp = S.mc_puntas(λ, Δm, H, replicas, maestra)
        pr, _ = S.mc_puntas_r123(λ, Δm, H, replicas, maestra)
        cerr = S.padres(λ, Δm)
        ms = sum(ps) / length(ps)
        mr = sum(pr) / length(pr)
        mp = sum(pp) / length(pp)
        @printf(io_out, "%.6f\t%.4f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\n",
                Δm, λ, cerr, ms, mr, mp, (ms - cerr) / cerr, (mr - cerr) / cerr)
    end
    return nothing
end

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
function main()
    op = parse_args(ARGS)
    dir = uno(op, "salida-dir", joinpath(@__DIR__, "resultados"))
    mkpath(dir)
    hw = carga_hardware(uno(op, "hardware", joinpath(@__DIR__, "mediciones", "hardware.tsv")))
    λ = parse(Float64, uno(op, "lambda", "1.0"))
    τ = parse(Float64, uno(op, "tau", "1.0"))
    Δs = [parse(Float64, x) for x in split(uno(op, "delta", "0.26,0.35,0.45,0.60"), ',')]
    Δms = [parse(Float64, x) for x in split(uno(op, "delta-medio", "0.138,0.20,0.30,0.387"), ',')]
    ramas = [parse(Float64, x) for x in split(uno(op, "ramas", "1.0,1.14,1.26,1.39,2.0"), ',')]
    replicas = parse(Int, uno(op, "replicas", "48"))
    H = parse(Float64, uno(op, "mc-h", "3000"))
    maestra = parse(UInt64, uno(op, "seed", "0x5E110A1A"))
    ηh = RB(parse(Int, uno(op, "eta-h", "1")))
    ηa = RB(parse(Int, uno(op, "eta-a", "1")))
    tareas = todos(op, "tarea")
    isempty(tareas) && (tareas = ["todo"])
    if "todo" in tareas
        tareas = ["f2", "f4", "f5", "cert", "mc"]
    end

    println("=== sellado-rama-v1 · $(S.MODELO_VERSION) ===")
    println("hardware: t_tabla=$(hw.t_tabla_s) s r=$(hw.r_tablas_s) tablas/s hilos=$(hw.hilos) piece=$(hw.piece_bytes) B")
    println("N_TiB=$(S.piezas_por_TiB(hw)) · horas/TiB 1 núcleo=$(S.horas_TiB_1nucleo(hw)) · máquina=$(S.horas_TiB_maquina(hw))")
    println("λ=$λ τ=$τ Δ=$Δs Δmedio=$Δms ramas=$ramas")
    println("hilos Julia=$(Threads.nthreads(:default)), interactivo=$(Threads.nthreads(:interactive))")

    if "f2" in tareas
        open(joinpath(dir, "F2-religadura.tsv"), "w") do io
            tarea_f2(io, hw; λ = λ, τ = τ, deltas = Δs, delta_medios = Δms)
        end
        println("escrito F2-religadura.tsv")
    end
    if "f4" in tareas
        open(joinpath(dir, "F4-honesto.tsv"), "w") do io
            tarea_f4(io, hw; λ = λ, τ = τ, Δ = max(0.26, minimum(Δs)), ramas = ramas)
        end
        println("escrito F4-honesto.tsv")
    end
    if "f5" in tareas
        open(joinpath(dir, "F5-alfa-sustitucion.tsv"), "w") do io
            tarea_f5(io; η_h = ηh, η_a = ηa)
        end
        println("escrito F5-alfa-sustitucion.tsv")
    end
    if "cert" in tareas
        open(joinpath(dir, "certificado.tsv"), "w") do io
            tarea_certificado(io; η_h = ηh, η_a = ηa)
        end
        println("escrito certificado.tsv")
    end
    if "mc" in tareas
        open(joinpath(dir, "F2-mc-puntas.tsv"), "w") do io
            tarea_mc(io, hw; λ = λ, delta_medios = Δms, replicas = replicas, H = H,
                     maestra = maestra)
        end
        println("escrito F2-mc-puntas.tsv")
    end
    println("=== fin ===")
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
