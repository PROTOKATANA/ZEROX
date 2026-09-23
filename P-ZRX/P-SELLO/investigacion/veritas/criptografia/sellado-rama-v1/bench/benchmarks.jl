# benchmarks.jl — tabla de rendimiento (LINEO §6) y asignaciones.
# Uso: JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 julia --project=. bench/benchmarks.jl

using BenchmarkTools
using SelladoRama
const S = SelladoRama
const RB = S.RB

const HW = S.Hardware(t_tabla_s = 0.80913, r_tablas_s = 25.027, hilos = 24,
                      piece_bytes = 1048672)

println("=== sellado-rama-v1 · BENCH ===")
println("julia ", VERSION, " · hilos=", Threads.nthreads(:default),
        " · interactivo=", Threads.nthreads(:interactive))
println("CPU=", Sys.CPU_NAME, " · carga=", strip(read(`uptime`, String)))

# --- 1. kernel de presupuesto (rejilla de Δ) ---
deltas = collect(range(0.10, 0.90; length = 257))
W = zeros(length(deltas)); tasa = zeros(length(deltas))
dmax = zeros(length(deltas)); pad = zeros(length(deltas))
S.kernel_presupuesto!(W, tasa, dmax, pad, deltas, 1.0, 1.0, HW.r_tablas_s; n_puntas = 1.0)
t1 = @benchmark S.kernel_presupuesto!($W, $tasa, $dmax, $pad, $deltas, 1.0, 1.0, $(HW.r_tablas_s); n_puntas = 1.0)
println("\n[kernel_presupuesto!] n=$(length(deltas)) celdas")
show(stdout, MIME"text/plain"(), t1); println()
println("minimum: ", minimum(t1).time, " ns · allocs: ", minimum(t1).allocs,
        " · mem: ", minimum(t1).memory, " B")

# --- 2. kernel de α* ---
bd = collect(range(0.0, 0.5; length = 257))
bx = collect(range(0.0, 0.5; length = 257))
α = zeros(length(bd))
S.kernel_alfa!(α, bd, bx, 1.0, 1.0)
t2 = @benchmark S.kernel_alfa!($α, $bd, $bx, 1.0, 1.0)
println("\n[kernel_alfa!] n=$(length(bd)) celdas")
show(stdout, MIME"text/plain"(), t2); println()
println("minimum: ", minimum(t2).time, " ns · allocs: ", minimum(t2).allocs,
        " · mem: ", minimum(t2).memory, " B")

# --- 3. kernel de materialización ---
frac = zeros(length(deltas)); veces = zeros(length(deltas))
S.kernel_materializacion!(frac, veces, W, S.piezas_por_TiB(HW), HW.r_tablas_s)
t3 = @benchmark S.kernel_materializacion!($frac, $veces, $W, $(S.piezas_por_TiB(HW)), $(HW.r_tablas_s))
println("\n[kernel_materializacion!] n=$(length(W)) celdas")
show(stdout, MIME"text/plain"(), t3); println()
println("minimum: ", minimum(t3).time, " ns · allocs: ", minimum(t3).allocs,
        " · mem: ", minimum(t3).memory, " B")

# --- 4. Monte Carlo de una réplica (modelo de punta) ---
rng = S.StableRNG(S.semilla_replica(UInt64(0x5E110A1A), 1) % UInt64)
S.mc_puntas_una(1.0, 0.30, 200.0, rng)   # calentamiento
t4 = @benchmark S.mc_puntas_una(1.0, 0.30, 2000.0, $rng)
println("\n[mc_puntas_una] H=2000 s (≈2000 bloques)")
show(stdout, MIME"text/plain"(), t4); println()
println("minimum: ", minimum(t4).time, " ns · allocs: ", minimum(t4).allocs,
        " · mem: ", minimum(t4).memory, " B")

# --- 5. oráculo exacto α* vs bisección (comparación de coste) ---
t5 = @benchmark S.alpha_estrella_exacta(RB(1), RB(1), RB(1, 5), RB(1, 5))
t6 = @benchmark S.biseccion_raiz(RB(1), RB(1), RB(1, 5), RB(1, 5); iter = 64)
println("\n[oráculo] α* forma cerrada (Rational{BigInt})")
show(stdout, MIME"text/plain"(), t5); println()
println("minimum: ", minimum(t5).time, " ns · allocs: ", minimum(t5).allocs)
println("\n[oráculo] bisección exacta 64 iteraciones")
show(stdout, MIME"text/plain"(), t6); println()
println("minimum: ", minimum(t6).time, " ns · allocs: ", minimum(t6).allocs)

# --- 6. tabla resumen LINEO §6 ---
println("\n=== TABLA (mediana) ===")
println("variante\tmediana_ns\tasignaciones\tmemoria_B")
for (nom, tr) in (("kernel_presupuesto!(257)", t1), ("kernel_alfa!(257)", t2),
                  ("kernel_materializacion!(257)", t3),
                  ("mc_puntas_una(H=2000)", t4), ("alpha_exacta", t5),
                  ("biseccion_64", t6))
    println(nom, "\t", minimum(tr).time, "\t", minimum(tr).allocs, "\t", minimum(tr).memory)
end
