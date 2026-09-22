# Informe de verificación de fuente — SpaceMint §4 (penalizaciones)

**Autoría:** Park, Kwon, Fuchsbauer, Gaži, Alwen, Pietrzak — *SpaceMint: A Cryptocurrency Based on Proofs of Space*.
**Documento verificado:** `https://eprint.iacr.org/2015/528.pdf` (PDF servido como versión vigente).
**Estado del PDF descargado:**
- 29 páginas; `CreationDate`/`ModDate = D:20180301014244-05'00'` → **1 de marzo de 2018**.
- `sha256 = cb2411469608c0d734fa0f1aa5347b57efe49e56d855b8a80761ea4eac2d769a`
- Según `https://eprint.iacr.org/archive/versions/2015/528`, la última versión listada es `20180301:065854` (la que corresponde a este PDF). Versiones anteriores: `20180301:065701`, `20160512:044404`, `20160324:164007`, `20151117:061050`, `20150623:221402`, `20150616:194350`, `20150605:000009`.

**Método:** descarga con `curl`, extracción de texto con `pypdf 6.17.0` página a página. La **página impresa coincide exactamente con el índice de página del PDF** (verificado leyendo los pies de página 1–28).

**Nota de transcripción:** las citas son literales. Únicamente he (i) normalizado las ligaduras tipográficas del PDF (`ﬃ`→`ffi`, `ﬁ`→`fi`, `ﬀ`→`ff`) y (ii) reunido palabras partidas por guion de fin de línea. Se conservan erratas del original (p. ej. «trying to extending»). Las comillas internas del original son tipográficas (“ ”).

---

## 0. Mapa de secciones relevantes

| Sección | Título | Página impresa (= PDF) |
|---|---|---|
| 3.1 | Mining | 6–7 |
| 3.3 | Transactions in SpaceMint (subapartado **Penalties**) | 7–8 (penalties en 8) |
| **4** | **Nothing-at-Stake Problems and Solutions** | **9–11** |
| Apéndice C | Challenge-grinding attacks (varianza) | 23–25 |
| Apéndice D | Parameter setting and interplay | 25–26 |
| 7.1 / 7.2 | Game Theory (límites del modelo) | 14 / 16 |

---

## 1. Sección 3.3 — «Penalties» (p. 8)

Cita literal (p. 8, §3.3):

> "**Penalties.** A penalty transaction
> `ctx = (penalty, txId,pk, prf )`
> consists of pk, the public key of the transaction creator, and prf, a proof of penalty-worthy behavior by another miner. These transactions serve to penalize miners that engage in malicious behavior. The primary usage of penalties in SpaceMint is to disincentivize mining on multiple chains (e.g., the proof would contain two blocks of the same index signed by the same miner), but penalty transactions can be used to discourage other types of (detectable) behavior in blockchain-based currencies."

(En el original «prf» y «ctx» van en cursiva/monoespaciado; aquí se transcriben en texto plano.)

---

## 2. Sección 4 — «Nothing-at-Stake Problems and Solutions» (pp. 9–11)

La sección se titula exactamente **"4 Nothing-at-Stake Problems and Solutions"** y comienza en la **p. 9**:

> "In this section we discuss the “nothing-at-stake” issues, which were already mentioned in the introduction. We describe them here in more detail, and outline how SpaceMint defends against them." (p. 9)

### 2.a) Definición exacta de la penalización (§4, apartado «II. Mining on multiple chains», *The solution*, p. 10)

> "Then, we impose a penalty, via the penalty transactions of §3.3, for any pair of identical proofs published in two candidate blocks: half of the block reward for such a “misbehaving” block is allocated to the creator of the penalty transaction, and the other half simply disappears." (p. 10)

> "Concretely, suppose a miner pk′ attempts to mine concurrently on two chains whose most recent blocks are βj and β′j, by announcing βj+1 and β′j+1 (which have the same quality and were mined using the same space). Then anyone who observes this can generate a transaction `( penalty,txId,pk, {pk′,βj+1,β′j+1})` to penalize pk′. This transaction can be added to a chain extending βj+1 (or β′j+1), and its meaning is that half of the reward (block reward and transaction fees) that should go to the miner who announced βj+1, is now going to pk (the “accuser”) instead, and the other half of the reward is destroyed, i.e., cannot be redeemed by any party. We destroy half of the reward so the penalty hurts even if the cheating miner can be reasonably sure to be able to accuse itself. For this to work, mining rewards can only be transferred by a miner some time after the block was added, so that there is enough time for other miners to claim the penalty." (p. 10)

Nota al pie 6 ligada a «simply disappears» (p. 10):

> "6 This is to disincentivize penalizing oneself." (p. 10, nota 6)

**Precisión importante para tu evaluación:** el objeto de la penalización en §4 es «any pair of **identical proofs** published in two candidate blocks»; §3.3 lo describe como «two blocks of the same index signed by the same miner». Como en §4 «for any given challenge, there is a single proof (i.e., the proof is deterministic given the challenge)» (p. 10), ambas descripciones coinciden para bifurcaciones de menos de ∆ bloques. La confiscación es **del 100 % de la recompensa del bloque infractor** (mitad al acusador, mitad destruida), y se aplica a **recompensas aún no transferibles**, no a un depósito.

### 2.b) Ausencia de depósito/pledge previo (§4, nota al pie 7, p. 10)

> "7 The idea of penalizing miners for extending multiple chains goes back at least to slasher https://blog.ethereum.org/2014/01/15/slasher-a-punitive-proof-of-stake-algorithm . **Unlike previous penalty-based proposals, we do not need the miners to make a deposit up-front; instead, they will simply lose their mining reward if they cheat.**" (p. 10, nota 7)

Esta es la única declaración explícita sobre ausencia de depósito. **Sí se menciona explícitamente** que no se exige depósito previo.

### 2.c) Límites declarados del mecanismo

**Límite 1 — bifurcaciones de más de ∆ bloques (retos distintos).** §4, apartado «II», *Case 2: chains forked more than ∆ ago* (p. 10):

> "In this case the miner receives different challenges for different chains, leading to proofs of different quality for the two chains. **In this case, even with our penalty scheme in place, a rational miner can still get an advantage by deviating:** instead of only trying to extending the highest-quality chain, it also generates proofs for the lesser chain. As the challenges differ, so will the two proofs, and if the proof on the lesser chain has very high quality, the rational miner would publish it, hoping that this chain will become the best chain and survive." (p. 10)

La defensa que ofrece el artículo es probabilística, no una garantía del mecanismo de penalización:

> "We address this problem by arguing that it is extremely unlikely (the probability is exponentially small in ∆) that this case occurs, as a weaker branch of the chain would have to “survive” for ∆ blocks despite a strong incentive (via our punishment scheme) for miners to only extend the chain of highest quality." (p. 10)

**Límite 2 — doble gasto que nunca publica dos pruebas para el mismo slot.** §4, apartado «III. Grinding challenges» (p. 11):

> "**Note that in this attack the adversary explores multiple chains in parallel, which we have addressed already using a penalizing scheme. But penalizing does not protect against double-spending attacks in which the adversary never actually published two proofs for the same slot.** And even he would, a double-spending attack can be profitable even if one loses some mining rewards due to the penalizing scheme." (p. 11)

**Límite 3 — supuesto (no teorema) de suficiencia de la penalización.** Apéndice D, apartado «Extending multiple chains» (p. 26):

> "We must ensure that for a miner it is rational to only announce blocks extending one chain, and this chain should be the chain of highest quality known to the miner. Ensuring that a miner only announces one block is done by penalizing miners otherwise (§4). **If there is a fork, we assume that with high probability this penalizing is sufficient to ensure that one branch will “die” within at most ∆ blocks. Otherwise, miners will get different challenges for the two chains, which (assuming the miners are rational) will slow down consensus.** Clearly, increasing ∆ makes this event less likely (at an exponential rate)." (p. 26)

**Límite 4 — el modelo de teoría de juegos no cubre todo.** §7.1 (p. 14):

> "Let us stress that our analysis herein is intended as a basic framework to model blockchain-based cryptocurrencies using the standard game-theoretic notion of an extended game, and does not claim to comprise an exhaustive modeling of all possible attack vectors. In particular, our stylized model does not capture some important aspects, most notably block withholding, which is used in “selfish mining.”" (p. 14)

Además, los teoremas del juego exigen <50 % de espacio (§7.2, *Remark*, p. 16):

> "Our exposition keeps the types implicit; our theorems require that no player has more than 50% of the space committed by active miners." (p. 16)

### 2.d) ¿Se dice que la penalización no disuade si el beneficio del doble gasto supera la recompensa?

**Sí, explícitamente** (§4, apartado «III. Grinding challenges», p. 11):

> "And even he would, a double-spending attack can be profitable even if one loses some mining rewards due to the penalizing scheme." (p. 11)

---

## 3. Sección 3.1 — «Mining» (pp. 6–7)

Define las recompensas de bloque; **no** menciona penalización ni depósito. Cita literal (p. 6):

> "**Mining.** Similar to Bitcoin, SpaceMint incentivizes mining (adding new blocks) through block rewards (freshly minted coins per block) and transaction fees." (p. 6)

En «Remark (Postponing Algorithm 2)» (pp. 6–7) se explica que el minero sólo ejecuta el algoritmo 2 al querer añadir un bloque, por eficiencia y porque así «the challenge for Algorithm 2 changes with every block» (p. 7). No hay en §3.1 ninguna mención a retención, confiscación ni recompensas diferidas; el único aplazamiento relevante está en §4 (p. 10), citado arriba: «mining rewards can only be transferred by a miner some time after the block was added».

---

## 4. Petición (e): varianza / recompensas pequeñas / mineros pequeños en relación con la penalización

**No verificado / no existe en el artículo.** La Sección 4 **no** contiene ninguna afirmación que relacione la penalización con la varianza de las recompensas, con recompensas pequeñas, ni con mineros pequeños. Tampoco aparece esa relación en §3.1, §3.3, §7 ni en los apéndices.

Los lugares donde el artículo **sí** trata esos temas, pero **sin conectarlos a la penalización**, son:

- **Varianza de la calidad de las pruebas** — Apéndice C (p. 25), en el contexto del *challenge grinding*, no de la penalización:
  > "Before we explain how to counter this attack, let us observe that what makes challenge grinding possible in the first place is the variance in the quality of a proof: for a space commitment (pk,γ), the expected quality of a proof is Nγ, but for any α > 1, the quality will be higher than α·Nγ with probability roughly 1/α. This variance is necessary as we need the expected quality of the best proof found amongst many commitments (pk1,γ1),...,(pkm,γm) to be the sum ∑mi=1 Nγi of all the spaces." (p. 25)
  > "We can decrease the advantage of challenge grinding over honestly mining by lowering the variance of the quality of proofs." (p. 25)

- **Mineros pequeños** — Resumen (p. 1):
  > "SpaceMint also rewards smaller miners fairly according to their contribution to the network, thus incentivizing more distributed participation." (p. 1)

- **Espacio pequeño / `minspace`** — Apéndice D (p. 26):
  > "Also setting minspace high will make the scheme more secure, but a high minspace will lower its usability, as parties with small space will not be able to participate." (p. 26)

- Lo más cercano dentro de §4 a un problema de autoacusación (no de varianza) es la nota 6 y la frase ya citada «We destroy half of the reward so the penalty hurts even if the cheating miner can be reasonably sure to be able to accuse itself.» (p. 10).

---

## 5. Respuestas directas a los apartados a)–e)

- **a) Definición de la penalización:** sí verificada. Objeto = «any pair of identical proofs published in two candidate blocks»; efecto = mitad de la recompensa (recompensa de bloque + comisiones) del bloque infractor al acusador, mitad destruida; se aplica a recompensas aún no transferibles. §4, p. 10.
- **b) Sin depósito/pledge previo:** sí verificado, explícito en la nota 7, p. 10: «we do not need the miners to make a deposit up-front; instead, they will simply lose their mining reward if they cheat».
- **c) Todos los límites declarados:** verificados en §4 (pp. 10–11: *Case 2* y apartado III), en el Apéndice D (p. 26: supuesto de que la penalización «is sufficient», no teorema) y en §7.1 (p. 14: modelo no exhaustivo, no cubre *block withholding*). Ver arriba las citas.
- **d) Beneficio del doble gasto > recompensa:** sí verificado y explícito, §4, p. 11: «a double-spending attack can be profitable even if one loses some mining rewards due to the penalizing scheme».
- **e) Varianza / recompensas pequeñas / mineros pequeños en relación con la penalización:** **no verificado / no existe tal afirmación en el artículo** (detalle en la sección 4 de este informe).

---

## 6. Lo que NO pude verificar

1. **Varianza, recompensas pequeñas o mineros pequeños ligados al mecanismo de penalización** (petición e). No hay ninguna frase en el documento que haga esa conexión. No la infiero.
2. **Cualquier límite del mecanismo de penalización distinto de los cuatro recogidos** (bifurcaciones >∆, doble gasto sin doble publicación, supuesto de suficiencia del Apéndice D, y no-exhaustividad del modelo de §7.1). No he encontrado otros; si existen, no están en §3.1, §3.3, §4, §7 ni en los apéndices según la búsqueda exhaustiva de «penal/punish/forfeit/deposit/pledge/double-spend/reward/assum/limitation».
3. **Texto de la «full version [31]»** a la que remite §4 para el análisis detallado del *challenge grinding* («A more detailed discussion of this attack and our defense is given in the full version [31].», p. 11). No la he consultado; las citas de este informe provienen solo del PDF de eprint 2015/528 (revisión 2018-03-01).
4. **Confirmación de que no existe una redacción distinta** de estos pasajes en las versiones previas de 2015/2016. Solo he verificado la versión vigente (20180301:065854). Las citas corresponden exclusivamente a esa revisión.

---

### Ficheros de respaldo
- `P-VERIF-SPACEMINT/spacemint.pdf` — PDF descargado (29 pp., 2018-03-01).
- `P-VERIF-SPACEMINT/spacemint.txt` — texto extraído con páginas marcadas (`===== PDF_PAGE n =====`).
