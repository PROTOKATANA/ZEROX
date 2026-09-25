# INFORME.md — ORDEN-L01

**Línea base reproducible de las primitivas candidatas del ZEROX antiguo (commit `9681061`).**
Sesión: DeepSeek Harness, modelo `deepseek-flash` («DeepSeek-V41-Flash»; la orden lo nombra
`deepseek-v4.1-flash`). Fecha: 2026-09-26, 01:05–01:08 +02:00.
Zona de ejecución: `/home/katana/zeo/ZEROX/deepseek/L01/`.

## 1. Veredicto por paso

| Paso | Comando (desde `checkout/`, con el entorno de §4) | Veredicto |
|---|---|---|
| **S0** | `cargo metadata --locked --format-version 1 > ../logs/S0-metadata.json` | **REPRODUCIDO** (exit 0; grafo resuelto con el `Cargo.lock` original, 496 paquetes) |
| **S1** | `cargo test --locked -p zx-core` | **REPRODUCIDO** (exit 0; **156/156** pasadas, 0 fallidas, 0 ignoradas) |
| **S2** | `cargo test --locked -p zx-pot` | **REPRODUCIDO** (exit 0; **5/5** pasadas, 0 fallidas, 0 ignoradas) |
| **S3** | `cargo test --locked -p zx-storage` | **REPRODUCIDO** (exit 0; **36/36** pasadas, 0 fallidas; **24 no compiladas** por estar tras la feature `rocksdb`, ver §5) |
| **S4** | `cargo test --locked -p zx-consensus` | **FALLA** (exit 101; **error de compilación** del binario `spec_numeros`: `SPEC.md` no fue extraído por la orden; ver §2 y §6) |
| **S5** (opcional) | `cargo test --locked -p zx-node --features farmer --test farmer_disco` | **REPRODUCIDO** (exit 0; **13/13** pasadas, 0 fallidas, 0 ignoradas) |

Presupuesto: tope 3 h de reloj, 16 hilos, 48 GiB RAM, 60 GiB disco. **Consumo real:** ≈ 3 min de
reloj de trabajo, 16 jobs, RAM pico observada ≤ 10 GiB en uso, disco ≈ 5,3 GiB (`target` 4,6 GiB +
`.cargo-home` 0,6 GiB + `checkout` 93 MiB). No se agotó.

## 2. Falta de definición detectada (hallazgo principal)

La preparación fija de §4 extrae del commit `9681061` solo:

```
crates prototipos testdata veritas ci Cargo.toml Cargo.lock rust-toolchain.toml
```

**`SPEC.md` no está en esa lista**, pero `crates/zx-consensus/tests/spec_numeros.rs:48` lo incluye
de forma incondicional:

```rust
const SPEC: &str = include_str!("../../../SPEC.md");
```

Por tanto, con la extracción fija **el paso S4 es imposible de compilar**, y con él el binario de
prueba `spec_numeros` (y la compilación completa de `zx-consensus` como test target). Es una
insuficiencia de la propia orden, no un fallo del código antiguo:

- El archivo existe en el commit (`SPEC.md` es un blob de nivel raíz), pero no se extrajo.
- **No lo he añadido ni he reintentado S4 con una extracción distinta**: §3 lo prohíbe
  expresamente («Si alguna instrucción de esta orden resulta ambigua o imposible… detente y
  descríbelo… no elijas tú»). Tampoco he tocado `crates/zx-consensus` ni `Cargo.lock`.
- Consecuencia: **el veredicto de S4 no refuta ni confirma el código**; queda indeterminado hasta
  que el director decida si `SPEC.md` debe formar parte de la entrada.

Este es el único defecto de definición encontrado. Las demás entradas y la preparación son
coherentes y ejecutables (verificado antes de actuar: commit, clon, toolchain, red, rutas y
ausencia de `.cargo/config.toml`).

## 3. Archivos creados (todos en la zona)

- `checkout/` — extracción de `9681061` (840 archivos fuera de `PDF`; solo lectura tras extraer).
- `checkout/PDF/autonomys-subspace/` — clon local `--no-hardlinks` fijado en
  `f8842d019cdf0f7163421b9644db5a9ff82b2a73` (no enlace simbólico).
- `.cargo-home/` — `CARGO_HOME` aislado (≈ 629 MiB).
- `target/` — `CARGO_TARGET_DIR` (≈ 4,6 GiB).
- `logs/`:
  - `00-preparacion.log`, `01-entrada-inicio.log`, `02-entrada-fin.log`, `99-integridad-final.log`
  - `S0.log`, `S0-metadata.json` (2 250 912 bytes), `S0-metadata.err.log`
  - `S1-zx-core.log`, `S2-zx-pot.log`, `S3-zx-storage.log`, `S4-zx-consensus.log`,
    `S5-zx-node-farmer_disco.log`
- `MANIFIESTO-CHECKOUT.sha256` — 840 huellas (excluye `./PDF`).
- `HORAS.log` — `date -Is` antes/después de cada paso.
- `PROGRESO.md`, `INFORME.md`, `RESULTADOS.tsv`, `ENTORNO.txt`.

## 4. Comandos exactos

Preparación (desde la zona):

```bash
git -C /home/katana/zeo/ZEROX archive 9681061 \
    crates prototipos testdata veritas ci Cargo.toml Cargo.lock rust-toolchain.toml \
  | tar -x -C checkout
git clone --no-hardlinks /home/katana/zeo/.trash/zerox/PDF/autonomys-subspace \
    checkout/PDF/autonomys-subspace
git -C checkout/PDF/autonomys-subspace checkout --detach f8842d019cdf0f7163421b9644db5a9ff82b2a73
git -C checkout/PDF/autonomys-subspace rev-parse HEAD      # → f8842d019cdf0f7163421b9644db5a9ff82b2a73
(cd checkout && find . -path ./PDF -prune -o -type f -print0 | sort -z \
    | xargs -0 sha256sum) > MANIFIESTO-CHECKOUT.sha256
```

Entorno para todos los comandos cargo:

```bash
export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/L01/.cargo-home
export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/L01/target
export CARGO_BUILD_JOBS=16 RUST_TEST_THREADS=16 RUSTFLAGS=
```

Pasos (desde `checkout/`): S0 … S5 según la tabla de §1. No se usó `--offline`, ni `cargo update`,
ni `--ignored`/`--include-ignored`, ni features fuera de las indicadas.

Comprobaciones de integridad:

```bash
sha256sum checkout/testdata/nist-cavp/SHA3_256ShortMsg.rsp \
          checkout/testdata/nist-cavp/SHA3_256LongMsg.rsp \
          checkout/testdata/nist-cavp/SHA3_256Monte.rsp \
          checkout/crates/zx-pot/tests/vectores-nightly.txt
(cd checkout && find . -path ./PDF -prune -o -type f -print0 | sort -z | xargs -0 sha256sum) \
  | diff - MANIFIESTO-CHECKOUT.sha256
git -C checkout/PDF/autonomys-subspace status --porcelain
cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-LINEA-BASE/ENTRADA.sha256
```

## 5. Resultados

### Test ejecutados (`RESULTADOS.tsv`, una fila por binario)

- **S1 `zx-core`** — `unittests src/lib.rs` 144; `tests/cavp_sha3_256.rs` 4 (oráculo NIST
  independiente, 2,03 s); `tests/ed25519_no_unicidad.rs` 1; `tests/oraculo_julia.rs` 1;
  `tests/parsers_dag_prop.rs` 2; `tests/vectores_dag.rs` 4; doc-tests 0. **Total 156/156.**
- **S2 `zx-pot`** — `unittests src/lib.rs` 1; `tests/contexto_verificado.rs` 3;
  `tests/diferencial.rs` 1 (32 vectores); doc-tests 0. **Total 5/5.**
- **S3 `zx-storage`** — `unittests src/lib.rs` **36**; `tests/almacen_dag.rs` 0;
  `tests/almacen_differential.rs` 0; `tests/matar_a_mitad.rs` 0; doc-tests 0. **Total 36/36.**
- **S4 `zx-consensus`** — sin binarios ejecutados: fallo de compilación (ver §6).
- **S5 `zx-node`** — `tests/farmer_disco.rs` **13/13** (35,09 s).

### Explicación de diferencias de conteo

- `zx-core` (referencia 156) y `zx-pot` (referencia 5): **coinciden exactamente**.
- `zx-consensus` (referencia 422 con 4 `#[ignore]`): el inventario `#[test]` da 422 y los
  atributos reales `#[ignore]` son 4. El `grep` de texto `#[ignore` da 5 porque
  `tests/firmante_local.rs:7` es un comentario de documentación, no un atributo. **No se ejecutó
  ningún `#[test]` por el fallo de compilación.**
- `zx-storage` (referencia 60): el inventario da 60, pero **solo 36 se ejecutan sin features**.
  Están tras `#![cfg(feature = "rocksdb")]` (o módulo equivalente) **24 tests**: 11 de
  `src/disco.rs` (módulo gateado en `src/lib.rs`) + 13 de integración (3 `almacen_dag.rs`,
  9 `almacen_differential.rs`, 1 `matar_a_mitad.rs`). Los propios archivos lo declaran: «Corre solo
  con `--features rocksdb`. Sin la feature, este archivo compila a nada». Por eso S3, con el
  comando de la orden (sin `rocksdb`), **no puede cubrir** «almacén diferencial» ni
  `matar_a_mitad`; el veredicto REPRODUCIDO se refiere a los 36 tests de memoria/UTXO que sí
  corrieron.

### Hashes fijos e integridad

- `testdata/nist-cavp/SHA3_256ShortMsg.rsp` `e75b1ded…`, `SHA3_256LongMsg.rsp` `741b75d0…`,
  `SHA3_256Monte.rsp` `0b387d75…`, `crates/zx-pot/tests/vectores-nightly.txt` `023a9fc8…`
  (prefijos correctos, al inicio y al final).
- Unidad de reproducibilidad intacta: `Cargo.toml` `619d4950…`, `Cargo.lock` `9021465d…`,
  `rust-toolchain.toml` `604b0c1b…`.
- **Integridad del checkout:** `diff` contra `MANIFIESTO-CHECKOUT.sha256` **vacío** antes y después
  de compilar (`exit_diff=0`). La compilación no escribió en `checkout/`; `Cargo.lock` no cambió.
- **Integridad del clon:** `git status --porcelain` vacío.
- **`ENTRADA.sha256`:** `ORDEN-L01.md: OK`, `V-ZRX/LINEO.md: OK` al inicio y al final.
- Toolchain efectiva desde `checkout/`: `nightly-2026-05-03-x86_64-unknown-linux-gnu`
  (`rustc 1.97.0-nightly (20de910db 2026-05-02)`, `cargo 1.97.0-nightly (4f9b52075 2026-05-01)`).

## 6. Fallos, con salida literal

Salida íntegra de S4 (`logs/S4-zx-consensus.log`), tras compilar los crates de Autonomys:

```
   Compiling zx-consensus v0.0.0 (/home/katana/zeo/ZEROX/deepseek/L01/checkout/crates/zx-consensus)
error: couldn't read `crates/zx-consensus/tests/../../../SPEC.md`: No such file or directory (os error 2)
  --> crates/zx-consensus/tests/spec_numeros.rs:48:20
   |
48 | const SPEC: &str = include_str!("../../../SPEC.md");
   |                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

error: could not compile `zx-consensus` (test "spec_numeros") due to 1 previous error
warning: build failed, waiting for other jobs to finish...
=== STEP S4-zx-consensus exit=101 elapsed=3 ===
```

No hubo ninguna prueba fallida en los pasos que compilaron. No se ejecutó ninguna prueba
`#[ignore]`.

## 7. Riesgos

- **S4 indeterminado por defecto de la orden**, no por el código: sin `SPEC.md` no se puede emitir
  juicio sobre la suite de `zx-consensus`. Es el riesgo principal del resultado.
- **Carga de la máquina no controlada**: `uptime` pasó de 0,33 a 3,51 (media 1 min) durante la
  sesión; hay otros procesos. Los «segundos» de `RESULTADOS.tsv` son tiempo de pared observado, no
  rendimiento, y no deben compararse.
- **Dependencia de red**: `CARGO_HOME` era nuevo y vacío; el grafo se descargó de crates.io y de
  `github.com/grandinetech/rust-kzg` (rev `8f5f1a0f…`). Otra sesión sin red no reproduciría sin el
  caché.
- `LD_LIBRARY_PATH` apunta a bibliotecas AOCC; no causó ningún error aquí, pero no se neutralizó.
- El veredicto S5 es opcional y de un solo binario; no cubre el resto de `zx-node`.

## 8. Lo que esta orden NO demuestra

- Que un test antiguo que pasa pruebe el **contrato híbrido** nuevo: prueba su **contrato antiguo**.
  Éxito aquí no transfiere ninguna garantía al diseño actual.
- Que **ninguna constante antigua** haya quedado validada. `T=120`, `N=90`, `SHIFT=26`,
  `COINBASE_MATURITY=12000`, `k=30`, `S_max=150`, etc. son parámetros de la red vieja; que sus
  tests pasen no los re-deriva ni los aprueba para el híbrido.
- Que la **carga de la máquina estuviera controlada**: no lo estaba (ver §7).
- Que `zx-consensus` compile o pase: **S4 quedó indeterminado** por la ausencia de `SPEC.md`.
- Nada sobre RocksDB, el almacén diferencial ni `matar_a_mitad`: no se compilaron (feature
  `rocksdb` excluida por la orden).
- Nada sobre las pruebas `#[ignore]`: no se ejecutaron.
- Nada sobre `zx-p2p`, `zx-mempool`, el nodo completo ni `tres_nodos`: fuera de alcance.

## 9. Presupuesto y trazas

- Presupuesto declarado y no agotado (§1). Checkpoints: los logs crudos y el checkout íntegro
  quedan en la zona.
- `ENTORNO.txt`: `uname -a`, `nproc` (32), `free -g` (123 GiB; 101→95 libres), `uptime` antes y
  después, toolchain y `cargo -V` desde `checkout/`, modelo del agente.
- `HORAS.log`: 14 marcas `date -Is` (preparación, antes/después de S0–S5).
- Criterio de fallo por §7: S4 se clasifica **FALLA** (error de compilación) y se documenta su
  causa raíz (entrada incompleta), sin arreglarlo.

## 10. Corrección C1 (2026-09-26, 01:12–01:14 +02:00)

**Origen.** `CORRECCION-L01-S4.md` confirma que la FALLA de S4 fue un defecto de la entrada de
`ORDEN-L01.md` (no extraía `SPEC.md`), no del código ni del ejecutor, y añade el paso S3b. Esta
sección **sustituye** el veredicto de S4 de §1; §1–§9 se conservan como registro de la primera
ejecución. No se detectó ninguna falta de definición en la corrección.

### 10.1 Cambios en la entrada y en el manifiesto

- Extracción adicional, desde `deepseek/L01/`:
  `git -C /home/katana/zeo/ZEROX archive 9681061 SPEC.md | tar -x -C checkout`.
- `sha256sum checkout/SPEC.md` =
  `b59905c5f1900076e699f762f3f6604f282790fa5a7ed97527d22d21f9d4e0ae`, exactamente el valor exigido
  (blob git `3b20616a55a9dd628cfe3891ca13752e75ad6331`). `logs/C1-extraccion.log`.
- `MANIFIESTO-CHECKOUT.sha256` regenerado con el mismo comando de §4: **841** archivos (antes 840).
  Copia previa: `MANIFIESTO-CHECKOUT.antes-C1.sha256` (840 huellas).
- `diff` entre ambos: **una sola línea añadida**, la de `./SPEC.md` (`logs/C1-diff-manifiesto.log`):
  `206a207` / `> b59905c5…  ./SPEC.md`. Nada más cambió (ni `Cargo.lock`). sha256 de los
  manifiestos: antes `7649ceb9…`, nuevo `a6f0880a…`.

### 10.2 Veredicto por paso (C1)

| Paso | Comando (desde `checkout/`, con el entorno de §4) | Veredicto |
|---|---|---|
| **S4** | `cargo test --locked -p zx-consensus` | **REPRODUCIDO** (exit 0, 13 s; 22 binarios; **421 pasadas, 0 fallidas, 4 ignoradas, 0 filtradas**) |
| **S3b** | `cargo test --locked -p zx-storage --features rocksdb` | **REPRODUCIDO** (exit 0, 62 s; 5 binarios; **60 pasadas, 0 fallidas, 0 ignoradas**) |

### 10.3 Conteo de S4 y explicación

- Inventario `grep '#\[test\]'`: **422** (207 en `src/` + 215 en `tests/`), con **4 atributos
  `#[ignore]` reales** (`src/firmante/mod.rs:389`, `tests/firmante_local.rs:398`,
  `tests/ghostdag_bench.rs:230`, `tests/spec_numeros.rs:150`). El texto `#[ignore` aparece 5 veces;
  `tests/firmante_local.rs:7` es un comentario de documentación. **Coincide con la referencia.**
- Ejecutado: 422 − 4 ignoradas = 418 `#[test]` + 3 doc-tests = **421 pasadas**, 4 ignoradas, 0
  fallidas. Binarios con ignoradas: `unittests src/lib.rs` (1), `tests/firmante_local.rs` (1),
  `tests/ghostdag_bench.rs` (1, ejecuta 0), `tests/spec_numeros.rs` (1). Sin diferencias que
  explicar.
- `tests/spec_numeros.rs` —el binario que falló en L01 por `SPEC.md`— compila y pasa 10/11; su
  única ignorada es `el_codigo_alcanza_la_base_poas_de_556`, con `#[ignore]` documentado.

### 10.4 S3b: almacén en disco, diferencial y `matar_a_mitad`

- `unittests src/lib.rs` 47 (36 de la ejecución sin feature + 11 de `src/disco.rs`),
  `tests/almacen_dag.rs` 3, `tests/almacen_differential.rs` 9, `tests/matar_a_mitad.rs` 1,
  doc-tests 0. **60/60**, 0 ignoradas.
- `matar_a_mitad_de_escritura_no_deja_el_almacen_incoherente` **pasó** (0,28 s; lanza subprocesos
  y los mata).
- `libclang` del sistema (`/usr/lib64/libclang.so.21.1.8`) bastó para `bindgen`; S3b descargó
  `bindgen 0.72.1`, `clang-sys 1.9.1`, `rocksdb 0.25.0` y `librocksdb-sys 0.19.0+11.8.1` de
  crates.io y compiló sin error de entorno. **No fue BLOQUEADO.**

### 10.5 Integridad final (después del último paso)

- `diff` del checkout contra el **nuevo** `MANIFIESTO-CHECKOUT.sha256` → **vacío**
  (`exit_diff=0`). La compilación de RocksDB no escribió en `checkout/`; `Cargo.lock` intacto
  (`9021465d…`).
- `git -C checkout/PDF/autonomys-subspace status --porcelain` → **vacío**.
- Hashes fijos sin cambios: `e75b1ded…`, `741b75d0…`, `0b387d75…`, `023a9fc8…`; unidad de
  reproducibilidad `619d4950…` / `9021465d…` / `604b0c1b…`.
- `ENTRADA.sha256` → OK. **`ENTRADA-C1.sha256` → OK** (`CORRECCION-L01-S4.md`, `ORDEN-L01.md`,
  `V-ZRX/LINEO.md`), ejecutada después de S3b y como **última** verificación
  (`logs/99-C1-integridad-final.log`).

### 10.6 Presupuesto y alcance

- Presupuesto C1: 1 h / 16 hilos / 48 GiB. Consumo ≈ 2 min de reloj (S4 13 s + S3b 62 s), sin
  tensión de RAM (disco adicional de RocksDB dentro de los 60 GiB; `target` crece). No se agotó.
- No se usó `--offline`, `cargo update`, `--ignored`/`--include-ignored`, Python, ni ningún parche;
  no se escribió fuera de `deepseek/L01/`.
- **Lo que C1 no cambia:** un test que pasa prueba el **contrato antiguo**, no el híbrido; ningún
  parámetro antiguo queda re-derivado; la carga de la máquina no estaba controlada; no se ejecutó
  ninguna prueba `#[ignore]`; S5 sigue siendo opcional y parcial; nada de `zx-p2p`, `zx-mempool`,
  nodo completo ni `tres_nodos`.
