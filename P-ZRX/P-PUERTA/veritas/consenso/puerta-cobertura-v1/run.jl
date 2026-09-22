#!/usr/bin/env julia
#
# PCO-v0.1 — CLI reproducible. Todos los comandos y su salida estan en METODO.md.
# Ninguna cifra del informe se escribe a mano: sale de una de estas ordenes, que la vuelca en
# `resultados/*.csv` con sus parametros al lado.

using Printf
using Dates
using LinearAlgebra
using InteractiveUtils

const AQUI = @__DIR__
include(joinpath(AQUI, "src", "PuertaCobertura.jl"))
using .PuertaCobertura
using Arblib

const RES = joinpath(AQUI, "resultados")

csv(nombre) = joinpath(RES, nombre)

function entorno()
    println("# entorno PCO-v0.1")
    println("fecha            = ", Dates.now())
    println("git HEAD         = ", strip(read(`git -C $(AQUI) rev-parse HEAD`, String)))
    println("VERSION          = ", VERSION)
    println("nthreads default = ", Threads.nthreads(:default))
    println("nthreads interact= ", Threads.nthreads(:interactive))
    println("CPU              = ", Sys.CPU_NAME, "  (", Sys.CPU_THREADS, " hilos logicos)")
    println("RAM total        = ", @sprintf("%.1f GiB", Sys.total_memory() / 2^30))
    println("BLAS             = ", BLAS.get_config())
    println("BLAS threads     = ", BLAS.get_num_threads())
    println("OPENBLAS_NUM_THREADS = ", get(ENV, "OPENBLAS_NUM_THREADS", "(sin fijar)"))
    println("JULIA_NUM_THREADS    = ", get(ENV, "JULIA_NUM_THREADS", "(sin fijar)"))
end

# ---------------------------------------------------------------- punto 1: el modelo de peso

"""Barrido del punto 1: la cancelacion del `SR`, en enteros exactos."""
function barrido_peso()
    open(csv("peso.csv"), "w") do io
        println(io, "piezas,SR,paridad,valores_aceptados,SR_mas_1,resto_suelo,",
                    "desviacion_exacta_num,desviacion_exacta_den,desviacion_float")
        for e in 3:16
            piezas = BigInt(10)^e
            SR = rango_de_piezas(piezas)
            SR < 1 && continue
            for sr in (SR, SR + (iseven(SR) ? 1 : -1))
                d = desviacion_cancelacion(sr)
                println(io, join((piezas, sr, iseven(sr) ? "par" : "impar",
                                  valores_aceptados(sr), sr + 1, resto_suelo(sr),
                                  numerator(d), denominator(d), Float64(d)), ","))
            end
        end
        # el borde: el rango minimo que el repositorio ha barajado y el maximo del tipo
        for sr in (BigInt(2)^11, BigInt(2)^11 + 1, BigInt(1), BigInt(2), SR_MAX, SR_MAX - 1)
            d = desviacion_cancelacion(sr)
            println(io, join((0, sr, iseven(sr) ? "par" : "impar", valores_aceptados(sr),
                              sr + 1, resto_suelo(sr), numerator(d), denominator(d),
                              Float64(d)), ","))
        end
    end

    open(csv("peso-sesgo.csv"), "w") do io
        println(io, "c,s1,W1,W2,piezas_totales,paridad1,paridad2,SR1,SR2,",
                    "sesgo_num,sesgo_den,sesgo_float,razon_espacios")
        for c in (0//1, 1//2, 9//10, 99//100), s1 in (3//5, 3//4, 1//1)
            W₁, W₂ = espacio_cubridor(c, s1)
            W₂ == 0 && continue
            for tot in (BigInt(10)^9, BigInt(10)^12)
                P1 = numerator(W₁ * tot) ÷ denominator(W₁ * tot)
                P2 = numerator(W₂ * tot) ÷ denominator(W₂ * tot)
                (P1 < 1 || P2 < 1) && continue
                for par1 in (:par, :impar), par2 in (:par, :impar)
                    SR1 = rango_retarget(P1, 1//1; paridad=par1)
                    SR2 = rango_retarget(P2, 1//1; paridad=par2)
                    s = sesgo_tasa(P1, P2, SR1, SR2)
                    println(io, join((c, s1, W₁, W₂, tot, par1, par2, SR1, SR2,
                                      numerator(s), denominator(s), Float64(s),
                                      Float64(W₁ / W₂)), ","))
                end
            end
        end
    end

    # la parte que NO se cancela: la fraccion azul en el transitorio
    open(csv("peso-beta.csv"), "w") do io
        println(io, "c,s1,W1,W2,nu0,Delta,k,beta1,beta2,razon_beta,razon_espacios,",
                    "razon_tasas_peso,sesgo_por_beta")
        for c in (0//1, 1//2, 9//10), s1 in (3//5, 3//4, 1//1), ν₀ in (0.1, 1.0), Δ in (1.0, 4.0, 16.0)
            for k in (18, 30)
                W₁, W₂ = espacio_cubridor(c, s1)
                W₂ == 0 && continue
                β₁ = fraccion_azul(float(W₁) * ν₀, Δ, k)
                β₂ = fraccion_azul(float(W₂) * ν₀, Δ, k)
                rz = float(W₁ / W₂)
                rt = (β₁ * float(W₁)) / (β₂ * float(W₂))
                println(io, join((c, s1, float(W₁), float(W₂), ν₀, Δ, k, β₁, β₂, β₁ / β₂,
                                  rz, rt, rt / rz - 1), ","))
            end
        end
    end
    println("escritos: peso.csv, peso-sesgo.csv, peso-beta.csv")
end

# ---------------------------------------------------------- punto 2: la dinamica con adopcion

const CS = (0//1, 1//4, 1//2, 3//4, 9//10, 95//100, 99//100, 1//1)
const S1S = (1//2, 11//20, 3//5, 3//4, 9//10, 1//1)
const EPS = (1e-3, 1e-6, 1e-9)
const FS = (600.0, 3600.0, 7200.0, 11520.0, 19080.0)   # s; ninguno es «el» F: son la rejilla

function barrido_dinamica(λ::Float64)
    open(csv("dinamica.csv"), "w") do io
        println(io, "regimen,c,s1,W1,W2,r,lambda1,lambda2,deriva,R_lundberg,I,",
                    "t_eps_1e-3_inf,t_eps_1e-3_sup,t_eps_1e-6_inf,t_eps_1e-6_sup,",
                    "t_eps_1e-9_inf,t_eps_1e-9_sup,",
                    join(["L_F_$(Int(F))_inf,L_F_$(Int(F))_sup,empate_F_$(Int(F))" for F in FS], ","))
        for c in CS, s1 in S1S
            W₁, W₂ = espacio_cubridor(c, s1)
            W₂ == 0 && continue
            for (nom, f) in (("regimen", flujos_regimen(c, s1, λ)),
                             ("transitorio", flujos_transitorio(c, s1, λ, 4.0, 30)))
                ts = [tiempo_hasta(f, ε) for ε in EPS]
                ls = Float64[]
                for F in FS
                    lo, hi = prob_cambio_posterior(f, F)
                    e, _ = prob_empate(f, F)
                    append!(ls, (lo, hi, e))
                end
                println(io, join((nom, c, s1, float(W₁), float(W₂), float(f.r), f.λ₁, f.λ₂,
                                  deriva(f), lundberg(f), tasa_grandes_desvios(f),
                                  ts[1][1], ts[1][2], ts[2][1], ts[2][2], ts[3][1], ts[3][2],
                                  ls...), ","))
            end
        end
    end
    println("escrito: dinamica.csv")
end

"""Curva `L(t)` completa para las celdas que el informe dibuja."""
function barrido_curva(λ::Float64)
    open(csv("curva-L.csv"), "w") do io
        println(io, "regimen,c,s1,t,L_inf,L_sup,empate")
        for c in (0//1, 1//2, 9//10, 99//100, 1//1), s1 in (1//2, 3//5, 1//1)
            W₁, W₂ = espacio_cubridor(c, s1)
            W₂ == 0 && continue
            for (nom, f) in (("regimen", flujos_regimen(c, s1, λ)),
                             ("transitorio", flujos_transitorio(c, s1, λ, 4.0, 30)))
                for t in (1.0, 3.0, 10.0, 30.0, 100.0, 300.0, 1000.0, 3000.0, 10_000.0,
                          30_000.0, 100_000.0)
                    lo, hi = prob_cambio_posterior(f, t)
                    e, _ = prob_empate(f, t)
                    println(io, join((nom, c, s1, t, lo, hi, e), ","))
                end
            end
        end
    end
    println("escrito: curva-L.csv")
end

# ------------------------------------------------- punto 2b: absorcion, divergencia, realimentacion

function barrido_absorcion(λ::Float64, replicas_base::Int, semilla::UInt64, tope_eventos::Float64)
    open(csv("absorcion.csv"), "w") do io
        println(io, "regimen,c,s1,F,lambda,replicas,T_max,censurados,mediana_abs,media_abs,",
                    "divergencia,div_inf,div_sup,cota_L_F_sup,eventos")
        for c in (0//1, 1//2, 3//4, 9//10), s1 in (1//2, 3//5, 3//4), F in (600.0, 7200.0)
            W₁, W₂ = espacio_cubridor(c, s1)
            W₂ == 0 && continue
            f = flujos_regimen(c, s1, λ)
            t3 = tiempo_hasta(f, 1e-3)[2]
            T = min(isfinite(t3) ? 6 * t3 + 4 * F : 40 * F, 4.0e6)
            Λ = f.λ₁ + f.λ₂
            n = max(200, min(replicas_base, floor(Int, tope_eventos / (Λ * T))))
            cs = replicas(f, T, F, n, semilla)
            r = resumen_absorcion(cs)
            cota = prob_cambio_posterior(f, F)[2]
            println(io, join(("regimen", c, s1, F, λ, n, T, r.censurados, r.mediana, r.media,
                              r.divergencia, r.div_inf, r.div_sup, cota, n * Λ * T), ","))
        end
    end

    open(csv("realimentacion.csv"), "w") do io
        println(io, "c,s1,F,lambda,rho,replicas,T_max,censurados,mediana_abs,media_abs,",
                    "divergencia,aceleracion_mediana")
        for c in (1//2, 3//4, 9//10), s1 in (1//2, 3//5), F in (600.0,)
            f = flujos_regimen(c, s1, λ)
            t3 = tiempo_hasta(f, 1e-3)[2]
            T = min(isfinite(t3) ? 6 * t3 + 4 * F : 40 * F, 4.0e6)
            Λ = 2 * λ
            n = max(200, min(replicas_base, floor(Int, tope_eventos / (Λ * T))))
            base = resumen_absorcion(replicas(f, T, F, n, semilla))
            for ρ in (0.0, 1e-5, 1e-4, 1e-3)
                cs = replicas_realimentadas(float(c), float(s1), λ, ρ, T, F, n, semilla)
                r = resumen_absorcion(cs)
                acel = (isnan(base.mediana) || isnan(r.mediana)) ? NaN : base.mediana / r.mediana
                println(io, join((c, s1, F, λ, ρ, n, T, r.censurados, r.mediana, r.media,
                                  r.divergencia, acel), ","))
            end
        end
    end
    println("escritos: absorcion.csv, realimentacion.csv")
end

# --------------- punto 2c: el congelamiento simultaneo (regla de R-FIN-7 por profundidad)

const TAUS = (1.0, 4.0, 16.0, 60.0)

"""
Barrido del **congelamiento divergente** bajo la lectura literal de R-FIN-7: la profundidad de la
reorganizacion para cambiar de flujo es `t − t_j`, luego todos los nodos se congelan a la vez en
`t_j + F` y la unica grieta es el desfase de vista.
"""
function barrido_congelamiento(λ::Float64, replicas_base::Int, semilla::UInt64)
    open(csv("congelamiento.csv"), "w") do io
        println(io, "regimen,c,s1,F,tau,lambda,deriva,p_div,p_div_cota,arcoseno_difusion,",
                    "delta_red,banda_delta,L_F_inf,L_F_sup,mc,mc_inf,mc_sup,replicas")
        for c in CS, s1 in S1S
            W₁, W₂ = espacio_cubridor(c, s1)
            W₂ == 0 && continue
            for (nom, f) in (("regimen", flujos_regimen(c, s1, λ)),
                             ("transitorio", flujos_transitorio(c, s1, λ, 4.0, 30)))
                for F in FS, τ in TAUS
                    v, e = prob_congelamiento_divergente(f, F, τ)
                    d = delta_red(f, τ)
                    b, _ = prob_banda(f, F, d)
                    lo, hi = prob_cambio_posterior(f, F)
                    mc = (NaN, NaN, NaN)
                    if F == 600.0 && (τ == 4.0 || τ == 16.0)
                        mc = mc_congelamiento(f, F, τ, replicas_base, semilla)
                    end
                    println(io, join((nom, c, s1, F, τ, λ, deriva(f), v, e,
                                      congelamiento_arcoseno(F, τ), d, b, lo, hi,
                                      mc[1], mc[2], mc[3], replicas_base), ","))
                end
            end
        end
    end

    open(csv("congelamiento-realimentado.csv"), "w") do io
        println(io, "c,s1,F,tau,lambda,rho,replicas,p_div,p_div_inf,p_div_sup,razon_frente_a_rho0")
        for c in (1//2, 3//4, 9//10), s1 in (1//2, 3//5), F in (600.0, 7200.0), τ in (4.0,)
            base = mc_congelamiento_realimentado(c, s1, λ, 0.0, F, τ, replicas_base, semilla)[1]
            for ρ in (0.0, 1e-5, 1e-4, 1e-3)
                p, lo, hi = mc_congelamiento_realimentado(c, s1, λ, ρ, F, τ, replicas_base, semilla)
                println(io, join((c, s1, F, τ, λ, ρ, replicas_base, p, lo, hi,
                                  base == 0 ? NaN : p / base), ","))
            end
        end
    end
    println("escritos: congelamiento.csv, congelamiento-realimentado.csv")
end

# ------------------------------------------------------------------- punto 3: cobertura

function barrido_cobertura()
    m = costes_repositorio()
    open(csv("smax.csv"), "w") do io
        println(io, "dur_slot_s,verif_pot_s,iops_por_TiB,nucleos,cap_TiB,",
                    "lecturas_por_TiB,nucleos_aud_por_TiB,nucleos_verif,nucleos_prod,",
                    "S_iops,S_nucleos,S_max")
        for ds in (0.1, 1.0, 6.0), vp in (0.092, 0.101, 0.190)
            mm = costes_repositorio(; dur_slot_s=ds, verif_pot_s=vp)
            for ι in (2_000.0, 10_000.0, 25_000.0, 100_000.0, 250_000.0)
                for nc in (4.0, 8.0, 16.0, 32.0), cap in (1.0, 4.0, 20.0, 100.0, 1000.0)
                    println(io, join((ds, vp, ι, nc, cap, lecturas_por_TiB(mm),
                                      nucleos_auditoria_por_TiB(mm), nucleos_verif_pot(mm),
                                      nucleos_prod_pot(mm), s_max_iops(mm, ι),
                                      s_max_nucleos(mm, nc, cap), s_max(mm, ι, nc, cap)), ","))
                end
            end
        end
    end

    open(csv("cobertura.csv"), "w") do io
        println(io, "rho_var,rho_fij_TiB,p_gana,x_min_TiB,x_min_productor_TiB,",
                    "umbral_p_1TiB,umbral_p_100TiB,c_equilibrio_pareto_a1,c_equilibrio_pareto_a2")
        for ρv in (0.0, 1e-4, 1e-3, 1e-2, 1e-1, 0.5), ρf in (1e-4, 1e-2, 1.0, 100.0, 1e4)
            ρp = ρf * nucleos_prod_pot(m) / nucleos_verif_pot(m)
            for p in (1e-6, 1e-3, 1e-2, 1e-1, 0.5)
                xmin = tamano_minimo(p, ρv, ρf)
                xprod = tamano_minimo_productor(p, ρv, ρf, ρp)
                cs = Float64[]
                for α in (1.0, 2.0)
                    xs, w = pareto_tamanos(0.5, α, 400)
                    push!(cs, cobertura_equilibrio(xs, w, xmin))
                end
                println(io, join((ρv, ρf, p, xmin, xprod, umbral_probabilidad(1.0, ρv, ρf),
                                  umbral_probabilidad(100.0, ρv, ρf), cs[1], cs[2]), ","))
            end
        end
    end
    println("escritos: smax.csv, cobertura.csv")
end

# ---------------------------------------------------------------- punto 4: la ley de arcoseno

function barrido_arcoseno(λ::Float64, replicas_base::Int, semilla::UInt64)
    open(csv("arcoseno-exacto.csv"), "w") do io
        println(io, "n,media_exacta_num,media_exacta_den,media_float,p_ultimo_mayor_0_9,",
                    "p_ultimo_mayor_0_99,continua_0_9,continua_0_99")
        for n in (10, 50, 100, 500, 1000)
            p = arcoseno_discreta(n)
            med = media_arcoseno_discreta(n)
            p09 = sum(p[k+1] for k in 0:n if k / n > 0.9; init=zero(Rational{BigInt}))
            p099 = sum(p[k+1] for k in 0:n if k / n > 0.99; init=zero(Rational{BigInt}))
            println(io, join((n, numerator(med), denominator(med), Float64(med),
                              Float64(p09), Float64(p099),
                              1 - arcoseno_continua(0.9), 1 - arcoseno_continua(0.99)), ","))
        end
    end

    # el contraste historico, calculado y no copiado: que horizonte implica cada cifra de la
    # ronda 3 bajo la ley del arcoseno, y que da el modelo de aqui con ese horizonte
    open(csv("arcoseno-contraste.csv"), "w") do io
        println(io, "magnitud,valor_historico,t_referencia,horizonte_implicito_s,",
                    "cola_arcoseno_en_ese_horizonte,epoca_declarada_s")
        # (1) P(cambia tras 600 s) = 0,82, ronda 3 (candidatos-auditoria.md:20-33)
        T1 = horizonte_implicito_cola(0.82, 600.0)
        println(io, join(("P(cambio tras 600 s)", 0.82, 600.0, T1,
                          cola_arcoseno(600.0 / T1), 205.7), ","))
        # (2) instante del ultimo cambio = 203,6 s, ronda 3, con epoca de 205,7 s
        T2 = horizonte_implicito_media(203.6)
        println(io, join(("instante del ultimo cambio", 203.6, 203.6, T2,
                          cola_arcoseno(203.6 / T2), 205.7), ","))
        # (3) lo que la ley del arcoseno da si el horizonte ES la epoca de 205,7 s
        println(io, join(("media si T = la epoca", 205.7 / 2, 205.7, 205.7,
                          cola_arcoseno(600.0 / 205.7), 205.7), ","))
        # (4) barrido de horizontes: que P(cambio tras 600 s) predice cada uno
        for T in (600.0, 1000.0, 2000.0, 6000.0, 7708.0, 20_000.0)
            println(io, join(("barrido", NaN, 600.0, T, cola_arcoseno(600.0 / T),
                              205.7), ","))
        end
    end

    open(csv("arcoseno-mc.csv"), "w") do io
        println(io, "regimen,c,s1,T,lambda,replicas,sin_cambio,media_rel,mediana_rel,",
                    "p_cambio_tras_600,p_inf,p_sup,L_600_inf,L_600_sup")
        for c in (0//1, 1//2, 9//10, 99//100, 1//1), s1 in (1//2, 3//5, 1//1)
            W₁, W₂ = espacio_cubridor(c, s1)
            W₂ == 0 && continue
            for (nom, f) in (("regimen", flujos_regimen(c, s1, λ)),
                             ("transitorio", flujos_transitorio(c, s1, λ, 4.0, 30)))
                for T in (205.7, 600.0, 6000.0)
                    cs = replicas(f, T, T + 1.0, replicas_base, semilla)
                    r = resumen_ultimo_cambio(cs, T; t_ref=600.0)
                    lo, hi = prob_cambio_posterior(f, 600.0)
                    println(io, join((nom, c, s1, T, λ, replicas_base, r.sin_cambio,
                                      r.media_rel, r.mediana_rel, r.p_despues, r.p_inf,
                                      r.p_sup, lo, hi), ","))
                end
            end
        end
    end
    println("escritos: arcoseno-exacto.csv, arcoseno-mc.csv")
end

# ----------------------------------------------------------------------- certificacion Arb

function barrido_certificado(λ::Float64)
    open(csv("certificado.csv"), "w") do io
        println(io, "regimen,c,s1,t,rap_inf,rap_sup,arb_inf,arb_sup,solapa,",
                    "R_arb_inf,R_arb_sup,I_arb_inf,I_arb_sup")
        for c in (0//1, 1//2, 9//10, 1//1), s1 in (1//2, 3//5)
            W₁, W₂ = espacio_cubridor(c, s1)
            W₂ == 0 && continue
            for (nom, f) in (("regimen", flujos_regimen(c, s1, λ)),
                             ("transitorio", flujos_transitorio(c, s1, λ, 4.0, 30)))
                R = lundberg_arb(f)
                I = tasa_grandes_desvios_arb(f)
                for t in (10.0, 100.0, 600.0)
                    lo, hi = prob_cambio_posterior(f, t)
                    b = prob_cambio_posterior_arb(f, t)
                    blo = Float64(Arblib.lbound(b)); bhi = Float64(Arblib.ubound(b))
                    println(io, join((nom, c, s1, t, lo, hi, blo, bhi,
                                      !(hi < blo * (1 - 1e-10) || lo > bhi * (1 + 1e-10)),
                                      Float64(Arblib.lbound(R)), Float64(Arblib.ubound(R)),
                                      Float64(Arblib.lbound(I)), Float64(Arblib.ubound(I))), ","))
                end
            end
        end
    end
    println("escrito: certificado.csv")
end

# ------------------------------------------------------------------------------- CLI

function main(args)
    λ = 1.0
    replicas_base = 4000
    semilla = UInt64(0x5A5A)
    tope_eventos = 4.0e8
    i = 1
    cmds = String[]
    while i <= length(args)
        a = args[i]
        if a == "--lambda"; λ = parse(Float64, args[i+1]); i += 2
        elseif a == "--replicas"; replicas_base = parse(Int, args[i+1]); i += 2
        elseif a == "--seed"; semilla = parse(UInt64, args[i+1]); i += 2
        elseif a == "--tope-eventos"; tope_eventos = parse(Float64, args[i+1]); i += 2
        else; push!(cmds, a); i += 1
        end
    end
    isempty(cmds) && (cmds = ["--ayuda"])
    for c in cmds
        t0 = time()
        if c == "--entorno"; entorno()
        elseif c == "--peso"; barrido_peso()
        elseif c == "--dinamica"; barrido_dinamica(λ); barrido_curva(λ)
        elseif c == "--absorcion"; barrido_absorcion(λ, replicas_base, semilla, tope_eventos)
        elseif c == "--congelamiento"; barrido_congelamiento(λ, replicas_base, semilla)
        elseif c == "--cobertura"; barrido_cobertura()
        elseif c == "--arcoseno"; barrido_arcoseno(λ, replicas_base, semilla)
        elseif c == "--certificado"; barrido_certificado(λ)
        elseif c == "--todo"
            entorno(); barrido_peso(); barrido_dinamica(λ); barrido_curva(λ)
            barrido_cobertura(); barrido_arcoseno(λ, replicas_base, semilla)
            barrido_congelamiento(λ, replicas_base, semilla)
            barrido_absorcion(λ, replicas_base, semilla, tope_eventos); barrido_certificado(λ)
        else
            println("""uso: run.jl [--lambda L] [--replicas N] [--seed S] [--tope-eventos E] ORDEN...
                       ordenes: --entorno --peso --dinamica --congelamiento --absorcion
                                --cobertura --arcoseno --certificado --todo""")
        end
        c != "--ayuda" && @printf("[%s] %.1f s\n", c, time() - t0)
    end
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    main(ARGS)
end
