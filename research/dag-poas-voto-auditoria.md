# Voto en el rezago — auditoría D9 (cuarta ronda); D8 interrumpido por límite de sesión

**Fecha:** 2026-09-08 · Audita `dag-poas-voto-en-rezago.md` · D9 en Opus (completo); D8 en Opus
**terminado a medias por HTTP 429** (límite de sesión), sin informe. Scripts de D9 en el
scratchpad de la sesión (`d9/voto_*.py`). **P-038 sigue cerrada.**

## 0 · Veredicto

La cuarta propuesta aporta dos cosas nuevas y reales, y cae por una tercera:

**Nuevo y demostrado.** (1) Durante el rezago de inyección hay una sola lotería: verificado en
`sp-consensus-subspace/src/lib.rs:118-126` (la entropía se mezcla solo si
`parameters_change.slot == next_slot`). (2) **El recuento honesto converge, y rápido**: con retardo
heterogéneo `U(0,D)` por par bloque-nodo y atacante balanceando con α = 1/3, los votos honestos al
no líder son < 2 de 78 para cualquier V entre 20 y 120; no reaparece la cola de 101 s. (3) La
herencia del ganador repara «cadena seleccionada ⊆ azules» (con la condición de que el color por
ganador solo aplique desde `t_k + w + V + k_c`). (4) El candidato ganador siempre está en `past(b)`.
(5) Double dipping con época en tiempo: `α* = 0,469` a λ = 1, I = 600, **mejor** que el 0,438 de la
lineal; a λ = 0,1 no hay I que lo iguale.

**Refutado, y es lo que decide (D9 §2, «semilla divergente anclada», DEMOSTRADO).** El atacante
construye un bloque `b*` cuyo padre seleccionado es un bloque honesto de slot `s*` y cuyos padres
extra son su cadena privada. `past(b*)` es cerrado hacia abajo y por tanto **legal** (validez
absoluta). Dentro de ese cono todos sus votos son azules (los honestos posteriores a `s*` no están),
así que eligiendo `s* = max{s : H(s) ≤ A_a}` el candidato perdedor lidera en `past(b*)` y
`ganador(b*) = B`. La semilla abre un flujo B con handicap `h = máx(0, H − A_a)`, parte positiva de
una Skellam, determinísticamente `h = (1−2α)λV − αλk_c`. Y a partir de ahí vuelve íntegra la
refutación de la ronda 3: cubrir ambos flujos es dominante (la unicidad de billete no lo impide:
la cobertura usa slots distintos), ambos crecen a λ, deriva cero, recurrente. La semilla es viable
si `h ≤ F` (profundidad de finalidad). **Con V = 40 y α = 0, h ≤ 40 < F = 99: un solo granjero con un
billete siembra una partición viable.**

`V` necesaria para `P(semilla viable) ≤ 10⁻⁹` por inyección (λ = 1, k_c = 24): **372 slots** con
F = 0 (supuesto más optimista), **847** con F = 100, a α = 1/3. A λ = 0,1: **3 623**. Y como
`t_k = k·I` es público desde génesis, el lookahead es `V + k_c − D + I(1−1/v)` ≥ **393 s = 36×
Autonomys** (79× con F = 100), peor que la ronda 3 (33 s) y del orden de la ronda 2. Ploteo dirigido:
5,7-12,5 GiB/GPU medidos, 98-217 extrapolados.

Refutado también: la cota «α > 1/3» (doble conteo; el volteo directo exige `α ≥ V/(2V+k_c)`, pero
la semilla anclada funciona con α ≈ 0); «voto mecánico» (lo fija la elección de padres, y sin
atacante coincide con `argmin solution_distance` el 93 %: el voto es casi epifenómeno); la ceguera
`v_max < I/V` (la ganancia es continua en la fracción estimada: 2 % con v = 0,5, 4 % con v = 2);
steering del ganador ≥ 22 % de las inyecciones a α = 1/3, no modelado por φ_c.

**Dependencia de q:** ningún q supera a la cadena lineal. A q = 1, lookahead 393-868 s por un umbral
de double dipping que mejora 3 puntos. A q = 10, V = 3 623 y lookahead 332×.

## 1 · Lo que cuatro rondas dejan escrito

| Ronda | Idea | Qué mató |
|---|---|---|
| 1 · GHOSTDAG puro | inyección por posición ordinal | split honesto o multi-flujo (10 % → 52,6 %) |
| 2 · Inyección anclada | inyector a profundidad L, no fusión | lookahead ×95; validez relativa; sin curación |
| 3 · Candidatos por color | validez absoluta, color por flujo | cobertura racional de flujos → deriva cero (sin atacante) |
| 4 · Voto en el rezago | una lotería durante el rezago, voto mecánico | semilla anclada legal → dos flujos con handicap h; V ≥ 372 → lookahead ×36 |

El núcleo, ya con cuatro pruebas distintas: **hace falta un evento acordado a profundidad cero e
impredecible.** Una cadena lenta lo tiene (bloque 50j único el 94 %). Un DAG rápido no. Cada
sustituto (profundidad, color, voto) desplaza el desacuerdo a un sitio donde o cuesta lookahead o
lo destruyen los incentivos. **La única vía no lineal que no toca ese núcleo sigue siendo espina +
fardos** (`dag-nativo-poas-propuesta.md` §3): no inyectan, no pesan, no se fusionan, no hay dos
loterías que cubrir.

## 2 · Lo aprovechable, con independencia del DAG

- Convergencia de recuento con desempate determinista y realimentación de pluralidad: resultado
  limpio, reutilizable si algún día hace falta un voto on-chain entre candidatos nombrados.
- `α* = 0,469` a I = 600: si la lineal pasara la época de inyección a tiempo con I grande, ganaría
  3 puntos de umbral, pero P-039 ya fijó que `c` va en bloques y el lookahead manda.
- La condición `w + V + k_c < I` y la naturaleza inductiva del «rezago compartido» valen para
  cualquier rediseño futuro de la inyección lineal (P-039): una sola inyección pendiente a la vez.

## 3 · D8 pendiente

D8 no llegó a informar. Sus vectores (manipulación por padres, steering, retención en la banda,
sub-DAG con ganador minoritario como DoS, timekeepers, castigo por sector, poda) quedan sin
ejecutar. **No cambian el veredicto**: la refutación de D9 es matemática y suficiente. Si Katana
quiere el informe de D8 por completitud, lanzarlo en Sonnet 5 tras el reinicio del límite.

---

## Anexo A · Informe D9 (Opus), íntegro

He terminado. Informe.

---

# D9 — refutación de `dag-poas-voto-en-rezago.md` (cuarta ronda)

Scripts nuevos en `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/d9/`: `voto_handicap.py`, `voto_sim.py`, `voto_tasa.py`, `voto_ceguera_lookahead.py`, `voto_epifenomeno.py`.

## 0 · Veredicto

| Regla / afirmación | Veredicto |
|---|---|
| **Regla 1** (candidatos = azules en `[t_k, t_k+w)`) | **DEMOSTRADA como bien definida.** Corolario nuevo: el candidato más endosado siempre está en `past(b)` (cierre hacia abajo) |
| **Regla 2** (rezago compartido = una sola lotería) | **DEMOSTRADA en el código**, con **dos condiciones** que la propuesta no escribe: `w+V+k_c < I`, y ninguna divergencia previa |
| **Regla 3** (voto mecánico) | **REFUTADA como «mecánico»**: el voto lo fija enteramente la elección de padres, es gratis desviarse, y el resultado coincide con `argmin solution_distance` el **93 %** de las veces sin atacante (α=1/3: 71 %) |
| **Regla 4** (herencia del ganador) | **DEMOSTRADA** que repara la contradicción de la ronda 3 — **si** se añade que el color por ganador solo aplica desde `t_k+w+V+k_c`. Contraejemplo abajo |
| **Regla 5** (validez absoluta / rojo) | SOBREVIVE |
| **Regla 6** (unicidad de billete) | **DEMOSTRADA dentro del rezago**; **no acota nada fuera** — la cobertura de dos flujos post-cierre usa **slots distintos** y no dispara el castigo |
| **Regla 7** (peso/DAA/k=24) | Sin cambios respecto de la ronda 3 |
| §2 «deriva cero resuelta» | **REFUTADA** — no se resuelve, se **tarifa** en `h = (1−2α)λV − αλk_c` bloques de handicap |
| §2 «revelación tardía ⟹ α>1/3» | **REFUTADA en las dos direcciones** (volteo abierto: α≈1/2; semilla anclada: α≈0) |
| §2 «lookahead 3-5× Autonomys» | **REFUTADA** — `V+k_c−D+I(1−1/v)` ≥ **393 s = 36×**; peor que la ronda 3 (33 s) |
| §3 ceguera `v_max < I/V` | **REFUTADA como umbral** — la ganancia es continua en `n`; hay ganancia con `v = 0,5` |
| §3 double dipping | **CONFIRMADA y mejorada**: α\*=0,469 a I=600, λ=1. No es lo que rompe el diseño |

---

## 1 · ¿Una sola lotería durante el rezago? (pregunta 1)

**VERIFICADO EN CÓDIGO.** `sp-consensus-subspace/src/lib.rs:118-126` (@f8842d0):

```rust
if parameters_change.slot <= next_slot {
    slot_iterations = parameters_change.slot_iterations;
    if parameters_change.slot == next_slot {          // solo en el slot exacto
        seed = parent_output.seed_with_entropy(&parameters_change.entropy);
    } else { seed = parent_output.seed(); }
```

La entropía se mezcla **solo** si `parameters_change.slot == next_slot`. Antes del slot objetivo el flujo es `parent_output.seed()` sin más: **los desafíos son idénticos con independencia de qué candidato acabe ganando.** La observación §0 de la propuesta es correcta y es el primer hallazgo genuinamente nuevo de las cuatro rondas.

**Los rezagos NO son iguales en Autonomys.** `pallet-subspace/src/lib.rs:963-966`: `target_slot = pre_digest.slot() + 15`, donde `pre_digest` es el bloque `n` múltiplo de 50 — el instante depende del **slot del inyector**, luego dos candidatos dan dos instantes. La propuesta fija `t_k = k·I` y aplica en `t_k+w+V+k_c`, constante de reloj. **Es implementable** (es más simple: `PotParametersChange.slot` pasa a ser función del reloj), pero **cambia la semántica** y es exactamente la *Design choice 1* que nazar-pc rechazó en el hilo 1615 #3. Precio, formalizado en §7: el instante de cada barrera futura es público desde génesis, que es el error E2 de la ronda 2 reintroducido.

Dos condiciones que faltan escribir: (a) `w+V+k_c < I`, o hay dos inyecciones pendientes a la vez y el rezago deja de ser compartido (`const_assert!(INTERVAL > DELAY)`, `subspace-runtime/src/lib.rs:161`); (b) la propiedad es **inductiva**: si la inyección `k−1` divergió, durante el rezago de `k` ya hay dos flujos.

---

## 2 · Convergencia del recuento (pregunta 2) — el resultado central

**El recuento honesto SÍ converge, y rápido.** No reaparece la cola de 101 s. Medido (`voto_sim.py`, retardo **heterogéneo** `U(0,D)` por par bloque-nodo — el `D` uniforme de `d8b/ghostdag_sim.py` iguala todas las vistas honestas por construcción y habría dado un falso positivo; 400 réplicas por celda): los votos honestos al **no** líder son, con el atacante balanceando,

| λ=1 | V=20 | V=40 | V=60 | V=120 |
|---|---:|---:|---:|---:|
| α=0 | 0,16 | 0,21 | 0,23 | 0,19 |
| α=1/3 | 1,19 | 1,47 | 1,75 | 1,68 |

Menos de 2 votos de 78. **El desempate determinista a recuento cero rompe la simetría de golpe y la realimentación de pluralidad la mantiene.** Esto responde afirmativamente a la primera pregunta abierta de §4 y es un resultado a favor de la propuesta.

**Y sin embargo el diseño cae, por otra vía. DEMOSTRADO.**

*Teorema (semilla divergente anclada).* Sea `H(s)` el número de votos honestos al líder hasta el instante `s`, `Aa` el total de billetes del atacante en `[t_k+w, t_k+w+V+k_c)`. El atacante construye un bloque `b*` con `sp(b*)` = bloque honesto de slot `s*` y padres extra = su propia cadena privada. `past(b*)` es cerrado hacia abajo y por tanto legal (regla 5, validez absoluta). Dentro de `past(b*)` **todos sus votos son azules**: los bloques honestos posteriores a `s*` no están en `past(b*)`, luego el anticono de cada bloque suyo dentro de ese cono es vacío. Tomando `s* = max{s : H(s) ≤ Aa}`, el candidato B lidera en `past(b*)` y `ganador(b*) = B`. El handicap de peso es exactamente

$$h \;=\; \max(0,\;H - Aa),\qquad H\sim\text{Poisson}((1{-}\alpha)\lambda V),\quad Aa\sim\text{Poisson}(\alpha\lambda(V{+}k_c))$$

es decir, la parte positiva de una **Skellam**. Determinísticamente `h = (1−2α)λV − αλk_c`.

Verificado: `voto_sim.py` mide `h` sobre el DAG simulado y coincide con la fórmula a ±0,1 bloques en las 64 celdas (λ∈{1;0,1} × V∈{20,40,60,120} × α∈{0;0,1;0,25;1/3} × {balanceo, retención}).

**Consecuencia.** La semilla abre un flujo B con `h` bloques de desventaja. A partir de ahí vuelve **íntegra** mi refutación de la ronda 3: cubrir ambos flujos es estrictamente dominante (la regla 6 no lo impide, §6 abajo), ambos crecen a λ, la diferencia de peso es Skellam de **deriva cero** y es recurrente. Sin una regla de finalidad la semilla es viable para cualquier `h`. Con profundidad máxima de reorg `F` (SPEC `MAX_REORG_LENGTH = 99`), es viable si `h ≤ F` con probabilidad `(F−h)/F` (ruina del jugador).

**`V` necesaria para `P(semilla viable) ≤ ε` por inyección** (`voto_handicap.py`, Skellam exacta, `k_c=24`):

| λ=1 | F=0, 10⁻⁶ | F=0, 10⁻⁹ | F=100, 10⁻⁶ | F=100, 10⁻⁹ |
|---|---:|---:|---:|---:|
| α=0 | 13,8 | 20,7 | 156 | 173 |
| α=0,10 | 39,2 | 56,5 | 212 | 240 |
| α=0,25 | 115 | 166 | 402 | 470 |
| **α=1/3** | **254** | **372** | **703** | **847** |

Decaimiento exponencial confirmado: tasa `r = (√((1−α)λ) − √(αλ))²` por slot (0,0572 a α=1/3, λ=1; empírica 0,0588). A λ=0,1 todo se multiplica por 10: **V = 3 623 slots** a α=1/3, F=0.

**Contraejemplo directo a `V = 40`:** con `V=40`, λ=1, α=0 el handicap máximo es 40 bloques < F=100. **Un solo granjero con un billete en la ventana, sin ninguna cuota de espacio, siembra una partición viable.** No hace falta α=1/3 ni atacante: hace falta `λV > F`.

---

## 3 · Cota bizantina (pregunta 3)

**REFUTADA la derivación de §2.** «Margen honesto `(1−2α)λV` frente a votos del atacante `αλV`» **cuenta dos veces** los votos del atacante: `(1−2α)λV` ya los descuenta. La condición correcta de volteo directo es `α(V+k_c) ≥ (1−α)V`, esto es

$$\alpha^\* = \frac{V}{2V+k_c} \in [0{,}385,\;0{,}5)$$

(0,385 con V=40/k_c=24; 0,483 con V=372). El 1/3 es **conservador**, no la cota.

**Los votos retenidos y publicados en la banda `k_c`: son ROJOS en los conos honestos**, no azules. Un voto de slot σ liberado en el cierre tiene anticono ≈ `λ(close−σ) > k` y la regla 4 solo cuenta azules. Luego la revelación tardía **no puede voltear el recuento honesto, con ningún α**. Pero **sí es azul en el cono anclado del propio atacante** (§2): la fila «revelación tardía» de §2 acierta en la conclusión, por la razón equivocada, y no ve la ruta que sí funciona.

**Steering temprano: existe y es grande.** `voto_epifenomeno.py`, 800 réplicas/celda: `P(ganador = argmin solution_distance)` = 0,93 con α=0 y **0,71 con α=1/3** (λ=1, V=120, m=2). Un atacante que además *elige* destino lo hará al menos igual de bien: **desplaza el ganador en ≥22 % de las inyecciones a α=1/3, ≥16 % a α=0,25**. Es grinding de entropía sobre la cadena pública, que `φ_c` no modela (BDK ramifica solo en el árbol privado). Y la otra cara: con α=0 el resultado es el desempate determinista el 93 % de las veces, luego **el voto es casi epifenómeno** — su única función real es tarifar la divergencia con `h`, no «elegir».

---

## 4 · Herencia del ganador (pregunta 4)

**DEMOSTRADO que repara la contradicción de la ronda 3, con una condición que falta.** Con `ganador(b)=ganador(sp(b))` para `slot(sp) ≥ cierre`, `sp(b)` nunca puede discrepar de `b`, luego nunca es rojo por ganador: **«cadena seleccionada ⊆ azules» se conserva**. Determinismo: `ganador` es función de `past(b)` en ambas ramas.

**Contraejemplo a la versión literal:** `b` con `slot(sp(b)) < cierre` recuenta sobre `past(b)`; su hijo `b'` con `sp(b')=b` y `slot(b) < cierre` **también recuenta**, sobre `past(b') ⊋ past(b)`, y puede dar otro ganador — con lo que `sp(b')=b` sería rojo bajo la regla 5 y vuelve la contradicción. **Corrección:** el color por ganador solo se aplica a bloques con `slot ≥ t_k+w+V+k_c`; antes de esa marca hay un solo flujo y la discrepancia de recuento no significa nada.

**Mergeset con dos ganadores: sí, y es determinista.** `sp` con ganador A y otro padre con ganador B: `b` hereda A, los bloques de B en el mergeset son rojos allí. Consistente.

**Corolario positivo nuevo:** el candidato más endosado **siempre** está en `past(b)`. Un voto por C tiene C en su pasado; `past(b)` es cerrado hacia abajo. No hay el caso «gano un candidato cuyos datos no tengo».

---

## 5 · Ceguera (pregunta 5)

**REFUTADA como condición binaria.** Para saber qué candidato le favorece, el atacante **no necesita la época entera**: estima con los primeros `n` slots de cada flujo. Con `n = vV/m`, el valor de elegir el mejor de `m` es `E[máx] − media = c_m·√(αλn)`, y frente al ingreso de la época `αλI` la ganancia relativa es

$$g \;=\; \frac{c_m\sqrt{\alpha\lambda n}}{\alpha\lambda I},\qquad c_2 = 0{,}564,\; c_4 = 1{,}029$$

Continua en `n`, **sin umbral** (`voto_ceguera_lookahead.py`): con `I=600, V=372, m=4` y **`v = 0,5`** (la mitad del tiempo real) la ganancia ya es **2,0 %**; con `v=2`, 4,1 %. La condición `v_max < I/V` no protege de nada; lo que hay que acotar es `g`, y `g` solo baja como `1/√I`.

**Cuando los honestos están divididos**, la ganancia de un voto sesgado es `P(pivotal)·g`. Con la división honesta medida (<2 votos), `P(pivotal)` es pequeña — pero el atacante no necesita ser pivotal en el cono honesto: ancla el suyo (§2). El «voto sesgado» es la vía débil; la fuerte es la semilla.

---

## 6 · Double dipping con `t_k = k·I` (pregunta 6)

`voto_tasa.py`, punto fijo `α* = 1/(1+φ(α*λI))` con la ec. 39 de BDK:

| λ=1 | I=100 | I=200 | I=300 | I=400 | I=600 | I=1200 |
|---|---:|---:|---:|---:|---:|---:|
| c_a | 43,5 | 90,2 | 138 | 185 | 281 | 572 |
| **α\*** | 0,4349 | 0,4511 | 0,4587 | 0,4634 | **0,4691** | 0,4770 |

| λ=0,1 | I=100 | I=200 | I=300 | I=600 | I=1200 |
|---|---:|---:|---:|---:|---:|
| **α\*** | 0,3385 | 0,3761 | 0,3943 | 0,4199 | 0,4396 |

**Sí hay I que supera el 0,438 de la cadena lineal a λ=1: cualquier `I ≥ 200`.** A λ=0,1 hace falta `I ≥ 1 200` y aun así queda por debajo. **Y no dispara el lookahead por sí mismo** — el lookahead lo dispara `V`, no `I` (§7). Es la única afirmación de la propuesta que sale reforzada.

**El teorema que falta sigue faltando, sin cambios.** La fórmula publicada `β_c = e^{−λΔ}/(e^{−λΔ}+φ_c)` es de **cadena larga**: con Δ=4 s da `β₅₀ = 0,0141` a λ=1 y `0,3434` a λ=0,1. Empalmar `φ_c` con el crecimiento azul de GHOSTDAG sigue sin demostración. **RESPALDADO POR FUENTE EN CONTRA**, igual que en la ronda 3.

---

## 7 · Lookahead (pregunta 7)

**REFUTADA la fórmula `rezago − D`.** Como `t_k = k·I` está fijado por el reloj, el **instante** de cada barrera es público desde génesis; lo único desconocido es el contenido, que se conoce en el cierre (o en `t_k+w+D`, porque el líder ya está bloqueado — medido en §2). Estado estacionario, para cualquier `v > 1`:

$$\text{lead}_{\max} = (V + k_c - D) + I\,(1 - 1/v)$$

| V | k_c | I | v | lead | ×Autonomys | GiB/GPU (69,363 s medido) | GiB/GPU (4 s extrapolado) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 40 | 24 | 200 | 1,001 | 60 s | 5,5× | 0,87 | 15 |
| **372** | 24 | 600 | 1,001 | **393 s** | **36×** | 5,66 | 98 |
| 372 | 24 | 600 | 2 | 692 s | 63× | 9,98 | 173 |
| 847 | 24 | 1200 | 1,001 | 868 s | 79× | 12,5 | 217 |

Con la `V` que la convergencia exige, el lookahead es **36×–79×** el de Autonomys (11 s), es decir **peor que la ronda 3 (33 s, 3×)** y del orden de la ronda 2 (1 046 s, 95×). La fila «Lookahead: 3-5×» de §2 solo vale con `V ≈ 40`, y con `V = 40` el esquema está roto por §2.

---

## 8 · Dependencia de `q` (pregunta 8)

**No hay ningún q en el que supere a la cadena lineal.** A λ=1 (q=1): `V ≥ 372` (F=0) o `847` (F=100) ⟹ `I ≥ 406` u `881` (por `w+V+k_c < I`) ⟹ lookahead ≥ 393 s frente a 11 s de la lineal, para un umbral de double dipping (0,469) que apenas mejora el 0,438 de la lineal. A λ=0,1 (q=10): `V ≥ 3 623`, `I ≥ 3 700`, lookahead ≥ 3 647 s = **332×**, y α\*=0,42 < 0,438. Peor en las dos dimensiones.

---

## Cierre

**REFUTADAS.** §2 «deriva cero resuelta» (se tarifa, no se resuelve; *impacto: partición permanente con probabilidad `P(Skellam ≤ F)` por inyección*) · §2 «revelación tardía ⟹ α>1/3» (doble conteo; volteo directo α≈1/2, semilla anclada α≈0; *impacto: `V=40` es rompible por un granjero cualquiera*) · §2 y §4 «lookahead 3-5×» (36×–79×; *impacto: ploteo dirigido 5,7-12,5 GiB/GPU medidos, 98-217 extrapolados*) · §3 ceguera `v_max < I/V` (no es un umbral; ganancia 2-6 % con v≤2) · regla 3 «voto mecánico» (lo fija la elección de padres; 93 % ≡ `argmin solution_distance` sin atacante) · regla 4 en su forma literal (contraejemplo con `slot(sp) < cierre`; corrección dada).

**DEMOSTRADAS.** El rezago compartido es una sola lotería (código, `derive` mezcla solo en el slot exacto) · la regla 6 conserva el recurso **dentro** del rezago · la herencia repara «cadena ⊆ azules» con la condición añadida · el candidato ganador siempre está en `past(b)` · el recuento honesto converge en ~D y no reaparece la cola de 101 s · `h = máx(0, H−Aa)` y su ley Skellam.

**COTAS CORREGIDAS.** `V`: 20-60 → **372 (α=1/3, F=0, λ=1)**, **847 (F=100)**, **3 623 (λ=0,1)** · rezago `w+V+k_c`: 40-60 → **≥ 406** · umbral de volteo: 1/3 → **V/(2V+k_c) ∈ [0,385; 0,5)** · lookahead: `rezago−D` → **`V+k_c−D+I(1−1/v)` ≥ 393 s** · α\* double dipping: 0,459 (I=300) → **0,4587**; **0,4691 a I=600**; 0,3943 a λ=0,1, I=300 · candidatos del atacante `αλw`: correcto, pero la palanca no es el conteo sino el steering (≥22 % de las inyecciones a α=1/3).

**NO DEMOSTRADAS.** Que `P(semilla viable)` decaiga exponencialmente **con atacante adaptativo** (mi Skellam supone que reparte óptimamente entre balanceo y anclaje; lo simulé, no lo demostré) · que la cobertura de dos flujos sea racional con el coste real de IOPS/núcleo (heredada de la ronda 3, sigue siendo la única salida) · que el steering del ganador esté acotado (`φ_c` no lo cubre) · el empalme `φ_c` + crecimiento azul de GHOSTDAG (sin cambios).

**LO QUE NO PUDE VERIFICAR.** `F` real: uso `MAX_REORG_LENGTH=99` del SPEC como proxy; la finalidad de GHOSTDAG no está derivada en ningún sitio y `V` es lineal en `F` · `Dmax` (Δ=4 s otra vez) · `v` defendible para AES-NI (sin fuente, igual que en la propuesta) · el comportamiento con `m>4` candidatos encadenado a lo largo de varias inyecciones.

### Lo que habría que demostrar antes del SPEC

1. **Una regla que haga costoso anclar un cono divergente**, no solo que lo penalice con `h`. Mientras el ganador se calcule sobre `past(b)` y `past(b)` lo elija el productor, `h` es el único obstáculo y `h` es lineal en `V`.
2. Una **profundidad de finalidad `F` derivada** para GHOSTDAG con constantes. Sin ella `V` no es calculable, y `V` es el parámetro del que cuelga todo el diseño.
3. Que la cobertura de flujos no sea racional con el coste medido de IOPS (sigue siendo la única refutación de mi refutación).
4. `φ` con steering del ganador público (≥22 % de las inyecciones a α=1/3).
5. Regla 4 reescrita con la marca `slot ≥ t_k+w+V+k_c` para el color por ganador.

### Valores que salen

`V = 372` slots (λ=1, α=1/3, ε=10⁻⁹, **F=0**, que es el supuesto más optimista posible) o `V = 847` con F=100. `w ≥ 2D = 8`. `k_c ≈ k/λ = 24`. `I > w+V+k_c` ⟹ **`I ≥ 406`** u `881`. Con esos valores: α\*(double dipping) = 0,469-0,475, lookahead 393-868 s. **A λ=0,1 no hay valores**: `V = 3 623` implica `I ≥ 3 700` y un lookahead de 332×.

### ¿Responde a mi refutación de la ronda 3?

**No. La aplaza y le pone precio.** El rezago compartido es real y la unicidad de billete conserva el recurso **mientras dura**, que es más de lo que consiguió ninguna de las tres anteriores. Pero en el cierre el atacante puede anclar un cono legal donde gana el otro candidato, y a partir de ahí vuelven dos loterías, cobertura dominante y deriva cero, exactamente como en la ronda 3. Lo único que se ha ganado es que la semilla nace con `h = (1−2α)λV` bloques de retraso, y hacer `h` grande cuesta `V` grande, y `V` grande cuesta lookahead.

**Más cerca en el mecanismo, más lejos en el precio.** Es la primera propuesta que produce **convergencia honesta demostrable y rápida** (menos de 2 votos desviados de 78 con α=1/3), y la primera que repara «cadena ⊆ azules» sin efectos colaterales. Eso es suyo y es real. Pero convierte el problema de la ronda 3 en un intercambio explícito entre `V` y el lookahead, y ese intercambio sale peor que la ronda 3 (393 s frente a 33 s) y con la misma conclusión de las cuatro: **hace falta un evento acordado a profundidad cero e impredecible, y el reloj no lo da**. La vía que no toca ese núcleo sigue siendo **espina + fardos** (`dag-nativo-poas-propuesta.md` §3).
