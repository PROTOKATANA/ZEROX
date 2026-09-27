# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:55:06.527
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e7e8 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R4-rep3-e7e8`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e7e8`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: (EJECUCION.txt sin CLK_TCK; USER_HZ de Linux por defecto))
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e7e8/A/registro.jsonl` | A | v1 | 1182 | 0 | `507d3978368e4fc1daed1b6f789dec5d44bc97de08d495a75acf30a9cf155336` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e7e8/B/registro.jsonl` | B | v1 | 658 | 0 | `2e43bf1592fd1eaf25c1ae6ff78667555764deb55b2178d0d1d89a1bbd2abc9e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e7e8/C/registro.jsonl` | C | v1 | 655 | 0 | `49b24c5edaa187335026e917fd1d838b68f406a8a38af32a4eb9d6e36fd566c8` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e7e8/recursos-A.csv` | A (recursos) | — | 156 muestras | 0 | `2729db1c58f426a3555c7454285b85e99bb9c8ceec99ed8267d2fac4c298729c` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e7e8/recursos-B.csv` | B (recursos) | — | 156 muestras | 0 | `c02b276c8027d32e196d37d663980855dc71da29dd3f94b09acb802d6e84f15d` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e7e8/recursos-C.csv` | C (recursos) | — | 156 muestras | 0 | `27de62da6f5b84a6eaa4638c8779b34a479bdcdfd54f8729791ca90d92987bdf` |

## Estado final

- A: `6e755a6efe2edb9cb2ff5b74b8acd7755709614497e5772dbf0e18107837b2c2`
- B: `6e755a6efe2edb9cb2ff5b74b8acd7755709614497e5772dbf0e18107837b2c2`
- C: `6e755a6efe2edb9cb2ff5b74b8acd7755709614497e5772dbf0e18107837b2c2`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.093687
- **Episodios:** 53 (0 sin reconverger antes del fin)

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
