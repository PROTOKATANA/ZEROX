"""
Equivalencia entre el kernel `Float64` y el oráculo `BigFloat`/exacto, e invariantes.

Criterio: error relativo <= 256 eps(Float64) en cada campo finito, y coincidencia exacta del signo
de los infinitos. Si un campo supera el umbral, la validación devuelve `false` y el informe declara
el resultado **inconcluso**, no redondeado a favor.
"""

const CAMPOS_COMPARADOS = (
    :p,
    :r_efectiva,
    :n_eq,
    :bytes_eq,
    :maquinas,
    :fraccion_una_maquina,
    :coste_por_solucion_s,
    :w_min_latencia,
    :w_equilibrio,
)

"""Compara un `Resultado` del kernel con el oráculo de alta precisión."""
function _comparar(rapido::Resultado{T}, referencia) where {T}
    max_error = 0.0
    rapido.latencia_holgada == referencia.latencia_holgada ||
        return false, Inf
    for campo in CAMPOS_COMPARADOS
        valor = Float64(getproperty(rapido, campo))
        ref = Float64(getproperty(referencia, campo))
        if isfinite(valor) && isfinite(ref)
            error = abs(valor - ref) / max(abs(ref), eps(Float64))
            max_error = max(max_error, error)
        elseif !(isinf(valor) && isinf(ref) && signbit(valor) == signbit(ref))
            return false, Inf
        end
    end
    return max_error <= 256eps(Float64), max_error
end

"""
Valida el kernel sobre una rejilla determinista de escenarios y valores de `w`.

Devuelve `(ok, max_error_relativo, n_comparaciones)`.
"""
function validar_referencia(casos::Vector{Tuple{Escenario{Float64},Float64}})
    peor = 0.0
    for (esc, w) in casos
        rapido = evaluar(esc, w)
        referencia = evaluar_referencia(esc, w)
        ok, error = _comparar(rapido, referencia)
        ok || return false, error, length(casos)
        peor = max(peor, error)
    end
    return true, peor, length(casos)
end

"""
Invariantes que deben cumplirse para todo escenario válido y todo `w > 0`:

1. `N_eq` es estrictamente creciente en `w` y en `r`.
2. `máquinas` es estrictamente decreciente en `w`.
3. `fraccion_una_maquina` es creciente en `w` y tiende a 1.
4. `coste_por_solución` es decreciente en `w`.
5. `r_efectiva ≤ r`, con igualdad exacta cuando `t_reto = 0`.
6. `w_min_latencia` es estrictamente decreciente en `r`.
7. Con `π_DAG = 1` el atacante nunca sale perjudicado respecto de `π_DAG < 1`.
"""
function comprobar_invariantes(e::Escenario{Float64}; pasos::Int = 64)
    ws = rejilla_w(1.0, 1.0e6, pasos)
    filas = [evaluar(e, w) for w in ws]

    all(diff([f.n_eq for f in filas]) .> 0) || return false, "N_eq no crece con w"
    all(diff([f.maquinas for f in filas]) .< 0) || return false, "maquinas no decrece con w"
    all(diff([f.fraccion_una_maquina for f in filas]) .> 0) ||
        return false, "fraccion no crece con w"
    all(diff([f.coste_por_solucion_s for f in filas]) .< 0) ||
        return false, "coste por solucion no decrece con w"
    # Con t_reto = 0 la igualdad es exacta, asi que el invariante es `<=`, no `<`.
    all([f.r_efectiva <= e.r * (1 + 1e-12) for f in filas]) ||
        return false, "r_efectiva supera r"

    e_sin_reto = con(e; t_reto_s = 0.0)
    abs(evaluar(e_sin_reto, 1.0).r_efectiva - e.r) <= 1e-12 ||
        return false, "r_efectiva no tiende a r con t_reto = 0"

    r2 = con(e; r = 2e.r)
    evaluar(r2, 1.0).w_min_latencia < evaluar(e, 1.0).w_min_latencia ||
        return false, "w_min no decrece con r"

    e_pi = con(e; pi_DAG = 0.5)
    evaluar(e_pi, 1.0).coste_por_solucion_s > evaluar(e, 1.0).coste_por_solucion_s ||
        return false, "pi_DAG < 1 no encarece la solucion"

    return true, "ok"
end
