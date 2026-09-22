#= retencion-clave-v1 · test/runtests.jl
   Controles de corrección. Cada bloque compara DOS VÍAS INDEPENDIENTES; ninguno compara una
   fórmula consigo misma (LINEO §8.3, PROMPT §4).

   Vías:
     V1  fórmula cerrada de los momentos exactos (ρIθ/2, ρ²I²θ/3, e^{−θ}) + integración numérica
     V2  oráculo por espacios exponenciales (exacto, muestreado)
     V3  enumeración multinomial explícita (discretización de K bins)
     V4  kernel rápido por conteos de bins
     V5  aritmética racional exacta del reparto multinomial

   Uso:  JULIA_NUM_THREADS=1 veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl
=#

using Test
using StableRNGs: StableRNG

include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
include(joinpath(@__DIR__, "..", "src", "referencia.jl"))
include(joinpath(@__DIR__, "..", "src", "rapido.jl"))

using .Modelo
using .Referencia
using .Rapido

const SEMILLA = UInt64(0x434C415645)   # "CLAVE"

"""CDF empírica de la vía exponencial (exacta) en `x`."""
function cdf_espaciado(th::Float64, coef::Float64, x::Real, n::Int, semilla::UInt64;
                       modo::Vesting = LINEAL)
    rng = StableRNG(semilla)
    k = 0
    for _ in 1:n
        b, _ = muestra_espaciado!(rng, th, coef; modo = modo)
        b <= x && (k += 1)
    end
    return k / n
end

@testset "retencion-clave-v1" begin

# ---------------------------------------------------------------- V1 · identidades

@testset "momentos exactos y frontera de deriva" begin
    for (rho, Tv, lam, f, I) in ((0.5, 100.0, 1.0, 0.01, 1.0),
                                 (0.25, 7.0, 2.0, 0.003, 3.0),
                                 (1.0, 50.0, 1.0, 0.2, 2.0))
        ret = Retencion(rho, Tv)
        θ = lam * f * Tv
        # Var = ρ²I² · ∫_0^{Tv} (1−a/Tv)² λf da  (integración numérica independiente)
        K = 20_000
        integ = 0.0
        h = Tv / K
        for i in 1:K
            a = (i - 0.5) * h
            integ += (1 - a / Tv)^2 * lam * f * h
        end
        @test isapprox(balance_var(lam, f, ret, I), rho^2 * I^2 * integ; rtol = 1e-6)
        @test isapprox(balance_medio(lam, f, ret, I), rho * I * θ / 2; rtol = 1e-12)
        @test isapprox(p_saldo_cero(lam, f, ret), exp(-θ); rtol = 1e-14)
    end
    # Frontera de deriva: g(α*) = 0 exacto y signo estricto a los dos lados.
    for (bd, bx) in ((0.0, 0.0), (0.2, 0.0), (0.0, 0.1), (0.25, 0.25), (0.5, 0.3))
        for (etah, etaa) in ((1.0, 1.0), (0.9, 1.1), (1.3, 0.7))
            αs = alpha_estrella(bd, bx, etah, etaa)
            @test isapprox(deriva(αs, bd, bx, etah, etaa), 0.0; atol = 1e-14)
            @test deriva(αs - 1e-9, bd, bx, etah, etaa) < 0
            @test deriva(αs + 1e-9, bd, bx, etah, etaa) > 0
        end
    end
    # β_x baja α* el doble que β_d (P-PRESTAMO §1) con η = 1.
    @test isapprox(0.5 - alpha_estrella(0.0, 0.1, 1.0, 1.0), 0.1; atol = 1e-12)
    @test isapprox(0.5 - alpha_estrella(0.1, 0.0, 1.0, 1.0), 0.05; atol = 1e-12)
    # El umbral literal del PROMPT §2.2 y el cruce de deriva coinciden SÓLO con η = 1.
    @test isapprox(beta_cruce(0.33, 1.0, 1.0), beta_umbral_deriva(0.33); atol = 1e-12)
    @test !isapprox(beta_cruce(0.33, 0.9, 1.1), beta_umbral_deriva(0.33); atol = 1e-6)
    # p_de_alpha ∈ [0,1] y monótona
    for a in 0.0:0.1:0.9
        p = p_de_alpha(a, 0.1, 0.0, 1.0, 1.0)
        @test 0 <= p <= 1
    end
end

# ----------------------------------------------- V2/V3/V4 · equivalencia de las vías

@testset "enumeración multinomial contra la fórmula cerrada" begin
    ret = Retencion(0.5, 100.0)
    for (K, θ) in ((4, 0.2), (4, 1.0), (8, 0.5), (8, 2.0))
        f = θ / 100.0
        d = dist_enumerada(1.0, f, ret, 1.0; K = K, N_max = 26)
        trunc = 1 - sum(poisson_pmf(θ, n) for n in 0:26)
        @test isapprox(sum(d.masas), 1.0; atol = max(1e-8, 10 * trunc))
        @test isapprox(d.masas[1], exp(-θ); atol = max(1e-8, 10 * trunc))
        @test isapprox(media_dist(d), media_teorica(1.0, f, ret, 1.0); rtol = 5e-3)
        @test isapprox(varianza_dist(d), varianza_teorica(1.0, f, ret, 1.0); rtol = 5e-2)
    end
end

# ------------------------------- DP exacta de la CDF frente a la enumeración bruta

@testset "DP de la CDF por m: exacta frente a enumeración bruta" begin
    ret = Retencion(0.5, 100.0)
    # (a) contra enumeración de composiciones con peso multinomial exacto
    for (K, m) in ((2, 3), (4, 2), (4, 3), (8, 2), (8, 3), (2, 4), (3, 4))
        w, paso = pesos_enteros(K, LINEAL, ret.rho, 1.0)
        for x in (0.02, 0.1, 0.5, 1.0)
            a = cdf_m_bins(m, K, w, x, paso)
            b = 0.0
            for comp in pmf_composiciones(m, K)
                idx = sum(w[j] * comp[j] for j in 1:K)
                idx * paso <= x + 1e-12 && (b += peso_composicion(comp, m, K))
            end
            @test isapprox(a, b; atol = 1e-10)
        end
    end
    # (b) la masa total de la DP debe ser 1 para cualquier K, m, x ≥ máximo alcanzable
    for (K, m) in ((5, 4), (16, 6), (32, 8))
        w, paso = pesos_enteros(K, LINEAL, ret.rho, 1.0)
        xmax = paso * m * sum(w)
        @test isapprox(cdf_m_bins(m, K, w, xmax, paso), 1.0; atol = 1e-10)
        @test cdf_m_bins(m, K, w, 0.0, paso) == 0.0
    end
end

@testset "CDF exacta por mezcla frente al oráculo exponencial" begin
    ret = Retencion(0.5, 100.0)
    n = 300_000
    for θ in (0.05, 0.5, 2.0, 10.0)
        f = θ / 100.0
        for x in (0.0, 0.02, 0.1, 0.5, 1.0)
            ex, corte, completa = cdf_exacta(1.0, f, ret, 1.0, x; K = 32)
            @test completa
            pe = cdf_espaciado(θ, ret.rho, x, n, SEMILLA + UInt64(round(Int, 1000θ + 10x)))
            ee = sqrt(max(pe * (1 - pe), 1e-12) / n)
            es = sqrt(max(ex * (1 - ex), 1e-12) / n)
            # MC (error ee) frente a exacta (error de MC del oráculo, es): tolerancia combinada.
            # Se añade 1e-6 absoluto por el sesgo de la truncación de M_corte en el oráculo MC.
            @test abs(ex - pe) <= 6 * sqrt(ee^2 + es^2) + 2e-3
        end
    end
    # P(B=0) es exactamente e^{−θ} en TODAS las vías
    for θ in (0.05, 0.5, 2.0, 10.0)
        f = θ / 100.0
        ex, _, _ = cdf_exacta(1.0, f, ret, 1.0, 0.0; K = 32)
        @test isapprox(ex, exp(-θ); rtol = 1e-12)
    end
end

@testset "CDF: kernel de K bins frente a oráculo exponencial" begin
    ret = Retencion(0.5, 100.0)
    n = 150_000
    for θ in (0.05, 1.0, 5.0)
        f = θ / 100.0
        for x in (0.0, 0.05, 0.25, 1.0)
            pe = cdf_espaciado(θ, ret.rho, x, n, SEMILLA + UInt64(round(Int, 1000 * θ + 10 * x)))
            v = saldo_mc(SEMILLA, n, 1.0, f, ret, 1.0; K = 64, hilos = false)
            pk = count(<=(x), v) / n
            ee = sqrt(max(pe * (1 - pe), 1e-12) / n)
            ek = sqrt(max(pk * (1 - pk), 1e-12) / n)
            @test abs(pk - pe) <= 5 * sqrt(ee^2 + ek^2) + 1e-9
        end
    end
end

@testset "error de discretización del kernel medido y decreciente" begin
    ret = Retencion(0.5, 100.0)
    # el kernel con K bins es una discretización: su error frente al oráculo exacto debe caer
    # al crecer K. Se comprueba con la CDF EXACTA, no con otra muestra MC.
    θ = 1.0
    f = θ / 100.0
    for x in (0.1, 0.5)
        ex, _, _ = cdf_exacta(1.0, f, ret, 1.0, x; K = 64)
        e8 = abs(count(<=(x), saldo_mc(SEMILLA, 150_000, 1.0, f, ret, 1.0; K = 8, hilos = false)) / 150_000 - ex)
        e128 = abs(count(<=(x), saldo_mc(SEMILLA, 150_000, 1.0, f, ret, 1.0; K = 128, hilos = false)) / 150_000 - ex)
        @test e128 <= e8 + 0.01
    end
end

@testset "P(B=0) exacta frente a las dos vías muestreadas" begin
    ret = Retencion(0.5, 100.0)
    n = 250_000
    for θ in (0.05, 1.0, 5.0)
        f = θ / 100.0
        p0 = exp(-θ)
        rng = StableRNG(SEMILLA ⊻ 0x11)
        k = 0
        for _ in 1:n
            b, _ = muestra_espaciado!(rng, θ, ret.rho)
            b == 0.0 && (k += 1)
        end
        lo, _, hi = ic_wilson(k, n)
        @test lo <= p0 <= hi
        v = saldo_mc(SEMILLA ⊻ 0x22, n, 1.0, f, ret, 1.0; K = 64, hilos = true)
        k2 = count(==(0.0), v)
        lo2, _, hi2 = ic_wilson(k2, n)
        @test lo2 <= p0 <= hi2
    end
end

@testset "la normal falla donde importa (θ pequeño)" begin
    ret = Retencion(0.5, 100.0)
    # P(B=0) = e^{−θ} es un átomo en el BORDE del soporte: la normal no la puede aproximar, y su
    # error es mayor cuanto más pequeño es θ. Éste es el hallazgo central del encargo.
    for θ in (0.001, 0.01, 0.1, 1.0, 10.0)
        f = θ / 100.0
        exacta = exp(-θ)
        aprox = masa_cero_aprox(1.0, f, ret, 1.0)
        @test 0 <= aprox <= 1
        if θ < 0.1
            # la exacta está pegada a 1 y la normal está cerca de 0,5: error relativo enorme
            @test exacta > 0.9
            @test abs(aprox - exacta) > 0.3
        end
        if θ >= 10.0
            # con θ grande la normal SIGUE sobreestimando, pero mucho menos en términos relativos
            @test aprox > exacta
        end
        @test isapprox(rsd_pequeno(1.0, f, ret), sqrt(4 / (3θ)); rtol = 1e-12)
    end
end

# -------------------------------------------------------- V5 · aritmética racional

@testset "reparto multinomial exacto en Rational{BigInt}" begin
    for (K, Nmax, θ) in ((2, 6, 1.0), (3, 5, 0.7))
        idxs, ps, paso = dist_exacta_racional(big(1)//big(2), big(1)//big(1), θ, K, Nmax)
        @test sum(ps) > 0
        @test isa(paso, Rational{BigInt})
        for p in ps
            @test p > 0
        end
        w = [2K - 2j + 1 for j in 1:K]
        acc = Dict{Int,Float64}()
        for N in 0:Nmax
            pN = poisson_pmf(θ, N)
            for comp in pmf_composiciones(N, K)
                idx = sum(w[j] * comp[j] for j in 1:K)
                acc[idx] = get(acc, idx, 0.0) + pN * peso_composicion(comp, N, K)
            end
        end
        for (i, p) in zip(idxs, ps)
            @test isapprox(Float64(p), acc[i]; rtol = 1e-6, atol = 1e-30)
        end
    end
end

# ------------------------------------------------------- kernel: invariantes y RNG

@testset "serial == hilos (sin carreras, reducción determinista)" begin
    ret = Retencion(0.5, 100.0)
    a = saldo_mc(SEMILLA, 20_000, 1.0, 0.01, ret, 1.0; K = 32, hilos = false)
    b = saldo_mc(SEMILLA, 20_000, 1.0, 0.01, ret, 1.0; K = 32, hilos = true)
    @test a == b
end

@testset "semillas por réplica no consecutivas" begin
    xs = [hash64(UInt64(1), UInt64(i)) for i in 1:64]
    @test length(unique(xs)) == 64
    ys = [UInt64(1) + UInt64(i) for i in 1:64]
    @test xs != ys
    @test hash64(UInt64(0), UInt64(0)) != hash64(UInt64(0), UInt64(1))
    @test issorted(xs) == false
end

@testset "bordes: ρ=0 y T_v=0 dan saldo cero" begin
    for ret in (Retencion(0.0, 100.0), Retencion(0.5, 0.0), Retencion(0.0, 0.0))
        d = dist_enumerada(1.0, 0.01, ret, 1.0; K = 4, N_max = 26)
        @test length(d.masas) == 1                # delta en 0: B ≡ 0
        @test isapprox(sum(d.masas), 1.0; atol = 1e-10)
        @test d.masas[1] ≈ 1.0 atol = 1e-10
        @test cdf_exacta(1.0, 0.01, ret, 1.0, 0.0; K = 4)[1] == 1.0
        @test balance_medio(1.0, 0.01, ret, 1.0) == 0.0
        @test balance_var(1.0, 0.01, ret, 1.0) == 0.0
    end
    a = balance_medio(1.0, 0.01, Retencion(0.5, 100.0), 1.0)
    b = balance_medio(1.0, 0.01, Retencion(0.5, 200.0), 1.0)
    @test isapprox(b / a, 2.0; rtol = 1e-12)
    # el kernel con ρ=0 devuelve exactamente 0 para todas las réplicas
    v = saldo_mc(SEMILLA, 5_000, 1.0, 0.01, Retencion(0.0, 100.0), 1.0; K = 32, hilos = false)
    @test all(iszero, v)
end

# ------------------------------------------------- reclutamiento: greedy = óptimo

@testset "reclutamiento: cobertura por mochila — greedy como cota, DP como óptimo" begin
    # El problema «mínimo coste con Σf ≥ β» es NP-duro (cobertura por mochila) y el greedy por
    # ratio NO es óptimo. Se comprueba: (a) el greedy nunca es MENOR que el óptimo por fuerza
    # bruta; (b) el DP exacto coincide con la fuerza bruta.
    rng = StableRNG(SEMILLA ⊻ 0x33)
    fallos_greedy = 0
    for prueba in 1:200
        n = rand(rng, 6:10)
        fs = rand(rng, n) .* 0.1 .+ 0.001
        fs ./= sum(fs)
        bribes = rand(rng, n) .* 2.0
        β = rand(rng) * 0.5
        g = reclutamiento_eligiendo(fs, bribes, β)
        d = reclutamiento_exacto(fs, bribes, β; pasos = 20_000)
        mejor = Inf
        for máscara in 0:(2^n - 1)
            espacio = 0.0
            coste = 0.0
            for i in 1:n
                (máscara >> (i - 1)) & 1 == 1 || continue
                espacio += fs[i]
                coste += bribes[i]
            end
            espacio >= β - 1e-9 && (mejor = min(mejor, coste))
        end
        @test g.suficiente && d.suficiente
        @test g.coste >= d.coste - 1e-9                       # el greedy es cota superior
        @test isapprox(d.coste, mejor; rtol = 1e-3, atol = 1e-9)  # el DP es el óptimo
        g.coste > d.coste + 1e-9 && (fallos_greedy += 1)
    end
    # el greedy SÍ falla en algunas instancias: el problema no admite greedy exacto
    @test fallos_greedy >= 1
end

@testset "reclutamiento: el greedy es exacto cuando el ratio es constante" begin
    # Si soborno_i = coef·f_i con coef constante, TODAS las ratios valen coef y cualquier
    # subconjunto que junte β cuesta coef·β: el greedy acierta. Es el caso del modelo base.
    rng = StableRNG(SEMILLA ⊻ 0x66)
    for prueba in 1:20
        n = 300
        fs = rand(rng, n) .+ 0.01
        fs ./= sum(fs)
        coef = 0.37
        bribes = coef .* fs
        β = 0.25
        g = reclutamiento_eligiendo(fs, bribes, β)
        d = reclutamiento_exacto(fs, bribes, β; pasos = 20_000)
        @test isapprox(g.coste, coef * g.espacio; rtol = 1e-12)
        # El espacio se pasa como mucho en la clave mayor, pero la rejilla del DP redondea cada
        # clave HACIA ARRIBA: el DP puede quedar hasta una celda por debajo de `β`. El intervalo
        # [coef·(β−paso), coef·(β+max f)] acota los dos métodos.
        paso_dp = β / 20_000
        @test coef * β <= g.coste <= coef * (β + maximum(fs)) + 1e-12
        @test coef * (β - paso_dp - maximum(fs)) - 1e-12 <= d.coste <= coef * (β + maximum(fs)) + 1e-12
    end
end

@testset "reclutamiento: elegir nunca es peor que el azar" begin
    rng = StableRNG(SEMILLA ⊻ 0x44)
    for prueba in 1:40
        n = 200
        fs = rand(rng, n) .+ 0.01
        fs = fs ./ sum(fs)
        θs = 5.0 .* fs
        bribes = [θ < 0.5 ? 0.0 : 0.5 * θ for θ in θs]
        β = 0.2
        re = reclutamiento_eligiendo(fs, bribes, β)
        ra = reclutamiento_azar(fs, bribes, β)
        @test re.suficiente && ra.suficiente
        @test re.coste <= ra.coste + 1e-12
    end
end

@testset "masa de espacio bajo umbral: E[min(f,x)]/E[f] == CDF truncada" begin
    ret = Retencion(0.5, 100.0)
    for α in (2.2, 2.6, 3.0)
        for Fmax in (Inf, 1e-2)
            dist = Pareto(1e-8, α)
            for b in (0.01, 0.1, 1.0)
                ana = masa_espacio_bajo_b(dist, b, ret, 1.0; F_max = Fmax)
                num = espacio_bajo_umbral_b(dist, b, ret, 1.0; F_max = Fmax)
                @test isapprox(ana, num; rtol = 1e-12)   # dos fórmulas equivalentes
                @test 0 <= ana <= 1 + 1e-12
            end
        end
    end
    # comprobación por CUADRATURA de una versión regularizada: con f_min = 1 y F_max = 1e6 el
    # cociente es 10^6 y una rejilla logarítmica sí es fiable (control del analítico)
    dist = Pareto(1.0, 2.5)
    x = 1e3
    βe = 2 - dist.alpha
    uF = (1e6)^βe
    ux = x^βe
    # F(x) = (1 − x^{2−α})/(1 − F_max^{2−α}) por la CDF truncada estándar
    Fx = (ux - 1) / (uF - 1)
    @test isapprox(Fx, masa_prob(dist, x; F_max = 1e6); rtol = 1e-12)
    @test isapprox(masa_espacio_bajo_b(dist, 100.0, ret, 1.0; F_max = 1e6),
                   masa_prob(dist, 100.0 / (ret.rho * ret.Tv / 2); F_max = 1e6); rtol = 1e-12)
    # α ≤ 2 sin truncar debe fallar de forma explícita, no devolver un número silencioso
    @test_throws ArgumentError masa_prob(Pareto(1e-8, 1.6), 1e-4)
    # con truncación, α ≤ 2 sí está definido y M(x) crece con x
    @test masa_prob(Pareto(1e-8, 1.6), 1e-5; F_max = 1e-2) <
          masa_prob(Pareto(1e-8, 1.6), 1e-4; F_max = 1e-2)
    # α MAYOR ⇒ cola más pesada hacia los pequeños (el factor (f_min/x)^{α−2} decrece con α)
    # ⇒ MÁS masa bajo el umbral. Se comprueba la monotonía en α en los dos sentidos.
    for (α1, α2) in ((2.2, 2.6), (2.6, 3.0))
        @test masa_espacio_bajo_b(Pareto(1e-8, α2), 0.1, ret, 1.0) >
              masa_espacio_bajo_b(Pareto(1e-8, α1), 0.1, ret, 1.0)
    end
end

@testset "coste de reclutamiento: fórmula cerrada contra greedy" begin
    rng = StableRNG(SEMILLA ⊻ 0x55)
    n = 500
    fs = rand(rng, n) .+ 0.01
    fs = fs ./ sum(fs)
    coef = 0.37
    bribes = coef .* fs
    r = reclutamiento_eligiendo(fs, bribes, 0.25)
    @test isapprox(r.coste, coef * r.espacio; rtol = 1e-12)
    @test r.espacio >= 0.25
    r2 = reclutamiento_eligiendo(fs, bribes, 0.25; overhead = 0.01)
    @test r2.coste > r.coste
end

end # testset
