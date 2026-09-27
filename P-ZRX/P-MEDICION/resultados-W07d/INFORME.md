# INFORME — ORDEN-W07d: registro del estado final (resumen tras la repetición y bloque de transición)

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, DeepSeek Harness). **Fecha:** 2026-09-27
(horas reales en `HORAS.log`). **Zona:** `/home/katana/zeo/ZEROX/deepseek/W07d/`.
**Base:** raíz en el commit `20214cb`, extraída a `ws.orig/` (intacta, `sha256sum -c` 34/34) y copiada
a `ws/`; `ENTRADA-W07d.sha256` verificada al empezar y los 30 ficheros no tocados reverificados al
final. **Sin Python, sin git en el repositorio, solo escritura en la zona.**

**Falta de definición:** se detectó e informó **antes de editar** en `FALTAS-DE-DEFINICION.md` (10
huecos; lectura mínima, literal y determinista adoptada). Ninguna cambia una regla de consenso, un
orden de la tubería ni una decisión del nodo. Los puntos 1–9 se resumen abajo; el 10 es un límite.

## 1. Qué se hizo

Solo registro: **ninguna regla, orden de la tubería ni decisión del nodo cambia**. El nodo escribe
más campos y eventos, y atiende `SIGTERM`/`SIGINT` con una parada ordenada.

- **`reinicio_completo`** (`crates/zx-node/src/nodo.rs`, `reiniciar`): además de
  `bloques_repetidos` y `duracion_ns`, lleva `punta`, `resumen_estado` (calculado **después** de
  repetir todo el almacén con la misma función `resumen_estado` que usa `cambio_punta`),
  `n_bloques_dag` y `compendio_bloques`. Sigue siendo crítico (`sync`).
- **`parada`** (`nodo.rs`, `ejecutar` + `escribir_parada`): el evento crítico lleva ahora `motivo`,
  `punta`, `resumen_estado`, `n_bloques_dag` y `compendio_bloques`, tanto en el final normal
  (`fin`/`parada_tras_slots`) como en la parada por señal. En ambos casos el proceso sale con código 0.
- **`SIGTERM`/`SIGINT`** (`crates/zx-node/src/parada.rs`, `main.rs`): manejador `signal(2)`/`signal(15)`
  que solo deja un flag atómico (`AtomicU8`), y sondeo del flag en las esperas de `fase_pow`
  (`recv_timeout`) y `fase_regimen` (`recv_timeout`, espera de transición y reposo). Al verlo, el nodo
  cierra el hilo minero / pide `Parar` al productor, escribe `parada` y sale con 0. **Sin dependencias
  nuevas** (`Cargo.lock` intacto, `af2b59…`): el `unsafe` está confinado a `parada.rs`.
- **`bloque_transicion_producido`** (`nodo.rs`, `producir_bloque_transicion`): evento de diagnóstico
  (`hash`, `slot`) que registra el bloque de transición propio; distinto de `bloque_producido` para no
  alterar lo que cuenta `reinicio.rs` (W07a-R).
- **Determinismo** (`crates/zx-node/src/compendio.rs`): `compendio_de_hashes` concatena los 32 bytes
  de cada `BlockHash` ordenados por bytes y aplica `zx_core::sha3_256_publico`; el orden de admisión
  no influye. `compendio_de_almacen` lo calcula sobre el registro persistido completo (PoW y PoST,
  génesis incluido).

### Archivos cambiados

| Fichero | Cambio |
|---|---|
| `crates/zx-node/src/compendio.rs` | **nuevo**: compendio SHA3-256 de hashes ordenados por bytes |
| `crates/zx-node/src/parada.rs` | **nuevo**: `SIGTERM`/`SIGINT` → flag atómico, sin dependencias nuevas |
| `crates/zx-node/src/nodo.rs` | campos de estado final, `parada` por señal, `bloque_transicion_producido` |
| `crates/zx-node/src/main.rs` | instala los manejadores de señal antes de arrancar el nodo |
| `crates/zx-node/src/lib.rs` | declara `pub mod compendio;` y `pub mod parada;` |
| `crates/zx-node/tests/registro_esquema.rs` | valida los campos/tipos nuevos |
| `crates/zx-node/tests/w07d_estado_final.rs` | **nuevo**: reinicio, determinismo y `SIGTERM` real |

`Cargo.toml` y `Cargo.lock` **no** cambian. Detalle exacto en `cambios.patch`; hashes en
`MIGRACION.sha256`.

## 2. Campos nuevos para incorporar al esquema (la orden prohíbe que yo edite el documento)

`ESQUEMA-REGISTRO-v1.md` no se tocó. Estos son los campos/eventos que el director debe incorporar:

| Evento | Crítico | Campos que se añaden | Definición adoptada |
|---|---|---|---|
| `reinicio_completo` | sí | `punta`, `resumen_estado`, `n_bloques_dag`, `compendio_bloques` | ver abajo |
| `parada` | sí | `punta`, `resumen_estado`, `n_bloques_dag`, `compendio_bloques` | ver abajo |
| `bloque_transicion_producido` | no | `hash`, `slot` | bloque PoST de transición propio admitido y persistido; después de admitir y antes de difundir |

- **`compendio_bloques`** (hex64): `SHA3-256` (`zx_core::sha3_256_publico`) de la concatenación de
  los hashes de **todos** los bloques admitidos y persistidos (PoW y PoST, **génesis incluido**), cada
  hash en sus **32 bytes** crudos (`BlockHash::as_bytes()`), ordenados **lexicográficamente por bytes**;
  el digest se escribe en hexadecimal minúsculo de 64 caracteres. `Almacen::repetir` es la fuente.
- **`n_bloques_dag`**: `Cadena::bloques_admitidos()` (PoW + PoST válidos), la misma definición que ya
  usa `bloque_red_admitido` en el §1.
- **`punta`**: `Cadena::mejor_punta().or(terminal())` en ese instante; `""` si no hay ninguna (fase
  PoW pura), igual que la convención de `cambio_punta`.
- **`resumen_estado`**: blake3 de la codificación canónica de `Estado` (`estado_resumen.rs`), sobre
  `Cadena::estado_virtual()`; la misma función que usa `cambio_punta`.
- **`motivo` de `parada`**: se añaden `"sigterm"` y `"sigint"` a `"fin"` y `"parada_tras_slots"`.

## 3. Tests

Nuevos:

- `crates/zx-node/src/compendio.rs`: el compendio no depende del orden de los hashes; cambia al
  cambiar el conjunto; dos almacenes con el mismo conjunto en orden y en orden inverso coinciden.
- `crates/zx-node/src/parada.rs`: sin solicitud no hay motivo; cada motivo se lee como su literal.
- `crates/zx-node/tests/w07d_estado_final.rs`:
  - `reinicio_completo_coincide_con_el_estado_virtual_reabierto`: proceso real → `SIGKILL` tras un
    bloque PoW → reapertura; el `resumen_estado` de `reinicio_completo` es exactamente el del estado
    virtual del nodo reabierto, y `punta`/`n_bloques_dag`/`compendio_bloques` cuadran.
  - `mismo_conjunto_en_orden_distinto_da_el_mismo_compendio_y_resumen`: dos almacenes con el mismo
    conjunto en orden distinto y dos `Estado` con las mismas entradas en orden distinto.
  - `parada_por_sigterm_en_proceso_real_sale_con_cero`: proceso real, `kill -TERM`, la última `parada`
    tiene `motivo == "sigterm"` y los campos nuevos, y el proceso sale con **código 0**.
- `registro_esquema.rs` valida los campos obligatorios nuevos y el tipo
  `bloque_transicion_producido` línea por línea.

Límite declarado (falta de definición 10): no se levantan dos procesos reales con el mismo conjunto
en órdenes distintos; el determinismo se comprueba sobre `compendio_de_almacen` y `resumen_estado`,
que son las funciones exactas que invocarían esos nodos. `parada` por señal se prueba en fase PoW
(en fase PoST su cobertura la da `registro_esquema.rs`, en proceso).

## 4. Verificación

Comando reproducible en `v.sh`. Resultados (log en `logs/`):

| Comprobación | Resultado |
|---|---|
| `cargo fmt --all -- --check` | limpio |
| `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | verde (`logs/clippy.log`) |
| `cargo test --workspace --all-features --locked` | **868 passed / 0 failed / 6 ignored** en 72 binarios (`logs/test.log`) |
| Diferencial T01 (`zx-consensus`) | 2/2 verde (236.81 s) |
| Diferencial T04 (`zx-cadena`) | 1/1 verde (382.05 s) |
| `ci/dependencias-exactas.sh` | OK — 24 dependencias con versión exacta |
| `ci/firmante-obligatorio.sh` | OK — sin `_sin_firmante` |
| `ci/frontera-crates.sh` | OK — 9 fronteras |
| `MIGRACION.sha256` | `sha256sum -c` 7/7 verde |
| `ENTRADA-W07d.sha256` (no tocados) | 30/30 verde; `ws.orig/` 34/34 intacto |

Presupuesto: poco más de 1 h de pared desde el inicio (16:46) hasta el cierre del registro (17:43),
dentro del límite de 1 h 30 min. `nice -n 19` en todo; la suite y las comprobaciones finales usaron
`CARGO_BUILD_JOBS=4`/`RUST_TEST_THREADS=4` (`env.sh`). Desviación declarada: la primera compilación de
dependencias (`cargo check`/`clippy`) usó 8 hilos durante unos minutos; se repitió `clippy` con 4
hilos (`logs/clippy-4h.log`, verde).

## 5. Restricciones cumplidas

- **Prohibido Python**: no se ejecutó ni se escribió Python.
- **Sin git en el repositorio**: no se hizo `commit`/`push`/`checkout`; solo lectura (`git archive` de
  la base) fuera de la zona de escritura.
- **Sin secretos**: no se leyeron `.env` ni credenciales; el modelo se declara como
  `deepseek-flash` (high) sin verificarlo por API.
- **Ningún `Ok` ficticio**: los tres tests nuevos y el actualizado pasan de verdad en la suite
  completa; no hay rutas de parada que devuelvan `Ok` sin escribir el evento.

## 6. Reproducción

```bash
source /home/katana/zeo/ZEROX/deepseek/W07d/env.sh
cd /home/katana/zeo/ZEROX/deepseek/W07d/ws
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --all-features --locked
bash ci/dependencias-exactas.sh && bash ci/firmante-obligatorio.sh && bash ci/frontera-crates.sh
```
