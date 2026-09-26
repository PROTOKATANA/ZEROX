# GDR — envoltorio local de solo lectura sobre el oráculo GHOSTDAG antiguo GDR-v0.2.
#
# `modelo.jl` y `referencia.jl` son copias literales de
# `veritas/consenso/ghostdag-rank-v1/src/{modelo,referencia}.jl` en `9681061`
# (sha256 en METODO.md). No se toca su lógica: la raíz sigue siendo el nodo 1, que
# en T04 se interpreta como el terminal `T` (D-P07). El módulo es de solo lectura
# para el resto de T04 (no se modifican sus ficheros).
module GDR

include("modelo.jl")
include("referencia.jl")

end # module GDR
