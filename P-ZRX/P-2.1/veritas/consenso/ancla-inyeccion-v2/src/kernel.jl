# ANCLA-v0.2 — kernel: mundo por escenario, GHOSTDAG por vista (GDR-v0.2 sin modificar),
# seguimiento incremental del ancla por umbral (saltos binarios, parada temprana con
# re-evaluación completa por replay), entrega con clausura de ancestros (ENCARGO: recv =
# max(llega, max recv(padres))), y ancla definitiva por punto fijo restringido a
# {slot < t_j} (ENCARGO §3.1).
#
# Slots enteros 0..H (τ_nom = 1 s/slot); tiempos de llegada Float64 (enteros en células
# uniformes). Bloques GLOBALES 1..nblo (1 = génesis); cada estado tiene índices locales.

const NLEV = 13   # saltos 2^(k-1), k=1..NLEV (cubre 8191 > H)

# ------- entrada del heap de puntas (SP_ZEROX: máx bw, empate mín sd, mín id) --------
struct TipEntrada
    bw_hi::UInt128
    bw_lo::UInt128
    sd::UInt64
    id::ID32
    b::Int32
end

function mejor_tip(a::TipEntrada, b::TipEntrada)
    a.bw_hi != b.bw_hi && return a.bw_hi > b.bw_hi
    a.bw_lo != b.bw_lo && return a.bw_lo > b.bw_lo
    a.sd != b.sd && return a.sd < b.sd
    return a.id < b.id
end

Base.isless(a::TipEntrada, b::TipEntrada) = mejor_tip(a, b)

# ------- colas de llegada (mín-heap por tiempo; empate, bloque menor = padre antes) ----
struct Arrival
    t::Float64
    b::Int32
end

Base.isless(a::Arrival, b::Arrival) = (a.t < b.t) || (a.t == b.t && a.b < b.b)

struct EventoRed
    t::Float64
    bi::Int32
    desde::Int32
    hasta::Int32
end

Base.isless(a::EventoRed, b::EventoRed) = a.t < b.t

# ------- estado de una vista (observador o latencia cero) ----------------------------
mutable struct ObsTrack
    est::GhostdagRank.EstadoRapido
    loc::Vector{Int32}            # bloque global -> local (0 = no insertado)
    g_de_loc::Vector{Int32}       # local -> global
    n_hijos::Vector{Int32}
    es_tip::BitVector
    tips::Vector{Int32}
    pos_tip::Vector{Int32}
    heap::Vector{TipEntrada}
    up::Matrix{Int32}             # NLEV × maxblo
    t_log::Vector{Float64}        # tiempo de cada cambio de punta
    tip_log::Vector{Int32}
    prev_tip::Int32
    t_insert::Vector{Float64}
    ancla::Vector{Int32}          # ancla actual por umbral (GLOBAL, 0 = sin ancla)
    ev_t::Vector{Vector{Float64}}
    ev_x::Vector{Vector{Int32}}   # ancla nueva en cada cambio (GLOBAL)
    last_change::Vector{Float64}
end

function ObsTrack(est, maxblo::Int, nj::Int)
    tr = ObsTrack(est, zeros(Int32, maxblo), zeros(Int32, maxblo), zeros(Int32, maxblo),
                  falses(maxblo), Int32[], zeros(Int32, maxblo), TipEntrada[],
                  zeros(Int32, NLEV, maxblo), Float64[], Int32[], Int32(1),
                  zeros(Float64, maxblo), zeros(Int32, nj),
                  [Float64[] for _ in 1:nj], [Int32[] for _ in 1:nj],
                  zeros(Float64, nj))
    tr.loc[1] = 1; tr.g_de_loc[1] = 1; tr.es_tip[1] = true
    push!(tr.tips, Int32(1)); tr.pos_tip[1] = 1
    tr.t_insert[1] = 0.0
    return tr
end

# ------- plan de réplica (compartido por todos los escenarios) ------------------------
struct PlanReplica
    replica::Int
    sh_semilla::UInt64
    ev_h::Vector{Int}
    ev_a::Vector{Int}
    sd_h::Vector{UInt64}
    sd_a::Vector{UInt64}
    ident_h::Vector{UInt64}
    ident_a::Vector{UInt64}
    creator_h::Vector{Int16}      # nodo creador por evento honesto (DMS)
    arr_h::Matrix{Float64}        # llegadas flood (n_ev_h × n_red); 0×0 si no DMS
    grafo::Any
end

"Genera el calendario de eventos de la réplica (RNG independiente por réplica)."
function plan_replica(pr::Params4A, replica::Int, semilla::Integer)
    rng = rng_replica(UInt64(semilla), replica)
    ev_h = Int[]; ev_a = Int[]
    for s in 1:pr.H
        rand(rng) < 1 - exp(-pr.λ*(1-pr.α)) && push!(ev_h, s)
        rand(rng) < 1 - exp(-pr.λ*pr.α) && push!(ev_a, s)
    end
    sd_h = [rand(rng, UInt64) for _ in ev_h]
    sd_a = [rand(rng, UInt64) for _ in ev_a]
    ident_h = collect(UInt64, 2:length(ev_h)+1)
    ident_a = collect(UInt64, length(ev_h)+2:length(ev_h)+length(ev_a)+1)
    arr_h = zeros(0, 0); creator_h = Int16[]; grafo = nothing
    if pr.Δ == 0.0
        grafo = red_erdos_renyi(rng, pr.n_red, pr.grado, pr.μ_lat, pr.σ_lat)
        creator_h = [Int16(rand(rng, 1:pr.n_red)) for _ in 1:length(ev_h)]
        arr_h = fill(Inf, length(ev_h), pr.n_red)
        precomputar_flood!(pr, grafo, ev_h, creator_h, arr_h)
    end
    return PlanReplica(replica, semilla ⊻ UInt64(replica)*0x2545F4914F6CDD1D,
                       ev_h, ev_a, sd_h, sd_a, ident_h, ident_a, creator_h, arr_h, grafo)
end

"Inundación hop-by-hop con cola serial (modelo DMS-v0.1): llegadas de bloques honestos."
function precomputar_flood!(pr::Params4A, grafo, ev_h::Vector{Int},
                            creator_h::Vector{Int16}, arr_h::Matrix{Float64})
    H = EventoRed[]
    next_free = zeros(Float64, pr.n_red)
    for (i, s) in enumerate(ev_h)
        u = Int(creator_h[i])
        arr_h[i, u] = s
        nf = max(Float64(s), next_free[u])
        @inbounds for k in Int(grafo.offsets[u]):(Int(grafo.offsets[u+1])-1)
            v = Int(grafo.vecinos[k])
            arr_h[i, v] <= s && continue
            nf += pr.t_tx
            hpush!(H, EventoRed(nf + grafo.lat[k], Int32(i), Int32(u), Int32(v)))
        end
        next_free[u] = nf
    end
    while !isempty(H)
        e = hpop!(H)
        i = Int(e.bi); v = Int(e.hasta)
        arr_h[i, v] <= e.t && continue
        arr_h[i, v] = e.t
        nf = max(e.t, next_free[v])
        @inbounds for k in Int(grafo.offsets[v]):(Int(grafo.offsets[v+1])-1)
            w = Int(grafo.vecinos[k])
            arr_h[i, w] <= e.t && continue
            nf += pr.t_tx
            hpush!(H, EventoRed(nf + grafo.lat[k], Int32(i), Int32(v), Int32(w)))
        end
        next_free[v] = nf
    end
    return nothing
end

# ------- escenario (estrategia del atacante) -----------------------------------------
struct Escenario
    nombre::String
    rel::Vector{Int}        # por evento atacante: slot de publicación (-1 = retenido)
    pol::Vector{Symbol}     # :tips | :tips_pub | :sp | :retro
    retro::Vector{Int}
    target::Int8            # A3: observador objetivo (0 = todos)
end

# ------- mundo ------------------------------------------------------------------------
mutable struct Mundo
    pr::Params4A
    plan::PlanReplica
    esc::Escenario
    nblo::Int
    maxblo::Int
    idstr::Vector{String}
    padres_g::Vector{Vector{Int32}}
    slot::Vector{Int}
    sd::Vector{UInt64}
    ident::Vector{UInt64}
    tipo::Vector{UInt8}
    creador::Vector{Int8}
    pub::Vector{Int}
    llega::Matrix{Float64}
    heap_obs::Vector{Vector{Arrival}}
    heap_zl::Vector{Arrival}
    obs::Vector{ObsTrack}
    zl::ObsTrack
    atk::GhostdagRank.EstadoRapido
    loc_atk::Vector{Int32}
    g_de_atk::Vector{Int32}       # local -> global en el estado del atacante
    T::Vector{Int}
    ancla_zl::Vector{Int32}
    ev_zl_t::Vector{Vector{Float64}}
    ev_zl_x::Vector{Vector{Int32}}
    last_change_zl::Vector{Float64}
    n_coinciden::Vector{Int8}
    last_any_change::Vector{Float64}
    stop_time::Vector{Int}
    activo::BitVector
    permite_parada::Bool
    n_h::Int; n_a::Int; sin_sp_h::Int; sin_sp_a::Int; filt_h::Int; filt_a::Int
    retenidos::Int; liberados::Int
end

function Mundo(pr::Params4A, plan::PlanReplica, esc::Escenario)
    maxblo = 2*pr.H + 2
    pg = params_gdr(pr)
    T = [pr.W0 + (j-1)*pr.paso_T for j in 1:pr.n_T]
    obs = [ObsTrack(GhostdagRank.EstadoRapido(pg, "G"; slot_g=UInt64(0), sr_g=pr.sr),
                    maxblo, length(T)) for _ in 1:pr.n_obs]
    zl = ObsTrack(GhostdagRank.EstadoRapido(pg, "G"; slot_g=UInt64(0), sr_g=pr.sr),
                  maxblo, length(T))
    atk = GhostdagRank.EstadoRapido(pg, "G"; slot_g=UInt64(0), sr_g=pr.sr)
    loc_atk = zeros(Int32, maxblo); loc_atk[1] = 1
    g_de_atk = zeros(Int32, maxblo); g_de_atk[1] = 1
    nj = length(T)
    m = Mundo(pr, plan, esc, 1, maxblo, ["G"], [Int32[]], [0], [UInt64(0)], [UInt64(0)],
              [UInt8(1)], [Int8(0)], [0], fill(Inf, maxblo, pr.n_obs),
              [Arrival[] for _ in 1:pr.n_obs], Arrival[], obs, zl, atk,
              loc_atk, g_de_atk, T, zeros(Int32, nj),
              [Float64[] for _ in 1:nj], [Int32[] for _ in 1:nj], zeros(Float64, nj),
              zeros(Int8, nj), fill(-Inf, nj), zeros(Int, nj), trues(nj),
              esc.target == 0,
              0, 0, 0, 0, 0, 0, 0, 0)
    return m
end

# ------- heaps mínimos genéricos (por isless) -----------------------------------------
function hpush!(H::Vector{E}, e::E) where {E}
    push!(H, e); i = length(H)
    @inbounds while i > 1
        p = i >> 1
        isless(H[p], H[i]) && break
        H[p], H[i] = H[i], H[p]; i = p
    end
end

function hpop!(H::Vector{E}) where {E}
    n = length(H); top = H[1]; ult = H[n]; pop!(H)
    n -= 1
    n >= 1 || return top
    H[1] = ult; i = 1
    @inbounds while true
        l = 2i; r = l + 1; mn = i
        l <= n && isless(H[l], H[mn]) && (mn = l)
        r <= n && isless(H[r], H[mn]) && (mn = r)
        mn == i && break
        H[mn], H[i] = H[i], H[mn]; i = mn
    end
    return top
end

function theap_push!(tr::ObsTrack, e::TipEntrada)
    H = tr.heap; push!(H, e); i = length(H)
    @inbounds while i > 1
        p = i >> 1
        mejor_tip(H[p], H[i]) && break
        H[p], H[i] = H[i], H[p]; i = p
    end
end

function theap_top!(tr::ObsTrack)
    H = tr.heap
    @inbounds while !isempty(H)
        if tr.n_hijos[H[1].b] == 0
            return H[1].b
        end
        n = length(H); H[1] = H[n]; pop!(H); n -= 1
        n == 0 && break
        i = 1
        while true
            l = 2i; r = l + 1; mn = i
            l <= n && mejor_tip(H[l], H[mn]) && (mn = l)
            r <= n && mejor_tip(H[r], H[mn]) && (mn = r)
            mn == i && break
            H[mn], H[i] = H[i], H[mn]; i = mn
        end
    end
    return Int32(0)
end

# ------- cruce de umbral --------------------------------------------------------------
"Primer bloque de la cadena desde génesis con slot ≥ T; 0 si la punta no alcanza T."
function cruce(tr::ObsTrack, tip::Int32, T::Int)
    slots = tr.est.slots
    up = tr.up
    @inbounds slots[tip] < UInt64(T) && return Int32(0)
    cur = tip
    @inbounds for k in NLEV:-1:1
        a = up[k, cur]
        a != 0 && slots[a] >= UInt64(T) && (cur = a)
    end
    return cur
end

# ------- inserción con seguimiento ----------------------------------------------------
function insertar!(m::Mundo, tr::ObsTrack, g::Int, t::Float64, es_zl::Bool)
    est = tr.est
    pg = params_gdr(m.pr)
    loc = est.n + 1
    tr.loc[g] = Int32(loc)
    tr.g_de_loc[loc] = Int32(g)
    np = length(m.padres_g[g])
    pl = Vector{Int}(undef, np)
    @inbounds for i in 1:np
        pl[i] = Int(tr.loc[m.padres_g[g][i]])
    end
    ok = GhostdagRank.anadir!(est, pg, m.idstr[g], pl, UInt64(m.slot[g]),
                              m.sd[g], m.pr.sr, m.ident[g])
    @assert ok "anadir! falló para bloque global $g slot $(m.slot[g])"
    @inbounds for p in pl
        tr.n_hijos[p] += 1
        if tr.es_tip[p]
            tr.es_tip[p] = false
            ip = Int(tr.pos_tip[p]); lst = tr.tips; lt = lst[end]
            lst[ip] = lt; tr.pos_tip[lt] = Int32(ip); pop!(lst)
        end
    end
    tr.es_tip[loc] = true
    push!(tr.tips, Int32(loc)); tr.pos_tip[loc] = Int32(length(tr.tips))
    gd = est.gd[loc]
    theap_push!(tr, TipEntrada(gd.bw.hi, gd.bw.lo, est.sds[loc], est.ids[loc], Int32(loc)))
    @inbounds tr.up[1, loc] = Int32(gd.sp)
    @inbounds for k in 2:NLEV
        a = tr.up[k-1, loc]
        tr.up[k, loc] = a == 0 ? Int32(0) : tr.up[k-1, a]
    end
    tr.t_insert[loc] = t
    tip = theap_top!(tr)
    if tip != tr.prev_tip
        tr.prev_tip = tip
        push!(tr.t_log, t); push!(tr.tip_log, tip)
        es_zl ? actualizar_anclas_zl!(m, tip, t) : actualizar_anclas!(m, tr, tip, t)
    end
    return loc
end

function actualizar_anclas!(m::Mundo, tr::ObsTrack, tip::Int32, t::Float64)
    nj = length(m.T)
    @inbounds for j in 1:nj
        x = cruce(tr, tip, m.T[j])
        xg = x == 0 ? Int32(0) : tr.g_de_loc[x]
        xg == tr.ancla[j] && continue
        push!(tr.ev_t[j], t); push!(tr.ev_x[j], xg)
        tr.ancla[j] = xg; tr.last_change[j] = t
        t > m.last_any_change[j] && (m.last_any_change[j] = t)
        m.n_coinciden[j] = Int8(count(o -> m.obs[o].ancla[j] == m.ancla_zl[j], 1:m.pr.n_obs))
    end
end

function actualizar_anclas_zl!(m::Mundo, tip::Int32, t::Float64)
    nj = length(m.T)
    @inbounds for j in 1:nj
        x = cruce(m.zl, tip, m.T[j])
        xg = x == 0 ? Int32(0) : m.zl.g_de_loc[x]
        xg == m.ancla_zl[j] && continue
        push!(m.ev_zl_t[j], t); push!(m.ev_zl_x[j], xg)
        m.ancla_zl[j] = xg; m.last_change_zl[j] = t
        t > m.last_any_change[j] && (m.last_any_change[j] = t)
        m.n_coinciden[j] = Int8(count(o -> m.obs[o].ancla[j] == xg, 1:m.pr.n_obs))
    end
end

function parada_temprana!(m::Mundo, s::Int)
    m.permite_parada || return nothing
    @inbounds for j in 1:length(m.T)
        m.activo[j] || continue
        m.ancla_zl[j] == 0 && continue
        if m.n_coinciden[j] == m.pr.n_obs &&
           Float64(s) - m.last_any_change[j] >= m.pr.d_calma
            m.activo[j] = false
            m.stop_time[j] = s
        end
    end
end

# ------- entrega con clausura ----------------------------------------------------------
"""
recv(b) = max(llega(b), max recv(padres)); la clausura entrega ancestros a τ. Encuela en
heap_obs[o] cada bloque recién entregado con su eff corregido (el drenaje por loc==0 evita
inserciones dobles). Devuelve llega[b,o] (el eff).
"""
function entregar!(m::Mundo, o::Int, b::Int, τ::Float64)
    llega = m.llega
    llega[b, o] <= τ && return llega[b, o]
    pila = Int[]; estado = UInt8[]
    push!(pila, b); push!(estado, 0x00)
    while !isempty(pila)
        cur = pila[end]
        if estado[end] == 0x00
            estado[end] = 0x01
            @inbounds for p in m.padres_g[cur]
                if llega[p, o] > τ
                    push!(pila, Int(p)); push!(estado, 0x00)
                end
            end
        else
            mx = τ
            @inbounds for p in m.padres_g[cur]
                lp = llega[p, o]
                lp > mx && (mx = lp)
            end
            llega[cur, o] = mx
            hpush!(m.heap_obs[o], Arrival(mx, Int32(cur)))
            pop!(pila); pop!(estado)
        end
    end
    return llega[b, o]
end

# ------- selección de padres ------------------------------------------------------------
clave_tip(est, loc::Int) = TipEntrada(est.gd[loc].bw.hi, est.gd[loc].bw.lo,
                                      est.sds[loc], est.ids[loc], Int32(loc))

function padres_honestos(m::Mundo, tr::ObsTrack, s::Int, creador::Int)
    est = tr.est
    cands = copy(tr.tips)
    sort!(cands; lt=(a, b) -> mejor_tip(clave_tip(est, Int(a)), clave_tip(est, Int(b))))
    sp = Int32(0)
    for c in cands
        d = s - Int(est.slots[c])
        0 <= d <= m.pr.s_max && (sp = c; break)
    end
    sp == 0 && return Int32[]
    cands[1] != sp && (m.filt_h += 1)
    ksp = clave_tip(est, Int(sp))
    resto = Int32[]
    for c in cands
        c == sp || push!(resto, c)
    end
    # shuffle determinista por bloque (R-FIN-12; sin el shuffle, puntas quedan fuera)
    sh = StableRNGs.StableRNG(m.plan.sh_semilla ⊻ UInt64(s)*0x9E3779B97F4A7C15 ⊻
                              UInt64(creador)*0xBF58476D1CE4E5B9)
    for i in length(resto):-1:2
        j = rand(sh, 1:i)
        resto[i], resto[j] = resto[j], resto[i]
    end
    padres = Int32[sp]
    for c in resto
        length(padres) >= m.pr.max_parents && break
        kc = clave_tip(est, Int(c))
        mejor_tip(kc, ksp) && continue
        pl = [Int(p) for p in padres]; push!(pl, Int(c))
        ms = GhostdagRank.mergeset_rapido(est, Int(sp), pl)
        length(ms) + 1 <= m.pr.mergeset_limit || continue
        push!(padres, c)
    end
    # devolver GLOBALES
    return Int32[Int32(tr.g_de_loc[Int(p)]) for p in padres]
end

function padres_atacante(m::Mundo, s::Int, pol::Symbol, retro::Int)
    n = m.nblo
    prog = falses(n + 1)
    pubk = falses(n + 1)
    for g in 2:n
        p = m.pub[g]
        p < 0 && continue
        prog[g] = true
        p <= s && (pubk[g] = true)
    end
    es_tip_pub = trues(n + 1)
    for g in 2:n
        pubk[g] || continue
        for p in m.padres_g[g]
            es_tip_pub[p] = false
        end
    end
    cands = Int32[]
    if pol == :tips_pub
        for g in 2:n
            pubk[g] && es_tip_pub[g] && push!(cands, Int32(g))
        end
    else
        for g in 2:n
            prog[g] && push!(cands, Int32(g))
        end
    end
    isempty(cands) && return Int32[]
    loc(c::Int32) = Int(m.loc_atk[c])
    sort!(cands; lt=(a, b) -> mejor_tip(clave_tip(m.atk, loc(a)), clave_tip(m.atk, loc(b))))
    if pol == :sp || pol == :retro
        sp = Int32(0)
        for c in cands
            d = s - Int(m.atk.slots[loc(c)])
            0 <= d <= m.pr.s_max && (sp = c; break)
        end
        sp == 0 && return Int32[]
        if pol == :sp
            return Int32[Int32(m.g_de_atk[loc(sp)])]
        end
        ch = Int[]; cur = loc(sp)
        while cur != 0
            push!(ch, cur); cur = Int(m.atk.gd[cur].sp)
        end
        idx = max(1, length(ch) - retro)
        return Int32[Int32(m.g_de_atk[ch[idx]])]
    end
    sp = Int32(0)
    for c in cands
        d = s - Int(m.atk.slots[loc(c)])
        0 <= d <= m.pr.s_max && (sp = c; break)
    end
    sp == 0 && return Int32[]
    cands[1] != sp && (m.filt_a += 1)
    ksp = clave_tip(m.atk, loc(sp))
    padres = Int32[Int32(loc(sp))]
    for c in cands
        length(padres) >= m.pr.max_parents && break
        Int32(loc(c)) == Int32(loc(sp)) && continue
        kc = clave_tip(m.atk, loc(c))
        mejor_tip(kc, ksp) && continue
        pl = [Int(p) for p in padres]; push!(pl, Int(loc(c)))
        ms = GhostdagRank.mergeset_rapido(m.atk, Int(loc(sp)), pl)
        length(ms) + 1 <= m.pr.mergeset_limit || continue
        push!(padres, Int32(loc(c)))
    end
    return Int32[Int32(m.g_de_atk[Int(p)]) for p in padres]
end

# ------- creación ------------------------------------------------------------------------
function crear_bloque!(m::Mundo, s::Int, sdv::UInt64, idv::UInt64, quien::UInt8,
                       creador::Int8, rel::Int, plg::Vector{Int32})
    g = m.nblo + 1
    push!(m.idstr, "b" * lpad(string(g, base=16), 8, '0'))
    push!(m.padres_g, plg)
    push!(m.slot, s)
    push!(m.sd, sdv)
    push!(m.ident, idv)
    push!(m.tipo, quien)
    push!(m.creador, creador)
    push!(m.pub, rel)
    m.nblo = g
    if quien == 0x02 && rel >= 0
        @inbounds for p in plg
            pp = m.pub[p]
            @assert pp < 0 || pp <= rel "clausura violada: padre $(p) pub=$(pp) > hijo pub=$(rel)"
        end
    end
    # conocimiento del atacante: inserción inmediata (adversario del paper)
    loca = m.atk.n + 1
    m.loc_atk[g] = Int32(loca)
    m.g_de_atk[loca] = Int32(g)
    pla = [Int(m.loc_atk[p]) for p in plg]
    oka = GhostdagRank.anadir!(m.atk, params_gdr(m.pr), m.idstr[g], pla,
                               UInt64(s), sdv, m.pr.sr, idv)
    @assert oka
    return g
end

# ------- bucle principal -----------------------------------------------------------------
"Corre el mundo con el escenario; devuelve el Mundo completado."
function correr!(m::Mundo)
    pr = m.pr; plan = m.plan; esc = m.esc
    hi = 1; ai = 1
    nh = length(plan.ev_h); na = length(plan.ev_a)
    for s in 1:pr.H
        # 1. drenar llegadas de observadores con eff ≤ s
        for o in 1:pr.n_obs
            H = m.heap_obs[o]
            while !isempty(H) && H[1].t <= s
                e = hpop!(H)
                m.obs[o].loc[e.b] == 0 && insertar!(m, m.obs[o], Int(e.b), e.t, false)
            end
        end
        # 2. latencia cero
        H = m.heap_zl
        while !isempty(H) && H[1].t <= s
            e = hpop!(H)
            m.zl.loc[e.b] == 0 && insertar!(m, m.zl, Int(e.b), e.t, true)
        end
        # 3. evento honesto en s
        if hi <= nh && plan.ev_h[hi] == s
            creador = Int8(mod1(s, pr.n_obs))
            tr = (pr.Δ == 0.0) ? m.zl : m.obs[creador]
            pl = padres_honestos(m, tr, s, Int(creador))
            if isempty(pl)
                m.sin_sp_h += 1
            else
                g = crear_bloque!(m, s, plan.sd_h[hi], plan.ident_h[hi], 0x01, creador, s, pl)
                m.n_h += 1
                insertar!(m, tr, g, Float64(s), tr === m.zl)
                hpush!(m.heap_zl, Arrival(Float64(s), Int32(g)))
                if pr.Δ == 0.0
                    idx = hi
                    for o in 1:pr.n_obs
                        entregar!(m, o, g, plan.arr_h[idx, o])
                    end
                else
                    m.llega[g, creador] = Float64(s)   # el creador se ve a sí mismo al instante
                    for o in 1:pr.n_obs
                        o == creador && continue
                        entregar!(m, o, g, Float64(s + pr.Δ))
                    end
                end
            end
            hi += 1
        end
        # 4. evento atacante en s
        if ai <= na && plan.ev_a[ai] == s
            pol = esc.pol[ai]; rel = esc.rel[ai]; ret = esc.retro[ai]
            pl = padres_atacante(m, s, pol, ret)
            if isempty(pl)
                m.sin_sp_a += 1
            else
                g = crear_bloque!(m, s, plan.sd_a[ai], plan.ident_a[ai], 0x02, Int8(0), rel, pl)
                m.n_a += 1
                if rel >= 0
                    m.liberados += 1
                    hpush!(m.heap_zl, Arrival(Float64(rel), Int32(g)))
                    if esc.target == 0
                        for o in 1:pr.n_obs
                            entregar!(m, o, g, Float64(rel))
                        end
                    else
                        o = Int(esc.target)
                        entregar!(m, o, g, Float64(rel))
                    end
                else
                    m.retenidos += 1
                end
            end
            ai += 1
        end
        # 5. parada temprana
        parada_temprana!(m, s)
    end
    # drenar lo que quedó publicado/con eff ≤ H (bloques del último slot)
    for o in 1:pr.n_obs
        Hq = m.heap_obs[o]
        while !isempty(Hq) && Hq[1].t <= pr.H
            e = hpop!(Hq)
            m.obs[o].loc[e.b] == 0 && insertar!(m, m.obs[o], Int(e.b), e.t, false)
        end
    end
    while !isempty(m.heap_zl)
        e = hpop!(m.heap_zl)
        m.zl.loc[e.b] == 0 && insertar!(m, m.zl, Int(e.b), e.t, true)
    end
    return m
end

# ------- ancla definitiva (punto fijo restringido) --------------------------------------
"Primer cruce de T en la cadena del virtual sobre {slot < t} (publicado, estado zl)."
function cruce_restringido(m::Mundo, t::Int, T::Int)
    est = m.zl.est
    n = est.n
    hijo = falses(n)
    mejor = Int32(0)
    kmejor = TipEntrada(UInt128(0), UInt128(0), typemax(UInt64),
                        ntuple(_ -> 0xff, 32), Int32(0))
    @inbounds for c in 2:n
        est.slots[c] >= UInt64(t) && continue
        for p in est.padres[c]
            hijo[p] = true
        end
    end
    @inbounds for c in 2:n
        est.slots[c] >= UInt64(t) && continue
        hijo[c] && continue
        k = clave_tip(est, c)
        mejor_tip(k, kmejor) && (mejor = Int32(c); kmejor = k)
    end
    mejor == 0 && return Int32(0)
    return cruce(m.zl, mejor, T)
end

"Ancla definitiva de la época j: punto fijo t = slot(I_j)+L_def sobre {slot < t}."
function ancla_definitiva(m::Mundo, j::Int)
    T = m.T[j]; L = m.pr.L_def
    visto = Dict{Int,Int32}()
    t = T + L
    while true
        X = cruce_restringido(m, t, T)
        X == 0 && return (Int32(0), :vacio)
        Xg = m.zl.g_de_loc[X]
        t2 = Int(m.zl.est.slots[X]) + L
        t2 == t && return (Int32(Xg), :fijo)
        haskey(visto, t2) && return (Int32(0), :ciclo)
        visto[t] = Int32(X)
        t = t2
    end
end

# ------- re-evaluación completa (replay de la bitácora de puntas) -----------------------
function replay_umbral!(tr::ObsTrack, j::Int, T::Int)
    empty!(tr.ev_t[j]); empty!(tr.ev_x[j])
    ancla = Int32(0)
    nt = length(tr.t_log)
    @inbounds for i in 1:nt
        x = cruce(tr, tr.tip_log[i], T)
        xg = x == 0 ? Int32(0) : tr.g_de_loc[x]
        xg == ancla && continue
        push!(tr.ev_t[j], tr.t_log[i]); push!(tr.ev_x[j], xg)
        ancla = xg
    end
    tr.ancla[j] = ancla
    return nothing
end

# ------- W_obs ---------------------------------------------------------------------------
function ultimo_desacuerdo(evt::Vector{Float64}, evx::Vector{Int32}, T::Int,
                           D::Int32, L::Int)
    n = length(evt)
    n == 0 && return 0
    if evx[n] != D && evx[n] != 0
        return L - 1
    end
    @inbounds for k in n-1:-1:1
        if evx[k] != D && evx[k] != 0
            d = ceil(Int, evt[k+1] - T) - 1
            return clamp(d, 0, L - 1)
        end
    end
    return 0
end

function ultimo_desacuerdo_par(et1, ex1, et2, ex2, T::Int, L::Int)
    n1 = length(et1); n2 = length(et2)
    i = 1; j = 1
    a1 = Int32(0); a2 = Int32(0)
    w = 0
    while i <= n1 || j <= n2
        if j > n2 || (i <= n1 && et1[i] <= et2[j])
            te = et1[i]
            a1 != 0 && a2 != 0 && a1 != a2 && (w = max(w, clamp(ceil(Int, te - T) - 1, 0, L - 1)))
            a1 = ex1[i]; i += 1
        else
            te = et2[j]
            a1 != 0 && a2 != 0 && a1 != a2 && (w = max(w, clamp(ceil(Int, te - T) - 1, 0, L - 1)))
            a2 = ex2[j]; j += 1
        end
    end
    if a1 != 0 && a2 != 0 && a1 != a2
        w = max(w, L - 1)
    end
    return w
end

"Primer instante (slot) en que la ancla del observador existe; Inf si nunca."
function primer_ancla(evt::Vector{Float64}, evx::Vector{Int32}, T::Int)
    @inbounds for i in 1:length(evt)
        evx[i] != 0 && return evt[i]
    end
    return Inf
end

"""
Resultado por umbral de un mundo: W_obs^def, W_obs^par, W_obs, W_vacío, ancla
definitiva y bandera. Los umbrales parados se re-evalúan si el ancla definitiva o la
trayectoria zl contradicen la convergencia observada.
"""
struct ResultadoUmbral
    T::Int
    wdef::Int
    wpar::Int
    w::Int
    wvacio::Int
    D::Int32
    flag::Symbol        # :ok | :vacio | :ciclo | :reeval
end

function medir_umbral(m::Mundo, j::Int)
    T = m.T[j]; L = m.pr.L_def
    D, fflag = ancla_definitiva(m, j)
    fflag == :fijo && (fflag = :ok)
    if !m.activo[j]
        valido = (m.ancla_zl[j] == D) && m.last_change_zl[j] <= m.stop_time[j]
        if valido
            for o in 1:m.pr.n_obs
                if m.obs[o].ancla[j] != D
                    valido = false
                    break
                end
            end
        end
        if !valido
            replay_umbral!(m.zl, j, T)
            for o in 1:m.pr.n_obs
                replay_umbral!(m.obs[o], j, T)
            end
            fflag = fflag == :ok ? :reeval : fflag
        end
    end
    wdef = 0; wpar = 0
    for o in 1:m.pr.n_obs
        wdef = max(wdef, ultimo_desacuerdo(m.obs[o].ev_t[j], m.obs[o].ev_x[j], T, D, L))
    end
    for o1 in 1:m.pr.n_obs, o2 in o1+1:m.pr.n_obs
        wpar = max(wpar, ultimo_desacuerdo_par(m.obs[o1].ev_t[j], m.obs[o1].ev_x[j],
                                               m.obs[o2].ev_t[j], m.obs[o2].ev_x[j], T, L))
    end
    wvacio = 0
    for o in 1:m.pr.n_obs
        t0 = primer_ancla(m.obs[o].ev_t[j], m.obs[o].ev_x[j], T)
        d = isfinite(t0) ? clamp(ceil(Int, t0 - T) - 1, 0, L - 1) : L - 1
        wvacio = max(wvacio, d)
    end
    return ResultadoUmbral(T, wdef, wpar, max(wdef, wpar), wvacio, D, fflag)
end
