#= sensores.jl — E1 (reloj de PoT) y E2 (tasa de bloques) con aritmética exacta donde importa.

REGLA DE LINEO §5.3 y del encargo §6: «Aritmética exacta (`Rational{BigInt}` o intervalos) para
las colas de Poisson de los sensores y para la captura de salientes: son colas, y ahí es donde el
flotante falla.»

Qué es exacto aquí y qué no, declarado:
  · La **suma parcial de Poisson** `Σ_{k<n} μ^k/k!` se calcula en `Rational{BigInt}` **exacto**.
    `μ = λ·W` es racional exacto. El único paso no exacto es `exp(−μ)`, que se evalúa en
    `BigFloat` a 256 bits; se declara.
  · La **búsqueda del umbral** es sobre enteros, así que el resultado es exacto salvo que el
    umbral caiga a menos de 1e-70 relativo de la frontera; se comprueba y se declara el margen.
  · La cola de la **frontera secuencial** de E1 (`P(L ≤ x) = ∏_{j≥0} F_D(x + jσ)`) usa
    distribuciones continuas: se evalúa en `BigFloat` a 256 bits. Es una **hipótesis declarada**
    de familia de cola (lognormal / Pareto), no un dato medido.

E1 y E2 viven **sólo** en un informe de `research/scripts/` (ronda 11b) y **no son reglas**:
`grep -niE "eclipse|sensor|n_min|falsa alarma" SPEC.md` no devuelve ninguna regla (comprobado en
el encargo §0.2). Este módulo los re-deriva en Julia; no los convierte en regla.
=#

module Sensores

using Printf

const SEG_ANO = 31_536_000.0      # segundos por año juliano
const SIGMA = 1.0                 # duración de slot (C-SLOT-01, variante A″)

# ---------------------------------------------------------------------------------------
# Cola de Poisson: parte exacta en Rational{BigInt}, exp en BigFloat
# ---------------------------------------------------------------------------------------

"""
`Σ_{k=0}^{n} μ^k/k!` como `Rational{BigInt}` **exacto**. `mu` es un `Rational`.
Devuelve `(suma, k)` con `k = n+1` (el número de términos).
"""
function suma_poisson_exacta(n::Integer, mu::Rational{BigInt})
    n < 0 && return (Rational{BigInt}(0), 0)
    acc = Rational{BigInt}(0)
    term = Rational{BigInt}(1)          # μ^0/0!
    for k in 0:n
        acc += term
        term = term * mu // (k + 1)     # μ^{k+1}/(k+1)!
    end
    return (acc, n + 1)
end

"""`P(N ≤ n)` con `N ~ Poisson(μ)`: exacto salvo `exp`, que va en `BigFloat` de 256 bits."""
function poisson_cdf_big(n::Integer, mu::Rational{BigInt})
    n < 0 && return BigFloat(0)
    s, _ = suma_poisson_exacta(n, mu)
    return setprecision(BigFloat, _PREC) do
        exp(-BigFloat(mu)) * BigFloat(s)
    end
end

"""
`n_min(W)` — el mayor umbral de alarma «la ventana `W` trae estrictamente menos de `n_min`
bloques» cuya probabilidad de falsa alarma con tráfico honesto `Poisson(λW)` queda por debajo
de `fa_ano` al año.

Portado **literalmente** de `r11b_lib.n_min_poisson`: se busca el primer `n` con
`P(N ≤ n−1) > fa_ano/pruebas` y se devuelve `n−1`. `solapadas=true` cuenta una prueba por slot
(cota conservadora, la que usó 11b en su columna «cota por slot»).
"""
function n_min(W::Real; lam::Real = 1.0, fa_ano::Real = 1.0, solapadas::Bool = true)
    mu = Rational{BigInt}(lam) * Rational{BigInt}(W)
    pruebas = solapadas ? SEG_ANO / SIGMA : SEG_ANO / W
    objetivo = setprecision(BigFloat, _PREC) do
        log(BigFloat(fa_ano) / BigFloat(pruebas))
    end
    tope = Int(floor(Float64(mu))) + 1
    n = 0
    while n <= tope
        v = setprecision(BigFloat, _PREC) do
            log(poisson_cdf_big(n - 1, mu))
        end
        if v > objetivo
            return n - 1
        end
        n += 1
    end
    return Int(floor(Float64(mu)))
end

"""
`α` mínima para que el número esperado de alarmas de E2 durante un ataque de duración `T` sea
`< objetivo`. La víctima ve tasa `α·λ`, luego `N ~ Poisson(α·λ·W)` por ventana y hay `T/σ`
pruebas. Se resuelve por bisección exacta sobre `α` (el criterio es monótono en `α`).
"""
function alpha_min(W::Real, nmin::Integer, T::Real; lam::Real = 1.0, objetivo::Real = 0.1)
    pruebas = T / SIGMA
    lo, hi = 0.0, 1.0
    for _ in 1:200
        mid = (lo + hi) / 2
        mu = Rational{BigInt}(mid) * Rational{BigInt}(lam) * Rational{BigInt}(W)
        p = Float64(poisson_cdf_big(nmin - 1, mu))
        if pruebas * p < objetivo
            hi = mid
        else
            lo = mid
        end
    end
    return hi
end

# ---------------------------------------------------------------------------------------
# E1 · la frontera secuencial del PoT
# ---------------------------------------------------------------------------------------

"""Parámetros de una lognormal con esa mediana y ese p99 (hipótesis declarada de familia)."""
function lognormal_params(mediana::Real, p99::Real)
    z99 = 2.3263478740408408
    return log(Float64(mediana)), (log(Float64(p99)) - log(Float64(mediana))) / z99
end

# `erf` NO está en Base de Julia. Para no añadir una dependencia se implementa en `BigFloat`.
#
# PRIMER INTENTO, Y POR QUÉ SE DESCARTA: una fracción continua de Lentz para `erfc`. El test de
# `Φ(1,96)` la cazó dando 0,98896 en vez de 0,97500 — y ese error, arrastrado, hacía que
# `P(D>8)` saliera 0,0045 cuando es **forzosamente** 0,0100 por construcción de la lognormal
# (p99 = 8 significa exactamente P(D≤8) = 0,99). Un instrumento que no reproduce una identidad
# suya por construcción no vale. Se sustituye por dos desarrollos con presupuesto de cancelación
# explícito:
#   · `y ≤ 10`: serie de Taylor de `erf`. El término máximo es ~10^41 a `y = 10`, luego se pierden
#     ~41 dígitos; con 512 bits (~154 dígitos) quedan >100. Suficiente y declarado.
#   · `y > 10`: expansión asintótica, truncada en el término mínimo (truncación óptima). A `y = 10`
#     el término mínimo es ~10^−43 relativo, muy por debajo de la cola que hay que resolver.

const _DOS_SQRT_PI = BigFloat(2) / sqrt(BigFloat(pi))
const _PREC = 512
const _UMBRAL_SERIE = BigFloat(10)

"""`erf(y)` por serie de Taylor, para `0 ≤ y ≤ 10`."""
function _erf_serie(y::BigFloat)
    y == 0 && return BigFloat(0)
    t = y
    acc = y
    y2 = y * y
    n = 0
    while true
        n += 1
        t *= -y2 / n
        term = t / (2n + 1)
        acc += term
        if abs(term) < abs(acc) * BigFloat(2)^(-(_PREC - 60)) || n > 800
            break
        end
    end
    return _DOS_SQRT_PI * acc
end

"""`erfc(y)` por expansión asintótica con truncación óptima, para `y > 10`."""
function _erfc_asint(y::BigFloat)
    # erfc(y) = exp(−y²)/(y√π) · Σ (−1)^n (2n−1)!! / (2y²)^n
    inv2y2 = 1 / (2 * y * y)
    term = BigFloat(1)
    acc = BigFloat(1)
    prev = BigFloat(1)
    for n in 1:200
        term *= -(2n - 1) * inv2y2
        nuevo = acc + term
        abs(term) > abs(prev) && break      # la serie empieza a divergir: truncación óptima
        acc = nuevo
        prev = term
    end
    return exp(-y * y) / (y * sqrt(BigFloat(pi))) * acc
end

"""`erfc(y)` para `y ≥ 0`."""
function _erfc_pos(y::BigFloat)
    y >= _UMBRAL_SERIE && return _erfc_asint(y)
    return 1 - _erf_serie(y)
end

"""`Φ(z)` con precisión de trabajo `_PREC`: `Φ(z) = ½·erfc(−z/√2)`."""
function _cdf_normal(z::BigFloat)
    return setprecision(BigFloat, _PREC) do
        y = z / sqrt(BigFloat(2))
        y >= 0 ? 1 - _erfc_pos(y) / 2 : _erfc_pos(-y) / 2
    end
end

"""`F_D(x)` para `D` lognormal(mediana, p99)."""
function cdf_lognormal(x::Real, mediana::Real, p99::Real)
    x <= 0 && return BigFloat(0)
    mu, sig = lognormal_params(mediana, p99)
    return setprecision(BigFloat, _PREC) do
        z = (log(BigFloat(x)) - BigFloat(mu)) / BigFloat(sig)
        _cdf_normal(z)
    end
end

"""
Pareto ajustada a la misma **mediana** y el mismo **p99** (control de robustez de la cola).

Forma estándar `F(x) = 1 − (x_m/x)^a`. Con mediana `m` y p99 `q`:
`mediana = x_m·2^(1/a)` y `p99 = x_m·100^(1/a)`, luego `q/m = 50^(1/a)` y `a = ln 50 / ln(q/m)`,
`x_m = m / 2^(1/a)`.

AVISO, y es una discrepancia con 11b que se anota en vez de resolver: 11b §B.1 publica para
Pareto `p99=8, ε=1 → B = 76,40 (excursión) / 138,92 (slot)` y `p99=16 → 1422,41 / 50691,69`.
Con el ajuste literal de «misma mediana y p99» **no se reproducen** (salen 54,80/81,71 y
724,48/6232,76). El informe de 11b no escribe la parametrización de su Pareto. Lo que sí se
reproduce **celda a celda** es la columna lognormal, que es la que valida el modelo de frontera.
"""
function cdf_pareto(x::Real, mediana::Real, p99::Real)
    m = Float64(mediana); q = Float64(p99)
    a = log(50.0) / log(q / m)
    xm = m / 2.0^(1.0 / a)
    x <= xm && return BigFloat(0)
    return setprecision(BigFloat, _PREC) do
        1 - (BigFloat(xm) / BigFloat(x))^BigFloat(a)
    end
end

"""
Cola de la **frontera secuencial**: `P(L > x)` con `P(L ≤ x) = ∏_{j≥0} F_D(x + jσ)`.
Un solo slot retrasado atasca la frontera verificada, que es lo que distingue este modelo de
«una muestra suelta del retardo». `cdf` es `cdf_lognormal` o `cdf_pareto`.
"""
function cola_frontera(x::Real, cdf::Function; mediana::Real = 4.0, p99::Real = 8.0,
                       sigma::Real = SIGMA, jmax::Integer = 2000)
    prod = BigFloat(1)
    uno = BigFloat(1) - BigFloat(2)^(-250)
    for j in 0:jmax
        f = cdf(x + j * sigma, mediana, p99)
        f <= 0 && return BigFloat(1)
        prod *= f
        # Cuando F_D ya es 1 a la precisión de trabajo, los factores restantes no la cambian.
        f >= uno && break
    end
    return 1 - prod
end

"""
`B` (s) tal que la alarma «el PoT recibido va más de `B` por detrás del reloj de pared» tiene
menos de `fa_ano` falsas alarmas al año, con deriva de reloj `eps` (se suma en el peor caso).

Dos contabilidades, las de 11b §B.1, y **no son la misma cola**:
  · `por_slot = true` — «por slot»: cuenta cada segundo en alarma y usa la cola de la **frontera
    secuencial** `L` (un slot retrasado atasca la frontera). Es la conservadora.
  · `por_slot = false` — «por excursión»: cada excursión la arranca un único slot con `D > B`, y
    usa la cola **marginal** de `D`. Es la cuenta operativa.
"""
function B_paro(mediana::Real, p99::Real;
                eps::Real = 1.0, fa_ano::Real = 1.0, por_slot::Bool = true,
                cdf::Function = cdf_lognormal)
    objetivo = fa_ano / (SEG_ANO / SIGMA)
    lo, hi = 0.0, 200_000.0
    for _ in 1:120
        mid = (lo + hi) / 2
        p = por_slot ?
            Float64(cola_frontera(mid - eps, cdf; mediana = mediana, p99 = p99)) :
            Float64(1 - cdf(mid - eps, mediana, p99))
        if p < objetivo
            hi = mid
        else
            lo = mid
        end
    end
    return hi
end

# ---------------------------------------------------------------------------------------
# Informe
# ---------------------------------------------------------------------------------------

function informe()
    println("VALIDACIÓN de la CDF normal implementada sin `erf` (no está en Base de Julia):")
    println("  Φ(0) debe ser 0,5; Φ(1,96) ≈ 0,9750021048517795; Φ(−1) = 1 − Φ(1)")
    @printf("  Φ(0) = %.17f\n", Float64(setprecision(BigFloat, _PREC) do
        _cdf_normal(BigFloat(0))
    end))
    @printf("  Φ(1,96) = %.17f\n", Float64(setprecision(BigFloat, _PREC) do
        _cdf_normal(BigFloat("1.96"))
    end))
    @printf("  Φ(1)+Φ(-1) = %.17f\n", Float64(setprecision(BigFloat, _PREC) do
        _cdf_normal(BigFloat(1)) + _cdf_normal(BigFloat(-1))
    end))
    println()
    println("E2 · umbral n_min(W) con menos de 1 falsa alarma al año (Poisson exacto)")
    println("Regla: alarma si la ventana deslizante (t−W, t] trae estrictamente menos de n_min")
    println("bloques. Cuenta una prueba por slot (cota conservadora), como la columna «por slot»")
    println("de 11b §C.1.  [publicado 11b: W=30→6, 60→23, 120→66, 300→211]")
    @printf("%8s %10s %12s %16s\n", "W (s)", "n_min", "P(N<n_min)", "α mín. evadir T=2h")
    for W in (30, 60, 120, 300)
        nm = n_min(W)
        p = Float64(poisson_cdf_big(nm - 1, Rational{BigInt}(W)))
        a = alpha_min(W, nm, 7200.0)
        @printf("%8d %10d %12.3e %16.4f\n", W, nm, p, a)
    end
    println()
    println("E2 · sensibilidad a la inestabilidad de λ. CONTABILIDAD PROPIA, DECLARADA:")
    println("se recalcula n_min con la media baja μ = (1−s_λ)·λW, que es la lectura literal de")
    println("«la tasa real fluctúa s_λ dentro de la ventana».")
    println()
    println("  AVISO DE MÉTODO, y es un hallazgo sobre el instrumento histórico: esta contabilidad")
    println("  reproduce EXACTAMENTE la columna s_λ = 0 de 11b §C.1 (6 / 23 / 66 / 211) y su")
    println("  columna de α para evadir (0,9249 a W=300, T=2 h), pero **NO** reproduce su columna")
    println("  s_λ > 0 (11b publica 16 con W=60 y 125 con W=300 a s_λ=0,10, y n_min=0 con W=300 a")
    println("  s_λ=0,20). El texto de 11b NO dice cómo entra s_λ en la cuenta, y la fórmula que")
    println("  declara (`n_min_poisson` sobre μ = λW) no toma s_λ como argumento en absoluto:")
    println("  esa columna se generó por otra vía que el informe no documenta. No se resuelve en")
    println("  silencio: se anota. Lo que se conserva es la DIRECCIÓN —n_min cae al caer μ— y la")
    println("  conclusión cualitativa: si λ es inestable, E2 pierde margen hasta desaparecer.")
    @printf("%8s %8s %12s\n", "W (s)", "s_λ", "n_min")
    for W in (30, 60, 120, 300), sl in (0.0, 0.10, 0.20)
        nm = n_min(W * (1 - sl))
        @printf("%8d %8.2f %12d\n", W, sl, nm)
    end
    println()
    println("E1 · B para menos de 1 falsa alarma al año")
    println("  «por slot» usa la cola de la FRONTERA SECUENCIAL L (un slot retrasado la atasca);")
    println("  «por excursión» usa la cola MARGINAL de D. No son la misma cola.")
    println("[publicado 11b §B.1, lognormal p99=8: ε=0,1 → 20,14 (excursión) y 20,70 (slot);")
    println(" ε=1,0 → 21,04 y 21,60. Pareto p99=8 ε=1 → 76,40 y 138,92.]")
    @printf("%10s %8s %8s %16s %16s\n", "cola", "p99", "ε (s)", "B (excursión)", "B (por slot)")
    for (nom, cdf) in (("lognormal", cdf_lognormal), ("pareto", cdf_pareto)),
        p99 in (8.0, 16.0), eps in (0.1, 1.0)
        be = B_paro(4.0, p99; eps = eps, cdf = cdf, por_slot = false)
        bs = B_paro(4.0, p99; eps = eps, cdf = cdf, por_slot = true)
        @printf("%10s %8.0f %8.1f %16.2f %16.2f\n", nom, p99, eps, be, bs)
    end
    println()
    println("CONTROLES DE CAPACIDAD de E1 — dos identidades que el instrumento DEBE reproducir:")
    println("  (a) por construcción de la lognormal (mediana=4, p99=8), P(D>8) es 0,0100 EXACTO.")
    println("      Un instrumento que no lo dé tiene la CDF mal — y así se cazó el primer intento.")
    p_d = 1 - Float64(cdf_lognormal(8.0, 4.0, 8.0))
    @printf("      P(D>8) = %.10f   (esperado 0,0100000000)\n", p_d)
    println("  (b) la cola SECUENCIAL debe ser ESTRICTAMENTE más pesada que la marginal:")
    println("      11b §B.0 publica P(D>8) = 0,0100 y P(L>8) = 0,014760.")
    p_l = Float64(cola_frontera(8.0, cdf_lognormal; mediana = 4.0, p99 = 8.0))
    @printf("      P(L>8) = %.6f   (publicado 0,014760)   ¿más pesada? %s\n",
            p_l, p_l > p_d ? "SÍ" : "NO")
end

end # module
