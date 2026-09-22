# REVISION-RUST — CRP-v0.2 (coste-rama-privada-v2)

**Clase de revisión:** revisión en **contexto independiente** (revisor distinto del ejecutor, con
acceso al repo real). **No es firma criptográfica de un tercero.** No modifiqué código de
producción, SPEC, TAREAS ni el encargo. No hice commit.

**Fecha:** 2026-09-18. **Revisor:** revisión independiente de Rust y semántica upstream.
**Objeto:** `MATRIZ-AUTORIDAD.md`, `MODELO.md`, `METODO.md`, `INFORME.md` y sus afirmaciones de
integración y de reutilización de GDR-v0.2, contra el código Rust de ZEROX y el encargo
`deepseek/ENCARGO-07v2-coste-rama-privada.md`.

---

## 0 · Alcance

Entra:

1. Veracidad de las afirmaciones de integración del instrumento sobre
   `crates/zx-consensus/src/ghostdag.rs`, `fork_choice.rs`, `crates/zx-core/src/wire_dag.rs`,
   `crates/zx-consensus/src/bloque_dag.rs` y `crates/zx-node/src/cadena.rs`.
2. Correspondencia del inventario normativo del instrumento con `ci/reglas-sin-cablear.txt`,
   `ci/reglas-sin-codigo.txt` y `ci/consenso-pendiente.txt`.
3. Corrección de la ruta y de la API de GDR-v0.2 usada por `src/gdr_wrapper.jl`
   (`EstadoReferencia`, `anadir!`, `gd[].blues/tipos`, `bw_de`).
4. Estado normativo de las reglas del SPEC citadas.

**No entra:** dictamen matemático/probabilístico, numerismo Julia, criptografía PoT. La suite
Julia se ejecutó solo como comprobación funcional del wrapper GDR; su corrección de cálculo es del
revisor de matemáticas/Julia.

## 1 · Método

- Lectura directa del código: `ghostdag.rs` (1184 líneas), `fork_choice.rs` (385), `wire_dag.rs`
  (733), `bloque_dag.rs` (638), `cadena.rs`, `nodo.rs`, `lib.rs` de `zx-consensus`.
- `grep -rn` acotado para localizar usos reales (`ghostdag`, `blue_work`, `IntegracionPotPendiente`,
  `comprobar_rango_contextual`, `comprobar_padres_contextual`, `ContextoRangoDag`), distinguiendo
  exportación de crate de llamada desde la ruta activa.
- Contraste con `ci/reglas-sin-cablear.txt`, `ci/reglas-sin-codigo.txt`,
  `ci/consenso-pendiente.txt` y con `SPEC.md` §6.1, §7.2, §11 y §16.6.
- Lectura del oráculo GDR-v0.2 (`veritas/consenso/ghostdag-rank-v1/src/{GhostdagRank,modelo,referencia}.jl`)
  y del wrapper del instrumento.
- Verificación de huellas (`sha256sum -c`) y **ejecución reproducible** de
  `test/runtests.jl` (`env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl`)
  para acreditar que la ruta GDR y su API funcionan.

---

## 2 · Afirmaciones de integración

### 2.1 `ghostdag.rs` NO está cableado en `zx-node` — CONFIRMADO

`grep` de `ghostdag|Ghostdag` en `crates/zx-node/src/` devuelve **cero** coincidencias. El almacén
solo aparece exportado por el crate (`crates/zx-consensus/src/lib.rs:36`) y consumido por el propio
crate (`ghostdag.rs`) y sus tests. La afirmación del instrumento
(`MATRIZ-AUTORIDAD.md:27` «implementada sin cablear | no lo usa `zx-node`») es **correcta**, igual
que la de `ci/reglas-sin-cablear.txt:39-43` y `ci/consenso-pendiente.txt:23-38`.

Matiz verificado: `impl ContextoDag for AlmacenGhostdag` existe (`ghostdag.rs:1126`), pero
`comprobar_padres_contextual` solo se invoca en tests (`bloque_dag.rs:570-636` y
`crates/zx-consensus/tests/ghostdag_rust.rs`). Ninguna ruta del nodo lo llama. Coincide con
`ci/reglas-sin-cablear.txt:42-43`.

### 2.2 `fork_choice.rs` usa trabajo PoW lineal, no `blue_work` — CONFIRMADO

`fork_choice.rs` importa `TrabajoAcumulado`, `hash_como_entero` y `trabajo_bloque` de
`zx_core::target` (`fork_choice.rs:24`) y decide por `a.trabajo.cmp(&b.trabajo)`
(`fork_choice.rs:79`), con `trabajo_acumulado` recalculado desde targets (`fork_choice.rs:100-108`).
No hay ninguna referencia a `blue_work`/`blue_score` en `cadena.rs` (grep vacío). La afirmación
«ruta activa (PoW lineal)» es **correcta**.

La ruta está viva: `cadena.rs:321` (`adoptar`) usa `preferir` (`cadena.rs:355`) y `adoptar` se
llama desde `nodo.rs:279`. El comentario `cadena.rs:413` («`fork_choice`… no está conectado») se
refiere a `extender`, no a `adoptar`; no contradice al instrumento.

### 2.3 `wire_dag.rs` devuelve `IntegracionPotPendiente` — CONFIRMADO

`IntegracionPotPendiente` está definido en `wire_dag.rs:349` y
`verificar_justificacion_pot` devuelve **siempre** `Err(IntegracionPotPendiente(...))`
(`wire_dag.rs:375-383`). También lo devuelve `rele_compacto.rs:733-738`. La afirmación
(`MATRIZ-AUTORIDAD.md:36`) es **correcta**. Igual que GHOSTDAG, esta función no está cableada en
`zx-node` (`C-HDR-07` es «implementada sin cablear», `ci/reglas-sin-cablear.txt:27-29,34`).

### 2.4 Inventario «implementada sin cablear» vs «sin código»

Según `ci/*.txt`:

- **Implementada sin cablear** (`ci/reglas-sin-cablear.txt`): `C-HDR-05`, `C-HDR-06`, `C-HDR-07`,
  `C-HDR-09`; `C-GD-01`…`C-GD-09`; `C-ORD-01`…`C-ORD-03`; `C-NET-06`…`C-NET-09`, `R-NET-01`,
  `R-NET-02`.
- **Sin código** (`ci/reglas-sin-codigo.txt`): `C-STORE-09`; `C-UPG-06/07/08`; `C-WIRE-06`;
  `C-HDR-08`; `C-CHK-01`…`C-CHK-07`; `C-SLOT-01`…`C-SLOT-03`; `C-EXP-01`…`C-EXP-06`;
  `C-SPEC-02/03`; `C-NET-25`…`C-NET-32`; `C-GD-10`, `C-ORD-04`, `C-GD-11`.

El instrumento clasifica bien `C-GD-01`…`09`, `C-ORD-01`…`03` (sin cablear), `C-GD-10`,
`C-ORD-04`, `C-GD-11` y `C-NET-31/32` (sin código). **Falla en `C-HDR-06`** (ver H1).

---

## 3 · Reutilización de GDR-v0.2

### 3.1 Ruta — CORRECTA

`src/gdr_wrapper.jl:9-14` resuelve
`deepseek/veritas/seguridad/coste-rama-privada-v2/src/../../../../../veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl`.
Con cinco `..` desde `src/` se llega a la raíz del repo y el archivo existe
(`realpath` verificado). La ruta es **correcta**.

### 3.2 API — EXISTE y significa lo que el wrapper cree

| Uso del wrapper | Definición GDR | Veredicto |
|---|---|---|
| `GhostdagRank.EstadoReferencia` | `referencia.jl:20` | existe |
| `GhostdagRank.anadir!(est, params, id, padres, slot, sd, sr, ident)` | `referencia.jl:165-166` | firma idéntica; devuelve `Bool` |
| `gd[].blues` | `GDRef.blues` (`referencia.jl:10`), `[sp, …]` (`referencia.jl:196,254`) | existe; semántica que el wrapper describe (incluye `sp`) |
| `gd[].tipos` | `GDRef.tipos::Dict{Int,UInt8}` (`referencia.jl:12`), `0x01` rojo_k, `0x02` rojo_U3 (`referencia.jl:210,224`) | existe; el wrapper mapea bien (`gdr_wrapper.jl:51-54`) |
| `GhostdagRank.bw_de(est, i)` | `referencia.jl:34` → `est.gd[i].bw` | existe; `bw` es el acumulador de `C-GD-08` (`referencia.jl:228-232`) |
| `GhostdagRank.peso_big` | `modelo.jl:86` | existe y es exportado |
| `GhostdagRank.tips` | `modelo.jl:230` | existe y es exportado |
| `Params(; k, s_max, …)` | `modelo.jl:125-141` | constructor keyword válido |

Detalles verificados: `bw_de` **no** está en la lista de `export` de `GhostdagRank.jl:5-16`, pero
el wrapper lo llama cualificado (`GhostdagRank.bw_de`, `gdr_wrapper.jl:61`), lo que funciona en
Julia. `bw` excluye el peso propio del bloque (C-GD-08, `referencia.jl:229,233-237`), y el wrapper
lo declara explícitamente (`gdr_wrapper.jl:74-75`); no hay doble conteo oculto.

### 3.3 Comprobación funcional

La suite del instrumento se ejecutó aquí y reproduce **128/128 en verde** (`resultados/TESTS.txt`),
lo que incluye los fixtures que pasan por GDR (`fixture_rojo_conocido`, `fixture_cero_rojos`) y la
simulación por vistas locales. La reutilización de GDR-v0.2 es real y ejecutable, no solo citada.

---

## 4 · Hallazgos: afirmaciones que el código/SPEC desmienten o exageran

### H1 · `C-HDR-06` no está «sin código»; es «implementada sin cablear» — error de estado

`MATRIZ-AUTORIDAD.md:35` marca `C-HDR-06` con integración **«sin código»**. El código existe:
`ContextoRangoDag` y `comprobar_rango_contextual` están en `crates/zx-consensus/src/bloque_dag.rs:105-135`
y se exportan en `crates/zx-consensus/src/lib.rs:27`. Lo que falta es el **algoritmo del
controlador** y su cableado (`ci/reglas-sin-cablear.txt:24-26,33` lo clasifica explícitamente como
implementada-sin-cablear). Debe decir «implementada sin cablear (interfaz); controlador pendiente»,
no «sin código».

### H2 · `R-FIN-1a` marcada `candidata` cuando es SPEC vigente (C-HDR-05) — error y omisión

`MATRIZ-AUTORIDAD.md:37` etiqueta `R-FIN-1a` como `candidata`. Pero el SPEC lo ha adoptado:
`C-HDR-05` dice literalmente `slot(sp(B)) ≤ slot(B)` **«(R-FIN-1a)»** (`SPEC.md:879-881`), y
`ci/reglas-sin-cablear.txt:21-23,32` lista `C-HDR-05` como implementada-sin-cablear. El instrumento
**no tiene fila para `C-HDR-05`**: sustituye una regla vigente por la regla de investigación de la
que nació. El estado correcto es `SPEC vigente` (integrada en el oráculo/`ghostdag.rs`, sin cablear
en el nodo).

### H3 · `R-FIN-11` marcada `candidata` contradice la propia fila `C-GD-07` del instrumento

`MATRIZ-AUTORIDAD.md:41` etiqueta `R-FIN-11 (U2/U3″)` como `candidata`, mientras la línea 18 del
mismo archivo marca `C-GD-07` como **SPEC vigente**. Son la misma regla: `C-GD-07` está redactado
como «Unicidad de billete (U2 y U3″ dinámica) … `(R-FIN-11)`» (`SPEC.md:1701-1707`), y la
definición de `R-FIN-11` en `research/dag-poas-ancla-de-orden.md:227-237` coincide término a
término. No puede ser candidata y vigente a la vez.

### H4 · R-FIN-5 no se aplica en el DAG: la fila «R-FIN-5 estructural + GDR» exagera la integración

`grep` de `compatible_rfin5|puede_incorporar_pasado|prefijo_flujo|DescriptorFlujo` en `src/`,
`test/` y `run.jl` muestra que solo se usan en `rfin5.jl`, en `run.jl` y en tests. `dag_sim.jl` **no
llama** a R-FIN-5 antes de colorear (grep vacío salvo un comentario). Sin embargo:

- `MATRIZ-VALIDEZ.md:11` presenta el escenario 4 como «R-FIN-5 estructural + GDR»;
- `dag_sim.jl:42` etiqueta el **máximo** de ramas (`maximum(res.W_priv)`) como «R-FIN-5», cuando no
  hay ningún filtro de flujo: es solo el máximo de ramas incompatibles.

El encargo exige que, en el escenario candidato, «flujo/R-FIN-5 se evalúa antes de GHOSTDAG»
(§5.3; §3.3; D7). En este instrumento R-FIN-5 y GDR **nunca se combinan**: el predicado es una
unidad estructural aislada y el simulador DAG colorea sin filtro. Debe decirse «predicado
estructural independiente», no «escenario DAG con R-FIN-5».

### H5 · La validez se declara trivaluada y luego se usa cuatrivaluada

El encargo §0 exige validez **trivaluada** (`Válida`, `Inválida`, `Pendiente`), y así lo dice
`MATRIZ-AUTORIDAD.md:5`. Pero `src/modelo.jl:12` añade `CONTRAFACTUAL` al enum de validez y
`MATRIZ-VALIDEZ.md:3` lo presenta como cuarta clase de validez. `Contrafactual` es una etiqueta de
**escenario** (encargo §1.5), no un cuarto valor de validez. Es una desviación menor del contrato,
pero rompe la trivalencia declarada.

### H6 · Escenario DAG clasificado `Válida` con `C-GD-11` ausente

`MATRIZ-VALIDEZ.md:10` clasifica el escenario 3 como `Válida (medido condicionado)` y anota «sin
`C-GD-11`». `C-GD-11` **decide validez de la fusión** y sigue con cinco pendientes
(`SPEC.md:1779-1797`), y GDR no lo implementa. El encargo §3.1 ordena clasificar `Pendiente` la
traza que necesite una decisión de `C-GD-11`. El instrumento lo declara y aun así la etiqueta como
`Válida`; en lectura estricta corresponde `Pendiente`/condicionada explícita a que `C-GD-11` no
invalide ninguna fusión. El propio `MATRIZ-AUTORIDAD.md:22` ya dice «validez de fusión
condicionada», lo que refuerza la incoherencia.

### H7 · `tasa_rojos_calibrada` mezcla conjuntos y unidades (secundario, para el revisor Julia)

En `src/validacion.jl:67-72`, el denominador suma `res.azules_publicos` (= `blue_score` de la punta,
azules distintos en el pasado de la punta, `dag_sim.jl:186`) con `res.rojos_publicos` (= bloque
honesto rojo en **cualquier** contexto, `dag_sim.jl:187-197`). Son conjuntos distintos: rojos
globales frente a azules del pasado de la punta. El «tasa_bloques» publicado
(`resultados/DAG.txt`; `INFORME.md:115`) no es una fracción limpia de bloques. No afecta a las
afirmaciones Rust, pero es una cifra que el INFORME presenta como medición.

### H8 · Imprecisiones menores

- `MATRIZ-AUTORIDAD.md:13` dice «`BW256` en GDR / `checked_add` Rust». En Rust es correcto
  (`ghostdag.rs:274-284`), pero GDR acumula `blue_work` en `BigInt` (`referencia.jl:229-232`), no en
  `BW256` (que solo es el peso por bloque, `modelo.jl:74-83`). El oráculo no impone la cota `u256`.
- `MATRIZ-AUTORIDAD.md:45` atribuye «valores pendientes» a `C-NET-31/32` en bloque. Solo `C-NET-32`
  tiene valor pendiente (presupuesto de CPU, `SPEC.md:3007`); `C-NET-31` está cerrado.
- `MATRIZ-AUTORIDAD.md:14` hace depender `C-GD-03` de `C-GD-10`. La selección del `sp` entre unos
  padres no depende de la política de qué padres tomar; la dependencia real es de la simulación de
  producción, no de la regla.
- La fila de `fork_choice.rs` (`MATRIZ-AUTORIDAD.md:28`) usa «ruta activa (PoW lineal)» en la
  columna de estado normativo, que no es uno de los estados admitidos por el encargo §0
  (`SPEC vigente`, `candidata`, `oráculo abstracto`, `implementada sin cablear`, `integrada`,
  `pendiente`, `excluida`).

### H9 · Entregable ausente declarado

`PROCEDENCIA.md:40` afirma que se generó `HUELLAS.sha256`. En el momento de esta revisión **no
existe** `HUELLAS.sha256` en el directorio (ni `REVISION-MATEMATICA.md`/`REVISION-JULIA.md`), que
el encargo §6 exige. Los `REVISION-*` pueden estar en curso; la huella final no lo está.

---

## 5 · Comprobaciones que sí cierran bien

- Huella de entrada: `ENTRADA.md` = encargo, SHA-256
  `a8912ba5…5c45`; sidecar `bd3ed5…fa32`. `sha256sum -c` OK.
- `ghostdag.rs` no cableado; `fork_choice.rs` PoW lineal activo; `wire_dag.rs`
  `IntegracionPotPendiente`; `C-HDR-06/07` con código en `zx-consensus` y sin cablear.
- Ruta y API de GDR-v0.2; suite 128/128 reproducida.
- El veredicto «umbral protocolario inconcluso» coincide con el encargo dadas las reglas
  pendientes (`C-HDR-06`, R-FIN-5 no integrada, PoT AES, `C-GD-11`, R-FIN-7/F).

---

## 6 · Qué NO verifiqué

- La corrección matemática y numérica de `dp.jl`, `referencia.jl`, `controlador_rce.jl` y el
  tratamiento de cotas; es del revisor de matemáticas/Julia. Solo confirmé que la suite pasa.
- La criptografía PoT (no hay verificador que auditar) y la semántica upstream de Autonomys más
  allá de lo citado.
- No regeneré `resultados/` con `run.jl` ni ejecuté `bench/`. Reproduje únicamente la suite de tests.
- No audité una por una todas las reglas del SPEC, solo las citadas por el instrumento y las
  necesarias para el inventario `ci/`.
- No verifiqué los números de `INFORME.md` (α_prob, P_eventual, W_pub/W_priv, ICs); eso es del
  revisor de matemáticas.

---

## 7 · Veredicto

La parte de **Rust e integración** que el instrumento afirma está, en lo esencial, **bien**:
`ghostdag.rs` no está cableado, `fork_choice.rs` sigue siendo la selección lineal por trabajo PoW
en la ruta activa, `wire_dag.rs` devuelve `IntegracionPotPendiente`, y la reutilización de GDR-v0.2
es correcta, existe y se ejecuta (128/128).

El instrumento **falla en el estado normativo de tres puntos** y **exagera una integración**:

1. `C-HDR-06` no es «sin código» (H1).
2. `R-FIN-1a` es SPEC vigente vía `C-HDR-05`, no candidata; `C-HDR-05` ni aparece (H2).
3. `R-FIN-11` es SPEC vigente vía `C-GD-07`, no candidata (H3).
4. La fila «R-FIN-5 estructural + GDR» y el rótulo «R-FIN-5» del máximo de ramas en `dag_sim.jl`
   presentan como integrado lo que es un predicado aislado (H4).

Ninguno de estos puntos cambia el veredicto global «inconcluso», pero **la matriz de autoridad
debe corregirse antes de usarse como entregable normativo**, porque hoy rebaja a `candidata` dos
reglas ya adoptadas por el SPEC y describe un escenario DAG con R-FIN-5 que no se ejecuta. Se
recomienda además cerrar H5–H7 y emitir `HUELLAS.sha256`.

**Dictamen:** evidencia de integración **sustancialmente correcta en Rust, con errores de
estado normativo y una sobre-enunciación de integración; requiere corrección documental, no
cambio de código.** No emite firma de tercero.
