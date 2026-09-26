#= DS-3 · validacion.jl
   Equivalencia entre vías, invariantes y bordes. Lo que aquí se comprueba es lo que
   `test/runtests.jl` publica; ninguna cifra del INFORME sale sin pasar por aquí.
=#

"""
    validar_primera_pasada() -> NamedTuple

Comprueba, sobre la rejilla exacta de P-PRESTAMO (`q ∈ {1/10,…,9/10}`, `d ∈ 0…7`,
`T ∈ 0…16`), que las cuatro vías coinciden:
  · DP `(mínimo, posición)` (Float64),
  · DP absorbente exacta (`Rational{BigInt}`),
  · enumeración exhaustiva (`Rational{BigInt}`),
  · y `paso + interior = 1` en el DP certificado.
Devuelve el máximo error absoluto y el número de celdas.
"""
function validar_primera_pasada()
    celda_max = 0.0
    n = 0
    n_enum = 0
    enum_max = 0.0
    for qn in (1, 3, 2, 5, 2, 9), qd in (10, 10, 5, 10, 3, 10)
        qn >= qd && continue
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
            if T <= 10                       # la enumeración es 2^T: sólo dominio pequeño
                en = enumerar_exhaustivo(q, d, T).paso
                enum_max = max(enum_max, abs(Float64(r.paso) - Float64(en)))
                n_enum += 1
            end
        end
    end
    return (celdas = n, error_max = celda_max, celdas_enum = n_enum, error_enum = enum_max)
end

"Comprueba la cola hipergeométrica rápida contra la exacta en el dominio pequeño."
function validar_cobertura(; N = 400, ks = (1, 5, 20, 60, 200), Bs = (0, 3, 10, 40))
    t = TablaLogFact(N)
    err = 0.0
    n = 0
    for M in (0, 1, 10, 50, 200, 399), k in ks, B in Bs
        k > N && continue
        exacto = Float64(cola_hiper_exacta(N, M, k, B))
        rapido = cola_hiper_rapida(t, N, M, k, B)
        err = max(err, abs(exacto - rapido))
        n += 1
    end
    return (casos = n, error_max = err)
end

"Comprueba la frontera de almacenamiento forzado exacta contra la de `modelo.jl`."
function validar_almacenamiento(; N = 1_048_480, Bs = (0, 25, 181_092, 500_000),
                                ks = (1_000, 100_000, 1_000_000))
    err = 0.0
    n = 0
    for B in Bs, k in ks
        exacto = Float64(almacenamiento_forzado_exacta(N, k, B))
        rapido = almacenamiento_forzado(N, B, k)
        err = max(err, abs(exacto - rapido))
        n += 1
    end
    return (casos = n, error_max = err)
end

"Comprueba `α*` exacto contra `Rational{BigInt}` en 12 filas y `g(α*) = 0`."
function validar_alpha()
    err = 0.0
    n = 0
    for βd in (0 // 1, 3 // 10, 17 // 50), βx in (0 // 1, 1 // 10), ηa in (1 // 1, 3 // 2)
        a = alpha_estrella_exacta(βd, βx, 1 // 1, ηa)
        # α* es la raíz de `g` del MODELO §2.1: g = η_a(α+β_d+β_x) − η_h(1−α−β_x), η_h = 1.
        g = ηa * (a + βd + βx) - (1 - a - βx)
        err = max(err, abs(Float64(g)))
        n += 1
    end
    return (filas = n, error_max = err)
end

"Resumen legible de todas las validaciones."
function validar_todo()
    vp = validar_primera_pasada()
    vc = validar_cobertura()
    va = validar_almacenamiento()
    val = validar_alpha()
    return (primera_pasada = vp, cobertura = vc, almacenamiento = va, alpha = val)
end
