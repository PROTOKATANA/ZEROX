function prepare_dcm(view::ArmView{DCM.FastView}, target::UInt64, chain::Vector{UInt64})
    candidate = deepcopy(view.state.dcm)
    outcome = DCM.replay_fast!(candidate, view.model.catalog, target, view.model.policy)
    return candidate, outcome
end

function reconstruct_controller(view::ArmView{DCM.FastView}, dcm::DCM.FastView,
                                chain::Vector{UInt64})
    model = view.model
    state = ControllerState(model.controller)
    for hid in chain
        frame = model.frames[hid]
        next = length(state.activations) + 1
        while next <= length(state.proposals)
            proposal = state.proposals[next]
            proposal.activation_slot <= frame.causal_seal_slot || break
            state.active_range = proposal.next_range
            push!(state.activations, proposal)
            next += 1
        end
        events = snapshot(model, dcm, hid)
        step = RCE.causal_step(state.active_range, UInt64(length(events)), cutoff(model, frame),
            frame.causal_seal_slot, model.window_width, model.controller; reference=false)
        append_step!(state, model, frame, events, step)
    end
    return state
end
