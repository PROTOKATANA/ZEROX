# REVISIÓN W05b3 — productor PoST en régimen y servicio PoT local

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 04:11–04:53.
Evidencia: `resultados-W05b3/`.

**Veredicto: SUPERADO. Migrada** (base idéntica a la raíz; `MIGRACION.sha256`, 158 archivos,
verificado; lock idéntico; 0 borrados; solo `zx-post`).

## Comprobado por el director

- `ENTRADA-W05b3.sha256` 7/7. `producir` (W05b2) intacto.
- Tests de `crates/zx-post/tests/regimen.rs` leídos por nombre: V4 (cadena de 8, hermanos del mismo
  slot con fusión, tres ramas, hueco de 150, cuerpo con transacción extra) y V5 (padre seleccionado
  que no da GHOSTDAG, padres excesivos o no canónicos, slot que no progresa, hueco de 151, checkpoint
  y `pot_output` alterados, solución y sello de otra clave, padre desconocido pendiente, v3 con slot
  distinto rechazada por el motor). Contextos reales: `AlmacenGhostdag`, `ServicioPot`, `ParcelaDisco`.
- Informe: 655 pasan, 0 fallan, 2 ignorados (el previo y el V6 de release, que se ejecuta con
  `--ignored`); 0 perdidos, 26 añadidos.
- Hallazgo H2 de RI-1b corregido: `ErrorContextoTransicion::SalidaDeSlotDiscrepa`.

## Medida V6 (`logs/V6-medicion-real.log`, release, `N_dev` = 138 873 760, carga ajena)

Tres bloques en slots consecutivos: producción 1,852 / 1,434 / 1,433 s (incluye avanzar el PoT un
slot, auditar y demostrar), verificación 0,066 s por bloque. **Error de etiqueta del ejecutor:** la
línea «preparación (historia + parcelas) 9,410 s» mide desde el inicio hasta el final del bucle, es
decir, el **total** (el propio `cargo test` informa 9,41 s), no la preparación.

**Consecuencia para W07 (derivación):** con `τ ≈ 1 s` de PoT, producir cuesta ≈ 0,43 s más que el slot;
un bloque sale ya avanzado el slot siguiente. Hay que medirlo en red (E-2) y declararlo.

## Decisiones del ejecutor ratificadas (`logs/V0-faltas-de-definicion.md`)

`ServicioPot::registrar_validado` alimenta `pasado()`; el productor antepone la v3 al cuerpo; F-17 se
rechaza en el motor, no en la puerta; `>15` padres y extras no canónicos los rechaza el formato de
`zx-core`; `ContextoRangoDag` sigue siendo la constante dev (D-P11).
