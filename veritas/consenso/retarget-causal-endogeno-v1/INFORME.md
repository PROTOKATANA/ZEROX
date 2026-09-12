# Informe RCE-v0.1

Estado: **instrumento estructural; no decisión de protocolo**. Fecha: 2026-09-11.

La suite controlada con comprobación de límites pasa: fixture compartido de 9 pasos, 12.800
comparaciones exactas más 3 rechazos de configuración aritmética, bordes de activación/Pending
y disponibilidad intr-slot de cuerpo,
igualdad de la proyección comprobada entre una implementación de referencia separada y el kernel
en cuatro variantes P0/P1 × L0/LG, actores con cero intentos, identidad estable entre rangos,
retención adversaria de cuerpo DA0 y deduplicación/reinclusión. Semilla principal: `20260911`.

En la semilla `20260911`, L0 produjo 5 eventos/600 slots y terminó en rango 900; LG produjo
104 eventos/600 slots y terminó en rango 548. P0 y P1 dieron los mismos agregados en esta traza,
lo que no demuestra que sean equivalentes. Todos los snapshots sellados conservaron igualdad
exacta de EventId contado/pagable. LG registró 20 actualizaciones perdidas; L0, cero.

DA0 dominó estos controles: L0 pasó 591/600 slots en Pending y cerró con una racha censurada de
571 slots sin EventId; LG pasó 575/600 y alcanzó 285 slots continuos sin EventId. Por tanto el
retarget causal evita retroactividad, pero no repara la viveza ante retención de cuerpos.

El benchmark sintético mediano del kernel fue 118.198/249.651/535.265 ns para
1.000/2.000/4.000 slots: aproximadamente lineal sólo en este intervalo. A 2.000 slots, elevar la
retención de cuerpo de 0 a 16 slots aumentó el tiempo de 333.179 a 541.400 ns y el máximo backlog
de 8 a 1.305 cabeceras, aunque cambió también el trabajo útil; no es una razón causal aislada ni
una cota. La referencia separada tardó 401.297 ns a 1.000 slots. JET 0.12.1 informó cero
diagnósticos, `code_warntype` no mostró `Any` y la corrida perfilada asignó 345.344 bytes.

Conclusión admisible por ahora: el controlador racional lineal nuevo y su activación causal
están definidos y el kernel coincide con la implementación de referencia separada en los casos
ejecutados. Ambas rutas comparten `causal_step`, tipos, IDs y auxiliares checked; por ello esta
comparación diferencial no es una prueba independiente del contrato causal. Esto
no prueba estabilidad global, viveza, seguridad PoAS ni superioridad de parámetros. Z0 mantiene
el rango durante sequías (desde la enmienda Z0 del 2026-09-12, como no-op **sin agenda**) y no
constituye recuperación de viveza.

El coste rápido es amortizado O(oportunidades + entregas + eventos log lote + ventanas), pero el
reescaneo de un backlog DA0 puede degradarlo a O(H·Bmax); la memoria es O(traza + eventos +
entregas futuras + backlog + pagos + H). Julia CPU basta para este instrumento. C++ no está
justificado por el perfil actual y CUDA tampoco por el control irregular y los tamaños pequeños.

Permanecen `MetricPending`: reversión tras aceptación (sin ramas), desacuerdo entre observadores
(una vista) y cola real de red/servicio (sólo hay entregas programadas). `W`, `G`, `W_adm`, rangos,
ganancia, clamps y retardos siguen siendo escenarios no adoptados.
