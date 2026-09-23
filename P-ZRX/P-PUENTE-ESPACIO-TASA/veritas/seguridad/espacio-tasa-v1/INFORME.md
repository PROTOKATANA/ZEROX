# INFORME — espacio-tasa-v1 · El puente de bytes de parcela a tasa de peso

> **Revisión 2 (corrección).** Este informe sustituye a la revisión 1, que tenía errores
> verificables. El detalle «afirmación anterior → corrección → fuente/test» está en
> [`INFORME-CORRECCION.md`](INFORME-CORRECCION.md), con las cifras que **siguen** siendo válidas.
> El veredicto **no** ha subido: sigue **sin** poder cuantificarse la caída del umbral de seguridad
> de ZEROX por doble farmeo (§9).

**Categoría dominante:** `seguridad`. **Secundarias:** `consenso` (peso y `blue_work`) y
`almacenamiento` (bytes de sector). Se declara aquí conforme a `veritas/LINEO.md` §1.

**Pregunta:** dada una capacidad *nominal* de parcelas PoAS, ¿cuántos chunks se auditan, cuántos
candidatos aparecen, cuántas pruebas verifican y qué tasa de peso puede justificarse por slot?

**Respuesta corta.** El puente se **mide** hasta *candidatos PoAS por slot*. La etapa central
—bytes → chunks auditados— tiene **media exacta** `piezas/2` (medido: 500,000000 con 1000 piezas)
pero **varianza 163,1689×** la del modelo «ocupación constante 1/2», y un sector de 1000 piezas
audita **cero** chunks en el **9,0668 %** de los slots. Las fracciones de bytes, de piezas, de
candidatos y de trabajo azul **no son la misma magnitud** y se publican por separado (§4). De
`blue_work/slot` se entrega **solo la fórmula condicional** (§6). **No se puede cuantificar la caída
del umbral de seguridad por doble farmeo** (§9).

**Presupuesto declarado antes de ejecutar** (`PRESUPUESTO.md`): 16 hilos, 8 GiB de RAM, 6 GiB de
disco, 3 h. **No se agotó**; la corrida más larga fueron 90 s.

---

## 0 · Qué se midió, con qué, y qué NO

| | |
|---|---|
| Fuente fijada | Autonomys `f8842d019cdf0f7163421b9644db5a9ff82b2a73`, clon limpio, usado **solo como dependencia por ruta**. Huellas en `PROCEDENCIA.md` y `resultados/FUENTES-AUTONOMYS.sha256`. |
| Oráculo | `oraculo-rust/`: llama a la API **pública** del clon (`Tables::create_proofs_parallel`, `ErasureCoding::extend`, `blake3_hash_with_key`, `bidirectional_distance`, `is_within_solution_range`, `sector_size`, `is_proof_valid`). No reimplementa primitivas. |
| Tablas PoS | **Reales**: `create_proofs` sobre las semillas que derivan `SectorId::derive_evaluation_seed`. 1000 piezas → 32 768 000 pruebas. |
| Codificación y hashes | **Reales**: `ErasureCoding::extend` sobre el registro y `chunk = record_chunk XOR blake3(proof)`, como en `plotting.rs:659-661`. |
| **Registros fuente** | **SINTÉTICOS.** Los bytes de historia que se codifican no proceden de historia archivada de ZEROX: se generan con `blake3` a partir de la semilla de evaluación. La estadística del puente no depende de su valor, pero **no se materializó historia real**. |
| **Bytes materializados** | **8 192 000 B** (`resultados/bitmaps.bin`, 1000 mapas de 8 192 B). **No** se escribió en disco un sector físico completo de ~1 GiB; los chunks viven en RAM durante la corrida de `audita`. |
| Verificación | **Solo la prueba PoS** de un candidato, con `is_proof_valid`. **No** se pasó ninguna solución por `verify_solution` (compromiso de registro, testigo KZG, firma, cabecera, PoT, admisión DAG). Ver §5. |
| Sujeto de medida | Un conjunto de **1000 piezas** (= `MAX_PIECES_IN_SECTOR`) con la geometría de un sector: 1 056 896 064 B nominales. **No** es un sector físico materializado ni un nodo. |
| Reproducción | `METODO.md`, con el comando exacto de cada tabla. |
| **No** medido | Admisión PoST + DAG, controlador de rango, retarget causal, red, PoT real, **preexistencia** de los bytes, y `blue_work` de una red ZEROX. Todo eso se marca `pendiente` o `condicionado`. |

**Aviso que gobierna este informe.** El formato **no** acredita que el granjero conserve la parcela
completa: `verify_solution` deriva el `sector_id` de la propia solución y no lo contrasta con nada, y
la preexistencia «hoy **nada** la acredita` (`P-ZRX/P-COBERTURA/investigacion/INFORME.md` §2.4).
Todas las cifras de espacio son **bytes que el protocolo auditaría suponiendo que existen**. Este
experimento **no acreditó almacenamiento físico ni preexistencia**, y no se afirma lo contrario.

---

## 1 · El puente, etapa por etapa

`bytes solicitados → sectores completos → piezas efectivas → chunks auditados/slot → candidatos
→ pruebas PoAS verificadas → bloques admisibles → bloques azules → trabajo azul/slot`

| Etapa | Valor o fórmula | Estado | Fuente / criterio |
|---|---|---|---|
| Bytes **solicitados** | lo que el granjero declara | `derivado` | entrada |
| Bytes de **sectores completos** | **por actor**: `⌊bytes_i / sector_size(1000)⌋ · sector_size(1000)` (esc. 1) o `⌊Σbytes / s⌋ · s` una sola vez (esc. 2) | `derivado` | el formato fija `pieces_in_sector`; un sector incompleto no es un sector. Ver §4 |
| **Sobrantes** | `bytes_i − sectores_i·s`, **no** son piezas y **no** se comparten en el esc. 1 | `derivado` | — |
| **Piezas efectivas** | `Σ sectores_i · 1000` en el esc. 1; `⌊Σbytes/s⌋ · 1000` en el esc. 2 | `derivado` | las únicas auditables; el esc. 1 da `≤` el esc. 2 |
| `sector_size(1000)` | **1 056 896 064 B** | `derivado` + **contrastado** | `sector.rs:47-53`; contraste con la API en `resultados/constantes.tsv` |
| Chunks auditados/slot, **media** | `piezas/2` | `derivado`, **confirmado** | 500,000000 medido |
| Chunks auditados/slot, **varianza** | `40 792,2309` por sector | `medido` | referencia `M/4 = 250` → **163,1689×** |
| Probabilidad por chunk auditado | `p(SR) = A(SR)/2^64`, `A(SR)=2⌊SR/2⌋+1` | `derivado`, **confirmado** | `verification/src/lib.rs:150-158` |
| Candidatos/slot | `chunks_auditados · p(SR)` | `medido` (PoAS) | §5 |
| **Pruebas PoAS verificadas** | `candidatos · π_validez` | **`pendiente`** | solo se verificó la prueba **PoS** de 1 candidato; `verify_solution` no se ejecuta en ZEROX |
| **Bloques admisibles** | `candidatos · π_validez · π_admision` | **`pendiente`** | admisión PoST + DAG no implementada; `AlmacGhostdag::admitir` es puerta **parcial** de rango; `zx-node` sigue lineal |
| **Bloques azules** | `… · β` | **`pendiente`** | `blue_work` suma **solo azules** (`SPEC.md` C-GD-08) |
| Peso por bloque | `w(SR) = ⌊2^128/(SR+1)⌋`, exacto en `BigInt` | `derivado` | `SPEC.md` C-GD-01 (`SPEC.md:2310`) |
| **Trabajo azul/slot** | `candidatos · π_validez · π_admision · β · w(SR)` | `condicionado` | los tres factores se mantienen **separados**; §6 |

**Los tres factores desconocidos no se absorben unos en otros.** `π_validez` (verificación completa),
`π_admision` (admisión PoST + DAG) y `β` (fracción azul) son magnitudes distintas, cada una
`pendiente`, y así aparecen en `resultados/CIFRAS.tsv` como filas propias con valor `nothing`.

---

## 2 · Tabla principal (1000 piezas, geometría de un sector)

Ficheros: `resultados/OCUPACION.tsv`, `AUDITORIA.tsv`, `CANDIDATOS.tsv`, `TABLA-VARIANZA.md`,
`TABLA-PUENTE.md`, `constantes.tsv`.

| Magnitud | Valor | Unidad | Denominador | Estado |
|---|---:|---|---|---|
| `sector_size(1000)` | 1 056 896 064 | B | sector de 1000 piezas | `derivado`, contrastado con la API |
| `1000 · Piece::SIZE` | 1 048 672 000 | B | — | `derivado` (no se usa como bytes físicos) |
| Diferencia | **8 224 064** | B | — | `derivado`: `1000·32 + 1000·8192 + 64` |
| Metadata **fuera** del fichero de sector | 131 116 | B/sector | `SectorMetadataChecksummed::encoded_size()` | `derivado`, contrastado |
| Bytes realmente materializados | 8 192 000 | B | `bitmaps.bin` | `medido` |
| Piezas | 1 000 | piezas | — | `medido` |
| Pruebas por pieza | 32 768 | pruebas/pieza | 65 536 buckets | `medido` (mín = máx) |
| Ocupación media por bucket | 0,500000000000 | pruebas/bucket | pieza·bucket | `medido` (exacto) |
| `s_bucket_size`: media | 500,000000 | chunks | bucket | `medido` |
| `s_bucket_size`: varianza | 40 792,2309 /(n−1); 40 791,6085 /n | chunks² | **65 536 buckets (universo completo del sector)** | `medido` |
| Cociente vs `Binomial(1000,½)` (var 250) | **163,1689** /(n−1); **163,1664** /n | — | `M/4` | `medido` → `TABLA-VARIANZA.md` |
| `s_bucket_size`: mín / mediana / máx | 0 / 584 / 658 | chunks | bucket | `medido` |
| Cuantiles 25/75/95/99 | 567 / 596 / 612 / 623 | chunks | bucket | `medido` |
| Buckets vacíos | 5 942 (**9,0668 %**) | buckets | 65 536 | `medido` |
| Chunks auditados/slot (512 retos) | 516,660 | chunks/slot | **512 retos (muestra)** | `medido` |
| Chunks auditados/slot: varianza | 34 108,2209 | chunks²/slot | 512 retos | `medido` |
| Cociente vs `M/4` | **136,4329** | — | `M/4` | `medido` |
| Índice de Poisson (`var/media`) | **66,0167** | — | **la media** | `medido` |
| Chunks auditados/slot: rango | 0 … 629 | chunks/slot | 512 retos | `medido` |
| Slots con **cero** chunks auditados | 38/512 = 7,42 % (exacto: 9,0668 %) | fracción | por sector y slot | `medido` + `derivado` |
| Coincidencia Julia ↔ Rust del conteo | 512/512 | retos | — | `medido` |
| Cota superior 95 % **unilateral** de `P(≥1 candidato/slot)`, en los `SR` con **0 candidatos en los 512 retos** (`SR ≤ 4 294 967 296`) | **5,83·10⁻³** | fracción | 512 retos con 0 observados | `derivado`; bilateral al 95 %: 7,18·10⁻³. De ella se sigue `P(0 por slot) ≥ 0,99417`, **no** la conjunta de los 512 slots (esa sería `≥ 0,05`). Con el `SR` calibrado **sí** se observaron candidatos (79), y ahí la cota no aplica |
| Coste de auditar 6144 (reto, `SR`) | 0,44 | s | 16 hilos | `medido` |
| **Trabajo azul/slot** | — | — | — | **`condicionado`**, §6 |

Los cocientes de varianza (163,1689 / 163,1664 / 136,4329 / 66,0167) **no son intercambiables**:
tienen poblaciones, convenciones (`/(n−1)` frente a `/n`) y denominadores distintos. Los 512 retos
cubren solo **510 buckets distintos**, así que son una muestra, no el universo. Están generados, con su etiqueta, en
`resultados/TABLA-VARIANZA.md`. **Extrapolar a varios sectores exige una hipótesis de dependencia
entre sectores que NO se ha medido.**

La media muestral de chunks auditados/slot (516,660, IC95 [500,66 ; 532,66] bajo el supuesto de
retos independientes) está **1,9 σ** por encima del valor exacto (500). La media sobre los 65 536
buckets **sí** es exactamente 500,000000: la diferencia es ruido de muestreo sobre una distribución
muy dispersa.

---

## 3 · El hallazgo central: la media es proporcional, la distribución no

El factor `NUM_S_BUCKETS/NUM_CHUNKS = 2` de `pieces_to_solution_range` (`solutions.rs:30-40`) es
exactamente `1/o` con `o = 1/2`, la **ocupación media**. Es correcto **en la media** y engañoso como
modelo de la distribución. Medido sobre los mapas de presencia reales:

* `create_proofs` produce **siempre 32 768 pruebas** y **corta** al alcanzarlas recorriendo los
  buckets en orden creciente (`chiapos.rs:225-268`). La densidad es alta en buckets bajos, cae, y es
  **exactamente cero** por encima de ≈59 738.
* La ocupación por bucket es **bimodal**: 9,0668 % de buckets vacíos y el 50 % central entre 567 y
  596 chunks. La media (500) queda por debajo de la mediana (584) por la masa de buckets vacíos.
* La varianza resultante (40 792,2309) es **163,1689×** la del modelo «ocupación constante 1/2»
  (250). La desviación típica es **12,774×**.

**Consecuencia para granjas pequeñas.** Para `S` sectores, en el modelo **declarado** de sectores
independientes, la desviación típica del total escala como `√S` en los dos modelos, así que la razón
es constante pero el valor absoluto se diluye:

| Sectores `S` | Bytes nominales | Desv. típica real | Desv. típica «modelo 1/2» | Razón | Coef. de variación | `P(0 chunks en el slot)` |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1,057 GB | 202,0 | 15,8 | 12,774 | 0,40394 | **9,0668 %** |
| 2 | 2,114 GB | 285,6 | 22,4 | 12,774 | 0,28563 | 0,8220 % |
| 4 | 4,228 GB | 403,9 | 31,6 | 12,774 | 0,20197 | 6,76·10⁻⁵ |
| 16 | 16,91 GB | 807,9 | 63,2 | 12,774 | 0,10099 | 2,09·10⁻¹⁷ |
| 1 040 (≈1,10 TB) | 1,10 TB | 6 513,4 | 509,9 | 12,774 | 0,01253 | ≈0 |

Todo `derivado` de la distribución **medida** de `s_bucket_sizes`, **bajo la hipótesis de que los
sectores son independientes — que NO se ha medido**. La única fila `medido` es `S = 1`, que es el
sector ensayado. **Consecuencia:** para una parcela de un sector, o para el primer sector de
cualquier granja, uno de cada once slots no ofrece ninguna oportunidad y la desviación típica de
oportunidades por slot es 12,8 veces la del modelo de ocupación constante.

**Y el adversario elige qué sector mirar.** El índice del bucket lo fija
`sector_id XOR global_challenge` (`sectors.rs:117-123`), así que un adversario que pueda elegir
`sector_id` (p. ej. `public_key`) puede sesgar su tasa por encima de la media pagando reploteo. Este
instrumento **no** mide ese coste; queda `pendiente`.

---

## 4 · Dos escenarios de reparto, separados

La revisión 1 mezclaba dos cosas distintas y eso falseaba la fracción del adversario. Se separan
explícitamente. Tablas generadas: `resultados/TABLA-PUENTE.md` y `resultados/TABLA-IDENTIDADES.md`
(datos crudos en `PUENTE.tsv` e `IDENTIDADES.tsv`).

### Escenario 1 — presupuestos independientes (principal)

Cada actor trae **su propio** presupuesto y se trunca **por su cuenta**:

```
sectores_i = ⌊bytes_i / sector_size(1000)⌋        piezas_i = sectores_i · 1000
denominador de candidatos y de la calibración de SR  =  Σ piezas_i  =  (Σ sectores_i) · 1000
```

Los **sobrantes de cada actor se pierden**: no se agregan ni se comparten. Es el escenario para
comparar actores que no comparten sobrantes.

**Caso exacto de 1 TiB con el adversario pidiendo el 1 %** (test en `test/runtests.jl`):

| | bytes | sectores | sobrantes |
|---|---:|---:|---:|
| adversario | 10 995 116 277 | **10** | 426 155 637 |
| honestos | 1 088 516 511 499 | **1029** | 970 461 643 |
| **total** | 1 099 511 627 776 | **1039** | — |

La cuota esperada del adversario es **10/1039 = 0,0096246…**, **no** `10/1040`. El `SR` experimental
se calibra sobre `Σ piezas = 1 039 000` → **5 918 108 461 247**, distinto del que saldría de 1 040 000.

### Escenario 2 — sectores ya ploteados y luego repartidos

Aquí los sectores **existen** y se reparten: el total se trunca **una sola vez**
(`S = ⌊bytes_totales/s⌋ = 1040`) y luego `⌊S·q_i⌋`. El resto no asignado (`S − Σ⌊S·q_i⌋ = 1` en el
caso de 1 TiB al 1 %) **no se regala a nadie**.

> **Advertencia que acompaña a este escenario.** En este reparto, el porcentaje de bytes
> **solicitado** por un actor **no** es su presupuesto físico independiente: su cuota es una fracción
> de los sectores que **ya existen**, y el truncamiento lo paga el conjunto, no cada actor. Este
> escenario se etiqueta `condicionado` y no se usa para comparar presupuestos.

### La propiedad `Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋` y el efecto de las identidades

Truncar por separado **nunca** da más sectores que truncar el total; la diferencia es espacio
nominal que no llega a ser parcela. El reparto entre `N` identidades **conserva todos los bytes**
(`reparto_igual_exacto` reparte también `T mod N`, de modo que `Σ bytes_i = T` **exactamente**), y el
escenario agregado se calcula **directamente desde `T`**, nunca desde `N·⌊T/N⌋`. Tabla generada:
`resultados/TABLA-IDENTIDADES.md`.

**Hipótesis declarada, no exigencia del formato.** Las columnas «hip. 1000» suponen
`piezas_por_sector = 1000`, que es el **máximo** `MAX_PIECES_IN_SECTOR`. `SectorMetadata` lleva un
campo `pieces_in_sector` (`u16`) por sector, así que un sector puede tener **menos** piezas. Todo el
instrumento usa 1000 como hipótesis de escenario y así se etiqueta en el código, en las tablas y aquí.

| `N` identidades | Bytes por identidad | `Σ bytes_i = T` | Sectores esc. 1 (hip. 1000) | Sectores esc. 2 (desde `T`) | Perdidos | `perdidos ≤ N` | Sin sector (hip. 1000) | `piezas_max_que_caben` | ¿Cabe algún sector? |
|---:|---:|:---:|---:|---:|---:|:---:|---:|---:|:---:|
| 1 | 1 099 511 627 776 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 3 | 366 503 875 926 | sí | 1038 | 1040 | 2 | sí | 0 | 1000 | sí |
| 7 | 157 073 089 683 | sí | 1036 | 1040 | 4 | sí | 0 | 1000 | sí |
| 10 | 109 951 162 778 | sí | 1040 | 1040 | **0** | sí | 0 | 1000 | sí |
| 100 | 10 995 116 278 | sí | 1000 | 1040 | 40 | sí | 0 | 1000 | sí |
| 1040 | 1 057 222 720 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 1041 | 1 056 207 136 | sí | 0 | 1040 | 1040 | sí | 1041 | **999** | **sí** |
| 2000 | 549 755 814 | sí | 0 | 1040 | 1040 | sí | 2000 | **520** | **sí** |

**La pérdida no es monótona en `N`.** Con `N = 7` se pierden 4 sectores y con `N = 10`, **0**. Lo
único afirmable es la desigualdad `Σ⌊bytes_i/s⌋ ≤ ⌊T/s⌋` y la cota `perdidos ≤ N`, porque cada
truncamiento pierde menos de un sector. Cualquier frase del tipo «la pérdida crece con `N`» está
retirada.

**La conclusión general «1041 identidades ⇒ cero espacio efectivo» está RETIRADA.** Es un enunciado
**condicionado a la hipótesis de 1000 piezas fijas**, no una propiedad del formato. El contraejemplo:
con `N = 1041` el presupuesto de cada identidad es 1 056 207 136 B, que **no** admite un sector de
1000 piezas (`sector_size(1000) = 1 056 896 064`) pero **sí** uno de **999**
(`sector_size(999) = 1 055 839 168 B`), incluso sumando los **131 116 B** de metadata externa:
`1 055 970 284 ≤ 1 056 207 136`. Lo mismo con `N = 2000`: cabe un sector de 520 piezas. Un actor que
pueda elegir `pieces_in_sector` **no** se queda sin sector por repartir su presupuesto.
### `α_bytes` no es una fracción de bytes físicos

**El primer renglón no es el tercero.** En el escenario 1 el adversario pide 10 995 116 277 B: eso
son **10** sectores completos (10 000 piezas) y **426 155 637 B sobrantes** que no son piezas. Por
eso su fracción de bytes solicitados (`0,009999999999`, truncada a bytes enteros) **no** es su
fracción de piezas efectivas (`10/1039 = 0,0096246`). La primera es una declaración; la segunda es la
que entra en el protocolo.

**`f_candidatos_esperados = f_piezas_efectivas` es una IDENTIDAD del modelo, no una validación
experimental.** Con el **mismo** `SR` de red, `p(SR)` y `o` se cancelan entre los dos flujos:

```
f_candidatos = (N_adv · o · p) / (N_adv · o · p + N_hon · o · p) = N_adv / Σ N_i
```

Se publica como comprobación aritmética y así se etiqueta. **No** demuestra que el experimento
acreditara almacenamiento físico, ni que la igualdad se sostenga por slot (§3), ni que se cumpla si
los dos flujos usan `SR` distintos (entonces **no** se cancela nada).

### Bytes físicos: tamaño de plot frente a metadata fija externa

`sector_size(1000) = 1 056 896 064 B` es lo que ocupa el **fichero de la parcela**. La metadata de
sector (`SectorMetadataChecksummed::encoded_size() = 131 116 B`: `sector_index`, `pieces_in_sector`,
`s_bucket_sizes` y `history_size`, más su checksum) se guarda **aparte** y **no** está dentro del
plot. Al hablar de bytes físicos por sector hay que decir cuál de las dos se está contando; sumarlas
solo tiene sentido si se declara que se cuenta el plot **más** su metadata externa.

### Trabajo azul y cuota normalizada

`blue_work` suma **solo azules** (`SPEC.md` C-GD-08). Las tasas esperadas de trabajo azul son

```
R_i = (N_i · o · p(SR)) · π_validez,i · π_admision,i · β_i · w(SR)
```

con `π_validez`, `π_admision` y `β` **explícitos y separados**. La cuota del adversario es la
magnitud normalizada correcta:

```
cuota_azul = R_adv / (R_adv + R_hon)
```

**Si el denominador es cero la cuota NO está definida** y el instrumento devuelve `nothing`, no `0`
ni `1` ni `NaN` disfrazado. El denominador se anula si ninguno de los dos flujos produce trabajo
azul (p. ej. `β = 0` en ambos, o ningún candidato): entonces no hay trabajo azul que repartir y la
pregunta por la cuota no aplica.

**La afirmación de la revisión 1 —«`α_blue_work ≤ α_bytes`»— era FALSA y se retira.** Bajo el
supuesto declarado `π_validez = π_admision = 1`:

```
cuota = (f · β_a) / (f · β_a + (1−f) · β_h)
```

y con `f = 0,3`, `β_a = 1`, `β_h = 1/2` sale **6/13 = 0,461538…**, **mayor** que `f = 0,3`. Hay un
test adversarial en `test/runtests.jl` que lo fija. `β` no es una «fracción de bytes» y no está
acotada por ella.

---

## 5 · Candidatos y verificación

Medido sobre la misma parcela, 512 retos por `SR`. Tabla generada en
`resultados/TABLA-CANDIDATOS.md` (completa, sin transcripción manual).

| `SR` | `p(SR)` | Candidatos/slot medido | Esperado `P·p` | Ratio | Varianza/media | Slots con 0 |
|---|---:|---:|---:|---:|---:|---:|
| 0, 1, 3, 4 096, 1 048 576, 4 294 967 296 | ≤ 2,3·10⁻¹⁰ | 0,000000 | ≈0 | — | — | 512/512 |
| **6 148 914 691 236 495** (calibrado de red de 1000) | 3,33333·10⁻⁴ | **0,154297** | 0,172220 | **0,8959** | 1,0249 | 440/512 |
| 144 115 188 075 855 870 | 7,8125·10⁻³ | **4,033203** | 4,036407 | **0,9992** | 1,5548 | 62/512 |
| 2 305 843 009 213 693 950 | 0,125 | **64,826172** | 64,582520 | **1,0038** | 9,2305 | 45/512 |
| 9 223 372 036 854 775 806 | 0,5 | **258,267578** | 258,330078 | **0,9998** | 33,6616 | 42/512 |
| `u64::MAX−1` y `u64::MAX` | 1,0 | **516,660156** | 516,660156 | **1,0000** | 66,0167 | 38/512 |

**Lo que sí se sostiene:** `E[candidatos/slot] = P · A(SR)/2^64` con `P` = chunks realmente
auditados. Los ratios van de 0,8959 a 1,0038; el único por debajo de 0,99 es el del `SR` calibrado,
donde se observaron **79** candidatos frente a **88,2** esperados con 512 retos, que es **−1,0 σ**
bajo Poisson: **no es una refutación**.

**Lo que no:** la varianza. `var/media` va de 1,02 a **66,0167** cuando `p ≈ 1`. La sobredispersión
**no** la introduce el predicado —`audit_chunk` es un `blake3` con clave y las distancias son
uniformes— sino el **número de chunks auditados** (§3).

**Cota con cero observado.** Cuando no se observa ningún candidato en los 512 retos, la cota
superior exacta **unilateral** al 95 % es `1 − 0,05^{1/512} = 5,83·10⁻³` (la **bilateral** sería
`1 − 0,025^{1/512} = 7,18·10⁻³`). Es una cota de **`P(≥1 candidato por slot)`**, la cola **de
arriba**; de ella se sigue, **por slot**, `P(0 candidatos en un slot) ≥ 0,99417`. **No** es la
probabilidad conjunta de 0 candidatos en los 512 slots, que valdría `≥ 1 − 0,95 = 0,05`. La
revisión 1 la etiquetaba al revés y sin distinguir unilateral de bilateral.

### Verificación: alcance exacto

`resultados/prueba-meta.tsv`: `candidatos = 1`, `pruebas_pos_validas = 1`,
`pruebas_pos_corruptas_aceptadas = 0`. El oráculo verifica la **prueba PoS** del candidato con
`is_proof_valid` y rechaza una copia con **un byte invertido**.

> **Lo que esto NO es.** `is_proof_valid` **no** equivale a `verify_solution`: no comprueba el
> compromiso de registro, ni el testigo KZG, ni la firma, ni la cabecera, ni el PoT, ni la admisión
> DAG. Por eso la columna se llama `pruebas_pos_validas` (antes `pruebas_completas_validas`, rótulo
> engañoso que se corrigió) y por eso **no se publica «pruebas verificadas/slot» como cifra**: queda
> **`pendiente`**.
>
> **Bloqueo reproducible de esa etapa.** Verificar una solución exige `verify_solution`
> (`subspace-verification/src/lib.rs`), que necesita el compromiso de registro y el testigo KZG de
> una pieza **de historia archivada real**; el clon no trae historia y generarla está fuera del
> presupuesto (P-INTENTO midió ~90 s por sector de 1000 piezas solo para plotear, más
> `ErasureCoding`/`Kzg::create_witness` de 19 ms por candidato). Además `zx-node` no ejecuta la ruta
> PoST + DAG, así que no hay contexto contra el que verificar. Entrada mínima para intentarlo:
> `candidatos = 1` con `bucket = 26859` en `resultados/prueba.tsv`. Se deja **pendiente**, no
> simulada.

---

## 6 · `blue_work/slot`: solo la fórmula condicional

**No existe hoy un camino validado que sustente una cifra de `blue_work/slot`.**

```
trabajo azul/slot = chunks_auditados/slot · p(SR) · π_validez · π_admision · β · w(SR)
                    └───── medido ─────┘  └derivado┘  └── PENDIENTE ──┘  └derivado┘
```

Los tres factores que faltan están en `resultados/CIFRAS.tsv` como filas **separadas** con valor
`nothing` y estado `pendiente`:

| Factor | Qué es | Por qué falta |
|---|---|---|
| `π_validez` | probabilidad de pasar la **verificación PoAS completa** | ninguna ruta de ZEROX ejecuta `verify_solution` |
| `π_admision` | probabilidad de pasar la **admisión PoST + DAG** | no implementada; `AlmacGhostdag::admitir` es puerta parcial de rango |
| `β` | fracción **azul** de los admitidos | `blue_work` suma solo azules; la única caracterización disponible es **H-BETA** (`P-PUERTA …/MODELO.md` §1.2), una **hipótesis declarada**, no un teorema de GHOSTDAG |

**Ninguno se absorbe en otro.** Poner los tres a `1` da el **límite favorable al adversario**:
`9,2234·10²¹ unidades de peso/slot` para el conjunto de 1000 piezas con el `SR` calibrado. Se publica
etiquetado `condicionado` y **no** debe citarse como la tasa de peso de ZEROX ni de ninguna red.

**Lo que sí está demostrado sobre la tasa de peso:** `R_i ∝ β_i · W_i`; el `SR` y la tasa de bloques
**se cancelan**, y lo único que separa el trabajo azul de la fracción de espacio es `β` (más los
`π`). Ver `P-ZRX/P-PUERTA/…/MODELO.md` §1.2, que este instrumento **reproduce y no modifica**.

---

## 7 · Uno frente a dos flujos, con los mismos bytes nominales

`resultados/FLUJOS.tsv`. Los tres escenarios del encargo con los **mismos bytes nominales**:

| Escenario | Chunks auditados/slot | Razón |
|---|---:|---:|
| 1 · Un flujo (toda la parcela, un reto) | 500,00 | — |
| 2 · Dos retos divergentes sobre la **misma** parcela | 1 051,94 | **2,0000000000** (identidad) |
| 3 · Reparto exclusivo (dos mitades disjuntas), **promedio de las dos asignaciones** | 525,97 | referencia |

**El factor 2 es una identidad algebraica, no una medición — pero con un caso degenerado.** Con
`s = s_a + s_b`:

```
asignación 1 = s_a[b_i] + s_b[b_j]        asignación 2 = s_a[b_j] + s_b[b_i]
promedio = (asignación 1 + asignación 2)/2 = (s[b_i] + s[b_j])/2 = compartido/2   para TODO par
```

La identidad **`promedio = compartido/2` vale para todo par**, incluido el degenerado. El **cociente**
`compartido/promedio` vale 2 cuando `compartido > 0` y está **INDEFINIDO** (`0/0`) cuando los dos
buckets están vacíos: en los 64 retos publicados hay 5 con `leidos = 0`, de modo que **10 de los
2016 pares** son degenerados (`reparto_exclusivo_pares_degenerados = 10`). El cociente de **medias**
`mean(compartido)/mean(promedio) = 1051,9375/525,9688 = 2,0000000000` sí es exacto. Se publican las
tres columnas —`promedio_igual_mitad`, `razon_medias`, `pares_degenerados`— más la de una sola
asignación (`2,002843`, `sesgo de diseno`).

**La revisión independiente refutó la parte universal de esta afirmación** («=2 para todo par»); la
identidad correcta es la que se enuncia arriba. El valor **2,0028** de la revisión 1 era el cociente
de **una sola** asignación asimétrica (`525,22` en vez de `525,97`): un artefacto de diseño.

**Diseño estadístico, corregido.** Los 2 016 pares se construyen con **64 retos únicos** y cada reto
aparece en 63 pares: **no son observaciones independientes**. La unidad independiente es el **reto**.
Por eso:

* se **retira** el veredicto «−2,5 σ» de la revisión 1 y cualquier intervalo que supusiera pares
  independientes;
* la incertidumbre se calcula con un **bootstrap de bloques sobre los 64 retos**
  (`ET.bootstrap_unidades`).

| Magnitud | Medido | IC95 bootstrap (sobre retos) | Referencia de independencia |
|---|---:|---|---:|
| Piezas auditadas por ambos retos | 275,81 | [232,50 ; 322,01] | 276,49 (hipergeométrico `|A₁||A₂|/M`) |
| `Pr(≥1 ganador)` con `SR` calibrado | 0,26339 | [0,1238 ; 0,3953] | 0,29330 |
| `Pr(≥1 ganador)` con `p = 1/2` | 0,99504 | [0,9843 ; 1,0000] | 0,99504 |
| Doble ganador sobre el mismo chunk (`p=1/2`) | 67,935 | — | 68,952 (`solapamiento·p²`) |

**Las referencias caen dentro de los intervalos.** El contraste ya **no** sostiene un veredicto de
discrepancia. Lo único que se puede afirmar es que, con 64 retos, no se detecta desviación de la
independencia; y que la **correlación poblacional es exactamente 0 por intercambiabilidad** de los
retos (dos retos son dos extracciones uniformes independientes), de modo que los `−0,011`
observados son ruido de muestra, no una dependencia medida.

**Lo que esto NO resuelve y NO debe presentarse como pérdida de seguridad de ZEROX.** Que el mismo
espacio pueda responder a dos retos **mide la oportunidad**, no la legalidad ni la magnitud de una
caída de umbral. Si el doble farmeo es posible depende de `C-FLU-13`, `C-FLU-14` y el controlador de
rango, que **no** están implementados, y de `π_validez`, `π_admision` y `β`, que **no** se miden.

---

## 8 · Lo que este experimento confirma y lo que refuta

**Confirma (válido tras la corrección):**

* `A(SR) = 2⌊SR/2⌋+1` y el predicado `d ≤ ⌊SR/2⌋`, con el **orden de bytes** little-endian,
  contra valores reales del código fijado (byte order, bucket, `rank/select` en los 65 536 buckets).
* `E_b[ocupación por bucket] = 1/2` **exacto**, y por tanto `E[chunks auditados/slot] = piezas/2`.
* `E[candidatos/slot] = P·A(SR)/2^64` en todo el rango medido (`p` de 5,4·10⁻²⁰ a 1).
* La cancelación del `SR` en la tasa de peso, con sus dos residuos exactos.
* La ocupación desigual del sector ensayado y la media derivada de 500 chunks por bucket.
* Los conteos de candidatos bajo los retos y `SR` experimentales.
* `sector_size(1000) = 1 056 896 064 B`, con `RecordMetadata = 128 B` y 131 116 B de metadata
  **fuera** del fichero de sector.

**Refuta o acota:**

* **`α_blue_work ≤ α_bytes` es FALSO.** Se retira de informe, contrato, hipótesis y tests. Con
  `f = 0,3`, `β_a = 1`, `β_h = 1/2` la cuota condicional es **6/13 = 0,461538 > 0,3**.
* **`α_bytes`, `α_candidatos` y el trabajo azul no son la misma magnitud.** Coinciden solo donde el
  modelo lo impone (`f_candidatos` con el mismo `SR`, que es una identidad), no por slot, y no en
  general.
* **No es cierto que una fracción de bytes dé la misma fracción de oportunidades por slot**: eso es
  una identidad de medias. La desviación típica es **12,774×** la del modelo de ocupación constante
  y `P(0 oportunidades)` es **9,0668 %** para una parcela de un sector (**bajo la hipótesis de
  independencia entre sectores, no medida**).
* **No es cierto que la ocupación sea aproximadamente constante por bucket** (varianza 163,1689× la
  binomial, 9,07 % de buckets vacíos, cero exacto por encima de ≈59 738).
* **`f_bytes_solicitados ≠ f_piezas_efectivas`** cuando hay sobrantes que no completan sector.
* **El factor 2 de compartir/repartir no es una medición** ni una pérdida de seguridad: es una
  identidad algebraica.
* **Los 2 016 pares no son independientes**: cualquier σ que lo supusiera está retirada.
* **`Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋`** se cumple siempre (test aleatorio, 200 casos), con
  `Σbytes_i = T` **exacto** y el agregado calculado **desde `T`**. La pérdida **no es monótona** en el
  número de identidades (`N=7` pierde 4 sectores, `N=10` pierde 0); la cota afirmable es
  `perdidos ≤ N`, porque cada truncamiento pierde menos de un sector.
* **«Muchas identidades ⇒ cero espacio efectivo» NO es una propiedad del formato.** Solo vale
  **condicionado** a la hipótesis `piezas_por_sector = 1000`; con 999 piezas el presupuesto de cada una
  de las 1041 identidades sí admite un sector (§4).
* **La cuota del adversario depende del escenario**: con 1 TiB al 1 % es `10/1039` si cada actor
  trunca por su cuenta y `10/1040` si se reparte el plot ya hecho. **No** se publica una sin decir
  cuál.
* **El tamaño de plot no es el tamaño físico total**: `sector_size()` excluye 131 116 B por sector de
  metadata fija externa.

**No refuta ni confirma (porque no se midió):** un umbral de seguridad físico, una tasa real de la
red ZEROX, la dificultad del doble farmeo, la preexistencia de los bytes, ni el coste de un
adversario que regenera piezas tras conocer el reto. **CPU equivalente no son bytes almacenados.**

---

## 9 · Respuesta explícita: ¿podemos ya cuantificar la caída del umbral de seguridad de ZEROX por doble farmeo?

**No.**

Faltan, como mínimo, cinco cosas y ninguna está medida aquí:

1. **Verificación completa** (`π_validez`): `verify_solution` — compromiso, testigo KZG, firma,
   cabecera — no se ejecuta en ninguna ruta de ZEROX y **no** se pasó ninguna solución por ella.
2. **Admisión PoST + DAG** (`π_admision`): no implementada. `AlmacGhostdag::admitir` es una puerta
   **parcial** de rango y `zx-node` sigue con cabecera lineal.
3. **Comportamiento del DAG y tasas azules** (`β`): `blue_work` suma solo azules, y `β` depende de
   GHOSTDAG y del retarget. Sin `β` no hay tasa de trabajo azul, y sin ella no hay umbral.
4. **El controlador de rango y las reglas de flujo** (`C-HDR-06`, `C-FLU-13`, `C-FLU-14`): sin
   ellas no se sabe si dos retos sobre la misma parcela son siquiera **admisibles**; el instrumento
   mide la **oportunidad**, no la legalidad.
5. **Una magnitud de comparación válida**: lo que este instrumento aporta es `R_i ∝ β_i·W_i` y la
   fórmula de la cuota `R_adv/(R_adv+R_hon)`. La cuota depende de factores `pendiente`, así que el
   instrumento **no** produce un número de umbral ni una caída de umbral.

Lo que sí permite decir: la cuota azul del adversario **no está acotada por su fracción de bytes**
(6/13 > 0,3 en el ejemplo adversarial), y el puente bytes → candidatos **sí** está medido, con sus
medias exactas y su dispersión. Eso **acota** el problema; no lo cuantifica.

---

## 10 · Verificación, rendimiento y límites

### Pruebas

`resultados/TESTS.txt`: **41 816 comprobaciones, 0 fallos**, en los dos perfiles
(`--check-bounds=yes` con 1 hilo, y sin límites con 4 hilos). Cubre las exigencias del encargo §4 y
además, tras la corrección:

| Exigencia | Dónde |
|---|---|
| Distancia circular, punto opuesto, bordes de `SR`, paridad | «referencia exacta», «distancia circular» |
| Cardinalidad **exhaustiva** en círculo pequeño vs fórmula | `eq_cardinalidad_exhaustiva`, 75 módulos |
| Orden de bytes y derivación del bucket frente a Rust | `eq_rust_byte_order`, `eq_rust_bucket`, `eq_buckets_propios` |
| Bucket vacío, ocupación desigual, **≤1 chunk por pieza y bucket** | `invariantes_bitmaps` |
| Cero, uno y varios candidatos por sector | sobre `audita-retos.tsv` |
| Candidato ganador cuya **prueba PoS** falla | `eq_prueba_pos`, byte invertido rechazado |
| Reproducción idéntica con la misma parcela y reto | `eq_determinismo` |
| Dos retos divergentes sobre la misma parcela | invariantes sobre los pares + **bootstrap por retos** |
| Referencia lenta vs kernel y **conservación de contadores** | `eq_conservacion_contadores`, `eq_conservacion_paralelo` (7 nº de bloques) |
| **Cuota azul adversarial 6/13 > 0,3 y denominador cero** | «cuota azul: la afirmación … es FALSA» |
| **Sobrantes que no completan sector** | «reparto de bytes: sobrantes…» |
| **Identidad exacta compartir/repartir = 2** | «identidad exacta compartir/repartir» |
| **Contabilidad de bytes contra la API del clon** | contra `resultados/constantes.tsv` |

### Rendimiento

`resultados/BENCH.txt`, `ESCALADO.txt`. Kernel con histograma: **22,81×** sobre el oráculo lento,
**0 asignaciones**. Escalado 1→24: 1,010 / 1,881 / 3,306 / 4,905 / 6,476 / **6,720**, eficiencia
hasta 0,28. **Decisión medida:** se conserva el kernel **serial**, porque la etapa cuesta 5 ms frente
a los 75 200 ms de generar el conjunto de piezas.

### Ausencia de integración, documentada

`zx-node` sigue lineal; `C-HDR-06`, el controlador de rango, el retarget causal y la red no están
implementados; `verificar_justificacion_pot` sigue devolviendo `IntegracionPotPendiente`; la semilla
y `N(s)` del PoT no viajan en el wire, así que el **reto real de un slot no está disponible** y el
instrumento usa retos reproducibles derivados con `blake3`, declarados como escenario experimental.

---

## 11 · Reproducción

```bash
cd P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1
export JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia"
J=/home/katana/zeo/ZEROX/veritas/julia.sh

# Oráculo Rust (comandos completos en METODO.md §1)
(cd oraculo-rust && CARGO_TARGET_DIR="$PWD/target" CARGO_NET_OFFLINE=true cargo build --release)
./oraculo-rust/target/release/puente constantes --out resultados   # contabilidad de bytes desde la API
./oraculo-rust/target/release/puente vectores   --out resultados
./oraculo-rust/target/release/puente prueba     --out resultados
./oraculo-rust/target/release/puente bits       --piezas 1000 --retos 512 --hilos 16 --out resultados
./oraculo-rust/target/release/puente audita     --piezas 1000 --retos 512 --hilos 16 --out resultados \
  --sr "…" --sr-pares "…"

# Análisis y validación
JULIA_NUM_THREADS=1 $J --check-bounds=yes --project=. test/runtests.jl   # 41 816 / 0 fallos
JULIA_NUM_THREADS=1 $J --project=. run.jl --piezas 1000 --retos 512   # TABLA-PUENTE, TABLA-IDENTIDADES, ...
```

**Integridad (corregida).** `resultados/GIT-ENTRADA.txt` y `GIT-SALIDA.txt` **no son idénticos**:
entre el inicio y el final aparecieron `?? P-ZRX/P-RIVAL/` y `?? P-ZRX/P-SELLO/`. Son directorios
**ajenos**, aparecidos por trabajo en paralelo; **no se atribuyen a nadie sin evidencia** y no se han
tocado. Lo que **sí** es invariante y se comprueba automáticamente: **ningún fichero versionado
cambió** (las 20 entradas `M`/`D`/`R`/`A` son idénticas) y el clon de Autonomys quedó **limpio**.
`bash verificar-huellas.sh` termina con **código de salida 0** (`METODO.md` §5). No se creó ni
ejecutó ninguna auditoría Python.

**Zona de escritura (desviación documentada).** El encargo pedía `veritas/seguridad/espacio-tasa-v1/`
relativo a la raíz de ZEROX, pero esa raíz está montada **de solo lectura** en esta sesión; el único
punto escribible es este directorio. **El instrumento no se mueve en esta corrección**: sus
dependencias Rust usan rutas relativas (`../../../../../../../fuentes/subspace/...`) y
`.julia-depot` es un depósito local. Para trasladarlo habría que: (1) reescribir las rutas de
`oraculo-rust/Cargo.toml` y regenerar `Cargo.lock`; (2) mover o regenerar `.julia-depot` y
`Manifest.toml`; (3) actualizar las rutas citadas en `METODO.md` §1 y en este §11.
