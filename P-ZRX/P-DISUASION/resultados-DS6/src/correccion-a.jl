#!/usr/bin/env julia
# CORRECCIÓN DS6-A — convención del exponente (densidad = cola + 1) y B(ε) EMPÍRICO directo
# (sin ajustar ninguna ley), sobre los mismos datos de crudo/farmers-raw.csv (SpaceFarmers.io,
# 2026-09-26). Ver P-ZRX/P-DISUASION/CORRECCION-DS6-A.md.
#
# Parte 1: recalcula B(ε) del ajuste de Pareto con alpha_dens = alpha_cola + 1 (la convención que
# de verdad usa `masa_prob` de DS3/src/modelo.jl: p(f) ∝ f^-alpha_dens, CCDF(f) = (f_min/f)^(alpha_dens-1),
# por tanto "alpha de la cola" (lo que ajusta mle_pareto/ks_pareto de analisis.jl, que fitea la CCDF
# como (xmin/x)^alpha) = alpha_dens - 1. Se verifica por rederivación de E[min(f,x)]/E[f] con
# densidad p(f)=c f^-g: converge y da exactamente `1-(f_min/x)^(g-2)` cuando g=alpha_dens, y
# requiere g>2 para que E[f] sea finito -- coincide con el comentario de P-CLAVE. Con esta g, el
# checkpoint de DS-3 (0.675466 para "dist_alpha"=2.2) se sigue reproduciendo exactamente porque
# escenarios.tsv ya declara `dist_alpha` en la convención de DENSIDAD (2.2 es `g`, no la cola).
#
# Parte 2: B(ε) EMPÍRICO, sin ajustar ninguna ley: fracción del espacio de red que está en
# granjeros con f_i < x = ε/(λ T_v), calculada directamente sobre los 2.453 granjeros limpios.
# Bootstrap por granjero (remuestreo con reemplazo, mismo tamaño de muestra, 5.000 réplicas).
#
# Sin Python, sin git, sin subagentes. Julia 1.13.0, 1 hilo, <1 GiB RAM, <1 s.

using Random
using Statistics
using Printf

const SEMILLA = UInt64(0x5a5a)
const N_BOOT  = 5000
const RUTA_MUESTRA = joinpath(@__DIR__, "..", "resultados", "muestra-limpia.csv")
const RUTA_OUT = joinpath(@__DIR__, "..", "resultados")

# ---------------------------------------------------------------------------
# Parte 1 — corrección de convención
# ---------------------------------------------------------------------------

function B_eps_truncada(dist_alpha::Float64; eps_saldo::Float64, lambda::Float64 = 1.0,
                         Tv::Float64, fmin::Float64 = 1e-8, Fmax::Float64 = 1.0)
    isapprox(dist_alpha, 2.0; atol = 1e-9) && return NaN
    x = eps_saldo / (lambda * Tv)
    x <= fmin && return 0.0
    x = min(x, Fmax)
    b = 2 - dist_alpha
    return (x^b - fmin^b) / (Fmax^b - fmin^b)
end

function B_eps_no_truncada(dist_alpha::Float64; eps_saldo::Float64, lambda::Float64 = 1.0, Tv::Float64, fmin::Float64 = 1e-8)
    dist_alpha <= 2 && return NaN
    x = eps_saldo / (lambda * Tv)
    x <= fmin && return 0.0
    return 1 - (fmin / x)^(dist_alpha - 2)
end

function parte1()
    println("=== Parte 1 · corrección de convención (densidad = cola + 1) ===\n")
    chk = B_eps_no_truncada(2.2; eps_saldo = 0.01, Tv = 3600.0)
    @printf("Autocomprobación (sin cambios): B(dist_alpha=2.2 EN CONVENCIÓN DE DENSIDAD) = %.6f (DS-3: 0.675466)\n\n", chk)

    # de analisis.jl (resultados/resumen-ajuste.csv): alpha_cola (convención de la cola, CCDF=(xmin/x)^alpha_cola)
    ajustes_cola = [
        ("global",      0.1113, 0.1102, 0.1124),
        ("cola_optima", 0.8560, 0.8096, 0.9069),
    ]

    abrir = open(joinpath(RUTA_OUT, "correccionA-Beps-corregido.csv"), "w")
    println(abrir, "ajuste,alpha_cola_hat,alpha_dens_hat,alpha_dens_ic_lo,alpha_dens_ic_hi,formula,Tv,eps,B_eps_punto,B_eps_ic_lo,B_eps_ic_hi")
    for (nombre, a_cola, lo_cola, hi_cola) in ajustes_cola
        a_dens  = a_cola + 1
        lo_dens = lo_cola + 1
        hi_dens = hi_cola + 1
        @printf("[%s] alpha_cola=%.4f -> alpha_dens=%.4f  IC95=[%.4f; %.4f]\n", nombre, a_cola, a_dens, lo_dens, hi_dens)
        for Tv in (3600.0, 100000.0), eps in (0.001, 0.01, 0.1)
            for (etiqueta, f) in (("no_truncada_DS3", B_eps_no_truncada), ("truncada_F1_PCLAVE", B_eps_truncada))
                bp = f(a_dens;  eps_saldo = eps, Tv = Tv)
                bl = f(lo_dens; eps_saldo = eps, Tv = Tv)
                bh = f(hi_dens; eps_saldo = eps, Tv = Tv)
                @printf(abrir, "%s,%.4f,%.4f,%.4f,%.4f,%s,%.0f,%.4f,%.6g,%.6g,%.6g\n",
                        nombre, a_cola, a_dens, lo_dens, hi_dens, etiqueta, Tv, eps, bp, bl, bh)
            end
        end
    end
    close(abrir)

    b_p  = B_eps_truncada(0.856 + 1; eps_saldo = 0.01, Tv = 3600.0)
    b_lo = B_eps_truncada(0.8096 + 1; eps_saldo = 0.01, Tv = 3600.0)
    b_hi = B_eps_truncada(0.9069 + 1; eps_saldo = 0.01, Tv = 3600.0)
    @printf("\nComprobación contra la cifra del director (cola óptima, eps=0.01, Tv=3600): B(ε)=%.4f [%.4f; %.4f] (esperado ≈0.095 [0.060;0.151])\n\n", b_p, b_lo, b_hi)
end

# ---------------------------------------------------------------------------
# Parte 2 — B(ε) empírico directo (sin ajustar ninguna ley)
# ---------------------------------------------------------------------------

struct Granjero
    points::Float64
    tib::Float64
end

function cargar_muestra(ruta::AbstractString)::Vector{Granjero}
    filas = Granjero[]
    open(ruta, "r") do io
        primera = true
        for linea in eachline(io)
            if primera; primera = false; continue; end
            isempty(strip(linea)) && continue
            campos = split(linea, ',')
            push!(filas, Granjero(parse(Float64, campos[2]), parse(Float64, campos[3])))
        end
    end
    return filas
end

"""B(ε) empírico: fracción del espacio DE REFERENCIA (denom) que está en granjeros con
f_i = tib_i/denom_tib < x = eps/(lambda*Tv). No ajusta ninguna ley."""
function B_emp(tibs::Vector{Float64}, denom_tib::Float64, eps::Float64, Tv::Float64; lambda::Float64 = 1.0)
    x = eps / (lambda * Tv)              # umbral en fracción del denominador
    umbral_tib = x * denom_tib           # mismo umbral, en TiB
    suma = 0.0
    @inbounds for t in tibs
        if t < umbral_tib
            suma += t
        end
    end
    return suma / denom_tib
end

function bootstrap_Bemp(tibs::Vector{Float64}, denom_tib::Float64, eps::Float64, Tv::Float64, nrep::Int, semilla::UInt64)
    n = length(tibs)
    rng = Xoshiro(semilla)
    reps = Vector{Float64}(undef, nrep)
    muestra = Vector{Float64}(undef, n)
    for r in 1:nrep
        for i in 1:n
            muestra[i] = tibs[rand(rng, 1:n)]
        end
        reps[r] = B_emp(muestra, denom_tib, eps, Tv)
    end
    return reps
end

function ic_percentil(reps::Vector{Float64}, p::Float64 = 0.025)
    q = sort(reps)
    return (quantile(q, p), quantile(q, 1 - p))
end

function parte2()
    println("=== Parte 2 · B(ε) EMPÍRICO directo (sin ajustar ninguna ley) ===\n")
    granjeros = cargar_muestra(RUTA_MUESTRA)
    tibs = [g.tib for g in granjeros]
    n = length(tibs)
    pool_total_tib = sum(tibs)  # denominador "pool" = suma de la propia muestra limpia (autocontenido)
    @printf("n granjeros = %d | suma TiB de la muestra (denom. 'pool') = %.2f TiB (%.2f PiB)\n",
            n, pool_total_tib, pool_total_tib / 1024)
    @printf("Referencia mostrada por el sitio (crudo/page_home.html, 2026-09-26): 576,07 PiB (%.3f%% de diferencia con la suma de la muestra)\n\n",
            100 * abs(pool_total_tib/1024 - 576.07) / 576.07)

    # Denominador "red": SECUNDARIO, con fecha distinta a la de la descarga y con incertidumbre
    # declarada. Fuente: XCH.today (ago-2026), citado en LowEndBox, "The Crypto That Ate All the
    # Hard Drives" (netspace efectivo <4 EiB, capacidad bruta real probablemente <3 EiB, ~10% del
    # pico histórico 36,73 EiB). NO se pudo obtener una cifra en vivo verificable con fecha
    # 2026-09-26 dentro del presupuesto de 45 min de esta corrección (spacescan.io/xchscan.com/
    # chiaexplorer.com/dashboard.chia.net devolvieron 403/302/JS-only al intentar leer el número
    # servido; se declara, no se inventa un valor puntual). Se usa una BANDA amplia de sensibilidad
    # que cubre el mínimo declarado y escenarios históricos más altos, precisamente porque el punto
    # no se pudo verificar.
    denom_red_PiB = [1024.0*1, 1024.0*3, 1024.0*4, 1024.0*10, 1024.0*20, 1024.0*36.73]  # 1,3,4,10,20,36.73 EiB en PiB
    etiquetas_red = ["1 EiB (piso especulativo)", "3 EiB (XCH.today ago-2026, bruto)",
                      "4 EiB (XCH.today ago-2026, efectivo)", "10 EiB (escenario intermedio)",
                      "20 EiB (escenario intermedio-alto)", "36,73 EiB (pico histórico, ATH)"]

    Tv_grid = (3600.0, 100000.0)
    eps_grid = (0.001, 0.01, 0.1)
    atacante_grid = (0.20, 0.25, 0.33, 0.40)

    abrir = open(joinpath(RUTA_OUT, "correccionA-Beps-empirico.csv"), "w")
    println(abrir, "denominador,denom_tib,Tv,eps,B_emp_punto,B_emp_ic_lo,B_emp_ic_hi,alpha_atacante,umbral,margen_punto,grieta")

    println("--- Denominador POOL (autocontenido, primario: mi propia muestra) ---")
    for Tv in Tv_grid, eps in eps_grid
        bp = B_emp(tibs, pool_total_tib, eps, Tv)
        reps = bootstrap_Bemp(tibs, pool_total_tib, eps, Tv, N_BOOT, SEMILLA)
        lo, hi = ic_percentil(reps)
        @printf("  Tv=%-7.0f eps=%-6.3f -> B_emp = %.6g  IC95=[%.6g; %.6g]\n", Tv, eps, bp, lo, hi)
        for aat in atacante_grid
            umbral = 1 - 2*aat
            margen = bp - umbral
            grieta = bp > umbral ? "SI" : "NO"
            @printf(abrir, "pool,%.2f,%.0f,%.4f,%.8g,%.8g,%.8g,%.2f,%.4f,%.8g,%s\n",
                    pool_total_tib, Tv, eps, bp, lo, hi, aat, umbral, margen, grieta)
        end
    end

    println("\n--- Denominador RED (secundario, banda de sensibilidad, ver reservas) ---")
    for (denom_PiB, etiqueta) in zip(denom_red_PiB, etiquetas_red)
        denom_tib = denom_PiB * 1024.0
        println("  [$etiqueta = $(denom_PiB) PiB]")
        for Tv in Tv_grid, eps in eps_grid
            bp = B_emp(tibs, denom_tib, eps, Tv)
            reps = bootstrap_Bemp(tibs, denom_tib, eps, Tv, N_BOOT, SEMILLA)
            lo, hi = ic_percentil(reps)
            @printf("    Tv=%-7.0f eps=%-6.3f -> B_emp = %.6g  IC95=[%.6g; %.6g]\n", Tv, eps, bp, lo, hi)
            for aat in atacante_grid
                umbral = 1 - 2*aat
                margen = bp - umbral
                grieta = bp > umbral ? "SI" : "NO"
                @printf(abrir, "red_%s,%.2f,%.0f,%.4f,%.8g,%.8g,%.8g,%.2f,%.4f,%.8g,%s\n",
                        replace(etiqueta, " "=>"_", ","=>""), denom_tib, Tv, eps, bp, lo, hi, aat, umbral, margen, grieta)
            end
        end
    end
    close(abrir)
    println("\nSalida: resultados/correccionA-Beps-empirico.csv, resultados/correccionA-Beps-corregido.csv")
end

parte1()
parte2()
