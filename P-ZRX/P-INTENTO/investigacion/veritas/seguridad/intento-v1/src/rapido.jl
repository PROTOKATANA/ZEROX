"""
Kernel rápido, tipoestable y sin asignaciones en el bucle.

Complejidad: O(n) en las filas del barrido, O(1) por fila, O(n) de salida. No hay RNG, no hay
grafos, no hay `Dict` en el camino caliente. Todo el estado vive en `struct` inmutables con campos
concretos y los destinos se preasignan.

Fórmulas (todas derivadas en `INFORME.md`):

```text
d(R_s)            = (2·floor(R_s/2) + 1) / 2^64
p                 = o · d(R_s)                      probabilidad por reto y por tabla
r_efectiva(w)     = 1 / (1/r + w · t_reto)          tablas/s con el coste de cruzar w retos
N_eq(w)           = r · w · τ                       piezas honestas equivalentes
bytes_eq(w)       = N_eq(w) · bytes_por_pieza
máquinas(α,N_h,w) = (α/(1−α)) · N_h / N_eq(w)
fracción(1 máquina)= N_eq(w) / (N_eq(w) + N_h)     cuota de peso de UNA máquina
coste_por_solución= (1/(r·w·p) + t_M3) / π_DAG      segundos de máquina por bloque PAGADO
                                                      (t_M3 = camino ganador SIN regenerar la
                                                       tabla: esa ya está contada en 1/(r·w·p))
w_min_latencia    = 1 / (r · τ · p)                 por debajo, no cubre ni un slot
w_equilibrio      = N_h / (r · τ)                   una máquina emula la red entera
```

`r_efectiva` NO entra en `N_eq` como factor: se publica aparte para que se vea que el descuento de
M2 es despreciable frente a M1 (se mide, no se supone).
"""

"""`d(R_s)`: fracción inclusiva del rango. `R_s` es un entero u64."""
@inline function prob_bucket(rango::T) where {T<:Real}
    return (2 * floor(rango / 2) + one(T)) / exp2(T(64))
end

"""Probabilidad de acierto por reto y por tabla."""
@inline function p_intento(o::T, rango::T) where {T<:Real}
    return o * prob_bucket(rango)
end

"""Tablas por segundo incluyendo el coste de cruzar la tabla con `w` retos."""
@inline function r_efectiva(r::T, t_reto_s::T, w::T) where {T<:Real}
    return inv(inv(r) + w * t_reto_s)
end

"""Piezas de espacio honesto equivalente que emula una máquina."""
@inline function n_eq(r::T, w::T, tau_s::T) where {T<:Real}
    return r * w * tau_s
end

"""Conversión de piezas equivalentes a bytes, con el tamaño de pieza explícito."""
@inline function bytes_equivalentes(n::T, bytes_por_pieza::Integer) where {T<:Real}
    return n * T(bytes_por_pieza)
end

"""Máquinas necesarias para una fracción `alpha` del peso de una red de `N_h` piezas."""
@inline function maquinas(alpha::T, N_h::T, r::T, w::T, tau_s::T) where {T<:Real}
    return (alpha / (one(T) - alpha)) * N_h / n_eq(r, w, tau_s)
end

"""`w` mínimo para cubrir al menos una solución por slot (restricción de latencia de caudal)."""
@inline function w_min_latencia(r::T, tau_s::T, p::T) where {T<:Real}
    return inv(r * tau_s * p)
end

"""`w` a partir del cual UNA máquina emula la red honesta entera."""
@inline function w_equilibrio(N_h::T, r::T, tau_s::T) where {T<:Real}
    return N_h / (r * tau_s)
end

"""
Segundos de máquina por bloque PAGADO.

`1/(r·w·p)` es el coste de generar las tablas hasta obtener un candidato (el intento ya incluye la
tabla). `t_ganador` es lo que se paga ADEMÁS por montar la solución del candidato, medido sin
regenerar la tabla. Se divide por `pi_DAG` porque solo esa fracción de los candidatos enviados
resulta pagada, y el atacante no sabe cuáles de antemano.
"""
@inline function coste_por_solucion(r::T, w::T, p::T, pi_DAG::T, t_ganador::T) where {T<:Real}
    return (inv(r * w * p) + t_ganador) / pi_DAG
end

"""Evalúa una fila. O(1), sin asignaciones."""
@inline function evaluar(e::Escenario{T}, w::T) where {T}
    p = p_intento(e.o, e.rango_solucion)
    ne = n_eq(e.r, w, e.tau_s)
    maq = e.N_h == zero(T) ? T(Inf) : maquinas(e.alpha, e.N_h, e.r, w, e.tau_s)
    # Fraccion del peso total que alcanza UNA sola maquina. `maquinas` ya es la inversa de esto
    # para una `alpha` dada, asi que la fraccion tiene que referirse a 1 maquina, no a `maq`.
    fraccion = e.N_h == zero(T) ? one(T) : ne / (ne + e.N_h)
    w_min = w_min_latencia(e.r, e.tau_s, p)
    return Resultado{T}(
        w,
        p,
        r_efectiva(e.r, e.t_reto_s, w),
        ne,
        bytes_equivalentes(ne, e.bytes_por_pieza),
        maq,
        fraccion,
        coste_por_solucion(e.r, w, p, e.pi_DAG, e.t_ganador_s),
        w >= w_min,
        w_min,
        w_equilibrio(e.N_h, e.r, e.tau_s),
    )
end

"""
Barrido en lote sobre una rejilla de `w` y, opcionalmente, sobre varias máquinas.

Preasigna la salida y escribe por índice: nada de `push!`. `ws` y `escs` deben tener la misma
longitud.
"""
function barrer!(salida::Vector{Resultado{T}}, escs::Vector{Escenario{T}}, ws::Vector{T}) where {T}
    length(salida) == length(escs) == length(ws) ||
        throw(ArgumentError("salida, escenarios y ws deben tener la misma longitud"))
    @inbounds for i in eachindex(salida)
        salida[i] = evaluar(escs[i], ws[i])
    end
    return salida
end

"""
Rejilla logarítmica de `w` de `w_min` a `w_max` con `pasos` puntos, ambos extremos incluidos.
Se genera con exponenciales, sin acumular multiplicaciones (evita deriva).
"""
function rejilla_w(w_min::T, w_max::T, pasos::Integer) where {T<:Real}
    pasos >= 2 || throw(ArgumentError("pasos debe ser >= 2"))
    w_min > zero(T) || throw(ArgumentError("w_min debe ser positivo"))
    w_max >= w_min || throw(ArgumentError("w_max debe ser >= w_min"))
    log_min = log(w_min)
    log_max = log(w_max)
    ws = T[exp(log_min + (log_max - log_min) * (i - 1) / (pasos - 1)) for i in 1:pasos]
    # Los extremos se fijan exactos: `exp(log(x))` no devuelve `x` bit a bit.
    ws[1] = w_min
    ws[end] = w_max
    return ws
end
