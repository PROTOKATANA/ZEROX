# CRP-v0.1 — estabilidad de tipos del kernel (LINEO §3.1). Debe salir sin `Any` rojo.
using InteractiveUtils
using StableRNGs

include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivada.jl"))
using .CosteRamaPrivada

const P = P_DEFECTO
println("== @code_warntype simular_rama_rapido (kernel) ==")
@code_warntype simular_rama_rapido(StableRNG(1), 0.5, P; n_slots=10)
