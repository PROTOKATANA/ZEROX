#!/usr/bin/env julia
# run.jl — CLI reproducible de CRP-v0.2. No usa notebooks.
# Ejecutar desde este directorio:
#   env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 64
using Dates
using Printf
using Random
using StableRNGs
include(joinpath(@__DIR__, "src", "CosteRamaPrivadaV2.jl"))
using .CosteRamaPrivadaV2

function _arg(nombre, defecto)
    i = findfirst(==(nombre), ARGS)
    i === nothing && return defecto
    return ARGS[i+1]
end

const SEMILLA = parse(UInt64, _arg("--seed", "0x5a5a"))
const REPLICAS = parse(Int, _arg("--replicas", "64"))
const RES = joinpath(@__DIR__, "resultados")
mkpath(RES)

function salida(nombre, f)
    ruta = joinpath(RES, nombre)
    open(ruta, "w") do io
        f(io)
    end
    println("escrito ", ruta)
end

salida("ENTORNO.txt", function (io)
    println(io, "CRP-v0.2 — entorno de ejecución")
    println(io, "fecha_utc = ", Dates.now(Dates.UTC))
    println(io, "julia_version = ", VERSION)
    println(io, "cpu = ", Sys.CPU_NAME)
    println(io, "hilos_default = ", Threads.nthreads(:default))
    println(io, "hilos_interactive = ", Threads.nthreads(:interactive))
    println(io, "sistema = ", Sys.KERNEL)
    println(io, "semilla = ", SEMILLA, " (", string(SEMILLA, base=16), ")")
    println(io, "replicas = ", REPLICAS)
    println(io, "presupuesto_declarado = max 64 GiB RAM, 24 hilos, disco temporal acotado")
end)

salida("TEORIA.txt", function (io)
    println(io, "Referencias exactas ±1 (p=9/10, q=1/10)")
    p, q = 9//10, 1//10
    for d in (0, 1, 2, 6, 12)
        pe = prob_empate_eventual(d, p, q)
        ps = prob_superar_eventual(d, p, q)
        @printf(io, "d=%2d  P(empate eventual)=%s  P(superar estricto eventual)=%s\n",
                d, string(pe), string(ps))
    end
    println(io, "\nRegresión 1/(1+ε^(-1/d)): debe converger a 1/2 DESDE ABAJO")
    for d in (1, 2, 4, 8, 16, 64)
        v, dist = corrimiento_alpha_prob(d, 1//10)
        @printf(io, "d=%2d  valor=%.15f  valor-1/2=%+.3e\n", d, Float64(v), Float64(dist))
    end
end)

salida("CORTO.txt", function (io)
    println(io, "DP de la carrera corta con contabilidad de masa (D2)")
    println(io, "d  T      alpha  P_sup_lower   P_sup_upper   fuga       conserv")
    for d in (3, 6, 12)
        for T in (50, 200)
            for a in (0.2, 0.4, 0.45)
                r = prob_superar_dp(Float64, d, 1 - a, a, T)
                @printf(io, "%2d %4d  %.2f  %.6e  %.6e  %.2e  %+.1e\n",
                        d, T, a, r.p_exito_lower, r.p_exito_upper, r.masa_fuga, r.conservacion)
            end
        end
    end
    println(io, "\nEmpate vs superación (d=6, T=200, α=0.4):")
    re = prob_empate_dp(Float64, 6, 0.6, 0.4, 200)
    rs = prob_superar_dp(Float64, 6, 0.6, 0.4, 200)
    @printf(io, "  empate=[%.6e, %.6e]  superar=[%.6e, %.6e]\n",
            re.p_exito_lower, re.p_exito_upper, rs.p_exito_lower, rs.p_exito_upper)
    println(io, "\nalpha_prob del baseline (p0=0.05, d=6, T=200):")
    inv = invertir_monotona(a -> prob_superar_dp(Float64, 6, 1 - a, a, 200).p_exito_lower,
                            0.05; lo=0.0, hi=0.5, pasos=120)
    println(io, inv === nothing ? "  NO MONÓTONA: indefinida" : "  intervalo = $(inv[3])")
end)

salida("RCE.txt", function (io)
    println(io, "Perfil candidato RCE-v0.1 rev2 (Z0). Instrumento, NO consenso.")
    cfg = ConfigRCE(; W=10, G=0, activation_delay_windows=1, Q=10, R_inicial=100,
                    R_min=1, R_max=1000, ganancia_a=1, ganancia_d=1,
                    p_lo=1, q_lo=2, p_hi=2, q_hi=1, redondeo=REDONDEO_FLOOR)
    c = ControladorRCE(cfg)
    r0 = cerrar_cohorte!(c, 0, 5, 10)
    println(io, "cohorte0 N=5 sello=10 -> ", r0.estado, " R=", r0.R_next, " activación=", r0.activacion)
    println(io, "rango(19)=", rango_en(c, 19), " rango(20)=", rango_en(c, 20))
    r1 = cerrar_cohorte!(c, 1, 0, 20)
    println(io, "cohorte1 N=0 sello=20 -> ", r1.estado, " (Z0: sin propuesta)")
    println(io, "rango(39)=", rango_en(c, 39), " rango(40)=", rango_en(c, 40))
    println(io, "\nPrimer dato ausente del controlador del SPEC (C-HDR-06): la VENTANA")
    println(io, "(TAREAS §2.3: arranque, ventana, límites, redondeos, fusiones fuera de ventana).")
    println(io, "Resultado del controlador del SPEC: Pendiente.")
end)

salida("RFIN5.txt", function (io)
    println(io, "R-FIN-5 estructural y escenarios de S")
    ev = [EventoPot(5, 0xaa, 100), EventoPot(12, 0xbb, 100)]
    fa = DescriptorFlujo(pot_origin="O", dominio="D", origen_indices=0, semilla=1,
                         N_inicial=100, autenticado=true, eventos=ev)
    fc = DescriptorFlujo(pot_origin="O", dominio="D", origen_indices=0, semilla=1,
                         N_inicial=100, autenticado=true,
                         eventos=[EventoPot(5, 0xaa, 100), EventoPot(12, 0x99, 100)])
    println(io, "compat en slot 7 (antes de la divergencia) = ", compatible_rfin5(fa, fc, 7))
    println(io, "compat en slot 20 (tras la divergencia)    = ", compatible_rfin5(fa, fc, 20))
    println(io, "\nToy escalar S: frontera de deriva α=1/(S+1)")
    for S in (1, 2, 4, 8, 16, 24)
        @printf(io, "S=%2d  α_drift=%.6f  g(α_drift)=%+.1e\n",
                S, 1 / (S + 1), toy_S_deriva(1 / (S + 1), S))
    end
    println(io, "\nCotas de unión para P_i = [0.1,0.2,0.05]: ", cota_union([0.1, 0.2, 0.05]))
end)

salida("DAG.txt", function (io)
    println(io, "D1 · fixtures deterministas de color")
    for k in (1, 2, 5)
        dag, m, herm, rojo = fixture_rojo_conocido(; k=k)
        cols = [color_contextual(dag, m, x) for x in herm]
        println(io, "k=$k rojo_conocido: colores=", cols)
    end
    for k in (3, 30)
        dag, m, herm = fixture_cero_rojos(; k=k)
        cols = [color_contextual(dag, m, x) for x in herm]
        println(io, "k=$k cero_rojos: colores=", cols)
    end
    println(io, "\nEstadística calibrada (k=2, concurrencia alta) y control (k=30), ",
            REPLICAS, " réplicas")
    for (k, cfg) in ((2, ConfigSim(; n_honestos=8, p_honesto=0.125, delta=4, S=1,
                                   T=300, t_fork=1, p_adversario=0.0)),
                     (30, ConfigSim(; n_honestos=8, p_honesto=0.125, delta=4, S=1,
                                    T=300, t_fork=1, p_adversario=0.0)))
        r = tasa_rojos_calibrada(x -> StableRNG(SEMILLA + x), cfg, REPLICAS; k=k)
        @printf(io, "k=%d  tasa_bloques=%.4f  frac_reps_con_rojo=%.3f  IC95=(%.3f,%.3f)\n",
                k, r.tasa_bloques, r.fraccion_replicas_con_rojo, r.ic[1], r.ic[2])
    end
    println(io, "\nFrontera MEDIDA por escenario (", REPLICAS, " réplicas por celda).")
    println(io, "S  regla      α_adv  d  exitos/n  P_win   IC95")
    for S in (1, 2, 4)
        for a in (0.1, 0.2, 0.3)
            # normalización de recurso: honesto total = 1−α; cada rama = α (la misma
            # parcela responde a S flujos). El borde aditivo queda en 1/(S+1).
            cfg = ConfigSim(; n_honestos=4, p_honesto=(1 - a) / 4, delta=4, S=S, T=400,
                            t_fork=1, p_adversario=a)
            for d in (0, 2)
                ex_max = 0
                ex_sum = 0
                for r in 1:REPLICAS
                    res = simular!(cfg, StableRNG(SEMILLA + 1000r + S + d); k=30)
                    m = maximum(res.W_priv; init=big(0))
                    s = sum(res.W_priv; init=big(0))
                    m - res.W_pub > d && (ex_max += 1)
                    s - res.W_pub > d && (ex_sum += 1)
                end
                pm, lm, hm = wilson(ex_max, REPLICAS)
                @printf(io, "%d  max(RFIN5) %.2f  %d  %4d/%d  %.3f  (%.3f,%.3f)\n",
                        S, a, d, ex_max, REPLICAS, pm, lm, hm)
                ps, ls, hs = wilson(ex_sum, REPLICAS)
                @printf(io, "%d  suma(adit) %.2f  %d  %4d/%d  %.3f  (%.3f,%.3f)\n",
                        S, a, d, ex_sum, REPLICAS, ps, ls, hs)
            end
        end
    end
end)

salida("CONTROL.txt", function (io)
    println(io, "Control escalar dedicado (encargo §4): S ramas iid, suma íntegra,")
    println(io, "sin red, rojos, U2/U3, límites ni recursos compartidos.")
    for S in (1, 2, 4, 8, 16, 24)
        der = control_escalar_S(1 / (S + 1), S)
        @printf(io, "S=%2d  α_drift=%.6f  g=%.3e\n", S, der.raiz, der.deriva)
    end
    println(io, "\nOff the toy: el DAG completo NO está obligado a recuperar 1/(S+1)")
    println(io, "al desactivar R-FIN-5; solo el control escalar lo acredita.")
    println(io, "\nα_drift, α_prob, P_eventual son objetos DISTINTOS (no se mezclan).")
end)

salida("MC.txt", function (io)
    println(io, "Exacto vs MC (±1), d=4, α=0.1")
    rng = StableRNG(SEMILLA)
    for T in (20, 60, 200)
        ex = Float64(prob_superar_finita(4, 9//10, 1//10, T))
        phat, lo, hi, ne, n = mc_superar(rng, 4, 0.1, T, 20000)
        @printf(io, "T=%3d exacto=%.6e  MC=%.6e  IC95=(%.6e,%.6e)\n", T, ex, phat, lo, hi)
    end
end)

salida("VEREDICTO.txt", function (io)
    println(io, "Reglas que impiden cerrar el umbral protocolario:")
    for (r, e) in (("C-HDR-06/§7.2 controlador", "Pendiente: ventana, arranque, redondeos"),
                   ("flujo PoT conjunto (R-FIN-5)", "candidata, no integrada"),
                   ("PoT AES real", "no integrado (IntegracionPotPendiente)"),
                   ("C-GD-11", "5 pendientes: métrica, valor, bootstrap, borde, finalidad"),
                   ("finalidad R-FIN-7/F", "F=2h provisional; Δ sin medir en red DAG"),
                   ("S_adversario", "sin medición de hardware compatible"))
        println(io, " - ", r, " → ", e)
    end
    println(io)
    println(io, frase_veredicto(false))
end)

println("CRP-v0.2 terminado. Artefactos en ", RES)
