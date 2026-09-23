**F2 · NO PUEDE EXISTIR, para el formato fijado y sin cambiarlo, una prueba de verificación
sucinta que distinga «almacenado» de «regenerado dentro del plazo» y que por tanto acredite
preexistencia.** La imposibilidad es de **simulación** y no usa ninguna suposición de dureza
computacional: el transcripto de un adversario que regenera el objeto dentro de la ventana es
**idéntico** al del honesto, porque el objeto es función determinista y pública de
`(clave, índice, historia)` (`plotting.rs:626-627,659-665`) y su cómputo es paralelizable por
unidad (`P-INTENTO`, medido). Las cuatro vías de escape del encargo **no son equivalentes**:
(i), (ii) y (iii) son **desigualdades cuantitativas sobre hardware y ventana** —ninguna es
imponible *por la prueba*, y con el modelo de amenaza de Katana sólo mueven el coste—; la
única que rompe la hipótesis estructural es (iv), y (iv) exige **cambiar el objeto ploteado**,
es decir, cambiar el formato. **Hipótesis a la vista en §3.** [demostrado]

# INFORME — P-COBERTURA

**Encargo:** `P-ZRX/P-COBERTURA/PROMPT.md`. **Instrumento:**
`P-ZRX/P-COBERTURA/investigacion/veritas/criptografia/cobertura-parcela-v1/` (categoría
`criptografia`; Julia 1.13.0, CPU `znver5`, 4 hilos). **Fecha:** 2026-09-22.

**Presupuesto declarado antes de ejecutar:** máximo **4 hilos**, **8 GiB de RAM**,
**256 MiB de disco**, **2 h de pared**. **No se agotó** (≈ 90 s la corrida completa).
Comprobaciones de entrada y salida en `PROGRESO.md`.

**Zona de escritura respetada:** solo `P-ZRX/P-COBERTURA/investigacion/`. No se editó ni
movió nada de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`,
`veritas/`, `PDF/` ni del resto de `P-ZRX/`. `PROMPT.md` y `ENTRADA.sha256` no se tocaron.

---

## 0 · Respuesta corta, y una corrección al planteamiento del encargo

### 0.1 · Objeciones al encargo, declaradas antes de ejecutar el instrumento

**O1 · El «salvo que» del teorema de §2.2 hace casi todo el trabajo, y el encargo no lo dice.**
Las cuatro vías (i)-(iv) no son del mismo tipo. (i), (ii) y (iii) son **condiciones
cuantitativas** —«la latencia es menor que…», «el coste secuencial supera…», «hacen falta más
unidades de las que caben en la ventana»— y ninguna de las tres es una propiedad que la prueba
pueda imponer: son propiedades del **hardware del adversario** y de `w`. Con el modelo de
amenaza obligatorio («un ente con mucha capacidad atacará»; «no compensa económicamente no es
argumento de seguridad»), (i)-(iii) **no cierran nada por principio**: sólo encarecen. La única
vía de naturaleza distinta es (iv), no regenerable, y exige cambiar el objeto. Por eso el
veredicto de F2 se enuncia con dos alcances separados: **imposible por principio** (cualquier
paralelismo) e **imposible bajo un tope de paralelismo declarado** (cuantitativo).

**O2 · «Para el formato fijado y sin cambiarlo» conviene decirlo en las dos direcciones.**
Si la respuesta es «no puede existir», la pregunta útil deja de ser «¿qué prueba falta?» y pasa
a ser «¿qué es lo máximo que sí se puede comprometer?», que es F6. El encargo ya lo pide; lo
subrayo porque la lectura de F2 no debe quedar como «hay que seguir buscando».

**O3 · La vía (iii) no está respaldada por la literatura que el propio encargo manda abrir.**
`PDF/time-memory-tre-off-proof-space.pdf` (Abusalah–Alwen–Cohen–Khilko–Pietrzak–Reyzin 2017)
da `T·S² ∈ Ω(ε²N²)` (Teorema 2, pág. 14), que es una cota sobre el **número total de consultas
al oráculo**, no sobre latencia, y el modelo **no postula no-paralelizabilidad** ni obliga a
materializar las `N` unidades a la vez. Es decir: el compromiso espacio-tiempo publicado
sostiene (ii) y (iii) sólo como **coste agregado**, exactamente igual que (i). Lo desarrollo en
§4.3.

**O4 · No se re-miden las entradas de §1.3, y una de ellas tiene la etiqueta imprecisa.**
`t_tabla` es **segundos por tabla a 1 núcleo**, no «por pieza»: coinciden numéricamente porque
hay **una** tabla-objeto por pieza, pero la llamada construye y destruye las siete tablas
ChiaPos dentro de la misma función. Y `r = 25,03` procede de la **ruta paralela**; la ruta no
paralela tiene un SIGSEGV reproducible
(`P-ZRX/P-INTENTO/investigacion/mediciones/fallo-semilla.md:14-17,78-87`). No rehago la medida;
lo digo para que la cifra no se use como si fuera un suelo del coste del adversario. **`r` es
cota superior del código publicado, o sea cota inferior del coste del atacante.**

### 0.2 · Las seis respuestas

| | Respuesta en una línea | Etiqueta |
|---|---|---|
| **F1** | Las tres coberturas se separan; el formato da la 1ª (inútil), **no da la 2ª ni la 3ª**, y la forma almacenada no se prueba **ni para un chunk**. A1+C1 pide la 2ª+3ª+preexistencia+vinculación. | `verificado en fuente` |
| **F2** | **No puede existir** para el formato fijado, por simulación, bajo H1-H5. (iv) es la única vía estructural; (i)-(iii) son cuantitativas. | `demostrado` |
| **F3** | (i) **no disponible** (`w` es estructural); (ii) disponible **cambiando la generación** (PoRep); (iii) **no cierra sola** y no la respalda el PDF; (iv) disponible **cambiando la semilla**. **(ii) y (iv) cambian la parcela; ninguna conserva el formato.** | `derivado` |
| **F4** | `almacenamiento_forzado = max(0, 1 − B/N)`, **independiente de `k`**. A `w=7.175`, 1 máquina: `B=181.092`; **con `k=1.000` o `k=100.000` la detección es imposible**; haría falta `k>181.092` aperturas por TiB. Coste del tramposo: **117,2 núcleos/TiB continuos** ≈ 1.524× la energía de almacenar. | `demostrado` + `derivado` |
| **F5** | Estado del registro: **0,21 MB por TiB** con 200 B/alta; la caducidad pseudoaleatoria induce **6–604 altas/día por TiB** según `κ`; un nodo doméstico lo aguanta. | `derivado` + `hipótesis` |
| **F6** | **Cambiar el formato (F3-ii o F3-iv) es la única rama que puede volver el ataque imposible ; el registro con edad y auditorías lo vuelve caro, no imposible, y no cierra el sembrador.** Lo máximo comprometible sin cambiar el formato está en §7.3. | `derivado` |

---

## 1 · Alcance, método y reconciliación obligatoria

**Qué es este informe.** Una **decisión matemática** (F2) más un **modelo pequeño** que la
cuantifica (F1, F3-F6). No se mide hardware nuevo: las cifras de `t_tabla`, `r`, `w` y el
precio del disco son **entradas** del encargo §1.3, etiquetadas y tratadas como cotas del
coste del atacante. El instrumento es la parte computable: 11 833 comprobaciones, kernel de
`0,181 ms` y **0 asignaciones** por barrido de 64 celdas, contra referencia exacta
`Rational{BigInt}`, encierre a 256 bits (ancho relativo ≈ 4·10⁻⁷⁴) y Monte Carlo con Philox
contracontador (`veritas/criptografia/cobertura-parcela-v1/INFORME.md`).

**Modelo de amenaza.** El del encargo: se asume que un ente con mucha capacidad **atacará**.
Se separa en todo momento lo que vuelve el ataque **imposible** de lo que sólo lo vuelve
**caro**, y el coste se publica en hardware (núcleos, máquinas, GPU-equivalentes), no en
moneda.

### 1.1 · Tarea de consistencia obligatoria: `235,6 h·núcleo/TiB` contra `5,84 CPU/TiB`

**No se contradicen: miden el mismo trabajo en unidades distintas.** `[derivado, verificado
contra el código de P-PERMANENCIA y reproducido en `resultados/F4-reconciliacion.tsv`]`

- **`235,6167575 h·núcleo/TiB`** es **trabajo**: `N_TiB · t_tabla`, con
  `N_TiB = 2⁴⁰/1.048.672 = 1.048.480,0088` piezas/TiB y `t_tabla = 0,809 s/tabla`
  (una tabla por pieza). `1.048.480,0088 × 0,809 = 848.220,327 s·núcleo = 235,6168 h·núcleo`.
  Fórmula literal: `e4_trabajo_nucleo_s(hw, N) = N * hw.t_tabla_s`
  (`P-ZRX/P-PERMANENCIA/.../permanencia-v1/src/modelo.jl:167`).
- **`5,838178903 «CPU»/TiB`** a `w=7.175` es una **tasa de máquinas**: cuántas máquinas
  completas (las que rinden el agregado `r = 25,03 tablas/s`) hay que sostener para regenerar
  1 TiB **una vez por ventana**. Fórmula literal:
  `e3_cpu_por_TiB(hw, w) = piezas_por_TiB(hw) / (hw.r_cpu_tablas_s * w * TAU_S)`
  (íd., `modelo.jl:115`). `1.048.480,0088 / (25,03 × 7.175) = 5,838178903`.
- **Factor exacto que las separa: `r · t_tabla = 25,03 × 0,809 = 20,249270`** núcleos-equivalentes
  por máquina. Las tres vías coinciden:
  `848.220,327 / 41.888,934 = 20,249270`; `118,218861 / 5,838179 = 20,249270`;
  `235,6168 / 11,6358 = 20,249270`.
- **El cociente «ingenuo» de las dos cifras impresas es `40,357920`**, y es
  **dimensionalmente inconsistente** (h·núcleo ÷ máquinas): vale
  `20,249270 × 7.175/3.600`, es decir, el factor puro multiplicado por las horas que dura la
  ventana. **No es un factor puro y no debe publicarse como tal.**
- **No entra ningún factor 7 ni `NUM_CHUNKS = 2¹⁵`.** Las siete tablas ChiaPos se construyen
  y se destruyen dentro de la misma llamada, que devuelve **un** objeto `Proofs<20>` de
  5,008 MiB (`P-ZRX/P-INTENTO/investigacion/INFORME.md:70-75,244-251`). Los factores erróneos
  serían `×7 = 1.649,32 h·núcleo/TiB` y `×32.768 = 7.720.690 h·núcleo/TiB`: **ninguno aplica**.
- **De dónde sale el «~20-140» del encargo:** `20,249270` es el factor exacto; `141,744890`
  sería el factor si se cargaran las siete tablas por pieza (**excluido**);
  `140,116294 = 24 × 5,838178903` es el producto por el número de hilos, no un factor de
  separación; `40,357920` es el cociente con unidades mezcladas.
- **Coherencia interna de E3:** contado en hilos de la máquina, E3 consume
  `279,2596 h·hilo/TiB = 1,185228 ×` el ideal serial de E1, y `1,185228 = 24/20,249270 = 1/0,843720`,
  exactamente la eficiencia paralela declarada (`r/(24·(1/t_tabla)) = 0,843720`).

**Tres defectos de etiqueta heredados** (no afectan al valor, sí a su lectura):
`mediciones/hardware.tsv:6` dice `s/pieza` donde es `s/tabla`; `hardware.tsv:8` y
`modelo.jl:15` dicen «16 núcleos físicos» cuando el banco usa una **piscina de 24 hilos**; y
`cpu_por_TiB` no declara que «CPU» = **máquina completa medida**, no un núcleo. Además,
`w_cruce_PiB_slots` de `E1-E4-coste.tsv` está inflado ×1,0995 por mezclar PiB con TB
decimales (`run.jl:255`), y hay filas duplicadas en `E3-ventana.tsv` por solape de la rejilla
logarítmica con valores fijos. **Ninguno toca `235,6` ni `5,84`.**

### 1.2 · Fuentes abiertas

Código del formato: `PDF/autonomys-subspace/` (`sectors.rs`, `pieces.rs`, `pos.rs`,
`segments.rs`, `subspace-verification/src/lib.rs`, `subspace-farmer-components/src/{plotting,reading,proving,auditing,sector}.rs`,
`subspace-runtime/src/lib.rs`). Encargos previos: `P-PERMANENCIA` entero, `P-SEMBRADOR`,
`P-INTENTO`, `P-CLAVE`, `P-REVELACION`, `P-ADELANTO`, `T-ZRX`. Externas abiertas:
`PDF/time-memory-tre-off-proof-space.pdf` (extraído y leído), `PDF/chia-blockchain/` (clon
local) y el greenpaper de Chia; especificación de Filecoin (`content/algorithms/pos/porep.md`,
`post.md`, `content/algorithms/sdr/_index.md`, `content/systems/filecoin_mining/sector/{sealing,adding_storage}.md`,
`proofs.md` anclado al commit `a4d9417`); protocolo de Spacemesh (`atx.md`, `nipost.md`,
`post.md`). **Lo que no se abrió va marcado `no verificado`.**

---

## 2 · F1 · La propiedad, formalizada

**[Las tres coberturas son objetos distintos y el encargo tiene razón al separarlas.]**

### 2.1 · Cobertura 1 · de los datos públicos — *existe y no sirve*

El `record_commitment` (KZG) se calcula sobre el polinomio del record (32.768 escalares) y se
abre en **una** posición con `chunk_witness`; además su hash de 254 bits se compara con la
entrada `position` del polinomio de `segment_commitment`. `[verificado en fuente]`
`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:263-269,336-345`;
`crates/subspace-archiving/src/archiver.rs:751-772`. **Por qué no sirve:** los datos son
públicos; probar su inclusión no dice nada sobre su conservación, y sobre todo no toca el
objeto que cuesta 809 ms por pieza.

### 2.2 · Cobertura 2 · del objeto caro — *no existe*

**Nada compromete la parcela como conjunto.** No hay raíz, acumulador ni compromiso sobre los
`P` records de un lote ni sobre los 65.536 s-buckets. Lo único que existe son compromisos
**por record y por segmento**, ambos sobre inclusión en el historial, y metadatos **locales
del granjero**: `s_bucket_sizes`, `pieces_in_sector` y `history_size` en `SectorMetadata`, el
`piece_checksum`, el checksum de `SectorContentsMap` y el checksum global del fichero de
sector. `SectorMetadataChecksummed` sólo aparece en `subspace-farmer` y
`subspace-farmer-components`, **no** en `subspace-verification`, `pallet-subspace` ni
`sp-consensus-subspace`. La `Solution` que ve el consenso lleva `record_commitment`,
`record_witness`, `chunk`, `chunk_witness` y `proof_of_space` — y nada más.
`[verificado en fuente]`
`subspace-farmer-components/src/sector.rs:56-65,93,139-146,313-325`;
`subspace-core-primitives/src/solutions.rs:265-275`;
`subspace-farmer-components/src/plotting.rs:608-610`.
El objeto caro —las tablas PoS y `blake3(proof)`— **no está comprometido en ningún sitio**:
`found_proofs` sólo existe como salida local del generador
(`shared/ab-proof-of-space/src/lib.rs:35-45`, **0 coincidencias** en
`subspace-farmer-components`).

### 2.3 · Cobertura 3 · la forma almacenada — *no se prueba ni para un chunk*

En disco el chunk está enmascarado: `plotting.rs:661` escribe
`raw_chunk XOR proof.hash()` (o `[0; 32]` donde no hay prueba). Al leerlo se desenmascara
(`reading.rs:243-244`) y **el verificador recibe el chunk ya desenmascarado y vuelve a
enmascararlo él**: `masked_chunk = solution.chunk XOR proof_of_space.hash()`
(`subspace-verification/src/lib.rs:248-249`). **El valor de disco no se recibe ni se acredita
en ningún punto del consenso.** No hay proof-of-retrievability ni reto-respuesta: la solución
la autogenera el granjero localmente (`auditing.rs:113-186`) y el nodo sólo valida álgebra.
Además el chunk es recuperable por erasure coding desde la mitad del record
(`proving.rs:278-285`). `[verificado en fuente]`
**Consecuencia:** que el granjero tenga el chunk **codificado en disco** no se demuestra; se
demuestra que conoce el chunk del codeword comprometido y un PoS válido.

### 2.4 · Las dos dimensiones temporales, y qué pide A1+C1

- **Preexistencia**: que los bytes existieran en `t − M`. Hoy **nada** la acredita.
  `SectorId = blake3_keyed(public_key_hash; [sector_index, history_size])`
  (`sectors.rs:61-67`) liga clave, índice e historia; `derive_evaluation_seed` liga
  `(sector_id, piece_offset)` (`:126-129`); `derive_piece_index` liga offset e historia
  (`:70-114`). **Ninguno de los tres fecha un cómputo.** Y `altura_ploteo` **no está** en el
  prefijo cerrado de `SPEC.md:825-845`: identifica el prefijo histórico, no el instante.
- **Vinculación**: que los bytes sean de *esa* clave y *esa* parcela. **Parcialmente sí**:
  `SectorId` liga la clave y el `piece_offset` liga la pieza, pero **no hay alta previa**: no
  existe registro de sectores en cadena. `verify_solution` **deriva** el `sector_id` de la
  propia solución y no lo contrasta con nada (`lib.rs:211-216,228-232`); sí hay un mapa de
  votantes con clave `(PublicKey, SectorIndex, PieceOffset, ScalarBytes, Slot)` para
  deduplicar votos (`pallet-subspace/src/lib.rs:495-502`), que **no** es un registro de la
  parcela. `sector_index` es un `u16` sin cota de rango comprobada en `verify_solution`.
  `[verificado en fuente]`

**Qué pide A1+C1, campo por campo.** A1 —antigüedad demostrable— pide **cobertura 2 + 
vinculación + preexistencia**; C1 —encarecer el intento dirigido— pide que la candidatura
dependa de todos los registros, lo que sin cobertura 3 es sólo una **tarifa**. La cobertura 1
ya está dada y no aporta. **Resumen: A1+C1 = {2, 3, preexistencia, vinculación}; el formato
sólo da {1} y una parte de vinculación.**

---

## 3 · F2 · El teorema que faltaba

### 3.1 · Enunciado

> **Teorema (imposibilidad de la preexistencia para un objeto público y paralelizable).**
> Sea `O = (O₁,…,O_N)` con `O_i = F(clave, i, historia)`, `F` determinista, pública y
> eficiente; sea el reto de auditoría conocido con `w ≥ 0` slots de antelación y plazo `D_a`;
> sea `R` la tasa a la que un adversario computa unidades de `F`; sea `t_unidad` el coste de
> una unidad en un núcleo estricto.
> Consideremos cualquier sistema de prueba `(P, V)` que cumpla:
> **(A)** *completitud*: el probador que almacena `O` y sigue el protocolo es aceptado;
> **(B)** *verificación sucinta*: `V` recibe `o(N)` bytes, no lee las `N` unidades;
> **(C)** *respuesta funcional*: la respuesta de `P` es función del reto y de las unidades que
> la prueba abre.
> Entonces existe un adversario que **no almacena `O`** y produce un transcripto aceptado,
> siempre que el trabajo que la prueba exige materializar quepa en la ventana:
> `M_min · t_unidad ≤ R · (w·τ + D_a)`. En particular, si `k · t_unidad ≤ R·(w·τ + D_a)`,
> ninguna prueba sucinta distingue «almacenado» de «regenerado dentro del plazo».

### 3.2 · Demostración

**Por simulación, y sin ninguna suposición de dureza.** Construimos el simulador `S`: dado el
reto `c` (público desde `t − w`) y los parámetros públicos `(clave, índice, historia)`,
`S` computa con `F` **exactamente** las unidades que `(P,V)` exige materializar y ejecuta el
algoritmo del probador honesto sobre ellas. Como `O_i = F(·)` es determinista y pública, las
unidades que obtiene `S` son **bit a bit** las del honesto: `plotting.rs:626-627` deriva la
tabla PoS de `pos_seed`, y `:659-665` produce el chunk enmascarado de forma determinista, sin
aleatoriedad adicional. Por (C) el transcripto de `S` coincide con el del honesto y, por (A),
`V` acepta. Las dos distribuciones de transcriptos son **idénticas**, así que ninguna `V`
—sucinta o no— puede separarlas con ventaja no nula. `S` cabe en la ventana exactamente
cuando `M_min·t_unidad ≤ R·(w·τ + D_a)`. ∎

**Corolario 1 (la imposibilidad es información-teórica, no computacional).** No se apoya en
que `F` sea difícil de invertir ni en ninguna hipótesis de dureza: los transcriptos son
iguales. Ninguna mejora de hardware crea la distinción; ninguna hipótesis criptográfica la
destruye.

**Corolario 2 (las únicas salidas son romper una hipótesis).**
**(i)** `R·(w·τ + D_a) < t_unidad` — latencia por debajo del tiempo de una unidad.
**(ii)** `F` tiene profundidad secuencial no paralelizable mayor que `w·τ + D_a`.
**(iii)** la prueba obliga a materializar `M_min` unidades **a la vez** con
`M_min·t_unidad > R·(w·τ + D_a)`.
**(iv)** `F` no es pública o no es determinista.

**Corolario 3 (por qué (i)-(iii) no cierran por principio).** (i), (ii) y (iii) son
desigualdades sobre `R`, `w`, `D_a` y `t_unidad`. Con el modelo de amenaza obligatorio —un
adversario con mucha capacidad y sin el argumento «no compensa»—, `R` no está acotada: para
**cualquier `N`** existe un `R` que satisface la desigualdad. Son **cotas de coste**, no
separaciones. Sólo (iv) cambia la naturaleza del objeto y rompe la simulación.

**Corolario 4 (por qué un compromiso no puede fechar nada).** Todo predicado sobre el **valor**
de `O` es invariante en el tiempo: `O` vale lo mismo se compute en `t₀` o en `t₀+M`. Por
tanto cualquier compromiso a `O` —raíz Merkle, KZG, acumulador— es consistente con haberlo
computado en cualquier instante, y **no puede acreditar preexistencia**. Para fechar hace
falta algo que **varíe con el tiempo y esté ligado al cómputo honesto**: exactamente el
«trabajo fresco, no reutilizable y ligado a la ancestría» que `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md`
§A.1 identifica como la propiedad necesaria. Esto es lo que convierte (ii) y (iv) en las
únicas salidas estructurales.

### 3.3 · Aplicación al formato fijado: por qué la respuesta es NO

| Hipótesis | ¿Se cumple en el formato fijado? | Evidencia |
|---|---|---|
| H1 determinista y público | **Sí** | `plotting.rs:626-627,659-665`; `sectors.rs:61-67,126-129` |
| H2 paralelizable por unidad | **Sí** | `generate_parallel` por pieza; agregado medido `r = 25,03` |
| H3 reto conocido con `w>0` | **Sí**, `w ∈ [7.175; 8.030]` sin VDF; `4.830,6` con VDF | `P-REVELACION:47-48,84`; `P-ADELANTO:45` |
| H4 verificación sucinta | **Sí** | `lib.rs:211-216,248-249,263-269` |
| (i) latencia | **No disponible**: `w` es estructural (publicidad del PoT) y `D_a` es de consenso; exigir `D_a < 0,809 s` con bloques de 6 s (`BlockSlotCount = 6`, `SLOT_DURATION = 1000`, `subspace-runtime/src/lib.rs:145,282`) no es viable | `[derivado]` |
| (ii) secuencial | **No la tiene hoy**: el ploteo es paralelo; imponerla exige un sellado nuevo | §4.2 |
| (iii) materializar `N` a la vez | **No disponible por el compromiso**: el formato no impone materializar nada simultáneamente y el PDF no lo respalda | §4.3 |
| (iv) no regenerable | **No**: la semilla es pública | `plotting.rs:400` |

**Veredicto: NO PUEDE EXISTIR** una prueba sucinta de preexistencia para el formato fijado sin
cambiarlo. **Y la parte de cobertura sí es construible**: el compromiso del objeto caro
(§7.3) es un problema de ingeniería, no de imposibilidad. **Cobertura ≠ preexistencia.** El
encargo pedía las dos juntas; la primera se puede, la segunda no.

**Un matiz que se declara y no se esconde:** si se acota el paralelismo del adversario a
`R_max`, la imposibilidad se vuelve **cuantitativa** y se sostiene mientras
`N > (w·τ + D_a)·R_max`; para lotes menores que `B = (w·τ+D_a)·R_max` el adversario de una sola
máquina regenera el lote entero y **no hay nada que detectar**. Las dos formas del resultado se
publican juntas en `F4-frontera.tsv`.

---

## 4 · F3 · El precio de romper cada hipótesis, en ESTE formato

### 4.1 · (i) Latencia — **no está disponible; y no es una propiedad de la prueba**

- **Qué habría que cambiar.** Sólo parámetros de consenso: `D_a` y/o `w`. Ficheros:
  `subspace-runtime/src/lib.rs` (parámetros), `SPEC.md` (no tocado en este encargo). **No basta
  añadir un compromiso.**
- **Coste para el honesto.** Ninguno extra: ya responde.
- **Qué abre de nuevo.** Exigir `D_a < 0,809 s` choca con un bloque cada 6 s
  (`BlockSlotCount = 6`) y con que el reto es público `w ≈ 7.175` slots antes. Para que (i)
  funcione habría que **eliminar el adelanto** (`w = 0`), que es justamente lo que el PoT
  público da y lo que P-REVELACION mide. Centralización: una red doméstica no puede sostener
  plazos de sub-segundo.
- **¿Conserva el formato fijado?** **En la parcela sí** (no se toca el objeto ploteado), pero
  **no en el consenso**: exige cambiar la revelación del reto, que es el mecanismo que produce
  `w`. No es una vía práctica.

### 4.2 · (ii) Coste secuencial no paralelizable — **disponible, y cambia la parcela**

- **Qué habría que cambiar.** El **objeto ploteado**: `subspace-farmer-components/src/plotting.rs`
  (la generación por pieza tendría que pasar de `generate_parallel` a una ruta con cadena
  secuencial ligada a un ticket previo), `shared/ab-proof-of-space` / `crates/subspace-proof-of-space`
  (la tabla), y `subspace-verification/src/lib.rs` (una prueba nueva). Precedente abierto:
  Filecoin PoRep publica `SealedCID`/`CommR` en `PreCommitSector` y exige que el
  `ProveCommit` ocurra **después** del `InteractiveEpoch`, 150 bloques después, con la
  aleatoriedad interactiva como reto, «a boundary established to make sure Miners don't have
  enough time to *fake* PoRep generation». `[no verificado en el cuerpo de rust-fil-proofs:
  no se abrió; la cita es de `adding_storage.md` y `porep.md` de la especificación]`
- **Coste para el honesto.** Alta lenta (horas por lote, no segundos), memoria temporal,
  prueba sucinta y verificación que **no** puede repetirse por sector. Además **rompe la
  regeneración determinista por terceros** y con ella la lógica de expiración existente: la
  caducidad pseudoaleatoria actual (`sectors.rs:144-156`) asume que un sector se replotea y
  caduca por `blake3(sector_id ‖ segment_commitment)`, algo que sólo tiene sentido si el
  ploteo es reproducible.
- **Qué abre de nuevo.** Ventaja ASIC/GPU en la ruta secuencial, y una **capa nueva de
  confianza** (el circuito de la prueba).
- **¿Conserva el formato fijado?** **NO.** Es la vía estructural, y su precio es replotear la
  red y rediseñar `proof_of_space`.

### 4.3 · (iii) Materializar las `N` unidades a la vez — **no cierra sola, y el PDF no la respalda**

- **Qué habría que cambiar.** Añadir un compromiso sobre la parcela en
  `plotting.rs`/`sector.rs` y una comprobación en `subspace-verification/src/lib.rs`. **Basta
  añadir un compromiso** para tener la *cobertura* del objeto caro, y eso **sí** se puede.
- **Lo que NO consigue.** La cobertura **no** obliga a materializar nada: el adversario puede
  computar el objeto y el compromiso dentro de la misma ventana. Para que (iii) cerrara
  haría falta una cota **inferior de tiempo en función del espacio** —un compromiso
  espacio-tiempo— y el PDF que el encargo manda abrir da `T·S² ∈ Ω(ε²N²)` (Teorema 2,
  pág. 14), que es una cota sobre el **número total de consultas al oráculo**, no sobre
  latencia; el modelo **no postula no-paralelizabilidad** (la única aparición de «sequential»
  describe el ataque de Hellman, pág. 8) y **no obliga a materializar `N` a la vez**. Además
  `research/time-memory-tradeoff.md:63-77` avisa de que la generalización a `k` tablas
  **no está probada** en el paper, y chiapos usa **siete** tablas: la extrapolación está
  «anunciada, no probada aquí». `[verificado en el PDF local + en el documento de research]`
  Conclusión: **(iii) es cuantitativa y es la misma desigualdad que (i)**; el compromiso
  espacio-tiempo la sostendría *si* existiera una instancia probada para este formato, y **no
  existe**.
- **Coste para el honesto.** Una raíz sobre el plot (hashear ~1 TiB una vez) y una apertura
  por auditoría. Bajo.
- **¿Conserva el formato fijado?** **Sí en la parcela** (no cambia lo que se plotea), pero
  **no sirve para F2**: sólo aporta la cobertura 2, no la preexistencia.

### 4.4 · (iv) Contenido no públicamente regenerable — **disponible, y cambia la parcela**

- **Qué habría que cambiar.** La **semilla**: `sectors.rs` (`SectorId` / `derive_evaluation_seed`)
  y `plotting.rs` (`plot_seed`), para que la tabla dependa de un secreto del granjero.
  Precedente abierto: Filecoin usa
  `ReplicaID = SHA254(proverID ‖ sectorID ‖ R_ReplicaID ‖ CommD ‖ PoRepID)` con `R_ReplicaID`
  «unique random value for each `ReplicaID`» (`content/algorithms/sdr/_index.md`).
  `[verificado en la especificación abierta]`
- **Coste para el honesto.** El plot deja de ser regenerable por un tercero: se pierde la
  propiedad que hoy permite restaurar un sector desde `(public_key, sector_index, history_size)`
  y el historial. **El secreto hay que conservarlo durante toda la vida del plot**: perderlo
  es perder el plot. Y **rompe la lógica de expiración**: `blake3(sector_id ‖ segment_commitment)`
  seguiría funcionando, pero el reploteo tras la caducidad exigiría el secreto.
- **Qué abre de nuevo.** Claves que hay que custodiar (backup, riesgo de pérdida), y **no
  prueba persistencia** —Filecoin sigue necesitando PoSt y su `WindowPoSt` es explícitamente
  un argumento económico (`post.md`: «makes it irrational for a miner to *not* keep a sealed
  copy»)—.
- **¿Conserva el formato fijado?** **NO.** Cambia el objeto ploteado.

### 4.5 · Comparación con los esquemas abiertos

| Esquema | ¿Compromiso a todos los bytes antes del reto? | (i) latencia | (ii) secuencial | (iii) `N` a la vez | (iv) no regenerable | ¿Prueba persistencia? |
|---|---|---|---|---|---|---|
| **Filecoin PoRep/Seal** | **Sí**: `SealedCID`/`CommR` en `PreCommitSector`; reto 150 bloques después | Parcial (ventana de `WinningPoSt`, parametrizada) | Afirmado por diseño (DRG, «sequential and regeneration resistant»); sin cota formal (`dashboardAudit: wip`) | No lo exige | **Sí** (`R_ReplicaID`) | **No**: `WinningPoSt` por plazo, `WindowPoSt` «irrational», no criptográfico |
| **Spacemesh ATX + ni-post** | **Sí**: raíz Merkle de la tabla inicial; retos posteriores = salida PoET | No (la duración es trabajo secuencial) | **Sí**, como trabajo secuencial verificable (PoET) | No | En parte | **No**, y lo declara: «the protocol does not allow a prover to prove they *stored* the data» (`post.md` l.9) |
| **Chia (plot filter, `plot_id`)** | **No**: el `plot_id` es `std_hash(pool_public_key ‖ plot_public_key)`, público y sin compromiso de bytes | No (filtro 1/512, retos cada 9.375 s) | No | No | **No**: contenido determinista desde un `plot_id` público | **No**: el greenpaper admite el *replotting* como ataque real |
| **TMTO (PDF local)** | N/A (es una cota, no un protocolo) | No | **Sólo coste agregado** | **No** | No (oráculos públicos) | No |

**Lo que esta tabla dice para ZEROX:** los dos esquemas desplegados que sí comprometen todos
los bytes antes del reto **también** tienen que apoyar la persistencia en un argumento
temporal o económico. **Ninguno prueba preexistencia criptográficamente.** Y Chia, que es el
pariente directo de la parcela Autonomys, **no compromete bytes en absoluto**.

---

## 5 · F4 · La frontera cuantitativa

### 5.1 · El modelo y su frontera exacta

Notación: `N` unidades en el lote; `k` aperturas por auditoría; `B` unidades que el adversario
puede regenerar **dentro de la ventana** `w·τ + D_a`; `M` unidades que omite; `X` = número de
unidades omitidas entre las `k` abiertas, `X ~ Hipergeométrica(N, M, k)`.

> **Frontera (combinatoria, exacta, sin aproximación).**
> `P(X > B) = 0  ⟺  M ≤ B  ó  k ≤ B`.
> Por tanto el **almacenamiento forzado** —la fracción que hay que conservar para que ninguna
> auditoría de `k` aperturas detecte nada— es
> **`almacenamiento_forzado(N, B) = max(0, 1 − B/N)` si `k > B`, y `0` si `k ≤ B`.**
> **Es independiente de `k` en el régimen `k > B`.** `[demostrado]`

Demostración en dos líneas: si `M ≤ B` entonces `X ≤ M ≤ B`; si `k ≤ B` entonces `X ≤ k ≤ B`;
y si `M > B` y `k > B`, la probabilidad de que las `k` abiertas incluyan `B+1` de las omitidas
es estrictamente positiva. El instrumento lo comprueba contra la fórmula exacta en **4.953
casos** (`resultados/TEST.txt`).

**Consecuencia de diseño, y es la que decide:** `k` **no mueve** la frontera. Sólo la mueven
`B = R·(w·τ + D_a)`, `N`, y el hardware del adversario. Subir `k` sólo compra **probabilidad**
de detección por debajo de la frontera, a costa de I/O del honesto.

### 5.2 · La frontera en los escenarios medidos

`resultados/F4-frontera.tsv`, con `N = 1.048.480` (1 TiB), `D_a = 60 s`, `r = 25,03`,
`t = 0,809`.

| Escenario | `w` [slots] | `B` [unidades] | `almacenamiento_forzado` | `k = 1.000` | `k = 100.000` | `k = 1.000.000` | `k = N` |
|---|---:|---:|---:|---|---|---|---|
| sin VDF | 7.175 | 181.092 | **82,73 %** | **no detectable** | **no detectable** | φ_γ = 81,91 %, `T(10⁻³) = 676` | φ_γ = 82,73 %, `T = 1` |
| con VDF (`ρ=2,5`) | 4.830,6 | 122.411 | **88,32 %** | **no detectable** | **no detectable** | φ_γ = 87,78 %, `T = 681` | φ_γ = 88,32 %, `T = 1` |
| tope histórico | 8.030 | 202.492 | **80,69 %** | **no detectable** | **no detectable** | φ_γ = 79,77 %, `T = 669` | φ_γ = 80,69 %, `T = 1` |
| `w = 1` (hipotético) | 1 | 1.526 | **99,85 %** | **no detectable** | φ_γ = 98,56 %, `T = 684` | φ_γ = 99,85 %, `T = 661` | φ_γ = 99,85 %, `T = 1` |

**El resultado que decide, y es incómodo:** con el `w` medido y **una sola** máquina
adversaria, **una auditoría que abra `k ≤ 181.092` posiciones de un lote de 1 TiB no puede
detectar absolutamente nada**, almacene el tramposo lo que almacene. `k = 1.000` y
`k = 100.000` están ambos por debajo. Para que la detección exista hay que pedir
`k > B`, es decir, **más de 181.092 aperturas por TiB y por auditoría** — el **17,3 % del lote
entero**. Ese es el precio, en I/O del honesto, de tener cualquier detección:
`181.092 lecturas / 60 s ≈ 3.018 lecturas/s` por TiB, que un SSD sirve y un HDD doméstico
(≈ 100 lecturas/s) no. **El adelanto `w` es lo que multiplica ese precio por `(1 + w·τ/D_a) ≈ 120`.**

**`B` no crece con `N`.** El número absoluto de posiciones que hay que abrir lo fija el
adversario (`B`), no el tamaño del lote. Por eso el coste **relativo** de auditar cae con el
tamaño del lote: `k/N = 17,3 %` para 1 TiB, `0,17 %` para 100 TiB. **Los lotes grandes son
auditables y los pequeños no.** Es la conclusión de diseño más útil de F4.

### 5.3 · Detección más allá de la frontera

Por debajo de la frontera la detección existe, pero es **carísima**.
`resultados/F3-deteccion.tsv`, `N = 1.048.480`, `k = 1.000`, `B = 25` (`w = 1`, `D_a = 0`):

| φ almacenado | `M` omitidas | `p` por auditoría | auditorías para 1−β = 99,9 % |
|---:|---:|---:|---:|
| 0,90 | 104.848 | 1,0 | 1 |
| 0,98 | 20.970 | 1,098·10⁻¹ | 61 |
| 0,99 | 10.485 | 1,541·10⁻⁵ | ≈ 448.000 |
| 0,999 | 1.048 | 5,176·10⁻²⁸ | ≈ 1,3·10²⁷ |
| 0,9999 | 105 | 5,878·10⁻⁵⁵ | astronómico |

**Traducción:** un tramposo que almacena el **99 %** del lote es detectable con probabilidad
`1,5·10⁻⁵` por auditoría. La frontera (`1 − B/N = 99,998 %`) es la frontera de la
**posibilidad**, no la de la **practicabilidad**. Entre ambas hay un abismo de 3 órdenes de
magnitud en almacenamiento. Cualquier diseño que se apoye en «detectable» debe fijar `k` y `γ`
juntos, y ninguna de las dos cosas se fija en este encargo.

**Certificación (`resultados/certificado.tsv`).** Los puntos que deciden están encerrados con
redondeo dirigido a 256 bits, ancho relativo ≈ 3·10⁻⁷¹. La frontera práctica del caso
`N=1.048.480, k=10⁶, B=181.092` se certifica en `M = 189.670` (`p = 9,8712·10⁻³ < γ`) contra
`M = 189.671` (`p = 1,0181·10⁻² ≥ γ`). El kernel `Float64` es un **criba rápida**: en dos
celdas su valor cae fuera del encierre por 10⁻¹⁰ relativo, y el artefacto se declara y se
recorta (`0,181 ms`, 0 asignaciones, 64 celdas; `BENCH.txt`).

### 5.4 · Coste absoluto del tramposo y cruce con el precio del disco

`resultados/F4-coste.tsv`.

| Modo | Magnitud | Valor | Etiqueta |
|---|---|---:|---|
| **Farmear regenerando el lote** | núcleos/TiB | **117,238** | derivado |
| | máquinas/TiB (agregado `r`) | 5,790 | derivado |
| | GPU/TiB (17×) | **6,896** | **hipótesis, NO medida** |
| | energía regenerar | **15,315 kWh/TiB/ventana** | hipótesis (65 W/núcleo) |
| | energía almacenar | 0,010 kWh/TiB/ventana | hipótesis (5 W/TiB) |
| | **razón** | **1.524×** | derivado |
| **Sólo responder auditorías (E2)** | s·núcleo por auditoría | **809,0** | derivado |

**El tramposo que sólo responde a auditorías no paga por `N`**: `k · t_unidad` por auditoría,
independiente del tamaño del lote y del TiB ahorrado. Es el colapso de E2, y aquí aparece
como una propiedad de la frontera (`k ≤ B` ⇒ nada que detectar). **Sólo el tramposo que sigue
farmando paga `N·t_unidad` por ventana.**

**Cruce con el precio del disco.** Para ahorrarse 1 TiB hay que sostener `nucleos_por_TiB`
núcleos durante toda la ventana; igualando el precio del hardware al del TiB:
`w + D_a/τ = N_TiB · t_unidad · (precio_núcleo / precio_TiB)`. Es **independiente de la
capacidad** y reproduce la cifra de P-PERMANENCIA cuando la razón de precios vale 1:

| Razón de precio núcleo/TiB | `w` de cruce [slots] | con GPU 17× [slots] |
|---:|---:|---:|
| 0,1 | 84.762 | 4.929 |
| 0,5 | 424.050 | 24.888 |
| **1,0** | **848.160** (≈ 9,8 días) | **49.835** |
| 2,0 | 1.696.381 (≈ 19,6 días) | 99.731 |

**Advertencia que corrijo del encargo y de P-PERMANENCIA:** el trabajo por TiB **no depende de
`w`** (el adversario regenera el lote **cada ventana**, porque la semilla de la tabla no cambia
con el slot y no lo almacena). La energía es por tanto **invariante en `w`** y **nunca** cruza:
regenerar cuesta ~1.524× la energía de almacenar a **cualquier** `w`. Lo que el `w` grande
reduce es el **paralelismo exigido**, es decir, el número de máquinas que hay que **comprar**.
El `w ≈ 8,4·10⁵` de P-PERMANENCIA es un **cruce de sustitución de hardware** («una máquina
fabrica en la ventana lo que un disco guarda»), con la hipótesis de que un núcleo y un TiB de
disco cuestan lo mismo; **no es un cruce energético ni económico en el sentido de «sale más
barato fabricar»**. Con solo el coste marginal (hardware ya comprado), **regenerar nunca sale
más barato**.

---

## 6 · F5 · El coste del registro

`resultados/F5-registro.tsv`. Lo que `P-ZRX/P-PERMANENCIA/` dejó `no determinado`.

**Lo que el formato ya fija, verificado en fuente:**
`MIN_SECTOR_LIFETIME = 4` segmentos (`subspace-runtime/src/lib.rs:190`);
`SLOT_DURATION = 1000 ms`, `BlockSlotCount = 6` (íd., `:145,282`);
`MAX_PIECES_IN_SECTOR = 1000` (íd., `:125`); `ArchivedHistorySegment::NUM_PIECES = 256`
(`segments.rs:546`). La expiración es
`expires_in = (blake3(sector_id ‖ segment_commitment) mod 3·h)` medida desde
`h + min_sector_lifetime`, es decir, **uniforme en `[min, min+3h)` segmentos** con media
`min + 1,5h`, y el tope `min + 4h` es **exclusivo**. `[verificado en fuente]`
`sectors.rs:141-156`. **Es determinista y pública**: depende de `sector_id` y del compromiso
de segmento, no de un secreto.

**Modelo (entradas: `κ` segmentos/slot y `h` segmentos; `200 B/alta` es hipótesis).**

| Magnitud | Valor | Etiqueta |
|---|---:|---|
| Sectores por TiB (`MAX_PIECES_IN_SECTOR = 1000`) | **1.049** | derivado |
| Bytes por alta (7 campos de §1 de `CANDIDATA.md` + firma) | ≈ 200 B | **hipótesis** |
| Estado en cadena por TiB | **0,21 MB** | derivado |
| Estado por PiB | ≈ **215 MB** | derivado |
| Altas/día por TiB, `κ = 10⁻³`, `h = 10⁴` | 6,0 | derivado |
| Altas/día por TiB, `κ = 10⁻²`, `h = 10⁴` | 60,4 | derivado |
| Altas/día por TiB, `κ = 10⁻¹`, `h = 10⁴` | **604,1** | derivado |
| Fracción de capacidad inactiva por la edad `M = 7.175` slots, `κ=10⁻¹`, `h=10⁴` | **4,78 %** | derivado |
| íd. con `κ = 10⁻³`, `h = 10⁶` | 0,0005 % | derivado |

**¿Lo aguanta un nodo doméstico?** **Sí, y con margen.** El estado acumulado es del orden de
**0,21 MB por TiB** de parcela registrada: 1 PiB de red son ≈ 215 MB, muy por debajo de
cualquier estado de cadena serio. La tasa de altas depende linealmente de `κ` y del número de
sectores, no de los bytes: **604 altas/día por TiB** en el escenario más agresivo del barrido.
El coste real del registro no es el estado, es **la fracción de capacidad que queda inactiva
durante la maduración**: con `M = 7.175` slots y una vida de sector de 150.040 slots
(`κ=10⁻¹`, `h=10⁴`), es el **4,78 %**; con vidas largas es despreciable. **El riesgo del
registro no es el nodo, es que `M` tenga que ser grande**: `P-ZRX/P-REVELACION/investigacion/DECISIONES-PENDIENTES.md:69-73`
concluye que **ningún `sup` finito sirve** y que `M` debe escribirse como un cuantil, lo que
empuja `M` hacia arriba y con él la capacidad inactiva.

**Lo que no se fija aquí:** `κ`, `h`, `M`, el tamaño de bloque, ni el formato de la entrada.
Todos son entradas.

---

## 7 · F6 · El veredicto

### 7.1 · Las tres ramas, con su coste

| Rama | Qué cierra | Coste | ¿Conserva el formato? |
|---|---|---|---|
| **A · Seguir por el registro, sin cambiar el formato** (`PlotBatchId` + edad + auditorías) | **Nada por principio.** Vuelve el ataque **caro y observable**: `117,2 núcleos/TiB` continuos, ~`1.524×` la energía de almacenar. No cierra el sembrador. | Estado de cadena trivial (0,21 MB/TiB); capacidad inactiva `M/T_vida`; **y auditorías con `k > B ≈ 181.092` por TiB**, que un HDD doméstico no sirve | **Sí** |
| **B · Cambiar el formato de parcela** (F3-ii sellado secuencial, o F3-iv semilla secreta, + raíz del plot) | **Es la única rama que puede volver el ataque imposible por principio**: (iv) rompe la simulación; (ii) impone un suelo de latencia | Replotear la red; `proof_of_space` nuevo; se pierde la regeneración determinista por terceros; hay que custodiar un secreto (iv) o confiar en un circuito (ii) | **No** |
| **C · Aceptar el agujero** | Nada; se declara | Ninguno | **Sí** |

**Recomendación propia, no decisión de Katana `[propuesto]`:** la rama **A+B parcial** —registrar
la parcela completa (cobertura 2, que **sí** es construible), conservar el formato para las
parcelas existentes, y **no** prometer que el registro acredita preexistencia—. La rama B sólo
merece la pena si Katana acepta replotear la red; la rama C es honesta pero deja el sembrador
abierto. **Lo que no se puede es seguir esperando una prueba de cobertura que acredite
preexistencia: no va a llegar para este formato.**

### 7.2 · Por qué el registro no cierra el sembrador, dicho sin palabras de cobertura

El sembrador hace tres cosas: (1) elige `(clave, sector_index, history_size)`; (2) regenera las
piezas que le interesan; (3) descarta. El registro con edad le obliga a **poseer el lote
durante `M`** y las auditorías le obligan a **responder sobre el lote entero cada periodo**.
Con eso pasa de pagar `0` a pagar `N·t_unidad` por ventana (o almacenar). **Pero**: la
preexistencia de los bytes sigue sin acreditarse, así que un atacante que **pueda** pagar
`117,2 núcleos/TiB` continuos —o `5,79` máquinas por TiB, o `6,9` GPU-equivalentes por TiB en
el escenario 17× no medido— **sigue sembrando**. Y con `k ≤ B` **ni siquiera paga la
detección**: no hay auditoría posible. **El registro convierte el sembrador en un problema de
factura, no de imposibilidad.** Eso es exactamente lo que `P-SEMBRADOR` ya decía y lo que este
encargo confirma por la vía estructural.

### 7.3 · Lo máximo que sí se puede comprometer, sin palabras de cobertura

**Se puede comprometer, y es construible hoy (no requiere cambiar lo que se plotea):**

1. Una **raíz de los bytes almacenados** —los chunks enmascarados `chunk XOR blake3(proof)` y
   los `blake3(proof)` por bucket ocupado— con Merkle o KZG. El granjero puede calcularla:
   los bytes están en disco (`plotting.rs:659-665`). `[propuesto; coste ≈ un hash del plot]`
2. La **cardinalidad** (`pieces_in_sector`, `s_bucket_sizes`) y la **versión** del formato.
3. La **identidad**: clave, `sector_index`, `history_size`, **dominio de red** y **época de
   registro**. Los cuatro primeros ya están ligados por `SectorId` (`sectors.rs:61-67`); el
   dominio y la época **no existen hoy** y son parte de la propuesta de `CANDIDATA.md` §1.
4. El **calendario de auditoría** y la ligadura de cada solución al lote
   (`TicketId = H(dominio, slot, PlotBatchId, sector_index, piece_offset)`).

**Qué elimina eso, exactamente:** la **suplantación entre lotes** —que un lote registrado
responda con los bytes de otro— y la ambigüedad sobre **qué** objeto se audita. Convierte la
obligación de permanencia en algo **medible**.

**Qué NO elimina: nada del ataque de regeneración.** El objeto es función determinista y
pública de `(clave, índice, historia)`, así que la raíz es calculable **en cualquier
instante**: el compromiso no fecha nada (Corolario 4). Un sembrador que registre la raíz
correcta **sin haber almacenado nunca** produce un registro válido. **La fracción del ataque
que el registro elimina es 0 para el sembrador**; lo que elimina es la posibilidad de
**reclamar** un lote cuyos bytes nunca se computaron, que es una operación **distinta** de la
que el sembrador necesita. Decirlo de otro modo —«el registro protege la parcela»— sería
exactamente el vocabulario de cobertura que el encargo prohíbe.

**Lo único que mueve la aguja del sembrador** es (a) acortar `w`, que es estructural y no está
en la parcela, o (b) cambiar el objeto ploteado (F3-ii o F3-iv).

---

## 8 · Lo que esta investigación NO resuelve

- **El valor real de `w`.** Es una banda medida `[7.175; 8.030]` sin VDF y `4.830,6` con VDF a
  `ρ=2,5`; el modelo barre `1 … 10⁶`. Toda la frontera depende de él.
- **El coste mínimo del ataque.** `r = 25,03` es cota **superior** del rendimiento demostrado
  del código publicado; SIMD, GPU y ASIC **no están medidos**. Y `r` sale de la ruta
  **paralela**, mientras la ruta no paralela tiene un SIGSEGV reproducible: si ZEROX hereda
  `ab-proof-of-space`, hereda el fallo.
- **La GPU.** El `17×` es **documentación ajena, nunca medida**. Entra con fila propia; si se
  confirma, el coste por TiB cae a `6,9` GPU/TiB y la cota económica se erosiona.
- **Si (ii) es realizable en este formato.** No se ha diseñado ni medido un sellado secuencial
  para la tabla de chiapos; el precedente de Filecoin existe, pero su cota de secuencialidad
  está **afirmada por diseño** y la especificación marca `dashboardAudit: wip`.
- **Si (iv) es compatible con la expiración.** Introducir un secreto en la semilla cambia qué
  significa «regenerar un sector» y afecta a la restauración desde el historial; no se ha
  analizado la migración.
- **El `(k, γ, D_a, P)` que un granjero doméstico sostiene** con `k > 181.092` por TiB. Sólo se
  ha comparado con IOPS nominales de HDD/SSD heredados, no medido.
- **El coste de la prueba** en (ii)/(iv): tamaño, probador, verificador, memoria. **No
  determinado**: no existe el diseño.
- **`π_DAG` y la varianza de pago** del DAG de ZEROX.
- **La verificación en el cuerpo** de PDP/PoR y de la implementación de Filecoin: la
  especificación se abrió; `rust-fil-proofs` **no**. Las cifras de sellado de Filecoin no se
  citan.
- **`κ`, `h`, `M`, el tamaño de bloque y `ρ_ret`**: entradas, no fijadas aquí. Los 200 B por
  alta son hipótesis.

---

## 9 · Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-COBERTURA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
cd P-ZRX/P-COBERTURA/investigacion/veritas/criptografia/cobertura-parcela-v1
./correr-modelo.sh          # tests + barridos + benchmarks + JET  (≈ 90 s, 4 hilos)
```

El depósito de paquetes de Julia (`investigacion/.julia-depot`, ~296 MB de caché de
precompilación) **no forma parte del entregable**: se retiró para respetar el presupuesto de
disco declarado de 256 MiB, y la primera corrida lo recrea automáticamente (verificado). El
presupuesto declarado cubre los **artefactos de cálculo**, no la caché de un entorno
reproducible.

Artefactos: `resultados/F4-frontera.tsv`, `F4-coste.tsv`, `F4-reconciliacion.tsv`,
`F3-deteccion.tsv`, `F3-exacto-racional.tsv`, `certificado.tsv`, `F5-registro.tsv`,
`VALIDACION.txt`, `BENCH.txt`, `JET.txt`. Hipótesis falsables:
`veritas/criptografia/cobertura-parcela-v1/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
Bitácora y huellas: `PROGRESO.md`. Bifurcaciones para Katana: `DECISIONES-PENDIENTES.md`.
