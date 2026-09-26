# ORDEN-W03-R — Rebase de W03 sobre la raíz actual

- **ID:** W03-R. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W03R/`.
- **Motivo:** W03 (SUPERADO, `deepseek/W03/INFORME.md`) partió de la raíz de las 02:26; después se
  migraron W05b1 (`zx-poas`, `zx-farmer`) y W06c (`zx-p2p`). Su `cambios.patch` aplica sobre la raíz
  actual **salvo** el trozo de `Cargo.lock` que añade `ed25519-zebra` a las dependencias de
  `zx-consensus` (el contexto cambió: ahora hay `thiserror 2.0.20`). Comprobado por el director con
  `git apply --check -p1` (todo lo demás aplica).

## Qué hacer

1. Copia la raíz actual (`Cargo.toml Cargo.lock rust-toolchain.toml crates/ testdata/ ci/ .github/`)
   a `ws.orig/` y a `ws/`, con el enlace `ws/PDF` al clon de la raíz (excluido de la migración).
2. En `ws/`, aplica `deepseek/W03/cambios.patch` **excepto** el trozo de `Cargo.lock`
   (`git apply -p1 --exclude=Cargo.lock`). **No cambies ningún otro archivo del parche.**
3. Deja que cargo actualice el lock para la dependencia nueva de `zx-consensus` con un único
   `cargo metadata --format-version 1 >/dev/null` (sin `cargo update`). Demuestra que la única
   diferencia del lock frente a la raíz es añadir `"ed25519-zebra",` a la lista de dependencias de
   `zx-consensus` (`logs/lock-diff.txt`).
4. Ejecuta, con `--locked`: `cargo fmt --all -- --check`,
   `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`,
   `cargo test --workspace --all-features --locked`. Criterio: todos los tests de la raíz actual con
   su nombre más los de W03; `diferencial_t01` con 0 discrepancias; `ci/dependencias-exactas.sh` y
   `ci/frontera-crates.sh` OK.
5. Entrega `cambios.patch` (`diff -ruN ws.orig ws`, sin `target` ni cachés), `MIGRACION.sha256`,
   `logs/`, `INFORME.md` breve (veredicto, recuentos, lock), `HORAS.log`.

Si algo más no aplica o falla, **para** e infórmalo con la salida literal. Entorno: `CARGO_HOME` y
`CARGO_TARGET_DIR` en la zona (caché copiable de `deepseek/W03/.cargo-home` o `W05b1`),
`CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`. DeepSeek `deepseek-flash`, esfuerzo `high`; lee y aplica
`V-ZRX/LINEO.md`; sin Python; nada fuera de la zona; sin commit ni push; sin secretos. Presupuesto:
1 h, 8 hilos, 16 GiB.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W03R && cd /home/katana/zeo/ZEROX/deepseek/W03R && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W03-R. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-W03-R.md y cúmplelo. Lee /home/katana/zeo/ZEROX/V-ZRX/LINEO.md antes de ejecutar nada." \
      > ../W03R-dsh.stdout 2> ../W03R-dsh.stderr )
