# INFORME — P-IDENTIDAD · ¿Qué se rompe si la identidad de billete deja de llevar `chunk`?

**La identidad se puede cambiar, pero el cambio vale mucho menos de lo que supone `P-ZRX/P-PRESTAMO/`, y
no es gratis.** Dentro de una misma historia las tres identidades **particionan igual**, así que U2, U3″
dinámica, P1, el conjunto consumido, el pago y el retarget **no cambian** y **no se pierde ningún bloque
honesto**. Lo único que cambia es cómo se tratan las copias de un mismo recurso en **ramas disjuntas con
flujos divergentes**: B y C las agrupan **solo cuando gana la misma pieza**, que con `pieces_in_sector`
grande es una fracción pequeña (≈1/`P` en la rejilla medida, `[0,001…0,06]` con IC), y a cambio (i) rompen
el «Invariante de no-equivocación del inyector» de `C-FLU-12` y (ii) crean un vector de invalidación en
cascada que `C-GD-10` no descarta hoy. **C exige un registro de parcelas que no existe**; **B se puede
adoptar sin él** porque `piece_offset` ya viaja en la cabecera. La razón de fondo: con el código fijado de
Autonomys, **`chunk` no es un grado de libertad independiente** — un reto fija un solo *s-bucket* por
sector y cada pieza aporta a lo sumo un chunk en ese bucket; la afirmación «dos soluciones de la misma
pieza con `chunk` distinto en el mismo slot» es **estructuralmente imposible dentro de una historia** y
solo aparece entre ramas con retos distintos.

---

## 0 · Respuestas cortas

| # | Pregunta | Respuesta | Etiqueta |
|---|---|---|---|
| **F1** | ¿A es más fina que B? ¿Existe «misma pieza, `chunk` distinto, mismo slot»? | **A refina a B** (A-igual ⇒ B-igual), salvo colisión de valor de `chunk` (~2⁻²⁴⁸ con escalares de 32 B). El caso «misma pieza, `chunk` distinto» **existe** — medido: fixture `flujo-divergente-misma-pieza` — pero **exige retos distintos**, es decir flujos divergentes; **no lo produce un granjero honesto con una sola vista** (E3 + E6 + E7). | `verificado en fuente` + `demostrado` + `enumerado` |
| **F2** | ¿Siguen sin colisionar dos bloques honestos? ¿Cuántos se pierden? | **Dentro de una historia no colisiona ninguno**: red honesta de un solo flujo ⇒ `U2 = herencia = rojo_U3 = 0` y resultado **idéntico** en A, B y C (48 400 bloques medidos). La pérdida aparece **solo** si un productor con **dos nodos de vistas divergentes** emite la misma pieza bajo otro flujo: con `equivoca = 0,05` son **9,8 %** de los bloques del DAG (inválidos + herederos) frente a **0,00 %** con A; con `equivoca = 1,0`, **64,8 %** frente a **0,40 %**. No es función de λ, `k` ni Δ (medidos: idéntico para λ∈{1,2}, Δ∈{1,4}, k∈{10,30}); es función de la tasa de equivocación y de `P(intersección)`. | `enumerado` + `medido` |
| **F3** | ¿Se pagan menos bloques? ¿Cambia la emisión o R-FIN-13′? | **Dentro de una historia: no.** El conjunto pagable de P1 es **idéntico** en A, B y C en los 27 casos fixture×modo. Fuera de una historia, B/C **reducen** el pagable exactamente en el caso de F2 (una copia `rojo_U3` en vez de dos azules): es una **ganancia de seguridad**, no un coste. La emisión efectiva no cambia por otra vía. | `enumerado` |
| **F4** | ¿B/C cierran el doble farmeo «por construcción»? | **La afirmación literal es falsa tal como está escrita.** Lo que B/C cierran es (i) que el par sea **evidencia objetiva** *cuando comparten pieza* y (ii) que al **fusionar** una copia sea inerte. Lo que **no** cierran es que la copia **sume mientras las ramas están separadas** (medido: mismo `blue_work` en A y en B, ambas azules en su rama). Y la evidencia solo aparece si el atacante **no puede elegir** piezas distintas: medido, `P(única ganadora y la misma) = 1,00 / 0,10 / 0,013 / 0,000 / 0,006` para `P = 1/4/16/32/1000`. Con `P = 1000` (mainnet, `MAX_PIECES_IN_SECTOR`), B detecta del orden del **0,6 %** de las equivocaciones con retos divergentes, y **0 %** de las que comparten reto (donde A ya da la misma evidencia). | `demostrado` + `enumerado` |
| **F5** | ¿Qué NO cierra? | Confirmado: publicar solo la rama ganadora, la carrera del ancla (`P-EQUIVOCACION` P4/P5), el alquiler exclusivo (`β_x`). **Añadido**: tampoco cierra el *grinding* de pruebas alternativas para el mismo `(pieza, bucket, chunk)` (`IDENTIDAD.md` §4), que bajo las tres identidades es **el mismo billete**. | `derivado` + `verificado en fuente` |
| **F6** | Coste de migración | Reescritura de **una tupla** (`C-GD-07`/R-FIN-11) más la **compresión a `u64`** en `zx-consensus::ghostdag`, que hoy **no está cableada** (`ci/consenso-pendiente.txt:31-38`). **Ningún vector caduca por el formato** (la identidad no entra en `block_hash`), pero sí por **semántica**: cualquier fixture que compare colisiones de billete. **Bloques ya producidos**: la identidad es clave de deduplicación local, no campo firmado; un replay bajo B puede invalidar bloques válidos bajo A ⇒ **activación de consenso** (§14), no cambio silencioso. **B se adopta sin registro de parcelas**; **C no** (`PlotBatchId` no existe). **IDV-01 sigue «condicionada»** por el bloqueante de `CONTRATO-VALIDACION.md:34-37` — qué retos y raíces alternativos del mismo slot son la misma oportunidad — **y B no lo levanta**: precisamente por E1/E2, B **no** unifica retos distintos del mismo slot. | `derivado` + `verificado en fuente` |

---

## 1 · Método, alcance y qué se ejecutó

- **Instrumento:** `veritas/consenso/identidad-billete-v1/` (Julia 1.13.0, CPU, `JULIA_DEPOT_PATH`
  propio). **No reimplementa GHOSTDAG**: usa `GhostdagRank` (GDR-v0.2, `veritas/consenso/ghostdag-rank-v1/`)
  como oráculo (`EstadoReferencia`) y como kernel (`EstadoRapido`); encima añade la invalidez U2 con su
  propagación por validez absoluta y la contabilidad de copias pagables de §7.2 (P1/C-ORD-02).
- **Comando exacto** (desde la raíz del repositorio):

  ```bash
  cd P-ZRX/P-IDENTIDAD/investigacion/veritas/consenso/identidad-billete-v1
  JULIA_DEPOT_PATH="$PWD/../../../../.julia-depot:$HOME/.julia" \
  JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
    ../../../../../../veritas/julia.sh --project=. --threads=4,0 run.jl --seed 0x5a5a --replicas 400 todo
  ```

- **Presupuesto:** 4 hilos, ≤ 8 GiB de RAM, ≤ 1 GiB de disco. Consumo real: 8,8 s de pared, 421 MiB
  de RSS máximo (mucho menos de lo declarado). **No se agotó**; nada queda inconcluso por recursos.
- **Controles (LINEO §5.1), todos en verde:** 259 tests con `--check-bounds=yes`. Ninguno compara una
  fórmula consigo misma: el oráculo es el de GDR; la capa pagable se contrasta con una **tercera vía
  por conjuntos** (`blueset` + rojos de todos los mergesets) en 27 casos fixture×modo, 0 discrepancias.
- **Lo que este informe NO hace:** no decide el cambio, no redacta reglas para el SPEC y no fija
  parámetros. Etiquetas: `demostrado` / `verificado en fuente` / `enumerado` / `derivado` / `estimado` /
  `propuesto` / `no determinado`.

### 1.1 · Advertencias de método declaradas antes de empezar

1. El encargo dice que A es «más fina» que B porque hay «varios `chunk` por `piece_offset`». **Es cierto,
   pero solo entre retos distintos.** Lo que hace falta para que A y B **no** estén en relación de
   refinamiento es un par con el **mismo `chunk` y distinta pieza**; con escalares de 32 bytes eso exige
   una colisión de valor. Medido con el dominio de `chunk` reducido a 4 bits (control C2), el cruce
   **existe** y es el único modo de romper el refinamiento. Con 32 bytes, A **refina** a B.
2. La tabla de `P-PRESTAMO` §3.3, leída literalmente («`β_d` no aporta peso neto»), **es falsa**: entre
   ramas disjuntas cada copia es azul en la suya y su `blue_work` la cuenta. Lo que B/C aportan es
   **evidencia**, y solo bajo condición. F4 lo cuantifica.
3. **El cambio sí toca `C-FLU-12`**: no su texto (que usa `sol.chunk` directamente) sino su
   *invariante* de no-equivocación. Medido: en `flujo-divergente-misma-pieza` bajo B y C, la misma
   identidad tiene **dos entropías distintas**; bajo A, no.

---

## 2 · Los hechos de fuente que deciden (abiertos, no citados de terceros)

Checkout `PDF/autonomys-subspace` @ `f8842d0`. Todo lo de este apartado es `verificado en fuente` por
lectura directa; las líneas que más pesan se copian.

**E1 · El reto depende de `(flujo, slot)`.** ZEROX: `aleatoriedad(f,s) = blake3(salida(f,s))`,
`reto(f,s) = blake3(aleatoriedad(f,s) ‖ LE64(s))` (`SPEC.md` §7.1.1, `C-POT-03`). Autonomys:
`global_challenge = Blake3(Blake3(pot_output) || slot.to_le_bytes())`.

**E2 · Un solo *s-bucket* por (pk, sector, historia, slot, flujo).**
`crates/subspace-core-primitives/src/sectors.rs:33-39`:

```rust
pub fn s_bucket_audit_index(&self) -> SBucket {
    const_assert_eq!(Record::NUM_S_BUCKETS, 1 << u16::BITS as usize);
    SBucket::from(u16::from_le_bytes([self.0[0], self.0[1]]))
}
```

`self` es `sector_slot_challenge = sector_id XOR global_challenge` (`sectors.rs:117-126`), y
`sector_id = Blake3_keyed(hash(pk), sector_index ‖ history_size)` (`sectors.rs:56-67`). **El bucket no
depende de la pieza.**

**E3 · Un chunk por (pieza, bucket).** `crates/subspace-farmer-components/src/sector.rs:582-608`:

```rust
fn record_has_s_bucket_chunk(s_bucket: usize, record_bitfields: &SingleRecordBitArray,
                             num_encoded_record_chunks: usize) -> Option<bool> {
    if record_bitfields[s_bucket] { Some(true) }
    else if num_encoded_record_chunks == Record::NUM_CHUNKS { None }
    else { /* … Some(false) si toca rellenar hueco, None si no */ }
}
```

Un **bit** por (pieza, bucket) ⇒ a lo sumo una entrada. `iter_s_bucket_records` (`sector.rs:521-552`)
recorre `(PieceOffset::ZERO..).zip(...)` aplicando esa función. El bucket entero se escanea en
`auditing.rs:236-271` y cada candidato se mapea a su `(piece_offset, encoded_chunk_used)` en
`proving.rs:397-410`; **cada chunk ganador produce una `Solution`** (`proving.rs:243-248`, `:317-328`).

**E4 · El chunk son 32 bytes.** `Record([[u8; ScalarBytes::FULL_BYTES]; NUM_CHUNKS])` con
`FULL_BYTES = 32` (`pieces.rs:462`; `lib.rs:255-258`); `chunk: ScalarBytes` en `Solution`
(`solutions.rs:250-275`). `NUM_CHUNKS = 32768`, `NUM_S_BUCKETS = 65536`.

**E5 · Gana por umbral sobre el chunk enmascarado.** `subspace-verification/src/lib.rs:236-259`:

```rust
let sector_slot_challenge = sector_id.derive_sector_slot_challenge(&global_challenge);
let s_bucket_audit_index = sector_slot_challenge.s_bucket_audit_index();
…
let masked_chunk = (Simd::from(*solution.chunk) ^ Simd::from(*solution.proof_of_space.hash())).to_array();
let solution_distance = calculate_solution_distance(&global_challenge, &masked_chunk, &sector_slot_challenge);
if solution_distance > solution_range / 2 { return Err(Error::OutsideSolutionRange { … }); }
```

**E6 · Un bloque por productor y slot.** `sc-consensus-subspace/src/slot_worker.rs:571-592`: si ya hay
pre-digest, registra *«Skipping solution that has quality sufficient for block because block pre-digest
was already created»* y la solución pasa a voto.

**E7 · Dentro de una historia, un solo reto por slot.** `C-FLU-14` exige que el flujo de todo
`X ∈ past(B)` coincida con `flujo(B, ·)`, y `C-FLU-05` cierra la monotonía. Dos bloques de la misma
historia con el mismo slot comparten pasado relevante ⇒ comparten flujo ⇒ comparten reto. El
enumerador lo comprueba: `incoherencias_de_flujo` devuelve ∅ en los 9 fixtures (test en verde).

**Lo que NO se puede determinar con este código** (recogido del rastreo de fuente): no existe
`chunk_index` ni `chunk_quality` como datos de consenso; no hay en `subspace-verification` ninguna noción
de «una solución por pieza» ni «por sector»; el código **no acota** la probabilidad de colisión de
escalares de 32 bytes (por eso E4 se usa como cota, no como teorema).

**Un dato más, que afecta al inventario:** la clave de deduplicación de la **propia Autonomys** incluye
**ambos** campos — `(public_key, sector_index, piece_offset, chunk, slot)`
(`crates/pallet-subspace/src/lib.rs:1591-1597`). Es decir, `C-GD-07` **ya es más gruesa** que la
referencia en la dimensión `piece_offset`, y B sería más gruesa en la dimensión `chunk`. Por E3, dentro
de un reto ambas proyecciones coinciden; el campo extra de Autonomys es redundante allí.

---

## 3 · F1 · Granularidad: qué separa exactamente A de B

**Definiciones.** A = `(pk, sector, historia, chunk, slot)` (`SPEC.md:2316`). B = `(dominio, slot, pk,
sector, historia, piece_offset)` (`IDV-01`). C = `H(dominio, slot, PlotBatchId, sector, piece_offset)`
(`SOLUCION-CANDIDATA-REUTILIZACION.md` §3).

**Resultado 1 — `demostrado`.** *A refina a B.* Supongamos `clave_a(x) = clave_a(y)`: mismo slot, pk,
sector, historia y **mismo `chunk`**. Si `x` e `y` se evaluaron bajo el mismo reto (mismo bucket por E2),
entonces E3 da `pieza(x) = pieza(y)`. Si se evaluaron bajo retos distintos, `pieza(x) = pieza(y)` exige
que dos celdas distintas de la tabla de chunks tengan el **mismo escalar de 32 bytes**: una colisión
(~N²·2⁻²⁴⁸). Por tanto A-igual ⇒ B-igual salvo colisión. **En el juguete se enumera**: control C1,
256 soluciones, pares O(n²), **0 violaciones**.

**Resultado 2 — `enumerado`.** *El cruce existe y es el único modo de que A no refine a B.* Bajando el
dominio de `chunk` a 4 bits (control C2) aparecen **3 pares A-igual y B-distinto** y **6 pares B-igual y
A-distinto**; ejemplo del segundo: `pieza = 0`, `chunk 2/8`, `flujo 0/1`, `slot 1/1`. El primero es la
colisión; el segundo es el caso discriminante.

**Resultado 3 — `demostrado` + `verificado en fuente`.** *«Misma pieza, `chunk` distinto, mismo slot»
existe **solo** entre retos distintos.* Por E2+E3, dentro de un reto la pieza determina el chunk. Con E7,
dos bloques de la misma historia con el mismo slot comparten reto. Luego el par solo puede formarse entre
**ramas con flujos divergentes** — exactamente el escenario de ancla de `P-EQUIVOCACION` P4/P5 — o con
un nodo que evalúa dos retos (dos vistas). **¿Lo produce un honesto?** No con una sola vista: por E6 un
productor honesto hace un bloque por slot, y por E3+E7 no tiene dos soluciones distintas de la misma
pieza en ese slot. **Sí** con dos nodos/harvesters de vistas divergentes (el caso C3 de
`CANDIDATA.md` §A.2), que es el único camino honesto a la equivocación.

**Resultado 4 — `enumerado`.** Multiplicidad de ganadoras: **no es un grado de libertad de la pieza
dentro de un reto**. `MC-A`, 400 réplicas: media medida de ganadoras por (sector, slot, flujo) =
0,990 / 0,995 / 0,995 para μ = 1 con P = 8/16/32, y `P(W≥2)` = 0,285 / 0,240 / 0,250 dentro del IC de la
Binomial(P,q) (0,264 / 0,264 / 0,264). Las ganadoras múltiples son **piezas distintas** ⇒ **billetes
distintos bajo A y bajo B**.

**Corolario para `P-EQUIVOCACION`/EQUIV-v0.1.** Su escenario «misma-parcela: 1 pieza × 8 `chunk`» modela
como independientes dos cosas que el código ata: con 1 pieza, «8 chunks» solo puede significar **8
retos distintos** (8 buckets). Es una abstracción legítima, pero entonces `κ_div(IDV-01) = 1,000`
presupone que **la misma pieza gana en los dos retos**. Con P piezas eso ocurre con la probabilidad de
`MC-B`, no con probabilidad 1 (Resultado 5, §6). Su `κ` de A sigue siendo correcto; el de B está
**sobreestimado** salvo en el extremo P = 1.

---

## 4 · F2 · U2 y U3″: cuántos bloques honestos se pierden

**Resultado 5 — `medido` (enumerado sobre DAGs de juguete).** *Red honesta de un solo flujo: pérdida
cero y comportamiento idéntico en A, B y C.* `MC-C`, 400 réplicas × 120 bloques por configuración,
λ ∈ {1, 2}, Δ ∈ {1, 4}, k ∈ {10, 30}: para las 12 configuraciones y las tres identidades,
`U2 = herencia = rojo_U3 = 0`, `válidos = pagables = 48 400`, `identidades = 48 000`. Ninguna λ, Δ o k
cambia nada: **no hay dependencia de λ, k ni Δ que medir**, porque el evento no es de red sino de
reutilización de una misma oportunidad.

**Resultado 6 — `medido`.** *La pérdida aparece solo con productores de vistas divergentes, y es
grande.* `MC-D` (misma red, `equivoca` = fracción de oportunidades con una segunda copia bajo otro
flujo, P = 16):

| `equivoca` | A: U2 / herencia | A: bloques no válidos | B/C: U2 / herencia | B/C: bloques no válidos |
|---:|---:|---:|---:|---:|
| 0,05 | 0 / 0 | **0,00 %** | 73 / 4 660 | **9,8 %** |
| 0,25 | 4 / 151 | **0,32 %** | 239 / 16 235 | **34,0 %** |
| 1,00 | 18 / 174 | **0,40 %** | 363 / 31 015 | **64,8 %** |

Los totales son sobre 48 400 bloques generados por 400 réplicas (el escenario `equivoca = 0,05` con
A produce 48 413 válidos porque el segundo bloque de la pareja no siempre se emite). Bajo B/C la
invalidación **no** se queda en la segunda copia: por validez absoluta (`C-FLU-13(3)`) arrastra a todo
bloque que la tenga en su pasado, y en particular a cualquier bloque que la tome como padre. Con A la
pérdida es ~1/B del efecto de B (la coincidencia de bucket, 1/16 en el juguete), porque A solo colisiona
cuando el chunk coincide.

**Resultado 7 — `derivado` + hallazgo de SPEC.** El daño de Resultado 6 no es inevitable:
`C-GD-10` enumera lo que el productor **MUST** descartar de su cola de puntas — violaciones de
`C-GD-11`, `slot` mayor, cambios de entropía/`t_j` — y **no incluye U2 ni C-GD-05**. Un productor que
respeta la letra de `C-GD-10` puede emitir un bloque que viola `C-GD-07/U2` por la sola elección de
padres, contra la frase «un productor no puede emitir un bloque inválido por una elección de padres que
él mismo controla» (`SPEC.md` §11). **Con A este agujero no tiene consecuencia; con B/C sí.** Es una
regla que habría que escribir si se adopta B.

**Conclusión F2.** El «riesgo más serio» del encargo **no se materializa en la red honesta** (0 medido,
y por E3+E6+E7 es 0 por construcción). Se materializa en el productor con dos nodos de vistas
divergentes, y allí el coste no es «pierde una recompensa» sino «pierde el bloque y su descendencia».
La asimetría se debe a que B agrupa lo que A separa, y esa agrupación, al fusionarse, **invalida**
bloques en vez de solo dejar de pagarlos.

---

## 5 · F3 · Pago y retarget

**Resultado 8 — `enumerado`.** *Dentro de una historia, el conjunto pagable de P1 es idéntico en A, B y
C.* En los 27 casos fixture×modo, `pagables`, `inertes`, colores y `blue_work` coinciden (control C3/C4;
el único cambio es `flujo-divergente-misma-pieza`, que es entre ramas). Consecuencia: **R-FIN-8′, P1,
`C-ORD-02` y R-FIN-13′ no cambian** dentro de una historia; retarget y emisión cuentan lo mismo.

**Resultado 9 — `enumerado`.** *Fuera de una historia, B/C reducen el pagable exactamente en el caso
discriminante.* En `flujo-divergente-misma-pieza` al fusionar: A paga 4 copias con `blue_work` 2¹²⁹·⁶;
B/C pagan 3 con 2¹²⁹·⁰ y marcan una `rojo_U3`. La magnitud de esa reducción **es** la de Resultado 6: no
hay una segunda vía por la que cambie la emisión.

**Resultado 10 — `derivado`.** Un `rojo_k` **sí** cambia de tratamiento entre A y B: bajo B puede
desaparecer (`U3`) justo cuando habría sido la copia no seleccionada. P1 ya lo habría dejado inerte, así
que **no hay doble pago en ningún caso**: el cambio no puede inflar el pago, solo reducirlo.

---

## 6 · F4 · El doble farmeo, por construcción

**Lo que dice `P-PRESTAMO` §3.3:** con B/C, «`β_d` no aporta peso neto porque las dos copias comparten
identidad y P1 solo paga una».

**Resultado 11 — `demostrado` + `enumerado`: la afirmación necesita una condición que no está escrita.**
- **Al fusionar**: correcto. `U3″` marca la segunda copia `rojo_U3`; no cobra, no cuenta y no aplica
  (`SPEC.md` §11 `C-GD-07`, §7.2 P1). Medido en `flujo-divergente-misma-pieza` y en
  `ramas-disjuntas-mismo-flujo`.
- **Mientras las ramas están separadas**: **falso**. Cada copia es azul en su rama y su `blue_work` la
  cuenta. Medido: en `ramas-disjuntas-mismo-flujo` A y B dan **el mismo peso** (`2¹²⁹·⁰`, `equivalentes`
  = true) y en `ramas-disjuntas-flujo-divergente`/`flujo-divergente-misma-pieza` también antes de
  fusionar. Es la misma observación que `veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6.
- **La única diferencia real es la evidencia**, y solo cuando el atacante no puede evitarla.

**Resultado 12 — `enumerado` (MC-B, 400 réplicas).** Probabilidad de que la misma pieza gane en los dos
retos del mismo slot, **condicionada** a que haya ganadora en ambos flujos (que es el caso en que el
atacante tiene dos copias que publicar). Columna «forzado»: única ganadora en cada rama **y la misma
pieza** — entonces B detecta con certeza; si hay más de una, el atacante publica piezas distintas y
escapa de B igual que de A:

| P (piezas/sector) | q | μ | P(intersección) | IC95 | cota inferior 1−(1−q²)ᴾ | **P(forzado)** | IC95 |
|---:|---:|---:|---:|---|---:|---:|---|
| 1 | 0,5 | 0,5 | 1,000 | [0,964, 1,000] | 0,250 | **1,000** | [0,964, 1,000] |
| 4 | 0,25 | 1,0 | 0,490 | [0,421, 0,559] | 0,228 | **0,101** | [0,066, 0,151] |
| 16 | 0,0625 | 1,0 | 0,171 | [0,120, 0,237] | 0,061 | **0,013** | [0,004, 0,045] |
| 32 | 0,03125 | 1,0 | 0,071 | [0,040, 0,123] | 0,031 | **0,000** | [0,000, 0,024] |
| 1000 | 0,001 | 1,0 | 0,006 | [0,001, 0,032] | 0,001 | **0,006** | [0,001, 0,032] |
| 0 (misma rama, mismo reto) | — | — | — | — | — | **0** (ya lo captura A) | — |

La cota inferior supone flujos independientes; la coincidencia de bucket (1/16 en el juguete, 1/2¹⁶ en
el código) correlaciona los ganadores y **sube** la medida, como se ve en la columna medida. Con
`P = 1000` — el valor de mainnet — MC-B mide **0,006**.

**Resultado 13 — `derivado`: dentro de una historia el cambio es vacuo.** Por E2+E3+E7, dos copias de la
misma oportunidad en una historia comparten chunk, luego son el mismo billete **bajo A y bajo B**. La
evidencia que `CANDIDATA.md` §5 quiere («mismo `TicketId` + dos `pre_hash` + dos firmas») **ya existe con
A** en todo el régimen de flujo común. El `chunk` de A **no** es un nonce libre dentro de un reto.

**Conclusión F4.** Lo que cierra el cambio es, exactamente: **(i)** la copia no suma **al fusionar**;
**(ii)** el par deja evidencia objetiva **cuando comparten pieza**, lo que exige retos divergentes y que
el atacante no tenga otra pieza ganadora. **No cierra** «no suma mientras las ramas están separadas», y
**no** elimina la dependencia del castigo: la convierte en dependencia de que el par comparta pieza, que
con `P` grande es raro. La conclusión de `P-PRESTAMO` **necesita esa condición escrita** y su tabla
necesita la columna «P(forzado)».

---

## 7 · F5 · Lo que el cambio NO cierra

- **Publicar solo la rama ganadora** — `derivado`, confirmado. Sin el par publicado no hay evidencia; el
  cambio no lo toca (idéntico en A, B y C).
- **La carrera del ancla** (`P-EQUIVOCACION` P4/P5) — `derivado`, confirmado **y agravado en su papel**:
  es la **condición de posibilidad** del único caso que B/C sí cierran (Resultado 12). Quien ataque sin
  ganar la carrera del ancla ya está en el régimen de flujo común, donde A da la misma evidencia que B.
- **Alquiler exclusivo (`β_x`)** — `derivado`, confirmado: no usa la misma oportunidad dos veces, así que
  ninguna identidad lo alcanza.
- **Añadido — grinding de pruebas alternativas** (`IDENTIDAD.md` §4): para el mismo `(pieza, bucket,
  chunk)` puede existir más de una prueba válida. Bajo las tres identidades eso es **el mismo billete**
  (mismo chunk por E3, misma pieza), así que **no crea cobros nuevos**; pero **sí** cambia qué bloque es
  elegible. Ninguna de las tres lo cierra, y el cambio no lo empeora.
- **Añadido — la invalidación en cascada de Resultado 6/7** no es un cierre sino un **coste nuevo** que
  B introduce y que A no tiene.

---

## 8 · F6 · Coste de la migración

**Reglas y artefactos que hay que reescribir** (detalle fila a fila en `INVENTARIO.md`):

1. `SPEC.md:2316` (`C-GD-07`/R-FIN-11): la tupla. Cambia la **definición**, no la estructura de U2 ni
   de U3″: ambas siguen igual, con otra clave.
2. La compresión de la tupla a `u64` en `crates/zx-consensus/src/ghostdag.rs` (`BloqueGhostdag.identidad`):
   hoy **el módulo no la calcula** — la recibe ya comprimida (`ghostdag.rs:136-151`) y esos puntos de
   entrada están en `ci/consenso-pendiente.txt:31-38`. **No hay código de producción que cambiar**, solo
   el contrato de quien la alimente.
3. `C-GD-10`: añadir el descarte de puntas que violarían U2 (Resultado 7).
4. `C-FLU-12`: su invariante debe reescribirse o imponerse (Resultado 16, §9).
5. `INVENTARIO.md` lista los modelos de test que consumen la identidad (DCM-v0.1, CBE-v0.1,
   ventana-retarget-causal): sus fixtures **no caducan por el formato**, pero sí por **semántica** si
   comparan colisiones de billete.

**Vectores que caducan.** Ninguno por bytes: la identidad **no** entra en `block_hash` ni en `pre_hash`
(los bytes de la solución sí, `zx-core::preimage::dag`). Caducan por semántica: cualquier fixture que
declare dos billetes iguales o distintos. `crates/zx-core/tests/vectores_dag.rs:62-77` y
`oraculo_julia.rs:68-77` **no** cambian (son vectores de serialización).

**Bloques ya producidos bajo A.** La identidad es una clave de deduplicación **local**; cambiar la regla
no invalida las firmas. Pero un replay de la historia bajo B puede **invalidar** bloques que eran válidos
bajo A (Resultado 6). Es un cambio de consenso del §14 (`C-UPG`), no una relectura.

**¿Se puede adoptar B sin el registro de parcelas?** **Sí**: `piece_offset` ya está en la cabecera
(`[154,156)`, `SPEC.md` §6.1) y en la prefirma, así que B no necesita ningún campo nuevo.
**C no**: `PlotBatchId` compromete «clave, raíz de los bytes codificados, cardinalidad, versión de
parcela y época de registro» (`SOLUCION-CANDIDATA-REUTILIZACION.md` §1) y **no existe** en el protocolo
ni en `crates/`; además arrastra maduración, recompensas retenidas y auditorías de permanencia.

**El bloqueo declarado de IDV-01.** Es literal —
`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md:34-37`:
*«Bloqueante pendiente: qué retos y raíces alternativos del mismo slot pertenecen a la misma oportunidad
en ZEROX»* — y ninguna autoridad lo levanta en ese documento; `P-EQUIVOCACION/investigacion/
DECISIONES-PENDIENTES.md:14` atribuye la decisión a Katana. **Este trabajo no lo levanta, y además
demuestra que B no lo levanta**: por E1/E2, dos retos distintos del mismo slot dan buckets distintos, y B
**no** los unifica (Resultado 3). La condición sigue abierta y es ahora más precisa: **B unifica «misma
pieza, distinto reto» solo cuando la misma pieza gana en ambos**, con la probabilidad de Resultado 12.

---

## 9 · Inventario (resumen; el detalle está en `INVENTARIO.md`)

| Qué usa la identidad | Propiedad que necesita | Con A | Con B | Con C |
|---|---|---|---|---|
| `C-GD-07` **U2** | unicidad en padres y pasado estricto | igual | **igual dentro de una historia**; más agresiva entre ramas | como B |
| `C-GD-07` **U3″** | unicidad entre azules del mergeset | igual | igual dentro de una historia | como B |
| **P1 / `C-ORD-02`** | agrupar copias y desempatar | igual | agrupa más (entre ramas) | como B |
| **Conjunto consumido + reorg** (§7.2) | una sola adjudicación por clave, reconstruible | igual | clave distinta ⇒ el conjunto cambia de contenido, no de reglas | como B |
| **R-FIN-8′ / R-FIN-13′** | mismo conjunto pagable en retarget y emisión | igual | igual dentro de una historia; se reduce al fusionar copias | como B |
| **`C-FLU-12` entropía** | **dos copias del mismo billete ⇒ misma entropía** | **se cumple siempre** | **se rompe** entre ramas de retos divergentes (medido) | se rompe |
| **`crates/`** | compresión de la tupla a `u64` | no existe; sin cablear | habría que definirla | ídem + `PlotBatchId` inexistente |
| **Cabecera `[154,156)` `piece_offset`** | el campo debe viajar | ya viaja | **ya viaja** | falta `PlotBatchId` |

---

## 10 · Resultado adicional: el invariante de `C-FLU-12` (Resultado 16)

`SPEC.md` §7.1.4: *«Invariante de no-equivocación del inyector. Dos copias del mismo billete MUST
producir la misma entropía y el mismo `t_j`»*, con
`entropía_j(B) = blake3(chunk(I_j(B)) ‖ pot_output(I_j(B)))`.

- Bajo **A**, `chunk` es parte de la identidad ⇒ dos copias comparten `chunk` ⇒ **el invariante es un
  teorema**.
- Bajo **B/C**, `chunk` **no** es parte de la identidad ⇒ dos copias pueden llevar `chunk` distinto (es
  el caso de Resultado 3) ⇒ **la entropía difiere**.
- **Medido** (columna «entropía violada» de `resultados/RUN.txt`): en `flujo-divergente-misma-pieza`,
  `viola = no` bajo A y **`SÍ`** bajo B y C; en los otros 8 fixtures, `no` en las tres.
- **Consecuencia para el coste ya escrito en §7.1.4.** El coste de A («dos billetes distintos con el
  mismo `chunk` dan la misma entropía») **no cambia de tamaño** con la identidad: sigue siendo una
  colisión de 32 bytes. Lo que cambia es que B/C **añaden** un caso que A no tiene: la misma identidad
  con **dos entropías**. Eso obliga a reescribir el invariante (p. ej. atándolo a la oportunidad y no al
  billete) o a declarar el caso como coste aceptado. **No se ha encontrado un ataque por esa vía y no
  encontrarlo no es cerrarlo.**

---

## 11 · Lo que esta investigación NO resuelve

1. **No decide.** A, B o C es decisión de Katana; aquí solo se dice qué toca cada una.
2. **No mide `q` ni `P` reales.** `pieces_in_sector` tiene cota (1000 mainnet) pero no distribución; `q`
   procede de `pieces_to_solution_range`, no de un plot real. Las tasas son **funciones**, no cifras del
   sistema.
3. **No mide la tasa real de flujos divergentes.** `equivoca` es un parámetro; `P-EQUIVOCACION` P4/P5 da
   la condición (`n_priv > n_com` en `V_j`), no la probabilidad. Sin ella no hay cifra de sistema.
4. **No hay criptografía en el enumerador.** Ni firmas, ni KZG, ni `blake3`: la identidad es una
   codificación inyectiva. La consecuencia de una colisión real (agrupar más) **no** está medida.
5. **No modela el coste de grindear pruebas alternativas** (`IDENTIDAD.md` §4) ni su efecto sobre la
   elegibilidad.
6. **No cuantifica el `blue_work` en unidades económicas.** Cuenta bloques pagables y pesos enteros; no
   emisión ni monedas. El puente espacio→tasa (`P-CRP/auditoria/DEFECTOS.md` C1) sigue abierto, así que
   «cuánto vale» el cierre de F4 sigue siendo `no determinado`.
7. **No rehace la aritmética de adelanto `+D`** de `C-FLU-12` (`TAREAS.md` §2.9).
8. **No verifica E3 sobre un plot real.** E3 se lee del código fijado; que la colocación de chunks en
   buckets sea exactamente «uno por (pieza, bucket)» en un plot generado por `plotting.rs` se apoya en la
   estructura de bitfields, no en una ejecución del plotter.

---

## 12 · Reproducción

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-IDENTIDAD/investigacion/veritas/consenso/identidad-billete-v1
export JULIA_DEPOT_PATH="$PWD/../../../../.julia-depot:$HOME/.julia"

# 1 · entorno (una vez)
../../../../../../veritas/julia.sh --project=. -e 'using Pkg; Pkg.develop(path="/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1"); Pkg.instantiate()'

# 2 · validación (259 tests, límites activos)
../../../../../../veritas/julia.sh --project=. --check-bounds=yes -e 'include("test/runtests.jl")'

# 3 · resultados del informe (8,8 s, 421 MiB)
../../../../../../veritas/julia.sh --project=. --threads=4,0 run.jl --seed 0x5a5a --replicas 400 todo

# 4 · benchmarks y escalado
../../../../../../veritas/julia.sh --project=. --threads=4,0 bench/benchmarks.jl
for h in 1 2 4; do ../../../../../../veritas/julia.sh --project=. --threads=$h,0 bench/escalado.jl; done
```

Artefactos: `resultados/RUN.txt`, `resultados/BENCH.txt`, `resultados/ESCALADO.txt`.
Semilla `0x5a5a`; RNG por réplica con secuencia de Weyl (no consecutiva, hallazgo de `P-ZRX/P-PUERTA/`),
reducción determinista por índice de réplica.

### Tabla de rendimiento (LINEO §6)

| Variante | Tiempo mínimo | Asignaciones | Hilos | Resultado frente al oráculo |
|---|---:|---:|---|---|
| Oráculo GDR (`EstadoReferencia`) | 0,848 ms | 31 999 | 1 CPU | fuente de verdad |
| Kernel GDR + capa pagable indexada | 0,500 ms | 12 029 | 1 CPU | idéntico en los 27 casos fixture×modo |
| Kernel GDR + capa pagable por conjuntos | 0,344 ms | 9 434 | 1 CPU | idéntico en los 27 casos fixture×modo |

Escalado del Monte Carlo (400 réplicas × 120 bloques): 0,104 s (1 hilo) → 0,071 s (2) → 0,040 s (4);
**2,6× a 4 hilos** con reducción entera idéntica (16 474). No se usó GPU ni `@fastmath`, `@inbounds`,
`@simd` ni `Float32`.
