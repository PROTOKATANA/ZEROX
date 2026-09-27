# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:22.112
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R1-rep2`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2/A/registro.jsonl` | A | v1 | 15131 | 0 | `cccd6378807318c44ea6465d14eb86bc01eb523e9eb6c3039a1cad3c93706c30` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2/B/registro.jsonl` | B | v1 | 12444 | 0 | `961954dfedbad5e4f7f3ac62cb2f7431ab40e118eb51c51248f5f660b89b72c9` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2/C/registro.jsonl` | C | v1 | 12449 | 0 | `3e89ca6081c9b45af7e29c37e7d48cd8dfa201482fb7b7423dc2402985dad5ed` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2/recursos-A.csv` | A (recursos) | — | 2063 muestras | 0 | `563090ebb276da4ae892bdfd5031ee4b698b6132ed6366775020906d6c86bd9e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2/recursos-B.csv` | B (recursos) | — | 2063 muestras | 0 | `423050d910142afb407af136fce65ae30a9327e11ecba1f10e03899e9ccb4aaf` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep2/recursos-C.csv` | C (recursos) | — | 2063 muestras | 0 | `f6bbaf177a93d32f7bfbe0282da28291cdf40928fa834e0c3b579017a12646d5` |

## Estado final

- A: `b4f5d8ed741cb8d94316df84c35c1a2cb84210ee7fb793aa778b69de4eec202d`
- B: `b4f5d8ed741cb8d94316df84c35c1a2cb84210ee7fb793aa778b69de4eec202d`
- C: `59fcbed756873d36183b45854dc6b4f4f84c19dd0563959053095cfc12e55a04`
- **Estado final igual:** no

## Divergencia

- **Fracción del intervalo en divergencia:** 0.216822
- **Episodios:** 1161 (0 sin reconverger antes del fin)

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
