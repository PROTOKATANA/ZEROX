# GDR-v0.1 — perfil del kernel (Profile). Salida → resultados/PERFIL.txt
using GhostdagRank
using StableRNGs
using Profile

params = P_DEFECTO
rng = StableRNG(0xDEAF)
n = 1000
especs = generar_dag(rng, n)
est = entregar(EstadoRapido, params, especs, collect(1:n), "G")   # compilar

println("== PERFIL GDR-v0.1 ==")
println("julia ", VERSION, " | ", Sys.CPU_NAME, " | hilos: ", Threads.nthreads(:default))

function correr_perfil(especs, n, params)
    for _ in 1:100
        entregar(EstadoRapido, params, especs, collect(1:n), "G")
    end
    return nothing
end

Profile.clear()
@profile correr_perfil(especs, n, params)
Profile.print(format=:flat, sortedby=:count, mincount=30)
println()
println("(el perfil es de 20 entregas completas de un DAG de n=", n, "; ",
        "el coste de entregar/validar es el objetivo)")
