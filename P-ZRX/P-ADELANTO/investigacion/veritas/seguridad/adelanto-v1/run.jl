#!/usr/bin/env julia
#
# run.jl — CLI reproducible de ADL-v1. Escribe los artefactos en `resultados/`.
#
# Uso:
#   julia --project=. run.jl --modo todo
#   julia --project=. run.jl --modo barrido-rho --rhos 1,1.001,1.01,1.5,2.5 --L 7200 --I 851 --W-dec 20
#
# Todos los parámetros de consenso entran como **símbolos** por línea de comandos: el
# instrumento no fija ninguno. `--L` es solo para la regresión contra SEM-v1 (que trata
# `L` como libre); el modelo vigente **deriva** `L` con `C-FLU-01` a partir de `--F`,
# `--L-suelo` y `--S-max`.

using Dates
using AdelantoV1

const RAIZ = @__DIR__
const RESULTADOS = joinpath(RAIZ, "resultados")

# ─────────────────────────────────────────────────────────────────────────────
# Utilidades
# ─────────────────────────────────────────────────────────────────────────────

function entorno_txt(io::IO, args::Vector{String})
    println(io, "# Entorno de ejecución")
    println(io, "fecha              = ", Dates.now())
    println(io, "julia              = ", VERSION)
    println(io, "cpu                = ", Sys.CPU_NAME)
    println(io, "hilos_lógicos      = ", Sys.CPU_THREADS)
    println(io, "hilos_julia_default= ", Threads.nthreads(:default))
    println(io, "hilos_julia_inter  = ", Threads.nthreads(:interactive))
    println(io, "ram_bytes          = ", Sys.total_memory())
    println(io, "blas               = no se usa (aritmética escalar pura; sin BLAS, sin hilos BLAS)")
    println(io, "proyecto           = ", Base.active_project())
    println(io, "argumentos         = ", join(args, " "))
    println(io, "semilla            = no aplica (instrumento determinista; Sim-v1 usa rejilla fija)")
    gh = try
        strip(read(`git -C $(dirname(dirname(dirname(dirname(dirname(RAIZ)))))) rev-parse HEAD`, String))
    catch
        "no disponible"
    end
    println(io, "git_hash           = ", gh)
    return nothing
end

"""Lista numérica de la CLI: `a,b,c` o un valor."""
function lista(texto::String, nombre::String)
    partes = split(texto, ',')
    vals = Float64[]
    for p in partes
        isempty(p) && continue
        v = tryparse(Float64, p)
        v === nothing && error("valor no numérico en --$nombre: '$p'")
        push!(vals, v)
    end
    isempty(vals) && error("--$nombre quedó vacía")
    return vals
end

function escalar(texto::String, nombre::String)
    v = tryparse(Float64, texto)
    v === nothing && error("valor no numérico en --$nombre: '$texto'")
    return v
end

function cabecera(io::IO, titulo::String)
    println(io, "# ", titulo)
    println(io, "# generado = ", Dates.now())
    println(io, "# instrumento = ADL-v1.0 (P-ZRX/P-ADELANTO/investigacion/veritas/seguridad/adelanto-v1)")
    println(io)
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Validación
# ─────────────────────────────────────────────────────────────────────────────

function modo_validacion(io::IO, cfg)
    cabecera(io, "ADL-v1 · validación")

    println(io, "## 1 · Regresión contra SEM-v1 (encargo §2a)")
    r = regresion_semv1()
    println(io, "filas_evaluadas                        = ", r.filas)
    println(io, "maxdiff_nucleo_vs_transcripcion_literal= ", r.maxdiff_nucleo_vs_literal)
    println(io, "maxdiff_A_D(D=0)_vs_SEMv1              = ", r.maxdiff_D0_vs_literal)
    println(io, "maxerr_tabla_publicada_SEMv1           = ", r.maxerr_tabla_publicada)
    println(io, "w_publicados_identicos                 = ", r.w_publicados_identicos)
    println(io, "ACEPTADO                               = ", r.aceptado)
    println(io)
    println(io, "  tabla publicada por SEM-v1 reproducida fila a fila (I=851, W_dec=20):")
    println(io, "  rho      L        A_core(repro)   A_publicado   w(repro)  w(publicado)")
    for k in eachindex(TABLA_SEMV1.rho)
        a = adelanto_nucleo(TABLA_SEMV1.rho[k], TABLA_SEMV1.L[k], 851.0, 20.0)
        w = desafios_nucleo(TABLA_SEMV1.rho[k], TABLA_SEMV1.L[k], 851.0, 20.0)
        println(io, "  ", rpad(TABLA_SEMV1.rho[k], 8), rpad(TABLA_SEMV1.L[k], 9),
            rpad(round(a; digits = 2), 16), rpad(TABLA_SEMV1.adelanto[k], 14),
            rpad(w, 10), TABLA_SEMV1.w[k])
    end
    println(io)

    println(io, "## 2 · Kernel contra BigFloat (256 bits)")
    filas = Vector{ParametrosAdelanto{Float64}}(undef, 0)
    for rho in (1.0, 1.001, 1.01, 1.5, 2.0, 2.5, 9.0), I in (151.0, 851.0, 4725.0),
        W in (5.0, 20.0, 45.0), D in (0.0, 4.0, 45.0), F in (1019.0, 7200.0, 19180.0),
        Lsu in (0.0, 3000.0)
        push!(filas, ParametrosAdelanto(rho, I, W, D, 150.0, F, Lsu, 1e5, cfg.rho_max, 0.0961))
    end
    k = kernel_vs_bigfloat(filas)
    println(io, "filas                    = ", length(filas))
    println(io, "peor_error_relativo      = ", k.peor_error_relativo, "  (campo ", k.peor_campo, ")")
    println(io, "tol                      = 64*eps(Float64) = ", 64 * eps(Float64))
    println(io, "violaciones              = ", k.violaciones)
    println(io, "ACEPTADO                 = ", k.aceptado)
    println(io)

    println(io, "## 3 · Modelo de fronteras contra Sim-v1 (oráculo independiente)")
    s = frontera_vs_sim()
    println(io, "maxdif_slots             = ", s.maxdif, "  (convención discreta de un slot)")
    println(io, "ACEPTADO (<= 1 slot)     = ", s.aceptado)
    println(io)
    println(io, "  rho      A_sim    A_cerrada  Gamma_sim  t_decision  fr_honesta  fr_atacante")
    for f in s.filas
        println(io, "  ", rpad(f.rho, 8), rpad(f.A_sim, 9), rpad(f.A_cerrada, 11),
            rpad(f.Gamma_sim, 11), rpad(f.t_decision, 12), rpad(f.fr_hon, 12), f.fr_adv)
    end
    println(io)

    println(io, "## 4 · Invariantes y bordes")
    inv = invariantes()
    for (nom, v) in inv.notas
        println(io, "nota  ", rpad(nom, 32), " = ", v)
    end
    println(io, "fallos                   = ", isempty(inv.fallos) ? "ninguno" : join(inv.fallos, "; "))
    println(io, "ACEPTADO                 = ", inv.aceptado)
    println(io)

    println(io, "## 5 · Exactitud de umbrales discretos (Float64 vs Rational{BigInt})")
    e = exactitud_umbrales()
    println(io, "filas                              = ", e.filas)
    println(io, "peor_error_rel_rho_estrella        = ", e.peor_error_rel_rho_estrella)
    println(io, "discrepancias_manda_F              = ", e.discrepancias_manda_F)
    println(io, "discrepancias_vivo                 = ", e.discrepancias_vivo)
    println(io, "discrepancias_rho                  = ", e.discrepancias_rho)
    println(io, "ACEPTADO                           = ", e.aceptado)
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Barrido de ρ (el que el encargo pide densificar alrededor de 1)
# ─────────────────────────────────────────────────────────────────────────────

function modo_barrido_rho(io::IO, cfg)
    cabecera(io, "ADL-v1 · adelanto frente a ρ (a ambos lados de 1)")
    println(io, "# L_slots derivada por C-FLU-01 de F_slots=$(cfg.F), L_suelo=$(cfg.L_suelo), S_max=$(cfg.S_max)")
    println(io, "# I_slots=$(cfg.I)  W_dec=$(cfg.W_dec)  D=$(cfg.D)  t_obs=$(cfg.t_obs)  rho_max=(cfg.rho_max)")
    println(io, "# 'acantilado' = A_core(1+) − A_core(1) con A_core(1)=0")
    println(io)
    println(io, join((
        "rho", "L_slots", "A_core", "A_D", "A_frontera", "A_frontera_inf", "rho_trans",
        "A_con_h", "A_con_h_D", "rho_estrella", "w_nucleo", "coste_rel", "lineas", "nucleos",
    ), '\t'))
    for rho in cfg.rhos
        p = ParametrosAdelanto(rho, cfg.I, cfg.W_dec, cfg.D, cfg.S_max, cfg.F, cfg.L_suelo,
            cfg.t_obs, cfg.rho_max, COSTE_VERIFY_SLOT_S)
        r = evaluar_fila(p)
        println(io, join((
            rho, r.L_slots, r.A_nucleo, r.A_D, r.A_frontera, r.A_frontera_inf,
            r.rho_transitorio, r.A_con_h, r.A_con_h_D, r.rho_estrella, r.w_nucleo,
            r.coste_relativo, r.lineas_timekeeper, r.nucleos_nodo,
        ), '\t'))
    end
    println(io)
    L = L_derivada(cfg.F, cfg.L_suelo, cfg.S_max)
    println(io, "# Lectura: A_core(1)=0 y A_core(1.001)=",
        adelanto_nucleo(1.001, L, cfg.I, cfg.W_dec),
        " ⇒ acantilado de ", adelanto_nucleo(1.001, L, cfg.I, cfg.W_dec), " slots.")
    println(io, "# A_frontera(1)=0 y A_frontera(1.001)=",
        adelanto_frontera(1.001, L, cfg.I, cfg.W_dec, cfg.D, cfg.t_obs),
        " ⇒ sin acantilado.")
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Barrido de D — las tres lecturas
# ─────────────────────────────────────────────────────────────────────────────

function modo_barrido_D(io::IO, cfg)
    cabecera(io, "ADL-v1 · dependencia en D (las tres lecturas del encargo §3)")
    L = L_derivada(cfg.F, cfg.L_suelo, cfg.S_max)
    println(io, "# L_slots=$(L) (C-FLU-01)  I=$(cfg.I)  W_dec=$(cfg.W_dec)  rho=$(cfg.rho)  t_obs=$(cfg.t_obs)")
    println(io, "# A_D         = PRIMARIA: D resta (frontera honesta limitada por su reloj)")
    println(io, "# A_add       = CONTRAFACTUAL prohibido (C-POT-03): reto derivado de pot_output")
    println(io, "# A_sub       = CONTRAFACTUAL incoherente: D solo al atacante, frontera honesta sin desplazar")
    println(io, "# A_frontera  = modelo de fronteras independiente (transitorio + flujo)")
    println(io, "# vivo        = D <= L − W_dec")
    println(io)
    println(io, join(("D", "vivo", "A_core", "A_D", "A_add", "A_sub", "A_frontera",
        "A_con_h", "A_con_h_D"), '\t'))
    for D in cfg.Ds
        p = ParametrosAdelanto(cfg.rho, cfg.I, cfg.W_dec, D, cfg.S_max, cfg.F, cfg.L_suelo,
            cfg.t_obs, cfg.rho_max, COSTE_VERIFY_SLOT_S)
        r = evaluar_fila(p)
        println(io, join((D, r.vivo, r.A_nucleo, r.A_D, r.A_add, r.A_sub, r.A_frontera,
            r.A_con_h, r.A_con_h_D), '\t'))
    end
    println(io)
    println(io, "# Umbral de viabilidad: D <= L − W_dec = ", L - cfg.W_dec,
        " slots. Por encima, el bloque del slot s exigiría un ancla futura y NINGÚN bloque avanzaría.")
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Regiones — el adelanto como función, no como constante
# ─────────────────────────────────────────────────────────────────────────────

function modo_regiones(io::IO, cfg)
    cabecera(io, "ADL-v1 · regiones: A(L_suelo, F, I, D) con L derivada por C-FLU-01")
    println(io, "# W_dec=$(cfg.W_dec)  S_max=$(cfg.S_max)  rho=$(cfg.rho)  rho_max=$(cfg.rho_max)  t_obs=$(cfg.t_obs)")
    println(io, "# 'manda_F' indica si L = F_slots (realimentación F→L activa) o si manda el suelo")
    println(io)
    println(io, join(("F_slots", "L_suelo", "I_slots", "D", "L_slots", "manda_F", "vivo",
        "A_core", "A_D", "A_frontera", "A_frontera_inf", "rho_estrella",
        "coste_rel", "lineas", "nucleos"), '\t'))
    for F in cfg.Fs, Ls in cfg.L_suelos, I in cfg.Is, D in cfg.Ds
        p = ParametrosAdelanto(cfg.rho, I, cfg.W_dec, D, cfg.S_max, F, Ls, cfg.t_obs,
            cfg.rho_max, COSTE_VERIFY_SLOT_S)
        r = evaluar_fila(p)
        println(io, join((F, Ls, I, D, r.L_slots, r.manda_F, r.vivo, r.A_nucleo, r.A_D,
            r.A_frontera, r.A_frontera_inf, r.rho_estrella, r.coste_relativo,
            r.lineas_timekeeper, r.nucleos_nodo), '\t'))
    end
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Fase 2 — revelación retardada, coste y realimentación
# ─────────────────────────────────────────────────────────────────────────────

function modo_fase2(io::IO, cfg)
    cabecera(io, "ADL-v1 · Fase 2 — revelación retardada (h) bajo C-FLU-01")

    println(io, "## 2.1 · ρ* con L derivada por C-FLU-01 (protección)")
    println(io, "# ρ*_cont = (L+I)/(I+W_dec)  [invierte (h.6) exactamente]")
    println(io, "# ρ*_disc = (L+I)/(I+W_dec−1) [donde A_con_h se anula con la convención −1 de A_core]")
    println(io)
    println(io, join(("F_slots", "L_suelo", "I_slots", "W_dec", "L_slots", "manda_F",
        "rho_estrella_cont", "rho_estrella_disc", "I_minima_f"), '\t'))
    for F in cfg.Fs, Ls in cfg.L_suelos, I in cfg.Is
        L = L_derivada(F, Ls, cfg.S_max)
        println(io, join((F, Ls, I, cfg.W_dec, L, L == F,
            rho_estrella_continua(L, I, cfg.W_dec), rho_estrella(L, I, cfg.W_dec),
            I_minima_f(cfg.rho_max, cfg.W_dec)), '\t'))
    end
    println(io)

    println(io, "## 2.2 · Coste por nodo con (h), en núcleos y en líneas q+1")
    println(io, "# nucleos = c_v·(1 + L/I), c_v = ", COSTE_VERIFY_SLOT_S, " s/slot (verify medido, research/dag-poas-ancla-de-orden.md:342)")
    println(io, "# lineas  = q+1 = ⌈L/I⌉+1")
    println(io, "# Separación protección/coste: rho*_cont = coste_rel · I/(I+W_dec)")
    println(io)
    println(io, join(("F_slots", "L_suelo", "I_slots", "L_slots", "coste_rel",
        "lineas_q+1", "nucleos_nodo", "rho*_cont", "separacion_rho*/coste"), '\t'))
    for F in cfg.Fs, Ls in cfg.L_suelos, I in cfg.Is
        L = L_derivada(F, Ls, cfg.S_max)
        cr = coste_relativo(L, I)
        nn = nucleos_nodo(L, I, COSTE_VERIFY_SLOT_S)
        re = rho_estrella_continua(L, I, cfg.W_dec)
        println(io, join((F, Ls, I, L, cr, lineas_timekeeper(L, I), nn, re, re / cr), '\t'))
    end
    println(io)

    println(io, "## 2.3 · (h.6) — I que iguala ρ* a ρ_max, y el suelo de F")
    println(io, "# I*(L, rho_max, W_dec) = (L − rho_max·W_dec)/(rho_max − 1)")
    println(io, "# Un I* <= 0 significa que ese ρ_max es inalcanzable con ese L: (h) NO puede comprarlo.")
    println(io)
    println(io, join(("rho_max", "L_slots", "origen_de_L", "I*", "I_minima_f",
        "I*_admisible", "coste_con_I*", "lineas_con_I*"), '\t'))
    for rmax in cfg.rho_maxs, (F, Ls) in ((cfg.F, cfg.L_suelo), (1019.0, 0.0), (3547.0, 0.0))
        L = L_derivada(F, Ls, cfg.S_max)
        Ie = I_estrella(L, rmax, cfg.W_dec)
        adm = Ie > max(I_minima_f(rmax, cfg.W_dec), cfg.S_max + 1)
        cr = Ie > 0 ? coste_relativo(L, Ie) : Inf
        li = Ie > 0 ? lineas_timekeeper(L, Ie) : Inf
        println(io, join((rmax, L, "F=$(F),suelo=$(Ls)", Ie, I_minima_f(rmax, cfg.W_dec),
            adm, cr, li), '\t'))
    end
    println(io)

    println(io, "## 2.4 · Realimentación F ↔ L ↔ ρ* (la pregunta del encargo §4.4)")
    println(io, "# Se baja F manteniendo I y el suelo, y se ve qué le pasa a ρ* y al coste.")
    println(io, "# 'manda_F'=false ⇒ el suelo desacopla y la realimentación es CERO.")
    println(io)
    println(io, join(("F_slots", "L_suelo", "L_slots", "manda_F", "I_slots",
        "rho*_cont", "coste_rel", "nucleos", "lineas"), '\t'))
    for F in cfg.Fs_bajos, Ls in cfg.L_suelos
        L = L_derivada(F, Ls, cfg.S_max)
        println(io, join((F, Ls, L, L == F, cfg.I, rho_estrella_continua(L, cfg.I, cfg.W_dec),
            coste_relativo(L, cfg.I), nucleos_nodo(L, cfg.I, COSTE_VERIFY_SLOT_S),
            lineas_timekeeper(L, cfg.I)), '\t'))
    end
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Fase 3 — las tres cotas
# ─────────────────────────────────────────────────────────────────────────────

function modo_fase3(io::IO, cfg)
    cabecera(io, "ADL-v1 · Fase 3 — cotas para las tres herramientas")

    println(io, "## 3.1 · ρ_max admisible y coste de cada opción")
    println(io, "# La cota inferior de I que hace ρ* >= ρ_max es I*(h.6); el coste se mide en I*.")
    println(io)
    println(io, join(("F_slots", "L_suelo", "rho_max", "L_slots", "I*_h6", "I_min_f",
        "admisible", "nucleos_nodo", "lineas", "I*+F"), '\t'))
    for F in cfg.Fs, Ls in cfg.L_suelos, rmax in cfg.rho_maxs
        L = L_derivada(F, Ls, cfg.S_max)
        Ie = I_estrella(L, rmax, cfg.W_dec)
        adm = Ie > max(I_minima_f(rmax, cfg.W_dec), cfg.S_max + 1)
        nn = Ie > 0 ? nucleos_nodo(L, Ie, COSTE_VERIFY_SLOT_S) : Inf
        li = Ie > 0 ? lineas_timekeeper(L, Ie) : Inf
        println(io, join((F, Ls, rmax, L, Ie, I_minima_f(rmax, cfg.W_dec), adm, nn, li,
            Ie + F), '\t'))
    end
    println(io)

    println(io, "## 3.2 · Cota inferior de la edad M (P-SEMBRADOR A1+C1): M > sup A + margen")
    println(io, "# Margen de red/finalidad NO incluido: se suma aparte y va como símbolo.")
    println(io)
    println(io, join(("F_slots", "L_suelo", "D", "rho_max", "L_slots",
        "supA_sin_h", "supA_con_h", "lineas", "nucleos"), '\t'))
    for F in cfg.Fs, Ls in cfg.L_suelos, D in cfg.Ds, rmax in cfg.rho_maxs
        L = L_derivada(F, Ls, cfg.S_max)
        s_sin = sup_A_sin_h(rmax, L, cfg.I, cfg.W_dec, D, cfg.t_obs)
        s_con = sup_A_con_h(rmax, L, cfg.I, cfg.W_dec, D)
        li = lineas_timekeeper(L, cfg.I)
        nn = nucleos_nodo(L, cfg.I, COSTE_VERIFY_SLOT_S)
        println(io, join((F, Ls, D, rmax, L, s_sin, s_con, li, nn), '\t'))
    end
    println(io)

    println(io, "## 3.3 · Cota inferior del tiempo de sellado secuencial adversarial")
    println(io, "# T_seal,adv > sup A. Se publica sup A (slots); la comparación con el hardware")
    println(io, "# del atacante queda como medición pendiente.")
    println(io)
    println(io, join(("F_slots", "L_suelo", "D", "rho_max", "T_seal_adv_min_slots",
        "T_seal_adv_min_horas(si τ=1s)", "coste_honesto_alta_si_igual"), '\t'))
    for F in cfg.Fs, Ls in cfg.L_suelos, D in cfg.Ds, rmax in cfg.rho_maxs
        L = L_derivada(F, Ls, cfg.S_max)
        cs = cota_sellado(rmax, L, cfg.I, cfg.W_dec, D, cfg.t_obs)
        println(io, join((F, Ls, D, rmax, cs, cs / 3600.0, cs / 3600.0), '\t'))
    end
    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

Base.@kwdef mutable struct Config
    rhos::Vector{Float64} = [1.0, 1.0001, 1.001, 1.005, 1.01, 1.05, 1.1, 1.25, 1.5, 2.0, 2.5, 3.0, 5.0, 9.0]
    rho::Float64 = 2.0
    rho_max::Float64 = 2.5
    I::Float64 = 851.0
    Is::Vector{Float64} = [151.0, 300.0, 851.0, 1875.0, 4725.0, 19180.0]
    W_dec::Float64 = 20.0
    D::Float64 = 4.0
    Ds::Vector{Float64} = [0.0, 1.0, 4.0, 15.0, 45.0, 150.0, 300.0, 1000.0]
    S_max::Float64 = 150.0
    F::Float64 = 7200.0
    Fs::Vector{Float64} = [1019.0, 1249.0, 3547.0, 7200.0, 19180.0]
    Fs_bajos::Vector{Float64} = [1019.0, 1249.0, 1800.0, 3547.0, 7200.0, 19180.0]
    L_suelo::Float64 = 0.0
    L_suelos::Vector{Float64} = [0.0, 500.0, 3600.0, 20000.0]
    rho_maxs::Vector{Float64} = [1.5, 2.0, 2.5, 3.0, 5.0, 9.0]
    t_obs::Float64 = 1.0e6
end

function parsear(args::Vector{String})
    cfg = Config()
    modo = "todo"
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--help"
            println("modos: validacion | barrido-rho | barrido-D | regiones | fase2 | fase3 | todo")
            exit(0)
        end
        i == length(args) && error("falta valor para $a")
        v = args[i + 1]
        if a == "--modo"
            modo = v
        elseif a == "--rhos"
            cfg.rhos = lista(v, "rhos")
        elseif a == "--rho"
            cfg.rho = escalar(v, "rho")
        elseif a == "--rho-max"
            cfg.rho_max = escalar(v, "rho-max")
        elseif a == "--rho-maxs"
            cfg.rho_maxs = lista(v, "rho-maxs")
        elseif a == "--I"
            cfg.I = escalar(v, "I")
        elseif a == "--Is"
            cfg.Is = lista(v, "Is")
        elseif a == "--W-dec"
            cfg.W_dec = escalar(v, "W-dec")
        elseif a == "--D"
            cfg.D = escalar(v, "D")
        elseif a == "--Ds"
            cfg.Ds = lista(v, "Ds")
        elseif a == "--S-max"
            cfg.S_max = escalar(v, "S-max")
        elseif a == "--F"
            cfg.F = escalar(v, "F")
        elseif a == "--Fs"
            cfg.Fs = lista(v, "Fs")
        elseif a == "--Fs-bajos"
            cfg.Fs_bajos = lista(v, "Fs-bajos")
        elseif a == "--L-suelo"
            cfg.L_suelo = escalar(v, "L-suelo")
        elseif a == "--L-suelos"
            cfg.L_suelos = lista(v, "L-suelos")
        elseif a == "--t-obs"
            cfg.t_obs = escalar(v, "t-obs")
        elseif a == "--L"
            # solo para la regresión: el modelo vigente deriva L
            cfg.F = escalar(v, "L")
            cfg.L_suelo = 0.0
            cfg.S_max = 0.0
        else
            error("argumento desconocido: $a")
        end
        i += 2
    end
    return modo, cfg
end

function main(args::Vector{String})
    modo, cfg = parsear(args)
    mkpath(RESULTADOS)

    abrir(nombre, f) = open(joinpath(RESULTADOS, nombre), "w") do io
        f(io, cfg)
    end

    entorno = open(joinpath(RESULTADOS, "ENTORNO.txt"), "w")
    entorno_txt(entorno, args)
    close(entorno)

    if modo in ("validacion", "todo")
        abrir("VALIDACION.txt", modo_validacion)
    end
    if modo in ("barrido-rho", "todo")
        abrir("BARRIDO-RHO.tsv", modo_barrido_rho)
    end
    if modo in ("barrido-D", "todo")
        abrir("BARRIDO-D.tsv", modo_barrido_D)
    end
    if modo in ("regiones", "todo")
        abrir("REGIONES.tsv", modo_regiones)
    end
    if modo in ("fase2", "todo")
        abrir("FASE2.tsv", modo_fase2)
    end
    if modo in ("fase3", "todo")
        abrir("FASE3.tsv", modo_fase3)
    end

    println("modo=", modo, " resultados=", RESULTADOS)
    return nothing
end

main(ARGS)
