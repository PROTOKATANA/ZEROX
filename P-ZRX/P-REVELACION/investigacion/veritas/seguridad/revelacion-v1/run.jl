#!/usr/bin/env julia
# ─────────────────────────────────────────────────────────────────────────────
# run.jl — CLI reproducible de REV-v1.0 (`P-ZRX/P-REVELACION`)
#
#   julia --project=. run.jl --modo <controles|adl|f1|f2|f3|f4|f5|todo> [--hilos N]
#
# Ningún parámetro de consenso está fijado: todos entran por la rejilla declarada en cada modo.
# Las cifras publicadas salen de aquí; `resultados/` guarda las salidas.
# ─────────────────────────────────────────────────────────────────────────────

using RevelacionV1
using Printf
using StableRNGs
using Dates

const RV = RevelacionV1

# modelo.jl de ADL-v1.0, **incluido como dependencia de lectura** para la comparación fila a fila
const RAIZ = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
const ADL_MODELO = joinpath(RAIZ, "P-ADELANTO", "investigacion", "veritas", "seguridad",
                            "adelanto-v1", "src", "modelo.jl")
module AdlRef end
if isfile(ADL_MODELO)
    Base.include(AdlRef, ADL_MODELO)
end

const HILOS = Ref(1)
const SEMILLA = Ref(UInt64(0x5a5a))

hdr(t) = (println(); println("="^100); println(t); println("="^100))

# ── utilidades de barrido ────────────────────────────────────────────────────

"Corre un barrido con la rejilla de ρ dada y devuelve el resultado."
function correr(; L, I, W_dec, D = 0.0, S_max = 150.0, Lrev = L, con_h = false, espera = false,
                cruce = true, lead_h = D, j_ini = 0, rhos, n_rep = 64, J = 1200,
                alpha = 0.33, modo_off = :geom, lambda = 0.2, bin = 16.0, nb = 4096,
                v_lo = -1024.0, boot_ref = 0.9 * L, seed = SEMILLA[])
    cfg = Config{Float64}(; L = L, I = I, W_dec = W_dec, D = D, S_max = S_max, Lrev = Lrev,
                          con_h = con_h, espera = espera, cruce = cruce, lead_h = lead_h,
                          j_ini = j_ini)
    return barrer!(cfg; rhos = Float64.(rhos), n_rep = n_rep, J = J, alpha = Float64(alpha),
                   seed = seed, nb = nb, bin = bin, v_lo = v_lo, boot_ref = boot_ref,
                   modo_off = modo_off, lambda = lambda, nthreads = HILOS[])
end

"Fracción de épocas con steering (propio / ajeno) de un barrido."
frac_pro(res, i) = sum(res.n_pro[i, :]) / max(1, sum(res.n_ep[i, :]))
frac_hon(res, i) = sum(res.n_hon[i, :]) / max(1, sum(res.n_ep[i, :]))

"Fracción de épocas con steering en un único ρ (usa los mismos sorteos que la rejilla)."
function frac_en(rho::Float64; kwargs...)
    r = correr(; rhos = [rho], kwargs...)
    return frac_pro(r, 1)
end

"""
ρ* simulado: **bisección** sobre la fracción de épocas con steering (cruce por 0,5).

La transición es abrupta (0,33 → 1,00 en menos del 5 % de ρ), así que interpolar sobre una rejilla
gruesa sesga el resultado: se biseca en escala logarítmica con los mismos números aleatorios.
"""
function rho_estrella_bis(f::Function; lo = 2.0, hi = 40.0, tol = 0.005)
    f(lo) >= 0.5 && return lo
    f(hi) < 0.5 && return NaN
    for _ in 1:60
        mid = sqrt(lo * hi)
        if f(mid) >= 0.5
            hi = mid
        else
            lo = mid
        end
        (hi / lo - 1) < tol && break
    end
    return sqrt(lo * hi)
end

"Intervalo de confianza aproximado (95 %) de una tasa `k/n` de conteo Poisson."
ic95(k::Int, n::Int) = n == 0 ? (NaN, NaN) : (k / n - 1.96 * sqrt(k) / n, k / n + 1.96 * sqrt(k) / n)

# ── CONTROLES ────────────────────────────────────────────────────────────────

function modo_controles()
    hdr("CONTROL C1 — tope SIN (h) y bootstrap (9c §E.1). Parámetros de r10a_b1_reloj.py:89")
    L, I, W = 19080.0, 4200.0, 150.0
    println("  cerrado de 9c: L + I − W_dec = ", L + I - W, " slots  [publicado 23 130]")
    println("  cerrado de la ronda 7 (tope simulado): L + I(1−1/ρ); el simulador usa W_dec = 0")
    println("  (fila α = 0 de 9c: no hay decisión que tomar), offset = 0, D = 0")
    rhos = [1.01, 1.05, 1.15, 1.5, 3.0]
    res = correr(; L = L, I = I, W_dec = 0.0, D = 0.0, S_max = 0.0, Lrev = L, con_h = false,
                 espera = false, cruce = false, lead_h = 0.0, rhos = rhos, n_rep = 1, J = 1500,
                 alpha = 0.0, modo_off = :cero, bin = 64.0, nb = 2048, boot_ref = 0.9 * L)
    resf = correr(; L = L, I = I, W_dec = 0.0, D = 0.0, S_max = 0.0, Lrev = L, con_h = false,
                  espera = false, cruce = true, lead_h = 0.0, rhos = rhos, n_rep = 1, J = 1500,
                  alpha = 0.0, modo_off = :cero, bin = 64.0, nb = 2048, boot_ref = 0.9 * L)
    @printf("  %6s | %14s | %11s | %10s | %14s | %10s\n", "rho", "boot cruce=0", "razon",
            "tope sim", "boot cruce=1/rho", "razon")
    for i in eachindex(rhos)
        b = res.boot[i, 1]
        cerrado = 0.9 * L / (rhos[i] - 1)
        bf = resf.boot[i, 1]
        @printf("  %6.2f | %11.2f h | %11.3f | %10.0f | %11.2f h | %10.3f\n",
                rhos[i], b / 3600, b / cerrado, res.vbar[i, 1], bf / 3600, bf / cerrado)
    end
    println("  cerrado 0,9L/(ρ−1) a ρ=1,01: ", round(0.9 * L / (rhos[1] - 1) / 3600, digits = 2),
            " h  ·  9c midió 477,06 h (razón 1,000)")
    println("  cruce=0 imita r10a_lib.py:167 (cruce gratis, +1 slot por época); cruce=1/ρ es la física")
    println("  tope simulado frente a L + I(1−1/ρ):")
    for i in eachindex(rhos)
        c = L + I * (1 - 1 / rhos[i])
        @printf("    rho=%5.2f  sim=%12.0f  cerrado=%12.0f  razon=%.6f\n", rhos[i], res.vbar[i, 1], c, res.vbar[i, 1] / c)
    end

    hdr("CONTROL C2 — las dos formas de la ronda 7 (dag-poas-ancla-de-finalidad.md:319-322)")
    println("  W_dec = 0, offset = 0, cruce instantáneo (convención de r10a_lib.py), D = 0")
    println("  sin (h): L + I(1−1/ρ)   ·   con (h): (L+I)(1−1/ρ)  [Lrev = L]")
    for (L2, I2) in ((7200.0, 851.0), (3600.0, 851.0), (19080.0, 4200.0))
        rhos2 = [1.05, 1.2, 1.5, 2.0, 3.0]
        r0 = correr(; L = L2, I = I2, W_dec = 0.0, D = 0.0, S_max = 0.0, Lrev = L2, con_h = false,
                    espera = false, cruce = false, lead_h = 0.0, rhos = rhos2, n_rep = 1, J = 1200,
                    alpha = 0.0, modo_off = :cero, bin = 16.0, nb = 2048)
        r1 = correr(; L = L2, I = I2, W_dec = 0.0, D = 0.0, S_max = 0.0, Lrev = L2, con_h = true,
                    espera = false, cruce = false, lead_h = 0.0, rhos = rhos2, n_rep = 1, J = 1200,
                    alpha = 0.0, modo_off = :cero, bin = 16.0, nb = 2048)
        for i in eachindex(rhos2)
            c0 = L2 + I2 * (1 - 1 / rhos2[i])
            c1 = (L2 + I2) * (1 - 1 / rhos2[i])
            @printf("  L=%7.0f (h)=%d I=%6.0f rho=%4.2f | sim=%10.0f cerrado=%10.0f raz=%.6f | sim=%10.0f cerrado=%10.0f raz=%.6f\n",
                    L2, 0, I2, rhos2[i], r0.vbar[i, 1], c0, r0.vbar[i, 1] / c0,
                    r1.vbar[i, 1], c1, r1.vbar[i, 1] / c1)
        end
    end

    hdr("CONTROL C3 — ρ ≤ 1 ⇒ steering 0 exacto (9c hallazgo E1); «ρ>1» es asintótico")
    println("  fracción de épocas con steering sobre SU candidato (n_eval ≥ 1), horizonte finito")
    for (L2, I2, Wmap) in ((7200.0, 851.0, (0.10, 10.0, 0.33, 20.0, 0.40, 45.0)),
                           (19080.0, 4200.0, (0.10, 10.0, 0.33, 20.0, 0.40, 45.0)))
        rhos3 = [1.0, 1.001, 1.01, 1.05, 1.2, 2.0]
        for (a, w) in ((Wmap[1], Wmap[2]), (Wmap[3], Wmap[4]), (Wmap[5], Wmap[6]))
            r = correr(; L = L2, I = I2, W_dec = w, D = 0.0, S_max = 150.0, Lrev = L2, con_h = false,
                       espera = false, cruce = false, lead_h = 0.0, rhos = rhos3, n_rep = 24,
                       J = 1400, alpha = a, modo_off = :geom, bin = 32.0, nb = 4096, j_ini = 200)
            @printf("  L=%7.0f I=%6.0f alpha=%.2f W=%4.1f | ", L2, I2, a, w)
            for i in eachindex(rhos3)
                @printf("%7.3f ", frac_pro(r, i))
            end
            @printf("| horizonte %.1f d\n", r.rhos[end] * 0 + (1400 - 200) * I2 / 86400)
        end
    end

    hdr("CONTROL ρ* — umbral de steering simulado frente al cerrado (Lrev+I)/(I+W_dec)")
    for (L2, I2, W, Lrev, publicado) in ((7200.0, 851.0, 20.0, 7200.0, 9.24),
                                         (7200.0, 851.0, 45.0, 7200.0, 8.99),
                                         (3600.0, 851.0, 20.0, 3600.0, 5.13),
                                         (7200.0, 851.0, 20.0, 0.979 * 7200, 9.07),
                                         (7200.0, 851.0, 20.0, 0.50 * 7200, 5.11))
        kw = (L = L2, I = I2, W_dec = W, D = 0.0, S_max = 150.0, Lrev = Lrev, con_h = true,
              espera = false, cruce = false, lead_h = 0.0, n_rep = 32, J = 1400, alpha = 0.33,
              modo_off = :geom, bin = 32.0, nb = 4096, j_ini = 200)
        rs = rho_estrella_bis(rho -> frac_en(rho; kw...))
        rc = rho_estrella_10a(L2, I2, W, Lrev)
        @printf("  L=%7.0f I=%6.0f W=%4.1f Lrev=%7.1f | rho* sim=%7.3f  cerrado=%7.3f  publicado=%6.2f\n",
                L2, I2, W, Lrev, rs, rc, publicado)
    end

    hdr("CONTROL rachas de ancla propia (ronda 10a §B.1.3)")
    println("  IC 95 % aproximado de conteo Poisson; las tasas < 1e-5 con este presupuesto NO se miden")
    for rho in (1.5, 2.0, 2.5, 3.0, 5.0)
        n = n_rachas(7200.0, 851.0, rho, 20.0, 0.0)
        tc = tasa_rachas(7200.0, 851.0, rho, 0.33, 20.0, 0.0)
        J = rho <= 2.0 ? 4000 : 2000
        nrep = rho <= 2.0 ? 128 : 48
        r = correr(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 0.0, S_max = 150.0, Lrev = 7200.0,
                   con_h = true, espera = false, cruce = false, lead_h = 0.0, rhos = [rho],
                   n_rep = nrep, J = J, alpha = 0.33, modo_off = :unif, bin = 32.0, nb = 4096, j_ini = 0)
        k = sum(r.n_pro[1, :]); nn = sum(r.n_ep[1, :])
        fs = k / nn
        (iclo, ichi) = ic95(k, nn)
        @printf("  rho=%4.1f  n*=%3d  cerrada=%.4e  simulada=%.4e [%.2e, %.2e]  k=%d/%d  razon=%.3f\n",
                rho, n, tc, fs, iclo, ichi, k, nn, tc > 0 ? fs / tc : NaN)
    end
end

# ── COMPARACIÓN CON ADL-v1.0 ─────────────────────────────────────────────────

function modo_adl()
    hdr("A_frontera de ADL-v1.0 frente a V_max simulada, fila a fila")
    if !isfile(ADL_MODELO)
        println("  NO DETERMINADO: no se encontró ", ADL_MODELO)
        return
    end
    println("  fuente: ", ADL_MODELO)
    println("  A_frontera(ρ) = máx(0, mín(ρ·t, Γ−D) − mín(t, Γ−D)), Γ = t+I+L−W_dec")
    L, I, W, D, t = 7200.0, 851.0, 20.0, 4.0, 1.0e6
    rhos = [1.0, 1.001, 1.005, 1.008, 1.01, 1.1, 1.5, 2.0, 2.5, 3.0, 9.0, 100.0]
    J = 1400
    println("  rejilla del encargo: L=$L I=$I W_dec=$W D=$D t=$t J=$J epocas (horizonte $(round(J*I/86400,digits=2)) d)")
    println("  V simulada: frontera honesta D por delante (lead_h=D, C-POT-05), cruce con coste 1/ρ,")
    println("              adversario que ESPERA la decisión (modelo de 9c, el que reproduce A_core)")
    r = correr(; L = L, I = I, W_dec = W, D = D, S_max = 150.0, Lrev = L, con_h = false,
               espera = true, cruce = true, lead_h = D, rhos = rhos, n_rep = 1, J = J, alpha = 0.0,
               modo_off = :cero, bin = 16.0, nb = 4096, j_ini = 0)
    r0 = correr(; L = L, I = I, W_dec = W, D = D, S_max = 150.0, Lrev = L, con_h = false,
                espera = true, cruce = true, lead_h = 0.0, rhos = rhos, n_rep = 1, J = J, alpha = 0.0,
                modo_off = :cero, bin = 16.0, nb = 4096, j_ini = 0)
    @printf("  %7s | %14s | %14s | %10s | %14s | %10s\n", "rho", "A_frontera ADL", "V_max sim (D)", "dif", "V_max sim (D=0)", "A_core")
    for i in eachindex(rhos)
        af = AdlRef.adelanto_frontera(rhos[i], L, I, W, D, t)
        ac = a_core_semv1(rhos[i], L, I, W)
        @printf("  %7.3f | %14.2f | %14.2f | %10.2f | %14.2f | %10.2f\n",
                rhos[i], af, r.vmax[i, 1], r.vmax[i, 1] - af, r0.vmax[i, 1], ac)
    end
    println()
    println("  régimen estacionario (ρ ≥ 2): ADL = L+I−W_dec−D = ", L + I - W - D,
            ";  V_max simulado (D) − ADL = ", r.vmax[end-2, 1] - (L + I - W - D))
end

# ── F1 · sin (h): ¿quién tiene razón? ────────────────────────────────────────

function modo_f1()
    hdr("F1 · V sin (h) frente a A_core, a L+I(1−1/ρ) y al tope de ADL")
    L, I, W, D = 7200.0, 851.0, 20.0, 4.0
    rhos = [1.01, 1.05, 1.1, 1.25, 1.5, 2.0, 2.5, 3.0, 5.0, 9.0]
    println("  L=$L I=$I W_dec=$W D=$D, offset 0, J=1500 epocas, 64 replicas para V_min (α=0)")
    for (etiqueta, espera, cruce, lead) in
        (("espera la decisión, honesto D adelante (C-POT-05)", true, true, D),
         ("espera la decisión, honesto en su frontera    ", true, true, 0.0),
         ("especula (10a), honesto D adelante            ", false, true, D),
         ("especula (10a), honesto en su frontera        ", false, true, 0.0))
        r = correr(; L = L, I = I, W_dec = W, D = D, S_max = 150.0, Lrev = L, con_h = false,
                   espera = espera, cruce = cruce, lead_h = lead, rhos = rhos, n_rep = 1, J = 1500,
                   alpha = 0.0, modo_off = :cero, bin = 16.0, nb = 4096, j_ini = 0)
        rr = correr(; L = L, I = I, W_dec = W, D = D, S_max = 150.0, Lrev = L, con_h = false,
                    espera = espera, cruce = cruce, lead_h = lead, rhos = rhos, n_rep = 32, J = 1500,
                    alpha = 0.0, modo_off = :unif, bin = 16.0, nb = 4096, j_ini = 0)
        println()
        println("  adversario: ", etiqueta)
        rs = correr(; L = L, I = I, W_dec = W, D = D, S_max = 150.0, Lrev = L, con_h = false,
                    espera = espera, cruce = cruce, lead_h = lead, rhos = rhos, n_rep = 4, J = 1500,
                    alpha = 0.0, modo_off = :unif, bin = 16.0, nb = 4096, j_ini = 700)
        @printf("  %6s | %10s | %10s | %10s | %10s | %10s | %10s | %10s | %10s\n",
                "rho", "V_max sim", "V_min ini", "V_min reg", "A_core", "L+I(1-1/r)", "ADL estac.",
                "boot(h)", "v_barrera")
        for i in eachindex(rhos)
            ac = a_core_semv1(rhos[i], L, I, W)
            r7 = L + I * (1 - 1 / rhos[i])
            adl = L + I - W - D
            @printf("  %6.2f | %10.1f | %10.1f | %10.1f | %10.1f | %10.1f | %10.1f | %10.2f | %10.1f\n",
                    rhos[i], r.vmax[i, 1], rr.vmin[i, 1], rs.vmin[i, 1], ac, r7, adl,
                    r.boot[i, 1] >= 0 ? r.boot[i, 1] / 3600 : NaN, r.vbar[i, 1])
        end
    end
    println()
    println("  bootstrap medido (llegar a 0,9·L) frente a 0,9L/(ρ−1), adversario que espera:")
    r = correr(; L = L, I = I, W_dec = W, D = D, S_max = 150.0, Lrev = L, con_h = false,
               espera = true, cruce = true, lead_h = D, rhos = [1.01, 1.05, 1.5, 3.0], n_rep = 1,
               J = 1500, alpha = 0.0, modo_off = :cero, bin = 16.0, nb = 4096, boot_ref = 0.9 * L)
    for i in eachindex(r.rhos)
        @printf("    rho=%5.2f  boot sim=%8.2f h  cerrado=%8.2f h  razon=%.3f\n",
                r.rhos[i], r.boot[i, 1] / 3600, 0.9 * L / (r.rhos[i] - 1) / 3600,
                r.boot[i, 1] / (0.9 * L / (r.rhos[i] - 1)))
    end
end

# ── F2 · con (h) ─────────────────────────────────────────────────────────────

function modo_f2()
    hdr("F2 · V con (h) y el steering, por separado")
    L, I, W, D, S_max = 7200.0, 851.0, 20.0, 4.0, 150.0
    rhos = [1.01, 1.05, 1.1, 1.25, 1.5, 2.0, 2.5, 3.0, 5.0, 9.0]
    for (etiq, Lrev) in (("Lrev = L", L), ("Lrev = L − S_max", L - S_max))
        for espera in (true, false)
            r = correr(; L = L, I = I, W_dec = W, D = D, S_max = S_max, Lrev = Lrev, con_h = true,
                       espera = espera, cruce = true, lead_h = D, rhos = rhos, n_rep = 1, J = 1500,
                       alpha = 0.0, modo_off = :cero, bin = 16.0, nb = 4096, j_ini = 0)
            println()
            @printf("  (h), %s, %s, honesto D adelante\n", etiq, espera ? "espera" : "especula")
            @printf("  %6s | %10s | %10s | %12s | %12s | %10s\n", "rho", "V_max", "V_min",
                    "(L+I)(1-1/r)", "(Lrev+I)(1-1/r)", "A_con_h ADL")
            for i in eachindex(rhos)
                v7 = (L + I) * (1 - 1 / rhos[i])
                v7r = (Lrev + I) * (1 - 1 / rhos[i])
                ach = max(0.0, (I + W - 1) - (L + I) / rhos[i])
                @printf("  %6.2f | %10.1f | %10.1f | %12.1f | %12.1f | %10.1f\n",
                        rhos[i], r.vmax[i, 1], r.vmin[i, 1], v7, v7r, ach)
            end
        end
    end
    println()
    println("  efecto de +D: V_max con honesto D adelante menos V_max con honesto en su frontera")
    ra = correr(; L = L, I = I, W_dec = W, D = D, S_max = S_max, Lrev = L - S_max, con_h = true,
                espera = true, cruce = true, lead_h = D, rhos = rhos, n_rep = 1, J = 1500,
                alpha = 0.0, modo_off = :cero, bin = 16.0, nb = 4096)
    rb = correr(; L = L, I = I, W_dec = W, D = D, S_max = S_max, Lrev = L - S_max, con_h = true,
                espera = true, cruce = true, lead_h = 0.0, rhos = rhos, n_rep = 1, J = 1500,
                alpha = 0.0, modo_off = :cero, bin = 16.0, nb = 4096)
    for i in eachindex(rhos)
        @printf("    rho=%5.2f  V_max(D)=%9.1f  V_max(0)=%9.1f  diferencia=%7.1f  (D=%g)\n",
                rhos[i], ra.vmax[i, 1], rb.vmax[i, 1], rb.vmax[i, 1] - ra.vmax[i, 1], D)
    end

    hdr("F2.b · distribución temporal de V con rachas, por α (cuantiles y excedencia)")
    println("  (h), Lrev = L − S_max, especula, honesto D adelante, J=2000, 96 réplicas, offset geom")
    println("  la rejilla de ρ es [1, ρ_max]; los cuantiles son de la masa de TIEMPO agregada")
    for a in (0.10, 0.25, 0.33, 0.40)
        rhos2 = exp.(range(0.0, log(3.0), length = 9))
        r = correr(; L = L, I = I, W_dec = 20.0, D = D, S_max = S_max, Lrev = L - S_max, con_h = true,
                   espera = false, cruce = true, lead_h = D, rhos = rhos2, n_rep = 96, J = 2000,
                   alpha = a, modo_off = :geom, bin = 32.0, nb = 8192, j_ini = 200)
        h, bajo, sobre = hist_agregado(r)
        q50 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.50)
        q90 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.90)
        q99 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.99)
        q999 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.999)
        exc = fraccion_excedencia(h, bajo, sobre, r.bin, r.v_lo, L - 20.0)
        @printf("  alpha=%.2f | q50=%8.1f q90=%8.1f q99=%8.1f q99.9=%8.1f | max(V)=%9.1f | P(V>=L−W)=%.4f\n",
                a, q50, q90, q99, q999, maximum(r.vmax), exc)
    end

    hdr("F2.c · ρ* simulado frente al cerrado (Lrev = L − S_max)")
    for (L2, I2, W2) in ((7200.0, 851.0, 20.0), (7200.0, 851.0, 45.0), (3600.0, 851.0, 20.0))
        Lrev = L2 - 150.0
        kw = (L = L2, I = I2, W_dec = W2, D = 0.0, S_max = 150.0, Lrev = max(Lrev, 1.0),
              con_h = true, espera = false, cruce = true, lead_h = 0.0, n_rep = 48,
              J = 1600, alpha = 0.33, modo_off = :unif, bin = 32.0, nb = 8192, j_ini = 200)
        rs = rho_estrella_bis(rho -> frac_en(rho; kw...))
        @printf("  L=%7.0f I=%6.0f W=%4.1f Lrev=%7.1f | rho* propio sim=%7.3f  cerrado=%7.3f\n",
                L2, I2, W2, Lrev, rs, rho_estrella_10a(L2, I2, W2, max(Lrev, 1.0)))
    end
end

# ── F3 · C-FLU-01 con I recalibrado ─────────────────────────────────────────

function modo_f3()
    hdr("F3 · C-FLU-01 con I recalibrado por (h.6); I* = (L − ρ_max·W_dec)/(ρ_max − 1)")
    W_dec, S_max, D = 20.0, 150.0, 4.0
    println("  L = máx(F, L_suelo = 0, S_max+1); Lrev = L − S_max; restricciones I > S_max y I ≥ ρ_max·W_dec")
    @printf("  %7s | %5s | %7s | %7s | %7s | %6s | %8s | %8s | %10s | %10s | %8s\n",
            "F", "rho_m", "L", "I*", "I usado", "q+1", "nucleos", "rho*", "V_max", "iny/h", "admisible")
    for F in (1019.0, 3547.0, 3600.0, 7200.0)
        for rho_max in (1.2, 1.5, 2.5, 3.0)
            L = max(F, S_max + 1)
            Lrev = L - S_max
            Istar = I_estrella(L, rho_max, W_dec)
            Imin = I_minima(rho_max, W_dec, S_max)
            adm = Istar >= Imin
            Ius = adm ? Istar : Imin
            q = lineas_timekeeper(L, Ius)
            nu = nucleos_nodo(L, Ius)
            rs = rho_estrella_10a(L, Ius, W_dec, Lrev)
            r = correr(; L = L, I = Ius, W_dec = W_dec, D = D, S_max = S_max, Lrev = Lrev,
                       con_h = true, espera = false, cruce = true, lead_h = D, rhos = [rho_max],
                       n_rep = 1, J = 900, alpha = 0.0, modo_off = :cero, bin = 16.0, nb = 4096)
            @printf("  %7.0f | %5.2f | %7.0f | %7.1f | %7.1f | %6d | %8.3f | %8.3f | %10.1f | %10.2f | %8s\n",
                    F, rho_max, L, Istar, Ius, q, nu, rs, r.vmax[1, 1],
                    instantes_por_hora(Ius), adm ? "si" : "NO")
        end
    end
    println()
    println("  realimentación F → L → ρ*: ρ* = (Lrev+I)/(I+W_dec) con I recalibrado en cada fila.")
    println("  ¿queda dependencia de ρ* en F una vez recalibrado I?  (dos F con el mismo L dan lo mismo)")
    for rho_max in (1.5, 2.5)
        for F in (1019.0, 3547.0, 3600.0, 7200.0)
            L = max(F, S_max + 1)
            I = max(I_minima(rho_max, W_dec, S_max), I_estrella(L, rho_max, W_dec))
            @printf("    rho_max=%.1f F=%7.0f L=%7.0f I=%7.1f rho*=%7.3f q+1=%2d nucleos=%.3f\n",
                    rho_max, F, L, I, rho_estrella_10a(L, I, W_dec, L - S_max),
                    lineas_timekeeper(L, I), nucleos_nodo(L, I))
        end
    end
end

# ── F4 · cotas para P-SEMBRADOR ─────────────────────────────────────────────

function modo_f4()
    hdr("F4 · edad M y sellado T_seal como CUANTIL de V (no como sup)")
    W_dec, S_max, D = 20.0, 150.0, 4.0
    println("  M > cuantil_q(V sobre ρ ∈ [1, ρ_max]) + margen; margen = símbolo (no se fija)")
    println("  se publica q99 y la tasa de excedencia P(V ≥ M) para M = q99")
    for (etiq, con_h, Lrev) in (("sin (h)", false, 0.0), ("con (h) Lrev=L−S_max", true, -1.0))
        println()
        println("  ── ", etiq)
        @printf("  %7s | %5s | %7s | %10s | %10s | %10s | %10s\n",
                "F", "rho_m", "L", "q50", "q90", "q99", "P(V>=q99)")
        for F in (1019.0, 3547.0, 3600.0, 7200.0)
            for rho_max in (1.2, 1.5, 2.5, 3.0)
                L = max(F, S_max + 1)
                Lr = con_h ? L - S_max : L
                rhos = exp.(range(0.0, log(rho_max), length = 9))
                r = correr(; L = L, I = 851.0, W_dec = W_dec, D = D, S_max = S_max, Lrev = Lr,
                           con_h = con_h, espera = false, cruce = true, lead_h = D, rhos = rhos,
                           n_rep = 64, J = 1200, alpha = 0.33, modo_off = :geom, bin = 16.0,
                           nb = 8192, j_ini = 150)
                h, bajo, sobre = hist_agregado(r)
                q50 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.50)
                q90 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.90)
                q99 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.99)
                pexc = fraccion_excedencia(h, bajo, sobre, r.bin, r.v_lo, q99)
                @printf("  %7.0f | %5.2f | %7.0f | %10.1f | %10.1f | %10.1f | %10.4f\n",
                        F, rho_max, L, q50, q90, q99, pexc)
            end
        end
    end
    println()
    println("  factor de reducción de la edad exigida por (h): q99(sin h)/q99(con h), misma fila")
end

# ── F5 · coste para el honesto ──────────────────────────────────────────────

function modo_f5()
    hdr("F5 · lo que (h) le cuesta al honesto (entradas medidas, no resultados)")
    println("  prove = 1,561 s/slot y verify = 96,1 ms/slot MEDIDOS en research/dag-poas-ancla-de-orden.md:342")
    println("  líneas = q+1 = ⌈L/I⌉+1;  núcleos/nodo = 0,0961·(1+L/I);  puntualidad Lrev ≤ L − W_dec − D")
    W_dec, D, S_max = 20.0, 4.0, 150.0
    @printf("  %7s | %7s | %7s | %5s | %5s | %10s | %10s | %10s | %12s\n",
            "F", "I", "L", "q+1", "m*q", "nucleos", "verif s/ep", "prove s/ep", "puntual")
    for (F, I) in ((1019.0, 851.0), (3547.0, 851.0), (3600.0, 851.0), (7200.0, 851.0),
                   (7200.0, 4725.0), (7200.0, 300.0), (3600.0, 300.0))
        L = max(F, S_max + 1)
        q = lineas_timekeeper(L, I)
        m = 1.83                          # menú medido por 9c a α = 0,40 (r10a_lib.py:61)
        nu = nucleos_nodo(L, I)
        (cv, cp) = coste_verificacion(L, I)
        Lrev = L - S_max
        punt = puntualidad_estricta(L, W_dec, Lrev, D, S_max)
        @printf("  %7.0f | %7.0f | %7.0f | %5d | %5.0f | %10.3f | %10.1f | %10.1f | %12s\n",
                F, I, L, q, m * q, nu, cv, cp, punt ? "si" : "NO")
    end
    println()
    println("  presupuesto del nodo: la cadena principal sola cuesta 0,0961 núcleos; con (h) el factor es 1+L/I")
    println("  instantes t_j por hora (cada uno es un punto donde puede nacer una partición de flujo):")
    for I in (300.0, 851.0, 4200.0, 4725.0)
        @printf("    I=%7.1f s -> %8.2f inyecciones/hora  (una cada %.1f min)\n", I, instantes_por_hora(I), I / 60)
    end
end

# ── main ─────────────────────────────────────────────────────────────────────

function main()
    modo = "todo"
    args = copy(ARGS)
    i = 1
    while i <= length(args)
        if args[i] == "--modo"
            modo = args[i+1]; i += 2
        elseif args[i] == "--hilos"
            HILOS[] = parse(Int, args[i+1]); i += 2
        elseif args[i] == "--semilla"
            SEMILLA[] = parse(UInt64, args[i+1]); i += 2
        else
            error("argumento desconocido: $(args[i])")
        end
    end
    println("REV-v1.0 · ", Dates.now(), " · Julia ", VERSION, " · ", Sys.CPU_NAME,
            " · hilos=", HILOS[], " · semilla=0x", string(SEMILLA[], base = 16))
    println("A_frontera de ADL-v1.0 disponible: ", isfile(ADL_MODELO))
    if modo in ("controles", "todo"); modo_controles(); end
    if modo in ("adl", "todo"); modo_adl(); end
    if modo in ("f1", "todo"); modo_f1(); end
    if modo in ("f2", "todo"); modo_f2(); end
    if modo in ("f3", "todo"); modo_f3(); end
    if modo in ("f4", "todo"); modo_f4(); end
    if modo in ("f5", "todo"); modo_f5(); end
    println()
    println("fin · ", Dates.now())
end

main()
