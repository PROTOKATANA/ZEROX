# ─────────────────────────────────────────────────────────────────────────────
# runtests.jl — REV-v1.0
#
# Ningún test compara una fórmula con su propia transcripción: el kernel se contrasta con el
# ORÁCULO por slot (exacto, Rational{BigInt}) y con las formas cerradas EXTERNAS de 9c / ronda 7 /
# ronda 10a / ADL-v1.0.
# ─────────────────────────────────────────────────────────────────────────────
using Test
using RevelacionV1
using StableRNGs

const RV = RevelacionV1

# modelo.jl de ADL-v1.0 (lectura; no se modifica)
const RAIZ = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "..", ".."))
const ADL_MODELO = joinpath(RAIZ, "P-ADELANTO", "investigacion", "veritas", "seguridad",
                            "adelanto-v1", "src", "modelo.jl")
module AdlRef end
const HAY_ADL = isfile(ADL_MODELO)
HAY_ADL && Base.include(AdlRef, ADL_MODELO)

@testset "REV-v1.0" begin

    @testset "1 · equivalencia kernel↔oráculo por slot (exacta, Rational{BigInt})" begin
        for (nc, sd, J) in ((80, UInt64(0x5a5a), 4), (60, UInt64(0xbeef), 7),
                            (80, UInt64(0xabcd), 6), (60, UInt64(0x99), 3))
            o = comparar_con_oraculo(ncasos = nc, seed = sd, J = J)
            @test o[4] == 0            # cero discrepancias
            @test o[1] == 0.0          # maxdiff vmax
            @test o[2] == 0.0          # maxdiff vmin
        end
    end

    @testset "2 · bordes e invariantes" begin
        # ρ = 1 ⇒ V ≡ 0 (nadie se adelanta)
        cfg1 = Config{Float64}(; L = 1000.0, I = 100.0, W_dec = 5.0, D = 2.0, S_max = 10.0,
                               Lrev = 900.0, con_h = true, cruce = true, lead_h = 2.0, j_ini = 0)
        b = Buffers{Float64}(40, 64)
        off = zeros(41); propia = fill(false, 41)
        m = simular_replica!(b, cfg1, off, propia, 1.0, 40, 1.0, -8.0, 0.0)
        @test m.vmax == 0.0 && m.vmin == 0.0

        # C-FLU-09: t_j estrictamente crecientes cuando S_max < I
        cfg2 = Config{Float64}(; L = 500.0, I = 100.0, W_dec = 5.0, D = 1.0, S_max = 10.0,
                               Lrev = 400.0, con_h = true, cruce = true, lead_h = 1.0, j_ini = 0)
        rng = StableRNG(UInt64(1))
        off2 = Vector{Float64}(undef, 50); propia2 = Vector{Bool}(undef, 50)
        sortear_offsets!(rng, off2, propia2, cfg2, 49, 0.3)
        for j in 1:48
            @test j * cfg2.I + off2[j] + cfg2.L < (j + 1) * cfg2.I + off2[j+1] + cfg2.L
        end

        # puntualidad: Lrev ≤ L − W_dec − lead_h ⇒ sin estancamientos del honesto
        cfg3 = Config{Float64}(; L = 1000.0, I = 200.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                               Lrev = 1000.0 - 20.0 - 4.0 - 1.0, con_h = true, cruce = true,
                               lead_h = 4.0, j_ini = 0)
        @test puntualidad_estricta(cfg3.L, cfg3.W_dec, cfg3.Lrev, cfg3.lead_h, cfg3.S_max)
        m3 = simular_replica!(Buffers{Float64}(30, 64), cfg3, zeros(31), fill(false, 31), 2.0,
                              30, 1.0, -8.0, 0.0)
        @test m3.n_stall_h == 0

        # y con Lrev > L − W_dec − D el honesto SÍ se estanca: la invariante detecta la violación
        cfg4 = Config{Float64}(; L = 1000.0, I = 200.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                               Lrev = 1000.0, con_h = true, cruce = true, lead_h = 4.0, j_ini = 0)
        m4 = simular_replica!(Buffers{Float64}(30, 64), cfg4, zeros(31), fill(false, 31), 2.0,
                              30, 1.0, -8.0, 0.0)
        @test m4.n_stall_h > 0
    end

    @testset "3 · CONTROL C1 (9c §E.1): tope y bootstrap" begin
        L, I = 19080.0, 4200.0
        @test L + I - 150.0 == 23130.0                      # cifra publicada
        rhos = [1.01, 1.05, 1.5, 3.0]
        cfg = Config{Float64}(; L = L, I = I, W_dec = 0.0, D = 0.0, S_max = 0.0, Lrev = L,
                              con_h = false, espera = false, cruce = false, lead_h = 0.0, j_ini = 0)
        r = barrer!(cfg; rhos = rhos, n_rep = 1, J = 1500, alpha = 0.0, seed = UInt64(0x5a5a),
                    nb = 2048, bin = 64.0, v_lo = -1024.0, boot_ref = 0.9 * L, modo_off = :cero)
        for i in eachindex(rhos)
            cerrado = L + I * (1 - 1 / rhos[i])             # ronda 7
            @test isapprox(r.vbar[i, 1], cerrado; rtol = 1e-9)                    # razón 1,000 exacta
        end
        # bootstrap físico (cruce con coste) frente a 0,9L/(ρ−1)
        cfgf = Config{Float64}(; L = L, I = I, W_dec = 0.0, D = 0.0, S_max = 0.0, Lrev = L,
                               con_h = false, espera = false, cruce = true, lead_h = 0.0, j_ini = 0)
        rf = barrer!(cfgf; rhos = [1.01], n_rep = 1, J = 1500, alpha = 0.0, seed = UInt64(0x5a5a),
                     nb = 2048, bin = 64.0, v_lo = -1024.0, boot_ref = 0.9 * L, modo_off = :cero)
        @test 0.99 < rf.boot[1, 1] / (0.9 * L / 0.01) < 1.02   # 9c midió 1,000
    end

    @testset "4 · CONTROL C2 (ronda 7): las dos formas, razón 1,000" begin
        for (L, I) in ((7200.0, 851.0), (3600.0, 851.0), (19080.0, 4200.0))
            rhos = [1.05, 1.2, 1.5, 2.0, 3.0]
            for con_h in (false, true)
                cfg = Config{Float64}(; L = L, I = I, W_dec = 0.0, D = 0.0, S_max = 0.0, Lrev = L,
                                      con_h = con_h, espera = false, cruce = false, lead_h = 0.0,
                                      j_ini = 0)
                r = barrer!(cfg; rhos = rhos, n_rep = 1, J = 1500, alpha = 0.0, seed = UInt64(1),
                            nb = 2048, bin = 16.0, v_lo = -1024.0, boot_ref = 0.0, modo_off = :cero)
                for i in eachindex(rhos)
                    cerrado = con_h ? (L + I) * (1 - 1 / rhos[i]) : L + I * (1 - 1 / rhos[i])
                    @test isapprox(r.vbar[i, 1], cerrado; rtol = 1e-9)
                end
            end
        end
    end

    @testset "5 · CONTROL C3 (9c E1): ρ ≤ 1 ⇒ steering 0" begin
        cfg = Config{Float64}(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 0.0, S_max = 150.0,
                              Lrev = 7200.0, con_h = false, espera = false, cruce = false,
                              lead_h = 0.0, j_ini = 200)
        r = barrer!(cfg; rhos = [1.0, 1.001, 1.01, 1.05, 2.0], n_rep = 24, J = 1400, alpha = 0.33,
                    seed = UInt64(0x5a5a), nb = 4096, bin = 32.0, v_lo = -1024.0, boot_ref = 0.0,
                    modo_off = :geom)
        f(i) = sum(r.n_pro[i, :]) / sum(r.n_ep[i, :])
        @test f(1) == 0.0                     # ρ = 1 exacto
        @test f(2) == 0.0                     # ρ = 1,001 con horizonte finito
        @test f(3) > 0.3                      # ρ = 1,01 ya hace steering
        @test f(5) > 0.9                      # ρ = 2 sistemático
    end

    @testset "6 · CONTROL ρ* (ronda 10a): umbral cerrado (Lrev+I)/(I+W_dec)" begin
        for (L, W, Lrev, publicado) in ((7200.0, 20.0, 7200.0, 9.24), (7200.0, 45.0, 7200.0, 8.99))
            # la forma cerrada reproduce lo publicado con error < 1 %
            @test abs(rho_estrella_10a(L, 851.0, W, Lrev) - publicado) / publicado < 0.01
        end
        # el ρ* simulado queda por ENCIMA del cerrado (el cerrado es optimista con off > 0)
        cfg = Config{Float64}(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 0.0, S_max = 150.0,
                              Lrev = 7200.0, con_h = true, espera = false, cruce = false,
                              lead_h = 0.0, j_ini = 200)
        frac(rho) = (b = barrer!(cfg; rhos = [rho], n_rep = 32, J = 1400, alpha = 0.33,
                                 seed = UInt64(0x5a5a), nb = 4096, bin = 32.0, v_lo = -1024.0,
                                 boot_ref = 0.0, modo_off = :geom);
                     sum(b.n_pro[1, :]) / sum(b.n_ep[1, :]))
        @test frac(9.243) < 0.5               # por debajo del cerrado NO hay steering mayoritario
        @test frac(10.0) > 0.9                # por encima, sí
    end

    @testset "7 · CONTROL rachas: tasa α^(n*−1)" begin
        @test n_rachas(7200.0, 851.0, 2.5, 20.0) == 6
        @test n_rachas(7200.0, 851.0, 3.0, 20.0) == 5
        @test isapprox(tasa_rachas(7200.0, 851.0, 2.5, 0.33, 20.0), 3.9135e-3, rtol = 1e-3)
        @test isapprox(tasa_rachas(7200.0, 851.0, 3.0, 0.33, 20.0), 1.1859e-2, rtol = 1e-3)
        # medido: ρ = 3, α = 0.33, 48 réplicas × 2000 épocas
        cfg = Config{Float64}(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 0.0, S_max = 150.0,
                              Lrev = 7200.0, con_h = true, espera = false, cruce = false,
                              lead_h = 0.0, j_ini = 0)
        r = barrer!(cfg; rhos = [3.0], n_rep = 48, J = 2000, alpha = 0.33, seed = UInt64(0x5a5a),
                    nb = 4096, bin = 32.0, v_lo = -1024.0, boot_ref = 0.0, modo_off = :unif)
        k = sum(r.n_pro[1, :]); nn = sum(r.n_ep[1, :])
        tc = tasa_rachas(7200.0, 851.0, 3.0, 0.33, 20.0)
        @test 0.6 < (k / nn) / tc < 1.6       # dentro de la banda de conteo
    end

    @testset "8 · ADL-v1.0: A_core es el máximo exacto y A_frontera su envolvente ρ→∞" begin
        @test HAY_ADL
        L, I, W, D = 7200.0, 851.0, 20.0, 4.0
        rhos = [2.0, 3.0, 9.0, 100.0]
        cfg = Config{Float64}(; L = L, I = I, W_dec = W, D = D, S_max = 150.0, Lrev = L,
                              con_h = false, espera = true, cruce = true, lead_h = 0.0, j_ini = 0)
        r0 = barrer!(cfg; rhos = rhos, n_rep = 1, J = 1400, alpha = 0.0, seed = UInt64(1),
                     nb = 4096, bin = 16.0, v_lo = -1024.0, boot_ref = 0.0, modo_off = :cero)
        for i in eachindex(rhos)
            # estacionario: V_max simulada SIN D == A_core, al decimal
            @test isapprox(r0.vmax[i, 1], a_core_semv1(rhos[i], L, I, W); rtol = 1e-9)
            # A_frontera de ADL sobreestima para ρ finito
            af = AdlRef.adelanto_frontera(rhos[i], L, I, W, D, 1.0e6)
            @test af >= r0.vmax[i, 1] - 1.0
        end
        # y el tope de ADL es el límite ρ→∞ de A_core−D (convención discreta ±1)
        @test abs(AdlRef.adelanto_frontera_inf(L, I, W, D) - (a_core_semv1(1.0e9, L, I, W) - D)) <= 2.0
    end

    @testset "9 · (h): V NO se anula por debajo de ρ*" begin
        L, I, W, D, Smax = 7200.0, 851.0, 20.0, 4.0, 150.0
        cfg = Config{Float64}(; L = L, I = I, W_dec = W, D = D, S_max = Smax, Lrev = L,
                              con_h = true, espera = true, cruce = true, lead_h = D, j_ini = 0)
        r = barrer!(cfg; rhos = [2.5], n_rep = 1, J = 1500, alpha = 0.0, seed = UInt64(1),
                    nb = 4096, bin = 16.0, v_lo = -1024.0, boot_ref = 0.0, modo_off = :cero)
        # la forma de la ronda 7 con (h), exacta, y muy lejos de 0
        @test isapprox(r.vmax[1, 1], (L + I) * (1 - 1 / 2.5); rtol = 1e-9)
        @test r.vmax[1, 1] > 4000
        # ADL la da como 0 en ese punto: el objeto que ADL llama A_con_h es la holgura de steering
        @test max(0.0, (I + W - 1) - (L + I) / 2.5) == 0.0
    end

    @testset "10 · +D resta D y la puntualidad exige L − W_dec − D" begin
        L, I, W, D, Smax = 7200.0, 851.0, 20.0, 4.0, 150.0
        base = (L = L, I = I, W_dec = W, D = D, S_max = Smax, Lrev = L - Smax, con_h = true,
                espera = true, cruce = true, rhos = [2.5], n_rep = 1, J = 1500, alpha = 0.0,
                seed = UInt64(1), nb = 4096, bin = 16.0, v_lo = -1024.0, boot_ref = 0.0,
                modo_off = :cero)
        cfgD = Config{Float64}(; L = L, I = I, W_dec = W, D = D, S_max = Smax, Lrev = L - Smax,
                               con_h = true, espera = true, cruce = true, lead_h = D, j_ini = 0)
        cfg0 = Config{Float64}(; L = L, I = I, W_dec = W, D = D, S_max = Smax, Lrev = L - Smax,
                               con_h = true, espera = true, cruce = true, lead_h = 0.0, j_ini = 0)
        rD = barrer!(cfgD; rhos = [2.5], n_rep = 1, J = 1500, alpha = 0.0, seed = UInt64(1),
                     nb = 4096, bin = 16.0, v_lo = -1024.0, boot_ref = 0.0, modo_off = :cero)
        r0 = barrer!(cfg0; rhos = [2.5], n_rep = 1, J = 1500, alpha = 0.0, seed = UInt64(1),
                     nb = 4096, bin = 16.0, v_lo = -1024.0, boot_ref = 0.0, modo_off = :cero)
        @test r0.vmax[1, 1] - rD.vmax[1, 1] == D
        @test puntualidad_estricta(L, W, L - Smax, D, Smax)
        @test !puntualidad_estricta(L, W, L - W, D, Smax)
    end

    @testset "11 · determinismo: el resultado no depende del número de hilos" begin
        cfg = Config{Float64}(; L = 2000.0, I = 300.0, W_dec = 10.0, D = 2.0, S_max = 150.0,
                              Lrev = 1800.0, con_h = true, espera = false, cruce = true,
                              lead_h = 2.0, j_ini = 20)
        kw = (rhos = [1.2, 2.0, 3.0], n_rep = 24, J = 400, alpha = 0.33, seed = UInt64(0x77),
              nb = 1024, bin = 32.0, v_lo = -512.0, boot_ref = 0.0, modo_off = :geom)
        a = barrer!(cfg; kw..., nthreads = 1)
        b2 = barrer!(cfg; kw..., nthreads = 4)
        @test a.vmax == b2.vmax
        @test a.vmin == b2.vmin
        @test a.n_pro == b2.n_pro
        @test a.hist == b2.hist
    end

    @testset "12 · histograma y cuantiles" begin
        cfg = Config{Float64}(; L = 1000.0, I = 100.0, W_dec = 10.0, D = 0.0, S_max = 50.0,
                              Lrev = 900.0, con_h = false, espera = false, cruce = true,
                              lead_h = 0.0, j_ini = 0)
        r = barrer!(cfg; rhos = [2.0], n_rep = 8, J = 300, alpha = 0.0, seed = UInt64(3),
                    nb = 1024, bin = 4.0, v_lo = -4.0, boot_ref = 0.0, modo_off = :cero)
        h, bajo, sobre = hist_agregado(r)
        # la masa del histograma + los contadores externos == tiempo total acumulado
        @test isapprox(sum(h) + bajo + sobre, sum(r.hist) + sum(r.bajo) + sum(r.sobre), rtol = 1e-12)
        q50 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.5)
        q99 = cuantil_hist(h, bajo, sobre, r.bin, r.v_lo, 0.99)
        @test q50 <= q99
        @test 0.0 <= fraccion_excedencia(h, bajo, sobre, r.bin, r.v_lo, q50) <= 1.0
        @test fraccion_excedencia(h, bajo, sobre, r.bin, r.v_lo, q99) < 0.05
    end

    @testset "13 · coste: formas cerradas del instrumento" begin
        @test lineas_timekeeper(7200.0, 851.0) == 10
        @test lineas_timekeeper(3600.0, 851.0) == 6
        @test isapprox(nucleos_nodo(7200.0, 851.0), 0.0961 * (1 + 7200 / 851), rtol = 1e-12)
        @test I_estrella(7200.0, 2.5, 45.0) == 4725.0     # r10a §C.5
        @test lineas_timekeeper(7200.0, 4725.0) == 3
        @test I_minima(9.0, 20.0, 150.0) == 180.0
    end
end
