# PRV-v0.1 — modelo: factores de circuito, conteo de operaciones y definiciones de
# selección. Toda factor lleva su procedencia: CITADO (fuente comprobada) o DECLARADO
# (supuesto con rango, a declarar en INFORME §3).

# ---------------------------------------------------------------------------
# Factores de conversión operación → restricciones.
#
# CITADO · halo2_poseidon 0.1.0, `p128pow5t3.rs`: Poseidon-128 con S-box x^5, ancho 3,
#   R_F = 8 rondas completas y R_P = 56 parciales. S-boxes por permutación:
#   8·3 + 56 = 80. Es la primitiva que usa Orchard (`orchard = "=0.15.5"`, SPEC §9).
#   Fuente: https://docs.rs/halo2_poseidon/0.1.0/src/halo2_poseidon/p128pow5t3.rs.html
# CITADO · halo2 Book, «Proving system»: el probador compromete polinomios (FFT + MSM)
#   de tamaño O(n) en el número de filas n; luego el trabajo del probador es Ω(n)
#   operaciones de campo. Fuente: https://zcash.github.io/halo2/design/proving-system.html
#
# DECLARADO · gates por S-box (2..4): una exponenciación x^5 es 2-3 multiplicaciones más
#   suma de constante; se toma un rango holgado.
# DECLARADO · operaciones de campo por segundo (1 hilo 1e9; 24 hilos 2,4e10): cota
#   OPTIMISTA, favorable a que el esquema cierre. Es una cota inferior del tiempo.
# DECLARADO · Halo2 realista (1e6 restricciones/s por hilo): las implementaciones de
#   Halo2 no sostienen el pico teórico de operaciones de campo (FFT, MSM, memoria). Es
#   la tasa que usaría un juicio conservador; el informe da la tasa de cierre para las
#   tres, de modo que el margen quede a la vista.
# DECLARADO · u256 (suma 2, comparación 3 restricciones) en un campo de 255 bits.
# NO CITADO · coste de Ed25519 / KZG-pairing / AES-PoT en circuito: NO se incluyen en la
#   cota inferior; sólo pueden AUMENTAR el coste (ver INFORME §3.4).
# ---------------------------------------------------------------------------

struct Factores
    sboxes_por_perm::Int          # CITADO: 80
    gates_por_sbox_lo::Float64
    gates_por_sbox_hi::Float64
    gates_u256_add::Float64
    gates_u256_cmp::Float64
    ops_campo_1hilo::Float64      # DECLARADO, optimista
    ops_campo_24hilos::Float64    # DECLARADO, optimista
    ops_campo_halo2::Float64      # DECLARADO, Halo2 realista (1e6), ver nota
end

function Factores(; sboxes_por_perm::Integer=80,
                  gates_por_sbox_lo::Real=2.0, gates_por_sbox_hi::Real=4.0,
                  gates_u256_add::Real=2.0, gates_u256_cmp::Real=3.0,
                  ops_campo_1hilo::Real=1.0e9, ops_campo_24hilos::Real=2.4e10,
                  ops_campo_halo2::Real=1.0e6)
    return Factores(Int(sboxes_por_perm), Float64(gates_por_sbox_lo),
                    Float64(gates_por_sbox_hi), Float64(gates_u256_add),
                    Float64(gates_u256_cmp), Float64(ops_campo_1hilo),
                    Float64(ops_campo_24hilos), Float64(ops_campo_halo2))
end

const P_FACTORES = Factores()

# ---------------------------------------------------------------------------
# Conteo de operaciones por bloque. Se guarda por bloque para poder reevaluar el coste
# con cualquier ventana de fusión W (parámetro NO fijado por el SPEC).
# ---------------------------------------------------------------------------

struct ConteoOperaciones
    n::Int
    ms::Vector{Int}        # |mergeset(B)| sin sp
    ctx::Vector{Int}       # |blueset(sp(B))| = contexto del k-cluster
    tam::Vector{Int}       # Σ_b |anticone(b) ∩ blueset(B)|
    ident::Vector{Int}     # hashes de identidad de billete exigidos por U2/U3″
    padres::Vector{Int}    # |padres(B)|
    blues::Vector{Int}     # |blues(B)| incluido sp
    orden::Vector{Int}     # comparaciones de orden del mergeset
end

"""Suma de dos conteos (para agregar varios DAGs)."""
function suma_conteos(a::ConteoOperaciones, b::ConteoOperaciones)
    return ConteoOperaciones(a.n + b.n, vcat(a.ms, b.ms), vcat(a.ctx, b.ctx),
                             vcat(a.tam, b.tam), vcat(a.ident, b.ident),
                             vcat(a.padres, b.padres), vcat(a.blues, b.blues),
                             vcat(a.orden, b.orden))
end

"Pares (candidato, azul del contexto) a decidir por reachability con ventana `W`."
function pares_anticone(c::ConteoOperaciones, W::Integer)
    s = 0
    @inbounds for i in 1:c.n
        s += c.ms[i] * min(c.ctx[i], Int(W))
    end
    return s
end

# ---------------------------------------------------------------------------
# Coste en restricciones.
# ---------------------------------------------------------------------------

"""
Cota INFERIOR de restricciones por bloque para probar el paso GHOSTDAG del bloque de
cadena: cada par (candidato, azul del contexto) exige una decisión de ancestría, que en
un circuito es una ruta de Merkle/intervalo de `ceil(log2(W+1))` hashes Poseidon. Se
excluyen firmas, KZG, PoT y UTXO (sólo suman). Devuelve un NamedTuple con el desglose.
"""
function coste_restricciones(c::ConteoOperaciones, W::Integer, f::Factores= P_FACTORES;
                             gs::Float64=f.gates_por_sbox_lo)
    c.n == 0 && return (restricciones=0.0, por_bloque=0.0, pares=0, hashes_reach=0.0,
                        hashes_ident=0.0, adds=0, cmps=0)
    L = W <= 1 ? 0.0 : ceil(log2(W + 1))
    pares = pares_anticone(c, W)
    gates_reach = L * f.sboxes_por_perm * gs
    r_reach = pares * gates_reach
    # identidad: 3 elementos ⇒ 2 permutaciones por hash (sponge rate 2)
    hashes_ident = 2 * sum(c.ident; init=0)
    r_ident = hashes_ident * f.sboxes_por_perm * gs
    adds = sum(c.blues; init=0)
    cmps = sum(c.orden; init=0)
    r = r_reach + r_ident + adds * f.gates_u256_add + cmps * f.gates_u256_cmp
    return (restricciones=r, por_bloque=r / c.n, pares=pares,
            hashes_reach=pares * L, hashes_ident=hashes_ident, adds=adds, cmps=cmps)
end

"Restricciones por bloque con el rango DECLARADO de gates/S-box."
function restricciones_por_bloque(c::ConteoOperaciones, W::Integer, f::Factores=P_FACTORES)
    lo = coste_restricciones(c, W, f; gs=f.gates_por_sbox_lo).por_bloque
    hi = coste_restricciones(c, W, f; gs=f.gates_por_sbox_hi).por_bloque
    return (lo=lo, hi=hi)
end

"Bloques/s máximos si el probador sostiene `ops_campo` operaciones de campo por segundo."
tasa_cierre(restricciones_por_bloque::Real, ops_campo::Real) = ops_campo / restricciones_por_bloque

"""
Coste paramétrico por bloque: `M` = |mergeset| medio, `W` = ventana de fusión. Supone el
contexto lleno (W azules), que es el estado estacionario de un DAG honesto podado por
ventana. Es una ESTIMACIÓN cuando `W` supera el tamaño del DAG medido; se declara.
"""
function coste_paramétrico(M::Real, W::Integer, f::Factores=P_FACTORES;
                           gs::Float64=f.gates_por_sbox_lo)
    L = W <= 1 ? 0.0 : ceil(log2(W + 1))
    return M * W * L * f.sboxes_por_perm * gs
end

"Tasas de cierre (bloques/s) para las tres tasas declaradas: Halo2 realista, 1e9 y 2,4e10."
function tasas_cierre(rpb::Real, f::Factores=P_FACTORES)
    return (halo2=f.ops_campo_halo2 / rpb,
            un_hilo=f.ops_campo_1hilo / rpb,
            veinticuatro=f.ops_campo_24hilos / rpb)
end

"""
Mayor potencia de 2 `W` para la que el modelo cierra a 1 bloque/s (`ops/restr ≥ 1`), con
`M` y `ops` dados. Es la frontera «a qué ventana sí cerraría»: por encima de `Wc`, no.
"""
function ventana_critica(M::Real, ops::Real, f::Factores=P_FACTORES; Wmax::Int=1 << 30,
                         gs::Float64=f.gates_por_sbox_lo)
    Wc = 1
    W = 1
    while W <= Wmax
        r = coste_paramétrico(M, W, f; gs=gs)
        if r > 0 && ops / r < 1
            return Wc
        end
        Wc = W
        W *= 2
    end
    return Wc
end

"""
Restricciones por bloque de una cadena LINEAL equivalente: un hash Poseidon del estado +
un hash de cadena (2 permutaciones), sin mergeset ni coloreo. Es el punto de comparación
del §3.2.
"""
function factor_lineal(c::ConteoOperaciones, W::Integer, f::Factores=P_FACTORES;
                       gs::Float64=f.gates_por_sbox_lo)
    coste = coste_restricciones(c, W, f; gs=gs).por_bloque
    lineal = 2 * f.sboxes_por_perm * gs
    return (dag=coste, lineal=lineal, factor=coste / lineal)
end

"Tasa (bloques/s) a la que cerraría con 1 y con 24 hilos (cotas optimistas)."
function bloques_por_segundo_que_cierra(restricciones_por_bloque::Real, f::Factores=P_FACTORES)
    return (un_hilo=tasa_cierre(restricciones_por_bloque, f.ops_campo_1hilo),
            veinticuatro=tasa_cierre(restricciones_por_bloque, f.ops_campo_24hilos))
end

# ---------------------------------------------------------------------------
# SELECCIÓN vs VALIDEZ (§2 del encargo).
#
# Una `Historia` es un DAG válido con su punta canónica y su blue_work. Una prueba de
# validez sólo atestigua «esta historia es válida y ésta es su punta canónica». El
# teorema de imposibilidad se apoya en que `canonica` NO es función de una sola historia.
# ---------------------------------------------------------------------------

struct Historia
    nombre::String
    n::Int
    padres::Vector{Vector{Int}}
    canonica::Int
    blue_work::BigInt
end

"Una prueba de validez de una historia: su DAG, su punta canónica y su blue_work."
struct PruebaValidez
    historia::Historia
end
