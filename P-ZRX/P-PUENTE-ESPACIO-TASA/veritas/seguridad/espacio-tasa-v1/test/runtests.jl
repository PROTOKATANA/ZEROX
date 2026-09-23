# espacio-tasa-v1 — suite de validación.
#
#   # Perfil de referencia (un hilo, límites activos, `@inbounds` neutralizado):
#   JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia" \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --check-bounds=yes --project=. test/runtests.jl
#
# Los conjuntos que dependen de los artefactos del oráculo Rust se **saltan** con un aviso si
# `resultados/bitmaps.bin` no existe, en vez de pasar en vacío. El informe declara qué se ejecutó.

using Test
using StableRNGs
using Statistics: mean

include(joinpath(@__DIR__, "..", "src", "EspacioTasa.jl"))
using .EspacioTasa
const ET = EspacioTasa

const RES = joinpath(@__DIR__, "..", "resultados")
hay_artefactos = isfile(joinpath(RES, "bitmaps.bin")) &&
                isfile(joinpath(RES, "audita-retos.tsv")) &&
                isfile(joinpath(RES, "vectores.tsv"))

@testset "espacio-tasa-v1" begin

    # -----------------------------------------------------------------------------------------
    @testset "referencia exacta: cardinalidad, peso, bordes de SR" begin
        # Encargo §4: bordes SR = 0,1,2,3, u64::MAX−1, u64::MAX y efecto de paridad.
        @test ET.valores_aceptados(0) == 1
        @test ET.valores_aceptados(1) == 1
        @test ET.valores_aceptados(2) == 3
        @test ET.valores_aceptados(3) == 3
        @test ET.valores_aceptados(typemax(UInt64) - 1) == big(2)^64 - 1
        @test ET.valores_aceptados(typemax(UInt64)) == big(2)^64 - 1
        # C-GD-01: SR=0 → 2^128; SR=2^64−1 → mínimo 2^64.
        @test ET.peso_bloque(0) == big(2)^128
        @test ET.peso_bloque(typemax(UInt64)) == big(2)^64
        # El suelo es lo único que introduce ⌊·⌋, y está acotado por SR (relativo < 2^-64).
        for SR in (1, 2, 3, 7, 8, 4096, 10^9, 2^40)
            @test ET.peso_bloque(SR) * (big(SR) + 1) + ET.resto_suelo(SR) == big(2)^128
            @test ET.resto_suelo(SR) < big(SR) + 1
        end
        # Paridad: A(2m) == A(2m+1) y sin embargo w distinto.
        ok_par, _ = ET.eq_paridad(64)
        @test ok_par
    end

    @testset "cancelación del SR en la tasa de peso" begin
        for SR in (0, 1, 2, 3, 7, 8, 255, 256, 4096, 2^20, typemax(UInt64) - 1)
            razón = ET.razon_cancelacion(SR)
            if iseven(SR)
                @test razón == 1 - ET.resto_suelo(SR) // big(2)^128
            else
                @test razón == big(SR) // (big(SR) + 1) -
                      big(SR) * ET.resto_suelo(SR) // ((big(SR) + 1) * big(2)^128)
            end
            @test razón <= 1
            # El sesgo entre dos flujos con el mismo SR es exactamente 0.
            @test ET.sesgo_tasa(1000, 500, SR, SR) == 0
        end
        # El déficit impar es materialmente mayor que el suelo par.
        @test ET.desviacion_cancelacion(2049) < ET.desviacion_cancelacion(2048)
    end

    @testset "distancia circular: kernel vs referencia exacta" begin
        # Punto opuesto y bordes de u64.
        @test ET.distancia_u64(UInt64(0), UInt64(0)) == 0
        @test ET.distancia_u64(UInt64(0), UInt64(1)) == 1
        @test ET.distancia_u64(UInt64(0), UInt64(1) << 63) == UInt64(1) << 63
        @test ET.distancia_u64(UInt64(0), typemax(UInt64)) == 1
        @test ET.distancia_u64(typemax(UInt64), UInt64(0)) == 1
        @test ET.distancia_u64_exacta(UInt64(0), UInt64(1) << 63) == big(2)^63
        ok_d, peor_abs, _ = ET.eq_distancia_aleatoria(20_000, 0x5a5a)
        @test ok_d
        @test peor_abs == 0            # igualdad exacta, no tolerancia
        # La fórmula cierra con la enumeración exhaustiva en círculos pequeños.
        ok_c, malas = ET.eq_cardinalidad_exhaustiva(collect(3:2:151), 200)
        @test ok_c
        @test isempty(malas)
        # Predicado: incluye el borde (d == SR÷2 gana) y excluye (d == SR÷2 + 1).
        @test ET.gana(UInt64(5), UInt64(10))
        @test ET.gana(UInt64(5), UInt64(11))
        @test !ET.gana(UInt64(6), UInt64(10))
        @test ET.gana(UInt64(0), UInt64(0))
        @test !ET.gana(UInt64(1), UInt64(0))
        @test ET.gana(ET.distancia_u64(UInt64(0), typemax(UInt64)), typemax(UInt64))
    end

    @testset "contabilidad de bytes real del sector" begin
        # `sector_size` NO es `Piece::SIZE`: incluye mapa de contenidos y checksum.
        # `RecordMetadata` son commitment 48 + witness 48 + piece_checksum 32 = 128, no 96.
        @test ET.sector_size(1) == big(1_048_576 + 128 + 8_192 + 32 + 32)
        @test ET.sector_size(1000) == 1000 * big(1_056_896) + 64
        # La diferencia con `1000·Piece::SIZE` es 8 224 064, NO 8 224.
        @test ET.sector_size(1000) - 1000 * big(1_048_672) == big(8_224_064)
        @test ET.sector_size(1000) - 1000 * big(1_048_672) ==
              1000 * big(32) + 1000 * big(8_192) + big(64)
        # Metadata que queda FUERA del fichero del sector.
        @test ET.metadata_fuera_del_sector() == big(131_116)
        # Un sector completo de 1000 piezas, y la vuelta.
        sectores, piezas, usados = ET.piezas_de_bytes(ET.sector_size(1000))
        @test sectores == 1 && piezas == 1000 && usados == ET.sector_size(1000)
        s2, p2, _ = ET.piezas_de_bytes(big(2)^40)
        @test p2 == s2 * 1000
        @test ET.bytes_por_pieza(1000) == (1000 * big(1_056_896) + 64) // 1000
        @test floor(ET.bytes_por_pieza(1000)) == 1_056_896
    end

    @testset "reparto de bytes: sobrantes que no completan un sector" begin
        ss = ET.sector_size(1000)
        # 2 sectores y medio: los bytes sobrantes NO son piezas.
        r = ET.reparto_bytes(2 * ss + ss ÷ 2)
        @test r.bytes_solicitados == 2 * ss + ss ÷ 2
        @test r.sectores_completos == 2
        @test r.bytes_sectores_completos == 2 * ss
        @test r.bytes_sobrantes == ss ÷ 2
        @test r.piezas_efectivas == 2000
        # Un solo byte no produce ninguna pieza.
        r1 = ET.reparto_bytes(1)
        @test r1.sectores_completos == 0 && r1.piezas_efectivas == 0
        @test r1.bytes_sobrantes == 1
        # Las fracciones distinguen bytes solicitados de bytes completos y de piezas.
        rt = ET.reparto_bytes(4 * ss + 7)
        ra = ET.reparto_bytes(ss + 3)
        fr = ET.fracciones(ra, rt)
        @test fr.bytes_nominales_solicitados == (ss + 3) // (4 * ss + 7)
        @test fr.bytes_nominales_completos == 1 // 4
        @test fr.piezas_efectivas == 1 // 4
        # La tercera NO es la primera: es una fracción de piezas efectivas, no de bytes.
        @test fr.piezas_efectivas != fr.bytes_nominales_solicitados
    end

    @testset "escenario 1: presupuestos independientes (1 TiB y 1 %)" begin
        # Test EXACTO pedido: cada actor trunca por su cuenta.
        #   floor(10 995 116 277 / 1 056 896 064) = 10
        #   floor( 1 088 516 511 499 / 1 056 896 064) = 1029
        #   total 1039 sectores; cuota esperada 10/1039
        TIB = big(2)^40
        s1000 = ET.sector_size(1000)
        bytes_adv = TIB ÷ 100                     # 1 % truncado a bytes enteros
        bytes_hon = TIB - bytes_adv
        ps = ET.presupuestos_independientes([("adv", bytes_adv), ("hon", bytes_hon)])
        @test length(ps) == 2
        @test ps[1].sectores == 10
        @test ps[2].sectores == 1029
        @test ET.sectores_totales(ps) == 1039
        @test ps[1].sectores + ps[2].sectores == 1039
        @test ET.piezas_totales(ps) == 1039 * 1000
        @test ps[1].piezas == 10 * 1000 && ps[2].piezas == 1029 * 1000
        # La cuota esperada es 10/1039, NO 10/1040.
        @test ps[1].sectores // ET.sectores_totales(ps) == 10 // 1039
        @test ps[1].sectores // ET.sectores_totales(ps) != 10 // 1040
        # Los sobrantes son de cada actor y se pierden; ninguno se agrega.
        @test ps[1].sobrantes == bytes_adv - 10 * s1000
        @test ps[2].sobrantes == bytes_hon - 1029 * s1000
        @test ps[1].bytes_en_sectores == ps[1].bytes_solicitados - ps[1].sobrantes
        @test ps[1].bytes_en_sectores + ps[2].bytes_en_sectores + ps[1].sobrantes +
              ps[2].sobrantes == TIB
        # La calibración experimental de SR usa Σ piezas, no el total sin truncar.
        sr_sep = ET.rango_de_piezas(ET.piezas_totales(ps))
        @test sr_sep == ET.rango_de_piezas(1039 * 1000)
        @test sr_sep != ET.rango_de_piezas(1040 * 1000)
    end

    @testset "escenario 2: sectores ya ploteados y repartidos" begin
        TIB = big(2)^40
        r = ET.reparto_sobre_plot(TIB, [1 // 100, 99 // 100])
        @test r.sectores_totales == 1040            # el total SÍ se trunca una sola vez
        @test r.asignados == [10, 1029]
        @test sum(r.asignados) + r.resto == r.sectores_totales
        @test r.resto == 1                          # no asignado: no se regala a nadie
        # Contraste explícito con el escenario 1: el total difiere en 1 sector.
        ps = ET.presupuestos_independientes([("adv", TIB ÷ 100), ("hon", TIB - TIB ÷ 100)])
        @test r.sectores_totales == 1040 && ET.sectores_totales(ps) == 1039
        @test r.sectores_totales > ET.sectores_totales(ps)
    end

    @testset "propiedad Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋" begin
        TIB = big(2)^40
        s1000 = ET.sector_size(1000)
        rng = StableRNG(0xE1DE)
        for _ in 1:200
            n = rand(rng, 1:12)
            partes = [big(rand(rng, 0:10^12)) for _ in 1:n]
            r = ET.perdida_agregacion(partes)
            @test r.por_separado <= r.agregado          # la desigualdad, siempre
            @test r.perdidos >= 0
            @test r.agregado == sum(partes) ÷ s1000
        end
        # Igualdad cuando todos son múltiplos exactos del tamaño de sector.
        multiplos = [3 * s1000, 5 * s1000, 0, 7 * s1000]
        r = ET.perdida_agregacion(multiplos)
        @test r.perdidos == 0 && r.por_separado == r.agregado == 15
        # Caso patológico: ningún trozo llega a un sector, el total sí.
        trozos = fill(1000, 2_000_000)     # 2·10⁹ B en 2·10⁶ identidades de 1 000 B
        r2 = ET.perdida_agregacion(trozos)
        @test r2.por_separado == 0
        @test r2.agregado > 0
        @test r2.perdidos == r2.agregado
    end

    @testset "conservación de bytes al repartir T entre N" begin
        TIB = big(2)^40
        # Σ bytes_i = T EXACTAMENTE: el resto T mod N también se reparte.
        for N in (1, 2, 3, 5, 7, 999, 1041, 2000, 100_000)
            partes = ET.reparto_igual_exacto(TIB, N)
            @test length(partes) == N
            @test sum(partes) == TIB                      # conservación exacta
            @test maximum(partes) - minimum(partes) <= 1  # reparto lo más igual posible
        end
        @test ET.reparto_igual_exacto(10, 3) == [4, 3, 3]
        @test sum(ET.reparto_igual_exacto(big(10)^30 + 7, 13)) == big(10)^30 + 7
        # Test pedido: T = sector_size(1000), N = 5. El agregado debe contener un sector.
        T = ET.sector_size(1000)
        r = ET.tabla_identidades(T, [5])[1]
        @test r.conserva
        @test r.suma_bytes == T
        @test r.sectores_agregado == 1                    # calculado DESDE T, no desde N·⌊T/N⌋
        @test r.sectores_agregado == T ÷ T                # = 1 por construcción
        # Y las cinco partes, cada una por separado y con la hipótesis de 1000 piezas, dan 0.
        @test r.sectores_esc1_1000 == 0
        # El agregado NO se calcula desde N·⌊T/N⌋: esa suma perdería T mod N bytes.
        @test 5 * (T ÷ 5) < T
    end

    @testset "hipótesis de 1000 piezas y su contraejemplo" begin
        TIB = big(2)^40
        s1000 = ET.sector_size(1000)
        filas = ET.tabla_identidades(TIB, [1, 3, 7, 10, 100, 1040, 1041, 2000])
        porN = Dict(f.N => f for f in filas)
        # --- La pérdida NO es monótona en N: 7 pierde 4 y 10 pierde 0. ---
        @test porN[big(7)].perdidos == 4
        @test porN[big(10)].perdidos == 0
        @test porN[big(7)].perdidos > porN[big(10)].perdidos
        # Cota que SÍ se puede afirmar: cada truncamiento pierde menos de un sector ⇒ perdidos ≤ N.
        for f in filas
            @test f.perdidos <= f.N
            @test f.perdidos >= 0
        end
        # En todos los casos el escenario 2 es el del total, calculado desde T.
        for f in filas
            @test f.sectores_agregado == 1040
            @test f.conserva
        end
        # --- El contraejemplo que retira la conclusión general ---
        # Presupuesto de cada identidad con N = 1041: no cabe un sector de 1000 piezas…
        b = porN[big(1041)].bytes_por_identidad
        @test b < s1000
        @test porN[big(1041)].sectores_esc1_1000 == 0          # hipótesis: 1000 piezas fijas
        @test porN[big(1041)].identidades_sin_sector_1000 == 1041
        # …pero SÍ cabe un sector de 999 piezas, incluso contando la metadata externa.
        @test ET.sector_size(999) == big(1_055_839_168)
        @test ET.sector_size(999) <= b
        @test ET.sector_size(999) + ET.metadata_fuera_del_sector() <= b
        @test ET.piezas_que_caben(b) == 999
        @test porN[big(1041)].piezas_max_que_caben == 999
        @test porN[big(1041)].sector_si_ajusta_piezas
        # Y con 2000 identidades también cabe un sector (de 520 piezas).
        @test porN[big(2000)].piezas_max_que_caben == 520
        @test porN[big(2000)].sector_si_ajusta_piezas
        # `piezas_que_caben` es monótona y devuelve 0 solo cuando no cabe ni una pieza.
        @test ET.piezas_que_caben(ET.sector_size(1)) == 1
        @test ET.piezas_que_caben(ET.sector_size(1) - 1) == 0
        @test ET.piezas_que_caben(10^15) == 1000               # tope MAX_PIECES_IN_SECTOR
        prev = 0
        for b2 in (ET.sector_size(1), ET.sector_size(2), ET.sector_size(999), ET.sector_size(1000))
            p2 = ET.piezas_que_caben(b2)
            @test p2 >= prev
            prev = p2
        end
    end

    @testset "tamaño de plot vs metadata fija externa" begin
        # `sector_size()` es lo que ocupa el FICHERO de la parcela. La metadata de sector
        # (`SectorMetadataChecksummed`) vive FUERA y no forma parte del plot.
        @test ET.sector_size(1000) == 1000 * big(1_056_896) + 64
        @test ET.metadata_fuera_del_sector() == big(131_116)
        # Son magnitudes distintas y se suman solo si se habla de bytes físicos totales por sector.
        @test ET.sector_size(1000) + ET.metadata_fuera_del_sector() ==
              1000 * big(1_056_896) + 64 + 131_116
        @test ET.sector_size(1000) != ET.sector_size(1000) + ET.metadata_fuera_del_sector()
    end

    @testset "cuota azul: la afirmación «α_blue_work ≤ α_bytes» es FALSA" begin
        # Caso adversarial del encargo: fracción de piezas 0,3, β_adv = 1, β_hon = 1/2.
        c = ET.cuota_azul_condicional(3 // 10, 1 // 1, 1 // 2)
        @test c == 6 // 13
        @test isapprox(Float64(c), 0.461538, atol=1e-6)
        @test c > 3 // 10            # la cuota azul SUPERA la fracción de piezas
        # Simetría: con β iguales, la cuota es la fracción de piezas.
        @test ET.cuota_azul_condicional(3 // 10, 1 // 1, 1 // 1) == 3 // 10
        # Denominador cero: la cuota NO está definida y no se devuelve un valor cómodo.
        @test ET.cuota_azul(big(0), big(0)) === nothing
        @test ET.cuota_azul(ET.peso_bloque(4096), big(0)) == 1 // 1
        # Factores desconocidos explícitos: sin β, el trabajo azul es `pendiente`, no un número.
        p = ET.puente(big(1000); SR=UInt64(6148914691236495))
        @test p.trabajo_azul === nothing
        @test p.chunks_auditados == 500 && p.candidatos > 0
        pl = ET.rendimiento_limite_adversario(big(1000); SR=UInt64(6148914691236495))
        @test pl.trabajo_azul !== nothing      # límite favorable al adversario: condicionado
        # La cuota del escenario 1 se calcula SOLO con presupuestos independientes.
        ss = ET.sector_size(1000)
        ps3 = ET.presupuestos_independientes([("adv", 3 * ss), ("hon", 7 * ss)])
        @test ET.cuota_piezas_escenario1(ps3, 1) == 3 // 10
        @test ET.cuota_piezas_escenario1(ps3, 2) == 7 // 10
        # Es una IDENTIDAD del modelo con el mismo SR, no una validación experimental.
        @test ET.fraccion_candidatos_esperada_esc1(ps3, 1; SR=UInt64(6148914691236495)) == 3 // 10
        # La función heredada que MEZCLABA presupuesto independiente con sectores agregados
        # está RETIRADA: ya no existe en el módulo.
        @test !isdefined(ET, :fraccion_candidatos_esperada)
        # Y con sobrantes, el escenario 1 NO da la fracción de bytes: 3ss+1 B sigue dando 3 sectores.
        ps4 = ET.presupuestos_independientes([("adv", 3 * ss + 1), ("hon", 7 * ss)])
        @test ET.cuota_piezas_escenario1(ps4, 1) == 3 // 10
        @test (3 * ss + 1) // (10 * ss + 1) != 3 // 10
    end

    @testset "identidad exacta compartir/repartir (factor 2 por construcción)" begin
        bm = ET.bitmaps_sinteticos(6, 32768; semilla=0x77)
        s_a = zeros(Int32, 65_536)
        s_b = zeros(Int32, 65_536)
        ET.s_bucket_sizes_histograma!(s_a, bm[1:3, :], zeros(Int32, 256))
        ET.s_bucket_sizes_histograma!(s_b, bm[4:6, :], zeros(Int32, 256))
        for (bi, bj) in ((0, 1), (17, 40000), (65535, 12345))
            r = ET.reparto_exclusivo(s_a, s_b, bi, bj)
            # La IDENTIDAD válida para TODO par, incluido el degenerado:
            @test r.promedio_mitades == r.compartido / 2
            @test r.compartido == r.asignacion_1 + r.asignacion_2
            # El COCIENTE par a par es 2 solo si el denominador no es 0.
            if r.compartido > 0
                @test r.razon == 2.0 && r.definido
            else
                @test r.razon === nothing && !r.definido
            end
        end
        # Caso degenerado explícito: dos buckets vacíos para las dos mitades.
        vacio = zeros(Int32, 65_536)
        r0 = ET.reparto_exclusivo(vacio, vacio, 4, 15)
        @test r0.compartido == 0 && r0.promedio_mitades == 0
        @test r0.razon === nothing          # 0/0 INDEFINIDO, no 2 y no Inf
        @test !r0.definido
    end

    @testset "calibración de SR: consistencia con la probabilidad de slot" begin
        # `pieces_to_solution_range` reparte 1/6 de solución por slot entre N piezas usando
        # o = 1/2: E[candidatos] = N · (1/2) · A(SR)/2^64 debe dar exactamente ~1/6.
        for N in (1000, 10^6, 10^9)
            sr = ET.rango_de_piezas(N)
            pu = ET.puente(N; SR=sr)
            esperado = big(1) // big(6)
            # No es igualdad exacta por los truncamientos enteros del port; el error relativo
            # debe ser minúsculo.
            @test abs(Float64(pu.candidatos - esperado)) < 1e-9
        end
        @test ET.rango_de_piezas(1000) > 0
    end

    @testset "bitmaps sintéticos: invariantes estructurales" begin
        bm = ET.bitmaps_sinteticos(4, 32768; semilla=0x1234)
        ok, det = ET.invariantes_bitmaps(bm)
        @test ok
        @test det.pruebas_iguales_32768
        @test det.maximo_un_chunk_por_pieza
        @test det.ocupacion_desigual          # la ocupación NO es constante 1/2 por bucket
        @test det.buckets_vacios > 0          # hay buckets sin ninguna prueba
        @test det.suma_total == 4 * 32768     # conservación exacta de contadores
        ok_k, total_ref, total_kernel = ET.eq_conservacion_contadores(bm)
        @test ok_k
        @test total_ref == total_kernel == 4 * 32768
        ok_rs, n_rs = ET.eq_rank_select(bm; muestra=2000)
        @test ok_rs
        @test n_rs == 2000
        ok_par, s_ser, s_par = ET.eq_conservacion_paralelo(bm)
        @test ok_par                       # el kernel paralelo conserva los contadores
        @test s_ser == s_par == 4 * 32768
    end

    # -----------------------------------------------------------------------------------------
    if !hay_artefactos
        @info "Sin artefactos del oráculo Rust en resultados/: los conjuntos de contraste con Rust se SALTAN"
    else
        @testset "contraste con el oráculo Rust (misma parcela, mismo reto)" begin
            meta = ET.leer_meta(joinpath(RES, "bits-meta.tsv"))
            bitmaps, M = ET.leer_bitmaps(RES)
            retos = ET.leer_retos(RES)
            vectores = ET.leer_tabla(joinpath(RES, "vectores.tsv"))
            vectores_buckets = ET.leer_tabla(joinpath(RES, "vectores-buckets.tsv"))
            audita_retos = ET.leer_tabla(joinpath(RES, "audita-retos.tsv"))
            pares = ET.leer_tabla(joinpath(RES, "audita-pares.tsv"))
            prueba_meta = ET.leer_meta(joinpath(RES, "prueba-meta.tsv"))

            @test M == parse(Int, meta["piezas"])

            @testset "orden de bytes y distancia contra Rust" begin
                ok, n = ET.eq_rust_byte_order(vectores)
                @test ok
                @test n > 0
            end

            @testset "derivación del bucket contra Rust" begin
                ok, n = ET.eq_rust_bucket(vectores_buckets)
                @test ok
                @test n > 0
                ok2, n2, disc = ET.eq_buckets_propios(meta, retos, audita_retos)
                @test ok2
                @test disc == 0
                @test n2 > 0
            end

            @testset "invariantes sobre los bitmaps reales" begin
                ok, det = ET.invariantes_bitmaps(bitmaps)
                @test ok
                @test det.pruebas_iguales_32768
                @test det.suma_total == M * 32768
                ok_k, tr, tk = ET.eq_conservacion_contadores(bitmaps)
                @test ok_k
                @test tr == tk == M * 32768
            end

            @testset "chunks auditados/slot: Julia reproduce a Rust" begin
                sizes = zeros(Int32, 65_536)
                ET.s_bucket_sizes_histograma!(sizes, bitmaps, zeros(Int32, 256))
                leidos_julia, leidos_rust, coinciden = ET.leidos_julia_vs_rust(meta, retos, audita_retos, sizes)
                @test coinciden
                @test leidos_julia == leidos_rust
                @test length(leidos_julia) == size(retos, 2)
            end

            @testset "cero, uno y varios candidatos por sector" begin
                cands = Int[Int(r.candidatos) for r in audita_retos]
                @test 0 in cands        # hay slots sin ningún candidato
                @test 1 in cands        # hay slots con exactamente uno
                @test maximum(cands) >= 2  # y slots con varios
                # En SR=0 el predicado no acepta nada salvo distancia exactamente 0.
                c0 = Int[Int(r.candidatos) for r in audita_retos if UInt64(r.sr) == 0]
                @test all(==(0), c0) || length(c0) == 0
            end

            @testset "candidato ganador cuya prueba PoS falla (NO es verify_solution)" begin
                ok, cand, validas, corruptas = ET.eq_prueba_pos(prueba_meta)
                @test ok
                @test cand >= 1
                @test validas == cand
                @test corruptas == 0   # una prueba con un byte invertido NO se acepta
                # El alcance está declarado: la verificación COMPLETA sigue pendiente.
                @test !haskey(prueba_meta, "pruebas_completas_validas")
            end

            @testset "contabilidad de bytes contra la API del clon (constantes.tsv)" begin
                c = ET.leer_constantes(RES)
                @test c["num_chunks"] == Int(ET.NUM_CHUNKS)
                @test c["num_s_buckets"] == Int(ET.NUM_S_BUCKETS)
                @test c["record_size"] == Int(ET.RECORD_SIZE)
                @test c["sector_size_1000"] == Int(ET.sector_size(1000))
                @test c["sector_record_chunks_size_1000"] == 1000 * c["record_size"]
                @test c["sector_record_metadata_size_1000"] == 1000 * 128
                @test c["sector_contents_map_encoded_size_1000"] == 1000 * 8192 + 32
                @test c["sector_metadata_checksummed_size"] == Int(ET.metadata_fuera_del_sector())
                @test c["sector_size_menos_1000_piece_size"] == 8_224_064
                @test c["sector_size_1000"] - 1000 * c["piece_size"] ==
                      c["sector_size_menos_1000_piece_size"]
            end

            @testset "reproducibilidad con la misma parcela y el mismo reto" begin
                buckets = Int[Int(r.bucket) for r in audita_retos]
                @test ET.eq_determinismo(bitmaps, buckets)
            end

            @testset "la misma parcela ante dos retos divergentes" begin
                @test length(pares) > 0
                for p in pares
                    # Invariantes estructurales del solapamiento.
                    @test Int(p.chunks_comunes) <= min(Int(p.leidos_i), Int(p.leidos_j))
                    @test Int(p.cand_comunes) <= min(Int(p.cand_i), Int(p.cand_j))
                    @test Int(p.cand_i) <= Int(p.leidos_i)
                    @test Int(p.cand_j) <= Int(p.leidos_j)
                    # Dos retos distintos pueden caer en el mismo bucket, pero es raro.
                    @test Int(p.bucket_i) != Int(p.bucket_j) || Int(p.bucket_igual) == 1
                end
                # Los pares NO son observaciones independientes: se forman con
                # `retos.min(64) = 64` retos únicos y cada reto aparece en 63 pares. La unidad
                # independiente es el RETO, y así se declara. Este test fija el hecho, no un
                # veredicto basado en suponer independencia.
                n_retos_unicos = length(unique(Int[p.i for p in pares]))
                @test n_retos_unicos <= 64
                @test length(pares) > n_retos_unicos      # hay reutilización de retos
                # El solapamiento esperado bajo independencia (hipergeométrico) se publica al
                # lado del medido; el test solo comprueba que el número existe y es plausible.
                comunes = Float64[Float64(p.chunks_comunes) for p in pares]
                esperado_indep = mean(Float64[Float64(p.leidos_i) for p in pares]) *
                                 mean(Float64[Float64(p.leidos_j) for p in pares]) / M
                @test mean(comunes) >= 0
                @test 0 < esperado_indep < M
            end

            @testset "identidad exacta compartir/repartir sobre los datos reales" begin
                # Con las dos asignaciones de las mitades promediadas, la razón es 2 EXACTA.
                mitad = M ÷ 2
                s_a = zeros(Int32, 65_536)
                s_b = zeros(Int32, 65_536)
                ET.s_bucket_sizes_histograma!(s_a, bitmaps[1:mitad, :], zeros(Int32, 256))
                ET.s_bucket_sizes_histograma!(s_b, bitmaps[(mitad + 1):M, :], zeros(Int32, 256))
                for p in pares[1:min(end, 200)]
                    r = ET.reparto_exclusivo(s_a, s_b, Int(p.bucket_i), Int(p.bucket_j))
                    @test r.compartido == r.asignacion_1 + r.asignacion_2
                    @test r.promedio_mitades == r.compartido / 2   # identidad para TODO par
                    if r.compartido > 0
                        @test r.razon == 2.0 && r.definido
                    else
                        @test r.razon === nothing && !r.definido  # 0/0
                    end
                end
            end
        end
    end
end
