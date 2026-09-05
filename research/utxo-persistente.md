# Persistencia del UTXO set — investigación con fuente primaria

**Fecha:** 2026-09-05 · **Para:** bloque B1 del plan de crates · **Método:** cinco agentes en
paralelo, uno por fuente. Ninguna afirmación de memoria; lo que no se encontró se declara laguna.

**Repos anclados:** `bitcoin/bitcoin @ v27.0` (`d8228395`) · `ZcashFoundation/zebra @ v6.3.0`
(`f5c5277f`) · `monero-project/monero @ v0.18.5.1` (`4f92268d`) · RocksDB 11.8.1, embebido vía
`librocksdb-sys 0.19.0` desde `rocksdb = "=0.25.0"`.

---

## 1 · Las tres arquitecturas

| | Bitcoin Core | zebra | Monero |
|---|---|---|---|
| Motor | LevelDB + ficheros planos | **RocksDB** | LMDB |
| UTXO en disco | `chainstate/`, clave = outpoint | `utxo_by_out_loc`, clave = **posición en cadena** (8 B) | `m_output_amounts` + `m_spent_keys` |
| ¿Revierte en disco? | **sí** | **nunca** | **sí**, con `pop_block` |
| Undo data | `rev*.dat`, ficheros planos | **no existe** | no: relee el bloque |
| Atomicidad | `CDBBatch` + marcador `DB_HEAD_BLOCKS` | un `WriteBatch` por bloque finalizado | transacción LMDB, **por lote de bloques** |
| Ventana no finalizada | — | **1 000 bloques en RAM** | — |

### Bitcoin: dos motores obligan a un marcador

`CCoinsViewDB::BatchWrite` (`src/txdb.cpp:91-150`) escribe `DB_HEAD_BLOCKS = [nuevo, viejo]` al
principio del batch y lo borra al final, junto con `DB_BEST_BLOCK`. Si al arrancar el marcador
sigue ahí, hubo un crash a mitad: `ReplayBlocks` (`src/validation.cpp:4550-4637`) desconecta y
reconecta hasta dejar la punta coherente.

El marcador existe porque **bloques y undo van en ficheros planos y el chainstate en LevelDB**: no
hay atomicidad posible entre los dos. Además el batch se parte si supera `-dbbatchsize` (16 MiB).

Y hay una vuelta de tuerca: el PR que introdujo esto, `bitcoin/bitcoin#10148`, **abandonó** el
flush atómico a propósito. sipa:

> *"Instead of relying on using atomic batch writes in LevelDB for the chainstate, we rely on the
> fact that we have an external log of updates to it already (called the blockchain)."*

### zebra: si no finalizas, no revierte

Reorgs 100 % en RAM (`NonFinalizedState`, árbol de `Chain`s). Solo cuando la mejor cadena supera
`MAX_BLOCK_REORG_HEIGHT = 1000` se congela el bloque más antiguo y se escribe, irrevocablemente.

Al gastarse una salida, su entrada **se borra** (`zebra_db/transparent.rs:695-699`,
`zs_delete(&utxo_by_out_loc, …)`). No hay undo porque no hace falta: lo que está en disco tiene
≥1 000 confirmaciones.

No hay clave "punta": el tip **se deriva** de la clave máxima de `hash_by_height`, que ya va en el
mismo batch (`zebra_db/block.rs:71-74`). Elegante — un dato menos que puede desincronizarse.

29 column families. La del UTXO se indexa por `OutputLocation` (3 B altura + 2 B índice de tx + 3 B
índice de salida = **8 bytes**), no por outpoint (36 B): permite barridos por rango, a cambio de
necesitar un índice txid→posición.

### Monero: revierte sobre estado persistido

Sin capa no finalizada. `pop_block` (`db_lmdb.cpp:4112-4129`) deshace directamente sobre LMDB,
reconstruyendo la reversión desde el propio bloque. **Laguna encontrada: no hay test unitario de
`pop_block` ni de `remove_spent_key`** en `tests/unit_tests/blockchain_db.cpp`.

Su transacción abarca **un lote entero de bloques** durante el sync (`blockchain.cpp:5070`), no un
bloque: garantía ACID más fuerte por transacción, granularidad más gruesa.

---

## 2 · RocksDB: qué garantiza de verdad

**Atómico entre column families.** Cita oficial, wiki de Column-Families:

> *"Atomic writes across Column Families are supported. This means you can atomically execute
> Write({cf1, key1, value1}, {cf2, key2, value2})"*
> *"By sharing write-ahead logs we get awesome benefit of atomic writes."*

**Caída de proceso ≠ caída de máquina.** El FAQ oficial las trata como dos preguntas distintas:

| | ¿Se pierde algo? |
|---|---|
| Muere el proceso, WAL activo | **no** — el `write()` ya entregó los bytes al SO |
| Cae la máquina o la corriente | se puede perder la cola de batches **no sincronizados**, siempre **enteros** |

Eso segundo es aceptable para una cadena: perder los últimos bloques de forma atómica es
«resincronizar», no «estado incoherente».

**`WALRecoveryMode`:** el default es `kPointInTimeRecovery` desde RocksDB 6.6, confirmado en
`include/rocksdb/options.h` y en `docs.rs/rocksdb/0.25.0`. **No usar `kAbsoluteConsistency`**:
`facebook/rocksdb#2871` (reproducido por PingCAP) muestra que convierte la cola truncada normal de
un `kill -9` en una base de datos **que no abre**.

**`atomic_flush`: no hace falta.** Comentario textual de `options.h`:

> *"it is not necessary to set atomic_flush to true if WAL is always enabled since WAL allows the
> database to be restored to the last persistent state in WAL. This option is useful when there are
> column families with writes NOT protected by WAL."*

**El riesgo no es RocksDB, es la frontera del batch.** La garantía es **por batch**, no por
operación lógica. Dos `db.write()` seguidos son dos átomos, no uno.

### Cómo lo usan en producción

- **TiKV** deja `wal-recovery-mode = "point-in-time"` en su plantilla de producción. Sí fuerza
  `sync-log = true`, pero **solo en su log de Raft**, no en el estado general.
- **TiKV, antipatrón documentado:** usa dos DB separadas (`raftdb`, `kvdb`) y por eso `tikv#6540`
  describe tener que hacer `fsync` de una antes que la otra **a mano**. Es exactamente lo que se
  evita manteniendo un solo `DB` con varias CFs.
- **Solana** hace configurable el `wal_recovery_mode` en tiempo de ejecución.
- **CockroachDB** abandonó RocksDB en 2020 — pero por el coste de mantener un binding CGo de 260k
  líneas, **no** por un defecto de atomicidad. No traslada a Rust.

---

## 3 · Cómo se ha roto esto en la vida real

| | Qué pasó | Qué obliga |
|---|---|---|
| `bitcoin#10693` | la recuperación tras el crash provoca el siguiente, por memoria. sipa: *"in general this problem is not solvable"* | acotar la reproducción |
| `bitcoin#33208` / `#33212` (**2025**) | un índice commiteado **por delante** del chainstate se corrompe tras apagado sucio | ningún índice derivado por delante de la punta finalizada |
| `go-ethereum#20238` (2019) | hueco entre freezer y LevelDB tras crash. `gap (#494) in the chain between ancients and leveldb` | tratar los dos almacenes como una transacción lógica |
| `go-ethereum#31499` (**2025**) | **el mismo bug otra vez**, al activar modo asíncrono por rendimiento | *"Probably sync mode is a safer choice anyway"* — el mantenedor |
| CVE-2018-17144 | una optimización saltó una comprobación «redundante» → **inflación**. El assert no saltaba si la salida venía de un bloque anterior | ninguna comprobación se salta por «ya se comprobó» |
| BIP-30 (2010) | coinbases duplicadas sobrescribían el UTXO. Revertirlas deja el original **perdido** | nunca sobrescribir un UTXO no gastado |
| **BIP-50** (marzo 2013) | **fork de red real**: un límite de locks de BerkeleyDB que LevelDB no tenía. Los nodos 0.7 rechazaron el bloque 225430, los 0.8 lo aceptaron | ningún límite incidental del motor puede decidir si un bloque se acepta |

**La respuesta a «¿molesto o catastrófico?»:** el agente buscó y **no encontró ni un caso** en que
una corrupción *pasiva* del UTXO set (bit rot, fallo de disco) causara un fork de red. Siempre fue
«un nodo se cae y resincroniza». El único fork real de la capa de almacenamiento fue **una
diferencia de comportamiento entre motores**, no datos corruptos.

**Y la mayoría de la corrupción real no es un bug.** maflcko, mantenedor, en `bitcoin#20117` y
`#12690`: *"Hardware defects might only become visible when running Bitcoin Core."*

### Lo que Bitcoin añadió por encima del motor

`gettxoutsetinfo` con `hash_serialized_2` y luego **MuHash incremental** (`bitcoin#19145`): un
checksum **lógico** del UTXO set entero. Los checksums de RocksDB detectan bytes corruptos; este
detecta **divergencia de contenido** entre dos nodos honestos. Anotado como candidato para B9.

---

## 4 · Probar la recuperación ante crash

RocksDB se prueba a sí mismo con `db_crashtest.py`, en dos modos: **blackbox** (`kill -9`) y
**whitebox** (`SyncPoint`, puntos de fallo antes y después de cada operación de sistema de
ficheros). Tiene incluso un target dedicado, `make crash_test_with_atomic_flush`.

**Laguna verificada, no supuesta:** el agente buscó `SyncPoint`, `sync_point` y `FaultInjection` en
el índice completo de la API de `rocksdb` 0.25.0 en docs.rs — **cero coincidencias**. La ruta
whitebox no está disponible desde Rust sin escribir C++ propio. Queda la blackbox.

**Y eso reduce el problema en vez de complicarlo.** Un test de `kill -9` en ZEROX **no debe
pretender demostrar que RocksDB es atómico** — eso ya lo demuestra su CI con años de fuzzing.
Debe detectar **un bug nuestro**: que una operación lógica se partió en más de un `db.write()`.

Diseño recomendado: un binario auxiliar que abre el almacén y avanza la punta en bucle; el test
padre lo mata con `SIGKILL` en un punto variable, reabre, y comprueba el invariante — que ningún
componente del estado va por delante de otro. Y, como manda la disciplina del proyecto: **verlo
fallar** con el bug presente antes de darlo por bueno.

---

## 5 · Qué se decidió con esto

En `DECISIONES.md §13`. En resumen: **el modelo de zebra con nuestra ventana de 99**, porque
`C-REORG-07` ya detiene el nodo más allá de esa profundidad y por tanto no hay nada que revertir.
El disco nunca revierte, no hay undo persistente, y toda operación lógica es **un solo
`WriteBatch`**.

---

## Lagunas declaradas

- Sin cifras oficiales de ops/seg para `sync=true` frente a `sync=false`. Lo único cuantificado por
  fuente primaria es la amplificación de escritura (~200× en el peor caso de la wiki).
- No se localizó test unitario de `ReplayBlocks` en Bitcoin ni de `pop_block` en Monero.
- El detalle causal del fork de marzo 2013 no está en el repo de Bitcoin: solo su consecuencia.
- No se encontró un proyecto Rust público que documente el patrón «subproceso + SIGKILL + reapertura
  + invariante»; el diseño del §4 es síntesis de la metodología de RocksDB más primitivas reales.
- No se profundizó en el layout de clave/valor de `m_output_amounts` de Monero.
