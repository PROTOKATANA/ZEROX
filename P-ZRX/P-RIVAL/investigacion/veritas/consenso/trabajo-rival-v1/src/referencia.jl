# src/referencia.jl — oráculos independientes y exactos (Rational{BigInt})
#
# Regla del encargo §4: "Un test que compara una fórmula consigo misma no es un test".
# Aquí cada ruta es DISTINTA de la que valida:
#   · la deriva se reconstruye desde las tasas W_b (no desde la expresión factorizada);
#   · la frontera se resuelve por bisección sobre g (no despejando α);
#   · la ventaja marginal se mide por diferencia finita exacta (no por la derivada simbólica);
#   · la compuerta se resuelve por enumeración exhaustiva de conteos enteros.

# ---------------------------------------------------------------------------
# O1 · Deriva reconstruida desde las tasas de peso (ruta distinta de g_aditivo)
# ---------------------------------------------------------------------------
function tasas_aditivas(α, β_d, β_x, θ, ρ)
    W_pub = (1 - θ) * espacio_publico(α, β_d, β_x) + θ * 1     # ρ_pub = 1 (honesto de referencia)
    W_priv = (1 - θ) * espacio_privado(α, β_d, β_x) + θ * ρ
    return W_pub, W_priv
end
function g_aditivo_desde_tasas(α, β_d, β_x, θ, ρ)
    W_pub, W_priv = tasas_aditivas(α, β_d, β_x, θ, ρ)
    return W_priv - W_pub
end

# ---------------------------------------------------------------------------
# O2 · Frontera por bisección exacta sobre g (ruta distinta de alpha_aditivo)
# ---------------------------------------------------------------------------
function alpha_por_biseccion(β_d, β_x, θ, ρ; iter = 512, lo = R(0), hi = R(1))
    f(α) = g_aditivo_desde_tasas(α, β_d, β_x, θ, ρ)
    f(lo) >= 0 && return R(0)                 # el atacante ya gana sin espacio propio
    f(hi) <= 0 && return R(1)                 # el honesto gana incluso con α = 1
    for _ in 1:iter
        m = (lo + hi) // 2
        if f(m) >= 0
            hi = m
        else
            lo = m
        end
    end
    return (lo + hi) // 2
end

# ---------------------------------------------------------------------------
# O3 · Ventaja marginal por diferencia finita EXACTA
#      g es afín en β_d y en β_x, así que la diferencia dividida es exacta.
#
#      Tres variantes, porque la compuerta admite dos formas de pagar el trabajo
#      de la segunda rama:
#        · β_d comprado    : el doble granjero COMPRA hash nuevo para la privada.
#        · β_d reasignado  : el doble granjero MUEVE hash de la pública a la privada.
#        · β_x             : el espacio abandona la pública y el trabajo se mueve con él
#                            (coste rival neto nulo, efecto de espacio doble).
# ---------------------------------------------------------------------------
function marginal_beta_d(θ, c)
    # ρ_priv = 1 + c·β_d, ρ_pub = 1 (trabajo nuevo comprado)
    g(β_d) = g_aditivo_desde_tasas(R(0), β_d, R(0), θ, 1 + c * β_d)
    return g(R(1)) - g(R(0))
end
function marginal_beta_d_reasignado(θ, c)
    # ρ_priv = 1 + c·β_d, ρ_pub = 1 − c·β_d (el mismo trabajo cambia de rama)
    gp(β_d) = (1 - θ) * (β_d - 1) + θ * ((1 + c * β_d) - (1 - c * β_d))
    return gp(R(1)) - gp(R(0))
end
function marginal_beta_x(θ, c)
    # β_x: σ_pub = 1 − α − β_x, σ_priv = α + β_x, y el trabajo acompaña al espacio
    gp(β_x) = (1 - θ) * (2β_x - 1) + θ * ((1 + c * β_x) - (1 - c * β_x))
    return gp(R(1)) - gp(R(0))
end

# ---------------------------------------------------------------------------
# O4 · Compuerta por enumeración exhaustiva de conteos enteros
#      Cada bloque de espacio vale 1 de peso y exige D hashes.  Un productor con
#      s unidades de espacio y h hashes produce min(s, h÷D) bloques (hashes enteros).
# ---------------------------------------------------------------------------
function umbral_enumera(s_pub, s_priv, h_pub, h_priv, D)
    prod_pub = min(s_pub, div(h_pub, D))
    prod_priv = min(s_priv, div(h_priv, D))
    return prod_priv > prod_pub ? 1 : (prod_priv < prod_pub ? -1 : 0)
end

# Barrido exhaustivo sobre repartos enteros: ¿gana la privada?
function barrido_umbral(; s_max = 12, h_max = 24, D = 4)
    filas = NamedTuple{(:s_pub, :s_priv, :h_priv, :gana), Tuple{Int,Int,Int,Int}}[]
    for s_pub in 0:s_max, s_priv in 0:s_max, h_priv in 0:h_max
        h_pub = h_max   # el honesto despliega todo su hash
        gana = umbral_enumera(s_pub, s_priv, h_pub, h_priv, D)
        push!(filas, (s_pub = s_pub, s_priv = s_priv, h_priv = h_priv, gana = gana))
    end
    return filas
end
