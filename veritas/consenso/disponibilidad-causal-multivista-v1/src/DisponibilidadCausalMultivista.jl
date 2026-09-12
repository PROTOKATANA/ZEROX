module DisponibilidadCausalMultivista

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export Policy, P0, P1, Color, Blue, RedK, RedU, Outcome, Applied, Pending, Invalid, PolicyMismatch,
       BlockSpec, HistorySpec, Catalog, RefView, FastView, deliver_header!, deliver_body!,
       deliver_invalid_body!, deliver_context!,
       apply_reference!, apply_fast!, replay_reference!, replay_fast!, undo_reference!,
       undo_fast!, projection, execute_fixture

end
