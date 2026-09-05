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

**C-ENC-06** · Las direcciones se codifican en **bech32m** (BIP-350) con estos HRP:

| HRP | Red y pool |
|---|---|
| `zzk` | mainnet, transparente |
| `zzs` | mainnet, blindada *(reservado, v1.1)* |
| `tzzk` | testnet, transparente |

**C-ENC-06b · El algoritmo de checksum MUST exigirse explícitamente.** Un decodificador **MUST**
rechazar una dirección cuyo checksum sea bech32 (BIP-173) aunque el resto sea válido. **MUST NOT**
usarse un decodificador permisivo que acepte cualquiera de los dos.

> ⚠️ **Cambiado 2026-09-04 al implementar. Antes decía bech32 (BIP-173).**
>
> **Por qué bech32m.** BIP-350 existe precisamente porque bech32 tiene un defecto de inserción
> documentado: en una cadena cuyo último carácter de datos es `p`, insertar o borrar caracteres `q`
> justo antes **no invalida el checksum**. Bitcoin conserva bech32 en segwit v0 por compatibilidad
> hacia atrás; ZEROX nace sin ningún legado que respetar. La diferencia es una constante —`1` frente
> a `0x2bc830a3`— y cuesta cero. Hay un test en `zx-core` que **reproduce el defecto** en bech32 y
> comprueba su ausencia en bech32m, en vez de citar el BIP y confiar.
>
> **Por qué C-ENC-06b, que es lo menos obvio.** La función de conveniencia `bech32::decode()` del
> crate acepta **los dos** algoritmos: prueba bech32m y, si falla, se conforma con bech32. Para un
> parser de direcciones eso es **maleabilidad** — dos cadenas distintas decodificarían a la misma
> dirección, y un sistema de pagos que las trate como identificadores distintos se descuadra.
> Verificado en el código del crate, `bech32-0.12.0/src/lib.rs:218-233`.

**C-ENC-07 · Una dirección transparente codifica la CLAVE PÚBLICA Ed25519, 32 bytes.** No su hash.
Un decodificador **MUST** rechazar cualquier longitud distinta de 32.

Los 32 bytes **MUST NOT** validarse como punto de la curva al decodificar la dirección: ZIP-215
exige aceptar codificaciones no canónicas (C-SIG-03), y rechazarlas aquí divergiría del verificador.

> ⚠️ **Cambiado 2026-09-04 — P-020 cerrado: ZEROX usa P2K, no P2KH.** Antes decía
> `SHA3-256(pubkey)`.
>
> **El hallazgo que lo desencadenó.** `SHA3-256` produce 32 bytes y una clave Ed25519 mide
> **exactamente** 32 bytes. Hashear no acortaba la dirección **ni un carácter**: solo obligaba a
> repetir la clave en el testigo al gastar. Coste medido: **32 bytes por entrada**, verificado por el
> test `p2k_ahorra_32_bytes_por_entrada` (una 2-in/2-out pasa de **371 a 307** unidades de peso,
> **−17,2 %**).
>
> **Por qué la contrapartida post-cuántica no compensa aquí.** P2KH retrasa la exposición de la clave
> del momento de *recibir* al de *gastar*, lo que en Bitcoin se cita como capa de defensa frente a un
> CRQC. En ZEROX ese argumento no se sostiene, y la razón es el pool blindado: **Halo2 sobre Pallas
> es solo *computacionalmente* binding bajo logaritmo discreto.** Un adversario cuántico no se limita
> a desanonimizar el pool — **forja pruebas**, es decir, inflación ilimitada. Proteger con un hash un
> subconjunto del pool transparente (solo las UTXO nunca gastadas) mientras el otro pool cae entero
> por un fallo peor es poner una cerradura al lado de un hueco sin pared.
>
> **Dónde vive de verdad la defensa post-cuántica de ZEROX:** en un **network upgrade** que añada una
> variante de `Lock` con un esquema de firma PQ, activada por altura con su propio
> `CONSENSUS_BRANCH_ID` (§14). Esa maquinaria ya está construida y probada. Añadir la variante
> después **no cuesta nada**: es exactamente para lo que sirve el branch id. La respuesta PQ es un
> plan versionado, no un formato de dirección.
>
> **Lo que sí se pierde, dicho sin rodeos:** con P2K la clave queda expuesta al **recibir**. Para una
> moneda de ahorro eso pesaría; para un raíl de pagos cuya vía recomendada de tenencia es el pool
> blindado, no.

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

### 2.4 · Serialización de red y disco — `C-WIRE`

> **No es la preimagen, y la diferencia importa.** La preimagen (§4) es un **árbol de hashes**: el
> txid no es la concatenación de los campos de una transacción, sino la raíz de un árbol de digests
> con separación de dominio. De una preimagen no se puede recuperar el objeto, porque no contiene
> los datos sino sus hashes. Esto de aquí es lo otro: lo que viaja por la red y se guarda en disco.

**C-WIRE-01 · La cabecera que viaja son los MISMOS bytes que se hashean.** La codificación de una
`BlockHeader` es exactamente la preimagen del PoW (§7.1) **sin su etiqueta de dominio**: 92 bytes,
mismo orden de campos.

> No es una optimización, es una restricción: impide que exista una **segunda descripción** del
> formato de cabecera capaz de divergir de la primera. Es la lección de **H-005**, donde un offset
> transcrito a mano dejó de cuadrar al cambiar el tipo de `timestamp`.
>
> ⚠️ **Y volvió a pasar con el tamaño, en la documentación.** Este SPEC decía "112 bytes" en tres
> sitios, y los comentarios del código en tres más. El tamaño real es
> `4 + 32 + 32 + 8 + 4 + 8 + 4 = `**92**, y ninguna de las seis menciones lo derivaba de
> `TAMANO_CABECERA`: todas eran el número escrito a mano. No era explotable —los límites de wire
> usan la constante, no el comentario— pero es exactamente la misma clase de fallo, en la capa de
> la documentación. Corregido 2026-09-05 tras la revisión adversarial del sincronizador.
>
> Corolario: **el decodificador MUST vivir junto al codificador** (`zx-core::wire`). Un
> decodificador en el crate de red re-describe el orden de los campos, y eso es exactamente el
> patrón que se quiere prohibir.

**C-WIRE-02 · Codificación de `Lock`.** La de C-TX-09b, sin cambios. Longitudes: 33 para `PubKey`,
`3 + 32n` para `MultiSig` con `n ≤ 16`, 101 para `Htlc`.

**C-WIRE-03 · Codificación de una transacción con sus testigos.**

```
version(4 LE) ‖ lock_time(4 LE) ‖ expiry_height(4 LE)
‖ CompactSize(n_in)  ‖ n_in  × [ prev_txid(32) ‖ prev_index(4 LE) ‖ sequence(4 LE) ]
‖ CompactSize(n_out) ‖ n_out × [ value(8 LE, i64) ‖ lock (C-WIRE-02) ]
‖ CompactSize(n_wit) ‖ n_wit × [ CompactSize(len) ‖ bytes(len) ]
```

Los testigos van **fuera** de la transacción, no dentro: son datos de **autorización**, el txid no
los incluye, y eso es lo que la hace no maleable (C-TX-01).

> **La invariante que ata esto al consenso:** la longitud de esta codificación **MUST** ser igual al
> peso que calcula la fórmula de C-WGT-02.
>
> Y son **dos definiciones independientes a propósito**. Definir el peso como `bytes.len()` las
> haría coincidir por construcción y volvería a atar el consenso al serializador — cambiar un byte
> del formato cambiaría el peso de todas las transacciones, y con él la validez de los bloques y el
> subsidio. Es exactamente lo que **H-006** arregló.
>
> Así que no se acoplan: se comprueban una contra otra sobre transacciones generadas al azar, y en
> los umbrales de `CompactSize` (252/253, 65 535/65 536) construidos a mano. Test diferencial
> `wire_peso_differential`. Si un día divergen, falla un test — no el consenso, en producción.

**C-WIRE-07 · Codificación de un bloque completo.**

```
cabecera(92) ‖ CompactSize(n_tx) ‖ n_tx × [ transacción con sus testigos (C-WIRE-03) ]
```

Los testigos van **dentro de cada transacción**, no en una lista paralela.

> Que la correspondencia `tx ↔ testigo` sea **posicional por construcción** elimina una clase entera
> de fallo: con dos listas separadas, una puede tener más elementos que la otra, y decidir qué hacer
> entonces es una regla más que escribir y otra que dos implementaciones pueden interpretar
> distinto.
>
> **El códec no opina sobre validez.** Un bloque sin transacciones da la vuelta aunque C-BLK-07 exija
> coinbase: mezclar codificación y reglas de consenso es lo que hace que un cambio de reglas rompa
> el formato.

**C-WIRE-04 · Todo contador declarado MUST acotarse ANTES de reservar memoria por él.** Un lector
**MUST** rechazar un `CompactSize` que declare más de `MAX_ELEMENTOS_DECLARADOS = 1 000 000`
elementos, **antes** de leer ninguno.

> **No es una regla de consenso, es una cota del *parser*.** El límite real lo pone `MAX_TX_WEIGHT`,
> pero ese se comprueba mucho más tarde — y "más tarde" es demasiado tarde cuando la reserva ya
> ocurrió. Un peer declara 2⁶⁴−1 entradas, manda veinte bytes, y el nodo reserva por lo declarado.
>
> Es el mismo patrón que lighthouse prueba **mintiendo en el prefijo de longitud** en vez de
> construir el payload real, y por la misma razón: el rechazo debe ocurrir leyendo el contador, no
> leyendo el cuerpo.

**C-WIRE-05 · Ningún dato de red puede hacer entrar en pánico a un lector.** Los lectores **MUST**
devolver `Result` ante cualquier entrada, incluida basura arbitraria.

> El workspace prohíbe `panic`, `unwrap` y `expect` en código de producción, pero eso **no** cubre
> un índice fuera de rango. Un parser de datos de red que entra en pánico es un DoS remoto de una
> línea. Se comprueba con property tests que alimentan bytes aleatorios a los tres lectores.

**C-WIRE-06 · Por qué a mano y no Cap'n Proto, para los mensajes de sincronización.**
`DECISIONES.md` eligió Cap'n Proto para wire y disco, y **sigue siendo la elección** para el
almacenamiento y para el intercambio de plantillas con el minero C++, donde el código generado para
dos lenguajes paga su precio. Para los **mensajes de sincronización** se decidió distinto:

| | Razón |
|---|---|
| **Superficie de ataque** | Estos bytes vienen de un peer no autenticado. El parser de Cap'n Proto hace aritmética de punteros sobre datos hostiles; su crate de Rust tuvo `RUSTSEC-2025-0143` (UB en `get_root_unchecked`) y el bug de canonicalización de 2018 vivía en el manejo de *far pointers* |
| **Una sola descripción** | Un `BlockHeader` ya tiene un orden de campos byte a byte fijado por el SPEC. Describirlo otra vez en un `.capnp` crea **dos** descripciones del mismo objeto — H-005 y H-006 otra vez |
| **Sin paso de compilación** | Ni `capnpc`, ni esquema, ni código generado que auditar |

> Coste asumido: se pierde el acceso *zero-copy*. No está en el camino caliente — procesar un bloque
> cuesta verificar firmas, no copiar 200 KB. Ver `research/capnproto-canon.md`, cuya conclusión ya
> era que ningún proyecto que necesite esto para consenso confía en el modo canónico de un
> serializador de propósito general.

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

**C-TX-06b · Formato del testigo, por tipo de `Lock`. El testigo NO lleva la clave** (P2K, P-020):
la aporta el `Lock` de la salida que se gasta.

```
PubKey   := sig(64)                                                    64 B

MultiSig := k × [ indice(1) ‖ sig(64) ]                                k·65 B
            con los índices ESTRICTAMENTE CRECIENTES

Htlc     := 0x00 ‖ CompactSize(n) ‖ preimagen(n) ‖ sig(64)                vía preimagen
          | 0x01 ‖ sig(64)                                                vía timeout
```

> ⚠️ **Cambiado 2026-09-04 con P-020.** Antes cada rama empezaba por `pubkey(32)`. Con P2K esa clave
> es **redundante** —está en el `Lock`— y su presencia costaba 32 B por entrada.
>
> Efecto lateral de seguridad, no solo de tamaño: desaparece la comprobación *"¿la clave del testigo
> corresponde a la salida?"*. La clave **es** la de la salida. Una comprobación que no existe no se
> puede olvidar, ni implementar mal en un segundo nodo.

**C-TX-06c · El testigo MUST consumirse por completo.** Tras interpretar el testigo según su tipo,
**MUST NOT** quedar ningún byte sin consumir. Un testigo con relleno sobrante **MUST** rechazarse.

> ⚠️ **Añadido 2026-09-04 al implementar §5.** El SPEC decía "el contenido depende del tipo" y no lo
> definía. No podía quedar así: sin formato fijado no hay dos implementaciones que coincidan.
>
> **Por qué índices estrictamente crecientes en `MultiSig`**, y no un escaneo ordenado estilo
> Bitcoin: los índices explícitos hacen la verificación `O(k)` en vez de `O(n·k)`, y la
> **monotonía estricta** cierra dos agujeros de una vez — elimina la maleabilidad por reordenación
> (solo hay un orden válido para el mismo conjunto de firmas) y hace imposible repetir una clave sin
> necesidad de comprobarlo aparte. Además evita reproducir el escaneo de `OP_CHECKMULTISIG`, con su
> conocido error de desplazamiento. El testigo **MUST** traer exactamente `k` entradas: ni menos, ni
> una de más.
>
> **Por qué C-TX-06c.** Sin ella, rellenar el testigo con basura no invalida la transacción: el
> `txid` no cambia —el testigo es dato de autorización— y el atacante consigue **banda y disco
> ilimitados, gratis**. Es exactamente el patrón de GHSA-2x4w-pxqw-58v9, el CVE real de Orchard
> donde `sizeProofs` no se validaba como regla de consenso. La longitud de la preimagen del HTLC
> queda acotada por `MAX_TX_WEIGHT` (C-WGT-11), así que no necesita una constante propia.

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
Lock ::= 0x00 PubKey  { pubkey: [u8; 32] }
       | 0x01 MultiSig{ k: u8, pubkeys: [[u8; 32]] }
       | 0x02 Htlc    { hash: [u8;32], receiver: [u8;32], sender: [u8;32], timeout: u32 }
```

Las claves van **en claro**, no hasheadas: **P2K, no P2KH** (P-020, razonado en C-ENC-07). El
`hash` del `Htlc` sí es un hash — `SHA3-256(preimagen)` — y no debe confundirse con una clave.

| Tipo | Condición de gasto |
|---|---|
| `PubKey` | Firma válida de **la** clave que la salida declara |
| `MultiSig` | `k` firmas válidas de `k` claves distintas del conjunto |
| `Htlc` | *(a)* preimagen `p` con `SHA3-256(p) = hash` **y** firma de `receiver`; o *(b)* altura del bloque `≥ timeout` **y** firma de `sender` |

**C-TX-09b · Codificación canónica de `Lock`.** Un `Lock` se codifica como
`discriminante(1) ‖ campos`, con los campos en el orden de la declaración de arriba. La lista de
`MultiSig` va precedida de su longitud en `CompactSize`:

```
PubKey   := 0x00 ‖ pubkey(32)
MultiSig := 0x01 ‖ k(1) ‖ CompactSize(n) ‖ pubkey₀(32) ‖ … ‖ pubkeyₙ₋₁(32)
Htlc     := 0x02 ‖ hash(32) ‖ receiver_pubkey(32) ‖ sender_pubkey(32) ‖ timeout(4 LE)
```

Los tamaños **no cambian** respecto a P2KH —32 bytes en ambos casos—, solo el contenido: la clave en
claro en lugar de su hash (P-020). El `hash(32)` del `Htlc` **sigue siendo un hash**: es
`SHA3-256(preimagen)`, no una clave.

> Añadido 2026-09-04 al implementar §4. El SPEC definía la estructura de `Lock` pero no la
> codificación de la lista de `MultiSig`, y eso **no puede quedar implícito**: `scripts_digest`
> (§4.3) concatena varios locks seguidos, así que sin un delimitador de longitud dos secuencias
> distintas de locks podrían producir los mismos bytes y por tanto el mismo digest. `CompactSize` es
> la única lectura coherente con §2.2, que lo define justamente para "contadores y longitudes", y
> su minimalidad ya está cubierta por C-ENC-05.

**C-TX-10** · El byte discriminante **MUST** estar en el conjunto definido. Valores desconocidos
**MUST** rechazarse (no tratarse como "gastable por cualquiera").

**C-TX-11** · En `MultiSig`, `1 ≤ k ≤ n` donde `n = len(pubkeys)`, y
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

Con `REF_WEIGHT = 3000` y `Mf = ZONA_LIBRE = 100 000`:

| Régimen | `recompensa_base` | tarifa/peso | tx típica de 350 B |
|---|---|---|---|
| Lanzamiento | 1,907·10¹¹ brek | 54 359 brek | **0,19 ZZK** |
| Cola (año 8,16+) | 3,2·10⁹ brek | 912 brek | **0,0032 ZZK** |

> ⚠️ **La tarifa varía ~60× a lo largo de la vida de la cadena**, porque escala con la recompensa
> base. Esta nota citaba solo la cifra de cola; un test que la comprobaba contra la recompensa de
> lanzamiento **falló**, y así se descubrió que faltaba la mitad del cuadro. Ambos números son
> correctos, cada uno en su régimen.
>
> ⚠️ **La tarifa satura en 1 brek por unidad de peso cuando `Mlt > √(base·REF_WEIGHT) ≈ 23,9 MB`.**
> Por encima de esa mediana el mínimo deja de escalar, y todo el antispam recae en la penalización
> de C-EMIT-06. Es una propiedad real del diseño que conviene tener presente si la cadena creciera
> hasta medianas de decenas de megabytes.
>
> Y una consecuencia del suelo: con `Mlt` ya en `ZONA_LIBRE`, la tarifa mínima **está en su máximo**
> y no puede subir más, porque `MedianaLarga` no admite valores por debajo del suelo.

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

**C-WGT-02 · El peso se calcula con una fórmula del protocolo, NO con el tamaño que produzca el
serializador.**

```
peso(tx) = 12                                             // version ‖ lock_time ‖ expiry_height
         + |CompactSize(n_in)|  + n_in  · 40              // prev_txid(32) ‖ index(4) ‖ sequence(4)
         + |CompactSize(n_out)| + Σⱼ (8 + |lock_j|)       // value(8) ‖ lock canónico (C-TX-09b)
         + |CompactSize(n_wit)| + Σᵢ (|CompactSize(lenᵢ)| + lenᵢ)
```

`|lock|` es la longitud de la codificación canónica de C-TX-09b: 33 para `PubKey`, `2 + |CompactSize(n)| + 32n`
para `MultiSig`, y 101 para `Htlc`.

Con P2K (P-020) el término del testigo es el que encoge: una entrada `PubKey` aporta
`|CompactSize(64)| + 64 = 65` en vez de `97`. Cuenta completa de una transacción 2-in/2-out:

```
12 + CS(2) + 2·40 + CS(2) + 2·(8+33) + CS(2) + 2·(CS(64)+64)  =  307      (P2K)
12 + CS(2) + 2·40 + CS(2) + 2·(8+33) + CS(2) + 2·(CS(96)+96)  =  371      (P2KH)
```

**−64 unidades, −17,2 %.** Reproducido en `zx-consensus`, test `p2k_ahorra_32_bytes_por_entrada`, que
calcula las dos cifras en vez de citarlas.

> ⚠️ **Corregido 2026-09-04 al implementar §5.4. Antes decía `weight(tx) = tamaño_serializado(tx)`,
> y eso contradecía directamente a C-ENC-08.**
>
> C-ENC-08 declara que la serialización Cap'n Proto **no es consensus-critical**, y su propia
> motivación dice que su modo canónico *"no garantiza bytes idénticos entre implementaciones"*. Pero
> el peso alimenta C-WGT-09 (validez de bloque) y C-EMIT-06 (subsidio del minero): si el peso
> dependiera del serializador, **dos nodos calcularían límites y subsidios distintos para el mismo
> bloque**. Split de cadena, y por una vía que ninguna suite de tests de hashing detectaría.
>
> La fórmula de arriba es determinista, está definida por el protocolo y es independiente de
> cualquier serializador. Incluye el testigo porque el testigo ocupa banda y disco reales, que es lo
> que el peso existe para acotar.
>
> Consecuencia práctica: el tamaño en el cable puede diferir del peso de consenso. **Es correcto y
> deliberado.** El peso es una magnitud del protocolo, no una medida del encoder.

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
> `1,7×` da ≈14,2× de expansión anual en Monero; con nuestra ventana de un año, ≈2,9×.
>
> ⚠️ **Corregido 2026-09-04.** Esta nota decía que `Mlt + (Mlt·7)/10` **no** es idéntica a
> `(Mlt·17)/10` bajo truncamiento entero. **Es falso**: como `Mlt` es entero y `⌊x+n⌋ = ⌊x⌋+n`,
> las dos formas coinciden siempre. Verificado sobre 300 000 valores, incluidos aleatorios hasta
> 2⁶³. La afirmación venía de `research/dynamic-blocksize.md` y se propagó aquí sin comprobarse; la
> cazó un test de `zx-consensus` que intentaba encontrar un contraejemplo y no lo encontró.
>
> **Se conserva la forma literal igualmente, por una razón distinta y real:** el margen de
> desbordamiento. `Mlt·17` desborda `u64` a partir de `1,09·10¹⁸`, `Mlt·7` a partir de
> `2,64·10¹⁸` — 2,4× más holgura — y mantiene identidad byte a byte con los valores intermedios de
> la implementación de referencia.

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

El orden de `min`/`max` **MUST NOT** reordenarse.

> ⚠️ **Justificación corregida 2026-09-04 por D9.** Esta regla decía *"cambia la semántica en los
> empates"*. **Es falso**: bajo el invariante `Mlt ≥ ZONA_LIBRE` que impone C-WGT-05, los
> reordenamientos razonables —conmutar el `max` interno, aplicar la ley distributiva de retículo,
> mover el suelo antes del techo— dan resultados **idénticos** en 200 000 casos, con empates
> exactos incluidos. Y el `max(…, ZONA_LIBRE)` final es, dado ese invariante,
> **matemáticamente redundante**.
>
> La razón real es otra y es más interesante: la equivalencia **depende de una precondición que
> vive fuera de esta regla**. Violando `Mlt ≥ ZONA_LIBRE` —por ejemplo `Mlt = 1000`, `Mst = 10⁸`—
> el orden original da `M = 100 000` y un reordenamiento da `42 900`: **2,3× menos**, porque el
> techo de ráfaga `50·1000` atrapa el valor antes de que el suelo lo rescate.
>
> Una regla de consenso no debe apoyarse en una condición que no puede comprobar. En `zx-consensus`
> la precondición pasó a estar **en el tipo** (`MedianaLarga`), igual que C-WGT-10 hizo con la resta
> `2M − x`.

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
> `TARGET_INICIAL` de **testnet** y el `powLimit` de Bitcoin.
>
> Definir la canonicidad como punto fijo del codificador no puede desincronizarse de él, porque
> **es** él. Enumerar reglas estructurales sí puede, y en el primer intento ya se equivocó.
>
> **D9 verificó la propiedad de forma exhaustiva, no muestreada:** los 167 116 800 pares
> (exponente, mantisa) válidos dentro de `[MIN_TARGET, POW_LIMIT]`. Cero fallos de identidad, cero
> colisiones. Inyectividad y `decodificar ∘ codificar = id` quedan **demostradas** sobre el dominio
> que ZEROX usa.
>
> ⚠️ **Y refutadas fuera de él.** Para todo `target < 2¹⁶`, `codificar` produce un `bits` con
> exponente `< 3` que `decodificar` **rechaza**: su propia salida no vuelve a decodificar a nada.
> Ejemplo mínimo: `codificar(0) = 0x00000000`, que `decodificar` rechaza por exponente cero.
>
> Hoy es inalcanzable —`MIN_TARGET = 2⁶⁴` está `2⁴⁸` veces por encima del umbral— pero **la
> propiedad no vale sobre los 256 bits, solo sobre el subrango**. Si algún día se rebajara
> `MIN_TARGET` por debajo de `2¹⁶`, `codificar` produciría `bits` indecodificables.

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

**C-DIFF-02 · Arranque.** Si `1 ≤ H ≤ N`, `siguiente_target(H) = TARGET_INICIAL(red)`. **Cada red
lleva su propio valor:**

```
mainnet:  TARGET_INICIAL_BITS = 0x1c07fff8    TARGET_INICIAL = 0x07fff8 · 2^200
testnet:  TARGET_INICIAL_BITS = 0x1d00ffff    TARGET_INICIAL = 0x00ffff · 2^208
```

Mainnet arranca **exactamente 32 veces más difícil** que testnet, sin resto.

El primer retarget calculado es el de `H = N+1`. La ventana es siempre exactamente `N`;
**MUST NOT** encogerse dinámicamente.

> ⚠️ **Corregido 2026-09-04 al implementar.** Esta regla decía `TARGET_INICIAL = POW_LIMIT =
> 2^224 − 1`, y **eso es inalcanzable**: el formato compacto de C-POW-03 solo representa valores de
> la forma `mantisa × 256^k` con la mantisa de 3 bytes, y `2^224 − 1` son 28 bytes de `0xFF`
> seguidos. Ningún `bits` decodifica a él, así que **el bloque génesis no habría podido llevar el
> target que la regla exigía**. `POW_LIMIT` sigue siendo la **cota** —C-POW-05 rechaza cualquier
> target por encima— y `TARGET_INICIAL` es un valor representable por debajo.

> 🔶 **P-004c · decidido 2026-09-04 (Katana): que el primer bloque dure lo que dura cualquier otro.**
>
> **Qué es esta constante, y qué no es.** Es **una estimación del hashrate del día 1 escrita como un
> target**, y no debe hacer nada más que eso. `0x1c07fff8` está elegida para que el primer bloque
> tarde **`T` = 120 s** si el día del lanzamiento hay **≈1,15 GH/s**.
>
> | Hashrate real el día 1 | Primer bloque | LWMA entra en |
> |---|---|---|
> | 0,25 GH/s | 9,2 min | 13,7 h |
> | 0,5 GH/s | 4,6 min | 6,9 h |
> | **1,15 GH/s** | **2,0 min** ← nominal | **3,0 h** |
> | 2 GH/s | 69 s | 1,7 h |
> | 3 GH/s | 46 s | 1,1 h |
> | 10 GH/s | 14 s | 21 min |
> | 30 GH/s | 4,6 s | 6,9 min |
>
> 1,15 GH/s es el extremo **conservador** de lo que rinde una GPU sola en SHA3-256. Se elige el
> extremo conservador y no el central por la asimetría de esta misma regla: si la estimación se queda
> **corta**, los bloques salen rápido y LWMA lo arregla en una hora; si se pasa de **larga**, los 90
> bloques a dificultad fija van lentos y **nada puede acelerarlos**.
>
> **Dos intentos anteriores, y por qué los dos estaban mal.**
>
> `0x1d00ffff` — el target más fácil representable, justificado por la asimetría de arriba pero
> **sin medir**: con una GPU los bloques salen en 1-4 segundos, no en 120.
>
> `0x1c00ffff` (×256) — elegido para que el primer bloque tardase ~10 min y encarecer así la carrera
> del día 1. **Descartado.** Le daba a esta constante **dos trabajos** —estimar el hashrate y frenar
> el arranque— y cuando dos propósitos comparten una constante deja de poder saberse cuál se está
> ajustando. Es la misma clase de acoplamiento oculto que produjo H-005 y H-006. Además volvía el
> arranque 5× más lento que el régimen normal, un comportamiento artificial que el protocolo no pide
> en ninguna parte.
>
> Si algún día se quiere desincentivar la carrera del día 1, el instrumento correcto es un
> **slow-start explícito sobre la emisión** —una regla propia, visible y discutible, como la de
> Zcash— no un target torcido.
>
> **El límite que no se puede quitar.** Ninguna cadena conoce su hashrate antes de existir, así que
> este número **es un pronóstico**. La única defensa real es **medir en vez de estimar**: cuando
> `zx-miner` funcione (Fase 8) se recalibra desde un benchmark. Revisable hasta el minuto antes de
> crear el génesis, y solo hasta entonces.
>
> **Por qué testnet se queda en el mínimo.** Una red local de tres nodos tiene que producir bloques
> en segundos o los tests de integración no son utilizables. El aislamiento entre redes **no** depende
> de la dificultad: lo garantizan el génesis distinto (C-GEN-04) y el prefijo mágico (C-NET-01).

**C-DIFF-03 · Reconstrucción monótona de solvetimes.** Todo en `i64`:

```
p := ts(H − N − 1)
para j = 1..N:
    h := H − N − 1 + j
    c := si ts(h) > p entonces ts(h) sino p + 1
    st[j] := min(ST_CAP, c − p)
    p := c
```

Invariante: `1 ≤ st[j] ≤ 720`. **MUST NOT** implementarse como `if st < 1 then st = 1`.

> ⚠️ **Precisado 2026-09-04 por D9.** Esta nota decía "por construcción, no por saturación", y solo
> es cierto de una de las dos mitades:
> - **`st ≥ 1` sí es por construcción**: cada timestamp se normaliza contra el anterior **ya
>   normalizado**, así que la resta nunca puede dar ≤ 0 y —lo que de verdad importa— `p` **nunca
>   queda contaminado** por un timestamp retrasado. Ahí está la diferencia con el patrón prohibido.
> - **`st ≤ 720` es saturación**, literalmente `min(ST_CAP, ·)`. Es segura porque **no toca `p`**:
>   recorta el valor que entra en la suma sin desincronizar la reconstrucción.

> *Motivación:* el patrón prohibido es exactamente el que produjo un ataque real — una moneda
> perdió 4 800 bloques en 5 horas porque los timestamps retrasados se convertían en solvetimes
> largos artificiales que hundían la dificultad.

**C-DIFF-04 · Suma ponderada.** `t := Σ_{j=1..N} j · st[j]` en `i64`.

**C-DIFF-05 · Suelo.** `si t < T_FLOOR entonces t := T_FLOOR`.

> ✅ **P-003 RESUELTO (2026-09-04): el suelo se incluye.** Sin él, un atacante que controle la
> ventana con timestamps a `padre+1` multiplica la dificultad por **120 en un solo bloque** y
> congela la cadena al retirarse. Con el suelo, el techo es **×10**.
>
> D9 verificó ambas cifras con aritmética de fracciones exactas: `K/4095 = 120` y `T_FLOOR/K = 1/10`,
> las dos **exactas**. (Con la corrección de sesgo activa serían ×120,3 y ×10,02; como P-005 dejó
> `BIAS = 1`, vuelven a ser exactas.) El mínimo absoluto de `t` es `N(N+1)/2 = 4095`, alcanzado con
> todos los `st[j] = 1`, y `next(t)` es no decreciente en `t`, así que **ninguna secuencia de
> timestamps puede superar el ×10** en un solo bloque.

**C-DIFF-06 · Suma de targets.** `S := Σ_{j=1..N} decode(bits(H − N − 1 + j))` en **U512**, sin
divisiones intermedias.

**C-DIFF-07 · Target siguiente.** En U512, división entera truncada:

```
next := (S · t · BIAS_NUM) / (NK · BIAS_DEN)
```

con **`BIAS_NUM = BIAS_DEN = 1`**: **el sesgo del clamp NO se corrige.** Los dos factores se
conservan en la fórmula, y no se colapsan a `next := S·t/NK`, para que la ausencia de corrección sea
una decisión visible y no una omisión.

> ✅ **P-005 CERRADO 2026-09-04 (Katana) → no se corrige. Sesgo documentado de +0,30 s.**
>
> **Historia, porque el error importa más que el resultado.** Esta regla decía antes que el racional
> sería `99752/100000 ≈ 1 − e⁻⁶`, es decir **menor que 1**. **D9 refutó la dirección**, y la
> refutación se verificó de forma independiente:
>
> - El clamp recorta por arriba, así que `E[min(X, 6T)] = T(1 − e⁻⁶) = 119,70 s < T`.
> - Luego `t < k`, el target **baja**, y los bloques salen **más lentos**. El punto fijo está en
>   `ρ·(1 − e^(−6/ρ)) = 1` → `ρ = 1,00252` → **120,30 s**, que es exactamente la cifra que esta
>   misma nota citaba: el modelo se valida solo.
> - Para llevar `ρ` a 1 haría falta `r = 1/(1 − e⁻⁶) = 1,002486`, es decir **`r > 1`: aflojar**.
>
> Multiplicar por `0,9975` empujaba al revés: desplazaba el punto fijo a **120,61 s**, *más lejos* de
> 120 que no corregir. Peor todavía, la implementación llevaba una aserción de compilación
> `BIAS_NUM < BIAS_DEN` "para que la corrección apriete" — **protegiendo la dirección equivocada**.
> Un candado mal orientado es peor que ningún candado: da confianza en la propiedad contraria a la
> que hace falta.
>
> **Por qué se cierra en "no corregir" y no en "invertirlo".** La **dirección** está demostrada; el
> **valor** no. El campo medio de primer orden da `1,002486`; el Monte Carlo de D9 —float y
> aritmética entera, varias semillas, hasta 300 000 bloques— sitúa el punto fijo empírico en
> `≈1,0045`. **Discrepan**, luego hay efectos de segundo orden sin capturar y, por la regla de
> independencia matemática, esa cifra **no puede presentarse como demostrada**. Fijar en el consenso,
> para siempre, un número que no sabemos justificar, a cambio de un error del 0,25 %, es un mal
> cambio.
>
> **Y el 0,25 % es pequeño en su contexto.** Durante cualquier periodo de crecimiento de hashrate
> LWMA va por detrás y los bloques salen *más rápido* que `T`; ese efecto es de un orden de magnitud
> mayor que el sesgo del clamp. Corregir el clamp con precisión de cuarto decimal en un sistema cuyo
> ruido normal es de varios puntos porcentuales es precisión falsa.
>
> **Consecuencias declaradas, para que estén escritas y no se descubran después:**
>
> | | Valor con `BIAS = 1` |
> |---|---|
> | Solvetime medio en régimen estacionario | **120,30 s**, no 120,00 |
> | Desviación | **+0,25 %** (+0,30 s por bloque) |
> | Bloques al año | 262 139 en vez de 262 800 — **661 menos** |
> | Efecto sobre la emisión | la curva es **por bloque**, así que el calendario se estira un 0,25 %: el hito de los 1000 M llega ~18 días más tarde de lo nominal |
> | Efecto sobre `N_LARGO` | la ventana "de un año" mide en realidad **366 días** |
>
> Ninguna de esas cifras es un fallo: son la definición del sistema, y ahora están escritas.
>
> **Precedente.** Flux, TENT y Tari usan LWMA-1 con clamp y **no corrigen** el sesgo.
>
> **Efecto lateral bueno:** con `BIAS = 1` las cifras de C-DIFF-05 (×120 sin suelo, ×10 con él)
> vuelven a ser **exactas**, verificado por D9 con aritmética de fracciones. Cualquier corrección las
> volvería a ensuciar.
>
> **Alternativa descartada explícitamente:** mover `T` a 119,70 s para que el punto fijo caiga en 120.
> Es la misma constante no demostrada con otro disfraz, y además rompe las cuatro constantes que
> cuelgan de `T` (`FTL`, `N_LARGO`, `T_FLOOR`, `ST_CAP`).
>
> **Qué haría falta para reabrirlo:** un modelo que capture los efectos de segundo orden
> —ponderación no uniforme de la ventana, Jensen sobre `S`— y **reconcilie** el campo medio con el
> Monte Carlo. Mientras las dos estimaciones discrepen, la respuesta correcta es no tocar nada.
>
> **Cota de overflow:** el peor caso real es `S·t·BIAS_NUM < 2²⁶⁹`, no 2²⁶⁵ como decía antes esta
> nota — con `S ≤ N·POW_LIMIT < 2²³¹`, `t ≤ ST_CAP·N(N+1)/2 < 2²²` y `BIAS_NUM < 2¹⁷`. La cota se
> mantiene calculada para `BIAS_NUM` arbitrario, no para 1, porque es la que valdría si P-005 se
> reabriera. Verificado en `zx-consensus`, test `el_numerador_de_c_diff_07_cabe_en_u512`. Es la razón
> de mandar U512 y no U256 en C-DIFF-06.

**C-DIFF-08 · Acotado.** `next := clamp(next, MIN_TARGET, POW_LIMIT)`.

> **`next(t)` es no decreciente en `t`, no estrictamente creciente** — precisado por D9. `⌊·⌋` y los
> clamps preservan el orden **no estricto**, así que `t₁ ≤ t₂ ⟹ next(t₁) ≤ next(t₂)` **siempre**;
> eso es lo que el consenso necesita y está demostrado algebraicamente. Pero la versión estricta
> falla en dos sitios: por debajo de `T_FLOOR` todos los `t` dan el mismo `next` (es lo que el suelo
> hace), y saturado en `MIN_TARGET` bloques mucho más lentos no ablandan nada.
>
> Consecuencia práctica: **el retarget nunca puede invertirse** —endurecer cuando debería aflojar—,
> que es la propiedad de seguridad. Pero no debe afirmarse "siempre estrictamente".

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
> (`cryptonote_basic_impl.cpp:111-112`).
>
> **Las dos divisiones son sucesivas y eso es equivalente a dividir por `M²`** — D9 lo demostró
> formalmente: para enteros no negativos, `⌊⌊a/m⌋/n⌋ = ⌊a/(m·n)⌋`.
>
> **La función es NO CRECIENTE, no estrictamente decreciente.** D9 lo precisó: `⌊·⌋` de una función
> estrictamente decreciente nunca sube, pero **puede tener mesetas**. Con los parámetros reales de
> ZEROX no aparecen —la resolución de `base` frente a `M²` sobra—, pero eso depende de esa relación
> y no es garantía general. Lo que el consenso necesita sí está demostrado: **un minero nunca cobra
> más por hacer un bloque más grande**.
>
> ⚠️ **`u128` tiene un techo real, y no es infinito.** Con `base = recompensa_base(0)`, el numerador
> máximo `base·M²` **desborda `u128` en cuanto `M > 42 238 129 881 480`**. No es un agujero de
> acuñación —`checked_mul` **falla cerrado**— pero sí sería una **denegación de validación** si `M`
> llegara ahí. Lo que lo hace inalcanzable no es el tipo, es la física: un bloque en ese umbral
> pesaría ~84,5 TB. Queda como **límite conocido documentado**, no como problema resuelto.

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

**C-EMIT-04 · Unicidad del txid de coinbase.** El campo `expiry_height` de una coinbase **MUST** ser
igual a la altura de su bloque.

> ⚠️ **Precisado 2026-09-04 al implementar §6.4.** Esta regla pedía "un campo `height: u32`", lo que
> se leía como un campo **nuevo** en la transacción. No hace falta: `expiry_height` ya existe
> (§5.1), ya forma parte de los datos de efecto —entra en `header_digest`, §4.2— y reutilizarlo
> evita tocar el árbol del txid, que ya está especificado y probado.
>
> Es además **exactamente la solución de la referencia**: Zcash Protocol Specification §7.1.2 dice
> *"[NU5 onward] The nExpiryHeight field of a coinbase transaction MUST be equal to its block
> height."*
>
> Propiedad adicional que sale gratis: por C-TX-08, una coinbase con `expiry_height = H` no es
> válida en ningún bloque de altura mayor, así que tampoco puede reproducirse más adelante.

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

**La comprobación MUST hacerse ANTES de deshacer nada.** Comprobar a mitad de la reorganización
dejaría el estado a medias precisamente en el caso que esta regla existe para tratar como
excepcional. Implementado en `zx-node::cadena::adoptar`, con un test que verifica que tras el
rechazo **la cadena y la punta quedan intactas**.

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

> 🔶 **C-UPG-06 y C-UPG-07 NO están implementadas, y conviene que quede escrito aquí.**
>
> La auditoría de trazabilidad las encontró como el único hueco **no declarado** del SPEC: no hay
> lógica de altura de activación en `zx-mempool`, ni detección de "he seguido bloques inválidos" en
> `zx-node`. Todos los demás huecos —el relé compacto, el kernel GPU, la validación de dificultad de
> cabeceras— sí venían marcados; estas dos parecían completas sin serlo, que es peor.
>
> Severidad baja y por una razón concreta: **son `SHOULD`, y ZEROX no tiene todavía ningún hard fork
> real que las ejercite** — solo existe la rama v1. Se cierran cuando exista la segunda, que es
> cuando por primera vez habrá dos conjuntos de reglas y por tanto algo que purgar del mempool. →
> **P-030**.

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

**C-GEN-06 · El timestamp del génesis MUST ser plausible.** `ts(0) ≥ TIMESTAMP_MINIMO_GENESIS =
1 767 225 600` (2026-01-01 00:00:00 UTC). Un génesis anterior **MUST** abortar el arranque.

> **No es cosmética: el timestamp del génesis entra en la ventana del primer retarget.** Para
> `H = N+1 = 91`, C-DIFF-01 consume `ts(H−N−1 .. H−1) = ts(0..90)`, y `ts(0)` es el del génesis.
>
> Con `ts(0) = 0` el primer solvetime reconstruido satura en `ST_CAP = 720` en lugar de valer
> `T = 120`, así que `t` sube exactamente `ST_CAP − T = 600` —con el peso más bajo, `j = 1`— y el
> primer target calculado sale **un 0,122 % más fácil** de lo que debería. Medido en
> `zx-consensus`, test `un_genesis_en_el_ano_cero_sesga_el_primer_retarget`.
>
> **Su función real es que un marcador de posición no pueda lanzarse por descuido.** Los parámetros
> de mainnet llevan `timestamp: 0` **a propósito** mientras P-017 siga abierto: así un nodo que
> intente arrancar mainnet sin rellenarlos **aborta citando P-017**, en vez de levantar una cadena
> sobre un génesis no intencionado. Test: `el_genesis_de_mainnet_todavia_no_arranca`.

**C-GEN-07 · El hash del génesis está congelado en el binario.** Cada red cuyo génesis esté
decidido **MUST** llevar su hash como constante, y el arranque **MUST** compararlo.

```
testnet:  fe56845a01bafa5a51ae43dd43d16584966f65a2acb41bc6fac281814062b6f1
mainnet:  🔴 sin congelar — P-017
```

> Sin la aserción, dos nodos con builds distintas levantarían **cadenas distintas creyendo que son
> la misma**, y el síntoma aparecería mucho más tarde y muy lejos de la causa. Mainnet **no debe**
> tener su constante todavía: congelar el hash de un marcador de posición es congelar el error.
>
> Y una red **sin** hash congelado **MUST NOT** arrancar. Son dos candados independientes con
> C-GEN-06 —uno por el timestamp, otro por el hash ausente— y es deliberado: cerrar P-017 exige
> tocar los dos, así que no basta con rellenar la fecha y olvidarse de congelar el hash.
>
> ⚠️ **Corregido 2026-09-05 tras la primera auditoría de trazabilidad.** La comparación existía
> **solo en un test**, y "el arranque" no es `cargo test`: un binario compilado con parámetros
> tocados habría levantado una cadena distinta sin decir nada. Ahora vive en
> `zx-consensus::genesis::comprobar_al_arrancar`, con un test que **toca cada parámetro** y
> comprueba que impide arrancar.


## 15.1 · Almacenamiento — `C-STORE`

**C-STORE-01 · La punta MUST escribirse después del dato, nunca antes.** Un almacén **MUST**
rechazar fijar la punta en una cabecera que no tenga guardada.

> **La asimetría es lo que importa.** Si el proceso muere entre medias:
>
> | | Resultado |
> |---|---|
> | Cabeceras escritas, punta no | **Recuperable.** Sobra información, se ignora |
> | Punta escrita, cabecera no | **Corrupto.** El nodo arranca creyendo estar en una altura de la que no tiene datos |
>
> Y el segundo caso no da la cara al arrancar: da la cara mucho después, cuando alguien pide esa
> altura. Por eso la comprobación se hace **leyendo**, no confiando.
>
> Es la misma razón por la que `revertir_bloque` aplica el undo data antes de mover el tip.

**C-STORE-02 · Guardar una cabecera es una operación ATÓMICA.** Toca dos índices —por hash y por
altura— y **MUST NOT** poder quedar a medias.

> Sin atomicidad hay una ventana en la que el índice de alturas apunta a una cabecera que aún no
> existe. En RocksDB se resuelve con `WriteBatch`.

**C-STORE-03 · Las alturas se indexan en BIG-endian.**

> RocksDB ordena las claves por bytes, así que big-endian hace que el orden lexicográfico coincida
> con el numérico. Con little-endian, la altura 256 —`00 01 00 00`— quedaría **antes** que la 2
> —`02 00 00 00`—, y cualquier recorrido por rango daría la cadena desordenada.
>
> Es la clase de fallo que no se ve hasta que la cadena pasa de 256 bloques. Hay un test que
> compara los dos órdenes explícitamente.

**C-STORE-04 · Todo backend MUST comportarse igual que la implementación de referencia.**

> `AlmacenEnMemoria` es la referencia; `AlmacenEnDisco` el backend real. Un test diferencial corre
> la misma secuencia contra los dos y exige respuestas **idénticas**, incluidas las de "no lo
> tengo".
>
> Es la disciplina que faltó en **H-001**: aquel kernel no tenía contra qué compararse, y por eso
> falló los 237 vectores CAVP sin que nadie lo notara.

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

**C-NET-02 · Puertos e identidad de protocolo.**

```
mainnet   TCP/QUIC 9833   ·  testnet   TCP/QUIC 19833
gossipsub topics:  /zerox/blocks/1  ·  /zerox/txs/1
request-response:  /zerox/sync/1
kademlia:          /zerox/kad/1
identify agent:    zerox/<version>
```

> **El nombre de protocolo de Kademlia NO es cosmético.** `kad::Config::default()` usa
> `/ipfs/kad/1.0.0` —la DHT **pública de IPFS**— y no falla al compilar. Verificado en
> `rust-libp2p@v0.56.0`, `protocols/kad/src/behaviour.rs:196-241`. Ver `research/libp2p-arquitectura.md` §0.

### 16.1 · Sincronización de cadena — headers-first CON umbral de trabajo

**C-NET-03 · Headers-first: el cuerpo NO se pide hasta validar la cabecera.** Un nodo **MUST**
descargar y validar la cadena de cabeceras —PoW (§7.1), continuidad de `prev_hash`, timestamps
(§7.4)— **antes** de solicitar ningún cuerpo de bloque.

> **Aquí ZEROX diverge de Zebra a propósito, y conviene dejar escrito por qué.**
>
> La hoja de ruta decía "headers-first, referencia Zebra". **Es falso que Zebra lo haga**: Zebra pide
> *hashes* con `getblocks`/`FindBlocks`, nunca emite `getheaders` como cliente, y compensa acotando
> altura y memoria en la descarga de cuerpos. Verificado en `zebra@b685fbe3`,
> `zebra-network/src/protocol/internal/request.rs:100-138`. Y **no existe RFC de Zebra** que explique
> la elección — la razón está dispersa en comentarios, así que "Zebra lo hace así" no vale como
> argumento.
>
> Para ZEROX la aritmética decide sola: **una cabecera mide 92 bytes y un cuerpo típico 100-200 KB**,
> una relación de ~1:1000. Validar el PoW de una cabecera cuesta **un SHA3-256**. Descargar cuerpos
> para descubrir después que la cadena no llevaba a ninguna parte cuesta mil veces más ancho de banda
> por bloque. Ver `research/sync-cadena.md`.

**C-NET-04 · Umbral anti-DoS de trabajo para cabeceras.** Un nodo **MUST NOT** retener en memoria una
cadena de cabeceras que no demuestre trabajo acumulado suficiente. El umbral **MUST** ser **relativo
al tip propio**, nunca una constante absoluta:

```
umbral = max( trabajo(tip) − 144·trabajo_de_un_bloque(tip),  TRABAJO_MINIMO_CADENA )
```

Por debajo del umbral, la cadena de cabeceras **MUST** mantenerse como resumen acotado, **MUST NOT**
materializarse en un índice por cabecera, y el peer **MUST NOT** ser penalizado por ello.

> **Esta regla existe porque headers-first tuvo su propio agujero: CVE-2019-25220**, divulgado el
> 2024-09-18. Bitcoin Core guardaba un `CBlockIndex` por cada cabecera con PoW válido **sin exigir
> trabajo acumulado**, y una cadena de cabeceras de baja dificultad tumbaba el nodo por OOM.
>
> Lo instructivo no es el fallo sino su deriva: **el coste del ataque bajó solo, con el tiempo**,
> porque el umbral era absoluto y la dificultad de red subía — de ~4,12 BTC (32 % de un bloque, enero
> 2019) a **~0,14 BTC** (4,4 % de un bloque, septiembre 2024). De ahí que el umbral **MUST** ser
> relativo al tip: un umbral fijo caduca sin que nadie lo note.
>
> Fuente: `bitcoin/bitcoin@4519933391`, `src/net_processing.cpp:749-753` (`GetAntiDoSWorkThreshold`),
> PR #25717 y #26355. El buffer de 144 bloques es suyo, y su razón es aceptar bifurcaciones cercanas
> al tip. **zcashd nunca portó el arreglo** (no encontrado; confianza media, búsqueda dirigida).
>
> ZEROX lo construye desde el día uno en vez de retrofitearlo, que es la única ventaja real de nacer
> después.
>
> ✅ **`TRABAJO_MINIMO_CADENA = 0`, y P-024 queda cerrada así.** Es el análogo de `nMinimumChainWork`
> de Bitcoin: un suelo que se sube en cada release según la cadena real crece. Para una cadena **que
> todavía no existe**, el único valor correcto es cero — cualquier otro rechazaría la cadena real en
> el arranque. **No es una constante permanente de consenso**: dos nodos con valores distintos no se
> bifurcan, solo difieren en cuánta basura retienen antes de descartarla.
>
> ⚠️ **El trabajo se cuenta desde el ANCLA, no desde el tip.** Un test lo destapó: la primera
> implementación sumaba el trabajo de la cadena candidata al del **tip**, y con esa cuenta una
> bifurcación que colgara de hace cinco mil bloques sumaba trabajo que **no es de esa rama** y
> superaba el umbral siempre. La defensa quedaba desactivada justo para el caso que existe para
> cubrir. `zx-consensus::antidos`, `zx-node::sync`.

**C-NET-05 · Lento y malicioso son cosas distintas.** Un peer que **no responde a tiempo** o devuelve
respuestas vacías **MUST** desconectarse sin puntuar. Solo una **violación de consenso positivamente
identificada** puntúa hacia el baneo.

> Copiado de Zebra con su razón, que es más sutil de lo que parece. Su comentario, literal:
>
> > *"`AboveLookaheadHeightLimit` deliberately falls through unscored, and must stay that way
> > (GHSA-qhr3-cvch-5fh2): `FindBlocks` responses carry no address, so the follow-up request goes to
> > an independently chosen, honest peer that served the block but did not choose its height."*
>
> Es decir: **quien te entrega un bloque no es quien eligió su altura.** Penalizar al mensajero por
> el contenido de una respuesta que no controló es un vector para que un tercero haga que banees a
> peers honestos. Zebra puntúa 0 casi todos los errores blandos, y 100 —ban de un golpe— los de
> consenso duro. Separa por mecanismo: los lentos caen por `FindResponseStallTracker` (umbral 3,
> desconecta y olvida), los maliciosos por score por IP.

### 16.2 · Relé compacto (BIP 152 adaptado) — transporte, NO consenso

**C-NET-06 · Validar la cabecera antes de emitir un bloque compacto.** Un nodo **MUST NOT** emitir un
anuncio compacto sin haber validado que la cabecera compromete cada transacción del bloque y que
construye sobre la cadena válida con PoW correcto. **MAY** emitirlo antes de validar que cada
transacción gasta UTXO existentes.

> Literal de BIP 152, y es la única de sus reglas que es **independiente del transporte**: habla del
> orden causal *interno* del nodo, no del canal. Ver `research/bip152.md` §7-§8.

**C-NET-07 · Derivación del ID corto.** Sobre `txid`:

```
h  = SHA3-256( cabecera(92 B) ‖ nonce(8 B LE) )       ← divergencia deliberada, ver abajo
k0 = h[0..8]  como u64 LE
k1 = h[8..16] como u64 LE
id = los 6 bytes bajos de SipHash-2-4(k0, k1, txid)
```

> **BIP 152 usa SHA256 *simple*** —no doble, a diferencia del blockhash de Bitcoin— y esa asimetría
> es una trampa documentada: quien lo implemente "como el blockhash" produce IDs incompatibles y el
> síntoma es que los bloques **nunca reconstruyen**, sin ningún error de protocolo. ZEROX no hereda
> la trampa porque su función de hash de cabecera ya es una sola pasada de SHA3-256.
>
> **El nonce no es decorativo.** Cita del BIP: *"by using the block hash as a key to SipHash, an
> attacker cannot predict what keys will be used […] so that even block creators cannot control where
> collisions occur"*. Sin él, un minero podría fabricar transacciones que colisionen con las del
> mempool ajeno y degradar la propagación de la red entera.
>
> 🔶 `SipHash-2-4` **no está definido en BIP 152** — remite a Aumasson & Bernstein. Es una laguna
> declarada, no una omisión nuestra.

**C-NET-08 · Las colisiones se recuperan, NO se castigan.** Un ID corto colisionado **MUST** resolverse
pidiendo la transacción completa, y el peer **MUST NOT** ser penalizado.

> Literal: *"short transaction IDs are expected to occasionally collide, and nodes MUST NOT be
> penalized for such collisions, wherever they appear."* Con 48 bits, bloques de ≤10 000 tx y mempools
> de ≤100 000, el BIP calcula un fallo de reconstrucción cada **281 474 bloques**.

**C-NET-09 · El receptor MUST verificar la raíz de Merkle del bloque reconstruido.**

> 🔴 **Esto NO está en BIP 152, y es una laguna suya.** El BIP obliga al **emisor** a comprometer la
> raíz, y del receptor solo dice que el bloque "shall be processed as normal". Pero existe un caso
> ciego: una colisión que produce **exactamente una coincidencia, y equivocada**. En ese caso el
> receptor ensambla un bloque distinto del real y no tiene forma de saberlo salvo comprobando la raíz.
>
> Se hace explícito aquí porque una regla que solo se cumple "por la vía de la validación ordinaria"
> es una regla que alguien puede optimizar sin darse cuenta de lo que quita.

**C-NET-10 · Máximo 3 peers en modo de alto ancho de banda.** Literal del BIP: *"Nodes MUST NOT send
such sendcmpct messages to more than three peers, as it encourages wasting outbound bandwidth across
the network."* Se eligen por **histórico de entrega rápida**, no al azar.

> 🔶 **La negociación de `sendcmpct` NO se porta.** Depende de una conexión TCP persistente con
> **orden total** entre `sendcmpct`, `getdata`, `cmpctblock`, `ping`/`pong`. libp2p multiplexa streams
> independientes sobre yamux y no garantiza ese orden. Lo que se adopta de BIP 152 es la derivación
> del ID corto, las estructuras, el algoritmo de reconstrucción y C-NET-06; el saludo se rediseña
> sobre el protocolo de request-response propio. Ver `research/bip152.md` §8.

### 16.3 · Límites de la capa de red — todos explícitos

**C-NET-11 · Ningún límite de transporte se deja en su valor por defecto.** En particular:

| Límite | Default de libp2p | Por qué NO sirve |
|---|---|---|
| `gossipsub::max_transmit_size` | **65 536 B** | Un bloque típico de ZEROX mide **100-200 KB**. Con el default, **ningún bloque normal se propaga** |
| `gossipsub::validate_messages` | **`false`** | El mensaje se **reenvía al mesh antes** de que lo validemos: amplificación regalada |
| `ConnectionLimits` | todo `None` | Sin límite de conexiones |
| Tamaño en `request_response::Codec` | **no existe** | El trait no impone ninguno; el `.take(MAX)` es responsabilidad de cada implementación |

> Los cuatro están verificados contra `rust-libp2p@v0.56.0` en `research/libp2p-arquitectura.md` §0
> y §3. **Ninguno de los cuatro falla al compilar**, y de ahí la regla: no es una recomendación de
> estilo, es que la capa de transporte de libp2p **no es segura por defecto** para una cadena.

**C-NET-13 · El límite de transporte MUST derivarse de `LIMITE(H)`, nunca ser una constante.** El
tamaño máximo de un mensaje de difusión **MUST** calcularse como `FACTOR_MARGEN · LIMITE(H)` con el
`LIMITE(H)` vigente al arrancar. Un nodo cuyo margen caiga por debajo de `MARGEN_MINIMO` **MUST**
negarse a funcionar.

> **Esta regla nace de un fallo propio, encontrado en la primera revisión adversarial del crate de
> red.** El límite era una constante, `8 × ZONA_LIBRE = 800 000 B`, y el razonamiento parecía
> sobrado. No lo era.
>
> `LIMITE(H) = 2·M(H)` crece con la mediana larga, **sin techo**, y el propio SPEC estima el
> crecimiento anual máximo de `Mlt` en ≈2,9× (C-WGT-04):
>
> | | `Mlt` | `LIMITE(H)` | ¿cabía en 800 000? |
> |---|---|---|---|
> | año 0 | 100 000 | 200 000 | sí |
> | año 1 | 290 000 | 580 000 | sí |
> | año 2 | 841 000 | **1 682 000** | **NO** |
>
> **En el año 2, un bloque perfectamente válido deja de poder propagarse.** Sin ataque, sin nada
> raro: es exactamente el caso para el que existe la mediana larga.
>
> Y el límite que decide es el del **receptor**, no el del emisor (verificado en
> `libp2p-gossipsub`, `src/protocol.rs`: el códec de lectura se construye con el
> `default_max_transmit_size` propio). Así que nodos con versiones distintas de la constante **se
> particionan entre sí en silencio**: unos aceptan el bloque, otros lo tiran por tamaño de frame, y
> ninguno emite un error de consenso.
>
> Lo más instructivo: el comentario del código **describía este escenario** —"se convierte en una
> partición de red silenciosa el día que los bloques crezcan"— y el arreglo que implementaba era
> multiplicar por 8 la zona libre de **hoy**, que no está atada a nada que crezca. **El aviso estaba
> escrito y el arreglo no.** Un comentario que identifica un riesgo no lo mitiga.
>
> La negativa a funcionar es el mismo patrón que C-GEN-06: el límite de gossipsub se fija al
> construir el behaviour y no cambia en caliente, así que un nodo que lleva meses encendido mientras
> la cadena crece puede quedarse corto. Parar diciendo "actualiza" es infinitamente mejor que seguir
> y dejar de ver la mitad de los bloques.

**C-NET-14 · mDNS MUST estar desactivado en mainnet.** El descubrimiento por multicast **MUST**
limitarse a testnet.

> Un nodo de mainnet con mDNS anuncia su presencia a todo su segmento L2 — que en un VPS barato o en
> un datacenter compartido significa decirle a los vecinos "aquí corre un nodo ZEROX". Es fuga de
> información gratuita, y un punto de partida barato para un eclipse: enumerar nodos sin pasar por
> Kademlia ni por los bootstrap.
>
> En testnet es justo lo que se quiere: el arnés multinodo local depende de que tres nodos se
> encuentren sin configurar nada.

**C-NET-15 · Las invariantes de los parámetros de red MUST vivir en el tipo, no en un comentario.**
Un `ParametrosRed` **MUST NOT** poder construirse campo a campo.

> Otro hallazgo de la misma revisión, y de la misma familia: el docstring **afirmaba** que los
> parámetros se construían siempre desde una `Red` y que por eso no existía la combinación "prefijo
> de mainnet con puerto de testnet"… y todos los campos eran `pub`, así que esa combinación se
> escribía con un literal de struct y el compilador la aceptaba.
>
> **Una invariante que solo vive en un comentario no es una invariante.** Es el mismo error que
> C-NET-13, en otra escala.

**C-NET-16 · Servir una petición MUST ser O(1) en el tamaño de la cadena.** Toda búsqueda que un
peer pueda provocar **MUST** ir por índice, y ninguna **MUST** recalcular hashes ya conocidos.

> **Nace de un DoS asimétrico encontrado en la primera revisión adversarial del sincronizador**, y
> es de los baratos de explotar y caros de sufrir.
>
> `cabeceras_desde` buscaba con `iter().position(|c| c.block_hash() == h)`. Dos cosas se juntaban:
> `block_hash()` **no está cacheado** —cada llamada reserva un `Vec` y computa un SHA3-256— y un
> locator trae **hasta 64 hashes**, ninguno de los cuales tiene por qué ser real.
>
> Un peer manda 64 hashes aleatorios en un mensaje de 2 KB y el servidor hace **64·n SHA3** y 64·n
> reservas, **dentro del bucle del `Swarm`** — con toda la red parada mientras tanto. Con una cadena
> de un año, decenas de millones de hashes por dos kilobytes, repetibles gratis. Ni siquiera hacía
> falta ser el peer de sincronización: bastaba estar conectado.
>
> Y una variante peor: colocando el hash del génesis —público, va en el saludo— en la **última**
> posición del locator, se pagaban 63 escaneos completos y además se clonaba la cadena entera antes
> de que el recorte la truncara. **El recorte MUST aplicarse antes de clonar, no después.**
>
> Corolario que también es regla: **`trabajo_hasta` MUST ser O(1)**. Se ejecutaba sobre el
> `prev_hash` que el peer elige, **antes** de validar nada — un escaneo completo de nuestra cadena a
> petición de cualquiera.

**C-NET-17 · "Estar al día" MUST medirse por cabeceras APLICADAS, nunca por recibidas.**

> El diseño original contaba la longitud de la respuesta cruda, y el comentario afirmaba que "que un
> peer deje de mandarte cabeceras nuevas no se puede fingir". **Era falso.** Bastaba con mandar tres
> respuestas cortas de basura —cabeceras con `prev_hash` inventado, que ni llegan a validarse— para
> que el nodo se declarase sincronizado **habiendo aplicado cero**, potencialmente seguido en el
> génesis.
>
> Y un nodo que se cree al día sin estarlo es exactamente lo que un monedero consulta antes de dar
> un pago por bueno. Contar lo aplicado sí es infalsificable: aplicar exige encadenar, `bits`
> canónico y PoW.

**C-NET-18 · Sin progreso, MUST cortarse; nunca reintentar con el mismo locator.** Si una respuesta
válida no aporta ninguna cabecera aplicable, o si no cuelga de nada nuestro, el nodo **MUST** dejar
de pedir a ese peer.

> Con el mismo locator, el peer respondería **lo mismo indefinidamente** — gratis para él, un
> escaneo por ronda para nosotros. Es un bucle infinito con la víctima pagando.
>
> ✅ **El caso de la bifurcación ya está cubierto (P-028, cerrada).** `Cadena::adoptar` decide con
> `fork_choice::preferir` —trabajo acumulado, con desempate por menor hash— y **reorganiza** cuando
> la rama candidata gana. Antes, una rama válida que colgara por debajo de la punta se validaba
> bien y se descartaba entera, dejando al nodo en la cadena perdedora **sin error y sin aviso**:
> la peor forma de divergir.
>
> Cortar sigue siendo la respuesta cuando la rama **no gana** o no cuelga de nada nuestro: reintentar
> con el mismo locator daría lo mismo indefinidamente.

**C-NET-19 · A un peer condenado no se le vuelve a pedir en la misma vuelta.** Desconectar **es
asíncrono** —encola un comando—, así que el sincronizador **MUST** olvidarlo de inmediato.

> Sin esto, el peer que acaba de ser condenado por violar consenso se llevaba **una ronda extra** de
> interacción antes de que la desconexión se procesara.

**C-NET-20 · Los límites de conexión y el baneo MUST contarse por PREFIJO DE RED, no por `PeerId`.**
IPv4 se agrupa por **/24** e IPv6 por **/64**.

> **Un `PeerId` es gratis.** `Keypair::generate_ed25519()` es instantáneo: sin PoW, sin registro, sin
> coste. Así que `MAX_CONEXIONES_POR_PEER = 1` no limita nada — basta con generar una identidad
> nueva por conexión.
>
> Y `connection_limits` de libp2p **no tiene ningún ajuste por IP**: verificado en el crate, sus
> únicos setters son globales o por `PeerId`. Hay que escribirlo, y por eso existe
> `zx-p2p::limites_ip`.
>
> Dos ataques que esto cierra, ambos desde **una sola máquina**:
>
> | Ataque | Cómo | Efecto sin la defensa |
> |---|---|---|
> | *Slowloris* | Abrir conexiones y no completar el handshake | El contador global de pendientes se llena y el nodo **rechaza a todo el mundo** |
> | Relleno de cupo | 72 `PeerId` desde la misma IP | Se ocupa el cupo entrante entero |
>
> **Por qué prefijo y no IP exacta.** Contar por IP se evade con cualquier VPS barato, y un /64 de
> IPv6 son 18 trillones de direcciones asignadas **a un solo cliente**. Agrupar hace que evadir
> cueste alquilar redes distintas, no pedir una IP más.
>
> **Una violación de consenso banea de un solo golpe** (100 de 100 puntos). Fabricarla cuesta
> trabajo real: no ocurre por accidente. El registro de baneos está **acotado a 20 000 con desalojo
> FIFO** — sin la cota, hacer crecer la tabla sería el ataque.
>
> **Los puntos por motivo** (P-026 cerrada):
>
> | Motivo | Puntos | Por qué |
> |---|---|---|
> | Violación de consenso | **100** — baneo de un golpe | Fabricarla cuesta trabajo real: no ocurre por accidente |
> | **Excedido** | **20** — cinco avisos | Atribuible al emisor, pero admite explicación inocente |
> | Lento, ilegible | **0** | No son atribuibles a mala fe |
>
> **Por qué `Excedido` puntúa aunque C-NET-05 diga que solo la violación de consenso lo hace.** La
> razón de C-NET-05 es la de Zebra sobre GHSA-qhr3-cvch-5fh2 —*quien te entrega un bloque no es
> quien eligió su altura*— y describe al **mensajero inocente**. Mandar 20 MB cuando el límite son
> 12,8 **no es reenviar**: es una acción del emisor, sin ambigüedad sobre quién la causó.
>
> **Por qué 20 y no 100.** Porque sí existe una explicación inocente: un peer con versión más nueva
> cuyos límites son mayores porque la cadena creció (C-NET-13). Ahí el desactualizado somos
> nosotros, y banearlo sería exactamente al revés.
>
> **Y los cinco avisos separan los dos casos solos.** Como el score va por **prefijo**, un desajuste
> de versión aparece como `Excedido` desde **muchos prefijos distintos** —toda la red es más nueva
> que nosotros— mientras que sondear los límites aparece como muchos **desde el mismo**. La misma
> señal, leída por prefijo, distingue las dos causas sin que nadie tenga que decidirlo. El log lo
> dice explícitamente para que el operador lo lea.

**C-NET-21 · Presupuesto AGREGADO de memoria en vuelo.** Toda lectura de red **MUST** reservar su
cupo de un contador **compartido** antes de leer, y **MUST** devolverlo al terminar. Techo:
`PRESUPUESTO_BYTES = 256 MiB`.

**C-NET-22 · La sincronización headers-first MUST comprobar la dificultad esperada.** Antes de
adoptar un lote de cabeceras, el nodo **MUST** verificar C-BLK-05 sobre cada una: que su `bits` es
exactamente `compact(siguiente_target(H))` (C-DIFF-09). La ventana del retarget se arma sobre la
**rama candidata**: las alturas por encima del ancla salen del lote, y las que están en el ancla o
por debajo, de la cadena propia.

Si faltan ancestros para calcularlo, el lote se rechaza **sin penalizar** — es una limitación
propia, no mala fe. Un `bits` distinto del que toca **sí** es mala fe (C-NET-05): el retarget es
una función pura (C-DIFF-01), así que dos nodos con los mismos ancestros obtienen el mismo valor.

> **Esto no es una regla nueva, es un cable que faltaba.** C-BLK-05 y C-DIFF-09 ya estaban, y
> `zx-consensus` implementaba LWMA-1 entero y probado. Lo que no existía era ninguna llamada desde
> el nodo: el camino de sincronización pasaba por `validar_cadena_de_cabeceras`, cuyo propio
> docstring dice que no comprueba la dificultad esperada.
>
> El agujero era que un peer podía servir cabeceras con **cualquier `bits` canónico** —uno más
> barato del que LWMA exige— y el nodo las adoptaba. La defensa que quedaba era el umbral de
> trabajo de C-NET-04, que solo atrapa lo grosero: un `bits` un poco más fácil produce una cadena
> que **ese nodo acepta y el resto de la red rechaza**. Divergencia de consenso, que es el peor
> sitio donde tener un hueco.
>
> **Por qué la ventana sale de la rama candidata y no de la punta propia.** Es literalmente el
> mismo error que ya se cazó una vez en `validar_cadena_de_cabeceras`, que sumaba el trabajo del
> tip en lugar del ancla: juzgar una rama con datos de otra. La segunda vez se escribió bien desde
> el principio, y hay un test que lo fija — `la_ventana_de_una_bifurcacion_usa_el_lote_no_nuestra_punta`.
>
> **Va después del PoW a propósito.** Reconstruir una ventana de 91 ancestros cuesta bastante más
> que un SHA3, y no merece gastarla en cabeceras que ni siquiera cumplen su propio `bits`.

**C-NET-23 · Un cuerpo MUST demostrar que es el de su cabecera antes de guardarse.** Antes de
escribir un cuerpo en el almacén, el nodo **MUST** recalcular la raíz de Merkle desde las
transacciones que llegan y comprobar que es la que la cabecera compromete (C-BLK-03). El
`consensus_branch_id` con el que se calculan los txid sale de **la cabecera**, no de la tabla de
ramas del nodo (C-TX-05).

Además: un cuerpo sin transacciones se rechaza (C-BLK-07), y el número de listas de testigos
**MUST** ser igual al de transacciones (§2.4). Todo esto es mala fe (C-NET-05): la raíz es
determinista.

Solo se guardan cuerpos de cabeceras que el nodo ya tiene y ha validado. Un cuerpo de una cabecera
desconocida **MUST** descartarse sin penalizar — puede ser una carrera con una reorganización.

> **El agujero que cierra.** Un cuerpo se indexa **por el hash de su cabecera**. Sin esta
> comprobación, un peer que responde a `Peticion::Bloques` puede mandar la cabecera correcta —la que
> le pedimos, la que ya validamos, así que la clave del almacén es la buena— con un cuerpo
> cualquiera. Lo guardaríamos, se lo serviríamos a otros peers como si fuera el bloque real, y
> `Cadena::bloque` lo devolvería sin una queja.
>
> Cuesta un recorrido de Merkle y no necesita estado: es la barrera **anterior** a la validación
> completa del cuerpo (§6.4), que necesita el conjunto UTXO y todavía no está cableada.

**C-NET-24 · La descarga de cuerpos va de menor altura a mayor, en lotes acotados.** Cumplida
C-NET-03, el nodo **MUST** pedir los cuerpos que le faltan **en orden ascendente de altura**, en
lotes de como mucho `MAX_BLOQUES_POR_RESPUESTA = 16`, y **MUST** mantener como mucho una petición
de cuerpos en vuelo por peer: la siguiente se emite al recibir la anterior.

Un nodo con las cabeceras completas y cuerpos a medias **MUST** entrar en la fase de cuerpos
directamente desde el saludo, sin pasar por la de cabeceras. No le falta cadena; le faltan cuerpos.

> **De abajo arriba, no en cualquier orden.** Un nodo a medias queda con un prefijo íntegro y un
> sufijo por descargar, en vez de agujeros repartidos. Con agujeros, cualquier consulta histórica
> falla de forma impredecible; con un prefijo, se sabe exactamente hasta dónde se puede responder.
>
> **El lote es 16 porque es lo que la respuesta puede traer.** Pedir más significa que el servidor
> recorta y que los que sobran se piden otra vez en la vuelta siguiente, habiéndolos nombrado dos
> veces.
>
> **Encadenar la siguiente petición a la respuesta anterior es el control de flujo.** No hace falta
> un temporizador ni una ventana: un peer lento retrasa su propia descarga y nada más.
>
> Hasta que esta regla se implementó, el nodo **no pedía ningún cuerpo jamás**: sincronizaba
> cabeceras y paraba. La fase existía en el enum del sincronizador y nada la construía.

> **El límite por petición no acota el producto.** Cada lectura del códec está acotada por
> `.take(MAX)`, y eso no basta:
>
> ```
> MAX_RESPUESTA_BYTES (25,6 MB) × MAX_STREAMS_SYNC (8) × MAX_PEERS_ENTRANTES (72) = 14,7 GB
> ```
>
> Bajar los streams concurrentes de 100 a 8 quitó un orden de magnitud y dejó el problema: casi
> quince gigabytes reservables por peticiones que un atacante emite gratis siguen siendo un OOM.
>
> ⚠️ **Esa cifra empezó siendo 7,2 GB en este SPEC, y estaba mal.** El arreglo de C-NET-13 dobló
> `MAX_GOSSIP_BYTES` —pasó de derivarse de `ZONA_LIBRE` a derivarse de `LIMITE_BLOQUE_GENESIS`, que
> es el doble— y los cuatro comentarios que narraban la aritmética se quedaron con el número
> anterior. **Tercera vez** que este proyecto escribe a mano un número que es función de una
> constante: H-005 (el offset del nonce), el tamaño de cabecera (112 frente a 92), y ahora esto.
> Encontrado por la auditoría de trazabilidad, y ahora hay un test que **deriva** las cifras.
>
> **Por qué un contador global y no más límites por peer.** Porque el recurso que se agota es
> global. Repartirlo por peer obliga a elegir entre dos males: o el reparto es generoso y la suma
> sigue sin acotar, o es estrecho y un nodo con muchos peers honestos se estrangula a sí mismo. Con
> un presupuesto compartido, **el techo es el techo**.
>
> **Se reserva ANTES de leer.** Reservar después contabilizaría memoria ya ocupada: el techo no
> acotaría nada, solo llevaría la cuenta del desastre.
>
> **Y se devuelve al soltarse la reserva**, incluido si el futuro se cancela o quien la tenía entra
> en pánico. No existe un método para liberar a mano: el único camino es el `Drop`. Un contador que
> hubiera que decrementar tendría una fuga por cada `return` temprano que alguien no viera, y **una
> fuga en un contador de presupuesto es un DoS diferido** — el nodo deja de aceptar peticiones sin
> que esté pasando nada.

**C-NET-12 · Validar antes de retransmitir.** Un bloque o transacción recibido por difusión **MUST**
validarse contra `zx-consensus` **antes** de reenviarse. Un bloque **huérfano** —cuyo padre aún no se
conoce— **MUST** descartarse **sin penalizar**, no rechazarse.

> La distinción es la que Ethereum codifica como `GossipIgnore` frente a `GossipReject`
> (`consensus-specs`, `p2p-interface.md:640-700`), y en libp2p es literalmente la diferencia entre
> `MessageAcceptance::Ignore` y `::Reject`: solo el segundo aplica la penalización P₄.
>
> **Un bloque huérfano no es un bloque inválido: es un bloque que llegó antes de tiempo.** Castigarlo
> penaliza a peers honestos con otro timing.

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
| **P-006** | §11 | ¿Sirve `Σ 2^256/(target+1)` con dificultad muy variable? D2 argumenta que el sesgo `(N−1)/N` de zawy afecta a la *estimación* de hashrate, no al *acumulador* — falta relectura verbatim de #58/#82 | **D9** |
| **P-014** | §13 | 🆕 La rama privada del atacante tiene su **propio LWMA** y se abarata sola tras `N=90`. Las tablas de confirmación asumen dificultad constante ⇒ las filas `q ≥ 40 %` podrían ser optimistas | **D9** |
| **P-015** | §11 | ¿Puede un minero *grindear* el nonce buscando hash bajo para ganar desempates (C-FORK-04)? | **D8** |
| **P-016** | §12 | Camino de recuperación de un nodo detenido por C-REORG-07 tras una partición larga | **D3** |
| **P-017** | §15, §16 | Mensaje, timestamp y nonce del génesis (mainnet y testnet) · puerto por defecto | Katana, el día del lanzamiento |
| **P-022** | §16.2 | 🆕 Rediseño del saludo de `sendcmpct` sobre request-response de libp2p: la negociación del BIP depende de orden total entre mensajes, que yamux no da | **D3**, Fase 5 |
| **P-023** | §16.3 | 🆕 `PeerScoreParams`/`TopicScoreParams` de gossipsub. **No existe precedente**: ninguna cadena PoW con bloques de 100-200 KB cada 120 s usa gossipsub v1.1. Hay que derivarlo y medirlo | **D3** + **D8**, Fase 5 |
| **P-019** | §16.2 | Medir `t_prop` real sobre gossipsub con bloques de 100-200 KB, **y de ahí derivar `D`/`D_low`/`D_high`/`heartbeat`**. Los de Ethereum son para slots de 12 s, no de 120 | **D3** |
| **P-011b** | §5.5 | Calibración de `REF_WEIGHT` con un modelo de coste de atacante | **D2** + **D8** |
| **P-011c** | §5.5 | ¿Anclar solo a `Mlt` abarata el spam si la demanda colapsa? | **D8** — revisión adversarial |
| **P-009g** | §6.5 (v1.1) | ¿Necesita Orchard un *clawback* análogo al de bulletproofs? | **D1** |
| **P-030** | §14 | 🆕 **C-UPG-06 y C-UPG-07 sin implementar.** No hay altura de activación en el mempool ni detección de "he seguido bloques inválidos". Son `SHOULD` y no hay hard fork que las ejercite todavía: se cierran con la segunda rama de consenso | **D2** |
| **P-031** | §7.2 | 🔴 **Ningún test puede minar PoW real.** `POW_LIMIT = 2²²⁴−1` hace que la cabecera más barata cueste ~2³² hashes, así que el hito de tres nodos no se puede demostrar. Bitcoin y Zcash lo rodean con una red `regtest` de dificultad trivial; añadir una red es decisión de consenso, y queda **bloqueada** a la espera de autoridad | **Katana** |
| **P-004d** | §7.3 | 🆕 ¿Puede LWMA adaptarse desde el bloque 1 **sembrando** la ventana con ancestros sintéticos, en vez de 90 bloques a dificultad fija? Encoger `N` está prohibido por varianza; sembrarla no. Regla de consenso nueva | Investigación + **D9** + **D8**, Fase 10 |

### Cerradas en esta revisión

| ID | Decisión | Dónde vive |
|---|---|---|
| **P-005** | **No se corrige** el sesgo del clamp. `BIAS = 1`, sesgo declarado de +0,30 s | C-DIFF-07 |
| **P-026** | **`Excedido` puntúa 20**, cinco avisos hasta el baneo. Es atribuible al emisor, pero admite una explicación inocente que el score **por prefijo** distingue sola | C-NET-05, C-NET-20 |
| **P-027** | **Presupuesto agregado de 256 MiB**, con reserva antes de leer y devolución por `Drop`. El peor caso baja de 14,7 GB a 256 MiB, sin importar peers ni streams | C-NET-21 |
| **P-029** | Un `RwLock` envenenado **recupera su contenido** —que es válido— y registra el error. Ni degrada en silencio ni tira un nodo sano | `zx-node::cadena` |
| **P-028** | **Reorganización de cabeceras**, con `fork_choice` conectado y la parada dura de C-REORG-07 comprobada **antes** de deshacer nada | C-NET-18, C-REORG-07 |
| **P-025** | **Límites y baneo por prefijo de red** (/24 y /64), en un behaviour propio: `connection_limits` de libp2p no mira la IP y un `PeerId` es gratis | C-NET-20 |
| **P-024** | **`TRABAJO_MINIMO_CADENA = 0`.** Es el análogo de `nMinimumChainWork`: para una cadena que no existe todavía, cero es el único valor correcto. Se sube por release, y **no es consenso** | C-NET-04 |
| **P-018** | **BIP 152 extraído verbatim** → `research/bip152.md`. Lo portable y lo que no, delimitado | C-NET-06..10 |
| **P-020** | **P2K**, no P2KH. La respuesta post-cuántica es un network upgrade con una variante nueva de `Lock`, no el formato de dirección | C-ENC-07, C-TX-06b, C-TX-09b |
| **P-004c** | `TARGET_INICIAL` **por red**: mainnet `0x1c07fff8` (primer bloque en `T` = 120 s con ≈1,15 GH/s), testnet `0x1d00ffff`. La constante estima el hashrate del día 1 y nada más. Recalibrable con benchmark hasta el génesis | C-DIFF-02 |

### Cubiertas desde la auditoría de cobertura

Aquella auditoría concluyó que el SPEC sabía **validar un bloque aislado** pero no **llevar una
cadena**. Los seis huecos están escritos:

| Sección | Reglas |
|---|---|
| §11 · Selección de cadena | C-FORK-01..04 |
| §12 · Reorganizaciones | C-REORG-01..07 |
| §13 · Profundidad de confirmación | política de producto, no normativa |
| §14 · Activación de cambios de consenso | C-UPG-01..08 |
| §15 · Bloque génesis | C-GEN-01..07 |
| §2.4 · Serialización de red | C-WIRE-01..07 |
| §15.1 · Almacenamiento | C-STORE-01..04 |
| §16 · Parámetros de red | C-NET-01..21 |

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
| §18.1 Coherencia SPEC↔código | — (patrón interno, 3 reincidencias) | `spec_numeros.rs`: 6 tests; 2 mutaciones comprobadas |

## 18.1 · Este documento no puede contradecir al código

**C-SPEC-01 · Toda cifra que este SPEC afirme y que sea función de una constante del código DEBE
estar comprobada por un test que la derive.** El test vive en
`crates/zx-consensus/tests/spec_numeros.rs`, lee este archivo con `include_str!` y falla si el texto
y las constantes discrepan. Añadir una cifra derivada al SPEC sin añadir su comprobación es una
violación de esta regla.

> **Por qué existe una regla sobre el propio documento.**
>
> Este proyecto ha cometido **tres veces** el mismo error, y las tres lo encontró una auditoría, no
> el compilador:
>
> | | Decía | Era | Cómo se rompió |
> |---|---|---|---|
> | **H-005** | nonce en `[92,100)`, offset 76 | `[96,104)`, offset 80 | `timestamp` pasó de `u32` a `u64` |
> | Tamaño de cabecera | 112, en **seis** sitios | **92** | nunca fue cierto; se copió |
> | `MAX_RESPUESTA_BYTES` | 12,8 MB, en **cuatro** sitios | **25,6 MB** | C-NET-13 dobló su base |
>
> El patrón no varía: **un número que es función de una constante, transcrito a mano en prosa.** El
> compilador no lo ve porque la prosa no compila; los tests no lo veían porque probaban el código,
> no lo que el código dice de sí mismo. Derivar el offset y añadir un test por módulo cerró cada
> instancia sin cerrar el patrón — por eso la tercera ocurrió igual que las dos anteriores.
>
> **Lo que cierra el patrón es que el SPEC entre en la suite de tests.** El test recalcula desde las
> constantes reales y comprueba que este documento dice el resultado. Mutar `ZONA_LIBRE` a su doble
> hace fallar dos tests en el acto, que es exactamente lo que no pasó cuando se dobló
> `MAX_GOSSIP_BYTES`.
>
> **Las cifras equivocadas siguen apareciendo en este archivo, a propósito**, dentro de las notas
> citadas como esta. Esa memoria es lo que impide que alguien "corrija" una regla devolviéndola al
> valor que ya falló. Por eso el test distingue: las comprobaciones de "esto no debe volver a
> decirse" miran solo el texto normativo —descarta toda línea que empiece por `>`—, y las de "esto
> debe seguir diciéndose" miran el archivo entero.
>
> **Lo que el test no hace** es entender el SPEC: comprueba que una cadena concreta aparece. Si
> alguien reescribe la frase, falla aunque el número siga bien. Es deliberado: una frase reescrita
> merece que alguien vuelva a mirar si el número cuadra.
