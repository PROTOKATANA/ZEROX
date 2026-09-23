# INFORME del instrumento — `veritas/economia/tasa-identidad-v1`

Ficha técnica del aparato. **Las conclusiones están en `P-ZRX/P-TASA/investigacion/INFORME.md`**; aquí
sólo se documenta qué se construyó, cómo se verificó, cuánto costó y qué no alcanza.

**Categoría:** `economía` (dominante); `seguridad` y `consenso` (secundarias). El tema dominante es el
coste y el reparto de un precio —a quién disuade una tasa por identidad y a quién cobra—, por eso
`veritas/economia/` y no `veritas/seguridad/`.

**Fecha:** 2026-09-23 · **Semilla:** `0x54415341` («TASA») · **Julia:** 1.13.0 · **CPU:** AMD Ryzen 9
9950X3D (`znver5`), 32 hilos lógicos, 123 GiB · **Sin Python**, CPU only (`veritas/julia.sh`).

---

## 1 · Pregunta

¿Una **tasa fija por identidad** (no proporcional al espacio, no recuperable) **toca el doble farmeo**
o sólo **habilita** reglas de exclusividad? Y si sólo habilita: **¿es el remedio peor que la
enfermedad** por la vía `β_d → β_x`?

## 2 · Método

Modelo contable de **medias** sobre espacio normalizado a 1, idéntico al de
`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` §1 (la deriva `g` y su raíz `α*`), extendido con el coste
de identidad y una distribución de tamaños de granja. Cuatro capas:

| capa | contenido | aritmética |
|---|---|---|
| `src/modelo.jl` | deriva, `α*`, las tres variantes de coste, `f_detenida`, `τ_min`, distribuciones (`ParetoTruncado`, `Discreta`, `Iguales`, `DosNiveles`), horarios `φ` y la dicotomía | genérica sobre `T<:Real`; `Rational{BigInt}` en toda la frontera |
| `src/referencia.jl` | oráculos: `Φ` por **sumas de Riemann** con cotas por monotonía; reclutamiento por **fuerza bruta** y **exacto de dos niveles**; barrido exhaustivo de la dicotomía | exacto |
| `src/rapido.jl` | kernels `Float64` tipoestables, barrido de tasa, **Monte Carlo con RNG por réplica** (`Philox4x` con semillas mezcladas con `splitmix64`, no consecutivas), IC de Wilson y t | `Float64` + IC |
| `src/validacion.jl` | las rutinas que cuentan controles y devuelven los fallos con su mensaje | — |

**Decisión de representación.** La operación dominante es evaluar `Φ(x)` y compararla con `1−2α` en
rejillas de tamaños y tasas: estructura **escalar y contigua** (nada de grafos ni diccionarios), con
las familias discretas **comprimidas** (`Iguales`, `DosNiveles` son funciones escalón, no vectores de
10⁶ racionales). El reclutamiento del atacante es un problema de **selección con coste fijo por
granja** —el coste por unidad de espacio **no** es constante—, así que el avaricioso es sólo una cota y
hace falta un exacto; por eso existe `reclutamiento_bruto` (fuerza bruta) y
`reclutamiento_dos_niveles` (enumeración exacta `O(2K)`).

## 3 · Verificación

**863 controles, 0 fallos** (`resultados/TEST.log`, 1 hilo, `--check-bounds=yes`). **Ningún test
compara una fórmula consigo misma**; cada vía se contrasta con otra independiente:

| vía | contra qué se contrasta |
|---|---|
| `g(α*) = 0` exacto y signo estricto a ambos lados | 180 combinaciones de `(β_d, β_x, η_h, η_a)` con `Rational{BigInt}` |
| `Φ` primitiva cerrada | **suma de Riemann** con cotas inferior/superior por monotonía (`V1-pareto-riemann.tsv`) |
| Monte Carlo | `Φ` cerrada con **IC de Wilson** (es una proporción desde que muestrea la medida de espacio) y **IC t** entre réplicas; por debajo de 20 aciertos esperados se declara **no aplicable** (`V2-mc-exacto.tsv`) |
| avaricioso de reclutamiento | **fuerza bruta** en 201 instancias (`V3-reclutamiento.tsv`, 49 no óptimas) y **exacto de dos niveles** |
| dicotomía `partir ⟺ regresiva` | dos expresiones distintas (`N·φ(f/N)`, `φ(f)/f`) más la subaditividad estricta (`F4b-dicotomia.tsv`) |
| reglas del proyecto | barrido del fuente: `@fastmath`, `@turbo`, `Float32` **fuera de comentarios** |

**Defectos propios detectados y corregidos** (§7.2 del informe principal): MC sobre la medida de
conteo (inútil en la cola), IC de Wilson mal usado con pocos eventos, contraejemplo mal construido,
`escribir` perdiendo columnas en silencio, identificador inválido, `$f()` en BenchmarkTools, y el
verificador de macros delatándose a sí mismo. Los siete tienen vector de regresión.

## 4 · Rendimiento

`resultados/BENCH.txt`, `BENCH-tabla.tsv`, `ESCALADO.tsv`. `uptime` en la cabecera: carga `1,88` con 4
hilos declarados ⇒ **medido con carga ajena**.

| Variante | Tiempo | Asignaciones | Hilos | Frente a la referencia |
|---|---:|---:|---:|---|
| `Φ` cerrada, rejilla 10⁴ | 0,153 ms | **0 B** | 4 | `= Phi_espacio` |
| `Φ` Riemann `K = 20 000` (oráculo) | 1,185 ms | 0 B | 4 | **acota** la cerrada |
| MC 1 réplica `M = 10⁴` | 0,167 ms | **0 B** | 4 | coincide (IC) |
| MC 4 réplicas, 1 → 4 hilos | 0,658 → 0,176 ms | 1 744 → 3 504 B | 1 → 4 | **idéntico**, ×3,75 |
| `f_detenida`, `τ_min` | `1,7·10⁻⁶` / `1,3·10⁻⁶` ms | **0 B** | 4 | — |
| barrido de tasa 200 puntos | 0,0062 ms | 3 328 B | 4 | monótono |
| reclutamiento exacto `K = 10⁶` | 0,686 ms | **0 B** | 4 | `=` fuerza bruta |

`@code_warntype`: `Body::Float64` sin `Any`. **JET 0.12.1: 0 diagnósticos** en los cinco kernels.
Sin `@fastmath`, sin `@turbo`, sin `Float32`, sin `@simd`. Escalado `1 → 2 → 4` hilos: ×1,92 y ×3,52,
**bit a bit idéntico**; **se conserva 4**, el tope del encargo.

## 5 · Reproducción

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-TASA/investigacion/veritas/economia/tasa-identidad-v1
export JULIA_DEPOT_PATH="/home/katana/zeo/ZEROX/P-ZRX/P-TASA/.julia-depot:/home/katana/.julia"
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --seed 0x54415341
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
./correr-todo.sh          # las tres, más el escalado 1/2/4
```

`Project.toml` es el catálogo del proyecto; el `Manifest.toml` es el de la plantilla compartida
(`veritas/plantilla/`). El depósito de precompilación vive fuera del encargo, en
`P-ZRX/P-TASA/.julia-depot` (caché regenerable, **no** un artefacto del informe).

## 6 · Límites del aparato (lo que no puede afirmar)

- **El puente espacio → tasa no existe** (`P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1). Aquí no se usa, pero
  no se cierra: `α`, `β`, `f` son fracciones de **espacio**.
- **La distribución de tamaños es una hipótesis** (H1): el instrumento la recibe; no la mide. **El
  teorema de la dicotomía no depende de ella; `τ_min` y la magnitud de la regresividad sí.**
- **El MC sólo certifica donde su resolución alcanza** (≥ 20 aciertos esperados). En la cola extrema
  el resultado se declara **no aplicable** y quien certifica es la **cota de Riemann**, que es exacta.
- **En las distribuciones discretas**, `τ_min` tabulado es un **ínfimo no alcanzado** (el umbral
  `Φ(f*) = p` no se da por igualdad): hay que superarlo estrictamente. Expuesto en la columna
  `brecha_Φ_menos_p` del artefacto `F2c`.
- **`κ`, `q`, `V`, `τ` y el resto de símbolos no se fijan.** El aparato da funciones y regiones.
- **No hay integración en `crates/`.** Es un modelo cuantitativo, no una migración.
