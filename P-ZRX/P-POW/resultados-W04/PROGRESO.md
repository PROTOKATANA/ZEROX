# PROGRESO.md — ORDEN-W04

Motor PoW de la red dev en el crate **nuevo** `crates/zx-consensus`, parametrizado por red, con
minero CPU. Zona única: `/home/katana/zeo/ZEROX/deepseek/W04/`.

## Entrada congelada — comprobación de INICIO (2026-09-26T01:38 +02:00)

`sha256sum -c P-ZRX/P-POW/ENTRADA-W04.sha256` desde la raíz; coinciden las 4 huellas
(`logs/entrada-inicio.log`):

```
P-ZRX/P-POW/ORDEN-W04.md: La suma coincide
P-ZRX/P-FORMATO/FORMATO-v0.md: La suma coincide
P-ZRX/PLAN-0.0.1.md: La suma coincide
V-ZRX/LINEO.md: La suma coincide
exit=0
```

`LINEO.md` se leyó íntegro antes de escribir código. Como Veritas es Julia/C++ y esta orden es
Rust de consenso, sus reglas aplicables se traducen así: oráculo/constantes **recalculadas** en
tests (no transcritas), determinismo explícito, aritmética entera comprobada (`checked_*`, sin
floats), nada de `unsafe`, y presupuesto declarado (§7: 2 h, 8 hilos, 16 GiB, 20 GiB).

## Falta de definición detectada e informada antes de editar

`ORDEN-W04 §3.5` fija `limites.max = decodificar(0x1e7fffff)` y `bits_iniciales = 0x1e7fffff`, con el
aviso «si `0x1e7fffff` no es canónico o viola alguna regla de `target.rs`, para e infórmalo».

Comprobado antes de tocar código: `0x1e7fffff` **sí es canónico** (exponente 30, mantisa
`0x7fffff`, sin bit de signo, `24 + 216 = 240 ≤ 256`) y su decodificación es exacta
(`0x7fffff · 2^216 = 2^239 − 2^216`, recalculado en test). Lo único que ocurre es que ese target
**supera el `POW_LIMIT` antiguo** (`2^224 − 1`) — precisamente el motivo de que la orden pida
`LimitesTarget` por red. No se eligió ningún otro valor: el perfil dev lo admite con sus propios
límites y `decodificar_con` los aplica. Queda fijado con los tests
`decodificar_con_aplica_los_limites_de_la_red` (zx-core),
`el_maximo_dev_es_la_expansion_de_su_bits_iniciales` y
`unos_bits_fuera_de_los_limites_de_la_red_invalidan`.

## Secuencia de trabajo

1. **01:38–01:39 · Lectura y montaje.** Lectura íntegra de `ORDEN-W04.md`, `V-ZRX/LINEO.md`,
   `P-TRANSICION/CONTRATO-v0.md` §0/§5, `P-FORMATO/FORMATO-v0.md` y `PLAN-0.0.1.md`; comprobación de
   la entrada; lectura del código antiguo (`dificultad.rs`, `fork_choice.rs`, `timestamps.rs`,
   `genesis.rs`, `activacion.rs`, `bloque.rs::validar_cabecera`, `error.rs`). Copia de
   `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`, `testdata/`, `ci/`, `.github/` a
   `ws.orig/` y `ws/`; copia de `.cargo-home` de W02.
2. **01:39–01:40 · `zx-core` por red.** `LimitesTarget`, `LIMITES_ANTIGUOS`, `LIMITES_AMPLIOS`,
   `decodificar_con`, `codificar_con`; `CompactBits::decodificar`/`codificar` delegan y los 12 tests
   antiguos de `target.rs` siguen pasando; 2 tests nuevos.
3. **01:40–01:45 · Crate `zx-consensus`.** `parametros.rs` (derivadas `k/nk/st_cap/t_floor/ftl` y
   perfiles antiguo/dev), `algoritmo.rs` (`AlgoritmoPow`, `Sha3Dev`), `activacion.rs` (rama dev),
   `error.rs` (`ErrorPow`), `dificultad.rs` (LWMA-1), `timestamps.rs`, `fork_choice.rs` (sin
   `MAX_REORG_LENGTH`), `genesis.rs` (mainnet/testnet/dev), `verificador.rs` y `minero_dev.rs`.
4. **01:45 · `HASH_GENESIS_DEV`.** Calculado con un ejemplo temporal (borrado después) y congelado:
   `c72fdb3b37e7571a82ec1e0e973e90d5e95e7ad9fc871772265b1994050c2d59`.
5. **01:45–01:47 · Tests nuevos.** `tests/pow_dev.rs` (V5 y V6) y `tests/verificador_pow.rs`
   (§5/§6). Un primer clippy señaló 4 expectativas incumplidas, 2 `expect()` y 2 divisiones
   enteras; corregido: **V1** y **V2** limpios.
6. **01:47–01:50 · V3–V7.** `cargo test --workspace --all-features --locked`: **265 pasan, 0
   fallan**; los **182** nombres de W02 siguen presentes. `ci/frontera-crates.sh` portado y
   ajustado a `zx-consensus → {zx-core}` (con `jq`, que sí está); CI actualizada.
7. **01:50– · Entregables.** `cambios.patch`, `MIGRACION.sha256` (70 huellas, `sha256sum -c` OK),
   `logs/lock-subconjunto.txt` (única adición: `zx-consensus 0.0.0`), logs V1–V7, `INFORME.md`,
   `HORAS.log` y comprobación final de la entrada.

## Resultado

- V1 `fmt` OK; V2 `clippy -D warnings` 0 avisos; V3 **265 tests, 0 fallan** (182 previos con su
  nombre); V4 tests portados con parámetros antiguos dan los mismos valores (detalle en
  `INFORME.md`); V5 40/40 válidos; V6 dirección y techo del retarget comprobados; V7 OK.
- `zx-consensus` es la **única** adición al `Cargo.lock`; ninguna versión existente cambia.
- Veredicto: **SUPERADO**.
