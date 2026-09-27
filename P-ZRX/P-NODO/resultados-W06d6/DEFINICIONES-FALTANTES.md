# Hallazgo bloqueante para V5 (no una falta de definición previa a implementar — descubierto
# durante la verificación de la decisión 1)

**Fecha:** 2026-09-27 ~03:20. **No bloquea las decisiones 1-7** (todas ya implementadas, compiladas,
con tests en verde, y V0/V1/V2/V3/V4/V6/V7-parcial superados con evidencia real). **Sí bloquea el
"superado" literal de V5** (partición PoST y reunión).

## El hallazgo

`crates/zx-node/src/nodo.rs::admitir_pow_interno` (línea ~560), reconstruye `ServicioPot` de
verificación cuando el terminal cambia, **solo si** `self.cadena.contexto_dag().is_none()` — es
decir, solo **antes** de que exista ningún bloque PoST admitido (el propio comentario del código,
de `ORDEN-W06d3`, lo dice: "posible mientras `Cadena::contexto_dag()` sigue en `None`, FC-3: una
rama más pesada puede desplazar al terminal tentativo **antes de que exista ningún bloque PoST**").

Un nodo que **ya ha producido bloques PoST sobre su propio terminal** y luego, por una reorganización
PoW real (una rama con más trabajo acumulado, `actualizar_seleccion_pow`), ve cambiar su terminal a
otro distinto, **no reconstruye `ServicioPot`**: se queda verificando contra el flujo PoT del
terminal viejo. Todo bloque PoST legítimo construido sobre el terminal **nuevo** falla entonces con
`Pot(...)` → `MotivoCabeceraPendiente::Padres(PadreNoValidado)` — clasificado `Pendiente`, reencolado
en `post_pendientes` (tope 64) y **nunca resuelto**, porque nada vuelve a intentarlo salvo un éxito
de admisión posterior (y aquí ninguno llega: todos dependen de la misma reconstrucción que falta).

## Cómo se reprodujo (V5, reunión tras partición PoST)

1. Partición real: `A` (claves 0,1,2), solo, cruza el corte y produce ~25 slots de PoST sobre **su
   propio terminal**. `B`+`C` (claves 3,4,5 y 6,7,8, conectados entre sí, sin `A`) cruzan el corte y
   producen ~25 slots sobre **otro terminal** (su propia rama PoW, con el doble de mineros que la de
   `A`). Confirmado con `--dejar-de-producir-en-slot 25` igual en los tres, y con las puntas
   efectivamente distintas antes de reunir.
2. Reunión: se mata `A` y se relanza con el mismo `--datos` (su cadena persistida) añadiendo
   `--red-marcar` hacia `B` y `C` — con los tres ya en reposo (decisión 6), para que la reunión no
   compita con producción en marcha (un primer intento sin esto, documentado en `PROGRESO.md`,
   quedó como una carrera que tampoco convergía, por un motivo distinto y menos interesante: dos
   ramas produciendo a la vez).
3. `A` admite correctamente (por la sincronización por registro, decisión 1: **sí llega**, sin
   necesitar deposit de huérfanos página a página) la rama PoW más pesada de `B`+`C`
   (`reorganizacion_pow`, profundidad 30, `bloque_red_admitido` familia `pow`, veredicto `Aceptar`) y
   cambia su terminal seleccionado — la propia decisión 1 funciona exactamente como se pedía en este
   punto.
4. Pero a partir de ahí, **todo** bloque PoST de la rama de `B`/`C` que `A` recibe (por la
   sincronización por registro, que sigue entregándolos) se clasifica `Pendiente` con motivo
   `Padres(PadreNoValidado { padre: <hash del nuevo terminal> })` — el guard de arriba impide
   reconstruir `ServicioPot`, porque `A` ya tenía `contexto_dag()` = `Some(...)` de su propia
   producción previa. Confirmado leyendo el código exacto (`nodo.rs:557-565`) y cruzando el hash del
   "padre" contra los eventos de `B` (`bloque_minado`/`cambio_punta`, altura 30 — su terminal real).
5. El proceso queda vivo (0 caídas, 0 fatales) pero **estancado**: 30 bloques admitidos y ninguno
   más durante minutos de espera, sin ningún error visible salvo los eventos `bloque_red_pendiente`
   repetidos.

## Por qué no lo corrijo en esta orden

- El propio comentario del código ya declara la limitación (**no es una regresión de
  `ORDEN-W06d6`**): esta situación exacta — terminal cambia **después** de que el nodo ya produjo
  PoST sobre el terminal viejo — nunca se había ejercitado antes de esta orden. Las particiones
  previas verificadas (`REVISION-W06d4.md` V6(a)) eran **durante la fase PoW**, antes de que exista
  ningún terminal; V5 de esta orden es la primera vez que se prueba una partición **PoST**
  (después del corte, con las dos ramas produciendo PoST de verdad) seguida de reunión.
- Una corrección correcta no es un simple "quitar el `is_none()`": reconstruir `ServicioPot` con
  bloques PoST propios ya admitidos exige decidir qué pasa con esos bloques (¿se abandonan si la
  rama nueva pesa más? ¿se re-verifican contra el terminal nuevo?) — una decisión de arquitectura de
  consenso, no de red, que toca directamente `zx-cadena`/`zx-post` (**vedados** por el contrato de
  esta orden: "Vedado: zx-core, zx-consensus, zx-cadena, zx-dag, zx-post, zx-storage"). Tocarlo sin
  mandato explícito y sin tiempo para las pruebas de regresión que merece sería exactamente el tipo
  de decisión que esta orden pide **parar y declarar**, no tomar en solitario.
- La sincronización por registro (decisión 1, lo que sí pedía esta orden) **funciona correctamente**
  hasta este punto: entrega la rama pesada completa, en orden causal, sin necesitar huérfanos uno a
  uno. El bloqueo está en una capa distinta (reconciliación del `ServicioPot` tras un segundo cambio
  de terminal), aguas abajo de lo que esta orden tenía que arreglar.

## Qué evidencia sí deja V5

- Partición real lograda y confirmada (puntas distintas, ambos lados cruzan el corte y producen de
  forma independiente, ≥20 slots cada uno).
- La reorganización PoW de la rama más pesada **sí** se propaga y se admite correctamente tras la
  reunión (prueba de que la sincronización por registro funciona también para una rama PoW ajena
  completa, no solo para "iba unos bloques por detrás").
- **0 caídas, 0 errores fatales** en ningún momento, en ningún nodo, en ninguno de los dos intentos.
- Lo que **no** se pudo demostrar: que los bloques PoST de la rama ganadora se terminen admitiendo
  en el lado que pierde el terminal, y que los tres conversjan a la misma punta/`resumen_estado` en
  reposo. **V5: NO SUPERADO**, con la causa exacta identificada y sin ocultar el fallo.

## Recomendación para quien retome esto

Decidir, como cuestión de arquitectura de consenso (fuera de esta orden): si un nodo que ya produjo
PoST sobre un terminal debe (a) reconstruir `ServicioPot` desde cero para el terminal nuevo y volver
a verificar/podar sus propios bloques PoST huérfanos de la rama vieja, o (b) rechazar de raíz un
cambio de terminal una vez que existe `contexto_dag()` (declarar que **no puede pasar** en el
protocolo real, y que si pasa aquí es porque la red dev permite algo que no debería — en cuyo caso
el hallazgo apunta a una regla de consenso ausente, no a un bug de reconciliación). Las evidencias
completas (los tres registros de ambos intentos) están en
`run-v5-intento1-diagnostico/` y `run-v5-intento2-diagnostico-bug-servicio-pot/`.
