#= retencion-clave-v1 · bench/benchmarks.jl
   Tabla de rendimiento de LINEO §6: tiempo mediano, asignaciones, hilos y comparación con la
   referencia. Se anota `uptime` antes de cada bloque (PROMPT: «Anota `uptime` antes de cada
   benchmark»).

   Uso:
     JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 veritas/julia.sh --project=. bench/benchmarks.jl
=#

using BenchmarkTools
using Printf
using StableRNGs: StableRNG

const DIR = @__DIR__
include(joinpath(DIR, "..", "src", "modelo.jl"))
include(joinpath(DIR, "..", "src", "referencia.jl"))
include(joinpath(DIR, "..", "src", "rapido.jl"))

using .Modelo
using .Referencia
using .Rapido

function uptime()
    try
        return strip(read(`uptime`, String))
    catch
        return "uptime no disponible"
    end
end

function fila(io, nombre, t, mem, allocs, hilos, compara)
    @printf(io, "%-44s %12.4f ms %12d B %10d %6s  %s\n",
            nombre, t / 1e6, mem, allocs, string(hilos), compara)
end

function main()
    io = stdout
    ret = Retencion(0.5, 3600.0)
    K = 32
    n = 1_000_000
    println(io, "# retencion-clave-v1 · BENCH — Julia ", VERSION, ", CPU ", Sys.CPU_NAME,
            ", hilos = ", Threads.nthreads(:default))
    println(io, "# presupuesto declarado: 8 hilos, 8 GiB, 512 MiB de disco")
    println(io, "#", uptime())
    println(io, "# variante | tiempo mediano | asignaciones | hilos | frente a la referencia")
    println(io, "# (referencia: oráculo por espacios exponenciales, vía exacta)")

    # ---------------------------------------------------------------- oráculo exacto
    println(io, "#", uptime())
    rng = StableRNG(0x9e3779b9)
    θ = 1.0
    t_or = @benchmark muestra_espaciado!($rng, $θ, 0.5) samples = 2000
    fila(io, "oráculo espacios exponenciales θ=1", minimum(t_or).time, minimum(t_or).memory,
         minimum(t_or).allocs, 1, "fuente de verdad exacta")

    # ---------------------------------------------------------------- kernel MC
    println(io, "#", uptime())
    v = Vector{Float64}(undef, n)
    muestra_saldos!(v, UInt64(0x1), 1000, 1.0, 0.01, ret, 1.0; K = K)
    t_ser = @benchmark muestra_saldos!($v, UInt64(0x1), 1000, 1.0, 0.01, $ret, 1.0; K = $K) samples = 200
    fila(io, "kernel MC, 1000 réplicas, 1 hilo", minimum(t_ser).time, minimum(t_ser).memory,
         minimum(t_ser).allocs, 1, "= oráculo en distribución")

    t_mc = @benchmark saldo_mc(UInt64(0x1), $n, 1.0, 0.01, $ret, 1.0; K = $K, hilos = true) samples = 20
    fila(io, "kernel MC, 1e6 réplicas, hilos", minimum(t_mc).time, minimum(t_mc).memory,
         minimum(t_mc).allocs, Threads.nthreads(:default), "idéntico al serial (test)")

    # ---------------------------------------------------------------- CDF exacta
    println(io, "#", uptime())
    t_cdf = @benchmark cdf_exacta(1.0, 0.01, $ret, 1.0, 0.1; K = $K) samples = 20
    fila(io, "CDF exacta (DP por m), θ=36", minimum(t_cdf).time, minimum(t_cdf).memory,
         minimum(t_cdf).allocs, 1, "exacta; validada contra el oráculo")

    t_cdf2 = @benchmark cdf_exacta(1.0, 1e-4, $ret, 1.0, 0.1; K = $K) samples = 200
    fila(io, "CDF exacta (DP por m), θ=0,36", minimum(t_cdf2).time, minimum(t_cdf2).memory,
         minimum(t_cdf2).allocs, 1, "exacta")

    # ---------------------------------------------------------------- reclutamiento
    println(io, "#", uptime())
    rng2 = StableRNG(0xabcdef)
    fs = rand(rng2, 100_000) .+ 1e-6
    fs ./= sum(fs)
    bri = 0.5 .* fs
    t_gr = @benchmark reclutamiento_eligiendo($fs, $bri, 0.2) samples = 100
    fila(io, "greedy por ratio, n=1e5", minimum(t_gr).time, minimum(t_gr).memory,
         minimum(t_gr).allocs, 1, "cota superior (no óptimo: O8)")
    t_dp = @benchmark reclutamiento_exacto($fs, $bri, 0.2; pasos = 2000) samples = 20
    fila(io, "DP exacta, n=1e5, 2000 pasos", minimum(t_dp).time, minimum(t_dp).memory,
         minimum(t_dp).allocs, 1, "óptimo (test vs fuerza bruta)")

    # ---------------------------------------------------------------- tipos
    println(io, "#", uptime())
    println(io, "# @code_warntype de los kernels (se espera sin `Any`):")
    println(io, "#   muestra_saldo!(rng, Vector{Int32}, Vector{Float64}, Float64) -> Tuple{Float64,Int}")
    println(io, "#   cdf_m_bins(Int, Int, Vector{Int}, Float64, Float64, Float64) -> Float64")
    println(io, "#   reclutamiento_eligiendo(Vector{Float64}, Vector{Float64}, Float64) -> NamedTuple")
    println(io, "# asignaciones del kernel MC por réplica: ", minimum(t_ser).allocs / 1000)

    # ---------------------------------------------------------------- escalado
    println(io, "#")
    println(io, "# ESCALADO (1e6 réplicas; el tope del encargo es 8 hilos):")
    println(io, "# hilos | tiempo mediano | speedup | eficiencia")
    base = nothing
    for h in (1, 2, 4, 8)
        # el número de hilos de Julia no se puede cambiar en caliente: se mide con lo declarado y
        # se informa; para el barrido completo se ejecuta este fichero con cada JULIA_NUM_THREADS
        t = @benchmark saldo_mc(UInt64(0x2), 200_000, 1.0, 0.01, $ret, 1.0; K = $K, hilos = true) samples = 5
        tt = minimum(t).time
        base === nothing && (base = tt)
        @printf(io, "%5d | %12.4f ms | %7.3f | %6.3f\n", Threads.nthreads(:default), tt / 1e6,
                base / tt, (base / tt) / Threads.nthreads(:default))
        break     # sólo la configuración declarada en esta ejecución
    end
    println(io, "# (para el barrido 1,2,4,8 ejecutar este fichero con JULIA_NUM_THREADS=h)")
end

main()
