# runtests.jl — perfil de referencia (1 hilo, límites activos)
# Se ejecuta con: veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl
using Test
using SpecialFunctions
using Arblib

include("../src/modelo.jl")
include("../src/referencia.jl")
include("../src/rapido.jl")
include("../src/validacion.jl")

const RB = Rational{BigInt}

@testset "secreto-atestiguacion-v1" begin

    @testset "F3 · captura (oráculo = enumeración)" begin
        @test validar_captura(6, 3)
        @test captura_reemplazo(RB(1), 5) == RB(1)
        @test captura_reemplazo(RB(0), 1) == RB(0)
        @test captura_reemplazo(RB(1, 2), 0) == RB(1)
        @test validar_sin_reemplazo(5, 3)
        @test captura_sin_reemplazo(RB(1, 2), 2, 3) == RB(0)
        @test captura_sin_reemplazo(RB(1, 2), 1000, 1) == RB(1, 2)
    end

    @testset "F3 · cadena (oráculo = enumeración por slot + ancla de constantes)" begin
        # enumeración de reto × sorteos en cada slot: mecánica distinta de la cerrada
        @test validar_cadena()
        # ancla independiente: log10 P = −(k+1)·d·log10(3) para α = 1/3
        for k in [1, 2, 4, 8], d in [10, 100, 7200]
            p = captura_cadena(RB(1, 3), k, d)
            l = log10(BigFloat(numerator(p)) / BigFloat(denominator(p)))
            @test l ≈ -(k + 1) * d * log10(3) atol = 1e-8 * (k + 1) * d
        end
        # con el factor del reto la captura es MENOR que sin él (k, d ≥ 1, α < 1)
        @test captura_cadena(RB(1, 3), 1, 2) < captura_cadena_sin_reto(RB(1, 3), 1, 2)
    end

    @testset "F4 · viveza (oráculo = enumeración, p < 1 incluido)" begin
        @test validar_produce(5, 3)
        @test validar_particion(5, 3)
        @test fraccion_produce(RB(0), RB(1), 1) == RB(1)
        @test fraccion_produce(RB(1, 2), RB(1), 1) == RB(1, 2)
        @test fraccion_produce(RB(1), RB(1), 1) == RB(0)
        # partición con sorteo del productor: k=1, corte 50/50 ⇒ P = 1 − 2·(1/2)² = 1/2
        @test paro_particion(RB(1, 2), 1) == RB(1, 2)
        @test paro_particion(RB(1, 2), 2) == RB(3, 4)
        
        @test paro_particion(RB(0), 4) == RB(0)      # sin corte: nadie para
    end

    @testset "F1 · superficie α* (control de P-PRESTAMO, demostrado)" begin
        @test validar_superficie()
        @test alpha_estrella_uno(RB(0), RB(0)) == RB(1, 2)
        @test alpha_estrella_uno(RB(1, 5), RB(0)) == RB(2, 5)
        @test alpha_estrella_uno(RB(0), RB(1, 5)) == RB(3, 10)
        @test alpha_estrella_uno(RB(1, 5), RB(1, 5)) == RB(1, 5)
    end

    @testset "F1 · control ejecutable de clasificación (§4.1), regímenes V1/V2" begin
        atk, d, pub, com = 7, 20, 999, 42
        rama = rama_privada_atacante(atk, d, pub, com)
        honestos = collect(1001:1004)
        # (1) compromiso previo → FALSIFICABLE: se satisface dentro de la rama privada
        @test cumple_compromiso_previo(rama, com)
        # (2) historial reciente → FALSIFICABLE
        @test cumple_historial_reciente(rama, atk, 5)
        # (3) referencia a datos públicos → FALSIFICABLE (ver no obliga a publicar)
        @test cumple_referencia_publica(rama, pub)
        # (4) atestiguación SIN firmas honestas → no se cumple (exige cooperación ajena)
        B = BloqueF1(150, atk, [com], [pub], [atk])
        @test !cumple_atestiguacion(B, honestos)
        # V1: con firmantes a ciegas la condición se satisface en rama privada
        B_v1 = BloqueF1(150, atk, [com], [pub], vcat([atk], firmas_obtenibles_v1(B, honestos)))
        @test cumple_atestiguacion(B_v1, honestos)
        # V2: la satisfacción implica que el bloque fue visto por cada firma ajena
        @test revelado_a_firmantes_v2(B_v1, honestos)
        # la rama del atacante NUNCA contiene firmas honestas por construcción
        @test all(b -> all(c -> c == atk, b.firmas), rama)
    end

    @testset "F4 · latencia: lognormal del enlace certificada" begin
        μ, σ = parametros_enlace()
        @test μ ≈ log(0.080) atol = 1e-15
        # identidades de parametrización (plomería, no evidencia externa): F(mediana)=0,5
        @test cdf_enlace_f64(0.080) ≈ 0.5 atol = 1e-12
        # comprobación independiente de z99: Φ(z99) = 0,99 con bola de Arb
        bz = comprobar_z99()
        @test abs(Float64(Arblib.midpoint(bz)) - 0.99) < 1e-9
        @test Float64(Arblib.radius(Arblib.Arf, bz)) < 1e-20
        # anclas de regresión (golden values independientes): F(0.5)=0.99 y umbrales
        bola = cdf_enlace_arb(0.500)
        @test abs(Float64(Arblib.midpoint(bola)) - 0.99) < 1e-6
        @test Float64(Arblib.radius(Arblib.Arf, bola)) < 1e-20
        for (t, esperado) in [(0.19, 0.8639109), (0.36, 0.9718904)]
            b = cdf_enlace_arb(t)
            m = Float64(Arblib.midpoint(b))
            @test Float64(Arblib.radius(Arblib.Arf, b)) < 1e-20
            @test abs(m - esperado) < 5e-3
        end
        # monotonías de borde de la cabida (modelo de suma de enlaces)
        @test p_cabe_multihop_conv(1.0, 0.60, 1, 1, 0.0) < p_cabe_multihop_conv(1.0, 0.26, 1, 1, 0.0)
        @test p_cabe_multihop_conv(1.0, 0.60, 4, 1, 0.0) < p_cabe_multihop_conv(1.0, 0.60, 1, 1, 0.0)
        @test p_cabe_conv(0.1, 2, 0.2) == 0.0
    end

    @testset "F4 · multihop: convolución ↔ Monte Carlo (rutas independientes)" begin
        semilla = UInt64(0x5EC5E70)
        # el MC del máximo de k enlaces debe igualar F_l^k en cuantiles de control
        for k in (1, 4, 8)
            n = 300_000
            maxs = mc_max_enlace(k, n, semilla)
            for q in (0.25, 0.5, 0.75)
                t = sort(maxs)[max(1, min(n, round(Int, q * n)))]
                @test cdf_enlace(t)^k ≈ q atol = 0.02
            end
        end
        # cruce convolución ↔ MC en celdas representativas (h = 3): el IC debe contener p_conv
        for (k, Δ) in [(1, 0.26), (4, 0.35), (8, 0.60)]
            p_conv = p_cabe_multihop_conv(1.0, Δ, k, 3, 0.02)
            p_mc, lo, hi = mc_p_cabe(1.0, Δ, k, 3, 0.02, 300_000, semilla)
            @test lo ≤ p_conv ≤ hi
            @test abs(p_mc - p_conv) < 0.01
        end
        # la convolución de UN enlace (m = 1) debe reproducir la CDF certificada
        for t in (0.19, 0.36, 0.50)
            x1, F1 = cdf_suma_enlaces(1, 6.0, 20_000)
            idx = clamp(round(Int, t / (6.0 / 20_000)) + 1, 1, length(F1))
            @test F1[idx] ≈ cdf_enlace_f64(t) atol = 2e-3
        end
    end

    @testset "F4 · fuga (oráculo = enumeración multinomial por plaza)" begin
        @test validar_fuga()
        # bordes exactos de la función generatriz
        @test p_no_fuga_exacta(RB(1, 3), RB(1), 2, 3) == RB(1)            # p_sil = 1: nadie filtra
        @test p_no_fuga_exacta(RB(1, 3), RB(0), 2, 3) == RB(1, 3)^(6)     # p_sil = 0: coincide con captura
        @test p_no_fuga_exacta(RB(0), RB(1, 2), 1, 2) == RB(1, 4)         # α = 0: honestos silenciosos 1/2
    end

    @testset "F3 · coste en cabecera (arimética entera)" begin
        @test bytes_cabecera_ed25519(0) == 0
        @test bytes_cabecera_ed25519(8) == 768
        @test bytes_cabecera_bls(8) == 97
        @test bytes_anuales(768) == 768 * SLOTS_ANUALES
    end
end
