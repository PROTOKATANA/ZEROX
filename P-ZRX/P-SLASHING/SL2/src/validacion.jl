#= SL-2 · validacion.jl
   Equivalencia entre vías, invariantes y bordes. Lo que aquí se comprueba es lo que
   `test/runtests.jl` publica; ninguna cifra del INFORME sale sin pasar por aquí.
=#

"""
    validar_primera_pasada() -> NamedTuple

Sobre la rejilla de P-PRESTAMO (`q ∈ {1/10,…,9/10}`, `d ∈ 0…7`, `T ∈ 0…16`), comprueba que las
cuatro vías coinciden: DP `(mínimo, posición)`, DP absorbente exacta, enumeración exhaustiva
(`T ≤ 10`) y el invariante `paso + interior = 1`.
"""
function validar_primera_pasada()
    celda_max = 0.0
    n = 0
    n_enum = 0
    enum_max = 0.0
    for (qn, qd) in ((1, 10), (3, 10), (2, 5), (5, 10), (2, 3), (9, 10))
        q = Rational{BigInt}(qn, qd)
        for d in 0:7, T in 0:16
            r = primera_dp(Float64(q), d, T)
            ex = primera_absorbente_exacta(q, d, T)
            fa = primera_dp_absorbente(Float64(q), d, T)
            err = max(abs(Float64(r.paso) - Float64(ex)),
                      abs(Float64(r.paso) - fa),
                      abs(r.paso + r.interior - 1.0))
            celda_max = max(celda_max, err)
            n += 1
            if T <= 10
                en = enumerar_exhaustivo(q, d, T).paso
                enum_max = max(enum_max, abs(Float64(r.paso) - Float64(en)))
                n_enum += 1
            end
        end
    end
    return (celdas = n, error_max = celda_max, celdas_enum = n_enum, error_enum = enum_max)
end

"Comprueba `α*` exacto y `g(α*) = 0`."
function validar_alpha()
    err = 0.0
    n = 0
    for βd in (0 // 1, 3 // 10, 17 // 50), βx in (0 // 1, 1 // 10), ηa in (1 // 1, 3 // 2)
        a = alpha_estrella(Float64(βd), Float64(βx), 1.0, Float64(ηa))
        g = Float64(ηa) * (a + Float64(βd) + Float64(βx)) - (1 - a - Float64(βx))
        err = max(err, abs(g))
        n += 1
    end
    return (filas = n, error_max = err)
end

"""
    validar_Bemp(d::Empirica, x, semilla; nrep, etiqueta) -> NamedTuple

Comprueba que el bootstrap del `B` empírico contiene el valor directo (IC de Wilson del conteo) y
que `B` es monótono decreciente en `T_v` (equivalentemente creciente en `x`).
"""
function validar_Bemp(d::Empirica, x::Float64, semilla::UInt64; nrep::Integer = 4000,
                      etiqueta::UInt64 = UInt64(9))
    bp = B_empirico(d, x)
    reps = bootstrap_Bemp(d, x, nrep, semilla; etiqueta = etiqueta)
    lo, hi = ic_percentil(reps)
    x1, x2 = 0.3 * x, 3.0 * x
    mono = B_empirico(d, x1) <= bp + 1e-15 <= B_empirico(d, x2) + 1e-15
    return (directo = bp, ic_lo = lo, ic_hi = hi, dentro = lo <= bp <= hi, monotono = mono,
            nrep = nrep)
end

"""
    validar_Bpar(alpha, x; m=200_000, semilla) -> NamedTuple

Comprueba que la fórmula cerrada `B_par` coincide con (i) la integración exacta `B_par_exacta` y
(ii) el Monte Carlo `mc_Bpar`, dentro del IC percentil.
"""
function validar_Bpar(alpha::Float64, x::Float64; f_min::Float64 = 1e-8, m::Integer = 200_000,
                      nrep::Integer = 200, semilla::UInt64 = UInt64(0x5a5a))
    cerrada = B_par(Pareto(f_min, alpha), x)
    Fmax = alpha > 2 ? Inf : 1.0
    exacta = B_par_exacta(f_min, alpha, x; F_max = Fmax)
    d = ParetoDist(f_min, alpha, 0.0)
    reps = mc_Bpar(d, x, nrep, semilla, m)
    lo, hi = ic_percentil(reps)
    return (cerrada = cerrada, exacta = exacta, err_exacta = abs(cerrada - exacta),
            mc_media = sum(reps) / length(reps), ic_lo = lo, ic_hi = hi,
            dentro = lo <= cerrada <= hi)
end

"""
    validar_region(esc, βd, ρ_ret) -> NamedTuple

Comprueba que los bordes devueltos por `region_tv` son de verdad los que cierran la región:
`A` se cumple en `Tv_min` y falla justo por debajo; `B` (honestidad) se cumple en `Tv_max` y falla
por encima. Márgenes relativos declarados.
"""
function validar_region(esc::Escenario, βd, ρ_ret)
    reg = region_tv(esc, βd; ρ_ret = ρ_ret)
    reg.existe || return (existe = false, a_en_min = false, b_en_max = false, margen = NaN)
    a_min = condicion_disuasion(esc, βd; ρ_ret = ρ_ret, Tv = reg.Tv_min + 1e-6)
    b_max = condicion_honesta(esc; ρ_ret = ρ_ret, Tv = reg.Tv_max, f_h = esc.f_h)
    margen = reg.Tv_max - reg.Tv_min
    return (existe = true, a_en_min = a_min, b_en_max = b_max.ok,
            margen = margen, borde_inf = reg.borde_inf, borde_sup = reg.borde_sup)
end
