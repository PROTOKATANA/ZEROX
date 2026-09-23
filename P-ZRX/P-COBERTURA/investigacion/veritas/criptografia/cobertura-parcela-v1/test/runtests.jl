# runtests.jl — referencia, bordes, invariantes, contraejemplos y regresión.
#
# Regla del encargo §4: «Un test que compara una fórmula consigo misma no es un
# test». Por eso aquí cada fórmula se contrasta con un oráculo de naturaleza
# distinta: la frontera combinatoria, la enumeración exacta, el Monte Carlo con
# Philox, una cota de acoplamiento demostrada y las identidades de coste.

using Test
using CoberturaParcela
const CP = CoberturaParcela

@testset "cobertura-parcela-v1" begin

    @testset "1 · la frontera es exacta: P(X>B)=0 ⟺ M≤B ó k≤B" begin
        casos = 0
        for N in (8, 13, 30), k in 0:N, B in (0, 1, 2, 5), M in 0:N
            ex = cola_hiper_exacta(N, M, k, B)
            pred = (M <= B) || (k <= B)
            @test iszero(ex) == pred
            casos += 1
        end
        @test casos == (31 * 4 * 31) + (14 * 4 * 14) + (9 * 4 * 9)
    end

    @testset "2 · almacenamiento forzado exacto y su régimen k≤B" begin
        @test almacenamiento_forzado_exacta(1000, 10, 100) == 0                 # k ≤ B
        @test almacenamiento_forzado_exacta(1000, 100, 10) == 1 - 10 // 1000    # k > B
        @test almacenamiento_forzado_exacta(1000, 10, 1000) == 0                # B = N
        @test almacenamiento_forzado(1_048_480, 179_590) ≈ 0.8287139478101633 atol = 1e-12
        @test almacenamiento_forzado(1_048_480, 0) == 1.0
        @test ahorro_maximo(1_048_480, 179_590) ≈ 1 - 0.8287139478101633 atol = 1e-12
        @test !deteccion_posible(1000, 1000)
        @test deteccion_posible(1001, 1000)
    end

    @testset "3 · bordes exactos" begin
        @test cola_hiper_exacta(5, 5, 5, 4) == 1 // 1        # todo omitido, k=N
        @test cola_hiper_exacta(5, 0, 5, 0) == 0 // 1        # nada omitido
        @test cola_hiper_exacta(5, 3, 0, 0) == 0 // 1        # k=0: X≡0
        @test cola_hiper_exacta(5, 3, 5, 5) == 0 // 1        # B≥min(k,M)
        @test cola_hiper_exacta(10, 1, 10, 0) == 1 // 1      # una omitida, k=N
        @test_throws ArgumentError cola_hiper_exacta(5, 6, 5, 0)
        @test_throws ArgumentError cola_hiper_exacta(5, 2, 6, 0)
        @test T_para_beta_exacta(0 // 1, 1 // 1000) == typemax(Int)
        @test T_para_beta_exacta(1 // 1, 1 // 1000) == 1
        @test deteccion_acumulada_exacta(1 // 2, 1) == 1 // 2
        @test deteccion_acumulada_exacta(1 // 2, 2) == 3 // 4
    end

    @testset "4 · kernel Float64 contra referencia Rational{BigInt}" begin
        peor, casos = contraste_kernel_referencia()
        @test casos > 1000
        @test peor < 1e-10
        # invariante: el kernel nunca sale de [0,1] (se recorta el artefacto del
        # espacio logarítmico, que en `grande_1TiB` φ=0,9 daba 1,0000000155)
        t400 = TablaLogFact(400)
        for N in (400,), k in (1, 10, 200, 400), B in (0, 5, 400), M in 0:N
            p = cola_hiper_rapida(t400, N, M, k, B)
            @test 0.0 <= p <= 1.0
        end
        # y el recorte no cambia ninguna frontera: p=0 sigue siendo 0
        @test cola_hiper_rapida(t400, 400, 100, 10, 10) == 0.0
    end

    @testset "5 · el encierre BigFloat contiene la referencia exacta" begin
        for N in (12, 25, 60), k in (1, 3, 7), B in (0, 2), M in 0:N
            k <= N || continue
            lo, hi = cola_hiper_intervalo(N, M, k, B; bits = 256)
            exf = setprecision(BigFloat, 1024) do
                BigFloat(cola_hiper_exacta(N, M, k, B))
            end
            @test lo <= exf <= hi
            @test lo <= hi
        end
    end

    @testset "6 · la cota de acoplamiento hiper↔binomial se cumple" begin
        for N in (6, 11, 23), k in 1:N, M in 0:N
            tv = Float64(tv_hiper_binomial_exacta(N, M, k))
            @test tv <= cota_tv_hiper_binomial(N, k) + 1e-12
        end
        @test cota_tv_hiper_binomial(10, 0) == 0.0
        @test cota_tv_hiper_binomial(10, 1) == 0.0
    end

    @testset "7 · Clopper–Pearson contra valores de referencia publicados" begin
        # valores exactos de la distribución beta (tablas estándar), 95 %
        lo, hi = clopper_pearson(3, 10)
        @test lo ≈ 0.06674 atol = 5e-5
        @test hi ≈ 0.65245 atol = 5e-5
        lo0, hi0 = clopper_pearson(0, 10)
        @test lo0 == 0.0
        @test hi0 ≈ 1 - 0.025^(1 / 10) atol = 1e-6      # 0,30850
        lon, hin = clopper_pearson(10, 10)
        @test hin == 1.0
        @test lon ≈ 0.025^(1 / 10) atol = 1e-6          # 0,69150
        lo2, hi2 = clopper_pearson(1, 2)
        @test lo2 ≈ 0.01258 atol = 5e-5
        @test hi2 ≈ 0.98742 atol = 5e-5
        @test_throws ArgumentError clopper_pearson(11, 10)
    end

    @testset "8 · Monte Carlo contra la fórmula exacta (Clopper–Pearson)" begin
        semilla = UInt64(0x5A5A)
        for (N, k, B, M) in ((200, 5, 0, 40), (500, 10, 1, 60), (300, 4, 2, 120))
            ex = Float64(cola_hiper_exacta(N, M, k, B))
            phat, exitos, rep = p_deteccion_mc(semilla, N, M, k, B, 4000)
            ok, lo, hi = mc_dentro_de_cp(exitos, rep, ex)
            @test ok
            @test lo <= phat <= hi
            # y una tolerancia declarada, no ±1σ
            sd = sqrt(ex * (1 - ex) / rep)
            @test abs(phat - ex) <= 5 * sd + 1 / rep
        end
    end

    @testset "9 · el muestreador sin reemplazo es uniforme" begin
        N, k, rep = 6, 2, 30_000
        cuenta = zeros(Int, N, N)
        m = Muestra(N, k)
        for r in 1:rep
            una_auditoria!(m, rng_replica(UInt64(0xBEEF), r), N, k, 0, 0)
            a, b = minmax(m.idx[1], m.idx[2])
            cuenta[a, b] += 1
        end
        esperado = rep / (N * (N - 1) / 2)          # 2000
        for a in 1:N, b in (a + 1):N
            @test abs(cuenta[a, b] - esperado) < 0.1 * esperado
        end
        @test sum(cuenta) == rep
    end

    @testset "10 · Philox contracontador, no semillas consecutivas" begin
        ac = autocorrelacion_lag1(UInt64(0x5A5A), 20_000)
        @test abs(ac) < 0.02
        @test rand(rng_replica(UInt64(1), 7), 5) == rand(rng_replica(UInt64(1), 7), 5)
        @test rand(rng_replica(UInt64(1), 7), 5) != rand(rng_replica(UInt64(1), 8), 5)
    end

    @testset "11 · identidad de coste: núcleos por TiB vs máquinas por TiB" begin
        e = Entrada(N = 1_048_480, k = 1000, w_slots = 7175.0, D_a_s = 0.0,
                    t_unidad_s = 0.809, r_maquina_s = 25.03)
        # trabajo total: 235,6168 h·núcleo/TiB (independiente de w)
        @test trabajo_nucleo_h_por_TiB(e) ≈ 235.6167575 rtol = 1e-7
        # la cifra publicada 5,838 «CPU»/TiB usa SOLO w (D_a=0)
        @test maquinas_por_TiB(e) ≈ 5.838178903 rtol = 1e-6
        # y 118,2189 núcleos estrictos en la misma ventana
        @test nucleos_por_TiB(e) ≈ 118.2188609 rtol = 1e-6
        neq = nucleos_equivalentes_por_maquina(e)
        @test neq ≈ 20.249270 rtol = 1e-6
        # la identidad que reconcilia las dos cifras publicadas
        @test nucleos_por_TiB(e) ≈ maquinas_por_TiB(e) * neq rtol = 1e-9
        @test maquinas_por_TiB(e) ≈
              trabajo_nucleo_h_por_TiB(e) / (neq * ventana_s(e) / 3600) rtol = 1e-9
        # con la ventana completa (w + D_a) la cifra baja: relación exacta, no constante
        e2 = Entrada(N = 1_048_480, k = 1000, w_slots = 7175.0, D_a_s = 60.0,
                     t_unidad_s = 0.809, r_maquina_s = 25.03)
        @test maquinas_por_TiB(e2) ≈ maquinas_por_TiB(e) * 7175 / 7235 rtol = 1e-12
        @test maquinas_por_TiB(e2) < maquinas_por_TiB(e)
        # E3 medido consume 1,185228× el ideal serial de E1 (eficiencia 0,84372)
        maq_s_por_TiB = piezas_por_TiB() / e.r_maquina_s
        @test (maq_s_por_TiB * 24 / 3600) / trabajo_nucleo_h_por_TiB(e) ≈
              24 / neq rtol = 1e-9
    end

    @testset "12 · el tramposo que sólo responde a auditorías no paga por N" begin
        e = Entrada(N = 1_048_480, k = 1000, w_slots = 7175.0, D_a_s = 60.0)
        # B = 181.070 unidades ≫ k = 1.000 ⇒ ninguna auditoría de 1.000 aperturas
        # puede detectar nada, almacene lo que almacene (colapso de E2)
        B = B_entero(e)
        @test B > e.k
        @test !deteccion_posible(e.k, B)
        @test almacenamiento_forzado_exacta(e.N, e.k, B) == 0
        # el umbral de detección como TASA: k/D_a debe superar B/D_a
        @test tasa_lectura_honesta(e) < tasa_regeneracion_adversaria(e)
        # y con 1.000.000 de aperturas sí hay detección posible
        @test deteccion_posible(1_000_000, B)
        @test almacenamiento_forzado_exacta(e.N, 1_000_000, B) > 0
    end

    @testset "13 · NO-CONSTANTE: el resultado cambia en la dirección correcta" begin
        # El almacenamiento forzado DECRECE al crecer B (más capacidad de regenerar)
        # y CRECE al crecer N (el mismo B cubre una fracción menor del lote).
        @test almacenamiento_forzado(1000, 100) < almacenamiento_forzado(1000, 50)
        @test almacenamiento_forzado(1000, 100) < almacenamiento_forzado(2000, 100)
        @test ahorro_maximo(1000, 100) > ahorro_maximo(1000, 50)
        # B crece con w, con D_a, con r y con el número de máquinas
        e0 = Entrada(N = 100_000, k = 10, w_slots = 100.0, D_a_s = 10.0)
        e1 = Entrada(N = 100_000, k = 10, w_slots = 200.0, D_a_s = 10.0)
        e2 = Entrada(N = 100_000, k = 10, w_slots = 100.0, D_a_s = 20.0)
        e3 = Entrada(N = 100_000, k = 10, w_slots = 100.0, D_a_s = 10.0, maquinas = 2.0)
        @test B_unidades(e0) < B_unidades(e1)
        @test B_unidades(e0) < B_unidades(e2)
        @test B_unidades(e0) < B_unidades(e3)
        @test B_unidades(e0) ≈ 110 * 25.03 rtol = 1e-12
        # con más máquinas puede omitir más: el almacenamiento forzado BAJA
        @test almacenamiento_forzado(100_000, B_entero(e3)) <
              almacenamiento_forzado(100_000, B_entero(e0))
        # la auditoría: más aperturas ⇒ más detección, nunca menos
        t = TablaLogFact(400)
        p1 = cola_hiper_rapida(t, 400, 200, 10, 0)
        p2 = cola_hiper_rapida(t, 400, 200, 20, 0)
        @test p2 > p1
        # más umbral de regeneración ⇒ menos detección
        @test cola_hiper_rapida(t, 400, 200, 20, 5) < cola_hiper_rapida(t, 400, 200, 20, 1)
        # 0 no es un valor por defecto silencioso
        @test !iszero(cola_hiper_rapida(t, 400, 200, 20, 0))
        
    end

    @testset "14 · coste y cruce con el precio del disco" begin
        e = Entrada(N = 1_048_480, k = 1000, w_slots = 7175.0, D_a_s = 60.0,
                    t_unidad_s = 0.809, r_maquina_s = 25.03)
        # cruce con razon_precio = 1: ≈ 8,4·10⁵ slots (la cifra de P-PERMANENCIA)
        @test w_cruce_disco_slots(e; razon_precio = 1.0) ≈ 848_266 rtol = 2e-3
        # el factor GPU (17×, documentación ajena NO MEDIDA) divide los núcleos
        e_da0 = Entrada(N = 1_048_480, k = 1000, w_slots = 7175.0, D_a_s = 0.0,
                        t_unidad_s = 0.809, r_maquina_s = 25.03)
        @test w_cruce_disco_slots(e_da0; razon_precio = 1.0, factor_gpu = 17.0) ≈
              w_cruce_disco_slots(e_da0; razon_precio = 1.0) / 17 rtol = 1e-12
        # el cruce escala linealmente con la razón de precios
        @test w_cruce_disco_slots(e_da0; razon_precio = 2.0) ≈
              2 * w_cruce_disco_slots(e_da0; razon_precio = 1.0) rtol = 1e-12
        # energía: regenerar 1 TiB en una ventana es ~1000× almacenarlo
        @test energia_kWh_por_TiB(e) > 1000 * energia_kWh_almacenar(e)
        # y el trabajo por TiB NO depende de w (el cruce es de hardware, no de energía)
        e_w = Entrada(N = 1_048_480, k = 1000, w_slots = 1_000_000.0, D_a_s = 60.0,
                      t_unidad_s = 0.809, r_maquina_s = 25.03)
        @test trabajo_nucleo_h_por_TiB(e_w) ≈ trabajo_nucleo_h_por_TiB(e) rtol = 1e-12
        @test nucleos_por_TiB(e_w) < nucleos_por_TiB(e)
    end

    @testset "15 · F5 · coste del registro y caducidad" begin
        c1 = coste_registro(piezas = 1_048_480, kappa_seg_slot = 1e-3, h_segmentos = 1e5,
                            bytes_alta = 200.0, M_slots = 7175.0)
        c2 = coste_registro(piezas = 1_048_480, kappa_seg_slot = 1e-2, h_segmentos = 1e5,
                            bytes_alta = 200.0, M_slots = 7175.0)
        @test c1.sectores == ceil(Int, 1_048_480 / 1000)          # 1049 sectores
        @test c1.vida_segmentos == 4 + 1.5 * 1e5
        # más segmentos por slot ⇒ vida más corta ⇒ más altas por día
        @test c2.altas_por_dia ≈ 10 * c1.altas_por_dia rtol = 1e-12
        @test c1.estado_B == c1.sectores * 200.0
        @test c1.estado_B_por_TiB ≈ ceil(1_048_480 / 1000) * 200.0
        # el estado y la fracción inactiva decrecen con la vida
        c3 = coste_registro(piezas = 1_048_480, kappa_seg_slot = 1e-3, h_segmentos = 1e6)
        @test c3.fraccion_inactiva_por_M < c1.fraccion_inactiva_por_M
        @test coste_registro(piezas = 1_048_480, kappa_seg_slot = 1e-3,
                             h_segmentos = 1e5, M_slots = 0.0).fraccion_inactiva_por_M == 0.0
        @test_throws ArgumentError coste_registro(piezas = 1000, kappa_seg_slot = 0.0,
                                                  h_segmentos = 1.0)
    end

    @testset "16 · la frontera no depende de k en el régimen k>B" begin
        # propiedad: para M>B fijo, P(X>B)>0 para TODO k>B y =0 para todo k≤B
        N, M, B = 40, 12, 3
        for k in 0:N
            ex = cola_hiper_exacta(N, M, k, B)
            @test iszero(ex) == (k <= B)
        end
    end
end
