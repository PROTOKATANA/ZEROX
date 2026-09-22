# ANCLA-v0.2 — validación: equivalencia kernel↔referencia en instancias pequeñas,
# bordes, invariantes y vectores de regresión. No es la suite de tests (test/runtests.jl):
# aquí viven las funciones que la suite invoca.

"World pequeño honesto para validación: Δ=2, 3 observadores, umbrales {30,...,270}."
function mundo_pequeno(replica::Int=1; α::Float64=0.0)
    pr = Params4A(α=α, Δ=2.0, via=:honesta, n_obs=3, W0=30, H=320, paso_T=30,
                  L_def=40, d_calma=40)
    plan = plan_replica(pr, replica, 0x5A5A)
    esc = esc_base(plan)
    m = Mundo(pr, plan, esc)
    correr!(m)
    return m
end

"Equivalencia total en el mundo pequeño (referencia por corte × kernel incremental)."
function validar_pequeno(m::Mundo)
    validar_heap_tips(m)
    for T in m.T
        # fuera del horizonte simulado no hay datos comparables (región del punto fijo)
        T + m.pr.L_def + 150 <= m.pr.H || continue
        validar_contra_referencia(m, T, m.pr.L_def)
        r = medir_umbral(m, idx_T(m, T))
        D2, f2 = ancla_def_ref(m, idx_T(m, T))
        f2n = f2 == :fijo ? :ok : f2
        (r.D == D2 && r.flag == f2n) ||
            error("ancla definitiva kernel≠ref: $(r.D)/$(r.flag) vs $D2/$f2")
    end
    return true
end

"""
Vector de regresión del artefacto prohibido: existe un DAG en el que el ancla sobre la
vista completa difiere del ancla restringida a {slot < t_j} (ENCARGO §3.1). Se construye
a mano con GDR directamente. Aquí: la cadena completa cruza T=10 en b3 (slot 20, linaje
B más pesado); con L=9 la restricción {slot < 19} excluye a b3 y no hay ancla.
"""
function vector_artefacto_vista_completa()
    pg = GhostdagRank.Params(k=4, max_parents=15, mergeset_limit=180, s_max=300)
    sr = UInt64(2)^50
    est = GhostdagRank.EstadoRapido(pg, "G"; slot_g=UInt64(0), sr_g=sr)
    @assert GhostdagRank.anadir!(est, pg, "b0000001", [1], UInt64(5),  UInt64(1), sr, UInt64(2))
    @assert GhostdagRank.anadir!(est, pg, "b0000002", [1], UInt64(8),  UInt64(2), sr, UInt64(3))
    @assert GhostdagRank.anadir!(est, pg, "b0000003", [3], UInt64(20), UInt64(3), sr, UInt64(4))
    @assert GhostdagRank.anadir!(est, pg, "b0000004", [4], UInt64(30), UInt64(4), sr, UInt64(5))
    T = 10
    # vista completa: punta b4 (local 5), cadena 1-3-4-5; primer slot ≥ 10 = b3 (local 4)
    tip = GhostdagRank.virtual_sp(est, pg)
    ch = GhostdagRank.cadena_seleccionada(est, tip)
    cruce_completo = 0
    for c in ch
        est.slots[c] >= UInt64(T) && (cruce_completo = c; break)
    end
    @assert cruce_completo == 4
    # restricción {slot < 19} (L=9): sub-DAG {1, b1, b2}; la mejor punta es b1 (desempate
    # sd 1 < 2); su cadena no alcanza T=10 -> SIN ancla.
    est2 = GhostdagRank.EstadoRapido(pg, "G"; slot_g=UInt64(0), sr_g=sr)
    @assert GhostdagRank.anadir!(est2, pg, "b0000001", [1], UInt64(5), UInt64(1), sr, UInt64(2))
    @assert GhostdagRank.anadir!(est2, pg, "b0000002", [1], UInt64(8), UInt64(2), sr, UInt64(3))
    tip2 = GhostdagRank.virtual_sp(est2, pg)
    ch2 = GhostdagRank.cadena_seleccionada(est2, tip2)
    cruce_restr = 0
    for c in ch2
        est2.slots[c] >= UInt64(T) && (cruce_restr = c; break)
    end
    @assert cruce_restr == 0
    @assert cruce_completo != cruce_restr
    # sanidad: con la restricción holgada (L=25, t=35) la ancla restringida = la completa
    est3 = GhostdagRank.EstadoRapido(pg, "G"; slot_g=UInt64(0), sr_g=sr)
    for b in (("b0000001", [1], UInt64(5), UInt64(1), UInt64(2)),
              ("b0000002", [1], UInt64(8), UInt64(2), UInt64(3)),
              ("b0000003", [3], UInt64(20), UInt64(3), UInt64(4)),
              ("b0000004", [4], UInt64(30), UInt64(4), UInt64(5)))
        @assert GhostdagRank.anadir!(est3, pg, b[1], b[2], b[3], b[4], sr, b[5])
    end
    tip3 = GhostdagRank.virtual_sp(est3, pg)
    ch3 = GhostdagRank.cadena_seleccionada(est3, tip3)
    @assert first(c for c in ch3 if est3.slots[c] >= UInt64(T)) == 4
    return (cruce_completo, cruce_restr)
end

"Criterio de aceptación: G debe cambiar con α (reimplementado en Julia)."
function criterio_alfa(n::Int=60, semilla::Integer=0xC0FE)
    pr0 = Params4A(α=0.0, Δ=4.0, via=:honesta, W0=300, H=900, L_def=300, d_calma=40)
    pr1 = Params4A(α=0.45, Δ=4.0, via=:a3, W0=300, H=900, L_def=300, d_calma=40)
    g0 = []; g1 = []
    for r in 1:n
        push!(g0, correr_replica(pr0, r, semilla; solo_primero=true).w)
        push!(g1, correr_replica(pr1, r, semilla; solo_primero=true).w)
    end
    m0 = sum(g0)/n; m1 = sum(g1)/n
    @assert m1 > m0 "criterio α: G(0,45) ≤ G(0): tautología"
    return (m0, m1)
end
