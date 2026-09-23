# PROCEDENCIA — espacio-tasa-v1

Toda cita `archivo:línea` de este instrumento se abrió y se leyó. Las huellas exactas están en
`resultados/FUENTES-AUTONOMYS.sha256` y `resultados/FUENTES-ZEROX.sha256`.

## 1 · Fuentes de ZEROX (documentos de contrato)

| Documento | Qué se tomó |
|---|---|
| `AGENTS.md`, `CLAUDE.md` | Alcance, prohibición de auditorías Python, LINEO obligatorio, zona de escritura. |
| `README.md` | Estado real: no existe nodo PoST + DAG; `zx-pot` no cableado. |
| `MIGRACION.md` | Parámetros como referencia de investigación, no configuración congelada; cabecera DAG redactada pero no integrada. |
| `SPEC.md` | **C-HDR-06** (`rango_solucion` contextual, prohibición de circularidad), **C-FLU-13/14** (validez absoluta, pasado consistente de flujo), **C-GD-01** (`w(B)=⌊2^128/(SR+1)⌋`, enteros, prohibida la coma flotante), **C-GD-08** (acumuladores; `blue_work` suma solo azules), **C-GD-02** (dominio `u256`), **§7.1 / C-POT-07/08** (orden de validación, caché por contexto, el reto se deriva del slot en el paso 5). |
| `veritas/LINEO.md` | Leído **íntegro** (627 líneas) antes de escribir código: estructura de proyecto, jerarquía de optimización, presupuesto, contrato de publicación. |
| `research/README.md` | Clasificación de evidencia histórica; no es autoridad. |
| `P-ZRX/P-CRP/auditoria/DEFECTOS.md`, defecto **C1** | El puente espacio → tasa **no existía**: `grep -rni "chunk\|sector\|distancia\|solution_range\|ganador"` daba 0 líneas en CRP-v0.2/v0.3. Todas las α de aquellos instrumentos eran **tasas por slot**, no fracciones de espacio. Esta es la pregunta del encargo. |
| `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` | **Advertencia inicial** (líneas 32-36): «El puente espacio → tasa **no existe** en ningún instrumento del repositorio»; todo F2 está **condicionado a H-PUENTE**. Modelo de `α`, `β_d`, `β_x` como fracciones de espacio. |
| `P-ZRX/P-PUERTA/veritas/consenso/puerta-cobertura-v1/MODELO.md` y `src/peso.jl` | Modelo del peso en enteros exactos: `A(SR)`, `w(SR)`, cancelación del `SR`, residuo de paridad, `rango_de_piezas` como port de `pieces_to_solution_range`, balance H-BETA. Se **cita** y se **reejecuta** como control analítico; no se heredan cifras. |
| `P-ZRX/P-INTENTO/investigacion/INFORME.md` | §2 Precisión 3 (**distribución de ocupación no uniforme**, media 0,5 exacta) y §11 (modelo sin precios, `N_eq = r·w·τ`). También **§13** (SIGSEGV reproducible de `create_proofs`), que este instrumento reprodujo por otra vía (§5 de este documento). |
| `P-ZRX/P-COBERTURA/investigacion/INFORME.md`, §2.4 y §7 | **Límite de preexistencia**: «Hoy **nada** la acredita»; `verify_solution` deriva el `sector_id` de la propia solución y no lo contrasta con nada. El formato **no** acredita que el granjero conserve la parcela completa. |

## 2 · Fuente fijada de Autonomys

- **Clon:** `/home/katana/zeo/fuentes/subspace` — usado como **dependencia por ruta** para el
  oráculo Rust. No se copió ni se modificó una línea; el árbol quedó limpio
  (`git status --short` → 0 líneas) antes y después.
- **Copia de lectura:** `PDF/autonomys-subspace/`, mismo commit. Comprobado por huella: el
  `sha256` de `crates/subspace-verification/src/lib.rs` es idéntico en las dos
  (`a2a682d20b793136b9dd12919527c06af657415e3e2de965baf1afcccda6d00e`).
- **Revisión:** `f8842d019cdf0f7163421b9644db5a9ff82b2a73`, de `2026-08-18 18:45:31 +0530`
  («Bump client versions to 0.1.12 and h2 to 0.4.16 (#3906)»). Es el **mismo** commit que
  `crates/zx-pot` (`MIGRACION.md`) y que el banco de P-INTENTO.
- **No se adoptan parámetros de la red Autonomys como parámetros de ZEROX.** Los valores `(1,6)`
  de `SLOT_PROBABILITY` y `1000` de `MAX_PIECES_IN_SECTOR` se usan **solo** como escenario de
  calibración para traducir bytes a `SR`; se declaran como tales en cada tabla.

### Reglas leídas, con su línea exacta

| Regla | Fuente | Contenido fijado |
|---|---|---|
| Predicado de aceptación | `crates/subspace-verification/src/lib.rs:150-158` | `solution_distance <= solution_range / 2` (división entera) |
| Distancia | `crates/subspace-core-primitives/src/solutions.rs:330-337` | `bidirectional_distance` con `wrapping_sub` en las dos direcciones y `min` |
| `audit_chunk` | `crates/subspace-verification/src/lib.rs:118-131` | `blake3_keyed(sector_slot_challenge, chunk)`, primeros 8 B **LE** |
| `sector_slot_challenge` | `crates/subspace-core-primitives/src/sectors.rs:117-123` | `SectorId XOR global_challenge`, 32 B |
| s-bucket auditado | `crates/subspace-core-primitives/src/sectors.rs:32-39` | dos primeros bytes **LE**; `NUM_S_BUCKETS = 2^16` |
| `SectorId` | `sectors.rs:61-67` | `blake3_keyed(public_key_hash; sector_index_le ‖ history_size_le)` |
| Semilla de evaluación | `sectors.rs:126-129` | `blake3_list([sector_id, piece_offset_le])` |
| Auditoría de un sector | `subspace-farmer-components/src/auditing.rs:198-271` | un bucket por reto; se leen los chunks del s-bucket; cada chunk ganador es un `ChunkCandidate` |
| `rank/select` del bucket | `shared/ab-proof-of-space/src/lib.rs:63-84` | byte `b/8`, bit `b%8` LSB-first; índice denso por `popcount` |
| `create_proofs` | `shared/ab-proof-of-space/src/chiapos.rs:195-268` | **corta** al alcanzar `NUM_CHUNKS = 32768` pruebas, recorriendo buckets en orden creciente |
| Chunk almacenado | `subspace-farmer-components/src/plotting.rs:615-680` | `record_chunk XOR blake3(proof)`; intercalado fuente/paridad, bucket par → fuente |
| Tamaño de sector | `subspace-farmer-components/src/sector.rs:27-53`, `:139-152`, `:174`, `:362-364` | `piezas·1_048_576 + piezas·128 + (piezas·8_192 + 32) + 32`. Los 128 B por registro son `commitment` 48 + `witness` 48 + **`piece_checksum` 32** (`RecordMetadata::encoded_size()`, `sector.rs:148-152`). Contraste con la API: `resultados/constantes.tsv` (`sector_size(1000) = 1 056 896 064`). |
| `NUM_CHUNKS`, `NUM_S_BUCKETS`, `Record::SIZE` | `subspace-core-primitives/src/pieces.rs:561-570` | `2^15`, `2^16`, `1_048_576` |
| Metadata de sector **fuera** del plot | `sector.rs:91-93` y `checksum.rs:99-108` | `SectorMetadataChecksummed::encoded_size() = 131 116 B`: `sector_index` 2 + `pieces_in_sector` 2 + `s_bucket_sizes` 65 536·u16 = 131 072 + `history_size` 8 + checksum 32. **No** forma parte del fichero de la parcela. |
| Tasa de código de borrado | `subspace-core-primitives/src/segments.rs:515` | `(1, 2)` → `NUM_S_BUCKETS = 2·NUM_CHUNKS` |
| `pieces_to_solution_range` | `solutions.rs:30-40` | `MAX / den · num / NUM_CHUNKS · NUM_S_BUCKETS / piezas` |
| `SLOT_PROBABILITY`, `MAX_PIECES_IN_SECTOR` | `subspace-runtime-primitives/src/lib.rs:48`; `subspace-runtime/src/lib.rs:125` | `(1,6)`; `1000` |
| Escalares (`SAFE_BYTES`) | `shared/subspace-kzg/src/lib.rs:123-130` | big-endian, byte 0 reservado; los 31 bytes útiles van en `1..32` |

## 3 · Contraste con la copia de lectura

El oráculo **no** reimplementa primitivas: usa `Tables::<20>::create_proofs_parallel`,
`ErasureCoding::extend`, `blake3_hash_with_key`, `bidirectional_distance` y
`is_within_solution_range` del clon. Lo único que recompone es la **secuencia** de operaciones del
plotter y del auditor; esa recomposición es la referencia independiente, y se contrasta en cada
muestra (si discrepa, el programa **falla** en vez de promediar). Resultado:
`resultados/vectores.tsv` (byte order y predicado), `resultados/vectores-meta.tsv`
(`buckets_contrastados_rank_select = 65536`).
