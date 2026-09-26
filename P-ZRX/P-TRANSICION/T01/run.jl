# run.jl — CLI reproducible del oráculo T01 (ORDEN §4.1, §6.2).
#
#     julia --project=. run.jl --seed 0x5a5a --replicas 200 --rejilla reducida
#
# Opciones extra: `--paso N`, `--i3-cada N`, `--i3-perm N` y
# `--ev-historias N` (por defecto 5000; barrido de evidencia con ≥ N historias).
#
# No paraleliza (1 hilo): el oráculo es la referencia (ORDEN §6.5).

using Transicion
using StableRNGs
using Combinatorics
using Printf
using Random

function parsear(args::Vector{String})
    cfg = Dict{String,String}()
    i = 1
    while i <= length(args)
        a = args[i]
        if startswith(a, "--")
            clave = a[3:end]
            if occursin("=", clave)
                k, v = split(clave, "=", limit = 2)
                cfg[k] = v
            else
                i += 1
                i <= length(args) || error("falta valor para --$clave")
                cfg[clave] = args[i]
            end
        end
        i += 1
    end
    return cfg
end

function parsear_seed(s::AbstractString)
    t = lowercase(strip(s))
    if startswith(t, "0x")
        return parse(UInt64, t[3:end]; base = 16)
    end
    return parse(UInt64, t)
end

function cadena_de(id::Int, por_id::Dict{Int,Bloque})
    c = Int[]
    while id != 0
        push!(c, id)
        b = get(por_id, id, nothing)
        b === nothing && break
        id = b.padre
    end
    return c
end

# Verifica I-1…I-7 sobre una historia. Devuelve un vector de contadores de fallo
# indexado por invariante (1..7) más el número de undos/permutaciones.
function verificar(bloques::Vector{Bloque}, P::Params;
                   con_i3::Bool = false, i3_perm::Int = 5)
    fallos = zeros(Int, 7)
    n_undos = 0
    n_perms = 0
    memo, por_id = construir_validos(bloques, P)
    # I-1 / I-1b
    for (_, E) in memo
        invariante_I1(E) || (fallos[1] += 1)
        invariante_I1b(E) || (fallos[1] += 1)
    end
    # I-2 e I-6
    for id in keys(memo)
        b = por_id[id]
        b.familia == Genesis && continue
        Ep = get(memo, b.padre, nothing)
        Ep === nothing && continue
        h0 = hash_canonico(Ep)
        r = aplicar_con_undo(Ep, b, P)
        r isa Err && continue
        E2, undo = r
        (hash_canonico(deshacer(E2, undo)) == h0 && hash_canonico(Ep) == h0) ||
            (fallos[2] += 1)
        n_undos += 1
        for tx in b.txs
            (tx.tipo == TxDeposito || tx.tipo == TxTransferencia) || continue
            for eid in tx.entradas
                o = get(Ep.utxo, eid, nothing)
                o === nothing && continue
                if o.origen == OrigenCoinbasePow
                    fase = b.familia == PoW ? FasePoW :
                           (Ep.fase == FasePoW ? FasePoST : Ep.fase)
                    gastable_en(o, fase, Ep.altura_terminal, Ep.s0, P,
                                b.familia == PoW ? b.altura : b.slot) ||
                        (fallos[6] += 1)
                end
            end
        end
        # I-4
        if b.familia == PoW
            E2.terminal == -1 || E2.terminal == b.id || (fallos[4] += 1)
        end
    end
    res = seleccionar(bloques, P)
    if res.punta != -1
        cad = cadena_de(res.punta, por_id)
        peso_esp = 0
        trab_esp = 0
        for cid in cad
            cb = por_id[cid]
            if cb.familia == PoST
                peso_esp += cb.peso
            elseif cb.familia == PoW
                trab_esp += cb.trabajo
            end
        end
        # I-5
        (peso_esp == res.estado.peso_sufijo && trab_esp == res.estado.trabajo_acum) ||
            (fallos[5] += 1)
        # I-7
        for (id, E) in memo
            por_id[id].familia == PoST || continue
            E.terminal != -1 || (fallos[7] += 1)
            if P.corte == CUT_HWPhi && E.terminal != -1
                # El terminal es, por construcción, el primero de su rama; basta
                # comprobar que Phi era verdadero en su estado.
                phi(memo[E.terminal], P) || (fallos[7] += 1)
            end
        end
        # I-3 (muestreada)
        if con_i3
            n = length(bloques)
            refh = hash_canonico(res.estado)
            perms = n <= 6 ? permutations(1:n) :
                    (randperm(StableRNG(0x1300 + UInt64(res.punta)), n) for _ in 1:i3_perm)
            for perm in perms
                tip, E = nodo_en_linea(bloques[collect(perm)], P)
                n_perms += 1
                if !(tip == res.punta && hash_canonico(E) == refh)
                    fallos[3] += 1
                    break
                end
            end
        end
    end
    con_post = res.punta != -1 && res.estado.fase == FasePoST
    return fallos, n_undos, n_perms, con_post
end

# SL-4c-O: error del último bloque de una historia de evidencia, para contar en
# el barrido las clases de forma nuevas. Devuelve `nothing` si no hay error o si
# el padre no es válido.
function ultimo_error(bloques::Vector{Bloque}, P::Params)
    memo, _ = construir_validos(bloques, P)
    B = last(bloques)
    Ep = get(memo, B.padre, nothing)
    Ep === nothing && return nothing
    r = aplicar(Ep, B, P)
    return r isa Err ? r : nothing
end

function main()
    cfg = parsear(ARGS)
    semilla = parsear_seed(get(cfg, "seed", "0x5a5a"))
    replicas = parse(Int, get(cfg, "replicas", "200"))
    rejilla = Symbol(get(cfg, "rejilla", "reducida"))
    paso = parse(Int, get(cfg, "paso", "1"))
    i3_cada = parse(Int, get(cfg, "i3-cada", "200"))
    i3_perm = parse(Int, get(cfg, "i3-perm", "5"))
    ev_historias = parse(Int, get(cfg, "ev-historias", "5000"))

    puntos = puntos_rejilla(rejilla = rejilla)[1:paso:end]
    @printf("T01 run: semilla=%s (0x%016x) replicas=%d rejilla=%s puntos=%d paso=%d\n",
            string(semilla), semilla, replicas, rejilla, length(puntos), paso)
    @printf("subsidio_pow=10 subsidio_post=3  i3_cada=%d i3_perm=%d ev_historias=%d\n",
            i3_cada, i3_perm, ev_historias)
    flush(stdout)

    fallos = zeros(Int, 7)
    total_hist = 0
    total_undos = 0
    total_perms = 0
    dif_fc1 = 0
    dif_fc2 = 0
    n_con_post = 0
    t0 = time()
    for (i, P) in enumerate(puntos)
        for rep in 1:replicas
            rng = StableRNG(semilla + UInt64(rep))
            bloques = generar_historia(rng, P; max_altura = 9, max_post = 3)
            con_i3 = i3_cada > 0 && (total_hist % i3_cada == 0)
            f, nu, np, cp = verificar(bloques, P; con_i3 = con_i3, i3_perm = i3_perm)
            fallos .+= f
            total_undos += nu
            total_perms += np
            cp && (n_con_post += 1)
            total_hist += 1
            # Diferencias FC-1/FC-2 respecto a FC-3 (dato, sin juicio),
            # muestreadas junto con I-3 para acotar el coste.
            if con_i3
                res3 = seleccionar(bloques, conseleccion(P, FC3))
                if res3.punta != -1
                    t1 = seleccionar(bloques, conseleccion(P, FC1)).punta
                    t2 = seleccionar(bloques, conseleccion(P, FC2)).punta
                    t1 != res3.punta && (dif_fc1 += 1)
                    t2 != res3.punta && (dif_fc2 += 1)
                end
            end
        end
        if i % 2000 == 0
            @printf("  progreso: punto %d/%d  historias=%d  t=%.0fs\n",
                    i, length(puntos), total_hist, time() - t0)
            flush(stdout)
        end
    end
    # --- SL-3b/SL-4c-O/SL-4c-O-B/SL-4c-O-C: barrido de evidencia (≥ `ev_historias`)
    total_ev = 0
    fallos_ev = zeros(Int, 7)
    undos_ev = 0
    n_rat3 = 0
    n_forma_cbid = 0
    n_forma_orden = 0
    n_forma_igual = 0
    n_forma_ambos = 0
    n_forma_entradas = 0
    n_dir_orden = 0
    n_dir_cbid = 0
    puntos_ev = puntos_evidencia()
    # Cada punto aporta 9 tipos de caso (`casos_evidencia_cobertura`; SL-4c-O-B
    # añade `orden_igual` a los 8 de SL-4c-O) más los dos dirigidos; se elige `n`
    # para cubrir el objetivo sin reducir el barrido principal de arriba.
    n_ev_tipo = max(1, cld(ev_historias, 9 * length(puntos_ev)))
    for P in puntos_ev
        casos = Tuple{String,Vector{Bloque}}[]
        cam = caso_rat3_carrera(P)
        if cam !== nothing
            push!(casos, ("EV-RAT3-carrera", cam[1]))
        end
        au = caso_autodenuncia(P)
        isempty(au[1]) || push!(casos, ("EV-autodenuncia", au[1]))
        append!(casos, casos_evidencia_dirigidos(P))
        append!(casos, casos_evidencia_cobertura(P; n = n_ev_tipo))
        for (nombre, bl) in casos
            f, nu, _, _ = verificar(bl, P; con_i3 = false, i3_perm = 0)
            fallos_ev .+= f
            total_ev += 1
            undos_ev += nu
            nombre == "ev-ambos" && (n_forma_ambos += 1)
            e = ultimo_error(bl, P)
            e == ErrForma(EvidenciaConEntradasOSalidas) && (n_forma_entradas += 1)
            e == ErrForma(EvidenciaCbidAjeno) && (n_forma_cbid += 1)
            e == ErrForma(OrdenCanonicoInvalido) && (n_forma_orden += 1)
            if nombre == "ev-orden_igual"
                e == ErrForma(OrdenCanonicoInvalido) && (n_forma_igual += 1)
            elseif nombre == "ev-dir-orden-cbid"
                e == ErrForma(OrdenCanonicoInvalido) && (n_dir_orden += 1)
            elseif nombre == "ev-dir-cbid-orden"
                e == ErrForma(EvidenciaCbidAjeno) && (n_dir_cbid += 1)
            end
        end
        # RAT-3: la liberación debe caer con ErrVentanaAbierta.
        if cam !== nothing
            bl, _, ilib = cam
            E = estado_inicial(P)
            for j in 1:ilib-1
                r = aplicar(E, bl[j], P)
                r isa Err && break
                E = r
            end
            rlib = aplicar(E, bl[ilib], P)
            (rlib == ErrVentanaAbierta) && (n_rat3 += 1)
        end
    end
    t1 = time()
    @printf("\nRESUMEN\n")
    @printf("puntos           = %d\n", length(puntos))
    @printf("replicas/punto   = %d\n", replicas)
    @printf("historias        = %d\n", total_hist)
    @printf("con sufijo PoST  = %d\n", n_con_post)
    @printf("undos exactos    = %d\n", total_undos)
    @printf("permutaciones I-3= %d\n", total_perms)
    for k in 1:7
        @printf("fallos I-%d       = %d\n", k, fallos[k])
    end
    @printf("historias evid.  = %d\n", total_ev)
    @printf("undos evid.      = %d\n", undos_ev)
    @printf("RAT-3 bloqueadas = %d\n", n_rat3)
    @printf("forma cbid/orden/entradas/ambos = %d / %d / %d / %d\n", n_forma_cbid,
            n_forma_orden, n_forma_entradas, n_forma_ambos)
    @printf("orden por igualdad    = %d\n", n_forma_igual)
    @printf("dirigidos 2 evidencias (orden,cbid) = %d / %d\n", n_dir_orden,
            n_dir_cbid)
    for k in 1:7
        @printf("fallos evid I-%d = %d\n", k, fallos_ev[k])
    end
    @printf("dif FC-1 vs FC-3 = %d\n", dif_fc1)
    @printf("dif FC-2 vs FC-3 = %d\n", dif_fc2)
    @printf("tiempo de pared  = %.1f s (%.2f min)\n", t1 - t0, (t1 - t0) / 60)
    total_fallos = sum(fallos) + sum(fallos_ev)
    @printf("VEREDICTO        = %s\n", total_fallos == 0 ? "SIN FALLOS" : "CON FALLOS")
end

main()
