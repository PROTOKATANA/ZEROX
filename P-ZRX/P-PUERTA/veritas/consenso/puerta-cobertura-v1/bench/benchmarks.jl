# Benchmark de PCO-v0.1 (LINEO §6). Produce `resultados/bench.txt`.
#
# Se mide DESPUES de validar: cada variante imprime tambien su resultado, para que la tabla diga
# «igual que la referencia» y no solo «X veces mas rapido».

using BenchmarkTools
using Printf
using InteractiveUtils
using LinearAlgebra

const AQUI = dirname(@__DIR__)
include(joinpath(AQUI, "src", "PuertaCobertura.jl"))
using .PuertaCobertura
using Arblib

const SALIDA = joinpath(AQUI, "resultados", "bench.txt")

open(SALIDA, "w") do io
    println(io, "# bench PCO-v0.1")
    println(io, "VERSION            = ", VERSION)
    println(io, "CPU                = ", Sys.CPU_NAME)
    println(io, "hilos (:default)   = ", Threads.nthreads(:default))
    println(io, "hilos (:interactive) = ", Threads.nthreads(:interactive))
    println(io, "BLAS threads       = ", BLAS.get_num_threads())
    println(io)

    ft = flujos_transitorio(1//2, 3//5, 1.0, 4.0, 30)
    fr = flujos_regimen(1//2, 3//5, 1.0)
    t = 60.0

    # --- calentar JIT y validar antes de medir
    v_rap = prob_cambio_posterior(ft, t)[1]
    v_ref = prob_cambio_posterior_ref(ft, t)[1]
    v_arb = prob_cambio_posterior_arb(ft, t)
    @assert isapprox(v_rap, v_ref; rtol=1e-9)
    @assert Arblib.contains(v_arb, Arb(v_rap; prec=160)) ||
            abs(Float64(Arblib.midpoint(v_arb)) - v_rap) < 1e-12

    b_ref = @benchmark prob_cambio_posterior_ref($ft, $t) samples=5 evals=1
    b_rap = @benchmark prob_cambio_posterior($ft, $t) samples=200
    b_arb = @benchmark prob_cambio_posterior_arb($ft, $t) samples=5 evals=1

    println(io, "## L(t) en t = $t, transitorio c=1/2 s1=3/5 (r = 1, encierre exacto)")
    println(io, "| Variante | Tiempo mediano | Asignaciones | Bytes | Hilos | Resultado |")
    println(io, "|---|---:|---:|---:|---|---|")
    @printf(io, "| Oraculo BigFloat (`prob_cambio_posterior_ref`) | %.3f ms | %d | %d | 1 CPU | %.14e (fuente de verdad) |\n",
            minimum(b_ref).time / 1e6, minimum(b_ref).allocs, minimum(b_ref).memory, v_ref)
    @printf(io, "| Kernel Float64 (`prob_cambio_posterior`) | %.3f us | %d | %d | 1 CPU | %.14e (igual, rtol 1e-9) |\n",
            minimum(b_rap).time / 1e3, minimum(b_rap).allocs, minimum(b_rap).memory, v_rap)
    @printf(io, "| Certificado Arb 160 bits | %.3f ms | %d | %d | 1 CPU | %s (contiene) |\n",
            minimum(b_arb).time / 1e6, minimum(b_arb).allocs, minimum(b_arb).memory, string(v_arb))
    @printf(io, "\naceleracion kernel/oraculo = %.0f x\n\n",
            minimum(b_ref).time / minimum(b_rap).time)

    # --- coste de L(t) en funcion de t: debe ir como sqrt(t)
    println(io, "## Coste de `prob_cambio_posterior` frente a t (modelo O(sqrt(lambda t)))")
    println(io, "| t | tiempo mediano | asignaciones | t^(1/2) normalizado |")
    println(io, "|---:|---:|---:|---:|")
    base = nothing
    for tt in (10.0, 100.0, 1000.0, 10_000.0, 100_000.0)
        b = @benchmark prob_cambio_posterior($fr, $tt) samples=20
        base === nothing && (base = minimum(b).time / sqrt(tt))
        @printf(io, "| %.0f | %.3f us | %d | %.2f |\n", tt, minimum(b).time / 1e3,
                minimum(b).allocs, (minimum(b).time / sqrt(tt)) / base)
    end
    println(io)

    # --- asignaciones del camino caliente de simulacion
    rng = PuertaCobertura.rng_replica(UInt64(1), 1)
    recorrer(rng, fr, 100.0, 50.0)                       # calentar
    a = @allocated recorrer(PuertaCobertura.rng_replica(UInt64(2), 1), fr, 10_000.0, 500.0)
    println(io, "## Simulacion")
    @printf(io, "asignaciones de `recorrer` sobre 10 000 slots: %d bytes\n", a)
    b_sim = @benchmark recorrer(PuertaCobertura.rng_replica(UInt64(3), 1), $fr, 10_000.0, 500.0) samples=20
    @printf(io, "tiempo mediano: %.3f ms  (%.1f ns por evento, ~%.0f eventos)\n",
            minimum(b_sim).time / 1e6,
            minimum(b_sim).time / (10_000.0 * (fr.λ₁ + fr.λ₂)),
            10_000.0 * (fr.λ₁ + fr.λ₂))
    println(io)

    # --- escalado de hilos: el tope declarado es 2, se mide 1 y 2
    println(io, "## Escalado de hilos (tope declarado: 2; otro agente ocupa 24 en P-2.1)")
    n = 2000
    b1 = @benchmark replicas($fr, 5_000.0, 500.0, $n, UInt64(0x11)) samples=3 evals=1
    @printf(io, "replicas(n=%d, T=5000) con %d hilo(s): %.3f s\n", n,
            Threads.nthreads(:default), minimum(b1).time / 1e9)
    println(io, "Nota: el escalado 1..24 de LINEO §7 NO aplica aqui. El encargo fija un tope de")
    println(io, "2 hilos porque otro agente usa 24 en `P-2.1/`; medir 4..24 habria contaminado su")
    println(io, "banco y habria violado el tope de la maquina. Se declara y no se hace.")
    println(io)

    # --- punto 1: enteros exactos
    println(io, "## Punto 1 (BigInt/Rational exactos)")
    SR = rango_de_piezas(BigInt(10)^9)
    b_peso = @benchmark desviacion_cancelacion($SR) samples=200
    @printf(io, "`desviacion_cancelacion(SR=%s)`: %.3f us, %d asignaciones, resultado %.6e\n",
            string(SR), minimum(b_peso).time / 1e3, minimum(b_peso).allocs,
            Float64(desviacion_cancelacion(SR)))
    println(io, "Es precision arbitraria a proposito: el resultado se decide en el bit 2^-64 y")
    println(io, "Float64 no puede verlo. No hay nada que optimizar aqui, hay algo que no romper.")
end

println(read(SALIDA, String))
