# HIPÓTESIS — espacio-tasa-v1

Escritas **antes** de programar el kernel. Cada una lleva su estado tras la medición. El encargo §3
pide además la complejidad del método (§6) y el control analítico (§5).

## 0 · Control analítico obligatorio (no es la respuesta final)

Reproducido en enteros exactos, con `SR` de tipo `u64`:

```
A(SR) = 2·⌊SR/2⌋ + 1                        cardinal de valores a distancia circular admisible
p(SR) = A(SR)/2^64                          probabilidad por chunk EFECTIVAMENTE auditado
w(SR) = ⌊2^128/(SR+1)⌋                       peso por bloque (SPEC.md C-GD-01)
E[candidatos/slot] = P · p(SR)              con P = chunks auditados por slot
```

El predicado se leyó del código fijado: `solution_distance <= solution_range / 2`
(`subspace-verification/src/lib.rs:150-158`) con `solution_distance` = distancia circular sobre
`Z/2^64` (`solutions.rs:330-337`). Aceptan los valores a distancia `0…⌊SR/2⌋`: uno a distancia 0 y
**dos** a cada distancia `j ≥ 1`; de ahí `2·⌊SR/2⌋+1`. `⌊SR/2⌋ ≤ 2^63−1`, así que los dos lados del
círculo no se solapan y la cuenta es exacta en todo el dominio.

**Efecto de paridad (demostrado y comprobado):** `A(2m) = A(2m+1)` y sin embargo
`w(2m) ≠ w(2m+1)`. Para la **misma** tasa de bloques hay **dos** pesos distintos. El déficit del
`SR` impar en la tasa de peso es exactamente `1/(SR+1)` menos el suelo, y **crece** al crecer la red
(porque `SR` decrece). Con `SR_MIN = 2^11` llegaría a `4,88·10⁻⁴`.

## 1 · Hipótesis y su estado tras medir

| # | Hipótesis | Estado | Evidencia |
|---|---|---|---|
| **H1** | El puente espacio → tasa **no existía** en el repositorio (defecto C1 de P-CRP; advertencia de P-PRESTAMO). Este instrumento lo construye para las etapas observables. | **Confirmada** la ausencia; **construida** la primera medición. | `DEFECTOS.md` C1; `P-PRESTAMO/INFORME.md:32-36`; `INFORME.md` §2. |
| **H2** | `create_proofs` produce **exactamente** `NUM_CHUNKS = 32768` pruebas sobre `NUM_S_BUCKETS = 65536` buckets, luego `E_b[ocupación] = 1/2` **exacto** y `E[chunks auditados/slot] = piezas/2`. | **Confirmada, exacta.** | 1000 piezas reales: `pruebas_por_pieza_min = max = 32768`; `s_bucket_size_media = 500.000000` con 1000 piezas. |
| **H3** | La ocupación **no es constante ni aproximadamente constante** por bucket: la varianza de `s_bucket_sizes` es mucho mayor que la de `Binomial(piezas, 1/2)`. | **Confirmada**: var `40792,23` frente a `250` de la referencia binomial → **factor 163,2**. | `OCUPACION.tsv`, `sobredispersion_bucket`. |
| **H4** | En consecuencia, el número de **chunks auditados por slot** tiene media `piezas/2` pero una dispersión muy superior a la binomial, y una fracción no despreciable de slots con **cero** oportunidad para un sector. | **Confirmada**: var `34108,22` (referencia `250`), **9,0668 %** de los buckets del sector están vacíos. | `AUDITORIA.tsv`, `OCUPACION.tsv`. |
| **H5** | `audit_chunk = blake3_keyed(ssc, chunk)` es uniforme, así que la probabilidad de ganar por chunk **efectivamente auditado** es exactamente `A(SR)/2^64`, y `E[candidatos/slot] = P·p(SR)`. | **Confirmada** en todo el rango medido: ratios medido/modelo `0,896` (SR calibrado), `0,9992`, `1,0038`, `0,9998`, `1,0000`. | `CANDIDATOS.tsv`. |
| **H6** | Los dos retos divergentes sobre la **misma** parcela **no** se reparten el espacio: `W₁+W₂ > 1`. | **Confirmada**: el escenario compartido audita `1 051,94` chunks/slot frente a `525,97` del reparto en mitades (promedio de las dos asignaciones). La razón es **2 exacto por construcción algebraica**, no una medición (H12). | `FLUJOS.tsv`, `reparto_exclusivo_razon_exacta` |
| **H7** | Las **oportunidades** de dos retos divergentes sobre la misma parcela son casi independientes. | **Confirmada**: `corr = −0,01125`; solapamiento `275,81` frente al hipergeométrico `276,49`. | `FLUJOS.tsv`. |
| **H8** | Los **ganadores** de dos retos divergentes son casi independientes, así que `Pr(≥1)` se puede calcular con el producto **al mismo nivel de agregación**. | **Confirmada, con matiz**: a `p = 1/2` el doble ganador medido es `67,94` y el independiente `68,95`; a `p = 1/3000`, `0,2634` observado frente a `0,2933`, y el IC95 por bootstrap sobre los 64 retos es `[0,1238, 0,3953]`, que **contiene** la referencia. El veredicto «−2,5 σ» de la revisión 1 **se retira**: suponía 2 016 pares independientes y son 64 retos. Se publican **los dos** números; **no** se sustituye la medida por el producto. | `FLUJOS.tsv` |
| **H9** | `α_bytes`, `α_candidatos` y el trabajo azul son la **misma** fracción, y en particular el trabajo azul del adversario **no supera** su fracción de bytes. | **REFUTADA, y la afirmación derivada era FALSA.** Son magnitudes distintas: `f_bytes_solicitados ≠ f_piezas_efectivas` cuando hay sobrantes, `f_candidatos = f_piezas_efectivas` es una **identidad del modelo** (no una validación), y la cuota azul condicional con `f = 0,3`, `β_a = 1`, `β_h = 1/2` es **6/13 ≈ 0,4615 > 0,3**. Retirada de informe, contrato, hipótesis y tests. | `modelo.jl` `cuota_azul_condicional`; test adversarial en `runtests.jl` |
| **H12** | El factor «compartir / repartir» de 2,0028 es una magnitud de pérdida de seguridad. | **REFUTADA.** Es una **identidad algebraica**: con `s = s_a + s_b`, `promedio = compartido/2` para **todo** par. El **cociente** es 2 si `compartido > 0` e **indefinido** (`0/0`) si los dos buckets están vacíos —**10 de los 2016 pares** reales—. El `2,0028` era el cociente de una sola asignación asimétrica. La parte universal («=2 para todo par») la refutó la revisión independiente. | `ET.reparto_exclusivo`; `FLUJOS.tsv`, `compartir_vs_repartir_pares_degenerados` |
| **H13** | La verificación de una prueba con `is_proof_valid` acredita la verificación completa de la solución. | **REFUTADA.** `is_proof_valid` verifica la **prueba PoS**; no comprueba compromiso, testigo KZG, firma, cabecera, PoT ni admisión DAG. Rótulo corregido a `pruebas_pos_validas`; la verificación completa queda **`pendiente`** con bloqueo reproducible. | `prueba-meta.tsv`; `INFORME.md` §5 |
| **H15** | La fracción de bytes de un actor es su cuota de sectores. | **REFUTADA como enunciado único.** Depende del escenario: con 1 TiB y `α = 1/100`, el escenario 1 (truncamiento por actor) da **10/1039** y el 2 (reparto del plot) da `10/1040`. Los dos se publican por separado. | `ET.presupuestos_independientes`, `ET.reparto_sobre_plot`; test exacto en `runtests.jl` |
| **H16** | Repartir el mismo espacio entre más identidades conserva el espacio efectivo. | **REFUTADA como igualdad; MATIZADA en su alcance.** `Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋` siempre (con `Σbytes_i = T` exacto), y la pérdida **no es monótona** en `N` (N=7 pierde 4, N=10 pierde 0); la cota afirmable es `perdidos ≤ N`. **El corolario «1041 identidades ⇒ cero espacio efectivo» queda RETIRADO**: es condicionado a `piezas_por_sector = 1000`, y con 999 piezas cada presupuesto de 1 056 207 136 B sí admite un sector. | `ET.perdida_agregacion`, `ET.tabla_identidades`, `ET.piezas_que_caben`; `TABLA-IDENTIDADES.md` |
| **H18** | `⌊bytes/sector_size(1000)⌋` es la capacidad en sectores de un presupuesto. | **CONDICIONADA.** Es la capacidad **bajo la hipótesis** `pieces_in_sector = 1000`. Con menos piezas por sector el mismo presupuesto admite más sectores; `ET.piezas_que_caben` da el máximo que cabe. | test «hipótesis de 1000 piezas y su contraejemplo» |
| **H19** | La fracción de candidatos puede calcularse mezclando un presupuesto independiente con los sectores agregados. | **REFUTADA y función retirada.** `fraccion_candidatos_esperada(ra, rt; SR)` derivaba el lado honesto por resta del total agregado y daba `10/1040` donde el escenario 1 da `10/1039`. Sustituida por `cuota_piezas_escenario1` y `fraccion_candidatos_esperada_esc1`, que solo usan presupuestos independientes. | test que comprueba `!isdefined(ET, :fraccion_candidatos_esperada)` |
| **H17** | `sector_size()` es el tamaño físico total de un sector. | **PRECISADA.** Es el tamaño del **plot**; la metadata `SectorMetadataChecksummed` (131 116 B) es fija, externa y no está en el fichero. | `ET.metadata_fuera_del_sector`; `resultados/constantes.tsv` |
| **H14** | El tamaño de sector calculado a mano es correcto. | **REFUTADA.** `RecordMetadata::encoded_size()` es **128**, no 96 (incluye el `piece_checksum` de 32 B). `sector_size(1000) = 1 056 896 064`, no 1 056 864 064. Detectado contrastando con la API del clon. | `resultados/constantes.tsv`; `sector.rs:139-152` |
| **H10** | `H-BETA`: la fracción azul `β` es `P(Poisson(2νΔ) ≤ k)`. | **No verificada aquí**: es una declaración de P-PUERTA y **no** un teorema de GHOSTDAG. Todo `blue_work` de este informe se publica con `β = 1`, que es el **límite favorable al adversario**, y se etiqueta `condicionado`. | `INFORME.md` §5. |
| **H11** | La cadena acredita cuántos bytes conserva un granjero. | **Refutada de antemano por P-COBERTURA §2.4**: «Hoy **nada** acredita» la preexistencia; `verify_solution` deriva el `sector_id` de la propia solución. Este instrumento **no** lo asume ni lo afirma. | `INFORME.md` §6. |

## 2 · Lo que **no** se asume

- **No** se asume independencia para calcular `Pr(≥1 ganador)`, varianza ni colas: se **mide** la
  frecuencia conjunta y se publica al lado del producto (H7/H8). El producto se calcula solo como
  contraste, y **al mismo nivel de agregación** que lo observado.
- **No** se asume que `η = 1`.
- **No** se acepta un `SR` sin la comprobación contextual de C-HDR-06: el `SR` del instrumento es un
  **escenario experimental calibrado**, no el valor de una red ZEROX.
- **No** se sustituye la admisión PoST + DAG por una puerta parcial: `AlmacenGhostdag::admitir` es
  una puerta de rango, **no** validación PoST completa, y `zx-node` sigue lineal.
- **No** se usa la coma flotante para decidir una regla discreta: el predicado, la cardinalidad y el
  peso van en enteros; `Float64` solo aparece al **resumir** una muestra.

## 3 · Complejidad del método

| Etapa | Coste | Representación |
|---|---|---|
| Aritmética exacta (`A`, `p`, `w`, cancelación) | `O(1)` por `SR`, precisión arbitraria | `BigInt`/`Rational{BigInt}`: la cancelación se decide en el bit `2^-64` |
| Ocupación por bucket, referencia lenta | `O(piezas × 65 536)` pruebas de bit | `Matrix{UInt8}` `(piezas, 8192)` |
| Ocupación por bucket, kernel | `O(65 536 × (piezas + 256×8))` | histograma de 256 bins por columna, contador `Int32[65536]` |
| Ocupación paralela | igual, partida por bloques de columnas | contador privado por bloque + reducción en orden de índice |
| Auditoría de un reto | `O(piezas)` con `rank/select` `O(1)` | `rank` de `popcount` por byte |
| Oráculo Rust (una pieza) | `O(tabla chiapos)` ≈ 75 ms/pieza a 16 hilos | `Tables::create_proofs_parallel` + `ErasureCoding::extend` |

El parámetro que domina todo el coste es la **generación de la tabla PoS** (H = 20): 1000 piezas
costaron **75,20 s** (13,30 tablas/s con 16 hilos). La auditoría de 6144 retos×`SR` sobre esas
1000 piezas costó **0,44 s**: auditar es entre 3 y 4 órdenes de magnitud más barato que plotear.
