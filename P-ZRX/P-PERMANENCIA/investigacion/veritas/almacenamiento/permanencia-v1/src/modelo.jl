# modelo.jl — símbolos, funciones puras y costes de los esquemas E1–E5.
#
# REGLA DEL ENCARGO: ningún parámetro de consenso ni de red se fija aquí. Todo símbolo
# (N, w, D_a, c, q, P, a, s, σ, λ_red…) entra por CLI o se lee de `mediciones/hardware.tsv`,
# que solo contiene CIFRAS DE HARDWARE MEDIDAS por otros encargos y su fuente.

"""
Medidas de hardware leídas de `mediciones/hardware.tsv`. NINGUNA es una decisión de consenso:
son entradas medidas, con su fuente y su etiqueta. `bytes_pieza` es `Piece::SIZE` del código
fijado, no una medición.
"""
struct Hardware
    t_tabla_s::Float64                 # generar una tabla (una pieza), 1 núcleo
    t_tabla_paralela_s::Float64        # generate_parallel, 24 hilos
    r_cpu_tablas_s::Float64            # mejor agregado medido (16 núcleos físicos)
    t_reto_s::Float64                  # cruzar una tabla con un reto (bucket aislado)
    t_reto_lote_s::Float64             # cruzar con w retos en lote (independiente de w)
    t_ganador_s::Float64               # camino que solo paga el intento ganador
    m_tabla_B::Int64                   # memoria viva por tabla
    bytes_pieza_B::Int64               # Piece::SIZE
    bytes_mapa_presencia_B::Int64      # `found_proofs` de Proofs<20>
    num_pruebas_por_pieza::Int64       # = NUM_CHUNKS
    num_s_buckets::Int64               # = NUM_S_BUCKETS
    o_medido::Float64                  # densidad media de bucket ocupado
    ploteo_sector_1000_piezas_s::Float64
    w_sin_vdf_slots::Float64           # L
    w_con_vdf_rho25_slots::Float64     # (L+I)(1-1/ρ) a ρ=2,5
    fuente::String
end

const TAU_S = 1.0            # SLOT_DURATION = 1000 ms, código fijado (entrada documentada)
const BYTES_POR_TiB = 2.0^40

"""Piezas que caben en un TiB con el tamaño de pieza del formato fijado."""
piezas_por_TiB(hw::Hardware) = BYTES_POR_TiB / hw.bytes_pieza_B

"""TiB que representan `N` piezas."""
TiB_de_piezas(hw::Hardware, N::Real) = N * hw.bytes_pieza_B / BYTES_POR_TiB

"""Tablas por segundo que rinde una máquina de `r` tablas/s durante `t` segundos."""
tablas_en(hw::Hardware, r::Real, t::Real) = r * t

# ---------------------------------------------------------------------------
# E2 · aperturas aleatorias con plazo
# ---------------------------------------------------------------------------

"""CPU (16 núcleos) necesarias para regenerar `(1-s)·c` piezas dentro de `D_a`."""
e2_cpu_sin_ventana(hw::Hardware, c::Real, D_a::Real, s::Real) =
    (1 - s) * c / (hw.r_cpu_tablas_s * D_a)

"""CPU (16 núcleos) necesarias si el tramposo conoce los `c` retos `w` slots antes."""
e2_cpu_con_ventana(hw::Hardware, c::Real, w::Real, s::Real) =
    (1 - s) * c / (hw.r_cpu_tablas_s * w)

"""¿Cabe la regeneración en el plazo, sin ventana?"""
e2_factible_sin_ventana(hw::Hardware, c::Real, D_a::Real, s::Real) =
    (1 - s) * c <= hw.r_cpu_tablas_s * D_a

"""¿Cabe la regeneración en la ventana?"""
e2_factible_con_ventana(hw::Hardware, c::Real, w::Real, s::Real) =
    (1 - s) * c <= hw.r_cpu_tablas_s * w

"""Número máximo de aperturas que un honesto puede servir en `D_a` a `t_lectura` s por apertura."""
e2_aperturas_honestas(D_a::Real, t_lectura::Real) = D_a / t_lectura

"""
Bytes en cadena por auditoría. `b_apertura` = bytes de una apertura (testigo KZG + chunk),
`b_compromiso` = bytes por posición comprometida. Dos políticas:
- todas: se publican las `c` aperturas;
- muestreo: se compromete el conjunto (`c` compromisos) y se abren `k` al azar.
"""
e2_bytes_todas(c::Real, b_apertura::Real) = c * b_apertura
e2_bytes_muestreo(c::Real, k::Real, b_compromiso::Real, b_apertura::Real) =
    c * b_compromiso + k * b_apertura

"""Probabilidad de que `k` aperturas al azar no alcancen a cubrir la fracción que no se guarda."""
# Se calcula con la referencia exacta (binomial); aquí solo la definición.

# ---------------------------------------------------------------------------
# E3 · pruebas parciales
# ---------------------------------------------------------------------------

"""
Coste de regeneración de un lote de `N` piezas, en CPU de `r` tablas/s.
Con `w` slots de adelanto, el tramposo regenera el lote **una vez por ventana** y reparte las
parciales de los `w` slots: la tasa es `N/w` tablas/s, continua e **independiente de `P`**
(`P` solo cambia cuántas parciales se guardan en el búfer). CPUs = `N/(r·w·τ)`.
"""
function e3_cpu_regeneracion(hw::Hardware, N::Real, w::Real, P::Real)
    w <= 0 && return Inf
    return N / (hw.r_cpu_tablas_s * w * TAU_S)
end

"""Piezas que una CPU puede fabricar por ventana: r·w (tope)."""
e3_piezas_fabricables(hw::Hardware, w::Real) = hw.r_cpu_tablas_s * w * TAU_S

"""
Fracción del lote que el tramposo PUEDE no almacenar con una CPU: min(1, r·w/N).
Su almacenamiento forzado es `max(0, 1 - r·w/N)`.
"""
e3_fraccion_fabricable(hw::Hardware, N::Real, w::Real) = min(1.0, e3_piezas_fabricables(hw, w) / N)

"""Almacenamiento forzado por el test, como fracción del lote."""
e3_almacenamiento_forzado(hw::Hardware, N::Real, w::Real) =
    1 - e3_fraccion_fabricable(hw, N, w)

"""`w` a partir del cual UNA CPU fabrica el lote entero."""
e3_w_cruce_lote(hw::Hardware, N::Real) = N / (hw.r_cpu_tablas_s * TAU_S)

"""`w` a partir del cual UNA CPU iguala un disco de `TiB_disco` TiB."""
e3_w_cruce_disco(hw::Hardware, TiB_disco::Real) =
    (TiB_disco * piezas_por_TiB(hw)) / (hw.r_cpu_tablas_s * TAU_S)

"""CPU necesarias para fabricar `TiB` de lote con ventana `w`."""
e3_cpu_por_TiB(hw::Hardware, w::Real) = piezas_por_TiB(hw) / (hw.r_cpu_tablas_s * w * TAU_S)

"""TiB que fabrica UNA CPU con ventana `w`."""
e3_TiB_por_cpu(hw::Hardware, w::Real) =
    e3_piezas_fabricables(hw, w) * hw.bytes_pieza_B / BYTES_POR_TiB

"""Media esperada de parciales por periodo para un lote de `N` piezas."""
e3_lambda(N::Real, q::Real, P::Real) = N * q * P

# ---- Agregación en cadena -------------------------------------------------

"""
Con `λ` parciales comprometidas por periodo y una política «comprometer el conjunto y abrir `k`
al azar», un tramposo que solo tiene `m` parciales reales pasa si las `k` posiciones abiertas
caen todas dentro de sus `m`: `C(m,k)/C(λ,k) ≈ (m/λ)^k`.
"""
e3_pasa_muestreo(lambda::Real, m::Real, k::Real) =
    lambda <= 0 ? 1.0 : (min(m, lambda) / lambda)^k

"""
Fracción mínima `m/λ` de parciales reales que hace falta para pasar con probabilidad `1-γ`:
`(1-γ)^(1/k)`. Casi 1 incluso para `k=1`: el muestreo NO abarata el compromiso si las
posiciones se eligen después y no se pueden anticipar.
"""
e3_mezcla_necesaria(k::Real, gamma::Real) = (1 - gamma)^(1 / k)

"""Piezas que hay que escanear (o almacenar) para tener esa fracción de parciales reales."""
e3_piezas_escaneadas(N::Real, k::Real, gamma::Real) = N * e3_mezcla_necesaria(k, gamma)

"""Intentos de grinding para colocar `k` aperturas dentro de `m` parciales de `λ` (Fiat-Shamir)."""
e3_grinding(lambda::Real, m::Real, k::Real) =
    (lambda <= 0 || m <= 0) ? Inf : (lambda / min(m, lambda))^k

"""
Si el tramposo CONOCE `w` slots antes qué `k` posiciones se abren (el reto sale del PoT, que es
público), solo regenera esas `k` piezas: `k` tablas por envío, independiente de `N`. CPU
continuas = `k·ceil(P/w)/(r·P)`.
"""
function e3_cpu_agregacion_con_ventana(hw::Hardware, k::Real, P::Real, w::Real)
    w <= 0 && return Inf
    regen = max(1.0, ceil(P / w))
    return k * regen / (hw.r_cpu_tablas_s * P)
end

"""Bytes en cadena por lote y periodo si van TODAS las parciales."""
e3_bytes_cadena(lambda::Real, b_parcial::Real) = lambda * b_parcial

# ---------------------------------------------------------------------------
# E4 · sellado secuencial
# ---------------------------------------------------------------------------

"""Trabajo de regeneración de un lote, en segundos de núcleo (N tablas)."""
e4_trabajo_nucleo_s(hw::Hardware, N::Real) = N * hw.t_tabla_s

"""Duración mínima que tendría que durar un sellado por sector para superar la ventana `w`."""
e4_sellado_minimo_slots(w::Real) = w

# ---------------------------------------------------------------------------
# E5 · farmear y nada más
# ---------------------------------------------------------------------------

"""Frecuencia de soluciones/slot de un granjero con fracción `sigma` de la red."""
e5_lambda_granjero(sigma::Real, lambda_red::Real) = sigma * lambda_red

"""
Slots hasta detectar con confianza `1-β` que una parcela ya no responde, por su propia
ausencia de victorias: P(0 victorias en T slots) = exp(-σ·λ·T).
"""
e5_deteccion_slots(sigma::Real, lambda_red::Real, beta::Real) =
    -log(beta) / (sigma * lambda_red)

"""Probabilidad de que un granjero honesto con `sigma` no gane en `T` slots (falso positivo)."""
e5_p_cero(sigma::Real, lambda_red::Real, T::Real) = exp(-e5_lambda_granjero(sigma, lambda_red) * T)

# ---------------------------------------------------------------------------
# Retención (F4), en periodos de auditoría, nunca en moneda
# ---------------------------------------------------------------------------

"""
Periodos de retención necesarios por *tiempo*: la ventana de evidencia es del orden de la
finalidad `F` (en slots) y la detección del esquema tarda `T_det` periodos. No incluye el
importe: `ρ_ret` es una entrada monetaria que el instrumento NO fija.
"""
retencion_periodos(F_slots::Real, P::Real, T_det::Real) = F_slots / P + T_det

# ---------------------------------------------------------------------------
# Lectura de las medidas de hardware
# ---------------------------------------------------------------------------

"""
Lee `mediciones/hardware.tsv`. Si falta una clave, **falla**: el instrumento no inventa
ninguna cifra de hardware. Devuelve `(Hardware, Dict de metadatos)`.
"""
function lectura_hardware(ruta::AbstractString)
    isfile(ruta) || error("no existe el fichero de medidas de hardware: $ruta")
    valores = Dict{String,Float64}()
    fuente = ""
    for linea in eachline(ruta)
        s = strip(linea)
        (isempty(s) || startswith(s, "#")) && continue
        partes = split(s, '\t')
        length(partes) >= 5 || error("línea de medidas mal formada: $linea")
        clave = String(strip(partes[1]))
        clave == "clave" && continue
        valores[clave] = parse(Float64, strip(partes[2]))
        if isempty(fuente) && length(partes) >= 4
            fuente = String(strip(partes[4]))
        end
    end
    exigidas = ("t_tabla_s", "t_tabla_paralela_s", "r_cpu_tablas_s", "t_reto_s", "t_reto_lote_s",
        "t_ganador_s", "m_tabla_B", "bytes_pieza_B", "bytes_mapa_presencia_B",
        "num_pruebas_por_pieza", "num_s_buckets", "o_medido", "ploteo_sector_1000_piezas_s",
        "w_sin_vdf_slots", "w_con_vdf_rho25_slots")
    for c in exigidas
        haskey(valores, c) || error("falta la medida obligatoria `$c` en $ruta")
    end
    hw = Hardware(
        valores["t_tabla_s"], valores["t_tabla_paralela_s"], valores["r_cpu_tablas_s"],
        valores["t_reto_s"], valores["t_reto_lote_s"], valores["t_ganador_s"],
        Int64(valores["m_tabla_B"]), Int64(valores["bytes_pieza_B"]),
        Int64(valores["bytes_mapa_presencia_B"]), Int64(valores["num_pruebas_por_pieza"]),
        Int64(valores["num_s_buckets"]), valores["o_medido"],
        valores["ploteo_sector_1000_piezas_s"], valores["w_sin_vdf_slots"],
        valores["w_con_vdf_rho25_slots"], fuente,
    )
    return hw
end
