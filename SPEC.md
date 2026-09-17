# ZEROX — Especificación del protocolo

> **ESTADO: especificación en migración; consenso PoSpace-Time + DAG no congelado.**
> Última revisión: 2026-09-10.
>
> Alcance: Proof of Space and Time con GHOSTDAG, capa transparente y capa blindada Orchard.
> La capa transparente conserva sus reglas comunes; §9 identifica el trabajo blindado pendiente.
> Este documento distingue las reglas comunes, la base PoAS lineal y el diseño DAG pendiente de
> integración. Ningún módulo heredado demuestra por sí solo que el consenso destino esté implementado.
> Las decisiones y los pendientes activos viven en este repositorio; el vault externo es histórico.
> Estado de la migración: `MIGRACION.md`. Evidencia: `research/`; cálculos nuevos: `veritas/`.

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
| `C-TS` | Timestamps |
| `C-EMIT` | Emisión y coinbase |
| `C-BLK` | Validez de bloque |

### 0.3 · Marcadores de pendiente

`<<PENDIENTE: P-00N>>` señala un valor o regla que **todavía no está decidido** y remite a la
entrada local de §17 y a la investigación indicada. **Ninguna implementación puede fijar
esos valores por su cuenta.**

### 0.4 · Codificación y estado de implementación

Las preimágenes y los compromisos son de consenso. §2.4 define la codificación de intercambio;
el almacenamiento interno puede usar otra representación si conserva el comportamiento.
Las partes señaladas como pendientes no son autorización para completar reglas por intuición.

### 0.5 · Auditorías y cálculos — obligatorio `veritas/` y `LINEO.md`

> Esta sección **no es normativa para el consenso**. Ningún nodo valida nada de aquí. Es la regla
> de proceso obligatoria para todo el trabajo de cálculo del proyecto: auditorías matemáticas,
> simulaciones, búsquedas exhaustivas, benchmarks y tests de cálculo.

**C-SPEC-02 · Toda auditoría, simulación, búsqueda exhaustiva, benchmark o test de cálculo DEBEN
vivir en `veritas/<categoria>/<nombre-auditoria>/`**, con la estructura de `veritas/LINEO.md` §1
(`Project.toml`, `Manifest.toml`, `src/`, `test/`, `bench/`, `run.jl`, `resultados/`, `INFORME.md`).
**La categoría la determina el agente** según el tema dominante de la auditoría —por ejemplo
`seguridad`, `rendimiento`, `consenso`, `economía`, `criptografía`, `red`, `almacenamiento` o
`finalidad`; la lista **no es cerrada**— para que cada asunto tenga su directorio y no se mezcle
todo. El agente puede crear tantas categorías temáticas como haga falta: si ninguna existente
encaja, crea una nueva. La categoría elegida y su motivo quedan declarados en el `INFORME.md`, y una
auditoría que toque varios temas se coloca por el dominante citando los secundarios. Se crea con
`veritas/nueva-auditoria.sh <categoria> <nombre>`, que copia la plantilla compartida y ejecuta
`Pkg.instantiate()`. Los scripts ya existentes en `research/scripts/` se conservan sin tocar como
evidencia histórica; esta regla aplica a toda auditoría nueva o modificación sustancial de una
existente.

**C-SPEC-03 · `veritas/LINEO.md` es de lectura y cumplimiento obligatorios** para todo agente o
persona que escriba o modifique código de cálculo. Resumen vinculante: Julia **solo CPU**; GPU en
**C++/CUDA**; presupuestos como topes (64 GiB de RAM y 24 hilos en la máquina de referencia);
ejecución con el envoltorio `veritas/julia.sh`; referencia estricta y validación contra oráculo;
benchmark y reproducibilidad antes de publicar cualquier cifra.

> **Alcance.** Quedan fuera los tests unitarios y de integración de los crates Rust (`cargo test`),
> que viven junto a su código y no son cálculos de auditoría. Lo que cubre esta sección es el
> cálculo de verificación: scripts, simulaciones, benchmarks y tests de cálculo.

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
resultados. La equivalencia entre implementaciones debe comprobarse en los bordes numéricos.

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

> *Motivación (verificada):* FIPS/Zcash documentan el ataque concreto — sin esta regla un productor
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

**C-WIRE-01 · La cabecera que viaja son los mismos bytes que se hashean.** Su codificación es
la de §6.1, sin la etiqueta de dominio del hash. Codificador y decodificador deben compartir una
sola definición. La base de 556 bytes descrita allí todavía no es el formato definitivo del DAG.

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

**C-WIRE-07 · Codificación de un bloque completo.** El bloque contiene su cabecera canónica,
las transacciones con sus testigos (C-WIRE-03) y la justificación PoT obligatoria (C-HDR-07).
Los testigos pertenecen a cada transacción. El códec no sustituye la validación.

**Pendiente de integración DAG:** el formato, los límites y el compromiso de los padres y de la
justificación PoT ya están fijados en §6.1–§6.2 y existen tipos y códecs en `zx-core`.
Falta integrarlos en la ruta activa del nodo, que sigue ligada a la cabecera lineal.

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

**C-WIRE-06 · Una sola descripción del formato de intercambio.** Los mensajes de sincronización
usan codificación explícita junto al codificador de los objetos. No se introduce otra descripción
de cabeceras o transacciones en un esquema independiente. El formato interno de disco se rige por
§15.1 y no altera las preimágenes.

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

La función hash de identificadores y transacciones se conserva al cambiar el mecanismo de
consenso. Cualquier aceleración nueva se valida contra la referencia y los vectores aplicables;
las reglas de cálculo están en §0.5.

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
| `ZZKBlkHeader____` | §6.2 hash de cabecera, sello incluido (C-HDR-09) |
| `ZZKBlkPreHash___` | §6.2 `pre_hash`: mensaje que firma el sello (C-HDR-03) |
| `ZZKBlkBodyHash__` | §6.1 compromiso completo del cuerpo, efectos y autorización |

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
> Convertirlo en consenso habría traído tres males: un productor no podría incluir transacciones
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
tarifa_por_byte  = max(TARIFA_SUELO, max(1, F − F/20))                   // el "0,95×", en entero, con suelo
tarifa_minima(tx)= redondear_arriba( weight(tx) · tarifa_por_byte, FEE_MASK )
aceptar si         fee ≥ tarifa_minima − tarifa_minima/50                // colchón del 2 %

REF_WEIGHT = 384 000     // bytes de weight — transacción de referencia; recalibrado 2026-09-09 (P-041)
FEE_MASK   = 10 000      // brek — cuantización de la tarifa
TARIFA_SUELO = 54 359    // brek/peso — suelo absoluto; = F(recompensa_base(0), ZONA_LIBRE)
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

#### Calibración

Con `REF_WEIGHT = 384 000`, `Mf = ZONA_LIBRE = 100 000` y la emisión recalibrada a `λ = 1`:

| Régimen | `recompensa_base` | tarifa/peso cruda | con `TARIFA_SUELO` | tx típica de 350 B |
|---|---|---|---|---|
| Lanzamiento, `Mf = ZONA_LIBRE` | 1,490·10⁹ brek | 54 359 brek | 54 359 | **0,19 ZZK** |
| Cola (año 8,56+) | 2,67·10⁷ brek | 972 brek | **54 359** | **0,19 ZZK** |
| Mediana a 4,91× la zona libre | 1,490·10⁹ brek | 2 255 brek | **54 359** | **0,19 ZZK** |

> 🔶 **`TARIFA_SUELO` — suelo absoluto, decidido por Katana el 2026-09-10.** La tarifa mínima **MUST NOT**
> bajar de `F(recompensa_base(0), ZONA_LIBRE) = 54 359` brek por unidad de peso. Cierra de un golpe los
> **dos** caminos por los que el antispam se desmoronaba, que resultaron ser el mismo visto de dos lados:
>
> 1. **El lazo de realimentación con la capacidad.** `F ∝ 1/Mf²`: subir la mediana abarata la tarifa, y
>    eso abarata seguir subiéndola. Sin suelo, la serie de costes **converge** y llevar la mediana hasta
>    34 MB/bloque cuesta 2,42× la primera ronda. Con suelo, cada ronda cuesta 1,7× más que la anterior.
> 2. **La degradación con la emisión.** `F ∝ recompensa_base`, que cae **56×** del lanzamiento al régimen
>    de cola. Sin suelo, el mismo ataque que costaba 487 M ZZK al lanzamiento cuesta **8,7 M** a partir del
>    año 8,56, el 0,9 % del suministro. Con suelo, se queda en 487 M **para siempre**.
>
> **Lo que se paga, dicho sin adornos:** la tarifa mínima **nunca baja de 0,19 ZZK** por una transparente
> de 350 B, aunque el tráfico real crezca y sobre capacidad. Es coherente con lo que esta misma sección
> ya elegía —*«para un marketplace la predictibilidad vale más que la eficiencia del racionamiento»*—
> pero el suelo está en unidades de moneda, no de poder adquisitivo: si el ZZK se revaloriza mucho,
> habrá que bajarlo. **Se puede: §5.5 no es consenso**, así que es un cambio de política y no un hard fork.
>
> Verificado en `research/scripts/rendimiento/verif_bola_nieve.py` (el lazo y su ruptura) y
> `verif_zona_libre.py` (el control que reproduce 54 359 y 972 brek/peso).
>
> ⚠️ **Sin auditar.** Nadie ha atacado el suelo. La pregunta para D8: al hacer la tarifa insensible a la
> capacidad, ¿se abre alguna vía por el otro lado —por ejemplo, que llenar bloques por debajo de la
> mediana deje de tener coste relativo cuando la mediana es enorme?
>
> ⚠️ **La tarifa cruda satura en 1 brek por unidad de peso cuando `Mf > √(base·REF_WEIGHT) ≈ 23,9 MB`.**
> Con `TARIFA_SUELO` esa saturación deja de alcanzarse: el suelo muerde mucho antes.
>
> **Alternativa documentada y NO adoptada:** anclar la tarifa a una **ventana larga aparte** (`Mf ≠ Mlt`,
> 180 días o un año, calculada como política y no como consenso). Rompe el lazo igual que el suelo, y
> además dejaría que la tarifa **sí** bajara con el crecimiento real sostenido; pero **no** protege de la
> degradación del punto 2, cuesta un segundo estado y su estimador no lo ha atacado nadie.

`REF_WEIGHT = 3 000` era el valor de Monero, adoptado como punto de partida por ser el único
precedente en producción. **Recalibrado a 384 000 el 2026-09-09** (P-041): la tarifa escala con
`recompensa_base`, y al dividir la recompensa por 128 para `λ = 1` el antispam se debilitaba en el
mismo factor; 384 000 = 3 000 × 128 devuelve el coste del atacante (543 590 ZZK por GB de cadena) al
valor del diseño original (`research/scripts/rendimiento/verif_zona_libre.py`). **La constante quedó
cerrada con ese modelo de coste explícito; lo que sigue abierto no es su valor, sino su ataque:**
el suelo `TARIFA_SUELO` no ha pasado ronda adversarial —la pregunta es si, al hacer la tarifa
insensible a la capacidad, se abre una vía por el otro lado.

---

## 6 · Bloques

### 6.1 · Cabecera

**Base PoAS lineal, no formato DAG definitivo.** La tabla siguiente conserva los campos de
solución, reloj y sello ya descritos. Los padres múltiples, la posición/altura derivada y sus
compromisos todavía necesitan integración. El tamaño final del DAG y sus offsets no están fijados.

| Campo | Tipo | Bytes | Offset |
|---|---|---|---|
| `consensus_branch_id` | `u32` | 4 | `[0, 4)` |
| `prev_hash` | `u256` | 32 | `[4, 36)` |
| `merkle_root` | `u256` | 32 | `[36, 68)` |
| `timestamp` | `u64` | 8 | `[68, 76)` |
| `height` | `u32` | 4 | `[76, 80)` |
| `slot` | `u64` | 8 | `[80, 88)` |
| `pot_output` | `[u8;16]` | 16 | `[88, 104)` |
| `rango_solucion` | `u64` | 8 | `[104, 112)` |
| `sol.public_key` | `[u8;32]` | 32 | `[112, 144)` |
| `sol.sector_index` | `u16` | 2 | `[144, 146)` |
| `sol.history_size` | `u64` | 8 | `[146, 154)` |
| `sol.piece_offset` | `u16` | 2 | `[154, 156)` |
| `sol.record_commitment` | `[u8;48]` | 48 | `[156, 204)` |
| `sol.record_witness` | `[u8;48]` | 48 | `[204, 252)` |
| `sol.chunk` | `[u8;32]` | 32 | `[252, 284)` |
| `sol.chunk_witness` | `[u8;48]` | 48 | `[284, 332)` |
| `sol.proof_of_space` | `[u8;160]` | 160 | `[332, 492)` |
| `sello` | `[u8;64]` | 64 | `[492, 556)` |
| **Total** | | **556** | |

**C-HDR-01** · La base PoAS lineal de la tabla ocupa `TAMANO_CABECERA = 556`. Se codifica
concatenando los campos en ese orden, con enteros little-endian. Esta cifra no incluye una
extensión de padres DAG y no afirma que el código ya implemente la base.

La **cabecera DAG** conserva los campos y offsets de la prefirma PoAS lineal `[0, 492)` y añade,
antes del sello:

```text
prefijo_fijo_poas_sin_sello(492)
‖ body_commitment(32)
‖ parent_count(1)
‖ extra_parents(32 · (parent_count − 1), o cero en génesis)
‖ sello(64)
```

Offsets fijos: `body_commitment [492, 524)`, `parent_count [524, 525)`,
`extra_parents [525, 525 + 32·(P−1))`, `sello` los últimos 64 bytes. Tamaños:
`normal(P) = 589 + 32·(P−1)` con `1 ≤ P ≤ 15`, de modo que `P=1` mide **589 B**, `P=2` **621 B**
y `P=15` **1 037 B**; el génesis mide **589 B**. Las constantes del tipo distinguen prefijo fijo,
cabecera mínima y cabecera máxima. Los padres adicionales se codifican por sus 32 bytes en orden
lexicográfico estrictamente ascendente, sin duplicados y sin repetir `prev_hash`; el parser
**MUST** rechazar el orden no canónico y no ordenar una entrada hostil para aceptarla.

**C-HDR-02** · La posición de un bloque se deriva de sus ancestros, nunca se confía en la altura
declarada. El génesis tiene `height = 0`. La definición de altura y su relación con cadena
seleccionada, orden DAG y activaciones sigue pendiente; no se usa el índice de un lote como altura DAG.

**C-HDR-02b** · `consensus_branch_id` **MUST** ser exactamente el identificador de rama activo a la
altura del bloque, según la tabla de C-UPG-02. Cualquier otro valor **MUST** rechazarse. No existe
un campo de "versión de bloque" separado: la rama de consenso *es* la versión.

**C-HDR-05** · En el diseño DAG A″, la relación de slot con el padre seleccionado es **no estricta**:
`slot(sp(B)) ≤ slot(B)` (R-FIN-1a). La igualdad no autoriza ciclos; la validación de ancestros,
flujo y justificación secuencial del PoT se integra conjuntamente. El génesis tiene `slot = 0`.

**C-HDR-06** · `rango_solucion` viaja en la cabecera y **MUST** ser exactamente el rango
esperado contextual:

```text
rango_esperado(B) = controlador(past(B), flow(B, slot(B)))
B.rango_solucion == rango_esperado(B)
```

El rango esperado **MUST** aportarlo el contexto del pasado DAG validado y del flujo; debe ser
función **exclusiva** de ese pasado. **MUST NOT** depender del orden de llegada, la punta local, el
reloj local, `timestamp`, `height` declarado ni del propio `rango_solucion` que declara `B`. Es
**redundancia comprobada** para clientes ligeros, nunca fuente de verdad.

Ninguna implementación **MUST** ofrecer una vía que acepte el `rango_solucion` declarado por el
propio candidato como si fuese el esperado: la circularidad **MUST** ser imposible, no solo
desaconsejada. El algoritmo del controlador —ventana, bootstrap, redondeos y fusiones fuera de
ventana— sigue en `TAREAS.md` §2.3; no se define aquí.

> *Nota ilustrativa (no normativa).* La implementación Rust de referencia expone un contexto
> (`zx-consensus::ContextoRangoDag`) que recibe una vista del candidato **sin** acceso a
> `rango_solucion`; el intento de leerlo no compila. Es una forma de cumplir la exigencia doble de
> arriba, no la exigencia misma: cualquier implementación, en cualquier lenguaje, **MUST** hacer
> imposible la circularidad.

**C-HDR-07** · La justificación del PoT no está en la base de cabecera, pero debe acompañar al
bloque para validar su prueba. Sin ella no se puede declarar válido ni adoptar el bloque.
La sincronización debe distinguir datos pendientes de pruebas verificadas como inválidas.

En el formato DAG, el bloque completo es:

```text
dag_header
‖ pot_bundle_count:u8
‖ pot_bundle_count × PotCheckpoints      (128 B cada uno: 8 PotOutput de 16 B)
‖ CompactSize(n_tx)
‖ n_tx × tx_con_testigos
```

`0 ≤ pot_bundle_count ≤ 150` y la cota se comprueba **antes** de reservar. `d = 0` tiene lista
vacía canónica; el génesis usa cero portadores. Para un bloque no génesis, la validación
contextual **MUST** exigir `pot_bundle_count == slot(B) − slot(sp(B))` y rechazar underflow o
diferencia mayor de 150. Los portadores se interpretan en orden cronológico y **MUST NOT**
aceptarse otra codificación del mismo valor. La prueba es evidencia contextual reemplazable y
**no** entra en `block_hash`; la cabecera sí firma/hashea `slot`, `pot_output` y los padres. Mientras
el verificador PoT AES no esté integrado, la comprobación **MUST** devolver un estado explícito
(`IntegracionPotPendiente`), nunca un booleano verdadero provisional.

**C-HDR-08** · La cabecera **MUST NOT** contener la dirección de recompensa. La recompensa es la
salida de la coinbase, ya comprometida en `merkle_root` (C-EMIT-04).

> Autonomys lleva `reward_address` en la solución porque en Substrate la recompensa va a una cuenta.
> ZEROX es UTXO: un solo sitio donde va el dinero. Se retira la extrapolación de ahorro a veinte
> años del ritmo anterior; cualquier estimación nueva debe usar el formato y la tasa DAG.

### 6.2 · Hash de cabecera y sello

**C-HDR-03** · En la base lineal, `prefirma = header_encoding[0, 492)`, excluyendo el sello.
En el formato DAG, `prefirma` es todo lo anterior al sello: el prefijo fijo, el compromiso del
cuerpo, `parent_count` y los padres adicionales. En ambos casos
`pre_hash = H_d("ZZKBlkPreHash___", prefirma)`.

**C-HDR-04** · `sello` **MUST** ser una firma Ed25519 válida sobre `pre_hash` bajo
`sol.public_key`, verificada con las reglas de ZIP-215 (C-SIG-01).

> El sello liga la solución a **este** bloque. Sin él, cualquiera que vea una solución difundida la
> reutiliza con su propia coinbase.
>
> **Corrección de seguridad:** el algoritmo habitual de firma Ed25519 es determinista, pero
> C-HDR-04 no obliga al propietario a usar ese algoritmo para elegir el nonce. Puede producir
> firmas válidas distintas para la misma clave y mensaje; la regresión
> `crates/zx-core/tests/ed25519_no_unicidad.rs` lo comprueba con el verificador real ZIP-215.
> No es falsificación de claves ajenas ni un fallo de Ed25519. Puesto que C-HDR-09 incluye el
> sello, su variación puede cambiar el hash sin cambiar la solución ni el cuerpo. Variar la
> coinbase también cambia `merkle_root`. Ninguna de estas vías queda neutralizada sólo por
> deduplicar pagos: el orden DAG necesita análisis propio de grinding y coste. Esta corrección
> no cambia el algoritmo de firma ni activa una regla de consenso.

**C-HDR-09** · `block_hash = H_d("ZZKBlkHeader____", header_encoding)`, sello incluido.
La base lineal ocupa **556** bytes; la cabecera DAG mide entre **589** y **1 037** bytes según el
número de padres. La misma codificación canónica alimenta wire, `pre_hash`, `block_hash` y la
derivación de identificadores cortos; no hay un segundo serializador.

De ese mismo formato se derivan los máximos que un par **MUST** usar para acotar lo que
transporta; no se escriben a mano:

```text
justificación PoT, payload máximo    = 150 × 128           = 19 200 B
justificación PoT, codificada        = 1 + 19 200          = 19 201 B
cabecera DAG + justificación, máximo = 1 037 + 19 201      = 20 238 B
```

La justificación **codificada** son 1 byte de `pot_bundle_count` más `pot_bundle_count × 128`
(C-HDR-07); el agregado usa la codificada, **no** el payload. La cabecera máxima son
`589 + 32·(15−1) = 1 037 B` (C-HDR-01). Estas cifras acotan cabecera y justificación PoT; el cuerpo
de transacciones se acota aparte por §6.5. Un límite de transporte que aplique otro máximo
rechazaría un bloque legítimo.

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

**C-BLK-04** · La solución de espacio, el PoT y el sello deben verificarse conjuntamente según
§6.2 y §7. La integración pendiente impide declarar un bloque DAG válido con el validador heredado.
**C-BLK-05** · `rango_solucion` debe coincidir con el rango esperado contextual (C-HDR-06).
**C-BLK-06** · El timestamp **MUST** cumplir §7.4.
**C-BLK-07** · La primera transacción **MUST** ser una coinbase válida (§8); ninguna otra lo es.
**C-BLK-08** · Todas las transacciones **MUST** ser válidas individualmente (§5.4).
**C-BLK-09** · Ninguna transacción **MUST** gastar un outpoint gastado por otra del mismo bloque.
**C-BLK-10** · El **weight** del bloque **MUST** ser `≤ LIMITE(H)`, según §6.5.

> **Frontera de implementación comprobada:** `validar_tx` deja las firmas para
> `testigo::satisface`; la ruta actual `validar_cuerpo` tampoco compone esa llamada. Su `Ok` no
> demuestra autorización completa ni cumplimiento de C-BLK-08. La regresión
> `crates/zx-node/tests/disponibilidad_real.rs` conserva el caso de una firma inválida que pasa
> esas comprobaciones parciales y falla en el verificador real de condiciones de gasto.
> La integración PoST/DAG no debe adoptar ese `Ok` como sustituto de validación completa.

### 6.5 · Peso de bloque y límite dinámico

Reglas derivadas de `research/dynamic-blocksize.md`, que las obtuvo de
`monero-project/monero@3d3920d7` y `Cuprate/cuprate@4383f0d6`.

> ⚠️ **MUST** ser el diseño post-2019 (con mediana de largo plazo). El original de CryptoNote
> (2014), con solo la mediana corta, es vulnerable al **big bang attack**: 689 GB de cadena en 24 h
> por ~€118 800 de fees (Isthmus, `noncesense-research-lab/Blockchain_big_bang`).

#### Constantes

```
N_CORTO       = 1 000        // bloques — 16,7 min a λ = 1 bloque/s; era 100 (200 min a T = 120 s), P-041 decisión 3
N_LARGO       = 21 600       // bloques — 6 h a λ = 1 bloque/s; ventana de CAPACIDAD, no de tarifa
ZONA_LIBRE    = 100 000      // bytes de weight
FACTOR_SURGE  = 50
MAX_TX_WEIGHT = 100 000      // bytes — igual a ZONA_LIBRE, ver C-WGT-11
```

> **Por qué divergen de Monero, y por qué `N_LARGO` dejó de ser una ventana larga.** En Monero, y en
> el ZEROX de `T = 120 s`, esta ventana hacía **dos trabajos a la vez**: fijar el suelo de capacidad
> sin penalización y anclar la tarifa mínima (`∝ 1/Mlt²`). Los dos quieren cosas opuestas: la
> capacidad quiere adaptarse deprisa a la demanda real, y la tarifa quiere ser lenta para que nadie
> pueda comprarla. Pegados, una ventana corta abre un **lazo de realimentación**: subir la mediana
> abarata la tarifa, y una tarifa más barata abarata seguir subiéndola; la serie de costes converge y
> llevar la mediana hasta 34 MB/bloque cuesta solo 2,42× la primera ronda
> (`research/scripts/rendimiento/verif_bola_nieve.py`).
>
> **Se rompió el lazo por el otro lado** (2026-09-10, Katana): la tarifa mínima gana un **suelo
> absoluto** (§5.5), con lo que deja de caer tanto cuando la mediana sube como cuando la recompensa
> decae. Con el lazo roto, `N_LARGO` queda libre para hacer **solo** el trabajo de capacidad, y se
> elige por agilidad: **6 h**, con la mediana moviéndose en 3 h. Coste del ataque con el suelo puesto:
> **487 M ZZK, el 49 % del suministro, y no se degrada nunca** (antes caía a 8,7 M en régimen de cola).
> Estado: 0,5 MB, frente a los 757 MB que costaba la ventana de un año. Y una propiedad que la ventana
> larga no tenía: si la mediana llegara a subir, **vuelve sola a la zona libre en 1,4 días** en vez de
> en 5,5 años (`verif_bola_nieve.py` §C).
>
> **Alternativa documentada y NO adoptada:** separar `Mf` de `Mlt` —capacidad en ventana corta de
> consenso, tarifa en ventana larga de política— consigue lo mismo contra el lazo, pero **no** contra
> la degradación en régimen de cola, y cuesta un segundo estado y un estimador que nadie ha atacado.
> Queda escrita por si algún día se quiere que la tarifa **sí** baje con el crecimiento real sostenido.
> `ZONA_LIBRE` de Monero (300 000) está dimensionada para transacciones CryptoNote, mucho mayores
> que una transparente de ZEROX (~350 B para 2-in-2-out). 100 000 bytes dan ~285 tx/bloque,
> que a `λ = 1` son **~285 tx/s ≈ 24,7 M tx/día libres de penalización**, con un suelo de
> crecimiento adversarial de 3 154 GB/año (31 536 000 bloques/año × 100 KB). El techo instantáneo
> es `2 · FACTOR_SURGE · Mlt` = 10 MB/bloque = 28 571 tx/s.
>
> ⚠️ **Recalibrado 2026-09-09 (P-041).** Estas constantes estaban en unidades de bloque calibradas a
> `T = 120 s` (262 800 bloques/año, 26,3 GB/año). Al pasar a `λ = 1` se conserva el **calendario en
> tiempo**; `N_LARGO` se apartó de esa regla al romperse el lazo con la tarifa (ver arriba): pasó de
> 262 800 a **21 600**, no a 31 536 000. `ZONA_LIBRE` se mantiene por decisión de Katana (absorbe el objetivo de
> 1 280 tx/s con 22× de margen y conserva la economía antispam; subirla abarata inflar la cadena como
> `1/ZONA_LIBRE²`). `N_CORTO = 1 000` (Katana, 2026-09-10): la sobrecarga absorbe una ráfaga de 1 280 tx/s en
> **25:02 de media, con desviación típica de 39 s** —los bloques son un proceso de Poisson, no un reloj: el 68 % de
> los episodios caen entre 24:23 y 25:41— y cola máxima de 423 000 tx. El tiempo es el de esa ráfaga concreta: con
> 600 tx/s son 16:42 y con 2 500, 35:11. Los tres momentos: el límite se dobla a los 8:21, cubre la demanda a los
> 16:41 y la cola se vacía a los 25:02 (`verif_n_corto_exacto.py`). Fijar la constante a 998 o 999 movería la media
> un segundo dentro de una franja de ±39 s: no se hizo.
> Además, cola máxima 423 000 tx, y la ventana resiste al mismo adversario que el consenso: un atacante la
> captura por azar nunca al 33-40 % y cada 17 días al 45 % (+3 % sobre lo que ya rellena gratis en la zona
> libre); a partir del 47 % la captura es continua, pero ahí ya gana la carrera de bloques (frontera 46,9 %).
> Con 100 la capturaba cada 8 días al 33 %; con 300, cada 2,3 h al 45 %; con 12 000 (la lectura en tiempo) la
> ráfaga tardaba 5 h (`research/scripts/rendimiento/verif_n_corto_barrido.py`).

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
> el peso alimenta C-WGT-09 (validez de bloque) y C-EMIT-06 (subsidio del productor): si el peso
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
> emisor puede obligar a un productor a asumir la penalización de C-EMIT-06 para incluirle. Con un
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

## 7 · Prueba de espacio y tiempo — integración del consenso DAG

El destino es PoSpace-Time: espacio archivado con pruebas de solución, un reloj PoT secuencial y
orden GHOSTDAG. Las reglas de investigación se encuentran en
`research/dag-poas-ancla-de-orden.md`, con las correcciones de rondas 9–11.
Ese documento conserva versiones históricas: prevalecen sus enmiendas explícitas, no sus tablas
anteriores. La integración de todas las piezas no está terminada.

### 7.1 · Prueba y desafío

R-FIN-14 describe el reto por slot derivado de la salida PoT secuencial del flujo. No basta
comprobar un hash de cabecera: hay que verificar solución de espacio, testigos KZG, identidad de
billete, reto, distancia de solución, sello y justificación PoT.

**Pendiente:** fijar el formato y validación conjunta, retardo de autoría, puntos de control,
inyección de entropía y dependencias por flujo. No se introduce una prueba de sustitución.

### 7.2 · Rango de solución

El rango esperado es una función de los ancestros candidatos y del flujo. R-FIN-13′ exige que
retarget y emisión contabilicen el mismo conjunto pagable: azules y `rojo_k`, excluyendo `rojo_U3`.
Esto es distinto del conjunto azul que aporta `blue_work` (§11).
La inflación `λ_real = 1,364` del retarget antiguo que solo contaba azules **deja de aplicar**
(`research/dag-poas-ancla-de-orden.md`, R-FIN-13′).

**Unicidad pagable — identidad pagable = el billete (P1).** La identidad pagable es el
**billete**, no la identidad azul que registra U3″. Un billete paga y cuenta
**exactamente una vez** en toda la historia seleccionada. La selección agrupa por
billete y elige una única copia pagable por billete; las demás copias no cobran, no
cuentan en el conjunto pagable y no aplican sus transacciones, tampoco en ventanas
posteriores.

**Contexto persistente.** El conjunto de billetes ya consumidos se arrastra a lo largo
de la cadena seleccionada: al aplicar una ventana, los billetes de sus ganadores entran
en el conjunto, y las ventanas posteriores los excluyen. En reorg, el conjunto se
reconstruye para la nueva cadena: un billete consumido en una historia abandonada
vuelve a estar disponible en la rama que prevalece. Lo respalda el vector
`fixture_reorg_libera_billete` de la comprobación decisiva v1, donde el mismo billete
gana en dos ramas competidoras y, tras el reorg, lo consume el bloque de la rama
prevalente. Consecuencia: un billete no puede cobrar dos veces **ni siquiera a través
de un reorg**, porque la proyección económica se reconstruye desde génesis sobre la
cadena que prevalece y los efectos de la rama abandonada se retiran íntegros. El
contexto nunca sobrevive a un reorg a favor de la rama perdedora.

**Copia en mergeset posterior o con ventana de origen fuera de la historia: INERTE.**
Ni cobra ni cuenta. Son **dos reglas independientes**: (a) el billete ya está en el
conjunto consumido de la cadena seleccionada; (b) la ventana de origen de la copia no
es la ventana de la historia que la fusiona. Cualquiera de las dos basta. En el
instrumento no se pueden aislar en vectores distintos porque el catálogo rechaza
declarar una copia con ventana de origen distinta a la de su billete; la inercia por
fusión posterior queda respaldada por dos guardas simultáneas, no por una.

**Desempate entre copias del mismo billete — P1, DECIDIDO POR KATANA (2026-09-12).**
Los candidatos al desempate son los bloques azules y los `rojo_k`; los `rojo_U3`
quedan excluidos de la candidatura (es lo que implementa `eligible()` en DCM-v0.1 y lo
que exige R-FIN-13′). Entre copias del mismo billete gana la **azul primero**; en
igualdad de color, menor `rank` (C-ORD-01 y C-ORD-02). No hay un tercer desempate: el
id de bloque que la redacción anterior añadía al final es **redundante**, porque `rank`
ya es total y ya termina en ese id. P0 (orden
por `(rank, id)` sin preferir color) queda **retirado como política de consenso de
ZEROX**; sigue existiendo y siendo válido en el instrumento como política de estudio,
para comparar P0 y P1 en vistas separadas, y la suite de la comprobación decisiva
sigue probando ambas: el vector `fixture_desempate_color` muestra que P0 y P1 eligen
ganadores distintos, y P1 elige el azul.

**Relación con R-FIN-8′.** Esta regla **REFINA R-FIN-8′(1)**. Leído al pie de la letra,
R-FIN-8′(1) —«Cobran los azules y los `rojo_k`; un `rojo_U3` no cobra nada»— pagaría a
DOS copias `RedK` del mismo billete cuando ninguna de las dos es `rojo_U3`, porque
`rojo_U3` se define como «copia: su identidad ya era azul»; sin esta regla, el SPEC se
contradiría consigo mismo y un implementador pagaría dos veces por el mismo billete.
Con esta regla:
1. Entre copias del mismo billete cobra y cuenta SOLO la copia seleccionada por P1,
   **AUNQUE NINGUNA SEA `rojo_U3`**: sean las dos rojas por k, las dos azules, o una
   de cada color.
2. La clasificación `rojo_k` / `rojo_U3` sigue siendo válida para lo que R-FIN-8′ ya
   resolvía (la copia de una identidad ya azul no cobra); lo que esta regla cierra es
   el caso que aquella clasificación NO cubría (dos copias del mismo billete sin copia
   azul).
3. La selección por billete se aplica **ANTES** de decidir cuál cobra: primero se
   elige la copia pagable del billete, y después se aplica ese resultado. Orden de las
   dos reglas: (i) selección por billete (P1); (ii) pago y aplicación de la única
   copia elegida.
4. R-FIN-13′ no cambia: retarget y emisión siguen contabilizando el mismo conjunto
   pagable. Lo que cambia es que ese conjunto tiene ahora, como máximo, un bloque por
   billete.

**SEPARACIÓN OBLIGATORIA — selección ≠ aplicación.** P1 es el orden de **SELECCIÓN**
entre copias del mismo billete. **NO** es el orden de **APLICACIÓN** del mergeset, que
sigue siendo el de R-FIN-8′(4): por cada bloque de la cadena seleccionada,
`[sp(B)] ++ mergeset(B)` con el mergeset en `blue_work` ascendente, desempate por
menor `solution_distance` y luego hash, azules y `rojo_k` entrelazados, saltándose los
`rojo_U3` — redactado como C-ORD-03, con el orden exacto en C-GD-05. Implementar
«azul primero» en la aplicación rompería R-FIN-8′(4); esta
separación debe quedar escrita para que nadie la confunda. El acoplamiento R-FIN-13′
—retarget y emisión contabilizan el mismo conjunto pagable— sigue vigente y no depende
de esta regla.

**C-ORD-01** · **`rank`, definición operativa.** `rank(B) := (blue_work(B),
solution_distance(B), id(B))`, comparado en orden lexicográfico ascendente: primero
`blue_work`, luego `solution_distance`, luego el id por orden de bytes. Gana el
**menor**. El último componente **MUST** ser el id de 32 bytes del bloque: es lo que
hace total el orden, y ninguna redefinición futura de `rank` puede quitarlo sin volver
a demostrar la totalidad.

- **Totalidad — DEMOSTRADO.** Cada componente es un orden total (enteros para
  `blue_work` y `solution_distance`; orden lexicográfico de bytes para el id), y el
  producto lexicográfico de órdenes totales es total. Bajo el supuesto declarado de que
  no hay colisión de id, dos bloques distintos tienen id distinto, así que sus tuplas
  `rank` nunca empatan.
- **Compatibilidad causal — DEMOSTRADO.** Si `A` es padre de `B`, entonces
  `rank(A) < rank(B)`. `sp(B) ∈ blues(B)` y `w(x) ≥ 2^64 > 0` (C-GD-01, C-GD-08), luego
  `blue_work(B) > blue_work(sp(B))`; y `sp(B)` maximiza `blue_work` entre los padres
  (C-GD-03), luego `blue_work(B) > blue_work(A)`. Decide el primer componente: el orden
  respeta siempre la ancestría, sin recurrir a `solution_distance` ni al id.
- **Alcance.** `rank` es una función **global** del bloque: depende solo de `past(B)`.
  El color, en cambio, es contextual (C-GD-09). P1 combina las dos cosas, que son de
  naturaleza distinta.

**C-ORD-02** · **Selección entre copias del mismo billete (P1).** Entre las copias
candidatas —azules y `rojo_k`; las `rojo_U3` quedan excluidas— gana la azul; en
igualdad de color, la de menor `rank`. **No hay tercer criterio**: por C-ORD-01 dos
copias distintas nunca empatan en `rank`.

**C-ORD-03** · **Orden de aplicación.** Por cada bloque `C` de la cadena seleccionada,
desde el génesis: `[sp(C)] ++ mergeset(C)` con el mergeset en el orden de C-GD-05,
azules y `rojo_k` entrelazados y saltando los `rojo_U3` (R-FIN-8′(4)). Cada bloque se
aplica **exactamente una vez**, en el primer bloque de cadena que lo fusiona
(R-FIN-8′(6)). La selección de C-ORD-02 **MUST NOT** alterar este orden.

**Estado de la evidencia.** Las tres reglas están implementadas y comprobadas en
`veritas/consenso/ghostdag-rank-v1/` (GDR-v0.2), con las demostraciones escritas en su
`PROPUESTA-SPEC.md`. Lo que sigue pendiente es el **código del nodo**: los fixtures de
DCM-v0.1 aún suministran `rank` y color como etiquetas, en vez de recalcularlos con
estas reglas.

**PENDIENTE — recompensa del bloque honesto tardío.** La regla (b) alcanza más de lo
que sugiere: un bloque honesto con billete único que nadie disputa, fusionado después
del cierre de su ventana, no cobra nunca. El destino de esa recompensa —pérdida
definitiva, o reinclusión como la que modela la cola de RCE-v0.1— **NO está decidido**;
la regla (b) no debe leerse como que ya lo está. Con Δ sin medir en DAG, no es un caso
de borde raro.

**Límites declarados de la evidencia.** La comprobación decisiva v1
(`veritas/consenso/comprobacion-decisiva-v1/`) que respalda esta regla: no usa firmas
ni criptografía (los billetes son IDs declarados en el fixture); no valida PoAS contra
el rango del pasado causal; no modela red; la convergencia está probada para UN par de
órdenes de entrega, no para un barrido de órdenes; y asume el vínculo
billete→oportunidad, cuya propiedad real depende de
`veritas/consenso/contrato-billete-v1/` y de C-HDR-03/04 (dos firmas Ed25519 bajo la
misma `public_key`, R-FIN-8′).

**Pendiente:** separadamente, ventana, arranque por red, límites y
redondeos, fusiones fuera de ventana y validación de ramas candidatas con pesos reales. Ningún
rango declarado por el productor sustituye su cálculo contextual. Los valores históricos
`W≥3 083, γ≤0,25` y `W≥12 331, γ≤1` no certifican este controlador: proceden de otra tasa/F y
una aproximación de desviación típica, no de una cota uniforme adversarial de error menor al 1 %.

### 7.3 · Parámetros del diseño y límites de la evidencia

El perfil de estudio A″ conserva `λ_obj = 1 bloque/s` nominal, `τ_nom = 1 s/slot`, `k = 30`
y `S_max = 150 s` nominales. Prevalecen slot **no estricto** (`slot(sp)≤slot(B)`), U2/U3″
dinámica, R-FIN-8′ y R-FIN-13′; el k25, el rechazo del empate y U3′-filtro residuales están
superados. R-FIN-12 conserva los límites 15 padres / 180 bloques de mergeset a k30 y el shuffle
de la **cola de candidatos**, no una cuota aleatoria de padres finales. El verificador no
colorea al azar ni decide por orden de llegada.

`F = 2 h` sigue provisional; no es la espera de Cortex ni se iguala por defecto a L. `L = 1 h`
es candidato condicionado, no adopción inequívoca. `I`, `L`, `ρ_max`, la configuración final
de `F` y la calibración frente a `Δ` siguen abiertos.

`45 s` es el máximo observado de `W_dec` en las simulaciones citadas, no una cota
universal. `I ≥ ρ_max·W_dec` es una restricción contra evaluar una época durante la elección
del ancla; no demuestra finalidad a los 112,5 s. El retardo efectivo de red `Δ` necesita medición.
Los escenarios que usan distintas tasas, pérdidas de red o presupuestos adversarios no se combinan.

#### Contrato de unidades del perfil de estudio

Esta notación consolida magnitudes; no fija todavía su serialización ni completa el protocolo:

- `slot(B)`, `I_slots`, `L_slots`, `S_max_slots` y `D_aut_slots` son índices o cantidades enteras
  de slots PoT. Con τ nominal de 1 s/slot, la referencia S_max se representa por 150 slots;
  limita `slot(B)−slot(sp(B))`, no el tiempo de retención ni Δ de red.
- `T_j=j·I_slots` es el umbral del inyector; `t_j=slot(I_j)+L_slots` es el índice de inyección.
  R-FIN-9 remite a ese inyector, no al contador obsoleto `c·j`. Origen/bootstrap, existencia del
  ancla, desempates y disponibilidad después de poda aún deben cerrarse. I separa umbrales,
  no necesariamente los instantes realizados de inyección.
- `N(s)` es trabajo secuencial por slot. Su eventual cambio coincide con la inyección, pero
  su regla de actualización y su valor inicial no están definidos. El `ensure_root` del
  actualizador de Autonomys **no se adopta** como autoridad de ZEROX.
- `τ_nom·I_slots` es duración nominal. Para N fijo, si `v_ref` es la velocidad de producción
  secuencial en slots/segundo físico y `ρ_max=v_A,max/v_ref`, la expresión dimensional del
  presupuesto histórico es `I_slots≥ρ_max·v_ref·W_dec,físico`. Esto no prueba su suficiencia:
  falta precisar trabajo disponible, comienzo y deadline; si N varía, también su calendario.

Se conserva `S_max_slots<I_slots` como **condición suficiente del perfil propuesto**, no como
necesidad universal demostrada. El candidato de 112,5 s nominales no satisface esa condición
manteniendo S_max; no se sustituye por otro I ni se reduce S_max para hacerlo encajar. Además,
si se pretende impedir terminar una evaluación hasta un deadline inclusivo, la igualdad del
presupuesto histórico requiere resolver el borde: no excluye por sí sola terminar justo a tiempo.
Ninguna de estas restricciones constituye una regla demostrada de irreversibilidad de pagos.

La procedencia y los cierres pendientes están en
[la ficha de modelo, revisión 2](veritas/finalidad/baseline-30m/MODELO.md), §§3 y 6.

### 7.4 · Timestamps y timelocks

**C-TS-01 · Contexto temporal.** La relación entre timestamp, slot y ancestros debe quedar fijada
en la integración PoT/DAG; no se hereda una separación de un segundo por cada arista.

**C-TS-02 · MTP para timelocks.** La política de mediana temporal para `lock_time` y HTLC debe
usar ancestros de la historia candidata. La selección de esos ancestros en el DAG está pendiente;
MTP no sustituye el índice PoT del retarget de rango.

**C-TS-03 · Future Time Limit.** Un rechazo por adelanto respecto al reloj local es temporal:
se difiere y reintenta, no se cachea como invalidez permanente ni justifica banear al par.
El valor de FTL para recalibración PoT queda pendiente.

**C-TS-04 · Prohibida la hora de red.** Ninguna regla de consenso usa la mediana de relojes de
pares ni hora ajustada por pares. La referencia temporal local no se convierte en voto de red.

**C-TS-05 · Producción.** El productor respeta el slot y la política temporal que se congelen
para PoT/DAG. No se publica una fórmula de producción antes de fijar esa relación.

---

## 8 · Emisión y coinbase

### 8.1 · Curva de emisión

```
SOFT_CAP           = 1 000 000 000 ZZK = 100 000 000 000 000 000 brek
SHIFT              = 26                 // recalibrado 2026-09-09 (P-041): 19 + 7, 2^7 = 128 ≈ 120
TAIL_EMISSION      = 0,26666666 ZZK/bloque =        26 666 666 brek   // 32 ZZK / 120
COINBASE_MATURITY  = 12 000 bloques      // 3,33 h a λ = 1; era 100 a T = 120 s
```

**C-EMIT-01 · Recompensa base.** La recompensa base del bloque de altura `H` es:

```
recompensa_base(H) = max( (SOFT_CAP_brek − emitido(H)) >> SHIFT , TAIL_EMISSION )
```

donde `emitido(H)` es la suma de los **subsidios efectivos** (C-EMIT-06) de los bloques `0 .. H−1`.

> Decaimiento exponencial suave, sin halvings. Recompensa inicial = `1 490 116 119` brek
> ≈ **14,90 ZZK**. La fórmula cae por debajo del tail hacia el **año 8,56**; el suministro cruza
> los 1000 M hacia el **año 10,69**. Inflación perpetua **0,84 %/año**, decreciente en porcentaje
> para siempre. Calendario fijado 2026-09-04 (P-002) a `T = 120 s`; **recalibrado el 2026-09-09
> (P-041) a `λ = 1 bloque/s` conservando el calendario en tiempo**: `SHIFT` sube en 7 (2⁷ = 128 es el
> entero más cercano a 120, y el calendario se estira un 5,3 %: 10,15 → 10,69 años) y `TAIL_EMISSION`
> se divide por 120. Con las constantes antiguas a `λ = 1` el techo se cruzaba en 30,9 días y la
> inflación perpetua era del 100,92 % anual (`research/scripts/rendimiento/verif_emision_lambda.py`).
>
> **El suministro NO tiene máximo.** A diferencia de Bitcoin, la cola no se apaga: tras el año
> ~10,69 se emiten `26 666 666 brek × 31 536 000 ≈ 8 409 600` ZZK/año indefinidamente. Por eso ZEROX no puede tener
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
> y no es garantía general. Lo que el consenso necesita sí está demostrado: **un productor nunca cobra
> más por hacer un bloque más grande**.
>
> ⚠️ **`u128` tiene un techo real, y no es infinito.** Con `base = recompensa_base(0)`, el numerador
> máximo `base·M²` **desborda `u128` en cuanto `M > 42 238 129 881 480`**. No es un agujero de
> acuñación —`checked_mul` **falla cerrado**— pero sí sería una **denegación de validación** si `M`
> llegara ahí. Lo que lo hace inalcanzable no es el tipo, es la física: un bloque en ese umbral
> pesaría ~84,5 TB. Queda como **límite conocido documentado**, no como problema resuelto.

**C-EMIT-07 · Orden de aplicación — el tail NO es un suelo por bloque.** El suelo `TAIL_EMISSION`
se aplica **dentro** de `recompensa_base` (C-EMIT-01), es decir **antes** de la penalización
C-EMIT-06, y la penalización lo multiplica. En consecuencia, un productor cuyo bloque exceda la
mediana efectiva percibe **menos de `TAIL_EMISSION`**, tendiendo a 0 conforme `x → 2M`.
El contador `emitido(H)` acumula el **subsidio efectivo ya penalizado**: la moneda no percibida
**MUST NOT** emitirse nunca.

> ⚠️ **`TAIL_EMISSION = 0,26666666 ZZK/bloque` (26 666 666 brek) es la emisión NOMINAL, no un
> mínimo garantizado por bloque.** Decidido 2026-09-04 (P-009f, hallazgo H-004); valor
> recalibrado el 2026-09-09 (P-041).
> La alternativa —aplicar el suelo *después* de penalizar— garantizaría el tail, pero anularía
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
`COINBASE_MATURITY = 12 000` bloques (3,33 h a `λ = 1`) desde su creación.

---

## 9 · Capa blindada Orchard — integración pendiente

Esta sección **no contiene reglas normativas todavía**. La investigación identificada a continuación
sirve de base; quedan por integrar las reglas y su validación.

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

## 11 · Orden y selección en GHOSTDAG

El diseño destino usa GHOSTDAG con `blue_work = Σ⌊2^128/(SR+1)⌋` sobre azules
(`research/dag-poas-ancla-de-orden.md`, R-FIN-6 y estructura de §2).
Es una modificación propia: el commit de Autonomys fijado en `PDF/README.md` usa `MAX_u64−SR`.

Las reglas de esta sección fijan la **dirección de cada desempate**, que es donde dos
implementaciones podían divergir. Katana la decidió el 2026-09-14 (`TAREAS.md` §1.3, «regla C»),
y el instrumento `veritas/consenso/ghostdag-rank-v1/` (GDR-v0.2) la implementa y la comprueba:
los seis vectores oficiales de rusty-kaspa (168 bloques) coinciden al 100 %, un oráculo con claves
propias coincide con el kernel en 7 200 DAGs, y 1 000 órdenes de llegada por familia dan el mismo
resultado. Ninguna de estas reglas tiene todavía código en `crates/`; están declaradas como trabajo
futuro en `ci/reglas-sin-codigo.txt`.

**C-GD-01** · **Peso de un bloque.** `w(B) = ⌊2^128 / (SR(B)+1)⌋`, con `SR` de tipo `u64` y
división entera exacta. El cálculo **MUST** hacerse en enteros; usar coma flotante está
**prohibido**. `SR = 0` da `w = 2^128`, que no cabe en `u128`; `SR = 2^64−1` da el mínimo,
`w = 2^64`. Por tanto `w(B) ≥ 2^64 > 0` para todo bloque.

**C-GD-02** · **Dominio de `blue_work`.** `blue_work` se representa como `u256` (§2, tabla de
tipos). Toda suma **MUST** usar aritmética comprobada (C-ENC-03): un desbordamiento es **fallo de
consenso explícito**, nunca envoltura ni truncamiento. Cota demostrada: `blue_work(B) < n · 2^128`,
donde `n = |past(B)| + 1`, porque cada bloque aporta su peso como mucho una vez al conjunto azul
acumulado; en bits, `128 + ⌈log₂ n⌉`. Con `u256` la cota no se alcanza salvo con un DAG de `2^128`
bloques. No se hereda el tipo de Autonomys ni el de Kaspa: `Uint192` desbordaría al acumular `2^64`
contribuciones máximas, y ZEROX no declara ningún tope de bloques.

**C-GD-03** · **Padre seleccionado.** `sp(B)` es el padre de **mayor** `blue_work`; si empatan,
el de **menor** `solution_distance`; si vuelven a empatar, el de **menor** id por orden de bytes.
Es decir: entre los padres de mayor `blue_work`, el que iría primero en el orden del mergeset
(C-GD-05). El mismo criterio elige la punta virtual entre las puntas del DAG.

**C-GD-04** · **Mergeset.** `mergeset(B) = past(B) \ (past(sp(B)) ∪ {sp(B)})`. El bloque **MUST**
rechazarse si supera los límites de R-FIN-12: más de 15 padres, o `|mergeset(B)| + 1 > 180` con
`k = 30`. Siguen vigentes `slot(sp(B)) ≤ slot(B)` (C-HDR-05) y `slot(B) − slot(sp(B)) ≤ S_max`.

**C-GD-05** · **Orden del mergeset.** Ascendente por `(blue_work, solution_distance, id)`, con el
id comparado por bytes. Es el **mismo** orden para colorear (C-GD-06, C-GD-07) y para aplicar
(C-ORD-03). **MUST NOT** depender del orden de llegada de los bloques.

**C-GD-06** · **Coloreo por k-cluster.** Se recorre el mergeset en el orden de C-GD-05. El
contexto de partida es el conjunto azul heredado de `sp(B)`, y `blues(B)` empieza por `sp(B)`. Un
candidato es **azul** si (i) su anticono dentro del contexto tiene como mucho `k` bloques, y
(ii) ningún azul de ese anticono llega a `k` con él dentro. Si falla cualquiera de las dos, es
`rojo_k`. Un candidato aceptado se añade al contexto antes de evaluar el siguiente.

**C-GD-07** · **Unicidad de billete (U2 y U3″ dinámica).** Con identidad de billete
`(public_key, sector_index, history_size, chunk, slot)` (R-FIN-11):
- **U2:** si esa identidad aparece en `padres(B)` o en el pasado estricto de algún padre, `B` es
  **inválido**. Es regla de consenso, no filtro de retransmisión.
- **U3″ dinámica:** un candidato del mergeset cuya identidad ya sea azul en `past(sp(B))`, o ya
  haya sido coloreada azul por un candidato anterior **en el orden de C-GD-05**, es `rojo_U3`, y
  **MUST NOT** evaluarse contra el k-cluster.

**C-GD-08** · **Acumuladores.** `blue_score(B) = blue_score(sp(B)) + |blues(B)|` y
`blue_work(B) = blue_work(sp(B)) + Σ_{x ∈ blues(B)} w(x)`, donde `blues(B)` incluye a `sp(B)`. Un
bloque **no** aporta su propio peso a su `blue_work`: lo hereda cuando otro lo incluye entre sus
azules.

**C-GD-09** · **Determinismo y color contextual.** Los datos GHOSTDAG de `B` —padre seleccionado,
mergeset ordenado, colores, `blue_score` y `blue_work`— son función **exclusiva** de `past(B)`:
**MUST NOT** depender del orden de llegada, de la punta observada ni del reloj local. El **color**,
en cambio, es contextual: es el que el bloque recibe en el bloque de cadena que lo fusiona, y puede
cambiar si un reorg cambia quién lo fusiona. El dato almacenado de un bloque no cambia; sí cambia
el papel que juega al ser fusionado.

**Lo que esta sección todavía no cierra.** Conflictos de transacciones y estado UTXO sobre el orden
resultante, cálculo contextual del rango, flujos y la laguna de unicidad pagable declarada en §7.2.
Los identificadores C-FORK-01 a C-FORK-04 del acumulador anterior quedan retirados; no se reutilizan
ni se reciclan sus números.

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
una ventana de bloques —las medianas `Mst`/`Mlt` de §6.5, las cachés de rango y de contexto PoT—
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

**C-REORG-07 · Límite heredado de la implementación, pendiente de sustituir en el DAG.**

```
MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 11 999 bloques
```

Este valor se conserva para identificar el estado transitorio del código; no fija la finalidad
del consenso DAG. R-FIN-7 propone no reorganizar por debajo de `F` segundos del reloj de slot
e ignorar la punta incompatible, sin detener el proceso. Su integración está pendiente.

Una restricción de reorg protege el estado local, pero no demuestra por sí sola acuerdo entre
dos nodos aislados. Convertir 11 999 bloques a unas 3,33 h a tasa nominal no da un plazo
determinista. No se publican ambas reglas como simultáneamente activas.

---

## 7.5 · Ritmo de desafío y caducidad de sectores

```
SIGMA                 = 1         // segundos por slot, variante A″
VIDA_MINIMA_BLOQUES    = 65 536    // base existente, calendario DAG pendiente
DISPERSION_BLOQUES     = 1 048 576 // base existente, calendario DAG pendiente
```

**C-SLOT-01** · La variante DAG A″ usa un slot de un segundo y tasa objetivo de un bloque por
segundo. La tasa de producción y la duración del slot son magnitudes distintas.

**C-SLOT-02** · El calibrador del rango debe admitir el régimen DAG con múltiples soluciones
por slot. Su fórmula y límites están pendientes; no se conserva la restricción lineal `q ≥ 20`.

**C-SLOT-03** · La ventana durante la que un reto puede explotarse depende de publicación,
autoría e inyección PoT. Su cota final no se identifica automáticamente con `SIGMA` ni con `Δ`
de red. El retardo de autoría y esta ventana siguen pendientes de integración.

Las reglas de sectores siguientes conservan su base documental. La altura usada, su calendario
y su relación con la finalidad temporal deben redefinirse conjuntamente para el DAG.

**C-EXP-01** · Todo sector lleva `altura_ploteo`, válido solo si `altura_ploteo < altura_actual`.

**C-EXP-02** · `desplazamiento = blake3(sector_id ‖ hash_bloque[altura_ploteo]) mod DISPERSION_BLOQUES`.
Como `DISPERSION_BLOQUES = 2^20`, el módulo es **exactamente una máscara de 20 bits** sobre la salida
de blake3: `bytes[0] | (bytes[1] << 8) | ((bytes[2] & 0x0F) << 16)`.

> Potencia de dos **no es estética**: sin división ni bignum no hay endianness que acordar.
> Autonomys hace `U256::from_le_bytes(...) % ...` (`sectors.rs:145`), y con un módulo cualquiera
> habría que replicar ese `U256` bit a bit en toda implementación o divergir.
> **Si alguien cambia `DISPERSION_BLOQUES` a un valor que no sea potencia de dos, esa clase de bug
> vuelve.**

**C-EXP-03** · `caducidad_altura = altura_ploteo + VIDA_MINIMA_BLOQUES + desplazamiento`. El sector
es válido para producir bloques si y solo si `altura_ploteo ≤ altura_actual < caducidad_altura`.

**C-EXP-04** · `hash_bloque[altura_ploteo]` **MUST** tomarse de la **cadena que se está validando**,
nunca de «la cadena activa del nodo».

> Es la fuente de no-determinismo más peligrosa de esta familia: leerlo de la cadena activa hace que
> dos nodos discrepen al validar una rama lateral. **Split garantizado.**

**C-EXP-05** · La caducidad debe depender de una referencia de historia ya estabilizada según
la finalidad adoptada. La desigualdad de alturas de la base lineal no demuestra esta propiedad
para `F` temporal; su condición concreta queda pendiente.

**C-EXP-06** · Todo nodo **MUST** retener los hashes de bloque de al menos las últimas
`VIDA_MINIMA_BLOQUES + DISPERSION_BLOQUES = 1 114 112` alturas (35,65 MB). Un sector cuyo
`altura_ploteo` caiga fuera de esa ventana está caducado por construcción.

> ⚠️ **La dispersión no es exigible, y el SPEC no debe fingir que lo es.** Un granjero puede moler su
> propia `altura_ploteo` —manteniendo huecos de disco vacíos hasta que salga un buen sorteo— y
> quedarse con el 99,9 % de `DISPERSION_BLOQUES`. **La vida de diseño es
> `VIDA_MINIMA + DISPERSION − 1`; la dispersión es una red de seguridad
> para el granjero ingenuo, no una garantía.** Las constantes están dimensionadas contra los dos
> regímenes.

## 12.1 · Checkpoint firmado del periodo frágil — `C-CHK`

**Diseño de bootstrap pendiente de integrar.** Se conservan las constantes y restricciones
identificadas, sin activar un firmante ni equiparar este mecanismo a finalidad general.
La relación rango/espacio se debe recalibrar con el rango PoST/DAG; la conversión antigua
con denominador 120 no certifica una equivalencia de espacio en el régimen A″.

Una red joven de pruebas de espacio no se defiende sola: **con el PoT sin verificar, el atacante
elige el desafío**, y entonces forjar peso de cadena cuesta lo mismo que auditar. Por debajo de
cierto tamaño de red eso sale más barato que defenderse.

⚠️ **El SPEC no fija aquí el coste por auditoría, y es deliberado.** La banda medida va de 2,82 µs
(atacante con lote SIMD) a 42,92 µs (granjero honesto con la implementación de referencia), y la
cota inferior **no tiene techo conocido** —blake3 en GPU está órdenes de magnitud por encima y nadie
lo ha medido. Un umbral derivado de ese número sería provisional; `UMBRAL_CHECKPOINT` se fija por
**coste económico del espacio honesto**, no por core-horas. Esta justificación histórica no
sustituye la recalibración de rango y bootstrap indicada al comienzo de esta sección.

```
UMBRAL_CHECKPOINT  = 90 185 365       // base conservada; equivalencia de espacio DAG pendiente
ALTURA_CADUCIDAD   = 63 072 000       // base conservada; semántica de altura DAG pendiente
```

**C-CHK-01** · Existe **un único** checkpoint firmado en la vida de la cadena. Una vez emitido, la
clave que lo firma se destruye y **MUST NOT** emitirse ningún otro.

**C-CHK-02** · El checkpoint es válido solo si `rango_solucion` de su bloque es
`≤ UMBRAL_CHECKPOINT`. Un checkpoint emitido por encima de ese rango —o sea, con la red más
pequeña que el umbral— **MUST** rechazarse.

> El rango **estrecha** al crecer la red, así que la condición se escribe al revés de como se
> piensa. `RANGO_INICIAL = 307 445 734 561 808` es **3 409 042×** más ancho que el umbral.

**C-CHK-03** · La autorización caduca en `ALTURA_CADUCIDAD`. Un checkpoint cuyo bloque esté a altura
`≥ ALTURA_CADUCIDAD` **MUST** rechazarse, aunque la firma sea válida y el rango cumpla C-CHK-02.

**C-CHK-04** · Un checkpoint válido fija la rama canónica: toda cadena que **no** contenga ese
bloque a esa altura **MUST** rechazarse, sin importar su peso acumulado.

**C-CHK-05** · Por debajo de la altura del checkpoint, un nodo **MAY** omitir la verificación de la
justificación del PoT. Por encima, **MUST** verificarla entera. **No hay muestreo.**

> ZEROX **no porta** el muestreo probabilístico de Autonomys (`verifier.rs:178-199`). Su constante
> `3 162` no tiene derivación pública —la especificación está en un Notion privado— y sus bordes no
> cierran: en `diff = 6 235` la tasa de muestreo **baja** al crecer la cadena. Esta observación
> histórica no autoriza a omitir la validación de PoT fuera del bootstrap especificado.

**C-CHK-06** · El checkpoint **MUST NOT** poder acuñar, cobrar recompensa, ni alterar la validez de
ninguna transacción. Su único efecto es el de C-CHK-04.

**C-CHK-07** · La autoría de bloques es **libre desde el bloque 1**. El checkpoint dice cuál es la
cadena canónica, **no** quién puede producir bloques.

> Es la diferencia con el lanzamiento de Autonomys, que arrancó con
> `AllowAuthoringBy::RootFarmer` y las recompensas desactivadas a mano.

## 13 · Confirmación de pagos — política del comercio

Esta sección no añade consenso. Cortex y cualquier otro comercio eligen la espera según importe
y riesgo. El consenso no depende de Cortex. La seguridad de una política requiere declarar red,
adversario, regla de aceptación y estado del consenso PoST/DAG.

### Referencia nominal de investigación

La carrera histórica `prev(α,1,t,90,1)` usa tasa 1/s, `k = 30`, ventaja inicial `3k = 90`
y pérdida de red aproximada por cero. Sus resultados publicados a 1 800 segundos son
`7,071·10⁻³⁶` para `α = 0,33` y `1,148·10⁻¹⁰` para `α = 0,40`
(`research/scripts/d12-quorum/salida_b.txt`).
Son resultados de ese modelo, no probabilidades universales certificadas para la implementación.

La pérdida `δ₀(Δ,k,λ)` requiere el escenario de red correspondiente. No se incorpora la inflación
del retarget antiguo: R-FIN-13′ la sustituyó. La tabla final exige el modelo coherente de pesos,
retarget, red y aceptación; queda pendiente.

### Confirmación adaptativa

El gate de `research/scripts/d16-gate/` compara una adaptación propia bajo un modelo nominal.
No refuta la familia DAGKNIGHT ni toda confirmación adaptativa. Sigue sin demostrarse que el
rank visible `k_ref` sustituya al `k` de la cota de freeloading; las simulaciones de retención
constituyen contraejemplos a la adaptación probada.

Hay dos diferencias por resolver antes de publicar ratios o un descarte general: el peor
`k_ref` proviene de red degradada mientras el gate mantiene pérdida cero; además, esperar
M bloques y evaluar la carrera a su tiempo medio son criterios de parada distintos. El factor
`2,56·10⁵` del gate no se presenta como riesgo exacto de la política original.

### Irreversibilidad y trabajo pendiente

La regla temporal R-FIN-7 del diseño DAG y el límite transitorio C-REORG-07 deben reconciliarse
al integrar consenso. Una parada o rechazo local no prueba acuerdo global durante una partición.
No se publica «cero riesgo de doble gasto a 3,33 h».

Falta fijar una política de aceptación verificable, medir `Δ`, integrar y comprobar `blue_work`,
y rederivar la tabla de riesgo. Los comités de decisión quedan fuera del alcance del proyecto.

---

## 14 · Activación de cambios de consenso

Las reglas comunes de actualización toman como referencia ZIP-200 y el código de
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
> perfectamente legítimo** según la regla de selección. Zcash se libró en Overwinter por
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
> compromiso de rama se conserva en la cabecera DAG, cuyo formato fija §6.1 (`consensus_branch_id`,
> C-HDR-02b).

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
> `zx-node`. Todos los demás huecos —el relé compacto, la integración PoT/DAG, la validación contextual de
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

## 15 · Bloque génesis — parámetros PoST/DAG pendientes

### 15.1 · Definición

**C-GEN-01 · Definición constructiva, hash asertado.** El génesis se construye determinísticamente
a partir de parámetros explícitos y su hash se compara con una constante congelada al arrancar.
El formato de la cabecera del génesis lo fija §6.1; los **valores** concretos de sus campos —raíz
inicial, reloj PoT, rango y bootstrap— quedan pendientes de definición.

**C-GEN-02 · Bootstrap.** La inserción del génesis es una ruta explícita. Las condiciones de
prueba y estado inicial PoST que la distingan de bloques posteriores deben especificarse antes
de habilitar una red; esta sección no inventa una exención de prueba.

**C-GEN-03 · Coinbase de valor cero e inconectable.** La coinbase del génesis tiene
`Σ value(salidas) = 0` y sus salidas no se insertan en el UTXO set.

**C-GEN-04 · Redes distintas, génesis distintos.** Mainnet y testnet deben tener hashes distintos.

### 15.2 · Parámetros de lanzamiento

**C-GEN-05** · El mensaje de coinbase contiene una referencia pública verificable de la fecha de
lanzamiento. Su contenido no interviene en las reglas posteriores de validez.

**C-GEN-06 · Fecha plausible.** `ts(0) ≥ TIMESTAMP_MINIMO_GENESIS = 1 767 225 600`
(2026-01-01 UTC). Los marcadores de posición no habilitan el arranque.

**C-GEN-07 · Hash congelado por red.** El binario compara el hash construido con el de la red
seleccionada y aborta si falta o no coincide. Los hashes del formato anterior no sirven para el
génesis PoST/DAG.

**Pendiente:** mensaje, timestamp, estado inicial de espacio y PoT, rango inicial, parámetros DAG
y hashes de mainnet/testnet. No hay un génesis de lanzamiento completo descrito aquí.

---

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

**C-STORE-05 · Codificación de una entrada del UTXO set.** Una entrada se guarda como un
par clave/valor:

```
clave = prev_txid(32) ‖ prev_index(4, BIG-ENDIAN)                          → 36 B
valor = value(8, i64 LE) ‖ altura_creacion(4, LE) ‖ es_coinbase(1) ‖ Lock  → 46 B con `PubKey`
```

El `Lock` usa **la misma codificación que en el cable** (C-WIRE-02), sin una variante propia: dos
formas de escribir un `Lock` serían dos sitios donde equivocarse, y la segunda envejecería sola.

> **Vive aquí y no en §2.4 con las demás codificaciones**, y la diferencia no es de orden: §2.4 es
> codificación **canónica**, con reglas que dos nodos MUST cumplir igual. Esta no lo es.
>
> **`prev_index` va en big-endian y el resto no.** No es incoherencia: es la misma razón que
> C-STORE-03 da para las alturas. El orden lexicográfico de las claves en RocksDB **es** el orden de
> los bytes, así que con big-endian todas las salidas de una misma transacción quedan contiguas y
> recorrerlas es un barrido de prefijo en vez de 4 000 millones de búsquedas. Los campos del
> **valor** no se ordenan por nada, así que ahí manda la coherencia con el resto del formato.
>
> **Esto NO es consenso.** Ningún byte de esta codificación entra jamás en un hash ni en una firma:
> el UTXO set es estado local reconstruible, y dos nodos pueden guardarlo de formas distintas sin
> divergir. Decirlo importa porque todo lo demás en §2.4 sí es normativo, y tratar esta regla como
> si lo fuera llevaría a alguien a bloquear un cambio de formato de disco por miedo a un fork que no
> existe. Lo único que **MUST** cumplirse es que la codificación sea **inyectiva**: dos entradas
> distintas no pueden producir los mismos bytes, o el almacén perdería UTXOs en silencio.
>
> **Sin compresión, y a propósito.** Bitcoin Core comprime cada `Coin`: la altura y el flag de
> coinbase en un solo `VARINT`, el importe reescalado en base 10, y el script en 21 o 33 bytes
> reconociendo P2PKH, P2SH y P2PK (`src/compressor.h`, v27.0). Aquí no se copia por dos motivos. El
> de fondo: su compresión de script **no aplica** — ZEROX tiene un enum `Lock` cerrado, no scripts,
> así que habría que diseñar un esquema nuevo, y un esquema nuevo es una segunda forma de escribir
> los mismos valores. El práctico: empaquetar `altura·2 + coinbase` ahorra **1 byte de 82**, y ese
> 1,2 % no compra el riesgo de que alguien lo decodifique mal.
>
> Lo que cuesta la decisión, medido con la fórmula real de C-WGT-02: una salida `PubKey` pesa 41
> unidades, así que `ZONA_LIBRE` da un techo de **2 439 salidas por bloque**. El coste anual depende
> de la tasa y de la ocupación real; no se conserva una estimación de la cadencia anterior. Ese peor caso no se
> sostiene —una transacción 2-in/2-out tiene crecimiento neto **cero**— pero basta para fijar lo
> importante: **el UTXO set no cabe en RAM**, y por eso hace falta una caché delante del disco.

**C-STORE-06 · Estado finalizado y recuperación.** El almacén persistente distingue el estado
finalizado del solapamiento que todavía puede cambiar. Antes de finalizar debe existir una
condición de finalidad integrada y verificable; al arrancar se reconstruye el estado reciente
a partir de los datos persistidos.

La implementación de almacenamiento no prueba que el nodo ya aplique R-FIN-7. Su integración,
poda, undo y presupuesto de memoria están pendientes. Un límite temporal `F` no fija un número
determinista de bloques: no se dimensiona el solapamiento sustituyendo dos horas por 7 200 bloques.

**C-STORE-07 · Una operación lógica es UN SOLO `WriteBatch`.** Avanzar la punta toca la cabecera, el
índice de alturas, el UTXO set y la propia punta. Los cuatro **MUST** entrar en el mismo lote y
escribirse con una sola llamada. Repartirlos en dos escrituras, aunque cada una sea atómica, deja
una ventana en la que un componente va por delante de otro.

> **La garantía existe y está citada.** Wiki de RocksDB, Column-Families: *"Atomic writes across
> Column Families are supported"*, y el porqué: *"By sharing write-ahead logs we get awesome benefit
> of atomic writes."* Por eso todo vive en **una sola** base de datos con varias familias, y no en
> varias bases.
>
> **El riesgo no es el motor, es la frontera del lote.** La atomicidad es **por batch**, no por
> operación lógica: dos `db.write()` seguidos son dos átomos, no uno. TiKV documenta el mismo
> problema desde el otro lado — al tener `raftdb` y `kvdb` como bases separadas, `tikv#6540`
> describe tener que ordenar los `fsync` **a mano**.
>
> ⚠️ **Esta regla se escribe con un incumplimiento presente.** `fijar_punta` es hoy una escritura
> suelta, fuera del lote de `guardar_cabecera`. Es recuperable —C-STORE-01 pone la punta después del
> dato, así que lo que sobra se ignora— pero deja de serlo en cuanto el UTXO set entra en juego.

**C-STORE-08 · Ninguna estructura derivada MAY ir por delante del estado del que se deriva.**
Cualquier cosa reconstruible a partir de la cadena o del UTXO set —el índice de cabeceras en
memoria, índices por dirección, estadísticas, lo que sea— **MUST** actualizarse **después** de que
el estado del que depende esté escrito, nunca antes y nunca en un lote propio más frecuente.

Quedarse **por detrás** es recuperable: se reconstruye. Ir por delante, no — describe un estado que
no existe.

> **Aplica ya, no en el futuro.** La estructura derivada que existe hoy es el índice de cabeceras
> en memoria de `Cadena`, y el orden correcto es escribir el lote primero y tocar el índice solo si
> la escritura salió bien. Hacerlo al revés dejaría la memoria diciendo una altura y el disco otra.
>
> Es un fallo de **2025**, no histórico: `bitcoin#33208`. Cita del arreglo, `#33212`: *"The committed
> state of an index should never be ahead of the flushed chainstate. Otherwise, in the case of an
> unclean shutdown, the blocks necessary to revert from the prematurely committed state are not
> available."* El síntoma en producción era `best block of the index not found. Please rebuild the
> index.`

**C-STORE-09 · Ningún límite incidental del motor de almacenamiento MAY decidir si un bloque se
acepta.** Tamaños de lote, límites de escritura, comportamiento de compactación: nada de eso entra
en la validez. Todo límite que afecte a la aceptación **MUST** estar escrito como regla de consenso
en este documento.

> Es la lección del **único fork de red real** causado por la capa de almacenamiento. BIP-50, marzo
> de 2013: Bitcoin 0.8 pasó de BerkeleyDB a LevelDB, y el límite de ~10 000 locks de BDB —que nunca
> fue una regla, solo un detalle del motor— se había convertido en consenso de facto. El bloque
> 225430 lo superó: los nodos 0.7 lo rechazaron, los 0.8 lo aceptaron, y la red se partió.
>
> La corrupción de un almacén es molesta: el nodo se cae y resincroniza. Esto es lo otro.

**C-STORE-10 · El WAL MUST estar activo, y el modo de recuperación es `PointInTimeRecovery`.** No se
sincroniza a disco en cada bloque: perder los últimos bloques **enteros** tras un corte de corriente
es recuperable resincronizando, y un estado incoherente no lo es. El modo de recuperación se fija
**explícitamente** aunque coincida con el valor por omisión.

> **Proceso y máquina no son lo mismo**, y el FAQ de RocksDB los trata como dos preguntas
> separadas. Con el WAL activo, que muera el proceso **no pierde nada**: el `write()` ya entregó los
> bytes al sistema operativo. Solo un corte de corriente puede perder la cola de lotes no
> sincronizados — y siempre lotes **enteros**, nunca a medias.
>
> **`kAbsoluteConsistency` NO**, aunque el nombre suene a más seguro. `facebook/rocksdb#2871`,
> reproducido por PingCAP: convierte la cola truncada normal de un `kill -9` en una base de datos
> **que no abre**. Un nodo que no arranca es peor que un nodo que resincroniza.
>
> **`atomic_flush` tampoco hace falta.** Comentario textual de `options.h`: *"it is not necessary to
> set atomic_flush to true if WAL is always enabled… This option is useful when there are column
> families with writes NOT protected by WAL."* No hay ninguna así.
>
> **Y se fija explícito porque el valor por omisión ya cambió una vez**, en RocksDB 6.6. Depender de
> un default es depender de que nadie lo mueva.
>
> Geth relajó esto por rendimiento y reintrodujo en 2025 un fallo de 2019. Conclusión del propio
> mantenedor: *"Probably sync mode is a safer choice anyway."*

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

### 16.1 · Sincronización de cabeceras, pruebas y DAG

**C-NET-03 · Validar antes de adoptar.** La sincronización comprueba codificación, compromisos,
ancestros, sello, solución y contexto de rango/PoT antes de declarar válido un bloque.
Los datos auxiliares necesarios para validar pueden solicitarse por fases acotadas; una
cabecera pendiente de justificación no se cuenta como trabajo verificado.

**C-NET-04 · Recursos acotados antes de validar.** Los candidatos incompletos se mantienen bajo
presupuestos de memoria, peticiones y coste de prueba. No se materializa un índice sin límites
por recibir cabeceras aparentemente válidas. El umbral anti-DoS basado en `blue_work`, su ancla
y el coste de verificar PoT requieren calibración; no se hereda un umbral de hashes ni 144 bloques.

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
construye sobre un estado cuya cabecera y pruebas de consenso estén verificadas. **MAY** emitirlo antes de validar que cada
transacción gasta UTXO existentes.

> Literal de BIP 152, y es la única de sus reglas que es **independiente del transporte**: habla del
> orden causal *interno* del nodo, no del canal. Ver `research/bip152.md` §7-§8.

**C-NET-07 · Derivación del ID corto.** Sobre `txid`:

```
h  = SHA3-256( cabecera_canónica ‖ nonce_transporte(8 B LE) )       ← divergencia deliberada, ver abajo
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
> collisions occur"*. Sin él, un productor podría fabricar transacciones que colisionen con las del
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
> un pago por bueno. Solo se cuenta progreso después de verificar contexto, pruebas y aplicación;
> recibir cabeceras por sí solo no demuestra progreso de consenso.

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

> **Un `PeerId` es gratis.** `Keypair::generate_ed25519()` es instantáneo: sin recurso escaso, sin registro, sin
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

**C-NET-22 · Validación contextual.** Antes de adoptar candidatos se comprueban sus ancestros,
rango esperado, rama de consenso, solución y reloj PoT sobre la historia candidata.
Faltar datos no demuestra mala fe; tampoco un rechazo temporal por el reloj local.

**C-NET-22a · No confiar en la posición declarada.** Altura, orden y ancestros se derivan del DAG
validado. El índice de llegada en un lote no define una altura de consenso. La representación y
el recorrido contextual del DAG están pendientes de integración; el validador lineal no acredita
esta propiedad.

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

> **Alcance del compromiso:** C-NET-23 vincula los datos de efecto, no todos los testigos.
> C-TX-01 excluye las firmas del txid y la cabecera actual no compromete el `auth_digest`.
> Una entrega con autorización incorrecta puede compartir cabecera/Merkle con otra correcta:
> rechazar esa entrega no demuestra por sí solo que la cabecera sea inválida. El formato DAG
> necesita resolver el compromiso de autorizaciones y el almacén distinguir datos recibidos
> de evidencia validada. Se estudia en
> [IDV-v0.1](veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md), sin activar una
> extensión de cabecera ni cambiar el txid en esta etapa.

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

### 16.4 · Propagación de bloques — transporte

**R-NET-01 · Relé compacto.** El relé compacto anuncia cabecera e identificadores cortos, negocia
el soporte por conexión y permite recuperar transacciones faltantes o el bloque completo.
No modifica las reglas que hacen válido al bloque.

**R-NET-02 · Sal por bloque.** Los identificadores cortos usan una clave derivada de la cabecera
y la sal de transporte (C-NET-07). Esa sal no es trabajo de consenso.

La latencia depende también de saltos de red, recuperación de datos y validación de PoT.
Se medirá con el formato DAG y las pruebas reales; no se trasladan estimaciones de huérfanos de
una cadena de bloques cada dos minutos.

---

## 17 · Pendientes activos del consenso destino

Esta lista es local y no depende del estado de un vault externo. La limpieza documental no
congela parámetros ni convierte prototipos en implementaciones.

| Área | Trabajo pendiente |
|---|---|
| Cabecera y wire | Integrar en la ruta activa del nodo el formato ya fijado en §6.1–§6.2: layout (C-HDR-01), prefirma (C-HDR-03), justificación PoT (C-HDR-07) y codec único (C-HDR-09). El texto normativo no deja nada pendiente aquí. |
| Prueba de espacio/tiempo | Verificación conjunta de solución, KZG, sello, reto secuencial, autoría y flujos. |
| Rango | R-FIN-13′ completo: arranque, ventana, redondeos, fusiones tardías, ramas candidatas. |
| DAG | Conflictos de transacciones sobre el orden ya definido (C-ORD-03) y su enlace con el estado UTXO (§2.6). Y tres reglas que esta especificación no tiene: `pick_virtual_parents` —qué puntas toma como padres un bloque que se produce, que es política de producción y no la verificación de C-GD-03—, el *merge depth bound* y el *pruning*. GHOSTDAG, U2/U3″, peso, cadena seleccionada y orden sí quedan especificados en §11. |
| Alturas y calendario | Activaciones, expiración de tx/sectores, timelocks, coinbase y archivado derivados del orden DAG. |
| Finalidad | Integración R-FIN-7, elección conjunta de I/F/L/ρ_max, particiones y recuperación. |
| Red | Medir Δ y coste de pruebas; calibrar sincronización, scoring, recursos y propagación. |
| Génesis | Parámetros y hashes PoST/DAG distintos por red; bootstrap explícito. |
| Pagos | Recalibrar §13 con el mismo modelo y criterio de aceptación en todas las alternativas. |
| Blindado | Convertir investigación Orchard de §9 en reglas, compromisos y validación integrados. |
| Tarifas/capacidad | Revisar coste adversarial, suelo de tarifa y peso blindado conservando constantes adoptadas. |

## 18 · Trazabilidad

Los documentos de investigación conservan evidencia y correcciones; no toda cifra histórica es
un parámetro activo.

| Área | Referencias locales |
|---|---|
| PoST/DAG | `research/dag-poas-ancla-de-orden.md`; enmiendas R-FIN-8′, R-FIN-13′ y R-FIN-14; rondas 9–11. |
| Reglas de red y pérdida honesta | `research/scripts/d9-ronda11a/informe.md`. |
| Confirmación | `research/scripts/d9-ronda10c/informe.md`, `research/scripts/d16-gate/`; límites de interpretación en §13. |
| Hash, codificación y firmas | `research/sha3-fips202.md`, `research/sha3-referencias.md`, `research/zip244.md`. |
| Blindado | `research/orchard-bundle.md`, `research/orchard-math-verification.md`. |
| Peso y tarifa | `research/dynamic-blocksize.md`, `research/dynamic-fee.md`. |
| Reproducibilidad | `veritas/LINEO.md`; los cálculos nuevos viven en Veritas. |



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
