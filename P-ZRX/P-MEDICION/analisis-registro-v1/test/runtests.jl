# runtests.jl — V1 (referencia a mano), V2 (percentiles) y V3 (propiedades con StableRNGs)
#
# Se ejecuta desde la raíz del proyecto:
#   JULIA_DEPOT_PATH=<zona>/.julia-depot:/home/katana/.julia \
#     env -u LD_LIBRARY_PATH julia --project=. test/runtests.jl

using Test
using StableRNGs
using JSON3
using Random

include(joinpath(@__DIR__, "..", "src", "analisis_registro_v1.jl"))
using .AnalisisRegistroV1
const AR = AnalisisRegistroV1

const DATOS = joinpath(@__DIR__, "datos")
const SALIDA = mktempdir()

# ----------------------------- helpers de consulta -----------------------------
filas_ent(res, metrica, ambito) =
    [f for f in res.filas_enteras if f.metrica == metrica && f.ambito == ambito]
fila_ent(res, metrica, ambito="todos") = first(filas_ent(res, metrica, ambito))
filas_real(res, metrica, ambito) =
    [f for f in res.filas_reales if f.metrica == metrica && f.ambito == ambito]
fila_real(res, metrica, ambito="todos") = first(filas_real(res, metrica, ambito))
lat(res, a, b) = first(f for f in res.latencias if f.nodo_a == a && f.nodo_b == b)

function eventos_de(lineas::Vector{String})
    pool = AR.PoolCadenas()
    return [AR.crear_evento(JSON3.read(l), i, pool) for (i, l) in enumerate(lineas)]
end
function resumen_dummy(nombre, eventos)
    return AR.ResumenNodo(nombre, "", "", length(eventos), 0, "?", eventos)
end

# ================================================================================
@testset "V2 — percentiles nearest-rank exactos" begin
    for n in (1, 2, 3, 100, 101)
        v = collect(1:n)
        for p in (50, 95, 100)
            r = div(p * n + 99, 100)
            @test AR.percentil_ordenado(v, p) == r
            @test AR.percentil_ordenado_ref(v, p) == r
        end
    end
    @test AR.percentil_ordenado(Int64[], 50) === missing
    @test AR.percentil_ordenado_ref(Int64[], 95) === missing
    # p fuera de (0,100] es error, no se redondea a un percentil válido
    @test_throws ArgumentError AR.percentil_ordenado(collect(1:10), 0)
    @test_throws ArgumentError AR.percentil_ordenado_ref(collect(1:10), 101)
    # n=2, p=50 => rango 1 (no interpolación)
    @test AR.percentil_ordenado(Int64[10, 20], 50) == 10
    # n=2, p=95 => rango 2
    @test AR.percentil_ordenado(Int64[10, 20], 95) == 20
end

# ================================================================================
@testset "V1(a) — 3 nodos, 5 bloques, latencias conocidas" begin
    res = AR.analizar(joinpath(DATOS, "caso-a"), ["P", "Q", "R"];
                      manifest_sha256 = "test")
    @test all(r -> r.version == "v1", res.procedencia.nodos_info)

    f = lat(res, "P", "Q")
    @test (f.producidos, f.admitidos, f.no_admitidos, f.negativos, f.n) == (2, 2, 0, 0, 2)
    @test (f.p50, f.p95, f.max) == (Int64(100), Int64(300), Int64(300))
    f = lat(res, "P", "R")
    @test (f.p50, f.p95, f.max, f.n) == (Int64(200), Int64(400), Int64(400), 2)
    f = lat(res, "Q", "P")
    @test (f.p50, f.p95, f.max, f.n) == (Int64(50), Int64(500), Int64(500), 2)
    f = lat(res, "Q", "R")
    @test (f.p50, f.p95, f.max, f.n) == (Int64(100), Int64(600), Int64(600), 2)
    f = lat(res, "R", "P")
    @test (f.p50, f.p95, f.max, f.n) == (Int64(100), Int64(100), Int64(100), 1)
    f = lat(res, "R", "Q")
    @test (f.p50, f.p95, f.max, f.n) == (Int64(200), Int64(200), Int64(200), 1)

    tot = fila_ent(res, "latencia_propagacion_ns", "total")
    @test (tot.n, tot.p50, tot.p95, tot.max) == (10, Int64(200), Int64(600), Int64(600))

    # etapa de admisión, padres, bloques por slot, fracción de rojos
    ta = fila_ent(res, "t_admision_ns")
    @test (ta.n, ta.ausentes, ta.p50, ta.p95, ta.max) == (10, 0, Int64(100), Int64(100), Int64(100))
    @test length(res.tramos) == 1
    @test (res.tramos[1].desde, res.tramos[1].hasta, res.tramos[1].n, res.tramos[1].p50) == (0, 499, 10, Int64(100))
    pa = fila_ent(res, "padres_por_bloque")
    @test (pa.n, pa.p50, pa.p95, pa.max) == (15, Int64(1), Int64(1), Int64(1))
    bs = fila_ent(res, "bloques_por_slot")
    @test (bs.n, bs.p50, bs.p95, bs.max) == (5, Int64(3), Int64(3), Int64(3))
    fr = fila_real(res, "fraccion_rojos")
    @test fr.n == 1
    @test isapprox(fr.max, 1 / 3; atol = 1e-12)
    @test res.estado_final_igual === missing

    # oráculo independiente
    evs = [AR.leer_registro(joinpath(DATOS, "caso-a", n, "registro.jsonl"), AR.PoolCadenas())[1]
           for n in ("P", "Q", "R")]
    ok_l, det_l = AR.comparar_latencias(evs, ["P", "Q", "R"])
    @test ok_l
    ok_d, det_d = AR.comparar_divergencia(evs, ["P", "Q", "R"])
    @test ok_d
end

# ================================================================================
@testset "V1(b) — un bloque que un nodo no admite" begin
    res = AR.analizar(joinpath(DATOS, "caso-b"), ["P", "Q", "R"])
    f = lat(res, "P", "Q")
    @test (f.producidos, f.admitidos, f.no_admitidos, f.n) == (2, 1, 1, 1)
    @test (f.p50, f.p95, f.max) == (Int64(100), Int64(100), Int64(100))
    f = lat(res, "P", "R")
    @test (f.producidos, f.admitidos, f.no_admitidos, f.n) == (2, 2, 0, 2)
    @test (f.p50, f.p95, f.max) == (Int64(150), Int64(200), Int64(200))
    @test lat(res, "Q", "P").n == 0
end

# ================================================================================
@testset "V1(c) — latencia negativa: se cuenta y entra" begin
    res = AR.analizar(joinpath(DATOS, "caso-c"), ["P", "Q"])
    f = lat(res, "P", "Q")
    @test (f.n, f.negativos, f.p50, f.p95, f.max) == (1, 1, Int64(-100), Int64(-100), Int64(-100))
    tot = fila_ent(res, "latencia_propagacion_ns", "total")
    @test (tot.n, tot.max) == (1, Int64(-100))
end

# ================================================================================
@testset "V1(d) — divergencia de duración conocida con dos cambios de punta" begin
    res = AR.analizar(joinpath(DATOS, "caso-d"), ["P", "Q"])
    @test res.divergencia_medida
    @test isapprox(res.divergencia_fraccion, 600 / 1100; atol = 1e-15)
    @test length(res.convergencia) == 3
    @test (res.convergencia[1].inicio_pared_ns, res.convergencia[1].duracion_ns, res.convergencia[1].truncada) == (100, 200, false)
    @test (res.convergencia[2].inicio_pared_ns, res.convergencia[2].duracion_ns, res.convergencia[2].truncada) == (500, 300, false)
    @test (res.convergencia[3].inicio_pared_ns, res.convergencia[3].duracion_ns, res.convergencia[3].truncada) == (1000, 100, true)
    @test res.estado_final_igual === true
    evs = [AR.leer_registro(joinpath(DATOS, "caso-d", n, "registro.jsonl"), AR.PoolCadenas())[1]
           for n in ("P", "Q")]
    ok, det = AR.comparar_divergencia(evs, ["P", "Q"])
    @test ok
end

# ================================================================================
@testset "V1(e) — última línea truncada (se tolera) y truncada en medio (aborta)" begin
    res = AR.analizar(joinpath(DATOS, "caso-e1"), ["P", "Q"])
    @test res.procedencia.nodos_info[1].truncadas == 1
    @test res.procedencia.nodos_info[1].lineas == 3
    @test lat(res, "P", "Q").p50 == 100

    err = try
        AR.analizar(joinpath(DATOS, "caso-e2"), ["P"])
        nothing
    catch e
        e
    end
    @test err isa AR.ErrorRegistro
    @test err.linea == 2
end

# ================================================================================
@testset "V1(f) — registro v0 sin version_esquema" begin
    res = AR.analizar(joinpath(DATOS, "caso-f"), ["P", "Q"])
    @test all(r -> r.version == "v0", res.procedencia.nodos_info)
    @test lat(res, "P", "Q").p50 == 100
    @test res.divergencia_medida
    @test isapprox(res.divergencia_fraccion, 100 / 900; atol = 1e-15)
    @test length(res.convergencia) == 1
    @test (res.convergencia[1].inicio_pared_ns, res.convergencia[1].duracion_ns, res.convergencia[1].truncada) == (100, 100, false)
    ar = fila_ent(res, "arranque_ns")
    @test (ar.n, ar.p50, ar.p95, ar.max) == (2, Int64(400), Int64(500), Int64(500))
    # v0 no trae tiempos por etapa
    ta = fila_ent(res, "t_admision_ns")
    @test (ta.n, ta.ausentes) == (0, 1)
end

# ================================================================================
@testset "V1(recursos) — CPU/RSS/E-S/disco con CSV sintético" begin
    res = AR.analizar(joinpath(DATOS, "caso-recursos"), ["P", "Q"])
    @test res.procedencia.clk_tck == 100
    cpu = fila_real(res, "cpu_util", "P")
    # deltas: (40-15)/100/1s = 0.25 s/s ; (80-40)/100/1s = 0.40 s/s
    @test (cpu.n, cpu.p50, cpu.p95, cpu.max) == (2, 0.25, 0.40, 0.40)
    rss = fila_ent(res, "rss_kib", "P")
    @test (rss.n, rss.p50, rss.p95, rss.max) == (3, Int64(1500), Int64(2000), Int64(2000))
    rb = fila_ent(res, "read_bytes_intervalo", "P")
    @test (rb.n, rb.p50, rb.p95, rb.max) == (2, Int64(100), Int64(200), Int64(200))
    wb = fila_ent(res, "write_bytes_intervalo", "P")
    @test (wb.n, wb.p50, wb.p95, wb.max) == (2, Int64(50), Int64(100), Int64(100))
    dc = fila_ent(res, "disco_datos_bytes", "P")
    @test (dc.n, dc.max) == (1, Int64(8192))
    # Q no tiene CSV: no hay filas de recursos para Q
    @test isempty(filas_real(res, "cpu_util", "Q"))
end

# ================================================================================
@testset "V1(g) — cobertura v1: tramos de 500, rechazos, reorg y reinicio" begin
    res = AR.analizar(joinpath(DATOS, "caso-g"), ["P"])
    # admisión vs profundidad: tramos [0,499], [500,999], [1000,1499]
    @test length(res.tramos) == 3
    @test (res.tramos[1].desde, res.tramos[1].hasta, res.tramos[1].n, res.tramos[1].p50, res.tramos[1].max) == (0, 499, 1, Int64(10), Int64(10))
    @test (res.tramos[2].desde, res.tramos[2].hasta, res.tramos[2].n, res.tramos[2].p50, res.tramos[2].p95, res.tramos[2].max) == (500, 999, 2, Int64(20), Int64(30), Int64(30))
    @test (res.tramos[3].desde, res.tramos[3].hasta, res.tramos[3].n, res.tramos[3].p50, res.tramos[3].max) == (1000, 1499, 1, Int64(40), Int64(40))
    # tiempos por etapa con los tres campos
    @test fila_ent(res, "t_cabecera_ns").n == 4
    @test fila_ent(res, "t_persistencia_ns").n == 4
    @test fila_ent(res, "t_total_ns").n == 4
    # rechazos por etapa y motivo, con coste
    @test length(res.rechazos) == 2
    r1 = first(f for f in res.rechazos if f.etapa == "cabecera")
    @test (r1.motivo, r1.n, r1.p50, r1.p95, r1.max) == ("m1", 2, Int64(100), Int64(300), Int64(300))
    r2 = first(f for f in res.rechazos if f.etapa == "admision")
    @test isequal((r2.motivo, r2.n, r2.p50), ("m2", 1, missing))
    # profundidad de reorganización (cambio_punta + reorganizacion_pow)
    pr = fila_ent(res, "profundidad_reorg")
    @test (pr.n, pr.p50, pr.p95, pr.max) == (2, Int64(1), Int64(3), Int64(3))
    # duración del reinicio completo
    dr = fila_ent(res, "duracion_reinicio_ns")
    @test (dr.n, dr.p50, dr.p95, dr.max) == (1, Int64(1234), Int64(1234), Int64(1234))
    # recursos v1: bloques por slot / padres / rojos con 4 admitidos
    bs = fila_ent(res, "bloques_por_slot")
    @test (bs.n, bs.p50, bs.max) == (4, Int64(1), Int64(1))
    fr = fila_real(res, "fraccion_rojos")
    @test fr.n == 1 && fr.max == 0.0
    # un solo nodo: latencia y estado final no medidos
    @test isempty(res.latencias)
    @test res.estado_final_igual === missing
end

# ================================================================================
@testset "V3 — propiedades con semilla fija (≥200 casos cada una)" begin
    rng = StableRNG(0x5a5a)
    # (1) permutar las líneas de un nodo no cambia las latencias
    iguales_perm = 0
    for _ in 1:200
        nn = rand(rng, 2:4)
        lineas = [String[] for _ in 1:nn]
        for k in 1:rand(rng, 1:6)
            a = rand(rng, 1:nn)
            t = rand(rng, 1_000:100_000)
            push!(lineas[a], "{\"tipo\":\"bloque_producido\",\"reloj_ns\":$t,\"reloj_pared_ns\":$t,\"hash\":\"h$k\",\"slot\":$k,\"n_padres\":1}")
            for b in 1:nn
                b == a && continue
                if rand(rng, Bool)
                    dt = rand(rng, 1:5_000)
                    push!(lineas[b], "{\"tipo\":\"bloque_red_admitido\",\"reloj_ns\":$(t+dt),\"reloj_pared_ns\":$(t+dt),\"hash\":\"h$k\",\"familia\":\"post\",\"slot\":$k}")
                end
            end
        end
        nombres = ["N$i" for i in 1:nn]
        evs = [eventos_de(lineas[i]) for i in 1:nn]
        nodos = [resumen_dummy(nombres[i], evs[i]) for i in 1:nn]
        f1 = AR.FilaLatencia[]
        AR.calcular_latencias(nodos, f1)
        # se permutan las líneas de cada nodo (no hay cambio_punta en este escenario)
        evs2 = [shuffle!(rng, copy(evs[i])) for i in 1:nn]
        nodos2 = [resumen_dummy(nombres[i], evs2[i]) for i in 1:nn]
        f2 = AR.FilaLatencia[]
        AR.calcular_latencias(nodos2, f2)
        clave(f) = (f.nodo_a, f.nodo_b, f.producidos, f.admitidos, f.no_admitidos,
                    f.negativos, f.n, f.p50, f.p95, f.max)
        c1 = sort([clave(f) for f in f1])
        c2 = sort([clave(f) for f in f2])
        # `isequal` (no `==`): p50/p95/max pueden ser `missing` si no hay muestras
        if isequal(c1, c2)
            iguales_perm += 1
        end
        # oráculo independiente
        ok, _ = AR.comparar_latencias(evs, nombres)
        @test ok
    end
    @test iguales_perm == 200

    # (2) duplicar un nodo idéntico da divergencia 0
    div_cero = 0
    for _ in 1:200
        n = rand(rng, 1:8)
        ts = sort(rand(rng, 0:10_000, n))
        puntas = ["p$(rand(rng, 1:3))" for _ in 1:n]
        lineas = [string("{\"tipo\":\"cambio_punta\",\"reloj_ns\":", ts[i],
                         ",\"reloj_pared_ns\":", ts[i],
                         ",\"punta\":\"", puntas[i],
                         "\",\"resumen_estado\":\"s", rand(rng, 1:3), "\"}")
                  for i in 1:n]
        push!(lineas, "{\"tipo\":\"parada\",\"reloj_ns\":20000,\"reloj_pared_ns\":20000,\"motivo\":\"fin\"}")
        p = eventos_de(lineas)
        q = copy(p)
        nodos = [resumen_dummy("P", p), resumen_dummy("Q", q)]
        frac, eps, medida = AR.calcular_divergencia(nodos)
        if medida && frac == 0.0 && isempty(eps)
            div_cero += 1
        end
        ok, _ = AR.comparar_divergencia([p, q], ["P", "Q"])
        @test ok
    end
    @test div_cero == 200
end

println("runtests.jl: OK")
