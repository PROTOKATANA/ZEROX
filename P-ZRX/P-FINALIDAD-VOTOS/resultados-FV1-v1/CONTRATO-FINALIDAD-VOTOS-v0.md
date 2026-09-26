# CONTRATO-FINALIDAD-VOTOS-v0 — Capa de finalidad por votos bajo R1–R5

**Orden:** FV-1. **Ejecutor:** Sonnet (diseño y análisis; sin código de producto). **Fecha:** 2026-09-26.
**Estado:** propuesta ratificable, **no normativa** hasta que Katana la apruebe. No cambia `D-ZRX/SPEC.md`
ni `P-ZRX/P-TRANSICION/CONTRATO-v0.md`: es una capa superpuesta (§0 de este documento).

Etiquetas: **[P]** fuente primaria leída en esta orden · **[S]** fuente secundaria · **[D]** derivación
propia sobre reglas ya fijadas del repositorio · **[H]** hipótesis de este contrato, no probada.
Ninguna cifra de memoria: toda cifra citada remite a `INFORME.md` (que a su vez remite al `.tsv` de
`calc/resultados/`) o a un documento ya validado del repositorio.

---

## 0 · Qué es y qué no es esta capa

- **Es** una capa de acuerdo bizantino (GossiPBFT, candidato) que corre en paralelo a PoAS+PoT+DAG y
  produce, de vez en cuando, un **certificado** que sella un prefijo ya seleccionado por GHOSTDAG.
  Es el patrón *ebb-and-flow* **[P]** (Neu, Tas, Tse, *Ebb-and-Flow Protocols: A Resolution of the
  Availability-Finality Dilemma*, IEEE S&P 2021 — leído vía `arxiv.org/abs/2009.04987`): «a full
  dynamically available ledger in conjunction with a finalized prefix ledger»; «the finalized ledger
  falls behind the full ledger when the network partitions but catches up when the network heals».
- **No es** un cambio de quién produce bloques, quién cobra, GHOSTDAG ni `blue_work` (mandato §3.2).
  `SPEC.md` §0 se mantiene: la garantía no da turnos ni peso de producción. **FV-1 no decide** si el
  peso del voto puede ser stake (§5 de este documento, decisión de Katana).
- **No es** un comité fijo ni muestreado por elección: es voto directo, ponderado por el recurso
  verificado en la cadena, de **todo el que tenga peso por encima de un mínimo estructural** (§2). Esto
  es una desviación deliberada de la propuesta antigua (`research/dag-poas-capa-finalidad.md`,
  R-FIN-16), que sorteaba `K` plazas; aquí no hay sorteo (§2.4 justifica por qué, y el bloque 2 de
  `calc/` cuantifica lo que se evita).
- **`C-FIN-01` no se toca.** Sigue siendo la red de seguridad: un nodo en línea no sustituye su cadena
  por una que bifurque a `d ≥ F_slots` **[P]** (`P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md` §10.4,
  `git show 9681061:...`, leído en `.trash/zerox`). Esta capa **añade** una finalidad más rápida al lado;
  no baja `F_slots` (mandato §3.3, y ya lo advertía el director en `CONTEXTO.md` §4.6.3).

---

## 1 · FV-01…FV-05 · Fuente del peso, tabla de pesos y su compromiso

**FV-01 · Interfaz `FuenteDePeso`, sustituible.** El contrato no fija la fuente del peso: define una
interfaz `peso: pk → ℕ`, función **solo del pasado validado** (`past(A_n)`, nunca de la vista local ni
del futuro), con tres candidatos — el mismo patrón de «interfaces sustituibles» que ya usa
`P-ZRX/P-TRANSICION/CONTRATO-v0.md` §8 **[D]**:

| Candidato | `peso(pk)` se deriva de | Retardo (*lookback*) natural |
|---|---|---|
| **(A) bloques cobrados** | Bloques azules/`rojo_k` que cobran (R-FIN-8′) con `sol.public_key = pk`, en una ventana `W_POWER` de slots | Ninguno propio: la ventana ya mira al pasado |
| **(B) sectores registrados** | Capacidad activa y auditada de `pk` en el registro de `P-REGISTRO-SECTORES` (QAP, análogo a F3) | El de la maduración del registro (`M_sec`, abstracto en `SEC-A`) |
| **(C) garantía `C-BON`** | `Garantía[pk].activo` (`C-BON-01`) | El de `C-BON-04` (evaluado en `past(B)`) |

Las tres son función exclusiva de `past`, cumplen la letra de **R2** («el peso es el recurso verificado
en la cadena; nunca votos de terceros ni métricas externas») y no necesitan permiso (**R1**). La
comparación completa, con coste y ataque, está en `INFORME.md` §3; **este contrato no elige una**
(mandato §3.6): se escribe para que cualquiera de las tres se pueda enchufar sin reescribir FV-02…FV-24.

**FV-01b · La tabla de poder se HEREDA por la cadena de certificados; no se recalcula libremente en
cada nodo cuando ya existe un certificado que la fija.** Éste es el punto que decide si (c) de la
pregunta falsable se sostiene bajo partición de red, y **no estaba escrito con esta precisión en la
propuesta antigua** (R-FIN-15 solo decía que la tabla «es función de `past(A_n)` y de nada más, luego
todo nodo honesto calcula la misma» — cierto **mientras todos vean el mismo `past`**, y falso en cuanto
dos nodos ven `past` distintos). La regla exacta: la tabla de poder de la instancia `n` es (i) la que el
certificado de la instancia `n-1` comprometió como tabla de `n` (FV-03), verificada por hash, si ese
certificado existe y el nodo lo conoce; o (ii), **solo** si ningún certificado la comprometió todavía
(arranque, FV-28/29), la que el propio nodo deriva de `past(A_{n-LOOKBACK})`. Un nodo que no pueda
reproducir ni verificar la tabla comprometida por (i) **MUST NOT** sustituirla por una recalculada
localmente: se declara sin tabla para esa instancia y, por tanto, sin voto posible (pasa a FV-20,
pausa). **[D]**, con el precedente exacto de F3 **[P]**: «the committee of participants for an instance
of GossiPBFT is determined by the chain state resulting from the tipset **finalized by a previous
instance**» (FIP-0086) — la tabla cuelga de una instancia YA finalizada, no de la vista local de cada
nodo en cada momento.

**Por qué hace falta, con el contraejemplo que lo exige.** Sin FV-01b, un ataque de **partición de red
pura** (sin ninguna clave doblemente firmante) rompe (c): supóngase la fuente de peso (A) —bloques
cobrados en una ventana— y una partición que separa la red en dos mitades `X`/`Y` sin ninguna vía entre
ellas. Si cada nodo recalculara la tabla de poder de la instancia `n` **desde su propio `past` local**
(la letra literal de R-FIN-15 de la propuesta antigua), la tabla de `X` contendría **solo** las claves
que produjeron bloques visibles para `X` — es decir, prácticamente el 100 % de lo que `X` puede ver—, y
lo mismo para `Y`. Con esa tabla local, la mayoría honesta **dentro de cada mitad** basta para un
certificado válido **según esa tabla local**, aunque la mitad en cuestión tenga, digamos, el 20 % del
peso real de toda la red. Las dos mitades certificarían historias contradictorias, **cada una localmente
válida y verificable, sin que ninguna clave haya firmado dos votos**: la falta de FV-23 no se dispara
—no hay evidencia porque no hay doble firma—, y sin embargo el sello se rompe. Esto es **peor que
`C-FIN-01` sola**, que ante la misma partición no produce ningún objeto que parezca autoritativo para
todo el mundo (cada lado simplemente sigue su propia cadena, sin certificado que lo blinde); viola la
condición (c). **Con FV-01b, la tabla que ambas mitades deben usar para la instancia `n` es la que el
último certificado PRE-PARTICIÓN comprometió** (la del `past` compartido antes de partirse): ninguna
mitad puede, por definición, reunir sobre ESA tabla compartida un `2/3` que no tenga en la realidad,
salvo que ya tuviera esa mayoría antes de partirse (ataque 1/2 del análisis adversarial, no éste). El
residuo declarado: **la primerísima tabla, antes de que exista ningún certificado (FV-28/29), no tiene
este blindaje** — es exactamente la ventana de activación prematura (ataque 11). **[D]**, hallazgo de
esta orden; no citado en `CONTEXTO.md` §4.1, que declaraba la hipótesis «como mucho sella un lado; el
otro se pausa» **sin comprobarla contra P-FLUJO** — comprobada aquí, y **refutada para el diseño sin
FV-01b**, **sostenida con FV-01b** salvo el residuo de activación.

**FV-02 · Retardo (`LOOKBACK`).** La tabla de poder de la instancia `n` se deriva de `past(A_{n-LOOKBACK})`,
donde `A_m` es el bloque de cadena seleccionada certificado por la instancia `m` — el mismo patrón que
F3 **[P]** (`PowerTableLookback = 10`, FIP-0086, `github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0086.md`,
leído íntegro en esta orden). `LOOKBACK` es un símbolo (§9); su función es que la tabla de poder de la
instancia en curso ya esté fijada cuando arranca, sin depender de bloques que la propia instancia podría
influir. **[D]** El retardo no cierra el sesgo del atacante sobre QUÉ bloques entran en la ventana de
poder (ataque 3, §Análisis adversarial): eso es orden de publicación, no de tiempo.

**FV-03 · Compromiso de la tabla siguiente dentro del certificado.** Todo certificado incluye el hash
de la tabla de poder que validará la instancia `n+1` — literal de F3 **[P]**: «A CID of the power table
CID corresponding to the next instance is included»; «the DagCBOR-blake2b256 CID of the power
table/committee to be used to validate the next instance» (FIP-0086, ídem). Es lo que hace la cadena de
certificados **autosuficiente**: se verifica desde génesis sin la cadena de bloques (FV-15).

**FV-04 · Mínimo estructural de participación (`q_voto`).** Solo `pk` con `peso(pk) ≥ q_voto > 0` entra
en la tabla de poder. `q_voto` es un símbolo (§9), **no** un sorteo ni una elección: es un umbral
mecánico, igual que `requisito(B) > 0` de `C-BON-04` **[D]**. Sin él, la interfaz (A) podría dar una
entrada de bitmap por cada clave que cobró un solo bloque en la ventana, inflando el certificado sin
aportar peso significativo (cuantificado en `calc/resultados/b3-*.tsv`).

**FV-05 · Escalado a entero de 16 bits, análogo a F3.** El peso normalizado de cada `pk` se escala para
que la suma total quepa en un entero acotado — literal de F3 **[P]**: «scaled such that the total power
of all participants fits in a 16-bit unsigned integer» (FIP-0086). **[D]** Es una decisión de
codificación, no de seguridad: el umbral de `2/3` se calcula sobre el entero escalado, y el redondeo
**MUST** favorecer al lado que exige `techo_exacto` (mismo criterio que `C-SLA-03`/`EV-19`, redondeo
hacia arriba en la confiscación, hacia abajo en el poder para no inflarlo).

---

## 2 · FV-06…FV-11 · Quién vota

**FV-06 · Todos los que tienen peso, sin sorteo.** Vota toda `pk` con `peso(pk) ≥ q_voto` en la tabla de
poder de la instancia. **No hay sorteo de plazas.** Esta es la desviación deliberada frente a R-FIN-16
de la propuesta antigua, y es la que satisface **R1** de forma literal: «participa cualquiera con el
recurso, sin permiso ni elección» — un sorteo, aunque sea limpio, es una **elección** (aleatoria, pero
elección) de quién vota en cada instancia, y abre exactamente el ataque que la propia propuesta antigua
declaró como su «hueco mayor» (§4.D, sesgo del sorteo por elección de ancla) **[S]** (cita literal en
`research/dag-poas-capa-finalidad.md`, leído en `.trash/zerox`, reproducido en `calc/resultados/b2-*.tsv`).
Sin sorteo, ese ataque **no tiene superficie**: no hay plazas que ganar por azar (§Análisis adversarial,
ataque 3). El precio es el tamaño del certificado, que crece con el número de votantes, no con `K`
(FV-20…FV-22 y `calc/resultados/b3-*.tsv`).

**FV-07 · Prohibido usar prueba de vida como filtro de entrada.** La propuesta antigua restringía el
sorteo a claves con un bloque cobrado en los últimos `W_VIVO = 1800 s` (R-FIN-16, `research/dag-poas-capa-finalidad.md`
§3) para resolver el problema de la §4.C (granjeros domésticos apagados). **Esta capa no adopta ese
filtro como condición de ADMISIÓN**: exigir «actividad reciente» para poder votar es una elección
—decide quién entra según una métrica adicional al peso mismo— y viola **R1/R2** tal como el mandato los
formula («entrada abierta»; «nunca... métricas externas»). Lo que la propuesta antigua resolvía con
`W_VIVO` (que el comité represente solo a quien puede firmar) se resuelve aquí de otra forma: **el
quórum se mide sobre el peso TOTAL, no sobre los presentes** (FV-13), y el problema de la §4.C se declara
como lo que es —una restricción de VIVEZA, no de admisión— y se cuantifica en `calc/resultados/b1-*.tsv`
sin filtrar a nadie de la tabla. **[D]**

**FV-08 · Clave de voto.** Firma la misma `sol.public_key` del sello del bloque que dio el peso (fuente A),
o la clave declarada por el titular de la garantía/registro (fuentes B/C), bajo el mismo esquema Ed25519
del resto del protocolo **para el registro de la clave**, con agregación **BLS12-381** para la firma del
certificado (FV-19). No hay una «clave de voto» separada obligatoria por defecto: eso abriría exactamente
el patrón de delegación que el ataque 7 explota (§Análisis adversarial) si se presenta como conveniencia.
Una implementación que quiera separar clave de producción y clave de voto puede hacerlo (declarando la
segunda con una operación firmada por la primera, mismo patrón que `R-FIN-20` de la propuesta antigua),
pero **el consenso no la exige** y el registro de esa declaración pesa sobre quien la usa: si delega la
firma del voto a un tercero, es exactamente la firma a ciegas de `P-ZRX/P-POOLS/` trasladada al voto
(ataque 7). **[D]**

**FV-09 · Sin cupo por clave.** Ninguna clave tiene un tope de peso votante distinto de su `peso(pk)` real.
Repartir el mismo espacio/garantía en muchas claves no cambia el peso total votante (mismo principio que
`RFT-05`/R-9: «repartirse en muchas claves no cambia nada, el peso se suma» — `CONTEXTO.md` §4.5). **[D]**

**FV-10 · El voto es sobre la instancia, no sobre contenido libre.** Lo único que una `pk` puede firmar en
la instancia `n` es una de las propuestas válidas de esa instancia: el bloque de la cadena seleccionada
localmente en el `lookback` correspondiente, o `⊥` (ningún acuerdo, análogo a la «propuesta base» de
GossiPBFT). **No existe** un campo libre de contenido en el voto: esto es la forma exacta de **R4** («los
votos solo sellan lo ya producido») — un votante no puede proponer una transacción, un orden alternativo
ni una cadena que él mismo no haya visto seleccionada por GHOSTDAG. **[D]**

**FV-11 · El voto respeta la frontera de flujo.** Un certificado de la instancia `n` **MUST** referirse a
un único flujo de PoT (`flujo(·)`, `C-FLU-10`): la propuesta que se vota es el bloque de cadena
seleccionada **dentro del mismo flujo** que el `past(A_{n-LOOKBACK})` que fijó su tabla de poder. Esta
regla es la traducción directa de `C-FLU-14` («un bloque MUST NOT referenciar un bloque de otro flujo») a
la capa de votos, y cierra por construcción el ataque 5 del análisis adversarial (un certificado que
cruce flujos) **[D]**, sobre la base **[P]** de `C-FLU-13/14` (`P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md`
líneas 1036–1123, leído en `.trash/zerox`): «un nodo honesto jamás verifica el PoT de un flujo ajeno», y
un bloque de otro flujo «no es referenciable». Un certificado que intentara sellar un bloque de un flujo
distinto del que su propia tabla de poder deriva es, por definición, **inadmisible**: no hay regla de
consenso PoAS+PoT+DAG bajo la que ese bloque sea válido para el observador, así que no hay nada que
certificar.

---

## 3 · FV-12…FV-16 · Protocolo de acuerdo y certificado

**FV-12 · GossiPBFT como candidato, con los parámetros de F3 citados literalmente y recalibrados.**
Fases por ronda: `QUALITY`/`CONVERGE`, `PREPARE`, `COMMIT` (F3 documenta un multiplicador adicional en
`QUALITY` para mejorar la propagación) **[P]**; el temporizador de cada fase es
`phase_timeout = 2·Δ_F·BackOffExponent^ronda` (cita literal de FIP-0086, «Participants start each
instance with `Δ=6s` and for each round, set the phase timeout to `2 * Δ * BackOffExponent^{round}`»).
**`Δ_F` no es la `Δ` de propagación de bloques de ZEROX** (esa `Δ` sigue sin medir en red real, IPA B-05):
es el parámetro propio del protocolo de acuerdo, y debe calibrarse **con** la `Δ` de red simulada
disponible (DMS-v0.1: p99 entre 0,26 y 0,60 s) más un margen, no copiarse el `6 s` de Filecoin sin
justificar (Filecoin calibra sobre su propia red). `calc/resultados/b4-*.tsv` barre `Δ_F` en
{0,26; 0,60; 4; 6; 16} s precisamente para no fijar un valor de producción aquí.

**FV-13 · Quórum sobre el peso TOTAL, no sobre los presentes.** Un certificado válido exige firmas que
sumen `≥ 2/3` del peso **total** de la tabla de poder de la instancia — cita literal de F3 **[P]**:
«Every certificate output by F3 is signed by ≥ ⅔ of the total QAP»; y el predicado exacto,
`IsStrongQuorum`, devuelve verdadero si `Power(p) ≥ ⌈⅔·Power(P)⌉`. La propuesta antigua ya descartó, con
número, la alternativa de exigir `2/3` de los **presentes**: con `α = 0,30` y `p = 0,80` (80 % de
honestos encendidos) esa variante deja al atacante con el `34,9 %` de los presentes, por encima de un
tercio **[S]** (`research/dag-poas-capa-finalidad.md` §4.C, recalculado de forma independiente y
confirmado por el bloque 1 de `calc/`).

**FV-14 · Solo sella prefijos de la cadena seleccionada; nada sobre contenido (R4).** La instancia `n`
solo puede decidir por el bloque de la cadena seleccionada por PoAS+PoT+DAG en el punto de `lookback`
(FV-02), o por «no decide» (`⊥`, viveza sin acuerdo). No hay una tercera opción de contenido arbitrario.
Es la forma exacta de la letra de F3: el certificado envuelve una decisión GossiPBFT sobre **una** cadena
ya producida por el mecanismo de base (EC en Filecoin, PoAS+PoT+DAG en ZEROX), nunca la inventa. **[D]**

**FV-15 · Certificado: contenido y verificación desde génesis.** Un certificado de la instancia `n`
contiene: número de instancia `n`; hash del bloque certificado; mapa de bits de firmantes sobre la tabla
de poder de `n`; firma **BLS12-381** agregada (G2 comprimido, 96 B) de los firmantes marcados en el mapa
de bits; hash de la tabla de poder de `n+1` (FV-03). La cadena de certificados `Cert_0, Cert_1, …, Cert_n`
se verifica **sin** la cadena de bloques: cada `Cert_{m+1}` usa la tabla de poder que `Cert_m` comprometió
— cita literal **[P]**: «Verifying the finality of a tipset from genesis does not require access to the
EC chain» (FIP-0086). Coste de verificación por certificado: dos operaciones de emparejamiento BLS
(agregada) más una comprobación de peso sobre el mapa de bits, `O(1)` respecto al tamaño de la historia —
igual que `EV-09` del contrato de evidencia (`P-ZRX/P-SLASHING/resultados-SL1/CONTRATO-EVIDENCIA-v0.md`)
consigue `O(1)` para la doble firma de bloques. **[D]**

**FV-16 · Esquema de firma: BLS obligatorio, con la misma bifurcación que la propuesta antigua ya señaló.**
Con voto directo (sin sorteo) el número de firmantes de un certificado puede llegar a ser el número total
de claves con `peso ≥ q_voto`, potencialmente mucho mayor que los `K = 4000` de la propuesta antigua.
Ed25519 sin agregar es **inviable** a esa escala (`calc/resultados/b3-*.tsv` lo cuantifica de nuevo, sin
asumir el número antiguo). BLS agregada es la única opción que cabe. **Esto reabre exactamente la
bifurcación que `research/dag-poas-capa-finalidad.md` §5 dejó para Katana**: `blst` (C + ensamblador,
auditado por NCC Group, en producción en Ethereum y Filecoin) frente a `bls12_381` de zkcrypto (Rust puro,
`no_std`, sin auditoría — su propio README: «This implementation has not been reviewed or audited»)
**[S]** (cita ya verificada por el director en esa fuente, recogida aquí sin re-verificarla). **[H]**
Este contrato no la resuelve: la señala como parámetro abierto (§9) y recomienda, si Katana ratifica esta
capa, `blst` confinado como excepción de FFI (mismo patrón ya aceptado para `zx-miner`), con `bls12_381`
como oráculo de contraste en tests diferenciales — es la misma recomendación de la propuesta antigua, y
nada en este análisis la cambia.

---

## 4 · FV-17…FV-19 · Convivencia con `C-FIN-01`

**FV-17 · Regla de selección con certificado.** Un nodo **MUST NOT** seleccionar, como cadena preferida,
una que bifurque por debajo del bloque certificado más profundo que conozca — mismo enunciado que
R-FIN-18 de la propuesta antigua **[S]**, adaptado: «un certificado nunca invalida un bloque ni apaga el
proceso; una punta que exigiera reorganizar por debajo de él se IGNORA, igual que en `C-FIN-01`». Entre
las dos reglas de no-reorganización manda la que prohíba primero: `C-FIN-01` prohíbe a `d ≥ F_slots`; un
certificado prohíbe por debajo de su propio bloque, sea la profundidad que sea (normalmente mucho menor
que `F_slots`, §Análisis numérico, bloque 4). **La finalidad por certificado, cuando existe, es siempre
al menos tan restrictiva como `C-FIN-01`**, nunca menos: por eso puede coexistir sin abrir un tercer
criterio de selección contradictorio. **[D]**

**FV-18 · Demostración de (c): con la capa pausada, rota o sin activar, ningún nodo queda peor que con
`C-FIN-01` sola.** *Prueba.* Si no hay certificado aplicable (capa pausada, sin quórum, o antes de la
activación, §6), FV-17 no aporta ninguna restricción adicional a la de `C-FIN-01`: la regla de selección
se reduce exactamente a `C-FIN-01` (TRN-09/FC-3). Si la capa está **rota** (un atacante logra dos
certificados contradictorios, §Análisis adversarial ataque 2), un nodo que reciba el certificado falso
**MUST** verificarlo contra su propia tabla de poder derivada de `past` (FV-01/FV-13): un certificado que
no reúna `2/3` del peso total de la tabla que el nodo calcula **se rechaza como inválido**, exactamente
como cualquier objeto mal formado — no hay ninguna vía por la que un certificado inválido empeore la
posición de un nodo que simplemente lo descarta y sigue con `C-FIN-01`. El único caso en que (c) podría
fallar es que el propio código de verificación de certificados introdujera una superficie de denegación
de servicio (ataque 9) o que un nodo aceptara un certificado sin verificarlo — ambos son defectos de
implementación, no de esta regla. `∎` **[D]**, con la estructura de demostración de
`P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md` §0.4 (A1, «inmutabilidad por herencia») como precedente de
método, no de contenido.

**FV-19 · La «mentira permanente»: qué recuperación existe si `2/3` certifican algo falso.** Si un
atacante reúne de verdad `2/3` del peso total y produce un certificado sobre un bloque que **no** es el
que la mayoría honesta de espacio habría seleccionado, **el certificado es válido por construcción**
(cumple FV-13) y **ningún nodo que lo verifique correctamente puede rechazarlo**: es la definición misma
de tener `2/3`. Esto es lo que la propuesta antigua llamaba, en su §6.1, la mentira permanente. **No hay
recuperación dentro de esta capa**: un certificado, una vez válido, no se puede invalidar retroactivamente
sin romper FV-15 (la cadena de certificados sería entonces subjetiva, no verificable desde génesis). La
única «recuperación» posible es **fuera del protocolo**: una decisión social (hard fork) que repudie la
tabla de poder comprometida — el mismo remedio, y el mismo límite, que tiene Casper FFG frente a `≥ 1/3`
bizantino con evidencia **[P]** («Two conflicting checkpoints cannot both be finalized» unless «≥1/3 of
the validators violate one of the two Casper Commandments», Buterin & Griffith, arXiv:1710.09437, leído
vía `arxiv.org/html/1710.09437v4`) o que Filecoin F3 frente a `> 1/3` bizantino: ninguno de los dos
promete recuperación automática. **Esto deja a ZEROX, en el escenario de `2/3` bizantino, exactamente
igual que hoy** (`C-FIN-01` sola tampoco recupera un ataque de mayoría de peso PoST sostenida, §Análisis
adversarial ataque 12) — no **peor**: la condición (c) sigue sosteniéndose porque «igual que hoy» no es
«peor que hoy». **[D]**

---

## 5 · FV-20…FV-22 · Pausa y reanudación (R3)

**FV-20 · Pausa, no fuga.** Si ninguna instancia alcanza quórum durante `S_pausa` instancias
consecutivas (símbolo, §9), la capa **se pausa**: el nodo deja de esperar certificados y opera con
`C-FIN-01` como único criterio de finalidad, sin detenerse, sin abortar y sin exigir intervención del
operador — mismo `MUST NOT` de `C-FIN-01` (`PROPUESTA-SPEC.md` §10.4). **No se adopta una fuga de
inactividad** (drenar el saldo/peso de los votantes ausentes hasta que los presentes controlen `2/3`,
como Ethereum **[P]**: «gradually reduces the stakes of validators who are not making attestations
until... the participating validators control 2/3 of the remaining stake», eth2book, «Inactivity leak»)
por el mandato §3.4 («Pausa, no fuga») y porque **arXiv:2404.16363** (Pavloff, Amoussou-Genou,
Tucci-Piergiovanni, *Byzantine Attacks Exploiting Penalties in Ethereum PoS*, leído vía su resumen y
metadatos en `arxiv.org/abs/2404.16363`) muestra el precio exacto que se evita: la fuga puede, bajo
coordinación bizantina, **acelerar la finalización de dos ramas contradictorias** y dejar a validadores
bizantinos superar el tercio de poder de voto efectivo — cita **[P]**: «scenarios where actions by
Byzantine validators expedite the finalization of two conflicting branches»; «voting power exceeding the
critical safety threshold of one-third»; «a probabilistic breach of safety». **La fuga por inactividad,
en el modelo de amenaza de Katana (atacante de Estado, dispuesto a coordinar), es un mecanismo que
convierte una PAUSA segura en un RIESGO de doble sello.** No se adopta. `INFORME.md` §6 la deja como
comparador con su precio documentado, tal como pide el mandato §3.4.

**FV-21 · Reanudación.** La capa se reanuda automáticamente en cuanto una instancia alcanza quórum
`2/3` de nuevo: no hace falta ninguna acción del operador ni un nuevo checkpoint de arranque. Es
consecuencia directa de que la tabla de poder es función determinista de `past` (FV-01): en cuanto el
peso presente vuelve a superar el umbral, cualquier nodo que reciba las firmas puede formar el
certificado. **[D]**

**FV-22 · Qué protege durante la pausa.** Mientras la capa está pausada, rige exactamente lo mismo que
rige hoy sin esta capa: `C-FIN-01` (con su `F_slots` provisional) como red de seguridad, y el resto de
`SPEC.md`/`CONTRATO-v0.md` sin cambios. Es la condición (c) de la pregunta falsable, ya demostrada en
FV-18: la pausa **no** añade ningún riesgo nuevo, solo retira la mejora de velocidad.

---

## 6 · FV-23…FV-27 · Falta y evidencia (R5): el doble voto

**FV-23 · Definición del doble voto, en la familia de `EvidenceTx`.** La única falta nueva es firmar dos
votos distintos y no-`⊥` para la **misma instancia** `n` — la traducción exacta del Mandamiento I de
Casper **[P]**: «a validator must not publish two distinct votes for the same target height» (Buterin &
Griffith, arXiv:1710.09437). **No se adopta el Mandamiento II** (surround votes): ese mandamiento existe
en Casper porque sus votos son pares `(fuente, destino)` sobre un árbol de checkpoints; el diseño de esta
capa (FV-10/FV-14, GossiPBFT tipo F3) vota **un valor por instancia**, sin pares fuente-destino, así que
no hay «votos que se envuelven» que prevenir — **[D]** sobre la estructura de la propia regla FV-10. Una
`EvidenceTx`-de-voto (`EV-VOTO`, nombre provisional para no colisionar con `EV-*` de bloques) contiene
exactamente dos votos firmados por la misma `pk` para la misma instancia `n`, con valores distintos
(`hash(voto_1) ≠ hash(voto_2)`), sellos válidos bajo `pk` y el propio número de instancia como identidad
de oportunidad — mismo patrón de `C-EVP-02`/`EV-06`/`EV-07` (`CONTRATO-EVIDENCIA-v0.md` §3), sustituyendo
`(sol.*, slot)` por `(n, pk)`. **[D]**

**FV-24 · Verificación `O(1)`, sin reconstruir nada.** Verificar `EV-VOTO` exige solo dos verificaciones
de firma (BLS individual del votante, no la agregada del certificado) y comparar `n` y `pk`: no hace
falta reconstruir ninguna cadena rival ni demostrar que ambos votos formaron parte de un certificado
real. Misma estructura que `EV-08`/`EV-09` del contrato de evidencia de bloques. **[D]**

**FV-25 · La garantía debe crecer con el peso del voto, o R5 no muerde.** Este es el punto que decide
entre las tres fuentes de peso (§1) y que el mandato §6.7 exige señalar sin rodeos:

- Con fuente **(C) garantía `C-BON`**: el peso **es** la garantía. Doble voto ⇒ confisca una fracción `f`
  de `Garantía[pk].activo` (mismo mecanismo que `EV-19`, con `f` calibrado por un SL-2 análogo). **R5
  muerde de forma directa**: quien tiene más peso tiene, por construcción, más garantía en juego.
- Con fuente **(B) sectores registrados**: si el registro de sectores llega a tener un colateral por
  sector (F4 de `P-DISUASION/SINTESIS.md`, «colateral por sector»), la confiscación es análoga a (C),
  proporcional a la capacidad registrada. **R5 muerde con esa condición**, que hoy **no está cerrada**
  (`P-REGISTRO-SECTORES` sigue en G1/G2, `ANALISIS.md` §5): se declara **condicional**, no se asume.
- Con fuente **(A) bloques cobrados**: **no hay ninguna garantía ligada al peso.** El peso es un conteo
  de bloques cobrados; una clave puede tener mucho peso votante sin tener un solo brek en `Garantía[pk]`.
  **Aquí R5 NO MUERDE**, tal como el mandato §6.7 exige declarar explícitamente cuando corresponda: un
  atacante que reúna `1/3` del peso por la vía (A) y firme dos votos contradictorios **deja evidencia
  verificable** (FV-23/FV-24: R5 «toda falta deja firma» se cumple en su primera mitad), pero **no hay
  nada que confiscarle** salvo que se le exija además un depósito por separado — que entonces sería, de
  hecho, una migración parcial hacia (C). Esto es una diferencia estructural entre las tres fuentes, no
  un defecto de redacción de esta regla: es la respuesta directa a la parte (b) de la pregunta falsable,
  y se retoma en `INFORME.md` §1 como **contraejemplo parcial** a (b) bajo la fuente (A). **[D]**

**FV-26 · Ventana de admisión y retiro.** `EV-VOTO` sigue el mismo patrón `EV-13…EV-16`/`EV-15b` del
contrato de evidencia de bloques: ventana `Plazo_voto_slots` desde el slot de la instancia; retención
`R_slots_voto > Plazo_voto_slots + M_margen_voto_slots`; y la misma segunda condición de `EV-15b` para
cerrar el hueco del retiro parcial con producción/voto continuado. **No se reabre el diseño**: se declara
que `EV-VOTO` hereda `EV-13…EV-26` sustituyendo `slot_falta` por `n` (número de instancia) y `sol.public_key`
por la clave de voto (FV-08). **[D]**

**FV-27 · Sin castigo correlacionado (DS-5) y sin castigo por ausencia.** No votar (abstención) **no**
es una falta: es exactamente lo que R3 exige que sea posible sin castigo. La fracción confiscada `f` de
FV-25 es **fija por incidente**, no creciente con el número de infractores del mismo periodo — mismo
motivo que `DS-L02`/`EV-21`: DS-5 (`P-ZRX/P-DISUASION/REVISION-DS5.md`) ya demostró que la versión
correlacionada no encarece al atacante grande y sí castiga a honestos con un fallo común de cliente
(exactamente el riesgo que el mandato §3.5 pide evitar: «un fallo común del cliente hundiría a muchos
honestos a la vez»). **[D]**

---

## 7 · FV-28…FV-30 · Activación tras el corte PoW → PoST

**FV-28 · Peso total mínimo y garantía madura mínima.** La capa **MUST NOT** activarse hasta que el peso
total de la tabla de poder alcance un mínimo `S_min_voto` **y** el número de claves distintas con peso
alcance `K_min_voto` — mismo patrón que `Φ` de `CUT-HWΦ` (`P-ZRX/P-TRANSICION/CONTRATO-v0.md` D-T04):
varias claves no demuestran operadores independientes (`C-BOT-06`), pero su ausencia total sí demuestra
que la capa no tiene con qué formar quórum. Ambos son símbolos (§9). **[D]**

**FV-29 · Qué rige antes de activarla.** Antes de la activación, rige `C-FIN-01` sola — igual que durante
una pausa (FV-22). La activación **no** es un evento de consenso retroactivo: los bloques producidos
antes de la activación no tienen ni pueden tener un certificado que los selle; un certificado posterior
solo puede sellar bloques producidos **después** de que la tabla de poder exista (FV-01). **[D]**

**FV-30 · Activación prematura (ataque 11, §Análisis adversarial).** Si `S_min_voto`/`K_min_voto` se
fijan demasiado bajos, la capa se activa con garantía repartida entre pocas claves grandes, y el `1/3`
del peso total (FV-13/FV-19) puede coincidir con una sola clave o con muy pocas. Este contrato no fija
los valores (son símbolos, §9): declara la desigualdad que deben cumplir — `S_min_voto` y `K_min_voto`
deben calibrarse contra la misma concentración medida por `P-ZRX/P-DISUASION/REVISION-DS6.md` (un pool
real de Chia, 576 PiB, altamente concentrado) como cota de referencia, no contra un ideal de reparto
uniforme que no existe en ninguna red real citada en este repositorio. **[H]**

---

## 8 · Cliente ligero (una línea, sin desarrollar)

Si `FV-03` se cumple, la cadena de certificados **puede** servir a un cliente ligero sin confiar en
ningún nodo (verificación desde génesis solo con certificados, FV-15), **con la condición** de que exista
además un certificado de cadencia más lenta (análogo a `R-FIN-22` de la propuesta antigua, «certificado de
época») para que el coste no crezca con el número de instancias transcurridas; no se desarrolla más aquí
(mandato §4, «si la cadena de certificados sirve al cliente ligero, dilo en una línea… no lo desarrolles»).

---

## 9 · Parámetros abiertos

| Símbolo | Qué fija | Restricción estructural ya escrita aquí |
|---|---|---|
| `LOOKBACK` | Instancias de retardo entre `past` y la tabla de poder que usa (FV-02) | `≥ 1`; F3 usa 10 |
| `q_voto` | Peso mínimo para entrar en la tabla de poder (FV-04) | `> 0` |
| `Δ_F` | Temporizador base de GossiPBFT (FV-12) | `> 0`; calibrar con la `Δ` de red de ZEROX, no copiar el de Filecoin |
| `S_pausa` | Instancias sin quórum antes de declarar pausa (FV-20) | `≥ 1` |
| `S_min_voto`, `K_min_voto` | Umbral de activación (FV-28) | Calibrar contra concentración medida (DS-6), no contra reparto uniforme |
| `f`, `Plazo_voto_slots`, `M_margen_voto_slots`, `R_slots_voto` | Calibración del castigo del doble voto (FV-25/FV-26) | Mismas desigualdades estructurales que `EV-15`/`EV-15b`, con `n` en vez de `slot_falta` |
| Esquema BLS | `blst` frente a `bls12_381` (FV-16) | Decisión de Katana; recomendación: `blst` confinado + contraste diferencial |
| Fuente del peso | (A)/(B)/(C) (§1) | Decisión de Katana; comparación completa en `INFORME.md` §3 |

Ninguno de estos símbolos se fija con un número en este documento (mandato: «no inventar un número»,
`LIBRO-DE-RESTRICCIONES.md`, línea roja de proyecto).

---

## 10 · Fuentes

Internas (todas ya citadas por ruta en el cuerpo): `P-ZRX/P-FINALIDAD-VOTOS/{PROGRAMA,CONTEXTO}.md`;
`D-ZRX/SPEC.md` §0, §5 (`C-BON`, `C-EVP`, `C-SLA`); `P-ZRX/P-TRANSICION/CONTRATO-v0.md`;
`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`; `P-ZRX/P-SLASHING/resultados-SL1/CONTRATO-EVIDENCIA-v0.md`;
`P-ZRX/P-DISUASION/{SINTESIS,REVISION-DS2,REVISION-DS5,REVISION-DS6}.md`;
`P-ZRX/P-REGISTRO-SECTORES/{ANALISIS,ENCARGO}.md`; `R-ZRX/LEGADO/stake/MAPA.md`;
`R-ZRX/LEGADO/eclipse/INFORME.md`; `research/dag-poas-capa-finalidad.md`,
`research/scripts/d14-sin-comite/informe.md`, `P-ZRX/T-ZRX/{LIBRO-DE-RESTRICCIONES,ESTADO-DOBLE-FARMEO,AGUJEROS-Y-SOLUCIONES}.md`,
`P-ZRX/P-SECRETO/investigacion/INFORME.md`, `P-ZRX/P-POOLS/investigacion/INFORME.md`,
`P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md`, `P-ZRX/P-CLAVE/investigacion/INFORME.md` (todos leídos en
`/home/katana/zeo/.trash/zerox/`, `= 9681061` salvo lo ya marcado).

Externas, leídas íntegras o en su HTML/resumen primario en esta orden:
- FIP-0086 (F3), `github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0086.md` — GossiPBFT, `PowerTableLookback`,
  `IsStrongQuorum`, compromiso de tabla siguiente, «EC continues operating "normally"», verificación desde génesis.
- Buterin & Griffith, *Casper the Friendly Finality Gadget*, arXiv:1710.09437 (`arxiv.org/html/1710.09437v4`)
  — los dos Mandamientos, seguridad responsable `≥1/3`, slashing del depósito entero, subjetividad débil.
- Neu, Tas, Tse, *Ebb-and-Flow Protocols*, arXiv:2009.04987 — ledger disponible + prefijo finalizado,
  tensión CAP disponibilidad/finalidad, comportamiento bajo partición.
- eth2book, «Inactivity leak», `eth2book.info/latest/part2/incentives/inactivity/` — mecanismo, fórmula
  cuadrática, restauración de `2/3`.
- Pavloff, Amoussou-Genou, Tucci-Piergiovanni, *Byzantine Attacks Exploiting Penalties in Ethereum PoS*,
  arXiv:2404.16363 — finalización de dos ramas contradictorias acelerada por la fuga de inactividad.
