# ComprobacionDecisiva-v1: tipos exactos de un instrumento de convergencia económica.
# Dos nodos con calendarios de entrega adversariales sobre el mismo conjunto de bloques;
# capa económica mínima entera sin criptografía (declarado) y peso azul deduplicado.
# Prohibido Float64 para dinero: importes y totales UInt64 con aritmética comprobada.
# Complejidad: la referencia reescanea propuestas por sello O(H^2); el kernel avanza un
# cursor O(H). La validación económica recorre cada bloque aplicado una vez, O(B).

struct UTXOSpec
    id::UInt64
    amount::UInt64
end

struct TxSpec
    piece_offset::UInt64
    variant::UInt64
    inputs::Vector{UInt64}
    outputs::Vector{UTXOSpec}
end

struct CloseFrame
    history::UInt64
    cohort::UInt64
    causal_seal_slot::UInt64
end
CloseFrame(h::Integer, j::Integer, s::Integer) = CloseFrame(UInt64(h), UInt64(j), UInt64(s))

struct EconModel
    catalog::DCM.Catalog
    txs::Dict{UInt64,TxSpec}
    genesis::Vector{UTXOSpec}
    frames::Dict{UInt64,CloseFrame}
    window_width::UInt64
    grace::UInt64
    controller::RCE.ControllerConfig
    policy::DCM.Policy
    function EconModel(catalog::DCM.Catalog, txs::Dict{UInt64,TxSpec},
                       genesis::Vector{UTXOSpec}, frames::Vector{CloseFrame},
                       width::UInt64, grace::UInt64, controller::RCE.ControllerConfig;
                       policy::DCM.Policy=DCM.P0)
        width > 0 || throw(ArgumentError("positive window width required"))
        Set(keys(txs)) == Set(keys(catalog.blocks)) || throw(ArgumentError("missing TxSpec"))
        length(unique(u.id for u in genesis)) == length(genesis) ||
            throw(ArgumentError("duplicate genesis utxo"))
        total = UInt64(0)
        for u in genesis
            total = Base.Checked.checked_add(total, u.amount)
        end
        for (bid, tx) in txs
            length(unique(tx.inputs)) == length(tx.inputs) ||
                throw(ArgumentError("duplicate input in TxSpec"))
            length(unique(o.id for o in tx.outputs)) == length(tx.outputs) ||
                throw(ArgumentError("duplicate output id in TxSpec"))
        end
        fd = Dict{UInt64,CloseFrame}()
        for frame in frames
            haskey(fd, frame.history) && throw(ArgumentError("duplicate CloseFrame"))
            haskey(catalog.histories, frame.history) ||
                throw(ArgumentError("unknown CloseFrame history"))
            fd[frame.history] = frame
        end
        Set(keys(fd)) == Set(keys(catalog.histories)) ||
            throw(ArgumentError("missing CloseFrame"))
        new(catalog, txs, genesis, fd, width, grace, controller, policy)
    end
end
EconModel(catalog::DCM.Catalog, txs::Dict{UInt64,TxSpec}, genesis::Vector{UTXOSpec},
          frames::Vector{CloseFrame}, width::Integer, grace::Integer,
          controller::RCE.ControllerConfig; kwargs...) =
    EconModel(catalog, txs, genesis, frames, UInt64(width), UInt64(grace), controller; kwargs...)

struct Proposal
    history::UInt64
    cohort::UInt64
    activation_slot::UInt64
    next_range::UInt64
end

struct SealRecord
    history::UInt64
    window::UInt64
    cohort::UInt64
    cutoff::UInt64
    causal_seal_slot::UInt64
    events::Vector{DCM.EventId}
    observed::UInt64
    input_range::UInt64
    code::RCE.StepCode
    output_range::UInt64
    activation_slot::UInt64
    clamped::Bool
end

mutable struct ControllerState
    initial_range::UInt64
    active_range::UInt64
    causal_slot::UInt64
    seals::Vector{SealRecord}
    proposals::Vector{Proposal}
    activations::Vector{Proposal}
end
ControllerState(cfg::RCE.ControllerConfig) =
    ControllerState(cfg.initial_range, cfg.initial_range, 0, SealRecord[], Proposal[], Proposal[])

struct PagoEvento
    context::UInt64
    block::UInt64
    utxo::UInt64
    amount::UInt64
end

struct ConsumoEvento
    context::UInt64
    block::UInt64
    utxo::UInt64
    amount::UInt64
end

struct EconomiaPublica
    payments::Vector{PagoEvento}
    consumptions::Vector{ConsumoEvento}
    available::Vector{UTXOSpec}
    total_paid::UInt64
    total_consumed::UInt64
end

# Aplica las transacciones de los ganadores en orden causal. Devuelve nothing si hay
# doble gasto, entrada desconocida o colisión de salida: la historia es Invalid y no
# se publica nada.
function aplicar_txs!(modelo::EconModel, ganadores::Vector{Tuple{UInt64,UInt64}})
    disponible = Dict{UInt64,UInt64}(u.id => u.amount for u in modelo.genesis)
    payments = PagoEvento[]
    consumptions = ConsumoEvento[]
    total_paid = UInt64(0)
    total_consumed = UInt64(0)
    for (hid, bid) in ganadores
        tx = modelo.txs[bid]
        for input in tx.inputs
            amount = pop!(disponible, input, nothing)
            amount === nothing && return nothing
            push!(consumptions, ConsumoEvento(hid, bid, input, amount))
            total_consumed = Base.Checked.checked_add(total_consumed, amount)
        end
        for out in tx.outputs
            haskey(disponible, out.id) && return nothing
            disponible[out.id] = out.amount
            push!(payments, PagoEvento(hid, bid, out.id, out.amount))
            total_paid = Base.Checked.checked_add(total_paid, out.amount)
        end
    end
    return EconomiaPublica(payments, consumptions,
        [UTXOSpec(k, v) for (k, v) in sort!(collect(disponible); by=first)],
        total_paid, total_consumed)
end

economia_inicial(modelo::EconModel) = aplicar_txs!(modelo, Tuple{UInt64,UInt64}[])

struct EstadoNodo{V<:DCM.AbstractView}
    dcm::V
    controller::ControllerState
    economia::EconomiaPublica
end

@enum DeliveryKind::UInt8 DelHeader DelBody DelContext

struct DeliveryEvent
    kind::DeliveryKind
    hid::UInt64
    bid::UInt64
end

mutable struct Nodo{V<:DCM.AbstractView}
    const modelo::EconModel
    nombre::String
    estado::EstadoNodo{V}
    pending::UInt64
    cola::Vector{DeliveryEvent}
    cursor::Int
    objetivo::UInt64
    respaldo::UInt64
end

ReferenceNode(modelo::EconModel, nombre::String, cola::Vector{DeliveryEvent},
              objetivo::UInt64, respaldo::UInt64) = Nodo(modelo, nombre,
    EstadoNodo(DCM.RefView(nombre, modelo.catalog; policy=modelo.policy),
               ControllerState(modelo.controller), economia_inicial(modelo)),
    UInt64(0), cola, 0, objetivo, respaldo)
FastNode(modelo::EconModel, nombre::String, cola::Vector{DeliveryEvent},
         objetivo::UInt64, respaldo::UInt64) = Nodo(modelo, nombre,
    EstadoNodo(DCM.FastView(nombre, modelo.catalog; policy=modelo.policy),
               ControllerState(modelo.controller), economia_inicial(modelo)),
    UInt64(0), cola, 0, objetivo, respaldo)

function deliver_event!(nodo::Nodo)
    nodo.cursor < length(nodo.cola) || return nothing
    nodo.cursor += 1
    event = nodo.cola[nodo.cursor]
    ok = event.kind === DelHeader ? DCM.deliver_header!(nodo.estado.dcm, event.bid) :
         event.kind === DelBody ? DCM.deliver_body!(nodo.estado.dcm, event.bid, true) :
         DCM.deliver_context!(nodo.estado.dcm, event.hid, event.bid, true)
    ok || throw(ArgumentError("fixture delivery rejected"))
    objetivo = replay!(nodo, nodo.objetivo)
    respaldo = objetivo === DCM.Applied ? objetivo : replay!(nodo, nodo.respaldo)
    return (objetivo, respaldo)
end

function procesar_eventos!(nodo::Nodo, n::Int)
    for _ in 1:n
        deliver_event!(nodo) === nothing && return nodo
    end
    return nodo
end

function entregar_todo!(nodo::Nodo)
    for bid in sort!(collect(keys(nodo.modelo.catalog.blocks)))
        DCM.deliver_header!(nodo.estado.dcm, bid) || error("fixture header rejected")
        DCM.deliver_body!(nodo.estado.dcm, bid, true) || error("fixture body rejected")
    end
    for key in sort!(collect(keys(nodo.modelo.catalog.context_truth)))
        DCM.deliver_context!(nodo.estado.dcm, key[1], key[2],
                             nodo.modelo.catalog.context_truth[key]) ||
            error("fixture context rejected")
    end
    return nodo
end

function cutoff(modelo::EconModel, frame::CloseFrame)
    count = Base.Checked.checked_add(frame.cohort, UInt64(1))
    return Base.Checked.checked_add(Base.Checked.checked_mul(count, modelo.window_width),
                                    modelo.grace)
end

function validated_chain(modelo::EconModel, target::UInt64)
    chain = DCM.history_chain(modelo.catalog, target)
    chain === nothing && throw(ArgumentError("unknown/cyclic history"))
    DCM.history_structure_valid(modelo.catalog, target) ||
        throw(ArgumentError("invalid DCM structure"))
    previous_seal = UInt64(0)
    for (index, hid) in enumerate(chain)
        frame = modelo.frames[hid]
        frame.cohort == UInt64(index - 1) ||
            throw(ArgumentError("cohorts must start at zero and be consecutive"))
        frame.causal_seal_slot >= previous_seal ||
            throw(ArgumentError("decreasing causal seal"))
        frame.causal_seal_slot >= cutoff(modelo, frame) ||
            throw(ArgumentError("seal before cutoff"))
        previous_seal = frame.causal_seal_slot
    end
    return chain
end

function snapshot(modelo::EconModel, dcm::DCM.AbstractView, hid::UInt64)
    h = modelo.catalog.histories[hid]
    events = dcm.public.counted[h.window]
    events == dcm.public.payable[h.window] ||
        throw(ArgumentError("counted != payable"))
    length(Set(events)) == length(events) ||
        throw(ArgumentError("duplicate snapshot event"))
    all(e -> e.history == hid, events) ||
        throw(ArgumentError("snapshot source mismatch"))
    [e for e in dcm.public.journal if e.history == hid] == events ||
        throw(ArgumentError("snapshot is not exact journal projection"))
    return copy(events)
end

function append_step!(state::ControllerState, modelo::EconModel, frame::CloseFrame,
                      events::Vector{DCM.EventId}, step)
    code, proposed_range, activation_slot, clamped = step
    # Enmienda Z0 (2026-09-12): HeldZero ya no se agenda. Agendar el rango del sello
    # como propuesta diferida lo revertiría a un valor obsoleto si otra propuesta
    # activó antes; "mantener" es no intervenir, como en MissedUpdate y Pending.
    if code === RCE.StepScheduled
        activation_slot > frame.causal_seal_slot ||
            throw(ArgumentError("own/retroactive activation"))
        any(p -> p.activation_slot == activation_slot, state.proposals) &&
            throw(ArgumentError("activation collision"))
        push!(state.proposals, Proposal(frame.history, frame.cohort, activation_slot,
                                        proposed_range))
    end
    push!(state.seals, SealRecord(frame.history,
        modelo.catalog.histories[frame.history].window, frame.cohort,
        cutoff(modelo, frame), frame.causal_seal_slot, events, UInt64(length(events)),
        state.active_range, code, proposed_range, activation_slot, clamped))
    state.causal_slot = frame.causal_seal_slot
    return state
end

proposal_projection(p::Proposal) = (p.history, p.cohort, p.activation_slot, p.next_range)

function controller_projection(state::ControllerState)
    seals = [(history=s.history, window=s.window, cohort=s.cohort, cutoff=s.cutoff,
              seal_slot=s.causal_seal_slot, events=[(e.history, e.block) for e in s.events],
              observed=s.observed, input_range=s.input_range, code=s.code,
              output_range=s.output_range, activation_slot=s.activation_slot,
              clamped=s.clamped) for s in state.seals]
    return (initial_range=state.initial_range, active_range=state.active_range,
            causal_slot=state.causal_slot, seals=seals,
            proposals=proposal_projection.(state.proposals),
            agenda=[proposal_projection(p) for p in state.proposals
                    if p.activation_slot > state.causal_slot],
            activations=proposal_projection.(state.activations))
end

function proyeccion_economia(e::EconomiaPublica)
    return (payments=[(p.context, p.block, p.utxo, p.amount) for p in e.payments],
            consumptions=[(c.context, c.block, c.utxo, c.amount) for c in e.consumptions],
            available=[(u.id, u.amount) for u in e.available],
            total_paid=e.total_paid, total_consumed=e.total_consumed)
end

function proyeccion_nodo(nodo::Nodo)
    return (dcm=DCM.projection(nodo.estado.dcm),
            controller=controller_projection(nodo.estado.controller),
            economia=proyeccion_economia(nodo.estado.economia),
            pending=nodo.pending)
end

# Consulta condicional a un slot causal explícito. No avanza la publicación ni
# interpreta el reloj de recepción como tiempo de consenso.
function range_at(state::ControllerState, causal_slot::UInt64)
    active = state.initial_range
    for proposal in state.proposals
        proposal.activation_slot <= causal_slot && (active = proposal.next_range)
    end
    return active
end

# Publicación conjunta DCM + controlador + economía. Solo sucede al completar la
# cadena; Pending e Invalid dejan el estado público previo intacto.
function replay!(nodo::Nodo, target::UInt64)
    local candidate, controller, economia
    try
        chain = validated_chain(nodo.modelo, target)
        candidate, outcome = prepare_dcm(nodo, target, chain)
        if outcome !== DCM.Applied
            nodo.pending = outcome === DCM.Pending ? candidate.pending : UInt64(0)
            return outcome
        end
        economia = economic_scan(nodo, candidate, chain)
        economia === nothing && (nodo.pending = 0; return DCM.Invalid)
        controller = reconstruct_controller(nodo, candidate, chain)
    catch error
        # Errores de dominio comprobados: no se publica la preparación parcial.
        # Fallos inesperados de implementación no se convierten en Invalid.
        (error isa ArgumentError || error isa OverflowError) || rethrow()
        nodo.pending = 0
        return DCM.Invalid
    end
    nodo.estado = EstadoNodo(candidate, controller, economia)
    nodo.pending = 0
    return DCM.Applied
end

# Peso azul deduplicado: el billete identifica la oportunidad; las copias agrupan
# a la misma oportunidad y no multiplican el peso.
function peso_dedup(modelo::EconModel, hid::UInt64, consumidos::Set{UInt64})
    h = modelo.catalog.histories[hid]
    return UInt64(length(DCM.objective_winners(modelo.catalog, h, modelo.policy, consumidos)))
end

# Control negativo: agrupa por (ticket, piece_offset, variant); cada copia cuenta
# por separado y multiplica el peso. Debe detectarse y no usarse en el estado.
function peso_naive(modelo::EconModel, hid::UInt64, consumidos::Set{UInt64})
    h = modelo.catalog.histories[hid]
    agrupado = Set{Tuple{UInt64,UInt64,UInt64}}()
    for bid in h.blocks
        b = modelo.catalog.blocks[bid]
        b.ticket in consumidos && continue
        b.origin_window == h.window || continue
        DCM.eligible(b.color) || continue
        tx = modelo.txs[bid]
        push!(agrupado, (b.ticket, tx.piece_offset, tx.variant))
    end
    return UInt64(length(agrupado))
end

function control_peso_naive(modelo::EconModel, hid::UInt64)
    consumidos = Set{UInt64}()
    for p in DCM.history_chain(modelo.catalog, hid)
        p == hid && break
        for b in DCM.objective_winners(modelo.catalog, modelo.catalog.histories[p],
                                       modelo.policy, consumidos)
            push!(consumidos, b.ticket)
        end
    end
    dedup = peso_dedup(modelo, hid, consumidos)
    naive = peso_naive(modelo, hid, consumidos)
    frame = modelo.frames[hid]
    step_dedup = RCE.causal_step(modelo.controller.initial_range, dedup,
        cutoff(modelo, frame), frame.causal_seal_slot, modelo.window_width,
        modelo.controller; reference=true)
    step_naive = RCE.causal_step(modelo.controller.initial_range, naive,
        cutoff(modelo, frame), frame.causal_seal_slot, modelo.window_width,
        modelo.controller; reference=true)
    return (dedup=dedup, naive=naive, rango_dedup=step_dedup[2],
            rango_naive=step_naive[2],
            naive_detected=naive != dedup && step_dedup[2] != step_naive[2])
end

# Control negativo del reloj local: la misma evidencia con distinto instante local
# de cierre produce retargets distintos; el camino causal usa causal_seal_slot.
function control_reloj_local(modelo::EconModel, frame::CloseFrame,
                             events::Vector{DCM.EventId}, reception_slot::UInt64,
                             query_slot::UInt64)
    length(Set(events)) == length(events) ||
        throw(ArgumentError("duplicate negative-control event"))
    local_seal = max(cutoff(modelo, frame), reception_slot)
    step = RCE.causal_step(modelo.controller.initial_range, UInt64(length(events)),
        cutoff(modelo, frame), local_seal, modelo.window_width, modelo.controller;
        reference=true)
    code, proposed, activation, _ = step
    scheduled = code === RCE.StepScheduled
    active = scheduled && activation <= query_slot ? proposed : modelo.controller.initial_range
    return (events=[(e.history, e.block) for e in events], code=code,
            local_seal_slot=local_seal, proposed_range=proposed,
            activation_slot=activation, active_range=active)
end
