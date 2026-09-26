#= SL-2 · modelo.jl
   Tipos, parámetros etiquetados y FÓRMULAS CERRADAS de la calibración del castigo.

   Base: modelo ratificado de DS-3 (`P-ZRX/P-DISUASION/resultados-DS2/MODELO.md`, código en
   `DS3/src/`), con las correcciones de `REVISION-DS3.md` (región de retención
   `ρ_ret·T_v > V/N − c_r − I·M`) y sin castigo correlacionado (`REVISION-DS5.md`).
   Reparto de espacio: empírico de DS-6 (`resultados-DS6/farmers-raw.csv`, convención de densidad
   corregida en `CORRECCION-DS6-A.md`) como caso central; Pareto truncada de DS-3 (H3) como caso
   pesimista.

   Las faltas de definición y su resolución declarada están en `DEFINICIONES-FALTANTES.md`
   (F1..F10). Nada se deriva aquí por primera vez sin citar MODELO o DS-6.
=#

# ───────────────────────────────────────────── hechos reutilizados de DS-3 (`escenarios.tsv`)
const TAU_S = 1.0                     # s/slot (P-COBERTURA, SLOT_DURATION)
const T_AÑO_S = 31_536_000.0          # s/año (365 d), para el ingreso anual (resolución F4)

# ───────────────────────────────────────────────────────────── tipos

"""Retención de recompensas M5: fracción `ρ_ret` retenida `T_v` slots (MODELO §2.3)."""
struct Retencion
    rho::Float64
    Tv::Float64
end

"""Pareto truncada de tamaños de clave (H3, P-CLAVE): densidad `∝ f^{−α}` en `[f_min, 1]`."""
struct Pareto
    f_min::Float64
    alpha::Float64
end

"""Reparto de espacio de la carrera de doble farmeo (MODELO §2.1)."""
struct Reparto
    α::Float64
    βd::Float64
    βx::Float64
    ηh::Float64
    ηa::Float64
end

Reparto(α, βd; βx = 0.0, ηh = 1.0, ηa = 1.0) = Reparto(α, βd, βx, ηh, ηa)

"""Distribución del espacio entre claves: empírica (DS-6) o Pareto truncada (H3)."""
abstract type DistribucionEspacio end

"""Empírica directa de DS-6: tamaños `tib`, ordenados con suma acumulada para consulta O(log n)."""
struct Empirica <: DistribucionEspacio
    tibs::Vector{Float64}         # originales (para bootstrap)
    tibs_ord::Vector{Float64}     # ordenados
    suma_acum::Vector{Float64}    # suma_acum[i] = sum(tibs_ord[1:i]), suma_acum[1] = 0
    denom::Float64
    f_media::Float64
end

"""Pareto truncada `[f_min, 1]` con exponente de DENSIDAD `alpha`."""
struct ParetoDist <: DistribucionEspacio
    f_min::Float64
    alpha::Float64
    f_media::Float64
end

"""Fila cruda de `farmers-raw.csv` (DS-6)."""
struct Granjero
    pagina::Int
    launcher::String
    points::Float64
    tib::Float64
end

"""Escenario completo de SL-2 (todo parámetro que entra en un cálculo)."""
struct Escenario
    dist::DistribucionEspacio
    V::Float64            # valor total del ataque (u.e.), resolución F6
    f_conf::Float64       # fracción confiscada (F1)
    q_g::Float64          # garantía mínima por identidad (M1)
    c_r::Float64          # recargo fijo por incidente
    I::Float64            # emisión por bloque (u.e.)
    λ::Float64            # bloques/slot
    κ::Float64            # fracción de doble farmeo que deja evidencia
    q_ev::Float64         # probabilidad de que la evidencia llegue (antes `q_gana`)
    eps_saldo::Float64    # umbral de saldo cero (u.e.)
    R_slots::Float64      # retardo de retiro (F3)
    F_slots::Float64      # ventana de finalidad
    P_obj::Float64        # probabilidad de éxito objetivo del ataque (F8)
    eps_h::Float64        # tasa anual de doble firma accidental del honesto
    f_h::Float64          # fracción de la clave honesta representativa
    frac_max::Float64     # tope de pérdida del honesto como fracción de su ingreso
    via_perdida::Symbol   # :P1 (fiel DS-3) o :P2 (corrección de unidades, F5)
end

# ─────────────────────────────────── frontera de deriva (MODELO §2.1)

"`α* = (η_h − η_a β_d − (η_h+η_a) β_x)/(η_h+η_a)`. Identidad aritmética exacta."
@inline alpha_estrella(βd, βx = 0.0, ηh = 1.0, ηa = 1.0) =
    (ηh - ηa * βd - (ηh + ηa) * βx) / (ηh + ηa)

"`β_d` que cruza `g = 0` con `β_x = 0`: `β_d > η_h(1−α)/η_a − α`; con `η=1`, `1−2α`."
@inline beta_cruce(α, ηh = 1.0, ηa = 1.0) = ηh * (1 - α) / ηa - α

"Trabajo de la rama pública por unidad de tiempo (MODELO §2.2)."
@inline mu_publica(r::Reparto) = r.ηh * (1 - r.α - r.βx)

"Trabajo de la rama privada por unidad de tiempo (MODELO §2.2)."
@inline mu_privada(r::Reparto) = r.ηa * (r.α + r.βd + r.βx)

"`g = μ_a − μ_p`: deriva (privada menos pública). `g > 0` ⇒ la privada gana la media."
@inline deriva(r::Reparto) = mu_privada(r) - mu_publica(r)

"Tasa del ADVERSARIO por paso, `p = μ_a/(μ_a+μ_p)` (MODELO §2.2, condicionado a H-PUENTE)."
@inline function p_de_alpha(r::Reparto)
    ra = mu_privada(r)
    rp = mu_publica(r)
    return ra + rp <= 0 ? 1.0 : ra / (ra + rp)
end

"`d = (μ_p − μ_a)·F`, déficit inicial (MODELO §2.2)."
@inline deficit_esperado(r::Reparto, F) = (mu_publica(r) - mu_privada(r)) * F

"Déficit entero que consume la DP. Convención declarada: `round(Int, d)` (DS-3 F3)."
@inline deficit_entero(r::Reparto, F) = max(0, round(Int, deficit_esperado(r, F)))

"Forma cerrada de horizonte largo `(q/p)^(d+1)`; cota superior, no se usa para `F` finito."
@inline eventual(q, d) = q < 1 - q ? (q / (1 - q))^(d + 1) : 1.0

"`log10` de la forma cerrada, para el régimen que subdesborda `Float64`."
@inline eventual_log10(q, d) = (d + 1) * log10(q / (1 - q))

# ─────────────────────────────── retención por clave (MODELO §2.3, §2.4)

"`θ = λ f T_v`: bloques esperados dentro de la ventana de retención."
@inline theta(λ, f, ret::Retencion) = λ * f * ret.Tv

"`E[B] = ρ_ret I θ/2` (liberación lineal)."
@inline balance_medio(λ, f, ret::Retencion, I) = ret.rho * I * theta(λ, f, ret) / 2

"`Var[B] = ρ_ret² I² θ/3` (liberación lineal)."
@inline balance_var(λ, f, ret::Retencion, I) = ret.rho^2 * I^2 * theta(λ, f, ret) / 3

"`P(B = 0) = e^{−θ}`, exacta en el modelo (Poisson)."
@inline p_saldo_cero(λ, f, ret::Retencion) = exp(-theta(λ, f, ret))

# ─────────────────────────── distribución del espacio / B(ε) (MODELO §2.4, DS-6)

"""
    masa_prob(dist::Pareto, x; F_max)

`E[min(f,x)] / E[f]` para la Pareto truncada en `[f_min, F_max]` (P-CLAVE `masa_prob`).
Con `F_max = 1` es la definición de H3 («Pareto truncada [10⁻⁸,1]»); es la única forma definida
para `alpha <= 2`, el régimen que midió DS-6 (resolución F10).
"""
function masa_prob(dist::Pareto, x; F_max = Inf)
    x <= dist.f_min && return 0.0
    b = 2 - dist.alpha
    if isinf(F_max)
        dist.alpha <= 2 && throw(ArgumentError("Pareto no truncada con α ≤ 2: E[f] diverge"))
        return 1 - (dist.f_min / x)^(dist.alpha - 2)
    else
        x = min(x, F_max)
        F_max > dist.f_min || throw(ArgumentError("F_max debe superar f_min"))
        return (x^b - dist.f_min^b) / (F_max^b - dist.f_min^b)
    end
end

"""
    B_par(dist::Pareto, x) -> Float64

Fracción de ESPACIO en claves con `f < x` para la Pareto de H3 (no `E[min]/E[f]`, que es otra
magnitud). Para `alpha > 2` se usa la rama no truncada de DS-3 (`F_max=Inf`, reproduce su
checkpoint `0.675466`); para `alpha <= 2` (régimen que midió DS-6) la truncada `[f_min,1]`, la
única definida (resolución F10).
"""
B_par(dist::Pareto, x) = dist.alpha > 2 ? masa_prob(dist, x; F_max = Inf) :
                                          masa_prob(dist, x; F_max = 1.0)
B_par(d::ParetoDist, x) = B_par(Pareto(d.f_min, d.alpha), x)

"""
    B_empirico(dist::Empirica, x) -> Float64

Fracción del espacio del denominador que está en claves con `f_i < x` (cálculo directo, sin
ajustar ley; DS-6 A.3). `x` es una fracción del denominador. Fuera del soporte observado vale 0
(resolución F9).
"""
function B_empirico(d::Empirica, x)
    x <= 0 && return 0.0
    x >= 1 && return 1.0
    umbral = x * d.denom
    k = searchsortedfirst(d.tibs_ord, umbral) - 1   # nº de tibs estrictamente < umbral
    return k == 0 ? 0.0 : d.suma_acum[k + 1] / d.denom
end

"Umbral `x = ε/(f·λ·T_v^eff)` con `T_v^eff = T_v + R_slots` (resoluciones F3, F7)."
@inline funcion_umbral(eps_saldo, f_conf, λ, Tv, R_slots) =
    eps_saldo / (f_conf * λ * (Tv + R_slots))

"`B` del escenario en `T_v` (empírica o Pareto)."
B_de(d::Empirica, x) = B_empirico(d, x)
B_de(d::ParetoDist, x) = B_par(d, x)

# ─────────────────────────────── pérdida y condiciones (MODELO §2.5 + F1/F5)

"""
    perdida_castigo(esc; ρ_ret, Tv) -> Float64

Pérdida expuesta por reclutado (garantía + saldo retenido + recargo) según la vía declarada:
  · `:P1` (fiel a DS-3): `f·(ρ_ret·I·T_v^eff + q_g) + c_r`;
  · `:P2` (corrección de unidades F5): saldo retenido por clave `ρ_ret·I·λ·f_media·T_v^eff/2`.
"""
function perdida_castigo(esc::Escenario; ρ_ret, Tv)
    Tveff = Tv + esc.R_slots
    retenido = esc.via_perdida === :P2 ?
        ρ_ret * esc.I * esc.λ * f_media_de(esc.dist) * Tveff / 2 :
        ρ_ret * esc.I * Tveff
    return esc.f_conf * (retenido + esc.q_g) + esc.c_r
end

"Fracción de espacio por clave media usada en la vía P2 y en `N_paid`."
f_media_de(d::Empirica) = d.f_media
f_media_de(d::ParetoDist) = d.f_media

"""
    coste_disuasion(esc, β_d; ρ_ret, Tv) -> (coste, N_paid, L, B)

Coste total que el atacante debe pagar para reclutar `β_d`, contando que las claves sin saldo
(`B(ε)`) se reclutan gratis y solo las pagadas cobran soborno esperado `κ·q_ev·L`:
`N_paid = max(0, β_d − B)/f_media`. Con `B = 0` reproduce `N_recl·κq·L` de DS-3 (resolución F6).
"""
function coste_disuasion(esc::Escenario, βd; ρ_ret, Tv)
    x = funcion_umbral(esc.eps_saldo, esc.f_conf, esc.λ, Tv, esc.R_slots)
    B = B_de(esc.dist, x)
    N_paid = max(0.0, βd - B) / f_media_de(esc.dist)
    L = perdida_castigo(esc; ρ_ret = ρ_ret, Tv = Tv)
    return (coste = N_paid * esc.κ * esc.q_ev * L, N_paid = N_paid, L = L, B = B)
end

"¿Disuade? coste total > valor total `V` (resolución F6)."
@inline condicion_disuasion(esc::Escenario, βd; ρ_ret, Tv) =
    coste_disuasion(esc, βd; ρ_ret = ρ_ret, Tv = Tv).coste > esc.V

"Ingreso anual de una clave de fracción `f_h` (resolución F4)."
@inline ingreso_anual(esc::Escenario; f_h) = esc.λ * f_h * esc.I * T_AÑO_S

"Tope de pérdida anual admitida para el honesto (fracción `frac_max` de su ingreso)."
@inline max_perdida_honesta(esc::Escenario; f_h) = esc.frac_max * ingreso_anual(esc; f_h = f_h)

"""
    condicion_honesta(esc; ρ_ret, Tv) -> (ok, perdida_anual, cociente)

Pérdida anual esperada del honesto `ε_h·L` frente al tope `frac_max·ingreso_anual` (resolución F4).
"""
function condicion_honesta(esc::Escenario; ρ_ret, Tv, f_h)
    L = perdida_castigo(esc; ρ_ret = ρ_ret, Tv = Tv)
    perdida = esc.eps_h * L
    tope = max_perdida_honesta(esc; f_h = f_h)
    return (ok = perdida <= tope, perdida_anual = perdida, cociente = tope > 0 ? perdida / tope : Inf)
end

# ─────────────────────────────── región en `T_v` para `ρ_ret` fijo (fórmulas cerradas)

"""
    region_tv(dist, β_d, esc; ρ_ret) -> NamedTuple

Región `(ρ_ret, T_v)` con fórmulas cerradas, en `T_v` para `ρ_ret` fijo:
  · cota inferior `Tv_min`: la cierra la disuasión `A` (o la viabilidad `T_v > F`);
  · cota superior `Tv_max`: la cierra la honestidad `B` (`ε_h·L ≤ frac_max·ingreso`);
  · `existe` y el motivo cuando se vacía (``A``, ``honesto`` o ``κq_ev=0``).
Monótona: `N_paid` y `L` crecen con `T_v`, así que si `A` falla en `Tv_max` falla en todo el
intervalo.
"""
function region_tv(esc::Escenario, βd; ρ_ret)
    F = esc.F_slots
    L(Tv) = perdida_castigo(esc; ρ_ret = ρ_ret, Tv = Tv)
    # cota superior por la honestidad: L(Tv) ≤ Cmax
    Cmax = max_perdida_honesta(esc; f_h = esc.f_h) / esc.eps_h
    retenido_unit = esc.via_perdida === :P2 ?
        ρ_ret * esc.I * esc.λ * f_media_de(esc.dist) / 2 : ρ_ret * esc.I
    pendiente = esc.f_conf * retenido_unit
    intercepto = esc.f_conf * (retenido_unit * esc.R_slots + esc.q_g) + esc.c_r
    Tv_max = pendiente > 0 ? (Cmax - intercepto) / pendiente : Inf

    # cota inferior por la disuasión A: coste(Tv) > V (monótono creciente en Tv)
    A_ok(Tv) = esc.κ * esc.q_ev > 0 && condicion_disuasion(esc, βd; ρ_ret = ρ_ret, Tv = Tv)

    if esc.κ * esc.q_ev <= 0
        return (existe = false, Tv_min = Inf, Tv_max = Tv_max, borde_inf = "κq_ev=0",
                borde_sup = "—", B_min = NaN, N_paid_min = NaN, L_min = NaN,
                motivo = "κq_ev = 0: sin evidencia no hay soborno ni disuasión")
    end
    if Tv_max <= F
        return (existe = false, Tv_min = Inf, Tv_max = Tv_max, borde_inf = "—",
                borde_sup = "honesto", B_min = NaN, N_paid_min = NaN, L_min = NaN,
                motivo = "la honestidad cierra antes de T_v > F (Tv_max ≤ F)")
    end
    if !A_ok(Tv_max)
        c = coste_disuasion(esc, βd; ρ_ret = ρ_ret, Tv = Tv_max)
        return (existe = false, Tv_min = Inf, Tv_max = Tv_max, borde_inf = "A", borde_sup = "honesto",
                B_min = c.B, N_paid_min = c.N_paid, L_min = c.L,
                motivo = "A no disuade ni en Tv_max (grieta o coste insuficiente)")
    end
    if A_ok(F)
        Tv_min = F
        borde_inf = "F (viabilidad T_v>F)"
    else
        lo, hi = F, min(Tv_max, 1e12)
        for _ in 1:200
            med = (lo + hi) / 2
            if A_ok(med)
                hi = med
            else
                lo = med
            end
            hi - lo <= 1e-6 * max(1.0, hi) && break
        end
        Tv_min = hi
        borde_inf = "A (disuasión)"
    end
    cmin = coste_disuasion(esc, βd; ρ_ret = ρ_ret, Tv = Tv_min)
    return (existe = Tv_min < Tv_max, Tv_min = Tv_min, Tv_max = Tv_max, borde_inf = borde_inf,
            borde_sup = "honesto", B_min = cmin.B, N_paid_min = cmin.N_paid, L_min = cmin.L,
            motivo = Tv_min < Tv_max ? "región no vacía" : "Tv_min ≥ Tv_max")
end

# ───────────────────────────────────────────── lectura de datos de DS-6

"Carga `farmers-raw.csv` (página, launcher_id, points, tib)."
function cargar_farmers(ruta::AbstractString)
    filas = Granjero[]
    open(ruta, "r") do io
        primera = true
        for linea in eachline(io)
            if primera; primera = false; continue; end
            isempty(strip(linea)) && continue
            campos = split(linea, ',')
            length(campos) == 4 || error("línea mal formada en $ruta: $linea")
            push!(filas, Granjero(parse(Int, campos[1]), String(campos[2]),
                                  parse(Float64, campos[3]), parse(Float64, campos[4])))
        end
    end
    return filas
end

"Deduplica por `launcher_id` y descarta `points = 0` (mismos criterios que DS-6)."
function limpiar_farmers(filas::Vector{Granjero})
    vistos = Set{String}()
    salida = Granjero[]
    for f in filas
        f.points <= 0 && continue
        f.launcher in vistos && continue
        push!(vistos, f.launcher)
        push!(salida, f)
    end
    return salida
end

"Construye la distribución empírica (denominador = suma de la muestra)."
function empirica(tibs::Vector{Float64})
    denom = sum(tibs)
    ord = sort(tibs)
    n = length(ord)
    acum = Vector{Float64}(undef, n + 1)
    acum[1] = 0.0
    @inbounds for i in 1:n
        acum[i + 1] = acum[i] + ord[i]
    end
    return Empirica(tibs, ord, acum, denom, 1.0 / n)
end

# ──────────────────────── RNG no consecutivo (misma mezcla que P-CLAVE/DS-3, declarada)

"Mezcla SplitMix64 de dos enteros de 64 bits (P-CLAVE `rapido.jl`)."
@inline function hash64(a::UInt64, b::UInt64)
    z = a + 0x9E3779B97F4A7C15 * b + 0x9E3779B97F4A7C15
    z = (z ⊻ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ⊻ (z >> 27)) * 0x94D049BB133111EB
    return z ⊻ (z >> 31)
end

"RNG independiente por réplica: `StableRNG(hash64(semilla ⊻ etiqueta, id))` (no consecutivo)."
@inline rng_replica(semilla::UInt64, id::Integer, etiqueta::UInt64 = UInt64(0)) =
    StableRNG(hash64(semilla ⊻ etiqueta, UInt64(id)))
