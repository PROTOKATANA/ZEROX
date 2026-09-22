# IB-v0.1 — validación: controles contra el ORÁCULO y contra una vía independiente.
#
# Ningún control compara una fórmula consigo misma:
#   C1 · Inyectividad de la tabla de chunks ⇒ A refina a B en el universo con escalares
#        «grandes» (H1). Es una comprobación exhaustiva sobre el subuniverso declarado.
#   C2 · Cruce A/B con el dominio de chunk reducido: par explícito A-igual y B-distinto.
#   C3 · `evaluar_ref` (oráculo GHOSTDAG de GDR) vs `evaluar_rapido` (kernel): mismos
#        colores, mismo peso y mismas copias pagables, bloque a bloque.
#   C4 · La capa pagable, vía cadena, contra una tercera vía basada en CONJUNTOS.
#   C5 · El invariante de no-equivocación de C-FLU-12, copia a copia.

"""
Subuniverso enumerable para los controles exhaustivos: (pk, sector, historia, pieza,
slot, flujo) pequeños. Se enumeran TODAS las combinaciones.
"""
function subuniverso(; npk=2, nsector=2, nhist=2, n_pieza=4, nslot=4, nflujo=2)
    out = Solucion[]
    for pk in 0:(npk - 1), sector in 0:(nsector - 1), historia in 0:(nhist - 1),
        pieza in 0:(n_pieza - 1), slot in 0:(nslot - 1), flujo in 0:(nflujo - 1)
        push!(out, solucion(pk=pk, sector=sector, historia=historia, pieza=pieza,
                            slot=slot, flujo=flujo))
    end
    return out
end

"""
C1 · ¿A refina a B? Con la tabla de chunks inyectiva, `clave_a(x) == clave_a(y)` debe
implicar `identidad(MODO_B, x) == identidad(MODO_B, y)`. Se comprueba sobre TODO el
subuniverso, por pares (O(n²) con `n` pequeño).
"""
function control_refinamiento(; colision_bits::Int=W_CHUNK_BITS)
    viejo = COLISION_CHUNK[]; COLISION_CHUNK[] = colision_bits
    try
        U = subuniverso()
        violaciones = Tuple{Solucion,Solucion}[]
        for i in eachindex(U), j in (i + 1):length(U)
            x, y = U[i], U[j]
            if clave_a(x) == clave_a(y) && identidad(MODO_B, x) != identidad(MODO_B, y)
                push!(violaciones, (x, y))
            end
        end
        return (n=length(U), violaciones=violaciones)
    finally
        COLISION_CHUNK[] = viejo
    end
end

"""
C2 · ¿A y B se cruzan? Se busca un par con la MISMA identidad A y DISTINTA identidad B, y
otro con la MISMA identidad B y DISTINTA A. El segundo es trivial (misma pieza, `chunk`
distinto por flujos distintos); el primero exige colisión de valor de chunk.
"""
function control_cruce(; colision_bits::Int)
    viejo = COLISION_CHUNK[]; COLISION_CHUNK[] = colision_bits
    try
        U = subuniverso(n_pieza=4, npk=1, nsector=1, nhist=1, nslot=2, nflujo=2)
        a_igual_b_distinto = Tuple{Solucion,Solucion}[]
        b_igual_a_distinto = Tuple{Solucion,Solucion}[]
        for i in eachindex(U), j in (i + 1):length(U)
            x, y = U[i], U[j]
            ia = clave_a(x) == clave_a(y)
            ib = identidad(MODO_B, x) == identidad(MODO_B, y)
            ia && !ib && push!(a_igual_b_distinto, (x, y))
            ib && !ia && push!(b_igual_a_distinto, (x, y))
        end
        return (n=length(U), a_igual_b_distinto=a_igual_b_distinto,
                b_igual_a_distinto=b_igual_a_distinto)
    finally
        COLISION_CHUNK[] = viejo
    end
end

"""
C4 · Tercera vía: capa pagable calculada por CONJUNTOS, sin recorrer la cadena.
Usa `blueset` del kernel (conjunto azul completo de la punta) y recoge los rojo_k de
todos los mergesets. Agrupa y aplica P1 con la misma tupla, pero por un camino distinto.
"""
function evaluar_bruto(especs::Vector{BloqueEspec}, modo::ModoId, params::GDR.Params)
    est = GDR.EstadoRapido(params, "G")
    mapa, u2, herencia = _poblar!(est, especs, modo, params)
    tip = GDR.virtual_sp(est, params)
    blues = GDR.blueset(est, tip)
    rojos = Set{Int}()
    for c in 1:est.n
        for x in GDR.ms_reds_de(est, c)
            GDR.es_rojo_u3(est, c, x) || push!(rojos, x)
        end
    end
    papel = Dict{Int,Symbol}()
    for x in blues; papel[x] = :azul; end
    for x in rojos
        haskey(papel, x) || (papel[x] = :rojo_k)
    end
    pagables, inertes, _ = _seleccionar(est, papel)
    return Resultado(modo, length(especs), Int[i for i in 1:length(especs) if mapa[i] != 0],
                     u2, herencia, Int[], Int[], Int[], pagables, inertes,
                     BigInt(GDR.bw_de(est, tip)), Dict{UInt64,Vector{NTuple{32,UInt8}}}())
end

"C3 · Equivalencia oráculo↔kernel, campo a campo, para un fixture y un modo."
function equivalentes(a::Resultado, b::Resultado)
    return a.validos == b.validos && a.u2 == b.u2 && a.herencia == b.herencia &&
           a.azules == b.azules && a.rojo_k == b.rojo_k && a.rojo_u3 == b.rojo_u3 &&
           a.pagables == b.pagables && a.inertes == b.inertes && a.peso == b.peso
end

"""
C5 · Invariante de no-equivocación del inyector (C-FLU-12): dos copias del MISMO billete
deben producir la MISMA entropía. Devuelve las identidades que lo violan.
"""
function violaciones_entropia(res::Resultado)
    malas = Tuple{UInt64,Vector{NTuple{32,UInt8}}}[]
    for (id, es) in res.entropias
        length(es) <= 1 && continue
        all(==(es[1]), es) || push!(malas, (id, es))
    end
    sort!(malas; by=first)
    return malas
end

"Resumen numérico de un resultado, para tablas."
function resumen(r::Resultado)
    return (modo=r.modo, n=r.n, validos=length(r.validos), u2=length(r.u2),
            herencia=length(r.herencia), azules=length(r.azules), rojo_k=length(r.rojo_k),
            rojo_u3=length(r.rojo_u3), pagables=length(r.pagables),
            inertes=length(r.inertes), peso=r.peso,
            identidades=length(r.entropias), entropia_violada=length(violaciones_entropia(r)))
end
