# ─────────────────────────────────────────────────────────────────────────────
# validacion.jl — controles de regresión contra lo publicado y contra el oráculo,
#                 más los controles independientes del encargo §3.
# ─────────────────────────────────────────────────────────────────────────────

"Filas publicadas de REV-v1.0 / ADL-v1.0 usadas como control externo."
function filas_publicadas()
    return (
        adl = (cfg = (L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7200.0, con_h = false, espera = true),
               J = 1400,
               rho = [1.0, 1.001, 1.005, 1.008, 1.01, 1.1, 1.5, 2.0, 2.5, 3.0, 9.0],
               valor = [0.0, 1197.40, 5963.16, 7181.75, 7183.43, 7252.36, 7458.67,
                        7600.50, 7685.60, 7742.33, 7931.44],
               fuente = "resultados/ADL.txt (J=1400)"),
        f1C = (cfg = (L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7200.0, con_h = false, espera = false),
               J = 1400,
               rho = [1.01, 1.05, 1.10, 1.25, 1.50, 2.00, 2.50, 3.00, 5.00, 9.00],
               valor = [7203.4, 7235.5, 7272.4, 7365.2, 7478.7, 7620.5, 7705.6, 7762.3, 7875.8, 7951.4],
               fuente = "resultados/F1.txt bloque C (especula)"),
        f2L = (cfg = (L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7200.0, con_h = true, espera = true),
               J = 1400,
               rho = [1.01, 1.05, 1.10, 1.25, 1.50, 2.00, 2.50, 3.00, 5.00, 9.00],
               valor = [79.7, 383.4, 731.9, 1610.2, 2683.7, 4025.5, 4830.6, 5367.3, 6440.8, 7156.4],
               fuente = "resultados/F2.txt (h, Lrev=L, espera)"),
        f2S = (cfg = (L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7050.0, con_h = true, espera = true),
               J = 1400,
               rho = [1.01, 1.05, 1.10, 1.25, 1.50, 2.00, 2.50, 3.00, 5.00, 9.00],
               valor = [203.2, 501.2, 843.3, 1705.2, 2758.7, 4075.5, 4865.6, 5392.3, 6445.8, 7152.0],
               fuente = "resultados/F2.txt (h, Lrev=L−S_max=7050, espera)"),
    )
end

"Reejecuta cada fila publicada con el kernel y devuelve el error máximo absoluto."
function control_filas_publicadas()
    out = NamedTuple[]
    for (nombre, f) in pairs(filas_publicadas())
        cfg = cfg_base(; f.cfg...)
        off = zeros(Float64, f.J + 1); propia = falses(f.J + 1)
        medido = Float64[]
        for rho in f.rho
            b = Bufs{Float64}(f.J, 1)
            push!(medido, simular_replica!(b, cfg, off, propia, Float64(rho), f.J, 1.0, 0.0, false).vmax)
        end
        push!(out, (control = String(nombre), fuente = f.fuente,
                    max_dif = maximum(abs.(medido .- f.valor)),
                    medido = medido, publicado = f.valor))
    end
    return out
end

"Posición de una frontera de la trayectoria en el instante `t` (para el muestreo denso)."
function posicion_en(tr::Tray{T}, t::T, rama::Symbol) where {T<:Real}
    tt = rama === :A ? tr.tA : tr.tH
    pp = rama === :A ? tr.pA : tr.pH
    n = rama === :A ? tr.nA : tr.nH
    i = 1
    @inbounds while i < n && tt[i+1] <= t
        i += 1
    end
    i == n && return pp[n] + (t - tt[n]) * (pp[n] - pp[n-1]) / (tt[n] - tt[n-1])
    return pp[i] + (pp[i+1] - pp[i]) * (t - tt[i]) / (tt[i+1] - tt[i])
end

"""
Equivalencia del oráculo max-plus con el kernel de puntos de ruptura, en `Rational{BigInt}`
y **traza pequeña**. Devuelve `(casos, peor)` con la mayor discrepancia en `τ_j`.
Cubre las banderas: con/sin (h), espera/especula, cruce con coste/gratis,
semilla presente/futura y espera frente a dos líneas causales. La igualdad
numérica no acredita los tiempos de conocimiento de una ancla DAG real.
"""
function equivalencia_oraculo(; Js = (3, 5, 8, 12), rhos = (Rational{BigInt}(3)//2,
                                                             Rational{BigInt}(2),
                                                             Rational{BigInt}(5)))
    R = Rational{BigInt}
    peor = R(0); casos = 0
    for conh in (true, false), espera in (true, false), cruce in (true, false),
        sf in (true, false), paralela in (true, false), J in Js, rho in rhos
        offr = [R(i % 3) for i in 1:J]
        propia = [isodd(i) for i in 1:J]
        cfg = Cfg{R}(L = R(40), I = R(11), W_dec = R(3), D = R(2), S_max = R(6),
                     Lrev = R(33), con_h = conh, espera = espera, semilla_futura = sf,
                     revelacion_paralela = paralela, lineas_revelacion = 2,
                     cruce = cruce, lead_h = R(2))
        tr = Tray{R}(J); construir!(tr, cfg, offr, propia, rho, J)
        tau = tau_maxplus(cfg, offr, propia, rho, J)
        for j in 1:J
            tj = R(j) * cfg.I + offr[j] + cfg.L
            kt = R(-1)
            for i in 1:tr.nA
                tr.pA[i] == tj && (kt = tr.tA[i])
            end
            d = abs(kt - tau[j]); d > peor && (peor = d)
        end
        casos += 1
    end
    return (casos = casos, peor = peor)
end

"""
Cuartiles exactos vs muestreo denso (validación independiente de la integración por
tramos). Devuelve `(q50_exacto, q50_denso, dif)`.
"""
function equivalencia_cuantil(; J = 6, rho = 5//2, δ_den = 64)
    R = Rational{BigInt}
    cfg = Cfg{R}(L = R(60), I = R(13), W_dec = R(4), D = R(3), S_max = R(7), Lrev = R(50),
                con_h = true, espera = false, semilla_futura = true,
                revelacion_paralela = false, cruce = true, lead_h = R(3))
    offr = [R(i % 4) for i in 1:J]
    propia = [isodd(i) for i in 1:J]
    tr = Tray{R}(J); construir!(tr, cfg, offr, propia, R(rho), J)
    t_ini = R(0); t_fin = tr.tA[tr.nA]
    q_ex = cuantil_exacto(tr, 0.5, t_ini, t_fin, R(-100), R(10000); iter = 40)
    # muestreo denso de V en t = t_ini + k·δ
    vals = R[]
    k = 0
    while true
        t = t_ini + R(k, δ_den)
        t > t_fin && break
        push!(vals, posicion_en(tr, t, :A) - posicion_en(tr, t, :H))
        k += 1
    end
    sort!(vals)
    q_de = vals[max(1, min(length(vals), ceil(Int, 0.5 * length(vals))))]
    return (q50_exacto = q_ex, q50_denso = q_de, dif = abs(q_ex - q_de), n_muestras = length(vals))
end

"""
Controles independientes del encargo §3. Cada uno devuelve `(control, valor, veredicto)`
con el valor medido y si el control se cumple.
"""
function controles_independientes(; J = 1500)
    out = NamedTuple[]
    base = (L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0)
    v_sin = vmax_det(cfg_base(; base..., Lrev = 7200.0, con_h = false), 2.5; J = J)

    # C1 — sin segunda cadena se recupera el PoT vigente
    c1 = control_filas_publicadas()[1].max_dif
    push!(out, (control = "C1 sin (h) recupera el PoT vigente (ADL.txt)",
                valor = c1, ok = c1 < 0.05))

    # C2 — ρ = 1 no crea adelanto por velocidad
    v1 = vmax_det(cfg_base(; base..., Lrev = 7050.0, con_h = true), 1.0; J = J)
    push!(out, (control = "C2 ρ=1 no crea adelanto", valor = v1, ok = abs(v1) < 1e-9))

    # C3 — la ventaja de ρ>1 no se anula mágicamente con la segunda cadena
    v19 = vmax_det(cfg_base(; base..., Lrev = 7050.0, con_h = true), 19.0; J = J)
    push!(out, (control = "C3 con (h) y ρ=19 la ventana sigue ≫0", valor = v19, ok = v19 > 1000.0))

    # C4 — ρ→∞ revela el límite del mecanismo. Dos objetos distintos:
    #   · el tope de ADL L+I−W_dec−D = 8027 NO es el límite del modelo;
    #   · con la condición inicial de REV (las dos fronteras a nivel en t=0) el máximo
    #     lo pone el transitorio de la PRIMERA época: L+I−lead_h = 8047.
    # Descartando el transitorio (j_ini>0) reaparece la envolvente A_core−D.
    vinf = vmax_det(cfg_base(; base..., Lrev = 7200.0, con_h = false), 1000.0; J = J)
    vinf_sin_trans = vmax_det(cfg_base(; base..., Lrev = 7200.0, con_h = false), 1000.0;
                              J = J, j_ini = 3)
    tope_adl = base.L + base.I - base.W_dec - base.D
    tope_trans = base.L + base.I - base.D
    env = (base.L - 1 - base.W_dec) + base.I - base.D     # A_core(∞) − D
    push!(out, (control = "C4 ρ→∞: límite = transitorio L+I−lead_h, no el tope ADL",
                valor = vinf, ok = vinf > tope_adl && vinf <= tope_trans + 1e-6))
    push!(out, (control = "C4b ρ→∞ sin transitorio (j_ini=3) recupera A_core−D",
                valor = vinf_sin_trans, ok = abs(vinf_sin_trans - env) < 1.0))

    # C5 — el coste de rachas no se sustituye por una media
    r = control_rachas(base.L, base.I, 2.5, base.W_dec, 0.33, 20_000, 64, UInt64(0x5a5a))
    push!(out, (control = "C5 tasa de rachas medida vs cerrada α^(n*−1)",
                valor = r.medida / max(r.cerrada, 1e-12), ok = abs(r.medida - r.cerrada) < 0.25 * r.cerrada))

    # C6 — la puntualidad del honesto falla si la revelación llega tarde
    cfg_tarde = cfg_base(; base..., Lrev = base.L - 1.0, con_h = true)
    off = zeros(Float64, J + 1); propia = falses(J + 1)
    b = Bufs{Float64}(J, 1)
    res = simular_replica!(b, cfg_tarde, off, propia, 2.5, J, 1.0, 0.0, false)
    push!(out, (control = "C6 Lrev=L−1 ⇒ el honesto se estanca",
                valor = Float64(res.n_stall), ok = res.n_stall > 0 &&
                holgura_puntualidad(base.L, base.W_dec, base.D, base.L - 1.0) < 0))

    # C7 — presupuesto agotado es Pendiente, no Inválido
    e1 = transicion_estado_pot(:Pendiente, :presupuesto_agotado)
    e2 = transicion_estado_pot(:Valido, :presupuesto_agotado)
    push!(out, (control = "C7 presupuesto agotado ⇒ Pendiente (nunca Inválido)",
                valor = (e1 === :Pendiente && e2 === :Pendiente) ? 1.0 : 0.0,
                ok = e1 === :Pendiente && e2 === :Pendiente))

    # C8 — control ideal separado: revelación instantánea sin ejecutar AES.
    v_par = vmax_det(cfg_base(; base..., Lrev = 7050.0, con_h = true,
                              revelacion_instantanea = true), 2.5; J = J)
    push!(out, (control = "C8 control ideal instantáneo ⇒ V vuelve a V_sin",
                valor = v_par, ok = abs(v_par - v_sin) < 1e-9))
    # C9 — varias líneas no pueden borrar la latencia de una cadena recién liberada.
    v_causal = vmax_det(cfg_base(; base..., Lrev = 7050.0, con_h = true,
                                 revelacion_paralela = true, lineas_revelacion = 9), 2.5; J = J)
    push!(out, (control = "C9 nueve líneas causales conservan latencia secuencial",
                valor = v_causal, ok = v_causal < v_sin && v_causal > 0))

    return out
end
