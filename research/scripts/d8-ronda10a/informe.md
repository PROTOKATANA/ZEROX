# D8 — Ronda 10a: romper la **revelación retardada por VDF**, R-FIN-14 (h)

**Agente:** D8 (adversarial), Opus 5 · **Fecha:** 2026-09-08 · **Método:** `research/scripts/METODO-AGENTES.md`
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
> **Lo que lo hunde como núcleo no es el reloj: es el coste.** (h) multiplica por **`1 + L/I` = 9,46**
> la verificación de PoT de **cada nodo** (0,91 núcleos continuos frente a 0,096) y por **`q+1` = 10**
> las líneas de AES del timekeeper — y, sobre todo, **un lado de partición sin esas 10 líneas queda
> muerto aunque conserve todo su espacio** (§B.4). Veredicto en §D.

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
