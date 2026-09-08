# Ronda 10c (D9) — Qué compra de verdad una `F` corta: el sembrador, la pinza del steering y el usuario

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio). Luego: `research/dag-poas-bitacora-2026-09-08.md`
§0, §2, §6, §11 · `research/dag-poas-ancla-de-orden.md` §1.2, §1.3, §2 (R-FIN-2, 3, 14), §3, §4 (puntos 2, 3 y 8), §6 (NO
editar) · `research/dag-poas-ancla-de-finalidad.md` §1 (el `A*` del plotter, «lookahead `L + I`»), §1.3 y §10 ·
`research/scripts/d9-ronda9c/informe.md` §D y §E.1 · `research/dag-poas-ancla-de-orden-auditoria-8c.md` §3 ·
`research/scripts/verif_almacen_ganadores.py` · `research/coste-ploteo-medido.md` · `research/scripts/verif_constantes.py`
(reversión a 600 s) · `research/scripts/verif_frontera_vs_F.py`.

**Contexto.** `F` se escribe hoy como `F = max(F_carrera, I/(W/κ − 1))` y además se acorta «para el usuario y contra el
sembrador» (plotter rápido que conoce los retos con antelación `I + F`). Pero con R-FIN-14 el reto de cada slot sale de
un PoT **secuencial** y, con `ρ ≤ 1`, nadie conoce un reto antes de que el PoT llegue a él. Sospecha del principal: parte
del argumento del «lookahead `I + F`» viene de diseños anteriores (reto = función del flujo, evaluable por adelantado) y
puede no aplicar ya. Tu trabajo: decir qué término manda de verdad en `F` en cada configuración.

## Puntos

**A · El lookahead real bajo R-FIN-14.** Con PoT secuencial: ¿cuántos slots por delante conoce sus victorias un granjero
honesto (`ρ = 1`)? ¿Y un atacante con `ρ ∈ {1,5; 3}` (adelanto `L(1 − 1/ρ)` acotado por la inyección)? ¿Y con la opción
(h) de revelación retardada? Traza el origen de «lookahead `I + F`» y de «margen B, plotter 10×» (ronda 7 §1 `A*`, 9c §D,
D8) y di si sobreviven, se reducen o desaparecen. Si el sembrador ya no puede sembrar a tiempo, dilo con número
(`research/coste-ploteo-medido.md`: ritmo de ploteo real frente a la ventana que le queda).

**B · La pinza `F ≥ I/(W/κ − 1)`.** Origen (ronda 7 §1.3, BDK `research/fuentes/bdk19.txt`), qué es `W/κ`, por qué 1,22 y
no 2,5, y si sigue siendo una restricción bajo R-FIN-14 (steering acotado por `n_eval`) y bajo (h) (steering 0). Si es un
artefacto de un diseño anterior, demuéstralo; si es real, qué `W/κ` permite qué `F` con `I ∈ {300, 851} s`.

**C · Lo que espera el usuario.** `F` es la garantía de irreversibilidad, pero un comerciante no espera `F`: espera a que
la probabilidad de reversión baje. Con el modelo corregido (`δ = 0`, ventaja `3k`) y con el pesimista, tabla de
probabilidad de reversión a `{60, 300, 600, 1 800, 3 600} s` para `α ∈ {0,10; 0,25; 0,33}` (`verif_constantes.py`,
`d8_a1c_riesgo.py`). Conclusión: ¿qué gana el usuario con `F = 1 h` frente a `2 h`, más allá de la garantía?

**D · Entrega.** Tabla: configuración (`ρ_max = 3` sin (h); con (h)) × término (`F_carrera`, pinza, sembrador, usuario)
→ `F` mínima que impone cada uno y cuál manda. Recomendación con etiqueta.
