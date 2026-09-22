# IB-v0.1 — CLI reproducible. Ninguna cifra del INFORME sale de otro sitio que de aquí.
#
#   JULIA_DEPOT_PATH="<investigacion>/.julia-depot:$HOME/.julia" \
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     ./veritas/julia.sh --project=. run.jl --seed 0x5a5a --replicas 200 todo
#
# `--seed` es obligatorio para los subcomandos con Monte Carlo.
using IdentidadBillete
import GhostdagRank as GDR
using StableRNGs, Random, Printf, Dates
const IB = IdentidadBillete

const P0 = GDR.Params()

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
"Semilla por réplica NO consecutiva (secuencia de Weyl). Evita el sesgo de StableRNG
con semillas consecutivas, hallazgo de P-ZRX/P-PUERTA."
semilla_replica(maestra::UInt64, r::Integer)::UInt64 =
    maestra ⊻ (UInt64(r) * 0x9E3779B97F4A7C15)

"Intervalo de confianza de Wilson al 95 % para una proporción."
function wilson(k::Integer, n::Integer; z::Float64=1.96)
    n == 0 && return (0.0, 0.0)
    p = k / n
    d = 1 + z^2 / n
    centro = (p + z^2 / (2n)) / d
    medio = z * sqrt(p * (1 - p) / n + z^2 / (4n^2)) / d
    return (max(0.0, centro - medio), min(1.0, centro + medio))
end

function cabecera(comando::String, semilla, replicas)
    println("# IB-v0.1 · identidad-billete-v1 · comando=", comando)
    println("# VERSION=", VERSION, "  hilos=", Threads.nthreads(:default),
            "/", Threads.nthreads(:interactive))
    println("# CPU=", Sys.CPU_NAME, "  hilos_lógicos=", Sys.CPU_THREADS)
    println("# semilla=", semilla === nothing ? "-" : string(semilla), "  réplicas=", replicas)
    println("# fecha=", Dates.now())
    println()
end

fmt(x) = @sprintf("%.4f", x)
fmtpeso(x) = x > big(10)^20 ? @sprintf("2^%.1f", log2(Float64(x))) : string(x)

# ---------------------------------------------------------------------------
# 1 · Fixtures
# ---------------------------------------------------------------------------
function correr_fixtures()
    _, F = IB.fixtures_canonicos()
    println("| fixture | bloques | modo | válidos | U2 | herencia | azul | rojo_k | rojo_U3 | pagables | inertes | identidades | entropía violada | peso |")
    println("|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for nombre in sort(collect(keys(F))), m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
        r = IB.evaluar_rapido(F[nombre], m, P0); s = IB.resumen(r)
        println("| ", nombre, " | ", length(F[nombre]) - 1, " | ", m, " | ", s.validos, " | ",
                s.u2, " | ", s.herencia, " | ", s.azules, " | ", s.rojo_k, " | ",
                s.rojo_u3, " | ", s.pagables, " | ", s.inertes, " | ", s.identidades, " | ",
                s.entropia_violada, " | ", fmtpeso(s.peso), " |")
    end
end

# ---------------------------------------------------------------------------
# 2 · Controles
# ---------------------------------------------------------------------------
function correr_controles()
    println("## C1 · ¿A refina a B? (subuniverso exhaustivo, escalares grandes)")
    r = IB.control_refinamiento()
    println("- pares evaluados sobre ", r.n, " soluciones (O(n²))")
    println("- violaciones A-igual ⇒ B-distinto: **", length(r.violaciones), "**")
    if !isempty(r.violaciones)
        x, y = r.violaciones[1]
        println("  - primera: chunk=", x.chunk, " pieza ", x.pieza, " vs ", y.pieza)
    end
    println()

    println("## C2 · ¿A y B se cruzan? (dominio de chunk reducido a 4 bits)")
    r2 = IB.control_cruce(colision_bits=4)
    println("- soluciones: ", r2.n)
    println("- pares A-igual y B-distinto (cruce hacia B): ", length(r2.a_igual_b_distinto))
    println("- pares B-igual y A-distinto (cruce hacia A): ", length(r2.b_igual_a_distinto))
    if !isempty(r2.a_igual_b_distinto)
        x, y = r2.a_igual_b_distinto[1]
        println("  - ejemplo: chunk=", x.chunk, " pieza ", x.pieza, "/", y.pieza,
                " flujo ", x.flujo, "/", y.flujo, " slot ", x.slot, "/", y.slot)
    end
    if !isempty(r2.b_igual_a_distinto)
        x, y = r2.b_igual_a_distinto[1]
        println("  - ejemplo: pieza=", x.pieza, " chunk ", x.chunk, "/", y.chunk,
                " flujo ", x.flujo, "/", y.flujo, " slot ", x.slot, "/", y.slot)
    end
    println()

    println("## C3/C4 · oráculo↔kernel y capa pagable por conjuntos")
    _, F = IB.fixtures_canonicos()
    peor = 0; total = 0
    for nombre in sort(collect(keys(F))), m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
        rr = IB.evaluar_ref(F[nombre], m, P0); rk = IB.evaluar_rapido(F[nombre], m, P0)
        rb = IB.evaluar_bruto(F[nombre], m, P0)
        total += 1
        (IB.equivalentes(rr, rk) && rb.pagables == rk.pagables) || (peor += 1)
    end
    println("- ", total, " casos (fixture × modo); discrepancias: **", peor, "**")
    println()

    println("## C4 · exhaustivo estructural sobre dos copias (rejilla declarada)")
    exhaustivo_copias()
end

"Enumera TODAS las asignaciones (pieza, flujo) de dos copias en el mismo slot y dos ramas."
function exhaustivo_copias(; npieza::Int=8, nflujo::Int=2)
    total = 0
    mismo_b = 0; mismo_b_chunk_distinto = 0; mismo_b_chunk_igual = 0
    mismo_a = 0; mismo_a_pieza_distinta = 0
    peso_igual = 0
    for p1 in 0:(npieza - 1), f1 in 0:(nflujo - 1), p2 in 0:(npieza - 1), f2 in 0:(nflujo - 1)
        total += 1
        s1 = IB.solucion(pk=1, sector=0, historia=0, pieza=p1, slot=1, flujo=f1)
        s2 = IB.solucion(pk=1, sector=0, historia=0, pieza=p2, slot=1, flujo=f2)
        ib = IB.identidad(IB.MODO_B, s1) == IB.identidad(IB.MODO_B, s2)
        ia = IB.clave_a(s1) == IB.clave_a(s2)
        ic = IB.identidad(IB.MODO_C, s1) == IB.identidad(IB.MODO_C, s2)
        ia && (mismo_a += 1)
        ib && (mismo_b += 1)
        if ib
            s1.chunk == s2.chunk ? (mismo_b_chunk_igual += 1) : (mismo_b_chunk_distinto += 1)
        end
        ia && p1 != p2 && (mismo_a_pieza_distinta += 1)
        @assert ib == ic "B y C deben coincidir en el juguete (H3)"
    end
    println("- asignaciones enumeradas: ", total, " (", npieza, " piezas × ", nflujo,
            " flujos, por copia)")
    println("- misma identidad B (misma oportunidad): ", mismo_b, " (", fmt(mismo_b/total), ")")
    println("  - de ellas, mismo `chunk`: ", mismo_b_chunk_igual, " · `chunk` distinto: ",
            mismo_b_chunk_distinto)
    println("- misma identidad A (mismo `chunk`): ", mismo_a, " (", fmt(mismo_a/total), ")")
    println("  - de ellas, con pieza distinta (cruce A→B): ", mismo_a_pieza_distinta)
end

# ---------------------------------------------------------------------------
# 3 · Monte Carlo
# ---------------------------------------------------------------------------
"MC-A · multiplicidad de ganadores por (sector, slot, flujo) frente a Binomial(P,q)."
function mc_multiplicidad(semilla::UInt64, replicas::Int, P::Int, q::Float64)
    cuenta = zeros(Int, P + 1)
    for r in 1:replicas
        rng = StableRNG(semilla_replica(semilla, r))
        slot = rand(rng, 1:N_SLOT-1)
        flujo = rand(rng, 0:N_FLOW-1)
        pk = rand(rng, 0:N_PK-1); sector = rand(rng, 0:N_SECTOR-1)
        w = length(IB.ganadores(pk, sector, 0, slot, flujo, P, q))
        cuenta[w + 1] += 1
    end
    media = sum((w - 1) * cuenta[w] for w in 1:(P + 1)) / replicas
    dos = sum(cuenta[3:end])
    lo, hi = wilson(dos, replicas)
    # Binomial exacta
    pbin = 1 - (1 - q)^P - P * q * (1 - q)^(P - 1)
    return (replicas=replicas, P=P, q=q, media=media, media_teorica=P * q,
            p_dos=dos / replicas, p_dos_ic=(lo, hi), p_dos_binomial=pbin)
end

"MC-B · ¿gana la MISMA pieza en dos flujos distintos del mismo slot?"
function mc_misma_pieza(semilla::UInt64, replicas::Int, P::Int, q::Float64)
    interseccion = 0; forzado = 0; al_menos_uno = 0
    for r in 1:replicas
        rng = StableRNG(semilla_replica(semilla, r))
        slot = rand(rng, 1:N_SLOT-1)
        pk = rand(rng, 0:N_PK-1); sector = rand(rng, 0:N_SECTOR-1)
        w0 = IB.ganadores(pk, sector, 0, slot, 0, P, q)
        w1 = IB.ganadores(pk, sector, 0, slot, 1, P, q)
        (isempty(w0) || isempty(w1)) && continue
        al_menos_uno += 1
        p0 = Set(t[1] for t in w0); p1 = Set(t[1] for t in w1)
        !isempty(intersect(p0, p1)) && (interseccion += 1)
        # «forzado»: el atacante NO puede elegir piezas distintas — su única ganadora en
        # cada rama es la MISMA pieza. Es la fracción en que B detecta con certeza.
        (length(w0) == 1 && length(w1) == 1 && w0[1][1] == w1[1][1]) && (forzado += 1)
    end
    lo1, hi1 = wilson(interseccion, al_menos_uno)
    lo2, hi2 = wilson(forzado, al_menos_uno)
    return (replicas=replicas, P=P, q=q, con_ganador_en_ambos=al_menos_uno,
            p_interseccion=interseccion / max(1, al_menos_uno), ic_interseccion=(lo1, hi1),
            p_forzado=forzado / max(1, al_menos_uno), ic_forzado=(lo2, hi2),
            p_interseccion_cota_inferior=1 - (1 - q^2)^P)
end


function mc_dag(semilla::UInt64, replicas::Int, n::Int, lambda::Float64, Delta::Int,
                q::Float64, P::Int, params::GDR.Params; equivoca::Float64=0.0)
    acc = Dict(m => (u2=0, her=0, ru3=0, pag=0, val=0, ident=0) for m in
               (IB.MODO_A, IB.MODO_B, IB.MODO_C))
    nb = 0
    for r in 1:replicas
        rng = StableRNG(semilla_replica(semilla, r))
        especs = IB.dag_honesto(rng, n, lambda, Delta, q, P; equivoca=equivoca)
        length(especs) < 3 && continue
        nb += 1
        for m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
            res = IB.evaluar_rapido(especs, m, params); s = IB.resumen(res)
            a = acc[m]
            acc[m] = (u2=a.u2 + s.u2, her=a.her + s.herencia, ru3=a.ru3 + s.rojo_u3,
                      pag=a.pag + s.pagables, val=a.val + s.validos, ident=a.ident + s.identidades)
        end
    end
    return (replicas=nb, acc=acc)
end

function correr_mc(semilla::UInt64, replicas::Int, params::GDR.Params)
    println("## MC-A · multiplicidad de ganadores por (sector, slot, flujo)")
    println("| P | q | μ=P·q | media medida | P(W≥2) medida | IC95 | P(W≥2) Binomial |")
    println("|---:|---:|---:|---:|---:|---|---:|")
    for (P, q) in ((8, 0.125), (16, 0.0625), (32, 0.03125), (8, 0.25))
        r = mc_multiplicidad(semilla, replicas, P, q)
        println("| ", P, " | ", q, " | ", P * q, " | ", fmt(r.media), " | ", fmt(r.p_dos),
                " | [", fmt(r.p_dos_ic[1]), ", ", fmt(r.p_dos_ic[2]), "] | ",
                fmt(r.p_dos_binomial), " |")
    end
    println()

    println("## MC-B · misma pieza ganadora en dos flujos del mismo slot (lo que B captura y A no)")
    println("La cota inferior supone flujos independientes; la coincidencia de bucket (1/", N_BUCKET,
            ") correlaciona los ganadores y sube la medida.")
    println("| P | q | μ | casos con ganador en ambos | P(intersección) | IC95 | cota inferior | P(forzado: única ganadora y la misma) | IC95 |")
    println("|---:|---:|---:|---:|---:|---|---:|---:|---|")
    for (P, q) in ((1, 0.5), (4, 0.25), (16, 0.0625), (32, 0.03125), (1000, 0.001))
        r = mc_misma_pieza(semilla, replicas, P, q)
        println("| ", P, " | ", q, " | ", P * q, " | ", r.con_ganador_en_ambos, " | ",
                fmt(r.p_interseccion), " | [", fmt(r.ic_interseccion[1]), ", ",
                fmt(r.ic_interseccion[2]), "] | ", fmt(r.p_interseccion_cota_inferior), " | ",
                fmt(r.p_forzado), " | [", fmt(r.ic_forzado[1]), ", ", fmt(r.ic_forzado[2]), "] |")
    end
    println()

    println("## MC-C · DAG honesto, un solo flujo por productor, un bloque por slot")
    for (lambda, Delta, k) in ((1.0, 1, 30), (1.0, 4, 30), (2.0, 4, 30), (1.0, 4, 10))
        p = GDR.Params(k=k)
        r = mc_dag(semilla, replicas, 120, lambda, Delta, 0.0625, 16, p)
        for m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
            a = r.acc[m]
            println("- λ=", lambda, " Δ=", Delta, " k=", k, " · ", m, ": válidos=", a.val,
                    " U2=", a.u2, " herencia=", a.her, " rojo_U3=", a.ru3,
                    " pagables=", a.pag, " identidades=", a.ident)
        end
    end
    println()

    println("## MC-D · productor con dos nodos de vistas divergentes (equivocación honesta)")
    for (lambda, Delta, k) in ((1.0, 1, 30), (1.0, 4, 30), (1.0, 4, 10))
        p = GDR.Params(k=k)
        for eq in (0.05, 0.25, 1.0)
            r = mc_dag(semilla, replicas, 120, lambda, Delta, 0.0625, 16, p; equivoca=eq)
            for m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
                a = r.acc[m]
                println("- P=", 16, " λ=", lambda, " Δ=", Delta, " k=", k, " equivoca=", eq,
                        " · ", m, ": válidos=", a.val, " U2=", a.u2, " herencia=", a.her,
                        " rojo_U3=", a.ru3, " pagables=", a.pag)
            end
        end
    end
end

# ---------------------------------------------------------------------------
# 4 · Entropía
# ---------------------------------------------------------------------------
function correr_entropia()
    _, F = IB.fixtures_canonicos()
    println("| fixture | modo | identidades | copias por identidad | entropías distintas | viola C-FLU-12 |")
    println("|---|---|---:|---|---:|---|")
    for nombre in sort(collect(keys(F))), m in (IB.MODO_A, IB.MODO_B, IB.MODO_C)
        r = IB.evaluar_rapido(F[nombre], m, P0)
        v = IB.violaciones_entropia(r)
        copias = join([string(length(e)) for (_, e) in sort(collect(r.entropias); by=first)], ",")
        distintas = join([string(length(unique(e))) for (_, e) in sort(collect(r.entropias); by=first)], ",")
        println("| ", nombre, " | ", m, " | ", length(r.entropias), " | ", copias, " | ",
                distintas, " | ", isempty(v) ? "no" : "**SÍ**", " |")
    end
end

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
function parsear(args)
    comando = isempty(args) ? "todo" : args[end]
    semilla = nothing; replicas = 200
    i = 1
    while i < length(args)
        if args[i] == "--seed"
            semilla = parse(UInt64, args[i + 1]); i += 2
        elseif args[i] == "--replicas"
            replicas = parse(Int, args[i + 1]); i += 2
        else
            i += 1
        end
    end
    return comando, semilla, replicas
end

function main(args)
    comando, semilla, replicas = parsear(args)
    semilla === nothing && (semilla = UInt64(0x5a5a))
    cabecera(comando, semilla, replicas)
    if comando in ("fixtures", "todo")
        println("# 1 · Fixtures canónicos"); println(); correr_fixtures(); println()
    end
    if comando in ("controles", "todo")
        println("# 2 · Controles"); println(); correr_controles(); println()
    end
    if comando in ("entropia", "todo")
        println("# 3 · Invariante de entropía (C-FLU-12)"); println(); correr_entropia(); println()
    end
    if comando in ("mc", "todo")
        println("# 4 · Monte Carlo"); println(); correr_mc(semilla, replicas, P0); println()
    end
end

main(ARGS)
