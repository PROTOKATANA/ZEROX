# ESPECIFICACIÓN-BYTES — S01: R1, R2, apertura y volcado

**Estado:** especificación del prototipo de investigación S01. No es una regla de consenso ni
modifica `D-ZRX/SPEC.md`.
**Ámbito:** `deepseek/S01/prototipo/` y `deepseek/S01/oraculo-r2/`.

Convenciones: todos los enteros son **little-endian**; `u16` = 2 B, `u32` = 4 B, `u64` = 8 B;
`H_d(tag, m) = SHA3-256(tag ‖ m)` con `tag` de **16 B** (C-HASH-04). Las etiquetas son:

| Etiqueta | Bytes |
|---|---|
| `TAG_HOJA` | `ZZKSectorHoja___` |
| `TAG_NODO` | `ZZKSectorNodo___` |
| `TAG_VACIO` | `ZZKSectorVacio__` |
| `TAG_RAIZ` | `ZZKSectorRaiz___` |
| `TAG_MAPA` | `ZZKSectorMapa___` |
| `TAG_META` | `ZZKSectorMeta___` |
| `TAG_ALTA` | `ZZKSectorAlta___` (elegida por S01; la orden no fija R1) |

---

## 1. Regiones del archivo de sector (formato del plotter, no de S01)

El archivo de sector que escribe `subspace-farmer-components::plotting::write_sector` tiene, en este
orden, `sector_size(pieces_in_sector)` bytes:

| Región | Tamaño | Origen |
|---|---|---|
| `mapa` | `SectorContentsMap::encoded_size(p) = 8192·p + 32` | bitfields Lsb0 (8192 B por pieza) + BLAKE3 interno de 32 B |
| `chunks` | `sector_record_chunks_size(p) = p · 2^15 · 32` | s-buckets; en orden s-bucket ascendente, dentro pieza ascendente |
| `meta` | `sector_record_metadata_size(p) = p · (48 + 48 + 32)` | `RecordMetadata` SCALE por registro (witness ‖ commitment ‖ checksum) |
| `checksum` | 32 B | BLAKE3 de todo lo anterior |

`p = pieces_in_sector`. `NUM_CHUNKS = 2^15 = 32768`; `NUM_S_BUCKETS = 2^16 = 65536`; cada registro
aporta exactamente `NUM_CHUNKS` chunks usados ⇒ `n = p · NUM_CHUNKS`.

---

## 2. R1 — alta de identidad y fecha

Construcción **elegida por S01** (la orden no fija bytes para R1); es contabilidad, no prueba:

```
R1 = H_d("ZZKSectorAlta___",
         public_key 32 B ‖ sector_index u16 ‖ history_size u64 ‖ slot_alta u64)
```

`public_key` son los 32 B del `PublicKey` de Autonomys; `slot_alta` es el slot del alta (no es un
dato de consenso en este prototipo).

---

## 3. Hoja de chunk

```
hoja(i) = H_d("ZZKSectorHoja___",
              s_bucket u16 ‖ piece_offset u16 ‖ codificado u8 ‖ chunk_almacenado 32 B)
```

- `s_bucket` ∈ `[0, 65535]`.
- `piece_offset` ∈ `[0, p−1]`.
- `codificado = 1` si el chunk se guardó enmascarado con la prueba de espacio; `0` si se guardó como
  chunk erasure-coded sin prueba (relleno final del registro).
- `chunk_almacenado` = los 32 B **tal cual están en la región `chunks`**.

---

## 4. Orden de hojas y árbol

El índice `i` (posición global, `chunk_location`) recorre la región `chunks` en orden físico:

```
para s_bucket = 0 .. 65535:
    para (piece_offset, codificado) en iter_s_bucket_records(s_bucket):   # pieza ascendente
        i += 1
```

Esto reproduce `subspace-farmer-components/src/sector.rs:436-470` (verificado en fuente por el
director). El número de hojas es `n = p · NUM_CHUNKS`; se comprueba.

Árbol Merkle binario:

```
nodo(izq, der) = H_d("ZZKSectorNodo___", izq 32 B ‖ der 32 B)
vacío          = H_d("ZZKSectorVacio__", "")
m              = next_pow2(n)
nivel0         = hoja(0) … hoja(n−1) ‖ vacío … vacío   (m entradas)
raiz_chunks    = plegar por pares con nodo hasta una entrada
```

Camino de apertura de la hoja `i`: un hermano por nivel, de abajo arriba (`log2(m)` hermanos).

---

## 5. R2 — compromiso exacto del sector

```
R2 = H_d("ZZKSectorRaiz___",
         0x01                        u8      -- versión del formato
         ‖ CBID                     u32
         ‖ public_key               32 B
         ‖ sector_index             u16
         ‖ history_size             u64
         ‖ pieces_in_sector         u16
         ‖ H_d("ZZKSectorMapa___",  bytes de la región `mapa`, 8192·p + 32 B)
         ‖ H_d("ZZKSectorMeta___",  bytes de la región `meta`, p·(48+48+32) B)
         ‖ raiz_chunks              32 B
         ‖ n                        u32)
```

Longitud de la preimagen: `1 + 4 + 32 + 2 + 8 + 2 + 32 + 32 + 32 + 4 = 149 B`.

`CBID` es el identificador de rama/dominio de red. En S01 se usa `CBID_PRUEBA = 0xc478_80ea`
porque **no existe** `CBID_RED_DEV` en `zx-core` (ver `INFORME.md` §2).

### Bytes que quedan FUERA de R2

- El `checksum` BLAKE3 de 32 B del propio archivo de sector.
- El archivo `.meta` del plotter (versión, `PlottedSector` SCALE con `sector_id`, `s_bucket_sizes`
  y `piece_indexes`); no existe en el prototipo S01, que guarda la metadata en memoria.
- Los `piece_indexes` (qué pieza del historial se ploteó en cada offset). La pertenencia de la
  pieza al historial la comprueba el verificador PoAS real por otra vía (KZG + `derive_piece_index`).
- El `s_bucket_sizes` explícito: el mapa ya determina qué chunks se usaron, y `n` fija la
  cardinalidad; R2 no lleva la lista de tamaños por separado.
- Cualquier dato de versión del *plotter* (la versión de Autonomys). `0x01` es la versión del
  **formato R2 de S01**, no la del plot.

---

## 6. Apertura

La orden la define como `(chunk_location, camino Merkle)` más los dos digests que transporta. La
estructura usada en el prototipo es:

| Campo | Bytes | Nota |
|---|---:|---|
| `chunk_location` | 4 | posición global `i` |
| `camino` | `32 · log2(next_pow2(n))` | hermanos de abajo arriba |
| `codificado` | 1 | la orden fija `1` |
| `raiz_chunks` | 32 | redundante; el camino debe reproducirla |
| `digest_mapa` | 32 | `H_d(TAG_MAPA, bytes del mapa)` |
| `digest_meta` | 32 | `H_d(TAG_META, bytes de meta)` |
| `s_bucket` | 2 | redundante; se coteja con el contexto |
| `piece_offset` | 2 | redundante; se coteja con la solución |

Tamaño = `4 + 32·log2(m) + 1 + 32 + 32 + 32 + 2 + 2`. Para `p = 2` (`m = 2^16`) son **617 B**;
para `p = 3` (`m = 2^17`) **649 B**; para `p = 4` (`m = 2^17`) **649 B**.

### Verificación (pasos exactos)

1. `public_key`, `sector_index`, `history_size` de la solución = los comprometidos, si no
   `ClaveDistinta` / `SectorDistinto` / `HistoriaDistinta`.
2. `apertura.piece_offset` = `piece_offset` de la solución (`PieceOffsetDistinto`).
3. `apertura.s_bucket` = `s_bucket` auditado por el contexto (`SBucketDistinto`).
4. `apertura.codificado == 1` (`CodificadoNoUno`).
5. `n = pieces_in_sector · NUM_CHUNKS` y `chunk_location < n`
   (`IncoherenciaCardinalidad` / `ChunkLocationFueraDeRango`).
6. `chunk_almacenado = chunk XOR proof_of_space.hash()` (director: `subspace-verification/src/lib.rs:248-249`).
7. `hoja = H_d(TAG_HOJA, s_bucket ‖ piece_offset ‖ 1 ‖ chunk_almacenado)`.
8. El camino debe dar `apertura.raiz_chunks` con longitud `log2(next_pow2(n))`
   (`CaminoLongitudInvalida` / `CaminoNoCoincide`).
9. Recomputar `R2` con los campos públicos y `digest_mapa`, `digest_meta`, `raiz_chunks`; debe
   coincidir con la R2 comprometida (`R2NoCoincide`).

La verificación PoAS real (`verify_solution::<ChiaTable,_>`) es **previa y separada**: una apertura
válida no sustituye la comprobación de la prueba de espacio ni de KZG.

---

## 7. Volcado para el oráculo

Archivo binario `sector-P<p>.dump`:

| Campo | Bytes |
|---|---:|
| `magic` = `ZZKS01D1` | 8 |
| `version_dump` = `1` u32 | 4 |
| `CBID` u32 | 4 |
| `public_key` | 32 |
| `sector_index` u16 | 2 |
| `history_size` u64 | 8 |
| `pieces_in_sector` u16 | 2 |
| `sector_bytes_len` u64 | 8 |
| `sector` (archivo completo tal cual) | `sector_bytes_len` |

El oráculo **no** recibe `raiz_chunks`, `R2` ni los digests: los recalcula desde `sector` y los
campos de identidad. Deriva `mapa_size`, `chunks_size` y `meta_size` de `pieces_in_sector` y
`sector_bytes_len`.

---

## 8. Parámetros de test (no de red)

| Parámetro | Valor | Origen |
|---|---|---|
| `sector_index` | 2 | fixture `farmer_disco.rs` |
| `public_key` | `PublicKey::default()` (32 B a cero) | fixture |
| `history_size` | 1 | fixture |
| `recent_segments` | 5 | fixture |
| `recent_history_fraction` | `(1, 10)` | fixture |
| `min_sector_lifetime` | 4 | fixture |
| `max_pieces_in_sector` | = `pieces_in_sector` | **elegido por S01** para poder medir 2, 3 y 4 piezas |
| `pieces_in_sector` | 2, 3, 4 | medición §6 |
| `rango` | `u64::MAX` | fixture (`RANGO_PRUEBA`) |
| `salida` de PoT | `[13u8; 16]` | fixture (`SALIDA_D2`) |
| `CBID` | `0xc478_80ea` | valor de test de `zx-core`/`zx-consensus`, declarado |
| semilla del archivo determinista | `0x9E37_79B9_7F4A_7C15` (splitmix64) | fixture |
| hilos | 8 (`RAYON_NUM_THREADS=8`) | presupuesto de la orden |
