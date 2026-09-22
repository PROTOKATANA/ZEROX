module RangoV1

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export ConfigControlador, gamma, A_sr, peso_big, peso_fast, razon_ref, razon_cerrada, deficit,
       divide_round_half_even, rejilla_par, cota_par_inferior, cota_par_superior,
       distancia_bidireccional, A_sr_enumerado, razon_producto, controlador_ref,
       activacion_ref, precondicion_u128, cabe_en_u256, controlador_fast, rango_esperado,
       Comprobacion, srs_de_regresion, validar_A_circulo, validar_razon_cerrada,
       validar_paridad, validar_dominio, validar_controlador, validar_ancho,
       validar_activacion, validar_z0, validar_deriva

end
