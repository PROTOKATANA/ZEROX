# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:09.389
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1 --nodos A,B,C,D --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R2-rep1`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/A/registro.jsonl` | A | v1 | 5428 | 0 | `ea298987c28836f343e460283e94bee07235919575047f54baad31e3187e73be` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/B/registro.jsonl` | B | v1 | 5417 | 0 | `d0bb3a530a99c2e288d743f7941d044e68fdcf0be6b24c45a75b21ab3be9fa85` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/C/registro.jsonl` | C | v1 | 5392 | 0 | `cf1a2ccba09829784bc7e53fae3a3006b718e269aa8bd8b9706674748eaddf43` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/D/registro.jsonl` | D | v1 | 5248 | 0 | `334537a819b2abf31b4d5639555994a4ef099aadc10514be2e41dd00e8c058e7` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/recursos-A.csv` | A (recursos) | — | 872 muestras | 0 | `c587ae50637d3df4de56fb6e2f75394abc153ee2915e9eb46ff7958ec5dd2570` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/recursos-B.csv` | B (recursos) | — | 872 muestras | 0 | `67a3aad75e58e046578c9b95ef0967523331844ca51aff84acb1cf8a37988696` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/recursos-C.csv` | C (recursos) | — | 872 muestras | 0 | `7e6ec8bacee7fda8de00983c02349723d093f183f650bf730933cbd46dee382b` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep1/recursos-D.csv` | D (recursos) | — | 119 muestras | 0 | `5f8b2ab5589d90b78bd339cfb718a392d190392afbab9341272bd11b9dbfbdda` |

## Estado final

- A: `67acba9540957c4fe0b1ed3c09692df49e66a7eec4133e7caaaa8225641ded0b`
- B: `67acba9540957c4fe0b1ed3c09692df49e66a7eec4133e7caaaa8225641ded0b`
- C: `67acba9540957c4fe0b1ed3c09692df49e66a7eec4133e7caaaa8225641ded0b`
- D: `67acba9540957c4fe0b1ed3c09692df49e66a7eec4133e7caaaa8225641ded0b`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.784206
- **Episodios:** 7 (0 sin reconverger antes del fin)

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
