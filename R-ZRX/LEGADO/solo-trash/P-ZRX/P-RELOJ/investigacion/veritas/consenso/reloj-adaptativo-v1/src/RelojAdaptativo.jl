# RelojAdaptativo.jl — P-RELOJ: ¿puede adaptarse `N` sin regalar el reloj ni el coste de verificar?
#
# ESTRUCTURA (espejo de `veritas/LINEO.md` §1, con los nombres que pide `PROMPT.md` §6):
#   modelos.jl     — los tres modelos matemáticos y las magnitudes medidas
#   medicion.jl    — puente con las mediciones de C (desviación de LINEO, argumentada)
#   referencia.jl  — oráculos exactos y fuerza bruta (pequeños y lentos, a propósito)
#   rapido.jl      — rutas de producción, Float64, sin asignaciones en el bucle
#   validacion.jl  — equivalencia referencia/rapido, invariantes y bordes
#
# NINGÚN parámetro de ZEROX se fija en este paquete. `N`, `N_max`, `τ`, `ρ`, `ε`, `K`, el FTL y la
# ganancia del controlador son ENTRADAS de las funciones.

module RelojAdaptativo

include("medicion.jl")
include("modelos.jl")
using .Modelos
using .Modelos: Maquina, MAQUINA_REF, CICLOS_POR_RONDA, CICLOS_POR_BLOQUE, Adaptador, Traza,
                traza_vacia, frontera_rapida, frontera_referencia, dispersion_maxima,
                admite_dispersion, dispersion_admitida, epsilon_minimo, N_verificable, en_dominio_pot04,
                N_desde_objetivo, U32_MAX, N_MAX_TIPO, simular!, hardware_alternante,
                amplitud_geometrica, amplitud_periodo, manipulacion_maxima,
                sesgo_mediana_adversario, factor_N_por_sesgo, region_manipulacion

include("referencia.jl")
using .Referencia

include("rapido.jl")
using .Rapido
include("validacion.jl")
using .Validacion

# ---------------- API pública, con nombres que no colisionan con los internos del modelo

"""
Presupuesto de verificación: qué dispersión admite. Todo son entradas.

`rho_max = eps*K` es un TECHO sobre `rho = t_s/t_f` (cuántas veces más lenta es la lenta), no un
suelo. `eps_min(rho)` es el presupuesto mínimo que admite una dispersión dada.
"""
presupuesto(ε::Real, K::Integer) = (dispersion_maxima = dispersion_maxima(ε, K),
                                    rho_max = dispersion_admitida(ε, K),
                                    admite_2x = admite_dispersion(ε, K, 2.0),
                                    admite_4x = admite_dispersion(ε, K, 4.0))

"Frontera rápida (`Float64`) de `(ADM)`. Devuelve `(admisible, ε_min, N_max)`."
frontera(tp::Float64, tv::Float64, K::Integer, ε::Float64, τ::Float64) =
    frontera_rapida(tp, tv, K, ε, τ)

"Frontera exacta (`Rational{BigInt}`) de `(ADM)`. Usar en las decisiones de borde."
frontera_exacta(tp, tv, K, ε, τ) = frontera_referencia(tp, tv, K, ε, τ)

"`N` máximo verificable en `ε·τ` con `tv` segundos por bloque."
N_max_verificable(ε::Real, τ::Real, tv::Real) = N_verificable(ε, τ, tv)

"Dominio de `C-POT-04`. Estado fuera de dominio: `Pendiente`, nunca `Inválido`."
dominio_pot04(N::Integer) = en_dominio_pot04(N)

"Mayor `N` del dominio de `C-POT-04` con `N·t ≤ τ`."
N_para_objetivo(τ::Real, t::Real) = N_desde_objetivo(τ, t)

"Sesgo máximo de la mediana con `α` de los slots y ventana `W`."
sesgo_mediana(α::Real, W::Integer, δ::Real, φ::Real, τ_obs::Real) =
    manipulacion_maxima(α, W, δ, φ, τ_obs)

"Simula el adaptador en la ruta rápida. `t` debe venir de `traza_vacia`."
simular_rapido!(t::Traza, hw::Vector{Float64}, p::Adaptador) = Rapido.simular_rapido!(t, hw, p)

"Corre las validaciones de `validacion.jl`. Devuelve un `NamedTuple` con los resultados."
validar(; kwargs...) = Validacion.ejecutar(; kwargs...)

end # module
