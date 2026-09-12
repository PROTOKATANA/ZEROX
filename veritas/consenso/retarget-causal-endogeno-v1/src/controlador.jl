@inline function divide_round(num::T, den::T, mode::RoundMode) where {T<:Integer}
    den > 0 || throw(DivideError())
    q, r = divrem(num, den)
    mode === RoundFloor && return q
    complement = den - r
    return r < complement ? q : r > complement ? Base.Checked.checked_add(q, one(T)) :
           iseven(q) ? q : Base.Checked.checked_add(q, one(T))
end

function next_range_reference(current::UInt64, observed::UInt64, cfg::ControllerConfig)
    observed == 0 && return current, false
    blend = (BigInt(cfg.gain_den) - cfg.gain_num) * observed +
            BigInt(cfg.gain_num) * cfg.target_count
    raw = divide_round(BigInt(current) * blend, BigInt(cfg.gain_den) * observed, cfg.rounding)
    lower = div(BigInt(current) * cfg.step_lo_num, cfg.step_lo_den)
    upper = cld(BigInt(current) * cfg.step_hi_num, cfg.step_hi_den)
    stepped = clamp(raw, lower, upper)
    bounded = clamp(stepped, BigInt(cfg.range_min), BigInt(cfg.range_max))
    return UInt64(bounded), bounded != raw
end

function next_range_fast(current::UInt64, observed::UInt64, cfg::ControllerConfig)
    observed == 0 && return current, false
    blend = Base.Checked.checked_add(
        Base.Checked.checked_mul(UInt128(cfg.gain_den - cfg.gain_num), UInt128(observed)),
        Base.Checked.checked_mul(UInt128(cfg.gain_num), UInt128(cfg.target_count)))
    num = Base.Checked.checked_mul(UInt128(current), blend)
    den = Base.Checked.checked_mul(UInt128(cfg.gain_den), UInt128(observed))
    raw = divide_round(num, den, cfg.rounding)
    lower = div(Base.Checked.checked_mul(UInt128(current), UInt128(cfg.step_lo_num)),
                UInt128(cfg.step_lo_den))
    upper_num = Base.Checked.checked_mul(UInt128(current), UInt128(cfg.step_hi_num))
    upper = cld(upper_num, UInt128(cfg.step_hi_den))
    stepped = clamp(raw, lower, upper)
    bounded = clamp(stepped, UInt128(cfg.range_min), UInt128(cfg.range_max))
    return UInt64(bounded), bounded != raw
end

function causal_step(current::UInt64, observed::Union{Nothing,UInt64}, cutoff::UInt64,
                     seal_slot::UInt64, window_width::UInt64,
                     cfg::ControllerConfig; reference::Bool=false)
    window_width > 0 || throw(ArgumentError("window width"))
    seal_slot >= cutoff || throw(ArgumentError("window is not closed"))
    observed === nothing && return (StepPending, current, UInt64(0), false)
    first_boundary = Base.Checked.checked_mul(
        Base.Checked.checked_add(cutoff ÷ window_width, UInt64(1)), window_width)
    delay_extra = Base.Checked.checked_mul(cfg.activation_delay_windows - UInt64(1), window_width)
    activation = Base.Checked.checked_add(first_boundary, delay_extra)
    seal_slot < activation || return (StepMissedUpdate, current, activation, false)
    # Enmienda Z0 (2026-09-12): HeldZero es no-op. La activación devuelta es 0 para que
    # NINGÚN llamante pueda agendar la propuesta: agendar R_j diferido revertiría el rango
    # a un valor obsoleto en lugar de mantenerlo.
    observed == 0 && return (StepHeldZero, current, UInt64(0), false)
    next, clamped = reference ? next_range_reference(current, observed, cfg) :
                                next_range_fast(current, observed, cfg)
    return (StepScheduled, next, activation, clamped)
end

causal_step(current::Integer, observed::Union{Nothing,Integer}, cutoff::Integer,
            seal_slot::Integer, window_width::Integer, cfg::ControllerConfig; kwargs...) =
    causal_step(UInt64(current), observed === nothing ? nothing : UInt64(observed),
                UInt64(cutoff), UInt64(seal_slot), UInt64(window_width), cfg; kwargs...)
