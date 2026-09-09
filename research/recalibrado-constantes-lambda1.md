# Recalibrado de constantes para `λ = 1 bloque/s`, con objetivo de diseño 1 280 tx/s

**2026-09-09** · Encargo de Katana: recalibrar primero, decidir el presupuesto con el marketplace
delante, y dimensionar para **1 280 transacciones por segundo** (110 592 000 al día) para tener
margen. · Responde a **P-041**. Scripts: `research/scripts/rendimiento/verif_recalibrado_1280.py` y
`verif_600tps_maduro.py`. **Estado: APLICADO en SPEC y código el 2026-09-09** (commit «recalibrado a lambda = 1 bloque/s»), con `ZONA_LIBRE`
sin tocar y `N_LARGO` = año completo por decisión de Katana; queda la decisión 3, `N_CORTO` (§5 bis).

> **El hallazgo que cambia el encargo.** 1 280 tx/s **no exige** subir `ZONA_LIBRE` a 448 000 bytes.
> La zona libre no es un techo: es el **suelo** de la mediana y el precio del atacante; el techo
> instantáneo es `2 · FACTOR_SURGE · Mlt`, que con la constante actual ya son **28 571 tx/s**. Así que
> el pico de 1 280 **ya cabe hoy**. Lo que decide el tamaño de la cadena no es el pico, es la **carga
> sostenida**, y ahí la diferencia entre poner el marketplace en la cadena o pasarlo por canales es de
> **14,13 TB al año contra 0,03**.

---

## 1 · Principio del recalibrado

**Lo que se conserva es el calendario en tiempo, no el número por bloque.** Toda constante en unidades
de bloque calibrada para `T = 120 s` se divide por 120 o se reexpresa en segundos. El factor es exacto:
262 800 → 31 536 000 bloques al año, **120×**.

**Control positivo antes de tocar nada.** El script reproduce, con las constantes originales a 120 s,
los cinco números que el propio SPEC declara (`SPEC.md:1467-1471`): recompensa inicial 1 907,35 ZZK,
caída al tail en el año 8,16, cruce de los mil millones en el año 10,15, cola de 8 409 600 ZZK al año e
inflación perpetua del 0,84 %. Coinciden. El instrumento es fiable.

---

## 2 · Emisión — el cambio obligatorio, sin compensaciones

| | Hoy a `λ = 1` (sin tocar) | **Propuesto** | Objetivo (lo de 120 s) |
|---|---:|---:|---:|
| `SHIFT` | 19 | **26** | — |
| `TAIL_EMISSION` | 32 ZZK/bloque | **26 666 666 brek = 0,266667 ZZK/bloque** | — |
| Recompensa inicial | 1 907,35 ZZK | 14,90 ZZK | — |
| Caída al tail | día 24,8 | año 8,56 | año 8,16 |
| Cruce de los mil millones | **día 30,9** | **año 10,69** | año 10,15 |
| Emisión de cola anual | 1 009 152 000 ZZK | **8 409 600 ZZK** | 8 409 600 ZZK |
| Inflación perpetua | **100,92 %** | **0,84 %** | 0,84 % |

**Por qué `SHIFT = 26` y no otro.** El desplazamiento tiene que crecer en `log₂(120) = 6,9`, y `2⁷ = 128`
es el entero más cercano. La aritmética del consenso exige un desplazamiento entero, no una división
arbitraria, así que el calendario se estira un **5,3 %**: los mil millones se cruzan en el año 10,69 en
vez del 10,15. **Es el único residuo del recalibrado y es aceptable**; la alternativa sería cambiar la
forma de la regla `C-EMIT-01` a una multiplicación con divisor, y eso es tocar consenso por un 5 %.

`SOFT_CAP` y la unidad **no se tocan**: el sistema es homogéneo de grado 1 (`SPEC.md:1475`), escalarlos
no cambia el calendario.

**Efecto colateral que importa.** Con el subsidio sin recalibrar, un bloque al doble de la mediana le
cuesta al granjero 1 907,35 ZZK, o sea **1,49 ZZK por transacción extra** en tarifas para compensarlo:
prohibitivo, ningún granjero supera la mediana y **la válvula de sobrecarga deja de funcionar**. Con el
subsidio recalibrado son 0,0116 ZZK por transacción. El mercado de tarifas vuelve a existir.

**Estado: SIN BIFURCACIÓN. Es derivación, y el resultado es este.**

### 2 bis · Efecto en cascada: la tarifa mínima escala con la recompensa, y hay que recalibrar `REF_WEIGHT`

La tarifa mínima es `base · REF_WEIGHT / Mf²` (`SPEC.md:730`). Al bajar `base` de 1 907,35 a 14,90 ZZK, la
tarifa mínima cae **128×** y con ella el coste de inflar la cadena: de 543 590 ZZK por GB en el diseño
original a 4 250. **El recalibrado de la emisión, solo, debilita el antispam 128 veces.** Para conservar el
coste del atacante hay que subir `REF_WEIGHT` en el mismo factor:

| | Hoy | **Propuesto** |
|---|---:|---:|
| `REF_WEIGHT` | 3 000 | **384 000** |

Con eso, la tarifa de lanzamiento vuelve a 54 359 brek por unidad de peso y 0,19 ZZK por transacción de 350
bytes, exactamente lo que el SPEC publica. El SPEC ya avisaba (`SPEC.md:793-795`) de que `REF_WEIGHT` «requiere
un modelo de coste de atacante explícito» y no es una constante cerrada: este es el momento de fijarla. La
tarifa mínima **no es consenso** (`SPEC.md:721-725`), así que el cambio no rompe nada en cadena.

**Estado: SIN BIFURCACIÓN, es derivación**, pero se descubrió al hacer el cálculo de §4 y no estaba en P-041.

---

## 3 · Ventanas en unidades de bloque

| Constante | Hoy | Equivale a | **Propuesto** | Comprobación |
|---|---:|---:|---:|---|
| `N_CORTO` | 100 | 3,33 h | **12 000** | — |
| `COINBASE_MATURITY` | 100 | 3,33 h | **12 000** | 3,33 h **>** F = 2 h ✓ |
| `MAX_REORG_LENGTH` | 99 | 3,30 h | **11 999** | `= COINBASE_MATURITY − 1` por regla (la primera versión decía 11 880 = 99×120, que no respeta la forma de la regla); sustituida por R-FIN-7 en el DAG |
| `N_LARGO` | 262 800 | 365 días | **ver §5** | problema de memoria |

`COINBASE_MATURITY` tiene que ser mayor que la finalidad del DAG para que una recompensa no se pueda
gastar antes de ser irreversible. Con el factor 120 quedan 3,33 horas contra las 2 de finalidad:
**cumple con margen**.

**Estado: SIN BIFURCACIÓN salvo `N_LARGO` (§5) y `N_CORTO` (§5 bis).**

### 3 bis · Más constantes en unidades de bloque, encontradas al aplicar

| Constante | Hoy | A `λ = 1` significa | Qué se hizo |
|---|---:|---:|---|
| `ALTURA_CADUCIDAD` (C-CHK-03) | 525 600 «dos años exactos a T = 120 s» | 6,08 días | **Aplicado ×120 = 63 072 000**: la intención era dos años y no tiene otra dependencia |
| `VIDA_MINIMA_BLOQUES` = 2¹⁶ (C-EXP-03) | 91 días a 120 s | **18,2 horas** | **NO tocada.** Es la vida mínima de un sector de granjero: a 1 b/s caducaría en horas. Potencia de dos obligatoria (C-EXP-02) y el DAG la reexpresa en `blue_work` (R-FIN-10): rederivar con la decisión de P-036/P-033, no aquí |
| `DISPERSION_BLOQUES` = 2²⁰ (C-EXP-02) | 4 años | **12 días** | **NO tocada**, misma razón |
| `HOLGURA_BLOQUES` = 144 (C-NET-04) | 4,8 h | 144 s, y ahora **menor** que `MAX_REORG_LENGTH` | **NO tocada**; comentario actualizado. Es el umbral de trabajo del PoW; el DAG lo sustituye por el coste del PoT por slot (C-NET-03/04, informe 52 §52) |
| Tabla de confirmaciones para Cortex (§policy) | 3 conf = 6 min, 6 = 12 min | 3 s, 6 s | Solo la fila de 100 → 12 000; nota de que las otras filas no están rederivadas |

**Consecuencia nueva, escrita en C-STORE-06:** el solapamiento de bloques no finalizados que el nodo
mantiene en memoria pasa de 99 × 2 439 × 82 B = 18 MB a **11 999 × 2 439 × 82 B = 2,40 GB** en el techo
adversarial. Bajo el DAG, R-FIN-7 (`F = 2 h` = 7 200 bloques) lo dejaría en 1,44 GB. Es una factura del nodo
doméstico que conviene tener delante al decidir la poda (P-034).


---

## 4 · `ZONA_LIBRE` — la decisión, con la implicación que corrige mi primera recomendación

> **Error mío, declarado.** En la primera versión de esta sección y en la pregunta que le hice a Katana
> escribí que duplicar `ZONA_LIBRE` «duplica el coste del big bang attack». **Es al revés.** La tarifa
> mínima del SPEC (§5.5) es `base · REF_WEIGHT / Mf²`, y con la mediana en su suelo `Mf = ZONA_LIBRE`:
> el coste de llenar un bloque es `base · REF_WEIGHT / ZONA_LIBRE`, **inversamente proporcional** a la
> constante, y como los bytes añadidos crecen con ella, **el coste de inflar un gigabyte va como
> `1/ZONA_LIBRE²`**. Duplicarla hace el ataque **cuatro veces más barato por GB**, no más caro. Verificado
> en `verif_zona_libre.py`, cuyo control reproduce exactamente la tabla del SPEC (54 359 y 912 brek/peso).

`ZONA_LIBRE` **no limita el caudal**: el techo instantáneo es `2 · FACTOR_SURGE · Mlt`, que con la
constante actual ya son **28 571 tx/s**, veintidós veces el objetivo de 1 280. Lo que la constante fija
es **una sola tarifa que hace dos trabajos a la vez**: lo que paga un usuario por transacción y lo que
le cuesta a un atacante inflar la cadena. No se puede abaratar una sin abaratar la otra.

**Las implicaciones, con `REF_WEIGHT` ya corregido a 384 000 (ver §2 bis) y la emisión recalibrada:**

| `ZONA_LIBRE` | Libres de penalización | Techo instantáneo | Tarifa de una tx de 350 B | Coste de inflar 1 GB | Frente al diseño original |
|---:|---:|---:|---:|---:|---:|
| **100 000 B** (actual) | 286 tx/s | 28 571 tx/s | **0,190 ZZK** | **543 590 ZZK** | **1,00×, idéntico** |
| 200 000 B | 571 tx/s | 57 143 tx/s | 0,048 ZZK | 135 900 ZZK | 0,25× |
| 448 000 B | 1 280 tx/s | 128 000 tx/s | 0,009 ZZK | 27 080 ZZK | 0,05× |

Las tarifas son las del régimen de lanzamiento; en el régimen de cola caen unas 56× en las tres filas,
como el SPEC ya documenta para la constante actual (`SPEC.md:779-783`).

**Lo que significa cada fila para el marketplace.** Con canales de estado el usuario no paga una tarifa
en cadena por cada pago, solo por cada liquidación, así que el argumento de «abaratar la tarifa al usuario»
pesa poco. Lo que pesa es el otro trabajo de la constante: a 100 000 B inflar un terabyte de cadena cuesta
más de la mitad del suministro total; a 448 000 B cuesta el 2,7 %. Y ese coste está denominado en ZZK, así
que vale lo que valga la moneda: en los primeros meses, cuando el precio sea bajo, es cuando el antispam
está más débil, y cuando más importa no haberlo debilitado por diseño.

**Recomendación corregida del principal: `ZONA_LIBRE = 100 000 B`, sin tocar.** Ya absorbe el pico de
1 280 tx/s con veintidós veces de margen, conserva exactamente la economía antispam que se decidió, y con
canales el precio por transacción no es el precio que ve el comprador. Subirla compra una tarifa más baja
para el tráfico directo a cambio de un antispam cuatro veces más débil por cada duplicación, y ese es un
intercambio que conviene hacer con datos de precio de la moneda, no antes del lanzamiento.

**BIFURCACIÓN DE KATANA**, con la recomendación cambiada respecto a la primera versión.

## 5 · `N_LARGO` — la ventana anual, con el ataque que el muestreo abre

> **Segunda corrección mía, declarada.** La primera versión recomendaba «muestrear un año, un bloque de
> cada 120». Al calcular el coste del atacante (`verif_n_largo.py`) resulta que **el muestreo determinista
> abre una palanca de 120×**: el atacante sabe qué alturas se muestrean y solo llena esas. Mismo tiempo
> que la ventana completa, pero el coste de mover la mediana cae de 1 457 M ZZK a 12 M. Retirada.

`N_LARGO = 262 800` bloques son un año a 120 s, elegido **expresamente** para que la mediana larga recuerde
el ciclo estacional del marketplace y sea difícil de mover (`SPEC.md:928-934`). A `λ = 1`, un año son
**31 536 000 bloques**: ~252 MB de estado (8 B por muestra, extrapolando los ~2 MB que el SPEC estima) y una
mediana sobre 31,5 millones de muestras en cada bloque.

**Lo que `Mlt` protege.** Es el suelo de la mediana efectiva, del límite duro y de la tarifa mínima
(`∝ 1/Mlt²`). Un atacante que la infle sube la capacidad sin penalización y abarata la tarifa: es la
palanca del *big bang attack* a largo plazo. El freno estructural es C-WGT-04 (`lt_weight ≤ 1,7·Mlt`): la
mediana sube como mucho 1,7× cada vez que el atacante consigue que **la mitad de las muestras** sean suyas.

**Las cuatro salidas, con el coste del atacante a la tarifa mínima corregida:**

| Opción | Estado | Recuerda | Tiempo mínimo para mover `Mlt` 1,7× | Coste en tarifas | Frente al suministro |
|---|---:|---:|---:|---:|---:|
| **1 · Año completo, mediana incremental** | 252 MB | 365 días | 182,5 días | **1 457 M ZZK** | **146 %: imposible** |
| 2 · Año muestreado, 1 de cada 120 | 2,1 MB | 365 días | 182,5 días | 12 M ZZK | 1,2 % |
| 3 · Acortar a 30 días | 21 MB | 30 días | 15 días | 120 M ZZK | 12 % |
| **4 · Año en cubos: mediana de cada 120** | 2,1 MB | 365 días | 182,5 días | **741 M ZZK** | **74 %** |

**Lectura de cada fila.**

- **Opción 1** conserva todo y es inatacable por tarifas: mover la mediana costaría más que todo el
  suministro. Cuesta 252 MB de estado por nodo, una mediana incremental (dos montículos o un árbol de
  orden, inserción y borrado logarítmicos: CPU despreciable) y reconstruir la ventana en la sincronización
  inicial. 252 MB frente a los 26 GB anuales de cadena no es el cuello de botella.
- **Opción 2** es la que retiro: el atacante conoce las alturas muestreadas y llena solo esas. Cien veces
  más barata de atacar que la 1 con el mismo estado que la 4.
- **Opción 3** pierde el ciclo estacional, que es el motivo por el que existe la constante, y además la
  mediana se mueve doce veces más rápido.
- **Opción 4** conserva el año y el estado pequeño, y solo abarata el ataque 2× respecto a la completa,
  porque para mover la mediana de un cubo hay que llenar 61 de sus 120 bloques. **Pero es un estimador
  distinto** (mediana de medianas, no mediana), y el SPEC especifica la mediana con aritmética entera exacta
  (C-WGT-03); habría que reescribir C-WGT-05 y demostrar que el nuevo estimador no abre otra palanca.

**Recomendación corregida del principal: opción 1, el año completo con mediana incremental.** No cambia
ninguna regla del SPEC, solo cómo se implementa la mediana; es la única sin análisis adversarial nuevo; y su
único coste, 252 MB, es el 1 % de un año de cadena. La opción 4 queda anotada como la alternativa si esos
252 MB resultaran un problema real en el nodo doméstico, y exigiría una ronda D8 propia.

**DECIDIDO (Katana, 2026-09-09): opción 1, año completo.** Aplicado como `N_LARGO = 31 536 000` con la
obligación de mediana incremental escrita en el SPEC.

### 5 bis · `N_CORTO` — la ventana corta también está en bloques, y decide cuánto tarda la sobrecarga en abrirse

`N_CORTO = 100` bloques se anota en el SPEC como «200 min», que es lo que 100 bloques daban a 120 s. La
mediana corta es la que abre la sobrecarga ante una ráfaga (C-WGT-08): hasta que se entera, los bloques van
capados a `2 · Mlt` = 200 000 B con subsidio cero en el tope. Medido con las reglas exactas sobre cadena madura
(`verif_n_corto.py`):

**Lo que se paga por la reacción rápida.** Un atacante que produzca más de la mitad de los últimos `N_CORTO`
bloques mueve la mediana corta hasta `50 · Mlt` y, mientras dura la ventana, mete bloques de 5 MB con subsidio
entero. Binomial exacta a `α = 0,33` y absorción medida (`verif_n_corto_barrido.py`; corrige la estimación
anterior de «~1 GB por evento, ~73 GB/año», que era una cota inconsistente):

| `N_CORTO` | Equivale a | Captura por azar al 33 % | Un evento cada | Inflado gratis (cota) | Ráfaga de 1 280 tx/s absorbida en | Cola máxima |
|---:|---:|---:|---:|---:|---:|---:|
| **100** (actual) | 100 s | 1,5·10⁻⁴ por ventana | **7,7 días** | 23,7 GB/año | **152 s** | 42 571 tx |
| 200 | 3,3 min | 2,4·10⁻⁷ | 26 años | 0,0 | 302 s | 84 857 tx |
| **300** | 5 min | 4,3·10⁻¹⁰ | **22 800 años** | 0,0 | **452 s** | 127 143 tx |
| 500 | 8,3 min | 1,6·10⁻¹⁵ | nunca | 0,0 | 752 s | 211 714 tx |
| 1 000 | 16,7 min | 5,1·10⁻²⁹ | nunca | 0,0 | 1 502 s | 423 143 tx |
| 12 000 (× 120, en tiempo) | 3,3 h | 0 | nunca | 0,0 | ~5 h | 5 109 006 tx |

La captura cae de forma exponencial con `N_CORTO` y la absorción crece de forma lineal: **el intercambio no es
simétrico**, y por eso el óptimo está cerca del extremo rápido. A 300 la captura por azar ocurre una vez cada
22 800 años y la ráfaga más alta pedida se absorbe en siete minutos y medio con 127 000 transacciones en cola
en el peor instante.

**Recomendación del principal, corregida: `N_CORTO = 300`** (propuesto por Katana; la primera versión decía
1 000, que compra seguridad que ya no hace falta a cambio de cuatro veces más cola). 200 es el suelo admisible.
Es una constante de consenso (entra en C-WGT-06): cambiarla después es hard fork.

**BIFURCACIÓN DE KATANA (decisión 3).**

## 6 · Resumen de lo propuesto

| Constante | Hoy | Propuesto | Tipo |
|---|---:|---:|---|
| `SHIFT` | 19 | **26** | derivación |
| `TAIL_EMISSION` | 3 200 000 000 brek | **26 666 666 brek** | derivación |
| `N_CORTO` | 100 | **12 000** | derivación |
| `COINBASE_MATURITY` | 100 | **12 000** | derivación |
| `MAX_REORG_LENGTH` | 99 | **11 999** | derivación, `= COINBASE_MATURITY − 1` (superada por R-FIN-7) |
| `ALTURA_CADUCIDAD` | 525 600 | **63 072 000** | derivación (dos años) |
| `N_CORTO` | 100 | **100 provisional** | **decisión 3** (§5 bis) |
| `REF_WEIGHT` | 3 000 | **384 000** | derivación (cascada de la emisión; no es consenso) |
| `ZONA_LIBRE` | 100 000 B | **100 000 B, sin tocar** (recomendado, corregido) | **decisión** |
| `N_LARGO` | 262 800 | **31 536 000, año completo con mediana incremental** (recomendado, corregido) | **decisión** |
| `SOFT_CAP`, `FACTOR_SURGE`, unidad | — | **sin tocar** | — |

## 7 · Lo que este recalibrado NO resuelve

- **1 280 tx/s sostenidos en cadena siguen siendo incompatibles con un nodo doméstico**, con cualquier
  valor de las constantes. Es aritmética de disco, no de consenso. La salida es la palanca 5 (canales).
- **La poda sigue sin resolver** (P-034). Con 14 TB al año importaría mucho más que con 26 GB.
- **El retardo de red sigue sin medir**, y de él dependen todos los umbrales de seguridad.
- **P-038 sigue abierta.** Este recalibrado es condición para publicar números, no para cerrar el DAG.
