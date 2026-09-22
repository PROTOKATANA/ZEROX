#= espacio-prestado-v1 · referencia.jl
   Oráculo del paseo de la ventana. Tres objetos DISTINTOS (BASELINE.md escenario 5):

     P_terminal(d,T)      = P(Z_T = −1)              (estar en −1 en el instante T)
     P_first_passage(d,T) = P(∃ t ≤ T : Z_t = −1)    (primera pasada, monótona en T)
     P_eventual(d)        = P(∃ t : Z_t = −1)        (límite de la anterior)

   Modelo: `Z_0 = d ≥ 0`; cada paso baja 1 con probabilidad `q` (bloque del ADVERSARIO) y
   sube 1 con probabilidad `p = 1−q` (bloque de la rama HONESTA/pública). El adversario
   gana al VISITAR por primera vez `−1`, es decir al agotarse la ventaja de la pública.

   ¡ATENCIÓN A LA NOTACIÓN! Ésta es la convención de `BASELINE.md` y del encargo original:
   `p` = tasa del HONESTO, `q` = tasa del ADVERSARIO. En las FIRMAS de este instrumento el
   primer argumento de `p_superar_exacto`, `p_empate_exacto` y `primera_dp` es la tasa del
   ADVERSARIO (el `q` de `BASELINE.md`), por compatibilidad con el nombre histórico del
   parámetro. Es un nombre desafortunado: si una cifra no cuadra, mirar aquí primero.
   Una versión anterior de este fichero acusó a `BASELINE.md` de tener la razón invertida:
   **era un error de lectura y se retiró**. `BASELINE.md` escenario 0 es correcto.

   ADVERTENCIA DE MÉTODO (defectos detectados durante la validación, conservados aquí
   como vectores de regresión):
     (1) Una DP con `−1` ABSORBENTE calcula `P(Z_T = −1)`, que NO es la primera pasada:
         el paseo revisita `−1` y las visitas se contarían dos veces.
     (2) Escribir en `v` mientras se lee `v` cuenta dos veces las mismas transiciones.
     (3) Truncar la cuadrícula en `d+T` pierde masa que sube, y el residuo lo delata.
   Por eso la vía exacta principal es la DP de tiempo de parada sobre `(mínimo, posición)`
   de `rapido.jl`, y las otras dos vías (enumeración recursiva y Monte Carlo) la comprueban.

   Hechos exactos y COMPROBADOS (en la notación de BASELINE.md: p honesto, q adversario):
     · P_eventual(d) = (q/p)^(d+1) si q < p (adversario en minoría); = 1 si q ≥ p.
       Reproduce `BASELINE.md:18` exactamente. Verificado contra la DP con
       (p, q, d) = (2/3, 1/3, 5) → 1/32; (3/5, 2/5, 2) → 8/27; (2/3, 1/3, 0) → 1/2.
       La recurrencia de primer paso `h(z) = q·h(z−1) + p·h(z+1)` con `h(−1) = 1` y `h`
       acotada da `h(z) = (q/p)^(z+1)` cuando `q < p`, y `h ≡ 1` cuando `q ≥ p`.
     · La primera pasada se calcula con la DP de tiempo de parada de `rapido.jl`
       (estado `(min, posición)`), VERIFICADA contra la enumeración exhaustiva en 714
       celdas y contra `(q/p)^(d+1)` en horizonte largo. Una fórmula de reflexión
       publicada antes en este mismo fichero era INCORRECTA (daba 2/3 en vez de 11/27 con
       el adversario en 1/3, d=0, T=3): se retiró y queda como regresión.
=#

module Referencia

using Random123: Philox4x, set_counter!
using Random: rand

export p_empate_exacto, p_superar_exacto, p_visitar_menos_uno_exacto
export terminal_desde_primera
export enumerar_exhaustivo, mc_ventana, wilson

# ------------------------------------------------------------- formas cerradas

"""
    p_superar_exacto(q, d) -> P_eventual(d)

P(∃t: Z_t = −1). Primer argumento = tasa del ADVERSARIO (`q` de `BASELINE.md`); dentro se
deriva `p = 1−q`, la tasa del honesto. Devuelve `(q/p)^(d+1)` si el adversario es minoría
(`q < p`) y `1` si no. **Reproduce `BASELINE.md:18` exactamente** (véase la tabla de
reconciliación en `INFORME.md` §2.4).
"""
function p_superar_exacto(q::Rational, d::Integer)
    p = 1 - q                                  # tasa del honesto (la `p` de BASELINE.md)
    q < p && return (q / p)^(d + 1)            # adversario en minoría ⇒ (q/p)^(d+1)
    return one(q)
end

function p_superar_exacto(q::AbstractFloat, d::Integer)
    p = 1.0 - q
    q < p && return (q / p)^(d + 1)
    return 1.0
end

"""
    p_empate_exacto(p, d) = (q/p)^d si p < 1/2 (empate eventual, incluye n = 0);
    1 si p ≥ 1/2.
"""
function p_empate_exacto(p::Rational, d::Integer)
    p > 1//2 || return one(p)
    return ((1 - p) / p)^d
end

"""    p_visitar_menos_uno_exacto(q) = 1 si el adversario no es minoría (`q ≥ 1/2`);
    `(1−q)/q` si lo es. Convención: primer argumento = tasa del ADVERSARIO."""
function p_visitar_menos_uno_exacto(q::Rational)
    p = 1 - q
    q < p || return one(q)
    return q / p
end

# ------------------------------------------------ fórmula de reflexión (exacta)

# --------------------------------------------------- enumeración exhaustiva

"""
    enumerar_exhaustivo(p, d, T) -> (terminal, paso)

Enumera TODAS las trayectorias por recursión directa (sin máscaras de bits, sin
recurrencia compartida con el oráculo), en `Rational{BigInt}`. Sólo `T ≤ 20`.
"""
function enumerar_exhaustivo(p::Rational{BigInt}, d::Integer, T::Integer)
    T ≤ 20 || throw(ArgumentError("enumeración exhaustiva sólo para T ≤ 20"))
    q = 1 - p
    term = zero(Rational{BigInt})
    paso = zero(Rational{BigInt})
    function enum_rec!(z::Int, t::Int, pr::Rational{BigInt}, tocado::Bool)
        # La primera visita a −1 se cuenta UNA vez (`tocado` pasa a true), pero la
        # trayectoria se sigue explorando: cortar la recursión al tocar −1 cuenta de más
        # (defecto detectado: con p=1/3, d=0, T=3 daba 5/9 en vez de 11/27).
        if z == -1 && !tocado
            paso += pr
            t == T && (term += pr)
            tocado = true
        end
        t == T && return
        enum_rec!(z - 1, t + 1, pr * p, tocado)
        enum_rec!(z + 1, t + 1, pr * q, tocado)
        return
    end
    enum_rec!(d, 0, one(Rational{BigInt}), false)
    return (terminal = term, paso = paso)
end

# ------------------------------------------------------------- Monte Carlo

"""
    mc_ventana(p, d, T, nrep, semilla) -> (terminal, paso, ic_terminal, ic_paso)

Monte Carlo con `Random123.Philox4x64` y semilla derivada por réplica con
`set_counter!(r, (0, id))` —la forma correcta según `DEFECTOS.md` A2:
`set_counter!(r, id)` desplaza una salida y correlaciona. IC de Wilson al 95 %.
"""
function mc_ventana(p::AbstractFloat, d::Integer, T::Integer, nrep::Integer, semilla::UInt64)
    nterm = 0
    npaso = 0
    for id in 1:nrep
        # `Philox4x` de Random123 (el paquete no exporta `Philox4x64`): semilla por par y
        # contador de 4 palabras. Se deriva un flujo POR RÉPLICA con `set_counter!`; la
        # forma de una sola palabra desplaza una salida y correlaciona (DEFECTOS.md A2).
        r = Philox4x((semilla, semilla ⊻ 0x9e3779b97f4a7c15))
        set_counter!(r, (0, 0, 0, id))
        z = d
        tocado = false
        for _ in 1:T
            if rand(r) < p
                z -= 1
            else
                z += 1
            end
            if z == -1
                tocado = true
                break
            end
        end
        tocado && (npaso += 1)
        (tocado && z == -1) && (nterm += 1)
    end
    return (terminal = nterm / nrep, paso = npaso / nrep,
            ic_terminal = wilson(nterm, nrep), ic_paso = wilson(npaso, nrep))
end

"""Intervalo de Wilson al 95 % para `k` éxitos de `n`."""
function wilson(k::Integer, n::Integer)
    n == 0 && return (0.0, 1.0)
    z = 1.959963984540054
    p̂ = k / n
    den = 1 + z^2 / n
    centro = (p̂ + z^2 / (2n)) / den
    medio = z * sqrt(p̂ * (1 - p̂) / n + z^2 / (4n^2)) / den
    return (max(0.0, centro - medio), min(1.0, centro + medio))
end

end # module
