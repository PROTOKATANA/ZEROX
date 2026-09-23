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
pequeño y exacto** de umbral bajo grinding. El bloque te aplica entero para ese modelo. **Máximo 4
hilos**, corridas de minutos; declara el presupuesto antes de ejecutar. Julia en CPU con
`./veritas/julia.sh`; **nada de Python**. Anota `uptime` antes de cada benchmark. **No ejecutes
ploteo ni `ab-proof-of-space`**: no hace falta para este encargo y su ruta no paralela tiene un
SIGSEGV reproducible.

# ENCARGO P-ANCESTRIA — ¿Puede el recurso pagarse de nuevo por cada ancestría sin caer al 27 %?

## 0 · Por qué existe este encargo

En PoW, el hash del bloque **compromete a los padres** y **es** el recurso escaso: las dos
propiedades viven en el mismo objeto, y por eso encontrar `L` ceros cuesta `2^L` hashes **sobre esa
ancestría**. **En PoST se separan**, y esa separación es la raíz de tres problemas a la vez: el
certificado de solución se pega a cualquier historia, el mismo espacio pesa en dos ramas, y las
pruebas de poda por niveles no funcionan (`veritas/consenso/poda-post-v1/INFORME.md:44-56`).

La revisión externa del 2026-09-18 dejó dos frases que son el encargo entero
(`veritas/consenso/poda-post-v1/PROCEDENCIA.md:110-119`):

> «lo que hace funcionar a PoW es más fuerte: **el recurso debe pagarse de nuevo por cada
> ancestría**. Un esquema que combine una condición cara pero **transferible** con otra barata
> ligada a los padres satisface las tres propiedades **literalmente** y sigue siendo inseguro.»
>
> «**El modelo excluye el PoT y sus flujos**, que es donde historias distintas podrían generar retos
> distintos. El Caso C lo trata en prosa; el instrumento no lo modela.»

**Nadie ha modelado eso.** Y es el único sitio donde la ancestría podría entrar en el recurso
**sin** pagar el precio del VDF por bloque, que ya se midió y es prohibitivo (§1.2).

## 1 · Entradas congeladas: verificado, y NO se rehace

### 1.1 · El teorema que acota cualquier propuesta tuya

`research/dag-poas-balizas-auditoria.md:30-38,66-78`: cualquier regla «una identidad-X publica bajo
un solo reloj» —sea X la clave, el sector o cualquier unidad— **es derrotable partiendo el espacio**
entre tantas identidades como relojes haya, **mientras crear una identidad nueva cueste lo mismo por
byte**. Es cierto por linealidad del ploteo más gratuidad de identidad. Escapar exige que crear
identidad cueste algo **no proporcional al espacio** (depósito, tasa), y eso es importar un recurso
ajeno al espacio: **PoS, rechazado al elegir PoST**.

**Contrasta contra este teorema cualquier cosa que propongas, y dilo explícitamente.** Si tu
propuesta es una regla de exclusividad por identidad, ya está refutada y el encargo termina ahí.

### 1.2 · La vía obvia, ya descartada y con precio medido

`research/dag-poas-ancla-de-finalidad.md:313-319`, «Considerado y descartado»:

> **Trunks por bloque (ronda 6, §5):** un VDF por bloque desde el padre seleccionado. Cada punta es
> una lotería: si el desafío se actualiza en cada bloque, `c = 1` y `φ₁ = e` (**umbral 27 %**); si se
> actualiza cada `c` bloques, vuelve la pregunta «cuál de los bloques del slot actualiza», que es el
> problema de acuerdo de las seis rondas. Y `k` timelords.

**Ese 27 % es la cota que tienes que batir.** Cualquier propuesta que acabe ahí o por debajo es un
«no» y se reporta como tal.

### 1.3 · Dónde está hoy la ancestría en ZEROX, y por qué no sirve

| Hecho | Dónde |
|---|---|
| El reto depende de **flujo y slot**, no de la ancestría: `reto(f, s) = blake3(aleatoriedad(f, s) ‖ LE64(s))` | `SPEC.md` `C-POT-03` |
| **Prohibida la circularidad**: el contexto se deriva del pasado DAG validado, **nunca del candidato** | `SPEC.md` `C-POT-06` |
| Los padres **sí** entran en la prefirma y en `pre_hash`, y el sello los liga… | `SPEC.md` `C-HDR-03`, `C-HDR-04` |
| …**pero firmar es gratis y el sello no es único**: el mismo `sol` se re-firma para otra ancestría sin tocar el disco. Es exactamente el patrón «cara transferible + barata ligada» que la revisión declara insuficiente | `SPEC.md` `C-HDR-04` y su nota; regresión en `crates/zx-core/tests/ed25519_no_unicidad.rs` |
| El nivel espacial se calcula **antes** de elegir padres (**D4**, 0 discrepancias en 500 pares) | `poda-post-v1/INFORME.md:50-52` |
| Validez del PoT **ABSOLUTA**, decidida por Katana el 2026-09-19/20 (`C-FLU-13`), y prohibido referenciar bloques de otro flujo (`C-FLU-14`) | `SPEC.md` §7.1 |

### 1.4 · La restricción que NO puedes romper

**La validez absoluta es una decisión de Katana, no una hipótesis.** Si tu propuesta hace que un
bloque sea válido en una rama e inválido en otra **según la vista del observador**, has reintroducido
la validez relativa, que abre el multistream y que Katana descartó expresamente. Un reto derivado de
datos que **viajan en la cabecera del propio bloque y están validados en su pasado** no es validez
relativa; uno que dependa de la cadena que el observador tiene por buena, sí. **Declara en qué lado
cae tu propuesta y demuéstralo.**

## 2 · Lo que tienes que hacer

### 2.1 · Formalizar la propiedad que falta (P4)

P1/P2/P3 del teorema D5 —comprobable sin el DAG, ligado a recurso, ligado a la ancestría— **no
capturan** la no-transferibilidad: el contraejemplo está dado en `PROCEDENCIA.md:110-116` y satisface
las tres literalmente. **Enuncia P4** («el recurso se paga de nuevo por cada ancestría») de forma que
el contraejemplo la viole, y demuestra que la viola. Sin P4 bien enunciada, el resto del encargo no
se sostiene.

### 2.2 · El eje que nadie ha explorado: la PROFUNDIDAD del anclaje

Ésta es la idea que el encargo pone a prueba, y es lo que lo separa de lo ya descartado.

El reto puede anclarse a la ancestría a distintas **profundidades**, y los dos extremos ya se
conocen:

- **`d = 0`** (el reto depende del **padre seleccionado**): máxima no-transferibilidad y **umbral
  27 %**, porque cada punta es una lotería y el atacante muele padres candidatos. **Descartado.**
- **`d = ∞`** (el reto depende solo del **flujo**, que es lo de hoy): **cero** grinding, pero dos
  ramas del **mismo** flujo comparten reto, así que no da P4 justo en el caso que importa —la rama
  privada y el doble farmeo ocurren **dentro** de un flujo.

**Entre los dos hay un continuo que nadie ha mirado.** Si el reto se anclara a un objeto de la
ancestría a profundidad `d` —por ejemplo el bloque a profundidad `d` de la cadena seleccionada, o el
ancla de inyección vigente, o un objeto de época—, entonces:

- dos ramas que **divergieron a menos de `d`** comparten reto (no hay separación),
- dos ramas que divergieron **antes** tienen retos distintos (**sí** hay separación),
- y para moler el reto el atacante tiene que **rehacer `d` bloques de ancestría**, lo que hace que el
  coste del grinding **crezca con `d`**.

**Las dos funciones que tienes que producir, y son el resultado:**

1. **`umbral(d)`** — la seguridad bajo grinding, con el mismo rigor con que se obtuvo `φ₁ = e` para
   `d = 0`. Reproduce primero ese caso conocido como control: **si tu modelo no devuelve 27 % con
   `d = 0`, está mal y no sigas.**
2. **`cobertura(d)`** — qué fracción de las conductas que nos preocupan quedan separadas: doble
   farmeo en rama privada, transferencia del certificado a otra historia, y niveles de poda.

Y la pregunta: **¿existe algún `d` donde `umbral(d)` sea aceptable y `cobertura(d)` no sea trivial?**
Si no existe, dilo con la demostración: cierra la puerta por escrito.

### 2.3 · La vía del flujo, que es la que la revisión señala

Aparte de la profundidad, examina lo que `PROCEDENCIA.md:117-119` apunta literalmente: **el PoT y
sus flujos**, «donde historias distintas podrían generar retos distintos». Con `C-FLU` ya redactado:

- ¿Qué separa hoy exactamente el identificador de flujo, y a qué granularidad? Lee `C-FLU-10`
  (derivación de `Chn(V_j)`), `C-FLU-12` (entropía de la inyección) y `C-FLU-13`/`C-FLU-14`.
- **¿Puede una rama privada permanecer en el mismo flujo que la pública?** Si la respuesta es sí
  —y creo que lo es—, el flujo **no** da P4 para el caso que importa, y hay que decirlo con esa
  claridad. Si es no, el doble farmeo estaría más acotado de lo que el repositorio cree, y **eso
  sería un hallazgo grande**: demuéstralo, no lo insinúes.
- ¿Puede la inyección de entropía (`C-FLU-12`) usarse como objeto de anclaje a profundidad media sin
  tocar `C-POT-03`? Es la candidata más barata, porque el ancla **ya es canónica por flujo**.

### 2.4 · El coste, si algo sobrevive

Solo para lo que quede vivo tras §2.2-§2.3: qué reglas del SPEC habría que tocar (por ID), si reabre
§6.1 (la cabecera está cerrada), qué le cuesta al granjero honesto en **lecturas de disco por slot**,
y cómo interactúa con el relé compacto, que hoy puede anunciar porque el billete **no** depende de
los padres.

## 3 · Las preguntas

**F1** · **P4 formalizada**, de modo que el contraejemplo «cara transferible + barata ligada» la
viole. Con demostración.
**F2** · **`umbral(d)`**, con el caso `d = 0` reproducido como control (**debe dar 27 %**).
**F3** · **`cobertura(d)`**: qué conductas separa cada profundidad.
**F4** · **¿Existe un `d` útil?** Sí con construcción, o no con demostración. **«No lo sé» no es
respuesta; «inconcluso con esta evidencia» sí, y entonces di qué falta.**
**F5** · **La vía del flujo**: ¿puede una rama privada quedarse en el flujo de la pública? ¿Da o no
da P4 el identificador de flujo? ¿Sirve el ancla de inyección como objeto de anclaje?
**F6** · Si algo sobrevive: su coste en reglas, en disco del honesto y en el relé; y si cae del lado
de la validez absoluta o de la relativa (§1.4).

## 4 · El instrumento

`P-ZRX/P-ANCESTRIA/investigacion/veritas/consenso/ancestria-reto-v1/`, estructura de LINEO §1.
Aritmética **exacta** (`Rational{BigInt}` o intervalos) para los umbrales: son colas y una
aproximación normal aquí no vale. **Control obligatorio:** `d = 0` reproduce el 27 % conocido; si no,
el instrumento está mal. Si usas Monte Carlo, RNG por réplica con semillas **no consecutivas** (las
consecutivas de `StableRNG` sesgan el MC, hallazgo de `P-ZRX/P-PUERTA/`). **Un test que compara una
fórmula consigo misma no es un test.**

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-ANCESTRIA/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-ANCESTRIA/` es de solo lectura `PROMPT.md`. Al empezar y al terminar, desde la
raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-ANCESTRIA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 6 · Lecturas (ábrelas ENTERAS)

`veritas/LINEO.md` · **`veritas/consenso/poda-post-v1/INFORME.md` y su `PROCEDENCIA.md` enteros**
(son el origen del encargo) · **`research/dag-poas-balizas-auditoria.md` entero** (el teorema; es el
filtro de §1.1) · `research/dag-poas-ancla-de-finalidad.md` §10 y la ronda 6 §5 que cita (el 27 %) ·
`SPEC.md` §7.1 entera (`C-POT-01…08`, `C-FLU-01…22`), §6.1-§6.2 (`C-HDR-03`, `C-HDR-04`, `C-HDR-07`)
y §11 (`C-GD-10`, `C-GD-11`) · `P-ZRX/P-2.1/SINTESIS.md` (por qué se eligió validez absoluta) ·
`research/dag-nativo-poas-propuesta.md` §3 (espina + fardos: la otra vía que escapa al teorema, para
que no la reinventes) · `research/README.md`.

**Advertencia de método, lección del 2026-09-21 en este repositorio:** dos errores del mismo día
salieron de leer una línea citada en vez del documento entero.

## 7 · Entregables (`P-ZRX/P-ANCESTRIA/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F4**: si existe un `d` útil, o por qué no puede
  existir. Después F1-F6.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`.
- **Contrasta explícitamente contra el teorema de §1.1** cualquier propuesta, y contra el 27 % de
  §1.2. Una propuesta que no bata esa cota es un «no».
- **Di de qué lado cae** de la validez absoluta (§1.4). Es la restricción dura del encargo.
- **No fijes** ningún parámetro de consenso: `d`, `k`, `P`, `I` y las profundidades son entradas.
- **No presentes una mejora de coste como un cierre**, ni uses palabras de cobertura.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
