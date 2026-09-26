# DS-1 — Fuentes primarias: mecanismos de disuasión en sistemas de espacio y de stake

**Ejecutor:** Sonnet (investigación web, sin código). **Fecha de consulta de todas las fuentes:** 2026-09-26.
**Marco:** `P-ZRX/P-DISUASION/MARCO.md`. **Orden:** `P-ZRX/P-DISUASION/ORDEN-DS1-FUENTES.md`.

Etiquetas usadas en cada afirmación:
- **[P]** fuente primaria comprobada — abrí la página/documento y leí el contenido citado.
- **[S]** fuente secundaria — blog, artículo de prensa o síntesis de un buscador que resume una fuente primaria que **no** pude abrir yo mismo.
- **[D]** derivación mía a partir de dos o más fuentes.
- **[H]** hipótesis, sin fuente que la confirme.

Aviso general: varias veces el motor de búsqueda devolvió un resumen ya sintetizado sin que yo abriera la página, y varios PDF (SpaceMint, el paper de Baig-Günther-Pietrzak sobre multi-recurso, el paper de electricidad de Filecoin) llegaron como binario ilegible para la herramienta de lectura — estos casos quedan marcados **[S]** o en la sección 3, nunca como **[P]**.

---

## 1. Tabla por sistema y mecanismo

### 1.1 Filecoin

| Mecanismo | Conducta objetivo | Condición de aplicación | Magnitud (fecha) | Fallos/incidentes documentados | Etiqueta |
|---|---|---|---|---|---|
| Consensus Fault (double-fork mining, time-offset mining, parent-grinding) | Un mismo minero firma dos bloques que violan las reglas de Expected Consensus (mismo slot, mismo padre con época distinta, o padre que debería incluir un bloque testigo y no lo hace) | **Condicionada**: cualquier usuario puede ser "slasher", pero debe presentar ambas cabeceras de bloque firmadas y válidas al actor `ReportConsensusFault`; si el atacante nunca publica el segundo bloque, no hay evidencia que perseguir | Pérdida de **todo** el pledge collateral del minero y de su power; el denunciante recibe una porción del penalty | No se encontró un caso real documentado de consensus fault ejecutado en mainnet (solo la especificación) | [P] spec.filecoin.io/algorithms/expected_consensus/ |
| Initial Pledge — Consensus Pledge (M1: garantía mínima para producir) | Producir poder (potencia) sin capital inmovilizado | **Exigible**: recae sobre el minero haga lo que haga, es requisito previo a producir, no depende de detectar nada | `SectorInitialConsensusPledge = 0.3 × CirculatingSupply × SectorQAP / max(NetworkBaseline, NetworkQAP)`; objetivo de red: ~30 % del suministro circulante bloqueado en consensus pledge | — | [P] spec.filecoin.io/systems/filecoin_mining/miner_collaterals/ |
| Initial Pledge — Storage Pledge | Cubrir penalizaciones futuras del sector | Exigible, previo a producir | ≈ 20 días de recompensa de bloque esperada para la cuota de potencia del sector | — | [P] spec.filecoin.io/systems/filecoin_mining/miner_collaterals/ |
| Fault Fee (FIP-0002) | No declarar un sector fallido antes de un chequeo WindowPoSt programado | **Exigible** una vez ocurre el fallo detectado en el chequeo periódico de la red (no depende de que un tercero denuncie, lo detecta el protocolo) | = 3.51 días de recompensa de bloque esperada | — | [P] github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0002.md |
| Termination Fee (FIP-0098, estado "Final") | Terminación voluntaria o involuntaria de un sector | Exigible al terminar el sector | `termination fee = max(MIN_TERMINATION_FEE × initial_pledge, max(0.085 × initial_pledge × min(1, edad_días/140), FAULT_FEE_MULTIPLE × fault_fee))`; `TERMINATION_LIFETIME_CAP = 140 días` | El FIP no indica fecha exacta de activación en mainnet (requiere upgrade de red) | [P] github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0098.md |
| PoRep / sellado lento con aleatoriedad de cadena mezclada | Reescritura retroactiva de sectores (ataque de largo alcance, análogo a A7 de ZEROX) | **Exigible**: cualquier atacante que quiera rehacer un mes de historia debe **regenerar todos los sectores** de ese periodo, sin que dependa de que nadie lo denuncie | Cita literal: mezclar aleatoriedad de la cadena obliga a que "an attacker going back a month in time to try and create their own chain would have to completely regenerate any and all sectors" | — | [P] spec.filecoin.io/systems/filecoin_mining/sector/sealing/ |
| Sellado (PoRep/SDR) — coste de hardware | Sembrador/regeneración bajo demanda (A3) | El coste recae sobre cualquiera que quiera sellar, sea honesto o atacante | RAM ≥128 GiB recomendada, CPU 8+ núcleos (AMD con extensiones SHA preferido), un sector de 32 GiB se expande a ~480 GiB durante el sellado, ≥1 TiB NVMe de caché; existirá un `MAX_SEAL_TIME` por tamaño de sector | No se encontró cifra de tiempo de sellado en horas ni de energía en kWh por sector (ver §3) | [P] lotus.filecoin.io/storage-providers/get-started/hardware-requirements/ + spec.filecoin.io/systems/filecoin_mining/sector/sealing/ |
| PoRep contra Sybil / Outsourcing / Generation attacks | (Sybil) fingir n copias almacenando solo 1; (Outsourcing) comprometerse a más almacenamiento del que se tiene, dependiendo de traerlo rápido de otro proveedor; (Generation) generar los datos bajo demanda en vez de almacenarlos | Se describe como propiedad estructural de PoRep (comparación de tiempos de codificación/decodificación), no un castigo posterior | — | El propio documento técnico (Benet & Dalrymple) no se pudo leer directamente (ver §3); solo tengo la síntesis del buscador | [S] — no confirmado con lectura directa del PDF |
| Colateral histórico | Coste de adquisición para atacar con capacidad (C-adq) | — | Coste de capital para incorporar el 33 % de la capacidad de red rondó "en magnitud" 25 millones de FIL la mayor parte del tiempo, según simulación (marzo 2023) | Es una estimación de los autores del blog, no una cifra oficial de la red | [S] blog.block.science/understanding-the-filecoin-consensus-pledge/ (leído directamente, pero es análisis de terceros, no dato oficial) |

### 1.2 Chia

| Mecanismo | Conducta objetivo | Condición | Magnitud (fecha) | Fallos/incidentes | Etiqueta |
|---|---|---|---|---|---|
| Ausencia de stake / castigo | Doble farmeo en varias ramas (A1) | **No existe mecanismo de castigo.** La única fricción es física: un mismo disco no puede hacer dos búsquedas de parcela a la vez sin degradarse mutuamente | Cita: "creating a PoSpace requires a physical resource (hard drive space), while creating a PoS only requires a key" — esto **evita el nothing-at-stake de PoS puro**, pero no impone ningún coste **exigible** adicional por farmear en varios forks simultáneamente; solo un límite práctico de rendimiento del harvester | Discusión oficial en GitHub reconoce que farmear 1 fork adicional es viable en la mayoría de granjas; con 4+ forks "things start to escalate quite quickly" (degradación de lookups, no penalización protocolar) | [P] docs.chia.net/docs/03consensus/analysis/ (concepto), [S] github.com/Chia-Network/chia-blockchain/discussions (detalle de degradación práctica) |
| Filtro de parcelas (plot filter) | Reduce la carga de cómputo por desafío, no es anti-doble-farmeo | — | Reducido de 512 a 256 en junio 2024, duplicando la carga de trabajo del harvester | — | [S] (síntesis de buscador, no confirmado con lectura directa) |
| Parcelas comprimidas (C1–C9) | Trade-off: menos disco a cambio de más cómputo por prueba | Exigible sobre quien elige comprimir (no es un castigo, es un coste de diseño que el propio farmer acepta a cambio de más "tamaño efectivo") | Requisitos mínimos declarados: C0–C3 Raspberry Pi 4; C4–C5 CPU de escritorio; C6–C7 CPU rápida; C9 GPU (GTX 1060 o similar); C7 da un 29.8 % más de recompensa efectiva que C0 | No se encontraron cifras de tiempo de descompresión en segundos ni de energía por prueba con C1–C9 (ver §3) | [P] docs.chia.net/plotting-compression/ |
| Timelords / VDF | Impide *grinding* de tiempo | Estructural, no depende de detectar a nadie | Cita: "muy pocos nodos ejecutan VDFs, y éstos no son paralelizados" → bajo coste marginal de farmear una vez sembrado | — | [P] docs.chia.net/docs/03consensus/analysis/ |

**Nota importante para DS-2:** no encontré ningún mecanismo en Chia que encarezca de forma **exigible** el doble farmeo en ramas privadas más allá de la fricción operativa del hardware. Esto coincide con el resultado teórico de la §1.4 (Baig & Pietrzak, 2025).

### 1.3 SpaceMint (Park, Kwon, Fuchsbauer, Gazi, Alwen, Pietrzak)

No pude leer el PDF original (dos intentos: `sunoopark.com/p/18/spacemint.pdf` y `fc18.ifca.ai/preproceedings/78.pdf`; ambos llegaron a la herramienta como binario/stream de PDF sin texto legible). Todo lo siguiente es **[S]**, síntesis de motor de búsqueda sobre el paper, no lectura directa mía.

| Mecanismo | Conducta objetivo | Condición | Magnitud | Etiqueta |
|---|---|---|---|---|
| "Punishment transaction" | Doble farmeo: un minero extiende dos bloques con la misma prueba de espacio en dos cadenas | **Condicionada**: exige que se publiquen (o se capturen) **dos bloques candidatos con la misma prueba**; si el atacante solo emite el que gana y nunca hace público el otro, no hay transacción de castigo posible | La mitad de la recompensa del bloque "infractor" va a quien construye la transacción de castigo; la otra mitad se destruye | [S] |
| Desafío derivado con retardo Δ | Evita que el reto del bloque i dependa del bloque i−1 inmediato (mitiga selfish-mining/grinding) | Estructural | Reto del bloque i se deriva del bloque i−Δ, forzando que exista una única prueba válida por desafío para cada minero | [S] |

**Conclusión sobre SpaceMint:** el mecanismo específico contra doble farmeo que aporta la literatura es **condicionado**, no exigible — exactamente lo contrario de lo que pide la pregunta falsable de DS-1.

### 1.4 Literatura (límites teóricos de PoSpace, coste de ataques, largo alcance)

| Fuente | Hallazgo | Relevancia | Etiqueta |
|---|---|---|---|
| Baig & Pietrzak, "On the (in)security of Proofs-of-Space based Longest-Chain Blockchains", FC 2025 (arXiv:2505.14891) | Bajo disponibilidad dinámica (las partes honestas controlan φ>1 veces más espacio que el adversario, y el adversario puede variar el espacio honesto en un factor 1±ε por bloque, con reploteo de ρ bloques), **no existe ningún protocolo de cadena-más-larga basado en PoSpace que sea seguro sin supuestos adicionales**. Construyen un adversario que produce un fork de longitud φ²·ρ/ε que gana bajo cualquier regla de selección de cadena | Refuta directamente la posibilidad de un mecanismo puramente PoSpace, exigible y sin supuestos extra, que impida el doble farmeo/reorganización | [P] leí el abstract y el resumen del resultado en arxiv.org/abs/2505.14891 (no el cuerpo completo del PDF, que no se pudo renderizar con esta herramienta) |
| crypto51.app | Metodología pública para el "coste de un ataque del 51 %": coste de alquilar en NiceHash suficiente hashrate para igualar la red durante 1 hora; usa hashrates de "What to Mine", precios de CoinMarketCap y precios de alquiler de NiceHash. Declara explícitamente que **no** descuenta la recompensa de bloque que el atacante ganaría (lo que puede sobreestimar el coste real hasta en un 80 %), y que NiceHash no tiene hashrate suficiente para las redes grandes | Es la metodología de referencia de "coste de un ataque" citada en el marco (C-adq, C-hardware); ejemplo con cifras del propio día de consulta: BTC ≈ US$1.441.231/hora, LTC ≈ US$62.967/hora, ZEC ≈ US$91.650/hora (2026-09-26) | [P] www.crypto51.app y www.crypto51.app/about.html, ambos leídos directamente hoy |
| Deirmentzoglou et al., "A Survey on Long-Range Attacks for Proof of Stake Protocols" | Cataloga defensas: weak subjectivity + checkpoint de confianza (un nodo nuevo pregunta a una fuente confiable el hash de la cadena válida), firmas de clave evolutiva (KES, que **no** previenen el ataque de largo alcance sin supuesto de mayoría honesta), comités de "consenso social" que marcan puntos de control | Cataloga exactamente las familias de defensa que aplican a A7 en ZEROX; ninguna es "gratis": todas dependen de un supuesto de sincronía social o de mayoría honesta, no de un coste puramente económico | [S] síntesis de buscador sobre el survey, no leí el PDF completo |
| Ethereum PoS: modelo de "coste de ataque" | El coste de reescribir finalidad exige que ≥1/3 de la garantía total sea *slashed* (para romper la propiedad de "accountable safety"), lo cual es la base de las estimaciones de "coste de finalidad" del protocolo | Ejemplo de metodología de coste exigible basada en stake, contraste con PoSpace puro | [S], derivado de eth2book y ethereum.org, no de un cálculo propio |

---

## 2. Autonomys / Subspace

| Mecanismo | Conducta objetivo | Condición | Magnitud | Etiqueta |
|---|---|---|---|---|
| Separación farmer/operador | El farmer (PoAS) **no tiene stake ni castigo**; solo el operador de dominio (ejecución) tiene `MinStake` y puede perder ese stake | — | No se encontró cifra de `MinStake` en AI3 con fecha | [P] academy.autonomys.xyz/autonomys-network/decoupled-execution/staking (leído) para la existencia de MinStake de operador; [P] academy.autonomys.xyz/autonomys-network/consensus/proof-of-archival-storage/farming (leído: confirma explícitamente que la página **no** menciona ningún mecanismo de penalización para auditorías de parcela fallidas) |
| Coste de plotting CPU/GPU | Sembrado de la parcela (relevante para A3) | — | **No encontrado**: ninguna fuente dio cifras de tiempo o energía de plotting en CPU o GPU con fecha | — | sin fuente (ver §3) |
| Página de seguridad del consenso (`consensus/security`) | — | — | La página no cargó contenido legible en dos rutas distintas (`.net` y `.xyz`, con redirección entre ambas) | — | intento fallido, no citado como comprobado |

---

## 3. Ethereum PoS (referencia, no es sistema de espacio pero está en el encargo)

| Mecanismo | Conducta objetivo | Condición | Magnitud (fecha) | Incidentes | Etiqueta |
|---|---|---|---|---|---|
| Slashing — Proposer violation | Firmar dos bloques distintos para el mismo slot | **Condicionada**: la evidencia debe incluirse en un bloque de la beacon chain (alguien debe presentarla) | Recompensa al que incluye la evidencia: `B/512` del balance efectivo del validador sancionado (máx. ≈0.001953 ETH) | Evento de referencia: 2021-02-04, 75 validadores operados por Staked Inc. sancionados a la vez [S, no confirmado con fuente primaria del incidente]; evento reciente: 2025-09-10, 39 validadores ligados a SSV Network [S] | [P] eth2book.info/latest/part2/incentives/slashing/ (mecanismo y fórmula), [S] para los incidentes concretos |
| Slashing — FFG double vote / surround vote | Votar dos checkpoints distintos para el mismo target, o votar de forma que "rodee" un voto anterior | Condicionada (misma vía) | — | — | [P] eth2book.info/latest/part2/incentives/slashing/ |
| Penalización correlacionada | Coordinación de varios validadores sancionados en la misma ventana | Condicionada a que haya slashing (que a su vez es condicionado a evidencia) | `correlation penalty = min(B, 3·S·B/T)`, con S = suma de balances sancionados en ventana de 36 días (18 antes/18 después), T = balance activo total, multiplicador 3 desde Bellatrix | — | [P] eth2book.info/latest/part2/incentives/slashing/ |
| Inactivity leak | Fuga de balance de validadores inactivos cuando la cadena lleva **más de 4 épocas sin finalizar** | **Exigible**: no depende de que nadie denuncie, es automático por falta de finalidad | Reduce el stake de los inactivos hasta que controlen <1/3 del total activo, restaurando el quórum de 2/3 | — | [P] ethereum.org/developers/docs/consensus-mechanisms/pos/rewards-and-penalties/ |

---

## 4. Respuesta a la pregunta falsable

**Pregunta:** «¿Existe al menos un mecanismo documentado en un sistema de prueba de espacio que encarezca el doble farmeo o la producción en ramas privadas de forma **exigible** (sin depender de que el atacante publique evidencia)?»

**Respuesta: REFUTADA, con un matiz.**

- En los tres sistemas de prueba de espacio investigados que compiten por cadena-más-larga (Chia, SpaceMint, Subspace/Autonomys), **todo mecanismo de disuasión contra el doble farmeo que existe depende de que la evidencia llegue a la cadena**:
  - Chia: **no tiene ningún mecanismo de castigo**; la única fricción es de rendimiento de hardware, no un coste garantizado [P, §1.2].
  - SpaceMint: su "punishment transaction" exige que se **publiquen ambos bloques con la misma prueba**; si el atacante nunca hace público el segundo, no hay castigo [S, §1.3].
  - Subspace/Autonomys: el farmer no tiene stake ni penalización documentada; solo el operador de dominio (una capa distinta, de ejecución, no de farmeo) tiene `MinStake` [P, §2].
- Hay además un resultado teórico que va más allá de "no lo encontré": Baig y Pietrzak (FC 2025) **demuestran** que, bajo disponibilidad dinámica, **ningún** protocolo de cadena-más-larga basado en PoSpace puro puede ser seguro sin añadir supuestos extra al modelo — es decir, no es solo que no se haya documentado un mecanismo exigible, es que el resultado formal dice que dentro de la familia "PoSpace puro" no puede existir uno que cierre el problema por sí solo [P (abstract), §1.4].
- El matiz: **Filecoin sí tiene un mecanismo exigible**, pero no contra el doble farmeo en el sentido de "dos ramas competidoras simultáneas" (A1), sino contra la **reescritura retroactiva de sectores ya sellados** (más parecido a A7, largo alcance): el sellado lento con aleatoriedad de cadena obliga a **regenerar todos los sectores** del periodo que se quiera reescribir, sin que importe si alguien lo detecta o no [P, §1.1]. Esto no es un mecanismo "de PoSpace puro que resuelva doble farmeo/ramas privadas" — es un mecanismo de **sellado lento (tipo VDF/time-lock)** que ZEROX ya cataloga aparte (O2, F3 en el marco) y que actúa sobre un problema relacionado pero distinto.

**Conclusión operativa para DS-2:** ningún candidato de PoSpace puro aporta una celda **E-exigible** contra A1 (doble farmeo). Los candidatos exigibles del catálogo (M1/M2 de PoStake, F3 de Filecoin) vienen de **fuera** de la familia PoSpace pura — de stake inmovilizado o de sellado lento —, no de un mecanismo nativo de prueba de espacio.

---

## 5. Lo que busqué y no encontré

- Cifra de **energía (kWh)** o tiempo de sellado en horas por sector Filecoin de 32/64 GiB: intenté `arxiv.org/pdf/2407.14519` (Electricity Consumption of Ethereum and Filecoin); el PDF llegó como binario ilegible a la herramienta de lectura, y no encontré una página HTML equivalente con las cifras. **No usado.**
- Confirmación primaria del *Proof-of-Replication Technical Report* (Benet & Dalrymple) sobre Sybil/Outsourcing/Generation attacks: `filecoin.io/proof-of-replication.pdf` devolvió 404; `web.archive.org` no es accesible con esta herramienta. Solo tengo la síntesis de un buscador — marcado **[S]**, no **[P]**.
- Texto completo del paper de SpaceMint (dos rutas de PDF probadas, ambas ilegibles para la herramienta). Todo el contenido de SpaceMint en este informe es **[S]**.
- Cifra exacta de colateral histórico Filecoin **por TiB** en USD con fecha: solo encontré una estimación agregada (25 M FIL para el 33 % de la capacidad, marzo 2023) en un blog de análisis, no la cifra por TiB pedida por la orden.
- Reporter/whistleblower reward exacto de un Consensus Fault en Filecoin (encontré dos cifras contradictorias en snippets de búsqueda —"0.001–0.05 × Consensus Fault Penalty" y "BlockReward/4"— sin poder confirmar cuál es la vigente en una fuente primaria). **No usado como magnitud confiable.**
- Cifras de tiempo/energía de descompresión GPU por nivel de parcela comprimida en Chia (C1–C9): solo obtuve requisitos mínimos de hardware por nivel, no tiempo por prueba ni consumo.
- Reducción del "plot filter" de Chia de 512 a 256 (junio 2024) y las comisiones de Gigahorse (3.125 %/1.562 %): solo en síntesis de buscador, no verificadas con lectura directa de una página primaria.
- Coste documentado de plotting en CPU o GPU para Autonomys/Subspace: no encontré ninguna cifra, ni siquiera de orden de magnitud, en ninguna fuente.
- Página `academy.autonomys.xyz/subspace-protocol/consensus/security`: no cargó contenido legible en ninguna de las dos rutas de dominio (`.net`/`.xyz`) probadas.
- No hubo tiempo, dentro del presupuesto de 2 h, para leer el cuerpo completo (no solo el abstract) del paper de Baig & Pietrzak 2025, ni el paper "Towards a Multi-Chain Future of Proof-of-Space" (arXiv:1907.07896) cuyo PDF también llegó ilegible.

## 6. Lista de fuentes (todas consultadas el 2026-09-26)

**Primarias comprobadas [P]:**
- https://spec.filecoin.io/algorithms/expected_consensus/
- https://spec.filecoin.io/systems/filecoin_mining/miner_collaterals/
- https://spec.filecoin.io/systems/filecoin_mining/sector/sealing/
- https://docs.filecoin.io/provide-storage/filecoin-economics/slashing
- https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0002.md
- https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0098.md
- https://lotus.filecoin.io/storage-providers/get-started/hardware-requirements/ (vía síntesis de búsqueda directa sobre la página)
- https://docs.chia.net/docs/03consensus/analysis/
- https://docs.chia.net/plotting-compression/
- https://eth2book.info/latest/part2/incentives/slashing/
- https://ethereum.org/developers/docs/consensus-mechanisms/pos/rewards-and-penalties/
- https://arxiv.org/abs/2505.14891 (abstract y resumen del resultado principal)
- https://www.crypto51.app/ y https://www.crypto51.app/about.html
- https://academy.autonomys.xyz/autonomys-network/decoupled-execution/staking
- https://academy.autonomys.xyz/autonomys-network/consensus/proof-of-archival-storage/farming

**Secundarias [S] (síntesis de buscador o blog de terceros, sin lectura directa del documento primario):**
- https://blog.block.science/understanding-the-filecoin-consensus-pledge/ (leído directamente, pero es análisis de terceros)
- Síntesis de búsqueda sobre `filecoin.io/proof-of-replication.pdf` (Sybil/Outsourcing/Generation attacks)
- Síntesis de búsqueda sobre SpaceMint (punishment transaction, desafío con retardo Δ)
- Síntesis de búsqueda sobre el plot filter de Chia y las comisiones de Gigahorse/Bladebit CUDA
- Síntesis de búsqueda sobre "A Survey on Long-Range Attacks for Proof of Stake Protocols" (Deirmentzoglou et al.)
- Síntesis de búsqueda sobre incidentes de slashing en Ethereum (2021-02-04 y 2025-09-10)

**Intentos fallidos (no citados como fuente):**
- https://filecoin.io/proof-of-replication.pdf (404)
- https://sunoopark.com/p/18/spacemint.pdf (PDF ilegible para la herramienta)
- https://fc18.ifca.ai/preproceedings/78.pdf (PDF ilegible)
- https://arxiv.org/pdf/2508.01448 (PDF ilegible)
- https://arxiv.org/pdf/1907.07896 (PDF ilegible)
- https://arxiv.org/pdf/2407.14519 (PDF ilegible)
- https://link.springer.com/chapter/10.1007/978-3-032-07035-7_8 (paywall, redirección a login)
- https://academy.autonomys.xyz/subspace-protocol/consensus/security y variante `.net` (contenido no disponible)
- https://web.archive.org/... (herramienta sin acceso a este dominio)
