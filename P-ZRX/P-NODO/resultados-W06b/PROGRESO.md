# PROGRESO.md — ORDEN-W06b

**ID:** W06b. **Ejecutor:** DeepSeek Harness, `deepseek-flash`, esfuerzo `high`.
**Zona única:** `/home/katana/zeo/ZEROX/deepseek/W06b/`. **Fecha:** 2026-09-26.
**Estado:** **CERRADO** — V1–V8 ejecutados; entregables generados. **Corrección A aplicada**
(integridad del cuerpo) y V1–V3/V5/V7/V8 re-ejecutados.

## 1. Crate `zx-storage` (D-N03′)

Implementado desde cero en `ws/crates/zx-storage`, dependiente **solo** de `zx-core` (más
`thiserror` y, tras la feature `rocksdb`, `rocksdb =0.25.0`). Esquema de tres familias
(`bloques`, `registro`, `meta`), admisión atómica por `WriteBatch`, idempotencia por hash,
integridad por recálculo del hash al abrir y al leer, y repetición en orden del registro.

- `src/error.rs` — `StorageError` (corrupto, red distinta, génesis distinto, versión de esquema,
  hueco del registro, entrada sin bloque, hash que no coincide, cuerpo que no coincide, backend).
- `src/formato.rs` — sobre `familia(1) ‖ canónicos`, familias `Pow`/`Post`, recálculo del hash **y
  del compromiso del cuerpo** (`merkle_root` PoW / `body_commitment` PoST) exigiendo forma canónica.
- `src/almacen.rs` — rasgo `Almacen`, `BloqueAdmitido`, `ErrorRepeticion`.
- `src/memoria.rs` — implementación de referencia.
- `src/disco.rs` — implementación sobre RocksDB (feature `rocksdb`).
- `tests/matar_a_mitad.rs` (V4), `tests/propiedades.rs` (V6 + diferencial), `examples/medir_almacen.rs` (V7).

## 2. Falta de definición detectada (informada antes de editar)

Cuatro puntos de `ORDEN-W06b` §4 no fijaban una decisión necesaria. Ninguno bloqueaba; se resolvió
cada uno con la opción mínima, documentada en el código:

1. **§4.2 no define el discriminante de familia** en `bloques`. Los dos códecs canónicos empiezan
   por el mismo `consensus_branch_id` y FORMATO‑v0 F‑04 prohíbe adivinar la familia. → Sobre de
   **1 byte** delante (`0x01` PoW, `0x02` PoST), con el precedente de `VERSION_ADMITIDOS_DAG` del
   `zx-storage` antiguo; `repetir` entrega el valor guardado completo.
2. **§4.3/§4.5 no fijan la función de admisión** (solo la firma de `repetir`). → Rasgo `Almacen`
   con `admitir(&self, bloque: &BloqueAdmitido<'_>, sync: bool)` y `BloqueAdmitido` tipado que
   codifica/decodifica con `zx-core`.
3. **El índice inicial del registro no se fija** («`u64` big-endian creciente»). → Empieza en `0`
   y se exige contigüidad estricta.
4. **Las claves de `meta` no se nombran.** → `red`, `genesis`, `version_esquema`; versión de
   esquema `1`.

## 3. Pasos

| Paso | Estado | Evidencia |
|---|---|---|
| V1 `fmt --check` | limpio | `logs/V1-fmt.log` |
| V2 clippy sin/con `rocksdb` | limpio | `logs/V2-clippy-sin-rocksdb.log`, `logs/V2-clippy-con-rocksdb.log` |
| V3 `test --workspace --all-features` | 650 pasan, 0 fallan, 1 ignorado | `logs/V3-test.log` |
| V4 `matar_a_mitad` (64 rondas) | pasa | `logs/V3b-storage-all-features.log` |
| V5 corrupción inyectada | 3/3 error explícito + 4/4 de cuerpo (a)–(d); (e) documenta el límite PoW | `src/disco.rs` (tests) |
| V6 proptest, semilla fija | pasa | `tests/propiedades.rs` |
| V7 medición release (10 000 bloques) | medido, sin umbral | `logs/V7-medicion.log` |
| V8 `dependencias-exactas`, `frontera-crates`, lock | OK | `logs/V8-*.log`, `logs/lock-analisis.txt` |
| 0 tests perdidos / 20 añadidos (15 de W06b + 5 de la Corrección A) | OK | `logs/comparacion-tests.txt` |

## 4. Entregables

`ws.orig/`, `ws/` (con `ws/PDF` excluido), `cambios.patch`, `MIGRACION.sha256` (166 huellas),
`logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`. El parche es exactamente
`diff -ruN -x target -x .cargo-home -x PDF ws.orig ws` (verificado con `cmp`; la corrección prohíbe
`git` y la máquina no tiene `patch`, así que no se aplica con herramienta externa:
`logs/patch-apply.log`), y `sha256sum -c` sobre `MIGRACION.sha256` es OK.

## 5. Corrección A — integridad del cuerpo (2026-09-26)

**Motivo.** `hash_canonico` no recalculaba el compromiso del cuerpo que declara la cabecera: un bit
cambiado dentro de una transacción dejaba el `block_hash` intacto y pasaba la integridad.

**Cambios.**

- `src/formato.rs`: `hash_canonico` recalcula `merkle_root(txids)` (PoW) y `body_commitment` sobre
  `(txid, auth_digest)` (PoST) con el código de `zx-core`, y los compara con la cabecera. Aplica al
  leer y al abrir (vía `hash_de_valor`) y a `desde_canonicos`/`desde_almacen`.
- `src/error.rs`: `StorageError::CuerpoNoCoincide`.
- Documentado el límite PoW: los testigos no entran en `merkle_root` (el `txid` los excluye); un
  testigo PoW cambiado lo detecta la verificación de firmas del motor al re-aplicar, no el almacén.
- Fixtures con compromisos reales en `disco.rs`, `memoria.rs`, `propiedades.rs`, `matar_a_mitad.rs` y
  el ejemplo de medición.
- 5 tests V5 nuevos en `src/disco.rs`: (a) importe coinbase PoW, (b) importe coinbase v3 PoST,
  (c) campo de tx no coinbase PoST, (d) testigo PoST ⇒ `CuerpoNoCoincide` al leer y al reabrir;
  (e) testigo PoW ⇒ el almacén no lo detecta (comportamiento fijado, no fingido).

**Registros rehechos.** `cambios.patch` (14 ficheros), `MIGRACION.sha256` (166 huellas),
`logs/V1-fmt.log`, `logs/V2-clippy-*.log`, `logs/V3-test.log`, `logs/V3b-storage-all-features.log`,
`logs/V7-*.log`, `logs/V8-*.log`, `logs/comparacion-tests.txt`, `logs/patch-apply.log`.

