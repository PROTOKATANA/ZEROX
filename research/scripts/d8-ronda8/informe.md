# D8 · ronda 8 — ataques contra el diseño completo (ancla por `slot`, constantes fijadas)

**Fecha:** 2026-09-08 · **Agente:** D8 (adversarial, fresco) · **Estado:** EN CURSO

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
| A0 | Validar el instrumento heredado (`d8_lib.py` del D8 muerto) | PENDIENTE |
| A1 | ¿Se **sostiene** el sesgo `δ` del Lema 9 con `α < 1/2`? `δ` sostenible real | PENDIENTE |
| A2 | Acuerdo honesto con **dos vistas** separadas por `Δ`: `P(I_j distinto)` | PENDIENTE |
| A3 | Partición + `S_max` + R-FIN-7: ¿se puede **provocar** sin partición real? | PENDIENTE |
| A4 | Cruce del ancla `slot` en régimen (`I = 4 200 s`, `F = 5,3 h`); retención hasta `S_max` | PENDIENTE |
| A5 | Soborno BDK+19 §2 portado a PoAS (`W/κ = 1,22`) | PENDIENTE |
| A6 | Líneas 3/5/6 de §7 + **margen económico** con lookahead `F + I = 6,5 h` | PENDIENTE |

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
Resultado: PENDIENTE (§A0).

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

