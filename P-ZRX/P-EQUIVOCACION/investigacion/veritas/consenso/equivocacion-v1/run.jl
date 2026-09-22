# =============================================================================
# run.jl — CLI reproducible del enumerador EQUIV-v0.1
#
#   ./veritas/julia.sh --project=. --threads=4 run.jl --modo todo --seed 0x5a5a
#
# Modos: contraste · rejilla · identidad · entorno · todo
# Ningún parámetro de consenso se fija aquí: L, F, I, S_max, k, α son entradas.
# =============================================================================
include("src/Equivocacion.jl")
using .Equivocacion
using Printf, Dates, StableRNGs, InteractiveUtils, LinearAlgebra

const DIR_RES = joinpath(@__DIR__, "resultados")
mkpath(DIR_RES)


# -----------------------------------------------------------------------------
# Contraste referencia ↔ kernel
# -----------------------------------------------------------------------------
function modo_contraste(io)
    println(io, "# Contraste referencia ↔ kernel (EQUIV-v0.1)")
    println(io, "# fecha: ", Dates.now())
    println(io, "# Julia: ", VERSION, "  hilos: ", Threads.nthreads())
    rng = StableRNG(0x5a5a)
    familias = [(nombre = "A n=10 I=4 L=8 jmax=3 k=3",  n = 10, I = 4, L = 8, jmax = 3, k = 3, casos = 500),
                (nombre = "B n=14 I=6 L=12 jmax=4 k=2", n = 14, I = 6, L = 12, jmax = 4, k = 2, casos = 300),
                (nombre = "C n=20 I=5 L=10 jmax=5 k=5", n = 20, I = 5, L = 10, jmax = 5, k = 5, casos = 200),
                (nombre = "D n=16 I=4 L=9 jmax=4 k=1",  n = 16, I = 4, L = 9, jmax = 4, k = 1, casos = 200)]
    for f in familias
        ok, fallo = contraste_aleatorio(rng, f.casos; n = f.n, I_slots = f.I, L = f.L,
                                        jmax = f.jmax, k = f.k)
        @printf(io, "%-34s casos=%-4d ok=%s\n", f.nombre, f.casos, ok)
        ok || println(io, "   FALLO: ", fallo)
    end
    # vectores de regresión explícitos
    reg = []
    push!(reg, ("contraejemplo A2: privada más pesada", configuracion(I = 20, F = 20, Smax = 15,
        delta = 1, x = 5, paso_comun = 5, paso_priv = 4, paso_rama = 4, d = 19)))
    push!(reg, ("control: privada más ligera", configuracion(I = 20, F = 20, Smax = 15,
        delta = 1, x = 5, paso_comun = 4, paso_priv = 5, paso_rama = 4, d = 19)))
    for (nombre, cfg) in reg
        cfg === nothing && continue
        ok, disc = comparar_anclas(cfg.d; I_slots = cfg.I, L = cfg.L, jmax = 5, k = 30)
        @printf(io, "regresión %-40s ok=%s%s\n", nombre, ok, ok ? "" : "  $(disc)")
    end
    return nothing
end

# -----------------------------------------------------------------------------
# Rejilla de la hipótesis: κ de flujo y condición de escape
# -----------------------------------------------------------------------------
function modo_rejilla(io)
    println(io, "# Rejilla de κ de flujo (EQUIV-v0.1)")
    println(io, "I,F,Smax,L,delta,x,paso_comun,paso_priv,paso_rama,d,ventana,flujo_comun,slots_doble,n_priv_V1,n_com_intervalo,ancla_distinta,primera_divergencia,slots_divergentes,kappa_flujo")
    filas = 0
    for cfg in rejilla_hipotesis()
        I, F, L, Smax = cfg.I, cfg.F, cfg.L, cfg.Smax
        delta, x, pc, pp = cfg.delta, cfg.x, cfg.paso_comun, cfg.paso_priv
        d = L - 1
        u = Universo(npiezas = 16, nchunks = 2, npruebas = 1, rango = UInt64(0))
        r = kappa(cfg.d, cfg.A, cfg.B, cfg.P, u; I_slots = I, L = L, F_slots = F,
                  jmax = 6, k = 30, s0 = cfg.d.bloques[cfg.P].slot)
        r.slots == 0 && continue
        gana, ap, apv, npriv, ncom = carrera_V1(cfg)
        div = findfirst(!, [x.flujo_comun for x in r.detalle])
        @printf(io, "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.4f,%d,%d,%d,%s,%s,%d,%.4f\n",
                I, F, Smax, L, delta, x, pc, pp, min(pc, pp), d,
                r.dentro_de_ventana, r.kappa_flujo, r.slots, npriv, ncom, gana,
                div === nothing ? "-" : string(r.detalle[div].slot),
                r.slots_divergente, r.kappa_flujo)
        filas += 1
    end
    @printf(io, "# filas: %d\n", filas)
    return nothing
end

# -----------------------------------------------------------------------------
# κ por identidad frente a la media de ganadores
# -----------------------------------------------------------------------------
function modo_identidad(io)
    println(io, "# κ por identidad y por régimen (EQUIV-v0.1)")
    println(io, "escenario,m,rango,piezas,chunks,slots,slots_comun,slots_div,oport_comun,oport_div,kappa_comun_spec07,kappa_div_spec07,kappa_comun_idv01,kappa_div_idv01,kappa_comun_candidata,kappa_div_candidata")
    # `misma-parcela` es el discriminador: una sola pieza con varios `chunk`. Toda pareja de
    # soluciones comparte la identidad de IDV-01/CANDIDATA (pieza) y solo C-GD-07 las separa.
    escenarios = [
        ("A2-ganada-delta1", (I = 20, F = 20, Smax = 15, delta = 1, x = 5,
                              paso_comun = 5, paso_priv = 4, paso_rama = 1, d = 19), 32, 4),
        ("control-delta1",   (I = 20, F = 20, Smax = 15, delta = 1, x = 5,
                              paso_comun = 4, paso_priv = 5, paso_rama = 1, d = 19), 32, 4),
        ("A2-ganada-delta4", (I = 20, F = 20, Smax = 15, delta = 4, x = 5,
                              paso_comun = 5, paso_priv = 4, paso_rama = 1, d = 19), 32, 4),
        ("misma-parcela",    (I = 20, F = 20, Smax = 15, delta = 1, x = 5,
                              paso_comun = 4, paso_priv = 5, paso_rama = 1, d = 19), 1, 8),
    ]
    for (nombre, kw, np, nc) in escenarios
        cfg = configuracion(; kw...)
        cfg === nothing && continue
        for m in (0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 4.0)
            rango = rango_para_media(np * nc, m)
            u = Universo(npiezas = np, nchunks = nc, npruebas = 1, rango = rango)
            r = kappa(cfg.d, cfg.A, cfg.B, cfg.P, u; I_slots = cfg.I, L = cfg.L,
                      F_slots = cfg.F, jmax = 6, k = 30, s0 = cfg.d.bloques[cfg.P].slot)
            f(x) = isnan(x) ? "-" : @sprintf("%.3f", x)
            @printf(io, "%s,%.2f,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s,%s,%s\n", nombre, m, rango,
                    np, nc, r.slots, r.slots_comun, r.slots_divergente,
                    r.oport_comun[:spec07], r.oport_divergente[:spec07],
                    f(r.kappa_comun[:spec07]), f(r.kappa_divergente[:spec07]),
                    f(r.kappa_comun[:idv01]), f(r.kappa_divergente[:idv01]),
                    f(r.kappa_comun[:candidata]), f(r.kappa_divergente[:candidata]))
        end
    end
    return nothing
end

# -----------------------------------------------------------------------------
# Entorno
# -----------------------------------------------------------------------------
function modo_entorno(io)
    println(io, "# ENTORNO — EQUIV-v0.1")
    println(io, "fecha: ", Dates.now())
    println(io, "julia: ", VERSION)
    println(io, "cpu: ", Sys.CPU_NAME)
    println(io, "hilos lógicos: ", Sys.CPU_THREADS, "  hilos Julia: ", Threads.nthreads())
    println(io, "hilos interactivos: ", Threads.nthreads(:interactive))
    println(io, "ram GiB: ", round(Sys.total_memory() / 2^30, digits = 1))
    println(io, "so: ", Sys.KERNEL, " ", Sys.ARCH)
    println(io, "blas: ", string(BLAS.get_config()))
    return nothing
end

function main()
    modo = "todo"
    for (i, a) in enumerate(ARGS)
        a == "--modo" && (modo = ARGS[i+1])
    end
    if modo in ("contraste", "todo")
        open(joinpath(DIR_RES, "contraste.txt"), "w") do io
            modo_contraste(io)
        end
        println("contraste → resultados/contraste.txt")
    end
    if modo in ("rejilla", "todo")
        open(joinpath(DIR_RES, "kappa-flujo.csv"), "w") do io
            modo_rejilla(io)
        end
        println("rejilla → resultados/kappa-flujo.csv")
    end
    if modo in ("identidad", "todo")
        open(joinpath(DIR_RES, "kappa-identidad.csv"), "w") do io
            modo_identidad(io)
        end
        println("identidad → resultados/kappa-identidad.csv")
    end
    if modo in ("entorno", "todo")
        open(joinpath(DIR_RES, "ENTORNO.txt"), "w") do io
            modo_entorno(io)
        end
        println("entorno → resultados/ENTORNO.txt")
    end
    return nothing
end

main()
