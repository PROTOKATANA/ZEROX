#=  validacion.jl — comprobaciones de ANR-v0.1.

Cada función devuelve `(ok::Bool, lineas::Vector{String})` salvo donde se indica. Las cifras
publicadas salen de aquí, nunca de un notebook.
=#

"Tabla 3 de BDK+19 (Anexo F, `Delta = 0`), copiada del texto extraído `research/fuentes/bdk19.txt`."
const TABLA3_PHI = Dict(
    1 => "e", 2 => 2.22547, 3 => 2.01030, 4 => 1.88255, 5 => 1.79545,
    6 => 1.73110, 7 => 1.68103, 8 => 1.64060, 9 => 1.60705, 10 => 1.57860,
)
const TABLA3_BETA = Dict(
    2 => 0.31003, 3 => 0.33219, 4 => 0.34691, 5 => 0.35772,
    6 => 0.36615, 7 => 0.37299, 8 => 0.37870, 9 => 0.38358, 10 => 0.38780,
)

"Valores de `phi_c` citados en el repositorio (research/dag-poas-ancla-de-finalidad.md §6)."
const PHI_REPO = Dict(16 => 1.4678, 50 => 1.2815, 100 => 1.2074, 250 => 1.1387,
                      500 => 1.1023, 1000 => 1.0754, 2000 => 1.0556)

# ---------------------------------------------------------------- reproducción externa

"Reproduce la Tabla 3 del paper (c = 1..10). Tolerancia 1e-4 por el redondeo a 5 cifras."
function tabla_paper()
    ok = true
    L = String[]
    push!(L, "c    phi_c(calculado)        phi_c(Tabla 3)   |dif|      beta*(calculado)  beta*(Tabla 3)")
    for c in 1:10
        p = Float64(phi_c_medio(c))
        b = Float64(umbral_c_medio(c))
        if c == 1
            pe = Float64(exp(big(1)))
            d = abs(p - pe)
            ok &= d < 1e-12
            push!(L, @sprintf("%-4d %-22.10f %-16s %.2e   %-17.8f %s", c, p, "e", d, b, "1/(1+e)"))
        else
            pt = TABLA3_PHI[c]
            d = abs(p - pt)
            ok &= d < 1e-4
            bt = TABLA3_BETA[c]
            db = abs(b - bt)
            ok &= db < 1e-4
            push!(L, @sprintf("%-4d %-22.10f %-16.5f %.2e   %-17.8f %.5f (dif %.1e)", c, p, pt, d, b, bt, db))
        end
    end
    return ok, L
end

"Reproduce los `phi_c` citados en el repositorio. Tolerancia 1e-4 por el redondeo a 4 cifras."
function tabla_repo()
    ok = true
    L = String[]
    push!(L, "c      phi_c(calculado)     phi_c(repositorio)  |dif|")
    for c in sort(collect(keys(PHI_REPO)))
        p = Float64(phi_c_medio(c))
        d = abs(p - PHI_REPO[c])
        ok &= d < 1e-4
        push!(L, @sprintf("%-6d %-19.10f %-19.4f %.2e", c, p, PHI_REPO[c], d))
    end
    return ok, L
end

# ---------------------------------------------------------------- control obligatorio

"""
    control_d0()

CONTROL OBLIGATORIO del encargo: `d = 0` debe devolver el 27 % conocido. Se comprueba que
`umbral_d(0)` encierra `1/(1+e)` y que `phi_c(1) = e`, con la ruta simbólica (O3) y la numérica.
"""
function control_d0()
    ok1, sym = phi_1_simbolico()
    lo, hi = umbral_d(0)
    objetivo = 1 / (1 + exp(big(1)))
    ok2 = lo <= objetivo <= hi
    p = Float64(phi_c_medio(1))
    L = String[
        @sprintf("d = 0  ->  c = 1  ->  phi_1 = %.15f   (e = %.15f)", p, Float64(exp(big(1)))),
        @sprintf("umbral(0) en [%.18f, %.18f]", Float64(lo), Float64(hi)),
        @sprintf("1/(1+e)      = %.18f   -> %.4f %%", Float64(objetivo), 100 * Float64(objetivo)),
        @sprintf("theta*(1) = -e y phi_1 = e exactos (sustitucion simbolica): %s", sym),
        @sprintf("CONTROL: umbral(0) == 1/(1+e)  ->  %s", ok2 ? "OK (27 %)" : "FALLA"),
    ]
    return (ok1 && ok2), L
end

# ---------------------------------------------------------------- monotonía y límites

"`phi_c` estrictamente decreciente y `umbral_c` estrictamente creciente en `c`; `phi_c ↓ 1`."
function monotonia_limites(; cs=1:400)
    ok = true
    prev = Float64(phi_c_medio(1))
    for c in 2:last(cs)
        p = Float64(phi_c_medio(c))
        ok &= p < prev
        prev = p
    end
    p_grande = phi_c_f64(10^7)
    ok &= p_grande > 1.0
    ok &= (p_grande - 1.0) < 0.01
    L = String[
        @sprintf("phi_c estrictamente decreciente en c = 1..%d: %s", last(cs), ok ? "OK" : "FALLA"),
        @sprintf("phi_{10^7} = %.10f  (> 1 y -> 1): %s", p_grande, (p_grande > 1 && p_grande - 1 < 0.01) ? "OK" : "FALLA"),
        @sprintf("umbral(inf) = 1/2 = 0.5 ; umbral(0) = %.10f", Float64(umbral_d_medio(0))),
    ]
    return ok, L
end

# ---------------------------------------------------------------- O1 y kernel

"O1: `phi_c` por maximización directa de `Lambda_c(t)/t` frente a la bisección de (39)."
function oraculo_maximo(; cs=(1, 2, 3, 5, 10, 50, 200, 1000))
    ok = true
    L = String[]
    push!(L, "c      phi_c(biseccion)      phi_c(sup Lambda/t)   |dif|")
    for c in cs
        a = Float64(phi_c_medio(c))
        b = Float64((r = phi_por_maximo(c; prec=256); (r[1] + r[2]) / 2))
        d = abs(a - b)
        ok &= d < 1e-8
        push!(L, @sprintf("%-6d %-21.12f %-21.12f %.2e", c, a, b, d))
    end
    return ok, L
end

"Equivalencia kernel Float64 ↔ referencia BigFloat en todo el rango de uso."
function oraculo_kernel(; cs=vcat(1:20, 50, 100, 500, 1000, 5000, 20000))
    peor = 0.0
    for c in cs
        a = Float64(phi_c_medio(c))
        b = phi_c_f64(c)
        peor = max(peor, abs(a - b) / a)
    end
    ok = peor < 1e-12
    L = String[@sprintf("peor discrepancia relativa kernel↔referencia en %d valores de c: %.3e", length(cs), peor)]
    return ok, L
end

# ---------------------------------------------------------------- O2

"Reducción *many-to-one* del Anexo F, comprobada exactamente (suma geométrica + forma de `Lambda`)."
function oraculo_many2one()
    g = identidad_geometrica()
    l = identidad_lambda()
    L = String[
        @sprintf("sum_{j=c}^{N} q^j + cola == q^c/(1-q), exacto en Rational{BigInt}: %s", g ? "OK" : "FALLA"),
        @sprintf("Lambda_c(t) == log(sum_{j>=c} (1/(1-t))^j), BigFloat, c hasta 1000: %s", l ? "OK" : "FALLA"),
    ]
    return (g && l), L
end

"""
    oraculo_brw(; cs, k, haz, hijos, replicas, semilla)

**ESTIMADO, no certificación.** `S*_k/k` simulado por haz sobre el árbol `T'` del Anexo F. El haz
trunca un árbol infinito y `k` es finito, así que el valor simulado es una **cota superior** de
`c/phi_c` y baja al ensanchar el haz. Se comprueban las dos propiedades falsables en esa
dirección (simulado > exacto; bajar el haz sube el valor). La tasa se certifica con
`phi_por_maximo` (O1) y con la reproducción de la Tabla 3 del paper, no con esto.
"""
function oraculo_brw(; cs=(1, 2, 3), k=7, haz=400, hijos=40, replicas=48, semilla=UInt64(0x5a5a5a5a))
    ok = true
    L = String[]
    push!(L, "c   c/phi_c(exacto)   S*_k/k(haz=400)   sesgo rel.")
    sesgos = Float64[]
    for c in cs
        expected = Float64(c) / Float64(phi_c_medio(c))
        v1 = brw_minimo(c; k=k, haz=haz, hijos=hijos, replicas=replicas, semilla=semilla)
        m1 = v1[cld(length(v1), 2)]
        sesgo = (m1 - expected) / expected
        push!(sesgos, sesgo)
        ok &= m1 > expected                       # truncamiento + k finito ⇒ cota superior
        push!(L, @sprintf("%-4d %-17.6f %-16.6f %+.3f", c, expected, m1, sesgo))
    end
    decreciente = all(sesgos[i] > sesgos[i + 1] for i in 1:(length(sesgos) - 1))
    ok &= decreciente
    push!(L, @sprintf("el sesgo decrece al crecer c (predicho por phi_c -> 1): %s", decreciente ? "OK" : "FALLA"))
    push!(L, "(estimado y truncado: NO certifica la tasa; contraste de construcción, no prueba)")
    return ok, L
end

# ---------------------------------------------------------------- O4

"O4: lema de ventana exhaustivo y conteo de clases de reto."
function oraculo_ventana(; cs=(1, 2, 3, 5), N=10)
    ok = true
    L = String[]
    for c in cs
        ok &= ventana_exhaustiva(c; Lmax=50)
        cnt = conteo_clases_ventana(c; N=N)
        # para c=1 el reto cambia en cada nivel; para c>1 se estabiliza en 2^(n-c+1) clases
        push!(L, @sprintf("c=%-3d lema de ventana exhaustivo: %s ; clases de reto a n=0..%d: %s",
                          c, ventana_exhaustiva(c; Lmax=50) ? "OK" : "FALLA", N, join(cnt, ",")))
        if c == 1
            ok &= all(cnt[n + 1] == 2^n for n in 0:N)
        end
    end
    return ok, L
end

# ---------------------------------------------------------------- resultado: umbral(d)

"""
    tabla_umbral_d(; ds)

`umbral(d)`, `phi_{d+1}` y la ventana de reutilización `c = d + 1`. `d = D_INF` es el diseño de
hoy (reto = flujo, C-POT-03): umbral 1/2 y ventana no acotada.
"""
function tabla_umbral_d(; ds=(0, 1, 2, 4, 9, 24, 49, 99, 249, 499, 999, 1999, 4999, 19999, D_INF))
    L = String[]
    push!(L, "d          c=d+1        phi_c          umbral(d)      ventana_reuso(bloques)")
    for d in ds
        if d == D_INF
            push!(L, @sprintf("%-10s %-12s %-14s %-14.6f %s", "inf", "inf", "1", 0.500000, "no acotada"))
        else
            c = d + 1
            p = Float64(phi_c_medio(c))
            u = Float64(umbral_d_medio(d))
            push!(L, @sprintf("%-10d %-12d %-14.6f %-14.6f %d", d, c, p, u, ventana_reuso(d)))
        end
    end
    return true, L
end

"""
    tabla_tipo_cambio(; betas)

El tipo de cambio del encargo, cuantificado: para cada umbral objetivo `beta`, el menor
`c = d + 1` que lo alcanza y la ventana de reutilización que hay que aceptar. Es la respuesta
numérica a F4.
"""
function tabla_tipo_cambio(; betas=(0.30, 0.35, 0.40, 0.45, 0.48, 0.49, 0.495))
    L = String[]
    push!(L, "umbral objetivo   c = d+1 minimo   d minimo   ventana de reutilizacion (bloques)   phi_c")
    for beta in betas
        c = c_para_umbral(beta; cmax=10^7, prec=192)
        if c === nothing
            push!(L, @sprintf("%-17.4f no alcanzable (el maximo es 1/2)", beta))
        else
            p = phi_c_f64(c)
            push!(L, @sprintf("%-17.4f %-17d %-10d %-36d %.6f", beta, c, c - 1, c, p))
        end
    end
    return true, L
end

# ---------------------------------------------------------------- cobertura(d)

"""
    tabla_cobertura(; L)

`cobertura(d)` para una rama privada de longitud `L` bloques: qué fracción de ella queda separada
del reto público. `L` es ENTRADA.
"""
function tabla_cobertura(; L=1000, ds=(0, 1, 9, 49, 99, 249, 499, 999, D_INF))
    Líneas = String[]
    push!(Líneas, @sprintf("rama privada de L = %d bloques", L))
    push!(Líneas, "d          c=d+1      bloques con reto compartido   bloques separados   cobertura(d)")
    for d in ds
        if d == D_INF
            push!(Líneas, @sprintf("%-10s %-10s %-29d %-19d %.4f", "inf", "inf", L, 0, 0.0))
        else
            bc = bloques_compartidos(d, L)
            bs = bloques_separados(d, L)
            push!(Líneas, @sprintf("%-10d %-10d %-29d %-19d %.4f", d, ventana_reuso(d), bc, bs, cobertura_rama(d, L)))
        end
    end
    return true, Líneas
end
