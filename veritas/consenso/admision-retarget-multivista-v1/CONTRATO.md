# ARM-v0.1 — comprobación de composición multivista

Fecha: 2026-09-11. Revisión del instrumento: **2** (enmendado 2026-09-12; consume **RCE-v0.1
revisión 2**). Estado: **contrato de prueba condicional, no regla de consenso adoptada**.
Categoría principal: consenso; secundarias: disponibilidad y retarget. No cambia SPEC,
validadores de producción, parámetros de red, staking ni finalidad de Cortex.

## Pregunta y fuentes

¿Dos observadores que terminan reproduciendo la misma historia completa obtienen los mismos
EventId, consumos, snapshots, propuestas, activaciones y rango, aunque reciban los cuerpos en
momentos distintos? Se reutilizan, sin editar sus motores, DCM-v0.1 revisión 2 para
selección/disponibilidad/replay y RCE-v0.1 **revisión 2** para el controlador entero. VRC-v0.1 aporta la
distinción entre recepción, incorporación y sello contextual reversible.

La prueba NO deriva una historia de GHOSTDAG. HistorySpec, orden, color, validez contextual y
el contexto causal del cierre son entradas objetivas comunes del fixture. Tampoco valida
soluciones contra rangos, ejecuta transacciones/coinbase/Orchard ni mide red o finalidad.
Que el rango calculado sea determinista no demuestra que los bloques que lo declaran sean válidos.

## Dominio y transición ensayados

1. El catálogo DCM, la política P0/P1 y la configuración RCE se fijan para una ejecución.
   P0 es principal; P1 sólo se contrasta en ejecuciones separadas. No se comparan vistas con
   reglas distintas. Mutar el catálogo suministrado viola el dominio de la prueba.
2. Cada HistorySpec tiene un descriptor externo `CloseFrame(history_id, cohort_index,
   causal_seal_slot)`. `cohort_index` es un índice temporal explícito, no el valor numérico
   del WindowId opaco de DCM. Las cohortes de cada rama empiezan en cero y son consecutivas;
   los slots causales de sello no decrecen. Dos ramas pueden dar otro papel al mismo billete.
3. El corte se calcula con enteros comprobados: `c_j=(j+1)*W+G`, W positivo. El sello debe
   satisfacer `causal_seal_slot>=c_j`. La asociación de los EventId de DCM a esa cohorte
   se suministra como parte del fixture: no implementa admisión LG/L0 ni decide qué contexto
   real del DAG cierra la ventana. Una sola HistorySpec representa el snapshot de esa cohorte.
   La asociación WindowId opaco/cohort_index debe ser biyectiva dentro de cada rama. Los IDs
   NO se suministran en una lista independiente: se extraen exactamente de
   `counted[HistorySpec(H).window] == payable[HistorySpec(H).window]` tras replay a H;
   pertenecen a su journal causal y no pueden repetirse ni reasignarse a otra cohorte.
4. Se prepara en privado el replay DCM de la rama objetivo. Si falta una cabecera/cuerpo/contexto
   requerido, el resultado es Pending: no se publica DCM ni se cierra una ventana con N=0.
   Invalid tampoco publica. No se sustituye un representante por otra copia disponible.
5. Para reconstruir el controlador se recorre el prefijo causal completo desde génesis.
   Antes de cada sello se aplican las propuestas de ancestros cuya activación es menor o igual
   al slot causal del sello. El snapshot contiene exactamente los EventId `counted==payable`
   de esa cohorte, sin duplicados; N es su cardinalidad, no peso azul ni importe.
6. Se llama al controlador RCE **revisión 2** (enmienda Z0, 2026-09-12) con ese rango activo,
   N, corte y **slot causal del sello**. Sólo las salidas Scheduled se agendan: HeldZero es
   no-op — activación devuelta `0`, sin propuesta —, igual que en los simuladores RCE Julia
   revisión 2 y en el helper Rust `FeedbackState.close`. La enmienda de este contrato queda
   registrada aquí en tres partes:

   **Qué observó bien la redacción original (revisión 1).** Su premisa era correcta: al omitir
   la propuesta HeldZero, el rango vigente en el slot de activación puede no ser el rango del
   sello. Es exactamente lo que pasa en el vector medido: en el slot 40 el rango es **200**, no
   el 100 del sello de la ventana vacía.

   **Dónde se equivocaba.** Convertía esa observación en una razón para agendar, cuando es la
   razón para **no** agendar. Que el rango vigente haya cambiado significa que llegó evidencia
   real posterior; reimponer el rango del sello es descartar esa evidencia en favor de una foto
   vieja. «Preservar la procedencia de RCE» no puede significar reimponer un valor obsoleto: el
   CONTRATO de RCE pide *mantener*, y mantener es no intervenir.

   **Qué queda del planteamiento.** La discrepancia con el helper Rust, que la revisión 1
   «conserva y reproduce […] sin corregir ese motor», deja de existir porque el motor que se
   corrige es el de Julia, no el de Rust. La frase «el adaptador de prueba ARM Rust debe
   completar explícitamente HeldZero» queda derogada junto con el adaptador (retirado el
   2026-09-12 de `crates/zx-consensus/tests/soporte/admision_retarget_multivista_frontera.rs`).
   Vectores propios de ARM que cambian de valor: (a) el vector de ventana vacía W=10, G=0,
   D=2 con frames `(100,0,10)`, `(200,1,20)`, `(300,2,40)` pierde las propuestas
   `(200,1,40,100)` y `(300,2,50,100)`: `range_at(40)` pasa de 100 a **200**, y tras el tercer
   sello el rango activo es 200 y la agenda queda vacía; (b) el vector de catálogo vacío
   `CloseFrame(700,0,10)` pierde la propuesta `(700,0,20,100)` y registra `activation_slot=0`.
   Las propuestas (sólo Scheduled) activan estrictamente después del contexto que las genera.
   Pending y MissedUpdate conservan sus significados RCE; HeldZero queda redefinido por la
   enmienda Z0. Un sello objetivamente
   tardío puede producir MissedUpdate para todos los observadores: no se elimina ese caso.
   La agenda registra fuente (HistoryId/cohorte), slot de activación y rango; las colisiones
   no se resuelven por llegada. La recepción local no entra en esta transición. El rango activo
   publicado se evalúa en el slot causal del último sello, no en el reloj local al terminar replay.
   Para W, G y desfase D constantes, `c_(j+1)=c_j+W` y `A_(j+1)=A_j+W`; por tanto la agenda
   emitida en orden de cohortes tiene activaciones estrictamente crecientes. Esa propiedad
   justifica el cursor del kernel, incluso si un salto causal consume varias propuestas.
7. Sólo al completar toda la preparación se publican conjuntamente estado DCM y controlador.
   Reproducir otra rama reconstruye sus sellos/agenda/activaciones/rango, no une los de ambas.
   Volver al prefijo o génesis retira los efectos del sufijo. El controlador puede reconstruirse
   desde el prefijo en este instrumento: no se requiere ni afirma persistencia durable de deltas.
8. La referencia reconstruye en privado desde génesis y usa la aritmética BigInt RCE; el kernel
   reutiliza replay DCM y aritmética UInt128 comprobada. Se comparan proyecciones exactas,
   incluyendo la procedencia de propuestas. La selección DCM y partes de RCE son compartidas:
   el contraste no es una prueba independiente de esos motores. Los vectores manuales y el
   contraejemplo simbólico proporcionan controles externos para la frontera temporal.

## Control negativo y adversario

El control deliberadamente incorrecto conserva los mismos EventId, pero pasa el instante local
de recepción como seal_slot. Para `c<=t_A<A<=t_B` y `R_next!=R`, Ana agenda una actualización
y Bruno obtiene MissedUpdate. Se exige detectar esa divergencia. Es una refutación de esa
**composición ingenua**, no de la aritmética ni de las conclusiones declaradas del RCE monovista.

El adversario sólo altera orden/ausencia de entregas, retiene cuerpos y presenta ramas/copias
del fixture. No falsifica pruebas, contextos o historia objetiva. La admisibilidad comprobada
es estructural bajo DCM, no una traza autenticada del nodo PoST+DAG destino. Eclipse total
puede impedir progreso indefinidamente; la igualdad se exige al validar la misma historia
con evidencia completa común, no simultáneamente durante una partición.

## Vectores, números y aceptación

Vector manual compartido: W=10 slots, G=0 slots, cohorte j=0, corte/sello causal=10 slots,
activación=20 slots (derivada), recepción temprana=9 y tardía=21 slots; el cierre temprano
se procesa en 10, no en 9. El control local usa `max(corte, local_ready_slot)`; no inserta
en un cierre datos que llegan después de su fase de incorporación. R inicial=100 unidades
abstractas, Q=10 adjudicaciones, N=5 EventId, ganancia=1/1, clamp por paso=[1/2,2/1],
rango global=[1,1000], desfase=1 ventana, redondeo Floor. Resultado exacto derivado:
`100*10/5=200`; el control local tardío conserva 100. Todos los valores son **elegidos para
el test**, no mediciones de red ni parámetros adoptados. Fuente: familia RCE y este fixture.
Los demás vectores deben etiquetar de igual forma sus valores y expectativas en tests/informe.

Aceptación: detectar el control negativo y obtener igualdad exacta en replay causal, ramas,
copias, fronteras de activación, ventana realmente vacía y Pending sin publicación. Cualquier
divergencia inesperada, actualización propia/retroactiva, overflow silencioso o mutación parcial
es fallo. Los errores de dominio deben rechazarse antes de publicar; timeout es inconcluso.

Coste: catálogos pequeños dispersos y vectores de eventos/propuestas; reconstruir el controlador
por prefijo evita un segundo algoritmo de undo. DCM conserva el coste de snapshots completos
y comprobaciones repetidas de estructura; no se afirma linealidad del replay conjunto ni que
el kernel esté optimizado. Se perfila el workload de esta comprobación, no el nodo.

Presupuesto declarado antes de ejecutar: Julia CPU, 1 hilo de cómputo, BLAS 1, hasta 8 GiB RAM,
2 GiB de artefactos nuevos y 30 minutos por suite (topes de trabajo, no parámetros de protocolo).
C++/CUDA no se implementa para este control pequeño e irregular; no hay trabajo GPU justificado.

## Pendientes que este resultado no cierra

- Derivar/autenticar el contexto de cierre y la inclusión desde el DAG real.
- Validar cada bloque contra el rango de su pasado causal antes de adjudicar; impedir que una
  actualización derivada de él modifique su propia validación. Aquí no existe ese verificador.
- Unicidad del peso azul, orden resistente a variantes, PoAS/PoT y selección de historia.
- Ejecución económica/UTXO/nullifiers real, compromiso firmado y recuperación durable.
- Sesgo del retarget por retención, planificación/cuotas, progreso de candidatos independientes,
  particiones y espera de Cortex a riesgo comparable.
