using InteractiveUtils
using JET
using Profile
using VentanaRetargetCausal

function carga_representativa(n::Int)
    bloques = Candidate[]
    sizehint!(bloques, n)
    for i in 1:n
        ticket = UInt64(1 + (i % 70))
        slot = UInt64(ticket % 9)
        color = i % 11 == 0 ? RedU3 : i % 2 == 0 ? Blue : RedK
        push!(bloques, Candidate(UInt64(i), ticket, slot, UInt64(i), color,
                                 Complete, UInt64(i % 5), UInt64(i % 3)))
    end
    return Batch(1, 0, 10, bloques)
end

lote = carga_representativa(180)
escenario = Scenario(P0, LGRule(), WindowSpec(0, 16, 3))
tipos = (State, typeof(lote), typeof(escenario))

apply_fast(State(), lote, escenario) # calentamiento
informe_jet = JET.report_opt(apply_fast, tipos)
diagnosticos = JET.get_reports(informe_jet)
isempty(diagnosticos) || error("JET detectó diagnósticos de optimización")

salida_tipos = sprint(io -> code_warntype(io, apply_fast, tipos))
contiene_any = occursin("::Any", salida_tipos)
contiene_any && error("code_warntype contiene Any")

bytes = @allocated apply_fast(State(), lote, escenario)
Profile.clear()
@profile for _ in 1:20_000
    apply_fast(State(), lote, escenario)
end
entradas = length(Profile.fetch())

println("workload=180_blocks_70_ticket_cycle_fixture")
println("jet_diagnostics=$(length(diagnosticos))")
println("code_warntype_any=$contiene_any")
println("return_type=$(only(Base.return_types(apply_fast, tipos)))")
println("allocated_bytes=$bytes")
println("profile_entries=$entradas")
