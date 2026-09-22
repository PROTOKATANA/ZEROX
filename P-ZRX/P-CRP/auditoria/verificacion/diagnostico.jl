# diagnostico.jl — P-CRP: comprobación propia de la derivación de semillas por réplica.
# 1 hilo. NO modifica instrumentos. Usa las funciones de la copia de v0.3 tal cual.
#
# Pregunta: ¿las 24 réplicas de una celda publicada son 24 muestras independientes?
#   - `run.jl` usa `StableRNG(SEMILLA + r)` (semillas consecutivas) — patrón que P-ZRX/P-PUERTA/
#     documentó como sesgado.
#   - la alternativa que prefiere `veritas/LINEO.md` §5.1/§7 es un RNG contracorriente
#     (`Random123`/Philox). Aquí se usa `Philox2x` con la SEGUNDA palabra del contador como id de
#     réplica, que es la forma correcta: la primera palabra avanza dentro del flujo.
#     (Con `set_counter!(r, id)` —una sola palabra— las réplicas comparten casi todo el flujo;
#     se demuestra en el bloque 4.)
#
# Se mide: (a) la autocorrelación lag-1 de la secuencia de uniforms; (b) la varianza del recuento
# por bloque de 24 réplicas frente a la binomial que exige el intervalo de Wilson publicado.

using Printf, Statistics
using StableRNGs, Random123

const COPIAS = normpath(joinpath(@__DIR__, "..", "copia"))
include(joinpath(COPIAS, "coste-rama-privada-v3", "src", "CosteRamaPrivadaV3.jl"))
using .CosteRamaPrivadaV3

"Correcto: id de réplica en la segunda palabra del contador (flujos disjuntos)."
rng_cc(clave, id) = (r = Philox2x(UInt64, clave); set_counter!(r, (0, UInt64(id))); r)
"Trampa: una sola palabra ⇒ la réplica `id` empieza en la salida `id` del mismo flujo."
rng_cc_mal(clave, id) = (r = Philox2x(UInt64, clave); set_counter!(r, UInt64(id)); r)

autocorr_lag1(x) = (n = length(x); m = mean(x); dx = x .- m;
                    sum(dx[1:(n - 1)] .* dx[2:n]) / sum(dx .^ 2))

function resumen(ks, reps)
    p = sum(ks) / (reps * length(ks))
    varb = reps * p * (1 - p)
    vobs = var(ks)
    return (p=p, vobs=vobs, varb=varb, ratio=varb == 0 ? Inf : vobs / varb)
end

# --- 1 · autocorrelación de los uniforms -----------------------------------------------------
println("== 1 · autocorrelación lag-1 de los uniforms por semilla consecutiva (n=100000) ==")
for cual in (1, 2)
    x = [let r = StableRNG(UInt64(0x5a5a) + UInt64(i)); v = rand(r); cual == 1 || (v = rand(r)); v end
         for i in 1:100_000]
    y = [let r = rng_cc(UInt64(0x5a5a), i); v = rand(r); cual == 1 || (v = rand(r)); v end
         for i in 1:100_000]
    @printf("salida %d: StableRNG(base+i) = %+.4f   Philox (0,id) = %+.4f\n",
            cual, autocorr_lag1(x), autocorr_lag1(y))
end
println("referencia iid: ±0.0095")

# --- 2 · control puro Bernoulli(0.5): 200 bloques x 24 ---------------------------------------
println("\n== 2 · control puro Bernoulli(0.5), 200 bloques x 24 réplicas ==")
for (nom, mk, p0) in (("StableRNG(base+r)", (b, r) -> StableRNG(UInt64(1000b + 7 + r)), 0.5),
                      ("Philox (0,id)", (b, r) -> rng_cc(UInt64(1000b + 7), r), 0.5),
                      ("Philox (id) MAL", (b, r) -> rng_cc_mal(UInt64(1000b + 7), r), 0.5))
    B, R = 200, 24
    M = [rand(mk(b, r)) < p0 ? 1.0 : 0.0 for b in 1:B, r in 1:R]
    ks = vec(sum(M; dims=2))
    s = resumen(ks, R)
    cs = [cor(M[:, i], M[:, j]) for i in 1:R for j in (i + 1):R]
    @printf("%-18s p̂=%.4f Var_obs=%6.3f Var_binom=%6.3f ratio=%5.2f  corr_media=%+.4f max=%+.3f\n",
            nom, s.p, s.vobs, s.varb, s.ratio, mean(cs), maximum(cs))
end

# --- 3 · el estadístico del simulador, celda de tasa intermedia -------------------------------
const W_PESO = fld(big(2)^128, BigInt(2))
cfg_celda() = ConfigSimV3(; n_honestos=4, alpha=0.2, delta=2, S=4, T=200, t_fork=1, k=30,
                          modo_correlacion=:derivada)
"suma aditiva terminal > punta pública (d=0): en SWEEP-DAG.txt, S=4 α=0.20 da 13/24"
function exito_suma(rng)
    res = simular_v3!(cfg_celda(), rng)
    return sum(res.W_priv_terminal; init=big(0)) - res.W_pub > 0
end
println("\n== 3 · estadístico del simulador (S=4, α=0.2, T=200, Δ=2, k=30, suma aditiva d=0) ==")
for (nom, mk) in (("StableRNG(base+r)", (b, r) -> StableRNG(UInt64(1000b + 7 + r))),
                  ("Philox (0,id)", (b, r) -> rng_cc(UInt64(1000b + 7), r)),
                  ("Philox (id) MAL", (b, r) -> rng_cc_mal(UInt64(1000b + 7), r)))
    B, R = 200, 24
    M = [exito_suma(mk(b, r)) ? 1.0 : 0.0 for b in 1:B, r in 1:R]
    ks = vec(sum(M; dims=2))
    s = resumen(ks, R)
    cs = [cor(M[:, i], M[:, j]) for i in 1:R for j in (i + 1):R]
    @printf("%-18s p̂=%.4f Var_obs=%6.3f Var_binom=%6.3f ratio=%5.2f  corr_media=%+.4f max=%+.3f\n",
            nom, s.p, s.vobs, s.varb, s.ratio, mean(cs), maximum(cs))
end

# --- 4 · por qué `set_counter!(r, id)` es una trampa ------------------------------------------
println("\n== 4 · solapamiento con una sola palabra de contador ==")
a = rand(rng_cc_mal(UInt64(7), 1), 4)
b = rand(rng_cc_mal(UInt64(7), 2), 4)
@printf("flujo id=1: %.6f %.6f %.6f %.6f\n", a...)
@printf("flujo id=2: %.6f %.6f %.6f %.6f\n", b...)
println("obsérvese que el flujo id=2 es el id=1 desplazado: NO son réplicas independientes")
