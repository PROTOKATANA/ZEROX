#!/usr/bin/env julia
# PRV-v0.1 — CLI reproducible. Ver METODO.md.
using Pkg
using Printf
using Dates
using StableRNGs

const DIR = @__DIR__
const RES = joinpath(DIR, "resultados")

include(joinpath(DIR, "src", "PruebaRecursiva.jl"))
using .PruebaRecursiva

function entorno(comando::String, semilla::Union{Nothing,UInt64}=nothing)
    io = IOBuffer()
    println(io, "== ENTORNO PRV-v0.1 ==")
    git = try
        strip(read(`git -C $(dirname(dirname(dirname(dirname(DIR))))) rev-parse HEAD`, String))
    catch
        "no disponible"
    end
    println(io, "git_HEAD: ", git)
    println(io, "fecha: ", Dates.now())
    println(io, "julia: ", VERSION)
    println(io, "cpu: ", Sys.CPU_NAME)
    println(io, "hilos_julia: ", Threads.nthreads(:default), " / ",
            Threads.nthreads(:interactive))
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
# §2 — SELECCIÓN vs VALIDEZ (prioridad máxima).
# ---------------------------------------------------------------------------

function modo_seleccion(GDR; n::Int=40, seed::UInt64=UInt64(0x5E1EC7))
    io = IOBuffer()
    println(io, "== §2 · VALIDEZ ≠ SELECCIÓN ==")
    println(io, "Pregunta: ¿puede un nodo nuevo comprobar, SIN el DAG, que ninguna rama")
    println(io, "competidora tiene más blue_work? La prueba recursiva sólo acredita validez.")
    println(io)
    r = dos_historias(GDR, n, seed)
    println(io, "H1: ", r.h1.n, " bloques, canónica = ", r.h1.canonica,
            ", blue_work = ", r.h1.blue_work)
    println(io, "H2: ", r.h2.n, " bloques, canónica = ", r.h2.canonica,
            ", blue_work = ", r.h2.blue_work)
    p1 = PruebaValidez(r.h1); p2 = PruebaValidez(r.h2)
    println(io, "verifica_prueba_validez(H1) = ", verifica_prueba_validez(p1),
            "   verifica_prueba_validez(H2) = ", verifica_prueba_validez(p2))
    println(io, "H1.canonica != H2.canonica : ", r.h1.canonica != r.h2.canonica)
    println(io, "blue_work(H2) > blue_work(H1) : ", r.h2.blue_work > r.h1.blue_work)
    println(io)
    println(io, "Puntas de H1 (por blue_work): ", r.puntas1)
    println(io, "Puntas de H2 (por blue_work): ", r.puntas2)
    println(io)
    println(io, "H2 = H1 + un bloque válido Y que fusiona las puntas de H1. Ambas historias")
    println(io, "son válidas y sus pruebas de validez verifican. Un nodo que recibe sólo")
    println(io, "π(H1) no puede distinguir el mundo en que la red sigue H1 del mundo en que")
    println(io, "el adversario RETIENE H2: su vista es idéntica y la punta correcta difiere.")
    println(io, "Por tanto ninguna prueba que sólo acredite validez decide la canónica.")
    println(io, "Es exactamente la laguna de D5 de PPP-v0.1, con otro traje.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
# §3.2 — coste de probar GHOSTDAG por bloque.
# ---------------------------------------------------------------------------

function analiza_dag(GDR, n::Int, W::Int, f::Factores)
    rng = StableRNG(UInt64(0xC057E) + UInt64(n))
    especs = GDR.generar_dag(rng, n, "C"; ventana=6)
    est = construir_estado(GDR, especs)
    c = contar_rapido(est)
    ms_medio = sum(c.ms) / c.n
    ctx_medio = sum(c.ctx) / c.n
    ctx_max = maximum(c.ctx)
    rpb = restricciones_por_bloque(c, W, f)
    tasa = bloques_por_segundo_que_cierra(rpb.lo, f)
    return (n=n, W=W, ms_medio=ms_medio, ctx_medio=ctx_medio, ctx_max=ctx_max,
            pares=pares_anticone(c, W), rpb=rpb, tasa=tasa, conteo=c)
end

"""
Coste extrapolado para una ventana `W` mayor que el DAG medido: el contexto por bloque
se toma como el mínimo entre `W` y el contexto medido, de modo que para `W ≥ ctx` el
coste por bloque es una EXTRAPOLACIÓN lineal (declarada) y no una medición.
"""
function analiza_extrapolado(GDR; n::Int=512, Ws=(1, 10, 100, 1000, 10_000, 100_000),
                             f::Factores=P_FACTORES)
    rng = StableRNG(UInt64(0xC057E) + UInt64(n))
    especs = GDR.generar_dag(rng, n, "C"; ventana=6)
    est = construir_estado(GDR, especs)
    c = contar_rapido(est)
    ms_medio = sum(c.ms) / c.n
    ctx_medio = sum(c.ctx) / c.n
    filas = NamedTuple[]
    for W in Ws
        r_med = coste_paramétrico(ms_medio, W, f)
        r_cap = coste_paramétrico(180, W, f)   # mergeset_limit de C-GD-04
        t_med = tasas_cierre(r_med, f)
        t_cap = tasas_cierre(r_cap, f)
        push!(filas, (W=W, r_med=r_med, r_cap=r_cap, t_med=t_med, t_cap=t_cap))
    end
    return (ms_medio=ms_medio, ctx_medio=ctx_medio, filas=filas)
end

function modo_coste(GDR; n::Int=512, W::Int=1000)
    io = IOBuffer()
    f = P_FACTORES
    a = analiza_dag(GDR, n, W, f)
    println(io, "== §3.2 · Coste de probar GHOSTDAG por bloque (cota INFERIOR) ==")
    println(io, "DAG n=", n, " (GDR-v0.2), ventana de fusión W=", W)
    @printf(io, "por bloque: mergerset medio=%.2f  contexto medio=%.2f (máx %d)\n",
            a.ms_medio, a.ctx_medio, a.ctx_max)
    println(io, "pares (candidato, azul) = ", a.pares)
    @printf(io, "restricciones/bloque (sin firmas, KZG, PoT, UTXO): %.3e .. %.3e\n",
            a.rpb.lo, a.rpb.hi)
    t = tasas_cierre(a.rpb.lo, f)
    @printf(io, "cierre (bloques/s): Halo2 realista=%.3e  1 hilo optimista=%.3e  24 hilos=%.3e\n",
            t.halo2, t.un_hilo, t.veinticuatro)
    println(io, "  (> 1 ⇒ cierra a 1 bloque/s con esa tasa; < 1 ⇒ no cierra)")
    println(io)
    println(io, "Desglose (gs=", f.gates_por_sbox_lo, "): ",
            coste_restricciones(a.conteo, W, f))
    println(io,)
    println(io, "NO incluye verificar en circuito: el sello Ed25519, los 2 KZG por cabecera")
    println(io, "(§26/§7), la cadena PoT (AES por slot) ni las transiciones UTXO. Sólo suman.")
    return String(take!(io))
end

function modo_barrido(GDR; n::Int=512)
    io = IOBuffer()
    f = P_FACTORES
    e = analiza_extrapolado(GDR; n=n, f=f)
    println(io, "== §3.2/§6 · a qué tasa y con qué ventana cierra ==")
    @printf(io, "DAG medido n=%d (GDR-v0.2): mergerset medio=%.2f, contexto medio=%.2f\n",
            n, e.ms_medio, e.ctx_medio)
    println(io, "Modelo por bloque: restr = M · W · ceil(log2(W+1)) · 80 · gs   (gs=2)")
    println(io, "M = mergeset medio medido, y M = 180 (tope de C-GD-04). Contexto = W.")
    println(io)
    @printf(io, "%10s %13s %13s | %15s %15s\n", "W", "restr(M med)", "restr(M=180)",
            "bloq/s Halo2(med)", "bloq/s Halo2(180)")
    for fila in e.filas
        @printf(io, "%10d %13.3e %13.3e | %15.3e %15.3e\n", fila.W, fila.r_med,
                fila.r_cap, fila.t_med.halo2, fila.t_cap.halo2)
    end
    println(io)
    println(io, "Ventana crítica W* (mayor potencia de 2 que CIERRA a 1 bloque/s):")
    for (nom, M) in (("M medido", e.ms_medio), ("M=180", 180.0))
        @printf(io, "  %-9s Halo2 realista=%8d   1e9=%8d   2.4e10=%8d\n", nom,
                ventana_critica(M, f.ops_campo_halo2, f),
                ventana_critica(M, f.ops_campo_1hilo, f),
                ventana_critica(M, f.ops_campo_24hilos, f))
    end
    println(io)
    println(io, "Para W mayor que el DAG medido la fila es una ESTIMACIÓN con el contexto lleno")
    println(io, "(W azules), no una medición. La ventana W es la profundidad de fusión")
    println(io, "(C-GD-11), constante PENDIENTE: el coste va como función de W, sin fijarla.")
    println(io, "Cota INFERIOR: firmas Ed25519, KZG, PoT y UTXO no están incluidos; sólo suman.")
    return String(take!(io))
end

function modo_lineal(GDR; n::Int=512, W::Int=1000)
    io = IOBuffer()
    f = P_FACTORES
    a = analiza_dag(GDR, n, W, f)
    lin = factor_lineal(a.conteo, W, f)
    println(io, "== §3.2 · DAG frente a cadena lineal equivalente ==")
    @printf(io, "DAG (n=%d, W=%d): %.3e restricciones/bloque\n", n, W, lin.dag)
    @printf(io, "cadena lineal (2 Poseidon/bloque): %.3e restricciones/bloque\n", lin.lineal)
    @printf(io, "factor DAG/lineal = %.3e×\n", lin.factor)
    println(io, "El factor mide lo que añade probar mergeset, coloreo y reachability.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
# §3.4 — ¿es orchard = "=0.15.5" una ventaja de recursión?
# ---------------------------------------------------------------------------

function modo_orchard()
    io = IOBuffer()
    println(io, "== §3.4 · ¿Halo2 en el árbol de dependencias = recursión disponible? ==")
    println(io, "SPEC §9 fija `orchard = \"=0.15.5\"`; Orchard es Halo2 sobre el ciclo")
    println(io, "Pallas/Vesta (SPEC.md §9; research/orchard-bundle.md:58,100).")
    println(io, "Hechos comprobados en fuentes:")
    println(io, "  - halo2_poseidon P128Pow5T3: ancho 3, R_F=8, R_P=56 (80 S-boxes/perm).")
    println(io, "  - Halo2 es un sistema de prueba; su libro describe compromisos/FFT/MSM y")
    println(io, "    el argumento de producto interno, NO un mecanismo de recursión.")
    println(io, "  - La recursión exige implementar el VERIFICADOR dentro del circuito y un")
    println(io, "    sistema PCD/IVC (Kimchi/Pickles en Mina). Eso no viene con `orchard`.")
    println(io)
    println(io, "Conclusión: el ciclo Pallas/Vesta es una condición NECESARIA —no hay que")
    println(io, "cambiar de curvas— pero NO es un sistema de recursión utilizable. Tener")
    println(io, "`orchard` en el árbol sólo aporta la primitiva Poseidon y el probador Halo2.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
# §6 · fuentes citadas: comprobar existencia con ruta desde la raíz del repo.
# ---------------------------------------------------------------------------

const FUENTES = [
    "SPEC.md",
    "TAREAS.md",
    "research/orchard-bundle.md",
    "research/orchard-math-verification.md",
    "veritas/consenso/poda-post-v1/DERIVACIONES.md",
    "veritas/consenso/poda-post-v1/INFORME.md",
    "veritas/consenso/poda-post-v1/PROPUESTA.md",
    "veritas/consenso/poda-post-v1/PROCEDENCIA.md",
    "veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl",
    "veritas/consenso/ghostdag-rank-v1/src/referencia.jl",
    "veritas/consenso/ghostdag-rank-v1/src/modelo.jl",
    "crates/zx-core/src/preimage/dag.rs",
]

function modo_fuentes()
    raiz = dirname(dirname(dirname(dirname(DIR))))
    io = IOBuffer()
    println(io, "== §6 · fuentes citadas (existencia comprobada desde la raíz) ==")
    println(io, "raíz: ", raiz)
    faltan = 0
    for f in FUENTES
        p = joinpath(raiz, f)
        if isfile(p)
            println(io, "  OK  ", f, "  (", filesize(p), " B)")
        else
            println(io, "  FALTA ", f)
            faltan += 1
        end
    end
    println(io, "\nLas huellas sha256 de estas fuentes y de los artefactos están en HUELLAS.sha256,")
    println(io, "verificable con `sha256sum -c` desde la raíz del repositorio.")
    println(io, "faltan: ", faltan)
    return String(take!(io))
end

function modo_resumen(GDR; n::Int=512, W::Int=1000, seed::UInt64=UInt64(0x5E1EC7))
    io = IOBuffer()
    for (nom, txt) in (("SELECCION", modo_seleccion(GDR; n=40, seed=seed)),
                       ("COSTE", modo_coste(GDR; n=n, W=W)),
                       ("BARRIDO", modo_barrido(GDR; n=n)),
                       ("LINEAL", modo_lineal(GDR; n=n, W=W)),
                       ("ORCHARD", modo_orchard()))
        println(io, "##### ", nom, " #####")
        println(io, txt)
        println(io)
    end
    return String(take!(io))
end

function main(args)
    semilla = UInt64(0x5E1EC7)
    if "--seed" in args
        i = findfirst(==("--seed"), args)
        semilla = parse(UInt64, args[i + 1])
    end
    n = let i = findfirst(==("--n"), args)
        i === nothing ? 512 : parse(Int, args[i + 1])
    end
    W = let i = findfirst(==("--W"), args)
        i === nothing ? 1000 : parse(Int, args[i + 1])
    end
    modo = isempty(args) ? "--ayuda" : args[1]
    salida = let i = findfirst(==("--out"), args)
        i === nothing ? nothing : args[i + 1]
    end
    cab = entorno(join(args, " "), semilla)
    texto = if modo == "--entorno"
        cab
    elseif modo == "--fuentes"
        cab * "\n" * modo_fuentes()
    elseif modo == "--orchard"
        cab * "\n" * modo_orchard()
    elseif modo in ("--seleccion", "--coste", "--barrido", "--lineal", "--resumen")
        GDR = incluir_ghostdag()
        cuerpo = if modo == "--seleccion"
            Base.invokelatest(modo_seleccion, GDR; n=40, seed=semilla)
        elseif modo == "--coste"
            Base.invokelatest(modo_coste, GDR; n=n, W=W)
        elseif modo == "--barrido"
            Base.invokelatest(modo_barrido, GDR; n=n)
        elseif modo == "--lineal"
            Base.invokelatest(modo_lineal, GDR; n=n, W=W)
        else
            Base.invokelatest(modo_resumen, GDR; n=n, W=W, seed=semilla)
        end
        cab * "\n" * cuerpo
    else
        cab * "\nmodos: --entorno --seleccion --coste --barrido --lineal --orchard " *
              "--fuentes --resumen [--n N] [--W W] [--seed S] [--out f]\n"
    end
    print(texto)
    if salida !== nothing
        isdir(RES) || mkpath(RES)
        write(joinpath(RES, salida), texto)
    end
end

main(collect(ARGS))
