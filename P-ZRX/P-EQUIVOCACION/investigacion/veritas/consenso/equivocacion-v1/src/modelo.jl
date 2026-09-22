# =============================================================================
# modelo.jl — reglas del destino, exactas y sin criptografía
#
# Qué implementa, por identificador de regla:
#   C-HDR-05 / C-FLU-02  cota de slot a TODOS los padres: slot(p) <= slot(B)
#   C-GD-01              w(B) = floor(2^128 / (SR(B)+1)), enteros exactos
#   C-GD-03              padre seleccionado sp(B): mayor (blue_work, -dist, -id)
#   C-GD-04              mergeset(B) y cota slot(B) - slot(sp(B)) <= S_max
#   C-GD-05              orden del mergeset: (blue_work, dist, id) ascendente
#   C-GD-06              coloreo por k-cluster
#   C-GD-07              U2 (misma identidad en el pasado de un padre) y
#                        U3'' (identidad ya azul en el contexto -> rojo_U3)
#   C-GD-08              acumuladores blue_score y blue_work
#   C-FLU-03             vista de época V_j(B) = (past(B) u {B}) & {slot < T_j+L}
#   C-FLU-04             ancla I_j(B) = primer bloque de Chn(V_j(B)) con slot >= T_j
#   C-FLU-05             época sin ancla: se salta
#   C-FLU-07             t_j = slot(I_j) + L ; el flujo lo fija la última j con t_j <= s
#   C-FLU-10             flujo acumulativo (se representa por su PREIMAGEN canónica)
#   C-FLU-12             entropía de la inyección
#
# Decisiones de modelo, declaradas y NO reglas de consenso (van al INFORME):
#  M1. El flujo NO se hashea: se representa por la lista canónica de sus inyecciones
#      [(entropía_j, t_j)] en orden de j. La igualdad estructural equivale a la
#      igualdad de C-FLU-10 salvo colisión de SHA3-256. Así el enumerador no
#      presupone ninguna propiedad criptográfica.
#  M2. `entropía_j = (chunk(I_j), slot(I_j))`: reproduce el invariante de
#      C-FLU-12 (dos copias del mismo billete dan la misma entropía y el mismo t_j)
#      sin modelar `pot_output`, que es un campo de cabecera. No se usa para
#      decidir nada de consenso.
#  M3. `blue_score` y `blue_work` usan el APORTE de B (sp más los candidatos
#      aceptados) y no el conjunto azul acumulado: la otra lectura duplicaría el
#      peso de la herencia. Se declara en el INFORME.
#  M4. El génesis tiene `blue_score = 1` y `blue_work = w(génesis)`; es un
#      desplazamiento constante que no cambia ningún orden.
#  M5. U3'' se comprueba contra el contexto azul ACUMULADO (que es lo que C-GD-06
#      llama «el conjunto azul heredado»). Es la lectura que hace a U3'' efectiva
#      dentro de una rama, como mide CRP-v0.1 §6.
# =============================================================================

"Peso de bloque, C-GD-01: `w(B) = floor(2^128/(SR+1))` en enteros exactos."
peso_bloque(sr::Integer) = fld(BigInt(2)^128, BigInt(sr) + 1)

"Un bloque del modelo. `billete` codifica la identidad de pieza; `chunk` es el escalar de la solución."
struct Bloque
    slot::Int
    padres::Vector{Int}
    billete::Int
    chunk::Int
    dist::Int
    sr::Int
end

"Un DAG del modelo. Los ids son densos (1..n) y están en orden topológico."
mutable struct Dag
    bloques::Vector{Bloque}
    pasado::Vector{BitVector}   # pasado estricto, cerrado por ancestros
end

Dag() = Dag(Bloque[], BitVector[])

"""
    agregar!(d, slot, padres, billete; chunk, dist, sr)

Añade un bloque. Exige ids de padres anteriores (orden topológico) y
`slot(padre) <= slot(B)` (C-HDR-05 / C-FLU-02).
"""
function agregar!(d::Dag, slot::Integer, padres::Vector{Int}, billete::Integer;
                  chunk::Integer = billete, dist::Integer = 0, sr::Integer = 1)
    id = length(d.bloques) + 1
    for p in padres
        (1 <= p < id) || error("padre inválido: $p (id nuevo $id)")
        d.bloques[p].slot <= slot || error("C-HDR-05 violada: slot(padre)=$(d.bloques[p].slot) > $slot")
    end
    ps = sort(unique(collect(Int, padres)))
    push!(d.bloques, Bloque(Int(slot), ps, Int(billete), Int(chunk), Int(dist), Int(sr)))
    # todas las máscaras de pasado se mantienen con longitud n (se amplían con `false`)
    for v in d.pasado
        resize!(v, id)
    end
    pas = falses(id)
    for p in ps
        pas[p] = true
        pas .|= d.pasado[p]
    end
    push!(d.pasado, pas)
    return id
end

nbloques(d::Dag) = length(d.bloques)

# -----------------------------------------------------------------------------
# Vista restringida y GHOSTDAG restringido (C-GD-01..C-GD-08 sobre un subconjunto)
# -----------------------------------------------------------------------------

struct Vista
    activos::BitVector          # V
    sp::Vector{Int}             # padre seleccionado dentro de V (0 = génesis de V)
    azules::Vector{BitVector}   # contexto azul acumulado (C-GD-06)
    aporte::Vector{BitVector}   # {sp} u candidatos aceptados (C-GD-08)
    blue_score::Vector{Int}
    blue_work::Vector{BigInt}
    color::Vector{UInt8}        # 0 inactivo · 1 azul · 2 rojo_k · 3 rojo_U3
    nino::Vector{Int}           # 0 si no hay hijo azul; si lo hay, id del hijo azul
    puntas::Vector{Int}         # bloques de V sin hijo en V
end

"Clave de C-GD-03: mayor `(blue_work, -dist, -id)`."
@inline function _mejor(d::Dag, vw::Vector{BigInt}, a::Int, b::Int)
    a == 0 && return b
    b == 0 && return a
    (vw[a], -d.bloques[a].dist, -a) > (vw[b], -d.bloques[b].dist, -b) ? a : b
end

"""
    seleccion_vista(d, activos, k) -> Vista

GHOSTDAG restringido a `activos`, con los acumuladores de C-GD-08. `activos`
debe ser cerrado por ancestros (lo es `V_j(B)`, C-FLU-03).
"""
function seleccion_vista(d::Dag, activos::BitVector, k::Int)
    n = nbloques(d)
    length(activos) == n || error("máscara de tamaño incorrecto")
    sp = zeros(Int, n)
    azules = [falses(n) for _ in 1:n]
    aporte = [falses(n) for _ in 1:n]
    bsc = zeros(Int, n)
    bwr = zeros(BigInt, n)
    color = zeros(UInt8, n)
    nino = zeros(Int, n)
    pesos = [peso_bloque(d.bloques[i].sr) for i in 1:n]
    puntas = Int[]

    for b in 1:n
        activos[b] || continue
        mejor = 0
        for p in d.bloques[b].padres
            (activos[p] && p != b) || continue
            mejor = _mejor(d, bwr, mejor, p)
        end
        sp[b] = mejor
        if mejor == 0
            # raíz de V
            azules[b][b] = true; aporte[b][b] = true
            color[b] = 0x01; bsc[b] = 1; bwr[b] = pesos[b]
            push!(puntas, b)
            continue
        end
        nino[mejor] = b
        # mergeset(B) = past(B) ∩ V \ (past(sp) ∪ {sp})   (C-GD-04)
        ms = Int[]
        for x in 1:n
            activos[x] || continue
            d.pasado[b][x] || continue
            (x == mejor || d.pasado[mejor][x]) && continue
            push!(ms, x)
        end
        sort!(ms; by = x -> (bwr[x], d.bloques[x].dist, x))   # C-GD-05
        ctx = copy(azules[mejor]); ctx[mejor] = true           # contexto de C-GD-06
        tam_anti = zeros(Int, n)                               # |anticono(y) ∩ ctx|, para y ∈ ctx
        for y in 1:n
            ctx[y] || continue
            c = 0
            for z in 1:n
                # anticono: z y y INCOMPARABLES (ninguno es ancestro del otro)
                (ctx[z] && z != y && !d.pasado[y][z] && !d.pasado[z][y]) && (c += 1)
            end
            tam_anti[y] = c
        end
        ap = falses(n); ap[mejor] = true                       # aporte de C-GD-08
        for x in ms
            # U3'' (C-GD-07): identidad ya azul en el contexto
            ya = false
            for y in 1:n
                if ctx[y] && d.bloques[y].billete == d.bloques[x].billete
                    ya = true; break
                end
            end
            if ya
                color[x] = 0x03
                continue
            end
            anti = falses(n); cuenta = 0
            for y in 1:n
                if ctx[y] && !d.pasado[x][y] && !d.pasado[y][x]
                    anti[y] = true; cuenta += 1
                end
            end
            rojo = cuenta > k
            if !rojo
                for y in 1:n
                    # todo `anti[y]` es azul: `anti ⊆ ctx` y `ctx` ES el conjunto azul acumulado
                    (anti[y] && tam_anti[y] + 1 >= k) && (rojo = true; break)
                end
            end
            if rojo
                color[x] = 0x02
            else
                color[x] = 0x01
                ap[x] = true
                ctx[x] = true
                for y in 1:n
                    anti[y] && (tam_anti[y] += 1)
                end
                tam_anti[x] = cuenta
            end
        end
        azules[b] = ctx
        aporte[b] = ap
        bsc[b] = bsc[mejor] + count(ap)
        bwr[b] = bwr[mejor] + sum(pesos[i] for i in 1:n if ap[i]; init = BigInt(0))
    end
    for b in 1:n
        (activos[b] && nino[b] == 0) && push!(puntas, b)
    end
    return Vista(activos, sp, azules, aporte, bsc, bwr, color, nino, puntas)
end

"Punta del virtual sobre `V`: C-GD-03 entre las puntas de la vista."
function punta_virtual(d::Dag, v::Vista)
    mejor = 0
    for t in v.puntas
        mejor = _mejor(d, v.blue_work, mejor, t)
    end
    return mejor
end

"`Chn(V)`: la cadena del bloque virtual sobre `V`, del génesis de `V` a su punta."
function cadena_vista(d::Dag, v::Vista)
    tip = punta_virtual(d, v)
    cad = Int[]
    b = tip
    while b != 0
        push!(cad, b)
        b = v.sp[b]
    end
    reverse!(cad)
    return cad
end

"`V_j(B)` (C-FLU-03). Es cerrada por ancestros porque `slot(p) <= slot(B)` (C-FLU-02)."
function vista_epoca(d::Dag, b::Int, T::Int, L::Int)
    n = nbloques(d)
    act = falses(n)
    for x in 1:n
        (x == b || d.pasado[b][x]) || continue
        d.bloques[x].slot < T + L && (act[x] = true)
    end
    return act
end

"`I_j(B)`: primer bloque de `Chn(V_j(B))` con `slot >= T_j`; 0 si la época se salta (C-FLU-05)."
function ancla_epoca(d::Dag, b::Int, T::Int, L::Int, k::Int)
    v = seleccion_vista(d, vista_epoca(d, b, T, L), k)
    for x in cadena_vista(d, v)
        d.bloques[x].slot >= T && return x
    end
    return 0
end

"Entropía de la inyección (M2): función de la solución y del slot del ancla, no de los padres."
entropia_ancla(d::Dag, a::Int) = (d.bloques[a].chunk, d.bloques[a].slot)

"""
    inyecciones(d, b, I_slots, L, jmax, k)

Lista canónica de las inyecciones realizadas en `past(b) u {b}`:
`(j, entropía, t_j)` en orden de `j`. Es la representación del flujo (M1).
"""
function inyecciones(d::Dag, b::Int, I_slots::Int, L::Int, jmax::Int, k::Int)
    out = Tuple{Int,Tuple{Int,Int},Int}[]
    for j in 1:jmax
        T = j * I_slots
        a = ancla_epoca(d, b, T, L, k)
        a == 0 && continue
        push!(out, (j, entropia_ancla(d, a), d.bloques[a].slot + L))
    end
    return out
end

"`flujo(B, s)`: prefijo de `inyecciones` con `t_j <= s` (C-FLU-07)."
function flujo_slot(inj::Vector{Tuple{Int,Tuple{Int,Int},Int}}, s::Int)
    i = 0
    for (j, e, t) in inj
        t <= s || break
        i += 1
    end
    return view(inj, 1:i)
end

# -----------------------------------------------------------------------------
# Generador de DAGs de dos ramas (el «patrón de retención» es la forma del DAG)
# -----------------------------------------------------------------------------

"""
    construir_dos_ramas(; slots_comun, idx_fork, slots_publica, slots_privada,
                          billete_base, I_slots, L, S_max, sr, dist_base,
                          fusionar = :P, billetes_publicos = nothing,
                          billetes_privados = nothing)

Construye el DAG mínimo que decide la pregunta del encargo:

* `slots_comun`: cadena común; el último bloque es `P`, el último ancestro común.
* `idx_fork`: índice (1-based) dentro de `slots_comun` donde bifurca la rama privada.
* `slots_publica`: cadena pública desde `P`; su punta es `A`.
* `slots_privada`: cadena privada desde el bloque de bifurcación; su último bloque es `B`.
* `fusionar`: `:P` añade `P` como padre adicional de `B` (es la **fusión** de un bloque
  retenido: hace que `P ∈ past(B)` sin que la cadena privada pase por `P`, que es el
  mecanismo de A2). `:publica` añade `A` (entonces `A ∈ past(B)` y NO hay bifurcación
  real: se usa como control). `:nada` no añade nada.

`billetes_publicos` / `billetes_privados` permiten forzar la MISMA identidad en dos ramas
(regresión de U2/U3″ de CRP-v0.1 §6). Por defecto cada bloque lleva identidad distinta.

Devuelve `(d, P, A, B)`.
"""
function construir_dos_ramas(; slots_comun::Vector{Int}, idx_fork::Int,
                             slots_publica::Vector{Int}, slots_privada::Vector{Int},
                             billete_base::Int = 1000, I_slots::Int, L::Int, S_max::Int,
                             sr::Int = 1, dist_base::Int = 0,
                             fusionar::Symbol = :P,
                             billetes_publicos::Union{Nothing,Vector{Int}} = nothing,
                             billetes_privados::Union{Nothing,Vector{Int}} = nothing)
    d = Dag()
    ids_comun = Int[]
    prev = Int[]
    for (i, s) in enumerate(slots_comun)
        id = agregar!(d, s, copy(prev), billete_base + i; dist = dist_base + i, sr = sr)
        prev = [id]
        push!(ids_comun, id)
    end
    P = ids_comun[end]
    ids_pub = Int[]
    prev = [P]
    for (i, s) in enumerate(slots_publica)
        bl = billetes_publicos === nothing ? billete_base + 100 + i : billetes_publicos[i]
        id = agregar!(d, s, copy(prev), bl; dist = dist_base + 10 + i, sr = sr)
        prev = [id]
        push!(ids_pub, id)
    end
    A = isempty(ids_pub) ? P : ids_pub[end]
    ids_priv = Int[]
    prev = [ids_comun[idx_fork]]
    for (i, s) in enumerate(slots_privada)
        bl = billetes_privados === nothing ? billete_base + 200 + i : billetes_privados[i]
        id = agregar!(d, s, copy(prev), bl; dist = dist_base + 20 + i, sr = sr)
        prev = [id]
        push!(ids_priv, id)
    end
    B = ids_priv[end]
    if fusionar === :P
        B = agregar!(d, max(d.bloques[B].slot, d.bloques[P].slot), [B, P],
                     billete_base + 900; dist = dist_base + 900, sr = sr)
    elseif fusionar === :publica
        B = agregar!(d, max(d.bloques[B].slot, d.bloques[A].slot), [B, A],
                     billete_base + 900; dist = dist_base + 900, sr = sr)
    elseif fusionar === :nada
        # nada
    else
        error("fusionar desconocido: $fusionar")
    end
    return d, P, A, B
end

"Comprueba U2 (C-GD-07): la identidad de `b` no aparece en `padres(b)` ni en el pasado de un padre."
function u2_ok(d::Dag, b::Int)
    bl = d.bloques[b].billete
    for p in d.bloques[b].padres
        d.bloques[p].billete == bl && return false
        for x in 1:nbloques(d)
            d.pasado[p][x] || continue
            d.bloques[x].billete == bl && return false
        end
    end
    return true
end

"Validez estructural del modelo: cota de slot (C-HDR-05) y U2 (C-GD-07)."
function estructura_ok(d::Dag)
    for b in 1:nbloques(d)
        for p in d.bloques[b].padres
            d.bloques[p].slot <= d.bloques[b].slot || return false
        end
        u2_ok(d, b) || return false
    end
    return true
end
