# =============================================================================
# rapido.jl — kernel rápido: buffers preasignados, máscaras por bits y
#             precálculo por rama (las inyecciones se calculan UNA vez por época,
#             no una vez por slot)
#
# Reparto de coste (LINEO §6, modelo de coste escrito antes de optimizar):
#   n = bloques del DAG · J = épocas · W = slots de la ventana
#   referencia : O(W · J · (n² + n·|V|))     recalcula pasado, coloreo y flujo por slot
#   rápida     : O(J · (n² + n·|V|) + W·J)    coloreo una vez por (rama, época); comparación en O(J)
# El término dominante es el coloreo por vista; el barrido de slots deja de pagarlo.
# =============================================================================

"Vista del DAG con campos planos y listas de hijos, para el camino caliente."
struct PreDag
    n::Int
    slots::Vector{Int}
    padres::Vector{Vector{Int}}
    hijos::Vector{Vector{Int}}
    billetes::Vector{Int}
    chunks::Vector{Int}
    dists::Vector{Int}
    pesos::Vector{BigInt}
    pasado::Vector{BitVector}
end

function PreDag(d::Dag)
    n = nbloques(d)
    slots = [d.bloques[i].slot for i in 1:n]
    padres = [d.bloques[i].padres for i in 1:n]
    hijos = [Int[] for _ in 1:n]
    for b in 1:n, p in padres[b]
        push!(hijos[p], b)
    end
    return PreDag(n, slots, padres, hijos,
                  [d.bloques[i].billete for i in 1:n],
                  [d.bloques[i].chunk for i in 1:n],
                  [d.bloques[i].dist for i in 1:n],
                  [peso_bloque(d.bloques[i].sr) for i in 1:n],
                  d.pasado)
end

"Buffers reutilizables del kernel rápido. Se preasignan una vez por DAG."
mutable struct Buffers
    activos::BitVector
    tmp::BitVector
    anti::BitVector
    sp::Vector{Int}
    color::Vector{UInt8}
    bsc::Vector{Int}
    bwr::Vector{BigInt}
    tam::Vector{Int}
    azules::Vector{BitVector}
    aporte::Vector{BitVector}
    puntas::Vector{Int}
end

function Buffers(n::Int)
    Buffers(falses(n), falses(n), falses(n), zeros(Int, n), zeros(UInt8, n),
            zeros(Int, n), zeros(BigInt, n), zeros(Int, n),
            [falses(n) for _ in 1:n], [falses(n) for _ in 1:n], Int[])
end

"`V_j(B)` por máscaras: `past(B) ∪ {B}` ya es cerrado por ancestros (C-FLU-02)."
function vista_epoca!(buf::Buffers, d::PreDag, b::Int, T::Int, L::Int)
    act = buf.activos
    copyto!(act, d.pasado[b]); act[b] = true
    corte = T + L
    @inbounds for x in 1:d.n                     # índices acotados: x ∈ 1:n = length(act)
        d.slots[x] < corte || (act[x] = false)
    end
    return act
end

"""
    seleccion_vista!(buf, d, k) -> símbolo de la vista en `buf`

GHOSTDAG restringido a `buf.activos` (C-GD-01…C-GD-08). Escribe en `buf` y devuelve
la punta del virtual.
"""
function seleccion_vista!(buf::Buffers, d::PreDag, k::Int)
    n = d.n
    fill!(buf.color, 0x00)
    fill!(buf.bsc, 0)
    empty!(buf.puntas)
    activos = buf.activos
    for b in 1:n
        activos[b] || continue
        # ---- C-GD-03: padre seleccionado dentro de la vista
        mejor = 0
        @inbounds for p in d.padres[b]
            activos[p] || continue
            if mejor == 0 || (buf.bwr[p], -d.dists[p], -p) > (buf.bwr[mejor], -d.dists[mejor], -mejor)
                mejor = p
            end
        end
        buf.sp[b] = mejor
        # ---- hijos activos (para las puntas)
        vivo = false
        @inbounds for c in d.hijos[b]
            if activos[c]
                vivo = true; break
            end
        end
        vivo || push!(buf.puntas, b)
        if mejor == 0
            fill!(buf.azules[b], false); buf.azules[b][b] = true
            fill!(buf.aporte[b], false); buf.aporte[b][b] = true
            buf.color[b] = 0x01
            buf.bsc[b] = 1
            buf.bwr[b] = d.pesos[b]
            continue
        end
        # ---- C-GD-04: mergeset
        ms = Int[]
        @inbounds for x in 1:n
            activos[x] || continue
            d.pasado[b][x] || continue
            (x == mejor || d.pasado[mejor][x]) && continue
            push!(ms, x)
        end
        sort!(ms; by = x -> (buf.bwr[x], d.dists[x], x))          # C-GD-05
        # ---- contexto azul heredado (C-GD-06)
        ctx = buf.azules[b]
        copyto!(ctx, buf.azules[mejor]); ctx[mejor] = true
        fill!(buf.tam, 0)
        @inbounds for y in 1:n
            ctx[y] || continue
            c = 0
            for z in 1:n
                # anticono: z y y INCOMPARABLES (ninguno es ancestro del otro)
                (ctx[z] && z != y && !d.pasado[y][z] && !d.pasado[z][y]) && (c += 1)
            end
            buf.tam[y] = c
        end
        ap = buf.aporte[b]
        fill!(ap, false); ap[mejor] = true
        for x in ms
            # ---- U3'' (C-GD-07)
            ya = false
            @inbounds for y in 1:n
                if ctx[y] && d.billetes[y] == d.billetes[x]
                    ya = true; break
                end
            end
            if ya
                buf.color[x] = 0x03
                continue
            end
            # ---- anticono de x dentro del contexto
            anti = buf.anti
            fill!(anti, false)
            @inbounds for y in 1:n
                if ctx[y] && !d.pasado[x][y] && !d.pasado[y][x]
                    anti[y] = true
                end
            end
            cuenta = count(anti)
            rojo = cuenta > k
            if !rojo
                @inbounds for y in 1:n
                    # todo `anti[y]` es azul: `anti ⊆ ctx` y `ctx` ES el conjunto azul acumulado
                    if anti[y] && buf.tam[y] + 1 >= k
                        rojo = true; break
                    end
                end
            end
            if rojo
                buf.color[x] = 0x02
            else
                buf.color[x] = 0x01
                ap[x] = true
                ctx[x] = true
                @inbounds for y in 1:n
                    anti[y] && (buf.tam[y] += 1)
                end
                buf.tam[x] = cuenta
            end
        end
        # ---- C-GD-08
        buf.bsc[b] = buf.bsc[mejor] + count(ap)
        s = buf.bwr[mejor]
        @inbounds for x in 1:n
            ap[x] && (s += d.pesos[x])
        end
        buf.bwr[b] = s
    end
    # ---- punta del virtual (C-GD-03 entre las puntas de V)
    tip = 0
    for t in buf.puntas
        if tip == 0 || (buf.bwr[t], -d.dists[t], -t) > (buf.bwr[tip], -d.dists[tip], -tip)
            tip = t
        end
    end
    return tip
end

"`Chn(V)`: cadena del virtual desde el génesis de la vista hasta su punta."
function cadena_rapida!(buf::Buffers, d::PreDag, tip::Int, salida::Vector{Int})
    empty!(salida)
    x = tip
    while x != 0
        push!(salida, x)
        x = buf.sp[x]
    end
    reverse!(salida)
    return salida
end

"Ancla rápida: primer cruce de `T` por la cadena (C-FLU-04)."
function ancla_rapida!(buf::Buffers, d::PreDag, b::Int, T::Int, L::Int, k::Int, cad::Vector{Int})
    vista_epoca!(buf, d, b, T, L)
    tip = seleccion_vista!(buf, d, k)
    cadena_rapida!(buf, d, tip, cad)
    for x in cad
        d.slots[x] >= T && return x
    end
    return 0
end

"Inyecciones de una rama (representación canónica del flujo, M1)."
function inyecciones_rapidas(buf::Buffers, d::PreDag, b::Int, I_slots::Int, L::Int,
                             jmax::Int, k::Int)
    cad = Int[]
    out = Tuple{Int,Tuple{Int,Int},Int}[]
    for j in 1:jmax
        T = j * I_slots
        a = ancla_rapida!(buf, d, b, T, L, k, cad)
        a == 0 && continue
        push!(out, (j, (d.chunks[a], d.slots[a]), d.slots[a] + L))
    end
    return out
end

"¿Coinciden los flujos de las dos ramas en el slot `s`?"
function flujos_iguales(a::Vector{Tuple{Int,Tuple{Int,Int},Int}},
                        b::Vector{Tuple{Int,Tuple{Int,Int},Int}}, s::Int)
    ia = 0; ib = 0
    while ia < length(a) && a[ia+1][3] <= s; ia += 1; end
    while ib < length(b) && b[ib+1][3] <= s; ib += 1; end
    ia == ib || return false
    @inbounds for i in 1:ia
        a[i] == b[i] || return false
    end
    return true
end

"""
    espectro_flujo(d, A, B; I_slots, L, F_slots, jmax, k, s0)

Barrido de la ventana `[s0, s0 + F_slots)`: para cada slot, si las dos ramas
comparten flujo (y por tanto reto, `C-POT-03`). Devuelve un `BitVector` indexado
por `s - s0 + 1`.
"""
function espectro_flujo(d::Dag, A::Int, B::Int; I_slots::Int, L::Int, F_slots::Int,
                        jmax::Int, k::Int, s0::Int)
    pd = PreDag(d)
    buf = Buffers(pd.n)
    ia = inyecciones_rapidas(buf, pd, A, I_slots, L, jmax, k)
    ib = inyecciones_rapidas(buf, pd, B, I_slots, L, jmax, k)
    res = falses(F_slots)
    for (i, s) in enumerate(s0:(s0 + F_slots - 1))
        res[i] = flujos_iguales(ia, ib, s)
    end
    return res, ia, ib
end

"Mismo barrido, sin precálculo: recalcula todo por slot (variante de control)."
function espectro_flujo_lento(d::Dag, A::Int, B::Int; I_slots::Int, L::Int, F_slots::Int,
                              jmax::Int, k::Int, s0::Int)
    res = falses(F_slots)
    for (i, s) in enumerate(s0:(s0 + F_slots - 1))
        res[i] = flujo_ref(d, A, s, I_slots, L, jmax, k) == flujo_ref(d, B, s, I_slots, L, jmax, k)
    end
    return res
end
