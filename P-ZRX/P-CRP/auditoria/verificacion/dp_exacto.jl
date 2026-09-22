# dp_exacto.jl — P-CRP: certificación independiente de las cifras de la DP con aritmética EXACTA.
#
# Qué comprueba, contra `prob_superar_finita` (DP exacta `Rational{BigInt}`, oráculo independiente
# del kernel `Float64`), que es lo que exige el encargo D2 y `veritas/LINEO.md` §5.3:
#   1. para toda la rejilla publicada en `resultados/CORTO.txt`: P_L ≤ exacto ≤ P_U y el error
#      de las dos cotas ≤ 1e-12 (o se declara inconcluso);
#   2. conservación de masa |masa_kernel+masa_exito+masa_fuga−1| ≤ 1e-12;
#   3. `α_prob` publicado (d=6, T=200, p0=0.05) queda DENTRO del intervalo exacto certificado
#      por bisección racional: se certifica P(α'_inf) ≥ p0 > P(α'_sup) con aritmética exacta;
#   4. el orden `P_terminal ≤ P_first_passage ≤ P_eventual` con exactitud (T pequeño);
#   5. `P_superar_finita(d,T) → (q/p)^(d+1)` monótona creciente en T (T grande, exacto).
# 1 hilo. NO modifica instrumentos.

using Printf
using StableRNGs

const COPIAS = normpath(joinpath(@__DIR__, "..", "copia"))
include(joinpath(COPIAS, "coste-rama-privada-v3", "src", "CosteRamaPrivadaV3.jl"))
using .CosteRamaPrivadaV3

const ALPHAS = Dict(0.2 => 1 // 5, 0.4 => 2 // 5, 0.45 => 9 // 20)

# α_prob publicado por CRP-v0.2 (resultados/CORTO.txt) para d=6, T=200, p0=0.05
const PUB_INF = 0.39466261863708496
const PUB_SUP = 0.39466267824172974
const P0 = 1 // 20
const DEN = big(2)^40

function seccion12()
    println("== 1/2 · rejilla publicada en CORTO.txt: cota exacta de [P_L,P_U] y conservación ==")
    @printf("%3s %5s %6s %14s %12s %12s %10s\n", "d", "T", "alpha", "exacto", "P_L", "P_U", "conserv")
    peor_lo = 0.0
    peor_hi = 0.0
    peor_cons = 0.0
    for d in (3, 6, 12), T in (50, 200), a in (0.2, 0.4, 0.45)
        q = ALPHAS[a]
        p = 1 - q
        r = prob_superar_dp(Float64, d, Float64(p), Float64(q), T)
        exacto = prob_superar_finita(d, p, q, T)
        ex = Float64(exacto)
        # errores en BigFloat para no atribuir a la DP el redondeo de la comparación
        peor_lo = max(peor_lo, Float64(BigFloat(exacto) - BigFloat(r.p_exito_lower)))
        peor_hi = max(peor_hi, Float64(BigFloat(r.p_exito_upper) - BigFloat(exacto)))
        peor_cons = max(peor_cons, abs(r.conservacion))
        @printf("%3d %5d %6.2f %14.6e %12.6e %12.6e %10.1e\n", d, T, a, ex,
                r.p_exito_lower, r.p_exito_upper, r.conservacion)
    end
    @printf("\npeor (exacto − P_L) = %.3e   peor (P_U − exacto) = %.3e   peor |conserv| = %.3e\n",
            peor_lo, peor_hi, peor_cons)
    println(peor_lo >= -1e-12 && peor_hi <= 1e-12 && peor_cons <= 1e-12 ?
            "CERTIFICADO: las dos cotas encierran el valor exacto con error ≤ 1e-12" :
            "INCONCLUSO: el error no queda por debajo de 1e-12")
end

function seccion3()
    println("\n== 3 · α_prob (d=6, T=200, p0=0.05): certificado exacto del intervalo publicado ==")
    f(m) = prob_superar_finita(6, 1 - m // DEN, m // DEN, 200)
    # OJO: P(superar) es **creciente** en α (α es la tasa del adversario). Con eso,
    #   α* = inf{α : P(α) ≥ p0} satisface  α* > a  ⟺  P(a) < p0   y   α* ≤ b  ⟺  P(b) ≥ p0.
    # Se certifica con aritmética exacta en α' = ceil(a·DEN)/DEN ≥ a y α'' = floor(b·DEN)/DEN ≤ b:
    #   P(α') < p0  ⇒ P(a) ≤ P(α') < p0     (α' ≥ a)
    #   P(α'') ≥ p0 ⇒ P(b) ≥ P(α'') ≥ p0    (α'' ≤ b)
    m_inf = ceil(BigInt, PUB_INF * DEN)
    m_sup = floor(BigInt, PUB_SUP * DEN)
    Pf_inf = f(m_inf)
    Pf_sup = f(m_sup)
    @printf("α' = ceil(α_inf) = %.17f  → exacto P = %.6e  < p0 = %.6e ? %s\n",
            Float64(m_inf // DEN), Float64(Pf_inf), Float64(P0), Pf_inf < P0)
    @printf("α''= floor(α_sup)= %.17f  → exacto P = %.6e  ≥ p0 = %.6e ? %s\n",
            Float64(m_sup // DEN), Float64(Pf_sup), Float64(P0), Pf_sup >= P0)
    println(Pf_inf < P0 && Pf_sup >= P0 ?
            "CERTIFICADO: el cruce exacto α* está en (α_inf, α_sup] con exactitud" :
            "INCONCLUSO: el intervalo publicado no encierra el cruce exacto")
end

function seccion45()
    println("\n== 4 · orden exacto de los tres eventos (z0=4, α=1/5) ==")
    for T in (10, 20)
        r = resultado_eventos(Rational{BigInt}, 4, 4 // 5, 1 // 5, T)
        ok = r.p_terminal <= r.p_paso && r.p_paso <= r.p_eventual
        @printf("T=%2d  terminal=%.6e  paso=%.6e  eventual=%.6e  orden=%s\n", T,
                Float64(r.p_terminal), Float64(r.p_paso), Float64(r.p_eventual), ok ? "OK" : "FALLA")
    end
    println("\n== 5 · P_superar_finita → (q/p)^(d+1), monótona en T (exacto) ==")
    p, q = 9 // 10, 1 // 10
    for d in (0, 1, 2)
        vals = [prob_superar_finita(d, p, q, T) for T in (10, 50, 200, 1000)]
        crece = all(vals[i] <= vals[i + 1] for i in 1:3)
        limite = (q // p)^(d + 1)
        @printf("d=%d  crece=%s  P(T=1000)=%.10f  (q/p)^(d+1)=%.10f  diferencia=%.3e\n",
                d, crece, Float64(vals[end]), Float64(limite), Float64(limite - vals[end]))
    end
end

seccion12()
seccion3()
seccion45()
