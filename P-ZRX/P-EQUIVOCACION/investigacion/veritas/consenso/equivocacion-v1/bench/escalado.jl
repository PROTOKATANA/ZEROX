# =============================================================================
# escalado.jl — barrido de la rejilla con hilos (LINEO §7: medir 1…N y conservar
#               lo que gane; aquí el tope declarado es 4)
#   for t in 1 2 4; do ./veritas/julia.sh --project=. --threads=$t bench/escalado.jl; done
# Cada configuración es independiente y escribe en su propia celda: sin carreras,
# reducción determinista al final (se cuentan coincidencias, no se suma en Float).
# =============================================================================
include(joinpath(@__DIR__, "..", "src", "Equivocacion.jl"))
using .Equivocacion
using Printf, Dates

const E = Equivocacion

function cadena_slots(a::Int, b::Int, paso::Int)
    a >= b && return Int[a]
    s = collect(a:paso:b)
    s[end] != b && push!(s, b)
    return s
end

function configuracion(; I, F, Smax, delta, x, paso_comun, paso_priv, paso_rama, d)
    L = max(F, Smax + 1)
    s0 = I + delta
    Wslot = I - x
    comun = cadena_slots(0, s0, paso_comun)
    idx_fork = findlast(<=(Wslot), comun)
    idx_fork === nothing && return nothing
    publica = cadena_slots(s0 + paso_rama, s0 + d, paso_rama)
    privada = vcat(cadena_slots(Wslot + paso_priv, s0, paso_priv),
                   cadena_slots(s0 + paso_rama, s0 + d, paso_rama))
    length(privada) >= 2 || return nothing
    dag, P, A, B = construir_dos_ramas(slots_comun = comun, idx_fork = idx_fork,
        slots_publica = publica, slots_privada = privada,
        I_slots = I, L = L, S_max = Smax, fusionar = :P)
    return (d = dag, P = P, A = A, B = B, L = L, I = I, F = F, Smax = Smax)
end

"Rejilla de barrido (la misma familia que `run.jl --modo rejilla`)."
function rejilla()
    out = []
    for I in (20, 24), Smax in (6, 9), F in (I, div(I, 2))
        L = max(F, Smax + 1)
        Smax >= L && continue
        for delta in (1, 2, 4, 8), x in (1, 3, 6), (pc, pp) in ((1, 1), (1, 3), (3, 1), (4, 2))
            Smax >= max(pc, pp) || continue
            d = L - 1
            d < F || continue
            cfg = configuracion(I = I, F = F, Smax = Smax, delta = delta, x = x,
                                paso_comun = pc, paso_priv = pp, paso_rama = min(pc, pp), d = d)
            cfg === nothing && continue
            push!(out, cfg)
        end
    end
    return out
end

"Una celda: cuántos slots comparten flujo (entero, reducción determinista)."
function celda(cfg)
    u = Universo(npiezas = 8, nchunks = 2, npruebas = 1, rango = UInt64(0))
    r = kappa(cfg.d, cfg.A, cfg.B, cfg.P, u; I_slots = cfg.I, L = cfg.L, F_slots = cfg.F,
              jmax = 6, k = 30, s0 = cfg.d.bloques[cfg.P].slot)
    return (r.slots, r.slots_comun)
end

function main()
    cfgs = rejilla()
    res = Vector{Tuple{Int,Int}}(undef, length(cfgs))
    celda(cfgs[1])                       # calentamiento JIT
    t0 = time()
    Threads.@threads for i in eachindex(cfgs)
        res[i] = celda(cfgs[i])
    end
    t1 = time()
    total_slots = sum(r[1] for r in res)
    total_comun = sum(r[2] for r in res)
    @printf("hilos=%d celdas=%d pared=%.4f s slots=%d kappa_flujo_global=%.6f\n",
            Threads.nthreads(), length(cfgs), t1 - t0, total_slots,
            total_slots == 0 ? NaN : total_comun / total_slots)
end

main()
