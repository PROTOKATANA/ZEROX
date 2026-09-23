# validacion.jl — oráculo independiente (Monte Carlo con Philox) y contrastes.
#
# El Monte Carlo NO compara una fórmula consigo misma: muestrea el juego de
# auditoría posición a posición y cuenta. Es un oráculo de naturaleza distinta.
#
# RNG: Philox contracontador con el id de réplica como CLAVE, nunca semilla
# consecutiva. Hallazgo de P-ZRX/P-PUERTA (verificado en su INFORME):
# `StableRNG(semilla + i)` con `i` consecutivo da autocorrelación lag-1 de −0,43
# entre réplicas; con Philox baja a −0,0006.

"""Generador de la réplica `i`. Contracontador Philox, no semilla consecutiva."""
rng_replica(semilla::UInt64, i::Integer) = Philox4x(UInt64, (semilla, UInt64(i)), 10)

"""Estado reutilizable de una réplica: `BitVector` de presencia + buffer de índices."""
struct Muestra
    visto::BitVector
    idx::Vector{Int}
end
Muestra(N::Integer, k::Integer) = Muestra(falses(Int(N)), Vector{Int}(undef, Int(k)))

"""
Una auditoría: `k` posiciones distintas uniformes de `1:N` (rechazo con `BitVector`,
exactamente uniforme sobre los subconjuntos de tamaño `k`), y detección si más de
`B` de ellas caen entre las `M` NO almacenadas. Las `M` primeras posiciones son las
omitidas: el adversario elige el conjunto antes del reto y el reto es uniforme, así
que un conjunto fijo de tamaño `M` reproduce la ley hipergeométrica.
"""
function una_auditoria!(m::Muestra, rng, N::Int, k::Int, M::Int, B::Int)
    fill!(m.visto, false)
    c = 0
    while c < k
        x = rand(rng, 1:N)
        if !m.visto[x]
            m.visto[x] = true
            c += 1
            @inbounds m.idx[c] = x
        end
    end
    aciertos = 0
    @inbounds for i in 1:k
        aciertos += (m.idx[i] <= M)
    end
    return aciertos > B
end

"""
Estimación Monte Carlo de `P(X > B)` con `replicas` réplicas independientes.
Devuelve `(p̂, exitos, replicas)`. Semilla obligatoria.
"""
function p_deteccion_mc(semilla::UInt64, N::Int, M::Int, k::Int, B::Int, replicas::Int)
    m = Muestra(N, k)
    exitos = 0
    for r in 1:replicas
        rng = rng_replica(semilla, r)
        exitos += una_auditoria!(m, rng, N, k, M, B) ? 1 : 0
    end
    return (exitos / replicas, exitos, replicas)
end

"""Comprueba que el Monte Carlo cae dentro del intervalo exacto de Clopper–Pearson."""
function mc_dentro_de_cp(exitos::Integer, replicas::Integer, p_exacto::Float64; alfa::Real = 0.05)
    lo, hi = clopper_pearson(exitos, replicas; alfa = alfa)
    return (lo <= p_exacto <= hi, lo, hi)
end

# ── Autocorrelación lag-1: el test que delata el esquema de semillas ─────────
"""
Autocorrelación lag-1 de las primeras salidas de `n` réplicas. Con Philox debe
quedar por debajo de 0,02 en valor absoluto. Si alguien vuelve a
`StableRNG(semilla + i)`, este número salta a ≈ −0,43 (hallazgo de P-PUERTA).
"""
function autocorrelacion_lag1(semilla::UInt64, n::Integer)
    a = Vector{Float64}(undef, n)
    for i in 1:n
        a[i] = rand(rng_replica(semilla, i))
    end
    media = sum(a) / n
    num = 0.0
    den = 0.0
    @inbounds for i in 1:(n - 1)
        num += (a[i] - media) * (a[i + 1] - media)
    end
    @inbounds for i in 1:n
        den += (a[i] - media)^2
    end
    return num / den
end

# ── Contrastes contra la referencia exacta ───────────────────────────────────
"""
Compara el kernel `Float64` con la referencia `Rational{BigInt}` sobre una rejilla
de instancias pequeñas. Devuelve `(max_error_abs, n_casos)`.
"""
function contraste_kernel_referencia(; Ns = (10, 17, 40, 64), ks = (1, 2, 5, 9), Bs = (0, 1, 3))
    peor = 0.0
    casos = 0
    for N in Ns, k in ks, B in Bs
        (k <= N) || continue
        t = TablaLogFact(N)
        for M in 0:N
            ex = cola_hiper_exacta(N, M, k, B)
            ra = cola_hiper_rapida(t, N, M, k, B)
            e = abs(Float64(ex) - ra)
            peor = max(peor, e)
            casos += 1
        end
    end
    return (peor, casos)
end
