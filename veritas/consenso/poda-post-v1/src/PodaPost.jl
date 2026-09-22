# PPP-v0.1 — ¿Hay una poda para ZEROX? Análogo PoST a los niveles de PoW.
# Instrumento de estudio. Ninguna regla de consenso se decide aquí: lo que el SPEC no
# determina queda como opción o como pendiente declarado. Ver CONTRATO.md.
module PodaPost

export Parametros, P_DEFECTO,
       M_DIST, umbral, es_valida, nivel,
       p_nivel_exacta, hipotesis_nivel, ratio_exacto,
       distancia_min, contar_niveles!,
       p_nivel_crudo, factor_anclaje,
       TablaNiveles, tabla_niveles,
       coste_sorteos, tiempo_medio_nivel,
       crecimiento_cabeceras,
       anclaje_independiente_de_padres,
       coste_molido_cpu,
       ResultadoMC, monte_carlo_niveles, p_mc,
       equivalencia_niveles, cubre_intervalo,
       ResultadoExhaustivo, oraculo_exhaustivo, p_exhaustiva, p_exhaustiva_ge,
       formula_escalada,
       valida_formula_vs_exhaustiva,
       Solucion, BloqueNivel, Certificado, certificado_de_soluciones,
       verifica_certificado_niveles, dos_historias_misma_solucion,
       valida_anclaje_independiente, certificado_falso_alto,
       coste_molido_hash, tabla_crecimiento

export incluir_ghostdag, RUTA_GDR

"""
Busca el oráculo GDR-v0.2 subiendo por los ancestros. Funciona igual en la zona
`deepseek/veritas/...` (instrumento ajeno, sólo lectura) que tras migrar a
`veritas/consenso/poda-post-v1/` (hermano del instrumento).
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

"""
Carga GDR-v0.2 (oráculo de GHOSTDAG ya auditado) desde `veritas/consenso/ghostdag-rank-v1/`.
Se reutiliza, no se reimplementa.
"""
function incluir_ghostdag()
    m = Module(:GDRReuso)
    Base.include(m, RUTA_GDR)
    return getfield(m, :GhostdagRank)
end

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

end # module
