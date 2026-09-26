# benchmarks.jl — medidas mínimas del oráculo T04 (LINEO §6).
#
#     julia --project=. bench/benchmarks.jl
#
# Un hilo. Mide, tras calentar JIT, el coste por historia y por comprobación.
# No hay kernel optimizado: T04 es un oráculo de referencia.

using EstadoDAG
using StableRNGs
using Printf

function medir(f, n::Int)
    t0 = time_ns()
    for _ in 1:n
        f()
    end
    return (time_ns() - t0) / n / 1e6   # ms
end

function main()
    println("# BENCH T04 · julia ", VERSION, " · hilos ", Threads.nthreads(:default),
            " · CPU ", Sys.CPU_NAME)
    pd = ParamsDAG(PARAMS_DAG_BASE[1], 1)
    # Calentamiento
    Aw = generar_dag_aleatorio(StableRNG(1), pd; npost = 8)
    Sw, _, _ = estado_virtual(Aw)
    @assert invariante_I1(Sw)

    n = 200
    t_gen = medir(() -> generar_dag_aleatorio(StableRNG(2), pd; npost = 8), n)
    A = generar_dag_aleatorio(StableRNG(2), pd; npost = 8)
    t_virt = medir(() -> estado_virtual(A), n)
    t_hist = medir(() -> aplicar_historia(A), n)
    t_ie1 = medir(() -> verificar_ie1_ie2_ie4(A), n)
    t_ie3 = medir(() -> verificar_ie3(A, collect(values(A.por_id)); intentos = 20), 20)
    t_gdr = medir(() -> revalidar_corpus("/home/katana/zeo/ZEROX/testdata/ghostdag-rank-v1/corpus-rust.txt"), 5)

    @printf("generar_dag_aleatorio (npost=8)  = %.3f ms\n", t_gen)
    @printf("estado_virtual                    = %.3f ms\n", t_virt)
    @printf("aplicar_historia                  = %.3f ms\n", t_hist)
    @printf("verificar_ie1_ie2_ie4             = %.3f ms\n", t_ie1)
    @printf("verificar_ie3 (20 ordenes)        = %.3f ms\n", t_ie3)
    @printf("revalidar_corpus (28 DAGs)        = %.3f ms\n", t_gdr)
    println("alloc_estado_virtual_bytes = ", Base.@allocated estado_virtual(A))
end

main()
