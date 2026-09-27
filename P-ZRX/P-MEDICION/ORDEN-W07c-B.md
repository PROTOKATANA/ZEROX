# ORDEN-W07c-B — Analizador: métricas por bloque (no por evento) y slots vacíos

**LINEO (`V-ZRX/LINEO.md`) rige este código Julia**; léelo íntegro antes de escribir código.

- **ID:** W07c-B. **Fecha:** 2026-09-27 (≈ 16:01). **Director:** Claude. **Ejecutor:** DeepSeek
  (`deepseek-flash`, esfuerzo `high`). **Zona escribible:** solo `P-ZRX/P-MEDICION/analisis-registro-v1/` (se lanza
  desde ahí). **Prioridad mínima (`nice -n 19`), 1 hilo:** W07b está midiendo con procesos reales en la máquina.
- **Motivo (hallazgo del director al revisar R1 rep1 de W07b):** `calcular_bloques_padres_rojos`
  (`src/rapido.jl` ≈ 345) cuenta **eventos** `bloque_producido` y `bloque_red_admitido` de **todos** los nodos, así
  que cada bloque se cuenta una vez por nodo (×3 con tres nodos), y la distribución de «bloques por slot» ignora los
  slots sin bloques. En R1 rep1 dio una mediana de 3 bloques por slot cuando los datos crudos dan ≈ 0,95 (1 502
  bloques distintos en ≈ 1 574 slots). Error del director: el esquema (§3) no decía «bloques distintos».

## Qué hacer (decisiones del director)

1. **Bloques por slot:** se cuentan **bloques distintos por `hash`** (cada bloque una vez, tomando su `slot` de
   cualquier evento que lo traiga) y se incluyen **todos los slots** del intervalo `[mínimo, máximo]` de slots
   observados, también los que tienen 0 bloques. Se publican la distribución (p50, p95, máx.) **y** la media
   `bloques distintos / slots del intervalo`.
2. **Padres por bloque y fracción de rojos:** también por bloque distinto (una vez por `hash`); si dos nodos
   informan valores distintos para el mismo bloque, se cuenta y se informa (sería un hallazgo).
3. Revisa si alguna otra métrica del §3 cuenta el mismo bloque varias veces sin quererlo; si la hay, corrígela con el
   mismo criterio y dilo. La latencia de propagación **sí** es por pareja de nodos (correcto tal cual).
4. Tests: casos sintéticos a mano con respuesta exacta (tres nodos que ven los mismos bloques; slots vacíos; un
   bloque que un nodo no ve); los tests existentes siguen en verde (actualizando solo los que medían lo erróneo, uno a
   uno y explicado).

`Pkg.test()` en verde; sección «W07c-B» en `INFORME.md`; `HUELLAS.sha256` regeneradas; `HORAS.log` (`date -Is` real);
nombre de modelo. **Prohibido Python.** Presupuesto 45 min. Nada fuera de la zona; sin git; sin secretos. Si falta
una definición, infórmala **antes de editar**.
