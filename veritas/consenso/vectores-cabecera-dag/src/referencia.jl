# Oráculo independiente — vectores de la cabecera DAG (H-08a)
#
# # Por qué existe
#
# Los vectores congelados de `crates/zx-core/tests/vectores_dag.rs` se generaron con la propia
# implementación Rust. Eso caza regresiones, pero **no** detecta que la implementación esté mal
# desde el principio. Este oráculo **recomputa desde el SPEC** —§2.2, §3, §4.2, §4.4 y §6.1–6.2—
# sin tocar el código Rust, y el test compara.
#
# # Qué NO hace
#
# No verifica firmas ni PoT. Solo la codificación canónica y los hashes. El sello del escenario son
# 64 ceros: no se firma nada.
#
# Referencia: `SPEC.md` §2.2 (CompactSize), §3 (H_d), §4.2 (txid), §4.4 (auth_digest), §6.1–6.2
# (cabecera DAG, pre_hash, block_hash) y el compromiso de cuerpo de la nota de §6.1.

using SHA

# ── little-endian explícito (no dependemos del endianness del host) ───────────

lebytes(x::UInt16) = UInt8[(x >> (8 * i)) & 0xff for i in 0:1]
lebytes(x::UInt32) = UInt8[(x >> (8 * i)) & 0xff for i in 0:3]
lebytes(x::UInt64) = UInt8[(x >> (8 * i)) & 0xff for i in 0:7]
lebytes(x::Int64) = lebytes(reinterpret(UInt64, x))
lebytes(x::Integer) = lebytes(UInt64(x))

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

function tag16(s::AbstractString)
    b = Vector{UInt8}(codeunits(s))
    @assert length(b) <= 16 "etiqueta más larga que 16 bytes: $s"
    return vcat(b, fill(UInt8(0x5f), 16 - length(b)))
end

h_d(tag::Vector{UInt8}, msg::Vector{UInt8}) = sha3_256(vcat(tag, msg))
h_d(s::AbstractString, msg::Vector{UInt8}) = h_d(tag16(s), msg)

# La raíz del txid: 12 ASCII + CBID en u32 LE (SPEC §4.5).
function raiz_tag(cbid::UInt32)
    b = vcat(Vector{UInt8}(codeunits("ZZKTxIdHash_")), lebytes(cbid))
    @assert length(b) == 16
    return b
end

# ── Estructuras del escenario ────────────────────────────────────────────────

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
end

# C-TX-09, P-020: P2K, la clave en claro; discriminante 0x00.
function lock_pubkey(pk::Vector{UInt8})
    @assert length(pk) == 32
    return vcat(UInt8[0x00], pk)
end

# ── Árboles de hashes del SPEC §4.2 y §4.4 ───────────────────────────────────

function txid(tx::TxSpec, cbid::UInt32)
    header = h_d("ZZKTxIdHeader___", vcat(lebytes(tx.version), lebytes(tx.lock_time), lebytes(tx.expiry)))

    prev = UInt8[]
    for e in tx.entradas
        prev = vcat(prev, e.prev_txid, lebytes(e.prev_index))
    end
    prev_d = h_d("ZZKTxIdPrevout__", prev)

    seq = UInt8[]
    for e in tx.entradas
        seq = vcat(seq, lebytes(e.sequence))
    end
    seq_d = h_d("ZZKTxIdSequence_", seq)

    inputs = h_d("ZZKTxIdInputs___", vcat(prev_d, seq_d))

    outs = UInt8[]
    for s in tx.salidas
        outs = vcat(outs, lebytes(s.valor), s.lock)
    end
    outs_d = h_d("ZZKTxIdOutputs__", outs)

    return h_d(raiz_tag(cbid), vcat(header, inputs, outs_d))
end

function auth_digest(testigos::Vector{Vector{UInt8}})
    m = UInt8[]
    for w in testigos
        m = vcat(m, compact_size(length(w)), w)
    end
    return h_d("ZZKTxAuthHash___", m)
end

function body_commitment(pares::Vector{Tuple{Vector{UInt8},Vector{UInt8}}})
    m = compact_size(length(pares))
    for (t, a) in pares
        m = vcat(m, t, a)
    end
    return h_d("ZZKBlkBodyHash__", m)
end

# C-BLK-02/03: nodos internos con etiqueta; hoja suelta con nulo, nunca duplicada.
function merkle_root(hojas::Vector{Vector{UInt8}})
    if isempty(hojas)
        return h_d("ZZKBlkMerkle____", UInt8[])
    end
    nivel = copy(hojas)
    while true
        sig = Vector{UInt8}[]
        i = 1
        while i <= length(nivel)
            if i + 1 <= length(nivel)
                push!(sig, h_d("ZZKBlkMerkle____", vcat(nivel[i], nivel[i + 1])))
            else
                push!(sig, h_d("ZZKBlkMerkle____", vcat(nivel[i], zeros(UInt8, 32))))
            end
            i += 2
        end
        if length(sig) == 1
            return sig[1]
        end
        nivel = sig
    end
end

# ── Cabecera DAG (SPEC §6.1–6.2) ─────────────────────────────────────────────

struct Cabecera
    cbid::UInt32
    prev::Vector{UInt8}
    merkle::Vector{UInt8}
    timestamp::UInt64
    height::UInt32
    slot::UInt64
    pot_output::Vector{UInt8}
    rango::UInt64
    pubkey::Vector{UInt8}
    sector_index::UInt16
    history_size::UInt64
    piece_offset::UInt16
    record_commitment::Vector{UInt8}
    record_witness::Vector{UInt8}
    chunk::Vector{UInt8}
    chunk_witness::Vector{UInt8}
    proof_of_space::Vector{UInt8}
    body::Vector{UInt8}
    extras::Vector{Vector{UInt8}}
    seal::Vector{UInt8}
end

function cabecera_bytes(c::Cabecera)
    b = UInt8[]
    b = vcat(b, lebytes(c.cbid))
    b = vcat(b, c.prev)
    b = vcat(b, c.merkle)
    b = vcat(b, lebytes(c.timestamp))
    b = vcat(b, lebytes(c.height))
    b = vcat(b, lebytes(c.slot))
    b = vcat(b, c.pot_output)
    b = vcat(b, lebytes(c.rango))
    b = vcat(b, c.pubkey)
    b = vcat(b, lebytes(c.sector_index))
    b = vcat(b, lebytes(c.history_size))
    b = vcat(b, lebytes(c.piece_offset))
    b = vcat(b, c.record_commitment)
    b = vcat(b, c.record_witness)
    b = vcat(b, c.chunk)
    b = vcat(b, c.chunk_witness)
    b = vcat(b, c.proof_of_space)
    b = vcat(b, c.body)
    b = vcat(b, UInt8[1 + length(c.extras)])
    for e in c.extras
        b = vcat(b, e)
    end
    b = vcat(b, c.seal)
    @assert length(b) == 589 + 32 * length(c.extras)
    return b
end

pre_hash(c::Cabecera) = h_d("ZZKBlkPreHash___", cabecera_bytes(c)[1:end-64])
block_hash(c::Cabecera) = h_d("ZZKBlkHeader____", cabecera_bytes(c))

# ── Escenario congelado ──────────────────────────────────────────────────────
#
# Es el mismo de `crates/zx-core/tests/vectores_dag.rs`: rama 0xc47880ea, P = 2, dos
# transacciones, sello de 64 ceros.

const CBID = UInt32(0xc47880ea)

function tx_del_escenario(n::UInt8, valor::Int64)
    return TxSpec(
        UInt32(1),
        UInt32(0),
        UInt32(0),
        [Entrada(fill(n, 32), UInt32(n), UInt32(0xffff_fffe))],
        [Salida(valor, lock_pubkey(fill(n, 32)))],
    )
end

function vectores()
    tx1 = tx_del_escenario(UInt8(1), Int64(5_000))
    tx2 = tx_del_escenario(UInt8(2), Int64(3_000))
    txids = [txid(tx1, CBID), txid(tx2, CBID)]

    testigos = [fill(UInt8(0x11), 64), fill(UInt8(0x22), 65)]
    auths = [auth_digest([testigos[1]]), auth_digest([testigos[2]])]
    cuerpo = body_commitment([(txids[1], auths[1]), (txids[2], auths[2])])
    merkle = merkle_root(txids)

    cabecera = Cabecera(
        CBID,
        fill(UInt8(0x10), 32),
        merkle,
        UInt64(1_788_480_000),
        UInt32(7),
        UInt64(1234),
        fill(UInt8(0xab), 16),
        UInt64(999),
        fill(UInt8(0x7a), 32),
        UInt16(5),
        UInt64(1) << 40,
        UInt16(3),
        fill(UInt8(0x01), 48),
        fill(UInt8(0x02), 48),
        fill(UInt8(0x03), 32),
        fill(UInt8(0x04), 48),
        fill(UInt8(0x05), 160),
        cuerpo,
        [fill(UInt8(0x20), 32)],
        zeros(UInt8, 64),
    )

    return (
        wire = cabecera_bytes(cabecera),
        pre_hash = pre_hash(cabecera),
        block_hash = block_hash(cabecera),
        body_commitment = cuerpo,
        merkle_root = merkle,
        txid1 = txids[1],
        txid2 = txids[2],
        auth1 = auths[1],
        auth2 = auths[2],
    )
end
