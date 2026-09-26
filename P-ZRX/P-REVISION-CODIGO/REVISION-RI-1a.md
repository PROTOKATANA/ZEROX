# REVISIÓN RI-1a — revisión independiente del motor de transición y los formatos

**Revisor de la revisión:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet
(≈ 20 min, 45 llamadas). Evidencia: `resultados-RI-1a/` (informe y diff de los tests de reproducción).

**Veredicto: ACEPTADA.** Dos hallazgos confirmados con test; el resto del ámbito revisado sin
hallazgos, con lista de puntos comprobados (undo por delta, descartes ED-4…ED-6, RD-7, F-01…F-10,
códec de padres, `Amount`, `CompactSize`, dominios de `txid`, ausencia de `HashMap`/relojes/flotantes).

## Hallazgos

| # | Hallazgo | Comprobación del director | Decisión |
|---|---|---|---|
| 1 (crítica) | `fusion_post` (`crates/zx-consensus/src/transicion/fusion.rs:230-347`) no actualiza `Estado.slot` ni `Estado.peso_sufijo`; el modo estricto sí (`aplicar.rs:796-801`). Un bloque de cadena sin mergeset da `slot = 0`, `peso_sufijo = 0` por fusión frente a `1`/`1` en estricto (test que falla, salida literal) | Contrastado con el oráculo T04 (`P-ZRX/P-DAG/T04/src/EstadoDAG.jl`): `aplicar_bloque_fusion!` fija `S.slot = punto` para **todo** bloque fusionado (línea 303) y `peso_sufijo` lo suma el **llamante** solo por los bloques de **cadena** (líneas 395, 607), no por los fusionados de lado. El diferencial de W06a (líneas `EST`) lo habría detectado, pero llega antes y con el diagnóstico | **Corrección obligatoria en W06a** (decisión 4 ampliada): mismo reparto que T04 |
| 2 (alta) | `fusion_pow` (`fusion.rs:145-228`) no exige `altura = altura_previa + 1` (R-10); el estricto sí | Leído. ED-1 del contrato DAG aplica la fase PoW **en modo estricto**: `fusion_pow` no debería ser alcanzable, pero lo es y no tiene tests | **W06a:** `aplicar_fusion` con un bloque PoW devuelve error explícito (no se fusionan bloques PoW); `zx-cadena` aplica PoW con `aplicar` |

## Error del director

`REVISION-W03` aceptó el modo fusión con cuatro tests que no leen `slot` ni `peso_sufijo` y sin
diferencial de fusión (el de W03 solo recorre el modo estricto). Es el mismo patrón que en T04:
aceptar una verificación sin preguntar **qué campos compara**. Regla añadida al método: en cada
revisión de código, listar qué campos del estado comprueba cada test de la nueva ruta.
