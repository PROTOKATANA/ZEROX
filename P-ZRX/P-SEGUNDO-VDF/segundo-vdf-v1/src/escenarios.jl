# ─────────────────────────────────────────────────────────────────────────────
# escenarios.jl — defecto 2 (escenarios mezclados), defecto 3 (semilla causal)
#                 y regímenes de líneas (encargo §4).
# ─────────────────────────────────────────────────────────────────────────────

"Configuración de control de la candidata: L=7200, W_dec=20 slots, D=4, S_max=150."
function cfg_base(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                  Lrev = L - S_max, con_h = false, espera = true, semilla_futura = true,
                  revelacion_paralela = false, revelacion_instantanea = false,
                  lineas_revelacion = 1, cruce = true, lead_h = D)
    return Cfg{Float64}(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max, Lrev = Lrev,
                        con_h = con_h, espera = espera, semilla_futura = semilla_futura,
                        revelacion_paralela = revelacion_paralela,
                        revelacion_instantanea = revelacion_instantanea,
                        lineas_revelacion = lineas_revelacion, cruce = cruce, lead_h = lead_h)
end

"V_max determinista (offset 0, α = 0) para una configuración."
function vmax_det(cfg::Cfg{Float64}, rho::Float64; J::Int = 1500, j_ini::Int = 0)
    off = zeros(Float64, J + 1); propia = falses(J + 1)
    b = Bufs{Float64}(J, 1)
    return simular_replica!(b, cfg, off, propia, rho, J, 1.0, 0.0, false; j_ini = j_ini).vmax
end

"""
Control de las **filas viejas** publicadas (REV-v1.0 + DECISIONES D2), tal como se
citaron, con el `I` que cada una usa. Devuelve una fila por afirmación y marca la
inconsistencia: la ventana y la edad salen de `I = 851`; el coste, de `I ≈ 4 766,7`.
"""
function control_filas_viejas()
    I_v = 851.0                 # F1.txt / ADL.txt / F4.txt
    I_c = 4766.67               # F3.txt (h.6 con L en el numerador)
    sin_h = cfg_base(I = I_v, con_h = false)
    con_h_ = cfg_base(I = I_v, con_h = true)
    v_sin = vmax_det(sin_h, 2.5)
    v_con = vmax_det(con_h_, 2.5)
    coste = tabla_coste(7200.0, 7050.0, I_c, 7200.0)
    return [
        (fila = "ventana V_max (ρ=2,5)", valor = v_sin, fuente = "ADL.txt/F1.txt", I = I_v),
        (fila = "ventana V_max con (h), Lrev=L−S_max", valor = v_con, fuente = "F2.txt", I = I_v),
        (fila = "ΔV/V_sin publicado", valor = (v_sin - v_con) / v_sin, fuente = "informe §1.1/D2", I = I_v),
        (fila = "edad q99 sin (h)", valor = 8800.0, fuente = "F4.txt (F=7200, α=0,33, ρ_max=2,5)", I = I_v),
        (fila = "edad q99 con (h)", valor = 5712.0, fuente = "F4.txt", I = I_v),
        (fila = "núcleos/nodo publicado", valor = coste.nucleos_verificador, fuente = "F3.txt/D2", I = I_c),
        (fila = "líneas publicadas", valor = coste.lineas_timekeeper, fuente = "F3.txt/D2", I = I_c),
        (fila = "I usado en el coste", valor = I_c, fuente = "F3.txt (I*=4766,7)", I = I_c),
    ]
end

"""
Defecto 2: reconstruye cada fila con el **mismo** `(I, L, Lrev, F, D, W_dec, α, ρ)`,
adversario y riesgo en las dos alternativas. `q99` se mide con `α = 0,33`,
`ρ = 2,5`, `J` épocas y `R` réplicas; el coste sale de la misma `I`.
"""
function tabla_escenarios_consistente(; L = 7200.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                                      rho = 2.5, F_slots = 7200.0, alpha = 0.33,
                                      J = 1200, R = 64, Is = (851.0, 4666.0),
                                      seed::UInt64 = UInt64(0x5a5a), nthreads::Int = 1)
    filas = NamedTuple[]
    for I in Is
        Lrev = L - S_max
        v_sin = vmax_det(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                  Lrev = Lrev, con_h = false), rho; J = J)
        v_con = vmax_det(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                  Lrev = Lrev, con_h = true), rho; J = J)
        res_sin = barrido(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                   Lrev = Lrev, con_h = false), [rho], J, R, seed,
                          400, 64.0, 0.0, Float64(alpha); modo_off = :geom, nthreads = nthreads)
        res_con = barrido(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                   Lrev = Lrev, con_h = true), [rho], J, R, seed,
                          400, 64.0, 0.0, Float64(alpha); modo_off = :geom, nthreads = nthreads)
        q99_sin = cuantil_hist(res_sin.hist[:, 1], res_sin.bajo[1], res_sin.sobre[1],
                               res_sin.bin, res_sin.v_lo, 0.99)
        q99_con = cuantil_hist(res_con.hist[:, 1], res_con.bajo[1], res_con.sobre[1],
                               res_con.bin, res_con.v_lo, 0.99)
        c = tabla_coste(L, Lrev, I, F_slots)
        push!(filas, (I = I, Lrev = Lrev, rho = rho,
                      rho_estrella = rho_estrella(Lrev, I, W_dec),
                      cumple_rho = rho_estrella(Lrev, I, W_dec) >= rho,
                      V_sin = v_sin, V_con = v_con,
                      dV_rel = (v_sin - v_con) / v_sin,
                      q99_sin = q99_sin, q99_con = q99_con,
                      factor_edad = q99_sin / q99_con,
                      puntualidad = holgura_puntualidad(L, W_dec, D, Lrev),
                      lineas = c.lineas_timekeeper,
                      nucleos = c.nucleos_verificador,
                      inyecciones_h = c.instantes_por_hora,
                      lineas_revelacion = c.lineas_capacidad))
    end
    return filas
end

"""
Defecto 3: misma comparación para las **dos semillas causales**.

- `semilla_futura = true` → C-FLU-12 vigente: ingrediente `pot_output(I_j) = salida(f, s_j+D)`.
- `semilla_futura = false` → candidata (h.1): ingrediente `salida(f, slot(I_j))`.

Devuelve V_max con y sin (h) en cada variante, la diferencia y los datos causales
(fecha en que cada entrada se conoce, grinding, unicidad, circularidad).
"""
function vmax_patron(cfg::Cfg{Float64}, rho::Float64, J::Int, patron::Symbol;
                      alpha::Float64 = 0.33, R::Int = 64, seed::UInt64 = UInt64(0x5a5a),
                      nthreads::Int = 1)
    if patron === :ajenas || patron === :propias
        off = zeros(Float64, J + 1)
        propia = patron === :propias ? trues(J + 1) : falses(J + 1)
        b = Bufs{Float64}(J, 400)
        return simular_replica!(b, cfg, off, propia, rho, J, 64.0, 0.0, false).vmax
    end
    res = barrido(cfg, [rho], J, R, seed, 400, 64.0, 0.0, alpha;
                  modo_off = :geom, nthreads = nthreads)
    # En el patrón mixto, la media de máximos por réplica conserva sensibilidad
    # a la semilla; el máximo global puede saturarse en la misma racha extrema.
    return mean(@view res.vmax[:, 1])
end

"""
Defecto 3: misma comparación para las **dos semillas causales**, en tres patrones de
ancla (ajena, propia y mixta α=0,33), porque la variante h.1 sólo puede diferenciarse
cuando el ancla es del atacante.

- `semilla_futura = true` → C-FLU-12 vigente: ingrediente `pot_output(I_j) = salida(f, s_j+D)`.
- `semilla_futura = false` → candidata (h.1): ingrediente `salida(f, slot(I_j))`.
"""
function tabla_semilla(; L = 7200.0, W_dec = 20.0, D = 4.0, S_max = 150.0, rho = 2.5,
                       Is = (851.0, 4666.0), J = 1500, R = 64,
                       seed::UInt64 = UInt64(0x5a5a), nthreads::Int = 1)
    filas = NamedTuple[]
    for I in Is
        Lrev = L - S_max
        for patron in (:ajenas, :propias, :mixto)
            v_sin = vmax_patron(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                         Lrev = Lrev, con_h = false, semilla_futura = true),
                                rho, J, patron; seed = seed, R = R, nthreads = nthreads)
            v_fut = vmax_patron(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                         Lrev = Lrev, con_h = true, semilla_futura = true),
                                rho, J, patron; seed = seed, R = R, nthreads = nthreads)
            v_pre = vmax_patron(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                         Lrev = Lrev, con_h = true, semilla_futura = false),
                                rho, J, patron; seed = seed, R = R, nthreads = nthreads)
            push!(filas, (I = I, patron = String(patron), V_sin = v_sin,
                          V_con_futura = v_fut, V_con_presente = v_pre,
                          dV_futura = (v_sin - v_fut) / v_sin,
                          dV_presente = (v_sin - v_pre) / v_sin,
                          dif_entre_semillas = v_pre - v_fut))
        end
    end
    return filas
end

"""
Datos causales de las dos variantes de semilla (sin modelo): fecha de conocimiento,
resistencia al grinding, unicidad por billete y circularidad.
"""
function datos_causales_semilla()
    return [
        (variante = "C-FLU-12 (vigente, D-F1=A)", ingrediente = "chunk(I_j) ‖ pot_output(I_j) = salida(f, s_j+D)",
         conocido_ancla_ajena = "al recibir el bloque I_j (≥ s_j): su cabecera ancla pot_output [C-POT-05]",
         conocido_ancla_propia = "cuando la frontera propia alcanza s_j+D (lead_h = D) [HIPOTESIS premisa 3]",
         grinding = "cerrado: ni hash de bloque, ni timestamp, ni padres, ni raíz entran en la entropía [C-FLU-12]",
         unicidad_billete = "NO distingue billete: dos copias del mismo chunk dan la misma entropía (coste declarado en C-FLU-12)",
         circularidad = "pot_output es salida FUTURA pero D < L ⇒ bien fundada; el contexto aporta la semilla, nunca el candidato [C-POT-06]"),
        (variante = "h.1 (candidata)", ingrediente = "chunk(I_j) ‖ salida(f, slot(I_j))",
         conocido_ancla_ajena = "al recibir el bloque I_j (≥ s_j)",
         conocido_ancla_propia = "cuando la frontera propia alcanza s_j (D/ρ antes que la variante vigente)",
         grinding = "mismo cierre mientras el ingrediente sea función de (f, slot) y del chunk",
         unicidad_billete = "igual: tampoco distingue billete",
         circularidad = "sin salida futura; el lookahead de R-FIN-14(f) está escrito sobre esta variante y no se rehízo con +D"),
    ]
end

"""
Compara espera REV-v1.0, líneas causales finitas y control ideal instantáneo.
`⌈Lrev/I⌉` cuenta capacidad para una cadena por época, no una salida anticipada.
"""
function tabla_regimenes(; L = 7200.0, W_dec = 20.0, D = 4.0, S_max = 150.0, rho = 2.5,
                         Is = (851.0, 4666.0), J = 1500)
    filas = NamedTuple[]
    for I in Is
        Lrev = L - S_max
        v_sin = vmax_det(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                  Lrev = Lrev, con_h = false), rho; J = J)
        v_mono = vmax_det(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                   Lrev = Lrev, con_h = true, revelacion_paralela = false), rho; J = J)
        v_par = vmax_det(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                  Lrev = Lrev, con_h = true, revelacion_paralela = true,
                                  lineas_revelacion = lineas_revelacion_por_epoca(Lrev, I)), rho; J = J)
        v_ideal = vmax_det(cfg_base(L = L, I = I, W_dec = W_dec, D = D, S_max = S_max,
                                    Lrev = Lrev, con_h = true,
                                    revelacion_instantanea = true), rho; J = J)
        push!(filas, (I = I, V_sin = v_sin, V_monolineal = v_mono, V_paralelo = v_par,
                      V_ideal = v_ideal,
                      reduccion_monolineal = (v_sin - v_mono) / v_sin,
                      reduccion_paralelo = (v_sin - v_par) / v_sin,
                      lineas_capacidad = lineas_revelacion_por_epoca(Lrev, I),
                      lineas_todos = lineas_revelacion_todos_candidatos(Lrev, I, S_max),
                      lineas_doble_chunk = lineas_revelacion_todos_candidatos(Lrev, I, S_max;
                                                                               variantes_chunk = 2),
                      lineas_timekeeper = lineas_timekeeper(L, I),
                      nucleos_verificador = nucleos_verificador(Lrev, I)))
    end
    return filas
end

"n* de rachas propias (ronda 10a §B.1.3) y tasa cerrada `α^(n*−1)`."
function tasa_rachas_cerrada(L::Real, I::Real, rho::Real, W_dec::Real, alpha::Real; off::Real = 0)
    rho <= 1 && return (n = typemax(Int), tasa = 0.0)
    x = ((L - W_dec + off) * rho / (rho - 1) - L) / I
    n = max(1, ceil(Int, x))
    return (n = n, tasa = alpha^(n - 1))
end

"""
Control negativo del §3: la tasa de rachas **no** es una media. Se mide la frecuencia
de épocas en que una racha de ≥ `n` anclas propias consecutivas está en curso, sobre
el proceso i.i.d. `Bernoulli(α)` (que es la fuente de aleatoriedad del modelo, premisa 9
de REV-v1.0), y se compara con la forma cerrada `α^(n−1)`.
"""
function control_rachas(L::Real, I::Real, rho::Real, W_dec::Real, alpha::Float64, J::Int,
                        R::Int, seed::UInt64)
    c = tasa_rachas_cerrada(L, I, rho, W_dec, alpha)
    c.n == typemax(Int) && return (n = c.n, cerrada = 0.0, medida = 0.0, k = 0, epocas = 0)
    total = 0; achats = 0
    for r in 1:R
        rng = StableRNG(seed + UInt64(r))
        racha = 0
        for _ in 1:J
            # `α^(n*−1)` es la probabilidad de que las n*−1 épocas ANTERIORES sean propias
            if racha >= c.n - 1
                achats += 1
            end
            total += 1
            if rand(rng) < alpha
                racha += 1
            else
                racha = 0
            end
        end
    end
    return (n = c.n, cerrada = c.tasa, medida = achats / total, k = achats, epocas = total)
end
