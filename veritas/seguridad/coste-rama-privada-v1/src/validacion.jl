# CRP-v0.1 — validación: equivalencia referencia/kernel, invariantes y bordes.

"Error relativo máximo de la identidad (sr/sr0)·(w(sr)/w(sr0)) ≈ 1 en la rejilla."
function error_invariancia(sr0::Integer)
    tabla = cota_invariancia(sr0)
    return maximum(t.error_rel for t in tabla)
end

"Comprueba que E[trabajo/slot] es sr-independiente (referencia exacta) para un `s` dado."
function chequear_invariancia_trabajo(sr0::Integer; s::Rational{BigInt}=big(3)//big(10),
                                      srs=[sr0 >> 3, sr0 >> 1, sr0, sr0 << 1, sr0 << 3])
    filas = [(sr, trabajo_esperado_exacto(s, sr, sr0)) for sr in srs]
    mn = minimum(f[2] for f in filas)
    mx = maximum(f[2] for f in filas)
    return (filas=filas, razon_max_min=BigFloat(mx) / BigFloat(mn))
end

"Equivalencia estadística referencia lenta (exponencial) vs kernel rápido (Knuth)."
function equivalencia_poisson(n::Int=200_000)
    rng1 = StableRNG(0x1111)
    rng2 = StableRNG(0x2222)
    for mu in (0.01, 0.1, 0.5, 1.0, 2.0, 5.0)
        s1 = 0; s2 = 0
        for _ in 1:n
            s1 += poisson_exponencial(rng1, mu)
            s2 += poisson_knuth(rng2, mu)
        end
        m1 = s1 / n; m2 = s2 / n
        # tolerancia a 3σ de una media Poisson: 3·sqrt(μ/n)/μ
        tol = 3 * sqrt(mu / n) / mu
        abs(m1 - mu) / mu > tol && return (ok=false, mu=mu, m1=m1, m2=m2)
        abs(m1 - m2) / mu > tol && return (ok=false, mu=mu, m1=m1, m2=m2)
    end
    return (ok=true, mu=NaN, m1=NaN, m2=NaN)
end

"Compara la referencia lenta y el kernel rápido del proceso de trabajo (medias)."
function equivalencia_trabajo(p::Parametros; s=0.37, n_slots=200, n_rep=20_000,
                              sr=p.sr0)
    # dos RNG distintos, cada uno con su método; se comparan medias con tolerancia MC.
    rng = StableRNG(0x3333)
    med_fast = 0.0
    for r in 1:n_rep
        rr = StableRNG(0x3333 + UInt64(r))
        med_fast += simular_rama_rapido(rr, s, p; n_slots=n_slots, sr=sr).trabajo
    end
    med_fast /= n_rep
    med_ref = 0.0
    for r in 1:n_rep
        rr = StableRNG(0x9999 + UInt64(r))
        med_ref += simular_rama_referencia(rr, s, p; n_slots=n_slots, sr=sr).trabajo
    end
    med_ref /= n_rep
    objetivo = s * n_slots
    return (fast=med_fast, ref=med_ref, objetivo=objetivo,
            err_fast=abs(med_fast - objetivo) / objetivo,
            err_ref=abs(med_ref - objetivo) / objetivo)
end

"Contra la ruina exacta (g=1) la difusión y el DP deben quedar en el mismo orden."
function validar_curva_corta()
    filas = NamedTuple[]
    for d in (6, 12), α in (0.2, 0.3, 0.4)
        ex = ruina_exacta(Rational{BigInt}(round(Int, α * 1000), 1000), d)
        dif = prob_alcance_difusion(α, d; g=1.0)
        dp = prob_alcance_dp(α, 1.0, 400; d=d)
        push!(filas, (d=d, α=α, exacta=ex, difusion=dif, dp=dp))
    end
    return filas
end
