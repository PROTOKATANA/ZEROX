module SembradorV1

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export ParametrosMargen,
       ResultadoMargen,
       adelanto_nucleo,
       desafios_conocidos,
       evaluar_margen,
       evaluar_referencia,
       barrer!,
       validar_referencia

end
