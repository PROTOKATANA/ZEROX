# Ronda 11c (D9) — Tres hipótesis del informe de los 52 problemas, puestas a prueba con el instrumento de D9-f

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio; sin presupuesto de tiempo, resultado completo). Luego:
`research/dag-poas-informe-52-problemas.md` §6 (6b, 6c), §7 (7c), §10 (`S_max` en dos escalas) · `research/dag-poas-ancla-de-orden.md`
§2, R-FIN-1, R-FIN-1a, R-FIN-6, R-FIN-11 (NO editar) · `research/dag-poas-ancla-de-orden-auditoria-6.md` (D9-f: la cuarta ancla,
`m ≤ 1 + λ·S_max`, `m = 2,54` medido, B0/B1) · `research/dag-poas-ancla-de-orden-auditoria-3.md` (D9-c: por qué cayó el ancla por
posición, «contador de saltos») · `research/dag-poas-ancla-de-finalidad.md` (ronda 7, ataque A1 que motivó R-FIN-1a) ·
`research/scripts/d9-ronda8f/` (instrumento de D9-f: `r8f_*.py`, `salida_b1_gran1.txt`) · `research/scripts/d9-ronda9c/r9c_lib.py`
(la clausura de publicación que corrige el artefacto «retener y publicar hijo») · `research/scripts/d9-ronda8c/r8c_gd.py`,
`r8c_steering.py` (`c_m`) · `research/scripts/verif_a2prima.py`.

**Contexto.** El ancla `I_j` es el bloque de la cadena seleccionada con menor `blue_work` entre `slot ≥ T_j`; el atacante elige
entre `m` candidatos (medido 2,54; cota `1 + λ·S_max = 151`) y el steering va como `c_m·√(…)`. El informe propone tres cambios
para reducir `m` sin censurar a nadie, todos HIPÓTESIS sin simular:

- **H1 · Ancla por slot exacto.** `I_j` := el bloque de la cadena seleccionada con `slot(B) = T_j`; si no hay ninguno, el primero
  con `slot > T_j` (menor slot; desempate por `blue_work`). Reduce el menú a los bloques de un slot (`λ·τ = 1` en media).
- **H2 · Desempate del ancla por `solution_distance`** en vez de por `blue_work` entre candidatos del mismo slot (R-FIN-6 ya
  desempata así los bloques).
- **H3 · `S_max` en dos escalas.** Validez a `S_max = 150 s` (como hoy) y **candidatura a ancla** solo si el bloque fue
  publicado antes de `S_max_ancla = 45 s` (= `W_dec`), con «publicado» := `slot` del primer bloque de la cadena seleccionada que
  lo referencia. Cota de `m`: 151 → 46.

## Puntos

**A · Control.** Reproduce `m = 2,54` (D9-f B1, `salida_b1_gran1.txt`) con el instrumento de D9-f **más la clausura de
publicación de 9c** (`r9c_lib.py`): esa es la línea base (y de paso cierra la laguna 41 del catálogo: `m` con retención sin
artefacto, 12 semillas, `α ∈ {0,10; 0,25; 0,40}`).

**B · `m` bajo H1, H2, H1+H2, H3, H1+H3.** Misma familia de estrategias del atacante que D9-f (global y bloque a bloque,
retención hasta `S_max`), 12 semillas, `α ∈ {0,10; 0,25; 0,40}`, criterio `α`. Tabla `m` y `c_m` (con `r8c_steering.c_m`), y el
`I` que resulta para `g = 3,6 %` con `n_eval = 135` (`ρ_max = 3`): `I = c_m·√(n_eval/(αλ))/g`.

**C · ¿Reabren algo?** Para cada hipótesis: (1) el ataque A1 de la ronda 7 (por el que existe R-FIN-1a): ¿un atacante puede
fabricar bloques con `slot = T_j` a voluntad? (el slot lo fija el PoT: solo puede **retener** un bloque suyo del slot `T_j`, no
crear uno después); (2) el «contador de saltos» de D9-c: ¿H1 devuelve al atacante una magnitud que fabrica a coste cero?;
(3) el Lema A4-slot (Prop. 7 cubre el ancla) con el desempate H2: escribe la prueba o el contraejemplo; (4) H3: ¿el «slot del
primer referenciador» es función de `past(B)`? (sí por construcción; comprueba que dos honestos con vistas distintas leen el
mismo `I_j` en `t_j` — el test de dos vistas de D8 A2, `d8-ronda8/`); (5) H3 con un atacante que **es** el primer
referenciador de sus propios candidatos: ¿puede adelantar la candidatura? (solo retrasarla, según el informe: verifícalo).

**D · Censura.** Con H3, ¿pierde algo un granjero honesto con retraso `E ∈ {20, 45, 60, 150} s`? (Su bloque sigue siendo válido
y cobra; solo deja de poder ser ancla: mide cuántas veces un honesto lento habría sido ancla y ya no lo es, y si eso le cuesta
recompensa — no debería: el ancla no cobra distinto.)

**E · Entrega.** Tabla hipótesis → `m` → `I` a `g = 3,6 %` → qué reabre → coste; y tu recomendación de cuál adoptar, con
etiqueta. Si alguna reabre un ataque, dilo en la primera línea del informe.
