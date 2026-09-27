# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:18.959
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R1-rep1`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1/A/registro.jsonl` | A | v1 | 17049 | 0 | `92f7c4911ef5ea0eef87b6b45c4f1c38947d25d50a404572ae46d38cda95ffc0` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1/B/registro.jsonl` | B | v1 | 14234 | 0 | `b3e69587305b1e91f5494882cd7fa7f2e4ed55af31f14660acf9b56322ae3f85` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1/C/registro.jsonl` | C | v1 | 14238 | 0 | `01fe5e3271cb2eaa1652b90e1dd2b3a0b550d8fd75f74db6f6ffbaff851cb06e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1/recursos-A.csv` | A (recursos) | — | 2174 muestras | 0 | `17a774e8b53f77815ed9540ad16019d1c609dfdc0a365e2907d15dded5c0d51d` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1/recursos-B.csv` | B (recursos) | — | 2174 muestras | 0 | `d408f22a6a137ab7990608d0a9bfa8da9dc27e378111d8e81e3d25e60ee378f7` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R1-rep1/recursos-C.csv` | C (recursos) | — | 2175 muestras | 0 | `683a25998057fa48c36a472e974d1e3a259d7d9aeb5969bd5600f77debfa38db` |

## Estado final

- A: `b9d8e2ba11a2b7d6053af8b04d69b41f57b2adbe42ec94bdb3f794f652ae8649`
- B: `2afdeb227bb77cde9a98cf00d7d7290cdf7a15cfca86f5f8c7b1c0d291477761`
- C: `2afdeb227bb77cde9a98cf00d7d7290cdf7a15cfca86f5f8c7b1c0d291477761`
- **Estado final igual:** no

## Divergencia

- **Fracción del intervalo en divergencia:** 0.116822
- **Episodios:** 1374 (1 sin reconverger antes del fin)

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
