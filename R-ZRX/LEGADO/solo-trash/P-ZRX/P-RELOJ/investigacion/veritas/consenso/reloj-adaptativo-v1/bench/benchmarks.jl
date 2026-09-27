# bench/benchmarks.jl — benchmark del instrumento `reloj-adaptativo-v1`.
#
# Ejecutar con:
#   ../../veritas/julia.sh --project=. bench/benchmarks.jl
#
# QUÉ SE MIDE Y POR QUÉ ESTO ES CORTO. El coste dominante de este instrumento es de MODELADO, no de
# cómputo: la corrida más larga (el barrido del adaptador, 4000 slots × 48 configuraciones) tarda
# menos de un segundo. Se mide lo que hay: (a) el lazo del adaptador con y sin `@inbounds`, (b) el
# barrido de la frontera, y (c) el oráculo DP, que sí es el más caro y se declara como tal. No se
# inventa un cuello que no existe.

using BenchmarkTools
using RelojAdaptativo
using RelojAdaptativo.Modelos
using RelojAdaptativo.Modelos: MAQUINA_REF, Adaptador, traza_vacia, simular!, hardware_alternante
using RelojAdaptativo.Rapido
using RelojAdaptativo.Referencia

const T = 4000
const N0 = 200_000_000
const HW = hardware_alternante(T, 7.77e-9, 1.554e-8, 200, 0.5)
const P = Adaptador(N0, 1_000_000, 800_000_000, 7.77e-9, N0, 0.1, 5, false, 0, 0)
const TRAZA = traza_vacia(T, MAQUINA_REF.t_bloque_par)

# Calentamiento (JIT) antes de medir: LINEO §5.6.
simular!(TRAZA, HW, P)
Rapido.simular_rapido!(TRAZA, HW, P)

println("== simular! (transparente) ==")
t1 = @benchmark simular!($TRAZA, $HW, $P)
display(t1)
println()

println("== simular_rapido! (@inbounds) ==")
t2 = @benchmark Rapido.simular_rapido!($TRAZA, $HW, $P)
display(t2)
println()

println("== asignaciones por llamada ==")
println("transparente: ", @allocated simular!(TRAZA, HW, P), " bytes")
println("rapido:       ", @allocated Rapido.simular_rapido!(TRAZA, HW, P), " bytes")
println()

println("== frontera (1000 × 16 puntos) ==")
εs = collect(range(0.01, 0.5; length = 1000))
Ks = collect(1:16)
S = Matrix{Float64}(undef, length(εs), length(Ks))
tf = @benchmark Rapido.barrido_frontera!($S, $εs, $Ks)
display(tf)
println()

println("== oráculo DP (lo más caro del instrumento) ==")
td = @benchmark Referencia.sesgo_mediana_dp(51, 26, 1.0, 7200.0; escala = 1.0)
display(td)
println()
println("NOTA: el DP es el coste dominante cuando se barre (W, C, δ, φ); se declara con este")
println("número en vez de describirlo. No se optimizó porque no es el camino de producción.")
