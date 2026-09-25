# ORDEN-L01 — Línea base reproducible de las primitivas candidatas del ZEROX antiguo

## 1. Identidad y contexto

- **ID:** L01. **Estado:** redactada 2026-09-26, **pendiente de lanzar** (bloqueo
  `R-ZRX/HARNESS.md` B-HARNESS-01). **Director:** Claude (rol de `AUTO-ZRX.md`).
- **Proyecto:** `/home/katana/zeo/ZEROX` (rama `rediseno/v1-spec-first`).
- **Zona de ejecución (única escribible):** `/home/katana/zeo/ZEROX/deepseek/L01/`. La sesión se
  lanza con ese directorio como `cwd`; todo lo demás es de solo lectura para ti.
- **Objetivo único:** reproducir, **sin modificar una sola línea**, la compilación y las suites de
  pruebas acotadas de las primitivas candidatas del código antiguo (commit `9681061`), con la
  toolchain y el lock originales, y conservar la salida cruda.
- **Pregunta falsable:** «Las suites de `zx-core`, `zx-pot`, `zx-consensus` y `zx-storage` del
  commit `9681061`, con `Cargo.lock` y `nightly-2026-05-03` originales y el clon de Autonomys en
  `f8842d019cdf0f7163421b9644db5a9ff82b2a73`, compilan con `--locked` y pasan todas sus pruebas no
  ignoradas en esta máquina.» Se refuta con un fallo de compilación o una prueba fallida.
- **Desbloquea:** `D-ZRX/IPA-ZRX.md` E-01, B-01, B-02, B-03 (línea base) y el portado posterior.

## 2. Autoridad y entradas

Lee **íntegros**, antes de nada:

1. Este archivo.
2. `/home/katana/zeo/ZEROX/V-ZRX/LINEO.md` (obligatorio aunque aquí no escribas cálculo nuevo: rigen
   sus reglas de reproducibilidad, versiones, presupuesto de recursos, trazas y fallos). Donde
   LINEO nombra `veritas/`, léase tu zona de ejecución.
3. `/home/katana/zeo/ZEROX/R-ZRX/MAPA-RESCATE.md` §1 (qué pieza es cada crate y por qué importa).

Fuentes de código (solo lectura, **material histórico no normativo**):

- Repositorio git `/home/katana/zeo/ZEROX`, commit `9681061` (código antiguo completo). Se extrae
  con `git archive`; **no** hagas checkout, worktree, stash, reset ni ninguna operación que escriba
  en `/home/katana/zeo/ZEROX/.git` o en el árbol de trabajo.
- Clon de Autonomys: `/home/katana/zeo/.trash/zerox/PDF/autonomys-subspace/` (repositorio git,
  `HEAD` = `f8842d019cdf0f7163421b9644db5a9ff82b2a73`). Se clona a tu zona; no se modifica el
  original.
- `/home/katana/zeo/.trash/` entero es **solo lectura**. No muevas, renombres ni reorganices nada
  fuera de tu zona.

Entrada congelada: `/home/katana/zeo/ZEROX/P-ZRX/P-LINEA-BASE/ENTRADA.sha256`. Compruébala **al
empezar y al terminar** con

    cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-LINEA-BASE/ENTRADA.sha256

y copia ambas salidas completas a `PROGRESO.md`.

## 3. Decisiones ya tomadas por el director (no las cambies)

- Se reproduce el código **tal cual**: ni parches, ni cambios de versión, ni `cargo update`, ni
  `--offline` forzado para esquivar un fallo, ni tests desactivados, ni features distintas de las
  listadas. Si algo no compila o falla, **se informa**, no se arregla.
- Toolchain: la de `rust-toolchain.toml` del commit (`nightly-2026-05-03`, ya instalada en
  `~/.rustup`). No instales ni cambies toolchains.
- Diseño de rutas: el workspace antiguo espera el clon en `PDF/autonomys-subspace/` **dentro** del
  checkout (lo excluye expresamente en `Cargo.toml`). Se reproduce ese diseño físicamente con un
  clon local, no con un enlace simbólico.
- Alcance fijo de suites: §6. No añadas `zx-p2p`, `zx-mempool`, `zx-node` completo ni `tres_nodos`.

Si alguna instrucción de esta orden resulta ambigua o imposible **antes de ejecutar**, detente y
descríbelo en `PROGRESO.md` e `INFORME.md`; no elijas tú.

## 4. Contrato de ejecución (no hay implementación)

Archivos que puedes crear, todos dentro de `/home/katana/zeo/ZEROX/deepseek/L01/`:

    checkout/                     extracción de 9681061 (solo lectura tras extraer)
    checkout/PDF/autonomys-subspace/   clon local fijado
    .cargo-home/                  CARGO_HOME
    target/                       CARGO_TARGET_DIR
    logs/                         salida cruda de cada comando
    MANIFIESTO-CHECKOUT.sha256    huellas de todo lo extraído
    HORAS.log                     `date -Is` antes y después de cada paso
    PROGRESO.md, INFORME.md, RESULTADOS.tsv, ENTORNO.txt

Preparación exacta (cada comando con su salida en `logs/`):

    cd /home/katana/zeo/ZEROX/deepseek/L01
    date -Is >> HORAS.log
    mkdir -p checkout logs
    git -C /home/katana/zeo/ZEROX archive 9681061 \
        crates prototipos testdata veritas ci Cargo.toml Cargo.lock rust-toolchain.toml \
      | tar -x -C checkout
    git clone --no-hardlinks /home/katana/zeo/.trash/zerox/PDF/autonomys-subspace \
        checkout/PDF/autonomys-subspace
    git -C checkout/PDF/autonomys-subspace checkout --detach f8842d019cdf0f7163421b9644db5a9ff82b2a73
    git -C checkout/PDF/autonomys-subspace rev-parse HEAD      # debe imprimir f8842d0…
    (cd checkout && find . -path ./PDF -prune -o -type f -print0 | sort -z \
        | xargs -0 sha256sum) > MANIFIESTO-CHECKOUT.sha256

Variables de entorno para **todos** los comandos cargo:

    export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/L01/.cargo-home
    export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/L01/target
    export CARGO_BUILD_JOBS=16
    export RUST_TEST_THREADS=16
    export RUSTFLAGS=           # vacío: no heredes flags del entorno

El `/tmp` del sandbox se vacía entre llamadas: no dejes nada ahí. Las compilaciones largas
lánzalas en segundo plano y consulta su salida; el límite por llamada síncrona es de 60 s.

Registra en `ENTORNO.txt`: `uname -a`, `nproc`, `free -g`, `uptime` (antes y después: hay otros
procesos en la máquina), `rustup show active-toolchain` y `rustc -Vv` ejecutados **desde
`checkout/`**, `cargo -V`, y el nombre de modelo que figure en tu propio contexto o respuesta de la
API si lo conoces.

## 5. Modelo de amenaza

No aplica al resultado (no es una medición de seguridad). Sí aplica a la **integridad de la
evidencia**: un test que «pasa» tras tocar el código o el lock no vale; un test que no se ejecutó
no cuenta como pasado; un conteo no coincidente se informa.

## 6. Plan de verificación

Ejecuta, en este orden, cada comando **desde `checkout/`**, con `--locked`, guardando stdout y
stderr completos en `logs/<paso>.log` y el código de salida:

| Paso | Comando | Qué verifica |
|---|---|---|
| S0 | `cargo metadata --locked --format-version 1 > ../logs/S0-metadata.json` | Resolución del grafo con el lock original |
| S1 | `cargo test --locked -p zx-core` | SHA3 con dominio y CAVP (oráculo NIST independiente), códec, vectores DAG, oráculo Julia de cabecera DAG, propiedades de parsers |
| S2 | `cargo test --locked -p zx-pot` | PoT AES y 32 vectores diferenciales |
| S3 | `cargo test --locked -p zx-storage` | UTXO/undo en memoria, almacén diferencial, `matar_a_mitad` (sin feature `rocksdb`) |
| S4 | `cargo test --locked -p zx-consensus` | Todo el crate: GHOSTDAG (+ oráculos), PoAS real (fixture paralela), PoT, firmante, emisión, LWMA, fork choice, génesis |
| S5 (opcional, solo si S1–S4 terminaron y queda presupuesto) | `cargo test --locked -p zx-node --features farmer --test farmer_disco` | Plotter y auditor PoAS reales en disco |

No ejecutes pruebas `#[ignore]` (no uses `--ignored` ni `--include-ignored`).

Tras cada paso, anota en `RESULTADOS.tsv` una fila por binario de prueba:

    paso  crate  binario  pasadas  fallidas  ignoradas  filtradas  segundos  codigo_salida

Conteo de referencia por `grep '#[test]'` del inventario (no es expectativa exacta: doctests,
`cfg` y features alteran el número ejecutado): `zx-core` 156, `zx-pot` 5, `zx-storage` 60,
`zx-consensus` 422 con 4 `#[ignore]`. Explica cualquier diferencia.

Comprueba además y anota el resultado:

- `sha256sum checkout/testdata/nist-cavp/SHA3_256ShortMsg.rsp checkout/testdata/nist-cavp/SHA3_256LongMsg.rsp checkout/testdata/nist-cavp/SHA3_256Monte.rsp checkout/crates/zx-pot/tests/vectores-nightly.txt`
  debe dar, en ese orden, prefijos `e75b1ded`, `741b75d0`, `0b387d75`, `023a9fc8`.
- Al terminar, **integridad del checkout**:
  `(cd checkout && find . -path ./PDF -prune -o -type f -print0 | sort -z | xargs -0 sha256sum) | diff - MANIFIESTO-CHECKOUT.sha256`
  debe salir vacío (la compilación no escribe en `checkout/` porque `CARGO_TARGET_DIR` está fuera;
  si aparece `Cargo.lock` modificado, es un fallo que se informa).
- `git -C checkout/PDF/autonomys-subspace status --porcelain` debe salir vacío.

**LINEO:** aplica sus reglas de reproducibilidad (§1, §7): versiones exactas, comando exacto, hora,
hardware, carga de la máquina, presupuesto y fallos con entrada mínima. **Prohibido crear o
ejecutar Python** para cualquier fin (parseo de logs incluido): usa herramientas de shell.

## 7. Medición

No es un benchmark. Los segundos de `RESULTADOS.tsv` son **tiempo de pared observado con carga
ajena posible**, no rendimiento; no los presentes como medida. Presupuesto máximo de la sesión:
**3 h de reloj, 16 hilos de compilación/prueba (tope de LINEO: 24), 48 GiB de RAM, 60 GiB de disco
en la zona**. Si se agota, detente, conserva logs y declara el paso **inconcluso**; un timeout no es
un fallo del código.

Criterio de aceptación, fijado **antes** de ejecutar, por paso:

- **REPRODUCIDO:** compila con `--locked` sin cambios y 0 fallidas.
- **FALLA:** error de compilación o ≥ 1 prueba fallida (con el nombre y la salida de cada una).
- **BLOQUEADO:** el entorno impide ejecutar (red, sandbox, toolchain, permisos) — con el error
  literal.
- **INCONCLUSO:** presupuesto agotado.

## 8. Entregables

En `/home/katana/zeo/ZEROX/deepseek/L01/`:

- `INFORME.md` con: tabla paso → veredicto; archivos creados; comandos exactos; resultados; fallos
  con salida literal; riesgos; y una sección **«Lo que esta orden NO demuestra»**, que debe decir
  como mínimo: que un test antiguo que pasa prueba su **contrato antiguo**, no el híbrido; que no se
  ha validado ninguna constante antigua; y que la carga de la máquina no estaba controlada.
- `PROGRESO.md` con las dos comprobaciones de `ENTRADA.sha256` y un diario de pasos.
- `RESULTADOS.tsv`, `ENTORNO.txt`, `HORAS.log`, `MANIFIESTO-CHECKOUT.sha256`, `logs/`.

Resumen final (tu última respuesta, en español, ≤ 40 líneas): veredicto por paso, fallos,
bloqueos, diferencias de conteo, integridad del checkout y de `ENTRADA.sha256`.

## 9. Límites de la sesión

- Modelo `deepseek-v4.1-flash` (id de catálogo del Harness: `deepseek-flash`, «DeepSeek-V41-Flash»),
  esfuerzo `high`, solo DeepSeek Harness.
- Lee íntegro y aplica `V-ZRX/LINEO.md` antes de ejecutar nada.
- Ningún código Python, ni de auditoría ni de pruebas, ni auxiliar.
- No elijas arquitectura, parámetros ni criterios; no amplíes el alcance.
- No modifiques nada fuera de `/home/katana/zeo/ZEROX/deepseek/L01/`, ni el checkout tras extraerlo.
- No sustituyas un resultado por `Ok`, no ocultes un fallo, no reintentes con cambios para «ponerlo
  en verde».
- No hagas commit, push ni ninguna operación de escritura git fuera de tu zona.
- No leas, imprimas ni copies `.env`, credenciales, tokens ni `~/.dsh/`.
- Si una prueba falla, repórtala con su salida literal.

## Lanzamiento (lo ejecuta el director cuando B-HARNESS-01 se resuelva)

    mkdir -p /home/katana/zeo/ZEROX/deepseek/L01 && cd /home/katana/zeo/ZEROX/deepseek/L01 && \
    node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden L01. Lee íntegro el archivo /home/katana/zeo/ZEROX/P-ZRX/P-LINEA-BASE/ORDEN-L01.md y cúmplelo. Antes de ejecutar o escribir nada, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de actuar." \
      > dsh.stdout 2> dsh.stderr

La referencia de la sesión (directorio en `~/.dsh/sessions/`) y la hora de lanzamiento se anotan en
`P-ZRX/P-LINEA-BASE/SESION.md` al lanzar.
