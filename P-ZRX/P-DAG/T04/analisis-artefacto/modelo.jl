# GDR-v0.1 — modelo: tipos, aritmética exacta de blue_work, pesos y comparadores.
# Instrumento de estudio; ninguna regla de consenso se decide aquí.

"""
Id de bloque: 32 bytes. La comparación es lexicográfica de bytes, como el `Ord` de
`kaspa_hashes::Hash` sobre `[u8;32]` (rusty-kaspa, crypto/hashes/src/lib.rs:38-46).
Los ids textuales cortos se rellenan con ceros a la derecha (como `string_to_hash` de
consensus_integration_tests.rs:343-347). Supuesto declarado: no hay colisión de hash.
"""
const ID32 = NTuple{32,UInt8}

function hash_de_id(s::String)::ID32
    b = codeunits(s)
    length(b) <= 32 || error("id textual de más de 32 bytes: $(repr(s))")
    return ntuple(i -> i <= length(b) ? b[i] : 0x00, 32)
end

# ---------------------------------------------------------------------------
# blue_work del kernel: dominio declarado [0, 2^256-1], sin desbordamiento silencioso.
# La política de desbordamiento está PENDIENTE en el SPEC (§11, SPEC.md:1548-1551); este
# instrumento lanza OverflowError y mide cuántos bits necesita blue_work en cada corrida.
# ---------------------------------------------------------------------------
struct BW256
    hi::UInt128
    lo::UInt128
end

const BW256_CERO = BW256(UInt128(0), UInt128(0))
const BW256_DOS128 = BW256(UInt128(1), UInt128(0))   # 2^128

Base.isless(a::BW256, b::BW256) = a.hi < b.hi || (a.hi == b.hi && a.lo < b.lo)
Base.:(==)(a::BW256, b::BW256) = a.hi == b.hi && a.lo == b.lo
Base.zero(::Type{BW256}) = BW256_CERO

function Base.:+(a::BW256, b::BW256)
    lo, c1 = Base.add_with_overflow(a.lo, b.lo)
    hi1, c2 = Base.add_with_overflow(a.hi, b.hi)
    hi, c3 = Base.add_with_overflow(hi1, c1 ? UInt128(1) : UInt128(0))
    (c2 | c3) && throw(OverflowError("blue_work fuera del dominio declarado [0, 2^256-1]"))
    return BW256(hi, lo)
end

function Base.:-(a::BW256, b::BW256)
    a >= b || throw(DomainError("blue_work negativo"))
    lo, borrow = Base.sub_with_overflow(a.lo, b.lo)
    hi1, borrow2 = Base.sub_with_overflow(a.hi, b.hi)
    @assert !borrow2 "resta BW256 incoherente"
    return BW256(borrow ? hi1 - UInt128(1) : hi1, lo)
end

BW256(x::UInt64) = BW256(UInt128(0), UInt128(x))
BW256(x::UInt128) = BW256(UInt128(0), x)

function BW256(x::BigInt)
    (0 <= x < big(2)^256) || throw(OverflowError("fuera del dominio BW256"))
    return BW256(UInt128(x >> 128), UInt128(x & (big(2)^128 - 1)))
end

function Base.BigInt(b::BW256)::BigInt
    return (BigInt(b.hi) << 128) | BigInt(b.lo)
end

"Bits necesarios para representar b (0 para el cero)."
function bits_necesarios(b::BW256)::Int
    b.hi != 0 && return 128 + (128 - leading_zeros(b.hi))
    b.lo != 0 && return 128 - leading_zeros(b.lo)
    return 0
end

# ---------------------------------------------------------------------------
# Peso exacto w(B) = ⌊2^128/(SR+1)⌋. SR es UInt64 ⇒ SR+1 ∈ [1, 2^64].
# SR=0 da 2^128 (no cabe en u128; aquí es BW256(1,0)). Todo UInt64 ⇒ w ≥ 2^64 > 0.
# ---------------------------------------------------------------------------
function peso(sr::UInt64)::BW256
    d = UInt128(sr) + UInt128(1)
    if d == UInt128(1)
        return BW256_DOS128
    end
    q_hi = fld(UInt128(1) << 64, d)     # 2^64 ÷ d ∈ [1, 2^63]
    r_hi = (UInt128(1) << 64) % d       # < d ≤ 2^64
    q_lo = fld(r_hi << 64, d)           # ≤ 2^128 − 1
    return BW256(UInt128(0), (q_hi << 64) | q_lo)
end

"Oráculo: misma fórmula en BigInt."
peso_big(sr::UInt64)::BigInt = fld(big(2)^128, BigInt(sr) + 1)

# ---------------------------------------------------------------------------
# Modos de desempate. Cada USO tiene su comparador explícito y separado.
#   (1) elección del padre seleccionado  -> sp_mode
#   (2) orden del mergeset para colorear -> merge_mode
#   (3) orden de aplicación (R-FIN-8′(4))-> merge_mode (misma clave, re-ordenando)
#   (4) rank para P1                      -> cmp_orden, ascendente (regla C)
# Direcciones históricas (véase DECISIONES-PENDIENTES.md, D-1/D-2, superadas por C):
#   :spec   (bw asc, sd asc, id asc), maximizado para sp  — ante empate elegía MAYOR sd y MAYOR id
#   :python (bw asc, sd DESC, id asc), maximizado para sp — menor sd, pero MAYOR id
#   :kaspa  (bw asc, id asc)                              — ordering.rs:38-42, sin sd
#
# **Regla C — DECIDIDO POR KATANA (2026-09-14), TAREAS.md §1.3 «Dirección de los
# desempates».** Orden del mergeset (colorear Y aplicar R-FIN-8′(4)): (bw, sd, hash)
# ascendente — esto YA es exactamente MERGE_SPEC/cmp_orden, sin cambios. Padre
# seleccionado y punta virtual: MAYOR blue_work; en empate, el que iría PRIMERO en
# ese mismo orden ascendente (MENOR sd, luego MENOR hash) — dirección MIXTA, no
# expresable como "máximo de la tupla ascendente" (eso es justo el error de
# SP_SPEC/SP_PYTHON que este modo corrige). `rank` para P1: la misma tupla
# ascendente, gana el menor — ya es cmp_orden/es_menor_rank, sin cambios.
# ---------------------------------------------------------------------------
@enum SpMode begin
    SP_SPEC
    SP_PYTHON
    SP_KASPA
    SP_ZEROX
end
@enum MergeMode begin
    MERGE_SPEC
    MERGE_PYTHON
    MERGE_KASPA
end
@enum U3Mode begin
    U3_OFF
    U3_FILTER
    U3_DYNAMIC
end

struct Params
    k::UInt32
    max_parents::UInt32
    mergeset_limit::UInt32
    s_max::UInt64
    u2::Bool
    u3_mode::U3Mode
    sp_mode::SpMode
    merge_mode::MergeMode
end

function Params(; k::Integer=30, max_parents::Integer=15, mergeset_limit::Integer=180,
                s_max::Integer=150, u2::Bool=true, u3_mode::U3Mode=U3_DYNAMIC,
                sp_mode::SpMode=SP_ZEROX, merge_mode::MergeMode=MERGE_SPEC)
    return Params(UInt32(k), UInt32(max_parents), UInt32(mergeset_limit),
                  UInt64(s_max), u2, u3_mode, sp_mode, merge_mode)
end

const P_DEFECTO = Params()

# ---------------------------------------------------------------------------
# Comparadores. Todos son totales porque el id es el último componente y dos
# bloques distintos no comparten id (supuesto de colisión declarado).
# ---------------------------------------------------------------------------
function cmp_orden(est, a::Int, b::Int)
    c = cmp(bw_de(est, a), bw_de(est, b)); c == 0 || return c
    c = cmp(est.sds[a], est.sds[b]);        c == 0 || return c
    return cmp(est.ids[a], est.ids[b])
end

function cmp_python(est, a::Int, b::Int)
    c = cmp(bw_de(est, a), bw_de(est, b)); c == 0 || return c
    c = cmp(est.sds[b], est.sds[a]);        c == 0 || return c
    return cmp(est.ids[a], est.ids[b])
end

function cmp_kaspa(est, a::Int, b::Int)
    c = cmp(bw_de(est, a), bw_de(est, b)); c == 0 || return c
    return cmp(est.ids[a], est.ids[b])
end

function menor_merge(est, params::Params, a::Int, b::Int)
    params.merge_mode == MERGE_SPEC && return cmp_orden(est, a, b) < 0
    params.merge_mode == MERGE_PYTHON && return cmp_python(est, a, b) < 0
    return cmp_kaspa(est, a, b) < 0
end

"""
Regla C: mayor blue_work; en empate, menor solution_distance; en empate, menor hash.
Dirección MIXTA (máximo en bw, mínimo en sd e id) — no es el máximo de una tupla
ascendente, es una comparación con dirección explícita por componente.
"""
function mejor_sp_zerox(est, a::Int, b::Int)
    bwa, bwb = bw_de(est, a), bw_de(est, b)
    bwa != bwb && return bwa > bwb
    sda, sdb = est.sds[a], est.sds[b]
    sda != sdb && return sda < sdb
    return cmp(est.ids[a], est.ids[b]) < 0
end

"¿Es `a` mejor padre seleccionado que `b`? (dirección propia de cada modo)"
function mejor_sp(est, params::Params, a::Int, b::Int)
    if params.sp_mode == SP_ZEROX
        return mejor_sp_zerox(est, a, b)
    elseif params.sp_mode == SP_SPEC
        return cmp_orden(est, a, b) > 0
    elseif params.sp_mode == SP_PYTHON
        return cmp_python(est, a, b) > 0
    else
        return cmp_kaspa(est, a, b) > 0
    end
end

function seleccionar_sp(est, params::Params, padres::Vector{Int})
    best = first(padres)
    for i in 2:length(padres)
        p = padres[i]
        mejor_sp(est, params, p, best) && (best = p)
    end
    return best
end

"""
rank, regla C (DECIDIDO POR KATANA 2026-09-14, TAREAS.md §1.3; texto normativo aún
PENDIENTE de redactar en SPEC.md §7.2, ver PROPUESTA-SPEC.md): (blue_work,
solution_distance, id) ascendente, gana el menor. Demostraciones de totalidad y
compatibilidad causal en PROPUESTA-SPEC.md §7.2 (no en INFORME.md).
"""
es_menor_rank(est, a::Int, b::Int) = cmp_orden(est, a, b) < 0

# ---------------------------------------------------------------------------
# Cadena seleccionada y orden de aplicación. Funciones puras de los datos GHOSTDAG
# (duck typing sobre est.gd; los accesores tipados viven en validacion.jl).
# ---------------------------------------------------------------------------
function cadena_seleccionada(est, tip::Int)
    ch = Int[]
    cur = tip
    while cur != 0
        push!(ch, cur)
        cur = sp_de(est, cur)
    end
    reverse!(ch)
    return ch
end

function tips(est)
    n = est.n
    con_hijo = falses(n)
    for i in 1:n
        for p in est.padres[i]
            con_hijo[p] = true
        end
    end
    return [i for i in 1:n if !con_hijo[i]]
end

"Punta virtual del estado visible: máximo de las puntas por la clave del modo sp."
function virtual_sp(est, params::Params)
    t = tips(est)
    return seleccionar_sp(est, params, t)
end

"blueset de una punta: ∪ mergeset_blues sobre la cadena ∪ {tip}."
function blueset(est, tip::Int)
    s = Set{Int}([tip])
    for c in cadena_seleccionada(est, tip)
        for x in ms_blues_de(est, c)
            push!(s, x)
        end
    end
    return s
end

"""
Orden de aplicación (R-FIN-8′(4), SPEC.md:1277-1280): por cada bloque C de la cadena
seleccionada, [sp(C)] ++ mergeset(C) con el mergeset re-ordenado por la clave del modo,
azules y rojo_k entrelazados, saltándose los rojo_U3. Concatenado por la cadena:
g, ms(C1), C1, ms(C2), C2, ... (el bloque va DESPUÉS de su mergeset; ghostdag.rs:83-91).
"""
function orden_aplicacion(est, params::Params, tip::Int)
    ch = cadena_seleccionada(est, tip)
    orden = Int[ch[1]]
    for c in ch[2:end]
        ms = [x for x in ms_blues_de(est, c) if x != sp_de(est, c)]
        append!(ms, ms_reds_de(est, c))
        apl = [x for x in ms if !es_rojo_u3(est, c, x)]
        sort!(apl; lt=(a, b) -> menor_merge(est, params, a, b))
        append!(orden, apl)
        push!(orden, c)
    end
    return orden
end

# ---------------------------------------------------------------------------
# Validez estructural compartida (SPEC §7.3, R-FIN-12, C-HDR-05, R-FIN-1a).
# Devuelve :ok o el motivo de rechazo.
# ---------------------------------------------------------------------------
function validar_estructura(est, params::Params, padres::Vector{Int}, slot::UInt64,
                            ident::UInt64)
    length(padres) <= params.max_parents || return :toomanyparents
    if params.u2 && ident != 0
        for p in padres
            est.idents[p] == ident && return :u2
            for x in est.anc[p]
                est.idents[x] == ident && return :u2
            end
        end
    end
    return :ok
end
