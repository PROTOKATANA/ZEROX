# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:31.185
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R3-E6-3d21b1f-rep2`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2/A/registro.jsonl` | A | v1 | 1128 | 0 | `822ef987ac1dcb49bb4ca9eccbc880da174b85640c054e2e59e7284fcebf8707` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2/B/registro.jsonl` | B | v1 | 1023 | 0 | `6626a6ec9a9542d55b37e451791e77cf96be63ea58dc964cdfd3b60042093c71` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2/C/registro.jsonl` | C | v1 | 1034 | 0 | `c5d7bd07e88fec5266f327560dbf6a3e518c625e142aa4e6ffdeba382d3c2fdd` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2/recursos-A.csv` | A (recursos) | — | 200 muestras | 0 | `3dbea9e56e4b297788edb89b9e7906e94eec6a34d0e88fbe4ab45d6737c1c365` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2/recursos-B.csv` | B (recursos) | — | 199 muestras | 0 | `7843efde7c3077fd5d21021da881336af5ad1faba7a8fd452c95fa8771eb0c2e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep2/recursos-C.csv` | C (recursos) | — | 199 muestras | 0 | `00c32d508e1a3fcdc72d72c558f73f323a1973689c868fc20ced45a8833e6a3e` |

## Estado final

- A: `dd1111feee2de91f1b2b4d40659e5b5a0a14f71e7f444c22c25538b0ddd9cb96`
- B: `dd1111feee2de91f1b2b4d40659e5b5a0a14f71e7f444c22c25538b0ddd9cb96`
- C: `dd1111feee2de91f1b2b4d40659e5b5a0a14f71e7f444c22c25538b0ddd9cb96`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.697741
- **Episodios:** 24 (0 sin reconverger antes del fin)

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
