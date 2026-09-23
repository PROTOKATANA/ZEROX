"""
CoberturaParcela — cobertura y preexistencia de una parcela Autonomys.

Instrumento del encargo `P-ZRX/P-COBERTURA`. Categoría `criptografia` (dominante:
propiedades de un compromiso y de una prueba; la estadística de auditoría es
secundaria y se cita).

Separa tres coberturas (encargo §2.1):
  1. cobertura de los datos PÚBLICOS   (KZG; ya existe, no sirve),
  2. cobertura del OBJETO CARO         (tablas PoS; no existe hoy),
  3. FORMA ALMACENADA                  (no se prueba ni para un chunk),
más dos dimensiones temporales: PREEXISTENCIA y VINCULACIÓN.

Este paquete implementa el juego «regeneración contra auditoría», su frontera
exacta `φ*(N,B)` y el coste absoluto del tramposo. Todas las entradas son símbolos.
"""
module CoberturaParcela

using Random
using Random123
using Printf
using Statistics

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export Entrada, ventana_s, B_unidades, B_entero, almacenamiento_forzado, ahorro_maximo,
       deteccion_posible, piezas_por_TiB,
       trabajo_nucleo_s_por_TiB, trabajo_nucleo_h_por_TiB, nucleos_por_TiB,
       maquinas_por_TiB, nucleos_equivalentes_por_maquina, w_cruce_disco_slots,
       energia_kWh_por_TiB, energia_kWh_almacenar, tasa_lectura_honesta,
       tasa_regeneracion_adversaria,
       frontera_exacta, almacenamiento_forzado_exacta,
       cola_hiper_exacta, cola_binomial_exacta, T_para_beta_exacta,
       deteccion_acumulada_exacta, cola_hiper_intervalo,
       cota_tv_hiper_binomial, tv_hiper_binomial_exacta, clopper_pearson,
       TablaLogFact, log_binomial, cola_hiper_rapida, cola_hiper_barrido!,
       barrido_phi!,
       rng_replica, Muestra, una_auditoria!, p_deteccion_mc, mc_dentro_de_cp,
       autocorrelacion_lag1, contraste_kernel_referencia,
       BYTES_TiB, PIEZA_B, TAU_S,
       PIEZAS_POR_SEGMENTO, MIN_SECTOR_LIFETIME_SEG, MAX_PIEZAS_POR_SECTOR, coste_registro

end # module
