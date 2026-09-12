# Investigación de ZEROX

El destino del proyecto es **PoSpace-Time + DAG**, con transferencias transparentes y un pool
blindado. El estado de la migración y la separación entre componentes conservados y pendientes
se documentan en [MIGRACION.md](../MIGRACION.md).

Los informes originales de este directorio conservan sus parámetros, resultados y correcciones.
Son **evidencia histórica**, no una especificación vigente ni instrucciones para implementar una
propuesta. Una etiqueta «VERIFICADO» pertenece al modelo y a la ejecución descritos en ese informe;
no acredita automáticamente el protocolo destino ni una implementación actual.

Las instrucciones actuales del usuario prevalecen sobre los encargos históricos. El vault externo
de Obsidian conserva documentación PoW desactualizada: no determina vigencia, parámetros ni
decisiones pendientes de ZEROX.

## Espacio, tiempo y pruebas

- [PoSpace y tiempo](proof-of-space-tiempo.md): contexto y diferencias entre diseños de Chia.
- [Intercambio entre tiempo y memoria](time-memory-tradeoff.md): límites de las pruebas de espacio.
- [Documentación de Chia](chia-documentacion-oficial.md) y [parcelas comprimidas](chia-parcelas-comprimidas.md): fuentes y alcance de cada versión.
- [Coste de ploteo](coste-ploteo-medido.md): mediciones y extrapolaciones, con su hardware.
- [PoT AES y hardware](pot-aes-asic-chacha.md): hipótesis sobre ventaja de cómputo.
- [Redundancia del timelord](timelord-redundancia-informe.md): dependencia operativa.
- [Prototipo PoT Rust](../prototipos/pot-estable/LEEME.md): código y vectores; su existencia no significa integración en el nodo.

## DAG, selección de cadena y finalidad

- [Consenso DAG sobre PoAS](dag-consenso-poas.md) y [propuesta de DAG nativo](dag-nativo-poas-propuesta.md): antecedentes del diseño.
- [Ancla de orden](dag-poas-ancla-de-orden.md): familia de reglas R-FIN y evolución de propuestas; contiene parámetros de distintas rondas.
- [Retardo y retarget](dag-poas-delta-real.md): modelo histórico superado por R-FIN-13′; no reutilizar su tasa ni su descuento como parámetros actuales.
- [Catálogo de ataques](dag-poas-catalogo-problemas-ataques.md) e [informe de problemas](dag-poas-informe-52-problemas.md): mapa de riesgos y referencias.
- [Empalme de peso](dag-poas-empalme-peso.md), [recursión de flujos](dag-poas-recursion-flujos.md) y [selección PoAS](fork-choice-poas.md): argumentos específicos.
- [Estado de migración y límites de evidencia](../MIGRACION.md): contraste de afirmaciones y límites de transferencia al destino.
- [Contrato candidato de billete CBE-v0.1](../veritas/consenso/contrato-billete-v1/CONTRATO.md) e [informe de validación](../veritas/consenso/contrato-billete-v1/INFORME.md): un derecho económico y un cuerpo ejecutable por identidad; modelo abstracto Rust/Julia, sin activación de consenso ni garantía nueva de finalidad.
- [Identidad y disponibilidad con verificadores reales, IDV-v0.1](../veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md) e [informe](../veritas/consenso/identidad-disponibilidad-v1/INFORME.md): condiciones criptográficas de la identidad, PoAS/PoT reales y fronteras de autorización/almacenamiento; no activación de consenso.
- [DAGKNIGHT y confirmación adaptativa](scripts/d14-dagknight/informe3.md), [Avalanche sobre espacio](scripts/d15-avalanche/informe.md) y [comparación de riesgo](scripts/d16-gate/informe.md): experimentos con correcciones posteriores; no garantías listas para producción.

Las auditorías `dag-poas-*-auditoria*.md`, bitácoras y variantes descartadas preservan la razón de
cada corrección. Un contraejemplo debe conservar sus condiciones: adversario, retardo, pesos,
reglas de padres, reloj, vista del cliente y criterio de aceptación. Ni resultados positivos ni
negativos se trasladan automáticamente a otro conjunto de reglas.

## Capa transparente, codificación y economía

- [Preimágenes y firmas: ZIP-244](zip244.md).
- [Codificación canónica](capnproto-canon.md).
- [UTXO persistente](utxo-persistente.md).
- [Tamaño dinámico de bloque](dynamic-blocksize.md) y [tarifas](dynamic-fee.md).
- [Recalibración temporal](recalibrado-constantes-lambda1.md): revisar unidades y ritmo antes de reutilizar constantes.
- [SHA-3 FIPS 202](sha3-fips202.md) y [referencias criptográficas](sha3-referencias.md): útiles para hashes y firmas; no implican conservar minería PoW.

## Pool blindado

- [Formato del bundle Orchard](orchard-bundle.md).
- [Verificación matemática de Orchard](orchard-math-verification.md).
- [ZIP-244](zip244.md): integración de los compromisos en las preimágenes.

## Red, sincronización y almacenamiento

- [Arquitectura libp2p](libp2p-arquitectura.md) y [pruebas de red](testing-libp2p.md).
- [Sincronización](sync-cadena.md) y [relay de bloques](bip152.md).
- [Reorganizaciones y selección de cadena](fork-choice-reorg.md): conserva mecanismos de atomicidad y evidencia comparativa; sus reglas de cadena lineal no sustituyen las del DAG destino.

## Fuentes y experimentos conservados

[fuentes/](fuentes/) y las subcarpetas de fuentes de cada ronda contienen papers y documentos
primarios. Una referencia PoW o BFT puede ser útil para un argumento o contraejemplo sin convertirse
en una propuesta de adopción. [La capa de comité](dag-poas-capa-finalidad.md) y
[sus costes](scripts/d14-instancia/informe.md) se conservan como evidencia de una familia excluida
por la restricción de no tener comités de decisión.

Los scripts y resultados de [scripts/](scripts/) conservan procedencia, dependencias y casos que
permiten revisar errores. **No se ejecutan como parte del flujo nuevo ni se usan como motores de
nuevas auditorías Python.** Las nuevas auditorías y pruebas de cálculo consultan primero
[veritas/LINEO.md](../veritas/LINEO.md): Julia en CPU y C++/CUDA para GPU cuando corresponda.
Un port debe preservar el modelo explícito y comprobar su equivalencia antes de reclamar cifras.

La eliminación de los mineros antiguos y de investigación exclusiva de PoW se registra en
[MIGRACION.md](../MIGRACION.md). Las referencias históricas a archivos retirados o ubicaciones
temporales no significan que esas piezas sigan disponibles o vigentes.
