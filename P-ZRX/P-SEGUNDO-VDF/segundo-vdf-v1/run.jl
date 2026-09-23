#!/usr/bin/env julia
# ─────────────────────────────────────────────────────────────────────────────
# run.jl — CLI reproducible de la auditoría P-SEGUNDO-VDF.
#
#   julia --project=. --threads=16,0 run.jl --modo todo --seed 0x5a5a
#
# Escribe artefactos en `resultados/`. Ningún parámetro se adopta: todo lo que
# aparece es escenario o frontera derivada.
# ─────────────────────────────────────────────────────────────────────────────
using SegundoVdfV1
using Printf, Dates, Random, StableRNGs, Statistics, Pkg

const DIR = joinpath(@__DIR__, "resultados")
mkpath(DIR)

function arg(nombre, por_defecto)
    i = findfirst(==(nombre), ARGS)
    i === nothing && return por_defecto
    return ARGS[i+1]
end

modo = arg("--modo", "todo")
semilla = parse(UInt64, arg("--seed", "0x5a5a"))
replicas = parse(Int, arg("--replicas", "64"))
J = parse(Int, arg("--epocas", "1500"))
hilos = Threads.nthreads(:default)

function entorno()
    git = try strip(read(`git -C $(dirname(@__DIR__)) rev-parse HEAD`, String)) catch; "n/d" end
    open(joinpath(DIR, "ENTORNO.txt"), "w") do io
        println(io, "Auditoría propuesta: P-ZRX/P-SEGUNDO-VDF/segundo-vdf-v1 (SegundoVdfV1)")
        println(io, "Julia: ", VERSION)
        println(io, "CPU: ", Sys.CPU_NAME, "  hilos lógicos: ", Sys.CPU_THREADS)
        println(io, "RAM total (GiB): ", round(Sys.total_memory() / 2^30, digits = 1))
        println(io, "Hilos Julia (default, interactive): ", Threads.nthreads(:default), ", ",
                Threads.nthreads(:interactive))
        println(io, "Semilla maestra: ", repr(semilla))
        println(io, "git HEAD: ", git)
        println(io, "Fecha: ", Dates.now())
        println(io, "Presupuesto declarado: 24 hilos, 64 GiB RAM, 8 GiB disco temporal")
        println(io, "Pkg.status() del proyecto aislado:")
        Pkg.status(; io = io)
    end
end

# ── defecto 1 ────────────────────────────────────────────────────────────────
function escribir_calibracion(io)
    c = control_historico_h6()
    println(io, "== CONTROL OBLIGATORIO (h.6), escenario histórico ==")
    @printf(io, "L=7200 slots  S_max=150 slots  W_dec=20 s = %d slots (τ_nom=1 s/slot)  ρ_max=2,5\n",
            c.W_dec_slots)
    @printf(io, "Lrev = L − S_max = %d slots\n", c.Lrev)
    println(io, "-- fila histórica (calibra con L en el numerador) --")
    @printf(io, "  I* histórico (continuo) = %.4f  → I entero = %d\n", c.I_historica, c.I_historica_entera)
    @printf(io, "  ρ* con Lrev = %s = %.4f  ≥ ρ_max = %s  ?  %s\n", c.rho_estrella_historica,
            Float64(c.rho_estrella_historica), c.rho_max, c.cumple_historica ? "SÍ" : "NO")
    @printf(io, "  fila publicada (redondeo a 4 767): ρ* = %s = %.4f  ≥ 2,5 ?  NO\n",
            c.rho_estrella_historica_redondeada, Float64(c.rho_estrella_historica_redondeada))
    println(io, "-- frontera corregida (Lrev = L − S_max) --")
    @printf(io, "  I ≤ (Lrev − ρ_max·W_dec)/(ρ_max−1) = %s = %.4f  → I_max = %d\n",
            c.frontera_corregida, Float64(c.frontera_corregida), c.I_corregida)
    @printf(io, "  ρ* con I = %d = %s = %.6f  ≥ 2,5 ?  %s\n", c.I_corregida,
            c.rho_estrella_corregida, Float64(c.rho_estrella_corregida), c.cumple_corregida ? "SÍ" : "NO")
    @printf(io, "  déficit de la fila histórica: %d slots (S_max/(ρ_max−1) = %.1f)\n",
            c.deficit_slots, 150 / 1.5)
    @printf(io, "  otras restricciones: I ≥ ρ_max·W_dec = %.1f ; I > S_max = 151 ⇒ I_min = %d\n",
            2.5 * c.W_dec_slots, c.I_minima)
    @printf(io, "  puntualidad honesta discreta: L − W_dec − D − 1 − Lrev = %.1f (≥0 ⇒ puntual)\n",
            c.holgura_puntualidad)
    @printf(io, "  cotas superiores de ρ_max: √(Lrev/W_dec) = %.3f ; C-FLU-09 = %.3f\n",
            c.rho_max_cota_sqrt, c.rho_max_cota_cflu09)
    e = rho_max_factible_entero(7050, 20, 150)
    @printf(io, "  máximo factible EXACTO con I entero y estas desigualdades: ρ=%s=%.6f en I=%d\n",
            e.rho, Float64(e.rho), e.I)
    println(io)
    println(io, "== SENSIBILIDAD A ρ_max (frontera correcta; ninguna fila se adopta) ==")
    @printf(io, "%8s %14s %10s %8s %6s %10s %8s %8s %8s\n", "rho_max", "frontera", "I_max",
            "I_min", "adm", "rho*", "lineas", "nucleos", "iny/h")
    for f in tabla_calibracion()
        @printf(io, "%8.3f %14.2f %10d %8d %6s %10.4f %8d %8.4f %8.4f\n", f.rho_max,
                f.I_frontera_continua, f.I_max, f.I_min, f.admisible ? "sí" : "NO",
                f.rho_estrella_en_frontera, f.lineas, f.nucleos, f.inyecciones_h)
    end
    println(io, "  √(Lrev/W_dec) es solo condición continua necesaria; con I entero manda 3713/198.")
end

# ── defecto 2 ────────────────────────────────────────────────────────────────
function escribir_escenarios(io)
    println(io, "== CONTROL: filas viejas tal como se publicaron (I mezclado) ==")
    @printf(io, "%48s %14s %10s %6s\n", "fila", "valor", "I", "fuente")
    for f in control_filas_viejas()
        @printf(io, "%48s %14.4f %10.1f %6s\n", f.fila, f.valor, f.I, f.fuente)
    end
    println(io, "  ⇒ la ventana y la edad usan I=851; el coste, I≈4766,7. No es una comparación.\n")
    println(io, "== RECÁLCULO CONSISTENTE: mismo I, L, Lrev, D, W_dec, α, ρ y riesgo ==")
    println(io, "L=7200  Lrev=7050  W_dec=20  D=4  S_max=150  ρ=2,5  α=0,33  J=$(J)  R=$(replicas)")
    @printf(io, "%8s %10s %10s %10s %14s %10s %10s %8s %8s %8s %8s %10s\n",
            "I", "rho*", "cumple", "V_sin", "V_con", "dV/V_sin", "q99_sin", "q99_con",
            "factor", "lineas", "nucleos", "iny/h")
    for f in tabla_escenarios_consistente(J = J, R = replicas, seed = semilla, nthreads = hilos)
        @printf(io, "%8.0f %10.4f %10s %10.2f %14.2f %10.4f %10.0f %8.0f %8.3f %8d %8.4f %10.4f\n",
                f.I, f.rho_estrella, f.cumple_rho ? "sí" : "NO", f.V_sin, f.V_con, f.dV_rel,
                f.q99_sin, f.q99_con, f.factor_edad, f.lineas, f.nucleos, f.inyecciones_h)
    end
end

# ── defecto 3 ────────────────────────────────────────────────────────────────
function escribir_semilla(io)
    println(io, "== DEFECTO 3: dos variantes; ajenas/propias V_max determinista, mixto media de V_max por réplica ==")
    @printf(io, "%8s %9s %12s %14s %15s %11s %11s %12s\n", "I", "patron", "V_sin",
            "V_con[+D]", "V_con[presente]", "dV[+D]", "dV[presente]", "dif_semillas")
    for f in tabla_semilla(J = J, R = replicas, seed = semilla, nthreads = hilos)
        @printf(io, "%8.0f %9s %12.2f %14.2f %15.2f %11.4f %11.4f %12.4f\n", f.I, f.patron,
                f.V_sin, f.V_con_futura, f.V_con_presente, f.dV_futura, f.dV_presente,
                f.dif_entre_semillas)
    end
    println(io)
    println(io, "== fecha en que cada entrada se conoce / grinding / unicidad / circularidad ==")
    for d in datos_causales_semilla()
        println(io, "· ", d.variante)
        println(io, "    ingrediente:        ", d.ingrediente)
        println(io, "    ancla ajena:        ", d.conocido_ancla_ajena)
        println(io, "    ancla propia:       ", d.conocido_ancla_propia)
        println(io, "    grinding:           ", d.grinding)
        println(io, "    unicidad de billete:", d.unicidad_billete)
        println(io, "    circularidad:       ", d.circularidad)
    end
end

# ── §4 regímenes ─────────────────────────────────────────────────────────────
function escribir_regimenes(io)
    println(io, "== REGÍMENES: espera REV-v1.0, línea causal finita, control instantáneo ==")
    @printf(io, "%8s %10s %14s %14s %14s %10s %10s %10s %10s %10s %10s\n", "I", "V_sin",
            "V_espera", "V_causal", "V_ideal", "red_espera", "red_causal", "lin_capacidad",
            "cap_150x1", "cap_150x2", "lin_timekeeper")
    for f in tabla_regimenes(J = J)
        @printf(io, "%8.0f %10.2f %14.2f %14.2f %14.2f %10.4f %10.4f %10d %10d %10d %10d\n", f.I, f.V_sin,
                f.V_monolineal, f.V_paralelo, f.V_ideal,
                f.reduccion_monolineal, f.reduccion_paralelo,
                f.lineas_capacidad, f.lineas_todos, f.lineas_doble_chunk,
                f.lineas_timekeeper)
    end
    println(io, "  control ideal: salida disponible sin ejecutar AES; no es un adversario causal")
    println(io, "  cap_150x{1,2}: capacidad hipotética para 150 slots × variantes de chunk, NO cota del DAG")
end

function escribir_traza_causal(io)
    println(io, "Traza de agenda abstracta, NO validada como DAG C-FLU-03/04/14/21.")
    println(io, "Hipótesis: chunk elegido conocido al alcanzar s_j (o al recibir bloque ajeno); una semilla seleccionada por época.")
    println(io, "Tiempo físico normalizado a τ_nom=1 s; línea 0 es el PoT principal y no cuenta entre las AES de revelación.")
    Jc = 6
    off = zeros(Float64, Jc)
    for (nombre, propias) in (("ajenas", falses(Jc)), ("propias", trues(Jc)),
                              ("mixtas", BitVector([false, true, false, true, false, true])))
        for futura in (true, false)
            cfg = cfg_base(I = 4666.0, con_h = true, semilla_futura = futura,
                           revelacion_paralela = true, lineas_revelacion = 2)
            tr = Tray{Float64}(Jc); eventos = NamedTuple[]
            construir!(tr, cfg, off, propias, 2.5, Jc; traza = eventos)
            println(io, "patrón=", nombre, " semilla=", futura ? "C-FLU-12" : "h.1")
            println(io, "época propia r_PoT r_chunk r_flujo r_recepción r_semilla c_decisión línea inicio fin barrera")
            for e in eventos
                @printf(io, "%d %s %.3f %.3f %.3f %.3f %.3f %.3f %d %.3f %.3f %.3f\n", e.epoca,
                        e.propia, e.pot_conocido, e.chunk_conocido, e.flujo_conocido,
                        e.bloque_recibido, e.semilla_completa, e.decision, e.linea,
                        e.inicio, e.fin, e.barrera)
            end
        end
    end
    println(io, "La especulación sobre variantes de chunk no está enumerada: cardinalidad y validez DAG pendientes.")
end

# ── defecto 5 ────────────────────────────────────────────────────────────────
function escribir_coste(io)
    println(io, "== DEFECTO 5: ¿expresa la primitiva auditada la cadena Lrev·N? ==")
    @printf(io, "prove/verify: NonZeroU32; N %% 16 == 0; 8 checkpoints (%d B); clave = blake3(seed)[0..16)\n",
            PRIMITIVA.bytes_bundle)
    N = N_SLOT_NOMINAL
    @printf(io, "N(slot) nominal = %d iteraciones (1 s a 6,2 GHz, Autonomys)\n", N)
    @printf(io, "mayor Lrev expresable en UNA llamada: %d slots\n", Lrev_max_una_llamada(N))
    for Lrev in (21.0, 300.0, 7050.0)
        s = segmentacion_zxpot(Lrev, N)
        @printf(io, "Lrev=%7.0f  T=%.3e  T/u32=%.1f×  una_llamada=%s  estado=%s\n",
                Lrev, s.T, s.factor_exceso_u32, s.una_llamada ? "sí" : "NO", s.estado)
    end
    println(io, "  segmentar por slots NO conserva la cadena: cada llamada redefine K = blake3(seed)[0..16)")
    println(io, "  vía posible sin reimplementar AES: ", segmentacion_zxpot(7050.0, N).via_correcta)
    println(io, "  aes::create/verify_sequential también usan u32 por tramo: exponerlas solas no basta")
    println(io, "  ⇒ medición de la segunda cadena: PENDIENTE (API pública insuficiente)\n")
    println(io, "== recursos: medidas de UN slot a N=200032000; extrapolación a segunda cadena PENDIENTE ==")
    @printf(io, "%8s %8s %10s %10s %12s %12s %10s %12s %12s\n", "L", "I", "lineas_tk",
            "nuc_PoT", "nuc_verif~", "prove s/ep~", "verify s/ep~", "iny/h", "lin_capacidad")
    for I in (300.0, 851.0, 4666.0, 4725.0)
        c = tabla_coste(7200.0, 7050.0, I, 7200.0)
        @printf(io, "%8.0f %8.0f %10d %10.4f %12.4f %12.1f %10.1f %12.4f %12d\n", 7200.0, I,
                c.lineas_timekeeper, c.nucleos_cadena_principal, c.nucleos_verificador,
                c.prove_s_epoca, c.verify_s_epoca, c.instantes_por_hora,
                c.lineas_capacidad)
    end
end

# ── controles y equivalencia ─────────────────────────────────────────────────
function escribir_controles(io)
    println(io, "== CONTROLES DE REGRESIÓN CONTRA LO PUBLICADO ==")
    for f in control_filas_publicadas()
        @printf(io, "%-8s max|dif| = %.4f   (%s)\n", f.control, f.max_dif, f.fuente)
    end
    println(io)
    println(io, "== CONTROLES INDEPENDIENTES (encargo §3) ==")
    for c in controles_independientes(J = J)
        @printf(io, "%-62s valor = %-12.4f %s\n", c.control, c.valor, c.ok ? "OK" : "FALLA")
    end
    println(io)
    e = equivalencia_oraculo()
    @printf(io, "== ORÁCULO max-plus vs kernel: %d casos, peor |Δτ| = %s ==\n", e.casos, e.peor)
    q = equivalencia_cuantil()
    @printf(io, "== CUANTIL exacto vs muestreo denso: q50_ex=%.6f q50_denso=%.6f Δ=%.6f (%d muestras) ==\n",
            Float64(q.q50_exacto), Float64(q.q50_denso), Float64(q.dif), q.n_muestras)
    println(io, "\n== ESTADOS DEL VERIFICADOR (C-POT-06) ==")
    for (estado, evento) in ((:Pendiente, :presupuesto_agotado), (:Valido, :presupuesto_agotado),
                             (:Pendiente, :aes_falla), (:Pendiente, :n_fuera_dominio),
                             (:Pendiente, :verificacion_exitosa), (:Valido, :sin_evento))
        @printf(io, "  %-10s + %-22s → %s\n", estado, evento, transicion_estado_pot(estado, evento))
    end
end

# ── main ─────────────────────────────────────────────────────────────────────
function main()
    t0 = time()
    entorno()
    partes = modo == "todo" ? ["controles", "calibracion", "escenarios", "semilla", "regimenes", "traza-causal", "coste"] :
             [modo]
    for p in partes
        archivo = joinpath(DIR, uppercase(p) * ".txt")
        tb = time()
        open(archivo, "w") do io
            println(io, "# P-SEGUNDO-VDF · ", p, " · ", Dates.now())
            if p == "controles"
                escribir_controles(io)
            elseif p == "calibracion"
                escribir_calibracion(io)
            elseif p == "escenarios"
                escribir_escenarios(io)
            elseif p == "semilla"
                escribir_semilla(io)
            elseif p == "regimenes"
                escribir_regimenes(io)
            elseif p == "traza-causal"
                escribir_traza_causal(io)
            elseif p == "coste"
                escribir_coste(io)
            else
                error("modo desconocido: $p")
            end
        end
        @printf("modo %-11s → %-38s %.2f s\n", p, relpath(archivo, @__DIR__), time() - tb)
    end
    open(joinpath(DIR, "TIEMPOS.txt"), "a") do io
        @printf(io, "modo=%s hilos=%d seed=%s replicas=%d epocas=%d total=%.2f s  %s\n",
                modo, hilos, repr(semilla), replicas, J, time() - t0, Dates.now())
    end
    @printf("TOTAL %.2f s (%d hilos)\n", time() - t0, hilos)
end

main()
