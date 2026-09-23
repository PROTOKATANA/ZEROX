# Lectura de los artefactos del oráculo Rust. Solo E/S: nada de cálculo aquí.
#
# Los ficheros que produce `oraculo-rust/src/bin/puente.rs` son deliberadamente TSV/binario simple
# para que se puedan inspeccionar a mano y para no añadir dependencias de serialización.

"""Divide una línea TSV. No usa `split` con límite para no perder columnas vacías."""
_filas(ruta::AbstractString) = begin
    isfile(ruta) || return Vector{Vector{String}}()
    lineas = readlines(ruta)
    isempty(lineas) && return Vector{Vector{String}}()
    [String.(split(l, '\t')) for l in lineas]
end

"""Convierte los TSV `campo\tvalor` del oráculo en un `Dict`."""
function leer_meta(ruta::AbstractString)
    d = Dict{String,String}()
    for f in _filas(ruta)[2:end]
        length(f) >= 2 && (d[f[1]] = f[2])
    end
    return d
end

"""Lee una tabla con cabecera y devuelve `Vector{NamedTuple}` con nombres de columna."""
function leer_tabla(ruta::AbstractString)
    f = _filas(ruta)
    isempty(f) && return NamedTuple[]
    cols = f[1]
    out = NamedTuple[]
    for fila in f[2:end]
        length(fila) == length(cols) || continue
        vals = map(cols, fila) do c, v
            c => (v == "true" ? true : v == "false" ? false : _parse_auto(v))
        end
        push!(out, NamedTuple{Tuple(Symbol.(cols))}(Tuple(last.(vals))))
    end
    return out
end

"""Interpreta el texto como entero, booleano o decimal, en ese orden."""
function _parse_auto(v::AbstractString)
    vi = tryparse(Int64, v)
    vi !== nothing && return vi
    vb = tryparse(UInt64, v)
    vb !== nothing && return vb
    vf = tryparse(Float64, v)
    vf !== nothing && return vf
    return String(v)
end

"""`bitmaps.bin` → `Matrix{UInt8}` de tamaño `(piezas, 8192)`, listo para el kernel."""
function leer_bitmaps(dir::AbstractString)
    meta = leer_meta(joinpath(dir, "bits-meta.tsv"))
    piezas = parse(Int, meta["piezas"])
    bytes = read(joinpath(dir, "bitmaps.bin"))
    return mapa_a_matriz(bytes, piezas), piezas
end

"""`retos.tsv` → `Matrix{UInt8}` de 32 × K (un reto por columna)."""
function leer_retos(dir::AbstractString)
    filas = leer_tabla(joinpath(dir, "retos.tsv"))
    isempty(filas) && return Matrix{UInt8}(undef, 32, 0)
    m = Matrix{UInt8}(undef, 32, length(filas))
    for (k, fila) in enumerate(filas)
        m[:, k] = hex_a_bytes(fila.hex)
    end
    return m
end

"""
    leer_constantes(dir) -> Dict{String,Int}

Lee `constantes.tsv`, que produce `oraculo-rust ... constantes` llamando a la **API del clon**
(`sector_size`, `sector_record_metadata_size`, `SectorContentsMap::encoded_size`,
`SectorMetadataChecksummed::encoded_size`). Es la fuente autoritativa contra la que se comprueba la
contabilidad de bytes del modelo; sirve para no volver a recomponerla a mano.
"""
function leer_constantes(dir::AbstractString)
    d = Dict{String,Int}()
    for f in _filas(joinpath(dir, "constantes.tsv"))[2:end]
        length(f) >= 2 || continue
        v = tryparse(Int, f[2])
        v === nothing || (d[f[1]] = v)
    end
    return d
end

"""Hex de 32 B a `Vector{UInt8}`."""
function hex_a_bytes(h::AbstractString)
    n = length(h) ÷ 2
    out = Vector{UInt8}(undef, n)
    for i in 1:n
        out[i] = parse(UInt8, h[2i-1:2i]; base=16)
    end
    return out
end

"""Los TSV del oráculo que hacen falta para el informe, todos juntos."""
function cargar_resultados(dir::AbstractString)
    return (
        bits_meta=leer_meta(joinpath(dir, "bits-meta.tsv")),
        audita_meta=leer_meta(joinpath(dir, "audita-meta.tsv")),
        prueba_meta=leer_meta(joinpath(dir, "prueba-meta.tsv")),
        constantes=leer_constantes(dir),
        vectores=leer_tabla(joinpath(dir, "vectores.tsv")),
        vectores_buckets=leer_tabla(joinpath(dir, "vectores-buckets.tsv")),
        audita_retos=leer_tabla(joinpath(dir, "audita-retos.tsv")),
        audita_pares=leer_tabla(joinpath(dir, "audita-pares.tsv")),
    )
end
