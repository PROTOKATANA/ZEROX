# CONTRATO.md — contrato del instrumento `reloj-adaptativo-v1`

## 1 · Qué se entrega y qué se afirma

| Entrega | Ruta | Qué sostiene |
|---|---|---|
| Medición de latencia de instrucción AES/VAES | `investigacion/mediciones/latencia-aes/` | M0: latencia de ronda y de bloque, factor de paralelismo |
| Instrumento Julia | este directorio | M1, M2, M3 y su validación |
| Informe | `investigacion/INFORME.md` | respuestas F1–F7 |
| Decisiones pendientes | `investigacion/DECISIONES-PENDIENTES.md` | las bifurcaciones reales |
| Bitácora | `investigacion/PROGRESO.md` | `date`, `uptime`, entradas y salidas |

**Lo que este instrumento NO afirma, y hay que leerlo antes de citarlo:**

- **No fija ningún parámetro de ZEROX.** `N`, `N_max`, `τ`, `ρ_max`, `ε`, `K`, el FTL, la ganancia
  y el retardo son **entradas** de las funciones, con valores de barrido declarados como tales.
- **No mide una red.** M2 y M3 son modelos analíticos y de simulación; no hay nodo, ni red, ni `Δ`
  medida. `Δ` sigue sin medir en este repositorio y el instrumento no la inventa.
- **No propone un mecanismo de consenso.** El §9 del encargo solo pide `BORRADOR-REGLA.md` si F7
  sale afirmativo; F7 sale **negativo**, así que no hay borrador de regla.
- **No revoca `C-TS-04`.** La cita y cuantifica el precio de las alternativas, nada más.

## 2 · Desviación de `veritas/LINEO.md`, argumentada

`LINEO.md` §1 asigna **Julia a CPU** y §5.7 reserva **C++/CUDA a GPU**. §4.1 del encargo pide medir
**latencia de instrucción AES**; eso **no se mide bien desde Julia**. La desviación es esta, y se
argumenta en los dos ficheros que el encargo exige:

### Qué se desvía

Tres programas en **C con intrínsecos** (`aesinst.c`, `carga.c`, `verif8.c`), compilados con `gcc`
y ejecutados con `taskset`, en `investigacion/mediciones/latencia-aes/`.

### Por qué es inevitable

1. **Julia no expone intrínsecos sin `llvmcall`.** Una cadena `x = aesenc(x, k)` repetida exige
   garantizar que el compilador **no reordena ni vectoriza** la cadena. En C se consigue con un
   bloque `asm` en línea, que fija el orden por construcción; en Julia habría que escribir el
   ensamblador a mano con `llvmcall`, que es frágil entre versiones.
2. **La medición es de LATENCIA, no de rendimiento.** `LINEO.md` está escrito para kernels
   numéricos: mide operaciones por segundo y valida contra un oráculo. Aquí la magnitud es el
   tiempo de una cadena **serial de un solo carril**, y lo que hay que evitar es precisamente el
   paralelismo que optimiza un kernel.
3. **El contraste que se busca es con documentación de arquitectura** (Agner Fog, uops.info, AMD
   SOG), no con otra implementación en Julia: el oráculo de esta medición son las tablas del
   fabricante, que hablan en ciclos.

### Qué se pierde, y cómo se compensa

| Se pierde | Compensación |
|---|---|
| `BenchmarkTools` como harness | Contador de rendimiento por hardware (`perf_event_open`) + TSC, ambos en el mismo binario; **mejor** que un cronómetro de pared porque da ciclos. |
| Preasignación y control de asignaciones de Julia | El bucle no asigna: registros `__m128i`/`__m512i` y contadores en registros. |
| `Manifest.toml` para esta parte | `gcc -O2 -march=native …` exacto y `SALIDA.sha256` de los binarios y sus salidas. |
| Ruta única de lenguaje | Puente explícito en `src/medicion.jl`: el instrumento Julia **lee** las salidas crudas y **falla** si falta un fichero o si falta el control de coherencia. No hay valores por defecto silenciosos. |

### Control de que la desviación no contamina la conclusión

- La parte C mide **latencia de instrucción** y la publica con su clase (`medido`).
- La parte Julia **no recalcula** esas magnitudes: las importa del fichero de medición.
- **Controles de coherencia obligatorios** en `aesinst.c`: `lat pxor xmm` debe dar ~2 ciclos
  (latencia real de `PXOR` en Zen 4/5 según uops.info) y `lat bloque PoT xmm` debe dar ~10× una
  ronda. Si el control no aparece, `medicion.jl` **lanza**.

## 3 · Contrato de la parte Julia

- Julia **1.13.0** fijada; `Project.toml` y `Manifest.toml` versionados.
- Ejecución con `veritas/julia.sh --project=.`, nunca el entorno global.
- **Tope de 4 hilos** (`PROMPT.md`): la corrida es secuencial; `JULIA_NUM_THREADS` no se usa.
- Los resultados se escriben **dentro de este directorio** (`resultados/`), nunca en el CWD.
- **Sin `@fastmath`.** `@inbounds` aparece en `Rapido.simular_rapido!` con la justificación escrita
  en el propio código (`idx = max(s − retardo, 1) ≤ s ≤ T`, dentro de `eachindex`) y cubierto por
  el test de invariantes.
- **Aritmética exacta** (`Rational{BigInt}`) en las fronteras de `(ADM)` y en el dominio de
  `C-POT-04`, porque ahí es donde el flotante decide mal: se documenta el caso de 1 ULP en
  `Referencia` y en `resultados/validacion.md`.
- Semillas: no hay Monte Carlo con RNG en este instrumento; M3 es determinista. **No se usan
  semillas consecutivas porque no se usa aleatoriedad** — se declara en vez de omitirlo.

## 4 · Entorno en el que se ejecutó

Ver la cabecera de `HUELLAS.sha256` y `PROGRESO.md`: fecha, `uptime`, hash de Git, CPU, versión de
Julia, `gcc -v` y `perf_event_paranoid`. El **aviso de método** de `PROMPT.md` §7 se cumplió:
nada de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/`
ni `P-ZRX/P-RELOJ/medicion-previa/` fue modificado (comprobado con `sha256sum -c` de entrada).

## 5 · Qué invalida este contrato

- Cambiar `N` a un `N` que no sea múltiplo de 16, o fijarlo: **rompe el aislamiento del encargo**.
- Presentar las cifras de M2/M3 como medidas: son derivadas y simuladas, con su clase declarada.
- Usar los números del 14900KS (`4,841 ns/bloque`, `6,196 GHz`) como medidos: son `[citado]` y el
  propio `chain_spec.rs:128-130` los marca con `TODO: Adjust once we bench PoT on faster hardware`.
