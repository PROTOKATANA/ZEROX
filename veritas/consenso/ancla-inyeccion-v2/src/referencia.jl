# ANCLA-v0.2 — referencia: oráculo simple y transparente para instancias pequeñas.
# Recalcula la vista de cada observador en cada corte desde cero (estado GDR fresco por
# corte, cadena completa por punta) y el ancla por búsqueda lineal. Valida el seguimiento
# incremental del kernel (heap de puntas, saltos binarios, bitácora de eventos).

"Vista de un observador en el corte d: bloques globales con llega ≤ T+d (índices)."
function vista_en_corte(m::Mundo, o::Int, T::Int, d::Int)
    cut = T + d
    gs = Int[]
    for g in 2:m.nblo
        m.llega[g, o] <= cut && push!(gs, g)
    end
    return gs
end

"Ancla de referencia en el corte d para el observador o (global; 0 = sin ancla)."
function ancla_ref(m::Mundo, o::Int, T::Int, d::Int)
    gs = vista_en_corte(m, o, T, d)
    est = GhostdagRank.EstadoRapido(params_gdr(m.pr), "G"; slot_g=UInt64(0), sr_g=m.pr.sr)
    loc = Dict{Int,Int}(1 => 1)
    orden = sort(gs; by=g -> m.llega[g, o])
    for g in orden
        pl = [loc[Int(p)] for p in m.padres_g[g]]
        ok = GhostdagRank.anadir!(est, params_gdr(m.pr), m.idstr[g], pl,
                                  UInt64(m.slot[g]), m.sd[g], m.pr.sr, m.ident[g])
        @assert ok
        loc[g] = est.n
    end
    tip = GhostdagRank.virtual_sp(est, params_gdr(m.pr))
    tip == 0 && return 0
    ch = GhostdagRank.cadena_seleccionada(est, tip)
    for c in ch
        est.slots[c] >= UInt64(T) && return loc_inv(loc, c)
    end
    return 0
end

loc_inv(loc::Dict{Int,Int}, c::Int) = c == 1 ? 1 : first(k for (k, v) in loc if v == c)

"Ancla de referencia definitiva (punto fijo) recomputando el virtual restringido desde cero."
function ancla_def_ref(m::Mundo, j::Int)
    T = m.T[j]; L = m.pr.L_def
    est = m.zl.est
    t = T + L
    visto = Set{Int}()
    while true
        gs = Int[]
        for g in 2:m.nblo
            Int(est.slots[m.zl.loc[g]]) < t && push!(gs, g)
        end
        est2 = GhostdagRank.EstadoRapido(params_gdr(m.pr), "G"; slot_g=UInt64(0), sr_g=m.pr.sr)
        loc2 = Dict{Int,Int}(1 => 1)
        for g in sort(gs; by=x -> m.zl.t_insert[m.zl.loc[x]])
            pl = [loc2[Int(p)] for p in m.padres_g[g]]
            ok = GhostdagRank.anadir!(est2, params_gdr(m.pr), m.idstr[g], pl,
                                      UInt64(m.slot[g]), m.sd[g], m.pr.sr, m.ident[g])
            @assert ok
            loc2[g] = est2.n
        end
        tip = GhostdagRank.virtual_sp(est2, params_gdr(m.pr))
        X = 0
        if tip != 0
            ch = GhostdagRank.cadena_seleccionada(est2, tip)
            for c in ch
                est2.slots[c] >= UInt64(T) && (X = loc_inv(loc2, c); break)
            end
        end
        X == 0 && return (0, :vacio)
        t2 = m.slot[X] + L
        t2 == t && return (X, :fijo)
        t2 in visto && return (0, :ciclo)
        push!(visto, t)
        t = t2
    end
end

"Compara el seguimiento incremental con la referencia en TODOS los cortes enteros."
function validar_contra_referencia(m::Mundo, T::Int, L::Int)
    for o in 1:m.pr.n_obs
        tr = m.obs[o]
        for d in 0:L-1
            a_ref = ancla_ref(m, o, T, d)
            # ancla del kernel en el corte d: último evento con t ≤ T+d
            a_ker = Int32(0)
            evt = ev_t_por_T(tr, m, T); evx = ev_x_por_T(tr, m, T)
            for k in 1:length(evt)
                evt[k] <= T + d && (a_ker = evx[k])
            end
            a_ref == Int(a_ker) ||
                error("discrepancia referencia vs kernel: obs=$o T=$T d=$d ref=$a_ref ker=$a_ker")
        end
    end
    return true
end

"Índice del umbral T en el tracking del estado (o error si no existe)."
function idx_T(m::Mundo, T::Int)
    for (j, t) in enumerate(m.T)
        t == T && return j
    end
    error("umbral T=$T no medido")
end

"Eventos del umbral T para el estado tr."
function ev_t_por_T(tr::ObsTrack, m::Mundo, T::Int)
    return tr.ev_t[idx_T(m, T)]
end
function ev_x_por_T(tr::ObsTrack, m::Mundo, T::Int)
    return tr.ev_x[idx_T(m, T)]
end

"Comprueba que el heap de puntas del kernel coincide con virtual_sp de GDR."
function validar_heap_tips(m::Mundo)
    for tr in Iterators.flatten((m.obs, (m.zl,)))
        tip = tr.prev_tip
        if tip != 0
            v = GhostdagRank.virtual_sp(tr.est, params_gdr(m.pr))
            Int32(v) == tip || error("heap ≠ virtual_sp: $tip vs $v")
        end
    end
    return true
end
