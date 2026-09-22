# runtests.jl — suite de RNG-v0.1. Ejecutar con:
#   ./veritas/julia.sh --project=P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1 \
#       P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1/test/runtests.jl
#
# Se ejecuta directamente (no vía `Pkg.test`) para no requerir escritura en el depósito de Julia.

include(joinpath(@__DIR__, "..", "src", "RangoV1.jl"))
using .RangoV1
using Test
using StableRNGs

const C = ConfigControlador(w_slots=20, g_slots=20, q=10,
                            ganancia_num=1, ganancia_den=2,
                            paso_lo_num=1, paso_lo_den=2,
                            paso_hi_num=2, paso_hi_den=1,
                            sr_min=2048, sr_max=UInt64(2)^32,
                            r_inicial=UInt64(2)^20, retardos_ventana=2)

@testset "RNG-v0.1" begin
    @testset "oráculos e invariantes" begin
        @test validar_A_circulo(256).ok
        @test validar_A_circulo(1024).ok
        srs = srs_de_regresion()
        @test validar_razon_cerrada(srs).ok
        @test validar_paridad(srs).ok
        @test validar_dominio(srs).ok
        @test validar_deriva(C, srs).ok
    end

    @testset "bordes de A(SR) y del peso" begin
        @test A_sr(0) == 1 && A_sr(1) == 1 && A_sr(2) == 3 && A_sr(3) == 3
        @test peso_big(0) == big(2)^128
        @test_throws DomainError peso_fast(UInt64(0))
        @test peso_fast(UInt64(1)) == big(2)^127
        @test peso_fast(UInt64(2)) == fld(big(2)^128, 3)
        @test peso_fast(UInt64(typemax(UInt64))) == big(2)^64
    end

    @testset "paridad: la rejilla par mata el déficit" begin
        for sr in BigInt[2, 4, 2048, big(2)^20]
            @test deficit(sr) == rem(big(2)^128, sr + 1) // big(2)^128
            @test deficit(sr) < 1 // big(2)^64
        end
        for sr in BigInt[2047, 2049, 3, big(2)^11 + 1]
            @test deficit(sr) >= 1 // (sr + 1)
        end
    end

    @testset "controlador: kernel == referencia y bordes" begin
        rng = StableRNG(0x52414E474F)
        casos = Tuple{BigInt,BigInt}[(C.sr_min, 1), (C.sr_min, 0), (C.sr_max, 1),
                                     (C.sr_max, C.q), (C.sr_max, 10^6),
                                     (C.r_inicial, C.q), (C.r_inicial, 0),
                                     (C.r_inicial, typemax(UInt32))]
        for _ in 1:3000
            r = C.sr_min + 2 * rand(rng, UInt64(0):((C.sr_max - C.sr_min) ÷ 2))
            push!(casos, (BigInt(r), BigInt(rand(rng, UInt64(0):UInt64(200_000)))))
        end
        @test validar_controlador(C, srs_de_regresion(), casos).ok
    end

    @testset "Z0 y activación" begin
        @test validar_z0(C).ok
        @test validar_activacion(C).ok
        @test controlador_fast(C.r_inicial, UInt64(0), C) == (C.r_inicial, false)
        # Z0 no revierte: el rango no cambia al cerrar una cohorte vacía
        @test controlador_ref(C.r_inicial, 0, C)[1] == big(C.r_inicial)
    end

    @testset "anchura y rechazo de configuración" begin
        @test precondicion_u128(C)
        @test cabe_en_u256(C)
        grande = ConfigControlador(w_slots=20, g_slots=20, q=10,
                                   ganancia_num=1, ganancia_den=2,
                                   paso_lo_num=1, paso_lo_den=2,
                                   paso_hi_num=2, paso_hi_den=1,
                                   sr_min=2048, sr_max=typemax(UInt64) - 1,
                                   r_inicial=UInt64(2)^20, retardos_ventana=2)
        @test !precondicion_u128(grande)
        @test_throws ArgumentError controlador_fast(grande.r_inicial, UInt64(1), grande)
        @test validar_ancho(grande).ok
    end

    @testset "configuraciones inválidas se rechazan" begin
        @test_throws ArgumentError ConfigControlador(w_slots=0, g_slots=0, q=1,
            ganancia_num=1, ganancia_den=1, paso_lo_num=1, paso_lo_den=1,
            paso_hi_num=1, paso_hi_den=1, sr_min=2, sr_max=4, r_inicial=2,
            retardos_ventana=1)
        @test_throws ArgumentError ConfigControlador(w_slots=1, g_slots=0, q=1,
            ganancia_num=1, ganancia_den=1, paso_lo_num=1, paso_lo_den=1,
            paso_hi_num=1, paso_hi_den=1, sr_min=0, sr_max=4, r_inicial=2,
            retardos_ventana=1)                     # SR_MIN = 0: w = 2^128, fuera de u128
        @test_throws ArgumentError ConfigControlador(w_slots=1, g_slots=0, q=1,
            ganancia_num=1, ganancia_den=1, paso_lo_num=1, paso_lo_den=1,
            paso_hi_num=1, paso_hi_den=1, sr_min=3, sr_max=4, r_inicial=4,
            retardos_ventana=1)                     # SR_MIN impar
        @test_throws ArgumentError ConfigControlador(w_slots=1, g_slots=0, q=1,
            ganancia_num=2, ganancia_den=1, paso_lo_num=1, paso_lo_den=1,
            paso_hi_num=1, paso_hi_den=1, sr_min=2, sr_max=4, r_inicial=2,
            retardos_ventana=1)                     # a > d
    end
end
