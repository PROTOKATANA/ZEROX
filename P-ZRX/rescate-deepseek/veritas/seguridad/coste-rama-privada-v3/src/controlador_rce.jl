# controlador_rce.jl — perfil candidato RCE-v0.1 revisión 2 (+ enmienda Z0) como
# INSTRUMENTO. No es consenso activado. Reproduce el núcleo entero del contrato
# `veritas/consenso/retarget-causal-endogeno-v1/CONTRATO.md`.
#
# Advertencia declarada (encargo D5): la asociación DAG→cohorte/`counted` y el
# contexto de cierre real no se derivan aquí; se suministran como fixture/oráculo.
# El controlador del SPEC (C-HDR-06) queda `Pendiente`: su primer dato ausente es la
# ventana del controlador (TAREAS §2.3).

@enum Redondeo REDONDEO_FLOOR REDONDEO_NEAREST_EVEN

struct ConfigRCE
    W::Int
    G::Int
    activation_delay_windows::Int
    Q::BigInt
    R_inicial::BigInt
    R_min::BigInt
    R_max::BigInt
    a::BigInt
    d::BigInt
    p_lo::BigInt
    q_lo::BigInt
    p_hi::BigInt
    q_hi::BigInt
    redondeo::Redondeo
end

function ConfigRCE(; W, G, activation_delay_windows, Q, R_inicial, R_min, R_max,
                   ganancia_a=1, ganancia_d=1, p_lo=1, q_lo=2, p_hi=2, q_hi=1,
                   redondeo=REDONDEO_FLOOR)
    a, dd = BigInt(ganancia_a), BigInt(ganancia_d)
    0 < a <= dd || throw(ArgumentError("se exige 0 < a <= d"))
    p_lo <= q_lo || throw(ArgumentError("p_lo<=q_lo"))
    p_hi >= q_hi || throw(ArgumentError("p_hi>=q_hi"))
    R_min <= R_inicial <= R_max || throw(ArgumentError("0<R_min<=R_inicial<=R_max"))
    W > 0 || throw(ArgumentError("W>0"))
    return ConfigRCE(Int(W), Int(G), Int(activation_delay_windows), BigInt(Q),
                     BigInt(R_inicial), BigInt(R_min), BigInt(R_max),
                     a, dd, BigInt(p_lo), BigInt(q_lo), BigInt(p_hi), BigInt(q_hi),
                     redondeo)
end

"Redondeo entero a cociente par (NearestEven) o suelo (Floor)."
function _redondea(num::BigInt, den::BigInt, modo::Redondeo)
    den > 0 || throw(ArgumentError("den>0"))
    if modo == REDONDEO_FLOOR
        return fld(num, den)
    end
    q, r = divrem(num, den)          # truncado hacia cero
    dosr = 2 * abs(r)
    if dosr > den
        return q + (num >= 0 ? 1 : -1)
    elseif dosr < den
        return q
    else
        return iseven(q) ? q : q + (num >= 0 ? 1 : -1)
    end
end

"Un paso del controlador RCE-v0.1 rev2: `(estado, R_next, activacion)`."
function paso_causal(R_j::BigInt, N_j::Integer, cfg::ConfigRCE)
    N = BigInt(N_j)
    if N == 0
        # Enmienda Z0: no se agenda propuesta alguna; activación 0.
        return (estado=:HeldZero, R_next=R_j, activacion=0)
    end
    num = R_j * ((cfg.d - cfg.a) * N + cfg.a * cfg.Q)
    den = cfg.d * N
    R_raw = _redondea(num, den, cfg.redondeo)
    # clamps de paso racionales: [floor(R*p_lo/q_lo), ceil(R*p_hi/q_hi)]
    paso_lo = fld(R_j * cfg.p_lo, cfg.q_lo)
    paso_hi = -fld(-(R_j * cfg.p_hi), cfg.q_hi)   # ceil
    R_step = clamp(R_raw, paso_lo, paso_hi)
    R_next = clamp(R_step, cfg.R_min, cfg.R_max)
    return (estado=:Scheduled, R_next=R_next, activacion=0)
end

"""
Controlador con agenda de propuestas `(activation_slot, R)`. La asociación DAG→cohorte
es externa (oráculo). `cerrar_cohorte!` sella una cohorte con `N_j` y agenda la
activación nominal; `avanzar!`/`rango_en` aplican las propuestas con activación ≤ slot.
"""
mutable struct ControladorRCE
    cfg::ConfigRCE
    R_activo::BigInt
    propuestas::Vector{Tuple{Int,BigInt}}
    colisiones::Vector{String}
end

ControladorRCE(cfg::ConfigRCE) = ControladorRCE(cfg, cfg.R_inicial, Tuple{Int,BigInt}[], String[])

"Corte de la cohorte j: c_j = (j+1)·W + G."
corte_cohorte(cfg::ConfigRCE, j::Integer) = (Int(j) + 1) * cfg.W + cfg.G

"Frontera estrictamente posterior al corte: b_j = (floor(c_j/W)+1)·W."
function frontera_b(cfg::ConfigRCE, j::Integer)
    c = corte_cohorte(cfg, j)
    return (fld(c, cfg.W) + 1) * cfg.W
end

"""
Cierra la cohorte `j` con `N_j` adjudicaciones contadas en `seal_slot`. Aplica primero
las propuestas ya vencidas. Si `N_j==0` (o Pending) no agenda nada (Z0). `propuesta`
sólo si `seal_slot < A_j`; en otro caso registra `MissedUpdate`.
"""
function cerrar_cohorte!(ctrl::ControladorRCE, j::Integer, N_j::Integer, seal_slot::Integer;
                         pending::Bool=false)
    cfg = ctrl.cfg
    avanzar!(ctrl, seal_slot)
    corte = corte_cohorte(cfg, j)
    seal_slot >= corte || throw(ArgumentError("seal_slot < corte de la cohorte"))
    if pending
        return (estado=:Pending, R_next=ctrl.R_activo, activacion=0)
    end
    b = frontera_b(cfg, j)
    A = b + (cfg.activation_delay_windows - 1) * cfg.W
    res = paso_causal(ctrl.R_activo, N_j, cfg)
    if res.estado == :HeldZero
        return (estado=:HeldZero, R_next=ctrl.R_activo, activacion=0)
    end
    if seal_slot < A
        push!(ctrl.propuestas, (A, res.R_next))
        return (estado=:Scheduled, R_next=res.R_next, activacion=A)
    else
        return (estado=:MissedUpdate, R_next=ctrl.R_activo, activacion=A)
    end
end

"Activa las propuestas con `activation_slot ≤ slot`. Rechaza colisiones de activación."
function avanzar!(ctrl::ControladorRCE, slot::Integer)
    vencidas = [p for p in ctrl.propuestas if p[1] <= slot]
    isempty(vencidas) && return ctrl
    sort!(vencidas; by=first)
    for (i, p) in enumerate(vencidas)
        i > 1 && vencidas[i][1] == vencidas[i-1][1] &&
            push!(ctrl.colisiones, "activación $(p[1]) repetida")
    end
    for (_, R) in vencidas
        ctrl.R_activo = R
    end
    ctrl.propuestas = [p for p in ctrl.propuestas if p[1] > slot]
    return ctrl
end

"Rango activo en `slot` (no muta el estado aplicado)."
function rango_en(ctrl::ControladorRCE, slot::Integer)
    R = ctrl.R_activo
    for (A, Rw) in sort([p for p in ctrl.propuestas if p[1] <= slot]; by=first)
        R = Rw
    end
    return R
end
