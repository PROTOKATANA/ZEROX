# RESUMEN de la ejecución analizada — W07c

- **Fecha:** 2026-09-27T18:16:03.513
- **Comando:** ``/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia -C native -J/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/lib/julia/sys.so -g1` --project=/home/katana/zeo/ZEROX/deepseek/W07b/analisis-instrumento run.jl --ejecucion /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1 --nodos A,B,C --salida /home/katana/zeo/ZEROX/deepseek/W07b/analisis/R3-E6-rep1`
- **Modelo (según la orden):** deepseek-flash
- **Directorio de ejecución:** `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1`
- **Julia:** 1.13.0 (hilos default=1, interactive=1)
- **CPU:** znver5
- **`sha256(Manifest.toml)`:** `22327796a9e8100ca2696726aae43f4bf263b14243cb9b646cbf2d2b8ac1a3c3`
- **`CLK_TCK`:** 100 (origen: /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1/EJECUCION.txt)
- **Duplicados de producción (hash producido >1 vez):** 0

## Procedencia de los archivos leídos

| archivo | nodo | version_esquema | líneas | truncadas | sha256 |
|---|---|---|---:|---:|---|
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1/A/registro.jsonl` | A | v1 | 1287 | 0 | `35426af4f6a929462200fb97039b90db5b236e9571c0cfeb44e8eb694d0802d5` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1/B/registro.jsonl` | B | v1 | 1035 | 0 | `0d679815d7e6225d90aaca0d896d790f5c7c373169527151fce08dfb46c8de8d` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1/C/registro.jsonl` | C | v1 | 1036 | 0 | `14f1a9d950f9509c725fad67a67ba82bab0897f308a19e1d96a3499749465e02` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1/recursos-A.csv` | A (recursos) | — | 195 muestras | 0 | `c979e503d310052cf5cf826b165bf99ced09ed961697b24436fe228933e297b2` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1/recursos-B.csv` | B (recursos) | — | 195 muestras | 0 | `6dda062015e4772d17c0c280537aade2af60f31fa12b3a0266daeb9a078edd23` |
| `/home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6-rep1/recursos-C.csv` | C (recursos) | — | 195 muestras | 0 | `edc47abe43b8b7a43996fdced8a5aa18e03b3ebbec3413213cc5913fcd030927` |

## Estado final

- A: `4839e15d36c5cfa627295cab278fb2656a81b47f0f91c2906f4ae788920f4ba9`
- B: `4839e15d36c5cfa627295cab278fb2656a81b47f0f91c2906f4ae788920f4ba9`
- C: `4839e15d36c5cfa627295cab278fb2656a81b47f0f91c2906f4ae788920f4ba9`
- **Estado final igual:** sí

## Divergencia

- **Fracción del intervalo en divergencia:** 0.347254
- **Episodios:** 56 (0 sin reconverger antes del fin)

## Métricas sin muestras en esta ejecución

- `arranque_ns` (todos): sin muestras.

## Notas de definición (ver `FALTAS-DE-DEFINICION.md`)

- Percentiles nearest-rank en enteros: rango = ceil(p·n/100); sin interpolación ni `Float64`.
- Latencia: producción más temprana de A y admisión más temprana de B por hash; las negativas entran y se cuentan.
- Divergencia: barrido O(E log E) sobre `cambio_punta`; episodios no reconvergidos marcados `truncada=1`.
- Recursos: diferencias entre muestras; `CLK_TCK` de `EJECUCION.txt` o 100 por defecto.
