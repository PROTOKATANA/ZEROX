# Informe — contrato de billete CBE-v0.1

Fecha: 2026-09-11. Categoría: `consenso`, porque se evalúa la transición de aceptación,
consumo y contabilidad, no una cota de finalidad.

## Resultado y alcance

Se ha escrito el [contrato candidato](CONTRATO.md) autorizado por el usuario y un modelo
abstracto M0 para contrastar Rust y Julia. **No está activado en el nodo.** El candidato
principal sigue siendo P0: primera copia elegible en orden canónico, un derecho económico
y un cuerpo ejecutable por identidad e historia. P1 conserva prioridad azul dentro del
lote como comparación legítima; ninguna política reemplaza consumos del prefijo heredado.

El contrato fija semántica suficiente para probar transiciones. No certifica todavía la
identidad criptográfica del billete, la derivación del orden DAG, disponibilidad adversarial,
el retarget completo ni una espera menor para Cortex. La investigación del ancla PoT sigue
separada. No hay un nuevo valor de segundos, riesgo, tasa o k avalado por esta entrega.

## Decisiones explícitas, sin activarlas como reglas de producción

| Tema | Perfil evaluado | Coste o límite |
|---|---|---|
| Identidad | TicketId opaco con equivalencia económica exigida por CBE-01 | La tupla concreta y su vínculo con pruebas alternativas siguen pendientes. |
| Disponibilidad DA0 | Esperar todos los cuerpos nuevos del lote; ausencia no significa invalidez | Incluso una copia perdedora retenida puede mantener el candidato pendiente. |
| Primera elegible P0 | Elegir por orden fijo, sin depender de llegada ni éxito de sus transacciones | Una roja anterior puede consumir el derecho de una azul posterior. |
| Comparador P1 | Azul primero sólo dentro del lote; ejecutar en la posición propia de la ganadora | Puede cambiar cuerpos aceptados; no demuestra ser superior a P0. |
| Tardíos L0 | Ventana común para subsidio, observación y ejecución; fuera de ella, cuerpo inerte | Excluye oportunidades honestas demoradas y requiere reinclusión de sus transacciones. |
| Consumo | También con subsidio cero, cuerpo vacío o todos los gastos en conflicto | No permite reintentar con otra copia para obtener un resultado de ejecución mejor. |
| Estado | Preparación privada, publicación conjunta, undo contextual y cambio de rama transaccional | M0 usa memoria; no valida recuperación de disco ni aislamiento de lectores reales. |

L0 y DA0 son decisiones **del perfil de evaluación**, no recomendaciones ya demostradas para
producción. La alternativa de ejecutar tardíos sin subsidio se reserva para otra comparación;
no se incluye silenciosamente. Validar un cuerpo inerte no equivale a ejecutar sus transacciones.

## Procedencia de parámetros e hipótesis

| Entrada o magnitud | Estado y unidad | Procedencia / significado |
|---|---|---|
| CBE-v0.1, P0/P1, DA0, L0 | Elegidos; reglas discretas | Este contrato y la autorización del usuario. |
| TicketId, IDs de bloque/contexto/transacción | Sintéticos UInt64 positivos | Etiquetas de fixtures; no hashes ni claves de consenso desplegables. |
| Rank y color B/R/U | Suministrados por oráculo | No calculados por GHOSTDAG ni derivados de llegadas. |
| V/P/I | Suministrados por oráculo | Resultado supuesto de disponibilidad/validación, no implementación del verificador. |
| Slot y W_adm | Elegidos; slots enteros | Casos de borde reproducibles; W_adm no se importa de Chia/Autonomys ni se identifica con F o S_max. |
| Subsidio y fee | Elegidos; unidades enteras abstractas | Pruebas de sumas/conflictos; no unidades monetarias ni coinbase de producción. |
| Conteo M0 | Derivado; adjudicaciones acumuladas | No es N_obs de una ventana ni peso azul. |
| UInt64::MAX | Derivado del dominio; 18 446 744 073 709 551 615 | Borde de overflow, no parámetro económico. |
| 35 casos / 49 EXPECT | Derivados del archivo compartido | Número de escenarios y puntos de observación, no probabilidades ni cobertura total. |
| Riesgo ε, α, retardo Δ, tasa λ, k, velocidad PoT | No utilizados aquí | Pendientes del modelo integrado y de su procedencia validada. |

No se han reutilizado cifras PoW ni transferido constantes upstream al DAG. Los contraejemplos
de M0 son entradas del dominio abstracto: no se presentan como ataques criptográficamente
construidos contra el nodo completo. Las conclusiones de fuentes previas y sus límites están
en [identidad-copias](../identidad-copias/INFORME.md).

## Argumento de unicidad, condicionado al contrato

Sea U el conjunto de identidades consumidas en un prefijo válido. Para cada lote completo,
P0 y P1 eligen como máximo un representante por identidad fuera de U. Se ejecutan únicamente
esos representantes y se publica U unido a sus identidades. Por inducción desde U vacío,
ninguna identidad ejecuta dos cuerpos ni genera dos eventos en una misma historia aplicada.
El argumento no depende del importe del subsidio ni del número de transacciones aceptadas.

Si el conteo empieza en cero, no se podan consumos y cada incorporación suma uno, el conteo
acumulado coincide con el número de identidades consumidas. Las sumas son comprobadas: un
overflow no publica transición. Un undo exacto restaura la hipótesis del prefijo; preparar una
rama alternativa privadamente no duplica efectos visibles si sólo se publica al terminar.

Esto presupone identidad, lote, orden, elegibilidad y estado previo correctos. No demuestra
que dos nodos obtengan esos mismos insumos, que un atacante no bloquee su disponibilidad ni
que el controlador permanezca estable. Tampoco convierte una reorganización permitida en
imposible: la unicidad en cada historia no es finalidad entre historias.

## Verificación y correcciones independientes

Participaron especialistas de Rust, matemáticas/Julia y C++/sistemas. Se consultó íntegramente
[LINEO](../../LINEO.md); no se crearon ni ejecutaron auditorías Python. No se añadió C++/CUDA
porque no hay una carga GPU justificada. El especialista de sistemas hizo revisión estática,
no certificó ejecuciones que no realizó.

El [modelo Rust](../../../crates/zx-consensus/tests/contrato_billete_modelo.rs) se limita a tests.
La [revisión independiente](REVISION.md) conserva los hallazgos y su resolución; no oculta las
correcciones. Detectó dos omisiones compartidas por las primeras funciones Julia: historial de
contextos activos y vinculación de txid a contenido dentro de un lote. Se añadieron regresiones
compartidas para impedir que dos implementaciones coincidan simplemente por omitir lo mismo.

| Comprobación | Resultado registrado |
|---|---|
| Rust, test de integración del modelo | 14 tests pasan; los 49 EXPECT compartidos coinciden. |
| Rust, clippy del test con advertencias como error | Pasa. |
| Rust, formato del archivo | Pasa. |
| Regresión Ed25519 conservada | 1 test pasa: dos firmas distintas del propietario verifican el mismo mensaje. No es falsificación por terceros. |
| Julia, oráculo exacto y kernel tipado | 9.024 aserciones pasan: 500 lotes aleatorios reproducibles bajo P0/P1, permutaciones, invariantes y bordes adicionales. |
| Julia, vectores compartidos | 163 aserciones pasan, incluidos los mismos 49 EXPECT que Rust. |
| Julia, rollback y cambio de rama | Tests de undo incorrecto/estado alterado, rama alternativa y fallo Pending/Invalid tras aplicar privadamente un primer lote. |
| Julia, inferencia y perfil | JET sin errores detectados; retorno inferido Symbol; perfil y asignaciones conservados en resultados/. |

Los vectores incluyen cuerpos pendientes/ inválidos, perdedores y tardíos retenidos, P0/P1,
fusiones sucesivas, subsidio cero, conflicto transparente/blindado, límites de ventana,
orden de ejecución propio de P1, overflow, replay, undo, errores sobre prefijo aplicado y
reutilización de contextos. EXPECT compara la proyección definida por el contrato, no un
journal completo ni durabilidad. Las pruebas internas adicionales deben justificarse aparte.

Los resultados Julia se conservan en [validacion.txt](resultados/validacion.txt). No se cuenta
cada aserción como un escenario independiente ni se infiere una probabilidad de fallo de que
9.024 comprobaciones pasen. Los lotes aleatorios no simulan red, producción adversarial ni DAG
válido por construcción. La corrección del argumento condicional y la cobertura de tests son
formas de evidencia diferentes.

## Coste medido del instrumento, no del nodo

Se midió una entrada sintética fija: 180 bloques, estado inicial vacío, W_adm=10 slots,
semilla 20260911, P0; produjo 70 adjudicaciones y 16 transacciones aceptadas. BenchmarkTools
usa 100 muestras y una evaluación por muestra, después de calentar las funciones. El kernel
incluye creación de estado, validación M0, selección, conflictos y publicación en memoria;
no incluye descarga, criptografía, UTXO/Orchard real ni disco. El tamaño no representa una
carga de producción establecida.

| Implementación / corrida | Mediana por lote | Bytes asignados | Asignaciones |
|---|---:|---:|---:|
| Referencia exacta, búsquedas lineales/BigInt | 142,8125 µs | 1.096.032 | 3.204 |
| Kernel tipado inicial | 17,8700 µs | 93.496 | 121 |
| Referencia en la corrida con reservas | 138,4520 µs | 1.096.320 | 3.204 |
| Kernel con reservas anticipadas, no conservado | 21,7545 µs | 72.088 | 81 |
| Referencia en la comprobación final | 144,0025 µs | 1.096.608 | 3.204 |
| Kernel conservado, comprobación final | 17,1450 µs | 93.496 | 121 |

El perfil inicial contiene 234 muestras y señala asignación de memoria/crecimiento de tablas
hash como coste importante. Se probó una única reserva anticipada de capacidad (`sizehint!`):
redujo asignaciones pero la mediana de latencia empeoró en la corrida medida. **No se conservó
esa optimización.** Esto no refuta universalmente preasignar memoria: no justificó adoptarlo en
este instrumento y entrada. La referencia varía entre corridas; no se oculta esa variabilidad
ni se presenta una sola corrida como intervalo estadístico de rendimiento.
Se conservan fuentes y artefactos de [baseline](resultados/baseline/) y del
[intento descartado](resultados/intento-reserva/).
La corrida final tras restaurar la fuente inicial volvió a pasar 9.024 + 163 aserciones y
generó los [resultados conservados](resultados/rendimiento.txt). El proceso completo de benchmark,
incluidos arranque, análisis JET y perfilado, duró 9,26 s y alcanzó 726.608 KiB de RSS según
[GNU time](resultados/proceso-benchmark-final.txt); no confundirlo con 17,1450 µs por transición.
El archivo `resultados/proceso-benchmark.txt` corresponde al intento de reservas, no al kernel final.
El `Any` de la ruta de excepciones no se presenta como un retorno inestable;
JET no detecta errores, pero no demuestra corrección semántica. La primera llamada cronometrada
dentro de benchmain no mide todo el arranque/JIT: no debe etiquetarse como tiempo total de compilación.

Ni la comparación con el oráculo deliberadamente sencillo ni esos microsegundos demuestran
que ZEROX sea más rápido. Faltan estado heredado creciente, cargas adversariales, P1 en rendimiento,
coste de copias antes de deduplicar, I/O y medición extremo a extremo. No se deriva un tiempo de
aceptación para Cortex ni se justifica modificar tasa o k.

## Reproducción

Directorio de trabajo: raíz de ZEROX. HEAD durante la ejecución:
`7b783d469fbae5722a0ae014b5e212ed6999eb2b`, con worktree previamente modificado.
El hash HEAD por sí solo no identifica los archivos nuevos; conservar también contrato,
fixtures, fuentes y entorno de esta auditoría. No se han restaurado ni eliminado cambios ajenos.
Las [huellas SHA-256](HUELLAS.sha256) identifican los principales insumos comprobados.

Rust: `rustc 1.97.0-nightly (20de910db 2026-05-02)`;
`cargo 1.97.0-nightly (4f9b52075 2026-05-01)`.

```sh
cargo test -p zx-consensus --test contrato_billete_modelo -- --nocapture
cargo test -p zx-core --test ed25519_no_unicidad
cargo clippy -p zx-consensus --test contrato_billete_modelo -- -D warnings
rustfmt --edition 2024 --check crates/zx-consensus/tests/contrato_billete_modelo.rs
git diff --check
sha256sum -c veritas/consenso/contrato-billete-v1/HUELLAS.sha256
```

Julia ejecutado: 1.13.0; BenchmarkTools 1.8.0, JET 0.12.1, StableRNGs 1.0.4, versiones transitivas
en [Manifest.toml](Manifest.toml). CPU AMD Ryzen 9 9950X3D, 16 núcleos / 32 lógicos, un nodo NUMA;
`Sys.CPU_NAME=znver5`, RAM visible 132.497.408.000 bytes. La ejecución registra Julia 1/0
hilos de cómputo/interactivos, BLAS configurado a 1, OpenBLAS ILP64. Sin afinidad fijada.

```sh
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/contrato-billete-v1 -e 'using Pkg; Pkg.resolve()'
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/contrato-billete-v1 --check-bounds=yes veritas/consenso/contrato-billete-v1/run.jl --seed 20260911
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/contrato-billete-v1 veritas/consenso/contrato-billete-v1/bench/benchmarks.jl --seed 20260911
```

La medición final de proceso usó el último comando precedido de
`/usr/bin/time -v -o veritas/consenso/contrato-billete-v1/resultados/proceso-benchmark-final.txt`.

El entorno Julia está aislado mediante Project/Manifest y versión registrada. Se declararon para
esta evaluación 1 hilo de cómputo Julia, BLAS 1, techo 4 GiB RAM y 2 GiB de disco de auditoría.
El presupuesto inicial de preparación/ejecución terminaba a las 10:58:21 UTC; antes de agotarlo
se amplió hasta las 11:06 UTC para cerrar las regresiones concretas del cotejo. No se autoriza
con ello una búsqueda abierta ni un cambio de parámetros para obtener tests verdes.

La espera de aprobación de Pkg.resolve se interrumpió tras aproximadamente 452 s, sin haber
ejecutado validación. Las restricciones de escritura de la caché Julia se resolvieron mediante
permisos explícitos, no cambiando verificadores. Se abrió una etapa acotada hasta las 11:15 UTC
para ejecutar las correcciones y medir su coste. Resolve, tests y benchmark terminaron con
código 0. El estado transitorio sin ejecución no se confundió con un resultado favorable.
Las corridas finales concluyeron antes del cierre de esa etapa. No se exploraron más semillas,
ventanas ni ajustes para favorecer la optimización descartada.

## Siguiente puerta de decisión

Para integrar, cerrar primero TicketId/compromisos y disponibilidad/elegibilidad reales. Después
fijar ventana y retarget causal, y comprobar recuperación del estado completo. Comparar P0/P1
en las mismas trazas válidas y también en simulaciones con realimentación propia de cada variante.

El criterio Cortex debe medir reversión de un pago ya aceptado, bajo una política explícita de
riesgo y continuidad del observador. Debe incluir pagos nunca aceptados, tiempos censurados,
reinclusiones, exclusión honesta, colas y falta de progreso. Un benchmark de esta transición
no mide esa espera, ni el coste de verificar/propagar variantes antes de deduplicarlas.

**Dictamen de esta entrega:** contrato candidato explícito y validación estructural acotada;
no aprobación de producción ni demostración de mejora global o finalidad acelerada.
