# =============================================================================
# runtests.jl — P-TASA · tasa-identidad-v1
# Perfil de referencia: 1 hilo, `--check-bounds=yes`, límites activos.
#   JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
#     veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl
# =============================================================================
using Test
using Random123

include("../src/modelo.jl")
include("../src/referencia.jl")
include("../src/rapido.jl")
include("../src/validacion.jl")

const RAIZ = normpath(joinpath(@__DIR__, ".."))

controles = Ref(0)
function control!(c::Bool, msg::String)
    controles[] += 1
    c || error("CONTROL FALLIDO: $msg")
    return c
end

@testset "P-TASA · tasa-identidad-v1" begin

    # ---------------------------------------------------------------- V1..V7
    for (nombre, res) in (
        ("umbral exacto", validar_umbral_exacto()),
        ("variantes de coste", validar_variantes()),
        ("dicotomía", validar_dicotomia()),
        ("Φ Pareto", validar_phi_pareto()),
        ("reclutamiento", validar_reclutamiento()),
        ("MC", validar_mc()),
    )
        @testset "$nombre" begin
            @test res.fallos == 0
            if res.fallos != 0
                for d in res.detalle
                    @info "fallo" d
                end
            end
        end
        controles[] += res.controles
    end

    @testset "macros y tipos prohibidos" begin
        rutas = [joinpath(RAIZ, "src", f) for f in
                 ("modelo.jl", "referencia.jl", "rapido.jl", "validacion.jl")]
        push!(rutas, joinpath(RAIZ, "run.jl"))
        inf = sin_macros_prohibidas(rutas)
        @test isempty(inf)
        isempty(inf) || @info "infracciones" inf
        controles[] += 1
    end

    # ------------------------------------------------ inercia de la tasa (O1)
    @testset "la tasa es inerte sin prueba (κq = 0)" begin
        λ, I, Pwin, Th, c_b = 1.0, 1.0, 1.0, 1.0, 0.0
        Lp = 1.0
        for τ in (0.0, 1e-9, 1e-3, 1.0, 1e6)
            fdet = f_detenida(τ, 0.0, Lp, λ, I, Pwin, Th, c_b)
            control!(fdet == 0.0, "f_det ≠ 0 con κq=0 y τ=$τ")
        end
        # con τ = 0 (y sin coste de bytes) la vía de partir es gratis ⇒ f_det = 0:
        # hacen falta LAS DOS cosas, κq > 0 **y** que la partición cueste.
        fdet = f_detenida(0.0, 0.3, Lp, λ, I, Pwin, Th, c_b)
        control!(fdet == 0.0, "f_det ≠ 0 con τ=0 y sin coste de bytes")
        # y con las dos, el umbral es el mínimo de las dos vías
        fdet = f_detenida(0.2, 0.3, Lp, λ, I, Pwin, Th, c_b)
        control!(isapprox(fdet, 0.2; rtol = 1e-12), "f_det ≠ min(κqLp, τ)/(λIPTh)")
        # monotonía en τ y tope en f_κ
        prev = -Inf
        for τ in (0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 1.0)
            fdet = f_detenida(τ, 0.3, Lp, λ, I, Pwin, Th, c_b)
            control!(fdet ≥ prev, "f_det no crece con τ")
            control!(fdet ≤ 0.3 + 1e-12, "f_det supera el tope de la vía de 1 identidad")
            prev = fdet
        end
        controles[] += 1
    end

    # ------------------------------------ proporcionalidad de τ_min (hallazgo R2)
    @testset "τ_min ∝ tamaño de la granja marginal" begin
        λ, I, Pwin, Th, c_b = 1.0, 1.0, 1.0, 1.0, 0.0
        for f in (1e-8, 1e-5, 1e-3, 0.1, 0.5)
            t1 = tau_minimo_fee(f, λ, I, Pwin, Th, c_b)
            t2 = tau_minimo_fee(2f, λ, I, Pwin, Th, c_b)
            control!(isapprox(t2, 2t1; rtol = 1e-12), "τ_min no es lineal en f*")
            control!(t1 ≥ 0, "τ_min negativo")
        end
        # con coste de bytes el τ_min baja exactamente en c_b·f*
        f = 0.1
        c_b2 = 0.25
        control!(isapprox(tau_minimo_fee(f, λ, I, Pwin, Th, c_b2), f * (1.0 - 0.25);
                          rtol = 1e-12), "τ_min no descuenta c_b")
        controles[] += 1
    end

    # ------------------------------------ equivalencia seguridad ⟺ τ ≥ τ_min
    @testset "Φ(f_det) ≤ 1−2α ⟺ κq ≥ κ_min y τ ≥ τ_min" begin
        d = ParetoTruncado(1e-8, 1.0, 2.2)
        λ, I, Pwin, Th, c_b = 1.0, 1.0, 1.0, 1.0, 0.0
        Lp = 1.0
        for α in (0.25, 0.33, 0.4), κq in (0.0, 0.01, 0.05, 0.2)
            fstar = inversa_Phi(d, 1.0 - 2α)
            τmin = tau_minimo_fee(fstar, λ, I, Pwin, Th, c_b)
            κmin = kappa_minimo(fstar, Lp, λ, I, Pwin, Th)
            for τ in (0.0, τmin / 2, τmin, 2τmin)
                fdet = f_detenida(τ, κq, Lp, λ, I, Pwin, Th, c_b)
                seguro = Phi_espacio(d, min(fdet, d.fmax)) ≤ 1.0 - 2α + 1e-12
                pred = (κq ≥ κmin - 1e-15) && (τ ≥ τmin - 1e-15)
                # κq=0 implica no seguro siempre
                if κq == 0.0
                    control!(!seguro, "κq=0 no debería ser seguro (α=$α, τ=$τ)")
                else
                    control!(seguro == pred || (κq < κmin && !seguro),
                             "equivalencia rota (α=$α κq=$κq τ=$τ)")
                end
            end
        end
        controles[] += 1
    end

    # ------------------- equivalencia exacta: partir ⟺ subaditividad estricta
    @testset "dicotomía: partición ⟺ subaditividad estricta ⟺ carga decreciente" begin
        fr = Rational{BigInt}[1 // 1000, 1 // 100, 1 // 20, 1 // 10, 1 // 4, 1 // 2, 3 // 4]
        continuas = Horario{Rational{BigInt}}[
            Lineal(Rational{BigInt}(1)),
            Fija(Rational{BigInt}(1)),
            FijaLineal(Rational{BigInt}(1), Rational{BigInt}(1) / 10),
        ]
        for h in continuas, f in fr, N in (2, 3, 5, 10)
            f * N ≤ 1 || continue
            parte = particion_mas_cara(h, f, N)
            sub = subaditiva_estricta_en(h, f / N, f - f / N)
            carga = carga_decreciente(h, f, f * N)
            control!(parte == sub, "partición ≠ subaditividad estricta en $h")
            control!(carga == sub, "carga decreciente ≠ subaditividad estricta en $h")
            if h isa Lineal
                control!(!parte && !carga, "la lineal no puede ser ni una ni otra")
            else
                control!(parte && carga, "la cóncava debe ser las dos cosas")
            end
            controles[] += 1
        end
        # El tope rompe la equivalencia: hay tamaños donde acumular es MÁS caro
        # que partir, o donde la carga y la partición discrepan. Es el hallazgo
        # de que el tope acerca la tasa a la variante (a).
        tope = Tope{Rational{BigInt}}(Rational{BigInt}(1), Rational{BigInt}(1) / 16)
        discordancias = 0
        for f in fr, N in (2, 3, 5)
            f * N ≤ 1 || continue
            particion_mas_cara(tope, f, N) != carga_decreciente(tope, f, f * N) &&
                (discordancias += 1)
        end
        control!(discordancias > 0, "el tope debería romper la equivalencia en algún tramo")
        controles[] += 1
    end

    # --------------------------------------- regresividad exacta (hallazgo R3)
    @testset "carga de la tasa ∝ 1/tamaño (regresividad exacta)" begin
        λ, I, Th = 1.0, 1.0, 1.0
        fstar = 2.5e-8
        τmin = tau_minimo_fee(fstar, λ, I, 1.0, Th, 0.0)
        prev = Inf
        for f in (1e-8, 5e-8, 1e-7, 1e-6, 1e-4, 1e-2)
            carga = carga_tasa_fraction(τmin, f, λ, I, Th)
            control!(carga < prev, "la carga no decrece con el tamaño")
            control!(isapprox(carga, fstar / f; rtol = 1e-12), "carga ≠ f*/f")
            prev = carga
        end
        # sin dispersión no hay regresividad y la tasa que funciona es proporcional
        d = granjas_iguales(1000)
        f_igual = Rational{BigInt}(1) / 1000
        fstar_eq = inversa_Phi(d, Rational{BigInt}(1) / 3)
        control!(fstar_eq == f_igual, "con granjas iguales f* ≠ 1/N")
        fi = Fija{Rational{BigInt}}(Rational{BigInt}(1))
        control!(subaditiva_en(fi, f_igual, f_igual), "la tasa fija debe ser subaditiva")
        # Sin dispersión, la tasa que funciona es proporcional al espacio: el
        # cociente τ_min/f es constante (es decir, la variante :A). Es el control
        # de degeneración del teorema de dicotomía.
        u = Rational{BigInt}(1)
        f2 = Rational{BigInt}(2) / 1000
        τ1 = tau_minimo_fee(f_igual, u, u, u, u, Rational{BigInt}(0))
        τ2 = tau_minimo_fee(f2, u, u, u, u, Rational{BigInt}(0))
        control!(τ1 / f_igual == τ2 / f2,
                 "sin dispersión la tasa por byte debería ser constante")
        controles[] += 1
    end

    # ------------------------------------------------- rotación (F3, P-CLAVE F4)
    @testset "rotación: bytes proporcionales, tasa fija" begin
        r = coste_rotacion(0.1, 3600.0, 360.0, 1.0, 1.0)
        control!(isapprox(r.factor_ploteo, 11.0; rtol = 1e-12), "factor de ploteo ≠ 11")
        control!(isapprox(r.coste_bytes, 0.1 * 11.0; rtol = 1e-12), "coste de bytes ≠ β·factor")
        control!(isapprox(r.coste_tasa_por_rotacion, 1.0; rtol = 1e-12),
                 "la tasa por rotación no es fija")
        # la tasa anualizada no depende de β: por eso no cambia la conclusión de P-CLAVE
        rb = coste_rotacion(0.5, 3600.0, 360.0, 1.0, 1.0)
        control!(r.coste_tasa_anualizado == rb.coste_tasa_anualizado,
                 "la tasa anualizada depende de β")
        controles[] += 1
    end

    # --------------------------------------------------- variante en cómputo
    @testset "variante pagada en cómputo" begin
        c = coste_computo_identidad(1.0, 1.0, 5)
        control!(c.trabajo_total == 5.0, "trabajo total ≠ n·W")
        control!(!c.arranque_requiere_moneda, "el cómputo no debería exigir moneda")
        control!(!c.escala_con_espacio, "el cómputo no debería escalar con el espacio")
        controles[] += 1
    end

    # ------------------------------------------------------- kernels y memoria
    @testset "kernels: exactitud, asignaciones y determinismo" begin
        d = ParetoTruncado(1e-8, 1.0, 2.2)
        xs = collect(range(1e-8, 1.0; length = 1000))
        dest = Vector{Float64}(undef, length(xs))
        phi_pareto!(dest, d, xs)
        control!(all(dest .== [Phi_espacio(d, x) for x in xs]), "phi_pareto! ≠ Phi_espacio")
        a = @allocated phi_pareto!(dest, d, xs)
        control!(a == 0, "phi_pareto! asigna $a bytes")
        # determinismo serial ≡ hilos
        r1 = mc_phi(UInt64(0x5a5a), d, 1e-4, 5000, 8; hilos = 1)
        r4 = mc_phi(UInt64(0x5a5a), d, 1e-4, 5000, 8; hilos = 4)
        control!(r1.ratios == r4.ratios, "serial ≠ hilos en el MC")
        controles[] += 1
    end

    # --------------------------------------------------------- barrido de tasa
    @testset "barrido de tasa monótono" begin
        d = ParetoTruncado(1e-8, 1.0, 2.2)
        τs = collect(range(0.0, 1.0; length = 200))
        Lp = 1.0
        fdet, disp = barrido_tasa(τs, d, 1.0, 1.0, 1.0, 1.0, 0.0, 0.1, Lp)
        control!(issorted(fdet), "f_det no monótona en τ")
        control!(issorted(disp; rev = true), "espacio no disuadido no decrece con τ")
        control!(all(0 .≤ disp .≤ 1), "espacio fuera de [0,1]")
        controles[] += 1
    end
end

println("CONTROLES TOTALES: ", controles[])
