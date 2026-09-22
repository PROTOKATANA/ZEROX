# IB-v0.1 — modelo: estructura real del PoAS de Autonomys, identidades A/B/C y entropía.
#
# ALCANCE. Modelo de juguete para comparar definiciones de identidad de billete. Ninguna
# constante es parámetro de consenso; ninguna cifra se propone al SPEC.
#
# ESTRUCTURA QUE SE MODELA (verificada en fuente en el checkout f8842d0; véase
# HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md para las citas):
#   E1 · El reto de un slot es función de (flujo, slot): `reto(f,s)` (ZEROX C-POT-03) /
#        `global_challenge = Blake3(Blake3(pot_output) || slot)` (Autonomys).
#   E2 · `sector_slot_challenge = sector_id XOR global_challenge` y
#        `s_bucket = primeros 2 bytes` ⇒ **UN solo bucket por (pk, sector, historia, slot,
#        flujo)**. `subspace-core-primitives/src/sectors.rs:33-39`.
#   E3 · En un bucket, cada pieza aporta **a lo sumo un chunk**:
#        `record_has_s_bucket_chunk -> Option<bool>` (un bit por (pieza,bucket)),
#        `subspace-farmer-components/src/sector.rs:582-608`; el bucket se recorre con
#        `iter_s_bucket_records` (`:521-552`).
#   E4 · El chunk es un escalar de 32 bytes (`ScalarBytes::FULL_BYTES = 32`,
#        `subspace-core-primitives/src/lib.rs:255-258`), almacenado por (pieza, bucket).
#   E5 · Gana si `is_within_solution_range(global_challenge, chunk, sector_slot_challenge,
#        rango)` (`subspace-verification/src/lib.rs:150-159`, `:239-272`).
#   E6 · Un productor honesto reclama **como mucho un bloque por slot**; las demás
#        soluciones se saltan (`sc-consensus-subspace/src/slot_worker.rs:571-592`).
#
# SUPUESTOS DECLARADOS DEL JUGUETE:
#   H1 · Tabla de chunks INYECTIVA (equivalent al escalar de 32 bytes: sin colisiones de
#        valor entre piezas). El cruce A/B se estudia aparte reduciendo el dominio.
#   H2 · El bucket es función de (slot, flujo) y NO de la pieza.
#   H3 · `PlotBatchId` de C compromete (pk, historia); con eso C ≡ B en el juguete.
#   H4 · La entropía usa SHA3-256 como sustituto determinista de blake3.

# ---------------------------------------------------------------------------
# Universo enumerado
# ---------------------------------------------------------------------------
const W_DOM    = 2
const W_SLOT   = 8
const W_PK     = 3
const W_SECTOR = 2
const W_HIST   = 2
const W_PIEZA  = 4
const W_BUCKET = 4
const W_FLOW   = 2

const N_DOM    = 1 << W_DOM      # 4   dominios económicos distinguibles
const N_SLOT   = 1 << W_SLOT     # 256 slots
const N_PK     = 1 << W_PK       # 8   claves
const N_SECTOR = 1 << W_SECTOR   # 4   sectores por clave
const N_HIST   = 1 << W_HIST     # 4   tamaños de historia
const N_PIEZA  = 1 << W_PIEZA    # 16  piece_offset por sector
const N_BUCKET = 1 << W_BUCKET   # 16  s-buckets (el real: 65536 = 2^16)
const N_FLOW   = 1 << W_FLOW     # 4   flujos

"Dominio económico de red/era del juguete (no es parámetro de consenso)."
const DOMINIO = UInt64(1)

# ---------------------------------------------------------------------------
# Mezclador determinista y reproducible (splitmix64). NO es criptográfico: solo
# construye funciones deterministas y auditables del juguete.
# ---------------------------------------------------------------------------
function mezclar(x::UInt64)::UInt64
    z = x + 0x9E3779B97F4A7C15
    z = (z ⊻ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ⊻ (z >> 27)) * 0x94D049BB133111EB
    return z ⊻ (z >> 31)
end
mezclar2(a::Integer, b::Integer)::UInt64 = mezclar(mezclar(UInt64(a)) ⊻ (UInt64(b) * 0xD6E8FEB86659FD93))

# ---------------------------------------------------------------------------
# Tabla de chunks almacenados (E4) y bucket del reto (E2)
# ---------------------------------------------------------------------------
"""
Número de bits efectivos del dominio de VALOR del chunk. Con `W_CHUNK_BITS = 40` el
modelo reproduce «32 bytes, sin colisiones»; bajarlo introduce colisiones de valor entre
piezas distintas, que es el único modo en que A y B pueden cruzarse (no refinarse).
"""
const W_CHUNK_BITS = 40

const COLISION_CHUNK = Ref{Int}(W_CHUNK_BITS)

"Chunk almacenado para (pk, sector, historia, pieza, bucket). Inyectivo salvo COLISION_CHUNK."
function chunk_almacenado(pk::Integer, sector::Integer, historia::Integer,
                          pieza::Integer, bucket::Integer)::UInt64
    x = mezclar2(pieza + 1024 * bucket, mezclar2(pk + 64 * sector, historia + 16))
    return x >>> (64 - COLISION_CHUNK[])
end

"""
Bucket auditado (E2). Depende de (slot, flujo) y del sector —nunca de la pieza.
`flujo` entra como símbolo; dos ramas con el mismo flujo comparten bucket y reto.
"""
function bucket_de(pk::Integer, sector::Integer, historia::Integer,
                   slot::Integer, flujo::Integer)::UInt64
    x = mezclar2(slot + 4096 * flujo, mezclar2(pk + 64 * sector, historia + 16))
    return x % N_BUCKET
end

# ---------------------------------------------------------------------------
# Solución de juguete
# ---------------------------------------------------------------------------
"""
Solución PoAS de juguete. `sr` fija el peso `w = ⌊2^128/(SR+1)⌋` de GDR; `sd` entra en
`rank` (C-ORD-01). `flujo` y `bucket` NO son campos de la solución real (el bucket lo
deriva el verificador); aquí se llevan para poder auditar la coherencia del fixture.

El constructor `solucion(...)` DERIVA `chunk` y `bucket` de la estructura E2–E4; no se
declaran a mano.
"""
struct Solucion
    pk::UInt64
    sector::UInt64
    historia::UInt64
    pieza::UInt64      # piece_offset
    chunk::UInt64      # valor del escalar almacenado
    slot::UInt64
    flujo::UInt64
    bucket::UInt64
    sr::UInt64
    sd::UInt64
end

"Tupla de la OPORTUNIDAD física: el recurso que un granjero lee en un slot."
oportunidad(s::Solucion) = (s.slot, s.pk, s.sector, s.historia, s.pieza)

function solucion(; pk::Integer, sector::Integer, historia::Integer, pieza::Integer,
                  slot::Integer, flujo::Integer, sr::Integer=0, sd::Integer=0)
    b = bucket_de(pk, sector, historia, slot, flujo)
    c = chunk_almacenado(pk, sector, historia, pieza, b)
    return Solucion(UInt64(pk), UInt64(sector), UInt64(historia), UInt64(pieza),
                    c, UInt64(slot), UInt64(flujo), b, UInt64(sr), UInt64(sd))
end

# ---------------------------------------------------------------------------
# Codificación inyectiva de las tres identidades
# ---------------------------------------------------------------------------
"""
Empaqueta campos en un `UInt64` con anchos declarados. Un campo fuera de su ancho es un
fixture mal formado, no un caso de borde. Devuelve `empaquetado + 1` para reservar el `0`
que GDR usa como «sin billete».
"""
function empaquetar(campos::NTuple{N,Integer}, anchos::NTuple{N,Int}) where {N}
    x = UInt64(0); bits = 0
    for i in 1:N
        v = UInt64(campos[i]); w = anchos[i]
        v < (UInt64(1) << w) || throw(DomainError(v, "campo $i fuera del ancho $w"))
        x |= v << bits
        bits += w
    end
    bits <= 63 || throw(ArgumentError("codificación de $bits bits: no cabe con el 0 reservado"))
    return x + UInt64(1)
end

@enum ModoId::UInt8 begin
    MODO_A = 1   # C-GD-07 / R-FIN-11: (public_key, sector_index, history_size, chunk, slot)
    MODO_B = 2   # IDV-01: (dominio, slot, public_key, sector_index, history_size, piece_offset)
    MODO_C = 3   # candidata: H(dominio, slot, PlotBatchId, sector_index, piece_offset)
end

const NOMBRE_MODO = Dict(MODO_A => "A · C-GD-07 (con chunk)",
                         MODO_B => "B · IDV-01 (con piece_offset)",
                         MODO_C => "C · candidata (PlotBatchId)")

"""
Identidad de billete de `s` bajo el modo `m`, como entero denso inyectivo.

- A no lleva dominio (el SPEC no lo incluye) ni `piece_offset`.
- B y C sí llevan dominio y no llevan `chunk`.
- C lleva `PlotBatchId` = (pk, historia) por H3, así que B y C particionan igual; la
  sensibilidad a que el lote NO determine `history_size` se mide con `MODO_C_SIN_HIST`.
"""
function identidad(m::ModoId, s::Solucion)::UInt64
    if m == MODO_A
        return empaquetar((s.slot, s.pk, s.sector, s.historia, s.chunk),
                          (W_SLOT, W_PK, W_SECTOR, W_HIST, W_CHUNK_BITS_A))
    elseif m == MODO_B
        return empaquetar((DOMINIO, s.slot, s.pk, s.sector, s.historia, s.pieza),
                          (W_DOM, W_SLOT, W_PK, W_SECTOR, W_HIST, W_PIEZA))
    else
        # H(dominio, slot, PlotBatchId, sector_index, piece_offset), PlotBatchId := (pk, historia)
        return empaquetar((DOMINIO, s.slot, s.pk, s.historia, s.sector, s.pieza),
                          (W_DOM, W_SLOT, W_PK, W_HIST, W_SECTOR, W_PIEZA))
    end
end

# El `chunk` real es un escalar de 32 bytes: no cabe en el empaquetado denso. Para que A
# sea EXACTA como relación (y no por truncar el chunk) se usa una clave de 63 bits que
# solo exige que el chunk entre sin colisión con los demás campos; con COLISION_CHUNK
# alto los chunks del universo pequeño son distintos dos a dos.
const W_CHUNK_BITS_A = W_CHUNK_BITS
@assert W_SLOT + W_PK + W_SECTOR + W_HIST + W_CHUNK_BITS_A <= 63 "A no cabe en 63 bits"

"A-igualdad sin pasar por `empaquetar` (evita el límite de bits): tupla directa."
clave_a(s::Solucion) = (s.slot, s.pk, s.sector, s.historia, s.chunk)

# ---------------------------------------------------------------------------
# Entropía de la inyección, C-FLU-12
# ---------------------------------------------------------------------------
"pot_output de juguete (H4): función exclusiva de (slot, flujo)."
pot_output(slot::Integer, flujo::Integer)::UInt64 = mezclar2(slot, flujo + 1)

"""
`entropia_j = blake3(chunk(I_j) ‖ pot_output(I_j))`, aquí SHA3-256 (H4). Devuelve los 32
bytes; lo único que se usa es la IGUALDAD entre copias del mismo billete.
"""
function entropia(chunk::Integer, pot::Integer)::NTuple{32,UInt8}
    buf = Vector{UInt8}(undef, 16)
    c = UInt64(chunk); p = UInt64(pot)
    for i in 0:7
        buf[1 + i] = UInt8((c >> (8i)) & 0xff)
        buf[9 + i] = UInt8((p >> (8i)) & 0xff)
    end
    h = sha3_256(buf)
    return ntuple(i -> h[i], 32)
end

entropia_de(s::Solucion) = entropia(s.chunk, pot_output(s.slot, s.flujo))
