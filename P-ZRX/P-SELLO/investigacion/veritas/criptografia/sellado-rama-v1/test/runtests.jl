# runtests.jl — perfil de referencia (1 hilo, límites activos)
# Se ejecuta con: julia --project=. --check-bounds=yes test/runtests.jl
# Cada comprobación contrasta DOS vías independientes (encargo §4).

using Test
using SelladoRama
const S = SelladoRama
const RB = S.RB

const HW = S.Hardware(t_tabla_s = 0.80913, r_tablas_s = 25.027, hilos = 24,
                      piece_bytes = 1048672)

@testset "sellado-rama-v1" begin

@testset "hardware y derivadas" begin
    @test S.piezas_por_TiB(HW) ≈ 1_048_480.0088 rtol = 1e-6
    @test S.horas_TiB_1nucleo(HW) ≈ 235.65 rtol = 1e-3
    @test S.horas_TiB_maquina(HW) ≈ 11.637 rtol = 1e-3
    @test S.nucleos_equivalentes(HW) ≈ 20.25 rtol = 1e-3
    @test S.t_tabla_maquina_s(HW) ≈ 0.039957 rtol = 1e-4
    @test_throws ArgumentError S.Hardware(t_tabla_s = 0.0, r_tablas_s = 1.0,
                                          hilos = 1, piece_bytes = 1)
end

@testset "presupuesto del honesto: bordes" begin
    p0 = S.presupuesto_honesto(1.0, 1.0, 0.0; n_puntas = 1.0)
    @test p0.W_s == 1.0
    pT = S.presupuesto_honesto(1.0, 1.0, 1.0; n_puntas = 1.0)
    @test pT.W_s == 0.0
    # Δ > τ se recorta (no hay presupuesto negativo)
    pX = S.presupuesto_honesto(1.0, 1.0, 2.0; n_puntas = 1.0)
    @test pX.W_s == 0.0
    # reparto entre n puntas
    pn = S.presupuesto_honesto(1.0, 1.0, 0.26; n_puntas = 2.0)
    @test pn.W_s ≈ (1.0 - 0.26) / 2
    @test pn.tasa_religadura ≈ 2.0
    @test_throws ArgumentError S.presupuesto_honesto(1.0, 1.0, 0.26; n_puntas = 0.0)
end

@testset "modelo de punta: monotonía y forma cerrada" begin
    @test S.padres(1.0, 0.26) ≈ 1.26
    @test S.padres(1.0, 0.60) ≈ 1.60
    @test S.padres(1.0, 0.26) < S.padres(1.0, 0.30)
    @test S.puntas_concurrentes(1.0, 0.138) < S.puntas_concurrentes(1.0, 0.387)
    # los padres típicos medidos 1,14-1,39 caen dentro del barrido de Δ̄
    @test 1.13 <= S.padres(1.0, 0.138) <= 1.15
    @test 1.38 <= S.padres(1.0, 0.387) <= 1.39
end

@testset "α* exacta: forma cerrada vs residuo vs bisección" begin
    # casos calculados a mano
    @test S.alpha_estrella_exacta(RB(1), RB(1), RB(0), RB(0)) == RB(1, 2)
    @test S.alpha_estrella_exacta(RB(1), RB(1), RB(1, 5), RB(0)) == RB(2, 5)
    @test S.alpha_estrella_exacta(RB(1), RB(1), RB(0), RB(1, 5)) == RB(3, 10)
    @test S.alpha_estrella_exacta(RB(1), RB(1), RB(1, 5), RB(1, 5)) == RB(1, 5)
    # 36 celdas exactas en dos vías independientes
    βs = [RB(0), RB(1, 10), RB(1, 5), RB(3, 10), RB(2, 5), RB(1, 2)]
    res = S.validar_alfa(RB(1), RB(1), βs, βs; iter = 200)
    @test res.n > 0
    @test res.n_residuo_cero == res.n      # g(α*) == 0 exacto en todas
    @test res.n_en_bracket == res.n        # la bisección independiente encierra α*
    @test res.max_ancho <= RB(1, 2)^200
    # η distintos: la superficie no es simétrica
    @test S.alpha_estrella_exacta(RB(2), RB(1), RB(1, 5), RB(0)) == (RB(2) - RB(1, 5)) // RB(3)
    # monotonía exacta
    @test S.validar_monotonia(RB(1), RB(1), βs, βs)
    # α* = 0 cuando el atacante ya gana la deriva
    @test S.alpha_estrella_exacta(RB(1), RB(1), RB(0), RB(1, 2)) == RB(0)
    @test_throws ArgumentError S.biseccion_raiz(RB(1), RB(1), RB(0), RB(1))
end

@testset "F5: gap exacto s/2 y umbral c_d = c_x/2" begin
    ss = [RB(1, 10), RB(1, 5), RB(3, 10), RB(2, 5)]
    rg = S.validar_gap(RB(1), RB(1), ss)
    @test rg.n == 4
    @test rg.n_residuo_cero == 4          # g = 0 exacto en los dos extremos
    @test rg.n_gap_exacto == 4            # a_bd − a_bx == s/2
    ru = S.validar_umbral([RB(1, 10), RB(1, 4), RB(2, 5), RB(1, 2), RB(3, 5), RB(1), RB(2)],
                          RB(1))
    @test ru.n == 7
    @test ru.n_coincide == 7              # regla vs comparación directa de daños
    # umbral: por debajo de φ = 1/2 el atacante aún usa β_d; por encima, no
    @test S.dano_por_coste(RB(2, 5), RB(1)).bd > S.dano_por_coste(RB(2, 5), RB(1)).bx
    @test S.dano_por_coste(RB(3, 5), RB(1)).bx > S.dano_por_coste(RB(3, 5), RB(1)).bd
    @test S.ventaja_bx_sobre_bd(RB(1, 2), RB(1)) == 1
    @test S.umbral_backfire(1.0) == 0.5
end

@testset "lema de circularidad: mismo conjunto de padres ⇒ misma ancestría" begin
    res = S.validar_ancestria(UInt64(0x5E110A1A), 200, 12)
    @test res.n_pares > 50
    @test res.n_iguales == res.n_pares
    # caso explícito: dos hijos de la misma punta
    pad = [Int[], [1], [1], [2], [2, 3]]
    @test S.ancestria(pad, 2) == S.ancestria(pad, 3)
    @test S.pares_mismo_padre(pad) == [(2, 3)]
end

@testset "kernels tipados: equivalencia y dimensiones" begin
    Δs = [0.138, 0.26, 0.387, 0.60]
    n = length(Δs)
    W = zeros(n); tasa = zeros(n); dmax = zeros(n); pad = zeros(n)
    S.kernel_presupuesto!(W, tasa, dmax, pad, Δs, 1.0, 1.0, HW.r_tablas_s; n_puntas = 1.0)
    for i in 1:n
        p = S.presupuesto_honesto(1.0, 1.0, Δs[i]; n_puntas = 1.0)
        @test W[i] == p.W_s
        @test tasa[i] == p.tasa_religadura
        @test pad[i] ≈ S.padres(1.0, Δs[i])
    end
    # kernel α vs oráculo racional
    bd = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
    bx = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
    α = zeros(6)
    S.kernel_alfa!(α, bd, bx, 1.0, 1.0)
    for i in 1:6
        exacto = S.alpha_estrella_exacta(RB(1), RB(1), RB(round(Int, bd[i]*10), 10),
                                         RB(round(Int, bx[i]*10), 10))
        @test isapprox(α[i], Float64(exacto); atol = 1e-12)
    end
    @test_throws DimensionMismatch S.kernel_presupuesto!(zeros(3), tasa, dmax, pad, Δs,
                                                         1.0, 1.0, 25.0; n_puntas = 1.0)
    # materialización: fracción × S = delta
    frac = zeros(n); veces = zeros(n)
    S.kernel_materializacion!(frac, veces, W, S.piezas_por_TiB(HW), HW.r_tablas_s)
    for i in 1:n
        @test isapprox(frac[i] * S.piezas_por_TiB(HW),
                       S.delta_max_piezas(HW, W[i]); rtol = 1e-12)
    end
end

@testset "semillas no consecutivas" begin
    maestra = UInt64(0x5E110A1A)
    s = [S.semilla_replica(maestra, r) for r in 1:128]
    @test length(unique(s)) == 128
    @test minimum(abs(Int128(s[i]) - Int128(s[j])) for i in 1:128 for j in (i+1):128) > 1
end

@testset "Monte Carlo del modelo de punta: dos RNG vs forma cerrada" begin
    for Δm in (0.20, 0.30)
        ps, pp = S.mc_puntas(1.0, Δm, 800.0, 24, UInt64(0x5E110A1A))
        pr, _ = S.mc_puntas_r123(1.0, Δm, 800.0, 24, UInt64(0x5E110A1A))
        cerr = S.padres(1.0, Δm)
        ms = sum(ps) / length(ps)
        mr = sum(pr) / length(pr)
        # el modelo reproduce la forma cerrada dentro del 10 %
        @test abs(ms - cerr) / cerr < 0.10
        @test abs(mr - cerr) / cerr < 0.10
        # los dos RNG coinciden entre sí dentro del 5 %
        @test abs(ms - mr) / cerr < 0.05
        @test all(pp .>= 1.0)               # el número de puntas nunca es < 1
    end
end

end
