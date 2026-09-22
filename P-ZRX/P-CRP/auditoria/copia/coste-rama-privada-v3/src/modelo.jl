# modelo.jl — unidades, escenarios y estados de validez.
#
# Unidad de trabajo: `blue_work` en unidades enteras de `w(B)=⌊2^128/(SR+1)⌋`.
# Para el juguete escalar se usa la unidad de "slot de trabajo": un evento honesto
# aporta `+wh` y uno adversario `-wa`; `g` es la granularidad de la retícula, de modo
# que el déficit se representa entero como `z = g·D`. El déficit `d` se declara SIEMPRE
# en unidades de trabajo; `z0 = g·d` lo lleva a la retícula. No se mezclan ambos.

"""
Validez trivaluada de una traza (encargo §0).
"""
@enum Validez VALIDA INVALIDA PENDIENTE

"""
Estado normativo de una regla/fuente (encargo §0).
"""
@enum EstadoNormativo SPEC_VIGENTE CANDIDATA ORACULO_ABSTRACTO IMPLEMENTADA_SIN_CABLEAR INTEGRADA NORM_PENDIENTE EXCLUIDA

"""
Unidades explícitas del modelo. Permite detectar mezclas de unidades.
"""
@enum Unidad TRABAJO SLOTS SEGUNDOS BLOQUES BLUE_WORK

"""
Escenario E de trabajo. Todos los campos son parámetros declarados, no hechos.
`observador` ∈ {:veterano,:nuevo_genesis,:eclipsado,:uno,:algunos,:todos}.
"""
struct Escenario
    nombre::String
    alpha::Float64          # fracción de espacio adversaria declarada [0,1)
    S::Int                  # número de flujos/ramas del escenario (no capacidad acreditada)
    d_inicial::Int          # déficit inicial en unidades de trabajo
    g::Int                  # granularidad de la retícula (peso por bloque = 1/g)
    T::Int                  # horizonte en slots/eventos
    p0::Float64             # nivel de confianza para alpha_prob
    observador::Symbol
    deadline::Union{Nothing,Int}
    regla_flujo::Symbol     # :spec_pendiente | :rfin5 | :aditivo
    notado::String
end

function Escenario(; nombre, alpha, S=1, d_inicial=0, g=1, T=1000, p0=0.05,
                   observador=:veterano, deadline=nothing,
                   regla_flujo=:spec_pendiente, notado="")
    return Escenario(nombre, Float64(alpha), Int(S), Int(d_inicial), Int(g), Int(T),
                     Float64(p0), Symbol(observador), deadline === nothing ? nothing : Int(deadline),
                     Symbol(regla_flujo), String(notado))
end

"""
Veredicto literal exigido por el encargo §7 (uno de los tres).
"""
function frase_veredicto(global_cerrado::Bool)
    global_cerrado && return "Umbral protocolario cerrado mediante cota exhaustiva para todas las estrategias y sin reglas relevantes pendientes."
    return "Umbral protocolario inconcluso; el baseline idealizado no sustituye las reglas pendientes."
end
