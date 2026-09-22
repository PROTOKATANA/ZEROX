#!/usr/bin/env julia
#= espacio-prestado-v1 · run.jl — CLI reproducible.
   Genera los artefactos publicados en `resultados/` a partir de los símbolos del encargo.
   Ningún parámetro de consenso se fija aquí: todo entra por CLI o queda como columna.

   Uso:
     julia --project=. run.jl --seed 0x5052455354414d4f --tarea f1
     julia --project=. run.jl --tarea f2 --F 1019,3547,3600,7200
     julia --project=. run.jl --tarea f3 --tarea f4 --tarea f5 --tarea f6
=#

using Printf

const DIR = @__DIR__

include(joinpath(DIR, "src", "modelo.jl"))
include(joinpath(DIR, "src", "referencia.jl"))
include(joinpath(DIR, "src", "rapido.jl"))

using .Modelo
using .Referencia
using .Rapido

const RES = joinpath(DIR, "resultados")

# ---------------------------------------------------------------- utilidades

function arg_float(args, clave, por_defecto)
    i = findfirst(==(clave), args)
    i === nothing && return por_defecto
    return parse(Float64, args[i+1])
end

function arg_int(args, clave, por_defecto)
    i = findfirst(==(clave), args)
    i === nothing && return por_defecto
    return parse(Int, args[i+1])
end

function arg_lista(args, clave, por_defecto)
    i = findfirst(==(clave), args)
    i === nothing && return por_defecto
    return [parse(Float64, s) for s in split(args[i+1], ",")]
end

function arg_lista_int(args, clave, por_defecto)
    i = findfirst(==(clave), args)
    i === nothing && return por_defecto
    return [parse(Int, s) for s in split(args[i+1], ",")]
end

function arg_tareas(args)
    out = String[]
    for i in eachindex(args)
        args[i] == "--tarea" && push!(out, args[i+1])
    end
    return isempty(out) ? ["f1", "f3", "f4", "f5", "f6"] : out
end

# -------------------------------------------------------- F1 · superficie exacta

"""
    f1(io)

Superficie `α*(β_d, β_x, η_h, η_a)` exacta, con la comprobación de los dos casos
particulares que pide el PROMPT §2 y el signo de `g` a ambos lados de la frontera.
"""
function f1(io)
    println(io, "# F1 · superficie de deriva exacta (Rational{BigInt})")
    println(io, "# α*(βd,βx,ηh,ηa) = (ηh − ηa·βd − (ηh+ηa)·βx)/(ηh+ηa)")
    println(io, "betad\tbetax\tetah\tetaa\talpha_estrella\tg_en_alpha_estrella")
    for (βd, βx, ηh, ηa) in ((0//1, 0//1, 1//1, 1//1),
                             (1//10, 0//1, 1//1, 1//1),
                             (1//3, 0//1, 1//1, 1//1),
                             (1//2, 0//1, 1//1, 1//1),
                             (2//3, 0//1, 1//1, 1//1),
                             (0//1, 1//10, 1//1, 1//1),
                             (0//1, 1//4, 1//1, 1//1),
                             (0//1, 1//2, 1//1, 1//1),
                             (1//3, 1//3, 1//1, 1//1),
                             (1//4, 1//4, 1//1, 1//1),
                             (1//4, 1//4, 99//100, 1//1),
                             (1//4, 1//4, 1//1, 9//10))
        αs = alpha_estrella(βd, βx, ηh, ηa)
        g = deriva(Deriva(αs, βd, βx, ηh, ηa))
        @printf(io, "%s\t%s\t%s\t%s\t%.10f\t%s\n", βd, βx, ηh, ηa, Float64(αs), g)
    end
    # Comprobación exacta de casos particulares.
    @assert alpha_estrella(0//1, 0//1, 1//1, 1//1) == 1//2
    @assert alpha_estrella(1//3, 0//1, 1//1, 1//1) == 1//3
    @assert alpha_estrella(1//2, 0//1, 1//1, 1//1) == 1//4
    @assert alpha_estrella(0//1, 1//4, 1//1, 1//1) == 1//4
    println(io, "# casos particulares exactos: α*(0,0,1,1)=1/2; α*(1/3,0,1,1)=1/3;")
    println(io, "# α*(1/2,0,1,1)=1/4; α*(0,1/4,1,1)=1/4. Todos con g = 0 exacto.")
    println(io, "# β_x baja α* el doble que β_d (con η=1): Δα*=βx frente a Δα*=βd/2.")
end

# ---------------------------------------------------------- F2 · ventana finita

"""
    f2(io, Fs, αs, βd_rel, ηh, ηa, Tmax)

`P_first_passage` y `P_terminal` para la rejilla del PROMPT §3 F2. El déficit inicial se
calcula con `deficit_esperado` (espacio → peso) y se redondea al entero más próximo en
unidades de peso. Etiqueta el resultado como CONDICIONADO al puente H-PUENTE.
"""
function f2(io, Fs, αs, βd_rel, βx_rel, ηh, ηa)
    println(io, "# F2 · ventana F (paseo de peso ±1). CONDICIONADO a H-PUENTE")
    println(io, "# (α, β son ESPACIO; q_adv = tasa del ADVERSARIO por paso = primer argumento de primera_dp)")
    println(io, "# P_primera y P_terminal se calculan con la DP EXACTA en todas las celdas.")
    println(io, "# etiqueta: exacto | imposible (d > F: hacen falta más pasos del adversario que la ventana)")
    println(io, "# NOTA DE MÉTODO: una versión anterior de este fichero publicaba (1−q_adv)^F como si fuera")
    println(io, "# la probabilidad de la celda. NO es una cota: con F=1019, α=0.33, βd=0 el valor real es")
    println(io, "# 9,75e-108 y (1−q)^F = 10^-177 < 9,75e-108. Corregido; ver PROGRESO.md O6.")
    println(io, "F\talpha\tbetad_rel\tbetax_rel\tq_adv\td_deficit\tP_primera\tlog10_P_primera\tP_terminal\tetiqueta")
    for F in Fs, α in αs, br in βd_rel, xr in βx_rel
        βd = br * (1 - α)
        βx = xr * (1 - α)
        (α + βd + βx > 1) && continue
        qa = p_de_alpha(α, βd, βx, ηh, ηa)
        dpeso = deficit_esperado(α, βd, βx, ηh, ηa, F)
        dpeso < 0 && (dpeso = 0.0)
        d = round(Int, dpeso)
        if d > F
            @printf(io, "%d\t%.3f\t%.3f\t%.3f\t%.10f\t%d\t0.000000e+00\t-inf\t0.000000e+00\timposible\n",
                    F, α, br, xr, qa, d)
        else
            r = primera_dp(qa, d, F)
            if r.paso > 0
                @printf(io, "%d\t%.3f\t%.3f\t%.3f\t%.10f\t%d\t%.6e\t%.4f\t%.6e\texacto\n",
                        F, α, br, xr, qa, d, r.paso, log10(r.paso), 0.0)
            elseif qa < 0.5
                # La DP subdesborda Float64 (el valor real es < 10^-308). Se publica el
                # LÍMITE EXACTO (q/(1−q))^(d+1), que es cota superior de P_first_passage,
                # en log10. No se publica 0: no es 0, es menor que el suelo de Float64.
                lim = (d + 1) * log10(qa / (1 - qa))
                println(io, @sprintf("%d\t%.3f\t%.3f\t%.3f\t%.10f\t%d\t%.6e\t%.4f\t%.6e\tlimite_ruina",
                        F, α, br, xr, qa, d, 0.0, lim, 0.0))
            else
                # qa ≥ 0.5: el adversario no es minoría y el límite es 1 (paseo recurrente).
                println(io, @sprintf("%d\t%.3f\t%.3f\t%.3f\t%.10f\t%d\t%.6e\t%.4f\t%.6e\trecurrente",
                        F, α, br, xr, qa, d, 1.0, 0.0, 0.0))
            end
        end
    end
end

"""
    f2_minimo_betad(io, F, α, ηh, ηa, umbral)

Para cada `F` y `α`, el menor `β_d` (como fracción de `1−α`) tal que
`P_first_passage ≥ umbral`. Barrido por bisección sobre el déficit continuo.
"""
function f2_minimo_betad(io, Fs, αs, ηh, ηa, umbral)
    println(io, "# F2b · β_d mínimo (relativo a 1−α) para P_primera ≥ $umbral, β_x = 0")
    println(io, "F\talpha\tbetad_rel_min\tP_en_el_minimo\tp\td")
    for F in Fs, α in αs
        lo, hi = 0.0, 1.0
        for _ in 1:60
            mid = (lo + hi) / 2
            βd = mid * (1 - α)
            p = p_de_alpha(α, βd, 0.0, ηh, ηa)
            dp = max(deficit_esperado(α, βd, 0.0, ηh, ηa, F), 0.0)
            d = round(Int, dp)
            P = primera_dp(p, d, F).paso
            if P ≥ umbral
                hi = mid
            else
                lo = mid
            end
        end
        βd = hi * (1 - α)
        p = p_de_alpha(α, βd, 0.0, ηh, ηa)
        dp = max(deficit_esperado(α, βd, 0.0, ηh, ηa, F), 0.0)
        d = round(Int, dp)
        P = primera_dp(p, d, F).paso
        @printf(io, "%d\t%.3f\t%.6f\t%.6e\t%.10f\t%d\n", F, α, hi, P, p, d)
    end
end

# ------------------------------------------------------------ F3 · el juego

"""
    f3(io, pg_base, κs, qs, ρrets, Tvs, N, bsoborno)

Equilibrio del granjero: para cada `(κ, q, ρ_ret, T_v)`, el soborno necesario por
reclutado y el número de reclutados que el atacante puede pagar con un presupuesto
`bsoborno` (en unidades de emisión). Sin castigo (`κ·q = 0`) el soborno necesario es 0.
"""
function f3(io, ingreso, c_r, M, λ, N, bsoborno, κs, qs, ρrets, Tvs)
    println(io, "# F3 · soborno necesario por reclutado (unidades de emisión)")
    println(io, "# ingreso=$ingreso c_r=$c_r M=$M λ=$λ  N_recl=$N  presupuesto=$bsoborno")
    println(io, "kappa\tq\trho_ret\tT_v\tperdida_total\tsoborno_necesario\treclutados_pagables\tbeta_d_max")
    for κ in κs, q in qs, ρ in ρrets, Tv in Tvs
        pg = PerdidaGranjero(ρ, Tv, ingreso, c_r, M, λ)
        pt = perdida_total(pg)
        b = max(κ * q * pt, 0.0)
        # reclutados pagables: b_por_reclutado · n = bsoborno (b = 0 ⇒ sin cota por precio)
        n_pag = b > 0 ? floor(bsoborno / b) : Inf
        βdmax = n_pag / N            # fracción del espacio honesto reclutado
        @printf(io, "%.2f\t%.2f\t%.2f\t%.0f\t%.6e\t%.6e\t%s\t%.6f\n",
                κ, q, ρ, Tv, pt, b, n_pag == Inf ? "sin_cota" : string(Int(n_pag)), βdmax)
    end
end

# ------------------------------------------------- F4 · coste absoluto del ataque

function f4(io, ingreso, c_r, M, λ, V_semanas, emision_semanal, N, κs, qs, ρ, Tv)
    println(io, "# F4 · coste relativo y absoluto del ataque, en SEMANAS DE EMISIÓN")
    println(io, "# emisión semanal = $emision_semanal u.e.; V (valor del ataque) = $V_semanas semanas")
    println(io, "kappa\tq\tsoborno_por_reclutado\tsoborno_total\tpot_nucleos_slot\tpot_total_V\ttotal_V\tV_en_u_e\trentable")
    for κ in κs, q in qs
        pg = PerdidaGranjero(ρ, Tv, ingreso, c_r, M, λ)
        b = max(κ * q * perdida_total(pg), 0.0)
        soborno_total = b * N
        pot = 0.092 * V_semanas * 604800     # 0,092 núcleos por reclutado y slot (cota inferior)
        total = soborno_total + pot
        V_ue = V_semanas * emision_semanal
        @printf(io, "%.2f\t%.2f\t%.6e\t%.6e\t%.3f\t%.6e\t%.6e\t%.6e\t%s\n",
                κ, q, b, soborno_total, pot, pot, total, V_ue,
                V_ue > total ? "SI" : "NO")
    end
end

# ------------------------------------------------- F5 · región (ρ_ret, T_v)

"""
    f5(io, ...)

Región mínima de `(ρ_ret, T_v)` para que `pérdida esperada > soborno` frente a un valor
de ataque `V` (en unidades de emisión), con `n` reclutados y cobertura `κ·q`.
`T_v` además debe superar la ventana en que la evidencia puede aparecer: `F + margen`.
"""
function f5(io, ingreso, c_r, M, λ, V_ue, N, κs, qs, ρrets, Tvs, F)
    println(io, "# F5 · región (ρ_ret, T_v): pérdida esperada > soborno ofrecido")
    println(io, "# V=$V_ue u.e.; N_recl=$N; F=$F slots; T_v debe superar F+margen")
    println(io, "kappa\tq\trho_ret\tT_v\tperdida_esperada_por_reclutado\tsoborno_max_por_reclutado\tcumple\tTv_supera_F")
    sob_max = V_ue / N
    for κ in κs, q in qs, ρ in ρrets, Tv in Tvs
        pg = PerdidaGranjero(ρ, Tv, ingreso, c_r, M, λ)
        pe = κ * q * perdida_total(pg)
        @printf(io, "%.2f\t%.2f\t%.4f\t%.0f\t%.6e\t%.6e\t%s\t%s\n",
                κ, q, ρ, Tv, pe, sob_max, pe > sob_max ? "SI" : "NO", Tv > F ? "SI" : "NO")
    end
end

# ------------------------------------------------- F6 · coste para el honesto

function f6(io, ingreso, c_r, M, λ, ε_h, ρrets, Tvs)
    println(io, "# F6 · pérdida esperada del honesto que firma doble por accidente")
    println(io, "# tasa ε_h=$ε_h por año (nodos redundantes, reinicio con estado perdido)")
    println(io, "rho_ret\tT_v\tperdida_por_evento\tperdida_esperada_anual\tsoborno_que_igual")
    for ρ in ρrets, Tv in Tvs
        pg = PerdidaGranjero(ρ, Tv, ingreso, c_r, M, λ)
        pt = perdida_total(pg)
        @printf(io, "%.4f\t%.0f\t%.6e\t%.6e\t%.6e\n", ρ, Tv, pt, ε_h * pt, pt)
    end
end

# ---------------------------------------------------------------- main

function main()
    args = ARGS
    semilla = arg_int(args, "--seed", 0x5052455354414d4f)
    tareas = arg_tareas(args)
    mkpath(RES)

    Fs = arg_lista_int(args, "--F", [1_019, 3_547, 3_600, 7_200])
    αs = arg_lista(args, "--alpha", [0.10, 0.20, 0.33, 0.40])
    βd_rel = arg_lista(args, "--betad", [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0])
    βx_rel = arg_lista(args, "--betax", [0.0, 0.5, 1.0])
    ηh = arg_float(args, "--etah", 1.0)
    ηa = arg_float(args, "--etaa", 1.0)
    umbral = arg_float(args, "--umbral", 1e-6)

    # Símbolos económicos (entradas; NO se fijan como parámetros de consenso).
    ingreso = arg_float(args, "--ingreso", 1.0)
    c_r = arg_float(args, "--cr", 10.0)
    M = arg_float(args, "--madurez", 20.0)
    λ = arg_float(args, "--lambda", 1.0)
    N = arg_float(args, "--reclutados", 100.0)
    bsoborno = arg_float(args, "--presupuesto", 1.0e4)
    V_sem = arg_float(args, "--V", 4.0)
    emision_sem = arg_float(args, "--emision-semanal", 1.0e4)
    ε_h = arg_float(args, "--eps-honesto", 1.0e-3)
    κs = arg_lista(args, "--kappa", [0.0, 0.25, 0.5, 0.9, 1.0])
    qs = arg_lista(args, "--q", [1.0, 0.5, 0.1, 0.0])
    ρrets = arg_lista(args, "--rho", [0.0, 0.1, 0.25, 0.5, 1.0])
    Tvs = arg_lista(args, "--Tv", [0.0, 100.0, 1_000.0, 10_000.0, 100_000.0])

    println("# semilla = ", semilla, " (UInt64); Julia ", VERSION,
            "; hilos = ", Threads.nthreads(:default))
    println("# F = ", Fs, "  α = ", αs, "  η_h = ", ηh, "  η_a = ", ηa)

    for t in tareas
        if t == "f1"
            open(joinpath(RES, "F1-superficie.tsv"), "w") do io; f1(io); end
            println("F1 -> resultados/F1-superficie.tsv")
        elseif t == "f2"
            suf = let i = findfirst(==("--sufijo"), args); i === nothing ? "" : args[i+1]; end
            open(joinpath(RES, "F2-ventana" * suf * ".tsv"), "w") do io
                f2(io, Fs, αs, βd_rel, βx_rel, ηh, ηa)
            end
            open(joinpath(RES, "F2b-betad-minimo" * suf * ".tsv"), "w") do io
                f2_minimo_betad(io, Fs, αs, ηh, ηa, umbral)
            end
            println("F2 -> resultados/F2-ventana" * suf * ".tsv, F2b-betad-minimo" * suf * ".tsv")
        elseif t == "f3"
            open(joinpath(RES, "F3-juego.tsv"), "w") do io
                f3(io, ingreso, c_r, M, λ, N, bsoborno, κs, qs, ρrets, Tvs)
            end
            println("F3 -> resultados/F3-juego.tsv")
        elseif t == "f4"
            open(joinpath(RES, "F4-coste-absoluto.tsv"), "w") do io
                f4(io, ingreso, c_r, M, λ, V_sem, emision_sem, N, κs, qs, 0.5, 10_000.0)
            end
            println("F4 -> resultados/F4-coste-absoluto.tsv")
        elseif t == "f5"
            open(joinpath(RES, "F5-region.tsv"), "w") do io
                f5(io, ingreso, c_r, M, λ, V_sem * emision_sem, N, κs, qs, ρrets, Tvs,
                   maximum(Fs))
            end
            println("F5 -> resultados/F5-region.tsv")
        elseif t == "f6"
            open(joinpath(RES, "F6-honesto.tsv"), "w") do io
                f6(io, ingreso, c_r, M, λ, ε_h, ρrets, Tvs)
            end
            println("F6 -> resultados/F6-honesto.tsv")
        else
            @warn "tarea desconocida" t
        end
    end
end

main()
