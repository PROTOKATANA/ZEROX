#!/usr/bin/env julia
# =============================================================================
# SL-2 · bench/benchmarks.jl — medición del kernel (LINEO §6).
#
#   JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia" julia --project=. bench/benchmarks.jl
#
# Mide el kernel certificado, la inversión β_d↔P, el kernel del modelo en frío y caliente, y el
# escalado del Monte Carlo (lanzar con --threads=1,2,4 y comparar). No optimiza por intuición.
# =============================================================================

using SL2
using BenchmarkTools
using Printf
using Statistics

const DIR_RES = joinpath(@__DIR__, "..", "resultados")
mkpath(DIR_RES)

tibs = Float64[g.tib for g in limpiar_farmers(cargar_farmers(
    joinpath(@__DIR__, "..", "datos", "farmers-raw.csv")))]
emp = empirica(tibs)
esc = Escenario(emp, 1e5, 1.0, 20.0, 10.0, 1.0, 1.0, 1.0, 1.0, 0.01, 0.0, 1019.0, 1e-3,
                1e-3, 1e-3, 0.01, :P1)

# ── calentamiento (JIT) ──────────────────────────────────────────────────────
primera_dp_absorbente(1 / 3, 346, 1019)
primera_dp(1 / 3, 346, 1019)
beta_minimo_para_p(0.33, 1019.0, 1e-3)
region_tv(esc, 0.278665; ρ_ret = 0.5)
B_empirico(emp, 0.01 / 3600)

io = open(joinpath(DIR_RES, "BENCH.txt"), "w")
@printf(io, "SL-2 · benchmark (LINEO §6)\n")
@printf(io, "julia = %s\n", VERSION)
@printf(io, "cpu = %s\n", Sys.CPU_NAME)
@printf(io, "nthreads_default = %d | nthreads_interactive = %d\n",
        Threads.nthreads(:default), Threads.nthreads(:interactive))
@printf(io, "memoria_total_GiB = %.1f\n\n", Sys.total_memory() / 2^30)

function fila(nombre, t, mem, allocs, n)
    @printf(io, "%-34s %12.3f us  %10d B  %8d allocs  (%d reps)\n",
            nombre, t / 1e3, mem, allocs, n)
end

for (nombre, b) in [
        ("primera_dp_absorbente(d=346,T=1019)", @benchmark primera_dp_absorbente(1/3, 346, 1019)),
        ("primera_dp(mín,pos) d=346,T=1019", @benchmark primera_dp(1/3, 346, 1019)),
        ("beta_minimo_para_p(0.33,1e-3)", @benchmark beta_minimo_para_p(0.33, 1019.0, 1e-3)),
        ("region_tv empírica rho=0.5", @benchmark region_tv($esc, 0.278665; ρ_ret=0.5)),
        ("B_empirico (búsqueda binaria)", @benchmark B_empirico($emp, 0.01/3600)),
    ]
    fila(nombre, minimum(b).time, minimum(b).memory, minimum(b).allocs, length(b.times))
end

# ── Monte Carlo: coste y escalado (la capa externa de hilos la posee @threads) ──
@printf(io, "\nMonte Carlo de la ventana (200000 réplicas), nthreads_default=%d:\n",
        Threads.nthreads(:default))
mc = @benchmark mc_ventana(1/3, 5, 400, 200_000, UInt64(0x5a5a); hilos=true)
fila("mc_ventana 2e5 reps (hilos)", minimum(mc).time, minimum(mc).memory, minimum(mc).allocs,
     length(mc.times))
mc1 = @benchmark mc_ventana(1/3, 5, 400, 200_000, UInt64(0x5a5a); hilos=false)
fila("mc_ventana 2e5 reps (serial)", minimum(mc1).time, minimum(mc1).memory, minimum(mc1).allocs,
     length(mc1.times))
@printf(io, "\n(comparar lanzando con --threads=1 y --threads=4 para el speedup real)\n")

# ── asignaciones del barrido de región (una celda) ──────────────────────────
@printf(io, "\n@allocated region_tv = %d B\n", @allocated region_tv(esc, 0.278665; ρ_ret=0.5))
close(io)
print(read(joinpath(DIR_RES, "BENCH.txt"), String))
