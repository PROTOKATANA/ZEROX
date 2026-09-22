# IB-v0.1 — Identidad de billete: ¿qué se rompe si la identidad deja de llevar `chunk`?
#
# Instrumento de ESTUDIO. No fija parámetros de consenso ni redacta reglas de SPEC.
# Construido sobre `GhostdagRank` (GDR-v0.2) como ORÁCULO de GHOSTDAG: aquí no se
# reimplementa el orden ni el coloreo.
module IdentidadBillete

using SHA
import GhostdagRank as GDR

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export ModoId, MODO_A, MODO_B, MODO_C, NOMBRE_MODO,
       Solucion, solucion, oportunidad, identidad, clave_a,
       bucket_de, chunk_almacenado, gana, ganadores, pot_output, entropia, entropia_de,
       COLISION_CHUNK, W_CHUNK_BITS, N_DOM, N_SLOT, N_PK, N_SECTOR, N_HIST, N_PIEZA,
       N_BUCKET, N_FLOW, DOMINIO,
       BloqueEspec, Resultado, evaluar, evaluar_ref, evaluar_rapido, evaluar_bruto,
       fixtures_canonicos, equivalentes, violaciones_entropia, subuniverso,
       control_refinamiento, control_cruce, resumen, incoherencias_de_flujo, dag_honesto, gana

end # module
