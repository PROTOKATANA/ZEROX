# PPP-v0.1 — modelo: proceso de solución PoAS, definiciones de nivel, anclaje y coste.
# Toda la aritmética de probabilidad de este archivo es EXACTA (Rational{BigInt}); el
# Monte Carlo vive en rapido.jl y se valida contra ella.

# ---------------------------------------------------------------------------
# El proceso de solución (de subspace @ f8842d0, verificado en
# PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:120-158):
#
#   global_challenge  = derive_global_challenge(slot)          (u32→8 B usados)
#   sector_slot_challenge = sector_id.derive_sector_slot_challenge(global_challenge)
#   s_bucket_audit_index  = sector_slot_challenge.s_bucket_audit_index()
#   audit_chunk       = blake3_keyed(sector_slot_challenge, chunk)
#   solution_distance = bidirectional_distance(global_challenge, audit_chunk)
#   válida            ⇔ solution_distance ≤ solution_range / 2
#
# `bidirectional_distance` (solutions.rs:332-337) es la distancia circular sobre u64:
# con `global_challenge` fijo y `chunk` uniforme, `solution_distance` es uniforme en
# {0,…,2^63−1}. `map_winning_chunks` (auditing.rs:236-270) recorre TODOS los chunks del
# s-bucket auditado y los ordena por distancia: el bloque usa el mínimo. De ahí que un
# bloque sea el mínimo de C sorteos iid, no un solo sorteo.
# ---------------------------------------------------------------------------

"""Número de valores distintos de `solution_distance`: 0,…,2^63−1."""
const M_DIST = UInt64(1) << 63

struct Parametros
    C::Int       # chunks auditados por s-bucket = sorteos iid por bloque
    Lmax::Int    # cota de nivel a tabular
end
Parametros(; C::Integer=1, Lmax::Integer=48) = Parametros(Int(C), Int(Lmax))
const P_DEFECTO = Parametros()

# ---------------------------------------------------------------------------
# Umbrales y niveles. `SR` es `solution_range::u64`; el SPEC/Rust usan división
# ENTERA por 2^L (lib.rs:158: `solution_range / 2`). `>>` sobre UInt64 es esa división.
# ---------------------------------------------------------------------------

"""Umbral del nivel `L`: `SR ÷ 2^L`. Nivel 1 = válida. `L ≥ 64` → 0."""
umbral(SR::UInt64, L::Integer) = L >= 64 ? UInt64(0) : (SR >> L)

"""`solution_distance` dentro del rango de solución."""
es_valida(d::UInt64, SR::UInt64) = d <= (SR >> 1)

"""
Mayor `L ≥ 1` con `d ≤ SR ÷ 2^L` (0 si no es válida). Es la definición natural
`solution_distance ≤ SR/2^L`; se acota a 64 por el ancho de `SR`.
"""
function nivel(d::UInt64, SR::UInt64; Lmax::Integer=64)
    es_valida(d, SR) || return 0
    L = 1
    while L < min(Lmax, 64) && d <= umbral(SR, L + 1)
        L += 1
    end
    return L
end

# ---------------------------------------------------------------------------
# Probabilidad EXACTA del nivel con C sorteos iid (mínimo de C uniformes).
#
# Con sorteos en {0,…,M−1}, M = 2^63:
#     F(x) = P(min ≤ x) = 1 − ((M−1−x)/M)^C          (0 ≤ x ≤ M−1)
#     P(L | válida) = F(SR ÷ 2^L) / F(SR ÷ 2)
# La hipótesis del encargo (`2^{−(L−1)}`) es el límite de esta razón cuando SR/M → 0.
# ---------------------------------------------------------------------------

"""P(min ≤ x) exacta para C sorteos uniformes en {0,…,M−1}; `x` entero, `M = 2^63`."""
function p_min_leq(x::Integer, C::Integer)
    M = big(2)^63
    x >= M - 1 && return big(1)//big(1)
    x < 0 && return big(0)//big(1)
    return 1 - ((M - 1 - x)//M)^C
end

"""Probabilidad exacta de que un bloque válido alcance el nivel `L` (definición `SR/2^L`)."""
function p_nivel_exacta(L::Integer, SR::UInt64, C::Integer)
    L >= 1 || error("L ≥ 1")
    T1 = umbral(SR, 1)
    F1 = p_min_leq(Int(T1), C)
    F1 == 0 && return big(0)//big(1)
    return p_min_leq(Int(umbral(SR, L)), C) // F1
end

"""Hipótesis de partida auditada: `P(nivel L | válida) = 2^{−(L−1)}`."""
function hipotesis_nivel(L::Integer)
    L >= 1 || error("L ≥ 1")
    return big(1)//(big(2)^(L - 1))
end

"""Razón exacta / hipótesis. `>1` ⇒ el nivel es MÁS frecuente que la hipótesis."""
ratio_exacto(L::Integer, SR::UInt64, C::Integer) = p_nivel_exacta(L, SR, C) / hipotesis_nivel(L)

"""Probabilidad exacta (por sorteo-slot) de alcanzar el nivel `L`, sin condicionar a válida."""
p_nivel_crudo(L::Integer, SR::UInt64, C::Integer) = p_min_leq(Int(umbral(SR, L)), C)

# ---------------------------------------------------------------------------
# Anclaje del umbral. Si el umbral se fija con un `SR` de REFERENCIA y el bloque se
# produjo con `SRb`, entonces P(L | válida) = F(SR0 ÷ 2^L) / F(SRb ÷ 2). La razón entre
# dos bloques con distinto SR es ≈ SR0/SRb. Sin un `SR` de referencia fijo, el "nivel"
# no es una unidad de trabajo estable.
# ---------------------------------------------------------------------------

function factor_anclaje(L::Integer, SRb::UInt64, SR0::UInt64, C::Integer)
    F1 = p_min_leq(Int(umbral(SRb, 1)), C)
    F1 == 0 && return big(0)//big(1)
    return p_min_leq(Int(umbral(SR0, L)), C) // F1
end

# ---------------------------------------------------------------------------
# Coste y crecimiento (funciones de parámetros NO fijados; se entregan como función).
# ---------------------------------------------------------------------------

"""
Bloques de nivel `L` por slot que produce una fracción de espacio `alpha` cuando la red
(con SR fijado por el controlador) produce `lambda_obj` bloques válidos por slot:
`alpha · lambda_obj · 2^{−(L−1)}`. Es un escalado, no una constante: `lambda_obj` y `alpha`
los fija el diseño.
"""
coste_sorteos(alpha::Real, lambda_obj::Real, L::Integer) = alpha * lambda_obj * 2.0^(-(L - 1))

"""Slots medios hasta el siguiente bloque de nivel `L` para esa fracción: `1/coste_sorteos`."""
function tiempo_medio_nivel(alpha::Real, lambda_obj::Real, L::Integer)
    c = coste_sorteos(alpha, lambda_obj, L)
    return c == 0 ? Inf : 1 / c
end

"""
Crecimiento sin poda. `bps` = bloques/s; `bytes_cab` = bytes/cabecera; `mergeset_limit`
acota lo que reachability guarda por cabecera. Devuelve el número de cabeceras/año, los
bytes/año y una cota de entradas/año de reachability `O(#cabeceras × mergeset_limit)`.
"""
function crecimiento_cabeceras(bps::Real, bytes_cab::Real, mergeset_limit::Integer;
                               segundos_ano::Real=365.0 * 24 * 3600)
    cab = bps * segundos_ano
    return (cab, cab * bytes_cab, cab * mergeset_limit)
end

# ---------------------------------------------------------------------------
# Anclaje: la solución se encuentra ANTES de elegir padres. El nivel es función de
# (solución, slot), nunca de `padres`. Construcción: la MISMA solución admite cualquier
# conjunto de padres con `slot(p) ≤ slot`; el nivel no cambia.
# ---------------------------------------------------------------------------

"""
Construcción central del §4 del INFORME. Devuelve `(nivel, b1, b2)` donde `b1` y `b2`
son dos bloques con la MISMA solución/slot (mismo nivel) y distinto conjunto de padres.
No es una coincidencia estadística: es identidad estructural del proceso.
"""
function anclaje_independiente_de_padres(d::UInt64, SR::UInt64, slot::UInt64,
                                         padres1::Vector{UInt64}, padres2::Vector{UInt64})
    return (nivel(d, SR), (slot, d, copy(padres1)), (slot, d, copy(padres2)))
end

"""
Coste de moler un nivel `L` si `level` se define sobre el hash de cabecera (que incluye
padres): `2^L` hashes esperados, a `hps` hashes/s, coste ~`2^L/hps` segundos y CERO
espacio. Mide por qué un nivel ligado a la ancestría deja de ser espacio-tiempo.
"""
coste_molido_cpu(L::Integer, hps::Real) = 2.0^(L - 1) / hps

# ---------------------------------------------------------------------------
# Tabla de niveles para CLI.
# ---------------------------------------------------------------------------

struct TablaNiveles
    L::Vector{Int}
    umbral::Vector{UInt64}
    exacta::Vector{BigFloat}
    hipotesis::Vector{BigFloat}
    ratio::Vector{BigFloat}
end

"""Tabla exacta `L, umbral, P_exacta, hipótesis, razón` para `L = 1..Lmax` con `SR`, `C`."""
function tabla_niveles(SR::UInt64, C::Integer; Lmax::Integer=20)
    Ls = collect(1:Int(Lmax))
    us = UInt64[umbral(SR, L) for L in Ls]
    pe = BigFloat[p_nivel_exacta(L, SR, C) for L in Ls]
    hp = BigFloat[hipotesis_nivel(L) for L in Ls]
    ra = pe ./ hp
    return TablaNiveles(Ls, us, pe, hp, ra)
end
