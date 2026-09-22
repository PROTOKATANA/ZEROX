# REVISION-RUST — CRP-v0.3 (coste-rama-privada-v3)

**Clase de revisión:** revisión en **contexto independiente** (revisor distinto del ejecutor, con
acceso al repo real). **No es firma criptográfica de un tercero.** No modifiqué código de
producción, `SPEC.md`, `TAREAS.md` ni el encargo. No hice commit.

**Fecha:** 2026-09-18. **Revisor:** revisión independiente de Rust y semántica upstream.
**Objeto:** `MATRIZ-AUTORIDAD.md`, `MODELO.md`, `INFORME.md` y las afirmaciones de integración y de
reutilización de GDR-v0.2, contra el código Rust de ZEROX y el encargo
`deepseek/ENCARGO-07v2-coste-rama-privada.md`.

---

## 0 · Alcance

Entra:

1. Estado normativo de `C-HDR-05/06/07`, `C-GD-01…11`, `C-ORD-01…04`, `R-FIN-1a/5/11/13′` y de los
   artefactos de código citados, contra `SPEC.md`, `TAREAS.md` y `ci/*.txt`.
2. Veracidad de las afirmaciones de integración: `ghostdag.rs` sin cablear, `fork_choice.rs` como
   ruta activa PoW lineal, `wire_dag` devolviendo `IntegracionPotPendiente`, guardas `ci/*.txt`.
3. Reutilización de GDR-v0.2 en `src/gdr_wrapper.jl`: ruta, API (`EstadoReferencia`, `anadir!`,
   `blueset`, `bw_de`, `gd[].blues/tipos`) y semántica.
4. Riesgo de que la compatibilidad **estructural** de flujo (`src/flujo.jl`) se presente como
   «PoT verificado».

**No entra:** dictamen matemático/probabilístico, numerismo Julia, criptografía PoT ni la
conveniencia de la política de red. La suite Julia se ejecutó solo como comprobación funcional de la
ruta GDR.

## 1 · Método

- Lectura directa: `crates/zx-consensus/src/{ghostdag,fork_choice,bloque_dag,error}.rs`,
  `crates/zx-core/src/wire_dag.rs`, `crates/zx-node/src/cadena.rs`,
  `crates/zx-p2p/src/rele_compacto.rs`, `ci/{reglas-sin-cablear,reglas-sin-codigo,consenso-pendiente}.txt`.
- Oráculo GDR-v0.2: `veritas/consenso/ghostdag-rank-v1/src/{GhostdagRank,modelo,referencia,rapido}.jl`
  y su `INFORME.md`; contraste con `src/gdr_wrapper.jl`.
- Contraste normativo con `SPEC.md` (§6.1, §7.2, §11, §16.6) y `TAREAS.md` §2.3–§2.4.
- Huellas: `sha256sum` de `ENTRADA.md` y sidecar; `diff` de la matriz contra v2.
- Ejecución reproducible de `test/runtests.jl` (76/76, `resultados/TESTS.txt`).

---

## 2 · Confirmaciones de integración (Rust)

- **`ghostdag.rs` no está cableado en `zx-node` — CONFIRMADO.** `crates/zx-node/src/cadena.rs:23`
  importa solo `zx_consensus::fork_choice`; un `grep` de `ghostdag` en `crates/zx-node/src/` da cero.
  El almacén se exporta (`crates/zx-consensus/src/lib.rs:18,35`) y solo lo consumen el propio crate
  y sus tests. Coincide con `MATRIZ-AUTORIDAD.md:27`, `ci/reglas-sin-cablear.txt:37-73` y
  `ci/consenso-pendiente.txt:23-38`.
- **`fork_choice.rs` es selección PoW lineal — CONFIRMADO.** Decide por trabajo acumulado PoW
  (`crates/zx-consensus/src/fork_choice.rs:24,79,100-108`) y la ruta está viva:
  `cadena.rs:23,342-355` usa `preferir`; el comentario `cadena.rs:413` se refiere a `extender`, no a
  `adoptar`. Coincide con `MATRIZ-AUTORIDAD.md:28`.
- **`wire_dag` devuelve `IntegracionPotPendiente` — CONFIRMADO.**
  `crates/zx-core/src/wire_dag.rs:349,375-383` devuelve siempre `Err`. También
  `crates/zx-p2p/src/rele_compacto.rs:733-738`. Coincide con `MATRIZ-AUTORIDAD.md:37`.
- **`C-HDR-06` es interfaz sin cablear, no «sin código» — CONFIRMADO.**
  `crates/zx-consensus/src/bloque_dag.rs:79-135` define `ContextoRangoDag` y
  `comprobar_rango_contextual`; no hay llamada desde `zx-node`. `MATRIZ-AUTORIDAD.md:36` lo refleja.
- **Guardas `ci/` — COHERENTES.** `C-GD-10` y `C-ORD-04` están en `ci/reglas-sin-codigo.txt:180-181`;
  `C-GD-11` en `:182-188`; `C-NET-31/32` en `:161-162`; `C-GD-01…09` y `C-ORD-01…03` en
  `ci/reglas-sin-cablear.txt:45-73`.
- **Huellas — OK.** `ENTRADA.md` = encargo `a8912ba5…5c45`; sidecar `bd3ed5…fa32`; `sha256sum -c`
  correcto.

---

## 3 · Hallazgos

### H1 · Fuente del SPEC mal atribuida para `C-NET-31/32` (error de fila)

`MATRIZ-AUTORIDAD.md:46` cita `SPEC.md` **§2.7** para `C-NET-31/32`. Esa sección **no existe**
(`grep` de `2.7` en `SPEC.md`: sin resultados); las reglas están en **§16.6**
(`SPEC.md:2971-3005`, `C-NET-31` en `:2976` y `C-NET-32` en `:2997`). Corresponde además a lo que
dice el propio repo en `ci/reglas-sin-codigo.txt:128-131` («§16.2, §16.5 y §16.6»). La fila hereda
el error sin corregirlo.

### H2 · La matriz es byte-idéntica a la de v2, contra lo que declara `MODELO.md`

`diff` de `coste-rama-privada-v2/MATRIZ-AUTORIDAD.md` contra `coste-rama-privada-v3/MATRIZ-AUTORIDAD.md`
da **cero diferencias**. `MODELO.md:54` afirma que va «copiada de v0.2, **con las correcciones de
estado normativo**»: no hay ninguna corrección. Las correcciones de v2 (H1–H3 del dictamen previo:
`C-HDR-06`, `C-HDR-05`, `R-FIN-11`) ya estaban en v2 antes de copiar, pero el texto de v3 induce a
creer que se revalidó la matriz y no se hizo. Los errores H1, H8 y H9 de este dictamen son,
precisamente, filas no revisadas.

### H3 · `R-FIN-13′` rebajada a `candidata` cuando el SPEC la declara vigente en su acoplamiento

`MATRIZ-AUTORIDAD.md:43` marca `R-FIN-13′` como `candidata`, integración `no`, dependencia
`ventana`. Pero `SPEC.md:1363-1365` dice literalmente: «El acoplamiento R-FIN-13′ —retarget y
emisión contabilizan el mismo conjunto pagable— **sigue vigente** y no depende de esta regla»
(véase también `SPEC.md:1289-1290`). `TAREAS.md:186-187` trata `R-FIN-13′` como la regla operativa
y acota lo pendiente a arranque/ventana/redondeos/fusiones, no al acoplamiento. Lo correcto es
desdoblarlo: **`SPEC vigente` en el conjunto pagable** y `pendiente` en la ventana/arranque, no
`candidata` en bloque.

### H4 · Ruta corta por `flujo_id` en `compatible_rfin5` relaja R-FIN-5

`src/flujo.jl:40` devuelve `VALIDA` en cuanto `flujo_B.flujo_id == flujo_X.flujo_id` y
`flujo_B.autenticado`, **sin comparar prefijos ni autenticar `pot_origin`/`N(s)`**. R-FIN-5 es
comparación de prefijo en `slot(X)` de **todo** `past(B)`
(`research/dag-poas-ancla-de-orden.md:223`). Un descriptor que declare el `flujo_id` del flujo
público saltaría el filtro. En el barrido no se dispara porque `construir_flujo` fija `flujo_id=rama`
(`flujo.jl:52-65`), pero el predicado no implementa la semántica que dice implementar. Debe
comparar los campos autenticados, no la etiqueta de flujo.

### H5 · Riesgo del punto 4: «PoT verificado»

No aparece la cadena «PoT verificado» en el instrumento (`grep` vacío) y `CONTRATO.md:38`,
`MATRIZ-AUTORIDAD.md:41` y `MATRIZ-VALIDEZ.md:7` lo etiquetan «estructural». **Riesgo contenido.**
Pero hay un resquicio de redacción: `INFORME.md:16` usa como condición «descriptor **autenticado**»
y `MODELO.md:28-32` repite «autenticado». `DescriptorFlujo.autenticado` es un `Bool` que fija el
propio instrumento (`flujo.jl:19,53-65`); no hay autenticación criptográfica. El test solo comprueba
que `autenticado=false ⇒ PENDIENTE` (`test/runtests.jl:78-82`). Debe decir «marcado autenticado (sin
verificación criptográfica)» para no confundir compatibilidad estructural con PoT verificado.

### H6 · `MATRIZ-VALIDEZ.md:7` clasifica `Válida` con `C-GD-11` ausente

La fila «DAG con red» es `Válida estructural / Pendiente cripto`. `C-GD-11` decide **validez de la
fusión** y sigue con cinco pendientes (`SPEC.md:1779-1797`), y GDR no lo implementa
(`ci/reglas-sin-codigo.txt:182-188`). El encargo §0 ordena que una decisión ausente —incluido
`C-GD-11`— «nunca se resuelve localmente para obtener `Válida`». La propia
`MATRIZ-AUTORIDAD.md:22` ya dice «validez de fusión condicionada», lo que delata la incoherencia.
Corresponde `Pendiente` o una condición explícita de que `C-GD-11` no invalida ninguna fusión.

### H7 · La matriz no cita las guardas `ci/` que sostienen su estado

`MATRIZ-AUTORIDAD.md` cita `ci/reglas-sin-codigo.txt` tres veces (`:21,:26,:46`) pero **no cita
nunca** `ci/reglas-sin-cablear.txt` ni `ci/consenso-pendiente.txt`, pese a que el encargo los lista
como fuentes (`ENTRADA.md:61`) y a que en ellos vive la prueba de «implementada sin cablear». Las
filas `ghostdag.rs` (`:27`) y `fork_choice.rs` (`:28`) deberían referenciarlas.

### H8 · Imprecisiones menores de filas (heredadas)

- `MATRIZ-AUTORIDAD.md:13`: «`BW256` en GDR / `checked_add` Rust». En Rust es correcto
  (`ghostdag.rs:274-284`); pero el oráculo acumula `blue_work` en `BigInt`
  (`referencia.jl:229-232`) y `BW256` es solo el peso por bloque (`modelo.jl:74-83`). El oráculo no
  impone la cota `u256`.
- `MATRIZ-AUTORIDAD.md:14`: `C-GD-03` «depende de C-GD-10». La selección de `sp` entre los padres
  dados no depende de qué padres decide tomar el productor; la dependencia real es de la simulación
  de producción.
- `MATRIZ-AUTORIDAD.md:28`: la columna *estado normativo* de `fork_choice.rs` contiene «ruta activa
  (PoW lineal)», que no es uno de los estados admitidos por el encargo §0.
- `MATRIZ-AUTORIDAD.md:46`: «valores pendientes» para `C-NET-31/32`. Solo `C-NET-32` tiene valor
  pendiente (`SPEC.md:2997-3005`); `C-NET-31` está cerrado.

---

## 4 · Reutilización de GDR-v0.2 (`src/gdr_wrapper.jl`)

**Ruta — CORRECTA.** `gdr_wrapper.jl:9-14` sube cinco niveles desde `src/` hasta la raíz del repo y
resuelve `veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl`; el archivo existe y la suite lo
carga.

**API — EXISTE y coincide** (`veritas/consenso/ghostdag-rank-v1/src/`):

| Uso del wrapper | Definición | Veredicto |
|---|---|---|
| `EstadoReferencia(params, id_genesis)` | `referencia.jl:20,36` | firma válida |
| `anadir!(est,params,id,padres,slot,sd,sr,ident)` | `referencia.jl:165-166` | firma idéntica; `Bool` |
| `est.n` / `est.motivo` / `est.gd` | `referencia.jl:22,31,30` | campos públicos |
| `gd.blues` | `referencia.jl:10,196,254` | `[sp, …]`; el comentario del wrapper (`gdr_wrapper.jl:57-58`) es correcto |
| `gd.tipos` | `referencia.jl:12,210,224` | `0x01` rojo_k, `0x02` rojo_U3; mapeo correcto (`gdr_wrapper.jl:51-54`) |
| `bw_de(est,i)` | `referencia.jl:34` → `gd[i].bw` | existe; no exportado, pero se llama cualificado (`gdr_wrapper.jl:61`) |
| `peso_big`, `tips`, `blueset` | `modelo.jl:86,230,248` | existen y son exportados |
| `Params(; k, s_max)` | `modelo.jl:125-141` | keyword válido; `u2=true`, `u3_mode=U3_DYNAMIC` por defecto |

**Semántica — correcta en lo esencial.** `gd[i].bw` **excluye** el peso propio del bloque
(`referencia.jl:229-237`), lo que el wrapper declara (`gdr_wrapper.jl:74-75`); no hay doble conteo
oculto. `blue_work_mergeset` (`gdr_wrapper.jl:64-72`) excluye `gd.sp`, coherente con `blues=[sp,…]`.
`color_contextual` usa el `gd` del fusionador, de modo que el color es contextual (C-GD-09), no
global.

**Observaciones de la capa GDR, no del wrapper:**

- El wrapper llama «GDR-v0.2» a lo que vive en `ghostdag-rank-v1/`, pero los propios fuentes se
  titulan «GDR-v0.1» (`referencia.jl:1`, `modelo.jl:1`); `INFORME.md` de GDR se titula «GDR-v0.2».
  Es un desajuste de etiqueta del upstream, no del instrumento.
- El wrapper no expone `u3_mode`; usa el defecto `U3_DYNAMIC`, que es el que el SPEC describe. Aceptable.
- El wrapper instancia el oráculo lento (`EstadoReferencia`) a propósito; coincide con lo declarado
  (`gdr_wrapper.jl:16-19`).

---

## 5 · No verificado

- La corrección matemática/numerística de `dp.jl`, `eventos.jl`, `referencia.jl` y
  `controlador_rce.jl`, y la validez de `P_terminal/P_first_passage/P_eventual`, `α_prob` e ICs: es
  del revisor de matemáticas/Julia. Solo reproduje que la suite pasa (76/76).
- La criptografía PoT (no hay verificador que auditar; `wire_dag.rs:375-383` siempre devuelve
  `IntegracionPotPendiente`) y la semántica upstream de Autonomys más allá de lo citado.
- No regeneré `resultados/` con `run.jl` ni ejecuté `bench/`; no audité cifra a cifra el `INFORME.md`.
- No audité todas las reglas del SPEC, solo las citadas por el instrumento y las del inventario `ci/`.
- `HUELLAS.sha256` y las revisiones `REVISION-MATEMATICA.md`/`REVISION-JULIA.md` **no existían** al
  escribir esta (entregables del encargo §6 en curso; esta es una de las tres).
- No verifiqué que `MATRIZ-AUTORIDAD.md` describa correctamente reglas fuera del alcance de Rust
  (p. ej. R-FIN-2/3/14, DAV/DCM/CBE/DMS).

---

## 6 · Veredicto

La parte de **Rust e integración está, en lo esencial, bien**: `ghostdag.rs` no está cableado,
`fork_choice.rs` es la ruta activa PoW lineal, `wire_dag` devuelve `IntegracionPotPendiente`, la
interfaz de `C-HDR-06` existe sin cablear, las guardas `ci/*.txt` coinciden y la reutilización de
GDR-v0.2 es correcta, existe y se ejecuta (76/76 reproducido). El riesgo del punto 4 (presentar la
compatibilidad estructural como «PoT verificado») está **contenido**, aunque persiste el resquicio
de redacción de «descriptor autenticado» (H5) y la ruta corta por `flujo_id` (H4).

El instrumento **falla en la matriz de autoridad**, que no fue corregida pese a declararlo:

1. `C-NET-31/32` citan `SPEC.md` §2.7, sección inexistente; su sede es §16.6 (H1).
2. `MATRIZ-AUTORIDAD.md` es byte-idéntica a la de v2, contra `MODELO.md:54` (H2).
3. `R-FIN-13′` es `candidata` cuando `SPEC.md:1363-1365` la declara «vigente» en su acoplamiento (H3).
4. `MATRIZ-VALIDEZ.md:7` etiqueta `Válida` un escenario sin decisión de `C-GD-11` (H6).
5. Faltan las referencias a `ci/reglas-sin-cablear.txt` y `ci/consenso-pendiente.txt` (H7), y
   persisten imprecisiones menores (H8).

Ninguno de estos puntos cambia el veredicto global —**umbral protocolario inconcluso**—, que es el
correcto dadas `C-HDR-06`, R-FIN-5 no integrada, PoT AES ausente, `C-GD-11` y R-FIN-7/`F`. Pero la
matriz debe corregirse antes de usarse como entregable normativo, y debe quitarse la afirmación de
`MODELO.md:54` de que hubo correcciones que no existen.

**Dictamen:** integración Rust y uso de GDR-v0.2 **correctos en lo sustancial**; **errores de
clasificación y de atribución en `MATRIZ-AUTORIDAD.md`/`MATRIZ-VALIDEZ.md`** y una relajación
semántica en el predicado R-FIN-5. Requiere corrección documental y del predicado, no cambio de
código de producción. No emite firma de tercero.
