# ZEROX — Especificación del protocolo

> **ESTADO: DRAFT v0 — NO IMPLEMENTAR TODAVÍA.**
> Cierra la Fase 0. Pendiente de revisión humana antes de escribir código de consenso.
> Última revisión: 2026-09-04.
>
> Alcance de este documento: **ZZK v1.0, capa transparente**. El pool blindado (v1.1, Fase 6)
> tiene secciones reservadas con punteros a la investigación, no reglas normativas todavía.
>
> Decisiones de arquitectura y su justificación: `../DECISIONES.md`.
> Preguntas abiertas: `../PREGUNTAS-PARA-KATANA.md`.
> Evidencia de cada sección: `research/*.md`.

---

## 0 · Cómo leer este documento

### 0.1 · Lenguaje normativo

Las palabras **MUST**, **MUST NOT**, **SHOULD** y **MAY** se usan como en RFC 2119.
Una regla marcada **MUST** es regla de consenso: un nodo que no la aplique **acepta o rechaza
bloques de forma distinta al resto de la red, y produce un split de cadena**.

### 0.2 · Numeración de reglas

Cada regla de consenso lleva un identificador estable `C-<ÁREA>-<NN>`. El código que la implementa
**MUST** citar ese identificador en un comentario. Áreas:

| Prefijo | Área |
|---|---|
| `C-ENC` | Codificación y serialización canónica |
| `C-HASH` | Funciones hash y separación de dominio |
| `C-HDR` | Cabecera de bloque |
| `C-TX` | Formato y validez de transacción |
| `C-SIG` | Firmas |
| `C-POW` | Prueba de trabajo |
| `C-DIFF` | Ajuste de dificultad |
| `C-TS` | Timestamps |
| `C-EMIT` | Emisión y coinbase |
| `C-BLK` | Validez de bloque |

### 0.3 · Marcadores de pendiente

`<<PENDIENTE: P-00N>>` señala un valor o regla que **todavía no está decidido** y remite a la
entrada correspondiente de `../PREGUNTAS-PARA-KATANA.md`. **Ninguna implementación puede fijar
esos valores por su cuenta.**

### 0.4 · Qué NO es este documento

No es la serialización de wire ni de almacenamiento — eso es Cap'n Proto y **no es
consensus-critical** (§2.4). Este documento define **qué se hashea y qué se firma**, que es
cosa distinta y sí lo es.

---

## 1 · Identidad y unidades

| | |
|---|---|
| Nombre | ZEROX |
| Ticker | **ZZK** |
| Unidad atómica | **brek** |
| Decimales | **8** — `1 ZZK = 100 000 000 brek` |

**C-ENC-01** · Todo importe en el protocolo se expresa y se codifica en **brek**, nunca en ZZK.
Las conversiones a ZZK son exclusivamente de presentación.

### 1.1 · Escalera de unidades de presentación — convención del ecosistema, NO regla de consenso

> Esta sección **no es normativa para el consenso**. Ningún nodo valida nada de aquí. Es la
> convención obligatoria para todo software del ecosistema ZEROX (wallet, Cortex, exploradores,
> RPC de cara al usuario), y existe para que no se repita el desastre de BTC/mBTC/bits/sats: ese
> problema no nació de que fuera difícil, sino de que miles de carteras independientes eligieron
> convenciones distintas y nadie pudo imponer una. ZEROX controla su stack completo; aquí se fija.

| Unidad | Valor | Cuándo se usa |
|---|---|---|
| `MZZK` | 10⁶ ZZK | cantidad ≥ 1 000 000 ZZK |
| `kZZK` | 10³ ZZK | cantidad ≥ 1 000 ZZK |
| `ZZK` | 1 ZZK = 10⁸ brek | cantidad ≥ 1 ZZK |
| `brek` | 10⁻⁸ ZZK | cantidad < 1 ZZK |

```
elegir_unidad(cantidad_en_ZZK):
    si cantidad ≥ 1 000 000  → MZZK
    si cantidad ≥ 1 000      → kZZK
    si cantidad ≥ 1          → ZZK
    si no                    → brek
```

**Reglas de uso:**

1. **Una sola unidad por pantalla.** El fallo de UX no es el prefijo, es mezclar dos prefijos en la
   misma vista. Si una lista contiene importes de magnitudes distintas, se elige la unidad por el
   importe mayor y se aplica a todos.
2. **Cortex cotiza en moneda fiat y liquida en ZZK.** El comprador ve "12 €"; el importe en ZZK es
   un detalle de la transacción, no el precio. Esto disuelve la mayor parte del problema sin tocar
   el protocolo.
3. **Nunca redondear a la baja un importe a pagar.** La presentación puede truncar dígitos; el
   importe firmado es siempre el valor exacto en brek.

> **Por qué existe esta escalera.** El precio unitario es `capitalización / suministro`, y la
> capitalización no se controla: la magnitud que ve el comprador deriva por fuerza. A nivel de
> protocolo es **inevitable** — las únicas soluciones conocidas (rebase estilo Ampleforth, pegs
> algorítmicos) requieren un **oráculo de precio**, es decir un tercero de confianza dentro del
> consenso, que es justo lo que ZEROX existe para no tener. A nivel de presentación, en cambio, es
> el mismo problema que "1,2 GB" en lugar de "1 288 490 188 bytes": resuelto con prefijos.
> La mitigación de protocolo ya está aplicada en la elección de `SOFT_CAP` (§8.1).

---

## 2 · Notación, tipos y codificación canónica

### 2.1 · Enteros

**C-ENC-02** · Todos los enteros de longitud fija se codifican en **little-endian**, sin excepción.

| Tipo | Bytes | Rango |
|---|---|---|
| `u8` | 1 | `[0, 2⁸)` |
| `u16` | 2 | `[0, 2¹⁶)` |
| `u32` | 4 | `[0, 2³²)` |
| `u64` | 8 | `[0, 2⁶⁴)` |
| `i64` | 8 | `[−2⁶³, 2⁶³)`, complemento a dos |
| `u256` | 32 | `[0, 2²⁵⁶)` |

**C-ENC-03** · Toda aritmética de consenso **MUST** usar operaciones con comprobación explícita
de desbordamiento (`checked_*` o tipos de ancho suficiente). Está **prohibido** el desbordamiento
silencioso. Rust hace *wrapping* en perfil `release` y *panic* en `debug`: dos nodos, dos
resultados. Ver `research/lwma1.md` §No-determinismo.

**C-ENC-04** · Está **prohibido** el uso de coma flotante (`f32`, `f64`) en cualquier ruta de
consenso. La CI **MUST** fallar si aparece en `zx-core`, `zx-consensus` o `zx-storage`.

### 2.2 · `CompactSize`

Codificación de longitud variable para contadores y longitudes.

| Valor | Codificación |
|---|---|
| `< 0xFD` | 1 byte: el valor |
| `≤ 0xFFFF` | `0xFD` + `u16` |
| `≤ 0xFFFF_FFFF` | `0xFE` + `u32` |
| resto | `0xFF` + `u64` |

**C-ENC-05** · Un `CompactSize` **MUST** usar la codificación **mínima** posible para su valor.
Las codificaciones no mínimas **MUST** rechazarse.

> *Motivación (verificada):* FIPS/Zcash documentan el ataque concreto — sin esta regla un minero
> puede probar varias codificaciones distintas del mismo objeto contra el filtro de dificultad,
> en vez de solo la codificación intencionada. Ver `research/zip244.md` §8.

### 2.3 · Direcciones — bech32

**C-ENC-06** · Las direcciones se codifican en **bech32** (BIP-173) con estos HRP:

| HRP | Red y pool |
|---|---|
| `zzk` | mainnet, transparente |
| `zzs` | mainnet, blindada *(reservado, v1.1)* |
| `tzzk` | testnet, transparente |

**C-ENC-07** · Una dirección transparente codifica `SHA3-256(pubkey)` **completo, 32 bytes**.
**MUST NOT** truncarse.

> Decidido 2026-09-04. 20 bytes (estilo Bitcoin) dan 80 bits de resistencia a colisiones,
> insuficiente para una cadena que nace en 2026. El coste son 12 bytes por salida y ~17 caracteres
> más en la representación bech32 — irrelevante para un QR de checkout. Elimina una clase entera
> de análisis de seguridad.

### 2.4 · Serialización de wire vs preimagen de hashing

**C-ENC-08** · La serialización de wire y almacenamiento (Cap'n Proto) **NO es
consensus-critical**. Lo que se hashea y se firma es la **preimagen canónica** definida en §4,
que es una codificación propia, byte-exacta, independiente de Cap'n Proto.

> *Motivación (verificada):* el modo canónico de Cap'n Proto no garantiza bytes idénticos entre
> implementaciones distintas — la spec no define orden para campos de datos no-puntero, y no
> existe ningún conjunto de vectores de prueba compartido entre las implementaciones de C++, Rust
> y Go. Cosmos SDK (ADR-027), Diem/Aptos/Sui (BCS) y Zcash (ZIP-244) llegaron independientemente
> a la misma conclusión. Ver `research/capnproto-canon.md`.

**C-ENC-09** · El parser **MUST** rechazar cualquier codificación de wire que no sea la única
codificación aceptada para ese valor lógico. La unicidad del *valor lógico* la da el digest; la
unicidad de los *bytes* la tiene que dar el parser.

---

## 3 · Función hash

### 3.1 · La función de consenso

**C-HASH-01** · La función hash de consenso de ZEROX es **SHA3-256 tal como la define FIPS 202**,
es decir `KECCAK[512](M ‖ 01, 256)`:

- Permutación `KECCAK-p[1600, 24]`
- Rate `r = 1088` bits = **136 bytes**; capacity `c = 512` bits
- **Sufijo de separación de dominio `01`** → primer byte de padding **`0x06`**
- `pad10*1`, con el último bit en el byte `rate−1` → **`0x80`**
- Lanes de 64 bits empaquetados en **little-endian**, orden `i = x + 5y`

> ✅ **P-001 RESUELTO (2026-09-04): SHA3-256 FIPS 202.** Motivo decisivo: es la única de las dos
> opciones con una suite de vectores oficiales del NIST (860 CAVP) para validar en CI, y toda la
> metodología del proyecto se apoya en verificar contra fuentes autoritativas.
> Keccak-256 difiere en **exactamente un byte** de dominio (`0x01` vs `0x06`) y produce digests **no
> relacionados**. `SHA3-256("")` = `a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a`;
> `Keccak-256("")` = `c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470`.
> Esta especificación asume **SHA3-256 FIPS 202**, que es además la opción de menor trabajo
> (la ruta CPU actual ya lo es y pasa 860/860 vectores CAVP). Ver `research/sha3-fips202.md`.

**C-HASH-02** · Toda implementación de `SHA3-256` usada en consenso **MUST** validarse contra los
**860 vectores CAVP del NIST** (`sha-3bytetestvectors.zip`), incluidos los Monte Carlo. La CI
**MUST** fallar ante un solo mismatch.

> ⚠️ Trampa documentada: `KeccakKAT-3.zip/ShortMsgKAT_256.txt` (Keccak, `0x01`) y
> `XKCP/ShortMsgKAT_SHA3-256.txt` (SHA-3, `0x06`) tienen nombres casi idénticos y contenidos
> **incompatibles**. Usar el fichero equivocado produce un kernel que pasa sus tests y rompe el
> consenso. Ver `research/sha3-referencias.md`.

**C-HASH-03** · La ruta de verificación (CPU) y la ruta de minado (GPU) **MUST** producir digests
idénticos bit a bit para toda entrada. Un test de paridad cruzada **MUST** existir en CI.

> El kernel actual de `caliza` **no cumple C-HASH-01**: no implementa padding ni separación de
> dominio; es `KECCAK-p[1600,24]` crudo. 0 de 860 vectores CAVP. Ver `research/sha3-kernel-audit.md`.
> Remedio: portar la esponja de `XKCP/Standalone/CompactFIPS202`. Fase 8.

### 3.2 · Separación de dominio

ZEROX usa una sola función hash en consenso. A diferencia de BLAKE2b (que tiene un campo de
personalización en el *parameter block*), SHA3-256 no lo tiene, así que la separación de dominio
se hace con **prefijo explícito de longitud fija**.

**C-HASH-04** · Un *hash con dominio* se define como:

```
H_d(tag, m) := SHA3-256( tag ‖ m )
```

donde `tag` es una cadena ASCII de **exactamente 16 bytes**, rellenada a la derecha con `_`
(`0x5F`) si es más corta. La longitud fija es lo que hace inyectiva la construcción: con
etiquetas de longitud variable, `tag₁ ‖ m₁` podría coincidir con `tag₂ ‖ m₂`.

**C-HASH-05** · Toda etiqueta de dominio usada en esta especificación **MUST** aparecer en la
tabla de §4.5. Añadir una etiqueta nueva es un cambio de consenso.

> *Nota de diseño para D8/D9:* Zcash usa el campo de personalización de BLAKE2b, que se XORea
> contra el IV y por tanto no puede confundirse con contenido del mensaje. El prefijo de longitud
> fija logra la misma propiedad de inyectividad siempre que (a) las etiquetas midan exactamente
> 16 bytes y (b) el contenido de cada dominio sea, a su vez, inequívoco (longitud fija o
> prefijada). Ambas condiciones se cumplen aquí. **Marcado para revisión adversarial.**

---

## 4 · Preimagen canónica: txid y sighash

Diseño derivado del patrón de **ZIP-244** (`research/zip244.md`), adaptado: un solo pool
(transparente) en v1, y SHA3-256 con prefijo de dominio en vez de BLAKE2b personalizado.

### 4.1 · Principio: datos de efecto vs datos de autorización

**C-TX-01** · El **txid** se calcula **exclusivamente sobre los datos de efecto** de la
transacción: qué entradas consume, qué salidas crea, y sus metadatos. **NO** incluye firmas.

> *Motivación:* hace el txid **no maleable**. Un tercero no puede cambiar el identificador de una
> transacción alterando su firma. Esto es lo que permite construir una transacción B que gasta
> salidas de A **antes de que A esté minada** — necesario para HTLC y canales de pago.

**C-TX-02** · El **auth digest** compromete los datos de autorización (las firmas). El par
`(txid, auth_digest)` compromete la transacción serializada completa.

**C-TX-03** · El identificador de red de una transacción (`wtxid`) es `txid ‖ auth_digest`,
64 bytes.

### 4.2 · Árbol del txid

```
txid = H_d("ZZKTxIdHash_" ‖ CBID, header_digest ‖ inputs_digest ‖ outputs_digest)

  header_digest  = H_d("ZZKTxIdHeader___", version ‖ lock_time ‖ expiry_height)
  inputs_digest  = H_d("ZZKTxIdInputs___", prevouts_digest ‖ sequence_digest)
    prevouts_digest = H_d("ZZKTxIdPrevout__", ⋃ᵢ (txid_i ‖ index_i))       36 B por entrada
    sequence_digest = H_d("ZZKTxIdSequence_", ⋃ᵢ sequence_i)                4 B por entrada
  outputs_digest = H_d("ZZKTxIdOutputs__", ⋃ⱼ output_encoding_j)
```

**C-TX-04** · Un sub-digest cuyo conjunto de elementos esté **vacío** se calcula como
`H_d(tag, ⟨⟩)` — el hash con dominio de la cadena vacía. **MUST NOT** sustituirse por ceros.

> *Motivación (verificada):* ZIP-143/243 usaban `uint256(0)` para campos ausentes, con lo que
> "campo ausente" y "campo cuyo hash dio cero" son indistinguibles y **todos los campos ausentes
> colisionan entre sí**. El hash con dominio del vacío da a cada bucket un valor distinto e
> inalcanzable por contenido real.

**C-TX-05** · Los elementos de cada sub-digest se concatenan **en el orden de su índice en la
transacción**. No hay ordenación alternativa.

### 4.3 · Árbol del sighash

**C-SIG-01** · El `signature_digest` de la entrada `k` es idéntico al `txid` salvo que
`inputs_digest` se sustituye por `inputs_sig_digest`:

```
signature_digest(k) = H_d("ZZKTxIdHash_" ‖ CBID, header_digest ‖ inputs_sig_digest(k) ‖ outputs_digest)
```

**Misma etiqueta de dominio en la raíz que el txid** — a propósito: para una transacción sin
entradas transparentes, `sighash == txid`. Se separan por longitud del contenido, que es
siempre 96 bytes.

> 🔶 **C-SIG-01b · El `outputs_digest` de la raíz es el MODULADO.** Detectado 2026-09-04 al
> implementar. Leída al pie de la letra, la frase "idéntico al txid salvo que `inputs_digest` se
> sustituye" dejaría en la raíz el `outputs_digest` **sin modular**, es decir, el de todas las
> salidas. Con esa lectura, **`SIGHASH_NONE` y `SIGHASH_SINGLE` no harían nada**: la firma seguiría
> comprometiendo todas las salidas por la rama de la raíz, y la tabla de C-SIG-05 sería letra
> muerta.
>
> Por tanto el `outputs_digest` de la raíz **MUST** ser el modulado por `hash_type`, el mismo que
> entra en `inputs_sig_digest`. Bajo `SIGHASH_ALL` —el caso normal— ambas lecturas coinciden byte a
> byte, así que la corrección no afecta al camino habitual.
>
> Implementado así en `zx-core`. **Pendiente de confirmación humana → P-021.**

```
inputs_sig_digest(k) = H_d("ZZKTxIdInputs___",
      hash_type(1) ‖ prevouts_digest(32) ‖ amounts_digest(32) ‖
      scripts_digest(32) ‖ sequence_digest(32) ‖ outputs_digest(32) ‖ this_input_digest(32) )
```

| Componente | Contenido |
|---|---|
| `amounts_digest` | `H_d("ZZKTxSigAmounts_", ⋃ᵢ value_i)` — los importes de **las salidas gastadas**, `i64` LE |
| `scripts_digest` | `H_d("ZZKTxSigLocks___", ⋃ᵢ lock_encoding_i)` — las condiciones de bloqueo de las salidas gastadas |
| `this_input_digest` | `H_d("ZZKTxSigThisIn__", prevout(36) ‖ value(8) ‖ lock_encoding ‖ sequence(4))` |

**C-SIG-02** · `amounts_digest` y `scripts_digest` existen para que un firmante *offline* pueda
verificar el fee real y saber qué entradas le pertenecen sin recibir las transacciones previas
completas. **MUST** incluirse aunque el firmante sea online.

**C-SIG-03** · El `hash_type` es **1 byte** y **MUST** ser uno de:

| Valor | Nombre |
|---|---|
| `0x01` | `SIGHASH_ALL` |
| `0x02` | `SIGHASH_NONE` |
| `0x03` | `SIGHASH_SINGLE` |
| `0x81` | `SIGHASH_ALL \| ANYONECANPAY` |
| `0x82` | `SIGHASH_NONE \| ANYONECANPAY` |
| `0x83` | `SIGHASH_SINGLE \| ANYONECANPAY` |

Cualquier otro valor **MUST** causar fallo de validación. Los bits no definidos **MUST NOT**
ignorarse.

**C-SIG-04** · Usar `SIGHASH_SINGLE` sin una salida correspondiente (una salida con el mismo
índice que la entrada firmada) **MUST** causar fallo de validación.

> Sin esta regla, esas entradas usan de facto `SIGHASH_NONE` de forma silenciosa y engañosa.

**C-SIG-05** · Modulación por `hash_type`:

| Componente | `!ANYONECANPAY` | `ANYONECANPAY` |
|---|---|---|
| `prevouts_digest` | todas las entradas | hash con dominio del vacío |
| `amounts_digest` | todas las entradas | hash con dominio del vacío |
| `scripts_digest` | todas las entradas | hash con dominio del vacío |
| `sequence_digest` | todas las entradas, **incluso con SINGLE o NONE** | hash con dominio del vacío |

| Componente | ni SINGLE ni NONE | SINGLE | NONE |
|---|---|---|---|
| `outputs_digest` | todas las salidas | solo la salida del índice de la entrada | hash con dominio del vacío |

### 4.4 · Auth digest

```
auth_digest = H_d("ZZKTxAuthHash___", ⋃ᵢ witness_encoding_i)
```

**C-TX-06** · `witness_encoding` de una entrada es `CompactSize(len) ‖ witness_bytes`. El
contenido depende del tipo de salida gastada (§5.3).

### 4.5 · Tabla de etiquetas de dominio

**C-HASH-06** · Estas son **todas** las etiquetas de dominio de ZEROX v1.0. Cada una mide
exactamente 16 bytes.

> La raíz del txid/sighash es la excepción a "ASCII puro": son 12 bytes ASCII seguidos del
> `CONSENSUS_BRANCH_ID` en `u32` little-endian. Es el mecanismo de **protección de repetición entre
> ramas de consenso** (§14), copiado de ZIP-244 — que hace exactamente lo mismo con
> `ZcashTxHash_` ‖ CBID dentro de la personalización BLAKE2b. Una firma válida en una rama es
> inválida en otra, por construcción.

| Etiqueta | Uso |
|---|---|
| `ZZKTxIdHash_` ‖ `CBID` | Raíz del txid y del sighash. **12 bytes ASCII + `CONSENSUS_BRANCH_ID` como `u32` LE** (§14). Es la única etiqueta que no es ASCII puro |
| `ZZKTxIdHeader___` | §4.2 header |
| `ZZKTxIdInputs___` | §4.2 entradas y §4.3 entradas-para-firma |
| `ZZKTxIdPrevout__` | §4.2 outpoints |
| `ZZKTxIdSequence_` | §4.2 nSequence |
| `ZZKTxIdOutputs__` | §4.2 salidas |
| `ZZKTxSigAmounts_` | §4.3 importes gastados |
| `ZZKTxSigLocks___` | §4.3 condiciones de bloqueo gastadas |
| `ZZKTxSigThisIn__` | §4.3 la entrada que se firma |
| `ZZKTxAuthHash___` | §4.4 auth digest |
| `ZZKBlkMerkle____` | §6.3 árbol de Merkle de transacciones |
| `ZZKBlkHeader____` | §6.2 hash de cabecera (PoW) |

---

## 5 · Transacciones

### 5.1 · Estructura

| Campo | Tipo | Notas |
|---|---|---|
| `version` | `u32` | **MUST** ser `1` en v1.0 |
| `inputs` | `TxIn[]` | |
| `outputs` | `TxOut[]` | |
| `lock_time` | `u32` | altura o timestamp antes del cual la tx no es válida |
| `expiry_height` | `u32` | altura tras la cual la tx deja de ser válida; `0` = sin expiración |

**C-TX-07** · El campo `version` **MUST** validarse contra el conjunto de versiones activas a la
altura del bloque. Versiones desconocidas **MUST** rechazarse.

> Este campo es el gancho de extensión: el pool blindado (v1.1) y cualquier lenguaje de script
> futuro entran como **versiones nuevas activadas por altura**, sin invalidar lo anterior.

**C-TX-08** · Si `expiry_height ≠ 0`, la transacción **MUST** rechazarse en bloques de altura
`> expiry_height`.

### 5.2 · Entradas

| Campo | Tipo | Bytes |
|---|---|---|
| `prev_txid` | `u256` | 32 |
| `prev_index` | `u32` | 4 |
| `sequence` | `u32` | 4 |

La autorización (firma) **no** forma parte de la entrada a efectos de txid — va en el testigo
(§4.4).

### 5.3 · Salidas — conjunto cerrado de tipos

**C-TX-09** · Una salida es `value: i64 (brek) ‖ lock: Lock`. `Lock` es un **enum etiquetado
cerrado**. No hay lenguaje de script en v1.0.

```
Lock ::= 0x00 PubKey  { pubkey_hash: [u8; L] }
       | 0x01 MultiSig{ k: u8, pubkey_hashes: [[u8; L]] }
       | 0x02 Htlc    { hash: [u8;32], receiver: [u8;L], sender: [u8;L], timeout: u32 }
```

| Tipo | Condición de gasto |
|---|---|
| `PubKey` | Firma válida de la clave cuyo hash coincide |
| `MultiSig` | `k` firmas válidas de `k` claves distintas del conjunto |
| `Htlc` | *(a)* preimagen `p` con `SHA3-256(p) = hash` **y** firma de `receiver`; o *(b)* altura del bloque `≥ timeout` **y** firma de `sender` |

**C-TX-09b · Codificación canónica de `Lock`.** Un `Lock` se codifica como
`discriminante(1) ‖ campos`, con los campos en el orden de la declaración de arriba. La lista de
`MultiSig` va precedida de su longitud en `CompactSize`:

```
PubKey   := 0x00 ‖ pubkey_hash(32)
MultiSig := 0x01 ‖ k(1) ‖ CompactSize(n) ‖ pubkey_hash₀(32) ‖ … ‖ pubkey_hashₙ₋₁(32)
Htlc     := 0x02 ‖ hash(32) ‖ receiver(32) ‖ sender(32) ‖ timeout(4 LE)
```

> Añadido 2026-09-04 al implementar §4. El SPEC definía la estructura de `Lock` pero no la
> codificación de la lista de `MultiSig`, y eso **no puede quedar implícito**: `scripts_digest`
> (§4.3) concatena varios locks seguidos, así que sin un delimitador de longitud dos secuencias
> distintas de locks podrían producir los mismos bytes y por tanto el mismo digest. `CompactSize` es
> la única lectura coherente con §2.2, que lo define justamente para "contadores y longitudes", y
> su minimalidad ya está cubierta por C-ENC-05.

**C-TX-10** · El byte discriminante **MUST** estar en el conjunto definido. Valores desconocidos
**MUST** rechazarse (no tratarse como "gastable por cualquiera").

**C-TX-11** · En `MultiSig`, `1 ≤ k ≤ n` donde `n = len(pubkey_hashes)`, y
`n ≤ MAX_MULTISIG_KEYS = 16`. Las claves **MUST** ser distintas entre sí.

**C-TX-12** · `value` **MUST** estar en `[0, ZX_VALUE_SANITY_LIMIT]`, con

```
ZX_VALUE_SANITY_LIMIT = 2^62 brek = 4 611 686 018 427 387 904 brek ≈ 46 117 M ZZK
```

> Decidido 2026-09-04 (P-010). ZEROX **no tiene** un `MAX_MONEY` fijo — la tail emission hace el
> suministro no acotado —, así que no puede copiar literalmente las reglas de saneamiento de Zcash.
> `2^62` es una cota de cordura desacoplada de la emisión real: partiendo de 1000 M ZZK y creciendo
> 8 409 600 ZZK/año, el suministro tardaría **~5 365 años** en acercarse. Su función es acotar la
> aritmética, no la economía.

### 5.4 · Validez

**C-TX-13** · Toda entrada **MUST** referenciar una salida que exista en el UTXO set y no esté
gastada.

**C-TX-14** · `Σ value(entradas) ≥ Σ value(salidas)`. La diferencia es el **fee**.

**C-TX-15 · No existe tarifa mínima de consenso.** Un bloque **MUST NOT** rechazarse por contener
una transacción cuyo fee sea bajo, o incluso cero. El fee mínimo es **política de retransmisión y
de mempool** (§5.5), nunca condición de validez de bloque.

> ⚠️ **Corregido 2026-09-04.** Este documento afirmaba antes lo contrario. La investigación
> (`research/dynamic-fee.md` §0) demuestra que en Monero la comprobación se **omite por completo**
> cuando la transacción llega dentro de un bloque ya minado
> (`tx_pool.cpp:137-166`: `fee_good = kept_by_block || check_fee(...)`), y que Cuprate la ubica
> deliberadamente fuera del crate `consensus/`. UkoeHB lo enuncia así en `research-lab#70`:
> *"it is network consensus, not protocol consensus, to enforce the minimum fee"*.
>
> Convertirlo en consenso habría traído tres males: un minero no podría incluir transacciones
> gratuitas ni propias; cambiar la política de tarifas exigiría un **hard fork**; y aparece una
> circularidad, porque la tarifa depende de la mediana y la mediana de los bloques.
>
> El antispam a nivel de consenso ya está cubierto por otra vía, que es donde debe estar: la
> penalización cuadrática (C-EMIT-06), el límite duro de bloque (C-WGT-09) y el tope por
> transacción (C-WGT-11).

**C-TX-16** · Una transacción **MUST NOT** gastar dos veces el mismo outpoint, ni siquiera dentro
de sí misma.

**C-TX-17** · Una transacción **MUST** tener al menos una entrada y al menos una salida, salvo la
coinbase (§8), que no tiene entradas.

**C-TX-18** · `weight(tx)` **MUST** ser `≤ MAX_TX_WEIGHT`. Ver C-WGT-11 (§6.5) para la definición
y el razonamiento.

### 5.5 · Tarifa mínima — política de retransmisión, NO consenso

> Esta sección **no es normativa para el consenso**. Ningún bloque se invalida por incumplirla.
> Es la política por defecto del nodo de referencia para admitir una transacción en su mempool y
> retransmitirla. Un nodo puede relajarla; la red converge por interés propio, no por regla.

#### La fórmula

```
Mf(H)            = mediana de referencia para tarifas (ver más abajo)
F(H)             = recompensa_base(H) · REF_WEIGHT / Mf(H) / Mf(H)      // dos divisiones enteras
tarifa_por_byte  = max(1, F − F/20)                                      // el "0,95×", en entero
tarifa_minima(tx)= redondear_arriba( weight(tx) · tarifa_por_byte, FEE_MASK )
aceptar si         fee ≥ tarifa_minima − tarifa_minima/50                // colchón del 2 %

REF_WEIGHT = 3000        // bytes de weight — transacción de referencia
FEE_MASK   = 10 000      // brek — cuantización de la tarifa
```

Requisitos de implementación, tomados del código de referencia:
- Aritmética de **128 bits**: `recompensa_base × REF_WEIGHT` desborda `u64`.
- **Dos divisiones enteras sucesivas** por `Mf`, no una división por `Mf²`.
- El `0,95×` es `F − F/20` en entero, nunca coma flotante.
- La cuantización redondea **hacia arriba**: `(f + MASK − 1) / MASK * MASK`. Existe para que la
  tarifa no funcione como huella identificatoria del momento de construcción de la transacción.
- El resultado nunca es 0.

#### 🔶 Divergencia propuesta frente a Monero — `Mf` es la mediana LARGA, no `min(corta, larga)`

Monero usa `Mf = min(M(H), Mlt(H))`. Como `tarifa ∝ 1/Mf²`, tomar el mínimo equivale a tomar la
mediana que produce la **tarifa más alta** — y ahí nace el *fee cliff*: cuando la mediana corta se
desploma tras un pico, la tarifa mínima **salta hacia arriba de golpe** y deja varadas las
transacciones ya firmadas. `monero-project/research-lab#70` sigue **abierto** a fecha de esta
investigación.

Para un checkout eso es el peor fallo posible: el comprador ve "pago pendiente" y abandona.

**Propuesta para ZEROX: `Mf(H) = Mlt(H)`** — anclar la tarifa mínima **solo** a la mediana de largo
plazo. Como `Mlt` está acotada a `[Mlt·10/17, Mlt·17/10]` por bloque (C-WGT-04), la tarifa mínima
resulta **suave en ambas direcciones por construcción**, que es justo lo que Monero no tiene.

Contrapartida asumida: la tarifa mínima deja de reaccionar a la congestión de corto plazo. Se
acepta a conciencia — el racionamiento del espacio ya lo hacen el límite duro y la penalización, y
para un marketplace **la predictibilidad vale más que la eficiencia del racionamiento**. El mercado
de prioridades sigue existiendo por encima del mínimo.

> ⚠️ **Esta divergencia es una propuesta razonada, no un resultado verificado.** Requiere revisión
> adversarial de **D8** y **D2** antes de darse por buena: en concreto, si anclar solo a `Mlt`
> abarata el spam durante el periodo en que `Mlt` es alta y la demanda real ha colapsado.

#### Calibración pendiente

Con `REF_WEIGHT = 3000`, `Mf = ZONA_LIBRE = 100 000` y `recompensa_base = 32 ZZK` (régimen de cola),
sale `tarifa_por_byte ≈ 912` brek, de modo que una transacción transparente típica de ~350 B paga
≈ **0,0032 ZZK**, y sostener 100 KB/bloque de spam cuesta ≈ **656 ZZK/día**.

`REF_WEIGHT = 3000` es el valor de Monero, adoptado como punto de partida por ser el único
precedente en producción. **Su calibración para ZEROX requiere un modelo de coste de atacante
explícito** — encargo abierto para **D2** y **D8**, no una constante cerrada.

---

## 6 · Bloques

### 6.1 · Cabecera

| Campo | Tipo | Bytes | Notas |
|---|---|---|---|
| `consensus_branch_id` | `u32` | 4 | identificador de rama de consenso, §14 |
| `prev_hash` | `u256` | 32 | hash de la cabecera del padre |
| `merkle_root` | `u256` | 32 | §6.3 |
| `timestamp` | `u64` | 8 | segundos Unix |
| `bits` | `u32` | 4 | target compacto, §7.2 |
| `nonce` | `u64` | 8 | |
| `height` | `u32` | 4 | altura del bloque |
| **Total** | | **92** | con `timestamp: u64` |

**C-HDR-01** · La cabecera tiene tamaño **fijo**. Su codificación es la concatenación de los
campos en el orden de la tabla, cada uno en little-endian.

**C-HDR-02** · `height` **MUST** ser `height(padre) + 1`. El génesis tiene `height = 0`.

**C-HDR-02b** · `consensus_branch_id` **MUST** ser exactamente el identificador de rama activo a la
altura del bloque, según la tabla de C-UPG-02. Cualquier otro valor **MUST** rechazarse. No existe
un campo de "versión de bloque" separado: la rama de consenso *es* la versión.

> Incluir la altura en la cabecera hace que el hash de cabecera dependa de ella, lo que simplifica
> C-EMIT-04 (unicidad de txid de coinbase) y elimina una clase de ambigüedad en reorgs.

### 6.2 · Hash de cabecera

**C-HDR-03** · `block_hash = H_d("ZZKBlkHeader____", header_encoding)`.

> La **preimagen del PoW son estos 108 bytes** (16 de etiqueta + 92 de cabecera). Cabe holgadamente
> en un solo bloque de rate de SHA3-256 (136 bytes), lo que permite mantener un kernel GPU de
> absorción única. Ver `research/sha3-kernel-audit.md` — el kernel actual asume esto sin
> documentarlo, y aquí queda documentado como contrato.

**C-HDR-04** · El **nonce ocupa los bytes `[96, 104)` de la preimagen** (offset 16 de la etiqueta
+ 80 del inicio del campo `nonce` en la cabecera). El minero GPU **MUST** iterar exactamente ese
rango. Este offset es **regla de consenso**, no detalle de implementación.

Offsets de los campos dentro de la cabecera, para que no haya que contarlos a mano:

| Campo | Offset en cabecera | Offset en preimagen |
|---|---|---|
| `consensus_branch_id` | `[0, 4)` | `[16, 20)` |
| `prev_hash` | `[4, 36)` | `[20, 52)` |
| `merkle_root` | `[36, 68)` | `[52, 84)` |
| `timestamp` | `[68, 76)` | `[84, 92)` |
| `bits` | `[76, 80)` | `[92, 96)` |
| **`nonce`** | **`[80, 88)`** | **`[96, 104)`** |
| `height` | `[88, 92)` | `[104, 108)` |

> ⚠️ **Corregido 2026-09-04 · hallazgo H-005.** Esta regla decía `[92, 100)` con offset 76. El 76
> venía de cuando `timestamp` era `u32` (`4+32+32+4+4 = 76`); P-004 lo fijó en `u64` y **este offset
> no se actualizó**.
>
> La consecuencia no era cosmética: `[92, 100)` cubre **los últimos 4 bytes de `bits`** y solo los
> 4 primeros del `nonce`. Un minero que siguiera la regla al pie de la letra estaría **mutando el
> target mientras mina**, así que todo bloque que produjera violaría C-BLK-05 (`bits` **MUST** ser
> exactamente el valor del retarget) y sería rechazado. Nunca habría encontrado un bloque válido, y
> el síntoma —"el minero no saca bloques"— no habría apuntado a la causa.
>
> En `zx-core` este offset **se deriva de los tamaños de los campos**, no se escribe a mano, y un
> test lo fija (`el_nonce_esta_donde_dice_c_hdr_04`). Si alguien vuelve a cambiar el ancho de un
> campo, el test falla en vez de romper el minero en silencio.

> El kernel heredado clava el nonce en los bytes `[48,56)` por accidente histórico y, si la cabecera
> midiera menos de 56 bytes, **todos los hilos calcularían el mismo hash**. Ver
> `research/sha3-kernel-audit.md` hallazgo 7.

### 6.3 · Árbol de Merkle

**C-BLK-01** · `merkle_root` es la raíz de un árbol binario de Merkle sobre los **txid** de las
transacciones del bloque, en orden de aparición.

**C-BLK-02** · Los nodos internos se calculan como `H_d("ZZKBlkMerkle____", izq ‖ der)`.

**C-BLK-03** · Si un nivel tiene un número impar de nodos, el último **MUST** emparejarse con el
valor nulo `0x00 × 32`. **MUST NOT** duplicarse el último nodo.

> Decidido 2026-09-04. La duplicación es la construcción de Bitcoin y arrastra
> **CVE-2012-2459**: dos listas de transacciones distintas producen la misma raíz de Merkle, lo que
> permite maleabilidad de bloque. El relleno con nulo distinguible (lo que hace Zcash para
> `hashAuthDataRoot`) elimina la ambigüedad. Coste: cero.

### 6.4 · Validez de bloque

**C-BLK-04** · `block_hash` **MUST** satisfacer el PoW (§7).
**C-BLK-05** · `bits` **MUST** ser exactamente el valor que devuelve el retarget (§7.3, C-DIFF-09).
**C-BLK-06** · El timestamp **MUST** cumplir §7.4.
**C-BLK-07** · La primera transacción **MUST** ser una coinbase válida (§8); ninguna otra lo es.
**C-BLK-08** · Todas las transacciones **MUST** ser válidas individualmente (§5.4).
**C-BLK-09** · Ninguna transacción **MUST** gastar un outpoint gastado por otra del mismo bloque.
**C-BLK-10** · El **weight** del bloque **MUST** ser `≤ LIMITE(H)`, según §6.5.

### 6.5 · Peso de bloque y límite dinámico

Reglas derivadas de `research/dynamic-blocksize.md`, que las obtuvo de
`monero-project/monero@3d3920d7` y `Cuprate/cuprate@4383f0d6`.

> ⚠️ **MUST** ser el diseño post-2019 (con mediana de largo plazo). El original de CryptoNote
> (2014), con solo la mediana corta, es vulnerable al **big bang attack**: 689 GB de cadena en 24 h
> por ~€118 800 de fees (Isthmus, `noncesense-research-lab/Blockchain_big_bang`).

#### Constantes

```
N_CORTO       = 100          // bloques — 200 min
N_LARGO       = 262 800      // bloques — 1 año exacto a 120 s
ZONA_LIBRE    = 100 000      // bytes de weight
FACTOR_SURGE  = 50
MAX_TX_WEIGHT = 100 000      // bytes — igual a ZONA_LIBRE, ver C-WGT-11
```

> **Por qué divergen de Monero.** `N_LARGO` de Monero son 100 000 bloques = 138,9 días a 120 s —
> la cadena olvidaría el pico de Navidad antes de la siguiente Navidad y penalizaría cada año el
> mismo tráfico estacional legítimo. Una ventana de un año absorbe el ciclo del marketplace, y
> además es **más difícil de mover para un atacante** (hay que desplazar más muestras). Coste:
> ~2 MB de estado.
> `ZONA_LIBRE` de Monero (300 000) está dimensionada para transacciones CryptoNote, mucho mayores
> que una transparente de ZEROX (~350 B para 2-in-2-out). 100 000 bytes dan ~285 tx/bloque
> ≈ 205 000 tx/día **libres de penalización**, con un suelo de crecimiento adversarial de
> 26,3 GB/año (262 800 bloques/año × 100 KB).

#### Peso

**C-WGT-01** · El **weight** de un bloque es `weight(coinbase) + Σ weight(tx_i)`. La cabecera de
bloque y la lista de hashes de transacción **MUST NOT** contarse.

**C-WGT-02** · En v1 (solo pool transparente), `weight(tx) = tamaño_serializado(tx)` en bytes.

> Monero añade aquí un *clawback* que penaliza las bulletproofs agregadas, porque su tamaño crece
> **logarítmicamente** con el número de outputs y agrupar sale desproporcionadamente barato. En
> Orchard la prueba Halo2 es de tamaño fijo y cada acción cuesta ~820 B constantes, así que la
> distorsión es de otro orden y probablemente no requiere corrección. **Reservado para v1.1;
> pendiente de confirmación de D1** antes de escribir la regla del pool blindado (P-009g).

#### Medianas

**C-WGT-03 · Mediana entera.** La mediana de un multiconjunto ordenado de `n` elementos es el
elemento central si `n` es impar, y si `n` es par:

```
get_mid(a, b) := (a/2) + (b/2) + ((a − 2·(a/2)) + (b − 2·(b/2)))/2
```

con `a = v[n/2 − 1]`, `b = v[n/2]`, división entera truncada hacia cero. **MUST** usarse esta
forma y no `(a+b)/2`: son equivalentes matemáticamente pero la segunda desborda.
**MUST NOT** emplearse coma flotante en ningún punto de §6.5.

**C-WGT-04 · Peso de largo plazo.** Para un bloque `b` a altura `H`, con `Mlt = Mlt(H)` calculado
según C-WGT-05 sobre las alturas anteriores:

```
inferior := (Mlt · 10) / 17
superior := Mlt + (Mlt · 7) / 10
lt_weight(b) := min( max(weight(b), inferior), superior )
```

Todas las operaciones en `u128`, división entera truncada, **en exactamente este orden**.

> Equivale a acotar cada bloque al rango `[0,588·Mlt, 1,7·Mlt]` de cara al histórico largo. El
> `1,7×` da ≈14,2× de expansión anual. La forma `Mlt + (Mlt·7)/10` **MUST** respetarse literalmente:
> no es idéntica a `(Mlt·17)/10` bajo truncamiento entero, y es la que fija los vectores de
> referencia de Monero.

**C-WGT-05 · Mediana de largo plazo.**

```
Mlt(H) := max( ZONA_LIBRE, mediana( lt_weight(b) : b ∈ [H − n_l, H − 1] ) )
donde n_l := min(N_LARGO, H)
```

**C-WGT-06 · Mediana de corto plazo.**

```
Mst(H) := mediana( weight(b) : b ∈ [H − n_c, H − 1] )
donde n_c := min(N_CORTO, H)
```

**C-WGT-07 · Arranque.** Para `H = 0` (génesis), `Mlt = Mst = ZONA_LIBRE`. Las ventanas **MUST**
usar los bloques disponibles cuando `H` es menor que su tamaño nominal, nunca rellenarse con
valores sintéticos.

#### Mediana efectiva y límite

**C-WGT-08 · Mediana efectiva.**

```
M(H) := max( min( max(Mlt(H), Mst(H)), FACTOR_SURGE · Mlt(H) ), ZONA_LIBRE )
```

El orden de `min`/`max` **MUST NOT** reordenarse: cambia la semántica en los empates.

**C-WGT-09 · Límite duro.**

```
LIMITE(H) := 2 · M(H)
```

Un bloque cuyo weight exceda `LIMITE(H)` es **inválido** (no meramente penalizado).

**C-WGT-10 · Precondición de la penalización.** La comprobación C-WGT-09 **MUST** ejecutarse antes
de evaluar C-EMIT-06. Una implementación **MUST** hacer de `weight ≤ 2·M` una precondición
verificada por construcción (tipo, constructor validante), **no** una convención de orden de
llamada.

> Trampa real detectada en Cuprate (`consensus/rules/src/miner_tx.rs:44-74`): el término
> `2·median − weight` es aritmética `usize`; si se calcula la recompensa sin haber chequeado antes
> el límite, hace **underflow**. Monero no lo sufre porque su `get_block_reward` retorna antes.
> `clippy::unwrap_used` no atrapa esta clase de bug.

#### Tope por transacción

**C-WGT-11 · Peso máximo de una transacción.** `weight(tx)` **MUST** ser `≤ MAX_TX_WEIGHT`, con

```
MAX_TX_WEIGHT = ZONA_LIBRE = 100 000 bytes
```

Es un **límite fijo de consenso**, independiente de la altura y de la mediana vigente. Aplica a
toda transacción, coinbase incluida.

> **Por qué existe y por qué vale exactamente `ZONA_LIBRE`.** Sin esta regla, el único tope de una
> transacción individual sería `LIMITE(H) = 2·M(H)`, que **crece con la mediana**: tras un periodo
> sostenido de bloques llenos, una sola transacción podría pesar megabytes. Eso degrada la
> propagación (y con ella la tasa de huérfanos), y da a un atacante una primitiva de coste
> asimétrico.
>
> Atarlo a `ZONA_LIBRE` en lugar de a un número mágico (Monero usa `CRYPTONOTE_MAX_TX_SIZE`
> = 1 000 000, sin relación con su zona libre de 300 000) produce un invariante enunciable en una
> frase:
>
> **Toda transacción válida cabe siempre en un bloque, a cualquier altura, sin empujarlo más allá
> de la zona libre de penalización.**
>
> Dos consecuencias que importan a un marketplace: (a) ninguna transacción puede quedar
> permanentemente inminable porque la mediana esté baja — no hay fondos atrapados; (b) ningún
> emisor puede obligar a un minero a asumir la penalización de C-EMIT-06 para incluirle. Con un
> tope desacoplado de `ZONA_LIBRE` no se tiene ninguna de las dos garantías.
>
> ⚠️ **Revisar en la Fase 6.** A ~820 B por acción Orchard, 100 000 bytes dan ~121 acciones por
> transacción. Si el blindado por lotes de la tesorería de Cortex necesitara más, se parte en
> varias transacciones — pero conviene reevaluar el invariante cuando se diseñe el pool blindado.
>
> **LAGUNA heredada de la investigación:** en Monero no se pudo verificar si `CRYPTONOTE_MAX_TX_SIZE`
> se re-comprueba al aceptar un bloque ya ensamblado o si es solo política de admisión a mempool.
> En ZEROX, C-WGT-11 es **regla de consenso** y **MUST** verificarse en la validación de bloque,
> no solo en el relay. Ver `research/dynamic-blocksize.md` §14.

---

---

## 7 · Prueba de trabajo y dificultad

### 7.1 · Regla de PoW

**C-POW-01** · Un bloque es válido solo si, interpretando `block_hash` como entero **big-endian**
de 256 bits:

```
block_hash < target
```

**C-POW-02** · Está **prohibido** el criterio de "contar bytes cero a la cabeza". Su granularidad
es de 8 bits (saltos de dificultad de ×256), incompatible con un retarget por bloque como LWMA.

> El kernel actual usa exactamente ese criterio prohibido. Ver `research/sha3-kernel-audit.md`.

### 7.2 · Codificación compacta del target (`bits`)

**C-POW-03** · `bits` es un `u32` que codifica un target de 256 bits como
`mantisa (3 bytes) × 256^(exponente − 3)`, con el exponente en el byte más significativo.

**C-POW-04 · Canonicidad de `bits`, definida como punto fijo.** `bits` **MUST** ser exactamente el
valor que produce el codificador canónico aplicado al target que decodifica:

```
canónico(bits)  ⟺  codificar(decodificar(bits)) == bits
```

Además, y como condición previa: el bit de signo **MUST** estar a cero, el exponente **MUST NOT**
ser cero, la mantisa **MUST NOT** ser cero, y el resultado **MUST NOT** desbordar 256 bits.

> ⚠️ **Reformulado 2026-09-04 al implementar.** La redacción anterior decía "mantisa normalizada", y
> la lectura natural de eso —"el byte alto de la mantisa **MUST** ser distinto de cero"— **es
> incorrecta**: rechazaría `0x1d00ffff`, que es canónico. Ese byte cero no es un descuido, es el
> resultado del desplazamiento que evita invadir el bit de signo. Y `0x1d00ffff` es precisamente el
> `TARGET_INICIAL` de ZEROX y el `powLimit` de Bitcoin.
>
> Definir la canonicidad como punto fijo del codificador no puede desincronizarse de él, porque
> **es** él. Enumerar reglas estructurales sí puede, y en el primer intento ya se equivocó.

**C-POW-05** · El target decodificado **MUST** estar en `[MIN_TARGET, POW_LIMIT]`, con

```
POW_LIMIT  = 2^224 − 1     // target máximo  ⇒ dificultad MÍNIMA
MIN_TARGET = 2^64          // target mínimo  ⇒ dificultad MÁXIMA
```

> `POW_LIMIT = 2^224 − 1` equivale a una dificultad de `2^32` ≈ 4,29·10⁹ hashes por bloque, es
> decir **≈35,8 MH/s** sostenidos para mantener 120 s. `MIN_TARGET = 2^64` acota el error de
> truncamiento del retarget (§7.3) manteniendo al menos 64 bits significativos en el target.

### 7.3 · Ajuste de dificultad — LWMA-1

Reglas tomadas verbatim de `research/lwma1.md`, que las derivó de `zawy12/difficulty-algorithms`.

> ⚠️ **Existen DOS fórmulas publicadas bajo el nombre "LWMA-1"**, con resultados numéricos
> distintos. ZEROX usa la **variante de espacio-target en U512**, nunca la de dificultad en `u64`
> (esta última tiene un bug de overflow confirmado que Wownero tuvo que parchear en producción).

#### Constantes

```
T          = 120                    // segundos, objetivo de tiempo de bloque
N          = 90                     // ventana, en bloques      [P-003 ✅ 2026-09-04]
k          = N·(N+1)·T / 2          // = 491 400   — constante precomputada, NO evaluar la expresión
NK         = N · k                  // = 44 226 000
ST_CAP     = 6·T                    // = 720 segundos
T_FLOOR    = N·(N+1)·T / 20         // = 49 140    — constante precomputada  [P-003 ✅]
FTL        = N·T / 20               // = 540 segundos
MTP_W      = 11                     // bloques
```

**C-DIFF-01 · Pureza.** El retarget es la función pura `siguiente_target(H, cab[H−N−1 .. H−1])`.
Sus **únicas** entradas son la altura `H`, los `N+1` timestamps y los `N` targets
`decode(bits(h))`. **MUST NOT** leer reloj local, hora de red, mempool, configuración, ni ninguna
cabecera fuera de esa ventana.

**C-DIFF-02 · Arranque.** Si `1 ≤ H ≤ N`, `siguiente_target(H) = TARGET_INICIAL`, con

```
TARGET_INICIAL_BITS = 0x1d00ffff
TARGET_INICIAL      = 2^224 − 2^208    // el mayor target REPRESENTABLE bajo POW_LIMIT
```

> ⚠️ **Corregido 2026-09-04 al implementar.** Esta regla decía `TARGET_INICIAL = POW_LIMIT =
> 2^224 − 1`, y **eso es inalcanzable**: el formato compacto de C-POW-03 solo representa valores de
> la forma `mantisa × 256^k` con la mantisa de 3 bytes, y `2^224 − 1` son 28 bytes de `0xFF`
> seguidos. Ningún `bits` decodifica a él, así que **el bloque génesis no habría podido llevar el
> target que la regla exigía**.
>
> `POW_LIMIT` sigue siendo la **cota** —C-POW-05 rechaza cualquier target por encima— y
> `TARGET_INICIAL` es el mayor valor representable por debajo. La diferencia en dificultad es de
> 1,5·10⁻⁵: irrelevante. Es exactamente la situación de Bitcoin, cuyo `powLimit` es también
> `0x1d00ffff`.

El primer retarget calculado es el de `H = N+1`. La ventana es siempre exactamente `N`;
**MUST NOT** encogerse dinámicamente.

> 🔶 **Revisable hasta el momento de crear el génesis** — y solo hasta entonces. No hay cadena
> viva que romper mientras el bloque 0 no exista, y testnet puede llevar un valor distinto.
> La elección es asimétrica: arrancar demasiado **difícil** impide lanzar (los primeros bloques
> tardarían horas o días); arrancar demasiado **fácil** se autocorrige, porque con `N = 90` la
> ventana se llena en minutos y LWMA toma el control. Arrancar exactamente en `POW_LIMIT` es el
> extremo seguro de esa asimetría, y ahorra justificar una constante más.

**C-DIFF-03 · Reconstrucción monótona de solvetimes.** Todo en `i64`:

```
p := ts(H − N − 1)
para j = 1..N:
    h := H − N − 1 + j
    c := si ts(h) > p entonces ts(h) sino p + 1
    st[j] := min(ST_CAP, c − p)
    p := c
```

Invariante: `1 ≤ st[j] ≤ 720`, **por construcción**, no por saturación.
**MUST NOT** implementarse como `if st < 1 then st = 1`.

> *Motivación:* el patrón prohibido es exactamente el que produjo un ataque real — una moneda
> perdió 4 800 bloques en 5 horas porque los timestamps retrasados se convertían en solvetimes
> largos artificiales que hundían la dificultad.

**C-DIFF-04 · Suma ponderada.** `t := Σ_{j=1..N} j · st[j]` en `i64`.

**C-DIFF-05 · Suelo.** `si t < T_FLOOR entonces t := T_FLOOR`.

> ✅ **P-003 RESUELTO (2026-09-04): el suelo se incluye.** Sin él, un atacante que controle la
> ventana con timestamps a `padre+1` multiplica la dificultad por **120 en un solo bloque** y
> congela la cadena al retirarse. Con el suelo, el techo es **×10**.

**C-DIFF-06 · Suma de targets.** `S := Σ_{j=1..N} decode(bits(H − N − 1 + j))` en **U512**, sin
divisiones intermedias.

**C-DIFF-07 · Target siguiente.** En U512, división entera truncada:

```
next := (S · t · BIAS_NUM) / (NK · BIAS_DEN)
```

con `BIAS_NUM / BIAS_DEN` = `<<PENDIENTE: racional exacto — D9 debe fijarlo>>`, aproximando
`1 − e⁻⁶ = 0,99752124…`

> ✅ **P-005 RESUELTO (2026-09-04): SÍ se corrige el sesgo.** El clamp `min(6T, ST)` recorta por
> arriba y no por abajo, sesgando la media: sin corregir, el tiempo real de bloque sería
> ≈120,30 s en vez de 120,00 s. Flux, TENT y Tari no lo corrigen; ZEROX sí.
>
> El racional concreto lo fija D9. Referencia: `9975/10000` deja 0,0021% de error residual;
> `99752/100000` deja 0,00012%. El coste computacional es idéntico.
>
> **Cota de overflow con la corrección:** `S·t·BIAS_NUM ≈ 2²⁶⁵` en el peor caso. Cabe holgadamente
> en U512 — razón adicional para mandar U512 y no U256 en C-DIFF-06.

**C-DIFF-08 · Acotado.** `next := clamp(next, MIN_TARGET, POW_LIMIT)`.

**C-DIFF-09 · Ida y vuelta por `bits`.** `bits(H)` es válido **si y solo si**
`bits(H) == compact(next)`. El valor que consume C-DIFF-06 para bloques anteriores es **siempre**
`decode(bits(h))`, nunca un target de alta precisión persistido.

> Persistir y realimentar el target sin cuantizar produce un **split entre nodos con estado
> completo y nodos headers-first**.

**C-DIFF-10 · Nada más.** **MUST NOT** aplicarse: jump rule de LWMA-2/4, tempering, clamps por
bloque, límites de timespan, redondeo a dígitos significativos, ordenación de timestamps, lag,
cut, ni MTP como bloque más reciente de la ventana.

### 7.4 · Reglas de timestamp

**C-TS-01 · Monotonía.** `ts(H) ≥ ts(H−1) + 1`. Rechazo **permanente**.

**C-TS-02 · MTP solo para timelocks.** `MTP(H) = mediana(ts(H−1) .. ts(H−11))`. Se usa
exclusivamente como reloj para `lock_time` y HTLC. **MUST NOT** entrar en el retarget.

**C-TS-03 · Future Time Limit.** `ts(H) ≤ reloj_local + FTL`. Rechazo **NO permanente**: el bloque
se difiere y se reintenta, **MUST NOT** cachearse como inválido ni banear al par.

> Cachearlo como inválido permanente produce un **split garantizado con partición temporal**.

**C-TS-04 · Prohibida la hora de red.** Ninguna regla de consenso **MUST** usar mediana de pares,
NTP ni hora ajustada. Solo reloj local del nodo.

> Con `FTL = 540 s`, la regla "revert to node time" de Bitcoin/Zcash abriría un Sybil del 33 %.
> Al eliminar la hora de pares, la vulnerabilidad no existe.

**C-TS-05 · Regla del minero (NO es consenso).** `ts = max(reloj_local, ts(padre) + 1)`; no
publicar hasta que `ts ≤ reloj_local + FTL`.

---

## 8 · Emisión y coinbase

### 8.1 · Curva de emisión

```
SOFT_CAP           = 1 000 000 000 ZZK = 100 000 000 000 000 000 brek
SHIFT              = 19
TAIL_EMISSION      = 32 ZZK/bloque      =       3 200 000 000 brek
COINBASE_MATURITY  = 100 bloques
```

**C-EMIT-01 · Recompensa base.** La recompensa base del bloque de altura `H` es:

```
recompensa_base(H) = max( (SOFT_CAP_brek − emitido(H)) >> SHIFT , TAIL_EMISSION )
```

donde `emitido(H)` es la suma de los **subsidios efectivos** (C-EMIT-06) de los bloques `0 .. H−1`.

> Decaimiento exponencial suave, sin halvings. Recompensa inicial = `190 734 863 281` brek
> ≈ **1 907,35 ZZK**. La fórmula cae por debajo del tail hacia el **año 8,16**; el suministro cruza
> los 1000 M hacia el **año 10,15**. Inflación perpetua **0,84 %/año**, decreciente en porcentaje
> para siempre. Números fijados 2026-09-04 (P-002).
>
> **El suministro NO tiene máximo.** A diferencia de Bitcoin, la cola no se apaga: tras el año
> ~10,15 se emiten `32 × 262 800 = 8 409 600` ZZK/año indefinidamente. Por eso ZEROX no puede tener
> un `MAX_MONEY` y usa `ZX_VALUE_SANITY_LIMIT` (C-TX-12) en su lugar.
>
> **Por qué 1000 M y no 21 M.** El sistema es **homogéneo de grado 1**: escalar `SOFT_CAP` y
> `TAIL_EMISSION` por el mismo factor escala toda la emisión y deja el calendario intacto. El
> número, por tanto, no tiene consecuencia económica — solo fija la magnitud que ve un comprador en
> el checkout de Cortex. Con `SOFT_CAP = C` (en ZZK), un artículo de 1 € cuesta ≥ 1 ZZK mientras la
> capitalización se mantenga por debajo de `C` euros. 1000 M cubre sin decimales hasta una
> capitalización de 1000 M €.

**C-EMIT-06 · Penalización por tamaño.** Sea `x = weight(bloque)` y `M = M(H)` la mediana efectiva
(C-WGT-08). El **subsidio efectivo** es:

```
subsidio(H) = recompensa_base(H)                                    si  x ≤ M
subsidio(H) = (recompensa_base(H) · x · (2M − x)) / M / M           si  M < x ≤ 2M
```

Las operaciones **MUST** hacerse en `u128` y las dos divisiones **MUST** ser sucesivas, enteras y
truncadas hacia cero. El caso `x > 2M` no llega aquí: el bloque ya es inválido por C-WGT-09.

> El producto intermedio `recompensa_base · x · (2M − x)` desborda `u64` con holgura. Monero tuvo
> este bug en producción; el comentario sigue en su código:
> *"BUGFIX: 32-bit saturation bug (e.g. ARM7), the result was being treated as 32-bit by default."*
> (`cryptonote_basic_impl.cpp:111-112`). En Rust, `u128` nativo.

**C-EMIT-07 · Orden de aplicación — el tail NO es un suelo por bloque.** El suelo `TAIL_EMISSION`
se aplica **dentro** de `recompensa_base` (C-EMIT-01), es decir **antes** de la penalización
C-EMIT-06, y la penalización lo multiplica. En consecuencia, un minero cuyo bloque exceda la
mediana efectiva percibe **menos de `TAIL_EMISSION`**, tendiendo a 0 conforme `x → 2M`.
El contador `emitido(H)` acumula el **subsidio efectivo ya penalizado**: la moneda no percibida
**MUST NOT** emitirse nunca.

> ⚠️ **`TAIL_EMISSION = 32 ZZK/bloque` es la emisión NOMINAL, no un mínimo garantizado por
> bloque.** Decidido 2026-09-04 (P-009f, hallazgo H-004).
> La alternativa —aplicar el suelo *después* de penalizar— garantizaría los 32 ZZK, pero anularía
> la penalización en régimen de cola permanente, que en ZEROX es **para siempre**: llenar el bloque
> hasta `2M` saldría gratis y se reintroduciría el problema que `monero-project/monero#1878` ya
> señalaba en 2017. Ver `research/dynamic-blocksize.md` §6.

**C-EMIT-02** · No hay premine, ni founder reward, ni dev tax. El génesis tiene coinbase de valor
cero.

### 8.2 · Transacción coinbase

**C-EMIT-03** · La coinbase es la primera transacción del bloque, no tiene entradas, y su
`Σ value(salidas) ≤ subsidio(H) + Σ fees(bloque)`, con `subsidio(H)` según C-EMIT-06.

**C-EMIT-04 · Unicidad del txid de coinbase.** La coinbase **MUST** incluir un campo `height: u32`
igual a la altura del bloque, y ese campo **MUST** formar parte de los datos de efecto (entra en
el txid).

> ⚠️ **Regla crítica, fácil de omitir.** Como el testigo de la coinbase es dato de autorización y
> no entra en el txid, **dos coinbases de alturas distintas tendrían el mismo txid** sin esta
> regla. Zcash lo resolvió con una regla equivalente que **no está en ZIP-244** sino en su
> Protocol Specification — un diseño derivado solo del ZIP reproduce el bug.
> Ver `research/zip244.md` §7.

**C-EMIT-05 · Madurez.** Una salida de coinbase **MUST NOT** gastarse hasta que hayan pasado
`COINBASE_MATURITY = 100` bloques desde su creación.

---

## 9 · Reservado — v1.1, pool blindado (Fase 6)

Esta sección **no contiene reglas normativas todavía**. La investigación está completa y
verificada; se convertirá en reglas cuando se aborde la Fase 6.

| Tema | Investigación |
|---|---|
| Formato del bundle Orchard, byte a byte | `research/orchard-bundle.md` |
| No-overflow de la binding signature con parámetros de ZEROX | `research/orchard-math-verification.md` §1 |
| Derivación y unicidad del nullifier | `research/orchard-math-verification.md` §2 |
| Patrón de integración en el digest | `research/zip244.md` |

**Reglas ya identificadas que entrarán aquí** (no normativas todavía):

- `sizeProofs` **MUST** tener longitud canónica `2720 + 2272·n` — sin esta regla, rellenar la
  prueba con basura no invalida la tx **ni cambia su txid**: coste ilimitado de banda y disco,
  gratis. Es un CVE real (GHSA-2x4w-pxqw-58v9).
- `nActions` **MUST** ser `< 2^16`, verificado **antes** de verificar prueba y binding signature.
  En Zcash es redundante por su límite de bloque; en ZEROX es ahora **redundante también**, desde
  que §6.5 fija `LIMITE(H)`, pero **MUST** conservarse: cierra el argumento de no-overflow sin
  depender de la mediana vigente a esa altura.
- Un nullifier **MUST NOT** repetirse **ni dentro de una transacción** ni entre transacciones.
- `rk` **MUST NOT** ser el punto identidad; `ephemeralKey` **MUST** decodificar a un punto Pallas
  válido no-identidad. Ambas nacieron de incidentes reales (crash remoto y split de consenso).
- El anchor **MUST** estar en el digest del **txid** (semántica v5), no en el auth digest.
- Prohibido reimplementar el gadget de `DeriveNullifier`: la canonicidad de la descomposición del
  escalar es, literalmente, la puerta de un doble gasto.

**Versión mínima del crate**: `orchard = "=0.15.5"`. Versiones `< 0.14.0` tienen un bug de
soundness que permitía **violación de balance = falsificación de moneda invisible**.

---

## 10 · Reservado — scripting (v2+)

No hay lenguaje de script en v1.0. El gancho de extensión es el campo `version` de la transacción
(C-TX-07) más el `Lock` como enum etiquetado (C-TX-09): un tipo `Script` futuro es una variante
nueva activada por altura, no una reescritura.

---

## 11 · Selección de cadena (fork choice)

Derivado de `research/fork-choice-reorg.md`.

**C-FORK-01 · Trabajo de un bloque.**

```
trabajo_bloque(h) := ((2^256 − 1 − target(h)) / (target(h) + 1)) + 1
```

con `target(h) = decode(bits(h))`. **MUST** calcularse en aritmética sin signo de al menos 256 bits,
con operaciones comprobadas (C-ENC-03). **MUST NOT** truncarse a un ancho menor.

> Es `2^256 / (target+1)`, la esperanza del número de hashes necesarios para resolver ese bloque.
> Verbatim de `bitcoin/bitcoin:src/chain.cpp:120-133` (`GetBitsProof`).
> **Riesgo si se trunca:** dos implementaciones con anchos distintos divergen en silencio en cuanto
> el acumulado supere el ancho menor. Bitcoin usa 256 bits precisamente por esto.

**C-FORK-02 · Trabajo acumulado.**

```
trabajo_acumulado(0) := trabajo_bloque(0)
trabajo_acumulado(H) := trabajo_acumulado(H−1) + trabajo_bloque(H)
```

Es un valor **derivado y cacheable**, nunca fuente de verdad: **MUST** poder recalcularse
íntegramente a partir de los `bits` almacenados.

> Bitcoin lo marca así explícitamente en `src/chain.h`:
> *"(memory only) Total amount of work (expected number of hashes) in the chain up to and including
> this block"*.

**C-FORK-03 · Regla de Nakamoto.** Entre dos cadenas válidas que comparten un ancestro común, la
cadena activa **MUST** ser la de mayor `trabajo_acumulado(tip)`.

"Válida" exige que **todos** los bloques desde el ancestro común hasta el tip candidato cumplan
§5–§8, **evaluados sobre la cadena candidata** y nunca sobre la cadena activa vigente (C-REORG-06).

> El trabajo acumulado es condición **necesaria, no suficiente**. Bitcoin lo implementa así en
> `FindMostWorkChain()` (`validation.cpp:3126-3179`): toma el máximo, camina hacia atrás
> verificando que ningún ancestro esté marcado inválido o le falten datos, y si lo está lo purga del
> conjunto de candidatos y repite. No basta con ordenar por trabajo y quedarse con el primero.

**C-FORK-04 · Desempate determinista.** Si dos cadenas tienen `trabajo_acumulado(tip)` **idéntico**,
la cadena preferida es aquella cuyo `block_hash(tip)`, interpretado como entero **big-endian** (la
misma convención de C-POW-01), sea **menor**.

> 🔶 **Divergencia deliberada frente a Bitcoin.** Bitcoin desempata por `nSequenceId`, un contador
> asignado **en el orden de llegada local** (`validation.cpp:3817`), con la dirección de puntero
> como último recurso. Eso es **no determinista entre nodos**: dos nodos que reciben los mismos dos
> bloques en distinto orden pueden sostener tips distintos.
>
> Para ZEROX eso es inaceptable por dos razones. Primero, el proyecto se exige determinismo y lo
> testea; una regla cuyo resultado depende de la topología de red no es testeable. Segundo, y más
> concreto: **el nodo de Cortex y el del vendedor podrían discrepar sobre si un pago existe.**
>
> No es terreno inexplorado. Zebra —software en producción en la mainnet de Zcash— hace exactamente
> esto, y documenta que se aparta de la spec a propósito
> (`zebra-state/src/service/non_finalized_state/chain.rs:2334-2347`):
> *"Despite the consensus rules, Zebra uses the tip block hash as a tie-breaker... This departure
> from the consensus rules may delay network convergence... But Zebra nodes should converge as soon
> as the tied work is broken."*
>
> ⚠️ **Contrapartida asignada a D8:** con "gana el hash menor", un minero que encuentra un bloque
> tiene un incentivo marginal a **seguir buscando un hash más bajo** en vez de publicar de
> inmediato. Se estima dominado —el empate solo importa durante una carrera de huérfanos, y retrasar
> la publicación arriesga perder la carrera entera—, pero **debe cuantificarse**, no darse por
> supuesto.

---

## 12 · Reorganizaciones

**C-REORG-01 · Contenido del undo data.** Por cada bloque conectado, el nodo **MUST** persistir —por
cada transacción no coinbase y por cada una de sus entradas, en el orden de la transacción— el UTXO
consumido **completo**: `value`, `Lock`, altura de creación y marca de coinbase. **MUST** bastar
para reconstruirlo sin releer el bloque que lo originó.

> Es exactamente `CTxUndo`/`CBlockUndo` de `bitcoin/bitcoin:src/undo.h`
> (*"for all but the coinbase"*).

**C-REORG-02 · Orden del rollback.** Al desconectar un bloque:
1. Verificar que las salidas que creó están en el UTXO set **tal y como se esperan** y eliminarlas.
   La comparación es obligatoria: es la detección de corrupción.
2. Reinsertar los UTXO consumidos en orden **inverso de transacción** e **inverso de entrada** dentro
   de cada transacción.

Al desconectar varios bloques, **MUST** hacerse siempre del tip hacia el punto de fork, nunca en
otro orden ni en paralelo.

> `DisconnectBlock` (`validation.cpp:2178-2247`): *"undo transactions in reverse order"*.

**C-REORG-03 · Atomicidad.** Un reorg **MUST** ser atómico frente a cualquier consulta externa. Si
un solo bloque de la rama nueva falla al conectar, el nodo **MUST** volver exactamente al tip
anterior, recomponiendo la rama vieja completa, antes de responder a nada. **MUST NOT** quedar el
UTXO set en un estado que no corresponda a ningún tip válido conocido.

> Monero lo implementa en dos fases con reversión total en caso de fallo:
> `rollback_blockchain_switching(disconnected_chain, split_height)`
> (`blockchain.cpp:1132-1250`).

**C-REORG-04 · Mempool tras reorg.** Las transacciones de bloques desconectados que no aparezcan en
la cadena nueva **MUST** reinsertarse en el mempool y **re-validarse** contra el UTXO set
resultante. Las que resulten inválidas —doble gasto por la cadena nueva, madurez de coinbase
violada— **MUST** descartarse.

**C-REORG-05 · Cachés de ventana: la clave es el HASH, no la altura.** Toda estructura que cachee
una ventana de bloques —las medianas `Mst`/`Mlt` de §6.5, cualquier caché de solvetimes de LWMA—
**MUST** indexarse por el **hash del bloque tip que la originó**, nunca por altura ni por un
contador incremental. Antes de reutilizar un valor cacheado **MUST** compararse ese hash contra el
tip real de la cadena que se está evaluando; si no coincide, **MUST** recomputarse desde cero.

> ⚠️ **Esta es la regla que evita un fork silencioso**, el peor tipo: el nodo con caché contaminada
> sigue funcionando y aceptando bloques bajo una regla de peso o dificultad que ya no corresponde a
> la cadena real.
>
> Así lo hace Monero (`blockchain.cpp:1436-1493`, verificado línea a línea):
> ```cpp
> crypto::hash tip_hash = m_db->get_block_hash_from_height(tip_height);
> cached = tip_hash == m_long_term_block_weights_cache_tip_hash;   // ← hash, no altura
> ```
> Y su caché de dificultad se resetea con un flag explícito **en los tres puntos de entrada de
> reorg**: `m_timestamps_and_difficulties_height = 0;`.
>
> Un caché indexado por altura devuelve datos de la rama vieja tras un reorg que reemplaza bloques
> a las mismas alturas, **sin que nada falle visiblemente**.

**C-REORG-06 · Las ventanas se leen sobre la cadena candidata.** Al validar una cadena candidata,
toda ventana de §6.5 y §7.3 **MUST** recorrerse hacia atrás siguiendo `prev_hash` desde el
candidato. **MUST NOT** leerse de estructuras indexadas por altura de la cadena activa, que a la
misma altura pueden contener un bloque de la otra rama.

**C-REORG-07 · Profundidad máxima de reorg.**

```
MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 99 bloques
```

Un nodo que detecte una reorganización que retrocedería más de `MAX_REORG_LENGTH` bloques
**MUST NOT** aplicarla. **MUST** detenerse y alertar al operador de forma explícita y ruidosa.

> 🔶 **Decidido 2026-09-04, y es tanto decisión de producto como de consenso.**
>
> Las tres posturas reales: Bitcoin no tiene límite; Monero tampoco en consenso (solo checkpoints
> fuera de él); zcashd sí, exactamente `COINBASE_MATURITY − 1` (`src/main.h:64`), y **apaga el
> nodo** — *"the node is shutting down for your safety... Please help, human!"*
> (`src/main.cpp:4727-4746`).
>
> **Por qué el límite, para un marketplace.** Da a Cortex una garantía que se puede enunciar a un
> vendedor: *"pasadas 100 confirmaciones (3,3 h) el cobro es final por protocolo, no solo
> probablemente"*. Es finalidad al estilo Zcash en lugar de la finalidad probabilística de Bitcoin:
> *"In Zcash, chain state is final once it is beyond the reorg limit, unlike Bitcoin which only has
> only probabilistic finality."* Además cierra por completo el vector "el minero cobra, gasta el
> coinbase, y un reorg profundo se lo quita": ligado a `COINBASE_MATURITY`, un coinbase maduro no
> puede deshacerse jamás.
>
> **Por qué pesa más en una cadena pequeña.** No es teórico: Monero sufrió un reorg real de **18
> bloques** el 14-15 de septiembre de 2025, invalidando 118 transacciones. ZEROX nacerá mucho más
> pequeña que Monero, y por tanto más expuesta.
>
> **Contrapartida asumida:** una partición de red honesta y prolongada (>3,3 h con hashrate
> sustancial a ambos lados) se convierte en una parada de nodo que exige intervención humana. Es
> *fail-stop*, no *fail-safe*, y es deliberado: para infraestructura de pagos, pararse y avisar es
> preferible a seguir sirviendo un estado que quizá sea el de una minoría.
>
> ⚠️ **Requisito derivado, para D3:** debe existir y documentarse un **camino de recuperación** para
> el nodo detenido (resincronización, checkpoint). Sin él, la regla deja nodos congelados en una
> minoría sin saberlo, que es justo lo que Bitcoin evita al no tener límite.

---

## 13 · Profundidad de confirmación — política de producto, NO consenso

> Esta sección **no es normativa**. Es la guía para Cortex y para el wallet. Se apoya en Nakamoto
> §11, Rosenfeld (arXiv:1402.2009) y Grunspan & Pérez-Marco (arXiv:1702.02867), que **encontraron un
> error real en la fórmula de Nakamoto** —usa `Q_z` donde corresponde `Q_{z+1}`, lo que
> **subestima el riesgo**— y dan la forma cerrada `P(z) = I_{4pq}(z, 1/2)`.

### Confirmaciones necesarias para `P(doble gasto) < 0,1 %`

| `q` atacante | `z` correcto | `z` de Nakamoto (optimista) | Tiempo a T=120 s |
|---|---|---|---|
| 10 % | 6 | 5 | 12 min |
| 15 % | 9 | 8 | 18 min |
| 20 % | 13 | 11 | 26 min |
| 25 % | 20 | 15 | 40 min |
| 30 % | 32 | 24 | 1 h 04 |
| 35 % | 58 | 41 | 1 h 56 |
| 40 % | 133 | 81 | 4 h 26 ⚠ |
| 45 % | 539 | 340 | ~18 h ⚠⚠ |

### Riesgo con pocas confirmaciones (Rosenfeld, Tabla 1)

| `q` | n=1 | n=2 | n=3 | n=4 | n=6 |
|---|---|---|---|---|---|
| 0,10 | 20 % | 5,6 % | 1,71 % | 0,546 % | 0,059 % |
| 0,20 | 40 % | 20,8 % | 11,58 % | 6,67 % | 2,33 % |
| 0,30 | 60 % | 43,2 % | 32,6 % | 25,2 % | 15,6 % |

### Política recomendada para Cortex

| Nivel | Confirmaciones | Tiempo | Riesgo a `q=10 %` |
|---|---|---|---|
| Bajo valor (bien digital, importe pequeño) | **3** | 6 min | 1,71 % |
| Estándar | **6** | 12 min | 0,059 % |
| Alto valor / irreversible (envío físico caro) | **100** | 3,3 h | **cero por protocolo** (C-REORG-07) |

A T=120 s, `z` confirmaciones cuestan **5× menos tiempo real** que las mismas `z` en Bitcoin. El
tercer nivel no es una probabilidad: es la garantía dura de C-REORG-07.

> ⚠️ **Las filas de `q ≥ 40 %` pueden ser optimistas para ZEROX.** Ver §7.2 de
> `research/fork-choice-reorg.md`: las tablas asumen dificultad constante e idéntica en ambas ramas,
> pero C-DIFF-01 hace que **la rama privada del atacante tenga su propio LWMA** y se abarate sola
> tras completar su ventana de `N=90`. Con `z=133` o `z=539` se cruzan varias ventanas completas.
> Encargo abierto para **D9**.
>
> ⚠️ **`q` en el lanzamiento puede ser mucho mayor que en Bitcoin.** Con un hashrate de red pequeño,
> un pool de otra cadena SHA-3 puede apuntar hardware prestado a ZEROX de forma oportunista.
> Modelado asignado a **D8**.

---

## 14 · Activación de cambios de consenso

Derivado de `research/upgrades-genesis.md`, que lo obtuvo de ZIP-200, del código de
`monero-project/monero` (`src/hardforks/hardforks.cpp`) y de BIP-9/BIP-8.

### 14.1 · Principio

**C-UPG-01 · Solo hard forks, activados por altura.** Todo cambio de regla de consenso en ZEROX es
un **hard fork activado a una altura fija codificada en el software**. **MUST NOT** existir
señalización de mineros, votación por supermayoría ni detección de versión de cliente como
mecanismo de activación.

> Es el denominador común de los dos diseños maduros. Zcash lo exige textualmente (ZIP-200):
> *"When a consensus rule depends on activation of a particular upgrade, its implementation [...]
> MUST be gated by a block height check."*
> Y Monero, pese a tener implementada una clase `HardFork` con votación por supermayoría (ventana
> de 10 080 bloques, umbral 80 %), usa `threshold = 0` en **las 16 entradas reales** de su tabla:
> nunca la ha ejercido.
>
> BIP-9 y BIP-8 **no aplican**: están definidos para *soft forks* — *"allowing multiple
> backward-compatible changes (further called \"soft forks\") to be deployed in parallel"*. La
> señalización de mineros no evita un split en un hard fork, porque un nodo antiguo rechaza los
> bloques nuevos por definición, se señalice o no.

**C-UPG-02 · Tabla de ramas.** Cada red mantiene una tabla ordenada y hardcodeada de pares
`(CONSENSUS_BRANCH_ID, ACTIVATION_HEIGHT)`. `CONSENSUS_BRANCH_ID` es un `u32` **no cero** y
globalmente único por rama.

```
mainnet:  (0xc47880ea, 0)      // v1.0 — desde el génesis
```

> `0xc47880ea` = primeros 4 bytes de `SHA3-256("ZEROX/consensus-branch/v1.0")` leídos como `u32`
> little-endian. Derivado, no inventado: cualquiera puede reproducirlo.

**C-UPG-03 · Si cambia la altura, cambia el identificador.** Si `ACTIVATION_HEIGHT` de una rama se
modifica por cualquier motivo antes de activarse, su `CONSENSUS_BRANCH_ID` **MUST** cambiar también.

> ZIP-200, literal: *"if the ACTIVATION_HEIGHT of a network upgrade is changed for any reason
> (e.g. security vulnerabilities or consensus bugs are discovered), the CONSENSUS_BRANCH_ID MUST
> also be changed."*

### 14.2 · Protección contra repetición y contra barrido

**C-UPG-04 · Protección de repetición (replay).** El `CONSENSUS_BRANCH_ID` **MUST** formar parte de
la etiqueta de dominio raíz del txid y del sighash (§4.2, §4.3, §4.5): `"ZZKTxIdHash_" ‖ CBID`. Una
firma válida en una rama es por construcción inválida en cualquier otra.

**C-UPG-05 · Protección contra barrido (wipe-out).** El `CONSENSUS_BRANCH_ID` **MUST** ir en la
**cabecera de bloque** (C-HDR-02b), no solo en el sighash.

> ⚠️ **Esta regla cierra un agujero que ZIP-200 identifica y que Zcash NO implementó.**
>
> El escenario: si tras la altura de activación la rama no actualizada solo produce bloques que
> *también* serían válidos bajo las reglas nuevas (por ejemplo, bloques vacíos), un atacante con
> más trabajo acumulado en la rama vieja podría **barrer la rama nueva mediante un reorg
> perfectamente legítimo** según la regla de mayor trabajo. Zcash se libró en Overwinter por
> casualidad estructural: su cambio de formato de transacción invalidaba trivialmente lo anterior.
>
> ZIP-200 nombra la solución genérica y la deja sin implementar: *"More generally, this issue could
> be addressed in a future network upgrade by modifying the block header to include a commitment to
> the CONSENSUS_BRANCH_ID."*
>
> **Para ZEROX no es opcional.** Los hard forks que ya damos por previstos —ajustar `ZONA_LIBRE`,
> `N_LARGO`, `REF_WEIGHT`— son **cambios de parámetro puros**: no fuerzan ningún cambio de formato
> que resulte trivialmente inválido bajo las reglas viejas. Son exactamente el caso vulnerable.
> Al nacer sin cadena viva, podemos ponerlo en la cabecera desde el bloque 0 y sin coste: el
> campo ya existía como `version`, la cabecera sigue midiendo **92 bytes** y la preimagen de PoW
> sigue midiendo **108 bytes** (C-HDR-03, C-HDR-04 intactas).

### 14.3 · Comportamiento del nodo

**C-UPG-06 · Mempool.** Mientras la altura del tip esté por debajo de una `ACTIVATION_HEIGHT`, un
nodo **SHOULD NOT** aceptar en mempool transacciones que solo serán válidas en la rama posterior.
Al alcanzarse la altura, el mempool **SHOULD** purgarse de las que nunca serán válidas en la rama
nueva.

**C-UPG-07 · Nodo desactualizado.** Un nodo que detecte que ha estado siguiendo bloques que sus
reglas actuales consideran inválidos **SHOULD** detenerse y avisar al operador, en lugar de
continuar en silencio.

> ZIP-200: *"if there are a significant number of invalid blocks it SHOULD shut down and alert the
> user of the issue."*

**C-UPG-08 · Parámetros ajustables.** Se declaran explícitamente ajustables por hard fork, sin que
ello los convierta en variables de ejecución: `N_CORTO`, `N_LARGO`, `ZONA_LIBRE`, `FACTOR_SURGE`,
`MAX_TX_WEIGHT`, `REF_WEIGHT`, `FEE_MASK`. A cualquier altura concreta son constantes.

---

## 15 · Bloque génesis

### 15.1 · Definición

**C-GEN-01 · Definición constructiva, hash asertado.** El génesis **MUST** definirse por una
función determinista de parámetros explícitos (mensaje de coinbase, timestamp, `bits`, `nonce`,
recompensa cero), y la implementación **MUST** comparar el hash resultante contra una constante
hardcodeada y **abortar el arranque** si no coincide.

> Es el patrón de Bitcoin (`src/kernel/chainparams.cpp`) y de Zcash: `CreateGenesisBlock(...)`
> seguido de `assert(consensus.hashGenesisBlock == uint256{"000000000019d66..."})`. Monero, en
> cambio, hardcodea la transacción coinbase en hexadecimal crudo.
>
> Elegimos el patrón constructivo por dos razones: es **auditable** (se ve de qué parámetros sale)
> y **falla duro y visible** si alguien toca un parámetro sin recalcular el hash, en lugar de
> arrancar en silencio sobre un génesis no intencionado.

**C-GEN-02 · El génesis está exento de la comprobación de PoW.** La validación de PoW (§7.1)
**MUST NOT** aplicarse al bloque de altura 0. Su inserción en el índice es una ruta separada.

> Verificado en el código de Bitcoin, `src/validation.cpp:4200-4218`: `AcceptBlockHeader` envuelve
> la llamada a `CheckBlockHeader` en `if (hash != GetConsensus().hashGenesisBlock)`, y el génesis
> entra por `LoadGenesisBlock`, que nunca pasa por ahí. Es una exención **estructural**,
> independiente de si el génesis satisface o no su propio target.
>
> **LAGUNA:** no se pudo verificar si zcashd valida el PoW/Equihash de su propio génesis en el
> arranque real. Ver `research/upgrades-genesis.md` §B.5.

**C-GEN-03 · Coinbase de valor cero e inconectable.** La coinbase del génesis tiene
`Σ value(salidas) = 0` y sus salidas **MUST NOT** insertarse en el UTXO set.

> Bitcoin lo resuelve con un caso especial en `ConnectBlock` (`validation.cpp:2336-2342`,
> comentario: *"Special case for the genesis block, skipping connection of its transactions (its
> coinbase is unspendable)"*). No es que gastarla esté prohibido por regla: es que nunca existe.

**C-GEN-04 · Redes distintas, génesis distintos.** El génesis de mainnet y el de testnet **MUST**
producir hashes distintos. Ningún bloque de una red puede ser jamás el bloque 0 válido de otra.

> `DECISIONES.md` §7 solo describía el génesis de mainnet. El de testnet es una decisión pendiente
> y **no es un detalle de redacción**.

### 15.2 · El mensaje simbólico

**C-GEN-05** · El mensaje de la coinbase del génesis **no tiene función de consenso**: ningún nodo
inspecciona su contenido. **MUST** contener, aun así, una referencia a un evento público
verificable de la fecha de lanzamiento.

> El *"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"* de Bitcoin es
> indistinguible, en consenso, de cualquier otro relleno de la misma longitud: en
> `src/kernel/chainparams.cpp` se copia al `scriptSig` y ninguna ruta de validación lo parsea.
>
> Su valor es **una comprobación humana, manual y única**: cualquiera puede verificar que el titular
> corresponde a esa fecha y concluir que el bloque no pudo minarse antes.
>
> **Para ZEROX esto pesa más que en la mayoría de cadenas**, porque `DECISIONES.md` §7 declara
> "premine / dev tax / founder reward: ninguno". El precedente es Bytecoin, del que Monero nació
> como fork limpio: se concluyó públicamente que ~80 % del suministro ya existía antes del
> lanzamiento anunciado, con timestamps de bloque fabricados para simular actividad desde 2012.
> Un génesis con fecha verificable es la única defensa barata contra esa acusación.

**`<<PENDIENTE: mensaje, timestamp y nonce del génesis — se fijan el día del lanzamiento>>`**

---

## 16 · Parámetros de red

> Esta sección puede migrar a un SPEC de P2P independiente. Se recoge aquí porque C-NET-01 es lo
> que de verdad aísla las redes.

**C-NET-01 · Prefijo mágico.** Todo mensaje del protocolo P2P **MUST** ir precedido de un prefijo
de 4 bytes propio de la red, y **MUST** rechazarse cualquier mensaje cuyo prefijo no coincida.

```
mainnet:  9e 0f 10 44
testnet:  bb 79 64 3f
```

> Derivados: primeros 4 bytes de `SHA3-256("ZEROX/mainnet/magic")` y
> `SHA3-256("ZEROX/testnet/magic")`. Reproducibles por cualquiera, en lugar de inventados.
> Ambos cumplen el criterio que Bitcoin documenta para los suyos —*"designed to be unlikely to
> occur in normal data [...] not valid as UTF-8"*—: verificado, ninguna de las dos secuencias es
> UTF-8 válido.
>
> **Este prefijo, y no el hash del génesis, es lo que impide que un nodo de una red hable por error
> con un peer de otra.** El génesis distinto (C-GEN-04) evita que las cadenas se confundan; el
> prefijo evita que los nodos siquiera se saluden.

**`<<PENDIENTE: puerto por defecto y versión de protocolo P2P — Fase 3>>`**

### 16.2 · Propagación de bloques — requisito de Fase 3, NO consenso

> Esta subsección **no es normativa para el consenso**. Es transporte: cambia *cómo viaja* un
> bloque, no *qué bloque es válido*. Un nodo que no lo implemente funciona igual, solo gasta más
> ancho de banda. **No puede provocar un split de cadena**; el peor caso es que no ayude.

**R-NET-01 · Relé compacto de bloques.** El nodo **MUST** implementar relé compacto de bloques al
estilo **BIP 152**: en lugar del bloque completo se anuncia un boceto —cabecera más identificadores
cortos de las transacciones— y el par solicita únicamente las que le falten. **MUST** negociarse por
conexión y **MUST** degradar a envío del bloque completo si el par no lo soporta o si faltan
demasiadas transacciones.

**Por qué está aquí y no en la Fase 3 sin más.** La tasa de huérfanos es
`≈ 1 − e^(−t_prop/T)` (§6.1, y `DECISIONES.md` §2). Reducir `t_prop` es la única forma de bajarla
sin tocar consenso:

```
Bloque de 200 KB, ~571 transacciones
Boceto ≈ 92 B (cabecera) + 571 × 6 B (IDs cortos) ≈ 3,6 KB   →  ~55× menos datos por el cable
```

| | `t_prop` estimado | Huérfanos a `T = 120 s` |
|---|---|---|
| Sin relé compacto | ~2 s | ~1,65 % |
| **Con relé compacto** | ~0,5 s | **~0,42 %** |

*Estimaciones de sobremesa. Deben medirse sobre gossipsub real antes de darlas por buenas.*

**Qué mejora — y qué no.** **NO mejora el TPS**: no toca el tamaño de bloque ni `T`, que son los dos
factores que lo fijan. Mejora la **robustez**, en tres frentes concretos:
1. Menos hashrate honesto desperdiciado ⇒ la fracción **efectiva** de un atacante baja ⇒ la tabla de
   confirmaciones de §13 mejora.
2. Menos presión de centralización sobre el minero pequeño (un minero grande nunca compite consigo
   mismo, y esa ventaja escala con la tasa de huérfanos).
3. Menos reorganizaciones de un bloque ⇒ **menos veces que Cortex ve aparecer y desaparecer un
   pago**. Beneficio directo de producto.

**R-NET-02 · Los identificadores cortos MUST llevar sal por bloque.** La función que deriva los
identificadores cortos **MUST** tomar una clave dependiente de la cabecera del bloque, de modo que
un atacante no pueda precomputar transacciones cuyos identificadores colisionen y forzar viajes de
ida y vuelta indefinidos.

> ⚠️ **El mecanismo exacto MUST verificarse contra BIP 152 antes de implementarlo** — la función con
> clave, la derivación de la sal, el saludo de negociación y los dos modos de operación
> (alto/bajo ancho de banda). No se escribe de memoria. Encargo de investigación de Fase 3.

**Limitación conocida.** El relé compacto rinde bien cuando los mempools están sincronizados.
Durante un pico de demanda hay muchas transacciones frescas, los mempools divergen y hacen falta
viajes extra — **precisamente cuando los huérfanos más importan**. Mitigación benigna: que Cortex
retransmita transacciones de forma amplia y agresiva mantiene los mempools sincronizados, y
**beneficia también a quien no usa Cortex**, porque las transacciones acaban en la red P2P igual. No
crea dependencia ni poder de censura.

**Techo que el relé compacto NO puede romper.** `t_prop` es *número de saltos × latencia por salto*,
no solo ancho de banda. Con una malla de gossipsub de grado ~8 el diámetro son ~4-5 saltos; a 100 ms
por salto eso ya son 0,4-0,5 s pese el bloque lo que pese. El relé compacto **lleva al suelo, no por
debajo**.

---

## 17 · Decisiones abiertas que bloquean este documento

### Abiertas — decisiones

| ID | Bloquea | Resumen | Para quién |
|---|---|---|---|
| **P-005** | §7.3 | Racional exacto de la corrección del sesgo del clamp (≈0,9975) | **D9** — matemáticas, no a ojo |
| **P-006** | §11 | ¿Sirve `Σ 2^256/(target+1)` con dificultad muy variable? D2 argumenta que el sesgo `(N−1)/N` de zawy afecta a la *estimación* de hashrate, no al *acumulador* — falta relectura verbatim de #58/#82 | **D9** |
| **P-014** | §13 | 🆕 La rama privada del atacante tiene su **propio LWMA** y se abarata sola tras `N=90`. Las tablas de confirmación asumen dificultad constante ⇒ las filas `q ≥ 40 %` podrían ser optimistas | **D9** |
| **P-015** | §11 | ¿Puede un minero *grindear* el nonce buscando hash bajo para ganar desempates (C-FORK-04)? | **D8** |
| **P-016** | §12 | Camino de recuperación de un nodo detenido por C-REORG-07 tras una partición larga | **D3** |
| **P-017** | §15, §16 | Mensaje, timestamp y nonce del génesis (mainnet y testnet) · puerto por defecto | Katana, el día del lanzamiento |
| **P-018** | §16.2 | Mecanismo exacto de BIP 152: función con clave de los IDs cortos, derivación de la sal, saludo de negociación, modos alto/bajo ancho de banda. **No escribir de memoria** | Investigación, Fase 3 |
| **P-019** | §16.2 | Medir `t_prop` real sobre gossipsub con bloques de 100-200 KB. Las cifras de §16.2 son estimaciones | **D3** |
| **P-020** | §11–§13 | ¿P2K o P2KH? 17 % de throughput contra una capa de defensa post-cuántica. **Gratis hasta el génesis** | Katana |
| **P-011b** | §5.5 | Calibración de `REF_WEIGHT` con un modelo de coste de atacante | **D2** + **D8** |
| **P-011c** | §5.5 | ¿Anclar solo a `Mlt` abarata el spam si la demanda colapsa? | **D8** — revisión adversarial |
| **P-009g** | §6.5 (v1.1) | ¿Necesita Orchard un *clawback* análogo al de bulletproofs? | **D1** |
| **P-004c** | §7.3 | `TARGET_INICIAL` — fijado en `POW_LIMIT`, revisable hasta crear el génesis | Katana, antes del lanzamiento |

### Cubiertas desde la auditoría de cobertura

Aquella auditoría concluyó que el SPEC sabía **validar un bloque aislado** pero no **llevar una
cadena**. Los seis huecos están escritos:

| Sección | Reglas |
|---|---|
| §11 · Selección de cadena | C-FORK-01..04 |
| §12 · Reorganizaciones | C-REORG-01..07 |
| §13 · Profundidad de confirmación | política de producto, no normativa |
| §14 · Activación de cambios de consenso | C-UPG-01..08 |
| §15 · Bloque génesis | C-GEN-01..05 |
| §16 · Parámetros de red | C-NET-01 |

### Aparcadas — evaluadas, con factura desglosada, NO adoptadas

| Decisión | Qué compraría | Qué costaría | Estado |
|---|---|---|---|
| **Bajar `T` a 30 s** | 4× TPS y 4× menos latencia. Con relé compacto (R-NET-01) la tasa de huérfanos quedaría en ~1,65 %, la misma que hoy a 120 s | 🔴 **`FTL = N·T/20` bajaría a 135 s**: un nodo con 2 min de deriva de reloj produciría bloques rechazados por la red — deja fuera a mineros honestos por tener un reloj normal. Habría que **desacoplar `FTL` de `T`**, que es rediseñar una regla de timestamps. Además: rederivar `N_LARGO`, `k`, `T_FLOOR`, `ST_CAP` · ventana MTP de 22 → 5,5 min · IBD de cabeceras de 484 MB → **1,93 GB a 20 años, para siempre** · ×4 la sobrecarga fija por bloque | **No en v1.** Solo reconsiderable **antes del génesis** y con `t_prop` medido, no estimado |
| **P2K en lugar de P2KH** (guardar la clave pública en la salida en vez de su hash) | **17 % menos bytes** por transacción (368 → 304 B) ⇒ 2,8 TPS en vez de 2,4, gratis. La dirección mide lo mismo: bech32 de 32 B en ambos casos, cero cambio de UX. En Bitcoin el hash ahorra espacio porque su hash son 20 B y su pubkey 33; en ZEROX el hash **son 32 B, exactamente lo que mide una clave Ed25519** — no ahorra nada | La clave pública queda expuesta antes de gastar. Contra un adversario cuántico con Shor, P2KH da una ventana de protección hasta el momento del gasto. Argumento real aunque especulativo, y la razón por la que casi todas las cadenas mantienen el hash | **Decisión de Katana, gratis hasta el génesis.** Después, hard fork |
| **GHOST / recompensas de tío** | Desacopla la tasa de huérfanos de la pérdida de seguridad (el enfoque de Ethereum, que le permitió bloques de 13 s con 10-15 % de tíos) | Un subsistema de consenso entero: recompensas de tío, reglas de inclusión, su propio espacio de ataques | **Descartado.** Superficie de ataque desproporcionada |

### Cerradas — 2026-09-04

| ID | Sección | Resolución |
|---|---|---|
| **P-001** | §3.1 | **SHA3-256 (FIPS 202)** |
| **P-002** | §8.1 | **1 000 000 000 ZZK** · **32 ZZK/bloque** · madurez 100 |
| **P-003** | §7.3 | `N = 90`, **con** suelo `T_FLOOR` |
| **P-004** | §6.1, §7.2, §7.3 | `POW_LIMIT = 2^224 − 1` · `MIN_TARGET = 2^64` · `TARGET_INICIAL = POW_LIMIT` 🔶 · `timestamp: u64` |
| **P-009a–f** | §6.5, §8.1 | Bloque dinámico parametrizado; **el tail no es suelo por bloque** (C-EMIT-07) |
| **P-010** | §5.3 | `ZX_VALUE_SANITY_LIMIT = 2^62` brek |
| — | §2.3 | Dirección de **32 bytes**, sin truncar |
| — | §5.3 | `MAX_MULTISIG_KEYS = 16` |
| — | §6.3 | Merkle: **relleno con nulo** (evita CVE-2012-2459) |
| — | §6.5, §5.4 | `MAX_TX_WEIGHT = ZONA_LIBRE = 100 000` (C-WGT-11, C-TX-18) |
| **P-011** | §5.4, §5.5 | Tarifa mínima **NO es consenso** (C-TX-15 corregida); fórmula dinámica anclada a `Mlt` |
| **P-012** | §11 | Desempate **determinista por menor hash de tip** (C-FORK-04), estilo Zebra, no orden de llegada |
| **P-013** | §12 | `MAX_REORG_LENGTH = 99` con **fail-stop**. Finalidad por protocolo a las 100 confirmaciones |
| — | §14 | `CONSENSUS_BRANCH_ID` en la **cabecera** (C-UPG-05) — cierra el agujero de *wipe-out* que ZIP-200 dejó sin implementar |
| — | §16.2 | **Relé compacto de bloques** (R-NET-01/02, estilo BIP 152). Transporte, **no consenso** ⇒ no puede partir la cadena; el peor caso es que no ayude. Huérfanos ~1,65 % → ~0,42 % |

🔶 `TARGET_INICIAL` es la única cerrada que sigue siendo **revisable hasta crear el génesis**.

---

## 18 · Trazabilidad

Cada sección de este documento se apoya en investigación con fuente primaria verificada:

| Sección | Investigación | Verificación empírica realizada |
|---|---|---|
| §3 Hash | `research/sha3-fips202.md`, `sha3-referencias.md` | 860 vectores CAVP del NIST |
| §3 (kernel actual) | `research/sha3-kernel-audit.md` | Emulación línea a línea; 0/860 |
| §4 Preimagen | `research/zip244.md` | Reimplementación validada, 10/10 txid, 46/46 sighash |
| §7.3 Dificultad | `research/lwma1.md` | 6 implementaciones reales inspeccionadas |
| §2.4 Serialización | `research/capnproto-canon.md` | Patrón contrastado con Cosmos, BCS, Zcash |
| §9 Pool blindado | `research/orchard-bundle.md`, `orchard-math-verification.md` | 200 tx de mainnet; derivación numérica |
| §6.5 Peso de bloque | `research/dynamic-blocksize.md` | 2 implementaciones (monero@3d3920d7, cuprate@4383f0d6); 6 suites de vectores localizadas |
| §5.5 Tarifa | `research/dynamic-fee.md` | Código de 2 implementaciones; corrigió un error de capa en este SPEC |
| §11–§13 Fork choice, reorgs | `research/fork-choice-reorg.md` | 4 implementaciones (bitcoin, zebra, zcashd, monero); 3 papers con tablas numéricas |
| §14–§16 Upgrades, génesis, red | `research/upgrades-genesis.md` | ZIP-200, BIP-9/8, código de bitcoin/zcash/monero |
