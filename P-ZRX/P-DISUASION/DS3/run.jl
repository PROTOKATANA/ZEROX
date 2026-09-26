#!/usr/bin/env julia
# =============================================================================
# DS-3 · run.jl — Calculadora y Monte Carlo del coste mínimo de los ataques.
#
# Comando reproducible:
#   JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia" \
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     julia --project=. --threads=4,0 run.jl --seed 0x5a5a --reps 20000
#
# Presupuesto de la orden DS-3: 2 h, 4 hilos, 8 GiB de RAM, 256 MiB de disco.
# Si se agota: estado INCONCLUSO, sin convertir un timeout en un resultado negativo.
# =============================================================================

using DS3
using Printf

const DIR_RES = joinpath(@__DIR__, "resultados")
mkpath(DIR_RES)

# ───────────────────────────────────────────── CLI mínima y reproducible

function parsear_args(args)
    opciones = Dict{String,String}("seed" => "0x5a5a", "reps" => "20000",
                                   "escenarios" => joinpath(@__DIR__, "escenarios.tsv"),
                                   "objetivo" => "")
    i = 1
    while i <= length(args)
        a = args[i]
        if startswith(a, "--")
            clave = a[3:end]
            if i < length(args) && !startswith(args[i + 1], "--")
                opciones[clave] = args[i + 1]
                i += 2
            else
                opciones[clave] = "true"
                i += 1
            end
        else
            i += 1
        end
    end
    return opciones
end

const OPC = parsear_args(ARGS)
const SEMILLA = parse(UInt64, OPC["seed"] == "" ? "0x5a5a" : OPC["seed"])
const REPS = parse(Int, OPC["reps"])

# ───────────────────────────────────────────── lectura de escenarios.tsv

"""
    leer_escenarios(ruta) -> (valores, filas)

Lee el TSV de parámetros. Cada fila lleva `clave, valor, unidad, etiqueta, procedencia,
barrido`. Falla si falta una clave obligatoria: el modelo no inventa un número ausente.
"""
function leer_escenarios(ruta)
    valores = Dict{String,Float64}()
    filas = Vector{Vector{String}}()
    for linea in eachline(ruta)
        s = strip(linea)
        (isempty(s) || startswith(s, "#") || startswith(s, "clave\t")) && continue
        campos = split(linea, '\t')
        length(campos) < 6 && continue
        clave = String(campos[1]); valor = String(campos[2])
        push!(filas, [String(c) for c in campos[1:6]])
        valores[clave] = parse(Float64, valor)
    end
    return valores, filas
end

const ESC, FILAS_ESC = leer_escenarios(OPC["escenarios"])
obligatorias = ["alpha", "beta_d", "F_slots", "T_v", "rho_ret", "kappa", "q_gana", "I", "c_r",
                "M", "V", "N_recl", "nu", "q_garantia", "tipo_interes", "f_media", "eps_saldo",
                "dist_f_min", "dist_alpha", "w_sin_vdf", "N_TiB", "k_auditoria", "D_a",
                "r_maquina", "t_unidad", "t_M3", "pi_DAG", "N_h_20TB", "eps_honesto",
                "vatio_nucleo", "vatio_TiB", "nucleos_por_farmer_slot", "P_objetivo"]
for k in obligatorias
    haskey(ESC, k) || error("falta la clave de escenario obligatoria `$k` en $(OPC["escenarios"])")
end
p(k) = ESC[k]

# ───────────────────────────────────────────── escritura CSV

function escribir_csv(nombre, cabecera, filas)
    ruta = joinpath(DIR_RES, nombre)
    limpia(s) = replace(string(s), "," => ";")
    open(ruta, "w") do io
        println(io, join(limpia.(cabecera), ","))
        for f in filas
            println(io, join(limpia.(f), ","))
        end
    end
    return ruta
end

fmt(x; d = 6) = @sprintf("%.*g", d, x)

function fila(io, campos...)
    println(io, join(campos, ","))
end

# =============================================================================
# 1 · Los siete casos de comprobación de MODELO §4
# =============================================================================

function tabla_comprobaciones()
    filas = Vector{Vector{String}}()
    r = Reparto(p("alpha"), 0.0)
    P = primera_dp(p_de_alpha(r), deficit_entero(r, 1019), 1019).paso
    push!(filas, ["§4.2 P(F=1019,α=0.33,βd=0)", fmt(P; d = 12), "9.75e-108", "exacto DP",
                  "H-PUENTE"])
    normal = p_saldo_cero_normal(0.36)
    push!(filas, ["§4.3 P(B=0) θ=0.36", fmt(exp(-0.36); d = 10), "0.69768", "exacto Poisson",
                  "—"])
    push!(filas, ["§4.3 normal (delator)", fmt(normal; d = 10), "0.3017", "aproximación",
                  "no decide"])
    B3600 = masa_espacio_bajo_b(Pareto(p("dist_f_min"), p("dist_alpha")), p("eps_saldo"), 1.0, 3600.0)
    B100k = masa_espacio_bajo_b(Pareto(p("dist_f_min"), p("dist_alpha")), p("eps_saldo"), 1.0, 100000.0)
    push!(filas, ["§4.4 B(ε=0.01, Tv=3600)", fmt(B3600; d = 6), "0.675", "derivado H3", "grieta SÍ"])
    push!(filas, ["§4.4 B(ε=0.01, Tv=1e5)", fmt(B100k; d = 6), "0.369", "derivado H3", "grieta NO (heredado)"])
    t = TablaLogFact(Int(p("N_TiB")))
    det670 = cola_hiper_rapida(t, Int(p("N_TiB")), 189_670, 1_000_000, 181_092)
    det671 = cola_hiper_rapida(t, Int(p("N_TiB")), 189_671, 1_000_000, 181_092)
    push!(filas, ["§4.5 detección M=189670 k=1e6", fmt(det670; d = 6), "0.0098712", "exacto-redondeado", "k>B"])
    push!(filas, ["§4.5 detección M=189671 k=1e6", fmt(det671; d = 6), "0.010181", "exacto-redondeado", "k>B"])
    w_eq = w_equilibrio(p("N_h_20TB"), R_24H, 1.0)
    push!(filas, ["§4.6 w_equilibrio 20 TB", fmt(w_eq; d = 6), "7.6e5", "derivado", "disco 20 TB"])
    push!(filas, ["§4.6 núcleos/TiB w=7175", fmt(nucleos_por_TiB(7175.0); d = 6), "117.238",
                  "derivado", "65 W/núcleo"])
    bp = pasos_bp(2.0, 0.01, 4.0)
    push!(filas, ["§4.7 Baig–Pietrzak total", string(bp.total), "1233+140 [sic]",
                  "fórmula MODELO §2.11", "reserva F7"])
    return escribir_csv("comprobaciones.csv",
        ["caso", "valor", "esperado", "via", "etiqueta"], filas)
end

# =============================================================================
# 2 · A1 · doble farmeo — coste mínimo para una probabilidad de éxito
# =============================================================================

const ALPHAS = [0.20, 0.33, 0.40]
const FS = [1019]                 # F=3600 sólo en el barrido de monotonía (coste DP alto)
const PS = [1e-6, 1e-3, 0.5]

"""
    coste_A1(α, F, P_obj) -> NamedTuple

Coste del candidato M3+M5 (retención por saldo + castigo con evidencia) para lograr
`P_first_passage ≥ P_obj`, en B0, B1 y con el candidato, por reclutado (u.e.).
`β_d` mínimo por bisección sobre la DP certificada.
"""
function coste_A1(α, F, P_obj)
    dist = Pareto(p("dist_f_min"), p("dist_alpha"))
    ret = Retencion(p("rho_ret"), p("T_v"))
    B_eps = masa_espacio_bajo_b(dist, p("eps_saldo"), p("lambda"), p("T_v"))
    coef = coef_reclutamiento(ret, p("I"), p("lambda"))
    bm = beta_minimo_para_p(α, F, P_obj)
    βd = bm.βd
    isnan(βd) && return (βd = NaN, P = bm.P, C_total = Inf, C_per = Inf, N_recl = 0,
                         B0 = 0.0, B1 = Inf, honesto = Inf, ratio = Inf, bribe = Inf)
    N_recl = max(1, ceil(Int, βd / p("f_media")))
    C_total = coste_reclutamiento(βd, B_eps, coef)
    C_per = C_total / N_recl
    # Soborno por reclutado del candidato M3+M5 (P-PRESTAMO §3.2)
    bribe = soborno_necesario(p("kappa"), p("q_gana"),
                              perdida_por_reclutado(ret, p("I"), p("c_r"), p("M")))
    # B1 (M1+M2+M5 sin castigo): solo inmovilización de la garantía mínima por identidad
    horas = F * TAU_S / 31536000.0
    B1_per = p("tipo_interes") * p("q_garantia") * horas
    # Honesto: pérdida esperada por castigo accidental + inmovilización de su garantía
    honesto = p("eps_honesto") * (p("rho_ret") * p("I") * p("T_v") + p("c_r") + p("I") * p("M")) +
              p("tipo_interes") * p("q_garantia") * horas
    ratio = honesto > 0 ? C_per / honesto : Inf
    return (βd = βd, P = bm.P, C_total = C_total, C_per = C_per, N_recl = N_recl,
            B0 = 0.0, B1 = B1_per, honesto = honesto, ratio = ratio, bribe = bribe)
end

"""
    sensibilidad_A1(βd) -> (dominante, tabla)

Sensibilidad uno-a-uno del coste de reclutamiento `C(β_d)` (o de `B(ε)` si `C = 0`) a los
parámetros del modelo de retención, en los extremos declarados del §3. No re-biseca: usa el
`β_d` ya obtenido.
"""
function sensibilidad_A1(βd)
    B_eps = masa_espacio_bajo_b(Pareto(p("dist_f_min"), p("dist_alpha")), p("eps_saldo"),
                                p("lambda"), p("T_v"))
    coef = coef_reclutamiento(Retencion(p("rho_ret"), p("T_v")), p("I"), p("lambda"))
    base = coste_reclutamiento(βd, B_eps, coef)
    # Si la grieta hace el coste 0, la sensibilidad se mide sobre el umbral B(ε) que la produce,
    # NUNCA mezclando unidades de coste y de fracción de espacio.
    en_grieta = base == 0
    base_metrica = en_grieta ? B_eps : base
    variaciones = [
        ("ρ_ret", [0.10, 1.00]), ("T_v", [1000.0, 100000.0]), ("ε_saldo", [0.001, 0.01]),
        ("λ", [0.5, 2.0]), ("I", [0.5, 2.0]), ("dist_alpha", [2.05, 3.0]),
    ]
    tabla = Vector{Vector{String}}()
    dominante = ("—", 0.0)
    for (nombre, extremos) in variaciones
        peor = 0.0
        for x in extremos
            ρr = nombre == "ρ_ret" ? x : p("rho_ret")
            tv = nombre == "T_v" ? x : p("T_v")
            εs = nombre == "ε_saldo" ? x : p("eps_saldo")
            ll = nombre == "λ" ? x : p("lambda")
            ii = nombre == "I" ? x : p("I")
            da = nombre == "dist_alpha" ? x : p("dist_alpha")
            Be = masa_espacio_bajo_b(Pareto(p("dist_f_min"), da), εs, ll, tv)
            cf = coef_reclutamiento(Retencion(ρr, tv), ii, ll)
            v = coste_reclutamiento(βd, Be, cf)
            metrica = en_grieta ? Be : v
            peor = max(peor, abs(metrica - base_metrica) / max(base_metrica, 1e-300))
        end
        push!(tabla, [nombre, fmt(peor; d = 4), fmt(base; d = 6), fmt(B_eps; d = 6)])
        peor > dominante[2] && (dominante = (nombre, peor))
    end
    return (dominante = dominante, tabla = tabla, en_grieta = en_grieta)
end

function tabla_ataque_A1()
    filas = Vector{Vector{String}}()
    sens_filas = Vector{Vector{String}}()
    for α in ALPHAS, F in FS, P_obj in PS
        c = coste_A1(α, F, P_obj)
        sens = isnan(c.βd) ? nothing : sensibilidad_A1(c.βd)
        dom = sens === nothing ? ("—", 0.0) : sens.dominante
        grieta = sens === nothing ? false : sens.en_grieta
        nota = grieta ? "grieta B(ε)≥β_d: coste 0; domina el umbral B(ε)" : "coste > 0"
        push!(filas, [fmt(α; d = 3), string(F), fmt(P_obj; d = 3), fmt(c.βd; d = 6),
                      fmt(c.P; d = 6), string(c.N_recl), fmt(c.C_total; d = 6),
                      fmt(c.C_per; d = 6), fmt(c.bribe; d = 6), fmt(c.B0; d = 6),
                      fmt(c.B1; d = 6), fmt(c.honesto; d = 6), fmt(c.ratio; d = 6), dom[1],
                      "condicionado H-PUENTE; " * nota])
        push!(sens_filas, [fmt(α; d = 3), string(F), fmt(P_obj; d = 3), dom[1],
                           fmt(dom[2]; d = 4), fmt(c.C_per; d = 6), grieta ? "SÍ" : "NO"])
    end
    escribir_csv("ataque-A1-doble-farmeo.csv",
        ["alpha", "F_slots", "P_objetivo", "beta_d_min", "P_alcanzada", "N_recl",
         "C_candidato_M3M5_total_ue", "C_candidato_por_reclutado_ue", "soborno_por_reclutado_ue",
         "C_B0_ue", "C_B1_ue", "C_honesto_ue", "cociente_X_honesto", "param_dominante",
         "etiqueta"], filas)
    escribir_csv("sensibilidad-A1.csv",
        ["alpha", "F_slots", "P_objetivo", "param_dominante", "cambio_relativo",
         "C_por_reclutado_ue", "en_grieta"], sens_filas)
end

# =============================================================================
# 3 · A3 · sembrador — coste de cobertura y detección
# =============================================================================

function tabla_ataque_A3()
    filas = Vector{Vector{String}}()
    N = Int(p("N_TiB"))
    t = TablaLogFact(N)
    phi_tramposo = 0.80                     # escenario declarado: el tramposo almacena el 80 %
    M = max(0, min(N, round(Int, (1 - phi_tramposo) * N)))
    for w in [p("w_sin_vdf"), 8030.0, p("w_con_vdf")]
        B = floor(Int, B_unidades(p("r_maquina"), 1.0, w, TAU_S, p("D_a")))
        nuc = nucleos_por_TiB(w, p("t_unidad"), TAU_S, p("D_a"))
        maq = maquinas_por_TiB(w, p("r_maquina"), TAU_S, p("D_a"))
        e_reg = energia_regenerar_kWh(w, p("vatio_nucleo"), p("t_unidad"), TAU_S, p("D_a"))
        e_alm = energia_almacenar_kWh(w, p("vatio_TiB"), TAU_S, p("D_a"))
        for k in [1_000, 100_000, 1_000_000]
            af = almacenamiento_forzado(N, B, k)
            det = k > B ? cola_hiper_rapida(t, N, M, k, B) : 0.0
            push!(filas, [fmt(w; d = 6), string(B), string(k), fmt(af; d = 6),
                          fmt(phi_tramposo; d = 3), string(M), fmt(det; d = 6),
                          fmt(nuc; d = 4), fmt(maq; d = 4), fmt(e_reg; d = 6),
                          fmt(e_alm; d = 8), fmt(razon_energia(w); d = 6),
                          k > B ? "Ee coste / Ec detección (k>B)" : "Ee coste / detección CERO (k≤B)",
                          "condicionado k>B; regeneración medida P-INTENTO"])
        end
    end
    escribir_csv("ataque-A3-sembrador.csv",
        ["w_slots", "B_unidades", "k_auditoria", "almacenamiento_forzado", "phi_almacenado",
         "M_omitido", "deteccion", "nucleos_por_TiB", "maquinas_por_TiB",
         "kWh_regenerar_TiB_ventana", "kWh_almacenar_TiB_ventana", "razon_regenerar_almacenar",
         "veredicto", "etiqueta"], filas)
end

# =============================================================================
# 4 · A4 · Sybil — coste por identidad (regresivo)
# =============================================================================

function tabla_ataque_A4()
    filas = Vector{Vector{String}}()
    for q in [100.0, 1000.0, 10000.0], f in [1e-6, 1e-3, 1e-1]
        ingreso_semanal = f * p("lambda") * p("I") * 7 * 86400.0
        push!(filas, [fmt(q; d = 6), fmt(f; d = 6), fmt(coste_identidades(q, 1.0); d = 6),
                      fmt(coste_por_byte(q, f); d = 6),
                      fmt(fraccion_ingreso(q, ingreso_semanal); d = 6),
                      "Ee exigible; regresivo (P-TASA F4)"])
    end
    escribir_csv("ataque-A4-sybil.csv",
        ["q_garantia_ue", "f_fraccion_clave", "coste_por_identidad_ue", "coste_por_byte_ue",
         "fraccion_ingreso_semanal", "etiqueta"], filas)
end

# =============================================================================
# 4b · A2 · equivocación publicada — κ escalonado (MODELO §2.6)
# =============================================================================

function tabla_ataque_A2()
    filas = Vector{Vector{String}}()
    ret = Retencion(p("rho_ret"), p("T_v"))
    perdida = perdida_por_reclutado(ret, p("I"), p("c_r"), p("M"))
    B_eps = masa_espacio_bajo_b(Pareto(p("dist_f_min"), p("dist_alpha")), p("eps_saldo"),
                                p("lambda"), p("T_v"))
    coef = coef_reclutamiento(ret, p("I"), p("lambda"))
    # β_d que cruza la deriva con α=0.33: 0.34; el coste de reclutarlo es 0 por la grieta.
    for (regimen, m, κ) in [("C-GD-07, m≤0.05", 0.05, 1.000), ("C-GD-07, m=1", 1.0, 0.455),
                            ("C-GD-07, m=4", 4.0, 0.000), ("flujo divergente", NaN, 0.000),
                            ("misma-parcela IDV-01", NaN, 1.000)]
        bribe = κ * p("q_gana") * perdida
        push!(filas, [regimen, fmt(m; d = 3), fmt(κ; d = 3), fmt(perdida; d = 6),
                      fmt(bribe; d = 6), fmt(coste_reclutamiento(0.34, B_eps, coef); d = 6),
                      κ > 0 ? "Ec (evidencia necesaria)" : "N (κ=0: sin evidencia)",
                      "condicionado a κ>0 y a que la evidencia llegue"])
    end
    escribir_csv("ataque-A2-equivocacion.csv",
        ["identidad", "m_soluciones_slot", "kappa", "perdida_ue", "soborno_ue",
         "coste_reclutamiento_ue", "veredicto", "etiqueta"], filas)
end

# =============================================================================
# 5 · A8 · transición — hash PoW medido
# =============================================================================

function tabla_ataque_A8()
    filas = Vector{Vector{String}}()
    for (nombre, tasa) in [("CPU 16 núcleos reposo", HASH_CPU_16), ("GPU GTX 1070", HASH_GPU_1070)]
        for hashes in [1e9, 1e12, 1e15]
            e = energia_pow(hashes, J_POR_HASH_GPU)
            push!(filas, [nombre, fmt(tasa; d = 6), fmt(hashes; d = 6), fmt(e; d = 6),
                          fmt(e / 3.6e6; d = 6), fmt(tiempo_pow(hashes, tasa); d = 6),
                          "medido A10-M1; falta hash/bloque y precio para coste absoluto"])
        end
    end
    escribir_csv("ataque-A8-transicion.csv",
        ["hardware", "tasa_H_s", "hashes", "energia_J", "energia_kWh", "tiempo_s", "etiqueta"],
        filas)
end

# =============================================================================
# 6 · Tabla por mecanismo (Ratificación): Δ coste de X y coste del honesto
# =============================================================================

function tabla_por_mecanismo()
    filas = Vector{Vector{String}}()
    # A1/M3+M5: Δ de coste absoluto por reclutado para α=0.33, F=1019, P*=1e-3
    c = coste_A1(0.33, 1019, 1e-3)
    push!(filas, ["M3+M5", "A1/A2",
                  "0 por la grieta (β_d=0.279 < B(ε)=0.675); soborno nominal " *
                  fmt(c.bribe; d = 6) * " u.e./reclutado",
                  fmt(c.B0; d = 6), fmt(c.honesto; d = 6),
                  "condicionado a κ>0 y saldo confiscable", "MODELO §2.4-2.5"])
    # A3/F1+F2+F4
    w = p("w_sin_vdf")
    e_reg = energia_regenerar_kWh(w, p("vatio_nucleo"), p("t_unidad"), TAU_S, p("D_a"))
    e_alm = energia_almacenar_kWh(w, p("vatio_TiB"), TAU_S, p("D_a"))
    push!(filas, ["F1+F2+F4", "A3", fmt(nucleos_por_TiB(w, p("t_unidad")) ; d = 6) * " núcleos/TiB",
                  "0", fmt(e_alm; d = 6) * " kWh/TiB/ventana", "Ee coste; Ec detección (k>B)",
                  "P-COBERTURA §5 (§2.8-2.9)"])
    push!(filas, ["F3 (sellado)", "A7", "no cuantificado (no existe en ZEROX)",
                  "0", "—", "Ee si se adopta; exige cambiar el objeto ploteado", "DS-2 §4.5"])
    push!(filas, ["M1 (garantía)", "A4", fmt(p("q_garantia"); d = 6) * " u.e./identidad",
                  "0", fmt(p("eps_honesto") * p("q_garantia"); d = 6) * " u.e./año",
                  "Ee exigible; regresivo", "P-TASA F4"])
    push!(filas, ["F4 (colateral)", "A4/A9/A10", fmt(p("q_garantia"); d = 6) * " u.e./sector",
                  "0", fmt(p("eps_honesto") * p("q_garantia"); d = 6) * " u.e./año",
                  "Ee exigible; regresivo", "DS-2 §3.2"])
    push!(filas, ["O4 (coinbase)", "A5", "regla de consenso: sin coste en tokens",
                  "0", "—", "Ee sin condición de detección", "P-POOLS §1.3"])
    push!(filas, ["O3 (C-FIN-01)", "A1/A7", "0 (no cambia el umbral dentro de F)",
                  "0", "—", "Ee estructural; acota daño", "P-PRESTAMO §2"])
    push!(filas, ["O2 (PoT)", "A1/A6/A7", "cierra bootstrapping/grinding; no la carrera en tiempo real",
                  "0", "0", "Ee para bootstrapping y A6", "DS-2 §2.3, §3.3"])
    push!(filas, ["M3 (falsos positivos)", "A12", "0 para X; coste >0 para el honesto accidental",
                  "0", fmt(p("eps_honesto") * (p("rho_ret") * p("I") * p("T_v") + p("c_r") +
                          p("I") * p("M")); d = 6) * " u.e./año",
                  "W: el honesto cae con probabilidad no despreciable", "P-EQUIVOCACION Parte B"])
    push!(filas, ["M4 (correlacionado)", "A1/A2", "no evaluado (falta definición)",
                  "—", "—", "candidato propio", "DS-2 reservas"])
    push!(filas, ["F5 (ciclo de vida)", "A10", "no cuantificado (falta fórmula en MODELO)",
                  "—", "—", "Ee débil", "MODELO §5"])
    escribir_csv("por-mecanismo.csv",
        ["mecanismo", "ataque", "delta_coste_X", "coste_B0", "coste_honesto", "veredicto",
         "fuente"], filas)
end

# =============================================================================
# 7 · Barridos declarados
# =============================================================================

function barridos()
    # Ventana: rejilla del MODELO §3
    filas = Vector{Vector{String}}()
    for (α, βd) in [(0.20, 0.00), (0.20, 0.34), (0.20, 0.70), (0.33, 0.00), (0.33, 0.34),
                    (0.33, 0.50), (0.40, 0.00), (0.40, 0.34), (0.40, 0.50)]
        for F in [1019, 3600]
            r = Reparto(α, βd)
            # Vía rápida absorbente (equivalente a la certificada, validada en 4.216 celdas)
            res = primera_dp_absorbente(p_de_alpha(r), deficit_entero(r, F), F)
            push!(filas, [fmt(α; d = 3), fmt(βd; d = 3), string(F), fmt(p_de_alpha(r); d = 6),
                          string(deficit_entero(r, F)),
                          fmt(res; d = 6), fmt(res > 0 ? log10(res) :
                              eventual_log10(p_de_alpha(r), deficit_entero(r, F)); d = 6),
                          res > 0 ? "exacto" : "limite_ruina", "condicionado H-PUENTE"])
        end
    end
    escribir_csv("ventana-barrido.csv",
        ["alpha", "beta_d", "F_slots", "p_adv", "d", "P_primera", "log10P", "etiqueta",
         "condicion"], filas)

    # Cobertura: barrido en φ para el escenario medido
    filas2 = Vector{Vector{String}}()
    N = Int(p("N_TiB"))
    t = TablaLogFact(N)
    for w in [p("w_sin_vdf"), 8030.0]
        B = floor(Int, B_unidades(p("r_maquina"), 1.0, w, TAU_S, p("D_a")))
        for k in [1_000, 100_000, 1_000_000]
            for phi in [1.0, 0.9999, 0.999, 0.99, 0.98, 0.90, 0.83, 0.82, 0.80, 0.70]
                M = max(0, min(N, round(Int, (1 - phi) * N)))
                det = k > B ? cola_hiper_rapida(t, N, M, k, B) : 0.0
                push!(filas2, [fmt(w; d = 6), string(B), string(k), fmt(phi; d = 6), string(M),
                               fmt(det; d = 6), k > B ? "auditoría posible" : "no detectable"])
            end
        end
    end
    escribir_csv("cobertura-barrido.csv",
        ["w_slots", "B", "k", "phi_almacenado", "M_omitido", "deteccion", "etiqueta"], filas2)
end

# =============================================================================
# 8 · Monte Carlo independiente (SOLO donde el suceso es alcanzable)
# =============================================================================

function monte_carlo()
    filas = Vector{Vector{String}}()
    dp = primera_dp(1 / 3, 5, 400).paso
    mc = mc_ventana(1 / 3, 5, 400, REPS, SEMILLA)
    push!(filas, ["ventana p=1/3 d=5 T=400", string(REPS), fmt(dp; d = 8),
                  fmt(mc.p_paso; d = 8), fmt(mc.ic_paso[1]; d = 8), fmt(mc.ic_paso[2]; d = 8),
                  mc.ic_paso[1] <= dp <= mc.ic_paso[2] ? "DENTRO" : "FUERA"])
    ex = exp(-0.36)
    mcs = mc_saldo_cero(0.36, REPS, SEMILLA)
    push!(filas, ["retención P(B=0) θ=0.36", string(REPS), fmt(ex; d = 8),
                  fmt(mcs.p; d = 8), fmt(mcs.ic[1]; d = 8), fmt(mcs.ic[2]; d = 8),
                  mcs.ic[1] <= ex <= mcs.ic[2] ? "DENTRO" : "FUERA"])
    push!(filas, ["cola profunda 9.75e-108", string(REPS), "9.75e-108", "no alcanzable",
                  "—", "—", "MC NO APLICA (P << 1/nrep): se usa oráculo exacto"])
    escribir_csv("monte-carlo.csv",
        ["caso", "replicas", "valor_exacto", "mc", "ic95_lo", "ic95_hi", "resultado"], filas)
end

# =============================================================================
# main
# =============================================================================

function main()
    t0 = time()
    r1 = tabla_comprobaciones()
    tabla_ataque_A1()
    tabla_ataque_A2()
    tabla_ataque_A3()
    tabla_ataque_A4()
    tabla_ataque_A8()
    tabla_por_mecanismo()
    barridos()
    monte_carlo()

    open(joinpath(DIR_RES, "RESUMEN.txt"), "w") do io
        println(io, "DS-3 · resumen de ejecución")
        println(io, "fecha_local = 2026-09-26 (fecha de la orden)")
        println(io, "julia = ", VERSION)
        println(io, "nthreads_default = ", Threads.nthreads(:default))
        println(io, "nthreads_interactive = ", Threads.nthreads(:interactive))
        println(io, "cpu = ", Sys.CPU_NAME)
        println(io, "memoria_total_GiB = ", round(Sys.total_memory() / 2^30; digits = 1))
        println(io, "semilla = ", string(SEMILLA))
        println(io, "reps = ", REPS)
        println(io, "escenarios = ", OPC["escenarios"])
        println(io, "segundos_pared = ", round(time() - t0; digits = 2))
        println(io)
        println(io, "validaciones:")
        vt = validar_todo()
        println(io, "  primera_pasada = ", vt.primera_pasada)
        println(io, "  cobertura = ", vt.cobertura)
        println(io, "  almacenamiento = ", vt.almacenamiento)
        println(io, "  alpha = ", vt.alpha)
        println(io)
        println(io, "artefactos:")
        for f in sort(readdir(DIR_RES))
            endswith(f, ".csv") && println(io, "  ", f)
        end
    end
    @printf("DS-3 terminado en %.1f s. Comprobaciones: %s\n", time() - t0, r1)
end

main()
