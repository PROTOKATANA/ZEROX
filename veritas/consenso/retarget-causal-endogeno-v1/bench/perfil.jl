using InteractiveUtils
using JET
using Profile
using RetargetCausalEndogeno

const U = UInt64

cfg = ControllerConfig(300, 10, 1, 2, 1, 2, 2, 1, 10, 900, 1,
                       RoundNearestEven)
scenario = Scenario("profile-synthetic", U(1000), U(40), U(4), U(3), P0, LG,
                    U(1024), U(2), U(1), U(3), U(7), U(16), U(13), U(2), U(4), cfg)
trace = generate_trace(U(20260911), scenario.horizon_slots,
                       scenario.honest_attempts, scenario.adversary_attempts)
types = (ExogenousTrace, Scenario)

simulate_fast(trace, scenario) # calentamiento fuera de las mediciones
jet_result = JET.report_opt(simulate_fast, types)
diagnostics = JET.get_reports(jet_result)

warntype = sprint(io -> code_warntype(io, simulate_fast, types))
contains_any = occursin("::Any", warntype)
contains_any && error("code_warntype contiene Any")

bytes = @allocated simulate_fast(trace, scenario)
Profile.clear()
@profile for _ in 1:200
    simulate_fast(trace, scenario)
end
entries = length(Profile.fetch())

println("workload=1000_slots_3_attempts_body_hold_16_synthetic")
println("jet_diagnostics=$(length(diagnostics))")
println("code_warntype_any=$contains_any")
println("return_type=$(only(Base.return_types(simulate_fast, types)))")
println("allocated_bytes=$bytes")
println("profile_entries=$entries")
