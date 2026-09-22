# semillas.jl — comprobación propia de P-CRP (no es un instrumento nuevo).
#
# OBJETO: comprobar la trampa §2.5 del encargo P-CRP —«semillas consecutivas de StableRNG
# sesgan el Monte Carlo (hallazgo de P-ZRX/P-PUERTA/)»— contra la derivación de semillas que
# usan CRP-v0.2 y CRP-v0.3.
#
# QUÉ MIDE, EN DOS PARTES INDEPENDIENTES:
#   A) la secuencia de números del RNG: autocorrelación lag-1 entre semillas consecutivas
#      (`StableRNG(base+i)`) frente a un esquema contracorriente (`Philox2x` + `set_counter!`,
#      que es el que prefiere `veritas/LINEO.md` §5.1/§7 para réplicas);
#   B) el efecto sobre un estadístico del simulador de v0.3: la varianza del recuento por bloque
#      de 24 réplicas frente a la varianza binomial que implicaría el IC publicado.
#
# NO se modifica ningún instrumento. Se usan sus funciones tal cual, desde `auditoria/copia/`.
# Presupuesto: 1 hilo, < 1 GiB de RAM, < 2 min.

using Printf
using StableRNGs
using Random123

const COPIAS = normpath(joinpath(@__DIR__, "..", "copia"))
include(joinpath(COPIAS, "coste-rama-privada-v3", "src", "CosteRamaPrivadaV3.jl"))
using .CosteRamaPrivadaV3

# --- RNG contracorriente: Philox2x(UInt64, clave) con contador = id de réplica ---------------
# El contador tiene DOS palabras: `rand` incrementa la primera. Para que cada réplica tenga un
# flujo DISJUNTO hay que fijar la primera a 0 y usar la segunda como id de réplica. Con
# `set_counter!(r, id)` (una sola palabra) las réplicas comparten casi todo el flujo: la primera
# salida de la réplica `id` es la salida `id` del mismo contador. Esto se comprobó aquí mismo y
# queda documentado como trampa de uso (ver `registros/diagnostico.txt`).
function rng_contracorriente(clave::UInt64, id::Integer)
    r = Philox2x(UInt64, clave)
    set_counter!(r, (0, UInt64(id)))
    return r
end

# --- Parte A: autocorrelación de la secuencia de uniforms -------------------------------------
function autocorr_lag1(x::Vector{Float64})
    n = length(x)
    m = sum(x) / n
    dx = x .- m
    num = sum(dx[1:(n - 1)] .* dx[2:n])
    den = sum(dx .^ 2)
    return num / den
end

function secuencia_stable(base::UInt64, n::Int, cual::Int)
    x = Vector{Float64}(undef, n)
    for i in 1:n
        r = StableRNG(base + UInt64(i))
        v = rand(r)
        cual == 1 || (v = rand(r))
        x[i] = v
    end
    return x
end

function secuencia_philox(base::UInt64, n::Int, cual::Int)
    x = Vector{Float64}(undef, n)
    for i in 1:n
        r = rng_contracorriente(base, i)
        v = rand(r)
        cual == 1 || (v = rand(r))
        x[i] = v
    end
    return x
end

function parte_A()
    n = 100_000
    bases = UInt64[0x5a5a, 0x0000_0000_0001_0000, 0xdead_beef]
    println("== Parte A · autocorrelación lag-1 de la secuencia de uniforms (n=$n por base) ==")
    @printf("%-28s %-6s %10s %10s\n", "esquema", "salida", "base1", "media 3 bases")
    for (nombre, f) in (("StableRNG(base+i)", secuencia_stable),
                        ("Philox2x+set_counter!", secuencia_philox))
        for cual in (1, 2)
            cs = [autocorr_lag1(f(b, n, cual)) for b in bases]
            @printf("%-28s %-6d %10.4f %10.4f\n", nombre, cual, cs[1], sum(cs) / length(cs))
        end
    end
    println("(referencia iid: autocorrelación ≈ 0 ± 3/√n ≈ ±0.0095)")
end

# --- Parte B: varianza por bloque de 24 réplicas en el simulador de v0.3 -----------------------
const ALPHA = 0.2
const S = 4
const T = 200
const D_BLOQUES = 0
const W_PESO = fld(big(2)^128, BigInt(1) + 1)

function cfg_celda()
    return ConfigSimV3(; n_honestos=4, alpha=ALPHA, delta=2, S=S, T=T, t_fork=1, k=30,
                       modo_correlacion=:derivada)
end

"""
Estadístico por réplica con tasa intermedia (≈0,54 en la celda publicada), que es donde la
dependencia entre réplicas se detecta con más potencia: ¿la **suma** de las ramas supera a la
punta pública? Con `d=0` es el evento aditivo terminal de `SWEEP-DAG.txt` (S=4, α=0.20 → 13/24).
"""
function exito_suma(rng)
    res = simular_v3!(cfg_celda(), rng)
    return sum(res.W_priv_terminal; init=big(0)) - res.W_pub > D_BLOQUES * W_PESO
end

exito_paso(rng) = exito_suma(rng)

function bloque_stable(base::UInt64, reps::Int)
    k = 0
    for r in 1:reps
        exito_paso(StableRNG(base + UInt64(r))) && (k += 1)
    end
    return k
end

function bloque_philox(base::UInt64, reps::Int)
    k = 0
    for r in 1:reps
        exito_paso(rng_contracorriente(base, r)) && (k += 1)
    end
    return k
end

function parte_B()
    reps = 24
    nbloques = 120
    println("\n== Parte B · recuentos por bloque de $reps réplicas, $nbloques bloques ==")
    println("celda: S=$S, α=$ALPHA, T=$T, Δ=2, k=30, modo=:derivada, d=$D_BLOQUES bloques (suma aditiva)")
    for (nombre, f) in (("StableRNG(base+r)", bloque_stable),
                        ("Philox2x contracorriente", bloque_philox))
        ks = [f(UInt64(1000 * b + 7), reps) for b in 1:nbloques]
        p = sum(ks) / (reps * nbloques)
        varb = reps * p * (1 - p)
        vobs = sum((k - reps * p)^2 for k in ks) / (nbloques - 1)
        @printf("%-26s p̂=%.4f  media=%.3f  Var_obs=%.3f  Var_binom=%.3f  ratio=%.2f\n",
                nombre, p, sum(ks) / nbloques, vobs, varb, varb == 0 ? Inf : vobs / varb)
    end
    # la celda publicada, con la semilla publicada 0x5a5a y sus 24 réplicas consecutivas
    k_pub = bloque_stable(UInt64(0x5a5a), reps)
    k_alt = bloque_philox(UInt64(0x5a5a), reps)
    @printf("celda publicada (base=0x5a5a): exitos=%d/%d con semillas consecutivas; %d/%d con contracorriente\n",
            k_pub, reps, k_alt, reps)
end

parte_A()
parte_B()
