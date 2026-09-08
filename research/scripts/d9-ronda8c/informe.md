# D9-c · Ronda 8c — refutación del ancla en la cadena seleccionada

**Fecha:** 2026-09-08 · **Agente:** D9-c (Opus 5), fresco, sin deferencia al principal.
**Objetivo:** `dag-poas-solucion-ancla.md` + `dag-poas-ancla-de-orden.md` §2 (R-FIN-1..12).
**Directorio:** `research/scripts/d9-ronda8c/` (duradero, en el repo).

## 0 · Instrumento

`r8c_gd.py` — GHOSTDAG mínimo con correspondencia línea a línea al clon `rusty-kaspa @ c338d495`.
Validado por `r8c_test_gd.py` (6 pruebas, todas pasan):

```
t1 cadena pura OK
t2 tope k+1 en mergeset_blues OK (k=2,3,5,25)
t3 blue_work estrictamente creciente sobre el past: 0 violaciones en 121 bloques
t4 orden topologico, 66 bloques, cadena de 20: el bloque va tras su mergeset OK
t5 cadena seleccionada subset de azules OK
t6 R-FIN-12: 13 padres -> TooManyParents OK
```

**VERIFICADO (código+paper) · La fórmula del orden del principal es correcta.**
Algoritmo 1 del paper (`phantom-ghostdag.txt` L361-375):
`order(G) = order(past(Bmax)) ++ [Bmax] ++ anticone(Bmax)`. Desenrollando una vez,
`order(past(Bmax)) = order(past(sp)) ++ [sp] ++ mergeset(Bmax)`, luego
`… , C_{i-1}, mergeset(C_i), C_i, …`. Kaspa hace lo mismo:
`consensus_ordered_mergeset = once(selected_parent).chain(ascending mergeset)`
(`model/stores/ghostdag.rs:86-91`), concatenado a lo largo de la cadena. **El bloque va después de
su mergeset.** Mi `total_order()` lo reproduce y `t4` lo comprueba.

**LEMA propio, DEMOSTRADO y comprobado (t3): `B ∈ past(C) ⇒ blue_work(B) < blue_work(C)`.**
Prueba: `blue_work(C) = blue_work(sp(C)) + Σ_{mergeset_blues(C)} w`, y `mergeset_blues` **siempre
contiene a `sp(C)`** (`ghostdag.rs:115-120`, `new_with_selected_parent` empuja el sp), luego
`bw(C) > bw(sp(C)) ≥ bw(p)` para todo padre `p` (`find_selected_parent` es el máximo). Inducción
sobre el past. Lo uso varias veces abajo.

---

## A3 · U3′-filtro — **REFUTADO** (contraejemplo determinista y ejecutable)

Script: `r8c_a3_filtro.py` (`python3 r8c_a3_filtro.py 30`). `k=30`, `max_block_parents=15`,
`mergeset_size_limit=180`, U2 activa.

### A3(a) · ¿Es función de `past(B)` y nada más? **Sí — y ese es justamente el fallo**

El texto de R-FIN-11 dice: *«solo es candidata a azul la que no tenga su identidad ya azul en
`past(sp)`»*. Es función de `past(B)` (R-FIN-4 se cumple), pero **la condición no cubre el caso que
el atacante controla**: si ninguna copia tiene su identidad azul en `past(sp)`, **el filtro no
dispara sobre ninguna** y todas entran en el voraz.

Basta con publicar las copias en el **anticono del padre seleccionado**. Es gratis: el atacante
elige de qué bloque cuelgan.

```
(1) Un solo billete, copias en el ANTICONO del padre seleccionado. k=30, mp=15
  u3_mode   original  copias | en mergeset  AZULES(copia)  rojas  invalidas U2
      off   RETENIDO      40 |          14             14      0             0
     post   RETENIDO      40 |          14              1     13             0
   filter   RETENIDO      40 |          14             14      0             0   <-- IDÉNTICO a 'off'
  dynamic   RETENIDO      40 |          14              1     13             0
      off  publicado      40 |          14             14      0             0
   filter  publicado      40 |          14             14      0             0   <-- ni U2 ni el filtro
```

**`filter` es indistinguible de GHOSTDAG sin ninguna regla de unicidad.** Y la fila *publicado*
enseña que **U2 tampoco cubre esto**: U2 solo mira el `past`, y las copias cuelgan del mismo bloque
que el original, no de él.

**Un billete produce `max_block_parents − 1` bloques azules** en el coloreado de un solo bloque:
**14** a `k=30`, **11** a `k=25` (verificado con `python3 r8c_a3_filtro.py 25`). El barrido satura
exactamente en `mp−1`, que es el tope de padres, no un artefacto.

> **La afirmación de `dag-poas-solucion-ancla.md` §1.3 —«con U3′-filtro cero copias son azules en
> ninguna vista»— es FALSA.** Su medición (0/20) midió un escenario en el que el original ya estaba
> azul en `past(sp)`; es el único caso que la regla cubre, y es el que el atacante evita.

### A3(b) · El ataque de PRESUPUESTO de D9-a **sigue vivo**

`r8c_a3b_presupuesto.py`. Portadores del atacante que transportan copias hasta el mergeset de un
bloque honesto `M` cuyo `sp` es una punta honesta profunda (past sin copias):

```
  u3_mode  portad.  copias | |mergeset| azules az.COPIAS hon.en ms az.hon ROJOS hon
      off        0       0 |          4      4         0         4      4          0   (referencia)
   filter        0       0 |          4      4         0         4      4          0
   filter        2      28 |         34     13        11         4      1          3
   filter        6      84 |         94     13        11         4      1          3
   filter       10     140 |        154     13        11         4      1          3
  dynamic        2      28 |         34      7         1         4      4          0
  dynamic        6      84 |         94     11         1         4      4          0

Barrido de la profundidad `retro` a la que cuelgan las copias, 10 portadores:
 retro |  filter az.cop  filter ROJOS hon |  dynamic az.cop  dynamic ROJOS hon
     1 |             29                 3 |               1                  0
     2 |             28                 3 |               1                  0
     4 |             26                 3 |               1                  0
     8 |             22                 3 |               1                  0
    16 |             14                 3 |               1                  0
```

**De 4 puntas honestas que serían azules, 3 quedan ROJAS**, y **un solo billete pone hasta 29
bloques azules**. Es la refutación de D9-a íntegra: R-FIN-11 no la cierra, solo cambia de sitio la
condición. La hipótesis «1 billete = 1 bloque» del Lema 9 (paper L1135) sigue rota.

### A3(c) · La partición y la frontera

Dos copias en anticono mutuo cuyos `sp` no tienen ninguna azul: **ambas son azules en la misma
vista, no hace falta que sean vistas distintas** (fila `filter`, 14 azules a la vez). La pregunta
de la ronda 1 se queda corta: no es un desacuerdo entre vistas, es un acuerdo **en una sola vista**
sobre que un billete vale 14 bloques.

### La reparación que sí cierra: **U3″ dinámica**

`u3_mode='dynamic'`: candidata a azul si su identidad no es azul en `past(sp)` **ni ha sido ya
coloreada de azul en este mismo mergeset**. Sigue siendo función de `past(B)` (el orden del
mergeset es determinista: `sort_blocks` por `(blue_work, desempate)`), y en las tres tablas deja
**1 azul por identidad** y **0 honestos rojos de más**. **PLAUSIBLE**, no demostrada: no he probado
que no reabra otra cosa.

---

## A5 · R-FIN-12 — **el griefing NO existe, pero la regla está adoptada a medias**

**VERIFICADO en el clon.** Un nodo honesto de Kaspa **nunca** produce un bloque `MergeSetTooBig`:
`pick_virtual_parents` (`consensus/src/pipeline/virtual_processor/processor.rs:1092-1118`) lleva un
presupuesto explícito y llama a `mergeset_increase(&virtual_parents, candidate, limit − size)`
(`:1121-1140`); si el candidato no cabe lo **rechaza y lo sustituye por un ancestro suyo**
(`MergesetIncreaseResult::Rejected { new_candidate }`, `:1105-1114`), y corta el bucle en
`mergeset_size >= mergeset_size_limit || virtual_parents.len() >= max_block_parents` (`:1098`).

> **El escenario «170 bloques baratos y el siguiente honesto que los fusione es inválido» NO ocurre**
> — siempre que el nodo implemente `pick_virtual_parents`. **REFUTADA la hipótesis de griefing.**

Y los candidatos van **en orden descendente de `blue_work`** (`:987`, *«parent candidates ordered in
descending blue work order»*), así que el presupuesto se gasta **primero en las puntas honestas**,
que son las caras. Las puntas baratas del atacante son las últimas. `max_block_parents = 15` frente
a `λΔ ≈ 4` puntas honestas deja holgura de 11.

**LAGUNA, y es de la propuesta, no de Kaspa.** R-FIN-12 adopta **los dos límites** y **no** el
algoritmo que los hace inocuos. Un `zx-node` que solo copie los números y elija padres «todas las
puntas» sí fabricará bloques inválidos. `pick_virtual_parents` —presupuesto, sustitución por
ancestro, orden descendente de `blue_work`, y `remove_bounded_merge_breaking_parents`— **tiene que
entrar en la regla**, no en una nota de implementación.

---

## A2 · ¿Cubre la Prop. 7 la cadena seleccionada? — **DEMOSTRADO que sí, pero el argumento del principal es incorrecto**

### El argumento del principal no vale

`dag-poas-solucion-ancla.md` §0: *«si la cadena cambia a profundidad `d`, el orden cambia a
profundidad ≤ `d` … contrapositivo: orden estable ⇒ cadena estable»*.

**El paso falla porque «el orden es estable» no es lo que dice la Prop. 7.** Literal
(`phantom-ghostdag.txt` L1053-1056):

> *«the probability that the ordering of **two blocks published before time t** will change after
> time `t + r` is `O(e^{−cr})`»*

Es un enunciado **por parejas**, no sobre la secuencia. Una secuencia puede reescribirse entera
**sin invertir ninguna pareja vieja**: basta insertar bloques nuevos en medio. Eso es exactamente lo
que hacen las copias contra el **índice** (D9-b), y por eso el índice necesitaba una cota de la
unión que D9-a dejó como LAGUNA (a). «El orden cambia a profundidad ≤ d» **no implica** que se
invierta ninguna pareja publicada antes de `t`.

### La demostración correcta — LEMA A2

Sea `Chn` la cadena seleccionada del virtual honesto en `t+r` y `Chn′` la de un `s > t+r`. Si
difieren, sea `p` la **menor** posición en que difieren, `W = Chn[p]`, `W′ = Chn′[p]`,
`D = Chn[p−1] = Chn′[p−1]`.

1. **`sp(W) = sp(W′) = D`.** Por definición de cadena seleccionada (`chain[i−1] = sp(chain[i])`) y
   minimalidad de `p`.
2. **`W` y `W′` están en anticono mutuo.** Si `W ∈ past(W′)`: como `W ∈ future(D)` y `W ∈ past(W′)`,
   entonces `W ∈ mergeset(W′) = past(W′) \ (past(D) ∪ {D})`; luego `W′` tiene un padre `Q` con
   `W ≤ Q`, y por el **Lema de monotonía** `bw(Q) ≥ bw(W) > bw(D)`. Pero `find_selected_parent` es
   el **máximo** (`protocol.rs:99-106`), así que `sp(W′) ≠ D`. Contradicción. Simétrico al revés.
3. **`W ≺ W′` en `t+r` y `W′ ≺ W` en `s`.** En `t+r`, `W` es bloque de cadena en la posición `p` y
   `W′ ∈ anticone(W)`; `W′ ∉ past(D)` (porque `sp(W′) = D`), luego `W′` solo puede aparecer en el
   mergeset de un bloque de cadena de posición `> p`, es decir **después** de `W` — o no estar aún
   en `G`, y entonces la Def. 2 lo pone después igual (*«we use the same notation `B ≺ C` when
   `B ∈ G` but `C ∉ G`»*, L512-513). En `s`, simétrico.

Por tanto

```
Pr[ la cadena cambia en una posición ≤ p después de t+r ]  ≤  Risk_u(W, t, r)  =  O(e^{−cr})
```

**y esta reducción es MÁS LIMPIA que la del índice**: el evento entra entero dentro del `∃C` que la
Def. 2 ya tiene **dentro** de la probabilidad, así que **no hace falta ninguna cota de la unión** —
la LAGUNA (a) de D9-a desaparece con el ancla de cadena. Ese es el argumento que la propuesta
debería escribir, no el suyo.

**Comprobado empíricamente** (`r8c_a2_prop7.py`, 270 cambios de cadena reales sobre α ∈ {0; 0,10;
0,25; 0,40}, 8 semillas cada uno, profundidades 1…103):

```
   (i)   sp(W) = sp(W') = Chn[p-1] .............. 270/270
   (ii)  W y W' en anticono mutuo ............... 270/270
   (iii) W<W' antes y W'<W despues (inversion) .. 270/270
```

### Lo que el Lema A2 **no** salva

- **La Prop. 7 es asintótica en `r`.** No dice nada en el **frontera**, que es donde vive el
  *steering* (línea A1). Que el ancla se estabilice a `F = 3,2 h` no impide que el atacante
  **elija** su valor mientras se está fijando.
- La Prop. 7 se demuestra vía Prop. 8 + Lemas 9 y 10, y el Lema 9 supone **1 billete = 1 bloque**
  (L1135). **A3 rompe esa hipótesis**, así que la constante `c` de la Prop. 7 no está establecida
  para ZEROX bajo R-FIN-11 tal como está escrita.
- Sigue en pie la objeción (c) de D9-a: `Risk` es el **máximo sobre honestos** y la Def. 2 fija
  `Risk_u = 1` cuando `B ∉ G^u_t`; un desacuerdo de flujo (R-FIN-5/R-FIN-7) da `Risk = 1`
  permanente. **No lo he vuelto a auditar: LAGUNA heredada.**
- El paper dice (L1089-1091) que *«the blue score of the virtual node actually decreases»*. Con el
  Lema A2 eso deja de ser una objeción al ancla: el decremento es del **virtual** (la punta), y el
  Lema A2 acota los cambios **a cada profundidad `p`** por un evento de la Def. 2. **Etiqueta:
  la objeción de la meta-auditoría queda RESUELTA, no por su argumento sino por el Lema A2.**

---

## A4 · Retrolectura de U2 — **REFUTADO el argumento del principal; la cota existe pero por otra regla, que la propuesta NO ha adoptado**

**El argumento del principal no cierra.** *«Como la identidad incluye `slot`, dos copias comparten
slot y la búsqueda está acotada.»* Compartir el slot no acota nada por sí solo: para validar `B` hay
que recorrer `past(B)` buscando `ident(B)`, y **ninguna de R-FIN-1..12 acota a qué profundidad del
DAG puede estar un bloque con slot `s`.**

- **R-FIN-1a solo pide `slot(sp(B)) < slot(B)`, estricta.** No pone **cota superior al salto**. Un
  bloque `X` con slot `s` puede colgar de un bloque de cadena con slot `s − 10⁶`: R-FIN-1a se
  cumple, y R-FIN-4 solo exige que la justificación de PoT cubra el hueco — que el atacante puede
  haber precomputado.
- **HALLAZGO EXTRA, no pedido: eso es un DoS.** `CLAUDE.md` dice que la verificación del PoT de
  Autonomys **no es sucinta** (recomputa una cadena AES). Un bloque con un salto de slot de 10⁶
  obliga a **todos** los nodos a recomputar 10⁶ slots de AES para decidir si es válido — y basta
  con que sea *sintácticamente* plausible. **`R-FIN-1a` necesita `slot(B) − slot(sp(B)) ≤ S_max`,
  no solo `>0`.** Sin eso, `C-NET-03`/`C-NET-04` no tienen nada que calibrar.

**Lo que sí acota la retrolectura, VERIFICADO en el clon:** `check_bounded_merge_depth`
(`post_pow_validation.rs:79-96`) exige que todo **rojo** del mergeset sea ancestro del
`merge_depth_root` o de un *kosherizing blue*, o el bloque es `ViolatingBoundedMergeDepth`. Con
`MERGE_DEPTH_DURATION = 3600 s` (`config/constants.rs:81`) y `merge_depth_bound() = BPS·3600`
(`bps.rs:88-90`), **ningún bloque puede fusionar por debajo de una hora de profundidad**. Eso, más
un límite de finalidad, es lo que hace finita la ventana de U2.

| Constante de Kaspa | Valor | ¿La ha adoptado ZEROX? |
|---|---|---|
| `merge_depth_bound = BPS·3600` | 1 h | **NO** |
| `finality_depth = BPS·43 200` | 12 h | parcialmente: `F = 3,2 h` es límite de reorg |
| `pruning_depth ≥ finality + 2·merge_depth + 4·mergeset_limit·k + …` (`bps.rs:94-105`) | ≥ 30 h | **NO** |

**Cota, con las reglas de Kaspa adoptadas:** la ventana de U2 es
`merge_depth_bound · λ_real = 3600 · 1,364 ≈ 4 900 bloques`; con `F = 3,2 h` como límite de reorg,
`11 520 · 1,364 ≈ 15 700 bloques`. **Es finita y cabe en un índice `ident → bloque`, pero es
estado nuevo que la propuesta no menciona.**

**¿Choca con la poda?** **No**, si se adopta `pruning_depth` de Kaspa: `pruning_depth` está por
construcción **por encima** de `finality + 2·merge_depth`, así que la ventana de U2 nunca alcanza
bloques podados. **Sin adoptarla, sí choca**: un nodo podado no puede decidir U2 y no puede validar.

**Etiqueta: LAGUNA** — la cota existe, pero descansa en **tres reglas de Kaspa que R-FIN-12 no
adoptó**. R-FIN-12 se quedó a medias: cogió los dos límites baratos y dejó fuera los tres que
sostienen el argumento.

---

## A1 · ¿Es inmune la posición de cadena? — **REFUTADO**

Scripts: `r8c_sim.py` (simulador de eventos), `r8c_a1_menu.py` (menú), `r8c_a1b_mecanismo.py`
(mecanismo), `r8c_a1c_robustez.py` (autocrítica), `r8c_steering.py` (traducción a `g`).

**Validación del instrumento antes de usarlo.** A `α = 0` mi simulador da
`λ_chain = 0,1988 /s`, frente al **0,2008 /s** que la propuesta usa. Reproduce la constante del
diseño, así que no estoy midiendo otra cosa.

### A1.1 · El argumento de inmunidad es un *non sequitur*

`dag-poas-solucion-ancla.md` §1.3: *«cadena ⊆ azules, y las copias son rojas ⇒ una copia no puede
estar en la cadena, a ninguna profundidad. **No hay mecanismo por el que la desplace.**»*

**El mecanismo existe y no pasa por meter nada en la cadena.** `pos(B) = pos(sp(B)) + 1` cuenta
**saltos**. GHOSTDAG elige la cadena por **`blue_work`**, que es **agnóstico al número de saltos**:
un bloque que fusiona 20 azules gana 20 de `blue_work` con **un** salto. Añadir o quitar **un solo
salto** por debajo de la posición objetivo **desplaza todo lo que hay a partir de ahí**. No hace
falta que el bloque insertado sea del atacante, ni que ninguna copia sea azul.

Medido (`r8c_a1b_mecanismo.py`, posición 30, 12 semillas): el desplazamiento del ocupante de
referencia recorre

```
  alpha   menu   entropías del ATACANTE  honestas   desplazamiento del ocupante
   0.00   1.00                     0.00      1.00   [0]
   0.10   7.33                     1.58      5.75   [-6 … 0]
   0.25   9.50                     5.25      4.25   [-14 … 0]
   0.33  10.50                     5.67      4.83   [-16 … 0]
```

**La mayor parte del menú a `α = 0,10` son bloques HONESTOS** (5,75 de 7,33): el atacante no
necesita ocupar la posición, le basta con mover **cuál** honesto cae en ella.

### A1.2 · La `m` medida — y no es 1,3-2,0

Menú contado **por estructura**: cada bloque lleva un `seed` (la entropía que aportaría como
inyector, R-FIN-2) **fijado en el instante de creación** y jamás recalculado. Renombrar bloques no
puede cambiarlo — el artefacto que el principal se comió (`solución` §5.3) es imposible aquí.
Números aleatorios comunes: el calendario de creaciones es idéntico entre estrategias; **solo
cambia lo que el atacante decide.**

Tres niveles de coste, acumulativos (posición 30, 12 semillas, `k=30`, `mp=15`, U3″ dinámica):

| `α` | **m GRATIS** (publica todo al instante, solo elige padres) | m +retraso | m +retención |
|---:|---:|---:|---:|
| 0,00 | **1,00** (0/12 con m>1) | 1,00 | 1,00 |
| 0,10 | **4,50** (máx 6) | 5,92 | 7,33 |
| 0,25 | **5,00** (máx 6) | 8,25 | 9,50 |
| 0,33 | **5,17** (máx 7) | 9,00 | 10,50 |
| 0,40 | **5,25** (máx 8) | 9,17 | 10,67 |

**Criterio α: PASA.** `α = 0` da exactamente 1,00 en 12/12 semillas; el resultado cambia con `α` en
las tres columnas.

> **El «menú real 1,3-2,0» de la solución §1.2 no se sostiene.** La `m` **gratis** —el atacante no
> retiene nada, no pierde ni un bloque, solo **elige padres**— es **4,5-5,25**. Con retención llega
> a 9-11.

**Mi propia limitación, dicha:** enumero una familia **dirigida** de ~230 estrategias, no el espacio
completo (es exponencial). Por tanto **`m ≥ 4,5` es una COTA INFERIOR**, no la `m` verdadera.
`r8c_a1c_robustez.py` mide la curva de saturación.

### A1.3 · Y hay un regalo previo: el atacante ya ocupa la mitad de las posiciones sin atacar

`r8c_a1b_mecanismo.py` (1). Con el adversario del paper —*«suffers no internal delays or delays
from or to honest nodes»* (L1024-1027)— sus bloques cuelgan siempre de la punta **más fresca** y
ganan la carrera de `sp`:

| `α` | `λ_chain` | % de posiciones de cadena del atacante |
|---:|---:|---:|
| 0,00 | 0,1988 | 0,0 % |
| 0,10 | 0,3181 | **30,3 %** |
| 0,25 | 0,4838 | **49,2 %** |
| 0,33 | 0,5631 | 53,6 % |
| 0,40 | 0,6275 | 58,1 % |

**A `α = 0,25` el ancla cae en un bloque del atacante el 49 % de las veces, jugando limpio.**

### A1.4 · Consecuencia que la propuesta no vio: **`λ_chain` no es una constante, y `c` está en posiciones**

R-FIN-1 + solución §3: *«`c` vuelve a contarse en posiciones de cadena: `c = I·λ_chain = 500`»*. El
retarget fija **`λ`** (bloques/s), **no `λ_chain`**. Luego la duración real de la época es
`I′ = c / λ_chain(α)`, y el atacante la **acorta**:

| `α` | `λ_chain` | `I′` real | `I` nominal | `g` con la m GRATIS | `W/κ = 1+I′/F` |
|---:|---:|---:|---:|---:|---:|
| 0,10 | 0,3181 | **1 572 s** | 2 490 s | **8,74 %** | 1,136 |
| 0,25 | 0,4838 | **1 033 s** | 2 490 s | **7,24 %** | 1,090 |
| 0,33 | 0,5631 | 888 s | 2 490 s | 6,90 % | 1,077 |
| 0,40 | 0,6275 | 797 s | 2 490 s | 6,66 % | 1,069 |

La época dura **2-3 veces menos** de lo derivado, y como `g ∝ 1/√I`, el steering sube en `√` de eso.
`W/κ` mejora (efecto colateral), pero es la mitad benigna de una pinza que se ha desequilibrado.

### A1.5 · El steering resultante

`r8c_steering.py`. `c_m = E[máx de m normales] − media`, calculado por integración numérica y
**contrastado con los valores publicados** (`dag-poas-voto-auditoria.md` L199):
`c_2 = 0,5642` (publicado 0,564), `c_4 = 1,0294` (publicado 1,029). ✔

`g = c_m/√(αλI)` con `I = 2 490 s` (el nominal, sin el efecto A1.4):

| `α` | `m = 1,3` (lo que publica la solución) | **m GRATIS (D9-c)** | m +retraso | m +retención |
|---:|---:|---:|---:|---:|
| 0,10 | 1,07 % | **6,95 %** | 7,98 % | 8,72 % |
| 0,25 | 0,68 % | **4,66 %** | 5,77 % | 6,06 % |
| 0,33 | 0,59 % | **4,12 %** | 5,18 % | 5,45 % |
| 0,40 | 0,54 % | **3,77 %** | 4,73 % | 4,98 % |

Y con `I′` real (A1.4), **`g` llega a 8,7 % a `α = 0,10`**. El peor caso está en `α` **baja**, porque
`g ∝ 1/√α`: un atacante pequeño paga poco por época y el premio relativo es mayor.

> **La tabla de la solución §3 —«Steering `g` con `m` medido: `m≈1,3-2,0` → 1,0-2,4 %»— es falsa.
> El número correcto está entre 3,8 % y 8,7 %, y el techo de 3,6 % que la ronda 8 usó para DERIVAR
> `I = 2 490 s` no se cumple con ninguna `α`.**

### A1.6 · Lo que costaría arreglarlo (primer orden, no exacto)

Para volver a `g ≤ 3,6 %` con la `m` gratis medida, y manteniendo `W/κ ≤ 1,22`:

| `α` | `I` necesaria | `c` en posiciones | `F` necesaria |
|---:|---:|---:|---:|
| 0,10 | 9 272 s (**2,58 h**) | ≥ 2 949 | **≥ 11,7 h** |
| 0,25 | 4 174 s (1,16 h) | ≥ 2 020 | ≥ 5,3 h |
| 0,40 | 2 727 s (0,76 h) | ≥ 1 711 | ≥ 3,4 h |

**`F = 3,2 h` no sobrevive.** Dimensionando por el peor `α` (0,10), hacen falta `I ≈ 2,6 h` y
`F ≈ 11,7 h` — es decir, **el límite de reorg pasa de 3,2 h a casi 12 h**. Es una cota de primer
orden calculada con la `m` medida en el escenario nominal: **cota, no realidad** (regla 5). Pero el
signo y el orden de magnitud no dependen de la aproximación.

---

## A1 · autocrítica de la medida — y **la explicación de por qué el principal midió 1,3-2,0**

### (a) ¿Depende `m` de la posición? No (`r8c_a1c_robustez.py`)

```
 alpha      P=15     P=25     P=35     P=45
  0.00      1.00     1.00     1.00     1.00
  0.10      6.38     6.75     7.25     6.75
  0.25     10.75     9.50     9.00     9.75
  0.40     10.00    10.12    10.12    10.62
```

### (b) ¿Es un artefacto de enumerar muchas estrategias? Satura

```
 alpha      n=10     n=25     n=50    n=100    n=200    n=400   (estrategias enumeradas)
  0.10      3.88     4.38     5.50     6.00     6.88     6.88
```

```
  0.25      4.38     4.62     5.38     8.25     9.38     9.38
  0.40      4.50     4.75     5.00     8.75     9.75    10.12
```

Satura entre 200 y 400. **Sigue siendo cota inferior**: una familia distinta podría encontrar más.

**Control de determinismo**: el mismo conjunto de estrategias barajado en 5 órdenes distintos da el
mismo menú (`[4,4,4,4,4]`, `[1,1,1,1,1]`, `[11,11,11,11,11]`, `[7,7,7,7,7]`). El DAG no depende del
orden de enumeración; el menú no es ruido.

**Con copias (U3′-filtro tal como está escrita), `α = 0,10`**: `m` gratis 4,67 (era 4,50), con
retención **8,92** (era 7,33), máximo 15. Las copias **suman** al menú porque compran `blue_work`
(§A3 (3)) y con él saltos de cadena. **Solo tengo la fila `α = 0,10`: el resto seguía corriendo al
cerrar el informe. LAGUNA.**

### (c) ¿Es realizable EN LÍNEA? Sí — y este es el número conservador (`r8c_a1e_reactivo.py`)

Atacante **reactivo**: solo usa bloques suyos creados **después** de que ya exista el candidato de
la posición `P`, y los publica al instante. Ve el candidato y decide si lo desplaza. Coste cero,
sin mirar al futuro:

```
 alpha  menu reactivo   max      >1   bloques disponibles
  0.00           1.00     1   0/12                    0.0
  0.10           2.08     3  10/12                    3.4
  0.25           2.92     4  11/12                    8.2
  0.33           2.50     4  10/12                   10.2
  0.40           2.17     4   9/12                   11.3
```

**Suelo firme: `m ≥ 2,1-2,9`, en 9-11 de cada 12 semillas.** Ya está por encima del techo del
principal.

### (d) EL CONTROL QUE LO EXPLICA TODO (`r8c_a1d_control.py`)

Repito la medida quitándole al atacante el privilegio del paper (*«suffers no internal delays or
delays from or to honest nodes»*, L1024-1027) y haciéndole sufrir el mismo `Δ = 4 s`:

| modelo | `α` | `λ_chain` | % cadena atac. | **m GRATIS** | m +retención |
|---|---:|---:|---:|---:|---:|
| **paper** (atacante sin retardo) | 0,10 | 0,3284 | 31,2 % | **4,12** | 6,88 |
| **paper** | 0,25 | 0,4933 | 49,8 % | **4,88** | 9,38 |
| **paper** | 0,40 | 0,6438 | 59,0 % | **5,00** | 10,25 |
| **CONTROL** (atacante con Δ) | 0,10 | 0,1986 | 12,6 % | **1,38** | 1,88 |
| **CONTROL** | 0,25 | 0,1986 | 27,8 % | **2,00** | 2,88 |
| **CONTROL** | 0,40 | 0,1986 | 41,7 % | **2,62** | 3,38 |

> **«Menú real 1,3-2,0» es exactamente lo que sale con un atacante RETARDADO.** El desacuerdo no es
> de medición: es de **modelo de adversario**. Y el diseño **no puede elegir**: `k = 25/30`, `δ`,
> `F`, `I`, el `3k` del Lema 10 y la Prop. 7 entera **se citan del paper**, y el paper los demuestra
> **contra el atacante sin retardo**. Dimensionar el *steering* contra uno más débil que aquel del
> que se toman los teoremas es incoherente. **Con el adversario cuyos teoremas invoca el diseño,
> `m` está entre 2,1 (reactivo, en línea) y 5,25 (gratis, ex post).**

### El steering, en las tres lecturas

```
 alpha |  m REACTIVO        g |  m GRATIS        g |  m +retencion        g
  0.10 |        2.08    3.72% |      4.50    6.95% |          7.33    8.72%
  0.25 |        2.92    3.30% |      5.00    4.66% |          9.50    6.06%
  0.33 |        2.50    2.46% |      5.17    4.12% |         10.50    5.45%
  0.40 |        2.17    1.94% |      5.25    3.77% |         10.67    4.98%
```

Con la `I′` real de A1.4 (época medida en posiciones de cadena, `λ_chain` inflada) el `g` gratis
llega a **8,74 % a `α = 0,10`**.

**El techo de 3,6 % con el que la ronda 8 DERIVÓ `I = 2 490 s` se supera en la lectura gratis para
todo `α ≤ 0,33`, y en la lectura reactiva —la más conservadora posible— para `α ≤ 0,25`.**
`I = 2 490 s` deja de estar derivada.

---

# VEREDICTO

> **NO. El ancla en la posición de la cadena seleccionada NO aguanta, y R-FIN-11 tampoco.**
> La cadena es inmune a que una copia *ocupe* una posición —eso es cierto—, pero el ancla no es un
> bloque: es un **contador de saltos**, y el número de saltos no es una magnitud protegida por
> GHOSTDAG. Menú medido **2,1-2,9 en línea y gratis**, **4,1-5,25 gratis ex post**, frente al
> **1,3-2,0** publicado; y U3′-filtro, tal como está escrita, **no filtra nada** en el caso que el
> atacante controla.

| Línea | Etiqueta | Qué queda |
|---|---|---|
| **A1** · ¿inmune la posición de cadena? | **REFUTADO** | El mecanismo no es la copia azul, es el **salto de cadena**. `m ≥ 2,1` (en línea, gratis) hasta 10,7 (con retención). `g` sube de 1,0-2,4 % a 3,3-8,7 %. **`I = 2 490 s` y `F = 3,2 h` dejan de estar derivadas** |
| **A2** · ¿cubre la Prop. 7 la cadena? | **DEMOSTRADO que sí — con otra prueba** | El argumento del principal («orden estable ⇒ cadena estable») no vale: la Prop. 7 es **por parejas**. El **Lema A2** de §A2 sí lo prueba, y **mejor**: sin cota de la unión. 270/270 comprobado |
| **A3** · U3′-filtro | **REFUTADO** | Contraejemplo determinista: copias en el **anticono del `sp`**. `filter` ≡ GHOSTDAG **sin ninguna regla**. Un billete = **14 azules** (`mp−1`), hasta **29** con portadores; 3 de 4 puntas honestas quedan rojas. El ataque de D9-a sigue vivo |
| **A4** · retrolectura de U2 | **LAGUNA** (y argumento REFUTADO) | «La identidad incluye el slot ⇒ acotado» no cierra. Lo que acota es `merge_depth_bound` + finalidad + `pruning_depth`, **tres reglas de Kaspa que R-FIN-12 no adoptó**. Ventana ≈ 4 900-15 700 bloques |
| **A5** · R-FIN-12 | **REFUTADA la hipótesis de griefing**; **LAGUNA** | Un nodo de Kaspa nunca emite `MergeSetTooBig`: `pick_virtual_parents` lleva presupuesto. Pero R-FIN-12 adoptó **los límites y no el algoritmo** |

**Lo que hay que cambiar, en orden de urgencia:**

1. **U3″ dinámica** en vez de U3′-filtro (§A3). Sin ella no hay «1 billete = 1 bloque» y el Lema 9
   no aplica — y entonces la constante `c` de la Prop. 7 no existe para ZEROX, y **A2 no sirve de
   nada** aunque su lema sea correcto.
2. **Cota superior al salto de slot** en R-FIN-1a (`slot(B) − slot(sp(B)) ≤ S_max`). Sin ella hay
   DoS de verificación de PoT y U2 no tiene ventana.
3. **Adoptar `pick_virtual_parents`, `merge_depth_bound` y `pruning_depth`** en R-FIN-12, no solo
   los dos números.
4. **Rederivar `I`, `c` y `F`** con la `m` del adversario del paper y con `λ_chain` bajo ataque
   (§A1.4, §A1.6). Primer orden: `I ≈ 2,6 h`, `c ≈ 3 000 posiciones`, **`F ≈ 11,7 h`**.
5. **Decidir el ancla en unidades de tiempo o de `blue_score`, no de saltos.** El `blue_score` de
   la cadena seleccionada (`blue_score(Chn[p])`) es el candidato obvio: no lo infla el atacante
   añadiendo saltos, porque cuenta azules, no hops. **No lo he auditado. Es una sugerencia, no un
   resultado.**

---

# Salida de `AUDITA_SCRIPTS.py`

```
$ python3 /home/katana/zeo/ZEROX/research/scripts/AUDITA_SCRIPTS.py \
          /home/katana/zeo/ZEROX/research/scripts/d9-ronda8c/
Scripts analizados: 10

======================================================================
Sospechas totales: 0
```

Hubo **una** marca antes de limpiarla, y la declaro: `[T3b] r8c_test_gd.py L113: ['d','d2'] =
MISMA expresión: DAG(k=25, u2=False, u3_mode='off')` — dos instancias distintas construidas con los
mismos argumentos en la prueba `t6`. Falso positivo, pero reescribí `t6` para que no lo pareciera
(y de paso para que use `MAX_PARENTS` del módulo en vez del 12 cableado, que ya no es el valor).

**Criterio α:** todas las simulaciones adversariales cambian de resultado con `α`, y a `α = 0` dan
el valor neutro:

| Medida | α = 0 | α = 0,10 | α = 0,25 | α = 0,40 |
|---|---:|---:|---:|---:|
| menú de la posición 30, gratis | **1,00** (0/12 con m>1) | 4,50 | 5,00 | 5,25 |
| menú reactivo en línea | **1,00** | 2,08 | 2,92 | 2,17 |
| `λ_chain` | **0,1988** | 0,3181 | 0,4838 | 0,6275 |
| % de cadena del atacante | **0,0 %** | 30,3 % | 49,2 % | 58,1 % |
| azules honestos perdidos (A3b) | **0** | — | 3 de 4 | — |

---

# Mis propios errores

1. **Mi primer contraejemplo de A3 era enrevesado y por eso salió mal.** Monté portadores en dos
   niveles y medí `az.COPIAS = 0` a `k=30` — y lo estuve a punto de leer como «el filtro funciona».
   No funcionaba: el `sp` del portador era **una copia**, que envenena su propia identidad. El
   contraejemplo bueno es de cinco líneas: `M = [Q] + copias`. **Casi firmo un DEMOSTRADO falso por
   una estructura mal elegida.**
2. **Mi simulador tenía un fallo de `mergeset`** que solo aparecía con padres que no son una
   anticadena (Kaspa nunca los tiene). Lo cazó la prueba `t4` con 30 duplicados en el orden. Lo
   arreglé haciendo la función igual a `past(B) \ (past(sp) ∪ {sp})` por definición.
3. **Empecé asumiendo que el ataque a la cadena sería con copias azules.** Lo era en parte (A3
   compra `blue_work`), pero el mecanismo principal —el **salto**— lo encontré después, y solo
   porque el desplazamiento medido no era 0. Si me hubiera quedado en «las copias son rojas» habría
   confirmado al principal.
4. **`t6` tenía el `12` cableado** de `k=25` y dejó de probar lo que decía cuando el coordinador
   cambió a `k=30`. Pasaba en verde midiendo otra cosa.

---

# LAGUNAS

1. **`pick_virtual_parents` real baraja** los candidatos más allá de `max_block_parents/2`
   (`processor.rs:1076-1090`, `shuffle(&mut rand::thread_rng())`). Mi simulador es determinista.
   Esa aleatoriedad **no es controlable por el atacante**, así que no puede *aumentar* `m`; podría
   *reducir* su capacidad de dirigir con precisión. **No lo he medido.** Dirección del sesgo:
   mi `m` puede ser optimista **a favor del atacante** en este punto concreto.
2. **`m` es una cota inferior** por familia dirigida (satura a 400 estrategias en mi familia, pero
   otra familia puede encontrar más). Y una cota **superior** en el sentido *ex post*: la lectura
   honesta es el intervalo `[2,1 reactivo, 5,25 gratis]`.
3. **No he auditado la Prop. 7 bajo U3″ dinámica.** A3 rompe R-FIN-11 tal como está; que la
   reparación no rompa otra cosa es **PLAUSIBLE, no demostrado**.
4. **No he tocado la objeción (c) de D9-a** —`Risk = 1` permanente por desacuerdo de flujo
   (R-FIN-5/R-FIN-7)—. Sigue abierta y **es anterior a todo lo mío**: si `Risk = 1`, la Prop. 7 no
   dice nada y el Lema A2 tampoco.
5. **`δ_ef` bajo U3′-filtro no lo he medido en simulación de eventos**, solo en el contraejemplo
   determinista (3 de 4 puntas honestas rojas en un mergeset). La comparación directa con el
   `δ = 0,2424 / 0,267` de la cota **no está hecha**.
6. **No he auditado el ancla alternativa** (`blue_score` de la cadena en vez de `pos`). La sugiero
   porque el `blue_score` no lo infla un salto, pero **no la he atacado**.
7. **`k = 30` llegó a mitad de trabajo.** A3, A5 y el simulador corren con `k=30`/`mp=15`; A3 está
   verificado además con `k=25`/`mp=12` y el resultado es el mismo con `mp−1` en vez de 14. A1 y A2
   corren solo con `k=30`. **No he rehecho A1 con `k=25`.**
