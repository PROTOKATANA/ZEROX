# ─────────────────────────────────────────────────────────────────────────────
# test/runtests.jl — regresión de la auditoría P-SEGUNDO-VDF.
#   JULIA_DEPOT_PATH="/tmp/segundo-vdf-julia-depot:$HOME/.julia" \
#     ../../../veritas/julia.sh --project=. --threads=4,0 test/runtests.jl
# ─────────────────────────────────────────────────────────────────────────────
using Test
using SegundoVdfV1
using StableRNGs, Statistics

@testset "P-SEGUNDO-VDF" begin
    @testset "1 · control externo (filas publicadas REV-v1.0 / ADL-v1.0)" begin
        for f in control_filas_publicadas()
            @test f.max_dif < 0.05
        end
    end

    @testset "2 · oráculo max-plus exacto vs kernel" begin
        e = equivalencia_oraculo()
        @test e.casos == 384
        @test e.peor == 0                       # igualdad exacta en Rational{BigInt}
    end

    @testset "3 · cuantil exacto vs muestreo denso" begin
        q = equivalencia_cuantil()
        @test q.dif < 0.01
    end

    @testset "4 · defecto 1: calibración (h.6) corregida" begin
        c = control_historico_h6()
        @test c.W_dec_slots == 20
        @test c.Lrev == 7050
        @test c.frontera_corregida == 14000 // 3          # (7050 − 50)/1,5
        @test c.I_corregida == 4666
        @test c.I_historica_entera == 4766
        @test c.I_historica_redondeada == 4767
        # la fila histórica NO cumple su propio criterio
        @test !c.cumple_historica
        @test c.rho_estrella_historica_redondeada < 5 // 2
        # la frontera corregida sí
        @test c.cumple_corregida
        @test c.rho_estrella_corregida >= 5 // 2
        @test c.deficit_slots == 100                       # S_max/(ρ_max−1)
        @test c.I_minima == 151                            # máx(ρ_max·W_dec, S_max+1)
        @test c.holgura_puntualidad == 125.0               # L − W_dec − D − 1 − Lrev
        @test rho_max_cota_sqrt(7050.0, 20.0) ≈ 18.7749 atol = 1e-3
        @test rho_max_factible_entero(7050, 20, 150) == (rho = 3713 // 198, I = 376)
        # sensibilidad: por encima de √(Lrev/W_dec) el intervalo factible se vacía
        @test !tabla_calibracion(rhos = (19.0,))[1].admisible
        @test tabla_calibracion(rhos = (18.0,))[1].admisible
    end

    @testset "5 · defecto 2: escenarios consistentes" begin
        filas = tabla_escenarios_consistente(J = 400, R = 8, Is = (851.0, 4666.0))
        @test length(filas) == 2
        for f in filas
            @test 0.0 < f.dV_rel < 1.0
            @test f.cumple_rho                       # en las dos, ρ* ≥ ρ_max declarado
            @test f.lineas == lineas_timekeeper(7200.0, f.I)
        end
        # la fila consistente con I corregido cuesta menos líneas que la de I=851
        @test filas[2].lineas < filas[1].lineas
    end

    @testset "6 · defecto 3: las dos semillas dan la misma ventana" begin
        for f in tabla_semilla(J = 600, R = 16, Is = (851.0,))
            @test f.dif_entre_semillas == 0.0        # el modelo no las distingue
        end
        d = datos_causales_semilla()
        @test length(d) == 2
        @test occursin("pot_output", d[1].ingrediente)
        @test occursin("slot(I_j)", d[2].ingrediente)
    end

    @testset "7 · defecto 4: estados y mapa de reglas" begin
        @test transicion_estado_pot(:Pendiente, :presupuesto_agotado) === :Pendiente
        @test transicion_estado_pot(:Valido, :presupuesto_agotado) === :Pendiente
        @test transicion_estado_pot(:Pendiente, :aes_falla) === :Invalido
        @test transicion_estado_pot(:Pendiente, :n_fuera_dominio) === :Pendiente
        @test transicion_estado_pot(:Pendiente, :verificacion_exitosa) === :Valido
        @test_throws ErrorException transicion_estado_pot(:Valido, :evento_inventado)
        mapa = mapa_reglas_vdf()
        ids = [f.id for f in mapa]
        @test "C-FLU-12" in ids
        @test length(ids) >= 22                  # no basta cambiar C-FLU-12
        @test length(unique(ids)) == length(ids)
    end

    @testset "8 · defecto 5: la cadena larga no es expresable" begin
        s = segmentacion_zxpot(7050.0, Float64(N_SLOT_NOMINAL))
        @test !s.una_llamada
        @test s.estado === :pendiente
        @test !s.segmentar_por_slots
        @test Lrev_max_una_llamada(Float64(N_SLOT_NOMINAL)) == 20
        @test segmentacion_zxpot(8.0, 16.0).una_llamada       # caso expresable
    end

    @testset "9 · controles independientes (§3)" begin
        for c in controles_independientes(J = 800)
            @test c.ok
        end
    end

    @testset "10 · determinismo y ausencia de carreras" begin
        cfg = cfg_base(I = 851.0, con_h = true)
        r1 = barrido(cfg, [2.0, 2.5], 800, 16, UInt64(0x5a5a), 400, 64.0, 0.0, 0.33;
                     nthreads = 1)
        r2 = barrido(cfg, [2.0, 2.5], 800, 16, UInt64(0x5a5a), 400, 64.0, 0.0, 0.33;
                     nthreads = Threads.nthreads(:default))
        @test r1.vmax == r2.vmax
        @test r1.hist == r2.hist
        if Threads.nthreads(:default) > 2
            @test_throws ArgumentError barrido(cfg, [2.0], 10, 2, UInt64(0x5a5a),
                                               10, 64.0, 0.0, 0.33; nthreads = 2)
        end
    end

    @testset "11 · invariantes de puntualidad" begin
        c = control_historico_h6()
        @test c.holgura_puntualidad >= 0          # Lrev = L − S_max es puntual
        @test holgura_puntualidad(7200.0, 20.0, 4.0, 7200.0) < 0   # Lrev = L no lo es
    end

    @testset "12 · latencia causal, líneas y semilla" begin
        for futura in (true, false), patron in (:ajenas, :propias, :mixtas)
            cfg = cfg_base(I = 4666.0, con_h = true, semilla_futura = futura,
                           revelacion_paralela = true, lineas_revelacion = 2)
            J = 6; off = zeros(Float64, J)
            propias = patron === :ajenas ? falses(J) :
                      patron === :propias ? trues(J) : BitVector([false,true,false,true,false,true])
            tr = Tray{Float64}(J); eventos = NamedTuple[]
            construir!(tr, cfg, off, propias, 2.5, J; traza = eventos)
            @test length(eventos) == J
            for e in eventos
                @test 1 <= e.linea <= 2
                @test e.inicio >= e.semilla_completa
                @test e.fin - e.inicio ≈ 7050 / 2.5
                @test e.barrera >= max(e.decision, e.fin)
            end
            for linea in 1:2
                de_linea = filter(e -> e.linea == linea, eventos)
                @test all(de_linea[k].fin <= de_linea[k+1].inicio for k in 1:length(de_linea)-1)
            end
        end
        f = tabla_regimenes(J = 400, Is = (4666.0,))[1]
        @test f.V_paralelo < f.V_sin
        @test f.V_ideal == f.V_sin
        # Una decisión temprana no permite usar un chunk recibido tarde.
        cfg_tarde = cfg_base(I = 4666.0, con_h = true, revelacion_paralela = true,
                             lineas_revelacion = 2)
        tr_tarde = Tray{Float64}(1); evt_tarde = NamedTuple[]
        construir!(tr_tarde, cfg_tarde, [0.0], falses(1), 2.5, 1;
                   traza = evt_tarde, chunk_conocido = [8000.0],
                   bloque_recibido = [7000.0], flujo_previo_conocido = [100.0],
                   ancla_decidida = [4700.0])
        @test evt_tarde[1].semilla_completa == 8000.0
        @test evt_tarde[1].inicio == 8000.0
        @test evt_tarde[1].fin == 10820.0
        cfg_ideal = cfg_base(I = 4666.0, con_h = true, revelacion_instantanea = true)
        evt_ideal = NamedTuple[]
        construir!(Tray{Float64}(1), cfg_ideal, [0.0], falses(1), 2.5, 1;
                   traza = evt_ideal, chunk_conocido = [8000.0],
                   ancla_decidida = [4700.0])
        @test evt_ideal[1].barrera == 8000.0 # instantáneo al conocer toda la semilla
        cfg = cfg_base(I = 851.0, con_h = true)
        a = barrido(cfg, [2.5], 100, 8, UInt64(0x5a5a), 400, 64.0, 0.0, 0.33)
        b = barrido(cfg, [2.5], 100, 8, UInt64(0x5a5a), 400, 64.0, 0.0, 0.33)
        c = barrido(cfg, [2.5], 100, 8, UInt64(0x5a5b), 400, 64.0, 0.0, 0.33)
        @test a.vmax == b.vmax && a.hist == b.hist
        @test a.vmax != c.vmax || a.hist != c.hist
    end
end
