# ─────────────────────────────────────────────────────────────────────────────
# rapido.jl — kernel Float64 con histograma por bins y barrido paralelo.
#
# Representación: una `Tray{T}` por réplica (puntos de ruptura, preasignada) y un
# histograma de `V` con el reparto exacto del tiempo dentro de cada tramo lineal.
# RNG por réplica (`StableRNG(semilla + id)`) y reducción en orden de id.
# ─────────────────────────────────────────────────────────────────────────────

"Sortea `off_j` (geometric truncada, λ = 0,2) y `propia_j` (Bernoulli α) de una réplica."
function sortear!(rng::AbstractRNG, off::Vector{T}, propia::Vector{Bool}, cfg::Cfg{T},
                  J::Int, alpha::T; modo::Symbol = :geom, lambda::T = T(0.2)) where {T<:Real}
    for j in 1:J
        if modo === :cero
            off[j] = zero(T)
        elseif modo === :unif
            off[j] = T(rand(rng)) * cfg.S_max
        elseif modo === :geom
            e = -log(rand(rng)) / lambda
            off[j] = e < cfg.S_max ? T(e) : cfg.S_max
        else
            error("modo de offset desconocido: $modo")
        end
        propia[j] = rand(rng) < alpha
    end
    return nothing
end

"Buffers de una réplica: trayectoria + histograma."
mutable struct Bufs{T<:Real}
    tr::Tray{T}
    hist::Vector{Float64}
    bajo::Float64
    sobre::Float64
    t_total::Float64
end

function Bufs{T}(J::Int, nb::Int) where {T<:Real}
    return Bufs{T}(Tray{T}(J), zeros(Float64, nb), 0.0, 0.0, 0.0)
end

function reiniciar!(b::Bufs)
    fill!(b.hist, 0.0)
    b.bajo = 0.0; b.sobre = 0.0; b.t_total = 0.0
    return b
end

"Reparte el tiempo `dt` de un tramo lineal de `V` entre bins (exacto en el tramo)."
@inline function llenar_rampa!(b::Bufs{T}, v0::T, v1::T, dt::T, bin::T, v_lo::T) where {T<:Real}
    hist = b.hist
    nb = length(hist)
    if v0 == v1
        k = floor(Int, (v0 - v_lo) / bin)
        if k < 0
            b.bajo += Float64(dt)
        elseif k >= nb
            b.sobre += Float64(dt)
        else
            @inbounds hist[k+1] += Float64(dt)
        end
        return nothing
    end
    lo = v0 < v1 ? v0 : v1
    hi = v0 < v1 ? v1 : v0
    dv = hi - lo
    k0 = floor(Int, (lo - v_lo) / bin)
    k1 = floor(Int, (hi - v_lo) / bin)
    @inbounds for k in k0:k1
        a = lo > v_lo + T(k) * bin ? lo : v_lo + T(k) * bin
        bb = hi < v_lo + T(k + 1) * bin ? hi : v_lo + T(k + 1) * bin
        w = bb - a
        if w > zero(T)
            tt = Float64(dt * w / dv)
            if k < 0
                b.bajo += tt
            elseif k >= nb
                b.sobre += tt
            else
                hist[k+1] += tt
            end
        end
    end
    return nothing
end

"""
Acumula el histograma temporal de `V` en `[t_ini, t_fin]`. Devuelve `(vmax, vmin)`.
Recorre la lista fusionada de puntos de ruptura de las dos fronteras.
"""
function acumular_hist!(b::Bufs{T}, t_ini::T, t_fin::T, bin::T, v_lo::T,
                        con_hist::Bool = true) where {T<:Real}
    tr = b.tr
    tA = tr.tA; pA = tr.pA; tH = tr.tH; pH = tr.pH; evt = tr.evt
    nA = tr.nA; nH = tr.nH
    nE = 0; ia = 1; ih = 1
    @inbounds while ia <= nA && ih <= nH
        if tA[ia] <= tH[ih]
            nE += 1; evt[nE] = tA[ia]; ia += 1
        else
            nE += 1; evt[nE] = tH[ih]; ih += 1
        end
    end
    @inbounds while ia <= nA
        nE += 1; evt[nE] = tA[ia]; ia += 1
    end
    @inbounds while ih <= nH
        nE += 1; evt[nE] = tH[ih]; ih += 1
    end
    vmax = zero(T); vmin = zero(T); visto = false
    pa = 1; ph = 1
    tprev = evt[1]; vprev = pA[1] - pH[1]
    @inbounds for e in 2:nE
        t = evt[e]
        ultimo = false
        if t > t_fin
            t = t_fin; ultimo = true
        end
        while pa < nA && tA[pa+1] <= t
            pa += 1
        end
        while ph < nH && tH[ph+1] <= t
            ph += 1
        end
        va = pa < nA ? pA[pa] + (pA[pa+1] - pA[pa]) * (t - tA[pa]) / (tA[pa+1] - tA[pa]) : pA[pa]
        vh = ph < nH ? pH[ph] + (pH[ph+1] - pH[ph]) * (t - tH[ph]) / (tH[ph+1] - tH[ph]) :
             pH[nH] + (t - tH[nH]) * (pH[nH] - pH[nH-1]) / (tH[nH] - tH[nH-1])
        v = va - vh
        if t >= t_ini
            if !visto
                vmax = v; vmin = v; visto = true
            end
            v > vmax && (vmax = v)
            v < vmin && (vmin = v)
            if tprev < t_ini
                f = (t_ini - tprev) / (t - tprev)
                vprev = vprev + f * (v - vprev)
                tprev = t_ini
            end
            dt = t - tprev
            if dt > zero(T)
                con_hist && llenar_rampa!(b, vprev, v, dt, bin, v_lo)
                b.t_total += Float64(dt)
            end
        end
        tprev = t; vprev = v
        ultimo && break
    end
    return (vmax, vmin)
end

"Una réplica completa: construye, mide extremos exactos y llena el histograma."
function simular_replica!(b::Bufs{T}, cfg::Cfg{T}, off::AbstractVector{T}, propia::AbstractVector{Bool},
                          rho::T, J::Int, bin::T, v_lo::T, con_hist::Bool = true;
                          j_ini::Int = 0) where {T<:Real}
    nst = construir!(b.tr, cfg, off, propia, rho, J)
    t_ini = T(j_ini) * cfg.I
    t_fin = fin_horizonte(b.tr)
    vmax, vmin, vmed, vfin = extremos!(b.tr, t_ini, t_fin)
    b2max, b2min = acumular_hist!(b, t_ini, t_fin, bin, v_lo, con_hist)
    return (vmax = vmax, vmin = vmin, vmed = vmed, vfin = vfin, n_stall = nst,
            vmax_hist = b2max, vmin_hist = b2min)
end

"Resultado de un barrido `réplicas × ρ`."
struct ResultadoBarrido
    rho::Vector{Float64}
    vmax::Matrix{Float64}
    vmin::Matrix{Float64}
    vmed::Matrix{Float64}
    n_stall::Int
    hist::Matrix{Float64}     # [bin, ρ]
    bajo::Vector{Float64}
    sobre::Vector{Float64}
    t_total::Vector{Float64}
    bin::Float64
    v_lo::Float64
end

"""
Barrido sobre una rejilla de `ρ` con `R` réplicas y semilla maestra.
Números aleatorios **comunes a toda la rejilla** (mismo `off`/`propia` por réplica)
para localizar umbrales. Reducción en orden de id de réplica.
"""
function barrido(cfg::Cfg{T}, rho_grid::AbstractVector{T}, J::Int, R::Int, seed::UInt64,
                 nb::Int, bin::T, v_lo::T, alpha::T;
                 modo_off::Symbol = :geom, lambda::T = T(0.2), nthreads::Int = 1,
                 con_hist::Bool = true) where {T<:Real}
    (nthreads == 1 || nthreads == Threads.nthreads(:default)) ||
        throw(ArgumentError("nthreads debe ser 1 o igual a Threads.nthreads(:default); iniciar otro proceso Julia para medir otro número"))
    nrho = length(rho_grid)
    vmax = zeros(Float64, R, nrho); vmin = zeros(Float64, R, nrho); vmed = zeros(Float64, R, nrho)
    # Acumuladores POR RÉPLICA: ninguna tarea escribe la celda de otra (sin carrera).
    hist_r = zeros(Float64, nb, nrho, R)
    bajo_r = zeros(Float64, nrho, R); sobre_r = zeros(Float64, nrho, R); ttot_r = zeros(Float64, nrho, R)
    stalls = zeros(Int, R, nrho)

    tareas = collect(1:(R * nrho))
    @inbounds if nthreads > 1
        Threads.@threads for idx in tareas
            _una!(vmax, vmin, vmed, hist_r, bajo_r, sobre_r, ttot_r, stalls,
                  cfg, rho_grid, J, R, seed, nb, bin, v_lo, alpha, modo_off, lambda, con_hist, idx)
        end
    else
        for idx in tareas
            _una!(vmax, vmin, vmed, hist_r, bajo_r, sobre_r, ttot_r, stalls,
                  cfg, rho_grid, J, R, seed, nb, bin, v_lo, alpha, modo_off, lambda, con_hist, idx)
        end
    end
    # Reducción determinista, en orden de id de réplica, después del bucle paralelo.
    hist = zeros(Float64, nb, nrho); bajo = zeros(Float64, nrho)
    sobre = zeros(Float64, nrho); ttot = zeros(Float64, nrho)
    for irho in 1:nrho, r in 1:R
        @inbounds for k in 1:nb
            hist[k, irho] += hist_r[k, irho, r]
        end
        bajo[irho] += bajo_r[irho, r]; sobre[irho] += sobre_r[irho, r]; ttot[irho] += ttot_r[irho, r]
    end
    return ResultadoBarrido(collect(Float64, rho_grid), vmax, vmin, vmed, sum(stalls),
                            hist, bajo, sobre, ttot, Float64(bin), Float64(v_lo))
end

function _una!(vmax, vmin, vmed, hist_r, bajo_r, sobre_r, ttot_r, stalls,
               cfg::Cfg{T}, rho_grid, J, R, seed, nb, bin, v_lo, alpha, modo_off, lambda,
               con_hist, idx) where {T<:Real}
    r = (idx - 1) ÷ length(rho_grid) + 1
    irho = (idx - 1) % length(rho_grid) + 1
    rng = StableRNG(seed + UInt64(r))
    off = Vector{T}(undef, J + 1)
    propia = Vector{Bool}(undef, J + 1)
    sortear!(rng, off, propia, cfg, J, alpha; modo = modo_off, lambda = lambda)
    b = Bufs{T}(J, nb)
    res = simular_replica!(b, cfg, off, propia, T(rho_grid[irho]), J, bin, v_lo, con_hist)
    vmax[r, irho] = res.vmax; vmin[r, irho] = res.vmin; vmed[r, irho] = res.vmed
    stalls[r, irho] = res.n_stall
    @inbounds for k in 1:nb
        hist_r[k, irho, r] = b.hist[k]      # celda exclusiva de esta réplica
    end
    bajo_r[irho, r] = b.bajo; sobre_r[irho, r] = b.sobre; ttot_r[irho, r] = b.t_total
    return nothing
end

"Extremo inferior del bin que contiene el cuantil `q` (cota inferior declarada)."
function cuantil_hist(h::AbstractVector{Float64}, bajo::Float64, sobre::Float64,
                      bin::Float64, v_lo::Float64, q::Float64)
    total = sum(h) + bajo + sobre
    total <= 0 && return NaN
    obj = q * total
    acc = bajo
    if acc >= obj
        return v_lo - 1.0
    end
    for k in eachindex(h)
        acc += h[k]
        if acc >= obj
            return v_lo + (k - 1) * bin
        end
    end
    return v_lo + length(h) * bin
end

"Fracción del tiempo con `V ≥ umbral` (el bin que lo contiene se reparte linealmente)."
function fraccion_excedencia(h::AbstractVector{Float64}, bajo::Float64, sobre::Float64,
                             bin::Float64, v_lo::Float64, umbral::Float64)
    total = sum(h) + bajo + sobre
    total <= 0 && return NaN
    acc = 0.0
    if umbral <= v_lo
        return 1.0
    end
    ku = floor(Int, (umbral - v_lo) / bin)
    for k in 0:(ku - 1)
        k >= 0 && k < length(h) && (acc += h[k+1])
    end
    if ku >= 0 && ku < length(h)
        f = (umbral - (v_lo + ku * bin)) / bin      # fracción del bin por debajo del umbral
        acc += (1 - f) * h[ku+1]
    end
    return acc / total
end

"Media, cuantiles y máximo de una fila `ρ` del barrido (masa de tiempo agregada)."
function resumen_rho(res::ResultadoBarrido, i::Int; cuantiles = (0.5, 0.9, 0.99, 0.999))
    h = @view res.hist[:, i]
    return (vmax = maximum(@view res.vmax[:, i]),
            vmin = minimum(@view res.vmin[:, i]),
            vmed = sum(@view res.vmed[:, i]) / size(res.vmax, 1),
            cuantiles = [cuantil_hist(h, res.bajo[i], res.sobre[i], res.bin, res.v_lo, q) for q in cuantiles])
end
