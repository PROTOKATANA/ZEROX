# Revisión del director — T01-B (2026-09-26)

**Veredicto: SUPERADO.** DeepSeek, 02:08–02:25.

- R-6…R-9 aplicadas en el oráculo (marcadas `RATIFICACION-v0.1-Rn`); `run.jl --replicas 50`:
  7 372 800 historias, 0 fallos.
- `resultados/vectores-transicion-v0.txt`: 2 055 casos (55 dirigidos, 2 000 aleatorios), solo
  interfaces por defecto, sha256 `06d95324…41e6d766` (el `.sha256` contiene solo el hash, no el
  formato de `sha256sum -c`: comprobado a mano por el director). Relectura independiente: 0
  discrepancias; determinista.
- **Cobertura medida por el director:** caminos válidos bien ejercitados (13 637 coinbases PoW,
  8 035 depósitos, 5 835 coinbases PoST, 3 826 transferencias, 3 712 retiros, 2 909 liberaciones;
  1 947 casos terminan en fase PoST). **Débil en rechazos de transacción:** 0 `ErrSaldo`,
  0 `ErrDobleGasto`, 0 `ErrRetiroPendiente`, 3 `ErrAutorizacion`, 8 `ErrInmaduro`. Se encarga
  **T01-C** (casos negativos de transacción dirigidos) para completar el diferencial.
- Omisiones declaradas: X-12 (estado manual no releíble) y X-15 (`SEC-A`), que siguen en los tests.
