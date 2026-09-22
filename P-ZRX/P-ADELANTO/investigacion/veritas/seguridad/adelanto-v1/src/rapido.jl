"""
Kernel rápido de `AdelantoV1`: barrido de una rejilla de parámetros con salida
preasignada (`SoA`), sin asignaciones en el bucle, tipoestable y con paralelización por
**rangos disjuntos de filas** (sin reducción flotante y sin RNG: el resultado no depende
del número de hilos, que es lo que exige LINEO §7).

La operación dominante es evaluar `n` filas de ~12 funciones escalares; la representación
elegida es un `Vector{ParametrosAdelanto{Float64}}` de `struct` **inmutable e isbits** (el
kernel consume todos los campos de una fila a la vez, así que `AoS` aquí es lo correcto:
no hay un campo que se recorra sobre millones de filas) más **vectores paralelos de
salida** para no construir objetos por fila. Con `n` de decenas de miles y ~12 cuentas por
fila no se justifica `StructArrays`, `StaticArrays` ni CSR: no hay dispersión ni tamaño
fijo pequeño.
"""

"""
Evalúa la rejilla `filas` y escribe las salidas en los vectores preasignados. Devuelve el
número de filas escritas. Cada índice lo escribe **un solo** hilo.
"""
function barrer!(
    salida::Vector{ResultadoAdelanto{T}}, filas::Vector{ParametrosAdelanto{T}},
    rango::UnitRange{Int},
) where {T<:AbstractFloat}
    @inbounds for k in rango
        salida[k] = evaluar_fila(filas[k])
    end
    return length(rango)
end

"""
Barrido completo, serial. Se conserva como **referencia del barrido**: la variante con
hilos debe dar resultados **idénticos**, y el test lo comprueba.
"""
function barrer!(salida::Vector{ResultadoAdelanto{T}}, filas::Vector{ParametrosAdelanto{T}}) where {T<:AbstractFloat}
    barrer!(salida, filas, 1:length(filas))
    return salida
end

"""
Barrido con `Threads.@threads` sobre **bloques contiguos disjuntos**. No hay reducción ni
estado compartido —cada fila la escribe un solo hilo—, así que el resultado es
independiente del número de hilos (LINEO §7). El tamaño de bloque es fijo
(`bloque = 4096`) para que el troceado no dependa de `nthreads()`.
"""
function barrer_hilos!(
    salida::Vector{ResultadoAdelanto{T}}, filas::Vector{ParametrosAdelanto{T}};
    bloque::Int = 4096,
) where {T<:AbstractFloat}
    n = length(filas)
    nbloques = cld(n, bloque)
    Threads.@threads for b in 1:nbloques
        ini = (b - 1) * bloque + 1
        fin = min(b * bloque, n)
        barrer!(salida, filas, ini:fin)
    end
    return salida
end

"""
Barrido con extracción a `SoA` plana: matrices `n × k` de `Float64` y un `BitVector` para
la viabilidad. Se preasignan **una vez** y se reutilizan; no se crean temporales por fila.
"""
function barrer_soa!(destino::Matrix{T}, filas::Vector{ParametrosAdelanto{T}}) where {T<:AbstractFloat}
    n = length(filas)
    size(destino, 1) == n || throw(ArgumentError("destino debe tener $(n) filas"))
    size(destino, 2) >= 14 || throw(ArgumentError("destino necesita al menos 14 columnas"))
    @inbounds for k in 1:n
        r = evaluar_fila(filas[k])
        destino[k, 1] = r.L_slots
        destino[k, 2] = r.A_nucleo
        destino[k, 3] = r.A_D
        destino[k, 4] = r.A_frontera
        destino[k, 5] = r.A_frontera_inf
        destino[k, 6] = r.A_con_h
        destino[k, 7] = r.A_con_h_D
        destino[k, 8] = r.A_add
        destino[k, 9] = r.A_sub
        destino[k, 10] = r.rho_transitorio
        destino[k, 11] = r.rho_estrella
        destino[k, 12] = r.coste_relativo
        destino[k, 13] = r.lineas_timekeeper
        destino[k, 14] = r.nucleos_nodo
        destino[k, 15] = r.vivo ? one(T) : zero(T)
        destino[k, 16] = r.manda_F ? one(T) : zero(T)
        destino[k, 17] = T(r.w_nucleo)
    end
    return destino
end

"""
Rejilla cartesiana determinista. El orden es el de **columnas de Julia**: la última
coordenada (`rho`) varía más rápido, para que el barrido de `ρ` —el eje que el encargo
pide densificar alrededor de 1— sea el más contiguo en memoria.
"""
function rejilla(
    rhos::Vector{T}, Is::Vector{T}, Ws::Vector{T}, Ds::Vector{T}, Ss::Vector{T},
    Fs::Vector{T}, Lsuelos::Vector{T}, t_obs::T, rho_max::T, c_v::T,
) where {T<:AbstractFloat}
    n = length(rhos) * length(Is) * length(Ws) * length(Ds) * length(Ss) *
        length(Fs) * length(Lsuelos)
    filas = Vector{ParametrosAdelanto{T}}(undef, n)
    k = 0
    @inbounds for Lsuelo in Lsuelos, F in Fs, S in Ss, D in Ds, W in Ws, I in Is, rho in rhos
        k += 1
        filas[k] = ParametrosAdelanto(rho, I, W, D, S, F, Lsuelo, t_obs, rho_max, c_v)
    end
    k == n || error("la rejilla no se llenó: $k de $n")
    return filas
end
