# PPP-v0.1 — asignaciones del kernel (LINEO §2/§6, pregunta 2).
using Printf
include(joinpath(@__DIR__, "..", "src", "PodaPost.jl"))
using .PodaPost
using StableRNGs

SR = UInt64(1) << 62
rng = StableRNG(UInt64(0xB0E1))
conteo = zeros(Int, 48)
contar_niveles!(conteo, rng, 8, SR, 1000, 48)   # calienta JIT

for N in (10_000, 100_000, 1_000_000)
    a = @allocated contar_niveles!(conteo, rng, 8, SR, N, 48)
    @printf("N=%9d  @allocated=%d B\n", N, a)
end
println("summarysize(conteo) = ", Base.summarysize(conteo), " B (48 Int64)")
