# V-ZRX — registro de instrumentos validados y mediciones verificadas

**Abierto:** 2026-09-26 22:25. **Mantiene:** Claude (director, `AUTO-ZRX.md` §5.6). **No toca** `V-ZRX/LINEO.md`
(documento de Katana).

**Qué entra aquí** (`AUTO-ZRX.md`): solo instrumentos que pasaron revisión y se reproducen, y mediciones
verificadas con sus condiciones. Un número que aparece en un informe no entra por aparecer.

**Por qué es un registro y no una copia.** Los instrumentos se quedan donde se validaron: las órdenes en
curso congelan su entrada por ruta y hash (`ENTRADA-*.sha256`), los crates leen `testdata/` y las revisiones
citan esas rutas. Moverlos rompería esas referencias; copiarlos crearía dos versiones que pueden divergir.
Este registro fija **qué versión** está validada (commit y huella), **cómo** se reproduce y **con qué
límites**. Cualquier cambio posterior en una ruta registrada invalida la fila hasta una revisión nueva.

## 1. Oráculos y modelos (Julia 1.13.0, LINEO)

Reproducción común: desde la carpeta del instrumento, `julia --project -e 'using Pkg; Pkg.test()'` y
`julia --project -t 4 run.jl` con la versión fijada en su `julia-version.toml`. `Manifest.toml` fija las
dependencias (huella: primeros 16 hex de `sha256`).

| Instrumento | Ruta | Commit | `Manifest.toml` | Validado por | Qué garantiza | Límites |
|---|---|---|---|---|---|---|
| Oráculo de transición T01 | `P-ZRX/P-TRANSICION/T01/` | `433f192` | `2ed91d3652493678` | `REVISION-T01…T01-E`, `P-SLASHING/REVISION-SL3b.md`, `REVISION-SL4c-O.md` | CONTRATO-v0 v0.1 + FORMATO v0.1 + evidencia (RAT-2′): 29,5 M historias, 0 fallos; genera los vectores v0.4 | Rejilla pequeña; semilla y generador declarados en su `METODO.md` |
| Oráculo de estado DAG T04 | `P-ZRX/P-DAG/T04/` | `433f192` | `4f037ea4d70cb059` | `REVISION-T04…T04-D`, `REVISION-SL3b.md`, `REVISION-SL4c-O.md` | Contrato de estado DAG, IE-1…IE-6 (46 500 bloques, 600 000 órdenes, 0 fallos); genera los vectores v0.5 | Máximo 3 padres en el generador |
| Oráculo de formato v0.1 | `P-ZRX/P-FORMATO/oraculo-formato-v0.1/` | `ccf4b6d` | `998525aba1454555` | `REVISION-W02b.md` | Codificación y forma de FORMATO v0.1 (85/85) | Sin `EvidenceTx` v4 (la cubren T01/T04 v0.4/v0.5) |
| Modelo adversarial T02 | `P-ZRX/P-TRANSICION/T02/` | `49e4434` | `e05a57a9691d97b8` | `REVISION-T02.md`, `CORRECCION-T02-A.md` | Selección a través del corte (FC-1…FC-4), RFT-13, censura de depósitos (IPA A-08) | Sin latencia ni retarget |
| Modelo de disuasión DS-3 | `P-ZRX/P-DISUASION/DS3/` | `54add85` | `688b622e36141b6a` | `REVISION-DS3.md` (aceptada con reparos) | Coste mínimo por ataque y mecanismo; cuatro vías coinciden en 4 216 celdas | Escenarios hipotéticos en u.e.; mezcla de magnitudes F5 (SL-2) |
| Calibración del castigo SL-2/SL-2b | `P-ZRX/P-SLASHING/SL2/` | `46562ff` | `688b622e36141b6a` | `REVISION-SL2.md`, `REVISION-SL2b.md` | Región de parámetros no vacía; valores dev; 97/97 tests; con `s = 0` reproduce SL-2 bit a bit | Parámetros dev, no producción |
| Cálculo de la capa de votos FV-1 | `P-ZRX/P-FINALIDAD-VOTOS/resultados-FV1/calc/` | `bfc40b9` | `622db153743968a9` | `REVISION-FV1.md` (aritmética rehecha por el director) | Umbrales de pausa y sello con prima `b` (RFT-17) | Sin latencia real (`T_instancia` sin medir) |
| Cálculo de la falta de ausencia AV-1 | `P-ZRX/P-AUSENCIA-VOTO/resultados-AV1/calc/` | `98ceea8` | `b3fd0c5957d706bd` | `REVISION-AV1.md` | Coste de pausa con `m_aus` fijo y proporcional (RFT-20) | Unidades hipotéticas |
| Analizador de registros del nodo (W07c + W07c-B) | `P-ZRX/P-MEDICION/analisis-registro-v1/` | `6a7292c` (W07c en `fe77b4a`) | `22327796a9e8100c` | `P-ZRX/P-MEDICION/REVISION-W07c.md` (§ W07c-B); reejecutado en W07b (525 aserciones en verde) | Métricas del esquema de registro v1 (§3): latencias por pareja con recuento comprobado a mano, divergencia, rechazos, admisión frente a profundidad, recursos; **W07c-B**: un bloque cuenta una vez por `hash` y los slots vacíos entran | Solo analiza lo que el nodo registra; el estado final solo es comparable tras un reposo |
| Arnés de procesos reales (W07b) | `P-ZRX/P-MEDICION/resultados-W07b/scripts/` (bash; los datos crudos en `deepseek/W07b/run/` con `HUELLAS.sha256`) | `60d2446` (guiones), `305cbf8` (E-0 final) | — (sha256 conjunto de los `.sh`: `31c0696db131bc25`) | `P-ZRX/P-MEDICION/REVISION-W07b.md` | Receta E-0 desde un clon limpio; escenarios E-1…E-9 con una clave por nodo (3 por lado en E-6b y E-9); partición con **aislamiento verificado** (puerto nuevo, 0 contactos cruzados); **veredicto de mismo estado W07d**: reposo, reabrir cada nodo aislado sobre una **copia** de sus datos y comparar `resumen_estado` y `compendio_bloques` | Localhost y un reloj; hasta 4 nodos; los guiones asumen `127.0.0.1` y los puertos que usan |

## 2. Vectores de prueba (leídos por los crates)

| Vectores | Ruta | Commit | Huellas (primeros 16 hex) | Generador | Consumidor |
|---|---|---|---|---|---|
| Transición v0.4 (2 795 casos) | `testdata/transicion-v0.4/` | `69cfaa4` | vectores `4f0a175a3b4390e4`, cobertura `f0a7baef80828545` | T01 (`f62c879`) | `zx-consensus/tests/diferencial_t01` |
| Estado DAG v0.5 (1 878 casos) | `testdata/estado-dag-v0.5/` | `69cfaa4` | vectores `c7de88de1fa8755f`, cobertura `9c67f230989b2a51` | T04 (`f62c879`) | `zx-cadena/tests/diferencial_t04` |
| **Transición v0.5 (3 179 casos; vigente)** | `testdata/transicion-v0.5/` | `ec9c6b9` | vectores `d72c5fd9bd9a988d`, cobertura `3bc430c35a2f28f5` | T01 (`433f192`, SL-4c-O/-B/-C) | `zx-consensus/tests/diferencial_t01` (0 discrepancias, SL-4c-R) |
| **Estado DAG v0.6 (2 108 casos; vigente)** | `testdata/estado-dag-v0.6/` | `ec9c6b9` | vectores `86348a48e32491c9`, cobertura `2839de9749857b47` | T04 (`433f192`, SL-4c-O/-B/-C) | `zx-cadena/tests/diferencial_t04` (0 discrepancias, SL-4c-R) |
| Formato v0.1 | `testdata/formato-v0.1/` | — | vectores `8dadda90384928e8` | oráculo de formato v0.1 | `zx-core` |
| NIST CAVP SHA3-256 | `testdata/nist-cavp/` | — | ver `R-ZRX/MAPA-RESCATE.md` §1 | fuente externa | `zx-core` |

Cada carpeta lleva su `.sha256`; `sha256sum -c` desde la carpeta la verifica. Resultado vigente de los
diferenciales: **0 discrepancias** con cobertura idéntica a la del oráculo (`P-SLASHING/REVISION-SL4a.md`).

## 3. Mediciones verificadas

| Medición | Valor | Condiciones | Evidencia | Revisión |
|---|---|---|---|---|
| Hashrate PoW dev (SHA3-256), GPU | **561 084 507 H/s** en régimen; 109,0 W; **1,94·10⁻⁷ J/hash** (solo la tarjeta) | GTX 1070 (Pascal, 2016), NVRTC 12.9 `compute_61`, estrangulamiento térmico a ~85 °C; volcados CPU = GPU idénticos (10⁶ digests) | `P-ZRX/P-POW/resultados-A10-M1/` (`HUELLAS.sha256` `39adfda90acbe1e2`) | `REVISION-A10-M1.md` |
| Hashrate PoW dev, CPU | 73,8 MH/s en reposo, 16 hilos (SMT no aporta); GPU/CPU = 7,6× | AMD 9950X3D; la medida con carga ajena (68,5 MH/s, 32 hilos) queda como provisional | ídem, `CORRECCION-A10-M1-B.md` | `REVISION-A10-M1.md` |
| Regenerar un registro PoAS en GPU | **0,0545 s/registro**, 18,37 registros/s, 95,5 W, 5,24 J/registro; ≈ 7,1 GTX 1070 y ≈ 677 W por TiB | Tabla **v2** de Autonomys (ZEROX usa v1; en CPU 0,921 frente a 0,9006 s/registro); CPU = GPU en 1 000 registros | `P-ZRX/P-DISUASION/resultados-DS4/` (`HUELLAS.sha256` `e50552a984b5e6e0`) | `REVISION-DS4.md` |
| Espacio en claves sin saldo en un pool real | `B = 1,78·10⁻⁴` [1,49·10⁻⁴; 2,08·10⁻⁴] (`ε = 0,01`, `T_v = 3 600`, pool como denominador) | 2 470 granjeros de un pool público de Chia; cálculo empírico sin ajuste | `P-ZRX/P-DISUASION/resultados-DS6/farmers-raw.csv` (`a18b7738fc015a7b`) | `REVISION-DS6.md` (tras la Corrección A) |
| Slot PoT con `N_dev` real | 1,66 s por slot (60 slots en 99,5 s) | Máquina con carga ajena posible; `SR_dev` sin calibrar | `P-ZRX/P-NODO/resultados-W06d1/` | `REVISION-W06d1.md` — **provisional**; W07b dio 1,28 s (fila siguiente), sin explicar la diferencia |
| Slot PoT con `N_dev` real, en red | **1,28 s por slot** (τ medido en la calibración de E-2a) | Tres nodos reales en `127.0.0.1`, AMD 9950X3D (32 hilos), `N_dev = 138 873 760`; **no concuerda** con el 1,66 s de W06d1 en la misma máquina (causa no investigada) | `P-ZRX/P-MEDICION/resultados-W07b/INFORME.md` §2 | `REVISION-W07b.md` |
| Calibración de `SR_dev` | `13043817825332783104` (2^63,5) → **0,99 bloques por slot** | 4 puntos de bisección, ventanas de 200·τ; una clave por nodo | ídem §2 | `REVISION-W07b.md` |
| Coste por bloque en la ruta del nodo (R1, régimen, 3 repeticiones) | Cabecera (PoST + PoT) p50 66–68 ms, p95 133–192 ms; admisión GHOSTDAG p50 0,09 ms (0–499 bloques) → 0,44 ms (1 500–1 999); persistencia p50 0,84 ms | `26312ff`; instrumento W07c-B | `resultados-W07b/analisis/R1-rep{1,2,3}/` | `REVISION-W07b.md` |
| Propagación productor → admisión | p50 ≈ 170 ms, p95 ≈ 0,35–0,42 s, máx. ≈ 1,2 s entre nodos vivos (`Δ_p99` sin calcular) | Localhost, incluye la verificación | ídem | `REVISION-W07b.md` |
| Reinicio, nodo tardío y reunión | Reinicio tras `SIGKILL` ≈ 104 s (p50) y puesta al día ≈ 118 s; nodo tardío al día en ≈ 60–64 s; reunión tras partición PoST ≈ 12 s | R1 y R2 con `26312ff`; R3 con `3d21b1f` | `resultados-W07b/INFORME.md` §3 | `REVISION-W07b.md` |
| Recursos por nodo | RSS 0,79 GiB (p50) – 1,48 GiB (máx.); CPU p50 ≈ 1,2–1,3 s/s | R1 | `resultados-W07b/analisis/` | `REVISION-W07b.md` |
| Castigo de la doble firma en procesos reales | Confiscación total (`activo = 0`) en los tres nodos, 3/3; autodenuncia en rep1 (remanente congelado 93) | `3d21b1f`, `f = 1` | `resultados-W07b/run/R4-rep*/e7e8/e8-evidencia.txt` | `REVISION-W07b.md` (comprobado por el director en el estado) |
| Penalización del par en gossip | 4/4 vectores inválidos penalizados por repetición (3 repeticiones), 0 desconexiones honestas; 0 falsos positivos en 3 redes al slot 150 y una partición | W06d10 y W06d10-B | `P-ZRX/P-NODO/resultados-W06d10{,-B}/` | `REVISION-W06d10.md`, `REVISION-W06d10-B.md` |
| E-0 del candidato final `c107163` | 891/0/6 en 85 binarios; fmt, clippy, guardianes y release verdes; humo de tres nodos con el mismo estado | Clon limpio, Autonomys `f8842d0` | `resultados-W07b/run/e0-c107163-resumen.txt`, `humo-c107163-paradas.jsonl` | `REVISION-W07b.md` (anexo) |


## 4. Pendiente de entrar

`Δ_p99` (el instrumento da p50, p95 y máximo); la causa de 1,66 s frente a 1,28 s por slot; `t_iter` de AES en
varias CPU (`ρ_max`, 0.0.2 paso 1); la plantilla Julia de LINEO (`veritas/plantilla/`, IPA E-05), solo tras validarse
aquí. **Actualizado:** 2026-09-28 (mediciones de W07b, W06d10 y la E-0 final).
