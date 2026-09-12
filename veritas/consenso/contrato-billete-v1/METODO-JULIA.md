# Método Julia M0

Modelo y alcance: CONTRATO.md CBE-v0.1. IDs opacos UInt64 dispersos, colores/orden/cuerpos
proporcionados; ninguna prueba criptográfica o regla GHOSTDAG se calcula aquí. Referencia
independiente por agrupación y búsquedas lineales, sumas BigInt con comprobación final UInt64.
Kernel por mapas tipados, selección de representantes y ejecución en su rank original; sumas
checked UInt64. No se comparten helpers de selección ni preflight entre ambos motores.

Coste de referencia: cuadrático en bloques/transacciones más búsquedas sobre estado heredado.
Kernel: tiempo esperado O(n log n + tx + estado), espacio O(n + tx + estado), condicionado a
operaciones hash usuales. Los IDs son dispersos: no se asignan arrays de tamaño max(ID).
AoS conserva los campos consumidos juntos. Copias privadas de estado son deliberadas para
publicación all-or-nothing; no son un motor persistente optimizado ni un benchmark del nodo.

La validación incluye fixtures compartidos, oráculo independiente, permutaciones, invariantes,
overflow, Pending/Invalid, undo protegido y preparación atómica de cambio de rama. El ledger
Julia guarda la proyección representante/contexto/slot y agregados; NO conserva el diario
individual completo de subsidios/comisiones que contiene el instrumento Rust. La equivalencia
entre lenguajes se limita a la proyección declarada en EXPECT, no a todo estado interno Rust.

Recursos: un hilo Julia, cero interactivos, BLAS uno, máximo 4 GiB de RAM y 2 GiB de disco del
proyecto. Etapa original de 12 minutos fue interrumpida por 452 s de espera de aprobación; el
principal autorizó explícitamente una nueva etapa hasta 11:15 UTC (2026-09-11). Un timeout no
refuta el contrato. Sin Python, SIMD, fastmath, GPU ni paralelización: transición secuencial
finita de lote, no búsqueda larga; un hilo es el perfil de esta fase. No se reclama optimalidad.

Benchmark: 180 bloques sintéticos, W_adm=10, estado inicial vacío, semilla CLI; referencia y
kernel sobre la misma entrada tras calentamiento. Profile, allocated, code_warntype y JET
generan artefactos en resultados/. Las asignaciones del staging y mapas se miden, no se esconden.
No hay conversión de estos microsegundos a tiempo de aceptación Cortex ni riesgo de pago.

La primera variante tipada y sus artefactos se conservan en resultados/baseline/. Su rapido.jl
es la fuente anterior a las reservas sizehint! guiadas por el perfil. Para reproducir esa variante,
copiar el proyecto a otro directorio y sustituir allí src/rapido.jl por ese archivo; no sobrescribir
la fuente activa ni mezclar outputs de ambas variantes. La reserva de capacidad es un único
experimento de rendimiento, no una modificación de elegibilidad, comprobaciones o aritmética.

Ese intento no se conserva en el kernel activo: en la comparación realizada pasó de 17 870 ns
a 21 754,5 ns de mediana, aunque bajó de 93 496 B/121 asignaciones a 72 088 B/81 asignaciones.
El criterio prioriza latencia medida de la transición completa, no sólo reducir asignaciones.
Su fuente y artefactos quedan en resultados/intento-reserva/. Es evidencia de esa entrada y
corrida, no una refutación universal de preasignar. No se ensayó una segunda optimización.
La copia privada y los mapas de la variante conservada tienen coste de asignación conocido;
se mantiene para esta fase tras comparar la mejora guiada por perfil, sin afirmar optimalidad.

Comandos (desde raíz, usando caché local Julia con permisos apropiados):

```sh
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/contrato-billete-v1 --check-bounds=yes veritas/consenso/contrato-billete-v1/run.jl --seed 20260911
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/contrato-billete-v1 veritas/consenso/contrato-billete-v1/bench/benchmarks.jl --seed 20260911
```

Project.toml mínimo procede de la plantilla obligatoria; BenchmarkTools, JET y StableRNGs.
Manifest.toml resuelto y conservado por el principal; julia-version.toml fija 1.13.0. Las corridas
registraron un hilo default y cero interactivos. El principal ejecutó la validación y benchmark;
INFORME.md registra resultados efectivos. La primera llamada cronometrada dentro de benchmain
NO mide toda la compilación de ese método ni el arranque del proceso: no se presenta como TTFX.
