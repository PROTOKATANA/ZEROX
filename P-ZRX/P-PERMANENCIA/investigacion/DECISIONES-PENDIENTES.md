# DECISIONES-PENDIENTES — P-PERMANENCIA

Bifurcaciones reales para Katana. **Ninguna la decide este informe.** Cada una lleva: la pregunta,
las opciones, qué cierra y qué paga cada una, y qué evidencia falta. Los números citados salen de
`INFORME.md` y de `veritas/almacenamiento/permanencia-v1/resultados/`.

---

## D1 · ¿Se acepta el escenario GPU `17×` como riesgo de primer orden?

- **Qué está en juego.** Es **la** bifurcación. Sin GPU, E3 fuerza ~82,9 % del lote a `w=7.175` y
  regenerar cuesta ~100× más que almacenar. Con `17×`, una GPU fabrica **2,9 TiB por ventana**,
  `0,343 GPU/TiB`, y **cualquier lote ≤ 2,9 TiB es íntegramente falseable**.
- **Opciones.** (a) Medir una GPU real con el kernel de Autonomys antes de apoyarse en E3; (b)
  aceptar E3 como cota que puede erosionarse y reforzarla con E1/E4; (c) declarar E3 insuficiente y
  no publicar garantía de permanencia.
- **Qué falta.** Una medición de `r_gpu` (no la cifra de documentación). La máquina de referencia
  **no tiene `/dev/nvidia*` ni root** (`P-ZRX/P-INTENTO/…/INFORME.md` §9): hay que decidir dónde se
  mide.
- **Qué cambiaría la recomendación.** Un `r_gpu` medido < ~3× el de CPU haría E3 sólido; > ~17× lo
  haría inútil para lotes pequeños.

## D2 · ¿Todas las parciales quedan ligadas, o se muestrean?

- **Qué está en juego.** El muestreo «comprometer `λ` y abrir `k`» **colapsa** la obligación si las
  posiciones se conocen por adelantado (`w` slots): el tramposo regenera solo `k` piezas,
  `0,004 CPU` con `k=10`. Ligarlas todas conserva la obligación pero paga `λ·b` bytes por lote y
  periodo.
- **Opciones.** (a) Todas ligadas (bytes: 2.097 B/periodo/TiB con `λ=10,5`, `b=200 B`); (b)
  muestreo con posiciones derivadas de **aleatoriedad no anticipable** (no existe hoy: el reto sale
  del PoT, público `w` slots antes); (c) agregado con prueba sucinta de que el conjunto es real
  — que es una prueba de cómputo, es decir, volver a E1.
- **Qué falta.** Fijar `P`, `b` y el tamaño de bloque (parámetros de consenso) y medir si los bytes
  caben.
- **Qué cambiaría.** Si el agregado con prueba sucinta fuera viable, E3 se abarataría en cadena sin
  perder obligación; hoy **no existe**.

## D3 · ¿Cuánto vale `w` y se adopta la segunda línea VDF?

- **Qué está en juego.** El coste de E3 escala como `1/w`. Con `w=7.175` (sin VDF) son 5,84 CPU/TiB;
  con `w=4.830,6` (con VDF a ρ=2,5) son 8,67; con `w=10⁵` serían 0,42. El cruce «fabricar más
  barato que el disco» está en `w≈8,4·10⁵` slots.
- **Opciones.** (a) Adoptar R-FIN-14(h) y fijar `Lrev` para reducir `w`; (b) dejar `w` en ~`L` y
  aceptar 5,84 CPU/TiB; (c) no apoyarse en E3 para nada y cerrar (i) con E1/E4.
- **Qué falta.** El valor final de `w` tras R-FIN-14(h), y la regla de adopción entre flujos
  (`P-ZRX/P-REVELACION/…/INFORME.md` §1.3).
- **Qué cambiaría.** `w` mayor de ~8·10⁵ slots anula la garantía de E3.

## D4 · ¿Se mantiene C1/E1 como requisito bloqueante?

- **Qué está en juego.** `P-ZRX/P-SEMBRADOR/…/INFORME.md` concluyó que el agujero C1 **bloquea todo
  el paquete**, y este informe confirma que **E1 no existe** para el formato fijado. E3 no lo
  sustituye para «existía antes del reto».
- **Opciones.** (a) Mantener C1 como requisito y no avanzar el paquete hasta tener E1/E4; (b)
  aceptar E3 como mitigación económica explícita y **documentar que el sembrador no está cerrado**;
  (c) rediseñar la parcela hacia un sellado (E4), con el coste de migración que eso implica.
- **Qué falta.** Decisión de producto: ¿basta una garantía económica, o se exige criptográfica?
- **Qué cambiaría.** Ninguna medición: es una decisión de umbral de seguridad.

## D5 · ¿Cómo se trata al honesto con disponibilidad `a<1`?

- **Qué está en juego.** Con `K` calibrado a `a=1`, un honesto con `a=0,99` tiene falso fallo
  `5,17·10⁻³` (5,2× `β`) en el caso `s=0,9`; con `a=0,5` el test no es utilizable.
- **Opciones.** (a) Recalibrar `K` a la `a` declarada por lote; (b) tolerar `m` fallos por ventana;
  (c) ventanas de gracia; (d) no usar E3.
- **Qué falta.** Medir la disponibilidad real de un granjero doméstico (apagones, red) — no medida
  en ningún encargo.
- **Qué cambiaría.** Una `a` real muy por debajo de 1 haría E3 inviable sin rediseñar el test.

## D6 · Diseño del `PlotBatchId`

- **Qué está en juego.** Debe ligar codificación, clave y lote, o los mismos bytes se re-registran
  tras un castigo. Hoy `SectorId` liga clave, índice e historia (`sectors.rs:54-68`) y
  `derive_piece_index` liga offset e historia (`:70-114`), pero **no hay alta previa ni fecha**.
- **Opciones.** (a) Transacción de activación con raíz, versión y cardinalidad (`CANDIDATA.md` §1);
  (b) acumulador/conjunto activo; (c) dejar `SectorId` como está y aceptar re-registro.
- **Qué falta.** Formato, bytes, estado, poda y tasa de altas (prototipo).

## D7 · Retención: importe y duración

- **Qué está en juego.** El **tiempo** mínimo de retención sale del modelo: `T` de detección + `F/P`
  periodos (72 periodos de finalidad con `P=100`, `F=7.200`). El **importe** `ρ_ret` es monetario y
  **este informe no lo fija**.
- **Opciones.** Fijar `ρ_ret` y `T_v` con el modelo del juego `α+β` de `CANDIDATA.md` §A.2/C1, que
  es otro encargo.
- **Qué falta.** El modelo `α+β` y precios (prohibidos aquí).

## D8 · ¿Se acepta que un granjero pequeño sea invisible en E5?

- **Qué está en juego.** Con solo farmear, un granjero con `σ=10⁻⁵` tarda **8,0 días** en notarse
  por azar; con `σ=10⁻⁴`, 19,2 h.
- **Opciones.** (a) Aceptar la línea base; (b) exigir E3 para todos; (c) auditorías directas (E2),
  que **caen** ante la regeneración.
- **Qué falta.** Decidir si la red protege al granjero pequeño o solo al agregado.

## D9 · Categoría y portabilidad del instrumento

- **Qué está en juego.** El instrumento quedó en `almacenamiento` (dominante), con `seguridad` y
  `economía` como secundarias. No comparte entorno con otros.
- **Opciones.** Reutilizarlo como base del prototipo de auditorías, o congelarlo como evidencia.
- **Qué falta.** Ninguna: es una decisión de proceso.
