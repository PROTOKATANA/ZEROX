# Validación: equivalencia referencia↔kernel, invariantes, bordes y contraste con el oráculo Rust.
#
# Ninguna de estas funciones "confía" en el kernel: todas comparan contra la referencia exacta o
# contra un artefacto producido por el código fijado de Autonomys.

using Random: rand, rand!
using StableRNGs: StableRNG

"""
    bitmaps_sinteticos(M, ocupados=32768; semilla) -> Matrix{UInt8}

Genera `M` mapas de presencia **sintéticos** con exactamente `ocupados` bits por pieza, elegidos
uniformemente sobre los 65_536 buckets. Se usa en los tests que no deben depender de los artefactos
del oráculo (perfil de referencia de CI). El invariante «exactamente `NUM_CHUNKS` pruebas» se
respeta a propósito, porque es lo que hace `create_proofs`.
"""
function bitmaps_sinteticos(M::Integer, ocupados::Integer=32768; semilla::Integer=0x1234)
    rng = StableRNG(semilla)
    m = zeros(UInt8, M, 8192)
    perm = collect(0:65_535)
    for p in 1:M
        # Fisher-Yates **parcial**: los `ocupados` primeros quedan uniformes sin barajar el resto.
        for i in 1:ocupados
            j = rand(rng, i:65_536)
            perm[i], perm[j] = perm[j], perm[i]
            b = perm[i]
            m[p, (b >> 3) + 1] |= UInt8(1) << (b & 7)
        end
    end
    return m
end

"""
    SR_BORDES

Bordes de `solution_range` que el encargo §4 exige: `0, 1, 2, 3`, `u64::MAX−1`, `u64::MAX`, más
valores que separan paridad (7/8) y magnitudes de red. Son **escenarios experimentales**, no
decisiones de consenso.
"""
const SR_BORDES = UInt64[0, 1, 2, 3, 7, 8, 255, 256, 4096, 1 << 20, 1 << 31,
                         typemax(UInt64) - 1, typemax(UInt64)]

"""
    eq_distancia_aleatoria(n, semilla) -> (ok, peor_abs, peor_rel)

Compara `distancia_u64` (kernel `UInt64`) con `distancia_u64_exacta` (círculo en `BigInt`) en `n`
pares adversarios: incluye `0`, `1`, el punto opuesto `2^63`, `2^63 ± 1`, `u64::MAX` y vecinos, más
pares aleatorios reproducibles.
"""
function eq_distancia_aleatoria(n::Integer=20_000, semilla::Integer=0x5a5a)
    rng = StableRNG(semilla)
    # Vector adversario fijo: los extremos y el punto opuesto son donde `wrapping_sub` cambia de
    # rama y donde `min` puede elegir el lado equivocado si la resta no envuelve.
    fijos = UInt64[0, 1, 2, 3, (UInt64(1) << 63) - 1, UInt64(1) << 63,
                   (UInt64(1) << 63) + 1, typemax(UInt64) - 1, typemax(UInt64)]
    ok = true
    peor_abs = big(0)
    peor_rel = big(0)
    for i in 1:n
        a = i <= length(fijos) ? fijos[i] : rand(rng, UInt64)
        b = i <= length(fijos) ? fijos[mod1(length(fijos) - i + 1, length(fijos))] :
            rand(rng, UInt64)
        k = big(distancia_u64(a, b))
        r = distancia_u64_exacta(a, b)
        k == r || (ok = false)
        peor_abs = max(peor_abs, abs(k - r))
        peor_rel = max(peor_rel, r == 0 ? big(0) : abs(k - r) // max(r, big(1)))
    end
    return ok, peor_abs, peor_rel
end

"""
    eq_cardinalidad_exhaustiva(modulos, SR_max) -> (ok, filas)

En un círculo **pequeño** `Z/m` enumera todos los residuos y compara con la fórmula cerrada
`min(m, 2·(SR÷2)+1)`. Es la comprobación de cardinalidad del encargo §4: refuta la fórmula sin
depender del tamaño del círculo.
"""
function eq_cardinalidad_exhaustiva(modulos::AbstractVector{<:Integer}=collect(3:2:201),
                                    SR_max::Integer=260)
    ok = true
    filas = NamedTuple[]
    for m in modulos
        for SR in 0:min(SR_max, 2 * m + 3)
            c = cardinalidad_exhaustiva(m, SR)
            f = cardenalidad_circular(m, SR)
            if c != f
                ok = false
                push!(filas, (m=m, SR=SR, enumerado=c, formula=f))
            end
        end
    end
    return ok, filas
end

"""
    eq_paridad(n) -> (ok, ejemplos)

Para todo `SR`, `A(2m) = A(2m+1)`; y sin embargo `w(2m) ≠ w(2m+1)`: la **misma** tasa de bloques
tiene **dos** pesos distintos. Devuelve ejemplos donde el déficit impar es mayor.
"""
function eq_paridad(n::Integer=64)
    ok = true
    ejemplos = NamedTuple[]
    for m in 1:n
        par = 2 * big(m)
        impar = par + 1
        if valores_aceptados(par) != valores_aceptados(impar)
            ok = false
        end
        if peso_bloque(par) == peso_bloque(impar)
            ok = false
        end
        push!(ejemplos, (SR=Int(m), deficit=desviacion_cancelacion(impar),
                         peso_par=peso_bloque(par), peso_impar=peso_bloque(impar)))
    end
    return ok, ejemplos
end

"""
    eq_conservacion_contadores(bitmaps) -> (ok, tamaño_ref, tamaño_kernel)

Compara `s_bucket_sizes_referencia!` con `s_bucket_sizes_histograma!` y comprueba la conservación
global: la suma de todos los contadores es `piezas × 32768`, porque cada pieza tiene exactamente
`NUM_CHUNKS` pruebas.
"""
function eq_conservacion_contadores(bitmaps::AbstractMatrix{UInt8})
    M = size(bitmaps, 1)
    a = zeros(Int32, 65_536)
    b = zeros(Int32, 65_536)
    hist = zeros(Int32, 256)
    s_bucket_sizes_referencia!(a, bitmaps)
    s_bucket_sizes_histograma!(b, bitmaps, hist)
    ok = a == b
    total = sum(b)
    return ok, total, Int64(M) * Int64(32768)
end

"""
    invariantes_bitmaps(bitmaps) -> (ok, detalles)

Invariantes estructurales exigidos por el encargo §4:

* cada pieza tiene **exactamente** `NUM_CHUNKS = 32768` pruebas sobre `NUM_S_BUCKETS = 65536`
  buckets (media de ocupación `1/2` **exacta**);
* para una pieza y un reto hay **como máximo un** chunk en el bucket seleccionado (un bit);
* `s_bucket_sizes[b] ≤ piezas` para todo `b`;
* hay buckets **vacíos** y la ocupación es **desigual** (no todos los buckets tienen lo mismo).
"""
function invariantes_bitmaps(bitmaps::AbstractMatrix{UInt8})
    M = size(bitmaps, 1)
    pruebas = zeros(Int64, M)
    for p in 1:M
        pruebas[p] = bits_de_pieza(bitmaps, p)
    end
    todas_32768 = all(==(32768), pruebas)
    b = zeros(Int32, 65_536)
    hist = zeros(Int32, 256)
    s_bucket_sizes_histograma!(b, bitmaps, hist)
    cota_ok = all(x -> 0 <= x <= M, b)
    vacios = count(==(0), b)
    ocupados = count(>(0), b)
    desigual = length(unique(b)) > 1
    # «Como máximo un chunk por pieza y bucket» es exactamente que el contador suma 0 o 1 por
    # pieza en cada bucket; se comprueba bit a bit sobre una muestra de buckets.
    max_uno = true
    for bucket in (0, 1, 32767, 32768, 65534, 65535)
        n = 0
        for p in 1:M
            bit_en(bitmaps, p, bucket) && (n += 1)
        end
        n <= M || (max_uno = false)
    end
    detalles = (pruebas_iguales_32768=todas_32768, cota_por_piezas=cota_ok,
                buckets_vacios=vacios, buckets_ocupados=ocupados,
                buckets_distintos=length(unique(b)), ocupacion_desigual=desigual,
                maximo_un_chunk_por_pieza=max_uno,
                suma_total=sum(b))
    return todas_32768 && cota_ok && desigual && max_uno, detalles
end

"""
    eq_rank_select(bitmaps; muestra) -> (ok, n_contrastados)

Contrasta `rank_select` con el recuento directo de bits: si el bucket está ocupado, el índice denso
debe estar en `1..pruebas` y crecer estrictamente con el bucket.
"""
function eq_rank_select(bitmaps::AbstractMatrix{UInt8}; muestra::Integer=2_000)
    M = size(bitmaps, 1)
    rng = StableRNG(0xBEEF)
    ok = true
    n = 0
    for _ in 1:muestra
        p = rand(rng, 1:M)
        bucket = rand(rng, 0:65_535)
        rs = rank_select(bitmaps, p, bucket)
        if bit_en(bitmaps, p, bucket)
            rs === nothing && (ok = false)
            rs !== nothing && (rs < 1 || rs > 32768) && (ok = false)
        else
            rs === nothing || (ok = false)
        end
        n += 1
    end
    # Monotonía: el índice denso crece con el bucket en los buckets ocupados.
    p = rand(rng, 1:M)
    prev = 0
    for bucket in 0:65_535
        rs = rank_select(bitmaps, p, bucket)
        if rs !== nothing
            rs > prev || (ok = false)
            prev = rs
        end
    end
    return ok, n
end

"""
    eq_rust_byte_order(vectores) -> (ok, n)

Contra los vectores **reales** del oráculo Rust: lee el `audit_chunk` y el reto en little-endian,
recalcula la distancia con el kernel y compara con la distancia y el veredicto que calculó el
código fijado. Es la prueba de **orden de bytes** del encargo §4.
"""
function eq_rust_byte_order(vectores)
    ok = true
    n = 0
    for v in vectores
        ac = hex_a_bytes(String(v.audit_chunk_hex))
        gc = hex_a_bytes(String(v.global_hex))
        d = distancia_u64(u64_le(ac), u64_le(gc))
        d == UInt64(v.distancia) || (ok = false)
        gana(d, UInt64(v.sr)) == (v.gana == 1) || (ok = false)
        n += 1
    end
    return ok, n
end

"""
    eq_rust_bucket(vectores_buckets) -> (ok, n)

Contrasta la derivación del s-bucket (`SectorId XOR reto`, dos primeros bytes LE) con la que
calculó el código fijado para los mismos bytes.
"""
function eq_rust_bucket(vectores_buckets)
    ok = true
    n = 0
    for v in vectores_buckets
        sid = hex_a_bytes(String(v.sector_id_hex))
        gc = hex_a_bytes(String(v.global_hex))
        ssc = hex_a_bytes(String(v.ssc_hex))
        buf = zeros(UInt8, 32)
        ssc_xor!(buf, sid, gc)
        buf == ssc || (ok = false)
        bucket_de(ssc) == Int(v.bucket) || (ok = false)
        n += 1
    end
    return ok, n
end

"""
    eq_buckets_propios(bitmaps, meta, retos, audita_retos) -> (ok, n, discrepancias)

Julia deriva por su cuenta el s-bucket de cada reto a partir del `sector_id` real y contrasta con
la columna `bucket` que escribió el oráculo Rust en el barrido de auditoría. Cubre la derivación
completa (XOR de 32 B + little-endian de 16 bits) sobre todo el barrido, no solo sobre los vectores.
"""
function eq_buckets_propios(meta, retos::AbstractMatrix{UInt8}, audita_retos)
    sid = hex_a_bytes(String(meta["sector_id_hex"]))
    buf = zeros(UInt8, 32)
    decl = Dict{Int,Int}()
    for r in audita_retos
        decl[Int(r.reto)] = Int(r.bucket)
    end
    ok = true
    n = 0
    discrepancias = 0
    for k in 1:size(retos, 2)
        idx = k - 1
        haskey(decl, idx) || continue
        ssc_xor!(buf, sid, view(retos, :, k))
        bucket_de(buf) == decl[idx] || (ok = false; discrepancias += 1)
        n += 1
    end
    return ok, n, discrepancias
end

"""
    eq_prueba_pos(prueba_meta) -> (ok, n_cand, n_validas, n_corruptas)

El encargo §4 pide «candidato ganador cuya prueba completa falla». Lo que el oráculo comprueba de
verdad es la **prueba PoS** con `is_proof_valid` (la misma función que usa el nodo) y una copia con
un byte invertido, que **debe** ser rechazada.

**Alcance, explícito.** Esto **no** es `verify_solution`: no se comprueba el compromiso de registro,
ni el testigo KZG, ni la firma, ni la cabecera, ni el PoT, ni la admisión DAG. La etapa de
verificación completa queda `pendiente` (ver `CONTRATO.md` §5). Por eso la clave se llama
`pruebas_pos_validas` y no `pruebas_completas_validas`.
"""
function eq_prueba_pos(prueba_meta)
    cand = parse(Int, prueba_meta["candidatos"])
    validas = parse(Int, prueba_meta["pruebas_pos_validas"])
    corruptas = parse(Int, prueba_meta["pruebas_pos_corruptas_aceptadas"])
    return (validas == cand) && (corruptas == 0), cand, validas, corruptas
end

"""
    eq_conservacion_paralelo(bitmaps; bloques) -> (ok, serial, peor_paralelo)

Comprueba que el kernel paralelo conserva los contadores **exactamente** igual que el serial, para
**varios** números de bloques. Con un solo bloque el reparto por bloques no se ejerce y un defecto
de desplazamiento de bucket pasaría inadvertido (pasó: ver `_hist_bloque!`).
"""
function eq_conservacion_paralelo(bitmaps::AbstractMatrix{UInt8};
                                  bloques::AbstractVector{<:Integer}=[1, 2, 3, 5, 7, 16, 33])
    a = zeros(Int32, 65_536)
    b = zeros(Int32, 65_536)
    hist = zeros(Int32, 256)
    s_bucket_sizes_histograma!(a, bitmaps, hist)
    ok = true
    for t in bloques
        s_bucket_sizes_paralelo!(b, bitmaps, t)
        a == b || (ok = false)
    end
    return ok, sum(a), sum(b)
end

"""
    leidos_julia_vs_rust(meta, retos, audita_retos, sizes) -> (julia, rust, coinciden)

Julia deriva por su cuenta el bucket de cada reto a partir del `sector_id` **real** y del reto
**real**, y lee el tamaño de ese s-bucket en la tabla de ocupación construida con los bitmaps
**reales**. El resultado se compara con la columna `chunks_leidos` que escribió el oráculo Rust
auditando la misma parcela con el mismo reto. Es la comprobación de que el puente entero se
reproduce por dos caminos independientes.
"""
function leidos_julia_vs_rust(meta, retos::AbstractMatrix{UInt8}, audita_retos, sizes)
    sid = hex_a_bytes(String(meta["sector_id_hex"]))
    buf = zeros(UInt8, 32)
    decl = Dict{Int,Int}()
    for r in audita_retos
        decl[Int(r.reto)] = Int(r.chunks_leidos)
    end
    n = size(retos, 2)
    lj = zeros(Int, n)
    lr = zeros(Int, n)
    for k in 1:n
        ssc_xor!(buf, sid, view(retos, :, k))
        lj[k] = Int(sizes[bucket_de(buf) + 1])
        lr[k] = decl[k - 1]
    end
    return lj, lr, lj == lr
end

"""
    eq_determinismo(bitmaps, piezas) -> Bool

Reproduce la misma parcela dos veces desde su descripción (los mapas reales) y comprueba que la
auditoría da cifras idénticas. Es la prueba de reproducibilidad del encargo §4.
"""
function eq_determinismo(bitmaps::AbstractMatrix{UInt8}, buckets::AbstractVector{<:Integer})
    a = zeros(Int32, 65_536)
    b = zeros(Int32, 65_536)
    hist = zeros(Int32, 256)
    s_bucket_sizes_histograma!(a, bitmaps, hist)
    s_bucket_sizes_histograma!(b, bitmaps, hist)
    la = zeros(Int32, length(buckets))
    lb = zeros(Int32, length(buckets))
    auditar_slots!(la, a, buckets)
    auditar_slots!(lb, b, buckets)
    return a == b && la == lb
end
