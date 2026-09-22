# benchmarks.jl — BenchmarkTools tras calentar JIT (LINEO §5.1, §6).
# Mide el kernel dominante (cola de Poisson rigurosa y umbral) y el barrido E3.
using BenchmarkTools
using PermanenciaV1

hw = lectura_hardware(joinpath(@__DIR__, "..", "mediciones", "hardware.tsv"))

# Calentamiento
poisson_cdf_intervalo(BigInt(100), BigInt(1), 120)
umbral_rechazo(BigInt(100), BigInt(1), 1e-3)
barrer_e3!([0.0], [0.0], [0.0], hw, [7200.0], 1.0e6)

println("# permanencia-v1 · benchmarks · julia ", VERSION, " · hilos ", Threads.nthreads(:default))
println("# CPU ", Sys.CPU_NAME)

t1 = @benchmark poisson_cdf_intervalo($(BigInt(100)), $(BigInt(1)), 120)
println("poisson_cdf_intervalo(lambda=100, k=120)   min=", minimum(t1).time / 1e6, " ms  allocs=",
    minimum(t1).allocs, "  mem=", minimum(t1).memory)

t2 = @benchmark umbral_rechazo($(BigInt(100)), $(BigInt(1)), 1e-3)
println("umbral_rechazo(lambda=100, beta=1e-3)      min=", minimum(t2).time / 1e6, " ms  allocs=",
    minimum(t2).allocs, "  mem=", minimum(t2).memory)

t3 = @benchmark periodos_deteccion($(BigInt(100)), $(BigInt(1)), $(BigInt(1)), $(BigInt(2)),
    1e-3, 1e-2; Tmax = 500)
println("periodos_deteccion(lambda=100, s=1/2)      min=", minimum(t3).time / 1e6, " ms  allocs=",
    minimum(t3).allocs, "  mem=", minimum(t3).memory)

ws = rejilla_log(1.0, 1e6, 1000)
cpu = zeros(length(ws))
forz = zeros(length(ws))
tib = zeros(length(ws))
barrer_e3!(cpu, forz, tib, hw, ws, 1.0e6)
t4 = @benchmark barrer_e3!($cpu, $forz, $tib, $hw, $ws, 1.0e6) setup = (fill!($cpu, 0.0))
println("barrer_e3!(1000 puntos)                    min=", minimum(t4).time / 1e6, " ms  allocs=",
    minimum(t4).allocs, "  mem=", minimum(t4).memory)

# Escalado de hilos sobre el eje naturalmente independiente: puntos de la rejilla
using Base.Threads
function barrer_paralelo(hw, ws, N)
    cpu = zeros(length(ws)); forz = zeros(length(ws)); tib = zeros(length(ws))
    @threads for i in eachindex(ws)
        w = ws[i]
        fab = e3_piezas_fabricables(hw, w)
        cpu[i] = N / (hw.r_cpu_tablas_s * w * TAU_S)
        forz[i] = 1 - min(1.0, fab / N)
        tib[i] = fab * hw.bytes_pieza_B / BYTES_POR_TiB
    end
    return nothing
end
barrer_paralelo(hw, ws, 1.0e6)
t5 = @benchmark barrer_paralelo($hw, $ws, 1.0e6)
println("barrer_paralelo(1000 puntos, ", Threads.nthreads(:default), " hilos)   min=",
    minimum(t5).time / 1e6, " ms  allocs=", minimum(t5).allocs, "  mem=", minimum(t5).memory)
