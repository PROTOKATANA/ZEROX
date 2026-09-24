# Corrección a DeepSeek · C1: pruebas de frontera sin leer el código fuente

DeepSeek V4.1 Flash, esfuerzo `high`, mediante DeepSeek Harness. Continúa sobre el diff de [ORDEN-C1-LECTURA-INDICE-ADMITIDOS.md](ORDEN-C1-LECTURA-INDICE-ADMITIDOS.md). No hagas commit ni push. Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, la orden, `almacen_admitidos_dag.rs`, sus backends y `dag_causal.rs` antes de editar.

## Correcciones

1. Elimina `el_trait_de_admitidos_solo_declara_lectura` y `las_inyecciones_de_fixture_estan_tras_cfg_test` de `almacen_admitidos_dag.rs`: buscan texto con `include_str!`, repiten la implementación y se rompen por formato. La ausencia de escritor público se comprueba mejor por el compilador. Si añades un doctest `compile_fail`, haz que sea una llamada completa al nombre del método sin errores independientes que lo hagan fallar por otra razón; o deja la frontera como propiedad revisada del API sin test artificial. No es obligatorio sustituir esos dos tests.
2. Revisa los comentarios y nombres de tests `la_entrada_admitida_no_se_reemplaza...`: hoy solo demuestran que el **helper `#[cfg(test)]`** rechaza un duplicado. No demuestran la futura escritura de admisión ni atomicidad con estado, undo y GHOSTDAG. Di exactamente eso; si no aportan más que repetir `contains_key`, retíralos. Mantén los tests de aislamiento candidato/índice, corrupción de bytes/clave/versión y reapertura, que sí ejercen riesgos reales de lectura.
3. Revisa documentación que llame a las entradas "plenamente admitidas" sin matizar que el índice está vacío en la ruta activa y solo los tests lo llenan con bytes no verificados. Conserva el nombre del índice como destino y la API de lectura; evita afirmar que el propio almacenamiento certifica validez o asegura un snapshot estable con escritor futuro.
4. Corrige cualquier defecto concreto que encuentre la revisión Rust sin ampliar alcance. No edites `TAREAS.md`, P-ECLIPSE/P-RELOJ, CI, SPEC, ni código fuera de los seis archivos permitidos en la orden original.

## Gates

`cargo test -p zx-storage --locked`, `cargo test -p zx-storage --features rocksdb --locked` dirigidos, `cargo test -p zx-node --locked --lib dag_causal`, Clippy, formato y guardianes CI. Reporta límites. C1 sigue abierta.
