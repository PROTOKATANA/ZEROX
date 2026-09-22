using Test
using AnclaInyeccion
using StableRNGs

const AI = AnclaInyeccion

function red_pr(; n = 40, T = 60.0, seed = UInt64(0x5a5a), lambda = 1.0)
    ParametrosRed(n, 8, lambda, T, 65e-6, log(0.08), 0.7879, 15, UInt64(1000), seed)
end

@testset "ANCLA-v0.1" begin
    @testset "red: conexión, grados, latencias" begin
        g = red_erdos_renyi(StableRNG(1), 60, 8, log(0.08), 0.7879)
        @test g.n == 60
        @test all(>(0.0), g.lat)
        for u in 1:g.n
            @test Int(g.offsets[u + 1]) > Int(g.offsets[u])
        end
    end

    @testset "Δ del modelo dentro del rango medido" begin
        d = simular_red(red_pr(; n = 100, T = 200.0))
        @test count(isequal(Inf), d.llega) == 0
        ds = Float64[]
        nd99 = ceil(Int, 0.99 * d.n)
        for b in 2:d.nblo
            lleg = sort(d.llega[b, :])
            push!(ds, lleg[nd99] - d.t_crea[b])   # Δ_99
        end
        sort!(ds)
        @test ds[round(Int, 0.5 * length(ds))] < 1.0
        @test ds[round(Int, 0.99 * length(ds))] < 2.5
    end

    @testset "determinismo por semilla" begin
        d1 = simular_red(red_pr(; T = 40.0, seed = UInt64(7)))
        d2 = simular_red(red_pr(; T = 40.0, seed = UInt64(7)))
        d3 = simular_red(red_pr(; T = 40.0, seed = UInt64(8)))
        @test d1.padres == d2.padres
        @test d1.llega == d2.llega
        @test d1.padres != d3.padres
    end

    @testset "GDR-v0.2: oráculo == kernel sobre una vista de la red" begin
        d = simular_red(red_pr(; n = 30, T = 80.0))
        params = P_DEFECTO
        # vista completa en orden de creación
        especs = BloqueEspec[BloqueEspec(d.ids[1]; padres = Int[], slot = 0, sr = 1000)]
        for b in 2:d.nblo
            push!(especs, BloqueEspec(d.ids[b]; padres = d.padres[b], slot = d.slot[b],
                                     sd = d.sd[b], sr = d.sr[b]))
        end
        est_ref = EstadoReferencia(params, d.ids[1]; slot_g = d.slot[1], sr_g = d.sr[1])
        construir(est_ref, params, especs[2:end])
        est_rap = EstadoRapido(params, d.ids[1]; slot_g = d.slot[1], sr_g = d.sr[1])
        for e in especs[2:end]
            anadir!(est_rap, params, e.id, e.padres, e.slot, e.sd, e.sr, e.ident)
        end
        @test equivalencia(est_ref, est_rap, params)
    end

    @testset "mapeo local→global (defecto 1 corregido)" begin
        d = simular_red(red_pr(; n = 30, T = 60.0))
        params = P_DEFECTO
        # EstadoObs con todos los bloques en orden de creación
        eo = AI.nuevo_EstadoObs(1, params, d)
        eo.orden = collect(2:d.nblo)
        for b in eo.orden
            @test AI.puede_añadir(eo, d, b)
            AI.insertar!(eo, d, params, b)
        end
        cglob = AI.cadena_global(eo, cadena_seleccionada(eo.est, virtual_sp(eo.est, params)))
        # referencia directa (índice local == global en orden de creación)
        ref = EstadoRapido(params, d.ids[1]; slot_g = d.slot[1], sr_g = d.sr[1])
        for b in 2:d.nblo
            anadir!(ref, params, d.ids[b], Int[p for p in d.padres[b]], d.slot[b], d.sd[b],
                    d.sr[b], UInt64(0))
        end
        cref = cadena_seleccionada(ref, virtual_sp(ref, params))
        @test cglob == cref
    end

    @testset "la curva es no creciente en su primer tramo" begin
        d = simular_red(red_pr(; n = 60, T = 200.0))
        acc = medir_transitorio(d, P_DEFECTO, collect(1:60), 200.0, 1.0, 4)
        filas = curva_pooled(acc)
        p = Dict(f.D => f.p_dis for f in filas)
        # D=0 debe ser ≥ que D=1 en expectativa del modelo; comprobación laxa anti-regresión
        @test get(p, 0, 0.0) >= get(p, 1, 0.0)
    end
end
