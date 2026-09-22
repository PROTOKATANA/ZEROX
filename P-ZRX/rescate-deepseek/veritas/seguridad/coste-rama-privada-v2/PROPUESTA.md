# CRP-v0.2 · Propuesta

Únicamente **obligaciones** que una futura regla de flujo/controlador debe cumplir para poder
cerrar un umbral. **No** se redactan reglas normativas ni números para el SPEC.

## Flujo PoT (R-FIN-5 y dependencias)

- **F1.** Toda decisión de incorporación debe poder evaluarse sobre el **prefijo de flujo en
  `slot(X)`**, no sobre etiquetas actuales, y debe ser función exclusiva de `past(B)`.
- **F2.** El descriptor debe autenticar `PotOrigin` (dominio, origen de índices, semilla,
  `N` inicial) y los eventos `(slot_activación, entropía, N_efectivo)`. Sin ellos, el resultado
  debe ser `Pendiente`, nunca `true`.
- **F3.** Debe existir una regla de coexistencia con la caché de PoT por slot (C-NET-31/32): o
  caché `(flujo,slot)` o caché global, pero no ambas por convención.
- **F4.** Una divergencia posterior no puede invalidar retroactivamente un bloque cuyo prefijo
  coincidía en su slot; una incompatibilidad en el slot consultado debe rechazarse **antes** de
  colorear.
- **F5.** Debe separarse explícitamente "máximo de ramas incompatibles" de "suma aditiva"; la
  suma no puede presentarse como consecuencia de desactivar R-FIN-5.

## Controlador de rango (C-HDR-06)

- **C1.** Debe fijar ventana, arranque/bootstrap, redondeos y política de fusiones fuera de ventana
  antes de que cualquier corrida adversarial pueda declararse `Válida`.
- **C2.** El `SR` usado para validar un bloque debe derivarse del pasado causal, no del propio
  `rango_solucion` declarado; la circularidad debe ser imposible por tipo, no por convención.
- **C3.** El conjunto que el retarget cuenta y el que la emisión paga deben ser el mismo
  (R-FIN-13′), incluyendo `rojo_k` y excluyendo `rojo_U3`.

## C-GD-11 y finalidad

- **M1.** Deben decidirse métrica, valor, bootstrap, borde de igualdad y relación con
  finalidad/poda. Ninguna constante puede copiarse de Kaspa ni derivarse de `F = 2 h`
  (provisional).
- **M2.** La finalidad aplicable (R-FIN-7) necesita `F` y `Δ` de la red DAG; sin medirlos, el
  régimen largo queda `Pendiente`.

## Métrica y coste

- **E1.** La eficiencia de trabajo `η_x` debe definirse como
  `E[blue_work_x]/E[trabajo bruto elegible_x]` con ventana y punta/contexto declarados; `η_h` y
  `η_a` medidos por separado, sin suponer igualdad.
- **E2.** Cualquier afirmación económica concreta debe acreditar `S_adversario` con un perfil de
  hardware medido (lecturas aleatorias, p50/p95/p99, CPU/PoT/PoAS por slot, margen de
  utilización); el contrafactual `S·α` es solo sensibilidad.
- **E3.** Debe distinguirse coste marginal de coste hundido, y "cero espacio plotteado
  adicional" de "ataque gratis".
