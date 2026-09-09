# Recalibrado de constantes para `λ = 1 bloque/s`, con objetivo de diseño 1 280 tx/s

**2026-09-09** · Encargo de Katana: recalibrar primero, decidir el presupuesto con el marketplace
delante, y dimensionar para **1 280 transacciones por segundo** (110 592 000 al día) para tener
margen. · Responde a **P-041**. Scripts: `research/scripts/rendimiento/verif_recalibrado_1280.py` y
`verif_600tps_maduro.py`. **Estado: PROPUESTA. El SPEC no se toca hasta que Katana decida §4 y §5.**

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

---

## 3 · Ventanas en unidades de bloque

| Constante | Hoy | Equivale a | **Propuesto** | Comprobación |
|---|---:|---:|---:|---|
| `N_CORTO` | 100 | 3,33 h | **12 000** | — |
| `COINBASE_MATURITY` | 100 | 3,33 h | **12 000** | 3,33 h **>** F = 2 h ✓ |
| `MAX_REORG_LENGTH` | 99 | 3,30 h | **11 880** | sustituida por R-FIN-7 en el DAG |
| `N_LARGO` | 262 800 | 365 días | **ver §5** | problema de memoria |

`COINBASE_MATURITY` tiene que ser mayor que la finalidad del DAG para que una recompensa no se pueda
gastar antes de ser irreversible. Con el factor 120 quedan 3,33 horas contra las 2 de finalidad:
**cumple con margen**.

**Estado: SIN BIFURCACIÓN salvo `N_LARGO`.**

---

## 4 · `ZONA_LIBRE` — la decisión, y no es la que parecía

`ZONA_LIBRE` **no limita el caudal**. Limita tres cosas: qué cabe sin penalización, cuál es el suelo de
la mediana, y cuánto le cuesta a un atacante inflar la cadena (`SPEC.md:915`, *big bang attack*). El
caudal instantáneo lo fija `2 · FACTOR_SURGE · Mlt`:

| `ZONA_LIBRE` | Libres de penalización | Techo instantáneo | ¿Cabe el pico de 1 280? | Si fuera sostenido |
|---:|---:|---:|:---:|---:|
| **100 000 B** (actual) | 286 tx/s | **28 571 tx/s** | **sí** | 3 154 GB/año |
| 200 000 B | 571 tx/s | 57 143 tx/s | sí | 6 307 GB/año |
| 448 000 B (1 280 tx/s libres) | 1 280 tx/s | 128 000 tx/s | sí | 14 128 GB/año |

**Y lo que de verdad decide el tamaño de la cadena:**

| Escenario | En cadena | Crecimiento | SSD de 4 TB |
|---|---:|---:|---:|
| Todo el marketplace en cadena, 1 280 tx/s | 1 280 tx/s | 14,13 TB/año | **3,4 meses** |
| Por canales, 200 000 pares liquidando a diario | 2,3 tx/s | 0,03 TB/año | 157 años |
| Por canales, 1 M de pares liquidando a diario | 11,6 tx/s | 0,13 TB/año | 31 años |
| Canales más 50 tx/s de tráfico directo | 50 tx/s | 0,55 TB/año | 7,2 años |
| Canales más 285 tx/s de tráfico directo | 285 tx/s | 3,15 TB/año | 1,3 años |

110 592 000 pagos al día repartidos entre 200 000 pares son **553 pagos por par y día**, que se liquidan
en una sola transacción: **factor 553× de reducción**.

**Contra las paredes medidas del nodo doméstico** (8 núcleos, 50 Mbps de subida, SSD de 4 TB), con
1 280 tx/s sostenidos en cadena:

| Recurso | Techo | Uso | |
|---|---:|---:|---|
| CPU verificando firmas | 84 211 tx/s | 1,5 % | sobra |
| Red con 8 pares | 2 232 tx/s | 57,3 % | cabe; **34 % con Erlay** |
| Almacenamiento | 72 tx/s | **1 778 %** | **17,8× por encima** |

**Recomendación del principal: `ZONA_LIBRE = 200 000 B`.** Duplica el margen libre de penalización sobre
la constante actual (571 tx/s), deja el techo instantáneo en 57 143 tx/s —cuarenta y cuatro veces el
objetivo—, y **no compromete al nodo doméstico**, porque el crecimiento real lo fija la carga sostenida y
no esta constante. Subirla a 448 000 solo tendría sentido si el marketplace fuera a liquidar de verdad
1 280 tx/s en cadena, y en ese caso el problema no es la constante: es que la cadena crece 14 TB al año.

**BIFURCACIÓN DE KATANA.**

---

## 5 · `N_LARGO` — un problema de ingeniería que aparece con el recalibrado

`N_LARGO = 262 800` bloques son un año a 120 s, y se eligió **expresamente** para absorber el ciclo
estacional del marketplace sin penalizar el pico de Navidad (`SPEC.md:928-934`). A `λ = 1`, un año son
**31 536 000 bloques**. El SPEC estima ~2 MB de estado con la ventana actual; con la nueva serían
**~240 MB**, más una mediana sobre 31,5 millones de muestras en cada bloque.

Tres salidas:

1. **Mantener el año y pagar la memoria**, con mediana incremental (estructura ordenada con inserción y
   borrado en tiempo logarítmico en vez de ordenar la ventana entera). Conserva la propiedad estacional;
   cuesta 240 MB de estado permanente y trabajo de implementación.
2. **Acortar la ventana** a, por ejemplo, 30 días (2 592 000 bloques, ~20 MB). Se pierde la propiedad
   estacional que motivó el valor: la cadena olvidaría el pico de Navidad antes de la Navidad siguiente,
   que es exactamente el defecto que el SPEC le achaca a Monero.
3. **Muestrear la ventana**: mediana sobre una submuestra determinista de un año (por ejemplo, un bloque
   de cada 120). Conserva la propiedad estacional con el mismo estado que hoy; hay que demostrar que la
   mediana muestreada no abre una palanca de manipulación nueva.

**Recomendación del principal: la opción 3, con la 1 como respaldo.** El muestreo determinista conserva
lo que la constante existía para conservar y no cuesta memoria; su riesgo es analizable en una ronda.

**BIFURCACIÓN DE KATANA.**

---

## 6 · Resumen de lo propuesto

| Constante | Hoy | Propuesto | Tipo |
|---|---:|---:|---|
| `SHIFT` | 19 | **26** | derivación |
| `TAIL_EMISSION` | 3 200 000 000 brek | **26 666 666 brek** | derivación |
| `N_CORTO` | 100 | **12 000** | derivación |
| `COINBASE_MATURITY` | 100 | **12 000** | derivación |
| `MAX_REORG_LENGTH` | 99 | **11 880** | derivación (superada por R-FIN-7) |
| `ZONA_LIBRE` | 100 000 B | **200 000 B** (recomendado) | **decisión** |
| `N_LARGO` | 262 800 | **muestreo de un año** (recomendado) | **decisión** |
| `SOFT_CAP`, `FACTOR_SURGE`, unidad | — | **sin tocar** | — |

## 7 · Lo que este recalibrado NO resuelve

- **1 280 tx/s sostenidos en cadena siguen siendo incompatibles con un nodo doméstico**, con cualquier
  valor de las constantes. Es aritmética de disco, no de consenso. La salida es la palanca 5 (canales).
- **La poda sigue sin resolver** (P-034). Con 14 TB al año importaría mucho más que con 26 GB.
- **El retardo de red sigue sin medir**, y de él dependen todos los umbrales de seguridad.
- **P-038 sigue abierta.** Este recalibrado es condición para publicar números, no para cerrar el DAG.
