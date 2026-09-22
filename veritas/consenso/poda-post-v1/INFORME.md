# INFORME — PPP-v0.1 · ¿Existe una poda para ZEROX?

**Categoría**: `consenso` (dominante) — el objeto es un mecanismo de consenso; `almacenamiento`
(secundaria), por poda y disponibilidad histórica. **Pregunta del encargo**: ¿existe en PoST un
análogo a los niveles de PoW que sostenga una prueba de poda verificable, y bajo qué supuestos?

**Respuesta corta.** No con los mecanismos disponibles, y el motivo es estructural, no de
calibración: un nivel basado en la solución PoAS no liga a la ancestría, y un nivel basado en el
hash de cabecera no mide espacio-tiempo. Por eso añadir `parents_by_level` **no** arreglaría la
poda y **§6.1–§6.2 no se reabren** (§4). La poda **local** sí es posible; la prueba de poda para
un nodo nuevo, no. Una testnet sin poda con archivales declarados **no cuenta como solución**
(§5.8 del encargo).

## 1. Veredictos separados para los tres problemas (§2 del encargo)

| # | Problema | Veredicto | Etiqueta | Motivo |
|---|---|---|---|---|
| **1** | **Poda local**: qué descarta un nodo que ya validó toda la historia | **SÍ, con alcance condicionado** | demostrado (límite: constantes pendientes) | el nodo confía en su propia validación: conserva checkpoint finalizado + estado UTXO + ventana de retención. No necesita prueba de tercero |
| **2** | **Prueba de poda e IBD sin confianza** para un nodo nuevo | **NO** para los mecanismos examinados | demostrado (D5, D4, D8) | ningún predicado de nivel cumple a la vez (P1) medible sin el DAG, (P2) ligado a recurso y (P3) ligado a la ancestría; un certificado de niveles se pega a cualquier historia y `blue_work` no se recomputa |
| **3** | **Disponibilidad histórica** (archivales) | **Fuera del consenso; no es una solución** | estimado / no demostrado | garantía social/económica, no criptográfica; no resuelve (2) y una testnet sin poda no cuenta |

**Un «sí» en (1) no es un «sí» en (2).** (1) es autoconsistente y no ayuda a nadie más; (2) exige
un objeto **verificable por un tercero**, y es ahí donde el diseño actual no tiene nada que ofrecer.

### 1.1 Problema (1): poda local — SÍ

Un nodo que validó toda la historia puede descartar lo que ya no necesita: conserva (a) un
**checkpoint finalizado** (su punto de irreversibilidad, R-FIN-7), (b) el **estado UTXO** con sus
datos de deshacer recientes, (c) la **ventana de hashes de bloque** que exige C-EXP-06
(`VIDA_MINIMA + DISPERSION = 1 114 112` alturas = **35,65 MB**) y las ventanas del cálculo
contextual (rango, `merge_depth` C-GD-11, finalidad), y (d) madurez de coinbase y timelocks.
Puede tirar cabeceras y cuerpos por debajo del checkpoint porque **no tiene que convencer a
nadie**: su estado ya está validado. Es exactamente el «nodo veterano, disco» del §2.

Lo que **no** está demostrado: la profundidad exacta de retención. Depende de las cinco
constantes pendientes de C-GD-11 (métrica, valor, bootstrap, borde de igualdad, relación con
poda) y de R-FIN-7, que este instrumento no fija (§5.1 del encargo). Se entrega como **función**:
`profundidad_retención = max(ventana_rango, merge_depth, ventana_finalidad) + VIDA_MINIMA + DISPERSION`.

Además, la poda local **no** es una prueba: un nodo nuevo no puede heredarla sin confiar en el
nodo que se la da. Decir «(1) resuelto, luego (2) resuelto» sería el error grave que el encargo
prohíbe.

### 1.2 Problema (2): prueba de poda e IBD sin confianza — NO

Para que un nodo nuevo arranque sin validar todo y **sin confiar en nadie**, hace falta un objeto
`π` que acredite la historia canónica. En Kaspa, los niveles de PoW lo dan porque el hash del
bloque **compromete los padres** y encontrar `L` ceros cuesta `2^L` hashes *sobre esa ancestría*:
(P1) medible, (P2) ligado al recurso, (P3) ligado a la ancestría. En ZEROX:

- el **nivel espacial** (`solution_distance ≤ SR/2^L`) se calcula sin leer los padres; la solución
  se encuentra **antes** de elegirlos. Es independiente de la ancestría (**D4**, 0 discrepancias en
  500 pares). Falla (P3).
- el **nivel por hash de cabecera** sí liga a los padres, pero se muele con CPU y espacio ≈ 0 (el
  sello Ed25519 **no es único**, C-HDR-04; el `merkle_root` varía con la coinbase). Falla (P2).
- **cualquier combinación** de ambos no crea la propiedad que falta (**D5**).

Consecuencias medidas:

1. **Rama privada (punto 5).** El certificado de niveles de 64 bloques de nivel 8 construido desde
   `(slot, solución)` es **aceptado** por el verificador más fuerte que sólo mira niveles
   (`run-certificado.txt`). Al mismo tiempo, dos DAG con idénticos `(slot, sd, SR)` tienen distinto
   `blue_score` (4 vs 3) y distinto `blue_work`, según `--bluework` con GDR-v0.2
   (`run-bluework.txt`). El certificado no
   puede distinguir la rama canónica de la privada: **no es sound**.
2. **`blue_work` declarado es gratis (ATAQUE 8).** Un cliente ligero no puede recomputar
   `blue_work(B) = blue_work(sp(B)) + Σ w(x)` sin el mergeset, el coloreo y los `SR` (D8); y la
   afirmación en cabecera sólo la comprueba un nodo completo. Un certificado de niveles no lo
   sustituye.
3. **`SR` endógeno (puntos 1–2).** El nivel anclado al bloque es escala-invariante, pero su `SR`
   lo fija el pasado de la propia rama; con ancla de referencia la tasa escala `≈ SR₀/SR` y una
   rama privada que estire su `SR` infla sus niveles (D3, `run-sranclaje.txt`). Ninguna ancla es
   estable y no manipulable.
4. **Multiplicidad (punto 3).** `C` chunks ganadores por s-bucket son `C` billetes distintos
   (la identidad R-FIN-11 incluye `chunk`); no dan ventaja relativa, pero rompen la lectura
   «N bloques de nivel L ⟹ N·2^L unidades de espacio-tiempo atadas a una historia» (D6,
   `run-multiples.txt`).
5. **Retención (punto 4).** No reduce el gasto; compra elegir la ancestría después. Es
   optatividad, no ataque de recursos (D7, `run-retencion.txt`).
6. **Un nivel basado en el PoT tampoco sirve.** Mediría trabajo de VDF (no espacio, y un VDF más
   rápido lo estira, ATAQUE 1–2), y el flujo de PoT puede ramificarse en los puntos de inyección,
   así que no liga a una ancestría única (D5, Caso C).

**Precisión para no sobrerreclamar.** Un certificado de niveles sí puede acotar el
**espacio-tiempo global** gastado (con las correcciones de D2/D3/D6). Lo que no puede es decir
**a qué historia** corresponde ese gasto. Y (2) no necesita «se gastó recurso en algún sitio»:
necesita determinar **cuál** es la historia canónica, que en ZEROX es el resultado de GHOSTDAG
sobre el DAG completo (§11). El doble uso (mismos billetes/espacio en dos candidatas, D6) y el
`blue_work` no recomputable (D8) son las dos caras de esa ausencia. Es un fallo de **soundness**
de la prueba, no (necesariamente) un ataque de mayoría.

**La raíz del fallo** es que `blue_work` —el objeto sobre el que el SPEC define la cadena (§11)—
vive en el DAG completo, y nada de lo que un tercero puede comprobar sin el DAG determina el DAG.
No hay una laguna de formato que cerrar; hay una **ausencia de mecanismo** de anclaje
resultado↔ancestría.

### 1.3 Problema (3): disponibilidad histórica — fuera del consenso

Quién conserva lo podado: nodos archivales. La garantía es **social/económica** (incentivos,
reputación, contratos), **no** criptográfica: nada impide que desaparezcan. Ayuda a la
operación —y `C-STORE`/§15.1 ya hablan de almacenamiento— pero **no resuelve (2)**. La poda es
requisito para lanzar mainnet; una testnet puede operar sin poda con archivales explícitos, y eso
**no cuenta como solución** (§5.8).

## 2. Las cinco preguntas de LINEO

**1. Complejidad.** Fórmula exacta por bloque: `O(C)`; Monte Carlo: `O(N·C)`; exhaustiva del
modelo escalado: `O(M^C)` (sólo `M≤8`, `C≤3`). El coste dominante es el horizonte del Monte
Carlo y `C`; la fórmula exacta es instantánea. Reachability sin poda:
`O(#cabeceras × mergeset_limit) ≤ 5,68·10⁹` entradas/año (D9).

**2. Perfil y asignaciones.** `contar_niveles!` no asigna en el bucle: **0 B / 0 allocs** por
corrida (`resultados/BENCH.txt`). Escalado por réplicas: 1→24 hilos, `5,24·10⁷ → 9,61·10⁸`
sorteos/s (×18,3), sublineal en 16–24 por hyperthreading. Sin BLAS.

**3. Oráculo.** Dos independientes: `oraculo_exhaustivo` (enumeración, no usa la fórmula) y la
fórmula exacta `Rational{BigInt}`; coinciden **sin discrepancias**. El kernel Monte Carlo coincide
con la exacta dentro de 4σ (`run-mc.txt`). Para `blue_work` se reutiliza **GDR-v0.2**, no una
reimplementación.

**4. Tipos numéricos.** Todo el veredicto discreto es aritmética entera exacta y
`Rational{BigInt}`; `Float64`/`BigFloat` sólo para presentación. Sin `@fastmath`. Sin tolerancias
en la equivalencia (la comparación exhaustiva/fórmula es exacta).

**5. Semilla, versión y hardware.** Cada archivo de `resultados/` lleva hash Git, fecha, `julia
1.13.0`, CPU `znver5`, hilos, comando y semilla. `Manifest.toml` sin cambios.

## 3. Verificación y reproducción

- Suite: **85/85** con `--check-bounds=yes` (`resultados/TESTS.txt`).
- Comandos exactos: `METODO.md`.
- `INFORME` no publica una cifra sin su artefacto en `resultados/`.

## 4. La consecuencia para el SPEC (§4 del encargo): §6.1 NO se reabre

La cabecera quedó cerrada el 2026-09-17 con padres planos
(`PadresDag { count, seleccionado, extra }`, `crates/zx-core/src/preimage/dag.rs:190`); **no existe
`parents_by_level`**. La pregunta del encargo era si una prueba de poda verificable lo **exige**.

**No.** Por D5, el problema no es que falte un campo, sino que ningún predicado de nivel satisface
(P1)+(P2)+(P3). Añadir `parents_by_level` cambiaría el layout `589 + 32·(P−1)` y el trabajo de
TAREAS §2.8 sin arreglar la soundness: los niveles seguirían (a) sin ligar a la ancestría si
dependen de la solución, o (b) molibles por CPU si dependen del hash. **No hay trabajo de cableado
bloqueado por esta auditoría.** Si en el futuro se diseñara un **reto ligado a la ancestría**
(p. ej. que el desafío dependa del hash de los padres), entonces sí habría que reabrir §6.1 y
analizar la molienda por elección de padres; ese diseño no existe hoy y no se propone como regla
(ver `PROPUESTA.md`, P3, con su coste).

## 5. Cobertura de los ocho puntos del §3

| # | Punto | Dónde | Etiqueta |
|---|---|---|---|
| 1 | `SR` variable y ancla del umbral | D3, `run-sranclaje.txt` | medido |
| 2 | Retarget: quién influye en `SR` | D3 (función de `ρ=SR_branch/SR_ref`; controlador no especificado) | no demostrado / paramétrico |
| 3 | Múltiples soluciones por s-bucket | D2, D6, `run-multiples.txt` | medido |
| 4 | Retención y publicación tardía | D7, `run-retencion.txt` | medido |
| 5 | Ramas privadas | D4, D5, `run-certificado.txt`, `run-bluework.txt` | demostrado + medido |
| 6 | Validación de `parents_by_level` | §4, D5; el campo no existe (`dag.rs:190`) | demostrado (no ayuda) |
| 7 | Recomputación de `blue_work` | D8, `run-bluework.txt`, ATAQUE 8 | demostrado |
| 8 | Compromiso verificable del estado | D10 | estimado / análisis |

## 6. Tabla de rendimiento (formato LINEO §6)

| Variante | Tiempo mediano | Asignaciones | Hilos/backend | Resultado frente a referencia |
|---|---:|---:|---|---|
| Oráculo exhaustivo (M≤8, C≤3) | < 1 s | — | 1 CPU | fuente de verdad discreta |
| Fórmula exacta `Rational{BigInt}` | < 1 s para 48 niveles | — | 1 CPU | igual a la exhaustiva (0 fallos) |
| Kernel Monte Carlo `contar_niveles!` (C=8) | 19,0 ms / 10⁶ sorteos | 0 B | 1 CPU | dentro de 4σ de la exacta |
| Réplicas independientes 1→24 hilos | 0,366→0,020 s | — | `Threads.@threads` | ×18,3; se conserva 24 |

No se publica un «X veces más rápido» aislado: cada cifra lleva tamaño, trabajo, semilla y
resultado comprobado.

## 7. Límites declarados

- **No demostrado**: que el controlador R-FIN-13′ no pueda estirar `SR` más allá de un factor; el
  efecto se da como función de `ρ`. Tampoco se mide la tasa real de sorteos/TiB (no hay granja).
- **Inconcluso**: el coste real de reachability sin poda en un nodo concreto; sólo la cota
  `O(#cabeceras × mergeset_limit)`.
- **Fuera de alcance**: PoT (flujos, inyección, VDF rápido), ya auditado en
  `research/dag-poas-auditoria.md` (ATAQUE 1–2); este informe **no** reabre ese resultado, lo usa
  como supuesto donde toca y lo marca cuando no está garantizado.
- Los veredictos valen para el **diseño actual** (SPEC 2026-09-17). Un rediseño que ate el reto a
  la ancestría cambiaría (2), y empezaría por reabrir §6.1.

## 8. Lo que se rechaza, explícitamente

- No se da por buena la hipótesis `solution_distance ≤ SR/2^L`: se deriva exacta (D1), se compara
  (D2) y se muestra que **no es el problema**.
- No se mezclan los tres problemas: cada uno tiene veredicto e implicaciones propias.
- No se apoya ningún argumento en `blue_work` declarado en cabecera: al contrario, D8 muestra que
  no se puede recomputar desde un certificado.
- No se fija ningún parámetro (`L`, profundidad, tamaños): todo va como función.
- No se usa `F = 2 h`: ninguna cifra de este informe depende de él.
