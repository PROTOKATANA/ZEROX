# referencia.jl — oráculo: motor de simulación de eventos discretos mínimo y legible.
#
# Diseño deliberadamente distinto del kernel rápido: los eventos viven en un Vector de
# structs y cada paso selecciona el mínimo con argmin (escaneo lineal O(k) por evento).
# Es la fuente de verdad en instancias pequeñas (n ≤ ~100), donde sus resultados se
# verifican a mano en los casos de test. No comparte estructura de datos ni bucle
# principal con rapido.jl; sólo comparte las fórmulas puras de modelo.jl, que están
# cubiertas por casos calculados a mano.

"""
    Evento

Un evento pendiente: en el instante `t` el bloque `b` llega al nodo `v` (o se crea en
él si es el evento inicial). `seq` es el número de orden de inserción: desempate
determinista y compartido con el motor rápido para que ambos motores procesen los
empates exactamente igual.
"""
struct Evento
    t::Float64
    v::Int
    b::Int
    seq::Int
end

"""
    correr_referencia(red, t_creacion, creador) -> Matrix{Float64}

Inunda todos los bloques sobre la red y devuelve `llegada[n, H]`: instante en que cada
nodo recibe cada bloque (Inf si nunca — imposible en grafo conexo).

Reglas del modelo (semántica compartida con rapido.jl):
- el creador dispone del bloque en `t_creacion`;
- cada nodo reenvía cada bloque una sola vez (al primer recibo) a TODOS sus vecinos;
- el reenvío usa una cola serial por nodo: d transmisiones consecutivas de `t_tx`
  segundos, cada una seguida de la latencia de su arista;
- un recibo duplicado no consume la cola ni vuelve a reenviar.
"""
function correr_referencia(red::Red, t_creacion::Vector{Float64},
                           creador::AbstractVector{<:Integer})
    n = red.g.n
    H = length(t_creacion)
    llegada = fill(Inf, n, H)
    next_free = zeros(Float64, n)
    eventos = Evento[]
    sizehint!(eventos, H)
    seq = 0
    @inbounds for b in 1:H
        seq += 1
        push!(eventos, Evento(t_creacion[b], Int(creador[b]), b, seq))
    end
    g = red.g
    while !isempty(eventos)
        i = findmin(e -> (e.t, e.v, e.b, e.seq), eventos)[2]
        e = eventos[i]
        deleteat!(eventos, i)
        llegada[e.v, e.b] != Inf && continue
        llegada[e.v, e.b] = e.t
        o1 = Int(g.offsets[e.v]); o2 = Int(g.offsets[e.v+1])
        d = o2 - o1
        d == 0 && continue
        start = inicio_envio(e.t, red.t_proc, next_free[e.v])
        next_free[e.v] = siguiente_libre(start, d, red.t_tx)
        @inbounds for k in 0:(d - 1)
            u = Int(g.vecinos[o1 + k])
            eid = Int(g.aristas[o1 + k])
            seq += 1
            push!(eventos, Evento(arribo_vecino(start, k, red.t_tx, red.lat[eid]), u, e.b, seq))
        end
    end
    return llegada
end
