# Ronda 10b (D9) — El suelo de `F`: `F_carrera` y sus palancas

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio). Luego: `research/dag-poas-bitacora-2026-09-08.md`
§0, §2, §11 (punto 4: la tabla frontera-vs-F) · `research/scripts/verif_frontera_vs_F.py` y su `.salida.txt` ·
`research/scripts/d9-ronda9a/r9a_a3_frontera.py`, `informe.md` §L5-L6 y `research/dag-poas-ancla-de-orden-auditoria-8a.md` ·
`research/scripts/verif_constantes.py` · `research/scripts/d8-ronda8/d8_a1c_riesgo.py` y `research/dag-poas-ancla-de-orden-auditoria-7.md`
(la `δ` pesimista y «máx real 0,56·3k») · `research/dag-poas-recursion-flujos.md` (de dónde sale `3k` y la constante `c`) ·
`research/dag-poas-delta-real.md` y `research/scripts/verif_tau_vs_lambda.py` (cómo se fija `k`) ·
`research/dag-poas-ancla-de-orden.md` §1.1 y §5.5 (NO editar). Paper: `research/fuentes/phantom-ghostdag.txt` (Lema 10, la
carrera) y `bdk19.txt`.

**Contexto.** Katana ha decidido `F = 2 h` provisional y quiere `F` lo más corta posible en producción. Medido hoy con el
instrumento de 9a: la frontera de flujo único baja con `F` (2 h → 44,6 % con `δ = 0`, 35,1 % con la `δ` pesimista de D8;
20 min → 34,8 % / 28,7 %, y el 33 % cae). `F_carrera(33 %) = 0,28 h` (`δ = 0`) / 0,99 h (`δ` D8). **El suelo de `F` lo pone
la carrera.** Tu trabajo: decir de qué depende ese suelo y cuánto se puede bajar sin perder colchón.

## Puntos

**A · Control.** Reproduce `verif_frontera_vs_F.py` (46,8784 % / 36,5431 % y la fila `F = 2 h`). Reutiliza
`r9a_a3_frontera.prev/union10` SIN reescribirlos.

**B · Palancas de `F_carrera`, cada una con tabla:**
1. **Ventaja inicial `3k`.** Es cota (§5.5 de la propuesta). D8 midió «máx real 0,56·3k» — localiza la fuente exacta
   (fichero, línea, condiciones). Recalcula `F_carrera` al 33 % y 35 % con ventaja `∈ {3k, 2k, 1,68k, k}` en los dos modelos.
   ¿Es legítimo diseñar con la ventaja medida? Argumenta con el Lema 10 / la recursión de `dag-poas-recursion-flujos.md`.
2. **`k`.** `k = 30` viene del punto fijo del retarget a `Δ = 4 s`. `F_carrera` para `k ∈ {20, 25, 30, 40}` (con la `δ`
   coherente con cada `k` si el modelo la tiene; si no, decláralo).
3. **Objetivo de riesgo.** «Unión a 10 años < 1e-10» es una elección. Compárala con lo que de hecho garantiza Bitcoin
   (6 confirmaciones a 10 % de hash ≈ 1e-3 según Nakamoto §11; cita el paper en `research/fuentes/` si está, si no LAGUNA)
   y con Chia. Tabla `F_carrera` para objetivos `{1e-6, 1e-8, 1e-10, 1e-12}` a 10 años, al 33 %.
4. **El modelo de `δ`.** Tras R-FIN-8′/13′ (9b) y el doble conteo (9a), ¿cuál es el modelo correcto para diseñar `F`:
   `δ = 0`, la `δ` pesimista de D8, o algo intermedio? Argumenta con las fuentes; propón el que se debe usar y por qué.
5. **`Δ`.** `F_carrera` al 33 % para `Δ ∈ {4, 8, 16, 20} s` (usa la relación `δ₀(Δ)` de 9a `r9a_a6_frontera_delta.py`).

**C · Entrega.** Una tabla final: la `F` más corta que conserva **≥ 2 puntos** de colchón sobre el 33 % en cada modelo y
configuración, y tu recomendación de `F` provisional y de `F` de producción, con lo que cada una asume. Declara si el
`I` (851 s o 300 s) entra en alguna cuenta (épocas por año) y cuánto pesa.
