# IDV-v0.1 — Resultado con verificadores reales

Fecha: 2026-09-11. Categoría: **consenso**, porque se revisan las condiciones reales de entrada
al contrato de billete; incluye criptografía, red y almacenamiento. No activa consenso.

## Conclusión

La etapa sustituye varias hipótesis de M0 por comprobaciones contra implementaciones reales,
pero **no cierra todavía la elegibilidad de producción**. Hay evidencia concreta para conservar
piece_offset y separar identidad económica de caché contextual; además se confirma que la
representación PoS puede influir en elegibilidad, no sólo en el hash de desempate.

La disponibilidad necesita un refinamiento importante: respuesta incorrecta, firma no válida,
dependencia ausente e invalidez de una cabecera comprometida no son el mismo estado. Los tests
demuestran lagunas de composición de firmas y conservación de cuerpos en el código actual.
No se traducen esos hallazgos en una garantía nueva de finalidad ni en una tabla de riesgo.

Se conserva el [contrato IDV-v0.1](CONTRATO-VALIDACION.md), la
[derivación de identidad](IDENTIDAD.md) y la [caracterización de disponibilidad](DISPONIBILIDAD.md).
El contrato previo CBE-v0.1 y sus vectores permanecen intactos como modelo abstracto.

## 1. Identidad: recomendación y prueba que faltaba

La recomendación condicionada es:

```text
(dominio económico estable, slot, public_key, sector_index, history_size, piece_offset)
```

Dentro de un contexto archivado fijo, los compromisos KZG y la selección determinista de
pieza/bucket justifican que chunk sea redundante, bajo los supuestos criptográficos descritos
en IDENTIDAD.md. Eso **no** demuestra equivalencia entre flujos, raíces o retos alternativos,
ni que una declaración represente una cantidad determinada de espacio efectivo.

El nuevo [prototipo PoAS](../../../prototipos/poas-identidad/) usa la API real
`subspace_verification::verify_solution::<ChiaTable, _>`, sin feature testing ni sustituto de PoS.
Activa `Some(PieceCheckParams)`: comprobaciones de pieza/historia y KZG reales. La rama de
caducidad se ejercita separadamente con su compromiso opcional.

La raíz de segmento se construye criptográficamente con KZG para el fixture. **Es un contexto
sintético suministrado al verificador**, no una raíz obtenida de una historia ZEROX/Archiver
acreditada. La salida PoT y el rango también son entradas explícitas del experimento, no
valores de producción ni evidencia de su procedencia. No se valida una cabecera PoST completa.

Resultados que discrimina el instrumento:

- Dos declaraciones con distinto piece_offset y chunk igual pasan el verificador bajo el
  mismo contexto. La clave de investigación que omite offset las agrupa; añadirlo distingue
  esas declaraciones. No se infiere de ello una tasa económica o un ataque de red alcanzable.
- Dos PoS distintas para el mismo offset/seed/bucket son aceptadas; no se impone la primera
  prueba devuelta por el generador.
- Cambiar sólo esa PoS cambia la distancia. Un rango elegido entre ambas distancias permite
  que una representación sea elegible y otra no, con el resto de la solución/contexto iguales.
- Mutaciones dirigidas comprueban rechazo por prueba, chunk/testigos, rango, historia, límite
  de offset y caducidad. No se cuentan como equivalentes mutaciones que fallan en una regla anterior.

La consecuencia para el modelo es precisa: **un cobro por identidad no elimina la selección
entre pruebas antes de cobrar**. No se cuantifica su ventaja en red, independencia estadística,
coste de acceso a alternativas ni cumplimiento de deadlines. Una tabla que suponga un único
ensayo por oportunidad no queda justificada sólo por deduplicar el evento económico.

Valores reproducidos, exclusivamente del fixture: slot **4**, s_bucket **22412**.
Para offset 0, las distancias son **4352823087875908110** y **8322768934019865430**;
para offset 1, **3650123740992092631**. Con rango común **8705646175751816220**,
calculado como `2 * min(distancias)` con overflow comprobado, la primera PoS de offset 0
se admite y la segunda falla por `OutsideSolutionRange`. Son comparaciones enteras exactas,
sin Float64 ni tolerancia. No son parámetros adoptados por ZEROX.
Se conservan [entrada completa](../../../prototipos/poas-identidad/resultados/fixture.txt)
y [salida de la ejecución final](resultados/VALIDACION.txt).

## 2. Disponibilidad y firmas: fallos de integración reproducidos

Los [nueve tests de nodo](../../../crates/zx-node/tests/disponibilidad_real.rs) ejecutan wire,
Merkle, almacenamiento en memoria, validación de importes/estructura y el verificador real
de condiciones de gasto. La cabecera heredada sólo transporta los compromisos del fixture;
no se mina ni se considera una cabecera PoST válida.

| Resultado comprobado | Consecuencia para la integración |
|---|---|
| Mismo txid/Merkle/cabecera con firma válida o inválida; cambia auth_digest | Merkle de efectos no autentica los testigos. |
| comprobar_cuerpo y validar_cuerpo admiten el fixture de firma mala; satisface lo rechaza | Falta componer validación criptográfica; sus Ok aislados no habilitan CBE. |
| Composición explícita validar_cuerpo → sighash → satisface rechaza la firma mala | Las primitivas existentes permiten cerrar ese caso P2K; el helper de test no es validador general. |
| Guardar por blockhash permite mala→buena y también buena→mala | Hay que permitir reparación sin degradar evidencia ya verificada; no basta first-seen ni sobrescribir siempre. |
| Almacén distingue ausencia de bytes corruptos; Cadena::bloque devuelve None en ambos | La API superior pierde información necesaria para recuperación y clasificación. |
| Ausencia UTXO produce el mismo error para una salida retirada o desconocida | Hace falta procedencia/completitud del contexto antes de clasificar conflicto o invalidez. |
| Gasto repetido dentro del cuerpo incumple C-BLK-09 | No trasladar a ese caso la omisión de conflictos sintéticos del modelo M0. |

Esto no prueba explotación de la ruta de red completa ni adopción de un bloque no autorizado:
las pruebas de sustitución llaman directamente a la API de almacenamiento. El backend RocksDB
se inspeccionó, pero no se probó en esta etapa. Orchard y el estado conjunto DAG siguen pendientes.

Recomiendo comprometer explícitamente autorizaciones en la futura cabecera DAG, manteniendo
txid separado de firmas. Es un patrón compatible con la separación de
[ZIP-244](https://zips.z.cash/zip-0244#block-header-changes), no adopción de su formato ni de sus
primitivas. Sin ese compromiso, rechazar una firma recibida no demuestra que toda representación
del mismo hash de cabecera sea inválida. Con él, todavía falta garantizar disponibilidad.

## 3. PoT: comprobar prueba, no confiar sólo en output

En [contexto_verificado.rs](../../../prototipos/pot-estable/tests/contexto_verificado.rs)
se añadieron tres tests al verificador real del prototipo existente:

1. Corromper cualquiera de los ocho checkpoints se rechaza, incluidos los siete cambios que
   dejan intacta la salida final.
2. Los checkpoints no verifican al cambiar semilla o cantidad de iteraciones.
3. Una cantidad mal formada devuelve error, no aceptación ni prueba de ausencia de datos.

Pasaron además el test interno AES y el diferencial conservado de 32 vectores upstream.
Se añadió `[workspace]` al Cargo del prototipo para poder ejecutarlo independientemente;
no se incorporó al workspace del nodo ni se modificaron sus primitivas.

Parámetros elegidos de estos tests: semilla pública `[0x42;16]`, 1.600 iteraciones; controles
`[0x43;16]`, 3.200 y 17 iteraciones. Ocho checkpoints procede del tipo implementado, no de una
elección de finalidad. El test verifica esa relación entrada/prueba; no autentica la procedencia
del reloj ni fija su calendario. Una prueba auxiliar incorrecta tampoco convierte automáticamente
la cabecera que menciona el output en inválida: podría recibirse la prueba correcta.

## 4. Reproducción, parámetros y límites

Fuente PoAS: copia local `PDF/autonomys-subspace`, commit
`f8842d019cdf0f7163421b9644db5a9ff82b2a73`, comprobada limpia. Es referencia fijada, no afirmación
de versión más reciente. El Cargo/lock del prototipo es independiente; los paths upstream
deben conservar ese commit. No se actualizó ni modificó la copia upstream.

HEAD ZEROX: `7b783d469fbae5722a0ae014b5e212ed6999eb2b`, con cambios previos preservados.
HEAD no contiene por sí solo los instrumentos nuevos. Rust ejecutado:
`rustc 1.97.0-nightly (20de910db 2026-05-02)`; Cargo
`1.97.0-nightly (4f9b52075 2026-05-01)`. Se registra la toolchain existente; no se presenta como
certificación con compilador estable. El prototipo PoT conserva su lock: la resolución efectiva
usa aes 0.9.3, no inferirla sólo del rango declarado en Cargo.toml.

```sh
git -C PDF/autonomys-subspace rev-parse HEAD
git -C PDF/autonomys-subspace status --short
env POAS_GUARDAR_FIXTURE=1 cargo test --offline --locked -j 2 --manifest-path prototipos/poas-identidad/Cargo.toml -- --nocapture --test-threads=1
cargo test --offline --locked -j 2 -p zx-node --test disponibilidad_real -- --nocapture
cargo test --offline --locked -j 2 --manifest-path prototipos/pot-estable/Cargo.toml
cargo test --offline --locked -j 2 -p zx-core --test ed25519_no_unicidad
cargo clippy --offline --locked -j 2 --manifest-path prototipos/poas-identidad/Cargo.toml --tests -- -D warnings
cargo clippy --offline --locked -j 2 -p zx-node --test disponibilidad_real -- -D warnings
cargo clippy --offline --locked -j 2 --manifest-path prototipos/pot-estable/Cargo.toml --test contexto_verificado -- -D warnings
rustfmt --edition 2024 --check crates/zx-node/tests/disponibilidad_real.rs prototipos/poas-identidad/tests/identidad_real.rs prototipos/poas-identidad/src/lib.rs
rustfmt --edition 2021 --check prototipos/pot-estable/tests/contexto_verificado.rs
sha256sum -c veritas/consenso/identidad-disponibilidad-v1/HUELLAS.sha256
sha256sum -c veritas/consenso/contrato-billete-v1/HUELLAS.sha256
git diff --check
```

| Ejecución final del agente principal | Resultado |
|---|---|
| PoAS real y mutaciones dirigidas | 1 test aprobado; contiene los casos positivos, negativos y de rango descritos. |
| Disponibilidad/autorización del nodo | 9 tests aprobados. |
| PoT | 3 regresiones nuevas, 1 test AES y 1 diferencial de 32 vectores aprobados. |
| Regresión Ed25519 conservada | 1 test aprobado. |
| Clippy estricto de los tres instrumentos nuevos | Código 0, sin advertencias finales. |
| Formato de los fuentes nuevos | Código 0 usando la edición de cada crate. |

El primer Clippy PoAS detectó un `if` anidado y dos `clone` de tipos Copy; se corrigieron
sin cambiar casos ni valores y se repitió el test. La corrección de Clippy del test de nodo
se documenta en DISPONIBILIDAD.md. Un primer comando manual de formato usó edición 2021
para el nodo 2024; se repitió con la edición declarada, sin reformatear fuentes ajenos.
No se ocultaron rechazos ni se cambiaron valores esperados para obtener aceptación.

Hardware observado: AMD Ryzen 9 9950X3D, 16 núcleos/32 hilos lógicos; RAM total
132497408000 bytes. Cargo se limitó a 2 jobs por proceso; el test PoAS se ejecutó con
`--test-threads=1`. No se usó BLAS, GPU ni paralelización de simulaciones. Se conserva
[entorno observado](resultados/ENTORNO.txt); los targets aislados ocupaban 304 MiB PoAS
y 126 MiB PoT después de test/Clippy. No son tamaños de binario ni presupuesto de nodo.

Las [huellas](HUELLAS.sha256) fijan documentos, instrumentos, locks y artefactos de esta etapa.
Se verificaron también las huellas anteriores CBE-v0.1: todos los ficheros enumerados
permanecen idénticos. No se reejecutó Julia ni se presenta ese chequeo de bytes como
una nueva validación numérica.

Se siguió LINEO con especialistas Rust, matemáticas/Julia y C++/sistemas. No se creó una
simulación Julia nueva: esta fase exige ejecutar los verificadores Rust y razonar sus fronteras,
no sustituirlos por otro modelo. No se creó ni ejecutó Python, no hubo GPU ni Monte Carlo.

Presupuestos declarados de las subtareas: PoAS 20 minutos/8 GiB RAM/8 GiB disco/2 jobs;
disponibilidad 10 minutos/4 GiB/2 jobs. El test PoT se ejecutó con timeout 120 s y 2 jobs.
No se agotaron los presupuestos ni se rebajaron las comprobaciones criptográficas. Tiempos de
tests y picos de proceso son datos de ejecución, no benchmarks ni cotas de verificación en red.
Los parámetros concretos PoAS y sus resultados quedan junto al prototipo para no mezclar una
raíz/slot de fixture con los parámetros pendientes del DAG.

## 5. Qué se ha cambiado y qué sigue abierto

Nuevos: instrumento PoAS aislado, tests de disponibilidad y PoT, derivación/documentación IDV.
En SPEC se corrigió la afirmación falsa de unicidad del sello Ed25519 y se hicieron explícitas
las fronteras de firmas/compromisos comprobadas. No se cambió algoritmo de firma, txid, formato
de cabecera, validador activo, ventana, retarget, tasa ni k. No se limpiaron cambios anteriores.

**Orden recomendado antes de calcular:**

1. Definir el dominio económico entre flujos/retos y modelar la elección de PoS alternativas.
2. Cerrar el compromiso de autorizaciones y la composición de verificadores sobre contexto causal.
3. Separar almacenamiento recibido/validado, reparación y falta de datos; ensayar retención DA0.
4. Con esos contratos fijados, integrar ventana y controlador causal con las mismas adjudicaciones.

Los hallazgos no autorizan a decidir por llegada, añadir comité/staking ni declarar irreversibles
pagos en segundos. La próxima garantía debe referirse a reversión de pagos que Cortex aceptó,
incluyendo periodos sin progreso y pagos nunca aceptados, no sólo a la unicidad del ledger.
