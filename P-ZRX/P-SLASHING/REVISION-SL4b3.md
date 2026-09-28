# REVISIÓN SL-4b3 — transición con firmante seguro, funciones sin firmante fuera del nodo, tests de inclusión

**Revisor:** Claude (director). **Migrada:** 2026-09-27 ≈ 10:43 (`de7ae26`); en ese momento la revisión quedó solo en
`R-ZRX/BITACORA.md` (10:43–10:50). **Este documento:** 2026-09-28, redactado al auditar P-ZRX, con la comprobación
hecha sobre la E-0 del candidato final `c107163` (`deepseek/W07b/run/e0-c107163-ci.log`). **Ejecutor:** DeepSeek.
Evidencia: `resultados-SL4b3/`. **Veredicto: SUPERADO. Migrada.**

**Motivo:** defectos 1 y 2 de `REVISION-SL4b2.md`. El bloque de transición se firmaba sin el firmante seguro, y faltaban
los unitarios de inclusión de evidencia (V2 de SL-4b2).

| Decisión | Qué hizo | Comprobado el 2026-09-28 en `c107163` |
|---|---|---|
| 1. Transición con firmante | `producir_bloque_transicion` usa el mismo `Firmante` que el régimen; si se abstiene, no produce y registra `firmante_abstenido` | Guardián `ci/firmante-obligatorio.sh` verde en la E-0 final (`dep3_exit=0`); el test `registro_firmante_transicion` es una comprobación sobre una ejecución real y va `#[ignore]` (se lanza con `--ignored`) |
| 2. Sin firmante fuera del nodo | `producir` → `producir_sin_firmante`, `producir_en_regimen` → `producir_en_regimen_sin_firmante` («solo tests y arneses»); guardián de CI nuevo que falla si `crates/zx-node/src/` los menciona | `crates/zx-node/src/` sin ninguna mención de `_sin_firmante`; guardián en el job `deps` |
| 3. Tests de inclusión | `evidencia::elegibles` extraído; cuatro casos (ventana abierta, ya procesado, ventana cerrada, portador reorganizado fuera) | Los cuatro pasan en la E-0 final (`evidencia::tests::*`, 11 de 11 del módulo) |

**Límite que queda:** la comprobación con procesos reales de la transición firmada va aparte (`--ignored`). Su
evidencia son las ejecuciones de SL-4b3 y, de forma indirecta, todas las de W07b: todos los nodos cruzaron el corte con
el binario que exige el firmante.
