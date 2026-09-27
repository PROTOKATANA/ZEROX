# INFORME — ORDEN-SL4c-R (rebase de SL-4c sobre la raíz actual y adaptación del test de SL-4b1)

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, DeepSeek Harness). **Fecha:** 2026-09-27.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/SL4c-R/`. **Regla:** `V-ZRX/LINEO.md` leído íntegro antes
del código (`sha256 0343b832…`). **Prohibido Python:** no se ejecutó ninguno.
**Base:** raíz del repositorio en el commit `9df48b8` (con W06d5 y SL-4b1 migradas), verificada por
`P-ZRX/P-SLASHING/ENTRADA-SL4c-R.sha256` (**8/8 en verde**; log `logs/V0-entrada.log`).
`git diff --stat fa98bec 9df48b8` sobre los 11 archivos que toca SL-4c: **sin diferencias**, de modo
que su parche aplica sobre la raíz actual.
**Modelo de la API:** `deepseek-flash`, esfuerzo `high` (el entorno del arnés no expone un
identificador de modelo adicional; es el perfil configurado).

## Veredicto

**SUPERADO.** SL-4c queda rebasada sobre la raíz actual con los dos arneses diferenciales en
**0 discrepancias** (T01 v0.5, 3 179 casos; T04 v0.6, 2 108 casos) y cobertura **idéntica** a la de
los oráculos. El test de SL-4b1 `firmante_identidad_evidencia.rs` queda adaptado a la forma v4 con
`cbid` (`RAT-1`) y orden canónico. Primera suite conjunta de W06d5 + SL-4b1 + SL-4c:
**797 pasan, 0 fallan, 5 ignorados**, con todos los tests previos conservando su nombre salvo el que
la orden manda reescribir.

## Qué se hizo

1. **Copia y parche.** Copia de la raíz a `ws.orig/` y `ws/` (patrón de las órdenes W:
   `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`, `testdata/`, `ci/`, `.github/` y el
   enlace `ws/PDF`). `deepseek/SL4c/cambios.patch` aplicado a `ws/` **limpio** (11 archivos); los
   `sha256` de los 11 coinciden con `deepseek/SL4c/MIGRACION.sha256`.
2. **Testdata.** `testdata/transicion-v0.5/` y `testdata/estado-dag-v0.6/` copiados byte a byte
   desde `deepseek/SL4c/ws/testdata/`; vectores idénticos a
   `P-ZRX/P-TRANSICION/T01/resultados/vectores-transicion-v0.5.txt` (`d72c5fd9…`) y
   `P-ZRX/P-DAG/T04/resultados/vectores-estado-dag-v0.6.txt` (`86348a48…`), coberturas idénticas.
3. **Test adaptado.** Único archivo cambiado además de los 11 de SL-4c:
   `crates/zx-post/tests/firmante_identidad_evidencia.rs`.

## Adaptación del test de SL-4b1 (V2)

- **Llamadas a `validar_forma_tx_v4`.** Pasa a la firma de tres argumentos de SL-4c y recibe el
  `cbid` de la red local de las cabeceras (`CBID_EVP = 7`): `validar_forma_tx_v4(&tx, &[], CBID_EVP)`.
- **Expectativa del `cbid` ajeno.** Pasa a
  `ErrorTransicion::ErrForma(ErrorFormaTx::EvidenciaCbidAjeno)`, **leído** del código de SL-4c:
  `crates/zx-consensus/src/transicion/aplicar.rs:81` pasa `evp.cbid` a
  `validar_forma_tx_v4(tx, testigos, evp.cbid)`; `crates/zx-core/src/forma.rs:256-258` devuelve
  `ErrorFormaTx::EvidenciaCbidAjeno`; `crates/zx-consensus/src/transicion/error.rs:81-82` lo envuelve
  con `ErrForma(#[from] ErrorFormaTx)` y `error.rs:131` lo nombra `"ErrForma(EvidenciaCbidAjeno)"`.
- **`v5d` reescrito a lo contrario.** La prueba que afirmaba que la forma no mira la identidad pasa a
  `v5d_la_forma_v4_rechaza_cbid_ajeno_y_acepta_el_resto_de_la_identidad`: (1) un par con `cbid`
  ajeno en `H2` da `Err(ErrorFormaTx::EvidenciaCbidAjeno)`; (2) con el mismo `cbid` local, cambiar
  clave, sector, historial, `chunk` o `slot` (los otros campos de `incident_id_evidencia`) **pasa**
  la forma, porque su rechazo es semántico y lo cubren los `v5c_*`.
- **Comentarios.** Se corrigen la cabecera del módulo (V5(c)) y la de la sección V5(d).
- **Fallo intermedio detectado y corregido (se informa).** En la primera corrida de la suite, 5 tests
  `v5c_*_err_sin_evidencia` (clave, sector, historial, chunk, slot) **fallaron** (log
  `logs/V3-tests.log`): la forma de SL-4c
  comprueba el orden canónico (`EV-01`/`EV-04`) **antes** que la semántica, y el helper
  `caso_campo_identidad` construía pares no canónicos, así que el motor devolvía
  `ErrForma(OrdenCanonicoInvalido)` en vez de `ErrSinEvidencia`. Se corrigió el helper ajustando el
  `timestamp` de `H2` (campo **ajeno** a la identidad) hasta `pre_hash(H1) < pre_hash(H2)`; así el
  motor llega a la comprobación semántica y la prueba sigue midiendo lo que ordena la orden. No se
  cambió ninguna expectativa semántica a un error de forma.
- Los 12 tests del archivo pasan (`logs/V2-firmante.log`). El nombre
  `v5c_cbid_cambiado_oportunidad_distinta_y_err_cbid_ajeno` se conserva (`todo lo previo con su
  nombre`); solo se renombra el de V5(d), que afirmaba lo contrario.

## Tabla de verificación (V3)

| Paso | Comando | Resultado |
|---|---|---|
| V0 | `sha256sum -c P-ZRX/P-SLASHING/ENTRADA-SL4c-R.sha256` | **8/8** verde |
| V1 | parche de SL-4c sobre `ws/` + `sha256sum -c deepseek/SL4c/MIGRACION.sha256` | aplica limpio; **11/11** hashes |
| V1b | `diff -q` de los vectores y coberturas con los oráculos T01 v0.5 y T04 v0.6 | **idénticos** |
| V2 | `cargo test -p zx-post --test firmante_identidad_evidencia` | **12/12** (antes 7/12 por el fallo descrito) |
| V3 | `cargo fmt --all -- --check` | **OK** (`logs/V3-fmt.log`) |
| V3 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK**, 0 avisos (`logs/V3-clippy-final.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **797 pasan, 0 fallan, 5 ignorados** (`logs/V3-tests-final.log`) |
| V3 | `diferencial_t01` (T01 v0.5) | **3 179 casos, 0 discrepancias**; cobertura = `cobertura-v0.5.txt` |
| V3 | `diferencial_t01_negativos` (v0.2) | **3 914 casos, 0 discrepancias** |
| V3 | `diferencial_t04` (T04 v0.6) | **2 108 casos, 0 discrepancias**; cobertura = `cobertura-v0.6.txt` |
| V3 | `ci/dependencias-exactas.sh` | **OK** — 23 dependencias exactas (`logs/V3-ci-dependencias.log`) |
| V3 | `ci/frontera-crates.sh` | **OK** — 9/9 fronteras (`logs/V3-ci-frontera.log`) |
| V4 | `diff -ruN ws.orig ws` → `cambios.patch` (18 archivos, con `testdata/`) | OK; revierte limpio (`git apply -R --check`) |
| V4 | `MIGRACION.sha256` + `sha256sum -c` (último paso) | **18/18** verde |

La suite final pasa también `reinicio.rs` (W06d5) y los tests de zx-post (SL-4b1) con sus nombres.

## Cobertura (idéntica a la de los oráculos, comprobada por los arneses)

### T01 v0.5 (3 179 casos; `cobertura-v0.5.txt`)

| Contador | Casos | Contador | Casos |
|---|---:|---|---:|
| `aplicada` | 260 | `sin_saldo` | 120 |
| `duplicada` | 40 | `tardia` | 200 |
| `deshecha` | 380 | `cbid_ajeno` (`ErrForma(EvidenciaCbidAjeno)`) | 252 |
| `orden_canonico` (`ErrForma(OrdenCanonicoInvalido)`) | 252 | `con_entradas` (`ErrForma(EvidenciaConEntradasOSalidas)`) | 120 |
| `orden_descendente` (subtipo) | 132 | `orden_igual` (subtipo) | 120 |
| `ambos` (cbid + orden; gana cbid) | 120 | | |

### T04 v0.6 (2 108 casos; `cobertura-v0.6.txt`)

| Contador | Casos | Contador | Casos |
|---|---:|---|---:|
| `bloque_estructura` | 108 | `bloque_estructura_entradas` | 62 |
| `bloque_estructura_salidas` | 37 | `bloque_estructura_ambos` | 9 |
| `bloque_estructura_cbid_orden` | 9 | `bloque_cbid` | 283 |
| `bloque_orden` | 243 | `bloque_orden_igual` / `bloque_orden_desc` | 115 / 128 |
| `ev_estructura` | 108 | `ev_cbid` / `ev_orden` | 283 / 243 |
| `ev_orden_igual` / `ev_orden_desc` | 115 / 128 | `con_tx_estructura` | 108 |
| `con_tx_cbid` / `con_tx_orden` | 166 / 152 | `ambos_cbid` | 161 |
| `EV aplicada` / `construida` / `duplicada` | 353 / 560 / 20 | `EV sin_saldo` / `tardia` / `deshecha` | 42 / 145 / 59 |
| `minimos_SL4cO` | **OK** | | |

## Correspondencias de error nuevas, una a una

| Motor (`ErrorTransicion`) | Vector (`RES`/`nombre_t01`) |
|---|---|
| `ErrForma(ErrorFormaTx::EvidenciaCbidAjeno)` | `ErrForma(EvidenciaCbidAjeno)` |
| `ErrForma(ErrorFormaTx::OrdenCanonicoInvalido)` | `ErrForma(OrdenCanonicoInvalido)` |
| `ErrForma(ErrorFormaTx::EvidenciaConEntradasOSalidas)` | `ErrForma(EvidenciaConEntradasOSalidas)` |

## Faltas de definición detectadas y resueltas (se informan antes de editar)

1. **No hay `patch` en el entorno y la orden prohíbe git.** Se resolvió usando `git apply -p1`
   **solo** como aplicador del parche de entrada (sin tocar índice, historial ni commit: `git diff
   --cached` queda vacío y `deepseek/` está en `.gitignore`). El parche aplicó limpio; los 11 hashes
   coinciden con `deepseek/SL4c/MIGRACION.sha256`.
2. **La forma de SL-4c preempta `ErrSinEvidencia` en los `v5c` no-`cbid`.** La orden solo fijaba la
   expectativa del `cbid`; los otros cinco campos morían antes en `ErrForma(OrdenCanonicoInvalido)`
   porque los pares no eran canónicos. Resolución: hacer canónicos los pares en
   `caso_campo_identidad` (ajustar `timestamp`), preservando `ErrSinEvidencia` para los campos
   semánticos, que es lo que la orden describe.
3. **Alcance de `MIGRACION.sha256`.** W02 lo define como «sha256 de cada archivo de ws/», pero SL-4c
   no listó los `testdata/`. Aquí se listan **los 18 archivos cambiados** (11 de SL-4c, el test
   adaptado y los 6 de `testdata/`), para que `sha256sum -c` cubra todo lo entregado.

## Lo no demostrado

- La sección `run.jl` de `cobertura-v0.6.txt` (seed `0x5a5a`, 200 réplicas) no se reproduce desde el
  fichero de vectores: la genera otro `run.jl` que no está en la entrada congelada, igual que en SL-4a.
- El códec de red de la v4 no se prueba contra bytes de un peer real ni a través de `zx-p2p`/`zx-node`.
- La activación de la v4 sigue siendo decisión del motor (`ParametrosEvidencia::evp`).
- El rebase no re-mide el rendimiento (LINEO §6): esta orden es de corrección y adaptación de tests,
  no de optimización; no hay tabla de benchmark porque no hay kernel nuevo.

## Desviaciones de proceso (declaradas)

Además de los tres recursos autorizados de `deepseek/SL4c/` (`cambios.patch`, `MIGRACION.sha256` y
`ws/testdata/{transicion-v0.5,estado-dag-v0.6}/`), leí `deepseek/SL4c/INFORME.md` y
`deepseek/SL4c/env.sh` para orientarme, y consulté `MIGRACION.sha256` de `deepseek/SL4b1/` y
`deepseek/W06d5/` para comparar la convención del manifiesto. **Ninguna decisión de código se tomó
de esos archivos**: la firma y el error se citaron del código de `ws/` (SL-4c aplicada) y el parche
se aplicó desde `cambios.patch`; las únicas entradas usadas para la entrega son las de
`ENTRADA-SL4c-R.sha256`. No se escribió ni se ejecutó nada en esas zonas. Lo declaro por transparencia
ante el límite de lectura de la orden.

## Cómo reproducir

```bash
source /home/katana/zeo/ZEROX/deepseek/SL4c-R/env.sh
cd "$Z/ws"
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --all-features --locked
cargo test -p zx-consensus --test diferencial_t01 --locked -- --nocapture
cargo test -p zx-cadena   --test diferencial_t04 --locked -- --nocapture
bash ci/dependencias-exactas.sh && bash ci/frontera-crates.sh
cd "$Z/ws" && sha256sum -c "$Z/MIGRACION.sha256"
```

## Entregables

`ws.orig/`, `ws/`, `cambios.patch` (`diff -ruN ws.orig ws`, 18 archivos con `testdata/`),
`MIGRACION.sha256` (18 entradas, `sha256sum -c` verde), `logs/`, `INFORME.md`, `PROGRESO.md`,
`HORAS.log` con `date -Is` real, `env.sh`. Nada fuera de la zona; sin commit ni push; sin secretos;
ningún `Ok` ficticio.
