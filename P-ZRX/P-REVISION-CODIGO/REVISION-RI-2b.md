# REVISIÓN RI-2b — revisión independiente de `zx-storage`, productor en régimen y `zx-node`

**Revisor de la revisión:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet
(≈ 2 h, incluida la compilación de `librocksdb-sys` y una prueba dirigida de 625 s). Evidencia:
`resultados-RI-2b/` (informe y test de reproducción). **Veredicto: ACEPTADA.** Un hallazgo alto
(plausible, verificado por lectura); `zx-storage` y `productor_regimen.rs` sin hallazgos. Sin procesos
vivos al terminar (comprobado por el director).

| # | Hallazgo | Comprobación del director | Decisión |
|---|---|---|---|
| 1 (alta; crítica con red; PLAUSIBLE) | `admitir_post_interno` (`crates/zx-node/src/nodo.rs:555-568`) admite en `zx-cadena` **antes** de persistir; `admitir_pow_interno` (395-414) persiste primero y lo justifica en su comentario. Un `SIGKILL` entre ambas pierde un bloque propio; al reiniciar, con el PoT determinista reconstruido desde el almacén, la misma clave puede ganar el mismo slot y firmar otro bloque: doble firma | Leído: el orden es el descrito. Sin red, el bloque perdido no salió del nodo y la doble firma no es observable; **con red lo sería** si el bloque se difundió antes de persistirse. Incumple la letra de «Relanzamiento» punto 4 de `ORDEN-W06d1` | **Corrección dentro de W06d2** (avisada a su ejecutor): persistir antes de admitir también en PoST; difundir solo después de persistir; prueba con punto de inyección de fallo |
| — | Descartado con motivo: `ServicioPot::insertar_calculado` no re-verifica salidas al reconstruir, pero `pot_output` está cubierto por `block_hash` y `zx-storage` recalcula ese hash al abrir y al leer | De acuerdo | — |

La prueba dirigida (10 rondas de `SIGKILL` en régimen, 0 colisiones `(productor, slot)`) **no** descarta
el hallazgo: la ventana es la de un `WriteBatch` con `fsync` (milisegundos) y una espera aleatoria rara vez
cae en ella. Por eso la corrección pide un punto de inyección de fallo.
