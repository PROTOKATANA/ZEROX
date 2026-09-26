# CORRECCIÓN W06b-A — la integridad del almacén debe cubrir el cuerpo del bloque

**Fecha:** 2026-09-26. **Director:** Claude. Mismo ejecutor (DeepSeek), zona `deepseek/W06b/`, base y
límites que `ORDEN-W06b`. Se corrige **antes** de migrar.

## Qué evidencia falló

`crates/zx-storage/src/formato.rs::hash_canonico` (en `ws/`) comprueba que los bytes guardados
decodifican en forma canónica y que el hash de la **cabecera** coincide con la clave. El `block_hash`
**no** cubre el cuerpo más que a través del compromiso que la cabecera declara (`merkle_root` en la
cabecera PoW, F-01; `body_commitment` sobre `(txid, auth_digest)` en la cabecera PoST, F-02), y ese
compromiso **no se recalcula**. Un bit cambiado dentro de una transacción (p. ej. importe o destino de
la coinbase, que no lleva firma) decodifica bien, deja el hash de cabecera intacto y pasa la
integridad; como la repetición no re-verifica cabeceras (D-N03′), el nodo reconstruiría **en silencio**
un estado distinto. V5 no lo detectó porque sus corrupciones tocan la cabecera, `registro` o `meta`.
La causa está en la letra de la orden («integridad por hash», §2 y §4.4): error del director.

## Qué se espera cambiar

1. Al abrir y al leer, además de lo actual, recalcula el compromiso del cuerpo con el código de
   `zx-core` y compáralo con el de la cabecera: `merkle_root(txids)` para PoW;
   `body_commitment` (sobre `(txid, auth_digest)`) para PoST. Si no coincide, `StorageError`
   explícito (`CuerpoNoCoincide` o equivalente), sin reparación. Usa las funciones existentes de
   `zx-core` (`merkle_root`, `body_commitment`/`body_commitment_de_pares`); no reimplementes el cálculo.
2. Documenta qué **no** cubre el compromiso PoW (si los testigos quedan fuera del `merkle_root`, dilo y
   di qué lo detecta en la repetición: la verificación de firmas del motor al re-aplicar).
3. Tests nuevos de V5: bit cambiado en (a) el importe de la coinbase de un bloque PoW, (b) el de la
   coinbase v3 de un bloque PoST, (c) un campo de una transacción no coinbase de un bloque PoST, (d) un
   testigo de un bloque PoST. Cada uno ⇒ error explícito al abrir o al leer. (e) Si un testigo de un
   bloque PoW no está comprometido, un test que muestre qué ocurre y dónde se detecta.
4. Rehaz `cambios.patch`, `MIGRACION.sha256`, los registros afectados y añade «Corrección A» a
   `INFORME.md` y `PROGRESO.md`. V1–V3 y V8 se repiten.

Presupuesto: 45 min. Prohibido Python; nada fuera de la zona; sin git; sin secretos.
