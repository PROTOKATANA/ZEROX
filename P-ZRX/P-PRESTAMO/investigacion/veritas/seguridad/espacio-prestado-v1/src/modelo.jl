#= espacio-prestado-v1 · modelo.jl
   Tipos, definiciones y álgebra exacta del modelo de espacio prestado.

   Unidades y convenciones (declaradas en el INFORME, §1):
   · TODO espacio está normalizado a 1. `α`, `β_d`, `β_x` son FRACCIONES DE ESPACIO, no tasas.
   · `η_h`, `η_a` [adimensionales] son el trabajo (peso) efectivo por unidad de espacio y de tiempo
     de la rama pública y de la privada. `η_h = η_a = 1` es el caso IDEALIZADO, etiquetado así.
   · `α*` es la fracción propia del atacante que hace `g = 0`; `g` es la DIFERENCIA DE DERIVA
     (privada menos pública) en unidades de peso por unidad de tiempo.
   · Nada de aquí fija un parámetro de consenso: todo son entradas.
=#

module Modelo

export Deriva, deriva, alpha_estrella, region_gana
export fraccion_honesta, fraccion_retenida_privada, espacio_valido
export p_de_alpha, alpha_de_p, razon_q_p, deficit_esperado
export PerdidaGranjero, perdida_total, perdida_esperada
export soborno_necesario, RegionCastigo, coste_absoluto

"""
    Deriva(α, βd, βx, ηh, ηa)

Estado de reparto de espacio. `α` propio del atacante, `βd` doble farmeo,
`βx` alquiler exclusivo; el resto, `1-α-βd-βx`, leales (solo pública).
"""
struct Deriva{T<:Real}
    α::T
    βd::T
    βx::T
    ηh::T
    ηa::T
end

"""
    espacio_valido(d) -> Bool

Reparto físicamente admisible: todas las fracciones no negativas y las leales no negativas.
"""
@inline function espacio_valido(d::Deriva)
    return d.α ≥ 0 && d.βd ≥ 0 && d.βx ≥ 0 && d.α + d.βd + d.βx ≤ 1
end

"""
    fraccion_honesta(d) -> 1 - α - βx

Espacio que trabaja en la rama pública: leales + `β_d` (el doble granjero sigue publicando).
No depende de `β_d`: el doble granjero no añade ni quita a la pública.
"""
@inline fraccion_honesta(d::Deriva) = 1 - d.α - d.βx

"""
    fraccion_retenida_privada(d) -> α + βd + βx

Espacio que trabaja en la rama privada.
"""
@inline fraccion_retenida_privada(d::Deriva) = d.α + d.βd + d.βx

"""
    deriva(d) -> g

Diferencia de deriva (privada menos pública) en unidades de peso por unidad de tiempo:

    g = η_a·(α + β_d + β_x) − η_h·(1 − α − β_x)

`g > 0` ⇒ la privada gana la carrera; `g = 0` ⇒ empate de medias.
"""
@inline function deriva(d::Deriva)
    return d.ηa * fraccion_retenida_privada(d) - d.ηh * fraccion_honesta(d)
end

"""
    alpha_estrella(βd, βx, ηh, ηa) -> α*

Frontera de deriva (identidad aritmética exacta; `demostrado`):

    α*(β_d, β_x, η_h, η_a) = (η_h − η_a·β_d − (η_h + η_a)·β_x) / (η_h + η_a)

Casos particulares exactos: `α*(0,0,1,1) = 1/2`; `α*(β_d,0,1,1) = (1−β_d)/2`;
`α*(0,β_x,1,1) = 1/2 − β_x` (alquiler exclusivo: `α + β_x > 1/2`).
"""
@inline function alpha_estrella(βd, βx = 0, ηh = 1, ηa = 1)
    return (ηh - ηa * βd - (ηh + ηa) * βx) / (ηh + ηa)
end

"""
    region_gana(d) -> Bool

¿Puede el atacante ganar la carrera de medias con este reparto?
"""
@inline region_gana(d::Deriva) = deriva(d) > 0

# ------------------------------------------------- F2 · tasas, ventana, déficit

"""
    p_de_alpha(α, βd, βx, ηh, ηa) -> p

Tasa por paso del atacante en el paseo normalizado ±1. UNIDAD DE TIEMPO = un bloque
producido entre las dos ramas (el «paso»). Si la rama pública aporta `μ_p` bloques por
slot y la privada `μ_a`, entonces `p = μ_a/(μ_a+μ_p)`.

AQUÍ ESTÁ LA HIPÓTESIS QUE CODIFICA LA CONCLUSIÓN (H-PUENTE): se toma `μ_a/μ_p =
(α+β_d+β_x)·η_a / ((1−α−β_x)·η_h)`, es decir el puente «espacio → tasa de peso» es
proporcional y sin saturación. `DEFECTOS.md` C1 demuestra que ese puente NO está
implementado en ningún instrumento del repositorio: todo resultado de F2 está
CONDICIONADO a esta hipótesis.
"""
@inline function p_de_alpha(α, βd, βx = 0, ηh = 1, ηa = 1)
    ra = ηa * (α + βd + βx)
    rp = ηh * (1 - α - βx)
    return ra / (ra + rp)
end

"""
    alpha_de_p(p, βd, βx, ηh, ηa) -> α

Inversa de `p_de_alpha` en `α` (resuelve la razón `μ_a/μ_p = p/(1−p)`).
"""
@inline function alpha_de_p(p, βd, βx = 0, ηh = 1, ηa = 1)
    ρ = p / (1 - p)                       # μ_a/μ_p exigido
    return (ρ * ηh * (1 - βx) - ηa * (βd + βx)) / (ηa + ρ * ηh)
end

@inline razon_q_p(p) = (1 - p) / p

"""
    deficit_esperado(α, βd, βx, ηh, ηa, F) -> d·g  (en unidades de peso)

Déficit inicial en unidades de peso: ventaja de la rama pública al final de la ventana
`F`, `(μ_p − μ_a)·F`. Es el `d` del paseo, en unidades de peso.
"""
@inline function deficit_esperado(α, βd, βx, ηh, ηa, F)
    μa = ηa * (α + βd + βx)
    μp = ηh * (1 - α - βx)
    return (μp - μa) * F
end

# ------------------------------------------------------- F3/F5 · juego económico

"""
    PerdidaGranjero(ρ_ret, T_v, ingreso, c_r, M, λ)

Pérdida del granjero reclutado si lo castigan, en unidades de emisión de la red.
`ingreso` = ingreso del granjero por unidad de tiempo (∝ su espacio);
`T_v` [unidades de tiempo] duración del vesting; `M` [unidades de tiempo] maduración;
`c_r` = coste de replotear (misma unidad que el ingreso).
"""
struct PerdidaGranjero{T<:Real}
    ρ_ret::T
    T_v::T
    ingreso::T
    c_r::T
    M::T
    λ::T
end

"""Pérdida bruta (sin cobertura): retenido + replot + ingreso perdido durante `M`."""
@inline function perdida_total(g::PerdidaGranjero)
    return g.ρ_ret * g.ingreso * g.T_v + g.c_r + g.ingreso * g.M
end

"""
    perdida_esperada(pg, κ, q_inclusion) -> κ·q·pérdida_total

Pérdida esperada del granjero castigado. `κ` ∈ [0,1] es la fracción del doble farmeo
PUBLICADO que deja evidencia castigable (ADENDA-1 §B); `q_inclusion` ∈ [0,1] es la
probabilidad de que la evidencia entre en la historia seleccionada (censura: `q_gana`
si la privada gana, `q_pierde` si pierde).
"""
@inline perdida_esperada(pg::PerdidaGranjero, κ, q_inclusion) = κ * q_inclusion * perdida_total(pg)

"""
    soborno_necesario(pg, κ, q_inclusion, ganancia_extra) -> b*

Soborno mínimo que hace aceptar al granjero racional:
`b > κ·q·pérdida − ganancia_extra`. Devuelve `b*` tal que acepta si `b > b*`.
"""
@inline function soborno_necesario(pg::PerdidaGranjero, κ, q_inclusion, ganancia_extra = 0)
    return perdida_esperada(pg, κ, q_inclusion) - ganancia_extra
end

"""
    RegionCastigo(V, N_recl, n_slots)

Adversario económico. `V` [unidades de emisión] valor del ataque para el atacante;
`N_recl` número de reclutados; `n_slots` duración del ataque en slots. Todo entrada.
"""
struct RegionCastigo{T<:Real}
    V::T
    N_recl::T
    n_slots::T
end

"""
    coste_absoluto(rc, pg, κ, q_inclusion, coste_pot, α_propio) -> NamedTuple

Coste ABSOLUTO del ataque, en unidades de emisión, con desglose. `α_propio` (espacio
propio retirado de la pública) y `coste_pot` (cómputo de verificación PoT de la rama
privada) se devuelven aparte: no se compran con el soborno.
"""
function coste_absoluto(rc::RegionCastigo, pg::PerdidaGranjero, κ, q_inclusion, coste_pot, α_propio)
    b = soborno_necesario(pg, κ, q_inclusion)
    sobornos = max(b, zero(b)) * rc.N_recl
    pot = coste_pot * rc.n_slots
    return (total = sobornos + pot, sobornos = sobornos, pot = pot, α_propio = α_propio)
end

end # module
