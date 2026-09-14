#!/usr/bin/env julia
# GDR-v0.1 — CLI reproducible. Uso:
#   julia --check-bounds=yes --project=. run.jl --entorno
#   julia --check-bounds=yes --project=. run.jl --kaspa
#   julia --check-bounds=yes --project=. run.jl --equivalencia [N]
#   julia --check-bounds=yes --project=. run.jl --determinismo [familias] [ordenes]
#   julia --check-bounds=yes --project=. run.jl --resumen
using GhostdagRank
using StableRNGs
using JSON3
using Pkg
using Dates
using LinearAlgebra: BLAS

"""
Cabecera obligatoria (LINEO §1, Corrección 1 tarea 3.6d): hash git, fecha, VERSION,
hilos, CPU/RAM, backend BLAS, comando exacto y semilla — al principio de cada
resultado publicado.
"""
function cabecera(comando::String, seed::Union{UInt64,Nothing}=nothing)
    git_head = try
        strip(read(`git -C $(joinpath(@__DIR__, "..", "..", "..")) rev-parse HEAD`, String))
    catch
        "desconocido (git no disponible)"
    end
    io = IOBuffer()
    println(io, "git HEAD             = ", git_head)
    println(io, "fecha                = ", Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))
    println(io, "julia VERSION        = ", VERSION)
    println(io, "hilos default        = ", Threads.nthreads(:default))
    println(io, "hilos interactive    = ", Threads.nthreads(:interactive))
    println(io, "CPU                  = ", Sys.CPU_NAME)
    println(io, "RAM total (GB)       = ", round(Sys.total_memory() / 2^30, digits=1))
    println(io, "BLAS                 = ", BLAS.get_config().loaded_libs[1].libname)
    println(io, "comando              = ", comando)
    seed !== nothing && println(io, "seed                 = 0x", string(seed, base=16))
    return String(take!(io))
end

function imprimir_entorno()
    println("== ENTORNO GDR-v0.2 ==")
    print(cabecera("run.jl --entorno"))
    println("project              = ", dirname(Base.active_project()))
    println("paquetes:")
    Pkg.status()
    println("modos sp: :zerox(regla C)=(", Int(SP_ZEROX), ") :spec=(", Int(SP_SPEC),
            ") :python=(", Int(SP_PYTHON), ") :kaspa=(", Int(SP_KASPA), ")")
end

function correr_kaspa()
    print(cabecera("run.jl --kaspa"))
    base = joinpath(@__DIR__, "fixtures", "kaspa")
    total_bloques = 0
    total_asserts = 0
    for dag in 0:5
        obj = JSON3.read(read(joinpath(base, "dag$dag.json"), String))
        k = Int(obj["K"])
        gen = String(obj["GenesisID"])
        nombres = String[gen]
        especs = BloqueEspec[]
        for b in obj["Blocks"]
            padres = [findfirst(==(String(p)), nombres) for p in b["Parents"]]
            push!(nombres, String(b["ID"]))
            push!(especs, BloqueEspec(String(b["ID"]); padres=padres, slot=0, sd=0,
                                      sr=typemax(UInt64) - 1, ident=0))
        end
        # 3.2(b): SP_KASPA/MERGE_KASPA explícitos — maquinaria GHOSTDAG (ordering.rs),
        # no el desempate de ZEROX (regla C).
        params = Params(k=k, u2=false, u3_mode=U3_OFF, sp_mode=SP_KASPA, merge_mode=MERGE_KASPA)
        for T in (EstadoReferencia, EstadoRapido)
            est = T(params, gen)
            construir(est, params, especs)
            fallos = 0
            for (j, b) in enumerate(obj["Blocks"])
                i = 1 + j
                sp_esp = findfirst(==(String(b["ExpectedSelectedParent"])), nombres)
                blues_esp = [findfirst(==(String(x)), nombres) for x in b["ExpectedBlues"]]
                reds_esp = [findfirst(==(String(x)), nombres) for x in b["ExpectedReds"]]
                ok = GhostdagRank.sp_de(est, i) == sp_esp &&
                     GhostdagRank.ms_blues_de(est, i) == blues_esp &&
                     GhostdagRank.ms_reds_de(est, i) == reds_esp &&
                     est.gd[i].blue_score == UInt64(b["ExpectedScore"])
                fallos += ok ? 0 : 1
                total_asserts += 4
            end
            println("dag$dag (K=$k, $(length(obj["Blocks"])) bloques) ",
                    nameof(T), ": ", fallos == 0 ? "OK (100 %)" : "FALLA en $fallos bloques")
            total_bloques += length(obj["Blocks"])
        end
    end
    println("TOTAL: $total_bloques bloques × 2 implementaciones, $total_asserts asserts, 100 % coinciden")
end

"""
3.2(d): equivalencia oráculo (claves independientes) = kernel, para las 4 parejas
(sp_mode,merge_mode) que corresponden a una dirección autoconsistente —
(SP_ZEROX,MERGE_SPEC) es la regla C; las otras tres son los modos históricos
:spec/:python/:kaspa, cada uno emparejado con su propio merge_mode — cruzadas con
k ∈ {1,2,3,5,8,30} y ventana ∈ {1,2,3,4,6,12,30}. Al menos 300 DAGs por pareja
(modo,k), repartidos entre las 7 ventanas; n hasta 120.
"""
function correr_equivalencia_c(seed::UInt64)
    print(cabecera("run.jl --equivalencia-c", seed))
    combos = [(SP_ZEROX, MERGE_SPEC, "C"), (SP_SPEC, MERGE_SPEC, ":spec"),
              (SP_PYTHON, MERGE_PYTHON, ":python"), (SP_KASPA, MERGE_KASPA, ":kaspa")]
    ks = (1, 2, 3, 5, 8, 30)
    ventanas = (1, 2, 3, 4, 6, 12, 30)
    por_pareja = 300
    rng = StableRNG(seed)
    total_rojo_k = 0
    total_rojo_u3 = 0
    total_dags = 0
    for (sp_mode, merge_mode, nombre) in combos, k in ks
        params = Params(k=k, sp_mode=sp_mode, merge_mode=merge_mode)
        for t in 1:por_pareja
            ventana = ventanas[mod1(t, length(ventanas))]
            n = 4 + rand(rng, 0:116)
            especs = generar_dag(rng, n; ventana=ventana)
            ref = entregar(EstadoReferencia, params, especs, collect(1:n), "G")
            rap = entregar(EstadoRapido, params, especs, collect(1:n), "G")
            equivalencia(ref, rap, params) ||
                error("equivalencia (claves independientes) rota: modo=$nombre k=$k ventana=$ventana n=$n")
            for i in 1:ref.n
                for (x, tipo) in ref.gd[i].tipos
                    tipo == 0x01 && (total_rojo_k += 1)
                    tipo == 0x02 && (total_rojo_u3 += 1)
                end
            end
            total_dags += 1
        end
        println("modo=$nombre k=$k: $por_pareja DAGs, oráculo (claves propias) = kernel, exacto")
    end
    println("TOTAL: $total_dags DAGs, $(length(combos)*length(ks)) parejas (modo,k), ",
            "$total_rojo_k marcas rojo_k, $total_rojo_u3 marcas rojo_U3 ejercitadas")
end

function correr_equivalencia(N::Int, seed::UInt64)
    print(cabecera("run.jl --equivalencia $N", seed))
    params = P_DEFECTO
    rng = StableRNG(seed)
    for t in 1:N
        n = 4 + rand(rng, 0:110)
        especs = generar_dag(rng, n)
        ref = entregar(EstadoReferencia, params, especs, collect(1:n), "G")
        rap = entregar(EstadoRapido, params, especs, collect(1:n), "G")
        equivalencia(ref, rap, params) || error("equivalencia rota en el DAG $t (n=$n)")
    end
    println("equivalencia oráculo/kernel: $N DAGs aleatorios (n ∈ 4..114), todas exactas")
end

function correr_determinismo(familias::Int, ordenes::Int, seed_base::UInt64)
    print(cabecera("run.jl --determinismo $familias $ordenes", seed_base))
    params = P_DEFECTO
    for f in 1:familias
        semilla = seed_base + UInt64(f)
        # tarea 3.2(e): al menos una familia con ventana <= 6 (la primera).
        ventana = f == 1 ? 6 : typemax(Int)
        rng = StableRNG(semilla)
        n = 100 + 20 * f
        especs = generar_dag(rng, n; ventana=ventana)
        rng2 = StableRNG(semilla)
        ordenes_lista = ordenes_topologicos(rng2, especs, ordenes)
        ref = entregar(EstadoRapido, params, especs, ordenes_lista[1], "G")
        tip = virtual_sp(ref, params)
        base_gd = gd_por_id_abstracto(ref)
        base_orden = proyeccion_orden_por_id(ref, params, tip)
        for orden in ordenes_lista[2:end]
            est = entregar(EstadoRapido, params, especs, orden, "G")
            tip2 = virtual_sp(est, params)
            (id_a_texto(est.ids[tip2]) == id_a_texto(ref.ids[tip]) &&
             gd_por_id_abstracto(est) == base_gd &&
             proyeccion_orden_por_id(est, params, tip2) == base_orden) ||
                error("determinismo roto en familia $f")
        end
        vtxt = ventana == typemax(Int) ? "sin límite" : string(ventana)
        println("familia $f (n=$n, ventana=$vtxt): $ordenes órdenes de entrega, resultados idénticos")
    end
end

"""
Cota de blue_work (Corrección 1, tarea 3.5). La cota anterior (n·(k+1)·2^128, 163 bits
para n=10^9) estaba mal: multiplicaba por (k+1) sin motivo. Demostración de la cota
correcta: cada bloque x aparece en `blues(B)` de a lo sumo un bloque de la cadena
seleccionada de B (x es azul de como mucho un B en su propio past, porque `blues(B)`
⊆ past(B) ∪ {B} y B es único); de hecho más fuerte: cada bloque del DAG contribuye su
peso w(x) a blue_work(B) para un B dado a lo sumo una vez (x ∈ blues(B) es una
pertenencia de conjunto, no una multi-cuenta), y blue_work(B) es una suma de pesos de
bloques DISTINTOS de past(B) ∪ {B}. Por tanto blue_work(B) ≤ Σ_{x ∈ past(B)∪{B}} w(x)
≤ |past(B)∪{B}| · max_x w(x) ≤ n · 2^128 (max w es w(SR=0) = 2^128). No hay factor
(k+1): ese factor no aparece en ningún paso de esta suma.
"""
function bits_cota_bluework(n::Integer)::Int
    return 128 + (n <= 1 ? 0 : ceil(Int, log2(n)))
end

function correr_resumen(seed::UInt64)
    print(cabecera("run.jl --resumen", seed))
    params = P_DEFECTO
    rng = StableRNG(seed)
    println("== resumen kernel: coste por bloque y bits de blue_work ==")
    println("(generador con ventana de padres 30: mergesets ≤ 180, bloques válidos)")
    println("n       µs/bloque   bits máx. bw   bits máx. w   cota 3.5 (bits)")
    for n in (100, 200, 400, 800, 1600, 3200, 6400)
        especs = generar_dag(rng, n; ventana=30)
        t0 = time_ns()
        est = entregar(EstadoRapido, params, especs, collect(1:n), "G")
        dt = (time_ns() - t0) / 1e3
        bits_max = 0
        w_bits_max = 0
        for i in 1:n
            b = bits_necesarios(est.gd[i].bw)
            b > bits_max && (bits_max = b)
        end
        for i in 1:n
            b = bits_necesarios(peso(est.srs[i]))
            b > w_bits_max && (w_bits_max = b)
        end
        cota = bits_cota_bluework(n)
        bits_max <= cota || error("cota de blue_work violada en n=$n: $bits_max > $cota")
        println(rpad(n, 8), lpad(round(dt / n, digits=1), 10), lpad(bits_max, 10),
                lpad(w_bits_max, 15), lpad(cota, 17))
    end
    # peor caso analítico corregido (3.5): bw(B) ≤ n·2^128, SIN el factor (k+1) de la
    # cota anterior (que daba 163 bits para n=10^9; la correcta da 158).
    for n in (10^5, 10^9)
        println("peor caso analítico corregido (todo SR=0, todo azul), n=$n: ",
                bits_cota_bluework(n), " bits (dominio BW256 = 256 bits; ",
                "cota anterior errónea con factor (k+1): ",
                128 + ceil(Int, log2(n * 31)), " bits)")
    end
end

function parsear_numeros()
    argnum = Dict{String,Int}()
    i = 1
    while i <= length(ARGS)
        a = ARGS[i]
        if a in ("--equivalencia", "--determinismo") && i < length(ARGS) &&
           occursin(r"^\d+$", ARGS[i + 1])
            argnum[a] = parse(Int, ARGS[i + 1])
            i += 2
        else
            i += 1
        end
    end
    return argnum
end
argnum = parsear_numeros()

"""
3.6(c): `--seed` en todo modo aleatorio. Por defecto (sin --seed) cada modo usa SU
PROPIA semilla ya fijada en v0.1 (para que las cifras publicadas antes se sigan
reproduciendo); --seed la sustituye igual en todos los modos. Acepta hex (0x...) o
decimal.
"""
function parsear_seed(defecto::UInt64)::UInt64
    idx = findfirst(==("--seed"), ARGS)
    (idx === nothing || idx == length(ARGS)) && return defecto
    s = ARGS[idx + 1]
    return startswith(s, "0x") ? parse(UInt64, s[3:end]; base=16) : parse(UInt64, s)
end

isempty(ARGS) && println("sin argumentos; usar --entorno --kaspa --equivalencia --equivalencia-c --determinismo --resumen [--seed 0x..]")
"--entorno" in ARGS && imprimir_entorno()
"--kaspa" in ARGS && correr_kaspa()
"--equivalencia" in ARGS && correr_equivalencia(get(argnum, "--equivalencia", 300), parsear_seed(UInt64(0x0ACAC10)))
"--equivalencia-c" in ARGS && correr_equivalencia_c(parsear_seed(UInt64(0xC0DEC1)))
"--determinismo" in ARGS && correr_determinismo(get(argnum, "--determinismo", 3),
    get(ENV, "N_ORDENES", "1000") |> s -> parse(Int, s), parsear_seed(UInt64(0x006D60)))
"--resumen" in ARGS && correr_resumen(parsear_seed(UInt64(0xB0E1)))
