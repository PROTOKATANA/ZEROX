# modelo.jl — símbolos del encargo y relaciones derivadas.
#
# NADA de este fichero es un parámetro de consenso fijado: `N`, `k`, `w`, `D_a`,
# `R`, `φ`, `M` son ENTRADAS. El modelo es el juego «regeneración contra auditoría».
#
# Separación de las tres coberturas del encargo §2.1:
#   C-datos    = KZG sobre la codificación de datos PÚBLICOS  (ya existe; inútil)
#   C-caro     = atar las N tablas PoS / chunks enmascarados  (NO existe hoy)
#   C-forma    = probar que los bytes están en disco CODIFICADOS (NO se prueba ni
#                para un chunk: lib.rs:248-249 reconstruye el valor de disco)
# Las dimensiones temporales son `preexistencia` y `vinculación`.

# ── Constantes verificadas en fuente (no son parámetros de consenso) ───────────
const BYTES_TiB = 2.0^40                      # 1 TiB en bytes
const PIEZA_B   = 1_048_672                   # Piece::SIZE  (pieces.rs:1226)
const TAU_S     = 1.0                         # s/slot, perfil A″ nominal (entrada)

"""Piezas (unidades) por TiB con `Piece::SIZE`. `[derivado]`"""
piezas_por_TiB(bytes_pieza::Real = PIEZA_B) = BYTES_TiB / bytes_pieza

# ── Entradas del modelo ───────────────────────────────────────────────────────
"""
`N`   unidades (piezas) declaradas en el lote                    [unidades]
`k`   aperturas por auditoría (posiciones que el auditor pide)   [unidades]
`w`   adelanto con que el reto es conocido                       [slots]
`D_a` plazo de respuesta tras el reto                            [s]
`t_unidad` tiempo de 1 núcleo estricto por unidad                [s/unidad]
`r_maquina` rendimiento agregado de la máquina de referencia     [unidades/s]
`maquinas` máquinas que aporta el adversario                     [máquinas]
"""
struct Entrada
    N::Int
    k::Int
    w_slots::Float64
    D_a_s::Float64
    t_unidad_s::Float64
    r_maquina_s::Float64
    maquinas::Float64
    tau_s::Float64
end

function Entrada(; N::Integer, k::Integer, w_slots::Real, D_a_s::Real,
                 t_unidad_s::Real = 0.809, r_maquina_s::Real = 25.03,
                 maquinas::Real = 1.0, tau_s::Real = TAU_S)
    (N >= 1) || throw(ArgumentError("N debe ser >= 1"))
    (0 <= k <= N) || throw(ArgumentError("k debe estar en [0,N]"))
    (w_slots >= 0) || throw(ArgumentError("w debe ser >= 0"))
    (D_a_s >= 0) || throw(ArgumentError("D_a debe ser >= 0"))
    (t_unidad_s > 0) || throw(ArgumentError("t_unidad debe ser > 0"))
    (r_maquina_s > 0) || throw(ArgumentError("r_maquina debe ser > 0"))
    (maquinas > 0) || throw(ArgumentError("maquinas debe ser > 0"))
    return Entrada(Int(N), Int(k), Float64(w_slots), Float64(D_a_s),
                   Float64(t_unidad_s), Float64(r_maquina_s), Float64(maquinas),
                   Float64(tau_s))
end

"""Ventana total de la que dispone el tramposo: adelanto más plazo. [s]"""
ventana_s(e::Entrada) = e.w_slots * e.tau_s + e.D_a_s

"""
`B` — unidades que el adversario puede regenerar DENTRO de la ventana.
`B = maquinas · r_maquina · (w·τ + D_a)`. Es la primitiva del modelo: todo lo
demás (φ*, detección, coste) se expresa en función de `B`.
Etiqueta: `[derivado]` de las entradas.
"""
B_unidades(e::Entrada) = e.maquinas * e.r_maquina_s * ventana_s(e)
B_entero(e::Entrada) = floor(Int, B_unidades(e))

"""
Fracción **almacenada mínima** que el tramposo necesita para que NINGUNA auditoría
de `k` aperturas lo detecte:

    almacenamiento_forzado(N, B) = max(0, 1 − B/N)          [adimensional]

Si `k ≤ B`, vale `0`: no hace falta almacenar nada (colapso de E2). Es la frontera
que pide el encargo F4. **Independiente de `k` en el régimen `k > B`**: moverla exige
mover `B` (o sea `w`, `D_a`, `R`) o `N`, nunca el número de aperturas. Exacta y sin
aproximación (véase `referencia.jl: almacenamiento_forzado_exacta`). `[demostrado]`
"""
almacenamiento_forzado(N::Integer, B::Integer) = max(0.0, 1.0 - float(B) / float(N))

"""¿Existe alguna auditoría de `k` aperturas capaz de detectar algo? `k > B`. `[demostrado]`"""
deteccion_posible(k::Integer, B::Integer) = k > B

"""
Fracción máxima de almacenamiento que el tramposo puede AHORRARSE sin ser detectable:
`min(1, B/N)`. Es `1 − almacenamiento_forzado`. `[derivado]`
"""
ahorro_maximo(N::Integer, B::Integer) = min(1.0, float(B) / float(N))

# ── Coste absoluto del tramposo (F4) ─────────────────────────────────────────
"""
Trabajo total (una pasada) para generar el objeto caro de 1 TiB. `[derivado]`
`N_TiB · t_unidad`, en segundos·núcleo. Reproduce `235,6 h·núcleo/TiB`.
"""
trabajo_nucleo_s_por_TiB(e::Entrada, bytes_pieza::Real = PIEZA_B) =
    piezas_por_TiB(bytes_pieza) * e.t_unidad_s

"""Trabajo en horas·núcleo por TiB. `[derivado]`"""
trabajo_nucleo_h_por_TiB(e::Entrada, bytes_pieza::Real = PIEZA_B) =
    trabajo_nucleo_s_por_TiB(e, bytes_pieza) / 3600.0

"""
Núcleos estrictos que hay que sostener para regenerar 1 TiB DENTRO de la ventana.
`N_TiB·t_unidad/(w·τ + D_a)`. `[derivado]`
"""
nucleos_por_TiB(e::Entrada, bytes_pieza::Real = PIEZA_B) =
    trabajo_nucleo_s_por_TiB(e, bytes_pieza) / ventana_s(e)

"""
Máquinas de referencia (agregado `r_maquina`) que hay que sostener para regenerar
1 TiB dentro de la ventana. Reproduce `5,838 CPU/TiB` a `w=7.175`, `D_a=60`,
`r=25,027041`, `t=0,809`. `[derivado]`
"""
maquinas_por_TiB(e::Entrada, bytes_pieza::Real = PIEZA_B) =
    piezas_por_TiB(bytes_pieza) / (e.r_maquina_s * ventana_s(e))

"""
Núcleos-equivalentes que comprime una máquina de referencia: `r_maquina · t_unidad`.
Es el factor EXACTO de la reconciliación `235,6 h·núcleo/TiB ↔ 5,84 CPU/TiB`.
`[derivado]`
"""
nucleos_equivalentes_por_maquina(e::Entrada) = e.r_maquina_s * e.t_unidad_s

"""
Cruce con el precio del disco, en slots. Para AHORRARSE 1 TiB hay que sostener
`nucleos_por_TiB` núcleos durante toda la ventana; igualando el precio del
hardware de esos núcleos al de 1 TiB de disco:

    w + D_a/τ = N_TiB · t_unidad · (precio_núcleo / precio_TiB)   [s]

`razon_precio = precio_núcleo/precio_TiB` es una HIPÓTESIS declarada, no un dato.
Con `razon_precio = 1` reproduce el `w ≈ 8,4·10⁵` slots de P-PERMANENCIA.
`factor_gpu` (documentación ajena, 17×, NO MEDIDA) divide los núcleos necesarios.
`[derivado + hipótesis]`
"""
function w_cruce_disco_slots(e::Entrada; razon_precio::Real = 1.0, factor_gpu::Real = 1.0,
                             bytes_pieza::Real = PIEZA_B)
    (razon_precio > 0) || throw(ArgumentError("razon_precio > 0"))
    (factor_gpu > 0) || throw(ArgumentError("factor_gpu > 0"))
    seg = piezas_por_TiB(bytes_pieza) * e.t_unidad_s * razon_precio / factor_gpu - e.D_a_s
    return max(0.0, seg / e.tau_s)
end

"""Energía del tramposo por TiB y ventana, en kWh, con `vatio_nucleo` [W]. `[derivado + hipótesis]`"""
energia_kWh_por_TiB(e::Entrada; vatio_nucleo::Real = 65.0, bytes_pieza::Real = PIEZA_B) =
    trabajo_nucleo_s_por_TiB(e, bytes_pieza) * vatio_nucleo / 3.6e6

"""Energía de conservar 1 TiB durante una ventana, en kWh, con `vatio_TiB` [W]. `[derivado + hipótesis]`"""
energia_kWh_almacenar(e::Entrada; vatio_TiB::Real = 5.0) =
    ventana_s(e) * vatio_TiB / 3.6e6

# ── Presupuesto efectivo de aperturas del honesto (entrada de diseño) ────────
"""
Lecturas por segundo que debe sostener el honesto para servir `k` aperturas en
`D_a`: `k/D_a`. Comparar con `r_maquina·(1 + w·τ/D_a)`, el umbral de detección
expresado como TASA. `[derivado]`
"""
tasa_lectura_honesta(e::Entrada) = e.k / e.D_a_s
"""Umbral de tasa: `B/D_a`. `[derivado]`"""
tasa_regeneracion_adversaria(e::Entrada) = B_unidades(e) / e.D_a_s

# ── F5 · Coste del registro (altas, estado, caducidad pseudoaleatoria) ───────
# Constantes VERIFICADAS EN FUENTE del formato fijado:
const PIEZAS_POR_SEGMENTO   = 256    # ArchivedHistorySegment::NUM_PIECES (segments.rs:546)
const MIN_SECTOR_LIFETIME_SEG = 4    # MIN_SECTOR_LIFETIME (subspace-runtime/src/lib.rs:190)
const MAX_PIEZAS_POR_SECTOR = 1000   # MAX_PIECES_IN_SECTOR (subspace-runtime/src/lib.rs:125)

"""
Coste del registro de una parcela de `piezas` unidades.

`kappa_seg_slot` tasa de producción de segmentos archivados [segmentos/slot] (ENTRADA:
no se fija aquí). `h_segmentos` es `history_size` en el momento del alta [segmentos].
`bytes_alta` bytes por entrada de registro [B]. `M_slots` edad exigida [slots].

La caducidad verificada es `expires_in = h + min + (input_hash mod 3h)`, con
`input_hash = blake3(sector_id ‖ segment_commitment)`; luego la vida restante es
uniforme en `[min, min+3h)` segmentos y su media es `min + 1,5h`. `[derivado]`
"""
function coste_registro(; piezas::Integer, kappa_seg_slot::Real, h_segmentos::Real,
                        bytes_alta::Real = 200.0, M_slots::Real = 0.0)
    (kappa_seg_slot > 0) || throw(ArgumentError("kappa > 0"))
    (h_segmentos > 0) || throw(ArgumentError("h > 0"))
    sectores = ceil(Int, piezas / MAX_PIEZAS_POR_SECTOR)
    vida_seg = MIN_SECTOR_LIFETIME_SEG + 1.5 * h_segmentos
    vida_slots = vida_seg / kappa_seg_slot
    altas_slot = sectores / vida_slots
    return (sectores = sectores,
            vida_segmentos = vida_seg,
            vida_slots = vida_slots,
            altas_por_slot = altas_slot,
            altas_por_dia = altas_slot * 86_400.0,
            estado_B = sectores * bytes_alta,
            estado_B_por_TiB = ceil(piezas_por_TiB() / MAX_PIEZAS_POR_SECTOR) * bytes_alta,
            fraccion_inactiva_por_M = M_slots / vida_slots)
end
