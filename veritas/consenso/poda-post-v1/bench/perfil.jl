# PPP-v0.1 — perfil estadístico del kernel (LINEO §6, pregunta 2).
using Profile
include(joinpath(@__DIR__, "..", "src", "PodaPost.jl"))
using .PodaPost
using StableRNGs

const SR = UInt64(1) << 62

function carga()
    for r in 1:50
        rng = StableRNG(UInt64(r))
        c = zeros(Int, 48)
        contar_niveles!(c, rng, 8, SR, 200_000, 48)
    end
end

carga()                    # calienta JIT
Profile.clear()
@profile carga()
io = IOBuffer()
Profile.print(io; format=:flat, sortedby=:count, mincount=20)
print(String(take!(io)))
