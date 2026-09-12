function prepare_dcm(view::ArmView{DCM.RefView}, target::UInt64, chain::Vector{UInt64})
    # Conserva exclusivamente la evidencia local y reconstruye estado desde génesis.
    fresh = deepcopy(view.state.dcm)
    fresh.public = DCM.PublicState()
    empty!(fresh.undo)
    fresh.pending = 0
    for hid in chain
        outcome = DCM.apply_reference!(fresh, view.model.catalog, hid, view.model.policy)
        outcome === DCM.Applied || return fresh, outcome
    end
    return fresh, DCM.Applied
end

function reconstruct_controller(view::ArmView{DCM.RefView}, dcm::DCM.RefView,
                                chain::Vector{UInt64})
    model = view.model
    state = ControllerState(model.controller)
    for hid in chain
        frame = model.frames[hid]
        # Oráculo simple: vuelve a examinar todas las propuestas previas en cada sello.
        state.active_range = state.initial_range
        empty!(state.activations)
        for proposal in state.proposals
            if proposal.activation_slot <= frame.causal_seal_slot
                state.active_range = proposal.next_range
                push!(state.activations, proposal)
            end
        end
        events = snapshot(model, dcm, hid)
        step = RCE.causal_step(state.active_range, UInt64(length(events)), cutoff(model, frame),
            frame.causal_seal_slot, model.window_width, model.controller; reference=true)
        append_step!(state, model, frame, events, step)
    end
    return state
end
