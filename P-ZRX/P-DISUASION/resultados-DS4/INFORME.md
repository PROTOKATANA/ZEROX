# INFORME — DS-4: coste medido en GPU de regenerar un registro PoAS (el sembrador, A3)

**Ejecutor:** Sonnet (subagente único, sin subagentes ni forks). **Fecha:** 2026-09-26.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/DS4/`. Todo lo demás del repositorio se dejó en solo
lectura (verificado al cierre: `crates/` y `PDF/` sin cambios propios; la única entrada `D` de git
bajo `PDF/` —`time-memory-tre-off-proof-space.pdf`— es anterior a esta sesión, fecha de commit
2026-09-05, y el fichero ya no existía en disco al empezar).

## Veredicto (resumen)

**La pregunta falsable NO se refuta: se confirma, con margen.** En la GTX 1070, regenerar un
registro PoAS completo (tabla de prueba de espacio K=20 + codificación erasure + enmascarado, el
equivalente exacto de `record_encoding`) cuesta una **mediana de 0,0545 s**, frente a los **≈0,9
s·núcleo** de referencia (medidos aquí también, en esta misma máquina, a 1 hilo: mediana 0,921 s;
coincide con los 0,9006 s de S02a). Eso es **~6,0 %** del tiempo por núcleo de CPU — muy por debajo
del 10 % de la pregunta falsable — y una GPU **16,9×** más rápida que 1 hilo de CPU (**4,6×** más
rápida que 8 hilos de CPU, el tope de esta orden; comparaciones por mediana de s/registro, ver §7 en
agregado). La validación bit a bit exigida **pasó**: 1000
registros, salida idéntica byte a byte entre CPU y GPU (dos sha256 iguales, 0 discrepancias).

**Consecuencia para DS-2/DS-3:** si las auditorías/registro de sectores (F1, F2 del marco) suponen
que regenerar cuesta ~1 núcleo·s por registro, una GPU de 2016 ya lo hace en la ventana declarada por
la pregunta falsable; una GPU actual sería más barata todavía (no medida aquí, ver §7).

## 1. Entorno (capturado antes de medir)

| Campo | Valor |
|---|---|
| GPU | NVIDIA GeForce GTX 1070 (Pascal, CC 6.1), 8192 MiB, límite de potencia 170,00 W |
| Controlador | 580.126.18 (NVML/nvidia-smi); Vulkan `driverVersion` 580.126.18.0, `apiVersion` 1.4.312 |
| Backend usado | Vulkan vía `wgpu` (no `nvcc`: CUDA 13.1 instalado no soporta `sm_61`/Pascal; la propia ORDEN-DS4 autoriza Vulkan en su lugar) |
| CPU | AMD Ryzen 9 9950X3D, 16 núcleos/32 hilos, 1 nodo NUMA (32 lógicos totales; se usaron ≤ 8, tope de la orden) |
| Toolchain | `nightly-2026-05-03` (`rustc 1.97.0-nightly (20de910db 2026-05-02)`), igual que el clon y que S02a |
| Clon Autonomys | `PDF/autonomys-subspace` @ `f8842d019cdf0f7163421b9644db5a9ff82b2a73` (`git status` limpio) |
| Crates usados | `subspace-proof-of-space` (`chia_v2::ChiaV2Table`, ver §3), `subspace-proof-of-space-wgpu`, `subspace-erasure-coding`, `subspace-kzg`, `subspace-core-primitives` — todos por `path` al clon, sin reimplementar PoS/KZG/erasure coding |
| Zona propia | `CARGO_HOME=deepseek/DS4/cargo-home` (2,5 GiB), `CARGO_TARGET_DIR=deepseek/DS4/target` (1,1 GiB); crate `deepseek/DS4/banco/` con `[workspace]` vacío propio (no toca el workspace de la raíz ni `Cargo.lock` de `crates/`) |
| Caché reutilizada (no en mi zona, no es del proyecto) | `~/.cache/rust-gpu/codegen/…+bd49568b/librustc_codegen_spirv.so` ya compilada de una sesión anterior; sin ella la primera compilación habría tardado mucho más en construir el backend SPIR-V. Se detectó, no se modificó su contenido, solo se reutilizó (verificación de hash por `cargo-gpu-install`, sin escritura de mi parte) |
| Compilación de `ds4` | 1 min 54 s (primera, con fetch de crates.io/git) / 1,87 s (incremental tras corregir un fallo, ver §3) |

## 2. Qué mide el banco (`deepseek/DS4/banco/src/main.rs`)

Un solo binario `ds4` con tres subcomandos, todo con la API pública del clon (nada reimplementado):

- `enumerar`: lista dispositivos `wgpu` (igual criterio que la sonda de P-INTENTO,
  `9681061:P-ZRX/P-INTENTO/investigacion/banco-rust-gpu/`).
- `validar <n>`: para `n` semillas deterministas (`blake3(prefijo‖índice)`), genera un registro de
  1 MiB (`Record::new_boxed()`, contenido cero — el coste de la tabla PoS y de la codificación
  erasure no depende del contenido; usar cero aísla el coste del dispositivo, mismo criterio que la
  sonda de P-INTENTO) y lo codifica dos veces: en CPU (`ChiaV2Table::generator().generate_parallel`
  + mismo bucle de máscara XOR que `record_encoding`) y en GPU
  (`WgpuDevice::generate_and_encode_pospace`, la función que el propio clon declara «Mirrors
  `record_encoding`… so output is byte-identical»). Compara byte a byte y acumula un sha256 por vía.
- `medir <cpu|gpu> <segundos>`: bucle cerrado (sin overlap, un registro tras otro) durante al menos
  `<segundos>`, cuenta iteraciones.

## 3. Incidencia y corrección (declarada antes de medir cualquier cifra)

La primera versión usaba `subspace_proof_of_space::chia::ChiaTable` (el módulo `chia`, que llama al
`chiapos` **interno** de `subspace-proof-of-space`). La validación con esa tabla dio **1000/1000
discrepancias** (dos sha256 distintos, mapas de chunks usados distintos): esa tabla **no** es la
que implementa `ab-proof-of-space-gpu` en el shader. El propio clon expone
`subspace_proof_of_space::chia_v2::ChiaV2Table`, que envuelve explícitamente
`ab_proof_of_space::chiapos::Tables` — el mismo crate CPU que el shader SPIR-V reimplementa — y cuyo
doc dice literalmente «Proofs are looked up under Subspace's s-bucket convention, so they verify
under the existing `ChiaTable` verifier» (es decir: es la variante compatible). Cambiado el tipo,
la validación pasó a la primera. Esto se informa porque **hubo** un GPU-no-medida transitorio por
esta causa, y porque confirma que `subspace-proof-of-space` mantiene dos implementaciones de tabla
no intercambiables entre sí bit a bit — una nota relevante para cualquier otro encargo que compare
CPU/GPU en este clon.

## 4. Validación bit a bit (obligatoria antes de cualquier cifra GPU)

```
N                       1000
SHA256_CPU              d9be7a16dfe2f0ee5b559d60538fa934c5547d75b2f40df43b4a900bbab22927
SHA256_GPU              d9be7a16dfe2f0ee5b559d60538fa934c5547d75b2f40df43b4a900bbab22927
DISCREPANCIAS_BYTES     0
DISCREPANCIAS_MAPA_USADOS  0
RESULTADO               VALIDACION_OK: 1000 registros identicos bit a bit CPU/GPU
```

Comando: `RAYON_NUM_THREADS=8 ds4 validar 1000` (crudo en `resultados/validacion2.stdout.log`;
`resultados/` conserva también la corrida fallida con la tabla equivocada, `validacion.stdout.log`,
como evidencia de la incidencia §3).

## 5. Medidas de rendimiento

Bucle cerrado, 5 repeticiones ≥ 30 s por configuración, semillas distintas por iteración
(`DS4MEDCPU`/`DS4MEDGPU` + índice). CPU con `RAYON_NUM_THREADS` fijado (1 y 8; nunca más de 8, tope
de la orden). Carga de la máquina (`/proc/loadavg`, 1 min) antes/después de cada serie:

| Serie | antes | después |
|---|---|---|
| GPU | 2,05 | — (ver nvidia-smi, no se recogió loadavg propio tras esta serie) |
| CPU 1 hilo | 0,49 | 2,01 |
| CPU 8 hilos | 1,01 | 3,92 |

Había otra actividad de fondo en la máquina (compilaciones/otras órdenes, igual que registró
S02a); las medianas son la cifra robusta frente a eso, los mínimos por repetición se leen como el
caso menos perturbado.

### CPU, 1 hilo (referencia núcleo·s)

| rep | iteraciones | s totales | s/registro | registros/s |
|---:|---:|---:|---:|---:|
| 1 | 38 | 30,165 | 0,7938 | 1,2598 |
| 2 | 33 | 30,402 | 0,9213 | 1,0854 |
| 3 | 33 | 30,327 | 0,9190 | 1,0881 |
| 4 | 32 | 30,892 | 0,9654 | 1,0359 |
| 5 | 32 | 30,894 | 0,9654 | 1,0358 |

**Mediana: 0,9213 s/registro (1,085 registros/s).** Coincide con S02a (0,9006 s, misma máquina, otra
sesión): diferencia ≤ 3 %, coherente con la carga de fondo distinta.

### CPU, 8 hilos (tope de la orden)

| rep | iteraciones | s totales | s/registro | registros/s |
|---:|---:|---:|---:|---:|
| 1 | 119 | 30,020 | 0,2523 | 3,9641 |
| 2 | 151 | 30,194 | 0,2000 | 5,0010 |
| 3 | 139 | 30,179 | 0,2171 | 4,6059 |
| 4 | 114 | 30,144 | 0,2644 | 3,7819 |
| 5 | 115 | 30,153 | 0,2622 | 3,8138 |

**Mediana: 0,2523 s/registro (3,964 registros/s).** S02a midió 0,2063 s a 8 hilos con menos carga de
fondo; el escalado (≈3,6× de 1 a 8 hilos aquí, 4,4× en S02a) es coherente con «el generador de
tablas no escala más allá de ~6× a 16 hilos» (S02a §4).

### GPU (GTX 1070, Vulkan)

| rep | iteraciones | s totales | s/registro | registros/s |
|---:|---:|---:|---:|---:|
| 1 | 555 | 30,027 | 0,05410 | 18,483 |
| 2 | 551 | 30,003 | 0,05445 | 18,365 |
| 3 | 573 | 30,026 | 0,05240 | 19,083 |
| 4 | 540 | 30,009 | 0,05557 | 17,995 |
| 5 | 519 | 30,048 | 0,05790 | 17,272 |

**Mediana: 0,05445 s/registro (18,37 registros/s).** Agregado (2738 registros / 150,11 s):
18,24 registros/s.

**Coste no incluido en esta tabla:** cada invocación de `ds4 medir gpu` paga, antes de empezar su
cronómetro, la creación del pipeline Vulkan (compilación del SPIR-V por el controlador de NVIDIA,
sin caché entre procesos distintos) — se observó en el registro de `nvidia-smi` como ~30 s de GPU
prácticamente inactiva antes de cada ráfaga de trabajo real. El cronómetro del binario arranca
**después** de `elegir_gpu_discreta()`, así que esa cifra no contamina `s/registro`; se declara
porque en una plotadora real ese coste se paga una vez por proceso, no por registro.

## 6. Potencia, reloj y temperatura (GPU, `nvidia-smi` cada 1 s)

Muestreo continuo durante toda la serie GPU (`resultados/nvidia_smi_gpu.csv`, 416 filas). Filtrando
a las filas con `utilization.gpu > 0` (149 filas, coincide con los ~150 s de cómputo real de las 5
repeticiones):

| Métrica | valor |
|---|---:|
| Potencia media (activa) | 95,48 W |
| Potencia mediana (activa) | 93,17 W |
| Potencia mín/máx (activa) | 52,32 / 130,80 W |
| Reloj SM al final de cada ráfaga | hasta 1860 MHz (arranca ~1500 MHz: la tarjeta va acelerando dentro de cada ráfaga de 30 s) |
| Temperatura máxima observada | 83 °C |
| Límite de potencia de la tarjeta | 170,00 W (nunca se alcanzó) |

**J/registro (GPU) = potencia media activa / registros por segundo (agregado) = 95,48 W / 18,24
registros·s⁻¹ ≈ 5,24 J/registro** (rango 5,11–5,24 J usando mediana/media de potencia).

**CPU: energía no medida.** `/sys/class/powercap/intel-rapl:0/energy_uj` existe pero da «Permiso
denegado» sin root; `turbostat` no accede a los MSR sin root; `perf stat -e power/energy-pkg/`
falla («No supported events found»). Sin `sudo` disponible (prohibido por la orden) no hay ninguna
vía de medir la energía de la CPU en esta máquina. **No se sustituye por un TDP de catálogo**: se
declara «no medido», sin cifra.

## 7. Derivación a tiempo y energía por TiB

Un registro (`Record::SIZE`) mide exactamente **1 MiB** (`ScalarBytes::FULL_BYTES` (32) ×
`Record::NUM_CHUNKS` (2¹⁵) = 2²⁰ B). 1 TiB = 2⁴⁰ B = **2²⁰ = 1 048 576 registros**.

| Dispositivo | registros/s (agregado) | tiempo / TiB | energía / TiB |
|---|---:|---:|---:|
| CPU, 1 hilo | 1,100 | 953 038 s ≈ **264,7 h ≈ 11,0 días** | no medida |
| CPU, 8 hilos | 4,234 | 247 656 s ≈ **68,8 h ≈ 2,87 días** | no medida |
| GPU (GTX 1070) | 18,24 | 57 500 s ≈ **15,97 h** | ≈ **5,49 MJ ≈ 1,52 kWh** (5,36 MJ ≈ 1,49 kWh con potencia mediana) |

Es una **derivación aritmética** (registros/s medido × 2²⁰), no una corrida real de 16 h: no se
sostiene que la GPU mantendría exactamente 18,24 registros/s ni la misma potencia durante 16 horas
seguidas (§8). El precio del disco y de la energía se dejan como parámetros, sin inventarlos: a
título de referencia declarada (no una conclusión del encargo), 1,52 kWh es del orden de lo que
cuesta una fracción de céntimo a coste industrial de electricidad — la comparación con el precio
del disco por TiB no se hace aquí porque el precio de mercado no es una medida de este banco.

## 8. Lo que NO queda demostrado (declarado)

- **GTX 1070 = cota inferior de 2016, Pascal.** Una GPU actual (Ada/Blackwell/RDNA reciente) sería
  más rápida y más eficiente en J/registro; no se mide ni se extrapola con un factor inventado.
  DS-2/DS-3 no deben leer «18 registros/s» como el techo de un atacante con GPU moderna.
- **Energía de CPU: no medida** (sin RAPL/MSR accesibles sin root). El J/registro de la tabla del
  §7 solo existe para GPU.
- **Potencia y reloj de la GPU en régimen de 150 s, no de 16 h continuas.** Cada ráfaga de 30 s
  mostró el reloj SM subiendo (boost térmico progresivo); una plotadora real corriendo TiB tras TiB
  podría estabilizarse en un punto de reloj/potencia distinto (más alto si el límite térmico lo
  permite, o con throttling si la refrigeración no sostiene 83 °C+ durante horas). La cifra de
  energía/TiB es una extrapolación lineal de una muestra corta, declarada como tal.
- **Coste de red/obtención de la pieza excluido**, igual que S02a: el registro se generó con
  contenido cero, no leído de una historia archivada real; el cronómetro empieza con el registro ya
  en memoria.
- **Contenido cero del registro.** No afecta al coste de la tabla PoS (domina el cómputo) ni,
  según S02a, a la fracción de chunks codificados (`cod1 = n` en sus cuatro tamaños); se declara
  igualmente porque un registro con datos reales podría tener un patrón de bits que in principio
  interactúe distinto con la codificación erasure (no se ha medido esa diferencia aquí).
- **Un solo backend (Vulkan/wgpu), no CUDA.** La ORDEN-DS4 lo autoriza explícitamente porque CUDA
  13.1 en esta máquina no soporta Pascal (`sm_61`); no se sabe si un camino CUDA nativo (con CUDA
  12.x, no instalado) daría una cifra distinta en la misma tarjeta.
- **Comparación con el coste de almacenar un TiB en disco:** no se hace, por instrucción expresa de
  la orden de no inventar precios; queda como parámetro para DS-2/DS-3.

## 9. Presupuesto, incidencias y trazabilidad

- **Presupuesto de la orden:** 2 h 30 min, GPU entera, CPU ≤ 8 hilos. **Consumido:** ≈ 1 h 15 min de
  reloj (inicio 08:30, cifras finales cerradas 09:14); ningún proceso quedó vivo al terminar
  (verificado con `pgrep`/`ps` al final de cada fase).
- **Disco de la zona:** `cargo-home` 2,5 GiB, `target` 1,1 GiB (ambos en `deepseek/DS4/`, no en la
  raíz del proyecto).
- **Caché externa reutilizada, no escrita por mí:** `~/.cache/rust-gpu/codegen/…` (backend SPIR-V ya
  compilado por una sesión anterior a esta orden; sin ella la primera compilación habría tenido que
  compilar `rustc_codegen_spirv` desde cero, con presupuesto de tiempo mucho más ajustado). No es
  parte del proyecto ni de `crates/`/`PDF/`; no se modificó.
- **Sin Python, sin credenciales, sin `git commit`/`push`, sin instalar paquetes del sistema, sin
  tocar controladores.** Solo se leyó `/sys/class/powercap/...` (denegado) y se ejecutó `turbostat`
  sin `--no-msr` en modo lectura (falló limpio, sin escalar privilegios).
- **Zona única escrita:** `deepseek/DS4/` (este informe, `banco/`, `entorno.sh`,
  `muestreo_nvidia_smi.sh`, `resultados/`, `cargo-home/`, `target/`, y los logs de compilación y
  medición). Nada se escribió en `crates/`, `PDF/`, ni en el resto del repositorio.

## 10. Reproducción

```bash
cd /home/katana/zeo/ZEROX/deepseek/DS4/banco
source ../entorno.sh
cargo build --release --bin ds4

RAYON_NUM_THREADS=8 "$CARGO_TARGET_DIR/release/ds4" validar 1000

RAYON_NUM_THREADS=1 "$CARGO_TARGET_DIR/release/ds4" medir cpu 30   # × 5
RAYON_NUM_THREADS=8 "$CARGO_TARGET_DIR/release/ds4" medir cpu 30   # × 5
bash ../muestreo_nvidia_smi.sh ../resultados/nvidia_smi_gpu.csv &  # en paralelo
"$CARGO_TARGET_DIR/release/ds4" medir gpu 30                       # × 5
```

Crudos en `deepseek/DS4/resultados/`: `medir_cpu1.log`, `medir_cpu8.log`, `medir_gpu.log`,
`nvidia_smi_gpu.csv`, `validacion2.stdout.log` (validación buena), `validacion.stdout.log` (la
corrida con la tabla equivocada, §3, conservada como evidencia), `loadavg-*.txt`.

## 11. Cierre

Se responde la pregunta falsable con medida real, validada bit a bit contra CPU: **la GPU de 2016
regenera un registro PoAS en ~6 % del tiempo por núcleo de CPU** (0,054 s frente a 0,92 s/núcleo),
**16,9× más rápida que 1 hilo y 4,6× más rápida que 8 hilos** (por mediana; 16,6× y 4,3× si se
compara por rendimiento agregado, §7). El coste por TiB en esta tarjeta es de
**~16 horas y ~1,5 kWh** (derivado, no corrido completo). Con una GPU actual el margen solo puede
ser mayor. Esto reduce la disuasión que el marco atribuye a F1/F2 (registro/auditoría de sectores)
frente a un atacante con GPU, incluso una tan antigua como esta, y así se traslada a DS-2/DS-3.
