# Escalado del kernel de ocupación con el número de hilos.
#
# Se ejecuta **un proceso por número de hilos** porque el número de hilos de Julia se fija al
# arrancar. El conductor está en `METODO.md`:
#
#   for H in 1 2 4 8 16 24; do JULIA_NUM_THREADS=$H ... escalado.jl $H; done
#
# Mide el kernel paralelo por bloques disjuntos de columnas, que es trabajo independiente con
# reducción determinista. Comprueba contra el serial en cada configuración antes de publicar.

using BenchmarkTools
using Printf

include(joinpath(@__DIR__, "..", "src", "EspacioTasa.jl"))
using .EspacioTasa
const ET = EspacioTasa
const RES = joinpath(@__DIR__, "..", "resultados")

nbloques = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : Threads.nthreads(:default)

bitmaps, M = ET.leer_bitmaps(RES)
out_ser = zeros(Int32, 65_536)
out_par = zeros(Int32, 65_536)
ET.s_bucket_sizes_histograma!(out_ser, bitmaps, zeros(Int32, 256))
ET.s_bucket_sizes_paralelo!(out_par, bitmaps, nbloques)
@assert out_ser == out_par "el kernel paralelo NO conserva los contadores: no se publica"

# Calentamiento.
ET.s_bucket_sizes_paralelo!(out_par, bitmaps, nbloques)
t_par = @benchmark ET.s_bucket_sizes_paralelo!($out_par, $bitmaps, $nbloques)
t_ser = @benchmark ET.s_bucket_sizes_histograma!($out_ser, $bitmaps, zeros(Int32, 256))
@printf("%d\t%d\t%d\t%.0f\t%.0f\t%.3f\t%.3f\n",
        nbloques, Threads.nthreads(:default), Threads.nthreads(:interactive),
        minimum(t_par).time, minimum(t_ser).time,
        minimum(t_ser).time / minimum(t_par).time,
        (minimum(t_ser).time / minimum(t_par).time) / nbloques)
