# INFORME.md — ORDEN-W03

**ID:** W03. **Motor de estado de la transición en Rust, con diferencial contra el oráculo T01.**
**Ejecutor:** DeepSeek Harness, `deepseek-flash`, esfuerzo `high`. **Zona única:**
`/home/katana/zeo/ZEROX/deepseek/W03/`.

## 1. Veredicto

**SUPERADO** en V1–V7.

- **V1** `cargo fmt --all -- --check`: limpio (`logs/V1-fmt.log`).
- **V2** `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: limpio
  (`logs/V2-clippy.log`).
- **V3** `cargo test --workspace --all-features --locked`: **385 pasan, 0 fallan, 1 ignorado**
  (`logs/V3-test.log`). Ningún nombre de test previo desaparece: los cambios en `zx-core` son dos
  derivas (`Ord`) y en `zx-consensus` un módulo nuevo.
- **V4** `diferencial_t01`: **0 discrepancias en los 2 055 casos** (55 dirigidos + 2 000 aleatorios;
  1 947 con sufijo PoST), 176,5 s (`logs/V4-diferencial.log`, `logs/diferencial-tercera.log`).
- **V5** Tests unitarios propios: 8 nuevos en `src/transicion/tests.rs` (testigo real, depósito con
  cambio F-07, MultiSig, coinbase PoW sin salidas, dos coinbases, coinbase PoST en posición 2,
  `clave ≠ productor`, y los cuatro descartes/recorte de fusión); 76 tests de la lib pasan.
- **V6** `transicion_prop.rs` con `proptest` (`RngSeed::Fixed(0x5a5a)`, 64 casos): undo exacto,
  `I-1`, `I-1b` y determinismo; 2 propiedades verdes.
- **V7** `bash ci/dependencias-exactas.sh`: `OK — 10 dependencias con versión exacta`
  (`logs/V7-deps.log`). `Cargo.lock`: **una sola línea añadida** (`"ed25519-zebra"` en la lista de
  dependencias de `zx-consensus`) y **cero cambios de versión** (`diff ws.orig/Cargo.lock
  ws/Cargo.lock`).

**Incidente en la comprobación FINAL de la entrada congelada.** Al empezar (02:32) los 7 ficheros de
`ENTRADA-W03.sha256` coincidían. Al terminar (02:56), 6/7 coinciden y
`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` **falla**: pasó de `823984e8…` a `614dc72a…`. La causa es
**externa a W03**: la orden T04, ejecutándose en paralelo, reescribió ese contrato (RD-1…RD-10) y lo
dejó en el commit `aa2866f`. W03 **no ha escrito nada fuera de `deepseek/W03/`**; el diff de W03
(`cambios.patch`) no toca ese fichero. El detalle literal está en `logs/entrada-final.log`.

## 2. Diferencial por nombre de caso (V4)

| Caso | Casos | Con discrepancia | Caso | Casos | Con discrepancia |
|---|---:|---:|---|---:|---:|
| X-01 | 3 | 0 | X-11b | 3 | 0 |
| X-02 | 3 | 0 | X-11c | 3 | 0 |
| X-03 | 3 | 0 | X-13 | 3 | 0 |
| X-03b | 2 | 0 | X-14 | 3 | 0 |
| X-04 | 1 | 0 | X-16 | 3 | 0 |
| X-05 | 3 | 0 | X-17 | 3 | 0 |
| X-06 | 3 | 0 | X-18 | 3 | 0 |
| X-07 | 3 | 0 | X-19 | 1 | 0 |
| X-08 | 3 | 0 | X-20 | 3 | 0 |
| X-09 | 3 | 0 | aleatorio | 2 000 | 0 |
| X-10 | 3 | 0 | **TOTAL** | **2 055** | **0** |

El arnés compara, por caso: `RES` de cada bloque (incluido `ErrSinPadre`), `SEL`, `UTXO`
(multiconjunto ordenado por `(dueño, valor, origen, altura, slot)`), `GAR` (por clave, con pendientes,
retiradas y créditos) y `EST` (emitido, quemado, fase, terminal, altura, slot, peso del sufijo).
Además comprueba `deshacer(aplicar_con_undo(E,B)) == E` para todo bloque aplicado y, en X-16, la
independencia del orden de entrega.

## 3. Correspondencias usadas (§4 de la orden)

Se aplicaron **exactamente** las de §4, sin añadir ninguna:

| Esperado en T01 | Resultado Rust aceptado |
|---|---|
| `Evidencia` en PoW/PoST (`ErrOperacionFase`/`ErrFueraDeAlcanceV0`) | `ErrForma(VersionInactiva)` (v4 no construible) |
| `ErrAutorizacion` por `firmante ≠ dueño`/`clave` | `ErrFirma` o `ErrAutorizacion` |
| `ErrSaldo`/`ErrDobleGasto` por entrada/salida inexistente | el mismo nombre |
| R-8 importe 0 (`ErrSaldo`) | `ErrForma(ImporteCero)` |
| R-9 transferencia con entradas y sin salidas (`ErrSaldo`) | `ErrForma(TransferenciaSinSalidas)` |
| R-6/R-7/R-9 coinbase fuera de lugar/sin salidas/sin entradas (`ErrEmision`) | `ErrEmision` |
| Cualquier otro | nombre idéntico |

**Decisiones del arnés** (declaradas, no correspondencias de error): (a) cada salida abstracta usa
una clave de bloque única derivada de `(id, dueño)` para que dos coinbases idénticas no colisionen
en el mismo `txid` real (el oráculo les da ids de salida distintos); (b) el motor mantiene un
contador `prox_salida` para las salidas implícitas de `Liberacion`, como el oráculo, porque dos
liberaciones idénticas tendrían el mismo `txid`. Ambas son invisibles al render canónico y están
documentadas en `PROGRESO.md` (faltas 1–9).

## 4. API final (`crates/zx-consensus/src/transicion/`)

Tipos (`tipos.rs`): `HechosCabecera` (`Genesis`/`PoW`/`PoST`), `BloqueTransicion`
(`hechos`, `txs: Vec<(Tx, Vec<Vec<u8>>)>`, `cabecera_post: Option<DagBlockHeader>`),
`ParametrosTransicion`, `Fase`, `Punto`, `Origen`, `EntradaUtxo`, `Pendiente`, `EnRetirada`,
`Garantia`, `Estado`, `Undo`, `Marca`, `TxDescartada`, `Escalares`.

Errores (`error.rs`): `ErrorTransicion` con los nombres de T01 (`ErrGenesis`, `ErrPow`, `ErrEmision`,
`ErrInmaduro`, `ErrDepositoTemprano`, `ErrAutorizacion`, `ErrSaldo`, `ErrDobleGasto`,
`ErrPowTrasCorte`, `ErrSinTerminal`, `ErrTerminalAmbiguo`, `ErrGarantia`, `ErrOperacionFase`,
`ErrPruebaTardia`, `ErrSectorInactivo`, `ErrSlot`, `ErrDesbordamiento`, `ErrFueraDeAlcanceV0`,
`ErrRetiroPendiente`) más los propios (`ErrFirma`, `ErrForma(ErrorFormaTx)`, `ErrSinPadre`), y
`nombre_t01()` para el diferencial.

Funciones:
- `aplicar(estado, bloque, params, cbid) -> Result<Estado, ErrorTransicion>`
- `aplicar_con_undo(...) -> Result<(Estado, Undo), ErrorTransicion>`
- `deshacer(estado, undo) -> Estado` (delta, no copia)
- `seleccionar(bloques, params, cbid) -> Result<ResultadoSeleccion, _>` (FC-3)
- `nodo_en_linea(secuencia, params, cbid) -> Result<(Option<BlockHash>, Estado), _>` (`C-FIN-01`)
- `construir_validos`, `mapa_por_hash`, `es_terminal`, `es_terminal_condiciones`
- `phi`, `gastable_en`, `suma_utxo`, `suma_garantias`, `invariante_i1`, `invariante_i1b`
- `aplicar_fusion(estado, bloque, punto_aplicacion, params, cbid)
  -> Result<(Estado, Undo, Vec<TxDescartada>), _>` (primitivas de fusión de W03)

En `zx-core` se añadieron `PartialOrd, Ord` a `OutPoint` y `ClavePublica` (una línea cada uno) para
poder usar los `BTreeMap` que fija §3.4. No cambia wire, hash ni ninguna regla.

## 5. Lo que esta orden NO demuestra

- **Verificación de cabeceras**: PoW, PoT, PoAS y sellos son entradas de `HechosCabecera`; W03 no
  los comprueba. `pow_valido`/`prueba_valida` se reciben ya decididos.
- **Persistencia en disco**: no hay storage ni reorg persistente; el undo es en memoria.
- **Red**: no hay nodo, gossip, latencia ni particiones.
- **Parámetros de la red dev**: `ParametrosTransicion` no fija ningún valor; subsidios, `W_min`,
  `S_min`, `q`, madureces y `R_slots` son simbólicos (los del fichero de T01 son de prueba).
- **`SEC-A`, `EvidenceTx` y sectorización**: fuera de alcance v0; el motor solo implementa `SEC-0`
  (los vectores no contienen altas/pruebas de sector).
- **`FC-1`/`FC-2` y `CUT-H`/`CUT-W`**: solo se implementa la interfaz por defecto `CUT-HWΦ` + `FC-3`.
- **Motor DAG completo**: `aplicar_fusion` implementa el descarte con motivo y el recorte de la
  coinbase PoST, pero la orquestación ED-1…ED-6 (orden del mergeset, `rojo_U3`, punto de aplicación
  del virtual) es de W06a. La semántica de la coinbase en fusión usa la pre-pasada de las
  transacciones para conocer las tarifas aceptadas; es una lectura provisional declarada.
- **I-3/I-4/I-5/I-7 completos**: el diferencial cubre I-1, I-1b, I-2 y (X-16) parte de I-3; no se
  comprueban I-4…I-7 como propiedades exhaustivas.
- **Colisión de `txid` en el formato v0**: dos transacciones idénticas (coinbase o liberación) en
  bloques distintos tienen el mismo `txid`; el oráculo lo abstrae con ids de salida únicos. W03 lo
  resuelve en el arnés y con `prox_salida`, pero es una limitación de diseño de FORMATO-v0 que
  conviene elevar al director (W05/W06).
