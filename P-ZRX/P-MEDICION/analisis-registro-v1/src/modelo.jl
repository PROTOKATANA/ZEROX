# modelo.jl — tipos, constantes y lectura tolerante del registro (LINEO §1, §3.1, §4)
#
# El registro es una línea JSON por evento (ESQUEMA-REGISTRO-v1 §0). Este archivo:
#   * fija los códigos internos de `tipo`, `familia`, `etapa`, `fase`;
#   * interma las cadenas (hash, punta, resumen, motivo) a ids densos Int32 (LINEO §4, SoA/IDs densos);
#   * convierte cada línea a un `Evento` isbits con tipos concretos;
#   * tolera SÓLO la última línea inválida (escritura cortada) y aborta en cualquier otra.

# ---------------------------------------------------------------------------
# Códigos de tipo de evento (ESQUEMA §1)
# ---------------------------------------------------------------------------
const TIPO_DESCONOCIDO       = 0x00
const T_ARRANQUE             = 0x01
const T_REINICIO_COMPLETO    = 0x02
const T_BLOQUE_MINADO        = 0x03
const T_BLOQUE_PRODUCIDO     = 0x04
const T_BLOQUE_RECIBIDO      = 0x05
const T_BLOQUE_RED_ADMITIDO  = 0x06
const T_BLOQUE_RED_RECHAZADO = 0x07
const T_BLOQUE_RED_HUERFANO  = 0x08
const T_HUERFANO_RESUELTO    = 0x09
const T_HUERFANO_DESALOJADO  = 0x0a
const T_CAMBIO_PUNTA         = 0x0b
const T_REORGANIZACION_POW   = 0x0c
const T_PAR_CONECTADO        = 0x0d
const T_PAR_DESCONECTADO     = 0x0e
const T_PAR_PENALIZADO       = 0x0f
const T_LIMITE_ALCANZADO     = 0x10
const T_EVIDENCIA_DETECTADA  = 0x11
const T_EVIDENCIA_INCLUIDA   = 0x12
const T_FIRMANTE_ABSTENIDO   = 0x13
const T_PARADA               = 0x14

const TIPOS = Dict{String,UInt8}(
    "arranque"            => T_ARRANQUE,
    "reinicio_completo"   => T_REINICIO_COMPLETO,
    "bloque_minado"       => T_BLOQUE_MINADO,
    "bloque_producido"    => T_BLOQUE_PRODUCIDO,
    "bloque_recibido"     => T_BLOQUE_RECIBIDO,
    "bloque_red_admitido" => T_BLOQUE_RED_ADMITIDO,
    "bloque_red_rechazado"=> T_BLOQUE_RED_RECHAZADO,
    "bloque_red_huerfano" => T_BLOQUE_RED_HUERFANO,
    "huerfano_resuelto"   => T_HUERFANO_RESUELTO,
    "huerfano_desalojado" => T_HUERFANO_DESALOJADO,
    "cambio_punta"        => T_CAMBIO_PUNTA,
    "reorganizacion_pow"  => T_REORGANIZACION_POW,
    "par_conectado"       => T_PAR_CONECTADO,
    "par_desconectado"    => T_PAR_DESCONECTADO,
    "par_penalizado"      => T_PAR_PENALIZADO,
    "limite_alcanzado"    => T_LIMITE_ALCANZADO,
    "evidencia_detectada" => T_EVIDENCIA_DETECTADA,
    "evidencia_incluida"  => T_EVIDENCIA_INCLUIDA,
    "firmante_abstenido"  => T_FIRMANTE_ABSTENIDO,
    "parada"              => T_PARADA,
)
const NOMBRES_TIPO = Dict{UInt8,String}(v => k for (k, v) in TIPOS)

const FAMILIA_DESCONOCIDA = 0x00
const FAMILIA_POW = 0x01
const FAMILIA_POST = 0x02
const FAMILIAS = Dict{String,UInt8}("pow" => FAMILIA_POW, "post" => FAMILIA_POST)
const NOMBRES_FAMILIA = Dict{UInt8,String}(v => k for (k, v) in FAMILIAS)

const ETAPA_DESCONOCIDA = 0x00
const ETAPAS = Dict{String,UInt8}(
    "decodificacion" => 0x01,
    "limite"         => 0x02,
    "cabecera"       => 0x03,
    "admision"       => 0x04,
    "persistencia"   => 0x05,
)
const NOMBRES_ETAPA = Dict{UInt8,String}(v => k for (k, v) in ETAPAS)

const FASE_DESCONOCIDA = 0x00
const FASE_INICIO = 0x01
const FASE_LIMPIO = 0x02
const FASES = Dict{String,UInt8}("inicio" => FASE_INICIO, "limpio" => FASE_LIMPIO)
const NOMBRES_FASE = Dict{UInt8,String}(v => k for (k, v) in FASES)

# Sentinela de campo ausente (ESQUEMA §0: el campo se omite, no se escribe 0 ni -1).
const NODATO = typemin(Int64)

# ---------------------------------------------------------------------------
# Pool de cadenas: interma hash/punta/resumen/motivo a ids densos Int32
# ---------------------------------------------------------------------------
mutable struct PoolCadenas
    cadenas::Vector{String}
    ids::Dict{String,Int32}
end
PoolCadenas() = PoolCadenas(String[], Dict{String,Int32}())

@inline function internar!(p::PoolCadenas, s::AbstractString)::Int32
    id = get(p.ids, s, Int32(0))
    id == 0 || return id
    id = Int32(length(p.cadenas) + 1)
    push!(p.cadenas, String(s))
    p.ids[String(s)] = id
    return id
end

@inline cadena(p::PoolCadenas, id::Integer) = id == 0 ? "" : p.cadenas[id]

# ---------------------------------------------------------------------------
# Evento: isbits + id de cadena. Un campo ausente vale NODATO / 0.
# ---------------------------------------------------------------------------
struct Evento
    tipo::UInt8
    linea::Int32
    reloj_ns::Int64
    pared::Int64
    version_esquema::Int64
    hash::Int32
    familia::UInt8
    etapa::UInt8
    motivo::Int32
    fase::UInt8
    slot::Int64
    altura::Int64
    n_padres::Int64
    n_txs::Int64
    bytes::Int64
    n_bloques_dag::Int64
    t_cabecera_ns::Int64
    t_admision_ns::Int64
    t_persistencia_ns::Int64
    t_total_ns::Int64
    t_hasta_rechazo_ns::Int64
    azules::Int64
    rojos::Int64
    punta::Int32
    resumen::Int32
    profundidad_reorg::Int64
    profundidad_pow::Int64
    duracion_ns::Int64
    bloques_repetidos::Int64
end

# Constructores de valores por defecto
function _entero(obj, k::Symbol)::Int64
    haskey(obj, k) || return NODATO
    v = obj[k]
    v === nothing && return NODATO
    return Int64(v)
end

function _texto(obj, k::Symbol, pool::PoolCadenas)::Int32
    haskey(obj, k) || return Int32(0)
    v = obj[k]
    (v === nothing || !(v isa AbstractString)) && return Int32(0)
    return internar!(pool, v)
end

function _enum(obj, k::Symbol, mapa::Dict{String,UInt8})::UInt8
    haskey(obj, k) || return 0x00
    v = obj[k]
    (v === nothing || !(v isa AbstractString)) && return 0x00
    return get(mapa, v, 0x00)
end

function crear_evento(obj, linea::Int, pool::PoolCadenas)::Evento
    tipo_s = haskey(obj, :tipo) ? obj[:tipo] : nothing
    tipo = (tipo_s isa AbstractString) ? get(TIPOS, tipo_s, TIPO_DESCONOCIDO) : TIPO_DESCONOCIDO
    return Evento(
        tipo, Int32(linea),
        _entero(obj, :reloj_ns),
        _entero(obj, :reloj_pared_ns),
        _entero(obj, :version_esquema),
        _texto(obj, :hash, pool),
        _enum(obj, :familia, FAMILIAS),
        _enum(obj, :etapa, ETAPAS),
        _texto(obj, :motivo, pool),
        _enum(obj, :fase, FASES),
        _entero(obj, :slot),
        _entero(obj, :altura),
        _entero(obj, :n_padres),
        _entero(obj, :n_txs),
        _entero(obj, :bytes),
        _entero(obj, :n_bloques_dag),
        _entero(obj, :t_cabecera_ns),
        _entero(obj, :t_admision_ns),
        _entero(obj, :t_persistencia_ns),
        _entero(obj, :t_total_ns),
        _entero(obj, :t_hasta_rechazo_ns),
        _entero(obj, :azules_mergeset),
        _entero(obj, :rojos_mergeset),
        _texto(obj, :punta, pool),
        _texto(obj, :resumen_estado, pool),
        _entero(obj, :profundidad_reorg),
        _entero(obj, :profundidad),
        _entero(obj, :duracion_ns),
        _entero(obj, :bloques_repetidos),
    )
end

# Error con el número de línea (ORDEN §3.2: «aborta con el número de línea»).
struct ErrorRegistro <: Exception
    linea::Int
    detalle::String
end
function Base.showerror(io::IO, e::ErrorRegistro)
    print(io, "registro inválido en la línea ", e.linea, ": ", e.detalle)
end

"""
    leer_registro(path, pool) -> (eventos, n_lineas, n_truncadas)

Tolerancia (ORDEN §3.2): una línea que no es JSON válido sólo se tolera si es la ÚLTIMA del
archivo; en cualquier otra posición aborta con `ErrorRegistro(linea, ...)`.
"""
function leer_registro(path::AbstractString, pool::PoolCadenas)
    lineas = readlines(path)
    eventos = Vector{Evento}()
    sizehint!(eventos, length(lineas))
    truncadas = 0
    n = length(lineas)
    for i in 1:n
        l = lineas[i]
        if isempty(l)
            # Una línea vacía final aparece sólo si el archivo termina en "\n\n" o "\n " raro;
            # el esquema prohíbe líneas vacías, así que fuera de la última posición es error.
            if i == n
                truncadas += 1
                continue
            else
                throw(ErrorRegistro(i, "línea vacía (el esquema no las admite)"))
            end
        end
        obj = nothing
        fallo = false
        try
            obj = JSON3.read(l)
        catch
            fallo = true
        end
        if fallo || !(obj isa JSON3.Object)
            if i == n
                truncadas += 1
                continue
            else
                throw(ErrorRegistro(i, "no es un objeto JSON válido"))
            end
        end
        push!(eventos, crear_evento(obj, i, pool))
    end
    return eventos, n, truncadas
end

# ¿El nodo es v1? ⇔ algún `arranque` trae `version_esquema` (ESQUEMA §0). Si no, v0.
function es_v1(eventos::Vector{Evento})::Bool
    for ev in eventos
        if ev.tipo == T_ARRANQUE && ev.version_esquema != NODATO
            return true
        end
    end
    return false
end

# ---------------------------------------------------------------------------
# Muestras de recursos (ESQUEMA §2), leídas del CSV sin CSV.jl (dependencia mínima)
# ---------------------------------------------------------------------------
struct MuestraRecurso
    pared::Int64
    pid::Int64
    utime::Int64
    stime::Int64
    rss_kib::Int64
    read_bytes::Int64
    write_bytes::Int64
    disco::Int64
end

"""
    leer_recursos(path) -> Vector{MuestraRecurso}

Cabecera opcional (se salta si la primera celda no es un entero). Columnas del ESQUEMA §2:
`reloj_pared_ns,pid,utime_ticks,stime_ticks,rss_kib,read_bytes,write_bytes,disco_datos_bytes`.
"""
function leer_recursos(path::AbstractString)
    muestras = MuestraRecurso[]
    for (i, l) in enumerate(eachline(path))
        isempty(strip(l)) && continue
        campos = split(strip(l), ',')
        length(campos) < 8 && throw(ArgumentError("recursos: línea $i con $(length(campos)) columnas (se esperan 8): $l"))
        vals = try
            parse.(Int64, campos[1:8])
        catch
            i == 1 ? continue : rethrow()   # cabecera
        end
        push!(muestras, MuestraRecurso(vals...))
    end
    return muestras
end

# ---------------------------------------------------------------------------
# sha256 (procedencia) en streaming
# ---------------------------------------------------------------------------
function sha256_archivo(path::AbstractString)::String
    open(path, "r") do io
        return bytes2hex(SHA.sha256(io))
    end
end
