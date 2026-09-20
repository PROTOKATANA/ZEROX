# Reducciones deterministas sobre las replicas y comprobaciones de equivalencia.

"""
    resumen_absorcion(cs) -> NamedTuple

Reduce un vector de `Camino` **en orden de id** (reduccion determinista, LINEO §7): fraccion
censurada, mediana y media del instante de absorcion sobre las no censuradas, y la fraccion de
replicas con **divergencia** —dos nodos bloqueados en flujos distintos— con su intervalo de
Clopper–Pearson exacto.

La media se calcula solo sobre las no censuradas y se acompana siempre de la fraccion censurada:
una media condicionada sin su censura es la forma clasica de convertir un horizonte corto en un
resultado optimista.
"""
function resumen_absorcion(cs::AbstractVector{Camino}; α::Float64=0.05)
    n = length(cs)
    ts = Float64[]
    ncens = 0
    ndiv = 0
    for c in cs                              # orden de id: determinista
        c.censurado ? (ncens += 1) : push!(ts, c.t_absorcion)
        c.divergencia && (ndiv += 1)
    end
    sort!(ts)
    med = isempty(ts) ? NaN : ts[max(1, cld(length(ts), 2))]
    media = isempty(ts) ? NaN : sum(ts) / length(ts)
    dlo, dhi = clopper_pearson(ndiv, n, α)
    return (n=n, censurados=ncens / n, mediana=med, media=media,
            divergencia=ndiv / n, div_inf=dlo, div_sup=dhi)
end

"""
    resumen_ultimo_cambio(cs, T) -> NamedTuple

La magnitud del punto 4: el **instante del ultimo cambio de lider** dentro del horizonte `T`.
Devuelve media y mediana de `t_ultimo/T`, la fraccion de replicas sin ningun cambio, y la
fraccion con algun cambio despues de `T/2` y despues de un instante dado.
"""
function resumen_ultimo_cambio(cs::AbstractVector{Camino}, T::Real; t_ref::Real=600.0,
                               α::Float64=0.05)
    n = length(cs)
    TT = float(T)
    xs = Float64[]
    sin_cambio = 0
    despues = 0
    for c in cs
        c.cambios == 0 ? (sin_cambio += 1) : push!(xs, c.t_ultimo / TT)
        c.t_ultimo > float(t_ref) && (despues += 1)
    end
    sort!(xs)
    med = isempty(xs) ? NaN : xs[max(1, cld(length(xs), 2))]
    media = isempty(xs) ? NaN : sum(xs) / length(xs)
    plo, phi = clopper_pearson(despues, n, α)
    return (n=n, sin_cambio=sin_cambio / n, media_rel=media, mediana_rel=med,
            p_despues=despues / n, p_inf=plo, p_sup=phi, t_ref=float(t_ref), T=TT)
end

"""
    equivalencia_L(f, ts; tol_rel) -> Vector{NamedTuple}

Comprueba, para cada `t`, que el encierre del kernel rapido y la bola de Arb se **solapan** y que
el oraculo directo (solo `r = 1`) cae dentro del encierre. Devuelve la tabla, no un booleano: el
informe necesita ver la anchura.
"""
function equivalencia_L(f::Flujos, ts::AbstractVector{<:Real}; prec::Int=PREC)
    out = NamedTuple[]
    for t in ts
        lo, hi = prob_cambio_posterior(f, t)
        b = prob_cambio_posterior_arb(f, t; prec=prec)
        blo = Float64(Arblib.lbound(b)); bhi = Float64(Arblib.ubound(b))
        ref = canonico(f).r == 1 ? prob_cambio_posterior_ref(f, t)[1] : NaN
        push!(out, (t=float(t), rap_inf=lo, rap_sup=hi, arb_inf=blo, arb_sup=bhi, ref=ref,
                    solapa=!(hi < blo * (1 - 1e-10) || lo > bhi * (1 + 1e-10)),
                    ref_dentro=isnan(ref) ? true : (lo * (1 - 1e-6) <= ref <= hi * (1 + 1e-6))))
    end
    return out
end
