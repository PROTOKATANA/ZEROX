# CRP-v0.1 — ¿Cuánto cuesta construir en privado una rama con más blue_work que la honesta?
# Instrumento de estudio. Ninguna regla de consenso se decide aquí. Ver CONTRATO.md.
module CosteRamaPrivada

using StableRNGs
using Random

export DOS128, peso_exacto, peso_relativo,
       Parametros, P_DEFECTO, tasa_esperada, trabajo_esperado,
       AnclaControlador, CTRL_FIJO, CTRL_REACTIVO, CTRL_INVERSO,
       Controlador, actualiza_controlador,
       ProtocoloRef, POW_LINEAL, GHOSTDAG_POW, POST_DAG, trabajo_rama,
       prob_alcance_binomial, prob_alcance_difusion,
       cuota_multistream, α_efectivo_multistream,
       CotaInvariancia, cota_invariancia, trabajo_esperado_exacto,
       ruina_exacta, poisson_exponencial, simular_rama_referencia,
       umbral_medio, α_estrella_medio, pmf_poisson, pmf_cambio_neto, prob_alcance_dp,
       poisson_knuth, simular_rama_rapido, simular_raza, barrido_alpha, alpha_cruce,
       curva_corta_mc, efecto_varianza_sr, ruta_gdr, RUTA_GDR, incluir_ghostdag, params_gdr,
       construir_rama_gdr, medir_rama, medir_rama_normalizada,
       experimento_gdr_invariancia, experimento_gdr_controlador, experimento_u2u3,
       error_invariancia, chequear_invariancia_trabajo, equivalencia_poisson,
       equivalencia_trabajo, validar_curva_corta

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

end # module
