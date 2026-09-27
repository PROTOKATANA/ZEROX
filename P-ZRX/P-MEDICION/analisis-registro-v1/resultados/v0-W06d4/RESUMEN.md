# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T16:07:12.496
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/analisis-registro-v1 run.jl --ejecucion /home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/analisis-registro-v1/datos/W06d4-real --nodos A,B,C --salida /home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/analisis-registro-v1/resultados/v0-W06d4`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/analisis-registro-v1/datos/W06d4-real`
- **Julia:** 1.13.0 (hilos default=1, interactive=0)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: (sin EJECUCION.txt; USER_HZ de Linux por defecto))
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/analisis-registro-v1/datos/W06d4-real/A/registro.jsonl` | A | v0 | 2857 | 0 | `d6fc095709c2f85e53ff4288ef143f102c41a2e66ac859f085a595982d37da24` |
| `/home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/analisis-registro-v1/datos/W06d4-real/B/registro.jsonl` | B | v0 | 1071 | 0 | `1b8c942b4a5d4b8d90a01d32fa24528773d0342af5573ecf520876a652bb639f` |
| `/home/katana/zeo/ZEROX/P-ZRX/P-MEDICION/analisis-registro-v1/datos/W06d4-real/C/registro.jsonl` | C | v0 | 1428 | 0 | `65663503c1ae706dd68a17d29ae6cc518282d3edd04f06ce851f5385dcae2c63` |

## Estado final

- A: `ffcb4fb976ebaf47e7a2a5e6fc94c9143c815f45e1838b366d5ba6c2993a2ee2`
- B: `9cba0a1cdc4c06a2bc3079e992f5292819e90d7f30532ad9c2463aca5996eb14`
- C: `0a15a00d48ac5988c7bab77223ec4ca195d9e0fc08cfdbccf144d3c9bffbdca8`
- **Estado final igual:** no

## Divergencia

- **Fracción del intervalo en divergencia:** 0.348235
- **Episodios:** 372 (1 sin reconverger antes del fin)

## Hallazgos (W07c-B: bloques contados una vez por `hash`)

- `slot_distinto_por_bloque`: 0 (bloques cuyo slot difiere entre sus eventos)
- `padres_distintos_por_bloque`: 0 (bloques cuyo n_padres difiere entre sus eventos)
- `mergeset_distinto_por_bloque`: 0 (bloques cuyo par (azules,rojos) difiere entre sus eventos)
- `eventos_bloque_sin_hash`: 0 (eventos bloque_producido/bloque_red_admitido sin hash (no identificables))

## Métricas sin muestras en esta ejecución

- `t_cabecera_ns` (todos): sin muestras.
- `t_admision_ns` (todos): sin muestras.
- `t_persistencia_ns` (todos): sin muestras.
- `t_total_ns` (todos): sin muestras.
- `bloques_por_slot` (todos): sin muestras.
- `padres_por_bloque` (todos): sin muestras.
- `duracion_reinicio_ns` (todos): sin muestras.
- `media_bloques_por_slot` (todos): sin muestras.
- `fraccion_rojos` (todos): sin muestras.

## Notas de definición (ver `FALTAS-DE-DEFINICION.md`)

- Percentiles nearest-rank en enteros: rango = ceil(p·n/100); sin interpolación ni `Float64`.
- Bloques por slot / padres por bloque / fracción de rojos: un bloque cuenta una vez por `hash`; `bloques_por_slot` cubre todos los slots de `[mín,máx]`, vacíos incluidos (W07c-B).
- Latencia: producción más temprana de A y admisión más temprana de B por hash; las negativas entran y se cuentan.
- Divergencia: barrido O(E log E) sobre `cambio_punta`; episodios no reconvergidos marcados `truncada=1`.
- Recursos: diferencias entre muestras; `CLK_TCK` de `EJECUCION.txt` o 100 por defecto.
