# F0a · Clave de firma, identidad de plot y castigo de espacio

**Ronda:** d13-finalidad · **Fecha:** 2026-09-10 · **Encargo:** `ENCARGO.md` F0, variante 1
(castigo de espacio).
**Pregunta que decide:** probada la doble firma, ¿se puede revocar la elegibilidad del plot/clave
sin que el atacante escape rotando la clave? Es decir: **¿se puede rotar la clave del plot sin
volver a plotear?**

**Fuentes primarias leídas (no de memoria):**

| Fuente | Versión / commit |
|---|---|
| Autonomys `subspace` | `/home/katana/zeo/fuentes/subspace` @ `f8842d0` |
| Chia `chia-blockchain` | `/home/katana/zeo/ZEROX/PDF/chia-blockchain` @ `f87270c02` (release/2.7.4) |
| Medidas de ploteo propias | `research/coste-ploteo-medido.md` (banco sobre `f8842d0`) |
| Auditoría previa del Sybil de claves | `research/dag-poas-balizas-auditoria.md` VECTOR 1 |
| Equivocación gratis d12 | `research/scripts/d12-quorum/informe.md` §F.7 |

**Convención de etiquetas de este informe** (declarada para que no haya ambigüedad):

- **DEMOSTRADO** — probado por código o derivación, con `fichero:línea`.
- **VERIFICADO** — medido por nosotros o comprobado contra el artefacto primario (commit, banco).
- **PLAUSIBLE** — consistente con la evidencia, pero sin prueba cerrada ni medición directa.
- **REFUTADO** — la afirmación contraria está probada.
- **LAGUNA** — no encontrado; se dice qué haría falta.

---

## Veredicto en tres frases

1. La clave que firma la recompensa **es** la identidad del plot (`solution.public_key`), y el plot
   está criptográficamente atado a ella vía `SectorId`: **no se puede re-clavar un plot; hay que
   replotear**. Pero crear una identidad nueva es **gratis** y plotear escala con bytes, no con
   identidades.
2. Por tanto el castigo de espacio es **evadible a coste acotado y pequeño**: el atacante
   fragmenta su espacio en muchas claves sin pagar nada extra, y al ser baneada una clave solo
   pierde los sectores que produjeron la equivocación (suelo: ~1 sector; conservador: `k` sectores
   para un quórum de `k`).
3. Con los números medidos (83,6 s/GiB CPU 32 hilos; 69,4 s/GiB GTX 1070), replotear los sectores
   infractores de un quórum `k=64` cuesta **~64 GiB de ploteo: 89 min en CPU, 74 min en GTX 1070,
   4,6–10,6 min con una GPU tope de 2026 extrapolada** — o **cero** si el atacante abandona esos
   sectores. El castigo es *ex post* y no deshace la equivocación ya emitida.

**Etiqueta global de la variante «castigo de espacio»: REFUTADO** como regla anti-equivocación
sin dinero en juego. No restaura la Definición 1 de HotPoW.

---

## 1 · ¿La verificación de una solución mira el valor votado?

**Confirmado: no.** `verify_solution` no recibe ni consulta el valor votado, el bloque, ni la
cabecera. La cita del encargo (`subspace-verification/src/lib.rs:228-272`) es correcta.

Firma exacta de la función (`subspace-verification/src/lib.rs:211-216`):

```rust
pub fn verify_solution<'a, PosTable, RewardAddress>(
    solution: &'a Solution<RewardAddress>,
    slot: SlotNumber,
    params: &'a VerifySolutionParams,
    kzg: &'a Kzg,
) -> Result<SolutionRange, Error>
```

`VerifySolutionParams` son solo PoT, rango de solución y parámetros de comprobación de pieza
(`lib.rs:181-191`). No hay parámetro de bloque ni de valor.

La cadena de derivación del reto (`lib.rs:234-236`):

```rust
let global_randomness = proof_of_time.derive_global_randomness();
let global_challenge = global_randomness.derive_global_challenge(slot);
let sector_slot_challenge = sector_id.derive_sector_slot_challenge(&global_challenge);
```

- `derive_global_randomness` = `blake3(PoT)` (`subspace-core-primitives/src/pot.rs:278-280`).
- `derive_global_challenge(slot)` = `blake3(global_randomness ‖ slot)`
  (`subspace-core-primitives/src/lib.rs:110-112`). **El slot entra; el valor votado no.**
- `SectorId` = `blake3_keyed(public_key_hash, [sector_index, history_size])`
  (`subspace-core-primitives/src/sectors.rs:56-68`).

La `Solution` (`subspace-core-primitives/src/solutions.rs:254-275`) tiene `public_key`,
`reward_address`, `sector_index`, `history_size`, `piece_offset`, `record_commitment`,
`record_witness`, `chunk`, `chunk_witness`, `proof_of_space`. **No tiene campo de valor votado.**

La atadura al valor la pone **otra** verificación, separada: `check_reward_signature`
(`subspace-verification/src/lib.rs:107-116`), llamada con:

- el hash del **voto** en el pallet (`pallet-subspace/src/lib.rs:1476-1484`), donde
  `Vote::hash()` = `blake2_256(vote.encode())` e incluye `height`, `parent_hash`, `slot`,
  `solution`, `proof_of_time`, `future_proof_of_time`
  (`sp-consensus-subspace/src/lib.rs:180-198, 218-221`); y
- el **pre-hash** de la cabecera en el verificador (`sc-consensus-subspace/src/verifier.rs:339-348`).

Es decir: la elegibilidad es ciega al valor; la firma sí lo cubre, **pero la misma clave puede
firmar cuantos valores quiera**. Esto es exactamente el hallazgo de d12 §F.7
(`research/scripts/d12-quorum/informe.md:614-641`), y aquí queda confirmado contra el código.
**DEMOSTRADO.**

**Matiz importante (no invalida lo anterior):** el pallet sí detecta un caso estrecho de
equivocación —véase §4—, pero eso no cambia que el reto de la solución sea independiente del valor:
un atacante puede emitir votos en conflicto con soluciones válidas para todos ellos.

---

## 2 · ¿Qué clave firma la recompensa y qué relación tiene con el plot?

### 2.1 La clave que firma es la identidad del plot

El granjero de Autonomys guarda **una sola** identidad por farm, un keypair schnorrkel derivado de
32 bytes de entropía (`subspace-farmer/src/single_disk_farm/identity.rs:23-27, 48-52, 105-109`), en
`identity.bin` (`identity.rs:73`).

Esa identidad firma la recompensa (`identity.rs:149-152`):

```rust
pub fn sign_reward_hash(&self, header_hash: &[u8]) -> Signature {
    self.keypair.sign(self.substrate_ctx.bytes(header_hash))
}
```

y el flujo de firma comprueba que la clave pedida por el nodo **es** la de la identidad
(`subspace-farmer/src/single_disk_farm/reward_signing.rs:20-28`):

```rust
while let Some(RewardSigningInfo { hash, public_key }) = ... {
    // Multiple plots might have solved, only sign with correct one
    if identity.public_key().to_bytes() != *public_key {
        continue;
    }
    let signature = identity.sign_reward_hash(&hash);
```

Al verificar, la clave esperada es `solution.public_key`:

- voto: `check_reward_signature(signed_vote.vote.hash().as_bytes(), &signed_vote.signature,
  &solution.public_key, ...)` (`pallet-subspace/src/lib.rs:1476-1480`);
- cabecera: `check_reward_signature(pre_hash.as_ref(), &signature,
  &pre_digest.solution().public_key, ...)` (`sc-consensus-subspace/src/verifier.rs:339-343`).

Y esa misma `solution.public_key` es la que construye el `SectorId` que la prueba de espacio debe
satisfacer (§1 y §3). **La clave de firma es, literalmente, la identidad del plot. No hay una
«clave de recompensa» separada.** DEMOSTRADO.

El modo clúster no cambia esto: el controlador solo **reenvía** la firma que produce el farm
(`subspace-farmer/src/cluster/controller.rs:835-860`), y el farm firma con su identidad
(`subspace-farmer/src/single_disk_farm.rs:1244`). El controlador tiene su propia identidad para
libp2p (`commands/cluster/controller.rs:127`), no para recompensas.

### 2.2 Lo que sí se puede cambiar sin replotear: la dirección de recompensa

`solution.reward_address` es un campo independiente (`solutions.rs:257-258`). Se fija por CLI,
`--reward-address` (`commands/farm.rs:164-165, 293-304`), **no se persiste** en
`SingleDiskFarmInfo` (cuyos campos son `id`, `genesis_hash`, `public_key`, `pieces_in_sector`,
`allocated_space`: `single_disk_farm.rs:107-125`), y el pallet paga a
`solution.reward_address` (`find_block_reward_address`, `pallet-subspace/src/lib.rs:1748-1762`;
votantes en `1765-1782`).

**Conclusión §2:** cambiar **dónde va el dinero** no exige replotear; cambiar **la clave que firma**
sí, porque es la identidad del plot. DEMOSTRADO.

---

## 3 · ¿El plot está atado a una identidad de granjero? ¿Y si rota claves?

**Sí, está atado, y rotar la clave pierde la elegibilidad: hay que replotear.** No es una
interpretación: está en la derivación de la tabla.

| Paso | Cita |
|---|---|
| `SectorId = blake3_keyed(public_key.hash(), [sector_index, history_size])` | `subspace-core-primitives/src/sectors.rs:56-68` |
| Al plotear, la semilla de cada pieza es `sector_id.derive_evaluation_seed(piece_offset)` | `subspace-farmer-components/src/plotting.rs:400` |
| `derive_evaluation_seed = blake3(sector_id ‖ piece_offset)` | `subspace-core-primitives/src/sectors.rs:126-130` |
| `SectorId` en el ploteo | `subspace-farmer-components/src/plotting.rs:252-256` |
| `SectorId` en la verificación | `subspace-verification/src/lib.rs:228-232` |
| La prueba de espacio se valida contra esa semilla | `subspace-verification/src/lib.rs:240-246` |

`public_key.hash()` no es un dato concatenado: es la **clave** de un blake3 con clave
(`blake3_hash_list_with_key`, `sectors.rs:61-67`). Cambiar la clave cambia el `SectorId` de forma no
correlacionada, y con él la semilla de evaluación de **todas** las piezas del sector. El contenido
físico de un sector plotado para K1 no sirve para K2: **relabelear es imposible; hay que replotear**
(misma conclusión que `research/dag-poas-balizas-auditoria.md:101-107`, re-verificada aquí).

Además el farm se niega a abrir con otra identidad: `IdentityMismatch`
(`single_disk_farm.rs:1311-1317`), y el scrubbing comprueba lo mismo (`1834-1849`). Para usar otra
clave hay que borrar/recrear el farm, es decir, replotear. **DEMOSTRADO.**

---

## 4 · Prueba pública de doble firma: ¿qué se podría invalidar? ¿Hay registro on-chain?

### 4.1 La prueba es posible y verificable

Dos firmas schnorrkel de la misma `solution.public_key` sobre dos mensajes distintos (dos hashes de
voto o dos pre-hashes de cabecera) se verifican con la misma primitiva que usa el nodo
(`check_reward_signature`, `subspace-verification/src/lib.rs:107-116`), con contexto
`REWARD_SIGNING_CONTEXT = b"subspace_reward"` (`subspace-core-primitives/src/lib.rs:36`). El
cliente incluso **construye** la prueba: `check_equivocation` detecta dos cabeceras de distinto
hash firmadas por el mismo firmante en el mismo slot dentro de `MAX_SLOT_CAPACITY = 1000` slots
(polkadot-sdk `client/consensus/slots/src/aux_schema.rs:50-68, 31`). DEMOSTRADO.

### 4.2 Qué hace hoy la cadena con esa prueba: casi nada

- **El cliente no la usa:** en `check_and_report_equivocation` el manejo es literalmente
  `// TODO: Handle equivocation` (`sc-consensus-subspace/src/verifier.rs:402`); solo se registra un
  `info!` (393-399).
- **El pallet tiene una regla estrecha, de un solo bloque.** En `check_vote`, la clave de
  equivocación es `(public_key, sector_index, piece_offset, chunk, slot)`
  (`pallet-subspace/src/lib.rs:1591-1597`) y solo se compara contra `ParentBlockVoters` y
  `CurrentBlockVoters` (`1603-1634`), que se rotan en cada bloque (`1049`, `878`). Si hay
  equivocación, el castigo es: `offender = solution.public_key` (`1657`), se revoca la recompensa
  del bloque actual (`1665`, `1678`) y se devuelve `Equivocated` (`1684`), que en el pool se traduce
  en `InvalidTransaction::BadSigner` (`1384`). **No hay ban de épocas ni revocación de
  elegibilidad.** DEMOSTRADO.
- Obsérvese además que la detección del pallet exige **la misma solución** (mismo `chunk`, mismo
  `piece_offset`, mismo `slot`); dos soluciones distintas de la misma clave en el mismo slot no se
  cruzan ahí. El chequeo del cliente sí es por firmante+slot (cabeceras distintas), pero no se
  reporta.

### 4.3 Registro on-chain: no existe para plots

- El único `StorageMap` de `pallet-subspace` es `SegmentCommitment` (`pallet-subspace/src/lib.rs:448`).
- `RootPlotPublicKey` es un `StorageValue` único de arranque (prohibición de autoría hasta abrirla
  al público): se pone en `375`, se lee en `533-538` y se borra en `623-625`.
- No hay storage de plots, sectores, ni identidades de granjero. El plot es un fichero local
  (`plot.bin` + `metadata.bin`, `single_disk_farm.rs:867-870`).

Lo único con registro on-chain y slashing es `pallet-domains` (operadores con `MinOperatorStake`,
`register_operator` en `pallet-domains/src/lib.rs:1532`, `do_slash_operator`), pero eso es
**stake/dinero** y no tiene relación con plots. Usarlo sería justo reintroducir el dinero en juego
que la variante quiere evitar.

### 4.4 Qué se podría invalidar, en la práctica

Con una prueba pública y un ban list nuevo (que hoy no existe), lo único invalidable es **una clave
en el futuro**: rechazar sus soluciones durante `E` épocas. No se puede invalidar el plot físico
(la cadena nunca lo ve), no se puede impedir que los mismos bytes se reploteen bajo otra clave, y
no se puede deshacer la equivocación ya emitida. **DEMOSTRADO** en cuanto al código;
**PLAUSIBLE** en cuanto a que un ban así disuada (depende de la economía del atacante, §6).

---

## 5 · Chia: farmer key vs pool key, plot NFT y coste de replot

### 5.1 El farmer key está horneado en el plot; el pool no

Formato del memo del plot v1 (`chia/plotting/util.py:221-262`):

```
pool_public_key (48 B) ‖ farmer_public_key (48 B) ‖ local_master_sk (32 B)      ← plot clásico
pool_contract_puzzle_hash (32 B) ‖ farmer_public_key (48 B) ‖ local_master_sk (32 B)  ← plot NFT
```

La clave pública del plot se deriva **incluyendo** la del farmer
(`chia/types/blockchain_format/proof_of_space.py:359-364`):

```python
def generate_plot_public_key(local_pk, farmer_pk, include_taproot=False):
    ...
    return local_pk + farmer_pk + taproot_sk.get_g1()   # con taproot
    return local_pk + farmer_pk                          # sin taproot
```

Y el plot ID se deriva de pool + plot public key
(`proof_of_space.py:339-350`: `std_hash(pool_public_key ‖ plot_public_key)` o
`std_hash(pool_contract_puzzle_hash ‖ plot_public_key)`). El quality string se calcula desde el
plot ID (`proof_of_space.py:177, 215`). Por tanto **cambiar el farmer key cambia el plot ID y el
plot deja de validar: replot obligatorio.**

El farmer firma con la clave privada que casa con el `farmer_pk` del plot y lo comprueba
explícitamente (`chia/farmer/farmer_api.py:321-333`: `assert agg_pk ==
new_proof_of_space.proof.plot_public_key`). El harvester recibe por handshake las farmer pk y pool
pk y su propio doc dice: *«We cannot use any plots which have different keys in them»*
(`chia/harvester/harvester_api.py:146-157`). **DEMOSTRADO.**

### 5.2 Lo que sí cambia sin replotear: pool y dirección de pago

- **Pool:** con plot NFT (pool contract), el plot referencia el `puzzle_hash` del singleton, no la
  pool. `chia plotnft join` cambia el pool objetivo con una transacción
  (`chia/cmds/plotnft_funcs.py:343-413`), sin tocar el plot.
- **Dirección de pago:** `chia plotnft change_payout_instructions`
  (`plotnft_funcs.py:461-475`) actualiza las instrucciones de pago de la pool; tampoco toca el plot.

Es el mismo patrón que Autonomys: la **identidad** está en el plot; el **destino del dinero** no.
DEMOSTRADO.

### 5.3 Coste de rehacer un plot (k32)

| Magnitud | Valor | Fuente |
|---|---:|---|
| Tamaño esperado k32 = `(2k+1)·2^(k-1)` | 130,0 GiB | `chia/consensus/pos_quality.py:11-23` |
| Factor UI a tamaño real | ×0,78 | `chia/consensus/pos_quality.py:8` |
| **Tamaño real k32** | **101,4 GiB** | 130,0 × 0,78 |
| Espacio temporal, modo bitfield | 238,3 GiB | `CHANGELOG.md:2830` |
| Espacio temporal, versión anterior | 313 GiB | `CHANGELOG.md:3569` |
| **Tiempo de ploteo k32** | **LAGUNA** | sin benchmark primario local; ya declarado en `research/chia-parcelas-comprimidas.md:97` |

**LAGUNA:** el tiempo de ploteo de Chia no está en la fuente local. Haría falta ejecutar
chiapos/bladebit sobre hardware conocido (o el benchmark oficial de Chia) y anotar hardware, `-b`,
`-r` y `-u`. Lo que sí está verificado es el tamaño y el espacio temporal, que acotan el IO:
~101,4 GiB escritos por plot final y ~238,3 GiB de temporal en el peor caso v1 por defecto.

---

## 6 · Conclusión: ¿coste real no esquivable, o evasión a coste cero?

### 6.1 Lo que cuesta de verdad evadir el castigo

El atacante **no puede re-clavar el plot** (§3), así que para conservar la elegibilidad de los
sectores baneados debe replotearlos. La pregunta es cuántos sectores puede permitirse que le
baneen. La respuesta la da la propia estructura:

1. **Crear identidades es gratis.** `Identity::create` genera 32 bytes aleatorios y escribe
   `identity.bin` (`identity.rs:117-132`). No hay registro on-chain (§4.3). Cero coste.
2. **Plotear escala con bytes, no con identidades.** El trabajo por sector es el mismo con
   cualquier clave; el `public_key` solo cambia las semillas (`plotting.rs:144-202, 400`). Repartir
   `S` bytes entre `N` claves cuesta exactamente lo mismo que plotear `S` bajo una sola. Esto ya
   está establecido y medido en `research/dag-poas-balizas-auditoria.md:190-202` («para nuevas
   incorporaciones el coste es cero»), y aquí se confirma en el código.
3. **Un sector puede producir varias soluciones ganadoras en el mismo slot** (todos los chunks del
   s-bucket auditado dentro del rango: `auditing.rs:237-271`, sin tope). El suelo teórico del
   espacio baneado por una equivocación es **un sector**; conservadoramente, `k` sectores para un
   quórum de `k` soluciones distintas.
4. **Replotear el espacio baneado** es el coste real. Medido por nosotros
   (`research/coste-ploteo-medido.md`, banco sobre `f8842d0`, sector ≈ 1 GiB):

| Replot de los sectores infractores | CPU 32 hilos | GTX 1070 | GPU tope 2026 (extrapolada) |
|---|---:|---:|---:|
| 1 sector (suelo) | 83,6 s | 69,4 s | 4,3–9,9 s |
| 64 sectores (`k=64`) | **89,2 min** | **74,0 min** | **4,6–10,6 min** |
| 256 sectores (`k=256`) | 5,9 h | 4,9 h | 18–42 min |

Fuentes: 83,608 s/sector y 12,055 MiB/s (`coste-ploteo-medido.md:20-24`); 69,363 s/sector y
14,531 MiB/s (`:189-196`); extrapolación 4,28–9,92 s (`:229-232`). **VERIFICADO** (medido por
nosotros en esta máquina; no es el hardware del atacante).

5. **Alternativa aún más barata: no replotear.** Si el atacante fragmenta en claves de un sector,
   el ban pierde `k` GiB de su espacio. Para un atacante con `α=0,33` de una red de 10 TiB, 64 GiB
   son el **1,9 %** de su espacio; en una red de 1 PiB, el **0,019 %**. Y si el castigo es «por `E`
   épocas», basta con esperar o cambiar de clave; el coste se reduce a las recompensas no cobradas
   de esos sectores durante `E` épocas.

### 6.2 Por qué no disuade

- El castigo es **ex post**: la equivocación ya se emitió y la ambigüedad de d12 §F.7 ya ocurrió.
  El castigo solo puede encarecer equivocaciones **futuras**, y lo hace en una cantidad que el
  atacante elige (hasta hacerla ~0 fragmentando).
- El espacio baneado no es el espacio total del atacante: es el de la clave que usó para las
  soluciones infractoras. Con una clave por sector, el castigo es de `k` sectores; con una clave
  para todo, sería de todo el espacio — pero fragmentar es gratis, así que el atacante racional no
  elige eso.
- No hay forma de atar el castigo al **espacio** en vez de a la **clave**: la cadena no ve el plot
  (no hay registro, §4.3), y los mismos bytes reploteados bajo otra clave son indistinguibles.

**REFUTADO** como regla que restaure la Definición 1 sin dinero en juego. El coste mínimo real de
evasión es el reploteo de los sectores infractores — suelo ~1 sector (83,6 s en CPU medida), `k`
sectores para un quórum `k` (64 GiB ≈ 89 min CPU / 74 min GTX 1070 / 4,6–10,6 min GPU tope 2026
extrapolada) — o **cero reploteo** si el atacante abandona esos sectores y asume una pérdida de
espacio de `k` GiB (≈1,9 % de su cuota en una red de 10 TiB).

---

## Tabla de hallazgos

| # | Hallazgo | Evidencia | Etiqueta |
|---|---|---|---|
| 1 | `verify_solution` no ve el valor votado; el reto sale del PoT y del slot | `subspace-verification/src/lib.rs:211-216, 234-236`; `pot.rs:278-280`; `subspace-core-primitives/src/lib.rs:110-112` | DEMOSTRADO |
| 2 | La firma de recompensa se verifica contra `solution.public_key`, que es la identidad del plot; la misma clave firma voto y cabecera | `pallet-subspace/src/lib.rs:1476-1484`; `sc-consensus-subspace/src/verifier.rs:339-348`; `identity.rs:149-152`; `reward_signing.rs:20-28` | DEMOSTRADO |
| 3 | La dirección de recompensa es independiente y cambiable sin replotear | `solutions.rs:257-258`; `commands/farm.rs:164-165, 293-304`; `single_disk_farm.rs:107-125`; `pallet-subspace/src/lib.rs:1748-1762` | DEMOSTRADO |
| 4 | El plot está atado a la clave: `SectorId` usa `public_key.hash()` como clave de un blake3 con clave y de él sale la semilla de evaluación | `sectors.rs:56-68, 126-130`; `plotting.rs:252-256, 400`; `subspace-verification/src/lib.rs:228-232, 240-246` | DEMOSTRADO |
| 5 | Rotar la clave invalida los sectores existentes; el farm ni siquiera abre con otra identidad | `single_disk_farm.rs:1311-1317, 1834-1849` | DEMOSTRADO |
| 6 | Crear una identidad nueva es gratis (32 bytes aleatorios, sin registro) | `identity.rs:117-132` | DEMOSTRADO |
| 7 | No hay registro on-chain de plots/identidades; el único mapa del pallet es `SegmentCommitment` y `RootPlotPublicKey` es un valor de arranque | `pallet-subspace/src/lib.rs:448, 533-538, 375, 623-625` | DEMOSTRADO |
| 8 | El pallet detecta equivocación solo en ventana padre+actual y solo revoca la recompensa del bloque; no hay ban de épocas | `pallet-subspace/src/lib.rs:1591-1634, 1656-1685, 1049, 878` | DEMOSTRADO |
| 9 | El cliente construye una prueba de equivocación (mismo firmante, mismo slot, cabeceras distintas, ≤1000 slots) pero **no la reporta**: `// TODO: Handle equivocation` | polkadot-sdk `aux_schema.rs:50-68, 31`; `sc-consensus-subspace/src/verifier.rs:366-408, 402` | DEMOSTRADO |
| 10 | Lo único con registro y slashing es `pallet-domains` (operadores con stake); no hay relación con plots | `pallet-domains/src/lib.rs:1532, 435`; `do_slash_operator` | DEMOSTRADO |
| 11 | Con prueba pública de doble firma solo se podría banear una clave futura; no el plot físico ni los mismos bytes bajo otra clave | `pallet-subspace/src/lib.rs:1657, 1665, 1678`; §4.3 | DEMOSTRADO (código) / PLAUSIBLE (efecto) |
| 12 | Chia: el farmer key está en el memo y en el plot public key/plot ID; no se cambia sin replotear | `chia/plotting/util.py:221-262`; `proof_of_space.py:339-364`; `farmer_api.py:321-333`; `harvester_api.py:146-157` | DEMOSTRADO |
| 13 | Chia: pool y dirección de pago sí cambian sin replotear (plot NFT) | `plotnft_funcs.py:343-413, 461-475` | DEMOSTRADO |
| 14 | Chia k32 = 101,4 GiB reales; temporal 238,3 GiB (bitfield) | `pos_quality.py:8, 11-23`; `CHANGELOG.md:2830` | VERIFICADO (cálculo y changelog) |
| 15 | Tiempo de ploteo de Chia k32 | — | LAGUNA |
| 16 | Replot medido de Autonomys: 83,6 s/GiB (CPU 32 hilos), 69,4 s/GiB (GTX 1070); GPU tope 2026 extrapolada 4,3–9,9 s/GiB | `research/coste-ploteo-medido.md:20-24, 189-196, 229-232` | VERIFICADO |
| 17 | Plotear escala con bytes, no con claves: fragmentar identidades no cuesta extra | `plotting.rs:144-202, 400`; `research/dag-poas-balizas-auditoria.md:190-202` | DEMOSTRADO |
| 18 | El espacio baneado por una equivocación puede reducirse a los sectores infractores; suelo ~1 sector (varios chunks ganadores por s-bucket) | `auditing.rs:237-271` | PLAUSIBLE (código sí; frecuencia depende del rango de solución) |
| 19 | El castigo de espacio es evadible a coste pequeño y no restaura la Def. 1 sin dinero en juego | §6 | REFUTADO (la afirmación «coste no esquivable») |
| 20 | El valor económico de romper la finalidad frente al coste de evasión | — | LAGUNA |

---

## Lagunas y qué haría falta

1. **Tiempo de ploteo de Chia (k32).** No hay benchmark primario en el checkout local.
   Haría falta medir con chiapos/bladebit/madmax sobre hardware declarado, o traer el benchmark
   oficial. Lo demás del coste (tamaño, temporal) sí está verificado.
2. **Cuántos sectores distintos producen las `k` soluciones de un quórum real.** El suelo de ~1
   sector es una posibilidad del código (varios chunks ganadores por s-bucket, `auditing.rs:237-271`),
   pero la frecuencia depende del `solution_range` y de la ventana de slots. Haría falta simular la
   distribución de ganadores por sector a la densidad de la red objetivo.
3. **Valor de la equivocación.** No se cuantifica aquí cuánto vale romper la finalidad; sin ese
   número no se puede decidir si 89 min de CPU disuaden o no. Es un dato de economía del atacante,
   no de código.
4. **Claves compartidas.** No se analiza qué pasa si varias farms copian el mismo `identity.bin`:
   un ban por clave golpearía a todas, lo que podría ser deseable (pool) o un vector de griefing
   (clave filtrada). Queda fuera del encargo.

---

## Errores propios y correcciones

- Empecé comprobando si existía una «clave de recompensa» separada de la identidad del plot (por
  analogía con Chia). **No existe**: `sign_reward_hash` y el `SectorId` usan el mismo keypair
  (`identity.rs:149-152`; `sectors.rs:56-68`). Lo dejo escrito para que nadie repita la búsqueda.
- El pallet **sí** tiene una regla anti-equivocación (`check_vote`), y eso podría leerse como que el
  castigo ya existe. Es una ventana de un bloque y solo revoca la recompensa de ese bloque; no es
  un castigo de espacio ni persistente. Queda acotado en §4.2.
- La detección del pallet está indexada por la **misma solución** (`chunk` incluido), no por clave:
  dos soluciones distintas de la misma clave en el mismo slot no se cruzan ahí. Corregido en §4.2.
