# GDR-v0.1 — escalado de hilos: entrega de DAGs independientes en paralelo.
# Ejecutar con --threads=N para N ∈ {1,2,4,8,16}. Salida → se anexa a resultados/BENCH.txt
using GhostdagRank
using StableRNGs

params = P_DEFECTO
NTHREADS = Threads.nthreads(:default)
R = 256                       # réplicas independientes (DAGs de n=200)
n = 200

especs_por_replica = Vector{Vector{BloqueEspec}}(undef, R)
for r in 1:R
    especs_por_replica[r] = generar_dag(StableRNG(0xE5CA + UInt64(r)), n)
end

function correr()
    resultados = Vector{Bool}(undef, R)
    Threads.@threads for r in 1:R
        est = entregar(EstadoRapido, params, especs_por_replica[r], collect(1:n), "G")
        tip = virtual_sp(est, params)
        ch = cadena_seleccionada(est, tip)
        u3 = 0
        for c in ch, x in GhostdagRank.ms_reds_de(est, c)
            GhostdagRank.es_rojo_u3(est, c, x) && (u3 += 1)
        end
        resultados[r] = length(orden_aplicacion(est, params, tip)) ==
                        length(est.anc[tip]) + 1 - u3
    end
    all(resultados) || error("fallo en una réplica")
    return nothing
end

correr()                      # compilar
t0 = time_ns()
correr()
dt = (time_ns() - t0) / 1e9
println("escalado: ", NTHREADS, " hilos, ", R, " DAGs de n=", n, ": ", round(dt, digits=2),
        " s (", round(R * n / dt, digits=0), " bloques/s)")
