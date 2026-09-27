# ORDEN-SL4c-R — Rebase de SL-4c sobre la raíz actual y adaptación del test de SL-4b1

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust**; léelo íntegro antes de escribir código.

- **ID:** SL-4c-R. **Fecha:** 2026-09-27 (≈ 02:09). **Director:** Claude. **Ejecutor:** DeepSeek
  (`deepseek-flash`, esfuerzo `high`). **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/SL4c-R/`.
- **Motivo:** SL-4c (revisada por el director: `P-ZRX/P-SLASHING/resultados-SL4c/`) se hizo sobre una raíz
  anterior a la migración de W06d5 (`zx-node`) y de SL-4b1 (`zx-post`). Su parche toca otros crates, pero el
  test de SL-4b1 `crates/zx-post/tests/firmante_identidad_evidencia.rs` usa la firma antigua de
  `validar_forma_tx_v4` (dos argumentos), espera `ErrorTransicion::ErrCbidAjeno` (desaparece) y su test
  `v5d_la_forma_v4_no_mira_la_identidad` afirma que la forma no mira el `cbid` (ahora sí, RAT-1). Además, el
  parche de SL-4c no incluye los directorios nuevos de `testdata/`.
- **Base:** la raíz en el commit de `ENTRADA-SL4c-R.sha256` (con W06d5 y SL-4b1 migradas). **No** leas otras
  zonas de `deepseek/` salvo `deepseek/SL4c/` (solo lectura: su `cambios.patch`, `MIGRACION.sha256` y
  `ws/testdata/{transicion-v0.5,estado-dag-v0.6}/`).

## Qué hacer

1. Copia de la raíz a `ws.orig/` y `ws/` (patrón de las órdenes W). Aplica `deepseek/SL4c/cambios.patch` a
   `ws/` (debe aplicar limpio: si no, **para** e informa) y copia byte a byte los dos directorios de
   `testdata/`; comprueba que los vectores son idénticos a
   `P-ZRX/P-TRANSICION/T01/resultados/vectores-transicion-v0.5.txt` y
   `P-ZRX/P-DAG/T04/resultados/vectores-estado-dag-v0.6.txt`.
2. Adapta **solo** `crates/zx-post/tests/firmante_identidad_evidencia.rs`: las llamadas a
   `validar_forma_tx_v4` con el `cbid` de la red de sus cabeceras; la expectativa del `cbid` ajeno pasa a
   `ErrorTransicion::ErrForma(ErrorFormaTx::EvidenciaCbidAjeno)` (o el error de forma que devuelva el motor
   para ese caso, el que sea, **leído** del código de SL-4c y citado); `v5d` se reescribe para afirmar lo
   contrario de lo que afirmaba: la forma v4 **rechaza** un `cbid` ajeno y **acepta** cambios de los otros
   campos de la identidad (que siguen siendo semánticos). Los comentarios del archivo se corrigen a juego.
   Ningún otro archivo cambia respecto de «SL-4c aplicada».
3. Verificación: `fmt --check`, `clippy --workspace --all-targets --all-features --locked -- -D warnings`,
   `cargo test --workspace --all-features --locked` (primera suite conjunta de W06d5 + SL-4b1 + SL-4c: todo lo
   previo con su nombre), `diferencial_t01` y `diferencial_t04` con **0 discrepancias**,
   `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`.
4. `cambios.patch` (`diff -ruN ws.orig ws`, **incluyendo** `testdata/`) y `MIGRACION.sha256` como último paso,
   con `sha256sum -c` en verde.

**Prohibido Python.** Presupuesto: 1 h 30 min, **4 hilos, `nice -n 19`** (otra orden con procesos reales usa la
máquina). `INFORME.md`, `PROGRESO.md`, `HORAS.log` (`date -Is` real), nombre de modelo de la API. Nada fuera
de la zona; sin git; sin secretos; ningún `Ok` ficticio; si una prueba falla, se informa. Si detectas una
falta de definición, infórmala **antes de editar**.
