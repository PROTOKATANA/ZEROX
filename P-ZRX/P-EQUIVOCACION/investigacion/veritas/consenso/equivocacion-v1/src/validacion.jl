# =============================================================================
# validacion.jl — equivalencia referencia/kernel, propiedades e invariantes
# =============================================================================

"""
    comparar_anclas(d; I_slots, L, jmax, k) -> (ok, discrepancias)

Comprueba bloque a bloque y época a época que:
  * el ancla del kernel rápido («primer cruce») coincide con el oráculo
    («menor `blue_work` entre los cruces»), y
  * las dos cadenas seleccionadas de la vista coinciden.
"""
function comparar_anclas(d::Dag; I_slots::Int, L::Int, jmax::Int, k::Int)
    discrepancias = NamedTuple[]
    n = nbloques(d)
    for b in 1:n
        for j in 1:jmax
            T = j * I_slots
            a_fast = ancla_epoca(d, b, T, L, k)
            v = seleccion_vista(d, vista_epoca(d, b, T, L), k)
            cad_fast = cadena_vista(d, v)
            a_ref, cad_ref = ancla_ref(d, b, T, L, k)
            if a_fast != a_ref || cad_fast != cad_ref
                push!(discrepancias, (bloque = b, epoca = j, rapido = a_fast, referencia = a_ref,
                                      cadena_igual = cad_fast == cad_ref))
            end
        end
    end
    return isempty(discrepancias), discrepancias
end

"""
    comparar_flujos(d; I_slots, L, jmax, k, slots) -> Bool

Compara el flujo del kernel (prefijo precalculado) con el oráculo (recalculado
entero por slot) en cada bloque y cada slot pedido.
"""
function comparar_flujos(d::Dag; I_slots::Int, L::Int, jmax::Int, k::Int, slots::Vector{Int})
    ok = true
    for b in 1:nbloques(d)
        inj = inyecciones(d, b, I_slots, L, jmax, k)
        for s in slots
            if collect(flujo_slot(inj, s)) != flujo_ref(d, b, s, I_slots, L, jmax, k)
                ok = false
            end
        end
    end
    return ok
end

"""
    propiedad_P1(d; I_slots, L, jmax, k) -> (ok, detalle)

Comprueba P1: para todo bloque y toda época con ancla, `T_j ≤ slot(I_j) < T_j + S_max_slots`.
`S_max_slots` se pasa aparte porque es una entrada del modelo.
"""
function propiedad_P1(d::Dag; I_slots::Int, L::Int, jmax::Int, k::Int, S_max::Int)
    ok = true
    detalle = NamedTuple[]
    for b in 1:nbloques(d), j in 1:jmax
        T = j * I_slots
        a = ancla_epoca(d, b, T, L, k)
        a == 0 && continue
        s = d.bloques[a].slot
        if !(T <= s < T + S_max)
            ok = false
            push!(detalle, (bloque = b, epoca = j, ancla = a, slot = s, T = T, S_max = S_max))
        end
    end
    return ok, detalle
end

"""
    propiedad_P2(d, s0; I_slots, L, jmax, k) -> (ok, detalle)

Comprueba, sobre TODOS los bloques del DAG, la primera mitad de la hipótesis del
validador (teorema P3): si la inyección `j` está activa en un slot `s >= s0` con
`s - s0 < F_slots`, entonces `slot(I_j) < s0`. Es una comprobación de la
demostración, no su sustituto.
"""
function propiedad_P2(d::Dag, s0::Int; I_slots::Int, L::Int, F_slots::Int, jmax::Int, k::Int)
    ok = true
    detalle = NamedTuple[]
    for b in 1:nbloques(d)
        for j in 1:jmax
            a = ancla_epoca(d, b, j * I_slots, L, k)
            a == 0 && continue
            t = d.bloques[a].slot + L
            s = max(t, s0)
            (s < s0 + F_slots) || continue      # hay algún slot de la ventana con j activa
            if !(d.bloques[a].slot < s0)
                ok = false
                push!(detalle, (bloque = b, epoca = j, ancla = a, slot_ancla = d.bloques[a].slot,
                                t_j = t, s0 = s0))
            end
        end
    end
    return ok, detalle
end

"Generador seudaleatorio reproducible de DAGs pequeños para el contraste."
function dag_aleatorio(rng; n::Int, I_slots::Int, kmax_padres::Int = 3, sv::Int = 1)
    d = Dag()
    id = agregar!(d, 0, Int[], 1; dist = 0, sr = sv)
    for b in 2:n
        k = rand(rng, 1:kmax_padres)
        cand = collect(1:(b - 1))
        shuffle!(rng, cand)
        padres = sort(cand[1:min(k, length(cand))])
        slotmax = maximum(d.bloques[p].slot for p in padres)
        slot = slotmax + rand(rng, 0:3)
        agregar!(d, slot, padres, b; dist = rand(rng, 0:5), sr = sv)
    end
    return d
end

"""
    contraste_aleatorio(rng, ncasos; n, I_slots, L, jmax, k) -> (ok, primer_fallo)

Contraste referencia/kernel sobre `ncasos` DAGs aleatorios reproducibles.
"""
function contraste_aleatorio(rng, ncasos::Int; n::Int = 12, I_slots::Int = 4, L::Int = 8,
                            jmax::Int = 3, k::Int = 3)
    for caso in 1:ncasos
        d = dag_aleatorio(rng; n = n, I_slots = I_slots)
        ok, disc = comparar_anclas(d; I_slots = I_slots, L = L, jmax = jmax, k = k)
        ok || return false, (caso = caso, disc = disc)
        slots = sort(unique([d.bloques[i].slot for i in 1:nbloques(d)]))
        comparar_flujos(d; I_slots = I_slots, L = L, jmax = jmax, k = k, slots = slots) ||
            return false, (caso = caso, motivo = "flujo")
    end
    return true, nothing
end
