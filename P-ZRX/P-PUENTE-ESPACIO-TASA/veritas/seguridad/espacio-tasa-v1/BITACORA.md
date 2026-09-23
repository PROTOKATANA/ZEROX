# BITÁCORA — espacio-tasa-v1

Registro cronológico. Lo que se hizo, lo que falló y cómo se detectó. Los defectos **no** se borran:
son parte del resultado y de la evidencia de que las comprobaciones funcionan.

## 1 · Reconocimiento

1. **Estado del árbol.** `git status --short` registrado al inicio
   (`resultados/GIT-ENTRADA.txt`). El árbol tiene cambios y directorios ajenos (crates, P-ZRX,
   SPEC…), que se conservan intactos.
2. **Zona de escritura.** `findmnt` revela que `/home` está montado `ro` y que el **único**
   subvolumen escribible es `P-ZRX/P-PUENTE-ESPACIO-TASA/`. Se decide escribir el instrumento ahí,
   declarándolo en `INFORME.md` §10 y en `PRESUPUESTO.md`.
3. **Julia.** `which julia` no lo encuentra, pero `veritas/julia.sh` sí: juliaup vive en
   `/home/katana/torio/.juliaup`. Versión **1.13.0**. El depósito por omisión (`/home/katana/.julia`)
   es de **solo lectura**, así que se crea un depósito aislado dentro del instrumento y se compone:
   `JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia"`.
4. **Fuente fijada.** El clon compilable existe en `/home/katana/zeo/fuentes/subspace` @ `f8842d0`,
   limpio. `ab-proof-of-space` y `subspace-kzg` son dependencias **por ruta**, así que un oráculo
   Rust contra la API pública es viable. Se copia el patrón de `P-INTENTO/investigacion/banco-rust`.

## 2 · Construcción del oráculo Rust

5. Se escribe `oraculo-rust/` con cuatro subcomandos (`vectores`, `bits`, `audita`, `prueba`) y una
   librería que recompone la secuencia del plotter (`plotting.rs:615-680`) y del auditor
   (`auditing.rs:198-271`) usando **solo** primitivas del clon.
6. **D1 · `Invalid scalar`.** `ScalarBytes` es **big-endian con el byte 0 reservado**: los 31 bytes
   útiles van en `1..32` (`shared/subspace-kzg/src/lib.rs:123-130`). Poner a cero el byte 31 no
   garantiza nada. Corregido; queda escrito.
7. **D2 · `malloc(): corrupted top size` con la ruta serial.** `create_proofs` (serial) corrompe el
   montón a partir de ~64 piezas. Es **el mismo defecto** que P-INTENTO §13 documentó como SIGSEGV
   reproducible, con la misma mitigación: usar la ruta **paralela**, que además es **la que usa el
   plotter honesto** (`chia_v2.rs:37-41`). Se añade un interruptor `PUENTE_TABLA=serial|paralela` y
   un **control**: para las 24 piezas donde la serial no falla, los dos caminos producen
   `bitmaps.bin` **byte a byte idénticos** (`sha256 66fcaf890a80…`). Es decir, la ruta paralela es un
   sustituto **fiel**, no una aproximación.
8. **D3 · Desbordamiento de pila.** Con 1000 piezas, `fatal runtime error: stack overflow` en los
   hilos de rayon (2 MiB por omisión). Las tablas chiapos consumen varios MiB de pila por llamada.
   Corregido con `stack_size(64 MiB)`.
9. **D4 · `TablesCache` compartida.** `malloc(): corrupted top size` al compartir una sola caché
   entre hilos. Es **memoria de trabajo por llamada**; el banco de P-INTENTO ya la crea dentro de
   cada ámbito concurrente (`escalado.rs:135,160,180`). Corregido: una caché por pieza.

## 3 · Medición

10. **`vectores`**: 9 casos × 13 valores de `SR`, y `rank/select` contrastado contra
    `Proofs::for_s_bucket` en **los 65 536 buckets**.
11. **`prueba`**: 1 candidato con `SR = u64::MAX`; su prueba PoS **verifica** con `is_proof_valid`
    real y la copia con un byte invertido **se rechaza**.
12. **Control serial↔paralelo** (§7): bitmaps idénticos.
13. **`bits`**: 1000 piezas reales en **75,20 s** (13,30 tablas/s, 16 hilos).
14. **`audita`**: 1000 piezas en 74–90 s; 4608–6144 auditorías en ≤ 0,44 s.
15. Se detecta que los pares se evaluaban con `SR = u64::MAX`, donde **todo chunk gana** y la
    estadística conjunta de candidatos degenera en la de oportunidades. Se añade `--sr-pares` y se
    reejecuta con cuatro `SR` discriminantes.

## 4 · Análisis Julia

16. **D5 · Bucle de prueba.** La primera versión de `-%` no existe en Julia; la aritmética de
    enteros **ya envuelve**. Corregido.
17. **D6 · Precedencia en `rank_select`.** En Julia `&` liga **más fuerte** que `-`, así que la
    máscara de bits inferiores salía mal. Lo detectó `eq_rank_select`. Corregido con paréntesis
    explícitos y comentario.
18. **D7 · Desplazamiento de bucket en el kernel paralelo.** La primera versión usaba el índice
    **local** de la vista de columnas para calcular el bucket, así que cada bloque escribía sus
    cubos desde el bucket 0. **Los totales se conservaban**, por lo que la suma no lo delataba: se
    detectó porque `eq_conservacion_paralelo` comparó contra el serial. El test original usaba
    `nthreads()` = 1, con un solo bloque, y **pasaba**. Ahora prueba 1, 2, 3, 5, 7, 16 y 33 bloques.
    Es el defecto más instructivo del trabajo: una comprobación que existía pero no ejercía el
    camino.
19. **D8 · Independencia mal escalada.** Se comparaba `P(≥1 ganador)` **por par** con
    `1−(1−p₁)(1−p₂)` **por chunk**: error de nivel de agregación. Corregido a
    `1−(1−p)^leidos_i(1−p)^leidos_j` promediada por par.
20. **D9 · Microbanco hoisteado.** `u64_le` medía 2 ns para 100 000 lecturas porque LLVM extraía la
    lectura del bucle (entrada constante). Corregido variando el offset: 0,614 ns/op. Es el
    antipatrón «una medición imposible es un defecto, no un récord».
21. **D10 · Etiqueta de `p`.** `SR = 144 115 188 075 855 870` da `p = 1/128`, no `1/256`.
    Corregido.
22. **D11 · Dos cifras mal etiquetadas en `CIFRAS.tsv`.** `candidatos_por_slot_SR_calibrado` sumaba
    **dos** retos, y `blue_work` llevaba una unidad incorrecta (`2^128/slot`). Corregido: la primera
    pasa a ser la medida de un reto; la segunda pasa a «unidades de peso/slot» y se declara
    `condicionado` con el dato que falta.

## 5 · Cierre

23. **Pruebas**: 40 446 / 0 fallos con `--check-bounds=yes` y un hilo.
24. **Rendimiento**: kernel 22,81× sobre el oráculo lento, 0 asignaciones; escalado 1→24 medido
    (6,72× en 24 bloques, eficiencia 0,28). Decisión: conservar el kernel **serial** porque la etapa
    cuesta 5 ms frente a los 75 200 ms de generar el sector.
25. **`@code_warntype`**: sin `Any` en el camino caliente. **Perfil**: las líneas calientes son las
    que predice el modelo de coste.
26. **Integridad**: `git status --short` al final **idéntico** al del inicio. El clon quedó limpio.
    Ninguna ruta fuera de este instrumento cambió.

## 6 · Ronda de corrección (revisión 1 → revisión 2)

27. **`git status --short` al inicio de la ronda**, idéntico al de la ronda anterior. Aparecen
    directorios ajenos nuevos (`P-ZRX/P-RIVAL/`, `P-ZRX/P-SELLO/`): se conservan intactos.
28. **`sha256sum -c HUELLAS.sha256` sale 1.** Única discrepancia: `./HUELLAS.sha256`, es decir, el
    manifiesto incluía su propia huella. Se corrige el mecanismo (excluirse a sí mismo) y se añade
    `verificar-huellas.sh`, que además comprueba la ausencia de autorreferencia y el estado del clon.
29. **Contraste de la fila de 1 EiB** con `resultados/PUENTE.tsv`: los valores publicados estaban mal
    por factores de hasta 10³. Se decide **generar** las tablas (`TABLA-PUENTE.md`,
    `TABLA-CANDIDATOS.md`, `TABLA-VARIANZA.md`) desde los datos y citarlas, en vez de teclearlas.
30. **Se escribe `constantes` en el oráculo Rust** para leer los tamaños de la API del clon en lugar
    de recomponerlos a mano. Resultado inesperado y decisivo: `sector_record_metadata_size_1000 =
    128 000`, no 96 000. `RecordMetadata` incluye un `piece_checksum` de 32 B
    (`sector.rs:139-152`). Todo el modelo de bytes estaba 32 000 B corto por sector, y con él las
    piezas por TiB de `PUENTE.tsv`. Corregido en `referencia.jl` y contrastado en un test.
31. **Se retira `alfa_tasas`** y se sustituye por `RepartoBytes`/`fracciones`/`cuota_azul`. Se añade
    el test adversarial pedido: `f = 0,3`, `β_a = 1`, `β_h = 1/2` → **6/13 ≈ 0,461538 > 0,3**.
    `cuota_azul(0, 0)` devuelve `nothing`.
32. **Se corrige el diseño estadístico.** Los 2 016 pares se construyen con 64 retos; se retira el
    «−2,5 σ» y se sustituye por un bootstrap de bloques sobre los 64 retos. La primera versión del
    bootstrap que escribí era O(n²·pares) con `findfirst` por par (≈3·10⁹ operaciones); se reescribió
    con matrices indexadas por reto.
33. **Se demuestra que la razón compartir/repartir es 2 exacta** promediando las dos asignaciones de
    las mitades, y que el 2,0028 publicado era el sesgo de usar una sola. Se publican ambas columnas
    etiquetadas `identidad` y `sesgo de diseno`.
34. **Se separan las dos varianzas** (163,1689 sobre la población de buckets; 136,4329 sobre los 512
    retos; 66,0167 con denominador Poisson) en una tabla generada.
35. **Se corrige el rótulo de la cota de cola**: `1−0,05^{1/512}` acota `P(≥1 candidato)`, no
    `P(0)`.
36. **Se rebaja el alcance del oráculo**: registros fuente sintéticos, 8 192 000 B materializados,
    ninguna solución por `verify_solution`. `pruebas_completas_validas` → `pruebas_pos_validas`. La
    verificación completa queda `pendiente` con bloqueo reproducible.
37. **Se corrige el enunciado sobre la ruta serial**: se mantiene como defecto **reproducido**, sin
    afirmar que comparte causa raíz con el SIGSEGV de P-INTENTO.
38. **Cierre.** 40 891 / 0 fallos en los dos perfiles; `verificar-huellas.sh` termina en **0**;
    `git status --short` final idéntico al inicial; clon limpio.

39. **Revisión independiente** encargada a un agente separado (solo lectura, 8 afirmaciones con
    instrucción de refutarlas). Veredicto: 5 verificadas, 2 verificadas con matices, 1 parcialmente
    refutada. La revisión encontró **6 defectos reales** (D-r1…D-r6, `METODO.md`).
40. **La única afirmación sustantiva que cayó** fue la universalidad del «cociente = 2 para todo
    par»: `reparto_exclusivo` devolvía `Inf` en los 10 pares de 2016 con los dos buckets vacíos.
    La identidad correcta es `promedio = compartido/2`, que sí vale para todo par. Corregido el
    código, el docstring, los tests y el informe, y se publica el número de pares degenerados.
41. **Erratas menores corregidas**: nota del desglose de bytes en `constantes.tsv` (omitía el
    `piece_checksum`), 2 016 líneas en blanco en `audita-pares.tsv` (un `\n` de más por par),
    convención `/(n−1)` frente a `/n` en la tabla de varianza, cota unilateral frente a bilateral, y
    `f_bytes_solicitados` redondeado.
42. **Cierre de la ronda 3.** 41 094 / 0 fallos en los dos perfiles; `verificar-huellas.sh` en **0**;
    `git status --short` sin ningún fichero versionado cambiado; clon limpio.

43. **Ronda 4: separación de los dos escenarios de reparto.** El encargo pide separar
    «presupuestos independientes» (principal) de «sectores ya ploteados y repartidos», que estaban
    mezclados. Se lee `veritas/LINEO.md` íntegro antes de tocar los tests, como exige el propio
    LINEO §5.1 y el encargo.
44. **Test exacto pedido**: 1 TiB con el adversario al 1 % → `⌊10 995 116 277/s⌋ = 10`,
    `⌊1 088 516 511 499/s⌋ = 1029`, **total 1039**, cuota **10/1039** (no `10/1040`), con
    `s = 1 056 896 064`. El `SR` experimental se recalibra sobre `Σ piezas = 1 039 000`.
45. **Propiedad `Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋`** añadida con test aleatorio (200 casos) y tabla de
    `N` identidades. El hallazgo: con 1041 identidades cada una recibe `1 056 207 135 B` < un sector,
    y **el espacio efectivo total es cero** aunque el total dé 1040 sectores. Defecto propio
    corregido en el camino: `sin_sector` contaba un vector de un elemento.
46. **Contradicciones limpiadas**: `piezas·96` → `piezas·128` con `piece_checksum` en
    `PROCEDENCIA.md`; «mismo defecto» que el SIGSEGV retirado de `METODO.md` D1 sin prueba;
    «razón = 2 para todo par» reescrito en `INFORME-CORRECCION.md` con el caso `0/0`; y la
    afirmación de identidad de `git status` corregida —**no** son idénticos, aparecieron
    `?? P-ZRX/P-RIVAL/` y `?? P-ZRX/P-SELLO/`, que son ajenos y **no se atribuyen**—.
47. **Cierre de la ronda 4.** 41 750 / 0 fallos en los dos perfiles; `verificar-huellas.sh` en 0;
    ningún fichero versionado cambiado; clon limpio.

48. **Ronda 5: tabla de identidades.** Se retira la conclusión general «1041 identidades ⇒ cero
    espacio efectivo»: solo vale bajo la hipótesis `piezas_por_sector = 1000`, que es un **máximo** y
    no una exigencia (`SectorMetadata.pieces_in_sector` es un `u16`). Contraejemplo verificado:
    `sector_size(999) = 1 055 839 168 B` cabe en el presupuesto de 1 056 207 136 B, incluso con los
    131 116 B de metadata externa.
49. **El reparto de `T` entre `N` perdía `T mod N` bytes.** Con `T = sector_size(1000)` y `N = 5` el
    agregado daba 0 sectores cuando `T` contiene exactamente 1. Nuevo `reparto_igual_exacto` (reparte
    el resto) y agregado calculado **directamente desde `T`**.
50. **«La pérdida crece con `N`» era falso**: no es monótona (`N=7` pierde 4, `N=10` pierde 0). Se
    publica la cota `perdidos ≤ N`.
51. **`fraccion_candidatos_esperada` retirada**: mezclaba un presupuesto independiente con los
    sectores agregados y daba `10/1040` donde el escenario 1 da `10/1039`. Sustituida por
    `cuota_piezas_escenario1` y `fraccion_candidatos_esperada_esc1`.
52. **Cierre de la ronda 5.** 41 816 / 0 fallos en los dos perfiles; `verificar-huellas.sh` en 0;
    ningún fichero versionado cambiado; clon limpio.

## 7 · Lo que quedó abierto

* `β` (H-BETA) y por tanto `blue_work/slot`: **no medido**.
* El coste de un adversario que elige `sector_id` para sesgar su bucket: **no medido**.
* La verificación completa de una solución (KZG, firma, puerta contextual): **no ejecutada por
  ninguna ruta de ZEROX**.
* El coste de disco real (se cita la medición de P-INTENTO; no se repitió con caché fría).
* GPU: **no aplica**; el problema es aritmética entera y hashes, no un kernel regular dominante
  (LINEO §5.7).
