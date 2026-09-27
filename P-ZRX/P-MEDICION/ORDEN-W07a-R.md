# ORDEN-W07a-R — Rebase de la instrumentación (W07a) sobre la raíz con W06d7, eventos restaurados y suite completa

**LINEO (`V-ZRX/LINEO.md`) rige este código Rust**; léelo íntegro antes de escribir código.

- **ID:** W07a-R. **Fecha:** 2026-09-27 (redactada ≈ 06:47; se congela y lanza tras migrar W06d7).
  **Director:** Claude. **Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W07a-R/`. **Base:** la raíz en el commit de
  `ENTRADA-W07a-R.sha256` (con W06d7). Puedes **leer** `deepseek/W07a/` (su `cambios.patch`, `ws/`, informe y
  guion `v3.sh`); ninguna otra zona.
- **Motivo:** `P-ZRX/P-MEDICION/REVISION-W07a.md`: la instrumentación se hizo sobre una base anterior a W06d7
  (que reestructura `zx-cadena` en varios DAG y cambia `nodo.rs`), retiró seis eventos sin que se pidiera y no
  ejecutó la suite completa tras su última corrección.

## Qué hacer

1. Llevar a la base nueva **el mismo comportamiento** de W07a: eventos y campos de
   `ESQUEMA-REGISTRO-v1.md` §1 (salvo los de SL-4b2), accesos de lectura de `zx-cadena` (reimplementados sobre la
   estructura nueva si hace falta: **del terminal seleccionado**; un test compara cada uno con lo que ya calcula el
   código), `Arc<Registro>` compartido con la red, y la corrección de `reinicio.rs`. Si el parche no aplica, se
   adapta a mano **sin** cambiar reglas ni orden de la tubería (lo de W06d7 manda).
2. **Restaurar** los seis eventos retirados, con sus campos originales (esquema §1 bis): `dejar_de_producir`
   (crítico), `bloque_red_pendiente`, `bloque_red_ignorado_sin_penalizar`,
   `bloque_post_gossip_descartado_sincronizando`, `bloque_propio_rechazado_legitimo`,
   `bloque_post_de_red_sin_terminal`.
3. Verificación: **suite completa** `cargo test --workspace --all-features --locked` (todo lo previo con su
   nombre), diferenciales T01 v0.5 y T04 v0.6 con 0 discrepancias, `registro_esquema`, `fmt --check`,
   `clippy -D warnings`, guardianes; y un V3 corto con tres nodos reales (≥ 60 bloques PoST, con
   `--dejar-de-producir-en-slot` para que aparezca `dejar_de_producir`) cuyos registros tengan todos los tipos del
   §1 que esa ejecución puede producir.
4. `cambios.patch` (`diff -ruN ws.orig ws`; **no modifiques `ws.orig/`**) y `MIGRACION.sha256` como último paso.

**Tabla de cobertura** por tipo de evento (mínimo 1 por tipo, en test o en V3). **Prohibido Python** (también
para editar texto). Presupuesto: **2 h, 8 hilos**, `nice -n 10`. `INFORME.md`, `PROGRESO.md`, `HORAS.log`
(`date -Is` real), nombre de modelo de la API. Nada fuera de la zona; sin git; sin secretos; ningún `Ok`
ficticio; si una prueba falla, se informa. Si detectas una falta de definición, infórmala **antes de editar**.
