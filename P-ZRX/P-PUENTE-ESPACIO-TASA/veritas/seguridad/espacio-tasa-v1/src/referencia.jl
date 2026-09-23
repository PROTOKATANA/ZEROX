# Referencia matemática pequeña, transparente y **exacta**.
#
# Todo este fichero trabaja en `BigInt`/`Rational{BigInt}`. La razón no es purismo: el efecto de
# paridad que decide si el `SR` se cancela vive en el bit `2^-64`, y `Float64` no puede verlo.
# `SPEC.md` C-GD-01 prohibe además la coma flotante para el peso de un bloque.
#
# Nada de aquí usa aleatoriedad ni estructuras de datos: es aritmética entera comprobable a mano.

const DOS64 = big(2)^64
const DOS128 = big(2)^128

# --- Constantes del formato, leídas de Autonomys @ f8842d0 (ver PROCEDENCIA.md) ----------------

"""`Record::NUM_CHUNKS = 2^15`. `pieces.rs:561`. Chunks (escalares) por registro."""
const NUM_CHUNKS = big(2)^15

"""`Record::NUM_S_BUCKETS = 2^16`. `pieces.rs:565`, con `ERASURE_CODING_RATE = (1,2)`."""
const NUM_S_BUCKETS = big(2)^16

"""`Record::SIZE = 32 * 2^15 = 1_048_576` B. `pieces.rs:570`."""
const RECORD_SIZE = big(1_048_576)

"""`RecordCommitment::SIZE = 48` B. `pieces.rs:801`."""
const COMMITMENT_SIZE = big(48)

"""`RecordWitness::SIZE = 48` B. `pieces.rs:937`."""
const WITNESS_SIZE = big(48)

"""
`Blake3Hash::SIZE = 32` B. `hashes.rs:116`.

**Corrección.** `RecordMetadata` (`sector.rs:139-152`) son **tres** campos —
`commitment` 48 + `witness` 48 + `piece_checksum` (un `Blake3Hash`) 32 — y
`RecordMetadata::encoded_size() = 48 + 48 + 32 = 128`, no 96. La primera versión de este
instrumento omitió el `piece_checksum`, con lo que `sector_size(1000)` salía 32 000 B corto
(1 056 864 064 en vez de 1 056 896 064). Lo detectó `oraculo-rust ... constantes`, que lee
`sector_record_metadata_size` de la API del clon en vez de recomponerlo a mano.
"""
const PIEZA_CHECKSUM_SIZE = big(32)

"""`Blake3Hash::SIZE = 32` B."""
const CHECKSUM_SIZE = big(32)

"""`SingleRecordBitArray = [u8; NUM_S_BUCKETS/8]` → 8_192 B. `sector.rs:174`."""
const CONTENIDOS_POR_PIEZA = NUM_S_BUCKETS ÷ 8

"""
    BYTES_POR_PIEZA_PLOT

Bytes que aporta **cada pieza** al fichero del plot:
`Record::SIZE 1_048_576 + commitment 48 + witness 48 + piece_checksum 32 + mapa 8_192 = 1_056_896`.
Con el `+64` fijo por sector (los dos checksums), `sector_size(p) = p·BYTES_POR_PIEZA_PLOT + 64`.
"""
const BYTES_POR_PIEZA_PLOT = RECORD_SIZE + COMMITMENT_SIZE + WITNESS_SIZE + PIEZA_CHECKSUM_SIZE +
                             CONTENIDOS_POR_PIEZA

"""
`MAX_PIECES_IN_SECTOR = 1000`. `subspace-runtime/src/lib.rs:125`.

**Es un MÁXIMO, no una exigencia del formato.** `SectorMetadata.pieces_in_sector` es un campo
`u16` por sector (`sector.rs:120-135`): un sector puede tener **menos** piezas. Todo el instrumento
usa `piezas_por_sector = 1000` como **hipótesis de escenario** —la más favorable al que trunca, y la
que usa la runtime de Autonomys—, y se declara allí donde se usa. En particular, el
`⌊bytes/sector_size(1000)⌋` que decide cuántos sectores caben en un presupuesto **depende** de esa
hipótesis: con 999 piezas por sector el mismo presupuesto puede admitir un sector (ver
`piezas_que_caben` y el contraejemplo de la tabla de identidades).
"""
const MAX_PIEZAS_POR_SECTOR = 1000

"""`SLOT_PROBABILITY = (1, 6)`. `subspace-runtime-primitives/src/lib.rs:48`."""
const PROB_SLOT = (big(1), big(6))

"""`ERASURE_CODING_RATE = (1, 2)`. `segments.rs:515`."""
const ERASURE_RATE = (big(1), big(2))

# --- Cardinalidad y peso -----------------------------------------------------------------------

"""
    valores_aceptados(SR) -> BigInt

Cuántos de los `2^64` valores del entero `audit_chunk` satisfacen el predicado de aceptación.

El predicado **leído del código** (`subspace-verification/src/lib.rs:150-158`) es
`solution_distance <= solution_range / 2` con división entera, y la distancia es circular
(`solutions.rs:330-337`, `wrapping_sub` en las dos direcciones y `min`).

Aceptan los valores a distancia `0, 1, …, SR÷2` del reto: a distancia `0` hay uno; a cada
distancia `j ≥ 1`, dos (uno a cada lado). Luego `2·(SR÷2) + 1`.

`SR ÷ 2 ≤ 2^63 − 1`, así que los dos lados del círculo nunca se solapan y la cuenta es exacta en
todo el dominio (no hay conteo doble del punto opuesto salvo cuando `SR = 2^64−1`, donde
`2·(2^63−1)+1 = 2^64−1 = 2^64 − 1` y solo falta el propio reto, que sí está a distancia 0).
"""
valores_aceptados(SR::Integer) = 2 * (big(SR) ÷ 2) + 1

"""
    peso_bloque(SR) -> BigInt

`w(B) = ⌊2^128 / (SR+1)⌋`, división entera exacta (`SPEC.md` C-GD-01, `SPEC.md:2310`).

`SR = 0` da `2^128` (que no cabe en `u128`, y por eso el tipo de `blue_work` es `u256`);
`SR = 2^64−1` da el mínimo, `2^64`. En `BigInt` los dos extremos son exactos.
"""
peso_bloque(SR::Integer) = DOS128 ÷ (big(SR) + 1)

"""`2^128 mod (SR+1)`: el único error que introduce el suelo `⌊·⌋` del peso."""
resto_suelo(SR::Integer) = DOS128 % (big(SR) + 1)

"""Probabilidad exacta de billete por **chunk efectivamente auditado**: `|aceptados| / 2^64`."""
prob_billete(SR::Integer) = valores_aceptados(SR) // DOS64

"""
    tasa_peso(P, SR) -> Rational{BigInt}

Peso esperado por slot de un flujo con `P` chunks auditados por slot y rango `SR`:

    tasa = P · prob_billete(SR) · peso_bloque(SR)

Es `candidatos/slot × peso/bloque`, sin ninguna aproximación.
"""
tasa_peso(P::Integer, SR::Integer) = big(P) * prob_billete(SR) * peso_bloque(SR)

"""`tasa_peso(P,SR) / (P·2^64)`. Vale exactamente `1` si y solo si el `SR` se cancela del todo."""
razon_cancelacion(SR::Integer) = tasa_peso(1, SR) // DOS64

"""`razon_cancelacion(SR) − 1`: el residuo exacto que el `SR` deja en la tasa de peso."""
desviacion_cancelacion(SR::Integer) = razon_cancelacion(SR) - 1

# --- Distancia circular ------------------------------------------------------------------------

"""
    distancia_circular(a, b, m) -> BigInt

Distancia sobre el círculo `Z/m`. Es la definición de `bidirectional_distance`
(`solutions.rs:330-337`) generalizada a un módulo `m`; con `m = 2^64` y `a,b::UInt64` es
exactamente la del código, y por eso el test de cardinalidad exhaustiva puede hacerse en un
círculo **pequeño** sin depender del tamaño.
"""
function distancia_circular(a::Integer, b::Integer, m::Integer)
    m > 0 || throw(ArgumentError("el módulo debe ser positivo"))
    d1 = mod(big(a) - big(b), m)
    d2 = mod(big(b) - big(a), m)
    return min(d1, d2)
end

"""La distancia con `m = 2^64`: el caso que usa el protocolo."""
distancia_u64_exacta(a::Integer, b::Integer) = distancia_circular(a, b, DOS64)

"""
    cardinalidad_exhaustiva(m, SR) -> BigInt

Cuenta **enumerando** los `m` residuos, no con la fórmula. Sirve para refutar la fórmula en un
círculo pequeño; el test compara esta cuenta con `valores_aceptados` cuando `m = 2·(SR÷2)+1`
exactamente (es decir, cuando el círculo es tan pequeño que no hay solapamiento espurio).
"""
function cardinalidad_exhaustiva(m::Integer, SR::Integer)
    m = big(m)
    m2 = big(SR) ÷ 2
    c = big(0)
    for x in big(0):(m - 1)
        if distancia_circular(x, 0, m) <= m2
            c += 1
        end
    end
    return c
end

"""
    cardenalidad_circular(m, SR) -> BigInt

Número de residuos de `Z/m` a distancia `≤ SR÷2` de `0`, contado con la fórmula de anillo:
`min(m, 2·(SR÷2)+1)`. Con `m = 2^64` coincide con `valores_aceptados`.
"""
cardenalidad_circular(m::Integer, SR::Integer) = min(big(m), 2 * (big(SR) ÷ 2) + 1)

# --- Calibración del rango (port exacto de pieces_to_solution_range) ---------------------------

"""
    rango_de_piezas(piezas, prob_slot=(1,6)) -> BigInt

Port exacto de `pieces_to_solution_range` (`solutions.rs:30-40`), con el **mismo orden** de
operaciones y las mismas divisiones enteras truncadas:

    SR = (u64::MAX / prob.den * prob.num / NUM_CHUNKS * NUM_S_BUCKETS) / piezas

El factor `NUM_S_BUCKETS/NUM_CHUNKS = 2` es exactamente `1/o` con `o = 1/2`, la **ocupación media**
de s-bucket. Ese `1/2` es una media, no una constante por bucket: el instrumento mide la
distribución real y publica la diferencia.
"""
function rango_de_piezas(piezas::Integer, prob_slot::Tuple{<:Integer,<:Integer}=PROB_SLOT)
    sr = (DOS64 - 1) ÷ big(prob_slot[2]) * big(prob_slot[1])
    sr = sr ÷ NUM_CHUNKS * NUM_S_BUCKETS
    return sr ÷ big(piezas)
end

"""
    cuenta_alcanzable(objetivo) -> BigInt

`valores_aceptados` vale siempre `2m+1`, luego la cuenta alcanzable es **siempre impar**: un
retarget no puede fijar una tasa de bloques arbitraria, solo una de la retícula impar.
"""
function cuenta_alcanzable(objetivo::Rational)
    m = round(BigInt, (big(numerator(objetivo)) - big(denominator(objetivo))) // (2 * big(denominator(objetivo))), RoundNearest)
    m = max(m, big(0))
    return 2 * m + 1
end

"""
    rango_retarget(P, nu; paridad=:par) -> BigInt

El `SR` que un retarget ideal elige para que `P` chunks auditados por slot produzcan `nu` billetes
por slot. Devuelve **uno de los dos** `SR` que dan la misma cuenta de aceptados —el par
(`cuenta−1`) o el impar (`cuenta`)—. Los dos producen la **misma tasa de bloques** y **pesos
distintos**: ése es el efecto de paridad.
"""
function rango_retarget(P::Integer, nu::Rational; paridad::Symbol=:par)
    paridad in (:par, :impar) || throw(ArgumentError("paridad debe ser :par o :impar"))
    cuenta = cuenta_alcanzable(nu * DOS64 // big(P))
    sr = paridad === :par ? cuenta - 1 : cuenta
    return clamp(sr, big(1), DOS64 - 1)
end

"""
    sesgo_tasa(P1, P2, SR1, SR2) -> Rational{BigInt}

`[tasa_peso(P1,SR1)/tasa_peso(P2,SR2)] / (P1/P2) − 1`. Vale `0` exactamente si y solo si la razón
de tasas de peso reproduce la razón de chunks auditados.
"""
function sesgo_tasa(P1::Integer, P2::Integer, SR1::Integer, SR2::Integer)
    return (tasa_peso(P1, SR1) // tasa_peso(P2, SR2)) // (big(P1) // big(P2)) - 1
end

# --- Contabilidad de bytes del sector ----------------------------------------------------------

"""
    sector_size(piezas) -> BigInt

Tamaño **real** de un sector, port de `sector_size`
(`subspace-farmer-components/src/sector.rs:47-53`):

    chunks (piezas·Record::SIZE)
      + metadatos de registro (piezas·(48+48+32) = piezas·128)
      + mapa de contenidos (piezas·8192 + 32)
      + checksum del sector (32)

**Qué queda DENTRO** (lo que ocupa el fichero de la parcela): los chunks de los s-buckets, el
`commitment`, el `witness` y el `piece_checksum` de cada registro, el mapa de contenidos y su
checksum, y el checksum del sector.

**Qué queda FUERA**: `SectorMetadataChecksummed::encoded_size()` = **131 116 B** por sector
(`sector_index` 2 + `pieces_in_sector` 2 + `s_bucket_sizes` 65 536·u16 = 131 072 + `history_size` 8
+ checksum 32). Esa metadata la guarda el granjero aparte, **no** vive en el fichero del sector, y
`oraculo-rust ... constantes` la imprime desde la API del clon.

**No** es `Piece::SIZE` (1 048 672 B). La diferencia con `piezas · Piece::SIZE` es
`piezas·(128−96) + piezas·8192 + 64`: con 1000 piezas, **8 224 064 B**, no 8 224. `Piece::SIZE`
**no** se usa como sustituto de bytes físicos en ninguna cifra del informe.
"""
function sector_size(piezas::Integer)
    p = big(piezas)
    chunks = p * RECORD_SIZE
    metadata = p * (COMMITMENT_SIZE + WITNESS_SIZE + PIEZA_CHECKSUM_SIZE)
    mapa = p * CONTENIDOS_POR_PIEZA + CHECKSUM_SIZE
    return chunks + metadata + mapa + CHECKSUM_SIZE
end

"""Tamaño de la metadata de sector que **no** está en el fichero del sector: 131 116 B."""
function metadata_fuera_del_sector()
    # sector_index u16 + pieces_in_sector u16 + s_bucket_sizes [u16; 65536] + history_size u64
    # + checksum blake3. Contraste con la API: resultados/constantes.tsv.
    return big(2) + big(2) + NUM_S_BUCKETS * big(2) + big(8) + CHECKSUM_SIZE
end

"""Bytes por pieza dentro del sector, con los metadatos repartidos: `sector_size(p)/p`."""
function bytes_por_pieza(piezas::Integer)
    p = big(piezas)
    return sector_size(p) // p
end

"""
    piezas_de_bytes(bytes, piezas_por_sector=1000) -> (sectores, piezas, bytes_usados)

Traduce bytes nominales de parcela a piezas, con el tamaño real de sector. Los sectores se toman
**completos** (el formato fija `pieces_in_sector` por sector): los bytes sobrantes no son piezas.
"""
function piezas_de_bytes(bytes::Integer, piezas_por_sector::Integer=MAX_PIEZAS_POR_SECTOR)
    ss = sector_size(piezas_por_sector)
    sectores = big(bytes) ÷ ss
    return sectores, sectores * big(piezas_por_sector), sectores * ss
end

"""
    ocupacion_media_por_pieza() -> Rational{BigInt}

`NUM_CHUNKS/NUM_S_BUCKETS`. **Exactamente** `1/2`, porque `create_proofs` produce siempre
`NUM_CHUNKS = 32768` pruebas sobre `NUM_S_BUCKETS = 65536` buckets
(`shared/ab-proof-of-space/src/chiapos.rs:225-268`). Es una media exacta sobre buckets, no una
probabilidad constante por bucket.
"""
ocupacion_media_por_pieza() = big(NUM_CHUNKS) // big(NUM_S_BUCKETS)
