module IntentoV1

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export Medidas,
       Escenario,
       con,
       Resultado,
       lectura_mediciones,
       escenario_desde_medidas,
       prob_bucket,
       p_intento,
       n_eq,
       r_efectiva,
       maquinas,
       w_min_latencia,
       w_equilibrio,
       bytes_equivalentes,
       coste_por_solucion,
       barrer!,
       evaluar,
       evaluar_referencia,
       validar_referencia,
       comprobar_invariantes,
       rejilla_w,
       prob_bucket_exacta,
       p_intento_exacta,
       racional_exacto,
       contar_aceptados,
       d_empirica

end
