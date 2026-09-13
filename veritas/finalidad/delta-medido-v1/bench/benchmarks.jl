# bench/benchmarks.jl — BenchmarkTools sobre el kernel de propagación (no I/O).
#
# Ejecutar con: julia --project=. bench/benchmarks.jl
#
# Mide la inundación completa de un conjunto de bloques sobre una red generada: el
# oráculo (n pequeño) y el kernel rápido (n representativo). Las asignaciones del
# kernel caliente deben ser ~0 (todo preasignado salvo la matriz de salida por corrida).

using BenchmarkTools
using StableRNGs
using DeltaMedido

# --- workload pequeño: oráculo vs kernel, misma instancia ---------------------
p_pequeno = ParametrosRed(20, :regular, 8, 0.08, 0.5, 1.0e7, 683.0, 0.0, 1.0, 10.0)
rng_pequeno = StableRNG(UInt64(0x5A5A))
red_pequeno = construir_red(rng_pequeno, p_pequeno)
t_creacion_peq = calendario_poisson(rng_pequeno, 1.0, 10.0)
creador_peq = rand(rng_pequeno, 1:20, length(t_creacion_peq))
@assert correr_referencia(red_pequeno, t_creacion_peq, creador_peq) ==
        correr!(MotorRapido(20), red_pequeno, t_creacion_peq, creador_peq)
@assert invariantes(correr_referencia(red_pequeno, t_creacion_peq, creador_peq), t_creacion_peq)

trial_ref = @benchmark correr_referencia($red_pequeno, $t_creacion_peq, $creador_peq) samples=100 evals=1
m_peq = MotorRapido(20)
trial_rap_peq = @benchmark correr!($m_peq, $red_pequeno, $t_creacion_peq, $creador_peq) samples=1000 evals=1

println("workload=n20_d8_blocks~10")
println("reference_median_ns=$(median(trial_ref).time)")
println("reference_median_bytes=$(median(trial_ref).memory)")
println("reference_median_allocs=$(median(trial_ref).allocs)")
println("kernel_n20_median_ns=$(median(trial_rap_peq).time)")
println("kernel_n20_median_bytes=$(median(trial_rap_peq).memory)")
println("kernel_n20_median_allocs=$(median(trial_rap_peq).allocs)")

# --- workload representativo: n=1000 ------------------------------------------
p_medio = ParametrosRed(1000, :regular, 8, 0.08, 0.5, 1.0e7, 683.0, 0.0, 1.0, 30.0)
rng_medio = StableRNG(UInt64(0x5A5B))
red_medio = construir_red(rng_medio, p_medio)
t_creacion_med = calendario_poisson(rng_medio, 1.0, 30.0)
creador_med = rand(rng_medio, 1:1000, length(t_creacion_med))
m_med = MotorRapido(1000; capacidad = 64 + (1000 * 8 + 1) * 16)
llegada_med = correr!(m_med, red_medio, t_creacion_med, creador_med)
@assert invariantes(llegada_med, t_creacion_med)

trial_med = @benchmark correr!($m_med, $red_medio, $t_creacion_med, $creador_med) samples=100 evals=1
println("workload=n1000_d8_blocks~30")
println("kernel_n1000_median_ns=$(median(trial_med).time)")
println("kernel_n1000_median_bytes=$(median(trial_med).memory)")
println("kernel_n1000_median_allocs=$(median(trial_med).allocs)")

# --- workload representativo: n=10000 -----------------------------------------
p_grande = ParametrosRed(10000, :regular, 8, 0.08, 0.5, 1.0e7, 683.0, 0.0, 1.0, 30.0)
rng_grande = StableRNG(UInt64(0x5A5C))
red_grande = construir_red(rng_grande, p_grande)
t_creacion_gr = calendario_poisson(rng_grande, 1.0, 30.0)
creador_gr = rand(rng_grande, 1:10000, length(t_creacion_gr))
m_gr = MotorRapido(10000; capacidad = 64 + (10000 * 8 + 1) * 16)
llegada_gr = correr!(m_gr, red_grande, t_creacion_gr, creador_gr)
@assert invariantes(llegada_gr, t_creacion_gr)

trial_gr = @benchmark correr!($m_gr, $red_grande, $t_creacion_gr, $creador_gr) samples=20 evals=1
println("workload=n10000_d8_blocks~30")
println("kernel_n10000_median_ns=$(median(trial_gr).time)")
println("kernel_n10000_median_bytes=$(median(trial_gr).memory)")
println("kernel_n10000_median_allocs=$(median(trial_gr).allocs)")
