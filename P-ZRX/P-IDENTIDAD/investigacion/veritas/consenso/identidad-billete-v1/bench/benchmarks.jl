# IB-v0.1 — benchmarks (LINEO §6). Caso representativo: DAG de 200 bloques con
# oportunidades del universo declarado.
#
#   JULIA_DEPOT_PATH="<investigacion>/.julia-depot:$HOME/.julia" \
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     ./veritas/julia.sh --project=. --threads=4,0 bench/benchmarks.jl
using BenchmarkTools, StableRNGs, Printf, Dates, Base.Threads
using IdentidadBillete
import GhostdagRank as GDR
const IB = IdentidadBillete
const P0 = GDR.Params()

semilla_replica(maestra::UInt64, r::Integer)::UInt64 = maestra ⊻ (UInt64(r) * 0x9E3779B97F4A7C15)

"DAG determinista de `n` bloques con oportunidades densas (semilla fija)."
function dag_bench(n::Int; semilla::UInt64=UInt64(7))
    rng = StableRNG(semilla)
    especs = IB.BloqueEspec[IB.BloqueEspec("G", Int[],
        IB.solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0))]
    for i in 2:n
        npad = 1 + rand(rng, 0:2)
        padres = unique(Int[rand(rng, 1:(i - 1)) for _ in 1:npad])
        slot = maximum(especs[p].sol.slot for p in padres) + UInt64(rand(rng, 0:1))
        pk = rand(rng, 0:3); sector = rand(rng, 0:1)
        pieza = rand(rng, 0:15); flujo = rand(rng, 0:1)
        push!(especs, IB.BloqueEspec("B$i", padres,
            IB.solucion(pk=pk, sector=sector, historia=0, pieza=pieza, slot=slot,
                        flujo=flujo, sr=rand(rng, 0:3), sd=rand(rng, 0:4096))))
    end
    return especs
end

# sin MC en este fichero (ver bench/escalado.jl)
function wilson(k::Integer, n::Integer; z::Float64=1.96)
    n == 0 && return (0.0, 0.0)
    p = k / n; d = 1 + z^2 / n
    c = (p + z^2 / (2n)) / d; m = z * sqrt(p * (1 - p) / n + z^2 / (4n^2)) / d
    return (max(0.0, c - m), min(1.0, c + m))
end


println("# IB-v0.1 · benchmarks · ", Dates.now())
println("# VERSION=", VERSION, "  hilos=", Threads.nthreads(:default), "/",
        Threads.nthreads(:interactive), "  CPU=", Sys.CPU_NAME)
println("# uptime: ", read(`uptime`, String))

D = dag_bench(200)
println("\n## Corrección primero (LINEO §5.1)")
r = IB.evaluar_rapido(D, IB.MODO_A, P0)
println("DAG de ", length(D) - 1, " bloques → válidos=", length(r.validos),
        " pagables=", length(r.pagables), " identidades=", length(r.entropias))

println("\n## Tabla LINEO §6")
println("| Variante | Tiempo mínimo | Asignaciones | Hilos/backend | Resultado frente al oráculo |")
println("|---|---:|---:|---|---|")
t_ref = @benchmark IB.evaluar_ref($D, IB.MODO_A, $P0)
t_rap = @benchmark IB.evaluar_rapido($D, IB.MODO_A, $P0)
t_bruto = @benchmark IB.evaluar_bruto($D, IB.MODO_A, $P0)
println("| Oráculo GDR (EstadoReferencia) | ", @sprintf("%.3f ms", minimum(t_ref).time / 1e6),
        " | ", minimum(t_ref).allocs, " | 1 CPU | fuente de verdad |")
println("| Kernel GDR + capa pagable indexada | ", @sprintf("%.3f ms", minimum(t_rap).time / 1e6),
        " | ", minimum(t_rap).allocs, " | 1 CPU | idéntico en los 27 casos fixture×modo |")
println("| Kernel GDR + capa pagable por conjuntos | ", @sprintf("%.3f ms", minimum(t_bruto).time / 1e6),
        " | ", minimum(t_bruto).allocs, " | 1 CPU | idéntico en los 27 casos fixture×modo |")
@printf("Speedup kernel/oráculo: %.2f×\n", minimum(t_ref).time / minimum(t_rap).time)

println("\n## Escalado del Monte Carlo: lo mide `bench/escalado.jl` lanzado con")
println("   `--threads=1`, `--threads=2` y `--threads=4` (ver `resultados/ESCALADO.txt`).")
