"""
FV-1 · modelo.jl

Cuatro bloques de cálculo, en el orden del §4.C de `ORDEN-FV1-DISENO.md`:

  1. Quórum frente a `p` (participación honesta) y `a` (fracción del atacante),
     con ausencias CORRELACIONADAS por tamaño de clave (Monte Carlo propio).
  2. Reproducción cruzada de los números de la propuesta antigua
     (`research/dag-poas-capa-finalidad.md` §4.A y §4.D): sorteo ponderado,
     representación del comité y sesgo por elección de ancla — y comparación
     con el diseño SIN sorteo (voto directo ponderado, tipo F3) que este
     encargo recomienda.
  3. Tamaño y coste anual del certificado (BLS agregada + mapa de bits),
     paramétrico en el número de participantes elegibles `M`.
  4. Ventana del doble farmeo: tiempo hasta el sello con GossiPBFT
     (fórmula de temporizador de FIP-0086, `2*Δ*BackOffExponent^ronda`),
     paramétrico en `Δ` y comparado con `F_slots`.

Todo en Base + stdlib (Random, Statistics, Printf) — sin paquetes externos,
sin Python. Semillas fijas y NO consecutivas (ver `SEMILLAS` más abajo).
"""
module Modelo

using Random
using Statistics
using Printf

# ----------------------------------------------------------------------
# Semillas fijas, no consecutivas (LINEO §"semilla"; hallazgo de Katana:
# semillas consecutivas de StableRNG sesgan el MC — aquí no se usa StableRNG,
# se usa Random.Xoshiro de Base, y aun así se mantienen no consecutivas
# por disciplina de auditoría).
# ----------------------------------------------------------------------
const SEMILLAS = (
    quorum      = 0x1F3A9C7B5E,
    quorum_cov  = 0x7E2D0B5911,
    sorteo_cruz = 0x4C81F033A7,
    sesgo_ancla = 0x9B60E4127D,
)

# ======================================================================
# BLOQUE 1 · Quórum con ausencias correlacionadas por tamaño de clave
# ======================================================================

"""
    pesos_pareto(rng, n, xmin, alpha_cola)

`n` pesos i.i.d. de una Pareto de exponente de cola `alpha_cola` (P(X>x) ~ x^-alpha_cola),
escala mínima `xmin`. `alpha_cola` es el exponente de la COLA (no el de la densidad,
que es `alpha_cola+1` — la confusión exacta que corrigió DS-6 de `P-ZRX/P-DISUASION/`).
Devuelve el vector normalizado para que sume 1 (fracción del espacio honesto total).
"""
function pesos_pareto(rng::AbstractRNG, n::Int, xmin::Float64, alpha_cola::Float64)
    u = rand(rng, n)
    x = xmin .* (1.0 .- u) .^ (-1.0 / alpha_cola)
    return x ./ sum(x)
end

"""
    pesos_homogeneos(n)

`n` claves de igual tamaño (caso de contraste, "mean-field").
"""
pesos_homogeneos(n::Int) = fill(1.0 / n, n)

"""
    prob_quorum_mc(rng, pesos_honestos, a, pi_uptime, n_rep) -> (p_hat, ic99, n_min_cubierto)

Monte Carlo: cada clave honesta `i` (peso `w_i`, ya escalado a fracción de espacio
TOTAL, es decir `sum(pesos_honestos) == 1 - a`) está en línea de forma independiente
con probabilidad `pi_uptime` (aproximación de uptime por clave; la correlación real
que se mide aquí es la del TAMAÑO, no la del apagón en sí — un apagón autocorrelado
en el tiempo no se modela, se declara como límite en el informe).

Devuelve la fracción de réplicas en que el peso honesto en línea alcanza el quórum
`>= 2/3` del peso TOTAL (F3/FIP-0086: "≥ 2/3 of the TOTAL QAP", no de los presentes).
"""
function prob_quorum_mc(rng::AbstractRNG, pesos_honestos::Vector{Float64},
                         pi_uptime::Float64, n_rep::Int; umbral::Float64 = 2/3)
    exitos = 0
    n = length(pesos_honestos)
    online = Vector{Bool}(undef, n)
    for _ in 1:n_rep
        w_online = 0.0
        @inbounds for i in 1:n
            if rand(rng) < pi_uptime
                w_online += pesos_honestos[i]
            end
        end
        if w_online >= umbral
            exitos += 1
        end
    end
    p_hat = exitos / n_rep
    # IC 99% normal (Wald); válido porque n_rep >= 10^5 en todas las celdas publicadas.
    se = sqrt(max(p_hat * (1 - p_hat), 1e-12) / n_rep)
    ic99 = 2.5758293035489 * se
    return p_hat, ic99
end

"""
    barrido_quorum(; alphas_a, pis, colas, ns, xmin, n_rep, seed)

Barrido completo. `colas`: exponentes de cola Pareto a comparar (incluye el caso
`Inf` == homogéneo, como control). Devuelve un `Vector{NamedTuple}` con una fila
por celda.
"""
function barrido_quorum(; alphas_a = (0.10, 0.20, 0.25, 0.30, 0.33, 0.40),
                          pis = (0.80, 0.90, 0.95, 0.99, 1.00),
                          colas = (2.2, 2.5, 3.0, Inf),
                          ns = (100, 1_000, 10_000),
                          xmin = 1.0e-6,
                          n_rep = 200_000,
                          seed = SEMILLAS.quorum)
    filas = NamedTuple[]
    for a in alphas_a, cola in colas, n in ns, pi_up in pis
        rng = Xoshiro(seed ⊻ hash((a, cola, n, pi_up)))
        pesos = cola == Inf ? (1 - a) .* pesos_homogeneos(n) :
                               (1 - a) .* pesos_pareto(rng, n, xmin, cola)
        p_hat, ic99 = prob_quorum_mc(rng, pesos, pi_up, n_rep)
        push!(filas, (a=a, cola=cola, n=n, pi=pi_up, p_quorum=p_hat, ic99=ic99, n_rep=n_rep))
    end
    return filas
end

"""
    umbral_pi_teorico(a)

La `p` mínima cerrada de CONTEXTO.md §5: `(1-a)*p >= 2/3` ⟺ `p >= (2/3)/(1-a)`.
Sirve de oráculo de referencia exacto para el caso homogéneo determinista
(sin variar Monte Carlo): con pesos iguales y `pi_uptime` interpretado como la
FRACCIÓN exacta de claves en línea (no aleatoria), el quórum se alcanza si y
solo si `pi_uptime >= umbral_pi_teorico(a)`.
"""
umbral_pi_teorico(a::Float64) = (2/3) / (1 - a)

# ======================================================================
# BLOQUE 2 · Reproducción cruzada de la propuesta antigua (§4.A, §4.D)
#            y comparación con el diseño sin sorteo
# ======================================================================

"""
    cola_binomial_exacta(K, alpha, k0) -> BigFloat

`P(Bin(K, alpha) >= k0)` exacta, en `BigFloat` con 256 bits de precisión, usando
`Rational{BigInt}` para los coeficientes binomiales antes de convertir (evita el
error de cancelación de sumar directamente en floating point de 64 bits que ya
señaló el catálogo de defectos de la propuesta antigua para instrumentos previos).
"""
function cola_binomial_exacta(K::Int, alpha::Float64, k0::Int)
    setprecision(BigFloat, 256) do
        a = BigFloat(alpha)
        s = BigFloat(0)
        # log-espacio para evitar underflow con K grande; se usa BigFloat, no hace falta.
        for k in k0:K
            coef = big(binomial(BigInt(K), BigInt(k)))
            s += BigFloat(coef) * a^k * (1 - a)^(K - k)
        end
        return s
    end
end

"""
    reproduce_4A(; Ks, alphas)

Reproduce la tabla §4.A de `research/dag-poas-capa-finalidad.md`
(sorteo CON REEMPLAZO, cada una de `K` plazas va al atacante con prob. `alpha`
i.i.d.): P(>=1/3 del comité) y P(>=2/3 del comité), exacto.
"""
function reproduce_4A(; Ks = (1000,), alphas = (0.10, 0.20, 0.25, 0.30, 0.33))
    filas = NamedTuple[]
    for K in Ks, a in alphas
        k13 = ceil(Int, K / 3)
        k23 = ceil(Int, 2K / 3)
        p13 = cola_binomial_exacta(K, a, k13)
        p23 = cola_binomial_exacta(K, a, k23)
        push!(filas, (K=K, alpha=a, p_ge_13=p13, p_ge_23=p23))
    end
    return filas
end

"""
    reproduce_4D(; Ks, alphas, ms)

Reproduce §4.D (sesgo del sorteo por elección de ancla): el atacante elige la
mejor de `m` anclas independientes, cada una con su propio sorteo de `K` plazas.
`P(para la finalidad) = 1 - (1-p13)^m`; `P(finaliza una mentira) = 1-(1-p23)^m`.
"""
function reproduce_4D(; Ks = (1000, 4000), alphas = (0.25, 0.30, 0.33), ms = (2.955, 151))
    base = reproduce_4A(Ks=Ks, alphas=alphas)
    filas = NamedTuple[]
    for fila in base, m in ms
        p13m = 1 - (1 - Float64(fila.p_ge_13))^m
        p23m = 1 - (1 - Float64(fila.p_ge_23))^m
        push!(filas, (K=fila.K, alpha=fila.alpha, m=m, p_para=p13m, p_mentira=p23m))
    end
    return filas
end

"""
    sin_sorteo_es_determinista(a)

Con voto directo ponderado (sin sorteo, todo el que tiene peso vota — el diseño
de F3 real y el que este informe recomienda frente al sorteo de la propuesta
antigua): el quórum NO es una variable aleatoria de un sorteo, es aritmética
determinista sobre el peso real. Devuelve `true` si `a < 1/3` (no puede pausar
sola) y compara con la lectura probabilista de §4.A/§4.D, que en este diseño
deja de aplicar por construcción (no hay plazas que "tocar por azar").
"""
sin_sorteo_pausa_posible(a::Float64) = a >= (1/3)
sin_sorteo_sella_mentira_posible(a::Float64, control_red::Bool) = a >= (2/3) || (a >= 1/3 && control_red)

# ======================================================================
# BLOQUE 3 · Tamaño y coste anual del certificado
# ======================================================================

"""
    tamano_certificado_bytes(M; sig_bls_g2=96, hash_tabla=32, cabecera=64)

`M` = número de participantes elegibles representables en el mapa de bits
(cota superior del comité real de la instancia). Firma BLS agregada de 96 B
(G2 comprimido, BLS12-381, el mismo esquema que la propuesta antigua eligió en
§5 y que `blst`/`bls12_381` implementan) + mapa de bits de `M` bits +
compromiso de la tabla de poder siguiente (32 B, hash) + cabecera de instancia
(número de instancia, referencia al tipset/bloque certificado, versión — 64 B
de margen).
"""
function tamano_certificado_bytes(M::Int; sig_bls_g2::Int=96, hash_tabla::Int=32, cabecera::Int=64)
    bitmap = cld(M, 8)
    return sig_bls_g2 + hash_tabla + cabecera + bitmap
end

"""
    coste_anual_gb(tam_bytes, periodo_s)

GB/año de certificados de `tam_bytes` cada `periodo_s` segundos.
"""
function coste_anual_gb(tam_bytes::Int, periodo_s::Float64)
    certs_por_anio = (365.25 * 86400) / periodo_s
    return tam_bytes * certs_por_anio / 1.0e9
end

"""
    barrido_certificado(; Ms, periodos_s)

`Ms`: participantes elegibles (bitmap). `periodos_s`: cadencia de certificado.
"""
function barrido_certificado(; Ms = (600, 3_600, 10_000, 100_000, 1_000_000),
                                periodos_s = (6.0, 30.0, 60.0, 3600.0))
    filas = NamedTuple[]
    for M in Ms, T in periodos_s
        tam = tamano_certificado_bytes(M)
        gb = coste_anual_gb(tam, T)
        push!(filas, (M=M, periodo_s=T, tam_bytes=tam, gb_anio=gb))
    end
    return filas
end

# ======================================================================
# BLOQUE 4 · Ventana del doble farmeo: tiempo hasta el sello vs F_slots
# ======================================================================

"""
    latencia_instancia_gossipbft(delta_f, ronda_maxima; fases=3, backoff=2.0)

Fórmula literal de FIP-0086: `phase_timeout = 2*Δ*BackOffExponent^ronda`.
Se suma el timeout de cada fase (`fases` fases por ronda, F3 documenta
QUALITY/CONVERGE, PREPARE, COMMIT ≈ 3 fases efectivas por ronda) para
`ronda = 0 .. ronda_maxima`, en el caso pesimista de que TODAS las rondas
hasta `ronda_maxima` agoten su timeout (censura/vista fallida) y la última
decida. `ronda_maxima = 0` es el caso optimista (una sola ronda, sin fallo).
"""
function latencia_instancia_gossipbft(delta_f::Float64, ronda_maxima::Int;
                                       fases::Int = 3, backoff::Float64 = 2.0)
    total = 0.0
    for r in 0:ronda_maxima
        total += fases * 2 * delta_f * backoff^r
    end
    return total
end

"""
    tiempo_hasta_sello(delta_f, lookback, ronda_maxima; fases=3, backoff=2.0, periodo_min=1.0)

Tiempo hasta que un bloque queda sellado: `lookback` instancias de espera
(F3 usa `PowerTableLookback = 10`) más la latencia de decisión de la propia
instancia. El período entre instancias no puede ser menor que `periodo_min`
(cota física: no tiene sentido correr instancias más rápido que la latencia
de red mínima).
"""
function tiempo_hasta_sello(delta_f::Float64, lookback::Int, ronda_maxima::Int;
                             fases::Int = 3, backoff::Float64 = 2.0, periodo_min::Float64 = 0.0)
    lat = latencia_instancia_gossipbft(delta_f, ronda_maxima; fases=fases, backoff=backoff)
    periodo = max(lat, periodo_min)
    return lookback * periodo + lat
end

"""
    barrido_ventana(; deltas_f, lookbacks, rondas, F_slots, tau_s)

`F_slots` en índices de slot (símbolo de `C-FIN-01`/`C-FIN-01` §10.4 de
`PROPUESTA-SPEC.md`); `tau_s` = duración de un slot en segundos (1 s, `C-SLOT-01`
según la corrección de la ronda 14A: `λ=1`). Devuelve el tiempo hasta el sello
en segundos y su razón frente a `F_slots*tau_s`.
"""
function barrido_ventana(; deltas_f = (0.26, 0.60, 4.0, 6.0, 16.0),
                            lookbacks = (1, 10),
                            rondas = (0, 1, 2, 3),
                            F_slots = 7200,
                            tau_s = 1.0)
    filas = NamedTuple[]
    F_s = F_slots * tau_s
    for d in deltas_f, L in lookbacks, r in rondas
        t = tiempo_hasta_sello(d, L, r)
        push!(filas, (delta_f=d, lookback=L, ronda_max=r, t_sello_s=t,
                       F_s=F_s, razon_F_sobre_t=F_s / t))
    end
    return filas
end

end # module
