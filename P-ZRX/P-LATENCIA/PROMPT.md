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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: esto es **sobre todo lectura y criba**, no cómputo.
El bloque te aplica **solo si alguna familia sobrevive** y hay que cuantificar algo; entonces se
hace en Julia CPU con `./veritas/julia.sh`, **máximo 4 hilos**, corridas de minutos, y **nada de
Python**. Si ninguna sobrevive, **no hay instrumento y no pasa nada**: el entregable es la criba.

# ENCARGO P-LATENCIA — Cuatro familias que ZEROX nunca ha mirado: ¿alguna cierra o acota algo?

## 0 · Por qué existe este encargo, y qué se espera de verdad

Un inventario del 2026-09-22 sobre todo el repositorio encontró cuatro familias de mecanismos que
**no aparecen mencionadas en ningún documento** de `research/`, `P-ZRX/`, `SPEC.md`, `TAREAS.md`,
`veritas/` ni `MIGRACION.md`:

1. **Proof of latency / proof of location**
2. **Data Availability Sampling (DAS)** y compromisos vectoriales para disponibilidad
3. **Catalytic space** (espacio catalítico)
4. **Funciones memory-hard** como palanca anti-ASIC para el PoT

**Aviso que gobierna el encargo: se espera que la mayoría sean «NO».** Éste no es un encargo para
encontrar una solución; es para **cerrar por escrito cuatro puertas que hoy están entreabiertas**,
o para encontrar la que no lo esté. **Un «no» bien argumentado es el entregable completo y
satisfactorio.** Lo que no vale es un «podría explorarse» sin veredicto.

**No hay premio por extensión.** Si una familia se cae tras leer sus fuentes, ciérrala en dos
páginas con el argumento y pasa a la siguiente. Se valora la criba rápida y honesta.

**Modelo de amenaza (de Katana, obligatorio):** se asume que un ente con mucha capacidad —dinero,
CPU, GPU, discos, **presencia en muchas redes y países**— atacará. «No compensa económicamente» no
es un argumento de seguridad. Este modelo es especialmente duro con la familia 1: **un Estado tiene
presencia geográfica real**, así que cualquier esquema que solo distinga «datacenter único» de
«dispersión real» sirve contra el aficionado y no contra el adversario que importa. Tenlo delante
todo el rato.

## 1 · El filtro por el que pasa todo, y lo que ya está cerrado

### 1.1 · El teorema de exclusividad

`research/dag-poas-balizas-auditoria.md:30-38,66-78`: cualquier regla «una identidad-X publica bajo
un solo reloj» es derrotable **partiendo el espacio** entre identidades, mientras crear una identidad
cueste lo mismo por byte. Escapar exige un coste **no proporcional al espacio** (depósito, tasa), que
es importar un recurso ajeno: **PoS, rechazado**.

**Contrasta cada familia contra este teorema y dilo explícitamente.** Nota para la familia 1: la
latencia física **no se subdivide** entre identidades, así que no cae bajo el teorema por esa vía
— pero tiene su propio talón, que es quién verifica y qué presencia tiene el adversario.

### 1.2 · El hueco al que apunta la familia 1

`D2` en `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §1.4: **red y eclipse**. El propio repositorio dice
que es «**la palanca real de un Estado, no el reloj**» (`research/pot-aes-asic-chacha.md` §3) y que
sigue siendo «el hueco más serio frente al adversario de Katana». Estado: el eclipse **sí** se modeló
en la ronda 11b (`research/scripts/d8-ronda11b/informe.md`, instrumentos Python históricos, **no
heredables**), pero **falta integrarlo y validarlo para las reglas vigentes** (`C-NET`, `C-FLU`).

**No rehagas la ronda 11b.** Tu pregunta es distinta: ¿aporta la familia 1 algo que la ronda 11b no
tuviera?

### 1.3 · Lo que ya está descartado y no se reabre

Exclusividad por clave o sector (teorema de §1.1) · VDF por bloque anclado al padre (**umbral 27 %**,
`research/dag-poas-ancla-de-finalidad.md:313-319`) · certificados de niveles / NIPoPoW · prueba
recursiva para IBD · comités y firmas umbral (`AGENTS.md`: sin comités) · drand como beacon ·
ChaCha20 en vez de AES · muestreo PDP/PoR (E2) y parciales (E3) de `P-ZRX/P-PERMANENCIA/`.

### 1.4 · Cifra que mata sola a la familia 4, salvo que la refutes

`research/pot-aes-asic-chacha.md:36-45`: el ASIC de AES **realista** se estima en **1,5-2,5×**, no
19×; un 19× exigiría 25 ps por ronda de AES. La seguridad del PoT viene de la **latencia de la
instrucción encadenada**, no de su coste computacional. **Ábrelo antes de escribir una línea sobre
memory-hard.**

## 2 · Las cuatro familias, y qué hay que contestar de cada una

### 2.1 · Proof of latency / proof of location (la única con hueco grande enfrente)

Qué da, en el mejor de los casos: una **cota inferior de distancia física** —nadie puede fingir estar
más cerca de lo que está, porque la luz no va más rápido—, y con ello una comprobación de que los
pares de un nodo están realmente dispersos.

Contesta, con fuentes abiertas:

- **Quién verifica.** En una red sin permiso, los verificadores de latencia pueden ser del atacante.
  ¿Existe algún esquema que no colapse cuando una fracción de los verificadores es hostil? ¿Qué
  fracción aguanta?
- **Relés y proxies.** Un atacante con nodos en varias regiones responde desde el más cercano.
  ¿Queda algo en pie contra un adversario con **presencia global real**, que es el de §0?
- **Qué detectaría de verdad en ZEROX**: ¿un eclipse?, ¿un sybil concentrado?, ¿nodos que no
  reenvían? Sé concreto sobre **cuál de los tres vectores de `v2a`** (aislamiento, no reenvío,
  saturación) tocaría, si toca alguno.
- **Coste**: mensajes, estado por par, y si sobrevive a NAT, VPN y rutas asimétricas, que es la red
  real de un granjero doméstico.
- **Y lo más importante, la pregunta que puede salvar el encargo:** al estudiar esta familia vas a
  encontrar que buena parte de la defensa contra eclipse **no es criptografía, sino ingeniería de
  red** —diversidad de pares por ASN y por prefijo, gestión de tabla de direcciones, defensas tipo
  anti-Erebus, salida forzada de pares—. **Inventaría lo que de eso ZEROX no tiene y sí podría
  tener**, contrastándolo con `C-NET-01…33` y con `crates/zx-p2p/`. Eso es aplicable aunque las
  cuatro familias mueran, y puede ser el resultado más útil de este encargo. Márcalo como
  **ingeniería, no primitiva**, y no lo presentes como cierre de `D2`.

### 2.2 · DAS y compromisos de disponibilidad

**Separa dos cosas que se confunden y no son la misma**: la **validez** de la historia (es `D4`, el
arranque sucinto, y ya está estudiada: los niveles fallan y la prueba recursiva no decide la
canónica de GHOSTDAG) y la **disponibilidad** de los datos históricos, que hoy el repositorio declara
**fuera del consenso**, «capa social/económica» (`veritas/consenso/poda-post-v1/`, problema (3)).

- ZEROX hereda de Autonomys **erasure coding, `segment_commitment` y testigos KZG por record**
  (`PDF/autonomys-subspace`, `crates/subspace-verification/src/lib.rs:335-347`). **Ábrelo.** ¿Cuánto
  falta de ahí a un muestreo de disponibilidad hecho y derecho?
- ¿Convertiría eso la disponibilidad histórica de **problema social** en **problema verificable**? Si
  sí, di exactamente qué propiedad se gana y cuál **no**: DAS acredita que un dato está disponible
  **ahora**, no que alguien lo guarde ni que lo vaya a guardar.
- ¿Toca en algo el arranque sucinto? **Si tu respuesta es que sí, sospecha de ti mismo**: es el error
  clásico en esta familia. Demuéstralo o retíralo.
- Requisitos que DAS impone y que hay que declarar: número mínimo de muestreadores honestos, red de
  dispersión, y qué pasa con un adversario que responde a las muestras y nada más.

### 2.3 · Catalytic space

Va en **dirección contraria** a lo que ZEROX necesita: permite usar espacio ya ocupado sin
destruirlo, es decir, hace el espacio **más** reutilizable, cuando aquí se quiere que sea exclusivo.
**Mátala rápido como defensa.** Pero antes de cerrarla, contesta lo único que importa de ella:

- **¿Es un ataque?** Si existiera una construcción catalítica aplicable al formato de parcela de
  Autonomys, el espacio del atacante **abarataría**, porque podría farmear con disco que ya usa para
  otra cosa. ¿Existe algo así para este formato, o hay un obstáculo claro? Una frase con argumento
  basta si el obstáculo es evidente; si no lo es, es un hallazgo y hay que decirlo.

### 2.4 · Memory-hard como anti-ASIC del PoT

Lee §1.4 primero. Después contesta en pocas páginas:

- Los requisitos de una VDF —**secuencialidad inherente** y **verificación rápida y sucinta**— ¿los
  cumple alguna función memory-hard conocida (Argon2, scrypt, balloon)? Si no, la familia está
  muerta para este uso y se dice así.
- ¿Cambiaría el riesgo de ASIC lo suficiente para justificar tocar la primitiva del reloj, dado que
  el techo estimado es **1,5-2,5×**? Compara contra la alternativa ya estudiada (segundo VDF,
  `P-ZRX/P-REVELACION/`).
- Si mencionas VDFs de otras familias (grupos de clase, RSA), declara su **setup de confianza**: es
  lo que las descalifica o no en un diseño sin autoridad.

## 3 · Las preguntas

**F1** · Por cada familia: **¿cierra algo, acota algo, o nada?** Con el agujero nombrado según
`AGUJEROS-Y-SOLUCIONES.md` (A1, A2, B1-B3, C1-C3, D1-D6) y contrastada contra el teorema de §1.1.
**F2** · Proof of latency/location: **¿queda algo en pie contra un adversario con presencia global y
con parte de los verificadores bajo su control?** Sí o no, con el argumento.
**F3** · El **inventario de ingeniería de red anti-eclipse** que ZEROX no tiene y podría tener,
contrastado con `C-NET-01…33` y `crates/zx-p2p/`. Marcado como ingeniería, no primitiva.
**F4** · DAS: **¿vuelve verificable la disponibilidad histórica?** Qué propiedad se gana y cuál no.
Y la comprobación de que **no** has confundido disponibilidad con validez.
**F5** · Catalytic space **como ataque** al formato Autonomys: ¿existe o hay obstáculo claro?
**F6** · Memory-hard: ¿muerto para el PoT, o hay un caso? Con los requisitos de VDF delante.

## 4 · El instrumento

**Solo si algo sobrevive** y necesita cuantificarse. En ese caso:
`P-ZRX/P-LATENCIA/investigacion/veritas/red/<nombre>-v1/`, estructura de LINEO §1, aritmética exacta
antes de aproximar, RNG por réplica con semillas **no consecutivas**. **Si nada sobrevive, no
inventes un instrumento para justificar el encargo:** dilo y entrega la criba.

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-LATENCIA/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-LATENCIA/` es de solo lectura `PROMPT.md`. Al empezar y al terminar, desde la
raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-LATENCIA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 6 · Lecturas (ábrelas ENTERAS)

`veritas/LINEO.md` · **`research/dag-poas-balizas-auditoria.md`** (el teorema) ·
**`research/pot-aes-asic-chacha.md`** (el 1,5-2,5× y por qué la seguridad del PoT es latencia) ·
`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §1.4 (D2) y §6 · `research/scripts/d8-ronda11b/informe.md`
(qué se modeló ya del eclipse; **histórico, no heredable**) · `SPEC.md` §16 entera (`C-NET-01…33`) ·
`crates/zx-p2p/src/` (qué hay implementado de red) · `veritas/consenso/poda-post-v1/INFORME.md`
problema (3) · `PDF/autonomys-subspace` para los KZG de segmento. `research/README.md` para
localizar evidencia.

Fuentes externas: ábrelas si puedes; **lo que no abras, `no verificado`, y no inventes citas ni
números de sección.**

## 7 · Entregables (`P-ZRX/P-LATENCIA/investigacion/`)

- `INFORME.md` — **primera línea = el veredicto de las cuatro**, en una tabla de cuatro filas:
  cierra / acota / nada. Después F1-F6.
- `DECISIONES-PENDIENTES.md` — solo si algo sobrevive y Katana tiene que decidir. Si no sobrevive
  nada, dilo en una línea y no inventes decisiones.
- `PROGRESO.md` — bitácora con `date` y las comprobaciones de entrada y salida.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **Un «no» es un resultado.** No conviertas un «no» en un «podría estudiarse».
- **No presentes detección como prevención**, ni una mitigación con palabras de cobertura. Detectar
  un eclipse no es impedirlo.
- **Separa primitiva de ingeniería.** Lo de §2.1 último punto es ingeniería de red y se etiqueta así.
- **No fijes** ningún parámetro de consenso ni de red.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
