# src/modelo.jl — TR-v0.1 · modelo exacto del peso híbrido espacio + trabajo rival
#
# Encargo: P-ZRX/P-RIVAL/PROMPT.md. Instrumento: veritas/consenso/trabajo-rival-v1.
#
# Convenciones (todas las fracciones son Rational{BigInt}; nunca Float64 en una frontera):
#
#   espacio total ................................ 1
#   trabajo rival honesto de referencia .......... 1
#   α    espacio propio del atacante (retirado de la pública)
#   β_d  espacio que farmea LAS DOS ramas (sigue publicando y alimenta la privada)
#   β_x  espacio que ABANDONA la pública (exclusivo de la privada)
#   θ    fracción de peso que aporta el trabajo rival (0 ≤ θ < 1); el peso de espacio es (1−θ)
#   ρ    trabajo rival del atacante en la privada, en unidades del honesto (ρ = 1 ⇒ paridad)
#   c    trabajo rival que la compuerta exige POR UNIDAD DE ESPACIO (c = 0 ⇒ sin compuerta)
#
# Reparto (idéntico al del texto de P-ZRX/P-PRESTAMO/investigacion/INFORME.md §1):
#   σ_pub  = 1 − α − β_x          (leales + β_d: el doble granjero SIGUE publicando)
#   σ_priv = α + β_d + β_x        (β_d suma a la privada sin restar a la pública)
#   σ_pub + σ_priv = 1 + β_d      (el exceso β_d es exactamente la no-rivalidad del espacio)
#
# Este módulo NO fija θ, β_d, β_x, α, ρ ni c. Todos son entradas.

const R = Rational{BigInt}

espacio_publico(α, β_d, β_x) = 1 - α - β_x
espacio_privado(α, β_d, β_x) = α + β_d + β_x

# ---------------------------------------------------------------------------
# 1 · Composición ADITIVA (la que se analiza como principal)
#     W_b = (1−θ)·σ_b + θ·ρ_b
# ---------------------------------------------------------------------------

# Deriva: tasa de peso privada − tasa de peso pública.
g_aditivo(α, β_d, β_x, θ, ρ) = (1 - θ) * (2α + β_d + 2β_x - 1) + θ * (ρ - 1)

# Frontera exacta: despejar g = 0 en α.  θ = 1 se trata aparte (el espacio no pesa).
function alpha_aditivo(β_d, β_x, θ, ρ)
    θ == 1 && error("alpha_aditivo: θ = 1 es degenerado (el espacio no entra en el peso)")
    (1 - β_d - 2β_x - θ * (ρ - 1) / (1 - θ)) // 2
end

# Control obligatorio del encargo §4: θ = 0 ⇒ α* = (1 − β_d − 2β_x)/2.
alpha_control_prestamo(β_d, β_x) = (1 - β_d - 2β_x) // 2

# Desplazamiento de nivel que introduce la pata (constante en β_d y β_x):
#   α*(β;θ,ρ) − α*_control(β) = −θ(ρ−1) / (2(1−θ))
desplazamiento_nivel(θ, ρ) = -θ * (ρ - 1) / (2 * (1 - θ))

# Ventaja de umbral de un reparto: cuánto BAJA el umbral por usar β_d y β_x.
#   V(β_d,β_x) = α*(0,0) − α*(β_d,β_x) = (β_d + 2β_x)/2   [independiente de θ y ρ]
ventaja_umbral(β_d, β_x, θ, ρ) = alpha_aditivo(0, 0, θ, ρ) - alpha_aditivo(β_d, β_x, θ, ρ)

# Ventaja MARGINAL de una unidad de β_d (derivada de la deriva respecto de β_d):
#   ∂g/∂β_d = (1−θ) + θ·c        [sin compuerta, c = 0 ⇒ 1−θ]
# En el umbral la ventaja por unidad de β_d es 1/2, y con la compuerta se amplifica:
#   ∂α*/∂β_d = −[(1−θ) + θ·c] / (2(1−θ))     (trabajo extra comprado)
#   ∂α*/∂β_d = −[(1−θ) + 2θ·c] / (2(1−θ))    (trabajo reasignado desde la pública)
ventaja_marginal_aditiva(θ, c) = (1 - θ) + θ * c

# Ventaja de UMBRAL por unidad de espacio en la composición ADITIVA con compuerta
# cuyo trabajo SÍ entra en el peso (Modelo A; el trabajo de la pública no cambia
# para β_d y acompaña al espacio para β_x).  Tres casos, exactos:
#   · β_d con trabajo COMPRADO para la privada:  V = [1 + θc/(1−θ)]/2   ≥ 1/2
#   · β_d con trabajo REASIGNADO de la pública:  V = [1 + 2θc/(1−θ)]/2  ≥ 1/2
#   · β_x (el trabajo acompaña al espacio):      V = 1 + θc/(1−θ) = 2×V_βd(comprado)
# En los tres, V(θ,c) ≥ V(0,c) para θ<1: en la aditiva la pata NUNCA reduce la
# ventaja.  (Con compuerta cuyo trabajo NO entra en el peso —composición de umbral—
# el factor [1+θc/(1−θ)] desaparece y V vuelve a β_d/2 + β_x.)
ventaja_beta_d(θ, c) = (1 + θ * c / (1 - θ)) / 2
ventaja_beta_d_reasignado(θ, c) = (1 + 2 * θ * c / (1 - θ)) / 2
ventaja_beta_x(θ, c) = 1 + θ * c / (1 - θ)          # = 2 × ventaja_beta_d (comprado)

# Umbral EXACTO de cierre por IMPOSIBILIDAD: θ tal que α*(β_d,β_x) > 1, es decir el
# atacante no puede reunir espacio suficiente.  Exige ρ < 1 (el honesto gana la
# carrera de trabajo).
#   α*(β_d,β_x) = [1 − β_d − 2β_x + θ(1−ρ)/(1−θ)]/2 > 1
#   ⟺  θ > (1 + β_d + 2β_x) / (2 − ρ + β_d + 2β_x)   ≥ 1/2
function theta_cierre_imposible(β_d, β_x, ρ)
    ρ < 1 || return missing
    return (1 + β_d + 2β_x) / (2 - ρ + β_d + 2β_x)
end

# ---------------------------------------------------------------------------
# 2 · Composición MULTIPLICATIVA (Cobb–Douglas)  W_b = σ_b^(1−θ) · ρ_b^θ
#     Se compara en forma exacta elevando a q, con θ = p/q.
# ---------------------------------------------------------------------------

# signo de  σ_priv^(1−θ)·ρ_priv^θ  −  σ_pub^(1−θ)·ρ_pub^θ   (θ = θ_p/θ_q)
# devuelve -1, 0 o +1. Potencias de exponente entero no negativo ⇒ exacto.
function signo_multiplicativo(σ_priv, σ_pub, ρ_priv, ρ_pub, θ::R)
    θ_p = numerator(θ)
    θ_q = denominator(θ)
    (0 <= θ_p < θ_q) || error("signo_multiplicativo: se exige 0 ≤ θ < 1")
    ρ_priv > 0 && ρ_pub > 0 ||
        error("signo_multiplicativo: el trabajo rival debe ser positivo")
    # bordes: un factor de espacio nulo decide sin ambigüedad
    σ_priv == 0 && return σ_pub == 0 ? 0 : -1
    σ_pub == 0 && return 1
    σ_priv > 0 && σ_pub > 0 ||
        error("signo_multiplicativo: espacio negativo")
    izq = σ_priv^(θ_q - θ_p) * ρ_priv^θ_p
    der = σ_pub^(θ_q - θ_p) * ρ_pub^θ_p
    return izq < der ? -1 : (izq > der ? 1 : 0)
end

# Frontera multiplicativa hallada por BISECCIÓN EXACTA sobre α (ruta independiente
# de la forma cerrada aditiva).  ρ_priv y ρ_pub entran como funciones de α.
function alpha_multiplicativo_biseccion(β_d, β_x, θ::R, ρ_priv, ρ_pub;
                                        iter = 400, lo = R(0), hi = nothing)    θ == 0 && return alpha_control_prestamo(β_d, β_x)
    hi = hi === nothing ? (1 - β_x) : hi
    f(α) = signo_multiplicativo(espacio_privado(α, β_d, β_x),
                                espacio_publico(α, β_d, β_x),
                                ρ_priv(α), ρ_pub(α), θ)
    f(lo) >= 0 && return R(0)
    f(hi) <= 0 && return hi
    for _ in 1:iter
        m = (lo + hi) // 2
        if f(m) >= 0
            hi = m
        else
            lo = m
        end
    end
    return (lo + hi) // 2
end

# Forma CERRADA de la frontera multiplicativa, para el artefacto y el contraste con la
# bisección exacta (Float64; la vía exacta de decisión es `alpha_multiplicativo_biseccion`).
#   W_b = σ_b^(1−θ)·ρ_b^θ  ⇒  (σ_priv/σ_pub)^(1−θ) = (ρ_pub/ρ_priv)^θ
#   k := (ρ_pub/ρ_priv)^(θ/(1−θ))  ⇒  α* = [k(1−β_x) − β_d − β_x]/(1+k)
function alpha_multiplicativo_cerrado(β_d::Real, β_x::Real, θ::Real,
                                      ρ_priv::Real, ρ_pub::Real)
    (0 <= θ < 1) || error("alpha_multiplicativo_cerrado: se exige 0 ≤ θ < 1")
    (ρ_priv > 0 && ρ_pub > 0) || error("alpha_multiplicativo_cerrado: trabajo positivo")
    k = (ρ_pub / ρ_priv)^(θ / (1 - θ))
    return (k * (1 - β_x) - β_d - β_x) / (1 + k)
end

# Ventaja de umbral multiplicativa.  Con k como arriba:
#   V(β_d,β_x) = [β_d + β_x·(1+k)] / (1+k)
# k crece con θ si ρ_pub > ρ_priv (el honesto tiene MÁS trabajo) ⇒ V DECRECE con θ.
# k decrece con θ si ρ_pub < ρ_priv (atacante con más trabajo) ⇒ V CRECE con θ.
function ventaja_multiplicativa(β_d::Real, β_x::Real, θ::Real,
                                ρ_priv::Real, ρ_pub::Real)
    a0 = alpha_multiplicativo_cerrado(0, 0, θ, ρ_priv, ρ_pub)
    a1 = alpha_multiplicativo_cerrado(β_d, β_x, θ, ρ_priv, ρ_pub)
    return a0 - a1
end

# ---------------------------------------------------------------------------
# 3 · Composición de UMBRAL (compuerta): el PoW es condición de validez con
#     dificultad fija y NO entra en el peso.  El peso es el de espacio.
#     Modelo discreto exacto para el oráculo de referencia.jl.
#     Un productor con espacio s y tasa de hash h produce bloques a tasa
#       min(s, h/D),  D = hashes esperados por bloque.
# ---------------------------------------------------------------------------
function gana_privada_umbral(s_pub, s_priv, h_pub, h_priv, D)
    prod_pub = min(s_pub, h_pub / D)
    prod_priv = min(s_priv, h_priv / D)
    return prod_priv > prod_pub ? 1 : (prod_priv < prod_pub ? -1 : 0)
end
