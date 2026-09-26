# ORDEN-W06b — `zx-storage`: almacén de bloques admitidos en RocksDB y reinicio por repetición

## 1. Identidad y contexto

- **ID:** W06b. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek. Se lanza tras
  migrar W02b; corre **en paralelo** a W06a (no depende de `zx-cadena`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06b/`.
- **Objetivo único:** crate `zx-storage` (nombre de D-P01) que guarda, con atomicidad y detección de
  corrupción, los bloques que el nodo admite y el orden en que los admitió, y que al reiniciar los
  entrega en ese orden a quien los re-admita. Decisión **D-N03′** (sustituye a D-N03, abajo).
- **Pregunta falsable:** «Tras cualquier secuencia de admisiones interrumpida por la muerte del
  proceso en un punto arbitrario, el almacén reabre con un prefijo exacto de lo confirmado (ni bloques
  a medias ni entradas del registro sin su bloque), rechaza con error explícito cualquier corrupción
  de bytes, y la repetición entrega los bloques en el mismo orden y con los mismos bytes.»

## 2. D-N03′ (decisión del director)

**Qué se persiste:** bloques admitidos (bytes canónicos) y el registro de admisión; **no** el estado
derivado (UTXO, garantía, GHOSTDAG). **Al reiniciar**, el nodo repite las admisiones en el orden del
registro sobre `zx-cadena` en memoria; las cabeceras **no** se re-verifican (el almacén local es de
confianza; su integridad se comprueba por hash). **Por qué:** la corrección del estado descansa en un
único código ya contrastado con los oráculos (W03, W06a) en vez de en un segundo camino de undo en
disco; IE-3 (independencia del orden) garantiza además que el orden de repetición no altera el
resultado. **Coste, dicho:** el reinicio es lineal en la historia (re-ejecutar transiciones, no
verificar PoT/PoAS); sirve para la red dev y **no** para producción, que necesitará instantáneas
(queda como hueco en IPA E). W07 mide el tiempo de reinicio.

## 3. Entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-NODO/PLAN-W06.md`; `P-ZRX/P-FORMATO/FORMATO-v0.md`
(con v0.1); del árbol antiguo `9681061` (con `git show 9681061:<ruta>`, sin restaurarlo):
`crates/zx-storage/src/{disco.rs, formato.rs, memoria.rs, error.rs, almacen_admitidos_dag.rs}`,
`crates/zx-storage/tests/matar_a_mitad.rs` y `crates/zx-storage/Cargo.toml`. Base: el workspace de la
raíz (tras W02b). Entrada congelada: `P-ZRX/P-NODO/ENTRADA-W06b.sha256`.

## 4. Decisiones del director

1. **Crate `zx-storage`** en `crates/zx-storage`, dependiente **solo** de `zx-core`; `rocksdb`
   `=0.25.0` (la versión exacta de `9681061`) detrás de la feature `rocksdb`, como en el antiguo; una
   implementación en memoria con el mismo rasgo para los tests rápidos.
2. **Esquema** (familias de columnas): `bloques` (`block_hash` → bytes canónicos del bloque completo,
   cabecera y transacciones, con su familia PoW/PoST), `registro` (`u64` big-endian creciente →
   `block_hash`), `meta` (red, hash del génesis, versión del esquema). Abrir con otra red u otro
   génesis ⇒ error, no reescritura.
3. **Atomicidad:** cada admisión es **un** `WriteBatch` (bloque + entrada del registro), con `sync`
   configurable (`true` en los tests de muerte). Admitir dos veces el mismo hash es idempotente y no
   añade entrada al registro.
4. **Integridad al abrir y al leer:** se recalcula el hash de cada bloque (con el código de
   `zx-core`) y se compara con la clave; un hueco en el registro, una entrada sin bloque o un hash
   que no coincide ⇒ `StorageError` explícito, **sin reparación silenciosa**.
5. **Repetición:** `fn repetir(&self, destino: &mut impl FnMut(BlockHash, &[u8]) -> Result<(), E>)`
   (o equivalente) en orden del registro; se detiene en el primer error y lo devuelve.
6. **Portado del antiguo:** lo que sirva de `disco.rs` (apertura, opciones, familias) y el patrón de
   `matar_a_mitad.rs`; el resto del antiguo (UTXO en disco, cadena lineal, candidatos DAG) **no** se
   porta. Documenta en `INFORME.md` qué se tomó y de qué líneas.
7. Frontera: `zx-storage → {zx-core}` en `ci/frontera-crates.sh`, conservando las reglas actuales.

## 5. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` (con y sin `--features rocksdb`) | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo con su nombre + lo nuevo |
| V4 | `matar_a_mitad` portado: proceso hijo que admite bloques con `sync`, muerto con `SIGKILL` en ≥ 50 puntos aleatorios (semilla fija) | al reabrir, siempre un prefijo exacto; 0 corrupciones no detectadas |
| V5 | Corrupción inyectada (bit cambiado en un valor de `bloques`, entrada del registro borrada, `meta` de otra red) | error explícito en los tres casos |
| V6 | Propiedad (`proptest`, semilla fija): secuencia aleatoria de admisiones con duplicados ⇒ repetición = secuencia sin duplicados, mismos bytes | sin fallos |
| V7 | Medida: admisiones/s y tiempo de apertura + repetición de 10 000 bloques dev (release, 1 hilo, en `logs/`) | medido, sin umbral |
| V8 | `dependencias-exactas.sh`, `frontera-crates.sh`; el lock **no cambia la versión de ningún paquete existente** y lo que añade (`zx-storage`, `rocksdb`, `librocksdb-sys` y sus dependencias) está, cuando exista, a la versión del lock de `9681061` | OK, con `logs/lock-diff.txt` |

**Prohibido Python.** Presupuesto: **2 h 30 min, 8 hilos, 16 GiB** (la compilación de
`librocksdb-sys` es larga; caché de dependencias copiable en `deepseek/W05b2R/.cargo-home` o
`deepseek/L01/.cargo-home`, que contienen `rocksdb-0.25.0` y `librocksdb-sys-0.19.0+11.8.1`).

## 6. Entregables y límites

Patrón W02/W04 (`ws.orig/`, `ws/` con el enlace `ws/PDF` excluido, `cambios.patch`,
`MIGRACION.sha256`, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log` con `date -Is` real). Cargo
siempre desde `ws/` con `GIT_CEILING_DIRECTORIES` apuntando a tu zona y `CARGO_HOME`/`CARGO_TARGET_DIR`
en la zona. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO antes del código; nada fuera de la zona;
sin commit ni push; sin secretos; ningún `Ok` ficticio. Si algo del antiguo no compila con la
toolchain actual, **para** e infórmalo con la salida literal.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W06b && cd /home/katana/zeo/ZEROX/deepseek/W06b && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W06b. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-NODO/ORDEN-W06b.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W06b-dsh.stdout 2> ../W06b-dsh.stderr )
