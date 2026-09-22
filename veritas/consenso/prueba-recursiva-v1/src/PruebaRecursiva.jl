# PRV-v0.1 — ¿Da una prueba recursiva el IBD sin confianza que los niveles no dan?
# Instrumento de estudio. Ninguna regla de consenso se decide aquí. Ver CONTRATO.md.
#
# La pregunta central (§2 del encargo) es de SELECCIÓN, no de validez. Este módulo
# separa las dos cosas: `seleccion_*` razona sobre qué decide una prueba de validez, y
# `contar_*`/`coste_*` cuantifican lo que costaría probar GHOSTDAG por bloque.
module PruebaRecursiva

export Factores, P_FACTORES,
       ConteoOperaciones, suma_conteos, pares_anticone,
       coste_restricciones, restricciones_por_bloque, tasa_cierre,
       coste_paramétrico, tasas_cierre, ventana_critica,
       contar_rapido, construir_estado, construir_especs, historia_desde_estado,
       puntas_con_peso, dos_historias,
       Historia, PruebaValidez, verifica_prueba_validez,
       pasado_estricto, ancestro, mergeset_referencia, anticono_en,
       verificar_estructura_independiente, equivalencia_conteos, valida_seleccion,
       incluir_ghostdag, RUTA_GDR,
       bloques_por_segundo_que_cierra, factor_lineal

"""
Busca el oráculo GDR-v0.2 (auditado) subiendo por los ancestros. Funciona igual en la
zona `deepseek/veritas/...` que tras migrar a `veritas/consenso/prueba-recursiva-v1/`.
"""
function ruta_gdr()
    a = abspath(@__DIR__)
    for _ in 1:12
        for rel in (joinpath("veritas", "consenso", "ghostdag-rank-v1", "src", "GhostdagRank.jl"),
                    joinpath("consenso", "ghostdag-rank-v1", "src", "GhostdagRank.jl"))
            cand = joinpath(a, rel)
            isfile(cand) && return cand
        end
        padre = dirname(a)
        padre == a && break
        a = padre
    end
    error("no se encuentra GDR-v0.2 subiendo desde $(@__DIR__)")
end

const RUTA_GDR = ruta_gdr()

"Carga GDR-v0.2 como oráculo de GHOSTDAG (se reutiliza, no se reimplementa)."
function incluir_ghostdag()
    m = Module(:GDRReuso)
    Base.include(m, RUTA_GDR)
    # `invokelatest` evita la advertencia de world-age de Julia 1.12+ al leer el módulo
    # anidado desde un mundo anterior a su definición.
    return Base.invokelatest(getfield, m, :GhostdagRank)
end

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

end # module
