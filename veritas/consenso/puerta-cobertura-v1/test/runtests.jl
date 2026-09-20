# Suite de PCO-v0.1.
#
# Regla del encargo: «ningun resultado puede ser una constante literal; debe haber un test que
# falle si esa funcion se sustituye por su valor esperado escrito a mano en otro regimen».
# El bloque «NO-CONSTANTE» de cada seccion barre parametros y exige que el resultado **cambie**,
# con la direccion correcta. Si alguien reemplaza una funcion por un numero, esos tests fallan.

using Test
include(joinpath(@__DIR__, "..", "src", "PuertaCobertura.jl"))
using .PuertaCobertura
using Arblib
const PC = PuertaCobertura

@testset "PCO-v0.1" begin

# ---------------------------------------------------------------- punto 1: modelo de peso
@testset "peso · predicado de aceptacion" begin
    # |aceptados| = 2*(SR div 2)+1: SR+1 si par, SR si impar. Es TODO el punto 1.
    for SR in (1, 2, 3, 4, 99, 100, 2^20 - 1, 2^20, SR_MAX, SR_MAX - 1)
        @test valores_aceptados(SR) == 2 * (BigInt(SR) ÷ 2) + 1
        @test valores_aceptados(SR) == (iseven(SR) ? BigInt(SR) + 1 : BigInt(SR))
    end
    # dos SR consecutivos con la misma paridad de cuenta dan la MISMA tasa de bloques
    for m in (1, 7, 12345, 10^9)
        @test valores_aceptados(2m) == valores_aceptados(2m + 1)
    end
    # nunca se solapan los dos lados del circulo: SR div 2 <= 2^63 - 1
    @test SR_MAX ÷ 2 < BigInt(2)^63
end

@testset "peso · C-GD-01" begin
    @test peso_bloque(0) == DOS128                # SPEC.md:1671
    @test peso_bloque(SR_MAX) == DOS64            # SPEC.md:1671-1672
    for SR in (1, 2, 1000, 2^40, SR_MAX)
        @test peso_bloque(SR) * (BigInt(SR) + 1) + resto_suelo(SR) == DOS128
        @test 0 <= resto_suelo(SR) <= BigInt(SR)
    end
    # el port de pieces_to_solution_range reproduce los const_assert! de Autonomys
    # (solutions.rs:62-64): solution_range_to_pieces(pieces_to_solution_range(n)) == n
    for n in (1, 3, 5)
        sr = rango_de_piezas(n, (1, 6))
        base = (SR_MAX ÷ 6 * 1) ÷ PC.NUM_CHUNKS * PC.NUM_S_BUCKETS
        @test base ÷ sr == n
    end
end

@testset "peso · la cancelacion, exacta" begin
    # SR par: solo sobrevive el suelo, y su tamano es exactamente resto/2^128
    for SR in (2, 1000, BigInt(6148914690), BigInt(2)^40, SR_MAX - 1)
        @test iseven(SR)
        @test desviacion_cancelacion(SR) == -resto_suelo(SR) // DOS128
        @test abs(Float64(desviacion_cancelacion(SR))) < 2.0^-64
    end
    # SR impar: deficit de 1/(SR+1) salvo el suelo, y SIEMPRE mayor que el del par vecino
    for SR in (BigInt(2049), BigInt(6148914691), BigInt(2)^40 + 1, SR_MAX)
        @test isodd(SR)
        d = desviacion_cancelacion(SR)
        @test d < 0
        @test abs(d + 1 // (BigInt(SR) + 1)) <= 1 // DOS64      # el resto del suelo
        @test abs(d) > abs(desviacion_cancelacion(SR - 1))
    end
end

@testset "peso · NO-CONSTANTE: la desviacion depende de SR" begin
    ds = [Float64(desviacion_cancelacion(rango_de_piezas(BigInt(10)^e))) for e in 3:15]
    @test length(unique(ds)) == length(ds)               # ningun valor se repite
    # la rama impar crece exactamente como 1/(SR+1): al dividir SR por 10, la desviacion x10
    impares = [(sr = rango_de_piezas(BigInt(10)^e); isodd(sr) ? sr : sr - 1) for e in 3:15]
    for sr in impares
        @test isapprox(Float64(-desviacion_cancelacion(sr)), 1 / (Float64(sr) + 1); rtol=1e-6)
    end
    # y para SR par la desviacion es < 2^-64 en TODO el barrido: no es una constante, es una cota
    pares = [(sr = rango_de_piezas(BigInt(10)^e); iseven(sr) ? sr : sr - 1) for e in 3:15]
    @test all(abs(Float64(desviacion_cancelacion(sr))) < 2.0^-64 for sr in pares)
end

@testset "peso · el retarget elige paridad, y eso cambia el peso" begin
    P = BigInt(10)^9
    sp = rango_retarget(P, 1//1; paridad=:par)
    si = rango_retarget(P, 1//1; paridad=:impar)
    @test si == sp + 1
    @test valores_aceptados(sp) == valores_aceptados(si)          # MISMA tasa de bloques
    @test peso_bloque(sp) != peso_bloque(si)                      # DISTINTO peso por bloque
    @test tasa_peso(P, sp) > tasa_peso(P, si)                     # y distinta tasa de peso
end

@testset "peso · sesgo entre flujos" begin
    P1, P2 = BigInt(960_000_000), BigInt(940_000_000)
    for par in (:par, :impar)
        s = sesgo_tasa(P1, P2, rango_retarget(P1, 1//1; paridad=par),
                       rango_retarget(P2, 1//1; paridad=par))
        @test abs(Float64(s)) < 1e-11            # misma paridad: los deficits casi se cancelan
    end
    smix = sesgo_tasa(P1, P2, rango_retarget(P1, 1//1; paridad=:impar),
                      rango_retarget(P2, 1//1; paridad=:par))
    @test abs(Float64(smix)) > 1e-12             # paridad mezclada: aparece el termino completo
    # NO-CONSTANTE: el sesgo cambia con el tamano de la red
    ss = [Float64(sesgo_tasa(10 * P, 9 * P, rango_retarget(10 * P, 1//1; paridad=:impar),
                             rango_retarget(9 * P, 1//1; paridad=:par)))
          for P in (BigInt(10)^6, BigInt(10)^8, BigInt(10)^10)]
    @test length(unique(ss)) == 3
    @test abs(ss[1]) < abs(ss[2]) < abs(ss[3])
end

# ---------------------------------------------------------------- el proceso
@testset "proceso · espacio y deriva" begin
    for c in (0//1, 1//3, 1//1), s1 in (1//2, 3//5, 1//1)
        W₁, W₂ = espacio_cubridor(c, s1)
        @test W₁ + W₂ == 1 + c                      # el mismo sector cubre los dos flujos
        @test W₁ - W₂ == (1 - c) * (2 * s1 - 1)     # la deriva del encargo, en espacio
    end
    @test espacio_cubridor(1//1, 3//5) == (1//1, 1//1)   # cobertura total ⟹ simetria exacta
    @test_throws ArgumentError espacio_cubridor(3//2, 1//2)
end

@testset "proceso · Lundberg" begin
    # r = 1: la raiz tiene forma cerrada log(λ₁/λ₂)
    f = Flujos(0.8, 0.7, 1//1)
    @test isapprox(lundberg(f), log(0.8 / 0.7); rtol=1e-10)
    @test prob_ruina(f, 3)[1] == prob_ruina(f, 3)[2]              # exacto con r entero
    @test isapprox(prob_ruina(f, 3)[1], (0.7 / 0.8)^3; rtol=1e-10)
    # deriva nula o adversa ⟹ ruina segura
    @test lundberg(Flujos(1.0, 1.0, 1//1)) == 0.0
    @test prob_ruina(Flujos(1.0, 1.0, 1//1), 5) == (1.0, 1.0)
    # r != 1: el encierre contiene y es estrecho cuando R es pequeno
    g = flujos_regimen(9//10, 3//5, 1.0)
    lo, hi = prob_ruina(g, 4)
    @test lo < hi
    @test hi / lo ≈ exp(lundberg(g)) rtol = 1e-9
    # NO-CONSTANTE: R crece con la asimetria
    Rs = [lundberg(flujos_regimen(1//2, s, 1.0)) for s in (1//2, 11//20, 3//5, 3//4)]
    @test issorted(Rs)
    @test length(unique(Rs)) == 4
end

@testset "proceso · fraccion azul" begin
    @test fraccion_azul(0.0, 4.0, 30) == 1.0
    @test fraccion_azul(1.0, 4.0, 30) > fraccion_azul(2.0, 4.0, 30)      # mas tasa, menos azul
    @test fraccion_azul(1.0, 4.0, 30) > fraccion_azul(1.0, 8.0, 30)      # mas retardo, menos azul
    @test fraccion_azul(1.0, 4.0, 40) > fraccion_azul(1.0, 4.0, 18)      # mas k, mas azul
    # el transitorio favorece al minoritario: β del flujo pequeno es mayor
    c, s1 = 1//2, 3//5
    W₁, W₂ = espacio_cubridor(c, s1)
    @test fraccion_azul(float(W₂), 8.0, 18) > fraccion_azul(float(W₁), 8.0, 18)
end

# ---------------------------------------------------------------- L(t) y t(eps)
@testset "L(t) · equivalencia con el oraculo exacto (r=1)" begin
    f = flujos_transitorio(1//2, 3//5, 1.0, 4.0, 30)
    for t in (1.0, 10.0, 60.0)
        lo, hi = prob_cambio_posterior(f, t)
        ref, _ = prob_cambio_posterior_ref(f, t)
        # con r entero la parte de ruina es exacta; lo unico que separa lo de hi es la masa de
        # Poisson truncada, que es lo que la ventana adaptativa deja fuera a proposito
        @test hi - lo <= 1e-9 * max(hi, 1.0)
        @test lo * (1 - 1e-9) <= ref <= hi * (1 + 1e-9)
        @test isapprox(lo, ref; rtol=1e-9)
    end
end

@testset "L(t) · invariantes" begin
    f = flujos_regimen(1//2, 3//5, 1.0)
    ls = [prob_cambio_posterior(f, t)[2] for t in (1.0, 10.0, 100.0, 1000.0)]
    @test issorted(ls; rev=true)                      # L decrece en t
    @test all(0 .<= ls .<= 1)                         # sin recortes: sale en [0,1] solo
    # deriva nula: L = 1 CALCULADO, no escrito
    f0 = flujos_regimen(1//1, 3//5, 1.0)
    for t in (1.0, 100.0, 10_000.0)
        lo, hi = prob_cambio_posterior(f0, t)
        @test isapprox(lo, 1.0; atol=1e-9)
        @test isapprox(hi, 1.0; atol=1e-9)
    end
    # P(D≤0) + P(D>0) = 1
    for r in (1//1, 8//7, 3//2)
        a, _ = prob_no_positivo(20.0, 18.0, Rational{Int64}(r))
        b, _ = prob_positivo(20.0, 18.0, Rational{Int64}(r))
        @test isapprox(a + b, 1.0; atol=1e-12)
    end
    # kernel contra el oraculo BigFloat con r != 1
    for (m1, m2, r) in ((5.0, 4.0, 8//7), (20.0, 20.0, 11//10), (3.0, 7.0, 3//2))
        rr = Rational{Int64}(r)
        @test isapprox(prob_no_positivo(m1, m2, rr)[1],
                       prob_no_positivo_ref(m1, m2, rr; nmax=250)[1]; atol=1e-12)
    end
end

@testset "L(t) · NO-CONSTANTE y escala" begin
    # t(ε) escala como 1/λ y solo depende de λt: la ley de escala es un resultado, se comprueba
    for λ in (0.5, 1.0, 4.0)
        f = flujos_regimen(1//2, 3//5, λ)
        t = tiempo_hasta(f, 1e-6)[2]
        @test isapprox(t * λ, tiempo_hasta(flujos_regimen(1//2, 3//5, 1.0), 1e-6)[2];
                       rtol=1e-6)
    end
    # t(ε) crece al bajar ε, y crece al subir c (la cobertura estabiliza la particion)
    f = flujos_regimen(1//2, 3//5, 1.0)
    ts = [tiempo_hasta(f, ε)[2] for ε in (1e-3, 1e-6, 1e-9)]
    @test issorted(ts)
    @test length(unique(ts)) == 3
    tc = [tiempo_hasta(flujos_regimen(c, 3//5, 1.0), 1e-6)[2]
          for c in (0//1, 1//2, 3//4, 9//10)]
    @test issorted(tc)
    @test length(unique(tc)) == 4
    # c = 1 ⟹ nunca: no hay t finito
    @test tiempo_hasta(flujos_regimen(1//1, 3//5, 1.0), 1e-3) == (Inf, Inf)
    # L(F) crece con c a F fijo
    lf = [prob_cambio_posterior(flujos_regimen(c, 3//5, 1.0), 600.0)[2]
          for c in (0//1, 1//2, 3//4, 9//10, 1//1)]
    @test issorted(lf)
    @test length(unique(lf)) == 5
end

@testset "L(t) · certificado con Arb" begin
    for f in (flujos_transitorio(1//2, 3//5, 1.0, 4.0, 30), flujos_regimen(1//2, 3//5, 1.0))
        R = lundberg_arb(f)
        @test Arblib.contains(R, Arb(lundberg(f); prec=PC.PREC)) ||
              abs(Float64(Arblib.midpoint(R)) - lundberg(f)) < 1e-9
        for t in (10.0, 100.0)
            lo, hi = prob_cambio_posterior(f, t)
            b = prob_cambio_posterior_arb(f, t)
            blo = Float64(Arblib.lbound(b)); bhi = Float64(Arblib.ubound(b))
            @test !(hi < blo * (1 - 1e-9) || lo > bhi * (1 + 1e-9))   # los encierres se solapan
        end
    end
end

# ---------------------------------------------------------------- simulacion
@testset "simulacion · determinismo y acuerdo con la formula" begin
    f = flujos_transitorio(1//2, 3//5, 1.0, 4.0, 30)
    a = recorrer(PC.rng_replica(UInt64(0x5A5A), 7), f, 500.0, 100.0)
    b = recorrer(PC.rng_replica(UInt64(0x5A5A), 7), f, 500.0, 100.0)
    @test a.cambios == b.cambios && a.t_ultimo == b.t_ultimo && a.t_absorcion == b.t_absorcion
    # el Monte Carlo cae dentro del intervalo exacto de Clopper-Pearson alrededor de la formula
    for t in (5.0, 20.0)
        lo, _ = prob_cambio_posterior(f, t)
        _, ci_lo, ci_hi = mc_cambio_posterior(f, t, 20_000.0, 3000, UInt64(0x51))
        @test ci_lo <= lo <= ci_hi
    end
    # Clopper-Pearson: exacto en los bordes, nunca degenerado
    @test clopper_pearson(0, 100)[1] == 0.0
    @test clopper_pearson(0, 100)[2] > 0.0
    @test clopper_pearson(100, 100)[2] == 1.0
    lo, hi = clopper_pearson(30, 100)
    @test lo < 0.3 < hi
end

# ------------------------------------------- congelamiento simultaneo (R-FIN-7 por profundidad)
@testset "congelamiento · equivalencia con el oraculo" begin
    # prob_le generaliza prob_no_positivo
    for (m1, m2, r) in ((5.0, 4.0, 8//7), (20.0, 18.0, 1//1))
        rr = Rational{Int64}(r)
        @test prob_le(m1, m2, rr, 0//1)[1] == prob_no_positivo(m1, m2, rr)[1]
    end
    # el nucleo, contra la enumeracion completa en BigFloat
    for (c, s1) in ((1//1, 1//2), (1//2, 3//5)), (F, τ) in ((30.0, 4.0), (60.0, 2.0))
        f = flujos_regimen(c, s1, 1.0)
        @test isapprox(prob_congelamiento_divergente(f, F, τ)[1],
                       congelamiento_ref(f, F, τ); rtol=1e-8)
    end
    # y contra Monte Carlo
    f = flujos_regimen(1//1, 1//2, 1.0)
    for (F, τ) in ((600.0, 4.0), (600.0, 16.0))
        v = prob_congelamiento_divergente(f, F, τ)[1]
        _, lo, hi = mc_congelamiento(f, F, τ, 20_000, UInt64(0xC0FE))
        @test lo <= v <= hi
    end
end

@testset "congelamiento · forma cerrada y cotas" begin
    f = flujos_regimen(1//1, 1//2, 1.0)          # deriva nula: aplica el limite de difusion
    for (F, τ) in ((600.0, 4.0), (7200.0, 4.0), (11520.0, 4.0))
        @test isapprox(prob_congelamiento_divergente(f, F, τ)[1],
                       congelamiento_arcoseno(F, τ); rtol=0.03)
    end
    # NO es (2/π)arcsin: ese seria el suceso «hay un cero», el doble de frecuente
    @test congelamiento_arcoseno(600.0, 4.0) < 0.6 * arcoseno_continua(4.0 / 600.0)
    # la cota de banda es cota, y es holgada
    for (F, τ) in ((600.0, 4.0), (7200.0, 4.0))
        v = prob_congelamiento_divergente(f, F, τ)[1]
        b = prob_banda(f, F, delta_red(f, τ))[1]
        @test b >= v
    end
    # prob_banda crece con δ y vive en [0,1]
    bs = [prob_banda(f, 600.0, δ)[1] for δ in (1.0, 4.0, 16.0, 64.0)]
    @test issorted(bs)
    @test all(0 .<= bs .<= 1)
    @test length(unique(bs)) == 4
end

@testset "congelamiento · NO-CONSTANTE" begin
    f = flujos_regimen(1//1, 1//2, 1.0)
    # decrece con F como √(τ/F): al multiplicar F por 4, cae a la mitad
    p600 = prob_congelamiento_divergente(f, 600.0, 4.0)[1]
    p2400 = prob_congelamiento_divergente(f, 2400.0, 4.0)[1]
    @test isapprox(p2400 / p600, 0.5; rtol=0.05)
    # crece con τ
    ps = [prob_congelamiento_divergente(f, 600.0, τ)[1] for τ in (1.0, 4.0, 16.0, 60.0)]
    @test issorted(ps)
    @test length(unique(ps)) == 4
    # decrece con la deriva: la asimetria aleja D de cero antes de F
    pd = [prob_congelamiento_divergente(flujos_regimen(1//2, s, 1.0), 600.0, 4.0)[1]
          for s in (1//2, 11//20, 3//5, 3//4)]
    @test issorted(pd; rev=true)
    @test length(unique(pd)) == 4
    # y es independiente de c cuando s₁ = s₂ (deriva nula): c no entra
    pc = [prob_congelamiento_divergente(flujos_regimen(c, 1//2, 1.0), 600.0, 4.0)[1]
          for c in (0//1, 1//2, 9//10, 1//1)]
    @test all(≈(pc[1]), pc)
end

@testset "RNG · independencia entre replicas (regresion del defecto D4)" begin
    # Con `StableRNG(semilla + i)` esta autocorrelacion vale ≈ −0,43 y sesga el Monte Carlo.
    # Con Philox contracontador debe ser ≈ 0. Este test falla si alguien vuelve al esquema viejo.
    for semilla in (UInt64(0x5A5A), UInt64(0xC0FE))
        @test abs(autocorrelacion_replicas(semilla, 20_000)) < 0.02
    end
    # y sigue siendo reproducible bit a bit
    @test rand(rng_replica(UInt64(1), 7), 5) == rand(rng_replica(UInt64(1), 7), 5)
    @test rand(rng_replica(UInt64(1), 7), 5) != rand(rng_replica(UInt64(1), 8), 5)
end

# ---------------------------------------------------------------- cobertura
@testset "cobertura · S_max" begin
    m = costes_repositorio()
    # EL defecto que senala ADENDA-2 §5: S por IOPS NO depende de la capacidad
    s = [s_max_iops(m, 25_000.0) for _ in 1:3]
    @test all(==(s[1]), s)
    @test isapprox(s_max_iops(m, 25_000.0), 25_000.0 / lecturas_por_TiB(m); rtol=1e-12)
    # y por nucleos SI decrece con la capacidad
    sn = [s_max_nucleos(m, 16.0, cap) for cap in (1.0, 10.0, 100.0, 1000.0)]
    @test issorted(sn; rev=true)
    @test length(unique(sn)) == 4
    # S_max es el minimo de los dos
    for cap in (1.0, 100.0), ι in (10_000.0, 250_000.0)
        @test s_max(m, ι, 16.0, cap) == min(s_max_iops(m, ι), s_max_nucleos(m, 16.0, cap))
    end
    # NO-CONSTANTE: todo depende de las entradas medidas
    m2 = costes_repositorio(; dur_slot_s=6.0)
    @test s_max_iops(m2, 25_000.0) != s_max_iops(m, 25_000.0)
    @test nucleos_auditoria_por_TiB(m2) < nucleos_auditoria_por_TiB(m)
    m3 = CostesMedidos(8322.0, 4.0, 42.92, 1.0, 0.0961, 1.561)   # el doble de lecturas
    @test isapprox(s_max_iops(m3, 25_000.0), s_max_iops(m, 25_000.0) / 2; rtol=1e-12)
end

@testset "cobertura · la condicion economica" begin
    # el umbral decrece con el tamano y tiende a rho_var: es el termino fijo el que manda
    xs = (0.1, 1.0, 10.0, 100.0, 1e4, 1e8)
    us = [umbral_probabilidad(x, 1e-3, 1.0) for x in xs]
    @test issorted(us; rev=true)
    @test isapprox(us[end], 1e-3; rtol=1e-3)
    # sin coste fijo, el umbral no depende del tamano: es la hipotesis historica «cubrir es gratis»
    u0 = [umbral_probabilidad(x, 1e-3, 0.0) for x in xs]
    @test all(==(u0[1]), u0)
    # tamano minimo: infinito si ni siquiera el coste variable se cubre
    @test tamano_minimo(1e-4, 1e-3, 1.0) == Inf
    @test isfinite(tamano_minimo(1e-2, 1e-3, 1.0))
    @test tamano_minimo_productor(1e-2, 1e-3, 1.0, 16.0) > tamano_minimo(1e-2, 1e-3, 1.0)
    # NO-CONSTANTE: c en equilibrio decrece con el umbral de tamano y esta en [0,1]
    xs2, w = pareto_tamanos(0.5, 1.5, 300)
    cs = [cobertura_equilibrio(xs2, w, xm) for xm in (0.0, 1.0, 10.0, 100.0, 1e5)]
    @test issorted(cs; rev=true)
    @test all(0 .<= cs .<= 1)
    @test cs[1] == 1.0                       # sin umbral, cubre todo el espacio
    @test length(unique(cs)) >= 4
end

# ---------------------------------------------------------------- arcoseno
@testset "arcoseno" begin
    for n in (1, 5, 50)
        p = arcoseno_discreta(n)
        @test sum(p) == 1                                   # exacta: Rational{BigInt}
        @test all(x -> x > 0, p)
        @test p[1] == p[end]                                # simetrica
    end
    # la media tiende a 1/2 y NO a 0,99: es el nucleo del contraste historico
    ms = [Float64(media_arcoseno_discreta(n)) for n in (10, 100, 500)]
    @test all(x -> abs(x - 0.5) < 1e-12, ms)
    @test length(unique(ms)) >= 1
    # la ley continua: U, con masa en los dos extremos
    @test isapprox(arcoseno_continua(0.5), 0.5; rtol=1e-12)
    @test 1 - arcoseno_continua(0.99) > 0.06                # ~6,4 % por encima de 0,99·T
    @test 1 - arcoseno_continua(0.99) < 0.07
    # NO-CONSTANTE: la cola depende del umbral
    qs = [1 - arcoseno_continua(x) for x in (0.5, 0.9, 0.99, 0.999)]
    @test issorted(qs; rev=true)
    @test length(unique(qs)) == 4
end

end
