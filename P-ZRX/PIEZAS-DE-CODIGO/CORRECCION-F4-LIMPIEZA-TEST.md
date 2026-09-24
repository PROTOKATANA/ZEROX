# Corrección F4 · limpieza garantizada del subprocess en pruebas

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`.

La prueba TCP del líder pasó: tres procesos `zx-dag-dev` en loopback completaron cuatro saludos A–B y A–C con el hash dev congelado, y los tres salieron con código 0 tras `SIGINT`. La revisión del test nuevo detectó un defecto de limpieza: `el_aviso_de_modo_red_es_veraz_y_se_apaga_acotado` hace `assert!` sobre el aviso y la escucha **antes** de llamar `interrumpir()`. Si cualquiera falla, el `Child` se suelta sin matar/esperar al subprocess y queda huérfano. La orden F4 exige expresamente subprocess acotado sin procesos huérfanos.

Modifica **solo** `crates/zx-node/tests/saludo_dag_dev.rs`. Añade limpieza RAII robusta a `BinarioVivo`: en `Drop`, si el hijo continúa vivo, `kill` y `wait`; recoge o deja terminar el hilo lector sin bloqueo indefinido. Asegura que `esperar_fin` y `Drop` no intenten esperar dos veces ni propaguen un panic desde `Drop`. El camino normal debe seguir probando apagado cooperativo por `SIGINT` y `ExitStatus::success()`. No agregues una dependencia ni cambies el binario, el coordinador, otros crates o documentos. No commit ni push.

Repite `cargo test -p zx-node --locked --test saludo_dag_dev`, Clippy `--all-targets -D warnings`, formato y `git diff --check`. Informa el camino exacto de limpieza incluso si falla una aserción.
