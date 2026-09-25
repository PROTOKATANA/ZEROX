# Decisiones del director para W05 (DAG, PoT y PoAS anclados al terminal PoW)

**Fecha:** 2026-09-26. **Firma:** Claude. **Insumo:** mapa de adaptación de un subagente Sonnet de
solo lectura (resumen abajo), con sus tres afirmaciones centrales **comprobadas por el director** en
`9681061`: `ghostdag.rs:491-499` (`AlmacenGhostdag::nuevo(params, algoritmo, id_genesis, slot_genesis,
sr_genesis, ident_genesis)` acepta cualquier raíz), `bloque_dag.rs:294-322` (`count() == 0 ⟺
es_genesis`; el padre seleccionado debe estar validado en el contexto) y `pot_rango.rs:555-572`
(rama de génesis explícita: `PortadoresEnGenesis`, `GenesisSinEntropiaExterna`).

## Decisiones

| ID | Decisión | Motivo | Se revierte si |
|---|---|---|---|
| D-P07 | La raíz de GHOSTDAG es el terminal: `AlmacenGhostdag::nuevo(…, id_genesis = block_hash(T), slot_genesis = s_0 = 0, sr_genesis = SR_dev, ident_genesis = 0)`, `blue_work` 0 | D-T02; el constructor ya lo admite sin cambio de lógica | — |
| D-P08 | **No hay génesis DAG.** Una cabecera PoST con 0 padres es inválida. `ContextoDag::es_genesis` se sustituye por `es_terminal`; el bloque de transición tiene exactamente un padre, `T`, que el contexto da por validado (lo validaron W04/W03); ningún bloque PoST puede tener como padre un bloque PoW distinto de `T`, ni `T` como padre adicional | D-T02, TRN-06 | — |
| D-P09 | Contexto PoT inicial: `pasado = [{hash: block_hash(T), slot: 0, flujo: f₀}]` con `f₀ = H_flujo(ETIQUETA_GENESIS ‖ block_hash(T))` y `semilla(f₀, 0) = blake3(block_hash(T) ‖ entropía_externa)[0..16)` de `C-FLU-06`, con **`entropía_externa` vacía en la red dev**. Es la instancia concreta del marcador S1 de TRN-08; la salida confiada del slot 0 es esa semilla | Reutiliza la fórmula existente (`pot.rs:278`) sustituyendo el génesis por `T`; A-07 sigue abierto | Resultado de T03 (sesgo) |
| D-P10 | Perfil PoT dev: un solo flujo, sin inyecciones, `D = 0`, `N(s) = N_dev` constante configurable por red dev (valor de prueba pequeño en tests; valor de red calibrado por medición en W07) | Dev explícito; C-FLU-07… y el controlador de `N` siguen pendientes | — |
| D-P11 | `SR` (rango de solución) de la red dev: constante configurable (`C-HDR-06` sin controlador); valor calibrado en W07 | El controlador de rango derivado del pasado no existe | Cuando exista controlador |
| D-P12 | Historia plotable dev: **un segmento** obtenido con el `Archiver` real de Autonomys sobre `wire(génesis) ‖ relleno` hasta `RecordedHistorySegment::SIZE`, relleno con `ChaCha8Rng` sembrado con `block_hash(génesis)` (patrón de Autonomys `archiver.rs:515-541`, que siembra con el `state_root`), `add_block(bytes, BlockObjectMapping::default(), false)`, primer `NewArchivedSegment`. `history_size = 1` durante toda la red dev 0.0.1; los bloques posteriores **no** se archivan en 0.0.1 (IPA A-06 sigue abierto) | Sustituye el fixture splitmix64 por historia derivada de la cadena | A-06 |
| D-P13 | Crate nuevo **`zx-dag`** (depende solo de `zx-core`) con GHOSTDAG, comprobación contextual de padres, rango validado y vista causal; `zx-consensus` dependerá de él | Frontera limpia y evita conflictos de parche con W03 (`zx-consensus`) | — |

## Órdenes

- **W05a** (`P-ZRX/P-DAG/ORDEN-W05a.md`): `zx-dag` = `ghostdag.rs`, `bloque_dag.rs` (con D-P08),
  `dag_causal.rs`, con sus tests y los vectores de los oráculos GHOSTDAG copiados a `testdata/`.
- **W05b** (por redactar tras W05a y W03): `pot.rs`, `pot_rango.rs` (sin la rama de génesis),
  `poas.rs`, `cabecera_conjunta.rs`, `contexto_transicion` (D-P09…D-P11), historia génesis (D-P12),
  y la prueba de extremo a extremo «primer bloque PoST real hijo de un terminal dev».

## Riesgos heredados (del mapa, verificados donde se cita línea)

`C-HDR-02` (altura DAG) y `C-HDR-06` (controlador de rango) siguen sin resolver; `C-FLU-13/14` solo
comprueban consistencia de flujo; `past(B)` validado no lo acredita ningún índice todavía (W06);
`PieceCheckParams` pasa a depender de la historia y reabre `InvalidHistorySize` como `Pendiente`.
