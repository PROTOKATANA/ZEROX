# RESUMEN.md — coste por salto (Q4), opción descartada y matriz KZG (Corrección 1)

Etiquetas de procedencia: **MH** = medido en este hardware (media de lote 1 y lote 2,
separados ≥30 min — 21:54:33 → 22:24:52 —, todas las diferencias de mediana <5 %,
máxima observada −2,85 %); **D** = suma o producto derivado de valores MH.

Metodología, controles, ENTORNO, CSV crudo y matriz KZG cruda: ver `README.md`,
`CONTROLES.txt`, `ENTORNO.txt`, `MEDICIONES.csv`, `kzg-parallel.csv`, `kzg-opt-s.csv`,
`kzg-ambas.csv`, `perf-A.txt`, `perf-G.txt` y `REGISTRO.log` en este mismo directorio.
Ver también `BITACORA.md` §«Corrección 1» para el porqué de cada cambio.

## 1. Medianas por operación (MH, media lote1/lote2, ns) — TODAS las operaciones

| Op | lote 1 | lote 2 | dif % | media (ns) |
|---|---:|---:|---:|---:|
| A (verify_solution completa) | 1 195 847 | 1 192 537 | −0,28 % | 1 194 192 |
| B-pos (PoS sola K=20) | 9 030 | 9 070 | +0,44 % | 9 050 |
| B-kzg (chunk, NUM_S_BUCKETS) | 584 079 | 583 738 | −0,06 % | 583 909 |
| B-kzg-hist (parámetros históricos) | 585 659 | 584 239 | −0,24 % | 584 949 |
| C (sello Ed25519, 492 B) | 15 190 | 15 209 | +0,13 % | 15 200 |
| D-92 (block_hash cabecera, control) | 216 | 216 | 0,00 % | 216 |
| D-556 (H_d réplica, base PoAS) | 1 010 | 998 | −1,19 % | 1 004 |
| E-571 (merkle_root, 571 txids) | 122 728 | 122 827 | +0,08 % | 122 778 |
| E-4464 (merkle_root, 4 464 txids) | 954 862 | 955 572 | +0,07 % | 955 217 |
| F-1 (justificación PoT vs caché, 1 slot) | 1 | 1 | 0,00 % | 1 |
| F-150 (justificación PoT vs caché, 150 slots) | 232 | 231 | −0,43 % | 232 |
| H-571 (decode+txid, 571 tx) | 980 921 | 987 711 | +0,69 % | 984 316 |
| H-4464 (decode+txid, 4 464 tx) | 7 716 373 | 7 673 304 | −0,56 % | 7 694 839 |
| H-txid-571 (solo txid, 571 tx) | 931 162 | 924 862 | −0,68 % | 928 012 |
| H-txid-4464 (solo txid, 4 464 tx) | 7 307 061 | 7 240 522 | −0,91 % | 7 273 792 |
| G avx512f_vaes (1 slot) | 93 429 647 | 90 763 559 | −2,85 % | 92 096 603 |
| G avx2_vaes (1 slot) | 101 434 065 | 101 319 428 | −0,11 % | 101 376 747 |
| G aes_sse41 (1 slot) | 190 584 484 | 190 410 608 | −0,09 % | 190 497 546 |
| G crate-aes (1 slot, AES-NI vía crate `aes`) | 944 322 284 | 947 487 237 | +0,34 % | 945 904 761 |
| G aes-soft (1 slot, software real) | 8 288 119 751 | 8 340 044 967 | +0,63 % | 8 314 082 359 |

Control D: réplica `H_d` (sha3 0.12.0) sobre la cabecera de 92 B coincide byte a byte
con `zx_core::preimage::block::block_hash` — ver `CONTROLES.txt`. Controles H y
B-kzg-hist (+/−) también en `CONTROLES.txt` y en la salida de cada lote.

## 2. Coste por salto con la decisión Q4, en dos escenarios

**(a) Relé compacto** (R-NET-01: los txid ya se conocen del mempool, el término H es 0
— la suma es la misma que en la primera versión del banco):
`D-556 + A + C + E + F-1`

**(b) Cuerpo completo** (caso degradado: hay que decodificar y calcular los txid de
las transacciones del cuerpo antes de la raíz Merkle — omisión corregida en esta
versión): `D-556 + A + C + E + F-1 + H-N`

| Escenario | Merkle | D-556 | A | C | E | F-1 | H-N | **Total (D)** |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| (a) compacto | 571 | 1 004 | 1 194 192 | 15 200 | 122 778 | 1 | — | **1 333 175 ns ≈ 1,333 ms** |
| (a) compacto | 4 464 | 1 004 | 1 194 192 | 15 200 | 955 217 | 1 | — | **2 165 614 ns ≈ 2,166 ms** |
| (b) completo | 571 | 1 004 | 1 194 192 | 15 200 | 122 778 | 1 | 984 316 | **2 317 491 ns ≈ 2,317 ms** |
| (b) completo | 4 464 | 1 004 | 1 194 192 | 15 200 | 955 217 | 1 | 7 694 839 | **9 860 453 ns ≈ 9,860 ms** |

El escenario (b) con 4 464 tx es el más caro de los cuatro: unas 4,55× el (a) con
4 464 tx, porque decodificar+hashear 4 464 transacciones (H-4464 ≈ 7,69 ms) domina
sobre el resto de la suma (≈2,17 ms).

## 3. Coste de la opción descartada — PoT verificado en cada bloque (D = G × slots)

| Ruta | G · 1 slot (MH) | G · 150 slots (D = ×150) |
|---|---:|---:|
| avx512f_vaes | 92,097 ms | 13 814,5 ms ≈ 13,81 s |
| avx2_vaes | 101,377 ms | 15 206,5 ms ≈ 15,21 s |
| aes_sse41 | 190,498 ms | 28 574,6 ms ≈ 28,57 s |
| crate-aes (AES-NI vía crate `aes`, NO es software — Corrección 1 §1) | 945,905 ms | 141 885,7 ms ≈ 141,89 s |
| **aes-soft (software real, forzado con `--cfg aes_backend="soft"`)** | **8 314,08 ms** | **1 247 112 ms ≈ 20,79 min** |

**Límite obligatorio:** `avx2_vaes`, `aes_sse41`, `crate-aes` y `aes-soft` se midieron
FORZADAS en un Ryzen 9 9950X3D (Zen 5). Ninguna es una predicción del coste en una CPU
sin AVX-512 o sin AES-NI: otra microarquitectura tiene otros puertos AES, decodificación
y frecuencias — ver `pot-estable-rutas/DIFF.md`. `aes-soft` es, además, la ÚNICA de las
cinco que corre software real (fixslicing sin AES-NI); `crate-aes` usa AES-NI por
autodetección del crate `aes` 0.9.3 y por eso está mucho más cerca de las otras tres
rutas con intrínsecos que de `aes-soft` (factor ~90× entre `aes-soft` y `avx512f_vaes`,
frente a ~10× entre `crate-aes` y `avx512f_vaes`).

## 4. Comparación con la sensibilidad de DMS-v0.1 (INFORME §11.5, 0,1 s/salto)

| Opción | Coste | % del presupuesto de 0,1 s | Margen |
|---|---:|---:|---:|
| Q4 (a) compacto, 571 | 1,333 ms | 1,33 % | ≈75× |
| Q4 (a) compacto, 4 464 | 2,166 ms | 2,17 % | ≈46× |
| Q4 (b) completo, 571 | 2,317 ms | 2,32 % | ≈43× |
| Q4 (b) completo, 4 464 | 9,860 ms | 9,86 % | ≈10× |
| Descartada, avx512, 1 slot | 92,097 ms | 92,1 % | ≈1,09× (margen casi nulo) |
| Descartada, avx2/sse41/crate-aes, 1 slot | 101,4–945,9 ms | 101–946 % | **por encima del presupuesto ya en 1 slot** |
| Descartada, aes-soft, 1 slot | 8 314 ms | 8 314 % | 83× el presupuesto |
| Descartada, cualquier ruta, 150 slots | 13,8 s – 20,8 min | 13 800 %–1 247 100 % | 138×–12 471× por encima |

Incluso el escenario (b) más caro (cuerpo completo, 4 464 tx, 9,86 ms) deja **10×** de
margen bajo el presupuesto de 0,1 s; la opción descartada no deja margen ni con la ruta
más rápida y un solo slot.

## 5. Contraste con el ancla (96,1 ms/slot, avx512f_vaes)

- Esta sesión (harness `Instant`, media de 2 lotes separados ≥30 min): **92,097 ms**.
  Diferencia: (92,097 − 96,1) / 96,1 = **−4,17 %**, dentro del 10 % exigido.
- No se repitió el contraste con Criterion (`benches/ancla.rs`): el encargo de
  Corrección 1 no lo pedía («No hace falta repetir el ancla con Criterion»). El
  contraste de la sesión anterior (Corrección 0, mismo instrumento Criterion y semilla
  que el ancla) dio 89,738–89,761 ms, −6,6 % — ambas cifras, la de entonces y la de
  ahora, caen dentro del 10 %; la diferencia entre sesiones (89,7 ms vs 92,1 ms, +2,7 %)
  es coherente con el ruido de máquina compartida ya documentado (ver
  `ENTORNO.txt` §Corrección 1: loadavg 0,8–1,6 durante esta sesión, sin exclusividad
  real de la CPU).

## 6. Matriz KZG — por qué NO se reproducen los 1,0773 ms históricos

`Kzg::verify` (`subspace-kzg/src/lib.rs:788-816`) cachea las FFT settings y su coste
real es `check_proof_single`, que NO depende de `num_values` ni del índice — por eso
`B-kzg` (parámetros del banco de este proyecto) y `B-kzg-hist` (parámetros EXACTOS del
histórico: `RawRecord::NUM_CHUNKS`, índice 0) dan prácticamente el mismo número en
las CUATRO configuraciones:

| Configuración | B-kzg (µs) | B-kzg-hist (µs) | dif. B-kzg vs histórico (1 077,3 µs) |
|---|---:|---:|---:|
| base (`default-features=false`, sin `parallel`, sin `opt-level="s"`) | 583,91 | 584,95 | −45,8 % |
| `parallel` (`subspace-kzg/parallel`) | 584,07 | 584,28 | −45,8 % |
| `opt-level="s"` (rust-kzg-blst + rayon-core, perfil del workspace Autonomys) | 583,88 | 584,67 | −45,8 % |
| `parallel` + `opt-level="s"` (ambas) | 585,09 | 585,72 | −45,7 % |

Las ocho medias caben en una banda de 583,88–585,72 µs (0,31 % de dispersión total,
mucho menor que la diferencia con el histórico).

**Procedencia verificada del 1,0773 ms:** `research/scripts/d12-quorum/salida_bench_kzg.txt`
(2026-09-10), `cargo bench -p subspace-kzg --bench kzg -- verify` corrido DENTRO del
propio workspace de Autonomys (`PDF/autonomys-subspace`, no como crate externo aislado
como este banco) — citado en `research/scripts/d12-quorum/informe.md:601-602` y
`ZEROX-EN-NUMEROS.md`.

**Candidato adicional probado (fuera del alcance formal de 3.3, en respuesta a una
pregunta directa de Katana):** al correr `-p subspace-kzg` dentro de ESE workspace,
Cargo usa el `Cargo.lock` del propio workspace, que pinea `blst = "0.3.16"`
(`PDF/autonomys-subspace/Cargo.lock`, verificado). Este banco, al ser un
`[workspace]` aislado con su propio `Cargo.lock`, resolvió `blst = "0.3.17"` para el
mismo requisito (`rust-kzg-blst` pide `^0.3.11`, ambas versiones lo cumplen). Se
probó forzando `blst = "=0.3.16"` (compilación aparte, offline, diff de `Cargo.lock`
con SOLO ese paquete cambiando de versión): `B-kzg` = 587,2 µs, `B-kzg-hist` = 587,5 µs
— dentro de la misma banda de ruido que las otras cuatro configuraciones. **`blst`
0.3.16 vs 0.3.17 TAMPOCO explica el hueco.** (Prueba revertida tras medir: no forma
parte de las 4 compilaciones oficiales de 3.3.)

**Conclusión: de los tres candidatos probados (`parallel`, `opt-level="s"`, versión de
`blst`), ninguno explica los 1,0773 ms históricos — declarado así, sin forzar el
número.** El banco histórico no se pudo repetir tal cual (Criterion con `plotters` no
resuelve sin red, declarado ya en Corrección 0). Candidatos NO probados que quedan
abiertos: la propia `cargo bench` de Criterion añade overhead de medición distinto al
harness `Instant` (aunque en el contraste del ancla §5 ambos instrumentos coincidieron
dentro de ~3 %, así que es un candidato débil); una CPU, gobernador de frecuencia o
generación de microcódigo distinta en la máquina donde se corrió el histórico (no
declarada en `salida_bench_kzg.txt` ni en `informe.md`); la carga ambiente de esa
máquina en ese momento (tampoco declarada); o que ese `cargo bench` corriera con
otras flags/target-cpu no documentadas en el `informe.md` de `d12-quorum` — no
investigado aquí, fuera del alcance de Corrección 1.

## 7. Recorte ya señalado (Corrección 0, sigue vigente)

Ninguno adicional a lo ya declarado en §6 de esta sección: el hueco de KZG queda sin
explicación medida, y así se deja — no se reconcilia ni se oculta.
