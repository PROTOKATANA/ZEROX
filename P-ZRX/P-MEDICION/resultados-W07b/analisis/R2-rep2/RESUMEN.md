# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:15.836
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2 --nodos A,B,C,D --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R2-rep2`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/A/registro.jsonl` | A | v1 | 5502 | 0 | `f2b4892f112dbee21d636e7176ffdfd61e2a94e929b60a4ba42bf766508b21a9` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/B/registro.jsonl` | B | v1 | 5523 | 0 | `178d944a636f4abbd6ea5616e9d4223bb3ea9cef534cf536ee342c3ce4db18de` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/C/registro.jsonl` | C | v1 | 5533 | 0 | `91e788a67c900700808666e2f16912eb79b1e8283c2806db0d1c8c42400e391f` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/D/registro.jsonl` | D | v1 | 5365 | 0 | `2c5ba5739bab55b20be18c9f574d6397b39658897c2fd479ca3c414428235204` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/recursos-A.csv` | A (recursos) | — | 837 muestras | 0 | `049db0eaf846a763fe6aa2cca50bd598a17bc2f830dc601cf23b8b9d114c91de` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/recursos-B.csv` | B (recursos) | — | 837 muestras | 0 | `67648e6a6d5e08ccf9dee20cd911dd0ad36e818f939243acce9591e50b6b4f4a` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/recursos-C.csv` | C (recursos) | — | 837 muestras | 0 | `b523cba44201edae76086b1f9999fa3a71631ef00565a0da1a8d5c735b41b41e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R2-rep2/recursos-D.csv` | D (recursos) | — | 116 muestras | 0 | `05dc6a18a1a38014b9dca306c2067b239f709ffe05146c84fadabc948ce0ead9` |

## Estado final

- A: `305777f86f71e58da40747dc5f5da1c77d86b8b84f84170f2a62dfa7eeffb4ef`
- B: `305777f86f71e58da40747dc5f5da1c77d86b8b84f84170f2a62dfa7eeffb4ef`
- C: `305777f86f71e58da40747dc5f5da1c77d86b8b84f84170f2a62dfa7eeffb4ef`
- D: `305777f86f71e58da40747dc5f5da1c77d86b8b84f84170f2a62dfa7eeffb4ef`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.756529
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
