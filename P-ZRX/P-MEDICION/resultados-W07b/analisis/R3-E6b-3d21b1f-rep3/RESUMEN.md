# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:03.301
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R3-E6b-3d21b1f-rep3`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3/A/registro.jsonl` | A | v1 | 418 | 0 | `8d597d5ce839256dd33276eb1a1e79807a3797924a17119adf72571ab06e7b9c` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3/B/registro.jsonl` | B | v1 | 400 | 0 | `6cd7457ce6345aefc92000e1c31a2409909556f78950103c74324d20ccc70c28` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3/C/registro.jsonl` | C | v1 | 422 | 0 | `d590288c67fff67683a08d0fdec877bc6fa47ce87aa77ae238672d8979ccdfe4` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3/recursos-A.csv` | A (recursos) | — | 102 muestras | 0 | `d35d0a284ad88805873a57ef67675bcade39d2abc78796e9714f15270b42f7b4` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3/recursos-B.csv` | B (recursos) | — | 101 muestras | 0 | `3d0314e2970a7da2411c386955617a902b85fee8500993daa2f64733c8c780a3` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3/recursos-C.csv` | C (recursos) | — | 102 muestras | 0 | `654a6203c30d67ef5fa984af267d15390c473bd592f4a1565575f7960a1351b9` |

## Estado final

- A: `85526d6a41a9d5639f55d04690bf74229715d70a7cdf70ea5db87df34fc41c9a`
- B: `85526d6a41a9d5639f55d04690bf74229715d70a7cdf70ea5db87df34fc41c9a`
- C: `85526d6a41a9d5639f55d04690bf74229715d70a7cdf70ea5db87df34fc41c9a`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.451405
- **Episodios:** 7 (0 sin reconverger antes del fin)

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
