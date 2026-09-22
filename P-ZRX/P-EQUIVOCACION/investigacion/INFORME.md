# INFORME — P-EQUIVOCACION

**Respuesta, en una línea:** la hipótesis del validador es **verdadera sólo bajo una premisa añadida
que ella no enuncia** —que la sub-rama privada no se lleve la cadena de la vista truncada `V_j`—, y
**falsa en general**: su primera mitad («las anclas activas son anteriores a la bifurcación») es un
**teorema** (`P2`), pero el paso «luego las dos ramas comparten flujo» **no se sigue** y tiene
contraejemplo (`P4`); la infracción estrecha **sí** alcanza casi todo el doble farmeo que importa,
pero **no por la razón que da la hipótesis** sino porque **ninguna de las tres identidades contiene
el reto ni la rama** (`P7`) — y **`κ` es la fracción de slots de doble farmeo con flujo compartido**,
que es **1 siempre que el atacante no gane la carrera del ancla** y cae sólo en la cola de la ventana
cuando la gana; definir la infracción **sin castigar a honestos exige un firmante seguro**, que es
implementable pero tiene un coste honesto declarable (`FALSOS-POSITIVOS.md` §3).

---

## 1 · La respuesta, por partes

### 1.1 · ¿Es cierta la hipótesis? — verdadera bajo condición, falsa tal como está escrita

| Pieza de la hipótesis | Veredicto | Etiqueta |
|---|---|---|
| «las anclas de las inyecciones activas son anteriores a la bifurcación» (`slot(I_j) < s₀`) | **cierta** para toda inyección activa en la ventana, bajo 1a | `demostrado` (`P2`) |
| «luego las dos ramas comparten flujo» | **no se sigue**; es cierta sólo si el **bloque** ancla coincide, y eso exige una premisa añadida | `demostrado` (`P3`) + contraejemplo (`P4`) |
| «tienen los mismos retos» | cierta exactamente cuando el flujo coincide (`C-POT-03`) | `demostrado` |
| «quien farmea doble **duplica necesariamente la misma oportunidad**» | **cierta para identidades basadas en la pieza**, y **por una razón distinta**: la identidad no contiene el reto, así que no hace falta que los flujos coincidan | `demostrado` definicional (`P7`) |
| «su única salida es repartir su espacio» | **incompleta**: hay tres salidas, y dos no son «repartir» | `enumerado` (`P8`, `FALSOS-POSITIVOS.md`) |

**El contraejemplo, en una frase** (`P4`): con `I = 20`, `L = F = 20`, `S_max = 15`, una rama privada
que bifurca en el bloque común de slot `5 < T_1 = 20` y acumula **más bloques dentro de `V_1`** que la
cadena común en el intervalo `(5, 25]` hace que `Chn(V_1(B))` cruce `T_1` en un bloque **privado** de
slot 20 mientras `Chn(V_1(A))` cruza en el bloque **común** de slot 25. Las dos anclas son anteriores
a `s₀ = 25` (la hipótesis acierta en eso) y **son bloques distintos**: los retos difieren desde el
slot 40. Esto es exactamente el caso **A2** que
`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` §0.4 ya marca «PROBABILÍSTICO, no demostrado y NO
medido», no un hallazgo nuevo sobre el protocolo: lo nuevo es **delimitar que es la única fuga por el
ancla** y que su condición exacta es `n_priv > n_com` dentro de `V_j` (`P5`).

### 1.2 · ¿Cuánto vale `κ`?

`κ` = fracción del doble farmeo que deja evidencia castigable. Se descompone (`P8`) en la fracción de
slots de doble farmeo con flujo compartido y la que no:

```text
κ(id) = (|W_c|/|W|)·κ_comun(id) + (|W_d|/|W|)·κ_div(id)
```

**Medido** (`resultados/kappa-identidad.csv`, universo finito exacto, 32 piezas × 4 `chunk` y el
escenario `misma-parcela` de 1 pieza × 8 `chunk`):

| Régimen | `C-GD-07` (con `chunk`) | `IDV-01` / `CANDIDATA` (por pieza) |
|---|---|---|
| Flujo **común**, `m ≤ 0.05` | **1.000** | **1.000** |
| Flujo **común**, `m = 1` | 0.455 | 0.455 |
| Flujo **común**, `m = 4` | 0.000 | 0.000 |
| Flujo **común**, `misma-parcela`, `m = 1 … 4` | 0.286 → 0.000 | **1.000** |
| Flujo **divergente**, con oportunidad | **0.000** | **0.000** (0.000 con varias piezas; **1.000** en `misma-parcela`) |

donde `m` = número esperado de soluciones ganadoras del atacante **por slot** en su parcela
(`m ≈ α·(ganadoras de la red por slot)`). **Región** (`derivado` de la enumeración, no medido en
red): para un atacante pequeño (`m ≪ 1`, el caso de `CANDIDATA.md` §A.1) y con identidad basada en la
pieza, **`κ ≈ κ_flujo`**; y `κ_flujo = 1 − (slots divergentes)/|W|`, con
`slots divergentes ≲ δ := s₀ − T_j`. En la rejilla declarada, 54 de 480 configuraciones **no** tienen
escape y en las 54 el `κ_flujo` es exactamente 1.0000.

**Relación con `α` — `derivado`, NO medido.** La condición del escape (`P5`) es que la sub-rama
privada tenga más bloques dentro de `V_j` que los comunes en `(slot(W), s₀]`: eso exige
`α·(L + x) > δ + x`, es decir `α > (δ+x)/(L+x)`; y el número de slots divergentes es `≲ δ`.
Despejando, **la fracción de la ventana que escapa es del orden de `α`**, de modo que
`κ_flujo ≳ 1 − O(α)`. Es un argumento sobre el **modelo**, no una medición: la carrera real tiene
varianza y su cola **no está medida** (`D2` y `D3` de `DECISIONES-PENDIENTES.md`). No usar esto como
cifra.

> **La cifra que NO hay que usar.** `bench/escalado.jl` imprime `kappa_flujo_global = 0.764` sobre
> 5 256 slots: es un **agregado de la rejilla**, que sobre-representa el escape. No es una estimación
> de `κ` del sistema y no debe entrar en `P-ZRX/P-PRESTAMO/` como tal.

### 1.3 · ¿Se puede definir la infracción sin castigar a honestos?

**Sí, con un requisito de producción explícito, y con un coste honesto que hay que decir en voz
alta.** El catálogo exhaustivo está en `FALSOS-POSITIVOS.md`; el resumen:

- Las conductas honestas que producen `mismo TicketId y slot + dos pre_hash` son **reales y
  frecuentes**: dos *harvesters* redundantes sobre la misma parcela con vistas distintas de las
  puntas (con `max_block_parents = 15` y cola de candidatos barajada, `C-GD-10`, dos nodos eligen
  padres distintos **casi siempre**); reinicio con pérdida de estado; producción para un slot pasado
  tras adoptar la rama rival, admisible mientras `slot(B) − slot(sp(B)) ≤ S_max` (`C-GD-04`); y
  reempaquetado con otro cuerpo (que **sí** cambia `pre_hash`, porque la prefirma compromete
  `merkle_root` / `body_commitment`, `C-HDR-03`).
- La única defensa es el **firmante seguro**: persistir atómicamente `TicketId → pre_hash` **antes**
  de firmar, negarse a firmar otro `pre_hash` para el mismo `(TicketId, slot)`, y **abstenerse
  durante `S_max_slots`** si pierde el registro — que es justo el plazo en que un bloque para un slot
  pasado sigue siendo válido.
- **Lo que no cubre**: dos máquinas que no comparten el registro, una clave compartida o robada, y un
  registro perdido sin copia. `FALSOS-POSITIVOS.md` §3.4.
- **Coste honesto que no estaba escrito**: tras un reorg, `SPEC.md` §7.2 dice que el billete de la
  historia abandonada «vuelve a estar disponible»; con la infracción estrecha, el firmante seguro
  **debe negarse a reusarlo**, porque reusarlo es exactamente la conducta castigada. La
  reconciliación entre §7.2 y la infracción es una decisión, no un detalle
  (`DEFINICION-PROPUESTA.md` §5).

### 1.4 · La evidencia, como objeto verificable

El `pre_hash` y no el `block_hash`: `block_hash` incluye el sello y el sello Ed25519 **no es único
para el mismo mensaje** (`SPEC.md` C-HDR-04, con la regresión real
`crates/zx-core/tests/ed25519_no_unicidad.rs`). Comparar `block_hash` produciría evidencia **falsa**.
Con `pre_hash` la evidencia es autocontenida: las dos cabeceras bastan para comprobar las dos firmas,
porque `pre_hash = H_d("ZZKBlkPreHash___", prefirma)` y la prefirma es la cabecera sin el sello
(`C-HDR-03`). Lo que **no** es autocontenido es la coletilla «ambas cabeceras válidas en su
contexto»: con validez absoluta (`C-FLU-13`) la validez de `B` es función de `past(B)`, y un nodo que
sólo tiene la historia ganadora **no puede** comprobar la cabecera perdedora salvo que las dos ramas
compartan flujo — que es precisamente el caso que `P4` rompe. Detalle y tamaños:
`DEFINICION-PROPUESTA.md` §4.

---

## 2 · Alcance, presupuesto y qué se ejecutó

- **Zona de escritura:** sólo `P-ZRX/P-EQUIVOCACION/investigacion/`. `PROMPT.md`, `CANDIDATA.md` y
  `ENTRADA.sha256` son de solo lectura y **no** se tocaron (`ENTRADA.sha256` verificado al empezar y
  al terminar, `PROGRESO.md` §1 y §5).
- **Lecturas abiertas antes de citarlas:** `veritas/LINEO.md` (íntegro), `P-ZRX/P-EQUIVOCACION/CANDIDATA.md`
  (íntegro), `SPEC.md` §6.1–§6.2, §7.1–§7.5, §11, §12, §17,
  `veritas/consenso/identidad-disponibilidad-v1/` (IDENTIDAD, CONTRATO-VALIDACION, INFORME,
  DISPONIBILIDAD), `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` §0.4 y §2,
  `veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6, `P-ZRX/P-2.1/SINTESIS.md`,
  `research/README.md`. Las precedentes externos (SpaceMint, doble firma en validadores PoS) **no se
  citan** porque no se abrió ninguna fuente primaria: quedan **no verificadas** y fuera de este
  informe.
- **Presupuesto declarado:** ≤ 4 hilos, ≤ 4 GiB de RAM, ≤ 200 MiB de disco, corridas de minutos.
  Usado de verdad: 4 hilos, < 1 giB, < 1 MiB. Ninguna corrida agotó el presupuesto.
- **Entorno:** Julia 1.13.0, AMD Ryzen 9 9950X3D (`znver5`), 32 hilos lógicos, 123,4 GiB de RAM,
  Linux x86_64, `libopenblas64_` (`resultados/ENTORNO.txt`). Sin GPU, sin Python, sin `@fastmath`.
- **Comprobaciones ejecutadas:** `test/runtests.jl` → **567/567**; contraste referencia↔kernel sobre
  **1 200 DAGs aleatorios** más los vectores de regresión; rejilla de **480 configuraciones**;
  microbenchmarks y escalado 1/2/4 hilos.

---

## 3 · Parte A — cuánto doble farmeo deja evidencia

El desarrollo completo está en `PROPOSICIONES.md`. Lo esencial:

1. **`P1` + `P2` (demostrados).** El ancla cae en `[T_j, T_j + S_max)` y, si la inyección está activa
   en la ventana, su slot es **anterior a la bifurcación**: `slot(I_j) < s₀`, porque
   `slot(I_j) = t_j − L ≤ s − L < s₀ + F − L ≤ s₀` (perfil 1a).
2. **`P3` (demostrado).** Si el **bloque** ancla coincide en las dos ramas, el flujo coincide en toda
   la ventana y los retos son idénticos. La causalidad es directa: `C-FLU-12`, `C-FLU-07`, `C-FLU-10`.
3. **`P4` (contraejemplo).** «Anterior a la bifurcación» **no** implica «mismo bloque». El escalón que
   falta es que `Chn(V_j)` cruce `T_j` en el mismo bloque, y `V_j` es una vista **truncada** que crece
   al fusionar bloques retenidos sin que ninguna regla de finalidad lo impida (`C-FLU-04`, nota (1)).
4. **`P5` (demostrado + enumerado).** La condición exacta del escape es `n_priv > n_com` dentro de
   `V_j`, con empates resueltos por `C-GD-03`. En la rejilla: 418/418 en un sentido, 36/36 en el
   otro, 26 empates resueltos por `solution_distance` (18 a favor de la común, 8 de la privada).
5. **Asimetría de la carrera (`derivado`, no medido).** Dentro de `V_j(B)`, el `blue_work` de la rama
   honesta **se detiene en `P`** (los bloques honestos posteriores no están en `past(B)`), mientras
   que el atacante puede seguir sumando hasta el corte `T_j + L`: tiene `L − δ` slots de presupuesto
   extra. **No contradice a** CRP-v0.1 (`α_mínimo = 1/2`), que mide la rama privada frente a la
   cadena **completa**; mide **otro** objeto. La cola de esta carrera sigue **sin medir**.
6. **`P6` (derivado + enumerado).** La divergencia sólo cubre la **cola** de la ventana: los slots
   coincidentes son exactamente los anteriores a `t_min = mín(t_j(A), t_j(B))`. En la rejilla: con
   `δ = 1`, 1 de 19 slots; con `δ = 4`, 4 de 19.
7. **`P7` (demostrado, definicional) — la pieza que decide.** Ninguna de las tres identidades contiene
   padres, rama, flujo, reto ni `pre_hash`. Consecuencia doble: (a) la evidencia **no necesita** que
   los flujos coincidan; (b) el escape por el ancla **queda estrechado**: con identidad basada en la
   pieza, evadir exige **otra pieza ganadora** en el otro reto, no basta con que el reto cambie.
8. **`P8` (enumerado).** Y ahí está la diferencia real entre las tres identidades: `C-GD-07` incluye
   `chunk`, y una **misma pieza** admite varias soluciones ganadoras con `chunk` distinto
   (`veritas/consenso/identidad-disponibilidad-v1/IDENTIDAD.md` §4, medido con el verificador PoAS
   real). Por eso `κ(C-GD-07) ≤ κ(IDV-01) = κ(CANDIDATA)`, y la brecha crece con `m`.

### 3.1 · Reconciliación de las tres identidades (§1 del encargo)

| | `C-GD-07` / R-FIN-11 | IDV-01 | `CANDIDATA.md` |
|---|---|---|---|
| Campos | `(pk, sector, historia, chunk, slot)` | `(dominio, slot, pk, sector, historia, piece_offset)` | `H(dominio, slot, PlotBatchId, sector, piece_offset)` |
| ¿Objetiva entre ramas? | **sí** (no contiene padres ni rama) | **sí** | **sí** |
| ¿Distingue dos soluciones de la **misma pieza**? | **sí** (por `chunk`) | **no** | **no** |
| ¿Distingue dos **offsets** con el mismo `chunk`? | **no** ← colapsa dos oportunidades distintas | **sí** | **sí** |
| ¿Ambito de red? | no lo declara | `dominio` de red/era | `dominio` |
| Consecuencia medida | κ menor: el atacante evade cambiando de `chunk` en la misma pieza | κ mayor en todos los regímenes medidos | igual que IDV-01 |

**Cuál hace la evidencia objetiva entre ramas: las tres**, porque ninguna contiene nada de la rama.
**Cuál conviene:** IDV-01 o la de `CANDIDATA.md`; `C-GD-07` es simultáneamente **más fina** de más
(parte la misma oportunidad en varias) y **más gruesa** de menos (colapsa dos offsets con igual
`chunk`). **Entre flujos distintos (mismo slot y misma pieza, reto distinto):** con `C-GD-07` no hay
infracción —el `chunk` ganador cambia—; con IDV-01/CANDIDATA **sí** la hay *si la misma pieza gana
los dos retos*, que es justo lo que el atacante pequeño no consigue.

### 3.2 · El escapado por el ancla, delimitado frente a la partición de flujo

El encargo pide delimitar dónde acaba un caso y empieza el otro. **Es el mismo caso.** El escape
exige que la sub-rama retenida se lleve `Chn(V_j)`, y eso es exactamente lo que
`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` §0.4 llama A2 y lo que
`SPEC.md` C-FLU-15 trata como partición de flujo (con `C-FLU-14` impidiendo fusionar y `C-FIN-01`
limitando la reorganización). No hay un mecanismo separado que auditar: o la sub-rama no se lleva la
cadena —y entonces el flujo es común y la infracción estrecha lo alcanza— o se la lleva, y entonces
ya hay partición de flujo, con el umbral de CRP-v0.1 y la cola sin medir. La antelación necesaria no
es «un bloque antes»: la sub-rama debe bifurcar **por debajo de `T_j`** (`SPEC.md` C-FLU-04, nota
(1)) y **dentro del corte `T_j + L`**, y `L ≥ S_max + 1` la obliga a extenderse hacia arriba.

### 3.3 · Las otras fugas de `CANDIDATA.md`, una por una (§2.3 del encargo)

`P-ZRX/P-EQUIVOCACION/CANDIDATA.md` §«Lo que no debe prometer» lista seis cosas que el mecanismo no
cubre. El encargo pide decir, para cada una, si es **de verdad una fuga bajo 1a** o si queda reducida
a **repartir el espacio** (que ya no es doble farmeo).

| Fuga listada | ¿Es fuga bajo 1a? | Por qué |
|---|---|---|
| **Slots alternos** (`trabajar ramas diferentes en slots alternos`) | **NO — es repartir el espacio** | La parcela se usa **una vez por slot**: no hay dos bloques con el mismo slot, luego no hay nada que castigar y tampoco doble uso. Su peso efectivo por flujo se divide, así que no hay ganancia frente a elegir un flujo. `derivado`. |
| **Retos distintos de flujos distintos** | **SÍ — es la única fuga real por el ancla** | Es el escape A2 de `P4`/`P5`: la misma parcela se usa dos veces en el mismo slot con **dos soluciones distintas**. Con identidades de piezas distintas y varios candidatos, `κ_div = 0` medido; con **una sola pieza**, IDV-01/CANDIDATA dan `κ_div = 1.000` (la pieza es la misma aunque el reto cambie). Exige ganar la carrera de `blue_work` dentro de `V_j`. |
| **Parcelas propias preparadas con antelación** | **NO es una fuga distinta — es el insumo de la anterior** | «Preparar con antelación» = bifurcar por debajo de `T_j` (`x = T_j − slot(W) ≥ 1`). No evade nada por sí solo: sin ganar la carrera de `P5` no cambia el ancla. Su coste es `α*` y su cola **no está medida**. `derivado`. |
| **Una rama privada nunca revelada** | **SÍ, y es la fuga más incómoda; limita qué puede significar `κ`** | La evidencia exige que **los dos** bloques existan y sean conocidos. Un atacante que sólo publique la rama que va ganando nunca deja el par. Lo que **no** es gratis es retener: mientras la rama está oculta su `blue_work` no compite, y publicar tarde puede dejarla fuera del alcance de fusión (`C-GD-11`, hoy `<<PENDIENTE>>`). Si el saldo neto es positivo **no está medido aquí** ni en el repositorio. Consecuencia que hay que asumir: **`κ` mide el doble farmeo *publicado*, no el doble farmeo posible.** |
| **Censura temporal de la prueba** | **SÍ, pero es un problema de viveza, no de identidad** | El castigo de `CANDIDATA.md` §6 es **prospectivo** («cuando la evidencia entra en la historia seleccionada»). Quien pueda mantener la prueba fuera de la historia seleccionada retrasa o evita el castigo. No lo arregla ninguna identidad de billete. `derivado`; sin medir. |
| **Un doble gasto cuyo beneficio supere lo confiscable** | **SÍ, y no es un problema técnico** | El mecanismo topa la pérdida en las recompensas retenidas más el lote. Si el beneficio esperado del doble uso las supera, el cálculo racional sigue favoreciendo la trampa. Es la entrada que `P-ZRX/P-PRESTAMO/` necesita de este trabajo: **`κ`**, no una cifra nueva. `derivado`. |
| **Clave robada o *pool* custodial** (del catálogo del encargo §2.3) | **SÍ, y además es un vector de *griefing*** | Dos operadores con la misma clave y la misma parcela producen la evidencia sin mala fe; y un tercero con la clave puede **provocar** la confiscación del lote ajeno. `FALSOS-POSITIVOS.md` FP6. |

**Resumen de la §2.3: de las siete, dos no son fugas** (slots alternos y parcelas preparadas: la
segunda es el insumo de la de retos distintos), **una es la fuga central** (retos distintos = A2),
**dos son escapes fuera del alcance de cualquier regla de identidad** (rama nunca revelada y censura
de la prueba), **una es económica** (beneficio > confiscable) y **una es un falso positivo con vector
de *griefing*** (clave compartida o robada).

---

## 4 · Parte B — qué honestos caerían

Resumen: **caerían, y con frecuencia alta**, si la infracción se adopta sin firmante seguro. El
catálogo exhaustivo, con la frecuencia esperable como función, en `FALSOS-POSITIVOS.md`. Los tres
casos dominantes: *harvesters* redundantes (probabilidad ≈ 1 por slot en que ambos producen),
reinicio con pérdida de estado, y producción para un slot pasado tras adoptar la rama rival.

---

## 5 · Parte C — la evidencia como objeto verificable

Resumen: núcleo **autocontenido** (dos cabeceras: prefirmas, dos `pre_hash` distintos, dos sellos
Ed25519 válidos bajo la misma `sol.public_key`, mismo `TicketId` y mismo slot) de **589 + 589 B
mínimo** y **1 037 + 1 037 B máximo** por cabecera (`C-HDR-01`), más la justificación PoT de la
cabecera perdedora (hasta 19 201 B, `C-HDR-09`) **sólo si se exige «válida en su contexto»**.
Lo que impide fabricar una prueba contra un honesto es la **firma**: no se puede producir el segundo
sello sin la clave. El detalle, con el árbol de decisión y el plazo tras la poda, en
`DEFINICION-PROPUESTA.md` §4.

---

## 6 · Qué reglas vigentes tocaría

En `DEFINICION-PROPUESTA.md` §5, como **propuesta y no como SPEC**. Los tres puntos que no son
redacción menor: §7.2 (el billete vuelve a estar disponible tras un reorg, y su vector
`fixture_reorg_libera_billete` **es** la infracción estrecha), `C-GD-07`/R-FIN-11 (la identidad),
y la ausencia de una regla de producción que obligue al firmante seguro.

---

## 7 · Reproducción

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-EQUIVOCACION/investigacion/veritas/consenso/equivocacion-v1
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. test/runtests.jl
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=4 run.jl --modo todo
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=4 bench/benchmarks.jl
for t in 1 2 4; do /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=$t bench/escalado.jl; done
```

Semillas: `0x5a5a` (contraste, 500 casos), `0x1234` (300), `0xBEEF` (200), y la cuarta familia usa el
mismo `rng` tras las anteriores; `StableRNGs` fija el flujo entre versiones. Resultados en
`resultados/` (`contraste.txt`, `kappa-flujo.csv`, `kappa-identidad.csv`, `benchmark.txt`,
`ENTORNO.txt`).

### 7.1 · Coste medido (LINEO §6)

| variante | tiempo mediano | asignaciones | memoria | hilos |
|---|---:|---:|---:|---:|
| `seleccion_vista` (base) | 18,07 µs | 1 254 | 47,66 KiB | 1 |
| `seleccion_vista!` (buffers preasignados) | **8,17 µs** | **72** | **2,42 KiB** | 1 |
| `kappa` (20 slots, 128 candidatos) | 146,93 µs | 2 299 | 86,27 KiB | 4 |

Escalado de la rejilla completa (384 celdas, 5 256 slots): **0,174 s** (1 hilo) → **0,114 s** (2) →
**0,068 s** (4), con `κ_flujo` global **idéntico** en los tres (reducción entera determinista,
`resultados/escalado.txt`). No se conserva una configuración con más hilos porque el tope declarado de
este encargo es 4.

---

## 8 · Lo que esta investigación NO resuelve

1. **No mide la cola de A2.** La probabilidad de que la sub-rama privada se lleve `Chn(V_j)` —la
   carrera de `blue_work` dentro de `V_j`— no está medida aquí, ni lo estaba en
   `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` §0.4 (P2b: «NO medido»). `P5` da la
   **condición** exacta, no su probabilidad.
2. **`κ` mide doble farmeo PUBLICADO, no doble farmeo posible.** La evidencia exige que los **dos**
   bloques existan y sean conocidos. Un atacante que sólo publique la rama que va ganando no deja el
   par (§3.3, «rama privada nunca revelada»). Cuánto le cuesta retener —y por tanto si esa estrategia
   es rentable— **no está medido**, y depende de `C-GD-11`, que sigue `<<PENDIENTE>>`. **Ninguna
   identidad de billete puede cubrir ese caso**; lo único que puede decirse es que no lo alcanza.
3. **No mide la asimetría que descubre `P5`.** Que el `blue_work` honesto dentro de `V_j(B)` se
   detenga en `P` mientras el atacante puede seguir sumando hasta `T_j + L` es un **argumento**
   derivado del texto de `C-FLU-04`; su consecuencia sobre `α*` no se ha medido ni simulado. Es la
   primera cosa que habría que medir y **puede mover el resultado económico**.
4. **No fija ningún parámetro de consenso**: `I`, `F`, `L_suelo`, `S_max`, `k`, `D`, `W_dec` y la
   distribución de `δ` siguen siendo símbolos (`SPEC.md` §7.3).
5. **No sabe si el contraejemplo es alcanzable en el consenso destino.** La fusión de un bloque con
   `slot` muy anterior al de la punta es lo que `C-GD-11` (*bounded merge depth*) existe para
   limitar, y **sus cinco valores siguen `<<PENDIENTE>>`**. Si `C-GD-11` acaba siendo estrecho, el
   contraejemplo puede ser **inalcanzable**; el teorema `P2` y la refutación `P4` seguirían siendo
   ciertos como enunciados, pero su relevancia práctica cambiaría. Declarado también en
   `DECISIONES-PENDIENTES.md`.
6. **No mide la multiplicidad de pruebas PoS.** `IDENTIDAD.md` §4 e `INFORME.md` §1 verifican que dos
   pruebas distintas del mismo `offset/seed/bucket` **son aceptadas** por el verificador real; **a
   qué coste y con qué plazo** se consiguen, no se mide allí ni aquí. La brecha entre identidades de
   `P8` depende de ese número.
7. **No decide el castigo.** `κ` dice qué fracción deja evidencia; **no** dice cuánto hay que
   confiscar, ni resuelve el `α* = (1 − β)/2` de `CANDIDATA.md` §A.1, ni la varianza corta.
8. **No valida el mecanismo en red.** Todo el enumerador es un **modelo declarado**: sin firmas, sin
   KZG, sin red, sin `PoT` AES, con un predicado de elegibilidad sintético. Las afirmaciones
   marcadas `enumerado` son sobre la rejilla publicada, no sobre ZEROX en ejecución.
9. **No cierra la tensión §7.2 / infracción.** Se describe y se propone una salida; la decisión es de
   Katana (`DEFINICION-PROPUESTA.md` §5).
10. **No cubre los precedentes externos.** SpaceMint y la protección contra doble firma en validadores
   PoS se dejan **no verificados**: `PROMPT.md` §6 pide fuentes primarias abiertas y no se abrió
   ninguna.
