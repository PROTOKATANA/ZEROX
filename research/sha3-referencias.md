# SHA-3 — implementaciones de referencia y vectores · agente zx-implementaciones, 2026-09-04

> Material descargado y verificado en `/tmp/zx-sha3/`. Todo con repo@commit y ruta:línea.

## 1 · XKCP — referencia del equipo Keccak (el modelo para el kernel GPU)

`XKCP/XKCP @ eb5244d6b95fb1c434b211bac293093e18aa8fd1` (2026-07-06)

**No hay "función de padding"**: es un byte `delimitedSuffix` XOReado en el estado en la posición
actual + un `0x80` fijo XOReado en `rate-1`. Núcleo (5 líneas), de
`Standalone/CompactFIPS202/C/Keccak-readable-and-compact.c:283-331` (esponja completa en ~50 líneas,
**modelo directo para un kernel GPU**):

```c
state[blockSize] ^= delimitedSuffix;                 // 0x06 para SHA3-*
if (((delimitedSuffix & 0x80) != 0) && (blockSize == (rateInBytes-1)))
    KeccakF1600_StatePermute(state);                 // rama INALCANZABLE con entrada byte-alineada
state[rateInBytes-1] ^= 0x80;
KeccakF1600_StatePermute(state);
```

- `SHA3_256(...)` = `KeccakWidth1600_Sponge(1088, 512, input, inputByteLen, 0x06, output, 32)` — `SimpleFIPS202.c:35-38`.
- `SnP_AddByte` es **XOR, no copia** (`KeccakP-1600-reference.c:153`), por eso el pad se "suma" sobre el bloque parcial.
- **ZEROX no necesita la rama `suffix >= 0x80`** (siempre hashea bytes).
- ⚠️ `SpongeSqueeze` aplica `0x01` (Keccak) por defecto si nadie hizo el pad (`KeccakSponge.inc:256`). Trampa al usar la API de bajo nivel.
- **Valores intermedios para depurar**: `tests/TestVectors/KeccakSpongeIntermediateValues_SHA3-256.txt` (bloque padded literal `06 00…00 80`, 0x80 en byte 135, + estado tras permutar) y `KeccakF-1600-IntermediateValues.txt` (estado tras cada ronda).
- Agente compiló CompactFIPS202 (`gcc -O2`) → **237/237 vectores CAVP byte SHA3-256, 0 discrepancias**. Binario: `/tmp/zx-sha3/oracle/sha3ref`.

## 2 · crate `sha3` 0.12.0 (el que pinea ZEROX)

- Constantes: `KECCAK_PAD = 0x01`, `SHA3_PAD = 0x06` — `sha3-0.12.0/src/lib.rs:142-143`.
- Padding sobre palabras u64: `state[pos/8] ^= PAD << (8*(pos%8)); state[RATE/8-1] ^= 1<<63` — `utils.rs:13-15`.
- Absorción multi-bloque en `sponge-cursor 0.1.0` (`src/lib.rs:91-136`): rellena el bloque en curso, permuta, `chunks_exact(RATE)` permutando tras cada uno, cola parcial con `pos = tail.len()`, `pos < RATE` siempre.
- Verificado: `sha3` 0.12.0 **y** 0.10.8 → 237 CAVP + 100 Monte, **0 mismatches**. `cargo test` del crate: 9 KAT + 9 serialization, verdes.

### ⚠️ Dos hallazgos que afectan a ZEROX

**H-002 · Pinear `sha3 = "=0.12.0"` NO pinea la permutación.** `sha3` 0.12.0 declara
`keccak = "0.2"` y `sponge-cursor = "0.1"` como **rangos**. Cargo resolvió `keccak 0.2.2`, cuyo
backend soft es un fichero DIFERENTE al de 0.2.0 (0.2.2 quitó el unrolling manual, cambió
`truncate_rc` por `const RC`).
→ **Mitigación aplicada:** `Cargo.lock` se versiona (fuera de `.gitignore`), CI corre con `--locked`.
El lock es la fuente de verdad del árbol transitivo consensus-critical.

**H-003 · Dispatch en tiempo de ejecución.** En aarch64, `keccak 0.2.2` despacha a un backend con
la extensión ISA `sha3` (`keccak-0.2.2/src/lib.rs:59-92`); en x86 hay SIMD por cfg. La ruta que
ejecuta la permutación depende de target y CPU. Funcionalmente equivalentes (todos pasan CAVP y
`keccak/tests/parallel.rs` testea vectorizado vs escalar), pero la reproducibilidad del binario
cambia. Para ZEROX: no es divergencia de hash, es de binario; el `--locked` + tests de paridad lo cubren.

- ⚠️ Los KAT del crate (`tests/data/sha3_256_kat.blb`, 256 vectores) **NO son los del NIST** — origen no documentado (desde el primer commit, 2016). Correctos (verificados contra XKCP) pero si el SPEC dice "validado con los KAT del NIST", el crate solo no lo da.

## 3 · Implementaciones GPU

| Proyecto | Qué es | Padding | Notas |
|---|---|---|---|
| **hashcat** m17400 | SHA3-256 real, 1 fuente → CUDA/HIP/OpenCL/Metal | host pone `0x06` en `pw[pw_len]`; `0x80` = lane fija `a31 = 0x8000000000000000` (byte 135) | 1 bloque, `pw_len ≤ 63`. Corre en AMD vía **hiprtc**. `hc_rotl64` distinto por backend. Self-test KAT por backend en cada arranque |
| **ccminer** `cuda_keccak256.cu` | el kernel minero más copiado | **todo precomputado en host**, hardcoded a cabecera de 80 B; midstate (1ª ronda parcial); última ronda truncada a 4 lanes | ⚠️ usa **`0x01`** = Keccak-256 legacy, NO SHA-3. Agente verificó que la receta pasa a SHA-3 con `0x01→0x06` (`/tmp/zx-sha3/oracle/minerpad`) |
| **JtR** `opencl_keccak.h` | Keccak genérico multi-bloque en OpenCL | **dentro** del kernel, rate+delim como params | Para CPU, JtR **importa XKCP tal cual** → precedente de "adoptar, no reescribir" |

**No se encontró ninguna implementación HIP nativa reputada de Keccak/SHA-3 en abierto.** Los mineros AMD con kernel HIP propio (SRBMiner, lolMiner, TeamRedMiner) son cerrados. hashcat (vía hiprtc) es el único candidato inspeccionable.

## 4 · Paridad CPU-verify ↔ GPU-mine — 3 mecanismos reales, ninguno es un test unitario "hash CPU == hash GPU"

| Proyecto | Mecanismo |
|---|---|
| **ccminer** | "la GPU propone, la CPU dispone": el kernel devuelve nonces candidatos, el host los **re-hashea con una lib CPU independiente (sphlib)** antes de aceptar. Runtime, permanente. Differential testing de facto por share. `keccak256.cu:112-143` |
| **hashcat** | KAT self-test **por backend** en cada arranque (`selftest.c:1203`) + differential offline contra `Digest::SHA3` (Perl) en `test.pl` |
| **JtR** | arrays `tests[]` del formato, corridos por `--test` contra el kernel real |
| análogo intra-CPU más limpio | `keccak-0.2.2/tests/parallel.rs:10-26` — backend vectorizado vs escalar sobre el mismo estado, compara arrays completos |

**El hueco "test unitario hash CPU == hash GPU sobre N entradas aleatorias" es de ZEROX.** Coincide con lo que dijo zx-d12: la suite `zx-hash-parity` hay que construirla.

## 5 · Vectores en disco (`/tmp/zx-sha3/`)

```
nist/sha-3bytetestvectors/SHA3_256ShortMsg.rsp   137 (0..136 B)
nist/sha-3bytetestvectors/SHA3_256LongMsg.rsp    100 (273..13836 B)
nist/sha-3bytetestvectors/SHA3_256Monte.rsp      seed + 100 counts (cadena ×1000/count)
nist/sha-3bittestvectors/                        versión bit-level (ZEROX no la necesita)
xkcp/tests/TestVectors/ShortMsgKAT_SHA3-256.txt  2048 bit-level
xkcp/tests/TestVectors/KeccakSpongeIntermediateValues_SHA3-256.txt   ← para depurar el kernel
xkcp/tests/TestVectors/KeccakF-1600-IntermediateValues.txt          ← estado tras cada ronda
btc/src/test/crypto_tests.cpp:1132-1193          57 CAVP inline + checksum 262144×KeccakF = 5f4a7f2eca7d57740ef9f1a077b4fc67328092ec62620447fe27ad8ed5f7e34f
hashcat/src/modules/module_17400.c:30            SHA3-256("hashcat") = d60fcf6585da4e17224f58858970f0ed5ab042c3916b76b0b828e62eaf636cbd
```

Arneses reutilizables dejados montados: `/tmp/zx-sha3/oracle/sha3ref`, `/tmp/zx-sha3/oracle/minerpad`,
`/tmp/zx-sha3/run_cavp.py` (C), `/tmp/zx-sha3/cavp-rs/` (Rust, ShortMsg+LongMsg+Monte).

URLs CAVP (HTTP 200): `https://csrc.nist.gov/CSRC/media/Projects/Cryptographic-Algorithm-Validation-Program/documents/sha3/sha-3bytetestvectors.zip`

## 6 · Divergencia clave

**D1 · La constante de dominio.** SHA3-* = `0x06` · Keccak legacy = `0x01` · SHAKE = `0x1F`.
Idéntico en XKCP, crate `sha3`, Bitcoin Core, JtR, hashcat. **Pero ccminer usa `0x01`** — el kernel
minero más copiado del ecosistema da Keccak, no SHA-3. Copiarlo tal cual reintroduce H-001.

## Lagunas
- No se ejecutó ningún kernel GPU (no hay ROCm; `caliza` no compila). §3 es lectura estática + simulación CPU del padding (esa sí verificada).
- No se ejecutó la suite completa de XKCP (falta `xsltproc`); solo CompactFIPS202.
- No se comprobó qué versión de `sha3`/`keccak` pinean Zebra/orchard/librustzcash (posible doble versión de `keccak` en el árbol).
