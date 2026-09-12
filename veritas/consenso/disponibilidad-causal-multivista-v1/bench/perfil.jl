using InteractiveUtils
using JET
using Profile
using DisponibilidadCausalMultivista

const U = UInt64

blocks = [BlockSpec(U(1), U(1), U(7), U(1), Blue, U[])]
histories = [HistorySpec(U(100), U(0), U(7), U[1])]
cat = Catalog(blocks, histories; context_truth=Dict((U(100), U(1)) => true))
prepared = FastView("profile", cat)
deliver_header!(prepared, U(1))
deliver_body!(prepared, U(1), true)
deliver_context!(prepared, U(100), U(1), true)

types = (FastView, Catalog, UInt64, Policy)
warm = deepcopy(prepared)
apply_fast!(warm, cat, U(100), P0) === Applied || error("warmup failed")

jet_result = JET.report_opt(apply_fast!, types)
diagnostics = JET.get_reports(jet_result)
warntype = sprint(io -> code_warntype(io, apply_fast!, types))
contains_any = occursin("::Any", warntype)
contains_any && error("code_warntype contiene Any")

function one_apply(prepared_view::FastView, catalog::Catalog)
    candidate_view = deepcopy(prepared_view)
    return apply_fast!(candidate_view, catalog, U(100), P0)
end

one_apply(prepared, cat) === Applied || error("profile workload failed")
bytes = @allocated one_apply(prepared, cat)
Profile.clear()
@profile for _ in 1:2_000
    one_apply(prepared, cat)
end
entries = length(Profile.fetch())

println("workload=one_history_one_block_snapshot_fixture")
println("jet_diagnostics=$(length(diagnostics))")
println("code_warntype_any=$contains_any")
println("return_type=$(only(Base.return_types(apply_fast!, types)))")
println("allocated_bytes_including_fresh_view=$bytes")
println("profile_entries=$entries")
