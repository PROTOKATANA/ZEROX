# Informe DCM-v0.1 — revisión 2

Estado: **instrumento estructural evaluado; no regla de consenso**. Categoría consenso, con
disponibilidad/red y estado como áreas secundarias.

La revisión 2 corrige los lectores de fixtures, fija la política por vista, exige verdad contextual
explícita y elimina la recursión por profundidad del detector de ciclos Rust. También corrige la
presentación de unidades y precisa el alcance del resultado. La verificación de esta revisión se
registra separadamente de las ejecuciones originales.

## Registros originales y corrección de unidades

La suite original Julia CPU con comprobación de límites pasó 12 casos/118 aserciones internas del
fixture multivista y 48 aserciones Julia adicionales. El fixture cubre Ana/Bruno, recepción tardía,
partición/reunión, ramas/replay,
copia TicketId P0/P1, cono dependiente, tardío contextual, BodyInvalid y separación entre cuerpo
completo y validez por HistoryId. El modelo Rust aislado pasó entonces 3/3 tests.
Se conservan esos registros sin modificarlos en `resultados/TESTS.txt` y `resultados/RUN.txt`.

Medición original de revisión 1, `BenchmarkTools`, un hilo, 10 muestras, workload sintético.
Fuente: `resultados/BENCH.txt`; tiempos medidos convertidos exactamente de ns a µs:

| Perfil | Profundidad | Mediana | Bytes | Asignaciones |
|---|---:|---:|---:|---:|
| apply con snapshot completo | 16 | 49,269 µs | 318 128 | 3 957 |
| apply con snapshot completo | 32 | 176,4715 µs | 1 106 192 | 13 303 |
| apply con snapshot completo | 64 | 863,8585 µs | 4 756 680 | 48 120 |
| replay entre ramas | 16 | 133,7075 µs | 584 384 | 6 654 |
| replay entre ramas | 32 | 454,256 µs | 1 724 992 | 20 162 |
| replay entre ramas | 64 | 1 917,243 µs | 7 487 224 | 69 242 |

La última celda se publicó erróneamente como `1.917.243 µs`. El registro original contiene
`1917243.0 ns`: son **1 917,243 µs = 1,917243 ms**. La corrección afecta a la presentación del
informe, no al valor medido ni a parámetros económicos o temporales del protocolo.

El crecimiento es compatible con la advertencia Θ(H²): esta representación de undo no es un
kernel optimizado. Los valores no son rendimiento de nodo, cotas ni parámetros del protocolo.
El perfil original (`resultados/PERFIL.txt`) informó cero diagnósticos JET 0.12.1, ningún `Any`
en `code_warntype` y 13 840 bytes en el workload unitario, incluyendo una vista fresca.

## Verificación de revisión 2

La suite Julia con comprobación de límites pasa los mismos **12 casos/118 comprobaciones internas**
del fixture original, cuyo hash no cambió, y **14 237 aserciones fuera del fixture**. Estas últimas
incluyen las 48 previas y 14 189 nuevas; dentro de las nuevas están las **13 824 entradas** del
oráculo independiente de alcanzabilidad (512 grafos sobre tres bloques por 27 ubicaciones).
No son 13 824 ataques al destino: comprueban el predicado estructural del instrumento.
También se comprueba rollback completo si una reorganización de dos etapas termina Pending o Invalid.

Rust pasa **9/9 tests, ninguno ignorado**, incluyendo la cadena sintética de **50 000 bloques** que
agotaba la pila y el rechazo de su variante cíclica. El fixture conserva 12 casos y 59 directivas
comprobadas; el contador Julia registra dos comprobaciones por directiva para referencia y kernel.
Clippy estricto y rustfmt pasan. La revisión cruzada de lógica, parsers y APIs no detectó
bloqueantes dentro de las precondiciones declaradas. Comandos en `METODO.md`, resumen en
`resultados/TESTS-R2.txt` y entorno en `resultados/ENTORNO-R2.txt`.

Medición R2 posterior a las correcciones, mismo workload sintético de profundidad/replay,
BenchmarkTools con un hilo, diez muestras y una evaluación por muestra:

| Perfil | Profundidad | Mediana | Bytes | Asignaciones |
|---|---:|---:|---:|---:|
| apply con snapshot completo | 16 | 48,4495 µs | 318 128 | 3 957 |
| apply con snapshot completo | 32 | 177,1915 µs | 1 106 192 | 13 303 |
| apply con snapshot completo | 64 | 871,928 µs | 4 756 680 | 48 120 |
| replay entre ramas | 16 | 136,998 µs | 658 152 | 6 657 |
| replay entre ramas | 32 | 507,31 µs | 2 019 944 | 20 165 |
| replay entre ramas | 64 | 2 158,709 µs | 8 666 912 | 69 245 |

Fuente: `resultados/BENCH-R2.txt`, valores medidos en ns y convertidos exactamente a µs. La
preparación del catálogo/vista queda fuera de la medición. Replay incluye la copia privada del
mapa de verdad contextual, ahora explícito, por lo que su representación difiere de R1. Esta
comparación de coste no es una comparación DA0/DA1 ni una nueva calibración del protocolo.

El perfil R2 (`resultados/PERFIL-R2.txt`) informa **cero diagnósticos JET**, ningún `Any` en
`code_warntype` y 14 144 bytes asignados en la aplicación unitaria incluyendo una vista fresca.
Ese perfil examina `apply_fast!`; no acredita por sí solo todos los caminos del programa.

## Correcciones y alcance

- Los lectores rechazan CASE mal delimitados, cambios tras congelación, aridades incorrectas y
  componentes sobrantes/vacíos o duplicados en expectativas.
- La política se fija al construir la vista y forma parte de su comparación. Otra política causa
  `PolicyMismatch` local sin tocar estado, undo, Pending ni evidencia, incluso tras volver a génesis.
- Julia y Rust requieren el par `(H,B)` explícito para registrar evidencia contextual; la ausencia
  no se interpreta como validez. INVALID/REJECT tampoco dejan estados auxiliares contradictorios.
- La DFS recursiva Rust se sustituye por detección iterativa de ciclos. Se conserva una regresión
  de profundidad sintética; no se afirma que ese lote cumpla los límites del DAG destino.
- Se aclaran los dominios de cero, la política común e inmutable y las etiquetas rank/color
  globales suministradas. El oráculo de contexto no verifica UTXO ni nullifiers reales.

Resultado admisible: las pruebas contrastan selección y transición bajo HistorySpec objetiva,
catálogo y política fijos y evidencia suministrada. No eliminan el bloqueo de un ganador ni de una
HistorySpec atómica, no demuestran independencia UTXO/nullifier, no derivan GHOSTDAG/blue_work ni convierten
Applied en finalidad. Retarget, coste de red, eclipse y header-only sin peso quedan Pending.

Los casos examinados corroboran que el tiempo/orden local de recepción no determina el estado
lógico final al reproducir la misma historia con catálogo, política y evidencia comunes.
La igualdad comprobada es de proyecciones lógicas, no una prueba de serialización binaria ni de
acuerdo de red. `Inert` permanece contextual a `(H,W,B)`. No queda cerrado DA1: un ganador pendiente aún bloquea
la HistorySpec atómica y la influencia de header-only sobre GHOSTDAG sigue sin regla integrada.
C++/CUDA no se justifican para este control pequeño e irregular.
