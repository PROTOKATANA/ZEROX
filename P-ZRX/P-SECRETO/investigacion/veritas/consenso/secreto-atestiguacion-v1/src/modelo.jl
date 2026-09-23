# modelo.jl — tipos y fórmulas exactas del modelo de atestiguación por sorteo
# P-ZRX/P-SECRETO/investigacion/veritas/consenso/secreto-atestiguacion-v1
#
# Convención de unidades: α, β_d, β_x son fracciones de ESPACIO (normalizado a 1),
# como en P-ZRX/P-PRESTAMO/ §1. τ, Δ, latencias en segundos. Slots enteros.
# Ningún parámetro de consenso se fija aquí: todo entra por argumento o aparece
# como columna de la rejilla.
#
# Supuestos declarados (HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md):
#   S1. El sorteo ponderado por espacio exige una tabla de poder derivada (no hay
#       registro en PoST); el modelo supone la ponderación fiel por espacio real.
#   S2. Dos regímenes de firmante: V1 (firma lo que le pidan, p. ej. un hash a
#       ciegas) y V2 (firma solo bloques que ha visto enteros y validado).
#       La infalsificabilidad de la atestiguación depende de V2, y V2 NO es
#       verificable como condición de validez.
#   S3. El sorteo del slot se deriva de salida(f, s) (C-POT-02) y no es grindable
#       mientras el flujo sea el honesto; con partición de flujo (C-FLU-22) el
#       atacante puede re-elegir ancla → sorteo (steering, D8 de la capa de comité).
#   S4. Reto (C-POT-03) y sorteo se tratan como independientes (funciones de hash
#       distintas de la misma salida del PoT).

const RB = Rational{BigInt}

# ---------------------------------------------------------------------------
# Muestreo (declarado): k plazas por slot, CON reemplazo, ponderadas por espacio:
# cada plaza i ∈ [1..k] se asigna independientemente a una clave con probabilidad
# igual a su fracción de espacio. El teorema de identidad
# (research/dag-poas-balizas-auditoria.md §2) permite al atacante partir su espacio
# en claves gratis, con lo que su captura sin reemplazo tiende a α^k por debajo:
# α^k es la cota alcanzable.
# ---------------------------------------------------------------------------

"""P(los k sorteados son todos del atacante), con reemplazo: exacto."""
function captura_reemplazo(α::RB, k::Int)::RB
    return α^k
end

"""P(captura) sin reemplazo, atacante partido en M nodos iguales (peso α/M cada uno).
Exacto: producto secuencial de pesos restantes. M < k ⇒ 0 (un nodo solo se puede
sortear una vez). Con M → ∞ tiende a α^k por debajo."""
function captura_sin_reemplazo(α::RB, M::Int, k::Int)::RB
    M ≥ 1 || throw(ArgumentError("M ≥ 1"))
    k ≥ 0 || throw(ArgumentError("k ≥ 0"))
    M ≥ k || return RB(0)
    p = RB(1)
    wA = α // M
    for i in 0:(k-1)
        num = α - i * wA
        den = RB(1) - i * wA
        num > 0 || return RB(0)
        p *= num // den
    end
    return p
end

"""P(capturar la cadena de d bloques). Dos factores, con S4 (independencia reto/sorteo):
   (a) el atacante debe GANAR el reto PoST de cada uno de los d slots: α^d;
   (b) en cada slot ganado, los k sorteados deben ser suyos: α^k.
   Total: α^((k+1)·d)."""
function captura_cadena(α::RB, k::Int, d::Int)::RB
    return α^((k + 1) * d)
end

"""Variante sin el factor del reto (solo el sorteo): α^(k·d). Se publica como
comparación y para exhibir que el factor del reto refuerza la conclusión."""
function captura_cadena_sin_reto(α::RB, k::Int, d::Int)::RB
    return α^(k * d)
end

"""Fracción de bloques honestos que completan su ronda de k firmas.
Cada plaza cae en un nodo honesto con prob. (1−α) y ese nodo responde con
prob. p_disponible (encendido + no censurado). El atacante NUNCA firma bloques
honestos (abstención gratis, sin evidencia: silencio). Con reemplazo las plazas
son independientes: P(las k responden) = ((1−α)·p)^k. Exacto."""
function fraccion_produce(α::RB, p_disponible::RB, k::Int)::RB
    return ((RB(1) - α) * p_disponible)^k
end

"""Impuesto de abstención puro: p_disponible = 1. Un atacante con fracción α de
espacio corta la producción honesta a (1−α)^k sin coste y sin dejar evidencia."""
function abstención(α::RB, k::Int)::RB
    return (RB(1) - α)^k
end

"""Modelo de NODOS (disponibilidad por nodo, correlacionada entre plazas): h nodos
honestos de igual peso; cada uno responde con prob. p de forma independiente;
r nodos responden ⇒ la plaza cae en respondedor con prob. r/h.
P = (1−α)^k · Σ_r C(h,r) p^r (1−p)^{h−r} (r/h)^k.
Con h → ∞ tiende a fraccion_produce (continuo, plazas independientes).
Por Jensen (convexidad de x^k), este modelo da producción ≥ la del continuo:
fraccion_produce es la cota CONSERVADORA (pesimista) para la viveza."""
function fraccion_produce_nodos(α::RB, p::RB, k::Int, h::Int)::RB
    s = RB(0)
    for r in 0:h
        binom = binomial(h, r)
        s += binom * p^r * (RB(1) - p)^(h - r) * (RB(r) // h)^k
    end
    return (RB(1) - α)^k * s
end

"""Partición de red: el corte deja la fracción x del peso de un lado y (1−x) del otro.
En cada slot hay que sortear TAMBIÉN al productor (gana el reto PoST: con S4,
independiente de las plazas, cae en cada lado con prob. x / 1−x). Un lado produce
si y solo si el productor Y las k plazas caen todos de ese lado:
P(lado A produce) = x^(k+1). Ambos lados paran si ningún lado completa:
P(paro total) = 1 − x^(k+1) − (1−x)^(k+1). Exacto."""
function paro_particion(x::RB, k::Int)::RB
    return RB(1) - x^(k + 1) - (RB(1) - x)^(k + 1)
end

"""P(la rama privada de d bloques no filtra nada). Cada una de las k·d plazas
independientes cae: en el atacante (prob. α, sin fuga); en un honesto silencioso
(prob. (1−α)·p_sil); en un honesto que filtra (prob. (1−α)·(1−p_sil)).
P(ninguna fuga) = (α + (1−α)·p_sil)^(k·d). Función generatriz, exacta.
   p_sil = 1 ⇒ 1 (todo el mundo calla: secreto intacto, y nadie queda para parar
   la cadena honesta — es la corrupción total); p_sil = 0 ⇒ α^(k·d) (coincide con
   la captura del sorteo: solo sobrevive si todo el sorteo cae del lado atacante)."""
function p_no_fuga_exacta(α::RB, p_sil::RB, k::Int, d::Int)::RB
    return (α + (RB(1) - α) * p_sil)^(k * d)
end

# ---------------------------------------------------------------------------
# Superficie α* (P-ZRX/P-PRESTAMO F1, demostrado). Control de este instrumento.
#   g = η_a(α+β_d+β_x) − η_h((1−α)−β_x)
#   α*(β_d, β_x, η_h, η_a) = (η_h − η_a·β_d − (η_h+η_a)·β_x)/(η_h+η_a)
# La atestiguación NO mueve esta identidad (es una identidad de tasas): lo que
# hace es cerrar el canal secreto que hace usables β_d/β_x (F4 del INFORME).
# ---------------------------------------------------------------------------

"""Deriva g en α (tasas de peso por unidad de tiempo)."""
function deriva(α::RB, β_d::RB, β_x::RB, η_h::RB, η_a::RB)::RB
    return η_a * (α + β_d + β_x) - η_h * ((RB(1) - α) - β_x)
end

"""Frontera α* donde g = 0."""
function alpha_estrella(β_d::RB, β_x::RB, η_h::RB, η_a::RB)::RB
    return (η_h - η_a * β_d - (η_h + η_a) * β_x) // (η_h + η_a)
end

"""Con η = 1: α* = (1 − β_d − 2β_x)/2. β_x baja el umbral el DOBLE que β_d."""
function alpha_estrella_uno(β_d::RB, β_x::RB)::RB
    return (RB(1) - β_d - 2 * β_x) // 2
end

# ---------------------------------------------------------------------------
# Coste en cabecera y red (F3). Q2: cabecera típica ≤ ~1 kB (PROMPT §4.2).
#   Ed25519: 32 B clave pública + 64 B firma por firmante → 96·k B.
#   BLS12-381 agregada: 96 B firma agregada + ⌈k/8⌉ B de mapa de bits.
#   A λ = 1 bloque/s: 31_536_000 bloques/año.
# ---------------------------------------------------------------------------

const SLOTS_ANUALES = 31_536_000
const BYTES_ED25519_POR_FIRMANTE = 96
const BYTES_BLS_AGREGADA = 96
const PRESUPUESTO_Q2_CABECERA = 1024  # ~1 kB, presupuesto típico declarado en PROMPT §4.2

"""Bytes de atestiguación en cabecera, esquema Ed25519 (firma por plaza)."""
function bytes_cabecera_ed25519(k::Int)::Int
    return k * BYTES_ED25519_POR_FIRMANTE
end

"""Bytes de atestiguación, esquema BLS agregada + mapa de bits."""
function bytes_cabecera_bls(k::Int)::Int
    return BYTES_BLS_AGREGADA + cld(k, 8)
end

"""Coste anual de relé a λ = 1 bloque/s."""
function bytes_anuales(bytes_por_bloque::Int)::Int
    return SLOTS_ANUALES * bytes_por_bloque
end

# ---------------------------------------------------------------------------
# Control ejecutable de F1 (§4.1 del PROMPT): clasificación de condiciones en
# «falsificable en rama privada» frente a «infalsificable».
# Modelo mínimo: una rama es una lista de bloques; cada bloque tiene slot, clave
# productora, lista de compromisos, lista de referencias y lista de firmas recibidas.
# Regímenes de firmante (S2):
#   V1 (firma a ciegas): el firmante firma el pre_hash que le presentan sin ver el
#       bloque. La condición de atestiguación ES satisfacible en rama privada.
#   V2 (firma lo visto): el firmante firma solo bloques que ha visto enteros y
#       validado. Satisfacer la condición exige revelar el bloque a los firmantes,
#       es decir, la rama sale de la custodia del atacante. V2 no es verificable
#       como condición de validez: una firma no prueba que el firmante vio el bloque.
# ---------------------------------------------------------------------------

struct BloqueF1
    slot::Int
    clave::Int          # clave del productor
    compromisos::Vector{Int}
    referencias::Vector{Int}
    firmas::Vector{Int} # claves que firmaron este bloque
end

"""Condición 1 (control): compromiso previo de intención — satisfacible en rama privada."""
function cumple_compromiso_previo(past::Vector{BloqueF1}, compromiso::Int)::Bool
    return any(b -> compromiso in b.compromisos, past)
end

"""Condición 2 (control): historial reciente de clave — satisfacible en rama privada."""
function cumple_historial_reciente(past::Vector{BloqueF1}, clave::Int, ventana::Int)::Bool
    isempty(past) && return false
    ultimo = maximum(b -> b.slot, past)
    return any(b -> b.clave == clave && b.slot ≥ ultimo - ventana, past)
end

"""Condición 3 (control): referencia a datos públicos — satisfacible en rama privada
(ver lo público no obliga a publicar: el atacante referencia el bloque público y su
rama privada sigue siendo privada)."""
function cumple_referencia_publica(past::Vector{BloqueF1}, bloque_publico::Int)::Bool
    return any(b -> bloque_publico in b.referencias, past)
end

"""Condición candidata: atestiguación por sorteo. La condición formal es
«B.firmas ⊇ sorteados». Bajo V1 el atacante la satisface pidiendo firmas de claves
ajenas (que firman sin ver): falsificable en rama privada. Bajo V2 la satisfacción
exige que los firmantes hayan visto el bloque: la rama sale de la custodia del
atacante. El verificador solo ve la firma, no el régimen: la condición por sí sola
NO fuerza la publicación."""
function cumple_atestiguacion(B::BloqueF1, sorteados::Vector{Int})::Bool
    return all(c -> c in B.firmas, sorteados)
end

"""V1: el atacante puede obtener firmas de claves ajenas a la carta (firma de un
pre_hash presentado, sin ver el bloque). La condición de atestiguación queda
satisfacible en rama privada sin publicar nada."""
function firmas_obtenibles_v1(B::BloqueF1, sorteados::Vector{Int})::Vector{Int}
    return sorteados
end

"""V2: un firmante firma solo bloques vistos. El conjunto de claves que han visto el
bloque es exactamente el de firmas del bloque: satisfacer la condición implica que
el bloque fue visto por cada clave sorteada ajena. V2 es política del firmante, no
condición de validez (el verificador no puede distinguir una firma V1 de una V2)."""
function revelado_a_firmantes_v2(B::BloqueF1, sorteados::Vector{Int})::Bool
    return all(c -> c in B.firmas, sorteados)
end

"""Constructor de rama privada del atacante: solo entradas que el atacante produce.
Demuestra que las condiciones 1-3 se satisfacen sin cooperación honesta."""
function rama_privada_atacante(clave_atacante::Int, d::Int, bloque_publico::Int, compromiso::Int)::Vector{BloqueF1}
    return [BloqueF1(100 + i, clave_atacante, [compromiso], [bloque_publico], [clave_atacante]) for i in 1:d]
end
