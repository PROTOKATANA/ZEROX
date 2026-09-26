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
| Oráculo de transición T01 | `P-ZRX/P-TRANSICION/T01/` | `f62c879` | `2ed91d3652493678` | `REVISION-T01…T01-E`, `P-SLASHING/REVISION-SL3b.md` | CONTRATO-v0 v0.1 + FORMATO v0.1 + evidencia (RAT-2′): 29,5 M historias, 0 fallos; genera los vectores v0.4 | Rejilla pequeña; semilla y generador declarados en su `METODO.md` |
| Oráculo de estado DAG T04 | `P-ZRX/P-DAG/T04/` | `f62c879` | `4f037ea4d70cb059` | `REVISION-T04…T04-D`, `REVISION-SL3b.md` | Contrato de estado DAG, IE-1…IE-6 (46 500 bloques, 600 000 órdenes, 0 fallos); genera los vectores v0.5 | Máximo 3 padres en el generador |
| Oráculo de formato v0.1 | `P-ZRX/P-FORMATO/oraculo-formato-v0.1/` | `ccf4b6d` | `998525aba1454555` | `REVISION-W02b.md` | Codificación y forma de FORMATO v0.1 (85/85) | Sin `EvidenceTx` v4 (la cubren T01/T04 v0.4/v0.5) |
| Modelo adversarial T02 | `P-ZRX/P-TRANSICION/T02/` | `49e4434` | `e05a57a9691d97b8` | `REVISION-T02.md`, `CORRECCION-T02-A.md` | Selección a través del corte (FC-1…FC-4), RFT-13, censura de depósitos (IPA A-08) | Sin latencia ni retarget |
| Modelo de disuasión DS-3 | `P-ZRX/P-DISUASION/DS3/` | `54add85` | `688b622e36141b6a` | `REVISION-DS3.md` (aceptada con reparos) | Coste mínimo por ataque y mecanismo; cuatro vías coinciden en 4 216 celdas | Escenarios hipotéticos en u.e.; mezcla de magnitudes F5 (SL-2) |
| Calibración del castigo SL-2/SL-2b | `P-ZRX/P-SLASHING/SL2/` | `46562ff` | `688b622e36141b6a` | `REVISION-SL2.md`, `REVISION-SL2b.md` | Región de parámetros no vacía; valores dev; 97/97 tests; con `s = 0` reproduce SL-2 bit a bit | Parámetros dev, no producción |
| Cálculo de la capa de votos FV-1 | `P-ZRX/P-FINALIDAD-VOTOS/resultados-FV1/calc/` | `bfc40b9` | `622db153743968a9` | `REVISION-FV1.md` (aritmética rehecha por el director) | Umbrales de pausa y sello con prima `b` (RFT-17) | Sin latencia real (`T_instancia` sin medir) |
| Cálculo de la falta de ausencia AV-1 | `P-ZRX/P-AUSENCIA-VOTO/resultados-AV1/calc/` | `98ceea8` | `b3fd0c5957d706bd` | `REVISION-AV1.md` | Coste de pausa con `m_aus` fijo y proporcional (RFT-20) | Unidades hipotéticas |

## 2. Vectores de prueba (leídos por los crates)

| Vectores | Ruta | Commit | Huellas (primeros 16 hex) | Generador | Consumidor |
|---|---|---|---|---|---|
| Transición v0.4 (2 795 casos) | `testdata/transicion-v0.4/` | `69cfaa4` | vectores `4f0a175a3b4390e4`, cobertura `f0a7baef80828545` | T01 (`f62c879`) | `zx-consensus/tests/diferencial_t01` |
| Estado DAG v0.5 (1 878 casos) | `testdata/estado-dag-v0.5/` | `69cfaa4` | vectores `c7de88de1fa8755f`, cobertura `9c67f230989b2a51` | T04 (`f62c879`) | `zx-cadena/tests/diferencial_t04` |
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
| Slot PoT con `N_dev` real | 1,66 s por slot (60 slots en 99,5 s) | Máquina con carga ajena posible; `SR_dev` sin calibrar | `P-ZRX/P-NODO/resultados-W06d1/` | `REVISION-W06d1.md` — **provisional**: W07 la repite en reposo |

## 4. Pendiente de entrar

Mediciones de W07 (latencia, `Δ`, recursos, reinicio; `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md`); la plantilla
Julia de LINEO (`veritas/plantilla/`, IPA E-05) solo tras validarse aquí.
