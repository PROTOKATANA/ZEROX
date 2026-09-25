# Revisión del director — T02 + T02-A (2026-09-26)

**Ejecutor:** DeepSeek (T02 se detuvo con 4 ambigüedades de la orden; T02-A, 01:16–01:35).
**Veredicto de la entrega:** aceptada. **Veredicto de la pregunta falsable:** **refutada dentro del
modelo**, y la refutación es **correcta**: la pregunta estaba mal planteada por el director.

## 1. Comprobaciones del director

- Control E1: valores del artículo de Nakamoto §11 (`q = 0,1, z = 5 → 0,0009137`;
  `q = 0,3, z = 5 → 0,1773523`) reproducidos en `resultados/E1_tabla_nakamoto.csv` con error
  `< 2·10⁻⁸`.
- `ENTRADA-T02*.sha256` OK al empezar y al terminar (según `PROGRESO.md`); `Pkg.test()` 69/69.
- No se leyó `T01/` (independencia respetada).

## 2. Qué refuta exactamente

La pregunta decía que con FC-3 ningún adversario con `a < 1/2` hace cambiar a un nodo en línea
«cualquiera que sea `h`». Es **falso** porque existe una **ventana previa al primer bloque PoST
honesto**: mientras ningún sufijo tiene peso PoST, FC-3 decide por trabajo PoW y el ataque es la
carrera clásica de Nakamoto sobre los últimos `k` bloques (E2: con `h = 0,25`, `k = 6`, éxito
≈ 0,039 casi independiente de `a`: 0,036 con `a = 0,1`, 0,043 con `a = 0,45`; con `h ≥ 1/2`, ≈ 1).
`d = 0` en esa ventana, así que `C-FIN-01` no protege.

**Lo que no refuta:** la razón de ser de FC-3. Una vez que existe peso PoST honesto, el hash deja de
decidir (E2, barrido en `a`: el éxito solo sube con `a ≥ 1/2`). Y E3 confirma que la alternativa
FC-1 es peor: da al hash poder **permanente** tras el corte (el nodo nuevo cambia siempre) y crea una
**partición entre nodos en línea y nodos nuevos** (`P(d ≥ F_slots)`, hasta 1).

## 3. Decisiones

- **D-T03 (FC-3) se mantiene**, con el límite escrito: la seguridad de los últimos bloques PoW antes
  del primer bloque PoST es la de Nakamoto (depende de `h` y de la profundidad), no la de PoST.
- **Refutación nueva RFT-13** en `D-ZRX/RFT-ZRX.md`.
- **IPA A-05** pasa a «decidido provisional con límite medido»; se abre **A-05b** (reducir lo que está
  en juego en la ventana: p. ej. cerrar la admisión de depósitos `K` bloques antes del corte, que es
  la alternativa ya listada en `CONTRATO-v0.md` §8 `Madurez_residual`).
- **IPA A-08 (censura de depósitos):** con `h ≤ 1/2` el corte se retrasa de forma finita (p. ej.
  `h = 0,4`, `M_dep = 12`: media 25 `T_pow`, p99 64); con `h = 0,9` y `M_dep ≥ 6` la censura domina
  (81 % y 99,98 % de réplicas sin corte en `10⁴ T_pow`). D-T04 (prolongar PoW) deja a una mayoría de
  hash la capacidad de alargar la emisión PoW: **riesgo confirmado**, alternativa por evaluar
  (`Fallo_activacion`, tope `H_corte_max`).

## 4. Límites que se heredan (del propio informe)

Sin latencia (optimista para el honesto), sin retarget (E5 y `W_min` no medidos), `k = 0` en vez de
GHOSTDAG, sin sesgo de semilla, sin precios de hash; rejilla de E2 incompleta (35 puntos).

## 5. Error del director que queda registrado

La orden T02 original dejó cuatro definiciones abiertas (E1 `k` frente a `z`, reloj PoST de E2, E3
imposible sin retarget, E4 sin proceso de depósitos) y la pregunta falsable incluía todo `h < 1`, lo
que mezclaba la seguridad del PoW anterior al corte con la de FC-3.
