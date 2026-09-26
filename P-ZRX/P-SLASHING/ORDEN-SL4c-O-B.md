# ORDEN-SL4c-O-B — Ajuste de los oráculos: precedencia por transacción y los dos tipos de orden no canónico

**LINEO (`V-ZRX/LINEO.md`) rige este código Julia.** Mismas zonas, límites y lanzamiento que
`ORDEN-SL4c-O.md` (O1 desde `P-ZRX/P-TRANSICION/T01/`, O2 desde `P-ZRX/P-DAG/T04/`). **Fecha:** 2026-09-26
(≈ 23:24). **Director:** Claude. **Ejecutor:** DeepSeek.

**Motivo (revisión del director de SL-4c-O):** las dos partes cumplen, pero (1) aplican precedencias
distintas cuando un bloque lleva **varias** evidencias defectuosas: T01 va transacción a transacción; T04,
«todos los `cbid` antes que todos los órdenes»; y (2) cada una cubre un solo tipo de orden no canónico: T01 el
descendente (`pre_hash(H1) > pre_hash(H2)`) y T04 la igualdad (`H1 = H2`).

## Regla que fija el director (igual en T01, T04 y Rust)

Las transacciones de un bloque se comprueban **en su orden dentro del bloque**; para cada una, su forma
completa (estructura vigente → `cbid` → orden canónico); **la primera transacción defectuosa determina el
motivo** del rechazo del bloque. Motivo: es lo que hace una implementación que valida transacción a
transacción (Rust), y el consenso solo depende de la invalidez, no del motivo.

## Qué hacer

- **O2 (T04):** cambiar la precedencia a la regla anterior; añadir ≥ 10 casos de orden **descendente**
  además de los de igualdad; dos casos dirigidos: bloque con `[evidencia con orden no canónico, evidencia con
  cbid ajeno]` → `ErrForma(OrdenCanonicoInvalido)` y con el orden inverso → `ErrForma(EvidenciaCbidAjeno)`.
  Regenerar `vectores-estado-dag-v0.6.txt` (aún no lo consume nadie), su `.sha256`, la cobertura y
  `DIFERENCIAS-v0.5-v0.6.md` (mismo criterio: 0 cambios sin defecto).
- **O1 (T01):** añadir ≥ 10 casos de **igualdad** (`H1 = H2`) además de los descendentes; los mismos dos
  casos dirigidos de dos evidencias en un bloque (en modo estricto); regenerar `vectores-transicion-v0.5.txt`,
  `.sha256`, cobertura y `DIFERENCIAS-v0.4-v0.5.md`. Quitar de la lista de exportación los alias
  `ErrCbidAjeno`/`ErrOrdenCanonico` si solo los usa `comparar_vectores.jl` (que puede definirlos localmente).

`Pkg.test()` y `run.jl` en verde, relectura 0 discrepancias, sección «SL-4c-O-B» en `INFORME.md` y
`PROGRESO.md`. **Prohibido Python.** Presupuesto: 30 min y 1 hilo por parte. Entrada congelada:
`P-ZRX/P-SLASHING/ENTRADA-SL4c-O-B.sha256`.
