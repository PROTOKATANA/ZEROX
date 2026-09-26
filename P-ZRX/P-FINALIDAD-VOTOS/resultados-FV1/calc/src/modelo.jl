module ModeloFV1

using SpecialFunctions: loggamma

export q_atacante, frac_honesto_firmable, frac_total_firmable, p_necesaria,
       a_pausa, a_rompe, log_pmf_binom, sf_binom, cdf_binom,
       p_para_al_menos, p_finaliza_mentira, k_minimo,
       peso_elegible, tiempo_esperado_sello, coste_certificado_bytes

# ---------------------------------------------------------------------------
# 1. Modelo cerrado del sorteo con prima b (decision 6 de Katana)
# ---------------------------------------------------------------------------
#
# Cada uno de los K asientos se sortea con probabilidad proporcional al peso
# efectivo de cada registrado:
#   - atacante: siempre "encendido" (supuesto declarado del director), peso
#     efectivo a*b (por unidad de peso total = 1).
#   - honesto encendido (fraccion p del peso honesto (1-a)): peso efectivo
#     (1-a)*p*b.
#   - honesto apagado/censurado (fraccion (1-p)): peso efectivo (1-a)*(1-p)*1
#     (sin prima).
#
# q_atacante(a,b,p)      = fraccion ESPERADA de los K asientos que caen en el
#                          atacante.
# frac_honesto_firmable  = fraccion ESPERADA de asientos que caen en un
#                          honesto encendido (los unicos honestos que pueden
#                          firmar el asiento que les toco).
#
# Verificado contra CONTEXTO.md §3.6 (tabla a=0,25) y contra ORDEN-FV1 §3.6:
#   b=1            -> q_atacante = a  (no hay distorsion)
#   b->inf         -> q_atacante -> a*b/(a*b+(1-a)*p*b) = a/(a+(1-a)p)
#   p=0 (censura)  -> q_atacante = a*b/(a*b+1-a)          (techo del director)

peso_total_efectivo(a, b, p) = a*b + (1-a)*(1 + p*(b-1))

q_atacante(a, b, p) = (a*b) / peso_total_efectivo(a, b, p)

frac_honesto_firmable(a, b, p) = ((1-a)*p*b) / peso_total_efectivo(a, b, p)

# Si el atacante decide firmar lo honesto (no ataca esa ronda), la fraccion
# total firmable es la suma; sirve como referencia de "caso benigno".
frac_total_firmable(a, b, p) = q_atacante(a, b, p) + frac_honesto_firmable(a, b, p)

# p minima (participacion honesta REAL, es decir sin censura activa: el
# atacante no censura, solo esta siempre encendido) para alcanzar 2/3 de
# asientos firmables SIN la ayuda del atacante.
# Derivacion algebraica en el INFORME (reproduce b=1 -> (2/3)/(1-a);
# b->inf -> 2a/(1-a), las dos citadas literalmente en CONTEXTO.md/ORDEN).
p_necesaria(a, b) = 2*(a*b + 1 - a) / ((1-a)*(b+2))

# Umbral de peso `a` a partir del cual el atacante alcanza, EN ESPERANZA Y
# BAJO CENSURA TOTAL de las pruebas honestas (p=0), una fraccion >= 1/3 de
# los asientos (pausa) o >= 2/3 (rompe el sello). Ambos resueltos de
# q_atacante(a,b,0) = a*b/(a*b+1-a) = umbral.
a_pausa(b) = 1 / (2*b + 1)     # q_atacante(a,b,0) = 1/3
a_rompe(b) = 2 / (b + 2)       # q_atacante(a,b,0) = 2/3

# Peso "elegible" (con prueba de disponibilidad vigente, incluido el
# atacante que siempre la tiene por supuesto del modelo) sobre el peso TOTAL
# registrado. Es el candidato a suelo E de la decision 6 / CONTEXTO §3.5.
peso_elegible(a, p) = a + (1-a)*p

# ---------------------------------------------------------------------------
# 2. Cola binomial exacta (sustituye scipy.stats.binom.sf de los .py
#    historicos; NUNCA se ejecutan, solo se leen como referencia, V-ZRX/LINEO.md).
# ---------------------------------------------------------------------------

log_pmf_binom(k::Integer, n::Integer, p::Float64) =
    loggamma(n+1) - loggamma(k+1) - loggamma(n-k+1) + k*log(p) + (n-k)*log1p(-p)

"""
    sf_binom(k0, n, p)

P(X >= k0) para X ~ Binomial(n,p), sumando la pmf en escala natural desde k0
hasta n. Exacto en Float64 hasta ~1e-300; por debajo satura a 0.0 y se
etiqueta como tal (no se imita la extension de scipy a exponentes de miles
de digitos: no hace falta para las conclusiones cualitativas de este informe).
"""
function sf_binom(k0::Integer, n::Integer, p::Float64)
    p <= 0.0 && return k0 <= 0 ? 1.0 : 0.0
    p >= 1.0 && return 1.0
    k0 <= 0 && return 1.0
    k0 > n && return 0.0
    s = 0.0
    @inbounds for k in k0:n
        lp = log_pmf_binom(k, n, p)
        s += lp > -700.0 ? exp(lp) : 0.0
    end
    return min(s, 1.0)
end

cdf_binom(k::Integer, n::Integer, p::Float64) = 1.0 - sf_binom(k+1, n, p)

"P(>= frac*K asientos), K entero de plazas"
p_para_al_menos(alpha_efectiva::Float64, K::Integer, frac::Float64) =
    sf_binom(Int(ceil(frac*K)), K, alpha_efectiva)

"P(sesgo del sorteo por eleccion de m anclas): 1-(1-p)^m"
function p_finaliza_mentira(p::Float64, m::Real)
    m_int = max(1, Int(ceil(m)))
    p < 1e-12 && return min(1.0, p*m_int)
    return 1 - (1-p)^m_int
end

"K minimo tal que p_para_al_menos(alpha_ef,K,frac) < tol, busqueda simple"
function k_minimo(alpha_efectiva::Float64, frac::Float64, tol::Float64; kmax=200_000, paso=10)
    for K in 50:paso:kmax
        if p_para_al_menos(alpha_efectiva, K, frac) < tol
            return K
        end
    end
    return nothing
end

# ---------------------------------------------------------------------------
# 3. Certificado: tamano en bytes (Ed25519 vigente en ZEROX vs BLS agregada)
# ---------------------------------------------------------------------------
const ED_SIG, ED_IDX = 64, 2
const BLS_SIG_AGG = 96
const CERT_META = 96   # instancia, hash de bloque, hash tabla de pesos siguiente (C-BON-07-like)

function coste_certificado_bytes(K::Integer; esquema::Symbol=:ed25519)
    if esquema == :ed25519
        return CERT_META + K*(ED_SIG + ED_IDX)
    elseif esquema == :bls
        return CERT_META + BLS_SIG_AGG + cld(K, 8)
    else
        error("esquema desconocido")
    end
end

# ---------------------------------------------------------------------------
# 4. Ventana del doble farmeo: tiempo esperado hasta el sello
# ---------------------------------------------------------------------------
#
# Modelo minimo (GossiPBFT-like, F3): cada ronda de finalidad dura
# T_round = c_fases * Delta (c_fases fases de intercambio de mensajes; F3
# declara 2 fases + difusion del certificado, aqui se deja simbolico).
# Si la ronda no alcanza 2/3 de asientos firmantes (evento con probabilidad
# 1 - p_sella), se reintenta con un nuevo sorteo (nueva entropia) en la
# ronda siguiente. Tiempo esperado = T_round / p_sella (geometrica).
function tiempo_esperado_sello(p_sella::Float64, T_round_slots::Float64)
    p_sella <= 0.0 && return Inf
    return T_round_slots / p_sella
end

end # module
