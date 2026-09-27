# MODELO — `eclipse-red-v1`

El modelo matemático, la complejidad y los adversarios. `LINEO.md` §2 exige formularlo **antes** de
elegir la estructura de datos.

## 1 · El mundo, dirigido por eventos

- **Creación de bloques:** proceso de Poisson de tasa `λ` (nominal `1 bloque/s`). Cada evento es del
  atacante con probabilidad `α`, honesto con `1 − α`.
- **Retardo:** un bloque honesto creado en `t` lo ven los demás honestos en `t + Δ`. **El atacante
  ve todo al instante y entrega lo suyo al instante** (`atacante_sin_retardo = true`), que es el
  modelo del artículo y el caso más favorable al atacante.
- **Slot:** `slot(B) = ⌊t_B⌋` con `σ = 1 s` (`C-SLOT-01`, variante A″). `1 slot = 1 s`.
- **Vistas.** Cada actor tiene su propia vista: un bloque **existe** en el DAG desde su creación
  pero puede **no ser visible** todavía. Las puntas se calculan **sobre la vista**, no sobre el
  estado. Usar `tips(est)` de GDR habría sido un error silencioso y está comentado en `mundo.jl`.

**Complejidad.** `O(n)` por evento para la vista (barrido de `1:n`), `O(T log T)` para ordenar las
puntas, y `O(|anc|)` por candidato en la medida del mergeset. Total `O(n²/64)` en palabras de
64 bits por corrida con `n ≈ 900`. Medido: **~0,1–1 s por las 12 semillas** de una configuración.

**Representación elegida, y por qué** (`LINEO.md` §4, regla SoA): el DAG lo representa `GDR-v0.2`
como **SoA** (`ids`, `padres`, `slots`, `sds`, `srs`, `idents`, `anc`, `gd`). Este instrumento añade
sólo tres columnas paralelas por bloque (`tcrea`, `llegadaA`, `llegadaC`) más dos buffers de
barrido (`visible`, `marca` con token monotónico). Nada de `Dict` en el camino caliente; nada de
`Vector{Any}`.

## 2 · Política de padres (producción, no verificación)

Portada **literalmente** de `r8c_sim._padres` (`pick_virtual_parents`):

```text
candidatos = puntas VISIBLES, ordenadas por (−blue_work, id)   ← sin `sd`
sp := candidatos[1]                                            ← sólo para medir el mergeset
se añaden más candidatos mientras el mergeset no pase de msl ni los padres de mp
```

**El `sp` de consenso lo recalcula `anadir!`** con el desempate `(bw, −sd, id)`
(`SP_PYTHON`/`MERGE_PYTHON` de GDR, que coinciden con `r8c_gd._key`). La asimetría —la lista se
ordena sin `sd`, el `sp` se elige con `sd`— es una rareza del **instrumento heredado**, no una
decisión de diseño, y se reproduce tal cual porque el control positivo la necesita.

## 3 · Las tres variantes

| Modo | Qué hace el atacante | Qué ve la víctima |
|---|---|---|
| `:pot` | **retiene** el PoT | sin PoT no hay slot que justificar ⇒ **0 bloques** |
| `:filtro` | deja pasar el PoT; de los bloques honestos ajenos deja pasar una fracción `paso`; los suyos llegan siempre | tasa `≈ paso·(1−f_v)·λ` |
| `:retraso` | deja pasar todo con `E` s de retraso extra | tasa `≈ λ`, PoT retrasado `E` |

**Métricas:** `gaps_V` (`slot(B) − slot(sp(B))`, contra `S_max`), `rojo_V` (fracción de bloques de
la víctima **fuera del blueset de la vista pública final**), `tasa` observada, `n_V`.

**Forma cerrada de `:filtro` con `paso = 0`:** un nodo que sólo puede encadenar sobre sus propios
bloques tiene huecos `Exp(f_v·λ)`, luego `P(inválido) = e^{−f_v·S_max}`. **No depende de `Δ` ni del
peso**, y por eso es el control más robusto del instrumento (idéntico en las 8 combinaciones de
régimen).

## 4 · Sensores

- **E1 (reloj).** La frontera de PoT verificada **es secuencial** (`C-POT-01`: `semilla(f,s) =
  salida(f,s−1)`), así que un solo slot retrasado la atasca:
  `P(L ≤ x) = ∏_{j≥0} F_D(x + jσ)`. `D` es el retardo de entrega del PoT, con familia declarada
  (lognormal o Pareto) ajustada a una mediana y un p99. Alarma si `L > B`.
- **E2 (tasa).** Ventana deslizante `(t−W, t]`; alarma si trae **estrictamente menos de `n_min`**
  bloques válidos, **contando los propios**. `n_min` se deriva de `Poisson(λW)` con menos de una
  falsa alarma al año, con una prueba por slot (cota conservadora).
- **Aritmética:** la parte combinatoria de Poisson en `Rational{BigInt}` **exacta**; `exp` y la CDF
  normal en `BigFloat` a **512 bits**. La CDF normal se implementa **sin `erf`** (no está en `Base`
  de Julia) con serie de Taylor (`y ≤ 10`) y expansión asintótica con truncación óptima (`y > 10`).

## 5 · Captura de salientes

`P(las ω salientes son del atacante) = ∏_{i<ω} (s·t − i)/(G·t − i)`, **exacto** en
`Rational{BigInt}`. Con muchas direcciones por grupo tiende a `(s/G)^ω`, y de ahí el requisito
`p^(1/ω)` de fracción de grupos. Se distingue **IPs** de **prefijos**: son unidades distintas y
confundirlas es el error que la sección D evita.

## 6 · Partición de flujo (aritmética, no simulación)

`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)` (`C-FLU-01`). Con `t_j = slot(I_j) + L_slots`
y `slot(I_j) ≥ T_j`: la ventana de `C-FLU-22` es **vacía** si `s₀ ≤ T_j + L_slots − F_slots`, y la
duración mínima del eclipse es `E_min = t_j − s₀ ≥ F_slots`, **cota inferior exacta y alcanzada**
(se toma el ancla más temprana, que es lo que minimiza la duración). Después `C-FIN-01` prohíbe
reorganizar con `d ≥ F_slots`.

## 7 · Adversarios y casos de borde considerados

| Adversario / borde | Dónde |
|---|---|
| `α = 0` (sin espacio) | fila obligatoria en toda tabla |
| `α ∈ {0,10; 0,25; 0,33; 0,40}` | 11b y barrido |
| Atacante que ve todo al instante | por defecto (cota a favor del atacante) |
| `E` grande (`≥ S_max`) | 11b §A.3 y barrido de régimen |
| Época sin ancla | `C-FLU-05`, cubierto por la aritmética de `flujo.jl` |
| `F_slots` y `L_suelo_slots` como símbolos | `flujo.jl` recorre una rejilla, no fija valores |
| Réplica degenerada (`n_V = 0`) | cada tabla imprime `n`; con `n = 0` la fila no dice nada |
| Semillas | 12 en todo el Monte Carlo; el control usa las mismas que el oráculo |
