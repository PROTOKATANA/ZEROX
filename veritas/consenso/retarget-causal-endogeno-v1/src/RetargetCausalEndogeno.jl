module RetargetCausalEndogeno

include("modelo.jl")
include("controlador.jl")
include("simulacion.jl")
include("referencia.jl")
include("validacion.jl")

export RoundMode, RoundFloor, RoundNearestEven, ControllerConfig, next_range_reference,
       next_range_fast, causal_step, StepCode, StepPending, StepHeldZero, StepScheduled,
       StepMissedUpdate,
       SelectionPolicy, P0, P1, LatePolicy, L0, LG, Scenario, ExogenousTrace,
       generate_trace, stable_opportunity_ids, simulate_reference, simulate_fast, MetricPending, SimulationMetrics,
       validate_equivalence, execute_fixtures

end
