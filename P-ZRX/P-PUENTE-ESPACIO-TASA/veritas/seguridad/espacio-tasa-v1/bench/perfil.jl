# Perfil CPU del kernel dominante (LINEO §6 paso 5). Requiere perfil propio, no estimación.
#
#   JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia" \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/perfil.jl

using Profile
using Printf

include(joinpath(@__DIR__, "..", "src", "EspacioTasa.jl"))
using .EspacioTasa
const ET = EspacioTasa
const RES = joinpath(@__DIR__, "..", "resultados")

bitmaps, M = ET.leer_bitmaps(RES)
out = zeros(Int32, 65_536)
hist = zeros(Int32, 256)

# Calentamiento antes de perfilar (LINEO §5.6: no confundir JIT con cómputo).
for _ in 1:5
    ET.s_bucket_sizes_histograma!(out, bitmaps, hist)
end

Profile.clear()
@profile for _ in 1:50
    ET.s_bucket_sizes_histograma!(out, bitmaps, hist)
end

println("# PERFIL — s_bucket_sizes_histograma! (50 repeticiones, M=$(M))")
Profile.print(format=:flat, sortedby=:count, mincount=1)
