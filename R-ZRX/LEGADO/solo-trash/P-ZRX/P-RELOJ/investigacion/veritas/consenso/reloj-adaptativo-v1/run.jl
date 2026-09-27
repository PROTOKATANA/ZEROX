# run.jl — CLI reproducible del instrumento `reloj-adaptativo-v1`.
#
# Uso (desde ESTA carpeta, como manda `PROMPT.md` §6):
#   ../../veritas/julia.sh --project=. run.jl --todo
#   ../../veritas/julia.sh --project=. run.jl --validar
#   ../../veritas/julia.sh --project=. run.jl --frontera
#   ../../veritas/julia.sh --project=. run.jl --adaptador
#   ../../veritas/julia.sh --project=. run.jl --manipulacion
#   ../../veritas/julia.sh --project=. run.jl --regenerar
#
# Todos los resultados se escriben en `resultados/`, NUNCA en el CWD (`PROMPT.md` §6).
#
# NINGÚN parámetro de ZEROX se fija aquí: los que aparecen en las tablas son EJEMPLOS de barrido,
# declarados como tales en la cabecera de cada fichero de resultados.

using Dates
using RelojAdaptativo
using RelojAdaptativo.Modelos
using RelojAdaptativo.Modelos: MAQUINA_REF, Adaptador, traza_vacia, simular!,
                               hardware_alternante, dispersion_maxima, dispersion_admitida,
                               N_MAX_TIPO, U32_MAX, amplitud_geometrica
using RelojAdaptativo.Rapido
using RelojAdaptativo.Rapido: extremos_ventana, costo_verificacion_maximo, simular_rapido!
using RelojAdaptativo.Referencia
using RelojAdaptativo.Referencia: admisible_exacto, N_max_exacto
using RelojAdaptativo.Validacion

const BigRat = Rational{BigInt}

const DIR_RES = normpath(joinpath(@__DIR__, "resultados"))
const DIR_VEC = normpath(joinpath(@__DIR__, "vectores"))

mkpath(DIR_RES)
mkpath(DIR_VEC)

"Segundos del bloque AES-128 medidos en la máquina de referencia. Es el único `[medido]` propio."
const T_BLOQUE = MAQUINA_REF.lat_bloque

# Escribe SIEMPRE con `write(ruta, contenido)` a partir de un `IOBuffer`: es la ruta que funciona
# en este entorno (el `open(..., "w")` del sandbox de ficheros falla con ENOENT aunque el
# directorio exista).
function escribir_tabla(f, ruta)
    io = IOBuffer()
    f(io)
    mkpath(dirname(ruta))
    write(ruta, take!(io))
    return ruta
end

function cabecera(io, titulo)
    println(io, "# $titulo")
    println(io, "#")
    println(io, "# Generado: ", Dates.now())
    println(io, "# Máquina: ", MAQUINA_REF.nombre)
    println(io, "# Hardware medido: lat_ronda=", MAQUINA_REF.lat_ronda, " s, ",
                "lat_bloque=", MAQUINA_REF.lat_bloque, " s, ",
                "t_bloque_par=", MAQUINA_REF.t_bloque_par, " s, K=", MAQUINA_REF.carriles,
                ", ", MAQUINA_REF.ciclos_por_ronda, " ciclos/ronda, ",
                MAQUINA_REF.ghz_medidos, " GHz")
    println(io, "#")
    println(io, "# TODOS los parámetros de protocolo de este fichero son ENTRADAS de barrido,")
    println(io, "# declaradas como tales. Ninguno es un valor decidido para ZEROX.")
    println(io, "#")
end

# ---------------------------------------------------------------- 1 · frontera

"""
Tabla de la frontera: para cada (`ε`, `K`), la dispersión máxima admitida y el `ρ` mínimo.
`ε` y `K` son ENTRADAS: la tabla es una CURVA, no un punto.
"""
function tabla_frontera()
    ruta = joinpath(DIR_RES, "frontera.md")
    escribir_tabla(ruta) do io
        cabecera(io, "Frontera del presupuesto de verificación — M1")
        println(io, "## 1 · La curva `S_max(ε, K) = ε·K`")
        println(io)
        println(io, "`ρ_max = ε·K` es la dispersión MÁXIMA de hardware que admite el presupuesto, con")
        println(io, "`ρ := t_s/t_f` = cuántas veces más lenta es la máquina más lenta admitida que la más")
        println(io, "rápida. **Es la MISMA cantidad que la frontera `S` y es un TECHO, no un suelo.** La")
        println(io, "nomenclatura coincide con `ρ_max = v_A,max/v_ref` de `SPEC.md` §7.3. Y")
        println(io, "`ε_min = ρ/K` es el presupuesto mínimo que admite una dispersión `ρ`: **crece con `ρ`**.")
        println(io)
        println(io, "| ε | K=4 | K=8 | K=16 |")
        println(io, "|---:|---:|---:|---:|")
        for ε in (0.02, 0.03, 0.05, 0.10, 0.125, 0.20, 0.25, 0.50)
            println(io, "| $(ε) | $(round(dispersion_admitida(ε, 4), digits=4)) | ",
                        "$(round(dispersion_admitida(ε, 8), digits=4)) | ",
                        "$(round(dispersion_admitida(ε, 16), digits=4)) |")
        end
        println(io)
        println(io, "## 1b · `ε_min = ρ/K`, el presupuesto mínimo por dispersión")
        println(io)
        println(io, "| ρ | K=8 | K=16 |")
        println(io, "|---:|---:|---:|")
        for ρ in (1.0, 1.6, 2.0, 3.0, 4.0, 12.0)
            println(io, "| $(ρ) | $(round(100 * RelojAdaptativo.epsilon_minimo(ρ, 8), digits=2)) % | ",
                        "$(round(100 * RelojAdaptativo.epsilon_minimo(ρ, 16), digits=2)) % |")
        end
        println(io)
        println(io, "## 2 · `N_max` con el hardware medido")
        println(io)
        println(io, "`N_max = ε·τ/t_v`. Con `t_v` medido (`verif8.c`: 8 carriles) y `t_v/2` para 16")
        println(io, "carriles (`verif16.c`), para varios `τ`. `τ` es ENTRADA.")
        println(io)
        println(io, "| τ (s) | N_max con K=8 | N_max con K=16 |")
        println(io, "|---:|---:|---:|")
        tv8 = MAQUINA_REF.t_bloque_par
        tv16 = tv8 / 2
        for τ in (0.1, 0.5, 1.0, 2.0, 6.0, 10.0)
            for ε in (0.10,)
                n8 = ε * τ / tv8; n16 = ε * τ / tv16
                println(io, "| $(τ) (ε=$ε) | $(round(n8, sigdigits=6)) | $(round(n16, sigdigits=6)) |")
            end
        end
        println(io)
        println(io, "## 3 · El techo duro del tipo (`C-POT-04`)")
        println(io)
        println(io, "- `u32::MAX` = $(U32_MAX)")
        println(io, "- mayor múltiplo de 16 que cabe = $(N_MAX_TIPO)")
        println(io, "- `N` que satura el tipo con el hardware medido: ",
                    "$(round(Float64(N_MAX_TIPO) * T_BLOQUE, digits=4)) s de producción")
        println(io, "- `N` que satura el tipo a la latencia del 14900KS citada (4,841 ns/bloque): ",
                    "$(round(Float64(N_MAX_TIPO) * 4.841e-9, digits=4)) s")
    end
    return ruta
end

# ---------------------------------------------------------------- 2 · adaptador

"""
Barrido del controlador. La ganancia `g`, el retardo, el periodo y el `duty` son ENTRADAS.
Se mide la amplitud de `N` en unidades y en fracción, y el coste de verificación máximo.
"""
function tabla_adaptador()
    ruta = joinpath(DIR_RES, "adaptador.md")
    T = 4000
    N0 = 200_000_000
    t_rap = T_BLOQUE
    t_len = 1.6 * T_BLOQUE          # 1,6× más lento: dentro del rango medido/citado
    τ = Float64(N0) * t_rap
    escribir_tabla(ruta) do io
        cabecera(io, "Dinámica del adaptador — M3")
        println(io, "## 1 · Caso conectar/desconectar (hardware alternante)")
        println(io)
        println(io, "`N₀ = $N0`, `τ = $(round(τ, digits=4)) s`, hardware 1,6× alternante con")
        println(io, "periodo 200 slots y `duty = 0,5`. Rango de `N`: `[1e6, 8e8]`.")
        println(io)
        println(io, "| ganancia g | retardo (slots) | trinquete | amplitud ΔN | ΔN/N_max | " *
                    "amplitud analítica | coste verif. máx (s) |")
        println(io, "|---:|---:|:---:|---:|---:|---:|---:|")
        for g in (0.05, 0.1, 0.25, 0.5), ret in (1, 5, 50), trin in (false, true)
            hw = hardware_alternante(T, t_rap, t_len, 200, 0.5)
            p = Adaptador(N0, 1_000_000, 800_000_000, t_rap, N0, g, ret, trin, 0, 0)
            t = traza_vacia(T, MAQUINA_REF.t_bloque_par)
            simular!(t, hw, p)
            lo, hi, amp, amprel = Rapido.extremos_ventana(t, 1, T)
            # La amplitud analítica sólo está definida cuando el hardware rápido se va del todo
            # (`lo < hi`); si la traza no cae, la amplitud observada ya es 0 y no hay nada que
            # calcular. Se declara en vez de forzar la fórmula.
            amax = lo < hi ? amplitud_geometrica(hi, lo, g)[1] : 0.0
            cmax = Rapido.costo_verificacion_maximo(t)
            println(io, "| $(g) | $(ret) | $(trin ? "sí" : "no") | $(amp) | ",
                        "$(round(amprel, digits=4)) | $(round(amax, sigdigits=6)) | ",
                        "$(round(cmax, sigdigits=4)) |")
        end
        println(io)
        println(io, "## 2 · Escalado del coste cuando el hardware rápido desaparece")
        println(io)
        println(io, "La amplitud NO la fija la ganancia sola: la fija `N_max·(1 − (1−g)^k)` con `k`")
        println(io, "el número de slots hasta saturar. La fórmula cerrada y la simulación coinciden.")
    end
    return ruta
end

# ---------------------------------------------------------------- 3 · manipulación

"""
Región de manipulación de `N` con timestamps como fuente. `α`, `W`, `δ` (retraso máximo) y `φ`
(FTL, PENDIENTE en ZEROX) son ENTRADAS. `τ_obs` es la ventana observada, también ENTRADA.
"""
function tabla_manipulacion()
    ruta = joinpath(DIR_RES, "manipulacion.md")
    τ_obs = 600.0    # ventana de observación de 600 s: ENTRADA de ejemplo
    escribir_tabla(ruta) do io
        cabecera(io, "Región de manipulación de N — M2")
        println(io)
        println(io, "Fuente: timestamps. Reglas aplicables: `C-TS-01` (monotonía; la relación")
        println(io, "timestamp–slot **sigue pendiente** en `SPEC.md` §7.4), `C-TS-03` (FTL, **valor")
        println(io, "pendiente**), `C-TS-04` (prohíbe la hora de red) y `C-TS-02` (MTP no sustituye")
        println(io, "el índice PoT).")
        println(io)
        println(io, "PARÁMETROS DE EJEMPLO, todos ENTRADAS de barrido: ventana observada")
        println(io, "τ_obs = $(τ_obs) s, retraso máximo por bloque δ = 1 s, FTL φ (se declara en cada tabla).")
        println(io)
        println(io, "## 1 · Umbral de mayoría")
        println(io)
        println(io, "Con `W = 2m+1` la mediana es la posición `m+1`; el adversario la FIJA con")
        println(io, "`C = ⌊α·W⌋ ≥ m+1`, o sea con `α` por encima de:")
        println(io)
        println(io, "| W | α mínimo que fija la mediana |")
        println(io, "|---:|---:|")
        for W in (5, 11, 21, 51, 101, 201)
            println(io, "| $(W) | $(round((W ÷ 2 + 1) / W, digits=4)) |")
        end
        println(io)
        println(io, "## 2 · Sesgo por bloque y factor sobre N")
        println(io)
        println(io, "Sesgo máximo por bloque del adversario: hacia abajo `−min(δ,1)` (cadena monótona o")
        println(io, "posición), hacia arriba `+φ` (FTL). Factor sobre `N`, que escala con `1/τ_obs`:")
        println(io)
        println(io, "| C (bloques del adversario en la ventana) | sesgo abajo (s) | factor N abajo |" *
                    " sesgo arriba con φ=3600 s | factor N arriba |")
        println(io, "|---:|---:|---:|---:|---:|")
        for C in (1, 2, 5, 10, 20, 50, 100)
            sa = -Float64(C) * min(1.0, 1.0)
            sr = Float64(C) * 3600.0
            println(io, "| $(C) | $(sa) | $(round(Modelos.factor_N_por_sesgo(τ_obs, sa), digits=8)) | ",
                        "$(sr) | $(round(Modelos.factor_N_por_sesgo(τ_obs, sr), digits=8)) |")
        end
        println(io)
        println(io, "## 3 · Región por α y W (factor de N hacia abajo, δ = 1 s)")
        println(io)
        println(io, "`C = ⌊α·W⌋`; el sesgo es `−C·min(δ,1)` y el factor `τ_obs/(τ_obs+sesgo)`.")
        println(io)
        αs = [0.10, 0.20, 0.30, 0.40, 0.49, 0.50, 0.55, 0.66, 0.75, 0.90]
        Ws = (11, 51, 201)
        println(io, "| α \\ W | " * join(["W=$W" for W in Ws], " | ") * " |")
        println(io, "|---:|" * repeat("---:|", length(Ws)))
        for α in αs
            fila = "| $(α) | "
            for W in Ws
                C = floor(Int, α * W)
                sa = -Float64(C) * min(1.0, 1.0)
                fila *= "$(round(Modelos.factor_N_por_sesgo(τ_obs, sa), digits=6)) | "
            end
            println(io, fila)
        end
        println(io)
        println(io, "**Lectura:** con `α < 1/2` el adversario no fija la mediana, pero el factor se")
        println(io, "aleja de 1 de forma monótona en `α` y en `W`. Con `α > 1/2` domina la mediana.")
        println(io)
        println(io, "## 4 · Límite declarado de la evidencia")
        println(io)
        println(io, "El oráculo por programación dinámica (`Referencia.sesgo_mediana_dp`) reproduce")
        println(io, "estos números cuando TODOS los bloques del adversario van al final de la ventana y")
        println(io, "son mayoría para fijar la mediana. Fuera de ese régimen su modelo se separa del")
        println(io, "protocolo y **se declara inconcluso**, con el caso concreto que lo rompe:")
        println(io, "`W = 51, C = 48, δ = φ = 0` da mediana 2 s donde la escala honesta daría 25 s, porque")
        println(io, "el oráculo trata los timestamps como una única cadena monótona global y en el")
        println(io, "protocolo cada bloque honesto tiene su propio reloj. **Los números publicados de esta")
        println(io, "sección son los de la aritmética del orden, no los del oráculo**, y la discrepancia")
        println(io, "está contada en `resultados/validacion.md`.")
    end
    return ruta
end

# ---------------------------------------------------------------- 4 · validación

function tabla_validacion()
    r = RelojAdaptativo.validar(completo = true)
    ruta = joinpath(DIR_RES, "validacion.md")
    escribir_tabla(ruta) do io
        cabecera(io, "Validación — equivalencia de rutas, invariantes y bordes")
        println(io, "## Tabla de casos")
        println(io)
        println(io, "La columna `independiente` separa las rutas que calculan por caminos")
        println(io, "GENUINAMENTE distintos de las que sólo comprueban una identidad algebraica")
        println(io, "(§4.5 del encargo).")
        println(io)
        println(io, "| Caso | Vías comparadas | independiente | resultado | detalle |")
        println(io, "|---|---|:---:|:---:|---|")
        for c in r.casos
            println(io, Validacion.linea(c))
        end
        println(io)
        println(io, "**Total: $(r.total) · OK: $(r.ok) · fallos: $(r.fallos) · ",
                    "de ellos con rutas independientes: $(r.independientes).**")
        println(io)
        println(io, "El recuento sale de ESTE artefacto: es el fichero que se entrega.")
    end
    return ruta, r
end

# ---------------------------------------------------------------- 5 · vectores

function regenerar_vectores()
    ruta = joinpath(DIR_VEC, "regresion.csv")
    lineas = String[]
    push!(lineas, "# vectores/regresion.csv — regenerado por run.jl --regenerar")
    push!(lineas, "# Formato: nombre,tp,tv,K,epsilon,admisible")
    push!(lineas, "#   `epsilon` es una EXPRESIÓN de Julia, evaluada al leer: así el vector de frontera")
    push!(lineas, "#   es exactamente tv/(K·tp) y no un decimal escrito a mano.")
    push!(lineas, "#   `admisible` lo calcula la ruta EXACTA (Rational{BigInt}), no el kernel rápido.")
    push!(lineas, "nombre,tp,tv,K,epsilon,admisible")
    # Cada entrada: (nombre, tp, tv, K, expresión de ε)
    casos = [("frontera_exacta_1_3", 1.0, 1.0, 3, "1e0/3e0"),
             ("borde_1_3_prevfloat", 1.0, 1.0, 3, "prevfloat(1e0/3e0)"),
             ("borde_1_3_nextfloat", 1.0, 1.0, 3, "nextfloat(1e0/3e0)"),
             ("frontera_exacta_3_56_K8", 7.0, 3.0, 8, "3e0/56e0"),
             ("borde_3_56_prevfloat", 7.0, 3.0, 8, "prevfloat(3e0/56e0)"),
             ("borde_3_56_nextfloat", 7.0, 3.0, 8, "nextfloat(3e0/56e0)"),
             ("frontera_exacta_1_16_K16", 1.0, 1.0, 16, "1e0/16e0"),
             ("borde_1_16_prevfloat", 1.0, 1.0, 16, "prevfloat(1e0/16e0)"),
             ("presupuesto_10_K8", 7.77e-9, 7.77e-9, 8, "0.1"),
             ("presupuesto_10_K16", 7.77e-9, 7.77e-9, 16, "0.1"),
             ("presupuesto_3_K8", 7.77e-9, 7.77e-9, 8, "0.03"),
             ("presupuesto_3_K16", 7.77e-9, 7.77e-9, 16, "0.03"),
             ("presupuesto_12p5_K8", 7.77e-9, 7.77e-9, 8, "0.125"),
             ("presupuesto_12p5_K16", 7.77e-9, 7.77e-9, 16, "0.125"),
             ("dispersion_2x_K8_eps_20", 1.0, 2.0, 8, "0.2"),
             ("dispersion_4x_K8_eps_20", 1.0, 4.0, 8, "0.2"),
             ("dispersion_4x_K16_eps_25", 1.0, 4.0, 16, "0.25"),
             ("dispersion_8x_K8_eps_50", 1.0, 8.0, 8, "0.5")]
    for (n, tp, tv, K, εexpr) in casos
        ε = BigRat(eval(Meta.parse(εexpr)))
        adm = admisible_exacto(BigRat(tp), BigRat(tv), K, ε)
        push!(lineas, "$(n),$(tp),$(tv),$(K),$(εexpr),$(adm ? 1 : 0)")
    end
    write(ruta, join(lineas, "\n") * "\n")
    return ruta
end

# ---------------------------------------------------------------- main

function main(args)
    hacer_todo = isempty(args) || "--todo" in args
    if "--regenerar" in args
        r = regenerar_vectores()
        println("vectores regenerados: ", r)
    end
    if hacer_todo || "--frontera" in args
        println("frontera: ", tabla_frontera())
    end
    if hacer_todo || "--adaptador" in args
        println("adaptador: ", tabla_adaptador())
    end
    if hacer_todo || "--manipulacion" in args
        println("manipulacion: ", tabla_manipulacion())
    end
    if hacer_todo || "--validar" in args
        ruta, r = tabla_validacion()
        println("validacion: ", ruta, "  (", r.ok, "/", r.total, " OK)")
    end
    return nothing
end


main(ARGS)
