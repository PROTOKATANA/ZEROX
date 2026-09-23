# Modelo del puente `bytes → sectores → piezas → chunks auditados/slot → candidatos → pruebas
# → bloques admisibles → bloques azules → blue_work/slot`, y capa estadística.
#
# Cada magnitud se registra como una `Cifra` con valor, unidad, variable, denominador, versión del
# modelo, fuente, adversario, escenario, criterio de aceptación y estado. Es la exigencia del
# encargo §5 y de `AGENTS.md`: una cifra sin esas nueve etiquetas no se publica.

using Statistics: mean, var, std, quantile, cor
using Distributions: Beta, Poisson, cdf
using Random: rand
using StableRNGs: StableRNG

const VERSION_MODELO = "espacio-tasa-v1"

"""
    Estado

Estados admitidos por el encargo. No se inventan etiquetas nuevas y **no** se usa «medido» para
algo que solo se derivó de una fórmula.
"""
@enum Estado begin
    medido
    derivado
    simulado
    condicionado
    pendiente
end

"""
    Cifra

Una cifra publicable. `denominador` es obligatorio: el encargo prohíbe confundir conteos con tasas
y segundos con slots.
"""
struct Cifra
    variable::String
    valor::Any
    unidad::String
    denominador::String
    fuente::String
    adversario::String
    escenario::String
    criterio::String
    estado::Estado
end

"""Formatea el valor sin perder exactitud cuando es un entero grande o un racional."""
function _valor_txt(v)
    if v isa Rational
        return string(numerator(v), "/", denominator(v), " = ", Float64(v))
    elseif v isa BigInt
        return string(v)
    elseif v isa AbstractFloat
        return string(v)
    else
        return string(v)
    end
end

"""Cabecera del TSV de cifras, en el orden del encargo §5."""
const CABECERA_CIFRAS = join([
    "variable", "valor", "unidad", "denominador", "version_modelo", "fuente",
    "adversario", "escenario", "criterio_aceptacion", "estado",
], '\t')

function escribir_cifras(io::IO, cifras::AbstractVector{Cifra})
    println(io, CABECERA_CIFRAS)
    for c in cifras
        println(io, join([
            c.variable, replace(_valor_txt(c.valor), '\t' => ' '), c.unidad, c.denominador,
            VERSION_MODELO, c.fuente, c.adversario, c.escenario, c.criterio, string(c.estado),
        ], '\t'))
    end
end

# ---------------------------------------------------------------------------------------------
# Etapas del puente
# ---------------------------------------------------------------------------------------------

"""
    puente(piezas; ocupacion_media=1//2, SR, pi_validez, pi_admision, beta) -> NamedTuple

Recorre las etapas **aritméticas** del puente para `piezas` piezas efectivas de un flujo.

* `chunks_auditados = piezas · o`, con `o = NUM_CHUNKS/NUM_S_BUCKETS = 1/2`. **Exacto** en la
  media, porque `create_proofs` produce siempre `NUM_CHUNKS` pruebas sobre `NUM_S_BUCKETS` buckets.
  Que la **media** sea exacta no dice nada de la distribución: ver `INFORME.md` §3.
* `candidatos = chunks_auditados · A(SR)/2^64`, con `A(SR) = 2·(SR÷2)+1`. Es el número esperado de
  chunks que superan el **predicado de espacio**.
* `peso_por_bloque = ⌊2^128/(SR+1)⌋`.
* `trabajo_azul = candidatos · π_validez · π_admision · β · peso_por_bloque`, y vale `nothing`
  mientras **cualquiera** de los tres factores sea `nothing`.

**Los tres factores desconocidos se mantienen separados y explícitos**; ninguno se absorbe en `β`:

| Factor | Qué es | Estado |
|---|---|---|
| `π_validez` | probabilidad de que un candidato supere la **verificación PoAS completa** (`verify_solution`: compromiso de registro, testigo KZG, firma, y el resto de `C-HDR-06`) | `pendiente` |
| `π_admision` | probabilidad de que un bloque pase la **admisión PoST + DAG** | `pendiente` |
| `β` | fracción **azul** de los bloques admitidos (`blue_work` suma solo azules, `SPEC.md` C-GD-08) | `pendiente` |

Poner los tres a `1` es el **límite favorable al adversario**; se ofrece como función aparte
(`rendimiento_limite_adversario`) y se etiqueta `condicionado`, nunca `medido`.
"""
function puente(piezas::Integer; ocupacion_media::Rational=Rational{BigInt}(1, 2),
                SR::Integer,
                pi_validez::Union{Nothing,Rational{BigInt}}=nothing,
                pi_admision::Union{Nothing,Rational{BigInt}}=nothing,
                beta::Union{Nothing,Rational{BigInt}}=nothing)
    P = big(piezas) * ocupacion_media
    p = prob_billete(SR)
    candidatos = P * p
    w = peso_bloque(SR)
    if pi_validez === nothing || pi_admision === nothing || beta === nothing
        trabajo = nothing
    else
        trabajo = candidatos * pi_validez * pi_admision * beta * w
    end
    return (chunks_auditados=P, prob_billete=p, candidatos=candidatos,
            peso_por_bloque=w, razon_cancelacion=razon_cancelacion(SR),
            trabajo_azul=trabajo,
            pi_validez=pi_validez, pi_admision=pi_admision, beta=beta)
end

"""
    rendimiento_limite_adversario(piezas; SR, beta=1//1) -> NamedTuple

Igual que [`puente`](@ref) con `π_validez = π_admision = 1` y la `β` que se declare. Es el
**límite favorable al adversario** y toda cifra que salga de aquí es `condicionado`, nunca
`medido`: supone que ningún candidato se pierde por verificación ni por admisión.
"""
function rendimiento_limite_adversario(piezas::Integer; SR::Integer,
                                       beta::Rational{BigInt}=big(1)//big(1))
    return puente(piezas; SR=SR, pi_validez=big(1)//big(1), pi_admision=big(1)//big(1),
                  beta=beta)
end

# ---------------------------------------------------------------------------------------------
# Fracciones: bytes nominales, piezas efectivas, candidatos y trabajo azul
# ---------------------------------------------------------------------------------------------

"""
    RepartoBytes

Separa las magnitudes que **no** son la misma cosa al traducir una capacidad declarada a piezas.
Es donde se cometió el error de llamar «fracción de bytes» a una razón de piezas.

* `bytes_solicitados`: lo que el granjero declara tener.
* `sectores_completos`: `⌊bytes_solicitados / sector_size(piezas_por_sector)⌋`. El formato fija
  `pieces_in_sector`, así que un sector incompleto **no** es un sector.
* `bytes_sectores_completos`: `sectores_completos · sector_size(piezas_por_sector)`.
* `bytes_sobrantes`: `bytes_solicitados − bytes_sectores_completos`. **No** son piezas.
* `piezas_efectivas`: `sectores_completos · piezas_por_sector`. Son las que pueden auditarse.
* `bytes_materializados`: lo que el instrumento **realmente** escribió en disco. En este
  instrumento vale lo que ocupan los artefactos (mapas de presencia), **no** los bytes nominales.
"""
struct RepartoBytes
    bytes_solicitados::BigInt
    piezas_por_sector::BigInt
    sectores_completos::BigInt
    bytes_sectores_completos::BigInt
    bytes_sobrantes::BigInt
    piezas_efectivas::BigInt
    bytes_materializados::BigInt
end

function reparto_bytes(bytes_solicitados::Integer;
                       piezas_por_sector::Integer=MAX_PIEZAS_POR_SECTOR,
                       bytes_materializados::Integer=0)
    ss = sector_size(piezas_por_sector)
    sectores = big(bytes_solicitados) ÷ ss
    completos = sectores * ss
    return RepartoBytes(big(bytes_solicitados), big(piezas_por_sector), sectores, completos,
                        big(bytes_solicitados) - completos, sectores * big(piezas_por_sector),
                        big(bytes_materializados))
end

"""
    fracciones(ra, rt) -> NamedTuple

Las fracciones **separadas** que el encargo pide. Ninguna se llama «fracción de bytes físicos»:
la tercera es una fracción de **piezas efectivas**, que es una magnitud distinta de la primera
siempre que los sectores no estén completos o los tamaños por pieza difieran.
"""
function fracciones(ra::RepartoBytes, rt::RepartoBytes)
    return (bytes_nominales_solicitados=ra.bytes_solicitados // rt.bytes_solicitados,
            bytes_nominales_completos=ra.bytes_sectores_completos // rt.bytes_sectores_completos,
            piezas_efectivas=ra.piezas_efectivas // rt.piezas_efectivas)
end


# ---------------------------------------------------------------------------------------------
# Dos escenarios de reparto, SEPARADOS
#
# Mezclarlos era el error: `reparto_bytes(bytes_adv)/sector_size` contra `reparto_bytes(bytes_tot)`
# da a cada actor el beneficio de los sobrantes del TOTAL, lo que solo es legítimo si los sectores
# ya están ploteados y se reparten. Si cada actor trae su propio presupuesto, hay que truncar
# **cada uno por separado**.
# ---------------------------------------------------------------------------------------------

"""
    PresupuestoActor

Presupuesto **independiente** de un actor. Todos los truncamientos son suyos y sus sobrantes **no**
se comparten con nadie.

* `sectores = ⌊bytes_solicitados / sector_size(piezas_por_sector)⌋`, calculado **por actor**.
* `bytes_en_sectores = sectores · s`: lo que realmente se convierte en parcelas.
* `sobrantes = bytes_solicitados − bytes_en_sectores`: se pierde, no se agrega.
* `piezas = sectores · piezas_por_sector`.
"""
struct PresupuestoActor
    nombre::String
    bytes_solicitados::BigInt
    sectores::BigInt
    bytes_en_sectores::BigInt
    sobrantes::BigInt
    piezas::BigInt
end

"""
    presupuestos_independientes(actores; piezas_por_sector) -> Vector{PresupuestoActor}

**Escenario 1 (principal).** Cada actor declara su presupuesto y se trunca **por separado**:

    sectores_i = ⌊bytes_i / s⌋      piezas_i = sectores_i · piezas_por_sector

El denominador de candidatos y de la calibración experimental de `SR` es
`Σ piezas_i = (Σ sectores_i) · piezas_por_sector`, **no** `⌊(Σ bytes_i)/s⌋ · piezas_por_sector`.
Los sobrantes de cada actor se pierden en su propio truncamiento.
"""
function presupuestos_independientes(actores::AbstractVector{<:Tuple};
                                     piezas_por_sector::Integer=MAX_PIEZAS_POR_SECTOR)
    s = sector_size(piezas_por_sector)
    out = PresupuestoActor[]
    for (nombre, bytes) in actores
        b = big(bytes)
        sec = b ÷ s
        push!(out, PresupuestoActor(String(nombre), b, sec, sec * s, b - sec * s,
                                    sec * big(piezas_por_sector)))
    end
    return out
end

"""`Σ sectores_i` del escenario 1: el denominador físico real."""
sectores_totales(ps::AbstractVector{PresupuestoActor}) = sum(p.sectores for p in ps; init=big(0))

"""`Σ piezas_i` del escenario 1: el denominador de candidatos y de la calibración de `SR`."""
piezas_totales(ps::AbstractVector{PresupuestoActor}) = sum(p.piezas for p in ps; init=big(0))

"""
    cuota_piezas_escenario1(ps, indice=1) -> Rational{BigInt}

Cuota del actor `indice` en el **escenario 1**: `sectores_i / Σ sectores_j`, calculada **solo** con
los presupuestos independientes. Es el denominador correcto de candidatos y de la calibración de
`SR` en ese escenario.

**Función retirada.** La anterior `fraccion_candidatos_esperada(ra, rt; SR)` mezclaba un
`RepartoBytes` del adversario (truncado por su cuenta) con un `RepartoBytes` del **total** truncado
una sola vez, y derivaba el lado honesto por **resta** del agregado. Eso es exactamente mezclar
presupuestos independientes con sectores agregados: para el mismo `α` daba `10/1040` donde el
escenario 1 da `10/1039`. Se retira en vez de delimitarse, porque su firma invita al error.
"""
function cuota_piezas_escenario1(ps::AbstractVector{PresupuestoActor}, indice::Integer=1)
    S = sectores_totales(ps)
    S == 0 && return nothing
    return ps[indice].sectores // S
end

"""
    fraccion_candidatos_esperada_esc1(ps, indice; SR) -> Rational{BigInt} o `nothing`

Fracción **esperada de candidatos** del actor `indice` en el escenario 1, contando candidatos sobre
los presupuestos independientes (no sobre sectores agregados). Con el mismo `SR` para todos, `p` y
`o` se cancelan y coincide con [`cuota_piezas_escenario1`](@ref): es una **identidad del modelo**,
no una validación experimental.
"""
function fraccion_candidatos_esperada_esc1(ps::AbstractVector{PresupuestoActor},
                                           indice::Integer=1; SR::Integer)
    ca = puente(ps[indice].piezas; SR=SR).candidatos
    ch = sum((puente(p.piezas; SR=SR).candidatos for (j, p) in enumerate(ps)
              if j != indice); init=big(0) // big(1))
    (ca + ch) == 0 && return nothing
    return ca // (ca + ch)
end


"""
    reparto_sobre_plot(bytes_totales, cuotas; piezas_por_sector) -> NamedTuple

**Escenario 2.** Los sectores **ya están ploteados** y se reparten. Aquí sí vale
`S = ⌊bytes_totales/s⌋` una sola vez y luego `⌊S·q_i⌋` para cada cuota `q_i`.

**Advertencia que acompaña a este escenario.** En este reparto, el porcentaje de bytes
**solicitado** por un actor **no** es su presupuesto físico independiente: su cuota es una fracción
de los sectores que ya existen, y el truncamiento lo paga el conjunto, no cada actor. El resto no
asignado (`S − Σ⌊S·q_i⌋`) **no se regala a nadie**: se publica como `resto`.
"""
function reparto_sobre_plot(bytes_totales::Integer, cuotas::AbstractVector{<:Rational};
                            piezas_por_sector::Integer=MAX_PIEZAS_POR_SECTOR)
    s = sector_size(piezas_por_sector)
    S = big(bytes_totales) ÷ s
    asignados = BigInt[S * numerator(q) ÷ denominator(q) for q in cuotas]
    return (sectores_totales=S, asignados=asignados, resto=S - sum(asignados; init=big(0)),
            bytes_totales=big(bytes_totales), sector_size=s)
end

"""
    reparto_igual_exacto(total, n) -> Vector{BigInt}

Reparte `total` entre `n` partes **conservando todos los bytes**: con `total = n·q + r` y
`0 ≤ r < n`, devuelve `r` partes de `q+1` y `n−r` partes de `q`, de modo que `Σ = total`
**exactamente**. Sin esto, `N·⌊T/N⌋ < T` y el escenario agregado se calculaba sobre bytes que se
habían perdido antes de empezar.
"""
function reparto_igual_exacto(total::Integer, n::Integer)
    n >= 1 || throw(ArgumentError("n debe ser >= 1"))
    t = big(total); N = big(n)
    q, r = divrem(t, N)
    return BigInt[j <= r ? q + 1 : q for j in 1:n]
end

"""
    piezas_que_caben(bytes; piezas_max) -> Int

Mayor número de piezas `p ≤ piezas_max` tal que `sector_size(p) ≤ bytes`, o `0` si no cabe ni una
pieza. Es la comprobación que convierte «no cabe un sector de 1000 piezas» en «no cabe **ningún**
sector»: sin ella, la conclusión general es falsa.
"""
function piezas_que_caben(bytes::Integer; piezas_max::Integer=MAX_PIEZAS_POR_SECTOR)
    b = big(bytes)
    b < sector_size(1) && return 0
    p = (b - 2 * CHECKSUM_SIZE) ÷ BYTES_POR_PIEZA_PLOT
    p = min(p, big(piezas_max))
    p = max(p, big(0))
    while p > 0 && sector_size(p) > b
        p -= 1
    end
    return Int(p)
end

"""
    perdida_agregacion(bytes; piezas_por_sector) -> NamedTuple

**Propiedad general:** `Σ ⌊bytes_i/s⌋ ≤ ⌊(Σ bytes_i)/s⌋`. Truncar por separado nunca da más
sectores que truncar el total. `agregado` se calcula **directamente desde la suma** de `bytes`, y
`suma` se publica para que se vea que es el total real y no `N·⌊T/N⌋`.

**Sobre «la pérdida crece con N».** Es **falso en general**: la pérdida **no es monótona** en `N`
(con 1 TiB, `N=7` pierde 4 sectores y `N=10` pierde 0). Lo que sí se puede afirmar es una **cota**:
cada truncamiento pierde menos de un sector, luego `perdidos ≤ N`. Ver [`tabla_identidades`](@ref).
"""
function perdida_agregacion(bytes::AbstractVector{<:Integer};
                            piezas_por_sector::Integer=MAX_PIEZAS_POR_SECTOR)
    s = sector_size(piezas_por_sector)
    total = sum(big.(bytes); init=big(0))
    por_separado = sum(big(b) ÷ s for b in bytes; init=big(0))
    agregado = total ÷ s                      # DIRECTAMENTE desde el total, no desde N*floor(T/N)
    return (suma=total, por_separado=por_separado, agregado=agregado,
            perdidos=agregado - por_separado, sector_size=s)
end

"""
    tabla_identidades(bytes_totales, Ns; piezas_por_sector) -> Vector{NamedTuple}

Repite el **escenario 1** con `N` identidades que se reparten `bytes_totales` conservando **todos**
los bytes ([`reparto_igual_exacto`](@ref), así que `Σ bytes_i = bytes_totales` exactamente) y lo
compara con el **escenario 2**, calculado **directamente** desde el total.

**Hipótesis declarada, no exigencia del formato.** Las columnas `*_esc1_1000` suponen
`piezas_por_sector = 1000`, el **máximo** de `MAX_PIECES_IN_SECTOR`. El formato admite sectores con
**menos** piezas (`SectorMetadata.pieces_in_sector` es un `u16`), así que «no cabe un sector de 1000
piezas» **no** implica «no cabe ningún sector». La columna `piezas_max_que_caben` da el mayor sector
que sí cabe con ese presupuesto, y `sector_si_ajusta_piezas` dice si alguna identidad podría plotear
uno. La conclusión general «N identidades ⇒ espacio efectivo cero» se **retira**: solo vale como
enunciado **condicionado** a la hipótesis de 1000 piezas fijas.
"""
function tabla_identidades(bytes_totales::Integer, Ns::AbstractVector{<:Integer};
                           piezas_por_sector::Integer=MAX_PIEZAS_POR_SECTOR)
    tot = big(bytes_totales)
    s = sector_size(piezas_por_sector)
    filas = NamedTuple[]
    for N in Ns
        partes = reparto_igual_exacto(tot, N)          # Σ partes == tot, exacto
        r = perdida_agregacion(partes; piezas_por_sector=piezas_por_sector)
        b_ident = partes[1]
        pmax = piezas_que_caben(b_ident; piezas_max=piezas_por_sector)
        sin_sector_1000 = count(b -> b ÷ s == 0, partes)
        push!(filas, (N=big(N), bytes_por_identidad=b_ident,
                      bytes_ultima=partes[end], suma_bytes=r.suma,
                      conserva=(r.suma == tot),
                      sectores_esc1_1000=r.por_separado,
                      sectores_agregado=r.agregado, perdidos=r.perdidos,
                      identidades_sin_sector_1000=sin_sector_1000,
                      piezas_max_que_caben=pmax,
                      sector_si_ajusta_piezas=(pmax > 0),
                      fraccion_efectiva_1000=(r.agregado == 0 ? big(0) :
                                             r.por_separado // r.agregado)))
    end
    return filas
end

"""
    cuota_azul(R_adv, R_hon) -> Rational{BigInt} o `nothing`

Cuota **normalizada** del trabajo azul del adversario: `R_adv / (R_adv + R_hon)`.

Si el denominador es **cero** la cuota **no está definida** y se devuelve `nothing`; no se
devuelve `0`, `1` ni `NaN` con una etiqueta que finja un valor. Denominador cero ocurre, por
ejemplo, si `β = 0` en los dos flujos (nada resulta azul) o si ninguno de los dos produce
candidatos: entonces no hay trabajo azul que repartir y la pregunta por la cuota no aplica.
"""
function cuota_azul(R_adv, R_hon)
    (R_adv === nothing || R_hon === nothing) && return nothing
    d = R_adv + R_hon
    d == 0 && return nothing
    return R_adv // d
end

"""
    cuota_azul_condicional(f_accion, beta_adv, beta_hon) -> Rational{BigInt} o `nothing`

Cuota azul **bajo el supuesto declarado** `π_validez = π_admision = 1` en los dos flujos:

    cuota = (f · β_a) / (f · β_a + (1−f) · β_h)

donde `f` es la **fracción de piezas efectivas**. No es una cota: `f = 0,3`, `β_a = 1` y
`β_h = 0,5` dan `6/13 ≈ 0,461538`, **mayor** que `f`. Es exactamente el error que se corrigió:
«`α_blue_work ≤ α_bytes`» es **falso**.
"""
function cuota_azul_condicional(f_accion::Rational, beta_adv::Rational, beta_hon::Rational)
    num = f_accion * beta_adv
    den = num + (1 - f_accion) * beta_hon
    den == 0 && return nothing
    return num // den
end


# `alfa_tasas` se **retiró**: calculaba una razón a partir del número de piezas después de
# convertir bytes y la llamaba «α_bytes», y devolvía un `α_blue_work = (β_adv/β_hon)·α_bytes` que
# no es una cuota normalizada. Se sustituye por `reparto_bytes`, `fracciones`,
# `fraccion_candidatos_esperada`, `cuota_azul` y `cuota_azul_condicional`. La afirmación derivada
# «α_blue_work ≤ α_bytes» era **falsa** (con β_a/β_h = 2 y f = 0,3 la cuota condicional es 6/13).


# ---------------------------------------------------------------------------------------------
# Estadística
# ---------------------------------------------------------------------------------------------

"""Cuantiles de una muestra, sin dependencias opcionales."""
function cuantiles(v::AbstractVector{<:Real}, ps::AbstractVector{<:Real})
    s = sort(v)
    n = length(s)
    n == 0 && return fill(NaN, length(ps))
    return [quantile(s, p) for p in ps]
end

"""
    ic_clopper_pearson(k, n, conf) -> (lo, hi)

Intervalo **exacto** de Clopper–Pearson por la Beta: `lo = B(k, n−k+1)`, `hi = B(k+1, n−k)`.
Se usa el exacto, no Wilson, porque hay celdas con `k = 0` y el encargo §3 pide no convertir
`0/n` en probabilidad cero.
"""
function ic_clopper_pearson(k::Integer, n::Integer, conf::Real=0.95)
    n == 0 && return (0.0, 1.0)
    α = 1 - conf
    lo = k == 0 ? 0.0 : quantile(Beta(k, n - k + 1), α / 2)
    hi = k == n ? 1.0 : quantile(Beta(k + 1, n - k), 1 - α / 2)
    return (lo, hi)
end

"""
    cota_superior_exacta_cero(n, conf=0.95; lados=:uno) -> Float64

Cota superior exacta de una proporción cuando se observan **0 éxitos en `n` ensayos**.

* `lados=:uno` (por omisión): `1 − (1−conf)^{1/n}`, cota **unilateral** al nivel `conf`.
* `lados=:dos`: `1 − ((1−conf)/2)^{1/n}`, límite superior de Clopper–Pearson **bilateral**.

**Dirección e interpretación, que en la revisión 1 se publicaban mal.** Si
`p = P(≥1 candidato por slot)` y se observan 0 en `n` slots, la cota es de `p`: `p ≤ cota`. De ahí
se sigue, **por slot**, `P(0 candidatos en un slot) = 1 − p ≥ 1 − cota`. **No** es la probabilidad
conjunta de 0 candidatos en los `n` slots, que valdría `≥ 1−conf = 0,05` si los slots fuesen
independientes. Con `n = 512` y `conf = 0,95`: unilateral `5,834·10⁻³`, bilateral `7,179·10⁻³`.
"""
function cota_superior_exacta_cero(n::Integer, conf::Real=0.95; lados::Symbol=:uno)
    lados in (:uno, :dos) || throw(ArgumentError("lados debe ser :uno o :dos"))
    α = 1 - conf
    return 1 - (lados === :uno ? α : α / 2)^(1 / n)
end

"""
    sobredispersion(obs, mu) -> Float64

`Var_obs / mu`: el índice de dispersión. Vale `1` para una Poisson. Es la medida que revela que el
número de chunks auditados por slot **no** es binomial con `p = 1/2`, aunque su media sí sea `1/2`.
"""
function sobredispersion(obs::AbstractVector{<:Real}, mu::Real)
    mu == 0 && return NaN
    return var(obs) / mu
end

"""
    sobredispersion_binomial(obs, n) -> Float64

`Var_obs / (n/4)`, la referencia `Binomial(n, 1/2)` de la ocupación por bucket. `n/4` es la
varianza que tendría el número de piezas auditadas si cada bucket tuviese ocupación constante
`1/2` **y** las piezas fuesen independientes dentro del sector.
"""
function sobredispersion_binomial(obs::AbstractVector{<:Real}, n::Real)
    return var(obs) / (n / 4)
end

"""
    correlacion(x, y) -> Float64

Pearson. Se publica junto al solapamiento bruto, porque una correlación alta con solapamiento nulo
no es lo mismo que una correlación nula con solapamiento alto.
"""
function correlacion(x::AbstractVector{<:Real}, y::AbstractVector{<:Real})
    length(x) == length(y) || throw(DimensionMismatch("x e y deben tener la misma longitud"))
    return cor(x, y)
end

"""
    prob_al_menos_uno_indep(p1, p2) -> Float64

`1 − (1−p1)(1−p2)`: la probabilidad de **al menos un** ganador **si los dos retos fuesen
independientes**. Se calcula solo para contrastarla con la frecuencia empírica conjunta, tal como
exige el encargo §3 (no para sustituirla).
"""
prob_al_menos_uno_indep(p1::Real, p2::Real) = 1 - (1 - p1) * (1 - p2)

"""
    poisson_cola_superior(mu, k) -> Float64

`P(X ≥ k)` con `X ~ Poisson(mu)`, exacto por la Gamma incompleta regularizada que usa
`Distributions`. Sirve para las colas que el Monte Carlo no alcanza.
"""
poisson_cola_superior(mu::Real, k::Integer) = 1 - cdf(Poisson(mu), k - 1)

# ---------------------------------------------------------------------------------------------
# Incertidumbre con la unidad de observación correcta
# ---------------------------------------------------------------------------------------------

"""
    bootstrap_unidades(estadistico, n_unidades; B, semilla) -> Vector{Float64}

Bootstrap de bloques sobre la **unidad independiente**. Cuando las observaciones pareadas se
construyen combinando un conjunto pequeño de retos, el par **no** es la unidad independiente: cada
reto aparece en muchos pares y los pares comparten retos. La unidad que sí es independiente es el
**reto** (los retos son `blake3` distintos y sus buckets son uniformes independientes).

`estadistico(índices)` recibe un vector de índices de reto remuestreado **con reemplazo** y
devuelve un escalar. Se devuelven las `B` réplicas; los percentiles se calculan con
[`percentiles`](@ref).

Esto **sustituye** a cualquier σ calculada suponiendo que los pares son independientes.
"""
function bootstrap_unidades(estadistico::Function, n_unidades::Integer;
                           B::Integer=2000, semilla::Integer=0x5a5a)
    rng = StableRNG(semilla)
    out = Vector{Float64}(undef, B)
    for b in 1:B
        idx = rand(rng, 1:n_unidades, n_unidades)
        out[b] = Float64(estadistico(idx))
    end
    return out
end

"""Percentiles `(lo, hi)` de una muestra bootstrap al nivel de confianza dado."""
function percentiles(v::AbstractVector{<:Real}, conf::Real=0.95)
    α = 1 - conf
    return (quantile(v, α / 2), quantile(v, 1 - α / 2))
end

"""
    reparto_exclusivo(s_a, s_b, b_i, b_j) -> NamedTuple

Compara, para un par de retos, **compartir** la parcela (los dos retos auditan el sector completo)
frente a **repartirla** en dos mitades disjuntas, promediando las **dos** asignaciones posibles de
las mitades.

Identidad exacta: con `s = s_a + s_b` (partición de las M piezas),

    asignación 1 = s_a[b_i] + s_b[b_j]
    asignación 2 = s_a[b_j] + s_b[b_i]
    promedio     = (asignación 1 + asignación 2)/2 = (s[b_i] + s[b_j])/2 = compartido/2

luego **`promedio = compartido/2` para TODO par**, incluido el degenerado. El **cociente**
`compartido/promedio` vale `2` cuando `compartido > 0`, y está **INDEFINIDO** (`0/0`) cuando los dos
buckets están vacíos: en ese caso `razon` es `nothing`, **no** `2` y **no** `Inf`.

**Corrección.** La primera versión devolvía `Inf` en el caso degenerado y el docstring afirmaba que
el cociente era 2 «para todo par». La revisión independiente lo refutó: en los 64 retos publicados
hay 5 con `leidos = 0`, de modo que **10 de los 2016 pares** dan `0/0`. Lo que sí es exacto para
todo par es la igualdad `promedio = compartido/2`; y el cociente de **medias**
`mean(compartido)/mean(promedio)` también es exactamente 2 cuando la media no es nula.
"""
function reparto_exclusivo(s_a::AbstractVector{<:Integer}, s_b::AbstractVector{<:Integer},
                           b_i::Integer, b_j::Integer)
    asig1 = Int(s_a[b_i + 1]) + Int(s_b[b_j + 1])
    asig2 = Int(s_a[b_j + 1]) + Int(s_b[b_i + 1])
    promedio = (asig1 + asig2) / 2
    compartido = Int(s_a[b_i + 1]) + Int(s_b[b_i + 1]) +
                 Int(s_a[b_j + 1]) + Int(s_b[b_j + 1])
    # `promedio == compartido/2` siempre; el cociente solo está definido si el denominador no es 0.
    razon = promedio == 0 ? nothing : compartido / promedio
    return (asignacion_1=asig1, asignacion_2=asig2, promedio_mitades=promedio,
            compartido=compartido, razon=razon, definido=(promedio != 0))
end

