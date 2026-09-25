#!/usr/bin/env julia
# run.jl — CLI reproducible de T02 (ORDEN-T02 §4).
#
#   julia --project=. run.jl --seed 0x5a5a --replicas 100000 --escenario todos
#
# Escribe CSV crudos por escenario en resultados/.

include("src/T02.jl")
using .T02
using Printf, Statistics

const Mod = T02.Modelo
const Ref = T02.Referencia
const Rap = T02.Rapido
const Val = T02.Validacion

# ---------------------------------------------------------------------------
# Rejilla efectiva (valores de prueba de §3.6; se declara en METODO.md).
# Para E2 se recorre una sensibilidad alrededor de un punto base; los puntos con
# a >= 1/2 usan F_slots <= 1000 para acotar el coste del horizonte.
# ---------------------------------------------------------------------------
function puntos_e1()
    pts = Mod.PuntoE1[]
    for h in Mod.H_GRID, z in Mod.Z_GRID
        push!(pts, Mod.PuntoE1(length(pts) + 1, h, z))
    end
    return pts
end

function puntos_e2()
    pts = Mod.PuntoE2[]
    push!(pts, Mod.PuntoE2(1, 0.25, 0.4, 6, 0.1, 0.9, 1000.0))   # base
    for h in Mod.H_GRID
        push!(pts, Mod.PuntoE2(length(pts) + 1, h, 0.4, 6, 0.1, 0.9, 1000.0))
    end
    for a in Mod.A_GRID
        Fs = a >= 0.5 ? 100.0 : 1000.0
        push!(pts, Mod.PuntoE2(length(pts) + 1, 0.25, a, 6, 0.1, 0.9, Fs))
    end
    for k in Mod.K_GRID
        push!(pts, Mod.PuntoE2(length(pts) + 1, 0.25, 0.4, k, 0.1, 0.9, 1000.0))
    end
    for r in Mod.R_GRID
        push!(pts, Mod.PuntoE2(length(pts) + 1, 0.25, 0.4, 6, r, 0.9, 1000.0))
    end
    for p in Mod.P_GRID
        push!(pts, Mod.PuntoE2(length(pts) + 1, 0.25, 0.4, 6, 0.1, p, 1000.0))
    end
    for Fs in Mod.F_GRID                       # base a=0.4 < 1/2
        push!(pts, Mod.PuntoE2(length(pts) + 1, 0.25, 0.4, 6, 0.1, 0.9, Fs))
    end
    for h in (0.4, 0.6, 0.9), a in (0.25, 0.4, 0.45)   # pregunta falsable
        push!(pts, Mod.PuntoE2(length(pts) + 1, h, a, 6, 0.1, 0.9, 1000.0))
    end
    return pts
end

function puntos_e3()
    # Producto cartesiano completo de la rejilla (las fórmulas son O(1) por punto).
    pts = Mod.PuntoE3[]
    for h in Mod.H_GRID, a in Mod.A_GRID, k in Mod.K_GRID, delta in Mod.DELTA_GRID,
        r in Mod.R_GRID, p in Mod.P_GRID, Fs in Mod.F_GRID
        push!(pts, Mod.PuntoE3(length(pts) + 1, h, a, k, delta, r, p, Fs))
    end
    return pts
end

function puntos_e4()
    pts = Mod.PuntoE4[]
    for h in (0.1, 0.25, 0.4, 0.5, 0.6, 0.9), Mdep in Mod.MDEP_GRID
        push!(pts, Mod.PuntoE4(length(pts) + 1, h, Mdep))
    end
    return pts
end

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
function parse_seed(s::AbstractString)
    if startswith(s, "0x") || startswith(s, "0X")
        return parse(UInt64, s[3:end]; base = 16)
    end
    return parse(UInt64, s)
end

function parse_args(args)
    seed = UInt64(0x5a5a)
    replicas = 100_000
    escenario = "todos"
    hilos = Threads.nthreads()
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--seed"
            seed = parse_seed(args[i+1]); i += 2
        elseif a == "--replicas"
            replicas = parse(Int, args[i+1]); i += 2
        elseif a == "--escenario"
            escenario = args[i+1]; i += 2
        elseif a == "--hilos"
            hilos = parse(Int, args[i+1]); i += 2
        else
            error("argumento no reconocido: $a")
        end
    end
    return (seed = seed, replicas = replicas, escenario = escenario, hilos = hilos)
end

p99(v) = isempty(v) ? NaN : quantile(v, 0.99)
p50(v) = isempty(v) ? NaN : quantile(v, 0.50)

# ---------------------------------------------------------------------------
# Escenarios
# ---------------------------------------------------------------------------
function ejecutar_e1(reps::Int, seed::UInt64, dir::String)
    open(joinpath(dir, "E1.csv"), "w") do io
        println(io, "h,z,p_formula,p_mc,lo999,hi999,n,exitos,cumple")
        for pt in puntos_e1()
            exito = Vector{Bool}(undef, reps)
            k = Rap.correr_e1!(exito, pt, reps, seed)
            p, lo, hi = Mod.wilson(k, reps)
            pf = Ref.e1_prob(pt.z, pt.h)
            @printf(io, "%.4f,%d,%.12g,%.8f,%.8f,%.8f,%d,%d,%s\n",
                    pt.h, pt.z, pf, p, lo, hi, reps, k, lo <= pf <= hi ? "si" : "no")
        end
    end
    # vector de regresión: tabla publicada del artículo
    mx = Val.error_tabla_nakamoto()
    open(joinpath(dir, "E1_tabla_nakamoto.csv"), "w") do io
        println(io, "h,z,p_articulo,p_formula,error")
        for (h, z, pa) in Ref.TABLA_NAKAMOTO
            @printf(io, "%.4f,%d,%.7f,%.12g,%.3e\n", h, z, pa, Ref.e1_prob(z, h),
                    abs(Ref.e1_prob(z, h) - pa))
        end
    end
    @printf("E1: error máximo vs tabla publicada = %.3e (< 1e-6: %s)\n",
            mx, mx < 1e-6 ? "sí" : "NO")
    return mx
end

function ejecutar_e2(reps::Int, seed::UInt64, dir::String)
    open(joinpath(dir, "E2.csv"), "w") do io
        println(io, "h,a,k,r,p,Fs,M,n," *
                    "ge_nuevo_exitos,ge_nuevo_p,ge_nuevo_lo,ge_nuevo_hi," *
                    "ge_online_exitos,ge_online_p,ge_online_lo,ge_online_hi," *
                    "gt_nuevo_p,gt_online_p,pow_medio,slots_ge_media,slots_ge_p50,slots_ge_p99")
        for pt in puntos_e2()
            res = Rap.correr_e2(pt, reps, seed)
            pn, lon, hin = Mod.wilson(res.ge_nuevo, reps)
            po, loo, hio = Mod.wilson(res.ge_online, reps)
            @printf(io, "%.4f,%.4f,%d,%.6g,%.4f,%s,%d,%d,%.8f,%.8f,%.8f,%.8f,%d,%.8f,%.8f,%.8f,%.8f,%.8f,%.6f,%.4f,%.4f,%.4f\n",
                    pt.h, pt.a, pt.k, pt.r, pt.p, isinf(pt.Fs) ? "inf" : string(pt.Fs),
                    Mod.horizonte(pt.Fs), reps,
                    res.ge_nuevo, pn, lon, hin,
                    res.ge_online, po, loo, hio,
                    res.gt_nuevo / reps, res.gt_online / reps,
                    res.pow_medio, isempty(res.slots_ge) ? NaN : mean(res.slots_ge),
                    p50(res.slots_ge), p99(res.slots_ge))
        end
    end
    println("E2: $(length(puntos_e2())) puntos escritos")
end

function ejecutar_e3(reps::Int, seed::UInt64, dir::String)
    open(joinpath(dir, "E3.csv"), "w") do io
        println(io, "h,a,k,delta,r,p,Fs,fc1_particion_exacta,fc3_exacta,coste_trabajo")
        for pt in puntos_e3()
            fc1, fc3 = Ref.e3_probabilidades(pt.h, pt.a, pt.k, pt.delta, pt.r, pt.p, pt.Fs)
            @printf(io, "%.4f,%.4f,%d,%.4g,%.6g,%.4f,%s,%.10g,%.10g,%.6g\n",
                    pt.h, pt.a, pt.k, pt.delta, pt.r, pt.p,
                    isinf(pt.Fs) ? "inf" : string(pt.Fs), fc1, fc3, pt.k * (1 + pt.delta))
        end
    end
    println("E3: $(length(puntos_e3())) puntos escritos")
    # validación MC de una submuestra
    chk = Val.validar_e3(min(reps, 20_000), seed)
    fallos = count(!c.ok for c in chk)
    open(joinpath(dir, "E3_validacion_mc.csv"), "w") do io
        println(io, "etiqueta,n,exitos,p_mc,lo999,hi999,p_ref,ok")
        for c in chk
            @printf(io, "%s,%d,%d,%.8f,%.8f,%.8f,%.8f,%s\n",
                    replace(c.etiqueta, "," => ";"), c.n, c.exitos, c.p_mc, c.lo, c.hi,
                    c.p_ref, c.ok ? "si" : "no")
        end
    end
    println("E3 validación MC: $(length(chk)) chequeos, $fallos fuera del IC")
    return fallos
end

function ejecutar_e4(reps::Int, seed::UInt64, dir::String)
    open(joinpath(dir, "E4.csv"), "w") do io
        println(io, "h,Mdep,n,cortes,p_corte,lo999,hi999,frac_censurado," *
                    "t_corte_media,t_corte_p50,t_corte_p99,frac_adv_media,frac_adv_p99")
        for pt in puntos_e4()
            res = Rap.correr_e4(pt, reps, seed)
            p, lo, hi = Mod.wilson(res.cortes, reps)
            @printf(io, "%.4f,%d,%d,%d,%.8f,%.8f,%.8f,%.8f,%.4f,%.4f,%.4f,%.6f,%.6f\n",
                    pt.h, pt.Mdep, reps, res.cortes, p, lo, hi,
                    1 - p,
                    isempty(res.t_corte) ? NaN : mean(res.t_corte),
                    p50(res.t_corte), p99(res.t_corte),
                    isempty(res.frac_adv) ? NaN : mean(res.frac_adv),
                    p99(res.frac_adv))
        end
    end
    println("E4: $(length(puntos_e4())) puntos escritos")
end

function leer_csv(dir::String, name::String)
    path = joinpath(dir, name)
    isfile(path) || return String[], Vector{Vector{SubString{String}}}()
    ls = readlines(path)
    header = split(ls[1], ',')
    rows = [split(l, ',') for l in ls[2:end]]
    return header, rows
end

# Resumen agregado a partir de los CSV crudos.
function escribir_resumen(dir::String)
    open(joinpath(dir, "resumen.csv"), "w") do io
        println(io, "escenario,metrica,valor")
        if isfile(joinpath(dir, "E1_tabla_nakamoto.csv"))
            _, rows = leer_csv(dir, "E1_tabla_nakamoto.csv")
            mx = maximum(parse(Float64, r[5]) for r in rows)
            println(io, "E1,max_error_vs_tabla_nakamoto,$mx")
            _, e1 = leer_csv(dir, "E1.csv")
            nc = count(r -> r[9] == "si", e1)
            println(io, "E1,puntos_grid_mc_dentro_IC,$nc/$(length(e1))")
        end
        if isfile(joinpath(dir, "E2.csv"))
            _, e2 = leer_csv(dir, "E2.csv")
            ref = count(r -> parse(Float64, r[2]) < 0.5 && parse(Float64, r[11]) > 1e-3, e2)
            println(io, "E2,puntos_totales,$(length(e2))")
            println(io, "E2,refutadores_a<1/2_y_lo>1e-3,$ref")
            bv = -1.0; best = e2[1]
            for r in e2
                parse(Float64, r[2]) < 0.5 || continue
                v = parse(Float64, r[10])
                if v > bv
                    bv = v; best = r
                end
            end
            println(io, "E2,max_ge_nuevo_con_a<1/2,$bv (h=$(best[1]),a=$(best[2]),k=$(best[3]),Fs=$(best[6]))")
        end
        if isfile(joinpath(dir, "E3.csv"))
            _, e3 = leer_csv(dir, "E3.csv")
            mfc3 = maximum(parse(Float64, r[9]) for r in e3)
            nfc3 = count(r -> parse(Float64, r[9]) > 1e-3, e3)
            nref = count(r -> parse(Float64, r[2]) < 0.5 && parse(Float64, r[9]) > 1e-3, e3)
            mfc1 = maximum(parse(Float64, r[8]) for r in e3)
            println(io, "E3,puntos_totales,$(length(e3))")
            println(io, "E3,max_fc3,$mfc3")
            println(io, "E3,puntos_fc3>1e-3,$nfc3")
            println(io, "E3,puntos_fc3>1e-3_con_a<1/2,$nref")
            println(io, "E3,max_fc1_particion,$mfc1")
        end
        if isfile(joinpath(dir, "E4.csv"))
            _, e4 = leer_csv(dir, "E4.csv")
            println(io, "E4,puntos_totales,$(length(e4))")
            for r in e4
                println(io, "E4,censurado_h=$(r[1])_Mdep=$(r[2]),$(r[8])")
            end
        end
    end
    println("resumen.csv escrito")
end

function main()
    opt = parse_args(ARGS)
    dir = joinpath(@__DIR__, "resultados")
    mkpath(dir)
    @printf("T02 run: seed=0x%x replicas=%d escenario=%s hilos=%d\n",
            opt.seed, opt.replicas, opt.escenario, Threads.nthreads())
    if opt.escenario in ("E1", "todos")
        ejecutar_e1(opt.replicas, opt.seed, dir)
    end
    if opt.escenario in ("E2", "todos")
        ejecutar_e2(opt.replicas, opt.seed, dir)
    end
    if opt.escenario in ("E3", "todos")
        ejecutar_e3(opt.replicas, opt.seed, dir)
    end
    if opt.escenario in ("E4", "todos")
        ejecutar_e4(opt.replicas, opt.seed, dir)
    end
    escribir_resumen(dir)
    println("run.jl terminado")
end

main()
