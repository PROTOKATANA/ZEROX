# DCM-v0.1 — contrato causal multivista de disponibilidad

Fecha: 2026-09-11. Revisión del instrumento: **2**. Estado: **instrumento estructural; no regla adoptada**. Categoría dominante:
consenso; secundarias: red y estado. No introduce staking, comité, reloj de recepción consensual,
parámetros temporales ni un certificado de disponibilidad.

## Objetos y fuentes

`HistoryId`, `WindowId`, `BlockId`, `TicketId` y `ObserverId` son identificadores opacos.
HistoryId, BlockId y TicketId declarados deben ser mayores que cero; HistoryId cero identifica
exclusivamente el génesis interno. WindowId cero sí está permitido. Son dominios del instrumento,
no una decisión de codificación de consenso. Jamás se ordenan historias o ventanas por su valor
numérico. `BlockSpec(B)` fija TicketId, WindowId original, rank canónico, color B/R/U y padres.
Copias del mismo TicketId deben declarar la misma ventana original. `HistorySpec(H)`
fija exactamente `(parent_history, WindowId, included_blocks)`. Esa inclusión es la entrada
objetiva común: recibir o no bytes no añade, elimina ni reordena candidatos.

La política P0/P1 se fija al construir cada vista y se conserva incluso al deshacer hasta génesis.
Las comparaciones de observadores exigen el mismo catálogo inmutable y la misma política durante
toda la ejecución. APPLY/REPLAY con otra política devuelven `PolicyMismatch` antes de modificar
estado público, undo, Pending o evidencia. Es un rechazo local de invocación; no prueba que la
historia sea inválida. P0 y P1 se estudian con vistas separadas y no se mezclan sus estados.

Rank y color son etiquetas globales suministradas, no recalculadas por HistoryId. La compatibilidad
del rank con el orden causal también es una precondición externa: el verificador estructural no
comprueba que un padre preceda a su hijo por rank. La prueba de ramas de este instrumento no
acredita la coloración ni el orden contextual de GHOSTDAG.

El instrumento no deriva GHOSTDAG, PoAS/PoT, compromisos, firmas, UTXO ni Orchard. Esas entradas
proceden del oráculo estructural del fixture. `COMPLETE(BlockId)` significa bytes completos que
corresponden al compromiso y es monotónico. Separadamente, `ContextValid(HistoryId,BlockId)` o
`ContextInvalid(H,B)` modelan autorización/UTXO/nullifiers en ese pasado exacto. No implementa esos
verificadores reales ni permite reutilizar evidencia contextual entre H y H'.

## Selección y disponibilidad

Para cada TicketId, B/R son elegibles y U es ineligible. P0 elige el mínimo `(rank,BlockId)`; P1
elige el mínimo `(is_blue ? 0 : 1,rank,BlockId)`. Se selecciona sobre **todos** los bloques de
`HistorySpec`, nunca sobre el subconjunto disponible en un observador y nunca por llegada. Un
TicketId consumido por un ancestro no vuelve a ser candidato; sus nuevas copias son Inert. Un
bloque con ventana original ya presente en el pasado de la rama es tardío contextual e Inert. Si
su origen no es la ventana actual ni una ventana del pasado, HistorySpec es Invalid. Esta prueba es
de pertenencia, no una comparación numérica entre WindowId.

Para verificar la inclusión/selección, el observador debe poseer todas las cabeceras incluidas.
Después requiere `COMPLETE(B)+ContextValid(H,B)` para cada ganador y para el cierre transitivo de
sus padres. Si falta algo,
el resultado es `PendingHistory(H)` y el estado público no cambia. No hay fallback a otra copia.
`REJECT` describe una entrega concreta rechazada: no invalida la cabecera y no degrada un `COMPLETE`
previo. Un bloque no ganador o U fuera del cono requerido es `Inert(H,W,B)` aunque falte su cuerpo.
`BodyInvalid` exige el cuerpo exacto comprometido y un fallo objetivo de integridad/autorización
intrínseca; si afecta al cono requerido, la historia es Invalid atómicamente. Sin esa
evidencia permanece Pending. Como la cabecera ZEROX actual no compromete toda autorización,
`BodyInvalid` es aquí un oráculo estructural, no una capacidad integrada del nodo. Timeout, cuota,
ausencia, auth/contexto incompletos o bytes corruptos alternativos nunca crean `BodyInvalid`.
Catalog fija globalmente qué BlockId tienen BodyInvalid y el mapa explícito de verdad contextual
`(H,B) => VALID|INVALID`. Una pareja no declarada no se considera válida: su entrega se rechaza
sin mutación y, si es requerida, la historia permanece Pending mientras falte evidencia.
Ninguna vista puede registrar el veredicto contrario a una entrada declarada. Una autorización
no comprometida sigue siendo REJECT/Pending, no ContextInvalid irreversible.
Una entrega INVALID elimina el marcador informativo REJECT anterior; un REJECT posterior a
COMPLETE o INVALID no degrada ni modifica esa evidencia.

Sólo una transición `Applied(H)` publica, atómicamente:

- un `EventId=(HistoryId,BlockId)` por ganador;
- exactamente esos mismos IDs en `counted[WindowId]` y `payable[WindowId]`;
- los `Inert` contextuales y el nuevo HistoryId.

PendingHistory no crea snapshot ni observación y nunca se transforma en `N=0` para retarget. DCM
no implementa el controlador ni decide si una cabecera/cuerpo no disponible debe entrar en su
ventana: el efecto de withholding sobre N queda Pending.

Por construcción, cuerpo no COMPLETE o sin ContextValid implica no ejecutar, no pagar y no contar. `Inert` es contextual:
el mismo BlockId puede tener otro papel en otra HistoryId. Una llegada posterior puede resolver
Pending y permitir replay, pero nunca modifica un snapshot ya aplicado.

`HistorySpec` es un oráculo de inclusión, no una prueba de que un bloque header-only tenga peso,
fork-choice o validez estructural acreditados. El artefacto no calcula blue_work/GHOSTDAG: la
propiedad «header sin COMPLETE/ContextValid no influye en la historia objetiva» queda **Pending** y no se deduce de
`Inert`.

## Historia, ramas y reversión

Una aplicación directa exige `HistorySpec.parent == current_history`. `replay(H)` prepara en privado:
deshace hasta el ancestro común y aplica en orden causal la rama objetivo. Si cualquier paso es
Pending o Invalid, conserva íntegro el estado público anterior: Pending registra el candidato
faltante e Invalid limpia el candidato pendiente. Si termina, publica el cambio completo.
`undo(H)` sólo acepta el HistoryId exacto de la
punta y restaura journal, snapshots, inert y bloques objetivos al estado anterior; IDs numéricamente
mayores/menores no tienen significado.
`Applied` es reversible y no equivale a finalidad ni autoriza por sí solo a Cortex a aceptar el
pago; replay puede retirar sus EventId y snapshots.

Una HistorySpec es Invalid por BlockId duplicados/desconocidos en su lista de incluidos,
padre de historia desconocido, ciclo,
bloque repetido en su pasado, WindowId ya sellado en ese pasado, ventana original desconocida o
padre de bloque ausente de su
pasado causal. Ausencia o entrega
rechazada son Pending, nunca Invalid. Los IDs duplicados de BlockSpec/HistorySpec se rechazan al
construir Catalog. La comprobación de duplicados en una historia no acredita la codificación
canónica de listas de padres DAG: este instrumento tolera padres repetidos como la misma dependencia.

Invalid limpia el candidato Pending local anterior, sin tocar el estado público. Los vectores de
BlockSpec/HistorySpec se copian al construir Catalog y el catálogo se trata como owned e inmutable
durante una ejecución; mutar sus campos internos o intercambiar el catálogo de una vista viola la
precondición del instrumento. `PolicyMismatch` es distinto de Invalid y tampoco limpia Pending.

## Invariantes y adversario

- selección idéntica para Ana y Bruno dada la misma HistorySpec/política;
- ningún evento sin COMPLETE y ContextValid(H,B) en ganador+cierre de padres;
- `Set(counted[W]) == Set(payable[W])` y ambos son proyecciones del journal, por EventId;
- Pending/Invalid no mutan estado público y no hacen fallback;
- replay tras reunión, bajo catálogo y política comunes fijos y tras recibir COMPLETE y evidencia
  contextual equivalentes, converge exactamente en las proyecciones del estado lógico y del undo;
  no se ha implementado ni probado una serialización binaria canónica. No se exige igualdad
  simultánea durante una partición; undo exacto y contextual;
- copias de TicketId producen como máximo un ganador por historia/ventana.

El adversario controla orden y ausencia de entregas, retención selectiva, partición/reunión,
copias y ramas, pero no falsifica las entradas objetivas, `COMPLETE` ni evidencia contextual. Eclipse total puede mantener
Pending indefinidamente: no se afirma viveza. Spam de headers, cuotas/bytes, poda durable y coste
de red quedan `Pending` porque este artefacto no modela recursos ni peers.

La publicación es atómica por HistorySpec: un ganador independiente sin COMPLETE/ContextValid mantiene pendientes
a los demás ganadores del mismo history. DCM-v0.1 sigue exigiendo todas las cabeceras incluidas;
sólo elimina el bloqueo por **cuerpo** ausente de un perdedor/U que queda fuera del cono requerido.
No demuestra cuarentena/publicación por componente; esa mejora queda Pending.
Tampoco prueba independencia de estado entre ganadores: sin cuerpos no conoce conflictos
UTXO/nullifier. Para estudiar publicación independiente falta especificar una frontera causal
objetiva. Los tombstones o compromisos de conjuntos de lectura/escritura son opciones por evaluar,
no soluciones demostradas ni requisitos universales establecidos aquí.

## Criterios y coste

Aceptación estructural: todos los fixtures y propiedades anteriores coinciden exactamente entre
oráculo y kernel; cualquier diferencia es fallo. No hay probabilidades ni tolerancias. La medición
controlada incluye clonado transaccional, journal, snapshots, inert y undo. La implementación
inicial guarda snapshots completos: en una cadena lineal su undo ocupa Θ(H²) estado acumulado y
replay profundo puede ser superlineal. El perfil observado es compatible con esa advertencia, pero
no constituye una cota. Es un kernel tipado de contraste, **no optimizado**;
delta-undo/persistencia estructural queda como mejora.
Referencia y kernel tienen rutas de estado distintas, pero comparten validación estructural,
selección objetiva y cierre de padres. Su igualdad detecta defectos de transición/representación,
no constituye una prueba independiente de esas reglas compartidas.

La revisión 2 conserva un oráculo de alcanzabilidad independiente para grafos de tres bloques y
dos historias; su dominio finito no se extrapola a una prueba de consenso completa. Rust usa un
recorrido iterativo para detectar ciclos, con memoria proporcional al grafo y sin recursión
proporcional a su profundidad. La regresión de profundidad sintética no prueba recursos acotados
del nodo ni la admisibilidad de ese lote bajo los límites del DAG destino.

Presupuesto de revisión inicial: 1 hilo CPU, 8 GiB RAM, 2 GiB nuevos y 30 minutos por suite. Si se
agota, estado Inconcluso. Los números pertenecen al presupuesto, no al protocolo.

## Fixture compartido

`fixtures/CASOS.txt` usa listas separadas por coma y `-` para vacío/génesis. Los enteros del
fixture contienen sólo dígitos ASCII decimales, sin signo ni prefijos, y deben caber en UInt64;
se toleran ceros iniciales. Cada CASE debe construir al menos una vista sobre un catálogo con
alguna historia declarada. Una historia puede tener la lista de bloques vacía.
En EXPECT, Pending ausente se escribe `-`, nunca `0`:

```text
CASE nombre P0|P1
BLOCK bid ticket origin_window rank B|R|U parents|-
HISTORY hid parent|- window blocks
BODY_TRUTH bid COMPLETE|INVALID
CONTEXT_TRUTH hid bid VALID|INVALID
VIEW observador
HEADER observador bid
BODY observador bid COMPLETE|REJECT|INVALID
CONTEXT observador hid bid VALID|INVALID
APPLY observador hid Applied|Pending|Invalid
REPLAY observador hid Applied|Pending|Invalid
UNDO observador hid Applied|Invalid
EXPECT observador current|- journal|- counted|- payable|- inert|- consumed|- pending|-
EQUAL observador observador
END
```

EventId se serializa `hid:bid`; snapshots como `window=hid:bid,hid:bid/window=...`; Inert como
`hid:window:bid`. El parser rechaza tokens/aridades desconocidos, CASE anidados/sin END,
definiciones posteriores a congelar el catálogo y vistas duplicadas. También rechaza una entrada
sin casos, comandos fuera de CASE y componentes sobrantes/vacíos de EventId e InertKey; las
expectativas no pueden ocultar multiplicidad mediante IDs o ventanas repetidos.
PolicyMismatch se prueba mediante la API: el fixture fija una política por CASE y sus transiciones
siguen declarando sólo Applied, Pending o Invalid.
