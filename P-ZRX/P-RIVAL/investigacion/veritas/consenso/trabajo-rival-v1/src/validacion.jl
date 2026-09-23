# src/validacion.jl — invariantes, bordes y contraejemplos.  Cada función devuelve
# una lista de (nombre, ok, detalle).  Ninguna comprobación compara una fórmula
# consigo misma: la ruta de cada una está comentada.
#
# Se incluye DESPUÉS de src/modelo.jl y src/referencia.jl (sin `using` de módulos).

# R1 · Control obligatorio θ = 0 y frontera exacta con signo estricto alrededor.
function control_theta_cero(; grid_βd = R(0):R(1)//7:R(1), grid_βx = R(0):R(1)//5:R(1),
                            grid_ρ = (R(1)//2, R(1), R(2)))
    out = Tuple{String,Bool,String}[]
    ok = true
    for β_d in grid_βd, β_x in grid_βx, ρ in grid_ρ
        (β_d + β_x) <= 1 || continue
        a = alpha_aditivo(β_d, β_x, R(0), ρ)
        c = alpha_control_prestamo(β_d, β_x)
        if a != c
            ok = false
            push!(out, ("control θ=0", false, "β_d=$β_d β_x=$β_x: $a ≠ $c"))
        end
        g0 = g_aditivo_desde_tasas(a, β_d, β_x, R(0), ρ)
        if g0 != 0
            ok = false
            push!(out, ("g(α*)=0 θ=0", false, "β_d=$β_d β_x=$β_x: g=$g0"))
        end
        δ = R(1)//10^6
        if a - δ >= 0 && g_aditivo_desde_tasas(a - δ, β_d, β_x, R(0), ρ) >= 0
            ok = false
            push!(out, ("signo estricto abajo", false, "β_d=$β_d β_x=$β_x"))
        end
        if a + δ <= 1 && g_aditivo_desde_tasas(a + δ, β_d, β_x, R(0), ρ) <= 0
            ok = false
            push!(out, ("signo estricto arriba", false, "β_d=$β_d β_x=$β_x"))
        end
    end
    push!(out, ("control θ=0 sobre la rejilla", ok,
                ok ? "todas las celdas exactas" : "hubo fallos"))
    return out
end

# R2 · Frontera por bisección (ruta independiente) contra la forma cerrada.
#      Sólo se comparan celdas con g(0) < 0 < g(1), donde la frontera es interior.
function control_biseccion(; grid_βd = (R(0), R(1)//10, R(1)//4, R(1)//2),
                           grid_βx = (R(0), R(1)//10), grid_θ = (R(0), R(1)//4, R(1)//2),
                           grid_ρ = (R(1)//2, R(1), R(6)//5))
    out = Tuple{String,Bool,String}[]
    ok = true
    vistas = 0
    for β_d in grid_βd, β_x in grid_βx, θ in grid_θ, ρ in grid_ρ
        2 * β_x + β_d <= 1 || continue
        g0 = g_aditivo_desde_tasas(R(0), β_d, β_x, θ, ρ)
        g1 = g_aditivo_desde_tasas(R(1), β_d, β_x, θ, ρ)
        (g0 < 0 && g1 > 0) || continue
        vistas += 1
        cerrada = alpha_aditivo(β_d, β_x, θ, ρ)
        bisec = alpha_por_biseccion(β_d, β_x, θ, ρ)
        ε = R(1)//2^40
        gmenos = g_aditivo_desde_tasas(bisec - ε, β_d, β_x, θ, ρ)
        gmas = g_aditivo_desde_tasas(bisec + ε, β_d, β_x, θ, ρ)
        if !(gmenos <= 0 <= gmas)
            ok = false
            push!(out, ("bisección: cambio de signo", false, "β_d=$β_d β_x=$β_x θ=$θ ρ=$ρ"))
        end
        if abs(bisec - cerrada) > R(1)//2^39
            ok = false
            push!(out, ("bisección vs cerrada", false,
                        "β_d=$β_d β_x=$β_x θ=$θ ρ=$ρ: |Δ|=$(abs(bisec - cerrada))"))
        end
    end
    push!(out, ("frontera por bisección ($vistas celdas interiores)", ok && vistas > 0,
                ok ? "coincide con la forma cerrada" : "hubo fallos"))
    return out
end

# R3 · Ventaja marginal: derivada simbólica contra diferencia finita exacta.
function control_marginal(; grid_θ = R(0):R(1)//8:R(7)//8,
                          grid_c = (R(0), R(1)//2, R(1), R(2)))
    out = Tuple{String,Bool,String}[]
    ok = true
    for θ in grid_θ, c in grid_c
        d = marginal_beta_d(θ, c)
        s = ventaja_marginal_aditiva(θ, c)
        if d != s
            ok = false
            push!(out, ("marginal β_d comprado", false, "θ=$θ c=$c: diferencia=$d simbólica=$s"))
        end
        dr = marginal_beta_d_reasignado(θ, c)
        if dr != (1 - θ) + 2 * θ * c
            ok = false
            push!(out, ("marginal β_d reasignado", false, "θ=$θ c=$c: $dr"))
        end
        dx = marginal_beta_x(θ, c)
        if dx != 2 * s
            ok = false
            push!(out, ("marginal β_x = 2×β_d comprado", false, "θ=$θ c=$c: $dx ≠ $(2 * s)"))
        end
    end
    push!(out, ("ventaja marginal", ok,
                ok ? "derivada = diferencia finita; β_x = 2×β_d (trabajo reasignado)" :
                     "hubo fallos"))
    return out
end

# R4 · La ventaja de umbral NO depende de θ: V = (β_d + 2β_x)/2 en toda la rejilla.
function control_ventaja_independiente(; grid_θ = R(0):R(1)//10:R(9)//10,
                                       grid_ρ = (R(1)//2, R(1), R(2)))
    out = Tuple{String,Bool,String}[]
    ok = true
    for θ in grid_θ, ρ in grid_ρ
        v = ventaja_umbral(R(1)//4, R(1)//8, θ, ρ)
        esperado = R(1)//4 // 2 + R(1)//8
        if v != esperado
            ok = false
            push!(out, ("ventaja independiente de θ", false, "θ=$θ ρ=$ρ: V=$v"))
        end
    end
    push!(out, ("la ventaja de umbral no depende de θ ni de ρ", ok,
                ok ? "V = (β_d+2β_x)/2 idéntico en toda la rejilla" : "hubo fallos"))
    return out
end

# R5 · θ* marginal: no existe en [0,1) salvo el caso degenerado c = 0 (θ* = 1).
function control_theta_estrella()
    out = Tuple{String,Bool,String}[]
    ok = true
    for c in (R(1)//2, R(1), R(2), R(10))
        if !(theta_estrella_marginal(c) === missing)
            ok = false
            push!(out, ("θ* marginal con c>0", false,
                        "c=$c devolvió $(theta_estrella_marginal(c))"))
        end
    end
    if theta_estrella_marginal(R(0)) != R(1)
        ok = false
        push!(out, ("θ* marginal con c=0", false,
                    "esperado 1, dio $(theta_estrella_marginal(R(0)))"))
    end
    push!(out, ("θ* marginal", ok,
                ok ? "no existe en [0,1) para c>0; =1 sólo si c=0 (espacio decorativo)" :
                     "hubo fallos"))
    return out
end

# R6 · Composición de umbral: enumeración exhaustiva de conteos enteros.
#      Dos propiedades que deciden la dicotomía:
#        (a) con hash de sobra en AMBOS lados, gana quien tiene más espacio (el grifo
#            es neutral en la frontera de espacio);
#        (b) con el atacante escaso de hash, el espacio no le sirve: β_d no ayuda.
function control_umbral(; D = 4, s_max = 10)
    out = Tuple{String,Bool,String}[]
    ok = true
    for s_pub in 0:s_max, s_priv in 0:s_max
        h_pub = D * s_pub + D
        h_priv = D * s_priv + D
        esperado = s_priv > s_pub ? 1 : (s_priv < s_pub ? -1 : 0)
        if umbral_enumera(s_pub, s_priv, h_pub, h_priv, D) != esperado
            ok = false
            push!(out, ("umbral (a) hash de sobra", false, "s_pub=$s_pub s_priv=$s_priv"))
        end
    end
    for s_pub in 1:s_max, s_priv in 0:s_max
        h_pub = D * s_pub + D
        if umbral_enumera(s_pub, s_priv, h_pub, D - 1, D) != -1
            ok = false
            push!(out, ("umbral (b) atacante escaso", false, "s_pub=$s_pub s_priv=$s_priv"))
        end
    end
    push!(out, ("compuerta de umbral", ok,
                ok ? "neutral con hash de sobra; inútil para el atacante escaso" : "hubo fallos"))
    return out
end

# R7 · Multiplicativa: control θ = 0 y frontera con ρ_priv = ρ_pub (no cambia el umbral).
function control_multiplicativo(; grid_βd = (R(0), R(1)//10, R(1)//4),
                                grid_βx = (R(0), R(1)//10))
    out = Tuple{String,Bool,String}[]
    ok = true
    for β_d in grid_βd, β_x in grid_βx
        c0 = alpha_control_prestamo(β_d, β_x)
        a0 = alpha_multiplicativo_biseccion(β_d, β_x, R(0), _ -> R(1), _ -> R(1))
        if abs(a0 - c0) > R(1)//2^30
            ok = false
            push!(out, ("multiplicativa θ=0", false, "β_d=$β_d β_x=$β_x: $a0 ≠ $c0"))
        end
        for θ in (R(1)//4, R(1)//2)
            a = alpha_multiplicativo_biseccion(β_d, β_x, θ, _ -> R(1), _ -> R(1))
            if abs(a - c0) > R(1)//2^30
                ok = false
                push!(out, ("multiplicativa ρ iguales", false,
                            "β_d=$β_d β_x=$β_x θ=$θ: $a ≠ $c0"))
            end
        end
    end
    push!(out, ("composición multiplicativa", ok,
                ok ? "reduce al control y conserva la frontera con ρ iguales" : "hubo fallos"))
    return out
end

# R8 · La ventaja de umbral NO baja con θ: V(θ,c) ≥ V(0,c) en toda la rejilla.
function control_ventaja_no_baja(; grid_θ = R(1)//10:R(1)//10:R(9)//10,
                                 grid_c = (R(0), R(1)//2, R(1), R(3)))
    out = Tuple{String,Bool,String}[]
    ok = true
    for θ in grid_θ, c in grid_c
        if ventaja_beta_d(θ, c) < ventaja_beta_d(R(0), c)
            ok = false
            push!(out, ("V(β_d) no baja", false, "θ=$θ c=$c"))
        end
        if ventaja_beta_d_reasignado(θ, c) < ventaja_beta_d_reasignado(R(0), c)
            ok = false
            push!(out, ("V(β_d reasignado) no baja", false, "θ=$θ c=$c"))
        end
        if ventaja_beta_x(θ, c) < 1
            ok = false
            push!(out, ("V(β_x) ≥ 1", false, "θ=$θ c=$c"))
        end
        if ventaja_beta_x(θ, c) != 2 * ventaja_beta_d(θ, c)
            ok = false
            push!(out, ("V(β_x) = 2×V(β_d comprado)", false, "θ=$θ c=$c"))
        end
    end
    push!(out, ("la pata no reduce la ventaja de umbral", ok,
                ok ? "V(θ,c) ≥ V(0,c); igual sólo con c=0" : "hubo fallos"))
    return out
end

# R9 · θ de cierre por imposibilidad: α*(θ_imp) = 1 exacto y θ_imp > 1/2.
function control_cierre_imposible(; grid_βd = (R(0), R(1)//10, R(1)//2),
                                  grid_βx = (R(0), R(1)//10),
                                  grid_ρ = (R(0), R(1)//2, R(9)//10))
    out = Tuple{String,Bool,String}[]
    ok = true
    for β_d in grid_βd, β_x in grid_βx, ρ in grid_ρ
        2 * β_x + β_d <= 1 || continue
        θ = theta_cierre_imposible(β_d, β_x, ρ)
        θ === missing && continue
        if θ < R(1)//2
            ok = false
            push!(out, ("θ_imp ≥ 1/2", false, "β_d=$β_d β_x=$β_x ρ=$ρ: θ=$θ"))
        end
        a = alpha_aditivo(β_d, β_x, θ, ρ)
        if a != 1
            ok = false
            push!(out, ("α*(θ_imp) = 1", false, "β_d=$β_d β_x=$β_x ρ=$ρ: α*=$a"))
        end
    end
    # ρ ≥ 1: la pata baja el umbral, no existe θ de cierre
    if theta_cierre_imposible(R(0), R(0), R(1)) !== missing
        ok = false
        push!(out, ("ρ ≥ 1 no cierra", false, "devolvió $(theta_cierre_imposible(R(0), R(0), R(1)))"))
    end
    push!(out, ("cierre por imposibilidad", ok,
                ok ? "α*(θ_imp) = 1 exacto y θ_imp ≥ 1/2 (igualdad sólo en β=0, ρ=0)" :
                     "hubo fallos"))
    return out
end

# R10 · Composición multiplicativa: V decrece con θ si ρ_pub > ρ_priv (honesto con
#       más trabajo), crece si ρ_pub < ρ_priv, y es constante si son iguales.
#       Contraste de la forma cerrada contra la bisección EXACTA (ruta distinta).
function control_multiplicativa_ventaja(; β_d = R(1)//10, β_x = R(1)//10)
    out = Tuple{String,Bool,String}[]
    ok = true
    for (ρ_priv, ρ_pub, esperado) in ((R(1)//2, R(1), :decrece),
                                      (R(1), R(1), :constante),
                                      (R(2), R(1), :crece))
        θs = (R(0), R(1)//10, R(1)//4, R(1)//2, R(3)//4, R(9)//10)
        vs = [ventaja_multiplicativa(Float64(β_d), Float64(β_x), Float64(θ),
                                     Float64(ρ_priv), Float64(ρ_pub)) for θ in θs]
        if esperado === :decrece
            any(vs[i+1] >= vs[i] for i in 1:length(vs)-1) && (ok = false;
                push!(out, ("multiplicativa decrece", false, "ρ_priv=$ρ_priv ρ_pub=$ρ_pub")))
        elseif esperado === :constante
            any(abs(vs[i] - vs[1]) > 1e-12 for i in 2:length(vs)) && (ok = false;
                push!(out, ("multiplicativa constante", false, "ρ iguales")))
        else
            any(vs[i+1] <= vs[i] for i in 1:length(vs)-1) && (ok = false;
                push!(out, ("multiplicativa crece", false, "ρ_priv=$ρ_priv ρ_pub=$ρ_pub")))
        end
    end
    # V(0) = β_d/2 + β_x en las tres
    if abs(ventaja_multiplicativa(0.1, 0.1, 0.0, 0.5, 1.0) - (0.05 + 0.1)) > 1e-12
        ok = false
        push!(out, ("multiplicativa V(0)", false, "no da β_d/2+β_x"))
    end
    # contraste cerrado vs bisección exacta
    for θ in (R(1)//4, R(1)//2)
        v_cerrado = ventaja_multiplicativa(0.1, 0.1, Float64(θ), 0.5, 1.0)
        a0 = alpha_multiplicativo_biseccion(R(0), R(0), θ, _ -> R(1)//2, _ -> R(1))
        a1 = alpha_multiplicativo_biseccion(R(1)//10, R(1)//10, θ, _ -> R(1)//2, _ -> R(1))
        v_exacto = Float64(a0 - a1)
        if abs(v_cerrado - v_exacto) > 1e-9
            ok = false
            push!(out, ("multiplicativa cerrada vs bisección", false,
                        "θ=$θ: $v_cerrado ≠ $v_exacto"))
        end
    end
    push!(out, ("composición multiplicativa: signo de la ventaja", ok,
                ok ? "decrece con ρ_pub>ρ_priv, constante si iguales, crece si ρ_pub<ρ_priv" :
                     "hubo fallos"))
    return out
end

function todas_las_validaciones()
    out = Tuple{String,Bool,String}[]
    append!(out, control_theta_cero())
    append!(out, control_biseccion())
    append!(out, control_marginal())
    append!(out, control_ventaja_independiente())
    append!(out, control_theta_estrella())
    append!(out, control_ventaja_no_baja())
    append!(out, control_cierre_imposible())
    append!(out, control_umbral())
    append!(out, control_multiplicativo())
    append!(out, control_multiplicativa_ventaja())
    return out
end
