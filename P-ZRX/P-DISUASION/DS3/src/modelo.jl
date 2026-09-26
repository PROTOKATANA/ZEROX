#= DS-3 · modelo.jl
   Tipos, parámetros etiquetados y FÓRMULAS CERRADAS del MODELO ratificado por DS-2
   (`P-ZRX/P-DISUASION/resultados-DS2/MODELO.md`, ratificado en `REVISION-DS2.md`).

   Regla de oro de este fichero: NADA se deriva aquí por primera vez. Cada función cita la
   sección del MODELO o el informe fuente (P-PRESTAMO, P-CLAVE, P-COBERTURA, P-INTENTO,
   P-EQUIVOCACION) de la que proviene. Las etiquetas (hecho / derivación / hipótesis /
   condicionado) viajan con cada parámetro en `escenarios.tsv`, nunca como constante oculta.

   Unidades: espacio normalizado a 1; tiempo en slots (τ = 1 s/slot, `P-COBERTURA` `TAU_S`);
   energía en kWh salvo donde se diga; emisión en unidades de emisión (u.e.).
=#

# ───────────────────────────────────────────── hechos medidos (MODELO §2.7, §2.9, §2.10, §2.12)

const PIEZA_B = 1_048_672                 # Piece::SIZE (P-COBERTURA, pieces.rs:1226)
const BYTES_TIB = 2.0^40                  # 1 TiB en bytes
const TAU_S = 1.0                         # s/slot (SLOT_DURATION = 1000 ms)
const T_TABLA_S = 0.80913                 # s/núcleo, tabla PoS 1 hilo (P-INTENTO, medido)
const R_24H = 25.03                       # tablas/s, forma C 24 hilos (P-INTENTO, medido)
const T_M3_S = 0.02299                    # s, camino ganador sin regenerar tabla (P-INTENTO)
const T_UNIDAD_S = 0.809                  # s/unidad estricto (P-COBERTURA Entrada)
const R_MAQUINA_S = 25.03                 # unidades/s máquina de referencia (P-COBERTURA)
const D_A_S = 60.0                        # s, plazo de respuesta por defecto (P-COBERTURA)
const Vatio_NUCLEO = 65.0                 # W/núcleo (hipótesis P-COBERTURA §5.4)
const Vatio_TIB = 5.0                     # W/TiB (hipótesis P-COBERTURA §5.4)
const HASH_CPU_16 = 73_789_447.0          # H/s CPU 16 núcleos en reposo (A10-M1, medido)
const HASH_GPU_1070 = 561_084_507.0       # H/s GTX 1070 (A10-M1, medido; cota INFERIOR)
const J_POR_HASH_GPU = 1.94e-7            # J/hash (109,0 W / 561,1 MH/s; A10-M1, medido)

# Filecoin (Pankovska et al. 2024, tabla 5; MODELO §2.10): rangos y medias ponderadas
const A_FIL_MIN = 7.86e-9;  const A_FIL_MAX = 1.15e-7;  const A_FIL_MED = 2.17e-8   # Wh/byte
const B_FIL_MIN = 5.21e-13; const B_FIL_MAX = 1.00e-11; const B_FIL_MED = 4.16e-12   # W/byte
const PUE_MIN = 1.2;        const PUE_MAX = 1.79;        const PUE_MED = 1.426

# ───────────────────────────────────────────────────────────── tipos del reparto

"""Retención de recompensas: fracción `ρ_ret` retenida `T_v` slots (MODELO §2.3)."""
struct Retencion
    rho::Float64
    Tv::Float64
end

"""Distribución Pareto truncada de tamaños de clave (hipótesis H3, P-CLAVE)."""
struct Pareto
    f_min::Float64
    alpha::Float64
end

"""Reparto de espacio de la carrera de doble farmeo (MODELO §2.1)."""
struct Reparto
    α::Float64
    βd::Float64
    βx::Float64
    ηh::Float64
    ηa::Float64
end

Reparto(α, βd; βx = 0.0, ηh = 1.0, ηa = 1.0) = Reparto(α, βd, βx, ηh, ηa)

# ─────────────────────────────────── F1 · frontera de deriva (MODELO §2.1)

"`α* = (η_h − η_a β_d − (η_h+η_a) β_x)/(η_h+η_a)`. Identidad aritmética exacta."
@inline alpha_estrella(βd, βx = 0.0, ηh = 1.0, ηa = 1.0) =
    (ηh - ηa * βd - (ηh + ηa) * βx) / (ηh + ηa)

"Versión exacta en `Rational{BigInt}` para la comprobación de §4.1."
@inline alpha_estrella_exacta(βd::Rational, βx::Rational = 0 // 1,
                              ηh::Rational = 1 // 1, ηa::Rational = 1 // 1) =
    (big(ηh) - big(ηa) * big(βd) - (big(ηh) + big(ηa)) * big(βx)) / (big(ηh) + big(ηa))

"Trabajo de la rama pública por unidad de tiempo (MODELO §2.2)."
@inline mu_publica(r::Reparto) = r.ηh * (1 - r.α - r.βx)

"Trabajo de la rama privada por unidad de tiempo (MODELO §2.2)."
@inline mu_privada(r::Reparto) = r.ηa * (r.α + r.βd + r.βx)

"`g = μ_a − μ_p`: deriva (privada menos pública). `g > 0` ⇒ la privada gana la media."
@inline deriva(r::Reparto) = mu_privada(r) - mu_publica(r)

"`β_d` que cruza `g = 0` con `β_x = 0`: `β_d > η_h(1−α)/η_a − α`; con `η=1`, `1−2α`."
@inline beta_cruce(α, ηh = 1.0, ηa = 1.0) = ηh * (1 - α) / ηa - α

"Tasa del ADVERSARIO por paso, `p = μ_a/(μ_a+μ_p)` (MODELO §2.2, condicionado a H-PUENTE)."
@inline function p_de_alpha(r::Reparto)
    ra = mu_privada(r)
    rp = mu_publica(r)
    return ra + rp <= 0 ? 1.0 : ra / (ra + rp)
end

"`d = (μ_p − μ_a)·F`, déficit inicial en unidades de peso (MODELO §2.2)."
@inline deficit_esperado(r::Reparto, F) = (mu_publica(r) - mu_privada(r)) * F

"Déficit entero que consume la DP. Convención declarada: `round(Int, d)` (ver faltas F3)."
@inline deficit_entero(r::Reparto, F) = max(0, round(Int, deficit_esperado(r, F)))

"Forma cerrada de horizonte largo `(q/p)^(d+1)`; cota superior, no se usa para `F` finito."
@inline eventual(q, d) = q < 1 - q ? (q / (1 - q))^(d + 1) : 1.0

"`log10` de la forma cerrada, para el régimen que subdesborda `Float64`."
@inline eventual_log10(q, d) = (d + 1) * log10(q / (1 - q))

# ─────────────────────────────── F2 · retención por clave (MODELO §2.3, §2.4)

"`θ = λ f T_v`: bloques esperados dentro de la ventana de retención."
@inline theta(λ, f, ret::Retencion) = λ * f * ret.Tv

"`E[B] = ρ_ret I θ/2` (liberación lineal)."
@inline balance_medio(λ, f, ret::Retencion, I) = ret.rho * I * theta(λ, f, ret) / 2

"`Var[B] = ρ_ret² I² θ/3` (liberación lineal)."
@inline balance_var(λ, f, ret::Retencion, I) = ret.rho^2 * I^2 * theta(λ, f, ret) / 3

"`P(B = 0) = e^{−θ}`, exacta en el modelo (Poisson)."
@inline p_saldo_cero(λ, f, ret::Retencion) = exp(-theta(λ, f, ret))

"""
    p_saldo_cero_normal(θ; ρ = 1, I = 1, γ = 0.5) -> Float64

Aproximación normal `Φ(−μ/σ)` con `μ = ρIγθ`, `σ² = ρ²I²θ/3` (P-CLAVE `masa_cero_aprox`).
**No decide ninguna cifra**: existe para MEDIR su error y delatar una ruta que la use.
"""
function p_saldo_cero_normal(θ; ρ = 1.0, I = 1.0, γ = 0.5)
    μ = ρ * I * γ * θ
    σ2 = ρ^2 * I^2 * (θ / 3)
    σ2 <= 0 && return 1.0
    return 0.5 * erfc(μ / sqrt(2 * σ2))
end

"Desviación típica relativa `√(4/(3θ))`: mide cuándo falla la normal."
@inline rsd_pequeno(λ, f, ret::Retencion) = sqrt(4.0 / (3.0 * theta(λ, f, ret)))

"""
    masa_prob(dist, x; F_max = Inf)

`E[min(f,x)] / E[f]` para una Pareto truncada en `[f_min, F_max]` (P-CLAVE, `masa_prob`).
`F_max = Inf` exige `alpha > 2`; es la forma que H3 usa (Pareto(1e-8, 2.2)).
"""
function masa_prob(dist::Pareto, x; F_max = Inf)
    x <= dist.f_min && return 0.0
    b = 2 - dist.alpha
    if isinf(F_max)
        dist.alpha <= 2 && throw(ArgumentError("Pareto no truncada con α ≤ 2: E[f] diverge"))
        return 1 - (dist.f_min / x)^(dist.alpha - 2)
    else
        x = min(x, F_max)
        @assert F_max > dist.f_min "F_max debe superar f_min"
        return (x^b - dist.f_min^b) / (F_max^b - dist.f_min^b)
    end
end

"`M(ε/(λ T_v))`: fracción de espacio en claves con saldo < `ε` (MODELO §2.4)."
@inline masa_espacio_bajo_b(dist::Pareto, ε, λ, T_v) = masa_prob(dist, ε / (λ * T_v))

"`coef = ρ_ret·I·λ·T_v/2` (MODELO §2.4; con `I=1` coincide con P-PRESTAMO §2.4)."
@inline coef_reclutamiento(ret::Retencion, I, λ) = ret.rho * I * λ * ret.Tv / 2

"""
    coste_reclutamiento(β, B_ε, coef)

`C(β) = 0` si `β ≤ B(ε)`; `(β − B(ε))·coef` si `β > B(ε)`. Reproduce el ESCALÓN, no interpola.
"""
@inline function coste_reclutamiento(β, B_ε, coef)
    β <= B_ε && return 0.0
    return (β - B_ε) * coef
end

"Pérdida del reclutado castigado: `ρ_ret·I·T_v + c_r + I·M` (MODELO §2.5)."
@inline perdida_por_reclutado(ret::Retencion, I, c_r, M) = ret.rho * I * ret.Tv + c_r + I * M

"Soborno mínimo por reclutado: `κ·q·pérdida` (MODELO §2.5; P-PRESTAMO §3.2)."
@inline soborno_necesario(κ, q, perdida) = κ * q * perdida

"""
    region_disuasion(; κ, q, ρ_ret, I, c_r, M, V, N, ν, F)

Región `(ρ_ret, T_v)` de MODELO §2.5. Devuelve `(disuade, Tv_min, Tv_max, existe, motivo)`:
`disuade(ρ_ret,T_v)` exige las tres condiciones simultáneas
`κq(ρ_ret I T_v + c_r + I M) > V/N`, `ν ρ_ret T_v < 1` y `T_v > F`.
Con `κq = 0` o `V` sin cota la región es VACÍA. `ρ_ret·T_v` es la unidad que manda.
"""
function region_disuasion(; κ, q, ρ_ret, I, c_r, M, V, N, ν, F)
    perdida_fija = c_r + I * M
    if κ * q <= 0 || !isfinite(V)
        return (disuade = (Tv) -> false, Tv_min = Inf, Tv_max = 0.0, existe = false,
                motivo = κ * q <= 0 ? "κq = 0: el soborno es 0, la región se vacía" :
                                      "V sin cota: no hay región")
    end
    if ρ_ret <= 0
        return (disuade = (Tv) -> false, Tv_min = Inf, Tv_max = 0.0, existe = false,
                motivo = "ρ_ret = 0: no hay retención")
    end
    Tv_min = (V / (N * κ * q) - perdida_fija) / (ρ_ret * I)
    Tv_max = ν > 0 ? 1 / (ν * ρ_ret) : Inf
    Tv_min = max(Tv_min, F)                      # T_v MUST superar F (MODELO §2.5)
    existe = Tv_min < Tv_max
    disuade = (Tv) -> (κ * q * (ρ_ret * I * Tv + perdida_fija) > V / N) &&
                      (ν * ρ_ret * Tv < 1) && (Tv > F)
    return (disuade = disuade, Tv_min = Tv_min, Tv_max = Tv_max, existe = existe,
            motivo = existe ? "región no vacía" : "Tv_min ≥ Tv_max: región vacía")
end

# ─────────────────────────────── F3 · cobertura (sembrador A3, MODELO §2.8, §2.9)

"Piezas por TiB con `Piece::SIZE` (P-COBERTURA)."
@inline piezas_por_TiB(pieza = PIEZA_B) = BYTES_TIB / pieza

"Ventana total del tramposo: `w·τ + D_a` [s]."
@inline ventana_s(w, τ = TAU_S, D_a = D_A_S) = w * τ + D_a

"`B = maquinas·r_maquina·(w·τ + D_a)`: unidades regenerables dentro de la ventana."
@inline B_unidades(r_maquina, maquinas, w, τ = TAU_S, D_a = D_A_S) =
    maquinas * r_maquina * ventana_s(w, τ, D_a)

"`almacenamiento_forzado = max(0, 1 − B/N)` si `k > B`; `0` si `k ≤ B`. Frontera exacta."
@inline almacenamiento_forzado(N, B, k) = k <= B ? 0.0 : max(0.0, 1.0 - B / N)

"`1 − almacenamiento_forzado`."
@inline ahorro_maximo(N, B) = min(1.0, B / N)

"¿Existe auditoría de `k` aperturas capaz de detectar? `k > B` (frontera, no curva suave)."
@inline deteccion_posible(k, B) = k > B

"Núcleos estrictos continuos para regenerar 1 TiB dentro de la ventana (P-COBERTURA §5.4)."
@inline nucleos_por_TiB(w, t_unidad = T_UNIDAD_S, τ = TAU_S, D_a = D_A_S) =
    piezas_por_TiB() * t_unidad / ventana_s(w, τ, D_a)

"Máquinas de referencia para regenerar 1 TiB dentro de la ventana."
@inline maquinas_por_TiB(w, r_maquina = R_MAQUINA_S, τ = TAU_S, D_a = D_A_S) =
    piezas_por_TiB() / (r_maquina * ventana_s(w, τ, D_a))

"Energía de regenerar 1 TiB durante una ventana, kWh (hipótesis 65 W/núcleo)."
@inline energia_regenerar_kWh(w, vatio = Vatio_NUCLEO, t_unidad = T_UNIDAD_S,
                              τ = TAU_S, D_a = D_A_S) =
    piezas_por_TiB() * t_unidad * vatio / 3.6e6

"Energía de almacenar 1 TiB durante una ventana, kWh (hipótesis 5 W/TiB)."
@inline energia_almacenar_kWh(w, vatio = Vatio_TIB, τ = TAU_S, D_a = D_A_S) =
    ventana_s(w, τ, D_a) * vatio / 3.6e6

"Razón regenerar/almacenar (independiente de `w`, P-COBERTURA §5.4)."
@inline razon_energia(w, vatio_n = Vatio_NUCLEO, vatio_t = Vatio_TIB) =
    energia_regenerar_kWh(w, vatio_n) / energia_almacenar_kWh(w, vatio_t)

"Cruce de sustitución de hardware núcleo↔TiB, en slots (P-COBERTURA §5.4)."
@inline function w_cruce_disco(razon_precio = 1.0, factor_gpu = 1.0, t_unidad = T_UNIDAD_S,
                               τ = TAU_S, D_a = D_A_S)
    seg = piezas_por_TiB() * t_unidad * razon_precio / factor_gpu - D_a
    return max(0.0, seg / τ)
end

# ─────────────────────────────── F4 · sembrador (A3, MODELO §2.7)

"`N_eq = r·w·τ`: piezas honestas equivalentes que emula una máquina (P-INTENTO §11)."
@inline N_eq(r, w, τ = TAU_S) = r * w * τ

"`coste/solución = (1/(r·w·p) + t_M3)/π_DAG`, segundos de máquina por bloque pagado."
@inline coste_por_solucion(r, w, p, t_M3 = T_M3_S, π_DAG = 1.0) =
    (1 / (r * w * p) + t_M3) / π_DAG

"`w_min_latencia = 1/(r·τ·p)`."
@inline w_min_latencia(r, p, τ = TAU_S) = 1 / (r * τ * p)

"`w_equilibrio = N_h/(r·τ)`: `w` donde una máquina emula la red entera."
@inline w_equilibrio(N_h, r, τ = TAU_S) = N_h / (r * τ)

"`p ≈ λ/N_h` (calibración del controlador, P-INTENTO §11)."
@inline p_calibrado(λ, N_h) = λ / N_h

# ─────────────────────────────── F5 · partición de identidades (A4)

"Modelo DS-3 declarado: coste de `m` identidades con requisito fijo `q` (u.e.)."
@inline coste_identidades(q, m) = q * m

"Coste por byte de cumplir `q` con una clave de fracción `f`: `q/f`. No proporcional."
@inline coste_por_byte(q, f) = q / f

"Fracción de ingreso doméstico consumida por `q` sobre una granja de fracción `f_semanal`."
@inline fraccion_ingreso(q, ingreso_semanal) = ingreso_semanal <= 0 ? Inf : q / ingreso_semanal

# ─────────────────────────────── F6 · energía PoW (A8, MODELO §2.12)

"Hashers necesarios para el trabajo `W` [H]."
@inline energia_pow(hashes, J_por_hash = J_POR_HASH_GPU) = hashes * J_por_hash

"Tiempo [s] de calcular `hashes` a `tasa` H/s."
@inline tiempo_pow(hashes, tasa) = hashes / tasa

# ─────────────────────────────── F7 · modelo de energía Filecoin (MODELO §2.10)

"`P = (A·SR + B_fil·Cap)·PUE` [W]."
@inline potencia_filecoin(A, SR, B_fil, Cap, PUE) = (A * SR + B_fil * Cap) * PUE

# ─────────────────────────────── F8 · cota de Baig–Pietrzak (MODELO §2.11)

"""
    pasos_bp(φ, ε, ρ)

Cota del Teorema 1 **tal como está transcrita en MODELO §2.11**:
`⌈ρ²φ²(1+ε)((1+ε)−1/φ)/ε⌉ + ⌈ρφ²((1+ε)−1/φ)/ε⌉ + 2⌈log φ / log(1+ε)⌉`.
No es una cifra de ZEROX: es la comprobación cruzada de que la fórmula está bien implementada.
"""
function pasos_bp(φ, ε, ρ)
    t1 = ρ^2 * φ^2 * (1 + ε) * ((1 + ε) - 1 / φ) / ε
    t2 = ρ * φ^2 * ((1 + ε) - 1 / φ) / ε
    t3 = 2 * (log(φ) / log(1 + ε))
    return (bootstrap = ceil(Int, t1), termino2 = ceil(Int, t2), replot = ceil(Int, t3),
            total = ceil(Int, t1) + ceil(Int, t2) + ceil(Int, t3))
end

# ──────────────────────── RNG no consecutivo (misma mezcla que P-CLAVE, declarada)

"Mezcla SplitMix64 de dos enteros de 64 bits (P-CLAVE `rapido.jl`)."
@inline function hash64(a::UInt64, b::UInt64)
    z = a + 0x9E3779B97F4A7C15 * b + 0x9E3779B97F4A7C15
    z = (z ⊻ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ⊻ (z >> 27)) * 0x94D049BB133111EB
    return z ⊻ (z >> 31)
end
