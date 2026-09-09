# Palancas de rendimiento para ZEROX, y qué pasa con 600 pagos por segundo

**2026-09-09** · Encargo de Katana: «aplica estas y déjalas bien documentadas», sobre cinco palancas
de rendimiento, más la pregunta concreta del marketplace: **¿qué pasa si se hacen 600 pagos por
segundo?** · Estado de cada palanca al final de su sección. Scripts en `research/scripts/rendimiento/`.

> **HALLAZGO PRINCIPAL, y no estaba en la lista de pendientes del proyecto.** Las constantes que
> están expresadas **por bloque** se calibraron para un bloque cada 120 s y **nadie las rederivó**
> cuando el DAG pasó a un bloque por segundo, 120 veces más rápido. Afecta a la emisión de moneda, a
> la zona libre de tamaño de bloque, a la madurez de coinbase y a la ventana anual. Verificado hoy
> ejecutando la curva del propio SPEC (`verif_emision_lambda.py`): a `λ = 1 b/s` el techo de mil
> millones se cruza en **30,9 días** en vez del año 10,15, y la emisión de cola es del **100,92 %
> anual** en vez del 0,84 %. La primera decisión de rendimiento que hay que tomar es **cuál es el
> presupuesto de bytes a `λ = 1`**, porque de ella cuelga todo lo demás. Ver §0.

---

## 0 · Lo que hay que decidir antes que nada: el presupuesto a un bloque por segundo

`ZONA_LIBRE = 100 000` bytes está definida **por bloque** (`SPEC.md:923`), y la nota que la justifica
calcula el crecimiento como *«26,3 GB/año (262 800 bloques/año × 100 KB)»* (`SPEC.md:936`). Esos
262 800 bloques al año son un bloque cada 120 s. A un bloque por segundo hay **dos lecturas y ninguna
está decidida** (`verif_600tps.py` §A):

| Lectura | Zona libre por bloque | Capacidad libre | Crecimiento | SSD de 4 TB |
|---|---:|---:|---:|---:|
| **(a) Literal**: se conserva la constante | 100 000 B | **285,7 tx/s** | 3 154 GB/año | lleno en 1,27 años |
| **(b) Presupuesto**: se conservan los 26,3 GB/año | 833 B | **2,4 tx/s** | 26 GB/año | lleno en 151 años |

La hoja «ZEROX en números» publica 2,4 tx/s, que es la lectura (b). El SPEC, leído al pie de la letra,
dice (a). **Son 120 veces de diferencia en capacidad y en crecimiento de la cadena.** Cualquier
conversación sobre rendimiento empieza aquí.

**Estado: DECISIÓN PENDIENTE DE KATANA.** Va junto con la recalibración de la emisión (§6), porque las
dos vienen del mismo sitio y una sin la otra deja el sistema incoherente.

---

## 1 · El caso concreto: 600 pagos por segundo en el marketplace

Simulado con las reglas exactas del SPEC sobre una **cadena madura**
(`verif_600tps_maduro.py`; `Mlt` clavada en la zona libre, que es lo que ocurre durante los primeros
131 400 bloques porque mover la mediana larga exige llenar media ventana, 1,52 días).

**600 pagos por segundo transparentes son 210 000 bytes por bloque.** Qué pasa, minuto a minuto:

| Bloque | Límite duro | Tamaño real | Subsidio del granjero | Cola |
|---:|---:|---:|---:|---:|
| 1 | 200 000 B | 200 000 B | **0 %** | 29 tx |
| 50 | 200 000 B | 200 000 B | 0 % | 1 429 tx |
| 51 | 300 000 B | 300 000 B | 0 % | 1 171 tx |
| 60 | 400 000 B | 210 000 B | 99,7 % | 0 |
| 150 en adelante | 420 000 B | 210 000 B | **100 %** | 0 |

**La respuesta corta: el protocolo lo absorbe en 102 segundos y luego funciona sin penalización.**
Durante el minuto y medio de transición los granjeros pierden 101 386 ZZK de subsidio entre todos,
porque la mediana corta tarda 50 bloques en enterarse de que hay más demanda. Después, la mediana
efectiva sube hasta la demanda y los bloques de 210 000 bytes dejan de estar penalizados.

**El techo, y dónde está de verdad:**

| Demanda | Se estabiliza en | Veredicto |
|---:|---:|---|
| 285 tx/s | 1 s | absorbida, es la zona libre |
| **600 tx/s** | **102 s** | **absorbida** |
| 2 000 tx/s | 192 s | absorbida |
| 10 000 tx/s | 369 s | absorbida |
| 28 571 tx/s | — | **cola creciendo**, es el tope estructural |

El tope estructural es `2 · FACTOR_SURGE · Mlt` = 10 MB por bloque = **28 571 tx/s**, y por encima la
cola no se vacía nunca. Así que 600 pagos por segundo no son un problema de consenso: caben 47 veces
por debajo del techo.

**Dónde sí duele, y es lo único que duele:**

| Recurso del nodo doméstico | Techo | 600 tx/s |
|---|---:|---|
| CPU verificando firmas | 84 211 tx/s | ni la roza |
| Red, 50 Mbps de subida con 8 pares | 2 232 tx/s | cabe, al 27 % |
| **Almacenamiento, SSD de 4 TB** | **72 tx/s** | **la revienta por 8,3×** |

600 pagos por segundo transparentes son **6,62 TB al año**, y llenan un SSD de 4 TB en **7,2 meses**.
Si son pagos blindados del pool Orchard, 15,52 TB al año y **3,1 meses**.

**Conclusión para el marketplace: 600 pagos por segundo son perfectamente viables en el consenso, y
matan al nodo doméstico.** La pregunta no es si la cadena aguanta, es quién puede seguir corriendo un
nodo completo cuando la cadena crece a ese ritmo. Es la misma decisión de §0, con un número encima.

**Estado: MEDIDO.** Las dos salidas están en `research/scripts/rendimiento/`.

---

## 2 · Palanca 1 — Subir el presupuesto de bytes

**Qué es.** No inventar nada: decidir que la cadena puede crecer más. De 2,4 a unas 72 transacciones
por segundo antes de que el disco de un nodo doméstico se llene en cinco años.

**Lo que compra.** Es la palanca mayor y la única que no requiere investigación.

**Lo que cuesta.** Exactamente la propiedad que el proyecto protege: que un particular pueda correr un
nodo completo. A 72 tx/s la cadena crece 0,79 TB al año; a 600 tx/s, 6,62 TB al año.

**Cómo interactúa con lo demás.** Sube la presión sobre la palanca 4 (ancho de banda del chismorreo) y
sobre el cliente ligero, que hoy no existe y que la capa de finalidad resucitaría.

**Estado: DECISIÓN DE KATANA, bloqueada por §0 y §6.** No se puede subir un presupuesto que todavía no
está definido a `λ = 1`, y no se puede tocar sin rederivar la emisión.

---

## 3 · Palanca 2 — Ejecución desacoplada, o «dominios»

**Qué es.** Separar quién ordena las transacciones de quién las ejecuta. Autonomys lo tiene **en
producción**: los granjeros mantienen el consenso por espacio y almacenan la historia; unos operadores
aparte ejecutan las transacciones en cadenas secundarias llamadas dominios. La capacidad de ejecución
escala por su lado sin tocar el consenso.

**Lo que compra.** Es la palanca equivalente al DAG en su día: no es afinar un número, es repartir el
trabajo de otra forma. Y la seguridad se conserva aunque la mayoría de operadores sea deshonesta,
mientras la mayoría de granjeros sea honesta.

**La ventaja que nos regala nuestro propio consenso.** Una arquitectura así necesita que los datos
estén disponibles y repartidos, y **nosotros ya archivamos toda la historia con codificación de
borrado repartida entre granjeros**. Ese ingrediente, que a otros les cuesta una capa entera, lo
tenemos gratis por haber elegido Proof of Archival Storage.

**Lo que cuesta, y es lo que a Katana le importará.** En Autonomys los operadores **ponen dinero en
juego** para participar, bajo un esquema de participación nominada con recorte por mala conducta.
Reintroduce el mecanismo que el proyecto rechazó, aunque **confinado a la ejecución**: quién produce
bloques y quién cobra sigue dependiendo solo de espacio físico verificable.

**La pregunta que hay que responder antes de nada:** si se puede hacer que los operadores de ejecución
no necesiten poner dinero, o si se acepta ese coste sabiendo que el consenso sigue limpio.

**Estado: LÍNEA DE INVESTIGACIÓN, alta prioridad, después de cerrar P-038.** Al mismo nivel que la capa
de finalidad.

---

## 4 · Palanca 3 — Agregación de firmas

**Qué es.** Las firmas son la parte más gorda de una transacción. Agregarlas permite que todas las
entradas de una transacción compartan una sola firma en vez de una cada una.

**El número, con fuente.** La investigación de Bitcoin sobre agregación entre entradas mide una
**reducción del 20,6 % en el tamaño de la transacción media**. Funciona porque las firmas de Schnorr
tienen una propiedad de linealidad que las de curva elíptica clásicas no tienen.

**Lo que compra para nosotros.** Con el mismo presupuesto, de 2,4 a unas 3 transacciones por segundo;
o, en la lectura (a), de 285 a unas 360. Es modesto.

**Lo que cuesta.** Casi nada **si se adopta la capa de finalidad**, porque esa capa ya obliga a meter
la criptografía de curvas emparejadas que hace falta. Sin ella, es una dependencia nueva en la ruta de
consenso solo por un 20 %.

**Estado: PENDIENTE, atada a la capa de finalidad.** Si la capa se adopta, esto sale casi gratis; si
no, no compensa por sí sola.

---

## 5 · Palanca 4 — Erlay, para el ancho de banda del chismorreo

**Qué es.** No cambia lo que crece la cadena, cambia lo que gasta un nodo en contarle a sus vecinos qué
transacciones ha visto. Hoy cada nodo anuncia cada transacción a todos sus pares; Erlay sustituye ese
anuncio masivo por una reconciliación periódica de conjuntos.

**El número, con fuente.** Bitcoin lo cifra entre un **40 %** en pruebas prácticas y más del 80 % según
otras estimaciones, sobre el ancho de banda de retransmisión.

**Lo que compra para nosotros.** Aleja la segunda pared de la tabla, la de red, que hoy está en 2 232
transacciones por segundo con 8 pares. Importa precisamente **porque hace más cómoda la palanca 1**.

**Lo que cuesta.** Implementación en `zx-p2p`, que ya tiene pendiente cerrar el relé compacto y la
puntuación de pares. No toca consenso.

**Estado: MEJORA DE INGENIERÍA, sin bloqueo.** Encaja en B7 del plan de crates.

---

## 6 · Palanca 5 — Canales de estado

**Qué es.** Dos partes abren un canal, hacen mil pagos entre ellas sin tocar la cadena, y solo publican
el resultado. Es lo de Lightning en Bitcoin y lo de Hydra en Cardano.

**Lo que compra.** Capacidad prácticamente ilimitada fuera de la cadena, y es **la respuesta natural
para un marketplace**: comprador y plataforma, o plataforma y vendedor, interactúan muchas veces entre
las mismas dos partes. Los 600 pagos por segundo se convierten en un puñado de liquidaciones al día.

**Lo que cuesta.** No toca el diseño base en absoluto, que es su virtud y su límite: es una capa aparte
con su propia complejidad, su propia custodia y sus propios modos de fallo.

**Estado: LÍNEA ABIERTA, sin bloqueo, y la más prometedora para el caso de uso concreto de Cortex.**

---

## 7 · Lo que NO sirve, para no perseguirlo

- **Ejecución en paralelo** (Sealevel de Solana, Block-STM de Aptos y Sui): reparte el trabajo de
  ejecutar entre varios núcleos. Nuestra medición dice que en verificación de firmas aguantamos 84 211
  por segundo. Estamos cuatro órdenes de magnitud por debajo de que eso sea el problema.
- **Bloques más grandes o más frecuentes**: el DAG ya reparte los mismos bytes en 120 bloques pequeños
  en vez de uno grande. El total no cambia.

---

## 8 · La recalibración de constantes: lo que el DAG rompió sin que nadie lo anotara

Verificado hoy con `verif_emision_lambda.py`, que reproduce **exactamente** los números que el propio
SPEC declara a 120 s (recompensa inicial 1 907,35 ZZK, caída al tail en el año 8,16, cruce de los mil
millones en el año 10,15, inflación perpetua 0,84 %) y luego aplica las **mismas constantes** a un
bloque por segundo:

| Magnitud | Calibrado a 120 s | A un bloque por segundo | Factor |
|---|---:|---:|---:|
| Cruce del techo de mil millones | año 10,15 | **30,9 días** | 120× |
| Caída a la emisión de cola | año 8,16 | 24,8 días | 120× |
| Emisión de cola anual | 8 409 600 ZZK | **1 009 152 000 ZZK** | 120× |
| Inflación perpetua | 0,84 % anual | **100,92 % anual** | 120× |
| `N_LARGO`, ventana del tamaño de bloque | 365 días | **3,04 días** | 120× |
| `COINBASE_MATURITY` | 3,33 h | **1,7 min** | 120× |
| `MAX_REORG_LENGTH` | 3,30 h | 1,6 min | 120× |

**Qué significa cada fila.** La inflación del 100,92 % anual duplicaría el suministro cada año, para
siempre. La ventana de tamaño de bloque de 3 días **destruye el motivo por el que se eligió**: una
ventana de un año existía para absorber el ciclo estacional del marketplace sin penalizar el pico de
Navidad (`SPEC.md:928-934`). Y la madurez de coinbase de 100 segundos deja la profundidad máxima de
reorganización en 1,6 minutos, muy por debajo de la finalidad de 2 horas que el DAG necesita.

**Qué hay que hacer.** No es difícil, es trabajo de derivación: las constantes en unidades de bloque
tienen que pasar a unidades de tiempo o dividirse por 120, y hay que comprobar que la emisión resultante
sigue cumpliendo lo que P-002 decidió. **Pero es bloqueante**: mientras no esté hecho, el subsidio por
bloque es 120 veces mayor de lo que debería, y eso hace que la penalización por tamaño sea prohibitiva
en términos de tarifas (§1, tabla D de `verif_600tps.py`: compensar un bloque al doble de la mediana
exigiría 6,68 ZZK por transacción, cuando con el subsidio correcto serían 0,056).

**Estado: HALLAZGO NUEVO, BLOQUEANTE, no estaba en la lista de pendientes.** Va a P-041.

---

## 9 · Orden recomendado

1. **Recalibrar las constantes a `λ = 1`** (§8). Es bloqueante y no es investigación, es derivación.
2. **Decidir el presupuesto de bytes** (§0), con el caso del marketplace delante (§1).
3. **Erlay** (§5) dentro de B7, que ya está planificado.
4. **Canales de estado** (§6) como línea propia para Cortex: es lo que de verdad resuelve 600 pagos por
   segundo sin matar el nodo doméstico.
5. **Ejecución desacoplada** (§3) y **capa de finalidad**, las dos después de cerrar P-038, las dos con
   la misma pregunta pendiente: cuánto dinero en juego se acepta fuera del consenso.
6. **Agregación de firmas** (§4) cuando la capa de finalidad decida la curva criptográfica.
