# INFORME RI-2b — revisión independiente de `zx-storage`, `zx-post/{productor_regimen,servicio_pot}` y `zx-node`

**Revisor:** RI-2b (subagente Claude Sonnet). **Fecha:** 2026-09-26. **Alcance:** `crates/zx-storage/`,
`crates/zx-post/src/{productor_regimen.rs, servicio_pot.rs}`, `crates/zx-node/` (commit `4042821` o
posterior de la raíz, más el commit `c715c4b` visible al arrancar). Método: `ORDEN-RI-2.md` +
`ORDEN-RI-1.md` §«Qué buscar»/«Método». Zona escribible: `deepseek/RI-2b/` (esta). No se tocó
`deepseek/W06d2/` ni ninguna otra zona. Sin Python, sin credenciales, sin subagentes/forks.

## Tabla de hallazgos

| Gravedad | Estado | Archivo:línea | Descripción |
|---|---|---|---|
| **Alta** (crítica en cuanto exista red, W06d2) | **PLAUSIBLE** | `crates/zx-node/src/nodo.rs:555-568` (`admitir_post_interno`) | Admite el bloque PoST en `zx-cadena` (memoria) **antes** de persistirlo en `zx-storage`, al revés que `admitir_pow_interno` (`nodo.rs:395-414`, que persiste primero y documenta por qué); un `SIGKILL` entre las dos deja el bloque «producido» en memoria pero fuera del almacén, y como el `ServicioPot` se reconstruye solo desde lo persistido (D-N03′), el mismo slot vuelve a estar disponible y, con PoT de un solo flujo determinista (D-P10), la misma clave puede volver a ganar y firmar un **segundo** bloque distinto para el mismo slot: doble firma tras reinicio, justo lo que `ORDEN-W06d1` «Relanzamiento» punto 4 dice que no debe poder pasar. |

No se encontró ningún otro hallazgo de gravedad media o alta. Los detalles de lo investigado y
descartado están en la sección «Revisado sin hallazgos».

## Detalle del hallazgo

### H1 — Orden invertido `cadena.admitir` / `almacen.admitir` en `admitir_post_interno`

**Archivo:** `crates/zx-node/src/nodo.rs`, función `admitir_post_interno`, líneas 555-568.

```rust
let ya_admitido = self.cadena.es_valido(&hash) || self.cadena.motivo(&hash).is_some();
if !ya_admitido {
    self.cadena.admitir(BloqueCadena::Post(post))...?;   // (1) memoria, primero
}
if !ya_admitido && verificar {
    let admitido = BloqueAdmitido::post(&bloque);
    self.almacen.admitir(&admitido, true)?;               // (2) disco, después
}
```

Contrástese con `admitir_pow_interno` (líneas 395-414), que hace exactamente lo contrario y lo
explica en su propio comentario:

```rust
// Persistencia (D-N03′) **antes** de admitir en `zx-cadena`: si el proceso muere entre
// las dos, el reinicio repite desde el almacén y vuelve a llegar aquí con `ya_admitido`
// falso otra vez ...; al revés (admitir en memoria y morir antes de persistir) perdería
// el bloque sin dejar rastro.
if verificar {
    let admitido = BloqueAdmitido::pow(&cabecera, &txs, &testigos);
    self.almacen.admitir(&admitido, true)?;
}
...
self.cadena.admitir(BloqueCadena::Pow(bt))...?;
```

**Por qué importa solo para PoST.** `Cadena` es puramente en memoria (`crates/zx-cadena/src/cadena.rs`:
`es_valido`/`motivo` son *lookups* sobre `BTreeMap`, sin E/S); cualquier `SIGKILL` la pierde entera,
la sobreviva o no el almacén. Para un bloque **PoW** propio, perder «sin dejar rastro» un bloque ya
admitido en memoria pero no persistido solo cuesta volver a minarlo (memoryless, sin identidad ligada
al slot). Para un bloque **PoST**, el bloque lleva la firma de una clave **para un slot concreto**, y
el mecanismo que evita que esa clave vuelva a firmar ese mismo slot tras reiniciar es, a falta de un
firmante durable (`ORDEN-W06d1` «Relanzamiento» punto 4), puramente indirecto: el `ServicioPot` se
reconstruye al reiniciar **solo** a partir de lo que hay en el almacén (`admitir_post_interno` →
`actualizar_servicio_verificacion` → `ServicioPot::insertar_calculado`, `servicio_pot.rs:316-333`), y
el productor (`regimen.rs`, `hilo_productor_regimen`) solo avanza monótonamente desde
`servicio.slot_actual()`.

**Escenario concreto.** Con 3 claves y `SR_dev` generoso (como en `tests/reinicio.rs`/`integracion.rs`):

1. La clave `K` gana la auditoría del slot `S`; `hilo_productor_regimen` produce y firma el bloque
   `B` (`regimen.rs:211-224`) y lo envía al bucle.
2. `admitir_post_interno(B, ..., verificar=true)` ejecuta `self.cadena.admitir(...)` → `Ok`: `B`
   queda válido en la `Cadena` en memoria (tip, tips_validas lo verá, etc.).
3. `SIGKILL` llega **antes** de que `self.almacen.admitir(&admitido, true)` complete su
   `WriteBatch`/`fsync`. `B` nunca llega al disco.
4. Al reiniciar, `Nodo::arrancar` reconstruye `Cadena` y `ServicioPot` **solo** desde
   `AlmacenEnDisco::repetir` (D-N03′): `B` no existe en ningún sitio; `servicio.slot_actual()` queda
   por debajo de `S` (en el último slot que sí se persistió).
5. `hilo_productor_regimen` avanza el PoT determinista (D-P10, un solo flujo) hasta `S` de nuevo; con
   la misma parcela y la misma salida PoT, `K` **vuelve a ganar** la auditoría del slot `S`
   (determinista) y produce un bloque `B'` distinto de `B` (mismo slot, mismo padre esperado, pero
   `timestamp` de pared distinto ⇒ `pre_hash`/sello distintos ⇒ `block_hash` distinto).
6. Si esta segunda vez el proceso no muere en la misma ventana, `B'` se persiste con éxito. El
   almacén acumulado (que sobrevive a todos los reinicios del mismo directorio) queda con **dos**
   bloques PoST distintos, de la **misma clave**, para el **mismo slot**: una equivocación real.

**Intento de reproducción empírica (no concluyente).** Se escribió
`deepseek/RI-2b/ws/crates/zx-node/tests/ri2b_doble_firma.rs` (copia en esta zona, `CARGO_HOME`/
`CARGO_TARGET_DIR` en la zona, `--locked`, `-j 4`), que relanza el binario real `zx-node` (`N_dev`
pequeño, `SR_dev = u64::MAX`, 3 claves) repetidas veces con `SIGKILL` en régimen —cada ronda exige
progreso real (≥ 1 `bloque_producido` nuevo) antes de matar— y comprueba al reabrir que ningún par
`(productor, slot)` se repite en `Cadena::bloques_post()` acumulado. Resultado de 10 rondas
(`run3.log`, `finished in 625.05s`, `test result: ok`): **no se observó ninguna colisión**. La ventana
de la carrera es la duración de un `WriteBatch` de RocksDB con `sync=true` (típicamente
submilisegundos a pocos milisegundos): un `SIGKILL` disparado con una espera aleatoria de 0-4 ms tras
confirmar el bloque anterior tiene una probabilidad baja de caer exactamente ahí, así que 10 rondas no
son evidencia de ausencia. Se etiqueta **PLAUSIBLE**, no CONFIRMADO, con el razonamiento de código
como evidencia principal (el propio comentario de `admitir_pow_interno` describe, para el caso PoW, el
mecanismo exacto que aquí falta para PoST) y un intento de reproducción documentado que no lo
descarta.

**Nota relacionada (no es un hallazgo aparte):** `arranque_limpio` (líneas 201-226) tiene el mismo
orden (`cadena.admitir` antes de `almacen.admitir`), pero es inofensivo: el génesis es fijo y
determinista (no lleva firma ligada a un slot), así que perderlo «sin rastro» solo hace que
`arranque_limpio` se repita idéntico en el siguiente arranque.

**Corrección sugerida (no aplicada; fuera del mandato de RI-2b, solo lectura):** invertir el orden en
`admitir_post_interno` igual que en `admitir_pow_interno` —persistir en `almacen` primero, admitir en
`cadena` después—, documentando por qué (mismo argumento que el comentario ya existente). Añadir a
`tests/reinicio.rs` (o conservar `ri2b_doble_firma.rs`) la comprobación de que ningún `(productor,
slot)` se repite tras muchos ciclos de `SIGKILL` en régimen.

## Revisado sin hallazgos

Investigado explícitamente y descartado como defecto:

- **`ServicioPot::insertar_calculado` acepta `salida`/`portador` sin re-verificar** (`servicio_pot.rs`
  :299-333; ver también `actualizar_servicio_verificacion`, `nodo.rs:585-620`). Es exactamente el
  patrón que `ORDEN-RI-2` pide vigilar («reconstrucción del PoT que acepte salidas no verificadas»),
  pero es seguro: `pot_output` es parte de la prefirma cubierta por `block_hash`
  (`crates/zx-core/src/preimage/dag.rs:355-406`, `DagBlockHeader::escribir`/`block_hash`), y
  `zx-storage` recalcula ese hash al abrir y al leer (`formato.rs:hash_canonico`,
  `disco.rs:leer_verificado`/`verificar_estructura`); un `pot_output` alterado en disco se detecta
  como `StorageError` antes de llegar a `insertar_calculado`. El contrato es correcto siempre que el
  bloque se verificara una vez con `verificar_cabecera_conjunta` antes de persistirse, que es lo que
  ocurre en la ruta en vivo.
- **`zx-storage` (`almacen.rs`, `formato.rs`, `memoria.rs`, `disco.rs`, `error.rs`):** atomicidad,
  idempotencia, integridad (hash + compromiso del cuerpo) y repetición en orden se leyeron enteros;
  coinciden con `README.md` y con `ORDEN-W06b.md`. `matar_a_mitad.rs` (64 rondas de `SIGKILL` real
  contra RocksDB) y `propiedades.rs` (V6, `proptest` con semilla fija, más el diferencial
  memoria/disco) cubren exactamente lo que dicen. Sin hallazgos.
- **`crates/zx-post/src/productor_regimen.rs`:** validaciones de padres/slot/rango/clave contra la
  solución están completas; el cuerpo de `tests/regimen.rs` (V4/V5, contextos reales: GHOSTDAG real,
  `ServicioPot` real, `zx-farmer` real) las ejercita con bastante variedad (hermanos, fusión de 3
  ramas, hueco máximo de 150, negativos). Sin hallazgos.
- **`padres_de_regimen`** (`crates/zx-node/src/padres.rs`) trunca `tips_validas()` a 15: se comprobó
  que `Cadena::tips_validas()` (`crates/zx-cadena/src/cadena.rs:527-554`) ordena por hash
  (`sort_unstable`) antes de devolver, así que el truncamiento es determinista entre nodos con el
  mismo conjunto de puntas válidas (no es un defecto, aunque el archivo pertenece a `zx-cadena`,
  fuera de mi alcance directo).
- **Doble depósito por clave, reinicio con testigo PoW corrupto, negativa fuera de `Red::Dev`, tubería
  única, hilos con `unwrap`/`panic` convertidos a error fatal:** revisados en `pow.rs`, `regimen.rs`,
  `error.rs`, `cli.rs`, `main.rs`, `perfil.rs`, `claves.rs`, `identidad.rs`, `estado_resumen.rs`,
  `registro.rs`; sin hallazgos. `registro.rs` tiene un campo `primero` que ya no cumple su función
  literal (siempre queda en `true`) tras la corrección documentada de la coma que falta; es
  funcionalmente correcto (siempre añade la coma que hace falta) pero el nombre confunde — cosmético,
  no se reporta como hallazgo.

## Leído entero

`crates/zx-storage/src/{lib.rs, almacen.rs, formato.rs, memoria.rs, disco.rs, error.rs}`,
`crates/zx-storage/tests/{matar_a_mitad.rs, propiedades.rs}`, `crates/zx-storage/README.md`,
`crates/zx-storage/Cargo.toml`; `crates/zx-post/src/{productor_regimen.rs, servicio_pot.rs}`;
`crates/zx-node/src/{nodo.rs, regimen.rs, padres.rs, pow.rs, registro.rs, perfil.rs, identidad.rs,
main.rs, lib.rs, cli.rs, error.rs, estado_resumen.rs, claves.rs}`; `crates/zx-node/tests/{reinicio.rs,
integracion.rs, padres_maximos.rs, red_no_dev.rs}`; `crates/zx-post/tests/regimen.rs`;
`P-ZRX/P-REVISION-CODIGO/ORDEN-RI-2.md`, `ORDEN-RI-1.md`; `V-ZRX/LINEO.md`; `P-ZRX/P-NODO/PLAN-W06.md`,
`ORDEN-W06b.md`, `ORDEN-W06d1.md`; `P-ZRX/P-DAG/DECISIONES-W05.md`; `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`.

## Muestreado (no leído entero; fuera del alcance exacto de RI-2b)

`crates/zx-cadena/src/cadena.rs` (solo `tips_validas`, `mejor_punta`, `es_valido`, `motivo`, para
verificar una afirmación usada por `zx-node/src/padres.rs`); `crates/zx-core/src/preimage/dag.rs`
(solo `DagBlockHeader::escribir`/`block_hash`, para descartar el punto de «salidas PoT no
verificadas»); `crates/zx-post/tests/{pot_slot.rs, pot_derivaciones.rs, cabecera_conjunta.rs,
extremo_a_extremo.rs, flow.rs, justificacion.rs, pot_rango.rs}` (listados, no leídos: prueban
`pot.rs`/`cabecera_conjunta.rs`, fuera de mi lista de archivos).

## Reproducción

Copia de trabajo en `deepseek/RI-2b/ws/` (tar de la raíz sin `PDF/deepseek/target/.git`, con enlace
`ws/PDF`), `CARGO_HOME`/`CARGO_TARGET_DIR` en `deepseek/RI-2b/` (caché copiada de
`deepseek/W06bR/.cargo-home`), `--locked`, `-j 4`/`-j 8`. Comandos y resultado del intento de
reproducción de H1:

```
cd deepseek/RI-2b/ws
CARGO_HOME=.../deepseek/RI-2b/.cargo-home CARGO_TARGET_DIR=.../deepseek/RI-2b/target \
  cargo test -p zx-node --test ri2b_doble_firma --locked -j 4 -- --nocapture
...
test sigkill_repetido_en_regimen_no_debe_producir_dos_bloques_del_mismo_slot_por_la_misma_clave ... ok
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 625.05s
```

(10 rondas de `SIGKILL` en régimen, cada una con progreso real forzado; 0 colisiones `(productor,
slot)` observadas — no reproduce H1, no lo descarta; ver razonamiento arriba.)

Presupuesto usado: ~2 h de reloj (compilación de `librocksdb-sys` + dos rondas de la prueba dirigida
incluidas).
