# PPP-v0.1 — @code_warntype sobre el camino caliente (LINEO §3.1, pregunta 2 de §6).
using InteractiveUtils
include(joinpath(@__DIR__, "..", "src", "PodaPost.jl"))
using .PodaPost
using StableRNGs

rng = StableRNG(UInt64(1))
conteo = zeros(Int, 48)
SR = UInt64(1) << 62

for (nombre, llamada) in (
    ("contar_niveles!", () -> @code_warntype contar_niveles!(conteo, rng, 8, SR, 10, 48)),
    ("distancia_min", () -> @code_warntype distancia_min(rng, 8)),
    ("nivel", () -> @code_warntype nivel(UInt64(0), SR)),
    ("p_nivel_exacta", () -> @code_warntype p_nivel_exacta(4, SR, 1)),
)
    println("===== ", nombre, " =====")
    llamada()
    println()
end
