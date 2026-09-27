# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:54.759
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e7e8 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R4-rep1-e7e8`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e7e8`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: (EJECUCION.txt sin CLK_TCK; USER_HZ de Linux por defecto))
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e7e8/A/registro.jsonl` | A | v1 | 1180 | 0 | `fe68def46de0076f7a5a932a0d522e763a0b3e1f0d18238824fa1d0fd7c0eac4` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e7e8/B/registro.jsonl` | B | v1 | 653 | 0 | `a8ae23c2fb3a36a17255900c4992995fd61e98a3e6a0ffb6c5c3a8fca85b565a` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e7e8/C/registro.jsonl` | C | v1 | 648 | 0 | `d36f0943d9854fa7495701d1a3b9270c3402ddbe1d18bdd56a7c8bcae6acaf12` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e7e8/recursos-A.csv` | A (recursos) | — | 155 muestras | 0 | `11e2536c84003207e76fcec67f636c33d48c5720e86c114deca2430244272058` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e7e8/recursos-B.csv` | B (recursos) | — | 155 muestras | 0 | `75f1619c23be70655b7da622e4de6544264055356e6477cf5104ffe5201c7edb` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep1/e7e8/recursos-C.csv` | C (recursos) | — | 155 muestras | 0 | `029479d74442a50b1b7123c187a04fc3c42a25560c209446f45f38aaa21a4404` |

## Estado final

- A: `0b0c6d034faed61e68de349f062223644f672cd3c450960a72fc274be41fffe7`
- B: `0b0c6d034faed61e68de349f062223644f672cd3c450960a72fc274be41fffe7`
- C: `0b0c6d034faed61e68de349f062223644f672cd3c450960a72fc274be41fffe7`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.081492
- **Episodios:** 57 (0 sin reconverger antes del fin)

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
