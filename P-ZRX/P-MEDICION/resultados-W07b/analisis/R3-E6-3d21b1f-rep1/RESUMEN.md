# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:54:28.220
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R3-E6-3d21b1f-rep1`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1/A/registro.jsonl` | A | v1 | 1159 | 0 | `3b32206eb2d10829d83448ec597781f0c075efd63fd0e180aecb590a60099a76` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1/B/registro.jsonl` | B | v1 | 1061 | 0 | `2189e40537a9338b7e167225510ab71606e331bd44f536c8f0005fa98ec8e01c` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1/C/registro.jsonl` | C | v1 | 1063 | 0 | `ef208b2a1a145c6e79e5860f53c162152e376d118d72d2c57a75f0acf172ba9a` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1/recursos-A.csv` | A (recursos) | — | 198 muestras | 0 | `40a68a6503dcb1c904da5610ff1210e7a57e89bd62050a3e3bdd264ae5d00883` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1/recursos-B.csv` | B (recursos) | — | 197 muestras | 0 | `aeabc2cbdc297af10e5e868026d4053642dcda1c2870329d55e13473bfbfb677` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-3d21b1f-rep1/recursos-C.csv` | C (recursos) | — | 197 muestras | 0 | `93ad37d70ce02411d4cf24e0649861d5e36530e890a2d8c70e06352407d1000c` |

## Estado final

- A: `7a7e9a75fe3a4fcd301076a83ccd033aa616a8f3e609461ccd5ac82d5914fe0e`
- B: `7a7e9a75fe3a4fcd301076a83ccd033aa616a8f3e609461ccd5ac82d5914fe0e`
- C: `7a7e9a75fe3a4fcd301076a83ccd033aa616a8f3e609461ccd5ac82d5914fe0e`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.693758
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
