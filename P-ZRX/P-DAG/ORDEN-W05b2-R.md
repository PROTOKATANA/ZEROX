# ORDEN-W05b2-R — Rebase de W05b2 sobre la raíz actual

- **ID:** W05b2-R. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W05b2R/`.
- **Motivo:** W05b2 (SUPERADO, `deepseek/W05b2/INFORME.md`) partió de la raíz de las 02:33; después se
  migraron W06c (`zx-p2p`) y W03-R (motor de transición). Su `cambios.patch` aplica sobre la raíz
  actual **salvo** `Cargo.toml` (lista de miembros), `Cargo.lock` y `ci/frontera-crates.sh`, que
  W06c también modificó (comprobado por el director con `git apply --check -p1`).

## Qué hacer

1. Copia la raíz actual a `ws.orig/` y `ws/` (con el enlace `ws/PDF` al clon, excluido de la
   migración).
2. Aplica en `ws/` el parche de W05b2 **excepto** esos tres archivos
   (`git apply -p1 --exclude=Cargo.toml --exclude=Cargo.lock --exclude=ci/frontera-crates.sh`).
3. Rehaz a mano, con el **mínimo** cambio, lo que el parche hacía en ellos: añadir `crates/zx-post`
   a los miembros del workspace, la regla `zx-post → {zx-core, zx-pot, zx-dag, zx-poas}` en
   `frontera-crates.sh` **conservando** las reglas actuales, y deja que un único
   `cargo metadata --format-version 1 >/dev/null` actualice el lock (sin `cargo update`). Demuestra
   que el lock solo añade `zx-post` y sus aristas, sin cambiar versiones (`logs/lock-diff.txt`).
4. Ejecuta con `--locked`: `fmt --check`, `clippy -D warnings`, `cargo test --workspace
   --all-features`, `dependencias-exactas.sh`, `frontera-crates.sh`. Criterio: todos los tests de la
   raíz actual con su nombre más los de W05b2 (incluido el extremo a extremo del bloque de transición).
5. Entrega `cambios.patch` (`diff -ruN ws.orig ws`), `MIGRACION.sha256`, `logs/`, `INFORME.md` breve,
   `HORAS.log`.

Si algo más no aplica o falla, **para** e infórmalo con la salida literal. Entorno como W03-R
(`CARGO_HOME`/`CARGO_TARGET_DIR` en la zona, caché copiable de `deepseek/W05b2/.cargo-home`,
8 hilos). DeepSeek `deepseek-flash`, esfuerzo `high`; lee y aplica `V-ZRX/LINEO.md`; sin Python; nada
fuera de la zona; sin commit ni push; sin secretos. Presupuesto: 1 h, 8 hilos, 16 GiB.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W05b2R && cd /home/katana/zeo/ZEROX/deepseek/W05b2R && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W05b2-R. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-DAG/ORDEN-W05b2-R.md y cúmplelo. Lee /home/katana/zeo/ZEROX/V-ZRX/LINEO.md antes de ejecutar nada." \
      > ../W05b2R-dsh.stdout 2> ../W05b2R-dsh.stderr )
