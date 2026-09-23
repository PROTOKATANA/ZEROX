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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: el peso es **análisis de reglas** más un **modelo
pequeño y exacto** de captura de sorteo y de viveza. El bloque te aplica entero para ese modelo.
**Máximo 4 hilos**, corridas de minutos; declara el presupuesto antes de ejecutar. Julia en CPU con
`./veritas/julia.sh`; **nada de Python**. Anota `uptime` antes de cada benchmark.

# ENCARGO P-SECRETO — ¿Puede exigirse algo que no se pueda cumplir en secreto?

## 0 · EL CONTEXTO: qué problema se intenta resolver, y por qué este encargo es el que queda

**Lee `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` entero antes que nada.** Resume ocho encargos y evita que
repitas trabajo ya hecho. Lo esencial:

**El problema.** El **doble farmeo**: el mismo espacio produce peso en dos ramas a la vez, porque en
PoST el disco **no se consume al leerlo**. Una lectura produce un certificado válido para cualquier
historia. Eso abarata el ataque de mayoría: con `α* = (1 − β_d − 2β_x)/2`
(`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` F1, **`demostrado`**), cada unidad de espacio prestado
baja el umbral, y **el espacio que abandona la pública (`β_x`) lo baja el doble** que el que farmea
doble (`β_d`).

**Ocho vías cerradas, todas con números** (rutas en `ESTADO-DOBLE-FARMEO.md` §1): identidad de
billete por pieza, castigo por clave, castigo por parcela, maduración por registro (**imposibilidad
demostrada**), anclaje del reto a la ancestría, tasa fija por identidad, pata de trabajo rival y
sellado asimétrico ligado a la rama.

**Y la causa común de que cayeran las de castigo no es el recurso: es el SECRETO.** El atacante
construye la rama privada sin publicarla y **solo la publica cuando ya pesa más**; si no llega a
pesar más, no publica y no ha dejado ninguna evidencia. Es el caso `κ = 0`, y
`P-ZRX/P-CLAVE/investigacion/INFORME.md` F6 lo midió: **no existe ningún par `(ρ_ret, T_v)` que
valga frente a él**, para ningún valor de castigo. **Un castigo infinito aplicado con probabilidad
cero sigue disuadiendo cero.**

**La decisión de Katana que abre este encargo (2026-09-23):** *«es preferible ganar seguridad antes
que garantizar un secreto»*. El anonimato del productor en PoST **no es una propiedad elegida**: es
un efecto secundario de que nadie se registre. Katana acepta evaluar su renuncia. **Evaluar, no
adoptar.**

**Por qué este encargo y no otro.** Si el secreto se puede romper, el doble farmeo deja de ser
inatacable: vuelven a la mesa el castigo, la exclusividad y varias defensas hoy cerradas **solo**
porque no hay evidencia. Si no se puede romper, se cierra la última familia y la decisión pasa a ser
de arquitectura, no de criptografía.

## 1 · La pregunta central, y el obstáculo que hay que resolver o certificar

> **¿Existe alguna condición de validez de bloque, evaluable sobre `past(B)`, que un productor NO
> pueda satisfacer sin haber publicado?**

**El obstáculo, y es lo primero que tienes que atacar** `[lectura de Claude, NO validada]`:

> **En su rama privada, el atacante es la autoridad.** Toda condición que el consenso evalúe sobre
> `past(B)` la satisface él dentro de su propia rama: si le exiges historial reciente, se lo fabrica;
> si le exiges un compromiso previo, lo incluye; si le exiges referenciar datos públicos, los
> referencia — **ver lo público no obliga a publicar**.

**Si ese obstáculo es un teorema, dilo y demuéstralo**, porque entonces la respuesta a la pregunta
central es **no** y el encargo se resuelve por ahí. La forma candidata del enunciado, que tienes que
afinar o romper:

> Una condición es infalsificable en rama privada **solo si** depende de información que el atacante
> **no puede producir por sí mismo**. Y eso deja tres fuentes: **(a) otros participantes**,
> **(b) una cadena externa**, **(c) el tiempo físico**.

**(c) ya está evaluada y cerrada:** el tiempo **no es rival** —dos núcleos, dos líneas de VDF, dos
ramas— (`P-ZRX/P-RIVAL/` F1 y su H5; `P-ZRX/P-SELLO/` O5). **No la reabras**; úsala como control de
que tu formalización clasifica bien.

## 2 · Entradas congeladas: NO se re-miden ni se rehacen

| Hecho | Fuente |
|---|---|
| **No hay región frente a `κ = 0`** (publicar solo la rama ganadora) ni frente a censura total | `P-ZRX/P-CLAVE/investigacion/INFORME.md` F6 |
| `α* = (1 − β_d − 2β_x)/2`; **`β_x` baja el umbral el DOBLE que `β_d`** | `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` F1, `demostrado` |
| La evidencia de equivocación existe **solo cuando ambas firmas se publican** | `P-ZRX/P-EQUIVOCACION/investigacion/INFORME.md` §8 |
| **`C-FIN-01` limita la selección a `d < F_slots`**: el doble farmeo solo sirve dentro de esa ventana | `SPEC.md` §12 y §7.1 (cítalo por ID, no por línea) |
| **Validez del PoT ABSOLUTA, decidida por Katana el 2026-09-19/20** (`C-FLU-13`); la relativa a la cadena seleccionada **abre el multistream** | `SPEC.md` §7.1; `P-ZRX/P-2.1/SINTESIS.md` |
| `Δ` simulada **0,26-0,60 s**; `τ = 1 s`; `λ ≈ 1 b/s`; padres típicos 1,14-1,39 | `veritas/finalidad/delta-medido-v1/` (DMS-v0.1) |
| El teorema de exclusividad: toda regla por identidad se evade partiendo el espacio | `research/dag-poas-balizas-auditoria.md:30-38,66-78` |
| **`α_blue_work ≤ α_bytes` es FALSO** (6/13 = 0,4615 con `f = 0,3`) | `P-ZRX/P-PUENTE-ESPACIO-TASA/.../INFORME-CORRECCION.md` C1 |

## 3 · Las dos líneas rojas, y qué se te pide exactamente sobre ellas

`AGENTS.md` declara: **«No hay staking ni comités de decisión.»** Y el ancla externa está catalogada
como **«ayuda al operador, nunca regla de consenso»** (`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` D4).

**Este encargo NO revoca ninguna de las dos, y no debes proponer revocarlas.** Lo que se te pide es
distinto y más útil:

- **Determinar si la distinción se sostiene técnicamente**: un conjunto de nodos que **atestigua que
  vio un bloque** ¿es un «comité de decisión» en el sentido que `AGENTS.md` prohíbe, o es otra cosa?
  No elige cadena, no vota la canónica, no tiene poder de veto sobre el orden. **Analiza qué decide
  de verdad y qué no**, y deja la calificación política a Katana.
- **Cuantificar el precio de cada una**, para que la decisión se tome con la factura delante.

## 4 · Lo que hay que hacer

### 4.1 · Formalizar y decidir el obstáculo (§1)

Define «condición infalsificable en rama privada» con precisión, con el adversario declarado, y
decide el enunciado candidato. **Controles obligatorios:** tu formalización debe clasificar como
**falsificables** el compromiso previo de intención, el historial reciente de clave y la referencia a
datos públicos —los tres se satisfacen dentro de la rama privada—, y como **no falsificable** (si lo
es) la atestiguación por terceros. Si tu formalización no reproduce eso, está mal.

### 4.2 · Atestiguación por sorteo: la candidata concreta, con números

La forma que hay que evaluar: **un bloque solo es válido si lleva firmas de `k` nodos sorteados** por
el PoT del slot y **ponderados por espacio**.

- **Probabilidad de captura.** Si el atacante controla una fracción `α` del espacio, la probabilidad
  de que los `k` sorteados sean todos suyos es `≈ α^k` (declara el modelo de muestreo: con o sin
  reemplazo, y si el ponderado por espacio cambia la cuenta). Publica la tabla `k × α`.
- **Qué `k` hace la rama privada inviable** a la tolerancia que declares, y **cómo interactúa con
  `F_slots`**: el atacante necesita la cadena entera de `d < F_slots` bloques, no uno.
- **El efecto sobre el umbral**: mete la atestiguación en la superficie `α*` y di si sube, y cuánto.
- **El coste en la cabecera y en la red**: `k` firmas por bloque a `λ ≈ 1 b/s`, y qué le hace al
  presupuesto de `Q2` (cabecera ≤ ~1 kB típica) y al relé compacto.

### 4.3 · El precio real, que es la viveza — y es donde esto puede morir

**Ésta es la objeción más seria y hay que atacarla de frente, no al final.**

Exigir firmas de terceros convierte un problema de seguridad en uno de **disponibilidad**: si los
sorteados no responden —partición, censura, simplemente estar apagados—, **no se produce bloque**.

- Con `Δ = 0,26-0,60 s` y `τ = 1 s`: ¿cabe una ronda de recogida de `k` firmas dentro del slot?
  **Da el número.** Si no cabe, la vía está muerta por latencia y se dice así.
- ¿Qué fracción de nodos hay que suponer despierta y respondiendo? ¿Qué pasa con `k` firmas cuando
  esa fracción baja?
- **Partición de red:** con la red partida, ¿se detiene la producción en los dos lados? Contrasta con
  lo que hoy hace `C-FLU-22` y con el perfil 1a.
- **Y el vector nuevo que esto abre:** un atacante que **censura las respuestas** de los sorteados
  puede parar la cadena honesta sin tener espacio. Cuantifica qué le cuesta.

### 4.4 · El ancla externa, con la misma frialdad

Compromiso periódico en una cadena ajena. Evalúa: **granularidad** (anclas cada `N` minutos no
impiden reorganizaciones cortas — ¿qué profundidad cubre?), **dependencia** (qué pasa si la cadena
externa se detiene, se reorganiza o censura), y **coste**. Y di si cambia algo que la vía (c) —el
tiempo— ya no cubriera.

### 4.5 · Riesgo que tienes que vigilar en todo el encargo

Si tu condición depende de **la vista del nodo** en vez de `past(B)`, has reintroducido la **validez
relativa a la cadena seleccionada**, que abre el multistream y que Katana **descartó expresamente**.
**Declara de qué lado cae cada propuesta y demuéstralo.**

## 5 · Las preguntas

**F1** · «Condición infalsificable en rama privada», formalizada, con los controles de §4.1. **¿Es
el obstáculo de §1 un teorema?** Demuéstralo o rómpelo con un contraejemplo construido.
**F2** · Si es teorema: las tres fuentes, cuáles quedan vivas y por qué (la (c) ya está cerrada).
**F3** · Atestiguación por sorteo: `k` frente a `α`, el `k` necesario, el efecto sobre `α*` y el
coste en cabecera y red.
**F4** · **La viveza**: ¿cabe la recogida de `k` firmas en el slot con la `Δ` medida? ¿Qué pasa bajo
partición y bajo censura de respuestas? **Si no cabe, dilo en la primera línea.**
**F5** · ¿Se sostiene técnicamente la distinción entre **atestiguar** y **decidir**? Qué decide un
atestiguador y qué no, sin calificarlo políticamente.
**F6** · **Veredicto:** qué se puede cerrar de `κ = 0`, a qué precio, y qué decide Katana.

## 6 · El instrumento

`P-ZRX/P-SECRETO/investigacion/veritas/consenso/secreto-atestiguacion-v1/`, estructura de LINEO §1.
Aritmética **exacta** (`Rational{BigInt}` o intervalos) para las colas de captura: `α^k` con `k`
grande es justo donde la aproximación flotante falla. Si usas Monte Carlo: RNG por réplica con
semillas **no consecutivas** (hallazgo de `P-ZRX/P-PUERTA/`), réplicas e IC declarados. **Un test que
compara una fórmula consigo misma no es un test**, y en esta serie ya han aparecido tres: declara
cómo los has evitado y separa en una tabla las rutas independientes de las que no lo son.

## 7 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-SECRETO/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-SECRETO/` es de solo lectura `PROMPT.md`. Al empezar y al terminar, desde la
raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-SECRETO/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. **Aviso:** hay otro encargo trabajando en `crates/`, `ci/`,
`SPEC.md` y `TAREAS.md`; lo que ya aparezca `M` o `??` en tu entrada **no es tuyo**. Y por esa misma
razón **cita las reglas del SPEC por ID, nunca por número de línea**: las líneas se desplazan.

## 8 · Lecturas (ábrelas ENTERAS)

**`P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` entero** (el contexto; empieza por aquí) ·
`veritas/LINEO.md` · **`P-ZRX/P-CLAVE/investigacion/INFORME.md`** F6 (por qué `κ = 0` lo mata todo) ·
**`P-ZRX/P-PRESTAMO/investigacion/INFORME.md`** F1 (la superficie `α*`) ·
`P-ZRX/P-EQUIVOCACION/investigacion/INFORME.md` (qué evidencia existe y cuándo) ·
`P-ZRX/P-RIVAL/investigacion/INFORME.md` F1 y sus hipótesis (por qué el tiempo no es rival) ·
`research/dag-poas-capa-finalidad.md` (**la capa de comité ya se estudió y se descartó: lee por qué,
y di si tu propuesta cae en lo mismo**) · `research/dag-poas-balizas-auditoria.md` (el teorema) ·
`SPEC.md` §7.1 (`C-FLU-*`, `C-POT-*`), §12 (`C-FIN-01`) y §16 (`C-NET-*`) · `AGENTS.md` ·
`research/README.md`.

**Advertencia de método:** en este repositorio, dos errores del mismo día salieron de leer una línea
citada en vez del documento entero.

## 9 · Entregables (`P-ZRX/P-SECRETO/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F1**: si el obstáculo es teorema o no. Después
  F2-F6. Si la viveza mata la vía (F4), dilo también en esa primera línea.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana con el coste de cada rama. Si no
  hay nada que decidir, una línea y sin inventar decisiones.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 10 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **«No se ha encontrado» y «no puede existir» son distintas.** Di cuál afirmas, cada vez.
- **La premisa no tiene privilegio.** La idea de atacar `κ = 0` es **de Claude y no está validada**;
  si la refutas, ése es el resultado y es un entregable completo.
- **No revoques `AGENTS.md`** ni propongas hacerlo. Analiza y cuantifica; decide Katana.
- **No presentes un encarecimiento como un cierre**, ni uses palabras de cobertura.
- **No fijes** ningún parámetro: `k`, `α`, la tolerancia y los presupuestos son **entradas**.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
