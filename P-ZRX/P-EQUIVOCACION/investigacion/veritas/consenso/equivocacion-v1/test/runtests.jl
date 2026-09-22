# =============================================================================
# runtests.jl — bordes, invariantes, contraejemplos y regresión
#   ./veritas/julia.sh --project=. test/runtests.jl
# =============================================================================
include(joinpath(@__DIR__, "..", "src", "Equivocacion.jl"))
using .Equivocacion
using Test, StableRNGs

const E = Equivocacion

@testset "EQUIV-v0.1" begin

    @testset "C-GD-01 peso exacto" begin
        @test peso_bloque(0) == big(2)^128          # SR = 0 (no cabe en u128; el SPEC usa u256)
        @test peso_bloque(1) == big(2)^127
        @test peso_bloque(2) == fld(big(2)^128, 3)
        @test peso_bloque(big(2)^64 - 1) == big(2)^64   # mínimo: w >= 2^64
    end

    @testset "estructura: C-HDR-05 y C-GD-04" begin
        d = Dag()
        a = agregar!(d, 10, Int[], 1)
        b = agregar!(d, 20, [a], 2)
        @test d.bloques[b].slot - d.bloques[a].slot == 10
        @test_throws ErrorException agregar!(d, 5, [b], 3)   # slot(padre) > slot(hijo)
        @test estructura_ok(d)
    end

    @testset "cota de slot a TODOS los padres (C-FLU-02)" begin
        # el padre NO seleccionado también tiene que respetar la cota
        d = Dag()
        a = agregar!(d, 0, Int[], 1)
        b = agregar!(d, 30, [a], 2)
        c = agregar!(d, 30, [a, b], 3)
        @test estructura_ok(d)
        @test_throws ErrorException agregar!(d, 20, [a, b], 4)
    end

    @testset "referencia ↔ kernel: vectores de regresión" begin
        d1, P1, A1, B1 = construir_dos_ramas(slots_comun = [0, 5, 10, 15, 25], idx_fork = 2,
            slots_publica = [28, 32, 36, 40, 44],
            slots_privada = [8, 12, 16, 20, 24, 28, 32, 36, 40],
            I_slots = 20, L = 20, S_max = 15, fusionar = :P)
        ok, disc = comparar_anclas(d1; I_slots = 20, L = 20, jmax = 4, k = 30)
        @test ok
        d2, _, _, _ = construir_dos_ramas(slots_comun = [0, 5, 10, 15], idx_fork = 2,
            slots_publica = [20, 25, 30], slots_privada = [12, 16, 20, 24, 28, 32],
            I_slots = 20, L = 20, S_max = 15, fusionar = :publica)
        ok2, _ = comparar_anclas(d2; I_slots = 20, L = 20, jmax = 3, k = 30)
        @test ok2
    end

    @testset "referencia ↔ kernel: DAGs aleatorios" begin
        for (sem, n, I, L, jm, k, casos) in ((0x5a5a, 10, 4, 8, 3, 3, 200),
                                             (0x1234, 14, 6, 12, 4, 2, 150),
                                             (0xBEEF, 18, 5, 10, 5, 1, 100))
            ok, fallo = contraste_aleatorio(StableRNG(sem), casos; n = n, I_slots = I,
                                            L = L, jmax = jm, k = k)
            @test ok
        end
    end

    @testset "P1 · el ancla cae en [T_j, T_j + S_max)" begin
        dag, P, A, B = construir_dos_ramas(slots_comun = [0, 5, 10, 15, 25], idx_fork = 2,
            slots_publica = [28, 32, 36, 40, 44],
            slots_privada = [8, 12, 16, 20, 24, 28, 32, 36, 40],
            I_slots = 20, L = 20, S_max = 15, fusionar = :P)
        ok, det = propiedad_P1(dag; I_slots = 20, L = 20, jmax = 4, k = 30, S_max = 15)
        @test ok
        @test isempty(det)
    end

    @testset "P3 · ancla compartida ⟹ κ de flujo = 1 (sobre la rejilla publicada)" begin
        vistos = 0
        distintos = 0
        for cfg in rejilla_hipotesis()
            u = Universo(npiezas = 4, nchunks = 1, npruebas = 1, rango = UInt64(0))
            r = kappa(cfg.d, cfg.A, cfg.B, cfg.P, u; I_slots = cfg.I, L = cfg.L,
                      F_slots = cfg.F, jmax = 6, k = 30, s0 = cfg.d.bloques[cfg.P].slot)
            r.slots == 0 && continue
            gana, _, _, npriv, ncom = carrera_V1(cfg)
            if !gana
                vistos += 1
                @test r.kappa_flujo == 1.0
                @test npriv <= ncom        # sin ganar la carrera, el ancla es común
            else
                distintos += 1
                @test npriv >= ncom        # P5: el escape exige no perder la carrera en V_1
            end
        end
        @test vistos > 0        # el barrido contiene controles: no es vacuo
        @test distintos > 0     # y contiene escapes
    end

    @testset "contraejemplo: la carrera A2 produce κ de flujo < 1" begin
        dag, P, A, B = construir_dos_ramas(slots_comun = [0, 5, 10, 15, 25], idx_fork = 2,
            slots_publica = collect(26:1:44),
            slots_privada = vcat(collect(9:4:25), collect(26:1:44)),
            I_slots = 20, L = 20, S_max = 15, fusionar = :P)
        @test ancla_epoca(dag, A, 20, 20, 30) != ancla_epoca(dag, B, 20, 20, 30)
        u = Universo(npiezas = 4, nchunks = 1, npruebas = 1, rango = UInt64(0))
        r = kappa(dag, A, B, P, u; I_slots = 20, L = 20, F_slots = 20, jmax = 4, k = 30,
                  s0 = dag.bloques[P].slot)
        @test r.slots > 0
        @test r.kappa_flujo < 1.0
    end

    @testset "U2/U3″ entre ramas disjuntas (CRP-v0.1 §6)" begin
        # el MISMO billete en el MISMO slot en dos ramas disjuntas (hermanas, no en la
        # ancestría una de otra): válidas por separado; al fusionar, una es rojo_U3.
        comunes = [0, 5, 10]
        pubs = [15, 20, 25]
        privs = [15, 20, 25]
        dag, P, A, B = construir_dos_ramas(slots_comun = comunes, idx_fork = 1,
            slots_publica = pubs, slots_privada = privs,
            I_slots = 20, L = 20, S_max = 15, fusionar = :publica,
            billetes_publicos = [1, 2, 7], billetes_privados = [3, 4, 7])
        @test estructura_ok(dag)                      # U2 no salta: 7 está en ramas hermanas
        v = seleccion_vista(dag, vista_epoca(dag, B, 40, 20), 30)
        @test any(==(0x03), v.color)                  # al fusionar, el billete 7 repetido es rojo_U3
        # U2 sí salta si el MISMO billete se repite en la ancestría de una rama
        dag2, _, _, _ = construir_dos_ramas(slots_comun = comunes, idx_fork = 1,
            slots_publica = pubs, slots_privada = privs,
            I_slots = 20, L = 20, S_max = 15, fusionar = :nada,
            billetes_publicos = [7, 7, 7], billetes_privados = [3, 4, 5])
        @test !estructura_ok(dag2)
    end

    @testset "identidades: C-GD-07 separa lo que IDV-01 agrupa" begin
        u = Universo(npiezas = 1, nchunks = 8, npruebas = 1, rango = typemax(UInt64))
        s1 = u.soluciones[1]; s2 = u.soluciones[2]
        @test identidad(:spec07, s1, 5, u.dominio, u.plotbatch) !=
              identidad(:spec07, s2, 5, u.dominio, u.plotbatch)
        @test identidad(:idv01, s1, 5, u.dominio, u.plotbatch) ==
              identidad(:idv01, s2, 5, u.dominio, u.plotbatch)
        @test identidad(:candidata, s1, 5, u.dominio, u.plotbatch) ==
              identidad(:candidata, s2, 5, u.dominio, u.plotbatch)
    end

    @testset "misma parcela: κ_idv01 = 1 y κ_spec07 < 1 con varios chunk ganadores" begin
        u = Universo(npiezas = 1, nchunks = 8, npruebas = 1,
                     rango = rango_para_media(8, 4.0))
        reto = UInt64(12345)
        wa = ganadores(u, reto)
        @test length(wa) >= 2
        @test evasion_posible(u, wa, wa, :spec07, 3) == true
        @test evasion_posible(u, wa, wa, :idv01, 3) == false
        @test evasion_posible(u, wa, wa, :candidata, 3) == false
    end

    @testset "P2 sobre la rejilla (comprobación de la demostración)" begin
        dag, P, A, B = construir_dos_ramas(slots_comun = [0, 5, 10, 15, 25], idx_fork = 2,
            slots_publica = [28, 32, 36, 40, 44],
            slots_privada = [8, 12, 16, 20, 24, 28, 32, 36, 40],
            I_slots = 20, L = 20, S_max = 15, fusionar = :P)
        ok, det = propiedad_P2(dag, dag.bloques[P].slot; I_slots = 20, L = 20,
                               F_slots = 20, jmax = 4, k = 30)
        @test ok
        @test isempty(det)
    end
end
