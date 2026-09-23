"""
    EspacioTasa

Instrumento `espacio-tasa-v1`: mide el puente **espacio → tasa** de PoAS en ZEROX.

Categoría dominante: `seguridad` (la pregunta es cuánta oportunidad de consenso compra una
fracción de espacio). Secundarias: `consenso` (peso y `blue_work`) y `almacenamiento` (bytes de
sector). Se declara en `INFORME.md` conforme a `veritas/LINEO.md` §1.

Capas:

* `referencia.jl` — aritmética **exacta** (`BigInt`/`Rational{BigInt}`): cardinalidad, peso,
  cancelación del `SR`, distancia circular, contabilidad de bytes, port de la calibración.
* `rapido.jl` — kernel `UInt64`/`UInt8`: lectura little-endian, distancia envolvente, predicado,
  ocupación por bucket (referencia lenta **y** kernel con histograma).
* `modelo.jl` — etapas del puente, registro de `Cifra` con estado, y capa estadística exacta.
* `datos.jl` — lectura de los artefactos del oráculo Rust.
* `validacion.jl` — equivalencia referencia↔kernel, invariantes, bordes y contraste con Rust.
"""
module EspacioTasa

include("referencia.jl")
include("modelo.jl")
include("rapido.jl")
include("datos.jl")
include("validacion.jl")

end # module
