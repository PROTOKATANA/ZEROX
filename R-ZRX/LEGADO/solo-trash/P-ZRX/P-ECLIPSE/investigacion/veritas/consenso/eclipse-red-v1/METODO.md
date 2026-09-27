# METODO — `eclipse-red-v1`

Cómo se ejecuta, cómo se valida y qué se hizo para que el puerto fuera **fiel** y no sólo
**plausible**.

## 1 · Comando exacto

```bash
cd P-ZRX/P-ECLIPSE/investigacion/veritas/consenso/eclipse-red-v1

export JULIA_DEPOT_PATH=/home/katana/zeo/ZEROX/P-ZRX/P-ECLIPSE/.julia-depot:$HOME/.julia
JULIA=/home/katana/zeo/ZEROX/veritas/julia.sh   # añade ~/.juliaup/bin al PATH y quita LD_LIBRARY_PATH

$JULIA --project=. run.jl --entorno      # cabecera de entorno
$JULIA --project=. run.jl --control      # control positivo de D8 A3b
$JULIA --project=. run.jl --variantes    # las tres variantes contra las tablas de 11b
$JULIA --project=. run.jl --regimen      # F2: Δ medida y peso por SR
$JULIA --project=. run.jl --sensores     # E1/E2 con aritmética exacta
$JULIA --project=. run.jl --captura      # sección D
$JULIA --project=. run.jl --flujo        # §4.3 y F5

$JULIA --check-bounds=yes --project=. test/runtests.jl
```

`--check-bounds=yes` **es obligatorio** en los tests: el instrumento usa `@inbounds` en dos bucles
de barrido y LINEO §3.3 exige que CI corra también con comprobación de límites. De hecho, un fallo
real de este puerto fue exactamente eso: buffers de vista que no crecían con el estado y una
escritura fuera de rango que **segfaultó** en vez de fallar con un error. Está comentado en
`mundo.jl`.

## 2 · La decisión de método que hace posible el control

**El control positivo exige reproducir los mismos números, no unos parecidos.** La fila publicada de
D8 A3b es un promedio de Monte Carlo sobre 12 semillas del instrumento **Python** heredado, y ese
instrumento siembra con **cadenas** (`random.Random(f"{sem}|{T}|{α}|{E}|{fc}")`) además de con
enteros. Ningún generador de Julia reproduce esa secuencia.

Por eso `src/pyrng.jl` implementa **la réplica bit a bit de `random.Random` de CPython**: MT19937
con `init_by_array` y el sembrado por cadena (`int.from_bytes(s.encode() + sha512(s.encode()).digest(),
'big')`). Es un **puerto de la semántica del oráculo**, no una elección de estilo, y está declarado
como tal en el propio fichero.

**Validación del RNG, en tres capas:**
1. Vector publicado del MT19937 de referencia (`init_genrand(5489)`), 10 valores: valida twist y
   tempering.
2. `random.Random(0/1/42).random()`: `0.8444218515250481`, `0.13436424411240122`,
   `0.6394267984578837` — coincidencia exacta de 17 dígitos: valida `init_by_array` y `res53`.
3. **El control positivo entero.** Es la validación de la capa de cadena y del resto del modelo.

## 3 · Controles, y qué controla cada uno

| Control | Qué demuestra |
|---|---|
| **Positivo (D8 A3b)** | Que el puerto es **fiel**: promedios a 4 decimales **y** conteos de bloques (`n_C = 522` y `402`) |
| **Positivo (11b §A.2–A.3)** | Que las tres variantes son fieles: 6 filas con sus `n` (215, 193, 190, 178, 175, 180) |
| **Positivo (11b §B.1)** | Que el modelo de frontera secuencial es el mismo: `B` celda a celda en lognormal y Pareto |
| **Positivo (11b §C.1/C.5)** | Que la aritmética exacta de Poisson es la misma: `n_min` 6/23/66/211 y `α = 0,9249` |
| **Identidad por construcción** | `P(D>8) = 0,0100` con lognormal(4, 8). **Cazó un defecto real de la CDF** |
| **Identidad `SR=0` ↔ conteo** | Que reutilizar el motor de GDR para el régimen histórico es legítimo |
| **Criterio α** | Toda tabla lleva `α = 0` (sin espacio) y `α > 0` |
| **Cobertura** | Toda tabla imprime `n`; con `n = 0` la fila no dice nada |
| **Negativo** | Sin ataque (`paso = 1`) E2 no dispara — 11b §C.5 lo mide; aquí se conserva la fila `E=0`/`paso=1` |

**Ningún control compara una fórmula consigo misma**: cada uno compara con un **artefacto publicado**
de otro instrumento (Python) o con una **identidad forzosa** de la definición.

## 4 · Referencia y kernel

LINEO §1 pide `referencia.jl` + `rapido.jl` comparados. **Aquí esa pareja la aporta `GDR-v0.2`, que
ya la tiene**: `EstadoReferencia` (oráculo con `BigInt` y conjuntos) frente a `EstadoRapido` (kernel
SoA con `BitSet` y `BW256`), con `equivalencia` y 577 131 aserciones declaradas en su
`resultados/TESTS.txt`. **Reimplementar esa pareja habría sido exactamente lo que el encargo §3
prohíbe** («se reutiliza, no se reimplementa»).

Lo que este instrumento **sí** escribe por duplicado es la **medida del mergeset**, porque es la que
necesita la política de padres y GDR no la expone: se calcula como `|past(B) \ (past(sp) ∪ {sp})|`
sobre los `BitSet` de ancestros, que es **la misma definición** que el BFS de `r8c_gd`.

## 5 · Paralelismo y RNG

- **Ejecutado en serie, 1 hilo.** El barrido cabe en minutos y `LINEO.md` §7 dice que el número de
  hilos lo decide el escalado, no la ambición. **Los 8 hilos del encargo son un techo, no un
  objetivo**; no se ha medido escalado porque no hacía falta.
- **Monte Carlo:** 12 semillas, las mismas del oráculo. **El hallazgo de `P-ZRX/P-PUERTA/` —que
  semillas consecutivas de `StableRNGs` sesgan el MC— se respeta por construcción**: el único MC de
  este instrumento usa el RNG de CPython con las semillas del oráculo (obligatorio para el control),
  y cualquier MC nuevo usaría derivación **no consecutiva**. `StableRNGs` está declarado en
  `Project.toml` pero **no se usa**; se dice aquí para que nadie suponga lo contrario.
- **Reducción determinista**: las agregaciones son **conteos enteros** sumados en orden de semilla.
  Ninguna suma de `Float64` decide un veredicto.

## 6 · Reproducibilidad

Cada artefacto de `resultados/` lleva la cabecera con `VERSION` de Julia, hilos, CPU, RAM y el
comando exacto. `Manifest.toml` está versionado. `julia-version.toml` fija `1.13.0`.

**Semilla:** el instrumento no tiene una semilla maestra global; las semillas son el argumento
`semilla` de `ParametrosMundo`, y el control usa `1:12` porque el oráculo usó `range(1, 13)`.

## 7 · Qué haría falta para cerrar lo que queda abierto

1. **Simular la partición de flujo de extremo a extremo**: construir, por nodo, el estado GHOSTDAG
   restringido a `V_j(B)`, calcular `I_j` con `C-FLU-04` y comparar anclas y flujos. Exige un
   GHOSTDAG sobre un sub-DAG **por vista**, que GDR-v0.2 no ofrece.
2. **Medir los ms del paso 1b de `C-POT-08`** por bloque ajeno. Es la única medida que falta para
   decidir F5, y no necesita red.
3. **Medir `Δ` en red real.** Bloquea `L_suelo_slots`, el suelo de `F`, `B` y `n_min`.
