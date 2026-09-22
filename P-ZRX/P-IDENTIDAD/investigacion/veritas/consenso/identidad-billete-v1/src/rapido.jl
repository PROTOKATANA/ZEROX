# IB-v0.1 — rápido: la misma semántica que `referencia.jl` sobre el kernel
# `GhostdagRank.EstadoRapido`, con la capa pagable INDEXADA (arrays densos, sin `Dict`
# en el recorrido del mergeset) y los generadores de escenarios.

# ---------------------------------------------------------------------------
# Capa pagable indexada
# ---------------------------------------------------------------------------
"0 sin papel · 1 azul · 2 rojo_k · 3 rojo_U3"
const P_SIN = 0x00; const P_AZUL = 0x01; const P_ROJOK = 0x02; const P_ROJOU3 = 0x03

"""
Igual que la vía de cadena, pero el papel se guarda en un `Vector{UInt8}` indexado por
índice de estado y las copias se agrupan con índice denso + lista enlazada. Sin `Dict`
en el recorrido.
"""
function _papel_indexado(est, params::GDR.Params)
    tip = GDR.virtual_sp(est, params)
    ch = GDR.cadena_seleccionada(est, tip)
    papel = zeros(UInt8, est.n)
    for k in 2:length(ch)
        c = ch[k]
        papel[ch[k - 1]] = P_AZUL
        for x in GDR.ms_blues_de(est, c)
            x == GDR.sp_de(est, c) && continue
            papel[x] = P_AZUL
        end
        for x in GDR.ms_reds_de(est, c)
            papel[x] = GDR.es_rojo_u3(est, c, x) ? P_ROJOU3 : P_ROJOK
        end
    end
    papel[tip] = P_AZUL
    return tip, papel
end

function _seleccionar_indexado(est, papel::Vector{UInt8})
    # índice denso por identidad (una pasada), lista enlazada de copias
    idx = Dict{UInt64,Int32}()
    id_de = UInt64[]
    cabeza = Int32[]
    siguiente = zeros(Int32, est.n)
    for x in 1:est.n
        (papel[x] == P_AZUL || papel[x] == P_ROJOK) || continue
        id = est.idents[x]
        j = get(idx, id, Int32(0))
        if j == 0
            # DEFECTO D1 (corregido): empujar `x` aquí hacía `siguiente[x] = x` (autociclo
            # infinito). El grupo nace con cabeza 0 y se hace el prepend estándar.
            push!(id_de, id); push!(cabeza, Int32(0)); j = Int32(length(id_de))
            idx[id] = j
        end
        siguiente[x] = cabeza[j]
        cabeza[j] = Int32(x)
    end
    pagables = Int[]; inertes = Int[]
    for j in eachindex(id_de)
        mejor = 0
        x = cabeza[j]
        while x != 0
            if mejor == 0
                mejor = Int(x)
            else
                pa = papel[x] == P_AZUL; pm = papel[mejor] == P_AZUL
                gana = pa != pm ? pa : (GDR.cmp_orden(est, Int(x), mejor) < 0)
                gana && (mejor = Int(x))
            end
            x = siguiente[x]
        end
        push!(pagables, mejor)
        x = cabeza[j]
        while x != 0
            Int(x) == mejor || push!(inertes, Int(x))
            x = siguiente[x]
        end
    end
    sort!(pagables); sort!(inertes)
    return pagables, inertes
end

"Evalúa `especs` sobre el kernel rápido."
function evaluar_rapido(especs::Vector{BloqueEspec}, modo::ModoId, params::GDR.Params)
    est = GDR.EstadoRapido(params, "G")
    mapa, u2, herencia = _poblar!(est, especs, modo, params)
    tip, papel_v = _papel_indexado(est, params)
    pagables, inertes = _seleccionar_indexado(est, papel_v)

    azules = Int[]; rojos_k = Int[]; rojos_u3 = Int[]
    for x in 1:est.n
        papel_v[x] == P_AZUL && push!(azules, x)
        papel_v[x] == P_ROJOK && push!(rojos_k, x)
        papel_v[x] == P_ROJOU3 && push!(rojos_u3, x)
    end
    validos = Int[i for i in 1:length(especs) if mapa[i] != 0]
    ent = Dict{UInt64,Vector{NTuple{32,UInt8}}}()
    for i in 2:length(especs)
        i in herencia && continue
        s = especs[i].sol
        push!(get!(ent, identidad(modo, s), NTuple{32,UInt8}[]), entropia_de(s))
    end
    return Resultado(modo, length(especs), validos, u2, herencia, azules, rojos_k, rojos_u3,
                     pagables, inertes, BigInt(GDR.bw_de(est, tip)), ent)
end

# ---------------------------------------------------------------------------
# Ganadores del reto (E2–E5)
# ---------------------------------------------------------------------------
"""
Predicado de victoria determinista y auditable con probabilidad `q` por (pieza, reto).
Sustituye a `is_within_solution_range` conservando lo que importa aquí: es función de
(chunk, slot, flujo) y NO de la pieza salvo a través del chunk.
"""
function gana(pk::Integer, sector::Integer, historia::Integer, pieza::Integer,
              slot::Integer, flujo::Integer, q::Float64)::Bool
    b = bucket_de(pk, sector, historia, slot, flujo)
    c = chunk_almacenado(pk, sector, historia, pieza, b)
    u = mezclar2(c, mezclar2(slot + 4096 * flujo, pk + 64 * sector))
    umbral = UInt64(round(q * 65536.0))
    return (u % 65536) < umbral
end

"Ganadores de (pk, sector, historia, slot, flujo), en el orden de `sd` (menor primero)."
function ganadores(pk::Integer, sector::Integer, historia::Integer, slot::Integer,
                   flujo::Integer, P::Integer, q::Float64)
    out = Tuple{Int,UInt64,UInt64}[]
    b = bucket_de(pk, sector, historia, slot, flujo)
    for p in 0:(P - 1)
        c = chunk_almacenado(pk, sector, historia, p, b)
        u = mezclar2(c, mezclar2(slot + 4096 * flujo, pk + 64 * sector))
        if (u % 65536) < UInt64(round(q * 65536.0))
            push!(out, (p, c, u % 4096))
        end
    end
    sort!(out; by=t -> (t[3], t[1]))
    return out
end

# ---------------------------------------------------------------------------
# Fixtures canónicos (§F1–F4)
# ---------------------------------------------------------------------------
"""
Fixtures de la identidad. Cada uno declara SU DAG y sus soluciones de forma explícita.
Las soluciones coherentes con E2–E4 se construyen con `solucion(...)`; el caso de «misma
pieza, `chunk` distinto» se construye con flujos distintos en el mismo slot, que es la
ÚNICA vía por la que existe (E2 + E3).
"""
function fixtures_canonicos()
    P = GDR.Params()
    F = Dict{String,Vector{BloqueEspec}}()

    # 1 · Copia DESCENDIENTE en la MISMA historia y el MISMO flujo. La coherencia de flujo
    #     (C-FLU-14) obliga a que dos bloques de la misma historia con el mismo slot
    #     compartan reto ⇒ comparten `chunk` ⇒ son el mismo billete bajo A **y** bajo B.
    #     El segundo es inválido por U2 en las DOS definiciones: control de que el cambio
    #     no muerde aquí.
    F["mismo-flujo-descendiente-u2"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("B1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("B2", [2], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("B3", [3], solucion(pk=1, sector=0, historia=0, pieza=5, slot=2, flujo=0, sd=0)),
    ]

    # 2 · Hermanas en la MISMA historia y el MISMO flujo (misma oportunidad). A y B
    #     coinciden: una azul y una rojo_U3 (C-GD-07 U3″).
    F["mismo-flujo-hermanas-u3"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("B1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("B2", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=1)),
        BloqueEspec("T", [2, 3], solucion(pk=2, sector=0, historia=0, pieza=8, slot=2, flujo=0, sd=0)),
    ]

    # 3 · La misma oportunidad en DOS ramas disjuntas, mismo flujo. Ambas válidas y azules
    #     en la suya (medido en CRP-v0.1 §6); al fusionar, una es rojo_U3. A y B coinciden.
    F["ramas-disjuntas-mismo-flujo"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("A1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("B1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("M", [2, 3], solucion(pk=2, sector=0, historia=0, pieza=8, slot=2, flujo=0, sd=0)),
    ]

    # 4 · Ramas disjuntas con FLUJOS DIVERGENTES en el mismo slot y MISMA pieza. Es el
    #     ÚNICO caso en que A y B difieren: A ve dos billetes (`chunk` distinto por bucket
    #     distinto); B ve uno y lo marca rojo_U3. Y el invariante de C-FLU-12 se rompe.
    F["flujo-divergente-misma-pieza"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("A1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("B1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=1, sd=0)),
        BloqueEspec("M", [2, 3], solucion(pk=2, sector=0, historia=0, pieza=8, slot=2, flujo=0, sd=0)),
    ]

    # 5 · Ramas disjuntas con flujos divergentes y PIEZAS DISTINTAS: A y B coinciden en
    #     tratarlas como dos billetes. Es el escape que NINGUNA de las tres identidades
    #     cierra (ni A, ni B, ni C).
    F["flujo-divergente-piezas-distintas"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("A1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("B1", [1], solucion(pk=1, sector=0, historia=0, pieza=7, slot=1, flujo=1, sd=0)),
        BloqueEspec("M", [2, 3], solucion(pk=2, sector=0, historia=0, pieza=8, slot=2, flujo=0, sd=0)),
    ]

    # 6 · Dos PIEZAS distintas del mismo sector y slot, mismo flujo. A y B coinciden: dos
    #     billetes distintos en las dos definiciones (y A refina a B).
    F["dos-piezas-mismo-slot"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("B1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("B2", [1], solucion(pk=1, sector=0, historia=0, pieza=7, slot=1, flujo=0, sd=1)),
        BloqueEspec("T", [2, 3], solucion(pk=2, sector=0, historia=0, pieza=8, slot=2, flujo=0, sd=0)),
    ]

    # 7 · Misma pieza en slots DISTINTOS: nunca fue la misma oportunidad (el `slot` está en
    #     las tres identidades). Control negativo de los anteriores.
    F["misma-pieza-slots-distintos"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("B1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("B2", [2], solucion(pk=1, sector=0, historia=0, pieza=3, slot=2, flujo=0, sd=0)),
    ]

    # 8 · Copias del mismo billete con colores distintos: P1 elige el azul (§7.2).
    F["desempate-color-p1"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("C1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("C2", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=1)),
        BloqueEspec("T", [2, 3], solucion(pk=2, sector=0, historia=0, pieza=9, slot=2, flujo=0, sd=0)),
    ]

    # 9 · Reorg: el mismo billete gana en dos ramas; la reconstrucción desde el génesis
    #     lo libera en la rama abandonada (§7.2, `fixture_reorg_libera_billete`).
    F["reorg-libera-billete"] = BloqueEspec[
        BloqueEspec("G", Int[], solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0)),
        BloqueEspec("A1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=0)),
        BloqueEspec("A2", [2], solucion(pk=2, sector=0, historia=0, pieza=4, slot=2, flujo=0, sd=0)),
        BloqueEspec("B1", [1], solucion(pk=1, sector=0, historia=0, pieza=3, slot=1, flujo=0, sd=5)),
        BloqueEspec("B2", [4], solucion(pk=3, sector=0, historia=0, pieza=6, slot=3, flujo=0, sd=0)),
    ]
    return P, F
end

"""
Coherencia de flujo (C-FLU-14 + C-FLU-07): dentro de una MISMA historia, dos bloques con el
mismo `slot` comparten flujo y por tanto reto. Un fixture que la viole no es alcanzable.
Devuelve la lista de pares incoherentes (ancestro/descendiente, mismo slot, flujo distinto).
"""
function incoherencias_de_flujo(especs::Vector{BloqueEspec})
    n = length(especs)
    anc = [BitSet() for _ in 1:n]
    for i in 2:n
        for p in especs[i].padres
            push!(anc[i], p); union!(anc[i], anc[p])
        end
    end
    malos = Tuple{Int,Int}[]
    for i in 2:n, j in 2:n
        i == j && continue
        (i in anc[j] || j in anc[i]) || continue
        especs[i].sol.slot == especs[j].sol.slot || continue
        especs[i].sol.flujo == especs[j].sol.flujo || push!(malos, (i, j))
    end
    return malos
end

"""
DAG de un productor honesto con proceso de nacimiento de tasa `lambda` por slot y ventana
de padres `Delta`. Un bloque por (pk, sector, slot) —política de E6— y un solo flujo por
productor. `equivoca` = probabilidad de que un productor con dos nodos de vistas
divergentes emita una SEGUNDA copia en el mismo slot bajo otro flujo (mismo recurso físico,
reto distinto).
"""
function dag_honesto(rng, n::Int, lambda::Float64, Delta::Int, q::Float64, P::Int;
                     equivoca::Float64=0.0, npk::Int=4, nflujo::Int=2)
    especs = BloqueEspec[BloqueEspec("G", Int[],
        solucion(pk=0, sector=0, historia=0, pieza=0, slot=0, flujo=0))]
    ocupado = Set{Tuple{Int,Int,Int}}()
    t = 0.0
    intentos = 0
    while length(especs) - 1 < n && intentos < 200 * n
        intentos += 1
        t += -log(rand(rng)) / lambda
        slot = Int(floor(t)) + 1
        slot > N_SLOT - 1 && break
        pk = rand(rng, 0:(npk - 1)); sector = rand(rng, 0:(N_SECTOR - 1))
        flujo = rand(rng, 0:(nflujo - 1))
        (pk, sector, slot) in ocupado && continue
        ws = ganadores(pk, sector, 0, slot, flujo, P, q)
        isempty(ws) && continue
        push!(ocupado, (pk, sector, slot))
        nuevos = [(ws[1][1], flujo, ws[1][3])]
        if rand(rng) < equivoca
            otro = 1 - flujo
            ws2 = ganadores(pk, sector, 0, slot, otro, P, q)
            isempty(ws2) || push!(nuevos, (ws2[1][1], otro, ws2[1][3]))
        end
        for (pieza, fl, sd) in nuevos
            con_hijo = falses(length(especs))
            for i in 2:length(especs), p in especs[i].padres
                con_hijo[p] = true
            end
            cands = Int[i for i in 2:length(especs)
                        if !con_hijo[i] && especs[i].sol.slot + Delta >= slot]
            isempty(cands) && (cands = Int[length(especs)])
            length(cands) > 15 && (cands = cands[randperm(rng, length(cands))[1:15]])
            s = solucion(pk=pk, sector=sector, historia=0, pieza=pieza, slot=slot,
                         flujo=fl, sr=Int(rand(rng, 0:3)), sd=sd)
            push!(especs, BloqueEspec("B$(length(especs))", sort(cands), s))
        end
    end
    return especs
end
