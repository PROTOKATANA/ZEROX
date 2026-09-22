# IB-v0.1 — referencia: evaluación transparente sobre el ORÁCULO de GDR-v0.2
# (`GhostdagRank.EstadoReferencia`), que recalcula GHOSTDAG desde la definición.
#
# NO se reimplementa GHOSTDAG. Lo que este fichero añade encima del oráculo es:
#   1. la invalidez U2 (C-GD-07) y su propagación por herencia (C-FLU-13(3)), y
#   2. la contabilidad de copias pagables de §7.2 (P1 / C-ORD-02), escrita aquí de la
#      forma más tonta posible: recorriendo la cadena seleccionada y agrupando copias.
# `rapido.jl` repite (2) con una vía indexada; `validacion.jl` comprueba las tres contra
# una tercera vía basada en conjuntos.

"""
Bloque de un fixture. `padres` por índice 1-based sobre el vector, con el génesis en la
posición 1 (misma convención que GDR).
"""
struct BloqueEspec
    id::String
    padres::Vector{Int}
    sol::Solucion
end

"""
Resultado de evaluar un fixture bajo una identidad.

- `validos`: bloques admitidos en el DAG.
- `u2`: rechazados por U2 (C-GD-07).
- `herencia`: rechazados por tener un ancestro rechazado (validez absoluta).
- `azules` / `rojo_k` / `rojo_u3`: papel de cada bloque al ser fusionado (contextual).
- `pagables`: la copia seleccionada por billete (P1, C-ORD-02).
- `inertes`: copias del mismo billete que NO cobran ni cuentan.
- `peso`: `blue_work` de la punta virtual, en entero exacto.
- `entropias`: por identidad, las entropías de C-FLU-12 de TODAS sus copias admitidas o
  rechazadas por U2 (no por herencia). Es lo que decide el invariante de no-equivocación.
"""
struct Resultado
    modo::ModoId
    n::Int
    validos::Vector{Int}
    u2::Vector{Int}
    herencia::Vector{Int}
    azules::Vector{Int}
    rojo_k::Vector{Int}
    rojo_u3::Vector{Int}
    pagables::Vector{Int}
    inertes::Vector{Int}
    peso::BigInt
    entropias::Dict{UInt64,Vector{NTuple{32,UInt8}}}
end

"Añade los bloques al estado en orden; devuelve (mapa a índice de estado, u2, herencia)."
function _poblar!(est, especs::Vector{BloqueEspec}, modo::ModoId, params::GDR.Params)
    n = length(especs)
    mapa = zeros(Int, n)
    mapa[1] = 1                      # génesis
    u2 = Int[]; herencia = Int[]
    for i in 2:n
        if any(p -> mapa[p] == 0, especs[i].padres)
            push!(herencia, i)
            continue
        end
        pad = Int[mapa[p] for p in especs[i].padres]
        s = especs[i].sol
        ok = GDR.anadir!(est, params, especs[i].id, pad, s.slot, s.sd, s.sr, identidad(modo, s))
        ok ? (mapa[i] = est.n) : push!(u2, i)
    end
    return mapa, u2, herencia
end

"""
Capa pagable, vía «cadena seleccionada». Recorre la cadena desde el génesis y anota el
papel de cada bloque la primera vez que es fusionado (C-ORD-03), y agrupa por billete.
"""
function _pagables_cadena(est, params::GDR.Params, oraculo::Bool)
    tip = oraculo ? GDR.virtual_sp_ref(est, params) : GDR.virtual_sp(est, params)
    ch = GDR.cadena_seleccionada(est, tip)
    papel = Dict{Int,Symbol}()
    for k in 2:length(ch)
        c = ch[k]
        papel[ch[k - 1]] = :azul
        for x in GDR.ms_blues_de(est, c)
            x == GDR.sp_de(est, c) && continue
            papel[x] = :azul
        end
        for x in GDR.ms_reds_de(est, c)
            papel[x] = GDR.es_rojo_u3(est, c, x) ? :rojo_u3 : :rojo_k
        end
    end
    papel[tip] = :azul
    return tip, papel
end

"¿`a` gana a `b` en P1? Azul primero; después menor `rank` (C-ORD-01), que ya es total."
function _mejor_p1(est, a::Int, b::Int, papel::Dict{Int,Symbol})
    ca = papel[a] == :azul; cb = papel[b] == :azul
    ca != cb && return ca
    return GDR.cmp_orden(est, a, b) < 0
end

"""
Agrupa las copias por identidad y elige la pagable. Devuelve (pagables, inertes, papel).
"""
function _seleccionar(est, papel::Dict{Int,Symbol})
    grupos = Dict{UInt64,Vector{Int}}()
    for (x, p) in papel
        p == :rojo_u3 && continue
        push!(get!(grupos, est.idents[x], Int[]), x)
    end
    pagables = Int[]; inertes = Int[]
    for (_, xs) in grupos
        mejor = xs[1]
        for x in xs[2:end]
            _mejor_p1(est, x, mejor, papel) && (mejor = x)
        end
        push!(pagables, mejor)
        for x in xs
            x == mejor || push!(inertes, x)
        end
    end
    sort!(pagables); sort!(inertes)
    return pagables, inertes, papel
end

"""
Evalúa `especs` bajo el modo `modo`. `oraculo=true` usa `EstadoReferencia`; `false`, el
kernel `EstadoRapido`. La capa pagable es la misma en ambos; la equivalencia oráculo↔kernel
la comprueba `validacion.jl`.
"""
function evaluar(especs::Vector{BloqueEspec}, modo::ModoId, params::GDR.Params;
                 oraculo::Bool=false)
    est = oraculo ? GDR.EstadoReferencia(params, "G") : GDR.EstadoRapido(params, "G")
    mapa, u2, herencia = _poblar!(est, especs, modo, params)
    tip, papel = _pagables_cadena(est, params, oraculo)
    pagables, inertes, _ = _seleccionar(est, papel)

    azules = Int[]; rojos_k = Int[]; rojos_u3 = Int[]
    for (x, p) in papel
        p == :azul && push!(azules, x)
        p == :rojo_k && push!(rojos_k, x)
        p == :rojo_u3 && push!(rojos_u3, x)
    end
    sort!(azules); sort!(rojos_k); sort!(rojos_u3)

    validos = Int[i for i in 1:length(especs) if mapa[i] != 0]
    ent = Dict{UInt64,Vector{NTuple{32,UInt8}}}()
    for i in 2:length(especs)
        i in herencia && continue
        s = especs[i].sol
        push!(get!(ent, identidad(modo, s), NTuple{32,UInt8}[]), entropia_de(s))
    end

    return Resultado(modo, length(especs), validos, u2, herencia, azules, rojos_k, rojos_u3,
                     pagables, inertes, BigInt(GDR.bw_de(est, tip)), ent)
end

"Vía de referencia (oráculo GDR)."
evaluar_ref(especs::Vector{BloqueEspec}, modo::ModoId, params::GDR.Params) =
    evaluar(especs, modo, params; oraculo=true)
