# INFORME.md — ORDEN-W06b

**ID:** W06b. **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek Harness, `deepseek-flash`, esfuerzo
`high`. **Zona única:** `/home/katana/zeo/ZEROX/deepseek/W06b/`.
**Entrada:** `P-ZRX/P-NODO/ENTRADA-W06b.sha256` verificado (4/4 sumas correctas) antes de escribir
código.

## 1. Veredicto

**CUMPLIDO.** Se creó el crate `zx-storage` (D‑N03′) con un almacén de bloques admitidos y registro
de admisión sobre RocksDB (feature `rocksdb`) y una implementación en memoria con el mismo rasgo.
La pregunta falsable se responde en los ocho pasos de verificación: el almacén reabre con un prefijo
exacto tras `SIGKILL` en 64 puntos distintos, denuncia explícitamente las tres corrupciones
inyectadas, y la repetición entrega los bloques en el orden del registro y con los mismos bytes
(propiedad con semilla fija y test diferencial memoria↔disco). El lock solo añade 17 paquetes, todos
a la versión del lock de `9681061`, sin cambiar ninguna versión existente.

Tras la **Corrección A**, la integridad cubre además el **cuerpo** del bloque: al abrir y al leer se
recalcula el compromiso que declara la cabecera —`merkle_root(txids)` en PoW y `body_commitment`
sobre `(txid, auth_digest)` en PoST— y, si no coincide, se devuelve `StorageError::CuerpoNoCoincide`
sin reparación. Se documenta el límite del PoW (los testigos no entran en `merkle_root`) y se cubre
con tests nuevos.

## 1bis. Corrección A — la integridad debe cubrir el cuerpo del bloque

**Qué evidencia falló.** `formato.rs::hash_canonico` comprobaba que los bytes decodifican en forma
canónica y que el hash de la **cabecera** coincide con la clave, pero **no recalculaba** el
compromiso del cuerpo que la cabecera declara. Un bit cambiado dentro de una transacción (p. ej. el
importe o el destino de la coinbase, que no lleva firma) decodificaba bien, dejaba el `block_hash`
intacto y pasaba la integridad; como la repetición no re-verifica cabeceras (D-N03′), el nodo
reconstruiría **en silencio** un estado distinto. V5 no lo detectaba porque sus corrupciones tocaban
la cabecera, `registro` o `meta`. La causa fue la letra de la orden («integridad por hash»), error
del director.

**Qué cambió.**

- `src/formato.rs`: `hash_canonico` recalcula ahora el compromiso del cuerpo con el código de
  `zx-core` (no se reimplementa) y lo compara con el de la cabecera:
  - **PoW:** `merkle_root(txids)` (con `txid(tx, consensus_branch_id)`) contra
    `cabecera.merkle_root`.
  - **PoST:** `body_commitment(txs, testigos, cbid)` sobre `(txid, auth_digest)` contra
    `cabecera.body_commitment`.
  Como `hash_canonico` es la única rutina de decodificación validada, el recálculo alcanza la
  **lectura** (`disco::bloque` → `hash_de_valor`) y la **apertura** (`verificar_estructura` →
  `leer_verificado`), y también `BloqueAdmitido::desde_canonicos`/`desde_almacen`.
- `src/error.rs`: variante nueva `StorageError::CuerpoNoCoincide`, explícita y sin reparación.
- El módulo `formato.rs` y el `README.md` documentan qué **no** cubre el compromiso PoW: los
  testigos quedan fuera de `merkle_root` porque el `txid` los excluye (C-TX-01). Un testigo PoW
  cambiado no altera `block_hash` ni `merkle_root`, así que el almacén **no** puede verlo; lo detecta
  la **verificación de firmas del motor al re-aplicar** la transacción en la repetición (D-N03′).
  En PoST sí queda cubierto por `body_commitment`.
- Fixtures de `disco.rs`, `memoria.rs`, `propiedades.rs`, `matar_a_mitad.rs` y
  `examples/medir_almacen.rs` rehechos para que cada cabecera declare el compromiso real de su
  cuerpo; antes usaban raíces ficticias con cuerpos vacíos.

**Tests V5 nuevos** (`src/disco.rs`):

| Caso | Cuerpo alterado | Resultado |
|---|---|---|
| (a) | importe de la coinbase de un bloque **PoW** | `CuerpoNoCoincide` al leer y al reabrir |
| (b) | importe de la coinbase **v3** de un bloque **PoST** | `CuerpoNoCoincide` al leer y al reabrir |
| (c) | campo (importe de salida) de una tx **no coinbase** de un bloque PoST | `CuerpoNoCoincide` al leer y al reabrir |
| (d) | testigo de un bloque **PoST** | `CuerpoNoCoincide` al leer y al reabrir |
| (e) | testigo de un bloque **PoW** | el almacén **no** lo detecta (no está comprometido); la repetición lo entrega y el motor lo rechazará al verificar la firma |

La inyección se hace escribiendo el cuerpo recodificado bajo la misma clave (`put_cf` directo), que
es exactamente el escenario de corrupción de bytes que V5 debe cazar.

## 2. Qué se construyó

`ws/crates/zx-storage`, dependiente **solo** de `zx-core` (más `thiserror` y, tras la feature
opcional, `rocksdb = "=0.25.0"`):

| Fichero | Responsabilidad |
|---|---|
| `src/error.rs` | `StorageError`: corrupto, red distinta, génesis distinto, versión de esquema, hueco del registro, entrada sin bloque, hash que no coincide, **cuerpo que no coincide**, backend |
| `src/formato.rs` | Sobre `familia(1) ‖ canónicos`; familias `Pow`(0x01)/`Post`(0x02); recálculo del hash con `zx-core` exigiendo forma canónica **y del compromiso del cuerpo** (`merkle_root` PoW / `body_commitment` PoST) |
| `src/almacen.rs` | Rasgo `Almacen` (`admitir`, `bloque`, `repetir`, `longitud_registro`, `sincronizar`), `BloqueAdmitido`, `ErrorRepeticion` |
| `src/memoria.rs` | `AlmacenEnMemoria`, la referencia para los tests rápidos |
| `src/disco.rs` | `AlmacenEnDisco` sobre RocksDB (feature `rocksdb`) |
| `tests/matar_a_mitad.rs` | V4: `SIGKILL` en 64 puntos pseudoaleatorios con semilla fija |
| `tests/propiedades.rs` | V6 (proptest, semilla fija) y diferencial memoria↔disco |
| `examples/medir_almacen.rs` | V7: medición release de 10 000 bloques |

### Esquema y decisiones

- **Familias de columnas** (§4.2): `bloques` (`block_hash`(32) → `familia`(1) ‖ canónico), `registro`
  (índice `u64` BE → `block_hash`(32)), `meta` (`red`, `genesis`, `version_esquema`).
- **Atomicidad** (§4.3): cada admisión es **un** `WriteBatch` (bloque + entrada de registro) con
  `WriteOptions::set_sync(sync)`; `sync = true` en los tests de muerte.
- **Idempotencia** (§4.3): admitir dos veces el mismo hash no añade entrada; si los bytes ya
  guardados difieren, se denuncia como corrupción. En disco, la comprobación de duplicado y la
  asignación del índice van **dentro del mismo lock**, así que dos hilos que admitan a la vez el
  mismo bloque dejan una sola entrada (hay test de concurrencia para el mismo hash y para hashes
  distintos).
- **Integridad** (§4.4): al abrir se recorre el registro exigiendo contigüidad desde `0` y que cada
  entrada tenga su bloque con el hash correcto; al leer se recalcula el hash **y, en ambos, el
  compromiso del cuerpo** (`merkle_root` PoW / `body_commitment` PoST, Corrección A). Sin reparación
  silenciosa: un hueco, una entrada sin bloque, un hash que no cuadra o un cuerpo que no reproduce su
  compromiso son error.
- **Repetición** (§4.5): recorre el registro en orden, entrega `(block_hash, familia ‖ canónicos)` y
  se detiene en el primer error del destino.
- **Apertura con otra red u otro génesis** (§4.2): error, sin reescritura. Un almacén con datos y
  sin marca de esquema también es corrupción (no se «inicializa» por encima).

### Aclaración: el sobre de familia (punto no fijado en la orden)

Los códecs canónicos PoW (`wire::cuerpo_a_bytes`) y PoST (`wire_dag::bloque_dag_a_bytes`) empiezan
por el mismo `consensus_branch_id` de 4 bytes; un valor indexado solo por `block_hash` no dice a qué
familia pertenece, y FORMATO‑v0 F‑04 prohíbe adivinarlo. Por eso el valor guardado lleva delante un
discriminante de 1 byte, con el mismo patrón que el sobre versionado del `zx-storage` antiguo
(`almacen_admitidos_dag.rs`, `VERSION_ADMITIDOS_DAG`). `repetir` entrega ese valor completo, que se
reconstruye con `BloqueAdmitido::desde_almacen`. Esta decisión, junto a las otras tres faltas de
definición (función de admisión, índice inicial, claves de `meta`), se informó **antes** de editar y
se detalla en `PROGRESO.md` §2.

## 3. Portado del antiguo (§4.6)

Se tomó **solo** lo que servía; el resto (UTXO en disco, cadena lineal, candidatos DAG) **no** se
portó, y además la frontera prohíbe las dependencias que exigiría (`zx-consensus`, `zx-dag`).

| Origen en `9681061` | Líneas | Qué se tomó |
|---|---|---|
| `crates/zx-storage/src/disco.rs` | 96–131 | Apertura: `create_if_missing`, `create_missing_column_families`, `DBRecoveryMode::PointInTime` explícito y con su justificación (no `AbsoluteConsistency`), y `ColumnFamilyDescriptor` por familia |
| `crates/zx-storage/src/disco.rs` | 134–139 | Helper `cf()` que traduce una familia ausente en error, no en pánico |
| `crates/zx-storage/src/disco.rs` | 153, 262–266 | Patrón de `WriteBatch` como una sola operación lógica (aquí bloque + registro) |
| `crates/zx-storage/src/almacen_admitidos_dag.rs` | 61, 95–115 | Sobre con discriminante de versión/familia y decodificador que exige uno conocido (`split_first`), sin reinterpretar |
| `crates/zx-storage/src/almacen_admitidos_dag.rs` | 136–148 | Comprobación de que el bloque decodificado corresponde a la clave (`block_hash`) |
| `crates/zx-storage/src/memoria.rs` | 1–11 | La idea de la implementación de referencia como contraste del backend real |
| `crates/zx-storage/src/memoria.rs` | 70–75 | Traducir el lock envenenado a error en vez de propagar el pánico |
| `crates/zx-storage/src/error.rs` | 10, 58–63, 87 | Forma de `StorageError` (`Corrupto`, `Backend`) |
| `crates/zx-storage/src/formato.rs` | 14, 252–282 | Principio de codificación inyectiva y de no aceptar bytes crudos |
| `crates/zx-storage/tests/matar_a_mitad.rs` | 60, 93–135, 137–186, 190–241 | Patrón completo: variable de entorno, re-ejecución del propio binario, `AVANCE`, `current_exe`, `Command`, lectura de la primera señal, `kill`+`wait`, comprobación del invariante al reabrir |

Lo **no** portado, explícitamente: `utxo.rs` y el UTXO en disco, `almacen.rs` (cadena lineal y
punta), `almacen_dag.rs` (cola de candidatos), el índice de solo lectura `AlmacenAdmitidosDag` y el
`formato.rs` de entradas UTXO. La orden de admisión y el registro son nuevos.

## 4. Verificación (V1–V8)

| Paso | Comando / qué | Resultado | Log |
|---|---|---|---|
| V1 | `cargo fmt --all -- --check` | limpio | `logs/V1-fmt.log` |
| V2 | `cargo clippy --workspace --all-targets --locked -- -D warnings` | limpio | `logs/V2-clippy-sin-rocksdb.log` |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | limpio | `logs/V2-clippy-con-rocksdb.log` |
| V3 | `cargo test --workspace --all-features --locked` | **650 pasan, 0 fallan, 1 ignorado** (41 binarios, ≈10 min) | `logs/V3-test.log` |
| V4 | `matar_a_mitad`: 64 rondas con `SIGKILL` y `sync=true` | siempre un prefijo exacto; 0 corrupciones no detectadas | `logs/V3b-storage-all-features.log` |
| V5 | Corrupción inyectada | error explícito en los tres casos + **4/4 de cuerpo (a)–(d)**; (e) fija el límite PoW | `src/disco.rs` (tests) |
| V6 | `proptest` con semilla fija (`ChaCha`, 256 casos) + diferencial memoria↔disco | sin fallos | `logs/V3b-storage-all-features.log`, `tests/propiedades.rs` |
| V7 | `cargo run --release -p zx-storage --features rocksdb --example medir_almacen` | medido, sin umbral | `logs/V7-medicion.log`, `logs/V7-entorno.log` |
| V8 | `ci/dependencias-exactas.sh` | `OK — 22 dependencias con versión exacta` | `logs/V8-dependencias.log` |
| V8 | `ci/frontera-crates.sh` | 7 fronteras OK, incluida `zx-storage → {zx-core}` | `logs/V8-frontera.log` |
| V8 | Lock | +17 paquetes, 0 eliminados, 0 versiones cambiadas, todos los añadidos a la versión de `9681061` | `logs/lock-diff.txt`, `logs/lock-analisis.txt` |

### V4 — detalle

El subproceso abre el almacén, admite bloques con `sync = true` y anuncia `AVANCE i`; el padre lee
la primera señal, espera un tiempo pseudoaleatorio (splitmix64 con semilla fija `0x57303662_5f6d6174`,
64 rondas) y lo mata con `SIGKILL`. Al reabrir se exige que el registro sea `0..n` contiguo, que
cada bloque sea exactamente el de la secuencia determinista y que `repetir` coincida. El test
comprueba además que hubo trabajo y que los puntos de muerte fueron distintos. 64 rondas en 1,59 s.

### V5 — detalle

- **Bit cambiado en un valor de `bloques`**: `bloque()` devuelve error y reabrir también.
- **Entrada del registro borrada**: reabrir devuelve `HuecoEnRegistro { esperado: 1, encontrado: 2 }`.
- **`meta` de otra red**: reabrir con `Red::Mainnet` sobre un almacén `Red::Dev` devuelve
  `RedDistinta`, y reabrir después con la red correcta conserva los datos (no se reescribió nada).
  También se prueba `GenesisDistinto` y `VersionEsquema`.
- **Cuerpo cambiado (Corrección A)**: los cinco casos (a)–(e) de la tabla de §1bis. (a)–(d)
  devuelven `CuerpoNoCoincide` al leer y al reabrir; (e) fija que un testigo PoW no está
  comprometido y el almacén lo acepta (lo detecta el motor al re-aplicar).

### V6 — detalle

Propiedad con `TestRng::from_seed(RngAlgorithm::ChaCha, &SEMILLA)` y 256 casos: una secuencia
aleatoria de hasta 64 etiquetas con duplicados, admitida en un `AlmacenEnMemoria`, produce una
repetición igual a la secuencia **sin duplicados** (primera aparición) y con los mismos bytes. El
diferencial repite la misma secuencia contra memoria y disco y exige resultados idénticos, también
tras reabrir el de disco.

### V7 — medición (release, un hilo)

Entorno: AMD Ryzen 9 9950X3D (16 núcleos / 32 hilos lógicos), 123 GiB de RAM; `rustc 1.97.0-nightly
(20de910db 2026-05-02)`; perfil `release` del workspace (`opt-level = 3`, `lto = true`,
`codegen-units = 1`). El ejemplo es monohilo; RocksDB puede usar sus hilos internos de fondo.
10 000 bloques PoW con una coinbase cada uno (1 500 000 bytes ≈ 1,43 MiB), `sync = false` durante la
alta y `flush` final.

| Fase | Tiempo | Ritmo |
|---|---:|---:|
| Alta (10 000 admisiones + flush) | 0,047 s | 211 358 admisiones/s · 30,24 MiB/s |
| Apertura con verificación completa | 0,043 s | 233 790 bloques/s |
| Repetición (10 000 bloques, con re-hash y recálculo del compromiso) | 0,025 s | 396 926 bloques/s · 56,78 MiB/s |

Sin umbral: la orden solo pide medir. Cifras de una corrida representativa (5 corridas: alta 0,047–0,056 s);
las cifras bajan respecto a la entrega previa porque ahora cada bloque tiene un `merkle_root` real (el
fixture lo calcula dentro del bucle de alta) y la apertura/repetición **recalculan el compromiso del
cuerpo** (Corrección A), que es trabajo nuevo y deliberado. La apertura y la repetición siguen siendo
del mismo orden que la alta porque el árbol cabe en caché; el coste real a escala lo fijará W07.

### V8 — lock

`cargo metadata --offline --format-version 1` una sola vez, sin `cargo update`. Paquetes añadidos:
`zx-storage`, `rocksdb 0.25.0`, `librocksdb-sys 0.19.0+11.8.1` y sus dependencias (`bindgen 0.72.1`,
`bzip2-sys 0.1.13+1.0.8`, `cexpr 0.6.0`, `clang-sys 1.9.1`, `itertools 0.13.0`, `jobserver 0.1.35`,
`libloading 0.8.9`, `libz-sys 1.1.29`, `lz4-sys 1.11.1+lz4-1.10.0`, `pkg-config 0.3.34`,
`rustflags 0.1.7`, `shlex 1.3.0`, `vcpkg 0.2.15`, `zstd-sys 2.1.0+zstd.1.5.7`); **17 en total, todas
a la versión del lock de `9681061`**; 0 eliminados y 0 versiones de paquetes existentes cambiadas.
Las únicas aristas de paquetes ya presentes que cambian son desambiguaciones (`itertools 0.14.0`,
`shlex 2.0.1`) y dos que restauran exactamente lo que `9681061` registraba (`cc` con `jobserver` y
`libc`, `data-encoding-macro-internal` con `syn 3.0.4`); ninguna cambia una versión.

## 5. Tests

`ws.orig` (raíz actual) `--list`: **631** tests. `ws --list`: **651**. **0 perdidos, 20 añadidos**
(14 unit de `disco`, 3 unit de `memoria`, 2 de propiedades/diferencial, 1 de `matar_a_mitad`); de
ellos, 15 son de W06b y 5 de la **Corrección A** (los V5 (a)–(e)). El recuento de V3 (650 pasan, 1
ignorado) incluye doc-tests; el único ignorado es un banco preexistente ajeno a este crate. Evidencia:
`logs/comparacion-tests.txt`.

## 6. Presupuesto

Declarado: 2 h 30 min de reloj, 8 hilos, 16 GiB. Consumo real: **≈ 23 min de reloj**, 8 jobs de
compilación, RAM pico observada ≤ 12 GiB; no agotado. `librocksdb-sys` se reutilizó de la caché de
compilación (target de L01, misma toolchain y mismas features), por lo que la compilación nativa no
dominó el presupuesto (debug `--all-features` 50 s; release del ejemplo 56 s).

La **Corrección A** declaró 45 min y consumió **≈ 20 min** de reloj (04:45–05:05), sin agotar el
presupuesto; las re-ejecuciones de V1–V3 usaron la caché de compilación existente.

## 7. Límites y lo no demostrado

- **No se re-verifican cabeceras ni PoT/PoAS**: es D‑N03′; el almacén local es de confianza y su
  integridad se comprueba por hash. Quien re-admita (W06d1) repite las transiciones.
- **Los testigos de un bloque PoW no están comprometidos** por `merkle_root` (el `txid` los excluye,
  C-TX-01): el almacén no puede detectar un testigo PoW cambiado. Es un límite **demostrado** por el
  test V5 (e), no un olvido; lo detecta la verificación de firmas del motor al re-aplicar. En PoST sí
  queda cubierto por `body_commitment`.
- **El reinicio es lineal en la historia**; no hay instantáneas (IPA E). V7 solo dice que 10 000
  bloques pequeños caben en caché y se repiten rápido, **no** que sirva para producción.
- **La corrupción se inyecta en tests unitarios** de `disco.rs` (bits, borrados y `meta`), no desde
  una API pública de mutación: el binario de producción no expone cómo corromper.
- **No hay borrado ni compactación** de bloques; el almacén solo crece (no lo pide la orden).
- La prueba de muerte usa 64 rondas y `sync = true`; una operación lógica partida en dos escrituras
  no se puede cazar de forma fiable con una carrera (lo advierte el test antiguo), pero aquí cada
  admisión hace **una sola** llamada a `write_opt`, y la cobertura estructural queda en el código.

## 8. Entregables

`ws.orig/`, `ws/` (enlace `ws/PDF` excluido), `cambios.patch` (14 ficheros, 109 413 bytes),
`MIGRACION.sha256` (166 huellas, `sha256sum -c` OK), `logs/`, `INFORME.md`, `PROGRESO.md`,
`HORAS.log` (marcas `date -Is` reales). El parche es exactamente
`diff -ruN -x target -x .cargo-home -x PDF ws.orig ws` (verificado con `cmp`). La corrección prohíbe
`git` y la máquina no tiene `patch`, así que no se aplica con herramienta externa; la verificación
estructural queda en `logs/patch-apply.log`. Sin commit ni push; nada fuera de la zona.
