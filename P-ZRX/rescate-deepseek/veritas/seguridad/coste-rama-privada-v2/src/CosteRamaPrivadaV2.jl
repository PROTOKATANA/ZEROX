# CRP-v0.2 — Umbral de una rama privada bajo flujo PoT, DAG real y red asimétrica.
#
# Categoría Veritas: `seguridad` (dominante); `consenso` y `rendimiento` (secundarias).
# Instrumento de estudio. NINGUNA regla de consenso se decide aquí: lo que el SPEC no
# determina se clasifica `Pendiente` y no se rellena con constantes elegidas.
#
# Prohibiciones del encargo §5 respetadas:
#  - no se reimplementa GHOSTDAG: se reutiliza GDR-v0.2 (`GhostdagRank`) por ruta;
#  - no se ejecutan auditorías Python;
#  - el controlador del SPEC queda Pendiente; RCE/ARM se implementa como perfil candidato;
#  - `S` y el hardware son parámetros, no hechos.
module CosteRamaPrivadaV2

using Random
using StableRNGs

export Validez, VALIDA, INVALIDA, PENDIENTE,
       EstadoNormativo, SPEC_VIGENTE, CANDIDATA, ORACULO_ABSTRACTO,
       IMPLEMENTADA_SIN_CABLEAR, INTEGRADA, NORM_PENDIENTE, EXCLUIDA,
       Unidad, TRABAJO, SLOTS, SEGUNDOS, BLOQUES, BLUE_WORK,
       Escenario, ResultadoDP,
       prob_empate_eventual, prob_superar_eventual, prob_empate_finita, prob_superar_finita,
       prob_superar_antes, dp_exacta_racional, corrimiento_alpha_prob,
       dp_acotada, dp_adaptativa, prob_superar_dp, prob_empate_dp, invertir_monotona,
       Redondeo, REDONDEO_FLOOR, REDONDEO_NEAREST_EVEN,
       ConfigRCE, ControladorRCE, paso_causal, cerrar_cohorte!, avanzar!, rango_en,
       corte_cohorte, frontera_b,
       EventoPot, DescriptorFlujo, prefijo_flujo, compatible_rfin5,
       puede_incorporar_pasado, control_escalar_S, cota_union, ramas_fijas_max, ramas_aditivas,
       SimboloDAG, agregar!, color_contextual, blues_de, blue_work_de, blue_work_mergeset,
       peso_de, puntas, blue_work_bigint, ultimo_motivo,
       BloqueDAG, ConfigSim, ResultadoSim, Simulador, simular!,
       fixture_rojo_conocido, fixture_cero_rojos,
       wilson, mc_superar, prob_superar_toy_S, toy_S_deriva, tasa_rojos_calibrada,
       conserva, mc_max_S, identidad_iid_S,
       frase_veredicto, VERSION_MODELO

const VERSION_MODELO = "CRP-v0.2"

include("modelo.jl")
include("referencia.jl")
include("dp.jl")
include("controlador_rce.jl")
include("rfin5.jl")
include("gdr_wrapper.jl")
include("dag_sim.jl")
include("validacion.jl")

end # module
