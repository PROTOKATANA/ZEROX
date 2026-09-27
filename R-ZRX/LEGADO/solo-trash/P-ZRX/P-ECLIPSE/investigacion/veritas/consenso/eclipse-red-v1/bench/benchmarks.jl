#= benchmarks.jl — caso representativo, tras calentar JIT (LINEO §5.1 y §6).

Ejecutar:
    JULIA_DEPOT_PATH=<depot> /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl

Mide el coste de UNA simulación completa con el horizonte del encargo (900 s, ~900 bloques), que es
la unidad de trabajo del barrido. No mide un juguete: es la corrida que se repite 12 veces por
celda de la rejilla.
=#

using BenchmarkTools
using Printf

const AQUI = @__DIR__
include(joinpath(AQUI, "..", "src", "pyrng.jl"))
include(joinpath(AQUI, "..", "src", "GDR.jl"))
include(joinpath(AQUI, "..", "src", "mundo.jl"))
using .Mundo
const G = GDR.GhostdagRank

const HOR = 900.0

function caso_control(alpha, sem)
    p = ParametrosMundo(alpha, HOR, sem)
    ev = calendario(alpha, HOR, sem)
    sim = Sim(p, ev)
    return corre_control!(sim, 200.0; fc = 0.05)
end

function caso_retraso(alpha, sem, E)
    p = ParametrosMundo(alpha, HOR, sem)
    ev = calendario(alpha, HOR, sem)
    sim = Sim(p, ev)
    return corre_victima!(sim, :retraso, 0.05; E = E, t_ecl = 300.0)
end

function main()
    println("== BENCH eclipse-red-v1 ==")
    println("julia ", VERSION, " | ", Sys.CPU_NAME, " | hilos default=",
            Threads.nthreads(:default))

    # Calentamiento explícito: JIT y primera asignación de buffers.
    caso_control(0.0, 1); caso_control(0.25, 1)
    caso_retraso(0.0, 1, 200.0)

    for (nom, f, alpha, E) in (("control α=0,00 E=200", caso_control, 0.0, 200.0),
                               ("control α=0,25 E=200", caso_control, 0.25, 200.0))
        t = @benchmark caso_control($alpha, 1) samples = 20 evals = 1
        @printf("%-22s  mediana %8.2f ms | allocs %6d | memoria %8.2f MiB\n", nom,
                minimum(t).time / 1e6, minimum(t).allocs, minimum(t).memory / 2^20)
    end
    for E in (20.0, 60.0, 200.0)
        t = @benchmark caso_retraso(0.0, 1, $E) samples = 20 evals = 1
        @printf("%-22s  mediana %8.2f ms | allocs %6d | memoria %8.2f MiB\n",
                "iii E=$(Int(E)) α=0,00", minimum(t).time / 1e6, minimum(t).allocs,
                minimum(t).memory / 2^20)
    end

    # Coste del barrido completo de régimen: 8 configuraciones × 12 semillas de control.
    t0 = time()
    n = 0
    for delta in (4.0, 0.60), reg in (:conteo, :sr)
        for sem in 1:12
            p = ParametrosMundo(0.0, HOR, sem; delta = delta, regimen = reg)
            corre_control!(Sim(p, calendario(0.0, HOR, sem)), 200.0; fc = 0.05)
            n += 1
        end
    end
    @printf("barrido de control: %d corridas en %.1f s (%.3f s/corrida)\n", n, time() - t0,
            (time() - t0) / n)

    # Tamaño del problema.
    p = ParametrosMundo(0.0, HOR, 1)
    sim = Sim(p, calendario(0.0, HOR, 1))
    corre_control!(sim, 200.0; fc = 0.05)
    @printf("tamaño del caso representativo: %d bloques en el DAG, horizonte %.0f s\n",
            sim.est.n, HOR)
end

main()
