# INFORME del instrumento — `eclipse-red-v1`

**El informe del encargo está en `../../../INFORME.md`** (esto es `P-ZRX/P-ECLIPSE/investigacion/`,
un nivel por encima de la carpeta del instrumento). Aquí va lo que `LINEO.md` §1 y §6 piden del
instrumento mismo: qué se midió, con qué coste y con qué validación.

## 1 · Qué demuestra

| Resultado | Etiqueta | Artefacto |
|---|---|---|
| Control positivo de D8 A3b, promedios **y** conteos | `verificado` | `resultados/run-control.txt` |
| Las tres variantes de 11b, con sus `n` | `verificado` | `resultados/run-variantes.txt` |
| E2: `n_min = 6/23/66/211`, `α = 0,9249` | `verificado` | `resultados/run-sensores.txt` |
| E1: `B` celda a celda (lognormal y Pareto) | `verificado` | `resultados/run-sensores.txt` |
| Identidades forzosas `P(D>8) = 0,0100` y `P(L>8) = 0,014760` | `verificado` | `resultados/run-sensores.txt` |
| F2: barrido de `Δ` y de régimen de peso | `medido` | `resultados/run-regimen.txt` |
| Captura de salientes por prefijo | `derivado` | `resultados/run-captura.txt` |
| Partición de flujo y pinza de `PRESUP_NODO` | `derivado` | `resultados/run-flujo.txt` |
| 1006 aserciones, con `--check-bounds=yes` | `verificado` | `resultados/TESTS.txt` |

```
Test Summary:  | Pass  Total  Time
eclipse-red-v1 | 1006   1006  3.3s
```

## 2 · Rendimiento (LINEO §6: tamaño, trabajo, semilla, métrica y resultado comprobado)

Caso representativo: **una simulación completa** con el horizonte del encargo (900 s, **890 bloques**
en el DAG). Es la unidad que el barrido repite 12 veces por celda. Tras calentar JIT.
`BenchmarkTools`, `samples = 20`, `evals = 1`, **1 hilo**.

| Variante | Tiempo mediano | Asignaciones | Memoria | Hilos | Frente a la referencia |
|---|---:|---:|---:|---|---|
| Oráculo GHOSTDAG | — | — | — | 1 | `GDR-v0.2`: 577 131 aserciones declaradas, no reejecutadas aquí |
| Control E=200 α=0,00 | **6,86 ms** | 77 704 | 16,26 MiB | 1 | reproduce el oráculo Python **exactamente** |
| Control E=200 α=0,25 | **4,18 ms** | 58 099 | 14,52 MiB | 1 | idem |
| iii E=20 α=0,00 | **6,68 ms** | 75 418 | 16,92 MiB | 1 | idem |
| iii E=60 α=0,00 | **6,74 ms** | 75 297 | 16,33 MiB | 1 | idem |
| iii E=200 α=0,00 | **6,85 ms** | 76 303 | 16,45 MiB | 1 | idem |
| Barrido de control (48 corridas) | **0,4 s total** (8 ms/corrida) | — | — | 1 | — |

**Presupuesto:** el encargo fija un máximo de **8 hilos** y corridas de minutos a una hora. El
instrumento corrió **en serie, 1 hilo**, y **ninguna corrida superó los 10 minutos**; el instrumento
completo, con precompilación, queda por debajo de **1 hora**. **Ningún resultado es inconcluso por
presupuesto.** `LINEO.md` §7 trata el tope de hilos como techo y no como objetivo: no se midió
escalado porque no hacía falta.

## 3 · Por qué no se optimizaron más las asignaciones

`LINEO.md` §2 orden 0 manda preguntar **primero** si la complejidad es innecesaria, y §10 exige no
dejar asignaciones en el cuello **sin justificación explícita**. Aquí la justificación:

- Las **77 704 asignaciones** por corrida vienen de dos sitios conocidos: el barrido de visibilidad
  (`Vector{Int}` de puntas por evento) y las uniones de `BitSet` en `tam_mergeset`. Ambas están
  medidas y localizadas.
- El bucle caliente **ya usa un `BitSet` reutilizable** (`sim.scratch`) y una **marca por token**
  (`sim.marca`) en vez de reconstruir conjuntos, que era la versión ingenua.
- El coste real es **8 ms por corrida de 890 bloques = 9 µs por bloque**, y el estudio completo —el
  barrido de régimen, 96 corridas— tarda **menos de 1 segundo**. Optimizar más sería optimizar un
  cuello que no existe: la decisión de qué medir y cómo interpretarlo costó órdenes de magnitud más
  que el cómputo.
- **No se ha usado `@fastmath`, ni `@simd`, ni `@turbo`, ni `Float32`.** `@inbounds` sí, en dos
  bucles, y **precisamente por eso** los tests corren con `--check-bounds=yes`: de hecho un fallo
  real de este puerto fue una escritura fuera de rango con `@inbounds` (ver `BITACORA.md`).

## 4 · Lo que el instrumento NO mide

- **No mide la partición de flujo de extremo a extremo.** `flujo.jl` es **aritmética de enteros**
  sobre las reglas, no una simulación con dos vistas y dos flujos.
- **No mide nada en hardware.** Cita 92 ms/slot y 1,33–9,86 ms/salto de
  `veritas/rendimiento/coste-salto-v1/`.
- **No mide `Δ` en red.** Usa la `Δ` **simulada** de `DMS-v0.1`.
- **No mide `s_λ`, ni el coste del paso 1b**, que son las dos cantidades que dejan F5 y la
  viabilidad de E2 en `no determinado`.

## 5 · Documentos del instrumento

`CONTRATO.md` (alcance) · `MODELO.md` (matemática y complejidad) · `METODO.md` (comando, controles,
validación) · `HIPOTESIS.md` (supuestos con etiqueta) ·
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` (**autoexamen adversarial: qué supuesto cambiaría el
veredicto**) · `PROCEDENCIA.md` (de dónde sale cada pieza) · `BITACORA.md` (fallos y correcciones).
