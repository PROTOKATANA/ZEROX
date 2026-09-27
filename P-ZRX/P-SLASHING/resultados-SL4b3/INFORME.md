# INFORME — SL-4b3

**Orden:** `P-ZRX/P-SLASHING/ORDEN-SL4b3.md`. **Revisión que la motiva:**
`P-ZRX/P-SLASHING/REVISION-SL4b2.md` (defectos 1 y 2). **Ejecutor:** DeepSeek
(`deepseek-flash`, esfuerzo `high`), único. **Zona:** `/home/katana/zeo/ZEROX/deepseek/SL4b3/`.
**Base:** raíz en el commit `4925b86`; los 59 hashes de código de `ENTRADA-SL4b3.sha256`
se comprobaron contra esa base, 59/59.

## 1. Qué se ha hecho

### 1.1 Decisión 1 — bloque de transición con firmante seguro

`Nodo::producir_bloque_transicion` (`crates/zx-node/src/nodo.rs`) ya no llama a `producir`: abre el
**mismo** `Firmante` sobre el registro único del nodo (`firmante.registro`, `C-EVP-06`,
FIR-01…FIR-15) que usa el hilo productor de régimen y produce con `producir_con_firmante`. Si el
resultado es `ProductoFirmado::Abstenido { slot, motivo }`:

- **no se produce** el bloque;
- se escribe el evento crítico `firmante_abstenido` del esquema v1 con el `slot` real de la
  oportunidad y `motivo ∈ {conflicto, perdida_registro}`;
- `fase_regimen` espera (procesando red) a sincronizar la transición de otro nodo, la misma ruta
  que ya usaba cuando la clave local no tenía garantía.

`ProductoFirmado::Abstenido` incorpora el campo `slot` (`crates/zx-post/src/productor.rs`): el
evento del esquema exige un `slot` y la variante no lo transportaba. El texto del motivo se factoriza
en `motivo_abstencion_texto`, compartido por la transición y por el bucle de régimen.

### 1.2 Decisión 2 — funciones sin firmante fuera del alcance del nodo

- `zx_post::productor::producir` → **`producir_sin_firmante`**.
- `zx_post::productor_regimen::producir_en_regimen` → **`producir_en_regimen_sin_firmante`**.
- Ambas quedan documentadas como «solo tests y arneses; no protege contra la doble firma» y con la
  referencia al guardián de CI. Actualizados `crates/zx-post/src/lib.rs` y sus llamantes en los
  tests de `zx-post` (`extremo_a_extremo.rs`, `firmante_productores.rs`, `regimen.rs`).
- Nuevo guardián `ci/firmante-obligatorio.sh` (**bash, sin Python**): falla si
  `crates/zx-node/src/` menciona `_sin_firmante`. Falla cerrado si `grep` no devuelve 0/1.
  Añadido al job `deps` de `.github/workflows/zerox-ci.yml`.

### 1.3 Decisión 3 — unitarios de inclusión (V2 de SL-4b2)

El filtro de inclusión que vivía inline en `fase_regimen` se extrae a
`zx_node::evidencia::elegibles(detector, estado_base, slot_objetivo, plazo_slots, max_por_bloque)`
y `fase_regimen` lo consume. Cuatro tests unitarios en `crates/zx-node/src/evidencia.rs`:

| Caso | Aserción |
|---|---|
| Pendiente con ventana abierta | `elegibles` devuelve 1 `EvidenceTx` v4 |
| Incidente ya procesado en el estado base | `elegibles` devuelve 0 |
| Ventana cerrada | `podar_pendientes` la retira (`pendientes_len == 0`) y `elegibles` devuelve 0 |
| Bloque portador fuera de la cadena tras reorganización | con la punta que ya lo procesó, 0; con la punta nueva, vuelve a devolver 1 sin marca interna |

## 2. Falta de definición detectada (informada antes de editar)

La decisión 1 dice «si el resultado es `Abstenido` … lo reintenta en el siguiente slot como hoy».
Hoy `producir_bloque_transicion` se llama **una sola vez** y `producir` barre siempre desde S1: un
reintento construye el mismo candidato determinista (misma identidad RAT-1 y mismo slot) y el
firmante volvería a abstenerse, escribiendo el evento sin fin. Además el evento `firmante_abstenido`
exige un `slot` que `ProductoFirmado::Abstenido` no transportaba. Interpretación conservadora
aplicada: `Abstenido` lleva el `slot` real y, tras la abstención, el nodo no produce y espera a la
red; **el hilo productor de régimen sigue reintentando cada slot como hoy** en cuanto haya puntas.
No se encontró ninguna otra falta de definición que bloqueara la edición.

## 3. Verificación

| Paso | Resultado |
|---|---|
| `cargo fmt --all -- --check` | **OK** (tras aplicar `cargo fmt`) |
| `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK, 0 errores, 0 avisos** |
| `cargo test --workspace --all-features --locked` | **OK, 0 fallos** (82 binarios de prueba; 92 `ignored`, los que ya lo estaban) |
| `ci/dependencias-exactas.sh` | **OK** |
| `ci/frontera-crates.sh` | **OK** |
| `ci/firmante-obligatorio.sh` | **OK** («no invoca ningún productor `_sin_firmante`») |
| Guardián sobre copia con llamada reintroducida | **FALLA con `exit 1`** y cita el fichero/línea, como debe |
| Ejecución real corta (3 nodos cruzan el corte) | **3/3** |

### 3.1 Ejecución real corta

`ejecutar_sl4b3.sh`: tres nodos **aislados** (claves `0,1,2` / `3,4,5` / `6,7,8`), `N_dev = 2_000_000`
(dev, declarado), `SR_dev = u64::MAX`, `--parada-tras-slots 1`. Con `SR_dev` máximo la transición
cae en el slot 1 y el hilo productor de régimen se detiene antes de producir ningún bloque más, así
que la única entrada posible en `firmante.registro` es la de la transición. Los tres procesos
terminaron por `parada` (cruce del corte) y sus `firmante.registro` miden 136 B (56 de cabecera +
80 de una entrada). El test `registro_firmante_transicion` (API pública `Registro::abrir` +
`entradas()`/`max_slot()`) leyó **3/3 entradas en el slot 1**. Si la transición se sellara sin
firmante, `entradas()` sería 0 y el test falla.

### 3.2 Tabla de cobertura mínima (V2 de SL-4b2)

| Evento / resultado | Dónde se cubre |
|---|---|
| `firmante_abstenido` por conflicto | unitarios de `zx-post` (`firmante_productores`, V6b) y rama de transición (revisada) |
| `firmante_abstenido` por pérdida | unitario de `zx-post` (`firmante/mod.rs`, `la_abstencion_usa_el_perfil_de_registro_abrir`) |
| `evidencia_detectada` | unitarios de `evidencia.rs` (V1) y ejecución real de SL-4b2 |
| `evidencia_incluida` | unitarios nuevos de inclusión (V2 de SL-4b3) |
| Descarte por repetición / ventana cerrada | unitarios de `evidencia.rs` y del nuevo `elegibles` |
| `Reemitido` | `firmante/mod.rs` y `zx-post` (V6a) |

## 4. Resultado de la suite completa

`cargo test --workspace --all-features --locked`: **0 fallos** (registro íntegro en
`test-suite.log`). Incluye los cuatro unitarios nuevos de inclusión
(`evidencia::tests::{pendiente_con_ventana_abierta_se_incluye,
incidente_ya_procesado_en_el_estado_base_no_se_incluye,
ventana_cerrada_no_se_incluye_y_sale_de_la_lista,
bloque_portador_fuera_de_la_cadena_vuelve_a_ser_elegible}`) y los binarios de `zx-post`
(`firmante_productores`, `regimen`, `extremo_a_extremo`) con los nombres nuevos. Los `ignored`
son los mismos que ya lo estaban (coste de `fsync`, N_dev real, bancos).

## 5. Límites declarados

- El registro del firmante se lee con la API del propio `zx-post`; no se añadió ningún formato nuevo.
- La abstención de la transición no reintenta el mismo candidato (explicado en §2); es una decisión
  de implementación documentada, no una regresión del comportamiento del régimen.
- No se tocó `ws.orig/` tras copiarlo, ni `Cargo.lock`, ni ningún crate fuera de `zx-post`/`zx-node`
  y los guiones de CI.

## 6. Método y entorno

- **Ejecutor:** DeepSeek, modelo de la API `deepseek-flash`, esfuerzo `high`, un único agente
  (sin subagentes ni forks). Presupuesto 1 h 30 min, `nice -n 10`, `CARGO_BUILD_JOBS=8`.
- **Base:** la raíz en el commit `4925b86` se materializó con `git archive` (solo lectura; sin
  commits, sin tocar el índice ni el árbol de trabajo del repositorio). `ws.orig/` quedó intacto:
  los 59 hashes de código de `ENTRADA-SL4b3.sha256` se re-comprobaron al final y siguen 59/59.
- **Ejecución real:** `ejecutar_sl4b3.sh` (nodos aislados, `N_dev = 2_000_000` declarado como valor
  dev, `SR_dev = u64::MAX`, `--parada-tras-slots 1`); artefactos en `run-sl4b3/` y `real-run.log`.
- Sin Python en ningún paso.
