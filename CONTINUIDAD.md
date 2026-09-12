# Continuidad de trabajo — antes de `/clear`

Actualizado: 2026-09-11. Raíz: `/home/katana/zeo/ZEROX`.
Este documento conserva contexto y enlaces; **no activa reglas de consenso, no sustituye
los contratos ni autoriza por sí mismo nuevas implementaciones**.

## 1. Objetivo y decisiones del usuario

- Mantener **PoSpace-Time (PoAS + PoT) + DAG**, capa transparente y capa blindada
  Orchard/Halo2 prevista. Todavía no hay un nodo destino completo.
- Prioridades: seguridad global, coste de nodo asumible y menor espera real para que
  Cortex acepte un pago bajo un riesgo explícito. Cortex no decide el consenso.
- Restricciones vigentes: **sin staking ni comités de decisión**. Cliente ligero secundario;
  servidores privados de consulta como alternativa, no autoridades de finalidad.
- El usuario aprobó estudiar un único derecho económico y un único cuerpo ejecutable por
  billete; después aprobó comprobar identidad/disponibilidad reales y cerrar el dominio
  económico y la composición autorización/contexto/almacenamiento. Son candidatos de estudio.
- En tareas complejas de protocolo, especialistas independientes en matemáticas y en
  Rust, Julia y C++, conforme a AGENTS.md. Participaron `rust_consenso`,
  `matematicas_julia` y `cpp_protocolos`; no depender de que sus sesiones sobrevivan.
- Antes de nuevas auditorías, simulaciones o tests de cálculo: leer **íntegro**
  [veritas/LINEO.md](veritas/LINEO.md). No crear ni ejecutar auditorías Python.
  Julia CPU; C++/CUDA sólo si el perfil justifica GPU. Rust para verificadores reales.
- La limpieza antigua fue autorizada y el usuario tenía copia de seguridad. No es una
  autorización permanente para seguir borrando. Preservar todos los cambios existentes.
  El vault externo de Obsidian es histórico, contiene PoW y no es autoridad vigente.

## 2. Orden de lectura al retomar

1. [AGENTS.md](AGENTS.md), [README.md](README.md), [MIGRACION.md](MIGRACION.md)
   y las secciones pertinentes de [SPEC.md](SPEC.md).
2. Informes de las tres etapas, en orden: [CBE](veritas/consenso/contrato-billete-v1/INFORME.md),
   [IDV](veritas/consenso/identidad-disponibilidad-v1/INFORME.md),
   [DAV](veritas/consenso/dominio-autorizacion-v1/INFORME.md).
3. Sus contratos, fuentes y resultados cuando el encargo los requiera.
4. [Ficha de finalidad y parámetros](veritas/finalidad/baseline-30m/MODELO.md)
   y [fuentes upstream](PDF/README.md) antes de nuevos cálculos.

Los documentos anteriores conservan su fecha y alcance: un pendiente de CBE puede tener
una decisión candidata posterior en DAV sin estar integrado en producción. No interpretar
esa diferencia temporal como una contradicción ni como permiso para reescribir resultados.

## 3. CBE-v0.1: contrato y modelo abstracto Rust/Julia

Fuentes: [contrato](veritas/consenso/contrato-billete-v1/CONTRATO.md),
[informe](veritas/consenso/contrato-billete-v1/INFORME.md),
[modelo Rust](crates/zx-consensus/tests/contrato_billete_modelo.rs).

- **P0 principal:** primera copia elegible en orden canónico, nunca por llegada. Un derecho
  económico y un cuerpo ejecutable por identidad y por historia aplicada.
- **P1 comparador legítimo:** prioridad azul sólo dentro del mismo lote, respetando consumos
  heredados; la ganadora ejecuta en su posición propia. No espera ni reemplaza por azules futuros.
- El consumo también ocurre con subsidio cero, cuerpo vacío o todos los gastos en conflicto.
  No liberar el billete para ensayar otro cuerpo buscando un resultado mejor.
- Registro contextual, preparación privada, publicación conjunta y undo/reorg. No unir los
  registros de ramas alternativas ni presentar unicidad por historia como finalidad global.
- **DA0, perfil experimental:** exige todos los cuerpos nuevos del lote, incluidos perdedores
  y tardíos. Un cuerpo retenido puede bloquear el progreso. Ausente no significa inválido.
- **L0, perfil experimental:** ventana común para subsidio, conteo y ejecución; tardíos inertes.
  Tiene coste para participantes honestos y no es una política de producción ya aprobada.
- M0 recibe identidad, orden, color y validez de oráculos sintéticos. No deriva GHOSTDAG,
  no verifica criptografía real y no ejecuta UTXO/Orchard de producción.

Ejecución conservada: 14 tests Rust; 35 casos/49 EXPECT compartidos; Julia 1.13.0,
9.024 aserciones del modelo y 163 de fixtures. No son probabilidades ni ataques de red.
El microbenchmark final de 17,1450 µs por lote sintético **no mide rendimiento del nodo**.
Una reserva anticipada redujo asignaciones pero empeoró esa latencia; se descartó y quedó
documentada. Resultados, entorno y comandos están en el informe, no hace falta repetirlos
para recuperar contexto.

## 4. IDV-v0.1: identidad y disponibilidad con verificadores reales

Fuentes: [informe](veritas/consenso/identidad-disponibilidad-v1/INFORME.md),
[identidad](veritas/consenso/identidad-disponibilidad-v1/IDENTIDAD.md),
[disponibilidad](veritas/consenso/identidad-disponibilidad-v1/DISPONIBILIDAD.md).

- Bajo contexto archivado fijo y los supuestos criptográficos descritos, conservar
  `piece_offset` en la identidad; `chunk` resulta redundante dentro de ese contexto.
- [Prototipo PoAS](prototipos/poas-identidad/README.md): verificador real Autonomys,
  ChiaTable y KZG, con `Some(PieceCheckParams)`, sin mock de PoS. La raíz archivada es un
  fixture sintético, no una historia ZEROX autenticada; no valida una cabecera PoST completa.
- Dos offsets diferentes con el mismo chunk verifican. Dos PoS distintas del mismo offset
  cambian la distancia; con un rango discriminante una entra y la otra no. **Deduplicar pagos
  no elimina ensayos alternativos ni su posible ventaja de elegibilidad.** Coste, multiplicidad,
  independencia y deadlines de esos ensayos siguen sin cuantificarse.
- El algoritmo habitual de Ed25519 es determinista, pero su propietario puede producir
  varias firmas válidas del mismo mensaje. La [regresión](crates/zx-core/tests/ed25519_no_unicidad.rs)
  usa verificación real; no es falsificación de firmas ajenas ni motivo para reemplazar Ed25519.
- [Tests de nodo](crates/zx-node/tests/disponibilidad_real.rs): Merkle/txid actuales no
  comprometen autorización; una entrega con firma mala puede compartir cabecera con una buena.
  `validar_cuerpo` no compone por sí solo `satisface`; un Ok aislado no acredita firmas.
- Guardar directamente por blockhash permite reparación mala→buena, pero también degradación
  buena→mala. Es una caracterización de API, **no un exploit de adopción por la red completa**.
  El nivel superior también pierde distinciones entre ausente/corrupto y procedencia UTXO.
- [Tests PoT](prototipos/pot-estable/tests/contexto_verificado.rs): corromper checkpoints,
  semilla o iteraciones se rechaza; output final solo no acredita toda la prueba/contexto.

Ejecución conservada: 1 test PoAS con múltiples casos, 9 de nodo y 3 regresiones PoT;
también pasaron AES, diferencial de 32 vectores y Ed25519. Clippy/formato correctos.
No RocksDB ejecutado, ni integración Orchard, ni simulación Julia nueva en esta etapa.
SPEC sólo recibió correcciones explicativas sobre firmas/compromisos/fronteras; no se
activaron cambios de formato, validadores, parámetros o consenso.

## 5. DAV-v0.1: última etapa implementada

Fuentes: [contrato](veritas/consenso/dominio-autorizacion-v1/CONTRATO.md),
[informe](veritas/consenso/dominio-autorizacion-v1/INFORME.md),
[prototipo aislado](prototipos/autorizacion-contextual/README.md).

Clave económica candidata:

```text
(NetworkDomain, slot, public_key, sector_index, history_size, piece_offset)
```

NetworkDomain es fijo por red, no elegido por cada productor; no cambia por reto, raíz,
rango, flujo, firma o versión del software. Es **política económica**, no prueba de que
todos esos trabajos físicos sean equivalentes. Las coordenadas declaradas no son una PoAS.
Un productor honesto puede perder adjudicación al abandonarse su rama; no conservar la
afirmación excesiva «sólo perjudica a quien publica copias».

Componentes nuevos en `prototipos/autorizacion-contextual/src/`:

- `dominio.rs`: claves exactas y compatibilidad de prefijos PoT **declarados**, incluyendo
  iteraciones efectivas N y comparando cada bloque pasado en su propio slot. No basta comparar
  etiquetas de las puntas. No autentica origen, calendario, PoT ni pasado DAG.
- `lib.rs`: composición real de validación nativa, sighash y firmas sobre un snapshot owned
  inmutable. Token de autorización con construcción privada. Perfil PubKey/MultiSig/HTLC,
  HashType ALL; no soporta Orchard, lock_time no nulo ni dependencias intra-cuerpo.
  NoSoportado no significa inválido para consenso; gastado en snapshot no prueba autorización.
  El snapshot identifica su contenido, pero su procedencia/completitud las declara el llamante.
- `compromiso.rs`: vector ordenado txid/auth_digest, coinbase y multiplicidad incluidas;
  rechaza otra autorización incluso válida si no coincide con el compromiso esperado.
  Ese compromiso sigue suministrado externamente: **no está en una cabecera DAG firmada**.
  La clave local de caché incluye cabecera: insertarla en esa misma cabecera sería autorreferente.
- `almacen.rs`: caché de evidencia en memoria, no ledger. Sólo retiene tokens verificados,
  no degrada evidencia con entregas malas; claves exactas por cuerpo/contexto, límites locales,
  publicación condicional y rechazo de vistas obsoletas. No selecciona el ganador por llegada.

La revisión independiente detectó que contexto+revisión no aislaban distintas instancias de
caché. Se añadió identidad de instancia con contador comprobado y regresión con firmas reales.
No recicla identificadores; protección volátil dentro del proceso, no recuperación durable.
El presupuesto de peso **no equivale** a RAM/disco/tráfico total. La caché no elimina el coste
de recibir y verificar copias ni la retención DA0.

Ejecución final conservada: **40 tests runtime + 2 doctests compile_fail**, Clippy estricto,
formato y 14 regresiones CBE. Registros: [TESTS](veritas/consenso/dominio-autorizacion-v1/resultados/TESTS.txt),
[CONTROLES](veritas/consenso/dominio-autorizacion-v1/resultados/CONTROLES.txt),
[ENTORNO](veritas/consenso/dominio-autorizacion-v1/resultados/ENTORNO.txt).
No Julia nuevo, benchmark ni suite completa del nodo. DAV sólo añadió archivos nuevos;
no modificó SPEC, crates de producción ni artefactos CBE/IDV.

## 6. Dictamen y siguiente paso recomendado, no ejecutado

La arquitectura es explícita y comprobable como candidata. Hay mejoras concretas de
invariantes y composición en modelos/prototipos, **no prueba de superioridad global en
seguridad, rendimiento o finalidad**. Las lagunas del nodo activo siguen sin integrar.

Próxima fase propuesta: **ventana/admisión tardía y retarget causal** alimentados por las
mismas adjudicaciones. Antes de calcular fijar unidades, fuente y estado de cada parámetro
(elegido/medido/derivado/pendiente), adversario, criterio de aceptación y de fallo.

Obligaciones:

1. Producción admitida a tiempo no es toda la producción. Igualdad contada/pagable no
   demuestra estabilidad o ausencia de sesgo frente a retardo, saturación y retención.
2. Precisar ventana, bootstrap, desfase de observación, rango ancestral, límites, redondeos
   y política de tardíos. No inventar un número ni recalibrar tasa/k para favorecer resultados.
3. Mantener explícitos el bloqueo DA0 y los ensayos alternativos PoS/retos. Se puede estudiar
   el controlador condicionalmente; no certificar el sistema mientras esas hipótesis estén abiertas.
4. Comparar P0/P1 en trazas iguales y en evoluciones con realimentación propia. Mismo adversario
   y presupuesto de nodo; no comparar modelos con distinta pérdida o criterio de parada.
5. Medir **reversión de pagos que Cortex ya aceptó**, también pagos nunca aceptados, esperas
   censuradas, reinclusiones, exclusión honesta, colas y periodos sin progreso.
6. Antes de producción: contexto causal autenticado, compromiso de cuerpo firmado en cabecera
   DAG, verificación PoAS/PoT integrada, Orchard, transición atómica económica/UTXO/undo,
   recuperación durable, poda y disponibilidad adversarial.

No hay garantía nueva de segundos por ancla PoT. Los riesgos históricos a 30 minutos son de
una carrera nominal, no del pago DAG integrado. Los 112,5 s no tienen prueba válida de
irreversibilidad y no satisfacen la condición del perfil conservando S_max nominal.
Un límite local de reorganización tampoco demuestra «riesgo cero a 3,33 h» ni acuerdo global.
Ver SPEC §13 y la ficha de modelo, no reutilizar las primeras tablas del chat como verdades vigentes.

## 7. Última conversación: consulta sobre staking, sin adopción

El usuario preguntó qué implicaría añadir staking. Se explicó que requeriría capital bloqueado
para un papel en consenso; slashing es una elección adicional para infracciones demostrables.
Una capa de votación podría estudiarse sobre PoST+DAG, pero requiere diseñar su composición,
quórums, entrada/salida, penalizaciones y resolución de desacuerdos. No garantiza por sí sola
más capacidad, rapidez, disponibilidad ni indemnización a Cortex.

No implica necesariamente un comité fijo, pero si esos validadores deciden finalidad sí añade
un conjunto con poder de decisión. Cortex y los usuarios pagadores no tendrían necesariamente
que aportar depósito. PoST ya tiene costes de hardware/operación; «sin staking» significa no
exigir monedas como garantía del protocolo, no ausencia de todo coste económico.

Se consultaron como ejemplos las fuentes primarias de [PoS de Ethereum](https://ethereum.org/developers/docs/consensus-mechanisms/pos/)
y [Gasper](https://ethereum.org/developers/docs/consensus-mechanisms/pos/gasper/).
No se trasladaron sus umbrales o tiempos a ZEROX. **La pregunta no autorizó staking ni comités**;
la recomendación fue no añadirlos sólo por buscar velocidad y mantener cualquier estudio
alternativo separado si el usuario decide explícitamente revisar esas restricciones.

## 8. Conservación comprobada al cerrar esta sesión

HEAD de referencia: `7b783d469fbae5722a0ae014b5e212ed6999eb2b`.
El worktree tiene numerosos cambios, borrados históricos y archivos nuevos sin seguimiento.
**Están en disco, no incluidos por ello en HEAD. No se hizo commit ni push.** No restaurar
ni limpiar el worktree para hacerlo coincidir con HEAD; conservar también archivos untracked
si se hace una copia. Un commit de los archivos seguidos no sustituye esa copia completa.

Comprobación de integridad ejecutada de nuevo el 2026-09-11, antes de `/clear`:

| Manifiesto | Entradas verificadas | Resultado |
|---|---:|---|
| `veritas/consenso/contrato-billete-v1/HUELLAS.sha256` | 12 | Todas coinciden. |
| `veritas/consenso/identidad-disponibilidad-v1/HUELLAS.sha256` | 32 | Todas coinciden. |
| `veritas/consenso/dominio-autorizacion-v1/HUELLAS.sha256` | 58 | Todas coinciden. |

Hay archivos compartidos entre manifiestos: no son 102 archivos distintos. Esta comprobación
es de bytes contra registros conservados, **no una nueva ejecución de tests ni auditoría matemática**.
No se reejecutaron tests ni se modificaron validadores durante este cierre.

Las copias upstream están en `PDF/autonomys-subspace` y `PDF/chia-blockchain`, ignoradas por
Git. Versiones fijadas y reconstrucción en [PDF/README.md](PDF/README.md); Autonomys es
`f8842d019cdf0f7163421b9644db5a9ff82b2a73`, no la versión latest.
No actualizar fuentes/locks para retomar una comprobación antigua.

Permanece el fallo de migración conocido: cabecera Rust heredada de 92 bytes frente a base
PoAS lineal de 556 bytes del SPEC, que tampoco fija por sí sola el formato DAG. No desactivar
el test ni afirmar que la suite completa pasó por haber pasado un prototipo aislado.

Para retomar: **leer este documento y el informe DAV; después seguir el encargo actual del
usuario**. La siguiente fase recomendada está en §6; no hay cálculo o simulación pendiente
en ejecución que deba recuperarse.
