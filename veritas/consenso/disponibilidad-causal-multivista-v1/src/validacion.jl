parse_policy(s) = s == "P0" ? P0 : s == "P1" ? P1 : error("policy $s")
parse_color(s) = s == "B" ? Blue : s == "R" ? RedK : s == "U" ? RedU : error("color $s")
parse_outcome(s) = s == "Applied" ? Applied : s == "Pending" ? Pending :
                   s == "Invalid" ? Invalid : error("outcome $s")
parse_body_token(s) = s == "COMPLETE" ? :complete : s == "REJECT" ? :reject :
                      s == "INVALID" ? :invalid : error("body token $s")
parse_context_token(s) = s == "VALID" ? true : s == "INVALID" ? false :
                         error("context token $s")
function parse_u(s)
    !isempty(s) && all(c -> '0' <= c <= '9', s) || error("ID must be ASCII decimal: $s")
    return parse(UInt64, s)
end
parse_opt_u(s) = s == "-" ? UInt64(0) : parse_u(s)
parse_ulist(s) = s == "-" ? UInt64[] : parse_u.(split(s, ','))

function parse_events(s)
    out = Tuple{UInt64,UInt64}[]
    s == "-" && return out
    seen = Set{Tuple{UInt64,UInt64}}()
    for item in split(s, ',')
        fields = split(item, ':')
        length(fields) == 2 && all(!isempty, fields) || error("EventId arity: $item")
        event = (parse_u(fields[1]), parse_u(fields[2]))
        event in seen && error("duplicate EventId: $item")
        push!(seen, event); push!(out, event)
    end
    return out
end

function parse_snapshots(s)
    out = Vector{Tuple{UInt64,Vector{Tuple{UInt64,UInt64}}}}()
    s == "-" && return out
    seen = Set{UInt64}()
    for item in split(s, '/')
        pair = split(item, '=')
        length(pair) == 2 && all(!isempty, pair) || error("snapshot arity: $item")
        window = parse_u(pair[1])
        window in seen && error("duplicate snapshot window: $window")
        push!(seen, window)
        push!(out, (window, parse_events(pair[2])))
    end
    sort!(out; by=first)
    return out
end

function parse_inert(s)
    out = Tuple{UInt64,UInt64,UInt64}[]
    s == "-" && return out
    seen = Set{Tuple{UInt64,UInt64,UInt64}}()
    for item in split(s, ',')
        fields = split(item, ':')
        length(fields) == 3 && all(!isempty, fields) || error("InertKey arity: $item")
        key = (parse_u(fields[1]), parse_u(fields[2]), parse_u(fields[3]))
        key in seen && error("duplicate InertKey: $item")
        push!(seen, key); push!(out, key)
    end
    return sort!(out)
end

function truth_keys_known(blocks, histories, context_truth)
    block_ids = Set(b.id for b in blocks); history_ids = Set(h.id for h in histories)
    return all(key -> key[1] in history_ids && key[2] in block_ids, keys(context_truth))
end

function assert_expected(v::AbstractView, f, line)
    p = projection(v)
    pub = p.public
    consumed = parse_ulist(f[8])
    length(unique(consumed)) == length(consumed) || error("duplicate consumed ID line $line")
    pending = parse_opt_u(f[9])
    pending != 0 || f[9] == "-" || error("pending absence must be '-' line $line")
    expected = (current=parse_opt_u(f[3]), journal=parse_events(f[4]),
        counted=parse_snapshots(f[5]), payable=parse_snapshots(f[6]),
        inert=parse_inert(f[7]), consumed=sort!(consumed), pending=pending)
    actual = (current=pub.current, journal=pub.journal, counted=pub.counted,
        payable=pub.payable, inert=pub.inert, consumed=pub.consumed, pending=p.pending)
    actual == expected || error("fixture line $line expected $expected got $actual")
end

function state_invariants(v::AbstractView, cat::Catalog)
    v.public.counted == v.public.payable || return false
    for event in v.public.journal
        h = cat.histories[event.history]
        event in get(v.public.counted, h.window, EventId[]) || return false
        if v isa RefView
            event.block in v.good || return false
            (event.history, event.block) in v.context_good || return false
        else
            fast_has(v, v.good, event.block) || return false
            v.block_index[event.block] in get(v.context_good, event.history, BitSet()) || return false
        end
    end
    total = sum(length, values(v.public.counted); init=0)
    total == length(v.public.journal) || return false
    return length(v.public.consumed) == length(v.public.journal)
end

execute_fixture(path::AbstractString) = open(execute_fixture, path)

function execute_fixture(input::IO)
    cases = 0; assertions = 0
    policy = P0
    blocks = BlockSpec[]; histories = HistorySpec[]
    body_truth = Dict{UInt64,Bool}(); context_truth = Dict{Tuple{UInt64,UInt64},Bool}()
    cat = nothing
    in_case = false; frozen = false
    refs = Dict{String,RefView}(); fasts = Dict{String,FastView}()
    for (line_number, raw) in enumerate(eachline(input))
        line = strip(first(split(raw, '#'; limit=2)))
        isempty(line) && continue
        f = split(line); command = f[1]
        command != "CASE" && !in_case && error("command outside CASE line $line_number")
        if command == "CASE"
            in_case && error("nested CASE line $line_number")
            length(f) == 3 || error("CASE arity line $line_number")
            policy = parse_policy(f[3]); empty!(blocks); empty!(histories)
            empty!(refs); empty!(fasts); empty!(body_truth); empty!(context_truth)
            cat = nothing; in_case = true; frozen = false
        elseif command == "BLOCK"
            frozen && error("BLOCK after catalog freeze line $line_number")
            length(f) == 7 || error("BLOCK arity line $line_number")
            push!(blocks, BlockSpec(parse_u(f[2]), parse_u(f[3]), parse_u(f[4]),
                parse_u(f[5]), parse_color(f[6]), parse_ulist(f[7])))
        elseif command == "HISTORY"
            frozen && error("HISTORY after catalog freeze line $line_number")
            length(f) == 5 || error("HISTORY arity line $line_number")
            push!(histories, HistorySpec(parse_u(f[2]), parse_opt_u(f[3]),
                                         parse_u(f[4]), parse_ulist(f[5])))
        elseif command == "BODY_TRUTH"
            frozen && error("BODY_TRUTH after catalog freeze line $line_number")
            length(f) == 3 || error("BODY_TRUTH arity line $line_number")
            id = parse_u(f[2]); haskey(body_truth, id) && error("duplicate BODY_TRUTH line $line_number")
            f[3] in ("COMPLETE", "INVALID") || error("BODY_TRUTH token line $line_number")
            body_truth[id] = f[3] == "COMPLETE"
        elseif command == "CONTEXT_TRUTH"
            frozen && error("CONTEXT_TRUTH after catalog freeze line $line_number")
            length(f) == 4 || error("CONTEXT_TRUTH arity line $line_number")
            key = (parse_u(f[2]), parse_u(f[3]))
            haskey(context_truth, key) && error("duplicate CONTEXT_TRUTH line $line_number")
            f[4] in ("VALID", "INVALID") || error("CONTEXT_TRUTH token line $line_number")
            context_truth[key] = f[4] == "VALID"
        elseif command == "VIEW"
            length(f) == 2 || error("VIEW arity line $line_number")
            isempty(histories) && error("fixture must declare a history line $line_number")
            block_ids = Set(b.id for b in blocks)
            Set(keys(body_truth)) == block_ids || error("BODY_TRUTH must cover every block line $line_number")
            truth_keys_known(blocks, histories, context_truth) ||
                error("CONTEXT_TRUTH references unknown id line $line_number")
            invalid_bodies = Set(id for (id, valid) in body_truth if !valid)
            cat === nothing && (cat = Catalog(blocks, histories; invalid_bodies, context_truth))
            name = String(f[2])
            haskey(refs, name) && error("duplicate VIEW line $line_number")
            refs[name] = RefView(name, cat; policy); fasts[name] = FastView(name, cat; policy)
            frozen = true
        elseif command == "HEADER"
            length(f) == 3 || error("HEADER arity line $line_number")
            id = parse_u(f[3])
            deliver_header!(refs[f[2]], id) && deliver_header!(fasts[f[2]], id) ||
                error("unknown header block line $line_number")
        elseif command == "BODY"
            length(f) == 4 || error("BODY arity line $line_number")
            id = parse_u(f[3])
            token = parse_body_token(f[4])
            token !== :reject && get(body_truth, id, nothing) !== (token === :complete) &&
                error("BODY contradicts truth line $line_number")
            rr = token === :invalid ? deliver_invalid_body!(refs[f[2]], id) :
                 deliver_body!(refs[f[2]], id, token === :complete)
            rf = token === :invalid ? deliver_invalid_body!(fasts[f[2]], id) :
                 deliver_body!(fasts[f[2]], id, token === :complete)
            rr && rf || error("contradictory delivery line $line_number")
        elseif command == "CONTEXT"
            length(f) == 5 || error("CONTEXT arity line $line_number")
            hid = parse_u(f[3]); id = parse_u(f[4]); valid = parse_context_token(f[5])
            haskey(cat.histories, hid) && haskey(cat.blocks, id) ||
                error("unknown context evidence target line $line_number")
            get(context_truth, (hid, id), nothing) === valid ||
                error("CONTEXT missing/opposes truth line $line_number")
            rr = deliver_context!(refs[f[2]], hid, id, valid)
            rf = deliver_context!(fasts[f[2]], hid, id, valid)
            rr && rf || error("contradictory context line $line_number")
        elseif command == "APPLY" || command == "REPLAY"
            length(f) == 4 || error("APPLY/REPLAY arity line $line_number")
            id = parse_u(f[3]); expected = parse_outcome(f[4])
            rr = command == "APPLY" ? apply_reference!(refs[f[2]], cat, id, policy) :
                                      replay_reference!(refs[f[2]], cat, id, policy)
            rf = command == "APPLY" ? apply_fast!(fasts[f[2]], cat, id, policy) :
                                      replay_fast!(fasts[f[2]], cat, id, policy)
            rr == expected && rf == expected || error("outcome line $line_number ref=$rr fast=$rf")
            state_invariants(refs[f[2]], cat) && state_invariants(fasts[f[2]], cat) ||
                error("state invariant line $line_number")
            assertions += 2
        elseif command == "UNDO"
            length(f) == 4 || error("UNDO arity line $line_number")
            id = parse_u(f[3]); expected = parse_outcome(f[4])
            rr = undo_reference!(refs[f[2]], id); rf = undo_fast!(fasts[f[2]], id)
            rr == expected && rf == expected || error("undo line $line_number")
            state_invariants(refs[f[2]], cat) && state_invariants(fasts[f[2]], cat) ||
                error("state invariant line $line_number")
            assertions += 2
        elseif command == "EXPECT"
            length(f) == 9 || error("EXPECT arity line $line_number")
            projection(refs[f[2]]) == projection(fasts[f[2]]) || error("projection divergence line $line_number")
            assert_expected(refs[f[2]], f, line_number); assertions += 2
        elseif command == "EQUAL"
            length(f) == 3 || error("EQUAL arity line $line_number")
            projection(refs[f[2]]) == projection(refs[f[3]]) || error("reference views differ line $line_number")
            projection(fasts[f[2]]) == projection(fasts[f[3]]) || error("fast views differ line $line_number")
            assertions += 2
        elseif command == "END"
            length(f) == 1 || error("END arity line $line_number")
            cat === nothing && error("empty CASE line $line_number")
            cases += 1
            in_case = false
        else
            error("unknown $command line $line_number")
        end
    end
    in_case && error("CASE without END")
    cases > 0 || error("fixture without CASE")
    return (cases=cases, assertions=assertions)
end
