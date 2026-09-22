# Vectores de la propuesta P-POT

Crate mínimo que genera los vectores V1–V5 de `../PROPUESTA-SPEC.md` §5. Depende de
`pot-estable` por ruta (sin reimplementar nada) y ejecuta solo `N = 16` iteraciones por slot:
nada pesado.

## Regeneración (fuera de la máquina compartida con P-2.1, ligero)

```bash
CARGO_TARGET_DIR=/tmp/opencode/ppot-target cargo run --release --offline -j 2 \
  --manifest-path P-POT/propuesta/vectores/Cargo.toml > P-POT/propuesta/vectores/vectores.txt

CARGO_TARGET_DIR=/tmp/opencode/ppot-target cargo test --release --offline -j 2 \
  --manifest-path P-POT/propuesta/vectores/Cargo.toml
```

Salida determinista: blake3 y AES son funciones puras de las semillas fijas. El test compara
los valores recalculados contra las constantes capturadas el 2026-09-19.

## Límites declarados

- **V1/V2** fijan la **forma** del encadenado y de la inyección con `N` mínimo; no sustituyen
  los 32 vectores diferenciales de `pot-estable` (N grande, byte a byte contra Autonomys),
  que siguen siendo la validación externa del AES.
- **V5** cubre el rechazo de la primitiva (`NotMultipleOfCheckpoints`); los casos
  `N = 0` y `N > u32::MAX` no se pueden construir como `NonZeroU32` y corresponden a la
  proyección `u64 → NonZeroU32` del verificador (C-POT-04), no de la primitiva.
- **V6** (caché con clave contextual, C-POT-07) no es un vector criptográfico sino de
  comportamiento del verificador; no se genera aquí.
- **D-1 decidida por Katana el 2026-09-19 (opción A, blake3):** estos vectores quedan
  conformes; si algún día se cambiara a `H_d`, dejarían de valer y se regenerarían con las
  etiquetas nuevas.
