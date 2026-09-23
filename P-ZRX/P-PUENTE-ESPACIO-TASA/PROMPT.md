=== INICIO DEL PROMPT PARA DEEPSEEK ===

# Encargo P-PUENTE-ESPACIO-TASA: medir el puente espacio → tasa en ZEROX

Trabaja en `/home/katana/zeo/ZEROX`. El objetivo es responder, con datos y límites explícitos:

> Dada una capacidad *nominal* de parcelas PoAS, ¿cuántos chunks se auditan, cuántos candidatos aparecen, cuántas pruebas verifican y qué tasa de peso puede justificarse por slot?

**No presupongas que una fracción de bytes físicos equivale a la misma fracción de oportunidades, bloques o `blue_work`.** Tampoco afirmes que la cadena demuestra cuántos bytes conserva un granjero: el formato actual no acredita la preexistencia de la parcela completa.

## 1. Lectura y preservación

Antes de editar, lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `research/README.md`, las secciones aplicables de `SPEC.md` —en particular C-HDR-06, §7.1, C-FLU-13/14 y C-GD-01/08— y **todo** `veritas/LINEO.md`.

Lee además:

- `P-ZRX/P-CRP/auditoria/DEFECTOS.md`, defecto C1;
- `P-ZRX/P-PRESTAMO/investigacion/INFORME.md`, advertencia inicial e hipótesis H-PUENTE;
- `P-ZRX/P-PUERTA/veritas/consenso/puerta-cobertura-v1/MODELO.md` y `src/peso.jl`;
- `P-ZRX/P-INTENTO/investigacion/INFORME.md`, especialmente la distribución de ocupación y §11;
- `P-ZRX/P-COBERTURA/investigacion/INFORME.md`, límite de preexistencia.

Contrasta las reglas PoAS con la copia local de Autonomys en `PDF/autonomys-subspace/`, especialmente `subspace-farmer-components/src/{sector,auditing,proving}.rs`, `subspace-core-primitives/src/{solutions,pieces,sectors}.rs` y `subspace-verification/src/lib.rs`. Fija en el informe la revisión o huella exacta de las fuentes utilizadas. No adoptes parámetros de la red Autonomys como parámetros de ZEROX.

Registra `git status --short` al inicio. El árbol tiene cambios ajenos: consérvalos. Escribe únicamente en un instrumento nuevo bajo `veritas/seguridad/espacio-tasa-v1/`. No modifiques `SPEC.md`, `TAREAS.md`, `crates/`, `PDF/`, instrumentos anteriores ni los directorios de `P-ZRX/`, incluido este prompt. No uses Python. Para este protocolo complejo, usa revisiones independientes de matemáticas y de Rust/Julia si tu entorno permite especialistas; si no, declara esa limitación y realiza controles adversariales separados. El autor principal debe contrastar las fuentes por sí mismo.

## 2. Pregunta y fronteras del instrumento

Separa estas magnitudes, con unidades y denominadores explícitos:

`bytes nominales de parcelas → sectores y piezas → chunks auditados/slot → candidatos ganadores → pruebas PoAS verificadas → bloques admisibles → bloques azules → blue_work/slot`

Distingue también bloques **pagables** de bloques **azules**; no los iguales por comodidad. Informa por separado las fracciones `α_bytes`, `α_candidatos` y `α_blue_work`.

El instrumento debe entregar una primera medición válida de las etapas que **sí** pueden observarse hoy. Si las etapas de admisión PoST+DAG, retarget causal o red no están implementadas, márcalas `pendiente` o `condicionada`; no las sustituyas por `η=1`, por un `SR` aceptado sin contexto ni por un bloque sintético presentado como válido. `AlmacenGhostdag::admitir` es una puerta parcial del rango, no validación PoST completa. `zx-node` sigue lineal.

## 3. Modelo y experimentos

Antes de programar, escribe las hipótesis y la complejidad del método. Como control analítico —no como respuesta final— reproduce en enteros exactos:

- `A(SR) = 2·floor(SR/2)+1`, cardinal de valores a distancia circular admisible;
- `p(SR) = A(SR)/2^64` por **chunk efectivamente auditado**, bajo reto uniforme;
- `w(SR) = floor(2^128/(SR+1))`;
- `E[candidatos/slot] = P·p(SR)` para `P` ensayos efectivos bajo las hipótesis declaradas.

La tarea central es medir cómo se llega desde los bytes de sector hasta `P`. Usa el tamaño **real de sector con sus metadatos**, no `Piece::SIZE` como sustituto de bytes físicos. Mide ocupación por bucket, no solo su media: P-INTENTO encontró media 0,5 en su muestra, pero una distribución desigual. Registra sectores vacíos o parciales, piezas por sector, chunks leídos y candidatos por reto.

Ejecuta escenarios con retos y semillas reproducibles y con varios tamaños de parcela y valores de `SR`. Los valores de `SR` del barrido son **escenarios experimentales**, no decisiones de consenso. Incluye extremos y paridad en tests; selecciona escenarios adicionales capaces de observar eventos dentro del presupuesto. Para sucesos demasiado raros, usa el cálculo exacto y presenta una cota estadística honesta; no conviertas `0/n` en probabilidad cero.

Mide asimismo, con los **mismos bytes nominales**:

1. un flujo;
2. dos retos/flujos divergentes auditados con la misma parcela;
3. espacio repartido exclusivamente entre dos flujos.

Publica la correlación y el solapamiento de oportunidades entre ambos retos. No supongas independencia para calcular `Pr(≥1 ganador)`, varianza o colas. Compara adversario y honestos bajo el mismo `SR`, ventana, capacidad y restricciones de hardware. Mantén separado el atacante que regenera piezas tras conocer el reto: CPU equivalente **no** son bytes almacenados.

Si mides rendimiento de disco, identifica el sistema de archivos y comprueba que no estás midiendo un `tmpfs` o solo caché. Registra lecturas, IOPS, CPU, latencias y saturación; no extrapoles una máquina al adversario universal.

## 4. Oráculos y pruebas obligatorias

Crea una referencia matemática pequeña e independiente y contrástala con la lógica Rust PoAS fijada. Reutiliza el código criptográfico upstream; no reimplementes primitivas. Si la fuente Rust local no puede compilarse o no permite generar sectores reales dentro del presupuesto, conserva un caso mínimo reproducible, explica el bloqueo y rebaja el alcance de los resultados. No llames «verificada» a una solución si no pasó el verificador completo que afirmas usar.

Incluye pruebas para:

- distancia circular, punto opuesto, bordes `SR=0,1,2,3,u64::MAX−1,u64::MAX` y efecto de paridad;
- cardinalidad exhaustiva en un círculo pequeño frente a la fórmula;
- orden de bytes y derivación del bucket frente a Rust;
- bucket vacío, ocupación desigual y, para una pieza y un reto, como máximo un chunk en el bucket seleccionado;
- cero, uno y varios candidatos por sector;
- candidato ganador cuya prueba completa falla;
- reproducción idéntica con la misma parcela, reto y semilla;
- la misma parcela ante dos retos divergentes;
- referencia lenta frente al kernel optimizado y conservación de contadores en cada etapa.

Si se añade una capa DAG sintética, prueba aparte duplicados U2/U3 y azules/rojos, pero etiquétala **modelo condicional**, nunca medición de admisión real de ZEROX.

## 5. Resultados exigidos

No entregues solo código. Produce `INFORME.md`, hipótesis, procedencia, tests, benchmark y resultados legibles por máquina. Para cada cifra indica: valor, unidad, variable y denominador, versión del modelo, fuente, adversario, escenario, criterio de aceptación y estado (`medido`, `derivado`, `simulado`, `condicionado` o `pendiente`).

La tabla principal debe incluir, cuando proceda: bytes nominales, bytes realmente ocupados por los archivos de prueba, sectores, piezas, chunks auditados/slot, candidatos/slot y por TiB, pruebas válidas/slot, tasa de éxito, media, dispersión, cuantiles o cotas, intervalos de incertidumbre, coste de auditoría, y resultados pareados de uno frente a dos flujos. Para `blue_work/slot`, entrega cifra **solo si** existe un camino validado que la sustente; en caso contrario muestra la fórmula condicional y el dato que falta.

Explica expresamente si el experimento confirma o refuta alguna proporcionalidad en el dominio ensayado. **No declares un umbral de seguridad físico, una tasa real de la red ZEROX ni resuelto el doble farmeo** con un instrumento que solo mide candidatos PoAS.

## 6. Verificación y presupuesto

Usa un proyecto Julia aislado y reproducible creado conforme a `veritas/LINEO.md`. Puedes añadir un pequeño oráculo o colector Rust **dentro del nuevo instrumento** si sirve para contrastar la implementación upstream; mantenlo separado del código de consenso. Ejecuta sus tests, equivalencia referencia↔kernel, perfil y benchmark, y `git diff --check`. Publica comandos, semillas, versión de Julia/Rust, `Manifest.toml`, hardware y resultados reales. Verifica al final que ningún archivo ajeno al nuevo instrumento cambió por este encargo.

Declara **antes** de correr el presupuesto de tiempo, RAM, hilos y disco. Respeta los topes de LINEO —máximo 24 hilos y 64 GiB— y usa menos si basta. Si el presupuesto no alcanza para la precisión buscada, entrega los datos obtenidos, el intervalo o cota correspondiente y el bloqueo; no fabriques una conclusión.

## Instrucción obligatoria de Veritas

Eres especialista senior en Julia para cómputo científico reproducible, teoría de protocolos y optimización de alto rendimiento. Antes de escribir o modificar código, lee por completo `veritas/LINEO.md` y cumple todas sus reglas.

Tu prioridad conjunta es: **(1) resultado matemáticamente verdadero y reproducible; (2) el máximo rendimiento medido compatible con esa verdad.** No aceptes un programa lento sin un perfil, ni una aceleración sin una prueba contra un oráculo independiente.

Procedimiento obligatorio:

1. Formula el modelo matemático, la complejidad temporal/espacial y el adversario/caso de borde relevante antes de elegir la estructura de datos.
2. Diseña la representación para la operación dominante: tipos concretos, arrays contiguos, SoA frente a AoS, IDs densos, `BitVector`/CSR/`StaticArrays`/`Dict` solo cuando el caso lo justifique. Explica brevemente la elección.
3. Escribe primero una referencia pequeña, transparente y preferiblemente exacta; crea tests de bordes, invariantes, contraejemplos previos y semillas fijas.
4. Implementa el kernel rápido dentro de funciones tipoestables, sin globals dinámicos ni `Any`. Preasigna memoria, usa versiones mutantes (`!`), evita asignaciones y respeta el orden de columnas.
5. Valida el kernel rápido contra la referencia en instancias pequeñas, propiedades aleatorias y todos los vectores de regresión. Para umbrales numéricos, certifica con exactitud, intervalos o aritmética de bolas; si el margen no se puede certificar, declara el resultado inconcluso.
6. Mide el caso representativo tras calentar JIT con `BenchmarkTools`; perfila CPU/memoria con `Profile`, `@allocated`, `@code_warntype` y JET. Optimiza el cuello real, no el supuesto.
7. Paraleliza solo trabajo independiente y usa RNG por réplica/chunk, reducción determinista y ausencia demostrada de carreras. Arranca batch CPU-bound dentro del tope de 24 hilos (8 lógicos quedan para el sistema), mide el escalado `1…24` y conserva la configuración que gane realmente, aunque use menos hilos; evita BLAS anidado.
8. Considera `LoopVectorization` o MPI únicamente si el perfil demuestra un kernel regular dominante y el coste no lo anula. Para GPU **no uses Julia**: escribe el kernel en C++/CUDA (§5.7), con oráculo CPU estricto, transferencias medidas y `compute-sanitizer`. Compara siempre con CPU estricta.
9. No uses `@fastmath`. `@inbounds`, `@simd`, `@turbo` o precisión `Float32` requieren prueba de equivalencia, comentario de supuestos y benchmark. Nunca dejes que una optimización cambie un veredicto sin declararlo.
10. Entrega `Project.toml`, `Manifest.toml`, comando exacto, semilla, versión/hardware, tabla de rendimiento, número de asignaciones y resultado de la validación. Distingue con claridad lo demostrado, medido, estimado y no demostrado.
11. Declara antes de ejecutar el presupuesto de tiempo, memoria y disco (en la máquina de referencia: máximo 64 GiB de RAM y 24 hilos). Si se agota, conserva el checkpoint y reporta **inconcluso**; guarda semilla, parámetros, configuración y una entrada mínima reproducible para cada fallo. No confundas timeout con evidencia de falsedad.

Si una corrida supera el presupuesto declarado, detente antes de ampliar la exploración y produce un perfil más una hipótesis de cuello de botella. Propón la mejora algorítmica o de datos de mayor impacto y verifica que conserva resultados antes de lanzar otra corrida larga.

=== FIN DEL PROMPT PARA DEEPSEEK ===
