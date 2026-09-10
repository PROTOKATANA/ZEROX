# D15A — Avalanche/Snowball sobre peso de espacio: ¿finalidad rápida sin comité?

**Fecha:** 2026-09-10 · **Ronda:** 15A. **Directorio propio:** `research/scripts/d15-avalanche/`.
**Restricción vinculante de Katana (2026-09-10):** sin comités de decisión; descentralización y
seguridad. **Prioridad:** bajar el tiempo de irreversibilidad. El cliente ligero es secundario.
**Alcance:** no se tocó ningún fichero fuera de este directorio; no se ejecutó git (instrucción de
la ronda; `METODO-AGENTES.md:6` pide commit por punto: queda como la única desviación del método).

**Punto de partida auditado.** D8b estableció que Avalanche **no es un comité**: el muestreo es
abierto y el Sybil-resistance es *pluggable* (`fuentes/avalanche-1906.08936.txt:271-273, :318-319`).
Los 2.000 AVAX son requisito de despliegue, no del protocolo. La ronda 14C lo excluyó por el motivo
equivocado. Queda como el único candidato no-comité con latencia de décimas de segundo en un solo
emplazamiento (**0,206 s típicos, 0,4 s máximo**, `:1125-1130`) y **1,35 s geo-replicado**
(`:24, :1254`); el encargo los llama «sub-segundo», y solo el primero lo es. El baseline de ZEROX
mide **130,41 s a `α=0,33`** (GHOSTDAG `k=30`, `d14-dagknight/salida_zerox2.txt:32`).

---

## 0 · Método, definiciones y notación

**Qué se evalúa.** Una capa/protocolo de finalidad por submuestreo tipo Snowball
(`arXiv:1906.08936`, Figs. 5 y 6) en el que el peso del votante es **evidencia de espacio**, no
stake. La pregunta del encargo no es «¿funciona Snowball en abstracto?» sino «¿se puede muestrear
en ZEROX sin registro, sin dinero y sin comité, y baja la irreversibilidad?».

**Colisión de notación, declarada.** El paper llama `α` al **umbral de mayoría de la muestra**
(`α > ⌊k/2⌋`, `:345, :456`) y `f/n` a la **fracción adversaria**. El encargo y el resto del
proyecto usan `α` para la **fracción adversaria**. En este informe: `f` = fracción adversaria
(espacio), `q` = umbral de la muestra, `k` = tamaño de muestra, `β` = umbral de decisión. No se usa
`α` para el umbral. Esta confusión es la causa de que 14C comparara mal.

**Instrumentos propios.**
| Script | Qué mide | Salida |
|---|---|---|
| `snowball_ctmc.py` | Cadena de nacimiento-muerte de Slush/Snowflake con adversario (A.2/A.3): frontera del valle, `p_adv`, MTTF conservador | `salida_ctmc.txt` |
| `snowball_agentes.py` | Snowball/Slush por agentes con contadores de confianza (Figs. 5/6/10), 20 semillas, retardo de vista | `salida_agentes.txt` |
| `ataque_muestreo.py` | Ventana por publicación vs por `slot`; fracción online exigida; supresión | `salida_muestreo.txt` |
| `latencia_snowball.py` | Rondas medidas × tiempo de ronda `T(Δ)`; comparación con 130,41 s | `salida_latencia.txt` |

**Etiquetas:** DEMOSTRADO (argumento cerrado) · VERIFICADO (medido y reproducible) · PLAUSIBLE
(argumento sin cerrar) · REFUTADO · LAGUNA (no se sabe; se dice qué haría falta).

**Control positivo (criterio α).** En `snowball_agentes.py`, `k=10, q=6` (el `α=⌊k/2⌋+1` del paper,
`:623`) converge en 11-24 rondas y con `f≥0,25`, `k=10, q=8` **todos los honestos deciden rojo**:
reproduce la frontera de viveza del paper `f < (k−q)/k = 0,20` (`:598-599`). En
`snowball_ctmc.py`, la frontera del valle salta a 1 exactamente al cruzar ese umbral. Los
resultados cambian con `f` y con `q`; el criterio del método se cumple.

---

## 1 · Resumen ejecutivo (resultados ya cerrados)

1. **El muestreo sin registro SÍ es posible, y hay una fuente que resiste Sybil sin tabla: las
   soluciones de una ventana indexada por `slot` de PoT.** Una solución es una prueba de espacio
   válida (R-FIN-11: identidad `(pk, sector_index, history_size, chunk, slot)`); el número de
   soluciones por ventana es ∝ espacio; partir el espacio entre claves no cambia el total. No hace
   falta censo ni tabla de poder. **Pero** solo si la ventana se indexa por **`slot` de la
   solución**, no por **momento de publicación**: con publicación, un atacante que retiene
   `T = 4W` multiplica su fracción de `0,33` a `0,663` (calculado en `ataque_muestreo.py`); con
   `slot`, la fracción es invariante `f` (`0,33`) porque cada solución cuenta una sola vez en su
   slot. Esto separa esta ronda de la 14C: la tabla de poder de P-040 no es necesaria.
2. **La latencia baja, pero solo si `Δ` es pequeño.** Snowball con `f=0,33`, `k=50, q=30`,
   `β1=11` decide en **~14-19 rondas** (r90 = 14, media 18,7; 20 semillas, `salida_agentes.txt`).
   Con `T_ronda = 2Δ` (consulta-respuesta): `Δ=1` → **28-38 s**; `Δ=4` → **112-150 s**;
   `Δ=16` → **448-600 s**; `Δ=20` → **560-750 s**. Con `T_ronda = Δ` (voto en gossip):
   `14-19 s / 56-75 s / 224-300 s / 280-375 s`. **Frente al baseline de 130,41 s: gana con
   `Δ ≲ 2-4 s`, empata en `Δ≈4`, pierde con `Δ ≥ 16`.** `Δ` sigue sin medir (E1).
3. **No exige dinero.** No hay stake, depósito ni slashing: el peso es una prueba de espacio ya
   pagada (almacenamiento). Los 2.000 AVAX son del despliegue de Avalanche, no del protocolo
   (`:271-273`). El voto es gratis, pero el adversario del modelo ya puede votar arbitrariamente
   (`:242-254`), así que la gratuidad no le da poder extra; lo que sí aparece es **sesgo de
   respuesta** (ver punto 5).
4. **Seguridad: el amortiguamiento por confianza es obligatorio a `f=0,33`.** Slush/Snowflake
   cambian de color con un solo sondeo mayoritario; Snowball cambia solo si la confianza nueva
   supera la vieja (Fig. 6). La cadena CTMC (conservadora, sin contadores) da, para `f=0,33`,
   `k=50, q=30`, `n=10 000`, una MTTF de **10^1684 años** desde el consenso (frontera del valle en
   el 78,5 % de los honestos). La frontera entre atractores está en **~74,6 % de los honestos =
   50 % de la población total** (analítica `0,5/(1−f)`, confirmada por agentes entre `p0=0,7` y
   `p0=0,8`): si los honestos están menos alineados que eso al arrancar, **el adversario gana el
   voto** (20/20 semillas deciden rojo con `p0=0,7`; 0/20 con `p0≥0,8`).
5. **Los ataques al muestreo son de viveza o de vista, no de peso.** (i) El sesgo de respuesta
   exige que responda el **26,5-40,3 %** de los honestos muestreados para `q/k=0,55-0,65` con
   `f=0,33` (tabla en `salida_ctmc.txt`); un granjero apagado es una pérdida de viveza, no una
   falsificación. (ii) La supresión dirigida (DoS sobre la muestra pública) **no puede fabricar
   `q` respuestas rojas**: con `k=50, q=30, f=0,33` la muestra tiene ~16,5 adversarios y haría
   falta que 30 de 50 respondieran rojo; suprimir honestos solo **estanca** el sondeo. (iii) La
   eclipse del nodo que muestrea (Heilman et al.) queda fuera del modelo del paper (`:288-294`
   asume *bootstrapping* seguro) y es el hueco de transporte real.
6. **Composición: como capa sobre GHOSTDAG no baja la irreversibilidad; como fork choice es un
   núcleo nuevo.** Una regla local que finaliza un checkpoint y luego ignora una cadena de más
   `blue_work` **cambia la regla de selección** (es R-FIN-18 de P-040 con voto en vez de
   certificado). Si se deja a GHOSTDAG decidir, la irreversibilidad no puede bajar del riesgo del
   fork choice a esa profundidad. La capa de Snowball, para comprar algo, tiene que ser
   **finalizadora vinculante**, con la seguridad de Snowball (probabilista `ε`) y no la de
   GHOSTDAG. Convive con R-FIN-7 (manda la finalidad más profunda; el voto solo adelanta) y con
   `C-REORG-07` (que R-FIN-7 sustituye en el DAG). Exige un mensaje nuevo o un campo de voto en la
   cabecera; el coste está en §6.
7. **¿Cae bajo la prohibición de comité? Bajo la definición estricta (conjunto que decide con
   quórum/certificado vinculante): NO.** Snowball no tiene membresía, ni certificado, ni voto
   vinculante: cada nodo decide localmente tras su propio contador, el muestreo es abierto y la
   entrada es ganar un bloque. Bajo la definición amplia de 14C («cualquier subconjunto
   muestreado cuyos votos deciden»), **sí**; pero esa definición también captura a GossipSub y
   convierte en comité cualquier agregación de opiniones. Es una decisión de alcance para Katana,
   ya señalada por D8b (`audita-d8b.md:348-352`). Mi recomendación es la definición estricta, con
   la salvedad escrita de que la muestra es un conjunto público y acotado por decisión.

---

## 2 · Pregunta 1 — ¿De dónde se muestrea sin registro?

El paper muestrea «known nodes»: `K := sample(N\u, k)` (`:318-319`) y no exige conocer a todos
(`:288-297`; A.7, `:2173-2240`). Eso no resuelve el problema de ZEROX: `N` es el *peer set* de
gossip, y sin Sybil-control las identidades son gratis. La pregunta es qué subconjunto de `N`
tiene **evidencia de espacio** y se puede derivar sin registro.

### 2.1 · Las cuatro opciones

| Fuente | ¿Comité fijo disfrazado? | ¿Resiste Sybil? | Evidencia de espacio por muestra | Etiqueta |
|---|---|---|---|---|
| **(a) Productores de bloque recientes** (firma de recompensa; R-FIN-8′) | No fijo: cualquiera entra ganando un bloque. Es un conjunto **rodante y público**; para una decisión concreta, finito y conocido. Bajo la definición amplia, sí; estricta, no | **Sí**, si el peso es el número de bloques de la ventana: repartir el espacio en claves reparte el mismo total (D9, 5.ª ronda: el Sybil de claves no cambia el coste) | La cabecera firmada por la `public_key` + la solución PoSpace del bloque; el *rate* en la ventana es ∝ espacio | **VERIFICADO** el mecanismo; **PLAUSIBLE** el peso |
| **(b) Red P2P** (pares de gossip) | No | **No**: identidades gratis; sin prueba, el sondeo no está ponderado | Ninguna, salvo que el respondedor adjunte una solución (→ vuelve a (a)/(c)) | **REFUTADO** como fuente por sí sola |
| **(c) Soluciones recientes del DAG** (ventana por `slot`) | No fijo; mismo caso que (a) | **Sí**: una solución = una prueba de espacio; el número por ventana ∝ espacio | La prueba PoSpace misma (`subspace-verification`), verificable sin conocer al granjero | **VERIFICADO** el mecanismo; **DEMOSTRADO** que la ventana por publicación es atacable (abajo) |
| **(d) Pruebas de almacenamiento archivado (KZG)** | No aplica | — | En Autonomys el *plot* **ya es** historia archivada: `subspace-farmer-components/src/plotting.rs` trae las piezas de historia al sector; `SectorId = H(pk‖sector_index‖history_size)` (`subspace-core-primitives/src/sectors.rs:45-65`). KZG se usa para compromisos de segmentos y erasure coding (`sc-consensus-subspace/src/archiver.rs:73,473`), **no** como certificado de almacenamiento por granjero | La solución PoSpace existente; no añade nada | **REFUTADO** como fuente nueva; es (a)/(c) |

**La distinción que decide: ventana por `slot` vs ventana por publicación.** Si el conjunto de
credenciales es «soluciones publicadas en los últimos `W` segundos», el atacante retiene y publica
en ráfaga:

```
fracción adversaria = f·T / ((1−f)·W + f·T)
```

Con `f=0,33`: `T=W` → 0,33; `T=2W` → 0,496; `T=4W` → 0,663. **Rompe el 50 % sin espacio extra.**
Si el conjunto es «soluciones cuyo `slot ∈ [t−W, t]`», cada solución cuenta exactamente una vez en
su slot y la fracción es **invariante `f`**: retener no crea credenciales, solo las retrasa.
`ataque_muestreo.py` calcula la tabla. La lección es la misma de R-FIN-13: **el reloj (`slot`) es
lo que no se puede fabricar a coste cero**; la ventana debe indexarse por él.

### 2.2 · El problema que ninguna de las cuatro resuelve: clave → dirección

Una solución da una `public_key`, no una dirección. Para **preguntar** la preferencia hay que
llegar al tenedor de la clave. Tres salidas, con su coste:

1. **Voto embebido en el bloque (Snowman-like).** La cabecera lleva el checkpoint preferido
   (32 B) firmado por el productor; no hay consulta ni dirección; el voto se lee del DAG. Coste:
   ~32-64 B/bloque = **~1-2 GB/año** a `λ=1` (31,5 M bloques/año), sin mensajes nuevos. **La
   ventana es por `slot` por construcción** (el voto va en el bloque). Contrapartida: el rate de
   votos es `λ=1/s`, y **pierde la amplificación del muestreo** (§4.4): la probabilidad de chit
   rojo es `f=0,33` por bloque, no `p_adv=7,8e-5`.
2. **Consulta dirigida con mapeo clave→dirección.** El productor anuncia su dirección en la
   cabecera (campo nuevo, NAT/puertos, rotación) o en un registro P2P. El atacante puede anunciar
   direcciones falsas de claves ajenas: no puede firmar la respuesta, pero **sí causar timeout**
   (DoS dirigido). Requiere un canal autenticado por la clave, que la solución ya permite (firma
   Ed25519, `C-HDR-03/04`).
3. **Consulta por gossip con respuestas firmadas.** El nodo publica la consulta (semilla de
   muestreo derivada del PoT, R-FIN-14) y los tenedores responden firmado por gossip; el nodo
   cuenta una respuesta por identidad con solución en la ventana. No hay mapeo, pero el coste es
   `O(n)` por consulta y aparece **sesgo de respuesta** (§4.3).

**Conclusión Q1.** Se puede muestrear sin registro y sin Sybil con (a)/(c) indexado por `slot`.
(b) y (d) no aportan. La fuente no es un comité fijo: es un conjunto rodante y abierto, pero
**finito y público para cada decisión**, y eso hay que decirlo (Q6).

---

## 3 · Pregunta 2 — Peso sin tabla

**La respuesta es el *rate* de soluciones en una ventana por `slot`, no una tabla.** El peso de una
clave es el número de soluciones suyas en la ventana; en espera es `∝` a su espacio, porque el
`solution_range` del retarget es común y el número de intentos por slot es proporcional al espacio
almacenado. Tres precisiones:

1. **No hace falta materializar la tabla.** El muestreador no construye `pk → peso`; muestrea
   identidades (soluciones) uniformemente y cada identidad pesa 1. La distribución de la muestra
   queda ponderada por espacio sin tabla. Es la diferencia con R-FIN-15/16 de P-040: allí la tabla
   es explícita porque el certificado la necesita; aquí no hay certificado.
2. **El almacenamiento archivado no es una fuente distinta.** En Autonomys el plot es la historia
   (`plotting.rs`); una solución ya prueba almacenamiento archivado de un sector. No hay un
   «KZG de espacio» por granjero que dé más evidencia por muestra.
3. **El peso es histórico, no actual.** Una solución prueba espacio en su `slot`; con `W` corto
   (minutos) eso es prueba de espacio actual (mover un plot lleva horas). Con `W` largo (días) no.
   La ventana debe ser corta para el peso y **larga para diluir la varianza**; el compromiso está
   en §5.

**LAGUNA:** el peso en esperanza es ∝ espacio, pero la *varianza* del número de soluciones por
clave y la correlación entre claves del mismo dueño no están medidas con datos reales de ZEROX;
hace falta la distribución de tamaños de granja y el `λ_real` bajo retarget.

---

## 4 · Pregunta 3 — Seguridad y viveza de Snowball con `f=0,33` y `Δ`

**Notación.** `f` = fracción adversaria de espacio, `q` = umbral de la muestra, `k` = tamaño de
muestra, `β1` = umbral de confianza, `β2` = umbral consecutivo. El paper llama `α` a `q`; aquí se
usa `q` para no repetir la colisión de 14C.

### 4.1 · El umbral de sondeo está atrapado entre 0,5 y 0,67

Dos restricciones independientes:

- **Seguridad:** `q/k > 1/2`; por debajo, no hay mayoría y la metastabilidad no existe.
- **Viveza (paper, `:598-599`):** `f < (k−q)/k`, es decir `q/k < 1−f`. A `f=0,33`: `q/k < 0,67`.

Verificado con el instrumento propio: con `k=10, q=8` (`q/k=0,8`) y `f≥0,25`, **20/20 semillas
deciden rojo** en `salida_agentes.txt` (control). El margen útil es `(1−f) − q/k`: 0,067 a
`q/k=0,60`; 0,017 a `q/k=0,65`. El margen es lo que paga la latencia (más margen, más rápido) y lo
que encarece el sesgo de respuesta (§4.3).

### 4.2 · Metastabilidad y MTTF conservador

La cadena CTMC de Slush/Snowflake (sin contadores; cota **conservadora**, porque Snowball amortigua
con confianza, A.4) da, para `n=10 000` y `f=0,33`:

| `k` | `q` | `q/k` | `p_adv` = P(muestra ≥ q rojos) | frontera del valle (i/c) | log10 MTTF (rondas) | MTTF (años) |
|---|---|---|---|---|---|---|
| 20 | 12 | 0,60 | 1,18e-2 | 0,9999 | 81,6 | 10^74,1 |
| 20 | 13 | 0,65 | 3,34e-3 | 0,9999 | 385,7 | 10^378,2 |
| 50 | 30 | 0,60 | **7,80e-5** | **0,7849** | **1692,4** | **10^1684,9** |
| 50 | 32 | 0,64 | 6,71e-6 | 0,7752 | 2527,0 | 10^2519,5 |
| 100 | 60 | 0,60 | 2,43e-8 | 0,7654 | 4483,4 | 10^4475,9 |
| 100 | 65 | 0,65 | 4,83e-11 | 0,7596 | 6726,2 | 10^6718,7 |

Fuente: `salida_ctmc.txt`. **Lectura.** La frontera del valle es el punto donde `µ_i = λ_i`; por
encima, el proceso vuelve al consenso. A `k=50, q=30, f=0,33` hay que perder el 21,5 % de los
honestos para revertir, y la MTTF conservadora es `10^1684` años. La simulación por agentes con
**Snowball** (contadores de confianza, Fig. 6) no ve ninguna decisión mixta ni roja en 20 semillas
para `k=50,q=30,β1=11` (`salida_agentes.txt`). **La etiqueta es VERIFICADO en simulación; el
número analítico es una cota, no una medida de Snowball.**

**Cuidado con el `n`.** En el modelo CTMC sin contadores, la tasa agregada de volteo escala con
`c` (`c·p_adv`) mientras la de recuperación es ~1; para `n=50 000` la frontera salta a 1
(`salida_ctmc.txt`, tabla de sensibilidad a `n`). **Snowball con confianza no tiene ese problema**
(el contador no escala con `n`), pero **Slush/Snowflake sí**: por eso el amortiguamiento por
confianza es obligatorio a `f=0,33`, no un adorno.

### 4.3 · La frontera que no está en el paper: alineación inicial de los honestos

La simulación descubre una condición que el análisis del paper esconde en el arranque: con
`f=0,33`, el valle entre los dos atractores está en **el 50 % de la población total**, que en
honestos es `0,5/(1−f) = 74,6 %`. Medido:

| `p0` (fracción honesta que ya prefiere el checkpoint) | semillas con algún honesto rojo |
|---|---|
| 1,00 | 0/20 |
| 0,90 | 0/20 |
| 0,80 | 0/20 |
| **0,70** | **20/20** |
| 0,60 | 20/20 |
| 0,50 | 20/20 |

Fuente: `salida_agentes.txt`. **Con honestos menos alineados que ~75 %, el adversario gana el
voto.** En operación normal los honestos siguen la misma cadena de GHOSTDAG, así que `p0≈1`; pero
tras una partición, un lado puede quedar por debajo del 74,6 % y finalizar el checkpoint del
adversario. **La defensa es votar un checkpoint a profundidad `d ≥ Δ`** (en el pasado común de
todas las vistas honestas) y no votar la punta. El paper cubre las vistas partidas en A.7
(`:2173-2240`) con el conjunto común `Sd`; la condición operativa concreta es esta `p0 > 0,746`.

### 4.4 · Ataques al muestreo

| Ataque | Resultado | Fuente/etiqueta |
|---|---|---|
| **Retención/ráfaga, ventana por publicación** | Cruza el 50 %: `f_eff = fT/((1−f)W+fT)`; con `T=4W`, 0,663 a `f=0,33`. **Rompe el muestreo** | `salida_muestreo.txt` · DEMOSTRADO |
| **Retención/ráfaga, ventana por `slot`** | `f_eff = f` invariante; retener no crea credenciales | `salida_muestreo.txt` · DEMOSTRADO |
| **Sesgo de respuesta** (honestos apagados) | Exige que responda el **32,8 %** de los honestos muestreados a `f=0,33, q/k=0,60` (40,3 % a `q/k=0,55`) | `salida_muestreo.txt` · VERIFICADO (aritmética) |
| **Supresión dirigida (DoS)** con respuestas absolutas | No puede fabricar `q` rojos: `f·k = 0,33k < q = 0,60k` siempre. Solo **estanca** (viveza) | `salida_muestreo.txt` · DEMOSTRADO |
| **Supresión con normalización por respuestas** | Sí voltea; el diseño debe contar `q` de `k` identidades **absolutas**, no fracción de respondedores | `salida_muestreo.txt` · DEMOSTRADO |
| **Sybil de claves** (partir el espacio) | No cambia el peso total; D9 lo demostró teorema en la 5.ª ronda | `dag-poas-capa-finalidad.md:47-56` · DEMOSTRADO |
| **Eclipse del nodo que muestrea** | Fuera del modelo del paper (`:242-254, :288-294`); real en Internet | Heilman et al. · LAGUNA de transporte |
| **Voto embebido en bloque (sin muestreo)** | El chit rojo ocurre con `f=0,33` por bloque; ruina del jugador `(f/(1−f))^β` = 4,1e-4 a `β=11`. Con muestreo, `(p_adv/p_hon)^β` = 2,5e-45 | `salida_muestreo.txt` · DEMOSTRADO (la diferencia) |

**El punto que decide el diseño:** el muestreo **no es solo ahorro de mensajes, es la seguridad**.
Convierte la fracción adversaria `f=0,33` en la cola hipergeométrica `P(H(n,fn,k) ≥ q)=7,8e-5`, que
es ~40 órdenes de magnitud menor que `f` a igual `β`. Un voto por bloque (cabecera) no tiene esa
protección: es peso de cadena con otro nombre.

### 4.5 · El 1,35 s del paper no es alcanzable a `f=0,33`

El 1,35 s es la mediana de latencia del despliegue de Avalanche en 20 ciudades con 2 000 nodos
(`:1253-1255`); en un solo emplazamiento la mediana es 0,206 s y el máximo 0,4 s (`:1125-1130`).
Las consultas son **una vez por transacción** y la confianza se acumula por la progenie del
DAG (`:712-730`). Los parámetros de seguridad desplegados son `k=10, q/k=0,8, β1=11, β2=150`, y
garantizan `10^-9` **con 20 % bizantino** (`:1279-1285`); con `f≥0,25` esa configuración rompe la
viveza (medido: 20/20 rojo). **A `f=0,33` el paper no publica latencia medida.** El 1,35 s no se
puede citar como alcanzable en el umbral operativo de ZEROX; lo que hay es la tabla de §5.

---

## 5 · Pregunta 4 — Latencia en ZEROX

**Modelo.** Rondas medidas (`salida_agentes.txt`, 20 semillas, `f=0,33`, `p0=1`, sin retardo).
Tiempo de ronda `T ∈ {2Δ (consulta-respuesta), Δ (voto por gossip)}`. Profundidad de alineación
`d = Δ/λ = Δ` segundos (`λ=1`) para que el checkpoint esté en el pasado común. Latencia
`= d + r90·T`. Baseline: **130,41 s**.

| Config | r90 | T=2Δ, Δ=1 | T=2Δ, Δ=4 | T=2Δ, Δ=16 | T=2Δ, Δ=20 | T=Δ, Δ=1 | T=Δ, Δ=4 | T=Δ, Δ=16 | T=Δ, Δ=20 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `k=20, q=12` | 16 | 33 | 132 | 528 | 660 | 17 | 68 | 272 | 340 |
| `k=50, q=30` | 14 | **29** | **116** | 464 | 580 | **15** | **60** | 240 | 300 |
| `k=50, q=32` | 18 | 37 | 148 | 592 | 740 | 19 | 76 | 304 | 380 |
| `k=100, q=60` | 13 | **27** | **108** | 432 | 540 | **14** | **56** | 224 | 280 |
| `k=100, q=65` | 19 | 39 | 156 | 624 | 780 | 20 | 80 | 320 | 400 |

Fuente: `salida_latencia.txt`. **Cruce con el baseline:**

| `Δ` | `k=50,q=30`, T=2Δ | T=Δ | veredicto |
|---:|---:|---:|---|
| 1 | 29 s | 15 s | **GANA** |
| 2 | 58 s | 30 s | **GANA** |
| 4 | 116 s | 60 s | **GANA (al filo, T=2Δ)** |
| 8 | 232 s | 120 s | PIERDE (T=2Δ) / empata (T=Δ) |
| 16 | 464 s | 240 s | **PIERDE** |
| 20 | 580 s | 300 s | **PIERDE** |

**Umbral de decisión:** `r90·2Δ + Δ < 130,41` → `Δ < 4,5 s` (consulta-respuesta);
`r90·Δ + Δ < 130,41` → `Δ < 8,7 s` (gossip). **`Δ` sigue sin medir (E1).** La vía baja la
irreversibilidad **si y solo si `Δ ≲ 4-9 s`**; con `Δ=16-20 s` la empeora 2-5×.

**Gossip exigido.** La consulta dirigida necesita `k` consultas + `k` respuestas por nodo y ronda;
si **todos** los nodos votan, con `n=10 000, k=50` son ~100 MB/s agregados (`salida_latencia.txt`).
Si solo muestrean los interesados (exchanges, servidores de cartera), el coste cae a los
mensajes de esos nodos. El voto embebido en cabecera (~32-64 B/bloque, 1-2 GB/año) evita los
mensajes pero **pierde la amplificación del muestreo** (§4.4): no es sustituto. La vía intermedia
es consulta por gossip con respuestas firmadas y `O(n)` por consulta; el coste exacto no está
medido en ZEROX: LAGUNA.

---

## 6 · Pregunta 5 — Composición con GHOSTDAG + PoAS

**No es un fork choice alternativo ni una capa inocua: es un *override* de la finalidad.** Tres
posiciones posibles, y solo una compra algo:

| Posición | Qué hace | ¿Baja la irreversibilidad? | Etiqueta |
|---|---|---|---|
| **A · Señal asesora** | El nodo avisa «final» a su usuario, pero sigue a GHOSTDAG si aparece más `blue_work` | **No.** La finalidad económica del usuario es la de la cadena; el aviso no la cambia | **REFUTADO** como mejora |
| **B · Override vinculante** | Tras `β1` chits, el nodo **MUST NOT** reorganizar por debajo (patrón R-FIN-18 de P-040) | **Sí, en el caso normal:** la cadena la fija el voto, no `blue_work`, y el adversario tiene que ganar el voto (p_adv^β ≈ 1e-45) en vez de la carrera de peso | **PLAUSIBLE**, con el fallo nuevo de abajo |
| **C · Sustituir GHOSTDAG** | El voto elige la cadena; GHOSTDAG solo ordena | Sí, pero invalida R-FIN-1..14 (ancla, época, retarget por `blue_work`) | **LAGUNA**; no recomendado para v1 |

**Convivencia con R-FIN-7 y `C-REORG-07`.** La regla de B encaja como *la más profunda de las
dos*: `finalidad = max(voto, R-FIN-7)`. El voto solo puede **adelantar**; nunca retrasa `F`. Una
punta que exigiera reorganizar por debajo del checkpoint votado se **ignora** (mismo patrón que
R-FIN-7, `dag-poas-ancla-de-orden.md:271-277`). `C-REORG-07` ya está sustituida en el DAG por
R-FIN-7 (`dag-poas-ancla-de-orden.md:273`); la capa no la toca. **No hay contradicción formal.**

**El fallo nuevo, que hay que escribir.** Un certificado/voto sin *slashing* no tiene
responsabilidad: si el voto finaliza dos checkpoints distintos en una partición (dos lados con
`p0<0,746`), el nodo queda **congelado en la mentira para siempre** — el mismo riesgo de P-040 §6.1
(`dag-poas-capa-finalidad.md:290-293`), ahora con la `ε` de Snowball en vez de un certificado de
⅔. Sin dinero no hay castigo; la única defensa es la alineación inicial (`d ≥ Δ`) y el fallback
`F` de R-FIN-7.

**Mensaje nuevo.** Consulta/respuesta firmada (`color` o hash de checkpoint, ~100 B), o campo de
voto en cabecera. La consulta exige resolver clave→dirección (§2.2); la cabecera no, pero pierde
la seguridad del muestreo. Coste en §5.

---

## 7 · Pregunta 6 — ¿Cae bajo la prohibición de comité?

**Definición estricta** (la que usa el paper y la que hace operativa la restricción): un comité de
decisión es un **conjunto con membresía, cuyos votos/firmas constituyen la decisión** (quórum,
certificado, voto vinculante). Snowball **no es eso**: no hay membresía (cualquiera entra ganando
un bloque), no hay certificado, no hay voto vinculante, y **cada nodo decide solo** tras su propio
contador; el paper lo llama «leaderless BFT … via network subsampling» (`:6-8`) y tolera
discrepancias de membresía (`:82-85, :288-291`). La muestra **no decide**: cada nodo la usa para
actualizar su propia preferencia. **Bajo la definición estricta, NO cae bajo la prohibición.**

**Definición amplia** (la de 14C: «conjunto fijo o muestreado cuyos votos deciden»): entonces sí,
porque la muestra acotada determina estadísticamente la decisión. Pero esa definición también
convierte en comité a **GossipSub** y a cualquier agregación de opiniones; D8b ya señaló que es una
decisión de alcance, no un resultado técnico (`audita-d8b.md:348-352`). **Mi respuesta explícita:**
con la definición de Katana («sin comités de decisión; descentralización y seguridad»), Snowball
**no es un comité de decisión**; es un sondeo abierto y ponderado por espacio, sin cuerpo que
decida. Si Katana quiere prohibir *todo* subconjunto muestreado, entonces ninguna vía de
submuestreo sobrevive y hay que decirlo con esas palabras: no es una refutación técnica, es un
cambio de alcance. **Recomiendo la definición estricta y dejar escrita la salvedad:** el conjunto
de la ventana es finito y público por decisión; la seguridad no viene de su membresía sino de que
la muestra es un estimador insesgado del espacio.

---

## Veredicto

| Punto | Resultado | Etiqueta |
|---|---|---|
| ¿Se puede muestrear sin registro? | Sí: soluciones/productores de una ventana por `slot`; sin censo ni tabla | **VERIFICADO** el mecanismo |
| ¿Resiste Sybil? | Sí: `soluciones ∝ espacio`; partir claves no cambia el total; el burst por publicación se anula indexando por `slot` | **DEMOSTRADO** |
| ¿Exige dinero? | **No.** Sin stake, sin depósito, sin slashing; los 2.000 AVAX son despliegue de Avalanche | **VERIFICADO** |
| ¿Es comité? | Estricto: **no**. Amplio: sí, como GossipSub | **PLAUSIBLE** (decisión de alcance) |
| Umbral de sondeo a `f=0,33` | `q/k ∈ (0,5; 0,67)`; margen útil 1,7-6,7 puntos | **DEMOSTRADO** (paper `:598-599`) |
| Seguridad del voto (conservadora) | MTTF `10^1684` años a `k=50,q=30`; 0 fallos en 20 semillas con Snowball | **VERIFICADO** en simulación · cota analítica **PLAUSIBLE** |
| Alineación inicial | Si `p0 < 0,746` de honestos, el adversario gana el voto (20/20 semillas) | **VERIFICADO** |
| Latencia | `Δ≤4 s` → 29-116 s (T=2Δ) o 15-60 s (T=Δ): **GANA** al baseline de 130,41 s. `Δ≥16` → 464-580 s: **PIERDE** | **VERIFICADO** el modelo · **LAGUNA** `Δ` real |
| ¿Capa o fork choice? | Asesora: no compra nada. Override vinculante: compra latencia y añade el fallo permanente sin slashing. Sustituir GHOSTDAG: núcleo nuevo sin análisis | **PLAUSIBLE** |
| Ataques de muestreo | Sesgo de respuesta (32,8 % online), supresión (estanca), eclipse (LAGUNA), burst por publicación (REFUTADO con ventana por `slot`) | **VERIFICADO/DEMOSTRADO** |
| Coste de gossip | ~100 MB/s agregados a `n=10 000, k=50` si todos votan; voto en cabecera 1-2 GB/año pero pierde la seguridad del muestreo | **VERIFICADO** (aritmética) |

### Tabla pedida por el encargo

| | Snowball sobre peso de espacio en ZEROX |
|---|---|
| **Latencia** | `Δ≤4 s`: **29-116 s** (T=2Δ) / 15-60 s (T=Δ) → gana a 130,41 s. `Δ≥16 s`: 464-580 s → pierde. `Δ` **LAGUNA** (E1) |
| **¿Comité?** | **No** en la definición estricta (sin membresía, sin certificado, sin voto vinculante; decisión local). Sí en la amplia, como GossipSub |
| **¿Dinero?** | **No.** Sin stake/depósito/slashing; peso = prueba de espacio. 2.000 AVAX = despliegue de Avalanche, no protocolo |
| **Sybil** | **Resiste** con ventana por `slot`: soluciones ∝ espacio, partir claves no cambia el total. Ventana por publicación: **REFUTADA** (ráfaga) |
| **Supuestos** | `Δ ≲ 4 s`; checkpoint a profundidad `≥Δ` (alineación `p0>0,746`); honestos online y respondiendo (≥32,8 % de los muestreados); sin eclipse del sampler; `f<1−q/k` |
| **Coste** | `O(k)` mensajes por nodo y ronda si todos votan (~100 MB/s a `n=10 000,k=50`); consulta dirigida exige clave→dirección; fallo nuevo: split permanente sin slashing |
| **Fuente** | `salida_ctmc.txt`, `salida_agentes.txt`, `salida_muestreo.txt`, `salida_latencia.txt`; arXiv:1906.08936 `:24, :242-254, :271-273, :318-319, :598-599, :1022-1023, :1254, :1279-1285, :2173-2240` |

**Veredicto en una frase.** La vía **no muere por comité, ni por Sybil, ni por dinero**: muere o
vive por `Δ` y por la alineación inicial. Con `Δ ≲ 4 s` y checkpoint a profundidad `≥ Δ`, Snowball
sobre peso de espacio baja la irreversibilidad de **130,41 s a ~29-116 s** (T=2Δ; 15-60 s con
T=Δ) con `ε` dominada por los ataques de vista, no por la dinámica del voto. Con `Δ ≥ 16 s` **no
mejora el baseline**. Antes de escribir una línea de consenso hacen falta tres medidas: (1) `Δ`
real (E1); (2) la fracción de espacio honesta online y capaz de responder consultas; (3) la
distribución de tamaño de granja para la varianza del peso. **Recomendación: no adoptar todavía;
mantener como P abierta condicionada a `Δ`.** La alternativa que sí conviene cerrar es el coste de
la vía de P-040, que esta ronda no reabre.

---

## Errores propios

1. **Primer CTMC mal planteado.** Traté `i=c` (todos los honestos azules) como absorbente, cuando
   con `f>0` la tasa `µ_c = c·H(n,f,k,q)` es positiva. *Qué cambió:* el instrumento pasó de
   calcular `ξ` (absorción) a calcular la **MTTF hacia `i=0`** con `c` reflectante; los números de
   `ξ_c=0` de la primera corrida eran un artefacto y se descartaron.
2. **Confundí la decisión de Snowball con el contador consecutivo.** La primera simulación usaba
   `cnt≥β` con `β=150` (Figs. 5/6) y no decidía nunca a `f=0,1`; el camino real de Avalanche es la
   **confianza** `d[color]≥β1` (Fig. 10, `isAccepted`), y el consecutivo es el fallback. *Qué
   cambió:* la rejilla de rondas y la tabla de latencia usan `β1`; el consecutivo se reporta como
   refuerzo, no como camino principal.
3. **Pensé que el ataque de retención funcionaba contra toda ventana.** No: contra una ventana por
   **`slot`** el atacante no crea credenciales (su fracción queda en `f`); solo funciona contra una
   ventana por **publicación**. *Qué cambió:* la recomendación de diseño (indexar por `slot`) y la
   refutación del ataque de ráfaga.
4. **Casi descarté el muestreo como «solo coste de mensajes».** El cálculo de ruina del jugador
   muestra que el voto embebido en bloque (sin muestreo) tiene una probabilidad de chit rojo de
   `f=0,33`, y el muestreo la baja a `7,8e-5`: el muestreo es **carga estructural de seguridad**.
   *Qué cambió:* la vía «cabecera barata» queda como alternativa peor, no como preferida.
5. **El retardo `L` en la simulación no cambia las rondas** porque arranco con `p0=1`; solo se ve
   al partir de `p0=0,7` (13→33 rondas). No es un fallo del retardo, es del escenario: la
   sensibilidad a `Δ` real está en `T(Δ)`, no en el número de rondas.
6. **No ejecuté git** (instrucción de la ronda), aunque `METODO-AGENTES.md:6` pide commit por
   punto. Única desviación del método.

---

## 10 · Reproducción y auditoría

```
cd research/scripts/d15-avalanche
python3 snowball_ctmc.py        # -> salida_ctmc.txt
python3 snowball_agentes.py     # -> salida_agentes.txt
python3 ataque_muestreo.py      # -> salida_muestreo.txt
python3 latencia_snowball.py    # -> salida_latencia.txt
python3 ../AUDITA_SCRIPTS.py .  # -> salida_auditoria.txt
```

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d15-avalanche/
Scripts analizados: 4

======================================================================
Sospechas totales: 0
```

Sin sospechas T1/T2/T3/T3b/T4. Criterio α cumplido: en `snowball_agentes.py` los resultados
cambian con `f` (a `f≥0,45` con `k=50,q=30` todas las semillas deciden rojo; a `f=0` convergen en
11 rondas) y con `q` (a `k=10,q=8` y `f≥0,25`, rojo; a `q=6`, convergen).

## Fuentes

**Locales (research/fuentes/).** `phantom-ghostdag.txt` · `heilman2015-eclipse.txt` ·
`research/dag-poas-ancla-de-orden.md` (R-FIN-7 `:271-277`; R-FIN-11 `:206-217`; R-FIN-13
`:219-234`; R-FIN-14 `:236-266`; PoT 96,1 ms/slot `:312`) ·
`research/dag-poas-capa-finalidad.md` (P-040: R-FIN-15/16/18 `:60-93`; permanencia `:290-293`) ·
`research/scripts/d14-dagknight/salida_zerox2.txt:32` (baseline 130,41 s) ·
`research/scripts/d14-sin-comite/informe.md` (14C) · `research/scripts/d14-sin-comite/audita-d8b.md`
(Avalanche no-comité `:321-352`).

**Paper primario (copia en `research/scripts/d14-sin-comite/fuentes/`).**
`avalanche-1906.08936.txt` (arXiv:1906.08936v2): 1,35 s `:24, :1254`; adversario `:242-254`;
Sybil pluggable `:255-278`; muestreo `:318-319`; viveza `:598-599`; Snowball Fig. 6 `:418-437`;
Avalanche DAG `:667-730`; parámetros `:1022-1023`; MTTF/`10^-9` a 20 % `:1279-1285`; A.3 `:2017-2077`;
A.7 vistas partidas `:2173-2240`.

**Autonomys (`/home/katana/zeo/fuentes/subspace` @ `f8842d0`).**
`crates/subspace-core-primitives/src/sectors.rs:45-65` (`SectorId = H(pk‖sector_index‖history_size)`) ·
`crates/subspace-farmer-components/src/plotting.rs:108-126` (el plot son piezas de historia) ·
`crates/sc-consensus-subspace/src/archiver.rs:73,473` (KZG para segmentos, no por granjero).

**Externo no verificado en local.** `docs.avax.network` (stake de 2.000 AVAX): citado por 14C;
D8b no lo verificó y esta ronda tampoco (dato de despliegue, no del protocolo). LAGUNA.
