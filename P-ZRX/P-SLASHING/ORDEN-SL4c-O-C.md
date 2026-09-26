# ORDEN-SL4c-O-C — Oráculos: la `EvidenceTx` con entradas, salidas o testigos también es forma (EV-04)

**LINEO (`V-ZRX/LINEO.md`) rige este código Julia.** Mismas zonas, límites y lanzamiento que
`ORDEN-SL4c-O.md`. **Fecha:** 2026-09-26 (≈ 23:37). **Director:** Claude. **Ejecutor:** DeepSeek.

**Motivo (revisión del director de SL-4c-O-B):** EV-04 clasifica como **forma** todas las filas de su tabla,
también «`n_in ≠ 0` o `n_out ≠ 0` o `n_wit ≠ 0` → `ErrForma(EvidenciaConEntradasOSalidas)`», y `zx-core` ya lo
comprueba en `validar_forma_tx_v4`. Pero T04 lo modela como descarte semántico al fusionar (hereda
`ErrEvidenciaConEntradas` de T01) y **sus vectores no tienen ningún caso** (v0.5 y v0.6: 0). SL-4c-O prohibió
cambiarlo porque no lo había decidido; ahora se decide: se alinea con el contrato.

## Regla (igual en T01, T04 y Rust)

Por transacción, en su orden dentro del bloque: **entradas/salidas/testigos → `cbid` → orden canónico**; la
primera transacción defectuosa fija el motivo. Nombre: `ErrForma(EvidenciaConEntradasOSalidas)`.

## Qué hacer

- **O2 (T04):** la evidencia con entradas, salidas o testigos hace **inválido el bloque en la admisión**;
  ≥ 30 casos en los vectores, ≥ 10 en un bloque con transacciones válidas, y ≥ 5 con los tres defectos a la
  vez (gana «entradas»). Regenerar `vectores-estado-dag-v0.6.txt` (sigue sin consumidor), `.sha256`,
  cobertura y `DIFERENCIAS-v0.5-v0.6.md` (0 cambios sin defecto; como v0.5 no tenía casos de este tipo, se
  espera 0 cambios nuevos por él).
- **O1 (T01):** el `RES` de esos casos pasa de `ErrEvidenciaConEntradas` a `ErrForma(EvidenciaConEntradasOSalidas)`
  (en modo estricto ya invalidaban el bloque: cambia la clase, no la validez) con la precedencia de arriba;
  regenerar `vectores-transicion-v0.5.txt`, `.sha256`, cobertura y `DIFERENCIAS-v0.4-v0.5.md` (los únicos
  cambios nuevos admitidos son esos renombres).

`Pkg.test()` y `run.jl` en verde, relectura 0 discrepancias, sección «SL-4c-O-C» en `INFORME.md` y
`PROGRESO.md`. **O2 no ejecuta sus pruebas finales hasta que O1 haya terminado de editar `Transicion.jl`**
(T04 lo incluye): comprueba su `mtime` y déjalo escrito. **Prohibido Python.** Presupuesto: 30 min y 1 hilo por
parte. Entrada congelada: `P-ZRX/P-SLASHING/ENTRADA-SL4c-O-C.sha256`.
