# Mapa vivo de rescate del ZEROX antiguo

**Abierto:** 2026-09-26. **Mantiene:** Claude (director técnico, `AUTO-ZRX.md` §2 «Rescate
progresivo»). Cada fila clasifica una **pieza** o una **afirmación**, no un directorio.

**Categorías** (`AUTO-ZRX.md` §2): **sobrevive** (mismo contrato y supuestos) · **adaptar**
(cambió interfaz, formato o regla) · **condicional** (a un adversario o parámetro que cambió) ·
**refutado** · **obsoleto** (regla eliminada) · **pendiente de reproducir**. Una clasificación
«sobrevive» sin reproducción es provisional: se confirma solo tras una orden ejecutada.

**Origen.** Archivo `/home/katana/zeo/.trash/zerox/` (no es repositorio git). Comprobado
2026-09-26: los blobs de código coinciden con el commit `9681061` del repositorio (4 657/4 662
según la memoria de sesión anterior; 26 de 26 documentos citados aquí verificados uno a uno:
23 idénticos a git, 3 solo en `.trash`, ahora copiados en `R-ZRX/LEGADO/`). Las piezas se extraen
de **git `9681061`** para tener procedencia verificable; el clon de Autonomys
(`PDF/autonomys-subspace`, no versionado) se lee en el archivo, fijado en
`f8842d019cdf0f7163421b9644db5a9ff82b2a73` (`git rev-parse HEAD` del clon, 2026-09-26).

**Unidad de reproducibilidad del código antiguo.** `Cargo.toml` (sha256 `619d4950b3bef5e5fa771d3f1a3e6e635f0a18f4d88962a950a2c12261bc2495`),
`Cargo.lock` (`9021465df73c82c1e5c97d1ad00305e3c85494fc68d4d54bf4fb28ca49612b59`, 496 paquetes),
`rust-toolchain.toml` (`604b0c1bfdae30f1a0075734760c954072de325b6bf319b8b73790364ebb874e`,
`nightly-2026-05-03`, instalada en esta máquina) y el clon de Autonomys forman una unidad: copiar un
crate suelto no reproduce sus pruebas (`P-ZRX/PLAN-ARRANQUE-HIBRIDO.md` §2). Licencia del workspace:
`AGPL-3.0-or-later` declarada en `Cargo.toml`, **sin archivo LICENSE**; crates de Autonomys `0BSD`
(campo `license`); dependencia git `grandinetech/rust-kzg` rev `8f5f1a0f73b3c529c77cb880ff8d265830c7d7ac`
(`Cargo.lock:1977, :3421`). `caliza/` y `silicio/` sin licencia.

---

## 1. Código y datos

Sha256 del manifiesto de cada crate (`sha256sum crates/*/Cargo.toml` en el archivo, 2026-09-26).
Líneas de código de `wc -l` sobre `src/` + `tests/`.

| Pieza | Hash (manifiesto) | Qué conserva | Acoplamiento al consenso viejo | Clasificación | Siguiente acción |
|---|---|---|---|---|---|
| `zx-core`: SHA3 con dominio (`hash.rs:93-98`), codificación, tx, Merkle, firmas | `9e801865…60937a4` | Primitivas y vectores | Etiquetas de dominio de la red vieja | **reproducido** (L01: 156/156) → *sobrevive* salvo adaptación de formato | W01 (portado) |
| `testdata/nist-cavp/` (ShortMsg `e75b1ded…`, LongMsg `741b75d0…`, Monte `0b387d75…`) | — | Oráculo **independiente** NIST para SHA3-256 | ninguno | **sobrevive** (fuente externa) | Copiar al workspace nuevo con su README |
| `zx-core/src/preimage/block.rs` + `target.rs` (PoW lineal: preimagen de 108 B, nonce en 96, `hash < target` U256 big-endian, compact bits, `POW_LIMIT = 2^224−1`) | (en `zx-core`) | Verificador PoW | Cabecera lineal de 92 B con `height: u32`; bits iniciales de la red vieja | **adaptar** | Contrato PoW nuevo (A-12) antes de portar |
| `zx-consensus/src/dificultad.rs` (LWMA-1 en U512) | `22e2aef1…d39434c` | Algoritmo de retarget | `T = 120`, `N = 90` y constantes derivadas (`:47-71`) incoherentes con la emisión recalibrada a λ = 1 | **adaptar**; constantes **obsoletas** | Re-derivar tras elegir intervalo (A-02, A-12) |
| `fork_choice.rs` (mayor trabajo, desempate por hash) | (en `zx-consensus`) | Selección PoW (contrato de D-T01) | `MAX_REORG_LENGTH = COINBASE_MATURITY − 1` (`:42`) | selección **sobrevive** como contrato; límite de reorg **obsoleto** | Oráculo T01 fija el contrato; portado después |
| `emision.rs` (`SHIFT = 26`, `COINBASE_MATURITY = 12 000`) | (en `zx-consensus`) | Forma de curva | Calibrado a λ = 1 bloque/s de la red vieja | **obsoleto** como parámetro; forma **condicional** | A-02 |
| `zx-pot` + `tests/vectores-nightly.txt` (32 vectores, `023a9fc8…6b53fc15`) | `ea44e771…bd5f85` | PoT AES de Autonomys en Rust estable | ninguno en la primitiva | **reproducido** (L01: 5/5, 32 vectores) → *sobrevive* | W01 (portado) |
| `zx-consensus/src/pot.rs` (`semilla_genesis` = `C-FLU-06`), `pot_rango.rs` | (en `zx-consensus`) | Adaptadores y verificador de rango | Semilla desde el génesis DAG; `S_max = 150` | **adaptar** (TRN-08 del CONTRATO) | Tras T01/T03 |
| `zx-core/src/wire_dag.rs:375-380` `verificar_justificacion_pot` | (en `zx-core`) | — | Devuelve **siempre** `IntegracionPotPendiente` | **adaptar** (no es verificador) | Portado con integración PoT |
| `zx-consensus/src/poas.rs:309-328` (`verify_solution::<ChiaTable,_>` de Autonomys) | (en `zx-consensus`) | Verificador PoAS real | Formato Autonomys `f8842d0`; `piece_check_params` obligatorio | **reproducido** (L01-C1: `tests/poas.rs` dentro de 421/421 de `zx-consensus`) | portado en W05 |
| `zx-node/src/farmer.rs` (plotter/auditor, feature `farmer`) + `tests/farmer_disco.rs` (13 tests) | `e5564b3c…c2753f633` | Ploteo y auditoría reales | Parámetros dev (`history_size = 1`, 2 piezas/sector, `historia_dag_dev.rs:29-75`) | pieza **reproducida** (L01: `farmer_disco` 13/13); parámetros **obsoletos** | portado en W05 |
| `zx-consensus/src/ghostdag.rs` + oráculos (GDR-v0.2, vectores rusty-kaspa) | (en `zx-consensus`) | GHOSTDAG con modos Zerox/Kaspa | `k = 30`, 15 padres, mergeset 180, `S_max = 150` (`:68-74`); almacén en memoria; no integrado en el nodo | algoritmo **reproducido** (L01-C1, oráculos incluidos); constantes **condicionales** | portado en W05 |
| `zx-core/src/preimage/dag.rs` (cabecera DAG 589–1037 B) | (en `zx-core`) | Códec canónico | Campo `HEIGHT` (`:51`); sin campos de garantía/transición | **adaptar** | Tras decidir formato post-corte |
| `zx-storage/src/utxo.rs` (`UndoData`, `aplicar_bloque`, `revertir_bloque`) | `fe713883…6fe` | Conservación y rollback | Indexado por altura (`almacen.rs:64`) | **adaptar**; base **reproducida** (L01-C1: 60/60 con `rocksdb`, incluido `matar_a_mitad`) | Contrato de estado T01 → W03 |
| `zx-consensus/src/firmante/` (registro durable, firmar tras `sync_all`) | (en `zx-consensus`) | Defensa operativa `C-EVP-06` | Identidad de billete vieja | **adaptar**: `FIR-*` del contrato de evidencia; portado en SL-4b | C-09 |
| `genesis.rs`, `genesis_dag.rs` | (en `zx-consensus`) | Génesis constructivo | Génesis DAG separado (contrario a D-T02) | **adaptar** | Tras T01 |
| `cabecera_conjunta.rs` (puerta conjunta PoT→sello→AES→SR→PoAS) | (en `zx-consensus`) | Orden de validación `C-POT-08` | Sin pasado causal ni garantía | **adaptar** | Integración B-08 |
| `zx-node` `cadena.rs`, `sync.rs`, `contextual.rs`, `nodo.rs` | (en `zx-node`) | Ingeniería de nodo | Lineales; LWMA cableado (`contextual.rs:73,159`) | **obsoleto** como ruta activa; referencia | — |
| `zx-node` módulos `*_dag_dev.rs` y `puerta_primer_hijo_dag_dev` | (en `zx-node`) | Fixture PoT + PoAS + sello + cuerpo | `N = 200_032_000`, `SR = u64::MAX` (`perfil_primer_hijo_dag_dev.rs:79,87`) | fixture **pendiente de reproducir**; perfil **obsoleto** | `ORDEN-L01` (opcional, acotado) |
| `zx-node/tests/tres_nodos.rs` | (en `zx-node`) | Diseño de arnés `MemoryTransport` | 4 de 7 tests `#[ignore]` (P-031; el doc dice «tres») | **adaptar** como diseño de arnés | B-08 |
| `zx-p2p` (libp2p, relé compacto) | `60bebcf5…bbcc2` | Transporte | Límites de cabecera de 92 B (`limites.rs:166,268,377`) | **adaptar** tras fijar mensajes | B-08 |
| `zx-mempool` | `307268380e2671d08c86e023b181be95eb8968d948c5d69bea50ff5ae137e500` | Pool y tarifas | — | **adaptar** | Más tarde |
| `zx-rpc`, `zx-wallet`, `zx-scanner`, `zx-lightwalletd` | `a995f054…`, `e5371da1…`, `28a7abd6…`, `d791552e…` | Esqueletos de 5–7 líneas | — | **obsoleto** (sin contenido) | — |
| `prototipos/pot-estable` | `0fd0d66e…8e52` | Origen de `zx-pot` | — | referencia | — |
| `prototipos/poas-identidad` (K = 20, fixture `73a9ec14…`) | `b4a3419f…64982` | Generador del fixture PoAS | — | **pendiente de reproducir** | `ORDEN-L01` |
| `prototipos/autorizacion-contextual` (DAV-v0.1) | `6bd29288…8f5532` | Prototipo de dominio | No lo usa el nodo | **pendiente** de evaluar | Sin prioridad |
| `/home/katana/zeo/.trash/caliza/` (kernel HIP/CUDA) | `CMakeLists.txt` `2719507c…4469` | Ideas de kernel GPU | Keccak crudo sin relleno/dominio; nonce 48–55; criterio de bytes cero; `caxor/proto` ausente; carrera y `__syncthreads` en rama divergente | **condicional**; como minero, previsto **descartar** | A-11 (`ORDEN-L02`) |
| `/home/katana/zeo/.trash/silicio/` (bucle Rust) | `Cargo.toml` `4bb94e90…80ae` | — | `minero.rs` no se compila; nonce u128 al final; sin comparación de target | previsto **descartar** | A-11 |
| `ci/alcance-consenso.sh`, `citas-spec.sh`, `dependencias-exactas.sh`, `frontera-crates.sh` (+ listas) | `df662074…`, `fdda9063…`, `3ca92bd8…`, `7f829b6e…` | Ideas de guardianes: consenso sin llamar, reglas sin citar, versiones exactas, frontera de crates | Apuntan a `SPEC.md` y crates viejos; heurísticas grep (contaban llamadas de tests como uso) | **adaptar** como diseño; los scripts no se reutilizan tal cual | E-03 |
| `.github/workflows/zerox-ci.yml` (en el árbol nuevo) | — | — | Llama a archivos borrados | **obsoleto** | E-03 |
| Instrumentos Julia de `veritas/` (GDR, vectores de cabecera DAG, espacio-tasa…) | por instrumento | Oráculos y resultados | Modelos de la red vieja | **pendiente de reproducir** caso por caso | Solo cuando una decisión los necesite |
| Instrumentos Python históricos (`research/scripts/*.py`) | — | Evidencia para portar modelos | — | solo inspección; **no se ejecutan** (`AUTO-ZRX.md` §2) | — |

---

## 2. Afirmaciones y resultados

Refutaciones vigentes: ver `D-ZRX/RFT-ZRX.md` (RFT-01…RFT-12); aquí solo su clasificación y los
casos que **no** entraron en RFT.

| Afirmación antigua | Fuente (archivo) | Clasificación | Por qué | Siguiente acción |
|---|---|---|---|---|
| Doble farmeo no se cierra sin dejar de ser PoST puro; stake no crea evidencia | `ESTADO-DOBLE-FARMEO.md` (`a667b25a…`), `P-STAKE/MAPA.md` | **sobrevive** | Hasta el sello no hay evidencia; la capa de votos adoptada en principio (FV-D02) acota el tiempo, no lo cierra; ningún mecanismo de PoStake ni de Filecoin lo encarece de forma exigible (P-DISUASION) | RFT-01, RFT-14 |
| `κ = 0` con `m = 4` bajo identidad `C-GD-07` | `P-EQUIVOCACION` (`c4720eab…`) | **sobrevive** | `C-EVP-01` usa esa identidad | RFT-02 |
| Corolario 4 (ningún compromiso fecha nada); Cor. 1 (regenerado indistinguible) | `P-COBERTURA` (`63935b0d…`) | **sobrevive** | No dependen del consenso | RFT-03, RFT-04 |
| Retención por clave no disuade: claves de saldo cero, soborno cero | `P-CLAVE` (`74d512be…`) | **condicional** | `C-BON-04` exige `requisito > 0`: retira la premisa «claves gratis». Queda R-5 (coste fijo solo domina bajo un tamaño) | **Medido 2026-09-26:** con cola larga de claves diminutas el castigo no encarece (Δ = 0, DS-3); con el reparto real de un pool de Chia la grieta se cierra (DS-6) y la región de parámetros no es vacía (SL-2, SL-2b). Queda condicional al reparto de ZEROX, no medido. RFT-14 |
| `α* = (1 − β_d − 2β_x)/2` | `P-PRESTAMO` (`cf020a69…`) | **sobrevive** (identidad) | — | Usar en C-02/X-01 |
| Pools producen con espacio ajeno; atar coinbase a `sol.public_key` quita el premio, no la capacidad | `P-POOLS` (`bfac1d85…`) | **adaptar** | `C-BON-03` ya ata la coinbase: **implementado** en la puerta conjunta (`zx-post::cabecera_conjunta`, coinbase v3 a `sol.public_key`); falta la arquitectura | IPA B-06 |
| Pata PoW concurrente aditiva no baja `V` con `θ` | `P-RIVAL` (`8488417a…`) | **sobrevive** como advertencia; **no aplica** al arranque (no hay PoW tras el corte) | Premisa «PoW concurrente» ausente | RFT-09 |
| «No evaluar PoW de arranque (Decred)» | `R-ZRX/LEGADO/stake/MAPA.md` §5 | **obsoleto como recomendación** por instrucción vigente de Katana (`AUTO-ZRX.md`, `D-ZRX/SPEC.md` C-BOT-04); la **preocupación** (concentración de emisión PoW, DCP-0012) **sobrevive** | Las instrucciones actuales prevalecen | IPA A-10 |
| Arranque sin PoW con requisito ∝ oferta circulante | `R-ZRX/LEGADO/stake/MAPA.md` §4 | **condicional** | Comparador, no ruta elegida | IPA X-02 |
| «Una pata de PoW pequeña la domina un Estado y controla la entropía del ancla» | `T-ZRX/AGUJEROS-Y-SOLUCIONES.md` (`81ae2c92…`), lectura de Claude sin validar | **condicional** (hipótesis) | Aplica a la semilla del corte | IPA A-07 |
| Sembrador ≈ 100× peor que comprar disco (CPU; GPU sin medir); ploteo 83,6 s/GiB | `P-INTENTO` (`d7630deb…`), `research/coste-ploteo-medido.md` (`e4b7cbf7…`) | **reproducido y ampliado** (DS-4, 2026-09-26): GPU medida, 0,0545 s/registro en GTX 1070 con la tabla v2 ⇒ ≈ 7,1 GPU y ≈ 677 W por TiB frente a ≈ 5 W de almacenar | CPU 0,921 s/registro (coherente con S02a); la GPU es de la tabla v2, no la v1 de ZEROX | D-02, RFT-04, `V-ZRX/REGISTRO.md` |
| `ρ_max = ε·K`, `K = 16` medido (VAES), `AESENC` 4,001 ciclos | `R-ZRX/LEGADO/reloj/ESTADO-RELOJ.md` | **sobrevive** como medida de esa máquina; **pendiente** para hardware objetivo | Física de la CPU | B-02 |
| Ventana de adelanto no anulada con segundo VDF | `P-REVELACION` (`2abfab32…`), `P-SEGUNDO-VDF` (`70bcd723…`) | **sobrevive** (refuta P-ADELANTO) | — | RFT-12 |
| Ocupación bimodal de s-buckets (9,0668 % vacíos) y molienda de clave | `LIBRO-DE-RESTRICCIONES.md` R-12 | **sobrevive** para el formato `f8842d0` | — | IPA B-09 |
| Eclipse > `F` fabrica partición pagando IP | `R-ZRX/LEGADO/eclipse/INFORME.md` | estructura **sobrevive**; cifras **no transferibles** (lo dice el propio informe) | Red no implementada | IPA B-07 |
| `C-FIN-01` acota el doble farmeo a `d < F_slots` | `SPEC.md` antiguo | **sobrevive** como candidata | — | Usada en TRN-09 |
| Constantes `T = 120`, `N = 90`, `SHIFT = 26`, `12 000`, `k = 30`, `S_max = 150`, `F = 2 h`, `N = 200_032_000`, `SR = u64::MAX` | `SPEC.md` antiguo, crates | **obsoleto** como parámetro (`PLAN-ARRANQUE-HIBRIDO.md` §3) | Decisiones o medidas de otra red | Re-derivar |
| `C-CHK-01…07` (checkpoint único firmado) | `SPEC.md` antiguo | **condicional** | Depende del rango PoST; sería FC-4 del CONTRATO | IPA A-04/A-05 |
| `C-UPG-01…08` (hard forks por altura, `CONSENSUS_BRANCH_ID`) | `SPEC.md` antiguo | **adaptar** | Altura de activación sin semántica DAG | IPA B-10 |
| `C-EXP-01…06` (caducidad por `altura_ploteo`) | `SPEC.md` antiguo | **obsoleto** en su forma; necesidad **sobrevive** | Alturas lineales | IPA A-06 |
| `C-REORG-07` (`MAX_REORG_LENGTH = 11 999`) | `SPEC.md` antiguo | **obsoleto** (el propio SPEC la declaraba transitoria) | — | — |
| Castigo correlacionado `C-SLA-01…04` | `D-ZRX/SPEC.md` §5 (propuesta de Katana) | **refutado** (DS-5, 2026-09-26) | No confisca saldo inexistente y castiga a honestos con fallos comunes | RFT-15; `DS-L02` |
| Región de retención «≳ 4.000» | `P-PRESTAMO/investigacion/INFORME.md` línea 49 | **refutado** (aritmética): la desigualdad da `ρ_ret·T_v > 370`; los propios ejemplos del informe multiplican 300 | Incoherente en la fuente; detectado por DS-3 | `P-ZRX/P-DISUASION/REVISION-DS3.md` |
| Capa de finalidad por votos: tabla de poder «función de `past(A_n)` y de nada más» (R-FIN-15) | `research/dag-poas-capa-finalidad.md` | **adaptar**: la lectura literal rompe la finalidad bajo partición; se encadena la tabla por certificado (FV-01b, como FIP-0086) | Contraejemplo de FV-1 (primera ejecución) | RFT-19; `P-ZRX/P-FINALIDAD-VOTOS/` |
| `C-GD-07`, `C-ORD-03/04` | `SPEC.md` antiguo | **sobrevive**, ahora con código: `zx-cadena` (identidad real, W06a-C) y fusión del motor (W06a-B) | — | B-03, B-11 (cerrados) |
| Progreso 0.0.1 antiguo (A1…F4): adaptador PoAS, puerta parcial, primer hijo dev, firmante, D1 plotter | `PIEZAS-DE-CODIGO/PROGRESO-0.0.1.md` (`6ef45cb5…`), `HOJA-DE-RUTA.md` (`e6d3f445…`) | referencia de ingeniería; **ninguna pieza cerraba una ruta activa** (lo dice la hoja de ruta) | — | Usar sus correcciones como casos de prueba al portar |

---

## 3. Copias en `R-ZRX/LEGADO/`

| Tema | Copia | Origen | sha256 | Motivo |
|---|---|---|---|---|
| stake | `LEGADO/stake/MAPA.md` | `P-ZRX/P-STAKE/MAPA.md` (solo `.trash`) | `0261f56c55ad81dbd2f10997d5f2b8933374f78222cdabc6bba1077e6fb0d9ae` | Citado por `D-ZRX/SPEC.md` §10 e IPA X-02 |
| reloj | `LEGADO/reloj/ESTADO-RELOJ.md` | `P-ZRX/T-ZRX/ESTADO-RELOJ.md` (solo `.trash`) | `88f436498971ba84ff3a17a1ff908e438021766c13d776cc2f95a0369a1cda4a` | Citado por RFT-12 |
| eclipse | `LEGADO/eclipse/INFORME.md` | `P-ZRX/P-ECLIPSE/investigacion/INFORME.md` (solo `.trash`) | `afd8481f3c686636c8b34fada67fd25dc0b6534a743ef4e3fecc5a887b8873c5` | Citado por IPA B-07 |

Procedencia y huellas: `R-ZRX/LEGADO/PROCEDENCIA.txt`, `R-ZRX/LEGADO/HUELLAS.sha256`. **Una copia
aquí no es un instrumento validado** y no se promueve a `V-ZRX/`.

---

## 4. Bitácora del mapa

| Fecha | Cambio | Encargo que lo cerró |
|---|---|---|
| 2026-09-26 | Alta inicial por lectura (inventario de código, catálogo de refutaciones y reglas del SPEC antiguo, con citas comprobadas) | — (sin ejecución: B-HARNESS-01) |
| 2026-09-26 01:17 | `zx-core`, `zx-pot`, `zx-consensus` (incl. PoAS, GHOSTDAG, firmante), `zx-storage` (+`rocksdb`) y `farmer_disco` pasan de **pendiente de reproducir** a **reproducido** en su contrato antiguo | L01 + L01-C1 (`P-ZRX/P-LINEA-BASE/REVISION.md`) |
| 2026-09-26 22:25 | Puesta al día tras P-DISUASION, P-SLASHING, FV-1 y AV-1: doble farmeo (RFT-14), `P-CLAVE` medido, coinbase atada implementada, sembrador reproducido en GPU (DS-4), `C-GD-07`/`C-ORD` con código, firmante hacia SL-4b; filas nuevas: `C-SLA` refutado, «≳ 4.000» refutado, R-FIN-15 adaptada | DS-3, DS-4, DS-5, DS-6, SL-2, W06a-B/C, FV-1 |
