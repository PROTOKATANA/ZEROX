# Ronda 14A — DAGKNIGHT sobre el DAG de PoAS: ¿baja el suelo de irreversibilidad?

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio). Prioridad declarada: **bajar el
tiempo de irreversibilidad lo más posible**. El cliente ligero es secundario.

**Pregunta.** ¿Puede una regla de confirmación adaptativa tipo DAGKNIGHT sobre el DAG de PoAS de
ZEROX bajar el suelo de confirmación de 100–134 s (`dag-poas-catalogo-problemas-ataques.md:63`, D6)
sin comité, sin dinero y sin confianza nueva? ¿A qué latencia, con qué `α`, con qué `Δ`, y a qué
coste de consenso?

**Fuentes.**
- `research/fuentes/dagknight.txt` (paper). Fórmula en `:1007`:
  `O((ln(1/ε)+Dλ)/(1−2α)+(Dλ)²)` pasos; simulación en `:182-197` (λ=3,75, α=0,2, D=0,1/1/2 s,
  ε=0,05 → 1,2/6/12 s); cota en `:328-352`. El fichero tiene bytes no-UTF8: léelo con
  `open(..., encoding='latin-1')` o `grep -a`.
- Diseño vivo: `research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1..14; **NO editar**), sobre todo
  R-FIN-6 (k=25/30 fijo), R-FIN-5 (un flujo por PoT), R-FIN-7 (`F=2 h`), R-FIN-14 (reto por slot).
- Simuladores existentes (**importar, no modificar**): `research/scripts/d9-ronda8c/r8c_gd.py`
  (GHOSTDAG fiel a rusty-kaspa) y `r8c_sim.py` (eventos y adversario del paper). Ver el patrón de
  importación en `research/scripts/d9-ronda8d/r8d_lib.py:1-30`.
- Catálogo: `research/dag-poas-catalogo-problemas-ataques.md` (D6 suelo, A1 frontera, E1 `Δ`).

**Trabajo.**
1. **Control positivo primero.** Reproduce con el instrumento la tabla de `dagknight.txt:182-197`
   (λ=3,75, α=0,2, D=0,1/1/2, ε=0,05 → 1,2/6/12 s). Si no la reproduces, el instrumento no vale.
2. **Porta la regla de DAGKNIGHT** (k adaptativo y confirmación por cliente) sobre el simulador
   existente, en tu directorio. Documenta qué simplificas.
3. **Corre con parámetros ZEROX:** λ=1, `α ∈ {0,10, 0,25, 0,33, 0,40}`, `Δ ∈ {1, 4, 16, 20} s`,
   `ε ∈ {0,05, 1e-3, 1e-6, 1e-12}`. ≥12 semillas, media e intervalo.
4. **Compara con el baseline GHOSTDAG `k=30`** (el suelo 3k/((1−α)λ) = 100–134 s y la frontera
   44,6 %). ¿Cuánto baja la latencia y cuánto sube o baja la tolerancia a `α`?
5. **Coste de consenso:** qué reglas hay que sustituir o re-derivar (R-FIN-6, suelo 3k, frontera,
   R-FIN-7/`F`, interacción con R-FIN-5 y R-FIN-14). La confirmación de DAGKNIGHT es **por cliente**
   (`D`), no un certificado: dilo y valora si sirve para un comerciante y para un exchange.
6. **D8 sobre tu propio resultado** antes de cerrar: intenta tumbar la conclusión (¿el `k`
   adaptativo se puede manipular? ¿el atacante puede forzar `k` alto y congelar la confirmación?).

**Entregable:** `research/scripts/d14-dagknight/informe.md` incremental (commit por punto, solo tu
directorio, sin push), scripts y salidas, `AUDITA_SCRIPTS.py` pasado, `## Veredicto` con etiquetas
(DEMOSTRADO / VERIFICADO / PLAUSIBLE / REFUTADO / LAGUNA) y `## Errores propios`. Di la latencia
mínima alcanzada con número y condiciones.
