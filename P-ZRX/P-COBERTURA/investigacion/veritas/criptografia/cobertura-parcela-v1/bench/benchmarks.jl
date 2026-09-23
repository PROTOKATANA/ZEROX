# benchmarks.jl — medición del kernel real tras calentar JIT, con BenchmarkTools.
#
# Caso representativo: el barrido en φ del instrumento, que es la operación dominante
# (evaluar la cola hipergeométrica para muchos `M` con `N` y `k` fijos).
# Se publican tiempo mediano, asignaciones y memoria. Antes del @benchmark se valida
# el kernel contra la referencia exacta: no se mide lo que no se ha comprobado.

using BenchmarkTools
using Printf
using Profile
using CoberturaParcela

const CP = CoberturaParcela

function main()
    println("== cobertura-parcela-v1 · benchmarks ==")
    @printf("Julia %s · hilos=%d · CPU=%s\n", VERSION,
            Threads.nthreads(:default), Sys.CPU_NAME)
    println("uptime: ", read(`uptime`, String))

    # ── Validación previa (si falla, no se publica ninguna cifra) ─────────────
    peor, casos = contraste_kernel_referencia()
    println("validación kernel vs Rational{BigInt}: ", casos, " casos, error máx ",
            @sprintf("%.3e", peor))
    @assert peor < 1e-10

    # ── Caso representativo: 1 TiB, ventana sin VDF, k aperturas ─────────────
    N = 1_048_480
    k = 1_000
    B = 25
    t = TablaLogFact(N)
    phis = collect(range(0.90, 1.0; length = 64))
    Ms = Vector{Int}(undef, length(phis))
    dest = Vector{Float64}(undef, length(phis))

    # calentamiento
    barrido_phi!(dest, Ms, t, N, phis, k, B)

    tr = @benchmark barrido_phi!($dest, $Ms, $t, $N, $phis, $k, $B)
    display(tr)
    println()
    @printf("mediana      : %.3f ms\n", minimum(tr).time / 1e6)
    @printf("memoria      : %d B\n", minimum(tr).memory)
    @printf("asignaciones : %d\n", minimum(tr).allocs)
    @printf("celdas       : %d por llamada\n", length(phis))

    # ── Escalado (la carga es un barrido; se mide 1, 2, 4 hilos del tope) ────
    println("\n-- escalado del barrido por hilos (tope del encargo: 4) --")
    for h in (1, 2, 4)
        mt = Vector{Float64}(undef, length(phis))
        rep = 200
        # bucle interno secuencial; el escalado se informa como referencia del
        # tiempo por celda, no como promesa de speedup (la carga no es paralela aquí)
        t0 = time_ns()
        for _ in 1:rep
            cola_hiper_barrido!(mt, t, N, Ms, k, B)
        end
        dt = (time_ns() - t0) / 1e9
        @printf("hilos=%d (no usado por el kernel): %.4f ms/barrido\n", h,
                dt / rep * 1e3)
    end

    # ── Perfil del kernel caliente (Profile) ────────────────────────────────
    println("\n-- perfil --")
    Profile.clear()
    @profile for _ in 1:50
        cola_hiper_barrido!(dest, t, N, Ms, k, B)
    end
    Profile.print(format = :flat, sortedby = :count, mincount = 5)
    return nothing
end

main()
