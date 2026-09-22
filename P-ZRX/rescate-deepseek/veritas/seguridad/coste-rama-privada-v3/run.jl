#!/usr/bin/env julia
# run.jl — CLI reproducible de CRP-v0.3.
#   env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 24
using Dates, Printf, Random, StableRNGs
include(joinpath(@__DIR__, "src", "CosteRamaPrivadaV3.jl"))
using .CosteRamaPrivadaV3

_arg(n, d) = (i = findfirst(==(n), ARGS); i === nothing ? d : ARGS[i+1])
const SEMILLA = parse(UInt64, _arg("--seed", "0x5a5a"))
const REPS = parse(Int, _arg("--replicas", "24"))
const RES = joinpath(@__DIR__, "resultados"); mkpath(RES)
salida(n, f) = (open(joinpath(RES, n), "w") do io; f(io); end; println("escrito ", n))

const W = let sr = UInt64(1); fld(big(2)^128, BigInt(sr) + 1); end   # peso unidad

salida("ENTORNO.txt", io -> begin
    println(io, "CRP-v0.3 — entorno")
    println(io, "fecha_utc = ", Dates.now(Dates.UTC))
    println(io, "julia = ", VERSION, "  cpu = ", Sys.CPU_NAME)
    println(io, "hilos = ", Threads.nthreads(:default), "/", Threads.nthreads(:interactive))
    println(io, "semilla = ", SEMILLA, "  replicas = ", REPS)
    println(io, "peso_unidad_blue_work = ", W)
    println(io, "presupuesto = max 64 GiB RAM, 24 hilos")
end)

salida("EVENTOS.txt", io -> begin
    println(io, "P_terminal(T), P_first_passage(≤T), P_eventual — objetos separados")
    println(io, "z0  T     alpha  terminal        paso            eventual        cota_terminal")
    for z0 in (4, 8)
        for T in (20, 100, 400)
            for a in (0.2, 0.4)
                r = resultado_eventos(Float64, z0, 1 - a, a, T)
                @printf(io, "%2d %4d  %.1f    %.6e  %.6e  %.6e  (%.3e,%.3e)\n",
                        z0, T, a, r.p_terminal, r.p_paso, r.p_eventual,
                        r.p_terminal_cota[1], r.p_terminal_cota[2])
            end
        end
    end
    println(io, "\nalpha_prob por evento (d=4, p0=0.05, T=100):")
    for ev in (:terminal, :paso, :eventual)
        ap = alpha_prob_determinista(4, 0.05; evento=ev, Tol=100)
        println(io, "  ", ev, " → ", ap)
    end
end)

salida("SWEEP-TOY.txt", io -> begin
    println(io, "Toy escalar aditivo: frontera media α_drift = 1/(S+1)")
    println(io, "S  1/(S+1)   g en la frontera   P_sup(d=4,T=200) en 1/(S+1)±0.03")
    for S in (1, 2, 4, 8, 16, 24)
        a = 1 / (S + 1)
        pb = prob_superar_toy_S(Float64, max(0.0, a - 0.03), S, 4, 200).p_exito_upper
        pa = prob_superar_toy_S(Float64, a + 0.03, S, 4, 200).p_exito_upper
        @printf(io, "%2d  %.6f  %+.1e        bajo=%.4e  alto=%.4e\n",
                S, a, toy_S_deriva(a, S), pb, pa)
    end
end)

function celda_dag(S, alpha, T, d_bloques, delta, k, modo)
    cfg = ConfigSimV3(; n_honestos=4, alpha=alpha, delta=delta, S=S, T=T, t_fork=1,
                      k=k, modo_correlacion=modo)
    d = d_bloques * W
    emax = 0; esum = 0; epmax = 0; rgdr = 0
    for r in 1:REPS
        res = simular_v3!(cfg, StableRNG(SEMILLA + UInt64(r)))   # semilla NO depende de d
        m = maximum(res.W_priv_terminal; init=big(0))
        s = sum(res.W_priv_terminal; init=big(0))                # post-fork: prefijo una vez
        m - res.W_pub > d && (emax += 1)
        s - res.W_pub > d && (esum += 1)
        maximum(res.W_priv_paso; init=big(-1) * big(10)^40) > d && (epmax += 1)
        rgdr += get(res.rechazos, :gdr, 0)
    end
    return (emax=emax, esum=esum, epmax=epmax, rgdr=rgdr)
end

salida("SWEEP-DAG.txt", io -> begin
    println(io, "Barrido DAG. S={1,2,4,8,16,24}; α a ambos lados de 1/(S+1) y de 1/2;")
    println(io, "d en unidades de blue_work (", W, " por bloque); T=200, Δ=2, k=30;")
    println(io, REPS, " réplicas/celda; correlación derivada.")
    println(io, "S  alpha/d  max_terminal/REPS  max_1apaso/REPS  suma_terminal/REPS  rgdr")
    for S in (1, 2, 4, 8, 16, 24)
        b = 1 / (S + 1)
        grid = unique(clamp.([b - 0.05, b, b + 0.05, 0.45], 0.0, 0.48))
        alphaS = Float64[]; exmax = Int[]
        for a in grid
            for dbl in (0, 2)
                c = celda_dag(S, a, 200, dbl, 2, 30, :derivada)
                @printf(io, "%2d  %.2f/%d  %4d/%d           %4d/%d          %4d/%d          %d\n",
                        S, a, dbl, c.emax, REPS, c.epmax, REPS, c.esum, REPS, c.rgdr)
                if dbl == 0
                    push!(alphaS, a); push!(exmax, c.emax)
                end
            end
        end
        res = alpha_prob_simultaneo(alphaS, exmax, REPS, 0.05; gamma_total=0.05)
        println(io, "    α_prob R-FIN-5 (S=", S, ", evento terminal, cobertura simultánea): ", res)
    end
    println(io, "  (celdas 0/", REPS, " NO se llaman frontera; `rgdr`>0 indica ramas")
    println(io, "   truncadas por s_max=150, que sesgan las celdas de α bajo hacia abajo)")
end)

salida("VARIOS.txt", io -> begin
    println(io, "Sensibilidad a T, d, Δ, k (S=4, α=0.2, regla R-FIN-5=max, d=2 bloques)")
    println(io, "T    Δ   k   max_term/REPS   max_paso/REPS")
    for T in (80, 200, 400), delta in (1, 2, 6), k in (10, 30)
        c = celda_dag(4, 0.2, T, 2, delta, k, :derivada)
        @printf(io, "%4d %3d %3d  %4d/%d        %4d/%d\n", T, delta, k,
                c.emax, REPS, c.epmax, REPS)
    end
end)

salida("CORRELACION.txt", io -> begin
    println(io, "Controles de correlación de flujos (S=4, α=0.3, T=200, Δ=2, k=30)")
    for modo in (:perfecta, :iid, :derivada)
        cfg = ConfigSimV3(; n_honestos=4, alpha=0.3, delta=2, S=4, T=200, t_fork=1,
                          k=30, modo_correlacion=modo)
        r = simular_v3!(cfg, StableRNG(33))
        uniq = length(unique(r.W_priv_terminal))
        @printf(io, "%-9s W_priv distintos=%d  W_priv[1]=%s  η_h=%.3f  η_a=%s\n",
                String(modo), uniq, string(r.W_priv_terminal[1]), r.eta_h,
                string(round.(r.eta_a, digits=3)))
    end
    println(io, "perfecta ⇒ S flujos idénticos (recupera S=1). iid ⇒ identidad 1−E[F^S].")
end)

salida("U2U3.txt", io -> begin
    println(io, "Fixtures U2/U3 y orden explícito (flujo → validez → U2 → color U3″)")
    fu = fixture_u2_u3(; k=30)
    println(io, "  mismo billete en ramas disjuntas, fusionador: colores=", fu.colores,
            "  una_u3=", fu.una_u3)
    fm = fixture_u2_misma_rama(; k=30)
    println(io, "  mismo billete dentro de una rama: aceptado=", fm.aceptado,
            " motivo=", fm.motivo)
    iny = collect(10:10:100)
    fa = construir_flujo(; rama=0, t_fork=5, inyecciones=iny)
    fb = construir_flujo(; rama=1, t_fork=5, inyecciones=iny)
    println(io, "  prefijos compatibles en slot 5: ", compatible_rfin5(fa, fb, 5))
    println(io, "  prefijos incompatibles en slot 15: ", compatible_rfin5(fa, fb, 15),
            " (R-FIN-5 rechaza ANTES de colorear)")
    println(io, "  el flujo se comprueba antes de U2/U3: una fusión con flujo divergente")
    println(io, "  se rechaza aunque los billetes fueran únicos.")
end)

salida("ETA.txt", io -> begin
    println(io, "η_h y η_a por separado (S=4, α∈{0.1,0.2,0.3}, T=200, Δ=2, k=30)")
    println(io, "alpha  η_h(media)  η_a(media)  n_rojos_h  n_rojos_a")
    for a in (0.1, 0.2, 0.3)
        eh = 0.0; ea = 0.0; rh = 0; ra = 0
        for r in 1:REPS
            cfg = ConfigSimV3(; n_honestos=4, alpha=a, delta=2, S=4, T=200, t_fork=1,
                              k=30, modo_correlacion=:derivada)
            res = simular_v3!(cfg, StableRNG(SEMILLA + UInt64(r)))
            eh += res.eta_h; ea += sum(res.eta_a) / length(res.eta_a)
            rh += res.rojos_h; ra += res.rojos_a
        end
        @printf(io, "%.2f   %.4f      %.4f      %d          %d\n",
                a, eh / REPS, ea / REPS, rh, ra)
    end
    println(io, "η se mide, no se supone η_h=η_a. Sin IC de bloque (muestra de rojos);")
    println(io, "si la muestra de rojos es insuficiente, la curva con rojos queda INCONCLUSA.")
end)

salida("VEREDICTO.txt", io -> begin
    println(io, "Pendientes que impiden cerrar el umbral protocolario:")
    for (r, e) in (("controlador C-HDR-06", "ventana/arranque/redondeos"),
                   ("R-FIN-5", "candidata; PoT AES no integrado"),
                   ("C-GD-11", "5 pendientes"),
                   ("finalidad R-FIN-7/F", "F provisional; Δ sin medir"),
                   ("S_adversario", "sin hardware compatible"))
        println(io, " - ", r, " → ", e)
    end
    println(io, frase_veredicto(false))
end)
println("CRP-v0.3 terminado.")
