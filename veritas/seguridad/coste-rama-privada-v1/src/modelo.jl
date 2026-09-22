# CRP-v0.1 — modelo: tipos, contabilidad de trabajo y referencias de protocolo.
#
# Instrumento de estudio. NO fija parámetros de consenso ni redacta reglas. Todas las
# magnitudes físicas (N, C, M, SR, λ) entran como parámetros; el resultado se da como
# función y con los supuestos declarados. Ver CONTRATO.md y MODELO.md.
#
# --- Contabilidad de trabajo, con las unidades normalizadas ---
# Espacio total normalizado a 1 (se mide en fracción de sectores). Sea `sr0` el rango de
# referencia con el que el espacio completo produce la tasa objetivo `λ0` (bloques/slot).
# Para una rama con fracción de espacio `s` y rango `sr`:
#     tasa de bloques/slot      λ(s, sr) = s · λ0 · sr/sr0
#     peso por bloque (C-GD-01)  w(sr)   = ⌊2^128/(sr+1)⌋
# De aquí el trabajo por slot, en unidades de w(sr0):
#     E[trabajo/slot] = λ(s,sr) · w(sr)/w(sr0) ≈ s · λ0
# **independiente de `sr`**: la tasa de validación es ∝ sr y el peso es ∝ 1/sr. Ése es
# el hecho que el §3.2 del encargo pide medir; aquí se deriva y en `referencia.jl` se
# comprueba de forma exacta, y en `rapido.jl` por Monte Carlo.
#
# El vector sólo aparece si el `sr` que pondera NO es el que gobierna la validez. Con dos
# rangos (`sr_val` para validez, `sr_peso` para el peso), el trabajo por slot es
#     s · λ0 · (sr_val/sr0) · w(sr_peso)/w(sr0),
# amplificado por `sr_val/sr_peso`. En el SPEC ambos son el mismo campo (`rango_solucion`,
# C-GD-01 + §7.1): el acoplamiento es la propiedad que debe conservarse.

const DOS128 = big(2)^128

"Aritmética entera exacta de `w(B) = ⌊2^128/(sr+1)⌋` (C-GD-01)."
function peso_exacto(sr::Integer)::BigInt
    sr >= 0 || throw(ArgumentError("sr negativo"))
    return fld(DOS128, BigInt(sr) + 1)
end

"Peso relativo al del rango de referencia, exacto (Rational)."
function peso_relativo(sr::Integer, sr0::Integer)::Rational{BigInt}
    return peso_exacto(sr) // peso_exacto(sr0)
end

# ---------------------------------------------------------------------------
# Parámetros. `k`, padres y mergeset son los de R-FIN-12 / C-GD-04; S_max el de C-GD-05.
# `sr0` y `lambda0` son de NORMALIZACIÓN del instrumento (no constantes de producción).
# ---------------------------------------------------------------------------
struct Parametros
    k::UInt32
    max_padres::UInt32
    mergeset_limit::UInt32
    s_max::UInt64
    sr0::UInt64
    lambda0::Float64
end

function Parametros(; k::Integer=30, max_padres::Integer=15, mergeset_limit::Integer=180,
                    s_max::Integer=150, sr0::Integer=UInt64(1) << 50,
                    lambda0::Real=1.0)
    return Parametros(UInt32(k), UInt32(max_padres), UInt32(mergeset_limit),
                      UInt64(s_max), UInt64(sr0), Float64(lambda0))
end

const P_DEFECTO = Parametros()

"Tasa esperada de bloques válidos por slot para fracción `s` y rango `sr`."
tasa_esperada(s::Real, sr::Integer, p::Parametros) = s * p.lambda0 * Float64(sr) / Float64(p.sr0)

"Trabajo esperado por slot (unidades de w(sr0)); ≈ s·λ0, independiente de `sr`."
trabajo_esperado(s::Real, sr::Integer, p::Parametros) =
    tasa_esperada(s, sr, p) * Float64(peso_relativo(sr, p.sr0))

# ---------------------------------------------------------------------------
# Familia de controladores de rango (R-FIN-13′ NO está especificado; se modela una
# familia y se declaran sus supuestos, como exige el encargo §3.2/§5.3).
# ---------------------------------------------------------------------------
@enum AnclaControlador begin
    CTRL_FIJO          # no reacciona: sr = sr_ref
    CTRL_REACTIVO      # observa su propia ventana y sube sr si produce por debajo del objetivo
    CTRL_INVERSO       # reacciona con el signo contrario (para medir la DIRECCIÓN)
end

struct Controlador
    ancla::AnclaControlador
    gamma::Float64     # ganancia de la corrección por ventana
    ventana::Int       # slots de la ventana de observación
    sr_min::UInt64
    sr_max::UInt64
    sr_ref::UInt64
end

function Controlador(p::Parametros; ancla::AnclaControlador=CTRL_REACTIVO,
                     gamma::Real=1.0, ventana::Integer=20,
                     sr_min::Integer=UInt64(1), sr_max::Integer=typemax(UInt64) >> 1)
    return Controlador(ancla, Float64(gamma), Int(ventana), UInt64(sr_min),
                       UInt64(sr_max), p.sr0)
end

"Próximo `sr` dado el `sr` actual y las observaciones de la ventana (nº de bloques/slot)."
function actualiza_controlador(c::Controlador, sr::UInt64, obs::AbstractVector{Int}, p::Parametros)
    c.ancla == CTRL_FIJO && return c.sr_ref
    sumobs = sum(obs)
    objetivo = Float64(p.lambda0) * length(obs)
    # evita división por cero sin inventar constantes de protocolo: si no hay observación
    # la corrección es 0, es decir, se conserva el sr actual.
    (sumobs <= 0 || objetivo <= 0) && return sr
    g = c.ancla == CTRL_REACTIVO ? c.gamma : -c.gamma
    factor = (objetivo / Float64(sumobs))^g
    nv = Float64(sr) * factor
    isfinite(nv) || return nv > 0 ? c.sr_max : c.sr_min
    nv >= Float64(c.sr_max) && return c.sr_max
    nv <= Float64(c.sr_min) && return c.sr_min
    return UInt64(round(nv))
end

# ---------------------------------------------------------------------------
# Referencias bajo el MISMO criterio de éxito: superar el blue_work observado.
# El trabajo por slot es ∝ fracción de recurso en los tres. PoW lineal y GHOSTDAG-sobre-PoW
# no pueden reutilizar la misma unidad de recurso (el hash se gasta); PoST sí (el espacio
# produce soluciones nuevas cada slot, ligadas a sr). La diferencia de UMBRAL no viene de
# ahí: viene de cómo se reparte el trabajo entre las dos ramas.
# ---------------------------------------------------------------------------
@enum ProtocoloRef begin
    POW_LINEAL    # Bitcoin: una cadena, trabajo = nº de bloques × dificultad
    GHOSTDAG_POW  # Kaspa: DAG sobre PoW, blue_work; mismo recurso no reutilizable
    POST_DAG      # ZEROX: DAG sobre PoST, blue_work = Σ⌊2^128/(SR+1)⌋
end

"Trabajo por slot de la rama con fracción `s` para un protocolo y granularidad `g`."
function trabajo_rama(prot::ProtocoloRef, s::Real, p::Parametros; g::Real=1.0)
    # `g` = bloques por unidad de trabajo (granularidad). Todos tienen media s·λ0;
    # el protocolo sólo cambia la varianza por unidad de trabajo (menor con g mayor).
    return s * p.lambda0
end

# ---------------------------------------------------------------------------
# Curva de alcance (régimen CORTO): probabilidad de que un adversario con fracción α
# alcance una ventaja inicial de `d` unidades de trabajo. Referencia exacta: ruina del
# jugador para pasos ±1 (PoW lineal, g≈1). Aproximación de difusión para granularidad g.
# ---------------------------------------------------------------------------
"Probabilidad clásica de alcance desde `d` bloques, pasos ±1, adversario α (0<α<1)."
function prob_alcance_binomial(α::Real, d::Integer)
    0 <= α <= 1 || throw(ArgumentError("α fuera de [0,1]"))
    α <= 0 && return 0.0
    α >= 1 && return 1.0
    α >= 0.5 && return 1.0
    return (α / (1 - α))^d
end

"""
Aproximación de difusión para granularidad `g` (bloques por unidad de trabajo): la deriva
por unidad de trabajo es `2α−1` y la varianza es `1/g`, de donde
`p ≈ exp(−2(2α−1)·d·g)` para α<1/2. Con g=1 reproduce el orden de la ruina binomial.
"""
function prob_alcance_difusion(α::Real, d::Real; g::Real=1.0)
    α <= 0 && return 0.0
    α >= 0.5 && return 1.0
    return exp(-2.0 * (1.0 - 2.0 * α) * d * g)
end

# ---------------------------------------------------------------------------
# Multiplicidad (D6) y multistream (ATAQUE 2). Se calculan, no se suponen.
# ---------------------------------------------------------------------------
"Cuota efectiva con `m` flujos de PoT independientes y espacio α (ATAQUE 2)."
cuota_multistream(α::Real, S::Real) = S * α / (1 - α + S * α)

"Espacio total efectivo del adversario si puede abrir `S` flujos (sin acotar S)."
α_efectivo_multistream(α::Real, S::Real) = cuota_multistream(α, S)
