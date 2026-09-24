# Corrección C3 · quitar prueba tautológica del testigo

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`. No commit ni push.

Archivos declarados: `crates/zx-consensus/src/genesis_dag.rs` y `crates/zx-consensus/tests/genesis_dag.rs`. Lee el diff actual y conserva la preparación C3. No editar otros archivos.

La revisión independiente detectó que `el_testigo_conserva_el_hash` construye `EstructuraYHashGenesisDagDev { hash_comprobado: h }` directamente y luego compara `hash_comprobado()` con `h`: es una prueba tautológica, escrita solo para que `ci/alcance-consenso.sh` vea el getter público. Eso contradice el criterio de pruebas del encargo.

Elimina ese test y el getter público `hash_comprobado()`. Haz que `EstructuraYHashGenesisDagDev` siga siendo un testigo opaco con campo privado sin información adicional necesaria (por ejemplo `_privado: ()`), fabricado **solo** al terminar `comprobar_estructura_y_hash_dag_dev`. En `tests/genesis_dag.rs`, la prueba de éxito debe seguir comprobando el hash del candidato contra el literal fijo y que el comprobador devuelve `Ok(_)`; no construir ni leer el testigo directamente. Conserva la prueba interna `el_timestamp_marcador_se_rechaza`, que comprueba un rechazo real y mantiene los dos puntos de entrada públicos alcanzados para el guardián; no añadas llamadas falsas para darle verde.

Precisa en doc que la API compara contra `hash_esperado` proporcionado por el llamante; que esté congelado por una configuración de red no lo garantiza el tipo y sigue pendiente de integración al arranque C-GEN-07. No cambies la clasificación estructural, el hash de fixture ni los parámetros de prueba.

Ejecuta `cargo fmt --all -- --check`, `cargo test -p zx-consensus --locked`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Informa límites reales; C3 sigue pendiente.
