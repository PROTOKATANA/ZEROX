# ANCLA-v0.1 — vistas de observadores y curva de discrepancia del ancla.
#
# Para cada observador honesto (nodo de la red) se construye la vista local como el
# mayor sub-DAG cerrado por padres con `llega[b,u] <= T_eval`, y se le aplica GDR-v0.2
# (`anadir!`, `virtual_sp`, `cadena_seleccionada`) para obtener su cadena seleccionada.
# La referencia es la vista causal del observador de latencia cero: todo bloque con
# `t_crea <= T_eval`.
#
# P(discrepancia)(D): posición absoluta N = H_ref − D de la cadena seleccionada; se
# compara entre observadores que alcanzaron N. Es la probabilidad de que dos
# observadores honestos asignen bloques distintos a la posición N. NO es finalidad.

"""
Construye la cadena seleccionada de un observador.
`cutoff_crea=true` ⇒ vista de latencia cero (referencia); si no, vista local de `u`.
Devuelve `(cadena, completo)`, donde `completo=false` si alguna inserción fue rechazada.
"""
function construir_vista(d::DAGGlobal, params::Params, u::Int, T_eval::Float64;
                         cutoff_crea::Bool = false)
    n = d.nblo
    incl = falses(n)
    for b in 1:n
        tmin = cutoff_crea ? d.t_crea[b] : d.llega[b, u]
        tmin <= T_eval || continue
        ok = true
        for p in d.padres[b]
            if !incl[p]
                ok = false
                break
            end
        end
        ok && (incl[b] = true)
    end
    incl[1] || return (Int[], false)
    view = findall(incl)
    loc = zeros(Int, n)
    for (i, b) in enumerate(view)
        loc[b] = i
    end
    g1 = view[1]
    est = EstadoRapido(params, d.ids[g1]; slot_g = d.slot[g1], sr_g = d.sr[g1])
    completo = true
    for b in view[2:end]
        ps = Int[loc[p] for p in d.padres[b]]
        ok = anadir!(est, params, d.ids[b], ps, d.slot[b], d.sd[b], d.sr[b], UInt64(0))
        if !ok
            completo = false
            break
        end
    end
    completo || return (Int[], false)
    tip = virtual_sp(est, params)
    c = cadena_seleccionada(est, tip)
    return (Int[view[i] for i in c], true)   # índices GLOBALES
end

"""
Medición de una réplica. Devuelve la referencia, las cadenas por observador y, para cada
profundidad D, el número de observadores que votaron y el histograma bloque→votos.
"""
function medir_replica(d::DAGGlobal, params::Params, obs::Vector{Int}, T_eval::Float64)
    cref, okref = construir_vista(d, params, 1, T_eval; cutoff_crea = true)
    okref || return nothing
    chains = Vector{Vector{Int}}(undef, 0)
    chains_ok = Int[]
    for u in obs
        c, ok = construir_vista(d, params, u, T_eval)
        if ok
            push!(chains, c)
            push!(chains_ok, u)
        end
    end
    return (chain_ref = cref, obs = chains_ok, chains = chains)
end

# --- medición transitoria: barrido temporal con estados incrementales -------

mutable struct EstadoObs
    u::Int
    est::EstadoRapido
    loc::Vector{Int}          # global -> índice local en est (0 = no añadido)
    gid::Vector{Int}          # local -> global (gid[1] = 1)
    orden::Vector{Int}        # bloques ordenados por instante de llegada
    ptr::Int                  # próximo en `orden`
    pendientes::Vector{Int}   # recibidos con padres aún ausentes
end

nuevo_EstadoObs(u::Int, params::Params, d::DAGGlobal) = begin
    est = EstadoRapido(params, d.ids[1]; slot_g = d.slot[1], sr_g = d.sr[1])
    loc = zeros(Int, d.nblo)
    loc[1] = 1
    gid = zeros(Int, d.nblo + 1)   # crece con est
    gid[1] = 1
    EstadoObs(u, est, loc, gid, Int[], 1, Int[])
end

"Traduce una cadena en índices locales a índices globales."
cadena_global(eo::EstadoObs, c::Vector{Int}) = Int[eo.gid[i] for i in c]

"""
Recorre el tiempo en cortes `paso_corte` y, en cada corte, compara la posición absoluta
N = H_ref(corte) − D de la cadena de cada observador con la de los demás. Devuelve un
`AcumuladorD` pooled sobre cortes. Captura el transitorio de puntas distintas, que la
medición al final de la corrida no ve.
"""
function medir_transitorio(d::DAGGlobal, params::Params, obs::Vector{Int}, T_eval::Float64,
                           paso_corte::Float64, Dmax::Int)
    acc = AcumuladorD()
    # referencia: vista de latencia cero, se añade en orden de creación
    est_ref = EstadoRapido(params, d.ids[1]; slot_g = d.slot[1], sr_g = d.sr[1])
    ref_sig = 2
    # observadores
    ests = Vector{EstadoObs}(undef, 0)
    for u in obs
        eo = nuevo_EstadoObs(u, params, d)
        eo.orden = [b for b in 2:d.nblo if d.llega[b, u] <= T_eval]
        sort!(eo.orden; by = b -> d.llega[b, u])
        push!(ests, eo)
    end

    t = 0.0
    while t <= T_eval
        # referencia: prefijo en orden de creación ⇒ índice local == índice global
        while ref_sig <= d.nblo && d.t_crea[ref_sig] <= t
            ps = Int[p for p in d.padres[ref_sig]]
            anadir!(est_ref, params, d.ids[ref_sig], ps, d.slot[ref_sig], d.sd[ref_sig],
                    d.sr[ref_sig], UInt64(0))
            ref_sig += 1
        end
        cref = cadena_seleccionada(est_ref, virtual_sp(est_ref, params))
        H = length(cref)
        if H > Dmax
            chains = Vector{Vector{Int}}(undef, 0)
            for eo in ests
                añadir_hasta!(eo, d, params, t)
                push!(chains, cadena_global(eo,
                      cadena_seleccionada(eo.est, virtual_sp(eo.est, params))))
            end
            for D in 0:Dmax
                N = H - D
                tot = 0
                h = Dict{Int,Int}()
                for c in chains
                    length(c) >= N || continue
                    b = c[N]
                    h[b] = get(h, b, 0) + 1
                    tot += 1
                end
                tot == 0 && continue
                p_dis = 1.0 - sum((v / tot)^2 for v in values(h))
                acc.sum_p[D] = get(acc.sum_p, D, 0.0) + p_dis * tot
                acc.total[D] = get(acc.total, D, 0) + tot
                acc.max_bloques[D] = max(get(acc.max_bloques, D, 0), length(h))
                for (b, v) in h
                    b == cref[N] && continue
                    acc.dif_ref[D] = get(acc.dif_ref, D, 0) + v
                end
            end
        end
        t += paso_corte
    end
    return acc
end

"Inserta en `eo` todos los bloques con llegada ≤ t cuyos padres ya estén presentes."
function añadir_hasta!(eo::EstadoObs, d::DAGGlobal, params::Params, t::Float64)
    progreso = true
    while progreso
        progreso = false
        i = 1
        while i <= length(eo.pendientes)
            b = eo.pendientes[i]
            if puede_añadir(eo, d, b)
                insertar!(eo, d, params, b)
                eo.pendientes[i] = eo.pendientes[end]
                pop!(eo.pendientes)
                progreso = true
            else
                i += 1
            end
        end
        while eo.ptr <= length(eo.orden) && d.llega[eo.orden[eo.ptr], eo.u] <= t
            b = eo.orden[eo.ptr]
            eo.ptr += 1
            if puede_añadir(eo, d, b)
                insertar!(eo, d, params, b)
                progreso = true
            else
                push!(eo.pendientes, b)
            end
        end
    end
    return eo
end

puede_añadir(eo::EstadoObs, d::DAGGlobal, b::Int) =
    all(p -> eo.loc[p] != 0, d.padres[b])

function insertar!(eo::EstadoObs, d::DAGGlobal, params::Params, b::Int)
    ps = Int[eo.loc[p] for p in d.padres[b]]
    ok = anadir!(eo.est, params, d.ids[b], ps, d.slot[b], d.sd[b], d.sr[b], UInt64(0))
    ok || error("anadir! rechazó el bloque $b en la vista del observador $(eo.u)")
    eo.loc[b] = eo.est.n
    eo.gid[eo.est.n] = b
    return nothing
end

"Diagnóstico: cadenas de referencia y observadores en un corte concreto."
function diagnostico_corte(d::DAGGlobal, params::Params, obs::Vector{Int}, T::Float64)
    est_ref = EstadoRapido(params, d.ids[1]; slot_g = d.slot[1], sr_g = d.sr[1])
    for b in 2:d.nblo
        d.t_crea[b] <= T || continue
        anadir!(est_ref, params, d.ids[b], Int[p for p in d.padres[b]], d.slot[b],
                d.sd[b], d.sr[b], UInt64(0))
    end
    cref = cadena_seleccionada(est_ref, virtual_sp(est_ref, params))
    ests = Vector{EstadoObs}(undef, 0)
    for u in obs
        eo = nuevo_EstadoObs(u, params, d)
        eo.orden = [b for b in 2:d.nblo if d.llega[b, u] <= T]
        sort!(eo.orden; by = b -> d.llega[b, u])
        añadir_hasta!(eo, d, params, T)
        push!(ests, eo)
    end
    chains = [cadena_global(eo, cadena_seleccionada(eo.est, virtual_sp(eo.est, params)))
              for eo in ests]
    return (cref = cref, chains = chains,
            faltantes = [length(eo.orden) - eo.est.n + 1 for eo in ests],
            pendientes = [length(eo.pendientes) for eo in ests])
end

"Diagnóstico detallado de un observador en un corte (para depurar divergencias)."
function diagnostico_detalle(d::DAGGlobal, params::Params, u::Int, T::Float64)
    est_ref = EstadoRapido(params, d.ids[1]; slot_g = d.slot[1], sr_g = d.sr[1])
    for b in 2:d.nblo
        d.t_crea[b] <= T || continue
        anadir!(est_ref, params, d.ids[b], Int[p for p in d.padres[b]], d.slot[b],
                d.sd[b], d.sr[b], UInt64(0))
    end
    eo = nuevo_EstadoObs(u, params, d)
    eo.orden = [b for b in 2:d.nblo if d.llega[b, u] <= T]
    sort!(eo.orden; by = b -> d.llega[b, u])
    añadir_hasta!(eo, d, params, T)
    return eo
end

# --- acumulador de la curva, pooled por D sobre réplicas --------------------

mutable struct AcumuladorD
    sum_p::Dict{Int,Float64}     # D => Σ_réplicas p_dis(N)·n_obs(N)
    total::Dict{Int,Int}         # D => nº de votos acumulados
    dif_ref::Dict{Int,Int}       # D => votos que difieren de la referencia
    max_bloques::Dict{Int,Int}   # D => máximo de bloques distintos vistos en una réplica
    H::Vector{Int}
end
AcumuladorD() = AcumuladorD(Dict{Int,Float64}(), Dict{Int,Int}(), Dict{Int,Int}(),
                            Dict{Int,Int}(), Int[])

function acumular!(acc::AcumuladorD, med)
    med === nothing && return acc
    cref = med.chain_ref
    H = length(cref)
    push!(acc.H, H)
    # histograma por posición absoluta N dentro de esta réplica
    porN = Dict{Int,Dict{Int,Int}}()
    for c in med.chains
        @inbounds for N in 1:min(length(c), H)
            b = c[N]
            h = get!(porN, N, Dict{Int,Int}())
            h[b] = get(h, b, 0) + 1
        end
    end
    for (N, h) in porN
        D = H - N
        tot = 0
        dif = 0
        for (b, v) in h
            tot += v
            b == cref[N] || (dif += v)
        end
        p_dis = 1.0 - sum((v / tot)^2 for v in values(h))
        acc.sum_p[D] = get(acc.sum_p, D, 0.0) + p_dis * tot
        acc.total[D] = get(acc.total, D, 0) + tot
        acc.dif_ref[D] = get(acc.dif_ref, D, 0) + dif
        acc.max_bloques[D] = max(get(acc.max_bloques, D, 0), length(h))
    end
    return acc
end

"""
Curva pooled. `p_dis(D)` promedia la probabilidad de colisión within-réplica ponderada
por el número de observadores; `p_dif_ref(D)` es la fracción de votos que no coinciden
con la vista de latencia cero.
"""
function curva_pooled(acc::AcumuladorD)
    filas = NamedTuple[]
    for D in sort!(collect(keys(acc.total)))
        tot = acc.total[D]
        tot == 0 && continue
        push!(filas, (D = D, n_votos = tot,
                      p_dis = acc.sum_p[D] / tot,
                      p_dif_ref = get(acc.dif_ref, D, 0) / tot,
                      max_bloques = get(acc.max_bloques, D, 0)))
    end
    return filas
end
