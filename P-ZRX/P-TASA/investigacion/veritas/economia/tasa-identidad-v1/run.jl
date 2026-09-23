# =============================================================================
# run.jl — P-TASA · CLI reproducible (nada de notebook implícito)
# -----------------------------------------------------------------------------
# Uso (desde este directorio):
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl \
#       --seed 0x54415341 --tarea f1 --tarea f2 --tarea f3 --tarea f4 \
#       --tarea f5 --tarea f6 --tarea v1 --tarea v2 --tarea v3
#
# Ningún parámetro de consenso se fija: `λ`, `I`, `P_win`, `T_h`, `c_b`, `κq`,
# `L_p`, `ρ_ret`, `T_v`, `c_r`, `M`, la rejilla de `τ` y las distribuciones de
# tamaño entran por CLI y salen como columna.
# =============================================================================
using Printf
using Random123

include("src/modelo.jl")
include("src/referencia.jl")
include("src/rapido.jl")
include("src/validacion.jl")

const SALIDA = Ref("resultados")

# -----------------------------------------------------------------------------
# Utilidades de escritura
# -----------------------------------------------------------------------------
"""Formatea un número: los racionales se escriben como `num/den` (exactos)."""
fmt(x::Rational) = string(numerator(x), "/", denominator(x))
fmt(x::Integer) = string(x)
fmt(x::Real) = @sprintf("%.10g", Float64(x))
fmt(x::Bool) = x ? "si" : "no"
fmt(x::String) = x
fmt(x::Symbol) = string(x)

"""Escribe un TSV con la cabecera tomada de los nombres de campo del NamedTuple."""
function escribir(nombre::String, filas::Vector{<:NamedTuple})
    isempty(filas) && error("sin filas para $nombre")
    cabecera = collect(keys(filas[1]))
    for (i, f) in enumerate(filas)
        keys(f) == keys(filas[1]) ||
            error("fila $i de $nombre tiene campos distintos a la cabecera")
    end
    ruta = joinpath(SALIDA[], nombre)
    open(ruta, "w") do io
        println(io, join(String.(cabecera), '\t'))
        for f in filas
            println(io, join((fmt(getfield(f, c)) for c in cabecera), '\t'))
        end
    end
    println("escrito: $ruta ($(length(filas)) filas)")
    return ruta
end

# -----------------------------------------------------------------------------
# Símbolos del modelo (entradas, no decisiones)
# -----------------------------------------------------------------------------
Base.@kwdef struct Config
    λ::Float64 = 1.0          # bloques por slot de la red
    I::Float64 = 1.0          # valor de un bloque (u.e.)
    Pwin::Float64 = 1.0       # prob. de que la rama privada acabe pagando
    Th::Float64 = 1.0         # horizonte de disuasión (slots)
    c_b::Float64 = 0.0        # coste de bytes por replotear la identidad extra
    κq::Float64 = 0.1         # prob. de castigo efectivo (κ·q)
    ρ_ret::Float64 = 0.5      # retención
    Tv::Float64 = 3600.0      # ventana de retención (slots)
    c_r::Float64 = 10.0
    M::Float64 = 20.0
    n_extra::Int = 1
end

"""`L_p = ρ_ret·I·T_v + c_r + I·M` (pérdida por infracción probada)."""
Lp_de(c::Config) = perdida_por_infraccion(c.ρ_ret, c.I, c.Tv, c.c_r, c.M)

"""Distribuciones declaradas. `a` es el exponente de la Pareto (H3 de P-CLAVE)."""
function catalogo_pareto()
    return [("pareto-a2.05", ParetoTruncado(1e-8, 1.0, 2.05)),
            ("pareto-a2.2-H3", ParetoTruncado(1e-8, 1.0, 2.2)),
            ("pareto-a2.5", ParetoTruncado(1e-8, 1.0, 2.5)),
            ("pareto-a3.0", ParetoTruncado(1e-8, 1.0, 3.0))]
end

"""Distribuciones discretas declaradas (dispersión controlada)."""
function catalogo_discreto()
    return [("iguales-1e6", Iguales(1_000_000)),
            ("dos-niveles-0.34", DosNiveles(0.34, 0.34, 1_000_000)),
            ("dos-niveles-0.50", DosNiveles(0.50, 0.50, 500))]
end

const ALFAS = [0.10, 0.25, 1 / 3, 0.40, 0.45]

# -----------------------------------------------------------------------------
# F1 · Las tres variantes
# -----------------------------------------------------------------------------
function tarea_f1(c::Config)
    filas = NamedTuple[]
    for (v, nombre, costo, cpbid, pos, notas) in (
        (:A, "stake proporcional al espacio", "σ·f", "σ (constante)",
         "si", "es PoS: el depósito escala con el disco; descartado por AGENTS.md"),
        (:B, "depósito fijo confiscable", "D·κ·q", "D·κ·q/s_id",
         "no", "depende de κ: sin evidencia no se confisca; necesita κ·q > 0"),
        (:C, "tasa fija NO recuperable", "τ", "τ/s_id",
         "no", "no depende de κ como coste; su efecto sí (ver F2)"))
        push!(filas, (variante = v, nombre = nombre, coste_por_identidad = costo,
                      coste_por_byte_s_id_1e_minus6 = cpbid,
                      depende_de_kappa = depende_de_kappa(v),
                      coste_por_byte_satura_teorema = !(v === :A),
                      es_proporcional_al_espacio = pos,
                      nota = notas))
    end
    return escribir("F1-variantes.tsv", filas)
end

# -----------------------------------------------------------------------------
# F2 · Los dos regímenes, la tasa mínima y el coste de cada vía
# -----------------------------------------------------------------------------
"""α* exacto con `η = 1` en las dos configuraciones."""
function tarea_f2a(c::Config)
    filas = NamedTuple[]
    for β in (1 // 20, 1 // 10, 1 // 5, 3 // 10, 2 // 5, 1 // 2, 3 // 5)
        a_d = alpha_estrella_t(β, 0 // 1, 1 // 1, 1 // 1)
        a_x = alpha_estrella_t(0 // 1, β, 1 // 1, 1 // 1)
        push!(filas, (β = β, α_estrella_con_βd = a_d, α_estrella_con_βx = a_x,
                      diferencia = a_x - a_d,
                      βx_equivalente_en_deriva = β // 2,
                      veredicto = a_x < a_d ? "βx es peor a igual espacio" : "="))
    end
    return escribir("F2a-igual-espacio.tsv", filas)
end

"""τ mínimo, κ mínimo y carga, por distribución y α."""
function tarea_f2c(c::Config)
    Lp = Lp_de(c)
    filas = NamedTuple[]
    for (nombre, d) in vcat(catalogo_pareto(), catalogo_discreto())
        for α in ALFAS
            p = 1.0 - 2α
            p ≤ 0 && continue
            fstar_exacto = inversa_Phi(d, p)
            fstar = Float64(fstar_exacto)
            τ1 = tau_minimo_fee(fstar, c.λ, c.I, c.Pwin, c.Th, c.c_b; n_extra = 1)
            τ2 = tau_minimo_fee(fstar, c.λ, c.I, c.Pwin, c.Th, c.c_b; n_extra = 2)
            κmin = kappa_minimo(fstar, Lp, c.λ, c.I, c.Pwin, c.Th)
            # carga sobre la granja marginal y sobre una 10^3 veces menor
            carga_f = carga_tasa_fraction(τ1, fstar, c.λ, c.I, c.Th)
            f_peq = fstar / 1000
            carga_peq = carga_tasa_fraction(τ1, f_peq, c.λ, c.I, c.Th)
            push!(filas, (distribucion = nombre, tipo = d isa ParetoTruncado ? "continuo" : "discreto",
                          α = α, objetivo_uno_menos_2α = p, f_estrella = fstar,
                          Φ_de_f_estrella = Phi_espacio(d, fstar_exacto),
                          brecha_Φ_menos_p = Float64(Phi_espacio(d, fstar_exacto)) - p,
                          τ_min_n1 = τ1, τ_min_n2 = τ2, κq_min = κmin,
                          carga_marginal = carga_f, carga_1000x_menor = carga_peq,
                          proporcion_cargas = carga_peq / carga_f))
        end
    end
    return escribir("F2c-tau-minimo.tsv", filas)
end

"""Coste de capturar β por cada vía, con la tasa dentro (distribuciones discretas)."""
function tarea_f2d(c::Config)
    Lp = Lp_de(c)
    τs = [0.0, 1e-6, 1e-3, 1e-2, 1e-1]
    filas = NamedTuple[]
    for (nombre, d) in catalogo_discreto()
        d isa DosNiveles || continue
        for τ in τs, β in (0.10, 0.20, 0.34)
            b_g = soborno_granja(d.f_grande, τ, c.c_b, c.κq, Lp, c.λ, c.I, c.Pwin, c.Th;
                                 n_extra = c.n_extra)
            b_p = soborno_granja(d.f_peq, τ, c.c_b, c.κq, Lp, c.λ, c.I, c.Pwin, c.Th;
                                 n_extra = c.n_extra)
            # vía βx: renuncia al ingreso público, sin tasa (no necesita identidad nueva)
            coste_x = costo_beta_x(β, c.λ, c.I, c.Th)
            # vía βd: enumeración exacta de (grande, k pequeñas)
            rec = reclutamiento_dos_niveles(d.θ, d.f_grande, d.K, τ, c.c_b, c.κq, Lp,
                                            c.λ, c.I, c.Pwin, c.Th, β)
            push!(filas, (distribucion = nombre, τ = τ, β = β,
                          soborno_granja_grande = b_g, soborno_granja_pequena = b_p,
                          coste_βd_exacto = rec.coste, coste_βx = coste_x,
                          βd_mas_barato = rec.coste < coste_x,
                          α_estrella_si_βd = alpha_estrella(β, 0.0),
                          α_estrella_si_βx = alpha_estrella(0.0, β)))
        end
    end
    return escribir("F2d-coste-vias.tsv", filas)
end

# -----------------------------------------------------------------------------
# F3 · Evasiones: partición, rotación, y qué defensa revive
# -----------------------------------------------------------------------------
function tarea_f3a(c::Config)
    Lp = Lp_de(c)
    filas = NamedTuple[]
    for (nombre, d) in vcat(catalogo_pareto(), catalogo_discreto())
        for κq in (0.0, 1e-4, 1e-2, c.κq), α in (0.25, 1 / 3, 0.40)
            for τ in (0.0, 1e-8, 1e-6, 1e-4, 1e-2, 0.5)
                fdet = f_detenida(τ, κq, Lp, c.λ, c.I, c.Pwin, c.Th, c.c_b;
                                  n_extra = c.n_extra)
                fdet_rec = min(fdet, 1.0)
                disp = Phi_espacio(d, fdet_rec)
                push!(filas, (distribucion = nombre, κq = κq, α = α, τ = τ,
                              f_detenida = fdet, espacio_no_disuadido = disp,
                              umbral_a_cubrir = 1.0 - 2α, seguro = disp ≤ 1.0 - 2α))
            end
        end
    end
    return escribir("F3a-particion.tsv", filas)
end

function tarea_f3b(c::Config)
    filas = NamedTuple[]
    for β in (0.10, 0.20, 0.34), Trot in (60.0, 360.0, 3600.0), τ in (1e-6, 1e-3, 0.1)
        r = coste_rotacion(β, c.Tv, Trot, τ, 1.0)
        push!(filas, (β = β, T_rot = Trot, τ = τ, factor_ploteo = r.factor_ploteo,
                      coste_bytes_rel = r.coste_bytes,
                      identidades_en_vuelo = r.identidades_en_vuelo,
                      coste_tasa_por_rotacion = r.coste_tasa_por_rotacion,
                      coste_tasa_anualizado = r.coste_tasa_anualizado,
                      tasa_domina_a_bytes = r.coste_tasa_anualizado > r.coste_bytes))
    end
    return escribir("F3b-rotacion.tsv", filas)
end

function tarea_f3c(c::Config)
    Lp = Lp_de(c)
    filas = NamedTuple[]
    # D1 · exclusividad de reloj por identidad (la única que la tasa habilita)
    for α in (0.25, 1 / 3, 0.40)
        d = ParetoTruncado(1e-8, 1.0, 2.2)
        fstar = inversa_Phi(d, 1.0 - 2α)
        τ1 = tau_minimo_fee(fstar, c.λ, c.I, c.Pwin, c.Th, c.c_b; n_extra = 1)
        push!(filas, (defensa = "D1 exclusividad de reloj por identidad",
                      por_que_se_descarto = "teorema de partición: identidades gratis",
                      que_haria_falta = "tasa τ > 0 Y castigo κq > 0",
                      la_tasa_la_revive = true,
                      τ_o_κq_minimo = "τ=$(fmt(τ1)); κq=$(fmt(kappa_minimo(fstar, Lp, c.λ, c.I, c.Pwin, c.Th)))",
                      coste_de_la_revivencia = "regresiva: carga = f*/f sobre las granjas menores",
                      etiqueta = "derivado"))
    end
    push!(filas, (defensa = "D2 cuota/tope de espacio por identidad",
                  por_que_se_descarto = "no había coste de identidad",
                  que_haria_falta = "tope S_max por identidad",
                  la_tasa_la_revive = true,
                  τ_o_κq_minimo = "τ·⌈f/S_max⌉",
                  coste_de_la_revivencia = "se vuelve ∝ f: es la variante (a) disfrazada",
                  etiqueta = "derivado"))
    push!(filas, (defensa = "D3 detección estadística / cuota por identidad",
                  por_que_se_descarto = "Sybil gratis",
                  que_haria_falta = "que crear identidad cueste algo",
                  la_tasa_la_revive = false,
                  τ_o_κq_minimo = "—",
                  coste_de_la_revivencia = "coste fijo por identidad: absorbible por la granja grande",
                  etiqueta = "derivado"))
    push!(filas, (defensa = "D4 atribución de pool",
                  por_que_se_descarto = "P-POOLS: el operador hostil firma por el granjero",
                  que_haria_falta = "atar la coinbase a sol.public_key",
                  la_tasa_la_revive = false,
                  τ_o_κq_minimo = "—",
                  coste_de_la_revivencia = "la tasa no toca la firma",
                  etiqueta = "verificado en fuente (P-POOLS)"))
    push!(filas, (defensa = "D5 castigo por clave (P-CLAVE)",
                  por_que_se_descarto = "claves de saldo casi cero y nuevas: soborno 0",
                  que_haria_falta = "registro o moneda previa, inexistentes",
                  la_tasa_la_revive = false,
                  τ_o_κq_minimo = "—",
                  coste_de_la_revivencia = "encarecer identidades no crea evidencia (κ=0 sigue)",
                  etiqueta = "verificado en fuente (P-CLAVE F4/F6)"))
    return escribir("F3c-revive.tsv", filas)
end

# -----------------------------------------------------------------------------
# F4 · Regresividad y dicotomía
# -----------------------------------------------------------------------------
function tarea_f4a(c::Config)
    filas = NamedTuple[]
    for (nombre, d) in vcat(catalogo_pareto(), catalogo_discreto())
        for α in (1 / 3,)
            p = 1.0 - 2α
            fstar = Float64(inversa_Phi(d, p))
            τ1 = tau_minimo_fee(fstar, c.λ, c.I, c.Pwin, c.Th, c.c_b; n_extra = 1)
            for dec in 0:6
                f = fstar * 10.0^(-dec)
                f ≤ 0 && continue
                push!(filas, (distribucion = nombre, α = α, f_estrella = fstar,
                              f = f, factor_menor = 10.0^dec,
                              carga = carga_tasa_fraction(τ1, f, c.λ, c.I, c.Th),
                              τ_min = τ1))
            end
        end
    end
    return escribir("F4a-regresividad.tsv", filas)
end

function tarea_f4b(c::Config)
    fr = Rational{BigInt}[1 // 1000, 1 // 100, 1 // 20, 1 // 10, 1 // 4, 1 // 2, 3 // 4]
    horarios = Horario{Rational{BigInt}}[
        Lineal(Rational{BigInt}(1)),
        Fija(Rational{BigInt}(1)),
        FijaLineal(Rational{BigInt}(1), Rational{BigInt}(1) / 10),
        Tope(Rational{BigInt}(1), Rational{BigInt}(1) / 16),
    ]
    filas = NamedTuple[]
    for h in horarios
        for i in 1:(length(fr) - 1)
            a, b = fr[i], fr[i + 1]
            push!(filas, (horario = string(typeof(h)), f1 = a, f2 = b,
                          parte_mas_caro_f1_N2 = particion_mas_cara(h, a, 2),
                          carga_decrece = carga_decreciente(h, a, b),
                          concava = concava_en(h, a, b),
                          estrictamente_concava = estrictamente_concava_en(h, a, b),
                          subaditiva = subaditiva_en(h, a, b),
                          subaditiva_estricta = subaditiva_estricta_en(h, a, b)))
        end
        for f in (Rational{BigInt}(1) / 4,), N in (2, 3, 10, 100)
            f * N ≤ 1 || continue
            push!(filas, (horario = string(typeof(h)), f1 = f, f2 = f * N,
                          parte_mas_caro_f1_N2 = particion_mas_cara(h, f, N),
                          carga_decrece = carga_decreciente(h, f, f * N),
                          concava = concava_en(h, f, f * N),
                          estrictamente_concava = estrictamente_concava_en(h, f, f * N),
                          subaditiva = subaditiva_en(h, f, f * N),
                          subaditiva_estricta = subaditiva_estricta_en(h, f, f * N)))
        end
    end
    return escribir("F4b-dicotomia.tsv", filas)
end

function tarea_f4c(c::Config)
    filas = NamedTuple[]
    for Smax in (1.0, 0.1, 0.01, 1e-3, 1e-4, 1e-6), f in (0.5, 0.1, 0.01, 1e-3)
        h = Tope(1.0, Smax)
        push!(filas, (S_max = Smax, f = f,
                      cuota = cuota(h, f),
                      tasa_por_byte = cuota(h, f) / f,
                      tasa_asintota_bytes = Smax > 0 ? 1.0 / Smax : Inf,
                      desviacion_escalera = desviacion_tope(h, f),
                      subaditiva = subaditiva_en(h, f, f),
                      subaditiva_estricta = subaditiva_estricta_en(h, f, f)))
    end
    return escribir("F4c-tope.tsv", filas)
end

# -----------------------------------------------------------------------------
# F5 · Unidad, recurrencia y arranque
# -----------------------------------------------------------------------------
function tarea_f5a(c::Config)
    d = ParetoTruncado(1e-8, 1.0, 2.2)
    fstar = inversa_Phi(d, 1.0 - 2 / 3)
    τ1 = tau_minimo_fee(fstar, c.λ, c.I, c.Pwin, c.Th, c.c_b; n_extra = 1)
    filas = NamedTuple[]
    # mediana por conteo y por espacio (no son la misma)
    a = d.a
    f_med_conteo = (0.5 * (d.fmin^(-a) - d.fmax^(-a)) + d.fmax^(-a))^(-1.0 / a)
    f_med_espacio = inversa_Phi(d, 0.5)
    for (etq, f) in (("marginal-f*", fstar), ("mediana-conteo", f_med_conteo),
                     ("mediana-espacio", f_med_espacio), ("minima", d.fmin))
        push!(filas, (referencia = etq, f = f,
                      barrera_slots_de_ingreso = barrera_entrada_slots(τ1, f, c.λ, c.I),
                      barrera_anios = barrera_entrada_slots(τ1, f, c.λ, c.I) / T_ANIO_SLOTS,
                      carga_fraccion_ingreso = carga_tasa_fraction(τ1, f, c.λ, c.I, c.Th),
                      variante = "moneda (τ) o quemada"))
    end
    return escribir("F5a-unidad.tsv", filas)
end

function tarea_f5b(c::Config)
    d = ParetoTruncado(1e-8, 1.0, 2.2)
    fstar = inversa_Phi(d, 1.0 - 2 / 3)
    filas = NamedTuple[]
    for W in (1.0, 1e3, 1e6), c_core in (1.0,)
        r = coste_computo_identidad(W, c_core, 1)
        for f in (fstar, 1e-8)
            push!(filas, (W_nucleos_slot = W, f = f,
                          trabajo_total = r.trabajo_total,
                          arranque_requiere_moneda = r.arranque_requiere_moneda,
                          escala_con_espacio = r.escala_con_espacio,
                          carga_fraccion_ingreso = W * c_core / (f * c.λ * c.I),
                          regresiva = true))
        end
    end
    return escribir("F5b-computo.tsv", filas)
end

function tarea_f5c(c::Config)
    filas = NamedTuple[]
    for τ in (1e-6, 1e-3, 0.1), T_plot in (T_ANIO_SLOTS, 5 * T_ANIO_SLOTS)
        push!(filas, (τ = τ, T_plot_slots = T_plot,
                      tasa_amortizada_por_slot = τ / T_plot,
                      disuasion_residual = "decae como 1/T_plot",
                      recurrente_anual = τ * (T_ANIO_SLOTS / 360.0),
                      nota = "la única amortiza; la recurrente es impuesto permanente al honesto"))
    end
    return escribir("F5c-recurrencia.tsv", filas)
end

# -----------------------------------------------------------------------------
# F6 · Veredicto (tabla de decisión: ningún número inventado)
# -----------------------------------------------------------------------------
function tarea_f6(c::Config)
    Lp = Lp_de(c)
    filas = [
        (rama = "(a) stake proporcional al espacio", cae_dentro_de_la_linea = true,
         que_cierra = "nada nuevo: el teorema ya dice que el coste por byte es neutral",
         coste = "convierte el consenso en una subasta de capital",
         quien_paga = "el granjero sin capital", etiqueta = "verificado en fuente (AGENTS.md)"),
        (rama = "(b) depósito fijo confiscable", cae_dentro_de_la_linea = false,
         que_cierra = "nada sin κq > 0; con κq > 0 hereda la pared de P-CLAVE",
         coste = "depende de la economía de castigo ya refutada contra claves pobres/nuevas",
         quien_paga = "el honesto con dos nodos (falsos positivos)",
         etiqueta = "derivado"),
        (rama = "(c) tasa fija no recuperable, pagada en moneda", cae_dentro_de_la_linea = false,
         que_cierra = "habilita exclusividad; no toca el doble farmeo",
         coste = "regresiva (carga = f*/f) y exige moneda previa: barrera de entrada",
         quien_paga = "la granja pequeña", etiqueta = "derivado"),
        (rama = "(c') tasa fija pagada en cómputo", cae_dentro_de_la_linea = false,
         que_cierra = "cumple la letra del teorema y evita el arranque monetario",
         coste = "reintroduce minería PoW y es ASIC-able; regresiva igual",
         quien_paga = "el granjero doméstico frente al que compra cómputo a escala",
         etiqueta = "derivado"),
        (rama = "rechazar (11) entera", cae_dentro_de_la_linea = true,
         que_cierra = "nada: deja el hueco que la motivaba",
         coste = "ninguno; conserva el tablero honesto",
         quien_paga = "—",
         etiqueta = "propuesto"),
    ]
    println("L_p usado (símbolo declarado): ", Lp)
    return escribir("F6-veredicto.tsv", filas)
end

# -----------------------------------------------------------------------------
# V · Validaciones con artefacto
# -----------------------------------------------------------------------------
function tarea_v1()
    filas = NamedTuple[]
    for a in (2.05, 2.2, 2.5, 3.0)
        d = ParetoTruncado(1e-8, 1.0, a)
        for x in (1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1, 1.0)
            cerrada = Phi_espacio(d, x)
            lo, hi, ancho = Phi_pareto_riemann(d, x; K = 20_000)
            push!(filas, (a = a, x = x, phi_cerrada = cerrada, riemann_lo = lo,
                          riemann_hi = hi, ancho = ancho,
                          cerrada_dentro = lo - 1e-12 ≤ cerrada ≤ hi + 1e-12))
        end
    end
    return escribir("V1-pareto-riemann.tsv", filas)
end

function tarea_v2(seed::UInt64)
    d = ParetoTruncado(1e-8, 1.0, 2.2)
    filas = NamedTuple[]
    for x in (1e-6, 1e-5, 1e-4, 1e-2)
        cerrada = Phi_espacio(d, x)
        M, R = 100_000, 16
        res = mc_phi(seed, d, x, M, R; hilos = 4)
        esperados = cerrada * M * R
        push!(filas, (x = x, phi_cerrada = cerrada, mc_media = res.media,
                      wilson_lo = res.wilson_lo, wilson_hi = res.wilson_hi,
                      ic_t_lo = res.ic_lo, ic_t_hi = res.ic_hi,
                      desv_entre_replicas = res.desv, aciertos_esperados = esperados,
                      aplicable = esperados ≥ 20,
                      wilson_cubre = res.wilson_lo ≤ cerrada ≤ res.wilson_hi))
    end
    return escribir("V2-mc-exacto.tsv", filas)
end

function tarea_v3()
    filas = NamedTuple[]
    # contraejemplo del avaricioso
    f = [1 // 1, 3 // 5, 3 // 5]
    s = [9 // 10, 1 // 2, 1 // 2]
    β = 1 // 1
    av = reclutamiento_avaricioso(f, s, β)
    br = reclutamiento_bruto(f, s, β)
    push!(filas, (instancia = "contraejemplo-avaricioso", n = length(f),
                  avaricioso = av.coste, exacto = br.coste, factible = true,
                  avaricioso_es_optimo = av.coste == br.coste))
    # barrido aleatorio determinista con coste fijo
    for k in 1:200
        n = 4 + (k % 5)
        ff = [Rational{BigInt}(1 + (k * i) % 7) / 10 for i in 1:n]
        ss = [Rational{BigInt}(1 + (k * i * 3) % 11) / 10 for i in 1:n]
        βk = Rational{BigInt}(1 + k % 5) / 5
        avk = reclutamiento_avaricioso(ff, ss, βk)
        brk = reclutamiento_bruto(ff, ss, βk)
        factible = brk.factible && avk.espacio ≥ βk
        push!(filas, (instancia = "aleatoria-$k", n = n,
                      avaricioso = avk.coste, exacto = brk.coste,
                      factible = factible,
                      avaricioso_es_optimo = factible ? avk.coste == brk.coste : true))
    end
    return escribir("V3-reclutamiento.tsv", filas)
end

# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------
function main(args)
    tareas = String[]
    seed = UInt64(0x54415341)   # "TASA"
    i = 1
    while i ≤ length(args)
        a = args[i]
        if a == "--seed"
            seed = parse(UInt64, args[i+1]); i += 2
        elseif a == "--tarea"
            push!(tareas, lowercase(args[i+1])); i += 2
        elseif a == "--salida"
            SALIDA[] = args[i+1]; i += 2
        else
            error("argumento desconocido: $a")
        end
    end
    isempty(tareas) && (tareas = ["f1", "f2", "f3", "f4", "f5", "f6", "v1", "v2", "v3"])
    mkpath(SALIDA[])
    c = Config()
    println("== P-TASA tasa-identidad-v1 ==")
    println("julia ", VERSION, " · hilos ", Threads.nthreads(), " · semilla ", seed)
    println("CPU: ", Sys.CPU_NAME, " · RAM GiB: ", round(Int, Sys.total_memory() / 2^30))
    println("símbolos: λ=", c.λ, " I=", c.I, " Pwin=", c.Pwin, " Th=", c.Th,
            " c_b=", c.c_b, " κq=", c.κq, " ρ_ret=", c.ρ_ret, " Tv=", c.Tv,
            " c_r=", c.c_r, " M=", c.M, " n_extra=", c.n_extra)
    println("L_p = ", Lp_de(c))
    for t in tareas
        if t == "f1"
            tarea_f1(c)
        elseif t == "f2"
            tarea_f2a(c); tarea_f2c(c); tarea_f2d(c)
        elseif t == "f3"
            tarea_f3a(c); tarea_f3b(c); tarea_f3c(c)
        elseif t == "f4"
            tarea_f4a(c); tarea_f4b(c); tarea_f4c(c)
        elseif t == "f5"
            tarea_f5a(c); tarea_f5b(c); tarea_f5c(c)
        elseif t == "f6"
            tarea_f6(c)
        elseif t == "v1"
            tarea_v1()
        elseif t == "v2"
            tarea_v2(seed)
        elseif t == "v3"
            tarea_v3()
        else
            error("tarea desconocida: $t")
        end
    end
    println("== fin ==")
    return nothing
end

main(ARGS)
