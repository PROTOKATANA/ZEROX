#!/usr/bin/env julia
# DS-5 · comprobación de aritmética (NO es una auditoría LINEO completa: es aritmética de
# apoyo a un informe analítico, declarada así en DS5/INFORME.md). Reutiliza cifras ya
# validadas por DS-3 (resultados-DS2/MODELO.md, DS3/INFORME.md, DS3/escenarios.tsv) y la
# fórmula real de D-ZRX/SPEC.md §5 (C-SLA-03), no una invención.
#
# Ejecutar: env -u LD_LIBRARY_PATH /home/katana/torio/.juliaup/bin/julia comprobacion.jl

# ---------------------------------------------------------------------------
# 1) Forma M4-1 — la ya especificada en D-ZRX/SPEC.md C-SLA-03 (cuenta de claves n_e)
# ---------------------------------------------------------------------------
"""
    f_e_conteo(b, c, n_e)

Fracción de castigo de C-SLA-03: f_e = min(1, b + c*max(0, n_e-1)).
b, c son PENDIENTES en SPEC.md (dominio declarado: 0 < b <= 1, c >= 0).
"""
f_e_conteo(b::Float64, c::Float64, n_e::Int) = min(1.0, b + c*max(0, n_e-1))

"""
    f_e_saldo(gamma, S_e, T)

Forma alternativa, réplica funcional del "correlation penalty" de Ethereum
(eth2book.info/latest/part2/incentives/slashing/, verificado 2026-09-26,
`min(B, 3SB/T)`, multiplicador 3 desde Bellatrix): f_e = min(1, gamma*S_e/T),
escalando por FRACCIÓN DE SALDO TOTAL sancionado, no por número de claves.
"""
f_e_saldo(gamma::Float64, S_e::Float64, T::Float64) = min(1.0, gamma*S_e/T)

"""
    perdida(V, f_e)

C-SLA-03: perdida(P,e) = min(V(P,e), techo_exacto(f_e*V(P,e))).
Con Float64 (esto es una cota, no una liquidación de consenso): perdida <= V siempre.
"""
perdida(V::Float64, f_e::Float64) = min(V, f_e*V)

# ---------------------------------------------------------------------------
# 2) La grieta (P-CLAVE / DS-3): el atacante recluta N_recl claves con saldo < eps_saldo.
#    Cifras de DS3/INFORME.md §4.1 (alpha=0.33, P*=1e-3): N_recl=279; escenarios.tsv:
#    eps_saldo=0.01 u.e.; soborno nominal DS-3 = 1830 u.e./reclutado.
# ---------------------------------------------------------------------------
N_recl = 279
eps_saldo = 0.01          # u.e., escenarios.tsv
soborno_nominal_u = 1830.0 # u.e./reclutado, DS3/INFORME.md §4.1

println("=== 1) Cota superior de M4 bajo la grieta (cualquier forma con perdida<=V) ===")
for f_e in (0.0, 0.5, 1.0)
    V_i = eps_saldo # cota superior por clave (grieta: saldo < eps_saldo)
    perdida_i = perdida(V_i, f_e)
    total = N_recl * perdida_i
    razon = total / (N_recl*soborno_nominal_u)
    println("f_e=$(f_e)  perdida/clave<=$(perdida_i) u.e.  total<=$(round(total, digits=4)) u.e.  ",
            "razon frente al soborno nominal total = $(round(razon, sigdigits=3))")
end

println()
println("=== 2) Forma M4-1 (C-SLA-03, cuenta n_e) con b,c ilustrativos (PENDIENTES en SPEC) ===")
for (b,c) in ((0.1,0.01),(0.1,0.001),(0.05,0.0001))
    for n_e in (1, 10, 100, 279)
        fe = f_e_conteo(b,c,n_e)
        println("b=$(b) c=$(c) n_e=$(n_e) -> f_e=$(round(fe,digits=4))")
    end
end

println()
println("=== 3) Forma M4-2 (estilo Ethereum, fraccion de saldo S_e/T) ===")
T_total = 1.0e6 # u.e., escenario ilustrativo de saldo activo total de la red
for gamma in (1.0,3.0)
    for S_e in (1.0, 100.0, 1.0e4, 3.34e5) # ultimo ~ 1/3 de T
        fe = f_e_saldo(gamma, S_e, T_total)
        println("gamma=$(gamma) S_e=$(S_e) T=$(T_total) -> f_e=$(round(fe,digits=6))")
    end
end

println()
println("=== 4) Honesto correlacionado catastrofico (M4-1): umbral de c para no saturar ===")
# Si una fraccion p_share de N_activos claves activas comparte una falla comun de
# software (evento no malicioso), n_e ~ p_share*N_activos. Se busca el c maximo tal que
# f_e no sature (quede por debajo de 1) para un b dado.
b_fijo = 0.1
for N_activos in (1_000, 10_000, 100_000)
    for p_share in (0.01, 0.05, 0.10)
        n_e = max(1, round(Int, p_share*N_activos))
        # f_e = 1  =>  c = (1-b)/(n_e-1)
        c_max = n_e > 1 ? (1.0-b_fijo)/(n_e-1) : Inf
        println("N_activos=$(N_activos) p_share=$(p_share) -> n_e=$(n_e)  c_max_sin_saturar=$(round(c_max, sigdigits=4))")
    end
end
