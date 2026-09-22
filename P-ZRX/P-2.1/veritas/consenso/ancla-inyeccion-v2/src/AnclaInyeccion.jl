# ANCLA-v0.2 — P-2.1 v3: instrumento de estudio del ancla de orden R-FIN-1.
# GHOSTDAG: GDR-v0.2 reutilizado SIN MODIFICAR (include). CPU, Julia, sin Python.
module AnclaInyeccion

using StableRNGs
using SpecialFunctions
using Random: randn

# Ruta a GDR-v0.2 desde la raíz del repo (src/../../../../../veritas/consenso/...)
include(joinpath(@__DIR__, "..", "..", "..", "..", "..",
                 "veritas", "consenso", "ghostdag-rank-v1", "src", "GhostdagRank.jl"))
using .GhostdagRank

include("modelo.jl")
include("red.jl")
include("kernel.jl")
include("medicion.jl")
include("referencia.jl")
include("validacion.jl")
include("puerta.jl")

export Params4A, umbrales, plan_replica, Escenario, Mundo, correr!,
       correr_replica, medir_umbral, curva_g, ajuste_exponencial, l_min,
       r_calibrado, ResultadoUmbral, ResReplica, ResEscenario,
       ancla_definitiva, escenarios,
       correr_replica_ctrl9c, correr_replica_ctrl11c, ancla_en,
       GRID_9C, SS_11C, DEVS_11C,
       skellam_pmf, p_cambio_lider, deriva_absorcion, s_max_racional,
       condicion_cobertura, contraste_historico,
       mundo_pequeno, validar_pequeno, validar_contra_referencia,
       validar_heap_tips, vector_artefacto_vista_completa, criterio_alfa,
       rng_replica

end # module
