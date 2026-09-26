# ORDEN-W06b-R — Rebase de W06b (con la Corrección A) sobre la raíz actual

- **ID:** W06b-R. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06bR/`.
- **Motivo:** W06b + Corrección A (`deepseek/W06b/`, revisadas) partieron de la raíz de las 04:11;
  después se migraron W05b3 (`zx-post`) y W06a (`zx-cadena`, `fusion.rs`, `Cargo.toml`, `Cargo.lock`,
  `ci/frontera-crates.sh`). `git apply --check -p1` de su `cambios.patch` falla en `Cargo.toml` y
  `ci/frontera-crates.sh`, y aplica excluyendo esos dos y `Cargo.lock` (comprobado por el director).

## Qué hacer

1. Copia la raíz actual a `ws.orig/` y `ws/` (enlace `ws/PDF` al clon, excluido de la migración).
2. Aplica en `ws/` `deepseek/W06b/cambios.patch` con
   `git apply -p1 --exclude=Cargo.toml --exclude=Cargo.lock --exclude=ci/frontera-crates.sh`.
3. Rehaz a mano, con el **mínimo** cambio: `crates/zx-storage` en los miembros; la dependencia
   `rocksdb = "=0.25.0"` y lo que W06b añadió a `[workspace.dependencies]`; la regla
   `zx-storage → {zx-core}` en `frontera-crates.sh` **conservando** las actuales (incluida la de
   `zx-cadena`). Un único `cargo metadata --format-version 1 >/dev/null` actualiza el lock (sin
   `cargo update`); demuestra en `logs/lock-diff.txt` que solo añade los paquetes que añadía W06b, a las
   mismas versiones, sin cambiar ninguna existente.
4. Con `--locked`: `fmt --check`, `clippy -D warnings` (con y sin `--features rocksdb`),
   `cargo test --workspace --all-features`, `dependencias-exactas.sh`, `frontera-crates.sh`. Criterio:
   todos los tests de la raíz actual con su nombre más los 20 de W06b.
5. Entrega `cambios.patch` (`diff -ruN ws.orig ws`), `MIGRACION.sha256`, `logs/`, `INFORME.md` breve,
   `HORAS.log`.

Si algo más no aplica o falla, **para** e infórmalo con la salida literal. `CARGO_HOME`/`CARGO_TARGET_DIR`
en la zona (caché copiable de `deepseek/W06b/`), 8 hilos. DeepSeek `deepseek-flash`, esfuerzo `high`;
LINEO; sin Python; nada fuera de la zona; sin commit ni push; sin secretos. Presupuesto: 1 h.
