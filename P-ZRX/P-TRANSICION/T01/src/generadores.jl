# Generadores de historias y escenarios X-nn (ORDEN §6).
#
# Todo se construye sobre tipos concretos del módulo. Los escenarios de rechazo
# devuelven `(nombre, estado_padre, bloque, error_esperado)` para que la batería
# compruebe el TIPO de error, no solo que falle.

# ---------------------------------------------------------------------------
# Constructores
# ---------------------------------------------------------------------------

genesis_bloque(; id = 1) =
    Bloque(id = id, familia = Genesis, padre = 0, altura = 0, txs = Tx[])

gen_pow(; id, padre, altura, txs = Tx[], trabajo = 1, pow_ok = true) =
    Bloque(id = id, familia = PoW, padre = padre, altura = altura,
           trabajo = trabajo, pow_ok = pow_ok, txs = txs)

gen_post(; id, padre, slot, productor, peso = 1, sector = 0, req = 0, txs = Tx[]) =
    Bloque(id = id, familia = PoST, padre = padre, slot = slot,
           productor = productor, peso = peso, sector = sector,
           requisito_declarado = req, txs = txs)

# ---------------------------------------------------------------------------
# Cadena PoW válida (hasta un terminal, o hasta `hasta`)
# ---------------------------------------------------------------------------

function construir_poW(rng::AbstractRNG, P::Params; hasta::Int = 10,
                       depositar::Bool = true, trabajo::Int = 1,
                       alta_en::Int = -1, prueba_en::Int = -1,
                       alta2_en::Int = -1, transferir::Bool = false,
                       retirar_en::Int = -1, sin_clave1::Bool = false,
                       claves_extra::Vector{Int} = Int[])
    bloques = Bloque[genesis_bloque()]
    E = aplicar(estado_inicial(P), bloques[1], P)
    E isa Err && error("génesis inválido: $E")
    estados = Estado[E]
    next_id = 2
    out_id = 1000
    prod = 1
    for h in 1:hasta
        txs = Tx[]
        if h == 1
            if sin_clave1
                push!(txs, tx_coinbase([Salida(out_id, UInt64(10), 2, OrigenTx, -1, -1)]))
                out_id += 1
            else
                push!(txs, tx_coinbase([Salida(out_id, UInt64(5), 1, OrigenTx, -1, -1),
                                       Salida(out_id + 1, UInt64(5), 2, OrigenTx, -1, -1)]))
                out_id += 2
            end
        else
            dst = isempty(claves_extra) ? prod : claves_extra[mod1(h, length(claves_extra))]
            push!(txs, tx_coinbase([Salida(out_id, UInt64(10), dst, OrigenTx, -1, -1)]))
            out_id += 1
        end
        txs_ok = copy(txs)
        Ebase = E
        Bcb = gen_pow(id = next_id, padre = bloques[end].id, altura = h,
                      txs = txs_ok, trabajo = trabajo)
        r = aplicar(Ebase, Bcb, P)
        r isa Err && error("coinbase inválida en h=$h: $r")
        Et = r

        intentar(cand) = begin
            push!(txs_ok, cand)
            Bx = gen_pow(id = next_id, padre = bloques[end].id, altura = h,
                         txs = txs_ok, trabajo = trabajo)
            rr = aplicar(Ebase, Bx, P)
            if rr isa Err
                pop!(txs_ok)
                nothing
            else
                rr
            end
        end

        if depositar && h >= P.H_dep
            maduras = Salida[]
            for (_, o) in Et.utxo
                if o.origen == OrigenCoinbasePow && h >= o.creada_en_altura + P.M_cb
                    push!(maduras, o)
                end
            end
            sort!(maduras, by = x -> x.id)
            for o in maduras
                r2 = intentar(tx_deposito([o.id], o.dueño, Int(o.valor), o.dueño))
                r2 === nothing || (Et = r2)
            end
        end
        if P.sec == SECA && h == alta_en && h >= P.H_dep
            r2 = intentar(tx_alta_sector(1, prod, prod))
            r2 === nothing || (Et = r2)
        end
        if P.sec == SECA && h == prueba_en
            r2 = intentar(tx_prueba_sector(1, prod))
            r2 === nothing || (Et = r2)
        end
        if P.sec == SECA && h == alta2_en && h >= P.H_dep
            r2 = intentar(tx_alta_sector(2, prod, prod))
            r2 === nothing || (Et = r2)
        end
        if h == retirar_en
            g = get(Et.garantias, prod, nothing)
            if g !== nothing && g.activo >= UInt64(P.q)
                r2 = intentar(tx_retiro(prod, 1, prod))
                r2 === nothing || (Et = r2)
            end
        end
        if transferir
            gastables = Salida[]
            for (_, o) in Et.utxo
                if gastable(Et, o, P, h) && Int(o.valor) >= 2
                    push!(gastables, o)
                end
            end
            if !isempty(gastables)
                o = gastables[rand(rng, 1:length(gastables))]
                dst = rand(rng, 1:3)
                r2 = intentar(tx_transferencia([o.id],
                              [Salida(out_id, o.valor - UInt64(1), dst, OrigenTx, -1, -1)],
                              o.dueño))
                if r2 !== nothing
                    Et = r2
                    out_id += 1
                end
            end
        end
        B = gen_pow(id = next_id, padre = bloques[end].id, altura = h,
                    txs = txs_ok, trabajo = trabajo)
        r = aplicar(Ebase, B, P)
        r isa Err && error("bloque PoW inválido en h=$h: $r")
        E = r
        push!(bloques, B)
        push!(estados, E)
        next_id += 1
        E.terminal == B.id && break
    end
    return bloques, estados, next_id, out_id, prod
end

# ---------------------------------------------------------------------------
# Extensión PoST
# ---------------------------------------------------------------------------

function extender_post(rng::AbstractRNG, P::Params, bloques::Vector{Bloque},
                       estados::Vector{Estado}, next_id::Int, out_id::Int,
                       prod::Int; max_post::Int = 3)
    E = estados[end]
    E.terminal == -1 && return bloques, estados, next_id, out_id
    parent = bloques[end].id
    slot = 0
    retiro_hecho = false
    for _ in 1:max_post
        slot += rand(rng, 1:2)
        sector = P.sec == SECA ? 1 : 0
        txs_ok = Tx[tx_coinbase_post(3)]
        Ebase = E
        B0 = gen_post(id = next_id, padre = parent, slot = slot, productor = prod,
                      peso = 1, sector = sector, txs = txs_ok)
        r = aplicar(Ebase, B0, P)
        r isa Err && break
        Et = r

        intentar_post(cand) = begin
            push!(txs_ok, cand)
            Bx = gen_post(id = next_id, padre = parent, slot = slot,
                          productor = prod, peso = 1, sector = sector, txs = txs_ok)
            rr = aplicar(Ebase, Bx, P)
            if rr isa Err
                pop!(txs_ok)
                nothing
            else
                rr
            end
        end

        g = get(Et.garantias, prod, nothing)
        if !retiro_hecho && g !== nothing && g.activo > UInt64(P.q)
            r2 = intentar_post(tx_retiro(prod, 1, prod))
            if r2 !== nothing
                Et = r2
                retiro_hecho = true
            end
        end
        gl = get(Et.garantias, prod, nothing)
        if gl !== nothing
            for er in gl.en_retirada
                if er.inicio_slot + P.R_slots <= slot
                    r2 = intentar_post(tx_liberacion(prod, er.importe, prod))
                    r2 === nothing || (Et = r2)
                    break
                end
            end
        end
        if rand(rng) < 0.5
            gastables = Salida[]
            for (_, o) in Et.utxo
                if gastable(Et, o, P, slot) && Int(o.valor) >= 2
                    push!(gastables, o)
                end
            end
            if !isempty(gastables)
                o = gastables[rand(rng, 1:length(gastables))]
                r2 = intentar_post(tx_transferencia([o.id],
                      [Salida(out_id, o.valor - UInt64(1), rand(rng, 1:3), OrigenTx, -1, -1)],
                      o.dueño))
                if r2 !== nothing
                    Et = r2
                    out_id += 1
                end
            end
        end
        B = gen_post(id = next_id, padre = parent, slot = slot, productor = prod,
                     peso = 1, sector = sector, txs = txs_ok)
        r = aplicar(Ebase, B, P)
        r isa Err && break
        E = r
        push!(bloques, B)
        push!(estados, E)
        next_id += 1
        parent = B.id
    end
    return bloques, estados, next_id, out_id
end

# ---------------------------------------------------------------------------
# Inyección de bloques inválidos (≈ mitad válidos)
# ---------------------------------------------------------------------------

function bloque_invalido(rng::AbstractRNG, bloques::Vector{Bloque})
    idmax = maximum(b.id for b in bloques) + 1
    padre = bloques[rand(rng, 1:length(bloques))].id
    t = rand(rng, 1:5)
    if t == 1
        return gen_pow(id = idmax, padre = padre, altura = 0, txs = Tx[], pow_ok = false)
    elseif t == 2
        return gen_pow(id = idmax, padre = padre, altura = 0,
                       txs = [tx_coinbase([Salida(900000 + idmax, UInt64(100), 1, OrigenTx, -1, -1)])])
    elseif t == 3
        return gen_post(id = idmax, padre = padre, slot = 0, productor = 9999, peso = 1)
    elseif t == 4
        return gen_post(id = idmax, padre = padre, slot = 1, productor = 9999, peso = 0)
    else
        return gen_pow(id = idmax, padre = padre, altura = 0,
                       txs = [tx_transferencia([999999], [Salida(900001 + idmax, UInt64(1), 1, OrigenTx, -1, -1)], 1)])
    end
end

function generar_historia(rng::AbstractRNG, P::Params; max_altura::Int = 9,
                          max_post::Int = 3)
    alta = P.sec == SECA ? max(P.H_dep, 1) : -1
    bloques, estados, next_id, out_id, prod =
        construir_poW(rng, P; hasta = max_altura, depositar = true,
                      alta_en = alta, prueba_en = alta, transferir = true,
                      retirar_en = (max_altura >= P.H_corte_min ? P.H_corte_min : -1))
    bloques, estados, next_id, out_id =
        extender_post(rng, P, bloques, estados, next_id, out_id, prod; max_post = max_post)
    n_validos = length(estados)
    for _ in 1:n_validos
        push!(bloques, bloque_invalido(rng, bloques))
    end
    return bloques
end

# ---------------------------------------------------------------------------
# Rejilla de parámetros
# ---------------------------------------------------------------------------

function puntos_rejilla(; rejilla::Symbol = :reducida)
    if rejilla == :reducida
        H_deps = [1, 2]
        M_cbs = [1, 3]
        M_deps = [0, 2]
        W_mins = [1, 4]
        S_mins = [1, 10]
        K_mins = [1, 2]
        qs = [1, 5]
        M_res = [1, 3]
        M_dep_s = [1, 2]
        M_rec = [1, 2]
        R_s = [1, 3]
        F_s = [2, typemax(Int)]
        secs = [SEC0, SECA]
        cortes = [CUT_HWPhi, CUT_H, CUT_W]
        sels = [FC3, FC1, FC2]
    else
        H_deps = [1, 2, 3]
        M_cbs = [1, 2, 3, 5]
        M_deps = [0, 1, 2, 4]
        W_mins = [1, 2, 4, 8]
        S_mins = [1, 5, 10, 20]
        K_mins = [1, 2, 3]
        qs = [1, 2, 5, 10]
        M_res = [1, 2, 3, 5]
        M_dep_s = [1, 2, 3]
        M_rec = [1, 2, 3]
        R_s = [1, 2, 3, 5]
        F_s = [2, 3, typemax(Int)]
        secs = [SEC0, SECA]
        cortes = [CUT_HWPhi, CUT_H, CUT_W]
        sels = [FC3, FC1, FC2]
    end
    puntos = Params[]
    for H_dep in H_deps, M_cb in M_cbs, M_dep in M_deps
        base = max(H_dep, 1 + M_cb) + M_dep
        for H_corte_min in (base, base + 1),
            W_min in W_mins, S_min in S_mins, K_min in K_mins, q in qs,
            M_res_slots in M_res, M_dep_slots in M_dep_s, M_rec_slots in M_rec,
            R_slots in R_s, F_slots in F_s, sec in secs, corte in cortes,
            selsel in sels
            push!(puntos, Params(H_dep = H_dep, M_cb = M_cb, M_dep = M_dep,
                                 H_corte_min = H_corte_min, W_min = W_min,
                                 S_min = S_min, K_min = K_min, q = q,
                                 M_res_slots = M_res_slots, M_dep_slots = M_dep_slots,
                                 M_rec_slots = M_rec_slots, R_slots = R_slots,
                                 F_slots = F_slots, sec = sec, corte = corte,
                                 seleccion = selsel))
        end
    end
    return puntos
end

# ---------------------------------------------------------------------------
# Escenarios X-01 … X-15
# ---------------------------------------------------------------------------

# Devuelve casos `(nombre, padre, B, esperado, historial)` donde `padre` es el
# estado (posiblemente manual) sobre el que se aplica `B`, y `historial` es la
# cadena asociada (vacía si no se necesita para `es_terminal`).
function escenarios_rechazo(P::Params)
    Caso = NamedTuple{(:nombre, :padre, :B, :esperado, :historial)}
    casos = Caso[]

    gen_only = construir_poW(StableRNG(1), P; hasta = 0, depositar = false)
    Eg = gen_only[2][end]
    gid = gen_only[1][end].id
    alta = P.sec == SECA ? max(P.H_dep, 1) : -1

    # --- X-01: génesis con coinbase > 0 --------------------------------
    Bgen = Bloque(id = gid + 1, familia = Genesis, padre = 0, altura = 0,
                  txs = [tx_coinbase([Salida(1, UInt64(1), 1, OrigenTx, -1, -1)])])
    push!(casos, (nombre = "X-01", padre = Eg, B = Bgen,
                  esperado = ErrGenesis, historial = Bloque[]))

    # --- X-02: coinbase PoW por encima del subsidio --------------------
    B2 = gen_pow(id = gid + 1, padre = gid, altura = 1,
                 txs = [tx_coinbase([Salida(1, UInt64(11), 1, OrigenTx, -1, -1)])])
    push!(casos, (nombre = "X-02", padre = Eg, B = B2,
                  esperado = ErrEmision, historial = Bloque[]))

    # --- X-03a: gasto de coinbase_pow inmadura en el mismo bloque ------
    B3 = gen_pow(id = gid + 1, padre = gid, altura = 1,
                 txs = [tx_coinbase([Salida(50, UInt64(10), 1, OrigenTx, -1, -1)]),
                        tx_transferencia([50], [Salida(51, UInt64(9), 2, OrigenTx, -1, -1)], 1)])
    push!(casos, (nombre = "X-03", padre = Eg, B = B3,
                  esperado = ErrInmaduro, historial = Bloque[]))

    # --- cadena con terminal -------------------------------------------
    tb = construir_poW(StableRNG(7), P; hasta = 10, depositar = true,
                       alta_en = alta, prueba_en = alta, transferir = false)
    bloquesT, estadosT = tb[1], tb[2]
    ET = estadosT[end]
    T = bloquesT[end]
    if ET.terminal != -1
        # --- X-03b: madurez residual cruzando el corte -----------------
        prod_ok = haskey(ET.garantias, 1) &&
                  ET.garantias[1].activo >= UInt64(P.q)
        sector_ok = P.sec == SEC0 ||
            (haskey(ET.sectores, 1) && sector_activo(ET.sectores[1], ET, ET.altura_terminal))
        if P.M_res_slots > 1 && sector_ok && prod_ok
            inm = nothing
            for (_, o) in ET.utxo
                if o.origen == OrigenCoinbasePow &&
                   o.creada_en_altura + P.M_cb > ET.altura_terminal
                    inm = o
                    break
                end
            end
            if inm !== nothing
                B3b = gen_post(id = T.id + 1, padre = T.id, slot = 1, productor = 1,
                               peso = 1, sector = (P.sec == SECA ? 1 : 0),
                               txs = [tx_coinbase_post(3),
                                      tx_transferencia([inm.id],
                                        [Salida(500001, inm.valor - UInt64(1), 2, OrigenTx, -1, -1)],
                                        inm.dueño)])
                push!(casos, (nombre = "X-03b", padre = ET, B = B3b,
                              esperado = ErrInmaduro, historial = Bloque[]))
            end
        end
        # --- X-07: PoW hijo del terminal -------------------------------
        B7 = gen_pow(id = T.id + 1, padre = T.id, altura = T.altura + 1,
                     txs = [tx_coinbase([Salida(700001, UInt64(10), 1, OrigenTx, -1, -1)])])
        push!(casos, (nombre = "X-07", padre = ET, B = B7,
                      esperado = ErrPowTrasCorte, historial = Bloques_hist(bloquesT)))
        # --- X-09 / X-10: garantía insuficiente ------------------------
        B9 = gen_post(id = T.id + 1, padre = T.id, slot = 1, productor = 3, peso = 1,
                      sector = (P.sec == SECA ? Sector_de_ET(ET) : 0))
        push!(casos, (nombre = "X-09", padre = ET, B = B9,
                      esperado = ErrGarantia, historial = Bloque[]))
        B10 = gen_post(id = T.id + 1, padre = T.id, slot = 1, productor = 3, peso = 1,
                       req = 0, sector = (P.sec == SECA ? Sector_de_ET(ET) : 0))
        push!(casos, (nombre = "X-10", padre = ET, B = B10,
                      esperado = ErrGarantia, historial = Bloque[]))
        # --- X-12: no es el primero de su rama -------------------------
        B12 = gen_pow(id = T.id + 1, padre = T.id, altura = T.altura + 1,
                      txs = [tx_coinbase([Salida(700002, UInt64(10), 1, OrigenTx, -1, -1)])])
        hist12 = copy(bloquesT)
        push!(hist12, B12)
        Eman = clonar(ET)
        Eman.bloque_raiz = B12.id
        Eman.altura = B12.altura
        Eman.trabajo_acum += B12.trabajo
        B12p = gen_post(id = B12.id + 1, padre = B12.id, slot = 1, productor = 1,
                        peso = 1, sector = (P.sec == SECA ? Sector_de_ET(ET) : 0))
        push!(casos, (nombre = "X-12", padre = Eman, B = B12p,
                      esperado = ErrSinTerminal, historial = hist12))
    end

    # --- X-04: depósito antes de H_dep ---------------------------------
    if P.H_dep > 1
        pref = construir_poW(StableRNG(11), P; hasta = P.H_dep - 2, depositar = false)
        if pref[2][end].terminal == -1
            ED = pref[2][end]
            hD = P.H_dep - 1
            cid = 600000
            B4 = gen_pow(id = pref[3], padre = pref[1][end].id, altura = hD,
                         txs = [tx_coinbase([Salida(cid, UInt64(10), 1, OrigenTx, -1, -1)]),
                                tx_deposito([cid], 1, 10, 1)])
            push!(casos, (nombre = "X-04", padre = ED, B = B4,
                          esperado = ErrDepositoTemprano, historial = pref[1]))
        end
    end

    # --- X-05 / X-06: depósito que consume coinbase inmadura / clave ---
    pref5 = construir_poW(StableRNG(12), P; hasta = P.H_dep - 1, depositar = false)
    if pref5[2][end].terminal == -1
        E5 = pref5[2][end]
        cid5 = 610000
        B5 = gen_pow(id = pref5[3], padre = pref5[1][end].id, altura = P.H_dep,
                     txs = [tx_coinbase([Salida(cid5, UInt64(10), 1, OrigenTx, -1, -1)]),
                            tx_deposito([cid5], 1, 10, 1)])
        push!(casos, (nombre = "X-05", padre = E5, B = B5,
                      esperado = ErrInmaduro, historial = pref5[1]))
        B6 = gen_pow(id = pref5[3], padre = pref5[1][end].id, altura = P.H_dep,
                     txs = [tx_coinbase([Salida(cid5, UInt64(10), 1, OrigenTx, -1, -1)]),
                            tx_deposito([cid5], 2, 10, 1)])
        push!(casos, (nombre = "X-06", padre = E5, B = B6,
                      esperado = ErrAutorizacion, historial = pref5[1]))
    end

    # --- X-08: PoST sin terminal ---------------------------------------
    pref8 = construir_poW(StableRNG(8), P; hasta = P.H_corte_min - 1, depositar = false)
    if pref8[2][end].terminal == -1
        B8 = gen_post(id = pref8[3], padre = pref8[1][end].id, slot = 1,
                      productor = 1, peso = 1)
        push!(casos, (nombre = "X-08", padre = pref8[2][end], B = B8,
                      esperado = ErrSinTerminal, historial = pref8[1]))
    end

    # --- X-11: no-terminal por trabajo, altura o Phi -------------------
    if P.W_min > P.H_corte_min
        p11a = construir_poW(StableRNG(21), P; hasta = P.H_corte_min,
                             depositar = true, alta_en = alta, prueba_en = alta)
        if p11a[2][end].terminal == -1
            B = gen_post(id = p11a[3], padre = p11a[1][end].id, slot = 1,
                         productor = 1, peso = 1)
            push!(casos, (nombre = "X-11a", padre = p11a[2][end], B = B,
                          esperado = ErrSinTerminal, historial = p11a[1]))
        end
    end
    p11b = construir_poW(StableRNG(22), P; hasta = P.H_corte_min - 1,
                         depositar = true, alta_en = alta, prueba_en = alta)
    if p11b[2][end].terminal == -1
        B = gen_post(id = p11b[3], padre = p11b[1][end].id, slot = 1,
                     productor = 1, peso = 1)
        push!(casos, (nombre = "X-11b", padre = p11b[2][end], B = B,
                      esperado = ErrSinTerminal, historial = p11b[1]))
    end
    p11c = construir_poW(StableRNG(23), P; hasta = max(P.H_corte_min, 4),
                         depositar = false)
    if p11c[2][end].terminal == -1
        B = gen_post(id = p11c[3], padre = p11c[1][end].id, slot = 1,
                     productor = 1, peso = 1)
        push!(casos, (nombre = "X-11c", padre = p11c[2][end], B = B,
                      esperado = ErrSinTerminal, historial = p11c[1]))
    end

    # --- X-13 / X-14: operación fuera de fase --------------------------
    B13 = gen_pow(id = gid + 1, padre = gid, altura = 1, txs = [tx_evidencia(1)])
    push!(casos, (nombre = "X-13", padre = Eg, B = B13,
                  esperado = ErrOperacionFase, historial = Bloque[]))
    B14 = gen_pow(id = gid + 1, padre = gid, altura = 1, txs = [tx_liberacion(1, 1, 1)])
    push!(casos, (nombre = "X-14", padre = Eg, B = B14,
                  esperado = ErrOperacionFase, historial = Bloque[]))

    # --- X-15: SEC-A ---------------------------------------------------
    if P.sec == SECA
        ha = max(P.H_dep, 1)
        p15a = construir_poW(StableRNG(31), P; hasta = ha + P.P_sec,
                             depositar = false, alta_en = ha, prueba_en = -1)
        if p15a[2][end].terminal == -1 && p15a[1][end].altura == ha + P.P_sec
            B15a = gen_pow(id = p15a[3], padre = p15a[1][end].id, altura = ha + P.P_sec + 1,
                           txs = [tx_coinbase([Salida(800000, UInt64(10), 1, OrigenTx, -1, -1)]),
                                  tx_prueba_sector(1, 1)])
            push!(casos, (nombre = "X-15a", padre = p15a[2][end], B = B15a,
                          esperado = ErrPruebaTardia, historial = p15a[1]))
        end
        tb2 = construir_poW(StableRNG(32), P; hasta = 10, depositar = true,
                            alta_en = ha, prueba_en = ha, alta2_en = ha)
        E15 = tb2[2][end]
        prod_ok15 = haskey(E15.garantias, 1) &&
                    E15.garantias[1].activo >= UInt64(P.q)
        if E15.terminal != -1 && prod_ok15
            B15b = gen_post(id = tb2[1][end].id + 1, padre = tb2[1][end].id,
                            slot = 1, productor = 1, peso = 1, sector = 2)
            push!(casos, (nombre = "X-15b", padre = E15, B = B15b,
                          esperado = ErrSectorInactivo, historial = tb2[1]))
        end
    end

    return casos
end

# Sector activo de ET (o 0) para escenarios SEC-A.
function Sector_de_ET(ET::Estado)
    for (id, reg) in ET.sectores
        sector_activo(reg, ET, ET.altura_terminal) && return id
    end
    return 0
end

# Copia defensiva de un vector de bloques.
Bloques_hist(bs::Vector{Bloque}) = copy(bs)

# ---------------------------------------------------------------------------
# Historias pequeñas para X-16 … X-20
# ---------------------------------------------------------------------------

# Prefijo común hasta `H_corte_min - 1` con garantía madura en el terminal.
function prefijo_comun(P::Params; seed::Int = 101)
    alta = P.sec == SECA ? max(P.H_dep, 1) : -1
    return construir_poW(StableRNG(seed), P; hasta = max(P.H_corte_min - 1, 1),
                         depositar = true, alta_en = alta, prueba_en = alta,
                         transferir = false)
end

# Añade un bloque PoW hijo con coinbase simple usando `aplicar` sobre `E`.
function hijo_pow(P::Params, E::Estado, id::Int, padre::Int, altura::Int;
                  trabajo::Int = 1, txs::Vector{Tx} = Tx[])
    B = gen_pow(id = id, padre = padre, altura = altura, txs = txs, trabajo = trabajo)
    r = aplicar(E, B, P)
    r isa Err && return nothing, B
    return r, B
end

# Añade hasta `n` bloques PoST de peso `peso` sobre (E, id_padre).
function cadena_post(P::Params, E::Estado, id0::Int, padre0::Int, n::Int;
                     peso::Int = 1, productor::Int = 1, sector::Int = 0,
                     slot0::Int = 0, paso::Int = 1)
    bloques = Bloque[]
    Ecur = E
    padre = padre0
    id = id0
    slot = slot0
    for _ in 1:n
        slot += paso
        B = gen_post(id = id, padre = padre, slot = slot, productor = productor,
                     peso = peso, sector = sector, txs = [tx_coinbase_post(3)])
        r = aplicar(Ecur, B, P)
        r isa Err && break
        Ecur = r
        push!(bloques, B)
        padre = id
        id += 1
    end
    return bloques, Ecur, id
end

# Historia pequeña (≤ 6 bloques) con dos terminales y sufijos PoST de pesos
# distintos (X-17) o una rama PoW tardía con más trabajo (X-18).
function historia_dos_terminales(P::Params; pesos = (2, 1), trabajo_extra = 1)
    pref = prefijo_comun(P; seed = 202)
    bloques0, estados0 = pref[1], pref[2]
    E0 = estados0[end]
    p0 = bloques0[end].id
    h = P.H_corte_min
    deps = Tx[]
    maduras = Salida[]
    for (_, o) in E0.utxo
        if o.origen == OrigenCoinbasePow && h >= o.creada_en_altura + P.M_cb
            push!(maduras, o)
        end
    end
    sort!(maduras, by = x -> x.id)
    for o in maduras
        push!(deps, tx_deposito([o.id], o.dueño, Int(o.valor), o.dueño))
    end
    cid1 = 950000
    cid2 = 950100
    txs1 = vcat([tx_coinbase([Salida(cid1, UInt64(10), 1, OrigenTx, -1, -1)])], deps)
    txs2 = vcat([tx_coinbase([Salida(cid2, UInt64(10), 1, OrigenTx, -1, -1)])], deps)
    B1 = gen_pow(id = pref[3], padre = p0, altura = h, txs = txs1)
    B2 = gen_pow(id = pref[3] + 1, padre = p0, altura = h, trabajo = trabajo_extra,
                 txs = txs2)
    E1, _ = hijo_pow(P, E0, B1.id, p0, h; txs = txs1)
    E2, _ = hijo_pow(P, E0, B2.id, p0, h; txs = txs2, trabajo = trabajo_extra)
    (E1 === nothing || E2 === nothing) && return nothing
    E1.terminal == B1.id || return nothing
    sector = P.sec == SECA ? 1 : 0
    post1, _, _ = cadena_post(P, E1, pref[3] + 100, B1.id, pesos[1];
                              productor = 1, peso = 1, sector = sector)
    post2, _, _ = cadena_post(P, E2, pref[3] + 200, B2.id, pesos[2];
                              productor = 1, peso = 1, sector = sector)
    isempty(post1) && return nothing
    todos = vcat(bloques0, [B1, B2], post1, post2)
    return todos
end

# Rama reorg que elimina el depósito que habilitaba a la clave 1 (X-19).
function historia_reorg(P::Params)
    alta = P.sec == SECA ? max(P.H_dep, 1) : -1
    pref = construir_poW(StableRNG(303), P; hasta = 10, depositar = true,
                         alta_en = alta, prueba_en = alta, transferir = false)
    sin1 = construir_poW(StableRNG(304), P; hasta = 10, depositar = true,
                         alta_en = alta, prueba_en = alta, sin_clave1 = true,
                         claves_extra = [2], transferir = false)
    return pref, sin1
end
