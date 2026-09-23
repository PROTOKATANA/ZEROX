# Kernel rápido: tipos concretos, arrays contiguos, sin asignaciones en el bucle caliente.
#
# Representación elegida, y por qué (LINEO §4):
#
# * El mapa de presencia de una pieza son 8_192 B = 65_536 bits, un bit por s-bucket. Se guarda
#   como `Matrix{UInt8}` de tamaño `(piezas, 8192)`: la **columna** es el índice de byte y la
#   **fila** la pieza. En orden de columnas de Julia, recorrer las piezas de un byte fijo es
#   contiguo, que es exactamente el acceso de la auditoría (un bucket, todas las piezas).
# * El contador de ocupación por bucket es un `Vector{Int32}` de 65_536 posiciones. Cabe en
#   L2 y se recorre una vez por lote.
# * La aritmética de distancia y de aceptación es `UInt64`, sin coma flotante: el predicado
#   `d <= SR ÷ 2` es una decisión discreta y `Float64` no puede representar `SR = 2^64−1`.
#
# Todas las funciones mutantes (`!`) escriben en buffers preasignados y devuelven el buffer.

"""
    u64_le(bytes, off=1) -> UInt64

Lee 8 bytes en **little-endian** empezando en `off`. Es la lectura que hace el código fijado:

* `global_challenge_as_solution_range`: primeros 8 B LE del reto
  (`subspace-verification/src/lib.rs:131-140`).
* `audit_chunk_as_solution_range`: primeros 8 B LE del `audit_chunk`.

El orden de bytes es parte del contrato y por eso se comprueba contra vectores reales del oráculo.
"""
@inline function u64_le(bytes::AbstractVector{UInt8}, off::Int=1)
    return UInt64(bytes[off]) |
           UInt64(bytes[off + 1]) << 8 |
           UInt64(bytes[off + 2]) << 16 |
           UInt64(bytes[off + 3]) << 24 |
           UInt64(bytes[off + 4]) << 32 |
           UInt64(bytes[off + 5]) << 40 |
           UInt64(bytes[off + 6]) << 48 |
           UInt64(bytes[off + 7]) << 56
end

"""
    u16_le(bytes, off=1) -> UInt16

Los dos primeros bytes en little-endian. Es `s_bucket_audit_index`
(`subspace-core-primitives/src/sectors.rs:32-39`).
"""
@inline function u16_le(bytes::AbstractVector{UInt8}, off::Int=1)
    return UInt16(bytes[off]) | UInt16(bytes[off + 1]) << 8
end

"""
    distancia_u64(a, b) -> UInt64

Distancia circular sobre `Z/2^64`, idéntica a `bidirectional_distance` con `WrappingSub`
(`subspace-core-primitives/src/solutions.rs:330-337`): resta en las dos direcciones y el mínimo.

En Julia la aritmética de enteros **ya envuelve** (no hay comprobación de desbordamiento por
omisión, a diferencia de Rust), así que `a - b` sobre `UInt64` es exactamente el `wrapping_sub` del
código fijado. No existe un operador `-%`.
"""
@inline function distancia_u64(a::UInt64, b::UInt64)
    d1 = a - b
    d2 = b - a
    return min(d1, d2)
end

"""
    gana(d, SR) -> Bool

Predicado de aceptación: `solution_distance <= solution_range / 2`, con división **entera**
(`subspace-verification/src/lib.rs:157`).
"""
@inline gana(d::UInt64, SR::UInt64) = d <= (SR >> 1)

"""
    ssc_xor!(destino, sector_id, reto)

`sector_slot_challenge = SectorId XOR global_challenge`, byte a byte
(`sectors.rs:117-123`). Se escribe en `destino` (32 B) para no asignar.
"""
@inline function ssc_xor!(destino::AbstractVector{UInt8},
                         sector_id::AbstractVector{UInt8},
                         reto::AbstractVector{UInt8})
    @inbounds for i in 1:32
        destino[i] = sector_id[i] ⊻ reto[i]
    end
    return destino
end

"""
    bucket_de(ssc) -> Int

Índice de s-bucket en `0..65535`: dos primeros bytes LE del `sector_slot_challenge`.
Devuelve `Int` (1-based se aplica al indexar) para evitar conversiones en el bucle.
"""
@inline bucket_de(ssc::AbstractVector{UInt8}) = Int(u16_le(ssc, 1))

"""
    bit_en(bitmaps, pieza, bucket) -> Bool

¿Tiene `pieza` una prueba en el s-bucket `bucket` (0-based)?

`@inbounds` está justificado por `test/runtests.jl` («bordes de índice de bucket»), que recorre
`bucket = 0` y `bucket = 65535` para todas las piezas, y porque `byte ∈ 1:8192` y
`pieza ∈ 1:size(bitmaps,1)` se verifican en la construcción del modelo. El perfil de referencia de
CI corre además con `--check-bounds=yes`, que **anula** `@inbounds`.
"""
@inline function bit_en(bitmaps::AbstractMatrix{UInt8}, pieza::Int, bucket::Int)
    byte = (bucket >> 3) + 1
    mascara = UInt8(1) << (bucket & 7)
    @inbounds return (bitmaps[pieza, byte] & mascara) != 0
end

# --- Ocupación por bucket -----------------------------------------------------------------------

"""
    s_bucket_sizes_referencia!(out, bitmaps) -> out

**Referencia lenta y transparente.** Para cada pieza y cada bucket, si el bit está encendido suma
uno. Es la definición literal de `s_bucket_sizes`: cuántas piezas aportan un chunk a ese bucket.

Coste `O(piezas × 65_536)` pruebas de bit (con el atajo de byte nulo). No asigna.
"""
function s_bucket_sizes_referencia!(out::Vector{Int32}, bitmaps::AbstractMatrix{UInt8})
    fill!(out, Int32(0))
    M = size(bitmaps, 1)
    NB = size(bitmaps, 2)
    for byte in 1:NB
        base = (byte - 1) * 8
        for p in 1:M
            b = bitmaps[p, byte]
            b == 0 && continue
            for bit in 0:7
                if (b & (UInt8(1) << bit)) != 0
                    out[base + bit + 1] += Int32(1)
                end
            end
        end
    end
    return out
end

"""
    _hist_bloque!(out, bitmaps, ini, fin, hist) -> out

Acumula en `out` la ocupación de los bytes `ini:fin` (índices **absolutos** de columna).
`out` es un contador de 65_536 posiciones; el desplazamiento del bucket se calcula con el índice
absoluto, que es lo que permite usarlo tanto para el barrido completo como para un bloque.

**Aquí hubo un defecto real.** La primera versión pasaba una `view` de columnas y usaba el índice
local de la vista para el desplazamiento, así que cada bloque escribía sus cubos desde el bucket 0
en vez de desde el bucket del bloque. Los totales se conservaban (por eso la suma no lo delataba)
pero la distribución por bucket era falsa. Lo detectó `eq_conservacion_paralelo`, que ahora prueba
varios números de bloques; con un solo bloque el defecto no aparece.
"""
function _hist_bloque!(out::Vector{Int32}, bitmaps::AbstractMatrix{UInt8},
                       ini::Int, fin::Int, hist::Vector{Int32})
    M = size(bitmaps, 1)
    for byte in ini:fin
        fill!(hist, Int32(0))
        @inbounds for p in 1:M
            hist[Int(bitmaps[p, byte]) + 1] += Int32(1)
        end
        base = (byte - 1) * 8
        @inbounds for v in 0:255
            c = hist[v + 1]
            c == 0 && continue
            for bit in 0:7
                if (UInt8(v) & (UInt8(1) << bit)) != 0
                    out[base + bit + 1] += c
                end
            end
        end
    end
    return out
end

"""
    s_bucket_sizes_histograma!(out, bitmaps, hist) -> out

**Kernel optimizado.** Por cada columna (byte) se cuenta cuántas piezas tienen cada uno de los 256
valores de byte —un histograma de 256 bins— y después se reparte ese histograma a los ocho
contadores de bucket. Sustituye `8` pruebas de bit por pieza por `1` incremento por pieza más
`256 × popcount` incrementos por columna, con `piezas ≫ 256`.

`hist` es un buffer preasignado de 256 `Int32` que se reutiliza en cada columna, así que el bucle
no asigna. Conserva los contadores exactos: cada bit encendido suma exactamente uno a su bucket.
"""
function s_bucket_sizes_histograma!(out::Vector{Int32}, bitmaps::AbstractMatrix{UInt8},
                                    hist::Vector{Int32})
    fill!(out, Int32(0))
    return _hist_bloque!(out, bitmaps, 1, size(bitmaps, 2), hist)
end

"""
    s_bucket_sizes_paralelo!(out, bitmaps, nbloques) -> out

Versión paralela por **bloques disjuntos de columnas**. Cada tarea escribe en su propio contador
privado (`parciales[t]`), así que no hay carrera ni falso compartido en el bucle; la reducción es
posterior y en **orden de índice de bloque**, de modo que el resultado es idéntico bit a bit al
serial con cualquier número de hilos (LINEO §7: RNG/estado por tarea y reducción determinista).

No se usa `threadid()` para repartir nada: el reparto es por índice de bloque y una tarea puede
migrar entre hilos sin afectar al resultado.
"""
function s_bucket_sizes_paralelo!(out::Vector{Int32}, bitmaps::AbstractMatrix{UInt8},
                                  nbloques::Integer)
    fill!(out, Int32(0))
    NB = size(bitmaps, 2)
    t = clamp(Int(nbloques), 1, NB)
    parciales = [zeros(Int32, 65_536) for _ in 1:t]
    ancho = cld(NB, t)
    Threads.@threads for b in 1:t
        ini = (b - 1) * ancho + 1
        fin = min(b * ancho, NB)
        ini > fin && continue
        hist = zeros(Int32, 256)   # scratch local a la tarea
        _hist_bloque!(parciales[b], bitmaps, ini, fin, hist)
    end
    # Reducción determinista, en orden de índice de bloque.
    for b in 1:t
        p = parciales[b]
        @inbounds for i in 1:65_536
            out[i] += p[i]
        end
    end
    return out
end

# --- Auditoría por slot -------------------------------------------------------------------------

"""
    auditar_slots!(leidos, sizes, buckets) -> leidos

Chunks auditados por slot: para cada reto, el bucket que selecciona y el tamaño de ese s-bucket.
Es `O(1)` por sector y reto una vez precalculado `sizes`.
"""
function auditar_slots!(leidos::Vector{Int32}, sizes::Vector{Int32},
                        buckets::AbstractVector{<:Integer})
    @inbounds for k in eachindex(buckets)
        leidos[k] = sizes[Int(buckets[k]) + 1]
    end
    return leidos
end

"""
    buckets_de_retos!(destino, sector_id, retos, buf)

Deriva el s-bucket de cada reto para un sector, sin asignar por iteración.
`buf` es un `Vector{UInt8}` de 32 B reutilizado.
"""
function buckets_de_retos!(destino::Vector{Int32}, sector_id::AbstractVector{UInt8},
                           retos::AbstractMatrix{UInt8}, buf::Vector{UInt8})
    @inbounds for k in 1:size(retos, 2)
        ssc_xor!(buf, sector_id, view(retos, :, k))
        destino[k] = Int32(bucket_de(buf))
    end
    return destino
end

# --- Utilidades de bitmap -----------------------------------------------------------------------

"""Número de bits encendidos de una columna (una pieza). `count_ones` compila a `popcnt`."""
function bits_de_pieza(bitmaps::AbstractMatrix{UInt8}, pieza::Int)
    s = 0
    @inbounds for byte in 1:size(bitmaps, 2)
        s += count_ones(bitmaps[pieza, byte])
    end
    return s
end

"""
    rank_select(bitmaps, pieza, bucket) -> Union{Int,Nothing}

Índice **denso** (1-based) del chunk del bucket, o `nothing` si el bucket está vacío.
Es la referencia legible del `rank/select` de `proof_index_for_s_bucket`
(`shared/ab-proof-of-space/src/lib.rs:63-84`); el oráculo Rust lo contrasta bucket a bucket contra
la vía upstream.
"""
function rank_select(bitmaps::AbstractMatrix{UInt8}, pieza::Int, bucket::Int)
    byte = (bucket >> 3) + 1
    bit = bucket & 7
    bit_en(bitmaps, pieza, bucket) || return nothing
    r = 0
    @inbounds for j in 1:(byte - 1)
        r += count_ones(bitmaps[pieza, j])
    end
    # OJO con la precedencia: en Julia `&` liga **más fuerte** que `-`, así que la máscara de los
    # bits por debajo de `bit` necesita paréntesis explícitos. Sin ellos la expresión se lee
    # `(byte & (1<<bit)) - 1` y el índice denso sale mal. Lo detectó `eq_rank_select`.
    mascara_inferiores = (UInt8(1) << bit) - UInt8(1)
    @inbounds r += count_ones(bitmaps[pieza, byte] & mascara_inferiores)
    return r + 1
end

"""
    mapa_a_matriz(bytes, piezas) -> Matrix{UInt8}

Reinterpreta el `bitmaps.bin` del oráculo (`piezas × 8192` B, orden de pieza) como la matriz
`(piezas, 8192)`. La copia es deliberada: `bitmaps.bin` es fila-mayor por pieza y el kernel quiere
la pieza contigua dentro de cada columna.
"""
function mapa_a_matriz(bytes::AbstractVector{UInt8}, piezas::Integer)
    nb = 8192
    @assert length(bytes) == piezas * nb "bitmaps.bin: tamaño inesperado"
    m = Matrix{UInt8}(undef, piezas, nb)
    @inbounds for p in 1:piezas
        off = (p - 1) * nb
        for j in 1:nb
            m[p, j] = bytes[off + j]
        end
    end
    return m
end
