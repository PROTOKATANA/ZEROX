# INFORME — espacio-prestado-v1

**Categoría:** `seguridad` (dominante) · `consenso` y `economía` (secundarias). El asunto dominante
es la seguridad del consenso base frente al espacio prestado y el castigo necesario; por eso vive
en `seguridad` y no en `economía`.

**Encargo:** `P-ZRX/P-PRESTAMO/PROMPT.md` + `P-ZRX/P-PRESTAMO/ADENDA-1.md`. **Informe del
encargo (con las seis respuestas):** `P-ZRX/P-PRESTAMO/investigacion/INFORME.md`.

**Entorno.** Julia 1.13.0 (`/home/katana/zeo/ZEROX/veritas/julia.sh`), CPU AMD Ryzen 9 9950X3D
(16 núcleos / 32 hilos). `JULIA_DEPOT_PATH` propio en `investigacion/.julia-depot` (no se comparte
entorno ni se usa el global). Sin Python y sin GPU.

**Presupuesto.** 8 hilos, 8 GiB de RAM, 256 MiB de disco, minutos por tarea. No se agotó.

---

## Pregunta

¿Cuánto baja el umbral de una rama privada cuando el espacio honesto se presta a las dos ramas,
qué probabilidad tiene el atacante **dentro de la ventana** `F`, y cuánto castigo hace falta para
que el consenso base siga siendo seguro suponiendo que el doble farmeo es barato?

## Método

Cuatro piezas, por este orden (LINEO §2: complejidad, oráculo, kernel, medición):

1. **Álgebra exacta de la deriva** (`src/modelo.jl`): superficie `α*` en `Rational{BigInt}`, con
   `g(α*) = 0` exacto y signo estricto a los dos lados.
2. **Oráculo del paseo** (`src/rapido.jl::primera_dp`): DP de tiempo de parada sobre el estado
   `(mínimo, posición)`, `O(T·(d+1)·(d+T))`, con absorción en la primera visita a `−1` y residuo de
   conservación comprobado en cada llamada.
3. **Vías independientes de contraste** (`src/referencia.jl`): enumeración exhaustiva recursiva de
   las `2^T` trayectorias con bandera de primera visita (la trayectoria sigue; la visita se cuenta
   una vez), forma cerrada `(q/p)^(d+1)` en horizonte largo, y Monte Carlo `Philox4x` con semilla
   contracorriente por réplica e IC de Wilson.
4. **Juego económico** (`run.jl` tareas `f3`–`f6`): soborno necesario, región `(ρ_ret, T_v)` y
   coste del honesto, todo en función de símbolos; **ningún parámetro se fija**.

**Elección de estructuras (LINEO §4).** Estado entero acotado y vector `Float64` contiguo con doble
buffer `v`/`vn` (leer `v`, escribir `vn`, intercambiar al final: escribir en `v` mientras se lee
`v` cuenta dos veces las transiciones). Cuadrícula de seguridad `H = d+T+2`. Paralelismo por celda
de la rejilla de parámetros, con buffers propios por llamada y sin estado compartido.

## Resultado

- **Deriva (`demostrado`).** `α* = (η_h − η_a β_d − (η_h+η_a) β_x)/(η_h+η_a)`; con `η=1`,
  `(1 − β_d − 2β_x)/2`. Cada unidad de alquiler exclusivo baja el umbral **el doble** que una de
  doble farmeo. Contiene `β_d > 1−2α` y `α+β_x > 1/2` como casos exactos.
- **Ventana (`demostrado` la DP, `derivado` la rejilla, `condicionado` a H-PUENTE).** Todas las
  celdas se calculan con la **DP exacta** (una versión anterior publicaba `(1−p_adv)^F` como si
  fuera la probabilidad de la celda: **no acotaba**; `PROGRESO.md` O6). Donde el adversario no gana
  la deriva, `P` **decrece con `F`** y el mínimo medido es `8,53·10^-277`; la probabilidad salta a
  orden 1 **sólo al cruzar `g = 0`** (`β_d > (1−2α)/(1−α)`). Para `P ≥ 10^-6` con `α = 0,33` hace
  falta `β_d ≈ 0,44·(1−α)` con `F = 3.600` (0,38 con `F = 1.019`), y **la deriva sigue sin
  ganarse**. Las celdas donde la DP subdesborda `Float64` se publican con el **límite exacto**
  `(q/(1−q))^(d+1)` y la etiqueta `limite_ruina`, no con un cero.
- **Juego (`derivado`).** Sin castigo, `b* = 0` y `β_d` es dominante: `α*` cae a `α/2` y el umbral
  se pierde ⇒ **el castigo es imprescindible para el umbral**. La retención necesaria es
  `κ·q·(ρ_ret·ingreso·T_v + c_r + ingreso·M) > V/N` con `T_v > F + margen`.

## Verificación

`julia --check-bounds=yes --project=. test/runtests.jl` → **125/125 en verde** (perfil de
referencia, 1 hilo). Contraste entre vías independientes en **714 celdas exactas**
(`Rational{BigInt}`, `p ∈ {1/10…9/10}`, `d ∈ 0…7`, `T ∈ 0…16`): DP == enumeración exhaustiva,
`interior + paso = 1` exacto, `P_T` monótona. El kernel `Float64` coincide con el exacto a
`< 10^-12` relativo; `BigFloat` a 256 bits también; el Monte Carlo cae dentro del IC de Wilson del
valor exacto.

**Siete defectos propios detectados y corregidos** (cada uno con vector de regresión, detalle en
`PROGRESO.md` §3 y en la cabecera de `src/referencia.jl`): DP con `−1` absorbente (calcula
`P(Z_T=−1)`, no la primera pasada); escritura en `v` mientras se lee `v`; truncación de la
cuadrícula; enumerador que cortaba la recursión al tocar `−1` (contaba de más); mínimo inicial mal
puesto (daba `>1`); una fórmula de reflexión con el tope de suma mal puesto (retirada, no
publicada); `Random123.Philox4x64` inexistente (el paquete exporta `Philox4x`).

**Notación (y una acusación retirada).** `BASELINE.md` escenario 0 es **correcto y no se toca**:
en su convención `p` es la tasa del honesto y `q` la del adversario, luego `q < p` es «adversario
en minoría» y `(q/p)^(d+1) < 1`. Una versión anterior de este instrumento lo acusó de tener la
razón invertida: **era un error de lectura y se retiró** (`PROGRESO.md` O1). El kernel reproduce
su fórmula con exactitud cuando se le pasa la tasa del adversario como primer argumento; **ninguna
tabla publicada cambia**. Sí se corrigió un defecto real de notación en `p_superar_exacto`, que
tomaba la tasa del honesto mientras el módulo declaraba la del adversario (no afectaba a ninguna
cifra: sólo se usaba en asertos). Se añadió la reconciliación con `BASELINE.md` a los tests.

## Rendimiento

`resultados/BENCH.txt` (carga ajena `1,15` con 4 hilos ⇒ **medido con carga ajena**).

| Variante | Mediana | Asignaciones | Hilos | Frente a la referencia |
|---|---:|---:|---|---|
| DP `Rational{BigInt}` `d=2,T=12` | 0,161 ms | 11.555 | 1 | fuente de verdad exacta |
| Enumeración exhaustiva `T=18` | 118,2 ms | — | 1 | coincide en 714 celdas |
| DP `Float64` `d=10,T=1.000` | 13,36 ms | 6 | 1 | error rel. `< 10^-12` |
| DP `Float64` `d=100,T=3.600` | 1.543 ms | 6 | 1 | idem |
| Barrido 205 celdas, serial | 863,4 ms | — | 1 | — |
| Barrido 205 celdas, paralelo | 253,9 ms | — | 4 | idéntico, **×3,40** |

`@code_warntype primera_dp(::Float64, ::Int, ::Int)` → `@NamedTuple{paso::Float64, interior::Float64}`,
sin `Any`. Sin `@fastmath`, sin `@simd`, sin `Float32`.

## Reproducción

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-PRESTAMO/investigacion/veritas/seguridad/espacio-prestado-v1
export JULIA_DEPOT_PATH="$PWD/../../../.julia-depot:/home/katana/.julia"
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --check-bounds=yes --project=. test/runtests.jl
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
./correr-f2.sh
JULIA_NUM_THREADS=4 /home/katana/zeo/ZEROX/veritas/julia.sh --project=. \
  run.jl --tarea f1 --tarea f3 --tarea f4 --tarea f5 --tarea f6 --seed 0x5052455354414d4f
```

**Artefactos:** `resultados/F1-superficie.tsv`, `F2-ventana.tsv`, `F2b-betad-minimo.tsv`,
`F3-juego.tsv`, `F4-coste-absoluto.tsv`, `F5-region.tsv`, `F6-honesto.tsv`, `F2-corrida.log`,
`BENCH.txt`. **Hipótesis falsables:** `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## Límites

Todo resultado de ventana y de juego está **condicionado a H-PUENTE** (el puente espacio → tasa no
existe en el repositorio: `DEFECTOS.md` C1). `F`, `M`, `ρ_ret`, `T_v`, `κ`, `q`, `η`, `V`, `c_r`
son **símbolos**: no se fija ninguno. La rejilla completa de F2 con `F = 7.200` y `α` alto quedó
**inconclusa por coste** (minutos por celda). La asimetría de la carrera del ancla (`P5`) no está
medida y `κ` se barre constante. El escenario de compra de varianza (R-FIN-13′ sin especificar) no
se cuantifica y, si se especifica, **F2 no aplica**. Nada de esto está implementado en `crates/`:
es un modelo, no una migración.
