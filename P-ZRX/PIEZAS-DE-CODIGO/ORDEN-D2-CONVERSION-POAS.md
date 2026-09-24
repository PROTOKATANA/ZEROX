# Orden D2 parcial · de candidatos de disco a soluciones verificadas

## Modelo y límites

Escribe código con `deepseek-v4.1-flash`, esfuerzo `high`, mediante DeepSeek Harness. Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `PROMPT.md`, `ORDEN-D1-PLOTTER-AUDITOR.md`, `veritas/LINEO.md` íntegro antes del test de cálculo, secciones aplicables de `SPEC.md` (`C-POT-03/05/08`, `C-GD-10/11`, `C-HDR-03/09`) y el código exacto de D1, A1 y upstream. No hagas commit ni push. No edites `SPEC.md`, `research/`, `veritas/`, `PDF/`, CI ni el resto de `P-ZRX/`.

Archivos permitidos: `crates/zx-node/Cargo.toml`, `crates/zx-node/src/lib.rs`, `crates/zx-node/src/productor_poas.rs` nuevo y `crates/zx-node/tests/farmer_disco.rs` para reutilizar el fixture real de D1. `Cargo.lock` solo si Cargo necesita registrar la dependencia directa `subspace-verification` ya presente por A1; inspecciona el diff y no muevas versiones ajenas.

## Contrato

D2 completo exige elegir padres del DAG validado **antes** de derivar salida de slot, SR y contexto de pieza; el filtro C-GD-11 y bootstrap C-GEN-02 siguen pendientes. Por ello esta orden implementa **solo la conversión local**, sin firma, ensamblado, admisión, red ni publicación. El módulo debe declararse parcial y no llamarse productor activo. Entrada `salida_slot`, `slot`, `rango_validado` y `PieceCheckParams` es un lote coherente **inyectado por un futuro snapshot causal**; la función no acredita esa procedencia. No aceptar datos del bloque candidato como contexto validado. La API debe devolver resultados tipados como `SolucionComprobadaLocal`, con campos privados y distancia, que indiquen explícitamente que se verificaron **contra las entradas proporcionadas**, no validez global.

Implementa una función pública de la feature `farmer` que:

1. Llama `ParcelaDisco::auditar_candidatos(salida_slot, slot, rango_validado)` y conserva los préstamos de `&ParcelaDisco`/`File` durante toda la conversión.
2. Para cada `AuditResult`, consume `solution_candidates.into_solutions::<(), ChiaTable, _>` de la API Autonomys, con `ReadSectorRecordChunksMode::ConcurrentChunks`, `Kzg`/`ErasureCoding` recibidos y generador **paralelo** `ChiaTable::generator().generate_parallel(seed)`; no usa ruta no paralela de `ab-proof-of-space`.
3. Convierte cada `Solution<()>` campo a campo a `zx_core::SolucionPoas` (usar la conversión comprobada de `history_size` y wrappers que ya ejemplifica `zx-consensus/tests/poas.rs`). Llama `zx_consensus::poas::verificar_solucion_poas` con **el mismo** slot, salida, rango y `PieceCheckParams`. Devuelve solo pares `(SolucionPoas, distancia)` que pasaron A1. Un candidato falso positivo puede descartarse con motivo de prueba; un error de I/O, `into_solutions`, contexto aritméticamente inválido o conversión no representable debe propagarse como error, no confundirse con «sin solución». No medir peso GHOSTDAG a partir de distancia.
4. Separa contadores de candidatos, soluciones generadas, falsos positivos A1 y soluciones verificadas para diagnóstico **local**, sin declararlos F1–F3 ni métricas de red. No inventar SR/D/N(s) en el código.

## Prueba decisiva

Reutiliza `fondo()`/`instalar_par()` del test D1, que usa `Archiver` real, `plot_sector` y bytes persistidos. Construye `PieceCheckParams` desde `fondo().historial.segment_header.segment_commitment()` y `fondo().protocolo`, etiquetados como fixture de desarrollo, no parámetros de red. Barre slots con un límite de test explícito hasta obtener al menos una **solución verificada por A1**; falla con mensaje si no aparece, sin fabricar prueba. Comprueba que `verificar_solucion_poas` rechaza al menos una mutación de prueba de la solución devuelta y que la función nunca devuelve esa mutación como válida. Un contexto de pieza incompatible debe producir cero soluciones válidas o error explícito, según el error concreto, sin aceptación. El test debe fallar si se elimina `into_solutions` o A1. Mantén coste razonable y reporta el tiempo/hilos/RAM del fixture si lo observas; no presentes frecuencias del fixture como red real.

## Comprobación

`cargo test -p zx-node --features farmer --locked --test farmer_disco`, `cargo test -p zx-node --locked`, `cargo clippy -p zx-node --all-targets --features farmer --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/frontera-crates.sh`, `ci/dependencias-exactas.sh`, `git diff --check`. Informa `ci/alcance-consenso.sh` honestamente si sigue rojo por inventario textual de A3/D1.
