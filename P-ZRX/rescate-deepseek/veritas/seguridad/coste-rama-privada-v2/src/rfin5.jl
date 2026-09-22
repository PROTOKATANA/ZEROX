# rfin5.jl — flujo PoT estructural, escenario candidato R-FIN-5 y contrafactual aditivo.
#
# Este módulo NO ejecuta criptografía PoT AES. Lo que comprueba se llama, como exige
# el encargo §3.3, **compatibilidad estructural de flujo**, nunca "PoT verificado".
# La ausencia del verificador integrado no se sustituye por `true`: `autenticado` es
# un campo declarado y, si falta, el resultado es `PENDIENTE`.

"""
Evento `(slot_activación, entropía, N_efectivo)` de R-FIN-2/14. Un descriptor sin
`N_efectivo` no permite decidir la inyección (encargo D7).
"""
struct EventoPot
    slot_activacion::Int
    entropia::UInt64
    N_efectivo::Int
end

"""
Descriptor de flujo con `PotOrigin` —dominio, origen de índices, semilla y `N` inicial
autenticados— y eventos ordenados. Si falta cualquier campo autorizado, el descriptor
es no autenticado y toda decisión es `Pendiente`.
"""
struct DescriptorFlujo
    pot_origin::String
    dominio::String
    origen_indices::Int
    semilla::UInt64
    N_inicial::Int
    autenticado::Bool
    eventos::Vector{EventoPot}
end

function DescriptorFlujo(; pot_origin, dominio, origen_indices, semilla, N_inicial,
                         autenticado, eventos=EventoPot[])
    return DescriptorFlujo(pot_origin, dominio, Int(origen_indices), UInt64(semilla),
                           Int(N_inicial), Bool(autenticado), eventos)
end

"""
Prefijo de flujo hasta `slot` inclusive: identidad del `PotOrigin` más la lista de
eventos con `slot_activacion ≤ slot`, comparada por `(slot, entropía, N_efectivo)`.
Compara **prefijos en `slot(X)`**, no etiquetas de flujo actuales (R-FIN-5).
Devuelve `nothing` si el descriptor no está autenticado.
"""
function prefijo_flujo(desc::DescriptorFlujo, slot::Integer)
    desc.autenticado || return nothing
    evs = [(e.slot_activacion, e.entropia, e.N_efectivo) for e in desc.eventos
           if e.slot_activacion <= slot]
    return (desc.pot_origin, desc.dominio, desc.origen_indices, desc.semilla,
            desc.N_inicial, evs)
end

"""
Comprobación R-FIN-5: `X` puede incorporarse al pasado de `B` si el prefijo de flujo de
`B` en `slot(X)` coincide con el de `X` en `slot(X)`. Una divergencia **posterior** no
invalida el pasado común. Devuelve `Validez`.
"""
function compatible_rfin5(flujo_B::DescriptorFlujo, flujo_X::DescriptorFlujo, slot_X::Integer)
    pB = prefijo_flujo(flujo_B, slot_X)
    pX = prefijo_flujo(flujo_X, slot_X)
    (pB === nothing || pX === nothing) && return PENDIENTE
    return pB == pX ? VALIDA : INVALIDA
end

"""
Decide si el bloque `B` puede incorporar todo `past` bajo R-FIN-5. `slots` da el slot
de cada `X`. Devuelve `(Validez, primer_infractor)`.
"""
function puede_incorporar_pasado(flujo_B::DescriptorFlujo, flujos_past::Vector{DescriptorFlujo},
                                 slots::Vector{<:Integer})
    length(flujos_past) == length(slots) || throw(ArgumentError("longitudes distintas"))
    pendiente = false
    for i in eachindex(flujos_past)
        v = compatible_rfin5(flujo_B, flujos_past[i], slots[i])
        v == INVALIDA && return (INVALIDA, i)
        v == PENDIENTE && (pendiente = true)
    end
    return (pendiente ? PENDIENTE : VALIDA, 0)
end

"""
Frontera de deriva del contrafactual aditivo: el factor `S` aparece **solo** aquí,
sustituyendo `c_a·η_a` por `S·c_a·η_a` (encargo D6). Con `c_h=c_a=η_h=η_a=1` recupera
`α_drift = 1/(S+1)`.
"""
function control_escalar_S(alpha::Real, S::Integer; c_h=1.0, c_a=1.0, eta_h=1.0, eta_a=1.0)
    # g = lim E[W_priv − W_pub]/T: positivo ⇒ ventaja adversaria, por encargo §1.
    g = S * alpha * c_a * eta_a - (1 - alpha) * c_h * eta_h
    raiz = (c_h * eta_h) / (c_h * eta_h + S * c_a * eta_a)
    return (deriva=g, raiz=raiz, signo=sign(g))
end

"""
Cotas de unión para `S` ramas: `max_i P(E_i) ≤ P(∪E_i) ≤ min(1, Σ_i P(E_i))`.
"""
function cota_union(ps::Vector{Float64})
    isempty(ps) && return (0.0, 0.0)
    return (maximum(ps), min(1.0, sum(ps)))
end

"""
`S` ramas fijas con déficits `d_i`: la probabilidad conjunta estimada por MC se acota
con las cotas de unión; exige `P_i` por rama. No afirma concentración ni optimalidad.
"""
function ramas_fijas_max(P_i::Vector{Float64})
    lo, hi = cota_union(P_i)
    return (P_max=cota_union(P_i)[1], union_inf=lo, union_sup=hi,
            suma=sum(P_i), S=length(P_i))
end

"""
`S` ramas aditivas (contrafactual inseguro): la masa adversaria total es la suma. No es
una regla adoptada; solo cuantifica el peligro `S·α`.
"""
function ramas_aditivas(alpha::Real, S::Integer)
    cuota = S * alpha / (1 - alpha + S * alpha)
    return (cuota_efectiva=cuota, alpha_equivalente=cuota)
end
