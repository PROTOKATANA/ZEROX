# PROCEDENCIA.md — de dónde sale cada cifra publicada

Toda cifra lleva **valor, unidad, definición de la variable, fuente, clase y estado**. Las clases
son las de `PROMPT.md` §10: `medido`, `verificado en fuente`, `citado`, `derivado`, `simulado`,
`propuesto`, `no determinado`, `no verificado`.

Máquina de todas las mediciones: **AMD Ryzen 9 9950X3D (Zen 5)**, 16 núcleos / 32 hilos,
`aes`+`vaes`+`avx512f` presentes, gobernador `powersave`, `amd_pstate=active`, TSC a 4,300 GHz
(medido en el propio binario: los dos relojes se leen a la vez). Hilos de cómputo usados: **1**
(`taskset -c 8`), francamente por debajo del tope de 4 del encargo y del de 24 de `LINEO.md` §7.

---

## 1 · Latencia de instrucción — `mediciones/latencia-aes/`

Comando: `taskset -c 8 ./aesinst --n-iter 2000000`.
Fuente: `salida-aesinst-core8-n2e6.txt`. **Clase: `medido`.** Los ciclos salen del contador de
rendimiento por hardware (`perf_event_open`, `PERF_COUNT_HW_CPU_CYCLES`), no de una frecuencia
supuesta.

| Variable | Valor | Unidad | Definición |
|---|---:|---|---|
| `lat(AESENC)` | **4,001** | ciclos | latencia de una ronda encadenada a sí misma, medida con PMU |
| `lat(AESENC)` | 0,7347 | ns | la misma, contra el reloj monótono |
| `lat(AESENCLAST)` | **4,001** | ciclos | idem para la ronda final |
| `lat(bloque PoT)` | **42,01** | ciclos | `pxor + 9·aesenc + aesenclast` encadenados, la dependencia exacta del PoT |
| `lat(bloque PoT)` | 0,7739 | ns | la misma, contra el reloj monótono |
| `thr(AESENC)` | 0,517 | ciclos/instrucción | rendimiento recíproco con 8 cadenas independientes |
| `lat(VAESENC ymm/zmm)` | 4,001 | ciclos | la anchura **no** cambia la latencia |
| `thr(VAESENC ymm/zmm)` | 1,000 | ciclos/instrucción | 512 bits por ciclo y puerto |
| Control `lat(PXOR)` | **2,000** | ciclos | control de coherencia: es la latencia tabulada de `PXOR` en Zen 4/5 |
| Reloj real bajo carga | 5,428 | GHz | derivado de ciclos/segundo del PMU |
| Reloj del TSC | 4,298–4,300 | GHz | medido en el mismo binario; **no** es la frecuencia del núcleo |

**Control de coherencia que se exigió a sí mismo el programa:** `lat bloque PoT` = 42,01 ciclos
frente a 10 × 4,001 + 2 = 42,0 esperados. El `pxor` de la cadena y el lazo aportan los 2 ciclos
restantes. La identidad `lat_bloque ≈ 10·lat_ronda` se cumple, y por eso la medición es aceptable.

---

## 2 · Reproducción del ancla de `medicion-previa/`

Comando: `taskset -c 8 ./aeslat` con el fuente **intacto** de
`P-ZRX/P-RELOJ/medicion-previa/aeslat.c`. Fuente: `aeslat-corridas.txt`.

| | Valor | Clase |
|---|---:|---|
| Publicado en `medicion-previa/MEDICION.md` | 7,7716 ns/bloque | `medido` (por Claude, 2026-09-24) |
| Reproducido aquí | **7,7230** ns/bloque | `medido` |
| Diferencia | **−0,63 %** | `derivado` |

La carga de entrada era 1,64–2,81 en las dos sesiones: la condición declarada («no ociosa») es la
misma, así que las dos cifras son comparables. **El ancla se reproduce.**

## 3 · Independencia de la latencia respecto de la frecuencia — `carga.c`

Comando: `./carga K 20000000`, con el hilo medido fijo en el core 8 y `K` hilos saturados en los
cores 16…15+K. Fuente: `salida-carga.txt`. **Clase: `medido`.**

| Hilos de carga | ns/bloque | **ciclos/bloque** | GHz del PMU |
|---:|---:|---:|---:|
| 0 | 7,7917 | **42,017** | 5,393 |
| 1 | 7,7290 | **42,011** | 5,435 |
| 4 | 7,7281 | **42,012** | 5,436 |
| 8 | 7,7546 | **42,011** | 5,418 |
| 16 | 7,8525 | **42,011** | 5,350 |

**El resultado, y es el que decide F3:** los **ciclos por bloque no cambian** (42,01 ± 0,004) con
carga de 0 a 16 hilos; lo que cambia un 1,6 % es la **frecuencia** (5,393 → 5,350 GHz). El tiempo
por bloque sube porque el reloj baja, **no** porque la ronda se haga más lenta.

## 4 · Asimetría producir/verificar — `verif8.c`

Comando: `taskset -c 8 ./verif8 300000 3`. Fuente: `salida-verif8.txt`. **Clase: `medido`.**
Mismo trabajo por las tres rutas: `8 tramos × 300 000 bloques`.

| Ruta | ns/bloque | ciclos/bloque | Factor frente a producir |
|---|---:|---:|---:|
| Producir (1 carril secuencial) | 0,9677 | 5,252 | 1,00× |
| Verificar, escalar (8 tramos en secuencia) | 7,7347 | 42,012 | 7,99× |
| Verificar, AVX-512+VAES (8 tramos en paralelo) | 0,9644 | 5,235 | 1,00× |

**Factor de paralelismo medido: 8,02×** (escalar/AVX-512), frente al valor ideal `K = 8`. La
verificación con 8 carriles cuesta **lo mismo por bloque** que producir un solo carril: la cadena no
se acorta (sigue siendo 10 rondas dependientes), se **multiplica**.

## 5 · Carriles y techo de la verificación — `verif16.c`

Comando: `taskset -c 8 ./verif16 400000 3`. Fuente: `salida-verif16.txt`. **Clase: `medido`.**

| Carriles en vuelo | ns/bloque | ciclos/bloque | ns por VAES-512 |
|---:|---:|---:|---:|
| 4 | 1,9189 | 10,506 | 1,1993 |
| 8 | 0,9603 | 5,252 | 0,3001 |
| 12 | 0,6409 | 3,501 | 0,1335 |
| **16** | **0,4829** | **2,627** | **0,0755** |
| 16 (solo AESDEC) | 0,4607 | 2,501 | 0,0720 |

Escala casi lineal hasta 16 carriles: 2,627 ciclos/bloque ⇒ 0,263 ciclos por instrucción VAES-512,
con 10 instrucciones por bloque. **Es la medición que fija la cota `K ≤ 16` de H2 en el informe.**

## 6 · Coste de verificar un slot, contraste con el repositorio

| | Valor | Fuente | Clase |
|---|---:|---|---|
| `verify_sequential_avx512f_vaes`, 1 slot | 92,097 ms | `veritas/rendimiento/coste-salto-v1/resultados/RESUMEN.md` §1 | `medido` |
| `verify_sequential_avx2_vaes` | 101,377 ms | íd. | `medido` |
| `verify_sequential_aes_sse41` | 190,498 ms | íd. | `medido` |
| AES por software real | 8 314,08 ms | íd. | `medido` |
| `prove`, 200 032 000 iteraciones | 1,561 s/slot | `research/dag-poas-ancla-de-orden.md:342` | `medido` |
| Asimetría `prove/verify` | ≈ 17× | derivado de los dos anteriores | `derivado` |
| **Verificar con 16 carriles (este encargo)** | **0,4607 ns/bloque** | `salida-verif16.txt` | `medido` |

## 7 · Fuentes externas citadas (abiertas, con URL)

| Afirmación | Fuente | Clase |
|---|---|---|
| `AESENC` xmm: latencia 4 en Zen 1–4; 3 en Golden Cove y Raptor Cove (Emerald Rapids) | [uops.info](https://uops.info/html-instr/AESENC_XMM_XMM.html), [Agner Fog, *Instruction tables*](https://www.agner.org/optimize/instruction_tables.pdf) pp. 96, 109, 122, 151, 375 | `citado` |
| Zen 4: `AESENC` latencia 4 / throughput 2 por ciclo, FP0/1 | hoja oficial AMD SOG 57647 (`Zen4_Instruction_Latencies_version_1-00.xlsx`) | `citado` |
| La fila resumen de uops.info para Zen 5 imprime latencia 3, en contradicción con sus propios datos crudos (APERF ≈ 4,05 por instrucción), con `AESDEC`/`AESENCLAST` de la misma tabla (4) y con la documentación AMD 58455 (4) | [datos crudos Zen 5](https://uops.info/html-lat/ZEN5/AESENC_XMM_XMM-Measurements.html) | `citado` |
| `MAX_FUTURE_BLOCK_TIME = 2*60*60` | `bitcoin/bitcoin@master`, `src/chain.h` | `citado` |
| MTP de 11 bloques (`nMedianTimeSpan = 11`) | íd., `src/chain.h`, `src/validation.cpp`; BIP-113 | `citado` |
| `enforce_BIP94 = false` en mainnet, testnet3 y signet | íd., `src/kernel/chainparams.cpp` | `citado` |
| Dificultad de Bitcoin al mínimo en 38 días con timewarp | BIP-54 | `citado` |
| Chia: sub-slot de 600 s, 64 signage points, umbrales 54 % / 42,7 % / 40,5 % | `research/chia-documentacion-oficial.md` §1.1, §3.2, §3.4 | `citado` |
| `set_pot_slot_iterations` exige `ensure_root` y es trinquete | `PDF/autonomys-subspace/crates/pallet-subspace/src/lib.rs:630-670` | `verificado en fuente` |
| `pot_slot_iterations` mainnet 206 557 520 con `TODO: Adjust once we bench PoT…` | `PDF/autonomys-subspace/crates/subspace-node/src/chain_spec.rs:128-130` | `verificado en fuente` |
| Una iteración del PoT = 9 `AESENC` + 1 `AESENCLAST` encadenadas | `PDF/autonomys-subspace/crates/subspace-proof-of-time/src/aes/x86_64.rs:22-33` | `verificado en fuente` |
| `N(s)` fuera de `C-POT-04` ⇒ `Pendiente`, nunca `Inválido` | `SPEC.md` §7.1.1, `C-POT-04` | `verificado en fuente` |
| El cambio de `N` entra en `t_j`, la inyección de entropía | `SPEC.md` §7.1.7, `C-FLU-16` | `verificado en fuente` |

## 8 · Lo que **no** se midió y no se presenta como medido

| Cosa | Clase |
|---|---|
| Los `4,841 ns/bloque` y `6,196 GHz` del 14900KS | `citado` (y `derivado`: 1 s entre 206 557 520, con el «1 s» de un **comentario de código**) |
| El reparto 40 vs 30 ciclos por bloque entre AMD e Intel | `derivado` de tablas publicadas + medición propia; la parte de frecuencia es `derivado` |
| La latencia de una CPU Intel de esta generación | **no medido**: no hay acceso a ese hardware |
| El coste de verificar **en una CPU sin AVX-512** | **no medido**: se declara la fórmula, no una tabla |
| `Δ` de red | **no medida** en este repositorio; `L_suelo_slots` sigue pendiente por eso |
| El techo real de un ASIC de AES | `estimado` (1,5–2,5× sin paper localizado), como ya decía `research/pot-aes-asic-chacha.md` §3 |
| La latencia de `AESENC` en función de los datos | **no verificado**: los controles usan una sola entrada, igual que uops.info |
