@enum RoundMode::UInt8 RoundFloor RoundNearestEven
@enum StepCode::UInt8 StepPending StepHeldZero StepScheduled StepMissedUpdate
@enum SelectionPolicy::UInt8 P0 P1
@enum LatePolicy::UInt8 L0 LG

struct ControllerConfig
    initial_range::UInt64
    target_count::UInt64
    gain_num::UInt64
    gain_den::UInt64
    step_lo_num::UInt64
    step_lo_den::UInt64
    step_hi_num::UInt64
    step_hi_den::UInt64
    range_min::UInt64
    range_max::UInt64
    activation_delay_windows::UInt64
    rounding::RoundMode
    function ControllerConfig(initial_range::UInt64, target_count::UInt64,
            gain_num::UInt64, gain_den::UInt64, step_lo_num::UInt64,
            step_lo_den::UInt64, step_hi_num::UInt64, step_hi_den::UInt64,
            range_min::UInt64, range_max::UInt64, activation_delay_windows::UInt64,
            rounding::RoundMode)
        target_count > 0 || throw(ArgumentError("target_count must be positive"))
        0 < gain_num <= gain_den || throw(ArgumentError("gain must be in (0,1]"))
        step_lo_num > 0 && step_lo_den > 0 && step_hi_num > 0 && step_hi_den > 0 ||
            throw(ArgumentError("clamp ratios must be positive"))
        step_lo_num <= step_lo_den || throw(ArgumentError("lower clamp must not increase"))
        step_hi_num >= step_hi_den || throw(ArgumentError("upper clamp must not decrease"))
        UInt128(step_lo_num) * step_hi_den <= UInt128(step_hi_num) * step_lo_den ||
            throw(ArgumentError("lower step clamp exceeds upper"))
        0 < range_min <= initial_range <= range_max || throw(ArgumentError("range bounds"))
        activation_delay_windows > 0 || throw(ArgumentError("activation must be delayed"))
        BigInt(range_max) * gain_den * typemax(UInt64) <= typemax(UInt128) ||
            throw(ArgumentError("configuration exceeds exact UInt128 kernel domain"))
        new(initial_range, target_count, gain_num, gain_den, step_lo_num, step_lo_den,
            step_hi_num, step_hi_den, range_min, range_max, activation_delay_windows, rounding)
    end
end

ControllerConfig(initial_range::Integer, target_count::Integer, gain_num::Integer,
    gain_den::Integer, step_lo_num::Integer, step_lo_den::Integer,
    step_hi_num::Integer, step_hi_den::Integer, range_min::Integer, range_max::Integer,
    activation_delay_windows::Integer, rounding::RoundMode) =
    ControllerConfig(UInt64(initial_range), UInt64(target_count), UInt64(gain_num),
        UInt64(gain_den), UInt64(step_lo_num), UInt64(step_lo_den), UInt64(step_hi_num),
        UInt64(step_hi_den), UInt64(range_min), UInt64(range_max),
        UInt64(activation_delay_windows), rounding)

struct MetricPending
    reason::Symbol
end

struct Scenario
    label::String
    horizon_slots::UInt64
    window_width::UInt64
    grace::UInt64
    admission_width::UInt64
    selection::SelectionPolicy
    late::LatePolicy
    draw_scale::UInt64
    honest_attempts::UInt64
    adversary_attempts::UInt64
    honest_delay_max::UInt64
    adversary_header_delay::UInt64
    adversary_body_hold::UInt64
    congestion_period::UInt64
    congestion_delay::UInt64
    copy_modulus::UInt64
    controller::ControllerConfig
    function Scenario(label::String, horizon_slots::UInt64, window_width::UInt64,
            grace::UInt64, admission_width::UInt64, selection::SelectionPolicy,
            late::LatePolicy, draw_scale::UInt64, honest_attempts::UInt64,
            adversary_attempts::UInt64, honest_delay_max::UInt64,
            adversary_header_delay::UInt64, adversary_body_hold::UInt64,
            congestion_period::UInt64,
            congestion_delay::UInt64, copy_modulus::UInt64,
            controller::ControllerConfig)
        horizon_slots > 0 && window_width > 0 && draw_scale > 0 ||
            throw(ArgumentError("positive horizon/window/scale required"))
        ispow2(draw_scale) || throw(ArgumentError("draw_scale must be a power of two"))
        horizon_slots <= typemax(Int) || throw(ArgumentError("horizon exceeds host indexing"))
        Base.Checked.checked_mul(horizon_slots, honest_attempts) <= typemax(Int) ||
            throw(ArgumentError("honest trace exceeds host indexing"))
        Base.Checked.checked_mul(horizon_slots, adversary_attempts) <= typemax(Int) ||
            throw(ArgumentError("adversary trace exceeds host indexing"))
        2 * BigInt(horizon_slots) * (BigInt(honest_attempts) + adversary_attempts) <=
            typemax(UInt64) - 1 || throw(ArgumentError("identifier domain exhausted"))
        controller.range_max <= draw_scale || throw(ArgumentError("range exceeds draw scale"))
        new(label, horizon_slots, window_width, grace, admission_width, selection, late,
            draw_scale, honest_attempts, adversary_attempts, honest_delay_max,
            adversary_header_delay, adversary_body_hold, congestion_period,
            congestion_delay, copy_modulus, controller)
    end
end

struct Opportunity
    draw::UInt64
    delay_draw::UInt64
    copy_draw::UInt64
end

struct ExogenousTrace
    seed::UInt64
    honest::Vector{Opportunity}
    adversary::Vector{Opportunity}
end

struct Produced
    ticket_id::UInt64
    block_id::UInt64
    payment_id::UInt64
    original_slot::UInt64
    header_slot::UInt64
    body_slot::UInt64
    honest::Bool
    blue::Bool
end

struct EconomicEvent
    context_id::UInt64
    block_id::UInt64
    ticket_id::UInt64
    original_slot::UInt64
    incorporation_slot::UInt64
    window_id::UInt64
    honest::Bool
end

struct SimulationMetrics
    label::String
    horizon_slots::UInt64
    final_range::UInt64
    ranges_by_slot::Vector{UInt64}
    events::Vector{EconomicEvent}
    sealed_counted::Dict{UInt64,Vector{Tuple{UInt64,UInt64}}}
    payable_by_window::Dict{UInt64,Vector{Tuple{UInt64,UInt64}}}
    honest_produced::UInt64
    honest_excluded::UInt64
    reincluded::UInt64
    reinclusion_delay_sum::UInt64
    pending_slots::UInt64
    max_no_progress_pending::UInt64
    max_no_progress_empty::UInt64
    max_no_event_progress::UInt64
    no_event_streak_censored::Bool
    max_pending_headers::UInt64
    payments_originated::UInt64
    payments_never_accepted::UInt64
    clamp_count::UInt64
    missed_updates::UInt64
    reversal_after_acceptance::MetricPending
    observer_disagreement::MetricPending
    network_service_queue::MetricPending
end
