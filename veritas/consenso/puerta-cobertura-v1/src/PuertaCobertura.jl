"""
    PuertaCobertura  —  PCO-v0.1

¿Se sostiene sola una particion de flujo de PoT, sin atacante?

El modulo esta partido en lo que LINEO §1 pide: `peso.jl` (el modelo de peso, en enteros
exactos), `proceso.jl` (el proceso de la diferencia de peso y su raiz de Lundberg), `rapido.jl`
(el kernel de `L(t)` y `t(ε)`), `simulacion.jl` (el oraculo de Monte Carlo y las magnitudes de
excursion), `referencia.jl` (oraculos lentos y exactos), `cobertura.jl` (la condicion economica y
`S_max`), `certificado.jl` (bolas de Arb) y `validacion.jl` (equivalencias e invariantes).

Nada de lo que publica `INFORME.md` es una constante escrita a mano: cada numero sale de una de
estas funciones, y `test/runtests.jl` barre parametros para comprobar que **cambia**.
"""
module PuertaCobertura

using Printf
using Random
using Random123
using Arblib
using SpecialFunctions: gamma_inc, loggamma, beta_inc

include("peso.jl")
include("proceso.jl")
include("rapido.jl")
include("simulacion.jl")
include("referencia.jl")
include("cobertura.jl")
include("certificado.jl")
include("validacion.jl")

export SR_MAX, NUM_CHUNKS, NUM_S_BUCKETS, DOS64, DOS128,
       valores_aceptados, peso_bloque, resto_suelo, prob_billete, tasa_peso,
       razon_cancelacion, desviacion_cancelacion, rango_de_piezas, rango_retarget,
       cuenta_alcanzable, sesgo_tasa,
       fraccion_azul, espacio_cubridor, Flujos, deriva, canonico,
       flujos_regimen, flujos_transitorio, lundberg, prob_ruina,
       techo_racional, techo_desplazado, ventana_poisson, prob_le, prob_no_positivo, prob_positivo,
       prob_banda, delta_red, prob_congelamiento_divergente, congelamiento_arcoseno,
       tasa_grandes_desvios, prob_cambio_posterior, tiempo_suficiente, tiempo_hasta,
       prob_empate, objetivo_automatico,
       rng_replica, Camino, recorrer, replicas, recorrer_realimentado, replicas_realimentadas,
       mc_congelamiento, mc_congelamiento_realimentado,
       clopper_pearson,
       prob_no_positivo_ref, skellam_pmf_ref, prob_cambio_posterior_ref,
       mc_cambio_posterior, mc_ruina, arcoseno_discreta, arcoseno_continua,
       media_arcoseno_discreta, congelamiento_ref, autocorrelacion_replicas,
       cola_arcoseno, horizonte_implicito_cola,
       horizonte_implicito_media,
       CostesMedidos, costes_repositorio, lecturas_por_TiB, nucleos_auditoria_por_TiB,
       nucleos_verif_pot, nucleos_prod_pot, s_max_iops, s_max_nucleos, s_max,
       rho_variable, rho_fijo, rho_produccion, umbral_probabilidad, tamano_minimo,
       tamano_minimo_productor, cobertura_equilibrio, pareto_tamanos,
       lundberg_arb, prob_cambio_posterior_arb, tasa_grandes_desvios_arb, jmax_poisson,
       prob_no_positivo_arb, prob_positivo_arb, tabla_poisson_arb, cola_poisson_chernoff,
       resumen_absorcion, resumen_ultimo_cambio

end # module
