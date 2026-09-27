# medicion.jl — puente entre C y Julia: lee las mediciones crudas de
# `investigacion/mediciones/latencia-aes/` y las convierte en las constantes de `Modelos`.
#
# POR QUÉ ASÍ. §4.1 del encargo pide medir latencia de INSTRUCCIÓN, y `veritas/LINEO.md` reserva
# Julia para kernels numéricos en CPU. Medir latencia de instrucción exige intrínsecos y
# ensamblador en línea; Julia sólo lo expresaría con `llvmcall`, que además rompería la
# reproducibilidad entre versiones. La desviación está argumentada en CONTRATO.md y METODO.md.
#
# Este módulo NO inventa cifras: si un fichero de medición falta, lanza. Nunca hay un valor por
# defecto silencioso.

module Medicion



export RUTA_MEDICIONES, parsear_aesinst, parsear_carga, parsear_verif8, resumen_medido

const RUTA_MEDICIONES = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "mediciones",
                                          "latencia-aes"))

"Una fila de `aesinst`: nombre, ns por unidad, ciclos por unidad, GHz reales."
struct FilaAesinst
    nombre::String
    ns_por_unidad::Float64
    ciclos_por_unidad::Float64
    ghz::Float64
end

"""
    parsear_aesinst(ruta) -> Vector{FilaAesinst}

Lee la salida de `aesinst`. Lanza si el fichero no existe o si el control de coherencia
(`lat pxor xmm`) no aparece: sin control no se acepta la medición.
"""
function parsear_aesinst(ruta::AbstractString)
    isfile(ruta) || error("falta la medición: $ruta")
    filas = FilaAesinst[]
    for linea in eachline(ruta)
        m = match(r"^(lat|thr)\s+(\S.*?)\s+([0-9.]+)\s+ns/(\S+)\s+([0-9.]+)\s+ciclos/(\S+)\s+\(([0-9.]+)\s+GHz", linea)
        m === nothing && continue
        nombre = strip(String(m.captures[2]))
        push!(filas, FilaAesinst(nombre, parse(Float64, m.captures[3]),
                                 parse(Float64, m.captures[5]), parse(Float64, m.captures[7])))
    end
    isempty(filas) && error("no se pudo parsear ninguna fila de $ruta")
    any(f -> occursin("pxor", f.nombre), filas) ||
        error("$ruta no trae el control 'lat pxor xmm': medición no aceptable")
    return filas
end

"Una fila de `carga`: hilos de carga, ns/bloque, ciclos/bloque, GHz."
struct FilaCarga
    hilos::Int
    ns_bloque::Float64
    ciclos_bloque::Float64
    ghz::Float64
end

function parsear_carga(ruta::AbstractString)
    isfile(ruta) || error("falta la medición: $ruta")
    filas = FilaCarga[]
    for linea in eachline(ruta)
        m = match(r"hilos_de_carga=(\d+)\s+bloques=\d+\s+ns/bloque=([0-9.]+)\s+ciclos/bloque=([0-9.]+)\s+GHz_PMU=([0-9.]+)", linea)
        m === nothing && continue
        push!(filas, FilaCarga(parse(Int, m.captures[1]), parse(Float64, m.captures[2]),
                               parse(Float64, m.captures[3]), parse(Float64, m.captures[4])))
    end
    isempty(filas) && error("no se pudo parsear ninguna fila de $ruta")
    return filas
end

"Resumen de `verif8`: la asimetría producir/verificar medida."
struct FilaVerif8
    nombre::String
    ns_bloque::Float64
    ciclos_bloque::Float64
end

function parsear_verif8(ruta::AbstractString)
    isfile(ruta) || error("falta la medición: $ruta")
    filas = FilaVerif8[]
    for linea in eachline(ruta)
        m = match(r"^(verificar escalar \(8 seq\)|verificar AVX512\+VAES \(8 par\)|producir \(1 seq\))\s+bloques=\d+\s+([0-9.]+)\s+ns/bloque\s+([0-9.]+)\s+ciclos/bloque", linea)
        m === nothing && continue
        push!(filas, FilaVerif8(strip(String(m.captures[1])), parse(Float64, m.captures[2]),
                                parse(Float64, m.captures[3])))
    end
    isempty(filas) && error("no se pudo parsear ninguna fila de $ruta")
    return filas
end

"Resumen de `verif16`: ns por bloque para cada número de carriles en vuelo."
struct FilaLanes
    carriles::Int
    ns_bloque::Float64
    ciclos_bloque::Float64
end

function parsear_verif16(ruta::AbstractString)
    isfile(ruta) || error("falta la medición: $ruta")
    filas = FilaLanes[]
    for linea in eachline(ruta)
        m = match(r"^\s*resumen carriles=(\d+)\s+ns_bloque=([0-9.]+)\s+ciclos_bloque=([0-9.]+)", linea)
        m === nothing && continue
        push!(filas, FilaLanes(parse(Int, m.captures[1]), parse(Float64, m.captures[2]),
                               parse(Float64, m.captures[3])))
    end
    isempty(filas) && error("no se pudo parsear ninguna fila de $ruta")
    return filas
end

"""
    resumen_medido() -> NamedTuple

Lee TODAS las mediciones crudas y devuelve las constantes que usa el instrumento. Falla si falta
cualquiera: no hay valores por defecto.
"""
function resumen_medido()
    aes  = parsear_aesinst(joinpath(RUTA_MEDICIONES, "salida-aesinst-core8-n2e6.txt"))
    car  = parsear_carga(joinpath(RUTA_MEDICIONES, "salida-carga.txt"))
    vf8  = parsear_verif8(joinpath(RUTA_MEDICIONES, "salida-verif8.txt"))
    vf16 = parsear_verif16(joinpath(RUTA_MEDICIONES, "salida-verif16.txt"))

    lat_ronda = only(f for f in aes if f.nombre == "AESENC xmm").ns_por_unidad
    lat_bloque = only(f for f in aes if f.nombre == "bloque PoT xmm").ns_por_unidad
    ciclos_ronda = only(f for f in aes if f.nombre == "AESENC xmm").ciclos_por_unidad
    ghz = only(f for f in aes if f.nombre == "AESENC xmm").ghz
    esc = only(f for f in vf8 if f.nombre == "verificar escalar (8 seq)").ns_bloque
    par = only(f for f in vf8 if f.nombre == "verificar AVX512+VAES (8 par)").ns_bloque
    pro = only(f for f in vf8 if f.nombre == "producir (1 seq)").ns_bloque

    (lat_ronda_s = lat_ronda * 1e-9,
     lat_bloque_s = lat_bloque * 1e-9,
     ciclos_por_ronda = ciclos_ronda,
     ghz = ghz,
     verif_escalar_s = esc * 1e-9,
     verif_par8_s = par * 1e-9,
     producir_s = pro * 1e-9,
     factor_paralelismo = esc / par,
     factor_prove_verify = esc / pro,
     carga = car,
     verif8 = vf8,
     verif16 = vf16)
end

end # module
