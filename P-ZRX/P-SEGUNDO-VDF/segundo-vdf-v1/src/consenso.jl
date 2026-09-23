# ─────────────────────────────────────────────────────────────────────────────
# consenso.jl — defecto 4: orden de consenso, estados y mapa COMPLETO de reglas.
#
# Fuente: SPEC.md (reglas literales extraídas y citadas), TAREAS.md §2.1/§2.9,
# ci/reglas-sin-codigo.txt y ci/reglas-sin-cablear.txt. Ninguna regla se modifica.
# ─────────────────────────────────────────────────────────────────────────────

const ESTADOS_POT = (:Valido, :Invalido, :Pendiente)

"""
Una fila del mapa de reglas afectadas por introducir una segunda cadena AES.
`cambio` describe lo que la candidata exigiría; `estado` es el estado real hoy
(según `ci/reglas-sin-codigo.txt` / `ci/reglas-sin-cablear.txt`).
"""
struct FilaRegla
    id::String
    por_que::String
    cambio::String
    estado::Symbol
end

"""
Mapa de **todos** los IDs afectados. No basta cambiar `C-FLU-12`: la semilla es
entrada del encadenado (`C-POT-01`), de la cabecera (`C-POT-05`, `C-HDR-07`), de la
clave de caché (`C-POT-07`, `C-NET-31`), del orden de validación (`C-POT-08`), del
calendario de `N` (`C-FLU-16`), de la herencia de inyección (`C-FLU-21`), del
presupuesto de adopción (`C-FLU-22`, `C-NET-33`) y de la validez (`C-FLU-13/14/15`).
"""
function mapa_reglas_vdf()
    return FilaRegla[
        FilaRegla("C-FLU-12", "define la entropía: es la única que la candidata reescribe literalmente",
                  "entropía_j = blake3(chunk ‖ pot_output) → VDF(esa semilla)", :parcial),
        FilaRegla("C-POT-01", "la entropía es ENTRADA del encadenado de semilla slot a slot",
                  "la entrada pasa a ser salida de un VDF de Lrev·N iteraciones", :parcial),
        FilaRegla("C-POT-02", "salida = AES128_chain^N(semilla) con N % 16 == 0 y 8 checkpoints",
                  "la cadena de revelación excede u32::MAX con N realista (ver coste.jl)", :sin_cablear),
        FilaRegla("C-POT-04", "dominio de N(s) y proyección u64 → NonZeroU32",
                  "T = Lrev·N no es proyectable: no cabe en NonZeroU32", :sin_cablear),
        FilaRegla("C-POT-05", "pot_output(B) = salida(f, slot(B)+D): la salida FUTURA anclada",
                  "el ingrediente de la entropía es pot_output (futuro); h.1 usa salida(f, slot(I_j))", :sin_cablear),
        FilaRegla("C-POT-06", "tres estados y prohibición de circularidad",
                  "la revelación se CALCULA (no se publica): hay que decidir si es contexto o candidato", :parcial),
        FilaRegla("C-POT-07", "clave de caché = (f, s, semilla(f,s), N(s))",
                  "la semilla depende de la revelación: la clave no cambia, su cómputo sí", :sin_cablear),
        FilaRegla("C-POT-08", "orden: estructural y flujo antes de AES; caché antes de AES",
                  "si el flujo depende del segundo AES, acreditar esa salida antes de 1b y de la caché; orden pendiente", :parcial),
        FilaRegla("C-FLU-01", "L = máx(F, L_suelo, S_max+1); unidades en slots",
                  "sin cambio directo; (h.6) ata I a ρ_max y Lrev = L − S_max", :sin_codigo),
        FilaRegla("C-FLU-07", "t_j = slot(I_j) + L, activación inclusiva",
                  "sin cambio; la revelación debe estar lista EN t_j", :sin_codigo),
        FilaRegla("C-FLU-09", "S_max < I ⇒ a lo sumo una inyección por slot",
                  "restricción inferior de I en la calibración (h.6)", :sin_codigo),
        FilaRegla("C-FLU-10", "flujo = H_flujo(flujo(t_j−1) ‖ entropía_j ‖ LE64(t_j))",
                  "la entropía entra en el flujo: su cambio cambia el FLUJO derivado", :sin_codigo),
        FilaRegla("C-FLU-13", "validez absoluta, función de past(B) y nada más",
                  "la revelación debe ser determinista de past(B): sin ramas por disponibilidad", :sin_codigo),
        FilaRegla("C-FLU-14", "pasado consistente de flujo, estructural y sin AES",
                  "con entropía del segundo AES, el paso 1b deja de ser automáticamente sin AES; resolver circularidad", :parcial),
        FilaRegla("C-FLU-15", "partición de flujo = fallo de finalidad",
                  "sin cambio; (h) no cierra la partición (ver INFORME)", :sin_codigo),
        FilaRegla("C-FLU-16", "N(s) cambia exactamente en t_j",
                  "(h.5) congela N en slot(I_j): hay que fijar N(slot(I_j)) para la cadena larga", :sin_codigo),
        FilaRegla("C-FLU-21", "la inyección activada se hereda, no se recalcula",
                  "la revelación heredada debe venir con su entropía y su t_j", :sin_codigo),
        FilaRegla("C-FLU-22", "adopción del flujo rival dentro de la ventana, con presupuesto",
                  "(h) añade una partida al presupuesto de adopción (PRESUP_NODO no derivado)", :sin_codigo),
        FilaRegla("C-NET-31", "gossip /zerox/pot/1, una verificación por clave contextual, caché",
                  "(h.2) los checkpoints de la revelación viajan por gossip: carril nuevo", :sin_codigo),
        FilaRegla("C-NET-32", "verificación bajo demanda con tres salvaguardas",
                  "la revelación puede faltar: recomputar (×16,24) o retener (Pendiente)", :parcial),
        FilaRegla("C-NET-33", "PRESUP_PAR y PRESUP_NODO; agotar da Pendiente",
                  "(h) consume presupuesto de verificación de la revelación", :parcial),
        FilaRegla("C-FIN-01", "finalidad en índices de slot; F_slots es símbolo",
                  "sin cambio; el informe mide V, no finalidad económica", :sin_codigo),
        FilaRegla("C-HDR-07", "la justificación cubre (slot(sp)+D, slot(B)+D] y ancla pot_output",
                  "la segunda cadena no viaja en la cabecera: 16 B no cambian", :sin_cablear),
    ]
end

"Estados de `C-POT-06` alcanzables desde un evento; `Pendiente` nunca salta a `Válido` solo."
function transicion_estado_pot(estado::Symbol, evento::Symbol)
    estado in ESTADOS_POT || error("estado desconocido: $estado")
    if evento === :aes_falla || evento === :checkpoint_no_coincide ||
       evento === :descuadre_portadores || evento === :cache_discrepa_misma_clave
        return :Invalido
    elseif evento === :n_fuera_dominio || evento === :slot_futuro ||
           evento === :presupuesto_agotado || evento === :contexto_incompleto
        return :Pendiente
    elseif evento === :verificacion_exitosa
        # única transición a Válido: verificación posterior EXITOSA con el mismo contexto
        return :Valido
    elseif evento === :sin_evento
        return estado
    end
    error("evento desconocido: $evento")
end
