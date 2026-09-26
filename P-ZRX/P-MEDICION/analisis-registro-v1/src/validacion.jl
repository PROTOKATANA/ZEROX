# validacion.jl — equivalencia rápida vs. referencia e invariantes (LINEO §1)
#
# Las pruebas de ORDEN §4 V1 (referencia a mano) y V3 (propiedades) usan estos comparadores.

"""
    comparar_divergencia(eventos::Vector{Vector{Evento}}, nombres) -> (igual, detalle)

Comprueba que el barrido O(E log E) coincide con el oráculo O(E²) en fracción, episodios y
marcas de truncamiento.
"""
function comparar_divergencia(eventos::Vector{Vector{Evento}}, nombres::Vector{String})
    frac_r, ep_r, med_r = divergencia_referencia(eventos, nombres)
    nodos = [ResumenNodo(nombres[i], "", "", length(eventos[i]), 0, "?", eventos[i])
             for i in eachindex(eventos)]
    frac_f, ep_f, med_f = calcular_divergencia(nodos)
    igual = (med_r == med_f) && isequal(frac_r, frac_f) &&
            length(ep_r) == length(ep_f) &&
            all(ep_r[k] == (ep_f[k].inicio_pared_ns, ep_f[k].duracion_ns, ep_f[k].truncada)
                for k in eachindex(ep_r))
    detalle = "ref=($frac_r, $(length(ep_r)) eps, medida=$med_r) rápida=($frac_f, $(length(ep_f)) eps, medida=$med_f)"
    return igual, detalle
end

"""
    comparar_latencias(eventos, nombres) -> (igual, detalle)

Comprueba que la vía tipada coincide con el oráculo de doble bucle por par de nodos.
"""
function comparar_latencias(eventos::Vector{Vector{Evento}}, nombres::Vector{String})
    nodos = [ResumenNodo(nombres[i], "", "", length(eventos[i]), 0, "?", eventos[i])
             for i in eachindex(eventos)]
    filas = FilaLatencia[]
    muestras, _ = calcular_latencias(nodos, filas)
    lats_ref, noadm_ref = latencias_referencia(eventos, nombres)
    # orden determinista de pares
    pares = [(i, j) for i in eachindex(nombres) for j in eachindex(nombres) if i != j]
    ok = true
    detalle = ""
    for (i, j) in pares
        muestras_ref = sort(lats_ref[(i, nombres[j])])
        f = filas[findfirst(x -> x.nodo_a == nombres[i] && x.nodo_b == nombres[j], filas)]
        muestras_rap = Int64[]
        # reconstruye desde la referencia del rápido: no se guardan muestras; se comparan estadísticos
        n_ok = f.n == length(muestras_ref)
        p50_ok = isequal(f.p50, percentil_ordenado(muestras_ref, 50))
        p95_ok = isequal(f.p95, percentil_ordenado(muestras_ref, 95))
        max_ok = isequal(f.max, isempty(muestras_ref) ? missing : muestras_ref[end])
        nadm_ok = f.no_admitidos == noadm_ref[(i, nombres[j])]
        if !(n_ok && p50_ok && p95_ok && max_ok && nadm_ok)
            ok = false
            detalle = "difiere en $(nombres[i])->$(nombres[j])"
            break
        end
    end
    return ok, detalle
end
