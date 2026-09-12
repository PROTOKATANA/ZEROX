# Oráculo deliberadamente simple: reescanea desde el catálogo. Reconstruye DCM desde
# génesis, reexamina todas las propuestas previas en cada sello (O(H^2)) y usa la
# aritmética BigInt del controlador (reference=true).

function prepare_dcm(nodo::Nodo{DCM.RefView}, target::UInt64, chain::Vector{UInt64})
    # Conserva exclusivamente la evidencia local y reconstruye estado desde génesis.
    fresh = deepcopy(nodo.estado.dcm)
    fresh.public = DCM.PublicState()
    empty!(fresh.undo)
    fresh.pending = 0
    for hid in chain
        outcome = DCM.apply_reference!(fresh, nodo.modelo.catalog, hid, nodo.modelo.policy)
        outcome === DCM.Applied || return fresh, outcome
    end
    return fresh, DCM.Applied
end

function economic_scan(nodo::Nodo{DCM.RefView}, candidate::DCM.RefView,
                       chain::Vector{UInt64})
    # Reescanea los ganadores desde el catálogo con los tickets consumidos acumulados,
    # independiente del estado público de DCM.
    ganadores = Tuple{UInt64,UInt64}[]
    consumidos = Set{UInt64}()
    for hid in chain
        h = nodo.modelo.catalog.histories[hid]
        for b in DCM.objective_winners(nodo.modelo.catalog, h, nodo.modelo.policy,
                                       consumidos)
            push!(consumidos, b.ticket)
            push!(ganadores, (hid, b.id))
        end
    end
    return aplicar_txs!(nodo.modelo, ganadores)
end

function reconstruct_controller(nodo::Nodo{DCM.RefView}, dcm::DCM.RefView,
                                chain::Vector{UInt64})
    modelo = nodo.modelo
    state = ControllerState(modelo.controller)
    for hid in chain
        frame = modelo.frames[hid]
        # Oráculo simple: vuelve a examinar todas las propuestas previas en cada sello.
        state.active_range = state.initial_range
        empty!(state.activations)
        for proposal in state.proposals
            if proposal.activation_slot <= frame.causal_seal_slot
                state.active_range = proposal.next_range
                push!(state.activations, proposal)
            end
        end
        events = snapshot(modelo, dcm, hid)
        step = RCE.causal_step(state.active_range, UInt64(length(events)),
            cutoff(modelo, frame), frame.causal_seal_slot, modelo.window_width,
            modelo.controller; reference=true)
        append_step!(state, modelo, frame, events, step)
    end
    return state
end
