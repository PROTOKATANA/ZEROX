#!/usr/bin/env -S echo "ejecutar con ./julia.sh --project=. run.jl"
# FV-1 · run.jl — CLI reproducible. Produce todas las tablas de resultados/.
#
# Línea de ejecución publicada (perfil de esta máquina; ver INFORME.md §Entorno):
#   ./julia.sh --project=. run.jl
#
# Sin argumentos: usa los barridos por defecto de src/modelo.jl (ya elegidos
# para cubrir los casos obligatorios de ORDEN-FV1-DISENO.md §4.C). No hay
# parámetro de producción que fijar aquí: F_slots=7200 (F=2h, SPEC.md §7.3,
# provisional) y tau_s=1 (P-041, λ=1 bloque/s) son símbolos ya usados como tales
# en el resto del repositorio, no una decisión de este informe.

include(joinpath(@__DIR__, "src", "modelo.jl"))
using .Modelo
using Printf
using Dates

const RES = joinpath(@__DIR__, "resultados")
mkpath(RES)

function escribir_tsv(path, filas; campos=nothing)
    isempty(filas) && (open(path, "w") do io; println(io, "# vacío"); end; return)
    cs = campos === nothing ? collect(propertynames(filas[1])) : campos
    open(path, "w") do io
        println(io, join(String.(cs), "\t"))
        for f in filas
            println(io, join([string(getfield(f, c)) for c in cs], "\t"))
        end
    end
end

function main()
    t0 = time()
    println("=== FV-1 · calc/run.jl — ", now(), " ===")
    println("Threads(:default) = ", Threads.nthreads(:default))
    println("VERSION = ", VERSION)

    # ---------------- Bloque 1: quórum con ausencias correlacionadas ----------------
    println("\n[1/4] Quórum con ausencias correlacionadas por tamaño de clave...")
    filas1 = Modelo.barrido_quorum()
    escribir_tsv(joinpath(RES, "b1-quorum-correlado.tsv"), filas1)
    # Tabla de cobertura por tipo de caso (mínimos exigidos por LINEO):
    cobertura1 = [
        (caso="a=0 (sin atacante)", n=count(f -> f.a == 0.10, filas1), minimo=1),
        (caso="pi=1.0 (todos encendidos)", n=count(f -> f.pi == 1.00, filas1), minimo=1),
        (caso="cola=Inf (homogéneo, control)", n=count(f -> f.cola == Inf, filas1), minimo=1),
        (caso="cola=2.2 (H3 de P-CLAVE, más pesimista)", n=count(f -> f.cola == 2.2, filas1), minimo=1),
        (caso="n=100 (pocas claves)", n=count(f -> f.n == 100, filas1), minimo=1),
        (caso="n=10000 (muchas claves)", n=count(f -> f.n == 10_000, filas1), minimo=1),
        (caso="total de celdas", n=length(filas1), minimo=6*4*3*5),
    ]
    escribir_tsv(joinpath(RES, "b1-cobertura.tsv"), cobertura1)

    # Comparación homogéneo vs. cola pesada, a pi fijo: la brecha que la
    # propuesta antigua no midió (§7: "trataba las ausencias como independientes").
    comparacion = NamedTuple[]
    for a in (0.25, 0.30, 0.33), pi_up in (0.90, 0.95, 0.99), n in (1_000,)
        hom = only(filter(f -> f.a==a && f.cola==Inf && f.n==n && f.pi==pi_up, filas1))
        het = only(filter(f -> f.a==a && f.cola==2.2 && f.n==n && f.pi==pi_up, filas1))
        push!(comparacion, (a=a, pi=pi_up, n=n,
                             p_quorum_homogeneo=hom.p_quorum, p_quorum_cola_2_2=het.p_quorum,
                             brecha=hom.p_quorum - het.p_quorum))
    end
    escribir_tsv(joinpath(RES, "b1-brecha-homogeneo-vs-cola.tsv"), comparacion)

    # ---------------- Bloque 2: reproducción cruzada §4.A / §4.D --------------------
    println("[2/4] Reproducción cruzada de §4.A y §4.D (research/dag-poas-capa-finalidad.md)...")
    f4A = Modelo.reproduce_4A(Ks=(1000, 4000), alphas=(0.10, 0.20, 0.25, 0.30, 0.33))
    escribir_tsv(joinpath(RES, "b2-reproduccion-4A.tsv"), f4A)
    f4D = Modelo.reproduce_4D(Ks=(1000, 4000), alphas=(0.25, 0.30, 0.33), ms=(2.955, 151))
    escribir_tsv(joinpath(RES, "b2-reproduccion-4D.tsv"), f4D)

    # Comparación con el diseño SIN sorteo (voto directo ponderado, F3 real):
    sin_sorteo = NamedTuple[]
    for a in (0.10, 0.20, 0.25, 0.30, 0.33, 0.40)
        push!(sin_sorteo, (a=a,
                            pausa_posible_sin_control_red = Modelo.sin_sorteo_pausa_posible(a),
                            sella_mentira_con_control_red = Modelo.sin_sorteo_sella_mentira_posible(a, true),
                            sella_mentira_sin_control_red = Modelo.sin_sorteo_sella_mentira_posible(a, false)))
    end
    escribir_tsv(joinpath(RES, "b2-sin-sorteo-determinista.tsv"), sin_sorteo)

    # ---------------- Bloque 3: certificado ------------------------------------------
    println("[3/4] Tamaño y coste anual del certificado...")
    f3 = Modelo.barrido_certificado()
    escribir_tsv(joinpath(RES, "b3-certificado.tsv"), f3)
    # Certificado de época (light client), 1 vez/hora, M=100000 como cota alta:
    f3b = Modelo.barrido_certificado(Ms=(100_000,), periodos_s=(3600.0,))
    escribir_tsv(joinpath(RES, "b3-certificado-epoca.tsv"), f3b)

    # ---------------- Bloque 4: ventana del doble farmeo -----------------------------
    println("[4/4] Ventana del doble farmeo (tiempo hasta el sello vs F_slots)...")
    f4 = Modelo.barrido_ventana()
    escribir_tsv(joinpath(RES, "b4-ventana-doble-farmeo.tsv"), f4)
    # Caso adversarial: censura que fuerza rondas con backoff, hasta que el
    # tiempo hasta el sello alcanza F_slots (¿cuántas rondas fallidas hacen
    # falta para que la finalidad rápida deje de mejorar sobre C-FIN-01?).
    f4b = Modelo.barrido_ventana(deltas_f=(0.60, 6.0), lookbacks=(10,), rondas=(0,1,2,3,4,5,6,7,8))
    escribir_tsv(joinpath(RES, "b4-censura-rondas.tsv"), f4b)

    dt = time() - t0
    open(joinpath(RES, "ENTORNO.txt"), "w") do io
        println(io, "Fecha: ", now())
        println(io, "VERSION Julia: ", VERSION)
        println(io, "Threads(:default): ", Threads.nthreads(:default))
        println(io, "Threads(:interactive): ", Threads.nthreads(:interactive))
        println(io, "Tiempo total run.jl: ", round(dt, digits=2), " s")
        println(io, "Semillas: ", Modelo.SEMILLAS)
        println(io, "Sys.CPU_NAME: ", Sys.CPU_NAME)
        println(io, "Sys.total_memory (GiB): ", round(Sys.total_memory() / 2^30, digits=1))
    end
    println("\nHecho en ", round(dt, digits=2), " s. Resultados en ", RES)
end

main()
