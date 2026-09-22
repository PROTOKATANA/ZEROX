# Punto 1 del encargo: el modelo de peso, en enteros exactos.
#
# Todo este archivo trabaja en `BigInt` / `Rational{BigInt}`. `C-GD-01` (`SPEC.md:1669`) prohibe
# expresamente la coma flotante para el peso de un bloque, y la pregunta del punto 1 —si el `SR`
# se cancela— se decide en el ultimo bit, no en el septimo decimal.

const DOS64 = BigInt(2)^64
const DOS128 = BigInt(2)^128

"""
    SR_MAX

Mayor `solution_range` representable: `SR` es `u64` (`SPEC.md:1669`, `C-GD-01`).
"""
const SR_MAX = DOS64 - 1

"""
    NUM_CHUNKS

Chunks por registro en Autonomys, `2^15`. Fuente leida:
`PDF/autonomys-subspace/crates/subspace-core-primitives/src/pieces.rs:404`.
"""
const NUM_CHUNKS = BigInt(2)^15

"""
    NUM_S_BUCKETS

s-buckets por registro, `2^16`. Fuente leida: `.../src/pieces.rs:565`, con
`const_assert_eq!(Record::NUM_S_BUCKETS, 1 << u16::BITS)` en `.../src/sectors.rs:37`.
"""
const NUM_S_BUCKETS = BigInt(2)^16

"""
    valores_aceptados(SR) -> BigInt

Cuantos de los `2^64` valores posibles del entero `audit_chunk` satisfacen el predicado de
aceptacion de un billete, para un rango `SR`.

El predicado es `is_within_solution_range`
(`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:150-158`):

    solution_distance <= solution_range / 2        # division entera de u64

con `solution_distance = bidirectional_distance(audit_chunk_u64, global_challenge_u64)`
(`PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs:332-337`), que es el
minimo de las dos diferencias con `wrapping_sub`: una **distancia sobre un circulo** de `2^64`
puntos.

Aceptan los valores a distancia `0, 1, ..., SR÷2` del reto. A distancia `0` hay un valor; a cada
distancia `j ≥ 1` hay dos (uno a cada lado). Luego

    |aceptados| = 2·(SR÷2) + 1

que vale **`SR+1` si `SR` es par** y **`SR` si `SR` es impar**. Esa paridad es exactamente lo que
decide si la cancelacion del punto 1 del encargo es exacta o deja un residuo, porque el peso de
`C-GD-01` divide por `SR+1` y no por `|aceptados|`.

El caso `SR÷2 = 2^63` no se alcanza: `SR ≤ 2^64−1` da `SR÷2 ≤ 2^63−1`, asi que nunca hay
solapamiento de los dos lados del circulo y la formula es exacta en todo el dominio.
"""
valores_aceptados(SR::Integer) = 2 * (BigInt(SR) ÷ 2) + 1

"""
    peso_bloque(SR) -> BigInt

`C-GD-01` (`SPEC.md:1669`): `w(B) = ⌊2^128 / (SR+1)⌋`, division entera exacta.
"""
peso_bloque(SR::Integer) = DOS128 ÷ (BigInt(SR) + 1)

"""
    resto_suelo(SR) -> BigInt

Lo que el suelo de `C-GD-01` tira: `2^128 mod (SR+1)`. Es el unico error que introduce `⌊·⌋`,
y esta acotado por `SR`, luego su efecto relativo sobre el peso es `< (SR+1)/2^128 ≤ 2^{-64}`.
"""
resto_suelo(SR::Integer) = DOS128 % (BigInt(SR) + 1)

"""
    prob_billete(SR) -> Rational{BigInt}

Probabilidad exacta de que un ensayo —un par (sector auditado, pieza)— produzca billete:
`|aceptados| / 2^64`.
"""
prob_billete(SR::Integer) = valores_aceptados(SR) // DOS64

"""
    tasa_peso(P, SR) -> Rational{BigInt}

Peso esperado por slot que acumula un flujo con `P` ensayos por slot y rango `SR`:

    tasa = P · prob_billete(SR) · peso_bloque(SR)

Es el producto `bloques/slot × peso/bloque` del encargo, calculado sin ninguna aproximacion.
"""
tasa_peso(P::Integer, SR::Integer) = BigInt(P) * prob_billete(SR) * peso_bloque(SR)

"""
    razon_cancelacion(SR) -> Rational{BigInt}

`tasa_peso(P,SR) / (P · 2^64)`. Vale exactamente `1` si y solo si el `SR` se cancela del todo.
No depende de `P`.

Resultado (lo demuestra `test/runtests.jl`, no este docstring):
- `SR` **par**: `= (SR+1)·⌊2^128/(SR+1)⌋ / 2^128 = 1 − resto_suelo(SR)/2^128`, desviacion
  negativa de modulo `< 2^{-64}`.
- `SR` **impar**: `= SR·⌊2^128/(SR+1)⌋ / 2^128 ≈ SR/(SR+1)`, desviacion negativa de modulo
  `≈ 1/(SR+1)`.
"""
razon_cancelacion(SR::Integer) = tasa_peso(1, SR) // DOS64

"""
    desviacion_cancelacion(SR) -> Rational{BigInt}

`razon_cancelacion(SR) − 1`: el residuo exacto que el `SR` deja en la tasa de peso.
"""
desviacion_cancelacion(SR::Integer) = razon_cancelacion(SR) - 1

"""
    rango_de_piezas(piezas, prob_slot=(1,6)) -> BigInt

Port exacto de `pieces_to_solution_range`
(`PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs:30-40`), con el mismo
orden de operaciones y las mismas divisiones enteras truncadas:

    SR = (u64::MAX / prob.den * prob.num / NUM_CHUNKS * NUM_S_BUCKETS) / piezas

Sirve para poblar el barrido con valores de `SR` que una red real usaria, en vez de con numeros
inventados.
"""
function rango_de_piezas(piezas::Integer, prob_slot::Tuple{Integer,Integer}=(1, 6))
    sr = SR_MAX ÷ BigInt(prob_slot[2]) * BigInt(prob_slot[1])
    sr = sr ÷ NUM_CHUNKS * NUM_S_BUCKETS
    return sr ÷ BigInt(piezas)
end

"""
    cuenta_alcanzable(objetivo) -> BigInt

El numero de valores aceptados mas cercano a `objetivo` que un `SR` entero puede producir.

`valores_aceptados` vale `2m+1`, luego **la cuenta alcanzable es siempre impar**: un retarget no
puede fijar una tasa de bloques arbitraria, solo una de la reticula impar. Devuelve ese impar.
"""
function cuenta_alcanzable(objetivo::Rational)
    m = round(BigInt, (objetivo - 1) // 2, RoundNearest)
    m = max(m, BigInt(0))
    return 2 * m + 1
end

"""
    rango_retarget(P, ν; paridad=:par) -> BigInt

El `SR` que un retarget ideal elige para que `P` ensayos por slot produzcan `ν` billetes por slot.

Resuelve `P · |aceptados(SR)| / 2^64 = ν` sobre la reticula alcanzable y devuelve **uno de los
dos** `SR` que dan esa misma cuenta: el par (`cuenta−1`) o el impar (`cuenta`). Los dos producen
**la misma tasa de bloques** y **pesos distintos** —ese es el hallazgo del punto 1—, asi que la
paridad es un argumento, no un detalle.
"""
function rango_retarget(P::Integer, ν::Rational; paridad::Symbol=:par)
    cuenta = cuenta_alcanzable(Rational{BigInt}(numerator(ν), denominator(ν)) * DOS64 // BigInt(P))
    sr = paridad === :par ? cuenta - 1 : cuenta
    paridad in (:par, :impar) || throw(ArgumentError("paridad debe ser :par o :impar"))
    return clamp(sr, BigInt(1), SR_MAX)
end

"""
    sesgo_tasa(P1, P2, SR1, SR2) -> Rational{BigInt}

Lo que el encargo llama «demuestra o refuta que la tasa de peso del flujo `i` es `∝ W_i`»:

    sesgo = [tasa_peso(P1,SR1) / tasa_peso(P2,SR2)] / (P1/P2) − 1

Vale `0` exactamente si y solo si la razon de tasas de peso reproduce la razon de espacios. Todo
en `Rational{BigInt}`.
"""
function sesgo_tasa(P1::Integer, P2::Integer, SR1::Integer, SR2::Integer)
    return (tasa_peso(P1, SR1) // tasa_peso(P2, SR2)) // (BigInt(P1) // BigInt(P2)) - 1
end
