# INFORME RI-1b — Revisión independiente del código de consenso (PoW dev, zx-dag, puerta PoST)

**Revisor:** RI-1b (subagente Claude Sonnet 5). **Orden:** `P-ZRX/P-REVISION-CODIGO/ORDEN-RI-1.md`.
**Fecha:** 2026-09-26. **Zona escribible:** `deepseek/RI-1b/`.

**Alcance cubierto:** `crates/zx-consensus/src/{verificador.rs, dificultad.rs, timestamps.rs,
fork_choice.rs, activacion.rs, algoritmo.rs, genesis.rs, parametros.rs}`; `crates/zx-dag/`
(`ghostdag.rs`, `bloque_dag.rs`, `dag_causal.rs`, `identidad.rs`, `error.rs`, `lib.rs`);
`crates/zx-post/src/{cabecera_conjunta.rs, pot_rango.rs, pot.rs, contexto_transicion.rs,
justificacion.rs, productor.rs}`. También leí `crates/zx-core/src/preimage/dag.rs` (fuera de mi
zona, RI-1a) solo para comprobar si `PadresDag` permite padres duplicados — es relevante para un
hallazgo que descarté (ver «revisado sin hallazgos»).

**Presupuesto usado:** ~2 h de lectura y análisis + 1 reproducción medida (ver hallazgo H1).

---

## Tabla de hallazgos

| # | Gravedad | Estado | Archivo:línea | Descripción (una línea) |
|---|---|---|---|---|
| H1 | **Alta** | **CONFIRMADO** | `crates/zx-dag/src/ghostdag.rs:825-836` (U2, `pasado_contiene_ident`) y `:838-845` (`anc.unir`) | El coste de `AlmacenGhostdag::anadir_sintetico`/`admitir` por bloque crece con la profundidad de la cadena (no acotado): incluso en una cadena lineal sin mergeset, U2 recorre el bitset de pasado **completo** del padre; medido 18,46× más lento a 8× la profundidad. |
| H2 | Baja | PLAUSIBLE | `crates/zx-post/src/contexto_transicion.rs:176-181` | `ContextoTransicion::nuevo` tolera en silencio dos registros validados del mismo slot con `salida` (pot_output) distinta: se queda con la primera y no rechaza la incoherencia, contradiciendo su propio comentario («dos bloques del mismo slot comparten salida»). |

No se encontraron hallazgos de gravedad **crítica** ni divergencias entre código y los contratos
citados (`DECISIONES-W05.md`, `PERFIL-DEV-v0.md`, `CONTRATO-v0.md`, `REVISION-W04.md`,
`REVISION-W05a/b1/b2.md`) más allá de lo ya conocido y excluido por la orden.

---

## H1 — Coste no acotado de la admisión GHOSTDAG con la profundidad del DAG (alta, CONFIRMADO)

**Archivos/líneas:** `crates/zx-dag/src/ghostdag.rs`
- `admitir`/`anadir_sintetico` (líneas ~793-902): orden de comprobaciones.
- `pasado_contiene_ident` (líneas ~904-937): U2, recorre `anc[padre]` **entero**.
- Construcción de `anc` por unión (líneas ~838-845): cada bloque nuevo copia/amplía la unión de
  los bitsets de pasado de sus padres.

**Regla/contrato:** no hay una regla de contrato violada directamente (el propio módulo lo
documenta como límite abierto, ver más abajo), pero cae exactamente en lo que la orden pide buscar:
*"consumo no acotado (padres, tamaños, bucles) antes de validar"*. `DECISIONES-W05.md` marca
GHOSTDAG como **activo** en 0.0.1 (no está en la lista de exclusiones de la orden), así que lo
reporto.

**Escenario concreto:** una cadena PoST **lineal** (un solo padre, `k=30` por defecto, sin
mergeset porque no hay padres adicionales), con identidades de billete reales (`u2 = true`, valor
por defecto de `Parametros`). Al insertar el bloque `N+1`, `anadir_sintetico` llama, para el único
padre `N`, a `pasado_contiene_ident(N, identidad)`, que itera **todo** `anc[N]` (el pasado estricto
completo de `N`, un bitset de `O(N)` bits) buscando la identidad. Esto ocurre **antes** de
cualquier comprobación de tamaño de mergeset o de `S_max`, y ocurre en **cada** inserción. Además,
la propia construcción de `anc` para el bloque nuevo (unión de los `anc` de los padres) también
crece con `O(N)` por inserción. El resultado es que construir una cadena de `N` bloques cuesta
`O(N²)` en tiempo y memoria, no `O(N)`.

Esto ya está **documentado como límite conocido** en el propio módulo (`ghostdag.rs`, sección
«Límites pendientes (no cerrar con esta orden)»: *"U2 (`pasado_contiene_ident`) recorre los
ancestros de cada padre. Sin un índice compartido/acotado, el coste por bloque crece con el DAG.
No se inventa una cota."*). Mi aportación es (a) confirmarlo con una medición reproducible, y (b)
señalar que **no hace falta un mergeset grande**: una cadena lineal trivial, el caso más común y
honesto, ya lo dispara, porque U2 se ejecuta sobre el pasado del padre seleccionado
independientemente del tamaño del mergeset.

**Por qué importa para consenso/DoS:** hoy el almacén es "en memoria y de estudio", sin conexión a
la red (`admitir` no la llama ningún camino de `zx-node`, que aún no existe — W06). Pero
`DECISIONES-W05.md` lo marca **activo** para 0.0.1 y es la pieza que W06 va a cablear a la admisión
de bloques del nodo. Si se cablea tal cual, un nodo que reciba/valide una cadena PoST honesta de
tamaño moderado (miles de bloques) empezará a tardar segundos por bloque simplemente por la
profundidad acumulada, y un adversario que fuerce una cadena larga (o who simplemente deje pasar el
tiempo en una red real, sin necesidad de ser adversario) puede degradar el nodo sin gastar ningún
recurso extra de PoST/PoW: es puramente CPU/memoria del validador.

**Reproducción (CONFIRMADO):**

Copié la raíz a mi zona con
```
tar --exclude=./PDF --exclude=./deepseek --exclude=./target --exclude=./.git -cf - . \
  | tar -xf - -C deepseek/RI-1b/copia
```
y escribí el test mínimo en la copia:
`deepseek/RI-1b/copia/crates/zx-dag/tests/ri1b_coste_u2_lineal.rs` (incluido íntegro en esa ruta).
El test construye dos cadenas lineales de billetes distintos (`N=2000` y `N=16000`, escala 8×) con
`Algoritmo::Kernel` y mide el tiempo de las últimas 200 inserciones de cada una.

Comando y salida literal:

```
$ cd deepseek/RI-1b/copia
$ export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/RI-1b/.cargo-home
$ export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/RI-1b/target
$ export RUST_TEST_THREADS=4
$ cargo test -p zx-dag --test ri1b_coste_u2_lineal --release --locked -j 4 -- --nocapture
```
```
    Finished `release` profile [optimized] target(s) in 21.69s
     Running tests/ri1b_coste_u2_lineal.rs (.../ri1b_coste_u2_lineal-b4dd30195465a92f)

running 1 test
media últimas 200 inserciones @ N=2000: 90033 ns/inserción
media últimas 200 inserciones @ N=16000: 1662009 ns/inserción
razón (N=16000/N=2000) = 18.46× (escala de profundidad = 8×)
test el_coste_por_insercion_de_u2_crece_con_la_profundidad_de_la_cadena ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 9.88s
```

A 8× la profundidad, el coste por inserción subió 18,46× (superlineal, no la razón ~1× que daría
un coste O(1) acotado). Esto confirma empíricamente que el coste por bloque no está acotado y crece
con el tamaño del DAG, tal como advertía el comentario del módulo, y que el disparador mínimo es
una cadena lineal con identidades reales (no hace falta mergeset).

**Recomendación (no ejecutada, es de diseño):** el propio módulo ya apunta la dirección («un índice
compartido/acotado»). No lo implico como parte de esta revisión porque cambiaría la estructura de
datos del almacén; lo dejo como hallazgo de rendimiento/DoS para que quien cablee W06 no lo
descubra en producción.

---

## H2 — `ContextoTransicion` tolera salidas de slot incoherentes en silencio (baja, PLAUSIBLE)

**Archivo/línea:** `crates/zx-post/src/contexto_transicion.rs:176-181`

```rust
// El flujo es único y sin inyecciones: la salida de un slot es una función determinista
// del flujo y del slot, así que dos bloques del mismo slot comparten salida.
salidas_por_slot
    .entry(registro.slot)
    .or_insert(registro.salida);
```

**Regla/contrato:** el propio comentario del código afirma la invariante ("dos bloques del mismo
slot comparten salida"), pero el constructor no la comprueba: si el llamante pasa dos
`RegistroValidado` con el mismo `slot` y **distinta** `salida`, `or_insert` descarta en silencio la
segunda sin error. `ContextoTransicion::nuevo` sí rechaza duplicados de `hash` y de `terminal`
(`ErrorContextoTransicion::RegistroDuplicado`/`RegistroDelTerminal`), pero no esta incoherencia.

**Escenario concreto:** `ContextoTransicion::nuevo(t, N, SR, vec![RegistroValidado::nuevo(a, 5,
[0xAA;16], ...), RegistroValidado::nuevo(b, 5, [0xBB;16], ...)])` construye un contexto válido
(`Ok`) cuya `salida_validada(5)` es `[0xAA;16]`, ocultando que `b` declaró una salida distinta para
el mismo slot — una violación de la propia precondición que el módulo asume en `InstantaneaPot`.

**Por qué es de gravedad baja:** `ContextoTransicion` es explícitamente un contexto **dev**, no
cableado a ningún camino de red ni de nodo (W06 lo sustituirá); es el propio llamante quien
construye los `RegistroValidado`, y en todos los usos actuales (tests, `extremo_a_extremo.rs`) los
registros vienen de una única fuente coherente. No es explotable por un adversario remoto hoy. Lo
señalo porque, si `ContextoTransicion` se reutiliza como plantilla para el contexto real de W06 sin
revisar este punto, la incoherencia dejaría de ser inofensiva.

**Estado:** PLAUSIBLE, no CONFIRMADO — no escribí un test porque el comportamiento se sigue
directamente de leer `or_insert` y no hay ninguna rama de error que lo intercepte; consideré que no
merecía consumir presupuesto de reproducción frente a H1.

---

## Revisado sin hallazgos adicionales

### Leídos íntegros
- `crates/zx-consensus/src/verificador.rs`
- `crates/zx-consensus/src/dificultad.rs` (incluidos todos los tests)
- `crates/zx-consensus/src/timestamps.rs`
- `crates/zx-consensus/src/fork_choice.rs`
- `crates/zx-consensus/src/activacion.rs`
- `crates/zx-consensus/src/algoritmo.rs`
- `crates/zx-consensus/src/genesis.rs`
- `crates/zx-consensus/src/parametros.rs`
- `crates/zx-consensus/src/minero_dev.rs`
- `crates/zx-dag/src/ghostdag.rs` (completo, 1865 líneas)
- `crates/zx-dag/src/bloque_dag.rs`
- `crates/zx-dag/src/dag_causal.rs`
- `crates/zx-dag/src/identidad.rs`
- `crates/zx-dag/src/error.rs`
- `crates/zx-dag/src/lib.rs`
- `crates/zx-post/src/cabecera_conjunta.rs`
- `crates/zx-post/src/pot_rango.rs` (completo, 1337 líneas)
- `crates/zx-post/src/pot.rs`
- `crates/zx-post/src/contexto_transicion.rs`
- `crates/zx-post/src/justificacion.rs`
- `crates/zx-post/src/productor.rs`
- `crates/zx-core/src/preimage/dag.rs` (fuera de mi zona; leído para descartar un candidato a
  hallazgo sobre padres duplicados en `comprobar_padres_contextual` — `PadresDag::nuevo` y el
  parser de wire ya rechazan duplicados y repetición del seleccionado, así que no hay hallazgo)

### Solo muestreados (grep dirigido, no lectura completa)
- `P-ZRX/P-DAG/DECISIONES-W05.md`, `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`,
  `P-ZRX/P-TRANSICION/CONTRATO-v0.md`, `P-ZRX/P-POW/REVISION-W04.md`,
  `P-ZRX/P-DAG/REVISION-W05{a,b1,b2}.md`: leídos íntegros como contrato de referencia (no son
  código, pero los cito completos).
- `crates/zx-dag/tests/{dag_causal.rs, ghostdag_bench.rs, ghostdag_oraculo.rs, ghostdag_prop.rs,
  ghostdag_rust.rs, padres_dp08.rs}` y `crates/zx-post/tests/{cabecera_conjunta.rs,
  extremo_a_extremo.rs, flow.rs, justificacion.rs, pot_derivaciones.rs, pot_rango.rs,
  pot_slot.rs}`: **no leídos línea a línea**; solo grep de `#[ignore]` (una coincidencia,
  justificada: `ghostdag_bench.rs:230`, banco de rendimiento con motivo explícito, no oculta un
  fallo) y de patrones de aserción débil (`assert!(true)`, `TODO`, `FIXME`, `unimplemented`: cero
  coincidencias). Dado el tamaño (6541 líneas en total) y que los módulos de producción que
  ejercitan sí se leyeron íntegros, prioricé el código de producción sobre una lectura exhaustiva
  de los propios tests de integración.
- `crates/zx-consensus/src/error.rs`, `crates/zx-consensus/src/lib.rs`, `crates/zx-post/src/lib.rs`:
  no leídos (declaran tipos de error / reexports; los usos concretos de cada variante de error sí
  se revisaron en los módulos que los producen).
- `crates/zx-post/src/productor.rs`: leído íntegro, pero con menos profundidad de análisis porque
  es una herramienta de producción de bloques de **prueba** (dev), no un verificador: sus fallos
  afectarían a quien lo use para fabricar un bloque, no a la validación de un bloque ajeno.

### Grep dirigidos sobre todo el alcance, sin resultado relevante
- `unwrap()/expect()/panic!/unreachable!/todo!/unimplemented!` fuera de `#[cfg(test)]`: sin
  resultados en producción (todas las apariciones están dentro de módulos `tests`).
- `HashMap`/`HashSet` usados de forma que la iteración determine el resultado (no solo
  pertenencia): sin resultados — los usos existentes son de pertenencia (`contains`/`insert`) o de
  índice denso (`HashMap<BlockHash, Idx>` para lookup), no de iteración productora de salida.
- Casts truncantes (`as u32`/`as u16`/`as u8`) fuera de tests: los cuatro hallados en
  `ghostdag.rs` son de tamaños de anticono acotados por parámetros de consenso (`k`, `mergeset`),
  no de datos de un atacante sin cota previa.
- `#[ignore]`: una sola aparición, justificada (ver arriba).

### Parámetros dev fuera de `Red::Dev`
Revisé `parametros.rs::limites_de` y `activacion.rs::ramas`: ambos distinguen `Red::Dev` de
`Mainnet`/`Testnet` explícitamente y no hay ninguna vía por la que `PARAMETROS_POW_DEV` se filtre a
una red no-dev en el código de mi alcance. `zx-post` (PoT/PoAS/puerta conjunta) no referencia
`Red` en absoluto: sus parámetros (`n_dev`, `sr_dev`) los pasa el llamante explícitamente en cada
llamada, coherente con `PERFIL-DEV-v0.md` §4 y con que el cableado a `Red::Dev` es tarea de W06
(no existe aún el nodo que decida la red).
