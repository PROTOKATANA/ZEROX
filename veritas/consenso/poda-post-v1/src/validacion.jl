# PPP-v0.1 — validación: equivalencia entre la fórmula cerrada, la enumeración exhaustiva
# y el Monte Carlo; y comprobación de los invariantes de anclaje.

"""
Comprueba que `p_nivel_exacta` (fórmula cerrada con M = 2^63) coincide con la probabilidad
de un modelo ESCALADO calculada por enumeración exhaustiva. El modelo escalado usa M' y
SR' pequeños; la fórmula se evalúa con ese mismo M' (reescalado) para que la comparación
sea del álgebra, no del tamaño.
"""
function formula_escalada(L::Integer, SR::Integer, C::Integer, Mvals::Integer)
    # p_min_leq con M = Mvals (no 2^63)
    pmin(x) = x >= Mvals - 1 ? big(1)//big(1) : (x < 0 ? big(0)//big(1) :
              big(1) - ((big(Mvals) - 1 - x)//big(Mvals))^C)
    T1 = SR >> 1
    F1 = pmin(Int(T1))
    F1 == 0 && return big(0)//big(1)
    return pmin(Int(SR >> L)) // F1
end

"""Barrido exhaustivo vs fórmula escalada; devuelve las discrepancias (vacío = exacto)."""
function valida_formula_vs_exhaustiva(; Ms=(4, 6, 8), Cs=(1, 2, 3), SRs=(1, 3, 7, 15),
                                       Lmax=4)
    fallos = NamedTuple[]
    for M in Ms, C in Cs, SR in SRs
        SR <= M - 1 || continue          # SR debe caber en el modelo escalado
        r = oraculo_exhaustivo(M, C, SR; Lmax=Lmax)
        r.total == 0 && continue
        for L in 1:Lmax
            pe = p_exhaustiva_ge(r, L)
            pf = formula_escalada(L, SR, C, M)
            pe == pf || push!(fallos, (M=M, C=C, SR=SR, L=L, exhaustiva=pe, formula=pf))
        end
    end
    return fallos
end

# ---------------------------------------------------------------------------
# Invariantes de anclaje (§4 del INFORME): el nivel NO depende de los padres.
# ---------------------------------------------------------------------------

"""
Barrido de la construcción de anclaje: para cada par de conjuntos de padres, el nivel del
bloque es el mismo. Devuelve el número de pares comprobados y el número de discrepancias
(0 = el nivel es independiente de los padres, como exige el proceso).
"""
function valida_anclaje_independiente(; n=200, seed=UInt64(0x9A11A))
    rng = StableRNG(seed)
    discrepancias = 0
    for _ in 1:n
        SR = rand(rng, UInt64) >> 1
        sol = Solucion(rand(rng, UInt64), rand(rng, UInt64) >> 1, SR)
        pa = UInt64[rand(rng, UInt64) for _ in 1:2]
        pb = UInt64[rand(rng, UInt64) for _ in 1:3]
        ca, _, cb, _ = dos_historias_misma_solucion(sol, pa, pb)
        ca.bloques[1].nivel == cb.bloques[1].nivel || (discrepancias += 1)
    end
    return (casos=n, discrepancias=discrepancias)
end

# ---------------------------------------------------------------------------
# Certificado insuficiente: dos historias con el mismo certificado y distinta ancestría.
# El verificador de niveles (que es lo máximo comprobable sin el DAG) acepta ambas.
# ---------------------------------------------------------------------------

"""
Construye `k` soluciones "de nivel alto" (distancia forzada a 0 para el experimento) y
devuelve su certificado. Sirve para mostrar que ese certificado existe con independencia
de la historia a la que se pegue: el coste lo paga el espacio-tiempo global, no la rama.
"""
function certificado_falso_alto(k::Integer, Lreq::Integer; SR::UInt64=typemax(UInt64) >> 1,
                                slot0::Integer=0, ventana::Integer=10)
    sols = Solucion[Solucion(UInt64(slot0 + i), UInt64(0), SR) for i in 1:k]
    cert = certificado_de_soluciones(sols)
    ok = verifica_certificado_niveles(cert, Lreq, 1, ventana)
    return (certificado=cert, aceptado=ok, Lreq=Lreq, ventana=ventana)
end
