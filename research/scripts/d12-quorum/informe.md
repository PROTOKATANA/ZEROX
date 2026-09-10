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
