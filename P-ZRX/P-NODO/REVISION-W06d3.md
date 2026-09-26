# REVISIÓN W06d3 — PoST por red, bifurcaciones PoW y tres nodos de extremo a extremo

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet, único, ≈ 4 h 53 min
(por encima de las 4 h previstas). Evidencia: `resultados-W06d3/` (informe, progreso, logs, incluida la
ejecución real `v4-real-1`). **Veredicto: SUPERADO PARCIALMENTE. Migrada** por parche (13 rutas, base
idéntica, `git apply --check` limpio, 13 huellas verificadas; lock idéntico). Suite: **721 pasan, 0 fallan,
2 ignorados** (715 antes; 0 perdidos, 6 añadidos).

## Lo que queda hecho

- `BloqueRed::Post` transporta la justificación PoT (códec de `zx_core::wire_dag`): los PoST ajenos ya se
  pueden verificar por red.
- Elección entre ramas PoW (FC-3) en `zx-cadena` (`mejor_punta_pow`, candidatos a terminal) y el nodo mina
  sobre la punta seleccionada; 4 tests deterministas de bifurcación y reunión.
- **Cuatro fallos reales, solo visibles con procesos y red reales, corregidos:** nonce de depósito repetido
  (varias coinbases maduras en un bloque); carrera en `fase_pow` que producía `ErrPowTrasCorte` en un bloque
  propio; padres ajenos no registrados en el `ServicioPot` del productor; `SlotNoProgreso` tratado como
  pánico. Diagnóstico de la desconexión de W06d2: nada volvía a pedir cabeceras PoW si un bloque se perdía
  por gossip; reintento periódico.
- Prueba de reinicio: **5/5** ejecuciones seguidas.

## Lo que no está demostrado

V4 (tres procesos cruzan el corte) no cerró con la versión final: en la última ejecución los tres minaron
≈ 9 min hasta la altura ≈ 290 **sin rechazos y sin fijar nunca el terminal**; V5, V6 (con procesos reales) y
V7 en fase PoST quedaron sin ejecutar. Dos fallos sin resolver:

1. **El terminal nunca se fija con tres nodos.** **Hipótesis del director:** el propio ejecutor declara que el
   indicador local `depositada = true` no depende de la rama; con tres mineros a la vez hay bifurcaciones
   frecuentes, y si el bloque que llevaba el depósito queda fuera de la rama ganadora, el nodo no vuelve a
   depositar y nunca se reúnen las `K_min` claves con garantía que exige Φ. Encaja con que el mismo camino
   pase con un solo proceso (sin bifurcaciones).
2. `Pot(PasadoIncompleto)` al verificar un bloque propio, causa no encontrada.

## Otros

- El ejecutor afirma que LINEO «no aplica» a este trabajo en Rust: **incorrecto** (`AUTO-ZRX.md` §52; ya
  corregido en la orden W06d1). Tercer ejecutor que lo lee así: la próxima orden lo dirá en su primera línea.
- Todo lo pendiente pasa a `ORDEN-W06d4`.
