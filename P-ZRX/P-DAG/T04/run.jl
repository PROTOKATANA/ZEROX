# run.jl — batería completa de T04: revalidación GDR-v0.2, casos dirigidos y
# propiedades IE-1…IE-6 sobre la rejilla T04 (semilla fija, ≥200 réplicas/punto).
#
#     JULIA_NUM_THREADS=1 julia --project=. run.jl \
#         [--seed 0x5a5a] [--replicas 200] [--ie3-presupuesto 8000] [--salida RUTA]
#
# Un hilo (LINEO §7: el tope no es objetivo). Sin Python. Escribe el registro en
# `resultados/run-estado-dag-v0.3.log` (sin sobrescribir v0, v0.1 ni v0.2),
# publica la cobertura por tipo de operación (ORDEN-T04-C §2) y termina con
# estado ≠ 0 si hay algún fallo.

using EstadoDAG
using EstadoDAG.Transicion
import EstadoDAG.GDR
using StableRNGs
using Random
using Combinatorics
using Printf
using Dates

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

parsear_seed(s::AbstractString) = startswith(s, "0x") ? parse(UInt64, s[3:end]; base = 16) :
                                                       parse(UInt64, s)

function main()
    cfg = parsear(ARGS)
    seed = parsear_seed(get(cfg, "seed", "0x5a5a"))
    replicas = parse(Int, get(cfg, "replicas", "200"))
    ie3_exhaustivos = parse(Int, get(cfg, "ie3-exhaustivos", "5"))
    salida = get(cfg, "salida", "resultados/run-estado-dag-v0.4.log")
    mkpath(dirname(salida))
    io = open(salida, "w")
    t0 = time()

    cabecera(io, seed, replicas, ie3_exhaustivos, salida)
    fallos_globales = String[]

    # 1) Revalidación GDR-v0.2
    nd, nb, disc = revalidar_corpus("/home/katana/zeo/ZEROX/testdata/ghostdag-rank-v1/corpus-rust.txt")
    nk, disc2 = revalidar_kaspa(joinpath(@__DIR__, "testdata", "kaspa"))
    println(io, "REVALIDACION corpus: dags=$nd bloques=$nb discrepancias=$(length(disc))")
    println(io, "REVALIDACION kaspa:  bloques=$nk discrepancias=$(length(disc2))")
    append!(fallos_globales, disc)
    append!(fallos_globales, disc2)

    # 2) Casos dirigidos
    pd1 = ParamsDAG(PARAMS_DAG_BASE[1], 1)
    for (nombre, A, meta) in casos_dirigidos(pd1)
        f = verificar_ie1_ie2_ie4(A)
        f6 = verificar_ie6(A)
        println(io, "DIRIGIDO $nombre validos=$(count(v -> v, values(A.validos)))/$(length(A.validos)) ",
                "fallos=$(length(f) + length(f6))")
        append!(fallos_globales, f)
        append!(fallos_globales, f6)
    end
    # Assertions semánticas dirigidas mínimas
    _, Ad, md = EstadoDAG.caso_doble_gasto(pd1)
    _, _, descd = aplicar_historia(Ad)
    length(descd) == 1 && descd[1][3] == Transicion.ErrDobleGasto ||
        push!(fallos_globales, "dirigido D-1 doble gasto")
    _, Ac, mc = EstadoDAG.caso_coinbase_recortada(pd1)
    sum(p.importe for p in Ac.post[mc.X].garantias[1].creditos) == UInt64(4) ||
        push!(fallos_globales, "dirigido D-2 recorte")
    _, Adh, mdh = EstadoDAG.caso_deposito_habilita(pd1)
    (Adh.validos[mdh.Z] && !Adh.validos[mdh.W]) ||
        push!(fallos_globales, "dirigido D-3 depósito habilita")
    _, Ag, mg = EstadoDAG.caso_garantia_rama(pd1)
    !Ag.validos[mg.B] || push!(fallos_globales, "dirigido D-4 garantía rama")
    _, Au, mu = EstadoDAG.caso_rojo_u3(pd1)
    (mu.X2 in u3_virtual(Au) && !(mu.X2 in orden_aplicacion_virtual(Au))) ||
        push!(fallos_globales, "dirigido D-5 rojo_U3")
    _, Ao, mo = EstadoDAG.caso_una_vez(pd1)
    count(==(mo.X), orden_aplicacion_virtual(Ao)) == 1 ||
        push!(fallos_globales, "dirigido D-6 una vez")
    _, Ar, mr = EstadoDAG.caso_reorg(pd1)
    (mr.tipA == mr.A2 && mr.tipB1 == mr.A2 && mr.tipB3 == mr.B3) ||
        push!(fallos_globales, "dirigido D-7 reorg")
    _, Ah, mh = EstadoDAG.caso_hermanos_transicion(pd1)
    (Ah.validos[mh.Tb1] && Ah.validos[mh.Tb2]) ||
        push!(fallos_globales, "dirigido D-8 hermanos")
    # T04-B (F-15): repetición, orden inverso de nonces y reorganización.
    _, A9, m9 = EstadoDAG.caso_nonce_repeticion_fusionada(pd1)
    S9, _, d9 = aplicar_historia(A9)
    e9 = [d for d in d9 if d[3] == Transicion.ErrNonce]
    (length(e9) == 1 && e9[1][1] == m9.segundo &&
     length(S9.garantias[1].en_retirada) == 1 &&
     S9.garantias[1].nonce_siguiente == m9.n + UInt64(1)) ||
        push!(fallos_globales, "dirigido D-9 repetición fusionada")
    _, A10, m10 = EstadoDAG.caso_nonce_orden_inverso(pd1)
    S10, _, d10 = aplicar_historia(A10)
    e10 = [d for d in d10 if d[3] == Transicion.ErrNonce]
    (length(e10) == 1 && e10[1][1] == m10.Xa &&
     S10.garantias[m10.clave].nonce_siguiente == m10.n + UInt64(1) &&
     !haskey(S10.utxo, m10.utxo)) ||
        push!(fallos_globales, "dirigido D-10 nonce inverso")
    _, A11, m11 = EstadoDAG.caso_nonce_reorg(pd1)
    S11, _, _ = aplicar_historia(A11)
    (m11.tipB3 == m11.B3 && m11.tipA3 == m11.A3 && m11.retiros_B == 1 &&
     length(S11.garantias[1].en_retirada) == 1 &&
     S11.garantias[1].nonce_siguiente == m11.n + UInt64(1)) ||
        push!(fallos_globales, "dirigido D-11 reorg nonce")
    # T04-C: retiro + liberación + transferencia bajo reorganización y vuelta.
    _, A12, m12 = EstadoDAG.caso_retiro_liberacion_reorg(pd1)
    (m12.libA == 1 && m12.libSA == 0 && m12.outSA == 1 && m12.retSA == 0 &&
     m12.nonceSA == m12.n0 + UInt64(2) &&
     m12.libSB == 0 && m12.outSB == 0 && m12.retSB == 1 &&
     m12.nonceSB == m12.n0 + UInt64(1) &&
     m12.libSA2 == 0 && m12.outSA2 == 1 && m12.retSA2 == 0 &&
     m12.nonceSA2 == m12.n0 + UInt64(2) &&
     m12.tipB == m12.B3 && m12.tipA == m12.A4) ||
        push!(fallos_globales, "dirigido D-12 retiro/liberación/reorg")
    # T04-C: punto de aplicación (RD-4) de una liberación inmadura en su propio slot.
    _, A13, m13 = EstadoDAG.caso_liberacion_punto_aplicacion(pd1)
    (m13.spY == m13.Z && m13.slotX == 2 && m13.slotY == 3 && m13.libX == 0 &&
     m13.libY == 1 && m13.libY_slot == m13.slotY &&
     m13.nonceX == m13.n0 + UInt64(1) && m13.nonceY == m13.n0 + UInt64(2) &&
     length(m13.descX) == 1 && m13.descX[1][2] == Transicion.ErrSaldo) ||
        push!(fallos_globales, "dirigido D-13 punto de aplicación")
    # T04-D (F-18): dos liberaciones hermanas (mismo nonce, importes distintos) y
    # sendas transferencias; una liberación aplica y la otra cae por ErrNonce; la
    # transferencia de la rama aplicada aplica y la otra cae por entrada ausente,
    # nunca por colisión de ids.
    _, A14, m14 = EstadoDAG.caso_dos_liberaciones_hermanas(pd1)
    S14, _, d14 = aplicar_historia(A14)
    e14 = [d for d in d14 if d[3] == Transicion.ErrNonce]
    g14 = [d for d in d14 if d[3] == Transicion.ErrDobleGasto]
    (m14.a != m14.b && m14.id_a != m14.id_b && m14.outXb == 1 && m14.outXd == 0 &&
     m14.nonceS == m14.n1 + UInt64(1) && A14.validos[m14.B] &&
     !haskey(S14.utxo, m14.id_b) &&
     length(e14) == 1 && e14[1][1] == m14.segundo &&
     length(g14) == 1 && g14[1][1] == m14.Xd) ||
        push!(fallos_globales, "dirigido D-14 dos liberaciones hermanas")

    # SL-3 (D-15…D-18): evidencia aplicada, duplicada en ramas hermanas,
    # reaparición/undo y descartes (cbid, tardía, sin saldo).
    pdev = EstadoDAG._pd_ev(pd1)
    _, A15, m15 = EstadoDAG.caso_evidencia_aplicada(pdev)
    (m15.valido && m15.incidentes == 1 && m15.quemado > 0 && m15.I1) ||
        push!(fallos_globales, "dirigido D-15 evidencia aplicada")
    _, A16, m16 = EstadoDAG.caso_evidencia_hermanas(pdev)
    (m16.dup == 1 && m16.incidentes == 1 && m16.validos && m16.I1) ||
        push!(fallos_globales, "dirigido D-16 evidencia duplicada")
    _, A17, m17 = EstadoDAG.caso_evidencia_reorg(pdev)
    (m17.inc_past_Xc == 0 && m17.inc_post_Ye == 1 && m17.undo && m17.I1) ||
        push!(fallos_globales, "dirigido D-17 reaparición/undo")
    _, A18, m18 = EstadoDAG.caso_evidencia_descartes(pdev)
    (m18.cbid == 1 && m18.tardia == 1 && m18.sin_saldo && m18.I1) ||
        push!(fallos_globales, "dirigido D-18 descartes")

    # 3) Propiedades IE-1…IE-6
    total_hist = 0
    total_bloques = 0
    total_validos = 0
    total_desc = 0
    total_u3 = 0
    total_ie3 = 0
    ac = EstadoDAG.AcumuladorCobertura()
    for (pi, k) in PUNTOS_T04
        pd = ParamsDAG(PARAMS_DAG_BASE[pi], k)
        fallos_punto = String[]
        ie3_exhaustivos_hechos = 0
        ie3_gastado = 0
        for r in 1:replicas
            rng = StableRNG(seed + UInt64(10_000 * pi + r))
            npost = EstadoDAG.npost_t04c(r)
            A = generar_dag_aleatorio(rng, pd; npost = npost,
                                      pesos = EstadoDAG.PESOS_AJUSTADOS)
            bloques = collect(values(A.por_id))
            total_hist += 1
            total_bloques += length(bloques)
            total_validos += count(v -> v, values(A.validos))
            _, _, desc = aplicar_historia(A)
            total_desc += length(desc)
            total_u3 += length(u3_virtual(A))
            EstadoDAG.acumular_caso!(ac, A)
            f1 = verificar_ie1_ie2_ie4(A)
            f6 = verificar_ie6(A)
            for f in f1
                push!(fallos_punto, "P$pi k$k r$r: $f")
            end
            for f in f6
                push!(fallos_punto, "P$pi k$k r$r: $f")
            end
            # IE-3: todas las permutaciones si hay ≤ 7 bloques (hasta
            # `ie3_exhaustivos` historias por punto); 200 aleatorias si hay más.
            if length(bloques) <= 7 && ie3_exhaustivos_hechos < ie3_exhaustivos
                ordenes = collect(Combinatorics.permutations(1:length(bloques)))
                ie3_exhaustivos_hechos += 1
            else
                ordenes = nothing
            end
            intentos = ordenes === nothing ? 200 : length(ordenes)
            f3 = verificar_ie3(A, bloques; ordenes = ordenes, intentos = intentos,
                               semilla = UInt64(1_000_000 * pi + r))
            for f in f3
                push!(fallos_punto, "P$pi k$k r$r: $f")
            end
            ie3_gastado += intentos
            total_ie3 += intentos
            # IE-5 (solo cadenas sin fusiones), cada 10 réplicas
            if r % 10 == 0
                rng5 = StableRNG(seed + UInt64(500_000 + 10_000 * pi + r))
                pow, bps, Efin = generar_cadena_post(rng5, pd.P; npost = 4)
                A5 = Admision(pd, pow[1], pow[1][end].id)
                resolver!(A5, bps)
                for f in verificar_ie5(A5, bps, Efin)
                    push!(fallos_punto, "P$pi k$k r$r IE-5: $f")
                end
            end
        end
        println(io, "PUNTO P=$pi k=$k replicas=$replicas fallos=$(length(fallos_punto)) ",
                "ie3_ordenes=$ie3_gastado")
        append!(fallos_globales, fallos_punto)
        flush(io)
    end

    # 4) SL-3: rejilla con C-EVP activo y evidencia.
    total_ev = 0
    total_ev_validos = 0
    total_ev_desc = 0
    ev_dup = 0
    ev_tar = 0
    ev_cbid = 0
    for (pi, pdev) in enumerate(PARAMS_DAG_EV)
        fallos_punto = String[]
        for r in 1:replicas
            rng = StableRNG(seed + UInt64(20_000 * pi + r))
            A = generar_dag_aleatorio(rng, pdev; npost = EstadoDAG.npost_t04c(r),
                                      pesos = EstadoDAG.PESOS_AJUSTADOS)
            total_ev += 1
            total_ev_validos += count(v -> v, values(A.validos))
            _, _, desc = aplicar_historia(A)
            total_ev_desc += length(desc)
            for (_, _, e) in desc
                e == Transicion.ErrEvidenciaDuplicada && (ev_dup += 1)
                e == Transicion.ErrEvidenciaTardia && (ev_tar += 1)
                e == Transicion.ErrCbidAjeno && (ev_cbid += 1)
            end
            for f in verificar_ie1_ie2_ie4(A)
                push!(fallos_punto, "EV$pi r$r: $f")
            end
            for f in verificar_ie6(A)
                push!(fallos_punto, "EV$pi r$r: $f")
            end
            bloques = collect(values(A.por_id))
            for f in verificar_ie3(A, bloques; intentos = 50,
                                   semilla = UInt64(2_000_000 + 10_000 * pi + r))
                push!(fallos_punto, "EV$pi r$r: $f")
            end
        end
        append!(fallos_globales, fallos_punto)
        println(io, "PUNTO-EV EV=$pi f=$(pdev.P.f_num)/$(pdev.P.f_den) ",
                "Plazo=$(pdev.P.Plazo_slots) k=$(pdev.k) fallos=$(length(fallos_punto))")
        flush(io)
    end
    println(io, "TOTAL-EV historias=$total_ev validos=$total_ev_validos ",
            "descartes=$total_ev_desc duplicadas=$ev_dup tardias=$ev_tar cbid=$ev_cbid")

    println(io, "TOTAL historias=$total_hist bloques=$(total_bloques) validos=$(total_validos) ",
            "descartes=$(total_desc) rojo_U3=$(total_u3) ie3_ordenes=$(total_ie3)")
    EstadoDAG.escribir_cobertura(io, string("run.jl (seed=", seed,
                                            " replicas=", replicas, ")"), ac)
    for f in Iterators.take(fallos_globales, 40)
        println(io, "FALLO: ", f)
    end
    dt = time() - t0
    @printf(io, "ESTADO = %s\n", isempty(fallos_globales) ? "SUPERADO" : "REFUTADO")
    @printf(io, "tiempo_pared_s = %.1f\n", dt)
    close(io)
    @printf("run: fallos=%d tiempo=%.1fs -> %s\n", length(fallos_globales), dt, salida)
    flush(stdout)
    return isempty(fallos_globales) ? 0 : 1
end

function cabecera(io::IO, seed::UInt64, replicas::Int, ie3::Int, salida::String)
    println(io, "# run.jl T04 · ", Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))
    println(io, "seed = 0x", string(seed, base = 16), " replicas = ", replicas,
            " ie3_exhaustivos_por_punto = ", ie3)
    println(io, "julia = ", VERSION, " hilos_default = ", Threads.nthreads(:default),
            " hilos_interactive = ", Threads.nthreads(:interactive))
    println(io, "CPU = ", Sys.CPU_NAME, " RAM_GB = ", round(Sys.total_memory() / 2^30, digits = 1))
    println(io, "salida = ", salida)
end

exit(main())
