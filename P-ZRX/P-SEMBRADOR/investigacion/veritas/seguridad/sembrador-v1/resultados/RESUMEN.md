# Resultados reproducidos

- Fecha: 2026-09-20.
- Entorno: Julia 1.13.0, CPU `znver5`, 1 hilo Julia, 0 interactivos, OpenBLAS 1 hilo.
- Presupuesto observado en el barrido: 311 928 KiB de RSS máximo, 0,54 s de pared y 1 hilo; el
  proyecto completo ocupa 116 KiB sin contar cachés externas de Julia.
- Tests: 42/42 correctos en seis grupos.
- Kernel: 100 000 filas, mediana 1,484472 ms, mínimo 1,480172 ms, 0 bytes y 0 asignaciones calientes.
- Referencia BigFloat: una fila, mediana 2,270 µs, 3 024 bytes, 57 asignaciones.
- JET: `No errors detected`.
- Barrido adimensional: 96 filas; 54 rentables, 18 no rentables y 24 sin ventana dirigida, solo para
  los cocientes de entrada publicados en el propio TSV.

Comandos exactos:

```bash
cd /home/katana/zeo/ZEROX
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 \
  ./veritas/julia.sh \
  --project=P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1 \
  --threads=1,0 -e 'using Pkg; Pkg.test()'

JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 \
  ./veritas/julia.sh \
  --project=P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1 \
  --threads=1,0 \
  P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/bench/benchmarks.jl

/usr/bin/time -v env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 \
  ./veritas/julia.sh \
  --project=P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1 \
  --threads=1,0 \
  P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/run.jl \
  --rho 1,1.001,1.5,3 --L 3600,7200 --I 851 --W-dec 20 \
  --coste-intento 1e-9,1e-6,1e-3 --recompensa 1 \
  --espacio-honesto 1e3,1e6,1e9,1e12 \
  --salida P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/resultados/BARRIDO-ADIMENSIONAL.tsv
```

El barrido es deliberadamente adimensional. Sus valores económicos no son precios ni parámetros
propuestos; ejercitan ambos lados de la desigualdad de rentabilidad.
