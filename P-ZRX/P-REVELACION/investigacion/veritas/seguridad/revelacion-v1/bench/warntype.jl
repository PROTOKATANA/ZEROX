# warntype.jl — inspección de inferencia de tipos del núcleo (LINEO §3.1)
using RevelacionV1
using InteractiveUtils
const RV = RevelacionV1
cfg = Config{Float64}(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7050.0, con_h = true, espera = false, cruce = true, lead_h = 4.0,
                      j_ini = 150)
b = Buffers{Float64}(100, 256)
off = zeros(101); propia = fill(false, 101)
println("=== @code_warntype simular_replica! ===")
@code_warntype simular_replica!(b, cfg, off, propia, 2.0, 100, 16.0, -64.0, 0.0)
println("=== @code_warntype construir_trayectorias! ===")
@code_warntype construir_trayectorias!(b.tA, b.pA, b.tH, b.pH, cfg, off, propia, 2.0, 100)
println("=== @code_warntype acumular! ===")
@code_warntype RV.acumular!(b, cfg, 10, 10, 16.0, -64.0, 0.0, 0.0, 10.0)
