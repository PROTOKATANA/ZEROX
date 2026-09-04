# SHA3-256 — extracto normativo de FIPS 202

> Fuente de investigación para `SPEC.md §<PoW/hash>`. Agente `zx-specs`, 2026-09-04.
> Evidencia local: `/tmp/claude-1000/.../scratchpad/fips/` (fips202.pdf, fips202b.txt, CAVP zips, kec.py).
> FIPS PUB 202 · https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf · publicado agosto 2015.

## Definición

`SHA3-256(M) = KECCAK[512](M || 01, 256)` — FIPS 202 §6.1, p. 20.

- `KECCAK[c] = SPONGE[KECCAK-p[1600,24], pad10*1, 1600 − c]` — §5.2, p. 20.
- `KECCAK-p[1600,24]` = `KECCAK-f[1600]` (24 = 12 + 2·6) — §3.4, p. 17.
- capacity = 2 · digest → c = 512, r = 1600 − 512 = **1088 bits = 136 bytes** para SHA3-256.
- Tabla de rates (derivada de §6.1 + §5.2, confirmada por §7 Tabla 3 y keccak.team):

  | Función | d | c bits | r bits | r bytes |
  |---|---|---|---|---|
  | SHA3-224 | 224 | 448 | 1152 | 144 |
  | **SHA3-256** | **256** | **512** | **1088** | **136** |
  | SHA3-384 | 384 | 768 | 832 | 104 |
  | SHA3-512 | 512 | 1024 | 576 | 72 |

## Sufijo de dominio + padding

1. Orden: `M → N = M || 01 → P = N || pad10*1(r, len(N))` — §6.1 + §4 Alg. 8 paso 1.
2. `pad10*1(x, m)`: `j = (−m − 2) mod x`; devuelve `1 || 0^j || 1`. **Siempre ≥ 2 bits.** §5.1 Alg. 9, p. 19.
3. Forma en bytes (entrada alineada a byte), Apéndice B.2 Tabla 6 (non-normative pero consecuencia obligada):
   - `q = (r/8) − (m mod r/8)`
   - q = 1 → `M || 0x86`
   - q = 2 → `M || 0x06 0x80`
   - q > 2 → `M || 0x06 || 0x00…(q−2)… || 0x80`
   - El `0x06` = sufijo `01` (bits 0,1) + primer `1` de pad10*1 (bit 2) = 2¹+2² . El `0x80` = último `1` en bit 7.
4. Algoritmo 8 (SPONGE) paso 6: `S = f(S ⊕ (P_i || 0^c))` **una invocación de f por bloque de rate**;
   el bloque hace XOR contra los primeros r bits, ceros contra la capacity. Absorber > r bits o no
   invocar f viola este paso.

## Endianness (derivada de Apéndice B.1 + §3.1.2/3.1.3 — FIPS 202 nunca dice "endian")

- Cada lane de 64 bits se empaqueta **little-endian**: `byte[8i+m] = (lane_i >> 8m) & 0xFF`.
- Orden de lanes: `i = x + 5y` (x varía primero).
- Aplica tanto a absorber bloques de rate como a exprimir la salida.
- Verificado: implementación con `int.from_bytes(...,'little')` reproduce 137/137 vectores CAVP
  `SHA3_256ShortMsg.rsp` y coincide con `hashlib.sha3_256`.

## SHA3-256 vs Keccak-256 (Ethereum) — difieren en UN byte

| | SHA3-256 (FIPS 202) | Keccak-256 (Ethereum, submission v3) |
|---|---|---|
| Sufijo de dominio | `01` → primer byte padding **0x06** | ninguno → **0x01** |
| q=1 | 0x86 | 0x81 |
| Todo lo demás (perm, r, c, salida) | idéntico | idéntico |

- `SHA3-256("")` = `a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a`
- `Keccak-256("")` = `c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470`
- Digests **no relacionados**. Ethereum Yellow Paper §3: "as per version 3 of the winning entry
  ... rather than the final SHA-3 specification".

## Vectores de prueba

**Normativos (CAVP)** — solo lo validado por CAVP se considera conforme (§7, p. v):
- `https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/sha3/sha-3bytetestvectors.zip`
- Ficheros: `SHA3_256ShortMsg.rsp`, `SHA3_256LongMsg.rsp`, `SHA3_256Monte.rsp` (+ 224/384/512, + `sha-3bittestvectors.zip`).
- **NO** se llaman `ShortMsgKAT`. En `Len = 0`, `Msg = 00` es relleno, no un byte.

**KAT del concurso (formato `ShortMsgKAT_*.txt`)** — dos familias INCOMPATIBLES con nombres casi iguales:
- XKCP `tests/TestVectors/ShortMsgKAT_SHA3-256.txt` → SHA-3 (0x06). Cabecera: "or SHA3-256 as in FIPS 202 standard".
  Incluye `KeccakSpongeIntermediateValues_SHA3-256.txt` y `KeccakF-1600-IntermediateValues.txt` (útiles para depurar kernel).
- `keccak.team/obsolete/KeccakKAT-3.zip` → `ShortMsgKAT_256.txt` = **Keccak original (0x01), NO SHA-3**.

> ⚠️ Elegir el fichero equivocado como suite de validación produce un kernel que pasa sus tests
> y rompe el consenso. Para ZEROX: usar CAVP + XKCP `ShortMsgKAT_SHA3-256.txt`.

## Lagunas señaladas por el agente

- FIPS 202 no publica tabla explícita de (r, c) por función; se deriva.
- FIPS 202 no usa la palabra "endian"; el little-endian por lane es consecuencia del Apéndice B (non-normative).
- "Keccak-256" no está definido en FIPS 202; su fuente es el Yellow Paper + Keccak Reference 3.0.
- No verificados: vectores Monte Carlo, LongMsg, ni bit-oriented (solo 137 ShortMsg SHA3-256, todos OK).
