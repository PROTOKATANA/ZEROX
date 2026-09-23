# MÉTODO — espacio-tasa-v1

Todos los comandos están ejecutados y su salida está en `resultados/`. Ninguna cifra del informe se
teclea a mano.

## 0 · Entorno

```bash
cd P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1
export JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia"   # depósito aislado, HOGAR es de solo lectura
J=/home/katana/zeo/ZEROX/veritas/julia.sh                          # fija PATH de juliaup y quita LD_LIBRARY_PATH
```

`/home/katana/zeo/ZEROX` está montado **de solo lectura** en esta sesión (`findmnt` lo confirma);
el único punto escribible es este instrumento. Por eso el **depósito de Julia vive dentro del
instrumento** y se compone con el del sistema (`:` separa escritura y lectura).

Dependencias fijadas en `Manifest.toml`: `Arblib 1.8.1`, `BenchmarkTools 1.8.0`,
`Distributions 0.25.131`, `JET 0.12.1`, `Random123 1.7.1`, `SpecialFunctions 2.9.0`,
`StableRNGs 1.0.4`, `StatsBase 0.34.13`. Julia **1.13.0**.

## 1 · Oráculo Rust (una vez; ~5 min en total)

```bash
cd oraculo-rust
export CARGO_TARGET_DIR="$PWD/target" CARGO_NET_OFFLINE=true
cargo build --release
cd ..
export RAYON_NUM_THREADS=16
BIN=./oraculo-rust/target/release/puente

# 1a · Contabilidad de bytes EXACTA leída de la API del clon (instantáneo, sin tablas PoS)
$BIN constantes --out resultados

# 1b · Casos mínimos para el contraste de byte order, bucket y predicado (~19 s)
$BIN vectores --out resultados

# 1c · Verificación de la prueba PoS de candidatos + candidato con un byte invertido (<1 s)
$BIN prueba --out resultados

# 1d · Control serial↔paralelo de la generación de tablas (~19 s)
PUENTE_TABLA=serial   RAYON_NUM_THREADS=1  $BIN bits --piezas 24 --retos 4 --hilos 1  --out resultados/control-tabla/serial
PUENTE_TABLA=paralela RAYON_NUM_THREADS=16 $BIN bits --piezas 24 --retos 4 --hilos 16 --out resultados/control-tabla/paralela
cmp resultados/control-tabla/serial/bitmaps.bin resultados/control-tabla/paralela/bitmaps.bin

# 1e · Medición principal: 1000 piezas (geometría de un sector), 512 retos (~75 s)
$BIN bits --piezas 1000 --retos 512 --hilos 16 --out resultados

# 1f · Auditoría real: 1000 piezas × 512 retos × 12 SR, y 2016 pares × 4 SR (~90 s)
$BIN audita --piezas 1000 --retos 512 --hilos 16 --out resultados \
  --sr "0,1,3,4096,1048576,4294967296,6148914691236495,144115188075855870,2305843009213693950,9223372036854775806,18446744073709551614,18446744073709551615" \
  --sr-pares "9223372036854775806,2305843009213693950,144115188075855870,6148914691236495"
```

Los valores `SR` son **escenarios experimentales**, no decisiones de consenso. `6_148_914_691_236_495`
es el que `pieces_to_solution_range(1000, (1,6))` daría para una red de 1000 piezas; se incluye para
tener un régimen realista además de los bordes.

Presupuesto real consumido por corrida: ≤ 16 hilos, ≤ 2 GiB de RAM, ≤ 79 s de pared. Muy por debajo
del techo declarado en `PRESUPUESTO.md`.

## 2 · Análisis Julia

```bash
# Perfil de referencia de CI: un hilo y @inbounds neutralizado (~3 s)
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 $J --check-bounds=yes --project=. test/runtests.jl

# Tablas del informe (OCUPACION, AUDITORIA, CANDIDATOS, PUENTE, IDENTIDADES, FLUJOS, CIFRAS)
# y sus espejos markdown generados (TABLA-PUENTE.md, TABLA-IDENTIDADES.md, ...)
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 $J --project=. run.jl --piezas 1000 --retos 512
```

## 3 · Rendimiento

```bash
# Microbenchmarks: valida kernel↔oráculo ANTES de medir
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 $J --project=. bench/benchmarks.jl

# Escalado 1..24: un proceso por número de hilos (se fija al arrancar)
for H in 1 2 4 8 16 24; do
  JULIA_NUM_THREADS=$H OPENBLAS_NUM_THREADS=1 $J --project=. bench/escalado.jl $H
done

# Inferencia de tipos y perfil
JULIA_NUM_THREADS=1 $J --project=. bench/warntype.jl
JULIA_NUM_THREADS=1 $J --project=. bench/perfil.jl
```

## 4 · Contraste con el código fijado

Cuatro caminos independientes, todos automáticos en los tests:

1. **Byte order y predicado.** `resultados/vectores.tsv` trae `audit_chunk`, reto, distancia y
   veredicto calculados por el código fijado para 13 valores de `SR`. Julia relee en little-endian,
   recalcula la distancia con su kernel y compara: `eq_rust_byte_order`.
2. **Derivación del bucket.** `vectores-buckets.tsv` trae `SectorId`, reto, `ssc` y bucket. Julia
   rehace el XOR de 32 B y el `u16` LE: `eq_rust_bucket`. Además, sobre el barrido completo de 512
   retos, Julia deriva el bucket y lee su propio contador de ocupación, y lo compara con la columna
   `chunks_leidos` que escribió Rust auditando la misma parcela: `eq_buckets_propios` y
   `leidos_julia_vs_rust` (`coincidencia Julia↔Rust … true`).
3. **`rank/select`.** `contrastar_rank_select` recorre los 65 536 buckets de una pieza y compara el
   índice denso local con `Proofs::for_s_bucket` del clon (`buckets_contrastados_rank_select = 65536`).
4. **Prueba completa.** `resultados/prueba.tsv`: cada candidato ganador se verifica con
   `is_proof_valid` real, y una copia con un byte invertido **debe** ser rechazada
   (`pruebas_corruptas_aceptadas = 0`).

Si cualquiera de estos contrastes discrepa, el programa **falla** (los `assert`/`@test` están dentro
del camino de cálculo). No hay modo de publicar una cifra con el contraste roto.

## 5 · Verificación de integridad (corregida)

```bash
bash verificar-huellas.sh ; echo "EXIT=$?"
```

Dos manifiestos, con destinatarios distintos: `ENTRADA.sha256` (documentos de ZEROX, rutas
relativas a la raíz) y `HUELLAS.sha256` (instrumento, rutas relativas a este directorio).
El script termina con **código de salida 0** y su salida está en
`resultados/VERIFICACION-HUELLAS.txt`.

**Defecto corregido (D-c8).** `HUELLAS.sha256` se generaba incluyendo su **propia** huella, así que
`sha256sum -c HUELLAS.sha256` fallaba siempre con «La suma no coincide» en `./HUELLAS.sha256` y
salía 1. Ahora el manifiesto **excluye su propio fichero** y el script comprueba explícitamente que
no haya una línea de huella apuntando a él. **No se alteró ningún dato para cuadrar huellas** —de
hecho, el mecanismo detectó correctamente que un fichero listado había cambiado tras editar el
script, que es justo lo que debe hacer.

Reproducir el manifiesto (tras cualquier cambio):

```bash
{ echo "# Huellas del instrumento espacio-tasa-v1 (fuente, documentos y artefactos)."
  echo "# NO incluye HUELLAS.sha256: un manifiesto no puede contener su propia huella."
  find . -type f \( -name '*.jl' -o -name '*.toml' -o -name '*.rs' -o -name '*.md' -o -name '*.tsv' \
       -o -name '*.txt' -o -name '*.sha256' -o -name '*.bin' -o -name 'Cargo.lock' -o -name '*.sh' \) \
    -not -path './.julia-depot/*' -not -path './oraculo-rust/target/*' \
    -not -path './resultados/control-tabla/*' -not -name 'HUELLAS.sha256' \
    | LC_ALL=C sort | xargs sha256sum ; } > HUELLAS.sha256
```

## 6 · Defectos encontrados durante la construcción

Se documentan porque cambian el método y porque su detección es parte del resultado.

| # | Defecto | Cómo se detectó | Estado |
|---|---|---|---|
| D1 | **`create_proofs` serial corrompe el montón** para ciertas semillas derivadas de `(sector_id, piece_offset)`: `malloc(): corrupted top size` a partir de ~64 piezas. P-INTENTO §13 documentó un **SIGSEGV** reproducible para ciertas semillas en la misma función serial. **No se afirma que sea el mismo defecto:** los síntomas son distintos (corrupción de montón frente a violación de segmento), los binarios y perfiles no coinciden, y P-INTENTO declaró la causa raíz **«no determinada»**. Lo único comprobado aquí es que la **mitigación** coincide: la ruta paralela no falla y da bitmaps idénticos. | Ejecución de `bits --piezas 1000` | **Esquivado**: se usa `create_proofs_parallel`, que es **la ruta del plotter honesto** (`chia_v2.rs:37-41`). Control: serial y paralela producen `bitmaps.bin` **byte a byte idénticos** (`sha256 66fcaf89…`) para las 24 piezas donde la serial no falla. |
| D2 | **Desbordamiento de pila** en los hilos de rayon (2 MiB por omisión) al generar tablas chiapos. | `fatal runtime error: stack overflow` | **Corregido**: `stack_size(64 MiB)` en las dos piscinas de trabajo. |
| D3 | **`TablesCache` no se puede compartir entre hilos**: `malloc(): corrupted top size` en cuanto se comparte. | Ejecución concurrente | **Corregido**: una caché por llamada, igual que hace el banco de P-INTENTO (`escalado.rs:135,160,180`). |
| D4 | **Desplazamiento de bucket relativo en el kernel paralelo**: cada bloque escribía sus cubos desde el bucket 0 en vez de desde el del bloque. Los totales se conservaban, así que la suma no lo delataba. | `eq_conservacion_paralelo` con **varios** números de bloques | **Corregido**. Con un solo bloque el defecto no aparece: el test original usaba `nthreads()`=1 y pasaba. Ahora prueba 1,2,3,5,7,16,33. |
| D5 | **Precedencia de operadores en `rank_select`**: en Julia `&` liga **más fuerte** que `-`, así que la máscara de bits inferiores salía mal. | `eq_rank_select` sobre bitmaps sintéticos | **Corregido** con paréntesis explícitos. |
| D6 | **Escalares inválidos**: `ScalarBytes` es big-endian con el byte 0 reservado; poner a cero el byte 31 no garantiza nada. | `Invalid scalar` en la primera ejecución | **Corregido**: los 31 bytes útiles van en `1..32` (ver `subspace-kzg/src/lib.rs:123-130`). |
| D7 | **Hipótesis de independencia mal escalada**: se comparaba `P(≥1)` **por par** con `1−(1−p₁)(1−p₂)` **por chunk**. | Revisión del resultado en `FLUJOS.tsv` | **Corregido**: la referencia ahora es `1−(1−p)^leidos_i·(1−p)^leidos_j` promediada por par, al mismo nivel de agregación. |
| D8 | **Microbanco hoisteado**: `u64_le` medía 2 ns para 100 000 lecturas porque LLVM extraía la lectura del bucle. | Resultado físicamente imposible | **Corregido**: la entrada varía por offset; ahora 0,614 ns/op. |
| D9 | **Etiqueta de `p` equivocada**: `SR=144115188075855870` da `p = 1/128`, no `1/256`. | Recálculo de `A(SR)` | **Corregido** en el comentario y en el informe. |

### Defectos de la **revisión 2** (ronda de corrección)

| # | Defecto | Cómo se detectó | Corrección |
|---|---|---|---|
| D-c1 | **`α_blue_work ≤ α_bytes` es falso** y `(β_adv/β_hon)·α_bytes` no es una cuota normalizada. | Revisión del encargo; álgebra. | Se retira de informe, contrato, hipótesis y tests. Se añaden `cuota_azul` (denominador cero → `nothing`) y `cuota_azul_condicional`. Test adversarial: `f = 0,3`, `β_a = 1`, `β_h = 1/2` → **6/13 ≈ 0,461538 > 0,3**. |
| D-c2 | **`alfa_tasas` llamaba «fracción de bytes» a una razón de piezas** y presentaba `α_candidatos = α_bytes` como validación experimental. | Revisión. | Se retira. Se añaden `RepartoBytes`, `fracciones` y `cuota_azul`. (La `fraccion_candidatos_esperada` inicial se **retiró** después: ver D-e9.) Se distinguen bytes solicitados / de sectores completos / piezas efectivas / bytes materializados, con test del caso con sobrantes. |
| D-c3 | **`pruebas_completas_validas` era un rótulo engañoso**: `is_proof_valid` no es `verify_solution`. | Revisión. | Clave renombrada a `pruebas_pos_validas` en Rust y Julia; la verificación completa queda `pendiente` con bloqueo reproducible. |
| D-c4 | **Los 2 016 pares no son independientes** (64 retos únicos) y el «−2,5 σ» presuponía que sí. | Revisión. | Se retira el σ. Incertidumbre por **bootstrap de bloques sobre los 64 retos** (`ET.bootstrap_unidades`). |
| D-c5 | **`RecordMetadata` es 128 B, no 96**: faltaba el `piece_checksum`. `sector_size(1000)` salía 32 000 B corto. | `oraculo-rust ... constantes`, que lee el tamaño de la API en vez de recomponerlo a mano. | `sector_size(1000) = 1 056 896 064`; constante `PIEZA_CHECKSUM_SIZE`; test contra `constantes.tsv`. |
| D-c6 | **Fila de 1 EiB con transcripción manual errónea** (sectores y piezas del adversario). | Contraste con `resultados/PUENTE.tsv`. | `PUENTE.tsv` regenerado con las fracciones correctas y `TABLA-PUENTE.md` **generada** desde los mismos datos. |
| D-c7 | **Cota de cola invertida**: `1−0,05^{1/512}` se etiquetaba como cota de `P(0 candidatos)`. | Revisión. | Etiquetada como cota de **`P(≥1 candidato por slot)`**; de ella se sigue `P(0) ≥ 0,99417`. Columna nueva en `CANDIDATOS.tsv`. |
| D-c8 | **`HUELLAS.sha256` se autorreferenciaba** y `sha256sum -c` fallaba con salida 1. Además, el **informe de la verificación** también estaba en el manifiesto y el script lo reescribe: autorreferencia de segundo orden. | `sha256sum -c HUELLAS.sha256` al inicio de la ronda. | El manifiesto excluye **los dos** ficheros autorreferentes; `verificar-huellas.sh` comprueba ambas ausencias y termina en **0**, de forma idempotente. |
| D-c9 | **La razón 2,0028 se publicaba como medición** de pérdida de seguridad. | Revisión. | Se demuestra que promediar las **dos** asignaciones de las mitades da `compartido/2`, luego la razón es **2 exacto por construcción**; `ET.reparto_exclusivo` lo calcula y el test lo fija. Se publican ambas columnas, etiquetadas `identidad` y `sesgo de diseno`. |
| D-c10 | **Extrapolación a varios sectores sin hipótesis declarada.** | Revisión. | La tabla de escala se marca `derivado` bajo **independencia entre sectores, no medida**; solo `S = 1` es `medido`. |
| D-c11 | **No se declaraba que los registros fuente son sintéticos** ni que no se materializó un sector físico. | Revisión. | Declarado en `INFORME.md` §0, `CONTRATO.md` §1 y en este documento. |
| D-c12 | **`hex32` muerto en Rust** y `SpecialFunctions` declarada sin usarse. | Compilación / revisión. | Retirados. |

### Defectos de la **revisión independiente** (ronda 3)

| # | Defecto | Cómo se detectó | Corrección |
|---|---|---|---|
| D-r1 | **`reparto_exclusivo` devolvía `Inf` en el caso `0/0`** y el docstring afirmaba «cociente = 2 para todo par». En los datos reales, 10 de 2016 pares tienen los dos buckets vacíos. | Revisión independiente (A2, refutada). | `razon` es `nothing` si el denominador es 0; el docstring enuncia la identidad correcta (`promedio = compartido/2` para todo par); se publica el número de pares degenerados; tests del caso `0/0`. |
| D-r2 | **Nota errónea en `constantes.tsv`**: el desglose sumaba 8 192 064 y omitía el `piece_checksum`. | Revisión independiente (A3). | Nota corregida a `1000*32 + 1000*8192 + 32 + 32`; cita del mapa corregida a `sector.rs:362-364`. |
| D-r3 | **2 016 líneas en blanco** intercaladas en `audita-pares.tsv` (un `\n` de más por par). | Revisión independiente (A6). | Un `\n` eliminado en `cmd_audita`; el fichero pasa de 10 081 a 8 065 líneas. |
| D-r4 | **`TABLA-VARIANZA.md` llamaba «población completa» a los 65 536 buckets usando la varianza muestral** `/(n−1)`; y no decía cuántos buckets distintos cubre la muestra. | Revisión independiente (A7). | Publica **las dos** convenciones (163,1689 y 163,1664) y el número de buckets distintos (510). |
| D-r5 | **Cota de cola sin distinguir unilateral de bilateral** y con la interpretación «por slot» sin declarar. | Revisión independiente (A8). | `cota_superior_exacta_cero(n, conf; lados=:uno|:dos)`; informe con 5,83·10⁻³ unilateral, 7,18·10⁻³ bilateral y `P(0)` por slot. |
| D-r6 | **`f_bytes_solicitados` redondeado a 0,01** cuando es 0,009999999999 por truncamiento a bytes enteros. | Revisión independiente (A4). | El informe usa el valor del fichero. |

### Defectos de la **ronda 4** (escenarios de reparto)

| # | Defecto | Cómo se detectó | Corrección |
|---|---|---|---|
| D-e1 | **Los dos escenarios de reparto estaban mezclados.** `paso_puente` calculaba `⌊bytes_adv/s⌋` frente a los sectores del **total** ya truncado, lo que da a cada actor el beneficio de los sobrantes del conjunto. | Revisión del encargo. | Se separan: `presupuestos_independientes` (esc. 1, principal: trunca **por actor**, denominador `Σ piezas_i`) y `reparto_sobre_plot` (esc. 2: el total se trunca una vez y se reparte; la cuota **no** es presupuesto independiente). `PUENTE.tsv` y `TABLA-PUENTE.md` llevan columna `escenario`. |
| D-e2 | **`sin_sector` contaba un vector de un elemento** (`count(==(0), [x])`), así que informaba `1` en vez de `N`. | Contraste de la tabla de identidades contra la aritmética a mano. | Se cuenta `count(b -> b ÷ s == 0, partes)` con las partes reales. |
| D-e3 | **`paso_identidades` no existía**: no había tabla del efecto de `N`. | Requisito del encargo. | Nuevo paso, `IDENTIDADES.tsv` y `TABLA-IDENTIDADES.md`. |
| D-e4 | **`PROCEDENCIA.md:52` conservaba `piezas·96`** y citaba `sector.rs:367-380`. | Revisión del encargo. | Corregido a `piezas·128` con el `piece_checksum`, cita `:139-152` y `:362-364`. |
| D-e5 | **`METODO.md` D1 afirmaba sin prueba** que el fallo serial comparte causa raíz con el SIGSEGV de P-INTENTO. | Revisión del encargo. | Se mantiene como defecto **reproducido** y se declara que la causa raíz **no** está demostrada; lo comprobado es que la **mitigación** coincide. |
| D-e6 | **`INFORME-CORRECCION.md` A2 seguía diciendo** «la razón es 2 para todo par» pese al caso `0/0`. | Revisión del encargo. | Reescrito: la identidad es `promedio = compartido/2` para todo par; el cociente es 2 si `compartido > 0` e indefinido en los 10 pares degenerados. |
| D-e7 | **Se afirmaba que `GIT-ENTRADA.txt` y `GIT-SALIDA.txt` eran idénticos**, y no lo son: aparecieron `?? P-ZRX/P-RIVAL/` y `?? P-ZRX/P-SELLO/`. | `diff` de los dos ficheros. | Corregido en informe y en el informe de corrección. La comprobación automática ya no exige identidad del `??`: exige que **ningún fichero versionado** cambie. Los directorios ajenos **no se atribuyen** sin evidencia. |
| D-e8 | **No se distinguía el tamaño de plot de la metadata externa** al hablar de bytes físicos. | Revisión del encargo. | `sector_size()` es el fichero del plot; `SectorMetadataChecksummed` (131 116 B) es fija y externa. Test y documentación. |

### Defectos de la **ronda 5** (tabla de identidades)

| # | Defecto | Cómo se detectó | Corrección |
|---|---|---|---|
| D-f1 | **La conclusión «1041 identidades ⇒ cero espacio efectivo» se presentaba como general.** Solo vale bajo la hipótesis `piezas_por_sector = 1000`. | Revisión del encargo; `SectorMetadata.pieces_in_sector` es un `u16`. | Retirada como enunciado general. Se etiqueta la hipótesis en código, tablas e informe, y se añade el contraejemplo: `sector_size(999) = 1 055 839 168 B` cabe en 1 056 207 136 B (y con los 131 116 B de metadata externa: `1 055 970 284`). Nuevo `ET.piezas_que_caben` y columnas `piezas_max_que_caben` / `sector_si_ajusta_piezas`. |
| D-f2 | **El reparto de `T` entre `N` perdía `T mod N` bytes**: se usaba `fill(⌊T/N⌋, N)`, de modo que `Σbytes_i = N·⌊T/N⌋ < T`, y el agregado se calculaba sobre bytes ya perdidos. | Test pedido `T = sector_size(1000), N = 5`: el agregado daba 0 sectores cuando `T` contiene exactamente 1. | Nuevo `ET.reparto_igual_exacto` (reparte también el resto: `r` partes de `q+1` y `n−r` de `q`), y `perdida_agregacion` publica `suma` y calcula `agregado` **directamente desde `T`**. Test de conservación para 9 valores de `N`. |
| D-f3 | **«La pérdida crece con `N`» es falso**: no es monótona (con 1 TiB, `N=7` pierde 4 y `N=10` pierde 0). | Contraste de la propia tabla. | Retirado. Se publica la cota `perdidos ≤ N` (cada truncamiento pierde menos de un sector) y la desigualdad `Σ⌊·⌋ ≤ ⌊·⌋`. Test de no-monotonía y de la cota. |
| D-f4 | **`fraccion_candidatos_esperada(ra, rt; SR)` mezclaba un presupuesto independiente con los sectores agregados**: derivaba el lado honesto por **resta** del total truncado una vez. | Revisión del encargo. | **Retirada** (no delimitada: su firma invitaba al error). Sustituida por `cuota_piezas_escenario1` y `fraccion_candidatos_esperada_esc1`, que usan solo presupuestos independientes. Test que comprueba que ya no existe. |
| D-f5 | **El `+64` y los 1 056 896 B/pieza estaban como números mágicos** en `piezas_que_caben`. | Al escribir la función. | Constante `BYTES_POR_PIEZA_PLOT` derivada de los componentes del formato. |## 7 · Presupuesto y estado

Ninguna corrida se acercó a los topes de `PRESUPUESTO.md` (16 hilos, 8 GiB, 6 GiB de disco, 3 h).
Consumo real del instrumento en disco: **552 MiB** (`target/` de Cargo + depósito Julia + datos).
**No hubo presupuesto agotado y no hay resultados inconclusos por esa causa.**
