#= runtests.jl — validación de `eclipse-red-v1`.
Ejecutar con:
    JULIA_DEPOT_PATH=<depot> /home/katana/zeo/ZEROX/veritas/julia.sh --check-bounds=yes --project=. test/runtests.jl

Qué se comprueba, y por qué cada cosa (LINEO §2 y §10: la referencia y el kernel deben coincidir
en el dominio que la referencia alcanza; los umbrales deben tener comprobación rigurosa).

Las etiquetas `verificado` del INFORME se apoyan en estos tests. En particular el CONTROL POSITIVO
de D8 A3b se comprueba a cuatro decimales **y con su número de bloques**, que es lo que distingue
un puerto fiel de una coincidencia estadística.
=#

using Test

const AQUI = @__DIR__
include(joinpath(AQUI, "..", "src", "pyrng.jl"))
include(joinpath(AQUI, "..", "src", "GDR.jl"))
include(joinpath(AQUI, "..", "src", "mundo.jl"))
include(joinpath(AQUI, "..", "src", "sensores.jl"))
include(joinpath(AQUI, "..", "src", "captura.jl"))
include(joinpath(AQUI, "..", "src", "flujo.jl"))
using .PyRNG, .Mundo, .Sensores, .Captura, .Flujo
const G = GDR.GhostdagRank

@testset "eclipse-red-v1" begin

    # -----------------------------------------------------------------------------------
    @testset "pyrng: réplica de CPython" begin
        # Vector publicado del MT19937 de referencia (init_genrand(5489)). Valida twist y
        # tempering, que es el 95 % del generador.
        ref = UInt32[3499211612, 581869302, 3890346734, 3586334585, 545404204,
                     4161255391, 3922919429, 949333985, 2715962298, 1323567403]
        r = PyRNG.PyRandom()
        PyRNG.init_genrand!(r, UInt32(5489))
        @test [PyRNG.genrand_uint32!(r) for _ in 1:10] == ref

        # Valores publicados de `random.Random(int).random()` (camino init_by_array de CPython,
        # que es el que usa el instrumento heredado con semilla entera).
        @test PyRNG.random(PyRNG.PyRandom(0)) == 0.8444218515250481
        @test PyRNG.random(PyRNG.PyRandom(1)) == 0.13436424411240122
        @test PyRNG.random(PyRNG.PyRandom(42)) == 0.6394267984578837

        # El sembrado por cadena es determinista y separa semillas.
        @test PyRNG.random(PyRNG.PyRandom("1|900.0|0.0|200.0|0.05")) ==
              PyRNG.random(PyRNG.PyRandom("1|900.0|0.0|200.0|0.05"))
        @test PyRNG.random(PyRNG.PyRandom("1|900.0|0.0|200.0|0.05")) !=
              PyRNG.random(PyRNG.PyRandom("2|900.0|0.0|200.0|0.05"))

        # `py_str` debe reproducir el `repr` de Python en el dominio que este encargo usa.
        @test Mundo.py_str(900.0) == "900.0"
        @test Mundo.py_str(0.0) == "0.0"
        @test Mundo.py_str(0.05) == "0.05"
        @test Mundo.py_str(0.25) == "0.25"
        @test Mundo.py_str(0.33) == "0.33"
        @test Mundo.py_str(200.0) == "200.0"
    end

    # -----------------------------------------------------------------------------------
    @testset "GDR-v0.2: la identidad SR=0 <-> peso por conteo" begin
        # Es lo que permite reutilizar el motor de GDR para el régimen histórico sin
        # reimplementar GHOSTDAG. Si esto falla, la reutilización declarada en GDR.jl es falsa.
        p = ParametrosMundo(0.0, 900.0, 1)
        sim = Sim(p, calendario(0.0, 900.0, 1))
        corre_control!(sim, 200.0; fc = 0.05)
        @test sim.est.n > 100
        for i in 1:sim.est.n
            @test BigInt(sim.est.gd[i].bw) == big(2)^128 * BigInt(sim.est.gd[i].blue_score)
        end
        # El peso por SR sí se separa del conteo cuando SR ≠ 0.
        @test G.peso_big(UInt64(0)) == big(2)^128
        @test G.peso_big(UInt64(1)) == big(2)^127
    end

    # -----------------------------------------------------------------------------------
    @testset "CONTROL POSITIVO D8 A3b" begin
        # La fila publicada en research/scripts/d8-ronda8/salida_a3b.txt (E=200 s, f=5 %).
        # Se comprueba a 4 decimales Y el número de bloques: un puerto infiel puede acertar
        # los promedios por casualidad, pero no el conteo.
        SMAXES = [4, 20, 30, 150]
        esperado = Dict(0.0 => ([0.8218, 0.6513, 0.5920, 0.5460], 522),
                        0.25 => ([0.8806, 0.7687, 0.7289, 0.6816], 402))
        for alpha in (0.0, 0.25)
            tot = zeros(Int, length(SMAXES)); n = 0
            for sem in 1:12
                pw = ParametrosMundo(alpha, 900.0, sem)
                rr = corre_control!(Sim(pw, calendario(alpha, 900.0, sem)), 200.0; fc = 0.05)
                n += rr.n
                for (j, S) in enumerate(SMAXES)
                    tot[j] += count(>(S), rr.gaps)
                end
            end
            v = tot ./ max(n, 1)
            esp, en = esperado[alpha]
            for j in 1:length(SMAXES)
                @test round(v[j], digits = 4) == esp[j]
            end
            @test n == en
        end
    end

    # -----------------------------------------------------------------------------------
    @testset "variantes (ii) y (iii): filas publicadas de 11b" begin
        # (modo, paso, E) -> (inv S=4/20/30/150, rojo_V, n) publicados en 11b §A.2-A.3.
        SMAXES = [4, 20, 30, 150]
        casos = [(:filtro, 0.0, 0.0, [0.7927, 0.3109, 0.1762, 0.0000], 1.0000, 193),
                 (:filtro, 0.33, 0.0, [0.7070, 0.0047, 0.0000, 0.0000], 0.0093, 215),
                 (:retraso, 1.0, 20.0, [0.7753, 0.7022, 0.0056, 0.0000], 0.0449, 178),
                 (:retraso, 1.0, 60.0, [0.7600, 0.6743, 0.6743, 0.0000], 1.0000, 175),
                 (:retraso, 1.0, 200.0, [0.8167, 0.7500, 0.7500, 0.7500], 1.0000, 180)]
        for (modo, paso, E, esp_inv, esp_rojo, esp_n) in casos
            acc = zeros(Int, 4); nvr = 0; nrojo = 0; ntot = 0
            for sem in 1:12
                pw = ParametrosMundo(0.0, 900.0, sem)
                sim = Sim(pw, calendario(0.0, 900.0, sem))
                rr = corre_victima!(sim, modo, 0.05; paso = paso, E = E, t_ecl = 300.0)
                az = G.blueset(sim.est, G.virtual_sp(sim.est, sim.params))
                for (t, gp, bid) in zip(rr.t_V, rr.gaps_V, rr.ids_V)
                    t >= 600.0 || continue
                    nvr += 1; ntot += 1
                    bid in az || (nrojo += 1)
                    for (j, S) in enumerate(SMAXES)
                        gp > S && (acc[j] += 1)
                    end
                end
            end
            @test nvr == esp_n
            for j in 1:4
                @test round(acc[j] / max(nvr, 1), digits = 4) == esp_inv[j]
            end
            @test round(nrojo / max(ntot, 1), digits = 4) == esp_rojo
        end
    end

    # -----------------------------------------------------------------------------------
    @testset "variante (i): sin PoT no hay bloque" begin
        for f_v in (0.01, 0.05, 0.20)
            post = 0
            for sem in 1:12
                pw = ParametrosMundo(0.0, 900.0, sem)
                rr = corre_victima!(Sim(pw, calendario(0.0, 900.0, sem)), :pot, f_v;
                                    t_ecl = 300.0)
                post += count(>=(300.0), rr.t_V)
            end
            @test post == 0
        end
    end

    # -----------------------------------------------------------------------------------
    @testset "sensores: Poisson exacto contra lo publicado en 11b" begin
        # §C.1: el umbral n_min con menos de 1 falsa alarma al año.
        @test Sensores.n_min(30) == 6
        @test Sensores.n_min(60) == 23
        @test Sensores.n_min(120) == 66
        @test Sensores.n_min(300) == 211
        # §C.5: α mínima para evadir W=300 durante T=2 h, publicado 0,9249.
        @test round(Sensores.alpha_min(300, 211, 7200.0), digits = 4) == 0.9249
        # La suma de Poisson es exacta: P(N ≤ 0) = e^{−μ}, y el cociente P(N≤1)/P(N≤0) = 1+μ.
        mu = Rational{BigInt}(7, 2)
        p0 = Sensores.poisson_cdf_big(0, mu)
        p1 = Sensores.poisson_cdf_big(1, mu)
        @test abs(Float64(p1 / p0) - (1 + Float64(mu))) < 1e-12
        # CDF normal sin `erf` (no está en Base): comprobación contra valores conocidos.
        @test abs(Float64(Sensores._cdf_normal(BigFloat(0))) - 0.5) < 1e-15
        @test abs(Float64(Sensores._cdf_normal(BigFloat("1.96"))) - 0.9750021048517795) < 1e-14
        @test abs(Float64(Sensores._cdf_normal(BigFloat(1)) +
                          Sensores._cdf_normal(BigFloat(-1))) - 1.0) < 1e-15
        # IDENTIDAD POR CONSTRUCCIÓN: con mediana=4 y p99=8, P(D>8) tiene que ser 0,01 exacto.
        # Es el control que cazó el primer intento de CDF (daba 0,004516).
        @test abs(Float64(1 - Sensores.cdf_lognormal(8.0, 4.0, 8.0)) - 0.01) < 1e-12
        # Y lo mismo para la Pareto: p99 = 8 significa P(D>8) = 0,01.
        @test abs(Float64(1 - Sensores.cdf_pareto(8.0, 4.0, 8.0)) - 0.01) < 1e-12
        # B de la Pareto (columna «por excursión»), publicado 76,40 en 11b §B.1.
        @test abs(Sensores.B_paro(4.0, 8.0; eps = 1.0, cdf = Sensores.cdf_pareto,
                                  por_slot = false) - 76.40) < 0.01
        # Y la cola secuencial debe ser estrictamente más pesada que la marginal (11b §B.0).
        @test Float64(Sensores.cola_frontera(8.0, Sensores.cdf_lognormal;
                                            mediana = 4.0, p99 = 8.0)) >
              Float64(1 - Sensores.cdf_lognormal(8.0, 4.0, 8.0))
    end

    # -----------------------------------------------------------------------------------
    @testset "captura: hipergeométrico exacto" begin
        # Monotonía estricta en s, y techo 1 cuando el atacante controla todos los grupos.
        @test Captura.p_captura(0, 2, 100, 8) == 0
        @test Captura.p_captura(100, 2, 100, 8) == 1
        @test Captura.p_captura(50, 2, 100, 8) > Captura.p_captura(49, 2, 100, 8)
        # Con muchas direcciones por grupo el producto hipergeométrico tiende a (s/G)^ω.
        # La tolerancia es 1e-5 porque la corrección por muestreo sin reemplazo es O(ω²/N).
        p = Float64(Captura.p_captura(90, 10_000, 100, 8))
        @test abs(p - 0.9^8) < 1e-5
        # Identidades, mejor que constantes escritas a mano: f(p,ω)^ω = p.
        for om in (8, 10, 24), pp in (0.5, 0.9)
            @test abs(Captura.fraccion_grupos(pp, om)^om - pp) < 1e-12
        end
        @test Captura.fraccion_grupos(0.5, 24) > Captura.fraccion_grupos(0.5, 8)
    end

    # -----------------------------------------------------------------------------------
    @testset "flujo: aritmética de C-FLU-01/22 y C-FIN-01" begin
        # C-FLU-01: L_slots es una definición con tres términos.
        @test Flujo.L_slots(7200, 0, 150) == 7200
        @test Flujo.L_slots(100, 5000, 150) == 5000
        @test Flujo.L_slots(100, 0, 150) == 151
        # Umbral de s₀ para ventana vacía y duración mínima del eclipse.
        for F in (1000, 7200, 20000), L in (F, 2F, F + 500)
            s0 = Flujo.s0_max_ventana_vacia(0, F, L)
            @test Flujo.E_min(0, F, L) == F          # E_min = F_slots, independiente de L
            # La ventana está vacía justo cuando t_j ≥ s0 + F.
            t_j = 0 + L
            @test t_j >= s0 + F
            @test !(t_j >= (s0 + 1) + F)
        end
        # C-FIN-01: la igualdad d = F_slots cae DENTRO de lo prohibido (D-F4 = A).
        @test !Flujo.puede_volver(7200, 7200)
        @test Flujo.puede_volver(7199, 7200)
        # Cota inferior de PRESUP_NODO: F_slots × 92 ms.
        inf, _ = Flujo.presupuesto_pinza(7200)
        @test inf == 7200 * 92.0
        @test abs(inf / 60000 - 11.04) < 0.01        # el «≈11 min» del SPEC
    end
end
