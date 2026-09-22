# dag_sim.jl — simulador v0.3.
#
# Correcciones respecto a v0.2 (encargo v0.3):
#  - el autor conoce su bloque INMEDIATAMENTE; `Δ=0` es realmente 0 (drenaje en el
#    mismo slot tras la producción);
#  - las entregas se drenan al final (convención terminal simétrica);
#  - cada bloque lleva `DescriptorFlujo`/`PotOrigin`/`N(s)` y R-FIN-5 se aplica a TODO
#    `past(B)` antes de entregar a GDR;
#  - un único productor no genera rojos por latencia consigo mismo;
#  - los `S` flujos se generan conjuntamente desde oportunidades compartidas;
#  - se modelan presentación, validación, intento de fusión y decisión del observador;
#  - se miden `η_h` y `η_a` por separado.
#
# Sigue siendo instrumento: GDR-v0.2 colorea; no se reimplementa GHOSTDAG.

mutable struct BloqueV3
    id::Int
    autor::Symbol          # :honesto | :adversario
    rama::Int              # 0 pública, s≥1 rama adversaria
    slot::Int
    padres::Vector{Int}
    flujo::DescriptorFlujo
    billete::Int
    sr::UInt64
    sd::UInt64
    estado::Symbol         # :valido | :invalido_rfin5 | :invalido_u2 | :pendiente
end

struct Decision
    observador::Symbol
    rama::Int
    W_pub::BigInt
    W_priv::BigInt
    clasif::Symbol         # :adopta_privada | :mantiene_publica | :empate | :pendiente
    fusion::Symbol         # :posible | :rechazada_rfin5 | :rechazada_u2 | :na
    motivo::String
end

struct ConfigSimV3
    n_honestos::Int
    alpha::Float64
    delta::Int
    max_padres::Int
    S::Int
    T::Int
    t_fork::Int
    t_presenta::Int
    k::Int
    sr_constante::UInt64
    modo_correlacion::Symbol
    F_finalidad::Int       # 0 = no configurada ⇒ decisión del veterano Pendiente
    inyeccion_cada::Int
end

function ConfigSimV3(; n_honestos=4, alpha=0.2, delta=2, max_padres=15, S=1, T=200,
                     t_fork=1, t_presenta=-1, k=30, sr_constante=UInt64(1),
                     modo_correlacion=:derivada, F_finalidad=0, inyeccion_cada=50)
    return ConfigSimV3(Int(n_honestos), Float64(alpha), Int(delta), Int(max_padres),
                       Int(S), Int(T), Int(t_fork),
                       t_presenta < 0 ? Int(T) : Int(t_presenta), Int(k),
                       UInt64(sr_constante), Symbol(modo_correlacion),
                       Int(F_finalidad), Int(inyeccion_cada))
end

mutable struct SimuladorV3{R}
    dag::SimboloDAG
    bloques::Vector{BloqueV3}
    anc::Vector{BitSet}
    vista::Vector{BitSet}
    entregas::Vector{Tuple{Int,Int,Int}}
    cfg::ConfigSimV3
    rng::R
    flujo_publico::DescriptorFlujo
    flujos_rama::Vector{DescriptorFlujo}
    oportunidades::Matrix{Bool}
    rechazos::Dict{Symbol,Int}
end

function SimuladorV3(cfg::ConfigSimV3, rng::R; k::Integer=cfg.k) where {R}
    dag = SimboloDAG(; k=k, s_max=150, id_genesis="G")
    iny = collect(cfg.inyeccion_cada:cfg.inyeccion_cada:max(cfg.T * 3, 3 * cfg.inyeccion_cada))
    fp = construir_flujo(; rama=0, t_fork=cfg.t_fork, inyecciones=iny,
                         I_slots=cfg.inyeccion_cada)
    fr = [construir_flujo(; rama=s, t_fork=cfg.t_fork, inyecciones=iny,
                          I_slots=cfg.inyeccion_cada) for s in 1:cfg.S]
    bl = [BloqueV3(1, :honesto, 0, 0, Int[], fp, 0, UInt64(0), UInt64(0), :valido)]
    anc = [BitSet()]
    vistas = [BitSet([1]) for _ in 1:cfg.n_honestos]
    ops = oportunidades_compartidas(rng, cfg.T, cfg.S, cfg.alpha, cfg.modo_correlacion)
    return SimuladorV3{R}(dag, bl, anc, vistas, Tuple{Int,Int,Int}[], cfg, rng,
                          fp, fr, ops, Dict{Symbol,Int}())
end

"""
Oportunidades físicas compartidas para los `S` flujos.
- `:perfecta`  → todos los flujos idénticos (correlación 1);
- `:iid`       → sorteos independientes por flujo;
- `:derivada`  → oportunidad base común mezclada con el índice de flujo.
"""
function oportunidades_compartidas(rng, T::Integer, S::Integer, alpha::Real, modo::Symbol)
    flags = falses(T, S)
    u = rand(rng, T)
    for t in 1:T, s in 1:S
        if modo == :perfecta
            flags[t, s] = u[t] < alpha
        elseif modo == :iid
            flags[t, s] = rand(rng) < alpha
        else
            x = mod(u[t] + 0.6180339887498949 * s, 1.0)
            flags[t, s] = x < alpha
        end
    end
    return flags
end

"Conjunto de ancestros estrictos de un bloque del simulador."
_pasado(sim::SimuladorV3, padres::Vector{Int}) = begin
    s = BitSet()
    for p in padres
        push!(s, p)
        union!(s, sim.anc[p])
    end
    s
end

"Puntas de una vista (bloques vistos sin hijo visto)."
function _puntas_vista(sim::SimuladorV3, nodo::Integer)
    v = sim.vista[nodo]
    es_padre = falses(length(sim.bloques))
    for b in v, p in sim.bloques[b].padres
        es_padre[p] = true
    end
    return [b for b in v if !es_padre[b]]
end

function _elegir_padres(sim::SimuladorV3, nodo::Integer)
    tips = _puntas_vista(sim, nodo)
    isempty(tips) && return [1]
    length(tips) == 1 && return tips
    orden = sort(tips; by=t -> (-blue_work_bigint(sim.dag, t), t))
    virtual = orden[1]
    resto = orden[2:end]
    shuffle!(sim.rng, resto)
    sel = Int[virtual]
    for p in resto
        length(sel) >= sim.cfg.max_padres && break
        push!(sel, p)
    end
    return sort(sel)
end

"""
Añade un bloque si pasa, **en este orden**: R-FIN-5 sobre TODO `past(B)`, U2 y GDR.
Devuelve `(id, estado)`. Un bloque no válido no se incorpora.
"""
function _anadir_bloque!(sim::SimuladorV3, autor::Symbol, rama::Integer, slot::Integer,
                         padres::Vector{Int}, flujo::DescriptorFlujo, billete::Integer)
    past = _pasado(sim, padres)
    # R-FIN-5 sobre todo el pasado
    pend = false
    for x in past
        v = compatible_rfin5(flujo, sim.bloques[x].flujo, sim.bloques[x].slot)
        v == INVALIDA && (sim.rechazos[:rfin5] = get(sim.rechazos, :rfin5, 0) + 1;
                          return 0, :invalido_rfin5)
        v == PENDIENTE && (pend = true)
    end
    # horizonte de justificación separado (punto 2)
    slot_sp = isempty(padres) ? slot : sim.bloques[padres[1]].slot
    if horizonte_justificacion_ok(flujo, slot_sp, slot) == INVALIDA
        sim.rechazos[:horizonte] = get(sim.rechazos, :horizonte, 0) + 1
        return 0, :invalido_horizonte
    end
    # U2
    for x in past
        if sim.bloques[x].billete == billete && billete != 0
            sim.rechazos[:u2] = get(sim.rechazos, :u2, 0) + 1
            return 0, :invalido_u2
        end
    end
    id = length(sim.bloques) + 1
    ok = agregar!(sim.dag, "B$(id)", copy(padres), slot, id, sim.cfg.sr_constante, billete)
    if !ok
        sim.rechazos[:gdr] = get(sim.rechazos, :gdr, 0) + 1
        return 0, :gdr
    end
    estado = pend ? :pendiente : :valido
    push!(sim.bloques, BloqueV3(id, autor, rama, slot, copy(padres), flujo, Int(billete),
                                sim.cfg.sr_constante, UInt64(id), estado))
    push!(sim.anc, copy(past))
    return id, estado
end

function _programar_entrega!(sim::SimuladorV3, id::Integer, slot::Integer, autor::Integer)
    # el autor ya lo conoce; se entrega a los demás en slot+Δ
    for nodo in 1:sim.cfg.n_honestos
        nodo == autor && continue
        push!(sim.entregas, (slot + sim.cfg.delta, nodo, id))
    end
end

"Drena entregas con llegada ≤ `slot` (consumiéndolas)."
function _drenar!(sim::SimuladorV3, slot::Integer)
    i = 1
    while i <= length(sim.entregas)
        (lleg, nodo, id) = sim.entregas[i]
        if lleg <= slot
            push!(sim.vista[nodo], id)
            sim.entregas[i] = sim.entregas[end]
            pop!(sim.entregas)
        else
            i += 1
        end
    end
    return nothing
end

"Drena a TODOS los nodos (convención terminal simétrica)."
function _drenar_todo!(sim::SimuladorV3)
    for (lleg, nodo, id) in sim.entregas
        push!(sim.vista[nodo], id)
    end
    empty!(sim.entregas)
    return nothing
end

function _blue_work_tip(sim::SimuladorV3, tip::Integer)
    return blue_work_bigint(sim.dag, tip)
end

function _mejor_tip_rama(sim::SimuladorV3, rama::Integer)
    ids = [b.id for b in sim.bloques if b.rama == rama && b.estado == :valido]
    isempty(ids) && return 0
    return sort(ids; by=t -> (-_blue_work_tip(sim, t), t))[1]
end

# ---------------------------------------------------------------------------
# η por lado: trabajo azul / trabajo bruto elegible, en el contexto de la punta
# de su propia rama.
# ---------------------------------------------------------------------------
function _eta_rama(sim::SimuladorV3, rama::Integer, autor::Symbol)
    ids = [b.id for b in sim.bloques if b.rama == rama && b.estado == :valido &&
           b.autor == autor]
    isempty(ids) && return (eta=0.0, azul=big(0), bruto=big(0), n=0)
    tip = _mejor_tip_rama(sim, rama)
    bs = GhostdagRank.blueset(sim.dag.est, tip)
    az = big(0)
    for x in ids
        x in bs && (az += peso_de(sim.dag, x))
    end
    bruto = sum(peso_de(sim.dag, x) for x in ids; init=big(0))
    return (eta=bruto == 0 ? 0.0 : Float64(az / bruto), azul=az, bruto=bruto, n=length(ids))
end

# ---------------------------------------------------------------------------
# Simulación
# ---------------------------------------------------------------------------
struct ResultadoV3
    W_pub::BigInt
    W_priv_terminal::Vector{BigInt}
    W_priv_paso::Vector{BigInt}
    exitos_terminal::Vector{Bool}
    exitos_paso::Vector{Bool}
    total_bloques::Int
    azules::Int
    rojos::Int
    u3::Int
    rojos_h::Int
    rojos_a::Int
    decisiones::Vector{Decision}
    eta_h::Float64
    eta_a::Vector{Float64}
    modo_correlacion::Symbol
    rechazos::Dict{Symbol,Int}
end

function simular_v3!(cfg::ConfigSimV3, rng)
    sim = SimuladorV3(cfg, rng; k=cfg.k)
    p_hon = (1 - cfg.alpha) / cfg.n_honestos
    mejor_pub = 1
    mejor_rama = fill(0, cfg.S)
    raiz_comun = 0                   # punta pública congelada en el fork (prefijo común)
    dif_paso_max = fill(big(-1) * big(10)^40, cfg.S)
    # --- fase pública + ramas adversarias ---
    for slot in 1:cfg.T
        _drenar!(sim, slot)
        for nodo in 1:cfg.n_honestos
            rand(sim.rng) < p_hon || continue
            padres = _elegir_padres(sim, nodo)
            id, est = _anadir_bloque!(sim, :honesto, 0, slot, padres,
                                      sim.flujo_publico, id_global(sim))
            if id != 0
                push!(sim.vista[nodo], id)          # el autor lo conoce de inmediato
                _programar_entrega!(sim, id, slot, nodo)
                if id == mejor_pub || _blue_work_tip(sim, id) >= _blue_work_tip(sim, mejor_pub)
                    mejor_pub = id
                end
            end
        end
        if slot == max(cfg.t_fork, 1)
            raiz_comun = mejor_pub             # base común congelada antes de divergir
        end
        if slot >= max(cfg.t_fork, 1)
            for s in 1:cfg.S
                sim.oportunidades[slot, s] || continue
                fl = sim.flujos_rama[s]
                raiz = mejor_rama[s] == 0 ? (raiz_comun == 0 ? mejor_pub : raiz_comun) : mejor_rama[s]
                propios = [b.id for b in sim.bloques if b.rama == s && b.estado == :valido]
                tips_r = _tips_rama(sim, propios, raiz)
                id, est = _anadir_bloque!(sim, :adversario, s, slot, tips_r, fl,
                                          _billete_libre(sim, s, slot))
                if id != 0 && (mejor_rama[s] == 0 ||
                               _blue_work_tip(sim, id) >= _blue_work_tip(sim, mejor_rama[s]))
                    mejor_rama[s] = id
                end
            end
        end
        if cfg.delta == 0
            _drenar!(sim, slot)                     # Δ=0 ⇒ mismo slot, tras producir
        end
        # primera pasada: diferencia observada al final de cada slot
        if slot >= max(cfg.t_fork, 1)
            bwpub = _blue_work_tip(sim, mejor_pub)
            for s in 1:cfg.S
                if mejor_rama[s] != 0
                    d = _blue_work_tip(sim, mejor_rama[s]) - bwpub
                    d > dif_paso_max[s] && (dif_paso_max[s] = d)
                end
            end
        end
    end
    # presentación + drenaje terminal simétrico
    _drenar_todo!(sim)
    # --- medición: TODOS los incrementos son POST-FORK (prefijo común contado UNA vez) ---
    punta_pub = mejor_pub
    fork_ref = raiz_comun == 0 ? 1 : raiz_comun
    bw_fork = _blue_work_tip(sim, fork_ref)
    W_pub = max(big(0), _blue_work_tip(sim, punta_pub) - bw_fork)
    Wterm = BigInt[]
    Wpaso = BigInt[]
    eterm = Bool[]
    epaso = Bool[]
    for s in 1:cfg.S
        tip = mejor_rama[s]
        if tip == 0
            push!(Wterm, big(0)); push!(Wpaso, big(0))
            push!(eterm, false); push!(epaso, false)
            continue
        end
        wp = _blue_work_tip(sim, tip) - bw_fork
        push!(Wterm, wp)
        push!(Wpaso, dif_paso_max[s])   # (W_priv − W_pub), la resta cancela el fork
        push!(epaso, dif_paso_max[s] > 0)
        push!(eterm, wp > W_pub)
    end
    # colores y rojos por autor
    az = Int(sim.dag.est.gd[punta_pub].blue_score)
    set_r = Set{Int}(); set_u3 = Set{Int}()
    for i in 1:sim.dag.est.n
        for (x, t) in sim.dag.est.gd[i].tipos
            t == 0x01 && push!(set_r, x)
            t == 0x02 && push!(set_u3, x)
        end
    end
    rojos_h = count(x -> x <= length(sim.bloques) && sim.bloques[x].autor == :honesto, set_r)
    rojos_a = count(x -> x <= length(sim.bloques) && sim.bloques[x].autor == :adversario, set_r)
    # η
    eta_h = _eta_rama(sim, 0, :honesto).eta
    eta_a = [_eta_rama(sim, s, :adversario).eta for s in 1:cfg.S]
    decisiones = _decisiones(sim, W_pub, Wterm)
    return ResultadoV3(W_pub, Wterm, Wpaso, eterm, epaso, length(sim.bloques) - 1,
                       az, length(set_r), length(set_u3), rojos_h, rojos_a,
                       decisiones, eta_h, eta_a, cfg.modo_correlacion, sim.rechazos)
end

id_global(sim::SimuladorV3) = 10_000 + length(sim.bloques)

function _billete_libre(sim::SimuladorV3, rama::Integer, slot::Integer)
    return 1_000_000 + rama * 100_000 + slot     # único por rama y slot
end

function _tips_rama(sim::SimuladorV3, propios::Vector{Int}, raiz::Integer)
    conjunto = Set(propios); push!(conjunto, raiz)
    es_padre = Set{Int}()
    for b in conjunto, p in sim.bloques[b].padres
        p in conjunto && push!(es_padre, p)
    end
    tips = [b for b in conjunto if !(b in es_padre)]
    return isempty(tips) ? [raiz] : sort(collect(tips))
end

# ---------------------------------------------------------------------------
# Decisión explícita del observador y intento de fusión
# ---------------------------------------------------------------------------
function _fusion_posible(sim::SimuladorV3, flujo_a::DescriptorFlujo, flujo_b::DescriptorFlujo,
                         past_a::BitSet, past_b::BitSet)
    for x in past_b
        compatible_rfin5(flujo_a, sim.bloques[x].flujo, sim.bloques[x].slot) == INVALIDA &&
            return :rechazada_rfin5
    end
    for x in past_a
        compatible_rfin5(flujo_b, sim.bloques[x].flujo, sim.bloques[x].slot) == INVALIDA &&
            return :rechazada_rfin5
    end
    return :posible
end

function _decisiones(sim::SimuladorV3, W_pub::BigInt, Wterm::Vector{BigInt})
    ds = Decision[]
    tip_pub = _mejor_tip_rama(sim, 0)
    for (obs, F) in ((:nuevo, 0), (:veterano, sim.cfg.F_finalidad), (:eclipsado, -1))
        for s in 1:sim.cfg.S
            tip_s = _mejor_tip_rama(sim, s)
            if obs == :eclipsado
                push!(ds, Decision(obs, s, W_pub, Wterm[s], :pendiente, :na,
                                   "solo ve su rama: no puede comparar"))
                continue
            end
            if obs == :veterano && F <= 0
                push!(ds, Decision(obs, s, W_pub, Wterm[s], :pendiente, :na,
                                   "F provisional/no configurada (R-FIN-7)"))
                continue
            end
            if tip_s == 0 || tip_pub == 0
                push!(ds, Decision(obs, s, W_pub, Wterm[s], :mantiene_publica, :na,
                                   "rama ausente o vacía"))
                continue
            end
            fus = _fusion_posible(sim, sim.bloques[tip_pub].flujo, sim.bloques[tip_s].flujo,
                                  sim.anc[tip_pub], sim.anc[tip_s])
            clasif = Wterm[s] > W_pub ? :adopta_privada :
                     (Wterm[s] == W_pub ? :empate : :mantiene_publica)
            push!(ds, Decision(obs, s, W_pub, Wterm[s], clasif, fus,
                               "punta pública blue_work vs rama $(s)"))
        end
    end
    return ds
end

# ---------------------------------------------------------------------------
# Fixtures deterministas (recuperados de v0.2)
# ---------------------------------------------------------------------------
function fixture_rojo_conocido(; k::Integer=2)
    n = k + 3
    dag = SimboloDAG(; k=k, id_genesis="G")
    herm = Int[]
    for i in 1:n
        agregar!(dag, "H$(i)", [1], 1, 0, 1, i); push!(herm, 1 + i)
    end
    agregar!(dag, "M", copy(herm), 2, 0, 1, n + 1)
    return dag, 1 + n + 1, herm, herm[end]
end

function fixture_cero_rojos(; k::Integer=30)
    n = min(k + 1, 15)
    dag = SimboloDAG(; k=k, id_genesis="G")
    herm = Int[]
    for i in 1:n
        agregar!(dag, "H$(i)", [1], 1, 0, 1, i); push!(herm, 1 + i)
    end
    agregar!(dag, "M", copy(herm), 2, 0, 1, n + 1)
    return dag, 1 + n + 1, herm
end
