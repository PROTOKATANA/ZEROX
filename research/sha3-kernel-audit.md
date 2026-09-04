# Auditoría del kernel SHA-3 de `caliza` — agente zx-d12, 2026-09-04

> Método: emulación fiel línea a línea en Python (`/tmp/.../scratchpad/d12/*.py`) — no hay ROCm
> en la máquina y `caliza` no compila (deps privadas). Todo verificado contra FIPS 202 transcrito
> desde los Algoritmos 1-11 y contra los 860 vectores CAVP del NIST.

## Veredicto

`sha3.h` **NO implementa SHA3-256, ni Keccak-256, ni ninguna función hash estándar.**
Implementa correctamente la permutación `KECCAK-p[1600,24]` y la envuelve en algo que **no es la
construcción esponja**: `salida = Trunc₁₂₈(KECCAK-p[1600,24](M || 0*))`. La permutación es impecable;
el modo de operación no existe.

## CONFORME (lo salvable)

| Elemento | Evidencia |
|---|---|
| Permutación KECCAK-p[1600,24] | `sha3.h:61-97` — 5/5 estados aleatorios idénticos a la norma transcrita |
| `RC[24]`, `r[24]`, `piln[24]` | `sha3.h:11-33` — 24/24 derivadas del LFSR del Algorithm 5, no copiadas |
| Rates `TASA` = 18/17/13/9 palabras | `excavadora.cc:221-227` — = 144/136/104/72 B = r de FIPS 202 ✓ |
| Volcado lane→bytes little-endian | `sha3.h:109` `(k >> (j*8)) & 0xFF` — coincide con FIPS 202 y con crate `sha3` |

## NO CONFORME

| # | Hallazgo | Código | Severidad |
|---|---|---|---|
| 1 | **No existe padding.** Ni 0x06, ni 0x01, ni 0x80 final. La esponja se llena con `esponja[i] ^= saje[i]` y se permuta directo. `kernel("") = e7dde140…` — no coincide con SHA3-256("")=a7ffc6f8… ni con Keccak-256("")=c5d24601… | `sha3.h:53-55` | rompe-consenso |
| 2 | **Colisiones triviales** — la longitud no entra en el hash. `kernel("a"+7×0x00)` == `kernel("a"+15×0x00)`. Cualquier par que rellene a las mismas palabras de 64 bits colisiona | `sha3.h:55` | rompe-consenso |
| 3 | **`talla` recibe `TASA` (rate en palabras), no el digest size.** `excavadora.cc:87` pasa `TASA`∈{18,17,13,9} al 5º arg `talla`. Pero `excavadora.cc:219 switch(talla*8)` lo trata como bytes. SHA3-512 devuelve 9 bytes. Ningún caso produce el digest correcto | `sha3.h:45` + `excavadora.cc:87,219` | rompe-consenso + UB |
| 4 | **Memoria sin inicializar en el digest publicado.** `exudacion[32]` sin init, escribe 16 B, copia 17+. `HIPMALLOC<uint8_t>(talla)`=32 B sin init → todo se serializa a Cap'n Proto (`mineria.cc:35`). Si ningún hilo gana, `hash`/`nonce` nunca se escriben y se devuelve basura sin señal de fallo | `sha3.h:101,103,119` + `excavadora.cc:153,191` | UB + rompe-consenso |
| 5 | **OOB read en `exudacion[32]` vía `secuencia`.** `secuencia` uint8_t sin validar, `for (i<secuencia)`. `secuencia=40` → lee `exudacion[32..39]`. La hipótesis original (overflow por `talla`=48/64) **DESCARTADA** — `talla` vale 13/9, no 48/64. El overflow entra por otra puerta | `sha3.h:115` | UB |
| 6 | **Absorción de un bloque sin bucle de rate; escritura fuera de `esponja[25]`.** `sizesaje=30` → escribe `esponja[25..29]`. `sizesaje≥256` → `uint8_t i` desborda, **bucle infinito (cuelgue GPU)**. `excavadora.cc:55` copia sizesaje palabras en `uint64_t saje[TASA]` → desbordamiento de pila del hilo si sizesaje > TASA | `sha3.h:55`, `excavadora.cc:43,55` | UB |
| 7 | **Nonce en offset fijo (bytes 48..55).** Si `sizesaje < 7`, la absorción nunca toca la palabra 6 → todos los hilos calculan el mismo hash. Minería degenerada, 0 entropía | `excavadora.cc:73-85` | incorrección / rompe-consenso si la cabecera ZEROX acaba <56 B |
| 8 | **Divergencia CPU↔GPU.** El crate `sha3::Sha3_256` **SÍ es SHA3-256 FIPS 202** (validado 860/860 CAVP). Pero `minero.rs` concatena `u128::to_le_bytes()` (16 B) al final del bincode; la GPU mete un u64 en el byte 48. **Preimágenes distintas** | `minero.rs:19,157` vs `excavadora.cc:73` | rompe-consenso |
| 9 | **860 CAVP contra el kernel: 0 aciertos**, 799 ni expresables (solo acepta múltiplos de 8 B que quepan en un bloque) | — | rompe-consenso |

## Chequeo de dificultad

Contar bytes cero (`secuencia`) tiene granularidad de **8 bits** → salto de dificultad ×256 entre
escalones. **Incompatible con LWMA-1 por bloque** (ajuste fino, aquí no hay nada que ajustar).
→ Pasar a comparación de **target de 256 bits big-endian sobre el digest completo**. El mismo
comparador exacto debe existir en el nodo Rust: es regla de consenso tanto como el hash.

## Remedio recomendado (regla del proyecto: adoptar, no reescribir)

1. **CPU / nodo:** `sha3::Sha3_256` (RustCrypto) sin cambios — validado 860/860 CAVP en este informe. Fijar versión + hash del crate en SPEC.md. *(ZEROX ya pinea `sha3 = "=0.12.0"`.)*
2. **GPU:** portar la esponja desde **XKCP** (`lib/low/KeccakP-1600/plain-64bits/`). Son ~40 líneas alrededor de la permutación, que ya funciona. Referencia estructural (NO de la constante de dominio): `ccminer/Algo256/cuda_keccak256.cu`.
3. **Puerta de CI no negociable:** binario `caliza-kat` que corra los 860 `.rsp` de CAVP y **falle el build ante un solo mismatch**. Sin eso, cualquier corrección es otra vez artesanía sin verificar.

## Plan de paridad CPU↔GPU — suite `zx-hash-parity`, 3 capas obligatorias en CI

- **Capa 1 — conformidad absoluta (contra el NIST):** `caliza-kat` (C++/HIP) y `zx-hash-kat` (Rust), 860/860 vectores CAVP para 224/256/384/512, incluidos los Monte Carlo (100k iteraciones encadenadas). Si el kernel se limita a `len ≤ rate−1` byte-alineado, la capa 1 se restringe a ese subconjunto **documentado en SPEC.md**, nunca por accidente.
- **Capa 2 — entradas límite alrededor del rate** (SHA3-256, rate 136 B). Vectores ya generados (esperados = SHA3-256 FIPS 202):
  ```
  len   0  a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a
  len   1  5d53469f20fef4f8eab52b88044ede69c77a6a68a60728609fc4a65ff531e7d0
  len 135  fded8fd9d6551c601eeb3b7c6bc5e5cfd8aad1d015b7e9aaa9c9b9475231d5e2  (rate−1: pad 1 B → 0x86)
  len 136  cf3ccff92480a29160c2d38317c430e14749bfee1788106957dfe73f8c4930e5  (rate exacto: bloque de pad entero)
  len 137  9ed57188470a83b758cd71c00c6cc3beb984b36a6c35864b4e53017b24cf5699  (rate+1: dos bloques)
  len 272  0b21ec4a8eff6d179e09ba9fe0ab08515b24e0923fbf419f5c30a38e64577db5  (2×rate)
  len 273  6e7f5de2677213044468ef21d3c8c57bb10cc5957e4f99d038db65ac3151e9c1
  len  80  4b895fbf6a1c27109c165d8420751f31aec536824441d4e65fac9fd1bd34ba23  ('Z'×80)
  ```
  Repetir para 224/384/512 con len ∈ {0,1,r−2,r−1,r,r+1,2r−1,2r,2r+1}. Cada vector con su gemelo Keccak-256 (0x01) como **trampa**.
- **Capa 3 — paridad de la ruta de minería completa.** Misma cabecera serializada + mismo nonce → mismo digest en CPU y GPU. Requiere fijar antes en SPEC.md: (a) offset y ancho del nonce en la preimagen; (b) el empaquetado byte→uint64_t little-endian que la absorción GPU asume; (c) el comparador de target de 256 bits idéntico en ambos lados. Fuzzing diferencial 10⁶ cabeceras × nonces, tolerancia CERO. `compute-sanitizer` / `-fsanitize=address` una pasada.

## No verificado (requiere hardware) — riesgos de consenso abiertos

- El kernel en GPU real.
- **`__constant__ static const` con inicializador en cabecera: ¿igual en hipcc-AMD y nvcc-NVIDIA?** Si en una ruta las tablas quedan a cero en memoria de dispositivo, el hash cambia sin aviso. *Mismo código, dos GPUs, dos cadenas.* → tarea para D11.
- Flujo de `lanzador()` (`excavadora.cc:131-203`): el `else` de la línea 199 aborta cualquier `dispositivo != 0` en la primera iteración; sin `return` tras el bucle (UB si `device_total == 0`).
- Carrera entre hilos ganadores: escriben `hash` y `nonce` sin sincronización antes del `atomicCAS(bandera)` → el par devuelto puede mezclar dos soluciones.
- Formato final de la cabecera de ZEROX: hasta que exista en SPEC.md no se cierra la capa 3, ni se sabe si la cabecera cabe en un bloque de rate (permitiría mantener el kernel de absorción única).

## Evidencia local
`/tmp/claude-1000/.../scratchpad/d12/` — fips202_from_spec.py, kernel_emu.py, check_consts.py, run_audit.py, run_cavp.py, escenario_real.py, rustcheck/ (cargo: `sha3` v0.10 → 860/860 CAVP)
`/tmp/claude-1000/.../scratchpad/cavp/` — los 860 .rsp descomprimidos
