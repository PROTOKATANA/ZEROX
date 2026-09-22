# IB-v0.1 — escalado del Monte Carlo (LINEO §7). Se lanza con 1, 2 y 4 hilos.
using StableRNGs, Printf, Dates, Base.Threads
using IdentidadBillete
import GhostdagRank as GDR
const IB = IdentidadBillete
const P0 = GDR.Params()

semilla_replica(maestra::UInt64, r::Integer)::UInt64 = maestra ⊻ (UInt64(r) * 0x9E3779B97F4A7C15)

"Reducción determinista: una posición exclusiva por réplica y suma final en orden de ID."
function mc_par(semilla::UInt64, replicas::Int, n::Int, lambda::Float64, Delta::Int,
                q::Float64, Piezas::Int, params::GDR.Params; equivoca::Float64=0.0)
    salida = Vector{Int}(undef, replicas)
    @threads for r in 1:replicas
        rng = StableRNG(semilla_replica(semilla, r))
        especs = IB.dag_honesto(rng, n, lambda, Delta, q, Piezas; equivoca=equivoca)
        res = IB.evaluar_rapido(especs, IB.MODO_B, params)
        salida[r] = length(res.u2) + length(res.herencia)
    end
    return sum(salida)
end

# Calentamiento JIT
mc_par(UInt64(1), 4, 20, 1.0, 4, 0.0625, 16, P0; equivoca=0.25)

t = @elapsed s = mc_par(UInt64(0x5a5a), 400, 120, 1.0, 4, 0.0625, 16, P0; equivoca=0.25)
@printf("hilos=%d  tiempo=%.3f s  reduccion(invalidos+herencia)=%d  fecha=%s\n",
        Threads.nthreads(:default), t, s, Dates.now())
