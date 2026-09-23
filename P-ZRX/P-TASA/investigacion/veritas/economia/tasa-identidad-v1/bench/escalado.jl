# =============================================================================
# escalado.jl — escalado del kernel MC por réplicas (tope del encargo: 4 hilos)
# -----------------------------------------------------------------------------
# Se lanza como proceso independiente por cada número de hilos:
#   for h in 1 2 4; do JULIA_NUM_THREADS=$h ... escalado.jl $h; done
# Escribe resultados/ESCALADO-raw.tsv (una fila por hilo) para que
# `correr-todo.sh` lo agregue. Reducción determinista: el resultado debe ser
# idéntico en todos los casos.
# =============================================================================
using Random123
using Printf

include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
include(joinpath(@__DIR__, "..", "src", "rapido.jl"))

hilos = parse(Int, ARGS[1])
d = ParetoTruncado(1e-8, 1.0, 2.2)
M, R = 200_000, 64
seed = UInt64(0x54415341)

# calentamiento
mc_phi(seed, d, 1e-4, 1_000, 4; hilos = 1)
mc_phi(seed, d, 1e-4, 1_000, 4; hilos = hilos)

# referencia SERIAL medida en este mismo proceso, para que la comparación no sea
# una fórmula consigo misma (el resultado debe ser bit a bit idéntico).
serial = mc_phi(seed, d, 1e-4, M, R; hilos = 1)
t0 = time_ns()
res = mc_phi(seed, d, 1e-4, M, R; hilos = hilos)
t1 = time_ns()

@printf("hilos=%d  tiempo=%.6f s  media=%.12e  desv=%.3e  identico_a_serial=%s\n",
        hilos, (t1 - t0) / 1e9, res.media, res.desv, res.ratios == serial.ratios)
open(joinpath(@__DIR__, "..", "resultados", "ESCALADO-raw.tsv"), "a") do io
    @printf(io, "%d\t%.6f\t%.12e\t%.6e\t%s\n", hilos, (t1 - t0) / 1e9, res.media,
            res.desv, res.ratios == serial.ratios ? "si" : "no")
end
println("uptime: ", strip(read(`uptime`, String)))
