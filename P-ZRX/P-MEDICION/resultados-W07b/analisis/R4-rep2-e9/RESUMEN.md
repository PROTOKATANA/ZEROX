# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:55:03.578
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e9 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R4-rep2-e9`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e9`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: (EJECUCION.txt sin CLK_TCK; USER_HZ de Linux por defecto))
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e9/A/registro.jsonl` | A | v1 | 1036 | 0 | `283b509a0f7888151c562adbc14567e26cc6ca5858ab63a7b92689855baf0997` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e9/B/registro.jsonl` | B | v1 | 1143 | 0 | `838f1ec4fa4e258810f27cd9d1236d42df5819b934f1df64d3498d083b891515` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e9/C/registro.jsonl` | C | v1 | 1151 | 0 | `fb197fb66810ad3d8a6f0975cadc65cd6e5cba7ab080285d9b84515919adea48` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e9/recursos-A.csv` | A (recursos) | — | 221 muestras | 0 | `41b048b2c10caa212ba4c12b7c6a211167d64369b43fe6f2c39755e60596d2d0` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e9/recursos-B.csv` | B (recursos) | — | 221 muestras | 0 | `32b07c700a2b6c12dc0eb24c460ec5b5a1e4299a5e41bc7270dd8c7ff54cb313` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e9/recursos-C.csv` | C (recursos) | — | 221 muestras | 0 | `c1f183dc1e0c3a4c0da0c0ba40caeff5db5f018be3b79bbb38560a1eace5ff1d` |

## Estado final

- A: `5bd24aa1a16ad5f776d539a49140c4f91ee2c714990a8445438853065b6fd204`
- B: `5bd24aa1a16ad5f776d539a49140c4f91ee2c714990a8445438853065b6fd204`
- C: `5bd24aa1a16ad5f776d539a49140c4f91ee2c714990a8445438853065b6fd204`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.460289
- **Episodios:** 63 (1 sin reconverger antes del fin)

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
