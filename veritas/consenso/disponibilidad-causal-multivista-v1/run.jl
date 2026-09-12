using DisponibilidadCausalMultivista

function main()
    fixture = joinpath(@__DIR__, "fixtures", "CASOS.txt")
    result = execute_fixture(fixture)
    println("model=DCM-v0.1 revision=2 status=structural_not_adopted")
    println("fixture_cases=$(result.cases) fixture_assertions=$(result.assertions)")
    println("retarget=Pending branch_weight_without_body=Pending network_resources=Pending")
end

main()
