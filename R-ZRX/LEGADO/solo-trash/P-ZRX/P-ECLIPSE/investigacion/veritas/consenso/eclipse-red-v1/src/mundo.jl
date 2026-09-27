#= mundo.jl — el mundo heredado de la ronda 11b, portado a Julia sobre GDR-v0.2.

QUÉ ES ESTO
===========
Un **puerto**, no una reimplementación libre. La fuente es, verificado leyendo su código:

  · `research/scripts/d9-ronda8c/r8c_sim.py`  — calendario de eventos y `_padres`
  · `research/scripts/d8-ronda8/d8_a3_smax.py` — `MundoEclipse.corre_ecl` (el control de D8 A3b)
  · `research/scripts/d8-ronda11b/r11b_lib.py` — `MundoVictima.corre_victima` (las tres variantes)

y la pieza GHOSTDAG **no se porta**: la aporta `GDR-v0.2` (ver `GDR.jl`).

FIDELIDAD AL ORÁCULO, PUNTO POR PUNTO
=====================================
1. **Calendario.** Poisson de tasa `λ`, y por cada evento: `random() < α` decide autor,
   `randrange(10^9)` el `sd`, `randrange(10^12)` la semilla de inyección. El orden de consumo
   del RNG es el de Python y se respeta; el RNG es la réplica exacta de CPython (`pyrng.jl`).
2. **Retardo.** Un bloque honesto creado en `t` lo ven los honestos en `t + Δ`. El atacante
   **ve todo al instante** (`atacante_sin_retardo = True`, el modelo del artículo).
3. **Política de padres** (`pick_virtual_parents`): candidatos = puntas **visibles**, ordenadas
   por `(−blue_work, id)` —¡no por `sd`!—; `sp :=` la primera; se añaden más mientras el
   mergeset no pase de `msl` ni los padres de `mp`. `sp` se usa sólo para **medir** el mergeset;
   el `sp` de consenso lo recalcula `anadir!` con el desempate `(bw, −sd, id)`.
   Esa asimetría está en `r8c_sim.py:52-64` y **se reproduce tal cual**: es una rareza del
   instrumento heredado, no una decisión de diseño, y el control positivo la necesita.
4. **Peso.** El histórico era `blue_work = nº de azules`. Con `SR = 0` en todo bloque,
   `w = 2^128` y `bw = 2^128·|blues|`, que ordena igual. Ver `GDR.jl`.
5. **`S_max`.** `r8c_gd.add` **no** rechaza por `slot(B) − slot(sp(B)) > S_max`: R-FIN-1a se
   aplica como **medida** posterior, no como filtro. Por eso aquí se pasa
   `s_max = typemax(UInt64)`: dejar el 150 por defecto de GDR **cambiaría el DAG** y el control
   dejaría de reproducirse. Se declara porque es justo el tipo de detalle que un puerto
   descuidado rompe en silencio.
6. **Visibilidad frente a existencia.** `r8c_sim` mantiene `llega` (instante de llegada) y
   construye la vista con `ta <= t`. Un bloque **existe** en el DAG desde su creación pero puede
   **no ser visible** todavía. Las puntas se calculan sobre la vista, no sobre el estado, así que
   **no se usa `tips(est)` de GDR**: se calculan sobre el subconjunto visible. Usar `tips(est)`
   habría sido un error silencioso.
=#

module Mundo

using ..PyRNG
using ..GDR
const G = GDR.GhostdagRank

export ParametrosMundo, Evento, Sim, calendario, corre_control!, corre_victima!,
       py_str, ResultadoControl, ResultadoVictima, U3, SP, MERGE

const DELTA_NOMINAL = 4.0      # Δ del instrumento heredado (`r8c_sim.py:24`)
const SIGMA = 1.0              # duración de slot, s (`DECISIONES.md` §19; C-SLOT-01)
const S_MAX_KATANA = 150       # R-FIN-1a, la elección de Katana (auditoría 7 §4)

"""
Régimen de peso. `:conteo` = el histórico (`SR = 0`, blue_work monótono en el conteo de azules);
`:sr` = `C-GD-01` vigente, con `SR` = `solution_distance` del bloque.
"""
const REGIMENES = (:conteo, :sr)

"""Génesis. Debe ser el único id que no empieza por letra minúscula, como en el oráculo ("G")."""
const ID_GENESIS = "G"

struct ParametrosMundo
    alpha::Float64
    T::Float64
    semilla::Int
    k::UInt32
    mp::UInt32
    msl::UInt32
    lam::Float64
    delta::Float64
    regimen::Symbol
    s_max::UInt64
end

function ParametrosMundo(alpha::Real, T::Real, semilla::Integer;
                         k::Integer = 30, mp::Integer = 15, msl::Integer = 180,
                         lam::Real = 1.0, delta::Real = DELTA_NOMINAL,
                         regimen::Symbol = :conteo, s_max::Integer = typemax(UInt64))
    regimen in REGIMENES || error("régimen desconocido: $regimen (usa :conteo o :sr)")
    return ParametrosMundo(Float64(alpha), Float64(T), Int(semilla), UInt32(k), UInt32(mp),
                           UInt32(msl), Float64(lam), Float64(delta), regimen, UInt64(s_max))
end

struct Evento
    t::Float64
    atacante::Bool
    sd::UInt64
    sde::UInt64
end

"""
`repr` de Python para los flotantes que este encargo usa, y **sólo** para ellos.
Python escribe `900.0`, `0.0`, `0.05`, `0.1`, `0.25`, `0.33`; `string` de Julia coincide en todos.
Divergen en la notación científica (`1e-05` frente a `1.0e-5`), así que si algún día se usa un
valor así, esta función **debe** ampliarse. Se comprueba en los tests.
"""
function py_str(x::Float64)
    isfinite(x) || error("py_str no admite no finitos")
    if x == floor(x) && abs(x) < 1.0e16
        return string(Int64(x)) * ".0"
    end
    s = string(x)
    occursin('e', s) && error("py_str no reproduce la notación científica de Python para $x")
    return s
end

# ---------------------------------------------------------------------------------------
# Calendario
# ---------------------------------------------------------------------------------------

"""Calendario de eventos, idéntico a `r8c_sim.Mundo.__init__`. `semilla` entera."""
function calendario(alpha::Real, T::Real, semilla::Integer; lam::Real = 1.0)
    rng = PyRandom(semilla)
    ev = Evento[]
    t = 0.0
    while true
        t += expovariate(rng, Float64(lam))
        t > T && break
        atac = random(rng) < Float64(alpha)
        sd = UInt64(randrange(rng, 10^9))
        sde = UInt64(randrange(rng, 10^12))
        push!(ev, Evento(t, atac, sd, sde))
    end
    return ev
end

# ---------------------------------------------------------------------------------------
# Estado de una simulación
# ---------------------------------------------------------------------------------------

mutable struct Sim
    params::G.Params
    p::ParametrosMundo
    est::G.EstadoRapido
    tcrea::Vector{Float64}       # instante de creación por índice de bloque
    llegadaA::Vector{Float64}    # llegada a la vista "red honesta"
    llegadaC::Vector{Float64}    # llegada a la vista de la víctima / de C
    autor::Vector{UInt8}         # 0 génesis, 1 honesto, 2 víctima, 3 atacante
    visible::Vector{UInt8}
    marca::Vector{Int}
    token::Int
    scratch::BitSet
    ev::Vector{Evento}
    usa_sr::Bool                # false = régimen :conteo (SR := 0), true = C-GD-01 (SR := sd)
end

function Sim(p::ParametrosMundo, ev::Vector{Evento})
    params = G.Params(; k = p.k, max_parents = p.mp, mergeset_limit = p.msl,
                      s_max = p.s_max, u2 = true,
                      u3_mode = G.U3_DYNAMIC, sp_mode = G.SP_PYTHON, merge_mode = G.MERGE_PYTHON)
    est = G.EstadoRapido(params, ID_GENESIS; slot_g = UInt64(0), sr_g = UInt64(0),
                         ident_g = UInt64(0))
    return Sim(params, p, est, [0.0], [0.0], [0.0], UInt8[0x00], UInt8[0x00],
               Int[0], 0, BitSet(), ev, p.regimen === :sr)
end

const DELTA = DELTA_NOMINAL
const U3 = G.U3_DYNAMIC
const SP = G.SP_PYTHON
const MERGE = G.MERGE_PYTHON

@inline _slot(t::Float64) = UInt64(floor(t))

"""Añade un bloque. Devuelve su índice, o 0 si `anadir!` lo rechazó (no se añade nada)."""
function agrega!(sim::Sim, id::String, padres::Vector{Int}, t::Float64, sd::UInt64,
                 ident::UInt64)
    ok = G.anadir!(sim.est, sim.params, id, padres, _slot(t), sd,
                   sim.usa_sr ? sd : UInt64(0), ident)
    if ok
        push!(sim.tcrea, t)
        push!(sim.llegadaA, Inf)
        push!(sim.llegadaC, Inf)
        push!(sim.autor, 0x01)
        # Los buffers de vista se dimensionan con el estado: `tips_vista!` escribe por índice de
        # bloque y recorre `1:est.n`. No hacerlo así fue un fallo real de este puerto (escritura
        # fuera de rango con `@inbounds`), no una precaución teórica.
        push!(sim.visible, 0x00)
        push!(sim.marca, 0)
        return sim.est.n
    end
    return 0
end

# ---------------------------------------------------------------------------------------
# Puntas sobre una vista
# ---------------------------------------------------------------------------------------

"""
Puntas de la vista dada por `llegada[·] <= t`, en orden ascendente de índice.
`tips(vis) = vis \\ padres(vis)`, la definición de `r8c_gd.tips`.
"""
function tips_vista!(sim::Sim, llegada::Vector{Float64}, t::Float64, con_todos::Bool)
    n = sim.est.n
    @inbounds for i in 1:n
        sim.visible[i] = (con_todos || llegada[i] <= t) ? 0x01 : 0x00
    end
    sim.token += 1
    tok = sim.token
    @inbounds for i in 1:n
        if sim.visible[i] == 0x01
            for p in sim.est.padres[i]
                sim.marca[p] = tok
            end
        end
    end
    tips = Int[]
    @inbounds for i in 1:n
        if sim.visible[i] == 0x01 && sim.marca[i] != tok
            push!(tips, i)
        end
    end
    return tips
end

"""`|unordered_mergeset(sp, padres ∪ {extra})|` = `|past(B) \\ (past(sp) ∪ {sp})|`."""
function tam_mergeset(sim::Sim, sp::Int, padres::Vector{Int}, extra::Int)
    acc = sim.scratch
    empty!(acc)
    @inbounds for p in padres
        push!(acc, p)
        union!(acc, sim.est.anc[p])
    end
    if extra != 0
        push!(acc, extra)
        union!(acc, sim.est.anc[extra])
    end
    @inbounds for x in sim.est.anc[sp]
        delete!(acc, x)
    end
    delete!(acc, sp)
    return length(acc)
end

"""
`pick_virtual_parents` portado de `r8c_sim._padres`. Orden de candidatos `(−bw, id)`; **sin `sd`**.
"""
function elegir_padres(sim::Sim, tips::Vector{Int})
    isempty(tips) && error("vista sin puntas: el génesis siempre debe estar")
    est = sim.est
    sort!(tips, lt = (i, j) -> begin
        c = cmp(est.gd[i].bw, est.gd[j].bw)          # bw descendente
        c != 0 ? (c > 0) : (est.ids[i] < est.ids[j]) # empate: id ascendente
    end)
    sp = tips[1]
    padres = Int[sp]
    ms = 1
    msl = Int(sim.p.msl)
    mp = Int(sim.p.mp)
    for k in 2:length(tips)
        (ms >= msl || length(padres) >= mp) && break
        inc = tam_mergeset(sim, sp, padres, tips[k]) + 1 - ms
        if ms + inc <= msl
            push!(padres, tips[k])
            ms += inc
        end
    end
    return padres
end

# ---------------------------------------------------------------------------------------
# CONTROL POSITIVO — `d8_a3_smax.MundoEclipse.corre_ecl`
# ---------------------------------------------------------------------------------------

struct ResultadoControl
    gaps::Vector{Int}          # slot(B) − slot(sp(B)) de cada bloque de C
    n::Int                     # nº de bloques de C que se añadieron
end

"""
`corre_ecl(E, sem; fc = 0.05)`: un honesto `C` con fracción `fc` del espacio que recibe **todo**
con `E` s de retraso extra. Es el instrumento del control de D8 A3b: la fila publicada es
`E = 200`, `fc = 0.05`, α = 0 → 0,8218 / 0,6513 / 0,5920 / 0,5460 para `S_max ∈ {4, 20, 30, 150}`.
"""
function corre_control!(sim::Sim, E::Float64; fc::Float64 = 0.05, retraso::Float64 = 0.0)
    p = sim.p
    rng = PyRandom(string(p.semilla, "|", py_str(p.T), "|", py_str(p.alpha), "|",
                           py_str(E), "|", py_str(fc)))
    delta = p.delta
    gaps = Int[]
    nC = 0
    for (i, e) in enumerate(sim.ev)
        t = e.t
        if !e.atacante && random(rng) < fc
            tips = tips_vista!(sim, sim.llegadaC, t, false)
            padres = elegir_padres(sim, tips)
            idx = agrega!(sim, "c$i", padres, t, e.sd, UInt64(i))
            if idx != 0
                sim.llegadaA[idx] = t + delta
                sim.llegadaC[idx] = t
                sim.autor[idx] = 0x02
                sp = sim.est.gd[idx].sp
                push!(gaps, Int(floor(t)) - Int(floor(sim.tcrea[sp])))
                nC += 1
            end
            continue
        end
        if !e.atacante
            tips = tips_vista!(sim, sim.llegadaA, t, false)
            padres = elegir_padres(sim, tips)
            idx = agrega!(sim, "b$i", padres, t, e.sd, UInt64(i))
            if idx != 0
                sim.llegadaA[idx] = t + delta
                sim.llegadaC[idx] = t + delta + E
            end
            continue
        end
        tips = tips_vista!(sim, sim.llegadaA, t, true)   # el atacante ve TODO al instante
        padres = elegir_padres(sim, tips)
        idx = agrega!(sim, "a$i", padres, t, e.sd, UInt64(i))
        if idx != 0
            sim.llegadaA[idx] = t + retraso
            sim.llegadaC[idx] = t + retraso + E
            sim.autor[idx] = 0x03
        end
    end
    return ResultadoControl(gaps, nC)
end

# ---------------------------------------------------------------------------------------
# LAS TRES VARIANTES — `r11b_lib.MundoVictima.corre_victima`
# ---------------------------------------------------------------------------------------

struct ResultadoVictima
    t_V::Vector{Float64}         # instante de creación de cada bloque de V
    gaps_V::Vector{Int}          # slot(B) − slot(sp(B))
    ids_V::Vector{Int}           # índice del bloque en el estado
    llegadas_V::Vector{Float64}  # instantes en que algo ENTRA en la vista de V
    n_V::Int
    n_bloqueados::Int            # bloques ajenos que el filtro no dejó pasar
    n_pasados::Int
end

"""
`modo ∈ (:pot, :filtro, :retraso)`.
  · `:pot`      el atacante retiene el PoT: la víctima deja de fabricar bloques desde `t_ecl`.
  · `:filtro`   el PoT pasa; de los bloques honestos ajenos sólo llega una fracción `paso`;
                los del atacante llegan siempre (es su único vecino).
  · `:retraso`  el PoT pasa; todo llega con `E` s de retraso extra.
"""
function corre_victima!(sim::Sim, modo::Symbol, f_v::Float64; paso::Float64 = 1.0,
                        E::Float64 = 0.0, t_ecl::Float64 = 0.0, retraso_a::Float64 = 0.0,
                        con_todos_atacante::Bool = true)
    modo in (:pot, :filtro, :retraso) || error("modo desconocido: $modo")
    p = sim.p
    rng = PyRandom(string(p.semilla, "|", py_str(p.T), "|", py_str(p.alpha), "|", string(modo),
                           "|", py_str(f_v), "|", py_str(paso), "|", py_str(E), "|",
                           py_str(t_ecl)))
    delta = p.delta
    t_V = Float64[]; gaps_V = Int[]; ids_V = Int[]
    llegadas_V = Float64[]
    n_bloqueados = 0; n_pasados = 0
    for (i, e) in enumerate(sim.ev)
        t = e.t
        eclipsado = t >= t_ecl
        if !e.atacante && random(rng) < f_v
            # ---- bloque de la VÍCTIMA ----
            if modo === :pot && eclipsado
                continue                       # sin PoT no hay slot que justificar: no hay bloque
            end
            tips = tips_vista!(sim, sim.llegadaC, t, false)
            padres = elegir_padres(sim, tips)
            idx = agrega!(sim, "v$i", padres, t, e.sd, UInt64(i))
            if idx != 0
                sim.llegadaA[idx] = t + delta      # sus bloques SÍ llegan a la red
                sim.llegadaC[idx] = t
                sim.autor[idx] = 0x02
                sp = sim.est.gd[idx].sp
                push!(gaps_V, Int(floor(t)) - Int(floor(sim.tcrea[sp])))
                push!(t_V, t); push!(ids_V, idx)
            end
            continue
        end
        if !e.atacante
            # ---- honesto que NO es la víctima ----
            tips = tips_vista!(sim, sim.llegadaA, t, false)
            padres = elegir_padres(sim, tips)
            idx = agrega!(sim, "b$i", padres, t, e.sd, UInt64(i))
            if idx != 0
                sim.llegadaA[idx] = t + delta
                if !eclipsado
                    sim.llegadaC[idx] = t + delta
                    push!(llegadas_V, t + delta); n_pasados += 1
                elseif modo === :filtro
                    if random(rng) < paso
                        sim.llegadaC[idx] = t + delta
                        push!(llegadas_V, t + delta); n_pasados += 1
                    else
                        n_bloqueados += 1
                    end
                elseif modo === :retraso
                    sim.llegadaC[idx] = t + delta + E
                    push!(llegadas_V, t + delta + E); n_pasados += 1
                else                        # :pot  — no ve nada
                    n_bloqueados += 1
                end
            end
            continue
        end
        # ---- bloque del ATACANTE ----
        tips = tips_vista!(sim, sim.llegadaA, t, con_todos_atacante)
        padres = elegir_padres(sim, tips)
        idx = agrega!(sim, "a$i", padres, t, e.sd, UInt64(i))
        if idx != 0
            sim.autor[idx] = 0x03
            sim.llegadaA[idx] = t + retraso_a
            if modo === :pot && eclipsado
                n_bloqueados += 1
            elseif modo === :retraso && eclipsado
                sim.llegadaC[idx] = t + retraso_a + E
                push!(llegadas_V, t + retraso_a + E); n_pasados += 1
            else
                sim.llegadaC[idx] = t + retraso_a
                push!(llegadas_V, t + retraso_a); n_pasados += 1
            end
        end
    end
    return ResultadoVictima(t_V, gaps_V, ids_V, llegadas_V, length(ids_V), n_bloqueados,
                            n_pasados)
end

end # module
