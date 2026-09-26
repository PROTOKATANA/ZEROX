# INFORME RI-1a — Revisión independiente del motor de transición y los formatos de `zx-core`

**Revisor:** RI-1a. **Orden:** `P-ZRX/P-REVISION-CODIGO/ORDEN-RI-1.md`.
**Ámbito:** `crates/zx-consensus/src/transicion/` (motor de transición, modo estricto y fusión, undo)
y `crates/zx-core/src/{tx.rs, forma.rs, encoding/, preimage/, digest.rs, amount.rs}` (formatos y
`txid`), contra `P-ZRX/P-TRANSICION/CONTRATO-v0.md` (v0.1), `P-ZRX/P-FORMATO/FORMATO-v0.md` y
`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`. **Zona:** `deepseek/RI-1a/`.
**Código revisado:** commit `ac60b74` (rama `rediseno/v1-spec-first`), copia congelada en
`deepseek/RI-1a/copia/` para reproducción (idéntica a la raíz en `crates/zx-consensus/src/transicion/`
y en los archivos de formato de `crates/zx-core/src/` listados arriba).

**Excluido, per ORDEN-RI-1 (no se reporta):** unicidad de `txid` de la coinbase y falta de protección
contra repetición de operaciones de garantía (nonce) — F-15…F-18, corrección en curso en W02b; el
código de la copia todavía no implementa `nonce` (F-15) ni `expiry_height` de la coinbase PoW (F-16)
ni `slot` en la coinbase PoST (F-17): es exactamente lo ya conocido, no se cuenta como hallazgo nuevo.
Tampoco se reporta elección de algoritmo PoW (A-12) ni nada «no activo en 0.0.1».

## Tabla de hallazgos

| # | Gravedad | Estado | Archivo:línea | Descripción |
|---|---|---|---|---|
| 1 | **Crítica** | CONFIRMADO | `crates/zx-consensus/src/transicion/fusion.rs:230-347` (`fusion_post`) | En modo fusión nunca se actualiza `Estado.slot` ni `Estado.peso_sufijo` al fusionar un bloque PoST; el modo estricto (`aplicar.rs:796-801`, `aplicar_post`) sí los actualiza. Viola **IE-5** (`CONTRATO-ESTADO-DAG-v0.md` §4) e inutiliza el criterio de peso GHOSTDAG que usa `comparar_fc3` (`seleccion.rs:96-111`) en cualquier estado construido por fusión. |
| 2 | **Alta** | CONFIRMADO | `crates/zx-consensus/src/transicion/fusion.rs:145-228` (`fusion_pow`) | `fusion_pow` no exige `altura == altura_previa + 1` (regla **R-10** de `CONTRATO-v0.md`, sí exigida por `aplicar_pow` en `aplicar.rs:724-731`). Un bloque PoW fusionado con un salto de altura arbitrario se acepta y `Estado.altura`/`Estado.trabajo` adoptan el valor declarado sin comprobación de progresión; sin ningún test que ejercite `fusion_pow` con un bloque PoW (los tests de «modo fusión» existentes solo usan `bloque_post`). |

---

## Detalle de los hallazgos

### 1 · `fusion_post` no propaga `Estado.slot` ni `Estado.peso_sufijo` — CRÍTICA, CONFIRMADO

**Regla del contrato.** `CONTRATO-ESTADO-DAG-v0.md` §4, **IE-5**: «Con `k = 0` y sin fusiones, el
resultado coincide con el oráculo T01 (compatibilidad)». `peso_sufijo` es además el criterio
**primario** de la selección transversal `FC-3`/`TRN-09` (`CONTRATO-v0.md` §5, `seleccion.rs::comparar_fc3`,
líneas 96-111: compara `peso_sufijo` antes que el terminal y antes que el hash).

**Divergencia exacta.** En modo estricto, `aplicar.rs::aplicar_post` termina con:

```rust
ap.estado.slot = *slot;
ap.estado.peso_sufijo = ap.estado.peso_sufijo.checked_add(*peso)...;
```

En `fusion.rs::fusion_post` no existe ninguna asignación equivalente en todo el cuerpo de la función:
la rama `Fase::PoST => {}` (línea 262) que sustituye a la comprobación de progresión de slot de
`aplicar_post` tampoco actualiza nada, y el resto de la función (líneas 264-347) nunca vuelve a tocar
`ap.estado.slot` ni `ap.estado.peso_sufijo`.

**Escenario concreto.** Un mismo bloque `B` (un único bloque de cadena, sin mergeset — el caso `k = 0`
que IE-5 exige comparar) aplicado con `aplicar` y con `aplicar_fusion` desde el mismo estado de
partida produce dos estados que solo difieren en `slot`/`peso_sufijo`: `1`/`1` con `aplicar`, `0`/`0`
con `aplicar_fusion`. Encadenando un segundo bloque de cadena por fusión (como haría W06a al construir
`Estado(past(B))` según ED-2) el error se acumula: tras dos bloques, ambos campos siguen en `0`.

**Consecuencia de consenso.** En cuanto la orquestación del DAG (W06a) use `aplicar_fusion` para
construir los estados que alimentan la selección de cadena, `comparar_fc3` dejaría de discriminar por
peso PoST honesto — todo estado producido por fusión compararía `0 == 0` en el primer criterio— y la
selección colapsaría al desempate por menor `block_hash`. Es precisamente el escenario que `D-T03`
dice impedir: que el hash, no el peso PoST, decida la selección tras el corte.

**Reproducción.** Test añadido en la copia,
`deepseek/RI-1a/copia/crates/zx-consensus/src/transicion/tests.rs`
(`ri1a_fusion_post_actualiza_slot_y_peso_sufijo_como_el_modo_estricto`):

```rust
#[test]
fn ri1a_fusion_post_actualiza_slot_y_peso_sufijo_como_el_modo_estricto() {
    let (_, pk) = par(23);
    let cb1 = tx_coinbase_post(pk, 3);
    let mut estado = estado_post();
    con_garantia(&mut estado, pk, 10);
    estado.emitido = 10;
    estado.subsidio_acum = 10;
    let bloque = bloque_post(1, pk, vec![(cb1, Vec::new())]);

    let estricto = aplicar(&estado, &bloque, &params(), CBID_RED_DEV).unwrap();
    let (fusion, _undo, descartadas) =
        aplicar_fusion(&estado, &bloque, Punto::Slot(1), &params(), CBID_RED_DEV).unwrap();

    assert!(descartadas.is_empty());
    assert_eq!(estricto.slot, 1);
    assert_eq!(fusion.slot, estricto.slot);               // falla: fusion.slot == 0
    assert_eq!(fusion.peso_sufijo, estricto.peso_sufijo);  // falla: 0 != 1
    // ... (test completo también encadena un segundo bloque por fusión: el bug persiste)
}
```

Comando y salida literal (ejecutado en `deepseek/RI-1a/copia`, con `CARGO_HOME` y `CARGO_TARGET_DIR`
apuntando a `deepseek/RI-1a/`, `--locked`, 4 hilos):

```
$ export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/RI-1a/.cargo-home
$ export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/RI-1a/target
$ env -u LD_LIBRARY_PATH cargo test -p zx-consensus --locked -j 4 --lib \
    transicion::tests::ri1a_fusion_post_actualiza_slot_y_peso_sufijo_como_el_modo_estricto \
    -- --test-threads=4

running 1 test
test transicion::tests::ri1a_fusion_post_actualiza_slot_y_peso_sufijo_como_el_modo_estricto ... FAILED

thread '...' panicked at crates/zx-consensus/src/transicion/tests.rs:558:5:
assertion `left == right` failed: IE-5: aplicar_fusion (sin mergeset) MUST coincidir con el modo
estricto en Estado.slot; quedó en 0 en vez de 1
  left: 0
 right: 1

test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 76 filtered out
```

Corrida completa de la suite (`cargo test -p zx-consensus -p zx-core --locked -j 4 --no-fail-fast --
--test-threads=4`): **todos los tests preexistentes de `zx-consensus` (76) y de `zx-core` (148) más
las suites de integración (`diferencial_t01`, `pow_dev`, `transicion_prop`, `verificador_pow`,
`formato_v0`, `vectores_dag`, etc.) pasan**; solo el test nuevo falla. El hallazgo es aislado a
`fusion_post`, no un efecto del entorno.

**Por qué no lo detecta la batería existente.** `diferencial_t01.rs` (`ejecutar_caso`) construye
`Estado(past(B))` exclusivamente con `construir_validos`/`seleccionar`, que llaman a
`aplicar_con_undo` (modo estricto) — nunca a `aplicar_fusion`. Los cuatro tests de «modo fusión» en
`tests.rs` (`fusion_descarta_doble_gasto`, `fusion_descarta_retiro_duplicado`,
`fusion_descarta_liberacion_prematura`, `fusion_recorta_la_coinbase_post`) no leen `nuevo.slot` ni
`nuevo.peso_sufijo` en ninguna aserción. El modo fusión no tiene ninguna cobertura de estos dos campos.

**Corrección sugerida (diagnóstico, no aplicada):** propagar `slot`/`peso_sufijo` en `fusion_post`
igual que en `aplicar_post`. La corrección real depende de una decisión que el contrato deja abierta:
`RD-4` distingue si `punto` es el del bloque de cadena o el de un bloque fusionado de lado, y
`fusion_post` hoy no recibe esa distinción como parámetro explícito (solo `punto_aplicacion`). Señalar
la ambigüedad al equipo de W06a antes de corregir.

---

### 2 · `fusion_pow` no exige progresión exacta de altura — ALTA, CONFIRMADO

**Regla del contrato.** `CONTRATO-v0.md`, Ratificaciones v0.1, **R-10**: «Errores de forma sin nombre
propio: … altura o slot que no progresa y `peso < 1` ⇒ `ErrSlot`». `aplicar_pow` la aplica así
(`aplicar.rs:724-731`):

```rust
let esperada = ap.estado.altura.checked_add(1)...;
if *altura != esperada { return Err(ErrorTransicion::ErrSlot); }
```

**Divergencia exacta.** `fusion_pow` (`fusion.rs:145-228`) comprueba fase, `pow_valido` y
`trabajo != 0`, pero no repite la comprobación `altura == altura_previa + 1`. Al final asigna
`ap.estado.altura = *altura;` con el valor declarado, sea cual sea.

**Escenario concreto.** Desde un estado en fase PoW con `altura = 0`, un bloque PoW con `altura = 5`
(en vez de `1`) se acepta en modo fusión y `Estado.altura`/`Estado.trabajo` adoptan ese salto; el
mismo bloque aplicado con `aplicar` (modo estricto) se rechaza con `ErrSlot`.

**Reproducción** (test `ri1a_fusion_pow_acepta_un_salto_de_altura`, mismo archivo):

```rust
#[test]
fn ri1a_fusion_pow_acepta_un_salto_de_altura() {
    let cb = tx_coinbase_pow(vec![tx_out(10, par(30).1)]);
    let estado = estado_pow();
    let bloque = bloque_pow(5, vec![(cb, Vec::new())]); // salta de 0 a 5, no a 1
    let (nuevo, _undo, descartadas) =
        aplicar_fusion(&estado, &bloque, Punto::Altura(5), &params(), CBID_RED_DEV).unwrap();
    assert!(descartadas.is_empty());
    assert_eq!(nuevo.altura, 5); // el bug: adopta la altura sin comprobar progresión

    assert_eq!(
        aplicar(&estado, &bloque, &params(), CBID_RED_DEV),
        Err(ErrorTransicion::ErrSlot) // el modo estricto sí lo rechaza
    );
}
```

Salida verificada: `test transicion::tests::ri1a_fusion_pow_acepta_un_salto_de_altura ... ok` (las dos
aserciones se cumplen: aceptación indebida en fusión y rechazo correcto en modo estricto), confirmado
al ejecutar la suite completa (ver comando arriba; total 77 pasan + 1 falla = 78, el que falla es el
hallazgo 1).

**Nota de alcance.** `CONTRATO-ESTADO-DAG-v0.md` §2 (ED-1) dice que la fase PoW «se aplica igual que
en el contrato de transición» (modo estricto, no fusión), lo que sugiere que `fusion_pow` podría no
llegar a invocarse nunca en el diseño final de W06a (el DAG y sus fusiones son fenómenos de la fase
PoST). Aun así, es una función alcanzable hoy por cualquier llamante de `aplicar_fusion` con un bloque
PoW, no tiene ningún test que la cubra, y el propio archivo no documenta esa restricción de uso.
Clasificada ALTA y no CRÍTICA por esa incertidumbre de alcanzabilidad real en el diseño final; es
CONFIRMADO que el código, tal y como está escrito hoy, lo permite.

---

## Revisado sin hallazgos adicionales

No se encontraron más divergencias con `CONTRATO-v0.md`/`FORMATO-v0.md`/`CONTRATO-ESTADO-DAG-v0.md`,
desbordamientos no comprobados, no determinismo, o verificación saltada, más allá de lo ya excluido
por la orden. Puntos verificados explícitamente:

- **`TRN-04`/`TRN-05`** (terminal «primero que cumple», bloqueo de PoW tras el corte): correcto
  en `aplicar_pow`/`es_terminal_condiciones`; el estado guarda `terminal` de forma persistente y
  bloquea cualquier PoW posterior con `ErrPowTrasCorte`.
- **`TRN-06`/`TRN-07`** (bloque de transición con único padre = terminal; garantía evaluada sobre
  `past(B)` incluyendo lo que madura exactamente en `slot(B)`; `requisito` declarado se ignora,
  X-10): correcto en `aplicar_post`.
- **`I-1`/`I-2`** (conservación, undo exacto): el undo por delta (`estado.rs::Aplicador`) registra el
  valor previo de cada `OutPoint`/`ClavePublica` la primera vez que se toca en el bloque; no se
  detectó ninguna ruta de mutación de `utxo`/`garantias` que evite pasar por
  `insertar_utxo`/`borrar_utxo`/`garantia_mut` (y por tanto por el registro de undo). Verificado
  además por `proptest` (`transicion_prop.rs`, 64 casos) y por el diferencial contra T01.
- **`ED-4`/`ED-5`/`ED-6`** (descartes en modo fusión): correctos para transacciones no-coinbase; una
  descartada no aporta tarifa y una dependiente de ella se descarta también porque el estado mutado
  se revierte con `Aplicador::revertir_a` antes de intentar la siguiente.
- **`RD-7`** (la coinbase recortada se materializa después de las demás transacciones, aunque su
  posición en la lista siga siendo la primera): implementado literalmente en `fusion_post`.
- **F-05…F-10** (versiones activas, coherencia versión↔extensión, recuentos por tipo, testigos de v2,
  campos inactivos F-10): `forma.rs::validar_forma_tx` los aplica todos, con orden de comprobación
  fijado y documentado; `validar_forma_cabecera_post` aplica F-03 (`height` reservado en 0).
- **F-01…F-04** (tamaños y distinción de familias de cabecera): `preimage/block.rs` y
  `preimage/dag.rs` fijan 92/108 B (PoW) y 589-1037 B (PoST) con tests dedicados a las fronteras.
- **Códec de padres del DAG** (`preimage/dag.rs`): acota `parent_count` antes de reservar memoria o
  trocear el resto del buffer, rechaza padres no canónicos/duplicados/repetición del seleccionado; hay
  test de fuzzing simple (`bytes_arbitrarios_no_hacen_entrar_en_panico`).
- **`Amount`** (`amount.rs`): todo importe fuera de `[0, ZX_VALUE_SANITY_LIMIT]` es irrepresentable
  por construcción (el único constructor lo valida); `suma_comprobada`/`resta_comprobada` nunca
  saturan ni desbordan en silencio.
- **`CompactSize`** (`encoding/compact_size.rs`): rechaza codificaciones no mínimas.
- **`txid`/`sighash`/`auth_digest`** (`preimage/tx.rs`): dominios separados por etiqueta,
  `ANYONECANPAY`/`SINGLE`/`NONE` correctos, con vectores externos fijos (OpenSSL) para el flujo PoT
  (`preimage/flow.rs`).
- **No determinismo:** no hay `HashMap`/`HashSet`, relojes de pared, hilos ni flotantes en
  `zx-consensus/src/transicion/` ni en los archivos revisados de `zx-core`; todo el estado usa
  `BTreeMap`/`BTreeSet`, y `seleccion.rs::seleccionar` es explícitamente independiente del orden de
  llegada (cubierto por el caso X-16 del diferencial, verificado en la corrida).
- **Parámetros dev activables fuera de `Red::Dev`:** no aplica a este ámbito (vive en
  `zx-consensus/src/parametros.rs`, fuera del alcance de RI-1a).

### Archivos leídos enteros

- `crates/zx-consensus/src/transicion/mod.rs`
- `crates/zx-consensus/src/transicion/tipos.rs`
- `crates/zx-consensus/src/transicion/error.rs`
- `crates/zx-consensus/src/transicion/aplicar.rs`
- `crates/zx-consensus/src/transicion/estado.rs`
- `crates/zx-consensus/src/transicion/fusion.rs`
- `crates/zx-consensus/src/transicion/seleccion.rs`
- `crates/zx-consensus/src/transicion/tests.rs`
- `crates/zx-consensus/tests/transicion_prop.rs`
- `crates/zx-core/src/tx.rs`
- `crates/zx-core/src/forma.rs`
- `crates/zx-core/src/digest.rs`
- `crates/zx-core/src/amount.rs`
- `crates/zx-core/src/encoding/mod.rs`
- `crates/zx-core/src/encoding/int.rs`
- `crates/zx-core/src/encoding/compact_size.rs`
- `crates/zx-core/src/preimage/mod.rs`
- `crates/zx-core/src/preimage/tx.rs`
- `crates/zx-core/src/preimage/block.rs`
- `crates/zx-core/src/preimage/dag.rs`
- `crates/zx-core/src/preimage/flow.rs`
- `P-ZRX/P-TRANSICION/CONTRATO-v0.md`
- `P-ZRX/P-FORMATO/FORMATO-v0.md`
- `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`
- `V-ZRX/LINEO.md`
- `P-ZRX/P-REVISION-CODIGO/ORDEN-RI-1.md`

### Archivos/fuentes muestreados (no leídos línea a línea completos)

- `crates/zx-consensus/tests/diferencial_t01.rs` (1030 líneas; se leyó completo el arnés de
  comparación —`ejecutar_caso`, líneas 850-1030— y se confirmó por lectura y por grep que solo
  ejercita `aplicar_con_undo`/`seleccionar`, nunca `aplicar_fusion`; coherente con la falta de
  cobertura señalada en el hallazgo 1).
- `crates/zx-consensus/tests/pow_dev.rs`, `verificador_pow.rs` (fuera del ámbito de RI-1a; solo se
  comprobó que pasan en la corrida completa, sin leerlos a fondo).
- Búsqueda dirigida (`grep`) de `HashMap`/`HashSet`, `#[ignore]`, `todo!`/`unimplemented!`, `println!`
  en todo `zx-consensus/src/transicion/` y en los archivos de `zx-core` listados arriba: sin
  coincidencias relevantes.

## Método

Ambos hallazgos son **CONFIRMADO**: reproducidos con tests mínimos añadidos a
`deepseek/RI-1a/copia/crates/zx-consensus/src/transicion/tests.rs` (copia de la raíz —commit
`ac60b74`— en la zona escribible `deepseek/RI-1a/`, excluyendo `PDF/deepseek/target` del `tar` y
reenlazando `PDF`), compilados y ejecutados con `CARGO_HOME=deepseek/RI-1a/.cargo-home`,
`CARGO_TARGET_DIR=deepseek/RI-1a/target`, `--locked`, `-j 4`, `RUST_TEST_THREADS=4`. La corrida
completa de `zx-consensus` + `zx-core` (`--no-fail-fast`) confirma que ningún otro test se ve
afectado: todos los preexistentes pasan; el hallazgo 1 se manifiesta como el único test que falla
y el hallazgo 2 como un test que pasa demostrando ambas mitades de la divergencia (fusión acepta,
modo estricto rechaza).

No se usó Python. No se leyeron ni mostraron credenciales. No se escribió nada fuera de
`deepseek/RI-1a/` (la copia de trabajo en `deepseek/RI-1a/copia/` es un clon local del árbol, no un
remoto; no se hizo ningún `git commit`/`push`).
