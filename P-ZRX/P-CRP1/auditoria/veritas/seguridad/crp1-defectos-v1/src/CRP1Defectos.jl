# CRP1Defectos — recálculo independiente y exacto de las cifras publicadas por CRP-v0.1.
#
# Auditoría P-CRP1. Este paquete NO reutiliza el código de `veritas/seguridad/coste-rama-privada-v1/`
# para los recálculos: reimplementa el modelo desde el contrato (C-GD-01, predicado PoAS) y valida
# contra oráculos independientes. El instrumento original sólo se usa, en la copia de trabajo, para
# reproducir lo publicado y localizar los cargos.
#
# Presupuesto declarado (LINEO §7): ≤ 4 hilos, ≤ 8 GiB de RAM, ≤ 1 GiB de disco temporal.
module CRP1Defectos

using Printf
using Random
using LinearAlgebra
using StableRNGs

export DOS64, DOS128,
    peso_exacto, valores_aceptados, prob_billete, trabajo_por_ensayo, descomposicion_trabajo,
    razon_crp, razon_exacta, prob_empate_reticula, prob_superar_reticula,
    α_min_empate, α_min_superar,
    ParametrosVarianza, sr_adversario, medias_varianza,
    cuota_multistream, α_min_multistream, α_rojos_asimetricos, TABLA_ROJOS,
    conteo_residuos_por_enumeracion, ruina_unitaria_sistema_racional,
    ruina_unitaria_enumeracion, verificar_martingala, cota_martingala,
    cota_inferior_horizonte, mejor_cota_inferior_horizonte, poisson_inversa,
    pmf_poisson_f64, pmf_poisson_vec, logfact_acum, splitmix64,
    soporte_incremento, dp_ruina_conservada, alcance_compuesto, tabla_granularidad,
    varianza_exacta, quantil_normal, Phi, ic_wilson, ic_hoeffding,
    mc_varianza, autocorrelacion_lag1_consecutivas,
    validar_conteo_residuos, validar_ruina_forma_cerrada, validar_dp_contra_cotas,
    validar_varianza_exacta_contra_mc, validar_descomposicion_trabajo, validar_pmf_poisson

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

end # module
