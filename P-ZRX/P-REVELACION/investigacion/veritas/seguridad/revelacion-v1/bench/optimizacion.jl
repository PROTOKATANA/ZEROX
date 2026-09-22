# optimizacion.jl — antes/después de la única optimización guiada por perfil (LINEO §6)
# El perfil de `resultados/PERFIL.txt` señala `llenar_rampa!` (histograma) como cuello. Los
# barridos que sólo necesitan escalares (F1, F3, ADL, ρ*) pueden saltárselo sin cambiar la cifra.
using BenchmarkTools, RevelacionV1, Printf
cfg = Config{Float64}(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7050.0, con_h = true, espera = false, cruce = true, lead_h = 4.0, j_ini = 150)
kw = (rhos = [1.05, 1.5, 2.0, 3.0, 5.0, 9.0], n_rep = 64, J = 1500, alpha = 0.33,
      seed = UInt64(0x5a5a), nb = 4096, bin = 32.0, v_lo = -1024.0, boot_ref = 0.0, modo_off = :geom)
a = barrer!(cfg; kw..., nthreads = 1, con_hist = true)
b = barrer!(cfg; kw..., nthreads = 1, con_hist = false)
println("mismos escalares: ", a.vmax == b.vmax && a.vmin == b.vmin && a.vmed == b.vmed &&
        a.boot == b.boot && a.n_pro == b.n_pro && a.hist != b.hist)
t1 = @benchmark barrer!($cfg; $kw..., nthreads = 1, con_hist = true) samples = 10 evals = 1
t2 = @benchmark barrer!($cfg; $kw..., nthreads = 1, con_hist = false) samples = 10 evals = 1
@printf("con histograma:    mediana %8.2f ms\n", median(t1).time / 1e6)
@printf("sin histograma:    mediana %8.2f ms\n", median(t2).time / 1e6)
@printf("ganancia: %.2f×\n", median(t1).time / median(t2).time)
