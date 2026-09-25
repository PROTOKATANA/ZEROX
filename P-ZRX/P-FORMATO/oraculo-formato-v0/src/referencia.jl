# Oráculo independiente — formatos v0 del ZEROX híbrido (ORDEN-W02)
#
# # Por qué existe
#
# Los tests Rust de `crates/zx-core` comprueban la implementación contra sí misma. Este oráculo
# **recomputa desde `FORMATO-v0.md` y desde el código de preimagen existente leído como
# especificación**, en otro lenguaje y sin traducir el Rust línea a línea. El test
# `crates/zx-core/tests/formato_v0.rs` compara byte a byte.
#
# # Qué cubre
#
# SHA3-256 (stdlib `SHA`), `H_d`, el árbol del `txid` v1/v2/v3 (F-06), el sub-digest de la
# extensión de garantía/coinbase PoST, el mensaje de aceptación (F-08) y la codificación de red de
# F-14 para v1/v2/v3. No firma: las claves y testigos de los vectores son bytes fijos de prueba;
# la firma de aceptación se comprueba en Rust.
#
# Referencias: `P-ZRX/P-FORMATO/FORMATO-v0.md` F-05…F-08, F-12, F-14; y el código de preimagen
# (`hash.rs`, `preimage/tx.rs`, `wire.rs`) leído como especificación de los dominios y del orden.

module ReferenciaFormatoV0

using SHA

# ── little-endian explícito (independiente del endianness del host) ──────────

lebytes(x::UInt8) = UInt8[x]
lebytes(x::UInt16) = UInt8[(x >> (8 * i)) & 0xff for i in 0:1]
lebytes(x::UInt32) = UInt8[(x >> (8 * i)) & 0xff for i in 0:3]
lebytes(x::UInt64) = UInt8[(x >> (8 * i)) & 0xff for i in 0:7]
lebytes(x::Int64) = lebytes(reinterpret(UInt64, x))

# ── parámetros de red (F-12 y C-NET-01) ──────────────────────────────────────

# F-12: primeros 4 bytes, en little-endian, de SHA3-256("ZEROX hibrido red dev v0").
const CBID_RED_DEV = 0xa8b466a7
# Un `CONSENSUS_BRANCH_ID` distinto para separar dominios en los vectores.
const CBID_OTRO = 0x01020304
# El CBID de los vectores antiguos de [1, 2, 3] de la cabecera DAG.
const CBID_ANTIGUO = 0xc47880ea
# C-NET-01: primeros 4 bytes de SHA3-256("ZEROX/dev/magic").
const MAGIC_DEV = UInt8[0xdb, 0x34, 0x78, 0x47]

# ── CompactSize minimal (C-ENC-05, SPEC §2.2) ────────────────────────────────

function compact_size(v::Integer)
    if v < 0xfd
        return UInt8[v]
    elseif v <= 0xffff
        return vcat(UInt8[0xfd], lebytes(UInt16(v)))
    elseif v <= 0xffffffff
        return vcat(UInt8[0xfe], lebytes(UInt32(v)))
    else
        return vcat(UInt8[0xff], lebytes(UInt64(v)))
    end
end

# ── H_d con etiqueta de 16 bytes (C-HASH-04) ─────────────────────────────────
#
# La etiqueta se declara como literal de 16 bytes y el `@assert` la fija: no hay padding
# silencioso, porque una etiqueta de 15 bytes sería otro dominio.

function tag_lit(s::AbstractString)
    b = Vector{UInt8}(codeunits(s))
    @assert length(b) == 16 "la etiqueta debe medir 16 bytes: $(s) mide $(length(b))"
    return b
end

# Raíz del txid: 12 ASCII `ZZKTxIdHash_` + CBID en u32 LE (SPEC §4.5).
raiz_tag(cbid::UInt32) = vcat(Vector{UInt8}(codeunits("ZZKTxIdHash_")), lebytes(cbid))

h_d(tag::Vector{UInt8}, msg::Vector{UInt8}) = SHA.sha3_256(vcat(tag, msg))

sha3_vacio() = SHA.sha3_256(UInt8[])

# ── Locks (C-TX-09, P-020: P2K) ──────────────────────────────────────────────

const DISC_PUBKEY = 0x00
const DISC_MULTISIG = 0x01
const DISC_HTLC = 0x02

function lock_pubkey(pk::Vector{UInt8})
    @assert length(pk) == 32 "la clave pública debe medir 32 bytes"
    return vcat(UInt8[DISC_PUBKEY], pk)
end

function lock_multisig(k::Integer, pubkeys::Vector{Vector{UInt8}})
    b = vcat(UInt8[DISC_MULTISIG, UInt8(k)], compact_size(length(pubkeys)))
    for p in pubkeys
        b = vcat(b, p)
    end
    return b
end

function lock_htlc(hash::Vector{UInt8}, receiver::Vector{UInt8}, sender::Vector{UInt8}, timeout::Integer)
    @assert length(hash) == 32
    return vcat(UInt8[DISC_HTLC], hash, receiver, sender, lebytes(UInt32(timeout)))
end

# ── Tipos del escenario ──────────────────────────────────────────────────────

struct Entrada
    prev_txid::Vector{UInt8}
    prev_index::UInt32
    sequence::UInt32
end

struct Salida
    valor::Int64
    lock::Vector{UInt8}
end

struct TxSpec
    version::UInt32
    lock_time::UInt32
    expiry::UInt32
    entradas::Vector{Entrada}
    salidas::Vector{Salida}
    tipo::Union{Nothing,UInt8}
    clave::Union{Nothing,Vector{UInt8}}
    importe::Union{Nothing,Int64}
end

tx_v1(entradas::Vector{Entrada}, salidas::Vector{Salida}) =
    TxSpec(1, 0, 0, entradas, salidas, nothing, nothing, nothing)

tx_v2(entradas::Vector{Entrada}, salidas::Vector{Salida}, tipo::Integer, clave::Vector{UInt8}, importe::Integer) =
    TxSpec(2, 0, 0, entradas, salidas, UInt8(tipo), clave, Int64(importe))

tx_v3(clave::Vector{UInt8}, importe::Integer) =
    TxSpec(3, 0, 0, Entrada[], Salida[], nothing, clave, Int64(importe))

# ── Árbol del txid (F-06) y mensaje de aceptación (F-08) ─────────────────────

function header_digest(tx::TxSpec)
    m = vcat(lebytes(tx.version), lebytes(tx.lock_time), lebytes(tx.expiry))
    return h_d(tag_lit("ZZKTxIdHeader___"), m)
end

function prevouts_digest(tx::TxSpec)
    m = UInt8[]
    for e in tx.entradas
        m = vcat(m, e.prev_txid, lebytes(e.prev_index))
    end
    return h_d(tag_lit("ZZKTxIdPrevout__"), m)
end

function sequence_digest(tx::TxSpec)
    m = UInt8[]
    for e in tx.entradas
        m = vcat(m, lebytes(e.sequence))
    end
    return h_d(tag_lit("ZZKTxIdSequence_"), m)
end

function inputs_digest(tx::TxSpec)
    return h_d(tag_lit("ZZKTxIdInputs___"), vcat(prevouts_digest(tx), sequence_digest(tx)))
end

function outputs_digest(tx::TxSpec)
    m = UInt8[]
    for s in tx.salidas
        m = vcat(m, lebytes(s.valor), s.lock)
    end
    return h_d(tag_lit("ZZKTxIdOutputs__"), m)
end

# Campos extra en el orden de F-05/F-06, sin prefijo de longitud.
function campos_extra(tx::TxSpec)
    if tx.version == 0x01
        return UInt8[]
    elseif tx.version == 0x02
        @assert tx.tipo !== nothing && tx.clave !== nothing && tx.importe !== nothing
        return vcat(UInt8[tx.tipo], tx.clave, lebytes(UInt64(tx.importe)))
    elseif tx.version == 0x03
        @assert tx.clave !== nothing && tx.importe !== nothing
        return vcat(tx.clave, lebytes(UInt64(tx.importe)))
    else
        error("versión no soportada por el oráculo: $(tx.version)")
    end
end

extension_digest(tx::TxSpec) = h_d(tag_lit("ZZKTxIdGarantia_"), campos_extra(tx))

function txid(tx::TxSpec, cbid::UInt32)
    m = vcat(header_digest(tx), inputs_digest(tx), outputs_digest(tx))
    if tx.version == 0x02 || tx.version == 0x03
        m = vcat(m, extension_digest(tx))
    end
    return h_d(raiz_tag(cbid), m)
end

# F-08: Ed25519 sobre H_d("ZZKTxSigGarant__", txid) (32 B). Aquí solo el mensaje.
mensaje_aceptacion(tx::TxSpec, cbid::UInt32) = h_d(tag_lit("ZZKTxSigGarant__"), txid(tx, cbid))

# ── Codificación de red (F-14) ───────────────────────────────────────────────

function tx_wire(tx::TxSpec, testigos::Vector{Vector{UInt8}})
    b = UInt8[]
    b = vcat(b, lebytes(tx.version), lebytes(tx.lock_time), lebytes(tx.expiry))
    b = vcat(b, compact_size(length(tx.entradas)))
    for e in tx.entradas
        b = vcat(b, e.prev_txid, lebytes(e.prev_index), lebytes(e.sequence))
    end
    b = vcat(b, compact_size(length(tx.salidas)))
    for s in tx.salidas
        b = vcat(b, lebytes(s.valor), s.lock)
    end
    b = vcat(b, campos_extra(tx))
    b = vcat(b, compact_size(length(testigos)))
    for t in testigos
        b = vcat(b, compact_size(length(t)), t)
    end
    return b
end

# ── Anclas v1 antiguas (requisito §9(b) de ORDEN-W02) ────────────────────────
#
# [1] y [2] son los `txid1`/`txid2` congelados en `testdata/vectores-cabecera-dag/vectores.txt`
# (citados por `tests/oraculo_julia.rs` y `tests/vectores_dag.rs`).
# [3] es el `txid` del escenario `tx_ejemplo()` de los tests unitarios de
# `crates/zx-core/src/preimage/tx.rs`; se congeló con el código antiguo (commit 29b6bd6) antes de
# tocar `zx-core` y aquí se reproduce desde el SPEC.

function tx_antiguo(n::UInt8, valor::Integer)
    ents = [Entrada(fill(n, 32), UInt32(n), UInt32(0xffff_fffe))]
    sals = [Salida(Int64(valor), lock_pubkey(fill(n, 32)))]
    return tx_v1(ents, sals)
end

function tx_ancla_3()
    ents = [
        Entrada(fill(UInt8(1), 32), UInt32(1), UInt32(0xffff_ffff)),
        Entrada(fill(UInt8(2), 32), UInt32(2), UInt32(0)),
    ]
    sals = [
        Salida(50_000, lock_pubkey(fill(UInt8(10), 32))),
        Salida(25_000, lock_pubkey(fill(UInt8(11), 32))),
    ]
    return tx_v1(ents, sals)
end

const ANCLA_1 = "2c0c8801d8aafcf82556caf2197d41a699e2355c10ad71beb39b13e0d445432c"
const ANCLA_2 = "cc22d38fa5021ce74f30c0d7258ef6bbf55a8280bbd146300431b2d3e6e95f5b"
const ANCLA_3 = "c722c4f8a2edc1c092b4d494e6e287df2bc88ab79b9d4568f609f8eef9ce3bc6"

# ── Casos nuevos (≥ 12) ──────────────────────────────────────────────────────
#
# Claves, testigos y salidas son bytes fijos de prueba. El importe de la extensión se escribe en
# `u64` (F-05); el de las salidas, en `i64` (el códec antiguo de `outputs_digest`).

function casos()
    return [
        # v1 · transferencia
        (nombre = "v1_transferencia_dev", cbid = CBID_RED_DEV, testigos = [fill(UInt8(0x33), 64)],
         tx = tx_v1([Entrada(fill(UInt8(0x11), 32), 0, 0xffff_fffe)],
                    [Salida(12_345, lock_pubkey(fill(UInt8(0xa1), 32)))])),
        (nombre = "v1_transferencia_otro", cbid = CBID_OTRO, testigos = [fill(UInt8(0x33), 64)],
         tx = tx_v1([Entrada(fill(UInt8(0x11), 32), 0, 0xffff_fffe)],
                    [Salida(12_345, lock_pubkey(fill(UInt8(0xa1), 32)))])),
        # v1 · coinbase PoW (sin entradas ni testigos)
        (nombre = "v1_coinbase_pow_dev", cbid = CBID_RED_DEV, testigos = Vector{UInt8}[],
         tx = tx_v1(Entrada[], [Salida(5_000_000_000, lock_pubkey(fill(UInt8(0xb2), 32)))])),
        # v2 · depósito con cambio
        (nombre = "v2_deposito_1in_cambio_dev", cbid = CBID_RED_DEV,
         testigos = [fill(UInt8(0x44), 64), fill(UInt8(0x55), 64)],
         tx = tx_v2([Entrada(fill(UInt8(0x21), 32), 1, 0xffff_fffe)],
                    [Salida(1_000, lock_pubkey(fill(UInt8(0xc3), 32)))], 1,
                    fill(UInt8(0xd4), 32), 9_000)),
        (nombre = "v2_deposito_1in_cambio_otro", cbid = CBID_OTRO,
         testigos = [fill(UInt8(0x44), 64), fill(UInt8(0x55), 64)],
         tx = tx_v2([Entrada(fill(UInt8(0x21), 32), 1, 0xffff_fffe)],
                    [Salida(1_000, lock_pubkey(fill(UInt8(0xc3), 32)))], 1,
                    fill(UInt8(0xd4), 32), 9_000)),
        # v2 · depósito sin cambio
        (nombre = "v2_deposito_1in_sin_cambio_dev", cbid = CBID_RED_DEV,
         testigos = [fill(UInt8(0x44), 64), fill(UInt8(0x55), 64)],
         tx = tx_v2([Entrada(fill(UInt8(0x21), 32), 1, 0xffff_fffe)], Salida[],
                    1, fill(UInt8(0xd5), 32), 9_000)),
        # v2 · depósito de 3 entradas con cambio
        (nombre = "v2_deposito_3in_cambio_dev", cbid = CBID_RED_DEV,
         testigos = [fill(UInt8(0x61), 64), fill(UInt8(0x62), 64),
                     fill(UInt8(0x63), 64), fill(UInt8(0x64), 64)],
         tx = tx_v2([Entrada(fill(UInt8(0x31), 32), 0, 0xffff_fffe),
                     Entrada(fill(UInt8(0x32), 32), 2, 0),
                     Entrada(fill(UInt8(0x33), 32), 5, 1)],
                    [Salida(700, lock_pubkey(fill(UInt8(0xc3), 32)))], 1,
                    fill(UInt8(0xd4), 32), 7_000)),
        (nombre = "v2_deposito_3in_cambio_otro", cbid = CBID_OTRO,
         testigos = [fill(UInt8(0x61), 64), fill(UInt8(0x62), 64),
                     fill(UInt8(0x63), 64), fill(UInt8(0x64), 64)],
         tx = tx_v2([Entrada(fill(UInt8(0x31), 32), 0, 0xffff_fffe),
                     Entrada(fill(UInt8(0x32), 32), 2, 0),
                     Entrada(fill(UInt8(0x33), 32), 5, 1)],
                    [Salida(700, lock_pubkey(fill(UInt8(0xc3), 32)))], 1,
                    fill(UInt8(0xd4), 32), 7_000)),
        # v2 · depósito de 3 entradas sin cambio
        (nombre = "v2_deposito_3in_sin_cambio_dev", cbid = CBID_RED_DEV,
         testigos = [fill(UInt8(0x61), 64), fill(UInt8(0x62), 64),
                     fill(UInt8(0x63), 64), fill(UInt8(0x64), 64)],
         tx = tx_v2([Entrada(fill(UInt8(0x31), 32), 0, 0xffff_fffe),
                     Entrada(fill(UInt8(0x32), 32), 2, 0),
                     Entrada(fill(UInt8(0x33), 32), 5, 1)],
                    Salida[], 1, fill(UInt8(0xd4), 32), 7_000)),
        # v2 · retiro (tipo 2)
        (nombre = "v2_retiro_dev", cbid = CBID_RED_DEV, testigos = [fill(UInt8(0x71), 64)],
         tx = tx_v2(Entrada[], Salida[], 2, fill(UInt8(0xe6), 32), 2_500)),
        (nombre = "v2_retiro_otro", cbid = CBID_OTRO, testigos = [fill(UInt8(0x71), 64)],
         tx = tx_v2(Entrada[], Salida[], 2, fill(UInt8(0xe6), 32), 2_500)),
        # v2 · liberación (tipo 3)
        (nombre = "v2_liberacion_dev", cbid = CBID_RED_DEV, testigos = [fill(UInt8(0x72), 64)],
         tx = tx_v2(Entrada[], Salida[], 3, fill(UInt8(0xf7), 32), 2_500)),
        # v3 · coinbase PoST (sin entradas, salidas ni testigos)
        (nombre = "v3_coinbase_post_dev", cbid = CBID_RED_DEV, testigos = Vector{UInt8}[],
         tx = tx_v3(fill(UInt8(0x1a), 32), 5_000_000_000)),
        (nombre = "v3_coinbase_post_otro", cbid = CBID_OTRO, testigos = Vector{UInt8}[],
         tx = tx_v3(fill(UInt8(0x1a), 32), 5_000_000_000)),
    ]
end

end # module
