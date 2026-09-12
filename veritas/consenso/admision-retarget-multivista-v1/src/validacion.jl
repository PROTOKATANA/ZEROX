function test_controller(; rounding::RCE.RoundMode=RCE.RoundFloor)
    # Valores elegidos del vector ARM, unidades abstractas de rango/adjudicaciones.
    return RCE.ControllerConfig(100, 10, 1, 1, 1, 2, 2, 1, 1, 1000, 1, rounding)
end

function manual_model(; causal_seal::UInt64=UInt64(10), policy::DCM.Policy=DCM.P0,
                      rounding::RCE.RoundMode=RCE.RoundFloor)
    blocks = [DCM.BlockSpec(UInt64(i), UInt64(i), UInt64(700), UInt64(i), DCM.Blue, UInt64[])
              for i in 1:5]
    push!(blocks, DCM.BlockSpec(UInt64(6), UInt64(1), UInt64(700), UInt64(6), DCM.RedK, UInt64[]))
    histories = [DCM.HistorySpec(UInt64(100), UInt64(0), UInt64(700), UInt64[1,2,3,4,5,6]),
                 DCM.HistorySpec(UInt64(200), UInt64(0), UInt64(700), UInt64[2,3,4,5,6])]
    truth = Dict((h.id,b.id) => true for h in histories for b in blocks)
    catalog = DCM.Catalog(blocks, histories; context_truth=truth)
    frames = [CloseFrame(100, 0, causal_seal), CloseFrame(200, 0, causal_seal)]
    return ArmModel(catalog, frames, 10, 0, test_controller(; rounding); policy)
end

function branch_model(depth::Int; policy::DCM.Policy=DCM.P0,
                      rounding::RCE.RoundMode=RCE.RoundFloor)
    depth > 0 || throw(ArgumentError("positive synthetic depth"))
    blocks = [DCM.BlockSpec(UInt64(1), UInt64(1), UInt64(700), UInt64(1), DCM.Blue, UInt64[])]
    histories = [DCM.HistorySpec(UInt64(900), UInt64(0), UInt64(700), UInt64[1])]
    frames = [CloseFrame(900, 0, 10)]
    for branch in 1:2, level in 1:depth
        base = branch == 1 ? 1_000 : 2_000
        bid = UInt64(base + level)
        hid = UInt64(10_000 + base + level)
        window = UInt64(30_000 + base + level)
        parent_bid = level == 1 ? UInt64(1) : UInt64(base + level - 1)
        parent_hid = level == 1 ? UInt64(900) : UInt64(10_000 + base + level - 1)
        push!(blocks, DCM.BlockSpec(bid, bid, window, UInt64(level + 1), DCM.Blue, UInt64[parent_bid]))
        push!(histories, DCM.HistorySpec(hid, parent_hid, window, UInt64[bid]))
        push!(frames, CloseFrame(hid, UInt64(level), UInt64(10 * (level + 1))))
    end
    truth = Dict((h.id,b.id) => true for h in histories for b in blocks)
    model = ArmModel(DCM.Catalog(blocks, histories; context_truth=truth), frames,
                     10, 0, test_controller(; rounding); policy)
    return (model=model, target_a=UInt64(11_000 + depth), target_b=UInt64(12_000 + depth))
end

function deliver_all!(view::ArmView; missing_bodies=Set{UInt64}(), missing_headers=Set{UInt64}(),
                      missing_contexts=Set{Tuple{UInt64,UInt64}}())
    for bid in sort!(collect(keys(view.model.catalog.blocks)))
        bid in missing_headers || deliver_header!(view, bid) || error("fixture header rejected")
        if !(bid in missing_bodies)
            okay = bid in view.model.catalog.invalid_bodies ? deliver_invalid_body!(view, bid) :
                                                              deliver_body!(view, bid, true)
            okay || error("fixture body rejected")
        end
    end
    for key in sort!(collect(keys(view.model.catalog.context_truth)))
        key in missing_contexts && continue
        deliver_context!(view, key[1], key[2], view.model.catalog.context_truth[key]) ||
            error("fixture context rejected")
    end
    return view
end

function parse_seed(args::Vector{String})
    length(args) == 2 && args[1] == "--seed" || throw(ArgumentError("usage: --seed DECIMAL_U64"))
    token = args[2]
    !isempty(token) && all(c -> '0' <= c <= '9', token) || throw(ArgumentError("ASCII decimal seed required"))
    return parse(UInt64, token)
end

function validate_manual(seed::UInt64)
    model = manual_model()
    ana = deliver_all!(FastView(model, "Ana"); missing_bodies=Set(UInt64[6]))
    bruno = deliver_all!(FastView(model, "Bruno"); missing_bodies=Set(UInt64[1]))
    @assert replay!(ana, UInt64(100)) === DCM.Applied
    @assert replay!(bruno, UInt64(100)) === DCM.Pending
    @assert isempty(bruno.state.controller.seals)
    @assert replay!(bruno, UInt64(200)) === DCM.Applied
    @assert deliver_body!(bruno, UInt64(1), true)
    @assert replay!(bruno, UInt64(100)) === DCM.Applied
    @assert projection(ana) == projection(bruno)
    snapshot_ids = ana.state.dcm.public.counted[UInt64(700)]
    early = negative_local_control(model, model.frames[UInt64(100)], snapshot_ids, UInt64(9), UInt64(21))
    late = negative_local_control(model, model.frames[UInt64(100)], snapshot_ids, UInt64(21), UInt64(21))
    @assert early.events == late.events
    @assert early.active_range == 200 && late.active_range == 100
    @assert range_at(ana.state.controller, UInt64(19)) == 100
    @assert range_at(ana.state.controller, UInt64(20)) == 200
    return (seed=seed, observed=length(snapshot_ids), negative_detected=true,
            causal_convergence=true, causal_range_at_21=range_at(ana.state.controller, UInt64(21)),
            naive_early_range=early.active_range, naive_late_range=late.active_range)
end
