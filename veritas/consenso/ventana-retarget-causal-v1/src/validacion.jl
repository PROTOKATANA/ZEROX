function state_projection(state::State)
    events = [(e.event_id, e.ticket_id, e.block_id, e.original_slot,
               e.incorporation_slot, e.context_id, e.accounting_window,
               e.subsidy, e.fees) for e in state.journal]
    return (state.context_id, state.context_slot, events,
            sort!(collect(state.used_tickets); by=first), sort!(collect(state.seen_blocks)),
            sort!(collect(state.ticket_slots); by=first),
            sort!([(k, v.event_ids, v.context_id, v.context_slot)
                   for (k, v) in state.sealed_windows]; by=first),
            copy(state.causal_exclusions))
end

function validate_equivalence(state::State, batch::Batch, scenario::Scenario)
    reference = apply_reference(deepcopy(state), batch, scenario)
    fast = apply_fast(deepcopy(state), batch, scenario)
    return reference.code == fast.code && reference.reason == fast.reason &&
           reference.winners == fast.winners &&
           state_projection(reference.state) == state_projection(fast.state)
end

parse_u64(token::AbstractString) = parse(UInt64, token)

function parse_event_ids(token::AbstractString)
    token == "-" && return EventId[]
    return EventId[EventId(parse_u64(split(item, ':')[1]),
                           parse_u64(split(item, ':')[2])) for item in split(token, ',')]
end

function all_event_ids(state::State)
    return EventId[e.event_id for e in state.journal]
end

function execute_fixtures(path::AbstractString; engine=apply_fast)
    assertions = 0
    cases = 0
    state = State()
    scenario = nothing
    blocks = Candidate[]
    batch_header = nothing
    last_result = nothing
    last_undo = nothing

    for (line_number, raw) in enumerate(eachline(path))
        line = strip(first(split(raw, '#'; limit=2)))
        isempty(line) && continue
        fields = split(line)
        command = fields[1]
        fail(message) = error("fixture line $line_number: $message")

        if command == "CASE"
            length(fields) == 8 || fail("CASE arity")
            selection = fields[3] == "P0" ? P0 : fields[3] == "P1" ? P1 : fail("policy")
            width = parse_u64(fields[6])
            grace = parse_u64(fields[7])
            origin = parse_u64(fields[8])
            spec = WindowSpec(origin, width, grace)
            if fields[4] == "L0"
                fields[5] != "-" || fail("L0 requires W_adm")
                scenario = Scenario(selection, L0Rule(parse_u64(fields[5])), spec)
            elseif fields[4] == "LG"
                fields[5] == "-" || fail("LG does not use W_adm")
                scenario = Scenario(selection, LGRule(), spec)
            else
                fail("late policy")
            end
            state = State()
            empty!(blocks)
            batch_header = nothing
            last_result = nothing
            last_undo = nothing
            cases += 1
        elseif command == "BATCH"
            length(fields) == 4 || fail("BATCH arity")
            empty!(blocks)
            batch_header = (parse_u64(fields[2]), parse_u64(fields[3]), parse_u64(fields[4]))
        elseif command == "BLOCK"
            length(fields) == 9 || fail("BLOCK arity")
            color = fields[6] == "B" ? Blue : fields[6] == "K" ? RedK :
                    fields[6] == "U" ? RedU3 : fail("color")
            status = fields[7] == "C" ? Complete : fields[7] == "P" ? PendingData :
                     fields[7] == "I" ? Bad : fail("status")
            push!(blocks, Candidate(parse_u64(fields[2]), parse_u64(fields[3]),
                                    parse_u64(fields[4]), parse_u64(fields[5]), color,
                                    status, parse_u64(fields[8]), parse_u64(fields[9])))
        elseif command == "APPLY"
            scenario === nothing && fail("APPLY outside CASE")
            batch_header === nothing && fail("APPLY without BATCH")
            batch = Batch(batch_header[1], batch_header[2], batch_header[3], copy(blocks))
            last_result = engine(state, batch, scenario)
            last_undo = last_result.undo_state
            state = last_result.state
        elseif command == "EXPECT"
            length(fields) == 9 || fail("EXPECT arity")
            last_result === nothing && fail("EXPECT without APPLY")
            expected_code = fields[2] == "Applied" ? Applied : fields[2] == "Pending" ? Pending :
                            fields[2] == "Invalid" ? Invalid : fail("apply code")
            expected_winners = fields[3] == "-" ? UInt64[] : parse_u64.(split(fields[3], ','))
            expected_events = parse_event_ids(fields[4])
            window = parse_u64(fields[5])
            last_result.code == expected_code || fail("apply code mismatch")
            last_result.winners == expected_winners || fail("winner mismatch")
            all_event_ids(state) == expected_events || fail("journal mismatch")
            counted_ids(state, window) == parse_event_ids(fields[6]) || fail("count mismatch")
            payable_ids(state, window) == parse_event_ids(fields[7]) || fail("pay mismatch")
            expected_exclusions = fields[8] == "-" ? UInt64[] : parse_u64.(split(fields[8], ','))
            state.causal_exclusions == expected_exclusions || fail("exclusion mismatch")
            equality = counted_ids(state, window) == payable_ids(state, window)
            expected_equality = fields[9] == "Equal" ? true :
                                fields[9] == "Diverges" ? false : fail("equality marker")
            equality == expected_equality || fail("count/pay equality mismatch")
            assertions += 5
        elseif command == "QUERY"
            length(fields) == 6 || fail("QUERY arity")
            scenario === nothing && fail("QUERY outside CASE")
            id = parse_u64(fields[2])
            query_slot = parse_u64(fields[3])
            unresolved = fields[4] == "true" ? true : fields[4] == "false" ? false : fail("bool")
            expected_code = fields[5] == "Bootstrap" ? Bootstrap :
                            fields[5] == "Pending" ? ControllerPending :
                            fields[5] == "Ready" ? Ready : fail("controller code")
            pending = unresolved && batch_header !== nothing ?
                      Batch[Batch(batch_header[1], batch_header[2], batch_header[3], copy(blocks))] :
                      Batch[]
            result = close_window!(state, scenario.controller, id, query_slot;
                                   pending_batches=pending)
            result.code == expected_code || fail("controller code mismatch")
            result.event_ids == parse_event_ids(fields[6]) || fail("controller IDs mismatch")
            assertions += 2
        elseif command == "UNDO"
            last_undo === nothing && fail("UNDO unavailable")
            undo!(state, last_undo)
            assertions += 1
        elseif command == "STATE"
            length(fields) == 8 || fail("STATE arity")
            state.context_id == parse_u64(fields[2]) || fail("state context mismatch")
            ids = all_event_ids(state)
            ids == parse_event_ids(fields[3]) || fail("state journal mismatch")
            window = parse_u64(fields[4])
            counted_ids(state, window) == parse_event_ids(fields[5]) || fail("state count mismatch")
            payable_ids(state, window) == parse_event_ids(fields[6]) || fail("state pay mismatch")
            expected_exclusions = fields[7] == "-" ? UInt64[] : parse_u64.(split(fields[7], ','))
            state.causal_exclusions == expected_exclusions || fail("state exclusions mismatch")
            expected_seals = fields[8] == "-" ? UInt64[] : parse_u64.(split(fields[8], ','))
            sort!(collect(keys(state.sealed_windows))) == expected_seals ||
                fail("state seals mismatch")
            assertions += 4
        elseif command == "END"
            assertions += 1
        else
            fail("unknown command $command")
        end
    end
    return (cases=cases, assertions=assertions)
end
