# PRV-v0.1 — validación: el conteo rápido coincide con la recomputación independiente, y
# la demostración de selección se sostiene bajo las reglas reales del oráculo.

"""
Compara, en DAGs pequeños, el conteo rápido (que lee el oráculo) con la recomputación
independiente desde la definición (mergeset por conjuntos y anticono por ancestría).
Devuelve `(fallos, comprobaciones)`.
"""
function equivalencia_conteos(GDR; nrep::Int=20, nmax::Int=14, seed::UInt64=UInt64(0x5E1EC7))
    fallos = 0
    comprobaciones = 0
    for r in 1:nrep
        rng = StableRNG(seed + UInt64(r))
        especs = GDR.generar_dag(rng, nmax, "V"; ventana=5)
        est = construir_estado(GDR, especs)
        ok, _ = verificar_estructura_independiente(est)
        ok || (fallos += 1; continue)
        fast = contar_rapido(est)
        past = pasado_estricto(est.padres)
        for i in 1:est.n
            ms_ref = mergeset_referencia(past, i, est.gd[i].sp)
            comprobaciones += 1
            length(ms_ref) == fast.ms[i] || (fallos += 1)
            tam_ref = sum(anticono_en(past, x, est.gd[i].blueset) for x in est.gd[i].blueset;
                          init=0)
            tam_ref == fast.tam[i] || (fallos += 1)
        end
    end
    return (fallos=fallos, comprobaciones=comprobaciones)
end

"""
Valida la demostración de selección bajo las reglas reales: las dos historias son
válidas, sus pruebas de validez son aceptadas, y sus puntas canónicas difieren.
"""
function valida_seleccion(GDR; n::Int=40, seed::UInt64=UInt64(0x5E1EC7))
    r = dos_historias(GDR, n, seed)
    p1 = PruebaValidez(r.h1)
    p2 = PruebaValidez(r.h2)
    return (acepta1=verifica_prueba_validez(p1), acepta2=verifica_prueba_validez(p2),
            canonica1=r.h1.canonica, canonica2=r.h2.canonica,
            bw1=r.h1.blue_work, bw2=r.h2.blue_work,
            distintas=(r.h1.canonica != r.h2.canonica))
end
