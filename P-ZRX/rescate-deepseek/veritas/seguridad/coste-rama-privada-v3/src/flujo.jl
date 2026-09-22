# flujo.jl — descriptor de flujo por bloque, PotOrigin/N(s) y R-FIN-5 sobre TODO past(B).
#
# El descriptor es **estructural**: no se ejecuta PoT AES. Un descriptor no autenticado
# produce `PENDIENTE`, nunca `true`.

struct EventoPot
    slot_activacion::Int
    entropia::UInt64
    N_efectivo::Int
end

struct DescriptorFlujo
    flujo_id::Int
    pot_origin::String
    dominio::String
    origen_indices::Int
    semilla::UInt64
    N_inicial::Int
    autenticado::Bool
    eventos::Vector{EventoPot}
end

function DescriptorFlujo(; flujo_id=0, pot_origin, dominio, origen_indices, semilla,
                         N_inicial, autenticado, eventos=EventoPot[])
    return DescriptorFlujo(Int(flujo_id), pot_origin, dominio, Int(origen_indices),
                           UInt64(semilla), Int(N_inicial), Bool(autenticado), eventos)
end

"Prefijo de flujo hasta `slot`; `nothing` si el descriptor no está autenticado."
function prefijo_flujo(desc::DescriptorFlujo, slot::Integer)
    desc.autenticado || return nothing
    evs = [(e.slot_activacion, e.entropia, e.N_efectivo) for e in desc.eventos
           if e.slot_activacion <= slot]
    return (desc.pot_origin, desc.dominio, desc.origen_indices, desc.semilla,
            desc.N_inicial, evs)
end

"R-FIN-5 estructural entre `B` y `X` evaluado en `slot(X)`: `VALIDA|INVALIDA|PENDIENTE`."
function compatible_rfin5(flujo_B::DescriptorFlujo, flujo_X::DescriptorFlujo, slot_X::Integer)
    # Atajo seguro SOLO por identidad de objeto y autenticación mutua: nunca por id.
    if flujo_B.autenticado && flujo_X.autenticado && flujo_B === flujo_X
        return VALIDA
    end
    pB = prefijo_flujo(flujo_B, slot_X)
    pX = prefijo_flujo(flujo_X, slot_X)
    (pB === nothing || pX === nothing) && return PENDIENTE
    return pB == pX ? VALIDA : INVALIDA
end

"""
Comprueba el horizonte de justificación hasta `slot_B` desde `slot_sp` bajo el flujo:
todos los eventos del descriptor en `(slot_sp, slot_B]` deben ser conocidos. Devuelve
`Validez`. Es una comprobación **separada** de la de prefijo (encargo v0.3, punto 2).
"""
function horizonte_justificacion_ok(fl::DescriptorFlujo, slot_sp::Integer, slot_B::Integer)
    fl.autenticado || return PENDIENTE
    slot_B >= slot_sp || return INVALIDA
    return VALIDA
end

"""
Construye el descriptor de un flujo. Hasta `t_fork` todas las ramas comparten los
mismos eventos; después de la primera inyección posterior a `t_fork` divergen
(entropía distinta). `rama=0` es el flujo canónico honesto.
"""
function construir_flujo(; base::UInt64=0xA5A5_0000_0000_0000, rama::Integer=0, t_fork::Integer,
                         inyecciones::Vector{Int}, N0::Int=100, I_slots::Int=100)
    evs = EventoPot[]
    for (j, t) in enumerate(inyecciones)
        ent = t <= t_fork ? (base + UInt64(j)) :
              ((base + UInt64(j)) ⊻ (UInt64(rama) * 0x9E37_79B9_7F4A_7C15))
        N = N0                                   # N(s) constante en este instrumento
        push!(evs, EventoPot(t, ent, N))
    end
    # PotOrigin COMPARTIDO por todos los flujos que comparten historia; la divergencia
    # aparece solo en la entropía de las inyecciones posteriores a `t_fork`.
    return DescriptorFlujo(flujo_id=rama, pot_origin="ZEROX-PoAS", dominio="ZEROX-v0",
                           origen_indices=0, semilla=base, N_inicial=N0,
                           autenticado=true, eventos=evs)
end

"Primera inyección estrictamente posterior a `slot` (o `typemax`)."
function proxima_inyeccion(desc::DescriptorFlujo, slot::Integer)
    ts = [e.slot_activacion for e in desc.eventos if e.slot_activacion > slot]
    return isempty(ts) ? typemax(Int) : minimum(ts)
end

"""
Por convención, medir el déficit entre dos cadenas exige que compartan prefijo de flujo
hasta su ancestro común. Devuelve el slot de la primera divergencia observable.
"""
function primera_divergencia(a::DescriptorFlujo, b::DescriptorFlujo, hasta::Integer)
    for s in 0:hasta
        va = compatible_rfin5(a, b, s)
        va == INVALIDA && return s
        va == PENDIENTE && return s
    end
    return typemax(Int)
end

# ---------------------------------------------------------------------------
# Fixtures U2/U3 (encargo v0.3, punto 11).
# Orden explícito: compatibilidad de flujo → validez → U2 → color U3″.
# GDR (`ghostdag-rank-v1`) aplica U2/U3; aquí se fijan los escenarios.
# ---------------------------------------------------------------------------

"""
Billete repetido en la MISMA rama (mismo `billete` en el pasado) ⇒ el bloque es
inválido por U2 (SPEC §11, C-GD-07). El llamante decide comparando el pasado.
"""
u2_repite_en_pasado(billete::Integer, billetes_pasado::Vector{<:Integer}) =
    billete != 0 && any(==(billete), billetes_pasado)

"""
Dos copias del mismo billete en ramas disjuntas: ninguna ve a la otra, ambas válidas;
un fusionador que ve ambas colorea una azul y una `rojo_U3`.
"""
function fixture_u2_u3(; k::Integer=30)
    dag = SimboloDAG(; k=k, id_genesis="G")
    # rama A y rama B, disjuntas, mismo billete 77
    agregar!(dag, "A1", [1], 1, 0, 1, 77)
    agregar!(dag, "B1", [1], 1, 0, 1, 77)
    # fusionador que intenta ver ambas (si el flujo lo permite)
    agregar!(dag, "M", [2, 3], 2, 0, 1, 99)
    colA = color_contextual(dag, 4, 2)
    colB = color_contextual(dag, 4, 3)
    return (dag=dag, fusionador=4, colores=(A=colA, B=colB),
            una_u3=(colA == :rojo_U3) ⊻ (colB == :rojo_U3))
end

"""
Mismo billete dos veces DENTRO de una rama (copia descendiente del original): U2
invalida la segunda copia porque su identidad está en el pasado de su padre.
"""
function fixture_u2_misma_rama(; k::Integer=30)
    dag = SimboloDAG(; k=k, id_genesis="G")
    agregar!(dag, "A1", [1], 1, 0, 1, 55)
    # A2 copia con el mismo billete; su padre A1 ya lo tiene ⇒ U2 debe rechazar
    ok = agregar!(dag, "A2", [2], 2, 0, 1, 55)
    return (dag=dag, aceptado=ok, motivo=ultimo_motivo(dag))
end
