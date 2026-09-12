# Kernel: reutiliza el replay DCM con BitSet e índices, avanza un cursor sobre las
# propuestas pendientes (O(H)) y usa la aritmética UInt128 comprobada del controlador
# (reference=false). El barrido económico lee el estado público ya aplicado.

function prepare_dcm(nodo::Nodo{DCM.FastView}, target::UInt64, chain::Vector{UInt64})
    candidate = deepcopy(nodo.estado.dcm)
    outcome = DCM.replay_fast!(candidate, nodo.modelo.catalog, target, nodo.modelo.policy)
    return candidate, outcome
end

function economic_scan(nodo::Nodo{DCM.FastView}, candidate::DCM.FastView,
                       chain::Vector{UInt64})
    # Lee los ganadores ya aplicados por DCM (counted por ventana, en orden).
    ganadores = Tuple{UInt64,UInt64}[]
    for hid in chain
        for e in snapshot(nodo.modelo, candidate, hid)
            push!(ganadores, (hid, e.block))
        end
    end
    return aplicar_txs!(nodo.modelo, ganadores)
end

function reconstruct_controller(nodo::Nodo{DCM.FastView}, dcm::DCM.FastView,
                                chain::Vector{UInt64})
    modelo = nodo.modelo
    state = ControllerState(modelo.controller)
    for hid in chain
        frame = modelo.frames[hid]
        next = length(state.activations) + 1
        while next <= length(state.proposals)
            proposal = state.proposals[next]
            proposal.activation_slot <= frame.causal_seal_slot || break
            state.active_range = proposal.next_range
            push!(state.activations, proposal)
            next += 1
        end
        events = snapshot(modelo, dcm, hid)
        step = RCE.causal_step(state.active_range, UInt64(length(events)),
            cutoff(modelo, frame), frame.causal_seal_slot, modelo.window_width,
            modelo.controller; reference=false)
        append_step!(state, modelo, frame, events, step)
    end
    return state
end
