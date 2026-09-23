# Inferencia de tipos de los kernels (LINEO §3.1: `@code_warntype` sobre el kernel, no sobre la
# preparación). Busca `Any` o uniones en el camino caliente.
#
#   JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia" \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/warntype.jl

using InteractiveUtils

include(joinpath(@__DIR__, "..", "src", "EspacioTasa.jl"))
using .EspacioTasa
const ET = EspacioTasa

bitmaps = zeros(UInt8, 8, 8192)
out = zeros(Int32, 65_536)
hist = zeros(Int32, 256)
buf = zeros(UInt8, 32)
retos = zeros(UInt8, 32, 4)
nb = zeros(Int32, 4)

for (nombre, f, args) in (
    ("s_bucket_sizes_histograma!", ET.s_bucket_sizes_histograma!, (out, bitmaps, hist)),
    ("s_bucket_sizes_referencia!", ET.s_bucket_sizes_referencia!, (out, bitmaps)),
    ("s_bucket_sizes_paralelo!", ET.s_bucket_sizes_paralelo!, (out, bitmaps, 2)),
    ("distancia_u64", ET.distancia_u64, (UInt64(1), UInt64(2))),
    ("u64_le", ET.u64_le, (zeros(UInt8, 32), 1)),
    ("bucket_de", ET.bucket_de, (zeros(UInt8, 32),)),
    ("buckets_de_retos!", ET.buckets_de_retos!, (nb, zeros(UInt8, 32), retos, buf)),
    ("auditar_slots!", ET.auditar_slots!, (zeros(Int32, 4), out, nb)),
    ("rank_select", ET.rank_select, (bitmaps, 1, 5)),
)
    println("\n", "="^90)
    println("# @code_warntype ", nombre)
    println("="^90)
    @code_warntype f(args...)
end
