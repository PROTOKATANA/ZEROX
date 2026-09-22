# benchmarks.jl — medición del kernel tras calentar JIT (LINEO §5.1 y §6).
#
#   ./veritas/julia.sh --project=P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1 \
#       P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1/bench/benchmarks.jl

include(joinpath(@__DIR__, "..", "src", "RangoV1.jl"))
using .RangoV1
using BenchmarkTools

const C = ConfigControlador(w_slots=20, g_slots=20, q=10,
                            ganancia_num=1, ganancia_den=2,
                            paso_lo_num=1, paso_lo_den=2,
                            paso_hi_num=2, paso_hi_den=1,
                            sr_min=2048, sr_max=UInt64(2)^32,
                            r_inicial=UInt64(2)^20, retardos_ventana=2)

function tabla_pesos(n)
    sr = UInt64[]
    x = UInt64(2048)
    for _ in 1:n
        push!(sr, x)
        x = x * UInt64(3) + UInt64(1)
        x <= UInt64(2)^32 || (x = UInt64(2048))
    end
    return sr
end

function main()
    r = C.r_inicial
    n = UInt64(C.q)
    muestras = tabla_pesos(4096)

    controlador_fast(r, n, C)                 # calentamiento JIT
    peso_fast(UInt64(2048))
    suma = zero(UInt128)
    for s in muestras
        suma += peso_fast(s)
    end

    tc = @benchmark controlador_fast($r, $n, $C)
    tp = @benchmark begin
        acc = zero(UInt128)
        @inbounds for s in $muestras
            acc += peso_fast(s)
        end
        acc
    end
    tctrl_ref = @benchmark controlador_ref($(BigInt(r)), $(BigInt(n)), $C)

    println("kernel=controlador_fast mediana_ns=$(minimum(tc).time) allocs=$(minimum(tc).allocs) " *
            "bytes=$(minimum(tc).memory)")
    println("kernel=peso_fast (4096 sr) mediana_ns=$(minimum(tp).time) allocs=$(minimum(tp).allocs) " *
            "bytes=$(minimum(tp).memory) suma=$suma")
    println("referencia=controlador_ref mediana_ns=$(minimum(tctrl_ref).time) " *
            "allocs=$(minimum(tctrl_ref).allocs)")
    println("hilos_default=$(Threads.nthreads(:default))")
    println("BENCH_OK")
end

main()
