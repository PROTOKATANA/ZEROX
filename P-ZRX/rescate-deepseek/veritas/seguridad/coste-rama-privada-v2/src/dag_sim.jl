# dag_sim.jl — simulación por eventos/vistas locales (encargo D1).
#
# Corrección obligatoria de D1: los bloques concurrentes se producen contra la vista
# disponible en el instante de autoría, ANTES de recibir bloques todavía en tránsito.
# La propagación posterior crea puntas, anticonos y rojos reales. El coloreo NO se
# reimplementa: lo hace GDR-v0.2 (`SimboloDAG`). Aquí se eligen padres (C-GD-10),
# se aplica R-FIN-5 **estructural** antes de entregar a GDR (`_flujo_en` /
# `_anadir_bloque!`: un bloque no puede incorporar un padre de flujo ajeno) y se mide
# trabajo post-fork. GDR no conoce el flujo: la envoltura estructural es la que decide
# la incorporación, y no se afirma que GDR verifique R-FIN-5.
#
# Límite declarado: la selección de padres es una aproximación de C-GD-10 (cola de
# candidatos barajada, incluyendo la punta de mayor `blue_work`). No se afirma que
# reproduzca el nodo. El orden dentro de un slot se resuelve por índice de creación.

mutable struct BloqueDAG
    id::Int
    autor::Symbol       # :honesto | :adversario
    rama::Int           # 0 = pública, >0 = rama adversaria privada
    slot::Int
    padres::Vector{Int}
end

struct ConfigSim
    n_honestos::Int
    p_honesto::Float64       # prob. de producir por nodo y slot
    delta::Int               # latencia de propagación honesta, en slots
    max_padres::Int
    p_adversario::Float64    # prob. de producir por rama y slot
    S::Int                   # número de ramas adversarias (escenario)
    T::Int                   # horizonte en slots
    t_fork::Int              # slot en que el adversario abre su rama
    sr_constante::UInt64
end

function ConfigSim(; n_honestos=4, p_honesto=0.25, delta=1, max_padres=15,
                   p_adversario=0.1, S=1, T=100, t_fork=0, sr_constante=UInt64(1))
    return ConfigSim(Int(n_honestos), Float64(p_honesto), Int(delta), Int(max_padres),
                     Float64(p_adversario), Int(S), Int(T), Int(t_fork),
                     UInt64(sr_constante))
end

"""
Resultado de una réplica. `W_priv` es por rama; `W_pub` es el incremento de la punta
pública post-fork. El escenario R-FIN-5 incorpora **la mejor rama** (máximo); el
contrafactual aditivo usa la **suma**, que no es una regla adoptada.
"""
struct ResultadoSim
    W_pub::BigInt
    W_priv::Vector{BigInt}
    azules_publicos::Int
    rojos_publicos::Int
    rojos_u3_publicos::Int
    total_bloques::Int
    fork_idx::Int
    tips_publicas::Int
end

mutable struct Simulador{R}
    dag::SimboloDAG
    bloques::Vector{BloqueDAG}
    vista::Vector{BitSet}          # por nodo honesto
    entregas::Vector{Tuple{Int,Int,Int}}   # (slot_llegada, nodo, id_bloque)
    cfg::ConfigSim
    rng::R
end

function Simulador(cfg::ConfigSim, rng::R; k::Integer=30) where {R}
    dag = SimboloDAG(; k=k, s_max=150, id_genesis="G")
    bl = [BloqueDAG(1, :honesto, 0, 0, Int[])]
    vistas = [BitSet([1]) for _ in 1:cfg.n_honestos]
    return Simulador(dag, bl, vistas, Tuple{Int,Int,Int}[], cfg, rng)
end

"Puntas de una vista (bloques vistos sin hijo visto)."
function _puntas_vista(sim::Simulador, nodo::Integer)
    v = sim.vista[nodo]
    es_padre = falses(length(sim.bloques))
    for b in v, p in sim.bloques[b].padres
        es_padre[p] = true
    end
    return [b for b in v if !es_padre[b]]
end

"""
Selección de padres C-GD-10: hasta `max_padres` puntas de una cola de candidatos
barajada, incluyendo siempre la punta de mayor `blue_work` (punta virtual aproximada).
"""
function _elegir_padres(sim::Simulador, nodo::Integer)
    tips = _puntas_vista(sim, nodo)
    isempty(tips) && return [1]
    if length(tips) == 1
        return tips
    end
    # punta virtual: mayor blue_work ya presente
    orden = sort(tips; by=t -> (-blue_work_bigint(sim.dag, t), t))
    virtual = orden[1]
    resto = orden[2:end]
    shuffle!(sim.rng, resto)
    seleccion = Int[virtual]
    for p in resto
        length(seleccion) >= sim.cfg.max_padres && break
        push!(seleccion, p)
    end
    return sort(seleccion)
end

"""
Flujo estructural por slot: público (0) hasta `t_fork`; rama `rama` después. R-FIN-5
prohíbe que un bloque incorpore un padre cuyo flujo en `slot(padre)` sea distinto.
"""
function _flujo_en(rama::Integer, slot::Integer, t_fork::Integer)
    return slot <= t_fork ? 0 : Int(rama)
end

"""
Añade un bloque si pasa (a) R-FIN-5 estructural contra cada padre y (b) GDR. El
bloque rechazado **no** se incorpora a `sim.bloques`. Devuelve `(id, ok)`.
"""
function _anadir_bloque!(sim::Simulador, autor::Symbol, rama::Integer, slot::Integer,
                         padres::Vector{Int})
    tf = max(sim.cfg.t_fork, 1)
    for p in padres
        bp = sim.bloques[p]
        if _flujo_en(bp.rama, bp.slot, tf) != _flujo_en(rama, bp.slot, tf)
            return 0, false                       # R-FIN-5: flujo ajeno
        end
    end
    id = length(sim.bloques) + 1
    ident = id                      # billete único por bloque (U2 no invalida)
    ok = agregar!(sim.dag, "B$(id)", copy(padres), slot, id, sim.cfg.sr_constante, ident)
    ok || return id, false
    push!(sim.bloques, BloqueDAG(id, autor, rama, slot, copy(padres)))
    return id, true
end

function _programar_entrega!(sim::Simulador, id::Integer, slot_produccion::Integer)
    destino = slot_produccion + sim.cfg.delta
    for nodo in 1:sim.cfg.n_honestos
        push!(sim.entregas, (destino, nodo, id))
    end
end

function _procesar_entregas!(sim::Simulador, slot::Integer)
    i = 1
    while i <= length(sim.entregas)
        (llegada, nodo, id) = sim.entregas[i]
        if llegada <= slot
            push!(sim.vista[nodo], id)
            sim.entregas[i] = sim.entregas[end]
            pop!(sim.entregas)
        else
            i += 1
        end
    end
    return nothing
end

"Simula una réplica y devuelve el resultado. Determinista dada la semilla."
function simular!(cfg::ConfigSim, rng; k::Integer=30)
    sim = Simulador(cfg, rng; k=k)
    forks = Int[]                    # índice del bloque raíz de cada rama adversaria
    t_fork = max(cfg.t_fork, 1)
    # --- fase pública y ramas adversarias ---
    for slot in 1:cfg.T
        _procesar_entregas!(sim, slot)
        # producción honesta contra la vista local
        for nodo in 1:cfg.n_honestos
            rand(rng) < cfg.p_honesto || continue
            padres = _elegir_padres(sim, nodo)
            id, ok = _anadir_bloque!(sim, :honesto, 0, slot, padres)
            ok || continue
            _programar_entrega!(sim, id, slot)
        end
        # el adversario abre sus ramas en t_fork sobre la punta pública visible
        if slot == t_fork
            for s in 1:cfg.S
                tips_pub = _puntas_vista(sim, 1)
                forkp = isempty(tips_pub) ? 1 : sort(tips_pub; by=t -> (-blue_work_bigint(sim.dag, t), t))[1]
                push!(forks, forkp)
            end
        end
        # producción adversaria privada (no se entrega a los honestos)
        if slot >= t_fork
            for s in 1:cfg.S
                rand(rng) < cfg.p_adversario || continue
                # padres de la rama s: puntas de los bloques previos de esa rama + raíz
                propios = [b.id for b in sim.bloques if b.rama == s]
                raiz = forks[s]
                candidatos = isempty(propios) ? [raiz] : propios
                tips_r = _puntas_rama(sim, candidatos, raiz)
                id, ok = _anadir_bloque!(sim, :adversario, s, slot, tips_r)
                ok || continue
            end
        end
    end
    # --- medición post-fork ---
    if isempty(forks)
        return ResultadoSim(big(0), BigInt[], 0, 0, 0, length(sim.bloques) - 1, 1, 0)
    end
    tips_pub = _puntas_vista(sim, 1)
    punta_pub = isempty(tips_pub) ? 1 :
                sort(tips_pub; by=t -> (-blue_work_bigint(sim.dag, t), t))[1]
    fork_ref = forks[1]
    W_pub = max(big(0), blue_work_bigint(sim.dag, punta_pub) - blue_work_bigint(sim.dag, fork_ref))
    W_priv = BigInt[]
    for s in 1:cfg.S
        propios = [b.id for b in sim.bloques if b.rama == s]
        if isempty(propios)
            push!(W_priv, big(0))
            continue
        end
        tip_s = sort(propios; by=t -> (-blue_work_bigint(sim.dag, t), t))[1]
        push!(W_priv, max(big(0), blue_work_bigint(sim.dag, tip_s) - blue_work_bigint(sim.dag, fork_ref)))
    end
    # estadísticas: `blue_score` de la punta pública (azules reales acumulados) y
    # rojos/U3 **distintos** observados en algún contexto de fusión del DAG.
    az = Int(sim.dag.est.gd[punta_pub].blue_score)
    set_roj = Set{Int}()
    set_u3 = Set{Int}()
    for i in 1:sim.dag.est.n
        gd = sim.dag.est.gd[i]
        for (x, t) in gd.tipos
            x <= length(sim.bloques) || continue
            sim.bloques[x].rama == 0 || continue
            t == 0x01 && push!(set_roj, x)
            t == 0x02 && push!(set_u3, x)
        end
    end
    return ResultadoSim(W_pub, W_priv, az, length(set_roj), length(set_u3),
                        length(sim.bloques) - 1, fork_ref, length(tips_pub))
end

"Puntas de un subconjunto de bloques de una rama, ancladas en `raiz`."
function _puntas_rama(sim::Simulador, candidatos::Vector{Int}, raiz::Integer)
    conjunto = Set(candidatos)
    push!(conjunto, raiz)
    es_padre = Set{Int}()
    for b in conjunto, p in sim.bloques[b].padres
        p in conjunto && push!(es_padre, p)
    end
    tips = [b for b in conjunto if !(b in es_padre)]
    return isempty(tips) ? [raiz] : sort(tips)
end

"""
Fixture determinista con `rojo_k` conocido: `n = k+3` hermanos (todos hijos del génesis)
fusionados por un bloque M. A partir del candidato `k+2` el anticono azul supera `k`, así
que hay `rojo_k` en el contexto de M. Devuelve `(dag, idx_M, ids_hermanos, idx_rojo)`;
se comprueba `rojo_k` en el último hermano.
"""
function fixture_rojo_conocido(; k::Integer=2)
    n = k + 3
    dag = SimboloDAG(; k=k, id_genesis="G")
    hermanos = Int[]
    for i in 1:n
        agregar!(dag, "H$(i)", [1], 1, 0, 1, i)
        push!(hermanos, 1 + i)
    end
    agregar!(dag, "M", copy(hermanos), 2, 0, 1, n + 1)
    idx_M = 1 + n + 1
    return dag, idx_M, hermanos, hermanos[end]
end

"Fixture determinista con cero rojos: `min(k+1,15)` hermanos fusionados; ninguno excede k."
function fixture_cero_rojos(; k::Integer=30)
    n = min(k + 1, 15)
    dag = SimboloDAG(; k=k, id_genesis="G")
    hermanos = Int[]
    for i in 1:n
        agregar!(dag, "H$(i)", [1], 1, 0, 1, i)
        push!(hermanos, 1 + i)
    end
    agregar!(dag, "M", copy(hermanos), 2, 0, 1, n + 1)
    idx_M = 1 + n + 1
    return dag, idx_M, hermanos
end
