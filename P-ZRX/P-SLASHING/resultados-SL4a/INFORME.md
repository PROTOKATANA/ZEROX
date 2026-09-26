# INFORME — ORDEN-SL4a

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Fecha:** 2026-09-26.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/SL4a/`. **Entrada:** `P-ZRX/P-SLASHING/ENTRADA-SL4a.sha256`
(9/9 hashes en verde al terminar). **Regla:** LINEO rige este código Rust.

## Veredicto

**SUPERADO.** `zx-core` implementa la `EvidenceTx` v4 (`EV-01`…`EV-04`), `zx-consensus::transicion`
las reglas de evidencia (`EV-05`…`EV-22`, `RAT-1`, `RAT-2′`, `RAT-3`) y `zx-cadena` las aplica en el
DAG/fusión con undo exacto (`EV-27`/`EV-28`). Los dos arneses diferenciales reproducen el oráculo
SL-3b **sin ninguna discrepancia y con la tabla de cobertura idéntica**: T01 v0.4 (2 795 casos) y T04
v0.5 (1 878 casos). `crates/zx-node/` no se ha tocado (verificado byte a byte). Se declaran siete
faltas de definición (`DEFINICIONES-FALTANTES.md`) y una octava encontrada al implementar (FD-8).

## Tabla V1–V6

| Paso | Qué | Resultado |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | **OK** |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** |
| V3 | `cargo test --workspace --all-features --locked` | **OK** — **729 pasan, 0 fallan, 2 ignorados** (721/0/2 antes de la orden; +8 tests nuevos de V5, 0 perdidos). Log: `logs/test-workspace-final.log` |
| V4a | `diferencial_t01` (v0.4, 2 795 casos) | **0 discrepancias**; cobertura **idéntica** a `cobertura-v0.4.txt` |
| V4b | `diferencial_t04` (v0.5, 1 878 casos) | **0 discrepancias**; secciones `vectores-v0.5` y `evidencia SL-3b` **idénticas** a `cobertura-v0.5.txt` |
| V5 | tests propios | `zx-consensus/tests/evidencia.rs` **8/8** (RAT-3/ventana, autodenuncia, `cbid` ajeno, orden canónico, sellos, duplicada en hermanos, undo/reaparición, con salidas) |
| V6 | `dependencias-exactas.sh` (23 exactas) y `frontera-crates.sh` (9/9); `Cargo.lock` idéntico a la raíz | **OK** |

La sección `run.jl` de `cobertura-v0.5.txt` **no** se reproduce desde el fichero de vectores: la
genera otro `run.jl` (seed `0x5a5a`, 200 réplicas) que no está en la entrada congelada. Se comparan
las dos secciones que sí salen de `vectores-estado-dag-v0.5.txt`.

## Qué se implementó

### `zx-core` — formato (`EV-01`…`EV-04`)
- `ExtensionTx::Evidencia { h1, h2 }`: exactamente dos cabeceras `PoAS_PoT_DAG` completas.
- `validar_forma_tx_v4`: coherencia `4 ⇔ Evidencia`, sin entradas/salidas/testigos, `lock_time = 0`,
  `expiry_height = 0`, cada cabecera con forma F-03. La puerta de activación (`evp`) la aplica el
  motor (el parser es sin contexto, FD-4).
- `extension_digest` de la v4: `H_d("ZZKTxIdEvidencia", dag_header_a_bytes(H1) ‖ dag_header_a_bytes(H2))`
  (`EV-03`), que entra en el `txid`. Dos etiquetas nuevas en `TAGS_FIJAS` (19): `dom_txid_evp` y
  `dom_incidente`.
- `incident_id_evidencia`: `H_d("ZZKEvpIncidente_", cbid ‖ pk ‖ sector ‖ history ‖ chunk ‖ slot)`.
- `TAGS_FIJAS` pasa de 17 a 19 con su test de unicidad e invariante de prefijo de la raíz.

### `zx-consensus::transicion` — reglas
- `ParametrosEvidencia` (SL-4a): `f_num`, `f_den`, `plazo_slots`, `m_margen_slots`, `cbid`, `evp`.
  Se mantiene fuera de `ParametrosTransicion` para no tocar `zx-node` (FD-8).
- `Garantia.incidentes: Vec<Incidente>` (`id` de 32 B y `slot_falta` `i64`) y
  `Estado.ultimo_slot_producido`, restaurado por el undo exacto.
- `aplicar_evidencia` reproduce el **orden exacto** del oráculo: `ErrSinEvidencia` (sin cabeceras),
  `ErrEvidenciaConEntradas` (forma), `ErrCbidAjeno` (RAT-1), `ErrSinEvidencia` (identidad distinta),
  `ErrOrdenCanonico`, `ErrSinEvidencia` (sellos), `ErrPuertaRAT3` (RAT-3), `ErrEvidenciaTardia`
  (EV-13/14), `ErrEvidenciaDuplicada` (EV-12), registro del incidente (EV-11), congelación (EV-17),
  confiscación `C = mín(V, techo(f·V))` (EV-19), recompensa `suelo(C·2/8)` al productor (RAT-2′) y
  quema del resto; `congelado` es gravamen derivado y el remanente se fija tras el débito (EV-20).
- `debitar_garantia` en orden `activo → pendientes → en_retirada → créditos` (EV-19/EV-20).
- `podar_incidentes` usa el **punto de aplicación** en modo fusión (corrige el único fallo real que
  el diferencial T04 destapó, caso 972).
- EV-24(i) (`ErrCasoAbierto`) y EV-24(ii) (`ErrVentanaAbierta`, con `plazo + margen` desde
  `ultimo_slot_producido`) en la liberación; el retiro no se bloquea.
- `deshacer` restituye `ultimo_slot_producido` y las garantías (con incidentes y congelado).

### `zx-cadena` — DAG
- `Cadena::nueva_con_evidencia` (la firma de `nueva` no cambia) y paso de los parámetros a
  `aplicar`/`aplicar_fusion` en admisión, historia virtual, cadena y recomputación.
- La evidencia se aplica en modo fusión y, si no valida, se **descarta** sin invalidar el bloque
  (`ErrEvidenciaDuplicada`, `ErrEvidenciaTardia`, `ErrCbidAjeno`, …), con undo exacto.

### Arneses diferenciales
- `diferencial_t01` lee `testdata/transicion-v0.4/` y traduce cada `ev=` a dos cabeceras reales con
  sellos Ed25519 reales; el orden canónico real por `pre_hash` se ajusta con una sal. Reproduce los
  7 contadores de `cobertura-v0.4.txt`.
- `diferencial_t04` lee `testdata/estado-dag-v0.5/` con el mismo traductor, **slots negativos** del
  generador tardío incluidos, y reproduce la sección general y los 7 contadores `EV`. Compara el
  `incident_id` como opaco (multiconjunto de `@slot_falta`).

## Faltas de definición (resueltas y declaradas)

Las siete de `DEFINICIONES-FALTANTES.md` más:

- **FD-8 · parámetros de evidencia y `zx-node`:** añadirlos a `ParametrosTransicion` habría obligado
  a editar `crates/zx-node/src/perfil.rs` y `crates/zx-node/tests/padres_maximos.rs`, prohibido. Se
  crea `ParametrosEvidencia` y se pasa por parámetro; el nodo sigue inactivo hasta SL-4b.

Decisiones declaradas que un tercero debe conocer:

- **`incident_id` (FD-1):** el contrato (`H_d`) y el oráculo (`sha256` decimal) no coinciden. El motor
  implementa el contrato; el arnés compara el id como opaco. Ningún contador de cobertura depende del
  hex.
- **`ErrCbidAjeno` (FD-2):** se sigue el oráculo, no el `ErrForma` literal de RAT-1.
- **Slots negativos:** el motor mide la ventana en `i64` para reproducir el generador tardío de T04;
  en producción los slots son `u64` no negativos.
- **Wire de la v4 (FD-5):** `tx_a_bytes` escribe `H1 ‖ H2`; `tx_desde_bytes` sigue rechazando la v4.
  No afecta al diferencial, que construye las `Tx` tipadas.

## No demostrado

- La `run.jl` de `cobertura-v0.5.txt` (no está en la entrada congelada) y la calibración de
  `Plazo_slots`/`M_margen_slots` (SL-2): el perfil de pruebas usa valores que cumplen la puerta RAT-3.
- El firmante seguro, la detección y el envío de evidencia (`zx-node`, SL-4b).
- El códec de wire de la v4 (round-trip `tx_desde_bytes`).
- La igualdad byte a byte del `incident_id` con el oráculo (FD-1); sí se demuestra la equivalencia
  estructural (número de incidentes y `slot_falta`).

## Cómo reproducir

```bash
source /home/katana/zeo/ZEROX/deepseek/SL4a/env.sh
cd "$Z/ws"
cargo test --workspace --all-features --locked
cargo test -p zx-consensus --test diferencial_t01 --locked -- --nocapture
cargo test -p zx-cadena --test diferencial_t04 --locked -- --nocapture
```

Logs completos en `logs/`: `t01-run2.log`, `t04-run5.log`, `evidencia2.log`,
`test-workspace-final.log`, `clippy4.log`, `dependencias-exactas.log`, `frontera-crates.log`.
