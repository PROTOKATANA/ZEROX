# Método reproducible

Instrumento Julia CPU, aritmética entera, un hilo. El oráculo usa `BigInt`, escaneos lineales y
selección directa; el kernel usa `UInt128` comprobado, buckets por slot/ventana, conjuntos de IDs
y una cola con cursor. Son implementaciones separadas del simulador. `validate_equivalence`
compara exactamente sus proyecciones de estado y métricas sobre la misma traza.

Comandos publicados desde la raíz del repositorio, reproducidos con un depot Julia local
escribible:

```bash
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/retarget-causal-endogeno-v1 --check-bounds=yes veritas/consenso/retarget-causal-endogeno-v1/test/runtests.jl
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/retarget-causal-endogeno-v1 veritas/consenso/retarget-causal-endogeno-v1/run.jl 20260911
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/retarget-causal-endogeno-v1 veritas/consenso/retarget-causal-endogeno-v1/bench/benchmarks.jl
env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 timeout 60s veritas/julia.sh --project=veritas/consenso/retarget-causal-endogeno-v1 veritas/consenso/retarget-causal-endogeno-v1/bench/perfil.jl
```

Los valores de estos escenarios son controles sintéticos, no calibración ni elección de
producción. El benchmark separa escalado temporal, retención de cuerpo/backlog DA0 y coste del
oráculo. No ejecuta Python ni modela una cola de servicio por bytes.
