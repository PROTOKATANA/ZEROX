# run.jl — CLI reproducible del barrido de Δ en red sintética P2P.
#
# Modos:
#   julia --project=. run.jl                 barrido principal (2 topologías × 3 n × 12 réplicas)
#   julia --project=. run.jl --sensibilidad  barridos de sensibilidad a n=1000
#   julia --project=. run.jl --escalado      24 réplicas fijas (regular, n=10000) para medir
#                                            escalado de hilos (se invoca con distinto nº de hilos)
#   julia --project=. run.jl --caso --n 100 --topologia regular ...   una sola combinación
#
# Flags numéricos (un valor, o lista separada por comas en el barrido):
#   --n, --topologia, --grado, --mediana-latencia, --p99-latencia, --ancho-banda,
#   --tam-bloque, --retardo-procesado, --lambda, --horizonte, --replicas, --semilla
#
# Toda cifra publicada sale de aquí con semilla y entorno fijados (LINEO §7).

using StableRNGs
using DeltaMedido
using Printf
import Pkg

const QS = (50, 90, 99, 100)
const NOMBRES_Q = ["d50", "d90", "d99", "d100"]
const ESTADISTICOS = ["med", "p90", "p99", "max"]

# -----------------------------------------------------------------------------
# argumentos
# -----------------------------------------------------------------------------

function parse_args(argv::Vector{String})
    d = Dict{String,String}()
    i = 1
    while i <= length(argv)
        a = argv[i]
        startswith(a, "--") || error("argumento desconocido: $a")
        nombre = a[3:end]
        if nombre in ("sensibilidad", "escalado", "caso", "r2")
            d["modo"] = nombre
            i += 1
        else
            i + 1 <= length(argv) || error("falta valor para $a")
            d[nombre] = argv[i+1]
            i += 2
        end
    end
    return d
end

flag(d::Dict{String,String}, k::String, def) = haskey(d, k) ? d[k] : def
flag_float(d, k, def) = parse(Float64, flag(d, k, string(def)))
flag_int(d, k, def) = parse(Int, flag(d, k, string(def)))
lista_float(d, k, defs) = [parse(Float64, s) for s in split(flag(d, k, join(defs, ",")), ',')]
lista_int(d, k, defs) = [parse(Int, s) for s in split(flag(d, k, join(defs, ",")), ',')]
lista_sym(d, k, defs) = [Symbol(s) for s in split(flag(d, k, join(string.(defs), ",")), ',')]

# -----------------------------------------------------------------------------
# una corrida
# -----------------------------------------------------------------------------

struct Fila
    combo_id::Int
    replica::Int
    semilla::UInt64
    n_bloques::Int
    eventos::Int
    segundos::Float64
    D::Matrix{Float64}   # Δ por bloque × cuantil (50, 90, 99, 100)
end

function correr_una(rng::StableRNGs.LehmerRNG, p::ParametrosRed)
    red = construir_red(rng, p)
    t_creacion = calendario_poisson(rng, p.lambda, p.horizonte)
    creador = rand(rng, 1:p.n, length(t_creacion))
    m = MotorRapido(p.n; capacidad = 64 + (p.n * p.grado + 1) * 16)
    llegada = correr!(m, red, t_creacion, creador)
    invariantes(llegada, t_creacion) || error("invariantes rotos en corrida")
    D = deltas_por_bloque(llegada, t_creacion; qs = QS)
    eventos = length(t_creacion) * (length(red.g.vecinos) + 1)
    return D, length(t_creacion), eventos
end

# -----------------------------------------------------------------------------
# barridos
# -----------------------------------------------------------------------------

struct Combo
    id::Int
    p::ParametrosRed
end

function combos_barrido(o::Dict{String,String})
    n_lista = lista_int(o, "n", [100, 1000, 10000])
    topo_lista = lista_sym(o, "topologia", [:regular, :erdos_renyi])
    grado = flag_int(o, "grado", 8)
    med = flag_float(o, "mediana-latencia", 0.08)
    p99 = flag_float(o, "p99-latencia", 0.5)
    bw = flag_float(o, "ancho-banda", 1.0e7)
    tam = flag_float(o, "tam-bloque", 683.0)
    tproc = flag_float(o, "retardo-procesado", 0.0)
    lam = flag_float(o, "lambda", 1.0)
    T = flag_float(o, "horizonte", 600.0)
    combos = Combo[]
    for topo in topo_lista, n in n_lista
        push!(combos, Combo(length(combos) + 1,
            ParametrosRed(n, topo, grado, med, p99, bw, tam, tproc, lam, T)))
    end
    return combos
end

"""Sensibilidad: n=1000 fija (regular por defecto), un eje cada vez."""
function combos_sensibilidad(o::Dict{String,String})
    n = flag_int(o, "n", 1000)
    topo = lista_sym(o, "topologia", [:regular])[1]
    grado = flag_int(o, "grado", 8)
    med = flag_float(o, "mediana-latencia", 0.08)
    p99 = flag_float(o, "p99-latencia", 0.5)
    bw = flag_float(o, "ancho-banda", 1.0e7)
    tam = flag_float(o, "tam-bloque", 683.0)
    tproc = flag_float(o, "retardo-procesado", 0.0)
    lam = flag_float(o, "lambda", 1.0)
    T = flag_float(o, "horizonte", 600.0)
    base = (n = n, topo = topo, grado = grado, med = med, p99 = p99,
            bw = bw, tam = tam, tproc = tproc, lam = lam, T = T)
    ejes = [
        (:mediana_latencia, [0.03, 0.08, 0.2]),
        (:ancho_banda, [2.0e6, 1.0e7, 5.0e7]),
        (:tam_bloque, [683.0, 1.0e5, 1.0e6]),
        (:retardo_procesado, [0.0, 0.1]),
    ]
    combos = Combo[]
    for (eje, valores) in ejes
        for v in valores
            med_v, bw_v, tam_v, tproc_v = base.med, base.bw, base.tam, base.tproc
            eje === :mediana_latencia && (med_v = v)
            eje === :ancho_banda && (bw_v = v)
            eje === :tam_bloque && (tam_v = v)
            eje === :retardo_procesado && (tproc_v = v)
            push!(combos, Combo(length(combos) + 1,
                ParametrosRed(base.n, base.topo, base.grado, med_v, base.p99, bw_v,
                              tam_v, tproc_v, base.lam, base.T)))
        end
    end
    return combos
end

function combos_escalado(o::Dict{String,String})
    grado = flag_int(o, "grado", 8)
    return [Combo(1, ParametrosRed(10000, :regular, grado, 0.08, 0.5, 1.0e7, 683.0, 0.0, 1.0, 600.0))]
end

function combos_caso(o::Dict{String,String})
    n = flag_int(o, "n", 100)
    topo = lista_sym(o, "topologia", [:regular])[1]
    grado = flag_int(o, "grado", 8)
    med = flag_float(o, "mediana-latencia", 0.08)
    p99 = flag_float(o, "p99-latencia", 0.5)
    bw = flag_float(o, "ancho-banda", 1.0e7)
    tam = flag_float(o, "tam-bloque", 683.0)
    tproc = flag_float(o, "retardo-procesado", 0.0)
    lam = flag_float(o, "lambda", 1.0)
    T = flag_float(o, "horizonte", 600.0)
    return [Combo(1, ParametrosRed(n, topo, grado, med, p99, bw, tam, tproc, lam, T))]
end

# -----------------------------------------------------------------------------
# ejecución paralela determinista
# -----------------------------------------------------------------------------

function ejecutar(combos::Vector{Combo}, replicas::Int, semilla_maestra::UInt64)
    trabajos = Tuple{Int,Int}[]          # (combo_idx, replica)
    for (ci, c) in enumerate(combos), r in 1:replicas
        push!(trabajos, (ci, r))
    end
    # los combos grandes primero: equilibra los hilos
    sort!(trabajos; by = t -> -combos[t[1]].p.n)
    filas = Vector{Union{Fila,Nothing}}(nothing, length(trabajos))
    Threads.@threads for i in eachindex(trabajos)
        ci, r = trabajos[i]
        combo = combos[ci]
        semilla = semilla_derivada(semilla_maestra, UInt64(combo.id), UInt64(r))
        rng = StableRNG(semilla)
        t0 = time()
        D, n_bloques, eventos = correr_una(rng, combo.p)
        filas[i] = Fila(combo.id, r, semilla, n_bloques, eventos, time() - t0, D)
    end
    return [f for f in filas if f !== nothing]
end

"""Filas por combo, en orden de réplica (reducción determinista)."""
function agregar(combos::Vector{Combo}, filas::Vector{Fila})
    por_combo = [Fila[] for _ in combos]
    for f in filas
        push!(por_combo[f.combo_id], f)
    end
    for fs in por_combo
        sort!(fs; by = f -> f.replica)
    end
    return por_combo
end

# -----------------------------------------------------------------------------
# salida CSV
# -----------------------------------------------------------------------------

linea_csv(fields) = join(string.(fields), ",")

function parametros_fijos(c::Combo)
    p = c.p
    return Any[c.id, string(p.topologia), p.n, p.grado, p.mediana_latencia, p.p99_latencia,
               p.ancho_banda, p.tam_bloque, p.retardo_procesado, p.lambda, p.horizonte]
end

function encabezado_corridas()
    fijos = ["combo_id", "topologia", "n", "grado", "mediana_latencia_s", "p99_latencia_s",
             "ancho_banda_bps", "tam_bloque_B", "retardo_procesado_s", "lambda_1_s",
             "horizonte_s", "replica", "semilla", "n_bloques", "eventos", "segundos_pared"]
    qcols = ["$(s)_$(qn)_s" for qn in NOMBRES_Q for s in ESTADISTICOS]
    return vcat(fijos, qcols)
end

function fila_corrida(c::Combo, f::Fila)
    fijos = vcat(parametros_fijos(c),
                 Any[f.replica, f.semilla, f.n_bloques, f.eventos, f.segundos])
    vals = Float64[]
    for j in 1:length(QS)
        w = sort(f.D[:, j])
        m = length(w)
        push!(vals, w[cld(50 * m, 100)], w[cld(90 * m, 100)], w[cld(99 * m, 100)], w[m])
    end
    return vcat(fijos, vals)
end

function encabezado_resumen()
    fijos = ["combo_id", "topologia", "n", "grado", "mediana_latencia_s", "p99_latencia_s",
             "ancho_banda_bps", "tam_bloque_B", "retardo_procesado_s", "lambda_1_s",
             "horizonte_s", "n_corridas", "n_bloques_total", "eventos_total"]
    qcols = ["$(s)_$(qn)_s" for qn in NOMBRES_Q for s in ESTADISTICOS]
    return vcat(fijos, qcols)
end

"""Pool exacto: concatena los Δ por bloque de todas las réplicas del combo y calcula
los percentiles sobre el pool, en orden de réplica."""
function fila_resumen(c::Combo, fs::Vector{Fila})
    fijos = vcat(parametros_fijos(c),
                 Any[length(fs), sum(f -> f.n_bloques, fs), sum(f -> f.eventos, fs)])
    vals = Float64[]
    for j in 1:length(QS)
        pool = Float64[]
        for f in fs
            append!(pool, f.D[:, j])
        end
        w = sort(pool)
        m = length(w)
        push!(vals, w[cld(50 * m, 100)], w[cld(90 * m, 100)], w[cld(99 * m, 100)], w[m])
    end
    return vcat(fijos, vals)
end

# -----------------------------------------------------------------------------
# entorno y metadatos
# -----------------------------------------------------------------------------

"""utime + stime del proceso desde /proc/self/stat (campos 14 y 15, ticks de 100 Hz)."""
function cpu_time_seg()
    stats = read("/proc/self/stat", String)
    campos = split(stats)
    return (parse(Float64, campos[14]) + parse(Float64, campos[15])) / 100.0
end

function escribir_entorno(ruta_dir, semilla_maestra, argv, t0, t1)
    git_hash = try
        chomp(read(`git -C /home/katana/zeo/ZEROX rev-parse HEAD`, String))
    catch
        "no_disponible"
    end
    status = sprint(io -> Pkg.status(; io = io))
    fecha = chomp(read(`date -u +%Y-%m-%dT%H:%M:%SZ`, String))
    lineas = [
        "fecha=$fecha",
        "git_head=$git_hash",
        "julia=$(VERSION)",
        "proyecto=$(Base.active_project())",
        "hilos_julia=$(Threads.nthreads())",
        "cpu=$(Sys.CPU_NAME)",
        "cpu_hilos=$(Sys.CPU_THREADS)",
        "ram_bytes=$(Sys.total_memory())",
        "openblas_threads=$(get(ENV, "OPENBLAS_NUM_THREADS", "no_fijado"))",
        "julia_num_threads_env=$(get(ENV, "JULIA_NUM_THREADS", "no_fijado"))",
        "semilla_maestra=$(semilla_maestra)",
        "pared_seg=$(round(t1 - t0, digits = 2))",
        "cpu_seg=$(round(cpu_time_seg(), digits = 2))",
        "argv=$(join(argv, ' '))",
        "--- Pkg.status ---",
        status,
    ]
    write(joinpath(ruta_dir, "ENTORNO.txt"), join(lineas, "\n") * "\n")
    write(joinpath(ruta_dir, "RUN.txt"),
          "julia --project=. " * join(argv, ' ') * "\n")
end

# -----------------------------------------------------------------------------
# r2 (enmienda 2026-09-13): objetos del presupuesto de Q2 a 100 y 59,67 Mbit/s,
# ρ y régimen publicados, medias de llegada por bloque y por nodo (Q3), y Δ̄
# ponderada por producción bajo dos repartos de espacio. Todo es código NUEVO:
# los modos barrido/sensibilidad/escalado/caso de la r1 no cambian.
#
# IDs de combo: r1 usó 1..11; r2 usa 1001..1060 (rejilla), 1101..1104
# (concentración), 1201..1202 (t_proc=0,1 s) y 1301..1302 (control saturado).
# Como la semilla derivada es (maestra, combo, réplica), no hay colisión con la r1.
# -----------------------------------------------------------------------------

const OBJETOS_R2 = [
    ("cabecera-1p-1slot", 716.0),
    ("cabecera-4p-1slot", 812.0),
    ("anuncio-arranque-571tx", 4238.0),
    ("cabecera-peor-caso-16p-150slot", 20268.0),
    ("anuncio-techo-4464tx", 27596.0),
]
const ANCHOS_R2 = [1.0e8, 59.67e6]

struct ComboR2
    id::Int
    p::ParametrosRed
    concentracion::Bool
    objeto::String
end

struct FilaR2
    combo_id::Int
    replica::Int
    semilla::UInt64
    n_bloques::Int
    eventos::Int
    segundos::Float64
    D::Matrix{Float64}
    media_bloque::Vector{Float64}
    media_nodo::Vector{Float64}
    media_bloque_espacio::Vector{Float64}
    suma_esp_num::Float64
    suma_esp_den::Float64
    fraccion_top10::Float64
end

function correr_una_r2(rng::StableRNGs.LehmerRNG, p::ParametrosRed, concentracion::Bool)
    red = construir_red(rng, p)
    t_creacion = calendario_poisson(rng, p.lambda, p.horizonte)
    H = length(t_creacion)
    creador = if concentracion
        q, k = cuotas_concentracion(p.n)
        creadores_ponderados(rng, q, sum(q), H)
    else
        rand(rng, 1:p.n, H)
    end
    m = MotorRapido(p.n; capacidad = 64 + (p.n * p.grado + 1) * 16)
    llegada = correr!(m, red, t_creacion, creador)
    invariantes(llegada, t_creacion) || error("invariantes rotos en corrida r2")
    D = deltas_por_bloque(llegada, t_creacion; qs = QS)
    media_bloque, media_nodo = medias_llegada(llegada, t_creacion, creador)
    media_esp = Float64[]
    suma_esp_num = 0.0
    suma_esp_den = 0.0
    fraccion_top = NaN
    if concentracion
        q, k = cuotas_concentracion(p.n)
        pesos = pesos_de_cuotas(q)
        media_esp = media_bloque_espacio(llegada, t_creacion, creador, pesos)
        # regla (i): los creadores se sortean ∝ cuota → cada bloque es una unidad de
        # producción → Δ̄ = media SIMPLE de las medias ponderadas por observador. Pesar
        # además por la cuota del creador contaría la cuota dos veces (∝ cuota²).
        for mb in media_esp
            suma_esp_num += mb
            suma_esp_den += 1.0
        end
        fraccion_top = count(c -> Int(c) <= k, creador) / H
    end
    eventos = H * (length(red.g.vecinos) + 1)
    return D, media_bloque, media_nodo, media_esp, suma_esp_num, suma_esp_den,
           fraccion_top, H, eventos
end

function combos_r2_rejilla(o::Dict{String,String})
    grado = flag_int(o, "grado", 8)
    med = flag_float(o, "mediana-latencia", 0.08)
    p99 = flag_float(o, "p99-latencia", 0.5)
    lam = flag_float(o, "lambda", 1.0)
    T = flag_float(o, "horizonte", 600.0)
    combos = ComboR2[]
    id = 1001
    for (nombre, tam) in OBJETOS_R2, bw in ANCHOS_R2, topo in (:regular, :erdos_renyi),
        n in (100, 1000, 10000)
        push!(combos, ComboR2(id,
            ParametrosRed(n, topo, grado, med, p99, bw, tam, 0.0, lam, T), false, nombre))
        id += 1
    end
    return combos
end

function combos_r2_concentracion(o::Dict{String,String})
    combos = ComboR2[]
    id = 1101
    for (nombre, tam) in [("anuncio-arranque-571tx", 4238.0), ("anuncio-techo-4464tx", 27596.0)]
        for topo in (:regular, :erdos_renyi)
            push!(combos, ComboR2(id,
                ParametrosRed(1000, topo, 8, 0.08, 0.5, 1.0e8, tam, 0.0, 1.0, 600.0),
                true, nombre))
            id += 1
        end
    end
    return combos
end

function combos_r2_tproc(o::Dict{String,String})
    combos = ComboR2[]
    id = 1201
    for topo in (:regular, :erdos_renyi)
        push!(combos, ComboR2(id,
            ParametrosRed(1000, topo, 8, 0.08, 0.5, 1.0e8, 4238.0, 0.1, 1.0, 600.0),
            false, "anuncio-arranque-571tx-tproc01"))
        id += 1
    end
    return combos
end

function combos_r2_saturacion(o::Dict{String,String})
    combos = ComboR2[]
    id = 1301
    for T in (300.0, 600.0)
        push!(combos, ComboR2(id,
            ParametrosRed(1000, :regular, 8, 0.08, 0.5, 1.0e8, 1563212.0, 0.0, 1.0, T),
            false, "bloque-techo-4464tx"))
        id += 1
    end
    return combos
end

function ejecutar_r2(combos::Vector{ComboR2}, replicas::Int, semilla_maestra::UInt64)
    trabajos = Tuple{Int,Int}[]
    for (ci, c) in enumerate(combos), r in 1:replicas
        push!(trabajos, (ci, r))
    end
    sort!(trabajos; by = t -> -combos[t[1]].p.n)
    filas = Vector{Union{FilaR2,Nothing}}(nothing, length(trabajos))
    Threads.@threads for i in eachindex(trabajos)
        ci, r = trabajos[i]
        combo = combos[ci]
        semilla = semilla_derivada(semilla_maestra, UInt64(combo.id), UInt64(r))
        rng = StableRNG(semilla)
        t0 = time()
        D, mb, mn, me, sn, sd, ft, H, ev = correr_una_r2(rng, combo.p, combo.concentracion)
        filas[i] = FilaR2(combo.id, r, semilla, H, ev, time() - t0, D, mb, mn, me, sn, sd, ft)
    end
    return [f for f in filas if f !== nothing]
end

function agregar_r2(combos::Vector{ComboR2}, filas::Vector{FilaR2})
    idx = Dict(c.id => i for (i, c) in enumerate(combos))
    por_combo = [FilaR2[] for _ in combos]
    for f in filas
        push!(por_combo[idx[f.combo_id]], f)
    end
    for fs in por_combo
        sort!(fs; by = f -> f.replica)
    end
    return por_combo
end

function encabezado_corridas_r2()
    fijos = ["combo_id", "objeto", "topologia", "n", "grado", "mediana_latencia_s",
             "p99_latencia_s", "ancho_banda_bps", "tam_bloque_B", "retardo_procesado_s",
             "lambda_1_s", "horizonte_s", "rho", "regimen", "replica", "semilla",
             "n_bloques", "eventos", "segundos_pared", "fraccion_creadores_top10",
             "delta_barra_s", "delta_barra_espacio_s"]
    qcols = ["$(s)_$(qn)_s" for qn in NOMBRES_Q for s in ESTADISTICOS]
    return vcat(fijos, qcols)
end

function fila_corrida_r2(c::ComboR2, f::FilaR2)
    p = c.p
    rho = utilizacion(p)
    reg = regimen(rho)
    db = sum(f.media_bloque) / f.n_bloques
    dbe = f.suma_esp_den > 0 ? f.suma_esp_num / f.suma_esp_den : NaN
    ft = f.fraccion_top10
    base = Any[c.id, c.objeto, string(p.topologia), p.n, p.grado, p.mediana_latencia,
               p.p99_latencia, p.ancho_banda, p.tam_bloque, p.retardo_procesado, p.lambda,
               p.horizonte, rho, reg, f.replica, f.semilla, f.n_bloques, f.eventos,
               f.segundos, isnan(ft) ? "" : ft, db, isnan(dbe) ? "" : dbe]
    vals = Float64[]
    for j in 1:length(QS)
        w = sort(f.D[:, j])
        m = length(w)
        push!(vals, w[cld(50 * m, 100)], w[cld(90 * m, 100)], w[cld(99 * m, 100)], w[m])
    end
    return vcat(base, vals)
end

function encabezado_resumen_r2()
    fijos = ["combo_id", "objeto", "topologia", "n", "grado", "mediana_latencia_s",
             "p99_latencia_s", "ancho_banda_bps", "tam_bloque_B", "retardo_procesado_s",
             "lambda_1_s", "horizonte_s", "rho", "regimen", "n_corridas",
             "n_bloques_total", "eventos_total", "delta_barra_s", "delta_barra_espacio_s"]
    qcols = ["$(s)_$(qn)_s" for qn in NOMBRES_Q for s in ESTADISTICOS]
    return vcat(fijos, qcols)
end

function fila_resumen_r2(c::ComboR2, fs::Vector{FilaR2})
    p = c.p
    rho = utilizacion(p)
    reg = regimen(rho)
    total_bloques = sum(f -> f.n_bloques, fs)
    db = sum(f -> sum(f.media_bloque), fs) / total_bloques
    dbe = sum(f -> f.suma_esp_den, fs) > 0 ?
          sum(f -> f.suma_esp_num, fs) / sum(f -> f.suma_esp_den, fs) : NaN
    base = Any[c.id, c.objeto, string(p.topologia), p.n, p.grado, p.mediana_latencia,
               p.p99_latencia, p.ancho_banda, p.tam_bloque, p.retardo_procesado, p.lambda,
               p.horizonte, rho, reg, length(fs), total_bloques,
               sum(f -> f.eventos, fs), db, isnan(dbe) ? "" : dbe]
    vals = Float64[]
    for j in 1:length(QS)
        pool = Float64[]
        for f in fs
            append!(pool, f.D[:, j])
        end
        w = sort(pool)
        m = length(w)
        push!(vals, w[cld(50 * m, 100)], w[cld(90 * m, 100)], w[cld(99 * m, 100)], w[m])
    end
    return vcat(base, vals)
end

function escribir_medias_r2(ruta::String, c::ComboR2, fs::Vector{FilaR2})
    io_b = open(joinpath(ruta, "medias_bloque-$(c.id).csv"), "w")
    write(io_b, "replica,bloque,media_s\n")
    io_n = open(joinpath(ruta, "medias_nodo-$(c.id).csv"), "w")
    write(io_n, "replica,nodo,media_us\n")
    io_e = nothing
    if c.concentracion
        io_e = open(joinpath(ruta, "media_bloque_espacio-$(c.id).csv"), "w")
        write(io_e, "replica,bloque,media_s\n")
    end
    for f in fs
        for (b, v) in enumerate(f.media_bloque)
            write(io_b, "$(f.replica),$b,$(@sprintf("%.9f", v))\n")
        end
        for (v, x) in enumerate(f.media_nodo)
            if isfinite(x)
                write(io_n, "$(f.replica),$v,$(round(Int, x * 1.0e6))\n")
            else
                write(io_n, "$(f.replica),$v,\n")
            end
        end
        if io_e !== nothing
            for (b, v) in enumerate(f.media_bloque_espacio)
                write(io_e, "$(f.replica),$b,$(@sprintf("%.9f", v))\n")
            end
        end
    end
    close(io_b)
    close(io_n)
    io_e !== nothing && close(io_e)
    return nothing
end

function principal_r2(combos::Vector{ComboR2}, replicas::Int, semilla_maestra::UInt64,
                      subdir::String, argv::Vector{String})
    t0 = time()
    println("modo=r2 subtarea=$subdir combos=$(length(combos)) replicas=$replicas " *
            "hilos=$(Threads.nthreads()) semilla=0x$(string(semilla_maestra, base=16))")
    filas = ejecutar_r2(combos, replicas, semilla_maestra)
    por_combo = agregar_r2(combos, filas)
    orden = sortperm(combos; by = c -> (c.p.n, string(c.p.topologia), c.p.grado,
                                        c.p.mediana_latencia, c.p.ancho_banda,
                                        c.p.tam_bloque, c.p.retardo_procesado))
    ruta = joinpath(@__DIR__, "resultados", subdir)
    mkpath(ruta)
    io_c = open(joinpath(ruta, "corridas.csv"), "w")
    write(io_c, linea_csv(encabezado_corridas_r2()) * "\n")
    for i in orden
        for f in por_combo[i]
            write(io_c, linea_csv(fila_corrida_r2(combos[i], f)) * "\n")
        end
    end
    close(io_c)
    io_r = open(joinpath(ruta, "resumen.csv"), "w")
    write(io_r, linea_csv(encabezado_resumen_r2()) * "\n")
    for i in orden
        write(io_r, linea_csv(fila_resumen_r2(combos[i], por_combo[i])) * "\n")
    end
    close(io_r)
    for i in orden
        escribir_medias_r2(ruta, combos[i], por_combo[i])
    end
    t1 = time()
    escribir_entorno(ruta, semilla_maestra, argv, t0, t1)
    println("--- resumen (segundos) ---")
    for i in orden
        c = combos[i]
        p = c.p
        r = fila_resumen_r2(c, por_combo[i])
        rho = utilizacion(p)
        print(rpad("$(c.id) $(c.objeto) $(string(p.topologia)) n=$(p.n)", 58))
        println("rho=$(round(rho, digits=4)) ($(regimen(rho))) " *
                "db=$(round(r[18], digits=4)) " *
                "d50_med=$(round(r[20], digits=3)) d99_p99=$(round(r[30], digits=3)) " *
                "d100_med=$(round(r[32], digits=3))")
        if regimen(rho) == "saturado"
            println("  AVISO: saturado — sus cuantiles NO se publican como Δ (evidencia de cola no estacionaria)")
        end
    end
    println("pared_total_seg=$(round(t1 - t0, digits=2)) salida=$(ruta)")
end

# -----------------------------------------------------------------------------
# principal
# -----------------------------------------------------------------------------

function main()
    argv = ARGS
    o = parse_args(argv)
    modo = get(o, "modo", "barrido")
    t0 = time()
    semilla_maestra = UInt64(flag_int(o, "semilla", 0x5A5A))
    replicas = flag_int(o, "replicas", 12)

    if modo == "r2"
        subtarea = get(o, "r2-subtarea", "rejilla")
        if subtarea == "rejilla"
            combos_r2 = combos_r2_rejilla(o)
            subdir_r2 = "r2-rejilla"
        elseif subtarea == "concentracion"
            combos_r2 = combos_r2_concentracion(o)
            subdir_r2 = "r2-concentracion"
        elseif subtarea == "tproc"
            combos_r2 = combos_r2_tproc(o)
            subdir_r2 = "r2-tproc"
        elseif subtarea == "saturacion"
            combos_r2 = combos_r2_saturacion(o)
            subdir_r2 = "r2-saturacion"
        else
            error("r2-subtarea desconocida: $subtarea")
        end
        principal_r2(combos_r2, replicas, semilla_maestra, subdir_r2, argv)
        return
    end

    if modo == "barrido"
        combos = combos_barrido(o)
        subdir = "barrido-principal"
    elseif modo == "sensibilidad"
        combos = combos_sensibilidad(o)
        subdir = "sensibilidad"
    elseif modo == "escalado"
        combos = combos_escalado(o)
        replicas = flag_int(o, "replicas", 24)
        subdir = "escalado"
    elseif modo == "caso"
        combos = combos_caso(o)
        replicas = flag_int(o, "replicas", 1)
        subdir = "caso"
    else
        error("modo desconocido: $modo")
    end

    println("modo=$modo combos=$(length(combos)) replicas=$replicas " *
            "hilos=$(Threads.nthreads()) semilla=0x$(string(semilla_maestra, base=16))")

    filas = ejecutar(combos, replicas, semilla_maestra)
    por_combo = agregar(combos, filas)
    orden = sortperm(combos; by = c -> (c.p.n, string(c.p.topologia), c.p.grado,
                                        c.p.mediana_latencia, c.p.ancho_banda,
                                        c.p.tam_bloque, c.p.retardo_procesado))

    ruta = joinpath(@__DIR__, "resultados", subdir)
    mkpath(ruta)
    io_c = open(joinpath(ruta, "corridas.csv"), "w")
    write(io_c, linea_csv(encabezado_corridas()) * "\n")
    for i in orden
        for f in por_combo[i]
            write(io_c, linea_csv(fila_corrida(combos[i], f)) * "\n")
        end
    end
    close(io_c)

    io_r = open(joinpath(ruta, "resumen.csv"), "w")
    write(io_r, linea_csv(encabezado_resumen()) * "\n")
    for i in orden
        write(io_r, linea_csv(fila_resumen(combos[i], por_combo[i])) * "\n")
    end
    close(io_r)

    t1 = time()
    escribir_entorno(ruta, semilla_maestra, argv, t0, t1)

    println("--- resumen (segundos) ---")
    for i in orden
        c = combos[i]
        fs = por_combo[i]
        p = c.p
        r = fila_resumen(c, fs)
        print(rpad("combo $(c.id) $(string(p.topologia)) n=$(p.n)", 34))
        for j in 1:length(QS)
            qn = NOMBRES_Q[j]
            k0 = 15 + 4 * (j - 1)
            print(" $qn: med=$(round(r[k0], digits=3)) p90=$(round(r[k0+1], digits=3)) " *
                  "p99=$(round(r[k0+2], digits=3))")
        end
        println()
    end
    println("pared_total_seg=$(round(t1 - t0, digits=2)) salida=$(ruta)")
end

main()
