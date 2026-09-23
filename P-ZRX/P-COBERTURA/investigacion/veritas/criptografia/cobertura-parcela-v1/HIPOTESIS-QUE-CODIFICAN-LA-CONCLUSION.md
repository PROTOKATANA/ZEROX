# Hipótesis que codifican la conclusión — `cobertura-parcela-v1`

Cada fila dice **qué se está suponiendo**, **de dónde sale**, **qué afirmación sostiene** y
**qué la falsaría**. Si una hipótesis cae, la conclusión que sostiene cae con ella; el
`INFORME.md` principal marca, por cada resultado, de qué fila depende.

## H1 · El objeto es función determinista y pública de `(clave, índice, historia)`

- **Enunciado.** Las tablas PoS de una pieza se derivan de una semilla
  `pos_seed = derive_evaluation_seed(sector_id, piece_offset)`, con
  `sector_id = blake3_keyed(public_key_hash; sector_index, history_size)`, y el resto del
  ploteo no usa aleatoriedad adicional.
- **Fuente.** `PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:61-67,126-129`;
  `.../subspace-farmer-components/src/plotting.rs:252-256,400,626-627,659-665`.
  **Etiqueta: `verificado en fuente`.**
- **Sostiene.** El núcleo del teorema de imposibilidad (§3 del `INFORME.md`): si el objeto
  es público y determinista, un tercero puede reproducirlo bit a bit y la simulación del
  tramposo es exacta.
- **La falsaría.** Que la semilla de la tabla dependiera de un secreto del granjero, o que
  el ploteo introdujera aleatoriedad no reproducible. Eso es exactamente la vía (iv).

## H2 · El cómputo es paralelizable por unidad

- **Enunciado.** Las tablas de piezas distintas se generan de forma independiente; no hay
  una cadena secuencial que ate la generación de una unidad a la anterior.
- **Fuente.** `plotting.rs:626-627` usa `generate_parallel(pos_seed)` por pieza;
  `P-ZRX/P-INTENTO/investigacion/INFORME.md` mide el agregado concurrente (8 llamadores
  sobre una piscina de 24 hilos) con mediana `25,027041` unidades/s.
  **Etiqueta: `verificado en fuente` + `medido`.**
- **Sostiene.** Que la única barrera sea cuantitativa: con suficiente hardware, cualquier
  `N` se regenera dentro de la ventana. Es lo que hace que (i), (ii) y (iii) sean
  desigualdades sobre hardware y no propiedades de la prueba.
- **La falsaría.** Un grafo de profundidad (DRG) o un sellado secuencial que obligue a un
  orden total. Eso es la vía (ii). `research/time-memory-tradeoff.md:63-77` **no** prueba la
  generalización a siete tablas, así que **hoy no hay cota publicada** que la falsifique.

## H3 · El reto se conoce con `w > 0` de antelación

- **Enunciado.** `w` es la ventana de adelanto en slots con que el reto es público.
- **Fuente.** `P-ZRX/P-REVELACION/investigacion/INFORME.md:47-48` (`V_min = 7 175` sin
  segundo VDF), `:84` (`4 830,6` con VDF a `ρ = 2,5`); `P-ZRX/P-ADELANTO/.../INFORME.md:45`
  (tope histórico `8 030`). Unidad: **slots**; nominalmente `1 slot = 1 s`
  (`SPEC.md:2615,2620-2621`; `SLOT_DURATION = 1000` en
  `PDF/autonomys-subspace/crates/subspace-runtime/src/lib.rs:145`).
  **Etiqueta: `derivado de medida`.**
- **Sostiene.** La ventana total `w·τ + D_a` y, con ella, `B`. Es la palanca dominante:
  a `w = 7 175` la ventana vale 7 235 s y `B` es 120× mayor que con `D_a` solo.
- **La falsaría.** Que el reto no fuera conocido con antelación (`w = 0`). Entonces `B`
  caería a `R·D_a` y `k > B` sería alcanzable con `k` del orden de miles.

## H4 · La verificación es sucinta

- **Enunciado.** El verificador no lee las `N` unidades: recibe una prueba corta.
- **Fuente.** `subspace-verification/src/lib.rs:211-216,228-232` (sólo recibe la solución y
  parámetros de historia); `lib.rs:248-249,263-269,336-345` (una apertura KZG y una prueba
  PoS).
- **Sostiene.** Que la única información disponible sea el transcripto. Si el verificador
  leyera el lote entero, la simulación no bastaría.
- **La falsaría.** Un esquema en que el verificador descargue y compruebe todo el lote
  (deja de ser sucinto, pero cambia el problema).

## H5 · `t_unidad` y `R` son entradas, y `R` sólo está acotada por arriba

- **Enunciado.** `t_unidad = 0,809 s/unidad` (una tabla por pieza) y `R = 25,03
  unidades/s` (agregado de la máquina de referencia) son **entradas congeladas** del
  encargo §1.3, no medidas en este encargo.
- **Fuente.** `P-ZRX/P-INTENTO/investigacion/INFORME.md:210,223`;
  `mediciones/m1_tabla.txt:22`; `mediciones/m1_escalado.txt`. **Etiqueta: `medido`, sin
  revalidar.**
- **Sostiene.** Todas las cifras de coste. **`R` es cota SUPERIOR del rendimiento
  demostrado del código publicado**, es decir, **cota INFERIOR del coste del adversario**:
  SIMD, GPU y ASIC no están medidos. Ninguna garantía se deriva de `R`.
- **La falsaría.** Un kernel adversarial mejor. Baja el coste y **no** cambia la frontera
  `1 − B/N` en su forma, sólo su valor.
- **Nota de calidad heredada.** `t_tabla` es **s/núcleo y por tabla** (una tabla por
  pieza); la etiqueta `s/pieza` de `mediciones/hardware.tsv` en P-PERMANENCIA es
  imprecisa aunque numéricamente coincida. `R` procede de la **ruta paralela**; la ruta no
  paralela tiene un SIGSEGV reproducible (`P-ZRX/P-INTENTO/investigacion/mediciones/fallo-semilla.md:14-17,78-87`).

## H6 · El modelo de detección: posiciones uniformes sin reemplazo, auditorías independientes

- **Enunciado.** La auditoría pide `k` posiciones distintas uniformes; el adversario elige
  qué omitir antes del reto; las auditorías sucesivas son independientes.
- **Fuente.** Decisión de modelado, declarada. El `SectorId` y `derive_piece_index` ligan
  clave, índice, historia y offset (`sectors.rs:54-68,70-114`), así que las posiciones son
  función determinista del reto; el reto es público `w` slots antes.
- **Sostiene.** Que la ley sea hipergeométrica y que la frontera sea exacta
  (`k ≤ B` ⇒ no hay detección posible).
- **La falsaría.** Que el adversario pudiera sesgar qué posiciones se abren (lo que
  requeriría predecir el reto más allá de `w`), o que las auditorías no fueran
  independientes (lo que sólo cambiaría la acumulación, no la frontera).

## H7 · El adversario no está acotado en paralelismo (modelo de amenaza de Katana)

- **Enunciado.** Se asume un ente con mucha capacidad —dinero, CPU, GPU, discos— que
  **atacará**; «no compensa económicamente» no es argumento de seguridad.
- **Fuente.** Modelo de amenaza del encargo §0.
- **Sostiene.** La forma fuerte del veredicto: con paralelismo ilimitado, para **cualquier
  `N`** existe un `R` que regenera el lote dentro de la ventana, así que ninguna prueba
  sucinta de un objeto público lo excluye *por principio*.
- **La falsaría.** Acotar explícitamente el paralelismo del adversario. Entonces la
  imposibilidad se vuelve cuantitativa: se sostiene mientras `N > B`.

## H8 · Hipótesis declaradas del coste (no medidas)

| Hipótesis | Valor usado | Fuente | Qué sostiene |
|---|---:|---|---|
| Aceleración GPU | 17× | **documentación ajena, NUNCA medida** | fila propia de `F4-coste.tsv`; sin ella la cota económica se erosiona por debajo de ~6,9 GPU/TiB |
| Consumo por núcleo | 65 W | hipótesis | ratio energía regenerar/almacenar ≈ 1 524 |
| Consumo por TiB de disco | 5 W | hipótesis | íd. |
| Razón de precio núcleo/TiB | 1,0 | hipótesis | sitúa el cruce de hardware en `w ≈ 8,5·10⁵` slots |
| Bytes por alta de registro | 200 B | hipótesis | estado y tasa de altas de F5 |
| `κ` (segmentos/slot) y `h` | barridos | **entradas**, no medidas | vida del sector y tasa de re-altas |

**Ninguna de estas seis es una medida.** Todas entran con fila propia y etiqueta
`hipótesis` en los artefactos.

## H9 · Las cifras de coste publicadas son coherentes entre sí

- **Enunciado.** `235,6 h·núcleo/TiB` y `5,84 «CPU»/TiB` describen el mismo trabajo en
  unidades distintas, con factor exacto `r·t = 20,24927`.
- **Fuente.** `P-ZRX/P-PERMANENCIA/.../src/modelo.jl:108,111-112,167`; `resultados/E1-E4-coste.tsv`,
  `resultados/E3-ventana.tsv`; reconciliación reproducida en `resultados/F4-reconciliacion.tsv`.
  **Etiqueta: `derivado`.**
- **Sostiene.** Que se puedan usar las dos sin contradicción, con las etiquetas corregidas
  (`s/pieza` → `s/tabla`; «16 núcleos físicos» → «piscina de 24 hilos»; «CPU» = máquina
  completa medida).
- **La falsaría.** Que el factor no fuera `r·t`. **No entra ningún factor 7 ni
  `NUM_CHUNKS = 2¹⁵`**: las 7 tablas ChiaPos se construyen y se destruyen dentro de la
  misma llamada, y se retiene **un** objeto `Proofs<20>` de 5,008 MiB.

## H10 · El adversario decide con el hardware, no con el precio del disco

- **Enunciado.** El coste se publica en núcleos, máquinas y GPU-equivalentes. El precio
  del disco entra **sólo** como razón de precio declarada, para situar el cruce.
- **Sostiene.** Que el veredicto no dependa de un supuesto monetario.
- **La falsaría.** Nada: es una decisión de método. Pero **el cruce sí depende** de la
  razón de precio, y por eso se publica para `0,1 · 0,5 · 1 · 2` (`F4-coste.tsv`).
