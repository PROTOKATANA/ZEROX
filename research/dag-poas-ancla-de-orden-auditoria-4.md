# Auditoría D9-d — Ronda 8d: ¿aguanta el ancla `blue_score` con U3″ dinámica?

**Propuesta:** `dag-poas-ancla-de-orden.md` §2 con el tercer ancla (`I_j` = primer bloque de la cadena
seleccionada con `blue_score ≥ c·j`), U3″ dinámica, `S_max`, R-FIN-12 completa · **Fecha:**
2026-09-08, madrugada, modo autónomo · **Agente:** D9-d en **Opus 5**, fresco · **Informe íntegro,
17 scripts y 16 salidas (rutas duraderas, commit `9d87c5f`):** `research/scripts/d9-ronda8d/`.

> **VEREDICTO: NO AGUANTA — pero es el mejor de los tres.** `blue_score` es grindable (menú gratis
> 2,33-3,25 frente a 4,50-5,25 del ancla de saltos), porque **la protección que da sobre `pos` vale
> exactamente `E[incremento de blue_score por bloque de cadena]`**, que el atacante baja de 4,81 a
> 1,49 gratis inflando `λ_chain`; a incremento 1 **es** el ancla `pos` ya refutada. A cambio: el
> Lema 9 **sobrevive** a U3″ dinámica, la duración de la época deja de ser manipulable, y **sí existe
> `(I, F)`**: `F = 4,2 h` en vez de las 11,7 h que pedía el ancla de saltos.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commit `9d87c5f` | **Solo su directorio** (36 ficheros en `d9-ronda8d/`, 0 fuera) |
| `AUDITA_SCRIPTS.py` sobre `d9-ronda8d/` (17 scripts) | **0 marcas** |
| **A3**, `r8d_a3g_final.py`, ejecutado por mí | **Reproduce:** peor `δ_hon` medio con U3″ dinámica + `pick_virtual_parents` completo = **0,1293** (`α=0,40`, 14 copias); U3′-filtro **0,379**; sin regla 0,492; `α=0` → 0,0000 en todas las filas |
| **A1**, tabla `salida_a1_menu.txt` | Coincide con lo declarado (`m_BS` gratis 2,33/3,03/3,17/3,25; `α=0` → 1,00). **Re-ejecutada por mí completa** (`salida_a1_menu.rerun-principal.txt`): **IDÉNTICA** fila a fila (semillas deterministas) |
| Cita del `shuffle` (`virtual_processor/processor.rs:1069-1089`) | **Real:** *«Prioritize half the blocks with highest blue work and pick the rest randomly to ensure diversity between nodes»*; `rand::thread_rng().gen_range(i..slice.len())` |
| Adversario | **El del paper, sin retardo** (L1024-1027). D9-d reproduce los números de D9-c para `pos` en las mismas semillas: instrumento validado |

---

## 1 · A1 · `blue_score` es grindable — REFUTADO, pero mejor que `pos`

Menú por estructura (`seed` fijado al crearse), posición 30, `k=30`, `mp=15`, U3″ dinámica:

| `α` | `m_pos` gratis (D9-c) | **`m_bs` gratis** | `m_bs` +retraso | `m_bs` +retención |
|---:|---:|---:|---:|---:|
| 0,00 | 1,00 | **1,00** | 1,00 | 1,00 |
| 0,10 | 4,50 | **2,33** | 3,38 | 4,35 |
| 0,25 | 5,00 | **3,03** | 4,29 | 7,53 |
| 0,33 | 5,17 | **3,17** | 4,32 | 8,24 |
| 0,40 | 5,25 | **3,25** | 4,34 | 8,17 |

**−38 a −48 %** gratis. **Por qué** reduce, y por qué no más: cada bloque de cadena «posee» tantos
umbrales `c·j` como su **incremento** de `blue_score`; la protección es `E[incremento] =
λ_azul/λ_chain`. El atacante del paper (sin retardo) fusiona más y **acorta** la cadena: `λ_chain`
sube de 0,199 a 0,484 (`α=0,25`) y el incremento medio **cae de 4,81 a 1,49**. **A incremento 1 el
ancla `blue_score` es el ancla `pos`.**

**Lo que sí arregla (A1.3):** `λ_azul` es plana (0,971-0,978 para todo `α`), así que la **duración
real de la época nunca se desvía > 3 %** — cierra el defecto A1.4 de D9-c, donde `pos` la acortaba ×3,3.

## 2 · A2 · El cruce del umbral — canal nuevo, y el ancla está sesgada

**A2.1:** con la **misma sucesión de bloques de cadena** el ancla se mueve igual, solo por *dónde*
se cruza `c·j`: menú **1,35-1,57** (con `pos` vale 1 por construcción).

**A2.2, hallazgo no pedido:** si el ancla fuera neutral, caería en un bloque del atacante con su
cuota de **umbrales**, no de bloques. No lo es (`r8d_a2c_sesgo.py`, atacante jugando limpio):

| `α` | % bloques de cadena suyos | **% umbrales suyos** | incr. medio atacante | honesto |
|---:|---:|---:|---:|---:|
| 0,10 | 30,9 % | **37,2 %** | 3,59 | 2,71 |
| 0,25 | 49,3 % | **59,3 %** | 2,37 | 1,58 |
| 0,40 | 59,7 % | **68,6 %** | 1,72 | 1,17 |

**La causa es el modelo del paper**: el atacante sin retardo fusiona **1,5× más azules** por bloque.
Y eligiendo padres, gratis: el ancla es suya el **80,6 %** de las veces a `α=0,25`, **88,1 %** a 0,40.

> **Matiz que hay que escribir:** que el inyector sea *su* bloque no le da la entropía —
> `blake3(chunk ‖ pot_output)` no es moldeable por bloque—; su palanca es el **menú** `m`, ya medido.
> Pero el sesgo es real, contradice la intuición con la que se eligió el ancla, y **está sin explotar**.

## 3 · A3 · El Lema 9 sobrevive a U3″ dinámica — VERIFICADO en simulación de eventos

Peor `δ_ef` con U3″ dinámica: **0,1293** (39 % de margen sobre la cota nominal 0,2105; 52 % sobre
`δ_real = 0,267`). **U3′-filtro: 0,379 — rompe las dos cotas.** Cierra la LAGUNA 5 de D9-c. (D9-d lo
etiqueta DEMOSTRADO; es una **medición** sobre familias de estrategias, no una demostración: lo dejo
en VERIFICADO.)

**Hallazgo lateral decisivo (A3.1):** el daño **no** viene del presupuesto de mergeset (0 cortes por
`mergeset_size_limit`) sino del **tope de 15 padres frente a 548 puntas**; lo cierra el **`shuffle`**
de `pick_virtual_parents` (`processor.rs:1069-1089`), que R-FIN-12 **no nombraba** y que D9-c había
descartado. **Sin él, 14-21 bloques honestos quedan fuera del DAG para siempre.**

## 4 · A4 · `S_max` existe — y R-FIN-1a y R-FIN-7 se contradicen

- **Suelo (operación normal):** salto de slot entre bloques de cadena consecutivos, cola geométrica
  `P(salto > S) ≈ e^{−λ_chain·S}` (`λ_chain=0,199`): para ningún inválido honesto en 10 años a
  `10⁻¹²`, **`S_max ≥ 139`**.
- **Suelo (partición):** un lado con fracción `f` del espacio tiene huecos de `≈ 1/(fλ_chain)`; para
  que no fabrique inválidos durante `F` al 99 %: `f=0,10` → **119 s**; `f=0,05` → 222; `f=0,02` → 522.
- **Techo (DoS de PoT):** la verificación de Autonomys no es sucinta (recomputa AES, lineal en slots);
  el atacante fuerza `α·λ·n_cop·S_max` slots/s: `S_max=150` → **×60** a `α=0,40` sin copias;
  `S_max=11 520` (= `F`) → **×4 608**.

> **`S_max = 150 slots` (≈ 2,5 min): PLAUSIBLE.** Cubre la cola normal a `10⁻¹²`, cubre una partición
> de `F` para cualquier lado con **`f ≥ 0,09`**, DoS ×60.
>
> **Contradicción DEMOSTRADA:** la letra de R-FIN-7 —«tolera cualquier partición `< F`»— exige
> `S_max ≥ F = 11 520`, que es DoS ×4 608. **No existe `S_max` que cumpla las dos reglas tal como
> están escritas.** La tolerancia real es «`F`, **si el lado conserva ≥ 9 % del espacio**».

LAGUNA: el coste absoluto de un slot de PoT (no hay clon de Autonomys); todo en múltiplos del
presupuesto que la red ya gasta, no en ms.

## 5 · A5 · `(I, F)` sí existe — y no son los publicados

Pinza `g = c_m/√(αλI) ≤ 3,6 %` y `W/κ = 1 + I/F ≤ 1,22`; peor `α = 0,10` (`g ∝ 1/√α`):

| coste del atacante | `m` | **`I`** | **`F`** | `c` (azules) |
|---|---:|---:|---:|---:|
| reactivo (en línea) | 1,77 | 1 456 s | 1,84 h | 1 420 |
| **gratis ex post** | **2,33** | **3 333 s (0,93 h)** | **4,21 h** | **3 250** |
| +retraso | 3,38 | 6 472 s | 8,17 h | 6 310 |
| **+retención** | **4,35** | 8 936 s (2,48 h) | **11,28 h** | 8 712 |
| *ronda 8 publicaba* | 4 asumida | 2 490 s | 3,20 h | 2 490 |
| *D9-c, ancla `pos`* | 4,50 | 9 272 s | 11,70 h | — |

**Los publicados no se sostienen** (`I` 34 % corta, `F` 31 %). **El tercer ancla compra `F` de 11,7 h
a 4,2 h** — contra un atacante que **no retiene**. Contra uno que retiene, `F = 11,3 h`, casi lo que
pedía `pos`. **Es una elección de modelo de amenaza, no una derivación**, y hay que etiquetarla.

## 6 · Lo que D9-d deja abierto

1. **`blue_work = blue_score` en el simulador** (peso 1/bloque). El diseño usa `Σ w(SR)` y **eso elige
   la cadena entera**. **Es la laguna mayor de la ronda** y afecta a A1 y A2.
2. Prop. 7 con el ancla nueva: el Lema A2 de D9-c *debería* transferirse (`blue_score(B)` es inmutable
   una vez existe `B`), **no demostrado**.
3. `m` es cota inferior por familia dirigida. 4. Un solo nodo honesto: el argumento del `shuffle` es
   «diversity **between nodes**». 5. La objeción `Risk = 1` (D9-a §4c) sigue abierta y anterior.
6. **`Δ` sin medir** — mueve todos los números.

## 7 · Errores declarados por D9-d — y uno que importa para el método

Cinco. El grave: **una comparación suya era una tautología y casi la firma** — `r8d_a3d_kaspa.py` daba
resultados idénticos a la cuarta cifra en 16 filas porque **la rama bajo prueba nunca se ejecutaba**,
y **el criterio α pasaba**. Propone un detector nuevo: al comparar A con B, comprobar que la rama que
distingue a B **se ejecuta**. Lo adopto como criterio adicional obligatorio.

## 8 · Decisiones (autónomas, con el mandato de Katana)

1. **El ancla `blue_score` se queda** — es la única de las tres con unidad protegida por GHOSTDAG y
   la única con `(I, F)` alcanzable. R-FIN-1 lleva escrito **qué protege y qué no** y el sesgo A2.2.
2. **`I = 3 330 s`, `c = 3 250` azules, `F = 4,2 h`**, etiquetados «contra atacante que no retiene»;
   la alternativa con retención (`I = 2,5 h`, `F = 11,3 h`) escrita al lado como elección de amenaza.
3. **`S_max = 150`** y **R-FIN-7 reescrita**: tolerancia = «`F`, si el lado conserva ≥ 9 %».
4. **R-FIN-12 nombra el `shuffle`.** 5. **U3″ dinámica se queda** (VERIFICADO). 6. **`Δ`: LAGUNA
   declarada arriba de todo.**
7. **Siguiente agente: la laguna mayor.** Meter el peso real `Σ w(SR)` con el retarget en el
   simulador y re-medir A1/A2; intentar transferir el Lema A2 a `blue_score`. Un D8 sobre un
   simulador con el peso equivocado sería trabajo perdido.
