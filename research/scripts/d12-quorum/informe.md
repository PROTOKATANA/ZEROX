# D12 · Finalidad por quórum de soluciones como gadget sobre el DAG, frente a la capa estilo Filecoin

**Agente:** D12 · **Fecha:** 2026-09-10 · **Encargo:** `research/scripts/d12-quorum/ENCARGO.md`
**Método:** `research/scripts/METODO-AGENTES.md` (sin presupuesto de tiempo; LAGUNA nunca por falta de tiempo).

**Fuentes primarias leídas enteras antes de medir:**

| Fuente | Ruta | Qué se usa |
|---|---|---|
| Keller y Böhme, *HotPoW* | `research/fuentes/hotpow.txt` (1 942 líneas) | §3 teoría de quórums, §4 protocolo, §5 evaluación, Apéndices A/B/C |
| Sankagiri et al., *CAP Theorem Allows User-Dependent Adaptivity and Finality* | `research/fuentes/cap-adaptividad-finalidad.txt` | marco de dos reglas de confirmación |
| Lewis-Pye y Roughgarden, *Resource Pools and the CAP Theorem* | `research/fuentes/lewispye-roughgarden-cap.pdf` **descargado hoy** de `arxiv.org/pdf/2006.10698`, extraído con `pypdf` a `.txt` | Teorema 4.1 y sus hipótesis |
| Propuesta rival | `research/dag-poas-capa-finalidad.md` (R-FIN-15..22) | la comparación |
| Diseño vivo | `research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1..14), `research/dag-poas-catalogo-problemas-ataques.md` | la composición |
| Kaspa | `/home/katana/zeo/fuentes/rusty-kaspa @ c338d495` | reglas de selección y finalidad |
| Autonomys | `/home/katana/zeo/fuentes/subspace @ f8842d0` | tamaño real de una solución |

---

## A · Control positivo y auditoría del cálculo de partida

**Script:** `d12_a_control.py` · **Salida:** `salida_a.txt`

### A.1 · Los números del paper, reproducidos con tres instrumentos independientes

Tres vías para la misma cantidad: (1) la forma cerrada del Lema 1 en precisión arbitraria por la
gamma incompleta regularizada —la forma que el propio paper usa en la demostración del Teorema 1,
`hotpow.txt:1660-1668`, `f(k) = P(2k,k) = γ(2k,k)/(2k−1)!`—, (2) `scipy.stats.poisson.sf`, y
(3) un **Monte Carlo del proceso de Poisson de la Definición 1** (`hotpow.txt:279-283`), que no usa
ninguna fórmula cerrada: genera tiempos entre ATV exponenciales y cuenta.

| Control | Publicado | Reproducido | Etiqueta |
|---|---:|---:|---|
| POA de Bitcoin, `k = 1`, `λ = 0,1`, `t = 10 min` (`hotpow.txt:392-397`) | 0,2642 | **0,2642** | VERIFICADO |
| Tabla A.1, `k = 2` (`hotpow.txt:1839`) | 0,1429 | **0,14288** | VERIFICADO |
| Tabla A.1, `k = 16` | 0,0003 | **2,762e-04** | VERIFICADO |
| Tabla A.1, `k = 64` | 1,2e-12 | **1,2724e-12** | VERIFICADO |
| Tabla A.1, `k = 256` | 4e-45 | **3,959e-45** | VERIFICADO |
| Corolario 2: independencia de `λ` (`hotpow.txt:379-386`) | — | dispersión relativa **≤ 3,5e-15** sobre `λ ∈ {0,01 … 1 000}` para `k = 1, 16, 64` | VERIFICADO |
| Ec. (14), tasa asintótica `ln(e/4)` | −0,38629 | −0,51215 (`k=16`) → −0,38745 (`k=4 096`), converge por arriba | VERIFICADO |

El Monte Carlo (12 semillas: 11, 22, …, 333; 400 000 realizaciones cada una) coincide con la forma
cerrada en las siete configuraciones probadas, dentro del IC del 95 %:

| `k` | `λ` | MC media | IC 95 % | cerrada |
|---:|---:|---:|---|---:|
| 1 | 0,10 | 0,264341 | [0,264000, 0,264682] | 0,264241 |
| 2 | 1,00 | 0,142797 | [0,142542, 0,143052] | 0,142877 |
| 8 | 1,00 | 0,008253 | [0,008157, 0,008350] | 0,008231 |
| 16 | 1,00 | 0,000280 | [0,000267, 0,000293] | 0,000276 |

> **Nota de honestidad sobre el MC.** Las filas `(k=1, λ=0,1)` y `(k=1, λ=1,0)` salen **idénticas**, y
> las `(k=16, λ=0,1)`/`(k=16, λ=1,0)` también. No es un fallo del instrumento: el suceso
> `T_{2k} ≤ k/λ` es invariante de escala en `λ`, y con la misma semilla los uniformes subyacentes son
> los mismos. Es, de hecho, **la demostración muestral del Corolario 2**. Criterio α: el resultado sí
> cambia —y mucho— al cambiar `k` (0,264 → 1,27e-12 entre `k=1` y `k=64`), que es el parámetro que se
> estudia.

**Lo que NO se ha podido replicar:** la validación empírica sobre datos históricos de Bitcoin
(`ĥp = 0,2606` sobre 2017-2018, `hotpow.txt:397-401`) exige la serie de sellos de tiempo de Bitcoin,
que no está en local. **LAGUNA menor**; haría falta descargar los encabezados de Bitcoin. No afecta a
ninguna conclusión: es una validación del paper contra la realidad, no del instrumento.

### A.2 · Auditoría de `research/scripts/rendimiento/verif_quorum_soluciones.py`

| # | Afirmación del script | Veredicto |
|---|---|---|
| 1 | `POA(k) = P[Poisson(k) ≥ 2k]` | **CORRECTA.** Es literalmente el Corolario 2 (`hotpow.txt:379-386`): Lema 1 da `P[Poisson(λt) ≥ 2k]`, Corolario 1 da `t̄ = k/λ`, luego `λt̄ = k` |
| 2 | «independiente de λ» | **CORRECTA**, VERIFICADO en A.1c |
| 3 | Rutina propia `poisson_sf` | **CORRECTA.** Peor error relativo **6,4e-14** frente a mpmath/scipy en `k ∈ [16, 256]`. La condición de corte y el tope `k > λ·40 + 2000` no muerden en ese rango |
| 4 | «cae ~`e^{−0,386k}`» | **CORRECTA.** `ln(e/4) = −0,38629`, exactamente la tasa de la Ec. (14). Para `k` finito el decaimiento real es más rápido (−0,428 a `k=64`) |
| 5 | «un `k`-quórum tarda ~`k` segundos» a `λ = 1/s` | **CORRECTA en aritmética, ENGAÑOSA en composición.** `t̄ = k/λ`. Pero en HotPoW la tasa de **votos** es `k·λ_bloque` (`hotpow.txt:200-208`: *«HotPoW asks for k easier puzzles each expected to take 10/k minutes»*), de modo que el quórum tarda **un intervalo de bloque**. Si el voto es nuestro bloque, `λ_voto = λ_bloque = 1/s`, el quórum tarda `k` s **y consume `k` bloques**. Ver punto B |
| 6 | `bls = 48 + (k+7)//8` — certificado agregado « < 60 B » | **ERROR.** Ver abajo |

**El error 6, con el número del propio paper.** Un mapa de bits solo comprime si existe un **registro
ordenado de firmantes** contra el que indexar. En F3 lo hay: la tabla de poder. HotPoW **no tiene
registro** —esa es su ventaja anunciada— y por eso sus votos son autoportantes: la clave pública del
votante viaja **dentro** del voto. El paper lo tarifa en la Tabla A.1 (`hotpow.txt:1835-1843`):

| `k` | cabecera del paper | modelo `32 + 40k` |
|---:|---:|---:|
| 1 | 72 B | 72 B |
| 2 | 112 B | 112 B |
| 16 | 672 B | 672 B |
| 64 | 2,6 kB | 2 592 B |
| 256 | 10 kB | 10 272 B |

El modelo `32 + 40k` reproduce la tabla exactamente: 32 B de referencia común más **40 B por voto**
(32 B de clave pública + 8 B de solución). No hay 60 B agregados; **hay 40 B por voto que no se
pueden agregar sin reintroducir el registro** que la propuesta presume no necesitar. Y 8 B es el
tamaño de una solución de PoW; el de una solución de **espacio** de Autonomys es otro (punto F).

**Errores propios que declaro ya:** el `bls = 48 + (k+7)//8` del cálculo de partida es mío y es
inaplicable sin registro. El resto del script de partida es aritméticamente correcto.

**Etiqueta del punto A: VERIFICADO** (control positivo reproducido con tres instrumentos; un error
del cálculo de partida localizado y cuantificado).

---

## B · La composición con el DAG, que el paper NO hace

**Script:** `d12_b_composicion.py` · **Salida:** `salida_b.txt`

HotPoW **sustituye** el consenso; aquí se quiere **encima** de GHOSTDAG con el ancla por índice de
PoT. Todo lo que sigue es lo que aparece al hacer la composición.

### B.0 · Control positivo del segundo instrumento

`prev()` (`research/scripts/d9-ronda9a/r9a_a3_frontera.py:36-49`, idéntica a
`d8-ronda8/d8_a1c_riesgo.py:29-40`) reproduce los dos números publicados en el encargo para
`α = 0,33`: **1,516e-06 a los 600 s** y **7,071e-36 a los 1 800 s**. VERIFICADO.

### B.1 · ¿Sobre qué se vota?

| Candidato | Lo que tiene en contra | Etiqueta |
|---|---|---|
| Un bloque de la **cadena seleccionada** | `blue_score` no es monótono (*«In GHOSTDAG this no longer holds … the blue score of the virtual node actually decreases»*, citado en `dag-poas-ancla-de-orden.md:31-34`), pero **`blue_work` sí lo es bajo ancestría** (Lema A4b, R-FIN-10). Votar por «`B` está en mi cadena seleccionada» es una afirmación bien definida y monótona si se ancla en `blue_work` | **es el único candidato viable** |
| El ancla `I_j` | Ya es objeto de *steering* (rondas 3-10, A3 del catálogo). Un certificado sobre el ancla multiplicaría por `m ≤ 1 + λ·S_max = 151` los candidatos entre los que el atacante elige, exactamente el ataque que §4.D de la propuesta rival tuvo que pagar subiendo `K` de 1 000 a 4 000 | descartado |
| Un punto de `blue_work` | `blue_work` es una **afirmación de la cabecera**, no algo verificable sin colorear el DAG (`dag-poas-ancla-de-orden.md:398-400`). Un certificado sobre `blue_work` no es autoverificable, que era la única gracia del certificado | descartado |

**DEMOSTRADO** (por eliminación, con las citas de arriba): si se hace, se vota por un **bloque de la
cadena seleccionada**, identificado por su hash.

### B.2 · ¿De dónde sale el voto? — la pregunta que decide

Las dos únicas variantes, y lo que cada una implica:

**Variante 1 · el voto es el propio bloque.** `λ_voto = λ_bloque = 1/s`. Un `k`-quórum son `k`
bloques y tarda `k` segundos.

> **Es profundidad de confirmación con otro nombre. DEMOSTRADO.** Tres argumentos independientes:
>
> 1. **No hay información nueva.** El certificado «`k` bloques de la cadena seleccionada
>    descienden de `B`» es exactamente el predicado «`B` tiene `k` confirmaciones». No se
>    transmite ni un bit que el nodo no tuviera.
> 2. **La unicidad del quórum no la da la teoría de quórums.** Un voto de HotPoW es `(r, p, s)`
>    con `Hpow(r,p,s) ≤ tv` (`hotpow.txt:437-441`) y nada impide seguir buscando soluciones para
>    una `r` vieja: el atacante produce votos para `r` a tasa `αλ` **para siempre**. Medido
>    (`salida_b.txt`, B.b): a `α = 0,33` y `k = 64` le bastan **194 s** para tener un certificado
>    propio y válido para un valor en conflicto. Lo que impide el conflicto en HotPoW es la regla
>    de cabeza (Listing 4.6, línea 41, `hotpow.txt:597-601`: no cambiar de estado ya comprometido),
>    que es **literalmente R-FIN-7** y es literalmente lo que hace Kaspa
>    (`virtual_processor/processor.rs:1013` `is_chain_ancestor_of(finality_point, candidate)`;
>    `:1033` *«Finality Violation Detected. Block … is ignored from Virtual chain»*).
> 3. **Confirmación independiente en la literatura.** Sankagiri et al. clasifican HotStuff —el
>    protocolo del que HotPoW toma el *commit* de tres fases— como **incumplidor de CP1, la
>    condición de recencia**: *«PBFT and Hotstuff don't satisfy the CP1 (the recency condition).
>    The adversary could potentially lock on a block B privately when it becomes the leader of one
>    view, and then finalizes B as a checkpoint after a long time when B is no longer in the best
>    chain»* (`cap-adaptividad-finalidad.txt:1575-1580`). Es el mismo ataque que mido en B.b,
>    descrito por otros autores tres años antes.

**Variante 2 · voto aparte, `λ_voto = k·λ_bloque`.** Es la de HotPoW (*«HotPoW asks for k easier
puzzles each expected to take 10/k minutes»*, `hotpow.txt:200-208`). Aquí sí hay información nueva:
`k` muestras de espacio por intervalo de bloque en vez de una. **Es la única variante que puede
comprar algo.** Lo que cuesta está en C (retardo) y en F (bytes y CPU), y lo que rompe, en F.7.

### B.3 · La regla de selección, escrita y demostrada

**Texto propuesto (candidato, NO escrito en el SPEC — va aquí por el método):**

> **R-QUO-1 · Prioridad de la finalidad más profunda.** Sea `cert(B)` un certificado válido para el
> bloque de cadena `B`. Un nodo **MUST NOT** reorganizar por debajo de `B` mientras conozca
> `cert(B)`. En ausencia de certificado rige **R-FIN-7 sin cambios**. Cuando haya las dos, manda la
> **más profunda en `blue_work` de la cadena seleccionada**. Un certificado **MUST NOT** invalidar
> ningún bloque ni apagar el proceso: una punta que exigiera reorganizar por debajo de `B` se
> **ignora**, exactamente como en R-FIN-7.
>
> **R-QUO-2 · Recencia (CP1).** Un voto es válido para `B` solo si `slot(voto) ∈ [slot(B) + d,
> slot(B) + d + W)`. Un certificado con un voto fuera de esa ventana es inválido. `d` es la
> profundidad mínima de voto y `W` la ventana de quórum.

**Demostración de que el certificado solo puede adelantar la finalidad, nunca retrasarla.**
El conjunto de bloques finalizados por R-FIN-7 en el instante `t` es
`Fin₇(t) = {B : slot(punta) − slot(B) ≥ F}`, que es **creciente en `t`** y función solo de la cadena.
`R-QUO-1` define `Fin(t) = Fin₇(t) ∪ {B : conozco cert(B)}`. Como es una **unión**, `Fin(t) ⊇ Fin₇(t)`
para todo `t`: ningún bloque deja de estar finalizado por la llegada de un certificado. Y como la
regla de la punta es *ignorar* y no *invalidar* —igual que R-FIN-7 y que `processor.rs:1033`—, la
llegada de un certificado no puede volver inválido ningún bloque ya válido (R-FIN-4 hace la validez
función de `past(B)` y nada más, y un certificado no está en `past(B)`). **DEMOSTRADO.**

**Lo que la demostración NO cubre, y es lo grave.** Que el certificado no *retrase* nada no
significa que no pueda *adelantar una mentira*. `Fin` crece, sí, pero puede crecer con un `B`
equivocado, y entonces **la mentira es permanente**: es el ataque 6.1 que la propuesta rival ya se
declara a sí misma. Esa es la asimetría real de cualquier gadget de finalidad: convierte una
reorganización temporal y visible en un **split permanente**. El número está en D.6.

### B.4 · R-FIN-5, un flujo por PoT

R-FIN-5 dice: *«Para todo `X ∈ past(B)`: `flujo(X, slot(X)) = flujo(B, slot(X))`. Un bloque MUST NOT
referenciar un bloque de otro flujo»* — y el motivo es de coste: *«un nodo honesto jamás verifica el
PoT de un flujo ajeno»* (`dag-poas-ancla-de-orden.md:196-200`).

Un certificado **no es un bloque**, luego la letra no lo prohíbe. Pero un voto sí lleva `slot`, y por
R-FIN-14(c) la validez de una solución se comprueba **bajo un flujo**: `f = flujo(B, s)`. Un voto de
otro flujo obliga al verificador a evaluar el PoT ajeno, que es exactamente lo que R-FIN-5 existe
para impedir. Y sin la comprobación, un atacante puede fabricar votos bajo un flujo privado barato.

> **Regla necesaria (candidata):** **R-QUO-3.** Un voto para `B` es válido solo si
> `flujo(voto, slot(voto)) = flujo(B, slot(voto))`. Un certificado con votos de otro flujo es
> inválido y **se descarta antes de tocar ningún PoT**, igual que R-FIN-5.
>
> **Consecuencia que hay que decir:** con esa regla, un certificado **no cruza flujos**, luego **no
> ayuda a resolver una partición** — que era una de las cosas para las que uno querría un gadget.
> Y sin ella, el certificado es un vector de DoS de verificación de PoT (`C-NET-03/04`, B4 del
> catálogo). **PLAUSIBLE** (argumento cerrado sobre el texto de las reglas; no medido).

### B.5 · Y el número que ordena todo el punto

`POA(k)` **no depende de `α`** — se evalúa con `α = 0,00 / 0,25 / 0,33 / 0,49` y da 1,272367e-12 las
cuatro veces. **Falla el criterio α del método.** No es una cota de seguridad frente a un adversario:
es `P[mala realización]` **condicionada** a excluir PoW-1 y PoW-2 *por hipótesis*
(`hotpow.txt:265-272`). Y crece con el tiempo:

| `t` (con `k = 64`, `λ_voto = 1/s`) | 64 s (`= t̄`) | 128 s | 256 s |
|---|---:|---:|---:|
| `POA(64, t)` | 1,272e-12 | **0,5118** | 1,000 |

**Un `k`-quórum de 64 es «prácticamente único» exactamente en el instante `t̄`, y a los 128 s la
ambigüedad ya es del 51 %.** El paper evalúa en `t̄` *«in order to isolate the effect of k»*
(`hotpow.txt:374-377`), no como cota del protocolo desplegado — y el cálculo de partida (mío) leyó
`1,3e-12` como si lo fuera. **Es el segundo error propio.**

### B.6 · La tabla de poder implícita

Para impedir la acumulación de B.2 hace falta la ventana `W` de R-QUO-2, y entonces `k` tiene que
caber entre lo que produce el atacante y lo que producen los honestos:

```
α·λ_v·W   <   k   <   (1−α)(1−δ)·λ_v·W
```

Eso **es** una tabla de poder: hay que conocer `λ_v` (la sostiene el retarget) y acotar `α` (PoW-2).
**La ventaja anunciada «sin tabla de poder, sin suponer quién está encendido» es falsa: la tabla
sigue ahí, solo que implícita y menos informativa** — y por ser implícita no se puede indexar con un
mapa de bits (A.2d, F.3). Ventana mínima medida para que **los dos** riesgos bajen del objetivo:

| `α` | `λ_v` | `W` a 1e-6 | `W` a 1e-12 | `W` a 1e-30 |
|---:|---:|---:|---:|---:|
| 0,25 | 1/s | 170 s | 368 s | 976 s |
| **0,33** | **1/s** | **382 s** | **830 s** | **2 201 s** |
| 0,40 | 1/s | 1 122 s | 2 452 s | 6 499 s |
| 0,45 | 1/s | 4 514 s | 9 880 s | 26 228 s |
| 0,33 | 64/s | 6 s | 13 s | 34 s |

Con pérdida honesta por retardo `δ = 0,267` (el `δ_real` del diseño) a `α = 0,33` y `λ_v = 1/s`:
**1 420 s / 3 103 s / 8 226 s**; y a `α = 0,40`, **23 972 s** para un mísero 1e-6.

**Etiqueta del punto B: la variante 1 es REFUTADA como aportación** (es profundidad de confirmación,
DEMOSTRADO); **la variante 2 queda viva y pasa a C y F.**
