# INFORME.md — oráculo Julia de formatos v0 (ORDEN-W02)

**Auditoría:** `deepseek/W02/oraculo-formato-v0/`.
**Categoría:** `consenso` (dominante: formatos y `txid` de la red dev del híbrido; secundarias:
`criptografía` por `H_d`/SHA3-256 y mensaje de aceptación). No había categoría más específica en
`LINEO.md` y se declara el motivo.
**Fecha:** 2026-09-26. **Ejecutor:** DeepSeek Harness, `deepseek-flash`, esfuerzo `high`.
**Firma del director:** Claude (`ORDEN-W02`).

## 1. Objetivo y alcance

Producir, **en Julia y aparte del Rust**, los vectores de `FORMATO-v0.md` §§2 y F-12/F-14 que W02
implementa: `H_d`, el árbol del `txid` v1/v2/v3 (F-06), el sub-digest de la extensión
(`ZZKTxIdGarantia_`), el mensaje de aceptación (F-08, `ZZKTxSigGarant__`) y la codificación de red
de F-14. El test `crates/zx-core/tests/formato_v0.rs` compara byte a byte.

**No** firma Ed25519, **no** valida contexto (posición de coinbase, saldos, `clave == sol.public_key`)
y **no** sustituye a la máquina de estados de W03.

## 2. Línea de ejecución exacta (reproducible)

```bash
Z=/home/katana/zeo/ZEROX/deepseek/W02
JULIA_DEPOT_PATH="$Z/.julia-depot:" JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  env -u LD_LIBRARY_PATH \
  /home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia \
  --project="$Z/oraculo-formato-v0" --threads=1 \
  "$Z/oraculo-formato-v0/run.jl" --seed 0x5a5a
```

Sin `LD_LIBRARY_PATH` (LINEO §1: puede matar a Julia con las bibliotecas de AOCC). `--threads=1`:
no hay paralelismo que medir; el tope de 24 hilos de la máquina de referencia no se usa porque el
trabajo cabe en microsegundos.

## 3. Entorno capturado

| Elemento | Valor |
|---|---|
| Julia | 1.13.0 (`julia-version.toml`) |
| Binario | `/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia` |
| Hilos | `Threads.nthreads(:default) = 1`, `Threads.nthreads(:interactive) = 1` |
| Dependencias | solo stdlib `SHA` y `Test`; `Manifest.toml` versionado |
| Semilla | `0x5a5a` (argumento obligatorio; el cálculo es determinista, no consume RNG) |
| CPU/RAM | AMD Ryzen 9 9950X3D, 123 GiB (perfil de `LINEO.md` §7). No se midió afinidad: irrelevante para el coste |
| `LD_LIBRARY_PATH` | eliminado del entorno antes de invocar Julia |

## 4. Modelo de coste y tipos numéricos

Cada caso es un recorrido lineal sobre los campos de una transacción: **O(n)** en el número de
entradas, salidas y testigos, con `n` de un dígito en los vectores. La memoria es O(tamaño de la
transacción). No hay reducción de coma flotante, ni aleatoriedad, ni paralelismo: todo es aritmética
entera de anchura fija (`UInt8/16/32/64`, `Int64` en complemento a dos) y hashes SHA3-256 de la
stdlib.

**No se intentó ninguna optimización** (LINEO §2): no hay cuello medible, el resultado es una
igualdad exacta de bytes y una versión «acelerada» no añadiría veracidad. Por eso la tabla de
`LINEO.md` §6 se entrega con una sola variante:

| Variante | Tiempo mediano | Asignaciones | Hilos/backend | Resultado frente a referencia |
|---|---:|---:|---|---|
| Referencia (`referencia.jl`) | ~milisegundos de cómputo tras el arranque | no medidas (irrelevante) | 1 CPU, stdlib | es la fuente de verdad; validada contra NIST y 3 `txid` v1 antiguos |

No se publica una cifra de «veces más rápido» porque no hay dos implementaciones que comparar.

## 5. Validación del propio oráculo (antes de creerle un vector)

`test/runtests.jl` (se ejecuta con `Pkg.test()`, paso V4) comprueba:

- **(a)** `SHA3-256("")` = `a7ffc6f8…8434a` (vector NIST/FIPS 202, H-001).
- **(b)** tres `txid` v1 **antiguos**, de los tests de `zx-core`:
  - `txid1 = 2c0c8801…432c` y `txid2 = cc22d38f…5f5b`, congelados en
    `testdata/vectores-cabecera-dag/vectores.txt` y citados por `tests/oraculo_julia.rs` y
    `tests/vectores_dag.rs`;
  - `txid_v1_antiguo_3 = c722c4f8…3bc6`, del escenario `tx_ejemplo()` de los tests unitarios de
    `crates/zx-core/src/preimage/tx.rs`, congelado con el código antiguo (commit `29b6bd6`) antes
    de tocar `zx-core` y reproducido aquí desde el SPEC. **Hallazgo:** solo existían dos `txid` v1
    congelados como literales; el tercero se tomó de ese escenario ya presente en los tests.
- **(c)** `CBID_RED_DEV` y `MAGIC_DEV` recalculados de su fórmula (F-12, C-NET-01).

## 6. Artefacto generado

`testdata/formato-v0/vectores.txt`: 14 casos (`≥ 12` exigidos) — v1 transferencia, v1 coinbase PoW,
v2 depósito (1 y 3 entradas, con y sin cambio), v2 retiro, v2 liberación y v3 coinbase PoST — con
`CBID_RED_DEV` (`a8b466a7`) y con otro `CBID` (`0x01020304`). Cada línea `caso` lleva: nombre,
versión, `CBID`, `tipo` (o `-`), bytes de red en hex, `txid` y mensaje de aceptación (o `-`). El
fichero se copia sin editar a `ws/testdata/formato-v0/vectores.txt`.

## 7. Presupuesto declarado y uso

Presupuesto (LINEO §7): ≤ 10 min de reloj, 1 hilo, 1 GiB de RAM, 1 GiB de disco temporal. Uso real:
≈ 5 s incluyendo `Pkg.instantiate()` en un depot vacío, sin tensión de memoria ni disco. Si el
presupuesto se hubiera agotado, el estado habría sido **inconcluso** con el último vector válido.

## 8. Lo que este oráculo NO demuestra

- No prueba la firma de aceptación (los testigos son bytes fijos); eso lo comprueba Rust con
  `ed25519-zebra`.
- No prueba reglas contextuales (posición de la coinbase, saldos, madurez, `clave == sol.public_key`).
- No cubre el peso (`C-WGT-02`) ni el génesis (F-13).
- No demuestra que Rust sea correcto: solo que **coincide** con una segunda implementación escrita
  desde la especificación. Una especificación ambigua haría coincidir a las dos en el mismo error.
