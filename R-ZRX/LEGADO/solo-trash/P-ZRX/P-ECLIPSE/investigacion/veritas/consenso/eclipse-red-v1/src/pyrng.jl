#= pyrng.jl — réplica bit a bit de `random.Random` de CPython.

POR QUÉ EXISTE ESTE FICHERO, Y NO OTRO RNG
==========================================
El encargo P-ECLIPSE exige un **control positivo**: reproducir la fila publicada de D8 A3b
(`research/scripts/d8-ronda8/salida_a3b.txt`, `E = 200 s`, `f = 5 %`, α = 0 → 0,8218 / 0,6513 /
0,5920 / 0,5460) antes de medir nada nuevo, y dice literalmente: «Si tu puerto no la reproduce,
**el puerto está mal y se para ahí**».

La fila publicada es un promedio de Monte Carlo sobre 12 semillas del instrumento Python
heredado. Reproducirla a cuatro decimales NO se consigue con «otro RNG»: exige que el calendario
de eventos y el filtro aleatorio sean **los mismos números**. Por eso este fichero no implementa
«un MT19937»: implementa **el MT19937 de CPython y su sembrado**, que es lo que usaban
`r8c_sim.Mundo` (`random.Random(seed)` con `seed` entero) y `d8_a3_smax.MundoEclipse.corre_ecl`
(`random.Random(f"...")` con **cadena**).

Esto es un **puerto de la semántica del oráculo**, no una reimplementación de criptografía ni de
consenso; LINEO §5.3 pide precisamente aritmética exacta para que la vía rápida no pueda
falsificar una conclusión.

Alcance exacto, y sus dos límites declarados
--------------------------------------------
1. `seed_int!` reproduce `random_seed` de `_randommodule.c` para enteros: valor absoluto,
   palabras de 32 bits en orden **little-endian**, `keyused = max(1, (bits+31)/32)`, y
   `init_by_array` (que arranca en `init_genrand(19650218)`).
2. `seed_str!` reproduce `random.py::Random.seed(version=2)` para `str`:
   `a = int.from_bytes(a.encode() + sha512(a.encode()).digest(), 'big')`, y de ahí el camino
   entero. `sha512` viene de la stdlib `SHA`.
3. `random` reproduce `random_random` (`genrand >> 5`, `genrand >> 6`, res53).
4. `getrandbits`/`randbelow`/`randrange` reproducen `_randbelow_with_getrandbits`.
5. `expovariate` reproduce `-log(1.0 - random())/lambd`.

LÍMITE 1 (declarado): el sembrado por cadena depende de `repr(float)` de Python para construir la
cadena. `string(x)` de Julia y `repr(x)` de Python coinciden (ambos usan el formato más corto que
ida y vuelta) para los valores que este encargo usa —`900.0`, `0.0`, `0.05`, `0.1`, `0.25`,
`0.33`, `20.0`, `200.0`—, pero **no** coinciden en general (p. ej. `1e-05` frente a `1.0e-5`).
Por eso la interfaz admite la cadena **literal**: el llamante que necesite fidelidad exacta pasa
la cadena que Python habría producido, y `semilla_control` la construye explícitamente.

LÍMITE 2 (declarado): `expovariate` usa `log`. Si la `log` de Julia y la `log` de la libm de
CPython difiriesen en 1 ulp para alguna muestra, el instante de creación cambiaría en ~1e-16 s
relativos. Eso solo puede alterar el resultado si cae **exactamente** sobre una comparación
`ta <= t` o sobre un empate de orden; la probabilidad es del orden de 1 ulp relativo y no se ha
observado. Se declara en vez de silenciarse (LINEO §5.3: «si el margen no se puede certificar,
declara el resultado»).
=#

module PyRNG

using SHA

export PyRandom, genrand_uint32!, random, getrandbits, randbelow, randrange, expovariate,
       seed_int!, seed_str!, init_genrand!

const N = 624                    # grado de recurrencia
const M = 397                    # período medio
const MATRIX_A   = 0x9908b0df    # vector a
const UPPER_MASK = 0x80000000
const LOWER_MASK = 0x7fffffff
const INIT_GENRAND_SEED = 19650218   # semilla con la que arranca init_by_array (CPython)

"""
Estado del generador. `mt` está indexado 1..N y corresponde a `mt[0..N-1]` del código C:
`mt[i+1]` aquí es `mt[i]` allí.
"""
mutable struct PyRandom
    mt::Vector{UInt32}
    mti::Int
end

PyRandom() = PyRandom(zeros(UInt32, N), N + 1)

# ---------------------------------------------------------------------------------------
# Sembrado
# ---------------------------------------------------------------------------------------

"""`init_genrand(s)` del MT19937 de referencia. Se expone para poder comprobar los vectores
publicados de mt19937ar (semilla 5489), que validan twist y tempering."""
function init_genrand!(r::PyRandom, s::UInt32)
    mt = r.mt
    mt[1] = s
    @inbounds for i in 2:N
        mt[i] = 0x6c078965 * (mt[i - 1] ⊻ (mt[i - 1] >> 30)) + UInt32(i - 1)
    end
    r.mti = N
    return r
end

"""`init_by_array(key, key_length)` del MT19937 de referencia (el que usa CPython).
Se escribe con el índice `i` del C explícito para no torcer el algoritmo al traducirlo."""
function init_by_array!(r::PyRandom, key::Vector{UInt32})
    mt = r.mt
    keylen = length(key)
    init_genrand!(r, UInt32(INIT_GENRAND_SEED))
    i = 1                     # índice C de mt[i], 1 <= i <= N-1
    j = 0
    k = max(N, keylen)
    while k > 0
        prev = mt[i]                                   # mtC[i-1]
        cur  = mt[i + 1]                               # mtC[i]
        mt[i + 1] = (cur ⊻ ((prev ⊻ (prev >> 30)) * 0x0019660d)) + key[j + 1] + UInt32(j)
        i += 1; j += 1
        if i >= N
            mt[1] = mt[N]                              # mtC[0] = mtC[N-1]
            i = 1
        end
        if j >= keylen
            j = 0
        end
        k -= 1
    end
    for _ in 1:(N - 1)
        prev = mt[i]
        cur  = mt[i + 1]
        mt[i + 1] = (cur ⊻ ((prev ⊻ (prev >> 30)) * 0x5d588b65)) - UInt32(i)
        i += 1
        if i >= N
            mt[1] = mt[N]
            i = 1
        end
    end
    mt[1] = 0x80000000
    return r
end

"""`random_seed` de CPython para un entero: valor absoluto → palabras de 32 bits little-endian."""
function seed_int!(r::PyRandom, a::Integer)
    n = abs(BigInt(a))
    bits = n == 0 ? 0 : ndigits(n, base = 2)
    keyused = max(1, (bits + 31) ÷ 32)
    key = Vector{UInt32}(undef, keyused)
    @inbounds for i in 1:keyused
        key[i] = UInt32((n >> (32 * (i - 1))) & BigInt(0xffffffff))
    end
    return init_by_array!(r, key)
end

"""`Random.seed(str, version=2)`: `int.from_bytes(s.encode() + sha512(s.encode()).digest(), 'big')`."""
function seed_str!(r::PyRandom, s::AbstractString)
    b = Vector{UInt8}(codeunits(s))
    d = SHA.sha512(b)
    n = BigInt(0)
    @inbounds for byte in b
        n = (n << 8) | BigInt(byte)
    end
    @inbounds for byte in d
        n = (n << 8) | BigInt(byte)
    end
    return seed_int!(r, n)
end

PyRandom(seed::Integer) = seed_int!(PyRandom(), seed)
PyRandom(seed::AbstractString) = seed_str!(PyRandom(), seed)

# ---------------------------------------------------------------------------------------
# Extracción
# ---------------------------------------------------------------------------------------

"""`genrand_uint32`: twist cuando `mti >= N`, después tempering."""
function genrand_uint32!(r::PyRandom)::UInt32
    mt = r.mt
    if r.mti >= N
        @inbounds for kk in 0:(N - M - 1)
            y = (mt[kk + 1] & UPPER_MASK) | (mt[kk + 2] & LOWER_MASK)
            mt[kk + 1] = mt[kk + 1 + M] ⊻ (y >> 1) ⊻ (isodd(y) ? MATRIX_A : UInt32(0))
        end
        @inbounds for kk in (N - M):(N - 2)
            y = (mt[kk + 1] & UPPER_MASK) | (mt[kk + 2] & LOWER_MASK)
            mt[kk + 1] = mt[kk + 1 + (M - N)] ⊻ (y >> 1) ⊻ (isodd(y) ? MATRIX_A : UInt32(0))
        end
        y = (mt[N] & UPPER_MASK) | (mt[1] & LOWER_MASK)
        mt[N] = mt[M] ⊻ (y >> 1) ⊻ (isodd(y) ? MATRIX_A : UInt32(0))
        r.mti = 0
    end
    y = @inbounds mt[r.mti + 1]
    r.mti += 1
    y ⊻= (y >> 11)
    y ⊻= (y << 7) & 0x9d2c5680
    y ⊻= (y << 15) & 0xefc60000
    y ⊻= (y >> 18)
    return y
end

"""`random_random`: `(a·2^26 + b)/2^53` con `a` de 27 bits y `b` de 26. Exacto en `Float64`."""
function random(r::PyRandom)::Float64
    a = genrand_uint32!(r) >> 5          # 27 bits
    b = genrand_uint32!(r) >> 6          # 26 bits
    return ldexp(Float64(a) * 67108864.0 + Float64(b), -53)
end

"""`getrandbits(k)`: palabras little-endian; la última se recorta a `k mod 32` bits."""
function getrandbits(r::PyRandom, k::Integer)
    k <= 0 && return BigInt(0)
    if k <= 32
        return BigInt(genrand_uint32!(r) >> (32 - k))
    end
    words = (k - 1) ÷ 32 + 1
    acc = BigInt(0)
    restante = Int(k)
    for i in 0:(words - 1)
        w = genrand_uint32!(r)
        if restante < 32
            w >>= (32 - restante)
        end
        acc |= BigInt(w) << (32 * i)
        restante -= 32
    end
    return acc
end

"""`_randbelow_with_getrandbits(n)`: rechazo con `k = n.bit_length()` bits."""
function randbelow(r::PyRandom, n::Integer)
    n > 0 || throw(ArgumentError("n debe ser > 0"))
    k = ndigits(n, base = 2)
    while true
        x = getrandbits(r, k)
        x < n && return x
    end
end

"""`randrange(stop)` para `stop` que quepa en `Int`. `n < 2^31` en todo este encargo."""
randrange(r::PyRandom, n::Integer) = Int(randbelow(r, n))

"""`expovariate(lambd)`: `-log(1.0 - random())/lambd`."""
expovariate(r::PyRandom, lambd::Float64 = 1.0) = -log(1.0 - random(r)) / lambd

end # module
