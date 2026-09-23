"""
    SegundoVdfV1

Auditoría P-SEGUNDO-VDF: validación del beneficio neto y del protocolo concreto de
una segunda cadena secuencial AES de revelación retardada (`R-FIN-14(h)`).

Categoría: `seguridad` (dominante); `consenso`, `red` y `rendimiento` secundarias.
Ningún parámetro se adopta: `L, I, W_dec, D, S_max, Lrev, ρ, α` son símbolos.
"""
module SegundoVdfV1

using Printf
using Random
using StableRNGs
using Statistics

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("coste.jl")
include("consenso.jl")
include("escenarios.jl")
include("validacion.jl")

export Cfg, Tray, Bufs, ResultadoBarrido
export construir!, extremos!, fin_horizonte, simular_replica!, barrido, reiniciar!
export sortear!, cuantil_hist, fraccion_excedencia, resumen_rho
export tau_maxplus, ventana_exacta, tiempo_bajo_exacto, cuantil_exacto
export rho_estrella, rho_estrella_exacta, I_frontera, I_frontera_exacta,
       I_frontera_historica, I_frontera_entera, I_minima_entera,
       rho_max_cota_sqrt, rho_max_cota_cflu09, rho_max_factible_entero,
       holgura_puntualidad
export w_dec_slots, lineas_timekeeper, nucleos_verificador, instantes_por_hora,
       lineas_revelacion_por_epoca, lineas_revelacion_todos_candidatos,
       coste_ponerse_al_dia, cadena_larga, Lrev_max_una_llamada
export VERIFY_S_POR_SLOT, PROVE_S_POR_SLOT, N_SLOT_NOMINAL, U32_MAX
export tabla_calibracion, control_historico_h6
export tabla_escenarios_consistente, control_filas_viejas, tabla_semilla, tabla_regimenes,
       cfg_base, vmax_det, datos_causales_semilla, tasa_rachas_cerrada, control_rachas
export mapa_reglas_vdf, transicion_estado_pot, ESTADOS_POT
export controles_independientes, equivalencia_oraculo, equivalencia_cuantil,
       control_filas_publicadas, filas_publicadas, posicion_en
     export PRIMITIVA, segmentacion_zxpot, tabla_coste

end # module
