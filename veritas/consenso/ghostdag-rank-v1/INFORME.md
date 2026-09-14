# INFORME — GDR-v0.2 (ghostdag-rank-v1)

**Categoría**: `consenso` (dominante) — el objeto de estudio es una regla de consenso (GHOSTDAG +
`rank`), no una medición de rendimiento aislada. Secundaria: `rendimiento`, por el kernel
incremental y su escalado por hilos, medidos pero subordinados a la corrección.

**Estado**: Corrección 1 sobre GDR-v0.1, con la regla C ya DECIDIDA POR KATANA (TAREAS.md §1.3,
2026-09-14) implementada, probada y con demostraciones escritas. Quedan abiertos D-4 (redacción
normativa de `rank` en el SPEC — ya propuesta, no trasladada), D-5 (dominio/desbordamiento de
producción) y si P1 conserva el desempate final por `id` (`DECISIONES-PENDIENTES.md`).

## Las 5 preguntas de LINEO.md

**1. ¿Complejidad temporal y espacial? ¿Qué parámetro domina el coste?**

*Tiempo*: dominado por el tamaño del mergeset (≤180, R-FIN-12) y el largo de cadena recorrido por
el algoritmo incremental de k-cluster (`protocol.rs:168-283`). Medido (`resultados/BENCH.txt`):
del orden de unos pocos µs/bloque en el rango n=100..3200.

*Espacio — CORREGIDO en esta corrección (tarea 3.6a): NO es O(n).* La respuesta original de
GDR-v0.1 decía O(n) total; es falsa. `est.anc::Vector{BitSet}` (`rapido.jl:27`) guarda, para CADA
bloque, el conjunto COMPLETO de sus ancestros estrictos — ese conjunto puede crecer hasta O(n)
elementos por bloque (un DAG donde cada bloque desciende de casi todos los anteriores), dando
O(n²) memoria total en el peor caso. Lo mismo ocurre con `nd.blue_idents = copy(sp_bi)`
(`rapido.jl:189`, copia el conjunto completo de identidades azules en cada bloque nuevo) y, en el
oráculo, `contexto = copy(est.gd[sp].blueset)` / `tam = copy(est.gd[sp].tam)`
(`referencia.jl:122-123`, copian el blue set y las cuentas de anticono COMPLETOS en cada bloque).
Medido (`resultados/MEMORIA.txt`, Corrección 1): bytes/bloque de `Base.summarysize(EstadoRapido)`
crece de 1519 (n=100) a 8995 (n=6400) — un factor ≈5,9× mientras `n` crece 64×, consistente con
crecimiento por bloque proporcional a `n`, no constante. Esto es aceptable para un **instrumento
de estudio** que reconstruye estados completos para comparar oráculo/kernel en DAGs de hasta miles
de bloques (no para un nodo de producción a millones de bloques, que necesitaría una estructura de
ancestría comprimida — fuera de alcance declarado, `CONTRATO.md`).

**2. ¿Perfil de CPU, memoria y asignaciones tras compilar?**

`resultados/PERFIL.txt`: perfil estadístico de 20 entregas completas de un DAG n=1000
(`bench/perfil.jl`). El tiempo se reparte entre operaciones de `Dict`
(`check_azul`/`revisar_con_bloque_cadena`, sobre `blues_anticone_sizes`) y `hash_de_id`. Asignaciones
por bloque en el kernel (`resultados/BENCH.txt`): crecen con `n` (ver Q1). `resultados/WARNTYPE.txt`
(Corrección 1, tarea 3.6b): `@code_warntype` sobre `peso`, `+(::BW256,::BW256)`,
`tam_anticono_azul`, `check_azul` y `anadir!` del kernel — **cero** coincidencias de `::Any`
(ninguna inestabilidad de tipos en las 5 funciones). JET.jl no se ejecutó (opcional por LINEO y
por el encargo, requeriría un entorno `bench/jet/` aparte para no tocar el `Manifest.toml` del
instrumento); se documenta como no intentado, no como huella de que no haría falta.

**3. ¿Oráculo pequeño/lento contra el que se comprobó el kernel optimizado?**

`referencia.jl`: recalcula GHOSTDAG desde cero para cada bloque, con `Set{Int}` para
anticonos/ancestros y `BigInt` (`peso_big`) para `blue_work`. **Desde Corrección 1 (tarea 3.2c),
el oráculo usa claves de dirección independientes del kernel** (`seleccionar_sp_ref`,
`orden_merge_ref`, `virtual_sp_ref`, `orden_aplicacion_ref`) para los 4 modos (`SP_ZEROX` = regla
C, y los tres históricos), en vez de compartir `cmp_orden`/`mejor_sp`/`menor_merge` con el kernel
— así una diferencia de DIRECCIÓN entre ambas implementaciones queda expuesta por la equivalencia,
en vez de que ambas compartan el mismo posible error (motivación explícita de esta corrección).
Comprobado exactamente en: 740+ DAGs aleatorios del testset de equivalencia; 7200 DAGs del corpus
3.2(d) (`resultados/EQUIVALENCIA-C.txt`, 4 modos × 6 valores de k, ≥300 DAGs cada uno, ventana
1..30, con 173 718 marcas `rojo_k` y 51 815 `rojo_U3` ejercitadas — no vacío); los 6 vectores
oficiales de Kaspa con `SP_KASPA`/`MERGE_KASPA` explícitos. Verificado de forma independiente en
esta sesión de corrección con `--check-bounds=yes` (`resultados/TESTS.txt`).

**4. ¿Qué tipos numéricos y qué error de redondeo admite el resultado?**

Ninguno: todo el modelo es aritmética entera exacta. `w(B) = ⌊2^128/(SR+1)⌋` es división entera
exacta (`fld`). `blue_work` usa `BigInt` en el oráculo y `BW256` (256 bits fijos) en el kernel, con
`OverflowError` explícito si se excede el dominio. La cota `blue_work(B) < n·2^128` está DEMOSTRADA
por escrito (`PROPUESTA-SPEC.md` §11, Corrección 1 tarea 3.5) y comprobada en los DAGs de prueba
(testset dedicado, `test/runtests.jl`). No hay `Float64`/`Float32` en ningún cálculo que afecte a
un veredicto de consenso.

**5. ¿Qué semilla, versión de Julia, `Manifest.toml`, hardware y número de hilos reprodujeron la
cifra publicada?**

`julia 1.13.0` (`julia-version.toml`), `Manifest.toml` sin cambios en esta corrección (no se
añadieron dependencias, tarea §0). Hardware: `znver5`, 32 hilos lógicos, 123,4 GB RAM
(`resultados/ENTORNO.txt`). Desde Corrección 1, `run.jl` acepta `--seed` en todo modo aleatorio
(tarea 3.6c) y cada resultado publicado lleva cabecera con `git rev-parse HEAD`, fecha,
`VERSION`, hilos, CPU/RAM, backend BLAS, comando y semilla (tarea 3.6d — ver cualquier archivo de
`resultados/` generado por `run.jl` en esta corrección). Tests y vectores de Kaspa: 1 hilo.
Escalado (`bench/escalado.jl`): ver `resultados/BENCH.txt` para los hilos efectivamente medidos
(sujeto a convivencia con `deepseek/MIDIENDO`, `BITACORA.md`). Comando exacto de
reproducción de cada corrida: `METODO.md`.

## Resultados frente a los criterios de aceptación de Corrección 1 (sección 4 del encargo)

| # | Criterio | Resultado |
|---|---|---|
| 1 | `git status` idéntico al inicio; nada fuera de zona, tampoco en `/tmp` | Verificado (`BITACORA.md`, sección Corrección 1). Temporales en `tmp/` del instrumento, borrados al terminar. |
| 2 | Suite en verde con `--check-bounds=yes` | Ver `resultados/TESTS.txt` de esta corrección. |
| 3 | Kaspa: 6/6 al 100 %, con `SP_KASPA`/`MERGE_KASPA` explícitos | `resultados/run-kaspa.txt` (regenerado, tarea 3.8), `test/runtests.jl` actualizado (tarea 3.2b). |
| 4 | Determinismo con C: ≥1000 órdenes, una familia con ventana≤6 | Testset «determinismo: 1 000 órdenes por familia» (familia 1, ventana=6) + `resultados/run-determinismo.txt` regenerado. |
| 5 | Oráculo (claves propias) = kernel en todas las combinaciones 3.2(d) | `resultados/EQUIVALENCIA-C.txt`: 7200/7200 DAGs exactos, 4 modos × 6 k, ventana 1..30. |
| 6 | D8-D11 derivados antes de sus tests | `resultados/REGISTRO.log`: línea de derivación de cada uno antes de la línea de su test. Un discrepancia real en D8(b) (error aritmético propio), documentada como enmienda, no oculta. |
| 7 | Demostraciones (i)-(iii) y cota de 3.5 escritas como demostración | `PROPUESTA-SPEC.md` §7.2 y §11. |
| 8 | LINEO: `--seed`, cabeceras, `WARNTYPE.txt`, presupuesto, pregunta 1 corregida | `run.jl` (tarea 3.6), `resultados/WARNTYPE.txt`, `resultados/MEMORIA.txt`, `CONTRATO.md` (presupuesto), Q1 arriba. |
| 9 | Ninguna regla de consenso decidida por Claude | C es de Katana (TAREAS.md §1.3); D-4/D-5/id-P1 quedan como opción en `DECISIONES-PENDIENTES.md`. |

## Tabla de rendimiento (formato LINEO §6)

| Variante | Tiempo mediano | Asignaciones | Hilos/backend | Resultado frente a referencia |
|---|---:|---:|---|---|
| Oráculo (`referencia.jl`, claves independientes, n=100) | ver `resultados/BENCH.txt` | — (`BigInt`+`Set`) | 1 CPU | fuente de verdad; 7200 DAGs exactos contra el kernel (3.2d) |
| Kernel (`rapido.jl`, n=100..6400) | ver `resultados/BENCH.txt` | crece con `n` (ver Q1, `resultados/MEMORIA.txt`) | 1 CPU | igual, exacto |
| Escalado por réplicas independientes, 1→24 hilos | 0,13s→0,02s (256 DAGs n=200) | — | `Threads.@threads`, medido 1,2,4,8,16,24 (`resultados/BENCH.txt`) | 386 424→2 079 709 bloques/s; 24 hilos gana en throughput bruto, se conserva; sin interferencia de `deepseek/MIDIENDO` (se liberó antes de medir) |

No se publica una cifra de "X veces más rápido" aislada: el tamaño (n), el trabajo total y el
resultado comprobado acompañan cada número, como exige LINEO §6.

## Limitaciones declaradas

- D-4 (redacción normativa de `rank`), D-5 (dominio/desbordamiento de producción) y si P1
  conserva el desempate final por `id` quedan como decisión de Katana (`DECISIONES-PENDIENTES.md`).
- `JSON3.jl` sigue marcado `[deprecated]`; no se sustituyó en esta corrección (fuera de alcance,
  tarea 3.7 del encargo lo excluye explícitamente).
- La demostración de totalidad/causalidad de `rank` es DEMOSTRADA por escrito para el caso general
  (`PROPUESTA-SPEC.md` §7.2) y COMPROBADA exhaustivamente solo para n≤6 y por muestreo para n
  mayor — la demostración escrita cubre el caso general con una premisa (`sp(B)∈blues(B)`) que a su
  vez está comprobada como invariante, no derivada de primeros principios en este documento.
- El punto 3.12 del encargo original (color/rank sobre fixtures de otros instrumentos) sigue sin
  ejecutarse — fuera de alcance de Corrección 1 también.
- La cota de `blue_work < n·2^128` (D-5) no incluye un análisis adversarial de cuánto puede
  acumular un atacante con recursos acotados en un horizonte temporal — declarado NO DEMOSTRADO en
  `PROPUESTA-SPEC.md` §11.
