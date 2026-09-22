# ANCLA-v0.1 — CLI reproducible (LINEO §1).
#
#   julia --project=. --threads=24 run.jl --seed 0x5a5a --replicas 500 --T 600 \
#         --n 100 --obs 100 --paso 1.0 --Dmax 5 --out resultados/curva
#
# Mide P(discrepancia del ancla)(D) entre observadores honestos con la red y la Δ del
# modelo DMS-v0.1. Cada réplica es independiente (semilla derivada) y se reduce en orden.

using AnclaInyeccion
using Random
using Printf
using Dates
using StableRNGs

function parse_args(args)
    op = Dict{String,String}()
    i = 1
    while i <= length(args)
        a = args[i]
        if startswith(a, "--")
            k = a[3:end]
            v = i < length(args) ? args[i + 1] : ""
            op[k] = v
            i += 2
        else
            i += 1
        end
    end
    return op
end

entero(op, k, d) = haskey(op, k) ? parse(Int, op[k]) : d
real_(op, k, d) = haskey(op, k) ? parse(Float64, op[k]) : d
u64_(op, k, d) = haskey(op, k) ? parse(UInt64, op[k]) : d

"""
Δ_q de un bloque en la corrida: tiempo hasta que ⌈q·n/100⌉ nodos lo recibieron.
Devuelve el vector de Δ_99 y Δ_100 por bloque creado dentro de la ventana.
"""
function medir_delta(d::DAGGlobal, T::Float64, q::Float64)
    nd = ceil(Int, q * d.n / 100)
    ds = Float64[]
    for b in 1:d.nblo
        d.t_crea[b] <= T || continue
        lleg = sort(d.llega[b, :])
        lleg[nd] == Inf && continue
        push!(ds, lleg[nd] - d.t_crea[b])
    end
    return ds
end

function main()
    op = parse_args(ARGS)
    semilla = u64_(op, "seed", 0x5a5a)
    replicas = entero(op, "replicas", 50)
    T = real_(op, "T", 600.0)
    lambda = real_(op, "lambda", 1.0)
    n = entero(op, "n", 100)
    grado = entero(op, "grado", 8)
    obs = entero(op, "obs", n)
    paso = real_(op, "paso", 1.0)
    Dmax = entero(op, "Dmax", 5)
    out = get(op, "out", "resultados/curva")
    mu_lat = real_(op, "mu", log(0.08))
    sigma_lat = real_(op, "sigma", 0.7879)
    t_tx = real_(op, "ttx", 65e-6)
    sr = u64_(op, "sr", UInt64(1000))

    obsidx = collect(1:obs)
    # presupuesto declarado por adelantado
    @printf("# P-2.1 ANCLA-v0.1  %s\n", now())
    @printf("# git=%s\n", try strip(read(`git -C $(AnclaInyeccion._raiz_repo()) rev-parse HEAD`, String)) catch; "?" end)
    @printf("# julia=%s threads=%d\n", VERSION, Threads.nthreads())
    @printf("# replicas=%d T=%.1f lambda=%.3f n=%d grado=%d obs=%d paso=%.2f Dmax=%d seed=0x%x\n",
            replicas, T, lambda, n, grado, obs, paso, Dmax, semilla)
    @printf("# mu=%.5f sigma=%.5f ttb_tx=%.3g sr=%d\n", mu_lat, sigma_lat, t_tx, sr)

    # una fila por (réplica, D): votos, suma de p_dis·votos, dif_ref, max_bloques
    filas = Vector{NamedTuple{(:rep, :D, :n, :sp, :dif, :maxb),Tuple{Int,Int,Int,Float64,Int,Int}}}()
    candado = ReentrantLock()
    t0 = time()

    Threads.@threads for r in 1:replicas
        pr = ParametrosRed(n, grado, lambda, T, t_tx, mu_lat, sigma_lat, 15, sr,
                           semilla + UInt64(r) * 0x9e3779b97f4a7c15)
        d = simular_red(pr)
        acc = medir_transitorio(d, P_DEFECTO, obsidx, T, paso, Dmax)
        locales = NamedTuple{(:rep, :D, :n, :sp, :dif, :maxb),Tuple{Int,Int,Int,Float64,Int,Int}}[]
        for D in sort!(collect(keys(acc.total)))
            tot = acc.total[D]
            tot == 0 && continue
            push!(locales, (rep = r, D = D, n = tot, sp = acc.sum_p[D],
                            dif = get(acc.dif_ref, D, 0),
                            maxb = get(acc.max_bloques, D, 0)))
        end
        lock(candado) do
            append!(filas, locales)
        end
    end
    dt = time() - t0
    sort!(filas; by = f -> (f.rep, f.D))

    mkpath(dirname(out))
    open(out * ".csv", "w") do io
        println(io, "replica,D,n_votos,sum_p_dis,dif_ref,max_bloques")
        for f in filas
            @printf(io, "%d,%d,%d,%.10g,%d,%d\n", f.rep, f.D, f.n, f.sp, f.dif, f.maxb)
        end
    end

    # reducción determinista
    println("# reducción")
    @printf("# tiempo_pared_s=%.2f  procesado\n", dt)
    Ds = sort!(unique([f.D for f in filas]))
    println("# D,p_dis,ic95_lo,ic95_hi,p_dif_ref,dif_lo,dif_hi,n_votos")
    for D in Ds
        sub = [f for f in filas if f.D == D]
        tot = sum(f.n for f in sub)
        sp = sum(f.sp for f in sub)
        dif = sum(f.dif for f in sub)
        p = sp / tot
        # bootstrap por réplica (clúster) para IC
        reps = unique([f.rep for f in sub])
        pmap = Dict{Int,Float64}()
        nmap = Dict{Int,Int}()
        dmap = Dict{Int,Int}()
        for f in sub
            pmap[f.rep] = get(pmap, f.rep, 0.0) + f.sp
            nmap[f.rep] = get(nmap, f.rep, 0) + f.n
            dmap[f.rep] = get(dmap, f.rep, 0) + f.dif
        end
        rng = StableRNG(0x1234 + D)
        B = 2000
        vals = Vector{Float64}(undef, B)
        valsref = Vector{Float64}(undef, B)
        for b in 1:B
            st = 0.0; sn = 0; sd = 0
            for _ in 1:length(reps)
                rr = reps[rand(rng, 1:length(reps))]
                st += pmap[rr]; sn += nmap[rr]; sd += dmap[rr]
            end
            vals[b] = st / sn
            valsref[b] = sd / sn
        end
        sort!(vals); sort!(valsref)
        lo = vals[max(1, round(Int, 0.025 * B))]
        hi = vals[min(B, round(Int, 0.975 * B))]
        lor = valsref[max(1, round(Int, 0.025 * B))]
        hir = valsref[min(B, round(Int, 0.975 * B))]
        @printf("%d,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%d\n",
                D, p, lo, hi, dif / tot, lor, hir, tot)
    end
end

main()
