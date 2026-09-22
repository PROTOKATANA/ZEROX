using SembradorV1
using Test

P(args...) = ParametrosMargen(Float64.(args)...)

@testset "validación de entradas" begin
    @test_throws ArgumentError P(0, 10, 2, 1, 1, 1, 10)
    @test_throws ArgumentError P(2, -1, 2, 1, 1, 1, 10)
    @test_throws ArgumentError P(2, 10, 2, 1, -1, 1, 10)
    @test_throws ArgumentError P(2, 10, 2, 1, 1, 0, 10)
    @test_throws ArgumentError P(2, 10, 2, 1, 1, 1, 0.5)
end

@testset "bordes y significado económico" begin
    sin_ventana = evaluar_margen(P(1, 100, 20, 5, 1, 10, 1_000))
    @test sin_ventana.adelanto_slots == 0
    @test sin_ventana.desafios_futuros == 0
    @test sin_ventana.probabilidad_exito_intento == 0
    @test sin_ventana.soluciones_esperadas_por_intento == 0
    @test isinf(sin_ventana.intentos_esperados_por_candidato)
    @test isinf(sin_ventana.intentos_esperados_por_bloque)
    @test isinf(sin_ventana.margen_coste_beneficio)
    @test !sin_ventana.rentable

    # A = L - 1 = 2 retos; H = 2 da q = 3/4, pero E[X] = w/H = 1.
    exacto = evaluar_margen(P(2, 3, 0, 0, 1, 1, 2))
    @test exacto.desafios_futuros == 2
    @test exacto.probabilidad_exito_intento ≈ 0.75
    @test exacto.soluciones_esperadas_por_intento ≈ 1
    @test exacto.intentos_esperados_por_candidato ≈ 4 / 3
    @test exacto.intentos_esperados_por_bloque ≈ 1
    @test exacto.margen_coste_beneficio ≈ 1
    @test !exacto.rentable

    barato = evaluar_margen(P(2, 3, 0, 0, 0.5, 1, 2))
    @test barato.rentable
    @test barato.margen_coste_beneficio < 1
end

@testset "sensibilidad exigida a rho y L" begin
    base = P(1.001, 3_600, 851, 20, 1, 1, 1_000_000)
    rho_mayor = P(3, 3_600, 851, 20, 1, 1, 1_000_000)
    L_mayor = P(1.001, 7_200, 851, 20, 1, 1, 1_000_000)

    r0 = evaluar_margen(base)
    rr = evaluar_margen(rho_mayor)
    rL = evaluar_margen(L_mayor)

    @test rr.adelanto_slots > r0.adelanto_slots
    @test rr.probabilidad_exito_intento > r0.probabilidad_exito_intento
    @test rr.soluciones_esperadas_por_intento > r0.soluciones_esperadas_por_intento
    @test rr.margen_coste_beneficio < r0.margen_coste_beneficio
    @test rL.adelanto_slots > r0.adelanto_slots
    @test rL.probabilidad_exito_intento > r0.probabilidad_exito_intento
    @test rL.soluciones_esperadas_por_intento > r0.soluciones_esperadas_por_intento
    @test rL.margen_coste_beneficio < r0.margen_coste_beneficio
end

@testset "monotonías del modelo" begin
    pequeño = evaluar_margen(P(2, 1_000, 100, 10, 2, 10, 1_000))
    grande = evaluar_margen(P(2, 1_000, 100, 10, 2, 10, 10_000))
    @test grande.probabilidad_exito_intento < pequeño.probabilidad_exito_intento
    @test grande.soluciones_esperadas_por_intento < pequeño.soluciones_esperadas_por_intento
    @test grande.margen_coste_beneficio > pequeño.margen_coste_beneficio

    coste_doble = evaluar_margen(P(2, 1_000, 100, 10, 4, 10, 1_000))
    recompensa_doble = evaluar_margen(P(2, 1_000, 100, 10, 2, 20, 1_000))
    @test coste_doble.margen_coste_beneficio ≈ 2pequeño.margen_coste_beneficio
    @test recompensa_doble.margen_coste_beneficio ≈ pequeño.margen_coste_beneficio / 2
end

@testset "oráculo BigFloat" begin
    casos = ParametrosMargen{Float64}[
        P(0.9, 100, 20, 5, 1, 2, 1_000),
        P(1, 100, 20, 5, 1, 2, 1_000),
        P(1.001, 3_600, 851, 20, 1e-6, 2e-3, 1e12),
        P(1.5, 7_200, 851, 20, 2.5, 10, 1e8),
        P(3, 3_600, 300, 45, 0, 10, 1),
        P(10, 19_080, 4_200, 45, 1, 1, 1e15),
    ]
    ok, error = validar_referencia(casos)
    @test ok
    @test error <= 64eps(Float64)

    salida = Vector{ResultadoMargen{Float64}}(undef, length(casos))
    @test barrer!(salida, casos) === salida
    @test salida == evaluar_margen.(casos)
    @test_throws DimensionMismatch barrer!(salida[1:end-1], casos)
end

@testset "scripts parseables" begin
    raiz = normpath(joinpath(@__DIR__, ".."))
    @test Meta.parseall(read(joinpath(raiz, "run.jl"), String)) isa Expr
    @test Meta.parseall(read(joinpath(raiz, "bench", "benchmarks.jl"), String)) isa Expr
end
