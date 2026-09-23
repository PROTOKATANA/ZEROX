# INFORME del instrumento — secreto-atestiguacion-v1

**Ficha técnica (LINEO §1 y §7).** Pregunta del instrumento: cuantificar, con aritmética
exacta y rutas independientes, (1) la probabilidad de captura del sorteo de atestiguación
(k plazas ponderadas por espacio), (2) la cadena de d bloques, (3) la viveza honesta
(disponibilidad, partición, abstención), (4) la latencia de la ronda de recogida de
firmas con la Δ medida, (5) la fuga de secreto de la rama privada, (6) el coste en
cabecera/red, y (7) el control ejecutable de clasificación de F1 (§4.1 del PROMPT).

**Categoría:** `consenso` (dominante: condiciones de validez y su efecto sobre la
producción); secundarias `seguridad` (captura, fuga) y `red` (latencia). Por eso
`P-ZRX/P-SECRETO/investigacion/veritas/consenso/secreto-atestiguacion-v1/`.

**Adversario declarado.** El de Katana (`AGUJEROS-Y-SOLUCIONES.md` §0): un ente con
mucha capacidad atacará; «no compensa» descarta al atacante económico y a nadie más.
En este instrumento: atacante con fracción α del espacio, κ = 0 (solo publica la rama
ganadora), que NO firma bloques honestos (abstención gratis y sin evidencia) y que
puede censurar/sobornar firmantes (p_disponible, p_sil como entradas).

**Entradas congeladas (no se re-miden):** τ = 1 s/slot nominal; Δ_99 p99 = 0,26–0,60 s
y lognormal por enlace (mediana 80 ms, p99 500 ms) de `veritas/finalidad/delta-medido-v1/`
(DMS-v0.1 §11.2-11.3 y :44); λ ≈ 1 bloque/s; presupuesto de cabecera Q2 ≈ 1 kB.

**Semilla:** `0x5EC5E70`. **Versión:** Julia 1.13.0 (`julia-version.toml` no usado; se
documenta aquí y en CORRIDA.log). **Fecha:** 2026-09-23.

**Presupuesto declarado antes de ejecutar:** máximo 4 hilos, 8 GiB RAM, 300 MiB disco,
corridas de minutos. **No se agotó** (tests 3,0 s a 1 hilo; run.jl < 40 s; bench < 1 min;
`uptime` anotado en BENCH.txt; carga ajena media ~2 ⇒ «medido con carga ajena»).

## Método y rutas independientes

| Cifra | Ruta A (publicada) | Ruta B (oráculo) | Ruta C |
|---|---|---|---|
| captura 1 bloque | forma cerrada α^k, `Rational{BigInt}` | enumeración exhaustiva N^k sorteos ponderados (N ≤ 6) | — |
| captura sin reemplazo | producto secuencial exacto | enumeración sin reemplazo de nodos | — |
| captura de cadena | α^((k+1)d) exacta | enumeración reto×sorteos por slot (N=2, d ≤ 3) | ancla de constantes log10 = −(k+1)·d·log10(3) |
| producción honesta | ((1−α)p)^k (continuo) | enumeración 2^h configs de respuesta (modelo de nodos) + convergencia al continuo | — |
| partición | 1 − x^(k+1) − (1−x)^(k+1) exacta | enumeración productor×plazas por lado | — |
| fuga de secreto | (α+(1−α)p_sil)^(kd) exacta | enumeración multinomial 3 resultados/plaza | — |
| lognormal enlace | erf Float64 | bolas de Arb 128 bits (Φ(z99)=0,99; F(0,19); F(0,36); F(0,5)) | — |
| latencia multihop | convolución Simpson (F_1 exacta, O(dx⁴)/capa) | Monte Carlo Philox4x, semillas no consecutivas (splitmix64), IC Wilson 99 % | — |
| superficie α* | identidad P-PRESTAMO | g(α*) = 0 exacto y signo estricto a los dos lados | β_x = 2·β_d en la pendiente |
| F1 control | modelo mínimo de rama privada | — | regímenes V1/V2 explícitos |

**Cómo se evitó el test tautológico (PROMPT §6):** las identidades de parametrización
de la lognormal (`F(mediana)=0,5`, `F(p99)=0,99`) se etiquetan como plomería; la
identidad (α^k)^d = α^(kd) se retiró y se sustituyó por enumeración por slot y anclas
de constantes; el cruce convolución↔MC es de mecánicas distintas (integración
determinista frente a muestreo). La verificación independiente (dos especialistas,
matemáticas y Julia) revisó el instrumento el 2026-09-23 y sus hallazgos se
incorporaron: sorteo del productor en la partición, factor del reto en la cadena,
fuga binomial exacta, latencia multihop con tramos independientes, subdesbordamiento
de la fuga corregido (log10 BigFloat), y la clasificación V1/V2 en el control F1.

## Correcciones introducidas por la verificación independiente

| # | Hallazgo del revisor | Corrección | Efecto |
|---|---|---|---|
| E1 | Paro en partición sin el sorteo del productor | 1 − x^(k+1) − (1−x)^(k+1) | P(paro) sube: k=4, x=0,5 → 0,9375 (antes 0,875) |
| E2 | Cadena sin el factor del reto | α^((k+1)d) | log10 k=1, d=7200: −6870 (antes −3435) |
| E3 | Fuga con esperanza como exponente | (α+(1−α)p_sil)^(kd) exacta | unifica captura y silencio |
| E4 | Latencia de UN enlace contra Δ multihop | suma de 2h enlaces iid, h ∈ {1,2,3} | P(cabe) k=4, Δ=0,26: 0,956 (h=1) → 0,219 (h=3) |
| E5 | «Tasa efectiva» mal atribuida | retirada; la métrica correcta es P(no cabe) | — |
| E6 | Subdesbordamiento Float64 de la fuga | log10 con BigFloat | sin ceros falsos |
| E7 | Atestiguación «INFALSIFICABLE» codificaba la conclusión | regímenes V1/V2 explícitos | F1 reescrito con matiz |

## Tabla de rendimiento (LINEO §6)

Ver `resultados/BENCH.txt`. Resumen: kernels exactos µs (0,3–50 µs); la convolución de
la suma de 6 enlaces (npts = 4000, Simpson) 14,7 ms, amortizada entre todas las celdas
por precomputación; MC de 100k réplicas 59 ms. Sin `@fastmath`, sin `@simd`, sin
`Float32` en fronteras; `@inbounds` solo en el bucle de convolución tras el test de
rango (índices en rango por construcción, comentado). Kernels Float64 con
`Body::Float64` en `@code_warntype` (verificado; sin `Any`). Serial: el problema es
O(celdas) y no justifica hilos; el tope de 4 se declara y no se usa.

## Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-SECRETO/ENTRADA.sha256
cd P-ZRX/P-SECRETO/investigacion/veritas/consenso/secreto-atestiguacion-v1
export JULIA_DEPOT_PATH="$PWD/../../../.julia-depot:/home/katana/.julia"

# Perfil de referencia (1 hilo, límites activos): 80 controles
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl

# Artefactos publicados (F1-control, F3-captura/cadena/coste, F4-latencia/viveza/particion/soborno/alfa)
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --seed 0x5EC5E70 --tarea f1 --tarea f3 --tarea f4

# Benchmarks
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
```

Hardware: AMD Ryzen 9 9950X3D (`znver5`), 32 hilos lógicos, 123 GiB, Julia 1.13.0.
Sin Python. Manifest.toml versionado (fija Julia 1.13).
