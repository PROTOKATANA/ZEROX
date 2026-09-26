# Batería T01 — X-01 … X-20 e I-1 … I-7 (ORDEN §6).
#
# La rejilla y el muestreo se pueden ajustar por entorno para acotar el tiempo:
#   T01_REJILLA  = reducida | completa      (por defecto reducida)
#   T01_PASO_REJ = entero (paso sobre la rejilla para X-01…X-15)
#   T01_PASO_EQ  = entero (paso sobre la rejilla para X-16…X-20 e I-*)
#   T01_REPLICAS = historias aleatorias por punto de rejilla
#   T01_I3_PERM  = permutaciones aleatorias cuando |bloques| > 7

using Test
using Transicion
using StableRNGs
using Combinatorics
using Random

const REJILLA = Symbol(get(ENV, "T01_REJILLA", "reducida"))
const PASO_REJ = parse(Int, get(ENV, "T01_PASO_REJ", "1"))
const PASO_EQ = parse(Int, get(ENV, "T01_PASO_EQ", "1"))
const REPLICAS = parse(Int, get(ENV, "T01_REPLICAS", "2"))
const I3_PERM = parse(Int, get(ENV, "T01_I3_PERM", "5"))

puntos_rej() = puntos_rejilla(rejilla = REJILLA)[1:PASO_REJ:end]
puntos_eq() = puntos_rejilla(rejilla = REJILLA)[1:PASO_EQ:end]

# ---------------------------------------------------------------------------
# X-01 … X-15 — rechazos con error explícito
# ---------------------------------------------------------------------------

@testset "X-01…X-15 (rechazos)" begin
    por_caso = Dict{String,Vector{Bool}}()
    fallos = String[]
    for P in puntos_rej()
        for c in escenarios_rechazo(P)
            r = aplicar(c.padre, c.B, P)
            ok = (r isa Err) && (r == c.esperado)
            if startswith(c.nombre, "X-11") || c.nombre == "X-12"
                ok = ok && !es_terminal(c.historial, P)
            end
            push!(get!(por_caso, c.nombre, Bool[]), ok)
            if !ok && length(fallos) < 20
                push!(fallos, string(c.nombre, " esperado=", c.esperado, " obtenido=", r))
            end
        end
    end
    for n in sort(collect(keys(por_caso)))
        @testset "$n" begin
            @test all(por_caso[n])
            @test length(por_caso[n]) > 0
        end
    end
    isempty(fallos) || @info "primeros fallos X" fallos
end

# ---------------------------------------------------------------------------
# Ratificaciones v0.1 (R-6…R-9) — regresión dirigida
# ---------------------------------------------------------------------------

@testset "Ratificaciones v0.1 (R-6…R-9)" begin
    P = Params(H_dep = 1, M_cb = 1, M_dep = 0, H_corte_min = 2, W_min = 1,
               S_min = 1, K_min = 1, q = 1, M_res_slots = 1, M_dep_slots = 1,
               M_rec_slots = 1, R_slots = 1, F_slots = typemax(Int), sec = SEC0)
    E0 = estado_inicial(P)
    G = genesis_bloque()
    Eg = aplicar(E0, G, P)
    # R-7: coinbase PoW sin salidas ⇒ ErrEmision.
    BR7 = gen_pow(id = 2, padre = 1, altura = 1, txs = [tx_coinbase(Salida[])])
    @test aplicar(Eg, BR7, P) == ErrEmision
    # R-7 también en el génesis si trae una coinbase sin salidas.
    Gvacio = Bloque(id = 1, familia = Genesis, padre = 0, altura = 0,
                    txs = [tx_coinbase(Salida[])])
    @test aplicar(E0, Gvacio, P) == ErrEmision
    # Prefijo válido de 1 bloque PoW (salidas 1000:dueño1, 1001:dueño2).
    pref, ests, _, _, _ = construir_poW(StableRNG(77), P; hasta = 1,
                                        depositar = false, transferir = false)
    E1 = ests[end]
    pid = pref[end].id
    # R-6: coinbase única en segunda posición ⇒ ErrEmision.
    BR6 = gen_pow(id = pid + 1, padre = pid, altura = 2,
                  txs = [tx_transferencia([1000], [Salida(1100, UInt64(4), 2, OrigenTx, -1, -1)], 1),
                         tx_coinbase([Salida(1101, UInt64(10), 1, OrigenTx, -1, -1)])])
    @test aplicar(E1, BR6, P) == ErrEmision
    # R-9: transferencia sin entradas ⇒ ErrEmision.
    BR9a = gen_pow(id = pid + 1, padre = pid, altura = 2,
                   txs = [tx_coinbase([Salida(1102, UInt64(10), 1, OrigenTx, -1, -1)]),
                          tx_transferencia(Int[], [Salida(1103, UInt64(1), 2, OrigenTx, -1, -1)], 1)])
    @test aplicar(E1, BR9a, P) == ErrEmision
    # R-9: transferencia con entradas y sin salidas ⇒ ErrSaldo.
    BR9b = gen_pow(id = pid + 1, padre = pid, altura = 2,
                   txs = [tx_coinbase([Salida(1104, UInt64(10), 1, OrigenTx, -1, -1)]),
                          tx_transferencia([1000], Salida[], 1)])
    @test aplicar(E1, BR9b, P) == ErrSaldo
    # R-8: importe 0 en Depósito y Retiro ⇒ ErrSaldo.
    BR8a = gen_pow(id = pid + 1, padre = pid, altura = 2,
                   txs = [tx_coinbase([Salida(1105, UInt64(10), 1, OrigenTx, -1, -1)]),
                          tx_deposito([1000], 1, 0, 1; nonce = nonce_de(E1, 1))])
    @test aplicar(E1, BR8a, P) == ErrSaldo
    BR8b = gen_pow(id = pid + 1, padre = pid, altura = 2,
                   txs = [tx_coinbase([Salida(1106, UInt64(10), 1, OrigenTx, -1, -1)]),
                          tx_retiro(1, 0, 1; nonce = nonce_de(E1, 1))])
    @test aplicar(E1, BR8b, P) == ErrSaldo
    # R-8 en PoST: CoinbasePost y Liberación con importe 0 ⇒ ErrSaldo.
    tpost = construir_poW(StableRNG(78), P; hasta = 10, depositar = true,
                          transferir = false)
    ET = tpost[2][end]
    @test ET.terminal != -1
    if ET.terminal != -1
        T = tpost[1][end]
        BR8c = gen_post(id = T.id + 1, padre = T.id, slot = 1, productor = 1,
                        peso = 1, txs = [tx_coinbase_post(0)])
        @test aplicar(ET, BR8c, P) == ErrSaldo
        BR8d = gen_post(id = T.id + 1, padre = T.id, slot = 1, productor = 1,
                        peso = 1, txs = [tx_coinbase_post(3),
                                         tx_liberacion(1, 0, 1;
                                                       nonce = nonce_de(ET, 1))])
        @test aplicar(ET, BR8d, P) == ErrSaldo
    end
end

# ---------------------------------------------------------------------------
# X-16 — independencia del orden de llegada
# ---------------------------------------------------------------------------

function historia_X16(P::Params, seed::Int)
    rng = StableRNG(seed)
    alta = P.sec == SECA ? max(P.H_dep, 1) : -1
    pref = construir_poW(rng, P; hasta = max(P.H_corte_min - 1, 1),
                         depositar = true, alta_en = alta, prueba_en = alta,
                         transferir = false)
    bloques, estados = pref[1], pref[2]
    E0 = estados[end]
    p0 = bloques[end].id
    h = P.H_corte_min
    B1 = gen_pow(id = pref[3], padre = p0, altura = h,
                 txs = [tx_coinbase([Salida(960000, UInt64(10), 1, OrigenTx, -1, -1)])])
    E1, _ = hijo_pow(P, E0, B1.id, p0, h; txs = B1.txs)
    E1 === nothing && return Bloque[]
    sector = P.sec == SECA ? 1 : 0
    post, _, _ = cadena_post(P, E1, pref[3] + 50, B1.id, 2;
                             productor = 1, peso = 1, sector = sector)
    return vcat(bloques, [B1], post)
end

@testset "X-16 (orden de llegada)" begin
    ok = true
    n_hist = 0
    for (i, P) in enumerate(puntos_eq())
        bloques = historia_X16(P, 0x1600 + i)
        isempty(bloques) && continue
        ref = seleccionar(bloques, P)
        ref.punta == -1 && continue
        n_hist += 1
        n = length(bloques)
        # Muestreo determinista de órdenes (identidad, inverso y aleatorios);
        # la exhaustividad de permutaciones para n pequeño corresponde a I-3.
        perms = Vector{Vector{Int}}()
        push!(perms, collect(1:n))
        push!(perms, reverse(collect(1:n)))
        for k in 1:I3_PERM
            push!(perms, randperm(StableRNG(0x16ff + i * 7 + k), n))
        end
        refhash = hash_canonico(ref.estado)
        for perm in perms
            tip, E = nodo_en_linea(bloques[collect(perm)], P)
            if !(tip == ref.punta && hash_canonico(E) == refhash)
                ok = false
                @info "X-16 discrepancia" P tip ref.punta
                break
            end
        end
        ok || break
    end
    @test n_hist > 0
    @test ok
end

# ---------------------------------------------------------------------------
# X-17 / X-18 — dos terminales; rama PoW tardía
# ---------------------------------------------------------------------------

@testset "X-17 (dos terminales con pesos)" begin
    ok3 = true
    difiere_fc1 = 0
    difiere_fc2 = 0
    n = 0
    for P in puntos_eq()
        bloques = historia_dos_terminales(P; pesos = (2, 1), trabajo_extra = 1)
        bloques === nothing && continue
        n += 1
        tip3 = seleccionar(bloques, conseleccion(P, FC3)).punta
        tip1 = seleccionar(bloques, conseleccion(P, FC1)).punta
        tip2 = seleccionar(bloques, conseleccion(P, FC2)).punta
        tip1 != tip3 && (difiere_fc1 += 1)
        tip2 != tip3 && (difiere_fc2 += 1)
        if P.seleccion == FC3
            res = seleccionar(bloques, P)
            ok3 = ok3 && res.estado.peso_sufijo == 2
        end
    end
    @test n > 0
    @test ok3
    @info "X-17 diferencias respecto a FC-3" difiere_fc1 difiere_fc2
end

@testset "X-18 (rama PoW tardía con más trabajo)" begin
    ok3 = true
    difiere_fc1 = 0
    difiere_fc2 = 0
    n = 0
    for P in puntos_eq()
        bloques = historia_dos_terminales(P; pesos = (2, 0), trabajo_extra = 100)
        bloques === nothing && continue
        n += 1
        tip3 = seleccionar(bloques, conseleccion(P, FC3)).punta
        tip1 = seleccionar(bloques, conseleccion(P, FC1)).punta
        tip2 = seleccionar(bloques, conseleccion(P, FC2)).punta
        tip1 != tip3 && (difiere_fc1 += 1)
        tip2 != tip3 && (difiere_fc2 += 1)
        if P.seleccion == FC3
            res = seleccionar(bloques, P)
            ok3 = ok3 && res.estado.peso_sufijo == 2
        end
    end
    @test n > 0
    @test ok3
    @info "X-18 diferencias respecto a FC-3" difiere_fc1 difiere_fc2
end

# ---------------------------------------------------------------------------
# X-19 — reorganización que elimina el depósito habilitante
# ---------------------------------------------------------------------------

@testset "X-19 (reorg elimina depósito)" begin
    ok = true
    n = 0
    for P in puntos_eq()
        pref, sin1 = historia_reorg(P)
        (pref[2][end].terminal == -1 || sin1[2][end].terminal == -1) && continue
        n += 1
        TA = pref[1][end]
        TB = sin1[1][end]
        # Transición sobre la rama sin depósito de la clave 1 ⇒ ErrGarantia.
        B = gen_post(id = TB.id + 1, padre = TB.id, slot = 1, productor = 1, peso = 1,
                     sector = P.sec == SECA ? Transicion.Sector_de_ET(sin1[2][end]) : 0)
        r = aplicar(sin1[2][end], B, P)
        ok = ok && (r == ErrGarantia)
        # Undo exacto del prefijo con depósito.
        Eprev = pref[2][end - 1]
        r2 = aplicar_con_undo(Eprev, pref[1][end], P)
        if r2 isa Err
            ok = false
        else
            E2, undo = r2
            ok = ok && hash_canonico(deshacer(E2, undo)) == hash_canonico(Eprev)
        end
    end
    @test n > 0
    @test ok
end

# ---------------------------------------------------------------------------
# X-20 — undo exacto de prefijos válidos
# ---------------------------------------------------------------------------

@testset "X-20 (undo exacto)" begin
    ok = true
    n = 0
    for P in puntos_eq()
        bloques = generar_historia(StableRNG(0x2020), P; max_altura = 8, max_post = 2)
        memo, por_id = construir_validos(bloques, P)
        for id in keys(memo)
            b = por_id[id]
            b.familia == Genesis && continue
            Ep = get(memo, b.padre, nothing)
            Ep === nothing && continue
            r = aplicar_con_undo(Ep, b, P)
            r isa Err && continue
            E2, undo = r
            h0 = hash_canonico(Ep)
            if hash_canonico(deshacer(E2, undo)) != h0 || hash_canonico(Ep) != h0
                ok = false
                break
            end
            n += 1
        end
        ok || break
    end
    @test n > 0
    @test ok
end

# ---------------------------------------------------------------------------
# I-1 … I-7 — propiedades con historias aleatorias
# ---------------------------------------------------------------------------

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

@testset "I-1…I-7 (historias aleatorias)" begin
    n_hist = 0
    n_undo = 0
    n_perm = 0
    fallos_i1 = 0
    fallos_i1b = 0
    fallos_i2 = 0
    fallos_i3 = 0
    fallos_i4 = 0
    fallos_i5 = 0
    fallos_i6 = 0
    fallos_i7 = 0
    for (i, P) in enumerate(puntos_eq())
        for rep in 1:REPLICAS
            rng = StableRNG(0x5a5a + UInt64(i) * 131 + UInt64(rep))
            bloques = generar_historia(rng, P; max_altura = 9, max_post = 3)
            memo, por_id = construir_validos(bloques, P)
            n_hist += 1
            # I-1 / I-1b en cada estado válido.
            for (_, E) in memo
                invariante_I1(E) || (fallos_i1 += 1)
                invariante_I1b(E) || (fallos_i1b += 1)
            end
            # I-2 undo exacto; I-6 ninguna coinbase inmadura gastada.
            for id in keys(memo)
                b = por_id[id]
                b.familia == Genesis && continue
                Ep = get(memo, b.padre, nothing)
                Ep === nothing && continue
                h0 = hash_canonico(Ep)
                r = aplicar_con_undo(Ep, b, P)
                r isa Err && continue
                E2, undo = r
                (hash_canonico(deshacer(E2, undo)) == h0 &&
                 hash_canonico(Ep) == h0) || (fallos_i2 += 1)
                n_undo += 1
                # I-6: toda entrada coinbase_pow de un depósito/transferencia
                # debía ser gastable en el punto del bloque.
                for tx in b.txs
                    (tx.tipo == TxDeposito || tx.tipo == TxTransferencia) || continue
                    for eid in tx.entradas
                        o = get(Ep.utxo, eid, nothing)
                        o === nothing && continue
                        if o.origen == OrigenCoinbasePow
                            punto = b.familia == PoW ? b.altura : b.slot
                            fase = b.familia == PoW ? FasePoW :
                                   (Ep.fase == FasePoW ? FasePoST : Ep.fase)
                            gastable_en(o, fase, Ep.altura_terminal, Ep.s0, P, punto) ||
                                (fallos_i6 += 1)
                        end
                    end
                end
                # I-4 unicidad de fase.
                if b.familia == PoW
                    E2.terminal == -1 || E2.terminal == b.id || (fallos_i4 += 1)
                end
            end
            res = seleccionar(bloques, P)
            res.punta == -1 && continue
            # I-5: pesos y trabajo del sufijo son sumas de campos de bloque.
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
            (peso_esp == res.estado.peso_sufijo && trab_esp == res.estado.trabajo_acum) ||
                (fallos_i5 += 1)
            # I-7: todo bloque PoST válido exige un terminal en su pasado.
            for (id, E) in memo
                por_id[id].familia == PoST || continue
                E.terminal != -1 || (fallos_i7 += 1)
                if P.corte == CUT_HWPhi && E.terminal != -1
                    # el terminal del pasado debe ser el primero en cumplir TRN-04.
                    hist = Bloque[por_id[c] for c in reverse(cadena_de(E.terminal, por_id))]
                    es_terminal(hist, P) || (fallos_i7 += 1)
                end
            end
            # I-3: selección independiente del orden (muestreada).
            (n_hist == 1 || n_hist % 7 == 0) || continue
            n = length(bloques)
            refh = hash_canonico(res.estado)
            perms = n <= 5 ? permutations(1:n) :
                    (randperm(rng, n) for _ in 1:I3_PERM)
            for perm in perms
                tip, E = nodo_en_linea(bloques[collect(perm)], P)
                n_perm += 1
                if !(tip == res.punta && hash_canonico(E) == refh)
                    fallos_i3 += 1
                    break
                end
            end
        end
    end
    @test n_hist > 0
    @test fallos_i1 == 0
    @test fallos_i1b == 0
    @test fallos_i2 == 0
    @test fallos_i3 == 0
    @test fallos_i4 == 0
    @test fallos_i5 == 0
    @test fallos_i6 == 0
    @test fallos_i7 == 0
    @info "I-*" n_hist n_undo n_perm fallos_i1 fallos_i1b fallos_i2 fallos_i3 fallos_i4 fallos_i5 fallos_i6 fallos_i7
end

# ---------------------------------------------------------------------------
# F-15 — nonce por clave de garantía (T01-D)
# ---------------------------------------------------------------------------

function _error_neg(bloques::Vector{Bloque}, P::Params)
    memo, _ = construir_validos(bloques, P)
    B = last(bloques)
    Ep = get(memo, B.padre, nothing)
    Ep === nothing && return :sinpadre
    r = aplicar(Ep, B, P)
    return r isa Err ? r : :ok
end

@testset "F-15 (nonce por clave)" begin
    idxs, puntos = puntos_negativos()
    fam = Dict{String,Int}()
    fase = Dict{String,Int}()
    ok_rech = true
    ok_val = true
    n_validos = 0
    for i in idxs
        P = puntos[i]
        for c in casos_nonce(P)
            got = _error_neg(c.bloques, P)
            if got != c.esperado
                ok_rech = false
                @info "F-15 rechazo inesperado" c.nombre c.esperado got
            end
            fam[c.nombre] = get(fam, c.nombre, 0) + 1
            fase[c.fase] = get(fase, c.fase, 0) + 1
        end
        for (_, bloques) in casos_nonce_validos(P)
            memo, _ = construir_validos(bloques, P)
            haskey(memo, last(bloques).id) || (ok_val = false)
            n_validos += 1
        end
    end
    for k in ["neg-nonce-rep-retiro", "neg-nonce-rep-liberacion",
              "neg-nonce-saltado", "neg-nonce-viejo", "neg-nonce-dos-nn"]
        @test get(fam, k, 0) >= 30
    end
    @test fase["PoW"] >= 30
    @test fase["PoST"] >= 30
    @test n_validos > 0
    @test ok_rech
    @test ok_val
    @info "F-15" n_validos fam fase
end

# ---------------------------------------------------------------------------
# T01-E — id de la salida de una liberación (F-18) y partición del espacio de ids
# ---------------------------------------------------------------------------

@testset "T01-E (id de liberación F-18)" begin
    # (1) Fórmula e inyectividad en un dominio pequeño.
    tup = [(c, n, i) for c in (0, 1, 2, 5) for n in (0, 1, 2, 3)
           for i in (0, 1, 2, 7)]
    ids = [ID_LIB(c, n, i) for (c, n, i) in tup]
    @test all(x -> x >= LIMITE_ID_EXPLICITO, ids)
    @test length(unique(ids)) == length(ids)
    @test ID_LIB(2, 3, 7) == (Int(1) << 62) + 2 * (Int(1) << 40) +
                              3 * (Int(1) << 20) + 7
    @test ID_LIB(0, 0, 0) == LIMITE_ID_EXPLICITO
    # (2) Fuera de rango ⇒ error explícito, nunca un id truncado.
    @test ID_LIB(Int(1) << 20, 0, 0) === ErrDesbordamiento
    @test ID_LIB(0, Int(1) << 20, 0) === ErrDesbordamiento
    @test ID_LIB(0, 0, Int(1) << 20) === ErrDesbordamiento
    @test ID_LIB(-1, 0, 0) === ErrDesbordamiento
    @test ID_LIB(0, -1, 0) === ErrDesbordamiento
    # (3) Un id explícito en el rango reservado [2⁶², …) ⇒ ErrDesbordamiento;
    #     el mayor id explícito permitido (2⁶² − 1) sí aplica.
    P = Params(H_dep = 1, M_cb = 1, M_dep = 0, H_corte_min = 2, W_min = 1,
               S_min = 1, K_min = 1, q = 1, M_res_slots = 1, M_dep_slots = 1,
               M_rec_slots = 1, R_slots = 1, F_slots = typemax(Int), sec = SEC0)
    pref, ests, _, _, _ = construir_poW(StableRNG(79), P; hasta = 1,
                                        depositar = false, transferir = false)
    E1 = ests[end]
    pid = pref[end].id
    Bmal = gen_pow(id = pid + 1, padre = pid, altura = 2,
                   txs = [tx_coinbase([Salida(LIMITE_ID_EXPLICITO, UInt64(1), 1,
                                              OrigenTx, -1, -1)])])
    @test aplicar(E1, Bmal, P) == ErrDesbordamiento
    Bokl = gen_pow(id = pid + 1, padre = pid, altura = 2,
                   txs = [tx_coinbase([Salida(LIMITE_ID_EXPLICITO - 1, UInt64(1),
                                              1, OrigenTx, -1, -1)])])
    @test !(aplicar(E1, Bokl, P) isa Err)
    # (4) La salida de una liberación lleva exactamente ID_LIB(clave, nonce, importe).
    tpost = construir_poW(StableRNG(80), P; hasta = 10, depositar = true,
                          transferir = false)
    ET = tpost[2][end]
    @test ET.terminal != -1
    if ET.terminal != -1
        T = tpost[1][end]
        nret = nonce_de(ET, 1)
        B_ret = gen_post(id = T.id + 1, padre = T.id, slot = 1, productor = 1,
                         peso = 1,
                         txs = [tx_coinbase_post(3),
                                tx_retiro(1, 1, 1; nonce = nret)])
        E_ret = aplicar(ET, B_ret, P)
        @test !(E_ret isa Err)
        if !(E_ret isa Err)
            nlib = nonce_de(E_ret, 1)
            B_lib = gen_post(id = B_ret.id + 1, padre = B_ret.id, slot = 2,
                             productor = 1, peso = 1,
                             txs = [tx_coinbase_post(3),
                                    tx_liberacion(1, 1, 1; nonce = nlib)])
            E_lib = aplicar(E_ret, B_lib, P)
            @test !(E_lib isa Err)
            if !(E_lib isa Err)
                libs = [o for (_, o) in E_lib.utxo
                        if o.origen == OrigenLiberacion]
                @test length(libs) == 1
                @test libs[1].id == ID_LIB(1, nlib, 1)
                @test libs[1].id >= LIMITE_ID_EXPLICITO
            end
        end
    end
end
