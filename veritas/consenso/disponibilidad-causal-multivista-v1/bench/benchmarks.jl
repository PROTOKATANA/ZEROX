using BenchmarkTools
using DisponibilidadCausalMultivista

const U = UInt64

function linear_workload(depth::Int)
    blocks = BlockSpec[]; histories = HistorySpec[]
    for i in 1:depth
        id = U(i); parent_block = i == 1 ? U[] : U[id - U(1)]
        push!(blocks, BlockSpec(id, id, id, id, Blue, parent_block))
        push!(histories, HistorySpec(id, i == 1 ? U(0) : id - U(1), id, U[id]))
    end
    context_truth = Dict((U(i), U(ancestor)) => true for i in 1:depth for ancestor in 1:i)
    cat = Catalog(blocks, histories; context_truth); view = FastView("bench", cat)
    for i in 1:depth
        id = U(i); deliver_header!(view, id); deliver_body!(view, id, true)
        for ancestor in 1:i
            deliver_context!(view, id, U(ancestor), true)
        end
    end
    return cat, view
end

function apply_chain!(view, cat, depth)
    for i in 1:depth
        apply_fast!(view, cat, U(i), P0) === Applied || error("unexpected outcome")
    end
    return view
end

for depth in (16, 32, 64)
    cat, prepared = linear_workload(depth)
    trial = @benchmark apply_chain!(v, $cat, $depth) setup=(v=deepcopy($prepared)) samples=10 evals=1
    println("profile=full_snapshot_depth depth=$depth median_ns=$(median(trial).time) " *
            "bytes=$(median(trial).memory) allocs=$(median(trial).allocs)")
end

function fork_workload(depth::Int)
    blocks = BlockSpec[BlockSpec(U(1), U(1), U(100), U(1), Blue, U[])]
    histories = HistorySpec[HistorySpec(U(10), U(0), U(100), U[1])]
    for branch in 1:2, level in 1:depth
        base = branch == 1 ? 1_000 : 2_000
        bid = U(base + level); hid = U(10_000 + base + level); window = U(base + level)
        parent_bid = level == 1 ? U(1) : U(base + level - 1)
        parent_hid = level == 1 ? U(10) : U(10_000 + base + level - 1)
        push!(blocks, BlockSpec(bid, bid, window, U(level), Blue, U[parent_bid]))
        push!(histories, HistorySpec(hid, parent_hid, window, U[bid]))
    end
    context_truth = Dict((h.id, b.id) => true for h in histories for b in blocks)
    cat = Catalog(blocks, histories; context_truth); view = FastView("reorg", cat)
    for b in blocks
        deliver_header!(view, b.id); deliver_body!(view, b.id, true)
    end
    # Preparación fuera de la región medida; toda pareja conocida es válida en este workload.
    for h in histories, b in blocks
        deliver_context!(view, h.id, b.id, true)
    end
    apply_fast!(view, cat, U(10), P0) === Applied || error("base")
    for level in 1:depth
        apply_fast!(view, cat, U(11_000 + level), P0) === Applied || error("branch A")
    end
    return cat, view, U(12_000 + depth)
end

for depth in (16, 32, 64)
    cat, branch_a, target_b = fork_workload(depth)
    check = deepcopy(branch_a)
    @assert replay_fast!(check, cat, target_b, P0) === Applied
    @assert projection(check).public.current == target_b
    trial = @benchmark replay_fast!(v, $cat, $target_b, P0) setup=(v=deepcopy($branch_a)) samples=10 evals=1
    println("profile=deep_reorg branch_depth=$depth median_ns=$(median(trial).time) " *
            "bytes=$(median(trial).memory) allocs=$(median(trial).allocs)")
end
