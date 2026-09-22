# =============================================================================
# espectro.jl — las tres identidades de billete, el modelo de elegibilidad y κ
#
# Identidades (§1 del encargo), tal como están escritas en su fuente:
#   :spec07    C-GD-07 / R-FIN-11  (public_key, sector_index, history_size, chunk, slot)
#   :idv01     IDV-01              (dominio, slot, public_key, sector_index, history_size, piece_offset)
#   :candidata CANDIDATA.md        H(dominio, slot, PlotBatchId, sector_index, piece_offset)
#
# Modelo de elegibilidad (declarado, NO regla de consenso):
#   distancia(chunk, prueba, reto) = mezcla64 exacta de enteros (sin coma flotante)
#   elegible <=> distancia <= rango
# El `rango` es un PARÁMETRO del modelo. Controla la media m = N·(rango+1)/2^64 de
# candidatos ganadores por slot y por rama. Ningún `rango` de este archivo es un
# parámetro de consenso ni se propone como tal.
# =============================================================================

"Pieza de la parcela: coordenadas que la identidad usa."
struct Pieza
    pubkey::Int
    sector::Int
    historia::Int
    offset::Int
end

"Una solución concreta: una pieza, un escalar `chunk` y un nonce de prueba PoS."
struct Solucion
    pieza::Pieza
    chunk::Int
    prueba::Int
end

"Mezcla entera exacta de 64 bits. Determinista, sin coma flotante ni estado global."
@inline function mezcla64(a::UInt64, b::UInt64, c::UInt64)
    x = a + 0x9E3779B97F4A7C15
    x ⊻= b
    x = (x ⊻ (x >> 30)) * 0xBF58476D1CE4E5B9
    x = (x ⊻ (x >> 27)) * 0x94D049BB133111EB
    x ⊻= (x >> 31)
    x += c * 0xD6E8FEB86659FD93
    x = (x ⊻ (x >> 32)) * 0x9E3779B97F4A7C15
    x ⊻= (x >> 29)
    return x
end

distancia(s::Solucion, reto::UInt64) = mezcla64(UInt64(s.chunk), UInt64(s.prueba), reto)
elegible(s::Solucion, reto::UInt64, rango::UInt64) = distancia(s, reto) <= rango

"Reto derivado del flujo y del slot. El flujo se identifica por su preimagen canónica (M1)."
function reto_de_flujo(inj::Vector{Tuple{Int,Tuple{Int,Int},Int}}, s::Int, jmax::Int)
    h = 0xCBF29CE484222325
    for (j, (chunk, slot_a), t) in inj
        h = mezcla64(h, UInt64(chunk), UInt64(slot_a))
        h = mezcla64(h, UInt64(t), UInt64(j))
    end
    return mezcla64(h, UInt64(s), UInt64(jmax))
end

"Aproximación del flujo activo en `s`: solo las inyecciones con `t_j <= s`."
function flujo_activo(inj::Vector{Tuple{Int,Tuple{Int,Int},Int}}, s::Int)
    out = Tuple{Int,Tuple{Int,Int},Int}[]
    for e in inj
        e[3] <= s && push!(out, e)
    end
    return out
end

"Las tres identidades, sobre la misma solución y el mismo slot."
function identidad(cual::Symbol, s::Solucion, slot::Int, dominio::Int, plotbatch::Int)
    p = s.pieza
    if cual === :spec07
        return (p.pubkey, p.sector, p.historia, s.chunk, slot)
    elseif cual === :idv01
        return (dominio, slot, p.pubkey, p.sector, p.historia, p.offset)
    elseif cual === :candidata
        return (dominio, slot, plotbatch, p.sector, p.offset)
    else
        error("identidad desconocida: $cual")
    end
end

const IDENTIDADES = (:spec07, :idv01, :candidata)

"""
    Universo(piezas, nchunks, npruebas, rango, dominio, plotbatch)

Universo de soluciones que el agricultor puede generar: cada pieza ofrece
`nchunks` escalares `chunk` y `npruebas` nonces. `N = P · C · E` candidatos.
"""
struct Universo
    soluciones::Vector{Solucion}
    rango::UInt64
    dominio::Int
    plotbatch::Int
end

function Universo(; npiezas::Int, nchunks::Int, npruebas::Int, rango::UInt64,
                  dominio::Int = 7, plotbatch::Int = 42)
    sols = Solucion[]
    for i in 1:npiezas, c in 1:nchunks, e in 1:npruebas
        p = Pieza(1, 1, 1, i)                      # pubkey/sector/historia fijos y declarados
        # el escalar `chunk` es PROPIO de cada pieza: dos piezas distintas no comparten
        # valores de chunk salvo que el modelo lo pida (evita un colapso artificial de la
        # identidad de C-GD-07, que incluye `chunk`).
        chunk = (i - 1) * nchunks + c
        push!(sols, Solucion(p, chunk, e))
    end
    return Universo(sols, rango, dominio, plotbatch)
end

"Rango que da una media `m` de ganadores por slot: `rango+1 = m·2^64/N`."
function rango_para_media(u_N::Int, m::Float64)
    m <= 0 && return UInt64(0)
    v = m * 2.0^64 / u_N
    v >= 2.0^64 && return typemax(UInt64)
    return UInt64(floor(v))
end

"Conjunto de soluciones elegibles bajo un reto (exacto, sin muestreo)."
function ganadores(u::Universo, reto::UInt64)
    out = Int[]
    for (i, s) in enumerate(u.soluciones)
        elegible(s, reto, u.rango) && push!(out, i)
    end
    return out
end

"¿Puede el atacante evitar la evidencia en este slot con esta identidad?"
function evasion_posible(u::Universo, wa::Vector{Int}, wb::Vector{Int}, cual::Symbol, slot::Int)
    for a in wa, b in wb
        identidad(cual, u.soluciones[a], slot, u.dominio, u.plotbatch) ==
        identidad(cual, u.soluciones[b], slot, u.dominio, u.plotbatch) || return true
    end
    return false
end

"""
    kappa_slot(u, ident, reto_a, reto_b) -> (hay_oportunidad, evasion)

Clasifica UN slot de doble farmeo:
* `hay_oportunidad` = hay al menos una solución ganadora en cada rama.
* `evasion` = existe un par (rama A, rama B) con **identidades distintas**; es decir,
  el atacante puede doble-farmear ese slot **sin** dejar la evidencia estrecha.
"""
function kappa_slot(u::Universo, cual::Symbol, reto_a::UInt64, reto_b::UInt64, slot::Int)
    wa = ganadores(u, reto_a)
    wb = ganadores(u, reto_b)
    (isempty(wa) || isempty(wb)) && return (false, false)
    return (true, evasion_posible(u, wa, wb, cual, slot))
end

"""
    slots_rama(d, tip, P) -> Set{Int}

Slots de los bloques **propios** de la rama de `tip`: `(past(tip) ∪ {tip}) \\ (past(P) ∪ {P})`.
Excluir el pasado común es lo que distingue «dos bloques del mismo slot en dos ramas»
de «el mismo bloque común visto desde las dos».
"""
function slots_rama(d::Dag, tip::Int, P::Int)
    s = Set{Int}()
    for x in 1:nbloques(d)
        (x == tip || d.pasado[tip][x]) || continue
        (x == P || d.pasado[P][x]) && continue
        push!(s, d.bloques[x].slot)
    end
    return s
end

"""
    kappa(d, A, B, u; I_slots, L, F_slots, jmax, k, s0) -> NamedTuple

Recorre los slots de doble farmeo `W = slots(A) ∩ slots(B)` —los slots en que **ambas**
ramas llevan bloque, que es donde el agricultor usó su parcela dos veces— y calcula, por
identidad:

* `kappa_flujo`: fracción de slots de `W` en que las dos ramas comparten flujo (y por
  tanto reto, `C-POT-03`).
* `kappa[id]`: fracción de slots con oportunidad de doble farmeo en que el atacante
  **no** puede evitar la evidencia.

`kappa = 1 − evasión`. Es la definición del encargo: fracción del doble farmeo que deja
evidencia castigable.
"""
function kappa(d::Dag, A::Int, B::Int, P::Int, u::Universo; I_slots::Int, L::Int, F_slots::Int,
               jmax::Int, k::Int, s0::Int)
    pd = PreDag(d)
    buf = Buffers(pd.n)
    ia = inyecciones_rapidas(buf, pd, A, I_slots, L, jmax, k)
    ib = inyecciones_rapidas(buf, pd, B, I_slots, L, jmax, k)
    slots = sort(collect(intersect(slots_rama(d, A, P), slots_rama(d, B, P))))
    nflujo = 0
    noport = Dict(id => 0 for id in IDENTIDADES)
    nevad = Dict(id => 0 for id in IDENTIDADES)
    # separado por régimen: slots con flujo común y slots con flujo divergente
    noport_c = Dict(id => 0 for id in IDENTIDADES)
    nevad_c = Dict(id => 0 for id in IDENTIDADES)
    noport_d = Dict(id => 0 for id in IDENTIDADES)
    nevad_d = Dict(id => 0 for id in IDENTIDADES)
    detalle = NamedTuple[]
    for s in slots
        fa = flujo_activo(ia, s); fb = flujo_activo(ib, s)
        comun = fa == fb
        comun && (nflujo += 1)
        ra = reto_de_flujo(fa, s, jmax); rb = reto_de_flujo(fb, s, jmax)
        for id in IDENTIDADES
            hay, ev = kappa_slot(u, id, ra, rb, s)
            hay || continue
            noport[id] += 1
            ev && (nevad[id] += 1)
            if comun
                noport_c[id] += 1
                ev && (nevad_c[id] += 1)
            else
                noport_d[id] += 1
                ev && (nevad_d[id] += 1)
            end
        end
        push!(detalle, (slot = s, flujo_comun = comun,
                        ganadores_a = length(ganadores(u, ra)),
                        ganadores_b = length(ganadores(u, rb))))
    end
    kap = Dict{Symbol,Float64}()
    kap_c = Dict{Symbol,Float64}()
    kap_d = Dict{Symbol,Float64}()
    for id in IDENTIDADES
        kap[id] = noport[id] == 0 ? NaN : 1.0 - nevad[id] / noport[id]
        kap_c[id] = noport_c[id] == 0 ? NaN : 1.0 - nevad_c[id] / noport_c[id]
        kap_d[id] = noport_d[id] == 0 ? NaN : 1.0 - nevad_d[id] / noport_d[id]
    end
    # ¿coincide el BLOQUE ancla (no solo su slot) en cada época presente en las dos ramas?
    da = Dict(j => e for (j, e, _) in ia)
    db = Dict(j => e for (j, e, _) in ib)
    comunes = sort(collect(intersect(keys(da), keys(db))))
    anclas_iguales = [da[j] == db[j] for j in comunes]
    return (slots = length(slots),
            kappa_flujo = length(slots) == 0 ? NaN : nflujo / length(slots),
            slots_comun = nflujo, slots_divergente = length(slots) - nflujo,
            con_oportunidad = noport, evasion = nevad, kappa = kap,
            oport_comun = noport_c, oport_divergente = noport_d,
            kappa_comun = kap_c, kappa_divergente = kap_d,
            inyecciones_a = ia, inyecciones_b = ib, detalle = detalle,
            epocas_comunes = comunes, anclas_iguales = anclas_iguales,
            reorg_publica = d.bloques[A].slot - s0, reorg_privada = d.bloques[B].slot - s0,
            dentro_de_ventana = (d.bloques[A].slot - s0 < F_slots) && (d.bloques[B].slot - s0 < F_slots))
end
