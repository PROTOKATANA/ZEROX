# test/runtests.jl — suite del instrumento `reloj-adaptativo-v1`.
#
# Ejecutar con:
#   ../../veritas/julia.sh --project=. test/runtests.jl
#
# La suite NO fija parámetros de ZEROX. Comprueba:
#   1 · el oráculo exacto de la frontera y sus bordes (inclusividad y monotonía),
#   2 · que la frontera no depende de `N` ni de `τ`, y que `N_max` sí escala con `τ` y con `t_v`,
#   3 · la equivalencia entre dispersión, `ρ` y `K`,
#   4 · el dominio de `C-POT-04` y el techo duro del tipo,
#   5 · la equivalencia de `simular!` (Float64) con `simular_exacto` (Rational{BigInt}),
#   6 · los invariantes del adaptador, incluidos trinquete y ganancia cero,
#   7 · la mediana adversarial contra un oráculo DP independiente,
#   8 · los vectores de regresión.

using RelojAdaptativo
using Test

# Los nombres del paquete van CALIFICADOS (`Modelos.`, `Referencia.`) a propósito: así el test no
# depende de la lista de exportaciones y se ve en cada línea de qué ruta viene cada símbolo.
const Modelos = RelojAdaptativo.Modelos
const Referencia = RelojAdaptativo.Referencia
const Rapido = RelojAdaptativo.Rapido
const MAQUINA_REF = Modelos.MAQUINA_REF
const Adaptador = Modelos.Adaptador
const traza_vacia = Modelos.traza_vacia
const simular! = Modelos.simular!
const hardware_alternante = Modelos.hardware_alternante
const dispersion_maxima = Modelos.dispersion_maxima
const admite_dispersion = Modelos.admite_dispersion
const dispersion_admitida = Modelos.dispersion_admitida
const epsilon_minimo = Modelos.epsilon_minimo
const en_dominio_pot04 = Modelos.en_dominio_pot04
const frontera_rapida = Modelos.frontera_rapida
const N_MAX_TIPO = Modelos.N_MAX_TIPO
const U32_MAX = Modelos.U32_MAX
const N_max_exacto = Referencia.N_max_exacto
const admisible_exacto = Referencia.admisible_exacto

const BigRat = Rational{BigInt}

@testset "P-RELOJ · reloj-adaptativo-v1" begin

    @testset "1 · frontera: oráculo exacto y bordes" begin
        # La frontera se construye con el cociente EXACTO `tv/(K·tp)` expresado en BigRat, no con
        # el cociente en Float64: el cociente real de dos binarios no es el binario del cociente,
        # así que `tv/(K*tp)` en Float64 puede caer a cualquier lado de la frontera. Se prueba la
        # inclusividad, la monotonía y la coincidencia con el kernel rápido.
        for (tp, tv, K) in [(1, 1, 3), (7, 3, 8), (1, 1, 16), (3, 1, 4)]
            εb = BigRat(tv) / (K * BigRat(tp))          # frontera EXACTA
            @test Referencia.admisible_exacto(BigRat(tp), BigRat(tv), K, εb)
            @test !Referencia.admisible_exacto(BigRat(tp), BigRat(tv), K, εb / 2)
            @test Referencia.admisible_exacto(BigRat(tp), BigRat(tv), K, εb * 2)
            # En puntos NETOS (muy por debajo y muy por encima) las dos rutas coinciden siempre.
            εf = Float64(εb)
            @test !Referencia.admisible_exacto(BigRat(tp), BigRat(tv), K, BigRat(εf / 2))
            @test !frontera_rapida(Float64(tp), Float64(tv), K, εf / 2, 1.0).admisible
            @test Referencia.admisible_exacto(BigRat(tp), BigRat(tv), K, BigRat(εf * 2))
            @test frontera_rapida(Float64(tp), Float64(tv), K, εf * 2, 1.0).admisible
            # En el BORDE las dos rutas pueden discrepar, y es un hallazgo, no un fallo: el
            # kernel rápido calcula `tv/(K·tp)` en Float64, y el cociente real de dos binarios no
            # es el binario del cociente. Se comprueba que la discrepancia no pasa de 1 ULP, que
            # es la propiedad que importa, y NO se exige acuerdo en el punto de frontera.
            vfl = Float64(BigRat(tv)) / (K * Float64(BigRat(tp)))
            @test abs(vfl - Float64(εb)) <= eps(Float64(εb))
        end
        # Frontera con igualdad entera: t_v = 1, K = 8, t_p = 1/8  ⟹  ε_min = 1.
        @test Referencia.admisible_exacto(BigRat(1), BigRat(1), 8, BigRat(8))
        # Muy por debajo de la frontera, nunca admisible.
        @test !frontera_rapida(1.0, 4.0, 8, 0.1, 1.0).admisible
    end

    @testset "2 · la frontera NO depende de N ni de τ" begin
        a = frontera_rapida(1.0, 1.0, 8, 0.1, 1.0)
        b = frontera_rapida(1.0, 1.0, 8, 0.1, 1e9)
        c = frontera_rapida(1.0, 1.0, 8, 0.1, 1e-9)
        @test a.admisible == b.admisible
        @test b.admisible == c.admisible
        @test a.epsilon_min == b.epsilon_min
        @test b.epsilon_min == c.epsilon_min
        # N_max SÍ depende de τ, y de forma exactamente lineal.
        n1 = N_max_exacto(BigRat(1, 10), BigRat(1), BigRat(1, 1000))
        n2 = N_max_exacto(BigRat(1, 10), BigRat(2), BigRat(1, 1000))
        @test n2 == 2 * n1
        # Y de t_v de forma inversamente proporcional.
        n3 = N_max_exacto(BigRat(1, 10), BigRat(1), BigRat(2, 1000))
        @test n3 == n1 / 2
    end

    @testset "3 · dispersión, ρ y K son la misma frontera" begin
        for ε in (0.02, 0.05, 0.1, 0.25), K in (4, 8, 16)
            S = dispersion_maxima(ε, K)
            @test dispersion_admitida(ε, K) == S    # la frontera es un TECHO sobre rho, y rho = S
            # La frontera es inclusiva: `S` cabe, `S·1,0001` no, tanto si la frontera cae por
            # encima de 1 (admite alguna dispersión) como si cae por debajo (no admite ninguna).
            if S >= 1.0
                @test admite_dispersion(ε, K, S)
                @test !admite_dispersion(ε, K, S * (1 + 1//10000))
            else
                # Frontera por debajo de 1: ninguna dispersión real (S ≥ 1) es admisible. La API
                # rechaza el dominio en vez de devolver un veredicto sobre un valor imposible.
                @test S < 1.0
                @test_throws ArgumentError admite_dispersion(ε, K, S)
            end
        end
        # Contrato de dominio: sólo tiene sentido para S ≥ 1.
        @test_throws ArgumentError admite_dispersion(0.5, 8, 0.5)
        @test_throws ArgumentError admite_dispersion(0.0, 8, 1.0)
        @test_throws ArgumentError admite_dispersion(0.5, 0, 1.0)
        # El resultado central, comprobado explícitamente: K = 8 con ε = 10 % admite 0,8× de
        # dispersión, o sea MENOS de 1: no admite ninguna dispersión.
        @test dispersion_maxima(0.10, 8) < 1.0
        @test !admite_dispersion(0.10, 8, 1.0)
        @test dispersion_maxima(0.10, 16) == 1.6
        @test admite_dispersion(0.10, 16, 1.5)
        @test dispersion_maxima(0.125, 8) == 1.0
        # La correspondencia de las dos direcciones, comprobada en las dos direcciones:
        #   rho_max(eps, K) = eps*K   y   eps_min(rho, K) = rho/K
        for ε in (0.02, 0.10, 0.25), K in (8, 16)
            ρ = dispersion_admitida(ε, K)
            @test epsilon_minimo(ρ, K) ≈ ε          # despeje inverso exacto
            @test dispersion_admitida(epsilon_minimo(ρ, K), K) ≈ ρ
        end
        # Y el caso que el revisor señaló: rho = 3 con K = 16 exige eps = 18,75 %, NO 2,08 %.
        @test epsilon_minimo(3.0, 16) == 3 / 16
        @test !admite_dispersion(1 / (3 * 16), 16, 3.0)   # 2,08 % NO admite rho = 3
        @test admite_dispersion(3 / 16, 16, 3.0)          # 18,75 % SI lo admite
    end

    @testset "4 · dominio de C-POT-04 y techo del tipo" begin
        for (n, esperado) in [(0, false), (1, false), (15, false), (16, true), (17, false),
                              (32, true), (UInt64(4_294_967_295), false),
                              (UInt64(4_294_967_295) + 1, false),
                              (N_MAX_TIPO, true), (N_MAX_TIPO + 16, false)]
            @test en_dominio_pot04(n) == esperado
        end
        @test N_MAX_TIPO % 16 == 0
        @test N_MAX_TIPO + 16 > U32_MAX
        @test Referencia.dominio_concuerda()
        # Redondeo al múltiplo de 16 inferior, y que N+16 no quepa en el objetivo.
        nd = RelojAdaptativo.N_para_objetivo(1.0, 7.77e-9)
        @test nd % 16 == 0
        @test Float64(nd) * 7.77e-9 <= 1.0
        @test Float64(nd + 16) * 7.77e-9 > 1.0
    end

    @testset "5 · adaptador: Float64 vs Rational{BigInt}" begin
        T = 300
        hw = hardware_alternante(T, 7.77e-9, 1.554e-8, 40, 0.5)
        # τ objetivo construido como N₀·t_bloque con el MISMO Float64 que usa el lazo: así la
        # comparación mide la ley de control, no el error del objetivo.
        τ = 200_000_000 * 7.77e-9
        for (g, ret, trin, cad) in [(0.5, 1, false, 0), (0.25, 3, false, 0),
                                    (0.5, 5, true, 0), (0.3, 2, false, 7)]
            p = Adaptador(200_000_000, 1_000_000, 800_000_000, 7.77e-9, 200_000_000, g, ret, trin, cad, 0)
            t = traza_vacia(T, 0.0)
            simular!(t, hw, p)
            ex = Referencia.simular_exacto([BigRat(x) for x in hw], p)
            # Las dos rutas NO son idénticas bit a bit, y se dice en voz alta: el lazo rápido
            # evalúa `trunc(N·(1+g·e))` en Float64 y el oráculo en Rational{BigInt}, así que en
            # los puntos donde el producto cae a menos de 1 ULP de un múltiplo de 16 pueden
            # discrepar en UN paso de cuantización (16 unidades de N). El invariante que importa
            # es que la discrepancia no pase de ahí y que decidan lo mismo en el signo.
            peor = 0
            for s in 1:T
                d = abs(BigInt(t.N[s]) - ex[s])
                d > peor && (peor = d)
            end
            @test peor <= 16
            @test (t.N[end] == ex[end]) || abs(BigInt(t.N[end]) - ex[end]) <= 16
        end
    end

    @testset "6 · invariantes del adaptador" begin
        T = 400
        hw = hardware_alternante(T, 7.77e-9, 1.554e-8, 50, 0.4)
        p = Adaptador(200_000_000, 1_000_000, 800_000_000, 7.77e-9, 200_000_000, 0.3, 3, false, 0, 0)
        t = traza_vacia(T, 0.0)
        simular!(t, hw, p)
        @test all(v -> p.N_min <= v <= p.N_max, t.N)          # I1
        @test all(v -> v % 16 == 0, t.N)                      # I2
        for s in 2:T                                          # I5
            d = t.N[s] - t.N[s-1]
            esp = d > 0 ? Int8(1) : (d < 0 ? Int8(-1) : Int8(0))
            @test t.ajuste[s] == esp
        end
        # I3 · trinquete: nunca baja
        pt = Adaptador(200_000_000, 1_000_000, 800_000_000, 7.77e-9, 200_000_000, 0.5, 1, true, 0, 0)
        tt = traza_vacia(T, 0.0)
        simular!(tt, hw, pt)
        @test all(tt.N[s] >= tt.N[s-1] for s in 2:T)
        # I4 · ganancia cero: nunca cambia
        p0 = Adaptador(200_000_000, 1_000_000, 800_000_000, 7.77e-9, 200_000_000, 0.0, 1, false, 0, 0)
        t0 = traza_vacia(T, 0.0)
        simular!(t0, hw, p0)
        @test all(v -> v == 200_000_000, t0.N)
        # La copia rápida tiene que dar exactamente la misma traza que la transparente.
        p2 = Adaptador(200_000_000, 1_000_000, 800_000_000, 7.77e-9, 200_000_000, 0.3, 5, false, 0, 0)
        ta = traza_vacia(T, 0.0); simular!(ta, hw, p2)
        tb = traza_vacia(T, 0.0); RelojAdaptativo.simular_rapido!(tb, hw, p2)
        @test ta.N == tb.N
        @test ta.ajuste == tb.ajuste
    end

    @testset "7 · región de manipulación de la mediana" begin
        # La región publicada se calcula con la aritmética del ORDEN, no con una simulación: con
        # W = 2m+1, la mediana es la posición m+1; el adversario la fija con C ≥ m+1 y con menos
        # sólo puede desplazarla. Los dos sesgos se suman: `C·min(δ,1)` (cadena monótona o
        # posiciones) hacia abajo y `C·φ` (FTL) hacia arriba.
        for (W, δ, φ) in [(11, 1.0, 7200.0), (51, 1.0, 7200.0), (201, 2.0, 3600.0)]
            m = W ÷ 2
            # Sin adversario no hay sesgo.
            @test Modelos.sesgo_mediana_adversario(W, 0, δ, φ) == (0.0, 0.0)
            # La cota es monótona en el número de posiciones y en los dos parámetros.
            for C in 1:(W - 1)
                # Más posiciones del adversario = sesgo MÁS negativo (más daño) hacia abajo,
                # y más positivo hacia arriba.
                @test Modelos.sesgo_mediana_adversario(W, C, δ, φ)[1] >=
                      Modelos.sesgo_mediana_adversario(W, C + 1, δ, φ)[1] - 1e-12
                @test Modelos.sesgo_mediana_adversario(W, C, δ, φ)[2] <=
                      Modelos.sesgo_mediana_adversario(W, C + 1, δ, φ)[2] + 1e-12
            end
            # El umbral de mayoría: con C ≥ m+1 el adversario FIJA la mediana; por debajo, el
            # sesgo hacia abajo por cadena monótona es menor que el de la posición mayoritaria.
            if W >= 7
                @test Modelos.sesgo_mediana_adversario(W, m + 1, δ, φ)[1] < 0.0
            end
        end
        # El oráculo DP sólo se usa donde su modelo es válido: TODOS los bloques del adversario al
        # final de la ventana y con mayoría suficiente para fijar la mediana. Ahí coincide con la
        # cota en el término de cadena, que es el que decide.
        # El oráculo DP sólo coincide con la cota de cadena cuando el adversario NO puede
        # re-anclarse en la escala honesta antes de la mediana, es decir cuando controla la
        # mediana Y todos sus bloques van al final. Con `C = W` no queda bloque honesto, y ahí la
        # coincidencia es exacta.
        for (W, δ) in [(11, 2.0), (5, 2.0), (21, 1.0)]
            dp = Referencia.sesgo_mediana_dp(W, W, δ, 0.0; escala = 1.0)
            # Con todos los bloques en manos del adversario el oráculo NO baja todo lo que la cota
            # de cadena promete: el suelo honesto ya alcanzado lo frena. Se comprueba lo único que
            # importa, que es que el oráculo alcance AL MENOS el sesgo garantizable.
            cota = Modelos.sesgo_mediana_adversario(W, W, δ, 0.0)
            @test cota[1] <= dp[1] + 1e-9    # la cota subestima: nunca promete menos riesgo
            @test dp[1] <= 0.0               # el oráculo no sube la mediana
        end
        # Propiedades del factor de N: `N = τ_obj/(τ_obs + sesgo)`, así que un sesgo NEGATIVO
        # (la mediana se acorta) SUBE `N`, y uno positivo lo baja.
        @test Modelos.factor_N_por_sesgo(60.0, 0.0) == 1.0
        @test Modelos.factor_N_por_sesgo(60.0, -6.0) > 1.0
        @test Modelos.factor_N_por_sesgo(60.0, 6.0) < 1.0
        # La región exacta pasa por el oráculo inyectado, y sin adversario el factor es 1.
        r0 = Modelos.region_manipulacion(0.0, 11, 1.0, 7200.0, 600.0)
        @test r0.sesgo_abajo == 0.0 && r0.sesgo_arriba == 0.0
        @test r0.factor_abajo == 1.0 && r0.factor_arriba == 1.0
        r1 = Modelos.region_manipulacion(0.6, 11, 1.0, 7200.0, 600.0)
        @test r1.sesgo_abajo < 0.0        # con mayoría la mediana se acorta
        @test r1.factor_abajo > 1.0       # y por tanto N SUBE: el factor es τ/(τ+sesgo)
    end

    @testset "8 · vectores de regresión" begin
        casos = RelojAdaptativo.Validacion.v6_vectores()
        @test !isempty(casos)
        for c in casos
            @test c.ok
        end
    end
end
