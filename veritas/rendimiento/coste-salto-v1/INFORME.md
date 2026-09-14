# INFORME.md — banco `coste-salto` (Q4), adaptado a `veritas/LINEO.md`

Auditoría de rendimiento en Rust (no Julia: `veritas/LINEO.md` es la referencia
metodológica adaptada, `Cargo.lock` en vez de `Manifest.toml`, según el encargo). Validado y
migrado a `veritas/rendimiento/coste-salto-v1/` el 2026-09-14 (C-SPEC-02: todo benchmark vive en
`veritas/<categoria>/<nombre>/`); el detalle de la validación está al final de `BITACORA.md`.

## Categoría

**Rendimiento** (LINEO §1: «la categoría la determina el agente según el tema
dominante»). Secundarias: **red** (el resultado alimenta directamente el presupuesto
de reenvío de Q1/Q2 en TAREAS.md §3.1) y **finalidad** (Q4 es una precondición de
`C-NET-12`/`C-NET-06`, y el resultado se compara contra la sensibilidad de Δ de
DMS-v0.1).

## Declaración de presupuesto (antes de ejecutar, LINEO §7 y §8.11)

Esta auditoría puede usar como máximo 1 hilo de cómputo fijado con `taskset -c 8`
(no aplica el tope Julia de 24 hilos: es un banco Rust monohilo por diseño, para que
las medianas sean comparables al ancla del PoT), sin límite de RAM declarado aparte
del proceso mismo (fixture PoAS + tablas Chia K=20, del orden de cientos de MiB), y
sin límite de disco aparte de los `target*/` de compilación (varios GiB, dentro de la
zona). Si el presupuesto de tiempo de una sesión se agota, el estado es
**inconcluso** con lo medido hasta ese punto, nunca un resultado forzado — no ocurrió
en esta corrida.

## 1. Complejidad temporal/espacial y parámetro dominante

| Op | Complejidad | Parámetro dominante |
|---|---|---|
| A | O(1) — PoS K=20 (búsqueda en tablas ya construidas, coste fijo por K) + 2 verificaciones KZG (`check_proof_single`, coste fijo, independiente de `num_values`) + comprobaciones de rango/pieza O(1) | Ninguno variable: todo el coste es fijo por parámetro de protocolo (K=20, curva BLS) |
| B-pos | O(1) | K=20 |
| B-kzg / B-kzg-hist | O(1) — confirmado en la matriz (§6 de RESUMEN.md): NO depende de `num_values` ni del índice | Tamaño de curva/pairing (fijo) |
| C | O(1) para un mensaje de tamaño fijo (492 B); Ed25519 verify es dominado por la multiplicación escalar, no por el hash del mensaje | Fijo (492 B) |
| D-92 / D-556 | O(tamaño del buffer) — SHA3-256 absorbe 136 B por permutación de Keccak: 92 B + etiqueta de 16 B = 1 permutación; 556 B + 16 B = 5 permutaciones (coherente con D-556 ≈ 4,6 × D-92) | Tamaño del buffer (número de permutaciones) |
| E-571 / E-4464 | O(N) — árbol de Merkle binario, N hojas → ~N hashes internos | N = número de transacciones |
| F-1 / F-150 | O(slots) — `memcmp` de 128 B × slots | Número de slots (1 / 150 = S_max) |
| G-* | O(iteraciones) — cadena secuencial de AES-128 iterado (VDF; en verificación, cifrado y descifrado por tramo), 200 032 000 iteraciones, **no paralelizable dentro de un checkpoint** (cada iteración depende de la anterior) | Iteraciones por slot (fijo por protocolo), NO el tamaño de clave/estado |
| H-N / H-txid-N | O(N) — decodificar y/o hashear N transacciones de tamaño fijo (348 B) | N = número de transacciones |

Espacial: todas las operaciones son O(1) o O(N) en memoria sobre su entrada (sin
estructuras auxiliares que crezcan más rápido que la entrada); el único estado grande
del proceso es la fixture PoAS (tablas Chia K=20), construida una vez, fuera de lo
cronometrado.

## 2. Perfil de CPU (LINEO §6, `perf stat -r 5`)

### A vs. 2×B-kzg + B-pos (descomposición)

| | ns |
|---|---:|
| A (medido) | 1 194 192 |
| 2×B-kzg + B-pos (medido) | 1 176 868 |
| Diferencia (rango + límites de pieza + overhead) | 17 324 (1,45 % de A) |

El 1,45 % de diferencia es pequeño y consistente con que A no es más que «PoS + 2 KZG»
más comprobaciones O(1) baratas (rango, límites de pieza) — no hay un componente
oculto caro.

### `perf stat -r 5` (subcomando `coste-salto perfil --op {A,G} --n N`, sin CSV,
### contexto construido una vez por repetición, fuera del bucle cronometrado)

| | A (n=200 000) | G avx512f_vaes (n=30) |
|---|---:|---:|
| instrucciones/llamada (derivado) | 24 597 509 | 1 254 499 456 † |
| ciclos/llamada (derivado) | 6 617 919 | 1 084 081 473 † |
| IPC | 3,72 | 1,16 † |
| tiempo derivado de ciclos @ frecuencia medida | 1,226 ms | 193,6 ms † |
| branch-miss rate | 0,1 % | 0,8 % |
| page-faults (todo el proceso, 5 reps) | 14 524 (≈0/llamada) | 13 738 (≈0/llamada) |
| frecuencia media medida por `perf` | 5,4 GHz | 5,6 GHz |

† **Límite declarado:** para G, `n=30` no aísla bien el bucle de la construcción del
contexto + `prove()` (una vez por repetición, ~1,6 s + construcción de fixture): el
tiempo derivado de `perf` (193,6 ms/llamada) NO coincide con la mediana del harness
(92,097 ms/llamada) porque ~52,7 % del tiempo de cada repetición (3,073 s de 5,836 s)
es overhead fijo, no las 30 llamadas a `verify_con_ruta`. El IPC (1,16, bajo, coherente
con una cadena secuencial de dependencias — es exactamente lo que un VDF debe tener)
y el conteo de instrucciones SÍ son informativos; el tiempo derivado, no. Para A
(`n=200 000`), el overhead de construir el contexto UNA vez es despreciable frente a
200 000 llamadas, y el tiempo derivado de `perf` (1,226 ms) coincide con la mediana
del harness (1,194 ms) dentro del 2,7 %.

**Aviso de método:** el primer intento de este perfil usó `--n 200 000` para A creyendo
que A costaba ~1,2 µs/llamada (confusión de unidad con la cifra real, ~1,2 **ms**); cada
repetición tardó ~4 min en vez de ~1 s, y las 5 repeticiones ~20 min en vez de ~5 s. No
invalida el resultado (`n` grande es, si acaso, mejor para que el bucle domine), pero
es un error de estimación de tiempo, no de cifra, y se declara — `REGISTRO.log`.

## 3. Oráculo pequeño/lento

Cada operación tiene un control positivo (entrada válida → resultado esperado) y un
control negativo (entrada mutada → falla con el error/`false` concreto), impresos ANTES
de medir y guardados en `CONTROLES.txt`. Es el «oráculo» exigido por LINEO: no se mide
una función que no se haya comprobado primero contra un caso conocido.

Contraste adicional con un instrumento independiente para G: `benches/ancla.rs`
(Criterion, misma semilla `ChaCha8Rng` que el ancla original,
`research/dag-poas-ancla-de-orden.md:342`) — hecho en Corrección 0, no repetido aquí
(no lo pedía el encargo); coincide con el harness `Instant` dentro de ~0,1 % en esa
sesión.

## 4. Tipos numéricos y redondeo

- Todas las muestras se acumulan en `u128` nanosegundos enteros (`Instant::elapsed().as_nanos()`),
  sin coma flotante hasta el cálculo de estadísticos (mediana/percentiles/CV), que sí
  usa `f64` — aceptable porque son solo para presentación, no para ninguna regla de
  consenso.
- `F-1` cuantiza a 1 ns: la operación real (memcmp de 128 B) tarda del orden de
  decenas de ciclos (~unos ns), muy por debajo de la resolución práctica de
  `Instant` para una sola llamada; se mide en lotes de 10 000 y se divide (columna
  `division` de `Medicion`), lo que reduce pero no elimina la cuantización. Declarado
  también en `README.md` «Límites declarados».
- Los `ns` derivados de `perf stat` (ciclos/frecuencia) son un cálculo aparte, hecho
  en `awk` (no Python, no Julia con estado — es aritmética de una línea sobre
  contadores ya agregados por `perf`; no hay auditoría Julia dedicada porque no hay
  modelo, simulación ni búsqueda que auditar, solo una razón).

## 5. Reproducibilidad

- **Commits:** ZEROX `00c14fa1386081375e1a44b8ac6a650bd24029ab`; clon Autonomys
  `f8842d019cdf0f7163421b9644db5a9ff82b2a73` (ambos sin cambiar desde el inicio de la
  sesión — `git status --short` idéntico).
- **`rustc -Vv`:** `1.97.0-nightly (20de910db 2026-05-02)`, LLVM 22.1.4, toolchain
  `nightly-2026-05-03` heredado (`ENTORNO.txt`).
- **CPU y núcleo:** AMD Ryzen 9 9950X3D, `taskset -c 8` (CPU lógica 8, core 8, L3:1)
  en TODAS las mediciones cronometradas, incluidas `perf stat` y ambos lotes.
- **Gobernador:** `powersave` (no hay `performance` en esta máquina); frecuencia bajo
  carga medida por `perf` entre 5,4 y 5,6 GHz según la operación.
- **Semillas:** G usa `ChaCha8Rng::from_seed(Default::default())` (igual que el ancla);
  `B-kzg-hist` usa `ChaCha8Rng::seed_from_u64(0)` (DIFERENTE del histórico, que usa
  `rand::random()` no determinista — declarado en README.md); H usa transacciones
  deterministas por índice `i` (sin RNG).
- **`Cargo.lock`:** fijo con `--locked` en 4 de las 5 compilaciones nuevas; la
  compilación `kzg-parallel` amplió el lockfile la primera vez (solo entradas nuevas,
  ninguna versión existente cambió — `resultados/DIFF-cargo-lock-parallel.txt`), y
  las demás compilaciones `--locked` posteriores usan ese mismo lockfile ampliado.
- **Hilos:** 1 (monohilo, sin BLAS ni paralelismo Julia — no aplica el protocolo de
  hilos de LINEO §7, que es para auditorías Julia/CPU masivamente paralelas).
- **Dos lotes separados ≥30 min** (21:54:33 → 22:24:52), medianas reproducibles <5 %
  en las 20 operaciones + 12 filas de la matriz KZG (máxima diferencia observada:
  `G-pot-avx512f_vaes`, −2,85 %).

## Resumen de resultados

Ver `resultados/RESUMEN.md` para las tablas completas. En una línea: el coste por
salto de Q4 (1,3–9,9 ms según escenario y tamaño de bloque) deja entre 10× y 75× de
margen bajo el presupuesto de 0,1 s de DMS-v0.1; la opción descartada (PoT en cada
bloque) no deja margen ni con la ruta más rápida.
