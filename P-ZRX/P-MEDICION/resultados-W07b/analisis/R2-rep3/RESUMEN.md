# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:12.740
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3 --nodos A,B,C,D --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R2-rep3`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/A/registro.jsonl` | A | v1 | 5502 | 0 | `cc110b12ddc13f867fa47c56651848da7261d403e5a359859090bfb11164f160` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/B/registro.jsonl` | B | v1 | 5535 | 0 | `bc2d0c285bfa58233cb1ebbf558fce425e3ddf010bee403b07ae78d95ccaa741` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/C/registro.jsonl` | C | v1 | 5474 | 0 | `3c0f6f971653f8ddbf901eb9c513e05aca61d01d4e0121cbeb03885cd3747098` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/D/registro.jsonl` | D | v1 | 5346 | 0 | `dcffd1310b45f402a210980faecb391f3d92170e63768c304240e268fc241187` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/recursos-A.csv` | A (recursos) | — | 865 muestras | 0 | `0059a9ab9f3ab3da4423e4a67e307f27d5662088be6cab80df24f9a0a8d4657a` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/recursos-B.csv` | B (recursos) | — | 865 muestras | 0 | `588e1d0106627eed382a1c8f6aa7c4d4ad630293ad55ab5d47cec3c6d3a7f24c` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/recursos-C.csv` | C (recursos) | — | 864 muestras | 0 | `dcaca87b0c5192ac5853bf5ea41c1f15a9451748ac55a9fc2200408edb81128d` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep3/recursos-D.csv` | D (recursos) | — | 113 muestras | 0 | `16e2783ac237ce6e6719be16c20a28f5a5e95e0868a3acc6c534657431651ca4` |

## Estado final

- A: `abce92074c983048b56dd996a232134b8a4a4d85e9563c994770634d12348f51`
- B: `abce92074c983048b56dd996a232134b8a4a4d85e9563c994770634d12348f51`
- C: `abce92074c983048b56dd996a232134b8a4a4d85e9563c994770634d12348f51`
- D: `abce92074c983048b56dd996a232134b8a4a4d85e9563c994770634d12348f51`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.762103
- **Episodios:** 8 (0 sin reconverger antes del fin)

## Hallazgos (W07c-B: bloques contados una vez por `hash`)

- `slot_distinto_por_bloque`: 0 (bloques cuyo slot difiere entre sus eventos)
- `padres_distintos_por_bloque`: 0 (bloques cuyo n_padres difiere entre sus eventos)
- `mergeset_distinto_por_bloque`: 0 (bloques cuyo par (azules,rojos) difiere entre sus eventos)
- `eventos_bloque_sin_hash`: 0 (eventos bloque_producido/bloque_red_admitido sin hash (no identificables))

## Métricas sin muestras en esta ejecución

- `latencia_propagacion_ns` (D->A): sin muestras.
- `latencia_propagacion_ns` (D->B): sin muestras.
- `latencia_propagacion_ns` (D->C): sin muestras.
- `arranque_ns` (todos): sin muestras.

## Notas de definición (ver `FALTAS-DE-DEFINICION.md`)

- Percentiles nearest-rank en enteros: rango = ceil(p·n/100); sin interpolación ni `Float64`.
- Bloques por slot / padres por bloque / fracción de rojos: un bloque cuenta una vez por `hash`; `bloques_por_slot` cubre todos los slots de `[mín,máx]`, vacíos incluidos (W07c-B).
- Latencia: producción más temprana de A y admisión más temprana de B por hash; las negativas entran y se cuentan.
- Divergencia: barrido O(E log E) sobre `cambio_punta`; episodios no reconvergidos marcados `truncada=1`.
- Recursos: diferencias entre muestras; `CLK_TCK` de `EJECUCION.txt` o 100 por defecto.
