# Auditoría D9-c — Ronda 8c: ¿aguanta el ancla en la cadena seleccionada con R-FIN-11 + R-FIN-12?

**Propuesta:** `dag-poas-solucion-ancla.md` + `dag-poas-ancla-de-orden.md` §2 (ancla en posición de
cadena, U2 + U3′-filtro, límites de Kaspa) · **Fecha:** 2026-09-08, madrugada, modo autónomo
**Agente:** D9-c en **Opus 5**, fresco, con el encargo explícito de romper la solución del agente
principal · **Informe íntegro y scripts (rutas duraderas, commiteados):**
`research/scripts/d9-ronda8c/` (`informe.md`, `r8c_*.py`, simulador `r8c_gd.py` reconstruido desde el
código de Kaspa con su suite de tests).

> **VEREDICTO: NO AGUANTA.** El ancla en la posición de la cadena **no es un bloque: es un contador
> de saltos**, y GHOSTDAG elige la cadena por `blue_work`, que **no ve saltos**. Y U3′-filtro, tal
> como está escrita, **no filtra nada** en el caso que el atacante controla.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Suite del simulador `r8c_test_gd.py` (tope `k+1`, `blue_work` creciente, bloque tras su mergeset, cadena ⊆ azules, R-FIN-12) | **6/6 pasan** |
| A3, contraejemplo determinista `r8c_a3_filtro.py` | **Reproduce:** `filter` deja **14** copias azules (`= max_block_parents − 1`), `dynamic` 1; y esas copias compran `sp` (`bw(Z)=22` frente a `bw(H)=12`) |
| A1, control `r8c_a1d_control.py` | **Reproduce:** atacante **retardado** → `m` = 1,38 / 2,00 / 2,62 (mi rango); adversario **del paper** → 4,5-5,25, y ocupa 28-59 % de las posiciones |
| `AUDITA_SCRIPTS.py` sobre `d9-ronda8c/` | **0 marcas** |
| Citas de Kaspa (A4/A5), en el clon @ `c338d495` | **Reales:** `pick_virtual_parents` (`virtual_processor/processor.rs:1053`, presupuesto en `:974`), `calc_merge_depth_root` + `kosherizing_blues` (`post_pow_validation.rs:81-98`, `processes/block_depth.rs`), `pruning_depth` (`params.rs:189`) |
| Criterio α | **Pasa:** `α = 0` da menú 1,00 en 12/12 semillas; cambia con `α` |

---

## 1 · A1 · La posición de cadena es un contador de saltos — REFUTADO

`pos(B) = pos(sp(B)) + 1` cuenta **saltos**. GHOSTDAG elige `sp` por **`blue_work`**, y un bloque que
fusiona 20 azules gana 20 de `blue_work` con **un** salto. Añadir o quitar un salto por debajo de la
posición `c·j` **desplaza todo lo que hay a partir de ahí** — sin que ninguna copia sea azul y sin
reorganizar nada. La mayor parte del menú son **bloques honestos**: el atacante no ocupa la posición,
mueve **cuál** honesto cae en ella.

Menú por estructura (cada bloque con su `seed` fijado al crearse; el artefacto de renombrado es
imposible), posición 30, 12 semillas, `k=30`, `mp=15`, ya con U3″ dinámica:

| `α` | **m gratis** (publica al instante, solo elige padres) | +retraso | +retención |
|---:|---:|---:|---:|
| 0,00 | **1,00** (0/12 con m>1) | 1,00 | 1,00 |
| 0,10 | **4,50** | 5,92 | 7,33 |
| 0,25 | **5,00** | 8,25 | 9,50 |
| 0,40 | **5,25** | 9,17 | 10,67 |

**Por qué yo medí 1,3-2,0.** Mi `corre2()` aplicaba el retardo `Δ` **también a los bloques del
atacante**. El adversario del paper (L1024-1027) no tiene retardo — es el que demuestra `k`, `δ`,
`3k` y la Prop. 7 que el diseño cita. **No se puede tomar los teoremas de ese adversario y medir el
steering contra otro más débil.** Error mío, y es el mismo patrón que la ronda 7: medir contra un
modelo que favorece la conclusión.

**Consecuencia A1.4:** el retarget fija `λ`, no `λ_chain`; el atacante infla `λ_chain` (0,199 →
0,484 a `α=0,25`) y **acorta la época** (`I′ = c/λ_chain(α)`: 1 033 s en vez de 2 490). Como
`g ∝ 1/√I`, el steering sube:

| `α` | `g` con `m=1,3` (lo publicado) | **`g` con m gratis** | con `I′` real |
|---:|---:|---:|---:|
| 0,10 | 1,07 % | **6,95 %** | **8,74 %** |
| 0,25 | 0,68 % | **4,66 %** | 7,24 % |
| 0,40 | 0,54 % | **3,77 %** | 6,66 % |

**`I = 2 490 s` y `F = 3,2 h` dejan de estar derivadas.** Primer orden para volver a `g ≤ 3,6 %` con
`W/κ ≤ 1,22`: `I ≈ 2,6 h`, `c ≈ 3 000` posiciones, **`F ≈ 11,7 h`** (a `α=0,10`, el peor caso porque
`g ∝ 1/√α`).

## 2 · A3 · U3′-filtro no filtra — REFUTADO, determinista

U3′-filtro comprueba «identidad ya azul en `past(sp)`». Basta publicar las copias **en el anticono
del padre seleccionado**: el original no está en `past(sp)`, ninguna copia lo está, **todas son
candidatas**. `filter` ≡ GHOSTDAG **sin regla alguna**. Un billete = **14 azules** (`mp−1`), hasta 29
con portadores; **3 de 4 puntas honestas quedan rojas** en el mergeset. El ataque de presupuesto de
D9-a **sigue vivo**.

**Reparación que cierra las tres tablas: U3″ dinámica** — candidata a azul si su identidad no es azul
en `past(sp)` **ni ha sido ya coloreada de azul en este mismo mergeset**. Sigue siendo función de
`past(B)` (el orden del mergeset es determinista). **PLAUSIBLE, no demostrada.**

## 3 · A2 · Prop. 7 sí cubre la cadena — DEMOSTRADO, con otra prueba

Mi argumento («el orden se construye a lo largo de la cadena ⇒ orden estable ⇒ cadena estable»)
**no vale**: la Prop. 7 es **por parejas** (L1053-1056), no sobre la secuencia. El **Lema A2** de D9-c
lo repara: el bloque de cadena que cambia y su sustituto comparten `sp`, están en anticono mutuo y su
pareja se invierte ⇒ el evento cae dentro del `∃C` de la Def. 2, **sin cota de la unión** (270/270).
La cadena tiene teorema — **pero A1 muestra que la función que se lee de ella (los saltos) no es una
magnitud que ese teorema proteja.**

## 4 · A4 y A5 · R-FIN-12 está adoptada a medias — LAGUNA

- **A4:** «la identidad incluye el slot ⇒ búsqueda acotada» **no cierra**. Lo que acota la
  retrolectura de U2 en Kaspa son **`merge_depth_bound`**, la finalidad y **`pruning_depth`** —
  tres reglas que R-FIN-12 **no adoptó**. Extra: R-FIN-1a **sin cota superior al salto de slot** es
  un **DoS de verificación de PoT** (una justificación arbitrariamente larga).
- **A5:** el *griefing* de `MergeSetTooBig` **no existe**: un nodo de Kaspa **nunca** lo emite,
  porque `pick_virtual_parents` lleva presupuesto (`processor.rs:1053`, `:974`). Pero R-FIN-12
  adoptó **los dos números y no el algoritmo**. Y `pick_virtual_parents` **baraja** candidatos
  (`:1076-1090`, `shuffle`): aleatoriedad no controlable por el atacante, **no medida** en el
  simulador (sesgo posible a favor del atacante).

## 5 · Lo que D9-c dejó abierto, con etiqueta

1. Prop. 7 **bajo U3″ dinámica**: no auditada. 2. `δ_ef` bajo el filtro en simulación de eventos:
no medido. 3. La objeción `Risk = 1` por desacuerdo de flujo (D9-a §4c): **sigue abierta y es
anterior** — si `Risk = 1`, ni la Prop. 7 ni el Lema A2 dicen nada (la nota
`dag-poas-recursion-flujos.md` la trata como inducción por épocas, PLAUSIBLE). 4. `m` es cota
inferior por familia dirigida. 5. A1/A2 solo con `k=30`. 6. **El ancla por `blue_score` no está
atacada** — es su sugerencia, no un resultado.

## 6 · Decisiones (autónomas, con el mandato de Katana)

Las cinco correcciones de D9-c, en su orden, **aplicadas a la propuesta**:

1. **R-FIN-11 → U3″ dinámica.** 2. **R-FIN-1a + `S_max`** (cota al salto de slot). 3. **R-FIN-12
completa**: `pick_virtual_parents`, `merge_depth_bound`, `pruning_depth`, no solo los dos límites.
4. **`I`, `c`, `F` marcadas como NO derivadas** hasta rederivarlas con la `m` del adversario del
paper y `λ_chain` bajo ataque. 5. **El ancla pasa a `blue_score` de la cadena seleccionada:**
`I_j :=` el primer bloque de la cadena con `blue_score ≥ c·j`. Es la magnitud que GHOSTDAG **sí**
maximiza y que un salto **no** infla. **Sin auditar: es el objetivo del siguiente agente.**

**Balance:** tres anclas probadas —índice del orden (cuenta rojos), posición de cadena (cuenta
saltos), y ahora `blue_score` (cuenta azules)—. Las dos primeras cayeron por la misma razón:
**anclar en un contador que `blue_work` no protege**. La tercera es la única cuya unidad es la que
GHOSTDAG defiende.
