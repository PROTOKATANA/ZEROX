# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:55:09.465
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e9 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R4-rep3-e9`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e9`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: (EJECUCION.txt sin CLK_TCK; USER_HZ de Linux por defecto))
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e9/A/registro.jsonl` | A | v1 | 1026 | 0 | `19f6a30a67da0eb21eae888685a655ac736b5e9a41621d1583fb1c809f876313` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e9/B/registro.jsonl` | B | v1 | 1109 | 0 | `cdbe8e26b8b60042d76dc0018c4a042f3b0435017e0506e62d46cc633b70b563` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e9/C/registro.jsonl` | C | v1 | 1116 | 0 | `fe1d2c508e53082dd38a972b1ee2c7ddea8e2c93d70eaa7bb722d856ffdf1e90` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e9/recursos-A.csv` | A (recursos) | — | 221 muestras | 0 | `4fa5d9e6ff180513769b2c8d9ad05985726716dcfd245764b647a3c408be7266` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e9/recursos-B.csv` | B (recursos) | — | 221 muestras | 0 | `f47c402165c3117a0f3de80a83ebe1e8a79c238e0febf7bbe5630c60f6a74677` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep3/e9/recursos-C.csv` | C (recursos) | — | 221 muestras | 0 | `8887c85353a8ae07a5b147b70305646bb1567ed58706f376c02037b1282e0139` |

## Estado final

- A: `d2158d821f4ef43c5599a073c2c70b3fb02fc4956dcf5cdc92d11049489ccbc6`
- B: `d2158d821f4ef43c5599a073c2c70b3fb02fc4956dcf5cdc92d11049489ccbc6`
- C: `d2158d821f4ef43c5599a073c2c70b3fb02fc4956dcf5cdc92d11049489ccbc6`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.457264
- **Episodios:** 58 (1 sin reconverger antes del fin)

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
