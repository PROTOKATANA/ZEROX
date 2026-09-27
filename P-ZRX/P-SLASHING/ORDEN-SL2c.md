# ORDEN-SL2c — ¿Dan las reglas que existen (D-T08 + EV-17 + RAT-3) la región de disuasión de SL-2b?

**LINEO (`V-ZRX/LINEO.md`) rige este código Julia**; léelo íntegro antes de escribir código.

- **ID:** SL-2c. **Fecha:** 2026-09-27 (redactada ≈ 11:20; se lanza **después de W07b**, para no perturbar sus
  mediciones de CPU). **Director:** Claude. **Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`).
- **Zona escribible:** `P-ZRX/P-SLASHING/SL2c/` (proyecto Julia nuevo; el modelo de `P-ZRX/P-SLASHING/SL2/` se
  **copia** y no se modifica).
- **Motivo:** IPA C-12. El modelo de disuasión de SL-2/SL-2b supone una retención `ρ_ret` de cada recompensa durante
  `T_v` slots; **ninguna regla la implementa**. Lo que el código sí hace (verificado por el director):
  la coinbase PoST se acredita **entera** a la garantía del productor (D-T08, `creditar_post`, madura en
  `M_REC_SLOTS = 30`); EV-17 congela y EV-19 confisca con `f = 1` la garantía **total**; RAT-3 impide liberar antes
  de `último_slot_producido + Plazo_slots (300) + M_margen_slots (60)` y `R_SLOTS = 600` después del retiro.
- **Pregunta falsable:** «Con esas reglas y los valores del perfil dev, la pérdida del atacante que recluta
  (SL-2b, con y sin connivencia del incluidor) cae dentro de la región de disuasión de SL-2b en el caso central
  (reparto empírico DS-6), **incluso si el atacante rota claves** para sacar sus recompensas cuanto antes; y la
  pérdida esperada del honesto sigue ≤ 1 % de su ingreso anual.»

## Decisiones del director

1. **Modelo de retención de las reglas reales:** fracción retenida `1` (toda la recompensa PoST); horizonte de
   exposición de cada recompensa = desde que se acredita hasta que puede liberarse, que depende de la estrategia:
   (a) productor continuo: nunca libera mientras produce; (b) **rotación de claves** con periodo `P`: una clave deja
   de producir, retira y libera tras `máx(R_SLOTS, 360)`; el atacante elige `P` para minimizar lo expuesto. Se
   calcula el `T_v` **equivalente** de cada estrategia en las unidades de SL-2b, **cuidando la reserva F5** de
   `SL2/INFORME.md` (saldo por clave frente a pérdida por reclutado): se publican las dos lecturas.
2. **Coste para el honesto (nuevo):** con RAT-3, un productor continuo **no puede disponer de sus recompensas sin
   dejar de producir con esa clave** al menos `360` slots más `R_SLOTS`. Cuantificar ese coste de liquidez (fracción
   de ingreso inmovilizada, tiempo sin producir por clave con la mejor rotación honesta) y compararlo con el 1 % de
   SL-2.
3. Mismos escenarios, rejillas, semillas y repartos de SL-2b (empírico DS-6 central, Pareto H3 pesimista); `f = 1`,
   2/8 al incluidor (RAT-2′), `q = 10` ZZK por clave convertida a las unidades del modelo con la conversión
   **declarada** (si no hay una fundada, se publican resultados como función de esa conversión y se dice).

## Verificación

Referencia exacta pequeña (`Rational{BigInt}`) frente a la vía rápida en ≥ 20 celdas; reproducción de un punto de
SL-2b con `ρ_ret = 0,10`, `T_v = 10⁵` (el modelo copiado debe dar lo mismo); tabla de cobertura de estrategias
(continua, rotación con varios `P`, connivencia sí/no) con mínimo 1 celda por fila. **Prohibido Python.**
Presupuesto: 1 h 30 min, 8 hilos, 16 GiB. `INFORME.md` con veredicto, tabla de `T_v` equivalente por estrategia,
coste de liquidez del honesto, lo no demostrado; `HUELLAS.sha256`; `HORAS.log` (`date -Is` real); nombre de modelo.
Nada fuera de la zona; sin git; sin secretos. Si falta una definición, infórmala **antes de editar**.
