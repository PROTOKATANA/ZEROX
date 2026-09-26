# INFORME.md — ORDEN-W05b1

**Crates nuevos `crates/zx-poas` y `crates/zx-farmer`: verificador PoAS, historia derivada del
génesis dev (D-P12) y granjero real (ploteo y auditoría).**
Sesión: DeepSeek Harness, modelo `deepseek-flash`, esfuerzo `high`. Fecha: 2026-09-26,
02:13–02:29 +02:00. Zona única: `/home/katana/zeo/ZEROX/deepseek/W05b1/`. Sin Python, sin `unsafe`,
sin commit ni push, nada escrito fuera de la zona. Base: workspace de la raíz (W01+W02+W04+W05a)
copiado a `ws.orig/` y `ws/`; el clon `PDF/autonomys-subspace` @ `f8842d0` enlazado en
`ws/PDF` (symlink, declarado).

**Pregunta falsable:** «Con la historia de un segmento derivada del génesis dev de W04, un sector
ploteado con el plotter real produce, para algún reto, una solución que `verify_solution` de
Autonomys `f8842d0` acepta con los `PieceCheckParams` de esa historia, y rechaza las soluciones
alteradas de §6.»
**Veredicto: NO REFUTADA — SUPERADO.** Tres soluciones honestas del sector ploteado (la primera en
el slot 0) son aceptadas con su distancia, y los diez casos de §6 son rechazados con su error.

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §4 de la orden) | Veredicto |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; `logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0, 0 avisos; `logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; **415 pasan, 0 fallan, 1 ignorado**; `logs/V3-test.log`; nombres en `logs/V3-nombres.txt`) |
| V4 | Tests antiguos portados/adaptados | **OK** (15 portados + 12 adaptados; 1 retirado con motivo; `logs/V4-tests.txt`) |
| V5 | Génesis dev → historia → plot de 1 sector → ≥3 soluciones → `verificar_solucion_poas` acepta | **OK** (3/3; primera en el slot 0; `logs/V4-V7-detalle.log`) |
| V6 | 10 negativos por mutación / contexto | **OK** (cada uno con su error; `logs/V4-V7-detalle.log`) |
| V7 | `COMPROMISO_HISTORIA_GENESIS_DEV` recalculado dos veces | **OK** (igual; `logs/V4-V7-detalle.log`) |
| V8 | `bash ci/dependencias-exactas.sh`, `bash ci/frontera-crates.sh` | **OK** (15 exactas; `zx-poas → {zx-core, zx-consensus}`, `zx-farmer → {zx-core, zx-poas}`; `logs/V8-*.log`) |
| Entrada | `sha256sum -c P-ZRX/P-DAG/ENTRADA-W05b1.sha256` al inicio y al final | **OK** en ambos (4/4; `logs/entrada-inicio.log`, `logs/entrada-final.log`) |
| Lock | subconjunto de versiones frente a `9681061` | **OK** (220 paquetes; toda adición externa con su misma versión; `logs/lock-subconjunto.txt`) |

Desglose de V3 (416 nombres = 415 pasan + 1 ignorado): 372 nombres de W05a siguen presentes
(**0 ausentes**) y **44** son nuevos: 15 de `zx-poas/tests/poas.rs`, 2 de
`zx-poas/tests/historia_genesis.rs`, 3 unitarios de `zx-poas` (`reto` y `protocolo_dev`), 12 de
`zx-farmer/tests/farmer_disco.rs` y 12 de `zx-farmer/tests/extremo_a_extremo.rs`. El único
ignorado sigue siendo el banco `bench_coloreo_mergeset_maximo` de W05a.

## 2. Falta de definición detectada (informada antes de fijar el código)

**Ninguna impide cumplir la orden tal cual.** Se aplican cuatro interpretaciones, sin lógica nueva:

1. **Reto de auditoría.** §3.2 exige `farmer.rs`/`productor_poas.rs` «sin cambio de lógica», y el
   código antiguo deriva el reto con `zx_consensus::reto_desde_salida(salida, slot)`, que en
   `9681061` vive en `zx-consensus::pot`; §5 prohíbe PoT y pide retos de prueba de 32 B, y W04 dejó
   `zx-consensus` sin `pot.rs`. Como la frontera §6 V8 impide que `zx-farmer` vea `zx-consensus`, la
   función **pura** (blake3 de sus argumentos; sin AES, flujo, `N(s)` ni cabecera) se porta a
   `zx-poas::reto`, se conserva la firma antigua de auditoría y se añade
   `ParcelaDisco::auditar_con_reto(reto: [u8;32], rango)` para fijar el reto explícitamente. Los
   tests usan `salida` (16 B) y `slot` de prueba fijos, de los que se deriva el reto de 32 B.
2. **`protocolo_dev.rs` en `zx-poas`.** Se sigue la letra de §3.1 (el módulo devuelve
   `FarmerProtocolInfo`), lo que añade `subspace-farmer-components` a `zx-poas`.
3. **`rand` además de `rand_chacha`.** D-P12 pide `fill`; se añade `rand =0.9.5` (del lock antiguo)
   para usarlo literalmente. No se sigue el relleno de Autonomys (`rand 0.8.5` + `rand_chacha
   0.3.1`): el nuestro es definición propia (D-P12), declarada.
4. **Clon en `ws/`.** Se usa un enlace simbólico `ws/PDF -> ZEROX/PDF`, excluido de `cambios.patch`
   y de `MIGRACION.sha256`, en vez de copiar 81 MiB.

## 3. Archivos cambiados y por qué

**`crates/zx-poas/` (nuevo):**

| Fichero | Contenido |
|---|---|
| `Cargo.toml`, `README.md` | crate nuevo; `zx-core`, `zx-consensus`, `blake3`, `rand`, `rand_chacha` y siete paquetes de Autonomys por ruta al clon |
| `src/verificador.rs` | `verificar_solucion_poas`, `ErrorPoas`, `ContextoInvalido`: `crates/zx-consensus/src/poas.rs` de `9681061` **verbatim** (sin cambio de lógica ni de imports) |
| `src/historia.rs` | `HistoriaGenesis` (receta D-P12), `ErrorHistoriaGenesis`, `COMPROMISO_HISTORIA_GENESIS_DEV`, `comprobar_compromiso` |
| `src/protocolo_dev.rs` | `FarmerProtocolInfo` dev: `history_size = 1`, `max_pieces_in_sector = 2`, `recent_segments = 5`, `recent_history_fraction = (1, 10)`, `min_sector_lifetime = 4` |
| `src/reto.rs` | `reto_desde_salida` y `aleatoriedad_de_salida` puros (`C-POT-03`) |
| `src/lib.rs` | reexportaciones |
| `tests/poas.rs` | los 15 tests antiguos con su fixture sintético |
| `tests/historia_genesis.rs` | V7 y cotejo del compromiso |

**`crates/zx-farmer/` (nuevo):**

| Fichero | Contenido |
|---|---|
| `Cargo.toml`, `README.md` | crate nuevo; `zx-core`, `zx-poas`, `futures`, `async-lock`, `parity-scale-codec`, `blake3` y siete paquetes de Autonomys por ruta |
| `src/farmer.rs` | `plotear_sector_en_disco`, `ParcelaDisco` (`abrir`, `auditar_candidatos`, `auditar_con_reto`, `auditar_slot`), `ErrorFarmer`: `crates/zx-node/src/farmer.rs` de `9681061` sin cambio de lógica, `HistoriaDagDev` → `HistoriaGenesis` |
| `src/productor_poas.rs` | `convertir_candidatos_locales`, `DiagnosticoLocal`, `SolucionComprobadaLocal`, `ResultadoConversionLocal`: `crates/zx-node/src/productor_poas.rs` sin cambio de lógica |
| `src/lib.rs` | reexportaciones |
| `tests/farmer_disco.rs` | 12 tests de contrato de D1 adaptados a `HistoriaGenesis` |
| `tests/extremo_a_extremo.rs` | V5 (≥3 soluciones + reto explícito) y V6 (10 negativos) |

**Raíz del workspace:**

| Fichero | Cambio | Motivo |
|---|---|---|
| `Cargo.toml` | miembros `zx-poas` y `zx-farmer`; `exclude` de los 9 paquetes del clon; `rand`, `rand_chacha`, `futures`, `async-lock`, `parity-scale-codec` en `[workspace.dependencies]` | §3.1, §3.4, §4 |
| `Cargo.lock` | +88 pares `(name, version)`: el árbol Autonomys, con versiones del lock de `9681061` | §4; `logs/lock-subconjunto.txt` |
| `ci/frontera-crates.sh` | `zx-poas → {zx-core, zx-consensus}`, `zx-farmer → {zx-core, zx-poas}` | §6 V8 |
| `.github/workflows/zerox-ci.yml` | cabecera y nombre del paso de frontera | documentación |

## 4. Decisiones aplicadas

- **D-P12.** `bytes = cuerpo_a_bytes(génesis dev)` (cabecera PoW de 92 B + `CompactSize(n_tx)` +
  la coinbase con testigos); `resize(RecordedHistorySegment::SIZE, 0)`; `ChaCha8Rng::from_seed(
  block_hash(génesis))` y `rng.fill` sobre la cola; `Archiver::new(kzg, erasure_coding).add_block(
  bytes, BlockObjectMapping::default(), false)`; el **primer** `NewArchivedSegment` es el segmento 0.
  `Kzg::new()` y `ErasureCoding` con la escala de `historia_dag_dev`. `history_size = 1`.
- **D-P13 / §3.4.** `zx-poas` y `zx-farmer` no entran en conflicto con `zx-dag`; `zx-farmer` no
  depende de `zx-consensus`.
- **§3.1.** `protocolo_dev` con los valores antiguos, etiquetados **dev** en cada constante.
- **§5.** No se porta PoT, ni flujo, ni AES, ni `N(s)`, ni cabecera. El único préstamo de `pot.rs`
  es la derivación **pura** del reto, declarada en §2.1.

## 5. API entregada

- **`zx_poas::verificador`**: `verificar_solucion_poas(solucion, slot, salida_pot_verificada, rango_validado,
  contexto_pieza, kzg) -> Result<u64, ErrorPoas>`; `ErrorPoas` (`EntradaNoCanonica`,
  `ContextoInvalido(ContextoInvalido)`, `Prueba(subspace_verification::Error)`); `ContextoInvalido`
  con 6 variantes.
- **`zx_poas::historia`**: `HistoriaGenesis` (`construir`, `construir_bruto`, `historial`, `kzg`,
  `erasure_coding`, `segment_commitment`, `protocolo`, `history_size`, `params_pieza`);
  `ErrorHistoriaGenesis` (7 variantes); `COMPROMISO_HISTORIA_GENESIS_DEV`; `comprobar_compromiso`.
- **`zx_poas::protocolo_dev`**: constantes `*_DEV`, `a_tamano_historia`, `parametros`.
- **`zx_poas::reto`**: `ALEATORIEDAD_BYTES`, `aleatoriedad_de_salida`, `reto_desde_salida`.
- **`zx_farmer::farmer`**: `plotear_sector_en_disco`; `ParcelaDisco` (`abrir`, `sector_index`,
  `pieces_in_sector`, `ruta`, `metadata`, `auditar_candidatos`, `auditar_con_reto`, `auditar_slot`);
  `ErrorFarmer` (22 variantes); `ResumenCandidatos`; `VERSION_PARCELA`.
- **`zx_farmer::productor_poas`**: `convertir_candidatos_locales`; `DiagnosticoLocal`;
  `SolucionComprobadaLocal`; `ResultadoConversionLocal`; `ErrorProductorPoas`.

## 6. Extremo a extremo (V5) y negativos (V6)

**V5.** Con `PublicKey = [0x11;32]`, `sector_index = 3`, `pieces_in_sector = 2`, `salida =
[0xa5;16]`, `slot` recorrido desde 0 y rango de prueba `u64::MAX`:

- La historia génesis dev archiva su segmento 0 y **3 soluciones** verifican con
  `verificar_solucion_poas` (la primera en el **slot 0**, distancia `5380497425846111175`); cada una
  vuelve a verificar de forma independiente y su distancia coincide con la devuelta.
- `auditar_con_reto(reto, rango)` coincide con `auditar_candidatos(salida, slot, rango)`.
- En `farmer_disco.rs`, el mismo fixture produce 2 soluciones en el slot 0 (`candidatos: 2`,
  `soluciones_generadas: 2`, `rechazos_a1: 0`).

| V6 (mutación) | Error |
|---|---|
| `proof_of_space = [0;160]` | `ErrorPoas::Prueba(InvalidProofOfSpace)` |
| `chunk[0] ^= 0xFF` | `ErrorPoas::Prueba(InvalidChunk("Invalid scalar"))` |
| `public_key = [0;32]` | `ErrorPoas::Prueba(InvalidProofOfSpace)` |
| `sector_index += 1` | `ErrorPoas::Prueba(InvalidProofOfSpace)` |
| `history_size = 0` | `ErrorPoas::EntradaNoCanonica` |
| `history_size += 1` | `ErrorPoas::Prueba(InvalidProofOfSpace)` |
| `piece_offset ^= 1` | `ErrorPoas::Prueba(InvalidProofOfSpace)` |
| contexto: `segment_commitment = default` | `ErrorPoas::Prueba(InvalidPiece)` |
| contexto: `current_history_size = u64::MAX` | `ErrorPoas::ContextoInvalido(CurrentHistorySizeSinMargen)` |
| contexto: `recent_segments = u64::MAX >> 8` | `ErrorPoas::ContextoInvalido(UmbralRecienteDesborda)` |

## 7. Compromiso congelado

`COMPROMISO_HISTORIA_GENESIS_DEV = 8126fdbed3260227c9beb655673b19545d3e412bf9ad7e8a36daf70e64d33d8ceacdc941ac781e9ce2fa1df529f24af9`.

El test V7 construye la historia **dos veces** por caminos distintos (`construir`, con cotejo, y
`construir_bruto`, sin él), exige que ambos compromisos coincidan y que sean el congelado, y
comprueba que un byte mutado devuelve `ErrorHistoriaGenesis::CompromisoInesperado`.

## 8. Lo que esta orden NO demuestra

- **PoT**: flujo, semilla `f_0`, encadenado AES, inyecciones, `N(s)`, `D` y la derivación del reto
  desde la salida real del slot. Los retos de los tests son valores fijos de 16 B + slot; W05b2.
- **Cabecera** PoST conjunta, sello, cuerpo, DAG, orden, peso y admisión en el nodo.
- **Historia más allá de un segmento**: `history_size = 1`; los bloques posteriores no se archivan
  (IPA A-06) y `recent_segments = 5` queda en la rama no reciente (la aritmética lo comprueba).
- **Parámetros de red**: `history_size`, `max_pieces_in_sector`, `recent_segments`,
  `recent_history_fraction` y `min_sector_lifetime` son valores **dev** de fixture local.
- **Atomicidad del par de parcela**: dos `rename`, no una transacción (se hereda de D1).
- **Procedencia causal del lote** (slot, salida, rango y contexto): la inyecta el llamante; no se
  acredita aquí.
- **Verificación PoAS sobre una solución producida por el propio nodo**: el candidato sale del
  plotter real, pero el contexto causal y la firma no existen todavía.
- **CI en GitHub**: no se ejecutó allí. El workflow documenta además que el clon no se versiona.
- **Idoneidad de la seguridad de PoAS**: verificar correctamente no prueba que el diseño sea
  suficiente.

## 9. Presupuesto y trazas

Presupuesto declarado: **3 h de reloj, 8 hilos, 32 GiB de RAM, 40 GiB de disco**. Consumo real ≈
16 min de reloj. Tamaños: `ws` ≈ 3,4 MiB sin `target` ni clon, `ws.orig` ≈ 3,1 MiB, `cargo-home`
697 MiB, `target` ≈ 3,2 GiB, `ref/` ≈ 164 KiB, `logs/` ≈ 284 KiB; total de la zona ≈ 3,9 GiB.
Toolchain `nightly-2026-05-03`
(`cargo 1.97.0-nightly`, `rustc 1.97.0-nightly`), `CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`,
`RUSTFLAGS=`. **Informativo (no medición, perfil `debug`)**: archivar la historia génesis ≈ 18 s;
plotear el sector ≈ 4,9 s. No se ejecutó perfil `release`.

Artefactos: `ws/`, `ws.orig/`, `cambios.patch` (20 ficheros), `MIGRACION.sha256` (103 huellas),
`logs/` (entrada, lock, V1–V8, nombres, inventario de tests), `INFORME.md`, `PROGRESO.md`,
`HORAS.log`.

## 10. Resumen final (≤ 40 líneas)

1. W05b1 cumple: crates **nuevos** `zx-poas` (verificador PoAS + historia génesis dev + protocolo
   dev + reto) y `zx-farmer` (parcela + auditoría + conversión), portados de `9681061` sin cambio de
   lógica.
2. `verificador.rs` es `zx-consensus/src/poas.rs` **verbatim** (`verificar_solucion_poas`,
   `ErrorPoas`, `ContextoInvalido`).
3. `historia.rs` aplica **D-P12**: `cuerpo_a_bytes(génesis dev)` + relleno `ChaCha8Rng(
   block_hash(génesis))` hasta `RecordedHistorySegment::SIZE` + `Archiver::add_block(.., .., false)`
   + primer `NewArchivedSegment`.
4. `COMPROMISO_HISTORIA_GENESIS_DEV` congelado a `8126fdbe…29f24af9`; V7 lo recalcula dos veces con
   caminos distintos y exige igualdad y cotejo.
5. `protocolo_dev.rs`: `history_size = 1`, `max_pieces_in_sector = 2`, `recent_segments = 5`,
   `recent_history_fraction = (1, 10)`, `min_sector_lifetime = 4`, todos **dev**.
6. `reto.rs`: derivación pura del reto `C-POT-03`, portada a `zx-poas` por la frontera §6 V8.
7. `zx-farmer` usa `CpuRecordsEncoder<ChiaTable>` por la ruta **paralela** y `audit_plot_sync` sobre
   el descriptor verificado, igual que D1.
8. `productor_poas` convierte candidatos con `into_solutions` y verifica con
   `verificar_solucion_poas`; `InvalidHistorySize` se propaga como fallo de contexto.
9. V1 `fmt` OK; V2 `clippy -D warnings` 0 avisos.
10. V3 **415 pasan, 0 fallan, 1 ignorado**; 372 nombres previos intactos, 44 nuevos.
11. V4: 15 portados (`poas.rs`) + 12 adaptados (`farmer_disco.rs`) + 1 retirado
    (`convierte_pot_dev_y_solucion_disco`, PoT de W05b2).
12. V5: **3/3** soluciones del sector ploteado aceptadas; primera en el slot 0.
13. V6: los 10 negativos (6 campos + 2 de solución de historia + 2 de contexto) con su error.
14. V7: compromiso determinista y congelado.
15. V8: 15 dependencias exactas; `zx-poas → {zx-core, zx-consensus}` y `zx-farmer → {zx-core,
    zx-poas}`.
16. `Cargo.lock`: 220 paquetes; +88 pares, **todos** con la versión del lock de `9681061`; ninguna
    versión existente cambia.
17. Clon de Autonomys enlazado en `ws/PDF` (symlink declarado), no migrado.
18. «Lo que NO demuestra»: PoT, cabecera, admisión, historia > 1 segmento, parámetros de red y
    procedencia causal del lote.
19. Veredicto: **SUPERADO**; la pregunta falsable no queda refutada.
