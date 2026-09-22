# PRV-v0.1 — referencia: recomputación transparente, desde la definición del SPEC, de
# las cantidades que el kernel lee del oráculo GDR-v0.2. Sirve para acreditar el conteo
# en DAGs pequeños, no para rendimiento.

"""Pasado estricto de cada bloque a partir de la lista de padres (1-based, acíclica)."""
function pasado_estricto(padres::Vector{Vector{Int}})
    n = length(padres)
    past = [Set{Int}() for _ in 1:n]
    for i in 1:n
        for p in padres[i]
            push!(past[i], p)
            union!(past[i], past[p])
        end
    end
    return past
end

"¿`a` es ancestro estricto de `b`?"
ancestro(past::Vector{Set{Int}}, a::Int, b::Int) = a in past[b]

"""
Mergeset de `B` según C-GD-04: `past(B) \\ (past(sp(B)) ∪ {sp(B)})`, por operaciones de
conjunto, SIN leer los campos GHOSTDAG de `est`. `sp` es la única entrada del oráculo.
"""
function mergeset_referencia(past::Vector{Set{Int}}, i::Int, sp::Int)
    ms = Set{Int}()
    for x in past[i]
        (x == sp || x in past[sp]) && continue
        push!(ms, x)
    end
    return ms
end

"""
`|anticone(x) ∩ blueset|` para `x` y un `blueset` explícito, desde la definición:
`b` está en el anticono de `x` si ni `b ∈ past(x)` ni `x ∈ past(b)`.
"""
function anticono_en(past::Vector{Set{Int}}, x::Int, blueset)
    c = 0
    for b in blueset
        b == x && continue                    # el propio x no cuenta (semántica de `tam` GDR)
        (ancestro(past, b, x) || ancestro(past, x, b)) && continue
        c += 1
    end
    return c
end

"""
Comprueba, de forma independiente al kernel, que las cantidades que éste leerá del
oráculo coinciden con la definición para un DAG pequeño:
- el mergeset por conjuntos coincide con `gd[i].ms_ordenado`;
- `sum(values(gd[i].tam))` coincide con Σ_x |anticone(x) ∩ blueset(B)| recomputado.
Devuelve `(ok, detalle)`.
"""
function verificar_estructura_independiente(est)
    past = pasado_estricto(est.padres)
    for i in 1:est.n
        gd = est.gd[i]
        sp = gd.sp
        ms = mergeset_referencia(past, i, sp)
        ms_stored = Set(gd.ms_ordenado)
        ms == ms_stored || return (false, "mergeset distinto en bloque $i")
        # tam se define sobre el blueset FINAL de past(B) ∪ {B}
        blueset = gd.blueset
        reconstruido = 0
        for x in blueset
            reconstruido += anticono_en(past, x, blueset)
        end
        almacenado = sum(values(gd.tam); init=0)
        almacenado == reconstruido ||
            return (false, "tam distinto en bloque $i: $almacenado ≠ $reconstruido")
    end
    return (true, "estructura verificada en $(est.n) bloques")
end
