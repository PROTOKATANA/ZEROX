# PROCEDENCIA — PCO-v0.1

Instrumento ejecutado por un **agente Claude independiente** en
`P-PUERTA/veritas/consenso/puerta-cobertura-v1/`, según `P-PUERTA/PROMPT.md` (copia congelada en
`ENTRADA/`). Sustituye a la puerta 4.0 retirada de ANCLA-v0.2. **Validado por Claude (validador) el
2026-09-19/20** y migrado aquí.

## 1 · Qué comprobó el validador

| Comprobación | Resultado |
|---|---|
| `HUELLAS.sha256` | 60/60 ✓ |
| Suite `--check-bounds=yes`, copia aislada, 1 hilo | **239/239** ✓ (212/212 antes de la corrección) |
| Predicado de aceptación en la fuente de Autonomys (`solution_distance <= solution_range / 2`, división entera) | verificado: `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:150-158` |
| C-GD-01 en `SPEC.md:1669` | verificado |
| Cierre `arcsin(√(τ/F))/π` recalculado aparte | 0,02602 (F=600, τ=4) · 0,00593 (F=11 520) · 0,00750 (F=7 200, τ=4) ✓ |
| Recortes que oculten error (`min(1.0, …)`) | ninguno sobre resultados |

**No reejecutado:** el barrido completo. **No leído entero:** `src/`.

## 2 · Correcciones durante la validación

- **Objeción del validador, aceptada por el agente:** la finalidad limita la **profundidad** de la
  reorganización, no el tiempo desde la última adopción; todos los nodos se congelan **a la vez**. El
  `0,6828` deja de ser «dos nodos bloqueados en flujos distintos» y pasa a ser cota inferior del canal
  veterano / recién llegado; el bloqueo divergente entre veteranos es `arcsin(√(τ/F))/π`.
- **Dos defectos que encontró el propio agente:** réplicas correlacionadas por `StableRNG(semilla+i)`
  (autocorrelación −0,43; migrado a un generador por contador) y un factor 2 en el cierre analítico.
- **Precisión posterior (`../regla-flujo-v1/`, C-FLU-22):** la profundidad se mide desde el **último
  ancestro común**; el modelo de este instrumento (bifurcación en `t_j`, ventana `≈ F`) describe el
  **nacimiento espontáneo**. Con un corte de red anterior la ventana se estrecha y puede ser vacía.

## 3 · Alcance

Modelo de proceso de saltos (Skellam) con costes como **parámetros**; `s₁` (reparto al nacer la
partición) **no está medido ni modelado**; resultado sobre el peso **exacto** (`Rational{BigInt}`): el
`SR` se cancela en todo instante, con residuo de paridad `1/(SR+1)` para `SR` impar (≤ 4,9·10⁻⁴ con
`SR_MIN = 2^11`), pendiente de anotar en `TAREAS.md` §2.3.
