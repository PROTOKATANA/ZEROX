# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:34.153
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R3-E6-3d21b1f-rep3`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3/A/registro.jsonl` | A | v1 | 1193 | 0 | `e220ad786d7c3bd23f0a9120bcb75d01eae4180993576d041d23be3c17cd886b` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3/B/registro.jsonl` | B | v1 | 1076 | 0 | `d4e3e0c5d8eb4325ab3ce149ca35a2421e950eff850963761da5823dae6aea8e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3/C/registro.jsonl` | C | v1 | 1061 | 0 | `d78e1f1dff49dedf87b114dd7fa02a9babbe358e2c3c82410dacc76f90e8cf76` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3/recursos-A.csv` | A (recursos) | — | 207 muestras | 0 | `28d7dd80a996747b93c144309665dbbd4530d91061ea64bcbe6700f7b1b666fa` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3/recursos-B.csv` | B (recursos) | — | 207 muestras | 0 | `699e48ac38b6edeefb582cc2b032cbd1b4859bdc943618a7cc762382668b73e3` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep3/recursos-C.csv` | C (recursos) | — | 207 muestras | 0 | `cc7e38e79f85b0289d68b947239d4ce73ca927121e5687a4f1334c9d6f39a389` |

## Estado final

- A: `92e29e7705f7d1b84c5c473261608da3fdd6330b209d421c7bbfc8d296aef3a1`
- B: `23466216df017f8a4a7fc6a77668a8bf7b0bb18a20ea9510185d88eeeeffa251`
- C: `23466216df017f8a4a7fc6a77668a8bf7b0bb18a20ea9510185d88eeeeffa251`
- **Estado final igual:** no

## Divergencia

- **Fracción del intervalo en divergencia:** 0.662961
- **Episodios:** 28 (0 sin reconverger antes del fin)

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
