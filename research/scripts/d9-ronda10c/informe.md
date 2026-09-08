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

---

## Índice

- [Controles (regla 4)](#controles)
- [A · El lookahead real bajo R-FIN-14](#a)
- [B · La pinza `F ≥ I/(W/κ − 1)`](#b)
- [C · Lo que espera el usuario](#c)
- [D · Tabla configuración × término → `F`](#d)
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
| `A* = 41 h` (esc. B, GPU tope ALU) y `A*/10 = 4,1 h` | `dag-poas-ancla-de-finalidad.md:54-70`; `t_plot = 4,28 s` de `research/coste-ploteo-medido.md:228-231` | **Sobrevive sin cambios** (no depende del consenso) |
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
