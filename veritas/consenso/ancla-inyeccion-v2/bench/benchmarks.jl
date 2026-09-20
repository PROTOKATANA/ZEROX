# ANCLA-v0.2 — benchmarks: core-s por réplica a 1 y 24 hilos (JIT fuera del cronómetro),
# celdas representativas (honesta Δ=4 y V1 α=0,33). Salida → resultados/BENCH.txt
using AnclaInyeccion
using AnclaInyeccion.GhostdagRank

println("== BENCH ANCLA-v0.2 ==")
println("julia ", VERSION, " | ", Sys.CPU_NAME, " | hilos: ", Threads.nthreads(:default))

function core_s_por_replica(pr, n::Int, semilla::Integer; solo_primero::Bool=false)
    # calentar fuera del cronómetro
    correr_replica(pr, 1, semilla; solo_primero=solo_primero)
    GC.gc()
    t = @elapsed begin
        for r in 2:n+1
            correr_replica(pr, r, semilla; solo_primero=solo_primero)
        end
    end
    return t / n
end

pr_hon = Params4A(α=0.0, Δ=4.0, via=:honesta)
pr_v1 = Params4A(α=0.33, Δ=4.0, via=:v1)

for (nombre, pr, solo) in (("honesta Δ=4 (9 umbrales)", pr_hon, false),
                           ("V1 α=0,33 (1 umbral, 41 escenarios)", pr_v1, true))
    println("\n-- $nombre --")
    println("réplicas de medida: 20 (honesta) / 5 (V1) tras calentamiento")
    n = solo ? 5 : 20
    t1 = core_s_por_replica(pr, n, 0xB01D; solo_primero=solo)
    println("core-s por réplica (1 hilo):   ", round(t1, digits=3))
    if Threads.nthreads(:default) >= 24
        t24 = core_s_por_replica(pr, n, 0xB01D; solo_primero=solo)
        println("core-s por réplica (24 hilos): ", round(t24, digits=3),
                "  (escalado bruto ×", round(t1*24/t24, digits=2), ")")
    end
end

# asignaciones por réplica (honesta)
pr = pr_hon
correr_replica(pr, 1, 0xB01D)
GC.gc()
a = @allocated correr_replica(pr, 2, 0xB01D)
println("\nasignado por réplica honesta (Δ=4): ", round(a/2^30, digits=3), " GiB")
