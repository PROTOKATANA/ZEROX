# ORDEN-A10-M1 — Hashrate medido del PoW dev (SHA3-256 de la preimagen v1) en CPU y GPU

## 1. Identidad y contexto

- **ID:** A10-M1. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Claude Sonnet
  (la GPU **no** es visible dentro del sandbox de DeepSeek: `9681061:P-ZRX/P-INTENTO/investigacion/mediciones/gpu.txt`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/A10M1/`. Nada fuera de ella; sin git.
- **Motivo:** `AUTO-ZRX.md` §73 exige medir el hashrate CPU/GPU del PoW de arranque; IPA A-10 no tiene
  ninguna medida. `P-ZRX/P-POW/NOTA-A12-ALGORITMO.md` §3: sin estos números cualquier recomendación
  sobre el algoritmo sería intuición.
- **Pregunta falsable:** «Una GPU de consumo de 2016 (GTX 1070) calcula el `hash_pow` exacto de la red
  dev al menos 10 veces más rápido que los 32 hilos de la CPU de referencia.» Se refuta o se confirma
  con la medida; cualquiera de los dos resultados vale.

## 2. Qué se mide exactamente

El `hash_pow` de `Sha3Dev` (`crates/zx-consensus/src/algoritmo.rs`): SHA3-256 de
`BlockHeader::preimagen_pow()` (`crates/zx-core/src/preimage/block.rs`), una sola permutación
Keccak-f[1600] porque `TAMANO_PREIMAGEN_POW ≤ RATE_SHA3_256`, iterando **exactamente** los 8 bytes de
`[OFFSET_NONCE_PREIMAGEN, +8)`. Unidad: hashes por segundo (H/s) de esa preimagen, no de otra.

## 3. Método

1. **Referencia CPU (Rust).** En una copia de la raíz dentro de tu zona
   (`tar --exclude=./PDF --exclude=./deepseek --exclude=./target`), un binario de medida propio (no se
   migra) que llama a `zx_core::sha3_256_publico` sobre la preimagen con el nonce variando, en
   release, `--locked`, `CARGO_HOME`/`CARGO_TARGET_DIR` en tu zona (caché copiable en
   `deepseek/W05b2R/.cargo-home`). Hilos: 1, 2, 4, 8, 16, 32, con `taskset` y 5 repeticiones de ≥ 10 s
   cada una. Registra **antes y después** de cada serie `uptime`, `nproc` y los 10 procesos que más CPU
   usan: la máquina **está ejecutando otros encargos**; la cifra de 1 hilo en un núcleo libre es la
   principal y la escala multihilo queda marcada «con carga ajena» (el director la repetirá en reposo con
   tu mismo comando).
2. **GPU (CUDA).** Núcleo propio de Keccak-f[1600] para SHA3-256 de un bloque, con **CUDA 12.9**
   (`/usr/local/cuda-12.9/bin/nvcc -arch=sm_61`; CUDA 13 ya no genera código para Pascal). Cada hilo
   prueba nonces consecutivos sobre la preimagen fija y compara con un objetivo (como un minero real,
   para no medir solo escrituras a memoria).
3. **Validación antes de medir (obligatoria):** (a) los vectores SHA3-256 de
   `testdata/nist-cavp/` que quepan en un bloque, calculados en GPU, coinciden; (b) para 10⁶ nonces
   aleatorios con semilla fija, el hash GPU coincide bit a bit con el de la referencia Rust (compara
   ficheros o un resumen `sha256` de la concatenación ordenada); (c) una búsqueda con objetivo fácil
   encuentra el mismo primer nonce válido en GPU y CPU. **Sin (a)–(c) no hay cifra GPU.**
4. **Medida GPU:** 5 repeticiones de ≥ 30 s, configuración de rejilla y bloques barrida y declarada;
   `nvidia-smi --query-gpu=power.draw,clocks.sm,temperature.gpu,utilization.gpu` muestreado cada 1 s.
5. **Energía CPU:** si `/sys/class/powercap/*/energy_uj` es legible sin privilegios, J por hash; si
   no, dilo y no lo estimes.
6. **Contraste con fuentes (opcional):** cifras públicas de Keccak en GTX 1070 o GPU actuales, con URL
   y fecha de consulta, etiquetadas **fuente primaria comprobada** solo si leíste la página. No
   sustituyen la medida.
7. **Derivación final:** tabla de «tiempo y energía para producir `W` de trabajo» con las cifras
   medidas, para `W` = 2³⁶, 2⁴⁰, 2⁴⁴ y 2⁴⁸ hashes esperados, etiquetada **derivación**, sin precios
   inventados.

## 4. Límites

**Prohibido Python.** No leas ni muestres credenciales. No instales paquetes del sistema ni toques
controladores. Presupuesto: 1 h 30 min de reloj; CPU según §3.1; la GPU entera. Si CUDA 12.9 no
compila para `sm_61` o el dispositivo no responde, **para** y entrega la salida literal: el resultado
es «GPU no medida», nunca una cifra de documentación.

## 5. Entregable

`deepseek/A10M1/INFORME.md` (en español): entorno (CPU, GPU, controlador, CUDA, carga), comandos
exactos, validación (a)–(c) con salidas, tabla de medidas por repetición (no solo la media), ratio
GPU/CPU con su incertidumbre, derivación §3.7, fuentes, y qué **no** queda demostrado (p. ej., una
GTX 1070 es cota **inferior** de una GPU actual; ASIC no medido). Código fuente del banco y del núcleo
en la zona, con `sha256`.
