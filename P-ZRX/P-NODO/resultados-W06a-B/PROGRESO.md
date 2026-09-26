# PROGRESO.md — ORDEN-W06a-B

Diferenciales de `zx-consensus` (T01) y `zx-cadena` (T04) contra los oráculos T01-E (vectores v0.2) y
T04-D (vectores v0.3), **sin emulación de ids**. Zona única:
`/home/katana/zeo/ZEROX/deepseek/W06aB/`. Base: workspace de la raíz copiado a `ws.orig/` y `ws/`.

## Entrada congelada — comprobación de INICIO

`sha256sum -c P-ZRX/P-NODO/ENTRADA-W06a-B.sha256` desde la raíz: **9/9 coinciden**, exit 0
(`logs/entrada-inicio.log`). `V-ZRX/LINEO.md` se leyó íntegro **antes** de escribir código. Como esta
orden es Rust de consenso (no Julia/C++), las reglas de LINEO aplicables se traducen así: oráculos
consumidos como **vectores** (no recomputados), determinismo explícito, aritmética entera comprobada
(`checked_*`, sin flotantes ni `@fastmath`), nada de `unsafe`, presupuesto declarado (1 h 30 min,
8 hilos, 16 GiB) y prohibición de Python.

## Falta de definición detectada e informada ANTES de editar

Ninguna impide cumplir la orden; se declaran dos interpretaciones y **un hallazgo posterior** (§
«Hallazgo»), todos sin inventar semántica nueva:

1. **Alcance de «copia la raíz».** La raíz de `ZEROX` contiene documentación (`P-ZRX/`, `V-ZRX/`, …),
   `.git/` y `deepseek/`. Copiarlos literalmente sería recursivo y no son el workspace de Cargo.
   **Interpretación** (precedente de W06a): se copia el workspace —`Cargo.toml`, `Cargo.lock`,
   `rust-toolchain.toml`, `crates/`, `ci/`, `testdata/`, `.github/`— y `PDF` como enlace, excluido de
   `cambios.patch`/`MIGRACION.sha256`.
2. **Alcance de V5.** `cobertura-v0.3.txt` tiene dos apartados; el arnés solo ve los vectores.
   **Interpretación** (precedente de W06a): se compara la sección `vectores-v0.3 (casos aleatorios)`;
   el apartado `run.jl` es evidencia de T04-D.

## Secuencia de trabajo

1. **Lectura y montaje.** Lectura íntegra de `ORDEN-W06a-B.md`, `LINEO.md`, `REVISION-W06a.md`,
   `REVISION-T01-E.md`, `REVISION-T04-D.md`, los dos arneses y el generador de T04. Copia a
   `ws.orig/`/`ws/`, `env.sh`, caché de Cargo reutilizada de W06a dentro de la zona.
2. **V0.** `cargo test --workspace --all-features --locked` sin cambios: **680 pasan, 0 fallan,
   2 ignorados**, exit 0 (`logs/V0-test.log`). Es la primera corrida completa con W05b3 + W06a.
3. **Testdata.** Copia sin editar a `testdata/transicion-v0.2/` y `testdata/estado-dag-v0.3/` con
   `PROCEDENCIA.md`; `sha256` verificados contra la entrada congelada.
4. **Arnés T01.** Sin `prox_salida`: la liberación se indexa por `(clave, nonce, importe)` y la
   entrada con id `≥ 2⁶²` se decodifica y resuelve al `OutPoint` real `(txid, 0)`; se lee v0.2.
5. **Arnés T04.** Se eliminan `detectar_colisiones`, `forzada`, `ContextoTx`, `Colisiones` y el punto
   fijo; `construir_reales` en una pasada; cobertura `vectores-v0.3`; se lee v0.3.
6. **Verificación.** V1–V6 y entregables.

## Hallazgo (declarado en `INFORME.md` §4)

Al quitar el punto fijo, el diferencial de T04 acusó **4 discrepancias en 2 de los 914 casos**
(304 y 567). Diagnóstico con instrumentación temporal: dos transferencias abstractas con los mismos
prevouts y las mismas salidas en valor/dueño pero distinto id de salida (`1003`/`1004`) producen la
misma transacción real y el mismo `OutPoint`, mientras el oráculo las distingue. El punto fijo de
W06a lo enmascaraba. **Corrección mínima:** en el arnés de T04, `sequence` de las entradas de una
transferencia se fija al id abstracto de su primera salida (campo del `txid`/`sighash` que el motor
**no** interpreta); con ello el `txid` real es inyectivo en el contenido abstracto, sin contador, sin
entradas inventadas y sin punto fijo. Tras la corrección: **914/914 casos, 0 discrepancias** y
cobertura idéntica. T01 no lo necesita (estados por rama, sin fusión de ramas hermanas).

## Resultado

- **V1** `cargo fmt --all -- --check`: exit 0 (`logs/V1-fmt.log`).
- **V2** `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: exit 0,
  0 avisos (`logs/V2-clippy.log`).
- **V3** `cargo test --workspace --all-features --locked`: **680 pasan, 0 fallan, 2 ignorados**
  (`logs/V3-test.log`); `diferencial_t01`, `diferencial_t01_negativos` y `diferencial_t04` verdes.
- **V4** `diferencial_t01` v0.2: 2 055 base + 3 914 negativos, 0 discrepancias
  (`logs/V4-diferencial-t01.log`). `diferencial_t04` v0.3: 914 casos, 0 discrepancias
  (`logs/V4-diferencial-t04.log`). `grep forzad|colision|prox_salida`: vacío (`logs/V4-grep.log`).
- **V5** cobertura idéntica a `cobertura-v0.3.txt` (`logs/V5-cobertura.log`).
- **V6** 22 dependencias exactas, 8 fronteras OK, `Cargo.lock` idéntico
  (`logs/V6-guardianes.log`, `logs/lock-subconjunto.txt`).
- **Entrada** 9/9 al inicio y al final (`logs/entrada-*.log`).
- **Entregables**: `cambios.patch` (10 ficheros), `MIGRACION.sha256` (190 huellas, `sha256sum -c`
  OK), `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`.

**Veredicto: SUPERADO** (con el hallazgo declarado). La pregunta falsable no queda refutada.
