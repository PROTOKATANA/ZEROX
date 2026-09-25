# PROGRESO.md — ORDEN-L01

**Sesión:** DeepSeek Harness, modelo `deepseek-flash` (DeepSeek-V41-Flash; la orden lo nombra
`deepseek-v4.1-flash`). **Inicio:** 2026-09-26T01:05+02:00. **Fin:** 2026-09-26T01:08+02:00.
**Zona de ejecución:** `/home/katana/zeo/ZEROX/deepseek/L01/`.

## 0. Lectura previa y falta de definición

Leídos íntegros, antes de ejecutar o escribir nada: `P-ZRX/P-LINEA-BASE/ORDEN-L01.md` (202 líneas),
`V-ZRX/LINEO.md` (627 líneas) y `R-ZRX/MAPA-RESCATE.md` §1 (entradas obligatorias §2 de la orden).

Comprobaciones de viabilidad hechas antes de actuar (solo lectura, sin escribir fuera de la zona):

- Commit `9681061` existe en `/home/katana/zeo/ZEROX` (rama `rediseno/v1-spec-first`).
- Clon Autonomys en `/home/katana/zeo/.trash/zerox/PDF/autonomys-subspace` con `HEAD =
  f8842d019cdf0f7163421b9644db5a9ff82b2a73` y `status --porcelain` vacío.
- Toolchain `nightly-2026-05-03-x86_64-unknown-linux-gnu` instalada en `~/.rustup`. `/usr/bin/cargo`
  y `/usr/bin/rustc` son enlaces simbólicos a `rustup`, así que desde `checkout/` respetan
  `rust-toolchain.toml` (comprobado).
- Red operativa para un `CARGO_HOME` limpio (`index.crates.io` 200; `git ls-remote` de
  `grandinetech/rust-kzg` rev `8f5f1a0f…` correcto; en `Cargo.lock:1977, :3421`).
- El commit no tiene `.cargo/config.toml` ni configuración de Cargo fuera de las rutas archivadas;
  `git clone` crea los directorios padre ausentes.
- Rutas archivadas existentes: `crates`, `prototipos`, `testdata`, `veritas`, `ci`, `Cargo.toml`,
  `Cargo.lock`, `rust-toolchain.toml`.

**Falta de definición detectada (durante S4, ver §2 del INFORME):** la preparación fija de §4 no
extrae `SPEC.md`, pero `crates/zx-consensus/tests/spec_numeros.rs:48` lo necesita con
`include_str!("../../../SPEC.md")`. Con esa entrada, S4 **no puede compilar**. No se ha añadido
`SPEC.md` ni se ha reintentado con otra extracción: §3 lo prohíbe («no elijas tú»). Se informa.

## 1. Comprobación de `ENTRADA.sha256` — INICIO

Comando exacto (desde `/home/katana/zeo/ZEROX`):

```
LC_ALL=C sha256sum -c P-ZRX/P-LINEA-BASE/ENTRADA.sha256
```

Salida literal (2026-09-26T01:05:28+02:00), en `logs/01-entrada-inicio.log`:

```
P-ZRX/P-LINEA-BASE/ORDEN-L01.md: OK
V-ZRX/LINEO.md: OK
exit=0
```

## 2. Comprobación de `ENTRADA.sha256` — FIN

Mismo comando (2026-09-26T01:07:13+02:00), en `logs/02-entrada-fin.log`:

```
P-ZRX/P-LINEA-BASE/ORDEN-L01.md: OK
V-ZRX/LINEO.md: OK
exit=0
```

## 3. Diario de pasos

### Preparación (`logs/00-preparacion.log`)

- `git archive 9681061 crates prototipos testdata veritas ci Cargo.toml Cargo.lock
  rust-toolchain.toml | tar -x -C checkout` → `exit_extract=0`.
- `git clone --no-hardlinks … checkout/PDF/autonomys-subspace` → `exit_clone=0`.
- `git checkout --detach f8842d0…` → `exit_checkout=0`; `rev-parse HEAD =
  f8842d019cdf0f7163421b9644db5a9ff82b2a73`.
- Manifiesto: `840` archivos (excluido `./PDF`), `exit_manifest=0`.

### Integridad de la extracción (antes de compilar)

- Hashes fijos (§6) correctos: `SHA3_256ShortMsg.rsp` `e75b1ded…`, `SHA3_256LongMsg.rsp`
  `741b75d0…`, `SHA3_256Monte.rsp` `0b387d75…`, `crates/zx-pot/tests/vectores-nightly.txt`
  `023a9fc8…`.
- Unidad de reproducibilidad (coincide con `MAPA-RESCATE.md` §1): `Cargo.toml` `619d4950…`,
  `Cargo.lock` `9021465d…` (496 paquetes), `rust-toolchain.toml` `604b0c1b…`.
- Inventario `#[test]`: `zx-core=156`, `zx-pot=5`, `zx-storage=60`, `zx-consensus=422`,
  `zx-node=137`. Atributos reales `#[ignore]` en `zx-consensus`: **4** (el texto `#[ignore`
  aparece 5 veces; `firmante_local.rs:7` es un comentario de documentación).

### Pasos de verificación

| Paso | Inicio | Fin | Exit | Resultado |
|---|---|---|---|---|
| S0 `cargo metadata --locked` | 01:05:41 | 01:05:51 | 0 | REPRODUCIDO; `logs/S0-metadata.json` 2 250 912 B |
| S1 `cargo test -p zx-core` | 01:05:56 | 01:06:02 | 0 | REPRODUCIDO; 156/156 |
| S2 `cargo test -p zx-pot` | 01:06:02 | 01:06:03 | 0 | REPRODUCIDO; 5/5 |
| S3 `cargo test -p zx-storage` | 01:06:03 | 01:06:08 | 0 | REPRODUCIDO; 36/36 (24 tests tras `rocksdb`) |
| S4 `cargo test -p zx-consensus` | 01:06:08 | 01:06:11 | **101** | **FALLA**: `SPEC.md` no extraído |
| S5 `cargo test -p zx-node --features farmer --test farmer_disco` | 01:07:36 | 01:08:24 | 0 | REPRODUCIDO; 13/13 |

### Comprobaciones finales (`logs/99-integridad-final.log`)

- `diff` del checkout contra `MANIFIESTO-CHECKOUT.sha256` → **vacío** (`exit_diff=0`).
- `git -C checkout/PDF/autonomys-subspace status --porcelain` → **vacío** (`exit_status=0`).
- Hashes fijos y unidad de reproducibilidad: sin cambios.
- `ENTRADA.sha256` final: OK (ver §2).

### Presupuesto

Tope 3 h / 16 hilos / 48 GiB RAM / 60 GiB disco. Consumo real ≈ 3 min de reloj de trabajo; disco
≈ 5,3 GiB; RAM sin tensión. No se agotó. Carga ajena presente (`uptime` 0,33 → 3,51).

## 4. Veredicto

S0, S1, S2, S3 y S5 **REPRODUCIDOS**; S4 **FALLA** por causa de la entrada incompleta de la orden
(falta `SPEC.md`), no del código. Detalle y salida literal en `INFORME.md` §2, §5 y §6.

## 5. Corrección C1 (2026-09-26, 01:12–01:14 +02:00)

Origen: `P-ZRX/P-LINEA-BASE/CORRECCION-L01-S4.md` (ID L01-C1). Rige `ORDEN-L01.md` en todo lo no
cambiado. **Falta de definición: ninguna**; la corrección fija extracción, hash de control, comandos,
formato de filas y comprobaciones finales.

### 5.1 Cambios en la entrada

- Extracción adicional (desde `deepseek/L01/`):
  `git -C /home/katana/zeo/ZEROX archive 9681061 SPEC.md | tar -x -C checkout` → `exit_pipe=0 0`
  (`logs/C1-extraccion.log`).
- `sha256sum checkout/SPEC.md` = `b59905c5f1900076e699f762f3f6604f282790fa5a7ed97527d22d21f9d4e0ae`,
  idéntico al exigido.
- `MANIFIESTO-CHECKOUT.sha256` regenerado con el comando de §4 → **841** archivos; copia previa
  `MANIFIESTO-CHECKOUT.antes-C1.sha256` (840). `diff` = solo la línea `./SPEC.md` (`206a207`),
  guardado en `logs/C1-diff-manifiesto.log`; el resto del manifiesto idéntico.

### 5.2 Diario de pasos

| Momento | Acción | Resultado (`logs/`) |
|---|---|---|
| 01:12:01 | Extracción de `SPEC.md` y verificación sha256 | OK (`C1-extraccion.log`) |
| 01:12:04 | Manifiesto regenerado + `diff` contra el anterior | solo `./SPEC.md` (`C1-manifiesto.log`, `C1-diff-manifiesto.log`) |
| 01:12:08–01:12:21 | **S4** `cargo test --locked -p zx-consensus` | exit 0, 13 s (`S4-C1-zx-consensus.log`) |
| 01:12:31–01:13:33 | **S3b** `cargo test --locked -p zx-storage --features rocksdb` | exit 0, 62 s (`S3b-zx-storage-rocksdb.log`) |
| 01:14:10 | Integridad final: checkout, clon, hashes, `ENTRADA`, `ENTRADA-C1` | todo OK (`99-C1-integridad-final.log`) |

`HORAS.log` recibe las 4 marcas `date -Is` de S4 y S3b (líneas 15–18); las horas de la extracción y
del manifiesto quedan en las cabeceras de sus logs.

### 5.3 Resultados

- **S4**: 22 binarios; **421 pasadas, 0 fallidas, 4 ignoradas, 0 filtradas**. Conteo: 422 `#[test]`
  (referencia) con 4 `#[ignore]` reales + 3 doc-tests ⇒ 422 − 4 + 3 = 421. **Coincide.**
- **S3b**: 5 binarios; **60 pasadas, 0 fallidas, 0 ignoradas**. Cubre `src/disco.rs` (11) y los 13
  de integración, incluido `matar_a_mitad_de_escritura_no_deja_el_almacen_incoherente`.
  `libclang` del sistema sirvió a `bindgen`; descargó `rocksdb`/`librocksdb-sys` de crates.io.
- `RESULTADOS.tsv`: fila `S4` antigua marcada «(sustituida por C1)» + 27 filas nuevas (`S4-C1` 22,
  `S3b` 5). Copia previa en `logs/RESULTADOS.antes-C1.tsv`.

### 5.4 Veredicto

S0, S1, S2, S3, **S3b**, **S4** y S5 **REPRODUCIDOS**. Integridad del checkout y del clon vacía;
`ENTRADA.sha256` y `ENTRADA-C1.sha256` OK. Presupuesto C1 (1 h) no agotado (≈ 2 min de reloj).
