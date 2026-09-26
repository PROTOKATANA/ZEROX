#!/usr/bin/env julia
# DS-6 · análisis de la cola de tamaños de clave/granjero con datos reales de Chia (SpaceFarmers.io)
#
# Contexto (leer antes de tocar este archivo):
#   - P-ZRX/P-DISUASION/ORDEN-DS6-REPARTO-CLAVES.md (encargo)
#   - P-ZRX/P-DISUASION/resultados-DS2/MODELO.md §2.4 (definición de B(ε)) y §3 (H3: Pareto(f_min=1e-8, dist_alpha), truncada)
#   - P-ZRX/P-DISUASION/DS3/src/modelo.jl líneas 45-153 (implementación de referencia: `Pareto`, `masa_prob`, `masa_espacio_bajo_b`)
#   - P-ZRX/P-DISUASION/DS3/escenarios.tsv (parámetros: dist_f_min=1e-8, eps_saldo=0.01, lambda=1, T_v∈{...,3600,100000,...}, dist_alpha∈{2.05,2.2,2.5,3.0})
#
# Convención de `dist_alpha` (verificada contra DS3/src/modelo.jl, NO la de Clauset-Shalizi-Newman):
#   pdf(f) = dist_alpha * f_min^dist_alpha / f^(dist_alpha+1),  f >= f_min   (Pareto Tipo I, forma de Wikipedia/Distributions.jl)
#   CCDF(f) = (f_min/f)^dist_alpha
#   MLE con f_min conocido (fórmula clásica, no la de Clauset con el "+1"):
#       dist_alpha_hat = n / sum(log.(x ./ xmin))
#   (Clauset et al. 2009 usan pdf ∝ x^-α_C con α_C = dist_alpha + 1; NO USAR esa fórmula sin restar 1.)
#
# B(ε) = M(ε/(λT_v)) con F_max=∞ (así lo implementa DS3, ver masa_prob líneas 139-148, rama isinf(F_max)):
#       M(x) = 1 - (f_min/x)^(dist_alpha - 2)     [requiere dist_alpha > 2]
#
# Presupuesto declarado (LINEO §7): esta auditoría usa como máximo 1 hilo, <1 GiB de RAM y unos
# pocos MiB de disco; n≈2470, bootstrap B=5000 y una rejilla de xmin de ≤2470 candidatos son
# O(n) / O(n·|rejilla|) ≈ 10^6-10^7 operaciones escalares: no requiere hilos, GPU ni estructuras
# especiales. Si algo se agotara, el checkpoint es este mismo script con menos réplicas.
#
# Sin Python. Julia 1.13.0 (juliaup 1.22.7), CPU znver5, 1 hilo. Semilla fija: ver `SEMILLA` abajo.

using Random
using Statistics
using Printf

const SEMILLA = UInt64(0x5a5a)  # misma semilla que usa DS-3 (resultados/RUN.log), por comparabilidad
const N_BOOT  = 5000
const RUTA_CSV = joinpath(@__DIR__, "..", "crudo", "farmers-raw.csv")
const RUTA_OUT = joinpath(@__DIR__, "..", "resultados")

# ---------------------------------------------------------------------------
# 1. Carga y limpieza (function barrier: E/S dinámica -> vectores tipados)
# ---------------------------------------------------------------------------

struct Fila
    pagina::Int
    launcher_id::String
    puntos::Int64
    tib::Float64
end

function cargar_csv(ruta::AbstractString)::Vector{Fila}
    filas = Fila[]
    open(ruta, "r") do io
        primera = true
        for linea in eachline(io)
            if primera
                primera = false
                continue
            end
            isempty(strip(linea)) && continue
            campos = split(linea, ',')
            length(campos) == 4 || error("línea mal formada: $linea")
            push!(filas, Fila(parse(Int, campos[1]), String(campos[2]),
                               parse(Int64, campos[3]), parse(Float64, campos[4])))
        end
    end
    return filas
end

"""Deduplica por `launcher_id` (conserva la primera aparición, orden de página/rango).
13 duplicados esperados: la tabla del pool es en vivo y el barrido secuencial de 247
páginas (2026-09-26, ~07:25-07:30 UTC) tardó minutos; algunos granjeros pequeños
cambiaron de página frontera durante la descarga. Se documenta como sesgo de medición
menor (13/2470 = 0,53% de las filas), no se oculta."""
function deduplicar(filas::Vector{Fila})::Vector{Fila}
    vistos = Set{String}()
    salida = Fila[]
    for f in filas
        if !(f.launcher_id in vistos)
            push!(vistos, f.launcher_id)
            push!(salida, f)
        end
    end
    return salida
end

# ---------------------------------------------------------------------------
# 2. MLE de Pareto Tipo I (fórmula cerrada, no la de Clauset)
# ---------------------------------------------------------------------------

"""MLE cerrada de `dist_alpha` con `xmin` conocido/elegido, sobre la cola `x .>= xmin`.
Devuelve (alpha_hat, n_cola)."""
function mle_pareto(x::Vector{Float64}, xmin::Float64)
    cola = filter(>=(xmin), x)
    n = length(cola)
    n < 2 && return (NaN, n)
    s = sum(log.(cola ./ xmin))
    s <= 0 && return (NaN, n)
    return (n / s, n)
end

"""Estadístico KS entre la cola empírica `x .>= xmin` y la Pareto ajustada `(xmin, alpha)`."""
function ks_pareto(x::Vector{Float64}, xmin::Float64, alpha::Float64)
    cola = sort(filter(>=(xmin), x))
    n = length(cola)
    n == 0 && return NaN
    dmax = 0.0
    @inbounds for i in 1:n
        cdf_emp_sup = i / n
        cdf_emp_inf = (i - 1) / n
        cdf_mod = 1 - (xmin / cola[i])^alpha
        dmax = max(dmax, abs(cdf_emp_sup - cdf_mod), abs(cdf_emp_inf - cdf_mod))
    end
    return dmax
end

"""Búsqueda de `xmin` al estilo Clauset-Shalizi-Newman (2009): minimiza el KS sobre la
rejilla de valores únicos observados, exigiendo una cola de al menos `min_cola` puntos
para que la MLE sea estable. Devuelve (xmin, alpha, ks, n_cola)."""
function buscar_xmin(x::Vector{Float64}; min_cola::Int = 50)
    candidatos = sort(unique(x))
    mejor = (xmin = candidatos[1], alpha = NaN, ks = Inf, n_cola = 0)
    for xm in candidatos
        alpha, n_cola = mle_pareto(x, xm)
        n_cola < min_cola && continue
        isnan(alpha) && continue
        ks = ks_pareto(x, xm, alpha)
        if ks < mejor.ks
            mejor = (xmin = xm, alpha = alpha, ks = ks, n_cola = n_cola)
        end
    end
    return mejor
end

# ---------------------------------------------------------------------------
# 3. Bootstrap no paramétrico (réplica por semilla derivada, reducción determinista)
# ---------------------------------------------------------------------------

"""Bootstrap no paramétrico de `alpha_hat` sobre la cola `x .>= xmin`, remuestreo con
reemplazo de la MISMA cola (tamaño fijo = tamaño de la cola observada). `nrep` réplicas,
semilla fija. Devuelve el vector de réplicas (para IC percentil 2,5%-97,5%)."""
function bootstrap_alpha(x::Vector{Float64}, xmin::Float64, nrep::Int, semilla::UInt64)
    cola = filter(>=(xmin), x)
    n = length(cola)
    rng = Xoshiro(semilla)  # Base.Random, Julia >=1.7; determinista para esta versión de Julia
    reps = Vector{Float64}(undef, nrep)
    idx = Vector{Int}(undef, n)
    for r in 1:nrep
        for i in 1:n
            idx[i] = rand(rng, 1:n)
        end
        muestra = cola[idx]
        s = sum(log.(muestra ./ xmin))
        reps[r] = s > 0 ? n / s : NaN
    end
    return reps
end

function ic_percentil(reps::Vector{Float64}, p::Float64 = 0.025)
    limpio = filter(!isnan, reps)
    isempty(limpio) && return (NaN, NaN)
    q = sort(limpio)
    lo = quantile(q, p)
    hi = quantile(q, 1 - p)
    return (lo, hi)
end

# ---------------------------------------------------------------------------
# 4. B(ε) — fórmula EXACTA de DS3/src/modelo.jl líneas 139-148 (rama F_max=Inf)
# ---------------------------------------------------------------------------

"""Reproduce DS3.masa_espacio_bajo_b con F_max=∞ (el valor por defecto que usa DS-3).
Requiere dist_alpha > 2: para dist_alpha <= 2 la Pareto NO truncada tiene E[f] infinito y la
fórmula no está definida (DS-3 no cubre este caso; aquí se devuelve NaN explícito, no un
número inventado)."""
function B_eps(dist_alpha::Float64; eps_saldo::Float64 = 0.01, lambda::Float64 = 1.0,
               Tv::Float64 = 3600.0, fmin::Float64 = 1e-8)
    dist_alpha <= 2 && return NaN  # divergente / fuera de dominio, como en DS3
    x = eps_saldo / (lambda * Tv)
    x <= fmin && return 0.0
    return 1 - (fmin / x)^(dist_alpha - 2)
end

"""Generalización TRUNCADA (`F_max` finito) de la misma cantidad — la fórmula general de
P-CLAVE (`masa_prob`, rama no-Inf, MODELO §2.4) que sí está definida para cualquier
`dist_alpha != 2`, incluido `dist_alpha <= 2` (el régimen que los datos reales sugieren).
Con `F_max=1` (el truncamiento que declara H3 en MODELO §3: "Pareto truncada [1e-8,1]")."""
function B_eps_truncada(dist_alpha::Float64; eps_saldo::Float64 = 0.01, lambda::Float64 = 1.0,
                         Tv::Float64 = 3600.0, fmin::Float64 = 1e-8, Fmax::Float64 = 1.0)
    isapprox(dist_alpha, 2.0; atol = 1e-9) && return NaN
    x = eps_saldo / (lambda * Tv)
    x <= fmin && return 0.0
    x = min(x, Fmax)
    b = 2 - dist_alpha
    return (x^b - fmin^b) / (Fmax^b - fmin^b)
end

# ---------------------------------------------------------------------------
# 5. Programa principal
# ---------------------------------------------------------------------------

function main()
    mkpath(RUTA_OUT)
    t0 = time()

    filas_crudas = cargar_csv(RUTA_CSV)
    filas = deduplicar(filas_crudas)
    n_dup = length(filas_crudas) - length(filas)
    n_cero = count(f -> f.puntos == 0, filas)
    filas_pos = filter(f -> f.puntos > 0, filas)

    puntos = Float64.([f.puntos for f in filas_pos])
    sort!(puntos)

    println("=== DS-6 · Chia SpaceFarmers.io (pool), 2026-09-26 ===")
    @printf("Filas crudas: %d | duplicados por página frontera: %d | ceros excluidos: %d | n final: %d\n",
            length(filas_crudas), n_dup, n_cero, length(puntos))
    @printf("rango de 'points': [%d, %d]  (razón max/min = %.3g)\n",
            Int(minimum(puntos)), Int(maximum(puntos)), maximum(puntos)/minimum(puntos))

    # --- 5.0 Autocomprobación: reproducir el checkpoint publicado de DS-3 ---
    chk = B_eps(2.2)  # debe dar 0.675466 (DS3/resultados/comprobaciones.csv, caso §4.4)
    @printf("\nAutocomprobación B(eps=0.01,Tv=3600,dist_alpha=2.2) = %.6f (DS-3 publicó 0.675466)\n", chk)
    @assert isapprox(chk, 0.675466; atol = 1e-5) "la fórmula de B(ε) no reproduce el checkpoint de DS-3"

    # --- 5.1 MLE global (todo el rango observado, xmin = mínimo) ---
    xmin_global = minimum(puntos)
    alpha_global, n_global = mle_pareto(puntos, xmin_global)
    ks_global = ks_pareto(puntos, xmin_global, alpha_global)
    reps_global = bootstrap_alpha(puntos, xmin_global, N_BOOT, SEMILLA)
    lo_g, hi_g = ic_percentil(reps_global)

    @printf("\n[Ajuste GLOBAL, xmin=min observado=%d, cubre TODO el rango, n=%d]\n", Int(xmin_global), n_global)
    @printf("  dist_alpha_hat = %.4f   IC 95%% bootstrap = [%.4f, %.4f]   KS = %.4f\n",
            alpha_global, lo_g, hi_g, ks_global)

    # --- 5.2 Búsqueda de xmin al estilo Clauset (solo la cola que mejor ajusta una Pareto) ---
    mejor = buscar_xmin(puntos; min_cola = 50)
    reps_tail = bootstrap_alpha(puntos, mejor.xmin, N_BOOT, SEMILLA ⊻ UInt64(1))
    lo_t, hi_t = ic_percentil(reps_tail)

    @printf("\n[Ajuste de COLA óptima (Clauset-Shalizi-Newman), xmin=%.0f, n_cola=%d de %d]\n",
            mejor.xmin, mejor.n_cola, n_global)
    @printf("  dist_alpha_hat = %.4f   IC 95%% bootstrap = [%.4f, %.4f]   KS = %.4f\n",
            mejor.alpha, lo_t, hi_t, mejor.ks)

    @printf("\n[Traducción con la fórmula NO truncada de DS-3 (F_max=∞, requiere dist_alpha>2)]\n")
    @printf("  global (alpha=%.4f):      B(eps) = %s (fuera de dominio si NaN)\n", alpha_global, string(B_eps(alpha_global)))
    @printf("  cola óptima (alpha=%.4f): B(eps) = %s\n", mejor.alpha, string(B_eps(mejor.alpha)))
    @printf("\n[Traducción con la fórmula TRUNCADA F_max=1 (P-CLAVE MODELO §2.4, generalización)]\n")
    @printf("  global (alpha=%.4f):      B(eps) = %.6g\n", alpha_global, B_eps_truncada(alpha_global))
    @printf("  cola óptima (alpha=%.4f): B(eps) = %.6g\n", mejor.alpha, B_eps_truncada(mejor.alpha))

    # --- 5.3 Traducción a B(ε) y al criterio de grieta de DS-3 (§4.4: B(ε) > 1-2*alpha_atacante) ---
    escenarios_alpha = [
        ("global",      alpha_global, lo_g, hi_g),
        ("cola_optima", mejor.alpha,  lo_t, hi_t),
    ]
    atacante_grid = [0.20, 0.25, 0.33, 0.40]
    Tv_grid = [3600.0, 100000.0]

    open(joinpath(RUTA_OUT, "traduccion-grieta.csv"), "w") do io
        println(io, "ajuste,formula,dist_alpha_punto,dist_alpha_ic_lo,dist_alpha_ic_hi,Tv,alpha_atacante,B_eps_punto,B_eps_ic_lo,B_eps_ic_hi,umbral_1_menos_2alpha,grieta_punto,grieta_ic_lo,grieta_ic_hi")
        for (nombre, a, lo, hi) in escenarios_alpha, Tv in Tv_grid, aat in atacante_grid
            umbral = 1 - 2 * aat
            for (etiqueta_formula, f) in (("no_truncada_DS3", B_eps), ("truncada_F1_PCLAVE", B_eps_truncada))
                b_p  = f(a;  Tv = Tv)
                b_lo = f(lo; Tv = Tv)
                b_hi = f(hi; Tv = Tv)
                g_p  = isnan(b_p)  ? "NC" : (b_p  > umbral ? "SI" : "NO")
                g_lo = isnan(b_lo) ? "NC" : (b_lo > umbral ? "SI" : "NO")
                g_hi = isnan(b_hi) ? "NC" : (b_hi > umbral ? "SI" : "NO")
                @printf(io, "%s,%s,%.4f,%.4f,%.4f,%.0f,%.2f,%.6f,%.6f,%.6f,%.4f,%s,%s,%s\n",
                        nombre, etiqueta_formula, a, lo, hi, Tv, aat, b_p, b_lo, b_hi, umbral, g_p, g_lo, g_hi)
            end
        end
    end

    # --- 5.4 Guardar resultados ---
    open(joinpath(RUTA_OUT, "resumen-ajuste.csv"), "w") do io
        println(io, "ajuste,xmin,n_cola,dist_alpha_hat,ic95_lo,ic95_hi,ks")
        @printf(io, "global,%d,%d,%.4f,%.4f,%.4f,%.4f\n", Int(xmin_global), n_global, alpha_global, lo_g, hi_g, ks_global)
        @printf(io, "cola_optima,%.0f,%d,%.4f,%.4f,%.4f,%.4f\n", mejor.xmin, mejor.n_cola, mejor.alpha, lo_t, hi_t, mejor.ks)
    end

    open(joinpath(RUTA_OUT, "muestra-limpia.csv"), "w") do io
        println(io, "launcher_id,points,tib")
        for f in filas_pos
            @printf(io, "%s,%d,%.6f\n", f.launcher_id, f.puntos, f.tib)
        end
    end

    t1 = time()
    @printf("\nTiempo total (1 hilo, sin optimización dedicada — n≈%d no lo requiere): %.3f s\n", n_global, t1 - t0)
    println("Salidas: resultados/resumen-ajuste.csv, resultados/traduccion-grieta.csv, resultados/muestra-limpia.csv")
end

main()
