# GDR-v0.1 — GHOSTDAG + rank en Julia (CPU). Instrumento de estudio: ninguna regla
# de consenso se decide aquí; lo que el SPEC no determina queda como opción.
module GhostdagRank

export Params, P_DEFECTO,
       U3_OFF, U3_FILTER, U3_DYNAMIC,
       SP_SPEC, SP_PYTHON, SP_KASPA, SP_ZEROX,
       MERGE_SPEC, MERGE_PYTHON, MERGE_KASPA,
       BW256, BW256_CERO, BW256_DOS128, peso, peso_big, bits_necesarios,
       hash_de_id, ID32,
       EstadoReferencia, EstadoRapido,
       anadir!, cadena_seleccionada, orden_aplicacion, tips, virtual_sp, blueset,
       es_menor_rank, cmp_orden, cmp_python, cmp_kaspa,
       BloqueEspec, construir, generar_dag, ordenes_topologicos, entregar,
       equivalencia, proyeccion_gd, proyeccion_orden, proyeccion_gd_por_id,
       proyeccion_orden_por_id, gd_por_id_abstracto, id_a_texto

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

end # module
