# REVISIÓN T04-C — generador del oráculo DAG con nonce correcto, retiros y liberaciones

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Entrega:** `P-ZRX/P-DAG/T04/` (INFORME y
PROGRESO §T04-C, `resultados/*-v0.2.*`, `cobertura-v0.2.txt`), DeepSeek, 03:39–03:53.

**Veredicto: SUPERADO.** Los vectores v0.2 son la fuente del diferencial de W06a.

## Comprobado por el director

- `ENTRADA-T04-C.sha256` 5/5; T01 y `src/EstadoDAG.jl` sin cambios; v0 y v0.1 intactos.
- `sha256(vectores-estado-dag-v0.2.txt) = ee783b52…a94dd73`, igual al `.sha256` entregado.
- `cobertura-v0.2.txt` (generada por código): en los 900 casos aleatorios, aplicadas 349 depósitos,
  808 retiros, 115 liberaciones; `ErrDobleGasto` 316; reorganizaciones que deshacen garantía 312;
  `ErrNonce` 853. Los seis mínimos de la orden se cumplen; `run.jl` (3 000 historias) también.
- `run-estado-dag-v0.2.log`: D-12 8/8, D-13 5/5, 46 500 bloques, 600 000 órdenes IE-3, **0 fallos**.
- Relectura independiente: 913 casos, 0 discrepancias. Sin tests borrados en `test/runtests.jl`.

## Observaciones (no bloquean)

1. **Denominador de `ErrNonce`.** El ejecutor declaró antes de editar (AMBIGUEDAD-C1) que el tope
   del 25 % se mide sobre las operaciones **construidas** (4 663): 18,3 %. Sobre las **evaluadas** en
   el orden seleccionado final (2 280) es 37,4 %, porque el generador construye cada operación contra
   el estado de un bloque cualquiera, no necesariamente del pasado del nuevo, y el nonce deriva entre
   ramas. La intención de la orden (que la aplicación no quede dominada por el descarte) se cumple:
   1 272 operaciones de garantía aplicadas frente a 853 `ErrNonce`.
2. **Pesos ajustados** a 0,12 / 0,18 / 0,22 / 0,48 (transferencia / depósito / retiro / liberación)
   y `npost` 15–16: con los de partida las liberaciones aplicadas quedaban en 99. Declarado.
3. **Recuento de `Pkg.test()`** baja de 377 a 372 pese a añadir D-12, D-13 y la prueba de cobertura:
   parte de las aserciones dependen de las historias generadas; ninguna prueba se eliminó (diff
   revisado).
4. **D-13** fija el comportamiento que el código Rust debe reproducir: una liberación no vencida en el
   slot de su bloque X se descarta en `Estado(past(X))` (`ErrSaldo`) y se **aplica** en
   `Estado(past(Y))` si Y fusiona X de lado con `slot(Y) ≥ inicio + R_slots` (RD-4).
