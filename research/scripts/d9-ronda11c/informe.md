# D9 · Ronda 11c — Las tres hipótesis del informe de los 52 problemas, puestas a prueba

**Encargo:** `ENCARGO.md` (aquí) · **Método:** `research/scripts/METODO-AGENTES.md`
**Agente:** D9, Opus 5 · **Fecha:** 2026-09-09 · **Directorio único:** `research/scripts/d9-ronda11c/`

> **PRIMERA LÍNEA, como pide el encargo — dos hipótesis no hacen lo que dicen y una introduce una
> magnitud fabricable.** *(Se rellena al cerrar el punto E; hasta entonces esta línea es provisional.)*

---

## Cómo leer este informe

Cinco etiquetas: **DEMOSTRADO** (argumento cerrado), **VERIFICADO** (medido y reproducible),
**PLAUSIBLE** (argumento sin cerrar), **REFUTADO**, **LAGUNA** (no se sabe; se dice qué haría falta).
Cota ≠ realidad. Números con coma decimal.

*(informe incremental: cada punto se escribe al cerrarlo)*

---

# 0 · Tres proposiciones que hay que demostrar ANTES de medir

Las tres se refieren a la lectura del ancla **sobre la cadena seleccionada**, que es donde
R-FIN-1 la define (`research/dag-poas-ancla-de-orden.md:162-165`):

> `I_j(B) :=` el bloque de la cadena seleccionada de `B` con **menor `blue_work` entre los de
> `slot ≥ T_j`**.

Y usan dos hechos ya establecidos por rondas anteriores:

- **(F1) `slot` es no decreciente por la cadena seleccionada.** Es R-FIN-1a en su forma vigente
  (`≤`, `dag-poas-ancla-de-orden.md:184`), confirmada por `research/scripts/verif_a2prima.py`:
  con `≤` las violaciones son **0 por construcción** (un hijo se crea después de su padre).
- **(F2) `blue_work` es estrictamente creciente por la cadena seleccionada.** Es el **Lema A4b**
  de D9-e (`dag-poas-ancla-de-orden-auditoria-5.md:75-76`, 141 967/141 967 parejas), y en el
  simulador se sigue de `r8c_gd.py:258` (`blue_work(B) = blue_work(sp) + |mergeset_blues(B)|`,
  con `|mergeset_blues| ≥ 1` porque el propio `sp` va dentro).

## Prop. 1 — **H1 es una operación nula: da SIEMPRE el mismo bloque que la regla vigente.** DEMOSTRADO

Sea `Chn` la cadena seleccionada y `C = {B ∈ Chn : slot(B) ≥ T_j}` el conjunto de candidatos de la
regla vigente. Por (F2) `blue_work` es inyectiva y creciente sobre `Chn`, luego

  `argmin_{B∈C} blue_work(B) = ` el elemento de `C` de menor índice de cadena, llamémosle `B_q`.

H1 toma `s* = min{slot(B) : B ∈ Chn, slot(B) ≥ T_j}` y `C' = {B ∈ Chn : slot(B) = s*}`, con
desempate por `blue_work`. Por (F1) `slot` es no decreciente por `Chn`, luego para todo `B ∈ C` es
`slot(B) ≥ slot(B_q)`, y por tanto `s* = slot(B_q)` y `B_q ∈ C'`. Además `C' ⊆ C` (todo bloque de
slot `s* ≥ T_j` está en `C`) y `C'` es un tramo **contiguo de `Chn` que empieza exactamente en
`B_q`** (de nuevo por (F1)). El desempate de H1 es `blue_work` mínimo, que por (F2) vuelve a ser el
de menor índice: `B_q`. **Las dos reglas devuelven `B_q`.** ∎

**Consecuencia.** `m_H1 = m_BASE` **exactamente**, semilla a semilla y umbral a umbral; y la
estimación del informe de los 52 problemas («`m → 1,2`», §6b) es **incorrecta**: confunde *el
conjunto de bloques del que se elige* con *el bloque que la regla elige*. La regla vigente ya
selecciona un bloque de un solo slot — el primero que cruza `T_j` —; el menú `m = 2,54` **no viene
de que el atacante pueda elegir un bloque más profundo dentro de la ventana `S_max`**, sino de que
puede cambiar **cuál** bloque ocupa esa primera posición.

> **Y tampoco recorta la cota.** Si las dos reglas devuelven siempre el mismo bloque, TODA magnitud
> derivada coincide: la `m` medida, su cota, `c_m`, `I` y `F`. En particular la cota E de D9-f
> (`auditoria-6.md` §2) —`slot(I_j) ∈ [T_j, T_j + S_max)` por R-FIN-1a, luego `m ≤ 1 + λ·S_max`—
> vale exactamente igual bajo H1, y por la misma razón: lo que hace que el ancla pueda estar 150 s
> por delante de `T_j` no es que la regla mire lejos, es que **la cadena puede dar un salto de slot
> de hasta `S_max`** y entonces el primer bloque que cruza `T_j` está lejos. H1 no toca ese salto.

## Prop. 2 — **H1+H3 ≡ H3**, por el mismo argumento. DEMOSTRADO

H3 restringe los candidatos a `C₃ = {B ∈ C : publicado(B) − slot(B) < S_ancla}` y elige el de menor
`blue_work` = el de menor índice de `C₃`, sea `B_r`. H1+H3 toma `s*₃ = min{slot(B) : B ∈ C₃}` y los
de ese slot dentro de `C₃`; por (F1) ese conjunto es un tramo contiguo que empieza en `B_r`, y el
desempate por `blue_work` devuelve `B_r`. ∎

**Consecuencia.** De las cinco combinaciones que pide el encargo solo hay **tres reglas distintas**:
la vigente (≡ H1), el desempate por `solution_distance` (H2, en sus dos formas) y el filtro de
candidatura (H3 ≡ H1+H3). La medición lo confirma como control de la demostración (§B).

## Prop. 3 — **«publicado» de H3 es el `slot` del sucesor de cadena.** DEMOSTRADO

H3 define `publicado(X) :=` el `slot` del **primer bloque de la cadena seleccionada que referencia a
`X`**. Si `X = Chn[i]` es un bloque de la cadena:

- `Chn[i+1]` referencia a `X` (es su padre seleccionado, luego `X ∈ past(Chn[i+1])`);
- ningún `Chn[j]` con `j ≤ i` lo referencia (`X ∉ past(Chn[j])` para `j ≤ i`, por antisimetría del
  orden topológico);
- todo `Chn[j]` con `j > i+1` tiene `slot(Chn[j]) ≥ slot(Chn[i+1])` por (F1).

Luego `publicado(Chn[i]) = slot(Chn[i+1])`, y la regla H3 se lee, sin ambigüedad:

> **«`B` puede ser ancla solo si el salto de `slot` hasta su sucesor en la cadena seleccionada es
> menor que `S_ancla`.»**

Es **función de `past(·)`** de cualquier bloque que cuelgue de `Chn[i+1]`, y por tanto legible en
local — el punto C.4 lo mide en dos vistas. Y tiene una consecuencia inmediata que el informe de los
52 problemas no vio: **H3 no mide la retención, mide el hueco al sucesor**, y el sucesor puede ser
del atacante (punto C.5). El tip de la cadena no tiene sucesor: `publicado = +∞`, no es candidato
(se cuenta: `sin_sucesor`).

---

# C · ¿Reabren algo? — la parte argumental

*(las medidas van en §C.medido, más abajo; aquí van los argumentos y lo que cada uno predice)*

## C.1 · El ataque A1 de la ronda 7 con H1 — **NO se reabre.** DEMOSTRADO (mecanismo) + VERIFICADO (medida)

A1 (`dag-poas-ancla-de-finalidad-auditoria.md:193-211`) construye un **punto de divergencia** con
`slot` alto por debajo de la posición del inyector y hace que dos honestos lean inyectores
distintos. Lo que lo cerró fue R-FIN-1a, no la forma del ancla.

La pregunta del encargo es: **¿puede el atacante fabricar bloques con `slot = T_j` a voluntad?**
No, y por tres razones que se apilan:

1. **El `slot` es el índice del PoT, no un sello elegible** (R-FIN-13, `dag-poas-ancla-de-orden.md:233-235`).
   Bajo R-FIN-14 (`:236-249`) el reto de cada slot sale de una **cadena AES secuencial**, y un bloque
   con `slot = s` necesita la prueba de espacio que verifica bajo `reto(f, s)`: ganar la lotería de
   ese slot. No se elige, se gana.
2. **En el instrumento eso es literal:** el `slot` de un bloque es `floor(t_creación)` y
   `t_creación` lo fija el **calendario de Poisson** del `Mundo` (`r8c_sim.py:44-57`), que es común a
   todas las estrategias («números aleatorios comunes»). La estrategia decide **si** y **cuándo se
   publica**, nunca **cuándo se creó**. Se mide como invariante (§C.medido, `viol. slot`).
3. **Por Prop. 1, H1 no cambia el bloque elegido.** Una regla que devuelve exactamente el mismo
   bloque que la vigente no puede reabrir un ataque que la vigente cierra. La medida de dos vistas
   (§C.4) lo confirma columna a columna.

Lo único que H1 le añadiría al atacante si Prop. 1 fuese falsa sería **empujar `s*` hacia adelante**
reteniendo a los ocupantes del slot `T_j`. Es **unidireccional**: puede quitar ocupantes de un slot,
nunca ponerlos, porque poner uno exige ganar la lotería de ese slot.

## C.2 · El «contador de saltos» de D9-c con H1 — **NO se reabre.** DEMOSTRADO

D9-c mató el ancla por posición porque `pos(B) = pos(sp(B)) + 1` es un **contador**: GHOSTDAG elige
la cadena por `blue_work`, que **no ve saltos**, así que añadir o quitar un salto por debajo de `c·j`
desplaza todo lo que viene después **gratis** (`dag-poas-ancla-de-orden-auditoria-3.md:34-46`).

H1 **no introduce ningún contador**: lee `slot`, que es el índice del PoT. La magnitud nueva que
introduce, `s*` = «el menor slot ocupado ≥ `T_j`», es un **mínimo sobre un conjunto de índices de
PoT**, no una suma de incrementos: para moverla hacia atrás el atacante necesitaría un bloque de un
slot que no ganó. Es la lección de D9-f, intacta: *el inyector se lee de una magnitud que el atacante
no puede fabricar a coste cero.*

## C.3 · El Lema A4-slot con el desempate H2 — **REFUTADO tal como está enunciado**, y reparable. DEMOSTRADO

El Lema A4-slot (D9-f, `r8f_b3_prop7.py:20-33`) dice: *si el ancla cambia entre dos vistas, las dos
cadenas difieren en una posición `p ≤ idx(ancla)`*. Su prueba es una sola frase: **el ancla es «el
primer índice con la propiedad», y eso lo determina el prefijo `0..idx` y nada más.**

Con H2 el ancla **deja de ser el primer índice**. Contraejemplo (construcción, no hace falta
simulador):

> Sean dos vistas cuyas cadenas coinciden en `0..q+1`, con `slot(Chn[q]) = slot(Chn[q+1]) = s* ≥ T_j`
> (empates de slot que R-FIN-1a no estricta admite — D9-f B0 midió que son el 23,7-29,3 % de las
> aristas de cadena a `τ = 1 s` bajo ataque). Sea `Chn[q+2]` con `slot = s*` también, presente en la
> vista 2 y no en la 1 (la vista 1 termina en `q+1`, o su `Chn[q+2]` tiene otro slot).
> Si `sd(Chn[q+2]) < sd(Chn[q]) < sd(Chn[q+1])`, el ancla de la vista 1 es `Chn[q]` y la de la vista
> 2 es `Chn[q+2]`: **el ancla cambia con `p = q+2 > idx(ancla₁) = q`.** El lema falla.

**Reparación (DEMOSTRADO).** El enunciado correcto para H1+H2 es:

> **Lema A4-slot-sd.** Si el ancla cambia, las dos cadenas difieren en `p ≤ u + 1`, donde `u` es el
> índice del **último** candidato del tramo de slot `s*`.
>
> *Prueba.* El conjunto de candidatos `C'` es, por (F1), el tramo contiguo `[q, u]` de la cadena, y
> `u+1` es el primer índice con `slot > s*` (o el final de la cadena). Si las dos cadenas coinciden
> en `0..u+1`, coinciden en el tramo entero y en su terminador, luego `C'₁ = C'₂` y el mínimo de `sd`
> sobre el mismo conjunto es el mismo bloque. Contrapositivo. ∎

**Coste de la reparación.** El Lema A2 de D9-c reduce «la cadena cambia en `p`» a una **inversión de
pareja** de la Def. 2 y de ahí a la Prop. 7; funciona igual con `p ≤ u+1` que con `p ≤ q`. Lo que
cambia es la **profundidad** a la que hay que invocarlo: `u + 1 − q` posiciones más. Con `τ = 1 s`,
`λ = 1` y R-FIN-1a no estricta, ese tramo mide en media `λ·τ = 1` bloque y su cola es corta (se mide:
`cand_multi_max`). No es un agujero, es una hipótesis extra que hay que escribir. **Para H2 en su
forma amplia** (mínimo de `sd` sobre TODA la ventana `slot ≥ T_j`) la reparación análoga exige
`p ≤` el índice del último bloque con `slot < T_j + S_max`, es decir **hasta 151 posiciones**: ahí sí
la reparación es cara, y es una razón para preferir la forma H1+H2 del informe (§6c) a la amplia.

## C.5 · H3 con el atacante como primer referenciador — **el informe se equivoca: SÍ puede adelantar la candidatura.** DEMOSTRADO (construcción) + VERIFICADO (medida)

El informe de los 52 problemas (§10) dice: *«el slot del primer referenciador lo fija el PoT, no el
atacante, salvo que el atacante sea el referenciador, y entonces solo puede **retrasar** su
candidatura, no adelantarla»*. Por Prop. 3, `publicado(X) = slot(sucesor de cadena de X)`. Entonces:

> **Maniobra del primer referenciador.** El atacante tiene `X` con `slot(X) = s` y un segundo bloque
> propio `Y` con `slot(Y) = s + d`, `d < S_ancla`. Cuelga `Y` de `X` y **retiene los dos** hasta
> `T_pub = s + R` con `R ≫ S_ancla`. Al publicarlos (la clausura de 9c los publica juntos: publicar
> `Y` publica `X`), si `Y` entra en la cadena seleccionada, el sucesor de cadena de `X` es `Y` y
> **`publicado(X) = s + d < s + S_ancla`**: `X` pasa el filtro de H3 aunque estuvo retenido `R`
> segundos.

El precio es **un bloque más**, no un bloque distinto: el atacante no fabrica un `slot`, usa uno que
ya ganó. Con `α·λ = 0,25 bloques/s` tiene ~11 candidatos a `Y` dentro de los 45 s siguientes a `X`.
Lo que la maniobra necesita de verdad es que `Y` **acabe en la cadena seleccionada**, y eso sí lo
limita el consenso: es la misma condición que ya limita a `X`. La medida (§C.medido) separa las dos
cosas con el contador `falsos` = anclas de H3 cuya **retención real** (`llega[X] − t_X`) fue
`≥ S_ancla`, y `falsos con sucesor del atacante`.

**Lo que esto significa para el diseño.** H3 **no mide la retención**: mide el hueco al sucesor. Es
una magnitud que el atacante fabrica con un bloque propio — el patrón exacto que mató al ancla por
posición (D9-c) y al ancla por `blue_score` (D9-f). La cota `m ≤ 46` que el informe le atribuye es
una cota sobre la magnitud equivocada.

---

# D · Censura al granjero honesto lento bajo H3 — la parte argumental

**Ser ancla no paga. DEMOSTRADO por lectura de regla.** R-FIN-8′
(`research/dag-poas-ancla-de-orden.md:314-325`) enumera quién cobra: *«Cobran los azules y los
`rojo_k`; un `rojo_U3` no cobra nada»*, y *«se aplica la coinbase propia del bloque cobrador, sujeta
a `C-EMIT-03` con su propio `H`»*. **El ancla no aparece.** R-FIN-13′ (`:228-231`) cierra el
invariante por el otro lado: el retarget cuenta *«exactamente los bloques que cobran por R-FIN-8′»*.
Y R-FIN-2 (`:196-198`) solo usa el ancla para derivar `entropía_j` y `t_j`. Luego un bloque que deja
de poder ser ancla **no pierde ni un satoshi de coinbase, ni deja de contar para el retarget, ni
pierde sus comisiones**. La «censura» de H3 es censura de un **honor sin recompensa**.

**Lo que sí puede costarle a un lento, y no es H3.** R-FIN-1a exige
`0 ≤ slot(B) − slot(sp(B)) ≤ S_max` **como validez** (`:184-189`). Un granjero cuya vista va
retrasada `E` segundos puede quedarse sin ningún padre válido y **no producir bloque**. Eso es el
punto 10 del informe de los 52 problemas, y H3 **no lo toca**: la validez sigue en `S_max = 150 s`.
La medida de §D separa las dos cosas: `h. perdidos` (censura real, de la validez) frente a
`ancla lenta perdida` (lo que quita H3).

**Predicción antes de medir:** `h. perdidos` debe ser 0 para todo `E ≤ 150 − (cola de gap)` y saltar
solo cuando `E` se acerca a `S_max`; y `ancla lenta perdida` debe crecer con `E`, sin efecto sobre
`lentos azules` (la fracción de bloques lentos que cobran).
