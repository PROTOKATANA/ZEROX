# El empalme `φ_c` (conteo) ⊗ `blue_work` (peso) — reducido a una restricción de diseño

**Fecha:** 2026-09-08 (madrugada, modo autónomo) · **Origen:** deuda declarada desde la ronda 3
(`dag-poas-candidatos-auditoria.md` L173: *«φ_c está probado contra la cadena honesta ficticia, no
contra el crecimiento azul de un DAG… es exactamente el teorema que falta»*), repetida en las rondas
7 y 8 (`dag-poas-solucion-ancla.md` §4.5). **Script:** `research/scripts/verif_empalme.py`.

---

## 1 · Los dos objetos, por fin uno al lado del otro

**BDK+19** demuestra `φ_c` sobre el **número de bloques** del árbol privado frente a la cadena
honesta (§5.4, ec. 39; Tabla 3 con `Δ = 0`, `bdk19.txt` L1416).

**GHOSTDAG en Kaspa** compara **peso**, no número. Verificado en el clon @ `c338d495`:

```rust
// consensus/src/processes/ghostdag/protocol.rs:155-161
let added_blue_work: BlueWorkType = new_block_data.mergeset_blues.iter()
    .map(|hash| calc_work(self.headers_store.get_bits(hash).unwrap()).max(self.level_work))
    .sum();
let blue_work = self.ghostdag_store.get_blue_work(selected_parent).unwrap() + added_blue_work;
// consensus/src/processes/difficulty.rs:211-217
pub fn calc_work(bits: u32) -> BlueWorkType {   // 2^256 / (target + 1), de bitcoin/chain.cpp:131
```

**El peso de un bloque azul es `w(SR)` de su propio objetivo de dificultad.** La propuesta de ZEROX
usa la misma forma, `Σ⌊2^128/(SR+1)⌋` sobre azules.

## 2 · La reducción

Si `SR` es **constante** en el horizonte de la carrera, `blue_work = conteo × w` para las dos partes,
y la comparación por peso **es** la comparación por conteo: **`φ_c` aplica exactamente.** La brecha
entre los dos objetos es, por tanto, **la variación relativa de `w` a lo largo del horizonte de la
carrera**, y nada más. Ese horizonte es la profundidad de finalidad `F = 3,2 h`.

Quién mueve `SR` es el retarget de la ronda 3 (`dag-poas-candidatos-auditoria.md` §7):

```
ln SR_{n+1} = ln SR_n − γ (ln N_obs − ln N_obj),   ventana de W slots,   0 < γ < 2
```

Con `N_obs ~ Poisson(N_obj)`, cada paso mueve `ln SR` con desviación `≈ γ/√N_obj`; en `F/W` pasos
independientes, la desviación típica acumulada de `ln w` es

```
s = γ · √( F / (W² · λ_azul) )          con λ_azul = λ(1−δ) = 0,758/s a q=1, k=25
```

Un sesgo relativo de peso `ε` entre bloques del atacante y honestos equivale a `α_ef = α(1+ε)` en la
carrera: **el empalme es exacto salvo `ε`, y `ε` lo fijan `(γ, W)`.**

## 3 · La tabla — `ε` sobre el horizonte `F = 11 520 s`

| `W` (slots) | `N_obj` | `γ = 0,25` | `γ = 0,5` | `γ = 1,0` | `γ = 1,5` |
|---:|---:|---:|---:|---:|---:|
| 60 | 45 | 67 % | 179 % | 681 % | 2 082 % |
| 300 | 227 | 10,8 % | 22,8 % | 50,8 % | 85,3 % |
| 900 | 682 | 3,5 % | 7,1 % | 14,7 % | 22,8 % |
| **3 600** | 2 727 | **0,86 %** | 1,73 % | 3,48 % | 5,27 % |
| **11 520** (= `F`) | 8 727 | **0,27 %** | **0,54 %** | **1,08 %** | 1,62 % |

**Condición para `ε ≤ 1 %`:** `γ·√(F/(W²λ_azul)) ≤ 0,01`, es decir

| `γ` | `W` mínima |
|---:|---:|
| 0,25 | **3 083 slots = 0,86 h** |
| 0,5 | 6 166 slots = 1,71 h |
| 1,0 | 12 331 slots = 3,43 h |

Efecto sobre el umbral: con `α = 0,35` y `ε = 1 %`, `α_ef = 0,3535` — **0,35 puntos**. Con `ε = 5 %`,
`α_ef = 0,3675` — 1,75 puntos. Ventanas de un minuto (`W = 60`) destruyen el empalme; ventanas de
una hora lo hacen despreciable.

## 4 · Lo que esto cierra y lo que deja

**Cierra:** «`φ_c` no vale con peso» **no es un teorema que falte**: es una **restricción sobre el
retarget**. Con `W ≥ 3 083 slots` y `γ ≤ 0,25` (o `W ≥ 12 331` y `γ ≤ 1`), la discrepancia
conteo↔peso sobre todo el horizonte de finalidad es `< 1 %` y `φ_c` aplica con un error de umbral
`< 0,4` puntos. **Es una elección de diseño, con etiqueta:** `W_RETARGET ≥ 3 083 slots`,
`γ ≤ 0,25`. Kaspa opera con ventanas de miles de bloques; no es exótico.

**Deja (LAGUNA, con etiqueta):**
1. El modelo supone `N_obs` Poisson **sin atacante**. Bajo ataque, el sesgo del Lema 9 (`δ`) es
   sostenible o no — la ronda 3 lo dejó **PLAUSIBLE, NO DEMOSTRADO** (L222). Si el atacante mueve
   `N_obs` sistemáticamente, el retarget deriva y `ε` crece; el controlador es contractivo (ronda 3,
   A6), así que la deriva está acotada por `γ·|sesgo|`, pero no está cuantificada aquí.
2. La media geométrica: `w` es convexa en `ln SR`, así que la **media** del peso sube con la
   varianza (`E[e^X] ≥ e^{E[X]}`); a `ε ≤ 1 %` el efecto es de segundo orden (`≈ ε²/2`), pero no es
   cero.
3. La condición `λ_objetivo < k/(2D)` de existencia del punto fijo (ronda 3) sigue siendo previa.

## 5 · Consecuencia para la propuesta

Añadir a `dag-poas-ancla-de-orden.md` §2 una constante con procedencia: **`W_RETARGET ≥ 3 083 slots`
con `γ ≤ 0,25`** (o el par equivalente de la tabla). Con ella, el punto 5 de §4 de
`dag-poas-solucion-ancla.md` pasa de «sin demostrar desde la ronda 3» a **«exacto salvo `ε < 1 %`,
condicionado a (γ, W)»**.
