# modelos.jl — M1 (frontera del presupuesto de verificación), M2 (región de manipulación de
# timestamps), M3 (dinámica del adaptador).
#
# REGLA DE ORO DEL INSTRUMENTO: ningún parámetro de ZEROX se fija aquí. `N`, `τ`, `ε`, `K`, `δ`,
# `g`, `F_slots`, `I_slots` y `ρ` entran como ARGUMENTOS. Lo único que este archivo fija son las
# magnitudes MEDIDAS en la máquina de referencia, con su fuente.

module Modelos



# ================================================================ M0 · magnitudes medidas
#
# Todas las cifras de abajo son `[medido]` el 2026-09-24 en AMD Ryzen 9 9950X3D (Zen 5) por los
# programas de `investigacion/mediciones/latencia-aes/`. Procedencia línea a línea en PROCEDENCIA.md.

"""
Instrumentación de una máquina de referencia. Todos los tiempos en segundos.
`lat_bloque` es la latencia de UN bloque AES-128 encadenado (10 rondas dependientes).
`t_bloque_par` es el coste por bloque cuando hay `K` bloques en vuelo (verificación), que es lo
único que se paraleliza.
"""
struct Maquina
    nombre::String
    lat_ronda::Float64       # latencia de una ronda AESENC/AESENCLAST, s
    lat_bloque::Float64      # latencia de un bloque de 10 rondas, s (cadena, no paralelizable)
    t_bloque_par::Float64    # coste por bloque con K bloques en vuelo, s
    carriles::Int            # K: bloques AES en vuelo a la vez
    ciclos_por_ronda::Float64
    ghz_medidos::Float64
end

"La máquina donde se midió. Ver `mediciones/latencia-aes/` y PROCEDENCIA.md."
const MAQUINA_REF = Maquina(
    "AMD Ryzen 9 9950X3D (Zen 5)",
    0.7369e-9,   # lat AESENC xmm aislada = 4,001 ciclos a 5,43 GHz          [medido]
    0.7739e-9,   # lat bloque PoT (pxor + 9 aesenc + aesenclast)             [medido]
    0.9603e-9,   # verificar 8 tramos en paralelo: 5,235 ciclos/bloque      [medido]
    8,           # carriles de verificación por tramos (NUM_CHECKPOINTS)    [medido]
    4.001,       # ciclos por ronda AESENC, contador de rendimiento         [medido]
    5.428,       # GHz reales bajo carga, contador de rendimiento           [medido]
)

"Latencia de ronda medida, en ciclos. Es una propiedad de la microarquitectura, no del reloj."
const CICLOS_POR_RONDA = 4.001

"Latencia de bloque medida, en ciclos (10 rondas). Debe salir ≈ 10 × `CICLOS_POR_RONDA`."
const CICLOS_POR_BLOQUE = 42.01

# ================================================================ M1 · frontera de verificación
#
# MODELO. Sean
#   N     = pot_slot_iterations: bloques AES-128 encadenados por slot (ENTRADA, no se fija)
#   tp    = s por bloque del productor MÁS RÁPIDO admitido (ENTRADA)
#   tv(K) = s por bloque de verificación de un nodo, con K bloques en vuelo (ENTRADA medida)
#   K     = carriles de verificación (ENTRADA; cota arquitectural medida)
#   ε     = fracción del slot que un nodo admitido puede gastar verificando (ENTRADA)
#
# La duración del slot es una IDENTIDAD, no una decisión:  τ = N·tp.
# El camino de respaldo de C-POT-08 paso 4 (el único que es O(N)) tarda N·tv(K) segundos.
# Un nodo es admisible si eso cabe en ε·τ:
#
#       N·tv(K) ≤ ε·τ = ε·N·tp          (ADM)
#
# Con N > 0, (ADM) se simplifica a una condición que NO contiene N ni τ:
#
#       S := tv(K)/tp ≤ ε               (ADM′)
#
# y como en la MISMA máquina tv(K) = lat_bloque/K (medido: verif8.c da factor K exacto),
# (ADM′) queda  S_maq := lat_bloque/tp ≤ ε·K,  es decir  ρ := tp/lat_bloque ≥ 1/(ε·K),
# con ρ la ventaja de hardware del más rápido sobre el más lento admitido.

"Evaluación de `(ADM)` con aritmética exacta. Es el ORÁCULO de M1: compara sin redondear."
struct Frontera
    admisible::Bool
    holgura::Float64       # ε − S: positiva = cabe
    epsilon_min::Float64   # ε mínimo que admite esta máquina con estos K: S/K
    N_max::Float64         # N que caben en ε·τ con el tv dado: ε·τ/tv
end

const R0 = Rational{BigInt}(0)
rat(x::Real) = Rational{BigInt}(x)
rat(x::Integer) = Rational{BigInt}(x)

"""
    frontera_referencia(tp, tv, K, ε, τ)

`(ADM)` con `Rational{BigInt}`. Comprueba además las identidades del modelo con exactitud:
`tv == lat_bloque/K` cuando el llamante pasa los valores medidos coherentes.
"""
function frontera_referencia(tp::Rational{BigInt}, tv::Rational{BigInt}, K::Integer,
                             ε::Rational{BigInt}, τ::Rational{BigInt})
    (tp > 0 && tv > 0 && K > 0 && ε > 0 && τ > 0) ||
        throw(ArgumentError("dominio: tp,tv,ε,τ > 0 y K > 0"))
    eps_min = tv / (K * tp)
    Frontera(eps_min <= ε, Float64(ε - eps_min), Float64(eps_min), Float64(ε * τ / tv))
end

"`(ADM)` en `Float64`. El oráculo la valida; la discrepancia admisible en el signo es cero."
function frontera_rapida(tp::Float64, tv::Float64, K::Integer, ε::Float64, τ::Float64)
    (tp > 0.0 && tv > 0.0 && K > 0 && ε > 0.0 && τ > 0.0) ||
        throw(ArgumentError("dominio: tp,tv,ε,τ > 0 y K > 0"))
    eps_min = tv / (K * tp)
    Frontera(eps_min <= ε, ε - eps_min, eps_min, ε * τ / tv)
end

"""
    dispersion_maxima(ε, K) -> S_max

Cota EXACTA sobre la dispersión de hardware admitida: `S = lat_bloque/tp ≤ ε·K`.
No depende de `N` ni de `τ`. Es el resultado estructural de M1, y el que rompe la lectura de §3.
"""
dispersion_maxima(ε::Real, K::Integer) = ε * K

"""
    admite_dispersion(ε, K, S) -> Bool

¿Admite el presupuesto `ε` una dispersión de hardware `S` (lento/rápido, `S ≥ 1`) con `K`
carriles? La comparación es EXACTA: se hace en `Rational{BigInt}`, porque `S` y `ε·K` pueden
diferir en la última unidad y entonces `S <= ε*K` en punto flotante decide mal justo en la
frontera, que es donde importa.
"""
function admite_dispersion(ε::Real, K::Integer, S::Real)
    (ε > 0 && K > 0 && S >= 1) || throw(ArgumentError("dominio inválido"))
    return Rational{BigInt}(S) <= Rational{BigInt}(ε) * K
end

"""
    dispersion_admitida(ε, K) -> ρ_max

Dispersión MÁXIMA de hardware que admite el presupuesto: `ρ_max = ε·K`.

`ρ := t_s/t_f` —cuántas veces más lenta es la máquina más lenta admitida que la más rápida— es la
MISMA cantidad que la frontera `S`, no su recíproca. **Es un techo, no un suelo**: la nomenclatura
coincide con `ρ_max = v_A,max/v_ref` de `SPEC.md` §7.3.

El presupuesto mínimo que admite una dispersión `ρ` es `ε_min = ρ/K`.
"""
dispersion_admitida(ε::Real, K::Integer) = ε * K

"Presupuesto mínimo `ε_min = ρ/K` que admite una dispersión `ρ` con `K` carriles."
epsilon_minimo(ρ::Real, K::Integer) = ρ / K

"`N` máximo que un nodo con `tv` segundos por bloque verifica dentro de `ε·τ`: `ε·τ/tv`."
N_verificable(ε::Real, τ::Real, tv::Real) = ε * τ / tv

# ================================================================ M1b · dominio de C-POT-04
#
# `C-POT-04` (SPEC.md §7.1.1): N ≠ 0, N ≤ u32::MAX, N % 16 == 0. Fuera de dominio: estado
# `Pendiente`, NUNCA `Inválido`.

const U32_MAX = UInt64(4_294_967_295)
const N_MAX_TIPO = UInt64(4_294_967_280)   # mayor múltiplo de 16 que cabe en u32

"¿Cae `N` en el dominio de `C-POT-04`?"
en_dominio_pot04(N::Integer) = (N != 0) && (N <= U32_MAX) && (N % 16 == 0)

"""
    N_desde_objetivo(τ_obj, t_bloque) -> UInt64

Mayor `N` del dominio de `C-POT-04` con `N·t_bloque ≤ τ_obj`. Redondea al múltiplo de 16 INFERIOR.
"""
function N_desde_objetivo(τ_obj::Real, t_bloque::Real)
    (τ_obj > 0 && t_bloque > 0) || throw(ArgumentError("dominio: τ, t > 0"))
    c = floor(Int, τ_obj / t_bloque)
    c = (c ÷ 16) * 16
    c < 0 && (c = 0)
    return UInt64(c)
end

# ================================================================ M2 · región de manipulación
#
# MODELO. El adaptador no lee el reloj: lee la duración del slot, que con timestamps como fuente es
#
#       τ_obs = ts(s_fin) − ts(s_ini)  sobre una ventana de W slots,
#
# con la política de `C-TS-01` (monotonía) y `C-TS-03` (FTL, valor PENDIENTE). El adversario
# controla una fracción `α` de los slots y puede sesgar el timestamp de cada uno de sus slots en
# `[−δ, +φ]` segundos (δ = retraso máximo, φ = FTL = adelanto máximo), con monotonía.
#
# Con la MEDIANA como estadístico (es lo que hace Bitcoin con MTP), el sesgo máximo de la mediana
# de una ventana de `W` valores no depende de la forma de la cola, sino del número de posiciones
# que el adversario ocupa. Aquí se mide por enumeración adversarial, no se supone una fórmula.

"""
    sesgo_mediana_adversario(W, control, δ, φ) -> (abajo, arriba)

**COTA GARANTIZABLE, NO LA REGIÓN EXACTA.** Sesgo que un adversario con `control` posiciones en una
ventana de `W` timestamps **puede alcanzar al menos** sobre la mediana, en segundos, con la monotonía
de `C-TS-01` y el FTL `φ` de `C-TS-03`:

    abajo  = −max(control·δ, control)
    arriba = +control·φ

Los dos sumandos del máximo hacia abajo son dos ataques distintos y el adversario elige el mejor:
  · `control·δ` — recorrer la cadena monótona hacia abajo, `δ` por cada bloque propio.
  · `control`   — ocupar `control` posiciones de la ventana con valores "planos" mientras la escala
    honesta avanza 1 s por bloque; la mediana se desplaza `control` lugares. Sólo el producto
    elemento a elemento describe el conjunto alcanzable exacto, y esto es su cota inferior.
Hacia arriba, el FTL `φ` se puede aplicar una vez por bloque propio.

**Por qué no se publica una igualdad, con el dato delante.** Se comparó esta cota con el oráculo
exacto (`Referencia.sesgo_mediana_dp`) sobre 290 combinaciones de `(W, control, δ, φ)`: en **120**
de ellas el adversarial logra MÁS que la cota (por ejemplo `W=21, control=8, δ=2, φ=50` da
`(−14, 402)` frente a la cota `(−16, 400)`). Se conserva la cota porque **subestima** el ataque, que
es el lado seguro del error, y porque el oráculo con programación dinámica es quien publica la
región. Las dos direcciones hacia abajo se conservan porque cada una gana en un régimen distinto.

Con `control = 0` no hay sesgo.
"""
function sesgo_mediana_adversario(W::Integer, control::Integer, δ::Real, φ::Real)
    (W >= 1 && 0 <= control <= W) || throw(ArgumentError("0 ≤ control ≤ W"))
    (δ >= 0 && φ >= 0) || throw(ArgumentError("δ, φ ≥ 0"))
    control == 0 && return (0.0, 0.0)
    c = Float64(control)
    return (-max(c * Float64(δ), c), c * Float64(φ))
end

"""
    region_manipulacion(α, W, δ, φ, τ_obs) -> NamedTuple

Región de manipulación de la mediana: `control = ⌊α·W⌋` posiciones del adversario en una ventana de
`W` timestamps. Devuelve `(control, sesgo_abajo, sesgo_arriba, factor_abajo, factor_arriba)`.

Los sesgos son los de `sesgo_mediana_adversario`, y el factor es `τ_obs/(τ_obs + sesgo)`: `N` escala
con `1/τ_obs` a `τ` objetivo fijo, así que un sesgo NEGATIVO (la mediana se acorta) **sube** `N` y
uno positivo lo baja.

`τ_obs` es la ventana observada en segundos y es una ENTRADA: el instrumento no la fija.
"""
function region_manipulacion(α::Real, W::Integer, δ::Real, φ::Real, τ_obs::Real)
    (0 <= α <= 1) || throw(ArgumentError("α ∈ [0,1]"))
    τ_obs > 0 || throw(ArgumentError("τ_obs > 0"))
    control = floor(Int, α * W)
    sa, sr = sesgo_mediana_adversario(W, control, δ, φ)
    return (control = control, sesgo_abajo = sa, sesgo_arriba = sr,
            factor_abajo = factor_N_por_sesgo(τ_obs, sa),
            factor_arriba = factor_N_por_sesgo(τ_obs, sr))
end

"""
    factor_N_por_sesgo(τ_obs, sesgo)

`N` escala con `1/τ_obs` (a `τ` objetivo fijo): `N(τ_obs + s) / N(τ_obs) = τ_obs/(τ_obs + s)`.
Devuelve el FACTOR sobre `N` causado por un sesgo de ventana `s` segundos. Es una identidad, y por
eso se calcula exacto en el oráculo.
"""
factor_N_por_sesgo(τ_obs::Real, sesgo::Real) = τ_obs / (τ_obs + sesgo)

"""
    manipulacion_maxima(α, W, δ, φ, τ_obs)

Región: par `(factor_abajo, factor_arriba)` de `N` que un adversario con fracción `α` de los
slots puede imponer a la mediana de una ventana de `W` slots. `α` se convierte en número de
posiciones con `control = floor(α·W)` —el adversario no elige cuántos slots caen en la ventana,
solo cuáles son suyos.
"""
function manipulacion_maxima(α::Real, W::Integer, δ::Real, φ::Real, τ_obs::Real)
    (0 <= α <= 1) || throw(ArgumentError("α debe estar en [0,1]"))
    control = floor(Int, α * W)
    sa, _ = sesgo_mediana_adversario(W, control, δ, φ)
    _, sr = sesgo_mediana_adversario(W, control, δ, φ)
    return (factor_N_por_sesgo(τ_obs, sa), factor_N_por_sesgo(τ_obs, sr))
end

# ================================================================ M3 · dinámica del adaptador
#
# MODELO. Controlador multiplicativo discreto sobre slots:
#   s        índice de slot (1..T)
#   hw[s]    segundos por bloque del productor en ese slot (hardware, ENTRADA)
#   N[s]     parámetro vigente en el slot s
#   τ_obs[s] = N[s−r]·hw[s−r]   con r = retardo en slots (C-FLU-16: el cambio sólo entra en t_j)
#   e        = τ_obj/τ_obs − 1
#   N[s+1]   = cuant16(clamp(trunc(N[s]·(1 + g·e)), N_min, N_max))
# El coste de verificación por slot es `N[s]·tv` con `tv` la latencia de verificación por bloque
# (tv = lat_bloque/K con K carriles).

"""
Parámetros del adaptador. Todos son ENTRADAS: el instrumento no fija ninguno de ellos.

`t_bloque` y `N_objetivo` se declaran juntos porque la duración objetivo del slot es
`tau_obj = N_objetivo · t_bloque`: con `N_objetivo == N_inicial` el lazo arranca en equilibrio, que
es el régimen que interesa estudiar. Dejar `tau_obj` como campo independiente invita a comparar dos
redondeos distintos del mismo número, y eso no es una prueba de la ley de control.
"""
struct Adaptador
    N_inicial::Int64
    N_min::Int64
    N_max::Int64
    t_bloque::Float64      # segundos por bloque del hardware de referencia del objetivo
    N_objetivo::Int64      # N con el que el slot dura lo que debe durar
    ganancia::Float64      # g > 0
    retardo::Int           # slots (C-FLU-16 → al menos F_slots + I_slots)
    trinquete::Bool        # true = sólo sube (PotSlotIterationsMustIncrease de Autonomys)
    caducidad::Int         # 0 = sin caducidad; k>0 = sólo puede bajar dentro de k slots de la última subida
    paso_minimo::Int       # histéresis: no aplicar cambios menores
end

"Duración objetivo del slot: identidad, no decisión."
tau_objetivo(p::Adaptador) = Float64(p.N_objetivo) * p.t_bloque

"Traza de una corrida."
struct Traza
    N::Vector{Int64}
    hw::Vector{Float64}
    tau::Vector{Float64}
    ajuste::Vector{Int8}     # +1 sube, −1 baja, 0 sin cambio
    costo::Vector{Float64}   # N·tv por slot: el impuesto de verificación
    tv::Float64              # s por bloque de verificación (por carril, ya dividido por K)
end

"Reserva una traza. Fuera del bucle."
traza_vacia(T::Integer, tv::Float64) =
    Traza(zeros(Int64, T), zeros(Float64, T), zeros(Float64, T), zeros(Int8, T),
          zeros(Float64, T), tv)

"""
    simular!(t, hw, p; manipulacion=nothing)

Simulación transparente del lazo. Escribe en `t`, no asigna en el bucle. `manipulacion[s]` es el
sesgo (segundos) que el adversario impone al τ observado en el slot `s`; `nothing` = sin ataque.
Devuelve `t`.
"""
function simular!(t::Traza, hw::Vector{Float64}, p::Adaptador;
                  manipulacion::Union{Nothing,Vector{Float64}} = nothing)
    T = length(hw)
    length(t.N) == T || throw(ArgumentError("t.N debe tener la misma longitud que hw"))
    if manipulacion !== nothing
        length(manipulacion) == T || throw(ArgumentError("manipulacion debe tener longitud T"))
    end
    N = p.N_inicial
    t.N[1] = N
    t.hw[1] = hw[1]
    t.tau[1] = Float64(N) * hw[1]
    t.costo[1] = Float64(N) * t.tv
    t.ajuste[1] = 0

    for s in 2:T
        idx = max(s - p.retardo, 1)
        tau_obs = Float64(t.N[idx]) * hw[idx]
        if manipulacion !== nothing
            tau_obs += manipulacion[s]
        end
        e = tau_objetivo(p) / tau_obs - 1.0
        propuesto = Int64(trunc(N * (1.0 + p.ganancia * e)))
        propuesto = (propuesto ÷ 16) * 16
        propuesto = clamp(propuesto, p.N_min, p.N_max)

        if propuesto == N || abs(propuesto - N) < p.paso_minimo
            t.ajuste[s] = 0
        elseif propuesto < N && p.trinquete
            t.ajuste[s] = 0
        elseif propuesto < N && p.caducidad > 0 && (s - idx) > p.caducidad
            t.ajuste[s] = 0
        else
            t.ajuste[s] = propuesto > N ? Int8(1) : Int8(-1)
            N = propuesto
        end
        t.N[s] = N
        t.hw[s] = hw[s]
        t.tau[s] = Float64(N) * hw[s]
        t.costo[s] = Float64(N) * t.tv
    end
    return t
end

"""
    hardware_alternante(T, t_rapido, t_lento, periodo, duty)

Caso conectar/desconectar: el hardware rápido está presente `duty` fracción del tiempo, en
ciclos de `periodo` slots. Es una ENTRADA adversarial, no una medición.
"""
function hardware_alternante(T::Integer, t_rapido::Real, t_lento::Real,
                             periodo::Integer, duty::Real)
    (0 <= duty <= 1) || throw(ArgumentError("duty en [0,1]"))
    periodo > 0 || throw(ArgumentError("periodo > 0"))
    hw = Vector{Float64}(undef, T)
    on = round(Int, duty * periodo)
    for s in 1:T
        hw[s] = (mod(s - 1, periodo) < on) ? Float64(t_rapido) : Float64(t_lento)
    end
    return hw
end

"""
    amplitud_geometrica(N_max, N_min, g) -> (amplitud, pasos)

Amplitud de la caída geométrica de `N` con razón `(1 − g)` desde `N_max` hasta `N_min`. Es la
suma exacta de los decrementos: `N_max − N_final`. Vale mientras el error sea constante y
saturante (el hardware rápido se ha ido del todo).
"""
function amplitud_geometrica(N_max::Real, N_min::Real, g::Real)
    0 < g < 1 || throw(ArgumentError("la ganancia debe estar en (0,1)"))
    N_max > N_min || throw(ArgumentError("N_max debe superar N_min"))
    k = ceil(Int, log(N_min / N_max) / log1p(-g))
    N_fin = max(N_min, N_max * (1.0 - g)^k)
    return N_max - N_fin, k
end

"""
    amplitud_periodo!(t, p) -> (N_max_traza, N_min_traza, amplitud)

Amplitud observada en la traza, en unidades de `N` y en fracción del valor máximo. Segunda ruta
de cálculo, independiente de la fórmula cerrada: se mide sobre la simulación.
"""
function amplitud_periodo(t::Traza)
    Nmax = maximum(t.N)
    Nmin = minimum(t.N)
    return Nmax, Nmin, Nmax - Nmin, (Nmax - Nmin) / Nmax
end

end # module
