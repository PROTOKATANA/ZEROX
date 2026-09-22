"""
    Equivocacion

Enumerador exhaustivo del encargo **P-EQUIVOCACION**: ¿alcanza la infracción estrecha
(mismo `TicketId` y slot + dos `pre_hash` + dos sellos válidos + ambas cabeceras válidas
en su contexto) a todo el doble farmeo que importa, bajo el perfil 1a (`L_slots ≥ F_slots`,
`C-FLU-01`), y a qué precio en falsos positivos?

Implementa, con aritmética entera exacta y sin criptografía:
  * el ancla de época `C-FLU-04` sobre la vista truncada `C-FLU-03`,
  * el flujo `C-FLU-10` con la entropía de `C-FLU-12`,
  * GHOSTDAG restringido: `C-GD-01`, `C-GD-03`…`C-GD-08`,
  * las tres identidades de billete del §1 del encargo,
  * el barrido de κ sobre la ventana de reorganización.

No fija ningún parámetro de consenso: `L`, `F`, `I`, `S_max`, `k`, `α` son entradas.
"""
module Equivocacion

using Random
using StableRNGs

export Bloque, Dag, agregar!, nbloques, peso_bloque, Vista, seleccion_vista, vista_epoca,
       cadena_vista, ancla_epoca, entropia_ancla, inyecciones, flujo_slot,
       construir_dos_ramas, estructura_ok, u2_ok,
       pasado_ref, ghostdag_ref, ancla_ref, flujo_ref,
       PreDag, Buffers, seleccion_vista!, ancla_rapida!, inyecciones_rapidas,
       flujos_iguales, espectro_flujo, espectro_flujo_lento,
       Pieza, Solucion, mezcla64, distancia, elegible, reto_de_flujo, flujo_activo,
       identidad, IDENTIDADES, Universo, rango_para_media, ganadores, evasion_posible,
       kappa_slot, kappa, slots_rama,
       cadena_slots, configuracion, carrera_V1, rejilla_hipotesis,
       comparar_anclas, comparar_flujos, propiedad_P1, propiedad_P2, dag_aleatorio, contraste_aleatorio

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("espectro.jl")
include("rejilla.jl")
include("validacion.jl")

end # module
