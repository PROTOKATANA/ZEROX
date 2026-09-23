# Revisión independiente de SDV-v1 — 2026-09-23

**Estado: validación integral pendiente.** Esta revisión no adopta ni descarta el segundo VDF.
Las salidas numéricas originales se conservan para reproducir el instrumento. El criterio para
usar una reducción de ventana como argumento de seguridad es una traza causal que respete cuándo
se conoce la semilla de cada ancla y el tiempo secuencial de su cadena. SDV-v1 no satisface ese
criterio en su conclusión sobre líneas AES adicionales.

## Hallazgo que cambia el veredicto

En `src/modelo.jl:288-295`, `revelacion_paralela=true` omite por completo `Lrev/ρ` después de
conocer la semilla. `src/referencia.jl` hace la misma omisión; los 192 casos de equivalencia
comprueban que ambos programas coinciden, no que esa traza sea realizable. El control C8 compara
por construcción el modelo sin demora con el caso sin segunda cadena.

Sea `r_j` el primer instante en que se conocen todos los bytes de la semilla de la revelación y
`c_j` el instante en que la ancla queda decidida. Una cadena secuencial de `Lrev` pasos a tasa
`ρ` no puede estar lista antes de `r_j + Lrev/ρ`. Si se permite calcular desde `r_j`, la barrera
causal es al menos `max(c_j, r_j + Lrev/ρ)`; si se espera a la decisión, al menos
`c_j + Lrev/ρ`. Líneas adicionales sostienen varias cadenas simultáneas, pero no acortan esa
latencia individual. El modelo histórico REV-v1.0 ya asignaba una línea de revelación en paralelo
y conservaba el término `+Lrev/ρ` (`P-ZRX/P-REVELACION/investigacion/INFORME.md:208-220`).

Por tanto, `V_paralelo = V_sin` y la reducción **0,00 %** de `resultados/REGIMENES.txt` son un
**contrafáctico de revelación disponible sin demora**. `⌈Lrev/I⌉ = 2` para `I = 4 666` es una
cuenta de capacidad entre épocas, no una prueba de que un atacante pueda anticipar la salida de
una ancla recién conocida. La comparación «2 líneas adversarias frente a 3 honestas» omite además
la línea PoT principal del atacante. El recuento de candidatos por slot tampoco enumera las
posibles variantes de `chunk(I_j)`.

**Veredicto corregido:** la afirmación de que dos líneas anulan la mejora queda **NO VALIDADA**.
El beneficio de 28,27 % en `V_max` pertenece al modelo REV-v1.0 con demora causal de la segunda
cadena bajo sus entradas de escenario; no es una mejora de finalidad de ZEROX demostrada.

## Otros límites verificables

- La calibración algebraica `I ≤ (Lrev − ρ_max·W_dec)/(ρ_max−1)` y el ejemplo entero
  `I_max = 4 666` son correctos bajo `Lrev = 7 050`, `W_dec = 20 slots`, `ρ_max = 2,5`.
  `√(Lrev/W_dec) ≈ 18,775` es solo una cota continua necesaria: con `I` entero, el máximo
  factible de ese ejemplo es `7426/396 ≈ 18,7525` (derivado, no parámetro elegido).
- `INFORME.md:30-31` publica q99 `9 280→6 528` y `19 072→16 256`, mientras el artefacto
  `resultados/ESCENARIOS.txt:17-18` registra `9 280→6 464` y `19 008→16 192`. El informe
  mezcla también `V_max` determinista con anclas ajenas y offset cero con q99 de anclas mixtas
  (`α = 0,33`) y offset aleatorio; ambas comparaciones internas son pares distintos.
- `run.jl` registra `--seed`, pero las tablas aleatorias de `src/escenarios.jl` fijan `0x5a5a`.
  En `bench/benchmarks.jl`, los perfiles rotulados 2/4/8/16 hilos ejecutan en realidad todos los
  hilos del proceso siempre que `nthreads > 1` (`src/rapido.jl:195-205`). La tabla de escalado no
  mide esos números de hilos.
- Los costes `prove = 1,561 s/slot` y `verify = 96,1 ms/slot` son medidas de **un** slot a
  `N = 200 032 000` iteraciones (`research/dag-poas-ancla-de-orden.md:342`), mientras el cálculo
  de tamaño usa `N = 206 557 520`; no se midió la segunda cadena. Exponer solo las funciones
  AES internas no basta para `T ≈ 1,456·10¹²`: también reciben un contador `u32` por tramo.
- Si la entropía de `C-FLU-10` depende del segundo AES, `C-FLU-14` no puede seguir calificándose
  automáticamente «sin AES» antes de la caché. Hace falta definir cómo se acredita esa salida
  desde el pasado o cómo devuelve `Pendiente` sin circularidad. Las anclas de SDV-v1 no forman
  trazas DAG verificadas bajo las reglas destino; `V` es una métrica de frontera, no finalidad.

## Comprobación y siguiente versión

Se reejecutó `test/runtests.jl` en el proyecto aislado con Julia CPU y un hilo: **64/64 pasan**.
Ese resultado confirma coherencia interna del programa, con los límites anteriores. No se
regeneraron los artefactos ni se modificaron `SPEC.md`, `TAREAS.md`, `ci/` o `crates/` en esta
revisión.

Antes de usar H3 para una decisión, el instrumento debe modelar `r_j`, `c_j`, duración y agenda
de cada línea, incluyendo anclas ajenas, propias y candidatos especulados; comprobar que sus
trazas satisfacen las reglas destino; corregir semilla CLI, benchmark e informe frente a las
salidas generadas; y medir o dejar explícitamente pendiente la primitiva de la cadena larga.
