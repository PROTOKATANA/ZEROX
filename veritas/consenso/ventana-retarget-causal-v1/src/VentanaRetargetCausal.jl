module VentanaRetargetCausal

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export ApplyCode, Applied, Pending, Invalid, BlockStatus, Complete, PendingData, Bad,
       Color, Blue, RedK, RedU3, SelectionPolicy, P0, P1,
       WindowSpec, L0Rule, LGRule, Scenario, Candidate, Batch, EventId, Event, State,
       ApplyResult, ControllerCode, Bootstrap, ControllerPending, Ready,
       ControllerResult, apply_reference, apply_fast, close_window!, undo!,
       counted_ids, payable_ids, validate_equivalence, state_projection, execute_fixtures,
       causal_sufficient

end
