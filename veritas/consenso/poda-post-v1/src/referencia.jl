# PPP-v0.1 — referencia: oráculos transparentes, sin optimización, para casos pequeños.
# Independientes del kernel de rapido.jl y de la fórmula cerrada de modelo.jl cuando el
# dominio lo permite (enumeración exhaustiva en un modelo escalado).

# ---------------------------------------------------------------------------
# Oráculo 1 — enumeración exhaustiva en un modelo escalado (M pequeño). No usa la
# fórmula de p_min_leq: recorre TODAS las C-tuplas y cuenta. Sirve para comprobar que
# la fórmula cerrada describe el proceso, no solo a sí misma.
# ---------------------------------------------------------------------------

struct ResultadoExhaustivo
    M::Int
    C::Int
    SR::Int
    Lmax::Int
    conteo::Vector{BigInt}   # conteo por nivel 1..Lmax
    total::BigInt            # bloques válidos
end

function oraculo_exhaustivo(Mvals::Integer, C::Integer, SR::Integer; Lmax::Integer=8)
    Mvals >= 1 && C >= 1 || error("M, C ≥ 1")
    idx = zeros(Int, C)
    total = big(0)
    conteo = zeros(BigInt, Lmax)
    while true
        d = Mvals - 1
        for v in idx
            v < d && (d = v)
        end
        if d <= (SR >> 1)
            total += 1
            L = 1
            while L < min(Lmax, 63) && d <= (SR >> (L + 1))
                L += 1
            end
            conteo[L] += 1
        end
        k = 1
        while k <= C && idx[k] == Mvals - 1
            idx[k] = 0
            k += 1
        end
        k > C && break
        idx[k] += 1
    end
    return ResultadoExhaustivo(Mvals, C, SR, Lmax, conteo, total)
end

"""Probabilidad exhaustiva de que el nivel sea EXACTAMENTE `L`."""
function p_exhaustiva(r::ResultadoExhaustivo, L::Integer)
    r.total == 0 && return big(0)//big(1)
    (1 <= L <= r.Lmax) || error("L fuera de rango")
    return r.conteo[L] // r.total
end

"""
Probabilidad exhaustiva de que el nivel sea `≥ L`. Es la magnitud que describe
`solution_distance ≤ SR/2^L` y la que se compara con la fórmula cerrada.
"""
function p_exhaustiva_ge(r::ResultadoExhaustivo, L::Integer)
    r.total == 0 && return big(0)//big(1)
    (1 <= L <= r.Lmax) || error("L fuera de rango")
    return sum(r.conteo[L:end]; init=big(0)) // r.total
end

# ---------------------------------------------------------------------------
# Oráculo 2 — construcción de anclaje. Dos historias con el MISMO multiconjunto de
# soluciones (slot, distancia) y por tanto el MISMO certificado de niveles, pero distinta
# ancestría. El certificado es, por construcción, función solo de (slot, solución).
# ---------------------------------------------------------------------------

"""
Una solución ya resuelta: `slot`, `d` (solution_distance) y `SR` contextual. El nivel se
calcula con `nivel(d, SR)`; NO interviene ningún padre.
"""
struct Solucion
    slot::UInt64
    d::UInt64
    SR::UInt64
end

struct BloqueNivel
    slot::UInt64
    nivel::Int
    id::UInt64
end

struct Certificado
    bloques::Vector{BloqueNivel}   # orden no decreciente por slot (como en la cadena)
end

"""Certificado de niveles de una lista de soluciones; ignora por completo los padres."""
function certificado_de_soluciones(sols::Vector{Solucion})
    bs = [BloqueNivel(s.slot, nivel(s.d, s.SR), UInt64(i)) for (i, s) in enumerate(sols)]
    sort!(bs; by=b -> b.slot)
    return Certificado(bs)
end

"""
Verificador de certificado de niveles: comprueba (i) slots no decrecientes, (ii) todos
los niveles ≥ 1, (iii) que en la ventana `[slot_i, slot_i + ventana]` de CADA bloque `i`
haya al menos `cuota` bloques con nivel ≥ `Lreq` (los bloques están ordenados por slot, así
que la ventana es un rango contiguo). Es el verificador más fuerte que puede escribirse
mirando SOLO el certificado; no puede mirar la ancestría porque no la tiene.
"""
function verifica_certificado_niveles(cert::Certificado, Lreq::Integer, cuota::Integer,
                                      ventana::Integer)
    bs = cert.bloques
    isempty(bs) && return false
    for i in 2:length(bs)
        bs[i].slot < bs[i - 1].slot && return false
    end
    all(b -> b.nivel >= 1, bs) || return false
    for i in eachindex(bs)
        c = 0
        for j in eachindex(bs)
            (bs[j].slot >= bs[i].slot && bs[j].slot <= bs[i].slot + UInt64(ventana)) || continue
            bs[j].nivel >= Lreq && (c += 1)
        end
        c >= cuota || return false
    end
    return true
end

"""
Dos bloques con la MISMA solución y distinta lista de padres. Devuelve los dos
certificados (idénticos) y los dos conjuntos de padres. El nivel no depende de ellos.
"""
function dos_historias_misma_solucion(sol::Solucion, padres_a::Vector{UInt64},
                                      padres_b::Vector{UInt64})
    ca = certificado_de_soluciones([sol])
    cb = certificado_de_soluciones([sol])
    return (ca, padres_a, cb, padres_b)
end

# ---------------------------------------------------------------------------
# Oráculo 3 — coste de molienda si el nivel se define sobre el hash de cabecera.
# Nivel L = L ceros iniciales ⇒ P = 2^{−L} ⇒ 2^L hashes esperados, coste CPU y CERO
# espacio. `hps` = hashes/s medidos o declarados.
# ---------------------------------------------------------------------------

coste_molido_hash(L::Integer, hps::Real) = 2.0^L / hps

# ---------------------------------------------------------------------------
# Oráculo 4 — crecimiento lineal de cabeceras (sin poda).
# ---------------------------------------------------------------------------

function tabla_crecimiento(; bps::Real=1.0, bytes_cab::Real=748.0,
                           mergeset_limit::Integer=180)
    cab, bytes, reach = crecimiento_cabeceras(bps, bytes_cab, mergeset_limit)
    return (cab_ano=cab, gb_ano=bytes / 1e9, reach_ano=reach)
end
