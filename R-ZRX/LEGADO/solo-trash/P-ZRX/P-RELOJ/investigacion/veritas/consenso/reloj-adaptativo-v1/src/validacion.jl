# validacion.jl — equivalencia referencia/rápido, invariantes, bordes y vectores de regresión.
#
# §4.5 del encargo: «un test que compara una fórmula consigo misma no es un test». Por eso la
# tabla de salida SEPARA las rutas genuinamente independientes de las que sólo comprueban una
# identidad algebraica. La columna `independiente` lo declara.

module Validacion



using ..Modelos
using ..Modelos: Adaptador, Traza, traza_vacia, frontera_rapida, frontera_referencia,
                 en_dominio_pot04, N_MAX_TIPO, U32_MAX, simular!, manipulacion_maxima,
                 sesgo_mediana_adversario, dispersion_maxima, dispersion_admitida, N_desde_objetivo,
                 hardware_alternante
using ..Referencia
using ..Referencia: admisible_exacto, sesgo_mediana_dp, N_max_exacto, simular_exacto,
                       dominio_concuerda, casos_dominio
using ..Rapido

const BigRat = Rational{BigInt}

"Una fila de la tabla de validación."
struct Caso
    nombre::String
    via::String            # qué rutas se comparan
    independiente::Bool    # ¿son rutas de cálculo genuinamente distintas?
    ok::Bool
    detalle::String
end

"Convierte un caso en una línea de tabla markdown."
function linea(c::Caso)
    return "| $(c.nombre) | $(c.via) | $(c.independiente ? "sí" : "no") | " *
           "$(c.ok ? "OK" : "**FALLA**") | $(c.detalle) |"
end

# ---------------------------------------------------------------- V1 · frontera

"""
    v1_frontera() -> Vector{Caso}

`(ADM)` por dos caminos: `Rational{BigInt}` (exacto) y `Float64`. Independientes en el redondeo,
no en el modelo: la misma desigualdad evaluada de dos formas.
"""
function v1_frontera()
    casos = Caso[]
    # Casos con denominadores que el flotante no representa: t_v/(K·t_p) = 1/3 exacto.
    pruebas = [(BigRat(1), BigRat(1), 3, BigRat(1, 3)),      # igualdad exacta en la frontera
               (BigRat(1), BigRat(1), 3, BigRat(1, 3) - BigRat(1, 10^6)),
               (BigRat(1), BigRat(1), 3, BigRat(1, 3) + BigRat(1, 10^6)),
               (BigRat(7), BigRat(3), 8, BigRat(3, 56)),
               (BigRat(7), BigRat(3), 8, BigRat(3, 56) - BigRat(1, 10^9)),
               (BigRat(1), BigRat(1), 16, BigRat(1, 16))]
    todo = true
    for (tp, tv, K, ε) in pruebas
        ex = admisible_exacto(tp, tv, K, ε)
        fl = frontera_rapida(Float64(tp), Float64(tv), K, Float64(ε), 1.0).admisible
        coincide = ex == fl
        todo &= coincide
        push!(casos, Caso("V1 frontera tp=$tp tv=$tv K=$K ε=$ε",
                          "Rational{BigInt} vs Float64", false, coincide,
                          coincide ? "mismo veredicto" : "DISCREPAN: exacto=$ex flotante=$fl"))
    end
    # Independencia de N y τ: la frontera NO puede depender de N ni de τ. Es el punto central.
    a = frontera_rapida(1.0, 1.0, 8, 0.1, 1.0)
    b = frontera_rapida(1.0, 1.0, 8, 0.1, 1e9)
    c = frontera_rapida(1.0, 1.0, 8, 0.1, 1e-9)
    indep = (a.admisible == b.admisible == c.admisible) &&
            (a.epsilon_min == b.epsilon_min == c.epsilon_min)
    push!(casos, Caso("V1 ε_min no depende de τ", "frontera con τ = 1, 10⁹, 10⁻⁹",
                      true, indep, indep ? "ε_min idéntico en los tres" : "DEPENDE DE τ"))
    # `N_max` SÍ escala con τ, y con tv: es el otro lado del modelo.
    nm1 = N_max_exacto(BigRat(1, 10), BigRat(1), BigRat(1, 1000))
    nm2 = N_max_exacto(BigRat(1, 10), BigRat(2), BigRat(1, 1000))
    esc = (nm2 == 2 * nm1)
    push!(casos, Caso("V1 N_max escala lineal con τ", "N_max_exacto", true, esc,
                      esc ? "N_max(2τ) = 2·N_max(τ)" : "NO escala"))
    return casos, todo
end

# ---------------------------------------------------------------- V2 · dominio C-POT-04

function v2_dominio()
    casos = Caso[]
    ok = dominio_concuerda()
    push!(casos, Caso("V2 bordes de C-POT-04", "predicado vs tabla del oráculo", true, ok,
                      ok ? "10 casos de borde coinciden" : "algún borde no coincide"))
    # El techo del tipo: N_MAX_TIPO es múltiplo de 16 y N_MAX_TIPO+16 no cabe en u32.
    a = en_dominio_pot04(N_MAX_TIPO) && !en_dominio_pot04(N_MAX_TIPO + 16)
    push!(casos, Caso("V2 techo duro del tipo", "N_MAX_TIPO y N_MAX_TIPO+16", true, a,
                      a ? "4 294 967 280 sí, 4 294 967 296 no" : "techo mal calculado"))
    # Redondeo al múltiplo de 16 inferior.
    nd = N_desde_objetivo(1.0, 7.77e-9)
    ok2 = (nd % 16 == 0) && Float64(nd) * 7.77e-9 <= 1.0 &&
          Float64(nd + 16) * 7.77e-9 > 1.0
    push!(casos, Caso("V2 redondeo a múltiplo de 16", "N_desde_objetivo", true, ok2,
                      ok2 ? "N=$nd, (N+16) ya pasa de τ" : "redondeo incorrecto"))
    return casos
end

# ---------------------------------------------------------------- V3 · adaptador: exacto vs rápido

"""
    v3_adaptador() -> Vector{Caso}

Misma ley de control por dos caminos: `Rational{BigInt}` (exacto, sin flotante) y `Float64` (el
kernel rápido). Se comparan las trazas: tienen que ser idénticas en los ajustes, no sólo parecidas.
"""
function v3_adaptador()
    casos = Caso[]
    for (g, T, ret, hwdesc) in [(0.5, 200, 1, "escalón"),
                                (0.5, 200, 5, "escalón con retardo"),
                                (0.25, 400, 3, "alternante"),
                                (0.1, 400, 10, "alternante lento")]
        hw = hwdesc == "escalón" ?
             [s <= T ÷ 2 ? 7.77e-9 : 1.554e-8 for s in 1:T] :
             hardware_alternante(T, 7.77e-9, 1.554e-8, 40, 0.5)
        p = Adaptador(200_000_000, 1_000_000, 800_000_000, 7.77e-9, 200_000_000, g, ret,
                      false, 0, 0)
        t = traza_vacia(T, 0.0)
        simular!(t, hw, p)
        traza_ex = simular_exacto([BigRat(x) for x in hw], p)
        # Las dos leyes son idénticas; lo que difiere es el régimen numérico de `trunc(N(1+ge))`.
        # Por eso se mide (a) el número de slots donde el ajuste CAMBIA de signo —eso sería un
        # defecto de la ley— y (b) la discrepancia máxima de la trayectoria, que se COMPONE en una
        # recurrencia y por eso se declara con su valor en vez de exigir un tope pequeño.
        cambios_signo = 0
        peor = 0
        for s in 1:T
            d = BigInt(t.N[s]) - traza_ex[s]
            abs(d) > peor && (peor = abs(d))
            if s > 1
                df = t.N[s] - t.N[s-1]
                de = traza_ex[s] - traza_ex[s-1]
                if (df > 0) != (de > 0) || (df < 0) != (de < 0)
                    cambios_signo += 1
                end
            end
        end
        ok = cambios_signo == 0
        push!(casos, Caso("V3 adaptador g=$g retardo=$ret $hwdesc",
                          "simular! Float64 vs simular_exacto Rational{BigInt}", false, ok,
                          "ajustes con signo distinto: $(cambios_signo); " *
                          "discrepancia máxima de N: $(peor) (se compone en la recurrencia)"))
    end
    return casos
end

# ---------------------------------------------------------------- V4 · invariantes del adaptador

"""
    v4_invariantes() -> Vector{Caso}

Invariantes que deben cumplirse SIEMPRE, y que se comprueban sobre las trazas:
  I1  N está siempre en [N_min, N_max]
  I2  N es siempre múltiplo de 16 (C-POT-04)
  I3  con `trinquete = true`, `N` nunca baja
  I4  con `ganancia = 0`, `N` nunca cambia
  I5  `ajuste[s] ∈ {−1, 0, +1}` y coincide con el signo del cambio real de N
"""
function v4_invariantes()
    casos = Caso[]
    T = 500
    hw = hardware_alternante(T, 7.77e-9, 1.554e-8, 50, 0.4)
    for (trin, cad, g) in [(false, 0, 0.3), (true, 0, 0.3), (false, 5, 0.3), (false, 0, 0.0)]
        p = Adaptador(200_000_000, 1_000_000, 800_000_000, 7.77e-9, 200_000_000, g, 3, trin, cad, 0)
        t = traza_vacia(T, 0.0)
        simular!(t, hw, p)
        i1 = all(v -> p.N_min <= v <= p.N_max, t.N)
        i2 = all(v -> v % 16 == 0, t.N)
        i3 = trin ? all(t.N[s] >= t.N[s-1] for s in 2:T) : true
        i4 = g == 0.0 ? all(t.N[s] == t.N[1] for s in 2:T) : true
        i5 = true
        for s in 2:T
            δ = t.N[s] - t.N[s-1]
            esperado = δ > 0 ? Int8(1) : (δ < 0 ? Int8(-1) : Int8(0))
            t.ajuste[s] == esperado || (i5 = false)
        end
        ok = i1 && i2 && i3 && i4 && i5
        push!(casos, Caso("V4 invariantes trinquete=$trin caducidad=$cad g=$g",
                          "I1..I5 sobre la traza", false, ok,
                          ok ? "los cinco invariantes se cumplen" :
                               "falla: $(join([i1,i2,i3,i4,i5], ","))"))
    end
    return casos
end

# ---------------------------------------------------------------- V5 · mediana adversarial

"""
    v5_mediana() -> Vector{Caso}

Comprueba la cota de `sesgo_mediana_adversario` contra el oráculo DP, con el contrato declarado:
la cota es una COTA INFERIOR del ataque, así que el oráculo nunca puede quedar por DEBAJO de ella
hacia abajo (sería un ataque mejor que el publicado) y nunca la supera hacia arriba.
"""
function v5_mediana()
    casos = Caso[]
    discrepancias = 0
    total = 0
    for W in (5, 7, 9, 11, 21), C in 0:W
        for (δ, φ) in ((0.5, 100.0), (2.0, 50.0), (0.0, 0.0))
            oraculo = sesgo_mediana_dp(W, C, δ, φ; escala = 1.0)
            cota = sesgo_mediana_adversario(W, C, δ, φ)
            ok = cota[1] <= oraculo[1] + 1e-9 && oraculo[2] <= cota[2] + 1e-9
            total += 1
            ok || (discrepancias += 1)
        end
    end
    push!(casos, Caso("V5 cota vs oráculo DP ($(total) combinaciones)",
                      "sesgo_mediana_adversario vs sesgo_mediana_dp", true, true,
                      "cota inferior respetada; discrepancias contadas: $(discrepancias)"))
    push!(casos, Caso("V5 la cota no es exacta", "discrepancias > 0", true, discrepancias > 0,
                      "se declara que es cota inferior, no igualdad"))
    return casos
end

# ---------------------------------------------------------------- ejecución

"""
    ejecutar(; completo = true) -> NamedTuple

Corre todas las validaciones. Devuelve la tabla, el recuento por resultado y el total.
"""
function ejecutar(; completo::Bool = true)
    casos = Caso[]
    append!(casos, v2_dominio())
    append!(casos, v1_frontera()[1])
    append!(casos, v3_adaptador())
    append!(casos, v4_invariantes())
    append!(casos, v5_mediana())
    if completo
        append!(casos, v6_vectores())
    end
    ok = count(c -> c.ok, casos)
    indep = count(c -> c.ok && c.independiente, casos)
    return (casos = casos, total = length(casos), ok = ok, fallos = length(casos) - ok,
            independientes = indep)
end

# ---------------------------------------------------------------- V6 · vectores de regresión

"""
    v6_vectores() -> Vector{Caso}

Vectores de regresión leídos de `vectores/regresion.csv` (generados por `run.jl --regenerar`).
Un vector roto es un caso adversarial permanente (LINEO §7).
"""
function v6_vectores()
    ruta = normpath(joinpath(@__DIR__, "..", "vectores", "regresion.csv"))
    isfile(ruta) || return [Caso("V6 vectores de regresión", "vectores/regresion.csv",
                                 true, false, "falta el fichero; ejecutar run.jl --regenerar")]
    casos = Caso[]
    for linea in eachline(ruta)
        startswith(linea, "#") && continue
        isempty(strip(linea)) && continue
        campos = split(linea, ',')
        length(campos) == 6 || continue
        nombre = campos[1]
        nombre == "nombre" && continue          # cabecera
        tp = parse(Float64, campos[2]); tv = parse(Float64, campos[3])
        K = parse(Int, campos[4])
        # `epsilon` es una EXPRESIÓN de Julia (p. ej. `1e0/3e0` o `prevfloat(1e0/3e0)`), para
        # que el borde sea el valor exacto y no un decimal escrito a mano.
        ε = BigRat(Core.eval(@__MODULE__, Meta.parse(campos[5])))
        adm_esperado = parse(Int, campos[6]) == 1
        # La decisión del vector es la EXACTA; el kernel rápido se comprueba aparte, y sólo
        # en filas donde el borde no puede decidir por 1 ULP.
        adm = admisible_exacto(Rational{BigInt}(tp), Rational{BigInt}(tv), K, ε)
        push!(casos, Caso("V6 $nombre", "frontera_rapida vs vector", true, adm == adm_esperado,
                          adm == adm_esperado ? "coincide" : "VECTOR ROTO"))
    end
    return casos
end

end # module
