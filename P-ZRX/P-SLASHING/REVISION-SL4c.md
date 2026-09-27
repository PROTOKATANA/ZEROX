# REVISIÓN SL-4c — forma de la `EvidenceTx` y decodificación de red de la v4 (Rust)

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 02:13). **Ejecutor:** DeepSeek; primer lanzamiento
23:51–23:54 (dos faltas de definición informadas antes de editar: ver `ACLARACION-SL4c.md`), segundo
23:55–02:08. Evidencia: `resultados-SL4c/`. **Veredicto: SUPERADO.** **Migración:** por la orden de rebase
**SL-4c-R** (la base de SL-4c es anterior a W06d5 y SL-4b1).

## Comprobado por el director

- Entrada 22/22. Diferenciales: T01 v0.5 (3 179 + 3 914 negativos) y T04 v0.6 (2 108) con **0 discrepancias** y
  cobertura idéntica a la de los oráculos; ida y vuelta de la v4 (210 con sellos reales) y rechazos del códec;
  suite de su base 734/0/2; `fmt`, `clippy -D warnings`, guardianes.
- **Vectores de `ws/testdata/` idénticos byte a byte** a las salidas de los oráculos (`cmp`).
- Precedencia implementada: entradas/salidas → `cbid` (`evp.cbid`, `ACLARACION-SL4c.md`) → orden canónico, por
  transacción; en `zx-cadena`, la forma de la v4 se comprueba antes que la garantía (sin eso, 660 discrepancias
  con T04). `zx-cadena/src/cadena.rs` no estaba en la lista de archivos de §4, pero la decisión 2 autorizaba
  invocar la forma allí: se acepta, declarado por el ejecutor.
- `tx_desde_bytes` decodifica la v4 (FD-5 cerrada); la activación sigue en el motor.

## Defectos de la entrega (corregidos en SL-4c-R)

1. `cambios.patch` **no incluye** `testdata/transicion-v0.5/` ni `testdata/estado-dag-v0.6/` (lección 6 del
   traspaso, otra vez: la comparación de `testdata/` detectó la omisión antes de migrar).
2. Incompatibilidad con el test de SL-4b1 `firmante_identidad_evidencia.rs` (firma antigua y `ErrCbidAjeno`):
   no es un defecto de SL-4c, sino de la secuencia de migraciones.
