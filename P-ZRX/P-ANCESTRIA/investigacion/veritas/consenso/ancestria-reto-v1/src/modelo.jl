#=  modelo.jl — ANR-v0.1

Modelo del reto anclado a la ancestría a profundidad `d`.

## Objeto

`d` = profundidad del objeto de ancestría del que depende el reto (`d = 0`: el padre
seleccionado; `d → ∞`: sólo el flujo, que es lo de hoy). Se escribe `c := d + 1`, el número de
niveles del árbol privado del atacante que **comparten reto** (ventana de reutilización).

## De dónde sale todo (procedencia, no invención)

`Lambda`, `dLambda`, la ecuación (39) y `phi_c` son **literalmente** el aparato del Anexo F y
§5.4 de BDK+19 (*Proof-of-Stake Longest Chain Protocols: Security vs Predictability*,
arXiv 1910.02218v3), leído en `research/fuentes/bdk19.txt`:

    Lambda_c(t)  = -log(-t) - (c-1)*log(1-t)            (lambda = 1, Anexo F)
    ecuacion39   : Lambda_c(t) = t * Lambda'_c(t)
    phi_c        = -c*t* / (log(-t*) + (c-1)*log(1-t*)) = c*t*/Lambda_c(t*)

con `t* < 0` la raíz negativa única de (39). `phi_c * lambda_a` es la tasa de crecimiento del
árbol privado; el umbral de seguridad con retardo nulo es `1/(1+phi_c)`. BDK+19 tabula
`phi_1 = e` y `phi_inf = 1`, de modo que el umbral va de `1/(1+e) = 26,8941 %` a `1/2`.

**El control obligatorio del encargo es ese extremo:** `d = 0` ⟹ `c = 1` ⟹ `phi_1 = e` ⟹
`umbral = 26,8941421369995… %`.

## Qué es hipótesis y qué es demostración

- **Demostrado en este fichero**: `phi_1 = e` exacto (la raíz de (39) con `c = 1` es `-e`, y se
  sustituye a mano, no numéricamente); monotonía y límites de `phi_c` (ver `validacion.jl`).
- **Derivado**: la reducción `d ⟷ c = d + 1`. Se apoya en el lema de ventana que se enuncia y
  se comprueba exhaustivamente en `referencia.jl` (`ventana_*`), y en la estructura de (39),
  que cuenta precisamente niveles del árbol privado entre actualizaciones de aleatoriedad.
- **No determinado aquí**: que la regla *literal* de diseño (reto dependiente del ancla **y** del
  slot, C-POT-03) se identifique *exactamente* con la c-correlación de BDK. La dirección del
  error está declarada en `INFORME.md`: la regla literal da aleatoriedad fresca adicional dentro
  de la ventana, así que el umbral derivado es una **cota superior** de la seguridad.

Ningún número de este fichero es un parámetro de consenso: `d`, `c`, `I`, `L`, `F`, `k`, `P` son
entradas.
=#

"Cota superior de la profundidad: `d = inf` (reto = flujo vigente, el diseño de hoy)."
const D_INF = typemax(Int)

"Factor de c-correlación mínimo admitido (c = d + 1 ≥ 1)."
const C_MIN = 1

# ---------------------------------------------------------------- ecuación (39)

"`Lambda_c(t)` del Anexo F de BDK+19 con `lambda = 1`."
Lambda(c::Integer, t) = -log(-t) - (c - 1) * log(1 - t)

"`Lambda'_c(t)`."
dLambda(c::Integer, t) = -1 / t + (c - 1) / (1 - t)

"Residuo de la ecuación (39): `Lambda_c(t) - t*Lambda'_c(t)`. Cero en `t*`."
function ecuacion39(c::Integer, t)
    c >= C_MIN || throw(ArgumentError("c ≥ 1"))
    return Lambda(c, t) - t * dLambda(c, t)
end

#=  Evaluación CERTIFICADA del signo de (39).

No se usa `Rational` (hay logaritmos) ni aritmética de bolas de una dependencia externa. Se
evalúa a precisión `prec + 128` y se compara contra una cota de error conservadora: MPFR redondea
correctamente cada operación, y aquí hay menos de diez, así que el error absoluto total está
acotado por `2^-(prec+120)`. Si el residuo supera esa cota, el signo es concluyente.
=#
function signo_ec39(c::Integer, t::BigFloat; prec::Int=384)
    return setprecision(BigFloat, prec + 128) do
        tt = BigFloat(t)
        v = -log(-tt) - (c - 1) * log(1 - tt) + 1 - (c - 1) * tt / (1 - tt)
        cota = BigFloat(2)^(-(prec + 120))
        abs(v) > cota ? (v > 0 ? 1 : -1) : 0
    end
end

#=  Recinto certificado de la raíz negativa `t*` de (39).

Barrido exponencial para acotar (F -> +inf cuando t -> 0-, F -> -inf cuando t -> -inf para todo
c >= 1) y bisección hasta anchura `2^-(prec-40)`. Devuelve `(lo, hi)` con signos opuestos
certificados y `lo < hi < 0`.
=#
function recinto_theta(c::Integer; prec::Int=384)
    c >= C_MIN || throw(ArgumentError("c ≥ 1"))
    return setprecision(BigFloat, prec + 128) do
        hi = BigFloat(-1) / BigFloat(2)^20
        # F(hi) > 0 para |hi| suficientemente pequeño (F -> +inf al acercarse a 0 por la izquierda)
        intentos = 0
        while signo_ec39(c, hi; prec=prec) <= 0
            hi /= 2
            intentos += 1
            intentos > 200 && error("no se halló cota superior con F > 0 (c=$c)")
        end
        lo = BigFloat(-1)
        intentos = 0
        while signo_ec39(c, lo; prec=prec) >= 0
            lo *= 2
            intentos += 1
            intentos > 4000 && error("no se halló cota inferior con F < 0 (c=$c)")
        end
        slo = signo_ec39(c, lo; prec=prec)
        shi = signo_ec39(c, hi; prec=prec)
        @assert slo * shi < 0
        while (hi - lo) > BigFloat(2)^(-(prec - 40))
            mid = (lo + hi) / 2
            smid = signo_ec39(c, mid; prec=prec)
            if smid == 0
                # residuo por debajo de la cota: se estrecha el recinto alrededor de mid
                lo = mid - BigFloat(2)^(-(prec - 30))
                hi = mid + BigFloat(2)^(-(prec - 30))
                break
            elseif smid == slo
                lo = mid
                slo = smid
            else
                hi = mid
                shi = smid
            end
        end
        return (lo, hi)
    end
end

"Punto medio del recinto de `t*` (sólo para presentación; el recinto es la fuente de verdad)."
theta_estrella(c::Integer; prec::Int=384) = (r = recinto_theta(c; prec=prec); (r[1] + r[2]) / 2)

# ---------------------------------------------------------------- phi_c y umbral

"`phi_c` en la forma del paper, evaluada en `t`. Positiva para `t` en el recinto de `t*`."
function phi_c_en(c::Integer, t::BigFloat)
    den = log(-t) + (c - 1) * log(1 - t)      # = -Lambda_c(t)
    return -c * t / den
end

"""
    phi_c(c; prec=384) -> (lo, hi)

Recinto certificado de `phi_c`. Se evalúa en los dos extremos del recinto de `t*` y se toma
min/max; el recinto es tan estrecho (anchura `≈ 2^-(prec-40)`) que la variación de `phi` dentro
de él es despreciable frente a las cifras publicadas. `phi` es monótona en `t` sobre el recinto
(comprobado densamente en `validacion.jl`).
"""
function phi_c(c::Integer; prec::Int=384)
    lo, hi = recinto_theta(c; prec=prec)
    a = phi_c_en(c, lo)
    b = phi_c_en(c, hi)
    return (min(a, b), max(a, b))
end

"Punto medio de `phi_c` (presentación)."
phi_c_medio(c::Integer; prec::Int=384) = (r = phi_c(c; prec=prec); (r[1] + r[2]) / 2)

"Umbral de seguridad `1/(1+phi_c)` con retardo nulo (Delta = 0), en recinto."
function umbral_c(c::Integer; prec::Int=384)
    lo, hi = phi_c(c; prec=prec)
    a = 1 / (1 + hi)
    b = 1 / (1 + lo)
    return (min(a, b), max(a, b))
end

umbral_c_medio(c::Integer; prec::Int=384) = (r = umbral_c(c; prec=prec); (r[1] + r[2]) / 2)

#=  Forma con retardo, ec. (38)/(5.4) de BDK+19:  beta_c = e^(-lh*Delta) / (e^(-lh*Delta) + phi_c).
    `Delta` y `lh` son SÍMBOLOS: aquí se dan como argumentos, nunca como constantes.  =#
function umbral_c_retardo(c::Integer, lh, Delta; prec::Int=384)
    e = exp(-BigFloat(lh) * BigFloat(Delta))
    lo, hi = phi_c(c; prec=prec)
    a = e / (e + hi)
    b = e / (e + lo)
    return (min(a, b), max(a, b))
end

"""
    umbral_d(d; prec=384) -> (lo, hi)

`umbral(d)`: umbral de fracción adversarial tolerada bajo grinding, con el reto anclado a
profundidad `d`. `d = D_INF` es el diseño de hoy (reto = flujo): `1/2`.
"""
function umbral_d(d::Integer; prec::Int=384)
    d < 0 && throw(ArgumentError("d ≥ 0"))
    d == D_INF && return (big(1)//big(2), big(1)//big(2))
    return umbral_c(d + 1; prec=prec)
end

umbral_d_medio(d::Integer; prec::Int=384) = (r = umbral_d(d; prec=prec); (r[1] + r[2]) / 2)

# ---------------------------------------------------------------- ventana y cobertura

"""
    ventana_reuso(d) -> Int

Número de bloques consecutivos de una rama privada, contados desde el ancestro común, que
**comparten el reto** con la rama pública. Es `c = d + 1`.

Demostración (lema de ventana): con `sigma(B) = ancestro de B a profundidad depth(B) - c`, dos
ramas con ancestro común último a profundidad `m` tienen `sigma` distinto en un bloque a
profundidad `n` si y sólo si `n - c > m`; luego comparten reto exactamente en `n ∈ (m, m+c]`.
"""
ventana_reuso(d::Integer) = d == D_INF ? typemax(Int) : d + 1

"Bloques de una rama privada de longitud `L` (desde el ancestro común) que comparten reto."
bloques_compartidos(d::Integer, L::Integer) = min(L, ventana_reuso(d))

"Bloques de esa rama con reto propio (separados del de la rama pública)."
bloques_separados(d::Integer, L::Integer) = L - bloques_compartidos(d, L)

"""
    cobertura_rama(d, L) -> Float64

Fracción de los `L` bloques de una rama privada que quedan **separados** del reto público.
`L` es la longitud de la rama en bloques: es una ENTRADA, no una constante.
"""
function cobertura_rama(d::Integer, L::Integer)
    L <= 0 && throw(ArgumentError("L ≥ 1"))
    return bloques_separados(d, L) / L
end

"""
    c_para_umbral(beta; cmax, prec) -> Union{Int,Nothing}

Menor `c ≥ 1` tal que `1/(1+phi_c) ≥ beta`. Devuelve `nothing` si no se alcanza con `c ≤ cmax`.
Como `phi_c ↓ 1`, el máximo alcanzable es `< 1/2`.
"""
function c_para_umbral(beta; cmax::Integer=10^9, prec::Int=256)
    beta >= 1 // 2 && return nothing
    lo, hi = 1, 2
    while hi <= cmax && umbral_c_medio(hi; prec=prec) < beta
        lo = hi
        hi *= 2
    end
    hi > cmax && return nothing
    while lo + 1 < hi
        mid = (lo + hi) ÷ 2
        if umbral_c_medio(mid; prec=prec) >= beta
            hi = mid
        else
            lo = mid
        end
    end
    return hi
end
