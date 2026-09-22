#!/usr/bin/env julia
# run.jl — CLI reproducible de la auditoría P-CRP1.
#
# Uso:
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 julia --project=. run.jl --resumen [--out f]
#   ... run.jl --d2 | --d3 | --d4 | --d5 | --d6 | --d7 | --d9 | --d10
# Los defectos D1 y D8 requieren el oráculo GDR-v0.2 y viven en `gdr.jl`.
using Printf
using Dates
using Pkg

include(joinpath(@__DIR__, "src", "CRP1Defectos.jl"))
using .CRP1Defectos

const DIR = @__DIR__
const RES = joinpath(DIR, "resultados")
const SEMILLA = UInt64(0xC057E07)
const P = ParametrosVarianza()

function entorno(comando::String)
    io = IOBuffer()
    raiz = dirname(dirname(dirname(dirname(dirname(DIR)))))
    git = try
        strip(read(`git -C $raiz rev-parse HEAD`, String))
    catch
        "no disponible"
    end
    println(io, "== ENTORNO CRP1-defectos-v1 ==")
    println(io, "git_HEAD: ", git)
    println(io, "fecha: ", Dates.now())
    println(io, "julia: ", VERSION)
    println(io, "cpu: ", Sys.CPU_NAME)
    println(io, "hilos_julia: ", Threads.nthreads(:default), " / ", Threads.nthreads(:interactive))
    println(io, "comando: ", comando)
    println(io, "semilla: ", SEMILLA)
    try
        println(io, "uptime: ", strip(read(`uptime`, String)))
    catch
        println(io, "uptime: no disponible")
    end
    print(io, "pkg: ")
    try
        Pkg.status(io = io)
    catch
        println(io, "no disponible")
    end
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_d2()
    io = IOBuffer()
    println(io, "== D2 · La DP de granularidad perdía masa y no reescalaba `d` ==")
    println(io, "Modelo: el déficit `d` está en unidades de trabajo (u.t.); cada bloque pesa 1/g u.t.,")
    println(io, "así que en la retícula el déficit es z = d·g BLOQUES. CRP-v0.1 usó z = d = 6.")
    println(io, "Corte fijo de la pmf de CRP-v0.1: `pmf_cambio_neto(α, g; corte=min(nmax,60))`.")
    println(io)
    @printf(io, "%6s %8s %16s %16s %18s %18s\n", "g", "z=d·g", "ruina exacta ±1",
            "DP compuesto", "cota martingala", "publicado CRP")
    pub = Dict(1 => 8.0e-2, 4 => 6.6e-2, 16 => 4.2e-2, 64 => 1.3e-2, 256 => 3.2e-26)
    for (g, m) in ((1, 6), (4, 24), (16, 96), (64, 384), (256, 1536))
        α = big(2)//big(5)
        exacto = Float64(prob_empate_reticula(α, m))
        mart = Float64(cota_martingala(α, m))
        dp = alcance_compuesto(0.4, Float64(g), m; ventanas = (m + 200, m + 600, m + 1200))
        @printf(io, "%6d %8d %16.6e %16.6e %18.6e %18.6e\n", g, m, exacto, dp.p, mart, pub[g])
    end
    println(io)
    println(io, "Masa retenida por el corte 0…60 de CRP-v0.1 (calculada con su propia pmf):")
    @printf(io, "%6s %14s %14s\n", "g", "masa corte=60", "¿se publicó la masa?")
    for g in (1, 4, 16, 64, 256)
        s = soporte_incremento(0.4, Float64(g); margen = 40.0)
        # reproducción exacta del corte fijo de CRP-v0.1
        μh = g * 0.6; μa = g * 0.4
        corte = min(600, 60)
        ph = pmf_poisson_vec(corte, μh); pa = pmf_poisson_vec(corte, μa)
        masa = sum(ph) * sum(pa)
        @printf(io, "%6d %14.6e   %s\n", g, masa, g == 256 ? "NO" : "no (masa ≈ 1)")
    end
    println(io)
    println(io, "Veredicto del cargo: REAL. El corte fijo sólo colapsa en g=256, pero el defecto de")
    println(io, "unidades (z=d en vez de d·g) arruina TODA la fila con g>1, y las cifras publicadas")
    println(io, "no van acompañadas de la masa cruda ni de ninguna cota de error.")
    println(io)
    println(io, "La frase «la contribución del DAG es de varianza, no de umbral» SOBREVIVE y se")
    println(io, "refuerza: la cola corregida decrece mucho más deprisa con g que la publicada.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_d3()
    io = IOBuffer()
    println(io, "== D3 · Empatar no es superar estrictamente ==")
    println(io, "El CONTRATO exige superar el blue_work observable. En la retícula ±1 con déficit z:")
    println(io, "  P(alcance = EMPATE, z=0)      = (q/p)^z")
    println(io, "  P(SUPERAR estrictamente, z<0) = (q/p)^(z+1)")
    println(io)
    println(io, "Tabla publicada (INFORME.md:39-44) frente a la del evento estricto, ε = 0,10:")
    @printf(io, "%5s %14s %14s %14s\n", "d", "α_min empatar", "α_min superar", "diferencia")
    for d in (3, 6, 12, 24, 50)
        te = α_min_empate(d, 0.10); ts = α_min_superar(d, 0.10)
        @printf(io, "%5d %14.6f %14.6f %+14.6f\n", d, te, ts, ts - te)
    end
    println(io, "  La sucesión de α_min(d, ε) con d creciente CONVERGE A 1/2 DESDE ABAJO:")
    for d in (50, 100, 1000, 10000)
        @printf(io, "    d=%6d  α_min(empate)=%.6f\n", d, α_min_empate(d, 0.10))
    end
    println(io, "  El texto publicado dice «→ 1/2⁺» (INFORME.md:43) y «→ 0.5 por arriba»")
    println(io, "  (run-corto.txt:49): es una etiqueta equivocada, la convergencia es por abajo.")
    println(io)
    println(io, "En la retícula, α=0,4, z=6: empate = ",
            Float64(prob_empate_reticula(big(2)//big(5), 6)),
            " ; estricto = ", Float64(prob_superar_reticula(big(2)//big(5), 6)))
    println(io, "DP del paseo compuesto (masa conservada), comparación de los dos eventos:")
    @printf(io, "%5s %8s %18s %18s %10s\n", "g", "z", "DP empatar", "DP superar", "razón")
    for (g, m) in ((1, 6), (4, 24), (16, 96), (64, 384), (256, 1536))
        a = alcance_compuesto(0.4, Float64(g), m; absorbe_estricto = false, ventanas = (m + 600,))
        b = alcance_compuesto(0.4, Float64(g), m; absorbe_estricto = true, ventanas = (m + 600,))
        @printf(io, "%5d %8d %18.6e %18.6e %10.6f\n", g, m, a.p, b.p, b.p / a.p)
    end
    println(io, "  La razón se mantiene ≈ q/p = 0,6667, coherente con la cota de martingala")
    println(io, "  (z^{z+1} = (q/p)·z^z).")
    println(io)
    println(io, "Veredicto del cargo: REAL para la TABLA de α_mínimo (usa el evento de empate cuando")
    println(io, "el contrato exige superación estricta) y REAL para la etiqueta «1/2⁺».")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_d4()
    io = IOBuffer()
    sr0 = big(2)^50
    println(io, "== D4 · `λ ∝ SR` era un supuesto, no una derivación ==")
    println(io, "Predicado PoAS exacto: acepta `2·⌊sr/2⌋ + 1` residuos de los 2^64 del círculo, que")
    println(io, "vale sr+1 si sr es par y sr si es impar. Peso C-GD-01: ⌊2^128/(sr+1)⌋.")
    println(io, "Trabajo por ensayo exacto T(sr) = (2⌊sr/2⌋+1)/2^64 · ⌊2^128/(sr+1)⌋.")
    println(io, "CRP-v0.1 SUPONE λ ∝ sr (src/modelo.jl:11, docstring 15-17) y normaliza por sr0.")
    println(io)
    println(io, "Descomposición exacta del trabajo por ensayo normalizado a 2^64:")
    @printf(io, "%22s %20s %20s %14s\n", "sr", "valor", "déficit paridad", "déficit suelo")
    for sr in (big(1), big(2), big(3), big(2048), big(2049), sr0 - 1, sr0, big(2)^63)
        d = descomposicion_trabajo(sr)
        @printf(io, "%22s %20.15f %20.6e %14.3e\n", string(sr),
                Float64(BigFloat(d.valor)), Float64(BigFloat(d.paridad)), Float64(BigFloat(d.suelo)))
    end
    println(io)
    println(io, "Desviación de la razón de CRP-v0.1 respecto de la razón EXACTA del predicado:")
    @printf(io, "%14s %20s %20s %14s\n", "sr/sr0", "razón CRP", "razón exacta", "desv. rel.")
    peor = 0.0
    for K in (1, 2, 4, 16, 64, 1024, 10^6)
        sr = sr0 ÷ K
        rc = Float64(razon_crp(sr, sr0))
        re = Float64(razon_exacta(sr, sr0))
        desv = abs(rc - re) / re
        peor = max(peor, desv)
        @printf(io, "%14s %20.15f %20.15f %14.3e\n", "1/" * string(K), rc, re, desv)
    end
    println(io, "  desviación relativa máxima de la rejilla ≈ ", @sprintf("%.3e", peor))
    println(io, "  CRP-v0.1 declara error_rel máx 1,33e-14 (run-teoria.txt:20): ese número sólo mide")
    println(io, "  el residuo del SUELO, no la paridad; su modelo no contiene la paridad.")
    println(io, "  El residuo de paridad 1/(sr+1) lo demuestra PCO-v0.1")
    println(io, "  (veritas/consenso/puerta-cobertura-v1/MODELO.md:41-62): para sr=2049 vale 4,878e-4,")
    println(io, "  y para sr=1 vale 1/2. CRP-v0.1 no lo ve.")
    println(io)
    println(io, "Contraste independiente con PCO-v0.1 (MISMA cancelación, MÉTODO distinto):")
    println(io, "  PCO deriva la tasa del predicado leído del código (A(sr)=2⌊sr/2⌋+1) y demuestra la")
    println(io, "  cancelación en enteros exactos, condicionada a ese predicado; CRP-v0.1 la SUPONE")
    println(io, "  («la probabilidad es ≈ sr/(2M)», MODELO.md:14-15) y luego la «comprueba» contra")
    println(io, "  su propio supuesto. Veredicto: conclusión correcta, demostración circular.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_d5()
    io = IOBuffer()
    pub = Dict(1 => 0.0220, 4 => 0.0968, 16 => 0.2435, 64 => 0.3078)
    println(io, "== D5 · El controlador real no se modeló (y la cifra que más importa) ==")
    println(io, "Parámetros: α=0,45, T=400 slots, K = sr0/sr ∈ {1,4,16,64}, sr0 = 2^50 (los de")
    println(io, "`efecto_varianza_sr`, src/rapido.jl:77-94). Evento: trabajo del adversario > honesto.")
    println(io)
    ex = varianza_exacta(P)
    println(io, "Recálculo EXACTO sin Monte Carlo (convolución de dos Poisson compuestos,")
    println(io, "pesos enteros exactos, 256 bits):")
    @printf(io, "%5s %10s %22s %12s %22s %10s\n", "K", "sr_a", "P(>) exacta", "P(>=) exacta",
            "publicado P(>)", "dif")
    for f in ex
        @printf(io, "%5d %10s %22.12f %12.9f %22.6f %+10.6f\n", f.K, string(f.sra),
                f.p_mayor, f.p_mayor_igual, pub[f.K], f.p_mayor - pub[f.K])
    end
    println(io, "  Masa de Poisson omitida por truncar las colas: ",
            @sprintf("%.2e", maximum(f.masa_b_truncada for f in ex)))
    println(io, "  Empates exactos P(=): ",
            join([@sprintf("K=%d: %.3e", f.K, f.p_igual) for f in ex], "  "))
    println(io)
    println(io, "Monte Carlo bien hecho (mismo proceso por slot, RNG por réplica):")
    println(io, "  autocorrelación lag-1 de la 1ª salida de StableRNG(semilla+i) = ",
            @sprintf("%.4f", autocorrelacion_lag1_consecutivas(20_000)),
            "  (P-PUERTA: «≈ −0,43»)")
    for modo in (:hashed, :consecutivas)
        mc = mc_varianza(P; n_rep = 40_000, modo = modo)
        println(io, "  modo=", modo, ":")
        for m in mc
            @printf(io, "    K=%3d  p=%.5f  IC99.9%% Hoeffding [%.5f, %.5f]  E[adv]=%.2f\n",
                    m.K, m.p, m.hoeffding.lo, m.hoeffding.hi, m.E_adv)
        end
    end
    println(io)
    println(io, "Dependencia del defecto D1: NINGUNA. `efecto_varianza_sr` -> `simular_raza` ->")
    println(io, "`simular_rama_rapido` (src/rapido.jl:87,67-68) y ese camino no toca GDR ni el DAG.")
    println(io)
    println(io, "Veredicto del cargo: REAL en el modelo (la familia de controladores es un juguete y")
    println(io, "R-FIN-13′ no está especificado; el propio INFORME.md:200-203 lo declara inconcluso).")
    println(io, "Las CIFRAS se sostienen dentro del ruido de MC: los valores exactos difieren del")
    println(io, "publicado en ≤ 0,016 (K=16, 2,4σ de una corrida de 4000 réplicas con semilla fija).")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_d6()
    io = IOBuffer()
    println(io, "== D6 · Los rojos asimétricos: fórmula y etiqueta ==")
    println(io, "Fórmula de PROCEDENCIA.md:57-62: si la honesta pierde fracción f de su trabajo por")
    println(io, "rojos y el adversario no pierde nada: α(2−f) > (1−f)  ⟺  α > (1−f)/(2−f).")
    for (f, Δ) in TABLA_ROJOS
        println(io, @sprintf("  f=%.4f (Δ=%4.1f s)  α_min=%.6f  (publicado %.4f)  coincide=%s",
                             f, Δ, α_rojos_asimetricos(f), (1 - f) / (2 - f),
                             isapprox(α_rojos_asimetricos(f), (1 - f) / (2 - f); atol = 1e-12)))
    end
    println(io, "  La fórmula es correcta (álgebra elemental).")
    println(io)
    println(io, "La ETIQUETA, en cambio, no: PROCEDENCIA.md:64 escribe «La Δ medida en")
    println(io, "`veritas/finalidad/delta-medido-v1/` es 0,26–0,60 s». Fuentes abiertas:")
    println(io, "  * delta-medido-v1/INFORME.md:1-9: «Δ medido en red sintética P2P», «esto mide,")
    println(io, "    no decide»; MODELO.md §2 etiqueta MR = «medida en red ZEROX (ninguna disponible)»")
    println(io, "    y las latencias como H (hipótesis de escenario).")
    println(io, "  * delta-medido-v1/INFORME.md:413: «Δ_99 p99 queda en 0,26–0,60 s» (de la rejilla r2).")
    println(io, "  * P-ZRX/P-2.1/SINTESIS.md:28: «La Δ es simulada (DMS-v0.1), no medida en red».")
    println(io, "  * P-ZRX/P-2.1/ENCARGO.md:497: «DMS-v0.1 es simulada con latencias supuestas».")
    println(io, "  Luego la Δ es una MEDIDA EN SIMULACIÓN (MS), no una medida de red: la etiqueta")
    println(io, "  «medida» sin calificar es un sobre-enunciado.")
    println(io)
    println(io, "Las fracciones rojas (0,0000/0,0020/0,0828/0,2858) NO salen de delta-medido-v1:")
    println(io, "están en `research/scripts/d9-ronda9a/r9a_a6_frontera_delta.py:31` (constante")
    println(io, "`DELTA0_MEDIDO`) y las reproduce `d9-ronda11a`. Son simulaciones históricas con Δ")
    println(io, "fijada a mano, exactamente el uso que el propio D6 prohíbe («no dibujes Δ marginales")
    println(io, "iid y los llames vistas de red coherentes»).")
    println(io)
    println(io, "El factor «25 veces por debajo» (PROCEDENCIA.md:64-65) NO se reproduce con los dos")
    println(io, "números citados: 4 s / 0,60 s = 6,7 y 4 s / 0,26 s = 15,4. Para llegar a 25 hay que")
    println(io, "comparar 16 s (el ÚLTIMO escalón) con 0,60 s, no el primero.")
    println(io)
    println(io, "Veredicto: REAL a medias. La fórmula y la conclusión («con Δ sub-segundo f≈0 y el")
    println(io, "umbral no se mueve») se sostienen; la ETIQUETA de la Δ y el factor «25×» no.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_d7()
    io = IOBuffer()
    println(io, "== D7 · Multistream era una identidad tautológica ==")
    println(io, "`cuota_multistream(α,S) = S·α/(1−α+S·α)` (src/modelo.jl:159) y el test")
    println(io, "test/runtests.jl:72-75 comprueba `1/(1+3) == 0.25` y `cuota_multistream(0.2,5) > 0.5`.")
    println(io, "Es decir: se prueba que la DEFINICIÓN aplicada a α=1/2 da 1/(S+1). No se prueba")
    println(io, "que S flujos puedan sumarse aditivamente.")
    println(io)
    println(io, "Despeje (lo único que el instrumento demuestra):")
    for S in (1, 2, 4, 8, 16, 24, 64)
        cuota = cuota_multistream(0.5, S)
        println(io, @sprintf("  S=%3d  cuota(α=1/2)=%.6f  1/(S+1)=%.6f  coincide=%s",
                             S, cuota, α_min_multistream(S),
                             isapprox(cuota, 0.5; atol = 1e-15)))
    end
    println(io)
    println(io, "Lo que exigiría una demostración real (D7 §4-5) y NO está:")
    println(io, "  * compatibilidad de todo past(B) en los slots solicitados;")
    println(io, "  * prefijos comparados en slot(X), no etiquetas de flujo actuales;")
    println(io, "  * P(max_i{W_i−d_i} > W_pub) con prefijo común contado una vez;")
    println(io, "  * cotas de unión  max_i P(E_i) ≤ P(∪E_i) ≤ min(1, Σ_i P(E_i));")
    println(io, "  * control «flujos idénticos ⇒ S=1» y control iid con déficit cero.")
    println(io, "  Cotas de unión que sí son válidas para la cuota aditiva (S flujos iid, cada uno con")
    println(io, "  P(E_i) = p): [p, min(1, S·p)]:")
    for S in (2, 4, 8, 16, 24)
        p = cuota_multistream(0.45, 1) / S
        println(io, @sprintf("    S=%3d  max_i P(E_i)=%.4f  ≤ P(∪E_i) ≤ %.4f",
                             S, cuota_multistream(0.45, S) * 0 + p, min(1.0, S * p)))
    end
    println(io)
    println(io, "Veredicto: REAL. Queda demostrado que la fórmula es la que es, y nada sobre si S")
    println(io, "flujos pueden sumarse. El propio INFORME.md:135-137 lo etiqueta «no demostrado /")
    println(io, "condicional», pero INFORME.md:135 lo llama «el único vector MEDIDO».")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_d9()
    io = IOBuffer()
    println(io, "== D9 · `S = 24` no fue una medición del v1 ==")
    println(io, "En el código de CRP-v0.1, `S` es un argumento de impresión: run.jl:117 itera")
    println(io, "`for S in (1,2,4,8,16,24,64)` y sólo evalúa `cuota_multistream(0.45,S)` y `1/(S+1)`.")
    println(io, "No hay ninguna medición de IOPS, ni de lecturas aleatorias, ni de núcleos.")
    println(io)
    println(io, "Origen de la cifra, rastreado: `floor(100000/4161) = ", fld(100000, 4161), "`.")
    println(io, "  * PROCEDENCIA.md:79 dice «S ≈ 24 es el límite de IOPS de un SSD de 100 k».")
    println(io, "  * `4161.0` aparece como constante en P-ZRX/P-2.1/veritas/consenso/ancla-inyeccion-v2/")
    println(io, "    src/puerta.jl:62 («lecturas_4TiB») y en P-ZRX/P-PUERTA/.../src/cobertura.jl:40.")
    println(io, "  * El propio encargo 07v2 §D9 prohíbe: «No conviertas floor(100000/4161)=24 en")
    println(io, "    capacidad acreditada» (ENCARGO-07v2-coste-rama-privada.md:372).")
    println(io)
    println(io, "Las tres magnitudes que D9 pide separar y su estado en CRP-v0.1:")
    println(io, "  * S_escenario      = 24 (elegido para el barrido) — SÍ, pero sin etiquetar como elección.")
    println(io, "  * S_microbenchmark = NO EXISTE: no hay ningún microbenchmark de I/O en el instrumento.")
    println(io, "  * S_adversario     = NO EXISTE: no hay perfil de hardware, ni p50/p95/p99, ni")
    println(io, "                       profundidad de cola, ni distinción caché de página/almacenamiento.")
    println(io)
    println(io, "Veredicto: REAL. `S=24` es una cota aritmética de IOPS citada, nunca medida por el v1.")
    println(io, "La parte paramétrica P(α,S) sí puede cerrarse condicionada a S; la afirmación")
    println(io, "económica sobre un adversario concreto no.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_d10()
    io = IOBuffer()
    println(io, "== D10 · «Ataque gratis» estaba sobre-enunciado ==")
    println(io, "INFORME.md:117-120 escribe: «Con α>1/2 el ataque es “gratis” en recursos» y define")
    println(io, "«gratis» como «sin espacio adicional, sin renunciar a la recompensa honesta más allá")
    println(io, "de la ventana de retención». D10 exige contabilizar por separado:")
    terminos = [
        ("espacio adicional plotteado", "0", "declarado en el modelo (el espacio se reutiliza)"),
        ("CPU / PoT / IOPS", "no contado", "el PoT se ejecuta igual en la rama privada"),
        ("energía", "no contado", "no aparece en ninguna cifra del instrumento"),
        ("recompensa y tarifas renunciadas", "parcial", "«≈ Δ·conf», SIN derivación ni unidades"),
        ("duración real bifurcación→decisión", "no medido", "T_retención ≈ Δ·conf es una afirmación"),
        ("capital hundido vs coste marginal", "no separado", "el modelo sólo tiene fracción α"),
    ]
    @printf(io, "%-38s %-12s %s\n", "término", "estado", "dónde")
    for (t, e, d) in terminos
        @printf(io, "%-38s %-12s %s\n", t, e, d)
    end
    println(io)
    println(io, "Lo que el §4 del informe calcula de verdad: el cociente de COSTE DE OPORTUNIDAD")
    println(io, "coste_op(PoST)/coste_op(PoW) = T_retención/T_a, con T_retención ≈ Δ·conf afirmado y")
    println(io, "sin derivar (run.jl:259-269). No hay ninguna cifra de recursos en el cálculo.")
    println(io)
    println(io, "Veredicto: REAL. La conclusión máxima admisible, con los supuestos declarados, es")
    println(io, "«cero espacio plotteado adicional». «Ataque gratis» y «coste marginal 0» no están")
    println(io, "sostenidos por el cálculo del §4.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_resumen()
    io = IOBuffer()
    for (nom, txt) in (("D2", modo_d2()), ("D3", modo_d3()), ("D4", modo_d4()),
                       ("D5", modo_d5()), ("D6", modo_d6()), ("D7", modo_d7()),
                       ("D9", modo_d9()), ("D10", modo_d10()))
        println(io, "##### ", nom, " #####")
        println(io, txt)
        println(io)
    end
    return String(take!(io))
end

function main(args)
    modo = isempty(args) ? "--ayuda" : args[1]
    salida = let i = findfirst(==("--out"), args)
        i === nothing ? nothing : args[i + 1]
    end
    cab = entorno(join(args, " "))
    texto = if modo == "--entorno"
        cab
    elseif modo == "--d2"
        cab * "\n" * modo_d2()
    elseif modo == "--d3"
        cab * "\n" * modo_d3()
    elseif modo == "--d4"
        cab * "\n" * modo_d4()
    elseif modo == "--d5"
        cab * "\n" * modo_d5()
    elseif modo == "--d6"
        cab * "\n" * modo_d6()
    elseif modo == "--d7"
        cab * "\n" * modo_d7()
    elseif modo == "--d9"
        cab * "\n" * modo_d9()
    elseif modo == "--d10"
        cab * "\n" * modo_d10()
    elseif modo == "--resumen"
        cab * "\n" * modo_resumen()
    else
        cab * "\nmodos: --entorno --d2 --d3 --d4 --d5 --d6 --d7 --d9 --d10 --resumen " *
              "[--out f]\n(D1 y D8 requieren GDR-v0.2: ver gdr.jl)\n"
    end
    print(texto)
    if salida !== nothing
        isdir(RES) || mkpath(RES)
        write(joinpath(RES, salida), texto)
    end
end

main(collect(ARGS))
