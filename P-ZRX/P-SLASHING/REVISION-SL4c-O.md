# REVISIÓN SL-4c-O (con -B y -C) — oráculos T01 y T04: los defectos de forma de la `EvidenceTx` invalidan el bloque

**Revisor:** Claude (director). **Fecha:** 2026-09-26 (≈ 23:52). **Ejecutor:** DeepSeek, tres rondas de dos
sesiones de un hilo: SL-4c-O 23:10–23:23, -B 23:24–23:37, -C 23:37–23:50. **Veredicto: SUPERADO.**

## Qué quedó

- **Regla única** (T01, T04 y, en SL-4c, Rust): las transacciones de un bloque se comprueban en su orden; para
  cada `EvidenceTx`, **entradas/salidas → `cbid` → orden canónico**; la primera defectuosa fija el motivo
  (`ErrForma(EvidenciaConEntradasOSalidas)`, `ErrForma(EvidenciaCbidAjeno)`, `ErrForma(OrdenCanonicoInvalido)`).
  En fusión (T04) el bloque es **inválido en la admisión**, no un descarte. La semántica (EV-06, EV-07, RAT-3,
  ventana, deduplicación) no cambia.
- **Vectores:** T01 **v0.5** (3 179 casos, `d72c5fd9…`) y T04 **v0.6** (2 108 casos, `86348a48…`); huellas
  comprobadas por el director; ningún nombre semántico antiguo en ellos. v0.4 (T01) y v0.5 (T04) intactos.
- **Diferencias con los vectores anteriores:** T01, 240 cambios de clase (120 `cbid` + 120 entradas), 0
  cuerpos distintos, **0 cambios sin defecto**; T04, 181 casos de v0.5 con defecto, 135 cambian (los otros 46
  ya eran inválidos por otro motivo), **0 sin defecto**.
- **Cobertura:** `cbid` 283, orden 243 (115 igualdad + 128 descendente), estructura 108; bloques con
  transacciones válidas y un defecto; dos evidencias en un bloque en ambos órdenes (gana la primera); tres
  defectos a la vez (gana entradas). `Pkg.test()` T01 2 253/2 253, T04 507/507; `run.jl` sin fallos;
  relecturas independientes, 0 discrepancias.
- **Sin carrera entre las sesiones** (T04 incluye `Transicion.jl` de T01): las pruebas finales de T04 de cada
  ronda son posteriores a la última edición de ese archivo (comprobado por `mtime`).

## Por qué hubo tres rondas (errores del director)

1. SL-4c-O no fijó el **alcance** de la precedencia (dentro de una transacción o en todo el bloque): cada
   oráculo eligió uno. -B lo fijó por transacción, que es lo que hace una implementación que valida
   transacción a transacción.
2. SL-4c-O prohibió tocar la «estructura vigente» y así dejó en T04 la evidencia con entradas como descarte,
   contra EV-04 (y sin un solo caso en sus vectores). -C lo alineó.

## Límite declarado

El modelo abstracto de transacción de los oráculos **no tiene testigos**: el caso `n_wit ≠ 0` de EV-04 solo
lo cubre Rust (`validar_forma_tx_v4`, pruebas de SL-4c V2). El resto de EV-04 está en los vectores.
