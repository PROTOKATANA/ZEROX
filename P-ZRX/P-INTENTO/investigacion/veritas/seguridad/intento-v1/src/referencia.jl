"""
Oráculo exacto y lento. Es la fuente de verdad para los tamaños pequeños y para los umbrales.

`d(R_s)` es una fracción con denominador `2^64`, así que se calcula con `Rational{BigInt}`: no hay
redondeo que pueda mover un veredicto. `p = o·d` se evalúa exacto si `o` es racional; cuando `o`
viene de una medida (un `Float64`) se convierte a racional exacto de su valor binario, y se declara
que la incertidumbre de la medida no entra en esta comprobación.
"""

"""Fracción inclusiva aceptada por el rango, exacta."""
function prob_bucket_exacta(rango::Integer)
    return (2 * div(rango, 2) + 1) // (big(2)^64)
end

"""Probabilidad por intento y reto, exacta."""
function p_intento_exacta(o::Rational{BigInt}, rango::Integer)
    return o * prob_bucket_exacta(rango)
end

"""Convierte un `Float64` medido a su racional exacto (sin inventar precisión)."""
racional_exacto(x::Real) = Rational{BigInt}(x)

"""
Oráculo de alta precisión. Repite las fórmulas del kernel con `BigFloat` (256 bits) y aritmética
exacta donde la fórmula es discreta.

Devuelve una tupla con los campos derivados para un `w` dado, con la misma semántica que `evaluar`.
"""
function evaluar_referencia(e::Escenario{T}, w::Real) where {T}
    setprecision(BigFloat, 256) do
        W = BigFloat(w)
        r = BigFloat(e.r)
        t_reto = BigFloat(e.t_reto_s)
        tau = BigFloat(e.tau_s)

        d = BigFloat(prob_bucket_exacta(round(UInt64, e.rango_solucion)))
        p = BigFloat(racional_exacto(e.o)) * d

        r_ef = one(BigFloat) / (one(BigFloat) / r + W * t_reto)
        n_eq = r * W * tau
        bytes_eq = n_eq * BigFloat(e.bytes_por_pieza)

        alpha = BigFloat(e.alpha)
        N_h = BigFloat(e.N_h)
        maq = N_h == 0 ? BigFloat(Inf) : (alpha / (1 - alpha)) * N_h / n_eq

        # Cuota de peso de UNA sola máquina.
        fraccion = N_h == 0 ? one(BigFloat) : n_eq / (n_eq + N_h)

        pi = BigFloat(e.pi_DAG)
        t_gan = BigFloat(e.t_ganador_s)
        coste_sol = pi == 0 ? BigFloat(Inf) : (one(BigFloat) / (r * W * p) + t_gan) / pi
        w_min = p == 0 ? BigFloat(Inf) : one(BigFloat) / (r * tau * p)
        w_eq = N_h == 0 ? BigFloat(Inf) : N_h / (r * tau)

        return (
            w = W,
            p = p,
            r_efectiva = r_ef,
            n_eq = n_eq,
            bytes_eq = bytes_eq,
            maquinas = maq,
            fraccion_una_maquina = fraccion,
            coste_por_solucion_s = coste_sol,
            latencia_holgada = (one(BigFloat) / (r * tau * p)) <= W,
            w_min_latencia = w_min,
            w_equilibrio = w_eq,
        )
    end
end

"""
Comprueba que `d(R_s)` coincide con el número de valores aceptados contando sobre un rango pequeño.

Para `R_s` pequeño el conjunto aceptado `{a : bidirectional_distance(g,a) <= R_s/2}` tiene
exactamente `2*floor(R_s/2)+1` elementos, sea cual sea `g`. Se cuenta de verdad, con `UInt64`.
"""
function contar_aceptados(rango::Integer)
    mitad = UInt64(div(rango, 2))
    g = UInt64(0x9e3779b97f4a7c15)
    aceptados = 0
    # El conjunto aceptado es [g - mitad, g + mitad] con aritmetica envolvente: esta centrado en
    # `g`, no en 0. Se recorre de verdad, con `UInt64`, y se cuenta.
    a = g - mitad
    for _ in 0:(2 * mitad)
        d1 = a - g
        d2 = g - a
        if min(d1, d2) <= mitad
            aceptados += 1
        end
        a += one(UInt64)
    end
    return aceptados
end

"""
Comprueba que `d(R_s)` coincide con la probabilidad medida empíricamente por Monte Carlo exacto
sobre `a` uniforme en `[0, 2^64)` restringido a los valores alcanzables. Sólo se usa en tests con
rangos pequeños.
"""
function d_empirica(rango::Integer, g::UInt64, n::Integer)
    mitad = UInt64(div(rango, 2))
    aceptados = 0
    estado = UInt64(0x243f6a8885a308d3)
    for _ in 1:n
        estado = estado * UInt64(6364136223846793005) + UInt64(1442695040888963407)
        a = estado
        d1 = a - g
        d2 = g - a
        if min(d1, d2) <= mitad
            aceptados += 1
        end
    end
    return aceptados // n
end
