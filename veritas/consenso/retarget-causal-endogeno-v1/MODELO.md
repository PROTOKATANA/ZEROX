# Modelo de simulación RCE-v0.1

## Objetivo

Medir estabilidad y efectos de admisión bajo realimentación propia, no elegir parámetros ni
reproducir GHOSTDAG/PoAS completos. Los escenarios pequeños son controles estructurales.

En cada slot la traza ofrece un número fijo de intentos honestos y adversarios. Un intento produce
si su palabra de 64 bits enmascarada cae por debajo de `R_active` en un dominio `R_scale` potencia
de dos. Un contracontador inyectivo codifica `(slot,intento)` y separa actor/tipo por dominios. Los bloques producidos
se programan mediante `header_visible_slot` y `body_available_slot`; la demora suma retardo base,
retención adversaria y congestión sintética. `adversary_body_hold` mantiene el cuerpo ausente
con la cabecera ya visible. Esta agenda no representa una cola de red/servicio.
Las copias conservan TicketId y slot. Las cabeceras visibles forman el conjunto pendiente; DA0
marca Pending cuando cualquier cuerpo falta, sin generar evento ni actualización.

P0/P1 y L0/LG se ejecutan sobre los mismos candidatos. Una transacción de pago honesta excluida
entra en una cola de reinclusión y se reasigna al siguiente billete honesto adjudicado. Un pago
queda “nunca aceptado” si la simulación termina antes de esa adjudicación. Esto mide el modelo de
cola, no reconocimiento real de wallet.

Cada cierre crea una propuesta con el rango que estaba activo y el snapshot sellado. La activación
diferida ocurre sólo en la frontera nominal posterior definida en CONTRATO. Las ventanas vacías
mantienen rango (Z0): la enmienda Z0 (2026-09-12) lo implementa como no-op **sin agenda** — la
activación devuelta es 0, igual que en Pending; la ventana sí se sella y registra. Pending bloquea cierres posteriores. Una resolución que alcanza su frontera
nominal produce `MissedUpdate` y mantiene rango. No se crean épocas vacías desde reloj local.

## Comparabilidad

- misma semilla y tabla exógena para todas las variantes;
- IDs de oportunidad reservados con independencia de si el rango activo la admite;
- orden de reducción fijo y contadores enteros;
- cada variante mantiene rango, journal, cola y calendario propios;
- se publican resultados por escenario/variante, sin mezclar medias de adversarios distintos;
- oráculo transparente deliberadamente lento con escaneos lineales y kernel incremental con
  buckets por entrega/ventana, conjunto de tickets y cola con cursor; no se llama SoA.

## Criterio de terminación

Referencia y kernel deben coincidir exactamente en rangos por slot, EventId, contadores, colas,
Pending, exclusiones y reinclusiones. Los límites de decisión no elegidos se informan como
`Pending`; timeout o presupuesto agotado produce `Inconcluso`.
