# =============================================================================
# rapido.jl — kernels rápidos (Float64) y Monte Carlo con RNG por réplica
# -----------------------------------------------------------------------------
# Reglas de LINEO respetadas: sin `@fastmath`, sin `@simd`, sin `Float32` como
# fuente de un veredicto; `@inbounds` sólo tras comprobar índices en los tests;
# `@threads` sólo sobre réplicas con escritura disjunta y reducción ordenada;
# semillas **no consecutivas** (mezcla splitmix64 de `(maestra, id)`).
# =============================================================================

# -----------------------------------------------------------------------------
# K1 · Mezcla de semillas (no consecutivas) y RNG por réplica
# -----------------------------------------------------------------------------
"""Mezcla de 64 bits (splitmix64). Rompe la consecutividad del id de réplica."""
@inline function splitmix64(x::UInt64)
    z = x + 0x9E3779B97F4A7C15
    z = (z ⊻ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ⊻ (z >> 27)) * 0x94D049BB133111EB
    return z ⊻ (z >> 31)
end

"""
    semilla_replica(maestra::UInt64, rid::Integer) -> NTuple{2,UInt64}

Par de claves de `Philox4x` derivado por mezcla. **No** son consecutivas aunque
`rid` lo sea: es el requisito del PROMPT §4 (las semillas consecutivas sesgan el
MC, hallazgo de `P-ZRX/P-PUERTA/`).
"""
@inline function semilla_replica(maestra::UInt64, rid::Integer)
    k1 = splitmix64(maestra ⊻ splitmix64(UInt64(rid) + 0x9E3779B97F4A7C15))
    k2 = splitmix64(k1 ⊻ 0xD1B54A32D192ED03)
    return (k1, k2)
end

# -----------------------------------------------------------------------------
# K2 · Φ exacta-cerrada en Float64, vectorizada sobre una rejilla
# -----------------------------------------------------------------------------
"""
    phi_pareto!(dest, d, xs)

Escribe en `dest` la fracción de espacio `Φ(x)` para cada `x` de `xs`. Broadcast
fusionado, sin temporales: no hay asignaciones en el bucle.
"""
function phi_pareto!(dest::Vector{Float64}, d::ParetoTruncado{Float64}, xs::AbstractVector{Float64})
    length(dest) == length(xs) || throw(ArgumentError("dest y xs deben coincidir"))
    b = 1.0 - d.a
    fmin_b = d.fmin^b
    fmax_b = d.fmax^b
    den = fmin_b - fmax_b
    @inbounds for i in eachindex(xs)
        x = xs[i]
        if x ≤ d.fmin
            dest[i] = 1.0
        elseif x ≥ d.fmax
            dest[i] = 0.0
        else
            dest[i] = (x^b - fmax_b) / den
        end
    end
    return dest
end

"""
    inversa_phi_pareto(d, p)

`f*`: tamaño de la granja marginal que suministra el top `p` del espacio.
"""
@inline function inversa_phi_pareto(d::ParetoTruncado{Float64}, p::Float64)
    b = 1.0 - d.a
    valor = p * (d.fmin^b - d.fmax^b) + d.fmax^b
    return valor^(1.0 / b)
end

# -----------------------------------------------------------------------------
# K3 · Barrido de la tasa: τ → fracción de espacio no disuadida
# -----------------------------------------------------------------------------
"""
    barrido_tasa(τs, d, λ, I, Pwin, Th, c_b, κq, Lp; n_extra=1)

Para cada `τ` devuelve `(τ, f_det, Φ(f_det))`: el espacio que queda disponible
para `β_d` con esa tasa. `Φ(f_det) ≤ 1−2α` es la condición de seguridad del
umbral (la comprueba `run.jl`, no este kernel).
"""
function barrido_tasa(τs::AbstractVector{Float64}, d::ParetoTruncado{Float64},
                      λ::Float64, I::Float64, Pwin::Float64, Th::Float64,
                      c_b::Float64, κq::Float64, Lp::Float64; n_extra::Integer = 1)
    n = length(τs)
    fdet = Vector{Float64}(undef, n)
    disp = Vector{Float64}(undef, n)
    @inbounds for i in eachindex(τs)
        fdet[i] = f_detenida(τs[i], κq, Lp, λ, I, Pwin, Th, c_b; n_extra = n_extra)
        disp[i] = Phi_espacio(d, min(fdet[i], d.fmax))
    end
    return fdet, disp
end

# -----------------------------------------------------------------------------
# K4 · Monte Carlo: Φ(x) por muestreo de la medida de conteo
# -----------------------------------------------------------------------------
"""
    mc_phi_replica(rng, d, x, M) -> Float64

Estima `Φ(x)` = fracción del **espacio** en granjas de tamaño `≥ x`, muestreando
`M` granjas de la **medida sesgada por tamaño** (densidad `∝ f^{−a}`, cuya CDF es
`1 − Φ`) y contando la frecuencia de `f ≥ x`.

⚠️ **Defecto propio corregido.** La primera versión muestreaba la medida de
**conteo** y pesaba por tamaño. Es insesgada pero inútil en la cola: con
`a = 2,2`, `P_conteo(f ≥ 10⁻⁴) = 1,6·10⁻⁹`, así que `2·10⁴` réplicas dan cero
aciertos y el estimador vale 0 con desviación nula. Muestrear la medida de espacio
convierte el estimador en una **proporción** (IC de Wilson aplicable) y mide la
cola con la precisión correcta. Consta en `PROGRESO.md` O1.
"""
function mc_phi_replica(rng, d::ParetoTruncado{Float64}, x::Float64, M::Integer)
    b = 1.0 - d.a
    fmin_b = d.fmin^b
    rango = fmin_b - d.fmax^b
    invb = 1.0 / b
    aciertos = 0
    @inbounds for _ in 1:M
        u = rand(rng, Float64)
        f = (fmin_b - u * rango)^invb
        if f ≥ x
            aciertos += 1
        end
    end
    return aciertos / M
end

"""
    wilson(k, n; z=1.959964) -> (lo, hi)

Intervalo de confianza de Wilson para una proporción. Se usa porque el estimador
de `mc_phi_replica` **es** una proporción, y la normal falla justo en la cola
(lección de `P-ZRX/P-CLAVE` F1).
"""
function wilson(k::Integer, n::Integer; z::Float64 = 1.959964)
    n > 0 || throw(ArgumentError("n > 0"))
    p = k / n
    den = 1.0 + z^2 / n
    centro = (p + z^2 / (2n)) / den
    mitad = z * sqrt(p * (1 - p) / n + z^2 / (4n^2)) / den
    return (centro - mitad, centro + mitad)
end

"""
    mc_phi(maestra, d, x, M, R; hilos) -> NamedTuple

`R` réplicas independientes con semillas derivadas por `semilla_replica` (no
consecutivas) y reducción determinista en orden de id. Devuelve la proporción
agrupada con su IC de Wilson, la media y desviación entre réplicas y los IC
individuales. La comparación contra el valor cerrado la hace `validar_mc`.
"""
function mc_phi(maestra::UInt64, d::ParetoTruncado{Float64}, x::Float64,
                M::Integer, R::Integer; hilos::Integer = 1)
    R ≥ 2 || throw(ArgumentError("R ≥ 2"))
    ratios = Vector{Float64}(undef, R)
    if hilos > 1
        Threads.@threads for rid in 1:R
            rng = Philox4x(semilla_replica(maestra, rid))
            ratios[rid] = mc_phi_replica(rng, d, x, M)
        end
    else
        for rid in 1:R
            rng = Philox4x(semilla_replica(maestra, rid))
            ratios[rid] = mc_phi_replica(rng, d, x, M)
        end
    end
    media = sum(ratios) / R
    varianza = sum(abs2, ratios .- media) / (R - 1)
    s = sqrt(varianza)
    t = t_cuanto(R - 1)
    mitad = t * s / sqrt(R)
    aciertos = round(Int, media * M * R)
    wlo, whi = wilson(aciertos, M * R)
    return (media = media, desv = s, ic_lo = media - mitad, ic_hi = media + mitad,
            wilson_lo = wlo, wilson_hi = whi, proporción = aciertos / (M * R),
            R = R, M = M, ratios = ratios)
end

"""
    t_cuanto(nu) -> Float64

Cuantil 0,975 de la t de Student para los grados de libertad usados; 1,959964 (el
normal) fuera de la tabla. Tabla pequeña y declarada para no arrastrar una
dependencia más.
"""
function t_cuanto(nu::Integer)
    tabla = Dict(1 => 12.7062, 2 => 4.3027, 3 => 3.1824, 4 => 2.7764, 5 => 2.5706,
                 7 => 2.3646, 9 => 2.2622, 15 => 2.1314, 19 => 2.0930, 31 => 2.0395,
                 63 => 1.9983, 127 => 1.9793)
    return get(tabla, nu, 1.959964)
end

# -----------------------------------------------------------------------------
# K5 · Coste de la enfermedad y del remedio, por unidad de espacio
# -----------------------------------------------------------------------------
"""
    coste_medio_por_espacio(espacio, coste) -> Float64

Coste por unidad de espacio capturado. Nótese que puede ser 0 (meseta de coste
cero) y que el cociente con el coste del remedio no es informativo cuando lo es:
la comparación pertinente es el **salto**, no el cociente (lección de
`P-ZRX/P-CLAVE` F2).
"""
@inline coste_medio_por_espacio(espacio::Float64, coste::Float64) =
    espacio > 0 ? coste / espacio : Inf

# -----------------------------------------------------------------------------
# K6 · Cargas de F5: barrera de entrada, rotación, recurrencia, cómputo
# -----------------------------------------------------------------------------
"""
    barrera_entrada_slots(τ, f, λ, I) -> Float64

Slots de ingreso propio que una granja de tamaño `f` necesita para pagar `τ`:
`τ/(f·λ·I)`. Es la medida de la **regresividad como barrera de entrada**.
"""
@inline barrera_entrada_slots(τ::Float64, f::Float64, λ::Float64, I::Float64) =
    τ / (f * λ * I)

"""
    carga_tasa_fraction(τ_min, f, λ, I, Th) -> Float64

Tasa mínima como múltiplo del ingreso de una granja `f` **en el mismo horizonte**:
`τ_min/(f·λ·I·T_h)`. Vale `(f*/f)·(1 − c_b/(λIPTh))`, inversamente proporcional al
tamaño: es la regresividad exacta.
"""
@inline carga_tasa_fraction(τ_min::Float64, f::Float64, λ::Float64, I::Float64, Th::Float64) =
    τ_min / (f * λ * I * Th)

"""
    coste_rotacion(β, Tv, Trot, τ, c_plot_byte) -> NamedTuple

Coste de mantener `β` de espacio con rotación de clave cada `T_rot`:
  · bytes: `1 + Tv/Trot` veces el ploteo (cita de `P-ZRX/P-CLAVE` F4, ×11 con
    `Tv=3600, Trot=360`);
  · tasa: una identidad nueva por rotación (más las que conviven durante `T_v`).
Es **fijo en la tasa y proporcional en los bytes**: por eso la rotación sigue
siendo barata para el grande, que es la conclusión de `P-CLAVE` que se quería ver
si cambiaba.
"""
function coste_rotacion(β::Float64, Tv::Float64, Trot::Float64, τ::Float64,
                        c_plot_byte::Float64)
    factor = 1.0 + Tv / Trot
    return (factor_ploteo = factor,
            coste_bytes = β * factor * c_plot_byte,
            identidades_en_vuelo = factor,
            coste_tasa_inicial = τ * factor,
            coste_tasa_por_rotacion = τ,
            coste_tasa_anualizado = τ * (T_ANIO_SLOTS / Trot))
end

"""Slots en un año a `λ = 1` bloque/s (unidad declarada, no parámetro de consenso)."""
const T_ANIO_SLOTS = 31_536_000.0

"""
    coste_computo_identidad(W, c_core_slot, n_identidades) -> NamedTuple

Variante pagada en cómputo: `n·W` de trabajo fijo por identidad, valorado en
`núcleos·slot`. **No exige moneda previa** (resuelve el arranque) y **no escala con
el disco** (cumple la letra del teorema), pero es fijo: la misma regresividad.
"""
function coste_computo_identidad(W::Float64, c_core_slot::Float64, n_identidades::Integer)
    return (trabajo_total = W * n_identidades,
            coste_nucleos_slot = W * n_identidades * c_core_slot,
            arranque_requiere_moneda = false,
            escala_con_espacio = false)
end
