using BenchmarkTools
using RetargetCausalEndogeno

const U = UInt64
cfg = ControllerConfig(300, 10, 1, 2, 1, 2, 2, 1, 10, 900, 1, RoundNearestEven)

function scenario(horizon; body_hold=4, label="scale")
    Scenario(label, U(horizon), U(40), U(4), U(3), P0, LG, U(1024),
             U(2), U(1), U(3), U(7), U(body_hold), U(13), U(2), U(4), cfg)
end

for horizon in (1000, 2000, 4000)
    s = scenario(horizon)
    trace = generate_trace(U(20260911), s.horizon_slots, s.honest_attempts,
                           s.adversary_attempts)
    horizon == 1000 && @assert validate_equivalence(trace, s)
    trial = @benchmark simulate_fast($trace, $s) samples=20 evals=1
    println("profile=scale horizon=$horizon kernel_median_ns=$(median(trial).time) " *
            "bytes=$(median(trial).memory) allocs=$(median(trial).allocs)")
end

for hold in (0, 4, 16)
    s = scenario(2000; body_hold=hold, label="backlog")
    trace = generate_trace(U(20260911), s.horizon_slots, s.honest_attempts,
                           s.adversary_attempts)
    trial = @benchmark simulate_fast($trace, $s) samples=20 evals=1
    m = simulate_fast(trace, s)
    println("profile=body_backlog body_hold=$hold kernel_median_ns=$(median(trial).time) " *
            "pending_headers=$(m.max_pending_headers) pending_slots=$(m.pending_slots) " *
            "bytes=$(median(trial).memory) allocs=$(median(trial).allocs)")
end

sref = scenario(1000; label="oracle")
tref = generate_trace(U(20260911), sref.horizon_slots, sref.honest_attempts,
                      sref.adversary_attempts)
ref_trial = @benchmark simulate_reference($tref, $sref) samples=10 evals=1
println("profile=oracle horizon=1000 reference_median_ns=$(median(ref_trial).time) " *
        "bytes=$(median(ref_trial).memory) allocs=$(median(ref_trial).allocs)")
