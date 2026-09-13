# rapido.jl — kernel optimizado: eventos discretos con heap binario SoA preasignado.
#
# El heap se guarda como cuatro vectores paralelos (tiempo, nodo, bloque, seq) y se
# opera con sift-up/sift-down a mano; no hay ninguna asignación en el bucle de eventos.
# La capacidad se estima por encima y sólo crece (duplicándose) si se agota, algo raro
# y amortizado. El desempate del heap es (t, v, b, seq), el mismo orden total que usa
# referencia.jl, de modo que ambos motores procesan los eventos en idéntico orden y sus
# resultados son comparables bit a bit (probado en validacion.jl).

"""
    MotorRapido

Estado de una corrida. `capacidad` entradas de heap preasignadas; `llegada` se
(re)dimensiona a `n × H` en cada corrida y se rellena con Inf.
"""
mutable struct MotorRapido
    t_heap::Vector{Float64}
    v_heap::Vector{Int32}
    b_heap::Vector{Int32}
    s_heap::Vector{Int32}
    nh::Int
    seq::Int
    next_free::Vector{Float64}
    llegada::Matrix{Float64}
end

function MotorRapido(n::Int; capacidad::Int = 64)
    capacidad = max(capacidad, 64)
    return MotorRapido(Vector{Float64}(undef, capacidad),
                       Vector{Int32}(undef, capacidad),
                       Vector{Int32}(undef, capacidad),
                       Vector{Int32}(undef, capacidad),
                       0, 0,
                       zeros(Float64, n),
                       Matrix{Float64}(undef, n, 0))
end

"""Orden total del heap: (t, v, b, seq) lexicográfico creciente."""
@inline function menor(t1::Float64, v1::Integer, b1::Integer, s1::Integer,
                       t2::Float64, v2::Integer, b2::Integer, s2::Integer)
    t1 != t2 && return t1 < t2
    v1 != v2 && return v1 < v2
    b1 != b2 && return b1 < b2
    return s1 < s2
end

@inline function intercambiar!(m::MotorRapido, i::Int, j::Int)
    @inbounds begin
        m.t_heap[i], m.t_heap[j] = m.t_heap[j], m.t_heap[i]
        m.v_heap[i], m.v_heap[j] = m.v_heap[j], m.v_heap[i]
        m.b_heap[i], m.b_heap[j] = m.b_heap[j], m.b_heap[i]
        m.s_heap[i], m.s_heap[j] = m.s_heap[j], m.s_heap[i]
    end
    return nothing
end

function crecer!(m::MotorRapido)
    c = length(m.t_heap)
    nc = c * 2
    t2 = Vector{Float64}(undef, nc); copyto!(t2, 1, m.t_heap, 1, c)
    v2 = Vector{Int32}(undef, nc); copyto!(v2, 1, m.v_heap, 1, c)
    b2 = Vector{Int32}(undef, nc); copyto!(b2, 1, m.b_heap, 1, c)
    s2 = Vector{Int32}(undef, nc); copyto!(s2, 1, m.s_heap, 1, c)
    m.t_heap = t2; m.v_heap = v2; m.b_heap = b2; m.s_heap = s2
    return nothing
end

function push_evento!(m::MotorRapido, t::Float64, v::Integer, b::Integer)
    m.seq += 1
    m.nh == length(m.t_heap) && crecer!(m)
    m.nh += 1
    i = m.nh
    @inbounds begin
        m.t_heap[i] = t; m.v_heap[i] = v; m.b_heap[i] = b; m.s_heap[i] = m.seq
        # sift-up: los índices i y p = i÷2 siempre están en 1..nh.
        while i > 1
            p = i >> 1
            menor(m.t_heap[i], m.v_heap[i], m.b_heap[i], m.s_heap[i],
                  m.t_heap[p], m.v_heap[p], m.b_heap[p], m.s_heap[p]) || break
            intercambiar!(m, i, p)
            i = p
        end
    end
    return nothing
end

function pop_evento!(m::MotorRapido)
    @inbounds begin
        t = m.t_heap[1]; v = m.v_heap[1]; b = m.b_heap[1]
        m.nh -= 1
        if m.nh > 0
            m.t_heap[1] = m.t_heap[m.nh+1]
            m.v_heap[1] = m.v_heap[m.nh+1]
            m.b_heap[1] = m.b_heap[m.nh+1]
            m.s_heap[1] = m.s_heap[m.nh+1]
            # sift-down: los hijos 2i, 2i+1 sólo se tocan si <= nh.
            i = 1
            while true
                l = i << 1
                l > m.nh && break
                c = l
                if l < m.nh &&
                   menor(m.t_heap[l+1], m.v_heap[l+1], m.b_heap[l+1], m.s_heap[l+1],
                         m.t_heap[l], m.v_heap[l], m.b_heap[l], m.s_heap[l])
                    c = l + 1
                end
                menor(m.t_heap[c], m.v_heap[c], m.b_heap[c], m.s_heap[c],
                      m.t_heap[i], m.v_heap[i], m.b_heap[i], m.s_heap[i]) || break
                intercambiar!(m, i, c)
                i = c
            end
        end
    end
    return t, v, b
end

"""
    correr!(m, red, t_creacion, creador) -> Matrix{Float64}

Corre la inundación con el kernel rápido y devuelve la matriz de llegadas
`llegada[n, H]`. Semántica idéntica a correr_referencia (ver referencia.jl).
"""
function correr!(m::MotorRapido, red::Red, t_creacion::Vector{Float64},
                 creador::AbstractVector{<:Integer})
    n = red.g.n
    H = length(t_creacion)
    if size(m.llegada, 2) != H
        m.llegada = fill(Inf, n, H)
    else
        fill!(m.llegada, Inf)
    end
    fill!(m.next_free, 0.0)
    m.nh = 0
    m.seq = 0
    @inbounds for b in 1:H
        push_evento!(m, t_creacion[b], Int(creador[b]), b)
    end
    g = red.g
    llegada = m.llegada
    next_free = m.next_free
    t_tx = red.t_tx
    t_proc = red.t_proc
    lat = red.lat
    while m.nh > 0
        t, v, b = pop_evento!(m)
        llegada[v, b] != Inf && continue
        llegada[v, b] = t
        o1 = Int(g.offsets[v]); o2 = Int(g.offsets[v+1])
        d = o2 - o1
        d == 0 && continue
        start = max(t + t_proc, next_free[v])
        next_free[v] = start + d * t_tx
        # @inbounds seguro: offsets[v+1]-1 <= offsets[n+1]-1 == length(vecinos) == length(aristas)
        @inbounds for k in 0:(d - 1)
            u = Int(g.vecinos[o1 + k])
            eid = Int(g.aristas[o1 + k])
            push_evento!(m, start + (k + 1) * t_tx + lat[eid], u, b)
        end
    end
    return llegada
end
