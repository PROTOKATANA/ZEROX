# Auditoría 9b — Ronda 10b: el suelo de `F` y sus palancas

**Pregunta:** de qué depende `F_carrera` (la `F` mínima con unión a 10 años `< 10⁻¹⁰` al 33 %) y cuánto se puede bajar `F`
sin perder colchón. · **Fecha:** 2026-09-09, madrugada · **Agente:** D9 en **Opus 5**, relanzado sin presupuesto de tiempo,
continuando desde su primer intento · **Informe (700 líneas), 11 scripts, 12 salidas, 10 commits solo en su directorio:**
`research/scripts/d9-ronda10b/`.

> **VEREDICTO (mío, tras reproducir la entrega C):** **`F = 2 h` es, al segundo, la `F` más corta que conserva ≥ 2 puntos de
> colchón sobre el 33 % en los seis modelos**, incluidos los dos que 9a y 9b refutaron: la elección provisional de Katana
> era exactamente el mínimo de la columna «sobrevive a todo». **`Δ` es la palanca que manda y `F` no la compra:** pasar de
> 1 h a 2 h tolera 1,9 s más de `Δ`; por encima de `Δ = 22,7 s` (`r = 1`) ninguna `F` basta. **La `δ` pesimista de D8
> (0,2867) y `δ₀(Δ = 16 s)` (0,2858) son el mismo número:** la discusión sobre el modelo de `δ` es en realidad «¿hasta qué
> `Δ` aguanto?». Las demás palancas son débiles: ventaja `3k → 1,68k`, 3,2 min; objetivo `10⁻¹² → 10⁻⁶`, 4,1 min; `I` por la
> carrera, +4,7 % en todo el rango; la incertidumbre de la propia medida de `δ` (±9 min) pesa más que las dos juntas. **Y
> una corrección al principal:** por debajo de `Δ ≈ 14 s` el suelo de `F` **no** lo pone la carrera sino el término de
> steering `I/(W/κ − 1)` (0,62-1,07 h); la bitácora §11.4 («el suelo lo pone el corredor») vale solo con el `δ` pesimista
> o a `Δ ≥ 14 s`. Recomendación de 10b: **`F = 2 h` mantener; producción `F = 1 h` con `ρ_max = 1,5`, `I = 602 s`,
> condicionada a `Δ_p99 ≤ 14,9 s` medido; 21-28 min solo con revelación retardada y `Δ ≤ 12 s`.**

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commits `5daaf2f`…`6ee103e` | **Solo su directorio** (un `.pyc` colado y retirado en el commit siguiente, declarado) |
| `AUDITA_SCRIPTS.py` (11 scripts), pasado por mí | **0 sospechas** |
| **`r10b_c_entrega.py` re-ejecutado por mí** (387 s) | Salida **IDÉNTICA** a `salida_c.txt` salvo la línea de tiempo |
| Los cuatro scripts heredados del primer intento | Re-ejecutados por el agente: idénticos |
| Controles | CONTROL 1 reproduce la fila `F = 2 h` de `verif_frontera_vs_F.py` (44,57 / 35,08 %); CONTROL 2, la identidad «frontera(`F`) = 35 % ⟺ `F_carrera(35 %) = F`» en los seis modelos (35,000 ± 0,001 %); B.5, 5/5 contra `auditoria-8a.md` §4 |
| Instrumento | Reutiliza `r9a_a3_frontera.prev/union10` sin reescribir; barrido grueso + `brentq`, como `verif_frontera_vs_F.py` |
| Fuentes | El «0,56·3k» localizado en `d8-ronda8/salida_a6b.txt` L14-18; la tabla de Nakamoto §11 reproducida 8/8 (PDF ausente en `research/fuentes/`: LAGUNA parcial, declarada); `ε` de Chia no publicado: LAGUNA |

---

## 1 · La tabla que decide (C)

`I = 851 s`, ventaja `3k = 90`, objetivo `10⁻¹⁰` a 10 años:

| Modelo | Supone | `F_carrera` (33 %) | **`F` mínima (+2 pts)** |
|---|---|---:|---:|
| M1 `δ = 0` (9a) | `Δ = 4 s` exacto | 0,28 h | **0,35 h** |
| M2 `δ₀(8 s)` | `Δ` el doble | 0,28 h | **0,35 h** |
| M3 `δ₀(12 s)` — el que 10b recomienda para diseñar | `Δ` el triple | 0,36 h | **0,46 h** |
| M4 `δ₀(16 s)` | el límite de `k = 30` | 0,98 h | **1,55 h** |
| M5 `δ` D8 (pesimista) | que el teorema de la ráfaga falle | 0,99 h | **1,92 h** |
| M6 `δ_real(k)` | que R-FIN-13′ no aplique | 0,63 h | 0,96 h |

Colchón de cada `F` candidata sobre el 33 %: con `F = 1 h`, +9,0 (M1) / +6,7 (M3) / +0,1 (M4) / +0,1 (M5); con `F = 2 h`,
+11,6 / +9,3 / +2,9 / +2,1. Y el `Δ` que cada `F` compra con 2 puntos de colchón: `F = 1 h` → 14,9 s; `F = 2 h` → 16,6 s;
`F = 5,3 h` → 18,3 s.

## 2 · Las cinco palancas (B)

| Palanca | Movimiento de `F` al 33 % | Veredicto |
|---|---|---|
| **`Δ`** 4 → 16 s | 0,28 h → 0,98 h (×3,5) | **domina** |
| Modelo de `δ` | M1 → M5: ×3,5 | es la misma palanca: `δ_D8 ≡ δ₀(16 s)` |
| `k` | sin signo propio: con `δ = 0`, `k`↑ alarga (+282 s de 20 a 40); con `δ_real(k)`, `k`↑ acorta 17 %; `k = 20` inadmisible (`k_Poisson = 26`) | real solo en el modelo anulado por 13′ |
| Incertidumbre de la medida de `δ` (IC95, 1 920 corridas, 12 semillas) | ±9 min | mayor que las dos siguientes juntas; `δ` **no depende de `k`** |
| Objetivo `10⁻¹² → 10⁻⁶` | −4,1 min (M1) / −17,4 min (M5) | barato de conservar; Bitcoin bajo el mismo criterio pediría 46 h a 33 % |
| Ventaja `3k → 1,68k` | −3,2 min / −7,8 min | la más débil; diseñar con la medida no es legítimo |
| `I` vía carrera 4 200 → 300 s | +4,7 % | despreciable (entra en logaritmo) |
| `I` vía steering 851 → 491 s | 1,07 h → 0,62 h | la segunda que más pesa |

## 3 · Lo que corrige

- **Bitácora §11.4 y lo dicho a Katana:** «el suelo de `F` lo pone el corredor, no el steering» es cierto solo con el `δ`
  pesimista o a `Δ ≥ 14 s`. Con el modelo de diseño a `Δ ≤ 12 s`, manda el término `I/(W/κ − 1)`, y entonces acortar
  `F_carrera` no compra nada sin revelación retardada. (10c, en verificación, añade que ese término estaba calculado en
  el rincón `ρ → ∞` y vale 1 198-2 488 s, no 3 868 s.)
- **`F = 20 min`** (la fila de la bitácora §11.4) está por debajo del suelo en todos los modelos.

## 4 · Errores declarados por el agente (6)

LAGUNA por presupuesto en el primer intento (corregida midiendo 1 920 corridas); cabecera falsa sobre T4; `f_carrera` usada
para un criterio por evento (daba 0 s); barrido de `Δ` por encima de `r = 1` (artefacto `r^700`, filas 24/32 s marcadas
como cota vacua); haber trabajado B.1-B.5 con el encuadre heredado «el suelo lo pone la carrera»; un `.pyc` commiteado.

## 5 · Lagunas que deja

`Δ` sin medir (única palanca decisiva); composición de `δ₀(Δ)` con la parásita a `Δ ≥ 16 s` (repetir el A2 de 9a con
`Δ ∈ {12, 16, 20}`); PDF de Nakamoto ausente en fuentes; `ε` de Chia.

## 6 · Efecto sobre las decisiones

- **F3 (`F` de producción):** 1 h si `Δ_p99 ≤ 14,9 s`, con R-FIN-8′/13′ en vigor, objetivo y `3k` conservados, `k = 30`.
- **F = 2 h provisional:** confirmada como el mínimo que sobrevive a todo. Cuesta 1,24 h sobre lo que el modelo de diseño
  pediría, y ese es el precio de no haber medido `Δ`.
- **F4 (`k`):** bajarlo es la peor de las cinco palancas; `k = 20` no es admisible.
