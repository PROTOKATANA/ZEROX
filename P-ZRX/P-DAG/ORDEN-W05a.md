# ORDEN-W05a — Crate `zx-dag`: GHOSTDAG, padres contextuales y vista causal, con raíz en el terminal PoW

## 1. Identidad y contexto

- **ID:** W05a. **Estado:** redactada 2026-09-26; se lanza tras migrar W04. **Director:** Claude.
  **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W05a/`.
- **Objetivo único:** portar al crate **nuevo** `crates/zx-dag` el orden DAG del commit `9681061`
  (`ghostdag.rs`, `bloque_dag.rs`, la parte genérica de `dag_causal.rs` y la identidad de billete),
  con las decisiones D-P07, D-P08 y D-P13 de `P-ZRX/P-DAG/DECISIONES-W05.md`, sin cambiar la lógica
  de GHOSTDAG y reproduciendo sus oráculos.
- **Pregunta falsable:** «GHOSTDAG portado reproduce exactamente los vectores de sus dos oráculos
  antiguos (GDR-v0.2 y rusty-kaspa) y sus tests, con la raíz en el `block_hash` de una cabecera PoW de
  92 B, y la comprobación de padres rechaza toda cabecera PoST sin padres o con un padre PoW que no
  sea el terminal.» Se refuta con un vector distinto o un rechazo que falta.
- **Desbloquea:** W05b (puerta conjunta PoST) y W06 (nodo).

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-DAG/DECISIONES-W05.md`;
`P-ZRX/P-TRANSICION/CONTRATO-v0.md` §0 (D-T02) y TRN-06; `P-ZRX/PLAN-0.0.1.md`. Código antiguo,
solo lectura, con `git -C /home/katana/zeo/ZEROX show 9681061:<ruta>`:
`crates/zx-consensus/src/ghostdag.rs`, `bloque_dag.rs`, `firmante/identidad.rs`, la función
`Firmante::identidad` de `firmante/mod.rs`, `error.rs` (variantes usadas),
`crates/zx-node/src/dag_causal.rs`; tests `crates/zx-consensus/tests/ghostdag_rust.rs`,
`ghostdag_prop.rs`, `ghostdag_oraculo.rs`, `ghostdag_bench.rs` (`#[ignore]`), los tests internos de
esos módulos y los de `dag_causal.rs`; vectores
`veritas/consenso/ghostdag-rank-v1/resultados/{corpus-rust.txt,kaspa-rust.txt}`.
Base de trabajo: el workspace de la raíz (con W02 y W04 migradas).
Entrada congelada: `P-ZRX/P-DAG/ENTRADA-W05a.sha256`, al empezar y como último paso.

## 3. Decisiones ya tomadas por el director

1. **Crate `zx-dag`** (miembro del workspace), dependencias: `zx-core`, `primitive-types`,
   `thiserror` y las de test ya presentes. **No** depende de `zx-consensus` ni de `zx-storage`.
2. **Identidad de billete** (`identidad.rs`): `IdentidadTicket` portado de `firmante/identidad.rs`
   sin cambios de bytes (`huella`, `bytes_canonicos`), y `identidad_de_cabecera(&DagBlockHeader)`
   con el cuerpo de `Firmante::identidad`. El registro durable del firmante **no** se porta (W06).
3. **`ghostdag.rs`**: lógica idéntica; `Firmante::identidad` → `identidad_de_cabecera`;
   `ConsensusError` → `ErrorDag` con las mismas variantes usadas. Las constantes (`k = 30`, 15
   padres, mergeset 180, `S_max = 150`) se conservan **como parámetros de `Parametros`** con los
   valores antiguos por defecto para los tests; docstring: «valores del consenso antiguo,
   condicionales; la red dev fijará los suyos».
4. **`bloque_dag.rs` con D-P08:** `ContextoDag` pierde `es_genesis` y gana
   `es_terminal(&BlockHash) -> bool`. `comprobar_padres_contextual`: `count() == 0` ⇒
   `ErrorDag::CabeceraPostSinPadres` (siempre); si el padre seleccionado es el terminal, la cabecera
   debe tener **exactamente un** padre (si no, `ErrorDag::TerminalConPadresExtra`); si algún padre
   adicional es el terminal ⇒ `ErrorDag::TerminalComoPadreExtra`; si un padre no es el terminal ni un
   bloque PoST validado del contexto ⇒ `PadreNoValidado` (como antes). El resto de comprobaciones
   (anticadena, orden ascendente, `prev_hash = sp`) sin cambios.
5. **Raíz GHOSTDAG (D-P07):** constructor de conveniencia
   `AlmacenGhostdag::con_raiz_terminal(params, algoritmo, hash_terminal, sr_raiz)` =
   `nuevo(params, algoritmo, hash_terminal, 0, sr_raiz, 0)`.
6. **`dag_causal.rs`:** se portan `RegistroEstructural`, `FuenteRegistrosDag`, `PresupuestoVista`,
   `ErrorVistaCausal` y `VistaPasadoEstructural`; **no** `FuenteIndiceAdmitidos` (depende del
   almacén: W06). Los tests que usaban `IndiceFake` sobre `AlmacenAdmitidosDag` se reescriben con una
   `FuenteRegistrosDag` en memoria que sirva los **mismos** registros; la raíz de la vista es el
   terminal (registro con `padres` vacíos marcado como terminal, no como génesis DAG).
7. **Vectores de los oráculos** copiados sin cambios a `testdata/ghostdag-rank-v1/` con
   `PROCEDENCIA.md` (origen, commit, sha256, instrumento, «no re-validado en el árbol nuevo»), y las
   rutas de `ghostdag_oraculo.rs` cambiadas solo en sus segmentos (como W01).
8. **Tests que dejan de aplicar** (por ejemplo, los que construían un génesis DAG con 0 padres como
   válido) se sustituyen por su versión «primer hijo del terminal» o se retiran **declarándolos** en
   el informe uno a uno con el motivo (D-P08). Ningún test de lógica de GHOSTDAG se retira.

Si algo no se puede cumplir tal cual, **para** e infórmalo antes de improvisar.

## 4. Contrato de ejecución

Patrón W02/W04: `deepseek/W05a/{ws.orig, ws}` copiados de la raíz, `cambios.patch`,
`MIGRACION.sha256`, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`; caché de cargo copiable de
`deepseek/W04/.cargo-home` (o W02/W01); `CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`, `RUSTFLAGS=`.
`Cargo.lock`: añadir `zx-dag` sin cambiar versiones (comprobación `logs/lock-subconjunto.txt`).

## 5. Modelo de amenaza

Cabeceras DAG de un par hostil: sin padres, con el terminal como padre adicional, con padres PoW
ajenos, con padres desordenados o duplicados, que no son anticadena; mergesets máximos. Ningún
pánico.

## 6. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo pasa con el mismo nombre; los portados y nuevos pasan |
| V4 | `ghostdag_oraculo`: GDR-v0.2 (`corpus-rust.txt`) y rusty-kaspa (`kaspa-rust.txt`) | coincidencia total |
| V5 | Lista de tests antiguos de GHOSTDAG/bloque_dag/dag_causal portados, sustituidos y retirados, con motivo | ningún test de lógica GHOSTDAG retirado |
| V6 | Casos nuevos de D-P08: 0 padres; transición con 2 padres; terminal como padre extra; padre PoW ajeno; transición válida con `T` como único padre y almacén con raíz `T` | cada uno con su resultado |
| V7 | `bash ci/dependencias-exactas.sh` | OK |

**Prohibido Python.** Presupuesto: **2 h, 8 hilos, 16 GiB, 20 GiB de disco**. **SUPERADO** si V1–V7.

## 7. Entregables y límites

`ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md` (veredicto; tabla de tests
portados/sustituidos/retirados; API de `zx-dag`; «Lo que esta orden NO demuestra»: admisión en el
nodo, verificación PoT/PoAS, persistencia, parámetros dev), `PROGRESO.md`, `HORAS.log`. Resumen
final ≤ 40 líneas. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO antes del código; sin Python;
nada fuera de `deepseek/W05a/`; sin commit ni push; sin secretos; ningún `Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W05a && cd /home/katana/zeo/ZEROX/deepseek/W05a && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W05a. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-DAG/ORDEN-W05a.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W05a-dsh.stdout 2> ../W05a-dsh.stderr )
