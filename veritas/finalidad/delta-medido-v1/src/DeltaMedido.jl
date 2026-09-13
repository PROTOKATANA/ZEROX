module DeltaMedido

using Random
using StableRNGs
using Distributions

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export GrafoCSR, ParametrosRed, Red, Evento, MotorRapido,
       grado, construir_red, exigir_conexo, es_conexo,
       construir_csr, base_regular, conmutar, grafo_regular_por_conmutacion,
       grafo_erdos_renyi, pareja_de_indice, generar_latencias,
       calendario_poisson, semilla_derivada,
       inicio_envio, arribo_vecino, siguiente_libre,
       correr_referencia, correr!, push_evento!, pop_evento!,
       deltas_por_bloque, cuantil_pct, invariantes, validar_equivalencia,
       tam_cabecera, tam_anuncio, tam_bloque_completo, utilizacion, regimen,
       cuotas_concentracion, pesos_de_cuotas, creadores_ponderados,
       medias_llegada, media_bloque_espacio, delta_barra_uniforme,
       delta_barra_sorteo_por_cuota, delta_barra_peso_por_creador

end
