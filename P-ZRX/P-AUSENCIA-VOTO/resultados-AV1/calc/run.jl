#!/usr/bin/env julia
"""
AV-1 · run.jl — genera todos los CSV de `resultados/` a partir de `src/modelo.jl`.
Uso: julia --project=. run.jl --seed 0x5a5a
Cómputo ligero (LINEO §7): declarado ≤ 4 hilos, ≤ 1 GiB RAM, ≤ 64 MiB de disco, minutos.
"""

using Printf
using Dates

include(joinpath(@__DIR__, "src", "modelo.jl"))
using .Modelo

const RESDIR = joinpath(@__DIR__, "resultados")
isdir(RESDIR) || mkpath(RESDIR)

function escribir_csv(ruta::String, cabecera::Vector{String}, filas::Vector{<:Tuple})
    open(ruta, "w") do io
        println(io, join(cabecera, ","))
        for fila in filas
            println(io, join(string.(fila), ","))
        end
    end
end

t0 = time()

# ---------------------------------------------------------------------------
# C1 · Datos por granjero y día de cada esquema (E.1 de la orden).
#   T_instancia_s es un símbolo (Δ no medida, IPA B-05): se barre un rango
#   ilustrativo, etiquetado [H], no una medición.
# ---------------------------------------------------------------------------
filas_c1 = Tuple[]
for T_instancia_s in (1.0, 5.0, 30.0, 300.0)
    instancias_dia = 86400.0 / T_instancia_s
    b1 = bytes_dia_esquema1(instancias_dia)
    for N_ventana in (1, 10, 100, 1000, 10000)
        b3 = bytes_dia_esquema3(instancias_dia, N_ventana)
        push!(filas_c1, (T_instancia_s, instancias_dia, N_ventana,
                          round(b1, digits=2), round(b3, digits=2),
                          round(b3 / max(b1, 1e-9), digits=4)))
    end
end
escribir_csv(joinpath(RESDIR, "C1-datos-por-dia.csv"),
             ["T_instancia_s", "instancias_dia", "N_ventana",
              "bytes_dia_esquema1", "bytes_dia_esquema3", "razon_A3_sobre_A1"],
             filas_c1)

# ---------------------------------------------------------------------------
# C2 · Coste absoluto de la pausa por hora para el atacante: m_aus fijo vs
#   proporcional, con concentración (m_split=1) vs fragmentación, y con/sin
#   censura de las pruebas de disponibilidad honestas (FV-1 ataque 13).
# ---------------------------------------------------------------------------
filas_c2 = Tuple[]
K = 1000
T_instancia_horas_ref = 1.0 / 3600.0  # 1 s, ilustrativo [H]
m_aus_fijo = 10.0     # u.e. simbólicas, [H] — Katana decide el valor real (D1)
f_aus = 0.05          # fracción simbólica de garantía, [H]
Garantia_total = 1.0e6
for a in (0.10, 0.20, 0.25, 0.30, 0.40)
    for b in (1.0, 2.0, 4.0)   # b=2 es FV-D05; se barre por sensibilidad
        for m_split in (1, 10, 1000)
            for censura in (false, true)
                c_fijo = costo_pausa_hora_fijo(a, b, K, m_aus_fijo, T_instancia_horas_ref;
                                                m_split=m_split, censura=censura)
                c_prop = costo_pausa_hora_proporcional(a, b, K, f_aus, Garantia_total,
                                                        T_instancia_horas_ref;
                                                        m_split=m_split, censura=censura)
                push!(filas_c2, (a, b, m_split, censura,
                                  round(c_fijo, digits=6), round(c_prop, digits=2)))
            end
        end
    end
end
escribir_csv(joinpath(RESDIR, "C2-costo-pausa-hora.csv"),
             ["a", "b", "m_split", "censura", "costo_hora_m_aus_fijo", "costo_hora_m_aus_proporcional"],
             filas_c2)

# ---------------------------------------------------------------------------
# C3 · Pérdida esperada del honesto por perfil, con y sin premio al voto.
# ---------------------------------------------------------------------------
filas_c3 = Tuple[]
instancias_dia_ref = 86400.0 / 1.0
b_ref = 2.0  # FV-D05
for f_h in (1e-6, 1e-4, 1e-2)
    for perfil in (:siempre_encendido, :dieciseis_horas, :apagon_mensual)
        for m_aus in (1.0, 10.0, 100.0)
            for premio in (0.0, 1.0)
                res = perdida_esperada_honesto_anual(f_h, b_ref, K, instancias_dia_ref, perfil, m_aus;
                                                       horas_apagon=6.0, premio_voto=premio)
                push!(filas_c3, (f_h, string(perfil), m_aus, premio,
                                  round(res.perdida_confiscacion, digits=6),
                                  round(res.incidentes_apagado_anio, digits=6),
                                  round(res.p_elegido_apagado, digits=8)))
            end
        end
    end
end
escribir_csv(joinpath(RESDIR, "C3-perdida-honesto-perfil.csv"),
             ["f_h", "perfil", "m_aus", "premio_voto", "perdida_anual_confiscacion",
              "incidentes_apagado_anio", "p_elegido_por_instancia_apagado"],
             filas_c3)

# ---------------------------------------------------------------------------
# C4 · Tasa de falsos positivos por censura (defensa del plazo de gracia).
# ---------------------------------------------------------------------------
filas_c4 = Tuple[]
for c in (0.1, 0.3, 0.5, 0.7, 0.9, 0.99, 0.999, 1.0)
    for n in (1, 10, 150, 1019)  # 1019 = F_slots de SL-2b
        push!(filas_c4, (c, n, round(tasa_fp_censura(c, n), digits=10)))
    end
end
escribir_csv(joinpath(RESDIR, "C4-fp-censura.csv"), ["c", "n_ventana_gracia", "tasa_fp"], filas_c4)

# ---------------------------------------------------------------------------
# C5 · Región de m_aus (caso proporcional f_aus): borde inferior de
#   disuasión y superior de honestidad. `costo_min_hora` e `ingreso_anual`
#   son símbolos declarados por el informe, no parámetros de producto.
# ---------------------------------------------------------------------------
filas_c5 = Tuple[]
ingreso_anual_simbolico(f_h) = f_h * 1.0e7  # unidad de cuenta simbólica [H], proporcional al peso
for a_ref in (0.20, 0.25, 0.33, 0.40)
    for costo_min_hora in (0.1, 1.0, 10.0)
        for frac_max in (0.01, 0.05)
            for f_h_peor in (1e-6, 1e-4, 1e-2)
                res = region_m_aus_vacia(a_ref, 2.0, K, Garantia_total, T_instancia_horas_ref,
                                          costo_min_hora, f_h_peor, instancias_dia_ref, 6.0,
                                          ingreso_anual_simbolico, frac_max;
                                          f_aus_grid=0.0001:0.0005:1.0)
                push!(filas_c5, (a_ref, costo_min_hora, frac_max, f_h_peor,
                                  res.vacia,
                                  isnan(res.f_aus_min) ? "" : round(res.f_aus_min, digits=4),
                                  isnan(res.f_aus_max) ? "" : round(res.f_aus_max, digits=4)))
            end
        end
    end
end
escribir_csv(joinpath(RESDIR, "C5-region-m_aus.csv"),
             ["a_ref", "costo_min_hora", "frac_max_ingreso", "f_h_peor", "vacia",
              "f_aus_min", "f_aus_max"], filas_c5)

# ---------------------------------------------------------------------------
# C6 · Concentración vs fragmentación (hallazgo central de la parte (e)).
# ---------------------------------------------------------------------------
filas_c6 = Tuple[]
for a_eff in (0.10, 0.25, 0.40)
    for m_split in (1, 2, 5, 10, 50, 100, 1000)
        inc = incidentes_por_instancia(a_eff, K, m_split)
        push!(filas_c6, (a_eff, K, m_split, round(inc, digits=6),
                          round(inc * m_aus_fijo, digits=4)))
    end
end
escribir_csv(joinpath(RESDIR, "C6-concentracion-vs-fragmentacion.csv"),
             ["a_eff", "K", "m_split", "incidentes_por_instancia", "costo_m_aus_fijo_por_instancia"],
             filas_c6)

t1 = time()

# ---------------------------------------------------------------------------
# RESUMEN.txt
# ---------------------------------------------------------------------------
open(joinpath(RESDIR, "RESUMEN.txt"), "w") do io
    println(io, "AV-1 · resumen de ejecución de run.jl")
    println(io, "Fecha: ", Dates.now())
    println(io, "Julia: ", VERSION)
    println(io, "Tiempo de pared (cálculo, sin JIT separado): ", round(t1 - t0, digits=3), " s")
    println(io, "Hilos Threads.nthreads(:default): ", Threads.nthreads(:default))
    println(io, "Archivos generados: C1..C6 + RESUMEN.txt en resultados/")
    println(io, "Hallazgo central (e): con m_aus FIJO y concentración (m_split=1),")
    println(io, "el coste de la pausa por hora es ~independiente de `a` para a≫1/K")
    println(io, "(ver C2, columna costo_hora_m_aus_fijo a m_split=1: apenas varía con a).")
    println(io, "Con m_aus PROPORCIONAL a la garantía, el coste SÍ crece con `a` (ver C2,")
    println(io, "columna costo_hora_m_aus_proporcional) y es ~invariante a m_split (ver C6",
                " para el contraste de incidentes, que SÍ varía con m_split).")
end

println("AV-1 run.jl completo en ", round(t1 - t0, digits=3), " s. Resultados en ", RESDIR)
