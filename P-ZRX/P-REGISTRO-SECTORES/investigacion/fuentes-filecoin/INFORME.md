# Fuentes primarias de Filecoin para P-REGISTRO-SECTORES

**Estado:** investigación de fuentes (sin código, sin prototipo). No es especificación ni
autorización de activación. No modifica `D-ZRX/SPEC.md`.
**Fecha de consulta de todas las URL:** 2026-09-26.
**Método:** cada URL se leyó con la herramienta de fetch web (que convierte HTML a texto y
lo resume bajo un prompt dirigido). Las citas entrecomilladas en inglés que aparecen abajo son
las devueltas literalmente por esa herramienta al pedir texto exacto; no se comprobó carácter a
carácter contra el HTML crudo, así que se marcan **[fuente-reportada]** en vez de **[fuente]**
estricta cuando hay ese matiz. Las frases en español sin comillas son parafraseo del extractor o
[derivación] propia, nunca cita.

**Convención:** [fuente-reportada] = cita textual devuelta por el fetch sobre la URL indicada.
[derivación] = razonamiento propio a partir de esas citas. [hipótesis] = supuesto no verificado
aquí. Ninguna cifra de Filecoin es parámetro de ZEROX.

---

## 1. Precompromiso y alta de almacenamiento (PreCommit / ProveCommit)

**URL:** https://spec.filecoin.io/systems/filecoin_mining/sector/adding_storage/
**Estado de la página:** `State: stable`, `Theory Audit: wip` [fuente-reportada].

**Citas:**
- «A Miner publishes a Sector's SealedCID, through `miner.PreCommitSector` of
  `miner.PreCommitSectorBatch`, and makes a deposit.» [fuente-reportada]
- «The Miner provides a Proof of Replication (PoRep) for the Sector through
  `miner.ProveCommitSector` or `miner.ProveCommitAggregate`.» [fuente-reportada]
- «ProveCommitments must happen AFTER the InteractiveEpoch (150 blocks after Sector
  PreCommit)» y «BEFORE the PreCommit expiration» [fuente-reportada]
- «the randomness included at that epoch is used in the PoRep» [fuente-reportada]

**Qué se compromete, cuándo y ventana:** el minero publica `SealedCID` y hace un depósito
(`PreCommit`); no puede completar la prueba hasta 150 bloques después (`InteractiveEpoch`), y
debe hacerlo antes de que expire el precompromiso. La aleatoriedad que entra en la PoRep se toma
del bloque en la `InteractiveEpoch`, es decir, **posterior** a la publicación del `SealedCID`.
No encontré en esta página el monto exacto del depósito ni el detalle de qué verifica el
verificador on-chain al recibir `ProveCommitSector`; esos detalles están en `porep` y
`miner_collaterals` (ver abajo). Tampoco apareció mención a `UnsealedCID` en esta página.

**Propiedad que demuestra:** (a) obligación de pagar trabajo — el depósito y la ventana obligan a
comprometerse antes de conocer parte de la aleatoriedad, y el sellado real (ver §2-3) es el coste.
No demuestra por sí sola (b), (c) ni (d); esas dependen de la PoRep y de WindowPoSt.

**Supuesto del que depende:** que el depósito sea mayor que el beneficio esperado de un
`PreCommit` vacío o fallido, y que 150 bloques sean suficientes para que la aleatoriedad de
`InteractiveEpoch` sea imprevisible en el momento del `PreCommit`. Ninguna cifra de umbral
apareció en esta página.

**Qué NO demuestra:** que el `SealedCID` corresponda a bytes que existían antes del `PreCommit`
(ver RFT-03 abajo); solo fija un identificador y una fecha de publicación del compromiso.

---

## 2. PoRep (Proof-of-Replication) y Stacked DRG (SDR)

**URL:** https://spec.filecoin.io/algorithms/pos/porep/
**Estado:** `Theory Audit: wip` [fuente-reportada].

**Citas:**
- «Time is included as the blockchain height when sealing took place and the corresponding
  chain reference is called `SealRandomness`.» [fuente-reportada]
- «the miner runs a SNARK on the proof in order to compress it and submits the result to the
  blockchain.» [fuente-reportada]
- PoRep vincula (parafraseado por el extractor, no cita literal en inglés): los datos, el actor
  minero y el tiempo de sellado.
- Se menciona **StackedDrgPoRep** con dos fases: «encoding y replication» y luego generación de
  Merkle proof + árbol con la función Poseidon (parafraseado).

**Qué se compromete, cuándo aparece la aleatoriedad:** `SealRandomness` es la altura de cadena en
la que ocurrió el sellado; la PoRep liga criptográficamente datos + identidad del minero + esa
altura. No apareció en esta página el tamaño de la prueba SNARK ni un enunciado formal explícito
de tipo «space-hardness»; el enunciado es funcional («vincula datos, minero y tiempo»), no una
prueba de seguridad citada en la página misma.

**Propiedad que demuestra:** (b) identificación de réplica — liga una codificación específica a
una clave de minero y a una altura de cadena, no reutilizable trivialmente por otro minero o para
otra altura. También aporta (c) **cota inferior** de tiempo: el cómputo de sellado usó una
aleatoriedad de esa altura, luego el sellado (al menos su fase final ligada a `SealRandomness`)
ocurrió en o después de ese punto. No aporta cota superior ni prueba de que los datos existieran
antes.

**Supuesto del que depende:** que la codificación en capas (DRG/Stacked-DRG) tenga una
profundidad secuencial mínima difícil de saltarse, y que el SNARK de compresión sea sólido y su
setup de confianza correcto. La página no detalla el setup de confianza ni cita una prueba de
seguridad formal para SDR; solo lo nombra.

**Qué NO demuestra:** preexistencia de los bytes **antes** de `SealRandomness` (imposible por
construcción: la aleatoriedad es posterior a la publicación del `SealedCID`, no anterior a los
datos); ni retención posterior al sellado (eso es tarea de WindowPoSt, §4).

---

## 3. Sellado (sealing) y origen de la aleatoriedad

**URL:** https://spec.filecoin.io/systems/filecoin_mining/sector/sealing/
**Estado:** `State: stable`, `Theory Audit: wip` [fuente-reportada].

**Citas:**
- «The ticket has to be drawn from a finalized block in order to prevent the miner from
  potential losing storage» [fuente-reportada]
- «as input to calculation of the ReplicaID in order to tie Proofs-of-Replication to a given
  chain, thereby preventing long-range attacks» [fuente-reportada]
- Fuentes de aleatoriedad citadas: DRAND (baliza distribuida) y un VRF sobre el valor VRF del
  bloque anterior (parafraseado con una frase entre comillas: «The output of a Verifiable Random
  Function (VRF), which takes the previous block's VRF value and produces the current block's
  VRF value»).
- No aparecieron cifras de tiempo de sellado; solo: «sectors can be sealed with commercial
  hardware and sealing cost is expected to decrease over time» [fuente-reportada].

**Qué se compromete, cuándo, ventana:** el `ticket` que entra en el cálculo de `ReplicaID` debe
salir de un bloque **finalizado** (no de la punta de la cadena), explícitamente para evitar
ataques de largo alcance («long-range attacks»). Esto liga la réplica a *un punto ya finalizado
de la cadena*, no a una rama concreta entre varias no finalizadas.

**Propiedad que demuestra:** refuerza (b) identificación de réplica atada a una cadena finalizada
concreta, y de forma indirecta (c) cota inferior de tiempo (no se pudo sellar con ese `ReplicaID`
antes de que ese bloque estuviera finalizado). Es la base técnica de por qué RFT-06 (abajo) aplica
sin cambios: «finalizado» en Filecoin es un punto único de un historial ya decidido, no un
selector entre ramas privadas simultáneas.

**Qué NO demuestra:** que el sellado se hiciera en una rama concreta cuando hay varias ramas no
finalizadas compitiendo por el mismo prefijo finalizado — el ticket es el mismo para todas ellas.

---

## 4. WinningPoSt y WindowPoSt

**URL:** https://spec.filecoin.io/algorithms/pos/post/
**Estado:** `State: reliable`, `Theory Audit: wip` [fuente-reportada].

**Citas:**
- WinningPoSt: «prove that the miner has a replica of the data at the specific time when they
  were asked» [fuente-reportada]
- WindowPoSt: «proof that a copy of the data has been continuously maintained over time»
  [fuente-reportada]
- «every sector of pledged storage is audited...at least once in any 24-hour period»
  [fuente-reportada]
- Estructura: 24 horas divididas en 48 «non-overlapping half-hour deadlines»; particiones de
  «2349 sectors proven simultaneously» [fuente-reportada]
- Verificación: «the miner has indeed stored the pledged sector», mediante prueba comprimida con
  SNARK por partición [fuente-reportada, parafraseado en la parte final]

**Qué se compromete, cuándo aparece la aleatoriedad, ventanas:** WinningPoSt se activa cuando el
minero es elegido por el mecanismo de consenso (Expected Consensus) para proponer bloque, con
reto ligado a ese instante. WindowPoSt divide un día en 48 ventanas de media hora y exige que
cada sector activo sea probado al menos una vez por día, en particiones simultáneas de 2349
sectores. La aleatoriedad del reto de WindowPoSt se toma a una distancia `WPoStChallengeLookback`
antes de la ventana; la página no precisó de forma explícita en el texto recuperado si esa
distancia garantiza un bloque finalizado (a diferencia de §3, donde sí se afirma explícitamente
para el ticket de sellado). Esto queda como dato **no confirmado literalmente** en esta página;
no lo doy por cierto sin más comprobación.

**Propiedad que demuestra:** (e) relación con producción de bloques — WinningPoSt liga
directamente la posesión de una réplica concreta, en el instante del reto, a la elegibilidad para
producir un bloque. (d) retención durante un intervalo — WindowPoSt es la comprobación repetida
que, agregada sobre 48 ventanas/día, aproxima una propiedad de retención continua bajo muestreo,
no una prueba continua real (es un muestreo periódico, no vigilancia continua).

**Supuesto del que depende:** que responder a una ventana de WindowPoSt dentro de media hora sea
más barato si los datos están realmente en disco que si hay que regenerarlos on-demand — es decir,
que el coste/tiempo de regenerar la réplica sellada exceda la ventana de reto. La página no publica
una cifra de ese coste de regeneración; solo describe el mecanismo de auditoría.

**Qué NO demuestra:** que la retención sea continua en sentido estricto (es muestreo cada 24h por
sector, con particiones agregadas), ni que la capacidad probada en WinningPoSt sea la misma
mercancía física en dos historias de la cadena compitiendo simultáneamente (eso es aparte, y
Filecoin no tiene el problema de ramas privadas largas de la misma forma que un DAG con reorg,
porque opera sobre Expected Consensus con su propio mecanismo de selección, no sobre el modelo de
ZEROX).

---

## 5. Faltas de sector (sector faults)

**URL:** https://spec.filecoin.io/systems/filecoin_mining/sector/sector-faults/
**Estado:** `State: stable`, `Theory Audit: wip`, última modificación 8 de julio de 2024
[fuente-reportada].

**Citas:**
- «This fee is paid per sector per day while the sector is in a faulty state»; «a one day grace
  period for recovery without fee» [fuente-reportada]
- «a sector is in a faulty state for too long» → tras más de 42 días consecutivos, el sector se
  retira del estado de cadena (parafraseado; la cifra de 42 días fue devuelta como dato concreto
  por el extractor, no verificada carácter a carácter por mí)
- «capped at 90 days worth of block reward» [fuente-reportada]
- «Without this incentive, it is impossible to distinguish an honest miner's hardware failure
  from malicious behavior» [fuente-reportada]

**Qué demuestra y qué NO:** la propia página admite, en la cita anterior, que el mecanismo **no
distingue técnicamente** un fallo honesto de disco de un abandono malicioso; la distinción es
puramente económica (una cuota diaria que, agregada, hace indiferente —o desincentiva— dejar de
responder, sin necesitar causa verificada). Esto es relevante para ENCARGO-05 §3.3: Filecoin
mismo reconoce que «ausencia observable no prueba su causa» y responde con una gracia de 1 día,
una cuota (no confiscación inmediata) y una terminación solo tras 42 días. No hay aquí prueba
criptográfica de intención; es un diseño de incentivos, no de detección.

---

## 6. Colaterales de minero

**URL:** https://spec.filecoin.io/systems/filecoin_mining/miner_collaterals/
**Estado:** `State: reliable` [fuente-reportada].

**Citas:**
- «initial pledge collateral, block reward as collateral, and storage deal provider collateral»
  [fuente-reportada]
- Pledge de almacenamiento: «Estimated20DaysSectorBlockReward» [fuente-reportada]
- Pledge de consenso: «30% × FILCirculatingSupply × (SectorQAP/max(NetworkBaseline,
  NetworkQAP))» [fuente-reportada]
- La pledge de almacenamiento cubre «7 days worth of Sector fault fee» (parafraseado)
- «Fault fees are slashed first from the soonest-to-vest unvested block rewards followed by the
  miner's account balance.» [fuente-reportada]

**Qué demuestra:** ninguna propiedad criptográfica; es el diseño económico que ata una garantía
al tamaño de la potencia declarada (`SectorQAP`) y al circulante, no al espacio físico verificado
byte a byte. **Estas fórmulas son hechos de Filecoin, citados con fuente; no son parámetros de
ZEROX** y no se trasladan sin rediseño, dado que POS2T mide garantía por clave, no por sector
(`D-ZRX/SPEC.md`, según `ANALISIS.md` §2).

---

## 7. rust-fil-proofs: cifras de sellado y tamaño de prueba

**URL:** https://github.com/filecoin-project/rust-fil-proofs (README) y
https://github.com/filecoin-project/rust-fil-proofs/blob/master/README.md

**Resultado:** la página cargó correctamente, pero **no contiene lo esperado**: no hay tabla de
benchmarks con tiempos de sellado por tamaño de sector (32 GiB/64 GiB), tamaño de la prueba SNARK
en bytes ni tiempo de verificación. El README solo documenta la herramienta `benchy` y comandos
para *ejecutar* benchmarks (p. ej. `cargo run --release --bin benchy -- window-post --size
2KiB`), sin resultados numéricos publicados en el propio archivo. Sí confirma el nombre del
esquema: `StackedDrgPoRep` en el crate `storage-proofs-porep`, y una nota de optimización:
«multicore SDR uses multiple cores...to assemble each nodes parents» (fase 1 de PreCommit)
[fuente-reportada]. Esta última frase es relevante para §8: indica que, aunque SDR impone una
estructura de capas con dependencias (grafo DRG), el trabajo de *ensamblar los padres de cada
nodo* admite paralelismo multi-núcleo dentro de una fase. No encontré, en esta página, una cifra
de la profundidad secuencial mínima ni del tiempo de sellado. **No inspeccioné el documento
académico de Stacked DRG enlazado por separado ni las páginas de benchmarks históricas fuera de
GitHub**; queda como fuente no consultada en esta ronda (ver resumen final).

---

## 8. Límites de transferencia a ZEROX

El PoAS de ZEROX (formato Autonomys-style) es, según `RFT-04`, un objeto **determinista, público
y paralelizable por unidad**: cualquier auditoría por muestreo sobre ese formato solo encarece la
regeneración dentro del plazo, no la distingue de almacenamiento real. Según `RFT-03`, ningún
compromiso sobre el **valor** de un objeto (raíz, `SectorId`, fecha de alta) fecha nada, de forma
incondicional — y esto se cumple también para la PoRep de Filecoin: lo que aporta no es
preexistencia, sino una **cota inferior** de tiempo (cómputo después de `SealRandomness`), tal
como anticipa `RFT-03` explícitamente en su «Qué NO dice».

Contraste mecanismo por mecanismo:

- **PreCommit + depósito (§1):** aporta (a) obligación de pagar, no (c) ni (d). En ZEROX no hay
  hoy nada equivalente: `D-ZRX/SPEC.md` registra garantía por clave (C-BON), no un depósito ligado
  a un sector concreto antes de producir con él.
- **PoRep/SDR (§2-3):** aporta (b) identificación de réplica + cota inferior de tiempo, **si y
  solo si** la codificación tiene profundidad secuencial real. Esta es exactamente la hipótesis
  que `RFT-04` señala como la única vía para «reabrirse»: «romper... la paralelizabilidad
  (sellado secuencial tipo PoRep)». El indicio de rust-fil-proofs (§7) de que SDR admite
  paralelismo *intra-fase* (multi-core) no refuta esto: `RFT-04`/`ENCARGO-04` piden separar
  **trabajo total** (paralelizable) de **profundidad secuencial** (el número mínimo de pasos que
  no se pueden solapar, propio del grafo de dependencias entre capas). Un formato con
  dependencias DRG en capas puede tener trabajo por capa paralelizable y, aun así, imponer una
  profundidad secuencial mínima entre capas que ningún número de núcleos elimina. **Esta es la
  hipótesis que SÍ cambiaría** si un formato tipo SDR se adoptara para el objeto de ZEROX: podría
  convertir una auditoría de «solo encarece» en «detecta regeneración» bajo un plazo de reto menor
  que esa profundidad secuencial mínima medida en el hardware más rápido disponible.
- **Sellado ligado a bloque finalizado (§3):** el ticket «has to be drawn from a finalized
  block», precisamente para «preventing long-range attacks» — pero un bloque finalizado es un
  único punto de un historial ya decidido, **no** un discriminador entre varias ramas privadas
  no finalizadas que comparten ese mismo prefijo. Esto es exactamente `RFT-06`: «El ticket de
  Filecoin se toma de un bloque finalizado y no separa forks.» **Esta hipótesis NO cambia** con
  un sellado secuencial tipo SDR: la secuencialidad ataca la *paralelizabilidad del cómputo*
  (relevante para RFT-04), no el *problema de a qué rama está atado el objeto* (relevante para
  RFT-06). Un atacante con dos ramas privadas que comparten el mismo prefijo finalizado puede
  usar el mismo sector sellado —con el mismo ticket— en ambas, exactamente como advierte
  `ENCARGO-05` §3.1 («uso en dos ramas privadas») y como cierra el propio encargo: «El sistema no
  puede declararse solución al doble farmeo de una rama que nunca revela una segunda firma.» El
  doble uso entre ramas de `RFT-06` es, por tanto, una vía **estructuralmente distinta** de la que
  ataca `RFT-04`; ningún PoRep, por secuencial que sea, la cierra por sí solo, porque no liga el
  objeto a una rama sino a un punto ya finalizado del historial — y ZEROX, a diferencia de
  Filecoin/Expected Consensus, es precisamente el caso con DAG y reorg donde puede no haber un
  único «bloque finalizado» reciente disponible a tiempo.
- **WindowPoSt (§4):** aporta (d) retención por muestreo periódico agregado, bajo el supuesto no
  cuantificado aquí de que regenerar cueste más que la ventana de reto. Es la pieza más cercana a
  lo que `ENCARGO-02`/G2 de `ANALISIS.md` piden medir para ZEROX (coste adversarial de
  regeneración frente a plazo), pero Filecoin no publicó, en las páginas revisadas, la cifra de
  ese coste de regeneración ni el tiempo de sellado — no hay cifra que trasladar, solo el diseño
  del muestreo (48 ventanas/día, partición de 2349 sectores).
- **Faltas y colateral (§5-6):** confirman, con la propia fuente de Filecoin, que la ausencia
  observable «no prueba su causa» (cita §5) y que la respuesta es gradual (gracia de 1 día, cuota
  diaria, terminación a 42 días) antes de cualquier confiscación fuerte — coherente con lo que
  `ENCARGO-05` §3.3 exige para ZEROX: no activar slashing automático por ausencia sin modelo de
  falsos positivos.

**Conclusión de esta ronda de fuentes:** ninguna de las seis páginas afirma, ni por asomo, que su
mecanismo resuelva el doble farmeo entre ramas privadas; ese problema (RFT-01, RFT-06) es ajeno al
diseño de Filecoin porque su modelo de consenso no tiene el mismo tipo de bifurcación sostenida
que un DAG con reorg. La única propiedad de Filecoin con potencial real de trasladarse —bajo
hipótesis explícitas y sin garantía— es la profundidad secuencial de un sellado tipo SDR frente a
`RFT-04`; no hay, en las fuentes revisadas, cifra publicada de esa profundidad ni del tiempo de
sellado que permita hoy cuantificar la ventaja.

---

## Resumen para decisión (no es el criterio de cierre de ENCARGO-05)

Esta investigación de fuentes no emite un veredicto de descartar/investigar/ratificar: es insumo
para las puertas G1-G5 de `ANALISIS.md` y el Encargo 05. El hallazgo operativo es que **la única
vía con potencial de aportar algo nuevo a ZEROX es un formato con profundidad secuencial real
(tipo SDR)**, evaluable frente a `RFT-04`, y que **ningún mecanismo de Filecoin revisado aquí
toca el problema de ramas privadas (`RFT-01`/`RFT-06`)**, que sigue exigiendo una vía fuera de la
familia determinista-pública, tal como esas refutaciones ya concluían antes de esta lectura.
