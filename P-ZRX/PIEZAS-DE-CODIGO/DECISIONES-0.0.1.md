# Decisiones de ZEROX 0.0.1

No hay valores de consenso nuevos decididos. Los parámetros `<<PENDIENTE>>` del SPEC no se fijan aquí. Se registrarán con el formato de `PROMPT.md` §4 las decisiones que bloqueen una pieza y, en régimen desatendido, cualquier elección provisional, su fundamento, aislamiento y reversión.

La discrepancia aritmética de 17 frente a 18 piezas no es una decisión de protocolo: se conservan las 18 casillas enumeradas. La frase introductoria desactualizada de `SPEC.md` §6.1 tampoco modifica C-HDR-01; requiere corrección editorial posterior fuera de la zona de trabajo.

## DECISIÓN NECESARIA · CI-A1

**Pieza bloqueada:** A1, cierre de §8.1 y guardián `ci/alcance-consenso.sh`.

**Descripción:** A1 añade `zx-consensus::poas::verificar_solucion_poas` como función pública deliberadamente no cableada hasta C1/B3. El guardián exige declararla en `ci/consenso-pendiente.txt`. Además, el enlace por ruta a los crates del clon fijado requirió modificar `Cargo.toml` de la raíz y regenerar `Cargo.lock`; esos dos archivos **ya fueron modificados por DeepSeek** y la orden A1 los declaró, pero `PROMPT.md` §8 solo permite escribir en `crates/` y `P-ZRX/PIEZAS-DE-CODIGO/`. Fue un error del líder autorizar esos archivos en su orden sin resolver antes el límite del encargo. Los tres archivos quedan fuera de la zona original.

**Opción A · Excepción mínima para dependencias e inventario de CI**

- Ventajas: conserva el enlace necesario a la API auditada, deja explícita la integración pendiente y permite pasar el guardián y cerrar A1 con trazabilidad.
- Desventajas: conserva dos archivos ya modificados fuera de la zona original y añade un tercero; exige inspección individual de sus diffs.
- Descripción: permitir solo `Cargo.toml`, `Cargo.lock` y `ci/consenso-pendiente.txt`. Los dos primeros registran exclusivamente las exclusiones de workspace y dependencias de A1; en el tercero, añadir la función con motivo y fase C1/B3. No alterar scripts, otras listas ni reglas.

**Opción B · Mantener la zona estricta**

- Ventajas: recupera literalmente el límite de archivos original.
- Desventajas: exige retirar los cambios de manifiesto y lock escritos por DeepSeek, A1 deja de compilar con dependencias por ruta y queda sin cerrar; el guardián sigue rojo mientras la función sea pública y huérfana.
- Descripción: revisar y revertir solo los cambios de DeepSeek en esos dos archivos, sin `git reset` ni borrar trabajo ajeno; mantener el resto como trabajo pendiente o rediseñar el enlace a Autonomys antes de marcar casilla.

**Recomendación:** A. El enlace por ruta requiere que Cargo resuelva el clon con su propio workspace; conservar los dos archivos hace reproducible la compilación. El inventario fue diseñado para registrar funciones de consenso aún no alcanzadas, exactamente esta situación. Los cambios son localizados y reversibles: las exclusiones y dependencias se retiran si se abandona el adaptador, y la entrada de CI se elimina cuando C1/B3 cablee la llamada. No fijan valores de consenso.

**Resolución del usuario (2026-09-24, «AFIRMATIVO»):** autorizada la opción A **solo para** `Cargo.toml`, `Cargo.lock` y `ci/consenso-pendiente.txt`. Se conservaron los dos primeros y se añadió a la lista la entrada `zx-consensus::poas::verificar_solucion_poas` con motivo y fase C1/B3. `ci/alcance-consenso.sh` y `ci/citas-spec.sh` pasan. No se autorizó editar otros archivos fuera de la zona original; `TAREAS.md` y `P-ZRX/P-ECLIPSE/` son trabajo concurrente ajeno y quedan intactos.

## DECISIÓN PROVISIONAL · C1-INDICADOR

**Pieza bloqueada:** C1, indicador de conmutación de la cabecera DAG.

**Descripción:** `PROMPT.md` §2 y §3 exigen quitar el `ignore` de `el_codigo_alcanza_la_base_poas_de_556` y hacerlo pasar. Ese test compara `zx_core::preimage::block::TAMANO_CABECERA`, que pertenece a la cabecera lineal heredada de 92 B, con 556 B. `SPEC.md` C-HDR-01/C-HDR-09 distingue la base PoAS lineal de 556 B de la cabecera DAG de 589–1037 B. La decisión arquitectónica ya tomada mantiene la ruta lineal en paralelo hasta conmutar. Hacer pasar la comparación literal cambiaría falsamente el tamaño del tipo lineal o no probaría que el nodo usa DAG.

**Opción A · Sustituir el indicador por una prueba de la ruta activa**

- Ventajas: certifica que `zx-node` recibe, persiste y valida `DagBlockHeader` con el codec canónico y que la admisión activa no pasa por `BlockHeader` lineal.
- Desventajas: hay que editar el test de aceptación y escribir una prueba de integración de nodo/almacén; se aparta de la instrucción literal de quitar un `ignore`.
- Descripción: al cerrar C1, retirar el test ignorado que compara el tipo lineal con 556 B y reemplazarlo por una prueba que ejercite la ruta activa DAG. Mantener una prueba separada de que el tipo lineal conserva su longitud real mientras siga existiendo. No declarar C1 cerrado por una constante o por un codec aislado.

**Opción B · Cumplir literalmente el test de 556 B**

- Ventajas: satisface el indicador textual de `PROMPT.md` sin editarlo.
- Desventajas: su aserción pertenece al tipo equivocado y puede dar verde aunque el nodo continúe en PoW lineal; cambiar el tamaño declarado rompería el codec lineal.
- Descripción: designorar el test actual y modificar su constante o el tipo lineal hasta que compare igual a 556 B.

**Recomendación y elección PROVISIONAL:** A. La evidencia está en `crates/zx-consensus/tests/spec_numeros.rs` y `SPEC.md` C-HDR-01/C-HDR-09; la ruta activa se verificará por comportamiento, no por una igualdad de constantes ajena a ella. Es reversible: esta decisión solo vive en este documento y la hoja de ruta hasta C1; si Katana elige otro indicador correcto, se cambiarán esas referencias y el futuro test de integración. No altera consenso ni `PROMPT.md`.

## DECISIÓN PROVISIONAL · C1-COLA

**Pieza bloqueada:** preparación del almacenamiento para C1; admisión del nodo sigue pendiente.

**Descripción:** C-HDR-07 deja la justificación PoT fuera de `block_hash` y permite reemplazar la evidencia para la misma cabecera. El almacén lineal actual no puede representar dos candidatos DAG del mismo slot. Antes de tener la puerta de validación, el almacén solo puede tratar los bloques como datos no confiables.

**Opción A · Una versión completa por hash en cola no confiable**

- Ventajas: implementación pequeña, atómica y reversible; admite reintentar una justificación PoT nueva sin bloquearse por la primera.
- Desventajas: una versión inválida posterior puede desalojar otra buena, y sin presupuesto de cantidad/tamaño la cola no es apta para exposición directa a la red.
- Descripción: guardar el `BloqueDag` completo por `block_hash` y reemplazarlo entero en la cola de candidatos. La futura admisión debe proteger la evidencia ya validada y acotar recursos antes de usar esta cola desde red.

**Opción B · Conservar varias versiones por hash desde el inicio**

- Ventajas: una justificación temprana inválida o tardía maliciosa no desplaza automáticamente otra evidencia.
- Desventajas: exige límites, política de expulsión y estado de verificación que aún no existen; una cola ilimitada sería un vector de agotamiento.
- Descripción: mantener un conjunto acotado de versiones por hash y elegir la evidencia validada mediante la futura puerta de consenso.

**Recomendación y elección PROVISIONAL para la preparación:** A, **solo como cola no validada y no conectada a red**. No constituye una decisión de validez ni de política de recursos de producción. La revisión Rust independiente confirmó los riesgos de liveness y volumen; bloquearán el cableado hasta que se implementen. La elección vive en `crates/zx-storage/src/{almacen_dag.rs,memoria.rs,disco.rs}` y sus tests; revertirla requiere cambiar esos tres métodos y las pruebas, sin tocar el formato ni parámetros de consenso.

## DECISIÓN NECESARIA · D1-CARGO

**Pieza bloqueada:** D1, plotter/auditor de parcela mediante la API pública de Autonomys.

**Descripción:** `PROMPT.md` §3 exige integrar el plotter/auditor real del clon fijado, y §8 limita las escrituras de DeepSeek a `crates/` y las del líder a este directorio. La excepción «AFIRMATIVO» de CI-A1 cubrió **solo** las dependencias A1 en `Cargo.toml`/`Cargo.lock`. `subspace-farmer-components` vive dentro de `PDF/autonomys-subspace`, hereda dependencias de su workspace y trae cuatro paquetes de ruta todavía no excluidos del workspace ZEROX: `subspace-farmer-components`, `subspace-archiving`, `subspace-data-retrieval` y `subspace-erasure-coding`. Se comprobó con `cargo metadata --offline` en un proyecto de sondeo bajo `/tmp`, sin editar la raíz ni el clon. D1 necesita además dependencias por ruta en el manifiesto de un crate de `crates/`; ello regenerará `Cargo.lock` de ZEROX.

**Opción A · Excepción acotada para manifest y lock de D1**

- Ventajas: permite compilar contra `plot_sector`, `CpuRecordsEncoder<ChiaTable>` y `audit_sector_sync`/`audit_plot_sync` reales, sin copiar formatos ni reimplementar KZG/PoS.
- Desventajas: cambia dos archivos fuera de la zona original y añade un árbol transitivo grande al lock; la compilación del farmer consume tiempo y memoria.
- Descripción: permitir editar **solo** `Cargo.toml` de la raíz para añadir las cuatro exclusiones de workspace indicadas y `Cargo.lock` para registrar la resolución necesaria de D1. El manifiesto del crate destino vive en `crates/` y permanece dentro de la zona original. Inspeccionar diff y tests antes de conservarlo. No tocar `PDF/` ni reglas de consenso.

**Opción B · Mantener la zona estricta**

- Ventajas: no cambia los archivos de raíz fuera de A1.
- Desventajas: D1 no puede enlazar la API pública del farmer desde el workspace; usar un plotter casero contrariaría la instrucción de adoptar la primitiva auditada y la advertencia del SIGSEGV de la ruta no paralela.
- Descripción: dejar D1 bloqueada y avanzar otras piezas hasta que se autorice una vía de dependencias reproducible.

**Decisión PROVISIONAL del líder bajo `PROMPT.md` §4.1: A, solo para la dependencia de D1.** El test upstream `subspace-farmer-components/tests/plot_read_roundtrip.rs` demuestra el uso de `plot_sector` con `CpuRecordsEncoder<ChiaTable>`; `auditing.rs` advierte que auditar devuelve candidatos que aún requieren prueba. El sondeo de Cargo resolvió los paquetes de ruta sin tocar ZEROX. La excepción es reversible: retirar exactamente las cuatro exclusiones D1 de `Cargo.toml`, las dependencias D1 de `crates/zx-node/Cargo.toml` y el módulo `farmer`, y regenerar `Cargo.lock`; A1 y el resto del workspace no se revierten. Si Katana elige B, se ejecuta esa reversión **fichero a fichero tras inspección**, sin `git reset` ni limpiar el árbol. Esta decisión no fija parámetros ni reglas de consenso y no autoriza editar `PDF/`, `SPEC.md` o CI. D1 puede cerrarse con esta elección marcada PROVISIONAL y Katana puede revisarla; no se presenta como aprobación de Katana.

## DECISIÓN NECESARIA · C3-ARRANQUE

**Pieza bloqueada:** C3, génesis DAG PoST; por dependencia, A2, D2 y la red local F4.

**Descripción:** `SPEC.md` C-FLU-06 define `semilla(f₀,0) = blake3(block_hash(génesis) ‖ entropía_externa)[0..16)`. C-POT-01/02 indican evaluar la salida del slot 0 desde esa semilla, y C-POT-03 deriva de esa salida el reto PoAS. Pero C-HDR-09 incluye en `block_hash(génesis)` tanto `pot_output` como la solución PoAS y el sello. Si se exige verificar esos campos del génesis con las reglas ordinarias, el reto y el output dependen de su propio hash; cambiar la solución para satisfacer el reto cambia a su vez el reto. C-GEN-02 deja sin definir precisamente la condición de prueba y estado PoST inicial, y §15 deja pendientes otros parámetros y hashes. La búsqueda en `P-ZRX/`, `research/` y `veritas/` halló la fórmula de C-FLU-06 repetida, pero no una resolución de esta circularidad. El génesis lineal exime PoW, **sin** autorizar una exención PoST nueva. Se puede construir y comprobar **solo estructura y hash** de un fixture DAG de desarrollo mientras se decide, pero no habilitar admisión PoST del génesis.

**Opción A · Génesis ancla explícita**

- Ventajas: elimina el ciclo sin cambiar el hash ni el formato DAG; el génesis de hash congelado y coinbase de valor cero es un punto de arranque acordado, y PoT/PoAS se exigen desde el primer bloque posterior. Permite una red de desarrollo medible con una excepción única y visible.
- Desventajas: requiere escribir en C-GEN-02 y las reglas relacionadas una excepción PoST **solo para génesis**, la semántica exacta de sus campos PoST y el ancla para el primer rango; esos campos no quedan acreditados por prueba ordinaria. Requiere fijar entropía externa y hash antes de activar la red.
- Descripción: definir al génesis como ancla estructural y de estado, sin recompensa gastable y sin prueba PoST ordinaria. Su hash se congela y se comprueba al arranque; de él y de la entropía externa precomprometida sale la semilla para las pruebas de los slots posteriores. La excepción se implementa en una rama de génesis explícita, nunca como `Ok` general ni como bypass para bloques posteriores.

**Opción B · Compromiso previo independiente**

- Ventajas: permite exigir PoT/PoAS también al génesis sin dependencia circular si la semilla y el reto se derivan de un compromiso previo que excluya `pot_output`, solución y sello.
- Desventajas: cambia la entrada actualmente escrita en C-FLU-06 y añade un nuevo objeto de lanzamiento, su dominio de hash, proceso de precompromiso, formato y vectores; aún necesita fijar el archivo de piezas y el contexto PoAS inicial. Mayor superficie para errores de arranque.
- Descripción: especificar un `bootstrap_commitment` canónico e independiente del hash de cabecera final. Derivar `f₀` y la semilla inicial de ese compromiso y de la entropía externa; después producir PoT, PoAS y sello del génesis. La prueba y el compromiso deben quedar vinculados inequívocamente a la red y al hash final.

**Recomendación, no decisión:** A para el perfil de desarrollo de 0.0.1. El hash congelado ya es el ancla de confianza de cualquier génesis; exigirle trabajo PoST autocircular no añade una comprobación ejecutable. La excepción tendría que quedar escrita y acotada antes de activar la red, y no se extrapola a mainnet/testnet por silencio. Es reversible mientras no haya red publicada: `genesis_dag.rs`, el perfil de desarrollo, las pruebas de arranque y luego las reglas de bootstrap serían los puntos a cambiar si se elige B. **No se ha elegido ni implementado una regla de validez de génesis; no se edita `SPEC.md` en este encargo.**
