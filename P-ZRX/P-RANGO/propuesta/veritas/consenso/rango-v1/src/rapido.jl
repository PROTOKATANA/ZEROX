# rapido.jl — kernel tipado, sin asignaciones y con aritmética comprobada (LINEO §2 pasos 2-4).
#
# Dos decisiones de representación, dichas antes del código:
#  1. El kernel del controlador vive entero en `UInt128` con `Base.Checked`. `UInt128` NO es
#     incondicionalmente seguro para entradas `u64`: hace falta la precondición de RCE-v0.1
#     (`sr_max·d·typemax(UInt64) ≤ typemax(UInt128)`). Se comprueba ANTES de usar el kernel.
#  2. El peso se calcula en `UInt128` sin materializar `2^128`: `⌊2^128/d⌋ = 2·⌊2^127/d⌋ + ⌊2r/d⌋`.

"""
    precondicion_u128(c)

Precondición **suficiente** del kernel en 128 bits, exacta:
`sr_max · d · typemax(UInt64) ≤ typemax(UInt128)`. Con `n, q ≤ typemax(UInt64)` y `d−a ≥ 0` se
tiene `(d−a)n + a·q ≤ d·typemax(UInt64)`, luego `num ≤ sr_max·d·typemax(UInt64)` y
`den = d·n ≤ d·typemax(UInt64)`. Fuera de la precondición la configuración se RECHAZA. Se
precalcula al construir `ConfigControlador` para no pagar `BigInt` por bloque.
"""
@inline precondicion_u128(c::ConfigControlador) = c.cabe_u128

"""
    cabe_en_u256(c)

`num` y `den` con entradas `u64` caben **siempre** en `u256`: `sr_max·d·M < 2^64·2^64·2^64 = 2^192`
y `den = d·n < 2^128`. Es la razón por la que `u256` (C-GD-02) no necesita precondición.
"""
@inline cabe_en_u256(c::ConfigControlador) =
    BigInt(c.sr_max) * BigInt(c.ganancia_den) * MAX_U64 < big(2)^192

"""
    peso_fast(sr)

`⌊2^128/(sr+1)⌋` en `UInt128`, exacto, sin construir `2^128`:
`2^128 = 2·(q·d + r)`, luego `⌊2^128/d⌋ = 2q + ⌊2r/d⌋` con `q, r = divrem(2^127, d)`.
`sr = 0` se rechaza: da `2^128`, fuera de `u128` (C-GD-01).
"""
@inline function peso_fast(sr::UInt64)
    sr >= 1 || throw(DomainError(sr, "SR=0 da w=2^128, fuera de u128 (C-GD-01)"))
    d = UInt128(sr) + UInt128(1)
    hi = UInt128(1) << 127
    q, r = divrem(hi, d)
    return 2 * q + fld(2 * r, d)
end

"""
    controlador_fast(r, n, c)

Kernel del controlador en `UInt128` comprobado. Mismo resultado que `controlador_ref`. Lanza si
la precondición de 128 bits no se cumple o si una operación desborda: **nunca** satura en
silencio. Devuelve `(rango_siguiente, clamped)`.
"""
function controlador_fast(r::UInt64, n::UInt64, c::ConfigControlador)
    n == UInt64(0) && return (r, false)            # Z0: no-op explícito
    precondicion_u128(c) || throw(ArgumentError("configuración fuera del dominio de u128"))
    d = UInt128(c.ganancia_den)
    a = UInt128(c.ganancia_num)
    q = UInt128(c.q)
    nn = UInt128(n)
    rr = UInt128(r)
    blend = Base.Checked.checked_add(Base.Checked.checked_mul(d - a, nn),
                                     Base.Checked.checked_mul(a, q))
    num = Base.Checked.checked_mul(rr, blend)
    den = Base.Checked.checked_mul(d, nn)
    r_raw = divide_round_half_even(num, den)
    r_par = rejilla_par(r_raw)
    lo = cota_par_inferior(Base.Checked.checked_mul(rr, UInt128(c.paso_lo_num)),
                           UInt128(c.paso_lo_den))
    hi = cota_par_superior(Base.Checked.checked_mul(rr, UInt128(c.paso_hi_num)),
                           UInt128(c.paso_hi_den))
    step = clamp(r_par, lo, hi)
    out = clamp(step, UInt128(c.sr_min), UInt128(c.sr_max))
    return (UInt64(out), out != r_raw)
end

"""
    rango_esperado(r, n, c)

Puerta única del kernel: rechaza `r` fuera de `[sr_min, sr_max]` antes de calcular, para que
ninguna implementación pueda usar el kernel como fuente de un rango fuera de dominio.
"""
function rango_esperado(r::UInt64, n::UInt64, c::ConfigControlador)
    c.sr_min <= r <= c.sr_max || throw(DomainError(r, "rango activo fuera de [sr_min, sr_max]"))
    return controlador_fast(r, n, c)
end
