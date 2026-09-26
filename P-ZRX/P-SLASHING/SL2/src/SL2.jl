#= SL-2 · SL2.jl
   Módulo de la calibración del castigo (Orden SL-2).

   Depende del modelo ratificado de DS-3 (`P-ZRX/P-DISUASION/DS3/src/`, revisado en
   `REVISION-DS3.md`) con dos correcciones del director:
     · la región de retención es `ρ_ret·T_v > V/N − c_r − I·M`, no «≳ 4.000»;
     · sin castigo correlacionado (DS-5).
   Y del reparto de espacio de DS-6 (empírico de un pool real, corrección A de convención) como
   caso central, con la Pareto de DS-3 como caso pesimista.

   Las faltas de definición y sus resoluciones declaradas están en `DEFINICIONES-FALTANTES.md`.
=#

module SL2

using Random
using Statistics
using SpecialFunctions
using StableRNGs
using Printf

export Reparto, Retencion, Pareto, Escenario, DistribucionEspacio, Empirica, ParetoDist, Granjero,
       alpha_estrella, beta_cruce, p_de_alpha, deficit_entero, deriva,
       primera_dp, primera_dp_absorbente, primera_absorbente_exacta, enumerar_exhaustivo,
       eventual, eventual_log10,
       beta_minimo_para_p, masa_prob, funcion_umbral, B_de,
       balance_medio, balance_var, p_saldo_cero, theta,
       perdida_castigo, coste_disuasion, ingreso_anual, max_perdida_honesta, f_media_de,
       condicion_disuasion, condicion_honesta, region_tv,
       B_empirico, B_par, B_par_exacta, cargar_farmers, limpiar_farmers, empirica,
       bootstrap_Bemp, ic_percentil,
       mc_ventana, mc_saldo_cero, mc_Bpar, mc_honesto, wilson, hash64, rng_replica,
       validar_primera_pasada, validar_alpha, validar_Bemp, validar_Bpar, validar_region

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

end # module SL2
