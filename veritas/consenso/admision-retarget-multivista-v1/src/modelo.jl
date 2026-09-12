# ARM-v0.1: tipos exactos de un instrumento de composición, sin reloj de red.
# El catálogo y la política son fijos. H es profundidad del prefijo y E eventos.
# Ambos controladores agregan O(H+E) estado. Las validaciones compartidas de
# snapshots y colisiones cuestan O(H*E+H^2); sólo el avance de activaciones del
# kernel es lineal. DCM conserva snapshots completos y comprobaciones repetidas.

struct CloseFrame
    history::UInt64
    cohort::UInt64
    causal_seal_slot::UInt64
end
CloseFrame(h::Integer, j::Integer, s::Integer) = CloseFrame(UInt64(h), UInt64(j), UInt64(s))

struct ArmModel
    catalog::DCM.Catalog
    frames::Dict{UInt64,CloseFrame}
    window_width::UInt64
    grace::UInt64
    controller::RCE.ControllerConfig
    policy::DCM.Policy
    function ArmModel(catalog::DCM.Catalog, frames::Vector{CloseFrame}, width::UInt64,
                      grace::UInt64, controller::RCE.ControllerConfig; policy::DCM.Policy=DCM.P0)
        width > 0 || throw(ArgumentError("positive window width required"))
        fd = Dict{UInt64,CloseFrame}()
        for frame in frames
            haskey(fd, frame.history) && throw(ArgumentError("duplicate CloseFrame"))
            haskey(catalog.histories, frame.history) || throw(ArgumentError("unknown CloseFrame history"))
            fd[frame.history] = frame
        end
        Set(keys(fd)) == Set(keys(catalog.histories)) || throw(ArgumentError("missing CloseFrame"))
        new(catalog, fd, width, grace, controller, policy)
    end
end
ArmModel(catalog::DCM.Catalog, frames::Vector{CloseFrame}, width::Integer, grace::Integer,
         controller::RCE.ControllerConfig; kwargs...) =
    ArmModel(catalog, frames, UInt64(width), UInt64(grace), controller; kwargs...)

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

# La publicación conjunta consiste en sustituir una única referencia ArmState.
# No se afirma durabilidad, paralelismo ni atomicidad de un almacén real.
struct ArmState{V<:DCM.AbstractView}
    dcm::V
    controller::ControllerState
end
mutable struct ArmView{V<:DCM.AbstractView}
    const model::ArmModel
    state::ArmState{V}
    pending::UInt64
end
ReferenceView(model::ArmModel, name::String="reference") = ArmView(model,
    ArmState(DCM.RefView(name, model.catalog; policy=model.policy), ControllerState(model.controller)), UInt64(0))
FastView(model::ArmModel, name::String="fast") = ArmView(model,
    ArmState(DCM.FastView(name, model.catalog; policy=model.policy), ControllerState(model.controller)), UInt64(0))

deliver_header!(v::ArmView, bid::UInt64) = DCM.deliver_header!(v.state.dcm, bid)
deliver_body!(v::ArmView, bid::UInt64, complete::Bool) = DCM.deliver_body!(v.state.dcm, bid, complete)
deliver_invalid_body!(v::ArmView, bid::UInt64) = DCM.deliver_invalid_body!(v.state.dcm, bid)
deliver_context!(v::ArmView, hid::UInt64, bid::UInt64, valid::Bool) =
    DCM.deliver_context!(v.state.dcm, hid, bid, valid)

function cutoff(model::ArmModel, frame::CloseFrame)
    count = Base.Checked.checked_add(frame.cohort, UInt64(1))
    return Base.Checked.checked_add(Base.Checked.checked_mul(count, model.window_width), model.grace)
end

function validated_chain(model::ArmModel, target::UInt64)
    chain = DCM.history_chain(model.catalog, target)
    chain === nothing && throw(ArgumentError("unknown/cyclic history"))
    DCM.history_structure_valid(model.catalog, target) || throw(ArgumentError("invalid DCM structure"))
    previous_seal = UInt64(0)
    for (index, hid) in enumerate(chain)
        frame = model.frames[hid]
        frame.cohort == UInt64(index - 1) || throw(ArgumentError("cohorts must start at zero and be consecutive"))
        frame.causal_seal_slot >= previous_seal || throw(ArgumentError("decreasing causal seal"))
        frame.causal_seal_slot >= cutoff(model, frame) || throw(ArgumentError("seal before cutoff"))
        previous_seal = frame.causal_seal_slot
    end
    return chain
end

function snapshot(model::ArmModel, dcm::DCM.AbstractView, hid::UInt64)
    h = model.catalog.histories[hid]
    events = dcm.public.counted[h.window]
    events == dcm.public.payable[h.window] || throw(ArgumentError("counted != payable"))
    length(Set(events)) == length(events) || throw(ArgumentError("duplicate snapshot event"))
    all(e -> e.history == hid, events) || throw(ArgumentError("snapshot source mismatch"))
    [e for e in dcm.public.journal if e.history == hid] == events ||
        throw(ArgumentError("snapshot is not exact journal projection"))
    return copy(events)
end

function append_step!(state::ControllerState, model::ArmModel, frame::CloseFrame,
                      events::Vector{DCM.EventId}, step)
    code, proposed_range, activation_slot, clamped = step
    # Enmienda Z0 (2026-09-12): HeldZero ya no se agenda. Agendar el rango del sello
    # como propuesta diferida lo revertiría a un valor obsoleto si otra propuesta
    # activó antes; "mantener" es no intervenir, como en MissedUpdate y Pending.
    if code === RCE.StepScheduled
        activation_slot > frame.causal_seal_slot || throw(ArgumentError("own/retroactive activation"))
        any(p -> p.activation_slot == activation_slot, state.proposals) &&
            throw(ArgumentError("activation collision"))
        push!(state.proposals, Proposal(frame.history, frame.cohort, activation_slot, proposed_range))
    end
    push!(state.seals, SealRecord(frame.history, model.catalog.histories[frame.history].window,
        frame.cohort, cutoff(model, frame), frame.causal_seal_slot, events, UInt64(length(events)),
        state.active_range, code, proposed_range, activation_slot, clamped))
    state.causal_slot = frame.causal_seal_slot
    return state
end

proposal_projection(p::Proposal) = (p.history, p.cohort, p.activation_slot, p.next_range)
function controller_projection(state::ControllerState)
    seals = [(history=s.history, window=s.window, cohort=s.cohort, cutoff=s.cutoff,
              seal_slot=s.causal_seal_slot, events=[(e.history,e.block) for e in s.events],
              observed=s.observed, input_range=s.input_range, code=s.code,
              output_range=s.output_range, activation_slot=s.activation_slot, clamped=s.clamped)
             for s in state.seals]
    return (initial_range=state.initial_range, active_range=state.active_range,
            causal_slot=state.causal_slot, seals=seals,
            proposals=proposal_projection.(state.proposals),
            agenda=[proposal_projection(p) for p in state.proposals if p.activation_slot > state.causal_slot],
            activations=proposal_projection.(state.activations))
end
public_projection(v::ArmView) =
    (dcm=DCM.projection(v.state.dcm), controller=controller_projection(v.state.controller))
projection(v::ArmView) = (public=public_projection(v), pending=v.pending)

# Consulta condicional a un slot causal explícito. No avanza la publicación del
# observador ni interpreta el reloj de recepción como tiempo de consenso.
function range_at(state::ControllerState, causal_slot::UInt64)
    active = state.initial_range
    for proposal in state.proposals
        proposal.activation_slot <= causal_slot && (active = proposal.next_range)
    end
    return active
end

function replay!(view::ArmView, target::UInt64)
    local candidate, controller
    try
        chain = validated_chain(view.model, target)
        candidate, outcome = prepare_dcm(view, target, chain)
        if outcome !== DCM.Applied
            view.pending = outcome === DCM.Pending ? candidate.pending : UInt64(0)
            return outcome
        end
        controller = reconstruct_controller(view, candidate, chain)
    catch error
        # Errores de dominio comprobados: no se publica la preparación parcial.
        # Fallos inesperados de implementación no se convierten en Invalid.
        (error isa ArgumentError || error isa OverflowError) || rethrow()
        view.pending = 0
        return DCM.Invalid
    end
    view.state = ArmState(candidate, controller)
    view.pending = 0
    return DCM.Applied
end

function negative_local_control(model::ArmModel, frame::CloseFrame, events::Vector{DCM.EventId},
                                reception_slot::UInt64, query_slot::UInt64)
    length(Set(events)) == length(events) || throw(ArgumentError("duplicate negative-control event"))
    local_seal = max(cutoff(model, frame), reception_slot)
    step = RCE.causal_step(model.controller.initial_range, UInt64(length(events)), cutoff(model, frame),
        local_seal, model.window_width, model.controller; reference=true)
    code, proposed, activation, _ = step
    scheduled = code === RCE.StepScheduled
    active = scheduled && activation <= query_slot ? proposed : model.controller.initial_range
    return (events=[(e.history,e.block) for e in events], code=code, local_seal_slot=local_seal,
            proposed_range=proposed, activation_slot=activation, active_range=active)
end
