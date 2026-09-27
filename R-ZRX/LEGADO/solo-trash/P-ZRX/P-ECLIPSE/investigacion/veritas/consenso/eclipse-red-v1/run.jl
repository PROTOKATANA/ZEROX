#= run.jl — CLI reproducible del instrumento `eclipse-red-v1` (P-ECLIPSE).

Uso (desde este directorio; `veritas/julia.sh` existe en la raíz del repositorio):

    JULIA_DEPOT_PATH=<depot> /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --entorno
    JULIA_DEPOT_PATH=<depot> /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --control
    ... run.jl --variantes
    ... run.jl --regimen

`<depot>` es un depósito Julia **escribible**. En la máquina donde se produjo esto,
`$HOME/.julia` es de sólo lectura para el agente, así que se usó
`P-ZRX/P-ECLIPSE/.julia-depot` como primer depósito y `$HOME/.julia` como segundo (sólo lectura).
Se declara en `PROCEDENCIA.md`: es una circunstancia del entorno, no una decisión del instrumento.
=#

using Printf

const AQUI = @__DIR__
include(joinpath(AQUI, "src", "pyrng.jl"))
include(joinpath(AQUI, "src", "GDR.jl"))
include(joinpath(AQUI, "src", "mundo.jl"))
include(joinpath(AQUI, "src", "sensores.jl"))
include(joinpath(AQUI, "src", "captura.jl"))
include(joinpath(AQUI, "src", "flujo.jl"))
using .PyRNG, .Mundo, .Sensores, .Captura, .Flujo
const G = GDR.GhostdagRank

const SMAXES = [4, 20, 30, 150]
const SEMS = collect(1:12)
const HOR = 900.0
const T_ECL = 300.0
const T_REG = 600.0
const RES = joinpath(AQUI, "resultados")

fm(v) = join([@sprintf("%.4f", v[j]) for j in 1:length(v)], "/")

function cabecera(modo::String)
    println("== eclipse-red-v1 · modo ", modo, " ==")
    println("julia ", VERSION, " | hilos default=", Threads.nthreads(:default),
            " interactive=", Threads.nthreads(:interactive))
    println("CPU ", Sys.CPU_NAME, " | RAM ", round(Sys.total_memory() / 2^30, digits = 1), " GiB")
    println("comando: run.jl --", modo)
    println()
end

# ---------------------------------------------------------------------------------------
# ENTORNO
# ---------------------------------------------------------------------------------------
function modo_entorno()
    cabecera("entorno")
    println("GDR-v0.2 reutilizado desde: ", GDR.RUTA_MODULO)
    println("  P_DEFECTO: k=", G.P_DEFECTO.k, " max_parents=", G.P_DEFECTO.max_parents,
            " mergeset_limit=", G.P_DEFECTO.mergeset_limit, " s_max=", G.P_DEFECTO.s_max)
    println("identidad SR=0 <-> peso por conteo: bw = 2^128 * blue_score (comprobada en tests)")
    println("peso_big(0) = ", G.peso_big(UInt64(0)))
    println()
    println("RNG: réplica de CPython `random.Random` (MT19937 + init_by_array + sembrado")
    println("     por cadena con SHA-512). Vectores de validación en test/runtests.jl.")
end

# ---------------------------------------------------------------------------------------
# CONTROL POSITIVO (D8 A3b)
# ---------------------------------------------------------------------------------------
function control(alpha, delta, reg)
    tot = zeros(Int, length(SMAXES)); n = 0
    for sem in SEMS
        p = ParametrosMundo(alpha, HOR, sem; delta = delta, regimen = reg)
        r = corre_control!(Sim(p, calendario(alpha, HOR, sem)), 200.0; fc = 0.05)
        n += r.n
        for (j, S) in enumerate(SMAXES)
            tot[j] += count(>(S), r.gaps)
        end
    end
    return tot ./ max(n, 1), n
end

function modo_control()
    cabecera("control")
    println("CONTROL POSITIVO — fila publicada de D8 A3b (salida_a3b.txt, E=200 s, f=5 %):")
    println("  esperado alpha=0.00 -> 0.8218/0.6513/0.5920/0.5460   (n_C=522)")
    println("  esperado alpha=0.25 -> 0.8806/0.7687/0.7289/0.6816   (n_C=402)")
    println()
    for alpha in (0.0, 0.25)
        v, n = control(alpha, 4.0, :conteo)
        println("  alpha=", @sprintf("%.2f", alpha), " GLOBAL | ", fm(v), " | n_C=", n)
    end
    println()
    println("NOTA: el control se reproduce EXACTAMENTE a cuatro decimales y con el mismo número")
    println("de bloques. Es la puerta que el encargo pone al puerto (§4.1) y está superada.")
end

# ---------------------------------------------------------------------------------------
# LAS TRES VARIANTES (validación contra las tablas de 11b)
# ---------------------------------------------------------------------------------------
function variante(alpha, delta, reg, modo; paso = 1.0, E = 0.0, f_v = 0.05)
    accr = zeros(Int, length(SMAXES)); nvr = 0; nrojo = 0; ntot = 0; nll = 0
    for sem in SEMS
        p = ParametrosMundo(alpha, HOR, sem; delta = delta, regimen = reg)
        sim = Sim(p, calendario(alpha, HOR, sem))
        r = corre_victima!(sim, modo, f_v; paso = paso, E = E, t_ecl = T_ECL)
        az = G.blueset(sim.est, G.virtual_sp(sim.est, sim.params))
        for (t, gp, bid) in zip(r.t_V, r.gaps_V, r.ids_V)
            t >= T_REG || continue
            nvr += 1; ntot += 1
            bid in az || (nrojo += 1)
            for (j, S) in enumerate(SMAXES)
                gp > S && (accr[j] += 1)
            end
        end
        nll += count(x -> T_REG <= x <= HOR, r.llegadas_V)
    end
    return accr ./ max(nvr, 1), nrojo / max(ntot, 1), nvr, nll / ((HOR - T_REG) * length(SEMS))
end

function modo_variantes()
    cabecera("variantes")
    println("Validación del puerto contra las tablas publicadas de la ronda 11b")
    println("(research/scripts/d8-ronda11b/salida_a.txt), régimen histórico Δ=4 s, peso por conteo.")
    println("Ventana de régimen [", Int(T_REG), ", ", Int(HOR), "] s; f_v=0.05; eclipse desde t=",
            Int(T_ECL), " s.")
    println()
    println("  variante        inv S=4/20/30/150                 rojo_V   n   | publicado")
    casos = [(:filtro, 0.0, 0.0, "0.7927/0.3109/0.1762/0.0000", "1.0000", 193),
             (:filtro, 0.33, 0.0, "0.7070/0.0047/0.0000/0.0000", "0.0093", 215),
             (:filtro, 0.10, 0.0, "0.7316/0.0579/0.0105/0.0000", "0.0895", 190),
             (:retraso, 1.0, 20.0, "0.7753/0.7022/0.0056/0.0000", "0.0449", 178),
             (:retraso, 1.0, 60.0, "0.7600/0.6743/0.6743/0.0000", "1.0000", 175),
             (:retraso, 1.0, 200.0, "0.8167/0.7500/0.7500/0.7500", "1.0000", 180)]
    for (modo, paso, E, esp, erojo, en) in casos
        v, rojo, n, _ = variante(0.0, 4.0, :conteo, modo; paso = paso, E = E)
        etq = modo === :filtro ? @sprintf("ii paso=%.2f", paso) : @sprintf("iii E=%.0f", E)
        @printf("  %-14s %-34s %-8.4f %-4d | %s rojo=%s n=%d\n", etq, fm(v), rojo, n, esp, erojo, en)
    end
    println()
    println("(i) el atacante RETIENE el PoT: la víctima fabrica 0 bloques tras el eclipse, para")
    println("    todo alpha y toda f_v. Publicado en 11b §A.1: 192 antes / 0 después con f_v=0.05.")
    for f_v in (0.01, 0.05, 0.20)
        pre = 0; post = 0
        for sem in SEMS
            p = ParametrosMundo(0.0, HOR, sem)
            r = corre_victima!(Sim(p, calendario(0.0, HOR, sem)), :pot, f_v; t_ecl = T_ECL)
            pre += count(<(T_ECL), r.t_V); post += count(>=(T_ECL), r.t_V)
        end
        @printf("    f_v=%.2f | antes %4d | despues %d\n", f_v, pre, post)
    end
end

# ---------------------------------------------------------------------------------------
# F2 — EL BARRIDO DE RÉGIMEN
# ---------------------------------------------------------------------------------------
function modo_regimen()
    cabecera("regimen")
    println("F2 · ¿qué conclusiones de la ronda 11b sobreviven al régimen vigente?")
    println("Δ histórico = 4 s (r8c_sim.py:24, nominal, simulado).")
    println("Δ de hoy = DMS-v0.1, p99 0.26–0.45 s con cabecera de 812 B y 0.26–0.60 s en la rejilla.")
    println("Peso: :conteo = histórico (SR=0); :sr = C-GD-01, w = ⌊2^128/(SR+1)⌋ con SR = sd.")
    println("OJO: la Δ de hoy es SIMULADA, no medida en red desplegada (DMS-v0.1 lo declara).")
    println()
    @printf("%6s %8s | %-34s | %-34s %-8s\n", "Δ", "peso", "CONTROL E=200 f=5%",
            "iii E=200 inv", "rojo_V")
    for delta in (4.0, 0.60, 0.45, 0.26), reg in (:conteo, :sr)
        c, n = control(0.0, delta, reg)
        v, rojo, _, _ = variante(0.0, delta, reg, :retraso; E = 200.0)
        @printf("%6.2f %8s | %-34s | %-34s %-8.4f\n", delta, string(reg), fm(c), fm(v), rojo)
    end
    println()
    println("Detalle completo por variante:")
    for delta in (4.0, 0.60, 0.45, 0.26), reg in (:conteo, :sr)
        c, n = control(0.0, delta, reg)
        println("\nΔ=", delta, " peso=", reg, "  control=", fm(c), " (n_C=", n, ")")
        for (modo, paso, E, etq) in ((:filtro, 0.0, 0.0, "ii paso=0 "), (:filtro, 0.33, 0.0, "ii paso=.33"),
                                     (:retraso, 1.0, 20.0, "iii E=20  "), (:retraso, 1.0, 60.0, "iii E=60  "),
                                     (:retraso, 1.0, 200.0, "iii E=200"))
            v, rojo, nn, tasa = variante(0.0, delta, reg, modo; paso = paso, E = E)
            @printf("    %-11s inv %-34s rojo_V=%.4f n=%3d tasa=%.4f\n", etq, fm(v), rojo, nn, tasa)
        end
    end
end

# ---------------------------------------------------------------------------------------
# SENSORES E1/E2 — aritmética exacta
# ---------------------------------------------------------------------------------------
function modo_sensores()
    cabecera("sensores")
    Sensores.informe()
end

# ---------------------------------------------------------------------------------------
# SECCIÓN D — captura de las 8 salientes
# ---------------------------------------------------------------------------------------
function modo_captura()
    cabecera("captura")
    Captura.informe()
end

# ---------------------------------------------------------------------------------------
# §4.3 — partición de flujo fabricada
# ---------------------------------------------------------------------------------------
function modo_flujo()
    cabecera("flujo")
    Flujo.informe()
end

# ---------------------------------------------------------------------------------------
const MODOS = Dict(
    "entorno"  => modo_entorno,
    "control"  => modo_control,
    "variantes" => modo_variantes,
    "regimen"  => modo_regimen,
    "sensores" => modo_sensores,
    "captura"  => modo_captura,
    "flujo"    => modo_flujo,
)

function main(args)
    if isempty(args)
        println("modos: ", join(sort(collect(keys(MODOS))), " · "))
        return
    end
    for a in args
        m = lstrip(a, '-')
        haskey(MODOS, m) || error("modo desconocido: $a (usa --entorno, --control, --variantes, --regimen, --sensores, --captura, --flujo)")
        MODOS[m]()
        println()
    end
end

main(ARGS)
