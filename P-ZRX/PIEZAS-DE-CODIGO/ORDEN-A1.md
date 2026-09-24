# Orden A1 para DeepSeek · verificador PoAS

**Modelo/ejecución:** DeepSeek Harness `dsh`, modelo de catálogo `deepseek-flash` = DeepSeek-V41-Flash, esfuerzo `high`. Trabaja en `/home/katana/zeo/ZEROX` y lee `AGENTS.md`, `README.md`, `MIGRACION.md` y las reglas citadas de `SPEC.md` antes de editar. Eres ejecutor de esta pieza; si un dato normativo falta, informa el bloqueo y deja error explícito. No elijas arquitectura ni valores de consenso.

**Objetivo aislado:** adaptar la API pública fijada `subspace_verification::verify_solution::<ChiaTable, _>` del clon `PDF/autonomys-subspace` @ `f8842d0` para comprobar `SolucionPoas` de ZEROX: PoS, distancia/rango, chunk KZG y testigo del compromiso de registro contra el segmento de historia. La regla aplicable es `C-POT-08` paso 5 y `C-FLU-13` punto 1; `C-HDR-01` define los campos wire. **A1 no autoriza declarar válido un bloque completo** ni saltar A2/A3.

**Archivos permitidos:** `Cargo.toml`, `Cargo.lock`, `crates/zx-consensus/Cargo.toml`, `crates/zx-consensus/src/lib.rs`, nuevo `crates/zx-consensus/src/poas.rs`, nuevo `crates/zx-consensus/tests/poas.rs`. Antes de tocar otro archivo, explica por qué y detente. No edites `zx-core`, nodo, `SPEC.md`, `research/`, `veritas/`, `PDF/`, otros `P-ZRX/`, `.git` ni el código fuente del clon. No hagas commits ni push: el líder inspecciona y hace el commit tras el cierre. **Ya se ha informado al líder de que `ci/alcance-consenso.sh` necesitará registrar la función pública fuera de esta lista; eso no impide avanzar en los archivos permitidos. Entrega el diff y el fallo real del guardián, sin tocar `ci/`.**

**API que debes entregar:**

```rust
pub fn verificar_solucion_poas(
    solucion: &zx_core::SolucionPoas,
    slot: u64,
    salida_pot_verificada: [u8; 16],
    rango_validado: u64,
    contexto_pieza: &subspace_verification::PieceCheckParams,
    kzg: &subspace_kzg::Kzg,
) -> Result<u64, ErrorPoas>;
```

El `slot`, PoT, rango y `contexto_pieza` son argumentos **del pasado/contexto ya validado**, nunca valores elegidos a partir de la solución candidata. **La salida PoT es la verificada para el slot auditado; `pot_output` de cabecera corresponde al slot futuro `slot + D` (C-POT-05) y no sirve directamente.** No aceptes `Option<PieceCheckParams>` en esta API. La conversión debe construir `VerifySolutionParams { proof_of_time, solution_range: rango_validado, piece_check_params: Some(contexto_pieza.clone()) }`, nunca `None`. El wrapper puede ofrecer un tipo propio que haga imposible mezclar contexto no validado, pero no cambies esta firma pública sin informar. `ErrorPoas` debe distinguir al menos conversión no canónica/inválida de entrada y error upstream de prueba; falta de contexto solo si surge en esta firma. Conserva el error concreto upstream como fuente (`#[source]` o equivalente), sin transformarlo en `Ok` ni en un booleano. `history_size=0` es error, sin panic; usa enteros comprobados. **Valida las precondiciones aritméticas de `PieceCheckParams` antes de pasarla al upstream:** allí `current_history_size + 1` y los productos/resta de `SectorId::derive_piece_index` usan aritmética ordinaria. Un contexto extremo o inconsistente debe dar error explícito, no panic ni wrap; no inventes topes de consenso. **En el código cita `C-POT-08` paso 5; no declares implementada `C-FLU-13`, porque su validación absoluta y derivación de flujo siguen pendientes.**

**Fuentes exactas:** `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs` (API y contrato), `.../subspace-core-primitives/src/solutions.rs` (`Solution<()>`), `.../subspace-proof-of-space/src/chia.rs` (`ChiaTable`), `.../shared/subspace-kzg/src/lib.rs` (`Kzg`), `crates/zx-core/src/preimage/dag.rs` (`SolucionPoas`). `veritas/rendimiento/coste-salto-v1/src/main.rs` muestra un fixture PoAS positivo con `piece_check_params: Some` y distancia externa conocida; léelo **solo como evidencia/fixture**, sin modificarlo ni ejecutarlo. Verifica los tipos/conversiones reales antes de escribir. Enlaza las dependencias por `path` al clon fijado; no copies ni reimplementes KZG, PoS, máscara del chunk o distancia. No actives feature `testing` de upstream.

**Tests Rust junto al crate:** caso positivo generado por API pública upstream, con distancia esperada independiente del wrapper; mutaciones separadas de `proof_of_space`, `chunk_witness`, `record_witness`, `record_commitment`, rango por debajo de la distancia, `history_size=0`, y salida PoT/slot equivocados. Un test que solo compara wrapper con otra llamada idéntica a `verify_solution` es insuficiente: usa el fixture positivo fijado y mutaciones que deben fallar. La generación costosa del fixture debe ocurrir una vez y no usar la ruta no paralela de ploteo que tiene SIGSEGV registrado. Si producir ese fixture dentro de estos archivos resulta inviable, informa el impedimento; no lo sustituyas por tests tautológicos o siempre inválidos.

**Verificación a entregar:** `cargo fmt --all -- --check`; `cargo check --workspace --locked`; `cargo test -p zx-consensus --test poas --locked`; `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`; `ci/citas-spec.sh`, `ci/alcance-consenso.sh` y `git diff --check`. Indica cada comando y resultado real. Comprueba `git status --short` antes/después; informa todo fichero fuera de la lista, incluso cambios indirectos del lock. Si una dependencia de Autonomys no resuelve, no la sustituyas por una implementación propia: reporta el error concreto.
