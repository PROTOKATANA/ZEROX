# REVISIÓN W06d4 — tres nodos reales cruzan el corte

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet, único, con varios
cortes forzados durante esperas largas (el director esperó cada proceso antes de retomarlo). Evidencia:
`resultados-W06d4/` (informe, progreso, horas, logs y registros de las ejecuciones reales; la carpeta
`run/` completa, 540 MB, queda en `deepseek/W06d4/`). **Veredicto: SUPERADO PARCIALMENTE. Migrada** por
parche (3 rutas, base idéntica, huellas verificadas; lock idéntico).

## Hito

**V4 superado con procesos reales:** tres `zx-node` en `127.0.0.1` fijan el mismo terminal y producen
**528 bloques PoST, 0 rechazos, 0 fallos fatales** durante varios minutos; la punta seleccionada converge
siempre (las 3 de 194 diferencias de resumen son del estado virtual, que depende de puntas laterales
transitorias). **V6(a) superado:** partición y reunión en fase PoW con reorganización en los tres nodos.

## Causas confirmadas y corregidas (con test que falla antes y pasa después)

1. **Hipótesis del director confirmada:** `CoinbasePropia.depositada` no dependía de la rama; con
   bifurcaciones reales el nodo dejaba de depositar y Φ no se cumplía. Ahora el depósito se decide sobre el
   estado de la punta seleccionada.
2. `Pot(PasadoIncompleto)`: un bloque de otra rama dejaba un hueco en `ServicioPot` y sus hijos fallaban.
   Nuevo `declarar_salida_pasada` (con detección de salida discrepante).

Suite 723/0/2 (sin la migración de SL-4a, que llegó después: **la combinación no se ha probado**).

## No superado (hallazgos nuevos, con causa y evidencia de una ejecución real)

- **V5** (cuarto nodo tardío): sincroniza bien, pero (a) intenta producir con una clave **sin garantía**
  (`ErrGarantia`) y (b) A y B caen por `Padres(SlotDePadrePosterior)`: el filtro de padres de `regimen.rs`
  solo mira el padre seleccionado, no los extra.
- **V6(b)** (partición y reunión en PoST): `ErrMergeDepth` (RD-5) porque con `N_dev = 2000` los slots
  corren tan rápido que unos minutos reales superan `F_SLOTS = 600`: calibración de la prueba.
- **V7** (`zx-adversario`): el objetivo no aceptó nada indebido ni cayó, pero la herramienta publica antes de
  que la malla de gossipsub esté formada y la ráfaga casi no llega: no concluyente.
- **Transversal:** la regla de W06d1 «bloque propio rechazado ⇒ fallo fatal» tira el proceso entero ante
  rechazos legítimos del protocolo en casos de borde reales; hay que distinguir un fallo interno de un
  rechazo legítimo.

Todo pasa a `ORDEN-W06d5`.
