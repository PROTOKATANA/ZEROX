# jet.jl — análisis estático (LINEO §5.1)
using JET
using RevelacionV1
const RV = RevelacionV1
cfg = Config{Float64}(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7050.0, con_h = true, espera = false, cruce = true, lead_h = 4.0,
                      j_ini = 150)
b = Buffers{Float64}(100, 256)
off = zeros(101); propia = fill(false, 101)
println("=== report_call(simular_replica!) ===")
report_call(simular_replica!, (Buffers{Float64}, Config{Float64}, Vector{Float64}, Vector{Bool},
                               Float64, Int, Float64, Float64, Float64))
println("=== report_call(construir_trayectorias!) ===")
report_call(construir_trayectorias!, (Vector{Float64}, Vector{Float64}, Vector{Float64},
                                      Vector{Float64}, Config{Float64}, Vector{Float64},
                                      Vector{Bool}, Float64, Int))
println("=== report_call(acumular!) ===")
report_call(RV.acumular!, (Buffers{Float64}, Config{Float64}, Int, Int, Float64, Float64, Float64,
                        Float64, Float64))
