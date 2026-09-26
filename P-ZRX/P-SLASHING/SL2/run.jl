#!/usr/bin/env julia
# =============================================================================
# SL-2 · run.jl — Calibración del castigo: disuadir al que recluta sin castigar al honesto.
#
# Comando reproducible:
#   export PATH=/home/katana/torio/.juliaup/bin:$PATH
#   JULIA_DEPOT_PATH="$PWD/.julia-depot" JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     env -u LD_LIBRARY_PATH julia --project=. --threads=4,0 run.jl --seed 0x5a5a --reps 20000
#
# Presupuesto de la orden SL-2: 2 h, 4 hilos, 8 GiB de RAM. Si se agota: INCONCLUSO.
# =============================================================================

using SL2
using Printf
using Statistics

const DIR_RES = joinpath(@__DIR__, "resultados")
const DIR_DAT = joinpath(@__DIR__, "datos")
mkpath(DIR_RES)

# ───────────────────────────────────────────── CLI mínima y reproducible

function parsear_args(args)
    opciones = Dict{String,String}("seed" => "0x5a5a", "reps" => "20000",
                                   "escenarios" => joinpath(@__DIR__, "escenarios.tsv"),
                                   "datos" => joinpath(DIR_DAT, "farmers-raw.csv"),
                                   "rapido" => "false")
    i = 1
    while i <= length(args)
        a = args[i]
        if startswith(a, "--")
            clave = a[3:end]
            if i < length(args) && !startswith(args[i + 1], "--")
                opciones[clave] = args[i + 1]
                i += 2
            else
                opciones[clave] = "true"
                i += 1
            end
        else
            i += 1
        end
    end
    return opciones
end

const OPC = parsear_args(ARGS)
const SEMILLA = parse(UInt64, OPC["seed"] == "" ? "0x5a5a" : OPC["seed"])
const REPS = parse(Int, OPC["reps"])
const RAPIDO = lowercase(OPC["rapido"]) in ("true", "1", "si", "sí")

# ───────────────────────────────────────────── lectura de escenarios.tsv

"""
    leer_escenarios(ruta) -> (valores, barridos, filas)

Lee el TSV `clave, valor, unidad, etiqueta, procedencia, barrido`. `valores` es escalar;
`barridos` parsea la última columna (`;`-separada) cuando existe. Falla si falta una obligatoria.
"""
function leer_escenarios(ruta)
    valores = Dict{String,Float64}()
    textos = Dict{String,String}()
    barridos = Dict{String,Vector{Float64}}()
    filas = Vector{Vector{String}}()
    for linea in eachline(ruta)
        s = strip(linea)
        (isempty(s) || startswith(s, "#") || startswith(s, "clave\t")) && continue
        campos = split(linea, '\t')
        length(campos) < 6 && continue
        clave = String(campos[1])
        val = strip(campos[2])
        textos[clave] = val
        v = tryparse(Float64, val)
        v === nothing || (valores[clave] = v)
        grid = Float64[]
        for tok in split(strip(campos[6]), ';')
            t = strip(tok)
            isempty(t) && continue
            vv = tryparse(Float64, t)
            vv === nothing || push!(grid, vv)
        end
        isempty(grid) || (barridos[clave] = grid)
        push!(filas, [String(c) for c in campos[1:6]])
    end
    return valores, barridos, textos, filas
end

const ESC, GRID, TEXTOS, FILAS_ESC = leer_escenarios(OPC["escenarios"])
obligatorias = ["F_slots", "kappa", "q_ev", "I", "c_r", "lambda", "eps_saldo", "dist_f_min",
                "f_media_hipotesis", "frac_ingreso_max"]
for k in obligatorias
    haskey(ESC, k) || error("falta la clave de escenario `$k` en $(OPC["escenarios"])")
end
p(k) = ESC[k]
grid(k, def) = haskey(GRID, k) ? GRID[k] : def

# MEMOIZACIÓN de β_d(α, P*): la inversión por bisección cuesta ~16 ms y solo hay 12 pares.
const CACHE_BETA = Dict{Tuple{Float64,Float64},NamedTuple}()
function beta_cache(α, P)
    get!(CACHE_BETA, (α, P)) do
        beta_minimo_para_p(α, p("F_slots"), P)
    end
end

# ───────────────────────────────────────────── escritura CSV

function escribir_csv(nombre, cabecera, filas)
    ruta = joinpath(DIR_RES, nombre)
    limpia(s) = replace(string(s), "," => ";")
    open(ruta, "w") do io
        println(io, join(limpia.(cabecera), ","))
        for f in filas
            println(io, join(limpia.(f), ","))
        end
    end
    return ruta
end

fmt(x; d = 6) = @sprintf("%.*g", d, x)
bool(x) = x ? "SI" : "NO"

# ───────────────────────────────────────────── casos de distribución

"""
    construir_casos(ruta_datos) -> Vector{NamedTuple}

Caso central: empírica de DS-6 (`farmers-raw.csv`, deduplicada, `points>0`). Casos pesimistas:
Pareto truncada de DS-3 (H3) con `α_dens ∈ {2.05, 2.2, 2.5, 3.0}`.
"""
function construir_casos(ruta_datos)
    crudos = cargar_farmers(ruta_datos)
    limpios = limpiar_farmers(crudos)
    tibs = Float64[g.tib for g in limpios]
    emp = empirica(tibs)
    n = length(limpios)
    pool_tib = sum(tibs)
    casos = NamedTuple{(:nombre, :dist, :etiqueta, :n),Tuple{String,SL2.DistribucionEspacio,String,Int}}[
        (nombre = "empirico", dist = emp, etiqueta = "medido DS-6 (pool SpaceFarmers)", n = n)]
    for al in (2.05, 2.2, 2.5, 3.0)
        d = ParetoDist(p("dist_f_min"), al, p("f_media_hipotesis"))
        push!(casos, (nombre = "pareto_" * replace(string(al), "." => "_"), dist = d,
                      etiqueta = "hipótesis H3 (α_dens=$al)", n = 0))
    end
    @printf("Datos: %d filas crudas -> %d limpias; pool = %.1f TiB; f_media_emp = %.3g\n",
            length(crudos), n, pool_tib, emp.f_media)
    return casos, emp
end

# ───────────────────────────────────────────── 1 · casos de comprobación

"Reproduce los siete casos de MODELO §4 (continuidad con DS-3) y añade los de SL-2."
function tabla_comprobaciones(emp)
    filas = Vector{Vector{String}}()

    # §4.2 ventana
    r = Reparto(0.33, 0.0)
    P = primera_dp(p_de_alpha(r), deficit_entero(r, 1019), 1019).paso
    push!(filas, ["MODELO §4.2 P(F=1019,α=0.33)", fmt(P; d = 12), "9.75e-108", "DP exacta",
                  "condicionado H-PUENTE"])
    # §4.3 retención
    push!(filas, ["MODELO §4.3 P(B=0) θ=0.36", fmt(exp(-0.36); d = 10), "0.69768", "Poisson exacta", "—"])
    # §4.4 grieta Pareto
    B3600 = B_par(Pareto(1e-8, 2.2), 0.01 / 3600)
    B100k = B_par(Pareto(1e-8, 2.2), 0.01 / 100000)
    push!(filas, ["MODELO §4.4 B(0.01,Tv=3600,α=2.2)", fmt(B3600; d = 6), "0.675466",
                  "Pareto truncada H3", "reproduce DS-3"])
    push!(filas, ["MODELO §4.4 B(0.01,Tv=1e5,α=2.2)", fmt(B100k; d = 6), "0.369", "Pareto truncada H3", "—"])
    # §4.7 Baig–Pietrzak (guardado como reserva, no se usa)
    push!(filas, ["DS-3 reserva F7 Baig–Pietrzak", "4253", "1233+140 [sic]", "fórmula MODELO", "reserva"])
    # SL-2: corrección de la región de retención (REVISION-DS3)
    reg = alpha_estrella(0.34, 0.0, 1.0, 1.0)
    push!(filas, ["SL-2 α*(βd=0.34)", fmt(reg; d = 8), "0.33", "identidad", "REVISION-DS3"])
    # grieta con datos DS-6 (empírica)
    Bemp = B_empirico(emp, 0.01 / 3600)
    push!(filas, ["SL-2 B_emp(0.01,Tv=3600) DS-6", fmt(Bemp; d = 6), "1.78e-4", "empírico directo",
                  "DS-6 Corrección A"])
    # umbral de la honestidad base
    ing = p("lambda") * p("f_honesto") * p("I") * SL2.T_AÑO_S
    push!(filas, ["SL-2 ingreso anual f_h=1e-3", fmt(ing; d = 6), "31536", "derivado", "resolución F4"])
    return escribir_csv("comprobaciones.csv", ["caso", "valor", "esperado", "via", "etiqueta"], filas)
end

# ───────────────────────────────────────────── 2 · β_d por (α, P*)

function tabla_beta(casos)
    filas = Vector{Vector{String}}()
    for α in grid("alpha_atacante", [0.20, 0.25, 0.33, 0.40]), P in grid("P_objetivo", [1e-6, 1e-3, 0.5])
        bm = beta_cache(α, P)
        push!(filas, [fmt(α; d = 3), fmt(P; d = 3), fmt(bm.βd; d = 6), fmt(bm.P; d = 6),
                      fmt(beta_cruce(α); d = 4), string(bm.iteraciones)])
    end
    return escribir_csv("beta-d.csv",
        ["alpha", "P_objetivo", "beta_d_min", "P_alcanzada", "1_menos_2alpha", "iteraciones"], filas)
end

# ───────────────────────────────────────────── 3 · B(ε) por escenario

function tabla_Beps(casos)
    filas = Vector{Vector{String}}()
    for caso in casos
        for Tv in (1000.0, 3600.0, 10000.0, 100000.0), f in (0.25, 0.5, 1.0), eps in (0.001, 0.01, 0.1)
            x = funcion_umbral(eps, f, p("lambda"), Tv, 0.0)
            B = B_de(caso.dist, x)
            push!(filas, [caso.nombre, fmt(Tv; d = 6), fmt(f; d = 3), fmt(eps; d = 4),
                          fmt(x; d = 6), fmt(B; d = 8), caso.etiqueta])
        end
    end
    return escribir_csv("Beps-escenarios.csv",
        ["caso", "T_v", "f_conf", "eps_saldo", "x_umbral", "B_eps", "etiqueta"], filas)
end

# ───────────────────────────────────────────── 4 · barrido de la región

function escenario_de(caso, V, f, qg, R, eh, fh, via, P; ρ = 0.5, Tv = 3600.0, s = 0.0,
                      q_ev = p("q_ev"))
    return Escenario(caso.dist, V, f, qg, p("c_r"), p("I"), p("lambda"), p("kappa"), q_ev,
                     p("eps_saldo"), R, p("F_slots"), P, eh, fh, p("frac_ingreso_max"), via, s)
end

"Barrido principal P1 (fiel a DS-3): región `(ρ_ret, T_v)` por escenario."
function barrido_region(casos)
    filas = Vector{Vector{String}}()
    resumen = Vector{Vector{String}}()
    for caso in casos
        for α in grid("alpha_atacante", [0.20, 0.25, 0.33, 0.40]),
            P in grid("P_objetivo", [1e-6, 1e-3, 0.5])
            bm = beta_cache(α, P)
            βd = bm.βd
            for V in grid("V", [1e4]), f in grid("f_conf", [1.0]),
                qg in grid("q_g", [20.0]), eh in grid("eps_honesto", [1e-3]),
                fh in [p("f_honesto")], ρ in grid("rho_ret", [0.5])
                esc = escenario_de(caso, V, f, qg, 0.0, eh, fh, :P1, P)
                reg = isnan(βd) ?
                      (existe = false, Tv_min = Inf, Tv_max = 0.0, borde_inf = "—", borde_sup = "—",
                       B_min = NaN, N_paid_min = NaN, L_min = NaN, motivo = "P* inalcanzable") :
                      region_tv(esc, βd; ρ_ret = ρ)
                push!(filas, [caso.nombre, fmt(α; d = 3), fmt(P; d = 3), fmt(βd; d = 6), fmt(V; d = 6),
                              fmt(f; d = 3), fmt(qg; d = 6), fmt(eh; d = 4), fmt(fh; d = 4),
                              "P1", fmt(ρ; d = 3), bool(reg.existe), fmt(reg.Tv_min; d = 6),
                              fmt(reg.Tv_max; d = 6), reg.borde_inf, reg.borde_sup,
                              fmt(reg.B_min; d = 6), fmt(reg.N_paid_min; d = 6),
                              fmt(reg.L_min; d = 6), reg.motivo])
            end
        end
    end
    escribir_csv("region.csv",
        ["caso", "alpha", "P_objetivo", "beta_d", "V", "f_conf", "q_g", "eps_h", "f_h", "via",
         "rho_ret", "existe", "Tv_min", "Tv_max", "borde_inf", "borde_sup", "B_en_Tv_min",
         "N_paid_en_Tv_min", "L_en_Tv_min", "motivo"], filas)
    return filas
end

"Barrido completo de la rejilla declarada (más filas) en modo no rápido."
function barrido_region_completo(casos)
    filas = Vector{Vector{String}}()
    for caso in casos
        for α in grid("alpha_atacante", [0.33]), P in grid("P_objetivo", [1e-3])
            bm = beta_cache(α, P)
            for V in grid("V", [1e4]), f in grid("f_conf", [1.0]), qg in grid("q_g", [20.0]),
                eh in grid("eps_honesto", [1e-3]), fh in grid("f_honesto", [1e-3]),
                ρ in grid("rho_ret", [0.5])
                esc = escenario_de(caso, V, f, qg, 0.0, eh, fh, :P1, P)
                reg = region_tv(esc, bm.βd; ρ_ret = ρ)
                push!(filas, [caso.nombre, fmt(α; d = 3), fmt(P; d = 3), fmt(bm.βd; d = 6),
                              fmt(V; d = 6), fmt(f; d = 3), fmt(qg; d = 6), fmt(eh; d = 4),
                              fmt(fh; d = 4), "P1", fmt(ρ; d = 3), bool(reg.existe),
                              fmt(reg.Tv_min; d = 6), fmt(reg.Tv_max; d = 6), reg.borde_inf,
                              reg.borde_sup, reg.motivo])
            end
        end
    end
    escribir_csv("region-completa.csv",
        ["caso", "alpha", "P_objetivo", "beta_d", "V", "f_conf", "q_g", "eps_h", "f_h", "via",
         "rho_ret", "existe", "Tv_min", "Tv_max", "borde_inf", "borde_sup", "motivo"], filas)
    return filas
end

"Frontera del caso central para la pregunta falsable: ε_h ≤ 1e-3, α ∈ [0.20,0.40], V y f barridos."
function frontera_central(casos)
    filas = Vector{Vector{String}}()
    central = casos[1]                        # empírico DS-6
    for P in (1e-6, 1e-3, 0.5), V in grid("V", [1e2, 1e3, 1e4, 1e5, 1e6]),
        f in grid("f_conf", [0.25, 0.5, 1.0]), qg in grid("q_g", [20.0, 1000.0, 10000.0]),
        eh in grid("eps_honesto", [1e-4, 1e-3])
        for α in grid("alpha_atacante", [0.20, 0.25, 0.33, 0.40])
            bm = beta_cache(α, P)
            mejor = (existe = false, rho = NaN, Tv_min = NaN, Tv_max = NaN,
                     borde_inf = "—", borde_sup = "—", margen = -Inf, L = NaN)
            for ρ in grid("rho_ret", [0.10, 0.25, 0.50, 1.00])
                esc = escenario_de(central, V, f, qg, 0.0, eh, p("f_honesto"), :P1, P)
                reg = region_tv(esc, bm.βd; ρ_ret = ρ)
                if reg.existe && (reg.Tv_max - reg.Tv_min) > mejor.margen
                    mejor = (existe = true, rho = ρ, Tv_min = reg.Tv_min, Tv_max = reg.Tv_max,
                             borde_inf = reg.borde_inf, borde_sup = reg.borde_sup,
                             margen = reg.Tv_max - reg.Tv_min, L = reg.L_min)
                end
            end
            push!(filas, [central.nombre, fmt(α; d = 3), fmt(P; d = 3), fmt(bm.βd; d = 6),
                          fmt(V; d = 6), fmt(f; d = 3), fmt(qg; d = 6), fmt(eh; d = 4),
                          bool(mejor.existe), fmt(mejor.rho; d = 3), fmt(mejor.Tv_min; d = 6),
                          fmt(mejor.Tv_max; d = 6), mejor.borde_inf, mejor.borde_sup,
                          fmt(mejor.margen; d = 6), fmt(mejor.L; d = 6),
                          "empírico DS-6; mejor ρ de la rejilla"])
        end
    end
    escribir_csv("frontera-central.csv",
        ["caso", "alpha", "P_objetivo", "beta_d", "V", "f_conf", "q_g", "eps_h", "existe_region",
         "rho_mejor", "Tv_min", "Tv_max", "borde_inf", "borde_sup", "margen_Tv", "L_en_Tv_min",
         "etiqueta"], filas)
    return filas
end

# ───────────────────────────────────────────── 5 · grieta (B vs umbral)

function tabla_grieta(casos)
    filas = Vector{Vector{String}}()
    for caso in casos
        for α in grid("alpha_atacante", [0.20, 0.25, 0.33, 0.40]), P in (1e-6, 1e-3, 0.5)
            bm = beta_cache(α, P)
            for Tv in (3600.0, 100000.0), f in (1.0,), eps in (0.01,)
                x = funcion_umbral(eps, f, p("lambda"), Tv, 0.0)
                B = B_de(caso.dist, x)
                umbral = beta_cruce(α)
                push!(filas, [caso.nombre, fmt(α; d = 3), fmt(P; d = 3), fmt(Tv; d = 6), fmt(f; d = 3),
                              fmt(bm.βd; d = 6), fmt(B; d = 8), fmt(umbral; d = 4),
                              B >= bm.βd ? "ABIERTA (gratis)" : "cerrada",
                              B >= umbral ? "B>=1-2a" : "B<1-2a"])
            end
        end
    end
    return escribir_csv("grieta.csv",
        ["caso", "alpha", "P_objetivo", "T_v", "f_conf", "beta_d_min", "B_eps", "umbral_1_menos_2alpha",
         "grieta_beta_d", "grieta_cruce"], filas)
end

# ───────────────────────────────────────────── 6 · sensibilidad P2, R y f_h

function tabla_sensibilidades(casos)
    # P2 (corrección de unidades, F5)
    filas = Vector{Vector{String}}()
    for caso in (casos[1], casos[end])
        for α in (0.33, 0.40), P in (1e-3,), V in (1e3, 1e4, 1e5), f in (0.5, 1.0),
            qg in (20.0, 1000.0), eh in (1e-3, 1e-1), ρ in (0.25, 0.5, 1.0)
            bm = beta_cache(α, P)
            esc = escenario_de(caso, V, f, qg, 0.0, eh, p("f_honesto"), :P2, P)
            reg = region_tv(esc, bm.βd; ρ_ret = ρ)
            push!(filas, [caso.nombre, fmt(α; d = 3), fmt(V; d = 6), fmt(f; d = 3), fmt(qg; d = 6),
                          fmt(eh; d = 4), fmt(ρ; d = 3), bool(reg.existe), fmt(reg.Tv_min; d = 6),
                          fmt(reg.Tv_max; d = 6), reg.borde_inf, reg.borde_sup, reg.motivo])
        end
    end
    escribir_csv("sensibilidad-P2.csv",
        ["caso", "alpha", "V", "f_conf", "q_g", "eps_h", "rho_ret", "existe", "Tv_min", "Tv_max",
         "borde_inf", "borde_sup", "motivo"], filas)

    # R_slots
    filas = Vector{Vector{String}}()
    central = casos[1]
    for R in (0.0, 1019.0, 2038.0), α in (0.20, 0.33, 0.40), V in (1e4, 1e5), eh in (1e-3, 1e-1),
        ρ in (0.25, 0.5, 1.0)
        bm = beta_cache(α, 1e-3)
        esc = escenario_de(central, V, 1.0, 20.0, R, eh, p("f_honesto"), :P1, 1e-3)
        reg = region_tv(esc, bm.βd; ρ_ret = ρ)
        push!(filas, [fmt(R; d = 6), fmt(α; d = 3), fmt(V; d = 6), fmt(eh; d = 4), fmt(ρ; d = 3),
                      bool(reg.existe), fmt(reg.Tv_min; d = 6), fmt(reg.Tv_max; d = 6),
                      reg.borde_inf, reg.borde_sup])
    end
    escribir_csv("sensibilidad-R.csv",
        ["R_slots", "alpha", "V", "eps_h", "rho_ret", "existe", "Tv_min", "Tv_max", "borde_inf",
         "borde_sup"], filas)

    # f_h (regresividad)
    filas = Vector{Vector{String}}()
    for caso in (casos[1], casos[end]), fh in (1e-6, 1e-3, 1e-1), eh in (1e-3, 1e-1),
        qg in (1000.0, 10000.0), ρ in (0.25, 0.5, 1.0)
        bm = beta_cache(0.33, 1e-3)
        esc = escenario_de(caso, 1e4, 1.0, qg, 0.0, eh, fh, :P1, 1e-3)
        reg = region_tv(esc, bm.βd; ρ_ret = ρ)
        push!(filas, [caso.nombre, fmt(fh; d = 3), fmt(eh; d = 4), fmt(qg; d = 6), fmt(ρ; d = 3),
                      bool(reg.existe), fmt(reg.Tv_min; d = 6), fmt(reg.Tv_max; d = 6),
                      reg.borde_inf, reg.borde_sup])
    end
    escribir_csv("sensibilidad-fh.csv",
        ["caso", "f_h", "eps_h", "q_g", "rho_ret", "existe", "Tv_min", "Tv_max", "borde_inf",
         "borde_sup"], filas)
end

# ───────────────────────────────────────────── 7 · Monte Carlo independiente

function monte_carlo(casos, emp)
    filas = Vector{Vector{String}}()

    # (a) paseo: DP vs MC
    dp = primera_dp(1 / 3, 5, 400).paso
    mc = mc_ventana(1 / 3, 5, 400, REPS, SEMILLA)
    push!(filas, ["ventana p=1/3 d=5 T=400", string(REPS), fmt(dp; d = 8), fmt(mc.p_paso; d = 8),
                  fmt(mc.ic_paso[1]; d = 8), fmt(mc.ic_paso[2]; d = 8),
                  mc.ic_paso[1] <= dp <= mc.ic_paso[2] ? "DENTRO" : "FUERA"])

    # (b) retención: Poisson exacta vs MC
    ex = exp(-0.36)
    mcs = mc_saldo_cero(0.36, REPS, SEMILLA)
    push!(filas, ["retención P(B=0) θ=0.36", string(REPS), fmt(ex; d = 8), fmt(mcs.p; d = 8),
                  fmt(mcs.ic[1]; d = 8), fmt(mcs.ic[2]; d = 8),
                  mcs.ic[1] <= ex <= mcs.ic[2] ? "DENTRO" : "FUERA"])

    # (c) B empírico: directo vs bootstrap
    x = 0.01 / 3600
    bp = B_empirico(emp, x)
    reps = bootstrap_Bemp(emp, x, 5000, SEMILLA)
    lo, hi = ic_percentil(reps)
    push!(filas, ["B empírico DS-6 (x=0.01/3600)", "5000", fmt(bp; d = 8),
                  fmt(mean(reps); d = 8), fmt(lo; d = 8), fmt(hi; d = 8),
                  lo <= bp <= hi ? "DENTRO" : "FUERA"])

    # (d) B Pareto: cerrada vs integración exacta vs MC
    for al in (2.05, 3.0)
        vb = validar_Bpar(al, 0.01 / 3600; m = 200_000, nrep = 200)
        push!(filas, ["B Pareto α=$al", "200x2e5", fmt(vb.cerrada; d = 8),
                      fmt(vb.mc_media; d = 8), fmt(vb.ic_lo; d = 8), fmt(vb.ic_hi; d = 8),
                      vb.dentro ? "DENTRO" : "FUERA"])
    end

    # (e) honesto: cerrada vs MC Poisson (dentro de 3 errores estándar)
    esc = escenario_de(casos[1], 1e4, 1.0, 20.0, 0.0, 1e-1, 1e-3, :P1, 1e-3)
    mch = mc_honesto(esc, 0.5, 3600.0; nrep = REPS, semilla = SEMILLA)
    L = perdida_castigo(esc; ρ_ret = 0.5, Tv = 3600.0)
    cerrada = esc.eps_h * L
    push!(filas, ["honesto ε_h·L vs MC", string(REPS), fmt(cerrada; d = 8), fmt(mch.media; d = 8),
                  fmt(mch.media - 3 * mch.se; d = 8), fmt(mch.media + 3 * mch.se; d = 8),
                  abs(mch.media - cerrada) <= 3 * mch.se ? "DENTRO" : "FUERA"])

    return escribir_csv("monte-carlo.csv",
        ["caso", "replicas", "valor_exacto", "mc", "ic95_lo", "ic95_hi", "resultado"], filas)
end

# ───────────────────────────────────────────── 8 · recomendación dev

"""
    recomendacion_dev(casos) -> Vector{Vector{String}}

Valores de desarrollo para la red dev (NO producción). Punto más duro de la pregunta falsable:
`α=0.40`, `P*=1e-3`, `V=1e5`, `f=1`, `q_g=20`, `ε_h=1e-3`, `f_h` representativo. Para cada `ρ_ret`
se da el `T_v` mínimo que **cubre los cinco casos de distribución** (empírico DS-6 + Pareto H3), y
se elige el `ρ_ret` que minimiza ese `T_v`. Etiquetado como recomendación de desarrollo.
"""
function recomendacion_dev(casos)
    filas = Vector{Vector{String}}()
    αref, Pref, Vref, ehref, qgref = 0.40, 1e-3, 1e5, 1e-3, 20.0
    bm = beta_cache(αref, Pref)
    mejor = (rho = NaN, Tv = Inf, todos = false, detalle = "")
    for ρ in (0.10, 0.25, 0.50, 1.00)
        todos = true
        maxTv = 0.0
        detalle = String[]
        for caso in casos
            esc = escenario_de(caso, Vref, 1.0, qgref, 0.0, ehref, p("f_honesto"), :P1, Pref)
            reg = region_tv(esc, bm.βd; ρ_ret = ρ)
            if reg.existe
                maxTv = max(maxTv, reg.Tv_min)
                push!(detalle, caso.nombre * "=" * fmt(reg.Tv_min; d = 4))
            else
                todos = false
                push!(detalle, caso.nombre * "=NO")
            end
        end
        push!(filas, [fmt(ρ; d = 3), bool(todos), fmt(maxTv; d = 6), join(detalle, "; "),
                      "dev; cubre los 5 casos; α=0.40,P*=1e-3,V=1e5,f=1,q_g=20,ε_h=1e-3"])
        todos && maxTv < mejor.Tv && (mejor = (rho = ρ, Tv = maxTv, todos = true,
                                               detalle = join(detalle, "; ")))
    end
    # fila de recomendación dev primaria (medida) y robusta (cubre H3)
    central = casos[1]
    escC = escenario_de(central, Vref, 1.0, qgref, 0.0, ehref, p("f_honesto"), :P1, Pref)
    regC = region_tv(escC, bm.βd; ρ_ret = 0.10)
    push!(filas, ["0.100", bool(regC.existe), fmt(regC.Tv_min; d = 6),
                  "empirico=" * fmt(regC.Tv_min; d = 4),
                  "DEV PRIMARIO (medido DS-6): f=1, rho=0.10, T_v recomendado=100000, q_g=20"])
    push!(filas, [fmt(mejor.rho; d = 3), bool(mejor.todos), fmt(mejor.Tv; d = 6), mejor.detalle,
                  "DEV ROBUSTO (cubre Pareto H3): f=1, rho=" * fmt(mejor.rho; d = 3) *
                  ", T_v recomendado=" * fmt(ceil(mejor.Tv / 1e5) * 1e5; d = 4) * ", q_g=20"])
    return escribir_csv("recomendacion-dev.csv",
        ["rho_ret", "cubre_5_casos", "Tv_min_peor", "detalle_por_caso", "etiqueta"], filas)
end

# =============================================================================
# 9 · SL-2b · recompensa al incluidor (s = 2/8) y censura de la evidencia
#     (G-SL2b-1..G-SL2b-5). No toca las tablas de SL-2: con s=0 se reproducen.
# =============================================================================

atacante(conf::Bool) = conf ? "confabulado" : "no_confabulado"

"""
    barrido_region_s2(casos) -> Vector{Vector{String}}

Repite el barrido de `region.csv` para los dos atacantes con `s = s_incluidor` (2/8) y las **dos
lecturas de unidades** P1/P2 (F5): la región completa en `region-s2.csv`, las celdas que se pierden
en `celdas-perdidas-s2b.csv` y el recuento por (caso, vía) en `resumen-s2b.csv`. Una celda se pierde
si existía para el no confabulado y no existe para el confabulado (el borde superior de honestidad
no cambia).
"""
function barrido_region_s2(casos)
    s2 = p("s_incluidor")
    filas = Vector{Vector{String}}()
    perdidas = Vector{Vector{String}}()
    resumen = Vector{Vector{String}}()
    for caso in casos, via in (:P1, :P2)
        n = 0; ex_no = 0; ex_si = 0; n_perd = 0
        for α in grid("alpha_atacante", [0.20, 0.25, 0.33, 0.40]),
            P in grid("P_objetivo", [1e-6, 1e-3, 0.5])
            bm = beta_cache(α, P)
            βd = bm.βd
            for V in grid("V", [1e4]), f in grid("f_conf", [1.0]), qg in grid("q_g", [20.0]),
                eh in grid("eps_honesto", [1e-3]), ρ in grid("rho_ret", [0.5])
                regs = Vector{NamedTuple}()
                for conf in (false, true)
                    esc = escenario_de(caso, V, f, qg, 0.0, eh, p("f_honesto"), via, P; s = s2)
                    reg = isnan(βd) ?
                          (existe = false, Tv_min = Inf, Tv_max = 0.0, borde_inf = "—",
                           borde_sup = "—", B_min = NaN, N_paid_min = NaN, L_min = NaN,
                           motivo = "P* inalcanzable") :
                          region_tv(esc, βd; ρ_ret = ρ, confabulado = conf)
                    push!(regs, reg)
                    push!(filas, [caso.nombre, string(via), fmt(α; d = 3), fmt(P; d = 3),
                                  fmt(βd; d = 6), fmt(V; d = 6), fmt(f; d = 3), fmt(qg; d = 6),
                                  fmt(eh; d = 4), fmt(s2; d = 4), atacante(conf), fmt(ρ; d = 3),
                                  bool(reg.existe), fmt(reg.Tv_min; d = 6), fmt(reg.Tv_max; d = 6),
                                  reg.borde_inf, reg.borde_sup, fmt(reg.B_min; d = 6),
                                  fmt(reg.N_paid_min; d = 6), fmt(reg.L_min; d = 6), reg.motivo])
                end
                n += 1
                ex_no += regs[1].existe
                ex_si += regs[2].existe
                if regs[1].existe && !regs[2].existe
                    n_perd += 1
                    push!(perdidas, [caso.nombre, string(via), fmt(α; d = 3), fmt(P; d = 3),
                                     fmt(βd; d = 6), fmt(V; d = 6), fmt(f; d = 3), fmt(qg; d = 6),
                                     fmt(eh; d = 4), fmt(s2; d = 4), fmt(ρ; d = 3),
                                     fmt(regs[1].Tv_min; d = 6), fmt(regs[1].Tv_max; d = 6),
                                     fmt(regs[2].Tv_min; d = 6), regs[2].motivo])
                end
            end
        end
        push!(resumen, [caso.nombre, string(via), string(n), string(ex_no), string(ex_si),
                        string(n_perd), "s=" * fmt(s2; d = 4)])
    end
    escribir_csv("region-s2.csv",
        ["caso", "via", "alpha", "P_objetivo", "beta_d", "V", "f_conf", "q_g", "eps_h",
         "s_incluidor", "atacante", "rho_ret", "existe", "Tv_min", "Tv_max", "borde_inf",
         "borde_sup", "B_en_Tv_min", "N_paid_en_Tv_min", "L_en_Tv_min", "motivo"], filas)
    escribir_csv("celdas-perdidas-s2b.csv",
        ["caso", "via", "alpha", "P_objetivo", "beta_d", "V", "f_conf", "q_g", "eps_h",
         "s_incluidor", "rho_ret", "Tv_min_no", "Tv_max_no", "Tv_min_conf", "motivo_conf"],
        perdidas)
    escribir_csv("resumen-s2b.csv",
        ["caso", "via", "celdas", "existe_no_confabulado", "existe_confabulado", "celdas_perdidas",
         "s_incluidor"], resumen)
    return resumen
end

"""
    frontera_central_s2(casos) -> Vector{Vector{String}}

Igual que `frontera-central.csv` (punto central empírico, mejor `ρ` de la rejilla) pero para los
dos atacantes con `s = 2/8`: `frontera-central-s2.csv`.
"""
function frontera_central_s2(casos)
    s2 = p("s_incluidor")
    filas = Vector{Vector{String}}()
    central = casos[1]
    for P in (1e-6, 1e-3, 0.5), V in grid("V", [1e2, 1e3, 1e4, 1e5, 1e6]),
        f in grid("f_conf", [0.25, 0.5, 1.0]), qg in grid("q_g", [20.0, 1000.0, 10000.0]),
        eh in grid("eps_honesto", [1e-4, 1e-3])
        for α in grid("alpha_atacante", [0.20, 0.25, 0.33, 0.40]), via in (:P1, :P2)
            bm = beta_cache(α, P)
            for conf in (false, true)
                mejor = (existe = false, rho = NaN, Tv_min = NaN, Tv_max = NaN,
                         borde_inf = "—", borde_sup = "—", margen = -Inf, L = NaN)
                for ρ in grid("rho_ret", [0.10, 0.25, 0.50, 1.00])
                    esc = escenario_de(central, V, f, qg, 0.0, eh, p("f_honesto"), via, P; s = s2)
                    reg = region_tv(esc, bm.βd; ρ_ret = ρ, confabulado = conf)
                    if reg.existe && (reg.Tv_max - reg.Tv_min) > mejor.margen
                        mejor = (existe = true, rho = ρ, Tv_min = reg.Tv_min, Tv_max = reg.Tv_max,
                                 borde_inf = reg.borde_inf, borde_sup = reg.borde_sup,
                                 margen = reg.Tv_max - reg.Tv_min, L = reg.L_min)
                    end
                end
                push!(filas, [central.nombre, string(via), atacante(conf), fmt(α; d = 3),
                              fmt(P; d = 3), fmt(bm.βd; d = 6), fmt(V; d = 6), fmt(f; d = 3),
                              fmt(qg; d = 6), fmt(eh; d = 4), fmt(s2; d = 4), bool(mejor.existe),
                              fmt(mejor.rho; d = 3), fmt(mejor.Tv_min; d = 6),
                              fmt(mejor.Tv_max; d = 6), mejor.borde_inf, mejor.borde_sup,
                              fmt(mejor.margen; d = 6), fmt(mejor.L; d = 6),
                              "empírico DS-6; mejor ρ de la rejilla; s=2/8"])
            end
        end
    end
    return escribir_csv("frontera-central-s2.csv",
        ["caso", "via", "atacante", "alpha", "P_objetivo", "beta_d", "V", "f_conf", "q_g", "eps_h",
         "s_incluidor", "existe_region", "rho_mejor", "Tv_min", "Tv_max", "borde_inf", "borde_sup",
         "margen_Tv", "L_en_Tv_min", "etiqueta"], filas)
end

"""
    recomendacion_dev_s2(casos) -> Vector{Vector{String}}

Valores de desarrollo (NO producción) para los dos atacantes, las dos lecturas P1/P2 y
`s ∈ {0; 2/8; 3/8}`: para cada `ρ_ret` se exige región en los cinco repartos en el punto duro
`α=0.40, P*=1e-3, V=1e5, f=1, q_g=20, ε_h=1e-3`; se elige el `ρ_ret` que minimiza el `T_v`
necesario. `s=0` es el control de SL-2.
"""
function recomendacion_dev_s2(casos)
    filas = Vector{Vector{String}}()
    αref, Pref, Vref, ehref, qgref = 0.40, 1e-3, 1e5, 1e-3, 20.0
    bm = beta_cache(αref, Pref)
    for s in grid("s_incluidor", [0.25]), via in (:P1, :P2), conf in (false, true)
        mejor = (rho = NaN, Tv = Inf)
        for ρ in (0.10, 0.25, 0.50, 1.00)
            todos = true
            maxTv = 0.0
            for caso in casos
                esc = escenario_de(caso, Vref, 1.0, qgref, 0.0, ehref, p("f_honesto"), via,
                                   Pref; s = s)
                reg = region_tv(esc, bm.βd; ρ_ret = ρ, confabulado = conf)
                if reg.existe
                    maxTv = max(maxTv, reg.Tv_min)
                else
                    todos = false
                    break
                end
            end
            todos && maxTv < mejor.Tv && (mejor = (rho = ρ, Tv = maxTv))
        end
        push!(filas, [fmt(s; d = 4), string(via), atacante(conf), fmt(mejor.rho; d = 3),
                      bool(isfinite(mejor.Tv)), fmt(mejor.Tv; d = 6),
                      fmt(isfinite(mejor.Tv) ? ceil(mejor.Tv / 1e5) * 1e5 : 0.0; d = 4),
                      "dev; α=0.40,P*=1e-3,V=1e5,f=1,q_g=20,ε_h=1e-3; cubre los 5 casos"])
    end
    return escribir_csv("recomendacion-dev-s2.csv",
        ["s_incluidor", "via", "atacante", "rho_ret", "cubre_5_casos", "Tv_min_peor",
         "Tv_recomendado", "etiqueta"], filas)
end

"""
    censura_s2(casos) -> Vector{Vector{String}}

Barrido de la fracción `c` de producción que censura la evidencia (G-SL2b-4): `q_ev = 1 − c^n` con
`n = 1` (conservador) y `n = F_slots` (ventana). Punto duro, `ρ_ret = 0.25`, `s = 2/8`, para el
caso empírico y los Pareto 2,5 y 3,0, en los dos atacantes. `censura-s2b.csv`.
"""
function censura_s2(casos)
    filas = Vector{Vector{String}}()
    αref, Pref, Vref, ehref, qgref = 0.40, 1e-3, 1e5, 1e-3, 20.0
    bm = beta_cache(αref, Pref)
    for c in grid("censura_c", [0.0]), n in (1, round(Int, p("F_slots"))),
        caso in (casos[1], casos[4], casos[5]), conf in (false, true), ρ in (0.25,)
        q = q_inclusion(c, n)
        esc = escenario_de(caso, Vref, 1.0, qgref, 0.0, ehref, p("f_honesto"), :P1, Pref;
                           s = p("s_incluidor"), q_ev = q)
        reg = region_tv(esc, bm.βd; ρ_ret = ρ, confabulado = conf)
        push!(filas, [fmt(c; d = 3), string(n), fmt(q; d = 6), caso.nombre, atacante(conf),
                      fmt(ρ; d = 3), bool(reg.existe), fmt(reg.Tv_min; d = 6),
                      fmt(reg.Tv_max; d = 6), reg.motivo])
    end
    return escribir_csv("censura-s2b.csv",
        ["c", "n_oportunidades", "q_ev", "caso", "atacante", "rho_ret", "existe", "Tv_min",
         "Tv_max", "motivo"], filas)
end

"""
    comprobaciones_s2b(casos) -> Vector{Vector{String}}

Comprobaciones de la orden §1: `s=0` no cambia la pérdida; el reparto `premio + quemado = C`;
la autodenuncia **nunca** es rentable; y los bordes de `q_inclusion`. `comprobaciones-s2b.csv`.
"""
function comprobaciones_s2b(casos)
    filas = Vector{Vector{String}}()
    s2 = p("s_incluidor")
    central = casos[1]
    e0 = escenario_de(central, 1e5, 1.0, 20.0, 0.0, 1e-3, 1e-3, :P1, 1e-3; s = 0.0)
    L0n = perdida_castigo(e0; ρ_ret = 0.5, Tv = 3600.0, confabulado = false)
    L0c = perdida_castigo(e0; ρ_ret = 0.5, Tv = 3600.0, confabulado = true)
    push!(filas, ["s=0 · L_conf == L_no", fmt(L0c; d = 12), fmt(L0n; d = 12),
                  "control reproduce SL-2", L0c == L0n ? "OK" : "FALLA"])
    e2 = escenario_de(central, 1e5, 1.0, 20.0, 0.0, 1e-3, 1e-3, :P1, 1e-3; s = s2)
    for (ρ, Tv) in ((0.5, 3600.0), (0.1, 1e5))
        C = parte_confiscable(e2; ρ_ret = ρ, Tv = Tv)
        prem = premio_incluidor(e2; ρ_ret = ρ, Tv = Tv)
        quem = parte_quemada(e2; ρ_ret = ρ, Tv = Tv)
        push!(filas, ["reparto premio+quemado ρ=$ρ Tv=$(Int(Tv))", fmt(prem + quem; d = 12),
                      fmt(C; d = 12), "premio=" * fmt(prem; d = 6) * "; quemado=" * fmt(quem; d = 6),
                      abs(prem + quem - C) <= 1e-9 * max(1.0, C) ? "OK" : "FALLA"])
        ad = autodenuncia(e2; ρ_ret = ρ, Tv = Tv)
        push!(filas, ["autodenuncia perdida_neta ρ=$ρ Tv=$(Int(Tv))", fmt(ad.perdida_neta; d = 12),
                      "> 0; cota ≥ (1−s)C = " * fmt(ad.cota_inferior; d = 6), "s=" * fmt(s2; d = 4),
                      (!ad.rentable && ad.perdida_neta > 0) ? "OK" : "FALLA"])
    end
    for (c, n) in ((0.0, 1), (0.5, 1), (1.0, 1), (0.5, 1019), (0.9, 1019))
        push!(filas, ["q_inclusion(c=" * fmt(c; d = 2) * ",n=$n)", fmt(q_inclusion(c, n); d = 12),
                      "1−c^n", "G-SL2b-4", q_inclusion(c, n) ≈ 1 - c^n ? "OK" : "FALLA"])
    end
    return escribir_csv("comprobaciones-s2b.csv",
        ["caso", "valor", "esperado", "etiqueta", "resultado"], filas)
end

# =============================================================================
# main
# =============================================================================

function main()
    t0 = time()
    casos, emp = construir_casos(OPC["datos"])
    tabla_comprobaciones(emp)
    tabla_beta(casos)
    tabla_Beps(casos)
    barrido_region(casos)
    if !RAPIDO
        frontera_central(casos)
    end
    tabla_grieta(casos)
    tabla_sensibilidades(casos)
    monte_carlo(casos, emp)
    recomendacion_dev(casos)

    # ── SL-2b: recomposición con la recompensa s = 2/8 (no altera las tablas SL-2, que son s=0) ──
    resumen_s2b = barrido_region_s2(casos)
    if !RAPIDO
        frontera_central_s2(casos)
    end
    recomendacion_dev_s2(casos)
    censura_s2(casos)
    comprobaciones_s2b(casos)

    open(joinpath(DIR_RES, "RESUMEN.txt"), "w") do io
        println(io, "SL-2 · resumen de ejecución")
        println(io, "fecha_local = 2026-09-26 (fecha de la orden)")
        println(io, "julia = ", VERSION)
        println(io, "nthreads_default = ", Threads.nthreads(:default))
        println(io, "nthreads_interactive = ", Threads.nthreads(:interactive))
        println(io, "cpu = ", Sys.CPU_NAME)
        println(io, "memoria_total_GiB = ", round(Sys.total_memory() / 2^30; digits = 1))
        println(io, "semilla = ", string(SEMILLA))
        println(io, "reps = ", REPS)
        println(io, "rapido = ", RAPIDO)
        println(io, "escenarios = ", OPC["escenarios"])
        println(io, "datos = ", OPC["datos"], " (sha256 ", "a18b7738...fdd18", ")")
        println(io, "segundos_pared = ", round(time() - t0; digits = 2))
        println(io)
        println(io, "validaciones:")
        vt = validar_primera_pasada()
        println(io, "  primera_pasada = ", vt)
        println(io, "  alpha = ", validar_alpha())
        println(io, "  Bemp = ", validar_Bemp(emp, 0.01 / 3600, SEMILLA; nrep = 4000))
        println(io, "  Bpar_2.05 = ", validar_Bpar(2.05, 0.01 / 3600; m = 200_000, nrep = 200))
        e0 = escenario_de(casos[1], 1e5, 1.0, 20.0, 0.0, 1e-3, 1e-3, :P1, 1e-3; s = 0.0)
        e2 = escenario_de(casos[1], 1e5, 1.0, 20.0, 0.0, 1e-3, 1e-3, :P1, 1e-3;
                          s = p("s_incluidor"))
        println(io, "  s2b = ", validar_s2b(e0, e2; ρ_ret = 0.5, Tv = 3600.0))
        println(io)
        println(io, "SL-2b (recompensa s = ", fmt(p("s_incluidor"); d = 4), " = 2/8):")
        for r in resumen_s2b
            println(io, "  ", r[1], " [", r[2], "]: celdas=", r[3], " existe_no=", r[4],
                    " existe_conf=", r[5], " perdidas=", r[6], " (", r[7], ")")
        end
        println(io)
        println(io, "artefactos:")
        for f in sort(readdir(DIR_RES))
            endswith(f, ".csv") && println(io, "  ", f)
        end
    end
    @printf("SL-2 terminado en %.1f s.\n", time() - t0)
end

main()
