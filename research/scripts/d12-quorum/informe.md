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

---

## D · Cuándo se para bajo ataque y cómo se recupera

**Script:** `d12_d_parada.py` · **Salida:** `salida_d.txt`

**El teorema, con su enunciado exacto y sus hipótesis.** Lewis-Pye y Roughgarden, Teorema 4.1
(`research/fuentes/lewispye-roughgarden-cap.txt:759`): *«No protocol is both adaptive and has
finality»*, donde **adaptativo** = vivo en el escenario **sin tamaño** (Def. 3.2, `:727-728`) y
**finalidad** = seguro en el parcialmente síncrono (Def. 3.4, `:744-745`), bajo la hipótesis
*«no balance, no voice»* (`:754-757`). La idea de la demostración, literal: *«in the unsized (and
partially synchronous) setting … network partitions [are] indistinguishable from waning resource
pools»* (`:774-777`).

> **Cómo escapa HotPoW: no escapa, se sale del escenario.** Excluye PoW-1 *por axioma*
> (`hotpow.txt:265-267` y `:1300-1303`: *«under axiomatic exclusion of the failure modes PoW-1 and
> PoW-2»*), que es exactamente ponerse en el escenario **con tamaño**. Quien sostiene ese tamaño en
> la práctica es el retarget, y el retarget tiene inercia: `W_RETARGET ≥ 3 083` índices de PoT
> (R-FIN-13). **DEMOSTRADO** que la parada es inevitable; lo medible es cuánto dura.

### D.1 · Fracción de instancias que no cierran quórum (atacante que retiene votos)

Con `W` = tiempo esperado de quórum honesto, **la mitad no cierra** (es la mediana de una Poisson).
Con holgura `W = c·k/((1−α)λ)`:

| `α` | `k` | `c` | `W` | `P[no cierra]` | `P[el atacante forja el certificado solo]` |
|---:|---:|---:|---:|---:|---:|
| 0,33 | 32 | 1,5 | 71,6 s | 5,9e-03 | **5,8e-02** |
| 0,33 | 64 | 1,5 | 143,3 s | 2,2e-04 | **1,2e-02** |
| 0,33 | 64 | 2,0 | 191,0 s | 1,4e-10 | **0,469** |
| 0,33 | 128 | 1,5 | 286,6 s | 3,8e-07 | 6,2e-04 |
| 0,40 | 64 | 1,5 | 160,0 s | 2,2e-04 | **0,517** |

**La pinza es la noticia.** Subir `W` mata la viveza del atacante… y le regala la seguridad: a
`α = 0,33`, `k = 64`, `c = 2`, el gadget cierra siempre y **el atacante forja su propio certificado
el 47 % de las veces**. Los dos riesgos no se pueden bajar a la vez sin subir `W` muchísimo (B.6).

Con la pérdida honesta por retardo `δ = 0,267`, `P[no cierra]` a `W = t̄` pasa de 0,48 a **0,99**
(`k = 64`). El retardo se come la viveza del gadget antes que ninguna otra cosa.

**Control del instrumento (D.1c):** Monte Carlo con 12 semillas (11, 23, …, 127; 200 000
realizaciones) frente al exacto: 0,006029 [0,005900, 0,006158] vs 0,005925. VERIFICADO.
*Nota honesta:* la columna de viveza sale **idéntica** para `α` distintos porque `W` se define como
`c·k/(1−α)`, que fija `μ_h = c·k`. La dependencia de `α` está toda en la columna de seguridad, que
sí se mueve tres órdenes de magnitud.

### D.2 · Tiempo hasta que vuelve a cerrarse

Las instancias son independientes (votos nuevos, ventana nueva), luego el número de instancias
hasta la primera que cierra es geométrico. Con `c = 1,5` la recuperación es de **una instancia**
(`E[espera] ≈ W`, p99 `= W`): a `α = 0,33` y `k = 64`, **143 s**. La parada *por ataque de retención*
es corta. La que no lo es está en D.4.

### D.3 · ¿Sigue avanzando la cadena entretanto? **Sí. DEMOSTRADO por la regla.**

R-FIN-7 ignora la punta, no apaga el proceso, y es literalmente lo que hace Kaspa
(`virtual_processor/processor.rs:1013` y `:1033`, *«ignored from Virtual chain»*). La cadena sigue
creciendo a `(1−α)λ` y `F = 2 h` sigue siendo el suelo. Es la misma propiedad que declara el FIP-0086
citado por la propuesta rival: *«EC … continues operating "normally" if F3 assumptions are violated
and F3 halts»*.

### D.4 · La parada que ES el teorema: se apaga espacio y `λ_v` cae

Si una fracción `(1−ρ)` del espacio se apaga de golpe, `λ_v` cae a `ρλ` hasta que el retarget
reacciona. Con `W` dimensionada para `α = 0,33` y `c = 1,5`:

| `ρ` | `k = 32` | `k = 64` | `k = 128` |
|---:|---:|---:|---:|
| 0,90 | 0,033 | 0,005 | 0,000 |
| **0,70** | **0,368** | **0,332** | **0,279** |
| 0,50 | 0,932 | 0,984 | 0,999 |
| 0,30 | 1,000 | 1,000 | 1,000 |

**Recuperación: una ventana de retarget, `W_RETARGET ≥ 3 083` s ≈ 51 min**, durante la cual el
gadget está caído y la cadena corre. A `ρ = 0,5` se pierden entre 21 y 40 instancias seguidas. Esto
**no es un ataque**: es un lunes por la mañana con el 30 % de los granjeros domésticos apagados. Es
la misma laguna que la propuesta rival declara en su §4.C («la `p` real de un granjero doméstico»),
solo que aquí aparece por otra puerta.

### D.5 · Partición

Fracción mínima de espacio de un lado para seguir certificando (misma `W`):

| `k` | `f` para `P[no cierra] < 0,5` | `f` para `< 0,01` |
|---:|---:|---:|
| 32 | 0,442 | 0,651 |
| 64 | 0,444 | 0,587 |
| 128 | 0,446 | 0,544 |

Frente al **9 %** que tolera R-FIN-7 (D9-d A4). **Matiz honesto:** el retarget del propio lado
restauraría `λ_v` pasados `W_RETARGET` s, así que la exigencia de 44-65 % vale para los primeros
~51 min de partición, no indefinidamente. Con `F = 2 h > W_RETARGET` la mayor parte de la ventana
de tolerancia queda cubierta, pero el gadget está caído durante el primer cuarto de ella.

### D.6 · La comparación que decide, y un error propio corregido

**Error propio (declarado).** Mi primera versión comparaba `W` con la espera de hoy como si el
certificado **sustituyera** a la profundidad. No la sustituye:

> Un granjero honesto vota por un bloque que **cree** en su cadena seleccionada. Si se equivoca, se
> equivocan **todos a la vez**, porque comparten la vista. Ese fallo es de **modo común** y el
> quórum no lo divide por nada: `POA` acota que existan **dos** certificados en conflicto, no que el
> **único** certificado esté sobre un bloque que la cadena va a abandonar.

Luego la garantía de un certificado emitido en `t = d + W` es `max( prev(α, d), P_forja(k, W, α) )`,
con `d` la profundidad a la que los honestos ya coinciden. Y sin gadget, esperando **el mismo tiempo**
`d + W`, la garantía es `prev(α, d + W)`. Como `prev` es **decreciente** en `t`:

```
prev(α, d)  >  prev(α, d + W)      para todo α < 1/2, todo d, todo W > 0
```

**El gadget está estrictamente dominado, por exactamente los `W` segundos que tarda en juntar el
quórum. DEMOSTRADO.**

| `α` | objetivo | `d` necesaria | `W` del gadget | total con gadget | total sin gadget | penalización |
|---:|---:|---:|---:|---:|---:|---:|
| 0,25 | 1e-12 | 482 s | 370 s | 852 s | **482 s** | +370 s |
| **0,33** | **1e-12** | **871 s** | **832 s** | **1 702 s** | **871 s** | **+832 s** |
| 0,33 | 1e-30 | 1 597 s | 2 201 s | 3 798 s | **1 597 s** | +2 201 s |
| 0,40 | 1e-30 | 4 126 s | 6 502 s | 10 629 s | **4 126 s** | +6 502 s |

La única salida sería que los honestos votaran a profundidad `d = 0`, como hace HotPoW (todos votan
por la única cabeza que elige su regla de preferencia). En nuestro DAG a `λ = 1/s` con `Δ > 0` hay
del orden de `λΔ` puntas simultáneas y los honestos **no** coinciden en la punta — es lo que mide C.
Y el catálogo ya lo declara como coste estructural **D6**: *«Ninguna confirmación posible antes de
≈ 3k/((1−α)λ) = 100-134 s, con ninguna F»*.

**Etiqueta del punto D: DEMOSTRADO** (dominación estricta) **+ VERIFICADO** (las tres tablas).

---

## F · El coste real del certificado — el punto que decide la comparación

**Script:** `d12_f_certificado.py` · **Salidas:** `salida_f.txt`, `salida_bench_kzg.txt`

### F.1 · Un voto de PoAS no son 72 B: son 484 B

Del código, campo a campo (`subspace @ f8842d0`,
`crates/subspace-core-primitives/src/solutions.rs:254-274`):

| campo | B | fuente |
|---|---:|---|
| `public_key` | 32 | `lib.rs:210` |
| `reward_address` | 32 | `AccountId32` |
| `sector_index` | 2 | `sectors.rs:25` (`u16`) |
| `history_size` | 8 | `segments.rs:274` (`NonZeroU64`) |
| `piece_offset` | 2 | `pieces.rs:229` (`u16`) |
| `record_commitment` | 48 | `pieces.rs:801` |
| `record_witness` | 48 | `pieces.rs:937` |
| `chunk` | 32 | `lib.rs:258` (`FULL_BYTES`) |
| `chunk_witness` | 48 | `solutions.rs:241` |
| `proof_of_space` | 160 | `pos.rs:103-105` (`K=20`, `SIZE = K·8`) |
| **`Solution`** | **412** | |

Voto autoportante = solución sin `reward_address` (380) + referencia (32) + slot (8) + firma Ed25519
(64) = **484 B**. En HotPoW un voto son **72 B**, porque una solución de PoW son 8 B y una de
**espacio** son 380. **Factor 48× en la parte que manda.**

### F.2 · Bytes por certificado y por año

| variante | `k` | certificado | cada 30 s | cada 64 s | cada 300 s | cada 1 h |
|---|---:|---:|---:|---:|---:|---:|
| 1 · voto = bloque (`k` cabeceras) | 64 | 43 712 B | 45,95 GB | 21,54 GB | 4,60 GB | 0,38 GB |
| 2 · voto aparte, Ed25519 | 64 | 31 008 B | 32,60 GB | 15,28 GB | 3,26 GB | 0,27 GB |
| 2 · voto aparte, BLS agregada | 64 | 30 032 B | 31,57 GB | 14,80 GB | 3,16 GB | 0,26 GB |
| 2 · voto aparte, BLS agregada | 128 | 59 984 B | 63,06 GB | 29,56 GB | 6,31 GB | 0,53 GB |

Referencias: cabeceras del diseño **21,50 GB/año**; PoT **4,0 GB/año**; capa estilo Filecoin
**724 B cada 30 s = 0,76 GB/año** (`dag-poas-capa-finalidad.md` §4.B).

### F.3 · La agregación BLS aquí **no sirve de nada**

| `k` | Ed25519 | BLS agregada | ahorro |
|---:|---:|---:|---:|
| 64 | 31 008 B | 30 032 B | **3,15 %** |
| 4 000 | 1 936 032 B | 1 872 080 B | **3,30 %** |

Frente al **99,70 %** que compra en F3 (237 728 B → 724 B). La razón es estructural: la agregación
comprime **firmas**, y en F3 el voto **es** una firma. Aquí el voto está dominado por la prueba de
espacio, que no se agrega. **La ventaja criptográfica anunciada del gadget se cae por los dos lados:
ni evita BLS (F.5) ni lo aprovecha.**

### F.4 · Tráfico de gossip de la variante 2

`λ_voto = k·λ` con `λ = 1/s`:

| `k` | votos/s | kB/s | **TB/año** |
|---:|---:|---:|---:|
| 16 | 16 | 7,7 | 0,24 |
| **64** | **64** | **31,0** | **0,98** |
| 256 | 256 | 123,9 | 3,91 |

La cadena entera son 0,0215 TB/año. **La variante que compra algo cuesta 45× la cadena en tráfico.**

### F.5 · ¿Obliga a BLS12-381? — **ya está dentro, y no por la finalidad**

`verify_solution` (`crates/subspace-verification/src/lib.rs:264-272`) llama a `kzg.verify(...)` para
comprobar que el `chunk` pertenece al `record_commitment`. Ese KZG es **`rust-kzg-blst`**
(`Cargo.toml:113,180`; `shared/subspace-kzg/Cargo.toml:24-27`), es decir **`blst` de Supranational,
C y ensamblador, sobre BLS12-381**, en la ruta de consenso de **todos** los nodos y para **todos**
los bloques. Y R-FIN-14(c) del diseño vivo cita literalmente `subspace-verification/src/lib.rs:234-260`,
que es esa misma función.

> **Consecuencia para la comparación, y es grande.** El coste que `dag-poas-capa-finalidad.md` §5
> presenta como bifurcación de Katana —meter BLS12-381 y `blst` en la ruta de consenso— **ya está
> pagado** si ZEROX adopta el PoAS de Autonomys con testigos KZG. No es una dependencia nueva de la
> capa de finalidad: es una dependencia del consenso. **VERIFICADO** en el código; **PLAUSIBLE** que
> ZEROX lo herede (el diseño cita la función, pero no hay una regla `C-XXX` que fije el esquema de
> archivado).

### F.6 · CPU de verificación, medida en esta máquina

`cargo bench -p subspace-kzg --bench kzg -- verify` (Criterion, 100 muestras):
**`kzg.verify` = 1,0773 ms** [1,0719 ; 1,0887].
*(La línea «change: −98,88 %» del banco es una colisión de nombre de Criterion con el banco `verify`
del PoT —96,1 ms/slot—, no una regresión: los identificadores comparten directorio.)*

| `k` | ms por certificado | % de un núcleo (1 cert/64 s) | % de un núcleo (variante 2) |
|---:|---:|---:|---:|
| 64 | 68,95 | 0,11 % | **6,89 %** |
| 128 | 137,89 | 0,22 % | **13,79 %** |
| 256 | 275,79 | 0,43 % | **27,58 %** |

La variante 2 suma **6,9 % de un núcleo** al **9,6 %** que ya cuesta el PoT (D4 del catálogo).

### F.7 · **Equivocación gratis: lo que rompe la Definición 1**

La Definición 1 de HotPoW (`hotpow.txt:279-283`): *«Each ATV can be used by the agent it is assigned
to, to vote **once** for **one** value»*. Toda la teoría de POA descansa ahí: dos quórums en
conflicto exigen `2k` ATVs. En HotPoW se cumple **por construcción**, porque el voto **es** la
solución y la solución contiene la referencia: `Hpow(r, p, s) ≤ tv` (`hotpow.txt:437-441`). Cambiar
`r` obliga a resolver otro puzzle.

**En PoAS no se cumple.** `verify_solution` (`subspace-verification/src/lib.rs:228-272`) **no ve
ninguna referencia al valor votado**: el reto es `global_randomness.derive_global_challenge(slot)`,
función del PoT y del **slot**. La atadura al valor la pone una **firma aparte**
(`check_reward_signature`, `lib.rs:107-117`; en ZEROX `C-HDR-03/04` con Ed25519), y una clave firma
cuantos mensajes quiera. **Una sola solución puede votar por todos los valores en conflicto a la vez,
a coste cero.**

Entonces dos quórums en conflicto ya no exigen `2k` ATVs sino `k`:

| `k` | POA con la Def. 1 (`2k`) | POA con equivocación (`k`) |
|---:|---:|---:|
| 16 | 2,762e-04 | **0,5333** |
| 64 | 1,272e-12 | **0,5166** |
| 256 | 3,959e-45 | **0,5083** |

**Sin regla anti-equivocación el gadget no tiene seguridad ninguna: la ambigüedad es ~0,5 para
cualquier `k`. REFUTADO.** Y una regla anti-equivocación exige castigo, o sea **R-FIN-19 de la
propuesta rival**, o sea **dinero en juego**: la ventaja anunciada «sin dinero en juego» desaparece.
La única alternativa es que el voto sea un **bloque**, donde U2/U3″ (R-FIN-11) ya da un voto por
identidad de billete — y eso es la variante 1, que es profundidad de confirmación (B.2).

**Etiqueta del punto F: REFUTADO** (la equivocación gratis y el coste de agregación cierran la
variante 2; F.5 quita a la propuesta rival su coste declarado principal).

---

## C · El umbral, con nuestro `Δ`, y el ataque de censura reproducido

**Script:** `d12_c_censura.py` · **Salida:** `salida_c.txt`

### C.0 · Control positivo (Figura 11 del paper), con un instrumento mejor que el suyo

El modelo del Apéndice B (`hotpow.txt:1856-1927`) es una cadena de Markov absorbente. Como **todas**
sus transiciones incrementan `a+d` en uno, se puede barrer por niveles `n = a+d` y **resolverla
exacta** en vez de con las 10⁶ realizaciones del paper. Resultado (`salida_c.txt`, C.1):

| `k` | `α = 0,020` | `α = 0,100` | `α = 0,200` | `α = 0,333` | `α = 0,500` |
|---:|---:|---:|---:|---:|---:|
| 1 | 0,0200 | 0,1000 | 0,2000 | 0,3333 | 0,5000 |
| 64 | 0,0204 | 0,1091 | 0,2339 | **0,4153** | **0,6432** |
| 256 | 0,0204 | 0,1094 | 0,2347 | 0,4170 | 0,6456 |

El paper: *«an α = 1/3 attacker contributes roughly 42 % (α = 1/2: 64 %) of the blocks»*
(`hotpow.txt:963-967`). **Reproducido. VERIFICADO.** Masa sin absorber ≤ 9,9e-16.

**Control del control:** Monte Carlo vectorizado, 12 semillas × 30 000 rondas, contra la DP exacta:
las seis configuraciones caen a **≤ 0,60 intervalos de confianza** del valor exacto. El simulador,
que es el que después se usa con retardo, es correcto en el caso que el paper publica.

### C.1 · Qué le hace el retardo a la unicidad del quórum

Dos honestos con vistas distintas votan valores distintos **sin ser atacantes**. El paper lo
reconoce y lo trata con la regla de preferencia (§5.2.1, `hotpow.txt:930-940`: *«as soon as the
first vote is received from an honest node, all honest nodes converge to a single value»*), es
decir: **resuelve el problema con un consenso**. Nosotros ya tenemos ese consenso —GHOSTDAG— y por
tanto el gadget no puede aportarlo; lo que aporta es la exigencia de que los honestos coincidan en
el valor votado, y eso obliga a votar a profundidad `d > 0` (D.6). Cuantitativamente, la pérdida
honesta se comporta como un `δ` y entra en la condición de B.6: con `δ = 0,267` la ventana mínima a
`α = 0,33` pasa de 830 s a **3 103 s** (objetivo 1e-12), y a `α = 0,45` **no existe ninguna `W`**.

### C.2 · El umbral compuesto

No es el mínimo de los dos, ni el del paper. Se compone así:

1. **Techo propio del gadget.** La condición `α·λ_v·W < k < (1−α)(1−δ)·λ_v·W` sólo tiene solución si
   `α < (1−δ)/(2−δ)`. Con `δ = 0` da el `α < 1/2` del paper; con el `δ_real = 0,267` del diseño da
   **42,30 %**; con el `δ_ef = 0,129` medido bajo U3″ (D9-d A3), **46,55 %**. Es un techo asintótico
   (`W → ∞`): **operativamente muere mucho antes** — a `α = 0,40` con `δ` hacen falta 23 972 s para
   un objetivo de 1e-6 (B.6).
2. **Frontera del DAG.** 44,6 % con `F = 2 h`, 38,3 % a `Δ = 16 s` (9a; catálogo A1/B1).
3. **Y el término que no es de ninguno de los dos:** un certificado sobre el bloque equivocado es
   **permanente**, no una reorganización temporal. Por eso el umbral compuesto es **la frontera
   recalculada con el horizonte de finalidad que impone el gadget**, `d + W`, que es lo que mide
   G.1 — y sale **por debajo** de la de hoy, no por encima.

### C.3 · El ataque de censura por retención de votos, en nuestro régimen

Cuota de certificados que controla el atacante (12 semillas × 20 000 rondas por configuración;
adversario del paper: ve todo al instante y no paga `Δ`; los honestos sí):

| `α` | `k` | `Δ = 0` | `Δ = 4 s` | `Δ = 8 s` | `Δ = 16 s` |
|---:|---:|---:|---:|---:|---:|
| **Variante 1 · el voto es el bloque (`λ_v = 1/s`)** | | | | | |
| 0,25 | 64 | 0,3010 | 0,3062 | 0,3139 | 0,3291 |
| **0,33** | **64** | **0,4105** | **0,4154** | **0,4242** | **0,4380** |
| 0,40 | 64 | 0,5086 | 0,5148 | 0,5197 | 0,5338 |
| **Variante 2 · voto aparte (`λ_v = k/s`), la de HotPoW** | | | | | |
| 0,10 | 64 | 0,1093 | 0,2337 | 0,2779 | **0,3221** |
| 0,25 | 64 | 0,3010 | 0,5055 | 0,5708 | **0,6316** |
| **0,33** | **64** | **0,4105** | **0,6164** | **0,6801** | **0,7389** |
| 0,40 | 64 | 0,5086 | 0,7002 | 0,7572 | **0,8088** |

**La respuesta a la pregunta del encargo:** un atacante al 33 % controla **el 41,5 %** de los
certificados en la variante 1 (que es la que no aporta nada) y **entre el 61,6 % y el 73,9 %** en la
variante 2 (que es la que aportaría algo), según `Δ`.

> **Y el hallazgo del punto:** *el retardo destruye precisamente la variante que compra algo.* En la
> variante 1 la ronda dura `k` segundos y `Δ = 4 s` es un 6 % de ella: la cuota sube 1,2 puntos. En
> la variante 2 la ronda dura ~1 s y `Δ = 4 s` es **cuatro veces** la ronda: la cuota sube **20,6
> puntos**. Es la misma física que la Figura 8 del paper (*«latencies in the order of 10 % of the
> expected block time delay the commit by about 20 %»*, `hotpow.txt:892-896`), llevada al régimen
> donde la latencia es 400 % del tiempo de quórum. Y `Δ` es **E1 del catálogo: sin medir.**
>
> Con `Δ = 16 s` un atacante del **10 %** ya controla un tercio de los certificados en la variante 2.

**Etiqueta del punto C: VERIFICADO** (control positivo del paper reproducido exacto; el ataque
portado a nuestro régimen con 12 semillas y cobertura de rama completa: 9 845 129 éxitos del
atacante y 13 194 871 de los honestos sobre 23 040 000 rondas, sin rondas truncadas).

---

## G · Lo que el gadget NO arregla, y lo que abre

**Script:** `d12_g_frontera_cliente.py` · **Salida:** `salida_g.txt`

### G.1 · Del catálogo, qué sigue exactamente igual

| # | Problema | Con el gadget puesto |
|---|---|---|
| A1 | Carrera de bloques | **Igual, o peor.** El gadget no cambia quién gana la cadena seleccionada; sólo cambia cuándo se deja de reorganizar. Y acortar ese horizonte **baja** la frontera (G.2) |
| A3/A4 | *Steering* y soborno del ancla | **Igual.** Y si se votara el ancla, peor (B.1) |
| A5 | Sembrador (plotter rápido) | **Igual.** El lookahead depende de `L` y `ρ`, no del gadget |
| B1 | Retardo adversarial `Δ_ef` | **Peor.** El gadget añade una segunda dependencia de `Δ`, y en la variante útil es catastrófica (C.3) |
| B2 | Eclipse | **Mejora en detección**, no en consenso: el Apéndice C del paper (`hotpow.txt:1928-1941`) muestra que con quórums grandes un nodo detecta el eclipse en 0,11 tiempos de bloque en vez de 6,91. **Es la única ganancia real que encuentro, y no necesita el gadget: basta contar votos** |
| C1 | Timekeeper único | **Igual** |
| D1 | Sin cliente ligero | **Igual: no lo resucita** (G.3) |
| D4 | Verificación de PoT no sucinta | **Peor:** +6,9 % de un núcleo en la variante 2 (F.6) |
| D5 | Umbral por debajo del 50 % | **Igual o peor** (C.2) |
| D6 | Suelo de confirmación 100-134 s | **Igual, y es lo que impide `d = 0`** (D.6) |
| E1 | `Δ` sin medir | **Manda más que antes** |

### G.2 · Sí toca la frontera de flujo único, y hacia abajo

El instrumento es el `frontera()` de D9-9a **sin reescribirlo**, con `F_SEG` sustituida (el horizonte
de finalidad efectivo). Control positivo: reproduce los dos números publicados.

| horizonte de finalidad efectivo | frontera 1e-10 |
|---|---:|
| `F = 5,3 h` (medido, diseño vivo) | **46,88 %** (publicado 46,9 % ✓) |
| `F = 2 h` (provisional, DECIDIDO) | **44,69 %** (publicado 44,6 % ✓) |
| `F = 1 h` (candidata de producción) | 42,14 % |
| `d+W = 3 798 s` (gadget, `α=0,33`, objetivo 1e-30) | 42,38 % |
| `d+W = 1 702 s` (gadget, `α=0,33`, objetivo 1e-12) | 37,79 % |
| `d+W = 988 s` (gadget, `α=0,33`, objetivo 1e-6) | **32,98 %** ← por debajo del umbral operativo publicado (33 %) |
| sólo `W = 143 s` (`k=64`, `c=1,5`: el gadget «rápido») | **SIN FRONTERA: el riesgo es 1 para todo `α`** |

> La última fila no es un artefacto del buscador: `union10(α) = 1` para todo `α ∈ [0,05 ; 0,499]` a
> ese horizonte, porque en 143 s los honestos apenas construyen 96 bloques contra la ventaja inicial
> de `3k = 90`. Un certificado a 143 s **no finaliza nada**: finaliza con probabilidad de reversión 1.

**Lectura:** si el gadget se usa para **acortar** el horizonte —que es para lo que se quiere—, la
frontera **baja**. Sólo es neutro si el certificado llega **después** de que `prev()` ya haya bajado
por sí sola, que es exactamente la dominación de D.6.

### G.3 · El cliente ligero: no lo resucita, y la razón es estructural

| | Capa estilo Filecoin | Quórum de soluciones |
|---|---|---|
| Qué es un voto | una **firma** de una clave que está en la tabla de poder | una **prueba de espacio** contra el reto del slot |
| Qué hace falta para verificarlo | la tabla, que va comprometida en el certificado anterior (R-FIN-21) | `derive_global_challenge(slot)` (`subspace-verification/src/lib.rs:234-236`), es decir **la salida del PoT de ese slot**, más el `record_commitment` de la historia archivada para el KZG |
| ¿Autoverificable desde génesis? | **Sí** (*«Verifying the finality of a tipset from genesis does not require access to the EC chain»*) | **No** |
| Coste del cliente | **6,6 MB/año** (R-FIN-22, sin auditar) | **4,0 GB/año de PoT + ~840 h de núcleo al año** de verificación secuencial (96,1 ms/slot, D4), más 263 MB/año de certificados |

> **Y esto es lo que ordena la comparación entera.** La propiedad que resucita al cliente ligero
> —que el certificado se verifique sin la cadena— se la da a F3 **exactamente la tabla de poder que
> el quórum de soluciones presume no necesitar**. El registro no es el defecto de la otra propuesta:
> es su producto. **DEMOSTRADO** sobre la definición de las dos reglas y el código de verificación.

### G.4 · Lo que abre, que hoy no existe

1. **Equivocación gratis (F.7).** Nuevo y letal. No existe hoy porque hoy el único objeto firmado es
   un bloque, y U2/U3″ ya castiga la copia dentro del DAG.
2. **La mentira permanente.** Igual que la otra propuesta (su §6.1), con la diferencia de que aquí la
   probabilidad no es 6,5e-105 sino `prev(α, d)`, que es un número **grande** si `d` es pequeño.
3. **DoS de verificación de votos.** Cada voto inválido cuesta 1,08 ms de KZG. A `λ_v = k/s` un
   atacante que inunde con votos falsos fuerza `k` verificaciones por segundo por nodo. `C-NET-03/04`
   se calibraron para un SHA3 y ya había que rehacerlos por el PoT (E18); esto lo agrava.
4. **Certificados de otro flujo** (B.4): sin R-QUO-3 son un vector de verificación de PoT ajeno;
   con ella, el certificado no cruza flujos y por tanto no ayuda en una partición.

**Etiqueta del punto G: VERIFICADO** (frontera) **+ DEMOSTRADO** (cliente ligero).

---

## E · Cara a cara con la capa estilo Filecoin

Mismas condiciones: `λ = 1 bloque/s`, `τ = 1 s`, `α = 0,33` (umbral operativo publicado), `Δ` sin
medir, `F = 2 h` como suelo. Las columnas de la capa estilo Filecoin salen de
`research/dag-poas-capa-finalidad.md` §4 (**sin auditar**, salvo donde digo lo contrario).

| Dimensión | **Quórum de soluciones** (HotPoW portado) | **Capa estilo Filecoin** (R-FIN-15..22) |
|---|---|---|
| **Finalidad conseguida** | Ninguna que mejore lo que hay. `d + W = 1 702 s` a `α=0,33` y objetivo 1e-12, frente a **871 s** esperando sin nada (D.6). **Estrictamente dominada** | Decenas de segundos en el caso normal; una instancia cada 30 s. Es una mejora real **cuando funciona** |
| **Umbral** | Techo asintótico **42,30 %** con `δ=0,267` (46,55 % con `δ_ef=0,129`); operativamente muere antes (a `α=0,40` hacen falta 23 972 s para un mísero 1e-6). Y **0 % sin regla anti-equivocación** (F.7) | Seguridad (finalizar una mentira) 6,5e-105 a `α=0,33` con `K=4 000`; **viveza rota a 33 %**: se para el 41 % de las instancias (§4.A) |
| **Qué se para y cuándo** | Se para si se apaga espacio: a `ρ = 0,7` no cierra ~1/3 de las instancias; recuperación = **una ventana de retarget, ~51 min** (D.4). Partición: exige que el lado conserve **44-65 %** del espacio, frente al 9 % de R-FIN-7 (D.5) | Se para si la participación honesta `p < ⅔/(1−α)`: **88,9 % a `α=0,25`, 99,5 % a `α=0,33`** (§4.C). Recuperación: cuando vuelva la participación |
| **Estado por nodo** | Ninguno nuevo: los votos son autoportantes | Tabla de poder derivada (bloques cobrados por clave en `W_POWER = 3 600 s`) + `W_VIVO` |
| **Bytes por año** | `k=64`, un certificado cada 64 s: **14,80 GB**; cada hora: 0,26 GB. Y **0,98 TB/año de gossip** en la variante 2 (F.2, F.4) | **0,76 GB/año** (`K=4 000`, certificado cada 30 s, BLS agregada) |
| **CPU por nodo** | **1,0773 ms medidos** por voto (KZG, `cargo bench -p subspace-kzg`). Variante 2: **+6,9 % de un núcleo** continuo sobre el 9,6 % del PoT | Una verificación de firma BLS agregada + mapa de bits por certificado: **despreciable** |
| **Criptografía que obliga a adoptar** | BLS12-381 igualmente (para el KZG de la propia solución) **+** Ed25519 por voto. Y la agregación **sólo ahorra el 3 %** (F.3) | BLS12-381 con `blst`. **Corrección importante: ese coste ya está pagado.** `verify_solution` de Autonomys llama a `kzg.verify` con `rust-kzg-blst` (F.5): `blst` ya está en la ruta de consenso de todos los nodos |
| **Supuestos sobre quién está encendido** | «Ninguno» es falso: excluye PoW-1 **por axioma** (`hotpow.txt:1300-1303`), o sea supone `λ` conocida y constante. Quien la sostiene es el retarget, con 51 min de inercia | Explícito y medible: `p ≥ ⅔/(1−α)`, con `W_VIVO = 1 800 s` como prueba de vida. **Laguna declarada por ellos mismos** |
| **Superficie de ataque nueva** | Equivocación gratis (**letal**), mentira permanente, DoS de verificación de votos a 1,08 ms cada uno, certificados de otro flujo | Doble firma (mitigada con R-FIN-19, que toca dinero), sesgo del sorteo por ancla (`m ≤ 151`, evaluado: sube `K` a 4 000), censura del comité, amplificación de la partición |
| **Cliente ligero** | **No lo resucita.** Verificar un voto exige el PoT del slot: 4,04 GB/año + **842 h de núcleo/año** (G.3) | **Lo resucita: 6,6 MB/año** (R-FIN-22, sin auditar). Es su mayor ganancia y no es la finalidad |
| **Qué hay que demostrar antes de escribirla** | (1) una regla anti-equivocación **sin dinero** —y D9 ya tiene el teorema de que el Sybil de claves rompe toda exclusividad por espacio—; (2) que `Δ ≪ 1/λ_v`, o sea `Δ` ≤ ~0,1 s en la variante útil; (3) que el certificado no baje la frontera (G.2 dice que sí la baja) | (1) la `p` real del granjero doméstico (**medida de campo**, no simulación); (2) las plazas correlacionadas por clave (§7, error declarado por el autor); (3) GossiPBFT portado y leído entero; (4) las dos cadencias de R-FIN-22; (5) `Δ` para los temporizadores |

### E.1 · Lo que esta ronda le cambia a la propuesta rival

Dos cosas, y una es a su favor:

1. **A su favor, y es grande.** Su §5 presenta la adopción de BLS12-381 y `blst` como *«el precio
   real y una bifurcación de Katana»*. **No lo es**: `blst` ya está en la ruta de consenso de todos
   los nodos, dentro de `verify_solution`, para verificar el testigo KZG de cada solución
   (F.5, VERIFICADO en `Cargo.toml:113,180` y `shared/subspace-kzg/Cargo.toml:24-27`). Su coste
   declarado principal **desaparece**, condicionado a que ZEROX herede el esquema de archivado de
   Autonomys —que es lo que R-FIN-14(c) cita.
2. **En su contra.** Su §4.C («el granjero doméstico se apaga») y mi D.4 («se apaga espacio y `λ_v`
   cae») son **el mismo problema medido por dos caminos distintos**, y ninguna de las dos propuestas
   lo resuelve. No es un defecto de la capa de finalidad: es que **una finalidad rápida exige saber
   quién está encendido**, y eso es exactamente lo que el Teorema 4.1 dice que no se puede tener
   gratis en el escenario sin tamaño.

### E.2 · Recomendación

**Ninguna de las dos ahora. PLAUSIBLE.** Y si hubiera que elegir una, **la capa estilo Filecoin, y
no por la finalidad sino por el cliente ligero** — que es lo único de las dos que compra algo que hoy
no existe y que ningún parámetro del diseño actual arregla (D1 del catálogo, ESTRUCTURAL).

**La condición que cambiaría la recomendación:** que la medida de campo de `p` (§4.C de la propuesta
rival) salga por encima del 90 % **y** que `Δ_p99` salga por debajo de 4 s. Con esas dos, la capa
estilo Filecoin pasa de «no funciona en el umbral publicado» a «funciona en el caso normal», y el
cliente ligero de 6,6 MB/año justifica por sí solo el resto. **Ninguna medida de `p` ni de `Δ`
resucita al quórum de soluciones**, porque lo que lo mata (F.7, D.6, G.3) no depende de ellas.

---

## H · Veredicto

### H.1 · ¿Merece la pena el quórum de soluciones? No, y no por poco

Tres disparos independientes, cada uno suficiente por sí solo:

1. **La premisa del paper no se cumple en PoAS.** La Definición 1 —*«cada ATV se usa para votar una
   vez por un valor»*— la garantiza en HotPoW el propio puzzle, porque la referencia va dentro del
   hash (`hotpow.txt:437-441`). En PoAS el reto sale del PoT y del slot y **no ve el valor votado**
   (`subspace-verification/src/lib.rs:228-272`): una solución firma cuantos valores quiera, gratis.
   `POA` pasa de 1,3e-12 a **0,52 para cualquier `k`**. Y arreglarlo exige un castigo, es decir
   dinero en juego, es decir la R-FIN-19 de la otra propuesta: **la ventaja anunciada desaparece por
   completo. REFUTADO.**
2. **Aunque se arreglara, está estrictamente dominado.** El fallo que importa —que el único
   certificado esté sobre un bloque que la cadena abandonará— es de **modo común** y el quórum no lo
   divide por nada. La garantía de un certificado en `t = d + W` es `max(prev(α,d), P_forja)`, y
   esperar `d + W` sin gadget da `prev(α, d+W) < prev(α, d)`. **El gadget cuesta `W` segundos y no
   compra ni un orden de magnitud. DEMOSTRADO.** A `α=0,33` y objetivo 1e-12: 1 702 s con gadget
   frente a **871 s** sin él.
3. **Y no entrega lo único que justificaría el esfuerzo.** El certificado de quórum **no es
   autoverificable**: comprobar un voto exige la salida del PoT de su slot, y el PoT no es sucinto
   (4,04 GB/año + **842 h de núcleo/año**). El cliente ligero sigue muerto. **DEMOSTRADO.**

A eso se añade: a `α = 0,33` el atacante controla entre el 41,5 % y el 73,9 % de los certificados
según la variante y `Δ` (C.3); la variante que compra información cuesta **0,98 TB/año** de gossip y
**+6,9 % de un núcleo** (F.4, F.6); y usar el certificado para acortar el horizonte **baja la
frontera por debajo del 33 % publicado** (G.2).

### H.2 · ¿Cuál de las dos? Ninguna — y el motivo es que la pregunta está mal puesta

**El riesgo de reversión hoy, a `α = 0,33`, es 1,5e-06 a los 10 min y 7,1e-36 a los 30 min** —
reproducido en B.0 con el instrumento del diseño. **La finalidad no es el problema de ZEROX.** Una
espera de 15 minutos para un pago grande es una convención comercial, no un defecto de consenso;
Bitcoin vive con 60 minutos y nadie ha construido un gadget para arreglarlo.

Lo que sí es un problema de ZEROX, ESTRUCTURAL y sin arreglo por parámetros, es **D1: no hay cliente
ligero.** *«Ninguna cartera de ZEROX podrá verificar sus propios pagos sin confiar en un servidor o
correr un nodo completo»* (`dag-poas-ancla-de-orden.md:439-441`).

> **Reformulación que propongo, y es lo más útil que sale de esta ronda.** La capa estilo Filecoin
> no debería evaluarse como *capa de finalidad* —donde su propia §4.A dice que a `α = 0,33` se para
> el 41 % de las instancias— sino como **capa de certificados para el cliente ligero**. En ese
> encuadre:
> - su viveza rota bajo ataque deja de ser fatal: si el gadget se para, el cliente ligero cae al
>   modelo de confianza en un servidor, que es **exactamente donde está hoy**; no se pierde nada;
> - su seguridad, que es lo que importa para un cliente ligero, es 6,5e-105 a `α = 0,33` con
>   `K = 4 000`, y ni el *steering* con `m ≤ 151` la mueve (§4.D);
> - su coste principal declarado (BLS12-381 y `blst`) **ya está pagado** por el KZG del propio PoAS
>   (F.5, VERIFICADO en el código);
> - y su ganancia es 6,6 MB/año frente a 21,5 GB/año, o sea **un móvil frente a una máquina
>   permanente**.
>
> **PLAUSIBLE**, no demostrado: R-FIN-22 sigue sin auditar y las dos cadencias son la primera cosa
> que habría que comprobar.

### H.3 · Lo que decidiría

| Si se mide… | …y sale | Entonces |
|---|---|---|
| `Δ_p99` (E1) | `> 8 s` | ninguna de las dos, sin discusión: la capa estilo Filecoin no calibra sus temporizadores y el quórum ya estaba muerto |
| `p` del granjero doméstico (§4.C) | `< 88,9 %` | la capa estilo Filecoin no vale como finalidad; **sí** como capa de cliente ligero (H.2) |
| `p` | `> 90 %` **y** `Δ_p99 < 4 s` | abrir la capa estilo Filecoin como P-040, con el cliente ligero como objetivo declarado y la finalidad como efecto secundario |
| cualquier cosa | — | el quórum de soluciones **no revive**: lo que lo mata (equivocación, dominación, cliente ligero) no depende de ninguna medida |

**Lo que NO recomiendo por ningún motivo:** escribir el gadget de quórum «porque es barato de
probar». No es barato: exige una regla anti-equivocación nueva, una ventana de voto nueva, una regla
de flujo nueva (R-QUO-3) y toca la regla de selección; y las cuatro son piezas de consenso.

---

## Veredicto

| Punto | Qué se concluye | Etiqueta | Número |
|---|---|---|---|
| **A** · control positivo | Los números del paper se reproducen con tres instrumentos; el cálculo de partida es correcto salvo los bytes | **VERIFICADO** | 0,2642 · 1,2724e-12 · 3,959e-45; error rel. de `poisson_sf` 6,4e-14 |
| **A** · bytes del certificado | El mapa de bits es inaplicable sin registro; el paper cobra 40 B por voto | **REFUTADO** (mi «< 60 B») | `32 + 40k` reproduce la Tabla A.1 exactamente |
| **B.1** · sobre qué se vota | Sólo un bloque de la cadena seleccionada; ancla y `blue_work` descartados | **DEMOSTRADO** | — |
| **B.2** · voto = bloque | Es profundidad de confirmación con otro nombre | **REFUTADO** como aportación | el atacante forja su certificado en **194 s** a `α=0,33`, `k=64` |
| **B.3** · regla de selección | El certificado sólo puede adelantar la finalidad (R-QUO-1) | **DEMOSTRADO** | `Fin(t) ⊇ Fin₇(t)` por unión |
| **B.4** · flujos | Hace falta R-QUO-3, y con ella el certificado no cruza flujos | **PLAUSIBLE** | — |
| **B.5** · `POA` | No depende de `α` (falla el criterio del método) y crece con `t` | **REFUTADO** como cota de seguridad | `POA(64, 2·t̄) = 0,5118` |
| **B.6** · tabla de poder | No desaparece: se vuelve implícita | **DEMOSTRADO** | `W ≥ 2 201 s` a `α=0,33` para 1e-30 |
| **C.0** · Figura 11 | Reproducida exacta con DP en vez de 10⁶ realizaciones | **VERIFICADO** | 0,4153 (paper 42 %) · 0,6432 (paper 64 %) |
| **C.2** · umbral compuesto | Techo asintótico propio del gadget con `δ` | **VERIFICADO** | **42,30 %** (`δ=0,267`); 46,55 % (`δ_ef=0,129`) |
| **C.3** · censura con `Δ` | El retardo destruye justo la variante útil | **VERIFICADO** | `α=0,33`: **41,5 %** (voto=bloque) vs **61,6-73,9 %** (voto aparte, `Δ=4..16 s`) |
| **D.1-D.2** · parada por retención | Pinza: bajar un riesgo sube el otro | **VERIFICADO** | `α=0,33`, `k=64`, `c=2`: no cierra 1,4e-10 **pero forja 0,469** |
| **D.3** · la cadena sigue | Sí, por R-FIN-7, no por el gadget | **DEMOSTRADO** | `processor.rs:1013,1033` |
| **D.4** · parada por el teorema | Se apaga espacio y el gadget cae hasta que reacciona el retarget | **VERIFICADO** | `ρ=0,7`: no cierra el 33 %; recuperación **~51 min** |
| **D.5** · partición | Exige mucho más espacio que R-FIN-7 | **VERIFICADO** | **44-65 %** frente al **9 %** de R-FIN-7 |
| **D.6** · dominación | El gadget está estrictamente dominado por esperar | **DEMOSTRADO** | `α=0,33`, 1e-12: **1 702 s vs 871 s** |
| **F.1-F.4** · coste | Un voto son 484 B, no 72 | **VERIFICADO** | `k=64` cada 64 s: **14,80 GB/año**; gossip **0,98 TB/año** |
| **F.3** · agregación | No sirve: comprime firmas y aquí el voto es una prueba | **VERIFICADO** | **3,15 %** de ahorro frente al **99,70 %** de F3 |
| **F.5** · BLS | `blst` ya está en la ruta de consenso, vía KZG | **VERIFICADO** | `rust-kzg-blst` en `Cargo.toml:113,180` |
| **F.6** · CPU | Medida en esta máquina | **VERIFICADO** | `kzg.verify` = **1,0773 ms** [1,0719 ; 1,0887] |
| **F.7** · equivocación | Rompe la Definición 1 de HotPoW | **REFUTADO** (el gadget entero) | `POA` 1,3e-12 → **0,5166** a `k=64` |
| **G.2** · frontera | El gadget sí la toca, y hacia abajo | **VERIFICADO** | 44,69 % → **32,98 %** a `d+W=988 s`; **sin frontera** a 143 s |
| **G.3** · cliente ligero | No lo resucita; la tabla de poder es lo que se lo da a F3 | **DEMOSTRADO** | 4,04 GB/año + **842 h de núcleo/año** vs 6,6 MB/año |
| **E** · cara a cara | Ninguna de las dos ahora; si una, la estilo Filecoin y por el cliente ligero | **PLAUSIBLE** | — |
| **H** · veredicto | **Ninguna de las dos como capa de finalidad.** Reformular la estilo Filecoin como capa de cliente ligero | **PLAUSIBLE** | riesgo hoy **7,1e-36 a 30 min** con `α=0,33` |
| — | Validación empírica del paper sobre datos de Bitcoin (`p̂ = 0,2606`) | **LAGUNA** | haría falta la serie de sellos de Bitcoin 2017-2018; no está en local y no afecta a ninguna conclusión |
| — | Que ZEROX herede el KZG de Autonomys (base de F.5) | **LAGUNA** | R-FIN-14(c) cita la función que lo contiene, pero no hay regla `C-XXX` que fije el esquema de archivado |
| — | GossiPBFT de F3, no leído | **LAGUNA** | la otra propuesta ya lo declara (§7); no se ha portado ni leído |

## Errores propios

1. **`bls = 48 + (k+7)//8` en `verif_quorum_soluciones.py` (mío, cálculo de partida).** Un mapa de
   bits necesita un registro ordenado de firmantes, y el quórum de soluciones no lo tiene. El coste
   real es **40 B por voto** en HotPoW (Tabla A.1 reproducida) y **484 B por voto** en PoAS.
   *Qué cambió:* el certificado pasa de «< 60 B» a **31 kB** con `k=64`, y el punto F pasa de detalle
   a argumento decisivo.
2. **Leer `POA(64) = 1,3e-12` como probabilidad de fallo del gadget (mío).** Es la probabilidad de
   ambigüedad **en el instante `t̄`**, condicionada a excluir PoW-1 y PoW-2 por hipótesis, y a los
   `2·t̄` ya vale 0,51. *Qué cambió:* la comparación «1,3e-12 frente a 7,1e-36» no era una
   comparación; hubo que rehacer el análisis con un modelo de ventana que sí depende de `α`.
3. **D.6, primera versión (mío, en esta ronda).** Comparé la ventana `W` del gadget con la espera de
   hoy **como si el certificado sustituyera a la profundidad**, y salió que el gadget ganaba en los
   objetivos flojos (1e-6 y 1e-12). Está mal: el fallo de modo común no lo divide el quórum, así que
   el certificado **hereda** `prev(α, d)` y hay que sumar `W` encima. *Qué cambió:* de «el gadget
   gana en 7 de 12 filas» a «el gadget está estrictamente dominado en las 12». La versión errónea
   quedó registrada en el propio script.
4. **`frontera()` devolviendo 49,90 % a `F = 143 s` (mío, en esta ronda).** Es el valor de retorno
   `hi` cuando no hay cruce, y lo leí como una frontera altísima. No lo es: a ese horizonte
   `union10(α) = 1` para todo `α`, o sea **no hay frontera**. *Qué cambió:* la fila pasa de «49,9 %»
   —que habría sido un argumento **a favor** del gadget— a «el certificado no finaliza nada».
   Añadí la comprobación explícita al instrumento para que no vuelva a pasar.
5. **Primera versión del simulador de C con bucle por voto.** Daba los mismos números (verificado
   contra la DP exacta) pero ~50× más lento, y su dimensionado de la ventana `M0` provocaba
   13,2 millones de rondas rechazadas y vueltas a sortear, lo que **condicionaba la muestra**.
   *Qué cambió:* nada en los números (la versión final reproduce la DP a ≤ 0,60 IC en las seis
   configuraciones de control), pero el contador `ronda_ampliada` pasó de 13 214 570 a **0**.

---

## Salida de `AUDITA_SCRIPTS.py`

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d12-quorum/
Scripts analizados: 6

======================================================================
Sospechas totales: 0
```

**Lectura de cada marca.** No queda ninguna. Hubo cinco en la primera pasada, todas del tipo **T3**
(«compara consigo mismo»), y las cinco eran comprobaciones de `NaN` escritas como `x == x`
(`th == th`, `tot_con == tot_con`, `fr == fr`) en `d12_d_parada.py` y `d12_g_frontera_cliente.py`.
Son correctas en Python, pero el detector tiene razón en marcarlas: `x == x` es indistinguible de una
tautología accidental. Se sustituyeron por `not np.isnan(...)`, que dice lo que quiere decir, y los
dos scripts se **volvieron a ejecutar** — con resultados idénticos, que es lo que había que
comprobar. No hay marcas **T1** (parámetro del atacante muerto): todas las funciones adversariales
—`p_no_cierra`, `p_atacante_solo`, `censor_dp`, `_rondas_vectorizadas`, `poa` no, que precisamente
por eso está señalado en B.5— usan `alpha`. No hay **T4**: las tres listas de semillas tienen 12
elementos (`d12_a_control.py:139`, `d12_c_censura.py:29`, `d12_d_parada.py:32`).

### Contadores de cobertura de rama (los seis scripts)

| Script | Contadores |
|---|---|
| `d12_b_composicion.py` | `prev_alpha_{0,10/0,25/0,33/0,40}` = 8 cada uno · `poa` = 8 · `acumula_alpha_*` = 5 cada uno · `region_valida` = 60 · `W_alcanzable` = 81 · `W_no_alcanzable` = 9 |
| `d12_c_censura.py` | `exito_atacante` = 9 845 129 · `exito_honesto` = 13 194 871 (suma exacta = 23 040 000 rondas) · `ronda_ampliada` = **0** · `dp_resuelta` = 45+ |
| `d12_d_parada.py` | `no_cierra_a{0,1/0,25/0,33/0,4}` = 23/21/23/23 · `atacante_solo_a*` = 12 cada uno · `apagon_rho{1,0/0,9/0,7/0,5/0,3}` = 3 cada uno · `W_alcanzada` = 12 · `t_hoy_alcanzada` = 12 |
| `d12_f_certificado.py` | `cert_v1` = 5 · `cert_v2_ed` = 13 · `cert_v2_bls` = 13 · `voto_ed` = 19 · `voto_bls` = 14 |
| `d12_g_frontera_cliente.py` | siete `frontera_F*` = 1 cada una · `sin_frontera_riesgo_1` = 1 |
| `d12_a_control.py` | control positivo puro: las ramas son las siete configuraciones de MC y los cinco `k` de la Tabla A.1, todas ejecutadas |

**La rama que distingue A de B sí se ejecuta** en los dos sitios donde importa: en `d12_c_censura.py`
las dos variantes (`λ_v = 1` y `λ_v = k`) y los cuatro `Δ` recorren las 96 configuraciones con las 12
semillas; en `d12_b_composicion.py` la región factible se visita 60 veces y la infactible produce
`W_no_alcanzable` = 9, que son exactamente las tres filas de `α = 0,45` con `δ = 0,267` por los tres
objetivos.
