# modelo.jl — definiciones exactas del controlador de rango (RNG-v0.1, encargo P-RANGO)
#
# Fuentes de cada definición, leídas enteras antes de escribir esto:
#  · Predicado de aceptación y A(SR): veritas/consenso/puerta-cobertura-v1/MODELO.md §1.1
#    (`bidirectional_distance(audit_chunk, global_challenge) <= SR ÷ 2`, círculo de 2^64 puntos;
#    leído allí del código de Autonomys, subspace-verification/src/lib.rs:150-158).
#  · Peso: C-GD-01 (`SPEC.md` §11): `w(B) = ⌊2^128/(SR+1)⌋`, entero exacto, coma flotante prohibida.
#  · Controlador entero mínimo, cohortes, corte, activación diferida, clamps y Z0 (no-op):
#    veritas/consenso/retarget-causal-endogeno-v1/CONTRATO.md y src/controlador.jl.
#
# Todo el modelo es aritmética entera o Rational{BigInt}. No entra Float64 en ninguna decisión.

const DOS128 = big(2)^128
const MAX_U64 = BigInt(typemax(UInt64))
const MAX_U128 = BigInt(typemax(UInt128))

# ── Lo que se mide: tasa de peso por ensayo ──────────────────────────────────────────────────

"""
    A_sr(sr)

Número de distancias aceptadas en el círculo de `2^64` con rango `sr`: `2·(sr ÷ 2) + 1`
(PCO-v0.1 `MODELO.md:31-33`). Con `sr` par vale `sr+1`; con `sr` impar, `sr`.
"""
@inline A_sr(sr::Integer) = 2 * fld(sr, 2) + 1

"""
    peso_big(sr)

`w(B) = ⌊2^128/(SR+1)⌋` (C-GD-01), exacto. `SR = 0` da `2^128`, que **no** cabe en `u128`.
"""
@inline peso_big(sr::Integer) = fld(DOS128, big(sr) + 1)

"""
    razon_ref(sr)

`tasa_peso(P, sr) / (P·2^64) = A(sr)·⌊2^128/(sr+1)⌋ / 2^128`, exacto (Rational{BigInt}).
Es `1` salvo por los dos residuos de PCO-v0.1 `MODELO.md:52-65`: el suelo y la paridad.
"""
@inline razon_ref(sr::Integer) = (big(A_sr(sr)) * peso_big(sr)) // DOS128

"""
    razon_cerrada(sr)

La misma magnitud por la forma cerrada de `MODELO.md:45-48`, **independiente** del producto de
arriba: `1 − ρ/2^128` si `sr` es par; `sr/(sr+1) − sr·ρ/((sr+1)·2^128)` si es impar, con
`ρ = 2^128 mod (sr+1)`.
"""
function razon_cerrada(sr::Integer)
    sr >= 0 || throw(DomainError(sr, "SR negativo"))
    rho = rem(DOS128, big(sr) + 1)
    if iseven(sr)
        return 1 - rho // DOS128
    else
        return big(sr) // (big(sr) + 1) - (big(sr) * rho) // ((big(sr) + 1) * DOS128)
    end
end

"""Déficit relativo `1 − razón(sr)`, exacto."""
@inline deficit(sr::Integer) = 1 - razon_ref(sr)

# ── Configuración del controlador: TODOS los parámetros son símbolos sin valor ───────────────

"""
    ConfigControlador

Todos los campos son **símbolos** en la propuesta P-RANGO. Este instrumento no les da valor de
consenso: elige valores de ensayo solo para poder comprobar el kernel. Campos: `w_slots`
(anchura de cohorte en índices de slot), `g_slots` (gracia causal), `q` (conteo objetivo por
cohorte), ganancia amortiguada `a/d`, clamps multiplicativos por cohorte `p_lo/q_lo` y
`p_hi/q_hi`, dominio global `[sr_min, sr_max]`, arranque `r_inicial` y `retardos_ventana`
(cohortes de activación diferida).
"""
struct ConfigControlador
    w_slots::UInt64
    g_slots::UInt64
    q::UInt64
    ganancia_num::UInt64
    ganancia_den::UInt64
    paso_lo_num::UInt64
    paso_lo_den::UInt64
    paso_hi_num::UInt64
    paso_hi_den::UInt64
    sr_min::UInt64
    sr_max::UInt64
    r_inicial::UInt64
    retardos_ventana::UInt64
    # Precondición de anchura **precalculada** en la construcción. Vive aquí para que el kernel
    # no pague una comprobación en `BigInt` por bloque (LINEO §2 paso 3: nada de asignaciones en
    # el camino caliente).
    cabe_u128::Bool
end

function ConfigControlador(; w_slots, g_slots, q, ganancia_num, ganancia_den,
                          paso_lo_num, paso_lo_den, paso_hi_num, paso_hi_den,
                          sr_min, sr_max, r_inicial, retardos_ventana)
    cabe = BigInt(sr_max) * BigInt(ganancia_den) * MAX_U64 <= MAX_U128
    c = ConfigControlador(UInt64(w_slots), UInt64(g_slots), UInt64(q),
                          UInt64(ganancia_num), UInt64(ganancia_den),
                          UInt64(paso_lo_num), UInt64(paso_lo_den),
                          UInt64(paso_hi_num), UInt64(paso_hi_den),
                          UInt64(sr_min), UInt64(sr_max), UInt64(r_inicial),
                          UInt64(retardos_ventana), cabe)
    # Precondiciones comprobadas. Una configuración fuera de dominio se RECHAZA, no se satura.
    c.w_slots > 0 || throw(ArgumentError("w_slots debe ser > 0"))
    c.g_slots >= 0 || throw(ArgumentError("g_slots debe ser >= 0"))
    c.q > 0 || throw(ArgumentError("q debe ser > 0"))
    c.ganancia_den > 0 || throw(ArgumentError("ganancia_den debe ser > 0"))
    c.ganancia_num > 0 || throw(ArgumentError("ganancia_num debe ser > 0"))
    c.ganancia_num <= c.ganancia_den || throw(ArgumentError("se exige 0 < a <= d"))
    c.paso_lo_den > 0 || throw(ArgumentError("paso_lo_den debe ser > 0"))
    c.paso_hi_den > 0 || throw(ArgumentError("paso_hi_den debe ser > 0"))
    c.paso_lo_num <= c.paso_lo_den || throw(ArgumentError("se exige p_lo <= q_lo"))
    c.paso_hi_num >= c.paso_hi_den || throw(ArgumentError("se exige p_hi >= q_hi"))
    c.retardos_ventana >= 1 || throw(ArgumentError("retardos_ventana >= 1"))
    # Dominio: SR=0 da w=2^128, fuera de u128 (C-GD-01). Con la rejilla par, SR_MIN >= 2.
    iseven(c.sr_min) || throw(ArgumentError("sr_min debe ser par"))
    iseven(c.sr_max) || throw(ArgumentError("sr_max debe ser par"))
    c.sr_min >= 2 || throw(ArgumentError("sr_min >= 2: SR=0 da w=2^128, fuera de u128"))
    c.sr_min <= c.sr_max || throw(ArgumentError("sr_min <= sr_max"))
    c.sr_min <= c.r_inicial <= c.sr_max || throw(ArgumentError("sr_min <= r_inicial <= sr_max"))
    c.paso_lo_num * c.paso_hi_den <= c.paso_hi_num * c.paso_lo_den ||
        throw(ArgumentError("clamps incompatibles: p_lo/q_lo <= p_hi/q_hi"))
    return c
end

"""Cota de deriva por cohorte: `γ := max(p_hi/q_hi − 1, 1 − p_lo/q_lo)`, exacta."""
function gamma(c::ConfigControlador)
    hi = big(c.paso_hi_num) // big(c.paso_hi_den) - 1
    lo = 1 - big(c.paso_lo_num) // big(c.paso_lo_den)
    return max(hi, lo)
end

# ── Redondeos: exactos, enteros, sin coma flotante ───────────────────────────────────────────

"""
    divide_round_half_even(num, den)

Entero más cercano a `num/den` (`den > 0`, `num >= 0`), **empates al cociente par**. Es el modo
`NearestEven` de RCE-v0.1 (`src/controlador.jl:1-8`), reescrito sin `Float64`.
"""
@inline function divide_round_half_even(num::Integer, den::Integer)
    den > 0 || throw(DivideError())
    num >= 0 || throw(DomainError(num, "num negativo"))
    q, r = divrem(num, den)
    # `complemento = den − r` en vez de `2r`: exactamente el mismo criterio y no desborda en
    # `UInt128` cuando `num` está cerca del máximo (donde `2r` sí desbordaría).
    complemento = den - r
    return r < complemento ? q : r > complemento ? q + 1 : (iseven(q) ? q : q + 1)
end

"""Proyección a la rejilla par, hacia abajo: `x` si es par, `x−1` si es impar."""
@inline rejilla_par(x::Integer) = iseven(x) ? x : x - 1

"""Mayor entero **par** `<= num/den` (`den > 0`). Sin duplicar `num` ni `den` (no desborda)."""
@inline function cota_par_inferior(num::Integer, den::Integer)
    q = fld(num, den)
    return iseven(q) ? q : q - 1
end

"""Menor entero **par** `>= num/den` (`den > 0`). Sin duplicar `num` ni `den` (no desborda)."""
@inline function cota_par_superior(num::Integer, den::Integer)
    q = cld(num, den)
    return iseven(q) ? q : q + 1
end
