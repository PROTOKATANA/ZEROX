# TAREAS — lo que falta para que el SPEC PoST + DAG pase a fase de código

Fecha: 2026-09-12; actualizado el 2026-09-23. Derivado de §17 de [SPEC.md](SPEC.md),
`ci/consenso-pendiente.txt`, los límites declarados de los instrumentos de `veritas/`,
[MIGRACION.md](MIGRACION.md), la auditoría externa de la comprobación decisiva v1
([AUDITORIA-EXTERNA.md](veritas/consenso/comprobacion-decisiva-v1/AUDITORIA-EXTERNA.md)) y las
decisiones de Katana sobre `Δ` del 2026-09-13 (§3.1).

No congela parámetros ni convierte pendientes en decisiones. Los niveles 1 y 2 separan «el SPEC
describe un protocolo» de «el SPEC especifica un protocolo». El nivel 3 separa «se puede
implementar» de «se puede lanzar».

---

## Nivel 1 — Forks latentes: el SPEC no es determinista aquí

Escribir código contra estos puntos produce nodos que discrepan. Son el único bloqueo duro. Tras
cerrar 1.2 y 1.3 en el SPEC el 2026-09-15 y 1.4 el 2026-09-17, el Nivel 1 **no tiene contenido
pendiente**: las tres están especificadas sin ambigüedad y las tres tienen código. Lo que queda es
integrarlo en la ruta activa, y eso es **§2.8**, Nivel 2.

### 1.2 · `rank`: especificado, implementado y sin cablear

§7.2 fija el desempate entre copias (P1: azul primero, luego `rank`, luego id de bloque), pero
`rank` es hoy una etiqueta abstracta suministrada — CONTRATO de DCM-v0.1: «Rank y color son
etiquetas globales suministradas, no recalculadas». Hay que atarlo al orden concreto del mergeset
(`blue_work`, `solution_distance`, hash) y **demostrar que es total**. Un empate hace el desempate
no determinista, y eso es un fork. Fue el PENDIENTE de §7.2 hasta el 2026-09-15.

**Estado: CERRADO EN EL SPEC (2026-09-15).** `rank` ya está redactado como **C-ORD-01** y P1 como
**C-ORD-02**, con el orden de aplicación en **C-ORD-03** (SPEC §7.2).
- `rank = (blue_work, solution_distance, id)` ascendente, y el id final es obligatorio: es lo que
  ancla la totalidad.
- **Decidido por Katana (2026-09-15):** P1 **pierde** su desempate final por id, porque `rank` ya
  es total y ya termina en ese id. Demostrado, no solo comprobado.
- Las demostraciones de totalidad y de compatibilidad causal están resumidas en el SPEC y completas
  en `veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md`.
- **El código ya existe** (2026-09-17): `crates/zx-consensus/src/ghostdag.rs` calcula `rank` como
  `(blue_work, solution_distance, id)` y `seleccionar_copia` resuelve P1 sin tercer desempate. Un
  test comprueba que `rank` es total sobre el corpus, que es lo que sostiene esa ausencia.
- **Lo que queda es cablearlo** (§2.8): los fixtures de DCM-v0.1 siguen suministrando `rank` y color
  como etiquetas en vez de recalcularlos, y C-ORD-01…03 están en `ci/reglas-sin-cablear.txt`.

### 1.3 · GHOSTDAG: especificado, implementado y sin cablear

El color (azul / `rojo_k` / `rojo_U3`) lo suministra hoy el oráculo del fixture; DCM-v0.1 declara
que «no acredita la coloración ni el orden contextual de GHOSTDAG». Con P1 decidido, el desempate
de §7.2 **no es computable** hasta que la coloración sea determinista y acordada por todos los
nodos. La elegibilidad ya dependía del color por R-FIN-8′, así que P1 no añade una dependencia
nueva, pero la vuelve crítica para el pago.

**Dirección de los desempates — DECIDIDO POR KATANA (2026-09-14): opción C de GDR-v0.1 (D-1/D-2).**

- **Orden del mergeset**, el mismo para colorear (U3″) y para aplicar (R-FIN-8′(4)):
  `(blue_work, solution_distance, hash)` ascendente, con el hash comparado byte a byte.
- **Padre seleccionado** (y punta virtual): el de mayor `blue_work`. Si hay empate, el que va
  primero en ese orden: menor `solution_distance` y, después, menor hash.
- **`rank` para P1:** la misma tupla, en orden ascendente; gana el menor.
- **Motivo:** dos hermanos con los mismos padres tienen siempre el mismo `blue_work`, así que el
  desempate del padre es el caso común. Con C, el orden de aplicación entre hermanos y la copia
  superviviente de un billete son los mismos tanto si llegan como padres como si llegan dentro de
  un mergeset. Con la lectura `:spec`, entre hermanos va primero el de mayor `solution_distance`;
  la lectura `:python` reproduce el error de `r8c_gd.py`.
- **Coste:** se aparta del patrón de Kaspa (padre = máximo del mismo orden) y obliga a redactar
  dos reglas en vez de una.
- **Comprobado por Claude** (regla sustituida en memoria sobre GDR-v0.1, sin tocar el
  instrumento):
  - hermanos y copias, coherentes;
  - oráculo = kernel en 1 800 DAGs con k de 1 a 30;
  - 1 000 órdenes de llegada idénticos en dos familias;
  - todo padre tiene menor `rank` que su hijo.
- **Pendiente derivado:**
  - **hecho (2026-09-14):** GDR-v0.2 (`veritas/consenso/ghostdag-rank-v1/`) implementa C con un
    oráculo de claves propias, derivaciones con hora verificable y demostraciones escritas de
    `rank`;
  - **hecho (2026-09-15):** redactado en el SPEC. §11 pasa a nueve reglas, **C-GD-01** a
    **C-GD-09** (peso, dominio de `blue_work`, padre seleccionado, mergeset, orden, coloreo,
    U2/U3″, acumuladores y determinismo), y §7.2 a **C-ORD-01** a **C-ORD-03**;
  - **D-5 decidido por Katana (2026-09-15):** `blue_work` se representa en **u256**, con
    desbordamiento como fallo explícito de consenso por C-ENC-03. No se hereda `Uint192` de Kaspa:
    desbordaría al acumular 2⁶⁴ contribuciones máximas y ZEROX no declara tope de bloques. El
    repositorio ya usaba `u256` como tipo de codificación (SPEC §2) y `TrabajoAcumulado(U256)` con
    suma comprobada (`crates/zx-core/src/target.rs:273-292`);
  - **hecho (2026-09-17):** `crates/zx-consensus/src/ghostdag.rs` implementa las doce reglas, con
    una referencia transparente y un kernel comparados entre sí, contra el oráculo Julia GDR-v0.2 y
    contra los vectores oficiales de rusty-kaspa. Determinismo comprobado con 3 000 órdenes de
    llegada barajados;
  - **lo que queda es cablearlo** (§2.8): el nodo sigue eligiendo cadena con `fork_choice.rs`, así
    que las doce están en `ci/reglas-sin-cablear.txt`, no en `ci/reglas-sin-codigo.txt`.

### 1.4 · La cabecera DAG: SPEC cerrado, falta cablear

**Estado: CERRADO EN EL SPEC (2026-09-17).** Igual que 1.2 y 1.3: lo que queda es código del nodo,
no SPEC.

- **Qué quedó fijado.** §6.1–§6.2 describen el formato completo: layout de la cabecera DAG con sus
  offsets y tamaños (`589 + 32·(P−1)`, con `P` entre 1 y 15: 589/621/1 037 B), prefirma (C-HDR-03),
  justificación PoT con `pot_bundle_count == slot(B) − slot(sp(B))` (C-HDR-07) y codec único para
  wire, `pre_hash`, `block_hash` e IDs cortos (C-HDR-09). Los máximos de transporte se derivan de
  esas fórmulas: 19 200 B de payload, 19 201 B codificados y 20 238 B de cabecera más
  justificación (Q2). C-HDR-06 quedó reescrita para el contexto DAG y prohíbe la circularidad con
  el `rango_solucion` declarado.
- **Qué no se cierra aquí.**
  - La **integración en `zx-node`**: la ruta activa sigue ligada a la cabecera lineal; hasta
    cablearla, `el_codigo_alcanza_la_base_poas_de_556` sigue ignorado y la discrepancia 92/556
    persiste. El test rojo es ahora ese, no `el_spec_dice_el_tamano_real_de_la_cabecera`, que
    dejó de existir.
  - El **controlador de rango** —ventana, bootstrap, redondeos y fusiones fuera de ventana—,
    TAREAS §2.3.
  - La **validación completa de cuerpo** y el estado UTXO, §2.6.
  - El **caso degradado del relé compacto**, que es transporte (§2.7), no formato de bloque.

**Presupuesto de diseño** (Q2 de §3.1, decidido por Katana el 2026-09-13): el formato de §6.1 lo
respeta. Cabecera ≤ ~1 kB en el caso típico y ≤ ~20 kB en el peor, que son 15 padres y 150 slots
de justificación PoT; anuncio compacto ≤ ~28 kB en el techo; relé compacto obligatorio en la ruta
crítica.

La r2 de `DMS-v0.1` midió 1,14–1,39 padres típicos, es decir, una cabecera típica de ≈716–748 B.

---

## Nivel 2 — Reglas escritas que todavía no se pueden computar

### 2.1 · Dependencias por flujo del PoT (§7.1) — CERRADO EN EL SPEC (2026-09-20), FALTA CABLEAR

> **CORRECCIÓN DEL TITULAR, y hay que leerla antes que el resto de la sección.** Este apartado se
> tituló «🔴 AQUÍ ESTÁ EL PROBLEMA DE SEGURIDAD» porque `1/(S+1)` —el **4 %** con `S ≈ 24`— se leyó
> como el umbral del diseño. **No lo es.** `1/(S+1)` es la **regla aditiva** —`S` flujos
> independientes suman cuota— y **no aplica con pasado consistente de flujo**: bajo `C-FLU-14` un
> bloque no puede referenciar un bloque de otro flujo, así que los flujos del atacante no se
> agregan a una sola cadena. **El propio instrumento ya lo etiquetaba así**: CRP-v0.1 declaró su
> resultado «condicionado al diseño del flujo, no demostrado»
> (`veritas/seguridad/coste-rama-privada-v1/`). En su baseline idealizado de un flujo,
> `α_drift = 1/2`; **no es un umbral global acreditado para ZEROX**. P-CRP auditó v0.2/v0.3
> sin validarlas ni migrarlas y declaró el veredicto protocolario **INCONCLUSO** (§2.9(e)). **Lo que
> este cierre corrige es el titular del 4 %, y no lo sustituye por otro titular ancho.**
>
> **Lo que el multistream sí obligaba a decidir era la bifurcación**, y Katana la decidió: validez
> **absoluta** (`C-FLU-13`) con perfil **1a**. Su precio no es el 4 %: es la **partición de flujo**,
> que no se cierra con una regla y se previene con `L_slots` frente a `Δ`.

**Estado: CERRADO EN EL SPEC, 2026-09-20.** Redactadas **31 reglas** en §7.1.1–§7.1.7, §12, §14.3
y §16.6: `C-POT-01`…`C-POT-08`, `C-FLU-01`…`C-FLU-18`, `C-FLU-20`…`C-FLU-22`, `C-FIN-01` y
`C-NET-33`. Familias nuevas: `C-POT`, `C-FLU`, `C-FIN`. `C-FLU-19` **no existe** y no se reutiliza.
Reglas existentes modificadas: `C-HASH-06`, `C-HDR-05`, `C-HDR-06`, `C-HDR-07`, `C-GD-04`,
`C-GD-10`, `C-REORG-07`, `C-NET-31`, `C-NET-32`.

Procedencia: `veritas/consenso/pot-primitiva-v1/` y `veritas/consenso/regla-flujo-v1/` (propuestas
validadas), sobre `veritas/consenso/ancla-inyeccion-v2/` y `veritas/consenso/puerta-cobertura-v1/`
(instrumentos validados). El hilo completo de decisiones, en `P-ZRX/P-2.1/SINTESIS.md`.

**Lo que queda, y es mucho:**

- **El código: sigue faltando casi todo, pero ya hay piezas PoT aisladas.** `C-FLU-02` tiene
  comprobación de todos los padres en los componentes DAG. Los encargos 03a–03c añadieron la
  primitiva AES, el adaptador de un slot, las derivaciones puras de semilla y reto, y un núcleo de
  rango con tres estados, caché contextual y anclaje en `pot_output`. Las reglas con código
  parcial están en `ci/reglas-sin-cablear.txt`; las que aún carecen de código siguen en
  `ci/reglas-sin-codigo.txt`. Ninguna de estas piezas PoT se ejecuta en la ruta lineal de `zx-node`.
- **Dos reglas existentes cambiaron de semántica y su código no está en la ruta activa:**
  `C-HDR-05` (la cota de slot alcanza ahora a **todos** los padres; los componentes DAG ya la
  comprueban para el seleccionado y los adicionales, pero `zx-node` continúa con la cabecera lineal
  y `fork_choice.rs`) y `C-HDR-07` (el `pot_output` es la salida futura y el último checkpoint la
  ancla; el verificador devuelve `IntegracionPotPendiente`). Declaradas en
  `ci/reglas-sin-cablear.txt`, con el precedente de C-NET-07.
- **Falta acreditar la procedencia contextual del PoT.** El núcleo de 03c comprueba el rango
  suponiendo que su instantánea procede de `past(B)` validado; no existe todavía el derivador de
  flujo, vista de época, ancla y salida base que pueda satisfacer esa precondición en producción.
- **Las mediciones que faltan: §2.9.**

---

**El registro de cómo se llegó aquí se conserva íntegro a partir de esta línea.**

Solución de espacio, testigos KZG, identidad de billete, reto, distancia de solución, sello y
justificación PoT. Pendiente además: formato y validación conjunta, retardo de autoría, puntos de
control, inyección de entropía y **dependencias por flujo**.

**Esa última línea motivó CRP-v0.1 el 2026-09-18.** La auditoría posterior
`P-ZRX/P-CRP/auditoria/INFORME.md` limita sus conclusiones: CRP-v0.1 es un **baseline
idealizado**, no una medición del umbral del protocolo completo.

- **Deriva en el baseline:** `α_drift = 1/2` es una identidad de ese modelo de un solo flujo;
  **no** acredita el umbral global de ZEROX, ni las colas corta/larga con controlador, red y
  finalidad del protocolo destino.
- **Rango en ese modelo:** la cancelación de tasa por peso vale bajo las hipótesis de tasa y
  rango comunes allí declaradas. P-PUERTA encontró un residuo de paridad (§2.3) y P-RANGO
  redactó una forma candidata de controlador; ni eso ni una media preservada acreditan su
  comportamiento en ramas privadas completas con `blue_work` real.
- **Multistream aditivo contrafactual:** la fórmula siguiente suma flujos independientes. Bajo
  `C-FLU-14` esos flujos no pueden agregarse a una sola ancestría válida; la tabla **no** es
  un umbral del diseño ni prueba que el doble farmeo en ramas separadas esté resuelto.
  Cuota efectiva del contrafactual `S·α/(1−α+S·α)` ⟹ `α_drift = 1/(S+1)`:

  | `S` | 2 | 4 | 8 | 16 | 24 |
  |---|---:|---:|---:|---:|---:|
  | `α_drift` contrafactual | 0,333 | 0,200 | 0,111 | 0,059 | **0,040** |

  `S = 24` fue un escenario de SSD/IOPS, **no** un límite adversario universal: CPU, tamaño
  de granja y paralelismo cambian el cuello de botella (P-PUERTA §2–3).

**No es un hallazgo nuevo: es el ATAQUE 2** de `research/dag-poas-auditoria.md` (2026-09-06),
calificado allí de **gravedad crítica** y con el estado «SOSPECHA fuerte — depende de una regla
(validez del PoT en DAG) que la propuesta no escribe». CRP-v0.1 cuantificó **ese contrafactual**;
la auditoría P-CRP deja inconcluso el umbral protocolario, no identifica un «único» vector global.

⚠️ **La auditoría avisaba de que las dos salidas obvias fallan:** si la validez del PoT es
**relativa a la cadena seleccionada**, se abre el multistream; si es **absoluta**, se abre el split
de cadena (ATAQUE 1). **DECIDIDO por Katana el 2026-09-19/20: validez absoluta, perfil 1a.** El
split no se cierra con una regla: se **previene** con `L_slots` frente a `Δ` y, si nace, se cura
**solo** en el caso espontáneo (`C-FLU-22`). Ver §2.9.

**Rojos asimétricos:** CRP-v0.1 no midió una frontera con rojos contextuales y red adversaria.
La Δ de 0,26–0,60 s procede de una **red sintética**, no de una red ZEROX desplegada; un resultado
de fracción roja en ese escenario no demuestra que el umbral global sea invariante
(`P-ZRX/P-CRP/auditoria/INFORME.md` §7–8).

**La parte de red ya está decidida** (Q4 de §3.1, 2026-09-13):
- antes de reenviar se comprueban cabecera, prueba de espacio, 2 KZG, sello, justificación PoT
  (desde la caché) y compromiso Merkle;
- después, firmas, pruebas Halo2 y UTXO;
- el PoT se verifica una vez por slot y se cachea.

Eso fija el orden, no la verificación conjunta en sí, que sigue pendiente. Las reglas que faltan
por escribir están en §2.7.

**La primitiva PoT está integrada y el núcleo de rango sigue aislado.** `crates/zx-pot` incorpora
`prototipos/pot-estable` —el AES de Autonomys con sus 32 vectores diferenciales— y
`zx-consensus::pot::verificar_slot_aes` verifica un slot: la semilla y `N(s)` no viajan en los
checkpoints del wire, pero llegan como **argumentos libres** y el adaptador **no acredita su origen
causal** (encargo 03a). El encargo 03c añadió `zx-consensus::pot_rango`, que verifica un rango
contra una instantánea contextual; falta el derivador que acredite esa instantánea desde el pasado
DAG validado. Ninguna ruta de `zx-node` llama al núcleo, y
`zx-core::wire_dag::verificar_justificacion_pot` sigue devolviendo `IntegracionPotPendiente` de
forma explícita en vez de un booleano provisional. Mientras siga así, C-HDR-07 está en
`ci/reglas-sin-cablear.txt` y nadie exige la justificación.

### 2.2 · La identidad del billete está supuesta, no demostrada
Toda §7.2 —dedup, unicidad pagable, peso— se apoya en que el billete identifique de verdad la
oportunidad. En los instrumentos eso es una declaración del fixture. La propiedad real depende de
`veritas/consenso/contrato-billete-v1/` y de C-HDR-03/04 (dos firmas Ed25519 bajo la misma
`public_key`). Es el límite H7 del INFORME; es el cimiento de lo que §7.2 acaba de cerrar.

### 2.3 · Rango: lo que R-FIN-13′ no cierra
Arranque por red, ventana, límites y redondeos, fusiones fuera de ventana y validación de ramas
candidatas con pesos reales. Conservado a propósito en el «Pendiente» de §7.2.

**Residuo de paridad del `SR`, anotado el 2026-09-20.** Bajo el predicado PoAS de Autonomys
examinado por PCO-v0.1, un `SR` par acepta `SR+1` valores y uno impar acepta `SR`; el peso
vigente divide por `SR+1`. Por eso, en el modelo de tasas de PCO, la cancelación media tiene
un déficit exacto de `1/(SR+1)` para `SR` impar. El ejemplo ≤ 4,9·10⁻⁴ presupone
`SR_MIN = 2^11`, **valor no adoptado**. El efecto del controlador completo y de ramas privadas
con pesos reales sigue pendiente. Fuente y condición:
`P-ZRX/P-PUERTA/veritas/consenso/puerta-cobertura-v1/INFORME.md` §1.1.

**P-RANGO (2026-09-22): propuesta, no cierre.** `P-ZRX/P-RANGO/propuesta/` redacta
`C-RET-01`…`C-RET-11` y comprueba aritmética local. El acoplamiento del rango validado con
el rango que pesa es una precisión de las reglas vigentes, pero P2/P3 **no tienen veredicto**
sobre una rama privada completa con controlador en el bucle y pesos reales. Siguen pendientes
`δ`, los valores del controlador, la relación de `G_slots` con C-GD-11 y la viveza de `Pending`
(`INFORME.md` §2). Las once reglas no están listas para traslado íntegro al SPEC.

**Encargo 02 (2026-09-22) y 02c: puerta parcial de SR, unicidad e intercambio cerrados.** Hay dos
entradas separadas por nombre y por firma. `AlmacenGhostdag::admitir(cabecera, sd, identidad, ctx)`
es la **puerta parcial de validación del `SR`**: valida C-HDR-06 con la **misma** cabecera cuyo
`block_hash` inserta y no acepta ni el `SR` ni el id, así que no se puede usar para colar un rango
libre ni para mover un resultado validado a otro bloque (un rango validado para `A` en un bloque con
id de `B` es `RangoDeOtroBloque`). **No** es una admisión PoST de producción: no verifica prueba de
espacio/tiempo, firma, cuerpo ni el resto de reglas. `AlmacenGhostdag::anadir_sintetico(BloqueGhostdag)`
es la entrada de oráculos/tests: **no valida** y sigue siendo API pública, de modo que un llamante
puede saltarse C-HDR-06 con `RangoSolucionValidado::para_oraculos`; se conserva como hueco declarado
con tests adversariales en `tests/ghostdag_rust.rs`. Ambas rechazan un `block_hash` ya almacenado con
`BloqueDuplicado` antes de mutar nada: es duplicado de almacenamiento, no invalidez PoST ni motivo
para penalizar al par. `acumular` usa el peso del rango y un azul sin `SR` almacenado es
`GhostdagIncoherente` explícito. Sigue **sin ruta activa en `zx-node`**, el controlador (ventana,
bootstrap, redondeos) continúa pendiente, y la precondición de fondo es que `ContextoRangoDag` derive
el esperado del pasado y del flujo: la vista opaca solo bloquea el acceso directo, así que **no**
prueba esa derivación. Esto no cierra C-HDR-06, ni P2/P3, ni los valores del controlador, ni el
acoplamiento con el retarget.

### 2.4 · Orden, conflictos y las tres reglas de Kaspa — TRES DE CUATRO REDACTADAS (2026-09-17)

Cadena seleccionada, peso, `blue_work` y orden de aplicación del mergeset ya estaban redactados
(C-GD-03, C-GD-05, C-GD-08 y C-ORD-03, desde el 2026-09-15). El 2026-09-17 se cierran tres de los
cuatro puntos que quedaban. **Dos de ellos no había que decidirlos: estaban decididos en
investigación y nadie los había escrito como regla.**

| Punto | Estado | De dónde salía |
|---|---|---|
| Conflictos de transacciones | **C-ORD-04**, redactada | R-FIN-8′(5), ya decidido |
| `pick_virtual_parents` | **C-GD-10**, redactada | D9-d: «R-FIN-12 nombra el `shuffle`», ya en SPEC §7.3 |
| Merge depth bound | **C-GD-11**, redactada con **5 pendientes** | Katana, 2026-09-17 |
| Pruning | **NO redactable** — auditoría abierta | — |

- **C-ORD-04** · gana el gasto que aparece primero en el orden de C-ORD-03; el otro se descarta en
  silencio, sin invalidar ni al bloque ni al fusionador; `fees` suma solo las aceptadas.
- **C-GD-10** · hasta 15 puntas de una cola de candidatos **barajada**, incluyendo siempre la punta
  virtual, y descartando las que violarían C-GD-11. Es política de **producción**: ningún
  verificador rechaza un bloque por la elección de padres de su autor. Sin el barajado, **14-21
  bloques honestos quedan fuera del DAG para siempre** (D9-d §A3.1). Laguna conservada: el
  argumento es de diversidad *entre nodos* y no aplica con un solo productor honesto.
- **C-GD-11** · *bounded merge depth* con kosherización, **decidido por Katana el 2026-09-17**: un
  rojo fuera del `merge_depth_root` que no sea ancestro de un azul kosherizante invalida al
  fusionador. **Decide validez de la fusión y nada más** — no cambia quién cobra ni qué se aplica:
  `rojo_k` por P1/R-FIN-8′, `rojo_U3` inerte. Cierra un hueco real: `mergeset_size_limit` acota el
  **tamaño** y `S_max` la distancia al **padre seleccionado**, pero un bloque viejo cuyo pasado ya
  está íntegro en `past(sp(B))` entra sumando **1** y ninguno de los dos lo toca.
  **Cinco pendientes, por orden expreso de Katana:** métrica (slots / `blue_score` / posiciones),
  valor, bootstrap, borde de igualdad, y relación con finalidad y poda. **No se copia la constante
  de Kaspa ni se deriva de `F = 2 h`**, que es provisional.

#### Pruning — AUDITADO (2026-09-17): no hay prueba de poda por niveles

Instrumento **PPP-v0.1** en `veritas/consenso/poda-post-v1/`, ejecutado por DeepSeek según
`ENCARGO-05-poda-post.md` y **validado por Claude reejecutando** (`PROCEDENCIA.md`).

> ⚠️ **Revisión externa del 2026-09-18: varios veredictos estaban sobre-enunciados.** Los defectos
> verificados están en `veritas/consenso/poda-post-v1/PROCEDENCIA.md` §3.3–§3.4, y la tabla de abajo
> ya los incorpora. **Lo que falta no es el IBD sin confianza, es el IBD *sucinto*:** un nodo nuevo
> siempre puede bajarse y validar toda la historia desde el génesis; lo que no puede es arrancar
> desde estado podado sin un ancla externa. La diferencia importa: lo primero sería un fallo de
> seguridad, lo segundo es coste y escalabilidad.

| Problema | Veredicto | Etiqueta |
|---|---|---|
| (1) **poda local** — nodo que ya validó toda la historia | **viable en principio**, sin implementar; exige finalidad integrada, estado UTXO con deshacer (§2.6, no existe) y profundidad de retención cerrada | política, no demostración |
| (2) **prueba de poda por certificados de niveles** | **descartada** para los mecanismos examinados | demostrado (D4, D5, D8), con el alcance acotado abajo |
| (3) **disponibilidad histórica** — archivales | fuera del consenso; **no resuelve (2)** | estimado |

**Lo que el teorema D5 NO demuestra**, y hay que decirlo: sus propiedades P1/P2/P3 no formalizan que
el recurso deba **pagarse de nuevo por cada ancestría**, que es lo que hace funcionar a PoW. Un
esquema que combine una condición cara pero **transferible** con otra barata ligada a los padres
satisface las tres literalmente y sigue siendo inseguro. Y el modelo **excluye el PoT y sus flujos**.
Vale para los mecanismos examinados; **no** para toda familia de pruebas.

**La raíz, y es estructural.** En PoW el hash del bloque compromete a los padres **y** es el recurso
escaso: las dos propiedades viven en el mismo objeto, y por eso los niveles funcionan. **En PoST se
separan.** El billete ganador se calcula del PoT y del disco **antes** de elegir padres (D4, 0
discrepancias), así que el mismo certificado se pega a cualquier historia; y un nivel sobre el hash
de cabecera sí liga a los padres, pero se muele con CPU y espacio ≈ 0 —C-HDR-04 reconoce que el
sello Ed25519 **no es único**, y el `merkle_root` varía con la coinbase—, así que no mide espacio.
Medido: un certificado de 64 bloques de nivel 8 es **aceptado**, y dos DAG con certificado idéntico
tienen distinto `blue_work` (comprobado con el oráculo GDR-v0.2).

**Lo que esto desbloquea: §6.1 NO se reabre.** `parents_by_level` no rescata la prueba, porque el
problema no es un campo que falte. **El cableado de la cabecera DAG (§2.8) no está bloqueado.** Era
la pregunta de máxima prioridad del encargo.

**Lo que queda abierto, y es un hueco del encargo, no de la ejecución.** El teorema cubre
**predicados de nivel**. La vía que no es un nivel —una **prueba recursiva** de la función de
transición del consenso (modelo Mina)— no cae en ninguno de sus cinco casos y no se examinó, porque
`ENCARGO-05` preguntaba por el análogo a los **niveles** de PoW. Con esa precisión, lo demostrado es
«no con certificados de niveles», no «no, en absoluto».

**Encargo 06 — decidido por Katana (2026-09-17):** auditar la vía de prueba recursiva. Es la única
candidata en pie; es cara (probar recursivamente GHOSTDAG, coloreo y `blue_work` es muy superior a
probar una cadena lineal) y puede salir un «no» por coste. `PROPUESTA.md` P3.3 avisa de la
dependencia: sin estado UTXO (§2.6) no hay qué comprometer.

**La poda sigue siendo requisito para lanzar mainnet.** Una testnet puede operar provisionalmente
sin poda y con nodos archivales declarados explícitamente, y **eso no cuenta como solución**.

### 2.5 · Alturas y calendario derivados del orden DAG
Activaciones, madurez de coinbase, timelocks, expiración de tx y sectores, archivado. MIGRACION:
«El significado de altura, orden de aplicación y madurez en DAG aún debe cerrarse antes de
trasladar esas cuentas a una garantía temporal». No escalar constantes por 120 mecánicamente.

### 2.6 · Estado UTXO con datos de deshacer
`ci/consenso-pendiente.txt` documenta que `zx-consensus::bloque::validar_bloque` no lo alcanza
nadie porque la cadena no mantiene ese conjunto — hay un `TODO(sincronizador)` en
`crates/zx-node/src/cadena.rs`. Sin eso no hay validación completa de bloque.

### 2.7 · Reglas de transporte — REDACTADAS EN EL SPEC (2026-09-17)

**Estado: CERRADO EN EL SPEC.** Salían de las decisiones de Katana del 2026-09-13 (Q1, Q2 y Q4 de
§3.1) y del 2026-09-16 (arquitectura «1+»). No son consenso, pero sin ellas la Δ medida es
optimista y el v2a no tiene qué modelar. Lo que queda es **código: ninguna de las nueve tiene una
línea**, y las nueve están en `ci/reglas-sin-codigo.txt`.

| Regla nueva | Qué fija | De dónde sale |
|---|---|---|
| **C-NET-25** | los tres canales; el bloque completo **nunca** por gossip | «1+» |
| **C-NET-26** | relé compacto **obligatorio**, sin negociación por conexión | Q2 |
| **C-NET-27** | anuncio sin padres → cola acotada y reevaluación (tamaño PENDIENTE) | «1+» |
| **C-NET-28** | pedir lo que falta es el camino ordinario; bloque entero, último recurso | Q2 + «1+» |
| **C-NET-29** | prioridad estricta de bloques y PoT sobre transacciones | Q1 |
| **C-NET-30** | presupuesto de subida con recorte, y anuncio-y-petición (valor PENDIENTE) | Q1 |
| **C-NET-31** | tema `/zerox/pot/1`, una verificación por **clave de contexto**, cacheada — **corregida el 2026-09-20**: la clave es `(f, s, semilla, N)` de `C-POT-07`, no el slot a secas | Q4 + `C-POT-07` |
| **C-NET-32** | verificación bajo demanda con tres salvaguardas — **corregida el 2026-09-20**: la salvaguarda 1 solo invalida **bajo la misma clave**, y la 3 remite a `C-NET-33` (cota global por nodo, D-F10) | Q4 + D-F10 |
| **C-NET-33** | **nueva**: los dos presupuestos de verificación de flujo ajeno y su modo de fallo `Pendiente` (`PRESUP_PAR`, `PRESUP_NODO`, ambos PENDIENTE) | D-F10 = B |

Reescritas: **C-NET-06** (orden completo de verificación), **C-NET-07** (de `txid` a
`wtxid = txid ‖ auth_digest`), **R-NET-01** (sin la negociación por conexión) y **C-NET-02** (los
temas). **C-NET-10 retirada con tombstone**; su número no se reutiliza. El SPEC pasa de 181 a 188
reglas.

**Hallazgo al redactar: C-NET-07 estaba mal archivada.** Estaba citada en
`crates/zx-p2p/src/id_corto.rs` y en **ninguna** de las dos listas, así que para `ci/citas-spec.sh`
contaba como «ruta activa» — es el límite que el propio guardián declara. Sus hermanas del mismo
módulo (C-NET-08, C-NET-09, R-NET-02) sí estaban declaradas. Corregido: pasa a
`ci/reglas-sin-cablear.txt`, que sube de 21 a 22. Y arrastra un segundo desfase: su código deriva
sobre `txid` y la regla ya dice `wtxid`, así que no es solo código sin cablear, es **código de la
versión anterior de la regla**.

**Los tres valores que el SPEC deja PENDIENTE a propósito** (§0.3: nadie los fija por su cuenta):
tamaño de la cola de anuncios huérfanos, presupuesto de reenvío de transacciones y presupuesto de
CPU del PoT bajo demanda. Los tres los calibra el v2 (Q5), y los tres son vectores que el v2b
ataca.

**Pregunta abierta, conservada:** relajar C-NET-06 para anunciar antes de reconstruir el bloque. Se
decide cuando el v2a mida con qué frecuencia faltan transacciones en las mempools.

#### Arquitectura «1+» del relé — DECIDIDO POR KATANA (2026-09-16)

Cierra dos preguntas que eran una sola: **cómo viaja el anuncio determina si queda algo que
negociar**. Si va por gossip a toda la malla, no hay negociación posible ni necesaria.

**Canales.**

| Protocolo | Lleva |
|---|---|
| `/zerox/blocks/2` | **solo** anuncios compactos. Versión nueva: hoy `/blocks/1` significa bloque completo |
| `/zerox/block-relay/1` | transacciones que faltan, colisiones y bloque completo como último recurso |
| `/zerox/sync/1` | IBD e histórico, **sin cambios** |

- **El bloque completo nunca se difunde por gossip.** Desaparece así el problema de que el anuncio
  y el bloque entero tengan `message_id` distinto y gossipsub no los deduplique.
- Un anuncio que no se puede evaluar por faltarle padres DAG va a una **cola acotada** y se
  reevalúa al llegar las dependencias; no depende de que gossipsub lo reentregue.
- La recuperación prueba **proveedores alternativos**, no queda cautiva del primer emisor.
- Pedir las transacciones que faltan es el **camino ordinario**. Bajarse el bloque entero al primer
  fallo tira la ventaja que el relé venía a dar.

**Identificadores cortos sobre `wtxid`.** C-NET-07 (`SPEC.md:2335`) pasa de derivar sobre `txid` a
derivar sobre `txid ‖ auth_digest`, como BIP 152 v2.

> El motivo **no es de consenso**. Un bloque mal reconstruido ya se rechaza: `merkle_root` va sobre
> `txid`, pero `body_commitment` cubre `txid ‖ auth_digest` y el relé lo comprueba. El problema es
> de **disponibilidad**: cuando ese compromiso falla, el nodo no sabe *qué* transacción estaba mal
> y debe rebajarse el bloque entero. Quien firma una transacción puede publicar dos variantes con
> el mismo `txid`, sembrarlas en mempools distintos y forzar fallbacks completos a coste casi cero.

**Reglas afectadas.**

| Regla | Qué pasa |
|---|---|
| **R-NET-01** | se conserva y se reescribe; se elimina **solo** la negociación `sendcmpct` por conexión |
| **C-NET-07** | de `txid` a `wtxid` — cambia una regla ya cerrada e implementada en `id_corto.rs` |
| **C-NET-10** | se **retira con tombstone** (`SPEC.md:2374`); su número no se reutiliza |
| **C-NET-06** | sigue pendiente: la validación previa al anuncio no está implementada |

**Por qué se descartaron las otras dos.** Dos temas conviviendo hace viajar el bloque dos veces,
que es justo el ancho de banda que el relé ahorra. Y empujar a ≤3 pares (BIP 152 fiel) exige estado
por conexión, que `research/bip152.md` §8 declara **no portable** a libp2p sin forzar un stream
lógico único por par sobre yamux.

**Aparcado:** el híbrido *eager/lazy* es portable —negociar al abrir cada substream no es
`sendcmpct`— pero añade RTT, estado de proveedores y el riesgo de que los «más rápidos» sean pares
adversarios. Queda como *fast lane* experimental; solo se activa si mejora p95/p99 frente a 1+ bajo
mempool frío, ramas DAG, pérdida y eclipse.

**Trampa al implementar.** Subir a `/zerox/blocks/2` no basta: `crates/zx-p2p/src/servicio.rs`
despacha con `topico.contains("/blocks/")` hacia `respuesta_desde_bytes`, que espera una
`Respuesta`. `/blocks/2` también cumple esa condición. Si se cambia la versión sin cambiar el
despacho, los anuncios se rechazan como basura **y el par que los propaga se lleva la penalización**.

### 2.8 · Cablear el DAG a la ruta activa del nodo
Es lo único que queda del Nivel 1 entero: §1.2, §1.3 y §1.4 están especificadas **y tienen código**,
y ninguna la ejecuta nadie. Las veintiuna reglas afectadas están declaradas en
`ci/reglas-sin-cablear.txt`, y los puntos de entrada de GHOSTDAG en `ci/consenso-pendiente.txt`.
Ese es el inventario exacto de lo que este trabajo cierra: cuando una regla se cablea, sale del
archivo, y el guardián falla si no lo hace.

Qué hay que conectar:

- **`zx-node`/`zx-storage` adoptan `DagBlockHeader`** en vez de la cabecera lineal de 92 B. El
  indicador de que está hecho es `el_codigo_alcanza_la_base_poas_de_556`, hoy ignorado a propósito
  en `crates/zx-consensus/tests/spec_numeros.rs`: deja de estarlo cuando esto se cierra.
- **GHOSTDAG sustituye a `fork_choice.rs`** en la selección de cadena, y el almacén se alimenta
  desde el sincronizador. `zx-consensus::ghostdag` expone ya `ContextoDag` con génesis, padres
  validados, anticadena y `prev_hash == sp(B)`.
- **El relé compacto** según la arquitectura «1+» de §2.7, con su cambio de `txid` a `wtxid`.

Dos deudas pequeñas que conviene saldar al cablear, no después:

- `ghostdag::Parametros` expone `sp`, `merge`, `k`, `u2` y `u3_dinamica` como campos públicos. El
  `default()` es la regla C, pero un llamante puede construir `ModoSp::Kaspa` y tener un nodo que
  forkea. El modo histórico existe para leer los vectores oficiales de rusty-kaspa, que es un uso
  legítimo; lo que no debe seguir es que la regla viva en la prosa y no en el tipo.
- `mod ancho` de `crates/zx-core/src/preimage/dag.rs` es privado, así que las anchuras de campo de
  §6.1 no se vigilan una a una. Quedan cubiertas de forma agregada —`TAMANO_PREFIJO_FIJO` es su
  suma, y esa sí se comprueba—, de modo que solo escapa un cambio **compensado** entre dos campos.
  Es estrecho, pero es la forma exacta del fallo H-005 que `spec_numeros.rs` documenta.

**No lo cierra todo.** `validar_bloque` seguirá sin alcanzarse aunque esto termine: necesita el
conjunto UTXO con datos de deshacer, que es §2.6.

### 2.9 · La deuda que §2.1 deja al cerrarse — ESCRITA AQUÍ PORQUE NO ESTABA EN NINGUNA LISTA

§2.1 quedó **cerrado en el SPEC** el 2026-09-20. Lo que sigue **no** es el trabajo de cablearlo:
son **huecos de evidencia y de alcance** que el cierre deja vivos y que hasta hoy no figuraban en
ningún inventario del repositorio. Están ordenados por lo que pasa si se ignoran.

**(a) Lo que el diseño supone y nadie ha medido**

1. **La vía A2 no está medida, y es un hueco nuevo.** `P(una rama privada desplaza el ancla dentro
   de V_j antes de t_j)` es la cola de una carrera de `blue_work` de longitud `L_slots`. El
   baseline de deriva **idealizado** da `α_drift = 1/2` (CRP-v0.1), pero el umbral del protocolo
   sigue **inconcluso** (P-CRP); **la cola a `L = F_slots` tampoco está medida**. Y lo que
   `P-2.1` midió —`L_mín`— es **otra magnitud**: desacuerdo honesto por latencia. Ni el encargo de
   `P-FLUJO` ni ninguna adenda contemplaban este vector. Instrumento que podría medirlo:
   `veritas/consenso/ancla-inyeccion-v2/`.
2. **El equilibrio adaptativo no está medido**, y es el ataque que va directamente contra (P2), que
   es donde descansa toda la seguridad del perfil 1a: partir a los honestos en dos mitades y
   sostener el empate. Lo medido es **A3 estática** —todos los bloques del atacante al mismo
   observador toda la réplica— con tope de 8 candidatos y ventana `[T, T+45]`.
3. **El coste de `C-FLU-02` para el productor honesto está `estimado ≈ 0`, no medido.** La
   propuesta declara que confirmarlo con ANCLA-v0.2 —fracción de bloques honestos que
   referenciarían un padre de slot mayor, con `Δ` = 0,5 / 4 / 16 s— es **«condición para pasar al
   SPEC», no trabajo opcional**. **La regla se trasladó igualmente, por decisión de Katana
   (D-F6 = A), y esa condición sigue SIN CUMPLIRSE.** En el régimen candidato `τ ≈ 0,1-0,17 s` los
   empates y cruces de slot se multiplican por 6-10, así que la estimación **no se extrapola sola**.
4. **La tercera rendija del presupuesto no está medida.** Dos nodos con **el mismo DAG** pueden
   acabar en flujos distintos porque uno pudo pagar la verificación dentro de la ventana de
   `C-FLU-22` y el otro no. A diferencia de las dos rendijas de PCO-v0.1, **ésta está parcialmente
   bajo control del atacante**, que puede gastar presupuesto ajeno con tráfico barato del paso 1b.
5. **El colateral honesto de `C-FLU-20` no está medido.** Un bloque tardío que cambiaría un ancla ya
   activada queda **infusionable para siempre**. Lo normal es que sea del atacante; con qué
   frecuencia atrapa bloques honestos, y cuánto empeora con `τ ≈ 0,1-0,17 s`, no se ha medido.
6. **La `Δ` de TODO lo anterior es simulada** (DMS-v0.1), no medida en red. Sigue siendo «la primera
   medición que el diseño necesita» (§3.1).

**(b) Lo que está demostrado que NO funciona, o que falta por demostrar**

7. **El sembrador (A5): las reglas actuales no prueban preexistencia y el margen adversarial
   real no está cerrado.** `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md` establece que ni
   `history_size` ni `altura_ploteo` demuestran antigüedad física: identifican el prefijo
   histórico, y un atacante puede escoger hoy una referencia antigua todavía válida. Basta
   **una pieza, no un sector**. `P-ZRX/P-INTENTO/investigacion/INFORME.md` midió una ruta de
   intento dirigido en una CPU y revisión concretas; no es el coste mínimo de un adversario
   con GPU/SIMD/ASIC ni una garantía económica. El cierre exigiría acreditar cobertura y
   preexistencia de la parcela completa antes del reto: **A1+C1 sigue siendo propuesta**, pues
   esa prueba no existe para el formato fijado
   (`P-ZRX/P-PERMANENCIA/investigacion/INFORME.md` F3). Bajo el perfil **1a** la salida
   histórica —«desatar `L` de `F`»— **queda cerrada**, y el suelo de `C-FLU-01` la cierra
   más: el margen histórico de **1,91×** es **con precios supuestos** y **no está medido**.
8. **La deuda principal: la convergencia del orden no está probada para este diseño.** Prop. 7 y
   Def. 2 de GHOSTDAG están probadas sobre GHOSTDAG **puro**; con las tres reglas añadidas encima,
   «que el orden total siga convergiendo bajo las tres **no está comprobado**. Es la deuda
   principal» (`research/dag-poas-ancla-de-orden.md:436-439`). **Toca a §7.1 del SPEC de lleno:**
   (F1) —`slot` no decreciente por la cadena seleccionada— y (F2) —`blue_work` estrictamente
   creciente—, de las que cuelgan `C-FLU-04` y toda §7.1.3, son **propiedades medidas en simulador
   y un lema**, no consecuencias del teorema.
9. **La existencia del ancla en el caso patológico no está medida.** `C-FLU-04` la demuestra bajo
   una condición suficiente y `C-FLU-05` cierra el caso contrario con un rechazo. **Con qué
   probabilidad `Chn(V_j(B))` diverge de la cadena de `B` por debajo de `T_j` no se sabe:** no hay
   ninguna proposición que ate `blue_work` con `slot`.
10. **La disponibilidad del ancla tras la poda no se resuelve.** `C-FLU-04` necesita `V_j(B)` para
    **todas** las épocas del pasado; qué pasa cuando esos bloques están podados sigue abierto, como
    ya decía R-FIN-1 y repite `SPEC.md` §7.3.

**(c) Aritmética revisada y calibración pendiente**

11. **La calibración de la ventana sigue pendiente.** `ρ_max` por plataforma adversaria y la
    cola de anclas no están medidas; `I`, edad y margen de seguridad no están fijados. Los
    análisis de alternativas permanecen en `P-ZRX/`, fuera de este inventario de trabajo.
12. **`PRESUP_NODO` se calibra en PINZA, y una de las dos mordazas no está derivada.** Por abajo:
    integrado sobre la ventana de `C-FLU-22`, **MUST** bastar para verificar **una rama rival
    completa** —peor caso `F_slots` slots, del orden de `F_slots × 92 ms` ≈ **11 min de CPU** con
    los valores nominales—; **con menos, la adopción nunca se completa y D-F9 queda derogada de
    hecho sin que nadie la revoque**. Por arriba: demasiado grande devuelve el DoS. **La cota
    superior NO está derivada.** El valor de `PRESUP_PAR` sigue siendo un `<<PENDIENTE>>` declarado
    que calibra el v2b (Q5).

**(d) Alcance que se decidió dejar fuera, no olvido**

13. **La reconciliación de `C-FIN-01`** con (i) el código que hoy **se detiene**
    —`ReorgDemasiadoProfunda` obliga a «detener el nodo y avisar al operador, no reintentar»—, (ii)
    **`COINBASE_MATURITY`**, de la que `MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 11 999` deriva, y
    (iii) **el techo de archivado**, que nadie ha estudiado. Quedó fuera **por alcance decidido**
    (D-F3 = C acotada al enunciado), no por falta de decisión. **Es trabajo, no bifurcación.**
    `C-REORG-07` sigue transitoria.
14. **La regla objetiva del recién llegado** —«el flujo canónico es el que lideraba en
    `t_j + F_slots`»— queda como **encargo aparte**, con su resistencia a bloques con slots antiguos
    por estudiar. `C-FLU-18` hace la conducta determinista y única; **no la hace acertada**: tras
    `ALTURA_CADUCIDAD` del checkpoint y con una partición viva, un nodo nuevo va al flujo más pesado
    **del momento**, que puede ser el minoritario.

**(e) Evidencia sin validar que afecta a lo anterior**

15. **CRP-v0.2 y CRP-v0.3 fueron auditadas, no validadas como instrumentos ni migradas.**
    `P-ZRX/P-CRP/auditoria/INFORME.md` da veredicto **protocolario inconcluso**; su
    `RECOMENDACION-MIGRACION.md` deja v0.2 como anexo histórico y permite considerar v0.3
    **solo tras corregir bloqueantes y rebajar su conclusión**. CRP-v0.1 sigue siendo baseline
    idealizado, no una prueba de umbral global. Los titulares residuales de §2.1 y `SPEC.md`
    §17 requieren la misma corrección; reproducir un barrido no valida sus hipótesis.

**(f) El código, que es lo único que cablea todo esto**

16. **El verificador PoT contextual no está integrado en el nodo**, y ahora tiene contrato:
    `C-POT-06` (tres estados y prohibición de circularidad), `C-POT-07` (caché por clave contextual)
    y `C-POT-08` (orden de validación). Desde 03a–03c existen `crates/zx-pot`, el adaptador de un
    slot y el núcleo `zx-consensus::pot_rango`. Este último reproduce la cadena AES y comprueba
    `pot_output`, pero su trait `InstantaneaPot` no acredita por sí mismo `past(B)` validado; falta
    derivar flujo, vista de época, ancla y salida base. Las piezas siguen fuera de la ruta activa,
    declaradas como parciales en `ci/reglas-sin-cablear.txt` y `ci/consenso-pendiente.txt`.
    `wire_dag::verificar_justificacion_pot` sigue devolviendo siempre `IntegracionPotPendiente`.
    Integrarlo con contexto, flujo y caché sigue pendiente.
17. **La derivación del flujo en el nodo no existe.** `C-FLU-10` necesita calcular `Chn(V_j)` sobre
    la vista de época; `C-FLU-17` necesita puntos de enganche en el nodo que tampoco existen. Nada
    de esto se puede empezar sin §2.8. **`C-FLU-02` es la excepción parcial:** su comprobación —y el
    accesor `ContextoDag::slot_de_padre` que le faltaba— **ya está implementada** en los
    componentes DAG (`comprobar_padres_contextual` y `AlmacenGhostdag (inserción)`, Referencia y
    Kernel), con tests; lo que sigue pendiente es **integrarla en el nodo**, que continúa con la
    cabecera lineal y `fork_choice.rs`. Por eso C-FLU-02 está en `ci/reglas-sin-cablear.txt`, no
    entre las reglas sin código.

### 2.10 · P-ZRX: frentes nuevos y alcance de los hallazgos (2026-09-22)

Solo se anotan **hechos y trabajos pendientes**, no defensas adoptadas. «Bloque válido» en las
auditorías del diseño no implica que el nodo lineal actual pueda producirlo o aceptarlo.

1. **Pool de farming y firma ciega — riesgo condicional, no explotación de un pool existente.**
   ZEROX aún no tiene protocolo de pool de farming ni productor DAG integrado. Si un futuro
   cliente firma un `pre_hash` construido por el operador, este puede elegir rama y coinbase sin
   tener la clave privada (`P-ZRX/P-POOLS/investigacion/INFORME.md` §1). **Pendiente:** decidir la
   arquitectura antes de implementarla y comprobar, en el futuro productor, que el granjero
   honesto construye y valida el candidato antes de firmarlo y que una **parcial de pool tiene
   dominio separado del sello de bloque**, de modo que no pueda autorizar un bloque. Es una
   condición arquitectónica para un cliente honesto, **no** una garantía frente a un cliente
   malicioso ni una solución general al doble farmeo. Atar la
   coinbase a `sol.public_key` quitaría el premio directo, **no** la capacidad de usar el espacio
   o sabotear la rama; es propuesta, no regla vigente (`DECISIONES-PENDIENTES.md` D1–D2).
2. **Doble farmeo/espacio prestado — sin defensa general validada.** El modelo
   `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` muestra erosión de la deriva bajo sus supuestos;
   la traducción de fracción física de espacio a tasa/peso y el canal de pool no están cubiertos.
   P-IDENTIDAD descarta que cambiar el billete por identidad de pieza elimine el peso simultáneo
   de ramas separadas. P-PERMANENCIA descarta E2 como prueba de almacenamiento y limita E3 a
   observabilidad/coste económico; no existe una prueba de cobertura/preexistencia de la parcela
   completa para este formato. P-EQUIVOCACION caracteriza evidencia **cuando ambas firmas se
   publican**, no una rama oculta, censura o sanción segura ante firma ciega. **P-CLAVE midió el
   único candidato de castigo vivo (retención ligada a la clave) y el resultado es que NO
   disuade al atacante que importa:** con la distribución de tamaños de clave declarada (H3), el
   67,5 % del espacio vive en claves de saldo casi nulo — más que el `β_d = 0,34` (con
   `α = 0,33`) que basta para cruzar la deriva —, así que ese `β_d` se compra con soborno **cero**;
   y las claves nuevas no se pueden encarecer sin registro ni moneda previa, porque el ploteo es
   lineal en bytes e independiente del número de identidades (identidades gratis por diseño).
   Queda como **mitigación parcial**, no como defensa del umbral. **Pendiente:**
   modelar juntos esos casos, C-GD-11 y el puente espacio→tasa, sin adoptar por inferencia
   registro, castigo ni compromiso de rama (`P-ZRX/P-IDENTIDAD/investigacion/INFORME.md` §6;
   `P-ZRX/P-PERMANENCIA/investigacion/INFORME.md` F1–F3;
   `P-ZRX/P-EQUIVOCACION/investigacion/INFORME.md` §8;
   `P-ZRX/P-CLAVE/investigacion/INFORME.md` F3–F6).
3. **Red adversaria/eclipses — falta transferencia al destino.** Q5 de §3.1 ya encarga v2a
   (aislamiento, no reenvío y saturación) y v2b (efecto de seguridad). Falta contrastar la
   investigación histórica de `research/dag-poas-informe-52-problemas.md` §2 y §12 con C-NET/C-FLU
   vigentes y medir red bajo ataque. Δ natural de DMS es **sintética**, no medición en una red
   ZEROX desplegada. Una partición mayor que `L_slots` no queda curada por C-FLU-22 (§2.1).
4. **Elección de padres/U2 — omisión textual, no pérdida observada «hoy».** C-GD-10 no enumera
   puntas cuya inclusión haría violar U2. El **0,40 %** procede únicamente del estrés MC-D de
   P-IDENTIDAD con identidad vigente, `equivoca = 1`, `P = 16`, 400 réplicas de unas 120
   emisiones; incluye bloques inválidos y herederos. La red honesta de un solo flujo del mismo
   instrumento dio **0**; no existe productor DAG activo y no se conoce una tasa real. El
   propio informe considera la omisión inocua bajo la identidad vigente y bloqueante si se
   adoptara la identidad por pieza (`P-ZRX/P-IDENTIDAD/investigacion/INFORME.md` F2 y resultado 7).
5. **`ab-proof-of-space`: la ruta serial no paralela tiene un SIGSEGV reproducible — bloqueo de
   adopción de esa ruta.** `P-ZRX/P-INTENTO/investigacion/mediciones/fallo-semilla.md` documenta,
   con entrada mínima de 32 bytes, que `Tables::<20>::create_proofs` y `Tables::<20>::create`
   (ruta **no paralela**, la que usa `ChiaV2TableGenerator::generate`) terminan el proceso con
   SIGSEGV con un solo hilo y una sola llamada; la ruta paralela (`create_proofs_parallel`, la del
   plotter honesto) **no falla con esa semilla**. **[medido]** en el clon fijado `f8842d0`; la
   causa raíz está **no determinada** (sin `gdb` ni sanitizer) y la tasa solo **estimada**, no
   medida. **Bloqueo de adopción de esa ruta:** antes de usarla hay que determinar la causa,
   verificar si existe en la revisión aplicable y contar con corrección y regresión. **No** se
   elige por ello la ruta paralela «que no falló con una semilla», ni se extrapola frecuencia o
   causa no medidas.
6. **P-FIRMANTE — prototipo local de *persist-before-sign*, no integración ni defensa.**
   `P-ZRX/P-FIRMANTE/informe/INFORME.md` e `INTEGRACION.md`: prototipo Rust fuera de `crates/`,
   con registro durable y orden decidir→persistir→sellar; su coste medido (~0,81 ms por bloque)
   es de esta máquina. Es un **filtro de accidentes honestos**, no una defensa contra claves
   compartidas, clientes que firman órdenes hostiles ni atacantes deliberados, y dos registros
   distintos no se coordinan. El **productor DAG al que se engancharía no existe** hoy
   (`INTEGRACION.md` §1). No se copia a `crates/` ni se fija su ubicación futura.

**Magnitudes todavía sin calibrar:** Δ en una red ZEROX real (§3.1); ventaja máxima del reloj
`ρ_max` por plataforma/adversario (P-REVELACION §6); probabilidad de que el atacante controle
un ancla seleccionada, **no identificada** con su cuota física de disco (P-REVELACION §§1.4, 6);
distribución observada de capacidad por granja y de espacio por clave (P-PUERTA H-TAMANOS,
P-CLAVE H3); y el puente entre bytes PoAS, oportunidades elegibles y tasa/peso
(`P-ZRX/P-CRP/auditoria/INFORME.md` C1). Los barridos existentes usan entradas o redes
sintéticas; ninguna de esas magnitudes puede copiarse de una celda de escenario.

**Construcción y reglas ya inventariadas:** falta un productor que ensamble, seleccione padres,
firme y publique bloques DAG (`P-ZRX/P-FIRMANTE/informe/INTEGRACION.md` §1), aunque existen tipos,
códec y GHOSTDAG sin cablear. `wire_dag::verificar_justificacion_pot` devuelve
`IntegracionPotPendiente` (§2.9(16)); el núcleo de rango PoT existe en `zx-consensus`, pero no
tiene derivador causal ni ruta en el nodo. Las 31 reglas nuevas,
`PRESUP_NODO`, C-GD-11 con cinco pendientes y `L_suelo_slots` ya están en §2.1, §2.4, §2.9 y
§3.3. Las once C-RET de P-RANGO son **propuesta** (§2.3), no reglas decididas. No se crea una
tarea llamada «trece pendientes»: el recuento textual de marcadores no equivale a trece
decisiones independientes.

---

## Nivel 3 — Parámetros sin cerrar (no impiden escribir, impiden lanzar)

| # | Punto | Estado |
|---|---|---|
| 3.1 | **`Δ` natural medida solo en simulación** | Instrumento `veritas/finalidad/delta-medido-v1/` (MS; revisión 2 validada y migrada el 2026-09-14); cinco decisiones tomadas; coste por salto medido en hardware (`veritas/rendimiento/coste-salto-v1/`, 2026-09-14); pendiente el v2 (v2a y v2b), ver abajo |
| 3.2 | `F` = 2 h **provisional** | Con obligación declarada de bajarla en producción |
| 3.3 | `I_slots`, `L_suelo_slots`, `ρ_max` | **`L` ya NO es un parámetro libre:** desde el 2026-09-20 es una definición, `L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)` (`C-FLU-01`, perfil 1a). Lo que queda abierto es **`L_suelo_slots`**, que va como símbolo y **no se puede fijar hoy**: su criterio exige una cota de `Δ` **medida en red real** (§3.1), no simulada. `I_slots` sin cerrar; `ρ_max` carece de cota medida por plataforma adversaria. Los análisis de alternativas no calibran estos valores (§2.9). |
| 3.4 | **P-038** | Abierta |
| 3.5 | Génesis | Parámetros y hashes distintos por red; bootstrap explícito |

### 3.1 · `Δ`: medición, decisiones y lo que falta

**Medición (MS, no MR).** `veritas/finalidad/delta-medido-v1/` (ID `DMS-v0.1`). Revisión 1
reproducida por Claude el 2026-09-13; revisión 2 y su corrección, reproducidas fuera del repo
con 16 hilos el 2026-09-14: 25 598 asserts en verde, `resumen.csv` de r1 y r2 y 140 trazas
idénticos byte a byte a los de 24 hilos. Migrado el 2026-09-14 sin las trazas de medias (47 MB,
decisión de Katana): su huella está en `TRAZAS.sha256`. Procedencia en `ENMIENDA-R2.md`,
bitácora del ejecutor en `BITACORA.md`. La incidencia de procedencia (la reproducción de Claude
con 8 hilos había sobrescrito `resultados/barrido-principal/`) quedó reparada en la r2.

**Resultados de la r2 con la base decidida** (100 Mbit/s, objetos de Q2, validación a 0 s como
cota inferior):
- Δ_99 p99 de 0,26 a 0,45 s con la cabecera de 812 B; de 0,32 a 0,54 s con el anuncio compacto del
  techo; 0,60 s como máximo en toda la rejilla. 60 de 60 combinaciones en régimen estable.
- Con 0,1 s de validación por salto, 0,90–1,01 s.
- El bloque completo del techo satura (ρ = 1,0005): la cola crece con el horizonte y sus cifras no
  son Δ.
- Padres típicos 1,14–1,39.
- Comprobación de cordura: máximo estable 8,63 s < S_max/10.

**Enmienda del INFORME — CERRADA (2026-09-14).**
- Declarado el sesgo del modelo: bloque completo a los 8 vecinos (`src/rapido.jl:151-158`) y
  validación a 0 s, frente al relé compacto (R-NET-01) y la validación antes de retransmitir
  (C-NET-12) del SPEC.
- Recalificadas como dependientes del modelo, sin borrarlas, tres conclusiones de la r1: «128 kB
  corresponde a la banda de 4–8 s», «1 MB satura» y el procesado a 0 s.
- Añadidas las medias de llegada por bloque y por nodo, y medidas las celdas de Q2.
- Corregido un error de método encontrado al validar: la media ponderada por espacio contaba la
  cuota dos veces (efecto ≤ 0,24 %).
- Queda una observación sin corregir: el test de ese estimador no cubre la ruta en línea de
  `run.jl` (`ENMIENDA-R2.md` §7).

| # | Pregunta abierta del v1 | Estado |
|---|---|---|
| Q1 | Ancho de banda de referencia | **Decidido por Katana, 2026-09-13** (abajo) |
| Q2 | Presupuesto de tamaño de cabecera y bloque DAG (satisfecho por §6.1) | **Decidido por Katana, 2026-09-13** (abajo) |
| Q3 | Qué estadístico de Δ gobierna cada parámetro | **Decidido por Katana, 2026-09-13** (abajo) |
| Q4 | Cuánto cuesta la validación por salto (C-NET-12 ya obliga a validar) | **Decidido por Katana, 2026-09-13** (abajo) |
| Q5 | Adversario de red: cuándo y cómo modelarlo | **Decidido por Katana, 2026-09-13** (abajo) |

**Q1 · Referencia de diseño de red: 100 Mbit/s de SUBIDA — DECIDIDO POR KATANA (2026-09-13).**

- **Techo:** ≈1,56 MB/s de datos que cada nodo puede reenviar, con la cuenta pesimista del repo
  (8 pares, sin overhead). Con transacciones de 350 B (Modelo B350, hipotético) son **4 464 tx/s**;
  con transacciones Orchard de 2 acciones (9 163 B) serían ≈170 tx/s. Por eso el techo se declara
  en bytes y no en tx/s. Equivale a 7,8 veces el límite de bloque de arranque.
- **Qué es y qué no:** se calcula por nodo, pero en un libro replicado cada nodo procesa todas
  las transacciones, así que es también el techo de planificación de la red entera: añadir
  nodos no lo sube. No es el límite actual del protocolo (el límite de bloque de arranque da
  ≈571 tx/s) ni la única cota: sostenido, ese techo son 49,3 TB/año de disco sin poda (4 TB en
  unos 30 días), frente al presupuesto de 72 tx/s del Modelo B350 (`ZEROX-EN-NUMEROS.md:160`).
  La CPU de validación por salto ya está medida (Q4).
- **Motivo:** política de marketplace. Se prioriza a quien produce bloques con conexión fija de
  calidad, aunque centralice algo y perjudique a los nodos mal conectados.
- **Alcance:** es una referencia de planificación, no un requisito. Ninguna regla la comprueba ni
  expulsa a nadie. No cambia Δ: con objetos pequeños, pasar de 10 a 50 Mbit/s mejora Δ_100 de
  0,337 a 0,325 s (v1 §6).
- **Fuente:** Speedtest Global Index, julio 2026, subida mediana de banda ancha fija, copiada por
  Katana. Mundial 63,72; EE. UU. 59,67; Canadá 96,30; México 94,09; Argentina 84,57; Brasil 133,90;
  Colombia 105,71; China 47,92; India 58,80; Japón 133,27; Taiwán 188,01; Singapur 352,74;
  Alemania 37,43; Francia 262,68; España 211,64. Faltan datos del Norte de Europa.
- **Consecuencia declarada:** la línea típica de EE. UU., Canadá, México, Argentina, China, India y
  Alemania queda por debajo. Con carga sostenida entre ≈2 139 y 4 464 tx/s (transacciones de 350 B)
  esas líneas no pueden reenviar toda la carga: siguen recibiendo y validando, pero el reenvío se
  concentra en los nodos mejor conectados.
- **Condición:** una regla de transporte que hoy no existe ni en SPEC §16 ni en
  `crates/zx-p2p/src/behaviour.rs`. Tres partes: cola prioritaria para bloques y PoT sobre
  transacciones; presupuesto de reenvío de transacciones por debajo de la subida disponible; y
  reenvío de transacciones por anuncio y petición. Sin ella, los nodos por debajo de la referencia
  se saturan en lugar de recortar. Pendiente de redactar como regla C-NET y de declarar en
  `ci/reglas-sin-codigo.txt` hasta que haya código.
- **Revisión:** cuando se mida el relé real, o si la carga sostenida se acerca a ~2 000 tx/s.

**Q2 · Presupuesto compacto para la ruta crítica — DECIDIDO POR KATANA (2026-09-13).**

- **Qué se fija:** un **presupuesto de diseño** que el formato cerrado en 1.4 respeta. El formato
  se fijó después en §6.1–§6.2; el presupuesto no se movió al hacerlo.
  - Cabecera DAG (base PoAS + padres + justificación PoT): ≤ ~1 kB en el caso típico y ≤ ~20 kB
    en el peor caso. El peor caso son 15 padres y 150 slots de justificación (S_max): 20 238 B
    (1 037 + 19 201), de los que 19 201 B son la justificación PoT codificada.
  - **Dos niveles.**
    - **Lo que se reenvía y se valida en cada salto:** la cabecera sin justificación
      (`589 + 32·(P−1)`; 1 037 B con 15 padres) y los IDs cortos.
    - **Lo que viaja pero no cuesta CPU por salto:** la justificación PoT (≤ 19 201 B). Acompaña
      al bloque (C-HDR-07) y se valida contra la caché de slots (Q4); su coste son bytes, 1,6 ms
      por par a 100 Mbit/s con 20 kB.
  - Anuncio compacto (cabecera + 6 B por transacción, C-NET-07): ≤ ~28 kB en el techo de Q1
    (≈4 464 transacciones de 350 B por bloque; 27 596 B).
  - Relé compacto **obligatorio en la ruta crítica**. Hoy R-NET-01 lo negocia conexión a
    conexión.
- **Motivo:** en el techo de Q1, con el modelo pesimista del v1 (8 pares en serie, ≈5,6 saltos),
  el anuncio compacto ocupa el 1,8 % de la subida de un nodo de 100 Mbit/s (utilización ρ = 0,018)
  y añade ≈0,1 s de Δ (≈0,17 s por líneas típicas de EE. UU.). El bloque completo **satura el
  enlace**: ρ = 1,0 con 100 Mbit/s y 1,68 por líneas típicas de EE. UU. No hay Δ estable, porque
  la cola crece con el tiempo. *Corregido el 2026-09-13: una versión anterior daba ≈5,6 s y ≈9,4 s
  para el bloque completo, pero eran solo tiempo de transmisión, sin la cola.*
- **Dependencia de Q1:** en el techo, el reenvío de transacciones ocupa toda la subida del nodo de
  referencia (ρ = 1,0 en la cuenta pesimista). El anuncio compacto solo sale a tiempo gracias a la
  regla de prioridad de bloques de Q1.
- **Riesgo declarado de esta opción:** con un bloque por segundo, lo que tardan las transacciones en
  llegar a todas las mempools es del orden del intervalo entre bloques. Si quien produce el bloque
  incluye transacciones hasta el último instante, puede faltar una parte grande en los receptores,
  y el caso degradado sería el normal. Es una hipótesis derivada, no medida; se mide en el v2a (Q5).
- **Pendiente derivado:**
  - Redactar la obligatoriedad del relé compacto en SPEC §16.
  - Especificar el **caso degradado** (el receptor pide las transacciones que le faltan) como
    mecanismo con presupuestos de recursos (C-NET-04), **sin penalizar a quien reenvía**: la falta
    suele venir de mempools desincronizadas, no de mala fe (C-NET-05, C-NET-08). Es transporte
    (§2.7), no formato de cabecera.
  - **Pregunta abierta: relajar C-NET-06.** Hoy exige tener todas las transacciones antes de emitir
    el anuncio, así que la petición de las que faltan está en la ruta crítica. Anunciar antes de
    reconstruir la sacaría de ahí, a cambio de reenviar anuncios cuyo cuerpo podría no coincidir.
    Se decide después de que el v2a mida con qué frecuencia faltan transacciones.

**Q3 · Ningún estadístico único: cada regla usa lo que consume — DECIDIDO POR KATANA (2026-09-13).**

- **Para `k`, la fracción de honestos rojos y la frontera:** la **distribución completa** de Δ
  (por bloque y por nodo, **ponderada por cuota de espacio**, no por número de nodos) entra en la
  medición de δ₀ (ronda 11a) en lugar de una Δ constante.
- **Para las reglas temporales duras** (S_max = 150 s, R-FIN-7 con F): no consumen un estadístico
  de Δ. S_max se dimensionó por tolerancia a particiones y por la cota de F
  (`research/dag-poas-ancla-de-orden.md:163`), y F por finalidad. Basta una **comprobación de
  cordura en régimen estable** (la red da abasto con la carga): Δ máxima muy por debajo de S_max
  (por ejemplo, menos de S_max/10 = 15 s) y de F. El v1 la pasa: máximo de 2,41 s con cabecera de
  683 B y 8,63 s con bloque completo de 100 kB a 10 Mbit/s. El caso saturado de 1 MB dio 3 428,7 s,
  por encima de S_max; por eso la comprobación exige régimen estable.
- **Para la aceptación de pagos:** no se usa Δ.
- **Valor provisional hasta tener esa medición:** Δ_99 en su p99. Recalculado en la r2 con la
  base decidida: **0,26–0,45 s** con la cabecera de 812 B a 100 Mbit/s, y 0,26–0,60 s en toda la
  rejilla (INFORME §11.3; en el v1 daba 0,28–0,48 s). **Etiqueta
  obligatoria:** representa «casi toda la red, casi siempre» y sirve para las herramientas
  históricas que exigen una Δ constante. No es el argumento de seguridad: ese es δ₀ medido, y
  bajo adversario en el v2b.
- **Media de llegada ponderada por producción:** se publica como estadístico **descriptivo de
  tamaño** (padres típicos ≈ 1 + λΔ̄, tamaño del mergeset), no de seguridad. Alimenta la cabecera
  típica de Q2: los «~4 padres» del ancla se estimaron con Δ = 4 s.
- **Ajuste del 2026-09-13, aprobado por Katana tras revisar un análisis externo.** Se rechazó usar
  esa media como provisional de seguridad en lugar de Δ_99 p99. Un bloque queda rojo cuando su
  anticono azul supera `k`, así que la fracción roja es un suceso de cola, no una función de la
  media. La ronda 11a lo muestra con `k=30`: 0,0000 / 0,0020 / 0,0828 / 0,2858 a Δ = 4 / 8 / 12 /
  16 s. Sustituir la distribución por su media quita la cola y subestima los rojos, que es la
  dirección insegura.
- **Motivo:** la pregunta del percentil existe solo porque las simulaciones antiguas usaban Δ
  constante. Hoy no cambia nada: todo estadístico del v1 queda por debajo de 4 s, donde `k=30` no
  deja bloques honestos rojos (ronda 11a). Importa para el método del v2.
- **Dependencia:** portar el instrumento δ₀ (Python) a Julia exige un GHOSTDAG en Julia. Ya
  existe: GDR-v0.2 (TAREAS 1.3, 2026-09-14). Ponderar por espacio requiere una hipótesis
  declarada sobre su reparto.

**Q4 · Consenso antes de reenviar, transacciones después; PoT por slot con caché y verificación
bajo demanda — DECIDIDO POR KATANA (2026-09-13).**

- **Antes de reenviar** (C-NET-12, C-NET-06): cabecera, prueba de espacio, 2 KZG, sello,
  justificación PoT (desde la caché) y compromiso Merkle. **Después**, antes de adoptar el estado:
  firmas, pruebas Halo2 y UTXO. Hay que reescribir C-NET-06 para decirlo explícitamente; hoy solo
  exime la comprobación de UTXO.
- **PoT:** se verifica una vez por slot en un tema de gossip propio y se guarda en caché. Es el
  patrón de Autonomys (`/home/katana/zeo/fuentes/subspace` @ `f8842d0`:
  `crates/sc-proof-of-time/src/source/gossip.rs` y `verifier.rs:25-29`). Es compatible con
  C-CHK-05: cada slot se verifica entero, una sola vez.
- **Verificación bajo demanda:** si un bloque cita slots aún no verificados, se verifican en ese
  momento con la justificación que trae el propio bloque (C-HDR-07), una vez por nodo y slot. Es el
  respaldo para nodos que se ponen al día; el camino normal sigue siendo el tema de gossip. Tres
  salvaguardas:
  1. comparar primero con la caché; si la salida no coincide, el bloque es inválido sin gastar CPU;
  2. los slots por delante del reloj PoT del nodo se retienen, no se verifican
     (`research/dag-poas-ancla-de-orden.md:342`);
  3. presupuesto de CPU para verificaciones bajo demanda, por par y por intervalo (espíritu de
     C-NET-04).
- **Motivo:** el coste por salto queda acotado por construcción. No depende del salto de slots
  (hasta 150 × 96,1 ms ≈ 14,4 s si el PoT se verificara por bloque) ni del número de transacciones
  (coste Halo2 sin medir). Es el mismo compromiso que BIP 152. Un bloque con cabecera válida y
  transacciones inválidas se propaga antes de detectarse, pero fabricarlo exige un billete ganador
  real.
- **Pendiente derivado:**
  - Tema de gossip del PoT en el SPEC (hoy solo hay `blocks` y `txs`, `SPEC.md:2122`).
  - Reescribir C-NET-06.
  - Nota de implementación: verificar varios slots en paralelo entre núcleos para ponerse al día
    (≈1,8 s para 150 slots en 8 núcleos; derivado, sin medir). Dentro de un slot no hay ganancia:
    la ruta AVX-512/VAES ya verifica los 8 tramos a la vez, con 16 carriles AES
    (`crates/subspace-proof-of-time/src/aes/x86_64.rs:248-269`).
  - **Banco en hardware — MEDIDO (2026-09-14, `veritas/rendimiento/coste-salto-v1/`; MH, un
    núcleo de un Ryzen 9 9950X3D).**
    - Validar antes de reenviar cuesta 1,33 ms (571 tx) y 2,17 ms (4 464 tx) con relé compacto.
    - Con cuerpo completo hay que calcular los txid, y sube a 2,32 y 9,86 ms.
    - Incluso el peor caso deja 10× de margen sobre los 0,1 s por salto de la sensibilidad de
      DMS-v0.1.
    - El PoT por slot cuesta 92 ms con AVX-512/VAES, 101 ms con AVX2/VAES, 190 ms con AES-NI y
      SSE4.1, y 8,3 s con AES por software.
    - Las rutas sin AVX-512 se forzaron en la misma CPU: no equivalen a una CPU antigua.

**Q5 · Adversario de red en un v2 partido en dos — DECIDIDO POR KATANA (2026-09-13).**

- **Punto de partida:** el v1 se enmienda y se migra primero, como medición de la Δ natural.
- **v2a · Δ bajo ataque, solo red.** Tres vectores:
  - nodos que no reenvían, o aislar a un nodo rodeándolo de pares propios;
  - mempools desincronizadas: el relé compacto se degrada porque el receptor tiene que pedir las
    transacciones que faltan antes de comprobar el compromiso Merkle (C-NET-06). Se modela con el
    **retardo de propagación de transacciones** (la «segunda Δ») como parámetro explícito, y con la
    **política de inclusión** de quien produce el bloque (hasta el último instante, o solo
    transacciones con cierta antigüedad) como variable. Resultado que se busca: con qué frecuencia
    faltan transacciones, para decidir si se relaja C-NET-06 (Q2);
  - inundación de transacciones contra la subida honesta, con y sin la regla de prioridad de Q1.

  Se modela con relé compacto y con el coste por salto medido. No necesita GHOSTDAG.
- **v2b · Efecto en la seguridad.** La distribución de Δ de v2a, ponderada por espacio, entra en
  δ₀ y en la frontera (Q3). Añade dos vectores de Q4: agotar el presupuesto de verificación bajo
  demanda, y bloques con cabecera válida y transacciones inválidas. Requiere el GHOSTDAG en Julia
  de 1.3.
- **Motivo:** los vectores ya están identificados y cada parte depende de algo distinto (banco en
  hardware, GHOSTDAG en Julia). Partirlo evita que la parte de red espere a la de consenso.
- **Orden:**
  1. enmienda del INFORME v1 y migración — **hecho, 2026-09-14**;
  2. banco en hardware del coste por salto (Q4) — **hecho, 2026-09-14**;
  3. v2a;
  4. GHOSTDAG en Julia (1.3 + 1.2) — **hecho, 2026-09-14**, adelantado en paralelo (GDR-v0.2);
  5. v2b.

---

## Nivel 4 — Decisiones de política que nadie ha tomado

### 4.1 · Recompensa del bloque honesto tardío
Abierta el 2026-09-12 y escrita en §7.2. Medido: un bloque honesto con billete único que nadie
disputa, fusionado tras el cierre de su ventana, **no cobra nunca**. ¿Pérdida definitiva, o
reinclusión como la que modela la cola de RCE-v0.1? La Δ natural ya está medida en simulación
(0,26–0,60 s, §3.1). Que eso vuelva raro el caso depende de dos cosas que siguen abiertas: el
margen `G` de cierre de la ventana, que en RCE-v0.1 es escenario pendiente, y las particiones y la
retención adversaria, que el v2 todavía no mide.

### 4.2 · IDs de regla — DECIDIDO POR KATANA (2026-09-15, ampliado el 2026-09-20)

Las reglas de §7.2 y §11 llevan IDs `C-XXX-NN`. Se aplicó con dos familias nuevas: **C-ORD-NN**
para el orden y el desempate de §7.2, y **C-GD-NN** para GHOSTDAG en §11.

**Tres familias más el 2026-09-20**, con el mismo criterio: **C-POT-NN** (el PoT como primitiva y
el contrato del verificador, §7.1.1–§7.1.2), **C-FLU-NN** (el flujo, §7.1.3–§7.1.7) y **C-FIN-NN**
(finalidad, §12). La separación entre `C-FLU` y `C-FIN` **es una decisión**, no una comodidad:
Katana la tomó en **D-F7 = B** porque la regla de finalidad **no es una regla de flujo**, es una
regla que el flujo usa. Por ese mismo criterio, el presupuesto de verificación de flujo ajeno
**no** es `C-FLU-23` sino **`C-NET-33`**: es una enmienda a C-NET-32.3, de la capa de red.

> ⚠️ **`C-FLU-19` NO EXISTE y su número no se reutiliza.** Fue el nombre de la regla de finalidad
> hasta que D-F7 la sacó de la familia y la renombró `C-FIN-01`. Es el mismo régimen que
> `C-FORK-01`…`04` y que `C-NET-10`.

- Los IDs son **nuevos y estables**: no se reutiliza ninguno retirado, empezando por los
  `C-FORK-01` a `C-FORK-04` del acumulador anterior.
- Mientras no exista código, se declaran en `ci/reglas-sin-codigo.txt`, como exige
  `ci/citas-spec.sh`; se retiran **uno a uno** conforme cada regla quede implementada y citada.
- Motivo: es el criterio spec-first del proyecto. El código entra cuando tiene su regla normativa
  que citar, y CI vigila que ninguna quede huérfana en los dos sentidos.

---

## Nivel 5 — Deuda de evidencia (debilita afirmaciones, no bloquea)

- **H2** — la convergencia de dos nodos está probada para **un** par de órdenes de entrega, sin
  barrido de permutaciones.
- **H4** — los «dos nodos» comparten el mismo `EconModel`, incluido el oráculo `context_truth`:
  convergen en parte por construcción.
- **H5** — la capa económica no comprueba `Σsalidas ≤ Σentradas`; en el fixture principal se
  consumen 5500 y se pagan 3000 sin que nadie lo note.
- **H6** — `catch ArgumentError → Invalid` enmascara roturas de invariante interno como veredicto
  de consenso.
- `comprobacion-decisiva-v1`, el instrumento promovido, no lleva `CONTRATO.md` ni `MODELO.md`
  como sus hermanos de `veritas/consenso/`.
- **Huellas de SPEC.md desalineadas:** `disponibilidad-causal-multivista-v1`,
  `dominio-autorizacion-v1`, `identidad-disponibilidad-v1` y `ventana-retarget-causal-v1` firman un
  `SPEC.md` que ya no existe con ese contenido. Cada uno firmó el SPEC del día en que se cerró, y
  el SPEC se reescribió después. Declarado en el commit f1a10a8 y comprobado de nuevo el
  2026-09-14; pendiente de decisión.
- **`DMS-v0.1`:** el test del estimador ponderado por espacio (T1) comprueba las funciones, pero
  `run.jl` aplica la regla en línea, sin llamarlas. Una regresión en esa ruta no la detectaría el
  test (`veritas/finalidad/delta-medido-v1/ENMIENDA-R2.md` §7).
- **`ANCLA-v0.2` escribe sus resultados en el directorio de trabajo, no en el suyo.** `run.jl` usa
  `joinpath("resultados", ...)` relativo al CWD (`veritas/consenso/ancla-inyeccion-v2/run.jl:49`,
  y lo mismo en `:81, :121, :150, :169`), mientras `METODO.md` manda ejecutar **desde la raíz del
  repositorio**. Seguir el método al pie de la letra crea `resultados/` **en la raíz**, no dentro
  de la carpeta del instrumento — que es donde el propio `METODO.md` dice que están las salidas.
  Detectado el 2026-09-20 al reejecutar la celda `hon-4` como control de identidad de la
  migración; **el control salió idéntico byte a byte**, así que no invalida ninguna cifra. Lo que
  sí hace es que **una reproducción descuidada puede comparar la copia consigo misma y no darse
  cuenta**. Avisado en el `METODO.md` del instrumento; **no corregido**, porque el único cambio de
  código que `P-ZRX/P-CIERRE/ENCARGO.md` §1.1 autorizaba era el `include` de GDR.
- **`puerta-cobertura-v1/HUELLAS.sha256` tiene 4 rutas de procedencia (de 82) que ya no resuelven.**
  Citan `P-ZRX/P-2.1/ENCARGO.md`, `P-ZRX/P-2.1/ADENDA-2.md`, `P-ZRX/P-PUERTA/PROMPT.md` y `P-ZRX/P-PUERTA/ENTRADA.sha256`;
  esos directorios se movieron a `P-ZRX/` el 2026-09-21, después de sellado el instrumento. El
  contenido no cambió: los mismos archivos, con el mismo hash, viven ahora bajo
  `P-ZRX/P-2.1/…` y `P-ZRX/P-PUERTA/…`. **No se edita el hash sellado**; se documenta aquí, igual
  que la línea de `SPEC.md` que ya fallaba a propósito desde la fase 1 de `P-CIERRE`.

---

## Orden recomendado

1. **`Δ` (3.1)** desde ya — es medición, no diseño, y desbloquea el nivel 3 entero. Δ natural
   medida en simulación y migrada (2026-09-14); el coste por salto, medido en hardware el mismo
   día. Siguiente paso: v2a (Q5), con las reglas de §2.7 redactadas antes, porque el v2a las
   modela.
2. **GHOSTDAG + `rank` total (1.3 + 1.2)** juntos — son el mismo problema por dos lados, y
   desbloquean §7.2 completa. El GHOSTDAG en Julia también alimenta δ₀ con la distribución de Δ
   (Q3) y el v2b (Q5). **No depende de Δ:** puede arrancar en paralelo al banco y al v2a, y es el
   camino crítico para escribir código, porque el nivel 1 es el único bloqueo duro. **Cerrado en
   el SPEC el 2026-09-15**: instrumento GDR-v0.2 y reglas C-GD-01 a C-GD-09 y C-ORD-01 a C-ORD-03.
   Lo que queda es el código del nodo, que es nivel 2.
3. **Cabecera DAG (1.4)** — **cerrada en el SPEC el 2026-09-17** (§6.1–§6.2). Lo que queda es
   integrarla en `zx-node`; hasta entonces ningún crate de serialización, red o almacenamiento debe
   darse por cerrado contra ella.
4. **Nivel 2, en dos mesas — decidido por Katana el 2026-09-17: SPEC primero, el ejecutor espera.**
   El Nivel 2 no es homogéneo, y esa es la razón del reparto: §2.4, §2.5 y §2.7 son **reglas sin
   redactar** y las escribe Claude; §2.1, §2.3, §2.6 y §2.8 son **código** y van a encargo. Mandar
   el Nivel 2 entero al ejecutor le obligaría a inventar reglas, que es justo lo que AGENTS.md
   prohíbe.
   - **§2.7 · transporte — HECHO (2026-09-17).** Ocho reglas nuevas (C-NET-25…32), tres reescritas
     (C-NET-06, C-NET-07, R-NET-01), C-NET-10 retirada.
   - **§2.4 · orden y conflictos — HECHO en tres de cuatro (2026-09-17).** C-ORD-04, C-GD-10 y
     C-GD-11. El pruning no era redactable: sale a auditoría.
   - **Pruning — encargo 05 escrito**, pendiente de lanzar. Puede **reabrir §6.1** si la prueba de
     poda exige `parents_by_level`: la cabecera DAG no tiene ese campo.
   - **Secuencia histórica del 2026-09-18, corregida por P-CRP.** Las auditorías de poda (05,
     06, 07) trasladaron la prioridad a las dependencias por flujo del PoT. La frase de entonces
     —«único punto medido que degrada el umbral, `α = 0,040` con `S = 24`»— **no describe el
     protocolo vigente**: era el contrafactual aditivo de CRP-v0.1 (§2.1), y el umbral global
     sigue inconcluso. La poda dejó además una deuda de arranque sucinto (§2.5), no una garantía
     de seguridad sobre ramas privadas.
   - **Lección de método de la serie 05–07, anotada para no repetirla.** Las tres auditorías
     produjeron **resultados correctos con alcance estrecho, presentados con etiqueta ancha**, y la
     validación de Claude no lo detectó hasta que una revisión externa lo señaló. En el 06, los dos
     defectos que invalidan su §1 estaban **escritos en los docstrings del código reejecutado**:
     reproducir un experimento no comprueba que el experimento pruebe lo que dice. Los tres
     `PROCEDENCIA.md` lo documentan instrumento a instrumento.
5. El resto por área, siguiendo §17 del SPEC.

---

## Cerrado recientemente (para no reabrirlo)

- **Dependencias por flujo del PoT (§2.1) redactadas en el SPEC**, 2026-09-20. **31 reglas
  nuevas** —`C-POT-01`…`08`, `C-FLU-01`…`18`, `C-FLU-20`…`22`, `C-FIN-01`, `C-NET-33`— y nueve
  existentes modificadas. Tres familias nuevas: `C-POT`, `C-FLU`, `C-FIN`. `C-FLU-19` no existe.
  - **La decisión de fondo:** validez del PoT **absoluta** (`C-FLU-13`) con perfil **1a**
    (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`). Su precio es la
    **partición de flujo**, que **no se cierra con una regla**: se previene con `L` frente a `Δ` y,
    si nace, `C-FLU-22` solo cura el nacimiento **espontáneo**.
  - **Corrección del titular anterior:** `1/(S+1)` —el «4 %»— es la **regla aditiva** y **no
    aplica con pasado consistente de flujo** (`C-FLU-14`). CRP-v0.1 ya etiquetaba su resultado
    «condicionado al diseño del flujo, no demostrado».
  - Evidencia: `veritas/consenso/pot-primitiva-v1/` y `veritas/consenso/regla-flujo-v1/`
    (propuestas validadas), sobre `veritas/consenso/ancla-inyeccion-v2/` (ANCLA-v0.2) y
    `veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1). Decisiones: D-1, D-2, D-F1…D-F10, todas
    cerradas; hilo completo en `P-ZRX/P-2.1/SINTESIS.md`.
  - **Pendiente: el código —ninguna de las 31 tiene una línea— y la deuda de evidencia de §2.9.**

- **GHOSTDAG y `rank` redactados en el SPEC (1.2 + 1.3)**, 2026-09-15. §11 pasa a nueve reglas
  (`C-GD-01`…`C-GD-09`) y §7.2 a tres (`C-ORD-01`…`C-ORD-03`), con la regla C, `blue_work` en u256
  y P1 sin su id final.
  - Evidencia: `ci/citas-spec.sh` da 181 reglas, todas implementadas o declaradas; los doce IDs
    nuevos están en `ci/reglas-sin-codigo.txt` hasta que haya código que los cite.
  - Pendiente: el código del nodo (nivel 2). La cabecera DAG quedó cerrada en el SPEC el
    2026-09-17 (§6.1–§6.2).
- **GHOSTDAG + `rank` en Julia (1.2 + 1.3, instrumento)**, 2026-09-14. `GDR-v0.2` en
  `veritas/consenso/ghostdag-rank-v1/`, con la regla C de Katana.
  - Qué calcula: color, cadena, orden y `rank`, que antes venían puestos a mano en los fixtures.
  - Qué queda probado: el resultado no depende del orden de llegada, y `rank` es total y
    compatible con la causalidad, demostrado por escrito.
  - Evidencia: 577 131 asserts; vectores de rusty-kaspa al 100 %; oráculo = kernel en 7 200 DAGs;
    regla C comprobada aparte por Claude en 168 869 bloques; `HUELLAS.sha256`.
  - Pendiente: redactar el SPEC.
- **Coste por salto en hardware (Q4)**, 2026-09-14. `veritas/rendimiento/coste-salto-v1/`: de
  1,33 a 9,86 ms según escenario (cifras en §3.1, Q4).
  - Evidencia: dos lotes separados 30 min; lote de Claude dentro del 3 %; `HUELLAS.sha256`.
  - Retira la cifra de 1,0773 ms por KZG, que no se reproducía: la medición vigente es 584 µs.
- **Δ natural medida en simulación (3.1, primer tramo)**, 2026-09-14. Instrumento `DMS-v0.1` en
  `veritas/finalidad/delta-medido-v1/`, revisión 2. Con la base decidida por Katana (100 Mbit/s
  de subida y relé compacto), Δ_99 p99 queda entre 0,26 y 0,60 s, frente a los 4 s que `k=30`
  tolera sin bloques honestos rojos. El bloque completo en el techo satura el enlace. Sigue
  siendo MS: sin mempool y sin adversario (v2); la validación por salto se midió después en
  hardware y cabe en ≤ 10 ms.
  Evidencia: 25 598 asserts; resultados de r1 y r2 reproducidos byte a byte por Claude con 16
  hilos frente a 24; `ENMIENDA-R2.md`, `HUELLAS.sha256`, `TRAZAS.sha256`.

- **Z0 / semántica de ventana vacía (antiguo 1.1)**, 2026-09-12. `HeldZero` pasa a no-op
  explícito: `causal_step` devuelve `(StepHeldZero, current, 0, false)` sin slot de activación,
  así que los seis puntos de llamada no pueden agendarla. CONTRATO de RCE-v0.1 y ARM-v0.1 suben a
  revisión 2; el vector `delay=2` (rango 100→200 revertido a 100 antes de la enmienda) queda como
  regresión permanente en el fixture. Convergencia Julia–Rust medida: `range_at(40) = 200` en
  ambos lenguajes.
  Verificado tras migrar: `cargo test --workspace` 485/486 (el único rojo es el preexistente de
  1.4, `el_spec_dice_el_tamano_real_de_la_cabecera`), `cargo fmt --check` y `cargo clippy -D
  warnings` en verde, Julia RCE 12856 + ARM 687 + comprobación decisiva 451 asserts en verde,
  `sha256sum -c HUELLAS.sha256` 35/35.
  Evidencia: commit `08b3681` en `rediseno/v1-spec-first`;
  `veritas/consenso/retarget-causal-endogeno-v1/ENMIENDA-Z0.md`.

- **Unicidad pagable (§7.2)**, 2026-09-12. Identidad pagable = el billete; contexto persistente
  con liberación en reorg; copia en fusión posterior o fuera de ventana = inerte por dos reglas;
  desempate **P1 azul primero**, decidido por Katana, separado por escrito del orden de aplicación
  de R-FIN-8′(4); y declarado que **refina R-FIN-8′(1)**, que al pie de la letra pagaría a dos
  copias `RedK` del mismo billete.
  Evidencia: `veritas/consenso/comprobacion-decisiva-v1/`, 449/449 asserts, reproducida de forma
  independiente por el auditor.
