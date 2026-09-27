# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:00.348
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R3-E6b-3d21b1f-rep2`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2/A/registro.jsonl` | A | v1 | 407 | 0 | `73bb5fb5cf0af0ca8f1fe578ec336f1ec0069b98139e340c0d2edb38b2c6ca2b` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2/B/registro.jsonl` | B | v1 | 393 | 0 | `78c9bd859aade84a24349681039c481dc4d8b177202104ca7abe032d4bf62b4b` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2/C/registro.jsonl` | C | v1 | 391 | 0 | `c58f3915bfcf08a1379a231dbf4d409339a16eb74dfb4d35aac23f4bc2e1947f` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2/recursos-A.csv` | A (recursos) | — | 99 muestras | 0 | `f87467f540257ee5b8bdd2562b7694d205a5558b08a340d157579fd1574eb5b1` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2/recursos-B.csv` | B (recursos) | — | 98 muestras | 0 | `6d3fb9f90ce011bbb083a9c07eaa0254439d2fd6ef4e9eab5df52c10c2363ac1` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2/recursos-C.csv` | C (recursos) | — | 99 muestras | 0 | `e909c4bdef82b26b95e3367198fe5cf21de1325d153f08b8b8c73c6d1bbdb979` |

## Estado final

- A: `afd1a8d99b9d256956aae25a48e8629ddb302e4cbe151d0e7fccebf640397b28`
- B: `afd1a8d99b9d256956aae25a48e8629ddb302e4cbe151d0e7fccebf640397b28`
- C: `afd1a8d99b9d256956aae25a48e8629ddb302e4cbe151d0e7fccebf640397b28`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.471867
- **Episodios:** 6 (0 sin reconverger antes del fin)

## Hallazgos (W07c-B: bloques contados una vez por `hash`)

- `slot_distinto_por_bloque`: 0 (bloques cuyo slot difiere entre sus eventos)
- `padres_distintos_por_bloque`: 0 (bloques cuyo n_padres difiere entre sus eventos)
- `mergeset_distinto_por_bloque`: 0 (bloques cuyo par (azules,rojos) difiere entre sus eventos)
- `eventos_bloque_sin_hash`: 0 (eventos bloque_producido/bloque_red_admitido sin hash (no identificables))

## Métricas sin muestras en esta ejecución

- `arranque_ns` (todos): sin muestras.

## Notas de definición (ver `FALTAS-DE-DEFINICION.md`)

- Percentiles nearest-rank en enteros: rango = ceil(p·n/100); sin interpolación ni `Float64`.
- Bloques por slot / padres por bloque / fracción de rojos: un bloque cuenta una vez por `hash`; `bloques_por_slot` cubre todos los slots de `[mín,máx]`, vacíos incluidos (W07c-B).
- Latencia: producción más temprana de A y admisión más temprana de B por hash; las negativas entran y se cuentan.
- Divergencia: barrido O(E log E) sobre `cambio_punta`; episodios no reconvergidos marcados `truncada=1`.
- Recursos: diferencias entre muestras; `CLK_TCK` de `EJECUCION.txt` o 100 por defecto.
