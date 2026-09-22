using IntentoV1
using Test

const RANGO_PRUEBA = UInt64(2^40)   # rango de solución de juguete, no un parámetro de consenso

function E(; r = 1.3, t_reto = 1.0e-6, o = 0.5, tau = 1.0, N_h = 1.0e9, alpha = 0.1,
    pi_DAG = 1.0, t_ganador = 0.8, rango = RANGO_PRUEBA)
    return Escenario(;
        r = Float64(r),
        t_reto_s = Float64(t_reto),
        o = Float64(o),
        rango_solucion = Float64(rango),
        tau_s = Float64(tau),
        N_h = Float64(N_h),
        alpha = Float64(alpha),
        pi_DAG = Float64(pi_DAG),
        t_ganador_s = Float64(t_ganador),
        bytes_por_pieza = 1_048_672,
    )
end

@testset "validación de entradas" begin
    @test_throws ArgumentError E(r = 0.0)
    @test_throws ArgumentError E(t_reto = -1.0)
    @test_throws ArgumentError E(o = 0.0)
    @test_throws ArgumentError E(o = 1.5)
    @test_throws ArgumentError E(tau = 0.0)
    @test_throws ArgumentError E(N_h = -1.0)
    @test_throws ArgumentError E(alpha = 0.0)
    @test_throws ArgumentError E(alpha = 1.0)
    @test_throws ArgumentError E(pi_DAG = 0.0)
    @test_throws ArgumentError E(pi_DAG = 1.5)
end

@testset "d(R_s) coincide con el conteo y con el oráculo exacto" begin
    for rango in (UInt64(0), UInt64(1), UInt64(2), UInt64(9), UInt64(1000), UInt64(4096))
        @test contar_aceptados(rango) == 2 * div(rango, 2) + 1
        exacto = Float64(prob_bucket_exacta(rango))
        @test prob_bucket(Float64(rango)) == exacto
    end
    # Bordes del tipo: R_s = 0 rechaza casi todo, R_s = 2^64-1 acepta todo.
    @test prob_bucket(0.0) == 1.0 / 2.0^64
    @test prob_bucket(1.0) == 1.0 / 2.0^64
    @test prob_bucket(2.0) == 3.0 / 2.0^64
end

@testset "p = o·d y el caso o = 1/2 medido" begin
    e = E()
    @test p_intento(0.5, e.rango_solucion) ≈ 0.5 * prob_bucket(e.rango_solucion)
    # Con o medido = 0.5, la probabilidad es exactamente la mitad de la fracción del rango.
    o_medido = 0.5
    @test p_intento(o_medido, e.rango_solucion) == o_medido * prob_bucket(e.rango_solucion)
end

@testset "N_eq, máquinas y fracción adversaria" begin
    e = E(r = 2.0, tau = 1.0, N_h = 1000.0, alpha = 0.5)
    f = evaluar(e, 10.0)
    @test f.n_eq == 20.0
    @test f.maquinas == (0.5 / 0.5) * 1000.0 / 20.0
    @test f.bytes_eq == 20.0 * 1_048_672
    # `n_eq = 20` frente a `N_h = 1000`: una máquina alcanza 20/1020 del peso.
    @test f.fraccion_una_maquina ≈ 20 / 1020
    # Y la fracción crece con w.
    f2 = evaluar(e, 21.0)
    @test f2.fraccion_una_maquina > f.fraccion_una_maquina
    # `maquinas(alpha)` es exactamente la inversa: con ese número entero de máquinas la cuota
    # supera alpha.
    n = ceil(Int, f.maquinas)
    cuota = (n * f.n_eq) / (n * f.n_eq + 1000.0)
    @test cuota >= 0.5
end

@testset "latencias y umbrales" begin
    e = E(r = 1.0, t_reto = 0.0, tau = 1.0, N_h = 1000.0)
    f = evaluar(e, 1000.0)
    @test f.w_equilibrio == 1000.0
    @test w_equilibrio(1000.0, 1.0, 1.0) == 1000.0
    @test f.latencia_holgada == (1000.0 >= f.w_min_latencia)

    # Si r*w*p = 1 exactamente, la latencia está justo en el límite.
    p = p_intento(e.o, e.rango_solucion)
    w_limite = 1.0 / (e.r * e.tau_s * p)
    @test evaluar(e, w_limite).latencia_holgada
    @test !evaluar(e, w_limite * 0.5).latencia_holgada
end

@testset "equivalencia kernel vs oráculo de alta precisión" begin
    casos = Tuple{Escenario{Float64},Float64}[]
    for r in (0.5, 1.3, 8.2), o in (0.25, 0.5, 1.0), rango in (UInt64(1), UInt64(2^40)),
        w in (1.0, 10.0, 1000.0, 1.0e5)

        push!(casos, (E(; r = r, o = o, rango = rango), w))
    end
    ok, error, n = validar_referencia(casos)
    @test n == length(casos)
    @test ok
    @test error <= 256eps(Float64)
end

@testset "invariantes" begin
    for r in (0.5, 1.3, 8.2, 100.0)
        ok, motivo = comprobar_invariantes(E(; r = r))
        @test ok
        ok || @info motivo
    end
    ok, _ = comprobar_invariantes(E(; t_reto = 0.0))
    @test ok
end

@testset "rejilla de w" begin
    ws = rejilla_w(100.0, 1.0e5, 64)
    @test length(ws) == 64
    @test ws[1] == 100.0
    @test ws[end] ≈ 1.0e5
    @test issorted(ws)
    @test_throws ArgumentError rejilla_w(100.0, 1.0e5, 1)
    @test_throws ArgumentError rejilla_w(0.0, 1.0e5, 4)
    @test_throws ArgumentError rejilla_w(1.0e5, 100.0, 4)
end

@testset "barrer! preasignado y determinista" begin
    escs = [E(; r = r) for r in (1.0, 2.0, 4.0)]
    ws = [1.0e3, 1.0e4, 1.0e5]
    salida = Vector{Resultado{Float64}}(undef, 3)
    barrer!(salida, escs, ws)
    for i in 1:3
        @test salida[i] == evaluar(escs[i], ws[i])
    end
    @test_throws ArgumentError barrer!(salida, escs, [1.0])
end

@testset "el barrido es determinista byte a byte" begin
    escs = [E(; r = 1.3) for _ in 1:64]
    ws = rejilla_w(1.0e2, 1.0e5, 64)
    a = Vector{Resultado{Float64}}(undef, 64)
    b = Vector{Resultado{Float64}}(undef, 64)
    barrer!(a, escs, ws)
    barrer!(b, escs, ws)
    @test all(a .== b)
end
