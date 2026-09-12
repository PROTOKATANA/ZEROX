# Método reproducible ARM-v0.1

Desde la raíz del repositorio. Julia CPU, un hilo y BLAS un hilo; semilla obligatoria
20260911 como etiqueta de corrida. Los vectores son deterministas y no usan RNG.
Presupuesto: 8 GiB RAM, 2 GiB de artefactos nuevos, 30 minutos por suite; cada comando Julia
se limita a 60 segundos. Un timeout es inconcluso. No hay auditorías Python ni GPU.

Project/Manifest propios mínimos: BenchmarkTools 1.8.0, JET 0.12.1, Julia 1.13.0.
Se reutilizó el lock compatible RCE y se comprobó mediante Pkg.resolve en modo offline,
sin añadir, quitar ni actualizar versiones. Las fuentes DCM y RCE se incluyen por ruta
relativa y quedan cubiertas por el manifiesto de huellas de ARM. No se comparte entorno global.
La caché de Julia puede necesitar permisos fuera del workspace; no sustituye los archivos
fuente ni permite cambiar silenciosamente las dependencias.

```bash
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/admision-retarget-multivista-v1 --check-bounds=yes veritas/consenso/admision-retarget-multivista-v1/test/runtests.jl --seed 20260911
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/admision-retarget-multivista-v1 veritas/consenso/admision-retarget-multivista-v1/run.jl --seed 20260911
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/admision-retarget-multivista-v1 veritas/consenso/admision-retarget-multivista-v1/bench/benchmarks.jl --seed 20260911
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/admision-retarget-multivista-v1 veritas/consenso/admision-retarget-multivista-v1/bench/perfil.jl --seed 20260911
cargo test --offline --locked -j 2 -p zx-consensus --test retarget_causal_endogeno_modelo arm_frontera:: -- --test-threads=1 --nocapture
cargo test --offline --locked -j 2 -p zx-consensus --test retarget_causal_endogeno_modelo -- --test-threads=1
cargo clippy --offline --locked -j 2 -p zx-consensus --test retarget_causal_endogeno_modelo -- -D warnings
rustfmt --edition 2021 --check crates/zx-consensus/tests/retarget_causal_endogeno_modelo.rs crates/zx-consensus/tests/soporte/admision_retarget_multivista_frontera.rs
sha256sum --check --strict veritas/consenso/admision-retarget-multivista-v1/HUELLAS.sha256
```

Los tests verdes incluyen detecciones esperadas de los controles negativos. Desde la enmienda
Z0 (2026-09-12) HeldZero es no-op en Julia y en Rust: ambos lados coinciden, y el vector de
ventana vacía con desfase 2 verifica la convergencia (`range_at(40)=200`), no una discrepancia.
Los informes separan alcance Julia, frontera Rust, errores detectados y pendientes de protocolo.
No se ejecuta aquí la suite completa del nodo; el fallo conocido de migración de cabecera
92/556 y la ausencia de integración PoST+DAG no se eliminan ni se ocultan.

Benchmark: ramas sintéticas de profundidad 8, 16 y 32 después de un prefijo común de una
historia; diez muestras, una evaluación por muestra. Se contrastan referencia/kernel antes de
medir. Preparación del catálogo, entrega inicial y copia de reset del harness quedan fuera;
preparación privada interna, validación DCM, snapshots y reconstrucción RCE quedan dentro.
Los tiempos se imprimen en ns; cualquier conversión a µs divide entre 1000 exactamente.
El perfil añade una vista fresca e incluye ese coste en su contador de asignaciones.
No se optimiza ni se paraleliza este control pequeño: el coste se mide y se declara, no se
presenta como una implementación eficiente para producción.
