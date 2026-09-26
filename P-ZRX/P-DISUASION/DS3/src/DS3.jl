#= DS-3 · DS3.jl
   Calculadora y Monte Carlo del coste mínimo de los ataques principales de ZEROX,
   B0 frente a B1 y candidatos. Especificación: `resultados-DS2/MODELO.md` ratificado.

   Proyecto Julia aislado (LINEO §1). Categoría declarada: `seguridad` (dominante);
   `consenso`, `economía` y `almacenamiento` (secundarias).
=#

module DS3

using Printf
using Random
using SpecialFunctions: erfc
using StableRNGs: StableRNG

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export Retencion, Pareto, Reparto, TablaLogFact
export PIEZA_B, BYTES_TIB, TAU_S, T_TABLA_S, R_24H, T_M3_S, T_UNIDAD_S, R_MAQUINA_S, D_A_S,
       Vatio_NUCLEO, Vatio_TIB, HASH_CPU_16, HASH_GPU_1070, J_POR_HASH_GPU
export alpha_estrella, alpha_estrella_exacta, deriva, mu_publica, mu_privada,
       beta_cruce, p_de_alpha, deficit_esperado, deficit_entero, eventual, eventual_log10
export theta, balance_medio, balance_var, p_saldo_cero, p_saldo_cero_normal, rsd_pequeno, masa_prob,
       masa_espacio_bajo_b, coef_reclutamiento, coste_reclutamiento, perdida_por_reclutado,
       soborno_necesario, region_disuasion
export piezas_por_TiB, ventana_s, B_unidades, almacenamiento_forzado, ahorro_maximo,
       deteccion_posible, nucleos_por_TiB, maquinas_por_TiB, energia_regenerar_kWh,
       energia_almacenar_kWh, razon_energia, w_cruce_disco
export N_eq, coste_por_solucion, w_min_latencia, w_equilibrio, p_calibrado
export coste_identidades, coste_por_byte, fraccion_ingreso
export energia_pow, tiempo_pow, potencia_filecoin, pasos_bp
export hash64, rng_replica
export primera_dp, primera_bigfloat_dp, primera_dp_absorbente, mc_ventana, mc_saldo_cero,
       wilson, cola_hiper_rapida, log_binomial, beta_minimo_para_p,
       barrido_ventana, barrido_cobertura
export enumerar_exhaustivo, primera_absorbente_exacta, eventual_exacto,
       almacenamiento_forzado_exacta, cola_hiper_exacta, muestra_saldo_espaciado!
export validar_primera_pasada, validar_cobertura, validar_almacenamiento, validar_alpha,
       validar_todo

end # module DS3
