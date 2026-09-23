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
| `C-POT` | Proof-of-Time como primitiva y contrato del verificador |
| `C-FLU` | El flujo del PoT: ancla, época, identificador y partición |
| `C-FIN` | Finalidad: profundidad máxima de reorganización |

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
| `ZZKFlowId_______` | §7.1.4 identificador de flujo del PoT (`C-FLU-10`) |
| `ZZKFlowGenesis__` | §7.1.3 flujo del génesis (`C-FLU-06`) |

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

**C-HDR-05** · En el diseño DAG A″, la cota de slot es **no estricta** y alcanza a **TODOS los
padres**, no solo al seleccionado: para todo bloque `B` y **todo** padre `p` de `B`,
`slot(p) ≤ slot(B)`. En particular `slot(sp(B)) ≤ slot(B)` (R-FIN-1a). La igualdad no autoriza
ciclos. El génesis tiene `slot = 0`.

Es la misma cota que `C-FLU-02`, y es materia de **validez**: sin ella el corte por slot de
`C-FLU-03` no es cerrado por ancestros y GHOSTDAG no está definido sobre él. Por eso `C-FLU-02`
entra también en la enumeración de `C-GD-10`.

> **Decidido por Katana el 2026-09-20 (D-F6 = A).** Hasta entonces el SPEC solo exigía la cota del
> padre seleccionado y **no determinaba** el slot de los demás padres. **El coste para el productor
> honesto está `estimado ≈ 0` y NO medido:** `TAREAS.md` §2.9.
>
> **Estado del código (actualizado el 2026-09-22).** La comprobación **sí está implementada en los
> componentes DAG**: `ContextoDag::slot_de_padre` obtiene el slot del contexto validado —falla de
> forma explícita si falta el padre o su slot, y nunca lo sustituye por cero ni lo lee del
> candidato—, `comprobar_padres_contextual` comprueba `slot(p) ≤ slot(B)` para el seleccionado y
> para cada padre adicional, y la inserción de `AlmacenGhostdag` aplica la misma cota a todos los
> padres —`Referencia` y `Kernel`— antes de modificar índices, padres, slots, colores o
> acumuladores. Eso
> **no** significa que la regla esté integrada: la ruta activa de `zx-node` sigue con la cabecera
> lineal y la selección de `fork_choice.rs`, así que nadie la ejecuta en producción y C-HDR-05
> permanece en `ci/reglas-sin-cablear.txt`. La regla **normativa** de arriba no cambia, y el número
> de portadores PoT sigue siendo `slot(B) − slot(sp(B))`, una regla distinta.

**C-HDR-06** · `rango_solucion` viaja en la cabecera y **MUST** ser exactamente el rango
esperado contextual:

```text
rango_esperado(B) = controlador(past(B), flujo(B, slot(B)))
B.rango_solucion == rango_esperado(B)
```

`flujo(B, s)` es el identificador de flujo de `C-FLU-10`, que **MUST** derivarse del pasado y
**MUST NOT** declararse (`C-FLU-11`). Como `C-FLU-10` es función exclusiva de `past(B)`, la
exigencia de esta regla queda satisfecha **por composición, sin añadir ninguna dependencia nueva**.

El rango esperado **MUST** aportarlo el contexto del pasado DAG validado y del flujo; debe ser
función **exclusiva** de ese pasado. **MUST NOT** depender del orden de llegada, la punta local, el
reloj local, `timestamp`, `height` declarado ni del propio `rango_solucion` que declara `B`. Es
**redundancia comprobada** para clientes ligeros, nunca fuente de verdad.

Ninguna implementación **MUST** ofrecer una vía que acepte el `rango_solucion` declarado por el
propio candidato como si fuese el esperado: la circularidad **MUST** ser imposible, no solo
desaconsejada. El algoritmo del controlador —ventana, bootstrap, redondeos y fusiones fuera de
ventana— sigue en `TAREAS.md` §2.3; no se define aquí.

El `rango_solucion` que ha superado esta comprobación es **el único `SR`** con el que `C-GD-01`
calcula `w(B)` y `C-GD-08` acumula `blue_work`. Un segundo `SR` con semántica distinta **MUST
NOT** existir: ni una re-derivación, ni otro redondeo, ni un `clamp` o una caché con semántica
propia, ni el valor declarado por el candidato.

> *Nota ilustrativa (no normativa).* La implementación Rust de referencia expone un contexto
> (`zx-consensus::ContextoRangoDag`) que recibe una vista del candidato **sin** acceso a
> `rango_solucion`; leerlo por esa vista no compila. Eso **solo** bloquea el acceso directo: un
> contexto que conserve la cabecera —o el valor por otra vía— puede devolver el declarado como
> «esperado», así que la vista **no** cumple por sí sola la exigencia de arriba. La única forma de
> cumplirla es que el contexto derive el esperado del pasado y del flujo, y ese controlador no
> existe todavía (`TAREAS.md` §2.3). La entrada Rust asociada (`AlmacenGhostdag::admitir`) es una
> puerta **parcial** de validación del `SR`: no es una admisión PoST de producción.

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

**Qué ancla la justificación, decidido por Katana el 2026-09-19 (D-2 = A).** El `pot_output` de la
cabecera es la salida **futura**, `salida(f, slot(B) + D)` (`C-POT-05`). Los `d` portadores cubren
el rango `(slot(sp(B)) + D, slot(B) + D]`, y el **último checkpoint del último portador MUST ser
igual a `pot_output(B)`**. La semilla del primer slot del rango la aporta el **contexto** desde el
pasado validado, **nunca el candidato** (`C-POT-06`). El orden interno de la verificación es el de
`C-POT-08`.

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

No basta comprobar un hash de cabecera: hay que verificar solución de espacio, testigos KZG,
identidad de billete, reto, distancia de solución, sello y justificación PoT.

Las subsecciones §7.1.1 a §7.1.7 fijan la parte **PoT y flujo** de esa verificación: el PoT como
primitiva (`C-POT-01`…`C-POT-05`), el contrato del verificador (`C-POT-06`…`C-POT-08`), y el
**flujo** — unidades, ancla, época, identificador, entropía, validez y partición
(`C-FLU-01`…`C-FLU-18`, `C-FLU-20`…`C-FLU-22`). La regla de finalidad de la que cuelgan es
`C-FIN-01` (§12); el presupuesto de verificación de flujo ajeno es `C-NET-33` (§16.6); la señal de
flujo minoritario, que **no es regla de consenso**, es `C-FLU-17` (§14.3).

> **Procedencia.** `C-POT-01`…`C-POT-08` salen de
> `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md`, validada el 2026-09-20; las reglas de
> flujo, de `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md`, validada el mismo día. **Las
> demostraciones y las cifras de simulación se quedan allí y no se repiten aquí.** Los
> instrumentos que las sostienen son `veritas/consenso/ancla-inyeccion-v2/` (ANCLA-v0.2) y
> `veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1), con el alcance declarado en sus
> `PROCEDENCIA.md`. **Ninguno de sus números entra aquí como constante.**

**Sigue pendiente**, y no lo cierran estas subsecciones: la **validación conjunta** de solución de
espacio, testigos KZG, distancia de solución y sello contra el reto derivado (el paso 5 de
`C-POT-08`), el **retardo de autoría** `D` como valor, y los puntos de control. No se introduce una
prueba de sustitución.

#### 7.1.1 · El PoT como primitiva

Un **flujo** `f` es un identificador opaco de 32 bytes (`C-FLU-10`). `semilla(f, 0)` la aporta el
contexto (`C-FLU-06`). `N(s)` es el trabajo secuencial del slot `s` (§7.3) y `D` el retardo de
autoría; los dos van como **símbolos**.

**C-POT-01** · **Encadenado de semilla slot a slot.**

```text
semilla(f, s) = salida(f, s−1)                                  (caso general)
semilla(f, s) = blake3(entropía(f, s) ‖ salida(f, s−1))[0..16)  (si el contexto declara inyección en s)
```

La entropía y el slot de activación son **ENTRADAS que aporta el contexto**, nunca el candidato
(`C-FLU-12`, `C-FLU-07`). **MUST** haber **a lo sumo una inyección por slot**; si el contexto
declarara más de una, el estado es `Pendiente` por error de contexto (`C-POT-06`), **nunca** una
decisión local. El bloque génesis no lleva justificación (`pot_bundle_count = 0`, C-HDR-07); la
salida de su slot se evalúa desde `semilla(f_0, 0)` y su reto se deriva como el de cualquier slot.

> El orden de la concatenación —**la entropía primero**, truncado a 16 bytes— y el aplicarla
> exactamente en el slot de inyección son los de Autonomys, verificados en fuente en
> `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:38-44`. `blake3` se conserva byte a byte
> por decisión de Katana del 2026-09-19 (**D-1 = A**): es lo que mantiene vivos los 32 vectores
> diferenciales de `prototipos/pot-estable` como validación externa.

**C-POT-02** · **Salida, checkpoints y verificación de un slot.**

```text
salida(f, s) = AES128_chain^{N(s)}(semilla(f, s))
```

evaluada en **8 tramos uniformes**: un `PotCheckpoints` de `8 × 16 = 128 B`, siendo la salida el
**último** de los ocho. La clave AES del tramo es `blake3(semilla)[0..16)`. `N(s)` **MUST** ser
múltiplo de 16; en otro caso la primitiva rechaza (`C-POT-04`).

La verificación de un slot **MUST** ser una función **determinista** de la terna
`(semilla, N, PotCheckpoints)`: misma terna, mismo resultado, en cualquier nodo y en cualquier
orden de llegada. Es la propiedad en la que se apoya `C-POT-07`.

> Vectores de forma V1–V5 en `veritas/consenso/pot-primitiva-v1/vectores/`, reproducidos 4/4. **No
> sustituyen** los 32 vectores diferenciales de `prototipos/pot-estable`, que son la validación
> externa del AES.

**C-POT-03** · **Aleatoriedad y reto por slot, sin atajos.**

```text
aleatoriedad(f, s) = blake3(salida(f, s))
reto(f, s)         = blake3(aleatoriedad(f, s) ‖ LE64(s))
```

Ningún reto de un slot **MUST** derivarse de una función que permita **saltarse slots**. En
particular **MUST NOT** existir `reto(f, s) = H(flujo(f) ‖ s)` ni ninguna PRF de `s` a partir de un
valor fijo de época: el reto de `s` solo es derivable **después** de evaluar la cadena secuencial
hasta `s`.

> Es lo único que impide evaluar de antemano la época entera de un candidato a ancla. Sin esta
> prohibición, el adelanto de `L_slots` con que se conoce la entropía (`C-FLU-07`) dejaría de
> costar tiempo secuencial.

**C-POT-04** · **Dominio de `N(s)` y proyección `u64 → NonZeroU32`.**

El contexto expresa `N(s)` en `u64`. El **verificador MUST** proyectarlo con comprobaciones y
**MUST NOT** hacer panic ni envolver en silencio. Si `N(s) == 0`, `N(s) > u32::MAX` o
`N(s) % 16 ≠ 0`, el estado es **`Pendiente` con diagnóstico de contexto, nunca `Inválido`**: el
fallo está en el pasado validado del nodo o en su implementación, no en el candidato.

`N(s)` es función del pasado validado y lo aporta el contexto; el candidato **MUST NOT** poder
declararlo. Su valor inicial, sus límites y **quién autoriza** un cambio siguen
`<<PENDIENTE: §7.3>>`; su calendario lo fija `C-FLU-16`.

**C-POT-05** · **Qué es el `pot_output` de la cabecera y qué cubre la justificación.**

```text
pot_output(B) = salida(f, slot(B) + D)      la salida «future», anclada en la cabecera
```

**Decidido por Katana el 2026-09-19 (D-2 = A):** de las dos salidas que Autonomys lleva en su
pre-digest, el campo único de 16 B de ZEROX (`[88,104)`, C-HDR-01) es la **futura**.

La justificación de `B` lleva `d = slot(B) − slot(sp(B))` portadores (C-HDR-07). El portador `i`
cubre el slot `slot(sp(B)) + D + i`, y el **último checkpoint del último portador MUST ser igual a
`pot_output(B)`**. Con esto `pot_bundle_count == slot(B) − slot(sp(B))` es exactamente el número
de slots del rango `(slot(sp(B)) + D, slot(B) + D]`. La semilla del primer slot del rango la deriva
el **contexto** del pasado validado —con D-2 = A es la salida del slot `slot(sp(B)) + D`, ya
anclada en un bloque anterior—, **nunca el candidato** (`C-POT-06`).

> **El coste de la opción A, dicho en voz alta y con su corrección.** El reto del slot `s`
> (`C-POT-03`) usa la salida del slot `s`, que **no** está anclada en la cabecera de `B`. En el
> camino normal la aporta la caché por slot (`C-NET-31`). En el camino **bajo demanda**
> (`C-NET-32`) hay que obtenerla del pasado validado: **como los padres se validan antes que el
> hijo, la salida del slot `s` sale siempre de ese pasado** —de la propia justificación de `B` si
> `d > D`, o de la de un ancestro—. La redacción de la propuesta decía que «la justificación de
> `B` no basta»; **es demasiado pesimista y queda corregida aquí**, según
> `veritas/consenso/pot-primitiva-v1/PROCEDENCIA.md`.

#### 7.1.2 · El contrato del verificador de PoT

**C-POT-06** · **Entradas, salida de tres estados y prohibición de circularidad.**

**Del candidato** —lo único que viaja en el wire— la cabecera DAG (con `slot` y `pot_output`) y la
justificación `PotCheckpoints` (C-HDR-07). **Del contexto**, derivado exclusivamente del pasado DAG
validado: el identificador de flujo `f`, la semilla del primer slot del rango, las inyecciones y
`N(s)` de cada slot del rango, el retardo `D`, y la caché del propio nodo (`C-POT-07`).

La salida **MUST** tener **tres** estados, no dos:

```text
PotValido        — cadena completa verificada y anclada
PotInvalido(r)   — defecto del candidato, verificable y final
PotPendiente(r)  — sin prueba de invalidez, pero tampoco de validez
```

`Inválido` **MUST** reservarse a: descuadre o desborde de portadores (C-HDR-05/C-HDR-07);
verificación AES fallida para alguna terna con la semilla y el `N(s)` del contexto; último
checkpoint ≠ `pot_output` (`C-POT-05`); discrepancia con la caché **bajo la misma clave**
(`C-POT-07`). `Pendiente` cubre: `N(s)` fuera del dominio de `C-POT-04`; slot por delante del reloj
PoT del nodo (C-NET-32.2); **presupuesto agotado** (`C-NET-33`); y fallo interno del contexto.
**Nada `Pendiente` pasa a `Válido` por defecto:** la única transición es una verificación posterior
**exitosa** con las mismas entradas de contexto.

**Prohibición de circularidad.** El verificador **MUST NOT** aceptar del propio candidato lo que
debe venir del pasado validado: el flujo, la semilla del rango, las inyecciones y `N(s)` **MUST**
aportarlos el contexto. El candidato solo aporta los checkpoints —evidencia reemplazable— y el
`pot_output` anclado —redundancia comprobada, **nunca fuente de verdad**—. Ninguna implementación
**MUST** ofrecer una vía que acepte el valor declarado por el candidato como si fuese el esperado:
**la circularidad MUST ser imposible, no desaconsejada**. Es el mismo principio de C-HDR-06.

El identificador de flujo es **opaco** para este verificador: se usa para indexar el contexto y la
caché, y **MUST NOT** interpretarse, derivarse de él ni validarse (`C-FLU-11`).

**C-POT-07** · **La caché se indexa por contexto, no por slot; y validez ≠ política de recursos.**

```text
clave_caché = (f, s, semilla(f, s), N(s))     los cuatro del CONTEXTO, no del candidato
valor       = salida(f, s)
```

La caché **MUST** indexarse por la clave contextual completa. Una entrada cacheada pertenece a un
contexto: **discrepar con una entrada de OTRA clave no prueba nada** —son cadenas de PoT distintas,
ambas legítimas—. Con la **misma** clave el PoT es determinista (`C-POT-02`), así que discrepancia
⟹ `Inválido`, y se decide comparando 128 B, **sin gastar AES**.

Agotar un presupuesto de CPU (`C-NET-33`) produce **`Pendiente`, nunca `Inválido`**: un nodo sin
recursos **MUST NOT** declarar falsa una prueba que no ha verificado. Lo mismo para la retención
por reloj (C-NET-32.2).

> **Por qué la clave y no el slot.** Con más de un flujo candidato, `salida(f₁,s) ≠ salida(f₂,s)`, y
> una caché por slot a secas haría depender la **validez** de qué llegó primero — contra el
> principio de que la validez es función del pasado del bloque y de nada más. **Con un único flujo
> la corrección es inocua**, y está demostrado en
> `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:259-275`: la clave pasa a ser función de `s`
> y el comportamiento observable es idéntico al del texto anterior.

**C-POT-08** · **Orden de validación: estructural y barato antes que AES; cada paso con su estado.**

| Paso | Comprobación | Estado si falla |
|---|---|---|
| 1 | **Estructural, sin AES.** Decode acotado (C-WIRE-04/C-WIRE-05); `slot(B) ≥ slot(p)` para **todo** padre (C-HDR-05); `pot_bundle_count == slot(B) − slot(sp(B)) ≤ 150` sin underflow (C-HDR-07) | `Inválido` |
| 1b | **Flujo (`C-FLU-14`), sin AES.** Derivar `flujo(B, ·)` del pasado validado y comprobarlo contra el de cada `X ∈ past(B)` | `Inválido` si discrepa; `Pendiente` si falta pasado |
| 2 | Cabecera y sello (C-HDR-03/C-HDR-04) | `Inválido` |
| 3 | **Caché por clave** (`C-POT-07`): comparar la salida anclada con la entrada de la clave del contexto | `Inválido` / `Pendiente` |
| 4 | **AES secuencial del rango**: por portador, verificar; encadenar semilla; último checkpoint == `pot_output` | `Inválido` si falla; `Pendiente` si se agota el presupuesto |
| 5 | Solo con `Válido`: derivar `reto` del slot (`C-POT-03`) y verificar la solución PoAS contra él | según §7.1 |

El paso 3 es lo que garantiza que **el camino normal no paga AES por bloque**: el coste por salto
queda acotado por construcción, que es el criterio de C-NET-06. El paso 4 es el respaldo bajo
demanda (C-NET-32), con el presupuesto de `C-NET-33`. Un `Pendiente` en el paso 4 **MUST NOT**
invalidar el bloque: el nodo retiene y completa cuando pueda.

> **El paso 1b va donde va, y no más tarde, por dos razones.** La clave de caché del paso 3
> **empieza por `f`**: sin el flujo resuelto no hay clave que consultar. Y `C-POT-06` exige que el
> flujo lo aporte el contexto: `C-FLU-10` y `C-FLU-11` son quien cumple esa exigencia.
#### 7.1.3 · El flujo: unidades, el ancla y la vista de época

**C-FLU-01** · **Todo lo del flujo se mide en índices de slot de PoT, y `L` va atada a `F`.**

```text
T_j      = j · I_slots                  umbral de época j (índice de slot), j ≥ 1
I_j      = ancla de la época j          (C-FLU-04)
t_j      = slot(I_j) + L_slots          instante de activación (índice de slot)
profundidad(t, P) = t − slot(P)         en slots, con P el último ancestro común

L_slots := máx( F_slots , L_suelo_slots , S_max_slots + 1 )
```

`L_slots` es una **definición**, no un parámetro libre: **MUST** derivarse y **MUST NOT**
declararse aparte. `F_slots := ⌈F / τ_nom⌉`. `F_slots`, `L_suelo_slots` e `I_slots` son
**símbolos**; esta regla no les da valor.

Una comparación de consenso **MUST NOT** depender de `τ_nom` en tiempo de ejecución ni de ningún
reloj físico. **La profundidad de una reorganización MUST medirse como
`slot(punta) − slot(último ancestro común)`, en índices de slot; MUST NOT medirse en bloques**: a
`λ = 1 bloque/s` y `τ_nom = 1 s/slot` coinciden nominalmente, pero C-GD-04 admite saltos de hasta
`S_max_slots` en la cadena, así que las dos cuentas se separan y **solo el slot es infalsificable**.

> **Los tres términos del máximo, y por qué hacen falta los tres.** El primero es la atadura que
> Katana decidió (perfil **1a**): si `F` baja en producción, `L` baja con ella, como identidad y no
> como nota de operación. El segundo es el **suelo**, y existe porque el primero no basta: `L`
> responde a una magnitud distinta —la cola de desacuerdo honesto frente a `Δ`—, que no baja cuando
> baja `F`. El tercero hace que `C-FLU-08` se cumpla por construcción para cualquier `F`.
>
> **`L_suelo_slots` MUST fijarse** a partir de (a) la cola medida de desacuerdo de cadena
> seleccionada a una `ε` elegida explícitamente y (b) **una cota de `Δ` medida en red real**.
> Mientras no exista (b), cualquier valor es provisional y **MUST** decirlo. La referencia de orden
> de magnitud —y **solo** eso— está en `veritas/consenso/ancla-inyeccion-v2/`, con `Δ` **simulada**
> (DMS-v0.1), no medida. `<<PENDIENTE: el valor de L_suelo_slots>>`.
>
> ⚠️ §7.3 advierte que `F` «no se iguala por defecto a `L`». Esa frase y `C-FLU-01` **no dicen lo
> mismo**: aquella prohíbe copiar `L` desde `F`; ésta **deriva `L` de `F` con un suelo**. Se parecen
> mucho y significan cosas distintas.

**C-FLU-02** · **Cierre de ancestros por slot.** Para todo bloque `B` y **todo** padre `p` de `B`:
`slot(p) ≤ slot(B)`, desigualdad **no estricta** (el empate está permitido, como en C-HDR-05).

> **Por qué es materia de validez y no política.** La vista de época de `C-FLU-03` es un corte por
> `slot`. Para que ese corte sea un sub-DAG bien formado tiene que ser **cerrado por ancestros**, y
> eso exige que ningún padre tenga un `slot` mayor que su hijo. Sin esta regla un bloque dentro del
> corte puede tener un padre fuera, el sub-DAG queda incompleto y GHOSTDAG **no está definido**
> sobre él. Por eso C-FLU-02 entra también en la enumeración cerrada de C-GD-10 y en C-HDR-05.
>
> **Decidido por Katana el 2026-09-20 (D-F6 = A).** Su coste para el productor honesto está
> **`estimado ≈ 0`, no medido**: `TAREAS.md` §2.9.

**C-FLU-03** · **Vista de época.** `V_j(B) := ( past(B) ∪ {B} ) ∩ { X : slot(X) < T_j + L_slots }`.

El corte **MUST** ser `T_j + L_slots` y **MUST NOT** ser `t_j`: `t_j` depende del ancla que se está
definiendo, y `T_j + L_slots` es función de `j` y de las constantes y de nada más.

> Consecuencia, dicha en voz alta: un bloque con `slot ∈ [T_j + L_slots, t_j)` **no participa** en
> elegir el ancla. Es deliberado.

**C-FLU-04** · **El ancla.** `I_j(B)` es el **primer** bloque de `Chn(V_j(B))` con `slot ≥ T_j`,
donde `Chn(V_j(B))` es la cadena seleccionada del bloque virtual sobre `V_j(B)`, calculada con
C-GD-01…C-GD-07 **restringidas a `V_j(B)`**.

> **`Chn(V_j(B))` NO es la cadena seleccionada del nodo.** Es lo que hace la definición bien
> fundada —la recursión termina, porque el flujo de todo `X ∈ V_j(B)` depende solo de épocas
> `j' < j`— y es también lo que deja la puerta abierta antes de `t_j`: `V_j(B)` **crece sin
> reorganización** en cuanto un bloque nuevo fusiona un bloque retenido del corte, y fusionar no es
> reorganizar. Desde `t_j` la deriva se detiene (`C-FLU-14`, `C-FLU-21`) y el productor la evita
> (`C-FLU-20`). **Antes de `t_j` no hay regla: hay carrera.**
>
> La existencia, la unicidad y la buena fundamentación están **demostradas** en
> `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:633-729`, con la condición suficiente escrita
> y el caso en que falla nombrado. Ese caso lo cierra `C-FLU-05`.

**C-FLU-05** · **Época sin ancla: se salta, y saltarla es definitivo.**

```text
Si Chn(V_j(B)) no cruza T_j, la época j NO produce inyección para B: el flujo de B
sigue siendo el de la última inyección realizada.
Un bloque B con slot(B) ≥ T_j + L_slots para el que I_j(B) no exista es INVÁLIDO.
```

Una época saltada **MUST NOT** recuperarse después. **No hay inyección retroactiva.**

> Sin la segunda frase la regla no es monótona: un descendiente con vista mayor tendría un flujo
> distinto del de `B` en slots donde `B` ya está fijado, `C-FLU-14` lo invalidaría, y la cadena se
> atascaría. Declarar inválido al bloque convierte un bloqueo global en un rechazo local. Un bloque
> honesto cuya cadena seleccionada coincide con la de su vista **nunca** cae aquí.

**C-FLU-06** · **El flujo del génesis y el origen de `semilla(f, 0)`.**

```text
f_0             := H_flujo( ETIQUETA_GENESIS ‖ block_hash(génesis) )        32 B
semilla(f_0, 0) := blake3( block_hash(génesis) ‖ entropía_externa )[0..16)  16 B
```

y `flujo(B, s) = f_0` para todo `s < t_1`. Las épocas se indexan desde `j = 1`: **no hay época 0 y
el génesis no es ancla de nada**. `entropía_externa` es **parámetro de lanzamiento** (§15.2), no
algo que derive el nodo: **MUST** ser pública, verificable e **imposible de elegir después** de
conocer el génesis. `<<PENDIENTE: el valor de entropía_externa por red>>`.

> **Las dos líneas usan hashes distintos a propósito, y el lector no debe «uniformarlas».**
> `semilla(f_0, 0)` conserva `blake3` porque alimenta la primitiva PoT, que D-1 = A dejó entera en
> `blake3`, y porque ahí sí hay oráculo: es la derivación de Autonomys. `f_0` usa `H_flujo`
> (`C-FLU-10`), que es `H_d` con etiqueta propia, porque el identificador de flujo **no tiene
> contraparte en Autonomys**: no hay oráculo que perder y gana la separación de dominio.

**C-FLU-07** · **Activación retardada.** `t_j := slot(I_j) + L_slots`. Para todo slot `s`,
`flujo(B, s)` lo fija la **última** inyección `j` con `t_j ≤ s`; si no hay ninguna, `f_0`. El borde
es **inclusivo**: en `s = t_j` la entropía **ya** está mezclada.

> **Una sola lotería, y está demostrado.** Para todo `s ∈ [slot(I_j), t_j)`, `flujo(B, s)` **no
> depende de `I_j`**: lo fija la inyección `j−1` o anterior. Dos nodos que discrepen del ancla
> producen y verifican **exactamente el mismo** `reto(f, s)` en todo ese intervalo. El intervalo es
> donde la red tiene `L_slots` para converger **sin que la discrepancia tenga consecuencias**; lo
> que ocurre en `t_j` es que la discrepancia, si sobrevive, se vuelve **irreversible**.

**C-FLU-08** · **`S_max_slots < L_slots` — condición de corrección.** Con ella el ancla cae dentro
de su propia vista de época, y en `t_j` está enterrada bajo al menos un bloque de cadena. Sin ella
**la definición del ancla no está bien puesta**. `C-FLU-01` la hace automática.

> **No es la condición que cierra el ataque del bloque retenido**, y decirlo al revés sería
> repetir el patrón de etiqueta ancha sobre resultado estrecho. Lo que cierra ese ataque después de
> `t_j` es `C-FIN-01` junto con `C-FLU-14` y `C-FLU-21`.

**C-FLU-09** · **`S_max_slots < I_slots`.** Entonces `t_j < t_{j+1}` **estrictamente**, los `t_j`
son distintos dos a dos y están ordenados como las épocas. Corolario: **a lo sumo una inyección por
slot**, que es lo que `C-POT-01` exige del contexto.

> §7.3 ya la conserva «como condición suficiente del perfil propuesto, no como necesidad universal
> demostrada», y esta regla **no la eleva** a necesidad: demuestra que es suficiente para lo que se
> usa. Con épocas saltadas (`C-FLU-05`) el número de inyecciones realizadas puede ser menor que el
> de umbrales cruzados.

#### 7.1.4 · El identificador de flujo y la entropía de la inyección

**C-FLU-10** · **Derivación del identificador de flujo.**

```text
flujo(B, s) := f_0                                                      si no hay inyección con t_j ≤ s
flujo(B, s) := H_flujo( flujo(B, t_j − 1) ‖ entropía_j(B) ‖ LE64(t_j) ) con j la última inyección con t_j ≤ s

H_flujo(m)  := H_d( ETIQUETA_FLUJO ‖ m ) = SHA3-256( ETIQUETA_FLUJO ‖ m )
```

El resultado son **32 bytes**. El primer argumento es `flujo(B, t_j − 1)` —«el valor vigente justo
antes de esta inyección»— y **MUST NOT** escribirse como `flujo(B, t_{j−1})`: con épocas saltadas
(`C-FLU-05`) `t_{j−1}` puede no existir. `t_j` entra como `LE64(t_j)`, codificación fija: una
concatenación de enteros sin longitud fija es ambigua por construcción.

> **Es acumulativo y es función exclusiva de `past(B)`, las dos cosas demostradas** en
> `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:932-941`. Lo primero convierte la comparación
> de flujos en una comparación de 32 bytes. Lo segundo es lo que satisface la exigencia de C-HDR-06
> de que nada dependa del orden de llegada, del reloj local ni de la punta local.
>
> **Decidido por Katana el 2026-09-20 (D-F2 = A):** `H_d` con etiqueta nueva, no `blake3`. Las dos
> etiquetas nuevas se añaden a C-HASH-06 (§4.5).

**C-FLU-11** · **El flujo NUNCA se declara.** La cabecera y el cuerpo **MUST NOT** contener el
identificador de flujo en ningún campo, ni ningún valor del que se derive. El flujo de un bloque lo
calcula el verificador a partir de `past(B)`, y **MUST NOT** existir vía alguna que acepte un valor
del candidato como si fuese el esperado: **la circularidad MUST ser imposible, no desaconsejada**.

`C-FLU-10` **es** la definición de `flujo(B, slot(B))` que C-HDR-06 usa sin definir. Como el flujo
es función exclusiva de `past(B)`, la exigencia de C-HDR-06 de que el rango esperado sea función
**exclusiva** de ese pasado queda satisfecha por composición, **sin añadir ninguna dependencia
nueva**.

**C-FLU-12** · **Entropía de la inyección.**

```text
entropía_j(B) := blake3( chunk(I_j(B)) ‖ pot_output(I_j(B)) )
```

y se entrega a `C-POT-01` como la entrada `entropía(f, t_j)`. Los dos ingredientes son campos de
**cabecera** de `I_j(B)`: `sol.chunk` en `[252,284)` y `pot_output` en `[88,104)` (C-HDR-01).

**Invariante de no-equivocación del inyector.** **Dos copias del mismo billete MUST producir la
misma entropía y el mismo `t_j`.** Cualquier cambio futuro que meta en la entropía un campo
**moldeable por el constructor del bloque** —el hash del bloque, el `timestamp`, el conjunto de
padres, la raíz de Merkle— **reabre el grinding de la entropía por contenido del bloque**, hoy
cerrado, y **MUST NOT** hacerse sin rehacer ese análisis.

> **Decidido por Katana el 2026-09-20 (D-F1 = A).** El motivo que más pesa no es criptográfico:
> es **no atar §7.1 a la identidad del billete (§7.2), que además puede cambiar** si algún día se
> adopta un registro de parcelas contra el sembrador.
>
> **El coste de A queda escrito:** dos billetes distintos con el mismo `chunk` en el mismo slot y
> flujo dan la misma entropía. La entropía no distingue **quién** ancló, solo **qué chunk** ganó.
> No se ha encontrado un ataque por esa vía, **y no encontrarlo no es cerrarlo**.
>
> **Aviso para quien valide:** con `pot_output` = salida **futura** (D-2 = A), la entropía se deriva
> de `salida(f, slot(I_j) + D)`. Ambos valores son función de `(f, slot)`, sin contenido del
> candidato.
#### 7.1.5 · Validez absoluta y pasado consistente de flujo

**C-FLU-13** · **Validez absoluta.** `B` es **válido** si y solo si: (1) su solución PoAS verifica
bajo `reto(flujo(B, slot(B)), slot(B))`; (2) su justificación de PoT cubre el rango exigido por
C-HDR-07 **bajo ese mismo flujo**; (3) todos los bloques de `past(B)` son válidos; (4) cumple
`C-FLU-14`.

La validez de `B` **MUST NOT** depender de la cadena seleccionada del observador, de su punta, de
su reloj ni del orden de llegada. Es función de `past(B)` y de nada más.

> **Ésta es la bifurcación de §2.1 de `TAREAS.md`, y su precio se paga aquí, explícito.** Si la
> validez del PoT fuese **relativa a la cadena seleccionada**, se abriría el **multistream**. La
> frontera `α = 1/(S+1)` de `veritas/seguridad/coste-rama-privada-v1/` pertenece al
> **contrafactual aditivo** de flujos independientes —identidad del modelo escalar, no umbral
> medido de una cadena válida— y `C-FLU-14` lo excluye; el **umbral protocolario global sigue
> inconcluso** (`P-ZRX/P-CRP/auditoria/INFORME.md`). Siendo **absoluta**, el multistream queda
> cerrado **por decisión del protocolo, no por medición** (un flujo fabricado por el atacante no
> es el flujo de ningún bloque honesto y sus bloques no se pueden referenciar, `C-FLU-14`) y lo
> que se abre es la **partición de flujo** (§7.1.6). **Lo que la contiene no es una regla: es
> `L_slots` frente a `Δ`**, con la probabilidad medida en simulación en
> `veritas/consenso/ancla-inyeccion-v2/` y la `Δ` **simulada, no medida en red**.

**C-FLU-14** · **Pasado consistente de flujo.**

```text
Para todo X ∈ past(B):   flujo(X, slot(X)) == flujo(B, slot(X))
```

Un bloque **MUST NOT** referenciar un bloque de otro flujo. La comprobación es **estructural** y va
**antes** de tocar ningún PoT (paso 1b de `C-POT-08`). Si el nodo no tiene todo `past(B)` el estado
es **`Pendiente` por contexto incompleto, nunca `Inválido`**.

> **No necesita AES, y está demostrado:** los ingredientes de `flujo(·)` son una constante, dos
> campos de cabecera por ancla, los `slot(I_j)` y el orden GHOSTDAG restringido a `V_j`. **Ninguno
> exige evaluar la cadena AES.** Lo que **sí** cuesta es recomputar cadena y flujo del sub-DAG
> ajeno, que es superficie de DoS: por eso el paso 1b va bajo el presupuesto de `C-NET-33`.

**C-FLU-20** · **Qué hace el productor con un bloque tardío que cambiaría un ancla ya activada.**
Al construir un bloque `B`, el productor **MUST** descartar de su cola de candidatos (C-GD-10) toda
punta cuya inclusión cambiaría `entropía_j` o `t_j` de **alguna época `j` ya activada en el pasado
de `B`** —es decir, con `t_j ≤ slot(X)` para algún `X ∈ past(B)`—. Un productor **MUST NOT** emitir
un bloque inválido por una elección de padres que él mismo controla.

Es **política de producción**, no verificación: un verificador no rechaza por el conjunto de
padres, rechaza por `C-FLU-14`, que es validez objetiva.

> **Consecuencia, y hay que decirla así: ese bloque queda INFUSIONABLE PARA SIEMPRE en ese flujo.**
> Como el pasado solo crece, ningún descendiente futuro podrá fusionarlo si hacerlo cambiaría `I_j`.
> **No hay caducidad ni ventana de rescate.** Normalmente paga el atacante, que es quien retiene;
> **el colateral honesto no está medido** (`TAREAS.md` §2.9).
>
> ⚠️ **Esta política MUST NOT extenderse al intervalo anterior a `t_j`.** Antes de `t_j` fusionar es
> legal, así que la política no se apoyaría en ninguna invalidez: sería un «lo primero que vi
> manda» y **haría el flujo dependiente del orden de llegada de los mensajes**, que es exactamente
> el defecto que la ronda 10a tuvo que retirar. **Solo actúa después de la activación.**

**C-FLU-21** · **La inyección ya activada se hereda, no se recalcula.** Si `past(B)` contiene algún
bloque `X` con `t_j ≤ slot(X)`, la inyección `j` de `B` —su `entropía_j` y su `t_j`— **MUST** ser la
de `X` y **MUST NOT** recalcularse a partir de `V_j(B)`. `I_j` solo se calcula con `C-FLU-04`
cuando ningún bloque del pasado la tiene activada.

> **No cambia qué bloques son válidos: la vuelve constructiva.** El verificador deja de recalcular
> `Chn(V_j(B))` por bloque y la hereda; el ancla se calcula **una vez por época y se transporta**.
> Se escribe aunque sea redundante porque, sin ella, dos implementaciones pueden calcular lo mismo
> por caminos distintos y discrepar en un borde que nadie ha enumerado.
>
> **Decidido por Katana el 2026-09-20 (D-F8 = C): la vista NO se congela.** Congelarla reabriría
> la circularidad del ancla —el ancla dependiendo de la cadena, la cadena de la validez, la validez
> del ancla— en una franja de anchura `≤ S_max_slots`, y compraba muy poco: adelantar la
> congelación 150 slots nominales sobre una carrera que dura `L_slots ≥ F_slots`. **Esto no arregla
> nada de la carrera anterior a `t_j`.**

#### 7.1.6 · Partición de flujo: estatuto, adopción y nodo sin cadena

> **Leer esto antes que las tres reglas.** **Ningún texto derivado de esta sección debe decir «las
> particiones de flujo se curan», ni tampoco «no tienen cura». Las dos son falsas: depende de cómo
> nació la partición.** `C-FLU-22` cura el nacimiento **espontáneo** —por latencia—, que es el
> improbable. **No cura** el nacimiento realista, un corte de red más largo que `L_slots`, donde la
> ventana es **vacía desde el propio `t_j`** y la partición es **permanente**. El diseño es, sobre
> todo, **prevención** —`L_slots` frente a `Δ`, con el suelo de `C-FLU-01`—; la recuperación es un
> añadido real pero acotado, **no una garantía de reconciliación**.

**C-FLU-15** · **Una partición de flujo tiene el estatuto de un fallo de finalidad.** Una partición
de flujo **se trata como** una violación de finalidad: es un fallo del modelo de seguridad, no un
estado que el protocolo gestione.

> **«Se trata como», no «es».** Escribirlo como equivalencia causal sería **falso**: existe una
> partición de flujo que nace **sin** violar ninguna regla de finalidad
> (`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:248-294`, refutación demostrada). Lo que sí
> es cierto y está demostrado: **si la partición nace, la finalidad es lo que impide curarla** fuera
> de la ventana de `C-FLU-22`.
>
> **Producir en un flujo no seleccionado no se puede prohibir criptográficamente**, y el motivo es
> más fuerte que una laguna: «cualquier mecanismo de exclusividad entre relojes en PoAS
> permisionless es derrotable por partición de identidad, porque el coste de producir espacio es
> lineal en bytes e independiente de cuántas identidades lo reclamen, y las identidades son gratis
> por diseño» (`research/dag-poas-balizas-auditoria.md:68-75`). Lo que el diseño **sí** hace es
> dejarlo **sin valor económico**, y no hace falta regla nueva: `C-FLU-14` impide referenciar esos
> bloques desde el flujo ganador, luego su coinbase nunca entra en la historia seleccionada.

**C-FLU-22** · **Adopción del flujo rival dentro de la ventana, con presupuesto.**

```text
Adoptar = seleccionar. Una rama de otro flujo es VÁLIDA en términos absolutos (C-FLU-13):
NO se puede FUSIONAR (C-FLU-14) pero SÍ se puede SELECCIONAR.

d(t) := slot(punta seleccionada actual) − slot(P),  con P el ÚLTIMO ANCESTRO COMÚN
        de la cadena actual y la rama candidata.
```

Un nodo **MUST** elegir entre ramas válidas por la selección ordinaria de GHOSTDAG (mayor
`blue_work`; desempates de C-GD-03), **sin excepción por flujo**, limitada por `C-FIN-01`: solo
mientras `d < F_slots`.

Orden y coste, que **MUST** respetarse:

1. La comprobación estructural del flujo va **siempre primero** (paso 1b de `C-POT-08`). **Sin AES.**
2. El PoT del flujo rival se verifica **solo si hace falta para adoptar**: solo si la rama rival va
   **por delante** en `blue_work` y `d < F_slots`. Si no, **no se verifica nada**: la punta se
   ignora (`C-FIN-01`).
3. Todo ello **bajo los dos presupuestos de `C-NET-33`**. Agotarlos da **`Pendiente`, nunca
   `Inválido`**.
4. **Sin validez comprobada no se adopta.** `Pendiente` **MUST NOT** contar como válido ni como
   inválido: el nodo se queda donde está y reintenta.

> **La congelación es simultánea.** El instante de cierre es `slot(P) + F_slots`, **función
> exclusiva de `P`**: no depende de cuándo cada nodo se enteró de la rama rival, ni de su reloj, ni
> del orden de llegada. Todos los nodos **con cadena** cruzan el umbral en el mismo índice de slot.
>
> **La anchura de la ventana depende de cómo nació la partición**, y esto es lo que hay que leer:
>
> | Nacimiento | `slot(P)` | Ventana |
> |---|---|---|
> | **Espontáneo** (latencia) | `t_j − 1` | **máxima**, `F_slots − 1` |
> | Corte de red que empezó en `s₀` | `s₀` | `[t_j, s₀ + F_slots)` |
> | **Corte de red más largo que `L`** | `≤ t_j − L_slots` | **VACÍA** |
>
> **Riesgo residual, con su alcance declarado.** Aun con congelación simultánea quedan dos rendijas
> medidas en `veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1): el **desfase de vista** en el
> instante de congelación, que va como `√(τ/F)` —**condicionado a que la partición haya nacido y a
> reparto simétrico**—, y **el nodo que sincroniza después**, que toma el líder del momento. El
> segundo **no lo cierra esta regla**: lo gobiernan `C-FLU-18` y `C-FLU-17`. `C-NET-33` añade una
> **tercera, no medida** y parcialmente bajo control del atacante.
>
> **R-FIN-5 cambia de motivo, y la frase exacta importa.** Deja de ser cierto a la letra que «un
> nodo honesto **jamás** verifica el PoT de un flujo ajeno». Lo cierto es: **nunca lo verifica para
> FUSIONAR** —`C-FLU-14` es estructural y no toca AES—; **solo lo verifica para ADOPTAR**, dentro
> de esta ventana y bajo presupuesto. La virtud que se conserva es la que importaba: **el camino
> normal nunca paga AES ajeno**.
>
> **Forzar ese gasto no es barato, y está demostrado** en
> `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1373-1425`: exige ganar una carrera de
> `blue_work` de longitud `L_slots`. La demostración **usa `L_slots ≥ F_slots`**, así que es un
> argumento a favor del perfil 1a, independiente de los demás. **La cola de esa carrera no está
> medida** (`TAREAS.md` §2.9).

**C-FLU-18** · **El nodo sin cadena previa aplica la selección ordinaria.** Un nodo sin cadena
previa selecciona la rama de **mayor `blue_work`** por las reglas C-GD vigentes, **sin excepción por
flujo**. `C-FIN-01` obliga **únicamente** a quien ya tiene una cadena seleccionada que reorganizar;
**no impone nada a quien no tiene ninguna**.

> **No es un mecanismo nuevo: es cerrar un hueco de redacción**, y sin escribirlo dos clientes
> pueden implementarlo distinto, que es la clase de fork latente que el Nivel 1 de `TAREAS.md`
> persigue.
>
> **Qué lo acota, y qué no.** En el arranque, C-CHK-01…C-CHK-07 fijan la rama canónica —pero son
> **uno solo** en la vida de la cadena y **caducan** en `ALTURA_CADUCIDAD`—. A largo alcance, lo
> acota la secuencialidad del PoT (`C-POT-03`). **Lo que NO acota:** después de `ALTURA_CADUCIDAD`
> y con una partición viva, un nodo nuevo va al flujo más pesado **del momento**, que puede ser el
> minoritario. **C-FLU-18 hace la conducta determinista y única; no la hace acertada.**

#### 7.1.7 · El calendario de `N(s)`

**C-FLU-16** · **`N(s)` cambia exactamente en `t_j`.** Cualquier cambio de `N(s)` **MUST**
aplicarse en el mismo slot `t_j` en que se aplica la entropía de la inyección `j`, y **en ningún
otro**. Entre dos activaciones, `N(s)` es constante.

> **Por qué es regla y no coincidencia.** `N(s)` entra en la clave de caché de `C-POT-07`. Si
> pudiera cambiar en un slot distinto de `t_j`, habría **dos** puntos de discontinuidad por época
> en vez de uno, y la clave tendría que rastrear un calendario propio. Con esta regla el calendario
> de `N` es **el mismo objeto** que el de las inyecciones, que `C-FLU-09` deja bien ordenado y con
> a lo sumo un cambio por slot.
>
> **Quién autoriza un cambio de `N(s)`, su valor inicial, sus límites y su anuncio siguen
> `<<PENDIENTE>>`** (§7.3). El `ensure_root` del actualizador de Autonomys **no se adopta** como
> autoridad de ZEROX. Esta regla fija **cuándo** se aplica, no **quién** lo decide.

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

`F = 2 h` sigue provisional, con obligación declarada de bajarla en producción; no es la espera de
Cortex. **`L` ha dejado de ser un parámetro libre:** desde el 2026-09-20 es una **definición**,
`L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)` (`C-FLU-01`), con el perfil **1a**
decidido por Katana. El candidato `L = 1 h` queda **superado**: no se elige `L`, se deriva.

**Cuidado con la frase heredada «no se iguala por defecto a `L`»:** prohibía copiar `L` desde `F`
sin más, y `C-FLU-01` hace lo contrario en el sentido contrario —**deriva `L` de `F` con un
suelo**—. Las dos frases se parecen mucho y significan cosas distintas.

`I_slots`, `ρ_max`, `L_suelo_slots`, la configuración final de `F` y la calibración frente a `Δ`
siguen abiertos. **`L_suelo_slots` no se puede fijar hoy**: su criterio exige una cota de `Δ`
**medida en red real**, que no existe (`TAREAS.md` §3.1).

`45 s` es el máximo observado de `W_dec` en las simulaciones citadas, no una cota
universal. `I ≥ ρ_max·W_dec` es una restricción contra evaluar una época durante la elección
del ancla; no demuestra finalidad a los 112,5 s. El retardo efectivo de red `Δ` necesita medición.
Los escenarios que usan distintas tasas, pérdidas de red o presupuestos adversarios no se combinan.

#### Contrato de unidades del perfil de estudio

Esta notación consolida magnitudes; no fija todavía su serialización ni completa el protocolo:

- `slot(B)`, `I_slots`, `L_slots`, `S_max_slots`, `F_slots`, `L_suelo_slots` y `D_aut_slots` son
  índices o cantidades enteras de slots PoT. Con τ nominal de 1 s/slot, la referencia S_max se
  representa por 150 slots; limita `slot(B)−slot(sp(B))`, no el tiempo de retención ni Δ de red.
  `F_slots := ⌈F / τ_nom⌉`, y **una comparación de consenso MUST NOT depender de `τ_nom` en tiempo
  de ejecución** (`C-FLU-01`). **La profundidad de una reorganización se mide en slots**,
  `slot(punta) − slot(último ancestro común)`, **nunca en bloques** (`C-FIN-01`).
- `L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)` es **definición, no parámetro**
  (`C-FLU-01`). `L_suelo_slots` es parámetro de consenso y va como **símbolo**:
  `<<PENDIENTE: el valor de L_suelo_slots; su criterio exige una cota de Δ medida en red real>>`.
- `T_j=j·I_slots` es el umbral del inyector; `t_j=slot(I_j)+L_slots` es el índice de inyección
  (`C-FLU-01`, `C-FLU-07`). R-FIN-9 remite a ese inyector, no al contador obsoleto `c·j`.
  **El origen, la existencia y la unicidad del ancla quedan cerrados** en `C-FLU-04`, `C-FLU-05` y
  `C-FLU-06`; **la disponibilidad después de poda NO**, y sigue abierta. I separa umbrales,
  no necesariamente los instantes realizados de inyección (`C-FLU-05`: una época puede saltarse, y
  saltarla es definitivo).
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
resultado. Estas reglas **sí tienen código** en `crates/zx-consensus/src/ghostdag.rs` (referencia y
kernel, oráculo y vectores), pero **ninguna ruta del nodo las ejecuta**: `zx-node` sigue con la
selección lineal de `fork_choice.rs`. Por eso están declaradas en `ci/reglas-sin-cablear.txt`, no
en `ci/reglas-sin-codigo.txt`.

**C-GD-01** · **Peso de un bloque.** `w(B) = ⌊2^128 / (SR(B)+1)⌋`, con `SR` de tipo `u64` y
división entera exacta. El cálculo **MUST** hacerse en enteros; usar coma flotante está
**prohibido**. `SR = 0` da `w = 2^128`, que no cabe en `u128`; `SR = 2^64−1` da el mínimo,
`w = 2^64`. Por tanto `w(B) ≥ 2^64 > 0` para todo bloque.

**De dónde sale el `SR` que pesa.** El `SR(B)` de esta fórmula **MUST** ser el mismo
`rango_solucion(B)` que `C-HDR-06` exige igual al rango esperado contextual. `w(B)` **MUST NOT**
calcularse ni entrar en `blue_work` (`C-GD-08`) antes de que ese rango haya superado la
comprobación contextual, y **MUST NOT** existir una segunda fuente de `SR` con semántica propia
—otra derivación, otro redondeo, un `clamp` o una caché distintos del valor validado—. Es una
precisión del acoplamiento ya implícito entre `C-HDR-06`, `C-GD-01` y `C-GD-08`; no añade una
regla de retarget, no cambia la fórmula del peso ni el orden de validación de §6.4. Procedencia:
P1/`C-RET-08` de `P-ZRX/P-RANGO/propuesta/PROPUESTA-SPEC.md`; es lo único que se toma de esa
propuesta, y las demás reglas `C-RET-01`…`C-RET-11` **no** se trasladan.

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
`k = 30`. Siguen vigentes la cota de slot de **todos** los padres, `slot(p) ≤ slot(B)` (C-HDR-05,
`C-FLU-02`), y `slot(B) − slot(sp(B)) ≤ S_max`.

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

**C-GD-10** · **Qué puntas toma como padres un bloque que se produce.** Al construir un bloque, el
productor **MUST** tomar como padres hasta `max_block_parents = 15` puntas del DAG (R-FIN-12),
elegidas recorriendo una **cola de candidatos barajada** al azar, y **MUST** incluir siempre la
punta virtual (C-GD-03) entre ellas. El resto del conjunto **MAY** variar entre nodos y entre
bloques: es la única regla de esta sección que **no** es determinista, y no lo es a propósito.

Además, el productor **MUST** descartar de la cola de candidatos:

1. toda punta cuya inclusión produciría un bloque que viola **C-GD-11**;
2. toda punta con `slot` mayor que el del bloque que produce (**C-FLU-02**);
3. toda punta cuya inclusión cambiaría `entropía_j` o `t_j` de alguna época ya activada en el
   pasado del bloque (**C-FLU-20**).

Un productor no puede emitir un bloque inválido por una elección de padres que él mismo controla.
**El punto 3 MUST NOT extenderse al intervalo anterior a `t_j`**: allí fusionar es legal y la
política se convertiría en un «lo primero que vi manda» que haría el flujo dependiente del orden de
llegada (`C-FLU-20`).

Esto es **política de producción**, no verificación: un verificador **MUST NOT** rechazar un bloque
por el conjunto de padres que eligió su autor mientras cumpla C-GD-04, C-GD-11, C-HDR-05,
`C-FLU-02` y `C-FLU-14`. C-GD-03 dice cómo se **elige el padre seleccionado entre unos padres
dados**; esta dice **de dónde salen esos padres**.

> **Sin el barajado se pierden bloques honestos para siempre, y está medido.** Con `k = 30` el tope
> es de 15 padres, y una red cargada llega a tener del orden de **548 puntas** simultáneas. Si todos
> los productores eligen las 15 «mejores» por el mismo criterio determinista, todos eligen **las
> mismas**: las puntas que ningún nodo escoge no entran en el DAG por ninguna vía, y **14-21 bloques
> honestos quedan fuera del DAG de forma permanente** (auditoría D9-d, §A3.1). El daño **no** venía
> del `mergeset_size_limit` —cero cortes por esa causa— sino del tope de padres.
>
> Es `pick_virtual_parents` de rusty-kaspa (`virtual_processor/processor.rs:1069-1089`), y la
> decisión de adoptarlo es de D9-d: **R-FIN-12 nombra el `shuffle`**. §7.3 ya lo recoge: se baraja
> la **cola de candidatos**, no se reparte una cuota aleatoria de los padres finales.
>
> 🔶 **Laguna declarada, sin cerrar.** El argumento del barajado es de *diversidad entre nodos*: con
> muchos productores honestos e independientes, el conjunto de puntas cubiertas es amplio. **Con un
> solo productor honesto el argumento no aplica** y la garantía se pierde. Está anotado como abierto
> en D9-d §6.4 y no se cierra aquí.
>
> **Aleatoriedad en un protocolo determinista, dicho en voz alta:** no rompe el consenso porque
> ningún verificador la reproduce. El determinismo que C-GD-09 exige es el de los **datos GHOSTDAG**
> —color, orden, `blue_work`—, que son función de `past(B)`. De dónde salió `past(B)` no entra en esa
> función.

**C-ORD-04** · **Conflictos de transacciones sobre el orden de aplicación.** Aplicando el orden de
C-ORD-03, una transacción que no valide contra `UTXO(sp(C)) ⊕ diff(mergeset hasta ella)` **MUST**
descartarse **en silencio**: **MUST NOT** invalidar ni al bloque que la contiene ni al bloque de
cadena que lo fusiona. Entre dos gastos en conflicto **gana el que aparece primero** en ese orden, y
el otro se descarta por esta misma regla. Las tarifas de un bloque suman **solo las transacciones
aceptadas**.

> Es R-FIN-8′(5), y el mecanismo es el de Kaspa (`utxo_validation.rs:311-313`). **La parte que hay
> que entender es por qué el descarte es silencioso.** Quien produce un bloque no sabe qué van a
> contener los bloques hermanos que se aplicarán antes que el suyo: exigirle que no colisione sería
> exigirle predecir el futuro, y convertiría un conflicto inevitable en una invalidación. El DAG
> ordena, y el orden decide; el bloque perdedor no hizo nada malo.
>
> **Dónde muerde la diferencia con Kaspa:** aquí solo entran al orden los azules y los `rojo_k`, y
> los `rojo_U3` se saltan (R-FIN-8′(3)/(4), C-ORD-03). Kaspa aplica las transacciones de **todos**
> los rojos (`utxo_validation.rs:122`), y portar eso bajo PoST daba inflación ×10 y espacio de bloque
> gratis. R-FIN-8 se aparta a propósito: **rojo = peso cero, estado cero, recompensa cero.**
>
> Que `fees` sume solo las aceptadas se sigue de lo anterior, pero se escribe porque es justo el tipo
> de detalle que una implementación resuelve «como salga»: cobrar la tarifa de una transacción
> descartada paga dos veces por un gasto que ocurrió una.

**C-GD-11** · **Límite de profundidad de fusión (*bounded merge depth*), con kosherización.** Un
bloque **MUST** rechazarse si algún bloque **rojo** de su mergeset queda **fuera del
`merge_depth_root`** y **no es ancestro de ningún azul kosherizante**. Un azul es kosherizante
cuando él mismo tiene el `merge_depth_root` en su pasado.

**Esta regla decide validez de la fusión, y nada más.** **MUST NOT** alterar quién cobra ni qué se
aplica al estado: un `rojo_k` admitido sigue tratándose por P1 y R-FIN-8′, y un `rojo_U3` sigue
siendo **inerte** (R-FIN-8′(3), C-ORD-03, C-ORD-04). Kosherizar **no** convierte un rojo en azul, no
le da peso y no le da recompensa; solo dice que el bloque que lo fusiona es válido.

**PENDIENTES declarados, que ninguna implementación puede fijar por su cuenta (§0.3):**

| `<<PENDIENTE>>` | Qué falta decidir |
|---|---|
| **La métrica** | si `merge_depth` se cuenta en slots, en `blue_score` o en posiciones de cadena seleccionada. Kaspa cuenta en `blue_score`; ZEROX tiene un reloj de slots que Kaspa no tiene, y no está decidido cuál manda |
| **El valor** | no se copia el de Kaspa ni se deriva de `F = 2 h`, que es **provisional** (MIGRACION §Parámetros). Una constante inventada aquí sería una regla de consenso fijada por intuición |
| **El bootstrap** | qué es el `merge_depth_root` mientras el DAG es más corto que la profundidad |
| **El borde de igualdad** | si la comparación es estricta o no en el bloque que cae exactamente en la profundidad |
| **Su relación con finalidad y poda** | en Kaspa, `merge_depth`, `finality_depth` y `pruning_depth` son la misma familia de constantes. En ZEROX la finalidad es R-FIN-7 y la poda está abierta (§17): la relación entre las tres **no** se hereda por analogía |

> **Qué acota, exactamente.** `mergeset_size_limit = 180` acota el **tamaño** de lo que se fusiona;
> `S_max` acota la distancia al **padre seleccionado** (C-GD-04). Ninguno acota la **profundidad**:
> un bloque viejo cuyo pasado ya está íntegro en `past(sp(B))` entra en el mergeset **sumando 1**, así
> que ni el límite de 180 ni `S_max` lo tocan. Ese es el hueco que esta regla cierra, y es la razón
> por la que Kaspa tiene `check_bounded_merge_depth` (`post_pow_validation.rs:79-101`,
> `block_depth.rs:109-119`) además de los otros dos límites.
>
> Sin ella, el coste de colorear no está acotado por nada salvo R-FIN-12, y un bloque puede fusionar
> un pasado arbitrariamente viejo — que es también por dónde entra la reorganización profunda que
> R-FIN-7 pretende impedir.
>
> **Por qué la constante se queda pendiente y no se pone un número «razonable».** Las tres
> profundidades de Kaspa están atadas a su finalidad, y la de ZEROX (`F = 2 h`) es **provisional en
> investigación**, no un parámetro adoptado. Derivar de ella daría una regla de consenso con
> apariencia de cerrada y un cimiento que se va a mover. Es exactamente el patrón que §0.3 prohíbe.
>
> **El productor no puede emitir un bloque que la viole:** C-GD-10 le obliga a descartar de su cola
> de candidatos las puntas que lo provocarían. La regla es de verificación, pero su cumplimiento
> empieza en la producción.

**Lo que esta sección todavía no cierra.** El **estado UTXO** sobre el orden resultante —el conjunto
con datos de deshacer que C-ORD-04 presupone y que hoy no existe (TAREAS §2.6)—, el cálculo
contextual del rango, los flujos y la laguna de unicidad pagable declarada en §7.2. Los cinco
pendientes de C-GD-11. Y una regla que esta especificación sigue sin tener y que **no es portable
desde Kaspa**: el **pruning** (§17).

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

Este valor se conserva para identificar el estado transitorio del código; **no fija la finalidad
del consenso DAG**. La regla de finalidad del diseño DAG es **`C-FIN-01`**, escrita más abajo en
índices de slot y sin `exit`. **`C-REORG-07` sigue siendo transitoria y no se reconcilia aquí**:
la reconciliación con el código que hoy se detiene, con `COINBASE_MATURITY` —de la que
`MAX_REORG_LENGTH` deriva— y con el techo de archivado queda declarada pendiente (§13,
`TAREAS.md` §2.9).

Una restricción de reorg protege el estado local, pero no demuestra por sí sola acuerdo entre
dos nodos aislados. Convertir 11 999 bloques a unas 3,33 h a tasa nominal no da un plazo
determinista, y **convertir bloques en slots exigiría meter `λ` —una magnitud estimada por el
retarget— dentro del consenso** (`C-FIN-01`). **Mientras las dos convivan, la que rige el destino
es `C-FIN-01`; `C-REORG-07` describe lo que el código hace hoy, no lo que el protocolo manda.**

**C-FIN-01 · Finalidad en índices de slot, sin `exit`.**

```text
Sea d = slot(punta actual) − slot(último ancestro común con la punta candidata),
en índices de slot de PoT (C-FLU-01).

Un nodo MUST NOT sustituir su cadena seleccionada por una candidata con d ≥ F_slots.
Una punta que lo exigiera se IGNORA.
El nodo MUST seguir operando: MUST NOT detenerse, MUST NOT abortar y MUST NOT exigir
intervención del operador por este motivo.
```

`F_slots` es un **SÍMBOLO**. Esta regla no le da valor: `<<PENDIENTE: §7.3>>`.

`C-FIN-01` obliga **únicamente** a quien ya tiene una cadena seleccionada que reorganizar
(`C-FLU-18`). La adopción dentro de la ventana que esta desigualdad deja abierta es `C-FLU-22`.

> **De dónde sale cada pieza.** El enunciado es el de R-FIN-7 (evidencia histórica,
> `research/dag-poas-ancla-de-orden.md:301-303`), con tres precisiones que R-FIN-7 no tenía: la
> magnitud es el **índice de slot** y no «segundos de slot»; **la desigualdad es explícita** —
> profundidad **exactamente** `F_slots` cae **dentro** de lo prohibido, que es la lectura
> conservadora (Katana, D-F4 = A)—; y el «nunca apaga el proceso» pasa de nota a **MUST NOT**
> enumerado, porque es precisamente lo que la diferencia del comportamiento vigente del código.
>
> **Por qué en slots y no en bloques.** `C-REORG-07` cuenta **bloques**; toda la regla de flujo
> cuenta **slots**. Convertir una en otra exige `λ`, que es una magnitud **estimada por el
> retarget**, no una constante de consenso. **Una regla de finalidad medida en bloques no se puede
> comparar con una profundidad medida en slots sin meter `λ` en el consenso.**
>
> **Relación con `C-REORG-07`: se declara, no se resuelve.** `C-REORG-07` sigue siendo
> **transitoria** y esta regla **no la toca**. Por alcance decidido (D-F3 = C, acotada al
> enunciado) **NO entran aquí**: la reconciliación con el código que hoy **se detiene**, la
> relación con `COINBASE_MATURITY` —de la que `MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 11 999`
> deriva— y el techo de archivado. Los tres están nombrados en `TAREAS.md` §2.9.
>
> ⚠️ **Dos reglas de profundidad conviven en este documento y dicen cosas distintas.** La que rige
> el diseño destino es **ésta**; `C-REORG-07` es **transitoria** y describe lo que el código hace
> hoy, no lo que el protocolo manda. **La reconciliación sigue pendiente** y está pedida en §13 y
> nombrada en `TAREAS.md` §2.9.

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

> **Alcance de `altura_ploteo` y `history_size`, dicho para no leer de más.** Los dos son
> referencias **lógicas** de historia y validez: identifican el prefijo histórico que determina la
> parcela y su caducidad. **No acreditan** cuándo se computaron físicamente los bytes, la posesión
> de un sector completo ni su permanencia, y un atacante puede escoger hoy una referencia antigua
> que aún sea válida. La interfaz examinada en `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`
> (resultado y «unidad mínima de intento») verifica **una pieza y su prueba**, no la preexistencia
> del sector entero. Esta nota no cambia campos, wire, predicados de aceptación ni edad de
> sectores, y no aprueba A1+C1, registro, maduración ni PoRep.

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

**C-FLU-17 · El nodo detecta que ha quedado fuera del flujo mayoritario y lo señala.**

> **Esto NO es una regla de consenso.** No cambia la validez de ningún bloque. Existe para que un
> nodo no siga funcionando **en silencio** dentro de un flujo minoritario.

Un nodo **MUST** señalar el estado «flujo posiblemente minoritario» cuando, **de forma sostenida**,
exista una punta `P` conocida con `flujo(P, slot(P)) ≠ flujo(mi punta, slot(mi punta))`,
`blue_work(P) > blue_work(mi punta seleccionada)`, y que `C-FIN-01` le obligue a ignorar.

La señal **MUST** exigir persistencia durante una ventana y **MUST NOT** dispararse con una sola
observación: una punta rival más pesada puede ser transitoria o fabricada.
`<<PENDIENTE: la ventana de persistencia y el margen de blue_work>>` — es calibración, y ninguna
implementación puede fijarla por su cuenta (§0.3).

El trabajo de calcular `blue_work` de una punta ajena **MUST** caer dentro del presupuesto de
`C-NET-33`, y agotarlo **MUST** dejar la señal como «no determinada», **nunca** como «estoy en el
mayoritario».

Qué hace el nodo con la señal: **nada automático**. La expone —registro, métrica, estado
consultable— y **MAY** dejar de producir bloques si el operador lo ha configurado así.

> **Es computable con lo que el nodo ya calcula y sin AES:** el flujo de `P` sale del paso 1b de
> `C-POT-08`, y `blue_work` es lo que GHOSTDAG ya produce. **La señal existe precisamente porque el
> protocolo no puede hacer nada más**: cambiar de flujo fuera de la ventana de `C-FLU-22` es lo que
> `C-FIN-01` prohíbe.

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
gossipsub topics:  /zerox/blocks/2  ·  /zerox/txs/1  ·  /zerox/pot/1
request-response:  /zerox/sync/1  ·  /zerox/block-relay/1
kademlia:          /zerox/kad/1
identify agent:    zerox/<version>
```

> **`/zerox/blocks/2`, no `/1`** (C-NET-25, 2026-09-16): el tema de bloques pasa a llevar **solo**
> anuncios compactos, y el `/1` significaba bloque completo. `/zerox/block-relay/1` recupera lo que
> falte y `/zerox/pot/1` lleva el PoT (C-NET-31). El código sigue en `/blocks/1`
> (`crates/zx-p2p/src/config.rs:91`): migrarlo es parte de cablear el relé.

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

### 16.2 · Relé compacto obligatorio — arquitectura «1+», transporte, NO consenso

> **Decidido por Katana el 2026-09-16**, sobre las decisiones de red del 2026-09-13 (Q1, Q2 y Q4 de
> TAREAS §3.1). Esta subsección deja de describir BIP 152 adaptado y pasa a describir el transporte
> de ZEROX: el relé compacto es **obligatorio**, no negociado, y el bloque completo **sale del
> gossip**. Lo que se conserva de BIP 152 es la derivación del ID corto, las estructuras, el
> algoritmo de reconstrucción y el orden causal de C-NET-06.

**C-NET-25 · Los tres canales, y qué lleva cada uno.** La propagación **MUST** repartirse así, y un
mensaje que llegue por un canal que no le corresponde **MUST** descartarse:

| Protocolo | Lleva |
|---|---|
| `/zerox/blocks/2` (gossipsub) | **solo** anuncios compactos: cabecera DAG, nonce de transporte e IDs cortos |
| `/zerox/block-relay/1` (request-response) | transacciones que faltan, resolución de colisiones y, como último recurso, el bloque completo |
| `/zerox/sync/1` (request-response) | IBD e histórico, **sin cambios** |

Un bloque completo **MUST NOT** difundirse por gossip en ningún caso.

> **Por qué el bloque completo sale del gossip, y no es una cuestión de ahorro.** Si el anuncio y el
> bloque entero viajan por el mismo mecanismo de difusión, tienen `message_id` distinto y gossipsub
> **no los deduplica**: la red transporta el mismo bloque dos veces, que es exactamente el ancho de
> banda que el relé compacto venía a ahorrar. Con dos temas conviviendo pasa lo mismo.
>
> **La versión del protocolo sube a `/2` y eso no es cosmético:** hoy `/zerox/blocks/1` significa
> «bloque completo». Un nodo nuevo que anuncie compacto en el tema viejo le manda a un nodo antiguo
> algo que no sabe parsear.
>
> ⚠️ **Trampa de implementación, verificada.** `crates/zx-p2p/src/servicio.rs` despacha por
> `topico.contains("/blocks/")` hacia `respuesta_desde_bytes`, que espera una `Respuesta`.
> `/blocks/2` **también** cumple esa condición. Cambiar la versión sin cambiar el despacho hace que
> los anuncios se rechacen como basura **y que el par que los propaga se lleve la penalización** —
> un nodo correcto baneando a otro nodo correcto, que es el peor fallo posible de esta familia.
>
> Se descartaron dos alternativas. **Dos temas conviviendo** hace viajar el bloque dos veces. **Empujar
> a ≤3 pares** (BIP 152 fiel) exige estado por conexión, que `research/bip152.md` §8 declara **no
> portable** a libp2p sin forzar un stream lógico único por par sobre yamux. El híbrido *eager/lazy*
> queda **aparcado** como *fast lane* experimental: es portable —negociar al abrir cada substream no
> es `sendcmpct`— pero añade RTT, estado de proveedores y el riesgo de que los «más rápidos» sean
> pares adversarios. Solo se activa si mejora p95/p99 bajo mempool frío, ramas DAG, pérdida y eclipse.

**C-NET-26 · El relé compacto es obligatorio en la ruta crítica.** Todo nodo **MUST** anunciar los
bloques que produce o adopta como anuncio compacto por `/zerox/blocks/2`, y **MUST** aceptar
anuncios compactos de cualquier par. No hay negociación por conexión ni modo de alto ancho de banda.

> **Es una decisión de presupuesto, no de estilo** (Q2, 2026-09-13). Con el techo de Q1 y el modelo
> pesimista del v1 —8 pares en serie, ≈5,6 saltos— el anuncio compacto ocupa el 1,8 % de la subida de
> un nodo de 100 Mbit/s y añade ≈0,1 s de Δ. **El bloque completo satura el enlace**: utilización
> ρ = 1,0 a 100 Mbit/s y 1,68 por líneas típicas de EE. UU. Con ρ ≥ 1 no existe una Δ estable,
> porque la cola crece con el tiempo: no es que la propagación sea lenta, es que no converge.
> Medido en `veritas/finalidad/delta-medido-v1/` (DMS-v0.1, revisión 2).
>
> Por eso «negociado por conexión» no sirve: si un par lo rechaza, el emisor cae al bloque completo
> y ese enlace entra en saturación. Una opción que solo funciona cuando todos la eligen no es una
> opción, es un requisito mal escrito.

**C-NET-27 · Un anuncio sin padres va a una cola acotada, no se descarta.** Un anuncio compacto que
no se pueda evaluar porque falten padres del DAG **MUST** retenerse en una cola de tamaño acotado y
**MUST** reevaluarse cuando lleguen sus dependencias. El nodo **MUST NOT** depender de que gossipsub
se lo vuelva a entregar, y **MUST NOT** penalizar al emisor (C-NET-12: huérfano no es inválido).

`<<PENDIENTE: tamaño de la cola y política de desalojo>>` — se dimensiona con el v2a (Q5); hasta
entonces ninguna implementación puede fijar el valor por su cuenta (§0.3). El presupuesto agregado
de C-NET-21 sigue aplicando como techo.

> Con el bloque completo fuera del gossip, **la reentrega deja de ser una red de seguridad**.
> gossipsub deduplica por `message_id`: un anuncio ya visto no se vuelve a entregar aunque la
> primera vez no se pudiera evaluar. En un DAG con varios padres esto no es un caso raro —es el caso
> normal cuando dos bloques hermanos llegan en orden inverso—, así que sin cola el anuncio se pierde
> y el bloque solo se recupera por IBD, con el retraso que eso implica.

**C-NET-28 · Pedir lo que falta es el camino ordinario; el bloque entero, el último recurso.** Ante
un anuncio cuyas transacciones no están todas en la mempool, el nodo **MUST** pedirlas por
`/zerox/block-relay/1`. **MUST** poder probar **proveedores alternativos** y no quedar cautivo del
primer emisor. Bajarse el bloque completo **MUST** ser el último recurso, no la reacción al primer
fallo. Ni la falta de transacciones ni una colisión **MUST** penalizar a quien reenvía.

> **Quien reenvía no eligió el contenido**, que es la razón de C-NET-05 y de C-NET-08 aplicada aquí:
> la falta viene casi siempre de **mempools desincronizadas**, no de mala fe. Con un bloque por
> segundo, lo que tardan las transacciones en llegar a todas las mempools es del orden del intervalo
> entre bloques, así que el caso degradado puede ser el normal —hipótesis derivada, aún sin medir:
> la mide el v2a (Q5).
>
> Y caer al bloque entero al primer fallo **tira la ventaja que el relé venía a dar**: devuelve el
> enlace a la saturación que C-NET-26 evita, y lo hace justo bajo la condición que un adversario
> puede provocar a coste casi nulo.

**C-NET-06 · Qué se verifica antes de reenviar, y qué después.** Antes de reenviar un bloque o de
emitir un anuncio compacto, el nodo **MUST** haber verificado, en este orden: **cabecera**, **prueba
de espacio**, los **dos testigos KZG**, el **sello**, la **justificación PoT** (contra la caché de
slots, C-NET-31) y el **compromiso del cuerpo**. **MUST NOT** reenviar sin eso.

**MAY** dejar para después —antes de adoptar el estado, nunca antes de reenviar— las **firmas**, las
**pruebas Halo2** y la comprobación de que cada entrada gasta un **UTXO existente**.

> Reescrita el 2026-09-17 sobre la decisión Q4 del 2026-09-13. La versión anterior solo eximía la
> comprobación de UTXO y dejaba el resto del orden sin decir, que es como no haberlo fijado.
>
> **El criterio es qué acota el coste por salto.** Lo que va antes está acotado por construcción: no
> depende del salto de slots —si el PoT se verificara por bloque serían hasta 150 × 96,1 ms ≈ 14,4 s—
> ni del número de transacciones, cuyo coste Halo2 no está medido. Medido en hardware
> (`veritas/rendimiento/coste-salto-v1/`, 2026-09-14, un núcleo de un Ryzen 9 9950X3D): validar antes
> de reenviar cuesta **1,33 ms** con 571 tx y **2,17 ms** con 4 464 tx usando relé compacto; con
> cuerpo completo, 2,32 y 9,86 ms. El peor caso deja 10× de margen sobre los 0,1 s por salto de la
> sensibilidad de DMS-v0.1.
>
> **Lo que se paga a cambio, dicho en voz alta:** un bloque con cabecera válida y transacciones
> inválidas se propaga antes de detectarse. Es el mismo compromiso que acepta BIP 152, y aquí cuesta
> más que en Bitcoin porque fabricar la cabecera exige un **billete ganador real** — no es gratis,
> pero tampoco es imposible. El vector entra en el v2b (Q5).
>
> 🔶 **Pregunta abierta: relajar esta regla.** Tal y como está, el nodo necesita **todas** las
> transacciones antes de anunciar, así que la petición de las que faltan (C-NET-28) está **dentro**
> de la ruta crítica. Anunciar antes de reconstruir la sacaría de ahí, a cambio de propagar anuncios
> cuyo cuerpo podría no coincidir. **Se decide cuando el v2a mida con qué frecuencia faltan
> transacciones** (Q2, Q5). No se decide antes por intuición.

**C-NET-07 · Derivación del ID corto.** Sobre `wtxid = txid ‖ auth_digest`:

```
h  = SHA3-256( cabecera_canónica ‖ nonce_transporte(8 B LE) )       ← divergencia deliberada, ver abajo
k0 = h[0..8]  como u64 LE
k1 = h[8..16] como u64 LE
id = los 6 bytes bajos de SipHash-2-4(k0, k1, wtxid)
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
>
> **Por qué `wtxid` y no `txid` — decidido por Katana el 2026-09-16**, como BIP 152 v2. Y el motivo
> **no es de consenso**: un bloque mal reconstruido ya se rechaza, porque `merkle_root` va sobre
> `txid` pero `body_commitment` cubre `txid ‖ auth_digest` y el relé lo comprueba (C-NET-09).
>
> El problema es de **disponibilidad**. Cuando ese compromiso falla, el nodo no sabe **qué**
> transacción estaba mal, y su única salida es bajarse el bloque entero — justo el fallback que
> C-NET-28 declara último recurso. Quien firma una transacción puede publicar dos variantes con el
> **mismo `txid`** y distinto `auth_digest`, sembrarlas en mempools distintas y forzar fallbacks
> completos **a coste casi cero**. Derivar sobre `wtxid` convierte esas dos variantes en dos IDs
> cortos distintos, y el fallo vuelve a ser una colisión ordinaria que C-NET-08 resuelve pidiendo la
> transacción.
>
> ⚠️ **Esto cambia una regla ya cerrada e implementada.** `crates/zx-p2p/src/id_corto.rs` deriva hoy
> sobre `txid`: su código es de la versión anterior de esta regla y **debe migrarse** al cablear el
> relé. Declarado en `ci/reglas-sin-cablear.txt`.

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

🪦 **C-NET-10 — RETIRADA el 2026-09-16. Su número no se reutiliza ni se recicla.**

Decía: «máximo 3 peers en modo de alto ancho de banda», literal de BIP 152 (*"Nodes MUST NOT send
such sendcmpct messages to more than three peers…"*), elegidos por histórico de entrega rápida.

**Por qué se retira.** Presuponía que existe un modo de alto ancho de banda que se negocia y que se
concede a unos pares y no a otros. Con C-NET-26 el relé compacto es **obligatorio con todos**, así
que no hay a quién elegir: la regla dejó de tener sujeto. Empujar a ≤3 pares, además, exige estado
por conexión que `research/bip152.md` §8 declara **no portable** a libp2p sin forzar un stream
lógico único por par sobre yamux.

> 🔶 **La negociación de `sendcmpct` NO se porta**, y esa parte sigue siendo cierta: depende de una
> conexión TCP persistente con **orden total** entre `sendcmpct`, `getdata`, `cmpctblock`,
> `ping`/`pong`. libp2p multiplexa streams independientes sobre yamux y no garantiza ese orden. Lo
> que se adopta de BIP 152 es la derivación del ID corto, las estructuras, el algoritmo de
> reconstrucción y C-NET-06.

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

**R-NET-01 · Relé compacto.** El relé compacto anuncia cabecera e identificadores cortos y permite
recuperar las transacciones que falten o, como último recurso, el bloque completo. No modifica las
reglas que hacen válido al bloque.

> **Reescrita el 2026-09-17: se elimina la negociación por conexión, y solo eso.** La redacción
> anterior decía que el relé «negocia el soporte por conexión», que es la parte de BIP 152 que
> C-NET-26 convierte en obligatoria y C-NET-10 retira. El resto de la regla se conserva.
>
> Esta regla contradecía a la decisión Q2 desde el 2026-09-13 y la contradicción estuvo viva cuatro
> días. Se anota porque un SPEC que se contradice a sí mismo es peor que uno incompleto: el
> incompleto se nota al implementar, y el contradictorio se implementa dos veces.

**R-NET-02 · Sal por bloque.** Los identificadores cortos usan una clave derivada de la cabecera
y la sal de transporte (C-NET-07). Esa sal no es trabajo de consenso.

La latencia depende también de saltos de red, recuperación de datos y validación de PoT.
Se medirá con el formato DAG y las pruebas reales; no se trasladan estimaciones de huérfanos de
una cadena de bloques cada dos minutos.

### 16.5 · Prioridad de reenvío y presupuesto de subida

> **Decidido por Katana el 2026-09-13** (Q1 de TAREAS §3.1), y es la condición sin la cual la
> referencia de 100 Mbit/s de subida no se sostiene: **sin estas reglas, un nodo por debajo de la
> referencia se satura en lugar de recortar.**

**C-NET-29 · El consenso se reenvía antes que las transacciones.** Las colas de salida **MUST**
servir los anuncios compactos de bloque (C-NET-25) y los mensajes de PoT (C-NET-31) **con prioridad
estricta** sobre el reenvío de transacciones. Una cola de transacciones llena **MUST NOT** retrasar
un anuncio de bloque.

> **En el techo de Q1 el reenvío de transacciones ocupa toda la subida del nodo de referencia**
> (ρ = 1,0 en la cuenta pesimista de 8 pares sin overhead). El anuncio compacto solo sale a tiempo
> porque esta regla existe: sin ella, el bloque espera detrás de la cola de transacciones justo
> cuando la red está cargada, que es cuando Δ importa.
>
> Y el orden importa en ambos sentidos: el PoT va con el bloque porque C-NET-31 lo pone en la ruta
> de validación de todos los demás. Un PoT que llega tarde retrasa la verificación de cada bloque
> que cite ese slot.

**C-NET-30 · Presupuesto de reenvío de transacciones, y recorte antes que saturación.** El reenvío
de transacciones **MUST** ir sujeto a un presupuesto de subida **estrictamente por debajo** de la
capacidad de subida disponible del nodo. Alcanzado el presupuesto, el nodo **MUST** recortar lo que
reenvía —y **MUST NOT** encolar sin límite ni dejar de reenviar bloques. Las transacciones **MUST**
reenviarse por **anuncio y petición**, nunca empujando la transacción completa sin que se la pidan.

`<<PENDIENTE: el valor del presupuesto y la política de recorte>>` — dependen del v2a (Q5), que mide
la inundación de transacciones contra la subida honesta con y sin esta regla. Ninguna implementación
puede fijarlos por su cuenta (§0.3).

> **Anuncio y petición no es un detalle de eficiencia: es lo que hace que el recorte sea posible.**
> Empujando la transacción completa, el emisor gasta su subida antes de saber si el receptor la
> quería; el receptor no puede decir que no, y el coste se paga en la dirección equivocada. Con
> anuncio y petición, un nodo saturado simplemente pide menos.
>
> **Consecuencia declarada de Q1, que esta regla no elimina:** con la carga sostenida del techo, las
> líneas típicas de EE. UU., Canadá, México, Argentina, China, India y Alemania quedan por debajo de
> la referencia. Esos nodos **siguen recibiendo y validando**; lo que se concentra en los nodos mejor
> conectados es el **reenvío**. Es el coste aceptado de la política de marketplace de Q1, no un
> efecto imprevisto.

### 16.6 · Proof-of-Time en la red — una verificación por slot

> **Decidido por Katana el 2026-09-13** (Q4). Es el patrón de Autonomys: `subspace` @ `f8842d0`,
> `crates/sc-proof-of-time/src/source/gossip.rs` y `verifier.rs:25-29`.

**C-NET-31 · El PoT viaja en su propio tema y se verifica una vez por clave de contexto.** Las
salidas de PoT **MUST** propagarse por un tema de gossip propio, `/zerox/pot/1`, independiente de
bloques y transacciones. Cada nodo **MUST** verificar cada slot **una sola vez por clave** y
**MUST** cachear el resultado; toda validación de bloque que cite ese slot **MUST** resolverse
contra esa caché (C-NET-06). Cada slot se verifica **entero**, lo que lo hace compatible con
C-CHK-05.

**La clave de la caché es la contextual de `C-POT-07`** —`(f, s, semilla(f, s), N(s))`, los cuatro
del contexto—, **no el slot a secas**. Con un único flujo candidato la clave es función de `s` y el
comportamiento es idéntico al de indexar por slot; con dos o más flujos, indexar por slot haría
depender la **validez** de qué llegó primero a la caché del nodo, que es lo que `C-POT-07` corrige.

> **Sin esto, el coste por salto depende del salto de slots y deja de estar acotado.** Verificar el
> PoT por bloque, con `S_max = 150` slots de justificación, costaría hasta 150 × 96,1 ms ≈ **14,4 s**
> por bloque. Con caché por slot, el coste es de un slot y se amortiza entre todos los bloques que lo
> citen.
>
> Coste real de un slot, medido en hardware (`veritas/rendimiento/coste-salto-v1/`, 2026-09-14):
> **92 ms** con AVX-512/VAES, **101 ms** con AVX2/VAES, **190 ms** con AES-NI y SSE4.1, y **8,3 s**
> con AES por software. Las rutas sin AVX-512 se forzaron en la misma CPU, así que no equivalen a
> una CPU antigua: son una cota superior optimista para hardware viejo, y el caso por software dice
> que un nodo sin aceleración AES **no puede seguir el ritmo**.
>
> Nota de implementación, derivada y sin medir: ponerse al día admite verificar **varios slots en
> paralelo** entre núcleos (≈1,8 s para 150 slots en 8 núcleos). **Dentro** de un slot no hay
> ganancia — la ruta AVX-512/VAES ya verifica los 8 tramos a la vez con 16 carriles AES.

**C-NET-32 · Verificación bajo demanda, con tres salvaguardas.** Si un bloque cita slots que el nodo
todavía no ha verificado, **MAY** verificarlos en ese momento con la justificación que trae el propio
bloque (C-HDR-07), **una sola vez por nodo y slot**. Esa verificación **MUST** aplicar las tres:

1. **Comparar primero con la caché, bajo la MISMA clave.** Si la salida no coincide con la ya
   verificada **para la misma clave contextual** (`C-POT-07`), el bloque es **inválido** y se
   rechaza **sin gastar CPU** en la cadena AES. **Discrepar con una entrada de OTRA clave no prueba
   nada** y **MUST NOT** invalidar: son cadenas de PoT distintas, ambas legítimas.
2. **Retener, no verificar, lo que va por delante del reloj.** Los slots posteriores al reloj PoT del
   nodo **MUST** retenerse, no verificarse (`research/dag-poas-ancla-de-orden.md:342`). El estado es
   `Pendiente`.
3. **Presupuesto de CPU acotado**, por par y por intervalo, en el espíritu de C-NET-04. **Para el
   trabajo sobre ramas de otro flujo hay además una cota global por nodo, y el modo de fallo está
   escrito: `C-NET-33`.** Agotar un presupuesto da **`Pendiente`, NUNCA `Inválido`** (`C-POT-07`).

`<<PENDIENTE: el valor del presupuesto de CPU por par e intervalo>>` — se calibra con el v2b (Q5),
que incluye agotar este presupuesto como vector de ataque. Ninguna implementación puede fijarlo por
su cuenta (§0.3).

> **Este es el respaldo, no el camino normal.** El camino normal es el tema de gossip de C-NET-31;
> esto existe para nodos que se ponen al día y para el bloque que llega antes que su slot.
>
> Las tres salvaguardas no son cortesía: sin la primera, cualquiera hace gastar 92 ms por slot
> inventado; sin la segunda, un bloque del futuro obliga a verificar una cadena que aún no debería
> existir; sin la tercera, el coste agregado de peticiones simultáneas no tiene techo. El v2b (Q5)
> las ataca a propósito.

**C-NET-33 · Presupuesto de verificación de flujo ajeno: dos cotas, y qué pasa al agotarlas.**

El trabajo que un nodo dedica a ramas de **otro flujo** —la comprobación estructural del paso 1b de
`C-POT-08` y la verificación de PoT de `C-FLU-22`— **MUST** estar acotado por **dos** presupuestos
a la vez:

```text
PRESUP_PAR    por par y por intervalo     (es el de C-NET-32.3)
PRESUP_NODO   por NODO y por intervalo    (nuevo)
```

Agotar **cualquiera** de los dos produce **`Pendiente`, NUNCA `Inválido`**. Con `Pendiente` el nodo:

- **MUST** conservar su cadena seleccionada actual — no adopta;
- **MUST NOT** tratar la rama como inválida;
- **MUST NOT** dejar de reenviarla por este motivo;
- **MUST** reintentar cuando vuelva a tener presupuesto, mientras la ventana de `C-FLU-22` siga
  abierta.

`<<PENDIENTE: los valores de PRESUP_PAR y PRESUP_NODO>>`. Ninguna implementación puede fijarlos por
su cuenta (§0.3).

> **Por qué hacía falta la segunda cota.** C-NET-32.3 acota «por par y por intervalo», y **las
> identidades son gratis por diseño** (`research/dag-poas-balizas-auditoria.md:68-75`): un atacante
> con `N` conexiones obtiene `N` presupuestos, así que el techo de trabajo por nodo **lo fija él**.
> Con `PRESUP_NODO` el techo **deja de depender de `N`**, que es el criterio declarado de C-NET-06.
> Esto **no** abarata ni encarece el **disparo** del AES ajeno —que sigue exigiendo ganar la
> carrera de `C-FLU-22`—; lo que acota es el **techo**.
>
> **Por qué el modo de fallo se escribe entero.** Bajo `C-FLU-22`, «no adoptar» **ya no es neutro**:
> quedarse sin presupuesto durante la ventana significa quedarse en el flujo en el que se está, y
> cuando la ventana se cierra, **quedarse ahí para siempre**. De ahí las cuatro obligaciones, y en
> particular **seguir reenviando**: un nodo sin presupuesto no debe convertirse además en
> amplificador de la partición cortando la propagación a sus pares.
>
> ⚠️ **Esto abre una rendija más, y no está medida.** Dos nodos **con el mismo DAG** pueden acabar
> en flujos distintos porque uno pudo pagar la verificación dentro de la ventana y el otro no. Es
> la **tercera** rendija, además de las dos de PCO-v0.1, y **a diferencia de aquellas está
> parcialmente bajo control del atacante**, que puede gastar presupuesto ajeno con tráfico barato
> del paso 1b. La **validez** no se mueve —sigue siendo función de `past(B)`—; lo que se mueve es la
> **selección**, que bajo `C-FLU-22` decide el flujo. `TAREAS.md` §2.9.
>
> **La calibración es una pinza, no un número suelto.** Por abajo, integrado sobre la ventana,
> `PRESUP_NODO` **MUST** bastar para verificar **una** rama rival completa —en el peor caso
> `F_slots` slots, del orden de `F_slots × 92 ms` con los costes de esta sección—; con menos, la
> adopción **nunca** se completa y **D-F9 quedaría derogada de hecho sin que nadie la revocara**.
> Por arriba, demasiado grande devuelve el DoS que la segunda cota existe para acotar. **La cota
> superior no está derivada.** `TAREAS.md` §2.9.

---

## 17 · Pendientes activos del consenso destino

Esta lista es local y no depende del estado de un vault externo. La limpieza documental no
congela parámetros ni convierte prototipos en implementaciones.

| Área | Trabajo pendiente |
|---|---|
| Cabecera y wire | Integrar en la ruta activa del nodo el formato ya fijado en §6.1–§6.2: layout (C-HDR-01), prefirma (C-HDR-03), justificación PoT (C-HDR-07) y codec único (C-HDR-09). El texto normativo no deja nada pendiente aquí. |
| Prueba de espacio/tiempo | Verificación conjunta de solución, KZG, sello, reto secuencial, autoría y flujos. El **umbral protocolario sigue inconcluso** (`P-ZRX/P-CRP/auditoria/INFORME.md`): `α_drift = 1/2` es una **identidad aritmética del baseline analítico idealizado** (un evento por paso, tasas simétricas), no un umbral demostrado de ZEROX; y `α = 1/(S+1)` —el «4 %» con `S = 24`— pertenece al **contrafactual aditivo** de flujos independientes, que `C-FLU-14` excluye: **no es umbral de una cadena válida** bajo las reglas vigentes. `S = 24` es un escenario de IOPS de una configuración de hardware (`P-ZRX/P-PUERTA/veritas/consenso/puerta-cobertura-v1/INFORME.md`), no una capacidad adversaria universal; `S_adversario` sigue pendiente (`P-ZRX/P-CRP/auditoria/RECOMENDACION-MIGRACION.md`). CRP-v0.2 y CRP-v0.3 fueron **auditadas**, no validadas como instrumentos ni migradas; v0.3 exige correcciones bloqueantes y veredicto rebajado, y v0.2 no sustituye esas correcciones. Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. **DECIDIDO por Katana (2026-09-19/20) y REDACTADO en §7.1: validez ABSOLUTA (`C-FLU-13`), perfil 1a (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`).** El multistream queda cerrado **por decisión, no por medición**: un flujo fabricado no es el de ningún bloque honesto y sus bloques no se pueden referenciar (`C-FLU-14`); `C-FLU-13`/`C-FLU-14` siguen vigentes. **El split NO se cierra con una regla: se previene con `L` frente a `Δ`**, y si nace se cura solo en el caso espontáneo (`C-FLU-22`), nunca en un corte de red más largo que `L`. **No se declara resuelto el doble farmeo ni existe un umbral global demostrado.** Lo que queda: el código —casi ninguna de las 31 reglas nuevas tiene una línea; la excepción es `C-FLU-02`, cuya comprobación `slot(p) ≤ slot(B)` ya existe en los componentes DAG, pero sigue sin ejecutarse en la ruta activa de `zx-node`, que continúa lineal— y las mediciones que faltan (`TAREAS.md` §2.9). |
| Rango | R-FIN-13′ completo: arranque, ventana, redondeos, fusiones tardías, ramas candidatas. |
| DAG | Redactado el 2026-09-17: conflictos de transacciones (**C-ORD-04**), `pick_virtual_parents` (**C-GD-10**) y *bounded merge depth* con kosherización (**C-GD-11**). Quedan: el enlace de C-ORD-04 con el estado UTXO (§2.6) y los **cinco pendientes de C-GD-11** —métrica, valor, bootstrap, borde de igualdad y relación con finalidad y poda—, que no se fijan por analogía con Kaspa ni derivando de `F = 2 h` provisional. GHOSTDAG, U2/U3″, peso, cadena seleccionada y orden quedan especificados en §11. |
| Poda (*pruning*) | **Auditado el 2026-09-17** (`veritas/consenso/poda-post-v1/`, PPP-v0.1), con **defectos anotados el 2026-09-18** en su `PROCEDENCIA.md` §3.3–§3.4. **Lo que falta no es el IBD sin confianza: es el IBD SUCINTO.** Un nodo nuevo siempre puede descargar y validar toda la historia desde el génesis sin confiar en nadie; lo que ZEROX no tiene es un arranque **sucinto desde estado podado** sin ancla externa. **(1) Poda local:** política de nodo **viable en principio**, no implementada, y condicionada a que existan finalidad integrada (R-FIN-7), estado UTXO con datos de deshacer (§2.6, hoy inexistente) y una profundidad de retención cerrada (C-GD-11). **(2) Prueba de poda por certificados de niveles: descartada.** El nivel de solución se calcula **antes** de elegir padres, así que se pega a cualquier historia; el nivel por hash de cabecera sí liga a los padres pero se muele con CPU (C-HDR-04: el sello Ed25519 no es único, y `merkle_root` varía con la coinbase), luego no mide espacio. En PoW ambas propiedades coinciden en el mismo objeto; en PoST se separan, y esa separación es la raíz. **El resultado vale para los mecanismos examinados, no para toda familia de pruebas**: su formalización no captura que el recurso deba pagarse de nuevo por cada ancestría, y no modela el PoT ni sus flujos. **(3) Disponibilidad histórica** — capa social/económica, no criptográfica: no resuelve (2). **Consecuencia: §6.1 NO se reabre por este mecanismo** — `parents_by_level` no rescata este certificado, luego el cableado de la cabecera DAG no está bloqueado; un reto futuro ligado a la ancestría sí la reabriría. **Abierto y sin cerrar:** la vía de prueba recursiva (coste **estimado**, no medido: no hay circuito ni banco de probador) y, sobre todo, **el coste real de construir una rama privada con más `blue_work`**, que ninguna auditoría ha medido y que decide si esto es un problema de ingeniería o de consenso. **La poda sigue siendo requisito para lanzar mainnet.** Una testnet **MAY** operar sin poda con nodos archivales declarados explícitamente, y eso **no cuenta como solución**. |
| Alturas y calendario | Activaciones, expiración de tx/sectores, timelocks, coinbase y archivado derivados del orden DAG. |
| Finalidad | **R-FIN-7 queda redactada como `C-FIN-01` (§12), en índices de slot y sin `exit`.** Lo que sigue abierto: la **reconciliación** con `C-REORG-07`, con el código que hoy se detiene, con `COINBASE_MATURITY` y con el techo de archivado (fuera de alcance por decisión, D-F3); la elección conjunta de `I`/`F`/`L_suelo`/`ρ_max`; y la **recuperación**, que `C-FLU-22` solo cubre para el nacimiento espontáneo de una partición de flujo. |
| Red | Δ natural y coste por salto: **medidos** (`veritas/finalidad/delta-medido-v1/`, `veritas/rendimiento/coste-salto-v1/`, 2026-09-14). El transporte quedó especificado el 2026-09-17: relé «1+» obligatorio (C-NET-25…28), prioridad y presupuesto de subida (C-NET-29, C-NET-30) y PoT por slot (C-NET-31, C-NET-32). **Pendiente:** los tres valores que el v2a/v2b deben calibrar —tamaño de la cola de anuncios huérfanos, presupuesto de reenvío de transacciones y presupuesto de CPU del PoT bajo demanda—, la decisión de relajar o no C-NET-06, y el código: ninguna de las ocho reglas nuevas tiene implementación. |
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
