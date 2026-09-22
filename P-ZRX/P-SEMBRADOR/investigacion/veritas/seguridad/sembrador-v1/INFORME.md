# El ataque es rentable exactamente donde `coste_intento/recompensa < w/H`; hoy faltan el coste del ploteo parcial y la probabilidad de pago DAG para afirmar en qué lado está ZEROX.

## Estado y alcance

**Resultado `derivado y verificado por instrumento`, condicionado.** Este proyecto reconstruye el
modelo mínimo del margen del sembrador sin heredar precios, hardware ni el punto de equilibrio
histórico `A*`. No decide un parámetro de consenso y no demuestra que el ataque sea rentable en la
red actual. La categoría dominante es `seguridad`; economía y rendimiento son secundarios.

Presupuesto declarado antes de ejecutar: máximo **8 hilos CPU, 16 GiB de RAM, 2 GiB de disco y
corridas de minutos**. Si se agota, el estado es **inconcluso**. El kernel es O(n) en las filas del
barrido, O(1) por fila y O(n) de salida. No usa RNG ni GPU; la ejecución publicada usa un hilo porque
el cálculo es corto y el benchmark debe justificar cualquier paralelización. El barrido publicado
midió 311 928 KiB de RSS máximo y 0,54 s de pared con `/usr/bin/time -v`; el directorio ocupa
116 KiB.

## Modelo

Para `rho > 1`, el adelanto estacionario discreto es

```text
A = max(0, (L - 1 - W_dec) + I(1 - 1/rho)) slots
w = floor(A) retos futuros completos
```

Para `rho <= 1`, `A=w=0`. El `-1` es la frontera `t_(j+1)-1`; la forma continua pedida por el
encargo es la misma sin ese slot. La sensibilidad se documenta, no se esconde como parámetro.

Sea `N_h` el número de registros/piezas honestos y `lambda_sol` la tasa esperada de soluciones
válidas por slot. La entrada `H=espacio_honesto` es **espacio efectivo**:

```text
H = N_h / lambda_sol
p = 1/H                         probabilidad de un registro por reto
q = 1 - (1-p)^w                 probabilidad de al menos un acierto en la ventana
mu = E[soluciones/intento] = w/H
E[intentos/candidato no vacío] = 1/q
E[intentos por bloque] = 1/mu   cociente de expectativas en régimen
M = coste_intento / (recompensa * mu)
```

`recompensa = pi_pago × recompensa_nominal`: incorpora que una solución válida puede no ser la
copia pagable del DAG. El ataque es rentable si y solo si `M < 1`, equivalente a
`coste_intento/recompensa < w/H`. Se usa `mu`, no `q`, porque la identidad de solución incluye el
slot y una unidad retenida puede acertar y cobrar en más de un slot de la ventana. `q` se conserva
como diagnóstico de cuántos intentos hacen falta hasta un candidato no vacío. Incluso si el
atacante se detiene al hallarlo, `E[X|X>0]=mu/q`, de modo que el coste por bloque es
`(coste_intento/q)/(mu/q)=coste_intento/mu`. `q` sería la magnitud económica si una regla futura
limitase el pago a una sola solución por intento y ventana; no existe aquí tal regla. Cuando `w=0`,
el ataque dirigido no tiene oportunidad y el margen se declara infinito. La vía rápida evalúa `q`
con `-expm1(w*log1p(-1/H))`; el oráculo usa `BigFloat` y la potencia directa. Ambos calculan
exactamente `mu=w/H` bajo este modelo.

## Por qué la unidad es un registro y no un sector

**`Verificado en fuente`.** `SectorId` depende de clave, índice e historia, y cada `piece_offset`
tiene semilla PoS propia (`PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:54-127`).
El reto elige un único `s-bucket`
(`PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:116-123`); la auditoría lee solo ese bucket
(`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs:54-103`). Al convertir un
candidato, el prover regenera la tabla del registro ganador, reconstruye sus chunks y crea el
testigo KZG (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/proving.rs:243-328`). El
verificador valida esa pieza y sus testigos, sin
probar que el resto del sector exista (`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:228-346`).

**`Demostrado por inspección de dependencias`.** Existe una ruta de intento parcial por registro:
el verificador depende de la pieza ganadora, su tabla PoS, chunks y testigos, pero no de un compromiso
del sector completo. El código upstream de plotting genera sectores completos y todas sus piezas
(`PDF/autonomys-subspace/crates/subspace-farmer-components/src/plotting.rs:236-320,378-420`), pero
esa es una implementación de granjero, no una obligación comprobada por consenso. Lo
**`no determinado`** es el coste y el kernel optimizado de esa ruta. Por eso los 69,363 s medidos
por sector completo en `research/coste-ploteo-medido.md` no son `coste_intento`. Hace falta
implementar y medir un plotter parcial adversarial antes de convertir el modelo en cifra.

La calibración upstream confirma la unidad: `pieces_to_solution_range` incluye el factor de bucket
ocupado y divide por el número de piezas (`PDF/autonomys-subspace/crates/subspace-core-primitives/src/solutions.rs:26-58`).
Con `NUM_S_BUCKETS/NUM_CHUNKS=2`, una prueba disponible aporta factor 1/2 y el test de distancia
aporta aproximadamente `solution_range/2^64`: `p_atómico ≈ solution_range/2^65 ≈ lambda_sol/N_h`.

## Diferencia frente al modelo histórico

El informe de ronda 10c (`research/scripts/d9-ronda10c/informe.md`) calculó un margen
`A*/lookahead` a partir de precios supuestos y del coste de un sector completo. Su cinemática del
PoT es útil y se porta; su economía no se hereda. El nuevo modelo separa:

- `rho, L, I, W_dec`, que determinan `w`;
- el rango y el espacio, resumidos sin fijarlos en `H=N_h/lambda_sol`;
- el coste total medido del intento parcial;
- el valor esperado pagable en el DAG.

Así el resultado cambia al variar `rho` o `L`: ambos cambian `w`, luego `mu`, intentos por bloque y
margen. Para `w << H`, además `q ≈ mu`; el margen exacto del modelo es
`M = coste_intento × H /(recompensa × w)`, que recupera la dependencia inversa con el lookahead sin
introducir precios de GPU o SSD.

## Representación y veracidad numérica

Cada fila usa dos `struct` inmutables concretos (`ParametrosMargen{Float64}` y
`ResultadoMargen{Float64}`), apropiados porque el kernel consume todos sus campos juntos. El barrido
preasigna la salida y escribe una posición por entrada. No usa `Any`, `@fastmath`, `@inbounds`, SIMD
ni reducción flotante. La referencia `BigFloat` de 256 bits cubre ceros, umbral de rentabilidad,
espacios grandes y varias ventanas. El criterio es coincidencia del número entero de retos y error
relativo `<= 64 eps(Float64)` en todas las salidas flotantes finitas.

## Ejecución reproducible

Todos los números del barrido son argumentos; no hay precios ni parámetros de consenso por defecto:

```bash
cd /home/katana/zeo/ZEROX
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  ./veritas/julia.sh \
  --project=P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1 \
  --threads=1,0 \
  P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/run.jl \
  --rho <lista> --L <slots> --I <slots> --W-dec <slots> \
  --coste-intento <lista> --recompensa <lista> --espacio-honesto <H=N_h/lambda_sol>
```

Pruebas y diagnósticos:

```bash
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 ./veritas/julia.sh \
  --project=P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1 \
  --threads=1,0 -e 'using Pkg; Pkg.test()'

JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 ./veritas/julia.sh \
  --project=P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1 \
  --threads=1,0 \
  P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/bench/benchmarks.jl
```

Los resultados medidos se escriben en `resultados/` después de ejecutar. `run.jl` registra fecha,
hash Git, Julia, CPU, hilos, argumentos y todas las entradas por fila. No hay semilla porque el
instrumento es determinista.

## Resultado reproducido en esta máquina

**`Medido` el 2026-09-20, Julia 1.13.0, CPU `znver5`, 1 hilo Julia / 0 interactivos.** Las 42
comprobaciones pasan: entradas, bordes, umbral económico exacto, sensibilidad a `rho` y `L`,
monotonías, equivalencia BigFloat y parseo de scripts. JET informa `No errors detected` y
`@code_warntype` infiere `ResultadoMargen{Float64}`.

El kernel caliente sobre 100 000 filas sintéticas tarda una mediana de **1,484472 ms**, con
**0 bytes y 0 asignaciones** después del calentamiento (mínimo 1,480172 ms). La referencia BigFloat
de una fila tarda una mediana de 2,270 µs, 3 024 bytes y 57 asignaciones. El perfil atribuye el
trabajo al barrido, `log1p` y `expm1`; no justifica hilos ni SIMD para un barrido de este tamaño.
Los artefactos exactos están en `resultados/BENCH.txt`, `WARNTYPE.txt`, `JET.txt` y `PERFIL.txt`.

`resultados/BARRIDO-ADIMENSIONAL.tsv` contiene 96 filas. Es un **barrido de sensibilidad**, no una
estimación de ZEROX: usa `recompensa=1`, cocientes `coste/recompensa` explícitos y valores de `H` de
varios órdenes para mostrar la frontera. `rho`, `L`, `I` y `W_dec` son controles de la ronda 10c,
no parámetros adoptados. Una sección a `coste/recompensa=10^-6`, `H=10^9`, `I=851`, `W_dec=20`
demuestra la variación exigida:

| `rho` | `L` (slots) | adelanto (slots) | `q` | `mu=w/H` | margen `M` |
|---:|---:|---:|---:|---:|---:|
| 1 | 3 600 | 0 | 0 | 0 | infinito |
| 1,001 | 3 600 | 3 579,85 | 3,57899e-6 | 3,579e-6 | 0,27941 |
| 1,001 | 7 200 | 7 179,85 | 7,17897e-6 | 7,179e-6 | 0,13930 |
| 1,5 | 3 600 | 3 862,67 | 3,86199e-6 | 3,862e-6 | 0,25893 |
| 1,5 | 7 200 | 7 462,67 | 7,46197e-6 | 7,462e-6 | 0,13401 |
| 3 | 3 600 | 4 146,33 | 4,14599e-6 | 4,146e-6 | 0,24120 |
| 3 | 7 200 | 7 746,33 | 7,74597e-6 | 7,746e-6 | 0,12910 |

Las 54 filas marcadas rentables y las 18 no rentables solo clasifican esos cocientes de entrada;
24 filas con `rho=1` quedan sin ventana dirigida. No son conteos de escenarios plausibles ni una
probabilidad de ataque.

## Criterio de aceptación y lectura

- **Aceptado matemáticamente:** referencia y kernel coinciden; monotonicidad con `rho`, `L`, coste,
  recompensa y `H`; el umbral `M=1` se reproduce.
- **Rentable condicional:** una fila tiene `M<1`.
- **No rentable condicional:** una fila tiene `M>=1`.
- **Sin ventana dirigida:** `rho<=1` o la fórmula da menos de un reto completo.
- **Inconcluso para ZEROX:** mientras no se midan el coste parcial, `N_h`, `lambda_sol` y `pi_pago`.

## Relación con la regla de flujo pendiente

Este instrumento porta el núcleo cinemático histórico R-FIN-14 para estudiar su frontera económica;
no lo promueve a regla actual. La propuesta de flujo conserva en cabecera
`pot_output(B)=salida(f,slot(B)+D)`, pero declara expresamente que la aritmética de *lookahead*
escrita para la salida del propio slot no se ha rehecho con `+D`
(`P-FLUJO/propuesta/PROPUESTA-SPEC.md:644-650,993-995`). Por tanto, `D` y su
integración final quedan pendientes. Si esa revisión cambia la ventana, hay que sustituir
`adelanto_nucleo`; ninguna clasificación del barrido puede adoptarse antes.

## Limitaciones

El modelo no incluye bootstrap, límite de throughput, retarget durante el ataque, soluciones
múltiples competidoras en un mismo slot, propagación, selección DAG más allá de `pi_pago`, ni el
coste de guardar ganadores. Sí cuenta todos los aciertos de una unidad durante slots distintos de la
ventana. Trata los retos como independientes y permite reutilizar cada intento en toda la ventana.
Tampoco demuestra que el atacante pueda obtener piezas y testigos a la velocidad necesaria; los
incorpora al coste que falta medir.

La fuente histórica `research/coste-ploteo-medido.md` contiene una corrección de 9,32 a 42,92 µs por
auditoría serie y luego conserva frases con la cifra retirada. Este instrumento no usa ninguna de
las dos. `research/time-memory-tradeoff.md` acota recomputación en otro juego y
`research/chia-parcelas-comprimidas.md` advierte que plot-ID grinding de Chia no se transfiere sin
más a Autonomys; tampoco se convierten en constantes.

## Lo que este instrumento NO resuelve

No mide el plotter parcial, no fija el rango de solución pendiente del DAG, no convierte bytes a
`N_h`, no estima `pi_pago`, no rehace el *lookahead* para `pot_output(slot+D)`, no valora energía o
hardware y no demuestra una mitigación. Entrega la frontera reproducible que esas mediciones deben
alimentar y evita que una cifra histórica de sector completo o un precio supuesto cierre la
decisión.
