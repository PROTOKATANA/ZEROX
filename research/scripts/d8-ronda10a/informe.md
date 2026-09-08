# D8 — Ronda 10a: romper la **revelación retardada por VDF**, R-FIN-14 (h)

**Agente:** D8 (adversarial), Opus 5 · **Fecha:** 2026-09-08/09 · **Método:** `research/scripts/METODO-AGENTES.md`
**Directorio:** `research/scripts/d8-ronda10a/` (no se toca ningún otro fichero del repositorio).

**Objeto.** La opción (h) de R-FIN-14 (`research/dag-poas-ancla-de-orden.md:284-287`):
`entropía_j = VDF(chunk(I_j) ‖ salida(I_j), L·iter)`, revelada en `t_j = slot(I_j) + L`. El encargo la
presenta con la cota **«steering 0 salvo `ρ ≥ L/W_dec`» (80 con `L = 1 h`, 160 con `L = 2 h`)**.

> **TITULAR.** La cota del encargo es **correcta para los candidatos ajenos y ciega para el propio.**
> Con `L = 2 h`, `I = 851 s`, `W_dec = 45 s`:
>
> | Qué evalúa el atacante | `ρ` mínimo | fuente |
> |---|---:|---|
> | un candidato **ajeno** (steering completo, elegir entre `m`) | **160** | `L/W_dec` — el del encargo, **CONFIRMADO** |
> | **su propio** candidato (publicar o retener: `m = 2` con una rama conocida) | **8,99** | `(L+I)/(I+W_dec)` — **nuevo** |
> | lo mismo, con **rachas** de `n*−1` anclas propias seguidas | **cualquier `ρ > 1`**, a tasa `α^(n*−1)` | **nuevo, cerrado y medido** |
>
> La razón: el atacante **no espera a que le revelen `entropía_j`; la calcula él**, porque sus dos
> entradas (`chunk(I_j)`, `salida(f, slot(I_j))`) son públicas —y, si el ancla es un bloque suyo, las
> tiene antes de que el slot llegue—. (h) no le quita el conocimiento: le cobra `Lrev/ρ` segundos de
> reloj por candidato, **en paralelo con la cadena principal**. Esto **no es un hallazgo mío contra la
> ronda 9c: es lo que ya decía la ronda 7** (`dag-poas-ancla-de-finalidad.md:319-322`, «reduce el
> lookahead de `L + I(1−1/v)` a `(L+I)(1−1/v)`, **sin cambiar la cota con `v → ∞`**»). **9c §E.5 se
> contradice con la ronda 7 y la ronda 7 tiene razón**; mi simulador reproduce las dos formas
> cerradas de la ronda 7 con razón 1,000 (§B.1, control C2).
>
> **Aun así (h) compra mucho:** sin (h) el steering renace con **cualquier `ρ > 1`** tras un
> *bootstrap* de días; con (h) hace falta `ρ ≥ 9` sistemático, y por debajo la tasa cae como
> `α^(n*−1)`: a `ρ = 1,5` y `α = 0,40`, **1,6·10⁻² épocas al año**. El techo físico estimado del
> reloj AES es **1,5-2,5×** (`pot-aes-asic-chacha.md` §3).
>
> **Lo que decide si puede ser núcleo no es el reloj: es el coste, y el coste tiene forma cerrada.**
> `ρ* = (1 + L/I)·I/(I + W_dec)`: **la protección de (h) y su precio son literalmente el mismo
> número** (§C.5). A la calibración vigente (`I = 851 s`, `F = 2 h`) compra `ρ* = 9,24` y cobra
> **0,91 núcleos continuos por nodo** (frente a 0,096) más **`q+1` = 10** líneas de AES por
> timekeeper — y **un lado de partición sin esas 10 líneas queda muerto aunque conserve todo su
> espacio** (§B.4). Como el techo físico del reloj es 1,5-2,5×, **se está pagando 3,7× de más**: con
> `ρ_max = 2,5` basta `I = 4 725 s`, 0,147 núcleos y `q+1 = 3` líneas.
>
> **Veredicto (§D): sí puede ser núcleo, con cinco correcciones y `I` recalibrada.** La más grave:
> `entropía_j` **no se publica, se calcula** — cualquier regla condicionada a «si la revelación está
> disponible» hace `flujo` dependiente de la vista y parte el DAG entre honestos.

---

## Índice

| § | Punto del encargo | Veredicto en una línea |
|---|---|---|
| [A](#a--la-regla-operativa-completa-antes-de-atacarla) | la regla, escrita del todo | seis piezas (h.1-h.6); **retiro** la (h.3) de mi intento anterior: rompía R-FIN-5 |
| [B.1](#b1--el-reloj-rápido-y-la-cota-ρ--lw_dec--la-cota-es-correcta-y-es-incompleta) | reloj rápido y `ρ ≥ L/W_dec` | correcta para el candidato **ajeno** (160), ciega para el **propio** (**8,99**) |
| [B.2](#b2--dos-de-verificación--refutado-como-ataque-el-coste-que-queda-es-el-honesto) | DoS de verificación | **REFUTADO**; 16,24× medido, 32,4× en orden aleatorio |
| [B.3](#b3--vivacidad-del-timekeeper--el-coste-de-cpu-no-es-el-problema-la-barrera-de-entrada-sí) | vivacidad del timekeeper | **25 líneas de AES cuestan 1,7 %**; el problema es la barrera ×(q+1) |
| [B.4](#b4--partición-y-s_max--sí-h-introduce-un-vector-nuevo-y-es-de-hardware) | partición y `S_max` | **vector nuevo**: lado con < `q+1` núcleos muere con todo su espacio |
| [B.5](#b5--carrera-de-bloques--demostrado-que-h-no-cambia-la-frontera-de-flujo-único) | carrera de bloques | **DEMOSTRADO** que (h) no la toca |
| [B.6](#b6--el-adelanto-l1--1ρ--refutado-como-daño-a-la-frontera-la-laguna-ráfagas-queda-cerrada) | el adelanto `L(1−1/ρ)` | **REFUTADO**; LAGUNA «ráfagas» cerrada en **0,46 puntos** |
| [C](#c--coste-de-h-con-número) | coste con número | `ρ*` y el coste **son el mismo número**; se paga 3,7× de más |
| [D](#d--veredicto--puede-h-ser-núcleo-del-diseño) | veredicto | **sí, con cinco correcciones y `I` recalibrada** |

---



## A · La regla operativa completa, antes de atacarla

9c dejó (h) en dos líneas de nota. Sin las cuatro decisiones que siguen no hay nada que atacar, así que las
fijo yo, en la lectura **más favorable al diseño** que sea consistente (atacar la versión fuerte, no un
hombre de paja). **Etiqueta del texto entero: PLAUSIBLE** — es una regla candidata mía, no verificada en red.

### A.0 · Notación

`I_j` = ancla de la época `j` (R-FIN-1) · `T_j = j·I` · `S_max = 150 s` · `W_dec ≤ 45 s` (9c §C, medida) ·
`L` = retardo de revelación en slots (= `F` en el diseño vigente) · `iter` = `slot_iterations` vigente
(R-FIN-9) · `ρ = reloj_AES(atacante) / reloj_AES(timekeeper)`.

### A.1 · Quién calcula el VDF de revelación y cuándo empieza — **nadie lo «publica»: se calcula**

> **(h.1)** Para cada época `j`, `entropía_j := blake3( AES128_chain^{Lrev·iter}( blake3(chunk(I_j) ‖
> salida(f, slot(I_j)))[0..16) ) )`, con `I_j` el ancla de R-FIN-1 y `Lrev` el **largo de la revelación**
> en slots, constante de consenso con `Lrev < L`. La inyección se aplica en `t_j = slot(I_j) + L`
> (R-FIN-2, sin cambios). **`entropía_j` es una función de `past(B)` y de nada más**, exactamente como
> `I_j`: no es un mensaje que haya que incluir, ni un dato que nadie pueda retener. Los `PotCheckpoints`
> de esa cadena son **una pista de verificación**, no un requisito de validez (§A.3).

Quién la calcula, en la práctica: **cualquiera con un núcleo libre**, y en particular el timekeeper, que
es quien ya tiene la infraestructura. Dos disciplinas, con su condición escrita:

| Disciplina | Cadenas simultáneas | Condición de puntualidad |
|---|---|---|
| **(i) esperar al ancla** (arranca en `T_j + W_dec`) | `q = ⌈L/I⌉` | dispone de `L + off − W_dec` slots para `Lrev` ⇒ **`Lrev ≤ L − W_dec`** |
| **(ii) especular** sobre el menú (arranca al ver cada candidato) | `m·q` | `Lrev ≤ L`; `m` medido 2,54, cota `1 + λ·S_max = 151` |

> ⚠️ **Corrección a mi propio intento anterior (regla de método 9).** Escribí que con la disciplina (i)
> «el timekeeper necesita ser un **0,63 % más rápido que el nominal**, y el nominal ya es el tope del
> mercado». **El número es correcto y la lectura era falsa.** La carrera **no es contra el reloj de
> pared**: `t_j` es un *índice de slot*, no un instante. Si el timekeeper va 1,56× más lento, su slot
> dura 1,56× más y su revelación también: la revelación compite **contra su propia cadena principal**,
> no contra un reloj externo. Lo que falta con `Lrev = L` es que **la línea de revelación adelante a la
> línea principal en el mismo silicio**, y eso no se compra con dinero. Se compra con **`Lrev < L`**.

**La palanca `Lrev`, con su precio exacto** (§B.3.c, medido): la condición de steering pasa a
`ρ* = (Lrev + I)/(I + W_dec)`. Con `L = 2 h`, `I = 851 s`, `W_dec = 20 s`:

| `Lrev/L` | holgura del timekeeper | `ρ*` |
|---:|---:|---:|
| 1,00 | 1,000× (**no llega**) | 9,24 |
| 0,99 | 1,010× | 9,16 |
| 0,979 (`Lrev = L − S_max`) | 1,021× | 9,07 |
| 0,75 | 1,333× | 7,17 |
| 0,50 | 2,000× | 5,11 |

> **(h.1b) Recomendación con etiqueta (PLAUSIBLE):** `Lrev = L − S_max`. Compra 2,1 % de holgura, que
> cubre `W_dec = 45 s` y el margen de acuerdo de §A.3, y cuesta **1,8 % de `ρ*`** (9,24 → 9,07).

### A.2 · Publicación y verificación

> **(h.2)** Los `PotCheckpoints` de la cadena de revelación viajan por el gossip de PoT
> (`/subspace/subspace-proof-of-time/1`, `sc-proof-of-time/src/source/gossip.rs:72`) bajo un tema
> separado, **según se calculan**, no de golpe. Un nodo **MUST NOT** verificar una revelación cuya
> semilla no sea exactamente `blake3(chunk(X) ‖ salida(f, slot(X)))` para un `X` que él mismo tenga
> por candidato a `I_j` — es la defensa que Autonomys ya aplica al PoT ordinario
> (`gossip.rs:245-256`: si `proof.seed ≠ next_slot_input.seed`, `GOSSIP_NEXT_SLOT_MISMATCH` y **no
> se verifica**; `GOSSIP_INVALID_PROOF` es `new_fatal`, `gossip.rs:43-49`).
> **(h.2b)** El bloque **NO** lleva la cadena: lleva, a lo sumo, el compromiso de 16 B. Meterla entera
> (`L·128 B` = **900 kB** con `L = 2 h`) añadiría **0,74 s** de propagación a un bloque por época en un
> enlace de 10 Mbit/s, un **18,4 % de `Δ = 4 s`** (§C.2), y `Δ` es la variable de la que depende la
> frontera entera (46,9 % a 4 s, 32,4 % a 20 s, 9a). **Vía P2 (gossip), la latencia añadida es cero.**
> **(h.2c) Regla de coste (necesaria, §B.2):** un nodo verifica **una sola** revelación por época, la
> del `I_j` de su cadena seleccionada, y **en orden de slot aleatorio**. Lo segundo es gratis y sube la
> asimetría de 16,2× a **32,3×** (§B.2.b).

### A.3 · Qué pasa si en `t_j` no hay entropía — **la pregunta está mal planteada, y esa es la respuesta**

> ⚠️ **Corrección a mi propio intento anterior (regla de método 9).** Escribí una regla **(h.3)
> «Continuidad por defecto»**: si en `t_j` ningún bloque de `past(B)` aporta la revelación, la cadena
> sigue sin inyectar y la inyección se aplica en el primer slot en que la revelación **esté disponible
> en `past(B)`**. **Esa regla está ROTA y la retiro.** Hace que `t'_j` —y con él `flujo`— dependa de
> **cuándo llegó un mensaje**, no de la estructura del pasado: dos honestos que construyen sobre puntas
> distintas leerían `t'_j` distintos, luego flujos distintos, y **R-FIN-5 les prohíbe referenciarse**.
> Es una partición del DAG entre honestos disparada por la red. Exactamente lo que `t_j = slot(I_j)+L`
> con `L = F` existe para evitar (a `t_j` el ancla lleva `F` de finalidad y todos coinciden en ella).
> Las dos alternativas que descarté entonces («parar» y «la aplica quien la traiga») fallan igual.

**La formulación correcta no tiene esa rama.** `entropía_j` es una **función determinista de `past(B)`**
(A.1). No hay «si no está»: está siempre, porque se calcula. Lo único que puede faltar son los
`PotCheckpoints`, y su ausencia **no cambia la validez de ningún bloque**: cambia el **coste** de
comprobarla, de `Lrev·verify` a `Lrev·prove`, es decir **×16,24** (medido, §B.2 control C0).

> **(h.3′) Validez incondicional.** Un bloque con `slot(B) ≥ t_j` es válido o inválido según
> `entropía_j` calculada de `past(B)`, **con independencia de que alguien haya publicado los
> checkpoints**. Un nodo que no los tenga los recomputa. **DEMOSTRADO** que esto elimina la rama que
> rompía R-FIN-5: no queda ninguna condición de validez que dependa de la vista.

Y aquí está el precio, que es el hallazgo real de este punto:

| | por nodo, en núcleos continuos (`I = 851 s`, `L = 2 h`) |
|---|---:|
| verificar con checkpoints publicados | **0,813** |
| recomputar sin ellos (`Lrev·prove/I`) | **13,2** |
| cadena principal sola, sin (h) | 0,096 |

**Un nodo sin checkpoints ajenos necesita 14 núcleos dedicados sólo a PoT.** No es un fallo de
vivacidad del consenso —los bloques son válidos—, es una **barrera de hardware para participar**.

### A.4 · Composición con R-FIN-3/4/5 (partición) y R-FIN-9 (recalibración)

> **(h.4)** La revelación es **por flujo**: `V(X)` se siembra con `salida(f, slot(X))`, luego dos flujos
> distintos producen revelaciones distintas del mismo `X` y R-FIN-5 sigue siendo una comprobación
> estructural previa a cualquier PoT. En una partición **cada lado debe sostener sus propias `q + 1`
> líneas de AES**; un lado que no pueda **no es que produzca bloques inválidos: es que no puede saber
> cuál es el reto**, y deja de farmear aunque conserve todo su espacio (§B.4). **Vector nuevo,
> introducido por (h): el suelo de hardware de un lado de partición pasa de 1 línea a `q+1` = 10.**
> **(h.5)** `N(s)` (R-FIN-9) se recalibra igual que hoy, pero el **número de iteraciones de la cadena de
> revelación queda congelado en el `N` vigente en `slot(I_j)`**: si se leyera el `N` de `t_j`, el propio
> retarget de iteraciones desplazaría el instante de revelación y `t_j` dejaría de ser determinista.
> **DEMOSTRADO por construcción** (es la única lectura que hace `t_j` función de `past`).

### A.5 · Precedente: la *infused challenge chain* de Chia

Chia ya opera una segunda cadena de VDF cuyo resultado se inyecta en el reto. Leído en el clon v2.7.4:

- **Quién:** el mismo timelord, como una tercera cadena concurrente —
  `PDF/chia-blockchain/chia/timelord/types.py:6-10` (`CHALLENGE_CHAIN`, `REWARD_CHAIN`,
  `INFUSED_CHALLENGE_CHAIN`) y `chia/timelord/timelord.py:351,470` (itera sobre las tres).
- **Cuándo empieza:** cuando el *deficit* del bloque anterior baja de `MIN_BLOCKS_PER_CHALLENGE_BLOCK = 16`
  (`chia/consensus/block_header_validation.py:170`, `chia/consensus/default_constants.py:15`, comprobado); dura un
  sub-slot (`SUB_SLOT_TIME_TARGET = 600 s`, `default_constants.py:38`).
- **Qué pasa si falta:** **no es opcional.** `block_header_validation.py:205`:
  `assert (sub_slot.infused_challenge_chain is None) == (icc_challenge_hash is None)`; y si el génesis la
  trae, `Err.SHOULD_NOT_HAVE_ICC` (`:163`). Su presencia es una **función del pasado**, exactamente como
  exige (h.2b) aquí.
- **Lo que Chia NO hace y (h) sí pediría:** la ICC de Chia dura **un sub-slot** (600 s) y hay **una** viva a
  la vez. (h) con `L = F = 2 h` e `I = 851 s` pide **nueve** vivas a la vez. El precedente **sostiene el
  mecanismo, no la escala.** VERIFICADO (citas leídas); la comparación de escala es mía.

---

### A.6 · El texto de la regla candidata, junto — **PLAUSIBLE** (mío, no verificado en red)

> **R-FIN-14 (h) · Revelación retardada por VDF. OPCIÓN.** *(No aplicada a la propuesta.)*
>
> **(h.1) Definición.** Con `Lrev` una constante de consenso en slots, `Lrev = L − S_max`:
> ```
> entropía_j = blake3( AES128_chain^{Lrev·N(slot(I_j))} ( blake3(chunk(I_j) ‖ salida(f, slot(I_j)))[0..16) ) )
> ```
> aplicada en `t_j = slot(I_j) + L` (R-FIN-2, sin cambios). `entropía_j` es **función de `past(B)` y
> de nada más**: no es un mensaje, no se «publica», **se calcula**. Cualquier nodo con un núcleo
> libre la produce.
> **(h.2) Pista de verificación.** Los `PotCheckpoints` de esa cadena viajan por el gossip de PoT
> bajo tema propio, **según se calculan** (nunca en bloque: `L·128 B` = 900 kB añadirían un 18,4 %
> de `Δ`). Un nodo **MUST NOT** verificar una revelación cuya semilla no corresponda a un candidato
> a `I_j` que él mismo tenga. Verifica **una** por época —la del ancla de su cadena— y **en orden de
> slot aleatorio**. Si le llegan más revelaciones distintas de las que compensa verificar, **se la
> calcula él** (es literalmente lo que hace Autonomys con el PoT ordinario,
> `sc-proof-of-time/src/source/gossip.rs:438-440`, con el umbral en la asimetría medida, 16,24).
> **(h.3) Validez incondicional.** La validez de un bloque con `slot(B) ≥ t_j` **NO** depende de que
> los checkpoints estén publicados: quien no los tenga, recomputa (×16,24). No existe ninguna rama
> de consenso condicionada a la disponibilidad de un mensaje. *(Es lo que impide que `flujo` dependa
> de la vista y parta el DAG entre honestos.)*
> **(h.4) Por flujo.** `V(X)` se siembra con `salida(f, slot(X))`: dos flujos dan revelaciones
> distintas del mismo `X`, y R-FIN-5 sigue siendo estructural y previa a cualquier PoT.
> **(h.5) Iteraciones congeladas.** El `N` de la cadena de revelación es el vigente en `slot(I_j)`,
> **no** el de `t_j`: si no, el retarget de R-FIN-9 desplazaría el instante de revelación y `t_j`
> dejaría de ser determinista.
> **(h.6) Calibración.** `I ≤ (L − ρ_max·W_dec)/(ρ_max − 1)`. Es la condición que hace `ρ* ≥ ρ_max`,
> y fija a la vez el coste: `1 + L/I ≈ ρ_max` (§C.5). **Pagar más `L/I` que `ρ_max` es tirar CPU.**

**Etiquetas por pieza:** (h.1) PLAUSIBLE · (h.2) PLAUSIBLE, con el precedente de Autonomys VERIFICADO ·
(h.3) DEMOSTRADO que elimina la dependencia de la vista · (h.4) DEMOSTRADO por construcción ·
(h.5) DEMOSTRADO por construcción · (h.6) DEMOSTRADO (aritmética) + VERIFICADO (§B.1, 14 semillas).

---

## B.1 · El reloj rápido y la cota `ρ ≥ L/W_dec` — **la cota es correcta y es incompleta**

Instrumentos: `r10a_lib.py` (la recursión de la frontera de PoT), `r10a_b1_reloj.py`, salida en
`salida_b1.txt`. 14 semillas, 4 000 épocas por semilla (39 días de red por semilla a `I = 851 s`).

### B.1.0 · El modelo, en cuatro líneas, y por qué es más fuerte que el de 9c

`s_j = slot(I_j) = T_j + off_j` · `t_j = s_j + L`. El atacante corre `ρ` slots de AES por segundo de
pared. Para pasar la barrera `t_j` necesita (1) haber llegado con su cadena común al slot `t_j − 1`
y (2) tener `entropía_j`. **Cuándo la tiene es lo único que cambia entre las variantes:**

| | sin (h) | con (h) |
|---|---|---|
| ancla **ajena** | en cuanto el bloque existe: `s_j` | `s_j + Lrev/ρ` |
| ancla **propia** | en cuanto su frontera pasa `s_j` (puede ser **antes** de `s_j`) | eso `+ Lrev/ρ` |

**Adversario del paper (regla de método 8):** especula sobre **todos** los candidatos; **no espera a
que la red decida el ancla**. Esto es más fuerte que el modelo de 9c, que le hacía esperar a
`T_j + W_dec`. Y es lo que hace que mi recursión reproduzca la forma cerrada de la **ronda 7** y no la
de 9c (control C2 abajo).

### B.1.1 · Los tres controles positivos — los tres pasan

| Control | Fuente | Resultado |
|---|---|---|
| **C1** tope y *bootstrap* sin (h) | 9c §E.1: `L+I−W_dec = 23 130`; `tope/(ρ−1)` | `23 130` **IDÉNTICO**. *Bootstrap* **medido** hasta `0,9 L`: 477,06 h a `ρ=1,01` frente al cerrado 477,00 h (**razón 1,000**); 95,56/95,40 h a 1,05; 2,72/2,38 h a 3,0 (razón 1,14: a `ρ` alta la granularidad de época domina) |
| **C2** las dos formas de la ronda 7 | `dag-poas-ancla-de-finalidad.md:319-322` | **razón 1,000 en las 15 filas.** `L + I(1−1/ρ)` sin (h) y `(L+I)(1−1/ρ)` con (h), producidas por la recursión, no programadas |
| **C3** `ρ ≤ 1 ⇒` steering 0 | 9c hallazgo E1 | `ρ = 1,000` → **0,000 exacto** en las 6 filas. `ρ = 1,001` → **0,000 también**, y eso es un matiz nuevo: «cualquier `ρ > 1`» es **asintótico**; con horizonte de 39 días el *bootstrap* `L/(ρ−1) = 83 días` no cabe |

> **C2 es el control que decide el punto.** Mi recursión reproduce **exactamente** lo que la ronda 7
> escribió en 2026-09-08 y **contradice** lo que 9c §E.5 escribió el mismo día («`n_eval = 0` para
> cualquier `ρ`»). No es opinión: la ronda 7 tiene razón y 9c se equivocó.

### B.1.2 · La cota real: tres condiciones, no una

Para hacer steering en la época `j` el atacante necesita, **antes de `D_j = T_j + W_dec`**, las tres:

```
(1) cadena común hasta t_j − 1      ⇒  ρ ≥ (Lrev + I) / (I + W_dec − off)
(2) entropía de SU candidato        ⇒  ρ ≥ (Lrev + q·I) / (q·I + W_dec − off),  q = ⌈L/I⌉
(3) entropía de un candidato AJENO  ⇒  ρ ≥ Lrev / (W_dec − off)      ← la cota del encargo
```

Medido (`salida_b1.txt`, B.1.a y B.1.b), con `L = 2 h`, `I = 851 s`, offset geométrico, 14 semillas:

| `α` | `W_dec` | (1) cadena común | (2) entropía propia | (3) entropía ajena | **`ρ*` propio, simulado** | **`ρ*` ajeno, simulado** |
|---:|---:|---:|---:|---:|---:|---:|
| 0,00 | −1 | — | — | — | sin steering | sin steering |
| 0,10 | 10 | 9,35 | 1,94 | **720** | 9,39 [9,39; 9,39] | > 1000 |
| 0,25 | 20 | 9,24 | 1,94 | **360** | 9,28 [9,28; 9,29] | 438,8 [433; 446] |
| 0,33 | 20 | 9,24 | 1,94 | **360** | 9,28 [9,28; 9,29] | 438,8 [433; 446] |
| 0,40 | 45 | 8,99 | 1,94 | **160** | 9,02 [9,02; 9,03] | 173,9 [173; 175] |

**Lectura, en tres frases.**
1. **La cota del encargo (3) es CORRECTA** para el steering completo —elegir entre los `m` candidatos
   del menú—, y la simulación la confirma con un 8 % de margen por el `off > 0` (173,9 medido frente
   a 160 cerrado; el bloque ajeno no existe antes de su slot y `off` come ventana).
2. **Es incompleta.** El atacante no necesita evaluar candidatos ajenos para hacer steering: le basta
   con **publicar o retener el suyo** (`m = 2` con una rama conocida y otra a ciegas). Para eso manda
   la condición (1) y `ρ*` cae de **160 a 8,99** — un factor **17,8×**.
3. La condición (2) —poder fabricar y evaluar su propio candidato— **nunca manda**: 1,94 frente a 9,24.
   Es decir: *tener* el candidato es barato; lo caro es *tener la cadena común donde inyectarlo*.

`ρ*` con otras parejas (B.1.a): `(2 h, 300 s)` → 23,7 · `(1 h, 851 s)` → 5,13 · `(1 h, 300 s)` → 12,3.
La forma cerrada `(L+I)/(I+W_dec)` reproduce las 16 filas con error ≤ 1,3 % (offset geométrico) y
≤ 0,1 % (offset cero). Con offset uniforme en `[0, S_max)` la simulación da hasta 10,27 frente a 9,35:
el cerrado es **conservador**, como debe ser.

### B.1.3 · Por debajo de `ρ*` queda un residuo: **las rachas de ancla propia** (hallazgo nuevo)

Si el ancla de una época es un bloque **del atacante**, la barrera `t_j` **no lo bloquea**: su VDF de
revelación arranca cuando su frontera pasa `s_j` y termina justo cuando su cadena principal llega a
`t_j` (las dos son `Lrev ≈ L` slots de AES). En una racha de anclas propias su ventaja **crece sin
tope**. Una sola ancla honesta la recorta a `L(1−1/ρ)`. De ahí, cerrado:

```
ventaja tras r anclas propias seguidas = (L + (r+1)·I)(1 − 1/ρ)
steering  ⟺  (L + (r+1)·I)(1 − 1/ρ) ≥ L − W_dec + off
n* = ⌈ ((L − W_dec)·ρ/(ρ−1) − L) / I ⌉        tasa de épocas con steering = α^(n*−1)
```

**VERIFICADO** contra la simulación (`salida_b1.txt`, B.1.c; 14 semillas × 4 000 épocas, `p_propia = α`):

| `α` | `ρ` | `n*` | tasa cerrada | tasa simulada | razón | épocas/año |
|---:|---:|---:|---:|---:|---:|---:|
| 0,33 | 1,5 | 17 | 1,98·10⁻⁸ | 0 (39 d × 14 sem.) | — | 7,3·10⁻⁴ |
| 0,33 | 2,0 | 9 | 1,406·10⁻⁴ | 8,93·10⁻⁵ | 0,63 | 5,21 |
| 0,33 | 2,5 | 6 | 3,914·10⁻³ | 3,97·10⁻³ | **1,01** | 145 |
| 0,33 | 3,0 | 5 | 1,186·10⁻² | 1,187·10⁻² | **1,00** | 439 |
| 0,33 | 5,0 | 3 | 1,089·10⁻¹ | 1,072·10⁻¹ | 0,98 | 4 040 |
| 0,33 | 9,0 | 2 | 3,300·10⁻¹ | 3,279·10⁻¹ | 0,99 | 12 200 |
| 0,40 | 2,5 | 6 | 1,024·10⁻² | 9,73·10⁻³ | 0,93 | 379 |
| 0,10 | 2,5 | 6 | 1,000·10⁻⁵ | 0 | — | 0,37 |

La fila `α = 0,00` da **0,000e+00 en las siete `ρ`**: criterio α cumplido, y por tres vías
independientes (`W_dec(α)`, `m(α)`, `p_propia = α`).

**Lo que esto significa para `ρ_max`.** El techo físico estimado del reloj AES es **1,5-2,5×**
(`pot-aes-asic-chacha.md` §3, ESTIMACIÓN del principal, sin paper; el estudio de Supranational que
Autonomys cita no se ha localizado — LAGUNA heredada). En ese rango:

| `ρ` | épocas con steering al año (`α = 0,40`) | ganancia amortizada `ḡ` por época |
|---:|---:|---:|
| 1,5 | 1,6·10⁻² | 0,000 % |
| 2,0 | 24 | 0,002 % |
| 2,5 | 379 | 0,026 % |
| 3,0 | 949 | 0,065 % |
| — sin (h), `ρ = 1,2` — | 37 000 (todas) | **1,07 %** (`α = 0,33`) |

### B.1.4 · Lo que compra, en la moneda del diseño

`g = c_m·√(α·λ·n_eval) / (α·λ·I)`, la fórmula de la ronda 4 verificada por 9c §D.1. Medida por época
(no `g` de la media: media de `g`), `L = 2 h`, `I = 851 s`, `α = 0,33`:

| `ρ` | `n_eval` sin (h) | `ḡ` sin (h) | `n_eval` con (h) | `ḡ` con (h) | factor |
|---:|---:|---:|---:|---:|---:|
| 1,0 | 0 | 0,000 % | 0 | 0,000 % | — |
| 1,2 | 18,1 | **1,074 %** | 0 | **0,000 %** | ∞ |
| 1,5 | 22,7 | 1,594 % | 0 | 0,000 % | ∞ |
| 2,0 | 30,2 | 1,953 % | 0,06 | 0,000 % | ∞ |
| 2,5 | 37,8 | 1,953 % | 2,42 | 0,007 % | **279×** |
| 3,0 | — | 1,953 % | 10,1 | 0,023 % | 85× |
| 9,0 | — | 1,953 % | 279 | 0,644 % | 3,0× |

*(«`ḡ` con (h)» toma la mejor de las dos ramas —candidato propio o ajeno— en cada época.)*

**Esto es lo que (h) compra de verdad, y es mucho:** en el rango físicamente alcanzable
(`ρ ≤ 2,5`) baja el steering de **1,95 % a 0,007 %** por época, un factor **279×**. Lo que **no**
hace es llevarlo a 0 «para cualquier `ρ`», como decía 9c §E.5.

### B.1.5 · Los contraataques que el encargo pide, uno a uno

| Pregunta | Respuesta | Etiqueta |
|---|---|---|
| ¿Correlaciones entre `chunk`, `salida(I_j)` y la época? | La semilla es `blake3(chunk ‖ salida)[0..16)` y de ahí `AES128^N`. La hipótesis es «no hay atajo para `f^N`», **la misma sobre la que descansa la cadena principal** (R-FIN-14 (a)); si cayera, cae el PoT entero, no sólo (h). No hay estructura adicional que explotar | DEMOSTRADO **condicional** a la hipótesis del PoT |
| ¿Reutilizar el VDF de candidatos anteriores? | La semilla depende de `(chunk(X), salida(f, slot(X)))`. Dos candidatos distintos difieren en al menos uno ⇒ semillas distintas ⇒ **cero reutilización**. Y el corolario **a favor** de (h): dos bloques con el **mismo** `chunk` y el mismo slot dan la **misma** entropía, luego **barajar transacciones o padres no es una palanca de grinding** | REFUTADO (el ataque) |
| ¿Retener candidatos y arrancar su VDF antes de publicarlos? | Es exactamente la rama «ancla propia»: **sí, y es la que rompe la cota del encargo** (§B.1.2 y B.1.3) | **CONFIRMADO** |
| Con `m ≤ 1 + λ·S_max` candidatos, ¿cuántos VDF en paralelo y qué compra? | Una línea AES por candidato y por época en vuelo: `q = ⌈L/I⌉ = 9` para la cadena común, `+q` por cada candidato que evalúe. **10** líneas para seguir la cadena, **19** para evaluar un candidato propio, **27** con el menú medido `m(0,40) = 1,83`, **1 369** con el `m` máximo. Y **no compra nada** evaluar candidatos ajenos por debajo de `ρ = 160`: las 1 350 líneas extra son dinero tirado | VERIFICADO (B.1.f) |

---

## B.2 · DoS de verificación — **REFUTADO como ataque; el coste que queda es el honesto**

Instrumento `r10a_b2_dos.py`, salida `salida_b2.txt`. **Control C0:** los dos costes unitarios no se
recitan, se leen del artefacto que dejó `cargo bench -p subspace-proof-of-time` en esta máquina
(`target/criterion/{prove,verify}/new/estimates.json`): `prove = 1,561347 s/slot` (sd 0,003265),
`verify = 0,096147 s/slot` (sd 0,000344), **asimetría 16,24×**. Coincide con lo publicado en
`dag-poas-ancla-de-orden.md`.

### B.2.1 · Dos cosas leídas en el código que cambian el análisis

1. **`verify_sequential` NO tiene salida temprana dentro de un slot.** Procesa los 8 checkpoints en
   paralelo con SIMD y en **encuentro por el medio** (cifra desde la entrada, descifra desde la
   salida, `checkpoint_iterations/2` cada mitad) y compara **al final**
   (`subspace-proof-of-time/src/aes/x86_64.rs:75-107`). **El grano mínimo de verificación es un slot
   entero = 96,1 ms**, no un checkpoint. La afirmación del encargo «paralelizable por checkpoints»
   es cierta *dentro* de la implementación (ya lo está), no como granularidad de rechazo.
2. **Entre slots sí hay salida temprana y paralelismo total.** La semilla del slot `i` es la salida
   del `i−1`, publicada en los `PotCheckpoints` (`pot.rs:328,332`), luego los `L` slots de una
   revelación se verifican **en cualquier orden y en paralelo**.

### B.2.2 · La cuenta del ataque

El atacante calcula de verdad un prefijo de `p` slots y falsifica el resto (`L − p` slots malos:
lo que no calcula, no le sale bien). Medido con 12 semillas × 20 000 búsquedas:

| `L` | `p/L` | slots malos | verif. **en orden** | coste del atacante | razón | verif. **en orden aleatorio** | razón |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 h | 0,00 | 7 200 | 0,10 s | 0 s | — | 0,15 s | — |
| 2 h | 0,25 | 5 400 | 173,2 s | 2 810,4 s | 16,2× | 0,18 s | 15 401× |
| 2 h | 0,50 | 3 600 | 346,2 s | 5 620,8 s | 16,2× | 0,24 s | 22 973× |
| 2 h | 0,90 | 720 | 623,1 s | 10 117,5 s | 16,2× | 1,02 s | 9 965× |
| 2 h | 0,99 | 72 | 685,4 s | 11 129,3 s | 16,2× | 9,52 s | 1 169× |
| 2 h | 1,00 | **1** | **692,4 s** | **11 241,7 s** | **16,2×** | **346,6 s** | **32,4×** |

*(la columna «en orden aleatorio» está **medida** con 12 semillas × 20 000 búsquedas; el cerrado
`(L+1)/(j+1)` la reproduce con error ≤ 0,4 %: 346,18 frente a 346,58 s en la última fila)*

**Tres conclusiones.**
- **La asimetría 16,2× basta**, y con una regla gratis sube a **32,5×**: verificar los `L` slots de
  la revelación **en orden de slot aleatorio**. Entonces el óptimo del atacante es dejar **un solo**
  slot malo —lo que le obliga a calcular `L−1` slots de verdad, 11 242 s de CPU— para arrancarle al
  verificador 346 s. Cualquier otra estrategia le sale peor.
- **Una revelación completamente falsa cuesta 96,1 ms** y `GOSSIP_INVALID_PROOF` es
  `new_fatal` en Autonomys (`gossip.rs:43-49` leído): un solo intento por par.
- El número de semillas de revelación que puede reclamar legítimamente por época es
  `α·λ·S_max` = **60 a `α = 0,40`** (necesita un bloque válido en la banda del ancla, que cuesta
  **espacio**, no CPU): 5,8 s por época sin la regla (h.2c), 0,096 s con ella.

> **Precedente en producción, y no lo esperaba: Autonomys ya implementa esta defensa.**
> `sc-proof-of-time/src/source/gossip.rs:438-440`:
> `// If we have too many unique proofs to verify it might be cheaper to prove it ourselves`
> `let correct_proof = if potentially_matching_proofs.len() < EXPECTED_POT_VERIFICATION_SPEEDUP {`
> con `const EXPECTED_POT_VERIFICATION_SPEEDUP: usize = 7` (`:32`). Es exactamente el argumento de
> la asimetría, cableado: si le llegan más pruebas distintas de las que compensa verificar, **se la
> calcula él**. **Y su constante es 7 donde yo mido 16,24**, luego su presupuesto es conservador por
> un factor 2,3. Para (h) la misma regla se aplica tal cual, con el umbral en la asimetría medida.

### B.2.3 · El coste que sí duele es el honesto

**El multiplicador de la verificación de PoT de cada nodo es `1 + L/I`.** Medido:

| `L` | `I` | CPU/época | núcleos continuos | × la cadena principal |
|---:|---:|---:|---:|---:|
| 2 h | 851 s | 692,3 s | **0,813** | **9,46×** |
| 2 h | 300 s | 692,3 s | **2,308** | **25,0×** |
| 1 h | 851 s | 346,1 s | 0,407 | 5,23× |

La cadena principal sola cuesta 9,61 % de un núcleo. **(h) lleva a un nodo completo de 0,096 a 0,91
núcleos continuos** sólo en PoT. Etiqueta: **VERIFICADO** (aritmética sobre una medida de Criterion).

### B.2.4 · El vector que sí escala, y su cota

Con (h.2c) el nodo verifica la revelación del ancla de **su** cadena. Una reorganización que cambie
el ancla de las últimas `F/I` épocas obliga a re-verificarlas: **8,5 épocas × 692 s = 5 857 s** de CPU
(183 s de pared con 32 núcleos) a `(I, F) = (851 s, 2 h)`, y **16 614 s** con `I = 300 s`. R-FIN-7 acota
la reorg a `F`, luego el número está acotado; y el atacante paga `prove` por cada época que quiera
hacer válida (**95 112 s**, 26,4 horas-núcleo). La asimetría se mantiene. **PLAUSIBLE** (no simulado
en red; es aritmética sobre la cota de R-FIN-7).

---

## B.3 · Vivacidad del timekeeper — **el coste de CPU no es el problema; la barrera de entrada sí**

Instrumentos: `r10a_b3_lineas.c` (microbanco en C que replica literalmente el núcleo de
`subspace-proof-of-time/src/aes/x86_64.rs:22-33`: nueve `_mm_aesenc_si128` más un
`_mm_aesenclast_si128` encadenados) y `r10a_b34_vivacidad.py`. Salida `salida_b34.txt`.

**Por qué hacía falta medir:** el bench de Autonomys `pot-compare-cpu-cores.rs` **fija la afinidad a
un núcleo cada vez y mide de uno en uno** (leído en el fuente); no dice nada sobre `q+1` líneas
simultáneas, que es justo lo que (h) pide.

**Control positivo:** 1 hilo → **1,484 s/slot**, frente a `prove` de Criterion **1,561 s/slot** en la
misma máquina: razón **0,950**, y el microbanco no guarda checkpoints ni pasa por Criterion, luego
tenía que salir algo por debajo. El instrumento está calibrado.

### B.3.1 · **HALLAZGO, y va a favor de (h): 25 líneas de AES simultáneas cuestan un 1,7 %**

| hilos | s/slot | degradación |
|---:|---:|---:|
| 1 | 1,486 | 1,001 |
| 10 | 1,513 | 1,020 |
| 16 | 1,513 | 1,020 |
| **25** | **1,509** | **1,017** |
| 32 | 1,623 | 1,094 |
| 48 | 2,126 | 1,433 |

Un 9950X3D (16 núcleos físicos, SMT ×2) sostiene **25 cadenas de PoT independientes con un 1,7 % de
degradación** — más líneas que núcleos físicos. La razón es física y está en el propio informe
`pot-aes-asic-chacha.md` §1: cada iteración son **diez `AESENC` dependientes**, luego una línea está
**limitada por latencia**, no por rendimiento, y el SMT la esconde entera. A 32 hilos la degradación
salta a 9,4 %, pero esta máquina tenía dos procesos de otros agentes encima durante la medida
(declarado; por eso se toma la **mejor de 5 corridas** y se reporta la peor).

> **Corrijo mi propia expectativa.** Iba a escribir que `q+1 = 10` líneas eran un coste serio para el
> timekeeper. **No lo son:** caben en un PC de sobremesa con margen. Lo que no cabe es la disciplina
> especulativa con el menú máximo: **1 360 líneas** a `(I, F) = (851 s, 2 h)` (§C.4). La regla (h.1)
> **tiene** que acotar `m`, o usar la disciplina (i) con `Lrev < L`.

### B.3.2 · Cadenas en vuelo y puntualidad

| `I` | `F = L` | `q = ⌈L/I⌉` | (i) líneas | (ii) `m = 1,83` | (ii) `m` máximo | ¿llega con `Lrev = L`? |
|---:|---:|---:|---:|---:|---:|---|
| 851 s | 2 h | 9 | **10** | 18 | 1 360 | **NO**, falta 0,62 % |
| 300 s | 2 h | 24 | **25** | 45 | 3 625 | **NO**, falta 0,62 % |
| 851 s | 1 h | 5 | **6** | 11 | 756 | **NO**, falta 1,25 % |

**Qué pasa si el timekeeper real va a 1,561 s/slot (esta máquina).** Nada: `t_j` es un **índice de
slot**, no un instante de pared. Si el timekeeper va 1,56× más lento, su slot dura 1,56× más **y su
revelación también**; la carrera es contra su propia cadena principal, en el mismo silicio. Lo
absoluto es que **cada línea necesita su núcleo**. (Este es el punto que corregí de mi intento
anterior, §A.1.)

La palanca `Lrev` (medida, B.3.c): `ρ* = (Lrev + I)/(I + W_dec)`.

| `Lrev/L` | holgura | `ρ*` a `W_dec = 20 s` | `ρ*` a `W_dec = 45 s` |
|---:|---:|---:|---:|
| 1,00 | 1,000× (no llega) | 9,24 | 8,99 |
| 0,99 | 1,010× | 9,16 | 8,91 |
| 0,90 | 1,111× | 8,42 | 8,18 |
| 0,50 | 2,000× | 5,11 | 4,97 |

**`Lrev = 0,99 L` cuesta el 0,9 % de `ρ*` y resuelve la puntualidad.** DEMOSTRADO (aritmética) +
VERIFICADO (la forma cerrada reproduce la simulación de B.1 con error ≤ 1,3 %).

### B.3.3 · `autonomys/subspace#2141` — **no empeora por velocidad; empeora por barrera de entrada**

Dos efectos, separados:
- **Velocidad (el issue en sí):** **ninguno**. La carrera de #2141 es por publicar antes el mismo
  slot. La revelación es determinista y también la gana el más rápido, sin darle nada más que a la
  cadena principal. `ρ` no cambia.
- **Barrera de entrada:** la multiplica por **`q+1`** — de 1 núcleo a **10** (`I = 851 s`, `F = 2 h`)
  o **25** (`I = 300 s`). Menos gente puede correr un timekeeper ⇒ **menos timekeepers ⇒ más #2141**.
  Es un empeoramiento **cualitativo, no de velocidad**, y B.3.1 dice que el número absoluto (10-25
  núcleos) sigue siendo un PC. **PLAUSIBLE**: el efecto sobre el *número real* de timekeepers no se
  puede medir sin red. LAGUNA declarada.

---

## B.4 · Partición y `S_max` — **sí, (h) introduce un vector nuevo, y es de hardware**

Con la formulación correcta (§A.3, (h.3′)) `entropía_j` es función de `past(B)`: los bloques del otro
lado son **válidos**. Pero un lado que no pueda calcularla **no sabe cuál es el reto de sus propios
slots** y deja de farmear, aunque conserve todo su espacio.

| `I` | `F = L` | líneas necesarias | núcleos del lado | retraso de cada revelación | `d/I` |
|---:|---:|---:|---:|---:|---:|
| 851 s | 2 h | 10 | 1 | **64 800 s = 18 h** | 76,1 |
| 851 s | 2 h | 10 | 2 | 28 800 s = 8 h | 33,8 |
| 851 s | 2 h | 10 | 4 | 10 800 s = 3 h | 12,7 |
| 851 s | 2 h | 10 | **10** | **0** | 0 |
| 300 s | 2 h | 25 | 4 | 37 800 s = 10,5 h | 126 |
| 851 s | 1 h | 6 | 4 | 1 800 s = 0,5 h | 2,1 |

**El vector, escrito:** *sin* (h) un lado de partición necesitaba **una** línea de AES para seguir
viva; *con* (h) necesita **`q+1`**. Con 4 núcleos y `(851 s, 2 h)` el retraso es de 3 h > `F = 2 h`:
**el lado queda por detrás de su propia finalidad y muere con todo su espacio intacto.** Es
exactamente el modo de fallo que R-FIN-7 quería evitar (tolerar una partición de hasta `F` con
`≥ 9 %` del espacio), y (h) lo reintroduce **por el lado del hardware, no del espacio**.

**Lo que NO introduce:** ningún vector de flujo. `V(X)` se siembra con `salida(f, slot(X))`, luego la
revelación es **por flujo** y R-FIN-5 sigue siendo una comprobación estructural previa a cualquier
PoT (h.4). Al reunirse, R-FIN-5/7 funcionan igual que sin (h). **DEMOSTRADO por construcción.**

**Y lo que casi introduce, si se escribe mal:** la regla (h.3) de mi intento anterior —«aplicar la
inyección en el primer slot en que la revelación esté disponible en `past(B)`»— hace `flujo`
dependiente de **cuándo llegó un mensaje** y parte el DAG entre honestos. Retirada en §A.3.
**Etiqueta del vector nuevo: VERIFICADO** (aritmética sobre la medida de B.3.1).

---

## B.5 · Carrera de bloques — **DEMOSTRADO que (h) no cambia la frontera de flujo único**

Instrumentos: `r10a_b56_frontera.py` y `r10a_b5b_intentos.py`, que **reutilizan sin tocar** el
`prev()` de `d9-ronda9a/r9a_a3_frontera.py` (el mismo que usa `verif_frontera_vs_F.py`, y que a su
vez es el de D8 y el de `verif_constantes.py`). Salidas `salida_b56.txt` y `salida_b5b.txt`.
**Control:** con `(F, I) = (19 080, 4 200)` y `offset = 3k = 90` salen **46,8784 % / 36,5432 %**,
idénticos a `verif_frontera_vs_F.salida.txt`. En los dos scripts.

**La demostración es de una línea, y por eso es una demostración.** La frontera se calcula con
`prev(α, λ, t, offset, hf)`. Sus cinco argumentos son: la fracción de espacio, la tasa de bloques, el
horizonte `F`, la ventaja inicial `3k` del Lema 10, y el `δ`. **No aparece `ρ`, ni el reto del slot,
ni la entropía, ni cómo se deriva.** (h) sólo puede entrar por dos puertas:

1. **Por `offset`** — si el adelanto `L(1−1/ρ)` le comprase ventaja inicial. Es B.6: **REFUTADO**.
2. **Por las `(I, F)` admisibles** — que es una decisión de calibración, no un efecto de (h).

Medido, para las parejas que (h) hace posibles (`offset = 3k`):

| `F` | `I` | frontera `δ = 0` | frontera `δ` D8 | unión10 a 33 %, `δ = 0` | `δ` D8 |
|---:|---:|---:|---:|---:|---:|
| 5,30 h | 4 200 s | 46,8784 % | 36,5432 % | 3,8·10⁻²¹¹ | 2,1·10⁻¹⁰³ |
| **2,00 h** | **851 s** | **44,5722 %** | **35,0824 %** | 1,4·10⁻¹⁶⁹ | 3,1·10⁻³² |
| 2,00 h | 300 s | 44,4989 % | 35,0369 % | 4,1·10⁻¹⁶⁹ | 8,7·10⁻³² |
| 1,00 h | 851 s | 41,9756 % | 33,0542 % | 1,6·10⁻⁷⁶ | 4,9·10⁻¹¹ |
| 0,28 h | 851 s | 33,0049 % | 27,3598 % | 9,7·10⁻¹¹ | 1,000 |

Es la misma dependencia de `F` que el principal midió el 2026-09-08 (bitácora §11.4): reproducida.
**La conclusión que importa: `F` la fija el corredor, no el steering, y (h) no toca al corredor.**

---

## B.6 · El adelanto `L(1−1/ρ)` — **REFUTADO como daño a la frontera; la LAGUNA «ráfagas» queda cerrada**

### B.6.1 · Cuánto adelanto es, medido

| `ρ` | sin (h): `L + I(1−1/ρ)` | con (h): `(L+I)(1−1/ρ)` | cociente |
|---:|---:|---:|---:|
| 1,00 | 7 200 slots | **0** | ∞ |
| 1,20 | 7 342 | 1 342 | **5,5×** |
| 1,50 | 7 484 | 2 684 | 2,8× |
| 2,00 | 7 626 | 4 026 | 1,9× |
| 2,50 | 7 711 | 4 831 | 1,6× |
| 3,00 | 7 767 | 5 367 | 1,4× |

**En el rango físicamente alcanzable (`ρ ≤ 2,5`) (h) divide el adelanto por 1,6-5,5×**, y a `ρ = 1`
lo lleva a **cero exacto**. Ésta es la ganancia real de (h) y coincide **exactamente** con lo que la
ronda 7 escribió (control C2, razón 1,000).

### B.6.2 · Qué compra ese adelanto — la ráfaga planificada, medida

Con `V` slots de adelanto el atacante conoce **sus propias** victorias futuras durante `V` segundos
(las ajenas no: no tiene los *plots* de nadie más). Deslizando la ventana mientras espera, elige el
instante de arrancar su cadena privada donde su cosecha sea mayor. Medido, 14 semillas × 200
realizaciones, espera de 1 mes, `α = 0,33`:

| régimen | `ρ` | `V` | ventanas | exceso medido (bloques) | cerrado `√(2 ln n)·√(αλV)` | razón | % de `3k` |
|---|---:|---:|---:|---:|---:|---:|---:|
| sin (h) | 1,2 | 7 342 | 358 | **146,1** | 168,8 | 0,866 | **162 %** |
| con (h) | 1,2 | 1 342 | 1 959 | **73,7** | 81,9 | 0,900 | 82 % |
| sin (h) | 2,0 | 7 626 | 344 | 148,4 | 171,5 | 0,865 | 165 % |
| con (h) | 2,0 | 4 026 | 653 | 115,1 | 131,2 | 0,877 | 128 % |
| — `α = 0,00` — | — | — | — | **0,00 en las 24 filas** | 0,00 | — | 0,0 % |

El exceso es **grande**: hasta 171 bloques frente a los 90 de `3k`. Si se sumara al `offset`, la
frontera caería **1,15 puntos** (44,5722 % → 43,4210 %) sin (h) y **0,58** con (h) (`salida_b56.txt`,
B.6.c). **Y eso sería contarlo dos veces.**

### B.6.3 · Por qué no cuenta: la cota de la unión ya se lo regaló

```
union10(α) = prev(α) · N,   N = épocas en 10 años = 370 576   (`d9-ronda9a/r9a_a3_frontera.py:65-68`)
```
es **una cota de la unión sobre `N` instantes de arranque**. Para cualquier conjunto `S` de
instantes, `P(⋃_{t∈S} éxito_t) ≤ |S|·prev(α)`. **Elegir la mejor ventana dentro del adelanto es
elegir un `S`, no cambiar `prev(α)`.** Mientras `|S| ≤ N`, la frontera publicada **ya lo cubre**, y
sumar el exceso al `offset` cuenta la misma fluctuación dos veces: una en el Skellam de la carrera y
otra en la ventaja inicial. **DEMOSTRADO.**

Y con número, porque `|S| ≤ N` no siempre se cumple (`salida_b5b.txt`, B.5.c): con `V` pequeño el
atacante distingue **más** ventanas que épocas hay.

| régimen | `ρ` | `V` | ventanas `\|S\|` | `\|S\|/N` | ¿cubierto? |
|---|---:|---:|---:|---:|---|
| sin (h) | 1,05-3,0 | 7 241-7 767 | 4,1-4,4·10⁴ | 0,110-0,118 | **sí** |
| con (h) | 1,05 | 383 | 8,2·10⁵ | **2,220** | no |
| con (h) | 1,2 | 1 342 | 2,4·10⁵ | 0,634 | sí |
| con (h), `L = 1 h` | 1,05 | 212 | 1,5·10⁶ | **4,015** | no |

Para los casos no cubiertos, la sensibilidad de la frontera al número de intentos está **medida**
(`salida_b5b.txt`, B.5.b), y es la cota rigurosa de todo el punto:

| factor de intentos | intentos en 10 años | frontera `δ = 0` (`F = 2 h`) | vs factor 1 |
|---:|---:|---:|---:|
| 1 | 3,71·10⁵ | 44,5722 % | — |
| 2,22 | 8,23·10⁵ | 44,5160 % | **−0,056 pt** |
| 10 | 3,71·10⁶ | 44,4116 % | −0,161 pt |
| 100 | 3,71·10⁷ | 44,2560 % | −0,316 pt |
| **851** (una carrera **por segundo** durante 10 años) | 3,15·10⁸ | **44,1155 %** | **−0,457 pt** |

> **Cierre de la LAGUNA «ráfagas» de 9c.** Aunque el atacante pudiera arrancar una carrera **cada
> segundo durante diez años** —el máximo concebible, `3,15·10⁸` intentos— la frontera de flujo único
> baja **0,46 puntos** (0,64 con `F = 1 h`; 0,35 con `F = 5,3 h`). El caso real del adelanto está
> entre 1× y 4,0× de intentos, es decir **menos de 0,08 puntos**. Los 1,15 puntos de B.6.c son un
> doble conteo. **REFUTADO como daño a la frontera; VERIFICADO el tamaño de la cota.**
>
> **Detalle honesto que va en contra de (h):** en este eje (h) es **ligerísimamente peor**, porque al
> encoger `V` multiplica el número de ventanas distinguibles (`|S|/N` pasa de 0,11 a 0,63-4,0). El
> efecto neto está acotado por los 0,46 puntos de arriba, así que da igual, pero conviene decirlo.

### B.6.4 · Lo que el adelanto sí compra y no está modelado — **LAGUNA, acotada**

Queda una cosa que ni `prev()` ni los simuladores de DAG de las rondas 8-9 modelan: **la retención
selectiva con información perfecta sobre uno mismo** dentro de GHOSTDAG (publicar o no cada bloque
sabiendo qué vas a ganar en los próximos `V` segundos). Es literalmente el pendiente 4 de la ronda 7
(`dag-poas-ancla-de-finalidad.md:303-305`: «qué hace un granjero que conoce sus victorias 15-60 min
antes; retención con información perfecta propia dentro de GHOSTDAG»), y sigue abierto.

**Lo que (h) hace con él:** encoge la ventana de **7 342 → 1 342 s** a `ρ = 1,2` (5,5×) y a **0** con
`ρ = 1`. **Lo que haría falta para cerrarlo:** un simulador de GHOSTDAG con una política de retención
que consulte las victorias futuras del atacante —`d9-ronda8c/r8c_sim.py` lo permitiría añadiendo un
oráculo de victorias— y medir `δ_ef` y la rentabilidad de la parásita con y sin oráculo, con las 12
semillas. **LAGUNA declarada; no es por falta de tiempo: es que el instrumento no existe.**

---

## C · Coste de (h), con número

Instrumento `r10a_c_coste.py`, salida `salida_c.txt`. Mismo control C0 que en B.2 (los dos costes
unitarios leídos del artefacto de Criterion de esta máquina, no recitados).

### C.1 · La tabla que pide el encargo

| `I` | `F = L` | `q = ⌈L/I⌉` | VDF en vuelo (i) | (ii) `m = 1,83` | núcleos del timekeeper | núcleo/nodo de verificación | × sin (h) | justif. **P1** | gossip **P2** |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 851 s | 2,00 h | 9 | 9 | 17 | **10** | **0,813** | **9,46×** | 900 kB | 1 152 B/s |
| 300 s | 2,00 h | 24 | 24 | 44 | **25** | **2,308** | **25,0×** | 900 kB | 3 072 B/s |
| 851 s | 1,00 h | 5 | 5 | 10 | 6 | 0,407 | 5,23× | 450 kB | 640 B/s |
| 300 s | 1,00 h | 12 | 12 | 22 | 13 | 1,154 | 13,0× | 450 kB | 1 536 B/s |
| 4 200 s | 5,30 h | 5 | 5 | 10 | 6 | 0,437 | 5,54× | 2 385 kB | 640 B/s |
| 851 s | 0,28 h | 2 | 2 | 4 | 3 | 0,115 | 2,20× | 127 kB | 256 B/s |

Referencia **sin (h)**: 1 línea en el timekeeper, 0,0961 s/slot = **9,61 %** de un núcleo por nodo,
18,8 kB de justificación por bloque (R-FIN-14 (d), `S_max × 128 B`).

### C.2 · Latencia añadida — **cero con (P2), 18,4 % de `Δ` con (P1)**

Meter la cadena entera en la justificación de un bloque (**P1**) es `L·128 B`: **900 kB** con
`L = 2 h`, que a 10 Mbit/s son **0,74 s** de propagación extra para un bloque por época, un
**18,4 % de `Δ = 4 s`**. `Δ` es la variable de la que depende toda la frontera (46,9 % a 4 s;
**32,4 % a 20 s**, 9a), así que no es un detalle de ingeniería.

Vía **P2** —gossip de los `PotCheckpoints` según se calculan, como el PoT ordinario— el caudal es
**1 152 B/s** con `(I, F) = (851 s, 2 h)` y el bloque lleva 16 B de compromiso: **latencia añadida
cero**. **P2 es la única vía admisible**, y va a la regla (h.2b).

### C.3 · Presupuesto de un nodo completo, en núcleos continuos a `τ = 1 s`

| `I` | `F = L` | cadena principal | revelación (h) | total | % de un 9950X3D (32 hilos) |
|---:|---:|---:|---:|---:|---:|
| 851 s | 2 h | 0,0961 | **0,813** | **0,910** | 2,84 % |
| 300 s | 2 h | 0,0961 | **2,308** | **2,404** | 7,51 % |
| 851 s | 1 h | 0,0961 | 0,407 | 0,503 | 1,57 % |
| 851 s | 0,28 h | 0,0961 | 0,115 | 0,211 | 0,66 % |

En absoluto no es prohibitivo en una máquina de escritorio (2,8 % de un 9950X3D). Sí lo es como
**suelo de participación**: casi un núcleo dedicado, permanentemente, sólo a PoT.

### C.4 · Presupuesto del timekeeper

| `I` | `F = L` | disciplina (i) | (ii) `m = 1,83` | (ii) `m` máximo `1 + λ·S_max` |
|---:|---:|---:|---:|---:|
| 851 s | 2 h | **10** | 18 | **1 360** |
| 300 s | 2 h | **25** | 45 | **3 625** |
| 851 s | 1 h | 6 | 11 | 756 |

Y B.3.1 dice que **25 líneas caben en un 9950X3D con un 1,7 % de degradación**. Luego (i) y (ii) con
el menú medido son **un PC**; (ii) con el `m` máximo es **un centro de datos**. La regla (h.1)
**tiene** que acotar `m`.

### C.5 · La identidad que decide el punto D — **protección y coste son el mismo número**

```
ρ*  = (L + I)/(I + W_dec)          (B.1, verificado, 14 semillas)
coste de verificación = 1 + L/I    (B.2, medido)
⇒   ρ* = (1 + L/I) · I/(I + W_dec) ≈ el multiplicador de coste, con W_dec ≪ I
```

Comprobado en las seis filas de C.1: `(851, 2 h)` → `ρ* = 9,24` y coste 9,46×; `(300, 2 h)` → 23,44 y
25,0×; `(851, 1 h)` → 5,11 y 5,23×. **La razón es 0,977 en todas.** (h) no tiene palanca: cada punto
de tolerancia a `ρ` cuesta exactamente un punto de CPU de verificación en cada nodo de la red.

**Consecuencia práctica, y es la recomendación de calibración.** Dado un `ρ_max` que se quiera
tolerar, la `I` que lo iguala es `I* = (L − ρ_max·W_dec)/(ρ_max − 1)`:

| `ρ_max` | `L` | `I*` | `q` | `ρ*` comprobado | coste | núcleos/nodo | `I+F` |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1,5 | 2 h | 14 265 s (3,96 h) | 1 | 1,50 | 1,50× | **0,049** | 5,96 h |
| 2,0 | 2 h | 7 110 s (1,98 h) | 2 | 2,00 | 2,01× | **0,097** | 3,98 h |
| **2,5** | **2 h** | **4 725 s (1,31 h)** | **2** | **2,50** | **2,52×** | **0,147** | **3,31 h** |
| 3,0 | 2 h | 3 532 s (0,98 h) | 3 | 3,00 | 3,04× | 0,196 | 2,98 h |
| 2,5 | 1 h | 2 325 s (0,65 h) | 2 | 2,50 | 2,55× | 0,149 | 1,65 h |

**La calibración vigente (`I = 851 s`, `F = 2 h`) compra `ρ* = 9,24` y paga 0,813 núcleos por nodo.
El techo físico estimado del reloj AES es 1,5-2,5× (`pot-aes-asic-chacha.md` §3). Está pagando
5,5× de más por una protección que nadie va a necesitar.** Con `ρ_max = 2,5` basta `I = 4 725 s`:
**0,147 núcleos**, `q = 2` líneas en el timekeeper, y ningún cambio en la seguridad útil.

**Lo que se paga a cambio, dicho en voz alta:** `I + F` sube de 0,93 h a **3,31 h**. `I + F` es el
lookahead que un *plotter* rápido puede aprovechar (9c §D, margen económico frente a un plotter 10×).
**Es una bifurcación de calibración, no una consecuencia de (h), y la decide Katana:** CPU de todos
los nodos contra margen económico frente al plotter.

---

## D · Veredicto — ¿puede (h) ser núcleo del diseño?

### D.1 · Respuesta

> **Sí, puede ser núcleo — pero no con el texto que tiene, no por la razón que 9c dio, y no a la
> calibración vigente.** Con las seis piezas de §A.6 y `I` recalibrada, (h) es una regla sana, con
> precedente en producción y con un precio que se puede escribir en una línea. Sin ellas, tiene un
> agujero de vivacidad, un vector de partición y un coste 3,7× mayor del necesario.

**Lo que hay que corregir antes de que sea núcleo, en orden de gravedad:**

| # | Qué | Por qué | Coste de la corrección |
|---|---|---|---|
| 1 | **`entropía_j` es función de `past(B)`, no un mensaje publicado** (h.3) | Cualquier regla condicionada a «si la revelación está disponible» hace `flujo` dependiente de **cuándo llegó un mensaje** y parte el DAG entre honestos vía R-FIN-5 | ninguno; es una forma de escribirlo |
| 2 | **`Lrev = L − S_max`, no `Lrev = L`** (h.1b) | Con `Lrev = L` la disciplina (i) del timekeeper **no llega**: le falta `W_dec/L` = 0,62 % y no se compra con hardware, porque la carrera es contra su propia cadena en el mismo silicio | **1,8 % de `ρ*`** (9,24 → 9,07) |
| 3 | **`I ≤ (L − ρ_max·W_dec)/(ρ_max − 1)`** (h.6) | `ρ*` y el coste son el mismo número (§C.5). Con `I = 851 s` se compra `ρ* = 9,24` y se paga 9,46× cuando el techo físico estimado es 1,5-2,5× | `I + F` sube de 0,93 h a **3,31 h**: es una **bifurcación de calibración para Katana**, CPU de todos los nodos contra margen frente al *plotter* |
| 4 | **Publicar por gossip, nunca en bloque** (h.2b) | 900 kB en un bloque por época = **18,4 % de `Δ = 4 s`**, y `Δ` decide la frontera entera | ninguno |
| 5 | **Verificar una por época y en orden de slot aleatorio** (h.2c) | Sube la asimetría de 16,2× a **32,4×** | ninguno |

**Lo que hay que aceptar y escribir en voz alta si se adopta:**

- **El multiplicador `1 + L/I` sobre la verificación de PoT de *cada* nodo.** A la calibración
  vigente, **0,91 núcleos continuos** frente a 0,096. A la recomendada (`ρ_max = 2,5`), **0,24**.
- **El suelo de hardware de un lado de partición sube de 1 línea de AES a `q+1`.** Con `q+1 = 10` y
  4 núcleos, la revelación llega 3 h tarde con `F = 2 h`: **el lado muere con todo su espacio
  intacto**. Es un modo de fallo nuevo, contradice la letra de R-FIN-7 («tolerar una partición de
  hasta `F` con `≥ 9 %` del espacio») y **no se compensa con espacio**. A `ρ_max = 2,5` el suelo baja
  a **`q+1 = 3` líneas**, que es cualquier PC.
- **Sube la barrera de entrada del timekeeper ×(q+1)**, luego empeora `autonomys/subspace#2141` por
  centralización (no por velocidad: por velocidad no cambia nada).

### D.2 · Lo que (h) compra de verdad, y lo que 9c prometió de más

| | 9c §E.5 | Medido aquí |
|---|---|---|
| steering | «**0 para cualquier `ρ`**» | **0 hasta `ρ* = 9,24`** en régimen; residuo `α^(n*−1)` por debajo |
| adelanto | «la cota de conocimiento pasa a `I`» | `(L+I)(1−1/ρ)`, exactamente lo que dijo la **ronda 7** |
| a `ρ ≤ 2,5`, `α = 0,33` | — | `ḡ` por época **1,953 % → 0,007 %**, factor **279×** |
| a `ρ = 1` | «0» | **0 exacto** ✔ |

**9c §E.5 contradice a la ronda 7 y la ronda 7 tiene razón.** No es un matiz: es la diferencia entre
«(h) cierra el steering» y «(h) lo divide por 279 en el rango físico». La segunda sigue siendo un
argumento excelente para adoptarla; la primera habría llevado a calibrar `I` y `F` sobre una
garantía que no existe.

### D.3 · La contramedida más barata, si Katana no quiere pagar (h)

`ρ*` **sin** (h) es 1 (cualquier reloj más rápido acaba haciendo steering, tras un *bootstrap* de
`L/(ρ−1)`). Las tres palancas alternativas, con su precio:

| Palanca | `ρ*` que compra | Precio |
|---|---:|---|
| **(h) a `I = 4 725 s`** | 2,50 | 0,15 núcleos/nodo · `q+1 = 3` líneas · `I+F` = 3,31 h |
| **(h) a `I = 851 s`** (vigente) | 9,24 | 0,81 núcleos/nodo · `q+1 = 10` líneas · `I+F` = 0,93 h |
| **subir `I` sin (h)** | 1 (no cambia) | no compra `ρ*`; sólo diluye `n_eval = ρ·W_dec` como `1/√I` |
| **bajar `W_dec`** (acortar la ventana de decisión) | 1 (no cambia) | tampoco: `W_dec` la fija la carrera, no `S_max` (9c §C) |
| **admitir `ρ_max = 3` y no hacer nada** | — | `n_eval = 135`, `I = 851 s`, `F = 1,07 h`, margen 3,13× (9c §D.2, tabla ya calculada) |

**Recomendación de D8, marcada como tal:** si el objetivo es cerrar el steering, **(h) con las cinco
correcciones y `I` calibrada a `ρ_max = 2,5`**. Si el objetivo es no añadir una pieza de consenso,
**admitir `ρ_max = 3` sin (h)** es defendible y ya está cuantificado por 9c — pero entonces el
adelanto se queda en `L + I(1−1/ρ)` = 7 767 slots y la LAGUNA de retención selectiva (§B.6.4) se
queda entera, que es lo que (h) sí encoge 5,5×.

**Lo que ninguna de las dos arregla:** `ρ_max` sigue siendo una **ESTIMACIÓN** sin paper (§B.1.3), y
`Δ` sigue sin medir. Las dos son precondiciones de todo lo demás.

---

## Veredicto por punto

| Punto | Resultado | Etiqueta | Número que decide |
|---|---|---|---|
| **A** regla operativa | Escrita entera (h.1-h.6); retirada mi (h.3) del intento anterior, que rompía R-FIN-5 | **PLAUSIBLE** (regla candidata) · (h.3)-(h.5) DEMOSTRADO por construcción | `Lrev = L − S_max`: holgura 2,1 %, coste 1,8 % de `ρ*` |
| **B.1** reloj rápido | La cota `ρ ≥ L/W_dec` es **correcta para candidatos ajenos** y **ciega para el propio** | **VERIFICADO** (14 semillas, 4 000 épocas) + **DEMOSTRADO** (forma cerrada) | `ρ*` = **160 → 8,99**, factor **17,8×**; residuo `α^(n*−1)`, razón sim/cerrado 0,93-1,01 |
| **B.2** DoS de verificación | El ataque no existe; el coste honesto sí | **REFUTADO** (el ataque) · **VERIFICADO** (el coste) | asimetría **16,24×**, y **32,4×** verificando en orden aleatorio; coste honesto **0,813 núcleos** |
| **B.3** vivacidad | La CPU no es el problema; la barrera de entrada sí | **VERIFICADO** (microbanco propio, control contra Criterion) | **25 líneas de AES simultáneas → 1,7 % de degradación**; barrera ×(q+1) = 10 |
| **B.4** partición | **Vector nuevo, de hardware** | **VERIFICADO** (aritmética sobre B.3) · el vector de flujo, **REFUTADO** | con 4 núcleos y `q+1 = 10`, revelación **3 h tarde** con `F = 2 h`: lado muerto |
| **B.5** carrera de bloques | (h) **no** cambia la frontera de flujo único | **DEMOSTRADO** (`prev()` no contiene `ρ` ni el reto) + control idéntico | 46,8784 % / 36,5432 % reproducidos |
| **B.6** el adelanto | Cierra la LAGUNA «ráfagas»: la cota de la unión ya lo cubre | **REFUTADO** (daño a la frontera) · **VERIFICADO** (tamaño) · **LAGUNA** (retención selectiva) | una carrera **por segundo** durante 10 años cuesta **0,46 puntos**; el caso real, **< 0,08** |
| **C** coste | Protección y coste son el mismo número | **DEMOSTRADO** (identidad) + **VERIFICADO** (medida) | `ρ* = (1+L/I)·I/(I+W_dec)`, razón **0,977**; con `ρ_max = 2,5`, `I = 4 725 s` y **0,147** núcleos |
| **D** veredicto | **Sí puede ser núcleo, con cinco correcciones y `I` recalibrada** | — | el precio: **`1 + L/I`** por nodo y **`q+1`** líneas por lado de partición |

---

## Errores propios (regla de método 9)

**Del intento anterior de esta misma ronda, que quedó a medias y he revisado con ojo crítico:**

1. **Titular sobreafirmado.** Escribí «esa cota es **FALSA** y sobra un factor ~18×». **La cota es
   correcta** para el steering completo sobre candidatos ajenos (`ρ ≥ 160`, confirmado con 14
   semillas); lo que faltaba era **la rama del candidato propio**. Y no era un hallazgo mío contra
   9c: **la ronda 7 ya lo había escrito** (`ancla-de-finalidad.md:319-322`) y yo no lo había leído
   al escribirlo. *Cambió:* el titular entero y el marco de §B.1.
2. **A.1 mal leída.** «El timekeeper necesita ser un 0,63 % más rápido que el nominal, y el nominal
   ya es el tope del mercado» — el número es correcto, la lectura era falsa: `t_j` es un **índice de
   slot**, no un instante de pared, y la carrera es contra su propia cadena principal en el mismo
   silicio. *Cambió:* la palanca deja de ser «comprar una CPU más rápida» (imposible) y pasa a ser
   **`Lrev < L`** (§A.1, §B.3.c), que cuesta 1,8 % de `ρ*`.
3. **A.3 rota, y retirada.** Mi regla **(h.3) «continuidad por defecto»** —aplicar la inyección en el
   primer slot en que la revelación esté disponible **en `past(B)`**— hace `flujo` dependiente de
   **cuándo llegó un mensaje** y **parte el DAG entre honestos** vía R-FIN-5. *Cambió:* sustituida
   por **(h.3′) validez incondicional**, y con ella desaparece la pregunta «qué pasa si falta».
4. **Script con expresión muerta.** `r10a_b1_reloj.py` del intento anterior tenía
   `ent_ok = R - L/rho + L/rho <= t_dec ... else R <= t_dec`: **las dos ramas idénticas**. No
   cambiaba ningún número, pero es exactamente el tipo de cosa que `AUDITA_SCRIPTS.py` busca.
   *Cambió:* script rehecho de cero sobre `r10a_lib.py`.
5. **Recorte no declarado.** El intento anterior corría 400 épocas por semilla y no medía el
   *bootstrap*: lo recitaba. Ahora son **4 000** (39 días de red por semilla) y el *bootstrap* se
   **mide** (control C1, razón 1,000).

**De este intento:**

6. **Bug propio en el simulador, detectado por un control que falló.** Puse
   `E_hon = max(arr_hon, D)` en la rama **sin (h)**: hacía al atacante esperar a que **la red**
   decidiera el ancla, lo que daba `n_eval = 0` por construcción y hacía que el **control C3 diera
   `nan`** en las seis filas. Es un adversario más débil que el del paper (regla de método 8).
   *Cambió:* corregido a especulación sobre todos los candidatos; C3 pasó de `nan` a `ρ* = 1`, y la
   cota sin (h) pasó de `L − W_dec + I(1−1/ρ)` a **`L + I(1−1/ρ)`** — que es exactamente la de la
   ronda 7. **El control positivo pagó su precio.**
7. **Error de ±1 en la forma cerrada de las rachas.** `n* = ⌈n⌉ + 1` en vez de `⌈n⌉`, que daba tasas
   `α` veces más pequeñas. Detectado al contrastar con la simulación (razón 0,30 en vez de 1,00).
   *Cambió:* corregido; la razón sim/cerrado quedó en **0,93-1,01** en las filas con estadística.
8. **`boot90` medido desde un origen desplazado.** El simulador arranca con
   `paso[0] = t[0] = L`, y yo reportaba el instante absoluto: inflaba el *bootstrap* en `L` segundos
   (8,0 h en vez de 2,7 h a `ρ = 3`). *Cambió:* se resta `paso[0]`; ahora reproduce `x/(ρ−1)` con
   razón 1,000-1,021.
9. **Modelo de B.2.b incompleto en la primera pasada.** Suponía **siempre un solo slot malo**, con
   lo que la fila `p = 0` daba 348 s en vez de 0,10 s. *Cambió:* los slots malos son `L − p`, y con
   ello aparece el resultado bueno: verificar **en orden aleatorio** deja el ataque por prefijo largo
   en 0,18-1,02 s.
10. **Etiqueta de columna incorrecta.** B.2.a imprimía `L/I` bajo el rótulo del multiplicador
    `1 + L/I` (8,46 donde debía poner 9,46). *Cambió:* corregido en el script y en el informe.
11. **`c_interp` sin memoizar.** Cada llamada a `frontera_pot` recalculaba la integración de Simpson
    de 400 000 pasos de `d9-ronda8c/r8c_steering.py:20-34`. No cambió ningún número; hizo inviable
    la primera corrida de B.1. *Cambió:* `functools.lru_cache` en `r10a_lib.py`.

**Contaminación declarada, no error:** el microbanco de B.3 se midió con **otros dos agentes
corriendo en la misma máquina**. Por eso toma la **mejor de 5 corridas** (9 en el control) y reporta
la peor al lado; el control de 1 hilo contra Criterion (razón 0,950) dice que la contaminación
residual es pequeña hasta 25 hilos. Por encima de 32 hilos la degradación medida **incluye** a los
otros agentes y no debe leerse como propiedad del hardware.

## Lagunas que quedan abiertas (y qué haría falta para cerrarlas)

| Laguna | Por qué no se cierra aquí | Qué haría falta |
|---|---|---|
| **`ρ_max` real** | El estudio de Supranational que Autonomys cita **no está localizado** (LAGUNA heredada de `pot-aes-asic-chacha.md` §5). El 1,5-2,5× es una ESTIMACIÓN del principal, sin paper | Localizar el estudio, o un análisis de latencia de S-box en un proceso concreto |
| **Retención selectiva con información perfecta propia** (§B.6.4) | Ni `prev()` ni `r8c_sim.py` modelan una política de retención que consulte las victorias futuras del atacante | Añadir un oráculo de victorias futuras a `d9-ronda8c/r8c_sim.py` y medir `δ_ef` y la rentabilidad de la parásita con y sin él, 12 semillas |
| **Efecto de la barrera ×(q+1) sobre el número real de timekeepers** | No es medible sin red | Datos operativos, o una encuesta de hardware de granjeros |
| **`Δ`** | Heredada; sólo se mide con nodos corriendo | Nodos en red |
| **`m` con retención inflada** (9c §2, hallazgo de instrumento) | `W_dec` y `m` que uso vienen de 9c y arrastran ese aviso | Reproducir `r9c_c4_wdec.py` con la clausura de publicación en los simuladores de D8/D9-c..f |

---

## Auditoría de scripts (regla de método 10)

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d8-ronda10a/
Scripts analizados: 7

research/scripts/d8-ronda10a/r10a_b56_frontera.py
   [T3b] L84: ['base0', 'f0'] = MISMA expresión: frontera(hf0, 3 * K)
   [T3b] L85: ['baseD', 'fD'] = MISMA expresión: frontera(hfD, 3 * K)

research/scripts/d8-ronda10a/r10a_b5b_intentos.py
   [T3b] L59: ['b0', 'f0'] = MISMA expresión: frontera_factor(hf0, 1.0)
   [T3b] L60: ['bD', 'fD'] = MISMA expresión: frontera_factor(hfD, 1.0)

research/scripts/d8-ronda10a/r10a_c_coste.py
   [T3b] L87: ['nucleo_verif', 'rev'] = MISMA expresión: L * verify / I

research/scripts/d8-ronda10a/r10a_lib.py
   [T3b] L135: ['off', 'paso'] = MISMA expresión: [0.0] * (n_ep + 2)

======================================================================
Sospechas totales: 6
```

**Cada marca, leída.** Las seis son T3b («dos variables con el mismo lado derecho largo, y luego
comparadas»). Las seis son **falsos positivos**, y por dos motivos distintos:

| Marca | Lectura |
|---|---|
| `r10a_b56_frontera.py:84-85` (`base0`/`f0`, `baseD`/`fD`) | Misma **expresión**, distinto **estado global**: `f0` se calcula tras `set_F_I(19 080, 4 200)` (el control) y `base0` tras `set_F_I(F, I)` dentro del bucle. Dan 46,8784 % y 44,5722 % respectivamente en la salida, luego **no** son el mismo valor. No se comparan entre sí |
| `r10a_b5b_intentos.py:59-60` (`b0`/`f0`, `bD`/`fD`) | Idéntico caso: `f0` es el control a `(19 080, 4 200)`, `b0` la línea base de cada pareja `(F, I)` del bucle. Y `frontera_factor` **sí** recibe un parámetro distinto en las filas de la tabla (`factor`) |
| `r10a_c_coste.py:87` (`nucleo_verif`/`rev`) | La **misma magnitud impresa en dos tablas distintas** (C.1 y C.3), a propósito: en C.1 como columna de coste por nodo y en C.3 dentro del presupuesto total. Nunca se comparan; si difirieran, sería un error |
| `r10a_lib.py:135` (`off`/`paso`) | Dos arrays distintos que se inicializan igual: `off` son los offsets `slot(I_j) − T_j` en el modo `"cero"` y `paso` son los instantes de paso por barrera. Se llenan con contenidos completamente distintos y **nunca se comparan** |

**Lo que AUDITA no puede ver, y aquí sí se cumple (criterio complementario del propio fichero):**
todos los resultados **cambian con `α`**, y por tres vías independientes —`W_dec(α)` medida por 9c,
`m(α)` medida por 9c y `p_propia = α`—. La fila `α = 0,00` da **0** en las siete `ρ` de B.1.c, en las
nueve de B.1.e, en las 24 de B.6.b y en las dos columnas de B.6.d. **Contadores de cobertura de rama
(B.1, 4,03·10⁶ épocas simuladas):** `ancla_honesta` 3 203 118 · `ancla_propia` 828 882 ·
`bloqueado_entropia` 2 838 293 · `bloqueado_llegada` 1 193 707 · `steer_honesto` 1 060 919 ·
`steer_propio` 327 587 · `sin_steer` 1 031 450. **Ninguna rama a cero**: la comparación vale.

---

## Cómo reproducir

| Fichero | Qué produce | Coste |
|---|---|---|
| `r10a_lib.py` | la recursión de la frontera de PoT y las formas cerradas | — |
| `r10a_b1_reloj.py` → `salida_b1.txt` | B.1 entero, 3 controles, 14 semillas × 4 000 épocas | ~25 min con 32 hilos |
| `r10a_b2_dos.py` → `salida_b2.txt` | B.2, control C0 leído de Criterion | < 1 min |
| `r10a_b3_lineas.c` | microbanco de líneas AES; `gcc -O3 -maes -mavx2 -pthread` | — |
| `r10a_b34_vivacidad.py` → `salida_b34.txt` | B.3 y B.4; necesita el binario anterior (`R10A_BIN`) | ~3 min |
| `r10a_b56_frontera.py` → `salida_b56.txt` | B.5 y B.6, control contra `verif_frontera_vs_F.salida.txt` | ~45 min |
| `r10a_b5b_intentos.py` → `salida_b5b.txt` | B.5.b/B.5.c, sensibilidad al número de intentos | ~15 min |
| `r10a_c_coste.py` → `salida_c.txt` | C entero, incluida la calibración C.5 | < 1 min |

Fuentes de los dos costes unitarios: `/home/katana/zeo/fuentes/subspace/target/criterion/{prove,verify}/new/estimates.json`
(artefacto de `cargo bench -p subspace-proof-of-time` en esta máquina, 9950X3D).
