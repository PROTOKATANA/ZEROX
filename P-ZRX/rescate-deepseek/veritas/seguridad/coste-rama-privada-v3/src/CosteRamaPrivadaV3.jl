# CRP-v0.3 — Umbral de una rama privada bajo flujo PoT, DAG real y red asimétrica.
#
# Derivado de CRP-v0.2 (que NO se cierra) con las correcciones del encargo v0.3:
# separación terminal/primera-pasada/eventual; flujo por bloque y R-FIN-5 sobre todo
# past(B); presentación/validación/fusión/decisión del observador; S flujos conjuntos
# desde oportunidades compartidas; red con autor-inmediato y Δ=0 real; único productor
# sin rojos propios; déficits en blue_work con semilla fija; barridos; intervalos con
# cobertura simultánea; η_h/η_a; fixtures U2/U3. Instrumento de estudio.
module CosteRamaPrivadaV3

using Random
using StableRNGs
using Distributions: Beta, quantile

export Validez, VALIDA, INVALIDA, PENDIENTE,
       EstadoNormativo, SPEC_VIGENTE, CANDIDATA, ORACULO_ABSTRACTO,
       IMPLEMENTADA_SIN_CABLEAR, INTEGRADA, NORM_PENDIENTE, EXCLUIDA,
       Unidad, TRABAJO, SLOTS, SEGUNDOS, BLOQUES, BLUE_WORK,
       Escenario, ResultadoDP,
       prob_empate_eventual, prob_superar_eventual, prob_empate_finita, prob_superar_finita,
       prob_superar_antes, dp_exacta_racional, corrimiento_alpha_prob,
       dp_acotada, dp_adaptativa, prob_superar_dp, prob_empate_dp, invertir_monotona,
       dp_distribucion, dp_terminal,
       ResultadoEventos, resultado_eventos, prob_eventual_pm1,
       cp_intervalo, alpha_prob_simultaneo, alpha_prob_determinista,
       Redondeo, REDONDEO_FLOOR, REDONDEO_NEAREST_EVEN,
       ConfigRCE, ControladorRCE, paso_causal, cerrar_cohorte!, avanzar!, rango_en,
       corte_cohorte, frontera_b,
       EventoPot, DescriptorFlujo, prefijo_flujo, compatible_rfin5, construir_flujo,
       proxima_inyeccion, primera_divergencia, u2_repite_en_pasado,
       fixture_u2_u3, fixture_u2_misma_rama,
       SimboloDAG, agregar!, color_contextual, blues_de, blue_work_de, blue_work_mergeset,
       peso_de, puntas, blue_work_bigint, ultimo_motivo,
       BloqueV3, Decision, ConfigSimV3, ResultadoV3, SimuladorV3, simular_v3!,
       oportunidades_compartidas, fixture_rojo_conocido, fixture_cero_rojos,
       wilson, mc_superar, mc_terminal, prob_superar_toy_S, toy_S_deriva, tasa_rojos_v3,
       conserva, mc_max_S, identidad_iid_S,
       control_escalar_S, cota_union, ramas_fijas_max, ramas_aditivas,
       frase_veredicto, VERSION_MODELO

const VERSION_MODELO = "CRP-v0.3"

include("modelo.jl")
include("referencia.jl")
include("dp.jl")
include("eventos.jl")
include("controlador_rce.jl")
include("gdr_wrapper.jl")
include("flujo.jl")
include("dag_sim.jl")
include("validacion.jl")

end # module
