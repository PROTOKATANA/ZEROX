# Auditoría D8 — Ronda 8g: ataques contra el diseño completo (ancla por `slot`, constantes fijadas)

**Pregunta:** por primera vez el DAG tiene reglas (R-FIN-1..13) **y** constantes (`k=30`, `q=1`, `τ=1 s`,
`S_max=150 s`, `I=4 200 s`, `F=5,3 h`). ¿Hay un ataque que lo rompa con esas constantes? Seis líneas: A1
sostenibilidad del sesgo del Lema 9, A2 dos vistas honestas, A3 partición + `S_max`, A4 cruce del ancla en
régimen, A5 soborno BDK+19 portado a PoAS, A6 margen económico + `3k` + `shuffle`.
**Fecha:** 2026-09-08, mañana (relanzado a las 09:56 tras morir el primero por cuota sin informe) ·
**Agente:** D8 en **Opus 5**, fresco, adversarial · **Informe (≈ 900 líneas), 17 scripts, 18 salidas, 14 commits
solo en su directorio:** `research/scripts/d8-ronda8/` (último `263a3a3`).

> **VEREDICTO (mío, tras reproducir cada número de D8 que decide algo):** D8 firma «dos ataques que rompen el
> diseño con sus constantes». Verificado: **(1) la cadena parásita es real, legal bajo R-FIN-1a/11/12,
> invisible para R-FIN-7 y rentable a partir de `α = 0,33`**; baja el umbral de orden de 40,0 a **37,1 %** y la
> frontera de flujo único de ≈ 39,3 a **36,5 %** (**36,25 %** compuesta con el retarget, §1.3). El **35 % publicado
> sobrevive** (`3·10⁻³⁸` en 10 años), con **1,25 puntos** de colchón en vez de 4,3. **(2) El soborno desacopla `m` de `α`** (`m = b+1`, incluso con
> `α = 0`). Leído contra el diseño real —donde `F` es una **constante fija**, no una función de `m`— el soborno
> no mueve `F`: mueve el **steering**, que a `α = 0,35` sube la cuota efectiva a **36,1-36,6 %**, a 0,1-0,6
> puntos de la frontera. **La pinza cierra por poco.** Y **(3) la economía**: con `I+F = 6,1 h` el margen frente
> a un plotter 10× es **0,67×** en el escenario B (era 1,05×); con la retención hasta `S_max` que A4.2 mide,
> `m = 2,822`, `F = 6,17 h` y el margen **0,54×**. El «`F ≤ 68,5 h` garantizado» **no tiene respaldo
> económico** (0,49× frente a la GPU de hoy) y no debe publicarse como garantía de seguridad.
> **Lo que NO se rompe:** acuerdo entre vistas honestas (A2), el cruce del ancla en régimen (A4.1: `m` baja
> con el horizonte), `3k` (holgada: máximo real `0,56·3k`), el `shuffle` (no-op en régimen: nunca > 15 puntas).

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commits `f778d6a`…`263a3a3` | **Solo su directorio**; `salida_a4c.txt` commiteada en `1b1d8d1` |
| `AUDITA_SCRIPTS.py` (17 scripts) | **3 marcas, las tres leídas por mí:** `[T3b] padres/ph = self._padres(d, visibles)` en `d8_lib.py:109`, `d8_a1d:53`, `d8_a6b:93`. Falso positivo: `padres` está en la rama `if quien == "h"` (bloque honesto) y `ph` en la rama del atacante, que **fusiona la vista honesta a propósito** — es el mecanismo, no una tautología. 0 marcas T1/T2/T3/T4 |
| **A1b** (`δ` de la parásita, 8 α × 5 J × 12 semillas, 1 800 s), **re-ejecutada por mí** | **IDÉNTICA** (22 líneas): `δ(0,33)=0,2867`, `δ(0,35)=0,3065`, `δ(0,40)=0,4366`, `rech=0` |
| **A1c** (propagación de riesgo, Skellam de `verif_constantes.py`), re-ejecutada | **IDÉNTICA** (7 s). Los 37,1 / 36,7 / 38,1 % son **interpolaciones** entre `α = 0,35` y `0,37-0,40` de esa tabla (comprobadas a mano: punto fijo `α*(δ(α)) = α` en 0,3713; `10⁻¹⁰` en 0,3669; `r = 1` en 0,381) — precisión ±0,5 puntos |
| **A1e** (rentabilidad), re-ejecutada | **IDÉNTICA**: ratio ingreso atacante/honesto 0,995 (`α=0,25`), **1,159 (0,33)**, 1,270 (0,35), 1,549 (0,40) |
| **A5** (soborno, 13 min), re-ejecutada | **IDÉNTICA** salvo el tiempo. `m = b+1` se **mide** quitando los bloques de los sobornados (`corre_sob`, `continue`) y releyendo el ancla, no se supone |
| **A6** (presupuesto), re-ejecutada | **IDÉNTICA** (54 s). Reproduce el 10,6×/1,05× del diseño con `I=2 490 s, F=3,2 h`, y usa los `A*` del propio documento (`dag-poas-ancla-de-finalidad.md` L64-66: 63/41/69 h hoy, 6,3/4,1/6,9 h con plotter 10×) |
| **A3b M2** (eclipse parcial), reproducida **e instrumentada** por mí | `0,715` exacto a `α=0, E=20 s, S_max=20 s`. Los válidos (167 de 586) son bloques que `H_C` **encadena sobre su propio bloque anterior** (159), no calentamiento (13): ocurre cuando dos bloques propios distan < ~7 s. **En régimen (segunda mitad), `E=200 s / S_max=150 s` da 77 % inválidos, no 68 %**: el número de D8 es conservador |
| Constantes con `m` de A4.2 (`r8f_lib.constantes`) | `m=2,822 → I=4 890 s, F=22 227 s = 6,17 h` ✓ · `m=23 → I=7,98 h, F=36,3 h` ✓ · `m=151 → I=15,07 h, F=68,5 h` ✓ |
| Lema 9 del paper (`phantom-ghostdag.txt` L1120-1145), releído | Es una cota de **un evento** («publishing `k+1` blocks in the anticone of the selected parent… on average at most `2Dλ` such blocks»). **No** acota un ritmo sostenido. La lectura de D8 es correcta; la de la ronda 3 (que la usó como tasa) era la PLAUSIBLE-NO-DEMOSTRADO que ella misma declaró |
| **Modelo cerrado de la parásita** (mío, `research/scripts/verif_parasita.py`) | Ver §1.1. `J* = kα/(1−2α)` cae en el punto de la rejilla que D8 eligió en 5 de 7 `α`; `δ_D8 ≤ δ_ráfaga(J*)` en las 7 |

---

## 1 · A1 · La cadena parásita — REFUTADO el `δ` del diseño (verificado)

### 1.1 · El mecanismo, en forma cerrada

El atacante encadena en privado `A_1 → A_2 → …`; cada `A_j` fusiona la vista honesta del instante. `A_1` es
bloque de cadena (azul) y su anticono azul solo admite `k` bloques (`protocol.rs:250`): los honestos creados
tras `t_1 − Δ` entran como azules **hasta llenar los `k`**, y a partir de ahí **todo honesto nuevo es rojo en
la vista privada** (empujaría el anticono azul de `A_1` por encima de `k`). Al publicar `J` bloques
(duración `T = J/(αλ)`):

```
privada = bw(fork) + k + J        honesta = bw(fork) + (1−α)λT = J(1−α)/α
por delante  ⇔  k + J > J(1−α)/α  ⇔  J < J* = kα/(1−2α)
rojos por ráfaga = honestos tras la saturación = J(1−α)/α − k   ⇒   δ_ráfaga(J) = 1 − kα/(J(1−α))
```

| `α` | `J*` teórico | punto de la rejilla ≤ `J*` | `J*` que D8 eligió | `δ_ráfaga(J*)` | `δ` D8 (todo el horizonte) |
|---:|---:|---:|---:|---:|---:|
| 0,25 | 15,0 | 16 | **16** | 0,375 | 0,154 |
| 0,33 | 29,1 | 16 | 31 | 0,523 | 0,287 |
| 0,35 | 35,0 | 31 | **31** | 0,479 | 0,307 |
| 0,37 | 42,7 | 31 | 48 | 0,633 | 0,345 |
| 0,40 | 60,0 | 48 | **48** | 0,583 | 0,437 |
| 0,45 | 135 | 96 | 64 | 0,616 | 0,583 |

Es **Nakamoto con ventaja inicial `k`**: `J* → ∞` cuando `α → 1/2`. El Lema 9 del paper cuenta `2Dλ` rojos
porque supone **un** evento de `k+1` bloques; aquí la cadena **sigue creciendo mientras esté por delante**, y
los rojos son los honestos de la segunda mitad de la ráfaga, no los del anticono del viejo padre.

### 1.2 · Lo que D8 midió (reproducido)

- **Legal:** `rech = 0` (U2, U3″, `mergeset_size_limit`, `max_block_parents`); bajo R-FIN-1a con
  `S_max = 20 s`, 1-15 bloques ilegales de 5 000-8 000 y `δ` **idéntico** (`d8_a1d`).
- **R-FIN-7 no la ve:** cada ráfaga tiene 64-142 s de profundidad frente a `F = 19 080 s`.
- **Rentable:** R-FIN-8 no paga rojos, así que el ingreso relativo del atacante sube: **gratis a 0,25**
  (0,995), **+16 % a 0,33**, +27 % a 0,35, +55 % a 0,40. Pierde el 0,1-1,2 % por retenciones fallidas. **Un
  granjero racional del 33 % la ejecuta por dinero.** Es el umbral de *selfish mining* del diseño.
- **Umbrales:** orden 40,0 → **37,1 %**; flujo único (`P < 10⁻¹⁰` en 10 años) ≈ 39,3 → **≈ 36,7 %**; `r = 1`
  en **38,1 %**. A `α = 0,25` el diseño era **conservador** (`δ` real 0,154 < 0,2105): reversión a 600 s
  `3,0·10⁻¹⁰` en vez de `6,6·10⁻⁸`.

### 1.3 · Composición con la inflación del retarget (LAGUNA 1 de D8, cerrada aquí)

**Medido por mí** (`research/scripts/verif_composicion_parasita.py`, instrumento de D8 sin tocar, 12 semillas, 1 800 s):
como `k` está en bloques, la única combinación adimensional que la inflación del retarget mueve es `Δ·λ`; se
sube `λ` con `Δ = 4 s` fijo. Control `λ = 1`: **reproduce** 0,2867 / 0,3065.

| `λ` (`Δλ`) | `δ(0,33, J=31)` | `δ(0,35, J=31)` |
|---:|---:|---:|
| 1,00 (4) | 0,2867 | 0,3065 |
| 1,25 (5) | 0,2973 | 0,3176 |
| 1,45 (6) | 0,3057 | 0,3231 |

`+14,5 %` de `δ` por unidad de `λ − 1`. Punto fijo `λ_real = 1/(1 − (1−α)δ)`: **`δ(0,35) = 0,318`,
`λ_real = 1,26`**. Propagado con el `prev()` de D8 (Skellam, `3k`, `F = 19 080 s`, 7 509 épocas/año) e
interpolando `δ(α)` linealmente entre sus puntos:

| | sin retarget | **con retarget (compuesto)** |
|---|---:|---:|
| Frontera de flujo único (`10⁻¹⁰` en 10 años) | 36,5 % (D8 escribe ≈ 36,7 con interpolación log) | **36,25 %** |
| `r = 1` | 38,2 % | **37,9 %** |
| Unión a 10 años en `α = 0,35` | `4,0·10⁻⁴⁵` | **`3,1·10⁻³⁸`** |

**La composición es de segundo orden** (el mecanismo cuenta bloques, no segundos): quita 0,3 puntos más. El
35 % sigue sobreviviendo; el colchón real es **1,25 puntos**, sin contar `Δ`.

---

## 2 · A5 · El soborno — REFUTADO como supuesto, reencuadrado contra el diseño real

**Lo que D8 mide:** `m = b+1` exacto, para todo `α` **incluido `α = 0`**: retirar los `b` primeros ganadores
tras `T_j` (que se conocen `F = 5,3 h` antes por R-FIN-2) da `b+1` anclas. Sin equívoco, negabilidad de BDK
intacta, U3″ no se entera. Coste ≥ `b` recompensas (cota inferior; con la corrección de D8 a ganadores en
vez de bloques de cadena, ×1,3). Valor `c_m·√(αλI)` (el modelo del diseño, `dag-poas-voto-auditoria.md`
L197-199): **12-23× el coste**; punto fijo del sobornador `m* = 23`.

**Lo que D8 concluye y lo que yo leo distinto.** D8 rehace `I` y `F` para `m* = 23` manteniendo el steering
objetivo `g = 3,6 %` y obtiene `I+F = 44 h > A* = 41 h`. Pero en el diseño **`F` es una constante publicada**
(5,3 h), no una función de `m`: el soborno no cambia `F`, cambia **cuánto steering consigue el atacante con
esa `F`**. Con `g = c_m/√(αλI)`, `I = 4 200 s`, `α_ef = α(1 + g(1−α))` (`c_m` de Blom):

| `m` | `c_m` | `g` a `α=0,35` | **`α_ef` a `α=0,35`** | `α` publicable para `α_ef ≤ 36,7 %` |
|---:|---:|---:|---:|---:|
| 2,548 (medido, propio) | 0,761 | 1,98 % | 35,45 % | 36,25 % |
| 12 (soborno con prima ×3) | 1,635 | 4,26 % | 35,97 % | 35,73 % |
| **23** (punto fijo de D8) | 1,929 | 5,03 % | **36,14 %** | 35,56 % |
| **151** (`1 + λ·S_max`) | 2,651 | 6,89 % | **36,57 %** | 35,46 % |

**Las dos lecturas llegan al mismo sitio por caminos distintos:** el 35 % publicado queda a **0,1-0,6 puntos**
de la frontera de 36,7 % una vez que el ancla se puede comprar. No está roto; está **sin colchón**.

---

## 3 · A6 + A4.2 · La economía — REFUTADO el margen (aritmética verificada)

| Caso | `m` | `I` | `F` | `I+F` | Margen hoy (A/B/C) | **Margen plotter 10× (A/B/C)** |
|---|---:|---:|---:|---:|---|---|
| Diseño (ronda 7) | — | 0,69 h | 3,2 h | 3,89 h | 16,2/10,6/17,7× | 1,62/**1,05**/1,77× |
| **Diseño actual**, `m` medida | 2,548 | 1,11 h | 5,03 h | 6,14 h | 10,3/6,7/11,2× | 1,03/**0,67**/1,12× |
| **Con retención hasta `S_max`** (A4.2) | **2,822** | 1,36 h | **6,17 h** | 7,53 h | 8,4/5,4/9,2× | 0,84/**0,54**/0,92× |
| Garantía `S_max = 150 s` | 151 | 15,1 h | 68,5 h | 83,6 h | **0,75/0,49/0,83×** | 0,08/0,05/0,08× |

- **A4.2 (TENSIÓN, medido):** retener y soltar justo antes de `S_max` sube `m` de 2,029 a **2,822** a
  `α = 0,25` (+39 %). No es vector nuevo, pero **la constante `m = 2,548` del diseño se queda corta**: hay
  que dimensionar con 2,822. D8 declara que las filas `α ≥ 0,33` y los horizontes ≥ 900 s **no terminaron**
  (el `DAG` heredado hace alcanzabilidad por cierre transitivo, `O(n²)`; Kaspa usa índices de intervalo).
- **La garantía `F ≤ 68,5 h` es de consenso, no de seguridad:** si alguna vez hubiera que apoyarse en ella,
  el ploteo dirigido sería más barato que el SSD **hoy**, en los tres escenarios. Publicarla sin esa etiqueta
  sería publicar un número roto.

---

## 4 · A3 · `S_max` — la red confirma 150 s; la economía solo muerde a la garantía

| | `S_max = 20 s` | `30 s` | **`150 s`** |
|---|---:|---:|---:|
| Honestos invalidados/h sin eclipse (`α = 0,40`) | 24,2 | 0 | **0** |
| Granjero con 20 s de retraso de entrada: bloques **inválidos** (no huérfanos) | **71-75 %** | 0,2 % | **0** |
| Granjero con 200 s de retraso (mi medida en régimen) | 77 % | 73 % | **77 %** |
| Partición `f = 0,09` (R-FIN-7): `P = e^{−fλS_max}` | 16,5 % | 6,7 % | **~0** |

R-FIN-1a **invalida**, no orfana: un granjero cuya entrada llegue más de `S_max` tarde es rechazado por
consenso, y no hace falta espacio para provocarlo (`α = 0` da lo mismo). Es presión de centralización de la
clase de P-036. **`S_max = 150 s` es la única elección segura en el eje de red.** El «eje económico» de D8
(0,49×) solo aplica si se diseña con la garantía, que Katana no eligió.

---

## 5 · SIN VECTOR (a favor del diseño, verificado que el instrumento podía ver)

- **A2, dos vistas honestas:** desacuerdo del ancla **0 en 3 168 muestras** a `D ≥ 128 s`, para todo `α`; la
  aplicación es a `D = F = 19 080 s`. Capacidad: `div_sp = 0,84-0,98`, 100 % a `D = 4 s`. **LAGUNA de modelo:**
  el adversario del paper sin retardo **sincroniza** las dos vistas (la fila `α = 0` es la peor); partirlas de
  verdad exige control del enlace honesto↔honesto, fuera del modelo.
- **A4.1, cruce en régimen:** `m` **baja** de 2,540 (260 s) a 2,421 (500 s); dos implementaciones
  independientes coinciden. Capturas del ancla 50,5 % a `α = 0,40` (sobrerrepresentación en cadena), rachas
  compatibles con independencia (`P(racha ≥ 11) ≈ 0,22` en 12 corridas): el supuesto de épocas
  independientes del steering **se sostiene**.
- **`3k`:** ventaja máxima real **50 = 0,56·3k**, incluso con la parásita. La tabla de riesgo es pesimista en
  este eje.
- **`shuffle`:** 0 diferencias en 10 790 selecciones; puntas máx 13 < `max_block_parents = 15`. **Que el
  simulador de D9-c/d/e/f no lo implementara no invalida sus medidas** (no-op en régimen). LAGUNA: el régimen
  > 15 puntas no está medido por nadie.

---

## 6 · Errores declarados por D8 (cinco) y lagunas (siete)

Heredó `d8_lib.py` del D8 muerto con un defecto (comparaba contra la vista omnisciente, debilitaba al
atacante) y lo corrigió antes de usarlo; su primer A2 no podía detectar lo que buscaba; comparó `δ` sin
retarget con `δ_real` sin decirlo; A4 demasiado caro y reescalado; el coste del soborno en la cota inferior.
Lagunas: composición con el retarget (cerrada en §1.3), partir dos vistas, régimen del `shuffle`, **`Δ` sin
medir** (si `Δ = 8 s`, `δ` nominal 0,348 y el umbral cae ~4 puntos más), `τ` (mis medidas están en `τ = 1 s`,
que es la rama decidida — D8 lo confirma en su §4), unidades de `S_max` (resuelto por (A″)), precio del
soborno. Y una nueva de implementación: **el coste de verificar PoT es por slot, no por bloque** —
`verify = 96,1 ms/slot` y `S_max = 150` slots serían 14,4 s de CPU **si** un bloque obligara a verificar su
salto; con `PotCheckpoints` cacheados por slot es el 9,6 % de un núcleo. Quien cierre `C-NET-03/04` lo
resuelve reteniendo bloques por delante del PoT verificado.

---

## 7 · Las tres decisiones de Katana, contrastadas

| Decisión | ¿Cambia? | Por qué |
|---|---|---|
| **`S_max = 150 s`** | **No.** Se mantiene | Única segura en red (§4). El coste es que la cota `m ≤ 151` deja de ser útil como garantía (§3) y que el steering comprado puede llegar a 6,9 % (§2) |
| **`F`: diseñar con el medido, publicar los dos** | **Sí, en dos cosas** | (i) el medido debe ser **`m = 2,822 → F = 6,17 h`** (retención hasta `S_max`, A4.2), no 5,3 h; (ii) el «68,5 h garantizado» solo puede publicarse con la etiqueta **«garantía de consenso sin respaldo económico»**. Y el precio: margen **0,54×** frente a un plotter 10× (B), 5,4× frente a hoy |
| **Umbral 35 % (flujo único)** | **Sobrevive, sin colchón** | Frontera real **36,7 %** (−2,6 puntos); con steering comprado, `α_ef(35 %) = 36,1-36,6 %`; **a partir de 33 % desviarse es rentable** (A1.5); `Δ` sin medir. El **40,0 % «de orden»** que se declara al lado **es falso: 37,1 %** |

**Mi recomendación, marcada como tal:** publicar **33 %** como número único de operación (el umbral de
incentivos, el menor de los tres), declarando al lado 36,7 % (flujo único) y 37,1 % (orden); y **no**
publicar 68,5 h como garantía. Alternativa: mantener 35 % declarando explícitamente que la desviación es
rentable desde 33 % y que el colchón real es < 1 punto. Las dos son honestas; la primera no requiere una nota
al pie para serlo.

## 8 · Soluciones posibles a lo que D8 abrió (para decidir, no decididas)

1. **Contra la rentabilidad de la parásita (A1.5): pagar los rojos con billete válido dentro de
   `merge_depth`.** El ingreso del atacante deja de subir cuando vuelve rojos a los honestos; el umbral de
   incentivos desaparece y queda solo el de seguridad (37,1 %). Coste: se pierde la penalización a los
   bloques laterales — que en PoAS ya no cuesta nada producir, así que se pierde poco; hay que comprobar que
   no reabre un vector de inflación de `λ_real` (los rojos ya cuentan en el retarget por R-FIN-13). **Es la
   palanca más barata y toca una sola regla (R-FIN-8).**
2. **Contra el soborno (A5): no hay regla que lo impida** — es la ventana de predicción de BDK+19 en su
   forma PoAS. Lo que lo acota es que el valor del steering está **saturado**: `g ≤ 6,9 %` incluso con
   `m = 151`, y la pinza de §2 se sostiene por 0,1-0,6 puntos. Subir `I` compra colchón a cambio de
   lookahead (§3): la bifurcación es de Katana.
3. **`Δ`:** sigue siendo la variable de la que cuelga todo y la única sin medir. Protocolo de medida en red
   de pruebas, antes de fijar ningún número como definitivo.
