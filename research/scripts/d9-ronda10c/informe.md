# D9 — Ronda 10c: qué compra de verdad una `F` corta (el sembrador, la pinza del *steering*, el usuario)

**Fecha:** 2026-09-08/09 · **Agente:** D9 (Opus 5) · **Directorio:** `research/scripts/d9-ronda10c/`
**Encargo:** `ENCARGO.md` · **Método:** `research/scripts/METODO-AGENTES.md` (sin presupuesto de tiempo).

**En una línea.** Bajo R-FIN-14 el lookahead real es **`(F − W_dec) + I·(1 − 1/ρ)`** en el núcleo y
**`I·(1 − 1/ρ)`** con la opción (h) — las dos **cero si `ρ ≤ 1`**. El argumento del sembrador
**sobrevive intacto para cualquier `ρ > 1` con paciencia** (no se reduce a `I`, como se sospechaba),
**desaparece con `ρ ≤ 1`** y **se hunde a `I(1−1/ρ)` con (h)**. La pinza `F ≥ I/(W/κ − 1)`
**no es un artefacto, pero su número sí lo es**: el `W` correcto no es `F + I`, y la pinza cae de
1,07 h a **0,33-0,69 h** (núcleo, `ρ = 1,5`-3) y a **0,13 h** con (h). Y para el **usuario**, `F = 1 h`
frente a `2 h` **no vale nada**: el riesgo del comerciante no depende de `F` en absoluto y ya está por
debajo de `10⁻⁹` a los **217-2 406 s** según `α` y modelo.

**Y un hallazgo que el encargo no pedía (§E):** el lookahead depende de **`L`** (el rezago de
aplicación de la inyección), **no de `F`** — y hoy el diseño los ata. Desatándolos,
**`L = 1 h`, `F = 2 h`** da el margen de sembrador de `F = 1 h` (**3,6×**), la frontera y la garantía
de `F = 2 h`, **y cumple la condición literal de BDK (`W/κ = 0,576 ≤ 1`) sin segundo VDF**. Se paga
en tolerancia a particiones (2 h → 1 h). Importa porque, **atados**, `F = 1 h` deja al umbral
operativo del 33 % con **0,05 puntos** de colchón en el modelo pesimista (frontera 33,05 %) frente a
los **2,08** de `F = 2 h` (35,08 %) — medido en §C.2.

---

## Índice

- [Controles (regla 4)](#controles)
- [A · El lookahead real bajo R-FIN-14](#a)
- [B · La pinza `F ≥ I/(W/κ − 1)`](#b)
- [C · Lo que espera el usuario](#c)
- [D · Tabla configuración × término → `F`](#d)
- [E · `L` desatada de `F`: la palanca que faltaba](#e)
- [Recomendación](#reco)
- [Auditoría de scripts](#auditoria)
- [Veredicto](#veredicto) · [Errores propios](#errores)

---

<a name="controles"></a>
## Controles (regla de método 4) — `r10c_c0_control.py`, `salida_c0.txt`

Antes de medir nada, reproducir números publicados **con el mismo instrumento**. `prev`,
`delta_interp`, `union10` y `frontera` se **importan** de `d9-ronda9a/r9a_a3_frontera.py`, que a su
vez es literalmente `research/scripts/verif_constantes.py:44-50` y
`d8-ronda8/d8_a1c_riesgo.py:29-40`. **No se reescribe ningún modelo.**

| Control | Publicado | Reproducido | |
|---|---|---|---|
| P1 · `verif_constantes.py` §3, reversión 600 s, `α = 0,25` | `k=18`: 2,45e-7 · `k=24`: 6,59e-8 · `k=30`: 1,11e-7 · `k=793`: 1,000 | 2,446e-7 · 6,590e-8 · 1,115e-7 · 1,000 | **OK** |
| P2 · `d8-ronda8/salida_a1c.txt:17`, `α = 0,33`, `δ = 0,2867` | reversión 600 s **5,538e-01**, unión 10 años **2,059e-103** | 5,538e-01 · 2,059e-103 | **OK** |
| P3 · frontera de flujo único (9a A3), `F = 19 080 s`, `I = 4 200 s` | 46,8784 % (`δ=0`) · 36,5431 % (`δ` D8) | 46,8784 % · 36,5431 % | **OK** |
| N1 · negativo, `α = 0` | 0 | 0,000e+00 | **OK** |
| P4 · criterio de variación del instrumento nuevo | — | el lookahead cambia con `ρ` (0 ↔ saturado), con `F` (núcleo) y **no** con `F` bajo (h) | **OK** |

<a name="a"></a>
## A · El lookahead real bajo R-FIN-14 — `r10c_a1_lookahead.py`, `r10c_a2_ancla_mc.py`

### A.0 · Qué se mide, y con qué dos instrumentos

«Lookahead» aquí es **cuántos slots por delante del reloj de consenso conoce alguien el reto de un
slot**. Bajo R-FIN-14 (b) `reto(f,s) = blake3(blake3(salida(f,s)) ‖ LE64(s))` y
`salida(f,s) = AES^N(salida(f,s−1))`: **conocer el reto de `s` exige haber calculado `s`**. Luego el
lookahead **es** la posición de la cadena de PoT que uno tiene, menos el reloj.

Dos instrumentos de la misma cinemática, uno valida al otro (`salida_a1.txt`, bloque A0):

| | qué hace |
|---|---|
| `cinematica` | paso a paso, **1 s de reloj por paso**, sin ninguna forma cerrada |
| `cinematica_rapida` | integrador exacto por ventana de inyección (resuelve el corte de dos rectas) |

**Peor discrepancia relativa entre los dos: 0,274 %** (el resto es la discretización `dt = 1 s`).
VALIDADO. Solo después se contrastan las formas cerradas.

### A.1 · El resultado, con las dos formas cerradas (VERIFICADAS por simulación)

```
NÚCLEO (R-FIN-14 a-g):   lookahead_max = (L − 1 − W_dec) + I·(1 − 1/ρ)      si ρ > 1;  0 si ρ ≤ 1
                         lookahead_medio = (L − 1 − W_dec) + I·(1 − 1/ρ)/2
OPCIÓN (h) retardada:    lookahead_max = I·(1 − 1/ρ)                        si ρ > 1;  0 si ρ ≤ 1
                         lookahead_medio = I·(1 − 1/ρ)/2                     — INDEPENDIENTE de F
```
con `L = F` (R-FIN-2 y R-FIN-7: `t_j = slot(I_j) + L`). En la rejilla completa
(`α ∈ {0; 0,10; 0,25; 0,33; 0,40}` × `ρ ∈ {0,5; 1; 1,001; 1,05; 1,2; 1,5; 3; 10}` ×
`F ∈ {0,34; 1; 2; 5,3} h` × `I ∈ {491; 602; 851} s`) **la simulación reproduce las dos formas
cerradas sin una sola discrepancia** (`grep -c DISCREPA salida_a1.txt` = 0).

> **Corrección al enunciado del encargo.** El encargo escribe «adelanto `L(1 − 1/ρ)` acotado por la
> inyección». **El factor `(1 − 1/ρ) multiplica `I`, no `L`**, y hay además un término aditivo
> `(L − W_dec)` que **no depende de `ρ`**. `L(1 − 1/ρ)` sería lo correcto si la cadena de PoT se
> reiniciara en cada `t_j` y el atacante tuviera que recorrer los `L` slots desde cero cada época —
> que es exactamente lo que hace **(h)**, pero con `I` en lugar de `L`, porque bajo (h) el bloqueo
> está en `t_j` y no en `T_j`. En el núcleo **no hay reinicio**: el atacante se queda pegado al tope
> de conocimiento y solo lo pierde si deja de calcular.

**Por qué el mecanismo es ese.** En el núcleo el atacante conoce `entropía_j` en `T_j + W_dec` (el
ancla ya no puede cambiar, 9c C.0) pero esa entropía **se aplica `L` slots más tarde**: puede
encadenar AES hasta `t_{j+1} − 1`, es decir, hasta `L + I − W_dec` por delante. Esa frontera avanza
a 1 slot/s de media, así que **no lo alcanza nunca si `ρ ≤ 1`**, y si `ρ > 1` lo alcanza y ahí se
queda, en diente de sierra. Con (h) la entropía **no existe** hasta `t_j`, así que la frontera está
siempre a `≤ I` y su ventaja **se resetea en cada inyección** — es exactamente el *«the advantage is
reset»* que Autonomys reclama para su PoT (`research/pot-aes-asic-chacha.md:47`) y que el núcleo de
ZEROX **no tiene**.

### A.2 · Las tres respuestas del encargo

| Quién | Lookahead (`F = 2 h`, `I = 851 s`, `α = 0,33` ⇒ `W_dec = 20 s`) | Etiqueta |
|---|---|---|
| **Granjero honesto, `ρ = 1`** | **0 slots.** Conoce el reto del slot `s` en el slot `s`, ni antes | **DEMOSTRADO** (R-FIN-14 b) + VERIFICADO |
| Atacante `ρ = 1,5` | **7 462,7 s = 2,073 h** (medio 7 320,8 s), *bootstrap* **4,01 h** | VERIFICADO |
| Atacante `ρ = 3` | **7 746,3 s = 2,152 h** (medio 7 462,7 s), *bootstrap* **1,06 h** | VERIFICADO |
| Atacante `ρ = 1,05` | **7 219,5 s = 2,005 h**, *bootstrap* **39,95 h** | VERIFICADO |
| Atacante `ρ = 1,001` | **7 179,9 s = 1,994 h**, *bootstrap* **1 994 h = 83 días** | VERIFICADO |
| **Con (h), cualquier `F`** | `ρ=1,5`: **283,3 s** · `ρ=3`: **566,7 s** · `ρ=10`: **765,0 s** | VERIFICADO |

**El hallazgo que decide todo: el término `(F − W_dec)` NO escala con `ρ`.** Es un acantilado, no una
rampa: `ρ = 1` da 0 y `ρ = 1,001` da el **99,7 %** de lo que da `ρ = 10`. Lo único que compra `ρ`
grande es **acortar el *bootstrap*** (83 días → 13 min). Un atacante paciente con un reloj
marginalmente más rápido tiene el lookahead entero.

> **Convergencia con la ronda 2, que ya lo había derivado.** `dag-poas-inyeccion-auditoria.md:126,157`
> escribe la fórmula exacta `lead = L + g − D + I(1−1/v)` y avisa: *«con `v = 1+ε` el lookahead sigue
> siendo `L−D ≈ 15 min`: no hace falta un VDF rápido, basta uno marginalmente más rápido y
> paciencia»*. Es **la misma forma** que mi cinemática, con `W_dec` en el papel de `D`. Lo que
> R-FIN-14 cambia respecto a aquella ronda es **el caso `v = 1`**: allí valía `L − D` sin más (el reto
> era función de la entropía, evaluable de golpe); aquí vale **0**.

### A.3 · Origen de «lookahead `I + F`» y de «margen B, plotter 10×» — trazados

| Pieza | Dónde nace | Estado |
|---|---|---|
| `lookahead = L + I(1−1/v) ≤ L + I` | `dag-poas-ancla-de-finalidad.md:188` (ronda 7 §5.1) | **La cota `L+I` es el rincón `v → ∞`.** Correcta como cota, **8 % holgada** a `ρ=1,5` (7 463 s frente a 8 051 s) y **ciega al acantilado**: esconde que `v=1` da 0 |
| `W = (L + I)·λ` en la ventana de predicción | `dag-poas-ancla-de-finalidad-metaauditoria.md:215-222` | Hereda el rincón `v → ∞`. Ver B |
| `I + F` como lookahead publicado (8,26 h → 0,76-1,31 h) | `dag-poas-ancla-de-orden-auditoria-8c.md:80-85`, 9c §C.3 | **Sobrevive como cota**, sobra un 4-8 % |
| `A* = 41 h` (esc. B, GPU tope ALU) y `A*/10 = 4,1 h` | `dag-poas-ancla-de-finalidad.md:54-70`; `t_plot = 4,28 s` de `research/coste-ploteo-medido.md:231` | **Sobrevive sin cambios** (no depende del consenso) |
| «margen B, plotter 10×» = `A*_10× / (I+F)` | 9c §D.2/C.3, auditoría 8c §3 | **Sobrevive**, y mejora un 4-8 % al usar el lookahead exacto |

### A.4 · ¿Puede el sembrador sembrar a tiempo? — con número

`research/coste-ploteo-medido.md`: ploteo **medido** 69,363 s/sector (GTX 1070) y 83,608 s (CPU 32
hilos); **extrapolado** a GPU tope 2026 **4,28 s** (ALU-bound) y 9,92 s (ancho de banda). A 4,28 s
son **841,1 GiB/h por GPU**. El espacio que puede fabricar *y probar* es `lookahead / t_plot`:

| Ventana del sembrador | Sectores de 1 GiB probables por GPU | TiB |
|---|---:|---:|
| **`ρ ≤ 1`, núcleo Y (h)** | **0,0** | **0,0000** |
| 1 slot (solo el reto actual) | 0,2 | 0,0002 |
| (h), `ρ = 1,5`, `I = 851 s` | 66,2 | 0,0646 |
| (h), `ρ = 3`, `I = 851 s` | 132,4 | 0,1293 |
| núcleo, `ρ = 1,5`, `F = 1 h` | 902,5 | 0,8813 |
| núcleo, `ρ = 3`, `F = 1 h` | 968,8 | 0,9461 |
| núcleo, `ρ = 1,5`, `F = 2 h` | 1 743,6 | 1,7027 |
| núcleo, `ρ = 3`, `F = 2 h` | 1 809,9 | 1,7675 |

Y el margen frente a `A*` (esc. B, el que **favorece al atacante**), `α = 0,33`:

| `F` | `ρ = 1` | `ρ = 1,5` | `ρ = 3` | con **(h)**, cualquier `ρ ≤ 3` |
|---|---:|---:|---:|---:|
| 0,34 h | ∞ | 9,93× | 8,34× | 26,0-52,1× |
| **1 h** | **∞** | **3,82×** | **3,56×** | **26,0-52,1×** |
| **2 h** | **∞** | **1,98×** | **1,91×** | **26,0-52,1×** |
| 5,3 h | ∞ | 0,76× | 0,75× | 26,0-52,1× |

**Conclusión A (etiqueta por caso):**
- Con **`ρ ≤ 1`**, el sembrador **no puede sembrar nada**: no conoce ni un reto futuro. El argumento
  «F corta contra el sembrador» **desaparece**. — **DEMOSTRADO** (secuencialidad de R-FIN-14 (a)/(e),
  verificada en el código de Autonomys por 9c §B.2) **+ VERIFICADO** (cinemática).
- Con **`ρ > 1`**, el sembrador **sí siembra**, y con casi todo el lookahead `≈ F`, sólo que tras un
  *bootstrap* de 1 h a 83 días. Con `F = 2 h` el margen frente al plotter 10× es **1,91-1,98×**; con
  `F = 1 h`, **3,56-3,82×**. **El argumento SOBREVIVE y acortar `F` casi duplica el margen.** —
  **VERIFICADO**.
- Con **(h)**, el lookahead deja de depender de `F` y el margen es **26-52×** para todo `ρ ≤ 3`.
  **El argumento desaparece por otra vía.** — **VERIFICADO** (la cinemática; el coste del VDF extra
  sigue **sin medir**, PLAUSIBLE, como lo dejó 9c E.5).
- ¿Es `ρ > 1` real? `research/pot-aes-asic-chacha.md:38-50`: un 19× **no es físicamente alcanzable**
  (exigiría 25 ps por ronda AES); la estimación propia del principal para un ASIC de latencia es
  **~1,5-2,5×**, y Autonomys cita a Supranational (*«no significant speedup … even with an ASIC»*,
  estudio **no leído**, LAGUNA menor). Con `ρ_max ∈ [1,5; 2,5]` **el argumento del sembrador vive**.

### A.5 · Parte estocástica (regla 5) — `r10c_a2_ancla_mc.py`, `salida_a2.txt`

La cinemática supone `slot(I_j) = T_j`. En realidad `δ_ancla = slot(I_j) − T_j ≥ 0` y desplaza `t_j`,
o sea desplaza el tope de conocimiento slot a slot. Se **mide** con el simulador de 9c
(`r9c_lib.MundoR9`, con R-FIN-1a como regla de validez y la clausura de publicación),
**12 semillas literales** `[11,23,37,41,59,67,73,89,97,101,113,127]`, `T_j ∈ {200,400,600,800,1000}`,
`S_max ∈ {20,150}`:

| `α` | `δ_ancla` media / p90 / máx (sin retención) | con el atacante reteniendo **todos** sus bloques |
|---:|---|---|
| **0,00** | 2,00 / 4 / **6** | 2,00 / 4 / **6** |
| 0,10 | 1,58 / 4 / 6 | 2,33 / 5 / 6 |
| 0,25 | 1,22 / 4 / 7 | 2,77 / 5 / 8 |
| 0,33 | 1,23 / 4 / 7 | 2,90 / 6 / 8 |
| 0,40 | 1,05 / 4 / 7 | **3,25 / 7 / 10** |

Criterio `α`: la media **crece monótonamente con `α`** en la columna con retención (2,00 → 3,25) y el
máximo, de 6 a 10 s. Idéntica con `S_max = 20` y con `150` (coherente con 9c C.2). Propagado al
lookahead con el peor valor medido (10 s): **+0,13 % a `F = 2 h`, +0,26 % a `F = 1 h`**. **Despreciable.**

**Cobertura de rama** (`COB` de `r9c_lib`, acumulada): `bloques_h = 225 575`, `bloques_a = 30 828`,
`retenidos = 30 828`, `clausura_publicacion = 44 388`, `sp_filtrado_h = 3`, `sin_sp_h = 9`.
**No ejercitadas, se declaran:** `sp_filtrado_a = 0`, `sin_sp_a = 0`, `liberados = 0`, `tips_pub = 0`
y `rfin1a_ok = 0` (la política `tips_pub` no llega a ejecutarse cuando el retraso es `None`: el
bloque se retiene antes; y R-FIN-1a se comprueba en `r9c_c0`, 751 053 aristas, 0 violaciones).

<a name="b"></a>
## B · La pinza `F ≥ I/(W/κ − 1)` — `r10c_b_pinza.py`, `salida_b.txt`

### B.1 · Qué es `W/κ`, y de dónde sale el 1,22

BDK+19 Def. 6 (`research/fuentes/bdk19.txt:2299-2312`): un protocolo es **`W`-predecible** si un
minero puede, **en el instante `t`**, producir ya un bloque válido para una cadena que aún no
existe y que se extenderá `W − 1` bloques. `W` **se mide en bloques**. El ataque de §D.3
(`bdk19.txt:2315-2340`) es un **soborno encubierto** a los líderes que *saben* que les tocará: exige
`W > κ`, con `κ` la profundidad de confirmación, y funciona *«bribing … an arbitrarily small total
stake»*. **El umbral del paper es `W/κ ≤ 1`, no 1,22.**

La identidad publicada `W/κ = 1 + I/F` sale de tomar `W = (L + I)·λ` con `L = F`
(`dag-poas-ancla-de-finalidad-metaauditoria.md:215-222`, tabla `q=1`: `κ = 201`, `W = 703`,
`W/κ = 3,50`). Reproducido (`salida_b.txt` B1): `F = 3,2 h`, `I = 2 490 s` → **1,2161** (publicado
1,22); `F = 3 600 s` → 1,6917 (publicado 1,69); `F = 1 000 s` → 3,4900 (publicado 3,49). **El
instrumento reproduce lo publicado.**

**De dónde sale el 1,22, exactamente.** De `dag-poas-ancla-de-finalidad-metaauditoria.md:786-795` y
`dag-poas-ancla-de-orden.md` §1.3: es **el valor que salió** al fijar `g = 3,6 %` (⇒ `I = 2 490 s`)
y `F = 3,2 h` (la rama `k = 793` de la ec. (2)), y que la propia propuesta etiqueta *«Es una
elección, no una derivación»* (§4.3). **No es un umbral de BDK.** Y hay un tell aritmético:

> **OBSERVACIÓN 1 (DEMOSTRADA).** `W/κ = 1 + I/F > 1` para **toda** `I > 0` y **toda** `F`. Bajo esa
> lectura de `W`, la condición de BDK (`W ≤ κ`) es **insatisfacible por construcción**. Un criterio
> que ningún diseño puede cumplir no está midiendo el diseño: está midiendo el modelo de `W`.

### B.2 · `W` recalculada con R-FIN-14

`W` no lo fija la época: lo fija **quien tenga el reloj de PoT más rápido y comparta su cadena** con
los sobornables — un sobornado a `ρ = 1` no sabe si ganará, pero el sobornante a `ρ > 1` **puede
publicarle** los `PotCheckpoints` adelantados y entonces el sobornado audita sus parcelas contra
retos futuros. Así que `W = lookahead_max(ρ_max)·λ` (A.1). Con `I = 851 s`, `α = 0,33`:

| Config | `ρ` | lookahead (s) | `W/κ` a `F=0,34 h` | `1 h` | `2 h` | `5,3 h` |
|---|---:|---:|---:|---:|---:|---:|
| Núcleo | **≤ 1** | **5** (solo el retardo de autoría `D=4 s`) | 0,0041 | 0,0014 | **0,0007** | 0,0003 |
| Núcleo | 1,024 | 1 223 | 0,9992 | 0,9997 | 0,9999 | 0,9999 |
| Núcleo | 1,05 | 1 243,5 | 1,0160 | 1,0054 | 1,0027 | 1,0010 |
| Núcleo | 1,5 | 3 862,7 / 7 462,7 | 1,2146 | 1,0730 | **1,0365** | 1,0138 |
| Núcleo | 3 | 4 146,3 / 7 746,3 | 1,4464 | 1,1518 | **1,0759** | 1,0286 |
| **(h)** | 1,5 | 283,3 | 0,2315 | 0,0787 | **0,0394** | 0,0148 |
| **(h)** | 3 | 566,7 | 0,4630 | 0,1574 | **0,0787** | 0,0297 |

> **Nota sobre el `W = 5` de la fila `ρ ≤ 1`.** Es la lectura **conservadora**: `1 + λ·D` con
> `D = 4 s`, el `BLOCK_AUTHORING_DELAY` de Autonomys (ZEROX **no ha fijado `D`**; R-FIN-14 (d) lo
> nombra y no le pone valor: LAGUNA menor). La lectura **estricta** es `W = 1`: en el instante `t` el
> granjero tiene el PoT hasta `t`, así que puede producir el bloque del slot `t` y **ninguno
> posterior**; el retardo de autoría desplaza la publicación **hacia atrás**, no el reto hacia
> delante (9c §B.3: el granjero reclama `slot_probado − D`). Con `W = 1` la razón es aún 5× menor.

**Con `ρ ≤ 1` el diseño está tres órdenes de magnitud DENTRO de la zona segura de BDK**, no un 22 %
fuera. Y el cruce `W = κ` ocurre en `ρ = 1/(1 − W_dec/I) = 1,024` con `I = 851 s`: por debajo de esa
velocidad de reloj **la condición del paper se cumple estrictamente**, para cualquier `F`.

### B.3 · La pinza corregida

De `W/κ = 1 + (I(1−1/ρ) − W_dec)/F` (núcleo) y `W/κ = I(1−1/ρ)/F` (con (h)):

```
NÚCLEO :  F ≥ (I(1−1/ρ) − W_dec) / (tope − 1)      y NO EXISTE si  I(1−1/ρ) ≤ W_dec
(h)    :  F ≥  I(1−1/ρ) / tope
```

| `tope W/κ` | `I` | `ρ` | `F` pinza NÚCLEO | `F` pinza con (h) | publicada `I/(tope−1)` |
|---:|---:|---:|---:|---:|---:|
| 1,22 | 851 | ≤ 1,024 | **no existe** | 16 s | 3 868 s (1,07 h) |
| 1,22 | 851 | 1,5 | **1 198 s (0,33 h)** | 233 s (0,06 h) | 3 868 s (1,07 h) |
| 1,22 | 851 | 3 | **2 488 s (0,69 h)** | 465 s (0,13 h) | 3 868 s (1,07 h) |
| 1,22 | 602 | 1,5 | 821 s (0,23 h) | 164 s | 2 736 s (0,76 h) |
| 1,22 | 602 | 3 | 1 733 s (0,48 h) | 329 s | 2 736 s (0,76 h) |
| 1,22 | 491 | 1,5 | 653 s (0,18 h) | 134 s | 2 232 s (0,62 h) |
| 1,22 | 491 | 3 | 1 397 s (0,39 h) | 268 s | 2 232 s (0,62 h) |
| **1,00** (BDK) | 851 | ≤ 1,024 | **no existe** (se cumple siempre) | 20 s | ∞ |
| **1,00** (BDK) | 851 | 1,5 / 3 | **∞** (ninguna `F` lo cumple) | 284 / 567 s | ∞ |

### B.4 · Veredicto de B

1. **La pinza NO es un artefacto: el mecanismo de BDK es real y el diseño entra en su régimen en
   cuanto alguien tiene `ρ > 1,024`.** — PLAUSIBLE (el porte del ataque de PoS a PoAS sigue **sin
   hacerlo nadie**: `dag-poas-ancla-de-finalidad-metaauditoria.md` lo declara y esta ronda no lo
   cierra; ver §B.5).
2. **Su NÚMERO sí es un artefacto.** `W = F + I` es el rincón `ρ → ∞` de la fórmula correcta.
   La `F` que la pinza exige de verdad es **1 198-2 488 s (0,33-0,69 h)** con `I = 851 s` y
   `ρ ∈ [1,5; 3]`, **no 3 868 s (1,07 h)**: entre **1,55× y 3,2× menos**. — **VERIFICADO**.
3. **Con `ρ ≤ 1,024` la pinza no existe** (`W ≤ κ` para toda `F`), y **con (h) es irrelevante**
   (`≤ 465 s`). — **VERIFICADO**.
4. **`W/κ = 1,22` como criterio hay que retirarlo o reetiquetarlo.** BDK marca 1,0; 1,22 fue el valor
   que salió en la ronda 7 y quedó como tope. Bajo la fórmula corregida, **1,0 es alcanzable** con
   `ρ ≤ 1,024` en el núcleo y con `F ≥ I(1−1/ρ)` bajo (h) — es decir, **con (h) el diseño puede
   cumplir la condición literal del paper, y el núcleo no puede para ningún `ρ > 1,024`**. — DEMOSTRADO
   (aritmética) sobre el modelo de `W` de B.2.

### B.5 · Lo que queda abierto en B (LAGUNA, declarada)

- **El porte del ataque de BDK a PoAS no está hecho.** En PoS el sobornado *sabe* que es líder y
  firma la bifurcación **sin equivocar** (negación plausible). En PoAS bajo R-FIN-14 el granjero no
  sabe que ganará hasta el slot; el vector que queda es que el **sobornante le regale su cadena de
  PoT adelantada**, y entonces el sobornado tiene que **renunciar a su recompensa honesta**
  (R-FIN-8′: un bloque en la rama perdedora no cobra), lo que **rompe la premisa de «arbitrarily
  small stake»** de BDK. **Nadie ha modelado ese cambio de coste.** Haría falta: un modelo de soborno
  con la coinbase de R-FIN-8′ como coste de oportunidad, y `κ+1` de `2κ+1` slots en `F·λ` bloques.
- **Unidades de `W` y `κ` en un DAG** (B4 de `salida_b.txt`): si `W` se contara en bloques del DAG
  (`λ = 1/s`) y `κ` en bloques de la cadena seleccionada (`λ_chain = 0,200/s`, ronda 1
  `chain_growth.py`), la razón se multiplicaría **por ~5,2-5,8**. Aquí se ha usado el mismo `λ` en
  los dos, como la metaauditoría. **Residuo declarado.**

### B.6 · Qué `W/κ` permite qué `F`, con `I ∈ {300, 851} s` (`salida_b.txt` B5)

**`I = 851 s`** — `F` mínima que exige cada tope:

| tope `W/κ` | **PUBLICADA** `I/(t−1)` | núcleo `ρ ≤ 1,024` | `ρ = 1,5` | `ρ = 3` | `ρ = 10` | **(h)** `ρ = 3` | (h) `ρ = 10` |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **1,00** (BDK) | ∞ | **no existe** | imposible | imposible | imposible | 567 s | 766 s |
| 1,05 | 17 020 s | no existe | 5 273 s | 10 947 s | 14 918 s | 540 s | 729 s |
| 1,10 | 8 510 s | no existe | 2 637 s | 5 473 s | 7 459 s | 516 s | 696 s |
| **1,22** | **3 868 s** | **no existe** | **1 198 s** | **2 488 s** | 3 390 s | **465 s** | 628 s |
| 1,50 | 1 702 s | no existe | 527 s | 1 095 s | 1 492 s | 378 s | 511 s |
| 2,00 | 851 s | no existe | 264 s | 547 s | 746 s | 284 s | 383 s |

**`I = 300 s`** (la época de Autonomys, para escala): tope 1,22 → publicada 1 364 s; núcleo
`ρ=1,5` **364 s**, `ρ=3` **818 s**; (h) `ρ=3` **164 s**.

**Y la respuesta a «por qué 1,22 y no 2,5».** Ninguno de los dos es un umbral del paper: **BDK marca
1,00**. El 1,22 es el **valor que salió** al fijar `g = 3,6 %` (⇒ `I = 2 490 s`) y `F = 3,2 h`, y la
propuesta lo etiqueta ella misma *«Es una elección, no una derivación»*
(`dag-poas-ancla-de-orden.md` §4.3). El «2,5» de la pregunta es el otro polo de esa misma frase —
*«un 22 % en vez de un 250 %»*—, y ese 250 % son los `W/κ = 3,49-3,50` de los dos puntos de ejemplo
de la ronda 7 (`dag-poas-ancla-de-finalidad-metaauditoria.md:215-222`), que la propia metaauditoría
declaró **«soborno encubierto posible»**. Es decir: se eligió 1,22 porque **era menos malo que 3,5**,
no porque 1,22 sea seguro y 2,5 no. **Con la `W` corregida la pregunta cambia de sitio:** con
`ρ ≤ 1,024` se cumple **1,00**, el umbral de verdad; con (h) se cumple 1,00 con `F ≥ 567 s`; y con
`ρ > 1,024` en el núcleo **no se cumple 1,00 con ninguna `F`** y hay que elegir un tope > 1 a
sabiendas, como hasta ahora, pero pagando **3,1× menos `F`** de la que se creía.


<a name="c"></a>
## C · Lo que espera el usuario — `r10c_c_reversion.py`, `r10c_c2_frontera.py`

### C.1 · La tabla de reversión (`salida_c.txt`)

`k = 30`, `λ = 1 bloque/s`, ventaja inicial `3k = 90` (Lema 10 de GHOSTDAG). **`prev()` no lleva `F`
en su firma**: el riesgo del comerciante que espera `t` segundos **no depende de `F` en absoluto**.
`F` solo entra en la unión a 10 años y en la frontera (C.2).

**Modelo CORREGIDO (9a, `δ = 0`):**

| `α` | `r` | 60 s | 300 s | 600 s | 1 800 s | 3 600 s |
|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 0,000 | **0** | **0** | **0** | **0** | **0** |
| 0,10 | 0,111 | 1,000 | 6,376e-21 | 1,305e-68 | 3,768e-316 | 0 |
| 0,25 | 0,333 | 1,000 | 2,234e-04 | 7,413e-19 | 9,476e-87 | 4,394e-191 |
| 0,33 | 0,493 | 1,000 | 2,539e-01 | 1,516e-06 | 7,071e-36 | 4,264e-82 |

**Modelo PESIMISTA (`δ(α)` medido por D8):**

| `α` | `δ` | `r` | 60 s | 300 s | 600 s | 1 800 s | 3 600 s |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 0,0000 | 0,000 | **0** | **0** | **0** | **0** | **0** |
| 0,10 | 0,0618 | 0,118 | 1,000 | 1,252e-17 | 2,138e-60 | 1,527e-261 | 0 |
| 0,25 | 0,1544 | 0,394 | 1,000 | 6,118e-02 | 3,009e-10 | 6,291e-54 | 3,813e-122 |
| 0,33 | 0,2867 | 0,691 | 1,000 | 9,986e-01 | **5,538e-01** | 2,375e-06 | 1,322e-16 |

> El **1,000 a 60 s** en todas las filas no es un fallo: es la ventaja `3k = 90` bloques del Lema 10.
> En 60 s los honestos producen `(1−α)·60 ≈ 40-54` bloques, menos que la ventaja regalada. **Ninguna
> confirmación es posible por debajo de ≈ `3k/((1−α)λ) = 100-134 s`, sea cual sea `F`.** Es una
> consecuencia directa de la cota de *freeloading*, y conviene escribirla en la documentación de
> producto: el mínimo absoluto de espera de ZEROX está en el orden de los 2 minutos.

### C.1b · Lo que el comerciante espera de verdad

Segundos hasta que la reversión baja de cada umbral (`brentq` sobre `t`):

| Modelo | `α` | `< 10⁻³` | `< 10⁻⁶` | `< 10⁻⁹` | `< 10⁻¹²` |
|---|---:|---:|---:|---:|---:|
| CORREGIDO (`δ=0`) | 0,10 | 159 s | 190 s | **217 s** | 241 s |
| CORREGIDO | 0,25 | 283 s | 356 s | **421 s** | 482 s |
| CORREGIDO | 0,33 | 460 s | 608 s | **742 s** | 871 s |
| PESIMISTA (`δ` D8) | 0,10 | 172 s | 206 s | **234 s** | 260 s |
| PESIMISTA | 0,25 | 381 s | 489 s | **584 s** | 674 s |
| PESIMISTA | 0,33 | 1 298 s | 1 869 s | **2 406 s** | 2 931 s |

**El comerciante espera entre 4 y 40 minutos. Nunca 1 h ni 2 h.**

### C.2 · Lo que se paga por acortar `F`: la frontera — `r10c_c2_frontera.py`, `salida_c2.txt`

Instrumento: `frontera`/`union10` de `d9-ronda9a/r9a_a3_frontera.py` **sin tocar**, igual que
`research/scripts/verif_frontera_vs_F.py` del agente principal, pero con la rejilla fina de 9a
(0,0005 + `brentq`) en vez de la gruesa (0,005). **Control:** `F = 19 080 s`, `I = 4 200 s` reproduce
**46,8784 % / 36,5431 %**, los dos valores de 9a.

| `F` | `I` | frontera `δ = 0` | frontera `δ` D8 | unión 10 años a `α=0,33`, `δ=0` | `δ` D8 |
|---|---:|---:|---:|---:|---:|
| 0,34 h | 491 | 34,72 % | 28,67 % | 1,50e-15 | **1,00** |
| 0,34 h | 851 | **34,81 %** | **28,74 %** | 8,65e-16 | **1,00** |
| 1 h | 491 | 41,92 % | 33,01 % | 2,74e-76 | 8,49e-11 |
| **1 h** | **851** | **41,98 %** | **33,05 %** | 1,58e-76 | 4,90e-11 |
| 1,07 h | 491 | 42,25 % | 33,27 % | 3,33e-83 | 2,32e-12 |
| 1,07 h | 851 | **42,30 %** | **33,31 %** | 1,92e-83 | 1,34e-12 |
| 2 h | 491 | 44,53 % | 35,06 % | 2,50e-169 | 5,29e-32 |
| **2 h** | **851** | **44,57 %** | **35,08 %** | 1,44e-169 | 3,05e-32 |
| 5,3 h | 491 | 46,78 % | 36,48 % | 3,27e-210 | 1,76e-102 |
| 5,3 h | 851 | 46,81 % | 36,50 % | 1,89e-210 | 1,02e-102 |

**Controles cruzados con lo ya publicado** (`dag-poas-bitacora-2026-09-08.md` §11, tabla de
`verif_frontera_vs_F.py`): `0,34 h / 851` → **34,81 % / 28,74 %** (publicado 34,81 / 28,74) ·
`1,07 h / 851` → **42,30 % / 33,31 %** (publicado 42,28 / 33,29, con rejilla más gruesa) ·
`2 h / 851` → **44,57 % / 35,08 %** y uniones **1,44e-169 / 3,05e-32** (publicado 44,57 / 35,08 y
1,4e-169 / 3,1e-32). **Reproducido.**

**La lectura:** de `F = 2 h` a `F = 1 h` la frontera baja **2,59 puntos** (`δ=0`: 44,57 → 41,98) y
**2,03 puntos** (pesimista: 35,08 → 33,05). Con `F = 1 h` el umbral operativo del 33 % conserva
**0,05 puntos** en el modelo pesimista — es decir, **no conserva nada**. Con `F = 2 h` conserva
**2,08 puntos**. Y a `F = 0,34 h` el 33 % **cae** en el modelo pesimista (unión = 1,00). **Este es el
precio real de acortar `F`, y se paga en la única dimensión que le importa al usuario: cuánto espacio
adversario aguanta la cadena.**

### C.3 · Qué gana el usuario con `F = 1 h` frente a `F = 2 h`

1. **En riesgo probabilístico: exactamente nada.** `prev(α, t)` es idéntica; a `t = 3 600 s` ya vale
   `4,264e-82` (`α = 0,33`, `δ=0`) y `1,322e-16` (pesimista). Adelantar la garantía por regla de 2 h
   a 1 h convierte un `10⁻¹⁶` en un `0`. **VERIFICADO.**
2. **En la garantía por regla (R-FIN-7): llega 1 h antes.** Real, pero solo importa a quien necesite
   irreversibilidad *categórica* (una bolsa acreditando un depósito grande), no a un comercio.
3. **Lo que se PAGA por acortarla: la frontera baja.** Ver C.2. Y la **tolerancia a particiones**,
   que es exactamente `F` (R-FIN-7), **se reduce a la mitad**.

**Conclusión C: el argumento «`F` corta para el usuario» está REFUTADO.** El usuario no espera `F`,
y su riesgo no depende de `F`. Los dos motivos legítimos para acortar `F` son **el sembrador**
(A, y solo si `ρ > 1`) y la latencia de la garantía categórica. — **VERIFICADO** (el instrumento es
el que publica los números del diseño, controlado en P1/P2).

### C.1c · Validación independiente del instrumento (regla 5) — Monte Carlo, 12 semillas

Segundo instrumento, **distinto**: se simula la carrera bloque a bloque (Poisson para el
adelanto en `t`, luego paseo aleatorio con `p = m_a/(m_a+m_h)` hasta alcanzar o hasta 400 bloques de
ventaja honesta), en vez de sumar la serie de Skellam. Celdas **elegidas en el régimen medible**
(`0,005 < p < 0,95`): un Monte Carlo no puede validar un `10⁻⁸`, y se dice.

| `α` | `hf` | `t` | MC media | MC mín | MC máx | analítico | razón |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0,33 | 1,000 | 300 | 0,252104 | 0,243250 | 0,262625 | 0,253942 | 0,9928 |
| 0,33 | 1,000 | 400 | 0,011131 | 0,010275 | 0,012400 | 0,011240 | 0,9904 |
| 0,35 | 1,000 | 300 | 0,516010 | 0,505750 | 0,529250 | 0,516328 | 0,9994 |
| 0,35 | 1,000 | 400 | 0,071050 | 0,069050 | 0,073050 | 0,071462 | 0,9942 |
| 0,40 | 1,000 | 500 | 0,352260 | 0,343125 | 0,362250 | 0,353035 | 0,9978 |
| 0,40 | 1,000 | 600 | 0,122444 | 0,117917 | 0,127083 | 0,123363 | 0,9926 |
| 0,40 | 1,000 | 800 | 0,007697 | 0,007417 | 0,008050 | 0,007823 | 0,9840 |
| 0,45 | 1,000 | 1 000 | 0,422969 | 0,415625 | 0,435625 | 0,425354 | 0,9944 |
| 0,45 | 1,000 | 1 500 | 0,074492 | 0,071350 | 0,080400 | 0,075780 | 0,9830 |
| 0,30 | 0,792 (`δ` D8) | 400 | 0,275921 | 0,273600 | 0,279200 | 0,275135 | **1,0029** |
| **0,00** | 1,000 | 600 | **0,000000** | 0,000000 | 0,000000 | **0,000000** | — |

**Razones 0,983-1,003 en 11 celdas independientes**, con la fila `α = 0` exactamente 0 en los dos
instrumentos. El sesgo sistemático de −1 a −2 % en las celdas de `p` pequeño está dentro de 0,5 σ
del propio muestreo (375-900 aciertos esperados). **VERIFICADO.** La extrapolación a `p ~ 10⁻⁸`
sigue siendo **analítica**, no medida: **cota ≠ realidad**, declarado.

<a name="d"></a>
## D · Configuración × término → `F` — `r10c_d_tabla.py`, `salida_d.txt`

### D.0 · Los cuatro términos no tiran en el mismo sentido

Es la corrección de forma más importante del punto: **el encargo pide «la `F` mínima que impone cada
término», pero el sembrador impone un MÁXIMO, no un mínimo.**

| Término | Sentido | De dónde |
|---|---|---|
| `F_carrera` | **mínimo** | unión a 10 años `< 10⁻¹⁰` al `α` objetivo (`r10c_c2_frontera.py` C2a) |
| pinza `W/κ` | **mínimo** | ventana de predicción de BDK con la `W` corregida (§B.3) |
| **sembrador** | **MÁXIMO** | `margen = A*₁₀ₓ / lookahead ≥ objetivo` (§A.4) |
| usuario | **ninguno** | el riesgo del comerciante no depende de `F` (§C.1) |

Manda `max(F_carrera, pinza)`, y hay que comprobar que **cabe por debajo** del máximo del sembrador.
Constantes: `A*₁₀ₓ = 14 760 s` (4,1 h, escenario B, el que favorece al atacante), `W_dec = 20 s`
(medida por 9c a `α ≤ 0,33`), tope `W/κ = 1,22` (el publicado).

### D.1 · La tabla, `α` objetivo = 0,33 (el umbral operativo publicado)

**Modelo CORREGIDO (`δ = 0`, 9a):**

| Configuración | `I` | `F_carrera` (mín) | pinza (mín) | usuario | `F` máx sembrador 3× | 5× | **MANDA** | viable 3× |
|---|---:|---:|---:|---:|---:|---:|---|---|
| `ρ_max = 1` (`n_eval=45`) | 491 | 1 028 s (0,29 h) | **0** (no existe) | nada | sin límite | sin límite | `F_carrera` **0,29 h** | SÍ |
| `ρ_max = 1,5` (`n_eval=68`) | 602 | 1 025 s (0,28 h) | 821 s (0,23 h) | nada | 4 740 s (1,32 h) | 2 772 s (0,77 h) | `F_carrera` **0,28 h** | SÍ |
| **`ρ_max = 3`** (`n_eval=135`) | 851 | 1 019 s (0,28 h) | **2 488 s (0,69 h)** | nada | 4 374 s (1,21 h) | 2 406 s (0,67 h) | **pinza 0,69 h** | SÍ |
| `ρ_max = 3` **CON (h)** | 851 | 1 019 s (0,28 h) | 465 s (0,13 h) | nada | sin límite | sin límite | `F_carrera` **0,28 h** | SÍ |
| `ρ_max = 10` **CON (h)** | 851 | 1 019 s (0,28 h) | 628 s (0,17 h) | nada | sin límite | sin límite | `F_carrera` **0,28 h** | SÍ |
| **(h)**, `I` libre = 300 s | 300 | 1 019 s (0,28 h) | 164 s (0,05 h) | nada | sin límite | sin límite | `F_carrera` **0,28 h** | SÍ |

**Modelo PESIMISTA (`δ` medido por D8):**

| Configuración | `F_carrera` (mín) | pinza (mín) | `F` máx sembrador 3× | **MANDA** | viable 3× |
|---|---:|---:|---:|---|---|
| `ρ_max = 1` | 3 588 s (1,00 h) | 0 | sin límite | `F_carrera` **1,00 h** | SÍ |
| `ρ_max = 1,5` | 3 573 s (0,99 h) | 821 s (0,23 h) | 4 740 s (1,32 h) | `F_carrera` **0,99 h** | SÍ |
| **`ρ_max = 3`** | 3 547 s (0,99 h) | 2 488 s (0,69 h) | 4 374 s (1,21 h) | `F_carrera` **0,99 h** | **SÍ** (pasillo [0,99; 1,21] h) |
| `ρ_max = 3` **CON (h)** | 3 547 s (0,99 h) | 465 s (0,13 h) | sin límite | `F_carrera` **0,99 h** | SÍ |

### D.2 · La misma tabla al `α` de diseño 0,35 — aquí es donde el núcleo se rompe

**Modelo PESIMISTA, `α = 0,35`:** `F_carrera = 6 900-6 987 s = 1,92-1,94 h` en todas las
configuraciones.

| Configuración | `F` máx sembrador 1,5× | 2× | 3× | 5× | ¿cabe `F_carrera = 1,92 h`? |
|---|---:|---:|---:|---:|---|
| `ρ_max = 1` | sin límite | sin límite | sin límite | sin límite | **SÍ** |
| `ρ_max = 1,5` | 2,68 h | 2,00 h | 1,32 h | 0,77 h | solo con margen **≤ 2×** |
| **`ρ_max = 3`** | 2,58 h | **1,90 h** | 1,21 h | 0,67 h | **solo con margen ≤ 1,5×** |
| `ρ_max ≤ 10` **CON (h)** | sin límite | sin límite | sin límite | sin límite | **SÍ, con cualquier margen** |

> **Este es el resultado que decide `F`.** Si se quiere que el modelo **pesimista** cubra `α = 0,35`
> **y** un margen `≥ 3×` frente al plotter 10×, **el núcleo es inviable para todo `ρ > 1`**: hace
> falta (h), o aceptar `ρ_max ≤ 1`, o bajar el margen objetivo a 1,5-2×.
> **Y explica exactamente qué es `F = 2 h` frente a `F = 1 h`:**
> · `F = 2 h` ≈ `F_carrera(0,35, pesimista) = 1,92 h` **con margen de sembrador 1,91×**;
> · `F = 1 h` ≈ `F_carrera(0,33, pesimista) = 0,99 h` **con margen de sembrador 3,56×**.
> **Bajar `F` de 2 h a 1 h es gastar los dos puntos de colchón (35 % → 33 %) del modelo pesimista
> para comprar el margen del sembrador de 1,9× a 3,6×.** No es una mejora para el usuario: es un
> intercambio entre dos riesgos, y hay que escribirlo así.

### D.3 · Con el tope LITERAL de BDK (`W/κ ≤ 1,00`), `α = 0,33`, `δ = 0`

| Configuración | `F_carrera` | pinza `W/κ ≤ 1` | MANDA |
|---|---:|---:|---|
| `ρ_max = 1` | 1 028 s (0,29 h) | 0 (se cumple siempre) | 1 028 s (0,29 h) |
| `ρ_max = 1,5` | 1 025 s | **sin límite: ninguna `F` lo cumple** | **IMPOSIBLE** (`W > κ` para toda `F`) |
| `ρ_max = 3` | 1 019 s | **sin límite** | **IMPOSIBLE** |
| `ρ_max = 3` **CON (h)** | 1 019 s | 567 s (0,16 h) | 1 019 s (0,28 h) |
| `ρ_max = 10` **CON (h)** | 1 019 s | 766 s (0,21 h) | 1 019 s (0,28 h) |

**Con (h) el diseño puede cumplir la condición literal de BDK; el núcleo no puede, para ningún
`ρ > 1,024`, con ninguna `F`.** — DEMOSTRADO (aritmética sobre el modelo de `W` de §B.2).

> Y hay una coincidencia que no es casual: bajo (h), «`W ≤ κ`» y «*steering* = 0» son **la misma
> condición**. Que el atacante no pueda evaluar candidatos exige `lookahead < L − W_dec`
> (9c E.5, `L > I`); que la ventana de predicción no exceda la confirmación exige `lookahead ≤ F`.
> Con `L = F` es la misma desigualdad. **Una sola constante, `F ≥ I(1−1/ρ_max) + W_dec`, cierra las
> dos cosas.**

### D.4 · El precio de (h), cuantificado por primera vez

R-FIN-14 (h) es **un segundo VDF de `L = F` slots por época**. Con el coste de PoT **medido**
(`dag-poas-ancla-de-orden.md`, bloque «Coste del PoT, MEDIDO»: `prove` 1,561 s/slot, `verify`
96,1 ms/slot en un 9950X3D, ruta `verify_sequential_avx512f_vaes`, 8 checkpoints), **verificarlo**
cuesta `F × 96,1 ms` por época:

| `F` | `I = 851 s` | `I = 491 s` |
|---:|---:|---:|
| 0,34 h (1 224 s) | 117,6 s/época = **13,8 %** de un núcleo | 24,0 % |
| 0,69 h (2 488 s) | 239,1 s = **28,1 %** | 48,7 % |
| **1 h** (3 600 s) | 346,0 s = **40,7 %** | 70,5 % |
| **2 h** (7 200 s) | 691,9 s = **81,3 %** | 140,9 % |
| 5,3 h (19 080 s) | 1 833,6 s = **215,5 %** | 373,4 % |

…**además** del 9,6 % de un núcleo que ya cuesta la cadena principal de PoT. **(h) hace que una `F`
larga sea cara en CPU de verificación, y el coste crece como `F/I`.** Es una **derivación** del coste
medido por slot, no una medición de punta a punta: **PLAUSIBLE**, y es el número que 9c dejó sin
poner (*«un VDF más … PLAUSIBLE, no medido»*). Falta medir: el `prove` del segundo VDF en el
timelord y si sus checkpoints se pueden solapar con los de la cadena principal.

<a name="e"></a>
## E · Hallazgo adicional (no pedido): **`L` es una palanca aparte de `F`, y es LA palanca del sembrador** — `r10c_e_palanca_L.py`, `salida_e.txt`

El lookahead del sembrador es `(L − W_dec) + I(1 − 1/ρ)`: **depende de `L`, no de `F`.** Hoy el
diseño los ata (`dag-poas-ancla-de-orden.md:282`, nota de R-FIN-7: *«ZEROX `I = 4 200 s`, `F = L = 5,3 h`»*),
y la ronda 7 ya había dejado escrita la alternativa sin explotarla
(`dag-poas-ancla-de-finalidad.md:89`: *«`L` rezago de aplicación; candidatos: `L = F`
(incondicional) o `L ≈ F/4` (probabilístico, §6)»*). Nadie la revisó después de R-FIN-14, que es
cuando pasa a importar.

**Qué exige `L` por sí sola.** `L` es la profundidad a la que el ancla `I_j` tiene que estar
**acordada** cuando se aplica en `t_j = slot(I_j) + L`. Si dos honestos leen anclas distintas el
flujo se parte (R-FIN-5: los flujos no se fusionan, nunca). Esa probabilidad es **la misma
reorganización que mide `prev()`**, evaluada en `L`. Luego **`L ≥ F_carrera(α_obj, modelo)`** — el
mismo número que C.2a calcula para `F`. Control E1: `L_min` reproduce C2a **exacto** (1 019 / 3 547 /
1 249 / 6 900 s).

**Qué se paga.** La **tolerancia a particiones pasa de `F` a `L`**: una partición más larga que `L`
puede dar dos anclas distintas y dos flujos irreconciliables aunque dure menos que `F`.

| Configuración (`I = 851 s`, `α_obj = 0,33`) | lookahead | margen 10× | `W/κ` | ¿BDK 1,00? | frontera la fija | tol. partición | garantía |
|---|---:|---:|---:|:--:|---|---:|---:|
| ATADA `L = F = 1 h`, `ρ = 3` | 4 146 s | 3,6× | 1,1518 | no | `F = 1 h` | 1,00 h | 1,00 h |
| ATADA `L = F = 2 h`, `ρ = 3` | 7 746 s | **1,9×** | 1,0759 | no | `F = 2 h` | 2,00 h | 2,00 h |
| **DESATADA `L = 1 h`, `F = 2 h`, `ρ = 3`** | **4 146 s** | **3,6×** | **0,5759** | **SÍ** | **`F = 2 h`** | 1,00 h | 2,00 h |
| DESATADA `L = 1 h`, `F = 2 h`, `ρ = 1,5` | 3 863 s | 3,8× | 0,5365 | SÍ | `F = 2 h` | 1,00 h | 2,00 h |
| DESATADA `L = 0,99 h`, `F = 5,3 h`, `ρ = 3` | 4 093 s | 3,6× | 0,2145 | SÍ | `F = 5,3 h` | 0,99 h | 5,30 h |
| (h), `L = F = 2 h`, `ρ = 3` | 567 s | **26,0×** | 0,0787 | SÍ | `F = 2 h` | 2,00 h | 2,00 h |

**La fila «DESATADA `L = 1 h`, `F = 2 h`» domina a las dos atadas:** tiene el margen de sembrador de
`F = 1 h` (**3,6×**), la frontera y la garantía de `F = 2 h`, y además **cumple la condición literal
de BDK (`W/κ = 0,576 ≤ 1`) sin necesidad del segundo VDF de (h)**. Lo único que pierde frente a
`L = F = 2 h` es la tolerancia a particiones, que baja de 2 h a 1 h.

**Etiqueta: PLAUSIBLE.** El mecanismo es directo y la aritmética está verificada, pero
`L ≥ F_carrera` es un **argumento** sobre `prev()` (la misma extrapolación que el diseño ya usa para
`F`), no una simulación de la discrepancia de ancla con dos vistas honestas distintas. **Lo que haría
falta para subirlo a VERIFICADO:** medir `P(dos honestos leen anclas distintas)` con `L < F` en un
simulador con dos vistas de verdad — el defecto `d8b_b3` que la propuesta ya señala (§7.4). No lo he
hecho en esta ronda.

<a name="reco"></a>
## Recomendación (con etiqueta)

1. **Retirar «`F` corta para el usuario» de la lista de razones.** — **REFUTADO** (§C). El riesgo del
   comerciante **no depende de `F`**; espera 217-2 406 s según `α` y modelo, y por debajo de
   ≈ 100-134 s no hay confirmación posible con ningún `F` (la ventaja `3k`). Lo que sí es cierto es
   que la garantía **categórica** llega en `F`, y eso solo le importa a quien la necesite categórica.
2. **La decisión de `ρ_max` es binaria, no un gradiente.** — **VERIFICADO** (§A.2). `ρ = 1` da 0 y
   `ρ = 1,001` da el 99,7 % de lo que da `ρ = 10`. Lo único que compra `ρ` grande es acortar el
   *bootstrap* (83 días → 13 min). Elegir entre **1,5 y 3 mueve el lookahead un ~5 % y el margen del
   sembrador un ~4 %**, no lo que sugería la tabla P3 publicada (5,42× / 4,42× / 3,13×), cuyo abanico
   venía enteramente de la pinza del *steering* que este informe corrige. **La pregunta real para
   Katana es «¿admito `ρ > 1` o no?», y la respuesta honesta es que sí** (`pot-aes-asic-chacha.md`
   estima el techo de un ASIC de latencia en 1,5-2,5×, y basta `ρ = 1,001` con paciencia).
3. **Desatar `L` de `F`** (§E) y fijar **`L = F_carrera(α_obj, modelo pesimista)`**, `F` por
   frontera / tolerancia a particiones / garantía. — **PLAUSIBLE**, con lo que falta dicho en §E.
4. **Punto de diseño recomendado, sin (h):** `ρ_max = 3`, `I = 851 s`, **`L = 1 h`, `F = 2 h`**.
   Da margen de sembrador **3,6×** (el de `F = 1 h`), la frontera y la garantía de `F = 2 h`, y
   **`W/κ = 0,576`, dentro del umbral literal de BDK**, sin segundo VDF. Se paga: tolerancia a
   particiones **1 h** en vez de 2 h.
5. **Si se exige tolerancia a particiones de 2 h**, las opciones son `L = F = 2 h` (margen **1,9×**,
   `W/κ = 1,08`, fuera de BDK) o **(h)** (margen **26×**, `W/κ = 0,079`), y (h) cuesta **81,3 % de un
   núcleo** de verificación continua a `F = 2 h` / `I = 851 s` (**40,7 %** a `F = 1 h`) — §D.4,
   PLAUSIBLE.
6. **Retirar `W/κ ≤ 1,22` como criterio** y sustituirlo por el literal `W ≤ κ` calculado sobre el
   lookahead real. Con `L` desatada **es alcanzable**; con `L = F` y `ρ > 1,024` **no lo es con
   ninguna `F`**. — DEMOSTRADO sobre el modelo de `W` de §B.2.
7. **No bajar `F` a 1 h atado.** — **VERIFICADO** (§C.2). Con `F = 1 h` la frontera del modelo
   pesimista es **33,05 %** frente al umbral operativo publicado de **33 %**: **0,05 puntos de
   colchón, es decir ninguno.** Con `F = 2 h` son **2,08 puntos** (35,08 %). Bajar de 2 h a 1 h
   **atados** es gastar todo el colchón del umbral para subir el margen del sembrador de 1,9× a 3,6×.
   **Desatando `L` se consigue exactamente ese margen sin gastar un solo punto de colchón**, y ese es
   el argumento decisivo a favor de §E.
8. **Consecuencia para la obligación anotada por Katana** («`F` se baja a 1 h en producción cuando el
   diseño corregido sobreviva a su ronda adversarial», `dag-poas-bitacora-2026-09-08.md` §11.2):
   **la obligación, tal como está escrita, hay que reformularla.** Lo que hay que bajar a 1 h es
   **`L`**, no `F` — y con eso se obtiene todo lo que se buscaba (margen de sembrador, `W/κ` dentro de
   BDK) sin tocar la frontera ni la garantía. — **VERIFICADO** el número; **PLAUSIBLE** el mecanismo
   de `L` (§E).

<a name="auditoria"></a>
## Auditoría de scripts (regla de método 10)

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d9-ronda10c/
Scripts analizados: 9

research/scripts/d9-ronda10c/r10c_lib.py
   [T1] L41: hf_delta0() recibe 'alpha' y NO lo usa

======================================================================
Sospechas totales: 1
```

**La marca, leída.** `hf_delta0(alpha)` ignora `alpha` **a propósito y eso es la tesis de 9a**: el
modelo corregido es `δ = 0` para todo `α` (atacante único, presupuestos disjuntos). La firma con
`alpha` existe para que `hf_delta0` y `hf_d8` sean intercambiables donde el código pasa `hf(a)`. **No
es un parámetro muerto: es el contraste.** Si se quitara el argumento habría que duplicar cada bucle,
y el criterio `α` de las tablas se comprueba precisamente **comparando** las dos columnas: `hf_d8`
**sí** depende de `α` (0,0000 / 0,0618 / 0,1544 / 0,2867), y las filas de C.1 se mueven con ella.
**Falso positivo, declarado.** 0 marcas T2 / T3 / T3b / T4.

> Dos marcas T3 (`bo != bo`, el test de NaN idiomático) aparecieron en la primera pasada y se
> **eliminaron reescribiendo con `math.isnan`**, que es más claro y no dispara al detector.
> Y se **borraron de la librería** las formas cerradas del primer esbozo (`tope_conocimiento`,
> `lookahead`, `bootstrap`, `F_de_la_pinza`), que tenían la opción (h) mal acotada: no debe viajar
> en el entregable una función equivocada junto a la buena. Tras borrarlas, `r10c_b`, `r10c_d` y
> `r10c_e` se re-ejecutaron y dan salidas **idénticas** (`diff` limpio), y `r10c_c0` se reescribió
> para que su control P4 use `cinematica_rapida`.

<a name="veredicto"></a>
## Veredicto

| Punto | Etiqueta | Número |
|---|---|---|
| **A** · lookahead honesto (`ρ = 1`) | **DEMOSTRADO** (R-FIN-14 a/b/e + código de Autonomys vía 9c §B.2) **+ VERIFICADO** | **0 slots.** `dag-poas-ancla-de-orden.md:374` (§4.8, «todo granjero conoce sus victorias `L` por adelantado») queda **REFUTADO** bajo R-FIN-14 |
| **A** · lookahead del atacante, núcleo | **VERIFICADO** (dos instrumentos, 0,274 % de discrepancia) | `(L − W_dec) + I(1 − 1/ρ)`; a `F = 2 h`, `I = 851`, `α = 0,33`: **7 462,7 s (`ρ=1,5`)**, **7 746,3 s (`ρ=3`)**; **0 si `ρ ≤ 1`** |
| **A** · lookahead con (h) | **VERIFICADO** | `I(1 − 1/ρ)`, **independiente de `F`**: 283,3 s (`ρ=1,5`), 566,7 s (`ρ=3`), 765,0 s (`ρ=10`) |
| **A** · ¿sobrevive el sembrador? | **VERIFICADO** | **Sí para todo `ρ > 1`** (margen 1,91× a `F=2 h`, 3,56× a `F=1 h`, con `ρ=3`); **no para `ρ ≤ 1`** (margen ∞); **casi no, con (h)** (26-52×) |
| **A** · `δ_ancla` medido (12 semillas) | **VERIFICADO** | media 1,05-3,25 s, máx **10 s**; propaga **+0,13 %** al lookahead. Despreciable |
| **B** · ¿es la pinza un artefacto? | **el mecanismo, PLAUSIBLE; el número, REFUTADO** | `W = F + I` es el rincón `ρ→∞`. Pinza real: **1 198 s (`ρ=1,5`) / 2 488 s (`ρ=3`)** con `I = 851`, frente a **3 868 s** publicados: **1,55-3,2× menos** |
| **B** · `W/κ` con `ρ ≤ 1` | **VERIFICADO** | **0,0007 a `F = 2 h`** (`W = 1 + λD = 5` bloques). Tres órdenes **dentro** de BDK, no un 22 % fuera |
| **B** · el 1,22 | **DEMOSTRADO que no es un umbral** | BDK marca **1,00**; `W/κ = 1 + I/F > 1` siempre ⇒ criterio insatisfacible bajo la `W` vieja. El 1,22 es el valor que salió a `F = 3,2 h` |
| **B** · porte del ataque de BDK a PoAS | **LAGUNA** | Nadie lo ha modelado; con R-FIN-8′ el sobornado **pierde su coinbase**, lo que rompe el «arbitrarily small stake». Hace falta el modelo de soborno con coste de oportunidad |
| **C** · tabla de reversión | **VERIFICADO** (analítico + MC de 12 semillas en 11 celdas, razones 0,983-1,003) | `α=0,33`, `δ=0`: 1,000 / 2,539e-1 / 1,516e-6 / 7,071e-36 / 4,264e-82 a 60/300/600/1 800/3 600 s. Pesimista: 1,000 / 9,986e-1 / 5,538e-1 / 2,375e-6 / 1,322e-16 |
| **C** · ¿qué gana el usuario con 1 h vs 2 h? | **REFUTADO que gane algo** | **Nada** en riesgo (`prev` no depende de `F`); la garantía categórica llega 1 h antes, sobre un riesgo que a 3 600 s ya vale `4,3e-82` / `1,3e-16` |
| **C** · suelo de espera | **VERIFICADO** | `≈ 3k/((1−α)λ) = 100-134 s`: **ninguna confirmación es posible antes**, con ningún `F` |
| **D** · qué término manda | **VERIFICADO** | `α=0,33`, `δ=0`: **`F_carrera` 0,28-0,29 h**, salvo `ρ_max=3` donde manda la **pinza, 0,69 h**. `α=0,33` pesimista: **`F_carrera` 0,99-1,00 h** en todas. `α=0,35` pesimista: `F_carrera` **1,92-1,94 h**, y el núcleo con `ρ>1` **no cabe** con margen ≥ 3× |
| **D** · el precio de (h) | **PLAUSIBLE** (derivado del coste medido por slot) | **40,7 %** de un núcleo a `F = 1 h`, **81,3 %** a `F = 2 h`, **215 %** a `F = 5,3 h` (con `I = 851 s`), además del 9,6 % de la cadena principal |
| **C** · frontera vs `F` | **VERIFICADO** (reproduce lo publicado) | `δ=0` / pesimista con `I=851`: 0,34 h **34,81 / 28,74 %** · 1 h **41,98 / 33,05 %** · 2 h **44,57 / 35,08 %** · 5,3 h **46,81 / 36,50 %**. Con `F = 1 h` el umbral del 33 % conserva **0,05 puntos**; con 2 h, **2,08** |
| **E** · `L` desatada de `F` | **PLAUSIBLE** | `L = 1 h`, `F = 2 h`, `ρ=3`: lookahead **4 146 s**, margen **3,6×**, **`W/κ = 0,576` (dentro de BDK)**; coste: tolerancia a particiones 2 h → 1 h |

<a name="errores"></a>
## Errores propios (regla de método 9)

1. **El esbozo interrumpido de esta misma ronda tenía mal la opción (h).** `tope_conocimiento(...,
   retardada=True)` devolvía `I` con independencia de `ρ`. Es una cota superior válida (`ρ → ∞`) pero
   **no es la cota**: bajo (h) la cadena se bloquea en cada inyección y el adelanto máximo es
   `I(1 − 1/ρ)`. Con `ρ = 1,5` e `I = 851 s` la diferencia es **851 → 283 s, un factor 3**.
   Corregido en `cinematica`/`cinematica_rapida`; el comentario queda en el fichero.
2. **Primera pasada de la validación A0: horizonte más corto que el *bootstrap*.** Con `ρ = 1,05`,
   `F = 19 080 s`, la simulación paso a paso se midió a 300 000 s cuando saturar exige 381 200 s, y
   publiqué una «discrepancia» de **4 258 slots** que era del instrumento, no de la fórmula. Corregido
   dimensionando el horizonte desde el *bootstrap* teórico (`2,5×`).
3. **El mismo error, otra vez, en el integrador rápido.** `n_epocas = 4 000` fijas hacían que
   `ρ = 1,001` marcara «CERRADA DISCREPA» en 10 filas. Corregido con auto-dimensionado
   (`3·cap/((ρ−1)·I) + 400`). **Es la misma clase de error dos veces en una hora**; lo anoto como tal.
4. **La media del integrador rápido no era una media temporal**, sino la media de los máximos por
   época. Corregida a la media temporal exacta de la ventana (rampa + tope decayendo).
5. **Primera pasada del Monte Carlo: celdas inútiles.** Elegí `α ∈ {0,40; 0,45; 0,48}` a
   `t ∈ {60, 300}` y **7 de 8 celdas dieron 1,0000**: no validaban nada. Rehecho eligiendo celdas con
   `0,005 < p < 0,95`.
6. **Etiqueta imprecisa en A.5.** La columna «con retención» de `r10c_a2` usa `retraso = None`, que
   en `r9c_lib` significa **retener para siempre**, no publicar con retraso; por eso `tips_pub = 0` y
   `liberados = 0`. Lo que mide es «el atacante retiene todos sus bloques», que es el peor caso para
   `δ_ancla`, pero **no es una retención temporal**. Declarado en el propio informe.
7. **No he vuelto a medir `W_dec`**: uso la de 9c (`salida_c4.txt`), con su LAGUNA de resolución
   declarada (rejilla `{0,10,20,45,…}`, tope de 10 candidatos). Todo el punto A y la pinza corregida
   heredan esa resolución.
8. **`L ≥ F_carrera` (§E) es un argumento, no una medición.** No he simulado la discrepancia de ancla
   con dos vistas honestas distintas, que es el defecto `d8b_b3` que la propuesta ya señala. Por eso
   §E es PLAUSIBLE y no VERIFICADO.
