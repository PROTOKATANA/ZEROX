# Microbenchmarks del kernel, con validación previa (LINEO §5.1: no medir sin comprobar antes).
#
#   JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia" \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
#
# Se calienta el JIT antes de medir y se publican mediana, asignaciones y memoria.

using BenchmarkTools
using Printf

include(joinpath(@__DIR__, "..", "src", "EspacioTasa.jl"))
using .EspacioTasa
const ET = EspacioTasa

const RES = joinpath(@__DIR__, "..", "resultados")

function main()
    bitmaps, M = ET.leer_bitmaps(RES)
    println("# BENCH — espacio-tasa-v1")
    @printf("# julia=%s cpu=%s hilos=%d piezas=%d\n", VERSION, Sys.CPU_NAME,
            Threads.nthreads(:default), M)

    out = zeros(Int32, 65_536)
    out2 = zeros(Int32, 65_536)
    hist = zeros(Int32, 256)

    # --- Validación previa: el kernel y el oráculo coinciden -------------------------------
    ET.s_bucket_sizes_histograma!(out, bitmaps, hist)
    ET.s_bucket_sizes_referencia!(out2, bitmaps)
    @assert out == out2 "kernel y oráculo discrepan: no se mide"
    @assert sum(Int64.(out)) == M * 32768
    println("# validacion previa: kernel == oraculo, suma = ", sum(Int64.(out)))

    # --- Calentamiento ---------------------------------------------------------------------
    ET.s_bucket_sizes_histograma!(out, bitmaps, hist)
    ET.s_bucket_sizes_referencia!(out2, bitmaps)
    b = UInt64(1) << 63
    for i in 1:1000
        ET.distancia_u64(UInt64(i), b) |> Ref
    end

    println("\n## Ocupacion por bucket: oraculo lento vs kernel con histograma")
    t_ref = @benchmark ET.s_bucket_sizes_referencia!($out2, $bitmaps)
    t_ker = @benchmark ET.s_bucket_sizes_histograma!($out, $bitmaps, $hist)
    @printf("oraculo_lento   mediana_ns=%12.0f  allocs=%d  memoria_B=%d\n",
            minimum(t_ref).time, minimum(t_ref).allocs, minimum(t_ref).memory)
    @printf("kernel_hist     mediana_ns=%12.0f  allocs=%d  memoria_B=%d\n",
            minimum(t_ker).time, minimum(t_ker).allocs, minimum(t_ker).memory)
    @printf("aceleracion     x%.2f\n", minimum(t_ref).time / minimum(t_ker).time)

    println("\n## Distancia y lectura little-endian (por operacion)")
    a = rand(UInt64, 1_000_000)
    c = rand(UInt64, 1_000_000)
    t_dist = @benchmark begin
        s = UInt64(0)
        @inbounds for i in eachindex($a)
            s += ET.distancia_u64($a[i], $c[i])
        end
        s
    end
    @printf("distancia_u64    mediana_ns=%12.0f  allocs=%d  ns/op=%.3f\n",
            minimum(t_dist).time, minimum(t_dist).allocs,
            minimum(t_dist).time / length(a))
    # `bytes` debe variar por offset: con una entrada constante LLVM saca la lectura del bucle
    # (la primera versión de este banco midió 2 ns para 100.000 lecturas, que es imposible).
    bytes = rand(UInt8, 8 * 4096)
    t_le = @benchmark begin
        s = UInt64(0)
        @inbounds for k in 0:4095
            s += ET.u64_le($bytes, 8 * k + 1)
        end
        s
    end
    @printf("u64_le           mediana_ns=%12.0f  allocs=%d  ns/op=%.3f\n",
            minimum(t_le).time, minimum(t_le).allocs, minimum(t_le).time / 4096)

    println("\n## Derivacion de s-bucket (XOR de 32 B + u16 LE) y auditoria de un lote")
    sid = ET.hex_a_bytes(ET.leer_meta(joinpath(RES, "bits-meta.tsv"))["sector_id_hex"])
    buf = zeros(UInt8, 32)
    retos = ET.leer_retos(RES)
    nb = zeros(Int32, size(retos, 2))
    t_buck = @benchmark ET.buckets_de_retos!($nb, $sid, $retos, $buf)
    @printf("buckets_de_retos mediana_ns=%12.0f  allocs=%d  ns/reto=%.1f\n",
            minimum(t_buck).time, minimum(t_buck).allocs,
            minimum(t_buck).time / size(retos, 2))

    leidos = zeros(Int32, size(retos, 2))
    t_aud = @benchmark ET.auditar_slots!($leidos, $out, $nb)
    @printf("auditar_slots    mediana_ns=%12.0f  allocs=%d  ns/reto=%.1f\n",
            minimum(t_aud).time, minimum(t_aud).allocs,
            minimum(t_aud).time / size(retos, 2))

    println("\n## Aritmetica exacta del modelo (por operacion)")
    t_prob = @benchmark ET.tasa_peso(1024, $(UInt64(6148914691236495)))
    @printf("tasa_peso        mediana_ns=%12.0f  allocs=%d\n",
            minimum(t_prob).time, minimum(t_prob).allocs)
    t_peso = @benchmark ET.peso_bloque($(UInt64(6148914691236495)))
    @printf("peso_bloque      mediana_ns=%12.0f  allocs=%d\n",
            minimum(t_peso).time, minimum(t_peso).allocs)
    return nothing
end

main()
