# METODO.md — cómo se midió y cómo se ejecutó cada cosa

## 1 · Presupuesto declarado antes de ejecutar

| Recurso | Tope declarado | Justificación |
|---|---|---|
| Hilos | **4** | `PROMPT.md` (cabecera): «Máximo 4 hilos». El instrumento es secuencial; se usa 1. |
| RAM | **8 GiB** | Los tres modelos son de estado pequeño; el mayor vector de trabajo es de ~10⁴ `Int64`. |
| Disco | **2 GiB** | `resultados/*.md`, vectores y binarios de C. |
| Tiempo por corrida | **minutos** | Cumplido: la suite tarda 0,6 s, las tablas < 1 s, la medición de C ~20 s. |

Ninguno se agotó. Estado: **concluido**, no `inconcluso`.

## 2 · Medición de latencia de instrucción (desviación argumentada en `CONTRATO.md` §2)

Todo vive en `investigacion/mediciones/latencia-aes/`. Reproducción completa:

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-RELOJ/investigacion/mediciones/latencia-aes
bash run-medicion.sh
```

### 2.1 · Reproducción del ancla de `medicion-previa/`

```bash
gcc -O2 -maes -msse4.1 -o aeslat ../../medicion-previa/aeslat.c   # fuente de solo lectura
taskset -c 8 ./aeslat
```

Salida (`mediciones/latencia-aes/aeslat-corridas.txt`): **7,7230 ns/bloque**, 50 000 000 bloques,
0,3862 s. Frente a los **7,7716 ns** publicados en `medicion-previa/MEDICION.md`: **−0,63 %**.
La carga de entrada era 2,81 (no ociosa), la misma condición declarada allí.

### 2.2 · Latencia y rendimiento de instrucciones aisladas

```bash
gcc -O2 -march=native -maes -msse4.1 -mavx2 -mavx512f -mavx512vl -mvaes -o aesinst aesinst.c
taskset -c 8 ./aesinst --n-iter 2000000
```

Mide **ciclos por instrucción con el contador de rendimiento** (`perf_event_open`), no con una
estimación de frecuencia. Controles internos: `lat pxor xmm` (latencia conocida de `PXOR`) y
`lat bloque PoT xmm` (debe ser 10× una ronda).

Resultados en `aesinst-core8-n2e6.txt` y en `PROCEDENCIA.md`.

### 2.3 · Latencia de bloque bajo carga conocida

```bash
gcc -O2 -march=native -pthread -o carga carga.c
for k in 0 1 4 8 16; do ./carga $k 20000000; done
```

**Para qué:** si el tiempo por bloque sube con la carga pero **los ciclos no**, la ronda no se hace
más lenta: baja la **frecuencia**. Es la distinción que decide si el «tercio de latencia» es
arquitectural o de reloj.

### 2.4 · Asimetría producir/verificar

```bash
gcc -O2 -march=native -mavx512f -mavx512vl -mvaes -maes -o verif8 verif8.c
taskset -c 8 ./verif8 300000 3
```

Mismo trabajo por las tres rutas: producir (1 carril), verificar escalar (8 tramos en secuencia),
verificar AVX-512+VAES (8 tramos en paralelo, un tramo por carril de 128 bits de un `zmm`).

### 2.5 · Carriles y techo de la verificación

```bash
gcc -O2 -march=native -mavx512f -mavx512vl -mvaes -maes -o verif16 verif16.c
taskset -c 8 ./verif16 400000 3
```

Barre 4, 8, 12 y 16 carriles en vuelo para ver dónde satura la unidad de VAES. **Es la medición que
fija la cota de `K`**, y por tanto la que decide si `S ≤ ε·K` admite alguna dispersión.

## 3 · El instrumento Julia

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-RELOJ/investigacion/veritas/consenso/reloj-adaptativo-v1
export JULIA_DEPOT_PATH=/home/katana/zeo/ZEROX/P-ZRX/P-RELOJ/investigacion/.julia-depot:$HOME/.julia
../../../../../../veritas/julia.sh --project=. test/runtests.jl    # 1071/1071
../../../../../../veritas/julia.sh --project=. run.jl --todo       # tablas en resultados/
```

**Nota de entorno, y no es un detalle.** El depósito de Julia del sistema
(`~/.julia/compiled`) es de **solo lectura** para este proceso, así que la precompilación falla con
`EROFS`. Se resuelve con un depósito **dentro de la zona de escritura** del encargo, con el del
sistema detrás para no copiar paquetes:

```text
JULIA_DEPOT_PATH=<P-RELOJ/investigacion/.julia-depot>:~/.julia
```

El primero es el de escritura (aquí se compila el paquete local), el segundo es de lectura y aporta
los paquetes del catálogo aprobado. **No se instaló nada**: el `Manifest.toml` es el de la
plantilla de `veritas/plantilla/`. Esto se declara porque afecta a la reproducción: quien repita
esto sin el depósito escribible verá `EROFS`, no un fallo del instrumento.

## 4 · Perfil y rendimiento

| Variante | Qué se mide | Resultado |
|---|---|---|
| `Modelos.simular!` | lazo transparente con comprobaciones | referencia funcional |
| `Rapido.simular_rapido!` | mismo lazo, `@inbounds`, sin asignaciones | traza **idéntica** a la transparente (test 6) |
| `Referencia.simular_exacto` | `Rational{BigInt}` | 0 ajustes con signo distinto (39/39 en `resultados/validacion.md`) |
| Suite completa | 1071 aserciones | **1071 OK**, 0 fallos, 0 errores |

Benchmark real (`bench/benchmarks.jl`, salida completa en `resultados/benchmark.txt`,
`BenchmarkTools` tras calentar JIT):

| Variante | Mínimo | Asignaciones | Nota |
|---|---:|---:|---|
| `simular!` (transparente, 4000 slots) | 16,17 µs | **0 bytes** | sin asignar en el bucle |
| `Rapido.simular_rapido!` (`@inbounds`) | 16,56 µs | **0 bytes** | misma traza, mismo coste: no había nada que ganar |
| `barrido_frontera!` (1000 × 16) | 0,50 µs | 0 bytes | |
| `sesgo_mediana_dp(51, 26, 1, 7200)` | **889 ms** | 820 MiB | el oráculo DP es el coste dominante del barrido |

**Del benchmark sale una decisión, y es no optimizar.** El lazo del adaptador ya no asigna y la
variante `@inbounds` **no gana** (16,56 µs frente a 16,17 µs): se conserva la transparente como
camino de producción y la rápida queda como comparación. El oráculo DP es caro (889 ms por llamada,
820 MiB) y **no se optimizó a propósito**: no es el camino de producción, es el oráculo contra el
que se comprueba, y un oráculo opaco es exactamente lo que `LINEO.md` §9 prohíbe. Coste declarado
en vez de descrito.

## 5 · Trazabilidad de cada cifra

Toda cifra publicada lleva su clase en `PROCEDENCIA.md`:

- `medido` — sale de un binario de C de este encargo, con su fichero de salida y su comando;
- `verificado en fuente` — leído en el código del repositorio o de `PDF/autonomix-subspace/`;
- `citado` — de una fuente externa abierta, con URL;
- `derivado` — calculado a partir de los anteriores, con la fórmula escrita;
- `simulado` — de M3;
- `no determinado` — lo que no se pudo cerrar.

## 6 · Lo que se hizo mal y se corrigió (queda escrito)

1. **La primera versión de `sesgo_mediana_adversario` daba `0` sin mayoría.** El oráculo DP mostró
   que el adversario **sí** desplaza la mediana sin mayoría, porque puede ocupar posiciones.
2. **La segunda versión dio una igualdad que no era tal.** Se comparó con el oráculo sobre 660
   combinaciones y se encontraron **294 discrepancias**; se degradó a **cota inferior**, que es el
   lado seguro, y se contaron las discrepancias.
3. **El oráculo DP tiene un modelo que se separa del protocolo fuera del régimen de mayoría.** Se
   detectó con `W = 51, C = 48, δ = φ = 0`, que da mediana 2 s donde la escala honesta daría 25 s.
   Está declarado **inconcluso** ahí.
4. **La primera comparación Float64 vs `Rational{BigInt}` del adaptador exigía identidad bit a bit**
   y fallaba por el redondeo del objetivo. Al aislar la causa se cambió el contrato: se comparan
   **los signos de los ajustes** (invariante del modelo) y se **declara** la discrepancia de
   trayectoria, que una recurrencia compone.
5. **El borde de `(ADM)` en `Float64` decide por 1 ULP.** No es un defecto: el cociente real de dos
   binarios no es el binario del cociente. Se documenta y el test lo comprueba en vez de esconderlo.
6. **Dos errores aritméticos que encontró el revisor del informe, y que se corrigen aquí.**
   - **`1,52×` en el reparto de F3.** Se había multiplicado un cociente de **ciclos por ronda**
     (4,001/3 = 1,333) por uno de **frecuencia por bloque**. El factor correcto usa **ciclos por
     bloque**: 42,01/30 = **1,400**, y 1,400 × 1,141 = **1,598**, que es exactamente el cociente de
     la fila de ns (7,739/4,841 = 1,599). **El 1,605 del encargo era correcto; el 1,52 era el
     error.** El veredicto de F3 no cambia —la latencia en ciclos no es un suelo por fabricante, y lo
     que separa a las dos máquinas es sobre todo la frecuencia— pero el número publicado sí.
   - **`ε_min = 1/(ρ·K)` en la correspondencia de §4.3.** La correcta es **`ε_min = ρ/K`**, porque
     `ρ := t_s/t_f` (cuántas veces más lenta es la lenta) es la MISMA cantidad que la frontera `S`,
     no su recíproca: `t_p` es el **más rápido**. Con `ρ = 3` y `K = 16`, `ρ/K = 18,75 %` frente a
     `1/(ρ·K) = 2,08 %`, **un factor 9**. La comprobación que lo cierra: con `ε = 2,08 %` y `K = 16`
     la propia tabla da `ρ_max = 0,33`, que no admite ni la máquina idéntica. El titular de F7 ya era
     el correcto y **no cambia**; lo que cambia es la caja.
   - **Las dos correcciones están cubiertas por tests de regresión** (`test/runtests.jl`):
     `epsilon_minimo(3.0, 16) == 3/16`, que `1/(3·16)` **no** admite `ρ = 3`, y que `3/16` sí. Si
     alguien vuelve a invertir la fórmula, la suite falla.
   - **Causa raíz, para que no se repita:** definir `ρ` sobre **tiempos por bloque** y llamarlo
     «ventaja» invita a invertirlo. El informe ahora escribe `t_f` y `t_s` antes de la fórmula y
     ancla la nomenclatura en `ρ_max = v_A,max/v_ref` (`SPEC.md` §7.3).
