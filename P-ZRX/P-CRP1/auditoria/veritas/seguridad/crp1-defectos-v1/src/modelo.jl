# modelo.jl — modelo matemático, unidades y constantes exactas.
#
# Unidades explícitas (éste es el punto que D2 dice que CRP-v0.1 confundía):
#   * `sr` (rango de solución) es un entero en [0, 2^64−1].        unidad: rango
#   * `w(sr) = ⌊2^128/(sr+1)⌋` (C-GD-01).                          unidad: peso (entero)
#   * `pe = peso_relativo(sr0) = w(sr0)`.                          unidad de trabajo (u.t.)
#   * `d` en las tablas de cola corta es una VENTAJA INICIAL medida en u.t.
#   * `g` = bloques por unidad de trabajo (granularidad). Cada bloque pesa 1/g u.t.
#   * En la retícula de paso 1/g, un déficit `d` en u.t. son `z = d·g` posiciones.
#   * `α` es la fracción de espacio del adversario, `1−α` la honesta.
#   * `T` es un número de slots.

const DOS64 = big(2)^64
const DOS128 = big(2)^128

# ---------------------------------------------------------------------------
# Predicado PoAS y peso (C-GD-01). Exacto en enteros.
# ---------------------------------------------------------------------------

"""
`w(sr) = ⌊2^128/(sr+1)⌋` — peso de un bloque con rango de solución `sr` (C-GD-01).
Entero exacto (`BigInt`). Análogo de `peso_exacto` de CRP-v0.1 pero reimplementado desde la
fórmula, no importado.
"""
peso_exacto(sr::Integer)::BigInt = fld(DOS128, BigInt(sr) + 1)

"""
Número de residuos de `solution_distance` aceptados por el predicado PoAS en un dominio
circular de `2^64` puntos: la distancia circular vale `0` (1 punto) o `j ≥ 1` (2 puntos), con
`solution_distance ≤ solution_range ÷ 2` (división ENTERA). Por tanto
`|aceptados| = 2·⌊sr/2⌋ + 1`, que vale `sr+1` si `sr` es par y `sr` si `sr` es impar.

Contraste independiente: [`conteo_residuos_por_enumeracion`](@ref) lo cuenta a fuerza bruta en
dominios pequeños, y el predicado está leído de
`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:150-158` vía
`veritas/consenso/puerta-cobertura-v1/src/peso.jl:39-61` (PCO-v0.1).
"""
valores_aceptados(sr::Integer)::BigInt = 2 * (BigInt(sr) ÷ 2) + 1

"""
Probabilidad exacta de que un ensayo (par sector auditado × pieza) produzca un billete
aceptado: `|aceptados|/2^64`. `Rational{BigInt}` exacto.
"""
prob_billete(sr::Integer)::Rational{BigInt} = valores_aceptados(sr) // DOS64

"""
Trabajo esperado por ensayo, en las MISMAS unidades que `w`: `prob_billete(sr)·w(sr)`.
`Rational{BigInt}` exacto. Es la cantidad que D4 dice que CRP-v0.1 supuso lineal en `sr` en vez
de derivar del predicado.
"""
trabajo_por_ensayo(sr::Integer)::Rational{BigInt} = prob_billete(sr) * peso_exacto(sr)

"""
Forma cerrada exacta del trabajo por ensayo normalizado a `2^64`:
`T(sr)/2^64 = 1 − ρ/2^128` si `sr` es par, y `= (sr/(sr+1))·(1 − ρ/2^128)` si `sr` es impar,
con `ρ = 2^128 mod (sr+1)` (residuo del suelo). Devuelve `(valor, deficit_paridad, deficit_suelo)`.
"""
function descomposicion_trabajo(sr::Integer)
    s = BigInt(sr)
    rho = DOS128 % (s + 1)
    suelo = rho // DOS128                     # residuo del suelo, < 2^-64
    if iseven(s)
        return (valor = 1 - suelo, paridad = big(0)//big(1), suelo = suelo)
    else
        # (sr/(sr+1))·(1 − ρ/2^128) = sr/(sr+1) − sr·ρ/((sr+1)·2^128)
        p = s // (s + 1)
        return (valor = p - p * suelo, paridad = 1 // (s + 1), suelo = p * suelo)
    end
end

# ---------------------------------------------------------------------------
# Modelo de CRP-v0.1 (lo que el instrumento SUPONE). Sirve para medir la desviación.
# ---------------------------------------------------------------------------

"""
Modelo lineal supuesto por CRP-v0.1 (`src/modelo.jl:11,61`): `λ(s,sr) = s·λ0·sr/sr0`.
Devuelve la razón de trabajo por ensayo respecto de `sr0` que ese modelo implica,
`(sr/sr0)·(w(sr)/w(sr0))`, exacta.
"""
razon_crp(sr::Integer, sr0::Integer)::Rational{BigInt} =
    (BigInt(sr) // BigInt(sr0)) * (peso_exacto(sr) // peso_exacto(sr0))

"""
Razón de trabajo por ensayo respecto de `sr0` que implica el predicado PoAS EXACTO:
`T(sr)/T(sr0)`.
"""
razon_exacta(sr::Integer, sr0::Integer)::Rational{BigInt} =
    trabajo_por_ensayo(sr) // trabajo_por_ensayo(sr0)

# ---------------------------------------------------------------------------
# Régimen CORTO: ruina del jugador en la retícula.
# ---------------------------------------------------------------------------

"""
Probabilidad EXACTA (`Rational{BigInt}`) de que un paseo ±1 en la retícula, con paso `+1` de
probabilidad `p = 1−α` y `−1` de probabilidad `q = α`, alcance el EMPATE (`z = 0`) partiendo de
la posición `z ≥ 0`: `(q/p)^z`. Para `q ≥ p` vale `1`. `z = d·g` con `d` en u.t. y `g` bloques
por u.t. (ésta es la prescripción de D2/D3).
"""
function prob_empate_reticula(α::Rational{BigInt}, z::Integer)::Rational{BigInt}
    q = α
    p = 1 - α
    q >= p && return big(1) // big(1)
    return (q // p)^z
end

"""
Probabilidad EXACTA de SUPERAR ESTRICTAMENTE (`z ≤ −1`) partiendo de `z ≥ 0`: `(q/p)^(z+1)`.
El caso `z = 0` no es absorbente en el instante inicial (D3).
"""
function prob_superar_reticula(α::Rational{BigInt}, z::Integer)::Rational{BigInt}
    return prob_empate_reticula(α, z + 1)
end

"""
`α_mínimo` tal que `P(empate) = ε` con `d` u.t. de ventaja: `1/(1+ε^(−1/d))`.
Converge a `1/2` DESDE ABAJO (la sucesión crece hacia 1/2). El texto de CRP-v0.1 dice
«→ 1/2⁺» y «por arriba» (`INFORME.md:43`, `run-corto.txt:49`): es una etiqueta equivocada.
"""
α_min_empate(d::Real, ε::Real) = 1 / (1 + ε^(-1 / d))

"""
`α_mínimo` tal que `P(superar estrictamente) = ε`: `1/(1+ε^(−1/(d+1)))`.
"""
α_min_superar(d::Real, ε::Real) = 1 / (1 + ε^(-1 / (d + 1)))

# ---------------------------------------------------------------------------
# Compra de varianza (D5). Parámetros publicados por CRP-v0.1.
# ---------------------------------------------------------------------------

"""Parámetros de la tabla de compra de varianza publicada (`INFORME.md:93-98`)."""
struct ParametrosVarianza
    α::Float64
    T::Int
    factores::Vector{Int}
    sr0::BigInt
end

ParametrosVarianza(; α::Real = 0.45, T::Integer = 400, factores = (1, 4, 16, 64),
                   sr0::Integer = big(2)^50) =
    ParametrosVarianza(Float64(α), Int(T), collect(Int, factores), BigInt(sr0))

"""`sr` del adversario para el factor `K = sr0/sr`, con división entera (como CRP-v0.1)."""
sr_adversario(sr0::Integer, K::Integer) = max(big(1), BigInt(sr0) ÷ BigInt(K))

"""
Medias de los dos procesos de Poisson compuestos, con las MISMAS unidades que CRP-v0.1:
`μ_h = (1−α)·T` (la honesta usa `sr0`), `μ_a = α·T·sr_a/sr0` (el adversario usa `sr_a = sr0÷K`).
El trabajo total es `H·w(sr0)` y `A·w(sr_a)`.
"""
function medias_varianza(p::ParametrosVarianza, K::Integer)
    sra = sr_adversario(p.sr0, K)
    μh = (1 - p.α) * p.T
    μa = p.α * p.T * Float64(sra) / Float64(p.sr0)
    return (sra = sra, μh = μh, μa = μa,
            wh = peso_exacto(p.sr0), wa = peso_exacto(sra))
end

# ---------------------------------------------------------------------------
# Multistream (D7)
# ---------------------------------------------------------------------------

"""Cuota aditiva de CRP-v0.1: `S·α/(1−α+S·α)`. Es una DEFINICIÓN, no una derivación."""
cuota_multistream(α::Real, S::Real) = S * α / (1 - α + S * α)

"""`α` que iguala la cuota aditiva a `1/2`: `1/(S+1)`."""
α_min_multistream(S::Real) = 1 / (1 + S)

# ---------------------------------------------------------------------------
# Rojos asimétricos (D6)
# ---------------------------------------------------------------------------

"""
Frontera de deriva del modelo de juguete de `PROCEDENCIA.md` §3.2: si la honesta pierde una
fracción `f` de su trabajo por rojos y el adversario no pierde nada, el adversario gana si
`α > (1−f)/(2−f)`. Se devuelve exacta.
"""
α_rojos_asimetricos(f::Real) = (1 - f) / (2 - f)

"""Ejemplos publicados por `PROCEDENCIA.md:57-62` (fracción roja honesta, Δ de origen)."""
const TABLA_ROJOS = [(0.0000, 4.0), (0.0020, 8.0), (0.0828, 12.0), (0.2858, 16.0)]
