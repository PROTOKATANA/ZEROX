#!/usr/bin/env -S julia --project=.
# FV-1 - comprobaciones numericas (ORDEN-FV1-DISENO.md §4.C)
# Ejecucion documentada: env -u LD_LIBRARY_PATH julia --project=. run.jl
# Maquina: la de referencia del repositorio (ver P-ZRX/P-DISUASION/DS3/julia-version.toml).
# Hilos: 1 (todo el calculo es cerrado o binomial pequeno; no hace falta mas).

using Printf
using StableRNGs

include(joinpath(@__DIR__, "src", "modelo.jl"))
include(joinpath(@__DIR__, "src", "referencia.jl"))
using .ModeloFV1
using .ReferenciaFV1

const RES = joinpath(@__DIR__, "resultados")
isdir(RES) || mkpath(RES)

function guardar_csv(nombre, cabecera, filas)
    open(joinpath(RES, nombre), "w") do io
        println(io, cabecera)
        for f in filas
            println(io, f)
        end
    end
end

println("="^78)
println("FV-1 · Seccion C.1 -- Reproduccion de las cifras de esperanza de la decision 6")
println("="^78)
a = 0.25
println("\n(a=0,25) Fraccion ESPERADA de asientos del atacante, por prima b:")
println(@sprintf("%-8s %14s %14s %20s", "b", "p=1,0", "p=0,8", "p=0 (censura total)"))
filas_b = []
for b in [1.0, 2.0, 4.0, 10.0, 1e6]
    q1 = q_atacante(a, b, 1.0)
    q08 = q_atacante(a, b, 0.8)
    q0 = q_atacante(a, b, 0.0)
    println(@sprintf("%-8.1f %14.4f %14.4f %20.4f", b, q1, q08, q0))
    push!(filas_b, @sprintf("%.4f,%.6f,%.6f,%.6f", b, q1, q08, q0))
end
guardar_csv("C1-esperanza-qa.csv", "b,q_a_p1,q_a_p08,q_a_p0", filas_b)

println("\n¿Sella con la participacion honesta dada? (frac_honesto_firmable >= 2/3)")
filas_sella = []
for b in [1.0, 2.0, 4.0, 10.0, 1e6]
    fh08 = frac_honesto_firmable(a, b, 0.8)
    sella = fh08 >= 2/3 ? "SI" : "no"
    pnec = p_necesaria(a, b)
    println(@sprintf("b=%-6.1f  frac_honesto(p=0,8)=%.4f  -> %-3s   p_necesaria=%.4f (%.1f%%)",
                      b, fh08, sella, pnec, 100*pnec))
    push!(filas_sella, @sprintf("%.4f,%.6f,%s,%.6f", b, fh08, sella, pnec))
end
guardar_csv("C1-sella-y-p-necesaria.csv", "b,frac_honesto_p08,sella_p08,p_necesaria", filas_sella)

println("\n" * "="^78)
println("Seccion C.1(D) -- HALLAZGO CENTRAL: umbrales de pausa y de ruptura bajo")
println("censura total de las pruebas de disponibilidad honestas (p=0), funcion de b")
println("="^78)
println(@sprintf("%-8s %16s %16s", "b", "a_pausa(b)=1/(2b+1)", "a_rompe(b)=2/(b+2)"))
filas_umbral = []
for b in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 20.0]
    ap = a_pausa(b)
    ar = a_rompe(b)
    println(@sprintf("%-8.1f %16.4f %16.4f", b, ap, ar))
    push!(filas_umbral, @sprintf("%.4f,%.6f,%.6f", b, ap, ar))
end
guardar_csv("C1-umbral-pausa-rompe.csv", "b,a_pausa,a_rompe", filas_umbral)
println("""
Lectura: con b=1 (sin prima) los dos umbrales son 1/3 y 2/3, los del diseno
"votan todos". Con CUALQUIER b>1, a_pausa(b) < 1/3: un atacante con MENOS de
un tercio del peso total, si ademas puede censurar la red (prueba de
disponibilidad honesta -> p=0), puede pausar el sello. A b=4 (la prima que
CONTEXTO.md recomienda como "moderada"), a_pausa=1/9=11,1%. a_rompe(4)=1/3
exactamente: al atacante de referencia (a=0,25) todavia no le alcanza para
romper (0,25<1/3), pero a partir de b>4 el umbral de ROMPER tambien cae por
debajo de 1/3.
""")

println("="^78)
println("Seccion C.1 -- Viveza/seguridad con K finito (extiende verif_sorteo.py)")
println("="^78)
fila_txt(vals; w=12, prec=2) = join([@sprintf("%*.*e", w, prec, v) for v in vals])

println("\nP(el atacante toma >= 1/3 de los K asientos), con CENSURA TOTAL (p=0):")
println(rpad("K", 6), " ", join([rpad("b=$b", 12) for b in [1,2,4,6,10]]))
filas_p13 = []
for K in [100, 400, 1000, 4000]
    vals = Float64[]
    for b in [1.0, 2.0, 4.0, 6.0, 10.0]
        qa = q_atacante(a, b, 0.0)
        push!(vals, p_para_al_menos(qa, K, 1/3))
    end
    println(rpad(K, 6), " ", fila_txt(vals))
    push!(filas_p13, string(K, ",", join(vals, ",")))
end
guardar_csv("C1-p-al-menos-tercio-censura.csv", "K,p13_b1,p13_b2,p13_b4,p13_b6,p13_b10", filas_p13)

println("\nP(el atacante toma >= 2/3 de los K asientos: rompe el sello), CENSURA TOTAL (p=0):")
println(rpad("K", 6), " ", join([rpad("b=$b", 12) for b in [1,2,4,6,10]]))
filas_p23 = []
for K in [100, 400, 1000, 4000]
    vals = Float64[]
    for b in [1.0, 2.0, 4.0, 6.0, 10.0]
        qa = q_atacante(a, b, 0.0)
        push!(vals, p_para_al_menos(qa, K, 2/3))
    end
    println(rpad(K, 6), " ", fila_txt(vals))
    push!(filas_p23, string(K, ",", join(vals, ",")))
end
guardar_csv("C1-p-al-menos-dostercios-censura.csv", "K,p23_b1,p23_b2,p23_b4,p23_b6,p23_b10", filas_p23)

println("""
Lectura: para b<=4 y K>=1000, la probabilidad de romper el sello por PURA
VARIANZA del sorteo (sin que el umbral en esperanza ya lo permita) sigue
siendo despreciable -- el riesgo real no es la varianza, es el DESPLAZAMIENTO
de la esperanza que muestra la tabla anterior. Para b=10, q_atacante(0,25,10,0)
= 0,769 > 2/3 ya EN ESPERANZA, así que con K grande P(rompe) -> 1: subir K no
protege de un umbral desplazado, solo protege de una excursion de varianza
alrededor de un umbral que sigue siendo seguro.
""")

println("="^78)
println("Seccion C.2 -- Tamano de K y su sesgo por eleccion de ancla (extiende")
println("verif_sesgo_sorteo.py con la fraccion q_atacante en vez de alpha desnudo)")
println("="^78)
println("K minimo tal que P(>=1/3)<1e-9 y P(>=2/3)<1e-18, bajo censura total, por b:")
println(@sprintf("%-6s %10s %10s", "b", "K(1/3)", "K(2/3)"))
filas_k = []
for b in [1.0, 2.0, 4.0]
    qa = q_atacante(a, b, 0.0)
    if qa >= 1/3
        println(@sprintf("%-6.1f %10s %10s", b, "N/A (q_a>=1/3 en esperanza)", "N/A"))
        push!(filas_k, "$b,NA,NA")
        continue
    end
    k13 = k_minimo(qa, 1/3, 1e-9)
    k23 = qa < 2/3 ? k_minimo(qa, 2/3, 1e-18) : nothing
    println(@sprintf("%-6.1f %10s %10s", b, string(k13), string(k23)))
    push!(filas_k, string(b, ",", k13, ",", k23))
end
guardar_csv("C2-K-minimo-censura.csv", "b,K_tercio,K_dostercios", filas_k)

println("\nSesgo por eleccion de m anclas (m=2,955 medido; m=151 cota por construccion,")
println("D9-f del diseno antiguo), con K=4000, censura total, por b:")
println(@sprintf("%-6s %10s %14s %14s", "b", "m", "P(para)", "P(rompe)"))
filas_sesgo = []
for b in [1.0, 2.0, 4.0]
    qa = q_atacante(a, b, 0.0)
    p13 = p_para_al_menos(qa, 4000, 1/3)
    p23 = p_para_al_menos(qa, 4000, 2/3)
    for m in [2.955, 151.0]
        pm13 = p_finaliza_mentira(p13, m)
        pm23 = p_finaliza_mentira(p23, m)
        println(@sprintf("%-6.1f %10.3f %14.2e %14.2e", b, m, pm13, pm23))
        push!(filas_sesgo, @sprintf("%.1f,%.3f,%.6e,%.6e", b, m, pm13, pm23))
    end
end
guardar_csv("C2-sesgo-ancla.csv", "b,m,p_para,p_rompe", filas_sesgo)

println("="^78)
println("Seccion C.3 -- Tamano y coste anual del certificado")
println("="^78)
println(@sprintf("%-6s %14s %14s %12s %12s", "K", "Ed25519 (B)", "BLS agreg. (B)", "GB/ano@30s", "GB/ano@10s"))
filas_cert = []
for K in [1000, 4000, 10000]
    bed = coste_certificado_bytes(K; esquema=:ed25519)
    bbls = coste_certificado_bytes(K; esquema=:bls)
    gb30_ed = bed*365*86400/30/1e9
    gb10_ed = bed*365*86400/10/1e9
    gb30_bls = bbls*365*86400/30/1e9
    println(@sprintf("%-6d %11d B %11d B %9.2f/%.4f %9.2f/%.4f", K, bed, bbls, gb30_ed, gb30_bls, gb10_ed, bbls*365*86400/10/1e9))
    push!(filas_cert, @sprintf("%d,%d,%d,%.4f,%.4f,%.4f,%.4f", K, bed, bbls, gb30_ed, gb30_bls, gb10_ed, bbls*365*86400/10/1e9))
end
guardar_csv("C3-certificado.csv", "K,ed25519_B,bls_B,ed25519_GBano30s,bls_GBano30s,ed25519_GBano10s,bls_GBano10s", filas_cert)
println("""
Referencia (SPEC 0.0.1): cabeceras PoST ~21,5 GB/ano, PoT ~4,0 GB/ano (mismas
cifras que citaba la propuesta antigua de 2026-09-09). Con Ed25519 y K>=4000
el certificado por si solo ya iguala o supera esa cifra si se emite cada 10 s;
con BLS agregada queda en una fraccion menor al 1%. NO se recomputa aqui la
verificacion de BLS por nodo: se remite a P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md
§2.4 (blst auditado) como unico candidato ya evaluado en el repositorio.
""")

println("="^78)
println("Seccion C.4 -- Ventana del doble farmeo: tiempo esperado hasta el sello")
println("="^78)
println("""
Delta (retardo de red) NO esta medida (IPA B-05); Delta_simulada de DMS-v0.1
da un p99 de 0,26-0,60 s por SALTO de overlay (no por enlace). Se deja
Delta como parametro simbolico y T_round_slots = c_fases * Delta/tau, con
tau=1 s/slot (perfil dev) y c_fases=3 (GossiPBFT: prepare+commit+difusion
del certificado, FIP-0086 declara 2 fases utiles de acuerdo mas 1 de
difusion, cifra no verificada linea a linea en este encargo: c_fases queda
como parametro simbolico, no un numero fijado por FV-1).
""")
println(@sprintf("%-6s %-6s %14s %16s", "a", "b", "p_sella(p=0,8)", "T_sello (rondas)"))
filas_ventana = []
K = 4000
for a2 in [0.20, 0.25, 0.30], b in [1.0, 4.0]
    fh = frac_honesto_firmable(a2, b, 0.8)
    need = Int(ceil(2*K/3))
    # P(sella) exacta con K finito: numero de asientos honestos-encendidos
    # sigue Binomial(K, fh); hace falta que ese conteo solo sea >= need
    # (aproximacion: se ignora la contribucion del atacante, caso pesimista
    # ya usado en toda la seccion C.1).
    p_sella = fh >= 1.0 ? 1.0 : sf_binom(need, K, fh)
    t_rondas = tiempo_esperado_sello(p_sella, 1.0)
    println(@sprintf("%-6.2f %-6.1f %14.4e %16.4e", a2, b, p_sella, t_rondas))
    push!(filas_ventana, @sprintf("%.2f,%.1f,%.6e,%.6e", a2, b, p_sella, t_rondas))
end
guardar_csv("C4-ventana-doble-farmeo.csv", "a,b,p_sella_por_ronda,rondas_esperadas", filas_ventana)
println("""
Lectura: con b=1 y participacion real p=0,8, el sello NUNCA llega en
esperanza finita para a>=0,20 (p_sella=0 exacto porque frac_honesto_firmable
< 2/3, ver C.1): la capa se queda permanentemente en C-FIN-01 (F_slots) sin
la prima. Con b=4 sella (t_rondas finito) para a=0,20 y a=0,25 pero no ya
para a=0,30 (frac_honesto_firmable(0,30;4;0,8) < 2/3, comprobado en C.1).
El tiempo hasta el sello es entonces T_sello = t_rondas * c_fases * Delta;
con Delta_p99 simulada (0,26-0,60 s/salto) y un puñado de rondas, T_sello es
del orden de segundos a minutos, muy por debajo de F_slots (horas): esto
cuantifica -bajo las condiciones declaradas y sin Delta medida en red real-
cuanto arrincona la capa al doble farmeo, tal como pide ORDEN-FV1 §3.8.
""")

println("="^78)
println("Seccion C.1(coverage) -- Cruce Monte Carlo de la formula cerrada")
println("(V-ZRX/LINEO.md: semillas fijas NO consecutivas, tabla de cobertura)")
println("="^78)
SEMILLAS = UInt64[0x51E11A00, 0x0FEA3B7D, 0x77C0FFEE, 0x1234ABCD, 0x9E3779B1,
                   0xDEADBEEF0, 0x2545F491, 0xA5A5A5A5]  # no consecutivas
casos = [(0.25, 1.0, 0.8, 4000), (0.25, 4.0, 0.8, 4000), (0.25, 4.0, 0.0, 4000),
         (0.20, 4.0, 0.0, 4000)]
filas_mc = []
for (a2, b, p2, K2) in casos
    rngs = [StableRNG(s) for s in SEMILLAS]
    cov = cobertura_sorteo(a2, b, p2, K2, rngs)
    qa_teor = q_atacante(a2, b, p2)
    fh_teor = frac_honesto_firmable(a2, b, p2)
    err_a = abs(cov.mean_a - qa_teor)
    println(@sprintf("a=%.2f b=%.1f p=%.1f K=%d | MC(n=%d): media_a=%.4f [%.4f,%.4f]  teorico=%.4f  |err|=%.5f",
                      a2, b, p2, K2, cov.n, cov.mean_a, cov.min_a, cov.max_a, qa_teor, err_a))
    push!(filas_mc, @sprintf("%.2f,%.1f,%.1f,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f",
                              a2, b, p2, K2, cov.n, cov.mean_a, cov.min_a, cov.max_a, qa_teor, err_a))
end
guardar_csv("C1-cobertura-montecarlo.csv",
            "a,b,p,K,n_replicas,mc_media_a,mc_min_a,mc_max_a,teorico_a,error_abs", filas_mc)
println("\nCobertura: 8 replicas por caso (semillas no consecutivas), 4 casos, min-max reportado.")
println("Fin de run.jl -- ver resultados/*.csv para las tablas completas.")
