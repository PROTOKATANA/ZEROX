# Método reproducible — revisión 2

Proyecto Julia CPU aislado, enteros exactos y sin RNG. Presupuesto de referencia: un hilo,
8 GiB RAM, 2 GiB de disco nuevo y 30 minutos por suite. El timeout produce Inconcluso.

```bash
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/disponibilidad-causal-multivista-v1 --check-bounds=yes veritas/consenso/disponibilidad-causal-multivista-v1/test/runtests.jl
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/disponibilidad-causal-multivista-v1 veritas/consenso/disponibilidad-causal-multivista-v1/run.jl
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/disponibilidad-causal-multivista-v1 veritas/consenso/disponibilidad-causal-multivista-v1/bench/benchmarks.jl
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/disponibilidad-causal-multivista-v1 veritas/consenso/disponibilidad-causal-multivista-v1/bench/perfil.jl
```

El benchmark etiqueta sus profundidades como carga sintética y mide el coste del snapshot completo;
no representa tamaños ni parámetros adoptados por ZEROX.

Regresiones Rust del mismo instrumento:

```bash
cargo test --offline --locked -j 2 -p zx-consensus --test disponibilidad_causal_multivista_modelo -- --test-threads=1
cargo clippy --offline --locked -j 2 -p zx-consensus --test disponibilidad_causal_multivista_modelo -- -D warnings
rustfmt --edition 2024 --check crates/zx-consensus/tests/disponibilidad_causal_multivista_modelo.rs
sha256sum --check --strict veritas/consenso/disponibilidad-causal-multivista-v1/HUELLAS.sha256
```

Los archivos originales `resultados/{TESTS,RUN,BENCH,PERFIL,ENTORNO}.txt` conservan los registros
de revisión 1; no se presentan como nuevas ejecuciones. Los registros con sufijo `-R2` documentan
la revisión corregida. La conversión del benchmark es ns/1 000 para µs y ns/1 000 000 para ms;
las cifras de la tabla usan coma decimal y espacio entre grupos de miles.
