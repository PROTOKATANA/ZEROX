# INFORME — `crp1-defectos-v1` (recálculo de los defectos de CRP-v0.1)

**Categoría:** `seguridad` (dominante); `consenso` (secundaria). **Motivo de la categoría:** el
objeto es la seguridad de una rama privada frente a la red honesta, y la pregunta es si el umbral
publicado se sostiene.

**Pregunta.** ¿Son reales los diez defectos D1–D10 atribuidos a CRP-v0.1 por
`ENCARGO-07v2` §2, y cuánto mueve cada uno las cifras publicadas?

**Relación con el instrumento auditado.** Este proyecto **no reutiliza** el código de
`veritas/seguridad/coste-rama-privada-v1/`: reimplementa el modelo desde el contrato (C-GD-01 y el
predicado PoAS) y valida contra oráculos independientes. El instrumento original sólo se usa, en
`auditoria/copia/`, para reproducir lo publicado y localizar los cargos. El informe de la auditoría
—con las diez fichas— es `auditoria/INFORME.md`; las cifras fila a fila, `auditoria/CIFRAS.md`.

**Presupuesto declarado.** Esta auditoría puede usar como máximo **64 GiB de RAM** (tope de la
máquina) y **4 hilos** (el encargo P-CRP1 los limita a 4 de los 24 del tope conjunto), y ≤ 1 GiB de
disco temporal. Si se agota, checkpoint y estado **inconcluso**. Consumo real: < 100 MiB de RAM,
< 1 min de CPU en total, matrices densas de ≤ 3336² `Float64` (~89 MB pico).

---

## 1 · Complejidad

| rutina | complejidad temporal | espacial | parámetro dominante |
|---|---|---|---|
| `dp_ruina_conservada` | `O(maxit · N · (xmax−xmin))` con matvec BLAS | `O(N²)` | `N = m + margen` (ventana); `maxit` converge en decenas de iteraciones |
| `soporte_incremento` | `O(Hmax · Amax)` | `O(Hmax + Amax)` | las medias `g(1−α)` y `gα` |
| `varianza_exacta` | `O(bmax · log)` con CDF acumulada | `O(amax)` | `bmax ≈ μ_a + 45√μ_a` |
| `mc_varianza` | `O(n_rep · T)` | `O(n_rep)` | `n_rep · T` |
| `peso_exacto` / `ruina_unitaria_*` | `O(1)` los primeros; `O(N³)` el sistema racional | `O(N)` / `O(N²)` | `N` en el oráculo |

El coste dominante en el uso real es la **DP de alcance** y, en el oráculo, la **resolución exacta
del sistema racional** (`N ≤ 60`).

## 2 · Representación elegida y por qué

- **Estado de la DP:** un `Int` (déficit en bloques) sobre una retícula de paso 1. La transición es
  una matriz de Toeplitz por bandas de `Float64` para poder usar `mul!`/BLAS en la iteración de
  valor; se prefiere eso a un `Dict` o a una representación dispersa porque la banda ocupa casi
  toda la fila para `g` grande. El vector de estados es contiguo y el objetivo es un índice
  (`kobj`).
- **Soportes de Poisson:** arrays contiguos `Vector{Float64}` con log-factoriales **acumulados**
  (`logfact_acum`), que bajan el coste de construir la pmf de `O(n²)` a `O(n)`.
- **Aritmética exacta:** `BigInt`/`Rational{BigInt}` para todo lo que decide el veredicto
  (`A(sr)`, `w(sr)`, la ruina ±1, la martingala, los empates de la tabla de varianza).
  `BigFloat` a 256 bits sólo para las pmf de Poisson, que son trascendentes; su error de
  truncación se publica (`masa_b_truncada`, `masa_omitida`).
- **Nada de `@fastmath`, `@simd`, `@turbo` ni `Float32`.** El paralelismo es sólo por réplica de
  Monte Carlo, con contadores enteros y reducción final ordenada.

## 3 · Oráculos independientes (LINEO §5)

| kernel | oráculo | coincidencia |
|---|---|---|
| `valores_aceptados` | enumeración exhaustiva del círculo, 36 combinaciones | exacta |
| `prob_empate_reticula` | sistema lineal en `Rational{BigInt}` | < 1e-8 rel. |
| `prob_empate_reticula` | enumeración de la distribución de caminos (`BigFloat`) | < 1e-9 rel. |
| `pmf_poisson_vec` | producto iterativo independiente + muestreador por transformada inversa | < 1e-12 rel. / 3,6e-3 empírico |
| `dp_ruina_conservada` | cota de martingala (superior) y `max_n P(S_n ≤ −m)` (inferior) | dentro del intervalo |
| `dp_ruina_conservada` | `prob_alcance_dp` del propio CRP-v0.1 **con el déficit corregido** | 6–8 dígitos en `g = 1,4,16` |
| `varianza_exacta` | Monte Carlo de 20 000–40 000 réplicas con semillas no consecutivas | dentro del IC 99,9 % en los cuatro `K` |
| `descomposicion_trabajo` | cálculo directo de `trabajo_por_ensayo` | < 1e-30 rel. |

**Ningún test compara una fórmula consigo misma** (ése es precisamente el defecto D7 del
instrumento auditado).

## 4 · Validación

`test/runtests.jl` — **60/60** con `--check-bounds=yes` en Julia 1.13.0. Cubre: conteo del
predicado PoAS y bordes del dominio circular, ruina ±1 por tres métodos, martingala del paseo
compuesto, pmf de Poisson, descomposición del trabajo (paridad y suelo), DP de masa conservada
(estabilidad frente a la ventana y bajo la cota), evento estricto vs empate, monotonía de
`α_min(d,ε)` hacia `1/2` desde abajo, convolución exacta de varianza contra MC, autocorrelación de
semillas consecutivas, aritmética de D6/D7/D9 y la regresión del corte fijo 0…60.

## 5 · Rendimiento medido (LINEO §6)

Tras compilar y validar. `BenchmarkTools`, `JULIA_NUM_THREADS=4`, `OPENBLAS_NUM_THREADS=1`,
`AMD Ryzen 9 9950X3D`, Julia 1.13.0. `uptime` durante la corrida: carga 0,82 sobre 32 hilos.

| variante | tiempo mediano | asignaciones | hilos |
|---|---:|---:|---:|
| DP alcance `g=1`, `m=6`, `N=206` | 7,375 ms | 11 013 | 4 |
| DP alcance `g=256`, `m=1536`, `N=1736` | 14,275 ms | 329 | 4 |
| `soporte_incremento` `g=1` | 5,628 µs | 10 | 4 |
| `soporte_incremento` `g=256` | 148,717 µs | 15 | 4 |
| `varianza_exacta` (4 factores, 256 bits) | 82,287 ms | 461 422 | 4 |
| `mc_varianza` `n_rep=4000`, hashed | 28,006 ms | 287 703 | 4 |
| `peso_exacto(2^50)` | 113,495 ns | 11 | 4 |
| `prob_empate_reticula(2/5, 1536)` | 1,874 µs | 124 | 4 |

Artefacto completo: `resultados/BENCH.txt`. **Mejora registrada**: la tabla exacta de varianza
pasó de **159 s a 0,18 s** (×880) al acumular los log-factoriales en vez de recomputar `log k!` en
cada evaluación; la validación contra MC se repitió después del cambio y no cambió ningún
resultado.

**Escalado.** La única parte paralelizable es la de Monte Carlo, por réplica
(`Threads.@threads for r in 1:n_rep`, RNG independiente por réplica, contadores enteros y reducción
final ordenada). No se persigue el escalado como objetivo: el caso real tarda milisegundos y el
tope del encargo son 4 hilos.

## 6 · Reproducción

```bash
# desde P-ZRX/P-CRP1/auditoria/
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 ./julia-local.sh \
    --project=veritas/seguridad/crp1-defectos-v1 \
    veritas/seguridad/crp1-defectos-v1/run.jl --resumen \
    --out run-resumen.txt

JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 ./julia-local.sh \
    --project=veritas/seguridad/crp1-defectos-v1 \
    --check-bounds=yes veritas/seguridad/crp1-defectos-v1/test/runtests.jl

# fichas D1 y D8 (requieren GDR-v0.2 y el instrumento original copiado)
./julia-local.sh --project=copia gdr-d1-d8.jl
```

- **Semilla** de Monte Carlo: `0xC057E07` (la del instrumento) o `0x5A71A` para la tabla de
  varianza; declarada en cada artefacto.
- **Versión y hardware:** Julia 1.13.0, `znver5`, 32 hilos lógicos, 123 GiB visibles.
- `Project.toml` + `Manifest.toml` versionados en este directorio.
- Entorno: `resultados/ENTORNO.txt` (con `uptime` y códigos de salida).

## 7 · Límites declarados

- `Float64` en la DP de alcance. Los valores llegan a `1,95e-272`, dentro del rango normal de
  `Float64`; el residuo relativo de la iteración se reporta (`residuo_rel`) y el resultado es
  estable a 15 dígitos al multiplicar por 6 el margen de ventana. **No es una cota certificada**:
  el intervalo certificado es `[max_n P(S_n ≤ −m), (α/(1−α))^{d·g}]`, que para `g=256` es
  `[2,03e-1010, 3,34e-271]`.
- `BigFloat` a 256 bits en las pmf; las masas omitidas por truncar colas se publican (≤ 2,8e-74 en
  la tabla de varianza; los valores negativos ~1e-75 son ruido de redondeo alrededor de 0).
- El contraste con PCO-v0.1 usa su lectura del predicado de Autonomys; **no abrí el Rust de
  `PDF/autonomys-subspace/`** en esta auditoría.
- El modelo de Poisson compuesto es el del instrumento auditado; no es mío y no lo valido aquí.

## 8 · Resultado

Las diez fichas están en `auditoria/INFORME.md`. En una línea: **nueve cargos reales y uno a
medias (D6); ocho cifras publicadas caen, tres cambian y las estructurales se sostienen; el
veredicto de «sobrevive sin recortes» no se mantiene.**
