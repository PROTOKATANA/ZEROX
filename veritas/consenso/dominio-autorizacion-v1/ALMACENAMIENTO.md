# Evidencia validada, reparación y contexto — contrato candidato

Fecha: 2026-09-11. Revisión de sistemas; propuesta para un prototipo Rust aislado.
**No activa consenso ni modifica el almacén de producción.** No hay cálculos, benchmarks,
tests nuevos ejecutados por esta revisión, Python ni GPU. Se leyeron las instrucciones locales
y [LINEO](../../LINEO.md) íntegramente. IDV y sus huellas se conservan intactos.

## 1. Evidencia primaria y frontera actual

| Fuente local | Hecho observado por lectura / evidencia previa | Consecuencia |
|---|---|---|
| [Cadena:444](../../../crates/zx-node/src/cadena.rs#L444) | Comprueba correspondencia y guarda bytes por blockhash | No es puerta de autorización completa |
| [Memoria:86](../../../crates/zx-storage/src/memoria.rs#L86), [disco:166](../../../crates/zx-storage/src/disco.rs#L166) | `insert` / `put_cf` reemplazan el cuerpo por esa clave | Una entrega posterior puede degradar la autorización almacenada |
| [Cadena:463](../../../crates/zx-node/src/cadena.rs#L463), [Cadena:484](../../../crates/zx-node/src/cadena.rs#L484) | Presencia consulta bytes; lectura devuelve `None` también ante corrupción/error | No modelan disponibilidad verificada ni diagnóstico completo |
| [Bloque:185](../../../crates/zx-consensus/src/bloque.rs#L185), [testigo:71](../../../crates/zx-consensus/src/testigo.rs#L71) | Validez estructural y autorización están separadas | Deben componerse sobre salidas y contexto correctos |
| [Disco:229](../../../crates/zx-storage/src/disco.rs#L229), [disco:282](../../../crates/zx-storage/src/disco.rs#L282) | Lote cabeceras/punta y finalización UTXO son operaciones diferentes | No hay aquí un batch conjunto de evidencia + ledger DAG + efectos |
| [UTXO:193](../../../crates/zx-storage/src/utxo.rs#L193), [UTXO:238](../../../crates/zx-storage/src/utxo.rs#L238) | Aplicar/deshacer trabaja sobre copia y publica al final | Patrón útil, no integración de estado DAG/blindado |
| [SPEC](../../../SPEC.md), C-TX-01/02/03, C-BLK-01, C-NET-23 | txid excluye auth; wtxid distingue txid/auth; header actual sólo compromete efectos | Un testigo malo no invalida todas las entregas de ese header |
| [Regresión Ed25519](../../../crates/zx-core/tests/ed25519_no_unicidad.rs) | Dos firmas distintas del propietario verifican el mismo mensaje | No exigir firma única ni escoger por hash como supuesto antigrinding |

Los nueve tests previos de [IDV](../identidad-disponibilidad-v1/DISPONIBILIDAD.md) ejecutaron
las APIs transparentes y el almacén en memoria. El comportamiento de RocksDB en esta revisión
es lectura de código, no una prueba diferencial ni de recuperación tras corte.

## 2. Separar objetos, no imponer una sola escala de estados

El prototipo debería distinguir cinco clases de dato:

1. **Entrega:** bytes recibidos y procedencia local; ninguna autoridad de consenso.
2. **Contenido:** efectos y autorizaciones concretos, con codificación inequívoca y orden.
3. **Evidencia:** resultado de verificar ese contenido bajo un snapshot y reglas concretos.
4. **Vista activa:** referencia a un snapshot seleccionado externamente, no por llegada.
5. **Aplicación económica:** ledger y efectos del orden canónico; fuera del almacén de evidencia.

`Recibido → Vinculado → Autorizado → Aplicado` no debe ser un enum único por blockhash:
pueden coexistir una entrega rechazada, una autorización válida en C1 y un conflicto de
ejecución en C2. Tampoco un cuerpo completo deja de estar disponible sólo porque perdió
un conflicto. Consultar por `(contenido, contexto)` y distinguir disponibilidad de ejecución.

**Clave candidata de evidencia:** `(id_contenido_completo, id_snapshot_causal, id_reglas)`.
El contenido completo incluye header/branch y secuencia delimitada de efectos y testigos.
El snapshot vincula todo parámetro que cambie el resultado: salidas gastadas completas,
altura/contexto temporal, importes, madurez, coinbase, límites y versión del verificador.
Los campos PoAS/PoT/archivo y Orchard se añadirían sólo junto con validadores reales;
su ausencia debe quedar expresa, no representarse mediante flags `true` suministrados.

El prototipo puede comparar estructuras completas por igualdad y usar identificadores opacos
para organización. **Un ID asignado por el llamante no acredita el snapshot:** debe quedar
vinculado de forma inmutable a esos datos; reusar el mismo ID con datos distintos es error.
Para producción faltan la derivación autenticada y el formato canónico de esa identidad.

No usar TicketId como clave de caché. Ni blockhash, altura, nombre de rama ni generación local
por sí solos vinculan todos los datos comprobados. Una generación puede prevenir carreras
locales, pero no reemplaza una identidad de historia ni entra en el consenso.

## 3. Admisión, reparación y no degradación

**EV-01 — Entrada validada no falsificable por el llamante.** El único constructor de la
capacidad de evidencia positiva debe ser el compositor real, con campos privados o frontera
equivalente. Evitar `insertar_validado(bytes, true)` y no exponer una conversión pública desde
una etiqueta sintética. Verificar el binding entre la evidencia y los bytes que se publican;
no permitir validar A y adjuntar su certificado a B después.

**EV-02 — Transición transaccional local.** Decodificar y verificar en staging; sólo tras éxito
publicar bytes y evidencia asociados. Un fallo de formato, compromiso, firma, contexto o
almacenamiento deja intacta la evidencia anterior. Una dependencia ausente no se guarda como
invalidez permanente. Los errores locales no penalizan automáticamente al productor.

**EV-03 — Reparación y duplicados.** Sin evidencia previa, una entrega mala no bloquea la buena
posterior. Repetir exactamente contenido/contexto/reglas es idempotente. Una entrega mala
posterior no borra ni reemplaza evidencia buena. Una caché negativa queda limitada a la entrada
exacta y sus condiciones; no contamina otras firmas ni todos los contextos del mismo billete.

**EV-04 — Variantes válidas.** Dos autorizaciones válidas distintas no son corrupción. Puede
conservarse un conjunto acotado o devolver `ValidaNoRetenida` por política local de recursos;
en ambos casos se preserva al menos la evidencia retenida que siga teniendo uso activo.
No prometer que se conservan infinitas variantes del propietario. Retener la primera prueba
válida como elección de caché puede ser local, pero **no** asigna prioridad económica, color,
elegibilidad, subsidio, conteo ni orden. Si dos variantes difieren en peso u otra propiedad
relevante, no se consideran intercambiables sin una regla; el almacén no resuelve esa elección.

Con el header actual, pedir sólo blockhash no identifica una autorización única. Una consulta
para ejecución debe indicar el contenido exacto o usar una regla de selección definida fuera
del almacén. `obtener_cualquiera_validada` sólo sirve como ayuda local explícitamente limitada,
no como selector de consenso. Si la futura cabecera compromete auth, una variante distinta
normalmente será otro candidato: no se reemplaza silenciosamente el contenido comprometido.

## 4. Contextos, reorg y publicación

**EV-05 — Snapshots inmutables y exactos.** Los datos usados durante la verificación no cambian
bajo el mismo ID. `UTXO=None` en una vista incompleta produce dependencia pendiente; en una
vista causal completa puede justificar un rechazo de esa transacción en ese contexto.
No confundirlo con conflicto posterior en el orden de aplicación. Madurez/timelocks también
requieren contexto: una firma válida aislada no prueba validez causal completa.

**EV-06 — Aislamiento entre ramas.** Evidencia para C1 no autoriza C2 automáticamente, aunque
tengan altura, txid y header iguales. Cambiar la vista activa no destruye el certificado de C1
ni lo relabela; volver a C1 puede reutilizarlo si contenido, reglas y snapshot siguen exactos.
Una evidencia válida permanece un hecho histórico local, no una instrucción de aplicar efectos.
Se pueden factorizar verificaciones independientes de contexto sólo con una clave que recoja
sus dependencias completas y una justificación explícita de esa independencia.

**EV-07 — Carrera de publicación.** Si la vista activa cambia durante una verificación, su
resultado puede conservarse bajo el snapshot original; no debe publicarse como evidencia de
la vista nueva. La publicación que realmente consume estado exige comparar la versión/snapshot
esperado y confirmar atómicamente, o devolver `ContextoCambio` sin efectos parciales.
No validar contra un puntero mutable y después leer otra vez “el contexto actual”.

**EV-08 — Dos atomicidades distintas.** Publicar un certificado local con sus bytes no equivale
a aplicar un lote económico. La integración posterior debe publicar ledger, UTXO, estado
blindado, emisión/fees/recuento, undo y referencia de contexto como una operación coherente.
Un reorg fallido conserva íntegro el estado anterior (C-REORG-03). Una implementación en
memoria puede demostrar esta propiedad con staging/copia; no certifica durabilidad de disco.
Persistencia futura: datos referenciados antes de exponer referencias, frontera única de batch
para el cambio lógico, política WAL explícita y recuperación que no confíe en índices adelantados
(C-STORE-01/07/08/10). No inferir atomicidad global de dos métodos que usan batches separados.

## 5. Recursos y poda: límites locales sin reglas de consenso implícitas

Los límites de staging, caché positiva/negativa y cuerpos retenidos se contabilizan separados,
incluyendo duplicados. Agotar recursos devuelve una condición de servicio/reintento, no
`BloqueInvalido`, ni cambia el representante económico. El presupuesto agregado de transporte
existente (C-NET-21) no limita por sí solo toda la caché o la verificación concurrente.

Una evidencia puede expulsarse si se deja de anunciar como disponible y puede recuperarse o
revalidarse antes de usarla; referencias activas necesitan pinning o un fallo explícito de
dependencia. Esto no autoriza olvidar el consumo de billetes ni otros datos de consenso.
Conservar cuerpos y conservar resúmenes exactos de consumo son problemas distintos; no hay
una regla de poda demostrada aquí. Ningún Bloom filter puede decidir consumo o validez.

Coste conceptual, sin cifras medidas: serialización/hashing lineal en bytes; verificación según
las primitivas invocadas; mapas exactos requieren espacio por evidencia/contexto retenidos.
Duplicar snapshots UTXO completos puede dominar memoria: para el primer oráculo pequeño es
aceptable; vistas persistentes/deltas posteriores requieren equivalencia y medición.

## 6. Pruebas mínimas para el prototipo aislado

| Grupo | Casos que deben distinguirse |
|---|---|
| Reparación | ausente→mala→buena; buena→mala; buena→idéntica; bytes distintos de los validados |
| Formato y binding | truncado, trailing bytes, raíz incorrecta, vector auth desalineado, firma mala |
| Variantes válidas | dos auth válidas distintas; orden de recepción invertido; sin elección económica por caché |
| Contexto | mismo ID con datos diferentes rechazado; mismo slot/altura con ramas distintas aislado; cambio de importe/lock/madurez/altura no reutiliza resultado |
| Completitud | salida ausente con contexto incompleto frente a completo; gasto aplicado después no invalida la evidencia causal anterior |
| Reorg | C1→C2→C1; fallo de publicación conserva vista anterior; verificación iniciada en C1 no se etiqueta C2 |
| Atomicidad local | rechazo tras cada fase relevante conserva bytes/certificados/referencias previos; no se expone estado intermedio |
| Recursos | saturación/expulsión no invalida header ni consume billete; evidencia referenciada no desaparece sin estado pendiente explícito |

Para variantes válidas usar verificadores reales. Los vectores Ed25519 conservados prueban
no unicidad para **su mensaje concreto**, no pueden reutilizarse como firmas de un sighash
distinto. Una opción de fixture de cuerpo es MultiSig 1-de-2 con dos autorizaciones legítimas
distintas, si ese perfil está incluido en el compositor; no llamarlo prueba P2K del propietario.
No exigir todos estos perfiles si el prototipo declara un subconjunto: marcar lo que falte.

Los resultados del prototipo sólo cerrarán los casos ejecutados. Quedan fuera cabecera PoST
autenticada, flujos/retos alcanzables, consenso DAG, Orchard, RocksDB y disponibilidad global.
DA0 puede seguir sin progresar por retención aun con una caché y reparación correctas.
