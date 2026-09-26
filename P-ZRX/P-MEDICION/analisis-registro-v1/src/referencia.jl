# referencia.jl — oráculos pequeños, claros y lentos (LINEO §2 paso 1, §5)
#
# La vía rápida vive en `rapido.jl`. Aquí sólo hay implementaciones independientes y de coste
# O(E²) o peor, usadas para comprobar por igualdad en casos pequeños (ORDEN §4 V1) y en las
# propiedades de V3.

# ---------------------------------------------------------------------------
# Percentil nearest-rank (ORDEN §3.3). Definición exacta en enteros:
#   rango = ceil(p/100 * n) = div(p*n + 99, 100)   (p entero en 1..100, n >= 1)
# La escritura con div evita Float64 (prohibido para decidir un umbral).
# ---------------------------------------------------------------------------
"""
    percentil_ordenado_ref(v, p) -> Int64 o missing

`v` debe venir ordenado de menor a mayor. Devuelve el elemento de rango
`ceil(p/100 * n)`; `missing` si `n == 0`.
"""
function percentil_ordenado_ref(v::AbstractVector{<:Integer}, p::Integer)
    n = length(v)
    n == 0 && return missing
    (1 <= p <= 100) || throw(ArgumentError("p debe estar en 1..100, recibido $p"))
    r = div(p * n + 99, 100)
    @inbounds return Int64(v[r])
end

# ---------------------------------------------------------------------------
# Oráculo de latencias: doble bucle sobre eventos, sin diccionarios de producción.
# ---------------------------------------------------------------------------
"""
    latencias_referencia(eventos::Vector{Vector{Evento}}, nombres) -> Dict

Devuelve `(A,B) => Vector{Int64}` con una muestra por `hash` producido por A y admitido por B,
usando la producción más temprana de A y la admisión más temprana de B (ORDEN §3.4 + falta 1).
También `(A,B) => (producidos, no_admitidos)`.
"""
function latencias_referencia(eventos::Vector{Vector{Evento}}, nombres::Vector{String})
    n = length(eventos)
    lats = Dict{Tuple{Int,String},Vector{Int64}}()
    noadm = Dict{Tuple{Int,String},Int}()
    for ia in 1:n
        prod = Dict{Int32,Int64}()
        for ev in eventos[ia]
            if ev.tipo == T_BLOQUE_PRODUCIDO || ev.tipo == T_BLOQUE_MINADO
                ev.hash == 0 && continue
                old = get(prod, ev.hash, NODATO)
                if old == NODATO || ev.pared < old
                    prod[ev.hash] = ev.pared
                end
            end
        end
        for ib in 1:n
            ia == ib && continue
            adm = Dict{Int32,Int64}()
            for ev in eventos[ib]
                if ev.tipo == T_BLOQUE_RED_ADMITIDO
                    ev.hash == 0 && continue
                    old = get(adm, ev.hash, NODATO)
                    if old == NODATO || ev.pared < old
                        adm[ev.hash] = ev.pared
                    end
                end
            end
            muestras = Int64[]
            faltan = 0
            for (h, p) in prod
                if haskey(adm, h)
                    push!(muestras, adm[h] - p)
                else
                    faltan += 1
                end
            end
            sort!(muestras)
            lats[(ia, nombres[ib])] = muestras
            noadm[(ia, nombres[ib])] = faltan
        end
    end
    return lats, noadm
end

# ---------------------------------------------------------------------------
# Oráculo de divergencia: evalúa la punta de cada nodo en cada frontera escaneando sus
# eventos (O(E) por segmento, O(E²) total). No muestrea: usa exactamente las fronteras.
# ---------------------------------------------------------------------------
struct _Cambio
    pared::Int64
    reloj_ns::Int64
    linea::Int32
    nodo::Int
    punta::Int32
end

function _cambios_ordenados(eventos::Vector{Evento}, nodo::Int)
    v = _Cambio[]
    for ev in eventos
        ev.tipo == T_CAMBIO_PUNTA || continue
        push!(v, _Cambio(ev.pared, ev.reloj_ns, ev.linea, nodo, ev.punta))
    end
    sort!(v; by = c -> (c.pared, c.reloj_ns, c.linea))
    return v
end

# última punta de un nodo en el instante `t` (evento con pared <= t; empate por reloj/línea)
function _punta_en(cambios::Vector{_Cambio}, t::Int64)::Int32
    punta = Int32(0)
    for c in cambios
        c.pared <= t || break
        punta = c.punta
    end
    return punta
end

"""
    divergencia_referencia(eventos, nombres) -> (fraccion, episodios, medido)

`episodios` es `Vector{Tuple{Int64,Int64,Bool}}` = `(inicio_pared, duracion_ns, truncada)`.
Igual definición que `rapido.jl` (ORDEN §3.5 + faltas 5).
"""
function divergencia_referencia(eventos::Vector{Vector{Evento}}, nombres::Vector{String})
    n = length(eventos)
    cambios = [_cambios_ordenados(eventos[i], i) for i in 1:n]
    # fin de cada nodo = último evento de cualquier tipo
    fin = fill(NODATO, n)
    for i in 1:n
        for ev in eventos[i]
            ev.pared > fin[i] && (fin[i] = ev.pared)
        end
    end
    participan = [i for i in 1:n if !isempty(cambios[i]) && fin[i] != NODATO]
    length(participan) >= 2 || return (missing, Tuple{Int64,Int64,Bool}[], false)
    t0 = maximum(cambios[i][1].pared for i in participan)
    t1 = minimum(fin[i] for i in participan)
    t0 < t1 || return (missing, Tuple{Int64,Int64,Bool}[], false)

    # fronteras: t0 y todos los cambios con t0 < pared <= t1
    fronteras = Int64[t0]
    for i in participan, c in cambios[i]
        if t0 < c.pared <= t1
            push!(fronteras, c.pared)
        end
    end
    sort!(unique!(fronteras))
    push!(fronteras, t1)

    estado_div = false
    div_ns = Int64(0)
    ini = Int64(0)
    episodios = Tuple{Int64,Int64,Bool}[]
    for k in 1:(length(fronteras)-1)
        a = fronteras[k]
        b = fronteras[k+1]
        puntas = [_punta_en(cambios[i], a) for i in participan]
        iguales = all(==(puntas[1]), puntas)
        if iguales
            if estado_div
                push!(episodios, (ini, a - ini, false))
                estado_div = false
            end
        else
            div_ns += b - a
            if !estado_div
                ini = a
                estado_div = true
            end
        end
    end
    if estado_div
        push!(episodios, (ini, t1 - ini, true))
    end
    return (div_ns / (t1 - t0), episodios, true)
end
