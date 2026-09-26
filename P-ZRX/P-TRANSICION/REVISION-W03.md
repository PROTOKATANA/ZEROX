# Revisión del director — W03 y W03-R (2026-09-26)

**Veredicto: SUPERADO y migrado a la raíz** (03:22). DeepSeek: W03 02:26–02:56; rebase W03-R
02:58–03:21.

- Motor de transición en `crates/zx-consensus/src/transicion/` sobre tipos reales: `aplicar`
  (estricto), `aplicar_fusion` (descarte con motivo y coinbase recortada), undo por delta,
  `seleccionar` (FC-3), `nodo_en_linea` (`C-FIN-01`).
- **Diferencial contra el oráculo T01: 2 055 casos (1 947 con fase PoST), 0 discrepancias**, con
  transacciones reales firmadas y las correspondencias fijadas por la orden, repetido tras el rebase
  sobre la raíz combinada (516 tests, 0 fallos).
- Lock: una única línea añadida (`ed25519-zebra` en `zx-consensus`), sin cambios de versión.
- El rebase resolvió una vez el workspace padre por error (su primer `cargo metadata`); **comprobado
  por el director**: el `Cargo.lock` de la raíz no cambió (`git diff` vacío).

**Hallazgo que corrige al director:** el diferencial real destapó que el formato v0 no daba `txid`
únicos a la coinbase PoW y permitía **repetir** retiros y liberaciones de garantía
(`FORMATO-v0.md` §«Corrección v0.1»). El motor migrado todavía usa el contador de salidas de
liberación (`prox_salida`) que W03 añadió para sortearlo; lo elimina W02b junto con el nonce por clave.

**Pendiente:** recuperar el test retirado en W05a si no lo hizo W03 (verificado: W03 añade el test de
testigo en `transicion/tests.rs`); diferencial de `aplicar_fusion` contra T04 (W06a); vectores
negativos de T01-C y de repetición de T01-D (W02b).
