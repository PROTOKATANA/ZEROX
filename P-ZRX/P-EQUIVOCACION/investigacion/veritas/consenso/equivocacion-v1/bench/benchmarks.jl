# =============================================================================
# benchmarks.jl — microbenchmarks del kernel (LINEO §5.1 y §6)
#   ./veritas/julia.sh --project=. bench/benchmarks.jl
# Calienta JIT antes de medir; interpola con `$`; no usa @fastmath.
# =============================================================================
include(joinpath(@__DIR__, "..", "src", "Equivocacion.jl"))
using .Equivocacion
using BenchmarkTools, Printf, Dates

const E = Equivocacion

# configuración representativa: el contraejemplo, con 20 slots de doble farmeo
function config_representativa()
    I, F, Smax, dpt = 20, 20, 15, 19
    L = max(F, Smax + 1)
    comun = collect(0:4:I + 1)
    idx = findlast(<=(I - 5), comun)
    publica = collect(I + 2:1:I + 1 + dpt)
    privada = vcat(collect(I - 5 + 4:4:I + 1), collect(I + 2:1:I + 1 + dpt))
    dag, P, A, B = construir_dos_ramas(slots_comun = comun, idx_fork = idx,
        slots_publica = publica, slots_privada = privada,
        I_slots = I, L = L, S_max = Smax, fusionar = :P)
    return dag, P, A, B, I, L, F, Smax
end

function main()
    dag, P, A, B, I, L, F, Smax = config_representativa()
    u = Universo(npiezas = 32, nchunks = 4, npruebas = 1, rango = rango_para_media(128, 0.5))
    activos = vista_epoca(dag, B, I, L)
    pd = PreDag(dag); buf = Buffers(pd.n)

    # calentamiento (JIT) y validación antes de medir
    @assert ancla_epoca(dag, B, I, L, 30) == E.ancla_ref(dag, B, I, L, 30)[1]
    @assert kappa(dag, A, B, P, u; I_slots = I, L = L, F_slots = F, jmax = 6, k = 30,
                  s0 = dag.bloques[P].slot).slots > 0

    println("## EQUIV-v0.1 — benchmark del kernel  (", Dates.now(), ")")
    println("Julia ", VERSION, " · hilos ", Threads.nthreads(), " · cpu ", Sys.CPU_NAME)
    println("DAG: ", nbloques(dag), " bloques · I=", I, " L=", L, " F=", F, " S_max=", Smax)
    println()
    println("| variante | tiempo mediano | asignaciones | memoria | hilos |")
    println("|---|---:|---:|---:|---:|")

    t1 = @benchmark seleccion_vista($dag, $activos, 30)
    @printf("| `seleccion_vista` (base) | %s | %d | %s | 1 |\n",
            string(minimum(t1).time), minimum(t1).allocs,
            string(round(minimum(t1).memory / 1024, digits = 2), " KiB"))

    t2 = @benchmark ancla_epoca($dag, $B, $I, $L, 30)
    @printf("| `ancla_epoca` (base) | %s | %d | %s | 1 |\n",
            string(minimum(t2).time), minimum(t2).allocs,
            string(round(minimum(t2).memory / 1024, digits = 2), " KiB"))

    @benchmark E.vista_epoca!($buf, $pd, $B, $I, $L)
    tip = E.seleccion_vista!(buf, pd, 30)
    t3 = @benchmark E.seleccion_vista!($buf, $pd, 30)
    @printf("| `seleccion_vista!` (preasignado) | %s | %d | %s | 1 |\n",
            string(minimum(t3).time), minimum(t3).allocs,
            string(round(minimum(t3).memory / 1024, digits = 2), " KiB"))

    s0 = dag.bloques[P].slot
    t4 = @benchmark kappa($dag, $A, $B, $P, $u; I_slots = $I, L = $L, F_slots = $F,
                          jmax = 6, k = 30, s0 = $s0)
    @printf("| `kappa` (20 slots, 128 candidatos) | %s | %d | %s | %d |\n",
            string(minimum(t4).time), minimum(t4).allocs,
            string(round(minimum(t4).memory / 1024, digits = 2), " KiB"), Threads.nthreads())

    println()
    println("Detalle `seleccion_vista`: ", t1)
    println("Detalle `kappa`: ", t4)
end

main()
