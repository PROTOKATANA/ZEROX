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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: el peso es **recogida de datos reales** de redes
existentes más **un modelo exacto** del quórum. La recogida no es cálculo: descargar, archivar y
fechar las fuentes se hace con las herramientas del sistema (`curl`, `jq`). **Todo el procesado y el
modelo van en Julia en CPU** con `./veritas/julia.sh`; **nada de Python**. **Máximo 4 hilos.**
Declara el presupuesto de tiempo, red y disco **antes** de descargar nada: hay APIs que devuelven
mucho. Anota `uptime` antes de cada benchmark.

# ENCARGO P-VIVEZA — ¿Cuánto del stake de voto estaría encendido con granjeros reales?

## 0 · POR QUÉ ESTE ENCARGO ES EL QUE DECIDE

`SPEC-POS2T.md` (raíz del repositorio, **propuesta, no normativa**) añade a ZEROX una **finalidad por
votos con stake** (`C-VOT`). Su viabilidad depende de una sola magnitud que **nadie ha medido**:

> **`p` = la fracción del stake de voto que está encendida y votando en cada época.**

Con `p` baja, la capa de votos se queda parada. Y **eso no es un defecto del diseño: es un teorema.**

### 0.1 · El teorema, y lo que de verdad pregunta este encargo

Lewis-Pye y Roughgarden, Teorema 4.1, en el repositorio: `research/fuentes/lewispye-roughgarden-cap.txt`
(enunciado en la línea 759), analizado en `research/scripts/d12-quorum/informe.md` §C:

> *«No protocol is both adaptive and has finality.»*

**Adaptativo** = sigue vivo sin saber cuántos participan. **Finalidad** = seguro en red parcialmente
síncrona. Traducido a ZEROX: **toda capa de finalidad se para cuando se apaga demasiada gente**, y
ningún diseño lo evita. Por eso `SPEC-POS2T` deja **la cadena PoST corriendo siempre** (`C-FIN-01`
como suelo) y la finalidad **encima**, pudiendo pararse (`C-VOT-05`) — el marco de las dos reglas de
confirmación de Sankagiri et al. (`research/fuentes/cap-adaptividad-finalidad.txt`).

> **La pregunta NO es si la capa de votos se parará con granjeros domésticos. Se parará. La pregunta
> es CON QUÉ FRECUENCIA, cuánto tiempo, y si eso la deja útil o inútil.**

**Aviso de lectura:** la hipótesis del teorema, *«no balance, no voice»*, solo dice que quien no tiene
recursos no puede emitir mensajes. **El stake no la rompe.** No busques una salida por ahí.

### 0.2 · El criterio ya está fijado — no lo inventes

**Dos documentos lo escribieron, y coinciden:**

- `research/dag-poas-capa-finalidad.md` §4.C: hay quórum solo si **`(1 − α)·p ≥ ⅔`**, exigiendo ⅔
  del peso **total**, no de los presentes:

  | `α` | `p` mínima |
  |---:|---:|
  | 0,10 | 74,1 % |
  | 0,20 | 83,3 % |
  | **0,25** | **88,9 %** |
  | 0,30 | 95,2 % |
  | 0,33 | 99,5 % |

- `research/scripts/d12-quorum/informe.md` §E.2 (2026-09-10): *«la condición que cambiaría la
  recomendación: que la medida de campo de `p` salga **por encima del 90 %** y que `Δ_p99` salga por
  debajo de 4 s»*. **`Δ` simulada da 0,26–0,60 s** (`veritas/finalidad/delta-medido-v1/`). **Lo único
  que falta es `p`.**

### 0.3 · La reformulación que puede cambiarlo todo

`p` **no es la fracción de granjeros encendidos. Es la fracción del STAKE encendido.** El quórum se
cuenta en peso (`C-VOT-04`). `[lectura de Claude, NO validada]`:

> Si los granjeros grandes —que concentran el stake— están encendidos 24/7 y los domésticos
> pequeños se apagan, **`p` por stake puede superar el 90 % aunque la mayoría de granjeros, por
> número, esté apagada.** Con la distribución de tamaños que el repo ha supuesto (Pareto, hipótesis
> H3 de `P-ZRX/P-CLAVE/investigacion/INFORME.md`), unos pocos concentran casi todo.

**La magnitud que decide es la correlación entre tamaño y tiempo encendido.** Si esa correlación es
positiva y fuerte, la capa funciona. Si es nula, `p` por stake ≈ `p` por granjero, y con granjeros
domésticos probablemente no.

**Pero cuidado con lo que eso compra:** si la finalidad depende de que los grandes estén encendidos,
**los grandes controlan la finalidad**. Mide también **cuánto stake hace falta apagar para pararla**:
es el coste de la censura (capa-finalidad §6.3).

### 0.4 · Lo que ya se sabe de la parada

`research/scripts/d12-quorum/informe.md` §D.4, **para el quórum de soluciones** (una variante ya
refutada, pero con la misma física): con un **30 %** del espacio apagado de golpe, entre el **28 % y el
37 %** de las instancias no cierran quórum, y la recuperación tarda **una ventana de retarget, ≈ 51
min**. *«Esto no es un ataque: es un lunes por la mañana con el 30 % de los granjeros domésticos
apagados.»*

Y el error que su autor reconoció en la capa de finalidad (§7): el cálculo trataba las ausencias como
**independientes**, pero **las plazas de una misma clave caen juntas**, y eso **subestima la varianza
del quórum**. **Tu modelo tiene que ser correlado.**

## 1 · LA PREGUNTA CENTRAL

> **Con granjeros de disco reales, ¿qué fracción del stake de voto estaría encendida en cada época,
> con qué frecuencia y durante cuánto se pararía la finalidad de `SPEC-POS2T`, y supera el criterio
> fijado de `p > 90 %`?**

## 2 · LAS FUENTES DE DATOS — ZEROX no tiene red; hay que usar redes parecidas

**ZEROX no tiene red desplegada ni granjeros.** Toda medida es **de una red sustituta**, y cada una
tiene que llevar escrito **cuánto se parece a un granjero de ZEROX y en qué no**. Examina, como
mínimo:

| Red | Por qué sirve | Por qué no basta | Qué dato buscar |
|---|---|---|---|
| **Autonomys (Subspace)** | **El mismo formato PoAS** y el mismo perfil de granjero doméstico que ZEROX hereda | Sin stake ni castigo: los incentivos para estar encendido son más débiles | Actividad por clave de granjero a lo largo del tiempo, en la cadena o en su telemetría pública |
| **Chia** | Granjeros domésticos de disco, red grande y madura | Otro formato de parcela; los pools cambian el comportamiento | **Parciales por granjero en los pools**: un granjero apagado deja de enviarlos. Es la señal de encendido más directa que existe |
| **Ethereum** | Tasa de participación de validadores **con stake, castigo y fuga por inactividad**: lo que esos incentivos consiguen | Operadores mayoritariamente profesionales, no domésticos | Tasa de participación por época, y su caída en incidentes |
| **Nodos de Bitcoin** | Tiempo encendido de nodos domésticos **sin incentivo alguno** | No producen nada ni arriesgan nada | Distribución de sesiones y abandonos |
| **Filecoin** | PoST con colateral en producción, y **F3** en marcha | Proveedores profesionales 24/7 | Participación en F3, si es pública |

**Reglas para las fuentes, obligatorias:**
- **Archiva cada fuente** con su URL, la fecha y hora de descarga y su `sha256`, en
  `investigacion/fuentes/`. Precedente: `P-ZRX/P-SELLO/` archivó 29 fuentes en
  `evidencia-fuentes/`.
- **Si una fuente no existe, no es pública o no se deja descargar, dilo** y pasa a la siguiente. **No
  inventes datos que falten.** «No se ha encontrado» es un resultado.
- **Distingue cotas:** una red **sin** incentivo para estar encendido da una **cota inferior** de lo
  que harían granjeros con stake en juego; una red de profesionales da una **cota superior**. **La `p`
  de ZEROX cae entre las dos**, y el encargo tiene que decir dónde y con qué argumento.

## 3 · LO QUE HAY QUE HACER

### 3.1 · La distribución de tiempo encendido, por tamaño

Para cada fuente que dé datos: la distribución de la fracción de tiempo encendido, **y su relación
con el tamaño** del participante (espacio, stake o producción). **Esa correlación es la magnitud
central** (§0.3). Si una fuente no permite medirla, dilo.

### 3.2 · `p` por stake, que es la que cuenta

Combina la distribución de §3.1 con distribuciones de tamaño **declaradas como entrada** —Pareto con
el exponente de la hipótesis H3 de `P-CLAVE`, y al menos una alternativa—, y calcula `p` **ponderada
por stake**. Da el resultado como **función** del exponente y de la correlación tamaño↔encendido, no
como un número.

### 3.3 · La frecuencia y la duración de las paradas

Con `p` por stake y **ausencias correladas** (las plazas de una clave caen juntas, y los granjeros
domésticos se apagan a la vez por la noche y los fines de semana en la misma zona horaria):

- la fracción de épocas **sin quórum**, en función de `α` y de `PERIODO_VOTO`;
- la **duración** de las rachas sin finalidad;
- **el ciclo diario y semanal**: ¿se para la finalidad **todas las noches** en una red con granjeros
  concentrados en pocas zonas horarias? Si los datos lo permiten, mídelo; es el «lunes por la mañana»
  de la ronda 12 visto desde el otro lado.

### 3.4 · La elegibilidad de `SPEC-POS2T` y sus alternativas

`C-VOT-02` hace elegible a quien tenga `stake_activo ≥ VOTO_MINIMO` **y** haya producido en los últimos
`W_ELEGIBLE` slots. **Barre `VOTO_MINIMO` y `W_ELEGIBLE` como entradas** y di dónde la capa funciona.
Compara con la alternativa de la capa de finalidad (`W_VIVO = 1 800 s`: solo votan quienes ganaron un
bloque en la última media hora, lo que sube `p` pero excluye al pequeño). **No fijes ningún valor.**

### 3.5 · La fuga por inactividad, con granjeros reales

`C-VOT-07` quema stake de los elegibles que no votan cuando la finalidad lleva `FUGA_EPOCAS` parada.
Con los datos de §3.3: **cuántas veces se dispararía, y cuánto perdería un granjero doméstico honesto**
por apagar su PC por la noche. Si la fuga castiga habitualmente a honestos, **eso contradice el valor
de Katana** *«el granjero es doméstico: enciende y apaga cuando quiere»* (`P-ZRX/P-RNG/PROMPT.md`
§2.4), y hay que decirlo.

### 3.6 · El coste de pararla a propósito

¿Qué fracción del stake tiene que **apagar o retener** un atacante para parar la finalidad, dado el
`p` honesto medido? Si los honestos ya van justos, **un atacante pequeño basta**. Coste **absoluto**,
no relativo.

## 4 · LAS PREGUNTAS

**F1** · ¿Supera `p` **por stake** el criterio de **90 %**? **Primera línea del informe.** Con su
intervalo y la fuente de la que sale.
**F2** · La **correlación tamaño↔encendido**, por fuente. Si no se pudo medir, dilo.
**F3** · La frecuencia y duración de las paradas, **con el ciclo diario y semanal**.
**F4** · La región de `VOTO_MINIMO` y `W_ELEGIBLE` donde la capa funciona.
**F5** · Cuánto le cuesta la fuga por inactividad al granjero doméstico honesto.
**F6** · El coste absoluto de parar la finalidad a propósito.
**F7** · **Veredicto — matar o seguir:** ¿funciona `C-VOT` tal como está en `SPEC-POS2T`, funciona
con otra elegibilidad, o no funciona con granjeros domésticos? **Si no funciona, dilo sin rodeos**:
es el resultado para el que existe este encargo.

## 5 · EL INSTRUMENTO

`P-ZRX/P-VIVEZA/investigacion/veritas/consenso/viveza-v1/`, estructura de LINEO §1 (`CONTRATO.md`,
`MODELO.md`, `METODO.md`, `HIPOTESIS.md`, `PROCEDENCIA.md`, `HUELLAS.sha256`, `BITACORA.md`,
`Project.toml`, `Manifest.toml`, `run.jl`, `src/`, `test/`, `resultados/`).

- **Los datos crudos descargados** van a `investigacion/fuentes/`, con su huella, y el instrumento los
  lee de ahí. **El instrumento no descarga nada**: así es reproducible sin red.
- **Aritmética exacta** en las colas del quórum: la probabilidad de no cerrar quórum es una cola, y ahí
  el flotante decide mal.
- **Monte Carlo** con semillas **NO consecutivas** (hallazgo de `P-ZRX/P-PUERTA/`), réplicas e IC.
- **Control positivo obligatorio:** reproduce la tabla del quórum de §0.2 (`(1 − α)·p ≥ ⅔`) antes de
  medir nada nuevo. Si no la reproduces, el modelo está mal y te detienes ahí.
- **`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`** obligatorio. **La hipótesis más peligrosa de este
  encargo es la transferibilidad** de cada red sustituta: nómbrala.
- **Resultados dentro de la carpeta del instrumento**, nunca en el CWD.
- **El conteo de tests que declares MUST salir de un artefacto que entregues.**

## 6 · ZONA DE TRABAJO Y HUELLAS

**Escribes SOLO en `P-ZRX/P-VIVEZA/investigacion/`.** No edites nada de `SPEC.md`,
`SPEC-POS2T.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni
del resto de `P-ZRX/`. `P-ZRX/P-VIVEZA/PROMPT.md` es de solo lectura. Al empezar y al terminar,
desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-VIVEZA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las salidas en `PROGRESO.md`. **Aviso:** hay otros encargos trabajando en paralelo —código en
`crates/`, y los de `P-ZRX/P-STAKE/`—; lo que aparezca `M` o `??` en tu entrada **no es tuyo**. **Cita
las reglas por ID, nunca por número de línea.**

## 7 · LECTURAS (ábrelas ENTERAS)

**Empieza por aquí:** `SPEC-POS2T.md` (sobre todo §8, `C-VOT`, y §13) ·
`research/dag-poas-capa-finalidad.md` §4.C y §7 · `research/scripts/d12-quorum/informe.md` §C, §D y
§E · `research/fuentes/lewispye-roughgarden-cap.txt` (el Teorema 4.1 y sus definiciones 3.2 a 3.4).

**Después:** `research/fuentes/cap-adaptividad-finalidad.txt` (las dos reglas de confirmación) ·
`P-ZRX/P-CLAVE/investigacion/INFORME.md` (la hipótesis H3 de tamaños) · `P-ZRX/P-STAKE/MAPA.md`
§1.2 (la fuga por inactividad de Ethereum, verificada) · `P-ZRX/P-RNG/PROMPT.md` §2 (los valores del
proyecto) · `veritas/finalidad/delta-medido-v1/INFORME.md` · `AGENTS.md` · `veritas/LINEO.md`.

**Advertencia de método:** en este repositorio, dos errores del mismo día salieron de leer una línea
citada en vez del documento entero.

## 8 · ENTREGABLES (`P-ZRX/P-VIVEZA/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F1.** Después F2-F7.
- `FUENTES.md` — cada red sustituta: qué se descargó, cuándo, de dónde, cuánto se parece a ZEROX y en
  qué no, y si da cota inferior o superior.
- `fuentes/` — los datos crudos archivados, con huellas.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones para Katana, con el coste de cada rama. Si la capa no
  funciona tal cual, **las alternativas de elegibilidad** con su precio.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 9 · REGLAS DE VALIDEZ

- **No cites un archivo, una línea, una API ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **«No se ha encontrado» y «no puede existir» son distintas.** Di cuál afirmas, cada vez.
- **Una red sustituta no es ZEROX.** Toda cifra que venga de otra red lleva escrito **de cuál**, y
  **si es cota inferior o superior**. Ninguna se presenta como «la `p` de ZEROX».
- **No fijes NINGÚN valor:** `VOTO_MINIMO`, `W_ELEGIBLE`, `PERIODO_VOTO`, `FUGA_EPOCAS`, `FUGA_TASA`,
  `α`. Son **entradas**.
- **No rebajes el criterio.** El 90 % lo fijó la ronda 12 y el 88,9 % la capa de finalidad; si `p`
  queda por debajo, **ése es el resultado**, no una invitación a relajar el umbral.
- **La premisa no tiene privilegio.** La lectura de §0.3 —que `p` por stake pueda salvar la capa— **es de
  Claude y no está validada**; refutarla es un entregable completo.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
