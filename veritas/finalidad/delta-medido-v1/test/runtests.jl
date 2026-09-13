# test/runtests.jl — casos a mano, propiedades, equivalencia de motores y bordes.
#
# Ejecutar con: julia --project=. test/runtests.jl

using Test
using Random
using StableRNGs
using DeltaMedido

@testset "DeltaMedido" begin

    @testset "casos calculados a mano" begin
        # Camino 1-2-3-4, latencia 1 s por enlace, transmisión instantánea (t_tx = 0).
        # Llegadas esperadas: nodo1=0, nodo2=1, nodo3=2, nodo4=3 s.
        g_camino = construir_csr(4, Int32[1, 2, 3], Int32[2, 3, 4])
        red_camino = Red(g_camino, [1.0, 1.0, 1.0], 0.0, 0.0)
        llegada = correr_referencia(red_camino, [0.0], Int32[1])
        @test llegada[:, 1] == [0.0, 1.0, 2.0, 3.0]
        D = deltas_por_bloque(llegada, [0.0])
        @test D[1, :] == [1.0, 3.0, 3.0, 3.0]   # Δ50, Δ90, Δ99, Δ100
        m = MotorRapido(4)
        llegada_rapida = correr!(m, red_camino, [0.0], Int32[1])
        @test llegada_rapida == llegada
        @test deltas_por_bloque(llegada_rapida, [0.0]) == D

        # Estrella con centro 1 y hojas 2-3-4; t_tx = 0,5 s, latencia 0. Bloque creado
        # en la hoja 2: hoja2=0, centro=0,5, hoja3=1,5, hoja4=2,0 (cola serial del centro).
        g_estrella = construir_csr(4, Int32[1, 1, 1], Int32[2, 3, 4])
        red_estrella = Red(g_estrella, zeros(3), 0.5, 0.0)
        llegada_estrella = correr_referencia(red_estrella, [0.0], Int32[2])
        @test sort(llegada_estrella[:, 1]) == [0.0, 0.5, 1.5, 2.0]
        D_estrella = deltas_por_bloque(llegada_estrella, [0.0])
        @test D_estrella[1, :] == [0.5, 2.0, 2.0, 2.0]
        m2 = MotorRapido(4)
        @test correr!(m2, red_estrella, [0.0], Int32[2]) == llegada_estrella

        # Camino con t_tx = 0,25 s y latencia 1 s: 0 / 1,25 / 2,75 / 4,25 s.
        red_mixta = Red(g_camino, [1.0, 1.0, 1.0], 0.25, 0.0)
        llegada_mixta = correr_referencia(red_mixta, [0.0], Int32[1])
        @test sort(llegada_mixta[:, 1]) == [0.0, 1.25, 2.75, 4.25]
        D_mixta = deltas_por_bloque(llegada_mixta, [0.0])
        @test D_mixta[1, :] == [1.25, 4.25, 4.25, 4.25]
        m3 = MotorRapido(4)
        @test correr!(m3, red_mixta, [0.0], Int32[1]) == llegada_mixta
        @test deltas_por_bloque(correr!(m3, red_mixta, [0.0], Int32[1]), [0.0]) == D_mixta

        # Latencia 0 y t_tx = 0: todo es instantáneo, Δ = 0.
        red_cero = Red(g_camino, zeros(3), 0.0, 0.0)
        llegada_cero = correr_referencia(red_cero, [0.0], Int32[1])
        @test all(==(0.0), llegada_cero)
        @test all(==(0.0), deltas_por_bloque(llegada_cero, [0.0]))
        m4 = MotorRapido(4)
        @test correr!(m4, red_cero, [0.0], Int32[1]) == llegada_cero

        # n = 1: el creador es el único nodo, Δ = 0 para todo cuantil.
        g_uno = construir_csr(1, Int32[], Int32[])
        red_uno = Red(g_uno, Float64[], 0.0, 0.0)
        llegada_uno = correr_referencia(red_uno, [0.0], Int32[1])
        @test llegada_uno == fill(0.0, 1, 1)
        @test all(==(0.0), deltas_por_bloque(llegada_uno, [0.0]))

        # El procesado por salto t_proc retrasa cada reenvío (también el del creador):
        # nodo2 llega en 1,5; reenvía desde 2,0: nodo3 en 3,0 y nodo4 en 4,5.
        red_proc = Red(g_camino, [1.0, 1.0, 1.0], 0.0, 0.5)
        llegada_proc = correr_referencia(red_proc, [0.0], Int32[1])
        @test sort(llegada_proc[:, 1]) == [0.0, 1.5, 3.0, 4.5]
        m5 = MotorRapido(4)
        @test correr!(m5, red_proc, [0.0], Int32[1]) == llegada_proc
    end

    @testset "grafo desconectado debe fallar" begin
        g_desconectado = construir_csr(4, Int32[1], Int32[2])
        @test !es_conexo(g_desconectado)
        @test_throws ErrorException exigir_conexo(g_desconectado)
        # un nodo aislado tampoco pasa
        g_aislado = construir_csr(3, Int32[1], Int32[2])
        @test !es_conexo(g_aislado)
        @test_throws ErrorException exigir_conexo(g_aislado)
    end

    @testset "decodificación de pares ER" begin
        n = 7
        esperado = Tuple{Int32,Int32}[]
        for j in 2:n, i in 1:(j-1)
            push!(esperado, (Int32(i), Int32(j)))
        end
        @test length(esperado) == n * (n - 1) ÷ 2
        for k in 1:length(esperado)
            @test pareja_de_indice(k, n) == esperado[k]
        end
    end

    @testset "muestreo ER condicionado a conexión (n=4, p=0,5)" begin
        # G(4, 1/2): 38 de 64 grafos son conexos; E[aristas | conexo] = 144/38,
        # así que cada arista aparece con probabilidad 24/38 ≈ 0,6316.
        n = 4
        p = 0.5
        conteo = zeros(Int, 6)
        n_casos = 4000
        for semilla in 1:n_casos
            rng = StableRNG(UInt64(semilla))
            g = grafo_erdos_renyi(rng, n, p)
            @test es_conexo(g)
            for v in 1:n
                @test grado(g, v) >= 1
            end
            for v in 1:n
                for k in Int(g.offsets[v]):Int(g.offsets[v+1]-1)
                    u = Int(g.vecinos[k])
                    u > v || continue
                    idx = (u - 2) * (u - 1) ÷ 2 + v
                    conteo[idx] += 1
                end
            end
        end
        prob = conteo ./ n_casos
        esperada = 24 / 38
        @test all(x -> abs(x - esperada) < 0.05, prob)
    end

    @testset "grafo d-regular por conmutación" begin
        for (n, d) in [(8, 4), (20, 8), (64, 4), (64, 8)]
            for semilla in 1:5
                rng = StableRNG(UInt64(0xABCD) + UInt64(semilla))
                g = grafo_regular_por_conmutacion(rng, n, d)
                @test es_conexo(g)
                @test all(v -> grado(g, v) == d, 1:n)
                @test length(g.vecinos) == n * d
                # sin bucles ni aristas duplicadas
                vistas = Set{UInt64}()
                for v in 1:n
                    for k in Int(g.offsets[v]):Int(g.offsets[v+1]-1)
                        u = Int(g.vecinos[k])
                        u > v || continue
                        @test u != v
                        c = UInt64(min(u, v)) * UInt64(n + 1) + UInt64(max(u, v))
                        @test !(c in vistas)
                        push!(vistas, c)
                    end
                end
                @test length(vistas) == n * d ÷ 2
            end
        end
        # base_regular conserva el grado y no tiene bucles
        a, b = base_regular(10, 4)
        @test length(a) == 20
        @test all(a .!= b)
    end

    @testset "equivalencia referencia == kernel rápido" begin
        casos = [ParametrosRed(8, :regular, 4, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 20.0),
                 ParametrosRed(12, :regular, 4, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 20.0),
                 ParametrosRed(20, :regular, 8, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 20.0),
                 ParametrosRed(3, :erdos_renyi, 1, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 20.0),
                 ParametrosRed(5, :erdos_renyi, 2, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 20.0),
                 ParametrosRed(8, :erdos_renyi, 4, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 20.0),
                 ParametrosRed(20, :erdos_renyi, 6, 0.08, 0.5, 1.0e6, 683.0, 0.1, 1.0, 20.0),
                 ParametrosRed(12, :regular, 4, 0.08, 0.5, 2.0e6, 1.0e5, 0.0, 1.0, 20.0),
                 ParametrosRed(12, :regular, 4, 0.08, 0.5, 1.0e6, 0.0, 0.0, 0.5, 20.0)]
        for (i, p) in enumerate(casos)
            for semilla in 1:3
                rng = StableRNG(UInt64(0x5A5A) + UInt64(i) * 97 + UInt64(semilla))
                ok, detalle = validar_equivalencia(rng, p; n_casos = 3)
                @test ok || detalle
            end
        end
    end

    @testset "invariantes y monotonía de cuantiles" begin
        for (n, topo, grado) in [(8, :regular, 4), (20, :regular, 8),
                                 (8, :erdos_renyi, 4), (20, :erdos_renyi, 6)]
            p = ParametrosRed(n, topo, grado, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 30.0)
            for semilla in 1:3
                rng = StableRNG(UInt64(0x77) + UInt64(semilla))
                red = construir_red(rng, p)
                t_creacion = calendario_poisson(rng, 1.0, 30.0)
                creador = rand(rng, 1:n, length(t_creacion))
                llegada = correr_referencia(red, t_creacion, creador)
                @test invariantes(llegada, t_creacion)
                D = deltas_por_bloque(llegada, t_creacion)
                @test all(D[:, 1] .<= D[:, 2])
                @test all(D[:, 2] .<= D[:, 3])
                @test all(D[:, 3] .<= D[:, 4])
                @test all(D .>= 0.0)
                m = MotorRapido(n)
                @test correr!(m, red, t_creacion, creador) == llegada
            end
        end
    end

    @testset "calendario Poisson" begin
        conteos = Int[]
        for semilla in 1:400
            rng = StableRNG(UInt64(semilla))
            push!(conteos, length(calendario_poisson(rng, 1.0, 30.0)))
        end
        media = sum(conteos) / length(conteos)
        @test 28.5 <= media <= 31.5
    end

    @testset "semilla derivada" begin
        a = semilla_derivada(UInt64(0x5A5A), UInt64(1), UInt64(1))
        @test semilla_derivada(UInt64(0x5A5A), UInt64(1), UInt64(1)) == a
        @test semilla_derivada(UInt64(0x5A5A), UInt64(1), UInt64(2)) != a
        @test semilla_derivada(UInt64(0x5A5A), UInt64(2), UInt64(1)) != a
        @test semilla_derivada(UInt64(0x5A5B), UInt64(1), UInt64(1)) != a
    end

    @testset "cuantiles" begin
        @test cuantil_pct([1.0, 2.0, 3.0, 4.0], 50) == 2.0
        @test cuantil_pct([1.0, 2.0, 3.0, 4.0], 90) == 4.0
        @test cuantil_pct([1.0, 2.0, 3.0, 4.0], 25) == 1.0
        @test cuantil_pct([4.0, 1.0, 3.0, 2.0], 75) == 3.0
        @test isnan(cuantil_pct(Float64[], 50))
    end

    @testset "validación de parámetros" begin
        @test_throws ErrorException construir_red(StableRNG(1),
            ParametrosRed(10, :regular, 2, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 10.0))
        @test_throws ErrorException construir_red(StableRNG(1),
            ParametrosRed(9, :regular, 5, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 10.0))  # n·grado impar
        @test_throws ErrorException construir_red(StableRNG(1),
            ParametrosRed(10, :nueva, 4, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 10.0))
        @test_throws ErrorException construir_red(StableRNG(1),
            ParametrosRed(10, :regular, 4, 0.5, 0.08, 1.0e6, 683.0, 0.0, 1.0, 10.0))  # p99 < mediana
    end

    # -------------------------------------------------------------------------
    # r2 — tests nuevos de la enmienda (5.8 del encargo). Los 25040 asserts de la
    # r1 están arriba y no se tocan.
    # -------------------------------------------------------------------------

    @testset "r2: tamaños de objeto y ρ (tabla 5.2, D1)" begin
        # cabecera = 556 + 32·padres + 128·slots; anuncio = 812 + 6·tx; bloque = 812 + 350·tx
        @test tam_cabecera(1, 1) == 716.0
        @test tam_cabecera(4, 1) == 812.0
        @test tam_cabecera(16, 150) == 20268.0
        @test tam_anuncio(571) == 4238.0
        @test tam_anuncio(4464) == 27596.0
        @test tam_bloque_completo(4464) == 1563212.0
        # ρ = λ·d·t_tx con λ=1, d=8, t_tx = 8·tam/banda; comparado con la tabla de TAREAS (4 dec.)
        rho_esperado = [
            (716.0, 1.0e8, 0.0005), (716.0, 59.67e6, 0.0008),
            (812.0, 1.0e8, 0.0005), (812.0, 59.67e6, 0.0009),
            (4238.0, 1.0e8, 0.0027), (4238.0, 59.67e6, 0.0045),
            (20268.0, 1.0e8, 0.0130), (20268.0, 59.67e6, 0.0217),
            (27596.0, 1.0e8, 0.0177), (27596.0, 59.67e6, 0.0296),
            (1563212.0, 1.0e8, 1.0005), (1563212.0, 59.67e6, 1.6766),
        ]
        for (tam, bw, rho_ref) in rho_esperado
            p = ParametrosRed(100, :regular, 8, 0.08, 0.5, bw, tam, 0.0, 1.0, 600.0)
            rho = utilizacion(p)
            @test round(rho, digits = 4) == rho_ref
        end
        @test regimen(0.999) == "estable"
        @test regimen(1.0) == "saturado"
        @test regimen(1.0005) == "saturado"
    end

    @testset "r2: medias a mano, camino de 4 nodos (D2)" begin
        g_camino = construir_csr(4, Int32[1, 2, 3], Int32[2, 3, 4])
        red = Red(g_camino, [1.0, 1.0, 1.0], 0.0, 0.0)
        llegada = correr_referencia(red, [0.0], Int32[1])
        @test llegada[:, 1] == [0.0, 1.0, 2.0, 3.0]
        mb, mn = medias_llegada(llegada, [0.0], Int32[1])
        @test mb == [2.0]
        @test isnan(mn[1]) && mn[2] == 1.0 && mn[3] == 2.0 && mn[4] == 3.0
        @test delta_barra_uniforme(mb) == 2.0
        D = deltas_por_bloque(llegada, [0.0])
        @test 1.0 <= mb[1] <= D[1, 4]  # mínimo ≤ media por bloque ≤ Δ_100 del bloque
        # el kernel rápido da las mismas medias (matriz idéntica)
        m = MotorRapido(4)
        llegada_r = correr!(m, red, [0.0], Int32[1])
        mb_r, mn_r = medias_llegada(llegada_r, [0.0], Int32[1])
        @test mb_r == mb
        @test isequal(mn_r, mn)  # isequal: NaN == NaN aquí es true (IEEE 754: == con NaN es false)
    end

    @testset "r2: medias a mano, estrella (D3)" begin
        g_estrella = construir_csr(4, Int32[1, 1, 1], Int32[2, 3, 4])
        red = Red(g_estrella, zeros(3), 0.5, 0.0)
        # creador hoja 2: llegadas [0,5; 0; 1,5; 2,0]; media = 4/3 (Float64 más próximo)
        llegada = correr_referencia(red, [0.0], Int32[2])
        @test sort(llegada[:, 1]) == [0.0, 0.5, 1.5, 2.0]
        mb, mn = medias_llegada(llegada, [0.0], Int32[2])
        @test mb == [4.0 / 3.0]  # misma operación (suma exacta 4,0; división redondeada)
        # creador centro 1: llegadas [0; 0,5; 1,0; 1,5]; media = 1,0 exacto
        llegada_c = correr_referencia(red, [0.0], Int32[1])
        mb_c, mn_c = medias_llegada(llegada_c, [0.0], Int32[1])
        @test mb_c == [1.0]
        @test isnan(mn_c[1]) && mn_c[2] == 0.5 && mn_c[3] == 1.0 && mn_c[4] == 1.5
    end

    @testset "r2: dos bloques en el camino, Δ̄ uniforme y ponderada por espacio (D4)" begin
        g_camino = construir_csr(4, Int32[1, 2, 3], Int32[2, 3, 4])
        red = Red(g_camino, [1.0, 1.0, 1.0], 0.0, 0.0)
        t = [0.0, 0.0]
        creador = Int32[1, 4]
        llegada = correr_referencia(red, t, creador)
        @test llegada[:, 1] == [0.0, 1.0, 2.0, 3.0]
        @test llegada[:, 2] == [3.0, 2.0, 1.0, 0.0]
        mb, mn = medias_llegada(llegada, t, creador)
        @test mb == [2.0, 2.0]
        @test delta_barra_uniforme(mb) == 2.0
        # media general sobre los 6 pares observador≠creador: 12/6 = 2,0 (coincide)
        @test (1.0 + 2.0 + 3.0 + 3.0 + 2.0 + 1.0) / 6.0 == delta_barra_uniforme(mb)
        D = deltas_por_bloque(llegada, t)
        @test 1.0 <= mb[1] <= D[1, 4]
        @test 1.0 <= mb[2] <= D[2, 4]
        # pesos uniformes exactos (n=4, 1/4 representable): con sorteo uniforme de creadores
        # ambas reglas coinciden bit a bit en este caso simétrico (2,0)
        pesos = fill(0.25, 4)
        mb_w = media_bloque_espacio(llegada, t, creador, pesos)
        @test mb_w == mb
        @test delta_barra_sorteo_por_cuota(mb_w) == 2.0
        @test delta_barra_peso_por_creador(mb_w, creador, pesos) == 2.0
        # media por nodo: nodo1 creó el bloque 1 (ve el 2: 3,0); nodo4 creó el 2 (ve el 1: 3,0)
        @test mn[1] == 3.0 && mn[2] == 1.5 && mn[3] == 1.5 && mn[4] == 3.0
    end

    @testset "r2: hipótesis de concentración — cuotas suman y muestreo (D5)" begin
        for n in (100, 1000, 10000)
            q, k = cuotas_concentracion(n)
            @test k == n ÷ 10
            @test length(q) == n
            @test all(q[1:k] .== 9)
            @test all(q[k+1:end] .== 1)
            total = sum(q)
            @test total == 9 * k + (n - k)  # aritmética entera exacta
            @test sum(q[1:k]) == sum(q[k+1:end])  # 50/50 exacto
            w = pesos_de_cuotas(q)
            @test isapprox(sum(w), 1.0; rtol = 1e-12)
        end
        # muestreo con semilla fija: fracción de creadores en el top-10 % ≈ 0,5
        n = 1000
        q, k = cuotas_concentracion(n)
        total = sum(q)
        rng = StableRNG(UInt64(0x5A5A) + 1234)
        H = 600
        c1 = creadores_ponderados(rng, q, total, H)
        rng2 = StableRNG(UInt64(0x5A5A) + 1234)
        @test creadores_ponderados(rng2, q, total, H) == c1  # determinista
        f = count(x -> x <= k, c1) / H
        # binomial(600, 0,5): σ ≈ 12,2 → 2,04 %; tolerancia 0,05 ≈ 2,45σ (declarada en ENMIENDA-R2 D5)
        @test abs(f - 0.5) <= 0.05
    end

    @testset "r2: distingue sorteo por cuota de peso por creador (T1: 1,25 y NO 1,1)" begin
        # Derivación ENMIENDA-R2 §6 T1. Dos nodos: rico cuota 3 (peso 3/4), pobre cuota 1 (1/4).
        pesos = [0.75, 0.25]
        # Medias por bloque ya ponderadas por observador: 1,0 (rico), 2,0 (pobre).
        mb_cuota = [1.0, 1.0, 1.0, 2.0]
        creador_cuota = Int32[1, 1, 1, 2]
        # Regla (i): media simple = 5/4 = 1,25 exacto en binario.
        @test delta_barra_sorteo_por_cuota(mb_cuota) == 5.0 / 4.0
        # La regla doble daría 11/10 = 1,1: el estimador correcto NO es 1,1.
        @test delta_barra_sorteo_por_cuota(mb_cuota) != 2.75 / 2.5
        num_doble = 0.0
        den_doble = 0.0
        for (b, mb) in enumerate(mb_cuota)
            w = pesos[creador_cuota[b]]
            num_doble += w * mb
            den_doble += w
        end
        @test num_doble / den_doble == 2.75 / 2.5  # 1,1 — el valor que NO debe salir
        # Regla (ii): sorteo uniforme, peso por creador = 3/4·1 + 1/4·2 = 1,25 exacto.
        mb_unif = [1.0, 2.0]
        creador_unif = Int32[1, 2]
        @test delta_barra_peso_por_creador(mb_unif, creador_unif, pesos) ==
              3.0 / 4.0 * 1.0 + 1.0 / 4.0 * 2.0
    end

    @testset "r2: equivalencia referencia↔rápido con medias, bit a bit (D6)" begin
        casos = [ParametrosRed(8, :regular, 4, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 20.0),
                 ParametrosRed(12, :regular, 4, 0.08, 0.5, 1.0e6, 4238.0, 0.0, 1.0, 20.0),
                 ParametrosRed(20, :regular, 8, 0.08, 0.5, 1.0e8, 812.0, 0.0, 1.0, 20.0),
                 ParametrosRed(5, :erdos_renyi, 2, 0.08, 0.5, 1.0e6, 683.0, 0.0, 1.0, 20.0),
                 ParametrosRed(8, :erdos_renyi, 4, 0.08, 0.5, 1.0e8, 20268.0, 0.0, 1.0, 20.0),
                 ParametrosRed(20, :erdos_renyi, 6, 0.08, 0.5, 1.0e8, 27596.0, 0.1, 1.0, 20.0),
                 ParametrosRed(12, :regular, 4, 0.08, 0.5, 2.0e6, 1.0e5, 0.0, 1.0, 20.0)]
        for (i, p) in enumerate(casos)
            for semilla in 1:3
                rng = StableRNG(UInt64(0x5A5A) + UInt64(i) * 97 + UInt64(semilla))
                red = construir_red(rng, p)
                t_creacion = calendario_poisson(rng, 1.0, 20.0)
                creador = rand(rng, 1:p.n, length(t_creacion))
                llegada_ref = correr_referencia(red, t_creacion, creador)
                m = MotorRapido(p.n)
                llegada_rapida = correr!(m, red, t_creacion, creador)
                @test llegada_ref == llegada_rapida
                mb_ref, mn_ref = medias_llegada(llegada_ref, t_creacion, creador)
                mb_rap, mn_rap = medias_llegada(llegada_rapida, t_creacion, creador)
                @test mb_ref == mb_rap
                @test mn_ref == mn_rap
                D = deltas_por_bloque(llegada_ref, t_creacion)
                for b in eachindex(t_creacion)
                    @test minimum(llegada_ref[v, b] - t_creacion[b]
                                  for v in 1:p.n if v != creador[b]) <= mb_ref[b] <= D[b, 4]
                end
            end
        end
    end
end