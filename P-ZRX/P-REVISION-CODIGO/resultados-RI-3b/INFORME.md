# INFORME RI-3b — Revisión independiente de evidencia y castigo (SL-4a)

**Revisor:** RI-3b (subagente Claude Sonnet, revisión con criterio propio). **Fecha:** 2026-09-26.
**Alcance revisado:** `crates/zx-consensus/src/transicion/{aplicar.rs, estado.rs, fusion.rs,
seleccion.rs, tipos.rs, error.rs}`; `crates/zx-core/src/{forma.rs, tx.rs, hash.rs, wire.rs,
preimage/tx.rs, preimage/mod.rs}` (`EvidenceTx` v4); `crates/zx-cadena/src/cadena.rs` (evidencia en
fusión). Contratos: `P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md` (con su «Ratificación v0», que
prevalece), `P-ZRX/P-SLASHING/DECISIONES.md`, `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`,
`P-ZRX/P-TRANSICION/CONTRATO-v0.md`.

## 0 · Comprobación previa

```
$ cd /home/katana/zeo/ZEROX && sha256sum -c P-ZRX/P-REVISION-CODIGO/ENTRADA-RI-3.sha256
P-ZRX/P-REVISION-CODIGO/ORDEN-RI-3.md: La suma coincide
P-ZRX/P-REVISION-CODIGO/ORDEN-RI-1.md: La suma coincide
```

Horas (`date`, huso CEST): inicio **22:49:01**, fin **23:06:51**. Presupuesto de 2 h no agotado
(≈18 min de reloj).

`V-ZRX/LINEO.md` leído entero antes de escribir código: es la guía de auditorías Veritas
(Julia/CPU y C++/CUDA/GPU) del proyecto, no tiene contenido específico de Rust. Sus reglas
transversales aplicables aquí (no usar Python, distinguir hecho/derivación/hipótesis, no inventar
cifras, reproducibilidad con comando y salida literal) están cubiertas por el propio método de esta
orden y por el test de reproducción incluido más abajo.

## 1 · Tabla de hallazgos

| # | Gravedad | Estado | Archivo:línea | Resumen |
|---|---|---|---|---|
| H1 | **Alta** | **CONFIRMADO** | `crates/zx-consensus/src/transicion/aplicar.rs:660-673` (semántica) vs. `crates/zx-core/src/forma.rs:203-244` (`validar_forma_tx_v4`, no las comprueba) | `RAT-1` (cbid ajeno) y `EV-04` (orden canónico `pre_hash(H1) < pre_hash(H2)`) exigen **rechazo de forma** — invalida el bloque entero en admisión —, pero el motor solo los comprueba en la capa **semántica** (`ErrorTransicion::ErrCbidAjeno` / `ErrOrdenCanonico`, no `ErrForma`). En **modo fusión** (`aplicar_fusion`/`fusion_post`, el camino real de `zx-cadena::admitir_post`) eso significa que la `EvidenceTx` mal formada se **descarta** y el **bloque se acepta**, en vez de invalidarse como exige el contrato. |

No se encontraron hallazgos de gravedad crítica ni de doble castigo/escape de castigo real (ver §3).

## 2 · Detalle del hallazgo H1

### Regla del contrato (cita literal)

- `CONTRATO-EVIDENCIA-v0.md` §2, tabla EV-04 («Rechazo de forma»): fila
  `pre_hash(H1) ≥_lex pre_hash(H2) → ErrForma(OrdenCanonicoInvalido)`, con la introducción de la
  tabla: **«El parser rechaza, con el error indicado, sin llegar a la verificación semántica»**.
- **Ratificación v0** (prevalece sobre lo anterior), **RAT-1**: *«Una `EvidenceTx` solo es admisible
  si **ambas** cabeceras llevan el `consensus_branch_id` de la red local; si no,
  **`ErrForma`** (no es evidencia de esta red)»*.
- `CONTRATO-ESTADO-DAG-v0.md` §3 (tabla ED): un fallo de **forma** de cabecera o de transacciones
  (F-03…F-10) es **bloque inválido**, evaluado en **admisión**; solo una transacción que falla al
  **aplicarla** en modo fusión se **descarta** sin invalidar el bloque (`ED-4`…`ED-6`, `C-ORD-04`).

Es decir: por el propio texto ratificado, tanto el `cbid` ajeno como el orden canónico inválido
**MUST** rechazar el bloque completo en admisión, no limitarse a descartar la transacción.

### Lo que hace el código

- `crates/zx-core/src/forma.rs:215-244` (`validar_forma_tx_v4`) es la única función de forma para
  v4. Comprueba versión, coherencia de la extensión, ausencia de entradas/salidas/testigos,
  `lock_time`/`expiry_height` y que `H1`/`H2` sean cabeceras `PoAS_PoT_DAG` válidas
  (`validar_forma_cabecera_post`, que solo mira `height == 0`). **No comprueba ni el `cbid` ni el
  orden canónico** — su propio comentario lo dice explícitamente: *«No comprueba el orden canónico
  ni el `cbid`, la identidad, los sellos, la puerta RAT-3 o la ventana: esas comprobaciones son
  semánticas y viven en `zx_consensus::transicion`»*.
- `crates/zx-consensus/src/transicion/aplicar.rs:660-673` (`aplicar_evidencia`) comprueba ambas
  cosas, pero como parte del motor **semántico**: `ErrorTransicion::ErrCbidAjeno` (línea ~664) y
  `ErrorTransicion::ErrOrdenCanonico` (línea ~672), ninguna de las dos es la variante `ErrForma(_)`.
- `crates/zx-consensus/src/transicion/aplicar.rs:1-5` documenta que en modo **estricto**
  (`aplicar`/`aplicar_con_undo`) «cualquier fallo invalida el bloque entero» — así que un test que
  solo use ese camino (como los ya existentes `cbid_ajeno` y `orden_canonico_invalido` en
  `crates/zx-consensus/tests/evidencia.rs`) **no revela el problema**.
- `crates/zx-consensus/src/transicion/fusion.rs:218-249` (`fusion_post`, modo **fusión**, el que usa
  producción vía `crates/zx-cadena/src/cadena.rs:477` `admitir_post` → `aplicar_fusion`) captura el
  `Err` de `aplicar_tx` y lo empuja a `descartadas`, **revirtiendo solo esa transacción** y dejando
  el resto del bloque en pie. Como `ErrCbidAjeno`/`ErrOrdenCanonico` no son `ErrForma`, cualquier
  `EvidenceTx` con el `cbid` equivocado o las cabeceras en el orden equivocado atraviesa
  `validar_bloque` sin fallar, y solo se descarta más tarde en `fusion_post`.
- Evidencia adicional de que esto es un cabo suelto, no una decisión explícita nueva:
  `crates/zx-core/src/error.rs:353` declara `ErrorFormaTx::OrdenCanonicoInvalido` (el nombre exacto
  de `EV-04`) y `crates/zx-consensus/src/transicion/error.rs:135` tiene el brazo de traducción
  `Self::ErrForma(ErrorFormaTx::OrdenCanonicoInvalido) => "ErrOrdenCanonico"` — pero esa variante
  **nunca se construye en ningún lugar del árbol** (`grep -rn OrdenCanonicoInvalido crates/` solo
  encuentra la declaración y esa traducción muerta). Es decir: el andamiaje para tratarlo como
  `ErrForma` está, pero `validar_forma_tx_v4` nunca lo dispara.
- El oráculo de referencia (`P-ZRX/P-TRANSICION/T01/src/Transicion.jl`, línea 1105-1106, y su
  integración con el modo fusión de `P-ZRX/P-DAG/T04/src/EstadoDAG.jl`, `aplicar_bloque_fusion!`)
  **reproduce el mismo comportamiento**: `ErrOrdenCanonico`/`ErrCbidAjeno` son códigos que se
  comprueban dentro de la aplicación de la transacción, no en la forma, y `T04` los trata igual que
  cualquier otro fallo de aplicación (se descarta, no invalida el bloque). Esto **no** es una
  divergencia entre el motor Rust y el oráculo — ambos coinciden — pero **sí** es una divergencia
  entre ambos y el **texto ratificado** de `CONTRATO-EVIDENCIA-v0.md` (EV-04 y RAT-1), que en ningún
  sitio se corrigió para reflejar la convención «descarta, no invalida» de `CONTRATO-ESTADO-DAG-v0`
  (ratificado el mismo día).

### Escenario concreto (entrada → resultado)

Un bloque PoST con una `EvidenceTx` v4 cuyas dos cabeceras firman el mismo identificador de
oportunidad, con sellos Ed25519 válidos, dentro de la ventana de admisión, pero **o bien** (a) con
`consensus_branch_id` distinto del de la red local, **o bien** (b) con `H1`/`H2` en el orden
contrario (`pre_hash(H1) > pre_hash(H2)`):

- **Contrato (RAT-1/EV-04 + `CONTRATO-ESTADO-DAG-v0` §3):** el bloque entero es **inválido**, se
  rechaza en admisión, no se propaga.
- **Motor Rust (confirmado):** `aplicar_fusion` devuelve `Ok`; el bloque se acepta e integra a la
  cadena; la única consecuencia es que esa transacción aparece en la lista de descartes con motivo
  `ErrCbidAjeno`/`ErrOrdenCanonico`. Ningún incidente se registra, no hay congelación ni
  confiscación (consistente en sí mismo), pero el **bloque contenedor no debía haberse aceptado**.

### Reproducción (CONFIRMADO)

Copia de la raíz en la zona de trabajo (`tar --exclude=./PDF --exclude=./deepseek --exclude=./target`,
enlace `PDF`), `CARGO_TARGET_DIR`/`CARGO_HOME` propios, `--locked`, 4 hilos:

```
$ cd /home/katana/zeo/ZEROX
$ mkdir -p deepseek/RI-3b/copia && \
  tar --exclude=./PDF --exclude=./deepseek --exclude=./target -cf - . | (cd deepseek/RI-3b/copia && tar -xf -)
$ ln -sfn /home/katana/zeo/ZEROX/PDF deepseek/RI-3b/copia/PDF
$ cp -r deepseek/RI-2b/.cargo-home/. deepseek/RI-3b/.cargo-home/   # caché de dependencias, no se usa en su sitio
```

Se añadieron dos tests mínimos a `crates/zx-consensus/tests/evidencia.rs` (en la **copia**), que
reutilizan los constructores de cabeceras/sellos reales ya presentes en ese archivo (`evidencia_tx`,
`cabecera`, `bloque_post`, `estado_post`):

```rust
#[test]
fn ri3b_orden_canonico_invalido_no_invalida_el_bloque_en_fusion() {
    let estado = estado_post();
    let tx = evidencia_tx(7, 1, 1, 22, 11, true, true, Vec::new()); // H1 con pre_hash MAYOR que H2
    let bloque = bloque_post(1, clave_de(1), vec![(tx, Vec::new())]);

    let estricto = aplicar_con_undo(&estado, &bloque, &params(), CBID_RED_DEV, &evp(7));
    assert_eq!(estricto, Err(ErrorTransicion::ErrOrdenCanonico)); // control positivo: sí se detecta

    let (nuevo, _undo, descartes) = aplicar_fusion(
        &estado, &bloque, Punto::Slot(1), &params(), CBID_RED_DEV, &evp(7),
    ).expect("BUG confirmado: el bloque se acepta en modo fusión pese a EV-04");
    assert_eq!(descartes.len(), 1);
    assert_eq!(descartes[0].motivo, ErrorTransicion::ErrOrdenCanonico);
    assert!(nuevo.garantias.get(&clave_de(1)).unwrap().incidentes.is_empty());
    assert_eq!(nuevo.quemado, 0);
}

#[test]
fn ri3b_cbid_ajeno_no_invalida_el_bloque_en_fusion() {
    let estado = estado_post();
    let tx = ev_valida(99, 1, 1); // cbid de la evidencia (99) ≠ cbid de la red local (evp(7))
    let bloque = bloque_post(1, clave_de(1), vec![(tx, Vec::new())]);

    let estricto = aplicar_con_undo(&estado, &bloque, &params(), CBID_RED_DEV, &evp(7));
    assert_eq!(estricto, Err(ErrorTransicion::ErrCbidAjeno));

    let (nuevo, _undo, descartes) = aplicar_fusion(
        &estado, &bloque, Punto::Slot(1), &params(), CBID_RED_DEV, &evp(7),
    ).expect("BUG confirmado: el bloque se acepta en modo fusión pese a RAT-1 (\"si no, ErrForma\")");
    assert_eq!(descartes.len(), 1);
    assert_eq!(descartes[0].motivo, ErrorTransicion::ErrCbidAjeno);
    assert!(nuevo.garantias.get(&clave_de(1)).unwrap().incidentes.is_empty());
    assert_eq!(nuevo.quemado, 0);
}
```

Ejecución:

```
$ export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/RI-3b/target
$ export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/RI-3b/.cargo-home
$ export RUST_TEST_THREADS=4
$ cd /home/katana/zeo/ZEROX/deepseek/RI-3b/copia
$ cargo test --locked -j 4 -p zx-consensus --test evidencia
running 10 tests
test cbid_ajeno ... ok
test evidencia_con_salidas ... ok
test orden_canonico_invalido ... ok
test ri3b_cbid_ajeno_no_invalida_el_bloque_en_fusion ... ok
test ri3b_orden_canonico_invalido_no_invalida_el_bloque_en_fusion ... ok
test autodenuncia ... ok
test sello_invalido ... ok
test ventana_de_liberacion_rat3 ... ok
test duplicada_en_hermanos ... ok
test undo_y_reaparicion ... ok

test result: ok. 10 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.02s
```

Los dos tests nuevos pasan **confirmando el bug**: `aplicar_fusion` devuelve `Ok` (bloque válido)
con la transacción en la lista de descartes, para ambos casos que el contrato dice que deben
invalidar el bloque completo.

### Por qué no es más grave de lo que se reporta (mitigación actual) y por qué sigue siendo Alta

- **Hoy no es alcanzable por red.** `crates/zx-core/src/wire.rs:300-308` (`tx_desde_bytes`) rechaza
  **toda** transacción v4 incondicionalmente (`EncodingError::VersionInactiva`), con el propio
  comentario admitiendo que el wire de v4 no está definido (`FD-5`,
  `deepseek/SL4a/DEFINICIONES-FALTANTES.md`). Ningún nodo puede hoy recibir ni decodificar un bloque
  con una `EvidenceTx` v4 desde la red: el motor y `zx-cadena` la implementan (por eso RI-3b los
  revisa, según excluye la propia orden), pero no hay camino de red que la alcance todavía. Por eso
  no hay hoy una vía de explotación entre pares.
- **No hay escape de castigo ni castigo falso.** En ambos casos la `EvidenceTx` malformada
  simplemente no tiene ningún efecto (no se registra incidente, no se congela ni confisca nada);
  el problema es exclusivamente que el **bloque contenedor** debía haberse rechazado y no se
  rechaza — no que alguien evite o sufra un castigo indebido.
- **El oráculo Julia (T01/T04) coincide con el motor Rust**, así que hoy no hay riesgo de una
  bifurcación de consenso entre las dos referencias del proyecto por esta causa.
- Se marca **Alta** y no Media/Baja porque: (a) coincide literalmente con uno de los puntos que la
  propia orden pide buscar («`EvidenceTx` que viola la forma v4 y aun así se acepta»); (b) viola el
  texto de **RAT-1**, que la orden señala expresamente como el que **prevalece**; (c) el andamiaje
  muerto (`OrdenCanonicoInvalido` declarado y traducido pero nunca emitido) indica que la intención
  original **sí** era tratarlo como forma, y quedó a medias; y (d) si SL-4b activa el wire de v4 sin
  corregir esto, el defecto pasa de dormido a explotable por cualquier par de la red el mismo día
  que se activa.

### Recomendación (no ejecutada; decisión del director)

Dos caminos, mutuamente excluyentes, cada uno con su coste:

1. **Mover las dos comprobaciones a `validar_forma_tx_v4`** (comparar `cbid` contra un `cbid` de red
   que la forma tendría que recibir como parámetro — hoy no lo tiene — y comparar `pre_hash(H1)` con
   `pre_hash(H2)`). Coste: la forma pasa a depender del `cbid` de la red (hoy es puramente estructural
   y sin contexto, por diseño — ver el docstring de `forma.rs`), y cualquier fallo pasa a invalidar
   el bloque entero, lo que también penaliza a un productor honesto que incluya por error una
   `EvidenceTx` ajena o mal ordenada construida por otro. Es la lectura literal de RAT-1/EV-04.
2. **Enmendar `CONTRATO-EVIDENCIA-v0.md`** (RAT-1 y la fila de `EV-04`) para declarar
   explícitamente que el `cbid` ajeno y el orden canónico son comprobaciones **semánticas** que se
   descartan sin invalidar el bloque, alineando el texto con `CONTRATO-ESTADO-DAG-v0` (`ED-3`…`ED-6`)
   y con lo que ya hacen el motor y el oráculo. Coste: ninguno en código; dejar por escrito que la
   «Ratificación v0» del 2026-09-26 tenía en este punto un texto no reconciliado con el contrato del
   DAG ratificado el mismo día.

No recomiendo una opción sobre la otra: es exactamente la clase de decisión de diseño (seguridad
por invalidación total del bloque vs. tolerancia del DAG a transacciones sueltas malformadas) que
corresponde al director, no a esta revisión.

## 3 · Revisado sin hallazgos adicionales

Se revisaron explícitamente, contra el catálogo de casos de `CONTRATO-EVIDENCIA-v0.md` §11 y contra
`DECISIONES.md` (DS-L01…DS-L05), sin encontrar divergencia (todos con test existente que lo cubre,
citado):

- **EV-05/EV-06 (identidad de oportunidad, RAT-1):** `identidad_de_cabecera` en `aplicar.rs:605-626`
  usa exactamente la tupla `(consensus_branch_id, public_key, sector_index, history_size, chunk,
  slot)` de `DS-L04`. Comparación por igualdad estructural, no por resumen.
- **EV-07 (sellos):** `DagBlockHeader::verificar_sello` (`crates/zx-core/src/preimage/dag.rs:408-416`)
  verifica cada cabecera contra su propio `pre_hash` bajo `sol.public_key`; como `EV-06` ya igualó las
  claves, probar los dos sellos con éxito prueba dos decisiones de firma de la misma clave. Cubierto
  por el test `sello_invalido`.
- **EV-10/EV-11/EV-12 (incident_id, registro, deduplicación):** `incident_id_evidencia`
  (`crates/zx-core/src/preimage/tx.rs:191-208`) recibe el `cbid` como argumento explícito (coherente
  con `RAT-1`); el registro y la deduplicación en `aplicar.rs:690-716` están cubiertos por
  `duplicada_en_hermanos` (dos bloques hermanos, la segunda `EvidenceTx` del mismo incidente se
  descarta con `ErrEvidenciaDuplicada`, sin doble congelación).
- **EV-13/EV-14 (ventana de admisión):** aritmética `saturating_add`/comparación en
  `aplicar.rs:683-689`, sin overflow silencioso.
- **EV-17/EV-19/EV-20/EV-22 (congelación, confiscación, débito determinista, clave sin saldo):**
  `debitar_garantia` (`estado.rs:199-263`) debita en orden `activo → pendientes → en_retirada →
  créditos`; `techo_fraccion`/`suelo_dos_octavos` (`estado.rs:170-195`) son aritmética entera
  comprobada, sin `Float64`. Cubierto por `autodenuncia` (verifica cifras exactas: `V=C=8`,
  `quemado=6`, recompensa `2`).
- **RAT-2′ (reparto 2/8 al incluidor, división hacia abajo):** `suelo_dos_octavos` implementa
  `C ÷ 4` (no `techo`), consistente con la corrección del 2026-09-26. Verificado con el mismo test.
- **RAT-3/EV-15b/EV-24 (puerta estructural y ventana de liberación):** la puerta
  `r_slots > plazo_slots + m_margen_slots` (`aplicar.rs:679-682`) y el bloqueo de liberación por
  incidente abierto (i) y por producción reciente (ii) (`aplicar.rs:523-538`) están cubiertos por
  `ventana_de_liberacion_rat3` (caso límite exacto: `slot 5 < 7` rechaza, `slot 7 ≥ 7` admite).
- **EV-27/EV-28 (undo exacto y reaparición tras reorg):** el undo por delta (`estado.rs:282-319`,
  `Aplicador`) restaura `incidentes`, `congelado` y `ultimo_slot_producido` byte a byte; cubierto por
  `undo_y_reaparicion` (deshacer y reaplicar produce el mismo estado, la reaplicación cuenta como
  primera, no como duplicada).
- **`EvidenceTx` en fase PoW (X-13):** rechazada con `ErrOperacionFase` en `aplicar_tx` (`aplicar.rs`
  línea ~797), antes de mirar `evp.evp`.
- **Codificación de la preimagen de `EvidenceTx` (EV-03):** `extension_digest` para v4
  (`preimage/tx.rs:175-183`) concatena `dag_header_a_bytes(h1) ‖ dag_header_a_bytes(h2)` sin prefijo
  de longitud (`PreimageWriter::canonical`, `preimage/mod.rs:97-105`); se comprobó que esto **no** es
  ambiguo porque la codificación de cada cabecera es autodelimitada (`parent_count` va **dentro** del
  cuerpo de la cabecera, antes de los padres extra y del sello — `crates/zx-core/src/preimage/dag.rs`,
  `OFFSET_PARENT_COUNT`/`tamano_cabecera`), así que la frontera entre `H1` y `H2` es reconstruible sin
  un delimitador aparte. No es un hallazgo.
- **Etiquetas de dominio (`TAG_TXID_EVP`, `TAG_EVP_INCIDENTE`):** de 16 bytes fijos, ninguna es
  prefijo de otra ni de `ZZKTxIdHash_` (`crates/zx-core/src/hash.rs:140-214`).
- **Wire de `EvidenceTx` v4:** `tx_desde_bytes` (`crates/zx-core/src/wire.rs:300-308`) rechaza **toda**
  v4 incondicionalmente. Esto está **declarado** como brecha conocida (`FD-5`) y coincide con lo que
  la propia orden excluye («el nodo aún no los activa»); no se reporta como hallazgo nuevo, pero es
  el contexto necesario para valorar el alcance de H1 (§2).

### Archivos leídos enteros

`crates/zx-consensus/src/transicion/aplicar.rs` (1048 líneas), `estado.rs` (534), `fusion.rs` (288),
`tipos.rs` (499), `error.rs` (168); `crates/zx-consensus/tests/evidencia.rs` (372, más los dos tests
añadidos en la copia); `crates/zx-core/src/forma.rs` (244), `tx.rs` (325), `preimage/tx.rs` (724);
`P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md`, `P-ZRX/P-SLASHING/DECISIONES.md`,
`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`, `P-ZRX/P-TRANSICION/CONTRATO-v0.md`,
`P-ZRX/P-REVISION-CODIGO/ORDEN-RI-3.md`, `ORDEN-RI-1.md`, `V-ZRX/LINEO.md`.

### Archivos muestreados (secciones relevantes a evidencia/castigo, no el archivo completo)

`crates/zx-core/src/hash.rs` (tabla de etiquetas, líneas 1-230 de 329); `crates/zx-core/src/wire.rs`
(codificación de `ExtensionTx` y despacho de versión, ~330 de 966 líneas); `crates/zx-core/src/
preimage/mod.rs` (métodos de `PreimageWriter`, completo salvo el prólogo); `crates/zx-core/src/
preimage/dag.rs` (layout de `DagBlockHeader`, `pre_hash`, `verificar_sello`, ~270 de ~600+ líneas;
fuera del alcance nominal de RI-3b pero necesario para verificar EV-03/EV-07); `crates/zx-consensus/
src/transicion/seleccion.rs` (grep dirigido: solo confirma que `evp` se pasa sin tocar la selección,
consistente con `I-5`); `crates/zx-cadena/src/cadena.rs` (1140 líneas; leídas ~250 centradas en
`admitir_post`, `chequear_forma`, cabecera del struct `Cadena` y comentarios ED-1…ED-3; el resto
—GHOSTDAG, bifurcaciones PoW, `equivocación`— es mayormente territorio de RI-1/RI-2/RI-3a y no se
auditó exhaustivamente aquí más allá de confirmar el punto de entrada de `aplicar_fusion`).
`P-ZRX/P-TRANSICION/T01/src/Transicion.jl` y `P-ZRX/P-DAG/T04/src/EstadoDAG.jl` (grep dirigido a
`OrdenCanonico`/`ErrCbidAjeno`/modo fusión, para contrastar el motor Rust con el oráculo).

## 4 · Limpieza

Copia de trabajo en `deepseek/RI-3b/copia/` (con `PDF` enlazado), `.cargo-home` (copiado de
`deepseek/RI-2b/.cargo-home`) y `target` propios, todo dentro de `deepseek/RI-3b/`. No se tocó
`deepseek/W06d5/` ni ninguno de sus procesos. Los `cargo test` se ejecutaron con `--locked`,
`CARGO_TARGET_DIR`/`CARGO_HOME` propios y como mucho 4 hilos (`-j 4`, `RUST_TEST_THREADS=4`).

El único proceso largo en segundo plano fue un `cargo test -p zx-core -p zx-consensus -p zx-cadena`
completo (PID de `cargo` 1400836, bajo `timeout 500`), lanzado como comprobación adicional de que
los dos tests de reproducción no rompían nada más. Se cortó por el propio `timeout` (500 s, código
de salida 143) sin terminar, atascado dentro del test de integración `diferencial_t04` (un
diferencial proptest contra los vectores del oráculo T04, ajeno a `EvidenceTx` y ya lento por
diseño — no es un fallo, es un test pesado que no cabía en el presupuesto de esta comprobación
extra). Esto **no** afecta a los hallazgos: los 10 tests de `crates/zx-consensus/tests/evidencia.rs`
(incluidos los dos de reproducción) se ejecutaron por separado hasta el final y pasaron, como se
pega en §2. Confirmado tras el corte que no queda ningún proceso vivo (`pgrep` de `cargo`, `rustc`,
`diferencial_t04` y los tres crates: vacío) antes de cerrar esta revisión.
