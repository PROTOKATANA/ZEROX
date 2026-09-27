# rapido.jl — kernel tipado: percentiles nearest-rank, latencias, divergencia y demás métricas
#
# Todas las funciones trabajan sobre `Vector{Evento}` concretos (LINEO §3.1) y devuelven filas
# tipadas. El oráculo equivalente está en `referencia.jl`.

# ---------------------------------------------------------------------------
# Percentil nearest-rank sobre muestra ordenada (ORDEN §3.3). Sólo enteros.
# ---------------------------------------------------------------------------
@inline function percentil_ordenado(v::AbstractVector{<:Integer}, p::Integer)
    n = length(v)
    n == 0 && return missing
    (1 <= p <= 100) || throw(ArgumentError("p debe estar en 1..100, recibido $p"))
    r = div(p * n + 99, 100)          # ceil(p/100 * n) exacto en enteros
    @inbounds return Int64(v[r])
end

# (n, p50, p95, max) de una muestra entera
function distribucion_entera(v::AbstractVector{<:Integer})
    n = length(v)
    n == 0 && return (0, missing, missing, missing)
    s = sort(v)
    return (n, percentil_ordenado(s, 50), percentil_ordenado(s, 95), Int64(s[n]))
end

# (n, p50, p95, max) de una muestra real (sólo para ratios/recursos; nunca decide un umbral)
function distribucion_real(v::AbstractVector{<:Real})
    n = length(v)
    n == 0 && return (0, missing, missing, missing)
    s = sort(Float64.(v))
    r50 = div(50 * n + 99, 100)
    r95 = div(95 * n + 99, 100)
    return (n, s[r50], s[r95], s[n])
end

# ---------------------------------------------------------------------------
# Filas de salida
# ---------------------------------------------------------------------------
struct FilaEntera
    metrica::String
    ambito::String
    n::Int
    ausentes::Int
    p50::Union{Missing,Int64}
    p95::Union{Missing,Int64}
    max::Union{Missing,Int64}
    unidad::String
end

struct FilaReal
    metrica::String
    ambito::String
    n::Int
    ausentes::Int
    p50::Union{Missing,Float64}
    p95::Union{Missing,Float64}
    max::Union{Missing,Float64}
    unidad::String
end

struct FilaLatencia
    nodo_a::String
    nodo_b::String
    producidos::Int
    admitidos::Int
    no_admitidos::Int
    negativos::Int
    n::Int
    p50::Union{Missing,Int64}
    p95::Union{Missing,Int64}
    max::Union{Missing,Int64}
end

struct FilaTramo
    desde::Int
    hasta::Int
    n::Int
    p50::Union{Missing,Int64}
    p95::Union{Missing,Int64}
    max::Union{Missing,Int64}
end

struct FilaRechazo
    etapa::String
    motivo::String
    n::Int
    p50::Union{Missing,Int64}
    p95::Union{Missing,Int64}
    max::Union{Missing,Int64}
end

# W07c-B: hallazgo cuantificado (contador de bloques con información inconsistente, etc.).
struct FilaHallazgo
    hallazgo::String
    detalle::String
    n::Int
end

struct FilaConvergencia
    inicio_pared_ns::Int64
    duracion_ns::Int64
    truncada::Bool
end

# ---------------------------------------------------------------------------
# Procedencia
# ---------------------------------------------------------------------------
struct ResumenNodo
    nombre::String
    ruta::String
    sha256::String
    lineas::Int
    truncadas::Int
    version::String
    eventos::Vector{Evento}
end

struct RecursoNodo
    nombre::String
    ruta::String
    sha256::String
    muestras::Vector{MuestraRecurso}
end

struct Procedencia
    julia_version::String
    julia_threads_default::Int
    julia_threads_interactive::Int
    cpu::String
    manifest_sha256::String
    ejecucion::String
    nodos::Vector{String}
    nodos_info::Vector{ResumenNodo}
    recursos::Vector{RecursoNodo}
    clk_tck::Int
    clk_tck_origen::String
    modelo::String
    comando::String
end

struct Resultado
    filas_enteras::Vector{FilaEntera}
    filas_reales::Vector{FilaReal}
    latencias::Vector{FilaLatencia}
    tramos::Vector{FilaTramo}
    rechazos::Vector{FilaRechazo}
    hallazgos::Vector{FilaHallazgo}
    convergencia::Vector{FilaConvergencia}
    divergencia_fraccion::Union{Missing,Float64}
    divergencia_medida::Bool
    estado_final_igual::Union{Missing,Bool}
    estado_final_detalle::Vector{Tuple{String,String}}
    duplicados_produccion::Int
    procedencia::Procedencia
end

# ---------------------------------------------------------------------------
# Latencias de propagación A -> B (ORDEN §3.4, faltas 1 y 2)
# ---------------------------------------------------------------------------
function calcular_latencias(resumenes::Vector{ResumenNodo}, filas::Vector{FilaLatencia})
    n = length(resumenes)
    # producción/admisión más temprana por (nodo, hash); se cuentan duplicados
    prod = [Dict{Int32,Int64}() for _ in 1:n]
    adm  = [Dict{Int32,Int64}() for _ in 1:n]
    duplicados = 0
    for i in 1:n
        for ev in resumenes[i].eventos
            if ev.tipo == T_BLOQUE_PRODUCIDO || ev.tipo == T_BLOQUE_MINADO
                ev.hash == 0 && continue
                if haskey(prod[i], ev.hash)
                    duplicados += 1
                    ev.pared < prod[i][ev.hash] && (prod[i][ev.hash] = ev.pared)
                else
                    prod[i][ev.hash] = ev.pared
                end
            elseif ev.tipo == T_BLOQUE_RED_ADMITIDO
                ev.hash == 0 && continue
                if haskey(adm[i], ev.hash)
                    ev.pared < adm[i][ev.hash] && (adm[i][ev.hash] = ev.pared)
                else
                    adm[i][ev.hash] = ev.pared
                end
            end
        end
    end

    muestras_total = Int64[]
    for ia in 1:n
        for ib in 1:n
            ia == ib && continue
            muestras = Int64[]
            no_adm = 0
            neg = 0
            for (h, p) in prod[ia]
                if haskey(adm[ib], h)
                    lat = adm[ib][h] - p
                    lat < 0 && (neg += 1)
                    push!(muestras, lat)
                else
                    no_adm += 1
                end
            end
            append!(muestras_total, muestras)
            ne, p50, p95, mx = distribucion_entera(muestras)
            push!(filas, FilaLatencia(
                resumenes[ia].nombre, resumenes[ib].nombre,
                length(prod[ia]), length(prod[ia]) - no_adm, no_adm, neg,
                ne, p50, p95, mx,
            ))
        end
    end
    return muestras_total, duplicados
end

# ---------------------------------------------------------------------------
# Divergencia (ORDEN §3.5, falta 5): barrido O(E log E) sobre los `cambio_punta`
# ---------------------------------------------------------------------------
function calcular_divergencia(resumenes::Vector{ResumenNodo})
    n = length(resumenes)
    # (pared, reloj_ns, linea, punta) por nodo, ordenados
    cambios = [Tuple{Int64,Int64,Int32,Int32}[] for _ in 1:n]
    fin = fill(NODATO, n)
    for i in 1:n
        for ev in resumenes[i].eventos
            ev.pared > fin[i] && (fin[i] = ev.pared)
            if ev.tipo == T_CAMBIO_PUNTA
                push!(cambios[i], (ev.pared, ev.reloj_ns, ev.linea, ev.punta))
            end
        end
        sort!(cambios[i])
    end
    participan = [i for i in 1:n if !isempty(cambios[i]) && fin[i] != NODATO]
    length(participan) >= 2 || return (missing, FilaConvergencia[], false)
    t0 = maximum(cambios[i][1][1] for i in participan)
    t1 = minimum(fin[i] for i in participan)
    t0 < t1 || return (missing, FilaConvergencia[], false)

    # eventos con t0 < pared <= t1
    todos = Tuple{Int64,Int64,Int32,Int32,Int}[]
    for i in participan, c in cambios[i]
        if t0 < c[1] <= t1
            push!(todos, (c[1], c[2], c[3], c[4], i))
        end
    end
    sort!(todos; by = x -> (x[1], x[2], x[3]))

    estado = Dict{Int,Int32}()
    for i in participan
        p = Int32(0)
        for c in cambios[i]
            c[1] <= t0 || break
            p = c[4]
        end
        estado[i] = p
    end
    iguales() = begin
        ref = estado[participan[1]]
        for k in 2:length(participan)
            estado[participan[k]] == ref || return false
        end
        return true
    end

    div_ns = Int64(0)
    episodios = FilaConvergencia[]
    estado_div = false
    ini = Int64(0)
    prev = t0
    i = 1
    m = length(todos)
    while i <= m
        t = todos[i][1]
        if iguales()
            if estado_div
                push!(episodios, FilaConvergencia(ini, prev - ini, false))
                estado_div = false
            end
        else
            div_ns += t - prev
            if !estado_div
                ini = prev
                estado_div = true
            end
        end
        while i <= m && todos[i][1] == t
            estado[todos[i][5]] = todos[i][4]
            i += 1
        end
        prev = t
    end
    if iguales()
        if estado_div
            push!(episodios, FilaConvergencia(ini, prev - ini, false))
            estado_div = false
        end
    else
        div_ns += t1 - prev
        if !estado_div
            ini = prev
            estado_div = true
        end
    end
    estado_div && push!(episodios, FilaConvergencia(ini, t1 - ini, true))
    return (div_ns / (t1 - t0), episodios, true)
end

# ---------------------------------------------------------------------------
# Tiempos por etapa (ESQUEMA §3) sobre `bloque_red_admitido`
# ---------------------------------------------------------------------------
function calcular_etapas(resumenes::Vector{ResumenNodo}, enteras::Vector{FilaEntera})
    campos = (
        ("t_cabecera_ns",     (ev -> ev.t_cabecera_ns)),
        ("t_admision_ns",     (ev -> ev.t_admision_ns)),
        ("t_persistencia_ns", (ev -> ev.t_persistencia_ns)),
        ("t_total_ns",        (ev -> ev.t_total_ns)),
    )
    for (nombre, getter) in campos
        vals = Int64[]
        ausentes = 0
        for r in resumenes, ev in r.eventos
            ev.tipo == T_BLOQUE_RED_ADMITIDO || continue
            v = getter(ev)
            if v == NODATO
                ausentes += 1
            else
                push!(vals, v)
            end
        end
        ne, p50, p95, mx = distribucion_entera(vals)
        push!(enteras, FilaEntera(nombre, "todos", ne, ausentes, p50, p95, mx, "ns"))
    end
end

# ---------------------------------------------------------------------------
# Admisión frente a n_bloques_dag, tramos de 500 (ESQUEMA §3, ORDEN §3.6, falta 6)
# ---------------------------------------------------------------------------
function calcular_admision_profundidad(resumenes::Vector{ResumenNodo}, tramos::Vector{FilaTramo})
    grupos = Dict{Int,Vector{Int64}}()
    for r in resumenes, ev in r.eventos
        ev.tipo == T_BLOQUE_RED_ADMITIDO || continue
        (ev.t_admision_ns == NODATO || ev.n_bloques_dag == NODATO) && continue
        k = fld(ev.n_bloques_dag, 500)
        push!(get!(grupos, k, Int64[]), ev.t_admision_ns)
    end
    for k in sort(collect(keys(grupos)))
        ne, p50, p95, mx = distribucion_entera(grupos[k])
        push!(tramos, FilaTramo(500 * k, 500 * k + 499, ne, p50, p95, mx))
    end
end

# ---------------------------------------------------------------------------
# Bloques por slot, padres por bloque, fracción de rojos (ESQUEMA §3)
#
# W07c-B: cada bloque se cuenta UNA vez por `hash` (no una vez por nodo/evento). El valor
# canónico de `slot`/`n_padres`/`(azules,rojos)` es el del evento más temprano por
# `(reloj_pared_ns, reloj_ns, nº de línea)`, para que no dependa del orden de los nodos. Si dos
# eventos del mismo bloque traen valores distintos, se cuenta como hallazgo (no se imputa).
# `bloques_por_slot` incluye TODOS los slots del intervalo `[mín,máx]`, también los de 0 bloques.
# ---------------------------------------------------------------------------
mutable struct _CanonBloque
    slot::Int64
    slot_pared::Int64
    slot_reloj::Int64
    slot_linea::Int32
    slot_ok::Bool
    slot_disc::Bool
    padres::Int64
    padres_pared::Int64
    padres_reloj::Int64
    padres_linea::Int32
    padres_ok::Bool
    padres_disc::Bool
    azules::Int64
    rojos::Int64
    mergeset_pared::Int64
    mergeset_reloj::Int64
    mergeset_linea::Int32
    mergeset_ok::Bool
    mergeset_disc::Bool
end

_CanonBloque() = _CanonBloque(
    NODATO, NODATO, NODATO, Int32(0), false, false,
    NODATO, NODATO, NODATO, Int32(0), false, false,
    NODATO, NODATO, NODATO, NODATO, Int32(0), false, false,
)

@inline function _antes_que(pared::Int64, reloj::Int64, linea::Int32,
                            bp::Int64, br::Int64, bl::Int32)
    pared < bp && return true
    pared > bp && return false
    reloj < br && return true
    reloj > br && return false
    return linea < bl
end

# Distribución de «bloques por slot» cuando hay `nslots` slots en el intervalo y solo `vals`
# (todos > 0) tienen bloques: el resto son ceros, computados sin materializar el vector.
function _distribucion_slots(vals::Vector{Int}, nslots::Int)
    nslots == 0 && return (0, missing, missing, missing)
    s = sort(vals)
    z = nslots - length(s)
    r50 = div(50 * nslots + 99, 100)
    r95 = div(95 * nslots + 99, 100)
    f(r) = r <= z ? Int64(0) : Int64(s[r - z])
    return (nslots, f(r50), f(r95), f(nslots))
end

function calcular_bloques_padres_rojos(resumenes::Vector{ResumenNodo}, enteras::Vector{FilaEntera},
                                       reales::Vector{FilaReal}, hallazgos::Vector{FilaHallazgo})
    # primera pasada: valor canónico (más temprano) por hash
    bloques = Dict{Int32,_CanonBloque}()
    eventos_sin_hash = 0
    for r in resumenes, ev in r.eventos
        (ev.tipo == T_BLOQUE_PRODUCIDO || ev.tipo == T_BLOQUE_RED_ADMITIDO) || continue
        if ev.hash == 0
            eventos_sin_hash += 1
            continue
        end
        c = get!(_CanonBloque, bloques, ev.hash)
        if ev.slot != NODATO &&
           (!c.slot_ok || _antes_que(ev.pared, ev.reloj_ns, ev.linea,
                                     c.slot_pared, c.slot_reloj, c.slot_linea))
            c.slot = ev.slot
            c.slot_pared = ev.pared; c.slot_reloj = ev.reloj_ns; c.slot_linea = ev.linea
            c.slot_ok = true
        end
        if ev.n_padres != NODATO &&
           (!c.padres_ok || _antes_que(ev.pared, ev.reloj_ns, ev.linea,
                                       c.padres_pared, c.padres_reloj, c.padres_linea))
            c.padres = ev.n_padres
            c.padres_pared = ev.pared; c.padres_reloj = ev.reloj_ns; c.padres_linea = ev.linea
            c.padres_ok = true
        end
        if ev.azules != NODATO && ev.rojos != NODATO &&
           (!c.mergeset_ok || _antes_que(ev.pared, ev.reloj_ns, ev.linea,
                                         c.mergeset_pared, c.mergeset_reloj, c.mergeset_linea))
            c.azules = ev.azules; c.rojos = ev.rojos
            c.mergeset_pared = ev.pared; c.mergeset_reloj = ev.reloj_ns; c.mergeset_linea = ev.linea
            c.mergeset_ok = true
        end
    end
    # segunda pasada: discrepancia respecto del canónico (mismo hash, valor distinto)
    for r in resumenes, ev in r.eventos
        (ev.tipo == T_BLOQUE_PRODUCIDO || ev.tipo == T_BLOQUE_RED_ADMITIDO) || continue
        ev.hash == 0 && continue
        c = bloques[ev.hash]
        ev.slot != NODATO && ev.slot != c.slot && (c.slot_disc = true)
        ev.n_padres != NODATO && ev.n_padres != c.padres && (c.padres_disc = true)
        if ev.azules != NODATO && ev.rojos != NODATO &&
           (ev.azules != c.azules || ev.rojos != c.rojos)
            c.mergeset_disc = true
        end
    end

    sin_slot = 0; sin_padres = 0; sin_mergeset = 0
    disc_slot = 0; disc_padres = 0; disc_mergeset = 0
    por_slot = Dict{Int64,Int}()
    padres = Int64[]
    suma_azules = 0; suma_rojos = 0
    for c in values(bloques)
        if c.slot_ok
            por_slot[c.slot] = get(por_slot, c.slot, 0) + 1
        else
            sin_slot += 1
        end
        if c.padres_ok
            push!(padres, c.padres)
        else
            sin_padres += 1
        end
        if c.mergeset_ok
            suma_azules += c.azules
            suma_rojos += c.rojos
        else
            sin_mergeset += 1
        end
        c.slot_disc && (disc_slot += 1)
        c.padres_disc && (disc_padres += 1)
        c.mergeset_disc && (disc_mergeset += 1)
    end

    if isempty(por_slot)
        push!(enteras, FilaEntera("bloques_por_slot", "todos", 0, sin_slot,
                                  missing, missing, missing, "bloques/slot"))
        push!(reales, FilaReal("media_bloques_por_slot", "todos", 0, sin_slot,
                               missing, missing, missing, "bloques/slot"))
    else
        vmin = minimum(keys(por_slot))
        vmax = maximum(keys(por_slot))
        nslots = Int(vmax - vmin + 1)
        conteos = collect(values(por_slot))
        ne, p50, p95, mx = _distribucion_slots(conteos, nslots)
        push!(enteras, FilaEntera("bloques_por_slot", "todos", ne, sin_slot, p50, p95, mx, "bloques/slot"))
        media = sum(conteos) / nslots
        push!(reales, FilaReal("media_bloques_por_slot", "todos", 1, 0, media, media, media, "bloques/slot"))
    end

    ne, p50, p95, mx = distribucion_entera(padres)
    push!(enteras, FilaEntera("padres_por_bloque", "todos", ne, sin_padres, p50, p95, mx, "padres"))

    if suma_azules + suma_rojos > 0
        f = suma_rojos / (suma_azules + suma_rojos)
        push!(reales, FilaReal("fraccion_rojos", "todos", 1, sin_mergeset, f, f, f, "fraccion"))
    else
        push!(reales, FilaReal("fraccion_rojos", "todos", 0, sin_mergeset, missing, missing, missing, "fraccion"))
    end

    push!(hallazgos, FilaHallazgo("slot_distinto_por_bloque",
        "bloques cuyo slot difiere entre sus eventos", disc_slot))
    push!(hallazgos, FilaHallazgo("padres_distintos_por_bloque",
        "bloques cuyo n_padres difiere entre sus eventos", disc_padres))
    push!(hallazgos, FilaHallazgo("mergeset_distinto_por_bloque",
        "bloques cuyo par (azules,rojos) difiere entre sus eventos", disc_mergeset))
    push!(hallazgos, FilaHallazgo("eventos_bloque_sin_hash",
        "eventos bloque_producido/bloque_red_admitido sin hash (no identificables)", eventos_sin_hash))
end

# ---------------------------------------------------------------------------
# Rechazos por etapa y motivo; coste hasta el rechazo (ESQUEMA §3, ORDEN §3.6)
# ---------------------------------------------------------------------------
function calcular_rechazos(resumenes::Vector{ResumenNodo}, rechazos::Vector{FilaRechazo},
                           pool::PoolCadenas)
    conteo = Dict{Tuple{UInt8,Int32},Int}()
    costes = Dict{Tuple{UInt8,Int32},Vector{Int64}}()
    for r in resumenes, ev in r.eventos
        ev.tipo == T_BLOQUE_RED_RECHAZADO || continue
        clave = (ev.etapa, ev.motivo)
        conteo[clave] = get(conteo, clave, 0) + 1
        if ev.t_hasta_rechazo_ns != NODATO
            push!(get!(costes, clave, Int64[]), ev.t_hasta_rechazo_ns)
        end
    end
    for clave in sort(collect(keys(conteo)); by = c -> (Int(c[1]), c[2]))
        vals = get(costes, clave, Int64[])
        ne, p50, p95, mx = distribucion_entera(vals)
        push!(rechazos, FilaRechazo(
            clave[1] == 0x00 ? "(ausente)" : get(NOMBRES_ETAPA, clave[1], "(desconocida)"),
            clave[2] == 0 ? "(ausente)" : cadena(pool, clave[2]),
            conteo[clave], p50, p95, mx,
        ))
    end
end

# ---------------------------------------------------------------------------
# Profundidad de reorganización (ESQUEMA §3)
# ---------------------------------------------------------------------------
function calcular_reorg(resumenes::Vector{ResumenNodo}, enteras::Vector{FilaEntera})
    vals = Int64[]
    ausentes = 0
    candidatos = 0
    for r in resumenes, ev in r.eventos
        if ev.tipo == T_CAMBIO_PUNTA
            candidatos += 1
            if ev.profundidad_reorg == NODATO
                ausentes += 1
            else
                push!(vals, ev.profundidad_reorg)
            end
        elseif ev.tipo == T_REORGANIZACION_POW
            candidatos += 1
            if ev.profundidad_pow == NODATO
                ausentes += 1
            else
                push!(vals, ev.profundidad_pow)
            end
        end
    end
    ne, p50, p95, mx = distribucion_entera(vals)
    push!(enteras, FilaEntera("profundidad_reorg", "todos", ne, ausentes, p50, p95, mx, "bloques"))
end

# ---------------------------------------------------------------------------
# Estado final (último resumen_estado por nodo) y duración de arranque/reinicio
# ---------------------------------------------------------------------------
function calcular_estado_final(resumenes::Vector{ResumenNodo})
    ids = Int32[]
    for r in resumenes
        mejor_pared = NODATO
        mejor_reloj = NODATO
        mejor_linea = Int32(-1)
        rid = Int32(0)
        for ev in r.eventos
            ev.tipo == T_CAMBIO_PUNTA && ev.resumen != 0 || continue
            if ev.pared > mejor_pared ||
               (ev.pared == mejor_pared && ev.reloj_ns > mejor_reloj) ||
               (ev.pared == mejor_pared && ev.reloj_ns == mejor_reloj && ev.linea > mejor_linea)
                mejor_pared = ev.pared
                mejor_reloj = ev.reloj_ns
                mejor_linea = ev.linea
                rid = ev.resumen
            end
        end
        push!(ids, rid)
    end
    # nombres primero para el detalle
    return ids
end

function calcular_arranque(resumenes::Vector{ResumenNodo}, enteras::Vector{FilaEntera})
    vals = Int64[]
    ausentes = 0
    for r in resumenes
        ini = NODATO
        lim = NODATO
        for ev in r.eventos
            ev.tipo == T_ARRANQUE || continue
            if ev.fase == FASE_INICIO && ini == NODATO
                ini = ev.pared
            elseif ev.fase == FASE_LIMPIO && lim == NODATO
                lim = ev.pared
            end
        end
        if ini != NODATO && lim != NODATO && lim >= ini
            push!(vals, lim - ini)
        else
            ausentes += 1
        end
    end
    ne, p50, p95, mx = distribucion_entera(vals)
    push!(enteras, FilaEntera("arranque_ns", "todos", ne, ausentes, p50, p95, mx, "ns"))

    vals2 = Int64[]
    ausentes2 = 0
    for r in resumenes, ev in r.eventos
        ev.tipo == T_REINICIO_COMPLETO || continue
        if ev.duracion_ns == NODATO
            ausentes2 += 1
        else
            push!(vals2, ev.duracion_ns)
        end
    end
    ne, p50, p95, mx = distribucion_entera(vals2)
    push!(enteras, FilaEntera("duracion_reinicio_ns", "todos", ne, ausentes2, p50, p95, mx, "ns"))
end

# ---------------------------------------------------------------------------
# Recursos por nodo desde el CSV (ESQUEMA §2, ORDEN §3.6, falta 7)
# ---------------------------------------------------------------------------
function calcular_recursos(recursos::Vector{RecursoNodo}, clk_tck::Int,
                           enteras::Vector{FilaEntera}, reales::Vector{FilaReal})
    for r in recursos
        m = r.muestras
        cpu = Float64[]
        rss = Int64[]
        rb = Int64[]
        wb = Int64[]
        for k in 1:(length(m)-1)
            a = m[k]
            b = m[k+1]
            dp = b.pared - a.pared
            dp <= 0 && continue
            push!(cpu, ((b.utime + b.stime) - (a.utime + a.stime)) / clk_tck / (dp / 1.0e9))
            push!(rb, b.read_bytes - a.read_bytes)
            push!(wb, b.write_bytes - a.write_bytes)
        end
        for s in m
            push!(rss, s.rss_kib)
        end
        ne, p50, p95, mx = distribucion_real(cpu)
        push!(reales, FilaReal("cpu_util", r.nombre, ne, length(m) < 2 ? 1 : 0, p50, p95, mx, "s/s"))
        ne, p50, p95, mx = distribucion_entera(rss)
        push!(enteras, FilaEntera("rss_kib", r.nombre, ne, 0, p50, p95, mx, "KiB"))
        ne, p50, p95, mx = distribucion_entera(rb)
        push!(enteras, FilaEntera("read_bytes_intervalo", r.nombre, ne, 0, p50, p95, mx, "bytes"))
        ne, p50, p95, mx = distribucion_entera(wb)
        push!(enteras, FilaEntera("write_bytes_intervalo", r.nombre, ne, 0, p50, p95, mx, "bytes"))
        if !isempty(m)
            d = m[end].disco
            push!(enteras, FilaEntera("disco_datos_bytes", r.nombre, 1, 0, d, d, d, "bytes"))
        else
            push!(enteras, FilaEntera("disco_datos_bytes", r.nombre, 0, 1, missing, missing, missing, "bytes"))
        end
    end
end

# ---------------------------------------------------------------------------
# Análisis completo
# ---------------------------------------------------------------------------
function leer_clk_tck(ejecucion::AbstractString)
    ruta = joinpath(ejecucion, "EJECUCION.txt")
    isfile(ruta) || return 100, "(sin EJECUCION.txt; USER_HZ de Linux por defecto)"
    for l in eachline(ruta)
        m = match(r"^\s*CLK_TCK\s*=\s*(\d+)\s*$", l)
        m === nothing && continue
        return parse(Int, m.captures[1]), ruta
    end
    return 100, "(EJECUCION.txt sin CLK_TCK; USER_HZ de Linux por defecto)"
end

function analizar(ejecucion::AbstractString, nodos::Vector{String};
                  modelo::String = "deepseek-flash",
                  comando::String = "",
                  manifest_sha256::String = "")
    pool = PoolCadenas()
    nodos_info = ResumenNodo[]
    recursos_info = RecursoNodo[]
    for nodo in nodos
        ruta = joinpath(ejecucion, nodo, "registro.jsonl")
        isfile(ruta) || throw(ArgumentError("no existe el registro del nodo $nodo: $ruta"))
        sha = sha256_archivo(ruta)
        eventos, lineas, truncadas = leer_registro(ruta, pool)
        push!(nodos_info, ResumenNodo(nodo, ruta, sha, lineas, truncadas,
                                      es_v1(eventos) ? "v1" : "v0", eventos))
        ruta_csv = joinpath(ejecucion, "recursos-$nodo.csv")
        if isfile(ruta_csv)
            muestras = leer_recursos(ruta_csv)
            push!(recursos_info, RecursoNodo(nodo, ruta_csv, sha256_archivo(ruta_csv), muestras))
        end
    end
    clk_tck, clk_origen = leer_clk_tck(ejecucion)

    enteras = FilaEntera[]
    reales = FilaReal[]
    latencias = FilaLatencia[]
    tramos = FilaTramo[]
    rechazos = FilaRechazo[]
    hallazgos = FilaHallazgo[]

    muestras_lat, duplicados = calcular_latencias(nodos_info, latencias)
    for f in latencias
        push!(enteras, FilaEntera("latencia_propagacion_ns", "$(f.nodo_a)->$(f.nodo_b)",
                                  f.n, f.no_admitidos, f.p50, f.p95, f.max, "ns"))
    end
    ne, p50, p95, mx = distribucion_entera(muestras_lat)
    push!(enteras, FilaEntera("latencia_propagacion_ns", "total", ne, 0, p50, p95, mx, "ns"))

    frac, episodios, medida = calcular_divergencia(nodos_info)
    if medida && frac !== missing
        push!(reales, FilaReal("divergencia_fraccion_tiempo", "total", 1, 0,
                               Float64(frac), Float64(frac), Float64(frac), "fraccion"))
    else
        push!(reales, FilaReal("divergencia_fraccion_tiempo", "total", 0, length(nodos), missing, missing, missing, "fraccion"))
    end

    calcular_etapas(nodos_info, enteras)
    calcular_admision_profundidad(nodos_info, tramos)
    calcular_bloques_padres_rojos(nodos_info, enteras, reales, hallazgos)
    calcular_rechazos(nodos_info, rechazos, pool)
    calcular_reorg(nodos_info, enteras)

    ids_estado = calcular_estado_final(nodos_info)
    detalle = Tuple{String,String}[]
    for (i, r) in enumerate(nodos_info)
        push!(detalle, (r.nombre, cadena(pool, ids_estado[i])))
    end
    con_resumen = [ids_estado[i] for i in eachindex(ids_estado) if ids_estado[i] != 0]
    estado_igual = if length(con_resumen) >= 2 && length(con_resumen) == length(ids_estado)
        all(==(con_resumen[1]), con_resumen)
    else
        missing
    end
    if estado_igual !== missing
        v = estado_igual ? 1.0 : 0.0
        push!(reales, FilaReal("estado_final_igual", "total", 1, 0, v, v, v, "booleano"))
    else
        push!(reales, FilaReal("estado_final_igual", "total", 0, length(nodos_info), missing, missing, missing, "booleano"))
    end

    calcular_arranque(nodos_info, enteras)
    calcular_recursos(recursos_info, clk_tck, enteras, reales)

    proc = Procedencia(
        string(VERSION),
        Threads.nthreads(:default),
        Threads.nthreads(:interactive),
        Sys.CPU_NAME,
        manifest_sha256,
        ejecucion,
        nodos,
        nodos_info,
        recursos_info,
        clk_tck,
        clk_origen,
        modelo,
        comando,
    )
    return Resultado(enteras, reales, latencias, tramos, rechazos, hallazgos, episodios,
                     frac === missing ? missing : Float64(frac), medida, estado_igual,
                     detalle, duplicados, proc)
end
