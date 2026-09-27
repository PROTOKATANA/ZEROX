# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T20:55:00.638
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e7e8 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R4-rep2-e7e8`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e7e8`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: (EJECUCION.txt sin CLK_TCK; USER_HZ de Linux por defecto))
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e7e8/A/registro.jsonl` | A | v1 | 1173 | 0 | `02aa73e953bd5969aaf30958fcc9ab3a26298e36599e0a326d942e3fa1c75adf` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e7e8/B/registro.jsonl` | B | v1 | 639 | 0 | `ad38fd86bd5f694e015cb671beca1689f685938c2b817c20187f560d76ee3928` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e7e8/C/registro.jsonl` | C | v1 | 637 | 0 | `4cfb3e294c6f65c227ade317e7622ede41bd39171903c6836575d2d3e62ac577` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e7e8/recursos-A.csv` | A (recursos) | — | 159 muestras | 0 | `027e37cda7d4bd4ed88c594590f145353b1ab95b4efb342497cc109ef1f919f1` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e7e8/recursos-B.csv` | B (recursos) | — | 159 muestras | 0 | `0975851bb7c4b7fc86be444a92601d008e58cdb593da77ff6f102766d470fc4e` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R4-rep2/e7e8/recursos-C.csv` | C (recursos) | — | 159 muestras | 0 | `0647e7b55d68baefb89a14062e0626d6080665e3fa250481ac7484847ef87453` |

## Estado final

- A: `53ec53da90f1771498ccac5d121323e6b3e3660176a17fb845ea6cf5648b5d08`
- B: `53ec53da90f1771498ccac5d121323e6b3e3660176a17fb845ea6cf5648b5d08`
- C: `53ec53da90f1771498ccac5d121323e6b3e3660176a17fb845ea6cf5648b5d08`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.120351
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
