module AdmisionRetargetMultivista

# Motores reutilizados sin alterar sus archivos ni sus entornos.
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

export DCM, RCE, CloseFrame, ArmModel, ArmView, ReferenceView, FastView,
       replay!, projection, public_projection, controller_projection, range_at,
       deliver_header!, deliver_body!, deliver_invalid_body!, deliver_context!,
       negative_local_control, manual_model, branch_model, deliver_all!, validate_manual,
       parse_seed

end
