# ORDEN-W01 — Workspace Rust nuevo con `zx-core` y `zx-pot` portados sin cambios

## 1. Identidad y contexto

- **ID:** W01. **Estado:** redactada 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek
  (portado mecánico y verificación; no requiere el plus de Sonnet).
- **Zona de ejecución (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W01/`.
- **Objetivo único:** preparar en `deepseek/W01/ws/` el **workspace Rust inicial del árbol nuevo**
  —que el director migrará a la raíz del repositorio tras revisarlo— con `zx-core` y `zx-pot`
  copiados **byte a byte** del commit `9681061`, sus vectores, un `Cargo.lock` recortado del antiguo
  **sin cambiar ninguna versión**, y una CI nueva que sustituya a la rota.
- **Pregunta falsable:** «`zx-core` y `zx-pot` de `9681061`, fuera de su workspace original, con el
  lock recortado y la misma toolchain, pasan exactamente los mismos tests que en la línea base L01
  (156 y 5), con `fmt`, `clippy -D warnings` y `--locked`.» Se refuta con un test distinto, un
  fallo, un aviso de clippy o una versión de paquete distinta de la del lock antiguo.
- **Desbloquea:** `D-ZRX/IPA-ZRX.md` E-02, E-03; `P-ZRX/PLAN-0.0.1.md` W02.

## 2. Autoridad y entradas

Lee **íntegros** antes de nada: este archivo; `/home/katana/zeo/ZEROX/V-ZRX/LINEO.md` (rige
reproducibilidad, versiones, recursos y fallos); `/home/katana/zeo/ZEROX/P-ZRX/PLAN-0.0.1.md`
(§3, D-P01 y D-P03); la entrega de L01 en `/home/katana/zeo/ZEROX/deepseek/L01/INFORME.md` y sus
logs `logs/S1-zx-core.log` y `logs/S2-zx-pot.log` (lista de tests de referencia).

Fuentes (solo lectura, material histórico):

- Repositorio `/home/katana/zeo/ZEROX`, commit `9681061`, extraído con `git archive` (no escribas en
  `.git` ni en el árbol de trabajo del repositorio).
- `.github/workflows/zerox-ci.yml` **del árbol actual** (roto: llama a scripts borrados) y el de
  `9681061` (`git show 9681061:.github/workflows/zerox-ci.yml`), como referencia.
- Caché de cargo de L01: `/home/katana/zeo/ZEROX/deepseek/L01/.cargo-home/` (puedes copiarla a tu
  zona para no volver a descargar; no la modifiques en su sitio).

Entrada congelada: `/home/katana/zeo/ZEROX/P-ZRX/P-WORKSPACE/ENTRADA-W01.sha256`; compruébala al
**empezar** y como **último** paso, con la salida en `PROGRESO.md`.

## 3. Decisiones ya tomadas por el director

1. **Copia byte a byte** de `crates/zx-core/` y `crates/zx-pot/` de `9681061`. **Única excepción
   permitida:** en `crates/zx-core/tests/oraculo_julia.rs`, la ruta del fichero de vectores pasa de
   `veritas/consenso/vectores-cabecera-dag/resultados/vectores.txt` a
   `testdata/vectores-cabecera-dag/vectores.txt` (mismos componentes de `PathBuf`, sustituyendo
   solo los segmentos de la ruta; actualiza el comentario que explica la ruta). Ningún otro cambio.
2. Vectores: `testdata/nist-cavp/` completo (con su `README.md`) copiado de `9681061`; el fichero
   `veritas/consenso/vectores-cabecera-dag/resultados/vectores.txt` de `9681061` copiado a
   `testdata/vectores-cabecera-dag/vectores.txt` **sin cambios**, con un `PROCEDENCIA.md` al lado que
   diga: ruta de origen, commit, sha256, qué instrumento Julia lo generó y que **no** es un
   instrumento re-validado en el árbol nuevo.
3. `Cargo.toml` raíz: parte del de `9681061` y deja **solo** los miembros `crates/zx-core` y
   `crates/zx-pot`, sin la lista `exclude` (todavía no hay clon de Autonomys), con
   `[workspace.package]` idéntico (incluida `license = "AGPL-3.0-or-later"`), las mismas `[lints]`
   del workspace, y en `[workspace.dependencies]` **solo** las entradas que usan esos dos crates
   (incluidas las de desarrollo), con la versión exacta `=x.y.z` antigua. Conserva los comentarios
   de las entradas que quedan.
4. `rust-toolchain.toml` idéntico al de `9681061`.
5. `Cargo.lock`: copia el antiguo y deja que cargo lo **recorte** con un único
   `cargo metadata --format-version 1 >/dev/null` **sin** `--locked` (ni `cargo update`, ni
   `generate-lockfile`). Después demuestra con shell/awk (no Python) que cada `name`+`version` del
   lock nuevo existe con **la misma versión** en el antiguo, y guarda la comparación en
   `logs/lock-subconjunto.txt`. Si alguna versión cambia, **para** y repórtalo.
6. `ci/dependencias-exactas.sh` copiado sin cambios de `9681061`.
7. CI nueva en `ws/.github/workflows/zerox-ci.yml`, que sustituirá a la rota. Solo dos jobs:
   `rust` (toolchain `nightly-2026-05-03` con `rustfmt` y `clippy`; `cargo fmt --all -- --check`;
   `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`;
   `cargo build --workspace --all-features --locked`; `cargo test --workspace --all-features
   --locked`) y `deps` (`bash ci/dependencias-exactas.sh`). Acciones fijadas como en la antigua
   (`actions/checkout@v4`, `dtolnay/rust-toolchain@master`, `Swatinem/rust-cache@v2`). Comentario
   de cabecera que diga qué cubre y qué **no** cubre todavía (consenso, nodo, red).
8. **No** portes `zx-consensus`, `zx-storage`, `zx-node`, `zx-p2p` ni el clon de Autonomys: son
   órdenes posteriores.

Si algo de esto no puede cumplirse tal cual, **para** y descríbelo antes de improvisar.

## 4. Contrato de ejecución

Estructura esperada:

    deepseek/W01/
    ├── ws/                         ← lo que se migrará a la raíz del repositorio
    │   ├── Cargo.toml  Cargo.lock  rust-toolchain.toml
    │   ├── crates/zx-core/  crates/zx-pot/
    │   ├── testdata/nist-cavp/  testdata/vectores-cabecera-dag/{vectores.txt,PROCEDENCIA.md}
    │   ├── ci/dependencias-exactas.sh
    │   └── .github/workflows/zerox-ci.yml
    ├── .cargo-home/   target/      ← fuera de ws/: no se migran
    ├── logs/  MIGRACION.sha256  INFORME.md  PROGRESO.md  HORAS.log

Variables para todos los comandos cargo (desde `ws/`):

    export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/W01/.cargo-home
    export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/W01/target
    export CARGO_BUILD_JOBS=8 RUST_TEST_THREADS=8 RUSTFLAGS=

(8 hilos: hay otras órdenes compilando en la máquina.) Compilaciones largas en segundo plano.

`MIGRACION.sha256`: `sha256sum` de **cada** archivo bajo `ws/`, con rutas relativas a `ws/`
(`cd ws && find . -type f -print0 | sort -z | xargs -0 sha256sum`). El director migrará con esa
lista y la volverá a comprobar en la raíz.

## 5. Modelo de amenaza

Integridad de la evidencia: un test que pasa tras editar el código no cuenta; comprueba con
`diff -r` contra la extracción de `9681061` que los crates son idénticos salvo la línea autorizada
de `oraculo_julia.rs`, y guarda la salida en `logs/diff-crates.txt`.

## 6. Plan de verificación

Desde `ws/`, con `--locked` tras el recorte del lock, y salida completa en `logs/`:

| Paso | Comando | Criterio |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | sin diferencias |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | sin avisos |
| V3 | `cargo test --workspace --all-features --locked` | `zx-core` 156 pasadas, `zx-pot` 5, 0 fallidas |
| V4 | Comparación de nombres de test: extrae las líneas `test <nombre> ... ok` de V3 y de `deepseek/L01/logs/S1-zx-core.log` + `S2-zx-pot.log`, ordénalas y compáralas con `diff` | idénticas |
| V5 | `bash ci/dependencias-exactas.sh` | éxito |
| V6 | `diff -r` de crates frente a la extracción de `9681061` | solo la línea autorizada |

**Prohibido Python.** Usa shell, `awk`, `sort`, `diff`.

## 7. Medición

No hay medición. Presupuesto: **1 h de reloj, 8 hilos, 16 GiB de RAM, 20 GiB de disco**.
Criterio: **SUPERADO** si V1–V6 cumplen; **FALLA** con el paso y la salida literal; **BLOQUEADO**
si el entorno lo impide.

## 8. Entregables

`ws/` completo, `MIGRACION.sha256`, `logs/`, `INFORME.md` (veredicto por paso, archivos creados,
lista exacta de diferencias con `9681061`, dependencias conservadas y eliminadas del workspace,
riesgos, y «Lo que esta orden NO demuestra»: que el portado cambie o valide ninguna regla de
consenso híbrido; que la CI se haya ejecutado en GitHub), `PROGRESO.md`, `HORAS.log`.

Resumen final (≤ 30 líneas, español).

## 9. Límites de la sesión

DeepSeek Harness, `deepseek-flash` («DeepSeek-V41-Flash»), esfuerzo `high`. Lee y aplica
`V-ZRX/LINEO.md`. Sin Python. Nada fuera de `deepseek/W01/`. Sin commit ni push. Sin leer secretos
(`.env`, `~/.dsh/`, credenciales). Ningún `Ok` ficticio; si algo falla, repórtalo literal.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W01 && cd /home/katana/zeo/ZEROX/deepseek/W01 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W01. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-WORKSPACE/ORDEN-W01.md y cúmplelo. Antes de ejecutar o escribir nada, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de actuar." \
      > ../W01-dsh.stdout 2> ../W01-dsh.stderr )
