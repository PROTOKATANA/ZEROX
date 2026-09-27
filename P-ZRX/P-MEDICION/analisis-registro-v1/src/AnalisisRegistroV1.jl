# analisis-registro-v1 — analizador de los registros del nodo (W07c)
#
# Proyecto Julia aislado (LINEO §1). Ordena según ORDEN-W07c y ESQUEMA-REGISTRO-v1.
# Entrada del paquete (necesaria para `Pkg.test()`): el módulo y sus `include`.
# Estructura:
#   modelo.jl     tipos, parseo tolerante, interning, sha256
#   referencia.jl oráculos O(E²) y percentil exacto
#   rapido.jl     kernel tipado y todas las métricas del §3 del esquema
#   validacion.jl equivalencia rápida vs. referencia
#   salida.jl     tablas TSV y RESUMEN.md con procedencia
module AnalisisRegistroV1

using JSON3
using Statistics
using Printf
using Dates
using SHA

# API pública (la usan run.jl y los tests)
export analizar, escribir_salidas, sha256_archivo, leer_registro, PoolCadenas,
       percentil_ordenado, percentil_ordenado_ref, calcular_divergencia, calcular_latencias,
       comparar_divergencia, comparar_latencias, ErrorRegistro, NODATO

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")
include("salida.jl")

end # module
