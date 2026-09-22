# CRP-v0.3 · Modelo

Versión `CRP-v0.3`. Deriva de `CRP-v0.2` (que no se cierra).

## 1 · Unidades

| Magnitud | Unidad | Definición |
|---|---|---|
| `w(B)` | `blue_work` | `⌊2^128/(SR(B)+1)⌋` (C-GD-01) |
| `d` | `blue_work` | déficit inicial como múltiplo explícito de `w` |
| `z` | retícula entera | `z = g·D`; un bloque pesa `1/g` |
| `slot` | índice de PoT | no es sello de cabecera |

**Corrección v0.3 (punto 7):** el déficit se expresa en unidades de `blue_work`
(`d = m·w`) y la **semilla no depende de `d`**; cambiar `d` no cambia la trayectoria física.

## 2 · Actores y red (puntos 3, 5, 6)

- `n_honestos` con vistas locales; el **autor conoce su bloque de inmediato**.
- Entregas a los demás en `slot+Δ`; `Δ=0` se drena en el mismo slot tras producir.
- **Drenaje terminal simétrico**: al cerrar `T` se entregan todos los pendientes a todos.
- Un único productor (`n_honestos=1`) no crea rojos por latencia consigo mismo.
- Observadores explícitos: **nuevo desde génesis**, **veterano** (sujeto a R-FIN-7/`F`) y
  **eclipsado**. Cada uno emite una `Decision` con clasificación y motivo.

## 3 · Flujo PoT (punto 2)

Cada bloque lleva `DescriptorFlujo` (`PotOrigin`, dominio, origen, semilla, `N` inicial,
autenticado) y eventos `(slot_activación, entropía, N_efectivo)`. R-FIN-5 compara el
**prefijo en `slot(X)`** para **todo** `X ∈ past(B)`, antes de entregar a GDR. `PotOrigin`
es común a los flujos que comparten historia; la divergencia aparece en la entropía de las
inyecciones posteriores al fork. Sin autenticación ⇒ `Pendiente`.

## 4 · `S` flujos conjuntos (punto 4)

Oportunidades físicas compartidas por slot; controles:
`:perfecta` (idénticos), `:iid` (independientes) y `:derivada` (base común mezclada).
La regla candidata R-FIN-5 incorpora **la mejor rama** (máximo); el contrafactual aditivo
usa la **suma** y no es regla adoptada.

## 5 · Escenarios y barrido (punto 8)

`S ∈ {1,2,4,8,16,24}`, `α` a ambos lados de `1/(S+1)` y de `1/2`, `T ∈ {80,200,400}`,
`Δ ∈ {1,2,6}`, `k ∈ {10,30}`, `d ∈ {0,2}` bloques de `blue_work`.

## 6 · Eficiencias (punto 10)

`η_x = (blue_work azul de x) / (blue_work bruto elegible de x)` en el contexto de la punta
de su propia rama. `η_h` y `η_a` se **miden por separado**; sin muestra suficiente de rojos,
la curva con rojos queda **inconclusa**.

## 7 · Vigencia de reglas

Igual que `MATRIZ-AUTORIDAD.md` (copiada de v0.2, con las correcciones de estado
normativo). Flujo, controlador del SPEC y partes de C-GD-11/finalidad siguen pendientes.
