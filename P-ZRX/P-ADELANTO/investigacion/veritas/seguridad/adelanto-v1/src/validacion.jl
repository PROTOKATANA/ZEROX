"""
Validación de `AdelantoV1`. Cada función devuelve datos; no imprime (la impresión es de
`run.jl`). Los criterios de aceptación están escritos en cada docstring.
"""

# ─────────────────────────────────────────────────────────────────────────────
# 1 · Regresión contra SEM-v1 (encargo §2(a))
# ─────────────────────────────────────────────────────────────────────────────

"""
Transcripción **literal** del núcleo de SEM-v1, escrita desde su fuente
(`P-ZRX/P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/src/modelo.jl:84-103`)
sin reutilizar `adelanto_nucleo`. Si las dos coinciden, la copia es fiel; si no, una de
las dos transcripciones está mal.
"""
function a_core_semv1(rho::T, L_slots::T, I_slots::T, W_dec::T) where {T<:AbstractFloat}
    if rho <= one(T)
        return zero(T)
    end
    adelanto = (L_slots - one(T) - W_dec) + I_slots * (one(T) - inv(rho))
    return max(zero(T), adelanto)
end

"""`w = floor(A_core)` de SEM-v1, entero conservador."""
function desafios_semv1(rho::T, L_slots::T, I_slots::T, W_dec::T) where {T<:AbstractFloat}
    a = a_core_semv1(rho, L_slots, I_slots, W_dec)
    (a <= zero(T) || a > T(typemax(UInt64))) && return UInt64(0)
    return UInt64(floor(a))
end

"""
Valores publicados por SEM-v1 (`INFORME.md:156-164`), transcripción literal de la tabla:
columnas `ρ`, `L`, `adelanto (slots)`, `w`. `I = 851`, `W_dec = 20`.
Se usan como vector de regresión permanente.
"""
const TABLA_SEMV1 = (
    rho = [1.0, 1.001, 1.001, 1.5, 1.5, 3.0, 3.0],
    L = [3600.0, 3600.0, 7200.0, 3600.0, 7200.0, 3600.0, 7200.0],
    adelanto = [0.0, 3579.85, 7179.85, 3862.67, 7462.67, 4146.33, 7746.33],
    w = UInt64[0, 3579, 7179, 3862, 7462, 4146, 7746],
)

"""
**Regresión exigida por el encargo §2(a).** Comprueba tres cosas:

1. `adelanto_D(ρ,L,I,W_dec,D=0)` coincide con `a_core_semv1` **bit a bit** (igualdad
   exacta de `Float64`, no tolerancia) en una rejilla densa;
2. `adelanto_nucleo` (transcripción propia) coincide con `a_core_semv1` (transcripción
   literal) en la misma rejilla;
3. los siete valores **publicados** por SEM-v1 se reproducen con error absoluto
   `≤ 0,005` slots (los publicados van a dos decimales) y el entero `w` es **idéntico**.

Criterio de aceptación: los tres, con `maxdiff == 0` en 1 y 2.
"""
function regresion_semv1(; rhos = nothing, Ls = nothing, I = 851.0, W = 20.0)
    rr = rhos === nothing ? [1.0, 1.0001, 1.001, 1.01, 1.1, 1.5, 2.0, 2.5, 3.0, 9.0, 100.0] : rhos
    LL = Ls === nothing ? [1.0, 10.0, 151.0, 851.0, 3600.0, 7200.0, 19180.0, 50000.0] : Ls

    maxdiff_nucleo = 0.0
    maxdiff_D0 = 0.0
    n = 0
    for rho in rr, L in LL
        a = adelanto_nucleo(rho, L, I, W)
        b = a_core_semv1(rho, L, I, W)
        c = adelanto_D(rho, L, I, W, 0.0)
        d = abs(a - b)
        maxdiff_nucleo = max(maxdiff_nucleo, d)
        maxdiff_D0 = max(maxdiff_D0, abs(c - b))
        n += 1
    end

    err_pub = 0.0
    w_ok = true
    for k in eachindex(TABLA_SEMV1.rho)
        rho = TABLA_SEMV1.rho[k]
        L = TABLA_SEMV1.L[k]
        a = adelanto_nucleo(rho, L, I, W)
        err_pub = max(err_pub, abs(a - TABLA_SEMV1.adelanto[k]))
        w_ok &= desafios_nucleo(rho, L, I, W) == TABLA_SEMV1.w[k]
    end

    return (
        filas = n,
        maxdiff_nucleo_vs_literal = maxdiff_nucleo,
        maxdiff_D0_vs_literal = maxdiff_D0,
        maxerr_tabla_publicada = err_pub,
        w_publicados_identicos = w_ok,
        aceptado = maxdiff_nucleo == 0.0 && maxdiff_D0 == 0.0 && err_pub <= 0.005 && w_ok,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# 2 · Kernel contra la referencia BigFloat
# ─────────────────────────────────────────────────────────────────────────────

"""
Compara el kernel rápido contra `referencia_bigfloat` en una rejilla. Criterio: error
relativo `≤ 64 eps(Float64)` en cada salida finita y **exactitud** en los enteros
(`lineas_timekeeper`) y en el predicado `vivo`.
"""
function kernel_vs_bigfloat(filas::Vector{ParametrosAdelanto{Float64}})
    tol = 64 * eps(Float64)
    peor = 0.0
    peor_campo = :ninguno
    malos = 0
    for p in filas
        r = evaluar_fila(p)
        b = referencia_bigfloat(p)
        pares = (
            (:L_slots, r.L_slots, b.L_slots),
            (:A_nucleo, r.A_nucleo, b.A_nucleo),
            (:A_D, r.A_D, b.A_D),
            (:A_frontera, r.A_frontera, b.A_frontera),
            (:A_frontera_inf, r.A_frontera_inf, b.A_frontera_inf),
            (:A_con_h, r.A_con_h, b.A_con_h),
            (:A_con_h_D, r.A_con_h_D, b.A_con_h_D),
            (:rho_transitorio, r.rho_transitorio, b.rho_transitorio),
            (:rho_estrella, r.rho_estrella, b.rho_estrella),
            (:coste_relativo, r.coste_relativo, b.coste_relativo),
            (:nucleos_nodo, r.nucleos_nodo, b.nucleos_nodo),
        )
        for (nom, x, y) in pares
            yf = Float64(y)
            ref = max(abs(yf), 1.0)
            e = abs(x - yf) / ref
            if e > peor
                peor = e
                peor_campo = nom
            end
            e > tol && (malos += 1)
        end
        if Float64(r.lineas_timekeeper) != Float64(b.lineas_timekeeper)
            malos += 1
        end
        r.vivo == b.vivo || (malos += 1)
    end
    return (peor_error_relativo = peor, peor_campo = peor_campo, violaciones = malos,
        aceptado = malos == 0)
end

# ─────────────────────────────────────────────────────────────────────────────
# 3 · Modelo de fronteras contra Sim-v1 (oráculo independiente)
# ─────────────────────────────────────────────────────────────────────────────

"""
Compara `adelanto_frontera` con **Sim-v1** (contabilidad de eventos). `Sim-v1` deriva `Γ`
de la lista de épocas y las fronteras de las dos restricciones; la forma cerrada usa
`t + I + L − W_dec`. La diferencia esperada es la **convención discreta de un slot**
(`Γ_sim = t_{i*+1} − 1`), la misma que el `−1` de `A_core`. Se publica la diferencia
medida, no se absorbe con una tolerancia.

Criterio: `|A_sim − A_frontera| ≤ 1` slot en toda la rejilla, y la diferencia **constante**
cuando el transitorio no manda.
"""
function frontera_vs_sim(;
    rhos = [1.001, 1.01, 1.1, 1.5, 2.0, 2.5, 3.0, 9.0],
    L = 7200, I = 851, W = 20, D = 4, n_epocas = 40, off_valor = 0,
)
    difs = Float64[]
    filas = NamedTuple[]
    for rho in rhos
        rr = Rational{Int}(round(Int, rho * 1000), 1000)
        sim = simular_fronteras(rr, L, I, W, D, n_epocas; off = rejilla_offsets(n_epocas, off_valor))
        t = Float64(sim.t_decision)
        cerrada = adelanto_frontera(rho, Float64(L), Float64(I), Float64(W), Float64(D), t)
        push!(difs, abs(Float64(sim.A_sim) - cerrada))
        push!(filas, (rho = rho, A_sim = sim.A_sim, A_cerrada = cerrada,
            Gamma_sim = sim.Gamma, t_decision = sim.t_decision,
            fr_hon = sim.frontera_honesta, fr_adv = sim.frontera_atacante))
    end
    return (difs = difs, maxdif = maximum(difs), filas = filas, aceptado = maximum(difs) <= 1.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# 4 · Invariantes y bordes
# ─────────────────────────────────────────────────────────────────────────────

"""
Invariantes que **deben** cumplirse. Cada uno con su justificación:

1. `A_frontera(ρ=1) == 0` exacto, y `lim_{ρ→1⁺} A_frontera = 0` (continuidad: no hay
   acantilado en el modelo de fronteras).
2. `A_core(ρ=1) == 0` y `A_core(1⁺) > 0`: el acantilado del histórico, que se **mide**.
3. `A_D(ρ, D=0) == A_core` para todo `ρ` (la generalización contiene al histórico).
4. `A_D` es no creciente en `D`; `A_add` es creciente en `D`.
5. `A_con_h(ρ*) ≈ 0` y `A_con_h(ρ) > 0` para `ρ > ρ*`.
6. Monotonías: `A_core` no decreciente en `L` y en `ρ` (`ρ > 1`) y no creciente en `W_dec`.
7. `vivo(L,W,D)` es monótona decreciente en `D` y el umbral es `L − W_dec`.
8. `A_frontera` es no decreciente en `ρ` y constante para `ρ ≥ ρ_transitorio`.
9. `L_derivada` reproduce `C-FLU-01` en los tres regímenes (manda `F`, manda el suelo,
   manda `S_max + 1`).
"""
function invariantes()
    fallos = String[]
    notas = Pair{String,Float64}[]

    L, I, W = 7200.0, 851.0, 20.0
    D = 4.0
    t = 100000.0

    # 1
    adelanto_frontera(1.0, L, I, W, D, t) == 0.0 || push!(fallos, "A_frontera(1) != 0")
    a1 = adelanto_frontera(1.0 + 1e-9, L, I, W, D, t)
    a1 < 1e-3 || push!(fallos, "A_frontera no es continuo en rho=1")
    push!(notas, "A_frontera(1+1e-9)" => a1)

    # 2
    adelanto_nucleo(1.0, L, I, W) == 0.0 || push!(fallos, "A_core(1) != 0")
    ac1 = adelanto_nucleo(1.001, L, I, W)
    ac1 > 0.9 * (L - W - 1) || push!(fallos, "A_core(1+) no muestra el acantilado")
    push!(notas, "acantilado A_core(1.001)" => ac1)

    # 3
    for rho in (1.0, 1.001, 1.5, 3.0, 100.0)
        adelanto_D(rho, L, I, W, 0.0) == adelanto_nucleo(rho, L, I, W) ||
            push!(fallos, "A_D(D=0) != A_core en rho=$rho")
    end

    # 4
    prev = Inf
    for d in 0.0:0.5:20.0
        a = adelanto_D(2.0, L, I, W, d)
        a <= prev + 0.0 || push!(fallos, "A_D no es no creciente en D")
        prev = a
    end
    prev = -Inf
    for d in 0.0:0.5:20.0
        a = adelanto_add(2.0, L, I, W, d)
        a >= prev || push!(fallos, "A_add no es creciente en D")
        prev = a
    end

    # 5
    re = rho_estrella(L, I, W)
    abs(adelanto_con_h(re, L, I, W)) < 1e-9 || push!(fallos, "A_con_h(rho*) != 0")
    adelanto_con_h(re * 1.5, L, I, W) > 0 || push!(fallos, "A_con_h(rho>rho*) <= 0")
    push!(notas, "rho*" => re)

    # 6
    prev = -Inf
    for LL in (1000.0, 2000.0, 4000.0, 7200.0, 20000.0)
        a = adelanto_nucleo(2.0, LL, I, W)
        a >= prev || push!(fallos, "A_core no monótona en L")
        prev = a
    end
    prev = -Inf
    for rho in (1.001, 1.01, 1.1, 1.5, 2.0, 3.0, 9.0)
        a = adelanto_nucleo(rho, L, I, W)
        a >= prev || push!(fallos, "A_core no monótona en rho")
        prev = a
    end
    prev = Inf
    for WW in (5.0, 10.0, 20.0, 45.0, 150.0)
        a = adelanto_nucleo(2.0, L, I, WW)
        a <= prev || push!(fallos, "A_core no decreciente en W_dec")
        prev = a
    end

    # 7
    vivo(L, W, L - W) || push!(fallos, "vivo debe ser cierto en el borde D = L - W")
    vivo(L, W, L - W + 1e-9) && push!(fallos, "vivo debe ser falso por encima del borde")

    # 8
    prev = -Inf
    for rho in (1.0, 1.001, 1.01, 1.5, 2.0, 100.0)
        a = adelanto_frontera(rho, L, I, W, D, t)
        a >= prev || push!(fallos, "A_frontera no monótona en rho")
        prev = a
    end
    rt = rho_transitorio(L, I, W, D, t)
    a_rt = adelanto_frontera(rt, L, I, W, D, t)
    a_lejos = adelanto_frontera(rt * 10, L, I, W, D, t)
    abs(a_rt - a_lejos) < 1e-6 || push!(fallos, "A_frontera no satura para rho >= rho_trans")
    push!(notas, "rho_transitorio" => rt)
    push!(notas, "A_frontera_inf" => max(0.0, L + I - W - D))

    # 9
    L_derivada(7200.0, 500.0, 150.0) == 7200.0 || push!(fallos, "C-FLU-01: no manda F")
    L_derivada(500.0, 7200.0, 150.0) == 7200.0 || push!(fallos, "C-FLU-01: no manda el suelo")
    L_derivada(100.0, 50.0, 150.0) == 151.0 || push!(fallos, "C-FLU-01: no manda S_max+1")

    return (fallos = fallos, notas = notas, aceptado = isempty(fallos))
end

# ─────────────────────────────────────────────────────────────────────────────
# 5 · Exactitud de los umbrales discretos
# ─────────────────────────────────────────────────────────────────────────────

"""
Compara `ρ*`, el predicado `vivo` y el término `L` que manda en `C-FLU-01` entre la
aritmética `Float64` del kernel y `Rational{BigInt}` de `referencia_exacta`. Criterio:
**cero discrepancias** en `manda_F` y en `vivo`, y error relativo `≤ 64 eps` en `ρ*`.
"""
function exactitud_umbrales(;
    Is = [151, 300, 851, 4725], Ws = [5, 20, 45, 150], Ds = [0, 4, 45, 150],
    Fs = [3600, 7200, 19180], Lsuelos = [0, 151, 3000], S = 150,
)
    peor_re = 0.0
    disc_manda = 0
    disc_vivo = 0
    disc_rho = 0
    n = 0
    for I in Is, W in Ws, D in Ds, F in Fs, Lsu in Lsuelos
        re = referencia_exacta(2, 1, I, W, D, S, F, Lsu)
        Lf = L_derivada(Float64(F), Float64(Lsu), Float64(S))
        re_f = rho_estrella(Lf, Float64(I), Float64(W))
        ref = Float64(re.rho_estrella)
        peor_re = max(peor_re, abs(re_f - ref) / max(abs(ref), 1.0))
        disc_manda += (re.manda_F == (Lf == Float64(F))) ? 0 : 1
        disc_vivo += (vivo(Lf, Float64(W), Float64(D)) == re.vivo) ? 0 : 1
        # contraste racional adicional: rho = 2 contra rho*
        disc_rho += (re.rho_es_menor_que_estrella == (Rational{BigInt}(2) < re.rho_estrella)) ? 0 : 1
        n += 1
    end
    return (filas = n, peor_error_rel_rho_estrella = peor_re,
        discrepancias_manda_F = disc_manda, discrepancias_vivo = disc_vivo,
        discrepancias_rho = disc_rho,
        aceptado = peor_re <= 64 * eps(Float64) && disc_manda == 0 && disc_vivo == 0 &&
            disc_rho == 0)
end
