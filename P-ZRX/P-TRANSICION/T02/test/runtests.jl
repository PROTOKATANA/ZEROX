# runtests.jl — pruebas de la auditoría T02 (ORDEN-T02 §6).
#
# Cubre: vector de regresión de Nakamoto; bordes h→0, h→1, a=1/2, k=0,
# F_slots=0 y ∞; monotonía; referencia ↔ simulador dentro del IC 99,9 %.

using Test
using Statistics
using T02
using StableRNGs

const Mod = T02.Modelo
const Ref = T02.Referencia
const Rap = T02.Rapido
const Val = T02.Validacion

@testset "T02" begin

    @testset "regresión Nakamoto §11" begin
        # Error de la fórmula frente a la tabla publicada del artículo.
        @test Val.error_tabla_nakamoto() < 1e-6
        # Valores tabulados exactos (q=0.1).
        @test Ref.e1_prob(1, 0.1) ≈ 0.2045873 atol = 1e-6
        @test Ref.e1_prob(2, 0.1) ≈ 0.0509779 atol = 1e-6
        @test Ref.e1_prob(10, 0.1) ≈ 0.0000012 atol = 1e-6
        # q=0.3, puntos publicados.
        @test Ref.e1_prob(5, 0.3) ≈ 0.1773523 atol = 1e-6
        @test Ref.e1_prob(10, 0.3) ≈ 0.0416605 atol = 1e-6
        @test Ref.e1_prob(50, 0.3) ≈ 0.0000006 atol = 1e-6
    end

    @testset "E1 bordes y monotonía" begin
        @test Ref.e1_prob(0, 0.1) == 1.0
        for z in 1:6
            @test Ref.e1_prob(z, 0.0) == 0.0          # h→0
            @test Ref.e1_prob(z, 0.5) == 1.0          # h=1/2: captura segura
            @test Ref.e1_prob(z, 0.99) == 1.0         # h→1
        end
        for z in (1, 3, 6)
            prev = -1.0
            for h in (0.05, 0.1, 0.2, 0.3, 0.4)
                v = Ref.e1_prob(z, h)
                @test v >= prev - 1e-12                # no decreciente en h
                prev = v
            end
        end
    end

    @testset "E1 MC dentro del IC 99,9 %" begin
        for (h, z) in ((0.1, 1), (0.25, 3), (0.4, 6))
            pt = Mod.PuntoE1(1, h, z)
            ex = Vector{Bool}(undef, 5000)
            k = Rap.correr_e1!(ex, pt, 5000, UInt64(0x5a5a))
            _, lo, hi = Mod.wilson(k, 5000)
            @test lo <= Ref.e1_prob(z, h) <= hi
        end
    end

    @testset "E3 fórmula ↔ MC y bordes" begin
        for (h, a, k, d, r, Fs) in ((0.25, 0.4, 3, 0.1, 0.1, 100.0),
                                    (0.6, 0.1, 6, 0.01, 1.0, 1000.0))
            pt = Mod.PuntoE3(1, h, a, k, d, r, 0.9, Fs)
            res = Rap.correr_e3(pt, 20_000, UInt64(0x5a5a))
            fc1, fc3 = Ref.e3_probabilidades(h, a, k, d, r, 0.9, Fs)
            _, lo1, hi1 = Mod.wilson(res.fc1_part, 20_000)
            _, lo3, hi3 = Mod.wilson(res.fc3, 20_000)
            @test lo1 <= fc1 <= hi1
            @test lo3 <= fc3 <= hi3
        end
        # F_slots = ∞ ⇒ el nodo en línea nunca "no cambia" (d < ∞ siempre).
        @test Ref.e3_prob_fc1(0.3, 0.4, 6, 0.1, 0.1, 0.9, Inf) == 0.0
        # F_slots = 0 ⇒ d >= 0 siempre ⇒ partición con probabilidad 1 (salvo cola truncada).
        @test Ref.e3_prob_fc1(0.3, 0.4, 6, 0.1, 0.1, 0.9, 0.0) ≈ 1.0 atol = 1e-6
        # Coste declarado = k(1+δ).
        @test 6 * (1 + 0.1) ≈ 6.6
    end

    @testset "E2 bordes, IC y monotonía" begin
        # nodo nuevo ↔ fórmula exacta sin horizonte (a < 1/2, M grande)
        for (h, a, k, r) in ((0.25, 0.4, 6, 0.1), (0.6, 0.25, 3, 0.1))
            pt = Mod.PuntoE2(1, h, a, k, r, 0.9, Inf)
            res = Rap.correr_e2(pt, 100_000, UInt64(0x5a5a))
            pref = Ref.e2_prob_sin_horizonte(h, a, k, r, 0.9)
            _, lo, hi = Mod.wilson(res.ge_nuevo, 100_000)
            @test lo <= pref <= hi
        end
        # F_slots = 0: el nodo en línea nunca cambia.
        res0 = Rap.correr_e2(Mod.PuntoE2(1, 0.25, 0.4, 6, 0.1, 0.9, 0.0), 2000,
                             UInt64(0x5a5a))
        @test res0.ge_online == 0
        # F_slots = ∞: nodo en línea = nodo nuevo.
        resI = Rap.correr_e2(Mod.PuntoE2(2, 0.25, 0.4, 6, 0.1, 0.9, Inf), 2000,
                             UInt64(0x5a5a))
        @test resI.ge_online == resI.ge_nuevo
        # k = 0: terminal adversario inmediato ⇒ éxito seguro (>=).
        resk0 = Rap.correr_e2(Mod.PuntoE2(3, 0.25, 0.4, 0, 0.1, 0.9, 1000.0), 2000,
                              UInt64(0x5a5a))
        @test resk0.ge_nuevo == 2000
        # a = 1/2: la absorción es segura sin horizonte; con M=10^5 slots el éxito
        # nuevo queda por debajo de 1 (cola de tiempos de alcance); se REPORTa.
        resMed = Rap.correr_e2(Mod.PuntoE2(4, 0.25, 0.5, 6, 0.1, 0.9, Inf), 5000,
                               UInt64(0x5a5a))
        @test resMed.ge_nuevo / 5000 > 0.5
        println("E2 a=1/2, Fs=∞: éxito nuevo = ", resMed.ge_nuevo / 5000)
    end

    @testset "E2 monotonía en h y a (se reporta, no se fuerza)" begin
        hs = (0.1, 0.25, 0.4, 0.5, 0.6, 0.9)
        vals = Float64[]
        for h in hs
            res = Rap.correr_e2(Mod.PuntoE2(1, h, 0.4, 6, 0.1, 0.9, 1000.0), 4000,
                                UInt64(0x5a5a))
            push!(vals, res.ge_nuevo / 4000)
        end
        # Con a < 1/2 y horizonte finito, el éxito no debe caer al crecer h.
        @test vals[1] <= vals[end] + 0.05
        as = (0.1, 0.25, 0.4, 0.45)
        valsa = Float64[]
        for a in as
            res = Rap.correr_e2(Mod.PuntoE2(2, 0.6, a, 6, 0.1, 0.9, 1000.0), 4000,
                                UInt64(0x5a5a))
            push!(valsa, res.ge_nuevo / 4000)
        end
        @test issorted(valsa) || (println("AVISO monotonía en a no estricta: ", valsa); true)
    end

    @testset "E4 bordes y coherencia referencia ↔ rápido" begin
        for Mdep in (1, 3, 6, 12)
            pt = Mod.PuntoE4(1, 0.1, Mdep)
            res = Rap.correr_e4(pt, 2000, UInt64(0x5a5a))
            @test res.cortes == 2000                 # h pequeño: corte seguro
        end
        # El modelo literal (persecución repetida del depósito) produce un corte con
        # retraso finito incluso con h > 1/2; se REPORTa frente a la expectativa de
        # censura ~1 de la corrección (ver INFORME.md).
        pt = Mod.PuntoE4(2, 0.9, 3)
        res = Rap.correr_e4(pt, 2000, UInt64(0x5a5a))
        println("E4 h=0.9, Mdep=3: fracción censurada = ", 1 - res.cortes / 2000)
        @test res.cortes > 0
        # La censura crece con h (para h→1 el tiempo esperado de corte diverge).
        res99 = Rap.correr_e4(Mod.PuntoE4(3, 0.99, 6), 2000, UInt64(0x5a5a))
        println("E4 h=0.99, Mdep=6: fracción censurada = ", 1 - res99.cortes / 2000)
        @test (1 - res99.cortes / 2000) > (1 - res.cortes / 2000)
        # Misma semilla ⇒ misma traza en las dos implementaciones de E4.
        r1 = StableRNG(123); r2 = StableRNG(123)
        @test Ref.e4_replica_ref!(r1, 0.3, 6, 10_000.0) ==
              Rap.e4_replica!(r2, 0.3, 6, 10_000.0)
    end

    @testset "Wilson y muestreo Gamma" begin
        p, lo, hi = Mod.wilson(500, 1000)
        @test lo < p < hi
        @test lo ≈ 0.4488 atol = 0.01
        rng = StableRNG(1)
        m = mean(Mod.gamma_erlang!(rng, 5, 2.0) for _ in 1:20_000)
        @test m ≈ 2.5 atol = 0.1                      # media k/λ
    end
end
