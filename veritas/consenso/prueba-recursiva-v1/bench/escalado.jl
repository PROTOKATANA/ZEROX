# PRV-v0.1 — escalado por hilos del conteo. Invocar con --threads=N,0 para N ∈ {1,..,24}.
# El conteo de CADA DAG es serial; la independencia está entre DAGs (réplicas), como en LINEO
# §7. No hay BLAS.
using Printf
using StableRNGs
using Base.Threads

include(joinpath(@__DIR__, "..", "src", "PruebaRecursiva.jl"))
using .PruebaRecursiva

GDR = incluir_ghostdag()
const NDAG = 128
const NBLQ = 1024

# Réplicas independientes: un DAG por réplica, semilla derivada del id.
function preparar()
    estados = Vector{Any}(undef, NDAG)
    for r in 1:NDAG
        rng = StableRNG(UInt64(0xE5CA1A) + UInt64(r))
        especs = GDR.generar_dag(rng, NBLQ, "B"; ventana=6)
        estados[r] = Base.invokelatest(construir_estado, GDR, especs)
    end
    return estados
end

function contar_todos(estados)
    cuenta = zeros(Int, NDAG)
    @threads for r in 1:NDAG
        c = contar_rapido(estados[r])
        cuenta[r] = c.n
    end
    return cuenta
end

estados = preparar()
contar_todos(estados)                # calienta JIT
t0 = time()
cuenta = contar_todos(estados)
dt = time() - t0
@printf("hilos=%2d  DAGs=%d  bloques/DAG=%d  %.3f s  bloques/s=%.3e  suma=%d\n",
        nthreads(:default), NDAG, NBLQ, dt, (NDAG * NBLQ) / dt, sum(cuenta))
