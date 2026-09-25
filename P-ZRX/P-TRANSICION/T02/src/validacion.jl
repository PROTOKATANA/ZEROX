# validacion.jl — comparación referencia ↔ simulador (T02).
#
# El oráculo es la fórmula cerrada donde existe; el simulador debe caer dentro de
# su intervalo de Wilson al 99,9 % (ORDEN-T02 §6, CORRECCION-T02-A).

module Validacion

using ..Modelo
using ..Referencia
using ..Rapido

struct Chequeo
    etiqueta::String
    n::Int
    exitos::Int
    p_mc::Float64
    lo::Float64
    hi::Float64
    p_ref::Float64
    ok::Bool
end

function chequear(etiqueta::String, exitos::Int, n::Int, p_ref::Float64)
    p, lo, hi = wilson(exitos, n)
    return Chequeo(etiqueta, n, exitos, p, lo, hi, p_ref, lo <= p_ref <= hi)
end

# --- E1: MC contra la fórmula de Nakamoto (y la tabla publicada) -----------
# Error máximo de la fórmula frente a la tabla publicada del artículo.
function error_tabla_nakamoto()
    mx = 0.0
    for (h, z, pref) in TABLA_NAKAMOTO
        mx = max(mx, abs(e1_prob(z, h) - pref))
    end
    return mx
end

function validar_e1(nrep::Int, master::UInt64)
    out = Chequeo[]
    idx = 0
    for h in H_GRID, z in Z_GRID
        idx += 1
        pt = PuntoE1(idx, h, z)
        exito = Vector{Bool}(undef, nrep)
        k = correr_e1!(exito, pt, nrep, master)
        push!(out, chequear("E1 MC h=$h z=$z", k, nrep, e1_prob(z, h)))
    end
    return out
end

# --- E3: MC contra la fórmula exacta ---------------------------------------
function validar_e3(nrep::Int, master::UInt64)
    out = Chequeo[]
    idx = 0
    for h in (0.25, 0.6), a in (0.1, 0.4), k in (3, 12), delta in (0.01, 0.1),
        r in (1/10, 1.0), Fs in (100.0, 1000.0)
        idx += 1
        pt = PuntoE3(idx, h, a, k, delta, r, 0.9, Fs)
        res = correr_e3(pt, nrep, master)
        push!(out, chequear("E3 FC1 h=$h a=$a k=$k d=$delta r=$r F=$Fs",
                            res.fc1_part, nrep,
                            e3_prob_fc1(h, a, k, delta, r, 0.9, Fs)))
        push!(out, chequear("E3 FC3 h=$h a=$a k=$k d=$delta r=$r",
                            res.fc3, nrep, e3_prob_fc3(h, a, k, delta, r, 0.9)))
    end
    return out
end

# --- E2: MC (sin horizonte efectivo) contra la fórmula exacta --------------
function validar_e2(nrep::Int, master::UInt64)
    out = Chequeo[]
    idx = 0
    for h in (0.25, 0.6), a in (0.1, 0.25, 0.4), k in (3, 6), r in (1/10,)
        idx += 1
        pt = PuntoE2(idx, h, a, k, r, 0.9, Inf)
        res = correr_e2(pt, nrep, master)
        pref = e2_prob_sin_horizonte(h, a, k, r, 0.9)
        push!(out, chequear("E2 h=$h a=$a k=$k r=$r", res.ge_nuevo, nrep, pref))
    end
    return out
end

# --- E4: borde h→0: el corte ocurre como Gamma(1+M_dep, 1) -----------------
function validar_e4(nrep::Int, master::UInt64)
    out = Chequeo[]
    for Mdep in (1, 3, 6, 12)
        pt = PuntoE4(Mdep, 0.1, Mdep)
        res = correr_e4(pt, nrep, master)
        # P(corte antes del horizonte) ≈ 1 para h pequeño.
        push!(out, chequear("E4 h=0.1 Mdep=$Mdep (corte)", res.cortes, nrep, 1.0))
    end
    return out
end

export Chequeo, chequear, error_tabla_nakamoto, validar_e1, validar_e2, validar_e3, validar_e4

end # module
