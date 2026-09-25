# PROGRESO.md — ORDEN-W02

Formatos v0 del híbrido en `crates/zx-core`, con oráculo Julia independiente. Zona única:
`/home/katana/zeo/ZEROX/deepseek/W02/`.

## Entrada congelada — comprobación de INICIO (2026-09-26T01:24 +02:00)

`sha256sum` de los cuatro ficheros de `P-ZRX/P-FORMATO/ENTRADA-W02.sha256`, comparados con el
contenido del fichero (coinciden los cuatro):

```
a93afafe0d838e62c613ab84ce43b8d3d3babd37a0827643c1792605b7e2b1b5  P-ZRX/P-FORMATO/ORDEN-W02.md
9503d535e588727789c9022f236df06aa06f5a54b32b0990640036c60cfa5a1e  P-ZRX/P-FORMATO/FORMATO-v0.md
3454c95d20b9e0a7c05900ebe6ec504439cf322f87888f75a3dcd538f4d26620  P-ZRX/PLAN-0.0.1.md
0343b83290489fde1b3ba961eb8fdd1f7ccb1bdf1ea1ee7062db993fc48936e1  V-ZRX/LINEO.md
```

## Entrada congelada — comprobación FINAL (2026-09-26T01:36 +02:00, último paso)

```
$ cd /home/katana/zeo/ZEROX
$ sha256sum -c P-ZRX/P-FORMATO/ENTRADA-W02.sha256
P-ZRX/P-FORMATO/ORDEN-W02.md: La suma coincide
P-ZRX/P-FORMATO/FORMATO-v0.md: La suma coincide
P-ZRX/PLAN-0.0.1.md: La suma coincide
V-ZRX/LINEO.md: La suma coincide
exit=0
```

## Secuencia de trabajo

1. **01:23–01:25 · Lectura y montaje.** Lectura íntegra de `ORDEN-W02.md`, `FORMATO-v0.md`,
   `LINEO.md` y `PLAN-0.0.1.md` §3; comprobación de la entrada; lectura del código base
   (`tx.rs`, `wire.rs`, `hash.rs`, `preimage/tx.rs`, `error.rs`, `red.rs`, `address.rs`,
   `forma` aún inexistente) y de los vectores antiguos. Copia de `Cargo.toml`, `Cargo.lock`,
   `rust-toolchain.toml`, `crates/`, `testdata/`, `ci/`, `.github/` a `ws.orig/` y `ws/`; copia de
   `.cargo-home` de W01. Se detectan las cinco definiciones imperfectas del §5 del `INFORME.md` y se
   informan antes de editar.
2. **01:25–01:26 · Tercer ancla v1.** Con el `ws/` aún prístino se congela el `txid` de
   `tx_ejemplo()` con un test temporal (`logs/ancla-tmp.log`): `c722c4f8…3bc6`. El test temporal se
   borra.
3. **01:26–01:30 · Implementación Rust.** `ExtensionTx`/`TipoGarantia` y `Tx.extension`;
   `ErrorFormaTx` y errores de códec; dos etiquetas nuevas en `TAGS_FIJAS` (15→17);
   `extension_digest` + `txid` v2/v3 + `mensaje_aceptacion` + `verificar_aceptacion`; códec F-14;
   `forma.rs`; `Red::Dev`/`MAGIC_DEV`/`CBID_RED_DEV`/`HRP_DEV`; actualización mecánica de los
   literales de test con `extension: Ninguna`.
4. **01:26–01:28 · Oráculo Julia.** Proyecto `oraculo-formato-v0/` (solo stdlib `SHA`/`Test`),
   `referencia.jl`, `runtests.jl`, `run.jl`, `Project.toml`, `Manifest.toml`, `julia-version.toml`.
   `Pkg.test()` 80/80 y `run.jl --seed 0x5a5a`: 14 casos. Vectores copiados a
   `ws/testdata/formato-v0/`.
5. **01:30–01:32 · Test Rust nuevo.** `formato_v0.rs`: 19 tests, todos verdes; Rust y Julia
   coinciden en wire, `txid` y mensaje de aceptación, y los tres `txid` v1 antiguos se reproducen.
6. **01:32–01:34 · V1–V7.** Primer clippy con dos avisos (`manual_range_patterns` y `expect`
   incumplidos); corregidos; segunda pasada: V1=0, V2=0, V3=0 (182/0), V7=0; V5 sin faltantes; V6
   con solo los dos diffs mecánicos. Julia regenerada (idéntica). Test nuevo re-ejecutado: 19/19.
7. **01:34–01:36 · Entregables.** `cambios.patch` (2164 líneas), `MIGRACION.sha256` (54 huellas,
   verificado), `oraculo-formato-v0/INFORME.md`, este `PROGRESO.md`, `HORAS.log`, `INFORME.md` y
   comprobación final de la entrada.

## Resultado

- V1 `fmt` OK; V2 `clippy -D warnings` OK; V3 **182 tests, 0 fallan**; V4 oráculo 80/80 y vectores;
  V5 los 161 antiguos con su nombre; V6 vectores antiguos intactos; V7 10 dependencias exactas.
- Ninguna dependencia Rust nueva; `Cargo.lock` y `Cargo.toml` sin tocar.
- Veredicto: **SUPERADO**.
