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
