# =============================================================================
# rejilla.jl — generador de las dos ramas y rejilla declarada
#
# Vive en `src/` para que `run.jl` y `test/runtests.jl` usen EXACTAMENTE la misma
# familia de configuraciones: una comprobación de propiedad sobre una rejilla
# distinta de la publicada no comprobaría la publicación.
# =============================================================================

"Cadena de slots de `a` a `b` con paso `paso` (incluye siempre `b`)."
function cadena_slots(a::Int, b::Int, paso::Int)
    a >= b && return Int[a]
    s = collect(a:paso:b)
    s[end] != b && push!(s, b)
    return s
end

"""
    configuracion(; I, F, Smax, delta, x, paso_comun, paso_priv, paso_rama, d)

Una configuración de dos ramas dentro de la ventana de reorganización:

* `delta = s0 - T_1`: cuánto por debajo de la bifurcación cae el umbral de época.
* `x = T_1 - slot(W)`: cuánto por debajo de `T_1` bifurca la sub-rama privada retenida.
* `paso_comun`, `paso_priv`: densidad de bloques de la cadena común y de la privada. Un paso
  menor es más bloques por slot, es decir más espacio; la asimetría de `P5` hace que lo que
  decide sea la comparación dentro de `V_1`, no el paso a secas.
* `d = slot(punta) - s0`: profundidad de las dos puntas.
"""
function configuracion(; I::Int, F::Int, Smax::Int, delta::Int, x::Int,
                       paso_comun::Int, paso_priv::Int, paso_rama::Int, d::Int)
    L = max(F, Smax + 1)
    s0 = I + delta
    Wslot = I - x
    Wslot >= 1 || return nothing
    comun = cadena_slots(0, s0, paso_comun)
    idx_fork = findlast(<=(Wslot), comun)
    idx_fork === nothing && return nothing
    publica = cadena_slots(s0 + paso_rama, s0 + d, paso_rama)
    privada = vcat(cadena_slots(Wslot + paso_priv, s0, paso_priv),
                   cadena_slots(s0 + paso_rama, s0 + d, paso_rama))
    length(privada) >= 2 || return nothing
    dag, P, A, B = construir_dos_ramas(slots_comun = comun, idx_fork = idx_fork,
                                       slots_publica = publica, slots_privada = privada,
                                       I_slots = I, L = L, S_max = Smax, fusionar = :P)
    return (d = dag, P = P, A = A, B = B, L = L, I = I, F = F, Smax = Smax,
            delta = delta, x = x, paso_comun = paso_comun, paso_priv = paso_priv,
            paso_rama = paso_rama)
end

"""
    carrera_V1(cfg)

Mide, dentro de `V_1(B)`, la carrera de `blue_work` que decide el ancla (P5):

* `n_priv`: bloques PROPIOS de la rama privada dentro del corte `T_1 + L`.
* `n_com`: bloques comunes con `slot ∈ (slot(W), s0]`.

La rama privada se lleva la cadena —y con ella el ancla— si y sólo si `n_priv > n_com`
(empates: `C-GD-03`, menor `solution_distance` y luego menor id).
Devuelve `(gana, ancla_pub, ancla_priv, n_priv, n_com)`.
"""
function carrera_V1(cfg)
    d, P, A, B = cfg.d, cfg.P, cfg.A, cfg.B
    I, L = cfg.I, cfg.L
    a_pub = ancla_epoca(d, A, I, L, 30)
    a_priv = ancla_epoca(d, B, I, L, 30)
    propios = [x for x in 1:nbloques(d) if d.pasado[B][x] && !(x == P || d.pasado[P][x])]
    corte = I + L
    n_priv = count(x -> d.bloques[x].slot < corte, propios)
    Wslot = I - cfg.x
    n_com = count(x -> d.bloques[x].slot > Wslot && d.bloques[x].slot <= d.bloques[P].slot,
                  findall(d.pasado[P]))
    return a_pub != a_priv, a_pub, a_priv, n_priv, n_com
end

"Familia de rejilla declarada; `d` se fija en el borde de la ventana (`L - 1 < F`)."
function rejilla_hipotesis(; I_list = (20, 24), Smax_list = (6, 9), pasos = ((1, 1), (1, 3), (3, 1), (4, 2)),
                           deltas = (1, 2, 4, 8), xs = (1, 3, 6))
    out = []
    for I in I_list, Smax in Smax_list, F in (I, div(I, 2))
        L = max(F, Smax + 1)
        Smax >= L && continue
        for delta in unique([deltas..., L - F + 1, L]), x in xs, (pc, pp) in pasos
            (delta >= 1 && x >= 1) || continue
            x < I || continue
            Smax >= max(pc, pp) || continue
            d = L - 1
            d < F || continue
            cfg = configuracion(I = I, F = F, Smax = Smax, delta = delta, x = x,
                                paso_comun = pc, paso_priv = pp, paso_rama = min(pc, pp), d = d)
            cfg === nothing && continue
            push!(out, cfg)
        end
    end
    return out
end
