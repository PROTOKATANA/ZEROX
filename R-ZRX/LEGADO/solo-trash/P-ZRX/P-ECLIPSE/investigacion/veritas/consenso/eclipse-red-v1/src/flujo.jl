#= flujo.jl — §4.3: ¿fabrica el eclipse la partición de flujo? Aritmética exacta de slots.

Esto responde a F1 y a F5 del encargo, y **no** es una simulación: es aritmética de enteros sobre
las reglas vigentes, con los símbolos tratados como símbolos.

TODAS las reglas que se usan, citadas por ID (nunca por número de línea):
  · `C-FLU-01`  `T_j = j·I_slots`; `L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`.
                `F_slots`, `L_suelo_slots`, `I_slots` son SÍMBOLOS: esta regla no les da valor.
  · `C-FLU-03`  `V_j(B) := (past(B) ∪ {B}) ∩ {X : slot(X) < T_j + L_slots}`.
  · `C-FLU-04`  `I_j(B)` = primer bloque de `Chn(V_j(B))` con `slot ≥ T_j`.
  · `C-FLU-05`  época sin ancla: se salta, y saltarla es definitivo.
  · `C-FLU-07`  `t_j := slot(I_j) + L_slots`.
  · `C-FLU-14`  pasado consistente de flujo: no se puede FUSIONAR un bloque de otro flujo.
  · `C-FLU-22`  adopción: ventana según el nacimiento; tabla literal del SPEC:
                    espontáneo (latencia)  slot(P) = t_j − 1      ventana F_slots − 1
                    corte que empezó en s₀ slot(P) = s₀           ventana [t_j, s₀ + F_slots)
                    corte más largo que L  slot(P) ≤ t_j − L      VACÍA
  · `C-FIN-01`  NO sustituir la cadena por una candidata con `d ≥ F_slots`; ignorar la punta.

LO QUE ESTE MÓDULO **NO** HACE: no inventa `F_slots`, ni `L_suelo_slots`, ni `I_slots`. Da el
resultado **como función** de ellos, como manda el encargo, e ilustra con el valor provisional de
investigación `F = 2 h` (= `F_slots = 7200` con `σ = 1 s/slot`, `C-SLOT-01`), etiquetado
`provisional` porque `F_slots` es símbolo en el SPEC.
=#

module Flujo

using Printf

const SIGMA = 1.0                 # s por slot (C-SLOT-01, variante A″)
const MS_AES_SLOT = 92.0          # ms por slot de PoT verificado (AVX-512/VAES, medido)
const MS_SALTO_MIN = 1.33         # ms, validar antes de reenviar (571 tx, relé compacto)
const MS_SALTO_MAX = 9.86         # ms, cuerpo completo (medido)
const KB_BLOQUE_MIN = 100.0       # SPEC §16.3: «un bloque típico de ZEROX mide 100-200 KB»
const KB_BLOQUE_MAX = 200.0
const KB_POT_S = 1.0              # ≈1 kB/s de gossip de PoT (HISTÓRICO, h.2b)

"""`C-FLU-01`: `L_slots` es una DEFINICIÓN, no un parámetro libre."""
L_slots(F_slots, L_suelo_slots, S_max_slots) = max(F_slots, L_suelo_slots, S_max_slots + 1)

"""
Umbral de `s₀` para que la ventana de `C-FLU-22` quede **vacía**: `t_j ≥ s₀ + F_slots`, con
`t_j = slot(I_j) + L_slots` y `slot(I_j) ≥ T_j`.

Se toma `slot(I_j) = T_j`, el ancla **más temprana** posible. Es el caso que **minimiza** la
duración necesaria (`t_j` mínimo ⇒ umbral de `s₀` máximo), así que el `E_min` que sale es una
**cota INFERIOR exacta** del eclipse necesario: la cota es del lado de la defensa, y además se
alcanza. Con un ancla posterior (`slot(I_j) = T_j + δ`), `t_j` crece, el umbral de `s₀` también y
la duración necesaria es `≥` la calculada aquí.
"""
s0_max_ventana_vacia(T_j, F_slots, L) = T_j + L - F_slots

"""
Duración mínima del eclipse para que la partición sea **permanente**, en slots, dado que el corte
debe empezar en `s₀ ≤ s0_max` y durar al menos hasta la activación `t_j ≥ T_j + L`.
`E_min = t_j − s₀ ≥ (T_j + L) − (T_j + L − F_slots) = F_slots`.
"""
E_min(T_j, F_slots, L) = (T_j + L) - s0_max_ventana_vacia(T_j, F_slots, L)

"""`C-FIN-01`: ¿puede volver la víctima? Prohibido si `d ≥ F_slots`."""
puede_volver(d, F_slots) = d < F_slots

"""Coste en bytes de ABSORBER el tráfico de una víctima durante `E` slots (si el atacante lo
cursa en vez de descartarlo). `kb` = tamaño de bloque; se ignoran cabeceras menores."""
function coste_absorber_bytes(E_slots, kb_bloque, lam = 1.0)
    return lam * E_slots * SIGMA * kb_bloque * 1000.0
end

"""Pinza de `C-NET-33`: cota inferior de `PRESUP_NODO` (debe bastar para UNA rama rival completa,
`F_slots` slots de AES) frente al trabajo estructural del paso 1b de `C-POT-08`, que **no** gasta
AES. `ratio` = cuántas veces más barato es, para el atacante, forzar trabajo estructural que
trabajo AES por slot de la víctima."""
function presupuesto_pinza(F_slots; ms_estructural_por_slot = NaN)
    inferior_ms = F_slots * MS_AES_SLOT
    if isnan(ms_estructural_por_slot)
        return inferior_ms, NaN
    end
    return inferior_ms, inferior_ms / ms_estructural_por_slot
end

function informe()
    println("§4.3 · ¿FABRICA UN ADVERSARIO DE RED LA PARTICIÓN DE FLUJO? (F1)")
    println("Aritmética de enteros sobre C-FLU-01/03/04/05/07/14/22 y C-FIN-01.")
    println()
    println("RESULTADO, y es una DERIVACIÓN, no una simulación:")
    println("  Sea s₀ el slot del último ancestro común P entre la cadena de la víctima y la de la")
    println("  red. La ventana de adopción de C-FLU-22 para la época j es [t_j, s₀ + F_slots), con")
    println("  t_j = slot(I_j) + L_slots ≥ T_j + L_slots. Luego la ventana es VACÍA siempre que")
    println("      s₀ ≤ T_j + L_slots − F_slots.")
    println("  Si además el corte sigue vivo en el corte de vista T_j + L_slots, la vista de época")
    println("  V_j diverge, el ancla diverge y con ella el flujo (C-FLU-10/12). A partir de ahí:")
    println("    · C-FLU-14 impide FUSIONAR los dos flujos, y")
    println("    · C-FIN-01 impide REORGANIZAR en cuanto d ≥ F_slots,")
    println("  y como s₀ + F_slots ≤ T_j + L_slots, cuando llega el corte de vista la prohibición de")
    println("  C-FIN-01 ya está activa. La partición es PERMANENTE sin que nadie haya roto una regla.")
    println()
    println("  Duración mínima del eclipse: E_min = t_j − s₀ ≥ F_slots slots = F segundos (σ = 1 s).")
    println("  Es decir: **basta un eclipse de duración > F_slots**, y el número coincide con el de")
    println("  la hipótesis §2 del encargo, ahora derivado y no supuesto.")
    println()
    println("MATIZ QUE CAMBIA EL MECANISMO, y hay que decirlo: un retraso UNIFORME de E < L_slots")
    println("NO fabrica la partición, porque el bloque que cruza T_j se produjo ~L_slots antes y la")
    println("víctima ya lo tiene. Lo que la fabrica es RETENER el bloque que cruza T_j (o el pasado")
    println("entero que lo contiene), y como todo bloque honesto posterior desciende de él, retenerlo")
    println("equivale a cortar el flujo honesto. El eje no es el retardo: es la RETENCIÓN.")
    println()

    println("Ilustración con F_slots = 7200 (F = 2 h, valor PROVISIONAL de investigación, no del")
    println("SPEC: F_slots es símbolo), S_max_slots = 150 (R-FIN-1a, elección de Katana).")
    @printf("%14s | %10s | %12s | %12s\n", "L_suelo_slots", "L_slots", "s₀ máx", "E_min (slots)")
    for Ls in (0, 7200, 14400, 28800)
        L = L_slots(7200, Ls, 150)
        @printf("%14d | %10d | %12d | %12d\n", Ls, L, s0_max_ventana_vacia(7200, 7200, L),
                E_min(7200, 7200, L))
    end
    println("  L_suelo_slots NO se fija: es símbolo (SPEC §7.1, C-FLU-01). La tabla lo recorre.")
    println("  Con L_suelo_slots ≥ F_slots, L_slots = L_suelo_slots y el umbral de s₀ depende de él.")
    println()

    println("§4.3 · COSTE ABSOLUTO DEL ATAQUE (F4) — en IP/prefijos/tiempo, NO en espacio")
    println("  La variante (i) —retener el PoT— no necesita disco (11b A.1: 192 → 0 bloques,")
    println("  reproducible aquí con `run.jl --variantes`). La partición tampoco: el atacante")
    println("  RETIENE, no fabrica. Su coste es:")
    println("   1) ocupar las salientes de la víctima durante E > F_slots, y")
    println("   2) no ser expulsado por lento (C-NET-05 desconecta al que no responde a tiempo).")
    println("  Ancho de banda si el atacante CURSARA el tráfico en vez de descartarlo:")
    for E in (7200, 86400)
        b1 = coste_absorber_bytes(E, KB_BLOQUE_MIN)
        b2 = coste_absorber_bytes(E, KB_BLOQUE_MAX)
        @printf("    E=%6d slots (%5.1f h): %.2f–%.2f GB  (%.2f–%.2f Mbit/s sostenidos)\n",
                E, E * SIGMA / 3600, b1 / 1e9, b2 / 1e9,
                b1 * 8 / (E * SIGMA) / 1e6, b2 * 8 / (E * SIGMA) / 1e6)
    end
    println("  DESCARTAR es más barato que cursar: el coste real del ataque NO es ancho de banda,")
    println("  es **sostener la ocupación de las salientes** frente a la renovación de pares.")
    println("  Por eso el borrador de regla que importa es «MUST renovar pares», no un umbral de")
    println("  ancho de banda. Y por eso F4 se responde en IP/prefijos (sección D), no en bits.")
    println()

    println("§4.3 · COLATERAL HONESTO DE C-FLU-20")
    println("  C-FLU-20 obliga al productor a descartar puntas cuya inclusión cambiaría entropía_j")
    println("  o t_j de una época YA ACTIVADA, y C-FLU-21 impide recalcularla. El SPEC dice la")
    println("  consecuencia con esas palabras: «ese bloque queda INFUSIONABLE PARA SIEMPRE».")
    println("  Cuántos bloques honestos condena un eclipse, como función de los símbolos:")
    println("    · bloque del propio granjero eclipsado: rojo_V = 1,0000 medido (variantes (ii) y")
    println("      (iii) con E ≥ 60 s): pierde el 100 % de su recompensa mientras dure el eclipse.")
    println("    · bloques ajenos que cambiarían un ancla activada: a lo sumo los que caen en la")
    println("      banda de la vista de época, ≈ S_max_slots por época activada; la tasa de épocas")
    println("      es 1/I_slots, luego ≈ E/I_slots épocas en un eclipse de E slots.")
    println("  Lo que NO está medido, y el SPEC lo declara pendiente (TAREAS §2.9): el colateral")
    println("  honesto exacto. Aquí se da la forma y se dice que el número no existe.")
    println()

    println("F5 · PINZA DE PRESUP_NODO (C-NET-33)")
    println("  Cota INFERIOR, la que el propio SPEC declara: PRESUP_NODO MUST bastar para verificar")
    println("  UNA rama rival completa = F_slots slots, del orden de F_slots × 92 ms.")
    for F in (7200, 3600)
        inf, _ = presupuesto_pinza(F)
        @printf("    F_slots=%5d -> %.1f s de CPU = %.2f min  [el SPEC dice «≈11 min»]\n",
                F, inf / 1000, inf / 60000)
    end
    println("  Cota SUPERIOR: el SPEC la declara NO DERIVADA (C-NET-33, comentario final).")
    println("  La tensión, y es de diseño antes que de número:")
    println("    El presupuesto se dimensiona para trabajo AES (92 ms/slot). Pero el MISMO")
    println("    presupuesto lo consume el paso 1b de C-POT-08 —comprobación ESTRUCTURAL de")
    println("    C-FLU-14, SIN AES— y el propio SPEC dice de ese paso: «Lo que sí cuesta es")
    println("    recomputar cadena y flujo del sub-DAG ajeno, que es superficie de DoS».")
    println("    Si forzar trabajo estructural cuesta, por unidad, menos que 92 ms de AES, el")
    println("    atacante agota el presupuesto del nodo con el trabajo MÁS BARATO de los dos y")
    println("    deniega la adopción de la rama legítima. El descuento es 92/ms_estructural.")
    println("    `TAREAS.md` §2.9(a)4 ya declara esa rendija «parcialmente bajo control del")
    println("    atacante». Lo que falta para cerrar el veredicto es UNA medida: los milisegundos")
    println("    de paso 1b por bloque ajeno. NO está medida. Sin ella, la compatibilidad de la")
    println("    cota inferior con la resistencia al agotamiento queda INCONCLUSA, pero la")
    println("    dirección del defecto —presupuesto dimensionado para la carga cara y consumido")
    println("    por la barata— no depende de esa medida.")
    println()
    println("  Cifra vecina que SÍ está medida, y no es lo mismo (se declara para no confundir):")
    @printf("    coste por salto de validar antes de reenviar: %.2f–%.2f ms por bloque\n",
            MS_SALTO_MIN, MS_SALTO_MAX)
    println("    (veritas/rendimiento/coste-salto-v1, 2026-09-14). Eso NO es el paso 1b.")
end

end # module
