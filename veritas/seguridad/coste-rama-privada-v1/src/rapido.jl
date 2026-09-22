# CRP-v0.1 — kernel: Monte Carlo rápido del proceso de trabajo, barrido de α y reúso
# del oráculo GDR-v0.2 para el DAG real (no se reimplementa GHOSTDAG).
using StableRNGs

# ---------------------------------------------------------------------------
# Poisson (Knuth). exacto para los μ pequeños del modelo (λ0 normalizado a 1 y s≤1).
# ---------------------------------------------------------------------------
function poisson_knuth(rng, mu::Float64)
    mu <= 0 && return 0
    L = exp(-mu)
    k = 0
    pr = 1.0
    while true
        pr *= rand(rng)
        pr <= L && return k
        k += 1
    end
end

"""
Rama rápida: espacio `s`, `n_slots` slots, controlador de rango opcional. Devuelve el
trabajo total (unidades de w(sr0)), los bloques y el nº de slots con al menos un bloque.
No asigna en el bucle salvo la ventana del controlador (preasignada de tamaño fijo).
"""
function simular_rama_rapido(rng, s::Real, p::Parametros; n_slots::Int=100,
                             sr::Integer=p.sr0, ctrl::Union{Nothing,Controlador}=nothing)
    total = 0.0
    bloques = 0
    sr_act = UInt64(sr)
    Wv = ctrl === nothing ? 0 : ctrl.ventana
    obs = zeros(Int, Wv)
    nobs = 0
    # el peso relativo se calcula SÓLO cuando cambia el sr; fuera del bucle si es fijo.
    wrel = Float64(peso_relativo(sr_act, p.sr0))
    for _ in 1:n_slots
        mu = tasa_esperada(s, sr_act, p)
        k = poisson_knuth(rng, mu)
        bloques += k
        total += k * wrel
        if ctrl !== nothing
            if nobs < Wv
                nobs += 1
            else
                @inbounds for i in 1:(Wv - 1)
                    obs[i] = obs[i + 1]
                end
            end
            obs[nobs] = k
            nuevo = actualiza_controlador(ctrl, sr_act, view(obs, 1:nobs), p)
            if nuevo != sr_act
                sr_act = nuevo
                wrel = Float64(peso_relativo(sr_act, p.sr0))
            end
        end
    end
    return (trabajo=total, bloques=bloques)
end

"Una réplica de la carrera: (trabajo_honesto, trabajo_adversario) en el modo dado."
function simular_raza(rng, p::Parametros, α::Real; publica::Bool=false, n_slots::Int=100,
                      ctrl_h::Union{Nothing,Controlador}=nothing,
                      ctrl_a::Union{Nothing,Controlador}=nothing,
                      s_h::Union{Nothing,Real}=nothing, s_a::Union{Nothing,Real}=nothing,
                      sr_h::Integer=p.sr0, sr_a::Integer=p.sr0)
    sh = s_h === nothing ? (publica ? 1.0 : (1.0 - α)) : s_h
    sa = s_a === nothing ? α : s_a
    rh = simular_rama_rapido(rng, sh, p; n_slots=n_slots, ctrl=ctrl_h, sr=sr_h)
    ra = simular_rama_rapido(rng, sa, p; n_slots=n_slots, ctrl=ctrl_a, sr=sr_a)
    return (rh.trabajo, ra.trabajo)
end

"""
Efecto de la VARIANZA elegida por el adversario: con el mismo trabajo medio `α·T`, un `sr`
más bajo (peso por bloque mayor, menos bloques) tiene más varianza. Se mide la probabilidad
de que el adversario supere a la honesta para α<1/2 y varios factores K=sr0/sr.
"""
function efecto_varianza_sr(p::Parametros; α::Real=0.45, n_slots::Int=400,
                            factores=(1, 4, 16, 64), n_rep::Int=4000,
                            semilla::UInt64=UInt64(0x5A71A))
    filas = Vector{Tuple{Int,Float64,Float64,Float64}}(undef, length(factores))
    for (ik, K) in enumerate(factores)
        sra = max(UInt64(1), p.sr0 ÷ K)
        gana = zeros(Int, n_rep)
        suma_a = zeros(Float64, n_rep)
        Threads.@threads for r in 1:n_rep
            rng = StableRNG(semilla + UInt64(0x9E3779B9) * UInt64(ik) + UInt64(r))
            bh, ba = simular_raza(rng, p, α; n_slots=n_slots, sr_a=sra, sr_h=p.sr0)
            gana[r] = (ba > bh) ? 1 : 0
            suma_a[r] = ba
        end
        filas[ik] = (K, sum(gana) / n_rep, sum(suma_a) / n_rep, α * n_slots)
    end
    return filas
end

"""
Barrido de α: fracción de réplicas en que el adversario supera ESTRICTAMENTE el trabajo
honesto. Paralelizado por réplica, RNG por réplica y reducción determinista (se suman
contadores enteros en orden). Devuelve vector de (α, prob_gana, n_rep).
"""
function barrido_alpha(p::Parametros, alphas; n_rep::Int=64, n_slots::Int=100,
                       publica::Bool=false, semilla::UInt64=UInt64(0xC057E),
                       ctrl_h::Union{Nothing,Controlador}=nothing,
                       ctrl_a::Union{Nothing,Controlador}=nothing)
    filas = Vector{Tuple{Float64,Float64,Int}}(undef, length(alphas))
    for (ia, α) in enumerate(alphas)
        ganan = Threads.Atomic{Int}(0)
        Threads.@threads for r in 1:n_rep
            rng = StableRNG(semilla + UInt64(0x9E3779B9) * UInt64(ia) + UInt64(r))
            bh, ba = simular_raza(rng, p, α; publica=publica, n_slots=n_slots,
                                  ctrl_h=ctrl_h, ctrl_a=ctrl_a)
            ba > bh && Threads.atomic_add!(ganan, 1)
        end
        filas[ia] = (Float64(α), ganan[] / n_rep, n_rep)
    end
    return filas
end

"Punto de cruce (interpolación lineal) de la primera fila con prob ≥ 0.5."
function alpha_cruce(filas)
    for i in 2:length(filas)
        (filas[i - 1][2] < 0.5 <= filas[i][2]) || continue
        (a0, p0, _) = filas[i - 1]; (a1, p1, _) = filas[i]
        p1 == p0 && return a1
        return a0 + (0.5 - p0) * (a1 - a0) / (p1 - p0)
    end
    return filas[1][2] >= 0.5 ? filas[1][1] : NaN
end

"Monte Carlo de la curva corta con granularidad `g` (pasos de Poisson), referencia."
function curva_corta_mc(αs, d_work::Real, g::Real; n_rep::Int=2000,
                        semilla::UInt64=UInt64(0xC0FFEE))
    out = Vector{Tuple{Float64,Float64}}(undef, length(αs))
    for (ia, α) in enumerate(αs)
        alcanzan = Threads.Atomic{Int}(0)
        Threads.@threads for r in 1:n_rep
            rng = StableRNG(semilla + UInt64(0x9E3779B9) * UInt64(ia) + UInt64(r))
            h = 0.0; a = 0.0
            ganado = false
            while h - a < d_work
                h += poisson_knuth(rng, g * (1 - α)) / g
                a += poisson_knuth(rng, g * α) / g
                if a >= h
                    ganado = true
                    break
                end
            end
            ganado && Threads.atomic_add!(alcanzan, 1)
        end
        out[ia] = (Float64(α), alcanzan[] / n_rep)
    end
    return out
end

# ---------------------------------------------------------------------------
# Reúso del oráculo GDR-v0.2 (auditado): NO se reimplementa GHOSTDAG.
# ---------------------------------------------------------------------------
function ruta_gdr()
    a = abspath(@__DIR__)
    for _ in 1:12
        for rel in (joinpath("veritas", "consenso", "ghostdag-rank-v1", "src", "GhostdagRank.jl"),
                    joinpath("consenso", "ghostdag-rank-v1", "src", "GhostdagRank.jl"))
            cand = joinpath(a, rel)
            isfile(cand) && return cand
        end
        padre = dirname(a)
        padre == a && break
        a = padre
    end
    error("no se encuentra GDR-v0.2 subiendo desde $(@__DIR__)")
end

const RUTA_GDR = ruta_gdr()

function incluir_ghostdag()
    m = Module(:GDRReuso)
    Base.include(m, RUTA_GDR)
    return Base.invokelatest(getfield, m, :GhostdagRank)
end

"Parámetros de GDR equivalentes a los de este instrumento."
function params_gdr(GDR, p::Parametros)
    return GDR.Params(k=Int(p.k), max_parents=Int(p.max_padres),
                      mergeset_limit=Int(p.mergeset_limit), s_max=Int(p.s_max),
                      u2=true, u3_mode=GDR.U3_DYNAMIC,
                      sp_mode=GDR.SP_ZEROX, merge_mode=GDR.MERGE_SPEC)
end

"""
Construye una rama DAG válida con GDR-v0.2. En cada slot produce `Poisson(λ(s,sr))`
bloques; cada bloque toma como padres la punta virtual (C-GD-03) más una muestra de las
demás puntas (hasta `max_padres`). `ctrl` actualiza el rango de la rama; `sr_fijo` lo fija.
Devuelve el estado GDR.
"""
function construir_rama_gdr(GDR, p::Parametros; s::Real, n_slots::Int=100,
                            sr_fijo::Union{Nothing,Integer}=nothing,
                            ctrl::Union{Nothing,Controlador}=nothing,
                            rng, idbase::String="B", ident_por_bloque::Bool=false,
                            sr_por_bloque::Union{Nothing,Function}=nothing)
    params = params_gdr(GDR, p)
    sr0g = sr_fijo === nothing ? p.sr0 : UInt64(sr_fijo)
    est = GDR.EstadoRapido(params, "G"; sr_g=sr0g)
    puntas = Int[1]
    sr_act = sr_fijo === nothing ? p.sr0 : UInt64(sr_fijo)
    Wv = ctrl === nothing ? 0 : ctrl.ventana
    obs = zeros(Int, Wv); nobs = 0
    contador = 0
    saltados = 0
    for t in 1:n_slots
        mu = tasa_esperada(s, sr_act, p)
        k = min(poisson_knuth(rng, mu), 200)   # tope de simulación: evita explotar si un
                                               # controlador patológico dispara `sr`
        for _ in 1:k
            contador += 1
            # padre seleccionado = punta de mayor blue_work (C-GD-03)
            sp = puntas[1]
            mejor = GDR.bw_de(est, sp)
            for x in puntas[2:end]
                bx = GDR.bw_de(est, x)
                if bx > mejor || (bx == mejor && x < sp)
                    sp = x; mejor = bx
                end
            end
            extras = [x for x in puntas if x != sp]
            npad = min(length(extras), Int(p.max_padres) - 1)
            if npad > 0
                shuffle!(rng, extras)
                extras = extras[1:npad]
            end
            padres = vcat(sp, extras)
            sr_bloque = sr_por_bloque === nothing ? sr_act : UInt64(sr_por_bloque(t, contador))
            ident = ident_por_bloque ? UInt64(contador) : UInt64(0)
            id = string(idbase, "_", contador)
            ok = GDR.anadir!(est, params, id, padres, UInt64(t), UInt64(rand(rng, 0:(2^20))),
                             sr_bloque, ident)
            if !ok && length(padres) > 1
                ok = GDR.anadir!(est, params, id, Int[sp], UInt64(t),
                                 UInt64(rand(rng, 0:(2^20))), sr_bloque, ident)
            end
            if !ok
                saltados += 1
                continue
            end
            nuevo = est.n
            # actualiza puntas: los padres dejan de ser puntas
            puntas = [x for x in puntas if !(x in padres)]
            push!(puntas, nuevo)
        end
        if ctrl !== nothing
            if nobs < Wv
                nobs += 1
            else
                @inbounds for i in 1:(Wv - 1); obs[i] = obs[i + 1]; end
            end
            obs[nobs] = k
            sr_act = actualiza_controlador(ctrl, sr_act, view(obs, 1:nobs), p)
        end
    end
    return (est=est, saltados=saltados)
end

"Medición de una rama GDR: bloques, azules de la punta y blue_work canónico."
function medir_rama(GDR, est)
    v = GDR.virtual_sp(est, GDR.P_DEFECTO)
    bs = GDR.blueset(est, v)
    return (n_total=est.n - 1, n_azules=length(bs), blue_work=est.gd[v].bw,
            blue_score=est.gd[v].blue_score, canonica=v)
end

"""
Medición de una rama GDR con el trabajo NORMALIZADO a w(sr0): suma de `w(sr_x)/w(sr0)`
sobre el conjunto azul de la punta. Permite comparar ramas cuyos bloques tienen sr
distinto (controlador), en las mismas unidades del modelo analítico.
"""
function medir_rama_normalizada(GDR, est, sr0::Integer)
    v = GDR.virtual_sp(est, GDR.P_DEFECTO)
    bs = GDR.blueset(est, v)
    t = big(0)//big(1)
    for x in bs
        t += peso_relativo(est.srs[x], sr0)
    end
    return (n_total=est.n - 1, n_azules=length(bs), trabajo_norm=t,
            blue_score=est.gd[v].blue_score, canonica=v)
end

"Experimento GDR: ramas con fracción `s` y `sr` fijo; el trabajo por slot debe ≈ s."
function experimento_gdr_invariancia(GDR, p::Parametros; ss=(0.1, 0.3, 0.5),
                                     srs=(p.sr0, p.sr0 << 2), n_slots::Int=200,
                                     semilla::UInt64=UInt64(0x6D1))
    filas = NamedTuple[]
    for (is, s) in enumerate(ss), (ir, sr) in enumerate(srs)
        rng = StableRNG(semilla + UInt64(1000 * is + ir))
        t = construir_rama_gdr(GDR, p; s=s, n_slots=n_slots, sr_fijo=sr, rng=rng)
        m = medir_rama(GDR, t.est)
        # trabajo en unidades de w(sr0): nº de pesos iguales × peso relativo
        trabajo_norm = Float64(BigInt(m.blue_work) // peso_exacto(sr)) *
                       Float64(peso_relativo(sr, p.sr0))
        push!(filas, (s=s, sr=sr, n_total=m.n_total, n_azules=m.n_azules,
                      trabajo_norm=trabajo_norm, trabajo_por_slot=trabajo_norm / n_slots,
                      saltados=t.saltados))
    end
    return filas
end

"Ramas GDR dirigidas por controlador: trabajo normalizado por slot (debe ≈ s)."
function experimento_gdr_controlador(GDR, p::Parametros; s=0.3, n_slots::Int=300,
                                     anclas=(CTRL_FIJO, CTRL_REACTIVO),
                                     n_rep::Int=8, semilla::UInt64=UInt64(0x6D2))
    filas = NamedTuple[]
    for (ia, ancla) in enumerate(anclas)
        vals = Float64[]
        ntots = Int[]
        for r in 1:n_rep
            # controlador "asentado": ganancia pequeña y ventana larga, para medir la
            # media sin la inestabilidad de un lazo proporcional agresivo (que se trata
            # aparte como vector de varianza).
            ctrl = Controlador(p; ancla=ancla, gamma=0.25, ventana=50)
            rng = StableRNG(semilla + UInt64(1000 * ia + r))
            t = construir_rama_gdr(GDR, p; s=s, n_slots=n_slots, ctrl=ctrl, rng=rng)
            m = medir_rama_normalizada(GDR, t.est, p.sr0)
            push!(vals, Float64(m.trabajo_norm) / n_slots)
            push!(ntots, m.n_total)
        end
        push!(filas, (ancla=ancla, s=s, trabajo_por_slot=sum(vals) / length(vals),
                      min=minimum(vals), max=maximum(vals), n_total_medio=sum(ntots) / length(ntots)))
    end
    return filas
end


# ---------------------------------------------------------------------------
# U2/U3″ contextual: comprobación contra el oráculo en los dos sentidos (§3.4).
# ---------------------------------------------------------------------------
function experimento_u2u3(GDR)
    params = GDR.Params(k=30, max_parents=15, mergeset_limit=180, s_max=150,
                        u2=true, u3_mode=GDR.U3_DYNAMIC,
                        sp_mode=GDR.SP_ZEROX, merge_mode=GDR.MERGE_SPEC)
    res = Dict{Symbol,Any}()

    # (a) DENTRO de una rama: dos copias del mismo billete en anticono. U3″ deja una azul.
    est = GDR.EstadoRapido(params, "G")
    okA = GDR.anadir!(est, params, "A1", Int[1], UInt64(1), UInt64(1), UInt64(1)<<40, UInt64(7))
    okB = GDR.anadir!(est, params, "A2", Int[1], UInt64(1), UInt64(1), UInt64(1)<<40, UInt64(7))
    # fusionador que ve ambas copias
    okC = GDR.anadir!(est, params, "C", Int[2, 3], UInt64(2), UInt64(1), UInt64(1)<<40, UInt64(0))
    tipos = est.gd[est.n].tipos
    azules_ms = est.gd[est.n].ms_blues
    rojos_ms = est.gd[est.n].ms_reds
    n_azules_ident7 = count(x -> est.idents[x] == 7, azules_ms)
    n_rojoU3 = count(x -> get(tipos, x, 0x00) == 0x02, rojos_ms)
    res[:dentro_ok] = (okA, okB, okC)
    res[:dentro_azules_ident7] = n_azules_ident7
    res[:dentro_rojoU3] = n_rojoU3
    res[:dentro_copias_validas] = okA && okB

    # (b) U2: un bloque cuyo padre YA contiene el mismo billete es rechazado.
    est2 = GDR.EstadoRapido(params, "G")
    GDR.anadir!(est2, params, "P", Int[1], UInt64(1), UInt64(1), UInt64(1)<<40, UInt64(9))
    okU2 = GDR.anadir!(est2, params, "H", Int[2], UInt64(2), UInt64(1), UInt64(1)<<40, UInt64(9))
    res[:u2_rechaza] = !okU2
    res[:u2_motivo] = est2.motivo[end]

    # (c) ENTRE dos ramas DISJUNTAS: el mismo billete en cada una; cada rama lo ve azul.
    est3 = GDR.EstadoRapido(params, "G")
    okX = GDR.anadir!(est3, params, "X", Int[1], UInt64(1), UInt64(1), UInt64(1)<<40, UInt64(11))
    okY = GDR.anadir!(est3, params, "Y", Int[1], UInt64(1), UInt64(1), UInt64(1)<<40, UInt64(11))
    # X e Y son disjuntas (ninguna es ancestro de la otra): ambas azules en su propio bloque.
    azulX = GDR.es_ancestro_rapido(est3, 2, 2) && okX
    azulY = GDR.es_ancestro_rapido(est3, 3, 3) && okY
    # y un fusionador posterior las ve: una azul, la otra roja_U3
    okZ = GDR.anadir!(est3, params, "Z", Int[2, 3], UInt64(2), UInt64(1), UInt64(1)<<40, UInt64(0))
    tiposZ = est3.gd[est3.n].tipos
    az_X = 2 in est3.gd[est3.n].ms_blues
    az_Y = 3 in est3.gd[est3.n].ms_blues
    res[:entre_validas] = (okX, okY, okZ)
    res[:entre_ambas_azules_en_su_rama] = azulX && azulY
    res[:entre_fusion_una_azul_otra_u3] = (az_X ⊻ az_Y) &&
        (get(tiposZ, az_X ? 3 : 2, 0x00) == 0x02)
    return res
end
