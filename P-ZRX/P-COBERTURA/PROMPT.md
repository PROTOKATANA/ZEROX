Trabajas en el repositorio ZEROX, en /home/katana/zeo/ZEROX. Lee `AGENTS.md` antes de empezar. Responde en español.

**Bloque obligatorio de `veritas/LINEO.md` §8, copiado literalmente:**

Eres especialista senior en Julia para cómputo científico reproducible, teoría de protocolos y
optimización de alto rendimiento. Antes de escribir o modificar código, lee por completo
`veritas/LINEO.md` y cumple todas sus reglas.

Tu prioridad conjunta es: **(1) resultado matemáticamente verdadero y reproducible; (2) el máximo
rendimiento medido compatible con esa verdad.** No aceptes un programa lento sin un perfil, ni una
aceleración sin una prueba contra un oráculo independiente.

Procedimiento obligatorio:

1. Formula el modelo matemático, la complejidad temporal/espacial y el adversario/caso de borde
   relevante antes de elegir la estructura de datos.
2. Diseña la representación para la operación dominante: tipos concretos, arrays contiguos,
   SoA frente a AoS, IDs densos, `BitVector`/CSR/`StaticArrays`/`Dict` solo cuando el caso lo
   justifique. Explica brevemente la elección.
3. Escribe primero una referencia pequeña, transparente y preferiblemente exacta; crea tests de
   bordes, invariantes, contraejemplos previos y semillas fijas.
4. Implementa el kernel rápido dentro de funciones tipoestables, sin globals dinámicos ni `Any`.
   Preasigna memoria, usa versiones mutantes (`!`), evita asignaciones y respeta el orden de
   columnas. No materialices combinaciones, grafos o temporales innecesarios.
5. Valida el kernel rápido contra la referencia en instancias pequeñas, propiedades aleatorias y
   todos los vectores de regresión. Para umbrales numéricos, certifica con exactitud, intervalos o
   aritmética de bolas; si el margen no se puede certificar, declara el resultado inconcluso.
6. Mide el caso representativo tras calentar JIT con `BenchmarkTools`; perfila CPU/memoria con
   `Profile`, `@allocated`, `@code_warntype` y JET. Optimiza el cuello real, no el supuesto.
7. Paraleliza solo trabajo independiente y usa RNG por réplica/chunk, reducción determinista y
   ausencia demostrada de carreras. Arranca batch CPU-bound dentro del tope de 24 hilos (8 lógicos
   quedan para el sistema), mide el escalado `1…24` y conserva la configuración que gane
   realmente, aunque use menos hilos; evita BLAS anidado.
8. Considera `LoopVectorization` o MPI únicamente si el perfil demuestra un kernel regular
   dominante y el coste no lo anula. Para GPU **no uses Julia**: escribe el kernel en C++/CUDA
   (§5.7), con oráculo CPU estricto, transferencias medidas y `compute-sanitizer`. Compara siempre
   con CPU estricta.
9. No uses `@fastmath`. `@inbounds`, `@simd`, `@turbo` o precisión `Float32` requieren prueba de
   equivalencia, comentario de supuestos y benchmark. Nunca dejes que una optimización cambie un
   veredicto sin declararlo.
10. Entrega `Project.toml`, `Manifest.toml`, comando exacto, semilla, versión/hardware, tabla de
    rendimiento, número de asignaciones y resultado de la validación. Distingue con claridad lo
    demostrado, medido, estimado y no demostrado.

11. Declara antes de ejecutar el presupuesto de tiempo, memoria y disco (en la máquina de
    referencia: máximo 64 GiB de RAM y 24 hilos). Si se agota, conserva el checkpoint y reporta
    **inconcluso**; guarda semilla, parámetros, configuración y una entrada mínima reproducible
    para cada fallo. No confundas timeout con evidencia de falsedad.

Si una corrida supera el presupuesto declarado, detente antes de ampliar la exploración y produce
un perfil más una hipótesis de cuello de botella. Propón la mejora algorítmica o de datos de mayor
impacto y verifica que conserva resultados antes de lanzar otra corrida larga.

---

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: el peso de este trabajo es **análisis criptográfico
y lectura de fuente**, con un **modelo pequeño** que cuantifica una frontera. El bloque te aplica
entero para ese modelo. **Máximo 4 hilos**, corridas de minutos; declara el presupuesto antes de
ejecutar. Julia en CPU con `./veritas/julia.sh`; **nada de Python**. Anota `uptime` antes de cada
benchmark. **No plotees ni ejecutes `ab-proof-of-space`**: su ruta no paralela (`create_proofs`,
`create`) tiene un SIGSEGV reproducible en el clon fijado (`P-ZRX/P-INTENTO/investigacion/mediciones/fallo-semilla.md`).

# ENCARGO P-COBERTURA — Cobertura y preexistencia de una parcela Autonomys: construcción o imposibilidad

## 0 · Por qué existe este encargo, y qué NO es

Tras `P-ZRX/P-CLAVE/` (2026-09-22), **el registro de parcelas con compromiso previo y edad es la
única vía estructural que queda en pie** contra tres agujeros a la vez: el sembrador (B2), el
alquiler corto (C1) y la reutilización del espacio entre ramas. Las otras candidatas cayeron:
la identidad de billete por pieza quedó refutada (`P-ZRX/P-IDENTIDAD/`) y la retención ligada a la
clave **no disuade** al atacante que decide, porque compra el espacio que necesita en claves de
saldo casi nulo con soborno cero (`P-ZRX/P-CLAVE/investigacion/INFORME.md` F3).

Y esa vía está bloqueada por **una sola pieza que no existe**: una prueba de que un compromiso
registrado antes del reto cubre **todos los bytes caros** de una parcela, y de que esos bytes
**existían** cuando se registró.

`P-ZRX/P-PERMANENCIA/` buscó esa pieza y concluyó **«no se ha encontrado»**, negándose
explícitamente a decir **«no puede existir»**. **Ese salto es tu encargo.** No repitas su búsqueda
bibliográfica: **decide el salto**, en un sentido o en el otro.

Las dos salidas son resultados y las dos le sirven a Katana:

- **Imposibilidad demostrada bajo hipótesis declaradas** ⟹ el cierre estructural exige **cambiar el
  formato de parcela** o **aceptar el agujero**, y se deja de esperar una pieza que no va a llegar.
- **Construcción candidata** ⟹ con su coste (tamaño de prueba, verificación, estado en cadena,
  cambio de formato) entra en el tablero como propuesta.

**Lo que NO es un resultado:** otro catálogo de familias criptográficas sin veredicto, ni un «parece
que no» sin modelo de adversario.

**Modelo de amenaza (de Katana, obligatorio):** se asume que un ente con mucha capacidad —dinero,
CPU, GPU, discos— **atacará**. «No compensa económicamente» **no es un argumento de seguridad**:
descarta al atacante que busca lucro y a nadie más. Separa siempre lo que vuelve el ataque
**imposible** de lo que solo lo vuelve **caro**, y da el coste **absoluto** en hardware.

## 1 · Entradas congeladas: esto está medido o verificado, y NO se re-mide ni se rehace

**Úsalo como entrada.** Si crees que alguna cifra está mal, dilo en `PROGRESO.md` con el argumento,
pero no gastes el encargo en rehacerla.

### 1.1 · Lo que el formato ya compromete, y lo que no (verificado por Claude en el clon `f8842d0`)

Árbol: `PDF/autonomys-subspace` (idéntico a `/home/katana/zeo/fuentes/subspace` salvo `target/`).

| Hecho | Dónde |
|---|---|
| `SectorId = blake3_keyed(public_key_hash; [sector_index, history_size])` | `crates/subspace-core-primitives/src/sectors.rs:56-68` |
| El reto selecciona **un solo s-bucket** de 65 536 por sector: `s_bucket_audit_index` = 2 bytes LE de `sector_slot_challenge` | `sectors.rs:34-39,117-123` |
| `derive_evaluation_seed = blake3_hash_list([sector_id, piece_offset])`: la semilla PoS es **por `piece_offset`** | `sectors.rs:126-130` |
| El KZG (`record_commitment` + `chunk_witness`, y `record_witness` contra `segment_commitment`) cubre **la codificación de datos públicos**, abierta en **una** posición | `crates/subspace-verification/src/lib.rs:263-272,335-347` |
| **El verificador recibe el `chunk` SIN enmascarar y enmascara él** (`masked_chunk = chunk XOR proof.hash()`): que el granjero tenga el chunk **codificado en disco** no se prueba nunca | `lib.rs:248-249` |
| **Nada compromete la parcela como conjunto**: no hay raíz, acumulador ni compromiso sobre los `P` records ni sobre los 65 536 s-buckets. `s_bucket_sizes` y los checksums Blake3 son metadatos locales del propio granjero, fuera del consenso | `subspace-farmer-components/src/sector.rs:27-65,139-151`; `solutions.rs:254-275` |
| **No existe registro de sectores en cadena**: `sector_index` no se contrasta con nada | `lib.rs:211-351` |
| La **expiración de sector existe** pero es pseudoaleatoria por `sector_id` (`blake3(sector_id ‖ segment_commitment)`), con tope `min_sector_lifetime + 4×history_size`: obliga a re-plotear, **no fecha los bytes** | `sectors.rs:135-164`; `lib.rs:303-323` |
| Ploteo **determinista**: un tercero con `(public_key, sector_index, history_size)` y el historial público regenera el sector **bit a bit** | `subspace-farmer-components/src/plotting.rs:616-690` |
| Constantes: `Record::NUM_CHUNKS = 2^15`, `NUM_S_BUCKETS = 2^16`, `Record::SIZE = 1 MiB`, `Piece::SIZE = 1 048 672 B`, `MAX_PIECES_IN_SECTOR = 1000`, tabla PoS Chia con `K = 20` | `pieces.rs:404,561,565-570,1226`; `subspace-runtime/src/lib.rs:125`; `pos.rs:103` |

### 1.2 · Lo que ya está establecido por los encargos previos

- **La unidad del atacante es la pieza/registro, no el sector.** Cada record se codifica por separado
  y el verificador comprueba **una** prueba PoS, **un** chunk y **un** testigo
  (`P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`).
- **Ni `history_size` ni `altura_ploteo` fechan bytes**: identifican el prefijo histórico y la
  caducidad, no cuándo se computó nada (íd.).
- **El objeto caro no son los datos públicos: son las siete tablas PoS y `blake3(proof)`**, y **eso
  es justo lo que ningún compromiso actual cubre** (`P-ZRX/P-PERMANENCIA/`, E1).
- **E2 (aperturas aleatorias por muestreo con plazo) CAYÓ, y no por calibración**: el tramposo
  regenera **solo** las `c` piezas pedidas, con coste independiente de `N` (íd., F1).
- **E3 (parciales todas ligadas) sobrevive solo como cota económica** y **no añade coste sobre
  farmear a secas**: vuelve la obligación *observable*, no más cara (íd., F2-F3).
- **A1+C1** = registrar **antes del reto** raíz/versión/cardinalidad de la parcela exacta **y** hacer
  que la candidatura dependa de **todos** los registros, con edad `M > sup A`. Es la forma mínima
  capaz de cerrar el mecanismo; sin registro ni acumulador, ninguna candidata estudiada lo elimina.
- **Descartado, no reabrir:** A0 (solo `history_size`/`altura_ploteo`), A2 (plegado en bloque
  anterior de la misma clave), F (acotar `ρ`, cuotas por identidad, detección estadística: las
  identidades son gratis), y una raíz presentada **después** de conocer el reto.

### 1.3 · Cifras medidas que son entrada

| Magnitud | Valor | Fuente |
|---|---|---|
| `t_tabla`: generar las 7 tablas con semilla nueva | **809,13 ms** de un núcleo | `P-ZRX/P-INTENTO/investigacion/INFORME.md` |
| `r`: rendimiento agregado | **25,03 tablas/s** con 24 hilos (**cota superior** del código tal cual) | íd. |
| Camino ganador (leer pieza, erasure, `Kzg::poly`, `create_witness`) | ≈ **2,8 %** del intento | íd. |
| Comprometer el objeto caro, por TiB | `N·t_tabla` = **235,6 h·núcleo** | `P-ZRX/P-PERMANENCIA/` E1 |
| E3/E5 regenerando dentro de la ventana | **5,84 CPU/TiB** a `w = 7 175`; cruce con el precio del disco en `w ≈ 8,4·10⁵` | íd. F2 |
| Ventana de antelación `w` con que el reto es conocido | **7 175–8 030** slots sin segundo VDF; **4 830,6** con `ρ = 2,5` y segundo VDF | `P-ZRX/P-REVELACION/` |

> **Tarea de consistencia, obligatoria y corta:** `235,6 h·núcleo/TiB` y `5,84 CPU/TiB` no pueden
> describir lo mismo (difieren en un factor ~20-140 según cómo se anualice la ventana). **Reconcilia
> las dos** —di qué mide cada una y bajo qué hipótesis— antes de usarlas. Si una está mal, dilo: es
> un resultado por sí solo.

## 2 · Lo que tienes que hacer

### 2.1 · Formalizar la propiedad ANTES de buscar nada

No escribas «prueba de cobertura» sin definirla. Separa al menos **tres** propiedades distintas, que
hoy se confunden:

1. **Cobertura de los datos públicos** — ya la da el KZG, y no sirve: los datos son públicos.
2. **Cobertura del objeto caro** — que el compromiso ate las `N` tablas PoS / chunks enmascarados.
3. **Forma almacenada** — que los bytes estén en disco **codificados**, no reconstruibles al vuelo
   desde el record limpio. Hoy **ni siquiera se prueba para un solo chunk** (`lib.rs:248-249`).

Y añade la dimensión temporal: **preexistencia** (los bytes existían en `t − M`) y **vinculación**
(son de *esa* clave y de *esa* parcela). Declara cuál de estas cinco pide A1+C1 y cuál pretende
demostrar o refutar cada respuesta tuya. **Una respuesta que no separe las tres primeras no vale.**

### 2.2 · El teorema que falta

Enuncia y decide, con un **modelo de adversario explícito**, esta afirmación o la suya contraria:

> Para un objeto que es **función determinista y pública** de `(clave, índice, historia)` y cuyo
> cómputo es **paralelizable**, ninguna prueba con verificación sucinta distingue «almacenado» de
> «regenerado dentro del plazo», salvo que se imponga (i) una **latencia** menor que el tiempo
> mínimo de regenerar una unidad, (ii) un **coste secuencial no paralelizable** en la generación,
> (iii) una dependencia que obligue a **materializar las `N` unidades a la vez**, o (iv) que el
> contenido **no sea públicamente regenerable**.

Parámetros mínimos del adversario, todos **símbolos**: `N` unidades declaradas; `φ` fracción
realmente almacenada; `R` tasa de regeneración disponible; `D_a` plazo de respuesta a una auditoría;
`k` aperturas por auditoría; `w` antelación con que se conoce el reto; `M` edad exigida.

**Se admite como resultado «imposible bajo estas hipótesis», y NO se admite «no lo he encontrado».**
Si el resultado es condicional, enúncialo como teorema con sus hipótesis a la vista. Si encuentras
la construcción, demuéstrala igual de explícitamente.

**Atención al punto que mató a E2:** el reto se conoce con `w` slots de antelación, así que
«a la vez» tiene una ventana enorme, y muestrear posiciones predecibles baja el coste del tramposo a
`k` tablas por envío. Cualquier construcción tuya tiene que sobrevivir a eso o declarar que no.

### 2.3 · El precio de romper cada hipótesis, en ESTE formato

Para cada una de las cuatro vías de escape (i)-(iv), y **solo** para las que tu teorema deje vivas:

- Qué habría que cambiar, **con la ruta del fichero** (`plotting.rs`, `sectors.rs`,
  `subspace-verification/src/lib.rs`): ¿basta añadir un compromiso, o cambia el objeto ploteado?
- Qué le cuesta al **granjero honesto**: tiempo de ploteo adicional, disco, CPU por auditoría.
- Qué **abre de nuevo**: ventaja ASIC, latencia exigida a una red doméstica, centralización,
  incompatibilidad con la expiración pseudoaleatoria que ya existe.
- Si alguna vía es compatible con **conservar el formato fijado**, dilo explícitamente: es la
  pregunta que más le importa a Katana.

Referencias vivas que puedes usar como comparación, **abriéndolas**: sellado secuencial tipo PoRep
(Filecoin), ATX + PoST inicial de Spacemesh, el *plot filter* y el `plot_id` de Chia
(`PDF/chia-blockchain` está en local), y `PDF/time-memory-tre-off-proof-space.pdf` (**ábrelo**: los
compromisos espacio-tiempo deciden si (iii) aguanta). **Lo que no puedas abrir, etiquétalo
`no verificado`; no inventes citas ni números de sección.**

### 2.4 · La frontera cuantitativa (esto es el instrumento)

Modela el **juego regeneración contra auditoría** y publica la frontera, con referencia exacta antes
de cualquier aproximación:

- Probabilidad de detección por auditoría y acumulada en `T` auditorías, para un tramposo que
  almacena `φ` y regenera el resto, en función de `(k, D_a, R, w)`.
- **El resultado que decide:** el `φ*` por debajo del cual el tramposo no es detectable con `k`
  sucinto, y qué hace falta para moverlo.
- El **coste absoluto** del tramposo en núcleos y en GPU-equivalentes por TiB ahorrado, y dónde
  cruza el **precio del disco**. La GPU **17×** es documentación ajena, **nunca medida**: entra como
  **hipótesis declarada** y con una fila propia, jamás como cifra medida.
- `t_tabla`, `r`, `w` y el precio del disco son **entradas** (§1.3). Ningún parámetro de consenso se
  fija aquí.

## 3 · Las preguntas

**F1** · La propiedad, formalizada: las tres coberturas, la preexistencia y la vinculación, y cuál
de ellas pide A1+C1. Qué prueba hoy el formato de cada una — incluido el hallazgo de que la **forma
almacenada no se prueba ni para un chunk**.
**F2** · **El teorema de §2.2: ¿puede existir, para el formato fijado y sin cambiarlo, una prueba
sucinta de cobertura del objeto caro y de preexistencia?** Demostración o refutación, con hipótesis
declaradas. «No lo he encontrado» no es respuesta.
**F3** · Para cada vía de escape que quede viva: qué cambia del formato, qué le cuesta al honesto y
qué abre de nuevo. Y si alguna conserva el formato fijado.
**F4** · La frontera `φ*(k, D_a, R, w)` y el coste absoluto del tramposo por TiB ahorrado, con el
cruce con el precio del disco.
**F5** · El **coste del registro**: bytes por alta, estado acumulado en cadena, tasa de altas y bajas
inducida por la expiración pseudoaleatoria ya existente, y si un nodo doméstico lo aguanta. Es lo que
`P-ZRX/P-PERMANENCIA/` dejó `no determinado`.
**F6** · **El veredicto para Katana**: seguir por el registro, cambiar el formato de parcela, o
aceptar el agujero — con el coste de cada rama. Y si la respuesta a F2 es «no puede existir», **qué
es lo máximo que sí se puede comprometer** y qué fracción del ataque cierra eso, dicho **sin palabras
de cobertura**.

## 4 · El instrumento

`P-ZRX/P-COBERTURA/investigacion/veritas/criptografia/cobertura-parcela-v1/`, estructura de
LINEO §1 (la categoría la determinas tú y la justificas en el `INFORME.md`; `criptografia` es la
propuesta). Referencia exacta (`Rational{BigInt}` o intervalos) para las colas de detección **antes**
de cualquier aproximación normal. Si usas Monte Carlo: RNG por réplica con semillas **no
consecutivas** —las consecutivas de `StableRNG` sesgan el MC, hallazgo de `P-ZRX/P-PUERTA/`—,
réplicas e IC declarados. **Un test que compara una fórmula consigo misma no es un test.**

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-COBERTURA/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-COBERTURA/` son de solo lectura `PROMPT.md` y `ENTRADA.sha256`. Al empezar y
al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-COBERTURA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 6 · Lecturas (ábrelas ENTERAS)

`veritas/LINEO.md` entero · **`P-ZRX/P-PERMANENCIA/investigacion/INFORME.md` entero** (es tu punto de
partida: E1-E5, F1-F3 y su §6) y su `CANDIDATA.md` §1, que fija qué debería comprometer un
`PlotBatchId` · **`P-ZRX/P-SEMBRADOR/investigacion/INFORME.md` entero** (A1+C1, y su «Lo que NO
resuelve») · `P-ZRX/P-INTENTO/investigacion/INFORME.md` (las cifras de §1.3 y sus límites) ·
`P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md` · `P-ZRX/P-CLAVE/investigacion/INFORME.md` F3-F6
(por qué el registro volvió a ser la única vía) · `research/README.md` para localizar evidencia.

Fuente del formato, **abriendo los ficheros citados en §1.1 uno a uno**: `PDF/autonomys-subspace`.
Externas: `PDF/time-memory-tre-off-proof-space.pdf` y `PDF/chia-blockchain`; PoRep de Filecoin y
ATX/PoST de Spacemesh si puedes obtenerlas. **Lo que no abras, `no verificado`.**

**Advertencia de método, lección del 2026-09-21 en este repositorio:** dos errores del mismo día
salieron de leer una línea citada en vez del documento entero.

## 7 · Entregables (`P-ZRX/P-COBERTURA/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F2**: si puede existir o no, y bajo qué hipótesis.
  Después F1-F6, en ese orden.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana, con el coste de cada rama.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`. La GPU 17× y el precio del disco son **hipótesis**.
- **«No se ha encontrado» y «no puede existir» son afirmaciones distintas.** Di cuál estás haciendo,
  cada vez. Este encargo existe porque el encargo anterior se negó, con razón, a confundirlas.
- **No presentes una garantía económica como criptográfica**, ni una mitigación con palabras de
  cobertura («lo elimina», «lo cierra», «protege»). Una cota económica se enuncia como cota
  económica, con su adversario y su precio.
- **`r = 25,03 tablas/s` es cota SUPERIOR del código tal cual**, no una cota inferior del adversario:
  SIMD, GPU y ASIC no están medidos. No derives de ella ninguna garantía.
- **No fijes** ningún parámetro de consenso: `M`, `k`, `D_a`, `w`, `φ`, `N` son entradas.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
