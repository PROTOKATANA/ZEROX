# REVISIÓN SL-4b2 — castigo activo en la red dev

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 09:47). **Ejecutor:** subagente Sonnet, único,
07:58–09:46. Evidencia: `resultados-SL4b2/`; ejecuciones reales en `deepseek/SL4b2/run-*`. **Veredicto: SUPERADO
CON DOS CORRECCIONES (SL-4b3). Migrada** por parche (7 archivos en `crates/zx-node/`; base sin cambios desde
`bb648fb`; 7/7 huellas; `crates/zx-node` idéntico a la zona; `Cargo.*` sin cambios).

## Resultado

| Paso | Resultado |
|---|---|
| Decisión 0 | Productor sigue al terminal seleccionado **en caliente**: con procesos reales, el nodo del lado perdedor se reorganiza y produce 9 bloques sobre el terminal ganador sin reiniciar; mismo `resumen_estado` en los tres. **Reserva:** los registros crudos de esta ejecución se borraron tras citarlos en `PROGRESO.md`; la repite W07b (E-6b con producción en marcha) |
| V1 | Detector: 7/7 unitarios (`crates/zx-node/src/evidencia.rs`) |
| V2 | **No hecho como se pidió**: sin unitarios de inclusión (ventana cerrada, ya procesado, reorganización que la vuelve elegible); solo el camino principal, dentro de V4 → SL-4b3 |
| V3 | Puerta RAT-3 en el arranque: 3/3 |
| V4 | Doble firma de extremo a extremo con `zx-adversario doble-firma --clave-indice 0 --repetir`, **3/3**: detectada en los tres, sin segunda evidencia por la tercera cabecera (EV-12), incluida y aplicada, garantía de la clave 0 `activo:0, congelado:0` en los tres, mismo `resumen_estado`. **No se comprobó explícitamente** `suelo(C·2/8)` al incluidor ni lo quemado (lo cubren los diferenciales del motor; W07b E-8 lo exige leído del estado) |
| V5 | 10 `SIGKILL` al productor honesto: 0 abstenciones, **0 evidencias** en B y C |
| V6 | Pérdida del registro del firmante: abstención en los slots 57…184 (`34 + 150`, borde inclusivo exacto), produce en 185, 0 evidencias |
| V7 | `fmt`, `clippy -D warnings`, suite completa (81 binarios, 0 fallos), guardianes; regresión de `zx-adversario` E-7/E-8 |

## Defectos (van a SL-4b3)

1. **El bloque de transición se produce sin firmante** (`crates/zx-node/src/nodo.rs`, `producir_bloque_transicion`
   llama a `producir`, no a `producir_con_firmante`), contra la decisión 2 («el nodo produce **solo** con las
   funciones `_con_firmante`»). Las funciones sin firmante siguen públicas en `zx-post` (el ejecutor no las retiró
   porque las usan tests de `zx-post`).
2. **V2** sin los unitarios de inclusión exigidos.

## Aceptado

Detector no persistente entre reinicios (declarado; otro nodo sigue pudiendo detectar); `PeticionPadres` interna
con el slot añadido (no es mensaje de red); el ejecutor corrigió dos fallos de sus propios diagnósticos y guiones,
declarados.
