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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: el peso es **análisis de reglas** más **cuatro
modelos pequeños y exactos**: el quórum con granjeros domésticos, la tabla de poder bajo retención
adversaria, el peso por espacio reciente frente a stake acumulado, y el coste absoluto del atacante
para paralizar o para congelar la finalidad. El bloque te aplica entero. **Máximo 4 hilos**,
corridas de minutos; declara el presupuesto antes de ejecutar. Julia en CPU con `./veritas/julia.sh`;
**nada de Python**. Anota `uptime` antes de cada benchmark.

# ENCARGO P-STAKE · PROMPT-2 — Finalidad por votos, con lo ganado en juego

> **Éste es el segundo de dos encargos del mismo directorio, y se ejecuta DESPUÉS de `PROMPT-1.md`.**
> **Lo primero que haces:** comprobar que existe `P-ZRX/P-STAKE/investigacion-1/INFORME.md`. **Si no
> existe, PARA** y dilo en `PROGRESO.md`: `PROMPT-1` no ha terminado y este encargo depende de él.

## 0 · EL OBJETIVO, EN PALABRAS DE KATANA

Dos frases, del 2026-09-24, y las dos mandan:

> *«En una red P2P donde no se puede confiar en nadie, un sujeto (t), sea honesto o un atacante,
> tiene que dejar algo de valor en juego, y eso son tokens. En caso de que se descubra que el sujeto
> (t) hizo algo malo, esos tokens desaparecen.»*

> *«El problema central está aquí: ¿qué conductas malas se pueden descubrir en ZEROX? **Todas las
> conductas, sean buenas o malas, tienen que dejar evidencia**: por tanto el objetivo sería diseñar un
> mecanismo para que esto se cumpla. […] **Todo el que quiera participar tiene que poner algo en
> juego** de tal forma que si decide hacer algo malo se le pueda castigar.»*

### 0.1 · El límite que no se puede saltar, y la reformulación que sí funciona

**Demostrado en el repositorio:** R-6 de `P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md` — *«ninguna
condición de validez sobre `past(B)` obliga a publicar; en su rama privada **el atacante es la
autoridad**»*. Farmear es leer el propio disco y no deja rastro. **«Toda conducta deja evidencia»,
tomado al pie de la letra, es imposible — también en PoS**: allí nadie ve lo que un validador hace en
privado.

**Lo que PoS hace, y funciona:** no intenta **ver** la conducta oculta; le **quita el efecto** si no
pasa por un acto público firmado. Casper FFG, literal (verificado en `P-ZRX/P-STAKE/MAPA.md` §1.3):

> *«Two conflicting checkpoints cannot both be finalized unless **≥1/3 of the validators** violate
> one of the two Casper Commandments.»*

Y Casper se diseñó como *«a proof of stake-based finality system which **overlays an existing proof
of work blockchain**»*: **exactamente el patrón de este encargo**, votos con stake encima de una
cadena que no es PoS.

**Traducido al objetivo de Katana:** dentro del papel de **votar**, toda conducta deja evidencia —el
voto, el voto contradictorio, el voto que falta—. Fuera de ese papel no. **La pregunta de este
encargo es si eso basta para que ninguna conducta oculta afecte a lo finalizado.**

### 0.2 · Esto NO es lo que refutó `P-SECRETO` — no lo confundas

`P-ZRX/P-SECRETO/` evaluó la atestiguación **como condición de validez de cada bloque**, para
**romper el secreto**, y murió por dos vías: la firma a ciegas no se distingue de la informada
(R-10), y la ronda de firmas cabía en el slot con **probabilidad 0,219**, con el **57 %** de los
slots muriendo sin atacante con un 90 % de nodos despiertos.

| | `P-SECRETO` (refutado) | Este encargo |
|---|---|---|
| Qué hacen las firmas | Condición de validez **de cada bloque** | Votos **aparte**, sobre puntos de control |
| ¿Frena la producción? | **Sí** | **No**: PoST sigue produciendo; la finalidad llega después |
| ¿Exige probar lo que se vio? | **Sí**, y R-10 lo impide | **No**: solo se castiga **contradecirse** |
| Objetivo | **Romper** el secreto | Hacer el secreto **inútil** para lo finalizado |

`[lectura de Claude sobre fuentes verificadas, NO validada]`. **Si encuentras que la muerte de
`P-SECRETO` sí se transfiere a este mecanismo, ése es el resultado**, y va en la primera línea.

### 0.3 · Lo que ya existe — ESTE ENCARGO ES UNA RONDA QUE NUNCA SE LANZÓ

**`research/dag-poas-capa-finalidad.md`** (2026-09-09, *«HIPÓTESIS, SIN AUDITAR»*) ya diseñó una
finalidad por votos para ZEROX. **Parte de ella; no la reinventes.** Lo esencial:

| Regla | Qué fija |
|---|---|
| **R-FIN-15** | **Tabla de poder derivada de la cadena**: los bloques que cobran por R-FIN-8′ en `W_POWER = 3 600 s`, agrupados por `public_key`. **Resuelve el «PoAS no registra a nadie»** sin registro aparte |
| **R-FIN-16** | Comité por **sorteo ponderado**, `K = 4 000` plazas, restringido a claves con un bloque cobrado en los últimos `W_VIVO = 1 800 s` (prueba de vida) |
| **R-FIN-17** | Certificado con **≥ ⅔ de las `K` plazas**, firma agregada + mapa de bits |
| **R-FIN-18** | No se reorganiza por debajo del bloque certificado más profundo; sin certificado rige `F = 2 h`. **Un certificado solo adelanta la finalidad, nunca la retrasa** |
| **R-FIN-19** | **Doble firma: prueba pública y quema** de las coinbases **no maduras** de esa clave, y exclusión de las tablas durante `W_BAN = 30 días`. *«Nadie compra nada para entrar; el aval aparece solo al granjear.»* |

**Lo que la propia propuesta declara no demostrado (§7), y es tu punto de partida:**
- *«El castigo es pequeño y **no disuade a un atacante que ya decidió gastar `α = 0,3`** en
  espacio. Su función es contra el granjero **racional**.»*
- La participación real de un granjero doméstico `p`, sin la que la viveza es conjetura.
- *«Las plazas de una misma clave caen juntas»* — error que su autor reconoció: el cálculo trata las
  ausencias como independientes y **subestima la varianza del quórum**.
- El protocolo de acuerdo concreto (GossiPBFT de F3 es el candidato; **no se portó ni se leyó
  entero**).
- La interacción con el flujo de PoT: *«un certificado cruza flujos»*.

**Y su §8 dejó escrito un encargo de ronda adversarial que NUNCA se lanzó**, porque el 2026-09-10
Katana excluyó los comités. Sus cinco puntos son obligatorios aquí: el sesgo de la **tabla** por
retención de bloques, la composición del **quórum**, la **permanencia** (¿puede un certificado
finalizar algo que R-FIN-7 no habría finalizado?), las **dos cadencias**, y el certificado como
**vector de DoS**.

### 0.4 · La línea roja, y qué se te pide sobre ella

`AGENTS.md` línea 6: **«No hay staking ni comités de decisión.»** Katana se ha retractado de la
primera mitad para **recompensas ganadas** (no compradas). **La segunda sigue vigente.** Y la ronda
14C (`research/scripts/d14-sin-comite/informe.md`) define comité como *«conjunto de participantes,
fijo o muestreado, cuyos votos/firmas **deciden** el resultado de consenso»*, y excluye
expresamente *«comités por sortición (Algorand, P-040/F3)»* y *«conjuntos de validadores con
stake»*.

**Este encargo NO revoca esa regla, ni propone revocarla.** Igual que hizo `P-SECRETO` con la misma
línea: **se evalúa si funciona y se cuantifica su precio; la calificación la hace Katana.** Y la
pregunta que solo él puede responder necesita **hechos técnicos**, que son entregable tuyo (F8):

> **¿Un conjunto de votantes abierto —cualquiera entra con lo que ha ganado, sin cupo— es un
> «comité central»?** ¿Y con sorteo? ¿Y votando todos, sin sorteo?

### 0.5 · Lo que recibes de `PROMPT-1`

`P-ZRX/P-STAKE/investigacion-1/` contiene el diseño de las cuatro condiciones (E, A, R, C) para
castigar la **doble firma de bloques**. **Reutilízalo para castigar votos contradictorios.**
**Advertencia:** esos resultados **NO están validados por Claude** cuando tú los lees. Úsalos como
entrada, no como verdad: si encuentras un error, **anótalo en tu informe; no lo corrijas** en su
directorio.

### 0.6 · El orden que la propia propuesta pedía, y dónde está

`research/dag-poas-capa-finalidad.md` §9: *«Esto va DESPUÉS de cerrar P-038 […] medir `Δ`, y
entonces abrir esta como P-040.»* Estado al 2026-09-24:
- **Lo que temía —que el ancla cambiara otra vez— está resuelto**: `C-FLU-04` está en el SPEC desde
  el 2026-09-20.
- **P-038 sigue abierta.**
- **`Δ` sigue sin medir en red.** Solo hay simulación: **0,26–0,60 s** (`DMS-v0.1`). **Todo resultado
  que dependa de `Δ` —cadencia, temporizadores del acuerdo, ventana no finalizada— sale
  condicionado**, y así hay que etiquetarlo.

## 1 · LA PREGUNTA CENTRAL

> **¿Puede una capa de finalidad por votos públicos, con las recompensas ganadas como lo que está en
> juego, conseguir que ninguna conducta oculta afecte a lo finalizado sin dejar evidencia —
> funcionando con granjeros domésticos que se apagan—, y a qué precio?**

## 2 · LOS PUNTOS DUROS, que hay que atacar primero

### 2.1 · Peso: espacio reciente o lo ganado acumulado

R-FIN-15 pondera por **bloques ganados en la última hora**. `[lectura de Claude, NO validada]`: eso
da peso en **una hora** a quien alquile capacidad (el agujero C1, «capacidad relámpago»). Si el peso
fuera **lo ganado y retenido durante mucho tiempo**, el recién llegado con mucho espacio alquilado
pesaría poco durante mucho tiempo: sería una **integral del espacio en el tiempo**, y resistiría la
capacidad relámpago.

**Evalúa las dos, y la mezcla.** Y la pregunta que decide si la segunda es legal: **¿el peso de voto
es transferible?** Si lo es, **se compra** —y eso choca con el valor de Katana (`P-ZRX/P-RNG/PROMPT.md`
§2.1: *«nadie posee monedas que no haya minado»*)—. Si no lo es, ¿cómo se impide?

### 2.2 · El arranque, que cambia de signo según el peso

Con peso por **espacio reciente**, la capa **puede funcionar desde el génesis** (no necesita moneda:
cuenta bloques). Solo el **castigo** crece con el tiempo. Con peso por **lo ganado acumulado**, al
principio **nadie pesa** y la capa está parada. `[lectura de Claude]`. **Cuantifica** cuándo se
activaría cada una y qué pasa mientras.

### 2.3 · La viveza con granjeros domésticos

`(1 − α)·p ≥ ⅔` (capa-finalidad §4.C): con `α = 0,25` hace falta **88,9 %** de honestos firmando;
con `α = 0,33`, **99,5 %**. Rehaz el cálculo **con plazas correladas** (el error reconocido). Evalúa
**la fuga por inactividad** de Ethereum (`MAPA.md` §1.2) como alternativa o complemento a `W_VIVO`,
**con su riesgo conocido**: en una partición larga, **las dos mitades** pueden fugar el peso de la
otra y finalizar cadenas contradictorias sin que nadie viole un mandamiento.

### 2.4 · Cuánto hay en juego

R-FIN-19 quema las coinbases no maduras (`COINBASE_MATURITY = 12 000` bloques, 3,33 h) y su autor lo
llama «castigo pequeño». Con el diseño de **R** de `PROMPT-1` —retención quizá separada de la
madurez—, ¿cuánto puede llegar a estar en juego, qué le cuesta en liquidez al honesto, y **disuade
ya al adversario del modelo (`α = 0,3`) o solo al granjero racional**?

### 2.5 · La ventana no finalizada, y la tensión de `F`

La rama privada sigue funcionando **entre dos puntos de control**. ¿Cuánto se puede acortar esa
ventana, y de qué depende (`Δ`, agregación de firmas, fases del acuerdo)?

**Y una tensión que ningún informe recoge todavía** — la unió Claude al validar `P-ECLIPSE` el
2026-09-24, a partir de dos resultados escritos:
- `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` H-6: `C-FIN-01` acota el doble farmeo a `d < F_slots`, y
  **bajar `F` es la única palanca del consenso que funciona** contra él.
- `P-ZRX/P-ECLIPSE/investigacion/INFORME.md` F1: la duración mínima del eclipse que fabrica una
  partición de flujo sin cura es **`E_min = F_slots`**. **Bajar `F` abarata ese ataque.**

**`F` tiene signo opuesto en los dos agujeros mayores.** ¿Una finalidad por votos **hereda** esa
tensión o **escapa** de ella? Recuerda R-FIN-18: el certificado solo adelanta, y sin certificado rige
`F`. Qué recibe un nodo **eclipsado**, que quizá no ve los certificados, es la pregunta.

### 2.6 · Los flujos

La capa se escribió **antes** de las reglas de flujo del 2026-09-20. Hoy la validez del PoT es
**absoluta** (`C-FLU-13`) y los flujos **no se fusionan** (`C-FLU-14`). *«Un certificado cruza
flujos»*, dijo su autor. Examina qué significa eso con las reglas vigentes.

### 2.7 · El ataque nuevo que esta capa abre

capa-finalidad §6.1: *«**La mentira se vuelve permanente.** Hoy un ataque con éxito produce una
reorganización, que es temporal y visible. Con certificados, un atacante que reúna ⅔ del comité
congela su versión **para siempre**»*. Con peso por stake, **da el coste absoluto** —en espacio, en
tiempo y en recompensas acumuladas— de **(a)** paralizar la finalidad (⅓) y **(b)** congelar una
mentira (⅔). Bajo el modelo de amenaza de Katana, **distingue imposible de caro**.

## 3 · LO QUE ESTÁ FUERA

| Fuera | Por qué |
|---|---|
| **Revocar `AGENTS.md`** | Se evalúa y se cuantifica; decide Katana |
| **Moneda comprada** como peso o colateral | Excluida por el valor de Katana. **Sí puedes cuantificar** cuánto cambiaría, sin proponerla |
| **La rama privada fuera de lo finalizado** | **Demostrado** que no se ve (R-6, `P-CLAVE` F6). Mide cuánto queda en esa ventana; no intentes cubrirla |
| **Portar un protocolo de acuerdo** | Di **qué exige** el acuerdo (GossiPBFT/F3 es el candidato declarado); **no lo portes** |
| **Código en `crates/`** | Otro encargo trabaja allí. Este encargo termina en el borrador de reglas |

## 4 · ENTRADAS CONGELADAS

- Las cifras de `research/dag-poas-capa-finalidad.md` §4: la tabla del quórum, `6,5·10⁻¹⁰⁵` a
  `α = 0,33` con sorteo limpio, `K = 4 000`, y el certificado: **69,51 GB/año** con Ed25519 por
  plaza frente a **0,37 GB/año** con BLS agregado (1 000 plazas). **Su §5: BLS entra en la ruta de
  consenso.**
- Casper, Ethereum y Filecoin verificados en `P-ZRX/P-STAKE/MAPA.md` §1. F3 bajó la finalidad de
  Filecoin de **7,5 h a decenas de segundos**.
- `P-SECRETO`: `0,219` y `57 %` (§0.2). `P-CLAVE`: F4 y F6.
- `Δ` simulada: **0,26–0,60 s**. **No es medida de red.**

## 5 · LAS PREGUNTAS

**F1** · **¿Se transfiere la muerte de `P-SECRETO` a este mecanismo?** Si sí, **primera línea** y el
resto se subordina. Si no, di por qué con precisión.
**F2** · **Peso**: espacio reciente, lo ganado acumulado o mezcla. Resistencia a la capacidad
relámpago y **transferibilidad**.
**F3** · **Arranque**: cuándo se activa cada variante y qué pasa mientras.
**F4** · **Viveza**: el quórum con plazas correladas y granjeros domésticos; la fuga por inactividad y
su riesgo en particiones.
**F5** · **Cuánto hay en juego** y a quién disuade: al racional, al del modelo, a ninguno.
**F6** · **La ventana no finalizada y la tensión de `F`**: ¿se hereda o se escapa?
**F7** · **El coste absoluto** de paralizar (⅓) y de congelar una mentira (⅔).
**F8** · **Los hechos para la decisión de comités**: apertura, quién puede quedar excluido, sorteo o
no, topes, coste de agregación, dependencia de BLS. **Hechos, no calificación.**
**F9** · **Veredicto:** qué partes del objetivo de Katana se cumplen, cuáles no, y qué decide él.

## 6 · EL INSTRUMENTO

`P-ZRX/P-STAKE/investigacion-2/veritas/consenso/finalidad-votos-v1/`, estructura de LINEO §1
(`CONTRATO.md`, `MODELO.md`, `METODO.md`, `HIPOTESIS.md`, `PROCEDENCIA.md`, `HUELLAS.sha256`,
`BITACORA.md`, `Project.toml`, `Manifest.toml`, `run.jl`, `src/`, `test/`, `resultados/`).

- **Referencia transparente + kernel rápido**, comparados entre sí.
- **Aritmética exacta** en el quórum y en el coste del atacante: son colas, y ahí el flotante decide
  mal. `6,5·10⁻¹⁰⁵` no se calcula en `Float64`.
- **Monte Carlo:** semillas **NO consecutivas** (hallazgo de `P-ZRX/P-PUERTA/`), réplicas e IC.
- **`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`** obligatorio.
- **Resultados dentro de la carpeta del instrumento**, nunca en el CWD.
- **El conteo de tests que declares MUST salir de un artefacto que entregues.**

## 7 · ZONA DE TRABAJO Y HUELLAS

**Escribes SOLO en `P-ZRX/P-STAKE/investigacion-2/`.** Son de solo lectura `PROMPT-1.md`,
`PROMPT-2.md`, `MAPA.md` **e `investigacion-1/` entero**. No edites nada de `SPEC.md`, `TAREAS.md`,
`ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`. Al
empezar y al terminar, desde la raíz:

```bash
test -f P-ZRX/P-STAKE/investigacion-1/INFORME.md || echo "PROMPT-1 NO HA TERMINADO: PARA"
LC_ALL=C sha256sum -c P-ZRX/P-STAKE/ENTRADA-2.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las salidas en `PROGRESO.md`. **Aviso:** hay otro encargo trabajando en `crates/`, `ci/`,
`Cargo.*` y `P-ZRX/PIEZAS-DE-CODIGO/`; lo que aparezca `M` o `??` en tu entrada **no es tuyo**.
**Cita las reglas del SPEC por ID, nunca por número de línea.**

## 8 · LECTURAS (ábrelas ENTERAS)

**Empieza por aquí:** `research/dag-poas-capa-finalidad.md` **entero** · `P-ZRX/P-STAKE/MAPA.md` ·
`P-ZRX/P-STAKE/investigacion-1/INFORME.md` y su `BORRADOR-REGLAS.md`.

**Después:** `P-ZRX/P-SECRETO/investigacion/INFORME.md` (lo refutado, para no confundirlo) ·
`research/scripts/d14-sin-comite/informe.md` (la definición de comité y las alternativas **sin**
comité) · `P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md` (R-1, R-6 y R-10, sobre todo) ·
`P-ZRX/P-ECLIPSE/investigacion/INFORME.md` · `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` ·
`P-ZRX/P-CLAVE/investigacion/INFORME.md` · `SPEC.md` §7.1 (`C-FLU-*`), §12 (`C-FIN-01`,
`C-REORG-*`), §7.2 y §8 · `AGENTS.md` · `veritas/LINEO.md`.

**Advertencia de método:** en este repositorio, dos errores del mismo día salieron de leer una línea
citada en vez del documento entero.

## 9 · ENTREGABLES (`P-ZRX/P-STAKE/investigacion-2/`)

- `INFORME.md` — **primera línea = la respuesta a F1.** Después F2-F9.
- `BORRADOR-REGLAS.md` — las reglas en una familia **provisional `C-VOT-NN`**, marcadas
  **PROPUESTA** (verificada libre el 2026-09-24; **el nombre lo decide Katana**, `TAREAS.md` §4.2).
  Da la **correspondencia** con los nombres de trabajo `R-FIN-15…22` de la capa de finalidad.
  **Todos los valores como símbolos.**
- `DECISIONES-PENDIENTES.md` — las bifurcaciones para Katana con el coste de cada rama. Como mínimo:
  **la decisión de comités con los hechos de F8**, peso por espacio o por lo ganado, transferibilidad,
  y umbral de activación.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 10 · REGLAS DE VALIDEZ

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **«No se ha encontrado» y «no puede existir» son distintas.** Di cuál afirmas, cada vez.
- **La premisa no tiene privilegio.** Las lecturas de Claude de §0.2, §2.1 y §2.2 **no están
  validadas**; refutar cualquiera es un entregable completo.
- **No fijes NINGÚN valor:** `K`, `W_VIVO`, `W_POWER`, `W_BAN`, la cadencia, la retención, el umbral
  de activación. Son **entradas**.
- **No presentes un encarecimiento como un cierre.** Distingue siempre **imposible** de **caro**, y da
  el coste **absoluto**.
- **No califiques la regla de comités.** Da hechos; decide Katana.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
