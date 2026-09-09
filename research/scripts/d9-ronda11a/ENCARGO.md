# Ronda 11a (D9) — `k` con margen frente a `Δ`: cuánto compra y cuánto cuesta

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio; sin presupuesto de tiempo, resultado completo). Luego:
`research/dag-poas-mitigaciones-cuatro-riesgos.md` §1 (M2, M3) · `research/dag-poas-ancla-de-orden-auditoria-8a.md` §4 y
`research/scripts/d9-ronda9a/informe.md` §5.5 y `r9a_a6_frontera_delta.py` (cómo se midió `δ₀(Δ)` a `α = 0`) ·
`research/scripts/verif_tau_vs_lambda.py` (el punto fijo `k*(D)` y `δ_real`) · `research/dag-poas-delta-real.md` ·
`research/scripts/d9-ronda10b/informe.md` §B.2 y §B.5 y `r10b_b2_k.py`, `r10b_b5_delta_red.py` (`F_carrera` vs `k` y vs `Δ`) ·
`research/scripts/verif_frontera_vs_F.py` · `research/dag-poas-ancla-de-orden.md` §1.1 y R-FIN-12 (NO editar) ·
`research/fuentes/phantom-ghostdag.txt` (la ecuación (2) de `k`, Lema 9) · `research/fuentes/dagknight.txt` §1.1.

**Contexto.** `k = 30` se calibró a `Δ = 4 s` y aguanta hasta `Δ ≈ 16 s`; a 20 s la frontera cae a 32,4 % y el 33 % se pierde.
`F` no compra `Δ` (10b). La palanca que sí puede comprar tolerancia a `Δ` es `k` (y `λ`). Nadie ha puesto número a cuánto `k`
hace falta para cada `Δ` ni a lo que cuesta.

## Puntos

**A · Control.** Reproduce `k* = 29` de `verif_tau_vs_lambda.py` a `D = 4` y la tabla `δ₀(Δ)` de 9a §5.5 con su instrumento.

**B · `k*(Δ)`.** El punto fijo de `verif_tau_vs_lambda.py` para `D ∈ {4, 8, 12, 16, 20, 24, 32}` s con `λ = 1` y `τ = 1 s`. Y la
misma cuenta con `λ = 1/2` (un bloque cada 2 s). Tabla: `Δ`, `k*`, `δ_real`, reversión a 600 s, cabeceras/año.

**C · Tolerancia real de cada `k`.** Para `k ∈ {30, 40, 50, 60}` y `Δ ∈ {4 … 32}`: `δ₀(Δ, k)` **medido** con el instrumento de 9a
(`α = 0`, 12 semillas), no la cola de Poisson (que sobreestima: 9a lo midió); frontera de flujo único a `F = 2 h` con ese `δ₀`
(instrumento `r9a_a3_frontera.prev/union10`, reutilizado sin reescribir, con `K` como parámetro); `F_carrera(33 %)` y la `F`
mínima con 2 puntos de colchón. Entrega: **el `Δ_max` que cada `k` tolera con 2 puntos de colchón sobre el 33 %.**

**D · Lo que cuesta cada `k`.** `mergeset_size_limit = 6k`, `max_block_parents = k/2` (R-FIN-12): bytes de cabecera y GB/año;
`F_carrera` con `δ = 0` (10b B.2: `k` grande la alarga); coste de coloreado GHOSTDAG por bloque (si se puede acotar por
`k²` con fuente, cítala; si no, LAGUNA); tiempo de confirmación a 600 s. Tabla `k` → coste.

**E · `λ = 1/2` como alternativa.** Misma tabla C y D con `λ = 1/2`, `k*` recalculado: ¿compra más tolerancia por unidad de
coste que subir `k`? Incluye la pérdida de reversión a 600 s frente a `λ = 1` (la rama (B) a `λ = 1/6` perdía 7 órdenes).

**F · Entrega.** Recomendación con número: qué `k` (y qué `λ`) publicar para cada `Δ_p99` que se mida (4-8, 8-12, 12-16,
16-20 s), con su coste. Declara si `k` puede cambiarse sin hard fork (lee R-FIN-12 y el paper: `k` entra en el coloreado de
todo bloque) — hipótesis explícita si no hay fuente.
