Un intento dirigido del sembrador cuesta **809 ms de un núcleo** (0,49 µs por reto adicional probado contra una tabla ya generada, o 1,4 ns si la tabla se cruza en lote), y una **CPU de 24 hilos emula de 0,0024 TiB a 23,9 TiB de disco honesto** según cuántos retos conozca por adelantado (`w` de 10² a 10⁶); iguala a un disco de 20 TB a partir de `w ≈ 7,6·10⁵`, no de miles.

> **Lo que mides es una cota SUPERIOR del coste del atacante.** Él puede tener mejor hardware y un
> kernel mejor que el de Autonomys. Ninguna cifra de este informe es el coste mínimo del ataque, y
> ninguna es una conclusión económica: **no hay precios y no se inventan**.

# Investigación P-INTENTO

## Índice

1. [Estado y alcance](#1--estado-y-alcance)
2. [El ataque, comprobado contra el código fijado](#2--el-ataque-comprobado-contra-el-código-fijado)
3. [Qué se midió y cómo](#3--qué-se-midió-y-cómo)
4. [Control obligatorio contra los 83,6 s por GiB](#4--control-obligatorio-contra-los-836-s-por-gib)
5. [M1 · `t_tabla`](#5--m1--t_tabla)
6. [M2 · `t_reto`](#6--m2--t_reto)
7. [M3 · `t_ganador`](#7--m3--t_ganador)
8. [M4 · cono mínimo de dependencia](#8--m4--cono-mínimo-de-dependencia)
9. [M5 · GPU](#9--m5--gpu)
10. [M6 · energía](#10--m6--energía)
11. [El modelo, sin precios](#11--el-modelo-sin-precios)
12. [A partir de qué `w` el sembrador iguala a comprar disco](#12--a-partir-de-qué-w-el-sembrador-iguala-a-comprar-disco)
13. [Hallazgo colateral: SIGSEGV reproducible para ciertas semillas](#13--hallazgo-colateral-sigsegv-reproducible-para-ciertas-semillas)
14. [Lo que esta investigación NO resuelve](#14--lo-que-esta-investigación-no-resuelve)
15. [Reproducción](#15--reproducción)

---

## 1 · Estado y alcance

**Categoría dominante:** `seguridad`. Secundarias: `rendimiento` (el banco Rust) y `almacenamiento`
(la conversión de piezas a TiB). Se declara en este informe por exigencia de `veritas/LINEO.md` §1.

**[Medido]** Todo lo que aparece con la etiqueta `medido` sale del banco Rust
(`investigacion/banco-rust/`) o de los bancos Criterion que ya trae el clon fijado, ejecutados en la
máquina de referencia. **[Derivado]** lo que sale de las fórmulas del §11. **[Estimado]** solo el
§13 y se dice allí. **[No determinado]** lo que no se pudo cerrar.

**Presupuesto declarado antes de ejecutar:** máximo **24 hilos**, **64 GiB de RAM**, **40 GiB de
disco temporal** (borrado al terminar) y **12 h de pared**. No se agotó. La GPU tenía su propio tope
de 1 h fijado por el encargo.

**Zona de escritura respetada:** solo `P-ZRX/P-INTENTO/investigacion/`. El clon
`/home/katana/zeo/fuentes/subspace` quedó intacto (comprobaciones de entrada y salida en
`PROGRESO.md`), todo `cargo` corrió con `CARGO_TARGET_DIR` dentro de la zona, y no se copió ni
modificó una línea de Autonomys: solo se llamó a su API pública.

---

## 2 · El ataque, comprobado contra el código fijado

El §1 del encargo describe el ataque. **Se comprobó línea a línea contra el código fijado** en lugar
de darlo por bueno. Confirma en lo esencial, y hay tres precisiones que cambian la forma de las
medidas.

**Lo que se confirma.**

- **[Verificado en fuente]** La tabla depende solo de la semilla; el reto solo elige el *s-bucket*:
  `ChiaV2TableGenerator::generate` → `Tables::<20>::create_proofs(seed)`
  (`crates/subspace-proof-of-space/src/chia_v2.rs:28-36`) y `find_proof(challenge_index)` →
  `for_s_bucket(SBucket::from(challenge_index as u16))` (`chia_v2.rs:64-68`).
- **[Verificado en fuente]** `s_bucket` = dos primeros bytes LE de
  `SectorId XOR global_challenge` (`crates/subspace-core-primitives/src/sectors.rs:32-39,117-123`);
  `Record::NUM_S_BUCKETS = 2^16` exacto (`crates/subspace-core-primitives/src/pieces.rs:561-567`).
- **[Verificado en fuente]** La unidad de aceptación es **una pieza**: el verificador abre una prueba
  PoS, un chunk y su testigo KZG (`crates/subspace-verification/src/lib.rs:228-270`) y no exige el
  sector completo ni una fecha de alta. Ya estaba demostrado en
  `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`; aquí no se redescubre.

**Precisión 1 — «la tabla» que el atacante conserva no son las siete tablas.** `ChiaV2Table`
almacena `Box<Proofs<20>>`: un mapa de presencia de **8.192 B** más 32.768 pruebas de 160 B =
**5.251.072 B (5,008 MiB)**. Las siete tablas se construyen y se destruyen dentro de
`create_proofs` (`shared/ab-proof-of-space/src/chiapos.rs:195-268`). **[Medido]** el objeto vivo son
5,008 MiB; el RSS observado crece 10,42 MiB por tabla retenida, que es una **cota superior** porque
incluye la retención del asignador. Es la primera cifra la que decide cuántas tablas caben a la vez.

**Precisión 2 — el test de «gana» no necesita el testigo, pero sí el chunk crudo.**
`calculate_solution_distance` se evalúa sobre el chunk **crudo**
(`crates/subspace-verification/src/lib.rs:118-146,245-254`) y el plotter guarda
`encoded = raw_chunk XOR blake3(proof)` con **cero** donde no hay prueba
(`crates/subspace-farmer-components/src/plotting.rs:646-655`). Consecuencia: el atacante sabe si hay
candidato y con qué distancia con el mapa de 8 KiB y 32 B del histórico; **el testigo solo se paga
si gana**. Esto *refuerza* el §1 y a la vez da forma a M2.

**Precisión 3 — la distribución de pruebas NO es uniforme, aunque su media sí sea 1/2.**
**[Medido]** (`banco-rust/src/bin/distribucion.rs`, 32 semillas): `create_proofs` produce **siempre
exactamente 32.768** pruebas (`PRUEBAS_MIN = PRUEBAS_MAX = 32768`) y **corta** al alcanzarlas
(`chiapos.rs:225-268`). La densidad es ≈ 0,587 por bucket hasta el índice ≈ 53.000, cae entre 53.000
y 58.410 y es **exactamente 0 por encima de ≈ 58.410**. Como el reto elige el bucket uniformemente,
la probabilidad **media** es exactamente `o = 0,5` (`O_MEDIDO = 0.500000`), que es lo que entra en
el modelo; pero `p` no es constante por bucket y los aciertos de una misma identidad se concentran
en buckets bajos.

---

## 3 · Qué se midió y cómo

### Máquina y entorno

| | |
|---|---|
| CPU | AMD Ryzen 9 9950X3D, 16 núcleos físicos / 32 hilos lógicos, 1 nodo NUMA |
| RAM | 123 GiB visibles |
| Gobernador | `powersave` (**no modificable sin root**; se registra, no se corrige) |
| GPU | GTX 1070 presente en PCI, módulos `nvidia*` cargados, **sin `/dev/nvidia*`** y sin root |
| Rust | `rustc 1.97.0-nightly (20de910db 2026-05-02)`, toolchain `nightly-2026-05-03` |
| Clon | `/home/katana/zeo/fuentes/subspace` @ `f8842d0`, árbol limpio antes y después |

**Todas las citas `archivo:línea` de este informe son del clon compilable**
`/home/katana/zeo/fuentes/subspace` @ `f8842d0`, no de la copia de lectura `PDF/autonomys-subspace/`
(que es el mismo commit). Se abrieron una por una; ninguna se hereda de un informe previo.
| Perfil | `bench` (hereda de `release`), `lto = false`, sin `-ffast-math`, sin `target-cpu=native` |
| Hilos | `RAYON_NUM_THREADS=24` en todas las corridas; `OPENBLAS_NUM_THREADS=1` |
| Julia | 1.13.0, `Manifest.toml` versionado, `JULIA_NUM_THREADS=1` |

Una sola carga a la vez. Ninguna medición se tomó con otro trabajo pesado corriendo.

### Banco Rust

`investigacion/banco-rust/` es un crate propio con **dependencias por ruta** al clon y su
`Cargo.lock` como punto de partida. Registra M1, M2, M3 y M4 con Criterion (mediana e intervalo) más
tres binarios de sonda (`escalado`, `cono`, `distribucion`). No usa nada privado: solo
`Tables::create_proofs`, `Tables::create_proofs_parallel`, `Tables::create`, `find_proof`,
`ErasureCoding::{extend,recover_poly}`, `Kzg::{poly,commit,create_witness}` e
`is_within_solution_range`.

El banco CPU tiene un defecto deliberado y documentado: **no hay ni una cifra tecleada**. El bin
`exportar_modelo` parsea las salidas crudas de Criterion y escribe
`mediciones/modelo-entrada.tsv`; el modelo Julia se niega a arrancar si falta una clave. Esto se
activó de verdad dos veces durante el trabajo (una por un formato de Criterion no contemplado),
y en ambas el modelo **falló en vez de inventar**.

### Bancos que ya traía el clon: qué aportó cada uno

Se ejecutaron **antes** de escribir banco nuevo, como pide el encargo. Los crudos están en
`mediciones/clon_*.txt`.

| Banco | Resultado medido | Para qué se usó |
|---|---|---|
| `subspace-farmer-components --bench plotting` | `plotting/in-memory` = **90,575 s** / 1.000 piezas | El **control** del §4 |
| `subspace-proof-of-space --bench pos` | `table/single/1x` = 727,77 ms; `table/parallel/1x` = 98,205 ms; `table/parallel/16x` = 751,71 ms (21,28 tablas/s); `proof/for-record` = 33,314 ms; `proof/missing` = 0,988 ns; `proof/present` = 2,552 ns | **Cruces independientes** de M1 y M2 (§5, §6) |
| `subspace-kzg --bench kzg` | `create-polynomial` = 1,376 ms; `commit` = 17,476 ms; `create-witness` = 18,200 ms; `verify` = 590,5 µs | Cruce de M3: coinciden con el banco propio (§7) |
| `subspace-farmer-components --bench proving` | `proving/memory` = **581,38 ms** por solución; `proving/disk` = 5,867 s / sector | Camino ganador extremo a extremo del prover honesto |
| `subspace-farmer-components --bench auditing` | `auditing/disk/sync` = **38,51 µs** por sector (1 sector) | Coherente con los 42,92 µs de `research/coste-ploteo-medido.md:81-85` (razón 0,90×) |

**No hubo que escribir banco nuevo para el control**, y ninguno de los cinco contradice al banco
propio: los tres cruces que se pueden comparar (`table/parallel/1x`, `proof/for-record`,
`create-witness`) caen dentro del 22 %.

### Comando exacto

```bash
cd P-ZRX/P-INTENTO/investigacion
./ejecutar-mediciones.sh suite     # M1..M4 + RAM + escalado, ~15 min
./ejecutar-mediciones.sh control   # bancos del clon, control de 83,6 s
$CARGO_TARGET_DIR/release/exportar_modelo mediciones
cd veritas/seguridad/intento-v1 && ./correr-modelo.sh
```

---

## 4 · Control obligatorio contra los 83,6 s por GiB

`research/coste-ploteo-medido.md:19-25` midió **83,608 s** por sector de 1.000 piezas
(`plotting/in-memory`, 32 hilos) en esta misma máquina y este mismo commit. Es evidencia histórica y
**no se hereda**: se repitió con el banco del propio clon.

**[Medido]** `cargo bench -p subspace-farmer-components --bench plotting --locked -- --sample-size 10`,
con `RAYON_NUM_THREADS=24`:

```
plotting/in-memory      time:   [88.537 s 90.575 s 92.849 s]
                        thrpt:  [10.856 MiB/s 11.128 MiB/s 11.384 MiB/s]
```

| | Por sector de 1.000 piezas | Hilos |
|---|---:|---:|
| Histórico (`research/coste-ploteo-medido.md:20`) | 83,608 s | 32 |
| **Medido ahora** | **90,575 s** (88,537 – 92,849) | 24 |
| Razón | **1,083×** | |

**Coherente, y a un 8,3 % — mucho más cerca que un orden de magnitud.** La diferencia se explica por
tres causas registradas, no supuestas:

1. **24 hilos frente a 32**: el tope del proyecto deja 8 hilos lógicos al sistema.
2. **Gobernador `powersave`**, no modificable sin root.
3. Calentamiento de una sola iteración, porque cada muestra dura ~90 s.

**Contraste independiente, por dos vías.** El banco `pos` del clon da `chia/table/parallel/1x` =
**98,205 ms** por tabla; multiplicado por 1.000 da 98,2 s, un 8,4 % por encima del plotter real
(90,58 s). Es decir: **el ploteo honesto completo —con erasure coding, KZG y escritura— cuesta
incluso algo menos que 1.000 generaciones de tabla sueltas**, de donde se sigue que en este hardware
el ploteo está dominado por la generación de tablas, no por el resto. Tres medidas independientes
cierran entre sí dentro del 9 %.

**Y el control corrige una estimación del banco nuevo.** `t_tabla_paralela` medida por el banco
propio (118,05 ms) sobreestima en un **20 %** a `chia/table/parallel/1x` (98,2 ms) del banco del
clon para la misma función. La causa es que el banco del clon llama a `generate_parallel` **desde
dentro de una tarea rayon** y el propio lo llama desde el hilo principal. Se declara en vez de
esconderlo; la cifra que vale como control es la del banco oficial, y el instrumento usa la
**ganadora del barrido del §5**, que es otra configuración distinta y está cruzada con las dos.

## 5 · M1 · `t_tabla`

**[Medido]** Criterion, `RAYON_NUM_THREADS=24`, muestra 10, calentamiento 2 s.

| Variante | Mediana | Intervalo | Hilos |
|---|---:|---|---:|
| `generate`, semilla fija | 818,72 ms | 806,09 – 833,86 ms | 1 |
| `generate`, semilla distinta por iteración | 809,13 ms | 766,12 – 859,35 ms | 1 |
| `generate_parallel` | 118,05 ms | 108,44 – 132,49 ms | 24 (rayon) |

**[Medido]** Barrido agregado, mediana de 3 repeticiones de 12 s cada una, **una carga a la vez**:

**Tres formas**, todas medidas con el mismo arnés, mediana de 3 repeticiones de 12 s cada una, una
carga a la vez, ciclando sobre un conjunto de semillas verificado:

| Hilos | A · `generate` independientes | B · `generate_parallel` secuencial (piscina de `h`) | C · `generate_parallel` × `h` concurrentes (piscina de 24) |
|---:|---:|---:|---:|
| 1 | 1,2244 | 1,2984 | 10,081 |
| 2 | 2,2779 | 2,2466 | 14,229 |
| 4 | 4,2912 | 3,7813 | 20,879 |
| 8 | 7,9447 | 5,8483 | **25,027** |
| 16 | 14,8221 | **8,7916** | 24,782 |
| 24 | **17,5245** | 7,9677 | 24,732 |

**Tres resultados que el encargo no anticipaba y que hay que declarar:**

1. **[Medido]** Gana la **forma C** —varias llamadas concurrentes a `generate_parallel` sobre una
   piscina de 24— con **8 concurrentes**: **25,03 tablas/s**. Es exactamente la forma que usa el
   granjero real: `CpuRecordsEncoder` recibe **varios** generadores y cada uno llama a
   `generate_parallel` (`crates/subspace-farmer-components/src/plotting.rs:374-415`).
2. **[Medido]** La forma C rinde **1,43×** más que A y **2,96×** más que B. Y el banco del clon
   mide la misma familia (`chia/table/parallel/16x` = 16 tablas en 751,7 ms = **21,28 tablas/s**),
   dentro del 15 % de la forma C medida aquí: las dos medidas se cruzan.
3. **[Medido]** `generate_parallel` **secuencial** (forma B) deja de escalar a partir de 16 hilos y
   **empeora a 24** (8,79 → 7,97 tablas/s) por oversubscripción. La forma C no tiene ese problema:
   se aplana en ~24,7-25,0 desde 8 concurrentes.

Eficiencia sobre 24 hilos: **85 %** en la forma C (25,03 frente a 24 × 1,2244 = 29,4), frente al
59,7 % de la forma A. **El instrumento conserva la ganadora**, como manda `veritas/LINEO.md` §7, y
publica las tres.

**[Medido]** RAM por tabla viva:

| Magnitud | Valor | Etiqueta |
|---|---:|---|
| `size_of::<Proofs<20>>()` | 5.251.072 B = **5,008 MiB** | medido (tamaño exacto del objeto) |
| RSS por tabla retenida (8 tablas) | 10.927.616 B = **10,42 MiB** | medido, **cota superior** (incluye retención del asignador) |
| Pruebas por tabla | **32.768** siempre | medido |

---

## 6 · M2 · `t_reto`

Pregunta del encargo: *¿escala como `w·t_reto`, o hay forma más barata de cruzar una tabla con `w`
buckets a la vez?*

**[Medido]** Coste aislado del `rank/select` que ofrece el código, por índice de bucket:

| Bucket | Mediana |
|---|---:|
| Bajo (0) | 0,64 ns |
| Medio (32.769) | 1,19 µs |
| Alto (54.985, el mayor con prueba) | 2,03 µs |
| Sin prueba (cualquiera) | 0,39 ns |

El coste es **lineal con el índice**: `proof_index_for_s_bucket`
(`shared/ab-proof-of-space/src/lib.rs:63-84`) recorre todos los bytes anteriores al bucket sumando
`count_ones`. Un bucket **sin** prueba retorna antes de esa suma (0,39 ns).

**[Medido]** Cruce de una tabla ya generada con `w` retos:

| `w` | Por bucket (total) | ns/reto | Lote completo (total) | Ahorro |
|---:|---:|---:|---:|---:|
| 1 | 3,5 ns | 3,5 | 477 ns | 0,007× |
| 10 | 4,25 µs | 425 | 486 ns | 8,7× |
| 100 | 41,9 µs | 419 | 627 ns | 67× |
| 1.000 | 489,4 µs | 489 | 1,86 µs | 263× |
| 10.000 | **4.882,1 µs** | 488 | **14,04 µs** | **348×** |

donde «lote completo» = derivar los `w` s-buckets por identidad (11,57 µs) + construir el mapa
objetivo de 8 KiB (2,05 µs) + **un solo `AND` palabra a palabra** del mapa de presencia con el
objetivo (0,418 µs). El `AND` es `O(NUM_S_BUCKETS/64) = 1.024` palabras **independientemente de
`w`**.

**Respuesta: sí, hay forma mucho más barata.** Un atacante que conserve el mapa de presencia
—campo **público** `found_proofs` de `Proofs<20>`— cruza la tabla con los `w` retos de golpe con un
`AND` de 8 KiB y solo extrae las pruebas de los buckets que caen en su ventana. A `w = 10⁴` es
**348× más barato** que recorrer los buckets uno a uno.

**Pero el ahorro no cambia la economía**, porque M2 ya era despreciable frente a M1: 4,88 ms (peor
camino) frente a 809 ms de generar la tabla es un **0,6 %**; por el camino en lote, un **0,0017 %**.
El instrumento publica `r_efectiva(w)` junto a `N_eq` precisamente para que se vea que el descuento
de M2 no mueve la aguja.

**Contraste independiente con el banco del clon.** `chia/proof/for-record` mide **33,314 ms**:
recorre los s-buckets en orden hasta encontrar `NUM_CHUNKS` pruebas, es decir unas 55.800 llamadas a
`find_proof`. Sale **0,60 µs por bucket**, coherente con los 0,488 µs medidos aquí para el mismo
recorrido (razón 1,22×). En cambio `chia/proof/present` mide **2,55 ns**, porque usa el índice de
reto 3 —un bucket bajo, donde el `rank/select` no recorre casi nada—: **ese es el mejor caso, no el
representativo, y subestima el coste real en ~500×**. Quien dimensione algo con ese número se
equivoca por tres órdenes de magnitud.

**Nota de método.** La primera versión de este banco midió **solo el test de bit** (0,29 ns/reto) en
vez del `rank/select`: LLVM eliminaba la suma de `count_ones` porque el índice era un valor muerto.
Se detectó porque el resultado era físicamente imposible. Corregido acumulando el índice, la cifra
subió **1.400×**. Es exactamente el antipatrón «una optimización cambió el veredicto sin
declararlo» de `veritas/LINEO.md` §9, y queda escrito aquí en lugar de borrado.

---

## 7 · M3 · `t_ganador`

El camino que **solo paga el intento que gana**. Descompuesto por componente con la API pública:

| Componente | Mediana | ¿Quién lo paga? |
|---|---:|---|
| Leer la pieza del histórico local (1 MiB) | 21,5 µs | por pieza ganadora (I/O local, **no** descarga) |
| `ErasureCoding::extend` de la pieza | 2,5105 ms | por pieza ganadora |
| `Kzg::poly` de la pieza | 1,4637 ms | por pieza ganadora (**atajo del atacante**) |
| `Kzg::create_witness` del chunk | 19,00 ms | por pieza ganadora |
| `ErasureCoding::recover_poly` sobre el registro | 71,73 ms | **solo el prover honesto** |
| `Kzg::commit` del registro | 16,82 ms | **el archivador**, una vez; el atacante lo lee |
| Regenerar la tabla de la semilla ganadora | 819,46 ms | por intento (ya contado en M1) |

**[Derivado de medidas]** Camino ganador del atacante **sin** regenerar la tabla:
`21,5 µs + 2,51 + 1,46 + 19,00 = **22,99 ms***`.

**Dos cosas que el atacante omite y el plotter honesto no:**

1. No construye ni escribe el sector, ni `SectorContentsMap`, ni el checksum de sector, ni extrae
   las 32.768 pruebas (solo las que caen en su ventana). Eso se acota en M4.
2. **Como conserva la pieza cruda, no necesita `recover_poly`.** El prover honesto reconstruye el
   polinomio fuente a partir de los chunks erasure-codificados leídos del plot (71,73 ms); el
   atacante ya tiene la pieza y obtiene el mismo polinomio con `Kzg::poly` (1,46 ms): **49× menos**.
   La ruta honesta cuesta 93,3 ms por solución; la del atacante, 23,0 ms.

Con `t_tabla = 809 ms` por delante, **el camino ganador es ≈ 2,8 % del intento**: ganar no es lo
caro, intentarlo sí.

---

## 8 · M4 · cono mínimo de dependencia

Pregunta: *¿hacen falta las siete tablas completas para responder a un bucket, o se puede podar?*

### Lo que se midió

**[Medido]** (Instant, n = 3, mediana; `banco-rust/src/bin/cono.rs`):

| Magnitud | Mediana | Nota |
|---|---:|---|
| `Tables::create` (las siete tablas, devueltas) | 757,0 ms | no paralelo |
| `Tables::create_proofs` (siete tablas + 32.768 pruebas) | 833,9 ms | es `t_tabla` |
| `Tables::create_proofs_parallel` (24 hilos) | 123,1 ms | — |
| **Cota superior de una poda de la extracción** | **76,9 ms** | = `create_proofs − create` = **9,2 %** |

**[Medido]** (Criterion) responder **un** bucket desde las dos representaciones que el clon ofrece:

| Representación | Bucket medio | Bucket bajo | Bucket alto |
|---|---:|---:|---:|
| Mapa compacto (`Proofs`, camino `ChiaV2Table`) | 1,208 µs | 0,715 ns | 1,990 µs |
| Siete tablas completas (camino `ChiaTable`) | **111,9 ns** | — | — |

### Veredicto

- **[Verificado en fuente]** **No se ha encontrado poda del cono de tablas.** `create_proofs`
  construye las siete incondicionalmente (`chiapos.rs:195-268`) y `find_proof_raw_internal` recorre
  table_7 → table_6 → … → table_2 (`chiapos.rs:436-470`); cada tabla se construye a partir de la
  anterior **completa** (`table.rs:503-600`). No hay forma de obtener una entrada de la tabla *n*
  sin construir la tabla *n−1* entera. **Etiqueta: «no se ha encontrado atajo», nunca «no existe».**
- **[Medido]** Lo único podable es **extraer pruebas que no vas a usar**, y está acotado por
  **76,9 ms (9,2 %)**. Es una poda real pero menor.
- **[Medido] Resultado contraintuitivo:** el objeto **compacto** que el código usa para responder
  buckets es **10,8× más lento** para un bucket medio que las siete tablas completas
  (1,208 µs frente a 111,9 ns), porque el `rank/select` recorre 8 KiB linealmente mientras que el
  recorrido de tablas está indexado por bucket. El mapa compacto ahorra memoria, no tiempo.
- **[Medido] El camino más barato de todos** es el cruce en lote de M2: 418 ns para responder a
  **10.000** buckets, frente a 111,9 ns **por** bucket con las siete tablas.

---

## 9 · M5 · GPU

**[No medida — ver `mediciones/gpu.txt`]** El clon tiene ruta GPU
(`shared/subspace-proof-of-space-wgpu`, `shared/ab-proof-of-space-gpu`, Vulkan vía `wgpu`, **no
CUDA**). En esta sesión:

- `nvidia-smi` falla: *«couldn't communicate with the NVIDIA driver»*.
- **No existe ningún nodo `/dev/nvidia*`** y `nvidia-modprobe` no puede crearlos (requiere root;
  `sudo` no está disponible: *«The "no new privileges" flag is set»*).
- El ICD de Vulkan de NVIDIA falla al cargar:
  `Could not get 'vkCreateInstance' via 'vk_icdGetInstanceProcAddr' for ICD /usr/lib64/libGLX_nvidia.so.0`.

Se construyó igualmente la sonda `banco-rust-gpu/` (enumera adaptadores y, si encuentra una GPU
discreta, mide `generate_and_encode_pospace`, que es el equivalente GPU de `record_encoding` en
`crates/subspace-farmer-components/src/plotting.rs:616-667`). Compila en 35,81 s y ejecuta, y
**wgpu enumera un solo adaptador**:

```
id=0  nombre="llvmpipe (LLVM 22.1.5, 256 bits)"  tipo=Cpu  backend=Vulkan
```

Es el rasterizador **por software** de Vulkan. La sonda se niega a medirlo: un fallback software no
es una GPU y su cifra no diría nada sobre hardware gráfico. **Resultado: «GPU no medida»**, con
menos de 5 minutos consumidos de la hora asignada.

**[Verificado en documento histórico]** `research/coste-ploteo-medido.md:166-173` **sí** enumeró la
GTX 1070 como `DiscreteGpu` el 2026-09-05. El estado de la máquina ha cambiado desde entonces; esa
medición pertenece a aquella sesión y **no se hereda**.

**El «<5 s por sector» de la documentación de Academy no se usa en ninguna parte de este informe.**
Es prosa ajena, no una medición. Y si la sonda hubiese medido, el número sería una **cota inferior**
de lo que hace una GPU actual: la tarjeta de esta máquina es de 2016.

---

## 10 · M6 · energía

**[No medida]** `escalado` intenta leer
`/sys/class/powercap/intel-rapl:0/energy_uj` en cada repetición y registra el resultado en la
columna `uj`. Todas las filas dan **`no_leible`**: el fichero existe pero es `0400` y propiedad de
`nobody`, y sin root no se puede leer. `nvidia-smi` tampoco está disponible (§9).
**Julios por tabla: no medidos.**

---

## 11 · El modelo, sin precios

Instrumento `veritas/seguridad/intento-v1/` (categoría `seguridad`), estructura de LINEO §1, con
oráculo exacto `Rational{BigInt}`/`BigFloat` y kernel tipado.

### Fórmulas

```text
d(R_s)             = (2·floor(R_s/2) + 1) / 2^64          fracción inclusiva del rango
p                  = o · d(R_s)                            prob. por reto y por tabla (o medido = 0,5)
r_efectiva(w)      = 1 / (1/r + w·t_reto)                  tablas/s con el coste de cruzar la tabla
N_eq(máquina, w)   = r · w · τ                             piezas honestas equivalentes
bytes_eq(w)        = N_eq(w) · Piece::SIZE                 Piece::SIZE = 1.048.672 B
máquinas(α,N_h,w)  = (α/(1−α)) · N_h / N_eq(w)
fracción(1 máquina)= N_eq(w) / (N_eq(w) + N_h)
coste/solución     = (1/(r·w·p) + t_M3) / π_DAG            segundos de máquina por bloque PAGADO
w_min_latencia     = 1 / (r·τ·p)                           mínimo para cubrir un slot
w_equilibrio       = N_h / (r·τ)                           donde UNA máquina emula la red entera
```

`t_M3 = 22,99 ms` (§7) es el camino ganador **sin** regenerar la tabla: esa ya está contada en
`1/(r·w·p)`. Se divide por `π_DAG` porque solo esa fracción de los candidatos enviados resulta
pagada y el atacante no sabe cuáles de antemano.

### Descomposición `N_eq = r·w·τ`

**[Derivado]** Un granjero honesto con `N` piezas gana `N·p` candidatos por slot (cada sector audita
un s-bucket, que contiene una entrada por pieza con prueba allí; con densidad media 1/2,
`S·P·o·d = N·p`). El sembrador con `r` tablas/s y `w` retos conocidos gana `r·τ·w·p` candidatos por
slot. Igualando, `N_eq = r·w·τ`. **La métrica del encargo se sostiene.**

### Entradas (ninguna fijada por el instrumento)

| Entrada | Valor usado | Origen |
|---|---|---|
| `τ` | 1 s | `SLOT_DURATION = 1000` ms, `crates/subspace-runtime/src/lib.rs:145` |
| `R_s` | derivado de `p = λ/N_h` | calibración del controlador (`pieces_to_solution_range`, `crates/subspace-core-primitives/src/solutions.rs:28-40`) y mismo `p` que usa SEM-v1 |
| `N_h` | 10⁶, 10⁸, 10⁹ piezas | **entrada**; 10⁹ piezas ≈ 1 PiB |
| `α` | 0,1 | **entrada** |
| `λ` | 1 solución/slot | **entrada** |
| `π_DAG` | 1,0 y 0,5 | **entrada**; **fijarla a 1 favorece al atacante** y así se etiqueta |
| `w` | 10²…10⁶ | **símbolo**; su valor real lo dará `P-ZRX/P-REVELACION/` |

**Contraste con la calibración upstream.** `pieces_to_solution_range`
(`crates/subspace-core-primitives/src/solutions.rs:28-40`) incorpora el factor de bucket ocupado
(`NUM_S_BUCKETS/NUM_CHUNKS = 2`, es decir `o = 1/2`, **medido** en `distribucion.txt`) y divide por
el número de piezas: de ahí `p ≈ R_s/2^65 ≈ λ/N_h`. Coincide con la calibración que usa SEM-v1
(`P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/INFORME.md`), que es el instrumento del
que este hereda la notación.

### Validación

- **58 comprobaciones** en `test/runtests.jl`: validación de entradas, `d(R_s)` contra conteo real
  sobre `UInt64` y contra el oráculo exacto, bordes de `R_s ∈ {0,1,2,9,1000,4096}`, monotonías,
  determinismo byte a byte del barrido, y equivalencia kernel↔oráculo.
- **[Medido]** Equivalencia con `BigFloat` de 256 bits en 200 casos: error relativo máximo
  **2,74·10⁻¹⁶** (≈ 1,2 `eps`), muy por debajo del umbral de 256 `eps`.
- **[Medido]** Kernel de 100.000 filas: mediana **581,6 µs**, **0 bytes**, **0 asignaciones**,
  1 hilo, Julia 1.13.0, `znver5`.
- JET y `@code_warntype` en `resultados/{JET,WARNTYPE,PERFIL}.txt`.

---

## 12 · A partir de qué `w` el sembrador iguala a comprar disco

**[Medido + derivado]** Con `τ = 1 s`, `α = 0,1`, `λ = 1`, `π_DAG = 1`:

| Máquina | `w = 10²` | `w = 10³` | `w = 10⁴` | `w = 10⁵` | `w = 10⁶` |
|---|---:|---:|---:|---:|---:|
| **1 núcleo** (1,236 tablas/s) | 0,0001 TiB | 0,0012 TiB | 0,0118 TiB | 0,118 TiB | 1,18 TiB |
| **CPU 24 hilos, forma C** (25,03 tablas/s) | 0,0024 TiB | 0,0239 TiB | **0,239 TiB** | **2,39 TiB** | **23,9 TiB** |

**Umbral de igualdad con un disco.** La CPU de 24 hilos en su forma ganadora emula un disco de 20 TB
(19.071.000 piezas) cuando `w ≈ 7,6·10⁵`. Dicho en hardware, que es como lo pide el encargo:

| Disco honesto | CPUs de 24 hilos necesarias, `w = 10⁴` | `w = 10⁵` | `w = 10⁶` |
|---|---:|---:|---:|
| 1 disco de 20 TB | **76** | **7,6** | **0,76** |
| 1 PiB (≈ 1,07·10⁹ piezas) | 4.290 | 429 | 42,9 |

**Y la restricción de latencia da el mismo umbral.** `w_min_latencia = 1/(r·τ·p)`; con la
calibración `p = λ/N_h` resulta `w_min = N_h/(r·τ·λ)`, que **coincide con `w_equilibrio`** cuando
`λ = 1`. El modelo lo reproduce exactamente: para `N_h = 10⁹`, `w_min = w_equilibrio = 3,996·10⁷`
slots (≈ 1,27 años de slots); para `N_h = 10⁶`, `3,996·10⁴`. No es casualidad: «emular la red
entera» y «ganar al ritmo de la red entera» son la misma condición.

> **Corrección al §3 del encargo.** El encargo dice *«con `w` de miles es holgada»*. **No lo es**
> para ninguna red no trivial: la latencia es holgada con `w` de miles solo si
> `N_h/λ ≲ r·τ·w ≈ 2,5·10⁵` piezas (≈ 0,25 TiB) para una CPU de 24 hilos y `w = 10⁴`. Para
> `N_h = 10⁹` hacen falta `w ≈ 4,0·10⁷`. Con `w` de miles el atacante **no cubre ni una solución por
> slot**: puede seguir generando tablas, pero gana mucho menos de lo que dura un slot. La
> consecuencia práctica es que, en ese régimen, el ataque no se descarta por caro sino por **tarde**.

### Frecuencia de M3 y coste por bloque pagado

**[Medido + derivado]** El camino ganador (23,0 ms) se paga **una vez por candidato**, no por
intento: en una ventana de `w` retos se esperan `w·p` candidatos por tabla. Con `π_DAG = 1`, una
CPU de 24 hilos con `w = 10⁴` tarda **4,84 s de máquina por candidato** y `π_DAG = 0,5` la encarece
exactamente ×2 (9,68 s). El coste por solución **no está dominado por M3**: está dominado por
generar las tablas hasta que una gane.

### Sensibilidad a `π_DAG`

`π_DAG` divide **linealmente** el coste por bloque pagado y **no** afecta a `N_eq` (que es una
medida de espacio emulado, no de pago). Fijarlo a 1 es el **límite favorable al atacante** y así se
etiqueta en todas las tablas.

### Precio

**No se usa ninguna cifra de precio.** No se pudo verificar un precio público con fuente y fecha
dentro del presupuesto, y el encargo prohíbe inventarlo. La comparación del §12 es en **hardware**
(máquinas frente a discos), que es la que el encargo pide.

---

## 13 · Hallazgo colateral: SIGSEGV reproducible para ciertas semillas

**[Medido]** No responde a ninguna pregunta del encargo; se documenta porque obligó a cambiar el
método del barrido agregado y porque afecta a la adopción de la dependencia.

`ab_proof_of_space::chiapos::Tables::<20>::create_proofs` —función **pública**, la que usa
`ChiaV2TableGenerator::generate`— termina el proceso con **SIGSEGV** para ciertas semillas.
Entrada mínima: **32 bytes**, `fc5317b05613ed8f1296ebca4c01b008e56a6dcc1d8c9619a4ddd741b285bcbc`.
Reproduce 3 de 3, con **un solo hilo y una sola llamada**, y también pasando la semilla como bytes
crudos (sin el ayudante del banco). La ruta **paralela** (`create_proofs_parallel`), que es la que
usa el plotter honesto, **no falla** con esa semilla.

**[Estimado, no medido]** Tasa del orden de **1 entre 10² y 10³** semillas. **[No determinado]** la
causa raíz: no hay `gdb`, los cores van a `systemd-coredump` (requiere root) y `-Zsanitizer=address`
quedó fuera del presupuesto.

Detalle completo, alcance e impacto: **`mediciones/fallo-semilla.md`**. El banco ahora cicla sobre
un conjunto de semillas verificado (`POOL_SEGURO` en `escalado.rs`); **ninguna cifra de M1–M4 está
afectada**, porque cada tabla se mide por separado.

---

## 14 · Lo que esta investigación NO resuelve

- **`w`.** Es la variable de la que cuelga todo y aquí es un símbolo. Su valor real —la ventana de
  adelanto con y sin revelación retardada— lo dará `P-ZRX/P-REVELACION/`.
- **`π_DAG`.** Cuántas soluciones sembradas terminan publicadas, seleccionadas y pagadas. Entrada.
- **`N_h` y `α`.** Entradas. La red de ZEROX todavía no existe.
- **El coste de derivar los retos.** La salida del PoT no se mide aquí; se supone conocida y
  compartida por todas las identidades, que es lo que hace el atacante del §1.
- **Un kernel adversarial mejor.** Todo lo medido es el código de Autonomys tal cual. La cifra es
  **cota superior**; un atacante con SIMD/GPU/ASIC propios puede bajarla y no se ha cuantificado.
- **El coste mínimo del ataque.** No es lo que se ha medido, en ningún caso.
- **La rentabilidad.** No hay precios. `N_eq` y `máquinas` son hardware, no dinero.
- **La causa raíz del SIGSEGV del §13**, su tasa exacta y si existe en el `rev` más reciente de
  Autonomys (aquí solo se probó `f8842d0`).
- **La GPU.** No medida: sin `/dev/nvidia*` y sin root. El «<5 s» de la documentación **no se usa**.
- **La energía por tabla.** RAPL ilegible sin root.
- **El efecto de la carga del sistema y del gobernador `powersave`** sobre cifras comparables con
  otras máquinas. Se registran; no se corrigen.
- **Una prueba sucinta de que se codificó un sector completo**, ni la seguridad de
  regeneración/compresión de las siete tablas frente a un adversario con memoria intermedia.

---

## 15 · Reproducción

```bash
# 0. Comprobaciones de entrada
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-INTENTO/ENTRADA.sha256
git -C /home/katana/zeo/fuentes/subspace rev-parse --short HEAD   # f8842d0
git -C /home/katana/zeo/fuentes/subspace status --short           # vacío

# 1. Banco Rust (M1..M4 + RAM + escalado), una sola carga a la vez
cd P-ZRX/P-INTENTO/investigacion
export CARGO_TARGET_DIR="$PWD/target" RAYON_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1
export BASE_PATH="$PWD/tmp-mediciones"
(cd banco-rust && cargo bench --no-run --locked)
./ejecutar-mediciones.sh suite          # ~15 min

# 2. Control contra los 83,6 s históricos (bancos del propio clon)
./ejecutar-mediciones.sh control        # ~40 min

# 3. Fichero de entrada del modelo, extraído de las salidas crudas
"$CARGO_TARGET_DIR"/release/exportar_modelo mediciones

# 4. Modelo Julia
cd veritas/seguridad/intento-v1
JULIA_DEPOT_PATH="$PWD/../../../.julia-depot:/home/katana/.julia" \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. test/runtests.jl
JULIA_DEPOT_PATH="$PWD/../../../.julia-depot:/home/katana/.julia" \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
./correr-modelo.sh

# 5. Sonda GPU (presupuesto 1 h)
cd ../../../banco-rust-gpu
CARGO_TARGET_DIR=../target cargo run --release -- 3
```

**Semilla de los barridos:** no hay RNG. Todas las semillas son deterministas
(`seed_i(i) = blake3("INTENTO1" ‖ i_le)`) y el modelo no usa aleatoriedad en absoluto.
