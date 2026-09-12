using InteractiveUtils
using JET
using Profile
using AdmisionRetargetMultivista

function one_replay(prepared::ArmView{DCM.FastView}, target::UInt64)
    fresh = deepcopy(prepared)
    return replay!(fresh, target)
end

function main(args::Vector{String})
    seed = parse_seed(args)
    fixture = branch_model(16)
    prepared = deliver_all!(FastView(fixture.model))
    replay!(prepared,fixture.target_a) === DCM.Applied || error("profile base")
    one_replay(prepared,fixture.target_b) === DCM.Applied || error("profile warmup")
    types = (typeof(prepared),UInt64)
    reports = JET.get_reports(JET.report_opt(replay!,types))
    warntype = sprint(io -> code_warntype(io,replay!,types))
    contains_any = occursin("::Any",warntype)
    allocated = @allocated one_replay(prepared,fixture.target_b)
    Profile.clear()
    @profile for _ in 1:400
        one_replay(prepared,fixture.target_b)
    end
    println("model=ARM-v0.1 seed=$seed rng=none workload=reorg branch_depth=16")
    println("jet_diagnostics=$(length(reports)) code_warntype_any=$contains_any")
    println("return_types=$(Base.return_types(replay!,types))")
    println("allocated_bytes_including_fresh_view=$allocated profile_entries=$(length(Profile.fetch()))")
    for diagnostic in reports
        show(stdout,diagnostic)
        println()
    end
    Profile.print(;format=:flat,sortedby=:count,mincount=20)
end

main(ARGS)
