# Coste de ploteo y de auditoría en PoAS — MEDIDO, no citado

**Fecha:** 2026-09-05 · **Motivo:** `PREGUNTAS-PARA-KATANA.md` P-032 y `DECISIONES.md` §15.

Toda la discusión del ritmo de relleno y del ataque de generación bajo demanda descansaba en una
cifra de prosa: *"Modern CPUs can complete the plotting of a sector in less than two minutes, while
a single high performance GPU can accomplish the same task in under five seconds"* (Autonomys
Academy, página *Plotting*). **Es exactamente el tipo de número que este proyecto ya se ha comido
tres veces** (H-005, tamaño de cabecera, `MAX_RESPUESTA_BYTES`), así que se midió.

## Qué se midió

`cargo bench -p subspace-farmer-components --bench plotting -- --sample-size 10`
sobre `subspace @ f8842d0`, toolchain `nightly-2026-05-03`, en la máquina de desarrollo (32 hilos).
El banco usa `CpuRecordsEncoder` y `ChiaV2Table`, con `MAX_PIECES_IN_SECTOR = 1000` (sector ≈ 1 GiB).

## Resultado

```
plotting/in-memory      time:   [82.236 s  83.608 s  85.476 s]
                        thrpt:  [11.792 MiB/s  12.055 MiB/s  12.257 MiB/s]
```

**83,6 s por sector de 1 GiB en CPU, 12,06 MiB/s.** La prosa de Academy («<2 min en CPU») **se
sostiene**. La cifra de GPU («<5 s») **no se ha medido** — no se usa como si estuviera verificada.

## Para qué sirve: el coste de fabricar espacio al vuelo

`SLOT_DURATION = 1000` ms (`subspace-runtime/src/lib.rs:145`). Un atacante que guarde la historia y
regenere sectores en el momento de auditar produce, como mucho, su rendimiento de ploteo por slot:

| | Espacio fabricable por slot de 1 s |
|---|---:|
| CPU 32 hilos — **medido** | **12,1 MiB** |
| GPU a 5 s/sector — *doc, sin medir* | 204,8 MiB |

Y por tanto, para fabricar una red entera al vuelo frente a comprarla en disco:

| Red | CPUs | GPUs | Disco honesto equivalente |
|---|---:|---:|---:|
| 10 TiB | 869 827 | 51 200 | ~$250 |
| 100 TiB | 8 698 266 | 512 000 | ~$2 500 |
| 1 PiB | 89 070 247 | 5 242 880 | ~$25 600 |

## Lo que esto NO demuestra

⚠️ La tabla supone que el atacante regenera **todo** el espacio que reclama, en **cada** slot. El
ataque real es más listo: no necesita responder a todos los desafíos, solo **encontrar un ganador**.
Con un `solution_range` ancho —que es justo lo que tiene una red pequeña— podría bastar con
regenerar unos pocos sectores candidatos. **La tabla acota el ataque ingenuo, no el ataque real.**

Contrastar con `chia-parcelas-comprimidas.md`: el número de Chia (una RTX 5090 ≈ 20 TB imitados) mide
otra cosa —*plot ID grinding*, no regeneración completa— y **no se transfiere** a este cuadro.

Pendiente: el banco `auditing` mide el coste por desafío, que es la magnitud que decide el ataque
real. Y la derivación formal está en manos de D9.

---

## El coste por auditoría — la magnitud que sí decide

`cargo bench -p subspace-farmer-components --bench auditing -- --sample-size 10`, misma máquina y
commit. `sectors_count` por defecto = 10 (`benches/auditing.rs:48`).

```
auditing/disk/sync      time:   [92.825 µs  93.221 µs  93.558 µs]   (10 sectores)
                        thrpt:  [106.89 Kelem/s  107.27 Kelem/s  107.73 Kelem/s]
```

~~**9,32 µs por sector auditado desde disco.**~~

> ## ⚠️ ESA CIFRA ESTÁ MAL. Corregido el 2026-09-06.
>
> `audit_plot_sync` usa **`.par_iter()`** sobre los sectores
> (`subspace-farmer-components/src/auditing.rs:128`). Los 92,8 µs son de **una llamada que audita
> 10 sectores en 32 hilos**, así que dividir entre 10 da **throughput, no coste serie**.
>
> Re-medido con el paralelismo desactivado:
>
> ```
> SECTORS_COUNT=1 RAYON_NUM_THREADS=1 cargo bench --bench auditing
> auditing/disk/sync   time: [42.874 µs  42.916 µs  43.006 µs]   ← UN sector, UN hilo
> ```
>
> **42,92 µs.** Mi cifra era 4,6× más baja.
>
> ### Y no hay un solo número: hay una banda de 15×, según de quién hablemos
>
> | Quién | Coste por auditoría | Cómo se obtuvo |
> |---|---:|---|
> | Granjero honesto, implementación de referencia | **42,92 µs** | medido aquí, un hilo, rango ancho |
> | Solo el bucle interno (500 blake3 + distancia) | 27,5 µs | medido por D9 |
> | **Atacante con lote SIMD de 16 vías** | **2,82 µs** | cota inferior por throughput bulk de blake3 |
> | ~~9,32 µs~~ | — | **throughput paralelo, no es un coste** |
>
> ⚠️ **Para un análisis de seguridad hay que usar la del atacante (2,82 µs), no la del granjero.**
> Y ese 2,82 es una **cota inferior sin techo**: blake3 en GPU está órdenes de magnitud por encima
> y nadie lo ha medido. Cualquier umbral derivado de este número es provisional.
>
> La cifra vieja se propagó a `SPEC.md` §12.1, y a `DECISIONES.md` §24 y §25. Corregida en los tres.



⚠️ El resultado `auditing/memory/sync = 404 ps` **es un banco roto de ellos, no una medición.** Usa
`b.iter(|| async { … })`: el bloque `async` construye un futuro que **nadie awaitea ni sondea**, así
que Criterion cronometra la construcción del futuro y nada más. No se usa esa cifra.

## El número que cierra el ataque de generación bajo demanda

| Acción, por sector | Coste |
|---|---:|
| Auditarlo honestamente desde disco | **9,32 µs** |
| Regenerarlo para auditarlo | **83,6 s** |
| **Razón** | **≈ 9,0 millones ×** |

Un granjero honesto audita ~107 000 sectores por segundo, es decir **~105 TiB de espacio prometido
por slot** con una sola máquina. El atacante que no guarda paga nueve millones de veces más **por
cada sector que quiera comprobar**, y tiene que comprobar para saber si gana.

Esto vale también para el ataque «listo» que la sección anterior dejaba abierto: el atacante no
necesita auditar todo, pero **auditar es precisamente cómo se descubre si un sector gana**. No hay
atajo que evite regenerar el sector que se quiere comprobar. La razón de 9 millones no depende de
cuántos sectores compruebe.

## Consecuencia para la compresibilidad del relleno (P-032)

La objeción abierta era: si el relleno es ChaCha8 sembrado de 32 bytes, ¿puede un atacante guardar
semillas en vez de piezas y regenerar al auditar?

**Puede regenerar las piezas gratis. Lo que no puede es saltarse la codificación.** Lo que el
auditor lee no es la pieza: es el **registro codificado** con la tabla de pruebas de espacio, y
producir eso es justo los 83,6 s medidos. La entropía del dato subyacente no es la barrera; **la
barrera es la tabla**. Que el relleno sea pseudoaleatorio derivable no lo hace comprimible en el
sentido que importa.

Lectura del hilo principal a partir de la medición; la derivación formal es de D9.

---

## Ploteo en GPU — MEDIDO en una GTX 1070, no citado

**Fecha:** 2026-09-05 · **Motivo:** la tabla de arriba tenía una columna de GPU marcada *"doc, sin
medir"* (204,8 MiB/s, extrapolada de la cifra de prosa de Academy, *"a single high performance GPU
can accomplish the same task in under five seconds"*). Se midió, con el hardware disponible: una
**GTX 1070 (Pascal, 2016, 8192 MiB)** — explícitamente **no** la "high performance GPU" de la cita.
Esa GPU es de hace diez años; el número que sigue es una cota real con hardware viejo, no una
refutación de la cifra de Academy.

### No hay banco de GPU en el repo — se construyó uno ad hoc

`crates/subspace-farmer-components/benches/` solo tiene bancos de CPU. La única ruta del monorepo
que ejercita el codificador de GPU de punta a punta es un test de igualdad de bytes:
`crates/subspace-farmer-components/tests/plot_read_roundtrip.rs:269-402`
(`WgpuTestEncoder` / `wgpu_plotted_sector_matches_cpu`, subspace @ `f8842d0`). Se replicó ese patrón
en un binario de medición manual (`examples/plotting_gpu_manual.rs`, temporal, borrado al terminar
— ver limpieza al final), usando el mismo `plot_sector` y el mismo `MAX_PIECES_IN_SECTOR = 1000` que
el banco de CPU, para que los números sean comparables.

El primer intento usó `criterion` (igual que el banco de CPU) pero cada iteración tarda ~65-70 s;
con `--sample-size 10` el banco necesita calentamiento + 10 muestras (~700-770 s) y se topó con mi
propio `timeout 590`, así que se mató a media ejecución (código de salida 143, no un fallo del
código bajo prueba). Se cambió a un binario con `std::time::Instant` explícito por iteración —
mismo camino de producción (`plot_sector` + `WgpuDevice` real sobre hardware real), solo cambia
cómo se cronometra, no qué se cronometra.

Dispositivo usado, confirmado por enumeración (`subspace_proof_of_space_wgpu::Device::enumerate`,
que envuelve `shared/ab-proof-of-space-gpu/src/host.rs:87-185`):

```
id=0 name="NVIDIA GeForce GTX 1070" type=DiscreteGpu backend=Vulkan   ← usado
id=1 name="AMD Ryzen 9 9950X3D ... (RADV RAPHAEL_MENDOCINO)" type=IntegratedGpu backend=Vulkan
id=2 name="llvmpipe (LLVM 22.1.5, 256 bits)" type=Cpu backend=Vulkan
```

Solo se usó **una cola** (`create_proofs_encoder_instances().into_iter().next()`), igual que el test
de igualdad de bytes del repo. `ab-proof-of-space-gpu` soporta múltiples colas por dispositivo
(`number_of_queues` en `Device::enumerate`) — esto es un piso, no un techo, de lo que una GPU podría
producir.

### Resultado — sector de 1000 piezas (1007,94 MiB), n=5

```
iteración 0: 67.570 s
iteración 1: 70.277 s
iteración 2: 69.841 s
iteración 3: 69.853 s
iteración 4: 69.272 s

media = 69.363 s   (rango: 67.570 s – 70.277 s)
throughput = 14.53 MiB/s   (rango: 14.34 – 14.92 MiB/s)
```

| | Tiempo por sector (1 GiB) | Throughput |
|---|---:|---:|
| CPU, 32 hilos — **medido antes** | 83,608 s (82,236–85,476) | 12,055 MiB/s (11,792–12,257) |
| GPU, GTX 1070, 1 cola — **medido ahora** | **69,363 s** (67,570–70,277) | **14,531 MiB/s** (14,34–14,92) |
| **Factor GPU/CPU en este hardware** | **1,21×** | **1,21×** |

**Una GTX 1070 de 2016 sólo es un 21 % más rápida que 32 hilos de CPU para esta tarea.** No es la
"GPU de alto rendimiento" de la cita, pero tampoco es un resultado ambiguo: el camino de GPU de
Autonomys funciona, produce sectores byte-idénticos a los de CPU (lo verifica su propio test), y en
este silicio concreto **no** da el salto de dos órdenes de magnitud que sugiere la prosa.

### El coste escala con el trabajo, no con una latencia fija por llamada

Se repitió la medición con sectores más pequeños para distinguir "cuello de botella de cómputo real"
de "coste fijo por invocación" (cada pieza hace su propio ciclo de mapeo de buffer y lectura, ver
`shared/ab-proof-of-space-gpu/src/host.rs` y el bucle en
`crates/subspace-farmer-components/tests/plot_read_roundtrip.rs:288-296`):

| Piezas en el sector | Tamaño | Media (n=3) | Throughput |
|---:|---:|---:|---:|
| 10 | 10,08 MiB | 0,630 s | 15,3–16,4 MiB/s |
| 100 | 100,79 MiB | 6,184 s | 16,2–16,3 MiB/s |
| 1000 | 1007,94 MiB | 69,363 s | 14,3–14,9 MiB/s |

El throughput se mantiene en una banda estrecha (14,3–16,4 MiB/s) en un rango de 100× en tamaño de
sector. **No hay coste fijo dominante por invocación** — el tiempo es genuinamente proporcional al
trabajo. Eso sí permite extrapolar por especificaciones de hardware (más abajo); lo que no permite
decir, sin perfilar con herramientas de GPU que no están disponibles aquí, es **qué recurso** está
saturado (ALU vs ancho de banda de memoria) — importa para la extrapolación siguiente.

### ¿Es plausible el «bajo 5 segundos» de Academy en una GPU moderna?

GTX 1070 (Pascal, 2016): 6,46 TFLOPS FP32, 256,3 GB/s de ancho de banda de memoria. RTX 5090
(Blackwell, 2026, el consumo tope actual): ~104,8 TFLOPS FP32 (16,2× la 1070), 1792 GB/s (7,0× la
1070) — especificaciones de fabricante/agregadores, no una medición propia de esa tarjeta.

| Si el cuello de botella fuera... | Factor vs GTX 1070 | Tiempo extrapolado para 1 sector |
|---|---:|---:|
| cómputo (TFLOPS FP32) | 16,2× | **4,28 s** — bajo los 5 s citados |
| ancho de banda de memoria | 7,0× | **9,92 s** — casi 2× por encima de los 5 s citados |

**No se puede decidir cuál de las dos aplica sin perfilar el shader**, y no hay herramientas de
perfilado de GPU en esta máquina para hacerlo con garantías. La carga de trabajo (ChaCha8, hashing
repetido, ordenación por cubos sobre arreglos grandes —
`shared/ab-proof-of-space-gpu/src/shader/constants.rs`) tiene pinta de sentarse entre ambos límites,
ni puramente ALU-bound ni puramente ancho-de-banda-bound. **Conclusión honesta: la cifra de Academy
es plausible para una GPU tope de 2026, en un rango de 4 a 10 s según el cuello de botella real —
ni claramente confirmada ni claramente refutada por esta medición.** Es una extrapolación acotada
por dos hipótesis, no una verificación.

### Consecuencia para P-034(a) — cuánto puede replotear un atacante entre desafíos

Con `T = 120 s`, y usando el número **medido**, no el de prosa:

| Fuente del número de GPU | MiB/slot (1 s) | GiB replanteables en `T = 120 s` |
|---|---:|---:|
| Doc, sin medir (5 s/sector, descartado) | 204,8 | ~24,0 |
| **Medido, GTX 1070 (piso real, hardware viejo)** | **14,5** | **~1,7** |
| Extrapolado, GPU tope 2026, si ALU-bound | ~235 | ~27,6 |
| Extrapolado, GPU tope 2026, si ancho-de-banda-bound | ~102 | ~12,0 |

La fila medida es casi idéntica a la de CPU (12,1 MiB/slot) — con hardware de 2016 el ataque de
replot no gana casi nada usando GPU en vez de CPU. Con una GPU tope de 2026 y si el cuello de
botella es cómputo, el ataque sí se acerca a la cifra doc-based que se había descartado. **No decido
aquí qué fila usar para dimensionar nada** — solo dejo el rango real con su procedencia.

### Consecuencia para la razón «auditar vs regenerar»

Con el número de GPU medido en vez del de CPU, la razón de la sección anterior (83,6 s / 9,32 µs ≈
9,0 millones×) cambia a **69,4 s / 9,32 µs ≈ 7,4 millones×**. Sigue siendo del mismo orden de
magnitud — la conclusión cualitativa (auditar honestamente es millones de veces más barato que
regenerar) no depende de si el atacante usa CPU o esta GPU concreta.

### Lo que arrastra esta ruta — no es solo "una feature nightly más"

Compilar `shared/ab-proof-of-space-gpu` no solo requiere nightly: **compila un shader SPIR-V con un
backend de compilador Rust completamente distinto.**

```toml
# Cargo.toml (raíz del monorepo), línea 56
cargo-gpu-install = { version = "=0.10.0-alpha.1", git = "https://github.com/Rust-GPU/rust-gpu", rev = "bd49568b..." }
```

`shared/ab-proof-of-space-gpu/build.rs:33-77` invoca ese crate para compilar el propio código del
shader (`shader-unknown-vulkan1.2`) con **`rustc_codegen_spirv`**, un backend alternativo de rustc
que traduce Rust a SPIR-V. Al compilarlo aquí descargó y cacheó por su cuenta:

```
~/.cache/rust-gpu/codegen/...   (36 MiB, el backend de codegen compilado)
~/.cargo/git/checkouts/rust-gpu-...   (checkout completo del repo rust-gpu)
```

Esto es, en la práctica, **un segundo toolchain de Rust**, fijado a un `rev` de git concreto, que
tiene que coincidir exactamente con la versión que `rust-gpu` soporta — no son solo banderas
`#![feature(...)]` (`generic_const_exprs`, `step_trait` en `ab-proof-of-space-gpu/src/lib.rs:7`;
`portable_simd` en `subspace-proof-of-space-wgpu/src/lib.rs:7`), que sí serían nightly ordinario.
Además `subspace-proof-of-space-wgpu` depende de `subspace-core-primitives`, `subspace-erasure-coding`
y `subspace-kzg` — no se puede extraer sin traerse buena parte del monorepo.

### Lo que esto NO demuestra

- No es la GPU de la cita. Es de 2016; la conclusión sobre la cita es una extrapolación acotada
  (4-10 s), no una confirmación ni un descarte.
- Solo se usó **una cola** de la GPU, cuando el propio diseño soporta varias; el número medido es un
  piso para lo que una GTX 1070 podría dar, no un techo.
- No se perfiló el shader (sin `nsight` ni contadores de GPU en esta máquina), así que "ALU-bound
  vs ancho-de-banda-bound" queda como hipótesis doble, no resuelta.
- Se cronometró a mano (`Instant`, no `criterion`) por el límite de tiempo de una sesión — n=5, sin
  detección estadística de outliers de Criterion. La variación observada es baja (~4 % entre
  mínimo y máximo), así que no parece un problema de primer orden, pero es una diferencia real
  frente al rigor del banco de CPU.
- No se probó la GPU integrada AMD ni `llvmpipe` (el *fallback* de Vulkan por software) — ambas se
  enumeraron pero son irrelevantes para la pregunta de "GPU de alto rendimiento".
- No existe una ruta CUDA en este código: la vía oficial de Autonomys para GPU es Vulkan/Metal vía
  `wgpu`, no CUDA — a pesar de que la GTX 1070 de esta máquina también tiene `nvcc` disponible, no
  hay nada en el monorepo que lo use para esto.

**Limpieza:** los ficheros añadidos al clon para esta medición (`benches/plotting_gpu.rs`,
`examples/gpu_probe.rs`, `examples/plotting_gpu_manual.rs`, y la entrada `[[bench]]` correspondiente
en `crates/subspace-farmer-components/Cargo.toml`) se borraron al terminar; no quedan en el árbol.
