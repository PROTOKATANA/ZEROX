# INFORME — Oráculo de vectores de la cabecera DAG (H-08a)

**Categoría:** criptografía (codificación canónica y hashes); secundaria: consenso.
**Modelo:** `SPEC.md` §2.2, §3, §4.2, §4.4, §6.1–6.2.
**Lenguaje:** Julia CPU, stdlib `SHA` (SHA3-256 FIPS 202). Sin dependencias externas.
**Presupuesto:** < 1 GiB de RAM, 1 hilo, < 1 MiB de disco. No se agota.

## Por qué es un oráculo y no un test más

Los vectores congelados en Rust los generó la propia implementación. Este programa **recomputa los
mismos vectores desde el SPEC**, en otro lenguaje, y el test
`crates/zx-core/tests/oraculo_julia.rs` compara ambos. Si el orden de un campo estuviera mal en
Rust desde el principio, el vector lo habría congelado y el test habría pasado para siempre; contra
este oráculo, no.

## Qué calcula

Escenario determinista idéntico al de `vectores_dag.rs`: rama `0xc47880ea`, `P = 2`, dos
transacciones (coinbase + gasto), sello de 64 ceros. Calcula, en este orden:

1. `txid` de cada transacción (árbol §4.2: header, prevouts, sequence, inputs, outputs).
2. `auth_digest` de cada testigo (§4.4).
3. `merkle_root` (§6.3) y `body_commitment` (nota de §6.1).
4. Los 621 bytes canónicos de la cabecera DAG.
5. `pre_hash` (SHA3-256 de `"ZZKBlkPreHash___" ‖ prefirma`).
6. `block_hash` (SHA3-256 de `"ZZKBlkHeader____" ‖ cabecera`).

## Validación

- **Ancla del oráculo:** `sha3_256("")` debe ser
  `a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a` (vector NIST/FIPS 202). Si
  Julia no fuera SHA3-256 FIPS 202, el oráculo aborta.
- **Estructura:** el wire debe medir exactamente 621 B para `P = 2`.
- **Comparación:** `oraculo_julia.rs` compara los 10 valores contra la implementación Rust.

## Resultado

**Coincidencia byte a byte, sin discrepancia.** `pre_hash`, `block_hash` y `body_commitment`
reproducen exactamente los vectores congelados de Rust, y el `wire` completo coincide.

## Reproducir

```bash
cd implementacion-02/lineo/vectores-cabecera-dag
JULIA_DEPOT_PATH=/home/katana/zeo/ZEROX/deepseek/cabecera-dag-v1/implementacion-02/lineo/.depot \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl
```

Julia se ejecuta con `env -u LD_LIBRARY_PATH` vía `veritas/julia.sh`, como exige LINEO. El depot
está dentro de `implementacion-02/lineo/.depot`, así que no se escribe en `~/.julia` ni en `/tmp`.

## Límites declarados

- No verifica firmas ni PoT: el sello son 64 ceros.
- No es un benchmark; no mide rendimiento.
- Un solo escenario; no barre parámetros.
