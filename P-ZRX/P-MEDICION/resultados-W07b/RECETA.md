# RECETA — E-0, clon limpio y build del commit candidato 27dcfeb

Todo esto se ejecuta con cwd `/home/katana/zeo/ZEROX/deepseek/W07b/clon` salvo que se diga otra cosa.
Zona única escribible: `/home/katana/zeo/ZEROX/deepseek/W07b/`. El repositorio principal no se toca.

## 1. Clon limpio (hecho, `date -Is` = 2026-09-27T10:46:31+02:00)

```bash
cd /home/katana/zeo/ZEROX/deepseek/W07b
git clone --no-hardlinks /home/katana/zeo/ZEROX clon
git -C clon checkout 27dcfeb   # 27dcfeb09e7e0a105c5c55a94766621b99fbfc57
```

Commit verificado: `27dcfeb09e7e0a105c5c55a94766621b99fbfc57` ("SPEC-0.0.1 e IPA: SL-4b3 hecha; W07b lista").

## 2. Clon fijado de Autonomys (paso "Clonar Autonomys" de zerox-ci.yml, adaptado a copia local)

```bash
cd clon
git clone --no-hardlinks /home/katana/zeo/ZEROX/PDF/autonomys-subspace PDF/autonomys-subspace
git -C PDF/autonomys-subspace checkout --detach f8842d019cdf0f7163421b9644db5a9ff82b2a73
```

## 3. Pasos del job `rust` de zerox-ci.yml

```bash
cd clon
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo build --workspace --all-features --locked
cargo test --workspace --all-features --locked
```

Toolchain: `nightly-2026-05-03` (fijado por `rust-toolchain.toml` o equivalente; comprobado con
`rustc --version` antes de compilar).

## 4. Pasos del job `deps`

```bash
cd clon
bash ci/dependencias-exactas.sh
bash ci/frontera-crates.sh
bash ci/firmante-obligatorio.sh
```

## 5. Binario release de las mediciones

```bash
cd clon
cargo build --release --locked -p zx-node
```

Produce `clon/target/release/zx-node` y `clon/target/release/zx-adversario` (mismo paquete, bin
adicional).

## 6. Resultado de E-0 (completo 2026-09-27T11:29+02:00)

- `cargo fmt --all -- --check`: verde.
- `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: verde, sin avisos.
- `cargo build --workspace --all-features --locked`: verde.
- `cargo test --workspace --all-features --locked`: verde, 0 fallos (workspace completo).
- `ci/dependencias-exactas.sh`: verde.
- `ci/frontera-crates.sh`: verde.
- `ci/firmante-obligatorio.sh`: verde.
- `cargo build --release --locked -p zx-node`: verde, `Finished release profile [optimized] target(s) in 1m 36s`.
- Commit del clon: `27dcfeb09e7e0a105c5c55a94766621b99fbfc57`.
- `sha256sum clon/target/release/zx-node` = `a9f0ffa1b42e3c7c3eaea0ba6a87a20f9a46dfd2118a3b761f4a26be58bf19e1`
- `sha256sum clon/target/release/zx-adversario` = `a8bcc9d09cf8d891b84212d367243885fc4e900777cec27e7ebecc0d6b906c38`
- CLI verificada con `--help`: todos los nombres de bandera (`--datos`, `--registro`, `--claves`,
  `--n-dev` [default 138873760], `--sr-dev` [default u64::MAX], `--semilla` [default 1],
  `--dejar-de-producir-en-slot`, `--red-escuchar`, `--red-marcar`) coinciden con lo asumido en
  `scripts/lib_red.sh`. `zx-adversario` confirma el subcomando `doble-firma` con `--clave-indice`,
  `--semilla`, `--plazo-espera-s`, `--repetir`.

**E-0: SUPERADO.**

## 7. E-0 repetido sobre el nuevo commit candidato (director, 2026-09-27 ~14:36): `26312ffee1b9fd1aa74b1323e087caa1d64a5a77`

W06d8 migrada: protocolo productor↔bucle numerado, sin el panic de `regimen.rs:438` (evidencia
conservada en `run/E2a-calibracion-intento4-panic-productor/`, medido sobre `27dcfeb`), parada
ordenada si el productor falla. Clon nuevo en `deepseek/W07b/clon-26312ff/` (mismo procedimiento:
clon limpio, checkout, clon fijado de Autonomys en `f8842d0`, todos los pasos de la CI local); el
clon anterior (`clon/`, commit `27dcfeb`) se conserva sin tocar.

- `cargo fmt --all -- --check`: verde.
- `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: verde.
- `cargo build --workspace --all-features --locked`: verde.
- `cargo test --workspace --all-features --locked`: verde, 0 fallos.
- `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`, `ci/firmante-obligatorio.sh`: verdes.
- `cargo build --release --locked -p zx-node`: verde. Terminado 2026-09-27T15:19.
- Commit: `26312ffee1b9fd1aa74b1323e087caa1d64a5a77`.
- `sha256sum clon-26312ff/target/release/zx-node` = `70b0cf2d521c5cbd1bdebd12bb47381c772a498c496861dd77e83d5911cddc01`
- `sha256sum clon-26312ff/target/release/zx-adversario` = `a8bcc9d09cf8d891b84212d367243885fc4e900777cec27e7ebecc0d6b906c38`
  (idéntico al de `27dcfeb`: `zx-adversario` no cambió entre estos dos commits, consistente con que
  W06d8 solo tocó `zx-node`/`regimen.rs`).

**Todos los escenarios R1…R4 se miden con ESTOS binarios (commit `26312ff`), no los de `27dcfeb`.**

## 8. E-0 completa sobre el commit definitivo (director, 2026-09-27 ~19:xx): `3d21b1f44301991fb59737e2117cc26a66a4e93f`

W06d9 migrada: el nodo registra todos los portadores PoT de la justificación (no solo el último),
así que el hilo productor ya no muere por «no hay portador retenido para el slot» cuando el
portador correcto no es el último anotado (causa real del `FALLO_FATAL` de C en
`run/R3-E6-rep1-26312ff-panic-contaminado/`). Clon en `deepseek/W07b/clon-3d21b1f/` (mismo
procedimiento: clon limpio, checkout, clon fijado de Autonomys en `f8842d0`). El build release
(`cargo build --release --locked -p zx-node`) se hizo primero (2026-09-27, para no bloquear las
mediciones de R3/R4); la CI completa se hizo al final, sobre el mismo árbol ya usado para medir
(sin cambios entre medias):

```bash
cd clon-3d21b1f
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo build --workspace --all-features --locked
cargo test --workspace --all-features --locked
bash ci/dependencias-exactas.sh
bash ci/frontera-crates.sh
bash ci/firmante-obligatorio.sh
cargo build --release --locked -p zx-node
```

Resultado (completo 2026-09-27T21:31:18+02:00, log en `run/e0-3d21b1f-ci.log`):

- `cargo fmt --all -- --check`: verde.
- `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: verde, sin avisos.
- `cargo build --workspace --all-features --locked`: verde.
- `cargo test --workspace --all-features --locked`: verde, 0 fallos (workspace completo, incluye
  los tests de reinicio/SIGKILL, dial-reintento, integración con cruce del corte, etc.).
- `ci/dependencias-exactas.sh`: verde — 24 dependencias con versión exacta.
- `ci/frontera-crates.sh`: verde — todas las fronteras de crates respetadas.
- `ci/firmante-obligatorio.sh`: verde — ningún productor sin firmante.
- `cargo build --release --locked -p zx-node`: verde (repetido para consistencia; `Finished` en
  0.14s porque ya estaba compilado).
- Commit del clon: `3d21b1f44301991fb59737e2117cc26a66a4e93f`.
- `sha256sum clon-3d21b1f/target/release/zx-node` = `e7ef7f19a701188237e38266f5d6361c16228620fcf4039e5a67d3b2339900de`
- `sha256sum clon-3d21b1f/target/release/zx-adversario` = `a8bcc9d09cf8d891b84212d367243885fc4e900777cec27e7ebecc0d6b906c38`
  (idéntico a `27dcfeb`/`26312ff`: `zx-adversario` no ha cambiado en ningún commit candidato de
  W07b).
- Estos hashes coinciden EXACTAMENTE con los usados durante todas las mediciones de R3 y R4
  (registrados en cada `EJECUCION.txt`): el binario no cambió entre la medición y esta CI final.

**E-0: SUPERADO. `3d21b1f` es el commit definitivo de 0.0.1 para W07b.**

**R3 (E-6, E-6b) y R4 (E-7, E-8, E-9) se midieron con ESTOS binarios (commit `3d21b1f`).**
