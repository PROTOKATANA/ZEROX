# Modelo y argumento de la comprobación ARM-v0.1

La definición normativa de este instrumento condicional está en [CONTRATO.md](CONTRATO.md).
No constituye una definición normativa del protocolo ZEROX.

## Dos relojes que no se pueden intercambiar

Sea E el snapshot completo de EventId de una misma historia H, R el rango al sellar y A la
activación calculada por RCE. El adversario retrasa únicamente la entrega de datos al observador;
no altera H, E ni el contexto causal del sello. Escoja una instancia con `R_next(R,|E|)!=R`.

Si se usa el instante local de cierre, con `c<=t_A<A<=t_B`, la misma función RCE devuelve:

- Ana: Scheduled, propuesta R_next para A.
- Bruno: MissedUpdate, sin esa propuesta, rango R.

Ambos pueden tener `counted==payable==E`. La igualdad de identificadores no determina el
instante de cierre: no basta para obtener la misma agenda ni el mismo rango. Es un
contraejemplo de composición de APIs, no un ataque autenticado al nodo completo.

En el control causal, la llegada sólo determina cuándo el observador puede completar su
reproducción. El valor suministrado al controlador es siempre `causal_seal_slot(H)`.
Una llegada tardía no parchea un snapshot anterior de H: permite reconstruir ese mismo H.
Adoptar otra historia sí sustituye los efectos de la rama abandonada por los de la nueva.

## Argumento condicional por prefijos

Bajo catálogo, configuración, política y descriptores causales fijos:

1. El prefijo vacío tiene exactamente el mismo estado inicial.
2. La selección DCM de la siguiente historia completa entrega el mismo snapshot por WindowId,
   con los mismos consumos heredados. La extracción verifica igualdad de los EventId, no sólo N.
3. Los dos observadores activan la misma subsecuencia de propuestas ancestrales antes del
   mismo sello causal. Por hipótesis inductiva coinciden fuentes, slots y rangos.
4. Con el mismo rango, N, corte, sello y configuración, el controlador entero produce el mismo
   resultado. Sólo Scheduled se conserva en la agenda; HeldZero (enmienda Z0, 2026-09-12) y
   MissedUpdate no crean propuesta.
5. La publicación conjunta de DCM y controlador sólo sucede al completar el prefijo. Pending
   e Invalid dejan el estado público previo intacto. Reconstruir otra rama aplica el mismo
   argumento a su prefijo, retirando antes lógicamente los efectos abandonados.

Este argumento supone que la historia, su inclusión y sus descriptores son objetivos. La
auditoría comprueba las implementaciones de la transición condicionada: no demuestra cómo
obtener esas entradas mediante GHOSTDAG ni cómo validar PoAS con el rango ancestral correcto.
La consulta `range_at` usa sólo las propuestas de la historia suministrada y no muta el estado
aplicado. Consultar un slot futuro es condicional a esas propuestas: no predice otras historias.

## Ventana vacía con propuestas en vuelo

Vector adicional elegido, mismas unidades y configuración que el vector principal salvo
desfase D=2 ventanas. W=10 slots, G=0, rango inicial R=100, objetivo Q=10 y ganancia 1/1.

| Contexto causal | Observación | Propuesta derivada |
|---|---|---|
| Sello de cohorte 0 en slot 10 | N=5, rango activo 100 | Scheduled: 200 en slot 30 |
| Sello de cohorte 1 en slot 20 | N=0, rango activo todavía 100 | HeldZero: ninguna propuesta (no-op) |

La primera activación lleva el rango a 200; la segunda ya no existe: el rango consultado
en 39 es 200 y en 40 es 200 (antes de la enmienda Z0 era 100, por una propuesta `100@40` que
revertía el rango). Son resultados exactos derivados del RCE Julia revisión 2, no una
recomendación de política económica. HeldZero no agenda: es la omisión, no una propuesta
diferida del rango del sello.

El helper `FeedbackState.close` del test Rust histórico tampoco agendaba esa propuesta y
conservaba 200. La enmienda Z0 (2026-09-12) alineó Julia con ese comportamiento: el adaptador
de prueba que completaba la agenda HeldZero se retiró, y el vector ahora documenta la
convergencia exacta de ambas implementaciones en `range_at(40)=200`.

## Representación, coste y límites

Los identificadores son dispersos y pequeños; se usan mapas concretos y vectores de eventos,
sellos y propuestas. Las ventanas opacas de DCM no se ordenan numéricamente: la posición causal
de la cohorte se valida contra CloseFrame. Con configuración constante, las activaciones
nominales consecutivas difieren exactamente en W; por eso el kernel puede usar un cursor.

La referencia reescanea propuestas; el kernel avanza el cursor y usa UInt128 comprobado.
Ambos reconstruyen el controlador completo y comparten validación de snapshots; DCM añade sus
copias de snapshots y comprobaciones repetidas de estructura. El coste conjunto puede ser
superlineal. El perfil incluye replay entre ramas; no es un benchmark de DA0/DA1 ni del nodo.

Rust reutiliza el controlador y journal de su test RCE mediante un módulo hijo; su adaptador
ARM no ejecuta DCM. Julia sí compone las APIs DCM y RCE. No se afirma equivalencia binaria de
ambos adaptadores, ni ejecución de dinero/UTXO/nullifiers, ni progreso bajo retención indefinida.
