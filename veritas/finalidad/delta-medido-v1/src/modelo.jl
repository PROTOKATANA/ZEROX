# modelo.jl — tipos, generación de red y semántica pura del modelo de propagación P2P.
#
# Este archivo define QUÉ se simula (el modelo matemático): red sintética estática,
# latencias lognormales por enlace, cola de transmisión serial por nodo, inundación
# hop-by-hop y tiempos de creación Poisson. referencia.jl y rapido.jl definen CÓMO se
# ejecuta (dos motores independientes del mismo modelo). validacion.jl prueba que
# coinciden bit a bit y que cumplen los invariantes.

"""
    GrafoCSR

Grafo simple no dirigido en formato CSR con convención de columna de Julia
(como `colptr` de CSC): los vecinos del nodo `v` son
`vecinos[offsets[v] : offsets[v+1]-1]`, con `offsets[1] = 1`.
- `aristas[k]` es el identificador (1..E) de la arista NO dirigida que cruza la entrada
  `k`; `lat[aristas[k]]` es su latencia unidireccional. Cada arista aparece dos veces
  (una por extremo), de modo que `length(vecinos) = 2E`.
"""
struct GrafoCSR
    n::Int
    offsets::Vector{Int32}
    vecinos::Vector{Int32}
    aristas::Vector{Int32}
end

grado(g::GrafoCSR, v::Int) = Int(g.offsets[v+1] - g.offsets[v])

"""
    ParametrosRed

Parámetros de una red sintética. Unidades: tiempos en segundos, `ancho_banda` en bit/s,
`tam_bloque` en bytes.

- `topologia`: `:regular` (grafo aleatorio d-regular por conmutación de aristas) o
  `:erdos_renyi` (G(n,p) con `p = grado/(n-1)`, re-muestreado hasta conectividad).
- `mediana_latencia` / `p99_latencia`: mediana y percentil 99 de la latencia
  unidireccional POR ENLACE, muestreada lognormal una vez por arista y fija durante la
  corrida (red estática).
- `retardo_procesado`: segundos por salto de verificar-y-reenviar (0 en el escenario base).
- `lambda`: tasa de creación de bloques (bloques/s, proceso Poisson homogéneo).
- `horizonte`: ventana de creación de bloques; la simulación sigue después hasta que la
  cola de eventos se vacía (ningún Δ queda censurado).
"""
struct ParametrosRed
    n::Int
    topologia::Symbol
    grado::Int
    mediana_latencia::Float64
    p99_latencia::Float64
    ancho_banda::Float64
    tam_bloque::Float64
    retardo_procesado::Float64
    lambda::Float64
    horizonte::Float64
end

"""
    Red

Instancia materializada de una red: grafo, latencia por arista (`lat`, indexada por el
id de arista del CSR), tiempo de transmisión de un bloque completo por enlace (`t_tx =
8·tam_bloque/ancho_banda`) y retardo de procesado por salto.
"""
struct Red
    g::GrafoCSR
    lat::Vector{Float64}
    t_tx::Float64
    t_proc::Float64
end

# -----------------------------------------------------------------------------
# Semántica pura de un paso de propagación (compartida por ambos motores).
# -----------------------------------------------------------------------------

"""Instante en que el nodo puede empezar a transmitir: su cola serial se libera en
`next_free` y antes debe terminar su procesado local `t_proc`."""
@inline inicio_envio(t::Float64, t_proc::Float64, next_free::Float64) = max(t + t_proc, next_free)

"""Instante de llegada al vecino `i`-ésimo (i = 0, 1, ...): la transmisión i se completa
en `start + (i+1)·t_tx` y luego recorre la latencia de la arista."""
@inline arribo_vecino(start::Float64, i::Int, t_tx::Float64, lat_arista::Float64) =
    start + (i + 1) * t_tx + lat_arista

"""Nuevo valor de `next_free` tras encolar d transmisiones seriales a partir de `start`."""
@inline siguiente_libre(start::Float64, d::Int, t_tx::Float64) = start + d * t_tx

# -----------------------------------------------------------------------------
# Generación de red
# -----------------------------------------------------------------------------

function validar_parametros(p::ParametrosRed)
    p.n >= 1 || error("n debe ser >= 1, recibido $(p.n)")
    if p.topologia === :regular
        p.grado >= 4 || error("grado regular debe ser >= 4 (el paseo de conmutación no preserva conexión en grado 2); recibido $(p.grado)")
        p.grado < p.n || error("grado debe ser < n")
        (p.n * p.grado) % 2 == 0 || error("n·grado debe ser par para un grafo d-regular")
    elseif p.topologia === :erdos_renyi
        p.grado >= 1 || error("grado esperado debe ser >= 1")
        0.0 < p.grado / (p.n - 1) < 1.0 || error("p = grado/(n-1) debe estar en (0,1)")
    else
        error("topología desconocida: $(p.topologia)")
    end
    p.mediana_latencia > 0 || error("mediana_latencia debe ser > 0")
    p.p99_latencia >= p.mediana_latencia || error("p99_latencia debe ser >= mediana_latencia")
    p.ancho_banda > 0 || error("ancho_banda debe ser > 0")
    p.tam_bloque >= 0 || error("tam_bloque debe ser >= 0")
    p.retardo_procesado >= 0 || error("retardo_procesado debe ser >= 0")
    p.lambda > 0 || error("lambda debe ser > 0")
    p.horizonte > 0 || error("horizonte debe ser > 0")
    return nothing
end

"""
    construir_red(rng, p) -> Red

Genera grafo (con re-muestreo hasta conectividad), latencias por arista y tiempos de
transmisión. Determinista dado `rng`.
"""
function construir_red(rng::AbstractRNG, p::ParametrosRed)
    validar_parametros(p)
    g = if p.topologia === :regular
        grafo_regular_por_conmutacion(rng, p.n, p.grado)
    else
        grafo_erdos_renyi(rng, p.n, p.grado / (p.n - 1))
    end
    exigir_conexo(g)
    E = length(g.vecinos) ÷ 2
    lat = generar_latencias(rng, p.mediana_latencia, p.p99_latencia, E)
    t_tx = 8.0 * p.tam_bloque / p.ancho_banda
    return Red(g, lat, t_tx, p.retardo_procesado)
end

"""Construye el CSR a partir de una lista de aristas no dirigidas `(a[k], b[k])` sin
bucles ni duplicados. Convención de columna de Julia (como `colptr` de CSC):
`offsets[1] = 1` y los vecinos del nodo v son `vecinos[offsets[v] : offsets[v+1]-1]`.
El id de arista es la posición en la lista (1..E)."""
function construir_csr(n::Int, a::Vector{Int32}, b::Vector{Int32})
    deg = zeros(Int32, n)
    @inbounds for k in eachindex(a)
        deg[a[k]] += 1
        deg[b[k]] += 1
    end
    offsets = zeros(Int32, n + 1)
    offsets[1] = 1
    @inbounds for v in 1:n
        offsets[v+1] = offsets[v] + deg[v]
    end
    m = Int(offsets[n+1] - 1)
    vecinos = Vector{Int32}(undef, m)
    aristas = Vector{Int32}(undef, m)
    cursor = zeros(Int32, n)
    @inbounds for e in eachindex(a)
        u = Int(a[e]); w = Int(b[e])
        cu = Int(offsets[u]) + cursor[u]
        cw = Int(offsets[w]) + cursor[w]
        vecinos[cu] = Int32(w); aristas[cu] = Int32(e)
        vecinos[cw] = Int32(u); aristas[cw] = Int32(e)
        cursor[u] += 1; cursor[w] += 1
    end
    return GrafoCSR(n, offsets, vecinos, aristas)
end

# --- grafo aleatorio d-regular por conmutación de aristas ---------------------

"""Codifica una arista {u,v} sin orden en un UInt64 (u,v ≤ n, sin ambigüedad)."""
@inline codigo_arista(u::Int32, v::Int32, n::Int) =
    UInt64(min(u, v)) * UInt64(n + 1) + UInt64(max(u, v))

"""Grafo d-regular de partida: ciclos de salto k = 1..d÷2 más un emparejamiento perfecto
si d es impar (n par). Como k < n/2, cada i ∈ 1..n aporta una arista distinta
`{i, mod1(i+k, n)}` (las aristas que cierran el ciclo, con i > n-k, no coinciden con
ninguna arista de otro i ni de otro k, porque k1 + k2 = n exigiría d = n)."""
function base_regular(n::Int, d::Int)
    a = Int32[]
    b = Int32[]
    @inbounds for k in 1:(d ÷ 2)
        for i in 1:n
            push!(a, Int32(i)); push!(b, Int32(mod1(i + k, n)))
        end
    end
    if d % 2 == 1
        @assert n % 2 == 0
        @inbounds for i in 1:(n ÷ 2)
            push!(a, Int32(i)); push!(b, Int32(i + n ÷ 2))
        end
    end
    return a, b
end

"""
    grafo_regular_por_conmutacion(rng, n, d)

Grafo aleatorio d-regular por el método del modelo de configuración + paseo de
conmutación de aristas (edge switching): M = 30·E conmutaciones a partir del grafo
base conectado, aceptando sólo cambios sin bucles ni aristas duplicadas. Re-muestrea
hasta conectividad. El muestreo no es exactamente uniforme; para esta medición basta
una familia d-regular bien mezclada (declarado en el INFORME).
"""
function grafo_regular_por_conmutacion(rng::AbstractRNG, n::Int, d::Int; max_intentos::Int = 100)
    @assert d >= 4 && d < n && (n * d) % 2 == 0
    for _ in 1:max_intentos
        g = conmutar(rng, n, d)
        es_conexo(g) && return g
    end
    error("grafo_regular_por_conmutacion: sin grafo conexo tras $max_intentos intentos (n=$n, d=$d)")
end

function conmutar(rng::AbstractRNG, n::Int, d::Int)
    a, b = base_regular(n, d)
    E = length(a)
    presentes = Set{UInt64}()
    sizehint!(presentes, E)
    @inbounds for k in 1:E
        push!(presentes, codigo_arista(a[k], b[k], n))
    end
    M = max(1000, 30 * E)
    for _ in 1:M
        e1 = rand(rng, 1:E)
        e2 = rand(rng, 1:E)
        e1 == e2 && continue
        x1, y1, x2, y2 = if rand(rng, Bool)
            a[e1], a[e2], b[e1], b[e2]
        else
            a[e1], b[e2], b[e1], a[e2]
        end
        (x1 == y1 || x2 == y2) && continue
        c1 = codigo_arista(x1, y1, n)
        c2 = codigo_arista(x2, y2, n)
        (c1 == c2 || c1 in presentes || c2 in presentes) && continue
        pop!(presentes, codigo_arista(a[e1], b[e1], n))
        pop!(presentes, codigo_arista(a[e2], b[e2], n))
        push!(presentes, c1); push!(presentes, c2)
        a[e1] = x1; b[e1] = y1; a[e2] = x2; b[e2] = y2
    end
    return construir_csr(n, a, b)
end

# --- G(n, p) por salto geométrico ---------------------------------------------

"""
    pareja_de_indice(k, n) -> (i, j)

Decodifica el índice lineal `k ∈ 1..n(n-1)/2` del par (i, j), 1 ≤ i < j ≤ n, con
`k = (j-2)(j-1)/2 + i`.
"""
function pareja_de_indice(k::Int, n::Int)
    # t = j-1 es el menor entero con t(t+1)/2 >= k; isqrt es exacto.
    t = (isqrt(8k + 1) - 1) ÷ 2
    (t * (t + 1)) ÷ 2 < k && (t += 1)
    j = t + 1
    i = k - (t * (t - 1)) ÷ 2
    @assert 1 <= i < j <= n
    return Int32(i), Int32(j)
end

"""
    grafo_erdos_renyi(rng, n, p)

Muestreo exacto de G(n, p) por salto geométrico sobre el índice lineal de pares:
cada par entra con probabilidad p e independiente. Re-muestrea hasta conectividad
(condicionado a grafo conexo — declarado).
"""
function grafo_erdos_renyi(rng::AbstractRNG, n::Int, p::Float64; max_intentos::Int = 1000)
    total = n * (n - 1) ÷ 2
    lnq = log1p(-p)
    for _ in 1:max_intentos
        a = Int32[]
        b = Int32[]
        sizehint!(a, min(total, 4 * ceil(Int, p * total) + 16))
        k = 0
        while true
            u = 1.0 - rand(rng)          # u ∈ (0, 1]
            gap = floor(Int, log(u) / lnq) + 1
            k += gap
            k > total && break
            i, j = pareja_de_indice(k, n)
            push!(a, i); push!(b, j)
        end
        g = construir_csr(n, a, b)
        es_conexo(g) && return g
    end
    error("grafo_erdos_renyi: sin grafo conexo tras $max_intentos intentos (n=$n, p=$p)")
end

# --- conectividad -------------------------------------------------------------

"""BFS desde el nodo 1; devuelve true si el grafo es conexo."""
function es_conexo(g::GrafoCSR)
    n = g.n
    n == 0 && return true
    visto = falses(n)
    cola = Vector{Int}(undef, n)
    cola[1] = 1; visto[1] = true
    frente = 1; fondo = 1; nv = 1
    while frente <= fondo
        v = cola[frente]; frente += 1
        # @inbounds seguro: offsets tiene n+1 entradas y offsets[n+1]-1 == length(vecinos).
        @inbounds for k in Int(g.offsets[v]):Int(g.offsets[v+1]-1)
            u = Int(g.vecinos[k])
            if !visto[u]
                visto[u] = true; nv += 1
                fondo += 1; cola[fondo] = u
            end
        end
    end
    return nv == n
end

"""Exige conectividad; si no, lanza un error con el detalle (el modelo no admite
grafo desconectado: un nodo aislado jamás recibiría el bloque)."""
function exigir_conexo(g::GrafoCSR)
    n = g.n
    visto = falses(n)
    cola = Vector{Int}(undef, n)
    cola[1] = 1; visto[1] = true
    frente = 1; fondo = 1; nv = 1
    while frente <= fondo
        v = cola[frente]; frente += 1
        @inbounds for k in Int(g.offsets[v]):Int(g.offsets[v+1]-1)
            u = Int(g.vecinos[k])
            if !visto[u]
                visto[u] = true; nv += 1
                fondo += 1; cola[fondo] = u
            end
        end
    end
    nv == n || throw(ErrorException(
        "grafo desconectado: n=$n, alcanzados desde el nodo 1: $nv"))
    return nothing
end

# --- latencias ----------------------------------------------------------------

const Z_99 = 2.3263478740408408  # cuantil 0,99 de la normal estándar Φ⁻¹(0,99)

"""Latencias unidireccionales por arista: lognormal con la mediana y el p99 pedidos,
una muestra por arista, fija durante la corrida."""
function generar_latencias(rng::AbstractRNG, mediana::Float64, p99::Float64, E::Int)
    mu = log(mediana)
    sigma = (log(p99) - mu) / Z_99
    return rand(rng, LogNormal(mu, sigma), E)
end

# --- calendario de creación ---------------------------------------------------

"""Instantes de creación de bloques: Poisson homogéneo de tasa `lambda` en [0, horizonte)."""
function calendario_poisson(rng::AbstractRNG, lambda::Float64, horizonte::Float64)
    ts = Float64[]
    t = 0.0
    while true
        t += rand(rng, Exponential(1.0 / lambda))
        t >= horizonte && break
        push!(ts, t)
    end
    return ts
end

# --- semilla derivada ---------------------------------------------------------

"""Derivación determinista de semilla por (semilla_maestra, combo, réplica) con el
finalizador splitmix64: réplicas independientes y reproducibles sin RNG compartido."""
function semilla_derivada(semilla_maestra::UInt64, combo::UInt64, replica::UInt64)
    x = semilla_maestra ⊻ combo ⊻ (replica << 17)
    x = (x ⊻ (x >> 30)) * 0xBF58476D1CE4E5B9
    x = (x ⊻ (x >> 27)) * 0x94D049BB133111EB
    return x ⊻ (x >> 31)
end

# --- métricas -----------------------------------------------------------------

"""
    deltas_por_bloque(llegada, t_creacion; qs=(50,90,99,100)) -> Matrix{Float64}

Devuelve D[b, j] = Δ_{qs[j]}(b): tiempo desde la creación del bloque b hasta que una
fracción qs[j]/100 de los nodos lo ha recibido. El rango usado es el índice
`k = ⌈q·n/100⌉` del vector de llegadas ordenado (el creador cuenta con llegada = t_creación).
"""
function deltas_por_bloque(llegada::AbstractMatrix{Float64}, t_creacion::Vector{Float64};
                           qs::Tuple = (50, 90, 99, 100))
    n, H = size(llegada)
    D = Matrix{Float64}(undef, H, length(qs))
    buffer = Vector{Float64}(undef, n)
    @inbounds for b in 1:H
        for v in 1:n
            buffer[v] = llegada[v, b]
        end
        sort!(buffer)
        for (j, q) in enumerate(qs)
            k = cld(q * n, 100)
            D[b, j] = buffer[k] - t_creacion[b]
        end
    end
    return D
end

"""Cuantil q (en porcentaje) de un vector: rango ⌈q·m/100⌉ tras ordenar una copia."""
function cuantil_pct(v::Vector{Float64}, q::Int)
    isempty(v) && return NaN
    w = sort(v)
    return w[cld(q * length(w), 100)]
end

# -----------------------------------------------------------------------------
# r2 — objetos del presupuesto Q2, utilización, medias de llegada (Q3) y
# repartos de espacio. Todo lo de aquí es NUEVO para la enmienda r2; ninguna
# función de arriba cambia.
# -----------------------------------------------------------------------------

"""Cabecera DAG según el presupuesto de Q2: 556 B base + 32 B por padre + 128 B por slot
de justificación PoT (TAREAS.md §3.1/Q2; valores de planificación, el formato no existe)."""
tam_cabecera(padres::Int, slots::Int) = 556.0 + 32.0 * padres + 128.0 * slots

"""Anuncio compacto (C-NET-07): cabecera típica (4 padres, 1 slot) + 6 B de ID corto por tx."""
tam_anuncio(tx::Int) = tam_cabecera(4, 1) + 6.0 * tx

"""Bloque completo: cabecera típica + 350 B por transacción (Modelo B350)."""
tam_bloque_completo(tx::Int) = tam_cabecera(4, 1) + 350.0 * tx

"""Utilización de la cola de reenvío de un nodo: ρ = λ·d·t_tx (TAREAS Q1/Q2)."""
utilizacion(p::ParametrosRed) = p.lambda * p.grado * (8.0 * p.tam_bloque / p.ancho_banda)

"""Etiqueta de régimen: estable si ρ<1, saturado si ρ≥1 (un saturado no publica Δ)."""
regimen(rho::Float64) = rho < 1.0 ? "estable" : "saturado"

"""Hipótesis de concentración H (sin datos reales): los k=n÷10 primeros nodos tienen el
50 % del espacio. Cuotas enteras (9, 1): k·9 = (n−k)·1, de modo que la fracción del top
es exactamente 1/2 en aritmética entera. Devuelve (cuotas, k)."""
function cuotas_concentracion(n::Int)
    n % 10 == 0 || error("hipótesis de concentración: n debe ser divisible por 10, recibido $n")
    k = n ÷ 10
    q = ones(Int, n)
    @inbounds for v in 1:k
        q[v] = 9
    end
    return q, k
end

pesos_de_cuotas(q::Vector{Int}) = Float64.(q) ./ sum(q)

"""Muestra m creadores con probabilidad proporcional a la cuota entera `q` (total = sum(q)).
Determinista dado rng: un draw `rand(rng, 1:total)` + búsqueda en la acumulada."""
function creadores_ponderados(rng::AbstractRNG, q::Vector{Int}, total::Int, m::Int)
    cum = cumsum(q)
    out = Vector{Int32}(undef, m)
    @inbounds for i in 1:m
        u = rand(rng, 1:total)
        out[i] = Int32(searchsortedfirst(cum, u))
    end
    return out
end

"""
    medias_llegada(llegada, t_creacion, creador) -> (media_bloque, media_nodo)

Medias de llegada (Q3), uniformes:
- `media_bloque[b]`: media sobre los nodos receptores (excluido el creador) de
  (llegada − creación) del bloque b;
- `media_nodo[v]`: media sobre los bloques que el nodo v no creó de (llegada − creación);
  NaN si v los creó todos.
"""
function medias_llegada(llegada::AbstractMatrix{Float64}, t_creacion::Vector{Float64},
                        creador::AbstractVector{<:Integer})
    n, H = size(llegada)
    media_bloque = Vector{Float64}(undef, H)
    media_nodo = fill(NaN, n)
    suma_nodo = zeros(Float64, n)
    cuenta_nodo = zeros(Int, n)
    @inbounds for b in 1:H
        s = 0.0
        for v in 1:n
            s += llegada[v, b]
        end
        media_bloque[b] = (s - n * t_creacion[b]) / (n - 1)
        c = Int(creador[b])
        for v in 1:n
            v == c && continue
            suma_nodo[v] += llegada[v, b] - t_creacion[b]
            cuenta_nodo[v] += 1
        end
    end
    @inbounds for v in 1:n
        cuenta_nodo[v] > 0 && (media_nodo[v] = suma_nodo[v] / cuenta_nodo[v])
    end
    return media_bloque, media_nodo
end

"""Media por bloque ponderada por espacio de los observadores (hipótesis b de Q3):
excluye al creador; pesos de los observadores según su cuota de espacio."""
function media_bloque_espacio(llegada::AbstractMatrix{Float64}, t_creacion::Vector{Float64},
                              creador::AbstractVector{<:Integer}, pesos::Vector{Float64})
    n, H = size(llegada)
    out = Vector{Float64}(undef, H)
    @inbounds for b in 1:H
        c = Int(creador[b])
        num = 0.0
        den = 0.0
        for v in 1:n
            v == c && continue
            w = pesos[v]
            num += w * (llegada[v, b] - t_creacion[b])
            den += w
        end
        out[b] = num / den
    end
    return out
end

"""Δ̄ ponderada por producción, reparto (a) uniforme: media simple de las medias por bloque
(cada bloque pesa 1/H; mismo orden de suma que `sum(media_bloque)/H`)."""
delta_barra_uniforme(media_bloque::Vector{Float64}) = sum(media_bloque) / length(media_bloque)

"""Δ̄ de la subtarea de concentración, regla (i): los creadores se sortean ∝ cuota, así que
cada bloque ya representa una unidad de producción y la Δ̄ es la media SIMPLE de las medias
por bloque ya ponderadas por observador. NUNCA combinar con peso por creador (contaría la
cuota dos veces: ∝ cuota²)."""
delta_barra_sorteo_por_cuota(media_b::Vector{Float64}) = sum(media_b) / length(media_b)

"""Δ̄ con peso por creador, regla (ii): cada bloque pesa la cuota de espacio de su creador.
Válida SOLO si los creadores se sortean de forma UNIFORME. No usar con sorteo ∝ cuota."""
function delta_barra_peso_por_creador(media_b::Vector{Float64}, creador::AbstractVector{<:Integer},
                                      pesos::Vector{Float64})
    num = 0.0
    den = 0.0
    @inbounds for (b, mb) in enumerate(media_b)
        w = pesos[creador[b]]
        num += w * mb
        den += w
    end
    return num / den
end
