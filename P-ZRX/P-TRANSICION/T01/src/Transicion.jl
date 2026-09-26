# T01 — Oráculo de referencia del contrato P-TRANSICION/CONTRATO-v0.
#
# Implementación clara, sin optimización (ORDEN-T01 §6.5). Tipos concretos, sin
# globales mutables ni `Any` en el núcleo (LINEO §3.1). Valores monetarios
# `UInt64` con aritmética comprobada; `Emitido`/`Quemado` en `Int128` para
# admitir el término negativo de §3.11 (AMBIGUEDAD-1).
module Transicion

using Random
using StableRNGs
using Combinatorics
using SHA
using Printf

export Familia, Genesis, PoW, PoST
export Fase, FaseGenesis, FasePoW, FasePoST
export Origen, OrigenCoinbasePow, OrigenTx, OrigenLiberacion
export SectorModo, SEC0, SECA
export CorteModo, CUT_HWPhi, CUT_H, CUT_W
export SeleccionModo, FC3, FC1, FC2
export Err, TipoTx
export TxCoinbase, TxCoinbasePost, TxTransferencia, TxDeposito, TxRetiro,
       TxLiberacion, TxEvidencia, TxAltaSector, TxPruebaSector
export ErrGenesis, ErrPow, ErrEmision, ErrInmaduro, ErrDepositoTemprano,
       ErrAutorizacion, ErrSaldo, ErrDobleGasto, ErrPowTrasCorte, ErrSinTerminal,
       ErrTerminalAmbiguo, ErrGarantia, ErrOperacionFase, ErrPruebaTardia,
       ErrSectorInactivo, ErrSlot, ErrDesbordamiento, ErrFueraDeAlcanceV0,
       ErrRetiroPendiente
export Salida, Pendiente, EnRetirada, Garantia, RegistroSector, Tx, Bloque, Estado, Params
export tx_coinbase, tx_coinbase_post, tx_transferencia, tx_deposito, tx_retiro,
       tx_liberacion, tx_evidencia, tx_alta_sector, tx_prueba_sector
export subsidio_pow, subsidio_post, estado_inicial, clonar, aplicar, aplicar!,
       aplicar_con_undo, deshacer, es_terminal, phi, sector_activo, gastable,
       gastable_en
export invariante_I1, invariante_I1b, suma_utxo, suma_garantias,
       representacion_canonica, hash_canonico
export seleccionar, seleccionar_con, ResultadoSeleccion, nodo_en_linea,
       construir_validos, puntas_validas
export Params, conseleccion, conWmin
export puntos_rejilla, generar_historia, construir_poW, extender_post,
       genesis_bloque, gen_pow, gen_post, bloque_invalido, escenarios_rechazo,
       prefijo_comun, hijo_pow, cadena_post, historia_dos_terminales,
       historia_reorg
export CasoNegativo, casos_negativos, casos_bloque, puntos_negativos,
       casos_garantia_insuficiente, casos_garantia_pendiente, cadena_base

# ---------------------------------------------------------------------------
# Enumeraciones
# ---------------------------------------------------------------------------

@enum Familia Genesis PoW PoST
@enum Fase FaseGenesis FasePoW FasePoST
@enum Origen OrigenCoinbasePow OrigenTx OrigenLiberacion
@enum SectorModo SEC0 SECA
@enum CorteModo CUT_HWPhi CUT_H CUT_W
@enum SeleccionModo FC3 FC1 FC2

@enum Err begin
    ErrGenesis
    ErrPow
    ErrEmision
    ErrInmaduro
    ErrDepositoTemprano
    ErrAutorizacion
    ErrSaldo
    ErrDobleGasto
    ErrPowTrasCorte
    ErrSinTerminal
    ErrTerminalAmbiguo
    ErrGarantia
    ErrOperacionFase
    ErrPruebaTardia
    ErrSectorInactivo
    ErrSlot
    ErrDesbordamiento
    ErrFueraDeAlcanceV0
    ErrRetiroPendiente      # AMBIGUEDAD-2
end

@enum TipoTx begin
    TxCoinbase
    TxCoinbasePost
    TxTransferencia
    TxDeposito
    TxRetiro
    TxLiberacion
    TxEvidencia
    TxAltaSector
    TxPruebaSector
end

# ---------------------------------------------------------------------------
# Tipos concretos
# ---------------------------------------------------------------------------

struct Salida
    id::Int
    valor::UInt64
    dueño::Int
    origen::Origen
    creada_en_altura::Int   # -1 si no aplica
    creada_en_slot::Int     # -1 si no aplica
end

struct Pendiente
    importe::UInt64
    madura_en_altura::Int   # -1 si no aplica
    madura_en_slot::Int     # -1 si no aplica
end

struct EnRetirada
    importe::UInt64
    inicio_slot::Int
end

mutable struct Garantia
    activo::UInt64
    pendientes::Vector{Pendiente}
    en_retirada::Vector{EnRetirada}
    congelado::UInt64       # siempre 0 en v0
    creditos::Vector{Pendiente}   # D-T08
end

struct RegistroSector
    id::Int
    P::Int
    alta_en::Int
    activa_en::Int
    plazo::Int
    prueba_en::Int          # -1 si no probado
end

struct Tx
    tipo::TipoTx
    salidas::Vector{Salida}
    entradas::Vector{Int}
    firmante::Int
    clave::Int
    importe::UInt64
    sector_id::Int
end

struct Bloque
    id::Int
    familia::Familia
    padre::Int
    altura::Int
    trabajo::Int
    pow_ok::Bool
    slot::Int
    productor::Int
    sector::Int
    peso::Int
    requisito_declarado::Int
    txs::Vector{Tx}
end

mutable struct Estado
    utxo::Dict{Int,Salida}
    garantias::Dict{Int,Garantia}
    emitido::Int128
    quemado::Int128
    fase::Fase
    terminal::Int            # id del terminal de esta rama, -1 si no
    altura::Int              # altura PoW alcanzada
    trabajo_acum::Int
    slot::Int                # último slot PoST
    s0::Int
    sectores::Dict{Int,RegistroSector}
    subsidio_acum::Int128
    prox_salida::Int         # reserva de ids para salidas sin id explícito
    bloque_raiz::Int         # bloque cuyo aplicar produjo este estado
    altura_terminal::Int     # altura del terminal (para madurez residual)
    peso_sufijo::Int         # Σ peso PoST del sufijo
end

struct Params
    H_dep::Int
    M_cb::Int
    M_dep::Int
    H_corte_min::Int
    W_min::Int
    S_min::Int
    K_min::Int
    q::Int
    M_res_slots::Int
    M_dep_slots::Int
    M_rec_slots::Int
    R_slots::Int
    F_slots::Int
    sec::SectorModo
    M_sec::Int
    P_sec::Int
    C_min::Int
    corte::CorteModo
    seleccion::SeleccionModo
end

function Params(; H_dep, M_cb, M_dep, H_corte_min, W_min, S_min, K_min, q,
                M_res_slots, M_dep_slots, M_rec_slots, R_slots, F_slots,
                sec, M_sec = 1, P_sec = 2, C_min = 1,
                corte = CUT_HWPhi, seleccion = FC3)
    Params(H_dep, M_cb, M_dep, H_corte_min, W_min, S_min, K_min, q,
           M_res_slots, M_dep_slots, M_rec_slots, R_slots, F_slots,
           sec, M_sec, P_sec, C_min, corte, seleccion)
end

conseleccion(P::Params, s::SeleccionModo) =
    Params(P.H_dep, P.M_cb, P.M_dep, P.H_corte_min, P.W_min, P.S_min, P.K_min,
           P.q, P.M_res_slots, P.M_dep_slots, P.M_rec_slots, P.R_slots,
           P.F_slots, P.sec, P.M_sec, P.P_sec, P.C_min, P.corte, s)

conWmin(P::Params, w::Int) =
    Params(P.H_dep, P.M_cb, P.M_dep, P.H_corte_min, w, P.S_min, P.K_min,
           P.q, P.M_res_slots, P.M_dep_slots, P.M_rec_slots, P.R_slots,
           P.F_slots, P.sec, P.M_sec, P.P_sec, P.C_min, P.corte, P.seleccion)

# ---------------------------------------------------------------------------
# Constructores cómodos de Tx
# ---------------------------------------------------------------------------

tx_coinbase(salidas::Vector{Salida}) =
    Tx(TxCoinbase, salidas, Int[], 0, 0, UInt64(0), 0)
tx_coinbase_post(importe::Integer) =
    Tx(TxCoinbasePost, Salida[], Int[], 0, 0, UInt64(importe), 0)
tx_transferencia(entradas::Vector{Int}, salidas::Vector{Salida}, firmante::Integer) =
    Tx(TxTransferencia, salidas, entradas, Int(firmante), 0, UInt64(0), 0)
tx_deposito(entradas::Vector{Int}, clave::Integer, importe::Integer, firmante::Integer) =
    Tx(TxDeposito, Salida[], entradas, Int(firmante), Int(clave), UInt64(importe), 0)
tx_retiro(clave::Integer, importe::Integer, firmante::Integer) =
    Tx(TxRetiro, Salida[], Int[], Int(firmante), Int(clave), UInt64(importe), 0)
tx_liberacion(clave::Integer, importe::Integer, firmante::Integer) =
    Tx(TxLiberacion, Salida[], Int[], Int(firmante), Int(clave), UInt64(importe), 0)
tx_evidencia(clave::Integer) =
    Tx(TxEvidencia, Salida[], Int[], 0, Int(clave), UInt64(0), 0)
tx_alta_sector(id::Integer, clave::Integer, firmante::Integer) =
    Tx(TxAltaSector, Salida[], Int[], Int(firmante), Int(clave), UInt64(0), Int(id))
tx_prueba_sector(id::Integer, firmante::Integer) =
    Tx(TxPruebaSector, Salida[], Int[], Int(firmante), 0, UInt64(0), Int(id))

function Bloque(; id, familia, padre = 0, altura = 0, trabajo = 0, pow_ok = true,
                slot = 0, productor = 0, sector = 0, peso = 0,
                requisito_declarado = 0, txs = Tx[])
    Bloque(id, familia, padre, altura, trabajo, pow_ok, slot, productor,
           sector, peso, requisito_declarado, txs)
end

# ---------------------------------------------------------------------------
# Parámetros de prueba y subsidios
# ---------------------------------------------------------------------------

# ORDEN §6.2: funciones de prueba, no propuestas.
subsidio_pow(h::Int, P::Params) = UInt64(10)
subsidio_post(s::Int, P::Params) = UInt64(3)

function estado_inicial(P::Params)
    Estado(Dict{Int,Salida}(), Dict{Int,Garantia}(), Int128(0), Int128(0),
           FaseGenesis, -1, 0, 0, 0, 0, Dict{Int,RegistroSector}(), Int128(0),
           1, 0, -1, 0)
end

function clonar(E::Estado)
    u = copy(E.utxo)
    g = Dict{Int,Garantia}()
    for (k, v) in E.garantias
        g[k] = Garantia(v.activo, copy(v.pendientes), copy(v.en_retirada),
                        v.congelado, copy(v.creditos))
    end
    s = copy(E.sectores)
    Estado(u, g, E.emitido, E.quemado, E.fase, E.terminal, E.altura,
           E.trabajo_acum, E.slot, E.s0, s, E.subsidio_acum, E.prox_salida,
           E.bloque_raiz, E.altura_terminal, E.peso_sufijo)
end

# ---------------------------------------------------------------------------
# Aritmética comprobada (ORDEN §3.5)
# ---------------------------------------------------------------------------

function suma_monetaria(a::UInt64, b::UInt64)
    r, ovf = Base.Checked.add_with_overflow(a, b)
    ovf && return ErrDesbordamiento
    return r
end

function add_activo!(g::Garantia, c::UInt64)
    r, ovf = Base.Checked.add_with_overflow(g.activo, c)
    ovf && return ErrDesbordamiento
    g.activo = r
    return nothing
end

function sub_activo!(g::Garantia, c::UInt64)
    r, ovf = Base.Checked.sub_with_overflow(g.activo, c)
    ovf && return ErrSaldo
    g.activo = r
    return nothing
end

# ---------------------------------------------------------------------------
# Accesores
# ---------------------------------------------------------------------------

function obtener_garantia!(E::Estado, clave::Int)
    g = get(E.garantias, clave, nothing)
    if g === nothing
        g = Garantia(UInt64(0), Pendiente[], EnRetirada[], UInt64(0),
                     Pendiente[])
        E.garantias[clave] = g
    end
    return g
end

punto_actual(E::Estado) = E.fase == FasePoST ? E.slot : E.altura

# Madurez de una salida coinbase_pow (TRN-02 y TRN-02b).
function gastable_en(o::Salida, fase::Fase, altura_terminal::Int, s0::Int,
                     P::Params, punto::Int)
    if o.origen == OrigenCoinbasePow
        if fase == FasePoW
            return punto >= o.creada_en_altura + P.M_cb
        else
            o.creada_en_altura + P.M_cb <= altura_terminal && return true
            return punto >= s0 + P.M_res_slots
        end
    end
    return true
end

function gastable(E::Estado, o::Salida, P::Params, punto::Int)
    return gastable_en(o, E.fase, E.altura_terminal, E.s0, P, punto)
end

# `SEC-A`: un sector está activo si su prueba se aplicó dentro del plazo y ya
# pasó `M_sec`; en PoST solo si ya lo estaba en T (ORDEN §3.8).
function sector_activo(reg::RegistroSector, E::Estado, punto::Int)
    reg.prueba_en == -1 && return false
    reg.prueba_en > reg.plazo && return false
    if E.fase == FasePoST
        return reg.activa_en <= E.altura_terminal
    end
    return punto >= reg.activa_en
end

function phi(E::Estado, P::Params)
    total = Int128(0)
    nq = 0
    for (_, g) in E.garantias
        total += Int128(g.activo)
        g.activo >= UInt64(P.q) && (nq += 1)
    end
    total >= Int128(P.S_min) || return false
    nq >= P.K_min || return false
    if P.sec == SECA
        ns = 0
        punto = punto_actual(E)
        for (_, reg) in E.sectores
            sector_activo(reg, E, punto) && (ns += 1)
        end
        ns >= P.C_min || return false
    end
    return true
end

# ---------------------------------------------------------------------------
# Promoción de pendientes (paso (b) de ORDEN §3.9)
# ---------------------------------------------------------------------------

function promover!(E::Estado, punto::Int, es_post::Bool)
    for (_, g) in E.garantias
        if es_post
            quedan = Pendiente[]
            for p in g.pendientes
                if p.madura_en_slot != -1 && p.madura_en_slot <= punto
                    r = add_activo!(g, p.importe)
                    r isa Err && return r
                else
                    push!(quedan, p)
                end
            end
            g.pendientes = quedan
            quedanc = Pendiente[]
            for p in g.creditos
                if p.madura_en_slot != -1 && p.madura_en_slot <= punto
                    r = add_activo!(g, p.importe)
                    r isa Err && return r
                else
                    push!(quedanc, p)
                end
            end
            g.creditos = quedanc
        else
            quedan = Pendiente[]
            for p in g.pendientes
                if p.madura_en_altura != -1 && p.madura_en_altura <= punto
                    r = add_activo!(g, p.importe)
                    r isa Err && return r
                else
                    push!(quedan, p)
                end
            end
            g.pendientes = quedan
        end
    end
    return nothing
end

# ---------------------------------------------------------------------------
# UTXO
# ---------------------------------------------------------------------------

function crear_utxos!(E::Estado, salidas::Vector{Salida}, origen::Origen,
                      altura::Int, slot::Int)
    vistos = Set{Int}()
    for s in salidas
        (s.id in vistos) && return ErrDobleGasto
        push!(vistos, s.id)
        haskey(E.utxo, s.id) && return ErrDobleGasto
    end
    for s in salidas
        E.utxo[s.id] = Salida(s.id, s.valor, s.dueño, origen, altura, slot)
        s.id >= E.prox_salida && (E.prox_salida = s.id + 1)
    end
    return nothing
end

# Consume entradas autorizadas y devuelve (resultado, total).
function consumir_entradas!(E::Estado, entradas::Vector{Int}, firmante::Int,
                            P::Params, punto::Int)
    vistos = Set{Int}()
    for id in entradas
        (id in vistos) && return (ErrDobleGasto, UInt64(0))
        push!(vistos, id)
    end
    total = UInt64(0)
    for id in entradas
        o = get(E.utxo, id, nothing)
        o === nothing && return (ErrDobleGasto, UInt64(0))
        o.dueño == firmante || return (ErrAutorizacion, UInt64(0))
        gastable(E, o, P, punto) || return (ErrInmaduro, UInt64(0))
        r = suma_monetaria(total, o.valor)
        r isa Err && return (r, UInt64(0))
        total = r
    end
    for id in entradas
        delete!(E.utxo, id)
    end
    return (nothing, total)
end

# ---------------------------------------------------------------------------
# Aplicación de transacciones
# ---------------------------------------------------------------------------

function aplicar_transferencia!(E::Estado, P::Params, punto::Int, tx::Tx)
    r, _ = consumir_entradas!(E, tx.entradas, tx.firmante, P, punto)
    r isa Err && return r
    return crear_utxos!(E, tx.salidas, OrigenTx,
                        E.fase == FasePoW ? punto : -1,
                        E.fase == FasePoST ? punto : -1)
end

function aplicar_deposito!(E::Estado, B::Bloque, P::Params, punto::Int, tx::Tx)
    # RATIFICACION-v0.1-R8: importe 0 en un depósito ⇒ ErrSaldo.
    tx.importe == 0 && return ErrSaldo
    tx.firmante == tx.clave || return ErrAutorizacion
    if E.fase == FasePoW
        B.altura >= P.H_dep || return ErrDepositoTemprano
    end
    r, total = consumir_entradas!(E, tx.entradas, tx.firmante, P, punto)
    r isa Err && return r
    total == tx.importe || return ErrSaldo
    g = obtener_garantia!(E, tx.clave)
    if E.fase == FasePoW
        ma = B.altura + P.M_dep
        ms = E.s0 + P.M_dep_slots
        if ma <= B.altura                      # AMBIGUEDAD-4 (M_dep = 0)
            return add_activo!(g, tx.importe)
        end
        push!(g.pendientes, Pendiente(tx.importe, ma, ms))
        return nothing
    else
        ms = B.slot + P.M_dep_slots
        if ms <= B.slot                        # AMBIGUEDAD-4
            return add_activo!(g, tx.importe)
        end
        push!(g.pendientes, Pendiente(tx.importe, -1, ms))
        return nothing
    end
end

function aplicar_retiro!(E::Estado, B::Bloque, P::Params, punto::Int, tx::Tx)
    # RATIFICACION-v0.1-R8: importe 0 en un retiro ⇒ ErrSaldo.
    tx.importe == 0 && return ErrSaldo
    tx.firmante == tx.clave || return ErrAutorizacion
    g = obtener_garantia!(E, tx.clave)
    tx.importe <= g.activo || return ErrSaldo
    isempty(g.en_retirada) || return ErrRetiroPendiente   # AMBIGUEDAD-2
    r = sub_activo!(g, tx.importe)
    r isa Err && return r
    inicio = E.fase == FasePoW ? E.s0 : B.slot
    push!(g.en_retirada, EnRetirada(tx.importe, inicio))
    return nothing
end

function aplicar_liberacion!(E::Estado, B::Bloque, P::Params, punto::Int, tx::Tx)
    E.fase == FasePoST || return ErrOperacionFase
    # RATIFICACION-v0.1-R8: importe 0 en una liberación ⇒ ErrSaldo.
    tx.importe == 0 && return ErrSaldo
    tx.firmante == tx.clave || return ErrAutorizacion
    g = obtener_garantia!(E, tx.clave)
    vencido = Int128(0)
    for r in g.en_retirada
        r.inicio_slot + P.R_slots <= B.slot && (vencido += Int128(r.importe))
    end
    Int128(tx.importe) <= vencido || return ErrSaldo
    restante = tx.importe
    nuevas = EnRetirada[]
    for r in g.en_retirada
        if restante > 0 && r.inicio_slot + P.R_slots <= B.slot
            if r.importe <= restante
                restante -= r.importe
            else
                push!(nuevas, EnRetirada(r.importe - restante, r.inicio_slot))
                restante = UInt64(0)
            end
        else
            push!(nuevas, r)
        end
    end
    g.en_retirada = nuevas
    id = E.prox_salida
    E.prox_salida += 1
    return crear_utxos!(E, [Salida(id, tx.importe, tx.clave, OrigenLiberacion,
                                   -1, B.slot)], OrigenLiberacion, -1, B.slot)
end

function aplicar_alta_sector!(E::Estado, B::Bloque, P::Params, tx::Tx)
    E.fase == FasePoW || return ErrFueraDeAlcanceV0      # AMBIGUEDAD-9
    P.sec == SECA || return ErrFueraDeAlcanceV0          # AMBIGUEDAD-8
    B.altura >= P.H_dep || return ErrDepositoTemprano    # AMBIGUEDAD-9
    tx.firmante == tx.clave || return ErrAutorizacion
    haskey(E.sectores, tx.sector_id) && return ErrDobleGasto
    E.sectores[tx.sector_id] = RegistroSector(tx.sector_id, tx.clave, B.altura,
                                              B.altura + P.M_sec,
                                              B.altura + P.P_sec, -1)
    return nothing
end

function aplicar_prueba_sector!(E::Estado, B::Bloque, P::Params, tx::Tx)
    E.fase == FasePoW || return ErrFueraDeAlcanceV0      # AMBIGUEDAD-9
    P.sec == SECA || return ErrFueraDeAlcanceV0          # AMBIGUEDAD-8
    reg = get(E.sectores, tx.sector_id, nothing)
    reg === nothing && return ErrSectorInactivo
    reg.P == tx.firmante || return ErrAutorizacion
    reg.prueba_en != -1 && return ErrDobleGasto
    B.altura > reg.plazo && return ErrPruebaTardia
    E.sectores[tx.sector_id] = RegistroSector(reg.id, reg.P, reg.alta_en,
                                              reg.activa_en, reg.plazo, B.altura)
    return nothing
end

function credito_post!(E::Estado, B::Bloque, P::Params, importe::UInt64)
    g = obtener_garantia!(E, B.productor)
    madura = B.slot + P.M_rec_slots
    if madura <= B.slot
        return add_activo!(g, importe)
    end
    push!(g.creditos, Pendiente(importe, -1, madura))
    return nothing
end

function aplicar_tx!(E::Estado, B::Bloque, P::Params, punto::Int, tx::Tx)
    t = tx.tipo
    if t == TxCoinbase
        E.fase == FasePoW || return ErrOperacionFase
        isempty(tx.salidas) && return ErrEmision   # RATIFICACION-v0.1-R7
        return crear_utxos!(E, tx.salidas, OrigenCoinbasePow, B.altura, -1)
    elseif t == TxCoinbasePost
        E.fase == FasePoST || return ErrOperacionFase
        tx.importe == 0 && return ErrSaldo         # RATIFICACION-v0.1-R8
        return credito_post!(E, B, P, tx.importe)
    elseif t == TxTransferencia
        return aplicar_transferencia!(E, P, punto, tx)
    elseif t == TxDeposito
        return aplicar_deposito!(E, B, P, punto, tx)
    elseif t == TxRetiro
        return aplicar_retiro!(E, B, P, punto, tx)
    elseif t == TxLiberacion
        return aplicar_liberacion!(E, B, P, punto, tx)
    elseif t == TxEvidencia
        E.fase == FasePoW && return ErrOperacionFase    # X-13
        return ErrFueraDeAlcanceV0                      # AMBIGUEDAD-10
    elseif t == TxAltaSector
        return aplicar_alta_sector!(E, B, P, tx)
    else
        return aplicar_prueba_sector!(E, B, P, tx)
    end
end

# Aplica todas las transacciones (R-6: la coinbase debe ser la primera) y
# actualiza Emitido/I-1b. Devuelve `nothing` o `Err`.
function aplicar_txs!(E::Estado, B::Bloque, P::Params, punto::Int)
    txs = B.txs
    ncb = 0
    idx_cb = 0
    for (i, t) in enumerate(txs)
        if t.tipo == TxCoinbase || t.tipo == TxCoinbasePost
            ncb += 1
            idx_cb = i
        end
    end
    ncb > 1 && return ErrEmision
    # RATIFICACION-v0.1-R6: la coinbase (única) debe ocupar la primera posición.
    ncb == 1 && idx_cb != 1 && return ErrEmision
    orden = txs
    tarifas = Int128(0)
    coinbase_pagada = UInt64(0)
    for tx in orden
        if tx.tipo == TxTransferencia
            # RATIFICACION-v0.1-R9: sin entradas es una coinbase fuera de lugar;
            # con entradas y sin salidas, ErrSaldo.
            isempty(tx.entradas) && return ErrEmision
            isempty(tx.salidas) && return ErrSaldo
            ve = Int128(0)
            for id in tx.entradas
                o = get(E.utxo, id, nothing)
                o === nothing && return ErrDobleGasto
                ve += Int128(o.valor)
            end
            vs = Int128(0)
            for s in tx.salidas
                vs += Int128(s.valor)
            end
            vs <= ve || return ErrSaldo          # AMBIGUEDAD-3
            tarifas += ve - vs
            r = aplicar_transferencia!(E, P, punto, tx)
            r isa Err && return r
        else
            r = aplicar_tx!(E, B, P, punto, tx)
            r isa Err && return r
            if tx.tipo == TxCoinbase
                for s in tx.salidas
                    rr = suma_monetaria(coinbase_pagada, s.valor)
                    rr isa Err && return rr
                    coinbase_pagada = rr
                end
            elseif tx.tipo == TxCoinbasePost
                coinbase_pagada = tx.importe
            end
        end
    end
    subsidio = B.familia == PoW ? subsidio_pow(B.altura, P) :
                                 subsidio_post(B.slot, P)
    Int128(coinbase_pagada) <= Int128(subsidio) + tarifas || return ErrEmision
    E.emitido += Int128(coinbase_pagada) - tarifas
    E.subsidio_acum += Int128(subsidio)
    return nothing
end

# ---------------------------------------------------------------------------
# (a) forma y familia · (b) promoción · (c) garantía · (d) txs · (e) terminal
# ---------------------------------------------------------------------------

function aplicar_genesis!(E::Estado, B::Bloque, P::Params)
    E.fase == FaseGenesis || return ErrGenesis
    (B.padre == 0 && B.altura == 0) || return ErrGenesis
    if !isempty(B.txs)
        (length(B.txs) == 1 && B.txs[1].tipo == TxCoinbase) || return ErrGenesis
        # RATIFICACION-v0.1-R7: la coinbase PoW exige al menos una salida
        # (el génesis, una de valor 0). Sin salidas ⇒ ErrEmision.
        isempty(B.txs[1].salidas) && return ErrEmision
        for o in B.txs[1].salidas
            o.valor == 0 || return ErrGenesis
        end
    end
    E.fase = FasePoW
    E.terminal = -1
    E.altura = 0
    E.trabajo_acum = 0
    E.slot = 0
    E.s0 = 0
    E.bloque_raiz = B.id
    E.altura_terminal = -1
    return nothing
end

function es_terminal_condiciones(E::Estado, B::Bloque, P::Params)
    cond_h = B.altura >= P.H_corte_min
    cond_w = E.trabajo_acum >= P.W_min
    cond_p = phi(E, P)
    P.corte == CUT_HWPhi && return cond_h && cond_w && cond_p
    P.corte == CUT_H && return cond_h
    return cond_w
end

function aplicar_pow!(E::Estado, B::Bloque, P::Params)
    E.fase == FasePoW || return (E.fase == FasePoST ? ErrPowTrasCorte : ErrGenesis)
    E.terminal == -1 || return ErrPowTrasCorte
    B.pow_ok || return ErrPow
    B.trabajo >= 1 || return ErrPow
    B.altura == E.altura + 1 || return ErrSlot
    r = promover!(E, B.altura, false)
    r isa Err && return r
    r = aplicar_txs!(E, B, P, B.altura)
    r isa Err && return r
    E.trabajo_acum += B.trabajo
    E.altura = B.altura
    E.bloque_raiz = B.id
    if es_terminal_condiciones(E, B, P)
        E.terminal = B.id
        E.altura_terminal = B.altura
    end
    return nothing
end

function aplicar_post!(E::Estado, B::Bloque, P::Params)
    if E.fase == FasePoW
        E.terminal != -1 || return ErrSinTerminal
        B.padre == E.terminal || return ErrSinTerminal
        B.slot >= 1 || return ErrSlot
        E.fase = FasePoST
        E.s0 = 0
    elseif E.fase == FasePoST
        B.slot > E.slot || return ErrSlot
    else
        return ErrGenesis
    end
    B.peso >= 1 || return ErrSlot
    r = promover!(E, B.slot, true)
    r isa Err && return r
    g = get(E.garantias, B.productor, nothing)
    activo = g === nothing ? UInt64(0) : g.activo
    activo >= UInt64(P.q) || return ErrGarantia
    if P.sec == SECA
        reg = get(E.sectores, B.sector, nothing)
        reg === nothing && return ErrAutorizacion
        reg.P == B.productor || return ErrAutorizacion
        sector_activo(reg, E, B.slot) || return ErrSectorInactivo
    end
    r = aplicar_txs!(E, B, P, B.slot)
    r isa Err && return r
    E.slot = B.slot
    E.peso_sufijo += B.peso
    E.bloque_raiz = B.id
    return nothing
end

function aplicar!(E::Estado, B::Bloque, P::Params)
    if B.familia == Genesis
        return aplicar_genesis!(E, B, P)
    end
    E.fase == FaseGenesis && return ErrGenesis
    if B.familia == PoW
        return aplicar_pow!(E, B, P)
    end
    return aplicar_post!(E, B, P)
end

# `aplicar` funcional: no muta E; devuelve el estado nuevo o `Err`.
function aplicar(E::Estado, B::Bloque, P::Params)
    E2 = clonar(E)
    r = aplicar!(E2, B, P)
    r isa Err && return r
    return E2
end

# Undo exacto por copia íntegra (AMBIGUEDAD-12).
function aplicar_con_undo(E::Estado, B::Bloque, P::Params)
    E2 = clonar(E)
    r = aplicar!(E2, B, P)
    r isa Err && return r
    return (E2, E)
end

deshacer(::Estado, undo::Estado) = undo

# ---------------------------------------------------------------------------
# `es_terminal` sobre una historia (cadena) según TRN-04
# ---------------------------------------------------------------------------

function es_terminal(hist::Vector{Bloque}, P::Params)
    isempty(hist) && return false
    E = estado_inicial(P)
    terminal_encontrado = -1
    for B in hist
        E2 = clonar(E)
        if B.familia == Genesis
            r = aplicar_genesis!(E2, B, P)
            r isa Err && return false
        elseif B.familia == PoW
            (E2.fase == FasePoW && E2.terminal == -1) || return false
            B.pow_ok || return false
            B.trabajo >= 1 || return false
            B.altura == E2.altura + 1 || return false
            r = promover!(E2, B.altura, false)
            r isa Err && return false
            r = aplicar_txs!(E2, B, P, B.altura)
            r isa Err && return false
            E2.trabajo_acum += B.trabajo
            E2.altura = B.altura
            if terminal_encontrado == -1 && es_terminal_condiciones(E2, B, P)
                terminal_encontrado = B.id
            end
        else
            # La historia se analiza solo para decidir terminalidad PoW.
            return false
        end
        E = E2
    end
    return terminal_encontrado == hist[end].id
end

# ---------------------------------------------------------------------------
# Invariantes de contabilidad
# ---------------------------------------------------------------------------

function suma_utxo(E::Estado)
    s = Int128(0)
    for (_, o) in E.utxo
        s += Int128(o.valor)
    end
    return s
end

function suma_garantias(E::Estado)
    s = Int128(0)
    for (_, g) in E.garantias
        s += Int128(g.activo) + Int128(g.congelado)
        for p in g.pendientes
            s += Int128(p.importe)
        end
        for p in g.creditos
            s += Int128(p.importe)
        end
        for r in g.en_retirada
            s += Int128(r.importe)
        end
    end
    return s
end

invariante_I1(E::Estado) = suma_utxo(E) + suma_garantias(E) == E.emitido - E.quemado
invariante_I1b(E::Estado) = E.emitido <= E.subsidio_acum

# ---------------------------------------------------------------------------
# Representación canónica (I-3, X-16, X-20)
# ---------------------------------------------------------------------------

function representacion_canonica(E::Estado)
    io = IOBuffer()
    print(io, "E|", E.emitido, "|", E.quemado, "|", E.fase, "|", E.terminal,
          "|", E.altura, "|", E.trabajo_acum, "|", E.slot, "|", E.s0, "|",
          E.subsidio_acum, "|", E.prox_salida, "|", E.altura_terminal, "|",
          E.peso_sufijo, "|")
    for id in sort(collect(keys(E.utxo)))
        o = E.utxo[id]
        print(io, "U:", o.id, ",", o.valor, ",", o.dueño, ",", o.origen, ",",
              o.creada_en_altura, ",", o.creada_en_slot, ";")
    end
    for k in sort(collect(keys(E.garantias)))
        g = E.garantias[k]
        print(io, "G:", k, ",", g.activo, ",", g.congelado, ";")
        for p in sort(g.pendientes, by = x -> (x.madura_en_altura,
                                               x.madura_en_slot, x.importe))
            print(io, "P:", p.importe, ",", p.madura_en_altura, ",",
                  p.madura_en_slot, ";")
        end
        for p in sort(g.creditos, by = x -> (x.madura_en_slot, x.importe))
            print(io, "C:", p.importe, ",", p.madura_en_slot, ";")
        end
        for r in sort(g.en_retirada, by = x -> (x.inicio_slot, x.importe))
            print(io, "R:", r.importe, ",", r.inicio_slot, ";")
        end
    end
    for id in sort(collect(keys(E.sectores)))
        s = E.sectores[id]
        print(io, "S:", s.id, ",", s.P, ",", s.alta_en, ",", s.activa_en, ",",
              s.plazo, ",", s.prueba_en, ";")
    end
    return String(take!(io))
end

hash_canonico(E::Estado) = bytes2hex(sha256(representacion_canonica(E)))

include("seleccion.jl")
include("nodo.jl")
include("generadores.jl")
include("generadores_negativos.jl")   # T01-C: casos negativos de transacción

end # module
