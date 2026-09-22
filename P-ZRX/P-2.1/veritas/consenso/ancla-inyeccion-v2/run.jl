# ANCLA-v0.2 — CLI reproducible (LINEO §1). Ejecutar siempre con veritas/julia.sh.
#
#   run.jl puerta                              -> 4.0 analítica (resultados/puerta/)
#   run.jl 4a --celda <c> --replicas N [--seed 0x5A5A] [--offset 0] [--chunk 100]
#   run.jl ctrl9c --alpha 0.33 --smax 150 [--semillas 12]
#   run.jl ctrl11c --alpha 0.25 [--semillas 12]
#   run.jl bench
#   run.jl test
#
# Celdas 4a: hon-dms | hon-4 | hon-10 | hon-16 | v1-a10..v1-a45 | a3-a10..a3-a45 |
#            v2-a25 | v2-a40 | v3-a40
# Salida: resultados/4a/<celda>/{resumen.csv, w.csv, g.csv} (CSV, checkpoint por chunk).

using AnclaInyeccion
using Statistics
using Dates
using AnclaInyeccion.GhostdagRank

const SEED_DEF = 0x5A5A

function celda(nombre::String)
    A = Dict{String,Params4A}(
        "hon-dms" => Params4A(α=0.0, Δ=0.0, via=:honesta),
        "hon-4"   => Params4A(α=0.0, Δ=4.0, via=:honesta),
        "hon-10"  => Params4A(α=0.0, Δ=10.0, via=:honesta),
        "hon-16"  => Params4A(α=0.0, Δ=16.0, via=:honesta),
        "hon-10L" => Params4A(α=0.0, Δ=10.0, via=:honesta, H=4200, L_def=2000),
        "hon-16L" => Params4A(α=0.0, Δ=16.0, via=:honesta, H=4200, L_def=2000),
        "v1-a10"  => Params4A(α=0.10, Δ=4.0, via=:v1),
        "v1-a25"  => Params4A(α=0.25, Δ=4.0, via=:v1),
        "v1-a33"  => Params4A(α=0.33, Δ=4.0, via=:v1),
        "v1-a40"  => Params4A(α=0.40, Δ=4.0, via=:v1),
        "v1-a45"  => Params4A(α=0.45, Δ=4.0, via=:v1),
        "a3-a10"  => Params4A(α=0.10, Δ=4.0, via=:a3),
        "a3-a25"  => Params4A(α=0.25, Δ=4.0, via=:a3),
        "a3-a33"  => Params4A(α=0.33, Δ=4.0, via=:a3),
        "a3-a40"  => Params4A(α=0.40, Δ=4.0, via=:a3),
        "a3-a45"  => Params4A(α=0.45, Δ=4.0, via=:a3),
        "v2-a25"  => Params4A(α=0.25, Δ=4.0, via=:v2),
        "v2-a40"  => Params4A(α=0.40, Δ=4.0, via=:v2),
        "v3-a40"  => Params4A(α=0.40, Δ=4.0, via=:v3),
    )
    return A[nombre]
end

"Ejecuta la celda 4a con paralelismo por réplica y checkpoint por chunk."
function paso_4a(nombre::String, nrep::Int, seed::Integer, offset::Int, chunk::Int)
    pr = celda(nombre)
    dir = joinpath("resultados", "4a", nombre)
    mkpath(dir)
    solo = pr.via != :honesta   # adversario: un umbral (T = W0) por réplica
    wfile = joinpath(dir, "w.csv")
    if offset == 0
        isfile(wfile) && rm(wfile)
        open(wfile, "w") do io
            write(io, "replica,w,wdef,wpar,wvacio,mejor_esc,n_esc\n")
        end
    end
    # chunk de réplicas
    for base in offset:chunk:(offset+nrep-1)
        hi = min(base + chunk - 1, offset + nrep - 1)
        rs = Vector{ResReplica}(undef, hi - base + 1)
        Threads.@threads for k in 1:(hi-base+1)
            r = base + k - 1
            rs[k] = correr_replica(pr, r, UInt64(seed); solo_primero=solo)
        end
        open(wfile, "a") do io
            for k in 1:length(rs)
                r = rs[k]
                write(io, "$(r.r),$(r.w),$(r.wdef),$(r.wpar),$(r.wvacio),$(r.mejor_esc),$(r.n_esc)\n")
            end
        end
        println("  [$(Dates.now())] celda=$nombre réplicas $(base)-$(hi) hechas")
    end
    return nothing
end

"Resumen y curva G(d) de una celda ya corrida."
function resumen_4a(nombre::String, seed::Integer)
    pr = celda(nombre)
    dir = joinpath("resultados", "4a", nombre)
    wfile = joinpath(dir, "w.csv")
    rows = readlines(wfile)[2:end]
    rs = Vector{ResReplica}()
    for l in rows
        p = split(l, ',')
        r = parse(Int, p[1])
        w = parse(Int, p[2]); wd = parse(Int, p[3]); wp = parse(Int, p[4]); wv = parse(Int, p[5])
        push!(rs, ResReplica(r, w, wd, wp, wv, p[6], parse(Int, p[7]),
                             [w], [wd], [wp], [wv]))
    end
    L = pr.L_def
    rng = rng_replica(UInt64(seed), 0xFFFF)
    c = curva_g(rs, L, rng)
    gfile = joinpath(dir, "g.csv")
    open(gfile, "w") do io
        write(io, "d,G,lo,hi\n")
        for i in eachindex(c.d)
            write(io, "$(c.d[i]),$(c.g[i]),$(c.lo[i]),$(c.hi[i])\n")
        end
    end
    fit = ajuste_exponencial(c, 20, L - 1)
    resumen = joinpath(dir, "resumen.csv")
    open(resumen, "w") do io
        write(io, "celda,replicas,r_cal,G_med,L1e-3,L1e-6,L1e-9,fit_r,fit_a,fit_d0,fit_d1\n")
        l3 = l_min(c, 1e-3, fit); l6 = l_min(c, 1e-6, fit); l9 = l_min(c, 1e-9, fit)
        rc = r_calibrado(pr.α)
        fr = fit === nothing ? "NA" : string(round(fit[1], digits=4))
        fa = fit === nothing ? "NA" : string(round(fit[2], digits=3))
        fd0 = fit === nothing ? "NA" : string(fit[3]); fd1 = fit === nothing ? "NA" : string(fit[4])
        write(io, "$(nombre),$(length(rs)),$(rc),$(round(mean(r.w for r in rs), digits=2)),",
                 "$(l3[1]):$(l3[2]),$(l6[1]):$(l6[2]),$(l9[1]):$(l9[2]),",
                 "$(fr),$(fa),$(fd0),$(fd1)\n")
    end
    println("resumen: ", read(resumen, String))
    return nothing
end

"4.0 puerta: analítica, sin red."
function paso_puerta()
    dir = joinpath("resultados", "puerta")
    mkpath(dir)
    open(joinpath(dir, "resumen.csv"), "w") do io
        write(io, "# 4.0 PUERTA — fecha $(Dates.now())\n")
        write(io, "seccion,valor,unidad,etiqueta\n")
        for (cap, s) in [(1.0, s_max_racional([1.0])[1]), (4.0, s_max_racional([4.0])[1]),
                         (10.0, s_max_racional([10.0])[1]), (20.0, s_max_racional([20.0])[1]),
                         (50.0, s_max_racional([50.0])[1]), (100.0, s_max_racional([100.0])[1])]
            write(io, "S_max_racional($(cap)TiB),$(s),flujos,derivado\n")
        end
        for c in 0.0:0.1:1.0
            _, dsin, tr_, ts_ = deriva_absorcion(c, 1.0)
            write(io, "absorcion_sin_retarget(c=$(c)),$(ts_),s,derivado\n")
        end
        (τ, p1, p2, p0) = contraste_historico(203.6)
        write(io, "P(D(203.6)!=0),$(p1),prob,exacto\n")
        write(io, "P(cambio_lider_en_203.6),$(p2),prob,exacto-dp\n")
        (τ2, q1, q2, q0) = contraste_historico(600.0)
        write(io, "P(D(600)!=0),$(q1),prob,exacto\n")
        write(io, "P(cambio_lider_en_600),$(q2),prob,exacto-dp\n")
        write(io, "contraste_historico_redondeado,203.6s_epoca_205.7s_P0.82,texto,histórico-r3\n")
    end
    println(read(joinpath(dir, "resumen.csv"), String))
    return nothing
end

function paso_ctrl9c(α::Float64, smax::Int, semillas::Int)
    pr = Params4A(α=α, Δ=4.0, via=:v1, n_obs=12, W0=200, H=1000, paso_T=200, L_def=100,
                  s_max=smax)
    dir = joinpath("resultados", "ctrl9c")
    mkpath(dir)
    out = joinpath(dir, "a$(α)-s$(smax).csv")
    open(out, "w") do io
        write(io, "semilla,w_i,w_ii,w_union,menus_i,menus_ii\n")
    end
    for s in 1:semillas
        w_i, w_ii, wu, mi, mii = correr_replica_ctrl9c(pr, s, SEED_DEF)
        open(out, "a") do io
            write(io, "$(s),$(w_i),$(w_ii),$(wu),\"$(join(mi, ';'))\",\"$(join(mii, ';'))\"\n")
        end
        println("  ctrl9c α=$(α) s=$(s): w=$(wu)")
    end
    return nothing
end

function paso_ctrl11c(α::Float64, semillas::Int)
    pr = Params4A(α=α, Δ=4.0, via=:a3, n_obs=2, W0=100, H=900, paso_T=20, L_def=64,
                  d_calma=10^9)
    dir = joinpath("resultados", "ctrl11c")
    mkpath(dir)
    out = joinpath(dir, "a$(α).csv")
    open(out, "w") do io
        write(io, "semilla,S,d,dis,den\n")
    end
    for s in 1:semillas
        mdis, mden, nesc = correr_replica_ctrl11c(pr, s, SEED_DEF)
        open(out, "a") do io
            for si in 1:length(SS_11C), di in 1:length(DEVS_11C)
                write(io, "$(s),$(SS_11C[si]),$(DEVS_11C[di]),$(mdis[si,di]),$(mden[si,di])\n")
            end
        end
        println("  ctrl11c α=$(α) s=$(s) hecho ($(nesc) escenarios)")
    end
    return nothing
end

# ------- CLI ---------------------------------------------------------------------------
function main()
    args = ARGS
    isempty(args) && (println("uso: run.jl {puerta|4a|ctrl9c|ctrl11c|bench|test} [opciones]"); return)
    paso = args[1]
    rest = args[2:end]
    function opt(nombre::String, def)
        i = findfirst(==("--" * nombre), rest)
        return i === nothing ? def : rest[i+1]
    end
    if paso == "puerta"
        paso_puerta()
    elseif paso == "4a"
        nombre = opt("celda", "")
        nrep = parse(Int, opt("replicas", "100"))
        seed = parse(UInt64, opt("seed", "0x5A5A"))
        offset = parse(Int, opt("offset", "0"))
        chunk = parse(Int, opt("chunk", "100"))
        paso_4a(nombre, nrep, seed, offset, chunk)
        resumen_4a(nombre, seed)
    elseif paso == "ctrl9c"
        α = parse(Float64, opt("alpha", "0.33"))
        smax = parse(Int, opt("smax", "150"))
        ns = parse(Int, opt("semillas", "12"))
        paso_ctrl9c(α, smax, ns)
    elseif paso == "ctrl11c"
        α = parse(Float64, opt("alpha", "0.25"))
        ns = parse(Int, opt("semillas", "12"))
        paso_ctrl11c(α, ns)
    elseif paso == "bench"
        include("bench/benchmarks.jl")
    elseif paso == "test"
        include("test/runtests.jl")
    else
        error("paso desconocido: $paso")
    end
end

main()
