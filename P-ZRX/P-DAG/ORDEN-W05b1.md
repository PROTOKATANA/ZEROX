# ORDEN-W05b1 — Crates `zx-poas` y `zx-farmer`: historia génesis, verificador PoAS y granjero real

## 1. Identidad y contexto

- **ID:** W05b1. **Estado:** redactada 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W05b1/`.
- **Objetivo único:** portar el verificador PoAS y el granjero (ploteo y auditoría) del commit
  `9681061` a dos crates nuevos, sustituyendo la historia de fixture por la **historia derivada del
  génesis dev** (D-P12), y demostrar de extremo a extremo que un sector ploteado sobre esa historia
  produce soluciones que el verificador real acepta.
- **Pregunta falsable:** «Con la historia de un segmento derivada del génesis dev de W04, un sector
  ploteado con el plotter real produce, para algún reto, una solución que `verify_solution` de
  Autonomys `f8842d0` acepta con los `PieceCheckParams` de esa historia, y rechaza las soluciones
  alteradas de §6.» Se refuta con un rechazo de una solución honesta o una aceptación de una alterada.
- **Desbloquea:** W05b2 (PoT + puerta conjunta del bloque de transición) y W06 (productor del nodo).

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-DAG/DECISIONES-W05.md` (D-P12, D-P13);
`P-ZRX/P-FORMATO/FORMATO-v0.md` §3; `P-ZRX/P-TRANSICION/CONTRATO-v0.md` D-T05 (contexto).
Base: workspace de la raíz (con `zx-core`, `zx-pot`, `zx-consensus` de W04; `zx-dag` puede estar
migrándose en paralelo: **no dependas de él**). El clon de Autonomys está en la raíz en
`PDF/autonomys-subspace` (`f8842d019cdf…`), preparado por el director, ignorado por git; **no lo
modifiques**; puedes copiarlo a tu zona si la compilación lo exige y declararlo.
Código antiguo (solo lectura, `git -C /home/katana/zeo/ZEROX show 9681061:<ruta>`):
`crates/zx-consensus/src/poas.rs`, `crates/zx-consensus/tests/poas.rs`,
`crates/zx-node/src/{farmer.rs, productor_poas.rs, historia_dag_dev.rs}`,
`crates/zx-node/tests/farmer_disco.rs`, `crates/zx-node/Cargo.toml` y `Cargo.toml` raíz (lista
`exclude` y dependencias por ruta del clon). Fuente del relleno del génesis:
`PDF/autonomys-subspace/crates/sc-consensus-subspace/src/archiver.rs:470-541`.
Entrada congelada: `P-ZRX/P-DAG/ENTRADA-W05b1.sha256` (no incluye el contrato, que se está actualizando), al empezar y como último paso.

## 3. Decisiones ya tomadas por el director

1. **`crates/zx-poas`** (depende de `zx-core`, `zx-consensus` para el génesis dev de W04, y de los
   crates de Autonomys por ruta al clon, como en `9681061`): `verificador.rs` = `poas.rs` antiguo sin
   cambio de lógica (`verificar_solucion_poas`, `ErrorPoas`, `ContextoInvalido`); `historia.rs` =
   `HistoriaGenesis` según D-P12 (ver punto 3); `protocolo_dev.rs` = `FarmerProtocolInfo` dev con los
   valores antiguos (`history_size = 1`, `max_pieces_in_sector = 2`, `recent_segments = 5`,
   `recent_history_fraction = (1, 10)`, `min_sector_lifetime = 4`), todos etiquetados **dev**.
2. **`crates/zx-farmer`** (depende de `zx-poas`, `zx-core` y Autonomys): `farmer.rs` y
   `productor_poas.rs` antiguos sin cambio de lógica (plot con `CpuRecordsEncoder<ChiaTable>` por la
   ruta paralela, auditoría con `audit_plot_sync`, conversión de candidatos a `Solution`), apuntando a
   `HistoriaGenesis` en vez de `HistoriaDagDev`.
3. **Historia génesis (D-P12), exactamente:** `bytes = cuerpo_a_bytes(génesis dev)` (codificación de
   red de `zx-core::wire`: cabecera de 92 B + transacciones con testigos) rellenado hasta
   `RecordedHistorySegment::SIZE` con `rand_chacha::ChaCha8Rng::from_seed(block_hash(génesis))`
   llamando a `fill` sobre los bytes que faltan (mismo patrón que `archiver.rs:524-541`, que siembra
   con el `state_root`); `Archiver::new(kzg, erasure_coding).add_block(bytes,
   BlockObjectMapping::default(), false)`; el **primer** `NewArchivedSegment` es el segmento 0.
   `Kzg::new()` y `ErasureCoding` como en `historia_dag_dev.rs`. Su `segment_commitment` se **congela**
   en una constante `COMPROMISO_HISTORIA_GENESIS_DEV` con un test que lo recalcula. `rand_chacha`
   `=0.9.0` (ya en el lock antiguo); si Autonomys usa otra versión para su relleno, **no** la sigas:
   la nuestra es una definición propia, declárala.
4. **Lista `exclude` y dependencias por ruta:** como en el `Cargo.toml` raíz de `9681061` (los crates
   del clon no son miembros del workspace).
5. **Nada de PoT ni de cabecera** en esta orden: los retos de auditoría son valores de prueba de 32 B
   fijados en los tests (la derivación desde PoT es de W05b2).

Si algo no se puede cumplir tal cual, **para** e infórmalo antes de improvisar.

## 4. Contrato de ejecución

Patrón W02/W04 (`ws.orig/`, `ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md`,
`PROGRESO.md`, `HORAS.log`). La copia de trabajo `ws/` incluye un enlace o copia del clon en
`ws/PDF/autonomys-subspace` para que las rutas relativas resuelvan (declara cuál; el director no
migrará `PDF/`). Caché de cargo copiable de `deepseek/L01/.cargo-home` (ya tiene las dependencias de
Autonomys). `CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`, `RUSTFLAGS=`. `Cargo.lock`: las versiones de
todos los paquetes nuevos deben ser **las del `Cargo.lock` de `9681061`**; demuéstralo
(`logs/lock-subconjunto.txt`) y ninguna versión existente cambia.

## 5. Modelo de amenaza

Soluciones alteradas por un productor hostil (ver §6); contexto de pieza falso (compromiso o
`history_size` que no son los de la historia). Ningún pánico en código no de test.

## 6. Plan de verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo pasa con su nombre + lo nuevo |
| V4 | Tests antiguos portados: `tests/poas.rs` (15, con su fixture sintético propio) y `farmer_disco.rs` (13) adaptados a `HistoriaGenesis` | lista portados/adaptados/retirados con motivo |
| V5 | Extremo a extremo: génesis dev → historia → plot de 1 sector con una clave dev → auditar retos de prueba hasta hallar ≥ 3 soluciones → `verificar_solucion_poas` acepta las 3 | 3/3 |
| V6 | Negativos: `chunk`, `proof_of_space`, `public_key`, `sector_index`, `history_size`, `piece_offset` alterados; `PieceCheckParams` con otro compromiso o `history_size` | cada uno rechazado con su error |
| V7 | `COMPROMISO_HISTORIA_GENESIS_DEV` recalculado dos veces (determinismo) | igual |
| V8 | `bash ci/dependencias-exactas.sh`, `bash ci/frontera-crates.sh` (actualízalo: `zx-poas → {zx-core, zx-consensus}`, `zx-farmer → {zx-core, zx-poas}`) | OK |

Informativo (no medición): tiempo de construir la historia y de plotear el sector, perfil `release`
si lo necesitas para el presupuesto (declárelo). **Prohibido Python.** Presupuesto: **3 h, 8 hilos,
32 GiB, 40 GiB de disco**.

## 7. Entregables y límites

`ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md` (veredicto; API; tests portados;
compromiso congelado; «Lo que esta orden NO demuestra»: PoT, cabecera, admisión, historia más allá
de un segmento, parámetros de red), `PROGRESO.md`, `HORAS.log`. Resumen final ≤ 40 líneas. DeepSeek
`deepseek-flash`, esfuerzo `high`; LINEO antes del código; sin Python; nada fuera de la zona; sin
commit ni push; sin secretos; ningún `Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W05b1 && cd /home/katana/zeo/ZEROX/deepseek/W05b1 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W05b1. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-DAG/ORDEN-W05b1.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W05b1-dsh.stdout 2> ../W05b1-dsh.stderr )
