# INFORME.md — ORDEN-W06a-B

**Diferenciales sin emulación de ids contra los oráculos T01-E y T04-D.** Sesión: DeepSeek Harness,
modelo `deepseek-flash`, esfuerzo `high`. Fecha: 2026-09-26, 05:30–06:15 +02:00. Zona única:
`/home/katana/zeo/ZEROX/deepseek/W06aB/`. Sin Python, sin dependencias Rust nuevas, sin `unsafe`, sin
commit ni push, nada escrito fuera de la zona. Base: workspace de la raíz copiado a `ws.orig/` y
`ws/`.

**Pregunta falsable:** «Sin emulación, el motor y `zx-cadena` coinciden con T01 (v0.2, base y
negativos) y con T04 (v0.3) en todos los casos, y la cobertura del arnés es idéntica a
`cobertura-v0.3.txt`.»
**Veredicto: NO REFUTADA — SUPERADO**, con **un hallazgo declarado** (§4): el `OutPoint` real
`(txid, índice)` no es inyectivo sobre los ids explícitos del oráculo.

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §5) | Veredicto |
|---|---|---|
| V0 | `cargo test --workspace --all-features --locked` sin cambios | **OK** (exit 0; **680 pasan, 0 fallan, 2 ignorados**; primera corrida conjunta W05b3+W06a; `logs/V0-test.log`) |
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; `logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0, 0 avisos; `logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; **680 pasan, 0 fallan, 2 ignorados**; `diferencial_t01`, `diferencial_t01_negativos` y `diferencial_t04` verdes; `logs/V3-test.log`) |
| V4 | `diferencial_t01` (v0.2 base 2 055 + negativos 3 914) y `diferencial_t04` (v0.3, 914) | **OK** (0 discrepancias; `grep forzad\|colision\|prox_salida` en los arneses: **vacío**; `logs/V4-diferencial-t01.log`, `logs/V4-diferencial-t04.log`, `logs/V4-grep.log`) |
| V5 | Cobertura del arnés vs sección `vectores-v0.3` de `cobertura-v0.3.txt` | **OK** (idéntica, 13 líneas; `logs/V5-cobertura.log`) |
| V6 | `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`; lock | **OK** (22 dependencias exactas; 8 fronteras; `Cargo.lock` **byte a byte idéntico**; `logs/V6-guardianes.log`, `logs/lock-subconjunto.txt`) |
| Entrada | `sha256sum -c P-ZRX/P-NODO/ENTRADA-W06a-B.sha256` al inicio y al final | **OK** en ambos (9/9; `logs/entrada-inicio.log`, `logs/entrada-final.log`) |

V0 es la **primera ejecución completa de la raíz con W05b3 y W06a juntas** que pedía
`REVISION-W06a.md` («Migración»): 680 pasan, 0 fallan. V3 repite el conjunto ya con los vectores
v0.2/v0.3 y da el mismo total; ningún nombre de test previo desaparece.

## 2. Qué se hizo

1. **Copia de la raíz** a `ws.orig/` y `ws/` (workspace: `Cargo.toml`, `Cargo.lock`,
   `rust-toolchain.toml`, `crates/`, `ci/`, `testdata/`, `.github/`; `PDF` por enlace, excluido de
   `cambios.patch`/`MIGRACION.sha256`). `env.sh` fija `CARGO_HOME`, `CARGO_TARGET_DIR`,
   `CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8` y `GIT_CEILING_DIRECTORIES` en la zona.
2. **`testdata/`**: se añaden `transicion-v0.2/` (base + negativos + `sha256` + `PROCEDENCIA.md`) y
   `estado-dag-v0.3/` (vectores + `cobertura-v0.3.txt` + `sha256` + `PROCEDENCIA.md`), copiados
   **sin editar**; sus `sha256` coinciden con `ENTRADA-W06a-B.sha256`. Los v0.1 y v0.2 se conservan.
3. **`diferencial_t01.rs`**: lee v0.2; se elimina el campo `prox_salida` y su espejo. La salida de
   una `Liberacion` se registra por `(clave, nonce, importe)` y una entrada con id `≥ 2⁶²` se
   **decodifica** (`decodificar_id_lib`, bits 40/20/20) y se resuelve al `OutPoint` real `(txid, 0)`.
4. **`diferencial_t04.rs`**: lee v0.3; se eliminan `detectar_colisiones`, `forzada`, `ContextoTx`,
   el tipo `Colisiones` y el bucle de punto fijo. `construir_reales` se llama una sola vez y
   `construir_y_resolver` aplica la historia en una pasada. La cobertura pasa a comparar
   `vectores-v0.3`.
5. **Correspondencias**: las vigentes de W03/W02b/W06a; **ninguna nueva**.

## 3. Cobertura (V5)

Tabla del arnés idéntica a `cobertura-v0.3.txt` (`vectores-v0.3`): Transferencia 1 112 construidas /
364 aplicadas / 204 `ErrDobleGasto`; Depósito 1 626 / 347 / `ErrNonce` 295 + `ErrDobleGasto` 101;
Retiro 2 579 / 808 / 474 / 11 `ErrSaldo` / 25 `ErrRetiroPendiente`; Liberación 458 / 115 / 84 / 20;
`garantia_errnonce` 853 (18,29 % / 37,41 %); `err_doble_gasto_total` 305; reorganizaciones 312.

## 4. Hallazgo: `(txid, índice)` no es inyectivo sobre los ids explícitos

La orden parte de que F-18 elimina la emulación. Elimina, en efecto, la colisión
**liberación↔transferencia** (`prox_salida`), pero queda una no inyectividad del **formato real**:
dos **transferencias abstractas** con los mismos prevouts y las mismas salidas en valor/dueño, pero
distinto `id` de salida (p. ej. `1003` y `1004`), producen **la misma transacción real** y por tanto
el mismo `OutPoint = (txid, 0)`, mientras el oráculo T04 las distingue por id. Sin el punto fijo, en
v0.3 **2 de 914 casos** (304 y 567) divergían: el arnés resolvía `1004` (creado por una transferencia
descartada) al `OutPoint` de su gemela aplicada `1003` y aplicaba una transacción que el oráculo
descarta; 4 discrepancias de `DESC`/`UTXO`/`GAR`. El punto fijo de W06a lo enmascaraba.

**Corrección mínima aplicada (T04):** fijar `sequence` de las entradas de una transferencia al id
abstracto de su primera salida. `sequence` forma parte del `txid` y del `sighash` (el arnés vuelve a
firmar) pero el motor **no lo interpreta**, así que el `txid` real pasa a ser inyectivo en el
contenido abstracto sin cambiar semántica de consenso ni añadir entradas. No es un contador ni un
punto fijo. T01 no lo necesita: sus estados se construyen por rama (`aplicar_con_undo` desde el
padre), sin fusión de ramas hermanas en un mismo estado. **Hallazgo para el director:** los ids
explícitos del oráculo no se derivan del contenido (a diferencia de `ID_LIB`); si se reexportara con
un id explícito inyectivo por contenido, el arnés no necesitaría la desambiguación.

## 5. Lo que esta orden NO demuestra

- **No re-verifica** los oráculos T01-E/T04-D: consume sus vectores como especificación; no regenera.
- **No prueba idoneidad** de GHOSTDAG ni del SPEC: solo la coincidencia del motor con el oráculo.
- **No cubre cabeceras, red ni persistencia**: siguen siendo W06b/W06c/W06d.
- **La desambiguación por `sequence`** es un artefacto del arnés para un defecto del formato/`out_id`;
  no es una regla de consenso y no toca `zx-core`/`zx-consensus`.
- **V5** solo alcanza la sección `vectores-v0.3`; el apartado `run.jl` de `cobertura-v0.3.txt` es
  evidencia de T04-D y no es exigible al arnés.

## 6. Presupuesto y trazas

Presupuesto: **1 h 30 min de reloj, 8 hilos, 16 GiB de RAM**, disco amplio. Consumo real ≈ 45 min de
reloj. Toolchain `nightly-2026-05-03` (`cargo/rustc 1.97.0-nightly`), 8 jobs,
`RUST_TEST_THREADS=8`, `RUSTFLAGS=`. Artefactos: `ws/`, `ws.orig/`, `cambios.patch`
(22 693 653 bytes, **10 ficheros**: 2 modificados + 8 nuevos), `MIGRACION.sha256` (**190 huellas**,
`sha256sum -c` OK), `logs/` (V0–V6, entrada, migración, lock), `INFORME.md`, `PROGRESO.md`,
`HORAS.log`. `Cargo.lock`: **sin cambios** (`diff` vacío, `cmp` igual).

## 7. Resumen final (≤ 40 líneas)

1. V0: primera corrida completa de W05b3+W06a, **680 pasan / 0 fallan / 2 ignorados**.
2. V1 `fmt --check` y V2 `clippy -D warnings` limpios.
3. V3: misma cifra; los tres tests diferenciales presentes y verdes.
4. V4: `diferencial_t01` v0.2 (2 055 + 3 914) **0 discrepancias**.
5. V4: `diferencial_t04` v0.3 (914) **0 discrepancias**.
6. V4: `grep forzad|colision|prox_salida` en los arneses **vacío**.
7. V5: cobertura del arnés **idéntica** a `cobertura-v0.3.txt`.
8. V6: 22 dependencias exactas y 8 fronteras OK; lock byte a byte idéntico.
9. Entrada congelada **9/9** al inicio y al final.
10. `diferencial_t01`: `prox_salida` eliminado; `ID_LIB(clave,nonce,importe)` decodificado a `(txid,0)`.
11. `diferencial_t04`: `detectar_colisiones`, `forzada` y el punto fijo eliminados.
12. `construir_reales` de T04 en una sola pasada; sin entradas inventadas.
13. Testdata v0.2 y v0.3 migrados sin editar, con `PROCEDENCIA.md`.
14. Sin correspondencias de error nuevas.
15. Hallazgo: `(txid, índice)` no inyectivo sobre ids explícitos; 2/914 casos; corregido con
    `sequence` = id de la primera salida (campo no interpretado por el motor).
16. Límites: sin cabeceras, red, persistencia ni idoneidad del SPEC.
17. Veredicto: **SUPERADO**; la pregunta falsable no queda refutada.
