# P-STAKE · Mapa previo — qué mecanismos de PoS resuelven qué agujeros de ZEROX

**Fecha:** 2026-09-24 · **Autor:** Claude, a petición de Katana · **Estado: MAPA DE INVESTIGACIÓN, NO
EVALUACIÓN.** Nada de este documento está medido con instrumento. Cruza mecanismos verificados en
fuente primaria con agujeros y resultados ya demostrados en el repositorio, y dice **qué habría que
evaluar primero y por qué**. **No recomienda adoptar nada.**

**Origen:** Katana, 2026-09-24: *«Necesito saber qué problemas resuelve PoS en zerox. Necesito extraer
mecanismos de PoS tales como el stake o slashing que se puedan implementar en zerox. El objetivo es
adaptar esos mecanismos a zerox de tal forma que podamos solventar problemas o vulnerabilidades
actuales.»* Katana se retracta del descarte previo del PoS «para determinadas tareas».

### El objetivo, en palabras de Katana (2026-09-24)

> *«En una red P2P donde no se puede confiar en nadie, un sujeto (t), sea honesto o un atacante,
> tiene que dejar algo de valor en juego, y eso son tokens. En caso de que se descubra que el sujeto
> (t) hizo algo malo, esos tokens desaparecen. Esto actúa como un mecanismo de disuasión: eso es lo
> que estoy buscando añadir en ZEROX PoST.»*

**Lo que ese objetivo implica, y ordena todo el mapa:**

```text
disuasión = P(ser descubierto) × valor en juego
```

Son **dos** preguntas y la primera manda: **(1) qué conductas se pueden descubrir en ZEROX**, y
**(2) qué tiene en juego cada participante**. Con `P = 0`, ningún valor en juego disuade
(`P-CLAVE` F6). **Por qué tokens y no el disco:** el disco se regenera —R-3; replotear 1 TiB con GPU
≈ 1,4 h, `documentado, no medido`—; **los tokens no se regeneran**, y eso es justo lo que el stake
aporta que PoST no tiene. `[lectura de Claude]`

**Etiquetas:** `verificado en fuente` (leído en la fuente primaria, con URL al final) ·
`demostrado en el repo` (con ruta) · `no evaluado` · `lectura de Claude` (razonamiento propio, sin
instrumento).

---

## 0 · El criterio que ordena todo el mapa

El repositorio ya lo había escrito al descartar el stake el 2026-09-23
(`P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` §3):

> **Lo que lo hace funcionar en PoS no es el colateral:** es que **el conjunto de validadores es
> conocido y la participación obligatoria**, así que la rama privada deja rastro.

De ahí salen **cuatro condiciones** para que un castigo con stake funcione. `[lectura de Claude,
derivada de las fuentes de §1]`

| # | Condición | Qué significa | Si falta… |
|---|---|---|---|
| **E** | **Evidencia** | La mala conducta deja un objeto verificable (dos firmas contradictorias) | el castigo se aplica con probabilidad cero, y por grande que sea disuade cero (`P-CLAVE` F6) |
| **A** | **Atribución** | Ese objeto identifica qué stake castigar (va firmado por una clave con stake) | se castiga a quien no es |
| **R** | **Retención** | El stake sigue bloqueado cuando llega la evidencia (periodo de retirada ≥ ventana de detección) | el infractor retira antes de que le alcancen |
| **C** | **Correlación** | El castigo crece con cuántos fallan a la vez | el accidente honesto se castiga igual que el ataque, y el falso positivo se vuelve catastrófico |

**La consecuencia que manda:** el stake **no crea evidencia**. Solo castiga la que ya existe. Donde
ZEROX no tiene evidencia —la rama privada, `κ = 0`— ningún stake la fabrica. **Lo que sí la fabrica
en PoS son los votos públicos**, y eso es un mecanismo distinto del stake (§1.3).

---

## 1 · Los mecanismos de PoS, verificados en fuente primaria

### 1.1 · Filecoin — PoST con colateral, en producción `[verificado en fuente]`

El pariente más cercano de ZEROX: mismo recurso físico, y usa colateral.

| Mecanismo | Qué es | Qué resuelve allí |
|---|---|---|
| **Colateral inicial (pledge)** | **Dos partes:** *storage pledge* ≈ 20 días de recompensa esperada del sector, y *consensus pledge* = `30 % × oferta circulante × (poder del sector / máx(línea base, poder de red))` | Hace caro comprometer espacio y retirarlo |
| **Recompensas en vesting** | *«a fixed duration linear vesting for the rewards that a miner earns after a short delay»*; *«fault fees are slashed first from the soonest-to-vest unvested block rewards»* | Las recompensas **ganadas** sirven de colateral sin comprar nada |
| **Faltas de consenso** | *Double-fork mining* (dos bloques en la misma época), *time-offset mining*, *parent grinding* | Castiga bifurcar la cadena |
| **Denuncia por terceros** | *«consensus faults have to be reported by other miners»*; el denunciante *«receives a portion of the slashed miner's pledge collateral»* | Da incentivo a publicar la evidencia |
| **F3** (finalidad) | Comité ponderado por poder registrado. Bajó la finalidad de **7,5 h a decenas de segundos** (`research/dag-poas-capa-finalidad.md`) | Finalidad rápida |

**Dos lecturas que importan para ZEROX:**
- **El consensus pledge es proporcional a la oferta circulante.** Con oferta cero el requisito es
  cero: es un **arranque gradual** que no necesita premine ni PoW. `[lectura de Claude]`
- **El colateral de Filecoin funciona porque resellar es caro** — `P-ZRX/P-SELLO/` verificó
  `post.md:17`: *«it is more expensive to seal a copy of the data every time they are asked»*. **El
  formato de ZEROX plotea barato** (R-3 de `LIBRO-DE-RESTRICCIONES.md`), así que esa pata **no se
  traslada tal cual**.

### 1.2 · Ethereum — slashing, correlación e inactividad `[verificado en fuente]`

| Mecanismo | Qué es | Qué resuelve allí |
|---|---|---|
| **Slashing** | Tres faltas: *«proposing and signing two different blocks for the same slot»*, doble voto, voto envolvente | Castiga equivocarse |
| **Penalización por correlación** | *«when more validators are slashed, the magnitude of the slash increases»*, hasta el saldo entero | **Separa el accidente aislado del ataque coordinado** |
| **Salida forzada de 36 días** | El stake queda retenido mientras se aplica el castigo | Cumple la condición **R** |
| **Fuga por inactividad** | Tras *«more than four epochs without finalizing»*, el stake de los inactivos se drena *«until they control less than 1/3»* | Recupera la finalidad cuando más de ⅓ está caído o aislado |
| **Sin castigo por ausencia** | *«There is no penalty for failing to propose a block»* | No castiga al que se desconecta |

### 1.3 · Casper FFG — finalidad por stake **superpuesta a una cadena de otra familia** `[verificado en fuente]`

El dato estructural: Casper se diseñó como *«a proof of stake-based finality system which **overlays
an existing proof of work blockchain**»*. **Es exactamente el patrón «stake encima de una cadena que
no es PoS»**, que es lo que Katana plantea para PoST.

| Mecanismo | Enunciado literal |
|---|---|
| **Seguridad responsable** | *«Two conflicting checkpoints cannot both be finalized unless **≥1/3 of the validators** violate one of the two Casper Commandments.»* |
| **Mandamiento I** | *«A validator must not publish two distinct votes for the same target height.»* |
| **Mandamiento II** | *«A validator must not vote within the span of its other votes»* |
| **Castigo** | Violar cualquiera de los dos cuesta **el depósito entero** |
| **Subjetividad débil** | *«each client will "log on" and gain a complete up-to-date view of the chain at some regular frequency (e.g., once per 1–2 months)»* |

**Ésta es la pieza que el stake solo no da.** Los votos de finalidad son **públicos**, así que para
finalizar una rama que contradiga a otra hace falta **votar dos veces**, y eso **es evidencia**.
**Casper no atrapa la rama privada; la vuelve irrelevante para la historia ya finalizada.**
`[lectura de Claude, sobre el enunciado verificado]`

### 1.4 · Decred — el híbrido PoW/PoS `[verificado en fuente]`

Reparto de recompensa: **60/30/10** al lanzar → **10/80/10** (DCP-0010) → **1/89/10** (DCP-0012,
2023). Motivo literal: *«the expected results of a fair coin distribution has not been achieved»* y
*«the majority of the PoW hash power is highly centralized and being used to maliciously manipulate
Decred markets»*. Consta como descartado desde el 2026-09-09 (`P-ZRX/P-RNG/PROMPT.md` §2.3); ahora
con cifras verificadas.

---

## 2 · La matriz: mecanismo × agujero de ZEROX

Agujeros tomados de `P-ZRX/T-ZRX/INVENTARIO-ABIERTO.md` §A, `ESTADO-DOBLE-FARMEO.md` y los
encargos del 2026-09-24. Columna E/A/R/C: qué condiciones de §0 cumple el caso.

### 2.1 · Donde un mecanismo PoS **podría** cambiar el veredicto — todos `no evaluados`

| Agujero | Mecanismo PoS | E/A/R/C | Por qué podría servir | Qué ya se sabe en el repo |
|---|---|---|---|---|
| **Finalidad lenta** (`F = 2 h` provisional) | Finalidad tipo Casper con votos ponderados por stake | E ✓ A ✓ | Es el único punto donde el propio repo reconoce que *«un consenso con moneda gana al nuestro»* (`research/dag-poas-capa-finalidad.md` l. 5). F3 lo hizo en Filecoin: de 7,5 h a decenas de segundos | La capa se propuso ponderada por espacio y **se bloqueó** porque *«PoAS no registra a nadie»*. El stake con registro crea esa tabla |
| **Doble farmeo en rama privada** (C3, `κ = 0`) | La misma finalidad | E ✓ solo para lo finalizado | No castiga la rama privada: **la deja sin efecto** sobre la historia finalizada. Y `F` corta es *«la única palanca del consenso que funciona»* contra el doble farmeo (H-6) | `P-CLAVE` F6: **ningún castigo** alcanza `κ = 0`. La finalidad no lo contradice: lo rodea |
| **Doble farmeo publicado** (pools, alquiler, vender acceso a dos) | Slashing por falta de consenso + denuncia por terceros + correlación | E ✓ A ✓, **R y C por diseñar** | Aquí sí quedan las dos firmas. Precedente directo: *double-fork mining* de Filecoin | Fila 7b de `PROPUESTAS-VIABLES.md`: *«dónde sí vale»*. **Pero** `P-EQUIVOCACION`: `κ = 1` con `m ≤ 0,05`, **`κ = 0` con `m = 4`** — el atacante grande no deja evidencia ni publicando |
| **Falsos positivos del castigo** (lo que mató la 7b) | **Penalización por correlación** | C ✓ | El nodo honesto redundante que firma dos veces es un fallo **aislado**: castigo mínimo. El ataque es **correlado**: castigo total | 7b murió porque *«el falso positivo pasa a ser catastrófico»*. **Ningún encargo examinó la correlación** |
| **Claves de saldo cero y rotación gratis** | Colateral en vesting (Filecoin) + requisito que crece con la oferta | R ✓ | El vesting convierte lo ganado en colateral sin comprar; el requisito proporcional a la oferta arranca en cero | `P-CLAVE` F4: *«NO… ninguna de las dos cosas —registro de parcelas, **moneda previa**— está disponible»*. Es el «NO» que la retractación de Katana reabre |
| **Alquiler corto** (C1) | Colateral + periodo de retirada | R ✓ | Alquilar espacio una hora obligaría a bloquear capital durante todo el periodo de retirada | **Nunca estudiado.** El periodo de retirada **no aparece en ningún documento** del repositorio |
| **Arranque sucinto tras poda** (D4) | Puntos de control finalizados + subjetividad débil | — | Así sincroniza un nodo nuevo en PoS | `PRV-v0.1` §3.4: un checkpoint **único y caducable** (`C-CHK-01/03`) no puede anclar a todo nodo nuevo. **Checkpoints recurrentes cambian el modelo de confianza** |
| **Partición de flujo** (D3) | Fuga por inactividad | — | Recupera la finalidad cuando más de ⅓ queda aislado | **Riesgo conocido:** en una partición larga, **las dos mitades** pueden fugar el stake de la otra y finalizar cadenas contradictorias sin que nadie haya violado un mandamiento `[lectura de Claude]` |
| **Eclipse** (D2) | Pares ponderados por stake (resistencia Sybil en la red) | — | Fabricar identidades de red dejaría de ser gratis | `P-ECLIPSE`: **no existe gestor de direcciones**. Es capa de red, no consenso |

### 2.2 · Donde PoS **no** cambia nada — demostrado o por física

| Agujero | Por qué no | Fuente |
|---|---|---|
| **Rama privada fuera de lo finalizado** | Sin evidencia no hay castigo. El stake no crea evidencia | `P-CLAVE` F6; R-6 |
| **Ventana de adelanto** (B1, `ρ > 1`) | Es física: velocidad de AES. El stake no cambia la latencia de una instrucción | `P-ZRX/T-ZRX/ESTADO-RELOJ.md` |
| **Sembrador** (B2) | Exige probar preexistencia, y eso es **imposible incondicionalmente** | R-2 (`P-COBERTURA` Cor. 4) |
| **Cobrar y borrar** (C2) | Borrar no es una falta en PoST: simplemente dejas de ganar. Y detectarlo choca con que lo regenerado es indistinguible de lo guardado | R-3 |
| **Sesgo eligiendo la clave** (H-5) | Se muelen claves **antes** de hacer stake; solo la elegida paga | `lectura de Claude` |
| **Doble farmeo publicado por un atacante grande** | Con `m ≥ 4` usa soluciones distintas en cada rama y no deja evidencia | `P-EQUIVOCACION` §1.2 |

---

## 3 · Las dos reglas del proyecto con las que choca

`AGENTS.md` línea 6: **«No hay staking ni comités de decisión.»**

Katana se ha retractado **de la primera mitad**. **La segunda sigue vigente**, y el mecanismo más
potente del mapa —la finalidad tipo Casper— **necesita las dos**:

> Katana, 2026-09-10, citado en `research/scripts/d14-sin-comite/informe.md`: *«Descarta todas
> aquellas opciones que impliquen un **comité central que tome decisiones**; busco
> descentralización y seguridad.»* Y esa ronda define comité como *«conjunto de participantes, fijo
> o muestreado, cuyos votos/firmas **deciden** el resultado de consenso»*, excluyendo expresamente
> los *«conjuntos de validadores con stake»*.

**Lo que decide si la finalidad por stake es admisible** es una distinción que solo puede hacer
Katana: **¿un conjunto de validadores abierto —cualquiera entra bloqueando stake, sin sorteo ni
cupo— es un «comité central»?** Por la definición de la ronda 14C, sí. Por el espíritu de la frase
(«central»), puede que no. **Sin esa decisión, la mitad superior de §2.1 no se puede ni evaluar.**

Y el valor del 2026-09-21 (`P-ZRX/P-RNG/PROMPT.md` §2.1): *«nadie posee monedas que no haya minado.
Cualquier mecanismo que obligue a **comprar** moneda para empezar a **producir** queda excluido»*.
**Ningún mecanismo de §2.1 exige comprar para producir** si el stake se limita a las tareas y se
financia con lo farmeado. **La puerta dura sí lo exigiría** (ver la conversación del 2026-09-24).

---

## 4 · El arranque, resuelto sin PoW

El problema planteado: sin premine (`C-EMIT-02`) y con génesis de valor cero (`C-GEN-03`), en el
arranque no existe moneda que bloquear.

**Dos mecanismos verificados lo resuelven sin PoW:** `[lectura de Claude sobre fuentes verificadas]`

1. **Requisito proporcional a la oferta circulante** — el *consensus pledge* de Filecoin. Con oferta
   cero, requisito cero.
2. **Recompensas en vesting como colateral** — lo ganado queda bloqueado un tiempo y sirve de
   garantía. Nadie compra.

**El precio, dicho entero:** en el arranque **el stake no aporta seguridad**, porque no puede —no
hay moneda—. La seguridad inicial es PoST pura, se diseñe como se diseñe. **Las tareas con stake se
activan cuando hay moneda suficiente**, igual que F3 entró en Filecoin años después del lanzamiento.
PoW no lo mejora: Decred muestra que concentra.

---

## 5 · Qué evaluar primero, y por qué — no qué adoptar

**Orden propuesto de evaluación**, por cuántos agujeros toca cada pieza y cuánto respaldo tiene:

1. **Finalidad tipo Casper, con votos ponderados por stake.** Toca finalidad lenta, la rama privada
   sobre lo finalizado, y el arranque sucinto. Precedente directo: Casper sobre PoW, F3 sobre PoST.
   **Bloqueada por la regla de comités**: sin la decisión de §3 no se evalúa.
2. **Penalización por correlación.** Es la pieza más barata y resuelve el problema que **mató la
   7b** (el falso positivo catastrófico). **Nadie la ha examinado** en el repositorio.
3. **Slashing del doble farmeo publicado, con denuncia por terceros.** Evidencia existe para el
   atacante pequeño; hay que medir hasta qué `m` compensa.
4. **Colateral en vesting + requisito proporcional a la oferta.** Reabre el «NO» de `P-CLAVE` F4 y
   resuelve el arranque. Hay que medir si la rotación de claves sigue siendo gratis.
5. **Periodo de retirada.** **Cero documentos lo mencionan**, y es la condición R de todo lo
   anterior.

**Lo que conviene NO evaluar**, porque ya está cerrado: stake contra el sembrador (R-2), contra
cobrar y borrar (R-3), contra `ρ` (física), y PoW de arranque (Decred).

---

## 6 · Lo que este mapa NO hace

- **No mide nada.** Toda fila de §2.1 está `no evaluada`.
- **No cuantifica ningún umbral.** La seguridad responsable de Casper es sobre fracción de
  **stake**, y el repositorio no sabe todavía convertir **espacio** en peso (`α_blue_work ≤ α_bytes`
  es falso, `PROPUESTAS-VIABLES.md` fila 5). Un híbrido tendrá **dos** umbrales y ninguno está medido.
- **No resuelve la interacción con la partición de flujo.** `P-ECLIPSE` halló que `F` tiene signo
  opuesto en el doble farmeo y en el eclipse; una finalidad rápida hereda esa tensión y no está
  estudiada.
- **No decide sobre `AGENTS.md`.** Las dos restricciones de §3 son de Katana.

---

## Fuentes primarias consultadas el 2026-09-24

- [Filecoin Spec — Miner Collaterals](https://spec.filecoin.io/systems/filecoin_mining/miner_collaterals/)
- [Filecoin Spec — Expected Consensus](https://spec.filecoin.io/algorithms/expected_consensus/)
- [Filecoin Features: Slashing](https://filecoin.io/blog/posts/filecoin-features-slashing/)
- [ethereum.org — PoS Rewards and Penalties](https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/rewards-and-penalties/)
- [Buterin & Griffith, *Casper the Friendly Finality Gadget*, arXiv:1710.09437](https://arxiv.org/abs/1710.09437)
- [Decred DCP-0010](https://github.com/decred/dcps/blob/master/dcp-0010/dcp-0010.mediawiki) · [DCP-0012](https://github.com/decred/dcps/blob/master/dcp-0012/dcp-0012.mediawiki)
