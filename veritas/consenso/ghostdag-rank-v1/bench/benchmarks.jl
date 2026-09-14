# GDR-v0.1 — benchmarks del kernel (BenchmarkTools). Salida → resultados/BENCH.txt
using GhostdagRank
using StableRNGs
using BenchmarkTools

println("== BENCH GDR-v0.1 ==")
println("julia ", VERSION, " | ", Sys.CPU_NAME, " | hilos: ", Threads.nthreads(:default))

const P_PARAMS = P_DEFECTO

function bench_tamano(n::Int)
    rng = StableRNG(0xB0E1 + UInt64(n))
    especs = generar_dag(rng, n; ventana=30)
    orden = collect(1:n)
    entregar(EstadoRapido, P_PARAMS, especs, orden, "G")   # compilar/JIT
    trial = @benchmark entregar(EstadoRapido, $P_PARAMS, $especs, $orden, "G") samples = 30
    t = minimum(trial)
    println(rpad(n, 8), lpad(round(t.time / 1e6, digits=2), 16),
            lpad(round(t.time / n / 1e3, digits=2), 9),
            lpad(t.allocs ÷ max(n, 1), 15))
    return nothing
end

println("\n-- coste del kernel por bloque frente al tamaño del DAG (k=30, pesos SR heterogéneos, ventana 30) --")
println("n       tiempo total (ms)   µs/bloque   allocs/bloque")
for n in (100, 200, 400, 800, 1600, 3200)
    bench_tamano(n)
end

function bench_contraste()
    params = P_PARAMS
    especs = generar_dag(StableRNG(0xCAFE), 100)
    orden = collect(1:100)
    entregar(EstadoReferencia, params, especs, orden, "G")
    entregar(EstadoRapido, params, especs, orden, "G")
    t_ref = @benchmark entregar(EstadoReferencia, $params, $especs, $orden, "G") samples = 20
    t_rap = @benchmark entregar(EstadoRapido, $params, $especs, $orden, "G") samples = 20
    println("\n-- oráculo (referencia) frente a kernel en n=100 (contraste) --")
    println("referencia n=100: ", round(minimum(t_ref).time / 1e6, digits=2), " ms total, ",
            round(minimum(t_ref).time / 100 / 1e3, digits=1), " µs/bloque")
    println("kernel     n=100: ", round(minimum(t_rap).time / 1e6, digits=2), " ms total, ",
            round(minimum(t_rap).time / 100 / 1e3, digits=1), " µs/bloque")
    return nothing
end

bench_contraste()

function bench_operaciones()
    println("\n-- operaciones elementales --")
    sr = typemax(UInt64) - 1
    peso_t = @benchmark peso($sr) samples = 10000
    println("peso(SR)          : ", round(minimum(peso_t).time, digits=1), " ns, ",
            minimum(peso_t).allocs, " allocs")
    a = GhostdagRank.BW256(big(2)^200)
    b = GhostdagRank.BW256(big(2)^150)
    bw_t = @benchmark $a + $b samples = 10000
    println("BW256 suma        : ", round(minimum(bw_t).time, digits=1), " ns, ",
            minimum(bw_t).allocs, " allocs")
    return nothing
end

bench_operaciones()
