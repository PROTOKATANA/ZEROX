# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:57.708
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e9 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R4-rep1-e9`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e9`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: (EJECUCION.txt sin CLK_TCK; USER_HZ de Linux por defecto))
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e9/A/registro.jsonl` | A | v1 | 1047 | 0 | `534a5a780772676fbd51b45b6c28f0ad15ca943be1785d0b6a6bc60bcb2de242` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e9/B/registro.jsonl` | B | v1 | 1171 | 0 | `7dfcf67884b3203dccb963002251f32c482ee16a1ab010d5d0b47f9c6326edf5` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e9/C/registro.jsonl` | C | v1 | 1171 | 0 | `d389f5d48e4a76118bf8cee14c646820939c55f3e216278e4a260a9404f5c94e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e9/recursos-A.csv` | A (recursos) | — | 221 muestras | 0 | `da3d446651fe12cf5bbe18c194c7d222fd6f9119ecbcbb9fdbc9273296628691` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e9/recursos-B.csv` | B (recursos) | — | 221 muestras | 0 | `3533ba9a8c453e8d21cbe9f7a7b501b6889d9ddb34dc12242f80d6b956a6815e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e9/recursos-C.csv` | C (recursos) | — | 221 muestras | 0 | `b403850f525cc261bee8365a96cdd1b77644043fd8afaa7322951fe7b4d27ea9` |

## Estado final

- A: `cf963ebad0b6fb3e6577cadb8d75f2c2dacf076be782643d991e6c55586e8a9c`
- B: `cf963ebad0b6fb3e6577cadb8d75f2c2dacf076be782643d991e6c55586e8a9c`
- C: `cf963ebad0b6fb3e6577cadb8d75f2c2dacf076be782643d991e6c55586e8a9c`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.453958
- **Episodios:** 66 (1 sin reconverger antes del fin)

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
