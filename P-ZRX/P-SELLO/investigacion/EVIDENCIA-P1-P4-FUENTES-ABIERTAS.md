# Evidencia de fuentes abiertas — sellado asimétrico ligado a rama

Tarea: investigación técnica de fuentes abiertas (solo extracción de citas literales con URL y
localización). No contiene interpretación para el proyecto ni recomendaciones.

Método: cada afirmación marcada **HECHO VERIFICADO EN FUENTE** proviene de un documento que fue
descargado y leído (texto íntegro o sección citada). Las citas se reproducen en su idioma original.
Copias locales de todo el material en `evidencia-fuentes/` (incluye `pdfs/` con el texto extraído de
los PDF). Las citas decisivas fueron **reabiertas y comprobadas una a una por el agente principal**
del encargo P-SELLO antes de usarse en `INFORME.md`.

Fecha de consulta: sesión actual del auditor.

---

## P1. Filecoin — PoRep / SDR

Fuentes primarias usadas (raw del repo oficial `filecoin-project/specs`, rama `master`; equivalentes
renderizados en `spec.filecoin.io`, verificados donde se indica):

- `content/algorithms/pos/porep.md` — https://raw.githubusercontent.com/filecoin-project/specs/master/content/algorithms/pos/porep.md
- `content/algorithms/sdr/_index.md` — https://raw.githubusercontent.com/filecoin-project/specs/master/content/algorithms/sdr/_index.md
- `content/algorithms/sdr/notation.md` — https://raw.githubusercontent.com/filecoin-project/specs/master/content/algorithms/sdr/notation.md
- `content/systems/filecoin_mining/sector/sealing.md` — https://raw.githubusercontent.com/filecoin-project/specs/master/content/systems/filecoin_mining/sector/sealing.md
- `content/systems/filecoin_mining/sector/adding_storage.md` — https://raw.githubusercontent.com/filecoin-project/specs/master/content/systems/filecoin_mining/sector/adding_storage.md
- `content/algorithms/pos/post.md` — https://raw.githubusercontent.com/filecoin-project/specs/master/content/algorithms/pos/post.md
- `content/systems/filecoin_mining/storage_mining/_index.md` — https://raw.githubusercontent.com/filecoin-project/specs/master/content/systems/filecoin_mining/storage_mining/_index.md
- FIP-0019 (Snap Deals, status: Final) — https://raw.githubusercontent.com/filecoin-project/FIPs/master/FIPS/fip-0019.md
- FIP-0017 (Three-messages Lightweight Sector updates) — https://raw.githubusercontent.com/filecoin-project/FIPs/master/FIPS/fip-0017.md
- FIP-0082 (aggregated replica update proofs) — https://raw.githubusercontent.com/filecoin-project/FIPs/master/FIPS/fip-0082.md
- FIP-0106 (removal of `ProveReplicaUpdates`) — https://raw.githubusercontent.com/filecoin-project/FIPs/master/FIPS/fip-0106.md
- Implementación de referencia `generate_replica_id()` — https://raw.githubusercontent.com/filecoin-project/rust-fil-proofs/be90253f8ff7316d8ef862a1aaed92e76c05ce36/storage-porepsrc/stacked/vanilla/params.rs (ruta exacta usada: `storage-proofs/porep/src/stacked/vanilla/params.rs`, líneas 735–754)

### P1(a) — ¿Existe actualización de una réplica sellada sin volver a sellar entera? ¿A qué coste relativo?

**HECHO VERIFICADO EN FUENTE (existe una operación de actualización):**

FIP-0019 `fip-0019.md`, frontmatter y "Simple Summary" (líneas 3 y 17–19):

> "title: Snap Deals" … "A one-message protocol for updating any sector with new data without re-sealing."

FIP-0019, "Change Motivation" (línea 29):

> "Since 90+% of sectors in the Filecoin Network are CC sectors, having a protocol that allows for updating CC sectors to store real data without incurring in a full re-sealing would massively improve our network in terms of the amount of real data stored through it."

El método on-chain asociado, FIP-0019 (líneas 127–139), es `Miner.ProveReplicaUpdates(Updates []SnapDealsUpdate)` (la especificación también usa el nombre `Miner.ReplicaUpdate(...)` en la línea 85).

**HECHO VERIFICADO EN FUENTE (coste relativo, cualitativo):**

FIP-0019, "Encoding" (línea 109):

> "The Encoding function is cheap and allows for parallel encoding."

FIP-0019, "Future work" (línea 289):

> "Update protocol that does not require to perform an operation on a full sector."

FIP-0019, "Product Considerations" (líneas 280–281):

> "Snap Deals protocol significantly reduces the time needed for data to be included in a sector and confirmed on-chian. The process was designed with cost for storage providers in mind."

**HECHO VERIFICADO EN FUENTE (la actualización opera sobre el sector completo; no hay cifra relativa explícita):**

FIP-0019, "One-messages Update Protocol", paso 3.2 (líneas 64–72):

> "3. **Storage Provider updates an existing replica with deals**:
> 1. Pre-generate HashShards possible number of `EncodingRand(ComputeUnsealedCID(P1, P2, P3, ...), i)`
> 2. Encode the deal data into existing replica using `newReplica[i] = Enc(sectorKey[i], data[i], EncodingRand(o))` function: …"

FIP-0017 `fip-0017.md`, "Algorithms / Encoding" (línea 115):

> "Note that it requires re-encoding the entire sector with the new randomness."

**NO VERIFICADO:** no se encontró en FIP-0019 (ni en FIP-0017, 0041, 0059, 0082, 0090, 0092, 0106) una **cifra o ratio numérico explícito** del coste de la actualización frente al sellado completo (p. ej. "X% de un sellado"). Solo hay las expresiones cualitativas citadas ("without re-sealing", "cheap", "reduces the time", y el "future work" que implica que hoy sí se opera sobre el sector completo). No se rellena esa cifra.

**HECHO VERIFICADO EN FUENTE (límite de alcance de la actualización):**

FIP-0019, "Limitations" (línea 192):

> "The update protocol is limited to CC sectors as the `SectorKey` commitment is only avaliable for sectors with no data. The SectorKey commitment is currently included as `CommRLast` commitment inside the on-chain `SealedSectorCID` when the sector is CC. When the sector contains deals natively the `SealedSectorCID` includes only `CommRLast+Data` commitment."

FIP-0019, "Future work" (líneas 287–290):

> "* DeclareDeals to support deal transfer: allow moving deals from sector to sector
> * CapacityDeals: … 
> * Update protocol that does not require to perform an operation on a full sector.
> * DealUpdates: a license to terminate a deal in place for a new one …"

**HECHO VERIFICADO EN FUENTE (la aleatoriedad del update no es la del ticket de cadena; se deriva del contenido):**

FIP-0019, "One-messages Update Protocol", paso 4.1 (líneas 73–77):

> "4. **Storage Provider produces a proof of sector update.**
> Generate a SNARK that proves:
> 1. Generation of ChallengesNumber challenges in batches of 8:
> 1. For `j=0..ChallengesNumber//8`, `[_, c[8*j+7], c[8*j+6], ..., , c[8*j] = Split-31bit(Poseidon-128(Poseidon-128(UnsealedSectorCID, SealedSectorCID), j)`."

FIP-0019, "Encoding Randomness" (línea 98):

> "`EncodingRand(UnsealedSectorCID, i) = Poseidon-128(UnsealedSectorCID, i*HashShards//NodeSectorSize)`"

**HECHO VERIFICADO EN FUENTE (estado posterior del método):**

FIP-0106 `fip-0106.md`, "Simple Summary"/"Abstract" (líneas 20 y 18):

> "This FIP proposes the removal of the `ProveReplicaUpdates` method (Method 27) from the miner actor as it has been superseded by the more flexible `ProveReplicaUpdates3` method, which offers the same functionality in a more effective manner."

FIP-0082 título y objeto: "Add support for aggregated replica update proofs" (línea 3), es decir, existe agregación on-chain de pruebas de actualización de réplica.

**HECHO VERIFICADO EN FUENTE (la especificación general está desactualizada respecto de FIP-0019):**

`content/systems/filecoin_mining/sector/adding_storage.md`, "Upgrading Sectors" (líneas 37–41):

> "To incentivize Miners to hoard storage space and dedicate it to Filecoin, CC Sectors have a unique capability: **they can be "upgraded" to Regular Sectors** (also called "replacing a CC Sector")."
> "Upgrading capacity currently involves resealing, that is, creating a unique representation of the new data included in the Sector through a computationally intensive process. Looking ahead, committed capacity upgrades should eventually be possible without a reseal. A succinct and publicly verifiable proof that the committed capacity has been correctly replaced with replicated data should achieve this goal. However, this mechanism must be fully specified to preserve the security and incentives of the network before it can be implemented and is, therefore, left as a future improvement."

### P1(b) — ¿La especificación dice algo sobre minar VARIAS RAMAS con el MISMO almacenamiento sellado, o que el sellado ata la réplica a UNA rama/historia?

**HECHO VERIFICADO EN FUENTE (atadura a una cadena/historia, y motivo declarado):**

`content/systems/filecoin_mining/sector/sealing.md`, "Drawing randomness for sector commitments" (línea 41):

> "Tickets are used as input to calculation of the ReplicaID in order to tie Proofs-of-Replication to a given chain, thereby preventing long-range attacks (from another miner in the future trying to reuse SEALs)."

`content/systems/filecoin_mining/sector/sealing.md` (línea 81):

> "Note that the prover here is submitting a message on chain (i.e. the SEAL). Using an older ticket than necessary to generate the SEAL is something the miner may do to gain more confidence about finality (since we are in a probabilistically final system). However it has a cost in terms of securing the chain in the face of long-range attacks (specifically, by mixing in chain randomness here, we ensure that an attacker going back a month in time to try and create their own chain would have to completely regenerate any and all sectors drawing randomness since to use for their fork's power)."

Página renderizada equivalente verificada: https://spec.filecoin.io/systems/filecoin_mining/sector/sealing/ (sección "Drawing randomness for sector commitments"; el texto coincide literalmente con el anterior).

`content/algorithms/pos/porep.md`, "Proof-of-Replication (PoRep)" (línea 14):

> "The PoRep proof ties together: i) the data itself, ii) the miner actor that performs the sealing and iii) the time when the specific data has been sealed by the specific miner. In other words, if the same miner attempts to seal the same data at a later time, then this will result in a different PoRep proof. Time is included as the blockchain height when sealing took place and the corresponding chain reference is called `SealRandomness`."

`content/algorithms/sdr/_index.md`, "Replication" y "ReplicaID Generation" (líneas 906–940): el `ReplicaID` se genera con `create_replica_id(ProverID, SectorID, R_ReplicaID, CommD, PoRepID)` y su preimagen es `ProverID || be_encode(SectorID) || R_ReplicaID || CommD || PoRepID` (ver P3(a) para el texto literal). `PorepID` es el parámetro de aleatoriedad de cadena (`SealRandomness`).

**NO ENCONTRADO:** no se encontró en `porep.md`, `sdr/_index.md`, `sealing.md`, `adding_storage.md` ni `post.md` una frase explícita del tipo "un minero no puede minar N ramas con el mismo almacenamiento sellado" formulada como regla independiente. Lo que sí aparece es la formulación de arriba: el ticket ata la PoRep a una cadena concreta y cambiar de rama obliga a "completely regenerate any and all sectors". La especificación no dedica una sección a "minería multi-rama"; el argumento se da como prevención de long-range attacks.

### P1(c) — ¿Declara la especificación que la garantía de persistencia (sellado/PoSt) es ECONÓMICA y no criptográfica?

**HECHO VERIFICADO EN FUENTE (la frase pedida existe literalmente):**

`content/algorithms/pos/post.md` (línea 17):

> "- **_WindowPoSt_** is used as a proof that a copy of the data has been continuously maintained over time. This involves submitting proofs regularly (see details below) and makes it irrational for a miner to _not_ keep a sealed copy of the data (i.e., it is more expensive to seal a copy of the data every time they are asked to submit a WindowPoSt challenge)."

`content/algorithms/pos/post.md` (línea 47):

> "It naturally follows that the more the sectors a miner has pledged to store, the more the partitions of sectors that the miner will need to prove per deadline. This requires ready access to sealed copies of each of the challenged sectors and makes it irrational for the miner to seal data every time they need to provide a WindowPoSt proof."

**HECHO VERIFICADO EN FUENTE (el mecanismo concreto de la garantía son penalizaciones económicas):**

`content/algorithms/pos/post.md` (línea 49):

> "The Filecoin network expects constant availability of stored files. Failing to submit WindowPoSt for a sector will result in a fault, and the storage miner supplying the sector will be slashed – that is, a portion of their pledge collateral will be forfeited, and their storage power will be reduced (see Storage Power Consensus)."

`content/systems/filecoin_mining/storage_mining/_index.md`, "Miner Accounting" (líneas 58–60):

> "1. Miners deposit tokens to act as collateral for their PreCommitted and ProveCommitted Sectors
> 2. Miners earn tokens from block rewards, when they are elected to mine a new block and extend the blockchain.
> 3. Miners lose tokens if they fail to prove storage of a sector and are given penalties as a result."

**NO VERIFICADO:** no se encontró una frase literal que diga "esta garantía es económica y no criptográfica". El argumento aparece formulado como "makes it irrational for a miner to not keep a sealed copy" (racionalidad/incentivos) y como slashing/penalizaciones. La afirmación "no criptográfica" no está escrita con esas palabras en las páginas citadas.

---

## P2. Cifrado actualizable (UE) y pruebas incrementales / IVC

### P2(a) — ¿Hay asimetría real entre CREAR y ACTUALIZAR? Definición de update y su coste

**HECHO VERIFICADO EN FUENTE (origen del término y definición):**

Boyd, Davies, Gjøsteen, Jiang, "Fast and Secure Updatable Encryption", CRYPTO 2020 (PDF: https://www.iacr.org/archive/crypto2020/12171157/12171157.pdf ; eprint: https://eprint.iacr.org/2019/1457), §1 Introducción, pág. 1:

> "An alternative approach to solving this problem is to useupdatable encryption (UE), rst dened by Boneh et al. [3] (henceforth BLMR). The user computes a token and sends it to the storage server. The token allows the server to update the ciphertexts so that they become encryptions under some new key. Although the token clearly depends on both the old and new encryption keys, knowledge of the token alone should not allow the server to obtain either key."

Referencia [3] del mismo paper (bibliografía, pág. 27):

> "3. Boneh, D., Lewi, K., Montgomery, H.W., Raghunathan, A.: Key homomorphic PRFs and their applications. In: Canetti, R., Garay, J.A. (eds.) Proceedings of CRYPTO 2013 I. LNCS, vol. 8042, pp. 410–428. Springer (2013)."

El paper original de BLMR está abierto: "Key Homomorphic PRFs and Their Applications", eprint 2015/220, https://eprint.iacr.org/2015/220.pdf , §7.3 "Updatable Encryption":

> "First, an updatable encryption scheme Π is the same as a symmetric proxy re-encryption scheme, except that the re-encryption key generation algorithm ReEnc takes as input two secret keys sk1 and sk2 along with a ciphertext C and outputs a short uni-directional re-encryption key rk1,2,C. The length of this re-encryption key rk1,2,C must be independent of the size of the ciphertext to which it will be used."

**NO ENCONTRADO:** no se localizó ningún paper de "Updatable Encryption" atribuido a **Boneh–Liskov–Pass**. La atribución que consta en las fuentes primarias es a Boneh–Lewi–Montgomery–Raghunathan (BLMR). Tampoco se encontró un **survey de updatable encryption de Boyd et al.**; la fuente primaria abierta encontrada de Boyd et al. sobre UE es el paper CRYPTO 2020 anterior. (Búsquedas realizadas; resultados no concluyentes.)

**HECHO VERIFICADO EN FUENTE (sintaxis: qué es update):**

Boyd et al. CRYPTO 2020, §2, Fig. 2 (págs. 8–9):

> "We follow the syntax of prior work [17], dening an Updatable Encryption (UE) scheme as a tuple of algorithms {UE.KG, UE.TG, UE.Enc, UE.Dec, UE.Upd} that operate in epochs, these algorithms are described in Fig. 2."

La Fig. 2 (texto extraído) da:

> "UE.TG Token Gen Det ke, ke+1 ∆e+1 ∆e+1← UE.TG(ke, ke+1)
> UE.Upd Update Ctxt Rand/det Ce,∆ e+1 Ce+1 Ce+1 ← UE.Upd(∆e+1, Ce)"

**HECHO VERIFICADO EN FUENTE (coste de crear vs. actualizar, en el esquema SHINE del mismo paper):**

Boyd et al. CRYPTO 2020, Abstract (pág. 1):

> "In the variant designed for short messages, ciphertext generation consists of applying one permutation and one exponentiation (per message block), while updating ciphertexts requires just one exponentiation."

Boyd et al. CRYPTO 2020, §5 "The SHINE Schemes", Fig. 14 (pág. 21), algoritmo SHINE0:

> "SHINE0.Enc(ke, M) : N ←− N ; Ce← (π(N‖M‖0t))ke ; return Ce"
> "SHINE0.Upd(∆e+1, Ce) : Ce+1← (Ce)∆e+1 ; return Ce+1"

Es decir, la actualización es **una exponenciación por bloque de ciphertext**, del mismo orden que una operación de cifrado de bloque (cifrar = una permutación + una exponenciación), y el token de actualización es el cociente de claves de época (`∆e+1← ke+1/ke`).

**HECHO VERIFICADO EN FUENTE (qué se almacena):** el objeto que se almacena sigue siendo el ciphertext; la actualización la aplica el servidor sobre el ciphertext almacenado (`UE.Upd(∆e+1, Ce)`), no se crea un objeto nuevo caro. No existe en estos papers una noción de "objeto caro de crear que se re-liga"; el modelo es rotación de clave sobre ciphertexts existentes.

### P2(b) — ¿Cuánto cuesta VERIFICAR la actualización? ¿La actualización es pública o requiere clave secreta?

**HECHO VERIFICADO EN FUENTE (el token se deriva de claves secretas y lo produce el cliente):**

Boyd et al. CRYPTO 2020, §1 (pág. 1): "The user computes a token and sends it to the storage server." (cita completa en P2(a)).

BLMR eprint 2015/220, §7.3: "the re-encryption key generation algorithm ReEnc takes as input two secret keys sk1 and sk2 along with a ciphertext C and outputs a short uni-directional re-encryption key rk1,2,C" (cita completa en P2(a)).

Boyd et al. CRYPTO 2020, §5, Fig. 14: `SHINE0.TG(ke, ke+1) : ∆e+1← ke+1/ke` — el token se calcula a partir de las claves secretas de dos épocas.

**HECHO VERIFICADO EN FUENTE (no hay noción de verificación pública de la actualización; la corrección es por descifrado y hay integridad de ciphertext):**

Boyd et al. CRYPTO 2020, §2, tras Fig. 2:

> "Correctness [17] is dened as expected: fresh encryptions and updated ciphertexts should decrypt to the correct message under the appropriate epoch key."

Boyd et al. CRYPTO 2020, Abstract (pág. 1):

> "We prove that SHINE is secure under our new condentiality denition while also providing ciphertext integrity."

**NO VERIFICADO / NO ENCONTRADO:** no se encontró en BLMR (eprint 2015/220) ni en Boyd et al. (CRYPTO 2020) un **coste explícito de "verificar la actualización"** ni una noción de verificador público de la actualización. Lo que las fuentes definen es corrección (descifrado) e integridad de ciphertext (INT-CTXT); no una prueba pública de que la actualización se hizo bien. Por tanto, "cuánto cuesta verificar" no está cuantificado en estas fuentes.

### P2(c) — IVC (Valiant; Nova): ¿qué se actualiza, qué cuesta verificarlo, se puede re-ligar sin recomputar, qué se almacena?

**HECHO VERIFICADO EN FUENTE (definición y origen):**

Nova: Kothapalli, Setty, Tzialla, "Nova: Recursive Zero-Knowledge Arguments from Folding Schemes", eprint 2021/370, https://eprint.iacr.org/2021/370.pdf , §2.3 (pág. 4), Definition 5:

> "Incrementally verifiable computation (IVC) [47] enables verifiable computation for repeated function application. Intuitively, for a function F, with initial input z0, an IVC scheme allows a prover to produce a proof Πi for the statement zi = F (i)(z0) (i.e., i applications of F on input z0) given a proof Πi−1 for the statement zi−1 = F (i−1)(z0)."

La referencia [47] del mismo paper (bibliografía, pág. 26) es:

> "[47] Valiant, P.: Incrementally verifiable computation or proofs of knowledge imply time/space eciency. In: TCC. pp. 552–576 (2008)"

Nova, §1.2 (pág. 3):

> "At each incremental step, the IVC prover produces a proof that the step was computed correctly and it has veried a proof for the prior step. In other words, at each incremental step, the IVC prover produces a proof of satisability for an augmented circuit that augments the circuit for F with a "verier circuit" that veries the proof of the prior step. Recursively, the nal proof proves the correctness of the entire incremental computation. A key aspect of IVC is that neither the IVC verier's work nor the IVC proof size depends on the number of steps in the incremental computation. In particular, the IVC verier only veries the proof produced at the last step of the incremental computation."

**HECHO VERIFICADO EN FUENTE (coste de verificación y de cómputo, cotas del propio paper):**

Nova, §1.2, Theorem 2 (pág. 4):

> "– IVC proof sizes are O(|F|) and the verier's work to verify them is Oλ(|F|). The prover's work at each incremental step is ≈|F|. Specically, the prover's work at each step is dominated by two multiexponentiations of size ≈|F|.
> – Succinct zero-knowledge proofs of valid IVC proofs are size Oλ(log|F|), and the verier's work to verify them is either Oλ(log|F|) or Oλ(|F|) depending on the commitment scheme for vectors. The prover's work to produce this succinct zero-knowledge proof is Oλ(|F|)."

Nova, §1.3 (resultados medidos, pág. 4):

> "When |F|≈ 220 constraints, the prover's per-step cost to produce an IVC proof is ≈1µs/constraint. For the same F , the cost to produce a compressed IVC proof is ≈24µs/constraint."
> "Compressed IVC proofs are ≈ 8–9 KB and are signicantly shorter than IVC proofs (e.g., they are ≈7,400× shorter when|F|≈ 220 constraints)."

Nova, §1.2 (pág. 3):

> "With the description thus far, the size of an IVC proof (which is a purported witness for the running relaxed R1CS instance) is Oλ(|F|). Instead of sending such a proof to a verier, at any point in the incremental computation, Nova's prover can prove the knowledge of a satisfying witness to the running relaxed R1CS instance in zero-knowledge with an Oλ(log|F|)-sized succinct proof using a zkSNARK that we design by adapting Spartan [41]."

**NO ENCONTRADO:** no se encontró en Nova (eprint 2021/370) ninguna operación de "re-ligar" un objeto ya computado a otra historia/rama sin recomputar. La definición ata la prueba al prefijo de cómputo concreto (`zi = F (i)(z0)`); el paper no define ni discute cambiar ese prefijo. Tampoco se encontró en Nova una afirmación de que el probador pueda actualizar la ligadura sin re-ejecutar los pasos. Sobre "qué se almacena": el paper cuantifica tamaño de la prueba IVC (`O(|F|)` elementos de grupo) y de la prueba comprimida (≈8–9 KB), pero **NO ENCONTRADO** una especificación explícita de qué estado/witness debe retener el probador entre pasos más allá de lo implícito en la construcción del folding.

---

## P3. Semilla secreta en proof-of-space

### P3(a) — ¿Cómo entra el secreto/aleatoriedad en el ReplicaID de Filecoin? ¿Es del minero? ¿Neutral entre ramas?

**HECHO VERIFICADO EN FUENTE (fórmula y función):**

`content/algorithms/sdr/_index.md`, "Replication" (línea 908):

> "$\line{1}{\bi}{\ReplicaID = \createreplicaid(\ProverID, \SectorID, \R_\replicaid, \CommD, \PorepID)}$"

`content/algorithms/sdr/_index.md`, "ReplicaID Generation" (líneas 918–940):

> "The function `$\createreplicaid$` describes how a miner having the ID `$\ProverID$` is able to generate a `$\ReplicaID$` for a replica `$R$` of sector `$D$`, where `$D$` has a unique ID `$\SectorID$` and commitment `$\CommD$`. The prover uses a unique random value `$\R_\ReplicaID$` for each `$\ReplicaID$` generated."
> "$\line{1}{}{\preimage: \Byte^{[136]} =}$
> $\quad\quad \ProverID$
> $\quad\quad \|\ \beencode(\SectorID) \as \Byte^{[8]}$
> $\quad\quad \|\ \R_\ReplicaID$
> $\quad\quad \|\ \CommD$
> $\quad\quad \|\ \PorepID$
> $\line{2}{}{\return \Sha{254}(\preimage) \as \Fqsafe}$"

`content/algorithms/sdr/notation.md` (línea 785):

> "`$\R_\replicaid: \Byte^{[32]}$` A random value used to generate a replica `$R$`'s `$\ReplicaID$`."

Implementación de referencia `generate_replica_id()` (rust-fil-proofs, `storage-proofs/porep/src/stacked/vanilla/params.rs`, líneas 736–753), firma y cuerpo:

> "pub fn generate_replica_id<H: Hasher, T: AsRef<[u8]>>(prover_id: &[u8; 32], sector_id: u64, ticket: &[u8; 32], comm_d: T, porep_seed: &[u8; 32]) -> H::Domain { … let hash = Sha256::new().chain(prover_id).chain(&sector_id.to_be_bytes()[..]).chain(ticket).chain(AsRef::<[u8]>::as_ref(&comm_d)).chain(porep_seed).result(); bytes_into_fr_repr_safe(hash.as_ref()).into() }"

**HECHO VERIFICADO EN FUENTE (procedencia de cada componente):**

- `R_ReplicaID` es un valor aleatorio **del probador** ("unique random value", "A random value used to generate a replica R's ReplicaID"), es decir, elegido por el minero. Es el único componente verdaderamente secreto/aleatorio propio; no depende de la rama, luego es neutral entre ramas por construcción.
- `PoRepID` es el parámetro de aleatoriedad de cadena. `sealing.md` línea 41: "Tickets are used as input to calculation of the ReplicaID in order to tie Proofs-of-Replication to a given chain…". En la implementación el parámetro correspondiente se llama `ticket`.
- `ProverID` ata el `ReplicaID` a la identidad del minero.

**HECHO VERIFICADO EN FUENTE (el ticket es público, no secreto):**

`content/systems/filecoin_blockchain/storage_power_consensus/_index.md` (línea 111):

> "Filecoin block headers also contain a single "ticket" generated from its epoch's beacon entry. Tickets are used to break ties in the Fork Choice Rule, for forks of equal weight."

`content/algorithms/pos/sealing.md` (línea 32 de `sealing.md`): "Assuming these values were not able to be predicted ahead of time, this helps ensure that Miners generated proofs at a specific point in time." (la seguridad se apoya en impredecibilidad, no en secreto).

**Respuesta literal a "neutral o atado a historia":** por las fuentes, el componente propio del minero (`R_ReplicaID`) es neutral entre ramas (no depende de la cadena); el componente `PoRepID`/ticket **sí** ata el `ReplicaID` a una cadena/historia concreta, y es público. El `ReplicaID` alimenta la generación de etiquetas (`Labels = generate_labels(ReplicaID)`), de modo que cambiar el ticket cambia las etiquetas. Esto es exactamente lo que `sealing.md` línea 81 describe como motivo de "completely regenerate any and all sectors".

**NO VERIFICADO (discrepancia menor de notación):** la especificación escribe `SHA254(preimage)`; la implementación de referencia usa `Sha256::new()` seguido de `bytes_into_fr_repr_safe` (truncado al cuerpo seguro). Se reporta tal cual; no se interpreta.

### P3(b) — ¿Hay propuestas abiertas de proof-of-space con semilla secreta ligada a la historia/cadena (no solo a la identidad)?

**HECHO VERIFICADO EN FUENTE (propuesta de PoS multi-cadena con prueba específica de cadena):**

Tang, Zheng, Deng, Wang, Liu, Gu, "Towards a Multi-Chain Future of Proof-of-Space", arXiv:1907.07896 (SecureComm 2019), https://arxiv.org/abs/1907.07896 (PDF: https://arxiv.org/pdf/1907.07896). Abstract:

> "Proof-of-Space provides an intriguing alternative for consensus protocol of permissionless blockchains due to its recyclable nature and the potential to support multiple chains simultaneously. However, a direct shared proof of the same storage, which was adopted in the existing multi-chain schemes based on Proof-of-Space, could give rise to newborn attack on new chain launching. To x this gap, we propose an innovative framework of single-chain Proof-of-Space and further present a novel multi-chain scheme which can resist newborn attack eectively by elaborately combining shared proof and chain-specic proof of storage."

Mismo paper, §2.2 "Proof-of-Space" (pág. 4 del PDF):

> "Initialization is an interactive process between the prover P and the verier V. It runs on shared inputs (id,S). id is an identier to assure that the prover P cannot reuse the same disk space to run PoC for dierent statement. S is the amount of storage the prover P wants to dedicate."

Mismo paper, §3.1 "Graph Labeling Game" (pág. 4 del PDF):

> "For every id, a fresh hash function can be sampled: Hid =H(id||·)."

**HECHO VERIFICADO EN FUENTE (semilla de PoS derivada de identidad + historia, en una especificación abierta de consenso):**

Subspace / Autonomys, `protocol-specs/docs/consensus/proof_of_space.md` (Dilithium consensus, basado en Chia PoS), https://raw.githubusercontent.com/subspace/protocol-specs/main/docs/consensus/proof_of_space.md , sección "Parameters":

> "- `seed`: a unique 32-byte seed that determines memory contents (the table values) obtained from the farmer public key, current sector, piece offset within the sector and current history size."

(Es una especificación abierta de un consenso propuesto; se cita como tal.)

**HECHO VERIFICADO EN FUENTE (SpaceMint: nonce y reutilización de espacio):**

Park, Kwon, Fuchsbauer, Gąsi, Alwen, Pietrzak, "SpaceMint: A Cryptocurrency Based on Proofs of Space", eprint 2015/528, https://eprint.iacr.org/2015/528.pdf , nota al pie 5 (pág. 5 del PDF):

> "The nonce just ensures that the same space cannot be used for two dierent proofs [14]; thus in a single-verier setting, P can generate the nonce."

SpaceMint, §"Long forks by space reuse" (pág. 26 del PDF):

> "The security of SpaceMint relies on the assumption that it is not possible to reuse space for mining. As we can compute the challenges for up to ∆ + δ blocks in advance, for reusing space even just twice, one would have to initialize the space in less than time(∆ +δ) = 1(50 + 10)/2 = 30 minutes. This is far from the ≈ 200 minutes required to instantiate 100 GB of space, which is the minimum we suggest."

SpaceMint, §"Long forks by space reuse" (continuación, pág. 26–27), sobre el adversario que hace un fork largo:

> "As the adversary has less space than the total space contributed by all miners, he must re-instantiate the space many times while generating these blocks. This will take a lot of time, but the adversary has time(low + high) minutes to generate these high blocks, so it will be possible by setting low high enough."

SpaceMint, §"Implementation" (pág. 13 aprox.):

> "In fact, space initialization should take non-trivial time because an extremely fast space initialization would make re-using the same space for dierent commitments a viable strategy."

**NO ENCONTRADO:** no se localizó ninguna propuesta primaria con los nombres exactos **"hidden seed proof of space"**, **"private seed proof of space"** ni **"proof of space with secret seed"**. Las búsquedas devolvieron resultados no relacionados (patentes, blogs, otros primitivos). Lo más cercano y verificado son: (i) el `id` específico de cadena/statement de Tang et al., (ii) el `seed` de Subspace derivado de clave pública del farmer + sector + offset de pieza + tamaño de historia actual, y (iii) el nonce/re-inicialización de SpaceMint.

### P3(c) — ¿La semilla secreta impide que OTRO regenere el objeto, o impide que el PROPIO dueño lo regenere?

Se separan los dos mecanismos que **sí** aparecen en fuentes, con cita; no se interpreta.

**HECHO VERIFICADO EN FUENTE (mecanismo A: aleatoriedad de codificación oculta al servidor → protege frente a TERCEROS):**

Damgård, Ganesh, Orlandi, "Proofs of Replicated Storage Without Timing Assumptions", CRYPTO 2019, https://www.iacr.org/archive/crypto2019/116940316/116940316.pdf , §1.2 "Technical Overview":

> "The existing time-bounded proofs use a public deterministic encoding function. The problem is that this always allow a malicious server to recompute encoded data and this may lead to a successful recomputation attack if the server has sucient computational resources. Our observation is that one can instead make the encoding be probabilistic. Now the adversary will only see the encoded data but not the randomness that the client used to encode. One may therefore hope that recomputing an encoding is not only slow, but completely unfeasible."

**HECHO VERIFICADO EN FUENTE (mecanismo B: la rama/historia entra en la aleatoriedad y re-ligar exige recomputación completa → el coste lo paga el DUEÑO):**

`sealing.md` línea 81 (citada completa en P1(b)):

> "…by mixing in chain randomness here, we ensure that an attacker going back a month in time to try and create their own chain would have to completely regenerate any and all sectors drawing randomness since to use for their fork's power."

`sealing.md` línea 41 (citada completa en P1(b)):

> "Tickets are used as input to calculation of the ReplicaID in order to tie Proofs-of-Replication to a given chain, thereby preventing long-range attacks (from another miner in the future trying to reuse SEALs)."

SpaceMint, §"Long forks by space reuse" (pág. 26 del PDF):

> "The security of SpaceMint relies on the assumption that it is not possible to reuse space for mining."

SpaceMint, §"Implementation":

> "space initialization should take non-trivial time because an extremely fast space initialization would make re-using the same space for dierent commitments a viable strategy."

**Distinción que las fuentes permiten sostener literalmente:**
- (i) **Secreto de la aleatoriedad de codificación** (Damgård–Ganesh–Orlandi): el servidor no puede recomputar porque no ve la aleatoriedad que usó el cliente. Esto es protección contra **terceros**; no se afirma nada sobre impedir al dueño.
- (ii) **Aleatoriedad derivada de la cadena/rama + inicialización cara** (Filecoin `sealing.md`; SpaceMint; Tang et al.): el mismo dueño que quiera la misma réplica para otra rama debe **regenerarla por completo**, y el coste es el de la inicialización/sellado. Esto es coste por rama para el **dueño**.
- **NO ENCONTRADO:** ninguna fuente que afirme que una semilla secreta impide al propio dueño regenerar (si él conoce la semilla, nada en las fuentes citadas se lo impide; el coste por rama en los sistemas citados proviene de que la semilla/parámetro depende de la rama y de que la inicialización es cara).

---

## P4. ¿Existe literatura sobre re-sellado incremental, "proof of replication update", "incremental SNARK for storage" o "updatable proof of storage"?

**HECHO VERIFICADO EN FUENTE (lo más cercano: PDP dinámico — actualiza DATOS, no la ligadura de rama):**

Erway, Küpçü, Papamanthou, Tamassia, "Dynamic Provable Data Possession", eprint 2008/432, https://eprint.iacr.org/2008/432.pdf , Abstract:

> "We present a denitional framework and ecient constructions for dynamic provable data possession (DPDP), which extends the PDP model to support provable updates to stored data. We use a new version of authenticated dictionaries based on rank information. The price of dynamic updates is a performance change from O(1) to O(log n) (or O(nǫ log n)), for a le consisting of n blocks, while maintaining the same (or better, respectively) probability of misbehav ior detection."

En este trabajo "update" significa modificar/insertar/borrar bloques del fichero del cliente; el servidor almacena los datos actualizados y prueba posesión. No hay cambio de ligadura de una réplica a otra historia/rama.

**HECHO VERIFICADO EN FUENTE (formalización de "proof of replication" y por qué un encoding público determinista permite recomputar):**

Damgård–Ganesh–Orlandi, CRYPTO 2019 (URL arriba), Abstract:

> "In this paper we provide the rst construction of a proof of replication which does not rely on any timing assumptions."

Mismo paper, §1.1, sobre trabajos previos:

> "Time-bounded Proofs of Replication. In a recent work by Pietrzak [Pie18], a construction for proof of replication based on proof of space is given. A proof of replication is not formally dened, and therefore it is not clear what is the replication property that the construction satises. In addition, since a proof of space is the starting point of the construction, it has the same "time-bounded" property as the Filecoin construction, since a malicious server can pass the audit by recomputing data."

Mismo paper, §1.2 (citado completo en P3(c)): encoding público determinista → recomputación posible; encoding probabilístico con aleatoriedad del cliente → el servidor no puede recomputar.

**HECHO VERIFICADO EN FUENTE (mecanismo real de Filecoin que SÍ es "update sin re-sellar", pero que no cambia la ligadura de rama):** FIP-0019 Snap Deals, ya citado en P1(a). Su aleatoriedad de actualización se deriva del contenido (`EncodingRand(UnsealedSectorCID, i)`, challenge seed `Poseidon-128(Poseidon-128(UnsealedSectorCID, SealedSectorCID), j)`), no de un ticket de cadena.

**NO ENCONTRADO (declaración explícita):** no se ha encontrado literatura ni especificación abierta que describa una primitiva que permita **cambiar la ligadura de una réplica ya sellada a otra historia/rama pagando menos que un sellado completo**. En particular:
- No se encontró "updatable proof of replication" / "proof of replication update" con esa semántica.
- No se encontró "incremental SNARK for storage" que re-ligue almacenamiento a otra historia.
- No se encontró una variante de PoR/PDP que cambie la ligadura de rama; PDP dinámico (eprint 2008/432) y proof-of-replication sin supuestos de tiempo (CRYPTO 2019) resuelven otros problemas.
- Los únicos "updates sin re-sellar" reales localizados son Filecoin FIP-0019/FIP-0017, y no re-ligan la réplica a otra rama (dependen del `SectorKey` del sellado original del sector CC).

Consultas de búsqueda empleadas para el "no encontrado" (entre otras): `"updatable proof of storage"`, `"incremental SNARK" storage`, `"proof of replication" update re-bind chain`, `"updatable proof of replication"`, `"incremental proof of replication"`, `"proof of storage update"`, `"updatable PoRep"`.

---

## Anexo: archivos locales de evidencia

- `.p1evidence/` — páginas de especificación Filecoin y FIPs descargadas (`.md`).
- `.p1evidence/pdfs/` — PDFs originales y su texto extraído (`.txt`): `ue-crypto2020`, `blmr`, `nova`, `dynpdp`, `repstorage`, `spacemint`, `multichain-pos`, `pos-essence`, `pos-dziembowski`, entre otros.

## Anexo: resumen de estados por subpregunta

| Subpregunta | Estado |
|---|---|
| P1(a) existencia de update sin re-sellar | HECHO (FIP-0019, Final) |
| P1(a) coste relativo numérico | NO VERIFICADO (solo cualitativo) |
| P1(b) atadura a una cadena / regeneración en fork | HECHO (sealing.md 41 y 81; porep.md 14) |
| P1(b) frase explícita "minar varias ramas con el mismo sellado" | NO ENCONTRADO como regla independiente |
| P1(c) "makes it irrational for a miner to not keep a sealed copy" | HECHO (post.md 17) |
| P1(c) frase "la garantía es económica, no criptográfica" | NO VERIFICADO |
| P2(a) definición de UE y coste | HECHO (BLMR 2015/220 §7.3; Boyd et al. CRYPTO 2020) |
| P2(a) paper "Boneh–Liskov–Pass" / survey de Boyd | NO ENCONTRADO |
| P2(b) verificación pública/coste | NO ENCONTRADO (UE define corrección e integridad) |
| P2(c) IVC: definición, coste, almacenamiento | HECHO (Nova eprint 2021/370, Thm. 2) |
| P2(c) re-ligar sin recomputar | NO ENCONTRADO |
| P3(a) fórmula de ReplicaID y origen del secreto | HECHO (sdr/_index.md; notation.md; rust params.rs) |
| P3(b) PoS con semilla ligada a historia/identidad | HECHO (arXiv:1907.07896; Subspace spec; SpaceMint) |
| P3(b) nombres exactos "hidden/private seed PoS" | NO ENCONTRADO |
| P3(c) distinción terceros vs. dueño | HECHO (Damgård et al.; sealing.md; SpaceMint) |
| P4 re-sellado incremental / re-ligadura barata | NO ENCONTRADO |
| P4 PDP dinámico / proof of replication formal | HECHO (eprint 2008/432; CRYPTO 2019) |
