"""
Modelo AV-1 — sorteo secreto verificable después, falta «elegido sin voto» y su consecuencia.

Reglas del proyecto (V-ZRX/LINEO.md): tipos concretos, sin globals dinámicos, funciones puras,
sin @fastmath. Cómputo ligero: fórmulas cerradas con verificación por enumeración/Monte Carlo
en referencia.jl.

Convenciones heredadas de FV-1 (P-ZRX/P-FINALIDAD-VOTOS/resultados-FV1/):
  a      = fracción del peso TOTAL del atacante (registrado, con garantía).
  b      = prima de disponibilidad (FV-D05: b = 2 es la decisión vigente; se barre b ∈ [1,10]).
  K      = plazas por instancia (sorteo con reemplazo, FV-07).
  q_a(a,b) = a·b / (a·b + 1 − a)   — fracción esperada de plazas del atacante bajo censura total
             de las pruebas de disponibilidad honestas (FV-1, INFORME.md §1(a); [S]).
  a_pausa(b) = 1/(2b+1), a_rompe(b) = 2/(b+2)  — umbrales de pausa/ruptura de FV-1 [S].

Símbolos nuevos de AV-1:
  m_aus       = confiscación fija o proporcional por incidente de ausencia (símbolo de la orden).
  f_aus       = si m_aus es proporcional, fracción de la garantía de la clave confiscada.
  D_prima     = duración (en instancias) de la pérdida de la prima b tras un incidente.
  T_instancia = duración esperada de una instancia (slots o segundos; símbolo, Δ no medida IPA B-05).
  N_ventana   = número de instancias por ventana de compromiso (esquema C, Merkle).
  m_split     = número de claves en que el atacante reparte su peso `a` (concentración vs fragmentación).
"""
module Modelo

export q_a, a_pausa, a_rompe, p_necesaria,
       peso_efectivo, prob_elegido_binom, prob_al_menos_una_plaza,
       incidentes_por_instancia, costo_pausa_hora_fijo, costo_pausa_hora_proporcional,
       bytes_dia_esquema1, bytes_dia_esquema3, bytes_ventana_esquema3,
       perdida_esperada_honesto_anual, tasa_fp_censura, q_ev,
       a_eff_retirada, region_m_aus_vacia

# ---------------------------------------------------------------------------
# 1. Fórmulas heredadas de FV-1 (recalculadas aquí, no importadas: zona AV1
#    es de solo escritura propia; se contrastan por test con los valores
#    publicados en FV-1/INFORME.md, [S]).
# ---------------------------------------------------------------------------

"Fracción esperada de plazas del atacante bajo censura total de la prima honesta (FV-1 §1(a))."
q_a(a::Float64, b::Float64) = (a * b) / (a * b + (1.0 - a))

"Umbral de peso al que q_a(a,b) = 1/3 (pausa). FV-1: a_pausa(b) = 1/(2b+1)."
a_pausa(b::Float64) = 1.0 / (2.0 * b + 1.0)

"Umbral de peso al que q_a(a,b) = 2/3 (ruptura). FV-1: a_rompe(b) = 2/(b+2)."
a_rompe(b::Float64) = 2.0 / (b + 2.0)

"Participación honesta mínima para sellar sin atacante activo (FV-1 §1(d))."
p_necesaria(a::Float64, b::Float64) = (2.0 * (a * b + 1.0 - a)) / ((1.0 - a) * (b + 2.0))

# ---------------------------------------------------------------------------
# 2. Sorteo con reemplazo (FV-07): K plazas, peso efectivo = peso × (b si hay
#    prueba vigente, 1 en otro caso). Modelo binomial de "ganar ≥1 plaza".
# ---------------------------------------------------------------------------

"Peso efectivo de una clave con fracción de peso `w` y prima activa `activa::Bool`."
peso_efectivo(w::Float64, b::Float64, activa::Bool) = activa ? w * b : w

"""
Probabilidad de que una clave con fracción de peso efectivo `s` (share del peso
efectivo TOTAL, s = peso_efectivo(P) / Σ peso_efectivo) gane exactamente `j`
de las `K` plazas (con reemplazo, aproximación binomial estándar de sorteo
ponderado tipo Algorand — [S] SOSP'17 §Sortition).
"""
function prob_elegido_binom(s::Float64, K::Int, j::Int)
    @assert 0.0 <= s <= 1.0
    @assert 0 <= j <= K
    # Binomial(K, s) en j.  log-espacio para evitar desbordes con K grande.
    logc = loggamma1p(K) - loggamma1p(j) - loggamma1p(K - j)
    logp = logc + j * log(s) + (K - j) * log1p(-s)
    return exp(logp)
end

"loggamma(n+1) sin SpecialFunctions (evita dependencia extra; suma de logs, exacto por Float64)."
function loggamma1p(n::Int)
    n < 0 && throw(DomainError(n))
    n == 0 && return 0.0
    s = 0.0
    @inbounds for k in 2:n
        s += log(k)
    end
    return s
end

"""
Probabilidad de ganar AL MENOS una de las `K` plazas = 1 − (1−s)^K.
Es el evento «elegido» de la falta AV-1: la identidad de oportunidad es
(public_key, n), FV-EVP-01-símil — se firma como mucho un valor por instancia
(FV-11), así que lo que importa es el evento binario, no el número de plazas.
"""
prob_al_menos_una_plaza(s::Float64, K::Int) = 1.0 - (1.0 - s)^K

# ---------------------------------------------------------------------------
# 3. Incidentes esperados por instancia del atacante bajo la falta AV-1,
#    según reparta su peso efectivo total `a_eff` en `m_split` claves iguales.
#    Hallazgo central de AV-1: con m_aus FIJO, concentrar (m_split pequeño)
#    minimiza el número de incidentes; fragmentar (m_split grande) lo maximiza
#    y tiende a a_eff·K (límite de Poisson).
# ---------------------------------------------------------------------------

function incidentes_por_instancia(a_eff::Float64, K::Int, m_split::Int)
    @assert m_split >= 1
    @assert 0.0 <= a_eff < 1.0
    s = a_eff / m_split
    return m_split * prob_al_menos_una_plaza(s, K)
end

"""
Coste absoluto de la pausa por hora para el atacante, con `m_aus` FIJO por
incidente (no proporcional a la garantía). `m_split=1` es la estrategia que
MINIMIZA el coste del atacante (concentración): con K·a_eff ≫ 1, el coste
tiende a `m_aus / T_instancia_horas`, INDEPENDIENTE de `a`.
"""
function costo_pausa_hora_fijo(a::Float64, b::Float64, K::Int, m_aus::Float64,
                                T_instancia_horas::Float64; m_split::Int=1,
                                censura::Bool=false)
    a_eff = censura ? q_a(a, b) : a  # censura total desplaza el umbral (FV-1); sin censura, a_eff=a de forma conservadora
    inc = incidentes_por_instancia(a_eff, K, m_split)
    return m_aus * inc / T_instancia_horas
end

"""
Coste absoluto de la pausa por hora con `m_aus` PROPORCIONAL a la garantía de
cada clave: `m_aus(P) = f_aus × garantía(P)`. La garantía agregada de las
claves del atacante es `a × Garantia_total` con independencia de `m_split`
(el peso se suma, RFT-05), así que el coste POR INCIDENTE de una clave que
tiene una fracción `a/m_split` del peso total es `f_aus × (a/m_split) ×
Garantia_total`, y el coste total por hora es INDEPENDIENTE de `m_split`
(a diferencia del caso fijo): concentrar o fragmentar da el mismo coste
esperado, porque el `m_aus` de cada incidente ya escala con lo que arriesga
esa clave.
"""
function costo_pausa_hora_proporcional(a::Float64, b::Float64, K::Int, f_aus::Float64,
                                        Garantia_total::Float64, T_instancia_horas::Float64;
                                        m_split::Int=1, censura::Bool=false)
    a_eff = censura ? q_a(a, b) : a
    s = a_eff / m_split
    garantia_por_clave = (a / m_split) * Garantia_total
    inc_por_clave = prob_al_menos_una_plaza(s, K)
    costo_por_instancia = m_split * inc_por_clave * f_aus * garantia_por_clave
    return costo_por_instancia / T_instancia_horas
end

# ---------------------------------------------------------------------------
# 4. Datos por granjero y día de cada esquema de sorteo verificable después.
# ---------------------------------------------------------------------------

"Tamaño de una prueba ECVRF-EDWARDS25519-SHA512-TAI: ptLen+cLen+qLen = 32+16+32 (RFC 9381 §5.1, [P])."
const TAM_PRUEBA_VRF_BYTES = 80.0

"""
Esquema A1 «publicación completa»: 1 prueba VRF por instancia por clave,
publicada individualmente (una transacción por instancia, con `overhead_tx`
bytes de cabecera mínima además de la prueba).
"""
function bytes_dia_esquema1(instancias_dia::Float64; overhead_tx::Float64=20.0)
    return instancias_dia * (TAM_PRUEBA_VRF_BYTES + overhead_tx)
end

"""
Esquema A3 «compromiso Merkle por ventana + revelación total obligatoria»
(diseño recomendado de este informe, variante de A3/A4 con revelación
completa en vez de auditoría aleatoria): 1 tx de compromiso (raíz de 32 B +
overhead) por ventana, más 1 tx de revelación en bloque con `N_ventana`
pruebas (80 B cada una, sin overhead de tx repetido: framing amortizado).
"""
function bytes_ventana_esquema3(N_ventana::Int; overhead_commit::Float64=52.0,
                                 overhead_reveal_framing::Float64=20.0)
    commit = overhead_commit  # 32 B raíz + 20 B overhead de tx
    reveal = overhead_reveal_framing + N_ventana * TAM_PRUEBA_VRF_BYTES
    return commit + reveal
end

function bytes_dia_esquema3(instancias_dia::Float64, N_ventana::Int;
                             overhead_commit::Float64=52.0, overhead_reveal_framing::Float64=20.0)
    ventanas_dia = instancias_dia / N_ventana
    return ventanas_dia * bytes_ventana_esquema3(N_ventana;
                                                  overhead_commit=overhead_commit,
                                                  overhead_reveal_framing=overhead_reveal_framing)
end

# ---------------------------------------------------------------------------
# 5. Pérdida esperada del honesto por perfil (encendido 24h; 16h/día;
#    un apagón al mes), con y sin premio al voto.
# ---------------------------------------------------------------------------

"""
Fracción de instancias en las que la clave está SIN prima (apagada / sin
prueba de disponibilidad vigente), según el perfil:
  :siempre_encendido -> 0.0
  :dieciseis_horas    -> 8/24 (8 h apagado de 24)
  :apagon_mensual     -> (duración del apagón en horas) / (horas del mes)
"""
function fraccion_tiempo_apagado(perfil::Symbol; horas_apagon::Float64=6.0)
    if perfil === :siempre_encendido
        return 0.0
    elseif perfil === :dieciseis_horas
        return 8.0 / 24.0
    elseif perfil === :apagon_mensual
        return horas_apagon / (30.0 * 24.0)
    else
        throw(ArgumentError("perfil desconocido: $perfil"))
    end
end

"""
Pérdida anual esperada de un honesto con fracción de peso individual `f_h`
(share del peso efectivo total cuando tiene prima, y de `f_h` sin factor `b`
cuando no la tiene), bajo el alcance `(i)`: paga si sale elegido, tenga o no
prima. `premio_voto` es la recompensa por voto emitido (0.0 si no se premia,
D3 de la orden pendiente).

`m_aus` puede ser fijo (Float64) o, si `proporcional=true`, se interpreta como
`f_aus` y se multiplica por `garantia_propia`.
"""
function perdida_esperada_honesto_anual(f_h::Float64, b::Float64, K::Int,
                                         instancias_dia::Float64, perfil::Symbol,
                                         m_aus::Float64; horas_apagon::Float64=6.0,
                                         premio_voto::Float64=0.0,
                                         proporcional::Bool=false, garantia_propia::Float64=0.0)
    frac_apagado = fraccion_tiempo_apagado(perfil; horas_apagon=horas_apagon)
    instancias_anio = instancias_dia * 365.0
    instancias_apagado_anio = instancias_anio * frac_apagado
    instancias_encendido_anio = instancias_anio - instancias_apagado_anio

    # Mientras apagado: peso efectivo = f_h (sin prima). Mientras encendido: f_h·b.
    p_elegido_apagado = prob_al_menos_una_plaza(f_h, K)          # aprox. por instancia
    p_elegido_encendido = prob_al_menos_una_plaza(min(f_h * b, 1.0), K)

    monto = proporcional ? m_aus * garantia_propia : m_aus

    # Incidentes esperados: solo cuenta «elegido y sin voto». Se asume que
    # mientras está APAGADO no puede votar nunca si sale elegido (perfil
    # honesto que apaga la máquina, sin firmante remoto). Mientras ENCENDIDO,
    # el honesto vota siempre que sale elegido (perfil sin fallo adicional):
    # el único término de pérdida "encendido" es el LUCRO CESANTE si hubiera
    # premio y el honesto perdiera votos por otra causa — aquí se deja en 0
    # salvo el caso de falsos positivos (ver tasa_fp_censura).
    incidentes_apagado_anio = instancias_apagado_anio * p_elegido_apagado
    perdida_confiscacion = incidentes_apagado_anio * monto

    # Lucro cesante del premio: mientras dure la pérdida de prima tras un
    # incidente, el honesto encendido pierde `premio_voto` por cada plaza que
    # ANTES habría ganado con prima y ahora gana solo a peso 1. Aproximación
    # de primer orden (D_prima se pasa aparte, ver `lucro_cesante_prima`).
    return (perdida_confiscacion=perdida_confiscacion,
            incidentes_apagado_anio=incidentes_apagado_anio,
            p_elegido_apagado=p_elegido_apagado,
            p_elegido_encendido=p_elegido_encendido)
end

"""
Lucro cesante esperado por la pérdida de la prima durante `D_prima`
instancias tras un incidente, para una clave encendida con peso `f_h` y
premio por voto `premio_voto`: diferencia de plazas esperadas con prima `b`
frente a sin prima (peso 1), multiplicada por el premio.
"""
function lucro_cesante_prima(f_h::Float64, b::Float64, K::Int, D_prima::Int, premio_voto::Float64)
    plazas_con_prima = K * min(f_h * b, 1.0)
    plazas_sin_prima = K * f_h
    return D_prima * (plazas_con_prima - plazas_sin_prima) * premio_voto
end

# ---------------------------------------------------------------------------
# 6. Tasa de falsos positivos por censura (defensa del plazo de gracia,
#    patrón de SL-2b q_ev(c) = 1 − c^n).
# ---------------------------------------------------------------------------

"Probabilidad de que un honesto NO logre incluir su voto/revelación pese a `n` oportunidades independientes bajo censura de fracción `c` (SL-2b, [S])."
q_ev(c::Float64, n::Int) = 1.0 - c^n

"Tasa de falso positivo por censura: 1 − q_ev, con n=1 (una sola oportunidad) o n=ventana de gracia."
tasa_fp_censura(c::Float64, n::Int) = c^n

# ---------------------------------------------------------------------------
# 7. Denominador encogido por retirada (comparador iv, PROGRAMA.md/DECISIONES).
# ---------------------------------------------------------------------------

"Fracción del peso ACTIVO que controla el atacante si una fracción `r` del peso honesto se retira (comparador iv)."
a_eff_retirada(a::Float64, r::Float64) = a / (a + (1.0 - a) * (1.0 - r))

# ---------------------------------------------------------------------------
# 8. Región de m_aus (o f_aus): borde inferior de disuasión y superior de
#    honestidad, patrón de SL-2 (region_tv), adaptado.
# ---------------------------------------------------------------------------

"""
Devuelve `(vacia::Bool, f_aus_min, f_aus_max)` para el caso proporcional:
  - Borde inferior (disuasión): coste_pausa_hora_proporcional(a_ref,...) ≥ costo_min_hora.
  - Borde superior (honestidad): pérdida anual del peor perfil honesto ≤ frac_max·ingreso_anual.
`ingreso_anual(f_h)` y `costo_min_hora` son símbolos del informe (no de producto).
"""
function region_m_aus_vacia(a_ref::Float64, b::Float64, K::Int, Garantia_total::Float64,
                             T_instancia_horas::Float64, costo_min_hora::Float64,
                             f_h_peor::Float64, instancias_dia::Float64, horas_apagon::Float64,
                             ingreso_anual_f::Function, frac_max::Float64;
                             f_aus_grid::AbstractVector{Float64}=0.001:0.001:1.0)
    f_min = NaN
    f_max = NaN
    for f_aus in f_aus_grid
        costo_h = costo_pausa_hora_proporcional(a_ref, b, K, f_aus, Garantia_total, T_instancia_horas)
        if isnan(f_min) && costo_h >= costo_min_hora
            f_min = f_aus
        end
        res = perdida_esperada_honesto_anual(f_h_peor, b, K, instancias_dia, :apagon_mensual, f_aus;
                                              horas_apagon=horas_apagon, proporcional=true,
                                              garantia_propia=f_h_peor * Garantia_total)
        if res.perdida_confiscacion <= frac_max * ingreso_anual_f(f_h_peor)
            f_max = f_aus  # el último que cumple, se sigue actualizando (monótono creciente en f_aus => el máximo es el mayor que cumple)
        end
    end
    vacia = isnan(f_min) || isnan(f_max) || f_min > f_max
    return (vacia=vacia, f_aus_min=f_min, f_aus_max=f_max)
end

end # module
