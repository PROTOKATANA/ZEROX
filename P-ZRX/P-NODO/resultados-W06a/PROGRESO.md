# PROGRESO.md — ORDEN-W06a

Crate **nuevo** `crates/zx-cadena`: estado del DAG en memoria (admisión PoW/PoST, `Estado(past(B))`,
virtual, cadena seleccionada y reorganización con undo exacto) sobre `zx-consensus` y `zx-dag`, con
diferencial contra el oráculo T04-C (`vectores-estado-dag-v0.2.txt`). Zona única:
`/home/katana/zeo/ZEROX/deepseek/W06a/`. Base: workspace de la raíz copiado a `ws.orig/` y `ws/`.

## Entrada congelada — comprobación de INICIO

`sha256sum -c P-ZRX/P-NODO/ENTRADA-W06a.sha256` desde la raíz: **23/23 coinciden**, exit 0
(`logs/entrada-inicio.log`). `LINEO.md` se leyó íntegro **antes** de escribir código. Como esta
orden es Rust de consenso (no Julia/C++), las reglas de LINEO aplicables se traducen así: oráculos
consumidos como **vectores** (no recomputados), determinismo explícito, aritmética entera
comprobada (`checked_*`, sin flotantes ni `@fastmath`), nada de `unsafe`, presupuesto declarado
(3 h, 8 hilos, 16 GiB) y prohibición de Python.

## Falta de definición detectada e informada ANTES de editar

Ninguna impide cumplir la orden. Se declaran cinco interpretaciones, aplicadas sin inventar
semántica nueva; las tres primeras son huecos reales del encargo:

1. **`Estado(past(V))` exige insertar el bloque virtual en `zx-dag`.** `AlmacenGhostdag` no es
   `Clone` ni expone una inserción con `max_parents`/`mergeset_limit` relajados como el
   `deepcopy` + `gp` de T04 (`EstadoDAG.jl:_virtual_gdr`). La decisión 4 solo autoriza cambios
   mínimos en `zx-consensus::transicion`. **Interpretación:** `zx-cadena` **no** modifica `zx-dag`;
   reconstruye un `AlmacenGhostdag` temporal con `max_padres = 255` (acotado por el tope interno
   `MAX_PADRES = 15`), `mergeset_limite = u32::MAX` y `u2 = true` (el virtual va con
   `SinBillete`, que U2 no mira), readmite los bloques en su orden de inserción y añade `V` con
   `slot = máx slot(puntas)`, `sd = 0`, `sr = 0`, identidad ausente. El `Idx` denso coincide con el
   del almacén principal. **Límite declarado:** si un caso tuviera más de 15 puntas válidas, `V` no
   se podría insertar (T04 sí lo acepta); se comprueba que no ocurre en los 913 vectores.
2. **Alcance de la tabla de cobertura (V4b).** `cobertura-v0.2.txt` tiene dos apartados; el arnés
   solo ve los vectores, no el generador Julia. **Interpretación:** el arnés reproduce y compara el
   apartado `vectores-v0.2 (casos aleatorios)` (900 casos: líneas `TIPO` y resumen); el apartado
   `run.jl` sigue siendo evidencia de T04 y no es exigible al arnés.
3. **`ErrMergeDepth` no existe en `ErrorTransicion`.** El contrato DAG (`RD-5`) nombra así el
   rechazo por `merge_depth`, y los vectores T04-C lo usan 235 veces en `RES`. **Interpretación:**
   `zx-cadena` define `MotivoBloque` con los nombres de bloque del oráculo (`ErrSinPadre`,
   `ErrSlot`, `ErrEmision`, `ErrSaldo`, `ErrMergeset`, `ErrU2`, `ErrMergeDepth`, `ErrGarantia`) y
   reutiliza `ErrorTransicion::nombre_t01()` para los motivos de `DESC`. No se añade ninguna
   correspondencia de error de transacción nueva.
4. **Garantía del productor sin `Aplicador::promover`.** `promover` es `pub(crate)` de
   `zx-consensus`. **Interpretación:** `zx-cadena` calcula el `activo` promovido en `slot(B)` desde
   los campos públicos de `Garantia` (pendientes y créditos con `madura_en_slot ≤ slot(B)`), que es
   exactamente lo que hace `promover!(_, _, true)`; no se toca la API de `zx-consensus`.
5. **Correcciones RI-1a/RD en `fusion.rs`.** Autorizadas por la decisión 4: `aplicar_fusion`
   rechaza PoW (`ErrOperacionFase`, se elimina `fusion_pow`), `fusion_post` fija
   `Estado.slot = punto`, la coinbase PoST es opcional (RD-2), el crédito se materializa tras las
   transacciones (RD-7) y **no** se recompueba la garantía al fusionar (RD-10). Se ajustan los
   tests de V5 de W03 que leían el reparto anterior.
6. **Colisión de ids abstractos del oráculo (defecto de T04-C, no de W06a).** El generador de T04-C
   mantiene `out_id` para las transferencias pero no lo incrementa cuando una **liberación**
   consume `E.prox_salida`; el oráculo T01 (no el formato real F-18) usa un espacio único de ids
   enteros donde `crear_utxos!` descarta con `ErrDobleGasto` una transferencia cuyo id de salida ya
   está vivo. El formato real F-18 usa `OutPoint = (txid, índice)` y no puede representar esa
   colisión. **Interpretación:** el arnés reproduce el espacio de ids del oráculo con un punto fijo
   (orden de aplicación → ids de liberación y descartes → reconstrucción de las transacciones),
   declarado en `detectar_colisiones`; no es una correspondencia de error nueva (el motivo ya es
   `ErrDobleGasto`, de W03). Se documentan los tres casos residuales en el informe si no convergen.

## Secuencia de trabajo

1. **Lectura y montaje.** Lectura íntegra de la orden, `LINEO.md`, el contrato DAG, el contrato de
   transición, `FORMATO-v0.md`, `PLAN-W06.md`, las revisiones de W03/W05a/W02b/T04-B/T04-C y RI-1a,
   el oráculo T04 (`EstadoDAG.jl`, `propiedades.jl`, `generadores.jl`, `exportar.jl`) y el arnés de
   W03. Base copiada a `ws.orig/` y `ws/`; vectores v0.2 y `cobertura-v0.2.txt` copiados a
   `testdata/estado-dag-v0.2/`.
2. **`zx-consensus`.** Correcciones RI-1a/RD-2/RD-7/RD-10 en `transicion/fusion.rs`.
3. **`zx-cadena`.** Crate nuevo con `bloque.rs`, `error.rs`, `cadena.rs` y `lib.rs`.
4. **Arnés y propiedades.** `tests/diferencial_t04.rs` (RES/DESC/SEL/UTXO/GAR/EST + cobertura) y
   `tests/propiedades.rs` (IE-1…IE-4).
5. **Verificación.** V1–V6 y entregables.

## Resultado

- **V1** `cargo fmt --all -- --check`: exit 0 (`logs/V1-fmt.log`).
- **V2** `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: exit 0,
  0 avisos (`logs/V2-clippy.log`).
- **V3** `cargo test --workspace --all-features --locked`: **635 pasan, 0 fallan, 1 ignorado**
  (~14 de compilación + pruebas; `logs/V3-test.log`). `diferencial_t01` (0 discrepancias) y
  `diferencial_t01_negativos` siguen verdes. El único fuente de crate existente que cambia es
  `fusion.rs`; `transicion/tests.rs` es idéntico a la base, así que no desaparece ningún nombre de
  test previo.
- **V4** `diferencial_t04`: **913/913 casos, 0 discrepancias** (`logs/diferencial-cuarta.log`,
  191,7 s). Los 13 dirigidos D-1…D-13 y los 900 aleatorios coinciden en `RES`, `DESC`, `SEL`,
  `UTXO`, `GAR` y `EST`.
- **V4b** la tabla de cobertura del arnés es idéntica a la sección `vectores-v0.2 (casos
  aleatorios)` de `cobertura-v0.2.txt`: 349 depósitos / 808 retiros / 115 liberaciones aplicadas,
  `ErrNonce` 853 (18,29 %), `ErrDobleGasto` 316 y 312 reorganizaciones.
- **V5** `propiedades` (semilla `0x5a5a`, 64 casos): IE-1 conservación, IE-2 aplicación única,
  IE-3 orden de llegada e IE-4 undo/reorg, 4/4 (`logs/propiedades-primera.log`).
- **V6** 20 dependencias con versión exacta y 7 fronteras OK, incluida
  `zx-cadena → {zx-core,zx-consensus,zx-dag}` (`logs/V6-*.log`).
- **Entrada** 23/23 coinciden al inicio y al final (`logs/entrada-inicio.log`,
  `logs/entrada-final.log`). **`Cargo.lock`**: única adición `zx-cadena 0.0.0`
  (`logs/lock-subconjunto.txt`). **`MIGRACION.sha256`**: 167 huellas, `sha256sum -c` OK
  (`logs/migracion-check.log`).

**Colisión de ids abstractos.** El diferencial destapó un defecto del **generador de T04-C**: las
liberaciones consumen `E.prox_salida` sin que el generador incremente su `out_id`, así que una
transferencia posterior puede reutilizar un id vivo y el oráculo la descarta con `ErrDobleGasto`.
El formato real F-18 (`OutPoint = (txid, índice)`) no puede representarlo; el arnés reproduce el
espacio de ids del oráculo con un punto fijo declarado (orden de aplicación → ids de liberación y
descartes → reconstrucción de las transacciones). Tras la corrección de orden (consumir entradas
antes de comprobar `crear_utxos!`) y del mapeo por orden de aplicación, los 913 casos dan 0
discrepancias. Se recomienda a la dirección corregir `out_id` en un T04-D.

**Veredicto: SUPERADO.** La pregunta falsable no queda refutada.

