#!/usr/bin/env julia
# PPP-v0.1 — CLI reproducible. Ver METODO.md para los comandos publicados.
using Pkg
using Printf
using Dates

const DIR = @__DIR__
const RES = joinpath(DIR, "resultados")

include(joinpath(DIR, "src", "PodaPost.jl"))
using .PodaPost

# ---------------------------------------------------------------------------
# Cabecera de entorno (LINEO §1: hash Git, versión, hardware, hilos, comando, semilla).
# ---------------------------------------------------------------------------

function entorno(comando::String, semilla::Union{Nothing,UInt64}=nothing)
    io = IOBuffer()
    println(io, "== ENTORNO PPP-v0.1 ==")
    git = try
        strip(read(`git -C $(dirname(DIR)) rev-parse HEAD`, String))
    catch
        "no disponible"
    end
    println(io, "git_HEAD: ", git)
    println(io, "fecha: ", Dates.now())
    println(io, "julia: ", VERSION)
    println(io, "cpu: ", Sys.CPU_NAME)
    println(io, "hilos_julia: ", Threads.nthreads(:default), " default / ",
            Threads.nthreads(:interactive), " interactive")
    println(io, "comando: ", comando)
    println(io, "semilla: ", semilla === nothing ? "(determinista)" : string(semilla))
    print(io, "pkg: ")
    try
        Pkg.status(io=io)
    catch
        println(io, "no disponible")
    end
    return String(take!(io))
end

fmt(x) = @sprintf("%.3e", Float64(x))

# ---------------------------------------------------------------------------
# Modos.
# ---------------------------------------------------------------------------

function modo_niveles(; SR::UInt64=UInt64(1) << 40, C::Int=1, Lmax::Int=12)
    io = IOBuffer()
    println(io, "== Niveles exactos: P(nivel L | válida) vs hipótesis 2^-(L-1) ==")
    println(io, "SR = ", SR, "   C (sorteos/bloque) = ", C, "   M = 2^63")
    println(io, "aceptación por sorteo = (SR÷2+1)/2^63 = ",
            @sprintf("%.6e", (Float64(SR >> 1) + 1) / 2.0^63))
    t = tabla_niveles(SR, C; Lmax=Lmax)
    @printf(io, "%3s %22s %14s %14s %12s\n", "L", "umbral=SR>>L", "exacta", "hipótesis", "exacta/hip")
    for i in eachindex(t.L)
        @printf(io, "%3d %22d %14s %14s %12.6f\n", t.L[i], t.umbral[i],
                fmt(t.exacta[i]), fmt(t.hipotesis[i]), t.ratio[i])
    end
    println(io, "\nLa hipótesis es el límite SR/2^63 → 0. El cociente es ≥ 1 (concavidad del")
    println(io, "mínimo de C uniformes) y crece con C y con SR/2^63; se cuantifica en --multiples.")
    return String(take!(io))
end

function modo_multiples(; Ls=(2, 4, 8), Cs=(1, 2, 4, 8, 16, 32, 64),
                        SRs=(UInt64(1) << 30, UInt64(1) << 45, UInt64(1) << 60,
                             typemax(UInt64) >> 1))
    io = IOBuffer()
    println(io, "== Punto 3 del §3: múltiples sorteos por s-bucket. Razón exacta/hipótesis ==")
    println(io, "razón = F(SR÷2^L)/F(SR÷2) / 2^-(L-1), F(x)=1-((M-1-x)/M)^C, M=2^63")
    for SR in SRs, L in Ls
        @printf(io, "SR=%20d  L=%d  acept/dibujo=%.3e |", SR, L,
                (Float64(SR >> 1) + 1) / 2.0^63)
        for C in Cs
            @printf(io, "  C=%d: %.6f", C, Float64(ratio_exacto(L, SR, C)))
        end
        println(io)
    end
    println(io, "\nLectura: la multiplicidad de chunks NO da ventaja injusta —la razón es la")
    println(io, "misma para todos—, pero infla la probabilidad de nivel alto respecto de la")
    println(io, "hipótesis. La desviación es despreciable si SR ≪ 2^63 y apreciable si no.")
    return String(take!(io))
end

function modo_sranclaje(; L::Int=4, SR0::UInt64=UInt64(1) << 45, C::Int=1)
    io = IOBuffer()
    println(io, "== Puntos 1-2 del §3: SR variable. Umbral de referencia SR0/2^L vs SR del bloque ==")
    println(io, "SR0 = ", SR0, "   L = ", L, "   C = ", C,
            "   factor = F(SR0÷2^L)/F(SRb÷2)")
    @printf(io, "%10s %20s %14s %14s\n", "rho=SRb/SR0", "SRb", "P(L|válida)", "P/hipótesis")
    for rho in (0.25, 0.5, 1.0, 2.0, 4.0, 16.0)
        SRb = UInt64(round(Float64(SR0) * rho))
        SRb == 0 && continue
        p = factor_anclaje(L, SRb, SR0, C)
        @printf(io, "%10.2f %20d %14s %14.6f\n", rho, SRb, fmt(p),
                p / hipotesis_nivel(L))
    end
    println(io, "\nLectura: con umbral de referencia fijo, la tasa de nivel escala ≈ SR0/SRb.")
    println(io, "Con umbral = SR del bloque, la razón es escala-invariante (--niveles), pero el")
    println(io, "SR es endógeno (R-FIN-13′) y una rama privada controla su propio SR. Ninguna")
    println(io, "de las dos anclas es a la vez estable y no manipulable: el ancla estable")
    println(io, "(referencia) es manipulable por la razón, y el ancla no manipulada (SR del")
    println(io, "bloque) hereda el SR que la propia rama eligió.")
    return String(take!(io))
end

function modo_cabeceras(; bps::Real=1.0)
    io = IOBuffer()
    println(io, "== Crecimiento sin poda (A″: 1 bloque/s, 1 s/slot, §7.5) ==")
    for bytes in (589.0, 748.0, 1037.0)
        t = tabla_crecimiento(bps=bps, bytes_cab=bytes)
        @printf(io, "cabecera %.0f B: %12.0f cab/año  %8.2f GB/año  reach<=%.3e entradas/año\n",
                bytes, t.cab_ano, t.gb_ano, t.reach_ano)
    end
    println(io, "\nReachability O(#cabeceras × mergeset_limit), mergeset_limit=180 (R-FIN-12).")
    println(io, "31,5 M cabeceras/año a 1 bloque/s; ~23,6 GB/año con la cabecera típica de 748 B")
    println(io, "(TAREAS §1.4). Es la laguna que motiva el encargo; sin poda no tiene cota.")
    return String(take!(io))
end

function modo_anclaje(; semilla::UInt64=UInt64(0x9A11A))
    io = IOBuffer()
    println(io, "== §4 del INFORME: la solución se encuentra antes que los padres ==")
    fallos = valida_formula_vs_exhaustiva()
    println(io, "exhaustiva vs fórmula (modelo escalado): ",
            isempty(fallos) ? "EXACTA (0 discrepancias)" : "FALLA en $(length(fallos))")
    for f in fallos
        println(io, "  ", f)
    end
    anc = valida_anclaje_independiente(seed=semilla)
    println(io, "anclaje independiente de padres: ", anc.casos,
            " pares, discrepancias = ", anc.discrepancias)
    println(io, "\nCoste de moler un nivel si se define sobre el hash de cabecera (incluye padres):")
    @printf(io, "%5s %18s %14s\n", "L", "hashes esperados", "s a 1e6 h/s")
    for L in (10, 20, 30, 40)
        @printf(io, "%5d %18.3e %14s\n", L, 2.0^L, fmt(coste_molido_hash(L, 1e6)))
    end
    println(io, "\nUn nivel ligado a la ancestría se muele con CPU (espacio ≈ 0). Un nivel ligado")
    println(io, "a la solución y el slot no depende de los padres. No hay término medio (INFORME §4).")
    return String(take!(io))
end

function modo_mc(; semilla::UInt64=UInt64(0x5A5A), SR::UInt64=UInt64(1) << 62,
                 C::Int=1, N::Int=100_000, replicas::Int=24, Lmax::Int=8)
    io = IOBuffer()
    println(io, "== Monte Carlo vs fórmula exacta (validación del kernel) ==")
    println(io, "SR=", SR, " C=", C, " N=", N, " réplicas=", replicas,
            " hilos=", Threads.nthreads(:default), " semilla=", semilla)
    res = monte_carlo_niveles(semilla, C, SR, N, replicas; Lmax=Lmax)
    println(io, "válidos observados = ", res.validos,
            " (esperado ≈ ", @sprintf("%.1f", (Float64(SR >> 1) + 1) / 2.0^63 * N * replicas), ")")
    @printf(io, "%3s %14s %14s %14s %8s\n", "L", "exacta", "MC", "sigma", "cubre")
    for f in equivalencia_niveles(res)
        cub = f.cubre === missing ? "—" : (f.cubre ? "sí" : "NO")
        @printf(io, "%3d %14s %14s %14s %8s\n", f.L, fmt(f.exacta),
                isnan(f.mc) ? "—" : fmt(f.mc), isnan(f.sigma) ? "—" : fmt(f.sigma), cub)
    end
    return String(take!(io))
end

# ---------------------------------------------------------------------------
# Reutilización de GHOSTDAG (GDR-v0.2): blue_work no se deriva del certificado.
# ---------------------------------------------------------------------------

function construir_dag(GDR, padres::Vector{Vector{Int}}, slots::Vector{UInt64},
                       sds::Vector{UInt64}, srs::Vector{UInt64})
    params = GDR.P_DEFECTO
    est = GDR.EstadoReferencia(params, "G")
    for i in eachindex(padres)
        ok = GDR.anadir!(est, params, "B$(i + 1)", padres[i], slots[i], sds[i], srs[i],
                         UInt64(0))
        ok || error("bloque inválido en la construcción: $(est.motivo[end])")
    end
    return est
end

function modo_bluework()
    GDR = incluir_ghostdag()
    # `GDR` se carga en tiempo de ejecución; hay que invocar en el mundo más reciente.
    return Base.invokelatest(experimento_bluework, GDR)
end

function experimento_bluework(GDR)
    io = IOBuffer()
    println(io, "== Punto 7 del §3 + ATAQUE 8: blue_work no se recomputa desde un certificado ==")
    println(io, "oráculo reutilizado: GDR-v0.2 (", abspath(RUTA_GDR), ")")
    SR = typemax(UInt64) >> 1
    # Mismos (slot, sd, sr) por bloque; distinta ancestría: una fusiona B4, la otra no.
    slots = UInt64[1, 2, 3, 4]
    sds = UInt64[0, 0, 0, 0]
    srs = fill(SR, 4)
    d_merge = construir_dag(GDR, [[1], [2], [2], [3, 4]], slots, sds, srs)
    d_lineal = construir_dag(GDR, [[1], [2], [2], [3]], slots, sds, srs)
    io2 = IOBuffer()
    println(io2, "dos DAG con idénticos (slot, solution_distance, SR) por bloque:")
    println(io2, "  DAG-mergeset (B5 ← {B3,B4}): blue_score=", d_merge.gd[5].blue_score,
            "  blue_work=", d_merge.gd[5].bw)
    println(io2, "  DAG-lineal   (B5 ← {B3})   : blue_score=", d_lineal.gd[5].blue_score,
            "  blue_work=", d_lineal.gd[5].bw)
    println(io2, "El certificado de niveles de ambos es IDÉNTICO (solo depende de sd y SR),")
    println(io2, "pero blue_score y blue_work difieren. Un nodo que arranca del certificado no")
    println(io2, "puede recomputar blue_work; y `blue_work` declarado en cabecera es gratis bajo")
    println(io2, "PoST (ATAQUE 8), así que no prueba nada. La afirmación de `blue_work` solo la")
    println(io2, "comprueba un nodo completo con todo el DAG.")
    print(io, String(take!(io2)))
    return String(take!(io))
end

function modo_certificado(; Lreq::Int=8, SR::UInt64=UInt64(1) << 40, C::Int=1)
    io = IOBuffer()
    println(io, "== Punto 5 del §3: rama privada con certificado de niveles ==")
    println(io, "El adversario paga el espacio-tiempo (igual que un honesto); la pregunta no es")
    println(io, "si el gasto es real, sino si el certificado lo liga a UNA historia.")
    println(io, "\nCoste esperado de un bloque de nivel L (SR=", SR, ", C=", C, "):")
    println(io, "P(L|válida) = ", fmt(p_nivel_exacta(Lreq, SR, C)))
    @printf(io, "%5s %20s %20s\n", "L", "sorteos/bloque", "sorteos para 100 bloques")
    for L in (2, 4, 6, 8, 10, 12)
        p = Float64(p_nivel_crudo(L, SR, C))
        @printf(io, "%5d %20.3e %20.3e\n", L, 1 / p, 100 / p)
    end
    r = certificado_falso_alto(64, Lreq; SR=SR, ventana=2)
    println(io, "\ncertificado de ", length(r.certificado.bloques), " bloques, Lreq=", Lreq,
            ", ventana=", r.ventana, ": aceptado por el verificador de niveles = ", r.aceptado)
    println(io, "\nEl certificado se construye desde SOLO (slot, solución). Se puede pegar a")
    println(io, "cualquier ancestría con slot(padre) ≤ slot. El verificador lo acepta porque no")
    println(io, "hay nada más que mirar: no ve la ancestría y no puede distinguir la rama privada")
    println(io, "de la canónica. Con `--bluework` se comprueba que esa rama puede tener distinto")
    println(io, "blue_work, que es lo que el SPEC usa para decidir la cadena (§11).")
    return String(take!(io))
end

function modo_retencion(; alpha::Float64=0.10, lambda::Float64=1.0,
                        Ls=(4, 8, 12, 16))
    io = IOBuffer()
    println(io, "== Punto 4 del §3: retención. Un billete de nivel L guardado y publicado tarde ==")
    println(io, "fracción de espacio alpha = ", alpha, "   lambda objetivo = ", lambda,
            " bloques/slot")
    @printf(io, "%5s %18s %18s %18s\n", "L", "slots/nivel-L", "nivel-L/día", "días para 100")
    for L in Ls
        s = tiempo_medio_nivel(alpha, lambda, L)
        @printf(io, "%5d %18.3e %18.3f %18.3e\n", L, s, 86400 / s, 100 * s / 86400)
    end
    println(io, "\nRetener no reduce el espacio-tiempo: un bloque de nivel L cuesta ~2^(L-1)")
    println(io, "sorteos válidos, con o sin retención. Lo que compra la retención es OPTATIVIDAD")
    println(io, "—elegir la ancestría con slot(padre) ≤ slot después de tener el billete—, y esa")
    println(io, "es exactamente la propiedad que un certificado de niveles no puede comprobar")
    println(io, "porque el nivel no depende de los padres. La retención no es un ataque de")
    println(io, "recursos: es el permiso para pegar el mismo gasto a otra historia.")
    return String(take!(io))
end

function modo_resumen(; semilla::UInt64=UInt64(0x5A5A))
    io = IOBuffer()
    for (n, f) in (("NIVELES", modo_niveles()), ("MULTIPLES", modo_multiples()),
                   ("SRANCLAJE", modo_sranclaje()), ("CABECERAS", modo_cabeceras()),
                   ("ANCLAJE", modo_anclaje(semilla=semilla)),
                   ("MC", modo_mc(semilla=semilla)),
                   ("RETENCION", modo_retencion()),
                   ("CERTIFICADO", modo_certificado()),
                   ("BLUEWORK", modo_bluework()))
        println(io, "##### ", n, " #####")
        println(io, f)
        println(io)
    end
    return String(take!(io))
end

# ---------------------------------------------------------------------------
# Parseo de argumentos.
# ---------------------------------------------------------------------------

function main(args)
    semilla = UInt64(0x5A5A)
    if "--seed" in args
        i = findfirst(==("--seed"), args)
        semilla = parse(UInt64, args[i + 1])
    end
    modo = isempty(args) ? "--ayuda" : args[1]
    salida = let i = findfirst(==("--out"), args)
        i === nothing ? nothing : args[i + 1]
    end
    cab = entorno(join(args, " "), semilla)
    texto = if modo == "--entorno"
        cab
    elseif modo == "--niveles"
        cab * "\n" * modo_niveles()
    elseif modo == "--multiples"
        cab * "\n" * modo_multiples()
    elseif modo == "--sranclaje"
        cab * "\n" * modo_sranclaje()
    elseif modo == "--cabeceras"
        cab * "\n" * modo_cabeceras()
    elseif modo == "--anclaje"
        cab * "\n" * modo_anclaje(semilla=semilla)
    elseif modo == "--mc"
        cab * "\n" * modo_mc(semilla=semilla)
    elseif modo == "--retencion"
        cab * "\n" * modo_retencion()
    elseif modo == "--certificado"
        cab * "\n" * modo_certificado()
    elseif modo == "--bluework"
        cab * "\n" * modo_bluework()
    elseif modo == "--resumen"
        cab * "\n" * modo_resumen(semilla=semilla)
    else
        cab * "\nmodos: --entorno --niveles --multiples --sranclaje --cabeceras --anclaje " *
              "--mc --certificado --bluework --resumen [--seed N] [--out fichero]\n"
    end
    print(texto)
    if salida !== nothing
        isdir(RES) || mkpath(RES)
        write(joinpath(RES, salida), texto)
    end
end

main(collect(ARGS))
