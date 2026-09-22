# benchmarks.jl — medición del caso representativo tras calentar JIT (LINEO §6).
# Ejecutar: julia --project=. bench/benchmarks.jl
using BenchmarkTools
using Printf

include(joinpath(@__DIR__, "..", "src", "CRP1Defectos.jl"))
using .CRP1Defectos

@printf("%-46s %14s %12s %10s\n", "variante", "tiempo mediano", "asignaciones", "hilos")

function fila(nombre, t)
    @printf("%-46s %14s %12d %10d\n", nombre, BenchmarkTools.prettytime(minimum(t).time),
            minimum(t).allocs, Threads.nthreads(:default))
end

# --- DP de alcance: g=1 (pequeño) y g=256 (grande) -------------------------
r1 = alcance_compuesto(0.4, 1.0, 6; ventanas = (206,)); fila("DP alcance g=1  m=6  N=206", @benchmark alcance_compuesto(0.4, 1.0, 6; ventanas = (206,)))
r2 = alcance_compuesto(0.4, 256.0, 1536; ventanas = (1736,)); fila("DP alcance g=256 m=1536 N=1736", @benchmark alcance_compuesto(0.4, 256.0, 1536; ventanas = (1736,)))

# --- soporte adaptativo ----------------------------------------------------
s1 = soporte_incremento(0.4, 1.0); fila("soporte_incremento g=1", @benchmark soporte_incremento(0.4, 1.0))
s2 = soporte_incremento(0.4, 256.0); fila("soporte_incremento g=256", @benchmark soporte_incremento(0.4, 256.0))

# --- tabla de varianza exacta ---------------------------------------------
p = ParametrosVarianza()
ex = varianza_exacta(p); fila("varianza_exacta (4 factores)", @benchmark varianza_exacta($p))

# --- Monte Carlo -----------------------------------------------------------
mc = mc_varianza(p; n_rep = 4000, modo = :hashed)
tt = @benchmark mc_varianza($p; n_rep = 4000, modo = :hashed) samples = 5
fila("mc_varianza n_rep=4000 hashed", tt)

# --- rutina aritmética exacta ---------------------------------------------
fila("peso_exacto(2^50)", @benchmark peso_exacto(big(2)^50))
fila("prob_empate_reticula(2/5, 1536)", @benchmark prob_empate_reticula(big(2)//big(5), 1536))

@printf("\nresumen exacto de la tabla de varianza:\n")
for f in varianza_exacta(p)
    @printf("  K=%3d  P(>)=%.12f  P(=)=%.3e  masa_omitida=%.2e\n",
            f.K, f.p_mayor, f.p_igual, f.masa_b_truncada)
end
