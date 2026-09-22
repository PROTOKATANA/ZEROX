#= espacio-prestado-v1 · rapido.jl
   Kernel de la primera pasada en régimen práctico (T hasta 7.200, d hasta miles), donde
   `(q/p)^(d+1)` subdesborda `Float64`.

   Objeto (véase `referencia.jl`):

     P_first_passage(d,T) = P(∃ t ≤ T : Z_t = −1),  Z = (trabajo público) − (trabajo privado)

   El paseo baja 1 con la probabilidad del ADVERSARIO y sube 1 con la del HONESTO;
   `primera_dp` absorbe en la primera visita a `−1` y devuelve también la masa interior,
   que permite comprobar `paso + interior = 1` en cada llamada.

   ¡NOTACIÓN! El primer argumento de `primera_dp` es la tasa del ADVERSARIO (el `q` de
   `BASELINE.md`, donde `p` es la del honesto). Nombre histórico conservado; declarado en
   la cabecera de `referencia.jl`. `BASELINE.md` escenario 0 es correcto y no se toca.

   Diseño numérico (LINEO §2 y §5.3):
   · DP de tiempo de parada sobre el estado `(mínimo, posición)`, `O(T·(d+1)·(d+T))`.
   · `BigFloat` a precisión declarada es la segunda vía, para certificar puntos de
     frontera. No es aritmética de bolas: es precisión arbitraria declarada.
   · Sin `@fastmath`, sin `@simd`, sin `Float32`, sin asignaciones en el bucle.
=#

module Rapido

export primera_dp, primera_bigfloat_dp, rejilla_dp, rejilla_dp_par
export eventual_float, rejilla_primera, rejilla_primera_par

"""
    primera_dp(p, d, T; H = d + T + 2) -> (P, masa_interior)

Primera pasada por DP exacta en estructura, sobre el estado `(m, z)`:
`m` = mínimo de los prefijos (incluido `Z_0`), `z` = posición actual. La trayectoria queda
absorbida la primera vez que `m` toca `−1`. Es una vía INDEPENDIENTE de la fórmula de
reflexión y directamente verificable: cada transición es un paso del paseo.

Cuadrícula: `m ∈ [−1, d]`, `z ∈ [−1, d+T]`, con tope superior de seguridad `H`. El estado
`z = −1` se trata como absorción (llegar a `−1` implica `m ≤ −1`). Devuelve también la
masa interior final (`≈ 0`), que sirve de control: si es grande, `H` se quedó corto.
"""
function primera_dp(p::T, d::Integer, Tsteps::Integer; H::Integer = d + Tsteps + 2) where {T<:Real}
    d ≥ 0 || throw(ArgumentError("d ≥ 0"))
    Tsteps ≥ 0 || throw(ArgumentError("T ≥ 0"))
    q = one(p) - p
    mmin, mmax = -1, d
    zmin, zmax = -1, H
    nz = zmax - zmin + 1
    nm = mmax - mmin + 1
    h = zeros(T, nm * nz)
    hn = zeros(T, nm * nz)
    @inline idx(m, z) = (m - mmin) * nz + (z - zmin) + 1
    h[idx(d, d)] = one(p)
    acc = zero(p)
    interior = one(p)
    @inbounds for _ in 1:Tsteps
        fill!(hn, zero(p))
        for m in mmin:mmax, z in zmin:zmax
            # Poda EXACTA: el mínimo de los prefijos nunca supera la posición actual,
            # así que todo estado con m > z es inalcanzable (masa 0 por construcción).
            # No cambia ningún resultado; evita recorrer medio producto cartesiano.
            m > z && continue
            v = h[idx(m, z)]
            iszero(v) && continue
            # paso del atacante: z−1 con p ; paso de la pública: z+1 con q
            zz = z - 1
            mm = min(m, zz)
            if mm ≤ -1
                acc += v * p
            else
                hn[idx(mm, zz)] += v * p
            end
            zz2 = z + 1
            if zz2 ≤ zmax
                mm2 = min(m, zz2)
                if mm2 ≤ -1
                    acc += v * q
                else
                    hn[idx(mm2, zz2)] += v * q
                end
            end
        end
        interior = zero(p)
        for i in eachindex(hn)
            interior += hn[i]
        end
        h, hn = hn, h
    end
    return (paso = acc, interior = interior)
end

"""
    rejilla_dp(ps, ds, T) -> Vector{NamedTuple}

Barrida serial por celdas del producto `(p, d)`, con el déficit inicial y el valor de
`p` declarados. Cada fila lleva `log10(P)` para no perder los casos que subdesbordan.
"""
function rejilla_dp(ps::AbstractVector{<:Real}, ds::AbstractVector{<:Integer}, Tsteps::Integer)
    out = NamedTuple{(:p, :d, :paso, :log10paso, :interior),
                     Tuple{Float64,Int,Float64,Float64,Float64}}[]
    for p in ps, d in ds
        r = primera_dp(Float64(p), Int(d), Tsteps)
        push!(out, (p = Float64(p), d = Int(d), paso = r.paso,
                    log10paso = r.paso > 0 ? log10(r.paso) : -Inf,
                    interior = r.interior))
    end
    return out
end

"""
    rejilla_dp_par(ps, ds, T) -> Vector{NamedTuple}

Igual, paralelizada por celda con `Threads.@threads`: buffers propios por llamada, sin
estado compartido. Mismo resultado que la serial (se comprueba en los tests).
"""
function rejilla_dp_par(ps::AbstractVector{<:Real}, ds::AbstractVector{<:Integer}, Tsteps::Integer)
    pares = [(Float64(p), Int(d)) for p in ps for d in ds]
    n = length(pares)
    res = Vector{NTuple{2,Float64}}(undef, n)
    Threads.@threads for i in 1:n
        p, d = pares[i]
        r = primera_dp(p, d, Tsteps)
        res[i] = (r.paso, r.interior)
    end
    return [(p = pares[i][1], d = pares[i][2], paso = res[i][1],
             log10paso = res[i][1] > 0 ? log10(res[i][1]) : -Inf,
             interior = res[i][2]) for i in 1:n]
end

"""
    primera_bigfloat_dp(p, d, T, prec) -> (paso, interior)

La misma DP con `BigFloat` a `prec` bits: certifica numéricamente el kernel `Float64`
cuando `Rational{BigInt}` es inviable (LINEO §5.3, patrón de dos velocidades).
"""
function primera_bigfloat_dp(p::AbstractFloat, d::Integer, Tsteps::Integer, prec::Integer = 256)
    return setprecision(BigFloat, prec) do
        pb = BigFloat(p)
        r = primera_dp(pb, d, Tsteps)
        return (r.paso, r.interior)
    end
end

end # module
