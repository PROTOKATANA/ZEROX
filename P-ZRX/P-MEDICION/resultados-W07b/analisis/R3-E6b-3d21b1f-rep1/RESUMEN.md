# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:06.347
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R3-E6b-3d21b1f-rep1`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1/A/registro.jsonl` | A | v1 | 449 | 0 | `c9b0740ba51fb99030271537f7b7c6007e86b0da745be85fc1ccd12143a70ce9` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1/B/registro.jsonl` | B | v1 | 430 | 0 | `a017e9f072aae2ca166e3b87e7323d71ebcf8bd942f86c1d79f656261afb5dfa` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1/C/registro.jsonl` | C | v1 | 442 | 0 | `115485f662ce505503a1b6867bfa0c78bb7c78c1289556e3597656587b150f5d` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1/recursos-A.csv` | A (recursos) | — | 102 muestras | 0 | `5ce5baac28ddbcffaa5bfdcd0753ae4f738342054cd85317a938581c9cac41a3` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1/recursos-B.csv` | B (recursos) | — | 101 muestras | 0 | `bee1c838b5bbb335a8abb56f2fd5705f893702ae87efa7e5f16661435ae8d81e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1/recursos-C.csv` | C (recursos) | — | 102 muestras | 0 | `4f080e50439a442b12b00cf73c64c16428776bcb781a4ca68f8ebaa24445f8b5` |

## Estado final

- A: `9a295d6d9d4f0f062f187cc6bf00ec5bf6f2067584d1f09cdcea35ad2e254cee`
- B: `9a295d6d9d4f0f062f187cc6bf00ec5bf6f2067584d1f09cdcea35ad2e254cee`
- C: `9a295d6d9d4f0f062f187cc6bf00ec5bf6f2067584d1f09cdcea35ad2e254cee`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.458138
- **Episodios:** 10 (0 sin reconverger antes del fin)

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
