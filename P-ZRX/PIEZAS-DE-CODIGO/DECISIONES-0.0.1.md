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

## DECISIÓN PROVISIONAL · CI-A2-FLUJO

**Pieza afectada:** A2, derivaciones puras C-FLU-06/10 y clasificación de su integración.

**Descripción:** `ORDEN-A2-FLUJO-PURO.md` añadió fórmulas puras y tests, pero no una fuente de `past(B)` ni llamada desde el nodo. `ci/citas-spec.sh` exige mover C-FLU-06/10 fuera de `sin-codigo`. `ci/alcance-consenso.sh` exige declarar `semilla_genesis` como entrada aún sin llamante; su lista conserva además dos funciones ahora alcanzadas textualmente por módulos parciales. La excepción CI-A1 previa era acotada; esta corrección es nueva y se decide bajo `PROMPT.md` §4.1, sin atribuírsela a Katana.

**Opción A · Inventario fiel de código parcial, PROVISIONAL.** Ventaja: guardianes vuelven a comprobar la realidad textual sin llamar activa a la ruta; desventaja: cambia tres archivos `ci/` fuera de la zona original y el chequeo de alcance sigue siendo heurístico. Descripción: mover solo C-FLU-06/10 a `sin-cablear`, declarar `semilla_genesis` sin cablear, retirar de `consenso-pendiente` los dos nombres que el chequeo ya alcanza en A3/D1/D2, y documentar que esas llamadas no son admisión de red.

**Opción B · Mantener CI rojo hasta permiso nuevo.** Ventaja: zona estricta intacta; desventaja: la clasificación conocida queda falsa y el gate de citas de §6 falla, bloqueando conservar el avance A2 aun como preparación. Descripción: registrar el fallo y continuar solo fuera de CI.

**Elección PROVISIONAL del líder: A.** Es un cambio de inventario, reversible restaurando solo esas líneas y comentarios tras revisar el diff; no cambia validez de consenso, código de nodo ni parámetros de red. La comprobación de alcance cuenta referencias textuales, por eso `PROGRESO-0.0.1.md` conserva explícitamente que `reto_desde_salida` y `verificar_solucion_poas` no están conectadas a admisión activa.

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

**Decisión PROVISIONAL del líder bajo `PROMPT.md` §4.1: A exclusivamente para un perfil de desarrollo de 0.0.1.** El hash congelado es el ancla de confianza del génesis; exigirle trabajo PoST autocircular no ofrece una comprobación ejecutable. Esta excepción se implementará en una ruta de génesis explícita y optativa que compruebe estructura/hash y no acepte otros bloques sin PoST. Su entropía, hash, rango y parámetros de desarrollo serán entradas explícitas, nunca valores implícitos de mainnet/testnet. Es reversible mientras no haya red publicada: `genesis_dag.rs`, un perfil de desarrollo separado, la inserción de génesis y las pruebas de arranque son los puntos a cambiar si Katana elige B. **No es una regla normativa del SPEC ni una aprobación de Katana; C3 y C-GEN-02 siguen pendientes de cierre para redes de lanzamiento y no se edita `SPEC.md` en este encargo.**

**Corrección matemática de la opción A, 2026-09-24 (PROVISIONAL, solo desarrollo):** la frase «de él y de la entropía ... sale la semilla para las pruebas de los slots posteriores» omite una segunda circularidad. C-POT-05 compromete en la cabecera `pot_output(G)` como salida del slot `D`; para `D=0`, esa salida sería también el resultado de evaluar la semilla inicial derivada de `block_hash(G)` por C-FLU-06, pero el hash incluye el propio `pot_output(G)` (C-HDR-09). La excepción dev ha de abarcar **el estado PoT inicial**, además de la prueba PoAS y el sello del génesis. En un perfil dev con `D_dev=0`, el `pot_output(G)` del hash literal congelado es un **ancla confiada del slot 0**, no una salida AES acreditada desde `semilla(f₀,0)`. Los bloques de slot ≥1 deberán demostrar PoT por AES desde esa ancla y pasar PoAS, sello, rango fijo y demás reglas aplicables; una función pura puede calcular `semilla(f₀,0)`, pero no debe usarla para afirmar que verificó el ancla. Para `D_dev>0`, otra construcción posible sería esperar hasta `slot>D_dev` y comprobar un rango PoT desde el ancla confiada del slot `D_dev`; sus restricciones de espera y anclaje necesitarían una definición dev separada. Esta decisión elige `D_dev=0` y no implementa esa alternativa. Esta corrección no modifica C-FLU-06 ni crea una excepción para bloques ordinarios. Revertirla exige sustituir solo el perfil y su bootstrap dev, antes de conectar la red; el SPEC de lanzamiento sigue pendiente.

## DECISIÓN PROVISIONAL · PERFIL-PRIMER-HIJO-DEV

**Piezas bloqueadas:** A2/A3 y D2 en el primer bloque posterior al génesis DAG dev.

**Descripción:** `C-POT-04` deja `N(s)` inicial pendiente y `C-HDR-06` deja el controlador de rango pendiente. El génesis dev ya tiene ancla PoT confiada de slot 0, pero su `SR_DEV=0x00AB_CDEF` es solo un literal de fixture y no da cobertura demostrada a la parcela pequeña. El test local D2/A2 con una parcela de dos piezas, `N=16` y `SR=u64::MAX` halló una solución PoAS verificada en el slot 2; **no midió tasa de red ni demuestra cobertura con el N definitivo**. La medición previa en `research/dag-poas-ancla-de-orden.md` § coste PoT da 1,561 s de `prove` y 96,1 ms de `verify` para 200 032 000 iteraciones en un Ryzen 9 9950X3D, ocho checkpoints; no es una medida de los tres nodos actuales bajo carga.

**Opción A · Perfil dev aislado con valores explícitos**

- Ventajas: permite construir el primer hijo desde datos fijos, reproducibles e independientes del candidato; conserva la carga PoT para la que ya hay una medición en esta máquina y permite encontrar soluciones con una parcela diminuta.
- Desventajas: `N=200_032_000` produjo históricamente ~1,56 s/slot, distinto de 1 s; `SR=u64::MAX` favorece muchos candidatos y no representa una tasa de lanzamiento. El test de una parcela no calibra una red de tres productores. No resuelve controlador, retarget, inyecciones ni flujo posterior a la primera ventana.
- Descripción: fijar **solo para `zx-dag-dev` y el primer hijo** `N_dev=200_032_000` (múltiplo de 16), `D_dev=0` ya existente y `SR_dev=u64::MAX`. El contexto de primer hijo admite como máximo los 150 slots desde G permitidos por el formato y declara que en esa ventana dev no hay inyecciones; fuera de ella devuelve falta de contexto, nunca extrapola. La salida del slot 0 viene exclusivamente del bootstrap congelado. El rango esperado se obtiene de este perfil y no de la cabecera candidata. No cambiar el literal `SR_DEV` del hash de G para esta preparación: G es el ancla excepcional del perfil dev; el rango del primer bloque ordinario es una entrada dev independiente y explícita.

**Opción B · Calibrar primero PoT y rango para la tasa objetivo**

- Ventajas: se puede acercar la cadencia y la tasa de bloques deseadas antes de conectar nodos.
- Desventajas: el coste real depende de tres parcelas/identidades, prueba de espacio, concurrencia, transporte y admisión que todavía no están conectados; ajustar dos números desde una simulación local repetiría el error que la 0.0.1 pretende resolver.
- Descripción: retrasar el primer hijo hasta crear parcelas distintas y medir una distribución de distancias y tiempos de producción bajo carga, luego fijar un perfil de red dev con esos datos.

**Elección PROVISIONAL del líder: A solo para la preparación del primer hijo dev.** Los valores no se exportan a mainnet/testnet ni se convierten en norma de consenso; la red de tres nodos tendrá que medir y, si procede, cambiar el perfil antes de afirmar tasas representativas. La elección es reversible en un módulo de perfil/contexto dev y sus tests; no toca `SPEC.md`, el génesis congelado ni reglas de lanzamiento. Ninguna cabecera se admitirá por esta decisión aislada: faltan contexto de pieza común, reloj y presupuesto operativos, sello, cuerpo, UTXO y publicación atómica.

## DECISIÓN PROVISIONAL · HISTORIA-DAG-DEV

**Piezas bloqueadas:** A3/D2 y el primer bloque dev verificable por PoAS.

**Descripción:** el test D1 `farmer_disco.rs` ya usa `Archiver` y `plot_sector` reales con un `RecordedHistorySegment` determinista, pero su `Fondo` privado no puede alimentar ni al productor ni al verificador del nodo. A1 exige siempre `PieceCheckParams` con compromiso de segmento procedente de historia coherente; un compromiso arbitrario o tomado del candidato produciría una falsa aceptación o rechazos ambiguos. La historia inicial de mainnet/testnet y su disponibilidad siguen sin fijarse, así que este paso solo puede crear una fuente dev explícita.

**Opción A · Extraer el historial determinista de D1 a un módulo dev compartido**

- Ventajas: productor, verificador y pruebas usan el mismo segmento archivado por upstream, el mismo `FarmerProtocolInfo` y los mismos parámetros de pieza; permite congelar y cotejar un compromiso para detectar divergencias entre procesos. Reutiliza el fixture ya probado.
- Desventajas: genera ~130 MB de entrada determinista para archivar el segmento y plotea sectores pequeños; es caro para el arranque local y no representa un archivo de red. Congelar un compromiso no demuestra disponibilidad de historia en red ni constituye una regla de lanzamiento.
- Descripción: mover la construcción determinista y los valores de desarrollo del fixture D1 a un módulo `zx-node` disponible solo con `feature=farmer`, exponer un objeto inmutable con el `NewArchivedSegment`, parámetros de ploteo y `PieceCheckParams`, y comparar el compromiso contra un literal congelado obtenido de una ejecución reproducible. El nodo dev podrá plotear claves distintas contra ese mismo archivo; este incremento no activa aún el binario.

**Opción B · Cada productor aporta su propio contexto de pieza**

- Ventajas: menor refactor inicial del test.
- Desventajas: dos nodos podrían aceptar soluciones contra historias/compromisos distintos y la red local mediría una configuración incoherente; el candidato podría influir en el contexto si se tomara de su parcela sin una fuente común.
- Descripción: mantener `Fondo` privado y pasar manualmente `PieceCheckParams` en cada llamada de productor/verificador, sin identidad congelada común.

**Elección PROVISIONAL del líder: A, solo para desarrollo local.** El compromiso congelado y la receta del archivo serán datos de fixture, no compromiso de génesis ni norma de mainnet/testnet. La decisión es reversible en un módulo dev, la extracción del test `farmer_disco.rs` y sus pruebas; no toca el clon Autonomys ni el SPEC. Antes de conectar tres nodos hay que comprobar que cada proceso obtiene el mismo compromiso y que claves de parcela distintas producen soluciones válidas bajo el mismo contexto. Ningún bloque se admite por tener este objeto: A3, cuerpo, reloj y publicación siguen pendientes.

## DECISIÓN PROVISIONAL · COINBASE-CERO-PRIMER-HIJO-DEV

**Piezas bloqueadas:** D2, B1/B3 y primer cuerpo DAG dev coherente con su cabecera.

**Descripción:** la prueba de la puerta A3 ya combina PoT de carga completa, PoAS y sello reales, pero usa cuerpo vacío y compromisos marcadores. La 0.0.1 quiere medir DAG/PoST con bloques reales. `C-BLK-07` exige coinbase, `C-EMIT-04` exige `expiry_height=height`, y `C-EMIT-03` permite que la coinbase cobre menos que el subsidio más fees. El controlador de emisión/mediana de bloque aún no está conectado al DAG; fabricar un subsidio esperado o validar el cuerpo lineal como si fuera DAG daría falsa validez.

**Opción A · Coinbase dev de valor cero y compromisos reales**

- Ventajas: es un subcaso permitido por `Σ salidas ≤ subsidio + fees`, siempre que el subsidio sea no negativo; ejercita txid, Merkle, `body_commitment`, ubicación y unicidad de coinbase, y aplicación UTXO sin elegir mediana de lanzamiento. Reutiliza primitivas ya escritas.
- Desventajas: no mide emisión ni incentivos, no paga a productores y no cierra la validación económica completa. Requiere impedir que el verificador parcial se presente como admisión.
- Descripción: un módulo exclusivo del primer hijo `zx-dag-dev` construye una única coinbase sin entradas, con una salida cero a la clave del productor, `expiry_height=1`, testigos vacíos y compromisos calculados por `zx-core`; un comprobador limitado a ese perfil exige la misma forma y llama a `comprobar_compromisos_cuerpo_dag`. No acepta transacciones de usuario ni recompensa positiva.

**Opción B · Subsidio completo desde el primer bloque dev**

- Ventajas: prueba antes la ruta económica que se necesitará al cerrar B3/D2.
- Desventajas: depende de mediana efectiva, `emitido(H)`, penalización y límite de peso DAG aún sin fuente causal; elegirlos ahora como si fueran consenso de lanzamiento inventaría parámetros o conectaría un validador lineal fuera de su contrato.
- Descripción: retrasar el primer cuerpo verificable hasta integrar las entradas económicas en el pasado DAG validado y calcular el subsidio exacto.

**Elección PROVISIONAL del líder: A para `zx-dag-dev` y el primer hijo `{G}` exclusivamente.** El valor cero es un **cobro voluntariamente inferior**, no un subsidio de consenso ni una exención de `C-EMIT-03`; el cierre de D2/B3 exigirá la ruta económica completa antes de llamar válido a un bloque. Se revierte modificando solo el módulo dev de coinbase/cuerpo y sus tests, y pasando al constructor económico cuando el contexto causal exista; no cambia `SPEC.md`, génesis ni redes de lanzamiento. El resultado de cuerpo básico tampoco cubre timestamps, autorizaciones, peso dinámico, orden DAG, firma D3 ni admisión atómica.

## DECISIÓN PROVISIONAL · ALTA-FIRMANTE-DAG-DEV

**Piezas bloqueadas:** D3/D2 y el primer bloque firmado del perfil `zx-dag-dev`.

**Hallazgo:** `Registro::abrir(ruta, 0, 150)` crea un registro ausente en abstención hasta el slot 150 inclusive; su primera firma posible es la del 151. El primer hijo `{G}` solo admite `slot=1..150` por `C-HDR-07` y el perfil dev. El prototipo de `P-FIRMANTE` distinguía explícitamente una primera instalación sin historia mediante `Registro::nueva`, pero la implementación de `crates/` no expone esa vía. La pérdida de un registro y una primera instalación son indistinguibles si solo se mira si el fichero existe. Esto es un bloqueo real de arranque, no un motivo para reducir `S_max`.

**Opción A · Alta vinculada a una clave nueva, generada y guardada por el nodo.** Crear una identidad de productor nueva dentro de una operación de aprovisionamiento; persistir la clave con permisos restrictivos y sincronización antes de crear un registro inicialmente sin abstención, también sincronizado. Si la clave ya existe y falta el registro, el reinicio usa exclusivamente `Registro::abrir` y se abstiene durante `S_max`; un fallo a mitad del alta debe fallar cerrado o recuperar por la ruta conservadora. El registro sin abstención solo se crea para una clave generada dentro de esa operación, nunca a partir de una clave importada por el llamante. Ventaja: permite el primer hijo con registro y conserva la semántica de pérdida. Costes: manejo durable de la clave, exclusión entre procesos y pruebas de cortes en cada fase; una clave copiada a otro directorio queda fuera del filtro local ya declarado por `P-FIRMANTE` §3.4.

**Opción B · Conservar solo `Registro::abrir`.** Ventaja: no añade una API que pueda invocarse mal. Coste: un nodo nuevo no puede producir el primer hijo desde G bajo el perfil actual, aunque puede verificarlo si lo produjo otro nodo con una identidad aprovisionada de otra forma.

**Elección PROVISIONAL del líder: A, solo para el productor dev y pendiente de implementación.** El alta debe demostrar por código y pruebas la secuencia clave nueva → persistencia durable → registro nuevo → firma, y la ruta de reinicio con registro ausente debe abstenerse. Hasta tenerla, D3 no se conecta a D2 y ninguna prueba de firma directa se presenta como producción. No cambia `S_max=150`, `SPEC.md` ni la política de pérdida del registro. Es reversible retirando el módulo de aprovisionamiento dev y su uso en D2.
