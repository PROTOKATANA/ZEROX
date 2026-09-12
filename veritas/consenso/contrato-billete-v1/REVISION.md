# Revisión independiente de CBE-v0.1

Fecha: 2026-09-11. Especialidad: sistemas, estado contextual, disponibilidad y publicación.
Estado: **modelo M0 revisado por lectura; hallazgos de equivalencia corregidos; producción no aprobada**.

## Alcance y método

Lectura de [CONTRATO.md](CONTRATO.md), del modelo Rust de tests
[contrato_billete_modelo.rs](../../../crates/zx-consensus/tests/contrato_billete_modelo.rs),
del SPEC aplicable y de [LINEO](../../LINEO.md). No se ejecutaron compilaciones, tests,
simulaciones ni benchmarks en esta revisión. No se creó código C++/CUDA: no hay una carga GPU
identificada que lo justifique. El revisor sólo modifica este documento.

M0 se revisa como transición abstracta con identidad, orden, colores y resultados de validación
suministrados por un oráculo. No se exige implementar criptografía o consenso completo para
probar esa transición. Tampoco se atribuyen al modelo las propiedades que toma como entradas.
Se amplió la lectura al Rust de 888 líneas y a `src/modelo.jl`, `src/referencia.jl`,
`src/rapido.jl` y `src/validacion.jl` cuando aparecieron; se releyeron tras sus correcciones.
El conjunto final de fixtures contiene 35 escenarios y 49 EXPECT según su preparación por el
principal. Este revisor inspeccionó las regresiones, pero no ejecutó sus expectativas.

## Dictamen del contrato

No se identifica una contradicción bloqueante para estudiar M0 en la versión leída. Esto no
aprueba producción ni demuestra seguridad global, mejora de rendimiento o finalidad de pagos.
Las dependencias siguientes están expresamente abiertas y deben seguir visibles en los informes.

| ID | Severidad y estado | Hallazgo y alcance |
|---|---|---|
| REV-01 | Alta para producción; declarada, no bloquea M0 | CBE-01/02 no certifican TicketId ni el compromiso de padres/cuerpo/sello. Una oportunidad económica podría admitir varias representaciones. Los enteros sintéticos no resuelven ese vínculo. |
| REV-02 | Alta para producción; declarada, no bloquea M0 | CBE-03 recibe un orden canónico y un lote ya determinados. Comparar P0/P1 con ranks fijos no prueba resistencia del orden al grinding ni que el productor no pueda cambiar el lote mediante padres alternativos. |
| REV-03 | Alta para viveza; coste declarado | DA0 exige también cuerpos perdedores, rojo_U3 y tardíos. Una copia ausente puede mantener Pending y una inválida inutilizar el candidato. No se demuestra disponibilidad adversarial ni solución del spam. |
| REV-04 | Alta para integración; frontera declarada | CBE-04 separa falta de datos, invalidez y conflicto de ejecución. Falta integrar el verificador que determine cada caso, especialmente autorización cuando se necesita información histórica. Las etiquetas V/P/I de fixtures no son ese verificador. |
| REV-05 | Alta para producción; declarada, no bloquea M0 | CBE-11 limita M0 al conteo acumulado. La igualdad entre adjudicación, subsidio y observación no prueba estabilidad del retarget, ausencia de sesgo por retención o tasa efectiva honesta. No igualar W_adm a una ventana DAA upstream. |
| REV-06 | Alta para persistencia; declarada, no bloquea M0 | Copiar y publicar un State comprueba atomicidad lógica del modelo; no prueba durabilidad, aislamiento de lectores, WAL ni recuperación tras fallos de disco. CBE-12/14 exigen esas propiedades para la implementación real. |
| REV-07 | Alta para poda; declarada | CBE-15 no permite borrar consumos por salir de ventana. DA0 mantiene obligaciones sobre cuerpos inertes. Poda de cuerpos, compactación exacta y olvido semántico requieren argumentos diferentes. |
| REV-08 | Media; aclaración resuelta | Rust Event incorpora slot de admisión, subsidio y comisiones por evento; CBE §7 aclara que EXPECT es una proyección y no serializa todo journal/undo/contextos activos. Esa proyección no demuestra por sí sola igualdad del estado interno completo. |
| REV-09 | Media para equivalencia; corregida por lectura | Rust `numeric_order` ordena por longitud y después texto los IDs decimales canónicos, y snapshot lo aplica a ledger/clave/bloques. Julia usa UInt64 y orden numérico. Se añadió fixture con 2/10; el revisor no lo ejecutó. |
| REV-10 | Alta para equivalencia M0; corregida por lectura | Julia omitía contextos activos y admitía 1→2→1. Ahora State conserva `active`, copy/restore lo incluyen y ambos kernels rechazan cualquier contexto activo antes de ejecutar. El fixture `reutilizar_contexto_ancestral` conserva la regresión, incluso con lotes vacíos. EXPECT omite ese conjunto, pero no su efecto sobre transiciones posteriores. |
| REV-11 | Alta para equivalencia M0; corregida por lectura | Ambos kernels Julia omitían comprobar txid/contenido intralote. Ahora el kernel usa un mapa de binding y el oráculo una comparación lineal independiente; ambos lo verifican antes de Pending. El fixture `txid_con_contenido_distinto` conserva la regresión. |
| REV-12 | Media para cobertura de undo; corregida y ampliada por lectura | Julia incorpora Undo(before,after), `undo!` compara estado y contextos activos antes de restaurar, y `reorganize!` opera sobre un estado privado. Se añadieron tests de undo incorrecto, alteración y sustitución Pending/Invalid; la ampliación final también aplica un primer lote y deja el segundo Pending/Invalid, exigiendo conservar el estado anterior completo mediante `equivalent`. |

Los hallazgos se comunicaron al principal y se conservan aquí con su corrección, sin borrar la
historia de revisión. No se modificó el contrato ni el código de otros autores. «Corregida por
lectura» no significa que el revisor haya ejecutado la regresión ni probado todo el dominio.

## Decisiones del candidato que sí quedan inequívocas

- El conjunto y orden del lote se fijan antes de consultar disponibilidad. Pending no cambia
  el representante ni publica consumo, conteo, subsidio, comisiones, efectos o contexto parciales.
- La invalidez establecida no habilita saltar una copia y elegir otra localmente. Una historia
  alternativa debe justificarse por sus propias reglas; no por orden de descarga.
- P1 selecciona sobre el lote completo, respeta el ledger heredado y ejecuta al ganador en su
  posición original. No adelanta la azul a la posición de una roja desplazada.
- Una adjudicación vacía, con todos los gastos en conflicto o con subsidio cero consume el
  billete. Un conflicto de transacción no invalida por sí mismo el bloque ni libera ese consumo.
- L0 excluye de pago, conteo y ejecución a la copia fuera de ventana, sin convertir esa
  exclusión en invalidez de cabecera. Los slots futuros son entrada inválida de M0.
- Los consumos son contextuales, no global-first-seen. Reorganizar prepara deshacer/aplicar
  privadamente; cualquier fallo o Pending conserva el estado público anterior completo.

## Criterio Cortex y pérdidas que no deben ocultarse

La sección 8 identifica correctamente como fallo retirar el hecho histórico de un pago después
de aceptarlo. No confundirlo con gastar posteriormente una salida legítima, perder un bloque
portador o cambiar blue_work. M0 no crea salidas ni reconoce pagos: no mide ese evento.

La comparación posterior debe incluir pagos nunca aceptados, tiempos censurados, falta de
progreso, reinclusión y exclusión honesta, además de la latencia de los éxitos. P0/P1 pueden
reducir ejecución repetida y a la vez descartar el payload que contenía el pago de interés.
DA0 puede reducir trabajo repetido después de reconocer una copia sin eliminar el tráfico,
la validación preliminar ni la presión de candidatos antes de reconocerla.

Mantener expresamente: mismo adversario y presupuesto de nodo; riesgo y política de aceptación
definidos; frescura/continuidad del observador; replay fijo separado de simulación endógena.
No hay plazo nuevo de aceptación ni reducción de riesgo demostrados en esta revisión.

## Cotejo estático de las transiciones

En las implementaciones leídas coinciden selección sobre lote completo, prioridad azul sólo
intralote y ejecución por rank original del ganador. También coinciden preflight de slots
futuros, coherencia de slot por billete local/heredado, Invalid estructural antes de Pending y
Pending antes de un overflow contable todavía no ejecutado. Ambos preparan un estado privado
antes de publicar; esta observación sigue limitada a atomicidad lógica en memoria.

Las discrepancias iniciales REV-10/11 no se descubrían comparando sólo ambos kernels Julia:
compartían las omisiones. La referencia documental y la implementación Rust independiente son necesarias para
ese cotejo. Las precondiciones de identidad/compromiso inmutable no exigen simular criptografía,
pero tampoco permiten omitir un rechazo estructural expresamente incluido en M0.

## Cierre del cotejo estático

La relectura final no identifica otra divergencia semántica bloqueante en el dominio y las
precondiciones declaradas de M0. Quedan revisados orden/posición de P1, coherencia de slots,
contextos activos, prioridad de errores, Pending con overflow todavía no ejecutado y publicación
privada del cambio de rama. El journal Rust contiene más información que Award Julia: la
comparación compartida continúa limitada a la proyección de EXPECT, como declara el contrato.

La última relectura de `src/validacion.jl` confirma la prueba de cambio de rama de dos lotes:
el primero aplicable y el segundo Pending o Invalid. También se usa `equivalent` entre kernel y
oráculo; incluye contextos activos además de la proyección de snapshot. Esos casos dejan de ser
pendientes de cobertura en este informe; no se convierten en una prueba universal del modelo.

El principal comunicó la ejecución correcta de 9 024 comprobaciones de propiedades y 163
aserciones de fixtures, con 49 EXPECT. Son resultados **ejecutados por el principal**, no por
este revisor; comandos, artefactos y benchmarks deben constar en el informe de ejecución.
La revisión independiente aquí realizada sigue siendo lectura de código y contrato, sin pruebas
de disco, consenso integrado ni pagos reales.
