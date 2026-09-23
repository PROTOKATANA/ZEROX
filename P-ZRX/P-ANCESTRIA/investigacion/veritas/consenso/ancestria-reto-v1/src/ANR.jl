#=  ANR.jl — módulo del instrumento ANR-v0.1 (anclaje del reto a profundidad d).

    P-ZRX/P-ANCESTRIA/investigacion/veritas/consenso/ancestria-reto-v1/

Categoría declarada: `consenso` (dominante) — el objeto es una regla de anclaje del reto de
consenso; `seguridad` (secundaria), por el umbral de grinding. Motivo en `INFORME.md`.
=#
module ANR

using Printf

include("modelo.jl")
include("rapido.jl")
include("referencia.jl")
include("validacion.jl")

end # module ANR
