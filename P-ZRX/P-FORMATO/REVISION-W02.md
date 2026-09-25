# Revisión del director — W02 (2026-09-26)

**Veredicto: SUPERADO y migrado a la raíz** (01:36). DeepSeek, sesión 01:23–01:35.

Revisado por el director en el código entregado:
- `txid` (`preimage/tx.rs`): los tres sub-digest antiguos intactos; `extension_digest` solo para
  v2/v3 con `"ZZKTxIdGarantia_"` y los campos de F-05 en orden — conforme a F-06.
- Firma de aceptación: `H_d("ZZKTxSigGarant__", txid)` verificada con ZIP-215 — conforme a F-08.
- `forma.rs::validar_forma_tx`: versiones 1–3 activas, 4 inactiva, resto desconocidas; recuentos
  por versión y tipo; importe > 0; testigo de aceptación de 64 B; `lock_time`/`expiry_height` = 0;
  sin `Htlc` — conforme a F-05, F-07, F-08, F-10. `validar_forma_cabecera_post` rechaza
  `height ≠ 0` (F-03).
- Parser (`wire.rs`): rechaza 4 y desconocidas al leer; la extensión se lee según la versión; el
  importe se lee como `i64` LE y `Amount::nuevo` rechaza negativos y > límite, así que un `u64`
  por encima de `i64::MAX` no se acepta.
- `Red::Dev`: magia `db347847`, `CBID_RED_DEV = a8b466a7`, HRP `dzzk`, recalculados en test.
- Base de DeepSeek (`ws.orig`) idéntica a la raíz antes de migrar; `MIGRACION.sha256` (54 archivos)
  verificado en la raíz tras copiar.

Faltas de definición que señaló el ejecutor, aceptadas: un tercer `txid` v1 anclado desde el
escenario `tx_ejemplo()` del código antiguo (solo había dos literales); inserción mecánica de
`extension: ExtensionTx::Ninguna` en literales de test (ningún vector cambió); el parser devuelve el
resto por diseño.

**Observación para W03:** una v1 sin entradas y sin salidas pasa `validar_forma_tx` como candidata
a coinbase PoW; W03 debe exigir al menos una salida en la coinbase PoW (la del génesis tiene una
salida de valor 0).

Oráculo Julia: `P-ZRX/P-FORMATO/oraculo-formato-v0/` (instrumento preliminar; no promovido a
`V-ZRX/`). Evidencia: `P-ZRX/P-FORMATO/resultados-W02/`.
