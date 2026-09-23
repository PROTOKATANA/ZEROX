# modelo.jl — tipos, constantes y kernels puros de sellado-rama-v1
#
# Todos los símbolos del encargo son ENTRADAS. Nada se fija aquí.
# Unidades: segundos (s), bytes, piezas, tablas. τ = 1 s/slot y λ = 1 bloque/s son entradas.

const MODELO_VERSION = "SELLO-v0.1"

# ---------------------------------------------------------------------------
# Hardware medido (P-INTENTO M1: `mediciones/hardware.tsv`). Nunca se re-mide aquí.
# ---------------------------------------------------------------------------
struct Hardware
    t_tabla_s::Float64   # s por tabla y por núcleo estricto (809,13 ms)
    r_tablas_s::Float64  # tablas/s agregado de la máquina, forma C (25,027)
    hilos::Int           # hilos del banco (24)
    piece_bytes::Int     # Piece::SIZE = 1_048_672 B
end

function Hardware(; t_tabla_s::Real, r_tablas_s::Real, hilos::Integer,
                  piece_bytes::Integer)
    t = Float64(t_tabla_s)
    r = Float64(r_tablas_s)
    (t > 0 && r > 0 && hilos > 0 && piece_bytes > 0) ||
        throw(ArgumentError("hardware inválido: t, r, hilos y bytes deben ser > 0"))
    return Hardware(t, r, Int(hilos), Int(piece_bytes))
end

const TiB_BYTES = UInt64(1) << 40

"Piezas de 1 MiB que caben en 1 TiB."
piezas_por_TiB(hw::Hardware) = Float64(TiB_BYTES) / hw.piece_bytes

"Horas de un núcleo estricto para plotear 1 TiB (= N · t_tabla)."
horas_TiB_1nucleo(hw::Hardware) = piezas_por_TiB(hw) * hw.t_tabla_s / 3600.0

"Horas de máquina completa (agregado r) para plotear 1 TiB."
horas_TiB_maquina(hw::Hardware) = piezas_por_TiB(hw) / hw.r_tablas_s / 3600.0

"Coste agregado de una tabla en la máquina (s)."
t_tabla_maquina_s(hw::Hardware) = 1.0 / hw.r_tablas_s

"Núcleos equivalentes que la máquina mantiene ocupados al rendir r (r·t_tabla)."
nucleos_equivalentes(hw::Hardware) = hw.r_tablas_s * hw.t_tabla_s

# ---------------------------------------------------------------------------
# Modelo de punta (H-TIPS, declarada).
#
# Bloque = proceso de Poisson de tasa λ. La propagación tarda Δ. Un bloque creado
# en t referencia las puntas del sub-DAG visible {j : t_j ≤ t − Δ}. Entonces:
#   padres medios = 1 + λ·Δ   (coincide con los 1,14-1,39 medidos en DMS-v0.1)
#   puntas concurrentes ≈ 1 + λ·Δ
# La punta seleccionada avanza a tasa λ (un bloque por slot en media).
# ---------------------------------------------------------------------------
padres(λ::Float64, Δ::Float64) = 1.0 + λ * Δ
puntas_concurrentes(λ::Float64, Δ::Float64) = 1.0 + λ * Δ

"Tasa de re-ligadura exigida al honesto [religaduras/s] si ata `n_puntas` puntas."
tasa_religadura(λ::Float64, n_puntas::Float64) = λ * n_puntas

# ---------------------------------------------------------------------------
# Presupuesto temporal del honesto (§2.2 del encargo).
# ---------------------------------------------------------------------------
struct Presupuesto
    lambda::Float64
    tau::Float64
    Delta::Float64
    n_puntas::Float64
    tasa_religadura::Float64  # religaduras/s
    W_s::Float64              # segundos disponibles por re-ligadura
end

"""
    presupuesto_honesto(λ, τ, Δ; n_puntas = 1 + λΔ)

Tiempo disponible por re-ligadura: el honesto recibe la punta Δ después de su
creación y debe producir dentro del slot τ. Si ata `n_puntas` puntas a la vez,
reparte ese presupuesto.
"""
function presupuesto_honesto(λ::Real, τ::Real, Δ::Real; n_puntas::Real = NaN)
    λf = Float64(λ); τf = Float64(τ); Δf = Float64(Δ)
    (λf > 0 && τf > 0) || throw(ArgumentError("λ y τ deben ser > 0"))
    (Δf >= 0) || throw(ArgumentError("Δ debe ser ≥ 0"))
    Δc = min(Δf, τf)
    np = isnan(n_puntas) ? puntas_concurrentes(λf, Δf) : Float64(n_puntas)
    np > 0 || throw(ArgumentError("n_puntas debe ser > 0"))
    W = (τf - Δc) / np
    return Presupuesto(λf, τf, Δc, np, λf * np, W)
end

"Piezas cuyo objeto se puede materializar dentro de W con la máquina intacta."
delta_max_piezas(hw::Hardware, W_s::Float64) = hw.r_tablas_s * W_s

"Fracción del objeto de `S_piezas` materializable dentro de W."
fraccion_materializable(hw::Hardware, W_s::Float64, S_piezas::Float64) =
    delta_max_piezas(hw, W_s) / S_piezas

"Segundos de máquina para materializar `piezas`."
segundos_materializar(hw::Hardware, piezas::Float64) = piezas / hw.r_tablas_s

"Cuántas veces el presupuesto W cuesta materializar un objeto de `S_piezas`."
veces_presupuesto(hw::Hardware, W_s::Float64, S_piezas::Float64) =
    segundos_materializar(hw, S_piezas) / W_s

# ---------------------------------------------------------------------------
# Superficie de deriva α* (P-PRESTAMO F1), en fracciones de ESPACIO.
#   g = η_a·(α + β_d + β_x) − η_h·(1 − α − β_x)
#   α* = (η_h − η_a·β_d − (η_h+η_a)·β_x) / (η_h+η_a)
# ---------------------------------------------------------------------------
alpha_estrella(η_h::Real, η_a::Real, β_d::Real, β_x::Real) =
    (η_h - η_a * β_d - (η_h + η_a) * β_x) / (η_h + η_a)

g_deriva(α::Real, η_h::Real, η_a::Real, β_d::Real, β_x::Real) =
    η_a * (α + β_d + β_x) - η_h * (1 - α - β_x)

"Gap exacto de α* al sustituir todo el espacio tramposo `s` de β_d por β_x."
perdida_sustitucion(s::Real) = s / 2

"Fracción del tiempo que el honesto dedica a re-ligaduras."
carga_religadura(p::Presupuesto, T_bajo_s::Float64) =
    p.tasa_religadura * T_bajo_s / p.tau

"Espacio extra relativo por atar `k` ramas en vez de una."
espacio_extra_relativo(k::Real) = Float64(k) - 1.0

"""
    umbral_backfire(c_x)

Coste por unidad de β_d a partir del cual el atacante abandona β_d del todo.
Como β_x da el doble de daño por unidad de espacio que β_d, el atacante prefiere
β_x en cuanto `c_d > c_x/2`. Devuelve `c_x/2`.
"""
umbral_backfire(c_x::Real) = Float64(c_x) / 2
