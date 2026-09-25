# Oráculo independiente S01: recalcula `raiz_chunks` y `R2` desde el volcado binario del sector.
#
# Implementación en Julia (LINEO: Julia solo en CPU; sin Python) que NO comparte código con el
# prototipo Rust. Reimplementa:
#   - `H_d(tag, m) = SHA3-256(tag ‖ m)` con la stdlib `SHA`;
#   - la decodificación del `SectorContentsMap` (bitfields Lsb0, una entrada por pieza);
#   - la regla `record_has_s_bucket_chunk` (bits codificados + no codificados al final);
#   - el orden físico de hojas (s-bucket ascendente, dentro pieza ascendente);
#   - el árbol Merkle con relleno `vacío` hasta potencia de dos;
#   - la preimagen y el hash de R2.
#
# El formato del volcado está en `../../ESPECIFICACION-BYTES.md` (sección «Volcado para el oráculo»).

module OraculoS01

using SHA

export recalcular, ResultadoOraculo

const TAG_HOJA  = Vector{UInt8}(codeunits("ZZKSectorHoja___"))
const TAG_NODO  = Vector{UInt8}(codeunits("ZZKSectorNodo___"))
const TAG_VACIO = Vector{UInt8}(codeunits("ZZKSectorVacio__"))
const TAG_RAIZ  = Vector{UInt8}(codeunits("ZZKSectorRaiz___"))
const TAG_MAPA  = Vector{UInt8}(codeunits("ZZKSectorMapa___"))
const TAG_META  = Vector{UInt8}(codeunits("ZZKSectorMeta___"))

const VERSION_R2   = UInt8(0x01)
const NUM_CHUNKS   = 32768
const NUM_S_BUCKETS = 65536
const BITARR       = div(NUM_S_BUCKETS, 8)   # 8192 B por pieza
const CHUNK_BYTES  = 32

struct ResultadoOraculo
    cbid::UInt32
    public_key::Vector{UInt8}
    sector_index::UInt16
    history_size::UInt64
    pieces_in_sector::UInt16
    n::UInt32
    digest_mapa::Vector{UInt8}
    digest_meta::Vector{UInt8}
    raiz_chunks::Vector{UInt8}
    r2::Vector{UInt8}
end

h_d(tag::Vector{UInt8}, msg::Vector{UInt8}) = sha3_256(vcat(tag, msg))

"Lee un entero little-endian de `k` bytes desde `bytes[ini:ini+k-1]`."
function le(bytes::AbstractVector{UInt8}, ini::Int, k::Int)
    x = zero(UInt64)
    @inbounds for i in 0:(k - 1)
        x |= UInt64(bytes[ini + i]) << (8 * i)
    end
    return x
end

le32(bytes, ini) = UInt32(le(bytes, ini, 4))
le16(bytes, ini) = UInt16(le(bytes, ini, 2))
le64(bytes, ini) = UInt64(le(bytes, ini, 8))

le_bytes(x::UInt16) = UInt8[x & 0xff, (x >> 8) & 0xff]
le_bytes(x::UInt32) = UInt8[x & 0xff, (x >> 8) & 0xff, (x >> 16) & 0xff, (x >> 24) & 0xff]
le_bytes(x::UInt64) = UInt8[
    (x >> (8 * i)) & 0xff for i in 0:7
]

"Bit `b` (0-based) del campo Lsb0 `campo`."
@inline function bit_lsb0(campo::AbstractVector{UInt8}, b::Int)
    return (campo[(b >> 3) + 1] >> (b & 7)) & 0x01
end

"""
Regla `record_has_s_bucket_chunk(s_bucket, bitfield, num_encoded) -> (usado, codificado)`.

Reproduce `subspace-farmer-components/src/sector.rs:582-608`:
- bit puesto ⇒ usado y codificado;
- si ya hay `NUM_CHUNKS` codificados, el resto no se usa;
- si no, caben `NUM_CHUNKS - num_encoded` no codificados, y se colocan al final.
"""
@inline function usado_y_codificado(campo, num_encoded::Int, b::Int, codificados_antes::Int)
    if bit_lsb0(campo, b) == 0x01
        return (true, true)
    elseif num_encoded == NUM_CHUNKS
        return (false, false)
    else
        no_codificados_antes = b - codificados_antes
        no_codificados_total = NUM_CHUNKS - num_encoded
        return (no_codificados_antes < no_codificados_total, false)
    end
end

"Construye la hoja de chunk."
function hoja(s_bucket::UInt16, piece_offset::UInt16, codificado::UInt8, chunk::AbstractVector{UInt8})
    @assert length(chunk) == CHUNK_BYTES
    msg = vcat(le_bytes(s_bucket), le_bytes(piece_offset), UInt8[codificado], Vector{UInt8}(chunk))
    return h_d(TAG_HOJA, msg)
end

"Merkle binario con relleno `vacío` hasta potencia de dos."
function merkle(hojas::Vector{Vector{UInt8}})
    @assert !isempty(hojas)
    m = nextpow(2, length(hojas))
    vacio = h_d(TAG_VACIO, UInt8[])
    nivel = Vector{Vector{UInt8}}(undef, m)
    @inbounds for i in 1:length(hojas)
        nivel[i] = hojas[i]
    end
    @inbounds for i in (length(hojas) + 1):m
        nivel[i] = vacio
    end
    while length(nivel) > 1
        siguiente = Vector{Vector{UInt8}}(undef, div(length(nivel), 2))
        @inbounds for i in 1:2:length(nivel)
            siguiente[(i + 1) >> 1] = h_d(TAG_NODO, vcat(nivel[i], nivel[i + 1]))
        end
        nivel = siguiente
    end
    return nivel[1]
end

"""
Recalcula `raiz_chunks` y `R2` desde los bytes del volcado.

Se decodifica el mapa, se reconstruye el orden físico y se recompone R2 sin usar ningún valor
calculado por el prototipo Rust (salvo los campos de identidad del volcado).
"""
function recalcular(dump::AbstractVector{UInt8})
    off = 1
    magic = String(Vector{UInt8}(dump[off:(off + 7)]))
    @assert magic == "ZZKS01D1" "magic de volcado inesperado: $magic"
    off += 8
    version_dump = le32(dump, off); off += 4
    @assert version_dump == 1 "versión de volcado no soportada: $version_dump"
    cbid = le32(dump, off); off += 4
    public_key = Vector{UInt8}(dump[off:(off + 31)]); off += 32
    sector_index = le16(dump, off); off += 2
    history_size = le64(dump, off); off += 8
    pieces = le16(dump, off); off += 2
    sector_len = Int(le64(dump, off)); off += 8
    sector = Vector{UInt8}(dump[off:(off + sector_len - 1)])

    mapa_size = BITARR * Int(pieces) + 32
    chunks_size = Int(pieces) * NUM_CHUNKS * CHUNK_BYTES
    meta_size = sector_len - mapa_size - chunks_size - 32
    @assert meta_size > 0 "metadatos no positivos: $meta_size"

    mapa = @view sector[1:mapa_size]
    chunks = @view sector[(mapa_size + 1):(mapa_size + chunks_size)]
    meta = @view sector[(mapa_size + chunks_size + 1):(mapa_size + chunks_size + meta_size)]

    digest_mapa = h_d(TAG_MAPA, Vector{UInt8}(mapa))
    digest_meta = h_d(TAG_META, Vector{UInt8}(meta))

    # Campos de bits por pieza (Lsb0) y número de bits puestos.
    campos = [@view mapa[(p * BITARR + 1):((p + 1) * BITARR)] for p in 0:(Int(pieces) - 1)]
    num_encoded = [sum(count_ones, campos[p + 1]) for p in 0:(Int(pieces) - 1)]

    n = Int(pieces) * NUM_CHUNKS
    hojas = Vector{Vector{UInt8}}(undef, n)
    codificados_antes = zeros(Int, Int(pieces))
    loc = 0
    @inbounds for b in 0:(NUM_S_BUCKETS - 1)
        for p in 0:(Int(pieces) - 1)
            campo = campos[p + 1]
            usado, cod = usado_y_codificado(campo, num_encoded[p + 1], b, codificados_antes[p + 1])
            if usado
                chunk = @view chunks[(loc * CHUNK_BYTES + 1):((loc + 1) * CHUNK_BYTES)]
                hojas[loc + 1] = hoja(UInt16(b), UInt16(p), cod ? UInt8(1) : UInt8(0), chunk)
                loc += 1
            end
            if bit_lsb0(campo, b) == 0x01
                codificados_antes[p + 1] += 1
            end
        end
    end
    @assert loc == n "se esperaban $n hojas, se generaron $loc"

    raiz_chunks = merkle(hojas)

    preimagen = vcat(
        UInt8[VERSION_R2],
        le_bytes(cbid),
        public_key,
        le_bytes(sector_index),
        le_bytes(history_size),
        le_bytes(pieces),
        digest_mapa,
        digest_meta,
        raiz_chunks,
        le_bytes(UInt32(n)),
    )
    r2 = h_d(TAG_RAIZ, preimagen)

    return ResultadoOraculo(
        cbid,
        public_key,
        sector_index,
        history_size,
        pieces,
        UInt32(n),
        digest_mapa,
        digest_meta,
        raiz_chunks,
        r2,
    )
end

end # module
