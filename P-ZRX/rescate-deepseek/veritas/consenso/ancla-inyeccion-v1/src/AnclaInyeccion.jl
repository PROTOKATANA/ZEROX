# ANCLA-v0.1 — ¿existe una ventana de anclaje para la inyección del PoT?
#
# Instrumento de estudio (P-2.1). Categoría dominante: consenso. NO decide reglas de
# consenso: mide P(discrepancia del ancla) entre observadores honestos en función de la
# profundidad D, y de ahí el mapa (ρ, F).
#
# GHOSTDAG / rank NO se reimplementan: se incluyen sin modificar los archivos fuente de
# GDR-v0.2 en veritas/consenso/ghostdag-rank-v1/src/.
module AnclaInyeccion

using Random
using Printf
using StableRNGs

# --- GDR-v0.2 (reutilizado tal cual; no se reimplementa) --------------------

function _raiz_repo()
    d = @__DIR__
    for _ in 1:15
        if isfile(joinpath(d, "veritas", "LINEO.md"))
            return d
        end
        d = dirname(d)
    end
    error("no se encontró la raíz del repo (veritas/LINEO.md) subiendo desde @__DIR__")
end

const GDR_SRC = joinpath(_raiz_repo(), "veritas", "consenso", "ghostdag-rank-v1", "src")
include(joinpath(GDR_SRC, "modelo.jl"))
include(joinpath(GDR_SRC, "referencia.jl"))
include(joinpath(GDR_SRC, "rapido.jl"))
include(joinpath(GDR_SRC, "validacion.jl"))

include("red.jl")
include("medicion.jl")

export ParametrosRed, DAGGlobal, simular_red, red_erdos_renyi,
       construir_vista, medir_replica, medir_transitorio, AcumuladorD, acumular!,
       curva_pooled, diagnostico_corte, diagnostico_detalle,
       # reexportados de GDR-v0.2 (sin modificar)
       Params, P_DEFECTO, EstadoRapido, EstadoReferencia, anadir!, cadena_seleccionada,
       virtual_sp, generar_dag, entregar, equivalencia, BloqueEspec, construir

end # module
