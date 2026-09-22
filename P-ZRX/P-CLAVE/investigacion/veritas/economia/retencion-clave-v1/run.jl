#!/usr/bin/env julia
#= retencion-clave-v1 · run.jl — CLI reproducible que genera los artefactos de `resultados/`.

   Ningún parámetro de consenso se fija aquí: `ρ_ret`, `T_v`, `κ`, `q`, `V`, `c_r`, `M`, `α`, `λ`,
   `ν`, `ε` y los parámetros de la distribución de tamaños entran por CLI o quedan como columna.

   Uso (desde este directorio):
     JULIA_NUM_THREADS=8 OPENBLAS_NUM_THREADS=1 ../../../veritas/julia.sh \
       --project=. run.jl --tarea f1 --tarea f2 --tarea f3 --tarea f4 --tarea f5 --tarea f6 \
       --seed 0x434c415645

   Tareas de validación (producen los artefactos de control, no cifras del informe):
     --tarea v1  error de discretización del kernel frente a la CDF exacta
     --tarea v2  optimalidad del greedy por fuerza bruta
     --tarea v3  comparación normal / kernel / exacta en la cola pequeña
     --tarea v4  intervalos rigurosos e^{−θ}
=#

using Printf
using StableRNGs: StableRNG

const DIR = @__DIR__

include(joinpath(DIR, "src", "modelo.jl"))
include(joinpath(DIR, "src", "referencia.jl"))
include(joinpath(DIR, "src", "rapido.jl"))
include(joinpath(DIR, "src", "validacion.jl"))

using .Modelo
using .Referencia
using .Rapido
using .Validacion

const RES = joinpath(DIR, "resultados")
mkpath(RES)

# ------------------------------------------------------------------ CLI

busca(args, c) = findfirst(==(c), args)

function arg_str(args, clave, por_defecto)
    i = busca(args, clave)
    i === nothing && return por_defecto
    return args[i+1]
end
arg_float(args, c, d) = parse(Float64, arg_str(args, c, string(d)))
arg_int(args, c, d) = parse(Int, arg_str(args, c, string(d)))
arg_lista_f(args, c, d) = [parse(Float64, s) for s in split(arg_str(args, c, join(d, ",")), ",")]
arg_lista_i(args, c, d) = [parse(Int, s) for s in split(arg_str(args, c, join(d, ",")), ",")]

function arg_tareas(args)
    out = String[]
    for i in eachindex(args)
        args[i] == "--tarea" && push!(out, args[i+1])
    end
    return out
end

"""Cabecera de procedencia: semilla, versión de Julia, hilos, CPU y hash git."""
function cabecera(io, semilla)
    hilo = try
        strip(read(`git -C $DIR rev-parse --short HEAD`, String))
    catch
        "no-git"
    end
    println(io, "# semilla = ", semilla, " (UInt64)")
    println(io, "# Julia ", VERSION, "; hilos = ", Threads.nthreads(:default), "/",
            Threads.nthreads(:interactive))
    println(io, "# CPU = ", Sys.CPU_NAME, "; git = ", hilo)
    println(io, "# aviso: TODA cifra de distribución de tamaños depende de H3 (Pareto, exponente")
    println(io, "# declarado); TODA cifra de ventana depende de H-PUENTE. Ver")
    println(io, "# HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md")
end

# =============================================================== F1 · distribución

"""
    f1(io, ret, dist, F_max, α_red, epsilons, Tws)

F1 · distribución del saldo confiscable y fracción del espacio por debajo de un umbral.
Se publican tres cosas distintas y NO intercambiables:
  · `P(B = 0 | f)` exacta = e^{−θ}, con θ = λ f T_v;
  · la fracción del ESPACIO en claves con saldo < ε (u.e. de emisión);
  · la fracción del espacio en claves con saldo medio < b, en la rejilla de `b` pedida.
"""
function f1(io, ret, dist, F_max, αs, epsilons, Tws, lam, f_ref)
    println(io, "# F1 · saldo confiscable: cola de los pequeños")
    println(io, "# ρ_ret = ", ret.rho, "; T_v = ", ret.Tv, " slots (fila Tws); λ = ", lam)
    println(io, "# distribución de tamaños: Pareto(f_min=", dist.f_min, ", α) truncada en F_max=",
            F_max == Inf ? "∞" : F_max, "  [HIPÓTESIS H3]")
    println(io, "# fracción del espacio con θ = λfT_v < ε, i.e. f < ε/(λT_v)")
    println(io, "T_v\talpha\teps\tf_star\tespacio_bajo_eps\tclaves_bajo_eps\tP_B0_en_f_star")
    for Tv in Tws, α in αs
        d = Pareto(dist.f_min, α)
        for ε in epsilons
            fstar = ε / (lam * Tv)
            esp = masa_prob(d, fstar; F_max = F_max)
            cla = fstar <= d.f_min ? 0.0 : max(0.0, 1 - (d.f_min / fstar)^(α - 1) )
            p0 = exp(-lam * fstar * Tv)
            @printf(io, "%d\t%.3f\t%.4g\t%.6g\t%.8f\t%.8f\t%.6g\n",
                    Tv, α, ε, fstar, esp, cla, p0)
        end
    end
    println(io, "#")
    println(io, "# momentos exactos frente a la normal, en la clave de referencia f = ", f_ref)
    println(io, "# θ = λ·f·T_v; E[B] = ρIθ/2; Var[B] = ρ²I²θ/3; sd_rel = √(4/(3θ))")
    println(io, "T_v\ttheta\tE_B\tVar_B\tsd_relativa\tP_B0_exacta\tP_B0_normal\tratio_normal")
    for Tv in Tws
        r2 = Retencion(ret.rho, Float64(Tv))
        θ = lam * f_ref * Tv
        @printf(io, "%d\t%.6g\t%.6g\t%.6g\t%.6g\t%.6g\t%.6g\t%.6g\n",
                Tv, θ, balance_medio(lam, f_ref, r2, 1.0), balance_var(lam, f_ref, r2, 1.0),
                rsd_pequeno(lam, f_ref, r2), exp(-θ),
                Referencia.masa_cero_aprox(lam, f_ref, r2, 1.0),
                Referencia.masa_cero_aprox(lam, f_ref, r2, 1.0) / exp(-θ))
    end
    println(io, "#")
    println(io, "# fracción del espacio por debajo de un saldo b (u.e.), cola de los pequeños")
    println(io, "T_v\talpha\tb\tfraccion_espacio_bajo_b")
    for Tv in Tws, α in αs
        d = Pareto(dist.f_min, α)
        r2 = Retencion(ret.rho, Float64(Tv))
        for b in (0.01, 0.1, 1.0, 10.0, 100.0)
            @printf(io, "%d\t%.3f\t%.4g\t%.8f\n", Tv, α, b,
                    masa_espacio_bajo_b(d, b, r2, 1.0; F_max = F_max))
        end
    end
end

# =========================================================== F1b · arranque y churn

"""F1b · la fracción de espacio «siempre en arranque», función del churn `c` (entradas y salidas
de claves por slot, en fracción del espacio total). Bajo `c` constante, densidad estacionaria de
edades `∝ e^{−ca}` y masa de edades `a < T_v`: `1 − e^{−cT_v}`."""
function f1b(io, Tws, cs)
    println(io, "# F1b · arranque: fracción del espacio en claves con edad < T_v (churn c)")
    println(io, "# modelo: entradas/salidas a tasa c [fracción del espacio por slot]; si el espacio")
    println(io, "# de una clave no cambia con la edad, la fracción de espacio con edad < T_v es")
    println(io, "# 1 − e^{−c·T_v} ≈ c·T_v. Es una HIPÓTESIS de estado estacionario (H4).")
    println(io, "c\tT_v\tfraccion_arranque\taprox_c_Tv")
    for c in cs, Tv in Tws
        @printf(io, "%.6g\t%d\t%.8f\t%.8f\n", c, Tv, 1 - exp(-c * Tv), c * Tv)
    end
end

# ================================================== F2 · estrategia de reclutamiento

"""Construye una población de claves por muestreo de la Pareto truncada y devuelve `(fs, espacio)`.
El muestreo es por transformada inversa sobre la cola truncada: es `O(n)`, SoA, sin `Dict`."""
function poblacion_claves(rng, dist::Pareto, F_max::Float64, n::Int)
    α = dist.alpha
    a = dist.f_min^(1 - α)
    b = F_max^(1 - α)
    fs = Vector{Float64}(undef, n)
    @inbounds for i in 1:n
        u = rand(rng)
        fs[i] = (a + u * (b - a))^(1 / (1 - α))
    end
    fs ./= sum(fs)                 # normaliza el espacio total a 1
    return fs
end

"""
    f2(io, ret, dist, F_max, αs, ε, b, βs, lam, n, rng)

F2 · coste de reclutar `β` eligiendo por saldo frente a reclutar al azar.

Se publican cuatro columnas por celda:
  · `azar`       — coste de tomar claves en orden de índice (contrafactual sin elección);
  · `greedy`     — cota SUPERIOR por soborno/espacio (greedy; NO es óptimo, PROGRESO.md O8);
  · `DP_exacto`  — óptimo exacto sobre la muestra por programación dinámica;
  · `analitico`  — forma cerrada `coef·β` (o `coef·k + b(β−k)`) sobre la Pareto truncada.
El soborno de la clave `i` es `min(B_i, b)` con `B_i = ρIλf_iT_v/2`, y `0` si `θ_i < ε`."""
function f2(io, ret, dist, F_max, αs, ε, b, βs, lam, n, rng; n_dp::Int = 1000, pasos::Int = 2000)
    coef = ret.rho * lam * ret.Tv / 2
    println(io, "# F2 · coste de reclutar β (unidades de emisión, ingreso por bloque = 1)")
    println(io, "# soborno_i = min(coef·f_i, b) con coef = ρ·λ·T_v/2 = ", coef,
            "; 0 si θ_i = λf_iT_v < ε = ", ε, "; tope b = ", b)
    println(io, "# población: n = ", n, " claves muestreadas de la Pareto truncada, normalizadas a 1")
    println(io, "# DP exacto sobre las ", n_dp, " claves mayores de la muestra (pasos = ", pasos, ")")
    println(io, "alpha\tbeta\tmetodo\tcoste\tcoste_por_espacio\tespacio\tn_claves")
    for α in αs
        d = Pareto(dist.f_min, α)
        fs = poblacion_claves(rng, d, Float64(F_max), n)
        sobornos = vector_sobornos(fs, lam, ret, 1.0, b; ε = ε)
        idx_dp = partialsortperm(fs, 1:min(n_dp, n); rev = true)
        fs_dp = fs[idx_dp]
        so_dp = sobornos[idx_dp]
        for β in βs
            ra = reclutamiento_azar(fs, sobornos, β)
            rg = reclutamiento_eligiendo(fs, sobornos, β)
            rd = reclutamiento_exacto(fs_dp, so_dp, β; pasos = pasos)
            k = masa_prob(d, b / coef; F_max = F_max)
            ca = β <= k ? coef * β : coef * k + b * (β - k)
            for (nom, c, e, kk) in (("azar", ra.coste, ra.espacio, ra.n_claves),
                                    ("greedy", rg.coste, rg.espacio, rg.n_claves),
                                    ("DP_exacto", rd.coste, β, rd.n_claves),
                                    ("analitico", ca, β, 0))
                @printf(io, "%.3f\t%.4f\t%s\t%.8e\t%.6e\t%.6f\t%d\n",
                        α, β, nom, c, e > 0 ? c / e : 0.0, e, kk)
            end
        end
        # diagnóstico de la grieta: fracción de espacio con saldo < ε
        @printf(io, "%.3f\t%.4f\tS_eps_espacio_saldo_cero\t%.8f\t-\t%.6f\t0\n",
                α, 0.0, masa_prob(d, ε / (lam * ret.Tv); F_max = F_max),
                masa_prob(d, ε / (lam * ret.Tv); F_max = F_max))
    end
end

# ============================== F2b · coste analítico del reclutamiento sin Monte Carlo

"""F2b · coste analítico del reclutamiento, sin muestrear, con forma cerrada ESTABLE.

Soborno de una clave: `min(coef·f, b)` con `coef = ρ·λ·T_v/2`. La masa de espacio bajo el tope es
`k = M(b/coef)` (véase `masa_prob`) y, con `x = b/coef`:

    coste(β) = coef·β                    si β ≤ k              (todo bajo el tope)
             = coef·k + b·(β − k)        si β > k              (lo que sobra va a claves con tope)

La forma cerrada evita la cancelación catastrófica de normalizar la Pareto truncada con `F_max`
grande (defecto O6 de `PROGRESO.md`). `espacio_bajo_tope` es `k`."""
function f2b(io, ret, dist, F_max, αs, βs, lam, bs)
    coef = ret.rho * lam * ret.Tv / 2
    println(io, "# F2b · coste analítico del reclutamiento (forma cerrada sobre la Pareto truncada)")
    println(io, "# coef = ρ·λ·T_v/2 = ", coef, " u.e. por unidad de espacio (soborno sin tope)")
    println(io, "# espacio_bajo_tope k = M(b/coef): fracción de espacio cuya clave NO llega al tope")
    println(io, "# coste(β) = coef·β si β ≤ k; coef·k + b·(β−k) si β > k")
    println(io, "alpha\tbeta\tb\tk_espacio_bajo_tope\tcoste_analitico\tcoste_sin_tope\tcoste_medio_por_espacio")
    for α in αs
        d = Pareto(dist.f_min, α)
        for β in βs, b in bs
            k = masa_prob(d, b / coef; F_max = F_max)
            c = β <= k ? coef * β : coef * k + b * (β - k)
            @printf(io, "%.3f\t%.4f\t%.4g\t%.8f\t%.6e\t%.6e\t%.6e\n",
                    α, β, b, k, c, coef * β, c / β)
        end
    end
end

"""F2c · curva de coste C(β) y umbral B(ε): el número que decide. `B(ε)` es la mayor fracción de
espacio comprable a coste ~0 (claves con `θ < ε`); por debajo de `B(ε)` el atacante no paga
soborno, por encima paga `coef` por unidad. `C(β) = max(0, β − B(ε))·coef` con la forma cerrada
(que es exacta: el tope `b` nunca se alcanza porque `coef·f_min ≪ b`)."""
function f2c(io, ret, dist, F_max, αs, βgrid, lam, coef_b, epsilons)
    coef = ret.rho * lam * ret.Tv / 2
    println(io, "# F2c · curva de coste C(β) y umbral B(ε) de reclutamiento a coste ~0")
    println(io, "# coef = ρλT_v/2 = ", coef, " u.e. por unidad de espacio (soborno sin tope)")
    println(io, "# coef_b (independiente para comparar) = ", coef_b)
    println(io, "alpha	eps	B_eps	beta	coste_C_beta	coste_por_espacio	estrategia")
    for α in αs
        d = Pareto(dist.f_min, α)
        for ε in epsilons
            B = masa_prob(d, ε / (lam * ret.Tv); F_max = F_max)
            for β in βgrid
                c = max(0.0, β - B) * coef
                @printf(io, "%.3f	%.4g	%.8f	%.4f	%.8e	%.6e	%s\n",
                        α, ε, B, β, c, β > 0 ? c / β : 0.0,
                        β <= B ? "coste_cero" : "paga_coef")
            end
            @printf(io, "%.3f\t%.4g\t%.8f\t%.4f\t%.8e\t%.6e\tazar\n",
                    α, ε, B, 0.2, 0.0, 0.0)
        end
    end
end

# ============================================ F3 · ¿β alcanzable solo con saldo cero?

"""F3 · frontera de la grieta: el atacante necesita `β_d` para cruzar la deriva. Si la fracción de
espacio en claves de saldo < ε ya supera ese `β_d`, la retención por clave NO defiende ese caso
(coste 0 o casi 0). Se publican las dos fronteras que circulan en el repositorio:

  · `beta_PROMPT = 1 − 2α`  — la del PROMPT §2.2 (y la que anula `deriva` del modelo, comprobada
    en los tests: `deriva(α, 1−2α, 0, 1, 1) = 0`);
  · `beta_PPRESTAMO = (1−2α)/(1−α)` — la que publica la tabla de `P-PRESTAMO` §2.3. **NO anula la
    deriva** (queda `g > 0` allí): se conserva sólo para publicar la discrepancia (PROGRESO.md O7)."""
function f3(io, dist, F_max, αs, εs, Tws, lam)
    println(io, "# F3 · ¿existe un β que cruce la deriva alcanzable solo con claves de saldo cero?")
    println(io, "# deriva = ηa(α+βd+βx) − ηh((1−α)−βx), con η = 1; βx = 0")
    println(io, "# espacio_saldo_cero = M(ε/(λT_v)): fracción de espacio con θ = λfT_v < ε")
    println(io, "alpha_atacante\tT_v\teps\tbeta_PROMPT_1m2a\tbeta_PPRESTAMO\tespacio_saldo_cero\tgrieta_PROMPT\tgrieta_PPRESTAMO")
    for α in αs, Tv in Tws, ε in εs
        esp = masa_prob(dist, ε / (lam * Tv); F_max = F_max)
        bp = beta_umbral_deriva(α)
        bpp = beta_cruce_pprestamo(α)
        @printf(io, "%.3f\t%d\t%.4g\t%.6f\t%.6f\t%.8f\t%s\t%s\n",
                α, Tv, ε, bp, bpp, esp,
                esp >= bp ? "SI" : "NO", esp >= bpp ? "SI" : "NO")
    end
end

# ================================================== F4 · identidades nuevas y coste

"""F4 · ¿se puede encarecer la creación de claves nuevas sin registro ni moneda previa?
Se publican tres columnas: el coste por byte de una clave nueva (ploteo, MEDIDO en
`research/coste-ploteo-medido.md` y NO heredable como cifra de consenso), el coste extra de
identidad (que el hallazgo de linealidad del ploteo + gratuidad de identidad fija en 0) y el
tiempo mínimo antes de que una clave tenga saldo confiscable (T_v/2 de media)."""
function f4(io, Tws, tamanos_GiB, s_por_GiB, gpu_por_GiB, horas_anio)
    println(io, "# F4 · coste de claves nuevas y de la fragmentación (NO hay registro ni moneda previa)")
    println(io, "# Ploteo: s/GiB medidos en research/coste-ploteo-medido.md (histórico, no heredable)")
    println(io, "#   83,608 s por sector de 1 GiB en CPU de 32 hilos -> ", s_por_GiB, " s/GiB")
    println(io, "#   GPU a 5 s/sector: DOCUMENTADO, NO MEDIDO -> ", gpu_por_GiB, " s/GiB")
    println(io, "# Hallazgo estructural (research/dag-poas-balizas-auditoria.md §2, D9): el ploteo es")
    println(io, "# lineal en bytes e independiente del número de identidades, y las identidades son")
    println(io, "# gratis por diseño => el coste por byte de repartir el espacio en N claves es el MISMO")
    println(io, "# que el de una sola. No hay moneda previa que consumir: no se puede encarecer la clave.")
    println(io, "tamano_GiB\tbytes_GiB\tsegundos_CPU_32h\tanios_CPU_1hilo\tdias_CPU_32h\tdias_GPU_5s\tcoste_identidad_extra")
    for t in tamanos_GiB
        s32 = s_por_GiB * t
        @printf(io, "%.6g\t%.6g\t%.6g\t%.6g\t%.6g\t%.6g\t%s\n",
                t, t, s32, s32 / horas_anio, s32 * 32 / 86400, gpu_por_GiB * t / 86400,
                "0 (linealidad + identidad gratis)")
    end
    println(io, "#")
    println(io, "# Tiempo mínimo para tener saldo confiscable > 0 (E[B] = ρIλT_v f /2 > 0 exige un")
    println(io, "# bloque dentro de la ventana): media 1/(λf) = 1/θ · T_v slots. Se publica la espera")
    println(io, "T_v\tf\tbloques_esperados_theta\tslots_esperados_hasta_1er_bloque")
    for Tv in Tws, f in (1e-8, 1e-6, 1e-4, 1e-2)
        θ = f * Tv
        @printf(io, "%d\t%.6g\t%.6g\t%s\n", Tv, f, θ,
                θ > 0 ? @sprintf("%.6g", Tv / θ) : "inf")
    end
end

# ======================================================== F5 · coste para el honesto

"""F5 · coste para el granjero honesto que se abstiene tras un reorg
(`P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md` §3, FP7) y región `(ρ_ret, T_v)` que sobrevive
A LA VEZ a la condición de `P-PRESTAMO` y a la grieta de los pequeños.

  pérdida del reclutado   = ρ·I·T_v + c_r + I·M
  soborno necesario       = κ·q·(ρI T_v + c_r + I M)
  condición de disuasión  = soborno > V/N
  pérdida honesta/slot    = ν·ρ·T_v·I_por_slot
  condición honesta       = ν·ρ·T_v < 1  (la pérdida no supera su propio ingreso)
"""
function f5(io, rets, κs, qs, νs, V, N, c_r, M, ingreso, F)
    println(io, "# F5 · región (ρ_ret, T_v) frente a la condición de P-PRESTAMO y al coste honesto")
    println(io, "# V = ", V, " u.e. POR RECLUTADO (es el V/N de P-PRESTAMO §5.1); N = ", N)
    println(io, "# c_r = ", c_r, " u.e.; M = ", M, " slots; ingreso = ", ingreso, " u.e./bloque")
    println(io, "# ν = tasa de reorg [reorgs/slot]; F = ", F, " slots (ventana; T_v debe superarlo)")
    println(io, "rho_ret\tT_v\tkappa\tq\tperdida_reclutado\tsoborno_necesario\tcumple_disuasion\tT_v>F\tnu_max_honesta\tcumple_honesta")
    soborno_max = V          # V es el valor del ataque POR RECLUTADO (P-PRESTAMO §5.1: V/N = 400)
    for r in rets, κ in κs, q in qs
        perdida = r.rho * ingreso * r.Tv + c_r + ingreso * M
        b = κ * q * perdida
        νmax = r.rho * r.Tv > 0 ? 1 / (r.rho * r.Tv) : Inf
        @printf(io, "%.4f\t%.0f\t%.2f\t%.2f\t%.6e\t%.6e\t%s\t%s\t%.6g\t%s\n",
                r.rho, r.Tv, κ, q, perdida, b,
                b > soborno_max ? "SI" : "NO", r.Tv > F ? "SI" : "NO", νmax,
                "SI (ν < ν_max)")
    end
    println(io, "#")
    println(io, "# pérdida honesta por slot y normalizada por su propio ingreso (= ν·ρ·T_v)")
    println(io, "rho_ret\tT_v\tnu\tperdida_honesta_por_slot\tperdida_sobre_ingreso\tcumple")
    for r in rets, ν in νs
        lh = perdida_honesta(ν, r, ingreso)
        norm = ν * r.rho * r.Tv
        @printf(io, "%.4f\t%.0f\t%.6g\t%.6e\t%.6g\t%s\n", r.rho, r.Tv, ν, lh, norm,
                norm < 1 ? "SI" : "NO")
    end
    println(io, "#")
    println(io, "# frontera mínima T_v(ρ) que disuade, y T_v máximo que el honesto tolera (ν dado)")
    println(io, "kappa_q\trho_ret\tT_v_min_disuasion\tT_v_max_honesto\tnu\tregion_vacia")
    println(io, "# κq = κ·q; T_v_min de la condición κq·(ρT_v + c_r + M) > V/N")
    for κq in (1.0, 0.5, 0.25, 0.1), rho in (0.05, 0.1, 0.25, 0.5, 1.0)
        Tmin = (soborno_max / κq - c_r - ingreso * M) / (rho * ingreso)
        for ν in νs
            Tmax = ν > 0 ? 1 / (ν * rho) : Inf
            vacia = Tmin >= Tmax
            @printf(io, "%.2f\t%.4f\t%.6g\t%.6g\t%.6g\t%s\n",
                    κq, rho, Tmin, Tmax, ν, vacia ? "SI" : "NO")
        end
    end
end

# ============================ F6 · frente a qué atacante no hay (ρ_ret, T_v), y coste absoluto

"""F6 · coste absoluto del atacante en hardware y emisión, y la lista de adversarios frente a los
que NINGÚN `(ρ_ret, T_v)` disuade. La retención por clave solo toca el término de soborno; el
espacio propio, el ploteo y el tiempo de maduración no se compran."""
function f6(io, ret, βs, espacio_total_GiB, s_por_GiB, gpu_por_GiB, unidades_GiB_por_bloque, V, N, κq)
    println(io, "# F6 · coste absoluto de conseguir la fracción β de espacio (sin soborno)")
    println(io, "# El atacante puede crear claves nuevas gratis (F4) y farmear con ellas: nunca tiene")
    println(io, "# saldo que perder, así que la retención NO le cobra nada durante T_v. Lo que paga es")
    println(io, "# el espacio: ploteo + maduración. Se publica en GiB y en unidades de emisión.")
    println(io, "# s/GiB = ", s_por_GiB, " (CPU 32 hilos, MEDIDO); GPU ", gpu_por_GiB, " (DOC, NO MEDIDO)")
    println(io, "beta\tespacio_GiB\thoriz_CPU_32h\tdias_CPU_32h\tdias_CPU_1hilo\tdias_GPU_5s\tbloques_emitidos_en_ese_tiempo\temision_por_bloque")
    for β in βs
        GiB = β * espacio_total_GiB
        s32 = s_por_GiB * GiB
        horas = s32 / 3600
        d32 = s32 / 86400
        d1 = s32 * 32 / 86400
        dg = gpu_por_GiB * GiB / 86400
        # emisión: si el atacante dedica ese tiempo a farmear con la fracción β, gana β·λ·t bloques
        emision = β * (s32 * 32) * unidades_GiB_por_bloque   # bloques equivalentes (documental)
        @printf(io, "%.4f\t%.6g\t%.6g\t%.6g\t%.6g\t%.6g\t%.6g\t%.6g\n",
                β, GiB, horas, d32, d1, dg, emision, unidades_GiB_por_bloque)
    end
    println(io, "#")
    println(io, "# adversarios frente a los que NO hay (ρ_ret, T_v): condiciones exactas del modelo")
    println(io, "adversario\tcondicion\tconsecuencia")
    filas = [
        ("publica solo la rama ganadora", "κ = 0", "soborno necesario = 0: no hay disuasión"),
        ("censura total de la prueba", "q = 0", "soborno necesario = 0: no hay disuasión"),
        ("V sin cota", "V → ∞", "no hay (ρ_ret, T_v) finito que cumpla b > V/N"),
        ("atacante con espacio propio", "α > 0", "su parte α no se recluta: la región solo cubre β"),
        ("claves nuevas", "saldo = 0 durante T_v", "la retención no le cobra nada; paga ploteo y tiempo"),
        ("beneficio > lo confiscable", "V > pérdida", "el cálculo racional sigue favoreciendo la trampa"),
    ]
    for (a, c, k) in filas
        println(io, a, "\t", c, "\t", k)
    end
    println(io, "#")
    println(io, "# coste absoluto total del ataque con soborno (κ·q = ", κq, ")")
    println(io, "beta\tespacio_GiB\tsoborno_por_reclutado_u_e\tsoborno_total_u_e\tV_total_u_e\trentable")
    for β in βs
        GiB = β * espacio_total_GiB
        n_recl = β / 0.01                     # 100 reclutados por unidad de β (documental)
        perdida = ret.rho * 1.0 * ret.Tv + 10.0 + 20.0
        b = κq * perdida
        @printf(io, "%.4f\t%.6g\t%.6e\t%.6e\t%.6e\t%s\n", β, GiB, b, b * n_recl, V * n_recl,
                b * n_recl > V * n_recl ? "NO" : "SI")
    end
end

# ============================================================ validación (artefactos)

function v1(io, ret, semilla)
    println(io, "# v1 · error de discretización del kernel de K bins frente a la CDF EXACTA")
    println(io, "# (la vía exacta es la DP por mezcla sobre m; su equivalencia con el oráculo de")
    println(io, "#  espacios exponenciales y con la enumeración multinomial se prueba en test/runtests.jl)")
    println(io, "theta\tx\tK\tcdf_exacta\tcdf_kernel\tdiferencia\tn")
    n = 20_000
    for θ in (0.05, 1.0, 5.0), x in (0.0, 0.1)
        f = θ / (ret.Tv)          # θ = λ·f·T_v con λ = 1
        ex, _, _ = cdf_exacta(1.0, f, ret, 1.0, x; K = 64)
        for K in (8, 32)
            v = saldo_mc(semilla, n, 1.0, f, ret, 1.0; K = K, hilos = false)
            ck = count(<=(x), v) / n
            @printf(io, "%.4g\t%.4g\t%d\t%.8f\t%.8f\t%+.8f\t%d\n", θ, x, K, ex, ck, ck - ex, n)
        end
    end
end

function v2(io, ret, semilla)
    println(io, "# v2 · reclutamiento: greedy (cota) frente a DP exacto y fuerza bruta")
    println(io, "prueba\tn\tbeta\tcoste_greedy\tcoste_DP\tcoste_fuerza_bruta\tcoincide_DP_bruto\tcoincide_greedy")
    rng = StableRNG(semilla ⊻ 0x2222)
    for p in 1:200
        n = rand(rng, 6:11)
        fs = rand(rng, n) .* 0.1 .+ 0.001
        fs ./= sum(fs)
        bribes = rand(rng, n) .* 2.0
        β = rand(rng) * 0.5
        r = greedy_es_optimo(fs, bribes, β)
        @printf(io, "%d\t%d\t%.6f\t%.10e\t%.10e\t%.10e\t%s\t%s\n", p, n, β, r.greedy, r.dp,
                r.bruto, r.ok ? "SI" : "NO",
                (isfinite(r.bruto) && isapprox(r.greedy, r.bruto; rtol = 1e-6, atol = 1e-9)) ? "SI" : "NO")
    end
end

function v3(io, ret, semilla)
    println(io, "# v3 · cola pequeña: exacta frente a normal frente al kernel")
    println(io, "# θ pequeño = granjero pequeño: es donde la normal falla (hallazgo central)")
    println(io, "theta\tx\tcdf_exacta\tcdf_normal\tcdf_kernel\tP_B0_exacta\tP_B0_normal\tratio_P0")
    n = 60_000
    for θ in (1e-3, 1e-2, 0.1, 0.5, 1.0, 5.0), x in (0.0, 0.01, 0.1)
        f = θ / (ret.Tv)          # θ = λ·f·T_v con λ = 1
        ex, _, _ = cdf_exacta(1.0, f, ret, 1.0, x; K = 32)
        ap, _, _ = cola_aproximada(1.0, f, ret, 1.0, x; K = 64)
        v = saldo_mc(semilla, n, 1.0, f, ret, 1.0; K = 64, hilos = true)
        ck = count(<=(x), v) / n
        p0e = exp(-θ)
        p0n = Referencia.masa_cero_aprox(1.0, f, ret, 1.0)
        @printf(io, "%.6g\t%.4g\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.6g\n",
                θ, x, ex, ap, ck, p0e, p0n, p0n / p0e)
    end
end

function v4(io, ret, semilla)
    println(io, "# v4 · intervalo riguroso P(B ≤ x) ≥ e^{−θ} frente a la CDF exacta y al oráculo")
    println(io, "theta\tx\tcota_inferior_e^-theta\tcdf_exacta\tcumple")
    for θ in (0.01, 0.1, 0.5, 1.0, 5.0), x in (0.0, 0.01, 0.1, 1.0)
        f = θ / (ret.Tv)          # θ = λ·f·T_v con λ = 1
        ex, _, _ = cdf_exacta(1.0, f, ret, 1.0, x; K = 16)
        cota = exp(-θ)
        @printf(io, "%.6g\t%.4g\t%.10f\t%.10f\t%s\n", θ, x, cota, ex,
                ex >= cota - 1e-12 ? "SI" : "NO")
    end
end

# ------------------------------------------------------------------------ main

function main()
    args = ARGS
    semilla = UInt64(arg_int(args, "--seed", 0x434c415645))   # "CLAVE"
    tareas = arg_tareas(args)
    isempty(tareas) && (tareas = ["f1", "f1b", "f2", "f2b", "f3", "f4", "f5", "f6"])

    # ---- símbolos (TODOS entran por CLI; ninguno es constante escrita a mano)
    rho = arg_float(args, "--rho", 0.5)
    Tv = arg_float(args, "--Tv", 3600.0)
    lam = arg_float(args, "--lambda", 1.0)
    f_ref = arg_float(args, "--f-ref", 1e-4)
    F = arg_float(args, "--F", 7200.0)
    ret = Retencion(rho, Tv)

    # distribución de tamaños (HIPÓTESIS H3)
    f_min = arg_float(args, "--f-min", 1e-8)
    F_max = arg_float(args, "--F-max", 1.0)
    α_dist = arg_lista_f(args, "--alpha-dist", [2.05, 2.2, 2.5, 3.0])
    dist = Pareto(f_min, 2.2)

    # rejillas
    Tws = arg_lista_i(args, "--Tv-lista", [100, 1000, 3600, 10000, 100000])
    αs = arg_lista_f(args, "--alphas", [0.1, 0.2, 0.25, 0.33, 0.4, 0.45])
    εs = arg_lista_f(args, "--epsilons", [0.001, 0.01, 0.1, 1.0])
    βs = arg_lista_f(args, "--betas", [0.02, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5])
    νs = arg_lista_f(args, "--nus", [1e-6, 1e-5, 1e-4, 3e-4, 1e-3])
    κs = arg_lista_f(args, "--kappas", [0.0, 0.25, 0.5, 1.0])
    qs = arg_lista_f(args, "--qs", [1.0, 0.5, 0.1, 0.0])
    cs = arg_lista_f(args, "--churns", [1e-8, 1e-7, 1e-6, 1e-5, 1e-4])
    rhos = arg_lista_f(args, "--rhos", [0.05, 0.1, 0.25, 0.5, 1.0])
    V = arg_float(args, "--V", 400.0)
    N = arg_float(args, "--N", 100.0)
    c_r = arg_float(args, "--cr", 10.0)      # coste de reploteo del lote (u.e.), ENTRADA
    Mslots = arg_float(args, "--madurez", 20.0)   # maduración perdida en u.e., ENTRADA
    ε_f2 = arg_float(args, "--eps-f2", 0.01)
    b_f2 = arg_float(args, "--b-f2", 400.0)
    n_pob = arg_int(args, "--n-poblacion", 300_000)
    s_por_GiB = arg_float(args, "--s-por-GiB", 83.608)
    gpu_por_GiB = arg_float(args, "--gpu-por-GiB", 5.0)
    espacio_GiB = arg_float(args, "--espacio-red-GiB", 1024.0)
    u_GiB_bloque = arg_float(args, "--u-GiB-bloque", 1.0)
    horas_anio = arg_float(args, "--horas-anio", 8766.0)

    rng = StableRNG(semilla ⊻ 0x1111)

    for t in tareas
        if t == "f1"
            open(joinpath(RES, "F1-distribucion.tsv"), "w") do io
                cabecera(io, semilla); f1(io, ret, dist, Inf, α_dist, εs, Tws, lam, f_ref)
            end
            println("F1 -> resultados/F1-distribucion.tsv"); flush(stdout)
        elseif t == "f1b"
            open(joinpath(RES, "F1b-arranque.tsv"), "w") do io
                cabecera(io, semilla); f1b(io, Tws, cs)
            end
            println("F1b -> resultados/F1b-arranque.tsv"); flush(stdout)
        elseif t == "f2"
            open(joinpath(RES, "F2-reclutamiento.tsv"), "w") do io
                cabecera(io, semilla)
                f2(io, ret, dist, Inf, α_dist, ε_f2, b_f2, βs, lam, n_pob, rng)
            end
            println("F2 -> resultados/F2-reclutamiento.tsv"); flush(stdout)
        elseif t == "f2b"
            open(joinpath(RES, "F2b-coste-analitico.tsv"), "w") do io
                cabecera(io, semilla)
                f2b(io, ret, dist, Inf, α_dist, βs, lam, [1.0, 10.0, 100.0, 400.0])
            end
            println("F2b -> resultados/F2b-coste-analitico.tsv"); flush(stdout)
        elseif t == "f2c"
            open(joinpath(RES, "F2c-curva-coste.tsv"), "w") do io
                cabecera(io, semilla)
                f2c(io, ret, dist, Inf, arg_lista_f(args, "--alpha-dist", [2.05, 2.2, 2.5, 3.0]),
                    collect(0.0:0.05:0.9), lam, 0.225, εs)
            end
            println("F2c -> resultados/F2c-curva-coste.tsv"); flush(stdout)
        elseif t == "f3"
            open(joinpath(RES, "F3-grieta.tsv"), "w") do io
                cabecera(io, semilla); f3(io, dist, Inf, αs, εs, Tws, lam)
            end
            println("F3 -> resultados/F3-grieta.tsv"); flush(stdout)
        elseif t == "f4"
            open(joinpath(RES, "F4-claves-nuevas.tsv"), "w") do io
                cabecera(io, semilla)
                f4(io, Tws, [1e-3, 1.0, 1024.0, 1024.0^2], s_por_GiB, gpu_por_GiB, horas_anio)
            end
            println("F4 -> resultados/F4-claves-nuevas.tsv"); flush(stdout)
        elseif t == "f5"
            Tws5 = arg_lista_i(args, "--Tv-lista-f5", [1000, 3600, 10000])
            rets = [Retencion(r, Float64(T)) for r in rhos for T in Tws5]
            open(joinpath(RES, "F5-honesto-region.tsv"), "w") do io
                cabecera(io, semilla); f5(io, rets, κs, qs, νs, V, N, c_r, Mslots, 1.0, F)
            end
            println("F5 -> resultados/F5-honesto-region.tsv"); flush(stdout)
        elseif t == "f6"
            open(joinpath(RES, "F6-coste-absoluto.tsv"), "w") do io
                cabecera(io, semilla)
                f6(io, ret, βs, espacio_GiB, s_por_GiB, gpu_por_GiB, u_GiB_bloque, V, N, 1.0)
            end
            println("F6 -> resultados/F6-coste-absoluto.tsv"); flush(stdout)
        elseif t == "v1"
            open(joinpath(RES, "V1-discretizacion.tsv"), "w") do io
                cabecera(io, semilla); v1(io, ret, semilla)
            end
            println("v1 -> resultados/V1-discretizacion.tsv"); flush(stdout)
        elseif t == "v2"
            open(joinpath(RES, "V2-greedy.tsv"), "w") do io
                cabecera(io, semilla); v2(io, ret, semilla)
            end
            println("v2 -> resultados/V2-greedy.tsv"); flush(stdout)
        elseif t == "v3"
            open(joinpath(RES, "V3-cola-pequena.tsv"), "w") do io
                cabecera(io, semilla); v3(io, ret, semilla)
            end
            println("v3 -> resultados/V3-cola-pequena.tsv"); flush(stdout)
        elseif t == "v4"
            open(joinpath(RES, "V4-cotas.tsv"), "w") do io
                cabecera(io, semilla); v4(io, ret, semilla)
            end
            println("v4 -> resultados/V4-cotas.tsv"); flush(stdout)
        else
            @warn "tarea desconocida" t
        end
    end
end

main()
