# =============================================================================
# benchmarks.jl — P-TASA · benchmarks y validación de rendimiento (LINEO §6)
# -----------------------------------------------------------------------------
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
#
# Reglas: se calienta JIT antes de medir; `@benchmark` interpola **datos** con `$`
# (nunca la función a medir: el patrón `$f()` lo rechaza BenchmarkTools); se
# publican tamaño, trabajo, hilos y resultado frente a la referencia. `uptime` en
# la cabecera. La tabla se publica en `resultados/BENCH-tabla.tsv`.
# =============================================================================
using BenchmarkTools
using Random123
using Printf
using InteractiveUtils

include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
include(joinpath(@__DIR__, "..", "src", "referencia.jl"))
include(joinpath(@__DIR__, "..", "src", "rapido.jl"))

const TABLA = NamedTuple[]

"""Imprime y acumula una fila de la tabla de rendimiento (LINEO §6)."""
function fila(etiqueta::String, t; hilos::Int = Threads.nthreads(),
              frente_a::String = "—")
    m = minimum(t)
    @printf("%-44s %11.4f ms %14d B %8d allocs  hilos=%d  frente=%s\n",
            etiqueta, m.time / 1e6, m.memory, m.allocs, hilos, frente_a)
    push!(TABLA, (variante = etiqueta, tiempo_mediano_ms = m.time / 1e6,
                  asignaciones_bytes = m.memory, allocs = m.allocs, hilos = hilos,
                  frente_a_la_referencia = frente_a))
    return t
end

println("== P-TASA · benchmarks ==")
println("julia ", VERSION, " · hilos ", Threads.nthreads(),
        " · hilos interactivos ", Threads.nthreads(:interactive))
println("CPU: ", Sys.CPU_NAME, " · núcleos lógicos: ", Sys.CPU_THREADS,
        " · RAM GiB: ", round(Int, Sys.total_memory() / 2^30))
println("uptime: ", strip(read(`uptime`, String)))
println()

d = ParetoTruncado(1e-8, 1.0, 2.2)
xs = collect(range(1e-8, 1.0; length = 10_000))
dest = Vector{Float64}(undef, length(xs))
rng1 = Philox4x(semilla_replica(UInt64(0x5a5a), 1))
τs = collect(range(0.0, 1.0; length = 200))
ff = fill(1.0 / 1000, 1000)
ss = fill(1e-3, 1000)
Lp = 1830.0

# --- calentamiento JIT -------------------------------------------------------
phi_pareto!(dest, d, xs)
Phi_espacio(d, 1e-4)
Phi_pareto_riemann(d, 1e-4; K = 20_000)
mc_phi_replica(rng1, d, 1e-4, 1_000)
mc_phi(UInt64(0x5a5a), d, 1e-4, 1_000, 4; hilos = 1)
f_detenida(1e-3, 0.1, Lp, 1.0, 1.0, 1.0, 1.0, 0.0)
tau_minimo_fee(1e-8, 1.0, 1.0, 1.0, 1.0, 0.0)
barrido_tasa(τs, d, 1.0, 1.0, 1.0, 1.0, 0.0, 0.1, Lp)
reclutamiento_avaricioso(ff, ss, 0.3)
reclutamiento_dos_niveles(0.34, 0.34, 1_000_000, 1e-3, 0.0, 0.1, Lp, 1.0, 1.0, 1.0, 1.0, 0.3)
println()

# --- tabla de rendimiento ----------------------------------------------------
# Las pruebas se asignan a una variable antes de pasarlas a `fila`: si el
# `@benchmark` quedara como argumento, se tragaría los kwargs de `fila`.
t = @benchmark Phi_espacio($d, 1e-4) samples = 1000
fila("Φ Pareto cerrada (1 punto)", t)
t = @benchmark phi_pareto!($dest, $d, $xs) samples = 500
fila("Φ Pareto cerrada (rejilla 10^4)", t; frente_a = "= Phi_espacio en la rejilla")
t = @benchmark Phi_pareto_riemann($d, 1e-4; K = 20_000) samples = 500
fila("Φ Riemann K=20.000 (oráculo)", t; frente_a = "acota la cerrada")
t = @benchmark mc_phi_replica($rng1, $d, 1e-4, 10_000) samples = 200
fila("MC 1 réplica M=10^4", t)
t = @benchmark mc_phi(UInt64(0x5a5a), $d, 1e-4, 10_000, 4; hilos = 1) samples = 200
fila("MC 4 réplicas M=10^4 (1 hilo)", t)
t = @benchmark mc_phi(UInt64(0x5a5a), $d, 1e-4, 10_000, 4; hilos = 4) samples = 200
fila("MC 4 réplicas M=10^4 (4 hilos)", t; frente_a = "idéntico al serial")
t = @benchmark f_detenida(1e-3, 0.1, $Lp, 1.0, 1.0, 1.0, 1.0, 0.0) samples = 1000
fila("f_detenida (kernel)", t)
t = @benchmark tau_minimo_fee(1e-8, 1.0, 1.0, 1.0, 1.0, 0.0) samples = 1000
fila("τ_min (kernel)", t)
t = @benchmark barrido_tasa($τs, $d, 1.0, 1.0, 1.0, 1.0, 0.0, 0.1, $Lp) samples = 500
fila("barrido de tasa (200 puntos)", t)
t = @benchmark reclutamiento_avaricioso($ff, $ss, 0.3) samples = 500
fila("reclutamiento avaricioso n=10^3", t; frente_a = "cota superior, no óptimo")
t = @benchmark reclutamiento_dos_niveles(0.34, 0.34, 1_000_000, 1e-3, 0.0, 0.1, $Lp, 1.0, 1.0, 1.0, 1.0, 0.3) samples = 200
fila("reclutamiento exacto 2 niveles K=10^6", t; frente_a = "= fuerza bruta en K pequeño")
println()

# --- asignaciones ------------------------------------------------------------
println("== @allocated ==")
@printf("phi_pareto!(10^4)       : %d B\n", @allocated phi_pareto!(dest, d, xs))
@printf("f_detenida              : %d B\n", @allocated f_detenida(1e-3, 0.1, Lp, 1.0, 1.0, 1.0, 1.0, 0.0))
@printf("mc_phi_replica M=10^4   : %d B\n", @allocated mc_phi_replica(rng1, d, 1e-4, 10_000))
@printf("barrido_tasa 200 puntos : %d B\n", @allocated barrido_tasa(τs, d, 1.0, 1.0, 1.0, 1.0, 0.0, 0.1, Lp))
println()

# --- estabilidad de tipos ----------------------------------------------------
println("== @code_warntype de los dos kernels calientes ==")
println("-- f_detenida --")
@code_warntype f_detenida(1e-3, 0.1, Lp, 1.0, 1.0, 1.0, 1.0, 0.0)
println("-- tau_minimo_fee --")
@code_warntype tau_minimo_fee(1e-8, 1.0, 1.0, 1.0, 1.0, 0.0)
println()

# --- validación de las variantes contra la referencia ------------------------
println("== validación de las variantes contra la referencia ==")
lo1, hi1, an1 = Phi_pareto_riemann(d, 1e-4; K = 20_000)
lo2, hi2, an2 = Phi_pareto_riemann(d, 1e-4; K = 80_000)
@printf("Riemann K=2e4: [%.12e, %.12e] ancho=%.3e\n", lo1, hi1, an1)
@printf("Riemann K=8e4: [%.12e, %.12e] ancho=%.3e\n", lo2, hi2, an2)
@printf("cerrada dentro de ambos: %s\n",
        (lo1 ≤ Phi_espacio(d, 1e-4) ≤ hi1) && (lo2 ≤ Phi_espacio(d, 1e-4) ≤ hi2))
@printf("phi_pareto! == Phi_espacio en la rejilla: %s\n",
        all(dest .== [Phi_espacio(d, x) for x in xs]))
r1 = mc_phi(UInt64(0x5a5a), d, 1e-4, 20_000, 8; hilos = 1)
r4 = mc_phi(UInt64(0x5a5a), d, 1e-4, 20_000, 8; hilos = 4)
@printf("MC serial == MC 4 hilos: %s\n", r1.ratios == r4.ratios)
fd = barrido_tasa(τs, d, 1.0, 1.0, 1.0, 1.0, 0.0, 0.1, Lp)[1]
@printf("barrido de tasa monótono en f_det: %s\n", issorted(fd))
@printf("f_det(0.3)=%.6e  f_det(0.6)=%.6e\n",
        f_detenida(0.3, 0.1, Lp, 1.0, 1.0, 1.0, 1.0, 0.0),
        f_detenida(0.6, 0.1, Lp, 1.0, 1.0, 1.0, 1.0, 0.0))
println()

# --- JET ---------------------------------------------------------------------
using JET
println("== JET (análisis estático de los kernels) ==")
function jet_contar(etiqueta::String, f, tipos)
    rep = JET.report_opt(f, tipos)
    n = length(JET.get_reports(rep))
    @printf("%-42s %d diagnósticos\n", etiqueta, n)
    return n
end
jet_contar("f_detenida", f_detenida,
           (Float64, Float64, Float64, Float64, Float64, Float64, Float64, Float64))
jet_contar("tau_minimo_fee", tau_minimo_fee,
           (Float64, Float64, Float64, Float64, Float64, Float64))
jet_contar("ganancia_cofarmacion", ganancia_cofarmacion,
           (Float64, Float64, Float64, Float64, Float64))
jet_contar("Phi_espacio (Pareto)", Phi_espacio, (ParetoTruncado{Float64}, Float64))
jet_contar("mc_phi_replica", mc_phi_replica,
           (Philox4x{UInt64, 10}, ParetoTruncado{Float64}, Float64, Int))
println()

# --- tabla a TSV -------------------------------------------------------------
ruta = joinpath(@__DIR__, "..", "resultados", "BENCH-tabla.tsv")
open(ruta, "w") do io
    println(io, join(string.(keys(TABLA[1])), '\t'))
    for f in TABLA
        println(io, join((string(getfield(f, k)) for k in keys(f)), '\t'))
    end
end
println("tabla escrita: ", ruta)
println("== fin benchmarks ==")
