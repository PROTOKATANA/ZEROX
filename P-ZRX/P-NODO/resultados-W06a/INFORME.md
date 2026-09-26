# INFORME.md — ORDEN-W06a

**Crate nuevo `crates/zx-cadena`: estado del DAG en memoria (admisión PoW/PoST, `Estado(past(B))`,
virtual, cadena seleccionada y reorganización con undo exacto) sobre `zx-consensus` y `zx-dag`, con
diferencial contra el oráculo T04-C.** Sesión: DeepSeek Harness, modelo `deepseek-flash`, esfuerzo
`high`. Fecha: 2026-09-26, 04:11–05:00 +02:00. Zona única:
`/home/katana/zeo/ZEROX/deepseek/W06a/`. Sin Python, sin dependencias Rust nuevas, sin `unsafe`, sin
commit ni push, nada escrito fuera de la zona. Base: workspace de la raíz copiado a `ws.orig/` y
`ws/`.

**Pregunta falsable:** «`zx-cadena`, alimentado con los bloques reales que el arnés construye de
cada caso de `vectores-estado-dag-v0.2.txt`, da el mismo resultado por bloque (incluidas las
transacciones descartadas y su motivo), la misma punta seleccionada y el mismo estado canónico que
T04, en todos los casos.»
**Veredicto: NO REFUTADA — SUPERADO.** 913/913 casos con 0 discrepancias, cobertura V4b idéntica,
`diferencial_t01` sigue en 0 y 635 tests del workspace pasan.

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §5) | Veredicto |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; `logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0, 0 avisos; `logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; **635 pasan, 0 fallan, 1 ignorado**; `diferencial_t01` y `diferencial_t01_negativos` verdes; `logs/V3-test.log`) |
| V4 | `diferencial_t04` sobre los 913 casos | **OK** (0 discrepancias; `logs/diferencial-cuarta.log`) |
| V4b | tabla de cobertura del arnés | **OK** (idéntica a la sección `vectores-v0.2` de `cobertura-v0.2.txt`) |
| V5 | `propiedades` con `proptest` (semilla `0x5a5a`, 64 casos) | **OK** (IE-1…IE-4, 4/4; `logs/propiedades-primera.log`) |
| V6 | `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh` | **OK** (20 dependencias exactas; 7 fronteras, incluida `zx-cadena → {zx-core,zx-consensus,zx-dag}`; `logs/V6-*.log`) |
| Entrada | `sha256sum -c P-ZRX/P-NODO/ENTRADA-W06a.sha256` al inicio y al final | **OK** en ambos (23/23; `logs/entrada-inicio.log`, `logs/entrada-final.log`) |

V3 desglosa 635 pasan + 1 ignorado (banco de `zx-dag`). El único fichero fuente de un crate
existente que cambia es `crates/zx-consensus/src/transicion/fusion.rs` (biblioteca); el fichero de
tests `transicion/tests.rs` es **byte a byte idéntico** al de la base, así que ningún nombre de test
previo desaparece. Lo nuevo: `zx-cadena` (lib + `diferencial_t04` + `propiedades`, 4 propiedades).

## 2. Diferencial por nombre de caso (V4)

| Caso | Casos | Con discrepancia | Caso | Casos | Con discrepancia |
|---|---:|---:|---|---:|---:|
| D-1…D-13 | 13 | 0 | aleatorio | 900 | 0 |
| **TOTAL** | **913** | **0** | | | |

El arnés compara, por caso: `RES` de cada bloque, `DESC` (bloque, índice 1-based y motivo),
`SEL punta`, `UTXO` (multiconjunto ordenado por `(dueño, valor, origen, altura, slot)`), `GAR` (por
clave, con pendientes, retiradas, créditos y `nonce`) y `EST` (emitido, quemado, fase, terminal,
altura, slot, `peso_sufijo`). La tabla de cobertura del arnés reproduce las ocho líneas `TIPO` y las
seis de resumen de la sección `vectores-v0.2 (casos aleatorios)`: depósitos 349 aplicados, retiros
808, liberaciones 115, `ErrNonce` 853 (18,29 % de las construidas), `ErrDobleGasto` 316,
312 reorganizaciones que deshacen garantía.

## 3. API de `zx-cadena`

- **`bloque`**: `BloqueCadena::{Pow(BloqueTransicion), Post(BloquePost)}`; `BloquePost` con
  `hash`, `padres`, `slot`, `productor`, `peso`, `prueba_valida`, `requisito_declarado`, `sr`,
  `distancia`, `identidad` y `txs`.
- **`error`**: `MotivoBloque` con los nombres del oráculo (`ErrSinPadre`, `ErrSlot`, `ErrEmision`,
  `ErrSaldo`, `ErrMergeset`, `ErrU2`, `ErrMergeDepth`, `ErrGarantia`, `ErrTransicion`).
- **`cadena`**: `Cadena::nueva(params, k, cbid)`; `admitir`, `resolver` (reintenta padres),
  `es_valido`, `motivo`, `estado_past`, `estado_post`, `descartes`, `terminal`, `estado_terminal`,
  `bloque`, `bloques_post`, `tips_validas`, `mejor_punta`, `cadena_virtual`, `u3_virtual`,
  `estado_virtual`, `aplicar_historia`, `aplicar_historia_completa`, `orden_aplicacion`,
  `aplicar_rama`, `deshacer_historia`; `Descarte { bloque, indice, motivo }`.

`Cadena` mantiene el almacén GHOSTDAG de `zx-dag` (raíz en el terminal, `k` por caso,
`max_padres = 3`, `mergeset_limite = 180`, `Algoritmo::Referencia`, `ModoSp::Zerox`,
`ModoMerge::Terna`), los estados `past`/`post` por bloque, los descartes y el terminal descubierto
por `es_terminal_condiciones`.

## 4. Correcciones RI-1a / RD en `zx-consensus::transicion::fusion`

| Cambio | Regla | Motivo |
|---|---|---|
| `aplicar_fusion` rechaza un bloque PoW (`ErrOperacionFase`); se elimina `fusion_pow` | RI-1a #2, ED-1 | la fase PoW se aplica con `aplicar` (estricto) |
| `fusion_post` fija `Estado.slot = punto` | RI-1a #1 | igual que `EstadoDAG.jl:303`; `peso_sufijo` lo suma el llamante solo por bloques de cadena |
| coinbase PoST **opcional** | RD-2 | el productor puede renunciar; si existe, única y primera |
| crédito de la coinbase tras las transacciones | RD-7 | `mín(declarado, subsidio_post(slot(X)) + tarifas aceptadas)` |
| se elimina la recompra de la garantía al fusionar | RD-10 | es admisión (`RD-9`), no se recompueba como bloque de lado |
| el importe usa `subsidio_post(slot(X))` | RD-1 | slot del propio bloque, no el punto de aplicación |

## 5. Falta de definición detectada e informada (y un defecto de T04-C)

1. **`Estado(past(V))` en `zx-dag`.** `AlmacenGhostdag` no es `Clone` ni acepta un bloque virtual con
   límites relajados. `zx-cadena` reproduce la copia del GDR de T04 reconstruyendo un almacén
   temporal con `max_padres = 255` (acotado por `MAX_PADRES = 15`), `mergeset_limite = u32::MAX` y
   `u2 = true` (el virtual va con `SinBillete`). No se tocó `zx-dag`; el `Idx` denso coincide.
2. **Alcance de V4b.** El arnés solo ve los vectores, así que compara la sección
   `vectores-v0.2 (casos aleatorios)`; el apartado `run.jl` sigue siendo evidencia de T04.
3. **`ErrMergeDepth`** no existe en `ErrorTransicion`; se nombra en `MotivoBloque` (RD-5), sin añadir
   correspondencias de error de transacción.
4. **Garantía sin `Aplicador::promover`.** Se calcula el `activo` promovido por slot desde los campos
   públicos de `Garantia`; no se cambió la API de `zx-consensus`.
5. **Colisión de ids abstractos (defecto de T04-C).** El generador mantiene `out_id` para las
   transferencias pero **no** lo incrementa cuando una liberación consume `E.prox_salida`; el oráculo
   T01 (no el formato real F-18) usa un espacio único de ids enteros donde `crear_utxos!` descarta
   con `ErrDobleGasto` una transferencia cuyo id de salida ya está vivo. El formato real F-18 usa
   `OutPoint = (txid, índice)` y **no puede representar** esa colisión. El arnés la reproduce con un
   punto fijo (orden de aplicación → ids de liberación y descartes → reconstrucción), declarado en
   `detectar_colisiones`; el motivo ya es `ErrDobleGasto` de W03 y no se añade ninguna
   correspondencia nueva. **Hallazgo para el director:** el defecto está en el generador de T04-C
   (v0.2), no en `zx-cadena`; se recomienda corregir `out_id` en un T04-D y reexportar.

## 6. Lo que esta orden NO demuestra

- **Verificación de cabeceras:** PoW, PoT, PoAS y sellos llegan decididos (`pow_valido`,
  `prueba_valida`); no se comprueban.
- **Persistencia y red:** el estado es en memoria; `zx-storage`/`zx-node`/red son W06b/W06c/W06d.
- **`Estado(past(V))` en producción:** la reconstrucción del virtual es `O(N²)` y acota `V` a 15
  padres (`MAX_PADRES`); T04 usa `max_parents = typemax`. No es la ruta de red.
- **Colisión de ids abstractos:** la traducción por punto fijo es un artificio del **arnés**; el
  motor real no la reproduce, porque F-18 la elimina.
- **Propiedades aleatorias:** los DAGs de `propiedades.rs` usan solo coinbases PoST y `q = S_min = 0`;
  no cubren garantías, fusiones con transacciones ni U3 (eso lo cubre el diferencial).
- **Interfaces:** solo `SEC0`, `CUT_HWPhi` y `FC3`.
- **Idoneidad de GHOSTDAG:** reproducir el oráculo no prueba que el SPEC sea correcto.

## 7. Presupuesto y trazas

Presupuesto: 3 h de reloj, 8 hilos, 16 GiB de RAM, disco amplio. Consumo real ≈ 50 min de reloj.
Toolchain `nightly-2026-05-03` (`cargo 1.97.0-nightly`, `rustc 1.97.0-nightly`), 8 jobs,
`RUST_TEST_THREADS=8`, `RUSTFLAGS=`. Artefactos: `ws/`, `ws.orig/`, `cambios.patch` (5,07 MB,
16 ficheros), `MIGRACION.sha256` (167 huellas, `sha256sum -c` OK; `logs/migracion-check.log`),
`logs/` (V1, V2, V3, V4, V4b en el informe de `diferencial-cuarta.log`, V5, V6, entrada, migración,
lock), `INFORME.md`, `PROGRESO.md`, `HORAS.log`. `Cargo.lock`: única adición `zx-cadena 0.0.0`,
cero cambios de versión (`logs/lock-subconjunto.txt`).

## 8. Resumen final (≤ 40 líneas)

1. W06a cumple: crate **nuevo** `crates/zx-cadena` con el estado del DAG en memoria (ED-1…ED-6,
   RD-1…RD-10).
2. Depende solo de `zx-core`, `zx-consensus` y `zx-dag` (lo vigila `ci/frontera-crates.sh`).
3. Correcciones RI-1a: `aplicar_fusion` rechaza PoW, `fusion_post` fija `slot = punto`; RD-2, RD-7 y
   RD-10 aplicadas.
4. `Estado(past(B))` (ED-2), virtual con `slot(V) = máx` (ED-3), `rojo_U3` inerte, `merge_depth` dev
   y cadena seleccionada.
5. Reorganización con `Undo` por delta y `deshacer_historia` (IE-4).
6. V1 `fmt` OK; V2 `clippy -D warnings` 0 avisos.
7. V3 **635 pasan, 0 fallan, 1 ignorado**; `diferencial_t01` y `diferencial_t01_negativos` verdes.
8. V4 **913/913 casos, 0 discrepancias**.
9. V4b tabla de cobertura **idéntica** a `cobertura-v0.2.txt` (sección de vectores).
10. V5 propiedades IE-1…IE-4, 4/4.
11. V6 20 dependencias exactas y 7 fronteras, incluida `zx-cadena`.
12. Entrada congelada 23/23 al inicio y al final.
13. `Cargo.lock`: única adición `zx-cadena 0.0.0`.
14. `MIGRACION.sha256`: 167 huellas verificadas.
15. Hallazgo: **defecto de generador de T04-C** (colisión de ids abstractos `out_id` vs
    `prox_salida`), reproducido por el arnés con un punto fijo declarado.
16. Límites: sin cabeceras, disco, red, ni `SEC-A`/PoT real.
17. Veredicto: **SUPERADO**; la pregunta falsable no queda refutada.
