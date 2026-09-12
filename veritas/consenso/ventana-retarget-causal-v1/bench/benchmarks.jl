using BenchmarkTools
using VentanaRetargetCausal

function representative_batch(n::Int)
    blocks = Candidate[]
    sizehint!(blocks, n)
    for i in 1:n
        ticket = UInt64(1 + (i % 70))
        slot = UInt64(ticket % 9)
        color = i % 11 == 0 ? RedU3 : i % 2 == 0 ? Blue : RedK
        push!(blocks, Candidate(UInt64(i), ticket, slot, UInt64(i), color,
                                Complete, UInt64(i % 5), UInt64(i % 3)))
    end
    return Batch(1, 0, 10, blocks)
end

spec = WindowSpec(0, 16, 3)
scenario = Scenario(P0, LGRule(), spec)
batch = representative_batch(180)
@assert validate_equivalence(State(), batch, scenario)

reference_trial = @benchmark apply_reference(State(), $batch, $scenario) samples=100 evals=1
fast_trial = @benchmark apply_fast(State(), $batch, $scenario) samples=100 evals=1

println("workload=180_blocks_70_ticket_cycle_fixture")
println("reference_median_ns=$(median(reference_trial).time)")
println("reference_median_bytes=$(median(reference_trial).memory)")
println("reference_median_allocs=$(median(reference_trial).allocs)")
println("kernel_median_ns=$(median(fast_trial).time)")
println("kernel_median_bytes=$(median(fast_trial).memory)")
println("kernel_median_allocs=$(median(fast_trial).allocs)")
