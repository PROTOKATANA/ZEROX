# Fuentes de coste — elección de algoritmo PoW de arranque (P-POW / FUENTES-COSTE)

**ID:** P-POW/FUENTES-COSTE. **Alimenta:** IPA A-10 (`D-ZRX/IPA-ZRX.md`), y por vía de A-10 la Nota
A-12 (`P-ZRX/P-POW/NOTA-A12-ALGORITMO.md`). **Estado:** investigación de fuentes, **sin medición
propia, sin código ejecutado**. **Fecha:** 2026-09-26. **Firma:** Claude (agente de investigación).

Etiquetas: **[fuente]** = cita literal verificada por lectura directa de la página/documento;
**[derivación]** = cálculo propio a partir de cifras con fuente, con la fórmula explícita;
**[hipótesis]** = supuesto no verificado; **[no verificado]** = dato buscado y no confirmado con
fuente fiable. Todas las fuentes se consultaron el 2026-09-26 salvo que se indique otra fecha.

Este informe **no decide** el algoritmo. Reúne datos con fuente para que A-10 pueda calcular el
coste absoluto de producir `W_min` de trabajo y compararlo entre candidatos, tal como pide la Nota
A-12 §3.

---

## 0. Qué mide cada bloque de datos y por qué importa

Tras el corte (`D-T03`/TRN-09 de `CONTRATO-v0.md`) el hash **no** da poder: el peso PoST decide
entre historias válidas. El PoW solo protege la fase de emisión anterior poniendo un umbral
absoluto `W_min` **[derivación, de CONTRATO-v0.md §0 D-T03 y TRN-04]**. Por tanto lo que importa no
es qué tan "justo" reparte el hash el algoritmo, sino: (i) cuánto cuesta comprar o alquilar
suficiente hardware para superar `W_min` en el tiempo que dure la fase PoW, y (ii) cuánto de ese
hardware puede **desviarse** de una red grande existente que use la misma primitiva a coste marginal
(alquiler, o —caso nuevo documentado en 2025— incentivo económico de un tercero que redirige
hashrate ajeno sin comprarlo). Los seis apartados pedidos se organizan bajo esa pregunta.

---

## 1. Rendimiento publicado por dispositivo

### 1.1 SHA3-256 / Keccak

- No se encontró una tabla de rendimiento "oficial de proyecto" para minería Keccak (no hay un
  proyecto de referencia equivalente a RandomX/xmrig, porque ningún PoW Keccak a escala está
  desplegado hoy). **[no verificado]**
- Verificación (no minería) en CPU x86-64 sin instrucciones especiales: **11.7–12.25 ciclos/byte**
  para SHA3-256, según mediciones de Daniel J. Bernstein citadas en un artículo de análisis técnico;
  con AVX-512VL en Skylake-X baja a **~6.4 ciclos/byte**, y con AVX2 a **~7.8 ciclos/byte** en
  Skylake — https://shattered.io/sha-256-vs-sha-3-2026/ (consultado 2026-09-26). **[no verificado]**:
  no pude leer la medición primaria de Bernstein, solo esta fuente secundaria que la cita; la
  fuente secundaria sí es identificable y fechada, pero no es el benchmark original.
- Minería GPU/FPGA: existen implementaciones académicas de Keccak en FPGA (ej. Xilinx Virtex-7,
  ~8 Gbps de throughput, eficiencia 5.5 Mbps/slice), pero son diseños de investigación, no productos
  de minería — https://ieeexplore.ieee.org/document/9668209/ (no leído en detalle, solo indexado por
  buscador). **[no verificado]**

### 1.2 RandomX (Monero)

- README oficial, tabla de rendimiento por CPU (fast mode = 2080 MiB, light mode = 256 MiB):
  Intel i9-9900K: **5770 H/s (8T) fast / 1160 H/s (16T) light**; AMD Ryzen 7 1700: **4100 H/s (8T)
  fast / 620 H/s (16T) light**; i7-8550U: **1700 H/s (4T) fast / 350 H/s (8T) light**; i3-3220:
  **510 H/s (4T) fast / 150 H/s (4T) light**; Raspberry Pi 3: **20 H/s (4T) light, sin fast**. Fuente:
  https://github.com/tevador/RandomX (README), consultado 2026-09-26. **[fuente]**
- Requisitos de memoria: **2080 MiB (fast/minería) y 256 MiB (light)**; el propio README dice que
  el modo light "is expected to be used only for proof verification" **[fuente]**.
- Datos más recientes de `xmrig.com/benchmark` (agregados enviados por usuarios, fecha de
  consulta 2026-09-26, "actualizado semanalmente" según la propia web): CPU de consumo — **AMD
  Ryzen 9 9950X: 28 415.55 H/s**; Ryzen 9 7950X: 26 959.77 H/s; Ryzen 9 5950X: 23 370.49 H/s. CPU de
  servidor de gama alta — AMD EPYC 9B45 (128 núcleos): **249 389.00 H/s**; EPYC 9755 (128 núcleos):
  235 687.86 H/s. https://xmrig.com/benchmark. **[fuente]** para los H/s; la web no publica vatios.
- Vatios: no publicados por xmrig ni por el README de RandomX. Un cálculo con el TDP declarado por
  AMD para el Ryzen 9 9950X (170 W, ficha de producto AMD, no releída en esta sesión) daría
  **≈ 167 H/s por vatio** = 28 415.55 H/s / 170 W. **[derivación, TDP no verificado en esta
  sesión — usar con cautela]**.
- Auditorías: Trail of Bits (patrocinada por Arweave), y Kudelski Security, X41 D-Sec, QuarksLab
  (patrocinadas por OSTIF/Monero Research Lab/comunidad Monero), publicadas 10-08-2019: "All four
  security teams agree that the RandomX code is of very high quality" y "None of the four teams
  found cryptographic short cuts... nor functions... that could be easily bypassed with hardware
  optimization." https://ostif.org/four-audits-of-randomx-for-monero-and-arweave-have-been-completed-results/
  **[fuente]**.
- Documento de diseño oficial sobre resistencia ASIC (`doc/design.md` de tevador/RandomX,
  consultado vía raw.githubusercontent.com, 2026-09-26): un minero con hardware optimizado que no
  puede ejecutar el 25% de los programas generados (`Q = 0.75`) pero ejecuta los soportados 50% más
  rápido obtiene una eficiencia relativa de **0.44** (peor que un minero honesto). Un ASIC de modo
  light con memoria de 1 ciclo de latencia necesitaría en promedio **95 × 8 = 760 ciclos** para
  construir un ítem del Dataset, cuello de botella deliberado (SuperscalarHash). **[fuente]**, cita
  literal del documento de diseño del propio proyecto.

### 1.3 Memoria-dura GPU (Ethash/Etchash/KawPow)

- GPU de consumo, KawPow (Ravencoin), RTX 3080: **42.0–43.65 MH/s** a **255–270 W** según el ajuste
  de límite de potencia (80%). Fuentes agregadas de mercado (Kryptex, 1stMiningRig, hashrate.no,
  MyRandomTechBlog), no documentación oficial de NVIDIA ni del proyecto Ravencoin — el propio
  Ravencoin no publica una tabla de rendimiento equivalente al README de RandomX. **[no verificado
  como fuente primaria del proyecto; sí como dato de mercado repetido por varias fuentes
  independientes]**.
- ASIC, Ethash/Etchash: **Bitmain Antminer E9 Pro** — **3.68 GH/s a 2200 W** (eficiencia declarada
  0.598 J/MH), lanzado febrero 2023, ficha oficial https://bitmain.company/etc_miner_e9_pro.html
  (indexada por buscador; no releída línea a línea en esta sesión — cifras confirmadas también por
  agregadores independientes ASIC Miner Value / Zeus Mining / Minerstat con los mismos números).
  **[fuente, con la salvedad de no haber abierto directamente la página de Bitmain en esta
  sesión]**.
- ECIP-1049 (Ethereum Classic), estado **Withdrawn**, https://ecips.ethereumclassic.org/ECIPs/ecip-1049
  (consultada 2026-09-26): "Ethash ASICs currently easily available on the market" — cita literal
  usada como justificación para proponer abandonar Ethash/Etchash. **[fuente]**.

---

## 2. Mercados de alquiler de hash por algoritmo

- **NiceHash** ofrece Keccak y KawPow como algoritmos de su *Hashrate Marketplace*
  (https://www.nicehash.com/algorithm/kawpow, https://www.nicehash.com/marketplace). **Aviso
  obligatorio de la tarea: estas páginas NO son legibles sin JavaScript** — al hacer fetch directo
  de `nicehash.com/algorithm/kawpow` solo se obtuvo el título de la página ("NiceHash - Leading
  Cryptocurrency Platform for Mining and Trading"), sin cifras. **[fuente parcial: existencia
  confirmada por el listado de algoritmos indexado; precios y hashrate NO verificados
  directamente]**.
- **RandomX en NiceHash**: existió como algoritmo `RandomXmonero`, añadido en 2019 para el hard
  fork de Monero (anuncio oficial de NiceHash, "New algorithm RandomXmonero to support Monero hard
  fork!", https://www.nicehash.com/blog/post/new-algorithm-randomxmonero-to-support-monero-hard-fork,
  indexado por buscador, no releído íntegro esta sesión). No se encontró evidencia de que haya sido
  retirado. **[no verificado su estado actual en 2026]**.
- **MiningRigRentals** lista alquiler de RandomX (rigs para XMR) con precio en **BTC por MH por
  día**: en el fetch directo de https://www.miningrigrentals.com/rigs/randomx (2026-09-26) se leyó
  "Last Price / MH: 0.00058000" BTC, promedio 30 días 0.00059467 BTC — pero la tabla de rigs
  disponibles en ese momento requería JavaScript para poblarse ("Showing records 0-Pending..") y
  mostraba "No rigs match the current filters". **[fuente parcial: el precio de referencia por MH sí
  se leyó; la disponibilidad de oferta concreta, no]**. MiningRigRentals también lista Sha3-Keccak y
  KawPOW entre sus algoritmos soportados según resultados de búsqueda agregados (no fetch directo de
  esas páginas específicas). **[no verificado directamente]**.
- Precio mínimo de orden en NiceHash: "0.001 BTC ($84.08) for every algorithm" y, para KAWPOW,
  "1.0 TH/day for 24 hours starts at 0.07620000 BTC (≈$6406.75)" — cifra de un resultado de
  búsqueda agregado, no confirmada por fetch directo de la página de precios. **[no verificado]**.

**Conclusión de este apartado:** existe mercado de alquiler documentado y con fecha para los tres
algoritmos (Keccak, RandomX, KawPow/Ethash), pero el contenido dinámico de NiceHash impidió leer
cifras en vivo en esta sesión; MiningRigRentals sí entregó un precio puntual para RandomX.

---

## 3. Tamaño de redes existentes con la misma primitiva

- **RandomX → Monero**: hashrate de red **≈ 6.01 GH/s** en el bloque 3 770 510, dato fechado
  **2026-09-25**, https://www.coinwarz.com/monero-hashrate (fetch directo, texto literal: "Monero
  network hashrate is an estimate of the total RandomX computing power securing the chain, currently
  around 6.01 GH/s"). **[fuente]**. Otras fuentes de agregación (Kryptex, bitinfocharts) dan cifras
  ligeramente distintas (5.79–7.54 GH/s según el rango de fechas de 2026), lo cual es normal porque
  el hashrate se infiere de la dificultad, no se mide directamente. **[fuente, con rango entre
  fuentes]**.
- **Ethash/KawPow → Ravencoin**: **≈ 4.77 TH/s**, CoinWarz (resultado de búsqueda agregado, no fetch
  directo de esa página en esta sesión); pico histórico citado de 12.1 TH/s el 2026-06-12.
  **[no verificado por fetch directo]**.
- **Etchash → Ethereum Classic**: no se logró una cifra actual (2026) fiable; el dato más sólido
  encontrado es histórico — pico de **311.11 TH/s** tras "The Merge" de Ethereum en septiembre de
  2022 (fuentes: CoinDesk, Watcher.Guru, Benzinga, consultadas solo por resumen de búsqueda, no
  fetch directo). **[no verificado para 2026; fuente secundaria fechada solo para 2022]**.
- **Keccak/SHA3 como PoW a escala**: no se encontró ninguna red grande operando Keccak puro como
  algoritmo de minería (ECIP-1049 lo *proponía* para Ethereum Classic, no lo implementó — estado
  Withdrawn). **[fuente para el hecho negativo: no hay despliegue conocido; ausencia de evidencia,
  no prueba de inexistencia]**.

---

## 4. Incidentes documentados de reescritura con hash alquilado o desviado

### Ethereum Classic (Etchash), enero 2019

Dos ataques 51% el 5 y el 7 de enero de 2019: intento de doble gasto de **US$1.1M contra Coinbase**
(rechazado) y doble gasto exitoso de **US$200k contra Gate.io**. Fuente primaria del incidente:
https://www.coinbase.com/blog/coinbases-perspective-on-the-recent-ethereum-classic-etc-double-spend
— **no se pudo leer directamente en esta sesión (HTTP 403 al hacer fetch)**; la cifra proviene de
resultados de búsqueda que citan ese blog (CryptoPotato, Decrypt). **[fuente secundaria; la fuente
primaria de Coinbase existe pero no se verificó su texto literal en esta sesión]**.

### Ethereum Classic (Etchash), 31 de julio – 1 de agosto de 2020

Datos de https://bitquery.io/blog/attacker-stole-807k-etc-in-ethereum-classic-51-attack (fetch
directo, 2026-09-26): el atacante insertó bloques entre las alturas **10 904 147 y 10 907 761**
(reorg de **3 615 bloques**), del 31-jul 16:36 UTC al 1-ago 4:53 UTC. Doble gasto de **807 260 ETC
(~US$5.6M)**. Coste del hashpower: **17.5 BTC (~US$192 000)**, alquilado "purchasing the hash power
for double price from Nicehash provider daggerhashimoto". **[fuente]**. Retorno sobre el gasto:
~29× (5.6M / 0.192M), coherente con el "2800% return" citado por resultados de búsqueda agregados
sobre el mismo informe de Bitquery. Hubo un segundo ataque unos días después (5 de agosto de 2020,
según CoinDesk, no verificado por fetch directo). **[no verificado el segundo evento]**.

### Bitcoin Gold (Equihash-BTG, memoria-dura pero de la misma familia de ataque por alquiler)

Dos episodios distintos, con cifras que **no deben mezclarse**:

- **Mayo 2018**: doble gasto reportado de **~US$18M** contra múltiples exchanges (Binance, Bitinka,
  Bitfinex, Bittrex, Bithumb, HitBTC); Bittrex pidió compensación al equipo de Bitcoin Gold.
  Coste al atacante estimado por CoinDesk: **"less than $4,000"**. Fuentes agregadas de búsqueda
  (Bitcoin News, 24/7 Wall St.), **no fetch directo de la fuente primaria de CoinDesk en esta
  sesión**. **[no verificado por lectura directa; fuente secundaria consistente entre varios
  medios]**.
- **Enero 2020** (documento técnico distinto, gist de un ingeniero identificado como metalicjames,
  https://gist.github.com/metalicjames/71321570a105940529e709651d0a9765, fetch directo 2026-09-26):
  dos reorgs — "14 blocks removed, 13 blocks added" con **1 900 BTG (~US$19 000)** doble gastados, y
  "15 blocks removed, 16 blocks added" con **~5 267 BTG (~US$53 000)**. Coste estimado por reorg:
  **"around 0.2 BTC (~$1,700)"**, señalando que "the attacker would have recouped around the same
  value in block rewards" (el ataque casi se autofinanció con la recompensa de bloque). El
  documento no especifica si el hash fue alquilado o propio, solo identifica la dirección de
  coinbase del atacante. **[fuente]** para las cifras del gist; **[hipótesis]** que sea alquiler
  (no confirmado en el documento).

### Vertcoin (Lyra2REv2 → memoria-dura), octubre–diciembre 2018

Documentado por Mark Nesbitt (ingeniero de seguridad de Coinbase) en un post técnico (Medium/
Coinmonks, resultados de búsqueda agregados, **no fetch directo del post original en esta
sesión**): **22 reorgs profundos**, el mayor de **307 bloques** (longitud 310), en 4 incidentes
distintos entre octubre y diciembre de 2018; doble gasto total **> US$100 000**. El método descrito
es alquiler de hashrate ASIC ajeno ("Anonymous cybercriminals rented a large amount of ASIC hash
rate"). **[no verificado por lectura directa de la fuente primaria; múltiples fuentes secundarias
coinciden en las cifras]**.

### Monero / RandomX — Qubic, julio–agosto 2025 (desviación, no alquiler clásico)

Caso distinto y relevante para "hash desviable": el proyecto Qubic implementó un esquema de
"useful Proof-of-Work" que **incentiva económicamente** a mineros de CPU externos a apuntar su
hashrate RandomX hacia Monero y entregar las recompensas a cambio de tokens Qubic, sin que Qubic
compre hardware ni alquile en un mercado como NiceHash. La cuota de Qubic sobre el hashrate global
de Monero subió de **<2% (18-may-2025) a >27%** en julio, cayó tras un boicot de la comunidad a
**10–15%**, y Qubic reclamó públicamente haber superado el **51%** el 12-ago-2025. Según Halborn
(fetch directo, 2026-09-26, https://www.halborn.com/blog/post/explained-the-monero-51-percent-attack-august-2025):
reorganización de **"six-block deep"** con **"orphaning around 60 blocks"**; el artículo no da coste
estimado ni porcentaje exacto de hashrate en el momento del reorg. Varios medios (DL News, The
Block) señalan que la comunidad Monero **disputa** que el ataque haya tenido el alcance reclamado
por Qubic. **[fuente para el reorg de 6 bloques y 60 huérfanos; hipótesis/disputado para el
"51% alcanzado" y para cualquier cifra de coste]**. Relevancia para ZEROX: muestra un vector de
"hash desviado" **sin mercado de alquiler visible**, vía incentivo económico directo a mineros de
una red grande con la misma primitiva — un riesgo que un mercado tipo NiceHash no capturaría.

---

## 5. Existencia verificable de ASICs

| Algoritmo | ¿Existe ASIC? | Evidencia |
|---|---|---|
| **Keccak/SHA3-256** | No se encontró ASIC comercial. "While Keccak is ASIC friendly... there isn't an ASIC currently available for this algorithm" (coinguides.org, resultado de búsqueda, no fetch directo). Existen diseños **académicos** en FPGA. **[no verificado como ausencia definitiva; sí como ausencia de oferta comercial detectable]** |
| **RandomX** | No hay ASIC conocido a 2026; el diseño (§1.2) busca deliberadamente hacerlo antieconómico (SuperscalarHash, dependencia de latencia DRAM); las 4 auditorías de 2019 no reportan bypass de hardware. **[fuente, indirecta: ausencia reportada + diseño publicado]** |
| **Ethash/Etchash** | **Sí.** Bitmain Antminer E9 Pro (2023), 3.68 GH/s, 2200 W. ECIP-1049 (2021-22, Withdrawn): "Ethash ASICs currently easily available on the market". **[fuente]** |
| **KawPow** | Diseñado específicamente para bloquear los ASICs de Ethash mediante cambios de programa; no se encontró ASIC comercial para KawPow en esta búsqueda. **[no verificado]** |

---

## 6. Coste de verificación por nodo

- **SHA3-256**: verificación = un solo hash sobre la cabecera; sin requisito de memoria dedicada más
  allá del estado interno de Keccak (~200 bytes). Coste temporal estimado por la vía de cycles/byte
  de Bernstein (§1.1): **~12 ciclos/byte sin instrucciones especiales**, del orden de **cientos de
  nanosegundos** para una cabecera de bloque típica (decenas a pocos cientos de bytes).
  **[derivación a partir de una cifra no verificada directamente — usar con cautela]**.
- **RandomX**: el modo *light* (256 MiB) está pensado explícitamente para verificación, no para
  minería (README, §1.2). Con la tabla del README, el i9-9900K hace 1160 H/s en light mode con 16
  hilos ⇒ **≈72.5 H/s por hilo** ⇒ **≈13.8 ms por hash por hilo**. **[derivación, fórmula:
  1160/16 = 72.5 H/s/hilo; 1/72.5 s = 0.0138 s]**. Esto es **~4 órdenes de magnitud más lento** que
  verificar un SHA3-256, y exige **256 MiB de RAM por verificación concurrente** — coste no trivial
  para un nodo que valida muchas cabeceras de la fase PoW en poco tiempo (reindexado, sincronización
  inicial). **[derivación]**
- **Ethash/Etchash/KawPow**: la verificación *light* de Ethash exige acceso a la cache DAG (~16-32
  MiB actualmente, creciente con la época) y varias lecturas pseudoaleatorias; más cara que SHA3
  pero mucho más barata que RandomX-light en tiempo, más cara en trabajo de mantenimiento de la
  cache. No se encontró una cifra de tiempo por hash de verificación con fuente directa en esta
  sesión. **[no verificado]**

---

## Tabla 1 — candidato × dispositivo × H/s × W × fuente × fecha

| Candidato | Dispositivo | H/s | W | Fuente | Fecha del dato |
|---|---|---|---|---|---|
| SHA3-256 | CPU x86-64 genérica (verificación, no minería) | — (12 ciclos/byte) | — | shattered.io (cita a Bernstein) [no verificado] | consultado 2026-09-26 |
| RandomX | Intel i9-9900K, fast mode 8T | 5 770 H/s | no publicado | github.com/tevador/RandomX README [fuente] | consultado 2026-09-26 |
| RandomX | Intel i9-9900K, light mode 16T | 1 160 H/s | no publicado | ídem [fuente] | consultado 2026-09-26 |
| RandomX | AMD Ryzen 9 9950X | 28 415.55 H/s | ~170 W (TDP AMD, no releído) | xmrig.com/benchmark [fuente parcial] | consultado 2026-09-26 |
| RandomX | AMD EPYC 9B45 (128 núcleos) | 249 389.00 H/s | no publicado | xmrig.com/benchmark [fuente] | consultado 2026-09-26 |
| Ethash/KawPow | NVIDIA RTX 3080 (80% power limit) | 43.65 MH/s | 255 W | agregadores de mercado (Kryptex/1stMiningRig/hashrate.no) [no verificado como fuente primaria] | búsqueda 2026-09-26 |
| Ethash/Etchash | Bitmain Antminer E9 Pro (ASIC) | 3.68 GH/s | 2 200 W | bitmain.company (vía agregadores) [fuente, no releída directamente] | lanzado feb-2023, consultado 2026-09-26 |
| Keccak/SHA3 | — | sin ASIC/GPU de referencia con fuente de proyecto | — | ninguna fuente de proyecto encontrada [no verificado] | — |

## Tabla 2 — incidente × red × algoritmo × profundidad × coste publicado × fuente

| Incidente | Red | Algoritmo | Profundidad reorg | Coste publicado (alquiler/ataque) | Doble gasto | Fuente |
|---|---|---|---|---|---|---|
| ene-2019 | Ethereum Classic | Etchash | no cuantificada en las fuentes revisadas | no cuantificado | US$1.1M intentado, US$200k logrado | Coinbase blog (vía secundarias) [fuente secundaria, no releída directa] |
| jul-ago 2020 | Ethereum Classic | Etchash | 3 615 bloques (10 904 147→10 907 761) | 17.5 BTC (~US$192 000), NiceHash "daggerhashimoto" | US$5.6M (807 260 ETC) | bitquery.io [fuente, fetch directo] |
| may-2018 | Bitcoin Gold | Equihash-BTG | no cuantificada en las fuentes revisadas | <US$4 000 (estimado CoinDesk, no releído directo) | ~US$18M | agregadores (Bitcoin News, 24/7 Wall St.) [no verificado directo] |
| ene-2020 | Bitcoin Gold | Equihash-BTG | 14–15 bloques por reorg | ~0.2 BTC (~US$1 700) por reorg | ~US$72 000 (US$19k+US$53k) | gist metalicjames [fuente, fetch directo] |
| oct-dic 2018 | Vertcoin | Lyra2REv2 | hasta 307 bloques | no cuantificado en las fuentes revisadas | >US$100 000 | Mark Nesbitt/Coinbase (vía secundarias) [no verificado directo] |
| jul-ago 2025 | Monero | RandomX | 6 bloques | no cuantificado (desviación por incentivo, no alquiler) | no cuantificado; disputado si "éxito" real | halborn.com [fuente, fetch directo] |

---

## Huecos abiertos (no cerrar A-10 sin resolverlos)

1. No hay una cifra de coste de alquiler **fechada y en vivo** para RandomX, Keccak ni KawPow —
   NiceHash requiere JavaScript y MiningRigRentals solo entregó el precio de referencia (BTC/MH/día)
   sin oferta concreta. Haría falta reintentar con un fetch que ejecute JS, o pedir el dato a mano.
2. No se verificó por lectura directa ninguna de las fuentes "primarias" de los incidentes de 2018-2019
   (Coinbase blog HTTP 403, gist/Medium de Nesbitt no releído) — las cifras usadas provienen de
   fuentes periodísticas que las citan de forma consistente entre sí, pero no es lo mismo que leer el
   original.
3. La cifra de vatios de las CPUs modernas de RandomX (Ryzen 9950X, EPYC) es una combinación
   [derivación] de una fuente [fuente] (H/s) con un TDP de fabricante que **no releí** en esta
   sesión — el coste en US$/W queda pendiente de una fuente de electricidad y un TDP verificado.
4. El caso Qubic/Monero 2025 está en disputa entre las propias fuentes citadas (¿alcanzó 51% o no?);
   antes de usarlo como precedente cuantitativo para A-10 habría que fijar cuál de las versiones
   (Halborn vs. la comunidad Monero) se toma como base.
