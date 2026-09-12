# `pot-estable` — el Proof-of-Time de Autonomys portado a Rust estable

**Prototipo verificado, NO es todavía un crate de ZEROX.** No está en `members` del workspace a
propósito: ZEROX es spec-first y este código entrará como crate cuando tenga sus reglas `C-XXX`
escritas en el SPEC. Se guarda aquí porque **está probado** y perderlo costaría rehacer el trabajo.

## Qué es

`subspace-proof-of-time` (subspace @ `f8842d0`, licencia 0BSD) compilando en **estable**.

- `src/aes.rs`, `src/aes/x86_64.rs`, `src/aes/aarch64.rs` — **copiados literalmente**, salvo la
  sustitución de `portable_simd` descrita abajo. No se ha reimplementado ninguna primitiva.
- `src/tipos.rs` — **escrito por nosotros.** Los cuatro *newtypes* (`PotKey`, `PotSeed`,
  `PotOutput`, `PotCheckpoints`) son envoltorios de `[u8;16]`; el original los saca de
  `subspace-core-primitives`, que arrastra `parity-scale-codec`, `scale-info` y `serde` — toda la
  serialización de Substrate, que ZEROX no usa (usamos Cap'n Proto). Reescribirlos evita esa rama
  entera del árbol de dependencias.

## La única modificación al código criptográfico

`aes/x86_64.rs` usaba `core::simd` (nightly) en **28 sitios**, y en todos ellos solo para convertir
`[u8;N]` a un registro y volver. El AES ya se hacía con `core::arch::x86_64`, que es **estable**.
Sustituido por `_mm_loadu_si128` / `_mm_storeu_si128` / `_mm256_loadu_si256` / `_mm512_loadu_si512`.

## Por qué se puede confiar en él

```
tests/diferencial.rs   32/32 vectores byte a byte idénticos al original
```

Los vectores de `tests/vectores-nightly.txt` se generaron ejecutando el **crate original sin
modificar** bajo `nightly-2026-05-03`. El port los reproduce exactamente. Y el test se verificó por
mutación: cambiando un solo byte de un vector, falla.

```
rustup run stable cargo test --release      # rustc 1.93.1
```

## Por qué sigue sirviendo aunque ZEROX ya esté en nightly

`rust-toolchain.toml` fija nightly para el workspace principal, así que **este port ya no es
necesario** para compilar. Sigue mereciendo la pena por lo otro: no arrastra Substrate. Si se adopta, ZEROX depende
para el PoT solo de `aes`, `blake3`, `cpufeatures` y `thiserror`.

Estado actual y contratos pendientes de integración: [MIGRACION.md](../../MIGRACION.md).
