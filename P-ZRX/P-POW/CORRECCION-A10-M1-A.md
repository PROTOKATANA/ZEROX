# CORRECCIÓN A10-M1-A — segunda ronda de la medida GPU por NVRTC

**Fecha:** 2026-09-26. **Director:** Claude. Mismo ejecutor, zona y límites que `ORDEN-A10-M1`.

**Qué falló en la primera ronda (evidencia en `deepseek/A10M1/gpu/evidencia-fallo/`):** `nvcc` 12.9,
el único que genera código para Pascal, no acepta el único compilador de C++ del sistema (gcc 15);
con `-allow-unsupported-compiler` fallan las cabeceras de C++ (`__is_pointer`, `noexcept` en
`math.h`). CUDA 13.1 ya no genera `compute_6x`. **No** es un fallo del núcleo.

**Qué se espera cambiar:** evitar por completo la compilación de anfitrión de `nvcc`.
1. **Vía principal:** el mismo núcleo, compilado en tiempo de ejecución con **NVRTC 12.9**
   (`/usr/local/cuda-12.9/lib64/libnvrtc.so`, opción `--gpu-architecture=compute_61`), cargado y
   lanzado con la **API del driver** (`/usr/lib64/libcuda.so`, `cuModuleLoadData`,
   `cuLaunchKernel`). Programa anfitrión en **C puro** (`gcc -std=c11`, incluye `cuda.h` y `nvrtc.h`
   de `/usr/local/cuda-12.9/include`, enlaza `-lcuda -lnvrtc`): `cuda.h` y `nvrtc.h` son cabeceras C
   y no arrastran la biblioteca de C++. El núcleo no debe incluir cabeceras del sistema.
2. **Alternativa**, solo si 1 falla con salida literal: OpenCL con el ICD de NVIDIA
   (`/etc/OpenCL/vendors/nvidia.icd`, `/usr/lib64/libOpenCL.so.1`, cabeceras de
   `/usr/local/cuda-12.9/include/CL/` si existen), anfitrión en C.
3. La validación (a)–(c) de la orden sigue siendo **obligatoria antes de cualquier cifra**; la medida
   y el muestreo de `nvidia-smi`, iguales.
4. CPU: no se repite ahora (la máquina sigue con carga ajena); las cifras de la primera ronda quedan
   como **provisionales con carga ajena** y el director las repetirá en reposo.

Presupuesto: 1 h. Sin instalar nada. Si ninguna vía compila, «GPU no medida» con la salida literal de
ambas. Añade la sección «Ronda 2» al mismo `INFORME.md`.
