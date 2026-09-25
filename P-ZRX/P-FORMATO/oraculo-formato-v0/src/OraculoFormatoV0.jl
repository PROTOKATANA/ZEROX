# Envoltura de paquete para que `Pkg.test()` (V4) tenga un módulo que cargar. La referencia
# independiente exigida por ORDEN-W02 §9 vive íntegra en `src/referencia.jl`; este archivo no
# añade semántica.

module OraculoFormatoV0

include("referencia.jl")

end
