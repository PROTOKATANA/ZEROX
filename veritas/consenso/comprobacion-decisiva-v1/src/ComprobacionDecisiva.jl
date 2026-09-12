module ComprobacionDecisiva

# Motores reutilizados sin alterar sus archivos ni sus entornos (patrón
# AdmisionRetargetMultivista.jl:3-8).
include(joinpath(@__DIR__, "..", "..", "disponibilidad-causal-multivista-v1", "src",
                 "DisponibilidadCausalMultivista.jl"))
include(joinpath(@__DIR__, "..", "..", "retarget-causal-endogeno-v1", "src",
                 "RetargetCausalEndogeno.jl"))
const DCM = DisponibilidadCausalMultivista
const RCE = RetargetCausalEndogeno

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export DCM, RCE, UTXOSpec, TxSpec, CloseFrame, EconModel, Proposal, SealRecord,
       ControllerState, EstadoNodo, DeliveryKind, DelHeader, DelBody, DelContext,
       DeliveryEvent, Nodo, ReferenceNode, FastNode, PagoEvento, ConsumoEvento,
       EconomiaPublica, replay!, deliver_event!, procesar_eventos!, entregar_todo!,
       proyeccion_nodo, cutoff, validated_chain, snapshot, range_at,
       controller_projection, peso_dedup, peso_naive, control_peso_naive,
       control_reloj_local, test_controller, fixture_convergencia,
       fixture_doble_gasto, fixture_doble_gasto_ventana, fixture_heldzero,
       fixture_copias_rojas_sin_azul, fixture_desempate_color,
       fixture_copia_en_fusion_posterior, fixture_reorg_libera_billete,
       fixture_rama, parse_seed,
       ejecutar_convergencia, verificar_heldzero,
       verificar_doble_gasto, verificar_doble_gasto_ventana, verificar_reloj

end
