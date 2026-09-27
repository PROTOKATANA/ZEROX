# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:25.213
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R1-rep3`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3/A/registro.jsonl` | A | v1 | 15682 | 0 | `79d02fe01f31e37eb3829c08acf02f365a6ce0ec2ace85229e9f12dcff9fd4c6` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3/B/registro.jsonl` | B | v1 | 12989 | 0 | `cc47cc14966d5fbdb3e258d51e689ff12b8e69c89a6f928e97179df1a25875f8` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3/C/registro.jsonl` | C | v1 | 12965 | 0 | `97e0da2ec26befe5e6e9836bcf8f07245f64376d5c6b374e87e67750816a051e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3/recursos-A.csv` | A (recursos) | — | 2199 muestras | 0 | `b2a1b218c4af3a5ed692f4831598ab311e5b3517be3598549b2aa084c151362b` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3/recursos-B.csv` | B (recursos) | — | 2199 muestras | 0 | `4f238cf7860a4856000e5e9b992be9ca5b14a54dc5365066e5de80524468569d` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep3/recursos-C.csv` | C (recursos) | — | 2199 muestras | 0 | `5b73b9bc685f9d797c0e7f339bc3750c7c9c4d22fc6dbf4115ba43f1fc0eba97` |

## Estado final

- A: `7bf46f475045a5a404a40a42d39c17a74f620b6c6779b25473c4c2d9b38c2b94`
- B: `9dd0d168a7ad5ff7009b3923af2acc33c68010392058c4e4e772b79c8b0377b4`
- C: `9dd0d168a7ad5ff7009b3923af2acc33c68010392058c4e4e772b79c8b0377b4`
- **Estado final igual:** no

## Divergencia

- **Fracción del intervalo en divergencia:** 0.219427
- **Episodios:** 1161 (0 sin reconverger antes del fin)

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
