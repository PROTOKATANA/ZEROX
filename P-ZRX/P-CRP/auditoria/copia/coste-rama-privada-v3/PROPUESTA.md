# CRP-v0.3 · Propuesta

Obligaciones que una futura regla de flujo/controlador debe cumplir. **No** se redactan
reglas normativas ni números para el SPEC.

## Flujo PoT y R-FIN-5

- **F1.** La incorporación se decide sobre el **prefijo de flujo en `slot(X)`** de **todo**
  `X ∈ past(B)`, no solo de los padres, y como función exclusiva de `past(B)`.
- **F2.** `PotOrigin` (dominio, origen, semilla, `N` inicial) y eventos
  `(slot_activación, entropía, N_efectivo)` deben estar autenticados; si falta, `Pendiente`.
- **F3.** El flujo se comprueba **antes** de U2/U3 y de colorear: una fusión con prefijo
  incompatible se rechaza aunque los billetes sean únicos.
- **F4.** La presentación debe definir una convención terminal simétrica (no regalar un
  hijo/sentinel a una rama) y una regla explícita de decisión del observador.
- **F5.** Debe separarse "máximo de ramas" de "suma aditiva"; `S` es escenario, no capacidad.

## Controlador (C-HDR-06) y finalidad

- **C1.** Ventana, arranque, redondeos y fusiones fuera de ventana deben cerrarse antes de
  declarar una traza `Válida`.
- **C2.** El `SR` se deriva del pasado; la circularidad con el `rango_solucion` declarado
  debe ser imposible por tipo.
- **C3.** Retarget y emisión deben contar el mismo conjunto pagable (R-FIN-13′).

## C-GD-11, métrica y economía

- **M1.** Métrica, valor, bootstrap, borde y relación con finalidad/poda de C-GD-11.
- **M2.** Finalidad R-FIN-7 con `F` y `Δ` de red DAG; sin ellos, régimen largo `Pendiente`.
- **E1.** `η_h` y `η_a` medidos por separado, con IC; sin muestra, curva inconclusa.
- **E2.** Cualquier afirmación económica exige `S_adversario` medido (I/O, CPU/PoT/PoAS por
  slot, colas, margen de utilización); `S·α` es sensibilidad.
- **E3.** Distinguir coste marginal de hundido; "cero espacio adicional" ≠ "ataque gratis".
