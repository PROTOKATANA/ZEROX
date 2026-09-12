# Método reproducible

Auditoría Julia CPU, un hilo. Presupuesto autorizado: 30 minutos por suite, 8 GiB RAM y
2 GiB de disco nuevo. Si se agota, el resultado es inconcluso. No se usa Python ni GPU.

La referencia selecciona por ticket con recorridos claros y publica sobre copia de estado.
El kernel ordena una vez, usa tablas tipadas e incorpora incrementalmente; su undo es un delta
contextual. Para `B` bloques y `T` tickets, la selección de referencia es `O(T*B)` más copia de
estado; el kernel es `O(B log B)` tiempo y `O(B)` memoria auxiliar. El benchmark incluye construir
estado, validar, seleccionar, publicar y crear undo; no incluye red, criptografía, disco ni DAG.
Tampoco incluye `close_window!`: antes del sello esa función recorre el journal, por lo que cerrar
`K` ventanas sobre `E` eventos cuesta `O(K*E)` y puede ser cuadrático en una traza creciente. El
modelo actual es oráculo estructural; un motor largo necesitará buckets o un ring por ventana.

Los fixtures comunes contienen bordes L0/LG, P0/P1, Pending, sellado, reconsulta, undo y el
contraejemplo L0. Los tests añaden overflow, slot único por identidad, cero económico y 100
comparaciones referencia/kernel. `UInt64` y `Base.Checked` gobiernan reglas discretas.

Comandos desde la raíz:

```sh
mkdir -p /tmp/zerox-vrc-julia-depot
env JULIA_DEPOT_PATH=/tmp/zerox-vrc-julia-depot:/home/katana/.julia \
  JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 \
  timeout 300s veritas/julia.sh --project=veritas/consenso/ventana-retarget-causal-v1 \
  --check-bounds=yes veritas/consenso/ventana-retarget-causal-v1/test/runtests.jl

env JULIA_DEPOT_PATH=/tmp/zerox-vrc-julia-depot:/home/katana/.julia \
  JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 \
  timeout 300s veritas/julia.sh --project=veritas/consenso/ventana-retarget-causal-v1 \
  veritas/consenso/ventana-retarget-causal-v1/run.jl

env JULIA_DEPOT_PATH=/tmp/zerox-vrc-julia-depot:/home/katana/.julia \
  JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 \
  timeout 300s veritas/julia.sh --project=veritas/consenso/ventana-retarget-causal-v1 \
  veritas/consenso/ventana-retarget-causal-v1/bench/benchmarks.jl

env JULIA_DEPOT_PATH=/tmp/zerox-vrc-julia-depot:/home/katana/.julia \
  JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 \
  timeout 300s veritas/julia.sh --project=veritas/consenso/ventana-retarget-causal-v1 \
  veritas/consenso/ventana-retarget-causal-v1/bench/perfil.jl
```
