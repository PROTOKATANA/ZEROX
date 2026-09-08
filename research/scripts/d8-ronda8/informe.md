# D8 · ronda 8 — ataques contra el diseño completo (ancla por `slot`, constantes fijadas)

**Fecha:** 2026-09-08 · **Agente:** D8 (adversarial, fresco) · **Estado:** CERRADO

> **Regla 8 (volcado incremental).** Un D8 anterior murió por cuota sin escribir nada. Este
> fichero se escribe ANTES de A1 y se cierra tras CADA línea con veredicto y números.
> Lo que esté en disco es lo único que sobrevive.

---

## 0 · Plan y estado del instrumento

### 0.1 · Qué se ataca

`research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1..13), con las constantes:
`k = 30`, `mp = 15`, `msl = 180`, `λ = 1 bloque/s`, `q = 1`, `Δ = 4 s`,
`I = 4 200 s`, `F = L = 5,3 h`, `S_max ∈ [20, 150] s`, `W_RETARGET ≥ 3 083`, `τ ≈ 0,1-0,17 s` (rama A).

### 0.2 · Líneas

| Línea | Objetivo | Estado |
|---|---|---|
| A0 | Validar el instrumento heredado (`d8_lib.py` del D8 muerto) | **REPRODUCIDO** |
| A1 | ¿Se **sostiene** el sesgo `δ` del Lema 9 con `α < 1/2`? `δ` sostenible real | **REFUTADO** |
| A2 | Acuerdo honesto con **dos vistas** separadas por `Δ`: `P(I_j distinto)` | **SIN VECTOR** + LAGUNA |
| A3 | Partición + `S_max` + R-FIN-7: ¿se puede **provocar** sin partición real? | **REFUTADO** (eclipse parcial) |
| A4 | Cruce del ancla `slot` en régimen (`I = 4 200 s`, `F = 5,3 h`); retención hasta `S_max` | **SIN VECTOR** |
| A5 | Soborno BDK+19 §2 portado a PoAS (`W/κ = 1,22`) | **REFUTADO** |
| A6 | Líneas 3/5/6 de §7 + **margen económico** con lookahead `F + I = 6,5 h` | **REFUTADO** (economía); líneas 3 y 5 SIN VECTOR |

> **El veredicto completo, con los números, está al final del documento.**

### 0.3 · Estado del instrumento — declaración sobre `d8_lib.py`

`d8-ronda8/d8_lib.py` (12 112 B, 2026-09-08 06:57) lo dejó el D8 que murió. **No se da por bueno.**
Lo que contiene, leído línea a línea:

- `MundoL9` — extiende `r8c_sim.Mundo`, sobrescribe el bucle para ejecutar la maniobra
  **adaptativa** del Lema 9 (`phantom-ghostdag.txt` L1131-1141): retener `J` bloques privados y
  soltarlos cuando `_key(tip_privado) > _key(sp_honesto)`. Reutiliza `_padres`
  (`pick_virtual_parents`) sin tocarlo. Contadores: `n_rafagas`, `n_abandonos`, `n_intentos`,
  `n_bloques_priv`, `n_bloques_perdidos`.
- `MundoDosVistas` — dos honestos `H_A`, `H_B` con `Δ` entre ellos; el atacante entrega a uno solo.
- `delta_hon`, `vista_en` — lecturas.

**Defecto encontrado en la lectura (declarado antes de usarlo):** en `corre_l9`,
`sp_h = d.virtual_sp(pub)` con `pub = [h for h in llega]` toma **todos los bloques entregados,
incluidos los que aún viajan** (`llega[b] = t + Δ`). Eso **no es** el padre seleccionado que el
honesto usará en `t`; es la vista omnisciente del atacante. La maniobra del Lema 9 exige superar
**la cadena que el honesto ve**. Se corrige y se parametriza (`vista_sp`), y se mide con las dos.

**Validación obligatoria antes de reutilizar** (encargo explícito): reproducir `m_SLOT = 2,54`
en las 12 semillas de `d9-ronda8f/salida_b1_gran1.txt` (`copias=14`, `α=0,25`, `gran=1,0`).
Resultado: **REPRODUCIDO exactamente** (§A0).

### 0.4 · Reglas que este informe respeta

1. Criterio `α` (fila `α = 0` en toda tabla). 2. Contadores de cobertura de rama.
3. ≥ 12 semillas. 4. El instrumento demuestra primero que **puede** detectar lo que busca.
5. `AUDITA_SCRIPTS.py` antes de entregar, salida declarada. 6. Etiquetas REFUTADO / SIN VECTOR /
TENSIÓN / LAGUNA. 7. Fichero y línea, o LAGUNA. 11. Adversario del paper, sin retardo.

---

## A0 · Validación del instrumento — **REPRODUCIDO**

Encargo: reproducir `m_SLOT = 2,54` en las 12 semillas de `d9-ronda8f/salida_b1_gran1.txt`.

Ejecutado `python3 d9-ronda8f/r8f_b1_slot.py 1.0` de cero (`salida_a0_reproduccion.txt`).
`diff` contra `salida_b1_gran1.txt` **a partir de la línea 9: idéntico salvo el tiempo de
ejecución** (623 s vs 652 s). En particular:

| copias | α | `m_BS` | **`m_SLOT`** | `ancla!=` | `equiv!=` |
|---:|---:|---:|---:|---:|---:|
| 14 | 0,00 | 1,000 | **1,000** | 462 / 1 764 | 0 |
| 14 | 0,25 | 6,052 | **2,540** | 18 404 / 26 838 | 0 |
| 14 | 0,40 | 6,167 | **3,024** | 28 938 / 37 674 | 0 |

Criterio `α` ✓ (`α=0 ⇒ m=1`). Capacidad ✓ (`ancla!=` ≫ 0: las dos anclas **no** son la misma
columna). Equivalencia «primer bloque con `slot ≥ S`» ≡ «menor `blue_work` con `slot ≥ S`» ✓
(0 discrepancias en 26 838 comprobaciones).

**Qué hice con `d8_lib.py`** (el fichero del D8 muerto): lo **leí entero, encontré un defecto,
lo corregí y lo extendí**. No lo di por bueno. En detalle:

1. **Defecto corregido.** `corre_l9` usaba `sp_h = d.virtual_sp(todo lo entregado)`, que
   incluye los bloques **aún en vuelo** (`llega = t+Δ`). Eso no es el padre seleccionado que
   el honesto usa en `t`: sobreestima al honesto y **retrasa la publicación de la ráfaga**,
   es decir, debilita al atacante. Ahora es un parámetro `vista_sp` con `'honesta'` por
   defecto (la vista real del nodo) y `'paper'` como control.
2. **Extensión: `modo='parasito'`** (nuevo, no existía en D9-c/d/e/f). Cada bloque privado
   fusiona la **vista honesta del instante** más la punta privada, así que el atacante
   hereda el `blue_work` honesto y su ventaja crece a ritmo `α` **sin carrera**. Toda la
   familia de D9 publica inmediatamente o con retraso fijo; ninguna acumula una cadena que
   fusione. Es la maniobra que hace ejecutable el Lema 9 con `α < 1/2` (§A1).
3. **Extensión: cierre de ancestros en la entrega** (`MundoDosVistas._entrega`). Entregar un
   bloque entrega **todo su pasado**: un nodo no valida sin ancestros. El código heredado
   entregaba bloques sueltos, lo que **sobreestimaba** el poder de retención selectiva.
4. **Contadores nuevos:** `n_score_ok` (veces que se cumplió la condición de score del Lema 9
   aunque faltaran bloques), `n_sesgados`, `n_ambos`.


## A1 · Sostenibilidad del sesgo del Lema 9 — **REFUTADO**

> **Veredicto: la cota `δ ≤ 2Dλ/(k+2Dλ)` del Lema 9 NO es el caso peor. Hay una maniobra
> ejecutable con `α < 1/2` que la supera, y el `δ` sostenible es una FUNCIÓN de `α`, no una
> constante. Cuesta ~3 puntos de umbral. El umbral publicado de ~35 % sobrevive.**

**Scripts:** `d8_a1_lema9.py` → `salida_a1.txt`; `d8_a1b_umbral.py` → `salida_a1b.txt`;
`d8_a1c_riesgo.py` → `salida_a1c.txt`. **Instrumento:** `d8_lib.MundoL9`.

### A1.1 · La maniobra literal del Lema 9 NO se sostiene — y ese es el punto de partida

`phantom-ghostdag.txt` L1131-1141 describe **un evento**: publicar `k+1` bloques en el
anticono del padre seleccionado, con el último a score ≥ el del padre. Un evento no es un
ritmo. Cada ráfaga consume `J ≥ k+1` bloques del atacante; fabricarlos cuesta `J/(αλ)` s.

Medido (`salida_a1.txt`, 12 semillas, horizonte 600 s, familia
`modo × J × d_fork × giveup` = 84 estrategias, ventana [60, 540] s):

| `α` | `δ` máx con `modo='cadena'` (la lectura literal) | ráfagas ejecutadas |
|---:|---:|---:|
| 0,25 | — | **0** |
| 0,40 | — | **0** |
| 0,55 | 0,9686 | 36 |
| 0,70 | 1,0000 | 155 |

**La cadena privada pura es una carrera de Nakamoto y el atacante la pierde con `α < 1/2`:
0 ráfagas ejecutadas hasta `α = 0,45`.** El contador `n_rafagas` lo demuestra; el control
`α ∈ {0,55, 0,70}` demuestra que el instrumento **sí ve** la maniobra cuando existe (regla 4).

### A1.2 · La maniobra que SÍ se sostiene: la cadena parásita

**Construcción (nueva; ninguna estrategia de D9-c/d/e/f la contiene).** El atacante mantiene
una cadena privada en la que **cada bloque fusiona la vista honesta del instante** más la
punta privada. Su `blue_work` = `blue_work` honesto del instante `− Δ` **más sus propios
bloques**: hereda todo el trabajo honesto y su ventaja crece a ritmo `α` **sin carrera**.
La publica cuando `key(punta privada) > key(sp honesto)` y ha acumulado `J` bloques.

El daño no es el del Lema 9. Los bloques honestos que fusiona **también se vuelven rojos**
en cuanto la cadena privada acumula más de `k` bloques en su anticono: un honesto creado en
`s` tiene en su anticono **todos** los `A_j` con `t_j < s + Δ`, y eso crece sin límite
mientras dure la ráfaga. **Es un mecanismo que el argumento del Lema 9 no cubre** — el paper
sólo cuenta *«the blocks in the anticone of the old selected parent»*, `2Dλ` en media.

**Medido** (`salida_a1b.txt`, horizonte 1 800 s, 12 semillas, `J*` = mejor de {16,31,48,64,96}):

| `α` | `J*` | **`δ` medido** | `(1−α)(1−δ)` | `r = α/((1−α)(1−δ))` | `α*` orden | ráfagas | rechazos | prof. ráfaga |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 16 | **0,0000** | 1,0000 | 0,000 | 0,4757 | 0 | 0 | — |
| 0,25 | 16 | 0,1544 | 0,6342 | 0,394 | 0,4341 | 333 | 0 | 64 s |
| 0,30 | 31 | 0,2079 | 0,5544 | 0,541 | 0,4181 | 205 | 0 | 103 s |
| 0,33 | 31 | **0,2867** | 0,4779 | 0,691 | 0,3929 | 225 | 0 | 94 s |
| 0,35 | 31 | **0,3065** | 0,4508 | 0,776 | 0,3862 | 239 | 0 | 89 s |
| 0,37 | 48 | **0,3448** | 0,4128 | 0,896 | 0,3728 | 162 | 0 | 130 s |
| 0,40 | 48 | **0,4366** | 0,3381 | **1,183** | 0,3382 | 173 | 0 | 120 s |
| 0,45 | 64 | 0,5834 | 0,2291 | 1,964 | 0,2743 | 146 | 0 | 142 s |

Cotas del diseño: `δ` nominal (Lema 9, `λ=1`) = **0,2105**; `δ_real` (con inflación del
retarget) = **0,267**. El `δ` medido las cruza en `α ≈ 0,30` y `α ≈ 0,32`.

- **Criterio `α` ✓** — `α=0 ⇒ δ=0`, ráfagas 0.
- **Cobertura ✓** — `raf` > 0 en toda fila con `α > 0`; `sok` (veces que se cumplió la
  condición de score) de 5 408 a 9 676.
- **Legalidad ✓** — `rech = 0`: **ningún** bloque del atacante fue rechazado por
  `MergeSetTooBig`, `U2` ni exceso de padres. La maniobra es legal bajo R-FIN-11 y R-FIN-12.
- **R-FIN-7 no la ve** — la profundidad de cada ráfaga es de 64 a 142 s, contra
  `F = 19 080 s`. La regla de finalidad **no protege** contra esto.
- **Estable con el horizonte** — a `α=0,40`, `J=48`: `δ` = 0,4008 (600 s), 0,3740 (1 200 s),
  0,4480 (2 400 s). No es un efecto de borde.

### A1.3 · Lo que mueve, propagado con el modelo del propio diseño

`d8_a1c_riesgo.py` reutiliza **sin reescribirla** la carrera de Skellam de
`verif_constantes.py:44-50` (Lema 10, ventaja inicial `3k = 90`), con `I = 4 200 s`,
`F = 19 080 s`, 7 509 épocas/año:

| `α` | `δ` | reversión 600 s | `p_F` por época | unión 10 años |
|---:|---:|---:|---:|---:|
| 0,25 | **medido 0,1544** | **3,0·10⁻¹⁰** | 1,0·10⁻²⁸³ | 7,5·10⁻²⁷⁹ |
| 0,25 | `δ_real` 0,267 | 1,9·10⁻⁵ | 2,8·10⁻²⁴⁰ | 2,1·10⁻²³⁵ |
| 0,35 | **medido 0,3065** | 0,928 | **5,4·10⁻⁵⁰** | **4,0·10⁻⁴⁵** |
| 0,35 | `δ_real` 0,267 | 0,767 | 6,8·10⁻⁷⁷ | 5,1·10⁻⁷² |
| 0,37 | **medido 0,3448** | 0,999 | 2,4·10⁻⁹ | **1,8·10⁻⁴** |
| 0,37 | `δ_real` 0,267 | 6,9·10⁻⁴⁰ | — | 5,1·10⁻³⁵ |

> ⚠️ Las filas `α ≥ 0,40` con `δ` medido dan `r ≥ 1`: ahí la cota **es vacua por
> construcción** y los números que imprime `prev()` (1,96·10⁻¹⁰, 0) son **artefacto
> numérico del recorte a `r^700`**, no un riesgo bajo. Se dejan en la salida marcados.

**Los tres números del diseño, corregidos:**

| | Diseño | **D8, con `δ` medido** |
|---|---:|---:|
| `r` cruza 1 (la garantía de flujo se vuelve vacua) | 43,1 % | **38,1 %** |
| Umbral de **orden** (punto fijo `α = α*(δ(α))`) | 40,0 % | **37,1 %** |
| Frontera de flujo único (`P < 10⁻¹⁰` en 10 años) | ≈ 39,3 % | **≈ 36,7 %** |
| Región de operación publicada `α ≲ 35 %` | ✓ | **✓ sobrevive** (4,0·10⁻⁴⁵) |
| Reversión a 600 s, `α = 0,25` | 6,6·10⁻⁸ | **3,0·10⁻¹⁰** (mejor) |

**Respuesta literal a A1:** el `δ` sostenible real es
`δ(α) ≈ {0 (α=0); 0,154 (0,25); 0,208 (0,30); 0,287 (0,33); 0,307 (0,35); 0,345 (0,37);
0,437 (0,40); 0,583 (0,45)}`. **Por debajo de `α ≈ 0,30` el diseño es conservador** (el `δ`
real es la mitad del supuesto); **por encima, la cota del paper se rompe** y todo lo que
cuelga de ella se mueve ~3 puntos a la baja.

**Etiqueta: REFUTADO** (ataque ejecutable, legal bajo las reglas, medido en 12 semillas y
tres horizontes). **Alcance: acotado** — no rompe la región de operación publicada.

**LAGUNA que abre:** el `δ` medido no incluye la inflación del retarget
(`dag-poas-delta-real.md` §1: `λ_real = λ·k/(k−2Dλ_obj)`). Si se compone, `δ` sube más. La
composición **no está medida** — mi simulador no tiene retarget.

---

## A2 · Acuerdo honesto con DOS vistas — **SIN VECTOR con esta familia**

**Script:** `d8_a2_dosvistas.py` → `salida_a2.txt`. **Instrumento:** `d8_lib.MundoDosVistas`
(con el cierre de ancestros que añadí, §0.3).

Dos honestos `H_A` y `H_B` con `Δ = 4 s` entre ellos, atacante del paper sin retardo capaz de
entregar a uno solo. Se lee el ancla por `slot` **en cada vista por separado** en
`t = T_j + D`, y se comparan por `seed`. 12 semillas × 11 umbrales × 24 estrategias
(`pol` × `sesgo` × `frac`) = **3 168 comparaciones por celda**.

**Máximo sobre la familia del atacante:**

| `α` | D=4 s | D=8 s | D=16 s | D=32 s | D=64 s | D=128 s | D=256 s | D=512 s | `div_sp` |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 1,000 | 0,886 | 0,644 | 0,348 | 0,0833 | **0,0076** | 0 | 0 | 0,980 |
| 0,10 | 1,000 | 0,870 | 0,455 | 0,174 | 0,0379 | 0 | 0 | 0 | 0,952 |
| 0,25 | 1,000 | 0,608 | 0,220 | 0,0152 | 0 | 0 | 0 | 0 | 0,895 |
| 0,33 | 1,000 | 0,553 | 0,144 | 0,0152 | 0 | 0 | 0 | 0 | 0,866 |
| 0,40 | 1,000 | 0,504 | 0,106 | 0,0152 | 0 | 0 | 0 | 0 | 0,839 |

**Capacidad ✓:** `div_sp` = 0,84-0,98 — las dos vistas tienen padre seleccionado **distinto**
en la gran mayoría de los instantes; la medida no es una tautología. En D=4 s el desacuerdo
del ancla es del 100 %: el instrumento detecta lo que busca.

**Dos lecturas, y la segunda es la incómoda:**

1. **A `D ≥ 128 s` el desacuerdo es 0 en 3 168 muestras, para todo `α`.** El instante de
   aplicación del diseño es `t_j = slot(I_j) + L` con `L = F = 19 080 s`, **149× más profundo**
   que el último punto donde se ve algo. La objeción «Risk = 1» de D9-a §4c **no tiene vector
   con esta familia**. Resolución del instrumento: `< 3,2·10⁻⁴`; la cota `p_F` que el diseño
   invoca es de `10⁻⁵⁰`, así que **no la confirmo — sólo digo que no la contradigo**.
2. **La fila `α = 0` es la PEOR.** El desacuerdo *baja* al subir `α`. La razón es estructural:
   el adversario del paper (regla 11, `phantom-ghostdag.txt` L1024-1027) **no sufre retardo, y
   por tanto entrega a los dos honestos a la vez**: cada bloque suyo es un **sincronizador**.
   Con `α = 0,40` el 40 % de los bloques llega simultáneamente a ambos y las vistas convergen
   antes. **El adversario del paper no es el adversario adecuado para esta pregunta.**

**LAGUNA declarada:** partir de verdad dos vistas honestas exige retardar el enlace
**honesto↔honesto**, que es control de red y **está fuera del modelo del paper y de este
simulador**. Con `Δ` como único parámetro no hay forma de expresarlo. Quien quiera cerrar
esta línea necesita un modelo de red, no un modelo de DAG. **Etiqueta: SIN VECTOR con esta
familia + LAGUNA de modelo.**

---

## A6 (parte económica) · El margen del lookahead — **REFUTADO**

**Script:** `d8_a6_presupuesto.py` → `salida_a6.txt`.

Lookahead = `I + F` (R-FIN-2: `entropía_j` se fija en `slot(I_j)` y rige de `t_j = slot(I_j)+L`
a `t_{j+1}`). El script **reproduce el número del diseño**: con `I = 2 490 s`, `F = 3,2 h` →
3,89 h → 10,57× y 1,054×, que es el «10,6× y 1,05×» de §4.2. Con las constantes nuevas:

| caso | `m` | `I` (h) | `F` (h) | **lookahead (h)** |
|---|---:|---:|---:|---:|
| medida, gratis | 2,079 | 0,74 | 3,35 | 4,09 |
| **medida, +retención — la del diseño** | **2,548** | **1,11** | **5,03** | **6,14** |
| garantía `S_max = 20 s` (`m ≤ 21`) | 21 | 7,65 | 34,77 | 42,42 |
| garantía `S_max = 30 s` (`m ≤ 31`) | 31 | 9,06 | 41,20 | 50,27 |
| **garantía `S_max = 150 s` (`m ≤ 151`)** | 151 | 15,07 | 68,49 | **83,56** |

**Margen = `A*` / lookahead. Por debajo de 1, plotear dirigido con GPU sale más barato que
comprar SSD** (`dag-poas-ancla-de-finalidad.md` §1):

| caso | A hoy | **A 10×** | B hoy | **B 10×** | C hoy | **C 10×** |
|---|---:|---:|---:|---:|---:|---:|
| medida, gratis | 15,41 | 1,54 | 10,03 | 1,00 | 16,88 | 1,69 |
| **la del diseño** | 10,26 | **1,03** | 6,68 | **0,67** | 11,24 | **1,12** |
| garantía `S_max=20 s` | 1,49 | 0,15 | **0,97** | 0,10 | 1,63 | 0,16 |
| garantía `S_max=30 s` | 1,25 | 0,13 | **0,82** | 0,08 | 1,37 | 0,14 |
| **garantía `S_max=150 s`** | **0,75** | 0,08 | **0,49** | 0,05 | **0,83** | 0,08 |

**Dos hallazgos, y el segundo es el que rompe:**

1. **El «número delgado» del diseño ya no es 1,05×: es 0,67×.** Con las constantes nuevas y
   el escenario de precios que el propio documento marca como *favorable al atacante*, un
   plotter 10× mejor que la extrapolación **gana**. En el escenario A queda en 1,03×: nulo.
2. **La garantía por construcción es económicamente inviable.** `m ≤ 1 + λ·S_max[s]` es lo
   único que respalda al diseño si la `m` medida resulta optimista — y con `S_max = 150 s`
   (el valor que R-FIN-7 necesita para tolerar particiones con `f ≥ 0,09`) el lookahead sube
   a **83,6 h** y el margen cae a **0,49-0,83× contra la GPU de hoy**, sin necesidad de
   ningún plotter futuro. Ni siquiera el `S_max = 20 s` mínimo de R-FIN-1a lo salva (0,97×
   en el escenario B).

**Inversión: qué `S_max` admite el presupuesto** (usando la propia garantía del diseño):

| exigencia | lookahead máx | `m` máx | **`S_max` máx** |
|---|---:|---:|---:|
| margen 1× frente a B hoy (41 h) | 41,00 h | 19,6 | **18,6 s** |
| margen 1× frente a A hoy (63 h) | 63,00 h | 57,4 | 56,4 s |
| margen 1× frente a B 10× (4,1 h) | 4,10 h | 2,08 | **1,1 s** |
| margen 1× frente a A 10× (6,3 h) | 6,30 h | 2,58 | **1,6 s** |

**R-FIN-1a exige `S_max ∈ [20, 150] s`. El presupuesto económico exige `S_max ≤ 18,6 s`
(hoy, escenario B) o `≤ 1,6 s` (frente a un plotter 10×). Los dos intervalos no se cortan.**
Es la misma clase de contradicción que D9-d demostró entre R-FIN-1a y la letra antigua de
R-FIN-7, ahora entre R-FIN-1a y §4.2.

**Etiqueta: REFUTADO** — no por simulación, por aritmética sobre las constantes publicadas y
las tablas de precios del propio proyecto. El diseño **sólo se sostiene sobre la `m` medida
(2,548), no sobre su garantía**; y aun así su margen frente al escenario tecnológico que él
mismo enumera es **0,67×**.


## A5 · Soborno BDK+19 §2 portado a PoAS — **REFUTADO (por otra vía que la del paper)**

**Scripts:** `d8_a5_soborno.py` → `salida_a5.txt`; `d8_a5b_equilibrio.py` → `salida_a5b.txt`.

### A5.1 · La aritmética de BDK **no** porta — y hay que decirlo primero

`bdk19.txt` L284-296: *«If the adversary gets more than κ+1 miners to respond… it only
requires κ+1 out of the next 2κ miners each holding a potentially infinitesimal fraction of
stake»*. Eso funciona porque **en Ouroboros cada slot tiene un líder exclusivo**: vaciando
κ+1 de 2κ+1 slots, la cadena honesta sólo puede tener κ bloques y la bifurcación sobornada
es más larga por construcción.

**En PoAS no hay calendario exclusivo.** Ganar es un Poisson sobre el espacio: sobornar `β`
da tasa `βλ` y los no sobornados siguen a `(1−β)λ`. Para superar a la cadena honesta hace
falta `β` por encima del umbral del sistema (35-40 %, §A1), no `κ+1` granjeros
infinitesimales. **El doble gasto de BDK §2 NO se compra con la ventana de predicción.**

### A5.2 · Lo que sí se compra: el ancla, a precio de saldo

R-FIN-1 lee `I_j` = el bloque de cadena con menor `blue_work` con `slot ≥ T_j`. R-FIN-2 fija
la entropía en `slot(I_j)` y la aplica `L = F = 5,3 h` después: **todo granjero conoce sus
victorias con 5,3 h de antelación**. El sobornador también. Le basta con pagar a los pocos
que van a producir los bloques del cruce para que **retengan** — no para que equivoquen: sin
doble firma, la negabilidad de BDK (L299-301) queda intacta y U3″ ni se entera.

**Medido** (`salida_a5.txt`, `MundoSoborno`, 12 semillas × 21 umbrales, horizonte 400 s):

| `α` | b=0 | b=1 | b=2 | b=3 | b=5 | b=8 |
|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | **1,000** | 2,000 | 3,000 | 4,000 | 6,000 | 9,000 |
| 0,10 | 1,000 | 2,000 | 3,000 | 4,000 | 6,000 | 9,000 |
| 0,25 | 1,000 | 2,000 | 3,000 | 4,000 | 6,000 | 9,000 |
| 0,33 | 1,000 | 2,000 | 3,000 | 4,000 | 6,000 | 9,000 |

**`m = b + 1`, exactamente, y con independencia de `α`.** Capacidad ✓ (`b=0 ⇒ m=1`: sin
soborno no hay menú). El resultado más importante es la **columna `α = 0`**: el sobornador
**no necesita espacio propio para fabricar candidatos, sólo dinero para retirarlos**. Toda la
derivación de `I` y `F` supone lo contrario: `m` es la que un atacante consigue **produciendo
sus propios bloques** (`m = 2,548`, D9-f). Con soborno **`m` es una variable de decisión del
atacante**, no una propiedad del protocolo.

### A5.3 · El balance, con las constantes publicadas

`valor = c_m·√(αλI)` bloques/época (el modelo del propio diseño,
`dag-poas-voto-auditoria.md` L197-199); `coste ≥ b = m−1` bloques (una recompensa por
granjero retirado — **cota inferior del coste**, así que el resultado es el favorable al
atacante y hay que leerlo como tal).

| `α` | b=1 | b=2 | b=4 | b=8 | b=16 | b=32 | b=64 | **b máx rentable** |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0,10 | 11,6 | 8,7 | 6,0 | 3,8 | 2,3 | 1,3 | 0,75 | **45** |
| 0,25 | 18,3 | 13,7 | 9,4 | 6,0 | 3,6 | 2,1 | 1,19 | **78** |
| 0,40 | 23,1 | 17,3 | 11,9 | 7,6 | 4,6 | 2,7 | 1,50 | **103** |

**Un solo soborno rinde 12-23× su coste.** El steering deja de ser un `g = 3,6 %` acotado por
la capacidad del atacante y pasa a ser un mercado.

### A5.4 · El punto fijo que rompe el diseño

Si `m` la elige el sobornador, `I = (c_m/g)²/(αλ)` hay que redimensionarla para **su** `m`, y
`F = I/(W/κ − 1)`, y `lookahead = I + F` — que tiene techo económico (§A6). Punto fijo del
sobornador racional (`argmax` valor − coste), `salida_a5b.txt`:

| `α` | **`m*`** | `c_m*` | `I` (h) | `F` (h) | **lookahead (h)** | margen vs `A*`=41 h |
|---:|---:|---:|---:|---:|---:|---:|
| **0,10** (el que usa el diseño) | **23** | 1,929 | 7,98 | 36,26 | **44,24** | **0,93×** |
| 0,25 | 23 | 1,929 | 3,19 | 14,50 | 17,69 | 2,32× |
| 0,33 | 23 | 1,929 | 2,42 | 10,99 | 13,40 | 3,06× |
| 0,40 | 23 | 1,929 | 1,99 | 9,06 | 11,06 | 3,71× |

Y el **tope duro es R-FIN-1a, que resulta ser la propia «garantía por construcción»**:
retirar `b` bloques de cadena consecutivos abre un hueco de `b/λ` segundos, y R-FIN-1a lo
corta en `S_max`. Luego `m ≤ 1 + λ·S_max` — **la misma cota que el diseño trata como lejana**.

| `S_max` | `m ≤ 1+λ·S_max` | `I` (h) | `F` (h) | lookahead (h) | margen vs `A*`=41 h |
|---:|---:|---:|---:|---:|---:|
| 20 s | 21 | 7,65 | 34,77 | 42,42 | **0,97×** |
| 30 s | 31 | 9,06 | 41,20 | 50,27 | **0,82×** |
| 150 s | 151 | 15,07 | 68,49 | 83,56 | **0,49×** |

**Etiqueta: REFUTADO.** No por el mecanismo del paper, sino por el que la ventana de
predicción habilita en PoAS: **el soborno desacopla `m` de `α`**, y `m` es la variable de la
que cuelgan `I`, `F` y el lookahead. El diseño mide `m = 2,548` suponiendo un atacante que
sólo puede usar sus propios bloques; con `1-23` recompensas por época esa suposición no se
sostiene, y el lookahead resultante (44 h con `α = 0,10`) **cae por debajo de `A*` = 41 h**.

**Lo que NO afirmo:** que el sobornador consiga un doble gasto (A5.1 dice que no), ni que el
coste real del soborno sea exactamente una recompensa (es la cota inferior; con una prima de
`p×` el `b` rentable cae a `b_max/p` y `m*` con él). Con `p = 3`, `m* ≈ 12` y el lookahead a
`α=0,10` sigue en 34 h (margen 1,2× frente a `A*`, 0,12× frente al plotter 10×).


## A6 (líneas 5 y 3 de §7) · `3k` y el `shuffle` — **SIN VECTOR (a favor del diseño)**

**Scripts:** `d8_a6b_lineas.py` → `salida_a6b.txt`; `d8_a6c_shuffle.py` → `salida_a6c.txt`.

### Línea 5 · ¿es `3k` la ventaja real o sólo una cota? — **sólo una cota, y holgada**

Toda la tabla de riesgo desplaza la carrera por `3k = 90` (Lema 10, `phantom-ghostdag.txt`
L1226-1236). D9-b midió 26 con estrategias que publican al instante. **Con la maniobra
parásita de A1, que es la que más ventaja acumula, tampoco se llega:**

| `α` | ventaja máx (mejor `J`) | `/k` | `/3k` | n_medidas |
|---:|---:|---:|---:|---:|
| **0,00** | — (`n_medidas = 0`: sin atacante no hay ventaja que medir) | — | — | **0** |
| 0,10 | 17 | 0,57 | 0,19 | 2 190 |
| 0,25 | 30 | 1,00 | 0,33 | 5 408 |
| 0,33 | **50** | 1,67 | **0,56** | 7 144 |
| 0,40 | 41 | 1,37 | 0,46 | 8 614 |

**Máximo absoluto 50 = 1,67 `k` = 0,56 · `3k`.** La cota `3k` **no se alcanza**, ni siquiera
con la maniobra que refuta el Lema 9. **Etiqueta: SIN VECTOR** — y es un punto **a favor** del
diseño: la tabla de riesgo de A1.3, que usa `3k`, es **pesimista** en este eje, lo que
amortigua en parte el `δ` mayor.

### Línea 3 · rojos cerca del cruce con U3″: ¿basta el `shuffle`? — **la pregunta no se decide en este régimen**

**Hallazgo previo, que hay que declarar:** el simulador de D9
(`r8c_sim.Mundo._padres`) **no implementa el `shuffle`** que R-FIN-12 declara obligatorio
(`processor.rs:1069-1089`). Lo implementé fiel (`MundoL9Shuffle`) y medí las dos:

| `α` | `J` | `δ` SIN shuffle | `δ` CON shuffle | `n_shuffles` |
|---:|---:|---:|---:|---:|
| 0,00 | 31 | 0,0000 | 0,0000 | 2 199 |
| 0,25 | 31 | 0,1084 | 0,1084 | 677 |
| 0,33 | 31 | 0,2867 | 0,2867 | 377 |
| 0,40 | 48 | 0,4366 | 0,4366 | 261 |

**Idénticos a cuatro decimales.** La causa, medida (`salida_a6c.txt`, 10 790 selecciones de
padres por fila, 12 semillas):

| `α` | padres distintos | de | puntas máx | puntas medias | veces puntas > `mp` |
|---:|---:|---:|---:|---:|---:|
| 0,00 | **0** | 10 790 | 13 | 4,92 | **0** |
| 0,25 | **0** | 10 790 | 12 | 2,89 | **0** |
| 0,40 | **0** | 10 790 | 9 | 2,22 | **0** |

Con `λΔ = 4` el número de puntas **nunca** alcanza `max_block_parents = 15`, así que el
`shuffle` no llega a activarse y da exactamente los mismos padres. Dos consecuencias:

1. **La pregunta de la línea 3 no se decide aquí.** Las «~550 puntas» de D9-d A3.1 vienen de
   un escenario de fabricación masiva de puntas, no del régimen de operación.
2. **Que el simulador de D9-c/d/e/f no lo implemente NO invalida sus medidas** — en su
   régimen es un no-op. Es la primera vez que esto se comprueba en vez de suponerse.

**Etiqueta: SIN VECTOR con esta familia + LAGUNA** (el régimen donde el `shuffle` sí importa
—>15 puntas simultáneas— no está cubierto por ninguna medida de esta ronda ni de las de D9).


### A1.4 · Autocrítica: ¿es LEGAL la maniobra parásita bajo R-FIN-1a? — **sí**

**Script:** `d8_a1d_rfin1a.py` → `salida_a1d.txt`.

El simulador heredado (`r8c_gd.DAG.add`) valida `max_block_parents`, `mergeset_size_limit`,
U2 y U3″, **pero no R-FIN-1a**. Es un hueco del instrumento que juega **a mi favor**, así que
había que cerrarlo antes de firmar A1. Medida de `slot(B) − slot(sp(B))` de los bloques del
**atacante** bajo la maniobra parásita, y `δ` recalculado rechazando los ilegales:

| `α` | frac. > 4 s (control) | **> 20 s** | > 30 s | > 150 s | gap máx | gap medio | `n_a` |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | *(n_a = 0: la fila no dice nada)* | | | | | | **0** |
| 0,10 | 0,4845 | 0,00000 | 0 | 0 | 15 | 4,36 | 2 190 |
| 0,25 | 0,3118 | 0,00074 | 0 | 0 | 26 | 3,47 | 5 408 |
| 0,33 | 0,2269 | 0,00014 | 0 | 0 | 24 | 2,87 | 7 144 |
| 0,40 | 0,1661 | 0,00012 | 0 | 0 | 24 | 2,46 | 8 614 |

`δ` con R-FIN-1a aplicada (`S_max = 20 s`, el más restrictivo): 0,1091 vs 0,1084 (`α=0,25`);
0,2871 vs 0,2867 (`α=0,33`); 0,3283 vs 0,3217 (`α=0,37`) — **idéntico dentro del ruido, y en
algún caso mayor**. Ilegales: 1-15 bloques de 5 000-8 000. Control `S=4 s`: 17-48 % de
violaciones, luego el instrumento **sí detecta** ilegalidad cuando la hay.

**La maniobra parásita es legal bajo R-FIN-1a, R-FIN-11 y R-FIN-12.** No hay regla del
diseño que la impida.

### A1.5 · Lo que le CUESTA al atacante — **nada; a partir de `α = 0,33` le paga**

**Script:** `d8_a1e_coste.py` → `salida_a1e.txt`. `ing_x` = fracción de los bloques de `x`
que acaban **azules** en la vista honesta final (= su ingreso relativo).

| `α` | `J` | `ing_h` (=1−δ) | `ing_a` | **ratio a/h** | `n_h` | `n_a` | perdidos | % perdidos |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 16 | 1,0000 | *(n_a=0)* | — | 19 978 | 0 | 0 | — |
| 0,10 | 16 | 0,9777 | 0,3108 | 0,318 | 17 924 | 2 054 | 50 | 2,43 % |
| 0,25 | 16 | 0,8456 | 0,8414 | **0,995** | 14 921 | 5 057 | 5 | 0,10 % |
| 0,30 | 31 | 0,7921 | 0,6961 | 0,879 | 13 907 | 6 071 | 14 | 0,23 % |
| **0,33** | 31 | 0,7133 | 0,8264 | **1,159** | 13 297 | 6 681 | 25 | 0,37 % |
| **0,35** | 31 | 0,6935 | 0,8804 | **1,270** | 12 882 | 7 096 | 21 | 0,30 % |
| **0,37** | 48 | 0,6552 | 0,7572 | **1,156** | 12 499 | 7 479 | 58 | 0,78 % |
| **0,40** | 48 | 0,5634 | 0,8727 | **1,549** | 11 937 | 8 041 | 95 | 1,18 % |

**Dos consecuencias que cambian la naturaleza del hallazgo:**

1. **A `α = 0,25` la maniobra es GRATIS** (ratio 0,995: el atacante no pierde ingreso) y aun
   así impone `δ = 0,11-0,15`. Es *griefing* sin coste de oportunidad.
2. **A partir de `α = 0,33` es ESTRICTAMENTE RENTABLE** (ratio 1,16 a 1,55): la maniobra
   **aumenta la cuota de ingreso** del atacante. No es un ataque que alguien deba querer
   pagar: es lo que un granjero racional del 33 % **haría por dinero**. Los bloques del
   atacante no se tiran —forman la cadena ganadora y cobran su coinbase—; sólo pierde el
   0,1-1,2 % por retenciones fallidas.

**Y aquí engrana con A5:** si la maniobra se autofinancia, el `α` necesario **se puede
alquilar**. Los ganadores se conocen `L = 5,3 h` antes, así que un coordinador puede reunir
el 33 % apuntando granjeros a su cadena privada, y **pagarles con su propia coinbase**, que
cobran igual. El umbral de 35-37 % deja de ser una barrera de capital y pasa a ser un
problema de coordinación de una tarde.


## A3 · Partición + `S_max` + R-FIN-7 — **TENSIÓN** *(medidas parciales; se cierra abajo)*

**Script:** `d8_a3_smax.py` → `salida_a3.txt`.

R-FIN-1a no orfana: **invalida**. Un bloque con `slot(B) − slot(sp(B)) > S_max` es rechazado
por la red; R-FIN-8 ni se le aplica. D9-d A4.2 lo leyó como tolerancia a particiones; D8 le da
la vuelta: **es una regla de censura**. Tres medidas.

**(M1) Sin eclipse — peor fracción de bloques honestos con `gap > S_max`, sobre 30
estrategias del atacante (7 políticas × 4 retrasos + retención total), 12 semillas, 900 s:**

| `α` | S=4 s *(control)* | **S=20 s** | S=30 s | S=150 s | gap máx | `n_hon` |
|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 0,72216 | **0,00000** | 0,00000 | 0,00000 | 12 | 948 |
| 0,10 | 0,76788 | **0,00000** | 0,00000 | 0,00000 | 17 | 837 |
| 0,25 | 0,81719 | **0,00434** | 0,00000 | 0,00000 | 22 | 706 |
| 0,33 | 0,86426 | **0,00510** | 0,00000 | 0,00000 | 23 | 634 |
| 0,40 | 0,90714 | **0,01121** | 0,00000 | 0,00000 | 22 | 574 |

**Capacidad ✓** — el control `S = 4 s` marca el 72-86 %: el instrumento **sí** detecta
invalidaciones cuando existen. **Criterio `α` ✓** — la columna S=20 crece con `α`.

**Bloques honestos invalidados por hora** (`fracción × 3 600 × (1−α)`):
`α = 0,25` → **11,7/h** con `S_max = 20 s`; **0/h** con `S_max ≥ 30 s`.
`α = 0,33` → **12,3/h** con `S_max = 20 s`; **0/h** con `S_max ≥ 30 s`.
`α = 0,40` → **24,2/h** con `S_max = 20 s`; **0/h** con `S_max ≥ 30 s` (`d8_a3b_eclipse.py`).

**Sin partición real, el atacante NO puede provocar invalidaciones si `S_max ≥ 30 s`.** Con
`S_max = 20 s` sí, pero a ritmo bajo (una docena de bloques/hora sobre 2 700 honestos/hora:
0,4-0,5 %). **Etiqueta de M1: SIN VECTOR** (con esta familia) para `S_max ≥ 30 s`;
**TENSIÓN** para `S_max = 20 s`, que es el extremo que el presupuesto económico de A6 exige.


---

# VEREDICTO

> **Sí: hay un ataque que rompe el diseño con sus constantes, y son dos, que se refuerzan.**
> **(1)** La cota `δ` del Lema 9 no es el caso peor: una **cadena parásita** la supera, es
> **legal** bajo R-FIN-1a/11/12, R-FIN-7 no la ve, y a partir de `α = 0,33` **es rentable**
> — un granjero racional del 33 % la ejecutaría por dinero. Baja el umbral de orden de
> 40,0 % a **37,1 %** y la frontera de flujo único de ≈39,3 % a **≈36,7 %**.
> **(2)** El **soborno** desacopla `m` de `α` (`m = b+1` medido, `α = 0` incluido) a
> 1-23 recompensas por época, con retorno de 12-23×; y `m` gobierna `I`, `F` y el lookahead,
> que tiene techo económico. Con `α = 0,10` el lookahead de equilibrio es **44 h > `A*` = 41 h**.
> Y la **«garantía por construcción» `m ≤ 1+λ·S_max` es inviable en todo el rango de
> R-FIN-1a**: margen 0,49-0,97× frente a la GPU de **hoy**.
>
> **Lo que NO se rompe:** la región de operación publicada `α ≲ 35 %` sobrevive a (1)
> (`P(partición) = 4·10⁻⁴⁵` en 10 años). El acuerdo entre vistas honestas no tiene vector
> (A2). `3k` es holgada (A6b). El `shuffle` es un no-op en régimen (A6c).

## Tabla de veredictos

| Línea | Etiqueta | Número que la sostiene | Script |
|---|---|---|---|
| **A1** · sostenibilidad de `δ` | **REFUTADO** | `δ(0,33) = 0,287 > 0,267`; `δ(0,40) = 0,437`; umbral 40,0 → **37,1 %** | `d8_a1_lema9.py`, `d8_a1b_umbral.py`, `d8_a1c_riesgo.py` |
| A1.4 · legalidad de la maniobra | confirmada | `> S_max=20 s`: 0,00012-0,00074 de sus bloques | `d8_a1d_rfin1a.py` |
| A1.5 · coste para el atacante | **REFUTADO (incentivos)** | ratio ingreso a/h = **1,16-1,55** para `α ≥ 0,33` | `d8_a1e_coste.py` |
| **A2** · dos vistas honestas | **SIN VECTOR** + LAGUNA de modelo | `P(desacuerdo) = 0` en 3 168 muestras a `D ≥ 128 s`; `F` es 149× más profundo | `d8_a2_dosvistas.py` |
| **A3** · `S_max` y R-FIN-7 | **TENSIÓN** | 11,7-12,3 bloques honestos invalidados/h con `S_max=20 s`; **0** con `≥30 s` | `d8_a3_smax.py` |
| **A4** · cruce del ancla en régimen | ver §A4 | `m` reproduce 2,540 a `α=0,25`; escalado con el horizonte, §A4 | `d8_a4_cruce.py`, `d8_a4b_horizonte.py` |
| **A5** · soborno BDK | **REFUTADO** | `m = b+1` (incluso a `α=0`); valor/coste 12-23×; `m* = 23` | `d8_a5_soborno.py`, `d8_a5b_equilibrio.py` |
| **A6** · margen económico | **REFUTADO** | margen 10× plotter **0,67×** (era 1,05×); garantía `S_max=150` → **0,49×** | `d8_a6_presupuesto.py` |
| A6 · línea 5 (`3k`) | **SIN VECTOR** (a favor) | ventaja real máx 50 = **0,56 · 3k** | `d8_a6b_lineas.py` |
| A6 · línea 3 (`shuffle`) | **SIN VECTOR** + LAGUNA | 0 diferencias en 10 790 selecciones; puntas máx 13 < `mp`=15 | `d8_a6c_shuffle.py` |

## Los números pedidos, en una línea cada uno

- **`δ` sostenible real (A1):** `δ(α) = 0 / 0,154 / 0,208 / 0,287 / 0,307 / 0,345 / 0,437 /
  0,583` para `α = 0 / 0,25 / 0,30 / 0,33 / 0,35 / 0,37 / 0,40 / 0,45`. **No es una
  constante.** Cruza la cota del paper (0,2105) en `α ≈ 0,30` y `δ_real` (0,267) en `α ≈ 0,32`.
- **`P(desacuerdo)` con dos vistas (A2):** `1,000 / 0,504 / 0,106 / 0,015 / 0 / 0 / 0 / 0`
  a `D = 4/8/16/32/64/128/256/512 s` (`α = 0,40`, máximo sobre 24 estrategias). Resolución
  del instrumento `3,2·10⁻⁴`; `F = 19 080 s`.
- **Margen económico recalculado (A6):** lookahead `I + F = 6,14 h`; margen **10,26× / 6,68×
  / 11,24×** frente a `A*` de hoy (escenarios A/B/C) y **1,03× / 0,67× / 1,12×** frente al
  plotter 10×. Con la garantía (`S_max = 150 s`): **0,75× / 0,49× / 0,83×** frente a hoy.

## Salida de `AUDITA_SCRIPTS.py` (regla 5) — DECLARADA

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d8-ronda8
Scripts analizados: 17

d8_a1d_rfin1a.py   [T3b] L53: ['padres', 'ph'] = MISMA expresión: self._padres(d, visibles)
d8_a6b_lineas.py   [T3b] L93: ['padres', 'ph'] = MISMA expresión: m._padres(d, visibles)
d8_lib.py          [T3b] L109: ['padres', 'ph'] = MISMA expresión: self._padres(d, visibles)

======================================================================
Sospechas totales: 3
```
*(guardada en `salida_audita.txt`; es la ejecución final, sobre los 17 scripts)*

**Las tres marcas, leídas una a una.** Son el **mismo patrón** y son **falsos positivos
justificados**: en `corre_l9` la rama honesta hace `padres = self._padres(d, visibles)` (los
padres del bloque **honesto**) y la rama del atacante hace `ph = self._padres(d, visibles)`
(las puntas honestas que el **parásito** fusiona, antes de anteponer su punta privada). El
detector marca dos variables distintas con el mismo RHS textual; aquí están en ramas
distintas del `if` y alimentan bloques de creadores distintos. **No es la tautología de
`d8b_b3`** (donde `Ij_A` e `Ij_B` eran literalmente el mismo valor comparado consigo mismo):
el atacante usa deliberadamente la vista honesta, que **es** el mecanismo del ataque.
Ninguna marca T1 (parámetro `alpha` muerto), T2 (literal cableado), T3 ni T4 (semillas).

## Errores propios (regla 10)

1. **Heredé un instrumento con un defecto y no lo vi al primer vistazo.** `d8_lib.corre_l9`
   comparaba contra `virtual_sp(todo lo entregado)`, incluidos los bloques en vuelo. Lo
   encontré al releer, lo corregí y lo dejé parametrizado (§0.3). Debilitaba al atacante, así
   que no invalidaba resultados anteriores — pero era una lectura incorrecta del modelo.
2. **Mi primer instrumento de A2 no podía detectar lo que buscaba, y tardé en verlo.** El
   adversario del paper (sin retardo) **sincroniza** las dos vistas honestas en vez de
   partirlas; por eso la fila `α = 0` es la peor. Lo declaro como límite del modelo, no como
   resultado (§A2).
3. **Comparé mi `δ` (sin retarget) con `δ_real` (con retarget) sin decirlo en la primera
   pasada.** Corregido: la comparación estricta es contra `δ = 0,2105`; contra `δ_real` el
   cruce ocurre un poco más arriba (`α ≈ 0,32` en vez de 0,30). La composición de mi `δ` con
   la inflación del retarget **no está medida** — es LAGUNA, y va en la dirección mala.
4. **A4 lo escribí demasiado caro** (familia completa a horizonte 1 500 s) y tuve que
   reescalarlo a mitad de ronda; el resultado dirigido está en `d8_a4b_horizonte.py`.
5. **En A5 el coste del soborno lo puse en 1 recompensa por granjero, que es la cota
   inferior.** Además, el sobornador tiene que pagar a los **ganadores** de la ventana, no a
   los **bloques de cadena** (`λ` vs `λ_chain ≈ 0,76`), así que el coste real es ~1,3× el que
   uso. Con una prima `p`, el `b` rentable cae a `b_max/p`: con `p = 3·1,3 ≈ 4` sigue siendo
   rentable hasta `b ≈ 20` a `α = 0,25`.

## LAGUNAS (regla 7: lo que no se puede afirmar con fichero y línea)

1. **Composición de `δ_parásita` con la inflación del retarget.** `dag-poas-delta-real.md` §1
   infla `λ` porque el observador ve `λ(1−δ)`. Mi simulador no tiene retarget. Con
   `δ = 0,29` en vez de 0,21, `λ_real = k/(k−2Dλ_obj)` no cambia (es función de `λ_obj`), pero
   `δ_real = 2Dλ_real/(k+2Dλ_real)` sí subestima si el `δ` de partida es mayor. **No medido.**
2. **Partir dos vistas honestas de verdad** exige retardar el enlace honesto↔honesto: fuera
   del modelo del paper y de este simulador (§A2).
3. **El régimen donde el `shuffle` importa** (>15 puntas simultáneas) no lo cubre ninguna
   medida, ni mía ni de D9 (§A6c).
4. **`Dmax` sigue sin medir.** Todo usa `Δ = 4 s`. `δ` es proporcional a `2Dλ`: si `Dmax`
   fuera 8 s, `δ` nominal pasa a 0,348 y el umbral cae otros ~4 puntos. Es la variable más
   sensible del diseño **y la única que nadie ha medido.**
5. **`τ` (duración del slot de PoT) y las dos ramas A/B.** Todo lo que he medido usa
   `slot = ⌊t⌋` con `λ = 1` (rama A con `τ = 1 s`, que el propio diseño descarta). Con
   `τ ≈ 0,1 s` los gaps de R-FIN-1a se miden en 10× más slots, y `S_max` en segundos no
   cambia — pero el DoS de verificación de PoT sí (×10). **No medido en ninguna rama.**
6. **`m ≤ 1 + λ·S_max` con `τ ≠ 1 s`.** La tabla de D9-f (`salida_c.txt` §3) escribe
   `m ≤ 1 + λ·τ·S_max`, que da 16 con `τ = 0,1 s`. Eso sólo vale si `S_max` está en **slots**;
   R-FIN-1a lo escribe en **segundos**, y entonces `m ≤ 151` con independencia de `τ`.
   **Las dos lecturas están en el mismo documento y dan `F` de 30 h y de 68 h.** Es una
   ambigüedad de la regla, no un resultado: **hay que decidirla.**
7. **El precio del soborno** (A5) es un supuesto, como los precios de `A*`. Ambos se mueven.


### A3 (M2) · Eclipse parcial — **REFUTADO: `S_max` es un arma de censura, y no necesita espacio**

**Script:** `d8_a3b_eclipse.py` → `salida_a3b.txt`. Un honesto `H_C` con el **5 %** del
espacio recibe **todo** con `E` segundos de retraso extra (el atacante le retiene las puntas;
no le corta la red). Fracción de **sus** bloques que R-FIN-1a **invalida**:

| `E` (s) | `α` | S=4 s *(control)* | **S=20 s** | **S=30 s** | **S=150 s** | `n_C` |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0,00 | 0,6096 | 0,0000 | 0,0000 | 0,0000 | 561 |
| 0 | 0,25 | 0,2222 | 0,0000 | 0,0000 | 0,0000 | 414 |
| 10 | 0,25 | 0,8847 | 0,0025 | 0,0000 | 0,0000 | 399 |
| **20** | **0,00** | 0,8038 | **0,7150** | 0,0017 | 0,0000 | 586 |
| **20** | 0,25 | 0,9021 | **0,7474** | 0,0000 | 0,0000 | 388 |
| **40** | 0,25 | 0,8886 | 0,8481 | **0,8430** | 0,0000 | 395 |
| **200** | 0,25 | 0,8806 | 0,7687 | 0,7289 | **0,6816** | 402 |

**Un retraso de entrega apenas mayor que `S_max` silencia al granjero: el 68-85 % de sus
bloques queda INVÁLIDO**, no huérfano. Y la fila **`α = 0`** es igual de mala que la de
`α = 0,25`: **el atacante no necesita ni un byte de espacio.** Es un ataque de red
—eclipse parcial, retención de puntas, o simplemente estar mal conectado—, no de consenso.

**(M3) Eclipse total de un grupo con fracción `f`** (forma cerrada `P = e^{−fλS_max}`,
comprobada por Monte Carlo: medido 0,36732 vs cerrado 0,36788):

| `f` | S=20 s | S=30 s | S=150 s |
|---:|---:|---:|---:|
| 0,01 | 0,8187 | 0,7408 | 0,2231 |
| 0,05 | 0,3679 | 0,2231 | 0,00055 |
| **0,09** (el de R-FIN-7) | **0,1653** | 0,0672 | ~0 |
| 0,20 | 0,0183 | 0,0025 | ~0 |

El «`f ≥ 0,09`» de R-FIN-7 **sólo vale con `S_max = 150 s`**: con `S_max = 20 s` ese mismo
lado pierde el **16,5 %** de sus bloques por invalidez.

### A3 · Veredicto y la pinza que cierra

| | `S_max = 20 s` | `S_max = 30 s` | `S_max = 150 s` |
|---|---:|---:|---:|
| Honestos invalidados/h **sin eclipse**, `α=0,33` / `0,40` (M1) | 12,3 / 24,2 | 0 | 0 |
| Granjero con 20 s de retraso: bloques inválidos (M2) | **71-75 %** | 0,2 % | 0 |
| Granjero con 200 s de retraso (M2) | 77 % | 73 % | **68 %** |
| Partición con `f = 0,09`: inválidos (M3) | 16,5 % | 6,7 % | ~0 |
| **Margen económico del lookahead que exige su garantía (A6)** | **0,97×** | **0,82×** | **0,49×** |

**Etiqueta: REFUTADO.** No porque `S_max` esté mal elegida, sino porque **no hay elección
buena**: `S_max` pequeña hace que un retraso de red de 20 s invalide al 75 % de los bloques
de un granjero; `S_max` grande hace que la garantía `m ≤ 1+λ·S_max` no quepa en el
presupuesto económico. R-FIN-1a queda atrapada entre la red y la economía, igual que
D9-d la dejó atrapada entre R-FIN-7 y el DoS de PoT.

**Y una consecuencia de descentralización que hay que escribir:** con `S_max = 20 s`,
cualquier granjero cuya conectividad sea peor que 20 s **es inválido por consenso, no
huérfano**. No pierde una carrera: la red le rechaza los bloques. Es presión de
centralización de la misma clase que P-036.


## A4 · El cruce del ancla `slot` en régimen — **SIN VECTOR con esta familia**

**Scripts:** `d8_a4_cruce.py` → `salida_a4.txt`; `d8_a4b_horizonte.py` → `salida_a4b.txt`;
`d8_a4c_rachas.py` → `salida_a4c.txt`.

### A4.1 · ¿Sube `m` al pasar de horizontes ≤ 700 s al régimen?

`I = 4 200 s` y `F = 5,3 h` salen de `m = 2,548`, medida con horizonte 260 s y `P = 30`. Como
`I ∝ c_m²` y `F ∝ c_m²`, si `m` creciera con el horizonte las constantes estarían
infradimensionadas. Familia **fija** (la literal de D9-f), profundidad escalada:

| HOR | `P` | `α` | `m` medio | `m` máx | estrat | `equiv!=` |
|---:|---:|---:|---:|---:|---:|---:|
| 260 | 30 | **0,00** | **1,000** | 1 | 7 | 0 |
| 260 | 30 | 0,10 | 2,238 | 5 | 48 | 0 |
| 260 | 30 | 0,25 | **2,540** | 5 | 106 | 0 |
| 260 | 30 | 0,33 | 2,929 | 5 | 128 | 0 |
| 260 | 30 | 0,40 | **3,024** | 5 | 150 | 0 |
| 500 | 60 | 0,10 | **2,131** | 5 | 49 | 0 |
| 500 | 60 | 0,25 | **2,421** | 5 | 100 | 0 |

**Reproducción exacta de D9-f** en las tres celdas comparables (2,238 / 2,540 / 3,024) — dos
implementaciones independientes (`d8_a4_cruce.py` y `d8_a4b_horizonte.py`) dan el mismo
2,421 a HOR = 500. Y **`m` no crece: baja** (2,540 → 2,421 a `α=0,25`; 2,238 → 2,131 a
`α=0,10`). El cruce del ancla es un fenómeno **local** a la banda `[T_j, T_j + gap)`, no
depende de la profundidad a la que se lea. `equiv!=` = 0 siempre: «primer bloque con
`slot ≥ S`» ≡ «menor `blue_work` con `slot ≥ S`» se cumple en toda ejecución.

**`I` y `F` no están infradimensionadas por el horizonte.** Lo que sí las mueve es el
soborno (§A5), que no es un efecto de horizonte sino de modelo de atacante.

### A4.2 · ¿Puede retener y soltar justo antes de `S_max`? · A4.3 · ¿Cuántas épocas seguidas captura?

`d8_a4c_rachas.py`: 37 épocas por corrida (umbrales cada 20 s), 12 semillas = **444 épocas**,
9 estrategias sin retraso / 37 con retraso barrido hasta `S_max = 150 s` + retención total.

**Sin retraso (control):**

| `α` | `m` medio | `m` máx | `nA` | capturas sin dirigir | racha máx | capturas dirigidas | racha máx | de |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | **1,000** | 1 | **0** | **0** | **0** | **0** | **0** | 444 |
| 0,10 | 1,694 | 4 | 238 | 75 (16,9 %) | 2 | 82 | 2 | 444 |
| 0,25 | 2,029 | 5 | 485 | 154 (34,7 %) | 4 | 163 | 4 | 444 |
| 0,33 | 2,117 | 4 | 594 | 190 (42,8 %) | 6 | 201 | 7 | 444 |
| 0,40 | 2,122 | 4 | 708 | 224 (50,5 %) | **11** | 243 | **11** | 444 |

**Lectura.** (i) La captura del ancla es **más frecuente que `α`** (50,5 % a `α = 0,40`):
el atacante está sobrerrepresentado en la cadena seleccionada, no sólo en el DAG. (ii) Las
rachas son **compatibles con independencia**: con `p = 0,505` y 37 épocas por corrida,
`P(racha ≥ 11) ≈ 37·0,505¹¹ ≈ 0,019` por corrida, ≈ 0,22 en 12 corridas — una racha de 11 es
lo esperado, no una anomalía. **El supuesto de épocas independientes del modelo de steering
(`g = c_m/√(αλI)`) se sostiene.** (iii) Dirigir la estrategia añade poco (243 vs 224): el
grueso de la captura es estructural.

**Etiqueta: SIN VECTOR con esta familia.** El ancla por `slot` aguanta lo que se le pide en
régimen; su punto débil no es el cruce, es **quién puede pagar por moverlo** (§A5).


### A4.2 (continuación) · Retención hasta `S_max = 150 s` — **no rompe la cota**

Segunda tabla de `d8_a4c_rachas.py`, con los 5 retrasos (0/4/12/40/**150** s = `S_max`) más
retención total, 37 estrategias:

| `α` | `m` medio | `m` máx | `nA` | capturas sin dirigir | racha | capturas dirigidas | racha | de |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | **1,000** | 1 | **0** | 0 | 0 | 0 | 0 | 444 |
| 0,10 | **2,282** | 7 | 343 | 75 | 2 | 99 | **4** | 444 |

Retener y soltar justo antes de `S_max` sube `m` de **1,694 a 2,282** a `α = 0,10`
(**+35 %**) y las capturas dirigidas de 82 a 99. **Sigue por debajo de la `m = 2,548` con la
que el diseño dimensiona `I` y `F`**, así que la retención hasta `S_max` **no** las
infradimensiona.

> **DECLARACIÓN DE EJECUCIÓN INCOMPLETA (regla 10).** Las filas `α ∈ {0,25; 0,33; 0,40}` de
> esta tabla y las celdas `HOR ∈ {900, 1500, 2400}` de A4.1 **no terminaron**. Motivo medido,
> no supuesto: con `copias = 14` (R-FIN-11) y `α = 0,25` el DAG llega a ~4 000 bloques a
> horizonte 900 s, y el `DAG` heredado de D9 (`r8c_gd.py`) calcula alcanzabilidad por **cierre
> transitivo con conjuntos**, coste `O(n²)` en memoria y tiempo. **No es una laguna del
> diseño: es un límite del instrumento**, y quien continúe esta línea debería sustituir el
> cierre transitivo por índices de intervalo (lo que hace Kaspa de verdad,
> `reachability/`) antes de subir el horizonte. Lo que **sí** está cerrado con datos:
> `m` **baja** de 260 s a 500 s en las dos `α` medidas, y la retención sube `m` un 35 % sin
> pasar de 2,548.

