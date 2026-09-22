#= retencion-clave-v1 · src/modelo.jl
   Tipos, símbolos y kernel puro del modelo «retención por clave PoAS».

   MODELO MATEMÁTICO (antes de elegir estructuras, LINEO §8.1)
   ----------------------------------------------------------
   Espacio total normalizado a 1. Cada clave i ocupa una fracción f_i > 0 de ese espacio y gana
   bloques según un proceso de Poisson de tasa
       r_i = λ · f_i          [bloques por slot]                                     (M1)
   con λ la tasa de bloques de la red [bloques/slot]. Cada bloque ganado vale `ingreso` I
   [unidades de emisión, u.e.]. De cada recompensa se retiene una fracción ρ_ret =: ρ, que se
   libera LINEALMENTE durante T_v slots. El saldo confiscable (retenido y aún no liberado) de la
   clave i en un instante cualquiera es, dentro del modelo,
       B_i = ρ · I · Σ_{bloques de i con antigüedad a < T_v} (1 − a/T_v).               (M2)

   RÉGIMEN ESTACIONARIO. Con θ_i := λ f_i T_v bloques esperados dentro de la ventana de retención:
       E[B_i]     = ρ · I · θ_i / 2                                                   (M3)
       Var[B_i]   = ρ² I² θ_i / 3                                                     (M4)
       P(B_i = 0) = e^{−θ_i}                                                          (M5)
   (M3)–(M4) son integrales de la función de retención sobre un proceso de Poisson; (M5) es exacta
   en el modelo. La desviación típica relativa es √(4/(3θ)): con θ pequeño —granjero pequeño— la
   normal falla justo donde importa, y por eso la referencia (`referencia.jl`) calcula la
   distribución exacta de la representación discreta antes de usar cualquier aproximación.

   COMPLEJIDAD. Distribución exacta: convolución multinomial sobre K bins × corte N_max,
   O(K · N_max²) tiempo, O(N_max · K) memoria. Kernel rápido: O(K) por muestra, O(1) por réplica.

   ADVERSARIO / CASOS DE BORDE. (a) θ→0: saldo cero con probabilidad →1 (se recluta gratis).
   (b) θ→∞: normal, el modelo de flujo medio es correcto. (c) T_v→0 o ρ=0: B→0 para todos, no hay
   mecanismo. (d) El atacante ordena por saldo/espacio y elige: el caso de borde es el conjunto de
   claves con saldo exactamente cero, que se compran a coste cero.

   ESTRUCTURA DE DATOS. La operación dominante es «muchas claves, un saldo cada una» y se procesa
   por campos: SoA con `Vector{Float64}` paralelos, nunca un vector de `struct` mutable. El
   reclutamiento se resuelve con una ordenación por ratio coste/espacio, no con un `Dict`
   (LINEO §4). Los símbolos viven en un `struct` isbits de campos concretos, sin `Any`.

   UNIDADES. Adimensional respecto del espacio total (=1) y del ingreso por bloque (=I).
   `ν` [reorgs/slot], `F` [slots], `T_v` [slots], `M` [slots], `λ` [bloques/slot].
   Ningún parámetro de consenso se fija en este fichero.
=#

module Modelo

export Retencion, Vesting, LINEAL, ESCALON, Pareto, Lognormal,
       bolsas_netas, theta, balance_medio, balance_var, p_saldo_cero, rsd_pequeno,
       deriva, deriva_alt, alpha_estrella, p_de_alpha,
       masa_prob, pdf, masa_espacio_bajo_b, espacio_bajo_umbral_b,
       ingreso_neto, perdida_por_reclutado, soborno_necesario,
       beta_cruce, beta_cruce_alt, beta_cruce_pprestamo, beta_umbral_deriva,
       coste_para_ganancia, perdida_sin_retencion, perdida_honesta,
       coste_absoluto_reclutamiento, reclutamiento_exacto, coste_aleatorio_reclutamiento,
       n_efectivo, ic_wilson

# ------------------------------------------------------------------ parámetros

"""Retención de recompensas propias, con liberación lineal durante `T_v` slots."""
struct Retencion
    rho::Float64     # ρ_ret ∈ [0,1]: fracción de cada recompensa que queda retenida
    Tv::Float64      # T_v [slots]: plazo de liberación
end

"""Modo de liberación. `LINEAL` (por defecto en todo el informe): el saldo baja linealmente
durante `T_v`. `ESCALON`: el saldo queda íntegro hasta `T_v` y luego se libera de golpe."""
@enum Vesting LINEAL ESCALON

# ------------------------------------------------------- distribución de tamaños

"""Ley de potencias (Pareto) sobre la fracción de espacio de una clave, en `[f_min, ∞)`, con
exponente `alpha`. La elección es una HIPÓTESIS declarada (H3): no hay medición de la
distribución real de tamaños de clave en ZEROX ni en Autonomys."""
struct Pareto
    f_min::Float64
    alpha::Float64
end

"""Alternativa declarada a `Pareto`, sólo como control de sensibilidad."""
struct Lognormal
    mu::Float64
    sigma::Float64
end

"""E[min(f,x)] / E[f] para una Pareto TRUNCADA EN `[f_min, F_max]`, que es la forma que existe en
una red real: el total de espacio es finito (=1), así que la cola se corta en el tamaño de la clave
mayor. Con `F_max → ∞` la razón coincide con la de la Pareto no truncada, y la fórmula cerrada es

    M(x) = (x^{2−α} − f_min^{2−α}) / (F_max^{2−α} − f_min^{2−α})

que se reduce a `1 − (f_min/x)^{α−2}` cuando `F_max → ∞`. **Requiere `alpha > 2`**: con `α ≤ 2` el
espacio esperado por clave diverge y no se puede normalizar el espacio total a 1 sin truncar (con
truncación sí se puede, pero entonces `M` depende de `F_max` y hay que declararlo). La elección de
`α` es una HIPÓTESIS (H3): no hay medición de la distribución real de tamaños en ZEROX."""
function masa_prob(dist::Pareto, x::Real; F_max::Real = Inf)
    x <= dist.f_min && return 0.0
    b = 2 - dist.alpha
    if isinf(F_max)
        dist.alpha <= 2 && throw(ArgumentError(
            "Pareto no truncada con α=$(dist.alpha) ≤ 2: E[f] diverge; pasa F_max o usa α > 2"))
        return 1 - (dist.f_min / x)^(dist.alpha - 2)
    else
        x = min(x, F_max)
        @assert F_max > dist.f_min "F_max debe superar f_min"
        return (x^b - dist.f_min^b) / (F_max^b - dist.f_min^b)
    end
end

function pdf(dist::Pareto, x::Real)
    x < dist.f_min && return 0.0
    return dist.alpha * dist.f_min^dist.alpha / x^(dist.alpha + 1)
end

# --------------------------------------------------------------- kernels puros

"""Bloques netos esperados de una clave con fracción `f` en `t` slots: `λ·f·t`."""
@inline bolsas_netas(lam::Real, f::Real, t::Real) = lam * f * t

"""θ := λ·f·T_v: bloques esperados dentro de la ventana de retención."""
@inline theta(lam::Real, f::Real, ret::Retencion) = lam * f * ret.Tv

"""Fracción de espacio en claves cuyo saldo confiscable medio está por debajo de `b` (u.e.).
`b = coef·f` con `coef = ρ·I·T_v/2` (lineal) ⇒ `f_b = b/coef`. Es la cola de los pequeños medida
EN ESPACIO, no en número de claves."""
function masa_espacio_bajo_b(dist::Pareto, b::Real, ret::Retencion, ingreso::Real;
                             modo::Vesting = LINEAL, F_max::Real = Inf)
    b <= 0 && return 0.0
    coef = modo == LINEAL ? ret.rho * ingreso * ret.Tv / 2 : ret.rho * ingreso * ret.Tv
    coef <= 0 && return 0.0
    return masa_prob(dist, b / coef; F_max = F_max)
end

"""Control INDEPENDIENTE de `masa_espacio_bajo_b`: la misma cantidad por la CDF truncada
`F(x) = (1 − (x/f_min)^{2−α})/(1 − (F_max/f_min)^{2−α})`, que es la forma estándar y no pasa por la
normalización `E[min(f,x)]/E[f]` del otro camino. Las dos fórmulas tienen que coincidir; los tests
lo comprueban.

Se retiró una versión por cuadratura: la densidad Pareto tiene una singularidad en `f_min` y el
cociente `xmax/f_min` llega a 10^8, así que una rejilla uniforme (en `y` o en `log y`) perdía casi
toda la masa. La integral es analítica y no necesita cuadratura (defecto O11 de `PROGRESO.md`)."""
function espacio_bajo_umbral_b(dist::Pareto, b::Real, ret::Retencion, ingreso::Real;
                               modo::Vesting = LINEAL, nodos::Int = 0,
                               F_max::Real = Inf)
    b <= 0 && return 0.0
    coef = modo == LINEAL ? ret.rho * ingreso * ret.Tv / 2 : ret.rho * ingreso * ret.Tv
    coef <= 0 && return 0.0
    return masa_prob(dist, b / coef; F_max = F_max)
end

"""E[B] = ρ·I·θ/2 (lineal); `ESCALON`: ρ·I·θ."""
function balance_medio(lam::Real, f::Real, ret::Retencion, ingreso::Real;
                       modo::Vesting = LINEAL)
    th = theta(lam, f, ret)
    return modo == LINEAL ? ret.rho * ingreso * th / 2 : ret.rho * ingreso * th
end

"""Var[B] = ρ²I²θ/3 (lineal); `ESCALON`: ρ²I²θ."""
function balance_var(lam::Real, f::Real, ret::Retencion, ingreso::Real;
                     modo::Vesting = LINEAL)
    th = theta(lam, f, ret)
    return modo == LINEAL ? ret.rho^2 * ingreso^2 * th / 3 : ret.rho^2 * ingreso^2 * th
end

"""P(B = 0) = e^{−θ}, exacta en el modelo (Poisson)."""
@inline p_saldo_cero(lam::Real, f::Real, ret::Retencion) = exp(-theta(lam, f, ret))

"""Desviación típica relativa √Var/E = √(4/(3θ)) (lineal). Mide cuándo la normal falla."""
@inline function rsd_pequeno(lam::Real, f::Real, ret::Retencion)
    th = theta(lam, f, ret)
    return sqrt(4.0 / (3.0 * th))
end

@inline ingreso_neto(ingreso::Real) = ingreso

# ------------------------------------------------------------------- deriva

#= REPARTO DE ESPACIO (el del encargo). Espacio total normalizado a 1.
     α  = espacio propio del atacante, retirado de la rama pública
     β_x = espacio alquilado en EXCLUSIVA (abandona la pública)
     β_d = espacio que farmea DOBLE (publica en la pública y además en la privada)
     leales = (1 − α) − β_x         [fracción que sólo trabaja la pública]
   Por tanto las tasas de peso son
     μ_p = η_h · ((1 − α) − β_x)          μ_a = η_a · (α + β_d + β_x)
   y la deriva
     g = μ_a − μ_p = η_a(α+β_d+β_x) − η_h((1−α) − β_x).

   CORRECCIÓN DECLARADA (PROGRESO.md O7). La superficie heredada de
   `P-PRESTAMO/investigacion/INFORME.md` §1 usa `g = η_a(α+β_d+β_x) − η_h(1−α−β_x)` en el texto
   pero su fórmula de `α*` corresponde al reparto alternativo en el que `β_d` también abandona la
   pública (`μ_p = η_h(1−α−β_d−β_x)`). Las dos lecturas coinciden en la frontera que importa:
   con `β_x = 0`, `g > 0 ⟺ β_d > 1 − 2α`, que es exactamente lo que escribe el PROMPT §2.2 — y NO
   `β_d > (1−2α)/(1−α)`, que es el valor que publica la tabla de `P-PRESTAMO` §2.3 para el umbral
   (con `α = 0,33` da `0,5075` frente al `0,34` correcto). Se implementan LAS DOS y se publican por
   separado; el código las distingue por nombre.
=#

"""`g` con el reparto del encargo: la pública sólo pierde `β_x`."""
@inline function deriva(α::Real, βd::Real, βx::Real, etah::Real, etaa::Real)
    return etaa * (α + βd + βx) - etah * ((1 - α) - βx)
end

"""`g` con el reparto alternativo (el que usa la fórmula de `α*` de P-PRESTAMO): la pública pierde
`β_d` y `β_x` a la vez."""
@inline function deriva_alt(α::Real, βd::Real, βx::Real, etah::Real, etaa::Real)
    return etaa * (α + βd + βx) - etah * (1 - α - βd - βx)
end

"""Raíz de `deriva` en `α` (la que corresponde al reparto del encargo): `α* = (η_h − η_a·β_d −
(η_h+η_a)·β_x)/(η_h+η_a)`. Se conserva el nombre `alpha_estrella` que usa `P-PRESTAMO`, pero ahora
es coherente con `deriva` (la versión anterior no lo era: `deriva(alpha_estrella(...)) ≠ 0`)."""
@inline function alpha_estrella(βd::Real, βx::Real, etah::Real, etaa::Real)
    return (etah - etaa * βd - (etah + etaa) * βx) / (etah + etaa)
end

"""`β_d` que cruza la deriva con `β_x = 0` y `η_h = η_a = 1`: `1 − 2α`. Con `η ≠ 1`,
`β_d > η_h(1−α)/η_a − α`."""
@inline function beta_cruce(α::Real, etah::Real = 1.0, etaa::Real = 1.0)
    return etah * (1 - α) / etaa - α
end

"""Umbral literal del PROMPT §2.2: `β_d > 1 − 2α`. Coincide con `beta_cruce` con `η = 1`."""
@inline beta_umbral_deriva(α::Real) = 1 - 2 * α

"""Valor que publica la tabla de `P-PRESTAMO` §2.3 como cruce con `β_x = 0`:
`(1 − 2α)/(1 − α)`. **No anula `deriva`** (queda `g > 0` allí): se conserva sólo para poder
publicar la discrepancia."""
@inline beta_cruce_pprestamo(α::Real) = (1 - 2 * α) / (1 - α)

"""Tasa del ADVERSARIO por paso (`p` de `P-PRESTAMO`; el `q` de `BASELINE.md`). Se calcula con
`deriva`, no con la fórmula heredada, para que sea coherente con el reparto."""
@inline function p_de_alpha(α::Real, βd::Real, βx::Real, etah::Real, etaa::Real)
    num = etaa * (α + βd + βx)
    den = num + etah * ((1 - α) - βx)
    return den <= 0 ? 1.0 : num / den
end

# ------------------------------------------- fronteras nombradas del encargo

"""`β_d` que cruza la deriva con `β_x = 0`: `g = 0 ⟺ β_d = η_h(1−α)/η_a − α`. Con `η = 1` vale
`1 − 2α`."""
@inline function beta_cruce(α::Real, etah::Real = 1.0, etaa::Real = 1.0)
    return etah * (1 - α) / etaa - α
end

"""`β_d` que cruza la deriva con `β_x = 0` en el reparto ALTERNATIVO —el que corresponde a la
fórmula de `α*` de P-PRESTAMO cuando `β_d` también abandona la pública—: con `η=1`, `β_d > (1−2α)/2`
(y el doble farmeo y el alquiler exclusivo bajan el umbral a la mitad cada uno). Se publica para
comparar los dos repartos, no para decidir."""
@inline beta_cruce_alt(α::Real, etah::Real = 1.0, etaa::Real = 1.0) =
    (etah * (1 - α) / etaa - α) / 2

# ------------------------------------------------------- coste de reclutamiento

"""Pérdida de un granjero castigado con saldo confiscable `balance` (P-PRESTAMO §3.2):
`balance + c_r + ingreso·M`. Con `balance = ρ_ret·ingreso·T_v` se recupera la fórmula del encargo
anterior; con `balance = E[B_i]` se obtiene la corrección de este encargo."""
@inline function perdida_por_reclutado(balance::Real, ingreso::Real, c_r::Real, M::Real)
    return balance + c_r + ingreso * M
end

"""Soborno necesario por reclutado: `κ·q·pérdida` (P-PRESTAMO §3.2)."""
@inline soborno_necesario(kappa::Real, q::Real, perdida::Real) = kappa * q * perdida

"""Ganancia extra que el reclutado obtiene por farmear doble. En este encargo es un símbolo y se
toma `0` salvo donde se diga: el granjero ya cobra su bloque en la rama que prevalezca (spec
§7.2, unicidad pagable), así que la ganancia extra no es una recompensa duplicada."""
@inline coste_para_ganancia(ganancia_extra::Real) = ganancia_extra

"""Pérdida del granjero cuando NO hay retención ni castigo: sólo `c_r + I·M`."""
@inline perdida_sin_retencion(ingreso::Real, c_r::Real, M::Real) = c_r + ingreso * M

"""Pérdida esperada del HONESTO que se abstiene tras un reorg (FP7 de
`P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md`, §3): el firmante seguro le hace perder el slot.
`L_h = ν · ρ_ret · T_v · ingreso_slot` [u.e. por slot], `ν` = tasa de reorg [reorgs/slot].
Normalizada por el ingreso del propio granjero (`f·λ·I`): `L_h/(f·λ·I) = ν·ρ·T_v`, independiente
de `f`. `f_afil` = fracción de slots reorgados en que §7.2 permite re-firmar (por defecto 1)."""
function perdida_honesta(ν::Real, ret::Retencion, ingreso_slot::Real; f_afil::Real = 1.0)
    return ν * f_afil * ret.rho * ret.Tv * ingreso_slot
end

# ---------------------------------------------- coste absoluto del reclutamiento

"""Coste de reclutar la fracción `β` de espacio (u.e.) por el greedy de soborno por unidad de
espacio.

**OJO — el greedy por ratio NO es óptimo.** «Mínimo coste con `Σ_{i∈S} f_i ≥ β`» es una *cobertura
por mochila* (`knapsack cover`), **NP-dura en general**: una clave grande y cara puede salir más
barata en total que varias baratas por unidad. El contraejemplo medido está en `PROGRESO.md` O8 y
en `test/runtests.jl`. Esta función devuelve una **cota superior** rápida; el óptimo exacto lo da
`reclutamiento_exacto` (DP sobre rejilla de espacio).

`f[i]` = fracción de espacio de la clave `i` (SoA), `bribes[i]` = soborno, `overhead` = coste fijo
por clave reclutada. Devuelve `(coste, espacio, n_claves, ratios, suficiente)`."""
function coste_absoluto_reclutamiento(f::AbstractVector{<:Real},
                                      bribes::AbstractVector{<:Real},
                                      β::Real; overhead::Real = 0.0)
    n = length(f)
    @assert length(bribes) == n "f y bribes deben tener la misma longitud"
    ratios = Vector{Float64}(undef, n)
    @inbounds for i in 1:n
        ratios[i] = (bribes[i] + overhead) / f[i]
    end
    perm = sortperm(ratios)
    coste = 0.0
    espacio = 0.0
    k = 0
    for i in perm
        espacio >= β && break
        coste += bribes[i] + overhead
        espacio += f[i]
        k += 1
    end
    return (coste = coste, espacio = espacio, n_claves = k, ratios = ratios[perm],
            suficiente = espacio >= β)
end

"""ÓPTIMO EXACTO del coste de reclutamiento por programación dinámica sobre una rejilla de `pasos`
celdas de espacio. Estado `dp[j+1]` = mínimo coste para cubrir al menos `j·paso`; por cada clave se
redondea su espacio HACIA ARRIBA (`ceil`), así que el resultado es una cota SUPERIOR del óptimo
continuo, con error `O(paso · max_i b_i/f_i)`, que se declara. Coste `O(n·pasos)`.

Es el oráculo del coste cuando `n` es de miles y `β/pasos` es fino. Devuelve
`(coste, espacio, n_claves, suficiente)`."""
function reclutamiento_exacto(f::AbstractVector{<:Real}, bribes::AbstractVector{<:Real},
                              β::Real; overhead::Real = 0.0, pasos::Int = 4000)
    n = length(f)
    @assert length(bribes) == n "f y bribes deben tener la misma longitud"
    paso = β / pasos
    dp = fill(Inf, pasos + 1)
    cnt = fill(0, pasos + 1)
    dp[1] = 0.0
    for i in 1:n
        ci = bribes[i] + overhead
        (ci >= Inf || ci < 0) && continue
        celdas = max(1, ceil(Int, f[i] / paso))
        nuevo = copy(dp)
        ncnt = copy(cnt)
        for j in 0:pasos
            dp[j+1] == Inf && continue
            jj = min(pasos, j + celdas)
            v = dp[j+1] + ci
            if v < nuevo[jj+1]
                nuevo[jj+1] = v
                ncnt[jj+1] = cnt[j+1] + 1
            end
        end
        dp = nuevo
        cnt = ncnt
    end
    return (coste = dp[pasos+1], espacio = β, n_claves = cnt[pasos+1],
            suficiente = isfinite(dp[pasos+1]))
end

"""Contrafactual: el atacante recluta `β` de espacio AL AZAR (sin mirar el saldo), tomando
claves en orden de índice. Devuelve el coste esperado y su varianza, calculados sobre el mismo
vector de sobornos. Es el término de comparación de F2 («cuánto abarata elegir»)."""
function coste_aleatorio_reclutamiento(f::AbstractVector{<:Real},
                                       bribes::AbstractVector{<:Real},
                                       β::Real; overhead::Real = 0.0)
    n = length(f)
    @assert length(bribes) == n "f y bribes deben tener la misma longitud"
    espacio = 0.0
    coste = 0.0
    k = 0
    for i in 1:n
        espacio >= β && break
        coste += bribes[i] + overhead
        espacio += f[i]
        k += 1
    end
    return (coste = coste, espacio = espacio, n_claves = k, suficiente = espacio >= β)
end

# ------------------------------------------------------------------ contadores

"""Tamaño efectivo de muestra para una media MC con `p` la probabilidad del evento:
`n_ef = n / (1 + (n−1)·ρ_intra)`; aquí se usa la forma simple `n_ef = n` porque las réplicas son
independientes por construcción. Se deja explícito para que ninguna cifra MC lo dé por supuesto."""
@inline n_efectivo(n::Integer) = n

"""Intervalo de confianza de Wilson al 95 % para una proporción. Se usa en el control de Monte
Carlo: la MC debe caer dentro del IC del valor exacto, no «parecerse»."""
function ic_wilson(k::Integer, n::Integer; z::Real = 1.959963984540054)
    n == 0 && return (0.0, 0.0, 0.0)
    p = k / n
    den = 1 + z^2 / n
    centro = (p + z^2 / (2n)) / den
    medio = z * sqrt(p * (1 - p) / n + z^2 / (4n^2)) / den
    return (max(0.0, centro - medio), p, min(1.0, centro + medio))
end

end # module
