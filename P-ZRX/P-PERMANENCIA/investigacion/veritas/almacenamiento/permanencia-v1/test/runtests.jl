using Test
using PermanenciaV1
using PermanenciaV1: suma_poisson_exacta, poisson_cdf_intervalo, umbral_rechazo,
    potencia_garantizada, falso_fallo_maximo, periodos_deteccion, binomial_cdf_exacta,
    validar_intervalo_vs_exacto, validar_poisson_vs_binomial, validar_kernel_vs_referencia,
    comprobar_bordes, e3_cpu_regeneracion, e3_almacenamiento_forzado, e2_factible_sin_ventana,
    _potencia_y_umbral

const HW = lectura_hardware(joinpath(@__DIR__, "..", "mediciones", "hardware.tsv"))

@testset "oráculo exacto Σ λ^j/j!" begin
    @test suma_poisson_exacta(1, 1, 0) == 1
    @test suma_poisson_exacta(1, 1, 1) == 2
    @test suma_poisson_exacta(1, 1, 2) == Rational{BigInt}(5, 2)
    @test suma_poisson_exacta(1, 1, 3) == Rational{BigInt}(8, 3)
    @test suma_poisson_exacta(0, 1, 5) == 1
    @test suma_poisson_exacta(3, 2, 0) == 1
end

@testset "binomial exacta" begin
    @test binomial_cdf_exacta(2, 1, 2, 1) == Rational{BigInt}(3, 4)
    @test binomial_cdf_exacta(2, 1, 2, 0) == Rational{BigInt}(1, 4)
    @test binomial_cdf_exacta(10, 1, 1, 5) == 0      # p = 1: X = n siempre
    @test binomial_cdf_exacta(10, 1, 1, 10) == 1
    @test binomial_cdf_exacta(10, 1, 1, -1) == 0
    @test binomial_cdf_exacta(4, 0, 1, 0) == 1
end

@testset "el intervalo contiene al oráculo exacto" begin
    v = validar_intervalo_vs_exacto()
    @test v.contiene
    @test v.max_rel < BigFloat("1e-60")
end

@testset "Poisson frente a la binomial exacta en lotes pequeños" begin
    v = validar_poisson_vs_binomial()
    # la Poisson es aproximación: se exige que quede dentro de la cota de Le Cam 2 n p²
    @test v.dentro
    @test v.max_dif < BigFloat("1e-2")
end

@testset "bordes" begin
    @test isempty(comprobar_bordes())
    @test poisson_cdf_intervalo(0, 1, 0)[1] == 1
    @test poisson_cdf_intervalo(1, 1, -1)[1] == 0
    @test umbral_rechazo(0, 1, 1e-3)[1] == -1
    @test isinf(e3_cpu_regeneracion(HW, 1000.0, 0.0, 100.0))
end

@testset "umbral y potencia son coherentes" begin
    λn, λd = BigInt(1000), BigInt(10)   # λ = 100
    K, ok = umbral_rechazo(λn, λd, 1e-3)
    @test ok
    @test K >= 0
    @test cdf_superior(λn, λd, K) <= BigFloat(1e-3)
    @test potencia_garantizada(λn, λd, K) <= 1 - BigFloat(1e-3) + BigFloat("1e-20")
    # una alternativa peor nunca puede tener más potencia
    @test potencia_garantizada(λn ÷ 2, λd, K) >= potencia_garantizada(λn, λd, K)
    ff1 = falso_fallo_maximo(λn, λd, K)
    ff2 = falso_fallo_maximo(λn * 9, λd * 10, K)   # a = 0,9
    @test ff2 >= ff1
end

@testset "periodos_deteccion coincide con la búsqueda directa" begin
    λn, λd = BigInt(1000), BigInt(10)     # λ = 100
    sn, sd = BigInt(1), BigInt(2)         # s = 0,5
    T, K, pot = periodos_deteccion(λn, λd, sn, sd, 1e-3, 1e-2; Tmax = 500)
    # búsqueda directa e independiente
    Tdir = 0
    for t in 1:500
        Kt, pt, ok = _potencia_y_umbral(λn, λd, t, sn, sd, 1e-3; prec = 256)
        if ok && pt >= 1 - BigFloat(1e-2)
            Tdir = t
            break
        end
    end
    @test Tdir > 0
    @test T == Tdir
    @test pot >= 1 - BigFloat(1e-2)
end

@testset "monotonía de la potencia en T" begin
    @test validar_monotonia_potencia(50.0, 0.5, 1e-3; Tmax = 32)
end

@testset "kernel rápido frente a la referencia" begin
    v = validar_kernel_vs_referencia()
    @test v.max_dK <= 2
    @test v.max_dP < 0.02
end

@testset "modelo: costes e invariantes" begin
    N1 = piezas_por_TiB(HW)
    @test isapprox(N1, 1_048_480.0; rtol = 1e-6)
    # el almacenamiento forzado crece con N y baja con w
    @test e3_almacenamiento_forzado(HW, N1, 7200.0) > 0.8
    @test e3_almacenamiento_forzado(HW, N1, 7200.0) < e3_almacenamiento_forzado(HW, 10N1, 7200.0)
    @test e3_almacenamiento_forzado(HW, N1, 100.0) > e3_almacenamiento_forzado(HW, N1, 7200.0)
    # con w = L la ventana cubre ~0,17 TiB y el lote entero necesita w≈4,2e4 slots
    @test isapprox(e3_TiB_por_cpu(HW, 7200.0), 0.1718; atol = 0.01)
    @test e3_w_cruce_lote(HW, N1) < 50_000
    # E2: con c pequeño y D_a largo, un tramposo sin ventana cabe de sobra
    @test e2_factible_sin_ventana(HW, 100.0, 60.0, 0.0)
    @test !e2_factible_sin_ventana(HW, 100_000.0, 1.0, 0.0)
    # E5: más espacio ⇒ detección más rápida
    @test e5_deteccion_slots(0.01, 1.0, 1e-3) < e5_deteccion_slots(0.001, 1.0, 1e-3)
end

@testset "agregación: muestreo, grinding y ventana" begin
    λ = 1000.0
    # el muestreo exige casi toda la mezcla real incluso con k=1
    @test e3_mezcla_necesaria(1.0, 1e-2) > 0.98
    @test e3_mezcla_necesaria(10.0, 1e-2) > 0.99
    # con pocas piezas reales la probabilidad de pasar se hunde al crecer k
    @test e3_pasa_muestreo(λ, 0.01λ, 1.0) < 0.02
    @test e3_pasa_muestreo(λ, 0.01λ, 10.0) < 1e-19
    @test e3_pasa_muestreo(λ, 1.0λ, 10.0) > 0.999
    # grinding: barato con k=1 y prohibitivo con k=10
    @test e3_grinding(λ, 0.01λ, 1.0) < 1e3
    @test e3_grinding(λ, 0.01λ, 10.0) > 1e18
    # la ventana abarata la agregación a k tablas por envío, independiente de N
    @test e3_cpu_agregacion_con_ventana(HW, 10.0, 100.0, 7200.0) < 0.01
    @test isinf(e3_cpu_agregacion_con_ventana(HW, 10.0, 100.0, 0.0))
end
