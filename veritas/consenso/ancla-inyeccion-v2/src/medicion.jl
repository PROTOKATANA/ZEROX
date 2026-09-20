# ANCLA-v0.2 — medición: familias de escenarios por vía de ataque, extracción de
# W_obs/W_steer por escenario, agregación G(d) con IC por clúster de réplica,
# ajuste exponencial contrastado con r_cal y L_mín.

const GRID_REL = [0, 10, 20, 30, 45]
const PS_V2 = [0, 30, 60, 90, 120]

"Escenario base: todo el atacante publica al crearse con tips_pub (rel = slot de creación)."
function esc_base(plan::PlanReplica; pol::Symbol=:tips_pub)
    na = length(plan.ev_a)
    return Escenario("base", copy(plan.ev_a), fill(pol, na), zeros(Int, na), Int8(0))
end

"Candidatos V1: eventos atacantes con slot ∈ [T, T+d], tope `tope` por muestreo uniforme."
function candidatos_v1(plan::PlanReplica, T::Int, d::Int, tope::Int=8)
    C = Int[]
    for (i, s) in enumerate(plan.ev_a)
        T <= s <= T + d && push!(C, i)
    end
    if length(C) > tope
        paso = length(C) / tope
        C = [C[floor(Int, (k-1)*paso) + 1] for k in 1:tope]
    end
    return C
end

"Familia V1: base (candidatos [T,T+45] retenidos) + liberar cada candidato en T+d."
function escenarios_v1(plan::PlanReplica, pr::Params4A, T::Int)
    na = length(plan.ev_a)
    es = Escenario[]
    # base: candidatos de la ventana [T, T+45] retenidos para siempre
    C_max = candidatos_v1(plan, T, 45, 8)
    rel_b = copy(plan.ev_a); pol_b = fill(:tips_pub, na); ret_b = zeros(Int, na)
    for i in C_max
        rel_b[i] = -1; pol_b[i] = :tips
    end
    push!(es, Escenario("base", rel_b, pol_b, ret_b, Int8(0)))
    for d in GRID_REL
        for X in candidatos_v1(plan, T, d, 8)
            rel = copy(rel_b); pol = copy(pol_b)
            rel[X] = T + d
            push!(es, Escenario("v1-X$(X)-d$(d)", rel, pol, ret_b, Int8(0)))
        end
    end
    return es
end

"Familia V2: cadena privada desde T−P con política sp, liberada en T+d (o nunca)."
function escenarios_v2(plan::PlanReplica, pr::Params4A, T::Int)
    na = length(plan.ev_a)
    es = Escenario[]
    push!(es, esc_base(plan))
    for P in PS_V2, d in GRID_REL
        rel = copy(plan.ev_a); pol = fill(:tips_pub, na); ret = zeros(Int, na)
        for (i, s) in enumerate(plan.ev_a)
            T - P <= s <= T + d || continue
            rel[i] = T + d; pol[i] = :sp
        end
        push!(es, Escenario("v2-P$(P)-d$(d)", rel, pol, ret, Int8(0)))
    end
    # nunca soltada (retención total de la cadena)
    rel = copy(plan.ev_a); pol = fill(:tips_pub, na); ret = zeros(Int, na)
    for (i, s) in enumerate(plan.ev_a)
        T - PS_V2[end] <= s <= T + GRID_REL[end] || continue
        rel[i] = -1; pol[i] = :sp
    end
    push!(es, Escenario("v2-nunca", rel, pol, ret, Int8(0)))
    return es
end

"Familia V3: cadena privada + entrega selectiva a un solo observador."
function escenarios_v3(plan::PlanReplica, pr::Params4A, T::Int)
    na = length(plan.ev_a)
    es = Escenario[]
    push!(es, esc_base(plan))
    for P in (0, 60, 120), d in (10, 30, 45), tgt in 1:pr.n_obs
        rel = copy(plan.ev_a); pol = fill(:tips_pub, na); ret = zeros(Int, na)
        for (i, s) in enumerate(plan.ev_a)
            T - P <= s <= T + d || continue
            rel[i] = T + d; pol[i] = :sp
        end
        push!(es, Escenario("v3-P$(P)-d$(d)-t$(tgt)", rel, pol, ret, Int8(tgt)))
    end
    return es
end

"Familia A3: entrega selectiva a un solo observador (todo publicado al crearse)."
function escenarios_a3(plan::PlanReplica, pr::Params4A)
    na = length(plan.ev_a)
    es = Escenario[]
    rel = copy(plan.ev_a); pol = fill(:tips, na); ret = zeros(Int, na)
    push!(es, Escenario("a3-ambos", rel, pol, ret, Int8(0)))   # control
    for tgt in 1:pr.n_obs
        push!(es, Escenario("a3-t$(tgt)", rel, pol, ret, Int8(tgt)))
    end
    return es
end

"Familia por vía."
function escenarios(pr::Params4A, plan::PlanReplica)
    T = pr.W0
    if pr.via == :honesta || pr.via == :criterio
        return [esc_base(plan)]
    elseif pr.via == :v1
        return escenarios_v1(plan, pr, T)
    elseif pr.via == :v2
        return escenarios_v2(plan, pr, T)
    elseif pr.via == :v3
        return escenarios_v3(plan, pr, T)
    elseif pr.via == :a3
        return escenarios_a3(plan, pr)
    elseif pr.via == :ctrl9c
        return escenarios_v1(plan, pr, 200)
    else
        error("vía desconocida: $(pr.via)")
    end
end

# ------- resultado por réplica ---------------------------------------------------------
struct ResEscenario
    esc::String
    w::Int
    wdef::Int
    wpar::Int
    wvacio::Int
    D::Int32
    flag::Symbol
    nj::Int                  # nº de umbrales medidos (1 para células adversarias)
    ws::Vector{Int}          # W por umbral (si nj > 1)
    wsdef::Vector{Int}
    wspar::Vector{Int}
    wsvacio::Vector{Int}
    Ds::Vector{Int32}
    flags::Vector{Symbol}
end

"Corre un escenario y extrae el resultado (todos los umbrales, o solo el primero)."
function correr_escenario(pr::Params4A, plan::PlanReplica, esc::Escenario; solo_primero::Bool=false)
    m = Mundo(pr, plan, esc)
    correr!(m)
    if solo_primero
        r = medir_umbral(m, 1)
        return ResEscenario(esc.nombre, r.w, r.wdef, r.wpar, r.wvacio, r.D, r.flag,
                            1, [r.w], [r.wdef], [r.wpar], [r.wvacio], [r.D], [r.flag])
    end
    nj = length(m.T)
    ws = Vector{Int}(undef, nj); wsdef = Vector{Int}(undef, nj)
    wspar = Vector{Int}(undef, nj); wsvacio = Vector{Int}(undef, nj)
    Ds = Vector{Int32}(undef, nj); flags = Vector{Symbol}(undef, nj)
    wmax = 0; wdmax = 0; wpmax = 0; wvmax = 0
    for j in 1:nj
        r = medir_umbral(m, j)
        ws[j] = r.w; wsdef[j] = r.wdef; wspar[j] = r.wpar; wsvacio[j] = r.wvacio
        Ds[j] = r.D; flags[j] = r.flag
        r.w > wmax && (wmax = r.w)
        r.wdef > wdmax && (wdmax = r.wdef)
        r.wpar > wpmax && (wpmax = r.wpar)
        r.wvacio > wvmax && (wvmax = r.wvacio)
    end
    return ResEscenario(esc.nombre, wmax, wdmax, wpmax, wvmax,
                        Ds[1], flags[1], nj, ws, wsdef, wspar, wsvacio, Ds, flags)
end

struct ResReplica
    r::Int
    w::Int                    # W_obs de la réplica (máx sobre escenarios y umbrales)
    wdef::Int
    wpar::Int
    wvacio::Int
    mejor_esc::String
    n_esc::Int
    ws::Vector{Int}           # por umbral (agregado al máx sobre escenarios)
    wsdef::Vector{Int}
    wspar::Vector{Int}
    wsvacio::Vector{Int}
end

"Corre la réplica: plan + todos los escenarios; W = máx sobre escenarios."
function correr_replica(pr::Params4A, replica::Int, semilla::Integer; solo_primero::Bool=false)
    plan = plan_replica(pr, replica, semilla)
    es = escenarios(pr, plan)
    best = correr_escenario(pr, plan, es[1]; solo_primero=solo_primero)
    for e in es[2:end]
        r = correr_escenario(pr, plan, e; solo_primero=solo_primero)
        r.w > best.w && (best = r)
    end
    nj = best.nj
    if solo_primero
        return ResReplica(replica, best.w, best.wdef, best.wpar, best.wvacio,
                          best.esc, length(es), [best.w], [best.wdef], [best.wpar],
                          [best.wvacio])
    end
    # por umbral, máximo sobre escenarios
    ws = zeros(Int, nj); wsdef = zeros(Int, nj); wspar = zeros(Int, nj); wsv = zeros(Int, nj)
    for e in es
        r = correr_escenario(pr, plan, e)
        for j in 1:nj
            ws[j] = max(ws[j], r.ws[j])
            wsdef[j] = max(wsdef[j], r.wsdef[j])
            wspar[j] = max(wspar[j], r.wspar[j])
            wsv[j] = max(wsv[j], r.wsvacio[j])
        end
    end
    return ResReplica(replica, maximum(ws), maximum(wsdef), maximum(wspar), maximum(wsv),
                      best.esc, length(es), ws, wsdef, wspar, wsv)
end

# ------- agregación ---------------------------------------------------------------------
struct CurvaG
    d::Vector{Int}
    g::Vector{Float64}
    lo::Vector{Float64}
    hi::Vector{Float64}
end

"""
G(d) = P(W_obs > d) agrupada por (réplica, umbral): x_r(d) = media sobre umbrales de la
réplica; IC 95 % por bootstrap percentil de clúster de réplica (unidad = réplica).
"""
function curva_g(rs::Vector{ResReplica}, L::Int, rng; reps::Int=2000)
    R = length(rs)
    d = collect(0:L-1)
    g = zeros(Float64, L); lo = zeros(Float64, L); hi = zeros(Float64, L)
    if R == 0
        return CurvaG(d, g, lo, hi)
    end
    X = Matrix{Float64}(undef, L, R)
    fill!(X, 0.0)
    for (i, r) in enumerate(rs)
        nj = length(r.ws)
        for j in 1:nj
            w = r.ws[j]
            for dd in 1:min(w, L)     # d = dd-1; W > d
                X[dd, i] += 1.0
            end
        end
        for dd in 1:L
            X[dd, i] /= nj
        end
    end
    buf = zeros(R)
    for dd in 1:L
        g[dd] = sum(@view X[dd, :]) / R
        copyto!(buf, @view X[dd, :])
        sort!(buf)
        lo[dd] = buf[max(1, floor(Int, 0.025*R))]
        hi[dd] = buf[min(R, ceil(Int, 0.975*R))]
    end
    return CurvaG(d, g, lo, hi)
end

"""
Ajuste exponencial log G(d) ≈ a − r·d sobre la ventana [d_lo, d_hi] con pesos
√(n·G(1−G)); devuelve (r̂, a, d_lo, d_hi) o nothing si no hay puntos medibles.
"""
function ajuste_exponencial(c::CurvaG, d_lo::Int, d_hi::Int)
    xs = Float64[]; ys = Float64[]
    for i in eachindex(c.d)
        d = c.d[i]
        d_lo <= d <= d_hi || continue
        c.g[i] <= 0 && continue
        push!(xs, Float64(d)); push!(ys, log(c.g[i]))
    end
    length(xs) < 3 && return nothing
    n = length(xs)
    mx = sum(xs)/n; my = sum(ys)/n
    sxx = 0.0; sxy = 0.0
    for i in 1:n
        sxx += (xs[i]-mx)^2
        sxy += (xs[i]-mx)*(ys[i]-my)
    end
    sxx == 0 && return nothing
    r = -sxy/sxx
    a = my + r*mx
    return (r, a, minimum(xs) |> Int, maximum(xs) |> Int)
end

"Tasa calibrada del repositorio: r = (√((1−α)λ) − √(αλ))² por slot."
r_calibrado(α::Float64, λ::Float64=1.0) = (sqrt((1-α)*λ) - sqrt(α*λ))^2

"L_mín(ε): medido (primer d con G(d) ≤ ε) o estimado por el ajuste."
function l_min(c::CurvaG, ε::Float64, fit)
    for i in eachindex(c.d)
        c.g[i] <= ε && return (c.d[i], :medido)
    end
    fit === nothing && return (NaN, :inconcluso)
    r, a, _, _ = fit
    r <= 0 && return (NaN, :inconcluso)
    return (ceil(Int, (a + log(1/ε))/r), :estimado)
end

# ------- controles positivos (ronda 9c y ronda 11c) ------------------------------------

"Ancla de la vista en el corte d (global; 0 = sin ancla), del tracking incremental."
function ancla_en(tr::ObsTrack, j::Int, T::Int, d::Int)
    a = Int32(0)
    evt = tr.ev_t[j]; evx = tr.ev_x[j]
    @inbounds for k in 1:length(evt)
        evt[k] <= T + d && (a = evx[k])
    end
    return a
end

"""
Control positivo 1 (ronda 9c): menú de anclas del atacante y W_steer. Portado de
r9c_c4_wdec.py: TJ=200, HOR=1000, rejilla {0,10,20,45,80,120,150,200,300}, tope 10
candidatos, 12 semillas, S_max ∈ {150, 20}. Devuelve (w_i, w_ii, w_union, menu_i, menu_ii).
"""
const GRID_9C = [0, 10, 20, 45, 80, 120, 150, 200, 300]

function correr_replica_ctrl9c(pr::Params4A, replica::Int, semilla::Integer; TJ::Int=200)
    plan = plan_replica(pr, replica, semilla)
    na = length(plan.ev_a)
    relb = copy(plan.ev_a); polb = fill(:tips_pub, na); retb = zeros(Int, na)
    C_max = candidatos_v1(plan, TJ, 300, 10)
    for i in C_max
        relb[i] = -1; polb[i] = :tips
    end
    rbase = correr_escenario(pr, plan, Escenario("b9", relb, polb, retb, Int8(0));
                             solo_primero=true)
    menu_i = Dict{Int,Set{Int32}}()
    menu_ii = Dict{Int,Set{Int32}}()
    for d in GRID_9C
        menu_i[d] = Set{Int32}([rbase.D])
        menu_ii[d] = Set{Int32}()   # solo el par (soltada, nunca) por P — port fiel r9c
    end
    for d in GRID_9C
        for X in candidatos_v1(plan, TJ, d, 10)
            rel = copy(relb); rel[X] = TJ + d
            r = correr_escenario(pr, plan,
                Escenario("i-X$(X)-d$(d)", rel, polb, retb, Int8(0)); solo_primero=true)
            push!(menu_i[d], r.D)
        end
    end
    for d in GRID_9C, P in (0, 30, 90)
        rel = copy(plan.ev_a); pol = fill(:tips_pub, na)
        for (i, s) in enumerate(plan.ev_a)
            TJ - P <= s <= TJ + d || continue
            rel[i] = TJ + d; pol[i] = :sp
        end
        r = correr_escenario(pr, plan,
            Escenario("ii-P$(P)-d$(d)", rel, pol, retb, Int8(0)); solo_primero=true)
        rel2 = copy(plan.ev_a); pol2 = fill(:tips_pub, na)
        for (i, s) in enumerate(plan.ev_a)
            TJ - P <= s <= TJ + d || continue
            rel2[i] = -1; pol2[i] = :sp
        end
        r2 = correr_escenario(pr, plan,
            Escenario("ii-nunca-P$(P)-d$(d)", rel2, pol2, retb, Int8(0)); solo_primero=true)
        push!(menu_ii[d], r.D)
        push!(menu_ii[d], r2.D)
    end
    w_i = -1; w_ii = -1
    for d in GRID_9C
        length(menu_i[d]) >= 2 && (w_i = d)
        length(menu_ii[d]) >= 2 && (w_ii = d)
    end
    return (w_i, w_ii, max(w_i, w_ii),
            [length(menu_i[d]) for d in GRID_9C],
            [length(menu_ii[d]) for d in GRID_9C])
end

"""
Control positivo 2 (ronda 11c C.1/C.4): P(dos honestos leen I_j distinto en T_j+d) con
entrega selectiva, Δ=4 s, k=30, 12 semillas, rejilla diádica {4..256}, umbrales 100:20:300.
Devuelve por semilla (dis, den) y el nº de escenarios.
"""
const DEVS_11C = [4, 8, 16, 32, 64, 128, 256]
const SS_11C = collect(100:20:300)

function correr_replica_ctrl11c(pr::Params4A, replica::Int, semilla::Integer)
    plan = plan_replica(pr, replica, semilla)
    es = escenarios(pr, plan)
    ns = length(SS_11C); nd = length(DEVS_11C)
    mdis = zeros(Int, ns, nd); mden = zeros(Int, ns, nd)
    for e in es
        m = Mundo(pr, plan, e)
        correr!(m)
        for (si, S) in enumerate(SS_11C)
            j = 0
            for (jj, T) in enumerate(m.T)
                T == S && (j = jj)
            end
            j == 0 && continue
            for (di, d) in enumerate(DEVS_11C)
                a1 = ancla_en(m.obs[1], j, S, d)
                a2 = ancla_en(m.obs[2], j, S, d)
                if a1 != 0 && a2 != 0
                    mden[si, di] += 1
                    a1 != a2 && (mdis[si, di] += 1)
                end
            end
        end
    end
    return (mdis, mden, length(es))
end
