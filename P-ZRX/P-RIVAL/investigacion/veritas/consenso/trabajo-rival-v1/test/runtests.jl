# test/runtests.jl — perfil de referencia: 1 hilo, límites activos.
#
#   JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl

using Test

include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
include(joinpath(@__DIR__, "..", "src", "referencia.jl"))
include(joinpath(@__DIR__, "..", "src", "rapido.jl"))
include(joinpath(@__DIR__, "..", "src", "validacion.jl"))

@testset "TR-v0.1 · modelo de trabajo rival" begin

    @testset "definiciones y bordes" begin
        # espacio público/privado: el exceso es exactamente β_d
        for β_d in (R(0), R(1)//4, R(1)//2), β_x in (R(0), R(1)//10), α in (R(0), R(1)//4)
            @test espacio_publico(α, β_d, β_x) + espacio_privado(α, β_d, β_x) == 1 + β_d
        end
        @test espacio_publico(R(0), R(0), R(0)) == 1
        @test espacio_privado(R(0), R(0), R(0)) == 0
    end

    @testset "control θ = 0 exacto" begin
        for β_d in R(0):R(1)//13:R(1), β_x in R(0):R(1)//7:R(1)//2
            2 * β_x + β_d <= 1 || continue
            @test alpha_aditivo(β_d, β_x, R(0), R(1)) == alpha_control_prestamo(β_d, β_x)
            @test alpha_aditivo(β_d, β_x, R(0), R(3)//2) == alpha_control_prestamo(β_d, β_x)
        end
        @test alpha_control_prestamo(R(0), R(0)) == R(1)//2
        @test alpha_control_prestamo(R(0), R(1)//10) == R(2)//5
    end

    @testset "g(α*) = 0 y signo estricto" begin
        for β_d in (R(1)//10, R(1)//3), β_x in (R(0), R(1)//10),
            θ in (R(1)//10, R(1)//2, R(9)//10), ρ in (R(1)//2, R(1), R(2))
            a = alpha_aditivo(β_d, β_x, θ, ρ)
            @test g_aditivo_desde_tasas(a, β_d, β_x, θ, ρ) == 0
            @test g_aditivo(a, β_d, β_x, θ, ρ) == 0          # dos expresiones distintas
        end
    end

    @testset "θ = 1 degenerado" begin
        @test_throws ErrorException alpha_aditivo(R(1)//4, R(0), R(1), R(1))
    end

    @testset "ventaja marginal e independencia de β_d" begin
        for θ in R(0):R(1)//11:R(10)//11, c in (R(0), R(1)//3, R(1), R(3))
            @test marginal_beta_d(θ, c) == ventaja_marginal_aditiva(θ, c)
            @test marginal_beta_d_reasignado(θ, c) == (1 - θ) + 2 * θ * c
            # β_x: el espacio abandona la pública y el trabajo se mueve con él;
            # gana el doble de efecto de espacio y por eso vale 2× β_d comprado.
            @test marginal_beta_x(θ, c) == 2 * ventaja_marginal_aditiva(θ, c)
        end
        # la ventaja de umbral no depende de θ ni de ρ
        for θ in (R(0), R(1)//4, R(1)//2, R(9)//10), ρ in (R(1)//2, R(1), R(4))
            @test ventaja_umbral(R(1)//5, R(1)//8, θ, ρ) == R(1)//5 // 2 + R(1)//8
        end
    end

    @testset "θ* no existe salvo el caso degenerado" begin
        for c in (R(1)//100, R(1)//2, R(1), R(2), R(100))
            @test theta_estrella_marginal(c) === missing
        end
        @test theta_estrella_marginal(R(0)) == R(1)
    end

    @testset "multiplicativa: control y frontera" begin
        for (β_d, β_x) in ((R(0), R(0)), (R(1)//10, R(0)), (R(1)//4, R(1)//10))
            c0 = alpha_control_prestamo(β_d, β_x)
            @test abs(alpha_multiplicativo_biseccion(β_d, β_x, R(0), _ -> R(1), _ -> R(1)) - c0) <=
                  R(1)//2^30
            for θ in (R(1)//4, R(1)//2, R(9)//10)
                @test abs(alpha_multiplicativo_biseccion(β_d, β_x, θ, _ -> R(1), _ -> R(1)) - c0) <=
                      R(1)//2^30
            end
        end
        # borde corregido: β_d = β_x = 0 y α = 0 no debe lanzar (σ_priv = 0)
        b0 = alpha_multiplicativo_biseccion(R(0), R(0), R(1)//2, _ -> R(1), _ -> R(1))
        @test abs(b0 - R(1)//2) <= R(1)//2^30
    end

    @testset "compuerta de umbral: enumeración de conteos enteros" begin
        for D in (2, 3, 4, 7)
            # (a) con hash de sobra en ambos lados, decide el espacio
            for s_pub in 0:8, s_priv in 0:8
                esperado = s_priv > s_pub ? 1 : (s_priv < s_pub ? -1 : 0)
                @test umbral_enumera(s_pub, s_priv, D * s_pub + D, D * s_priv + D, D) == esperado
            end
            # (b) atacante escaso de hash: el espacio no le sirve
            for s_pub in 1:8, s_priv in 0:8
                @test umbral_enumera(s_pub, s_priv, D * s_pub + D, D - 1, D) == -1
            end
        end
        # el grifo es neutral en la frontera de espacio cuando el atacante tiene hash
        @test gana_privada_umbral(3, 5, 100, 100, 4) == 1
        @test gana_privada_umbral(5, 3, 100, 100, 4) == -1
        # y cuando el hash limita, el espacio β_d no ayuda
        @test gana_privada_umbral(2, 9, 100, 4, 4) == -1   # h_priv/D = 1 < s_pub = 2
    end

    @testset "la pata no reduce la ventaja; θ de imposibilidad" begin
        for θ in R(1)//10:R(1)//10:R(9)//10, c in (R(0), R(1)//2, R(1), R(3))
            @test ventaja_beta_d(θ, c) >= ventaja_beta_d(R(0), c)
            @test ventaja_beta_d_reasignado(θ, c) >= ventaja_beta_d_reasignado(R(0), c)
            @test ventaja_beta_x(θ, c) >= 1
            @test ventaja_beta_x(θ, c) == 2 * ventaja_beta_d(θ, c)
        end
        # θ de cierre por imposibilidad: α* = 1 exacto y θ > 1/2
        for (β_d, β_x, ρ) in ((R(0), R(0), R(0)), (R(1)//10, R(0), R(1)//2),
                              (R(1)//2, R(1)//10, R(9)//10))
            θ = theta_cierre_imposible(β_d, β_x, ρ)
            @test θ !== missing
            @test θ >= R(1)//2
            @test alpha_aditivo(β_d, β_x, θ, ρ) == 1
        end
        # la igualdad θ_imp = 1/2 sólo ocurre en el origen (β_d = β_x = ρ = 0):
        # cualquier β > 0 o ρ > 0 la sube estrictamente por encima de 1/2
        @test theta_cierre_imposible(R(1)//100, R(0), R(0)) > R(1)//2
        @test theta_cierre_imposible(R(0), R(0), R(1)//100) > R(1)//2
        @test theta_cierre_imposible(R(0), R(0), R(0)) == R(1)//2
        @test theta_cierre_imposible(R(0), R(0), R(1)) === missing
    end

    @testset "cierre económico (trabajo comprado)" begin
        # c = 0: sólo θ = 1 (el espacio tendría que dejar de pesar)
        @test theta_estrella_economico(R(0), R(1)) == R(1)
        @test !cierra_economico(R(0), R(0), R(1))
        # c = 1: cierra para todo θ (el peaje ya iguala el valor del peso)
        @test theta_estrella_economico(R(1), R(1)) == R(0)
        @test cierra_economico(R(0), R(1), R(1))
        # c > 1: cierra para todo θ ≤ 1
        @test theta_estrella_economico(R(2), R(1)) == R(0)
        @test cierra_economico(R(0), R(2), R(1))
        # c = 1/2: sólo cierra en θ = 1
        @test theta_estrella_economico(R(1)//2, R(1)) == R(1)
        @test !cierra_economico(R(0), R(1)//2, R(1))
        @test cierra_economico(R(1), R(1)//2, R(1))
    end

    @testset "frontera por bisección (ruta independiente)" begin
        for (β_d, β_x, θ, ρ) in ((R(1)//10, R(0), R(1)//4, R(1)),
                                 (R(1)//4, R(1)//10, R(1)//2, R(1)),
                                 (R(0), R(0), R(1)//10, R(1)))
            g0 = g_aditivo_desde_tasas(R(0), β_d, β_x, θ, ρ)
            g1 = g_aditivo_desde_tasas(R(1), β_d, β_x, θ, ρ)
            if g0 < 0 && g1 > 0
                b = alpha_por_biseccion(β_d, β_x, θ, ρ)
                @test abs(b - alpha_aditivo(β_d, β_x, θ, ρ)) <= R(1)//2^39
            end
        end
    end

    @testset "multiplicativa: la ventaja SÍ puede decrecer con θ" begin
        # Contraejemplo de la verificación matemática independiente (2026-09-23):
        # β_d=1/10, β_x=1/10, ρ_priv=1/2, ρ_pub=1 ⇒ V estrictamente decreciente.
        vs = [ventaja_multiplicativa(0.1, 0.1, Float64(θ), 0.5, 1.0)
              for θ in (0//1, 1//10, 1//4, 1//2, 3//4, 9//10)]
        @test isapprox(vs[1], 0.15; atol = 1e-12)
        @test all(vs[i+1] < vs[i] for i in 1:length(vs)-1)
        @test vs[end] < vs[1]
        # ρ_priv = ρ_pub ⇒ constante = β_d/2 + β_x (el caso que el instrumento probaba antes)
        cst = [ventaja_multiplicativa(0.1, 0.1, Float64(θ), 1.0, 1.0)
               for θ in (0//1, 1//4, 1//2, 9//10)]
        @test all(abs(v - vs[1]) < 1e-12 for v in cst)
        # coherencia interna de la aditiva con compuerta (Modelo A)
        for θ in (R(1)//4, R(1)//2), c in (R(1)//2, R(1))
            @test ventaja_beta_x(θ, c) == 2 * ventaja_beta_d(θ, c)
        end
    end

    @testset "suite completa de validación" begin
        for (nombre, ok, detalle) in todas_las_validaciones()
            @test ok
        end
    end

    @testset "regresión de defectos propios" begin
        # D1: bucle roto del primitivo de compuerta (referencia inexistente) — eliminado.
        # D2: borde σ_priv = 0 en la multiplicativa — ahora devuelve sin error.
        @test signo_multiplicativo(R(0), R(1), R(1), R(1), R(1)//2) == -1
        # D3: bisección aditiva con g(0) ≥ 0 — ahora devuelve 0 en vez de lanzar.
        @test alpha_por_biseccion(R(0), R(0), R(1)//2, R(4)) == R(0)
        # D4: θ fuera de [0,1) en la multiplicativa debe fallar ruidosamente.
        @test_throws ErrorException signo_multiplicativo(R(1), R(1), R(1), R(1), R(1))
    end
end
