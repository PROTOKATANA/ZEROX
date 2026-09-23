# =============================================================================
# modelo.jl — P-TASA · Modelo económico de la tasa fija por identidad
# -----------------------------------------------------------------------------
# Unidades y convenciones (declaradas, nunca fijadas por el instrumento):
#   · espacio total = 1. `f` = fracción de ESPACIO de una granja (dimensionless).
#   · tiempo en SLOTS. `λ` [bloques/slot] = tasa de la red entera.
#   · `I` = valor de un bloque (u.e.). `λ·I` = ingreso por slot por unidad de
#     espacio. `T_h` [slots] = horizonte en el que se mide la disuasión.
#   · `P_win` = probabilidad de que la rama privada acabe pagando; ∈ (0,1].
#   · `κ` = prob. de que la infracción se PRUEBE; `q` = prob. de castigo dado
#     prueba; `L_p` = pérdida por infracción probada (u.e.).
#   · `τ` = tasa FIJA no recuperable por identidad (u.e.); `σ` por byte;
#     `D` depósito fijo confiscable (u.e.); `c_b` coste de bytes por replotear
#     la identidad extra (u.e. por unidad de espacio).
# Ninguno de esos símbolos se fija aquí: entran por CLI y salen como columna.
#
# Separación del encargo §2.1 (las tres variantes):
#   :A  stake proporcional al espacio      costo ∝ f            (PoS, rechazado)
#   :B  depósito fijo confiscable          costo = D·κq         (depende de κ)
#   :C  tasa fija NO recuperable           costo = τ            (no depende de κ)
# =============================================================================

# -----------------------------------------------------------------------------
# 1 · Deriva y frontera de umbral (aritmética exacta sobre `T`)
# -----------------------------------------------------------------------------
"""
    deriva_t(α, βd, βx, ηh, ηa)

Deriva en unidades de peso por unidad de tiempo, con el reparto del texto de
`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` §1: la rama pública conserva
`1 − α − βx` (el doble granjero **sigue publicando**), la privada suma
`α + βd + βx`. `βd` sólo suma a la privada; `βx` quita a la pública **y** suma a
la privada: por eso vale el doble.
"""
@inline function deriva_t(α::T, βd::T, βx::T, ηh::T, ηa::T) where {T<:Real}
    return ηa * (α + βd + βx) - ηh * ((one(T) - α) - βx)
end

"""
    alpha_estrella_t(βd, βx, ηh, ηa)

Frontera exacta `g = 0` despejada en `α`:
`α* = (ηh − ηa·βd − (ηh+ηa)·βx)/(ηh+ηa)`. Con `η = 1`: `(1 − βd − 2βx)/2`.
"""
@inline function alpha_estrella_t(βd::T, βx::T, ηh::T, ηa::T) where {T<:Real}
    return (ηh - ηa * βd - (ηh + ηa) * βx) / (ηh + ηa)
end

"""Frontera en `βd` con `βx = 0`: `ηa(α+βd) = ηh(1−α)`. Con `η=1`: `1−2α`."""
@inline function frontera_beta_d(α::T, ηh::T, ηa::T) where {T<:Real}
    return (ηh * (one(T) - α) - ηa * α) / ηa
end

"""Frontera en `βx` con `βd = 0`: `βx = ηh/(ηh+ηa) − α`. Con `η=1`: `1/2 − α`."""
@inline function frontera_beta_x(α::T, ηh::T, ηa::T) where {T<:Real}
    return ηh / (ηh + ηa) - α
end

# Envoltorios con promoción de tipos (uso fuera del camino caliente).
function deriva(α, βd, βx; ηh = 1, ηa = 1)
    T = promote_type(typeof(α), typeof(βd), typeof(βx), typeof(ηh), typeof(ηa))
    return deriva_t(T(α), T(βd), T(βx), T(ηh), T(ηa))
end
function alpha_estrella(βd, βx; ηh = 1, ηa = 1)
    T = promote_type(typeof(βd), typeof(βx), typeof(ηh), typeof(ηa))
    return alpha_estrella_t(T(βd), T(βx), T(ηh), T(ηa))
end

# -----------------------------------------------------------------------------
# 2 · Las tres variantes de coste de identidad, y su dependencia de κ
# -----------------------------------------------------------------------------
"""Coste por identidad de la variante `:A` (stake proporcional): `σ·f`."""
@inline costo_A(f::T, σ::T) where {T<:Real} = σ * f
"""Coste esperado por identidad de `:B` (depósito fijo confiscable): `D·κ·q`."""
@inline costo_B(κq::T, D::T) where {T<:Real} = D * κq
"""Coste por identidad de `:C` (tasa fija no recuperable): `τ`."""
@inline costo_C(τ::T) where {T<:Real} = τ

"""
    depende_de_kappa(v::Symbol) -> Bool

Sólo `:B` depende de `κ` como coste por identidad. `:A` y `:C` no. (Que `:A` no
dependa de `κ` no la salva: es proporcional al espacio y el teorema de
exclusividad la descarta por otra vía.)
"""
depende_de_kappa(v::Symbol) = v === :B

"""
    coste_por_byte(v, s_id, p...) -> Real

Coste por byte de una identidad que representa `s_id` bytes de espacio. Es el
criterio del teorema: hace falta que **no** tienda a una constante cuando
`s_id → 0`, es decir que crear una identidad cueste algo no proporcional a lo que
representa. `:A` da `σ` constante (no lo cumple); `:B` da `Dκq/s_id` y `:C` da
`τ/s_id` (sí lo cumplen).
"""
function coste_por_byte(v::Symbol, s_id::T, p::Vararg{T}) where {T<:Real}
    if v === :A
        return p[1]
    elseif v === :B
        return p[1] * p[2] / s_id
    elseif v === :C
        return p[1] / s_id
    else
        throw(ArgumentError("variante desconocida: $v"))
    end
end

# -----------------------------------------------------------------------------
# 3 · Beneficio de cofarmar y coste de cada evasión
# -----------------------------------------------------------------------------
"""
    ganancia_cofarmacion(f, λ, I, Pwin, Th)

Ganancia esperada de cofarmar durante `T_h`, para una granja con fracción de
espacio `f`: `f·λ·I·P_win·T_h` [u.e.]. **Es lineal en `f`** porque la recompensa
por espacio lo es — la premisa del propio teorema de exclusividad. Ésa es la
razón de que un coste fijo no pueda dominarla para todo tamaño.
"""
@inline function ganancia_cofarmacion(f::T, λ::T, I::T, Pwin::T, Th::T) where {T<:Real}
    return f * λ * I * Pwin * Th
end

"""
    perdida_por_infraccion(ρ_ret, I, Tv, c_r, M)

`L_p = ρ_ret·I·T_v + c_r + I·M`: lo que pierde un granjero castigado, con los
términos de `P-ZRX/P-CANDIDATA` §5 citados por `P-PRESTAMO` §5.1. Todos símbolos.
"""
@inline function perdida_por_infraccion(ρ_ret::T, I::T, Tv::T, c_r::T, M::T) where {T<:Real}
    return ρ_ret * I * Tv + c_r + I * M
end

"""
    f_detenida(τ, κq, Lp, λ, I, Pwin, Th, c_b; n_extra=1)

Fracción de espacio MÁXIMA que queda disuadida de cofarmar. El granjero elige la
evasión **más barata** entre:

  · quedarse con UNA identidad en dos ramas → coste esperado `κ·q·L_p`;
  · PARTIR en `n_extra` identidades extra          → coste `n_extra·τ + c_b·f`.

Como el granjero puede elegir la más barata, hay que cerrar **las dos**, luego el
tamaño disuadido es el mínimo de los dos umbrales:

    f_det = min( κq·L_p/(λIPTh),  τ/(λIPTh − c_b) )

⚠️ **Consecuencia que gobierna el encargo:** si `κ·q = 0`, el primer umbral es 0
y `f_det = 0` **para todo `τ`**: sin evidencia no hay nada que disuadir, porque
la evasión más barata (una identidad, dos ramas) **no usa ninguna identidad
nueva** y por tanto no paga tasa alguna. Devuelve `Inf` si el coste de bytes solo
ya disuade a todos (`c_b ≥ λIPTh`).
"""
@inline function f_detenida(τ::T, κq::T, Lp::T, λ::T, I::T, Pwin::T, Th::T, c_b::T;
                            n_extra::Int = 1) where {T<:Real}
    denominador = λ * I * Pwin * Th
    κq == zero(T) && return zero(T)            # sin prueba, la vía de 1 identidad es gratis
    f_κ = κq * Lp / denominador
    if c_b ≥ denominador
        f_τ = typemax(T)                        # los bytes solos disuaden a todos
    else
        f_τ = (n_extra * τ) / (denominador - c_b)
    end
    return min(f_κ, f_τ)
end

"""
    tau_minimo_fee(f_estrella, λ, I, Pwin, Th, c_b; n_extra=1)

Tasa mínima para que la vía de partir deje de compensar a una granja marginal de
tamaño `f_estrella`: `n_extra·τ ≥ f*(λIPTh − c_b)`. **Es proporcional a `f*`**, el
tamaño de la granja marginal — es decir, al espacio que hay que negar.
"""
@inline function tau_minimo_fee(f_estrella::T, λ::T, I::T, Pwin::T, Th::T, c_b::T;
                                n_extra::Int = 1) where {T<:Real}
    return f_estrella * (λ * I * Pwin * Th - c_b) / n_extra
end

"""Tasa mínima expresada como intervalo, para no fijar `n_extra`."""
function tau_minimo_fee_rango(f_estrella::T, λ::T, I::T, Pwin::T, Th::T, c_b::T) where {T<:Real}
    return (tau_minimo_fee(f_estrella, λ, I, Pwin, Th, c_b; n_extra = 1),
            tau_minimo_fee(f_estrella, λ, I, Pwin, Th, c_b; n_extra = 2))
end

"""
    kappa_minimo(f_estrella, Lp, λ, I, Pwin, Th)

Condición de `κ·q` para que **la vía de una sola identidad** quede disuadida en
la granja marginal: `κq ≥ f*·λIPTh/L_p`. Es la condición que la tasa **no** puede
sustituir (ver `f_detenida`).
"""
@inline function kappa_minimo(f_estrella::T, Lp::T, λ::T, I::T, Pwin::T, Th::T) where {T<:Real}
    return f_estrella * (λ * I * Pwin * Th) / Lp
end

"""Coste de capturar `βx` por la vía exclusiva: renuncia al ingreso público."""
@inline function costo_beta_x(βx::T, λ::T, I::T, T_hor::T) where {T<:Real}
    return βx * λ * I * T_hor
end

# -----------------------------------------------------------------------------
# 4 · Distribuciones de tamaño de granja
# -----------------------------------------------------------------------------
"""
    ParetoTruncado(fmin, fmax, a)

Pareto truncada en `[fmin, fmax]` con exponente de cola `a`, sobre la fracción de
espacio por granja. **Hipótesis declarada** (H3 de `P-ZRX/P-CLAVE`, exponente
`2,2`), no medición.
"""
struct ParetoTruncado{T<:Real}
    fmin::T
    fmax::T
    a::T
    function ParetoTruncado(fmin::T, fmax::T, a::T) where {T<:Real}
        fmin > 0 || throw(ArgumentError("fmin debe ser > 0"))
        fmax > fmin || throw(ArgumentError("fmax debe ser > fmin"))
        a > 0 || throw(ArgumentError("a debe ser > 0"))
        return new{T}(fmin, fmax, a)
    end
end

"""
    Phi_espacio(dist, x)

Fracción del **espacio** en granjas de tamaño `≥ x`. Para la Pareto truncada,
`Φ(x) = (x^{1−a} − fmax^{1−a})/(fmin^{1−a} − fmax^{1−a})`. Es la medida
**sesgada por tamaño**, que no es la de conteo (`Psi_conteo`).
"""
function Phi_espacio(d::ParetoTruncado{T}, x::Real) where {T<:Real}
    x ≤ d.fmin && return one(T)
    x ≥ d.fmax && return zero(T)
    b = one(T) - d.a
    num = x^b - d.fmax^b
    den = d.fmin^b - d.fmax^b
    return num / den
end

"""Fracción del **número** de granjas con tamaño `≥ x` (medida sin sesgo)."""
function Psi_conteo(d::ParetoTruncado{T}, x::T) where {T<:Real}
    x ≤ d.fmin && return one(T)
    x ≥ d.fmax && return zero(T)
    num = x^(-d.a) - d.fmax^(-d.a)
    den = d.fmin^(-d.a) - d.fmax^(-d.a)
    return num / den
end

"""
    inversa_Phi(d, p)

Tamaño `f*` tal que la fracción de espacio en granjas `≥ f*` es `p`. Es la
**granja marginal** que suministra el top `p` del espacio; con `p = 1−2α`, el
tamaño que decide la tasa mínima.
"""
function inversa_Phi(d::ParetoTruncado{T}, p::Real) where {T<:Real}
    (0 ≤ p ≤ 1) || throw(ArgumentError("p debe estar en [0,1]"))
    p == 0 && return d.fmax
    p == 1 && return d.fmin
    b = one(T) - d.a
    valor = p * (d.fmin^b - d.fmax^b) + d.fmax^b
    return valor^(one(T) / b)
end

"""
    Discreta(f, w)

Distribución **discreta explícita**: `f[i]` = tamaño (fracción de espacio) de una
granja, `w[i]` = fracción del ESPACIO que representa. `Σw = 1`. Es la forma
exacta y sin hipótesis funcional: `Rational{BigInt}` entra sin cambios.
"""
struct Discreta{T<:Real}
    f::Vector{T}
    w::Vector{T}
    function Discreta(f::Vector{T}, w::Vector{T}) where {T<:Real}
        length(f) == length(w) || throw(ArgumentError("f y w deben tener la misma longitud"))
        all(>(0), f) || throw(ArgumentError("tamaños deben ser > 0"))
        all(≥(0), w) || throw(ArgumentError("pesos deben ser ≥ 0"))
        return new{T}(f, w)
    end
end

"""Fracción de espacio en granjas de tamaño `≥ x` (suma exacta de pesos)."""
function Phi_espacio(d::Discreta{T}, x::Real) where {T<:Real}
    s = zero(T)
    @inbounds for i in eachindex(d.f)
        d.f[i] ≥ x && (s += d.w[i])
    end
    return s
end

"""Tamaño más pequeño `f` con `Φ(f) ≤ p` (búsqueda exacta, sin fórmula)."""
function inversa_Phi(d::Discreta{T}, p::Real) where {T<:Real}
    orden = sortperm(d.f)                      # ascendente
    acum = zero(T)
    for i in orden
        acum += d.w[i]
        (one(T) - acum) ≤ p && return d.f[i]
    end
    return d.f[orden[end]]
end

# Familias declaradas ------------------------------------------------------
"""
    granjas_iguales(N) -> Discreta

`N` granjas idénticas de tamaño `1/N`. **Control de degeneración:** sin
dispersión de tamaños no puede haber regresividad, y la tasa que funciona sale
proporcional al espacio, es decir variante `:A`.
"""
function granjas_iguales(N::Integer)
    N ≥ 2 || throw(ArgumentError("N ≥ 2"))
    f = fill(1 // BigInt(N), N)
    w = fill(1 // BigInt(N), N)
    return Discreta(f, w)
end

"""
    Iguales(N)

`N` granjas idénticas de tamaño `1/N`, en forma **comprimida** (no materializa el
vector: `Phi_espacio` es una función escalón). **Control de degeneración:** sin
dispersión de tamaños no puede haber regresividad, y la tasa que funciona sale
proporcional al espacio, es decir variante `:A`.
"""
struct Iguales{T<:Real}
    N::Int
    f::T
    function Iguales(N::Integer, ::Type{T} = Rational{BigInt}) where {T<:Real}
        N ≥ 2 || throw(ArgumentError("N ≥ 2"))
        return new{T}(Int(N), one(T) / T(N))
    end
end
Phi_espacio(d::Iguales{T}, x::Real) where {T<:Real} = x ≤ d.f ? one(T) : zero(T)
"""Granja marginal de `Iguales`: todas miden `1/N`, luego `f* = 1/N` (para `p < 1`)."""
inversa_Phi(d::Iguales{T}, p::Real) where {T<:Real} = d.f

"""
    DosNiveles(θ, f_grande, K)

Hipótesis declarada de **dispersión extrema**: una granja industrial con fracción
de espacio `θ` y `K` granjas pequeñas idénticas que se reparten `1−θ`. Comprimida:
`Φ(x)` toma tres valores (`1`, `θ`, `0`).
"""
struct DosNiveles{T<:Real}
    θ::T
    f_grande::T
    K::Int
    f_peq::T
    function DosNiveles(θ::T, f_grande::T, K::Integer) where {T<:Real}
        (0 < θ < 1) || throw(ArgumentError("θ ∈ (0,1)"))
        K ≥ 1 || throw(ArgumentError("K ≥ 1"))
        f_grande > 0 || throw(ArgumentError("f_grande > 0"))
        return new{T}(θ, f_grande, Int(K), (one(T) - θ) / T(K))
    end
end
function Phi_espacio(d::DosNiveles{T}, x::Real) where {T<:Real}
    x ≤ d.f_peq && return one(T)
    x ≤ d.f_grande && return d.θ
    return zero(T)
end
"""Granja marginal: la grande si el top `p` cabe en ella; si no, una pequeña."""
inversa_Phi(d::DosNiveles{T}, p::Real) where {T<:Real} = p < d.θ ? d.f_grande : d.f_peq

"""
    dos_niveles_discreta(θ, f_grande, K) -> Discreta

La misma familia de dos niveles **materializada** como lista de granjas. Sólo para
las instancias pequeñas del oráculo de reclutamiento (fuerza bruta); para las
cifras publicadas se usa `DosNiveles`, que no materializa nada.
"""
function dos_niveles_discreta(θ::Rational{BigInt}, f_grande::Rational{BigInt}, K::Integer)
    K ≥ 1 || throw(ArgumentError("K ≥ 1"))
    f = Vector{Rational{BigInt}}(undef, K + 1)
    w = Vector{Rational{BigInt}}(undef, K + 1)
    f[1] = f_grande
    w[1] = θ
    peq = (1 - θ) // BigInt(K)
    for i in 2:(K + 1)
        f[i] = peq
        w[i] = peq
    end
    return Discreta(f, w)
end

# -----------------------------------------------------------------------------
# 5 · Horarios de cuota φ(f) y la dicotomía partición/regresividad
# -----------------------------------------------------------------------------
abstract type Horario{T<:Real} end

"""φ(f) = σ·f — proporcional al espacio (variante `:A`)."""
struct Lineal{T<:Real} <: Horario{T}
    σ::T
end
"""φ(f) = τ — tasa fija pura (variante `:C`), no proporcional al espacio."""
struct Fija{T<:Real} <: Horario{T}
    τ::T
end
"""φ(f) = τ + σ·f — componente fija + proporcional."""
struct FijaLineal{T<:Real} <: Horario{T}
    τ::T
    σ::T
end
"""φ(f) = c·√f — estrictamente cóncava, no lineal en ningún tramo."""
struct Raiz{T<:Real} <: Horario{T}
    c::T
end
"""φ(f) = τ·⌈f/Smax⌉ — tasa fija + tope de espacio por identidad."""
struct Tope{T<:Real} <: Horario{T}
    τ::T
    Smax::T
end

"""Cuota pagada por una identidad que representa la fracción de espacio `f`."""
function cuota(h::Lineal{T}, f::T) where {T<:Real}
    return h.σ * f
end
function cuota(h::Fija{T}, f::T) where {T<:Real}
    return f > zero(T) ? h.τ : zero(T)
end
function cuota(h::FijaLineal{T}, f::T) where {T<:Real}
    return f > zero(T) ? h.τ + h.σ * f : zero(T)
end
function cuota(h::Raiz{T}, f::T) where {T<:Real}
    return f > zero(T) ? h.c * sqrt(f) : zero(T)
end
function cuota(h::Tope{T}, f::T) where {T<:Real}
    f ≤ zero(T) && return zero(T)
    return h.τ * ceil(f / h.Smax)
end

"""
    particion_mas_cara(h, f, N) -> Bool

`N` identidades de `f/N` cuestan **estrictamente más** que una de `f`. Es la
propiedad «partir cuesta» que el encargo §2.3 pregunta si puede existir junto a
«acumular no».
"""
function particion_mas_cara(h::Horario{T}, f::T, N::Integer) where {T<:Real}
    N ≥ 2 || throw(ArgumentError("N ≥ 2"))
    return N * cuota(h, f / N) > cuota(h, f)
end

"""
    regresiva(h, f1, f2) -> Bool

Alias histórico de `carga_decreciente`. Se conserva el nombre porque el encargo
§2.3 pregunta en esos términos.
"""
regresiva(h::Horario{T}, f1::T, f2::T) where {T<:Real} = carga_decreciente(h, f1, f2)

"""
    carga_por_byte(h, f) -> T

Cuota por unidad de espacio: `φ(f)/f`. Es la carga relativa que soporta una
granja de tamaño `f`. La **regresividad** es exactamente que esta función sea
estrictamente decreciente.
"""
function carga_por_byte(h::Horario{T}, f::T) where {T<:Real}
    return cuota(h, f) / f
end

"""
    carga_decreciente(h, f1, f2) -> Bool

`f1 < f2` y `φ(f1)/f1 > φ(f2)/f2`: la granja pequeña paga **más por unidad de
espacio**. Es la definición exacta de regresividad, sin aproximación.
"""
function carga_decreciente(h::Horario{T}, f1::T, f2::T) where {T<:Real}
    f1 < f2 || throw(ArgumentError("se espera f1 < f2"))
    return carga_por_byte(h, f1) > carga_por_byte(h, f2)
end

"""
    subaditiva_en(h, a, b) -> Bool

`φ(a+b) ≤ φ(a)+φ(b)`. Es la versión **no estricta**; la que equivale a la
regresividad es la estricta (`subaditiva_estricta_en`), porque la tasa lineal
también cumple ésta con igualdad y no es regresiva.
"""
function subaditiva_en(h::Horario{T}, a::T, b::T) where {T<:Real}
    return cuota(h, a + b) ≤ cuota(h, a) + cuota(h, b)
end

"""
    subaditiva_estricta_en(h, a, b) -> Bool

`φ(a+b) < φ(a)+φ(b)`. **Es la equivalencia exacta** con «partir cuesta» y con la
regresividad: la única familia que no la cumple es la proporcional al espacio,
que es la variante `:A`. La escalera con tope puede cumplirla en unos tramos y no
en otros: es el indicio de que el tope rompe la propiedad.
"""
function subaditiva_estricta_en(h::Horario{T}, a::T, b::T) where {T<:Real}
    return cuota(h, a + b) < cuota(h, a) + cuota(h, b)
end

"""
    concava_en(h, a, b) -> Bool

Concavidad en el punto medio: `φ((a+b)/2) ≥ (φ(a)+φ(b))/2`. Es **suficiente**
para la subaditividad, no necesaria: `φ(f)=τ` es cóncava (con igualdad) y
subaditiva estricta al mismo tiempo.
"""
function concava_en(h::Horario{T}, a::T, b::T) where {T<:Real}
    medio = (a + b) / 2
    return cuota(h, medio) ≥ (cuota(h, a) + cuota(h, b)) / 2
end

"""Concavidad estricta en el punto medio (`>` en vez de `≥`)."""
function estrictamente_concava_en(h::Horario{T}, a::T, b::T) where {T<:Real}
    medio = (a + b) / 2
    return cuota(h, medio) > (cuota(h, a) + cuota(h, b)) / 2
end

"""Tasa efectiva por byte de la escalera con tope: `τ/Smax` en el límite."""
tasa_por_byte_tope(h::Tope{T}) where {T<:Real} = h.τ / h.Smax

"""Cota de la desviación de la escalera respecto de su recta asíntota."""
function desviacion_tope(h::Tope{T}, f::T) where {T<:Real}
    f > zero(T) || throw(ArgumentError("f > 0"))
    n = ceil(f / h.Smax)
    return (n * h.Smax - f) / f
end
