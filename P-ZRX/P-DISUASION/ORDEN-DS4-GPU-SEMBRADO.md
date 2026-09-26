# ORDEN-DS4 — Coste medido de regenerar parcelas en GPU (el sembrador, A3)

## 1. Identidad y contexto

- **ID:** DS-4. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Sonnet (la GPU no
  es visible dentro del sandbox de DeepSeek; sí desde el entorno del director: GTX 1070, controlador
  580.126.18, ICD Vulkan de NVIDIA en `/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json`).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/DS4/`.
- **Hueco que cierra:** `P-INTENTO` (2026-09-21) midió el sembrador en CPU («~100× peor que comprar
  disco») y dejó la **GPU sin medir** (`9681061:P-ZRX/P-INTENTO/investigacion/mediciones/gpu.txt`: el
  sandbox no veía el dispositivo); la cifra «replotear 1 TiB con GPU ≈ 1,4 h» es **documental, no
  medida**. Si la GPU abarata mucho la regeneración, las auditorías y el registro de sectores
  (F1, F2) disuaden menos de lo que se cree; si no, son una barrera real. Es un dato de DS-2/DS-3.
- **Pregunta falsable:** «En la GTX 1070, regenerar un registro PoAS (tabla + codificación, el
  equivalente de `record_encoding`) cuesta menos de una décima parte del tiempo por núcleo de CPU
  medido en `P-ZRX/P-REGISTRO-SECTORES/investigacion/02-auditorias/` (≈ 0,9 s·núcleo por registro).»

## 2. Método

1. **Referencia CPU:** el mismo cálculo en CPU con el código del clon fijado
   (`PDF/autonomys-subspace` @ `f8842d0`, `shared/ab-proof-of-space` o la ruta que usa `zx-poas`),
   medido en tu zona.
2. **GPU por Vulkan** (sin `nvcc`, que no acepta el gcc 15 del sistema): `shared/subspace-proof-of-space-wgpu`
   y/o `shared/ab-proof-of-space-gpu` del clon, como hizo la sonda antigua
   `9681061:P-ZRX/P-INTENTO/investigacion/banco-rust-gpu/` (rehaz sus rutas hacia `PDF/`). Si una ruta
   no compila o no encuentra dispositivo, prueba la otra; si ninguna, **GPU no medida** con la salida
   literal. Nunca una cifra de documentación en su lugar.
3. **Validación antes de cualquier cifra:** para ≥ 1 000 registros con semillas fijas, la salida GPU
   es **idéntica bit a bit** a la CPU (resumen `sha256` de la concatenación).
4. **Medida:** registros por segundo y por vatio (`nvidia-smi` cada 1 s: potencia, reloj, temperatura,
   utilización), 5 repeticiones de ≥ 30 s; derivación a **tiempo y energía por TiB** y por registro
   auditado. Registra la carga de la máquina (`/proc/loadavg`) antes y después.
5. **Derivación (etiquetada):** comparación con el coste de almacenar (sin inventar precios: deja el
   precio del disco y de la energía como parámetros) y con las cifras CPU de `P-INTENTO` y S02a.

## 3. Límites y entregable

Dependencias: las del clon; si hay que descargar crates, en el `CARGO_HOME` de tu zona, sin tocar el
lock de la raíz. Sin instalar paquetes del sistema. **No lances subagentes ni forks.** Sin git; sin
Python; sin credenciales. Presupuesto: 2 h 30 min; la GPU entera; CPU ≤ 8 hilos. Entregable:
`deepseek/DS4/INFORME.md` con entorno, comandos, validación, tabla por repetición, derivación y lo que
**no** queda demostrado (una GTX 1070 es cota inferior de una GPU actual).
