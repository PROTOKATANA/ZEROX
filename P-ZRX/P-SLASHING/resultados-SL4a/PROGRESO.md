# PROGRESO — ORDEN-SL4a

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `/home/katana/zeo/ZEROX/deepseek/SL4a/`.
**Entrada:** `P-ZRX/P-SLASHING/ENTRADA-SL4a.sha256`. **Regla:** LINEO rige el código Rust.

## Resumen

La orden se ejecuta **sin tocar `crates/zx-node/`**. Como los nuevos parámetros de evidencia no pueden
entrar en `ParametrosTransicion` sin romper el perfil dev de `zx-node` (fuera de alcance), viven en
un `ParametrosEvidencia` propio (ver FD-8 abajo). El motor, `zx-core` y `zx-cadena` los reciben por
parámetro; `zx-node` sigue con la evidencia inactiva hasta SL-4b.

## Decisiones y hallazgos

- **FD-1 (informado en `DEFINICIONES-FALTANTES.md`):** `incident_id` del contrato (`H_d` SHA3-256)
  ≠ oráculo (SHA-256 decimal). El motor implementa el contrato; el arnés compara el id como **opaco**
  (multiconjunto de `@slot_falta`). No afecta a ningún contador de cobertura.
- **FD-2:** se adopta `ErrCbidAjeno` (oráculo) en vez del `ErrForma` literal de RAT-1.
- **FD-3:** `Plazo_slots`/`M_margen_slots` siguen sin calibrar; el perfil de pruebas fija valores que
  cumplen la puerta RAT-3.
- **FD-4:** `validar_forma_tx_v4` es la forma de la v4; el motor la elige cuando `evp` está activo.
- **FD-5:** el wire de la v4 (`H1 ‖ H2`) es una extensión declarada; `tx_desde_bytes` sigue sin
  aceptar la v4.
- **FD-6/7:** `cobertura-v0.4.txt` y los negativos v0.2 se usan tal cual están.
- **FD-8 (nuevo, no previsto en el contrato):** añadir los parámetros a `ParametrosTransicion`
  obligaría a editar `crates/zx-node/src/perfil.rs` y `crates/zx-node/tests/padres_maximos.rs`,
  prohibido por la orden. Se crea `ParametrosEvidencia` (mismo módulo `transicion`) y se pasa por
  parámetro; `Cadena::nueva` conserva su firma y añade `Cadena::nueva_con_evidencia`.
- **Traducción de evidencia v4:** los vectores se traducen a **dos cabeceras `PoAS_PoT_DAG` reales**
  con sellos Ed25519 reales. El orden canónico real por `pre_hash` se obtiene buscando una sal en
  `H2` hasta que la comparación real coincide con la abstracta. Sin emulación.
- **Slots negativos (T04):** el oráculo admite `slot_falta < 0` en su generador de evidencia tardía;
  la cabecera real los lleva en dos's complemento y el motor los reinterpreta como `i64` en la
  ventana y en el incidente. T01 no usa slots negativos.
- **Poda EV-11 en modo fusión:** se ejecuta con el **punto de aplicación**, no con el slot propio del
  bloque fusionado (lo confirmó la corrección del caso T04 972): era el único fallo real de reglas
  que el diferencial T04 encontró y que quedó corregido antes del cierre.
- **`deshecha` (cobertura T04):** el oráculo recalcula el conjunto de evidencias aplicadas **tras
  cada bloque** y solo compara al cambiar la punta; el arnés hace lo mismo.

## V1–V6

| Paso | Resultado |
|---|---|
| V1 `fmt --check` | **OK** (`cargo fmt --all -- --check` sin diferencias) |
| V2 `clippy -D warnings` | **OK** tras `#[expect(clippy::large_enum_variant)]` justificado en `ExtensionTx` |
| V3 `cargo test --workspace --all-features --locked` | **OK**: 729 pasan, 0 fallan, 2 ignorados (721/0/2 antes; +8 tests nuevos de V5, 0 perdidos). `logs/test-workspace-final.log` |
| V4a `diferencial_t01` (v0.4) | **0 discrepancias**; cobertura **idéntica** a `cobertura-v0.4.txt` (2 795 casos) |
| V4b `diferencial_t04` (v0.5) | **0 discrepancias**; sección `vectores-v0.5` y `EV` **idénticas** a `cobertura-v0.5.txt` (1 878 casos) |
| V5 tests propios | `zx-consensus/tests/evidencia.rs`: 8/8 (RAT-3/ventana, autodenuncia, `cbid` ajeno, orden canónico, sellos, duplicada en hermanos, undo/reaparición, con salidas) |
| V6 `dependencias-exactas.sh`, `frontera-crates.sh` | **OK** — 23 dependencias exactas; 9/9 fronteras; `Cargo.lock` idéntico a la raíz y sin cambios de versión |

## Logs

- `logs/t01-run2.log`: T01 v0.4 (0 discrepancias, cobertura idéntica).
- `logs/t04-run5.log`: T04 v0.5 (0 discrepancias, cobertura idéntica).
- `logs/evidencia2.log`: tests propios V5 (8/8).
- `logs/check*.log`, `logs/clippy*.log`: compilación y clippy.
