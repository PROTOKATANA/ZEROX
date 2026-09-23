# run.jl — CLI reproducible de TR-v0.1.  No es un notebook.
#
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --seed 0x524956414c
#
# Escribe artefactos en resultados/.  Nada de lo que aquí se publica fija θ, β_d,
# β_x, α, ρ, c ni la dificultad: son entradas y salen como columnas.

using Printf
using Dates

include(joinpath(@__DIR__, "src", "modelo.jl"))
include(joinpath(@__DIR__, "src", "referencia.jl"))
include(joinpath(@__DIR__, "src", "rapido.jl"))
include(joinpath(@__DIR__, "src", "validacion.jl"))

const RES = joinpath(@__DIR__, "resultados")
mkpath(RES)

function escribir(nombre::String, cabecera::Vector{String}, filas::Vector{Vector{String}})
    ruta = joinpath(RES, nombre)
    open(ruta, "w") do io
        println(io, join(cabecera, '\t'))
        for f in filas
            println(io, join(f, '\t'))
        end
    end
    return ruta
end

fmt(x::Rational) = string(numerator(x), "/", denominator(x))
fmt(x::Integer) = string(x)
fmt(x::AbstractFloat) = @sprintf("%.6g", x)

# ---------------------------------------------------------------------------
# F1 · «Rival» formalizado (tabla de definiciones y procedencia)
# ---------------------------------------------------------------------------
function tarea_f1()
    filas = Vector{String}[]
    push!(filas, ["PoW por bloque (reto ligado a los padres)", "sí",
                  "superaditiva: coste(∪H_i) ≥ Σ coste(H_i)",
                  "el intento (nonce, padres) sirve a UNA historia",
                  "P-ANCESTRIA F1.2 (oráculo aleatorio); balizas:72-73",
                  "demostrado"])
    push!(filas, ["lectura de disco con reto independiente de la ancestría", "no",
                  "reutilizable: coste(∪H_i) ≈ max_i coste(H_i)",
                  "una lectura vale para toda la clase de transferencia",
                  "P-ANCESTRIA F1.4; P-PRESTAMO §1",
                  "demostrado"])
    push!(filas, ["VDF por rama", "no (peaje por rama)",
                  "coste ∝ nº de ramas, no de intentos",
                  "el trabajo no escala con el peso duplicado",
                  "PROMPT §2.1; P-TASA §2.3 (R2)",
                  "derivado"])
    push!(filas, ["trabajo rival ligado a los padres (la pata propuesta)", "sí",
                  "coste ∝ intentos = peso producido",
                  "cada bloque de la segunda rama exige intentos nuevos",
                  "PROMPT §0; este instrumento",
                  "propuesto"])
    push!(filas, ["26,8941 % de «trunks»", "no aplica a la pata",
                  "cota de grinding con re-muestreo GRATIS (c = 1, φ₁ = e)",
                  "un PoW no re-muestrea gratis: cada reintento cuesta del presupuesto rival",
                  "research/dag-poas-ancla-de-finalidad.md:313-319; P-ANCESTRIA F2.3",
                  "derivado (condicional a que el reintento consuma el recurso)"])
    escribir("F1-rival.tsv",
             ["recurso", "¿rival?", "ley de coste", "por qué", "fuente", "etiqueta"], filas)
    return filas
end

# ---------------------------------------------------------------------------
# F2 · Composiciones y control θ = 0
# ---------------------------------------------------------------------------
function tarea_f2()
    filas = Vector{String}[]
    for β_d in (R(0), R(1)//10, R(1)//4, R(1)//2), β_x in (R(0), R(1)//10)
        2 * β_x + β_d <= 1 || continue
        for θ in (R(0), R(1)//10, R(1)//4, R(1)//2, R(9)//10)
            for ρ in (R(1)//2, R(1), R(3)//2)
                a = alpha_aditivo(β_d, β_x, θ, ρ)
                g0 = g_aditivo_desde_tasas(a, β_d, β_x, θ, ρ)
                control = alpha_control_prestamo(β_d, β_x)
                push!(filas, [fmt(β_d), fmt(β_x), fmt(θ), fmt(ρ), fmt(a),
                              fmt(g0), fmt(control),
                              a == control ? "=control" : "≠control",
                              "aditiva"])
            end
        end
    end
    # multiplicativa (θ con denominador 10 y 2) con ρ iguales: no cambia la frontera
    for β_d in (R(0), R(1)//4, R(1)//2), β_x in (R(0), R(1)//10)
        2 * β_x + β_d <= 1 || continue
        for θ in (R(0), R(1)//4, R(1)//2)
            a = alpha_multiplicativo_biseccion(β_d, β_x, θ, _ -> R(1), _ -> R(1))
            push!(filas, [fmt(β_d), fmt(β_x), fmt(θ), "1", fmt(a), "0",
                          fmt(alpha_control_prestamo(β_d, β_x)),
                          abs(a - alpha_control_prestamo(β_d, β_x)) <= R(1)//2^30 ?
                              "=control" : "≠control",
                          "multiplicativa (ρ iguales)"])
        end
    end
    escribir("F2-composiciones.tsv",
             ["β_d", "β_x", "θ", "ρ", "α*", "g(α*)", "control θ=0", "frente al control",
              "composición"], filas)
    return filas
end

# ---------------------------------------------------------------------------
# F3 · θ*(β_d): tres lecturas exactas de «deja de dar ventaja»
#   (a) marginal:  V(β_d) no baja en ningún θ < 1
#   (b) imposibilidad: α*(β_d) > 1  ⇒ θ > (1+β_d+2β_x)/(2−ρ+β_d+2β_x) ≥ 1/2
#   (c) económica: el granjero no gana  ⇒ (1−θ) ≤ c(p_v − θ)
# ---------------------------------------------------------------------------
function tarea_f3()
    filas = Vector{String}[]
    for β_d in (R(1)//100, R(1)//10, R(1)//4, R(1)//2, R(9)//10),
        β_x in (R(0), R(1)//10)
        2 * β_x + β_d <= 1 || continue
        for ρ in (R(0), R(1)//2, R(9)//10, R(1), R(3)//2)
            θ_imp = theta_cierre_imposible(β_d, β_x, ρ)
            for c in (R(0), R(1)//2, R(1), R(2))
                t_marg = theta_estrella_marginal(c)
                θ_ec = theta_estrella_economico(c, R(1))
                push!(filas, [fmt(β_d), fmt(β_x), fmt(ρ), fmt(c),
                              fmt(ventaja_beta_d(R(0), c)),
                              t_marg === missing ? "no existe en [0,1)" : fmt(t_marg),
                              θ_imp === missing ? "no existe (ρ ≥ 1)" : fmt(θ_imp),
                              θ_ec === missing ? "no existe en [0,1)" : fmt(θ_ec),
                              θ_imp === missing ? "la pata ayuda al atacante" :
                              (θ_imp > R(1)//2 ? "θ* > 1/2: sin θ útil" : "θ* = 1/2 en el límite")])
            end
        end
    end
    escribir("F3-theta-estrella.tsv",
             ["β_d", "β_x", "ρ", "c", "V por unidad de β_d (θ=0)",
              "θ* marginal", "θ* imposibilidad", "θ* económico (p_v=1)", "lectura"],
             filas)
    return filas
end

function tarea_f3b()
    filas = Vector{String}[]
    for ρ_priv in (R(1)//10, R(1)//2, R(1), R(2)),
        β_d in (R(1)//10, R(1)//2), β_x in (R(0), R(1)//10),
        θ in (R(0), R(1)//10, R(1)//4, R(1)//2, R(3)//4, R(9)//10)
        a = alpha_multiplicativo_cerrado(Float64(β_d), Float64(β_x), Float64(θ),
                                         Float64(ρ_priv), 1.0)
        v = ventaja_multiplicativa(Float64(β_d), Float64(β_x), Float64(θ),
                                   Float64(ρ_priv), 1.0)
        push!(filas, [fmt(β_d), fmt(β_x), fmt(ρ_priv), "1", fmt(θ),
                      @sprintf("%.6f", a), @sprintf("%.6f", v),
                      ρ_priv < 1 ? "ρ_pub>ρ_priv: V decrece" :
                      (ρ_priv == 1 ? "ρ iguales: V constante" : "ρ_pub<ρ_priv: V crece")])
    end
    escribir("F3b-multiplicativa.tsv",
             ["β_d", "β_x", "ρ_priv", "ρ_pub", "θ", "α* multiplicativo",
              "V multiplicativa", "signo"], filas)
    return filas
end

# ---------------------------------------------------------------------------
# F4 · α*(θ), desplazamiento de nivel y efecto perverso β_x
# ---------------------------------------------------------------------------
function tarea_f4()
    filas = Vector{String}[]
    for β_d in (R(0), R(1)//4, R(1)//2), β_x in (R(0), R(1)//10, R(1)//5)
        2 * β_x + β_d <= 1 || continue
        for θ in (R(0), R(1)//10, R(1)//4, R(1)//2, R(3)//4, R(9)//10), ρ in (R(1)//2, R(1), R(2))
            a = alpha_aditivo(β_d, β_x, θ, ρ)
            control = alpha_control_prestamo(β_d, β_x)
            push!(filas, [fmt(β_d), fmt(β_x), fmt(θ), fmt(ρ), fmt(a), fmt(control),
                          fmt(a - control),
                          fmt(-(β_d + 2 * β_x) // 2),   # ventaja de umbral (constante)
                          "∂α*/∂β_d = −1/2; ∂α*/∂β_x = −1 (β_x vale el doble)"])
        end
    end
    escribir("F4-alpha-theta.tsv",
             ["β_d", "β_x", "θ", "ρ", "α*", "control θ=0", "desplazamiento de nivel",
              "ventaja de umbral", "nota"], filas)
    return filas
end

# ---------------------------------------------------------------------------
# F5 · Coste: tasa de hash, vatios y comparación con el disco
# ---------------------------------------------------------------------------
function tarea_f5(; e_hash = 8.2e-7, t_plot = 83.608, P_plot = 100.0,
                  T_vida = 3.156e7, C = 1000.0, N = 1.048576e6, λ = 1.0)
    filas = Vector{String}[]
    for θ in (0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.99)
        H = tasa_hash_red(θ, N, C, λ)
        P = vatios_pow(θ, N, C, λ, e_hash)
        Pe = vatios_espacio(N, t_plot, P_plot, T_vida)
        r = P / Pe
        # núcleos necesarios para el agricultor doméstico de 100 TiB
        nucleos = nucleos_necesarios(tasa_hash_red(θ, 100 * 1024.0, C, λ), 1.82e7)
        push!(filas, [@sprintf("%.2f", θ), @sprintf("%.3e", H), @sprintf("%.3e", P),
                      @sprintf("%.3e", Pe), @sprintf("%.3e", r),
                      @sprintf("%.2f", nucleos)])
    end
    escribir("F5-coste.tsv",
             ["θ", "hash/s de red", "vatios PoW", "vatios espacio (amortizado)",
              "razón PoW/espacio", "núcleos para 100 TiB"], filas)
    # tabla de sensibilidad a e_hash
    filas2 = Vector{String}[]
    for e in (8.2e-7, 8.2e-9, 8.2e-11)
        for θ in (0.10, 0.50)
            r = coste_relativo(θ, N, C, λ, e, t_plot, P_plot, T_vida)
            push!(filas2, [@sprintf("%.2e", e), @sprintf("%.2f", θ), @sprintf("%.3e", r),
                           e == 8.2e-7 ? "CPU: 1,82e7 hash/s por hilo (medido en el repo) × 15 W/hilo (supuesto)" :
                           (e == 8.2e-9 ? "GPU/ASIC intermedio (supuesto)" :
                                          "ASIC (supuesto)")])
        end
    end
    escribir("F5b-sensibilidad-ehash.tsv",
             ["e_hash (J/hash)", "θ", "razón PoW/espacio", "escenario"], filas2)
    # comparación con ALMACENAR el mismo peso (potencia del disco, supuestos declarados)
    filas3 = Vector{String}[]
    for (medio, w_tib) in (("SSD (supuesto 0.1 W/TiB en reposo)", 0.1),
                           ("HDD (supuesto 5 W/TB en reposo)", 5.0))
        almacenamiento = N / 1024.0 * w_tib   # N GiB → TiB
        for e in (8.2e-7, 8.2e-11)
            for θ in (0.10, 0.50)
                p = vatios_pow(θ, N, C, λ, e)
                push!(filas3, [medio, @sprintf("%.2e", e), @sprintf("%.2f", θ),
                               @sprintf("%.3e", p), @sprintf("%.3e", almacenamiento),
                               @sprintf("%.3e", p / almacenamiento)])
            end
        end
    end
    escribir("F5c-disco.tsv",
             ["medio (supuesto)", "e_hash", "θ", "vatios PoW", "vatios almacenamiento",
              "razón PoW/almacenamiento"], filas3)
    return filas
end

# ---------------------------------------------------------------------------
# F6 · Dicotomía
# ---------------------------------------------------------------------------
function tarea_f6()
    filas = Vector{String}[]
    for c in (R(0), R(1)//2, R(1), R(2))
        push!(filas, [fmt(c), "no existe en [0,1)", fmt(ventaja_marginal_aditiva(R(1)//2, c)),
                      "aditiva: la pata no anula la ventaja: 1 + θ(c−1) ≥ 0",
                      c == 0 ? "degenerado: hace falta θ = 1 y el espacio deja de pesar" :
                               "la compuerta amplifica o deja igual la ventaja"])
    end
    push!(filas, ["multiplicativa (ρ_pub>ρ_priv)", "V decrece pero V>0",
                  @sprintf("%.6f", ventaja_multiplicativa(0.1, 0.1, 0.5, 0.5, 1.0)),
                  "k = (ρ_pub/ρ_priv)^(θ/(1−θ)); V = [β_d+β_x(1+k)]/(1+k) → β_x",
                  "θ<1/2 diluye la ventaja, pero exige mayoría de trabajo del honesto " *
                  "(ρ_pub>ρ_priv) y el atacante puede comprarla: carrera de hash"])
    push!(filas, ["multiplicativa (ρ_pub<ρ_priv)", "no existe en [0,1)",
                  @sprintf("%.6f", ventaja_multiplicativa(0.1, 0.1, 0.5, 2.0, 1.0)),
                  "el atacante con más trabajo ve CRECER la ventaja con θ",
                  "la pata ayuda al atacante"])
    push!(filas, ["umbral (trabajo fuera del peso)", "no existe en [0,1)",
                  fmt(ventaja_beta_x(R(1)//2, R(0))), "V = β_d/2 + β_x, sin factor de compuerta",
                  "el grifo no cambia la frontera; solo añade coste"])
    escribir("F6-dicotomia.tsv",
             ["c / composición", "θ* (seguridad)", "ventaja en θ=1/2", "razón", "consecuencia"],
             filas)
    return filas
end

# ---------------------------------------------------------------------------
# Control explícito (encargo §4)
# ---------------------------------------------------------------------------
function control()
    println("CONTROL OBLIGATORIO θ = 0")
    ok = true
    for (β_d, β_x) in ((R(1)//10, R(0)), (R(1)//4, R(1)//10), (R(1)//2, R(1)//5))
        a = alpha_aditivo(β_d, β_x, R(0), R(3)//2)
        c = alpha_control_prestamo(β_d, β_x)
        g0 = g_aditivo_desde_tasas(a, β_d, β_x, R(0), R(3)//2)
        coincide = a == c && g0 == 0
        ok &= coincide
        @printf("  β_d=%s β_x=%s  α*=%s  (1−β_d−2β_x)/2=%s  g(α*)=%s  %s\n",
                fmt(β_d), fmt(β_x), fmt(a), fmt(c), fmt(g0), coincide ? "OK" : "FALLO")
    end
    println(ok ? "CONTROL: θ=0 reproduce α* = (1 − β_d − 2β_x)/2  -> OK" :
                 "CONTROL: FALLO")
    return ok
end

function main()
    args = Dict{String,Vector{String}}()
    i = 1
    while i <= length(ARGS)
        a = ARGS[i]
        if startswith(a, "--")
            clave = a[3:end]
            vals = String[]
            i += 1
            while i <= length(ARGS) && !startswith(ARGS[i], "--")
                push!(vals, ARGS[i]); i += 1
            end
            args[clave] = vals
        else
            i += 1
        end
    end
    semilla = haskey(args, "seed") ? parse(UInt64, args["seed"][1]) : UInt64(0x524956414c)
    tareas = haskey(args, "tarea") ? args["tarea"] :
             ["f1", "f2", "f3", "f3b", "f4", "f5", "f6"]
    log = joinpath(RES, "CORRIDA.log")
    open(log, "w") do io
        println(io, "TR-v0.1 · ", now(), " · semilla=", semilla,
                " · Julia ", VERSION, " · hilos=", Threads.nthreads())
        println(io, "CPU=", Sys.CPU_NAME, " · ", Sys.total_memory() ÷ 2^30, " GiB")
    end
    if haskey(args, "control")
        control() || error("control falló")
    end
    for t in tareas
        t == "f1" && tarea_f1()
        t == "f2" && tarea_f2()
        t == "f3" && tarea_f3()
        t == "f3b" && tarea_f3b()
        t == "f4" && tarea_f4()
        t == "f5" && tarea_f5()
        t == "f6" && tarea_f6()
        println("tarea ", t, " hecha")
    end
    open(log, "a") do io
        println(io, "fin: ", now())
    end
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
