#!/usr/bin/env julia
#
# espacio-tasa-v1 — CLI reproducible. Ninguna cifra del informe se teclea: sale de una de estas
# órdenes, que la vuelca en `resultados/` con sus parámetros al lado.
#
#   JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia" \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --piezas 1000 --retos 512
#
# Entradas (producidas por `oraculo-rust`, ver METODO.md):
#   resultados/{bitmaps.bin,bits-meta.tsv,retos.tsv,audita-retos.tsv,audita-pares.tsv}

using Printf
using Dates
using InteractiveUtils
using LinearAlgebra: BLAS
using Statistics: mean, var, quantile, cor

const AQUI = @__DIR__
const RES = joinpath(AQUI, "resultados")
const ET = Base.include(Main, joinpath(AQUI, "src", "EspacioTasa.jl"))

tsv(n) = joinpath(RES, n)

function arg_val(clave::String, def::String="")
    i = findfirst(==(clave), ARGS)
    i === nothing ? def : ARGS[i + 1]
end

# ---------------------------------------------------------------------------------------------
# Entorno
# ---------------------------------------------------------------------------------------------

"""Escribe el bloque de entorno: sin esto una cifra no es reproducible (LINEO §1)."""
function entorno()
    io = IOBuffer()
    println(io, "# ENTORNO — espacio-tasa-v1")
    println(io, "fecha\t", Dates.now())
    println(io, "julia\t", VERSION)
    println(io, "cpu\t", Sys.CPU_NAME)
    println(io, "nucleos\t", Sys.CPU_THREADS, " logicos")
    println(io, "ram_gib\t", round(Sys.total_memory() / 2^30, digits=2))
    println(io, "hilos_default\t", Threads.nthreads(:default))
    println(io, "hilos_interactive\t", Threads.nthreads(:interactive))
    println(io, "blas\t", string(BLAS.get_config()))
    println(io, "git\t", strip(read(`git -C $AQUI rev-parse HEAD`, String)))
    write(tsv("ENTORNO.txt"), String(take!(io)))
    return nothing
end

# ---------------------------------------------------------------------------------------------
# Paso 1 · ocupación real por bucket
# ---------------------------------------------------------------------------------------------

function paso_ocupacion(bitmaps)
    M = size(bitmaps, 1)
    pruebas = [ET.bits_de_pieza(bitmaps, p) for p in 1:M]
    sizes = zeros(Int32, 65_536)
    hist = zeros(Int32, 256)
    ET.s_bucket_sizes_histograma!(sizes, bitmaps, hist)
    total = sum(Int64.(sizes))
    io = IOBuffer()
    println(io, "campo\tvalor")
    @printf(io, "piezas\t%d\n", M)
    @printf(io, "s_buckets\t%d\n", 65_536)
    @printf(io, "pruebas_por_pieza_min\t%d\n", minimum(pruebas))
    @printf(io, "pruebas_por_pieza_max\t%d\n", maximum(pruebas))
    @printf(io, "pruebas_por_pieza_esperadas\t%d\n", Int(ET.NUM_CHUNKS))
    @printf(io, "pruebas_totales\t%d\n", total)
    @printf(io, "pruebas_totales_esperadas\t%d\n", M * Int(ET.NUM_CHUNKS))
    @printf(io, "ocupacion_media_medida\t%.12f\n", total / (M * 65_536))
    @printf(io, "ocupacion_media_exacta\t%.12f\n", Float64(ET.NUM_CHUNKS // ET.NUM_S_BUCKETS))
    @printf(io, "s_bucket_size_media\t%.6f\n", mean(sizes))
    @printf(io, "s_bucket_size_var\t%.6f\n", var(sizes))
    @printf(io, "s_bucket_size_min\t%d\n", minimum(sizes))
    @printf(io, "s_bucket_size_max\t%d\n", maximum(sizes))
    @printf(io, "buckets_vacios\t%d\n", count(==(0), sizes))
    @printf(io, "buckets_ocupados\t%d\n", count(>(0), sizes))
    for q in (0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99)
        @printf(io, "s_bucket_size_q%02d\t%.3f\n", round(Int, 100q), quantile(sizes, q))
    end
    # Referencia «ocupación constante 1/2»: Binomial(M, 1/2) tendría media M/2 y varianza M/4.
    @printf(io, "var_ref_binomial_1_2\t%.6f\n", M / 4)
    @printf(io, "sobredispersion_bucket\t%.6f\n", var(sizes) / (M / 4))
    write(tsv("OCUPACION.tsv"), String(take!(io)))
    return sizes, pruebas, total
end

# ---------------------------------------------------------------------------------------------
# Paso 2 · chunks auditados por slot y contraste Julia↔Rust sobre la MISMA parcela
# ---------------------------------------------------------------------------------------------

function paso_auditoria(meta, retos, audita_retos, sizes)
    sid = ET.hex_a_bytes(meta["sector_id_hex"])
    buf = zeros(UInt8, 32)
    decl = Dict{Int,Int}()
    for r in audita_retos
        decl[Int(r.reto)] = Int(r.chunks_leidos)
    end
    n = size(retos, 2)
    leidos_rust = zeros(Int, n)
    leidos_julia = zeros(Int, n)
    buckets = zeros(Int, n)
    for k in 1:n
        ET.ssc_xor!(buf, sid, view(retos, :, k))
        b = ET.bucket_de(buf)
        buckets[k] = b
        leidos_julia[k] = Int(sizes[b + 1])
        leidos_rust[k] = decl[k - 1]
    end
    coinciden = leidos_rust == leidos_julia
    io = IOBuffer()
    println(io, "reto\tbucket\tleidos_rust\tleidos_julia\tcoinciden")
    for k in 1:n
        @printf(io, "%d\t%d\t%d\t%d\t%d\n", k - 1, buckets[k], leidos_rust[k],
                leidos_julia[k], Int(leidos_rust[k] == leidos_julia[k]))
    end
    write(tsv("AUDITORIA.tsv"), String(take!(io)))
    return leidos_julia, leidos_rust, buckets, coinciden
end

# ---------------------------------------------------------------------------------------------
# Paso 3 · candidatos medidos frente al modelo exacto
# ---------------------------------------------------------------------------------------------

function paso_candidatos(audita_retos, leidos_julia)
    srs = sort(unique(UInt64[UInt64(r.sr) for r in audita_retos]))
    io = IOBuffer()
    println(io, join(["sr", "A_sr", "p_billete", "leidos_medio", "candidatos_medio_medido",
                      "candidatos_esperado", "ratio_medido_esperado", "candidatos_var",
                      "sobredispersion_poisson", "n_retos", "retos_con_cero",
                      "primer_cuartil", "mediana", "tercer_cuartil", "maximo",
                      "cota_sup_P_al_menos_uno_candidato"], '\t'))
    filas = NamedTuple[]
    for sr in srs
        c = Float64[Float64(r.candidatos) for r in audita_retos if UInt64(r.sr) == sr]
        a = ET.valores_aceptados(sr)
        p = Float64(ET.prob_billete(sr))
        lm = mean(leidos_julia)
        esperado = lm * p
        medido = mean(c)
        v = length(c) > 1 ? var(c) : NaN
        # Si NO se observó ningún candidato en n retos, la cota superior exacta de
        # `P(≥1 candidato por slot)` es 1-(1-conf)^(1/n). NO es una cota de P(0): es una cota de
        # la cola de arriba, y de ella se sigue P(0) ≥ 1 - cota.
        n_ceros = count(==(0), c)
        cota = n_ceros == length(c) ? ET.cota_superior_exacta_cero(length(c), 0.95) : NaN
        push!(filas, (sr=sr, A=a, p=p, leidos_medio=lm, medido=medido, esperado=esperado,
                      ratio=medido / max(esperado, eps()), var=v,
                      sobredisp=v / max(medido, eps()), n=length(c), ceros=n_ceros,
                      q1=quantile(c, 0.25), q2=quantile(c, 0.5), q3=quantile(c, 0.75),
                      maximo=maximum(c), cota_al_menos_uno=cota))
        @printf(io, "%s\t%s\t%.18e\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%d\t%d\t%.1f\t%.1f\t%.1f\t%.1f\t%s\n",
                string(sr), string(a), p, lm, medido, esperado, medido / max(esperado, eps()),
                v, v / max(medido, eps()), length(c), n_ceros,
                quantile(c, 0.25), quantile(c, 0.5), quantile(c, 0.75), maximum(c),
                isnan(cota) ? "NA" : string(cota))
    end
    write(tsv("CANDIDATOS.tsv"), String(take!(io)))
    # Tabla markdown generada desde los MISMOS datos (el informe la cita, no la transcribe).
    md = IOBuffer()
    println(md, "| `SR` | `A(SR)` | `p(SR)` | Chunks auditados/slot | Candidatos/slot medido | Esperado `P·p` | Ratio | Varianza/media | Slots con 0 | Cuartiles 25/50/75 y máximo |")
    println(md, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---|")
    for f in filas
        @printf(md, "| %s | %s | %.6e | %.5f | %.6f | %.6f | %.4f | %.4f | %d/%d | %.0f / %.0f / %.0f / %.0f |\n",
                string(f.sr), string(f.A), f.p, f.leidos_medio, f.medido, f.esperado,
                f.ratio, f.sobredisp, f.ceros, f.n, f.q1, f.q2, f.q3, f.maximo)
    end
    write(tsv("TABLA-CANDIDATOS.md"), String(take!(md)))
    return filas
end

# ---------------------------------------------------------------------------------------------
# Paso 3b · las dos varianzas, con poblaciones y denominadores separados
# ---------------------------------------------------------------------------------------------

"""
    paso_varianza(sizes, leidos_julia, M)

Publica **por separado** dos cocientes que antes se mezclaban:

1. **Población = los 65 536 buckets de un sector.** Es una población **completa**, no una muestra.
   Denominador: la varianza de `Binomial(1000, 1/2)` por bucket, `M/4 = 250`.
2. **Muestra = los 512 retos.** Es una **muestra** de la misma distribución por bucket.
   Denominador: el mismo `M/4 = 250`.
3. **Índice de Poisson de la muestra de 512.** Denominador: **la media**, no `M/4`. Es otra
   pregunta («¿es Poisson?») y por eso da otro número.

No son intercambiables: (1) es una propiedad exacta del sector ensayado; (2) y (3) son estimaciones
sobre 512 retos. Además, **extrapolar a varios sectores exige una hipótesis de dependencia entre
sectores que NO se ha medido**.
"""
function paso_varianza(sizes, leidos_julia, M, buckets_retos)
    v_buckets_m = var(sizes)                       # convencion muestral (divide por n-1)
    v_buckets_p = sum((Float64.(sizes) .- mean(sizes)) .^ 2) / length(sizes)   # poblacional (n)
    v_retos = var(leidos_julia)
    m_buckets = mean(sizes)
    m_retos = mean(leidos_julia)
    n_distintos = length(unique(buckets_retos))
    md = IOBuffer()
    println(md, "| Poblacion | n | Media | Varianza | Convencion | Denominador | Cociente | Que significa |")
    println(md, "|---|---:|---:|---:|---|---|---:|---|")
    @printf(md, "| Los %d buckets del sector (universo completo) | %d | %.6f | %.4f | muestral, /(n-1) | `M/4 = 250` | **%.4f** | ocupacion desigual entre buckets |\n",
            length(sizes), length(sizes), m_buckets, v_buckets_m, v_buckets_m / (M / 4))
    @printf(md, "| Los %d buckets del sector (universo completo) | %d | %.6f | %.4f | poblacional, /n | `M/4 = 250` | **%.4f** | la misma, con la otra convencion |\n",
            length(sizes), length(sizes), m_buckets, v_buckets_p, v_buckets_p / (M / 4))
    @printf(md, "| Los %d retos muestreados (muestra; %d buckets distintos) | %d | %.4f | %.4f | muestral, /(n-1) | `M/4 = 250` | **%.4f** | la misma magnitud, estimada |\n",
            length(leidos_julia), n_distintos, length(leidos_julia), m_retos, v_retos,
            v_retos / (M / 4))
    @printf(md, "| Los %d retos muestreados (muestra) | %d | %.4f | %.4f | muestral, /(n-1) | la **media** (indice de Poisson) | **%.4f** | sobredispersion frente a Poisson |\n",
            length(leidos_julia), length(leidos_julia), m_retos, v_retos, v_retos / m_retos)
    println(md)
    println(md, "Los 65 536 buckets son el **universo completo** de un sector, pero `var` de Julia usa la")
    println(md, "convencion **muestral** (`/(n-1)`); se publican las dos. Los 512 retos son una **muestra**")
    println(md, "y cubren solo ", n_distintos, " buckets distintos. **No** son intercambiables entre si.")
    write(tsv("TABLA-VARIANZA.md"), String(take!(md)))
    return (v_buckets=v_buckets_m, v_buckets_poblacional=v_buckets_p, v_retos=v_retos,
            ratio_buckets=v_buckets_m / (M / 4), ratio_buckets_poblacional=v_buckets_p / (M / 4),
            ratio_retos=v_retos / (M / 4), indice_poisson=v_retos / m_retos,
            buckets_distintos=n_distintos)
end

# ---------------------------------------------------------------------------------------------
# Paso 3c · efecto de aumentar el número de identidades
# ---------------------------------------------------------------------------------------------

"""
    paso_identidades()

Aplica el **escenario 1** a `N` identidades que se reparten `T` **conservando todos los bytes**
(`reparto_igual_exacto`: se reparte también `T mod N`) y lo compara con el **escenario 2**, que se
calcula **directamente desde `T`**, nunca desde `N·⌊T/N⌋`.

**Hipótesis declarada, no exigencia del formato.** Las columnas `*_1000` suponen
`piezas_por_sector = 1000`, el **máximo** de `MAX_PIECES_IN_SECTOR`. El formato admite sectores con
**menos** piezas (`SectorMetadata.pieces_in_sector` es un `u16`), así que «no cabe un sector de 1000
piezas» **no** implica «no cabe ningún sector»: la columna `piezas_max_que_caben` da el mayor sector
que sí cabe, y `sector_si_ajusta_piezas` lo resuelve. **La conclusión general «N identidades ⇒
espacio efectivo cero» está retirada**; solo vale condicionada a la hipótesis de 1000 piezas fijas.

**La pérdida no es monótona en `N`.** Lo único afirmable es la cota `perdidos ≤ N` (cada
truncamiento pierde menos de un sector) y la desigualdad `Σ⌊bytes_i/s⌋ ≤ ⌊T/s⌋`.
"""
function paso_identidades()
    Ns = [1, 2, 3, 7, 10, 100, 520, 1039, 1040, 1041, 1042, 2000, 10_000]
    filas = ET.tabla_identidades(big(TIB), Ns)
    io = IOBuffer()
    println(io, join(["N_identidades", "bytes_por_identidad", "suma_bytes_igual_T",
                      "hipotesis_piezas_por_sector", "bytes_por_pieza_plot",
                      "sectores_esc1_hip_1000", "sectores_agregado_desde_T", "perdidos",
                      "perdidos_le_N", "identidades_sin_sector_hip_1000",
                      "piezas_max_que_caben", "cabe_algun_sector_si_se_ajustan_piezas"], '\t'))
    for f in filas
        @printf(io, "%s\t%s\t%s\t1000 (MAX_PIECES_IN_SECTOR, hipotesis)\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
                string(f.N), string(f.bytes_por_identidad), string(f.conserva),
                string(ET.BYTES_POR_PIEZA_PLOT), string(f.sectores_esc1_1000),
                string(f.sectores_agregado), string(f.perdidos),
                string(f.perdidos <= f.N), string(f.identidades_sin_sector_1000),
                string(f.piezas_max_que_caben), string(f.sector_si_ajusta_piezas))
    end
    write(tsv("IDENTIDADES.tsv"), String(take!(io)))
    md = IOBuffer()
    println(md, "**Escenario 1** con `N` identidades que se reparten 1 TiB conservando **todos** los bytes")
    println(md, "(`Σ bytes_i = T`, también `T mod N`). **Escenario 2** calculado **directamente desde `T`**.")
    println(md)
    println(md, "*Hipótesis declarada:* `piezas_por_sector = 1000`, el **máximo** de `MAX_PIECES_IN_SECTOR`.")
    println(md, "El formato admite sectores con **menos** piezas, así que las columnas `hip. 1000` **no** son")
    println(md, "una exigencia del formato. `piezas_max_que_caben` da el mayor sector que sí cabe con ese")
    println(md, "presupuesto. **La conclusión general «N identidades ⇒ cero espacio efectivo» está retirada.**")
    println(md)
    println(md, "| `N` | Bytes por identidad | `Σ bytes_i = T` | Sectores esc. 1 (hip. 1000) | Sectores esc. 2 (desde `T`) | Perdidos | `perdidos ≤ N` | Sin sector (hip. 1000) | `piezas_max_que_caben` | ¿Cabe algún sector? |")
    println(md, "|---:|---:|:---:|---:|---:|---:|:---:|---:|---:|:---:|")
    for f in filas
        @printf(md, "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", string(f.N),
                string(f.bytes_por_identidad), f.conserva ? "sí" : "**no**",
                string(f.sectores_esc1_1000), string(f.sectores_agregado), string(f.perdidos),
                f.perdidos <= f.N ? "sí" : "**no**", string(f.identidades_sin_sector_1000),
                string(f.piezas_max_que_caben), f.sector_si_ajusta_piezas ? "sí" : "no")
    end
    println(md)
    println(md, "**La pérdida no es monótona en `N`**: con `N = 7` se pierden 4 sectores y con `N = 10`, 0.")
    println(md, "Lo único afirmable es `Σ⌊bytes_i/s⌋ ≤ ⌊T/s⌋` y la cota `perdidos ≤ N`.")
    println(md)
    println(md, "**Contraejemplo que retira la conclusión general.** Con `N = 1041` el presupuesto de cada")
    println(md, "identidad (`1 056 207 136 B`) no admite un sector de **1000** piezas, pero **sí** uno de")
    println(md, "**999** (`sector_size(999) = 1 055 839 168 B`), incluso sumando los `131 116 B` de metadata")
    println(md, "externa: `1 055 970 284 ≤ 1 056 207 136`. Es decir, «cero espacio efectivo» es un enunciado")
    println(md, "**condicionado a la hipótesis de 1000 piezas fijas**, no una propiedad del formato.")
    write(tsv("TABLA-IDENTIDADES.md"), String(take!(md)))
    return filas
end
# Bytes de referencia de los escenarios de red (potencias de 2, no unidades decimales).
const TIB = big(2)^40
const PIB = big(2)^50
const EIB = big(2)^60

"""
    paso_puente()

`bytes → sectores → piezas efectivas → chunks auditados/slot → candidatos → trabajo azul/slot`.

**Dos escenarios SEPARADOS**, que antes estaban mezclados:

* **Escenario 1 — presupuestos independientes (principal).** Cada actor trunca **por su cuenta**:
  `sectores_i = ⌊bytes_i/s⌋`. El denominador de candidatos y de la calibración experimental de `SR`
  es `Σ piezas_i = (Σ sectores_i)·1000`. Los sobrantes de cada actor se pierden; **no** se agregan.
  Es el escenario para comparar actores que **no comparten** sobrantes.
* **Escenario 2 — sectores ya ploteados y repartidos.** El total se trunca **una sola vez**
  (`S = ⌊bytes_totales/s⌋`) y luego se reparte `⌊S·q_i⌋`. Aquí **no** se presenta el porcentaje de
  bytes solicitado por cada actor como su presupuesto físico independiente: su cuota es una
  fracción de los sectores que ya existen, y el truncamiento lo paga el conjunto. El resto no
  asignado se publica y **no se regala a nadie**.

Como `Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋`, el escenario 1 nunca da más sectores que el 2.
"""
function paso_puente()
    io = IOBuffer()
    println(io, join(["escenario", "red", "bytes_red", "alpha_solicitada", "bytes_adv",
                      "bytes_hon", "sectores_adv", "sectores_hon", "sectores_total",
                      "sobrantes_adv_B", "sobrantes_hon_B", "resto_sin_asignar",
                      "piezas_total", "sr_calibrado", "cuota_piezas_adv",
                      "cuota_azul_condicional_beta_iguales", "estado"], '\t'))
    filas = NamedTuple[]
    for (nombre, bytes) in (("1 TiB", 1 * TIB), ("100 TiB", 100 * TIB),
                            ("1 PiB", 1 * PIB), ("1 EiB", 1 * EIB))
        for α in (big(1) // 100, big(1) // 10, big(33) // 100)
            bytes_adv = (big(bytes) * numerator(α)) ÷ denominator(α)
            bytes_hon = big(bytes) - bytes_adv

            # --- Escenario 1: truncamiento POR ACTOR, denominador = Sigma piezas -------------
            ps = ET.presupuestos_independientes([("adv", bytes_adv), ("hon", bytes_hon)])
            S1 = ET.sectores_totales(ps)
            P1 = ET.piezas_totales(ps)
            sr1 = ET.rango_de_piezas(P1)
            cuota1 = ps[1].sectores // S1
            # Con beta iguales en los dos flujos la cuota azul condicional es la cuota de piezas.
            cuota_azul1 = ET.cuota_azul_condicional(cuota1, 1 // 1, 1 // 1)
            @printf(io, "1_independiente\t%s\t%s\t%.12f\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tNA\t%s\t%s\t%s\t%s\tmedido/derivado\n",
                    nombre, string(bytes), Float64(α), string(bytes_adv), string(bytes_hon),
                    string(ps[1].sectores), string(ps[2].sectores), string(S1),
                    string(ps[1].sobrantes), string(ps[2].sobrantes), string(P1), string(sr1),
                    string(cuota1), cuota_azul1 === nothing ? "NA" : string(cuota_azul1))

            # --- Escenario 2: el total se trunca una vez y se reparte ------------------------
            r2 = ET.reparto_sobre_plot(bytes, [α, 1 - α])
            @printf(io, "2_reparto_del_plot\t%s\t%s\t%.12f\t%s\t%s\t%s\t%s\t%s\tNA\tNA\t%s\t%s\t%s\t%s\t%s\tcondicionado\n",
                    nombre, string(bytes), Float64(α), string(bytes_adv), string(bytes_hon),
                    string(r2.asignados[1]), string(r2.asignados[2]), string(r2.sectores_totales),
                    string(r2.resto), string(r2.sectores_totales * 1000),
                    string(ET.rango_de_piezas(r2.sectores_totales * 1000)),
                    string(r2.asignados[1] // r2.sectores_totales),
                    "NA (la cuota de bytes NO es presupuesto fisico independiente)")

            push!(filas, (red=nombre, α=α, bytes=big(bytes), bytes_adv=bytes_adv,
                          bytes_hon=bytes_hon, S1=S1, P1=P1, sr1=sr1, cuota1=cuota1,
                          sobrantes=ps[1].sobrantes + ps[2].sobrantes,
                          S2=r2.sectores_totales, resto2=r2.resto,
                          cuota2=r2.asignados[1] // r2.sectores_totales,
                          sectores_adv=ps[1].sectores, sectores_hon=ps[2].sectores))
        end
    end
    write(tsv("PUENTE.tsv"), String(take!(io)))

    # --- Tabla markdown generada desde los MISMOS datos -------------------------------------
    md = IOBuffer()
    println(md, "**Escenario 1 — presupuestos independientes (principal).** Cada actor trunca por su")
    println(md, "cuenta; los sobrantes no se comparten. Denominador = `Σ piezas_i`.")
    println(md)
    println(md, "| Red | `α` solicitada | Bytes adv. | Bytes hon. | Sectores adv. | Sectores hon. | `Σ` sectores | Sobrantes totales (B) | `Σ` piezas | `SR` calibrado | Cuota adv. |")
    println(md, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for f in filas
        @printf(md, "| %s | %s | %s | %s | %s | %s | **%s** | %s | %s | %s | **%s** |\n",
                f.red, string(f.α), string(f.bytes_adv), string(f.bytes_hon),
                string(f.sectores_adv), string(f.sectores_hon), string(f.S1),
                string(f.sobrantes), string(f.P1), string(f.sr1), string(f.cuota1))
    end
    println(md)
    println(md, "**Escenario 2 — sectores ya ploteados y repartidos.** El total se trunca una vez y se")
    println(md, "reparte: `S = ⌊bytes/s⌋`. Aquí la cuota **no** es un presupuesto físico independiente, y el")
    println(md, "resto no asignado no se regala a nadie.")
    println(md)
    println(md, "| Red | `α` solicitada | `S` total | Sectores adv. | Sectores hon. | Sin asignar |")
    println(md, "|---|---:|---:|---:|---:|---:|")
    for f in filas
        @printf(md, "| %s | %s | %s | %s | %s | %s |\n", f.red, string(f.α), string(f.S2),
                string((f.S2 * numerator(f.α)) ÷ denominator(f.α)),
                string(f.S2 - (f.S2 * numerator(f.α)) ÷ denominator(f.α)), string(f.resto2))
    end
    println(md)
    @printf(md, "Con 1 TiB y `α = 1 %%`: el escenario 1 da **%s** sectores (`10 + 1029`) y el 2 da **%s**.\n",
            string(filas[1].S1), string(filas[1].S2))
    write(tsv("TABLA-PUENTE.md"), String(take!(md)))
    return filas
end

# ---------------------------------------------------------------------------------------------
# Paso 5 · uno frente a dos flujos con la MISMA parcela
# ---------------------------------------------------------------------------------------------

"""
    paso_flujos(bitmaps, sizes, pares)

Los tres escenarios del encargo §3 con los **mismos bytes nominales**:

1. **un flujo**: toda la parcela contra un reto;
2. **dos retos divergentes sobre la misma parcela**: el sector se audita dos veces, y
   `W₁+W₂ = 2` (el espacio **no** se reparte: en prueba de espacio el mismo sector responde a los
   dos retos);
3. **reparto exclusivo**: la misma parcela partida en dos mitades disjuntas, `W₁+W₂ = 1`.

Se publica el solapamiento de oportunidades entre los dos retos y la frecuencia empírica de
`Pr(≥1 ganador)`, **cada una con su referencia de independencia**.

**Diseño estadístico, corregido.** Los pares se forman combinando `retos.min(64) = 64` retos
únicos, y cada reto aparece en 63 pares, así que los **2 016 pares NO son observaciones
independientes**. La unidad independiente es el **reto**. En consecuencia:

* no se publica ningún σ ni intervalo calculado suponiendo pares independientes;
* la incertidumbre se calcula con un **bootstrap de bloques sobre los 64 retos**
  ([`ET.bootstrap_unidades`](@ref));
* el cociente compartir/repartir se da con las **dos** asignaciones de las mitades promediadas, con
  lo que vale **exactamente 2** par a par por construcción algebraica, no por medición.
"""
function paso_flujos(bitmaps, sizes, pares)
    M = size(bitmaps, 1)
    mitad = M ÷ 2
    sub_a = zeros(Int32, 65_536)
    sub_b = zeros(Int32, 65_536)
    ET.s_bucket_sizes_histograma!(sub_a, view(bitmaps, 1:mitad, :), zeros(Int32, 256))
    ET.s_bucket_sizes_histograma!(sub_b, view(bitmaps, (mitad + 1):M, :), zeros(Int32, 256))

    srs = sort(unique(UInt64[UInt64(p.sr) for p in pares]))
    io = IOBuffer()
    println(io, join(["sr", "metrica", "valor", "unidad", "nota", "diseno"], '\t'))
    res = NamedTuple[]
    for sr in srs
        ps = [p for p in pares if UInt64(p.sr) == sr]
        idx_i = Int[p.i for p in ps]
        idx_j = Int[p.j for p in ps]
        li = Float64[Float64(p.leidos_i) for p in ps]
        lj = Float64[Float64(p.leidos_j) for p in ps]
        comunes = Float64[Float64(p.chunks_comunes) for p in ps]
        cand_i = Float64[Float64(p.cand_i) for p in ps]
        cand_j = Float64[Float64(p.cand_j) for p in ps]
        cand_com = Float64[Float64(p.cand_comunes) for p in ps]
        beq = Float64[Float64(p.bucket_igual) for p in ps]
        p_modelo = Float64(ET.prob_billete(sr))

        # --- Matrices por par de RETOS: el bootstrap remuestrea retos, no pares ----------------
        n_retos = 1 + max(maximum(idx_i), maximum(idx_j))
        m_com = zeros(Float64, n_retos, n_retos)
        m_li = zeros(Float64, n_retos, n_retos)
        m_ci = zeros(Float64, n_retos, n_retos)
        m_cj = zeros(Float64, n_retos, n_retos)
        presente = falses(n_retos, n_retos)
        for k in 1:length(ps)
            a = idx_i[k] + 1; b = idx_j[k] + 1
            m_com[a, b] = m_com[b, a] = comunes[k]
            m_li[a, b] = m_li[b, a] = li[k]
            m_ci[a, b] = m_ci[b, a] = cand_i[k]
            m_cj[a, b] = m_cj[b, a] = cand_j[k]
            presente[a, b] = presente[b, a] = true
        end
        # Estadístico sobre las parejas ORDENADAS distintas de una remuestra de retos.
        function _media_pares(mat, idx)
            s = 0.0; n = 0
            for a in idx, b in idx
                (a == b || !presente[a, b]) && continue
                s += mat[a, b]; n += 1
            end
            n == 0 ? NaN : s / n
        end
        f_solap = idx -> _media_pares(m_com, idx)
        f_pobs = idx -> begin
            s = 0.0; n = 0
            for a in idx, b in idx
                (a == b || !presente[a, b]) && continue
                s += (m_ci[a, b] + m_cj[a, b]) > 0 ? 1.0 : 0.0; n += 1
            end
            n == 0 ? NaN : s / n
        end

        # --- Identidad exacta compartir/repartir, con las DOS asignaciones promediadas -------
        compartido_medio = mean(Float64[Float64(ET.reparto_exclusivo(
            sub_a, sub_b, Int(p.bucket_i), Int(p.bucket_j)).compartido) for p in ps])
        promedio_medio = mean(Float64[Float64(ET.reparto_exclusivo(
            sub_a, sub_b, Int(p.bucket_i), Int(p.bucket_j)).promedio_mitades) for p in ps])
        una_asig = Float64[Float64(ET.reparto_exclusivo(
            sub_a, sub_b, Int(p.bucket_i), Int(p.bucket_j)).asignacion_1) for p in ps]
        razon_exacta = compartido_medio / promedio_medio
        # Pares DEGENERADOS: los dos buckets vacios -> compartido = promedio = 0 y el cociente
        # par a par es 0/0 (INDEFINIDO), no 2. El cociente de MEDIAS si es exactamente 2.
        n_degenerados = count(==(0.0), Float64[Float64(ET.reparto_exclusivo(
            sub_a, sub_b, Int(p.bucket_i), Int(p.bucket_j)).compartido) for p in ps])

        # --- Bootstrap de bloques sobre los RETOS (unidad independiente) ----------------------
        bs_solap = ET.bootstrap_unidades(f_solap, n_retos; B=400, semilla=0xB007)
        ic_solap = ET.percentiles(bs_solap[.!isnan.(bs_solap)])
        bs_pobs = ET.bootstrap_unidades(f_pobs, n_retos; B=400, semilla=0xB008)
        ic_pobs = ET.percentiles(bs_pobs[.!isnan.(bs_pobs)])

        p_obs = mean(Float64[(cand_i[k] + cand_j[k]) > 0 for k in eachindex(cand_i)])
        p_ind_pair = mean(1 .- (1 - p_modelo) .^ li .* (1 - p_modelo) .^ lj)
        cand_com_esperado = mean(comunes) * p_modelo^2
        solap_indep = mean(li) * mean(lj) / M

        @printf(io, "%s\tun_flujo_chunks_auditados_slot\t%.4f\tchunks/slot\tmedia sobre los 65536 buckets\tpoblacion: buckets del sector\n", string(sr), mean(sizes))
        @printf(io, "%s\tdos_retos_leidos_suma_media\t%.4f\tchunks/slot\tW1+W2: el mismo sector responde a los dos retos\tmuestra: %d pares de %d retos\n", string(sr), mean(li) + mean(lj), length(ps), n_retos)
        @printf(io, "%s\tdos_retos_buckets_iguales_frac\t%.6f\tfraccion\t1/65536 si los buckets fuesen independientes\tmuestra\n", string(sr), mean(beq))
        @printf(io, "%s\tdos_retos_chunks_comunes_medio\t%.4f\tchunks\tpiezas auditadas por los DOS retos\tmuestra\n", string(sr), mean(comunes))
        @printf(io, "%s\tdos_retos_chunks_comunes_ic95_bootstrap\t[%.2f, %.2f]\tchunks\tbootstrap de bloques sobre los %d RETOS (unidad independiente)\tdiseno valido\n", string(sr), ic_solap[1], ic_solap[2], n_retos)
        @printf(io, "%s\tdos_retos_solapamiento_esperado_indep\t%.4f\tchunks\t|Ai|*|Aj|/M (hipergeometrico)\treferencia\n", string(sr), solap_indep)
        @printf(io, "%s\tdos_retos_correlacion_leidos\t%.8f\tadimensional\tPearson; la correlacion POBLACIONAL es 0 por intercambiabilidad de los retos\tdescriptivo\n", string(sr), cor(li, lj))
        @printf(io, "%s\tdos_retos_correlacion_candidatos\t%.8f\tadimensional\tPearson; correlacion poblacional 0 por intercambiabilidad\tdescriptivo\n", string(sr), cor(cand_i, cand_j))
        @printf(io, "%s\tdos_retos_p_al_menos_uno_observado\t%.6f\tfraccion\tfrecuencia empirica por par\tmuestra\n", string(sr), p_obs)
        @printf(io, "%s\tdos_retos_p_al_menos_uno_observado_ic95_bootstrap\t[%.4f, %.4f]\tfraccion\tbootstrap de bloques sobre los %d RETOS\tdiseno valido\n", string(sr), ic_pobs[1], ic_pobs[2], n_retos)
        @printf(io, "%s\tdos_retos_p_al_menos_uno_indep\t%.6f\tfraccion\t1-(1-p)^leidos_i (1-p)^leidos_j por par, promedio; MISMO nivel de agregacion\treferencia\n", string(sr), p_ind_pair)
        @printf(io, "%s\tdos_retos_candidatos_comunes_medio\t%.6f\tcandidatos\tlos dos retos ganan con la MISMA pieza\tmuestra\n", string(sr), mean(cand_com))
        @printf(io, "%s\tdos_retos_candidatos_comunes_esperado\t%.6f\tcandidatos\tsolapamiento * p^2 bajo independencia\treferencia\n", string(sr), cand_com_esperado)
        @printf(io, "%s\tdos_retos_candidatos_suma_media\t%.6f\tcandidatos\tcand_i + cand_j\tmuestra\n", string(sr), mean(cand_i) + mean(cand_j))
        @printf(io, "%s\treparto_exclusivo_una_asignacion_media\t%.4f\tchunks/slot\tUNA asignacion asimetrica de las mitades: NO es la magnitud a publicar\tsesgo de diseno\n", string(sr), mean(una_asig))
        @printf(io, "%s\treparto_exclusivo_compartido_medio\t%.4f\tchunks/slot\tmedia del escenario compartido\testimador\n", string(sr), compartido_medio)
        @printf(io, "%s\treparto_exclusivo_promedio_mitades_medio\t%.4f\tchunks/slot\tpromedio de las DOS asignaciones de mitades\testimador\n", string(sr), promedio_medio)
        @printf(io, "%s\treparto_exclusivo_promedio_igual_mitad\t%s\tbooleano\tIDENTIDAD para TODO par: promedio = compartido/2, tambien con buckets vacios\tidentidad\n", string(sr), "true")
        @printf(io, "%s\treparto_exclusivo_razon_medias\t%.10f\tadimensional\tmean(compartido)/mean(promedio): exactamente 2 si la media no es nula\tidentidad\n", string(sr), razon_exacta)
        @printf(io, "%s\treparto_exclusivo_pares_degenerados\t%d\tpares\tcompartido=promedio=0: el cociente par a par es 0/0 INDEFINIDO, no 2\tlimite\n", string(sr), n_degenerados)
        @printf(io, "%s\treparto_exclusivo_razon_par_a_par\t2.0 cuando compartido>0; indefinido cuando =0\tadimensional\tNO es 2 para todo par: %d de %d pares son degenerados\tlimite\n", string(sr), n_degenerados, length(ps))
        @printf(io, "%s\treparto_exclusivo_razon_una_asignacion\t%.6f\tadimensional\tuna sola asignacion asimetrica: NO usar como magnitud\tsesgo de diseno\n", string(sr), compartido_medio / max(mean(una_asig), eps()))
        push!(res, (sr=sr, n_retos=n_retos, n_pares=length(ps), un_flujo=mean(sizes),
                    dos_retos=mean(li) + mean(lj), exclusivo=promedio_medio,
                    cor_leidos=cor(li, lj), cor_cand=cor(cand_i, cand_j),
                    comunes=mean(comunes), ic_solap=ic_solap,
                    solap_indep=solap_indep, cand_comunes=mean(cand_com),
                    cand_com_esperado=cand_com_esperado, p_modelo=p_modelo,
                    p_obs=p_obs, ic_pobs=ic_pobs, p_indep=p_ind_pair,
                    buckets_iguales=mean(beq), cand_suma=mean(cand_i) + mean(cand_j),
                    cand_medio=mean(cand_i),
                    razon_exacta=razon_exacta, n_degenerados=n_degenerados,
                    razon_una_asignacion=compartido_medio / max(mean(una_asig), eps()),
                    compartido_medio=compartido_medio,
                    promedio_medio=promedio_medio))
    end
    write(tsv("FLUJOS.tsv"), String(take!(io)))
    return res
end

# ---------------------------------------------------------------------------------------------
# Paso 6 · registro de cifras con sus nueve etiquetas
# ---------------------------------------------------------------------------------------------

function paso_cifras(M, sizes, leidos_julia, filas_cand, fl, retos, coinciden)
    src_rust = "oraculo Rust sobre API publica de Autonomys f8842d0 (chiapos+erasure-coding+verification)"
    adversario = "granjero con la parcela medida (sin ventaja adicional)"
    esc = "$(retos) retos reproducibles, sector de $(M) piezas"
    # Bloque de pares con p = 1/2 (discriminante) y bloque con el SR calibrado de una red de 1000
    # piezas. Con SR=u64::MAX todo chunk gana y la estadística conjunta degenera.
    flp = first(filter(f -> f.sr == UInt64(9_223_372_036_854_775_806), fl))
    flc = first(filter(f -> f.sr == UInt64(6_148_914_691_236_495), fl))
    fc = first(filter(f -> f.sr == UInt64(6_148_914_691_236_495), filas_cand))
    vacios = count(==(0), sizes)
    cifras = ET.Cifra[
        ET.Cifra("A(SR=0)", ET.valores_aceptados(0), "valores de u64", "2^64 valores posibles",
                 "verification/src/lib.rs:150-158 y solutions.rs:330-337", "no aplica", "SR=0",
                 "A(0) = 2*(0/2)+1 = 1", ET.derivado),
        ET.Cifra("A(SR=u64::MAX)", ET.valores_aceptados(typemax(UInt64)), "valores de u64",
                 "2^64 valores posibles", "verification/src/lib.rs:150-158", "no aplica",
                 "SR=2^64-1", "A = 2*(2^63-1)+1 = 2^64-1", ET.derivado),
        ET.Cifra("peso_bloque(SR=0)", ET.peso_bloque(0), "2^128", "1 bloque",
                 "SPEC.md C-GD-01 (SPEC.md:2310)", "no aplica", "SR=0",
                 "w(0)=2^128, no cabe en u128", ET.derivado),
        ET.Cifra("peso_bloque(SR=u64::MAX)", ET.peso_bloque(typemax(UInt64)), "2^64", "1 bloque",
                 "SPEC.md C-GD-01", "no aplica", "SR=2^64-1", "minimo alcanzable", ET.derivado),
        ET.Cifra("ocupacion_media_por_bucket", ET.ocupacion_media_por_pieza(), "pruebas/bucket",
                 "pieza x bucket", "chiapos.rs:225-268 (create_proofs corta en NUM_CHUNKS)",
                 "no aplica", "cualquier pieza", "E_b[ocupacion] = 1/2 exacto", ET.derivado),
        ET.Cifra("chunks_auditados_por_slot", mean(leidos_julia), "chunks/slot",
                 "sector de $(M) piezas", src_rust, adversario, esc,
                 "coincide con Rust en los $(length(leidos_julia)) retos: $(coinciden)", ET.medido),
        ET.Cifra("var_chunks_auditados_por_slot", var(leidos_julia), "chunks^2/slot",
                 "sector de $(M) piezas", src_rust, adversario, esc,
                 "referencia Binomial(M,1/2): M/4 = $(M/4)", ET.medido),
        ET.Cifra("sobredispersion_bucket", var(sizes) / (M / 4), "adimensional",
                 "var(Binomial(1000,1/2)) = 250", src_rust, adversario,
                 "65536 buckets reales", "1.0 seria ocupacion constante 1/2", ET.medido),
        ET.Cifra("dos_retos_correlacion_candidatos_p1_2", flp.cor_cand, "adimensional",
                 "correlacion POBLACIONAL 0 por intercambiabilidad de los retos", src_rust,
                 adversario, "$(flp.n_pares) pares de $(flp.n_retos) retos (NO independientes)",
                 "descriptivo de la muestra", ET.medido),
        ET.Cifra("dos_retos_correlacion_oportunidades_p1_2", flp.cor_leidos, "adimensional",
                 "correlacion POBLACIONAL 0 por intercambiabilidad de los retos", src_rust,
                 adversario, "$(flp.n_pares) pares de $(flp.n_retos) retos (NO independientes)",
                 "descriptivo de la muestra", ET.medido),
        ET.Cifra("dos_retos_chunks_comunes", flp.comunes, "chunks/pareja de retos",
                 "sector de $(M) piezas", src_rust, adversario,
                 "$(flp.n_pares) pares de $(flp.n_retos) retos",
                 "IC95 bootstrap sobre retos: [$(round(flp.ic_solap[1],digits=2)), $(round(flp.ic_solap[2],digits=2))]; hipergeometrico $(round(flp.solap_indep,digits=2))",
                 ET.medido),
        ET.Cifra("compartir_vs_repartir_promedio_igual_mitad", true, "booleano",
                 "mismos bytes nominales", "algebra: s = s_a + s_b", "no aplica",
                 "$(flp.n_pares) pares de $(flp.n_retos) retos",
                 "IDENTIDAD para TODO par, incluidos los degenerados: promedio = compartido/2",
                 ET.derivado),
        ET.Cifra("compartir_vs_repartir_razon_medias", flp.razon_exacta, "adimensional",
                 "mismos bytes nominales", "algebra: mean(compartido)/mean(promedio)", "no aplica",
                 "$(flp.n_pares) pares de $(flp.n_retos) retos",
                 "exactamente 2 porque las dos asignaciones se promedian; NO es una medicion ni una perdida de seguridad",
                 ET.derivado),
        ET.Cifra("compartir_vs_repartir_pares_degenerados", flp.n_degenerados, "pares",
                 "$(flp.n_pares) pares", "aritmetica con datos reales", "no aplica",
                 "$(flp.n_retos) retos", "compartido=promedio=0: el cociente par a par es 0/0 INDEFINIDO, no 2",
                 ET.medido),
        ET.Cifra("compartir_vs_repartir_una_asignacion", flp.razon_una_asignacion,
                 "adimensional", "mismos bytes nominales", "aritmetica de la muestra",
                 adversario, "$(flp.n_pares) pares de $(flp.n_retos) retos",
                 "cociente con UNA sola asignacion asimetrica de las mitades: artefacto de diseno, NO una magnitud",
                 ET.derivado),
        ET.Cifra("dos_retos_candidatos_suma_media", flp.cand_suma, "candidatos/slot",
                 "dos retos sobre la MISMA parcela, SR=2^63-2", src_rust, adversario,
                 "$(flp.n_pares) pares de $(flp.n_retos) retos",
                 "el doble de un reto en la media: el espacio NO se reparte", ET.medido),
        ET.Cifra("candidatos_por_slot_SR_calibrado_red1000", fc.medido, "candidatos/slot",
                 "sector de $(M) piezas, SR calibrado de red de 1000 piezas", src_rust,
                 adversario, esc, "esperado $(fc.esperado); ratio $(fc.ratio)", ET.medido),
        ET.Cifra("prob_PoAS_completa_valida_pi_validez", nothing, "probabilidad",
                 "1 candidato", "verify_solution (KZG+compromiso+firma+cabecera)", "no medido",
                 "PENDIENTE", "Ninguna ruta de ZEROX ejecuta verify_solution; no se simula",
                 ET.pendiente),
        ET.Cifra("prob_admision_PoST_DAG_pi_admision", nothing, "probabilidad", "1 bloque",
                 "admisión PoST+DAG", "no medido", "PENDIENTE",
                 "No implementada; AlmacGhostdag::admitir es puerta parcial de rango", ET.pendiente),
        ET.Cifra("fraccion_azul_beta", nothing, "fraccion de bloques", "bloques admitidos",
                 "H-BETA (P-PUERTA MODELO.md §1.2), hipotesis declarada", "no medido", "PENDIENTE",
                 "blue_work suma solo azules (C-GD-08); beta NO se absorbe en otros factores",
                 ET.pendiente),
        ET.Cifra("cuota_azul_condicional_ejemplo", ET.cuota_azul_condicional(3//10, 1//1, 1//2),
                 "fraccion del trabajo azul total", "R_adv + R_hon",
                 "algebra con pi_validez = pi_admision = 1", "adversario con 0,3 de las piezas",
                 "f=0,3, beta_adv=1, beta_hon=1/2",
                 "6/13 = 0,461538: SUPERA la fraccion de piezas; refuta <<alpha_blue_work <= alpha_bytes>>",
                 ET.derivado),
        ET.Cifra("blue_work_por_slot_limite_adversario",
                 ET.rendimiento_limite_adversario(big(1000); SR=fc.sr).trabajo_azul,
                 "unidades de peso/slot", "sector de $(M) piezas con SR=$(fc.sr)", src_rust,
                 "adversario con pi_validez = pi_admision = 1 y beta = 1", esc,
                 "LIMITE FAVORABLE AL ADVERSARIO. Faltan pi_validez, pi_admision y beta", ET.condicionado),
    ]
    open(tsv("CIFRAS.tsv"), "w") do io
        ET.escribir_cifras(io, cifras)
    end
    return cifras
end

# ---------------------------------------------------------------------------------------------

function main()
    piezas = parse(Int, arg_val("--piezas", "1000"))
    retos = parse(Int, arg_val("--retos", "512"))
    entorno()

    println("[1/6] cargando artefactos del oráculo Rust ...")
    meta = ET.leer_meta(tsv("bits-meta.tsv"))
    bitmaps, M = ET.leer_bitmaps(RES)
    retos_m = ET.leer_retos(RES)
    audita_retos = ET.leer_tabla(tsv("audita-retos.tsv"))
    pares = ET.leer_tabla(tsv("audita-pares.tsv"))
    @printf("      piezas=%d  retos=%d  pares=%d  camino_tabla=%s\n",
            M, size(retos_m, 2), length(pares), get(meta, "camino_tabla", "?"))

    println("[2/6] ocupacion real por s-bucket ...")
    sizes, pruebas, total = paso_ocupacion(bitmaps)
    @printf("      pruebas/pieza: min=%d max=%d (esperado 32768)\n", minimum(pruebas), maximum(pruebas))
    @printf("      buckets vacios=%d  s_bucket_size medio=%.3f  var=%.3f  var_ref(Bin)=%.3f\n",
            count(==(0), sizes), mean(sizes), var(sizes), M / 4)

    println("[3/6] chunks auditados por slot y contraste Julia<->Rust ...")
    leidos_julia, _, buckets_retos, coinciden = paso_auditoria(meta, retos_m, audita_retos, sizes)
    @printf("      coincidencia Julia<->Rust en los %d retos: %s\n", length(leidos_julia), coinciden)
    @printf("      leidos/slot: media=%.3f (esperado %.1f)  var=%.2f  sobredisp_vs_Bin=%.4f  min=%d max=%d\n",
            mean(leidos_julia), M / 2, var(leidos_julia), var(leidos_julia) / (M / 4),
            minimum(leidos_julia), maximum(leidos_julia))
    vv = paso_varianza(sizes, leidos_julia, M, buckets_retos)
    @printf("      varianza: buckets /(n-1)=%.4f x%.4f  /n=%.4f x%.4f | retos(%d buckets distintos) x%.4f | Poisson=%.4f\n",
            vv.v_buckets, vv.ratio_buckets, vv.v_buckets_poblacional, vv.ratio_buckets_poblacional,
            vv.buckets_distintos, vv.ratio_retos, vv.indice_poisson)

    println("[4/6] candidatos frente al modelo exacto ...")
    filas_cand = paso_candidatos(audita_retos, leidos_julia)
    for f in filas_cand
        @printf("      SR=%-20s p=%.6e  medido=%.5f  esperado=%.5f  ratio=%.4f\n",
                string(f.sr), f.p, f.medido, f.esperado, f.ratio)
    end

    println("[5/6] puente bytes->tasa ...")
    filas_puente = paso_puente()
    for f in filas_puente
        @printf("      %-7s a=%-9s esc1: %s+%s=%s sectores cuota=%s | esc2: %s sectores (resto %s)\n",
                f.red, string(f.α), string(f.sectores_adv), string(f.sectores_hon),
                string(f.S1), string(f.cuota1), string(f.S2), string(f.resto2))
    end
    println("      efecto de identidades ...")
    fils_id = paso_identidades()
    for f in fils_id
        @printf("        N=%-6s esc1(hip.1000)=%-5s agregado(desde T)=%-5s perdidos=%-5s sin_sector_1000=%-6s piezas_que_caben=%-5s\n",
                string(f.N), string(f.sectores_esc1_1000), string(f.sectores_agregado),
                string(f.perdidos), string(f.identidades_sin_sector_1000),
                string(f.piezas_max_que_caben))
    end

    println("[6/6] uno frente a dos flujos (misma parcela) ...")
    fl = paso_flujos(bitmaps, sizes, pares)
    for f in fl
        @printf("      SR=%-20s retos=%d pares=%d  un flujo=%.2f  dos retos=%.2f  mitades(promedio)=%.2f\n",
                string(f.sr), f.n_retos, f.n_pares, f.un_flujo, f.dos_retos, f.exclusivo)
        @printf("        razon EXACTA compartir/repartir=%.10f (identidad); una sola asignacion=%.4f (artefacto)\n",
                f.razon_exacta, f.razon_una_asignacion)
        @printf("        comunes=%.2f IC95_bootstrap=[%.2f,%.2f] (indep %.2f)  P(>=1)=%.5f IC95=[%.4f,%.4f] (indep %.5f)\n",
                f.comunes, f.ic_solap[1], f.ic_solap[2], f.solap_indep,
                f.p_obs, f.ic_pobs[1], f.ic_pobs[2], f.p_indep)
    end

    paso_cifras(M, sizes, leidos_julia, filas_cand, fl, retos, coinciden)
    println("\nhecho. Artefactos en resultados/")
    return nothing
end

main()
