# INFORME — ORDEN-A10-M1: hashrate del PoW dev (SHA3-256 de la preimagen v1) en CPU y GPU

> **Actualización (Ronda 2, CORRECCION-A10-M1-A):** la GPU **sí se midió** evitando `nvcc` por
> completo (NVRTC + API del driver). Ver la sección «Ronda 2» al final. El resumen de una frase de
> más abajo describe el estado al cierre de la Ronda 1 y queda **superado** por la Ronda 2 en lo que
> toca a la GPU; la parte de CPU sigue siendo la misma medida (provisional, con carga ajena).

**Resultado en una frase (Ronda 1):** la CPU de referencia se midió con rigor (validación indirecta vía la
suite CAVP del propio crate + ancla SHA3-256(""), 6 niveles de hilos, 5 repeticiones ≥ 10 s cada
una); la GPU **no se pudo medir** — CUDA 12.9 no compila en esta máquina (único host compiler
instalado, gcc 15, es incompatible con nvcc 12.9, y CUDA 13 ya no genera código para Pascal/sm_61).
Por tanto la pregunta falsable de la ORDEN **queda sin determinar**, no confirmada ni refutada.

## 0. Desviaciones respecto a la letra de la ORDEN (declaradas)

1. **`--locked` no se pudo mantener en el `cargo build`.** El `tar` de la ORDEN excluye `PDF/`, pero
   tres miembros del workspace (`zx-poas`, `zx-farmer`, `zx-post`) dependen por *path* de
   `PDF/autonomys-subspace/...`, que ya no existe en la copia. Sin esos tres crates, el `Cargo.lock`
   deja de coincidir con el `Cargo.toml` del workspace, y `--locked` rechaza el build. Se editó el
   `Cargo.toml` de **la copia** (nunca el árbol real) para quitar esos tres miembros de
   `members = [...]` (quedan `zx-core`, `zx-pot`, `zx-consensus`, `zx-dag`, `zx-p2p`, que es todo lo
   que el banco necesita) y se compiló con `--offline` (sin `--locked`). Esto **no** mueve ninguna
   versión de `[workspace.dependencies]`: solo dejan de resolverse los tres paquetes no usados por el
   banco. `Cargo.lock` original no se toca (vive en el árbol real, fuera de la zona).
2. El presupuesto de tiempo (1 h 30 min) se gastó así: ~5 min de lectura/preparación, ~6 min de
   compilación y banco de CPU, y el resto en diagnosticar y documentar el bloqueo de CUDA (ver §3).
   No se intentó instalar ni un compilador alternativo ni un paquete del sistema (prohibido por la
   ORDEN); sí se probaron rutas sin privilegios (Clang/AOCC ya instalado, flags de `nvcc`) antes de
   declarar el bloqueo.

## 1. Entorno

| Campo | Valor |
|---|---|
| CPU | AMD Ryzen 9 9950X3D, 16 núcleos físicos / 32 hilos (`nproc`=32) |
| Kernel | Linux 6.18.9-1.0.2.sr20260202 |
| GPU | NVIDIA GeForce GTX 1070 (Pascal, CC 6.1), 8192 MiB |
| Driver NVIDIA | 580.126.18 (`nvidia-smi`, CUDA "13.0" reportado por el driver) |
| Toolkits CUDA instalados | `/usr/local/cuda-12.9` (nvcc 12.9.86) y `/usr/local/cuda-13.1` |
| Host compiler disponible | `gcc` 15.2.1 (SUSE) — **único** gcc en la máquina; también `clang` 17.0.6 (AOCC 5.1.0) |
| Rust toolchain | `nightly-2026-05-03` (fijado por `rust-toolchain.toml`, ya instalado) |
| Carga ajena durante la medida CPU | ver tabla de `uptime`/`ps` en §2.2; procesos `diferencial_t01` y `pow_dev-d659e1c` de otros encargos corriendo en paralelo todo el tramo |
| Energía CPU (`/sys/class/powercap/*/energy_uj`) | **no legible sin privilegios** (`Permiso denegado` en `intel-rapl:0`) — no se estima, tal como exige la ORDEN §3.5 |

## 2. Referencia CPU (Rust)

### 2.1 Qué se mide

`zx_core::sha3_256_publico(&preimagen)` sobre `BlockHeader::preimagen_pow()` (108 bytes), variando
el nonce (u64 little-endian) en `[OFFSET_NONCE_PREIMAGEN=96, +8)`, exactamente como pide la ORDEN
§2. Esto **es** el `hash_pow` de `Sha3Dev` (`crates/zx-consensus/src/algoritmo.rs`): la propia suite
de tests de `zx-consensus` (`el_hash_pow_dev_es_sha3_del_prefijo_y_la_cabecera`) fija esa igualdad.

Fuente: `deepseek/A10M1/repo/crates/zx-core/examples/bench_pow.rs` (no se migra al árbol real).
`sha256`: `6b50237f727d454849f539646159db1cbd27e7a4582022fb950719871c9ae29c`.

Corrección del oráculo: `sha3_256_publico` es exactamente `sha3::Sha3_256`, y **ya** está validado
contra el conjunto completo de vectores NIST CAVP en `crates/zx-core/tests/cavp_sha3_256.rs` del
propio proyecto (no se repitió aquí; se cita como evidencia de que la referencia CPU no es un
segundo oráculo sin contrastar). Punto de anclaje reproducido a mano en este banco:
`sha3_256("") = a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a` (coincide).

### 2.2 Comandos exactos

```
# Preparación de la copia (zona única escribible)
tar -C /home/katana/zeo/ZEROX --exclude=./PDF --exclude=./deepseek --exclude=./target --exclude=./.git -cf - . \
  | tar -C deepseek/A10M1/repo -xf -
cp -r deepseek/W05b2R/.cargo-home deepseek/A10M1/cargo-home     # caché de registry reutilizada (offline)

# Compilación (dentro de deepseek/A10M1/repo, con los 3 miembros PDF-dependientes fuera de members[])
export CARGO_HOME=deepseek/A10M1/cargo-home
export CARGO_TARGET_DIR=deepseek/A10M1/cargo-target
cargo build --offline --release --example bench_pow -p zx-core

# Banco (deepseek/A10M1/correr_cpu_bench.sh), 6 niveles de hilos × 5 repeticiones × 10 s:
taskset -c 0-$((t-1)) cargo-target/release/examples/bench_pow cpu-bench-mt <t> 10
```

`uptime`/`nproc`/top-10 antes y después de cada serie: `deepseek/A10M1/cpu_bench.log` (íntegro).
Ejemplos (inicio y fin del tramo):

```
--- ANTES-DE-TODO 2026-09-26T03:51:07+02:00 ---
 03:51:07  arriba 10:53,  2 users,  carga promedio: 4,97, 3,30, 3,10
--- DESPUES-DE-TODO 2026-09-26T03:56:08+02:00 ---
 03:56:08  arriba 10:58,  2 users,  carga promedio: 25,96, 11,25, 6,06
    PID %CPU %MEM COMMAND
 311611  193  0.0 diferencial_t01
 312187 91.7  0.0 pow_dev-d659e1c
```

La máquina **estaba ejecutando otros encargos** durante todo el tramo (carga promedio subiendo de
~5 a ~26 según se sumaban procesos ajenos). La cifra de 1 hilo es la principal, tal como pide la
ORDEN; la escala multihilo queda marcada explícitamente **"con carga ajena"**.

### 2.3 Tabla de medidas por repetición (no solo la media)

| hilos | rep | hashes | segundos | H/s |
|---|---|---|---|---|
| 1 | 1 | 48 168 960 | 10.011362 | 4 811 429 |
| 1 | 2 | 48 300 032 | 10.009024 | 4 825 649 |
| 1 | 3 | 47 972 352 | 10.005431 | 4 794 631 |
| 1 | 4 | 48 889 856 | 10.005705 | 4 886 198 |
| 1 | 5 | 49 152 000 | 10.012612 | 4 909 009 |
| 2 | 1 | 98 238 464 | 10.005459 | 9 818 486 |
| 2 | 2 | 98 107 392 | 10.010189 | 9 800 753 |
| 2 | 3 | 98 172 928 | 10.008206 | 9 809 244 |
| 2 | 4 | 98 304 000 | 10.013736 | 9 816 915 |
| 2 | 5 | 98 172 928 | 10.012311 | 9 805 221 |
| 4 | 1 | 193 462 272 | 10.011568 | 19 323 874 |
| 4 | 2 | 193 396 736 | 10.013762 | 19 313 095 |
| 4 | 3 | 193 462 272 | 10.012833 | 19 321 432 |
| 4 | 4 | 193 134 592 | 10.012654 | 19 289 050 |
| 4 | 5 | 193 331 200 | 10.013538 | 19 306 982 |
| 8 | 1 | 376 373 248 | 10.011100 | 37 595 594 |
| 8 | 2 | 375 717 888 | 10.014477 | 37 517 473 |
| 8 | 3 | 370 671 616 | 10.010851 | 37 026 984 |
| 8 | 4 | 375 193 600 | 10.014483 | 37 465 101 |
| 8 | 5 | 374 996 992 | 10.013886 | 37 447 700 |
| 16 | 1 | 683 278 336 | 10.014774 | 68 227 037 |
| 16 | 2 | 676 462 592 | 10.013380 | 67 555 867 |
| 16 | 3 | 672 923 648 | 10.017229 | 67 176 628 |
| 16 | 4 | 678 166 528 | 10.019122 | 67 687 220 |
| 16 | 5 | 677 838 848 | 10.017889 | 67 662 844 |
| 32 | 1 | 685 965 312 | 10.027737 | 68 406 794 |
| 32 | 2 | 688 062 464 | 10.023487 | 68 645 019 |
| 32 | 3 | 687 341 568 | 10.024866 | 68 563 669 |
| 32 | 4 | 689 831 936 | 10.027192 | 68 796 120 |
| 32 | 5 | 682 622 976 | 10.021843 | 68 113 520 |

**Medias (con carga ajena, ver §2.2):**

| hilos | H/s (media de 5 reps) | escalado respecto a 1 hilo |
|---|---|---|
| 1 | 4 845 383 | 1,00× |
| 2 | 9 810 124 | 2,02× |
| 4 | 19 310 887 | 3,99× |
| 8 | 37 410 570 | 7,72× |
| 16 | 67 661 919 | 13,97× |
| **32** | **68 505 024** | **14,14×** |

El escalado se aplana entre 16 y 32 hilos: 16 = número de **núcleos físicos**; los 16 hilos
adicionales son SMT sobre los mismos núcleos y prácticamente no añaden throughput en una carga
ALU/cache-bound como Keccak-f[1600] (los dos hilos lógicos de un núcleo compiten por las mismas
unidades de ejecución). Esto es coherente con la arquitectura del chip (9950X3D, 16 núcleos/32
hilos) y no es un artefacto de medida, pero **no se aisló** del efecto de la carga ajena creciente
(la carga promedio subía a la vez que se probaban más hilos); el director puede repetir en reposo
con el mismo comando (`correr_cpu_bench.sh`) para separar ambos efectos.

## 3. GPU (CUDA) — **no medida**

### 3.1 Qué se intentó

Núcleo propio de Keccak-f[1600]/SHA3-256 de un solo bloque en C++/CUDA:
`deepseek/A10M1/gpu/pow_gpu.cu` (sha256:
`4f203e473a086051f0e6c2e1cc24fedb39b79ef6d9595cdccc093ee0c3670566`). Implementa los cuatro modos que
pedía la ORDEN (`selftest` para (a), `dump` para (b), `search` para (c), `bench`), usando la misma
plantilla de 108 bytes que genera `bench_pow preimagen-hex` (no se transcribió a mano para no crear
una segunda fuente de verdad). **Nunca llegó a ejecutarse**: no compila.

### 3.2 El bloqueo, con la salida literal

```
$ /usr/local/cuda-12.9/bin/nvcc -O3 -arch=sm_61 -std=c++17 -o pow_gpu pow_gpu.cu
[...]/crt/host_config.h:143:2: error: #error -- unsupported GNU version!
  gcc versions later than 14 are not supported!
  The nvcc flag '-allow-unsupported-compiler' can be used to override this version check [...]
```

gcc 15.2.1 es el **único** compilador gcc instalado en la máquina (no hay gcc-12/13/14). Con el
flag de override (`-allow-unsupported-compiler`) el error cambia de naturaleza — deja de ser el
aviso de versión y pasa a ser una incompatibilidad real de cabeceras entre la libstdc++ de gcc 15 y
el front-end de `nvcc` 12.9:

```
$ /usr/local/cuda-12.9/bin/nvcc -O3 -arch=sm_61 -std=c++17 -allow-unsupported-compiler -o pow_gpu pow_gpu.cu
/usr/include/c++/15/type_traits(555): error: identifier "__is_pointer" is undefined
/usr/include/c++/15/type_traits(1844): error: incomplete type "std::__cv_selector<...>" is not allowed
/usr/include/bits/mathcalls.h(83): error: exception specification is incompatible with that of
  previous function "cospi" (declared in crt/math_functions.h)
[... 33 errores en total ...]
```

Se comprobó que esto **no** depende del contenido de `pow_gpu.cu`: un `.cu` mínimo, de una sola
línea (`__global__ void k(int*x){*x=42;}`, sin ningún `#include`), produce el mismo tipo de errores
— `nvcc` inyecta sus propias cabeceras (`crt/*.h`) que a su vez tiran de la `libstdc++`/`glibc`
instaladas, y el front-end de `cicc` (CUDA 12.9) no reconoce los *builtins* que la libstdc++ 15 usa
sin guardas (`__is_pointer`, `__is_pair`, etc.) ni las declaraciones `noexcept` de `math.h` en esta
versión de `glibc` (2.43). Salidas completas guardadas en
`deepseek/A10M1/gpu/evidencia-fallo/fallo-1-sin-flags.txt` y `fallo-2-allow-unsupported-compiler.txt`.

Alternativas probadas, sin instalar nada (prohibido por la ORDEN) y sin tocar el driver:

- **Clang como host compiler** (`-ccbin clang++`, AOCC 5.1.0/Clang 17, ya instalado): falla distinto,
  por el mismo choque `glibc` 2.43 vs `crt/math_functions.h` de CUDA 12.9 (`cospi`/`sinpi`/`rsqrt`
  con especificación de excepción incompatible).
- **CUDA 13.1** (el otro toolkit instalado): `nvcc --list-gpu-arch` no incluye `sm_61` ni ningún
  `compute_6x` — el mínimo es `compute_75`. Confirma lo que ya adelantaba la ORDEN: CUDA 13 no genera
  código para Pascal. Salida en `evidencia-fallo/cuda13-archs-sin-sm61.txt`.
- Contenedores (`docker`/`podman`/`distrobox`/`nix`) para aislar un `glibc`/`gcc` compatibles: **no
  hay ninguno instalado** en la máquina.

No existe en esta máquina ninguna combinación de compilador y CUDA que soporte simultáneamente
`sm_61` (Pascal) y el `glibc`/`gcc` instalados. Arreglarlo exige instalar un `gcc` 12–14 (o un
`glibc` de contenedor), que la ORDEN prohíbe expresamente. Aplicando la letra de la ORDEN §4: *"Si
CUDA 12.9 no compila para `sm_61` [...] para y entrega la salida literal: el resultado es «GPU no
medida», nunca una cifra de documentación."*

### 3.3 Validación (a)–(c)

**No se realizó ninguna.** El código de `selftest`/`dump`/`search` existe en `pow_gpu.cu` pero nunca
compiló, así que no hay binario que ejecutar. Por la letra de la ORDEN, sin (a)–(c) no hay cifra
GPU, y no se generó ninguna.

## 4. Ratio GPU/CPU-32 y la pregunta falsable

**No calculable.** Al no existir cifra GPU, el ratio GPU/CPU-32 no tiene numerador.

> «Una GPU de consumo de 2016 (GTX 1070) calcula el `hash_pow` exacto de la red dev al menos 10 veces
> más rápido que los 32 hilos de la CPU de referencia.»

**Queda sin determinar** (ni confirmada ni refutada) en esta máquina, por el bloqueo de §3, no por
falta de intento.

## 5. Derivación §3.7 — tiempo para producir `W` de trabajo (etiquetado **derivación**)

Solo con las cifras de CPU medidas (§2.3), "con carga ajena". Energía: no calculable (§1, RAPL sin
permiso); no se estima ningún número de energía.

| `W` (hashes esperados) | tiempo a 1 hilo (H/s=4 845 383) | tiempo a 32 hilos (H/s=68 505 024) |
|---|---|---|
| 2³⁶ ≈ 6,872 × 10¹⁰ | 14 182,5 s ≈ 3,94 h ≈ 0,164 d | 1 003,1 s ≈ 0,28 h ≈ 0,012 d |
| 2⁴⁰ ≈ 1,0995 × 10¹² | 226 919,4 s ≈ 63,03 h ≈ 2,626 d | 16 050,1 s ≈ 4,46 h ≈ 0,186 d |
| 2⁴⁴ ≈ 1,7592 × 10¹³ | 3 630 711,0 s ≈ 1 008,53 h ≈ 42,022 d | 256 801,4 s ≈ 71,33 h ≈ 2,972 d |
| 2⁴⁸ ≈ 2,8147 × 10¹⁴ | 58 091 375,5 s ≈ 16 136,49 h ≈ 672,354 d | 4 108 822,4 s ≈ 1 141,34 h ≈ 47,556 d |

No hay fila de GPU ni de ASIC: no se midió ninguna de las dos.

## 6. Fuentes externas (§3.6)

No se buscaron cifras públicas de Keccak en GTX 1070. Es un paso **opcional** de la ORDEN y, dado
que la GPU no se pudo medir aquí, una cifra de terceros sobre GTX 1070 tampoco cerraría la pregunta
falsable de esta máquina (sería una cota de otra máquina, no la medida pedida); se priorizó agotar y
documentar el bloqueo real dentro del presupuesto de tiempo. Queda pendiente si el director lo pide.

## 7. Qué NO queda demostrado

- El hashrate GPU real de esta GTX 1070 (ni de ninguna GPU) para este `hash_pow`: **no medido**, por
  el bloqueo de toolchain de §3, no por ausencia de dispositivo (el dispositivo responde:
  `nvidia-smi` lo ve, driver 580.126.18 operativo).
- Cualquier ratio GPU/CPU, y por tanto la pregunta falsable de la ORDEN, en esta máquina.
- El escalado 16→32 hilos "en reposo": la medida multihilo se hizo con carga ajena creciente
  (§2.2); no se puede separar aquí cuánto del aplanamiento 16→32 es SMT y cuánto es contención con
  `diferencial_t01`/`pow_dev-d659e1c`. La cifra de 1 hilo es la más limpia de las dos.
- Energía por hash en CPU: RAPL no legible sin privilegios; no se estimó ningún número.
- Nada sobre ASIC: no se midió ni se buscó ninguna cifra de terceros (§3.6 no ejecutado).
- Que una GPU **actual** (no una GTX 1070 de 2016) sea más rápida o más lenta: aunque se hubiera
  medido la 1070, seguiría siendo, como dice la ORDEN, una cota **inferior** de hardware moderno.

## 8. Ficheros de la zona (con `sha256`)

```
deepseek/A10M1/repo/crates/zx-core/examples/bench_pow.rs
  6b50237f727d454849f539646159db1cbd27e7a4582022fb950719871c9ae29c
deepseek/A10M1/gpu/pow_gpu.cu
  4f203e473a086051f0e6c2e1cc24fedb39b79ef6d9595cdccc093ee0c3670566
deepseek/A10M1/correr_cpu_bench.sh        — script del banco CPU (taskset + 6×5 reps)
deepseek/A10M1/cpu_bench.log              — salida íntegra del banco (uptime/ps antes y después + medidas)
deepseek/A10M1/gpu/evidencia-fallo/       — salidas literales de los intentos de compilación CUDA
deepseek/A10M1/repo/Cargo.toml            — copia de trabajo con zx-poas/zx-farmer/zx-post fuera de members[] (§0.1)
```

---

# Ronda 2 (CORRECCIÓN-A10-M1-A) — GPU medida por NVRTC + API del driver, sin `nvcc`

**Resultado en una frase:** funcionó. Compilando el mismo núcleo Keccak-f[1600] en tiempo de
ejecución con NVRTC 12.9 (`--gpu-architecture=compute_61`) y lanzándolo con `cuLaunchKernel` (API
del driver, sin pasar nunca por el `nvcc`/anfitrión C++ que bloqueó la Ronda 1), las validaciones
(a)-(c) pasan las tres, y la GTX 1070 mide entre **561 y 627 MH/s** según el reloj (con
*throttling* térmico durante la medida). Con la cifra CPU-32 de la Ronda 1 (68 505 024 H/s, con
carga ajena), el ratio GPU/CPU-32 está entre **8,19× y 9,15×** — **por debajo de 10×** en todas las
repeticiones. La pregunta falsable de la ORDEN queda **REFUTADA** en esta máquina.

## R2.1 Qué cambia respecto a la Ronda 1

El diagnóstico de la Ronda 1 (§3.2 más arriba) era correcto: el problema no era el núcleo ni la
arquitectura `sm_61`, sino que `nvcc` 12.9 necesita compilar el **anfitrión** en C++ con la
`libstdc++`/`glibc` del sistema, y la única disponible (gcc 15 / glibc 2.43) es demasiado nueva para
`nvcc` 12.9 (ni con `-allow-unsupported-compiler`).

La corrección evita ese paso por completo:

1. El núcleo (`deepseek/A10M1/gpu/kernel_nvrtc.cu`) es **exactamente la misma matemática** que
   `pow_gpu.cu` de la Ronda 1 (mismo `keccakf`, mismas constantes, misma convención de lanes, mismo
   offset del nonce en el lane 12), pero **sin ningún `#include`**: tipos con `typedef` propios
   (`u8`/`u32`/`u64`), sin arrastrar ninguna cabecera de C ni de C++. Lo compila **NVRTC**
   (`nvrtcCreateProgram` + `nvrtcCompileProgram` con `--gpu-architecture=compute_61`), que no
   depende en absoluto del `gcc` del sistema para el *device code*.
2. El anfitrión (`deepseek/A10M1/gpu/pow_gpu_nvrtc.c`) es **C11 puro**, compilado con el propio
   `gcc` de la máquina (el mismo gcc 15 que bloqueaba `nvcc`, aquí sin problema porque `cuda.h` y
   `nvrtc.h` son cabeceras C planas — declaran solo tipos y prototipos `extern "C"`, no arrastran
   `libstdc++`). Usa la **API del driver** (`libcuda.so`): `cuInit`, `cuCtxCreate`,
   `cuModuleLoadData` sobre el PTX que devuelve NVRTC, `cuModuleGetFunction`, `cuLaunchKernel`.
3. La preimagen fija de 108 bytes se obtiene en caliente ejecutando
   `bench_pow preimagen-hex` (el mismo binario Rust de la Ronda 1) vía `popen`, para no
   transcribirla a mano una tercera vez.

### Comandos exactos

```
gcc -std=c11 -O2 -I/usr/local/cuda-12.9/include \
    -o pow_gpu_nvrtc pow_gpu_nvrtc.c \
    -L/usr/local/cuda-12.9/lib64 -L/usr/lib64 -lnvrtc -lcuda \
    -Wl,-rpath,/usr/local/cuda-12.9/lib64

./pow_gpu_nvrtc kernel_nvrtc.cu <bench_pow> selftest <testdata/nist-cavp>
./pow_gpu_nvrtc kernel_nvrtc.cu <bench_pow> dump <seed> <n> <fichero>
./pow_gpu_nvrtc kernel_nvrtc.cu <bench_pow> search <bits_cero> <max_nonce>
./pow_gpu_nvrtc kernel_nvrtc.cu <bench_pow> bench <duracion_s> <blocks> <threads> <reps>
```

Compiló sin ningún error ni warning de compatibilidad (solo el aviso esperado de NVRTC: *"Architectures
prior to compute_75 are deprecated"* — informativo, no bloqueante). No fue necesaria la vía
alternativa de OpenCL.

## R2.2 Validación (a)-(c) — las tres pasan

**(a) Vectores NIST CAVP de un bloque**, calculados en GPU vía `k_validar_vectores`:

```
.../testdata/nist-cavp/SHA3_256ShortMsg.rsp: 136 vectores con Len<=1080 bits
.../testdata/nist-cavp/SHA3_256LongMsg.rsp: 0 vectores con Len<=1080 bits   (todos sus vectores superan 135 bytes)
validacion (a): 136/136 vectores NIST CAVP correctos (0 fallos)
```

**(b) 10⁶ nonces con semilla fija (424242)**, GPU vs. referencia Rust, comparados bit a bit:

```
$ bench_pow dump-ref 424242 1000000 cpu_dump.bin
$ pow_gpu_nvrtc kernel_nvrtc.cu bench_pow dump 424242 1000000 gpu_dump.bin
$ sha256sum cpu_dump.bin gpu_dump.bin
8ee6f015a3fa260b95199c79e383e25025747f19b6c7264bfe272bdb5c8895b3  cpu_dump.bin
8ee6f015a3fa260b95199c79e383e25025747f19b6c7264bfe272bdb5c8895b3  gpu_dump.bin
$ cmp cpu_dump.bin gpu_dump.bin && echo "IDENTICOS bit a bit"
IDENTICOS bit a bit
```

Mismo `sha256` de los 32 000 000 bytes (10⁶ × 32) en ambos lados: los digests son idénticos, no solo
"parecidos".

**(c) Búsqueda con objetivo fácil** (≥20 bits altos a cero, sobre `max_nonce=5·10⁶`), CPU y GPU:

```
CPU: search: nonce=1737536 hash=00000dbb63520af1f2d0f35db76cfe05955a7d0d69b653bf1275d491c58ed5ce bits_cero=20
GPU: search: nonce=1737536
```

Mismo primer nonce válido en los dos. Las tres validaciones pasan: **hay cifra GPU**.

## R2.3 Medida de hashrate GPU

Configuración de rejilla: se barrieron `blocks×threads` = 60×128, 120×128, 120×256, 240×128,
240×256, 480×128, 960×64, 60×256, 60×512, 120×512 (calibración de 2 s cada una); todas dieron entre
~618 y ~649 MH/s, sin un óptimo claro (el núcleo satura la GPU independientemente de la ocupación
declarada más allá de cierto mínimo). `blocks=30,threads=1024` y `blocks=15,threads=1024` fallaron
al lanzar (exceso de registros/recursos por bloque a esa ocupación) — configuraciones descartadas,
no cuentan como medida. Se eligió **blocks=120, threads=256** (30 720 hilos) para las 5 repeticiones
formales de ≥30 s, con `nvidia-smi` muestreado cada 1 s durante todo el tramo
(`deepseek/A10M1/gpu/nvidia_smi_muestreo.csv`, 152 muestras).

### Tabla de medidas por repetición

| rep | hashes | segundos | H/s | reloj SM (inicio→fin de la rep, aprox.) | temp GPU (aprox.) |
|---|---|---|---|---|---|
| 1 | 19 027 353 600 | 30.356394 | 626 798 875 | 1860→1695 MHz (arrancando) | 63→70 °C |
| 2 | 18 106 675 200 | 30.159374 | 600 366 416 | 1695→~1580 MHz | 70→~78 °C |
| 3 | 16 879 104 000 | 30.079798 | 561 144 195 | ~1580→1506 MHz | ~78→82 °C |
| 4 | 16 879 104 000 | 30.085154 | 561 044 294 | 1506 MHz (estable) | ~83→84 °C |
| 5 | 16 879 104 000 | 30.084042 | 561 065 033 | 1506 MHz (estable) | ~85→86 °C |

**Media de las 5 repeticiones: 582 083 763 H/s.** La caída de 627→561 MH/s entre la rep. 1 y la rep.
3 **no es ruido**: `nvidia-smi` muestra el reloj de los *streaming multiprocessors* bajando de 1860
a 1506 MHz (el reloj base de la tarjeta) a medida que la temperatura sube de 63 °C a ~85 °C —
*throttling* térmico real, con `utilization.gpu` al 99-100 % todo el tramo (confirma que el núcleo
es *compute-bound*, no limitado por transferencias). La proporción cuadra: 561/627 ≈ 0,894 y
1506/1695 ≈ 0,889 — casi el mismo factor, coherente con un núcleo cuyo coste escala linealmente con
el reloj. Potencia media muestreada: 108,6 W (resumen de las 152 muestras de
`nvidia_smi_muestreo.csv`).

**Cifra de referencia recomendada: el régimen estable y sostenido (reps 3-5), 561 084 507 H/s**,
porque es la que se sostendría en una sesión de minado real más allá de los primeros ~40 s (el pico
inicial de la rep. 1, con la tarjeta aún fría, no es representativo de un régimen continuo).

## R2.4 Ratio GPU/CPU-32 y veredicto de la pregunta falsable

CPU-32 (Ronda 1, con carga ajena — no repetida en esta ronda por instrucción explícita de la
CORRECCIÓN): **68 505 024 H/s**.

| Cifra GPU usada | H/s GPU | Ratio GPU/CPU-32 | ¿≥10×? |
|---|---|---|---|
| Media de las 5 reps | 582 083 763 | **8,50×** | No |
| Rep. 1 (pico, sin *throttle*, tarjeta fría) | 626 798 875 | **9,15×** | No |
| Reps 3-5 (régimen estable, recomendada) | 561 084 507 | **8,19×** | No |

**Las tres formas de leer la medida dan un ratio por debajo de 10×.** La pregunta falsable de la
ORDEN —*"una GPU de consumo de 2016 (GTX 1070) calcula el `hash_pow` exacto de la red dev al menos
10 veces más rápido que los 32 hilos de la CPU de referencia"*— **queda REFUTADA** en esta máquina,
con este núcleo y con esta CPU.

Una advertencia que no debilita la refutación sino que la refuerza: la cifra de CPU-32 usada
(68 505 024 H/s) se midió **con carga ajena** (Ronda 1, §2.2) y con el aplanamiento de escalado
16→32 hilos ya discutido (SMT + contención). Una medida de CPU-32 en reposo **no puede ser menor**
que la que se usó aquí —la contención solo resta hashrate, nunca lo añade—, así que el ratio real
"limpio" (GPU vs. CPU-32 sin carga ajena) es, si acaso, **igual o menor** que 8,19-9,15×, nunca mayor.
El director puede repetir la CPU en reposo (pendiente, según la CORRECCIÓN) para afinar el número,
pero no para revertir el veredicto de "no llega a 10×".

## R2.5 Qué sigue sin quedar demostrado

- El hashrate en un régimen verdaderamente sostenido (>30 s), con el disipador ya en equilibrio
  térmico: la rep. 5 (85→86 °C) sugiere que el sistema aún no había terminado de estabilizar del
  todo; una tanda más larga (varios minutos) podría asentarse un par de MH/s por debajo de 561 MH/s,
  pero no cambiaría el orden de magnitud del ratio.
- Energía por hash en GPU: no se calculó (no era parte de la ORDEN para GPU; solo se pidió el
  muestreo de `nvidia-smi`, que está en `nvidia_smi_muestreo.csv`).
- Cualquier cifra de ASIC o de una GPU más moderna: sigue sin medirse ni buscarse (§3.6 de la ORDEN,
  opcional, no ejecutado en ninguna ronda).
- La vía alternativa de OpenCL (§2 de la CORRECCIÓN) no se probó: no hizo falta, NVRTC funcionó a la
  primera.

## R2.6 Ficheros nuevos de la zona (con `sha256`)

```
deepseek/A10M1/gpu/kernel_nvrtc.cu        04fbbb3f2742bb0736df9fac7150524e76162177c91a1472432ef86a5128bc88
deepseek/A10M1/gpu/pow_gpu_nvrtc.c        bbd5d11a45edc7c6f232fef0f7ab18acd34731337631f9b10d13494768d84a5e
deepseek/A10M1/gpu/correr_gpu_bench.sh    — script de la medida (nvidia-smi en paralelo + 5×30s)
deepseek/A10M1/gpu/gpu_bench.log          — salida de las 5 repeticiones
deepseek/A10M1/gpu/gpu_bench.stderr       — log de compilación NVRTC + info de dispositivo
deepseek/A10M1/gpu/nvidia_smi_muestreo.csv — muestreo cada 1 s durante las 5 repeticiones (152 filas)
deepseek/A10M1/gpu/cpu_dump.bin / gpu_dump.bin — los 32 MB de la validación (b), sha256 idénticos
```

---

# Ronda 3 (CORRECCIÓN-A10-M1-B) — escala CPU en reposo

**Resultado en una frase:** repetida la escala de hilos con el mismo binario ya compilado y el mismo
método de la Ronda 1, esperando a que la carga de 1 minuto de `/proc/loadavg` bajara de 1,0 antes de
cada serie, cinco series (1, 2, 4, 8, 16 hilos) se midieron **en reposo** y solo la de **32 hilos**
quedó marcada **«con carga»** (la carga ajena no bajó de 1,0 en los 20 min de espera). Frente a la
Ronda 1, la CPU rinde prácticamente lo mismo a 1–8 hilos (+0,5 % a +2,3 %), pero **a 16 hilos rinde un
9,1 % más** (73,79 vs 67,66 MH/s), que es justo el tramo donde la Ronda 1 acumulaba la mayor carga
ajena. La serie de 32 hilos, aun marcada «con carga», da 68,03 MH/s (≈ −0,7 % que la Ronda 1): el
aplanamiento 16→32 **no** desaparece.

## R3.1 Método y ficheros

- Script: `deepseek/A10M1/correr_cpu_bench_reposo.sh`; salida íntegra: `deepseek/A10M1/cpu_bench_reposo.log`.
- Binario: `cargo-target/release/examples/bench_pow`, **el ya compilado en la Ronda 1** (no se recompiló).
- Comando por repetición, idéntico al de la Ronda 1:
  `taskset -c 0-$((t-1)) cargo-target/release/examples/bench_pow cpu-bench-mt <t> 10`,
  con `t ∈ {1,2,4,8,16,32}` y 5 repeticiones de 10 s por nivel.
- Antes de cada serie se lee `/proc/loadavg`: si la carga de 1 minuto es ≥ 1,0, se espera en pasos de
  30 s (máximo 20 min = 1200 s por serie), registrando cada espera; si no baja, la serie se marca
  `CON_CARGA` y se mide igualmente. En cada serie se registra `uptime`, `loadavg`, `nproc` y los 10
  procesos con más `%CPU` antes y después.
- Sin Python. Nada se escribió fuera de la zona. Sin git.

## R3.2 Tabla de medidas por repetición

| hilos | rep | hashes | segundos | H/s |
|---|---|---|---|---|
| 1 | 1 | 49 545 216 | 10.005847 | 4 951 626 |
| 1 | 2 | 49 610 752 | 10.010516 | 4 955 863 |
| 1 | 3 | 49 610 752 | 10.011305 | 4 955 473 |
| 1 | 4 | 49 610 752 | 10.009690 | 4 956 272 |
| 1 | 5 | 49 610 752 | 10.004762 | 4 958 713 |
| 2 | 1 | 98 893 824 | 10.005134 | 9 884 307 |
| 2 | 2 | 98 893 824 | 10.011878 | 9 877 649 |
| 2 | 3 | 98 893 824 | 10.011782 | 9 877 744 |
| 2 | 4 | 98 828 288 | 10.014065 | 9 868 947 |
| 2 | 5 | 98 828 288 | 10.011357 | 9 871 617 |
| 4 | 1 | 194 183 168 | 10.010949 | 19 397 079 |
| 4 | 2 | 194 314 240 | 10.007019 | 19 417 794 |
| 4 | 3 | 194 248 704 | 10.012444 | 19 400 727 |
| 4 | 4 | 194 379 776 | 10.010613 | 19 417 369 |
| 4 | 5 | 194 379 776 | 10.011248 | 19 416 138 |
| 8 | 1 | 378 994 688 | 10.013383 | 37 848 817 |
| 8 | 2 | 378 929 152 | 10.010820 | 37 851 959 |
| 8 | 3 | 378 470 400 | 10.011630 | 37 803 076 |
| 8 | 4 | 378 077 184 | 10.013529 | 37 756 638 |
| 8 | 5 | 377 880 576 | 10.013571 | 37 736 843 |
| 16 | 1 | 742 719 488 | 10.015913 | 74 153 946 |
| 16 | 2 | 740 818 944 | 10.010975 | 74 000 675 |
| 16 | 3 | 738 983 936 | 10.013302 | 73 800 228 |
| 16 | 4 | 739 573 760 | 10.015350 | 73 844 022 |
| 16 | 5 | 732 430 336 | 10.012943 | 73 148 360 |
| 32 | 1 | 692 518 912 | 10.036655 | 68 998 974 |
| 32 | 2 | 678 166 528 | 10.057676 | 67 427 755 |
| 32 | 3 | 685 899 776 | 10.020886 | 68 447 016 |
| 32 | 4 | 678 559 744 | 10.025767 | 67 681 581 |
| 32 | 5 | 677 773 312 | 10.024619 | 67 610 877 |

(Las cinco filas de 32 hilos se midieron con carga ajena; ver R3.4. El resto, en reposo.)

## R3.3 Media por número de hilos y estado de la serie

| hilos | H/s (media de 5) | estado | espera antes de medir | carga 1-min inicio → fin | escalado vs 1 hilo |
|---|---|---|---|---|---|
| 1 | 4 955 590 | EN_REPOSO | 0 s | 0,29 → 0,70 | 1,00× |
| 2 | 9 876 053 | EN_REPOSO | 0 s | 0,70 → 1,52 | 1,99× |
| 4 | 19 409 822 | EN_REPOSO | 30 s | 0,92 → 2,66 | 3,92× |
| 8 | 37 799 467 | EN_REPOSO | 90 s | 0,71 → 4,84 | 7,63× |
| 16 | 73 789 447 | EN_REPOSO | 270 s | 0,75 → 9,45 | 14,89× |
| 32 | 68 033 241 | **CON_CARGA** | 1200 s (máx. agotado) | 4,00 → 28,98 | 13,73× |

La «carga 1-min inicio → fin» es la de `/proc/loadavg` justo antes de la primera repetición y justo
después de la última; la «fin» incluye el propio banco (los hilos que acaban de correr), por eso sube
aunque el sistema estuviera en reposo al empezar.

## R3.4 Qué series quedaron «con carga»

Solo **32 hilos**. El script esperó los 1200 s completos (40 pasos de 30 s) sin que la carga de 1
minuto bajara de 1,0; durante la espera osciló entre 1,12 y 9,55, con picos de carga ajena
(la máquina está ejecutando otros encargos). Al agotarse el máximo se marcó `CON_CARGA` y se midió
igual. La carga de 1 minuto al terminar la serie fue 28,98.

Las series de **1, 2, 4, 8 y 16 hilos** quedaron `EN_REPOSO`: cargas de 1 minuto al iniciar la medida
0,29 / 0,70 / 0,92 / 0,71 / 0,75 respectivamente (< 1,0). La de 16 hilos necesitó 270 s de espera; las
de 1 y 2, ninguna. La de 32 hilos es, por tanto, la **única** que no pudo medirse en reposo.

**Limitación de registro (honesta):** las llamadas de shell de este ejecutor corren dentro de un
sandbox con su propio *PID namespace*: `ps -e` y `/proc` solo exponen los procesos del sandbox
(`bwrap`, `bash`, `ps`, `head`), no los procesos ajenos del anfitrión. El top-10 de `%CPU` pedido
queda por eso **incompleto**; la carga ajena solo es visible a través de `/proc/loadavg` (que sí es
del sistema completo) y de `uptime`, y fue esa lectura la que gobernó las esperas. El registro de
`uptime`/`loadavg`/`nproc`/`ps` antes y después de cada serie está igualmente en
`cpu_bench_reposo.log`.

## R3.5 Comparación con la Ronda 1

| hilos | R3 (en reposo) H/s | R1 (con carga ajena) H/s | R3 / R1 |
|---|---|---|---|
| 1 | 4 955 590 | 4 845 383 | **+2,3 %** |
| 2 | 9 876 053 | 9 810 124 | +0,7 % |
| 4 | 19 409 822 | 19 310 887 | +0,5 % |
| 8 | 37 799 467 | 37 410 570 | +1,0 % |
| 16 | 73 789 447 | 67 661 919 | **+9,1 %** |
| 32 | 68 033 241 (con carga) | 68 505 024 (con carga) | −0,7 % |

| hilos | escalado R3 | escalado R1 |
|---|---|---|
| 1 | 1,00× | 1,00× |
| 2 | 1,99× | 2,02× |
| 4 | 3,92× | 3,99× |
| 8 | 7,63× | 7,72× |
| 16 | **14,89×** | 13,97× |
| 32 | 13,73× | 14,14× |

Lectura:

- A **1–8 hilos** la Ronda 1 ya estaba prácticamente limpia: la repetición en reposo solo sube la
  cifra entre un 0,5 % y un 2,3 %. La contaminación de la Ronda 1 no era apreciable en ese tramo
  (el `uptime` de entonces daba carga ~5, pero repartida entre núcleos).
- A **16 hilos** sí se nota: 67,66 → 73,79 MH/s (+9,1 %). Es coherente con que la Ronda 1 registrara
  `diferencial_t01`/`pow_dev-d659e1c` ocupando núcleos justo en el tramo de 8/16/32 hilos; con la
  máquina más quieta, los 16 hilos físicos rinden más. El escalado a 16 hilos sube de 13,97× a
  **14,89×**.
- A **32 hilos** la serie volvió a caer en carga ajena y no es una medida en reposo comparable. Aun
  así, su media (68,03 MH/s) es casi idéntica a la de la Ronda 1 (68,51 MH/s), y sigue **por debajo**
  de los 16 hilos en reposo (73,79 MH/s): la conclusión de la Ronda 1 se mantiene —los 16 hilos
  lógicos extra de SMT sobre los 16 núcleos físicos no añaden throughput en Keccak-f[1600]— y el
  aplanamiento 16→32 **no** era solo efecto de la carga ajena.
- La cifra principal de 1 hilo en reposo es **4 955 590 H/s**.

## R3.6 Consecuencia para el ratio GPU/CPU-32 (derivación)

No se recalcula la pregunta falsable con una CPU-32 en reposo porque **no la hay**: la serie de 32
hilos volvió a quedar «con carga». Usando la cifra de 32 hilos de esta ronda (68 033 241 H/s, con
carga) frente a la GPU de la Ronda 2 (régimen estable 561 084 507 H/s; pico en frío 626 798 875 H/s)
el ratio GPU/CPU-32 es **8,25×–9,21×**, igual que en la Ronda 2 y todavía **por debajo de 10×**. El
veredicto de la Ronda 2 (pregunta falsable **refutada** en esta máquina) no cambia; lo único que la
Ronda 3 separa es que el techo multihilo limpio de esta CPU está en ~16 hilos (14,89× sobre 1 hilo),
no en 32.

## R3.7 Ficheros nuevos de la zona (con `sha256`)

```
deepseek/A10M1/correr_cpu_bench_reposo.sh  c683d0f1353b9479069568f67256f3db32e404b43246c982341e6e312c73b2ce
deepseek/A10M1/cpu_bench_reposo.log        5ca0577da9a4c83503c81664b3913f0d51fa079f14ac0a0b9115708a090217c5
```

## R3.8 Qué sigue sin quedar demostrado (Ronda 3)

- Una CPU-32 **en reposo**: la carga ajena no lo permitió en 20 min; la serie de 32 hilos quedó
  marcada «con carga». Lo que sí quedó demostrado es que el techo limpio está en 16 hilos.
- El top-10 real de procesos del anfitrión: el sandbox solo expone sus propios procesos (R3.4).
- Energía CPU: sin cambios (RAPL no legible sin privilegios); no se estimó.
- Todo lo que la Ronda 2 dejó abierto (régimen GPU >30 s, ASIC, GPU moderna) sigue abierto.

