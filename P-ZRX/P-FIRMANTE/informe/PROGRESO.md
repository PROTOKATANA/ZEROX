# PROGRESO — bitácora del encargo P-FIRMANTE

Cada medición lleva `date` y `uptime` anotados. Las comprobaciones de entrada y de salida del
encargo §6 están al principio y al final del documento. Ninguna cifra de este informe se ha anotado
sin su comando y su contexto.

---

## 0 · Comprobaciones de ENTRADA (encargo §6), antes de escribir una línea

```text
$ cd /home/katana/zeo/ZEROX
$ LC_ALL=C sha256sum -c P-ZRX/P-FIRMANTE/ENTRADA.sha256
P-ZRX/P-FIRMANTE/PROMPT.md: OK
P-ZRX/P-FIRMANTE/ESPECIFICACION.md: OK
[exit=0]

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
mar 22 sep 2026 17:13:48 CEST
$ uptime
 17:13:48  up 14 days 13:43,  0 users,  carga promedio: 1,18, 1,11, 1,10

$ rustc -Vv
rustc 1.97.0-nightly (20de910db 2026-05-02)
binary: rustc
commit-hash: 20de910db49d3476ccf49ea79a4b22e2b5dface0
commit-date: 2026-05-02
host: x86_64-unknown-linux-gnu
release: 1.97.0-nightly
LLVM version: 22.1.4

$ cargo -V
cargo 1.97.0-nightly (4f9b52075 2026-05-01)
```

Nota sobre `git status`: las tres primeras entradas (`ZEROX-EN-NUMEROS.md` borrado, `.trash/`,
`P-ZRX/`) **ya estaban** antes de empezar; no son cambios de este encargo. `P-ZRX/` entero figura
como no rastreado, así que el trabajo nuevo no ensucia ninguna ruta versionada. No se ha tocado ni
`crates/`, ni `SPEC.md`, ni `TAREAS.md`, ni `ci/`, ni `research/`, ni `veritas/`.

---

## 1 · Estado inicial: qué se abrió antes de diseñar

Para no reimplementar lo que ya existe (encargo §2) se leyeron **enteros**, con las rutas completas
desde la raíz:

- `P-ZRX/P-FIRMANTE/PROMPT.md` y `P-ZRX/P-FIRMANTE/ESPECIFICACION.md` (la especificación congelada).
- `AGENTS.md`, `CLAUDE.md`, `README.md`, `MIGRACION.md`, `rust-toolchain.toml`, `Cargo.toml` (raíz).
- `crates/zx-core/src/digest.rs` — la distinción entre lo que se firma (`PreHash`) y lo que
  identifica al bloque (`BlockHash`). **Es exactamente el problema del encargo.**
- `crates/zx-core/src/firma.rs` — verificación ZIP-215; comprobado que **no hay función de firma**.
- `crates/zx-core/src/preimage/dag.rs` — `DagBlockHeader`, `escribir`, `prefirma`, `pre_hash`,
  `block_hash`, `verificar_sello`, offsets (492/524/525), `body_commitment_de_pares`.
- `crates/zx-core/src/preimage/block.rs` (cabecera lineal, para no confundirla con el DAG) y
  `preimage/mod.rs` (`PreimageWriter`).
- `crates/zx-core/src/hash.rs` — `h_d` es `pub(crate)` a propósito; solo `sha3_256_publico` es
  público. Esto decide que la huella de identidad use un **dominio local** y no una etiqueta de
  `SPEC.md` §4.5.
- `crates/zx-core/src/wire_dag.rs` — `BloqueDag`, `JustificacionPot`, `MAX_BUNDLES_POT = 150`,
  `comprobar_diferencia_slots_del_bloque` (es donde vive el `pot_bundle_count`).
- `crates/zx-consensus/src/bloque_dag.rs`, `crates/zx-consensus/src/ghostdag.rs` (incluido
  `S_MAX_POR_DEFECTO = 150`), `crates/zx-consensus/Cargo.toml`, `crates/zx-core/Cargo.toml`,
  `crates/zx-core/src/lib.rs`, `crates/zx-consensus/src/lib.rs`, `crates/zx-node/src/lib.rs`.
- `SPEC.md` §7.3 (perfil A″: `λ_obj = 1 bloque/s`, `τ_nom = 1 s/slot`, `S_max = 150 s` nominales) y
  §11 (`C-GD-03`, `C-GD-04`, `C-GD-05`, `C-GD-07`, `C-GD-10`, `C-HDR-07`, `C-ORD-03`).
- `ci/` (guardianes `alcance-consenso.sh`, `citas-spec.sh`, `consenso-pendiente.txt`) para el
  informe de integración.

**Lo que NO existe en `crates/` y por tanto el prototipo define con nota** (encargo §2):
una función de firma de cabecera, un productor de bloques DAG y una identidad de oportunidad en
código. `pre_hash` no aparece en ningún sitio fuera de `crates/zx-core`. Detalle en
`informe/INTEGRACION.md` §1.

---

## 2 · Cronología de lo que se hizo

| Momento (`date`) | Qué |
|---|---|
| 17:13–17:16 | Comprobaciones de entrada; lectura de fuentes; diseño del crate |
| 17:16 | `cargo generate-lockfile --offline` — 105 paquetes desde el índice local |
| 17:16–17:19 | Primer build y primera pasada de tests; 7 fallos por la abstención mal modelada |
| 17:19 | Arreglo: `abstencion_activa` explícita en vez de deducirla de `max_slot == 0` |
| 17:20 | Primera medición, **sobre `/tmp` (tmpfs)** — cifra engañosa, descartada |
| 17:20–17:22 | Diagnóstico y arreglo del descriptor heredado (`O_CLOEXEC` + reintento acotado) |
| 17:22–17:31 | Medición final sobre btrfs real; 40 pasadas de estrés de la suite |
| 17:31–17:33 | Informes |

### 2.1 · Problemas encontrados, y cómo se resolvieron

1. **La abstención se activaba en un registro nuevo.** El primer diseño deducía «hay que abstenerse»
   de `max_slot == 0`, y un registro recién creado con `Registro::nueva` tiene exactamente ese
   `max_slot`. Resultado: 7 tests fallaban con `EnAbstinencia` sobre registros que no habían firmado
   nada. **Arreglo:** un campo explícito `abstencion_activa`, que solo pone `Registro::abrir` sobre
   un fichero inexistente (y `Registro::nueva` deja en falso). Se limpia al escribir la primera
   entrada, porque escribir implica que ya se está fuera de la ventana.
2. **El descriptor del registro se heredaba.** Síntoma: `Bloqueado` intermitente sobre un registro
   recién cerrado por el propio proceso, en 1–4 de cada 10 pasadas de la suite con hilos en
   paralelo. Diagnóstico por `/proc/<pid>/fd` y `/proc/locks`: el `flock` vive en la *open file
   description*, y un proceso hijo forkeado por **otro test** lo compartía. Se probaron dos cosas
   antes de la buena: (i) `OpenOptions::custom_flags(O_CLOEXEC)` — **no funcionó** en esta máquina
   (el descriptor acababa con `flags: 02100002`); (ii) `fcntl(F_SETFD, FD_CLOEXEC)` después de abrir
   — cierra la mayoría de la ventana, pero no la que hay entre el `open` y el `fcntl`. **Arreglo
   final:** abrir con `libc::open(..., O_CLOEXEC)` (`abrir_sin_herederos`) **y** reintentar la toma
   del cerrojo durante 2 s con retroceso exponencial, para no confundir un titular transitorio (el
   hijo entre `fork` y `exec`) con un segundo escritor real. Verificación: `0 / 40` pasadas fallidas
   después, y dos tests nuevos que lo fijan (`el_descriptor_del_registro_no_sobrevive_a_un_exec`,
   `el_ciclo_abrir_cerrar_reabrir_no_deja_el_cerrojo_vivo`).
3. **La primera medición medía RAM.** `/tmp` en esta máquina es `tmpfs`: un `fsync` ahí no toca
   ningún disco y daba ~12 µs por bloque. Se corrigió el ejemplo para que reciba el directorio y
   para que imprima `findmnt -T` del directorio usado; las cifras del informe son sobre el btrfs
   real. **Sin ese detalle, el informe habría dicho que el firmante cuesta 12 µs cuando cuesta 800.**

---

## 3 · Presupuesto declarado (encargo §11) y consumo real

| Recurso | Presupuesto declarado | Consumo real |
|---|---|---|
| Tiempo de CPU | < 10 min de compilación + 10 min de tests/medición | ~4 min de build (105 paquetes, `zx-core` incluido) + 6,7 s de tests + 2 s de medición |
| Memoria | < 4 GiB | muy por debajo (un proceso de test, 8 hilos) |
| Disco | `target/` dentro de la zona, borrado al terminar | **559 MiB** (`579 285 098` bytes), borrado; tamaño anotado en §5 |
| Hilos | tope de 24 del proyecto | `cargo` por defecto; el test de concurrencia usa 8 hilos; no se lanzó ningún *batch* CPU-bound |

No se agotó nada y no hubo que reportar `inconcluso`.

---

## 4 · Mediciones, con su contexto

### 4.1 · Las dos corridas del ejemplo `medir_coste`

**Corrida 1 — sobre `/tmp` (`tmpfs`). Etiqueta: descartada, se conserva para documentar el error.**

```text
$ date && uptime
mar 22 sep 2026 17:20:03 CEST
 17:20:03  up 14 days 13:49,  0 usuarios,  carga promedio: 6,45, 3,45, 2,05
$ ./target/release/examples/medir_coste 2000
A · Resolver+Firmar con fsync      mediana=    11.7 µs   p99=     14.0 µs
B · write sin sincronizar          mediana=     1.0 µs
C · write + fdatasync              mediana=     0.2 µs
```

`findmnt` del directorio: `tmpfs`. **Un `fsync` sobre `tmpfs` no llega a ningún disco**: estas
cifras no describen el coste real y no se usan en el informe.

**Corrida 2 — sobre `target/mediciones` (btrfs, `/dev/mapper/cr_root`). La válida.**

```text
$ date && uptime
mar 22 sep 2026 17:31:26 CEST
 17:31:26  up 14 days 14:00,  0 usuarios,  carga promedio: 1,62, 2,24, 2,20

$ ./target/release/examples/medir_coste 2000 target/mediciones
A · Resolver+Firmar con fsync      n=2000  mediana=    807.7 µs   media=    820.1 µs   p99=     988.7 µs   máx=    2894.1 µs
B · write sin sincronizar (cota)   n=2000  mediana=      1.8 µs   media=      1.9 µs   p99=       2.4 µs   máx=      21.5 µs
C · write + fdatasync              n=2000  mediana=    397.9 µs   media=    403.5 µs   p99=     505.9 µs   máx=     676.3 µs
Coste del fsync (A − B): 805.9 µs
Margen del slot de 1 s (p99): 0.0989 %     (peor caso: 0.2894 %)
tras 2000 bloques: 2200 entradas, 176032 bytes (80.0 B/entrada)
sistema de ficheros: btrfs sobre /dev/mapper/cr_root (findmnt -T)
CPU: AMD Ryzen 9 9950X3D 16-Core Processor
```

```text
$ date && uptime
mar 22 sep 2026 17:31:28 CEST
 17:31:28  up 14 days 14:00,  0 usuarios,  carga promedio: 1,73, 2,25, 2,20
```

### 4.2 · Corridas de la suite

```text
$ date && uptime            # antes de la primera pasada de tests
mar 22 sep 2026 17:16:45 CEST
 17:16:45  up 14 days 13:46,  carga promedio: 1,53, 1,36, 1,20

# después del arreglo del descriptor, 40 pasadas del binario de integración con 8 hilos:
$ for i in $(seq 1 40); do $BIN --test-threads=8; done
TOTAL FALLOS: 0 / 40

# y las 30 pasadas de la vuelta de estrés anterior al último arreglo (documentadas para no ocultar
# que el problema existió): 16 / 30 fallos, todos `Bloqueado` en la reapertura.
```

Antes del arreglo se midió el fallo explícitamente para no confundir «no puedo reproducirlo» con
«no pasa»: `1 / 12`, `5 / 20`, `16 / 30`, `21 / 40` fallos según la configuración, siempre el mismo
test y siempre `EWOULDBLOCK` sobre un fichero recién cerrado. Con el arreglo: `0 / 40`.

---

## 5 · Comprobaciones de SALIDA (encargo §6)

```text
$ cd /home/katana/zeo/ZEROX
$ LC_ALL=C sha256sum -c P-ZRX/P-FIRMANTE/ENTRADA.sha256
P-ZRX/P-FIRMANTE/PROMPT.md: OK
P-ZRX/P-FIRMANTE/ESPECIFICACION.md: OK
[exit=0]

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
mar 22 sep 2026 17:32:42 CEST
```

Las dos entradas de `ENTRADA.sha256` siguen verificando: `PROMPT.md` y `ESPECIFICACION.md` están
intactos. El `git status` de salida es **idéntico** al de entrada: este encargo no ha añadido
ninguna ruta versionada nueva, porque todo vive bajo `P-ZRX/`, que ya figuraba como no rastreado.

### 5.1 · Tamaño de `target/` antes de borrarlo (encargo §2)

```text
$ du -sb P-ZRX/P-FIRMANTE/prototipo/target
579285098
$ du -sh P-ZRX/P-FIRMANTE/prototipo/target
559M	P-ZRX/P-FIRMANTE/prototipo/target
$ uptime
 17:32:55  up 14 days 14:02,  0 usuarios,  carga promedio: 2,47, 2,38, 2,25
```

`target/` quedó en **559 MiB (579 285 098 bytes)** y se borró al terminar, como manda el encargo.
El crate entregado no lo contiene. Después, la verificación final desde cero (solo `cargo test
--locked --offline`, perfil `test`) volvió a construir `target/` y quedó en **320 MiB**, y se borró
otra vez. Estado final entregado: sin `target/`.

### 5.2 · `rustc -Vv` de la máquina que compiló y midió

```text
rustc 1.97.0-nightly (20de910db 2026-05-02)
binary: rustc
commit-hash: 20de910db49d3476ccf49ea79a4b22e2b5dface0
commit-date: 2026-05-02
host: x86_64-unknown-linux-gnu
release: 1.97.0-nightly
LLVM version: 22.1.4
```

---

## 6 · Cómo se compiló y se probó (comandos exactos)

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-FIRMANTE/prototipo
export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/P-ZRX/P-FIRMANTE/prototipo/target

cargo generate-lockfile --offline                       # una sola vez, desde el índice local
cargo build      --locked --offline --all-targets
cargo test       --locked --offline
cargo clippy     --locked --offline --all-targets -- -D warnings
cargo build      --release --locked --offline --example medir_coste
```

- `--locked` en todo lo que compila: se usa el `Cargo.lock` generado, que fija las mismas versiones
  que el lock de la raíz (`zx-core 0.0.0` por ruta, `ed25519-zebra 4.2.0`, `libc 0.2.189`,
  `tempfile 3.24.0`, `thiserror 2.0.20`).
- `--offline`: no se consultó la red. El crate declara su propio `[workspace]` vacío para no
  reclamar ni ser reclamado por el workspace de la raíz (`crates/` es de solo lectura).
- `CARGO_TARGET_DIR` siempre dentro de la zona del encargo.
- `cargo clippy ... -- -D warnings` termina **sin un solo aviso**.
- **No se ha escrito ni ejecutado nada en Julia ni en Python** (encargo §0). El encargo es de código
  Rust y así se ha tratado. No se ha creado ninguna auditoría en `veritas/`.

---

## 7 · Tests que quedan marcados `#[ignore]` y por qué

`hijo_persiste_y_aborta`, `hijo_intenta_abrir_y_reporta` y `hijo_inventaria_sus_descriptores` son
**puntos de entrada de proceso hijo**, no tests normales: los lanza el test padre re-ejecutando el
propio binario de test, y **abortan el proceso a propósito** (los dos primeros con `SIGABRT`, el
tercero no). `cargo test` no los ejecuta por defecto, y no deben ejecutarse a mano. Es el mecanismo
con el que se prueba la durabilidad del punto 3 de la regla; está descrito en
`informe/INFORME.md` §3.3.

---

## 8 · Desviaciones y decisiones que conviene revisar

1. **No hay ruta de producción en el repositorio**, así que el prototipo no se ha podido probar
   contra un productor real ni medir con su carga. La medición mide el mismo camino (hash, firma,
   `fsync`) con cabeceras sintéticas pero reales en su forma. Es lo que se puede hacer hoy; está
   declarado en el informe.
2. **El prototipo no es miembro del workspace.** Añadirlo exigía editar `Cargo.toml` en la raíz, que
   está fuera de la zona autorizada. Se resolvió con un `[workspace]` propio y dependencia por ruta.
   La consecuencia es un `Cargo.lock` propio, revisado para que las versiones coincidan con el de la
   raíz.
3. **El dispositivo de aborto vive en `src/aborto.rs`**, no detrás de `cfg(test)`, porque los tests
   de `tests/` son otro crate y no ven lo `#[cfg(test)]` de la biblioteca. **No está en el camino de
   producción**: `Firmante::firmar` no lo llama, y `aborto_si_procede` no hace nada si la variable de
   entorno no está puesta. Se valoró un *feature* opcional y se descartó para no complicar el
   comando de compilación; queda anotado por si al integrar se prefiere.
4. **`libc` entra como dependencia directa** para `flock(2)` y `open(2)` con `O_CLOEXEC`. Está en la
   versión 0.2.189, la misma del `Cargo.lock` de la raíz. En `INTEGRACION.md` §5.1 se discuten las
   alternativas.
5. **`S_max_slots` entra como parámetro y el prototipo trae el valor nominal 150 con su procedencia
   escrita.** No se ha fijado ningún parámetro de consenso (encargo §8) y no se propone texto de
   `SPEC.md`.
