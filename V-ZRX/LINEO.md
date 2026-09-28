# Veritas: cálculo rápido y verificable — Julia (CPU) y C++/CUDA (GPU)

> **LECTURA OBLIGATORIA.** Todo agente o persona que cree, porte o modifique una auditoría,
> simulación, búsqueda exhaustiva, benchmark matemático o test de cálculo bajo `research/` o
> `veritas/` **MUST** leer este documento antes de escribir código. Su objetivo dual es:
>
> 1. obtener el máximo rendimiento medible que sea compatible con el problema, y
> 2. preservar la veracidad, reproducibilidad y auditabilidad del resultado.
>
> **Reparto de lenguajes:** Julia se usa **solo en CPU**. Todo cálculo de GPU se escribe en
> **C++/CUDA** (§5.7), con las mismas reglas de rendimiento y veracidad de este documento. No se
> usa Julia para GPU.
>
> Julia es el lenguaje principal de cálculo de Veritas en CPU. Por instrucción del usuario,
> **no se crean ni ejecutan auditorías Python**. Los instrumentos Python históricos conservados
> sólo se inspeccionan como evidencia y para portar los modelos pertinentes a Julia o C++/CUDA.

## Regla de decisión

**No se acepta un cálculo lento por costumbre, ni una optimización por intuición.** Antes de
declarar un resultado, toda auditoría debe poder responder estas preguntas:

1. ¿Cuál es la complejidad temporal y espacial del algoritmo? ¿Qué parámetro domina el coste?
2. ¿Cuál es el perfil de CPU, memoria y asignaciones después de compilar el código?
3. ¿Cuál es el oráculo pequeño/lento contra el que se comprobó el kernel optimizado?
4. ¿Qué tipos numéricos y qué error de redondeo admite el resultado?
5. ¿Qué semilla, versión de Julia, `Manifest.toml`, hardware y número de hilos reprodujeron la
   cifra publicada?

Si una respuesta es «no se midió», el trabajo está **incompleto**, aunque entregue un número.

---

## 1. Política de proyecto, entorno y ejecución

Cada auditoría Julia vive en un proyecto aislado y reproducible:

```text
veritas/<categoria>/<nombre-auditoria>/
├── Project.toml          # dependencias declaradas
├── Manifest.toml         # árbol exacto resuelto; se versiona
├── src/
│   ├── modelo.jl         # tipos, transición y kernel puro
│   ├── referencia.jl     # oráculo simple/exacto para casos pequeños
│   ├── rapido.jl         # implementación optimizada
│   └── validacion.jl     # equivalencia, invariantes y bordes
├── test/runtests.jl
├── bench/benchmarks.jl
├── run.jl                # CLI reproducible, no notebook implícito
├── resultados/           # artefactos generados; no fuente de verdad
└── INFORME.md
```

La plantilla compartida vive en `veritas/plantilla/` con el catálogo aprobado y su `Manifest.toml`.
Crear una auditoría nueva: `veritas/nueva-auditoria.sh <categoria> <nombre>` (copia la plantilla y
ejecuta `Pkg.instantiate()`). **La categoría la determina el agente** según el tema dominante de la
auditoría —`seguridad`, `rendimiento`, `consenso`, `economía`, `criptografía`, `red`,
`almacenamiento`, `finalidad`, u otras muchas que puede crear: la lista **no es cerrada**— y se
declara, con su motivo, en el `INFORME.md`. El objetivo es que cada asunto tenga su directorio y no
se mezcle todo: una auditoría que toque varios temas se coloca por el dominante y cita los
secundarios. Cada auditoría es independiente: no comparte entorno con las demás.

- **`LD_LIBRARY_PATH` puede matar a Julia.** En la máquina de referencia hay bibliotecas de AOCC en
  el entorno y `julia` sufre *segfault* al cargar el registro. Ejecutar siempre con
  `env -u LD_LIBRARY_PATH` o, mejor, con el envoltorio `veritas/julia.sh`, que además fija el PATH
  de juliaup.

- Pinear la versión de Julia en `julia-version.toml` o documentarla de forma explícita; usar
  versiones estables soportadas, nunca una nightly para un resultado de consenso.
- Ejecutar siempre con `julia --project=.`. `Manifest.toml` es obligatorio: impide que la misma
  auditoría cambie por actualizar un paquete.
- Preferir `Pkg.add(name; preserve=Pkg.PRESERVE_ALL)` al actualizar una dependencia y registrar el
  motivo en el informe. No usar el entorno global.
- La línea de ejecución publicada debe incluir, al menos (perfil de la máquina de referencia, §7):

  ```bash
  # Perfil máximo; el escalado puede ganar con menos hilos.
  JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 \
    julia --project=. --threads=24,0 run.jl --seed 0x5a5a --replicas 64
  ```

  El presupuesto de la máquina de referencia es un **límite máximo, no un objetivo**: **24 hilos de
  cómputo de los 32 lógicos** (8 quedan para el sistema) y **64 GiB de RAM de los 123 GiB visibles**.
  Ninguna corrida **MUST** superar esos topes. La línea de arriba es el perfil máximo; el número real
  de hilos lo decide el escalado (`1, 2, 4, 8, 16, 24`, §7) y puede ser menor. Usar
  `--threads=auto` o `JULIA_NUM_THREADS=auto` **MUST NOT** publicarse como línea de ejecución en esta
  máquina: tomaría los 32 hilos y rompería el tope. El informe registra
  `Threads.nthreads(:default)` y `Threads.nthreads(:interactive)`.

  Si el kernel depende de BLAS multihilo, medir también una configuración con `OPENBLAS_NUM_THREADS`
  controlado. No combinar ciegamente hilos Julia y BLAS: se puede sobresaturar la CPU y empeorar.
  Para un bucle Julia paralelizado manualmente, la línea base es `OPENBLAS_NUM_THREADS=1`; para una
  única operación densa BLAS dominante, comparar contra Julia con un hilo y BLAS usando hasta 24
  hilos (`OPENBLAS_NUM_THREADS=24` como tope). Conserva la configuración que gane en el benchmark
  extremo a extremo.

- Capturar en cada resultado: hash Git, `VERSION`, `Pkg.status()`, `Sys.CPU_NAME`, núcleos/hilos,
  RAM, backend BLAS, GPU/controlador si aplica, argumentos, semilla y tiempo de pared/CPU.
- Un notebook Pluto/Jupyter es útil para explorar; la cifra publicada debe salir de `run.jl`, con
  argumentos y entorno fijados.

---

## 2. Jerarquía de optimización obligatoria

Aplicar esta secuencia. No saltar a GPU, `@simd` o un paquete exótico antes de pasar los pasos
anteriores.

| Orden | Pregunta | Acción correcta |
|---:|---|---|
| 0 | ¿La complejidad es innecesaria? | Eliminar enumeración por simetría, poda, DP, memoización, fórmula cerrada, convolución o muestreo con intervalo de confianza. |
| 1 | ¿El resultado es correcto? | Escribir primero el oráculo claro; probar bordes, contraejemplos y propiedades. |
| 2 | ¿El compilador especializa? | Mover el trabajo a funciones, usar tipos concretos y `@code_warntype`; eliminar globals y `Any`. |
| 3 | ¿Se asigna memoria en el bucle? | Preasignar, mutar con `!`, usar `@views`, buffers locales y `mul!`; medir `@allocated`. |
| 4 | ¿Los datos siguen la memoria? | Elegir estructura de datos, acceso contiguo y orden de bucles conforme a columnas de Julia. |
| 5 | ¿El cuello sigue siendo CPU? | Vectorizar/broadcast fusionado o usar un bucle tipado simple; medir ambos. |
| 6 | ¿Las réplicas son independientes? | Paralelizar por semillas/chunks con reducción determinista y sin carreras. |
| 7 | ¿El kernel domina y es regular? | Considerar SIMD, `LoopVectorization` o MPI; para GPU, escribir **C++/CUDA** (§5.7); validar bit a bit/exactamente contra CPU. |

Una aceleración solo se conserva si el benchmark de extremo a extremo y la validación la justifican.

---

## 3. Fundamentos Julia que son obligatorios

### 3.1 Funciones, tipos y especialización

El camino caliente debe vivir en una función pequeña, con argumentos y tipos estables. Nunca hacer
un cálculo pesado en global ni depender de una variable global mutable.

```julia
# MAL: `estado` global y tipo potencialmente cambiante.
estado = []
for x in datos
    push!(estado, f(x))
end

# BIEN: el compilador conoce los tipos y el destino está preasignado.
function transformar!(dest::Vector{Float64}, datos::Vector{Float64})
    @inbounds for i in eachindex(datos, dest)
        dest[i] = f(datos[i])
    end
    return dest
end
```

Reglas:

- Definir `struct` inmutables con campos concretos para estado estable. Usar `mutable struct` solo
  si hay una mutación real y medida.
- Nunca `Vector{Any}`, `Dict{Any,Any}`, campos `::AbstractVector`/`::Function` en un objeto caliente,
  ni un `Union` grande. Parametrizar: `struct Modelo{T<:Real} ... end`.
- Usar una *function barrier*: parsing, CLI e I/O pueden ser dinámicos; convertirlos una vez a tipos
  concretos y llamar al kernel tipado.
- Inspeccionar el kernel con `@code_warntype`, no con una función de preparación. El rojo o
  `Any` en el bucle es un defecto que se debe explicar o arreglar.
- Preferir `const` para tablas y parámetros globales inmutables. No usar `const` para esconder
  estado mutable compartido entre réplicas.

### 3.2 Memoria, arrays y orden de acceso

Julia almacena arreglos en **orden de columnas**. En una matriz `A`, el índice izquierdo debe variar
en el bucle interno para recorrer memoria contigua:

```julia
@inbounds for j in axes(A, 2), i in axes(A, 1)
    A[i, j] = g(i, j)
end
```

- Preasignar salidas y usar convenciones mutantes (`simular!`, `actualizar!`, `mul!`, `map!`).
- Usar `@views` o `view` para cortes en un camino caliente; `A[:, j]` puede copiar.
- Usar broadcast punteado (`@.` o `a .= b .+ c .* d`) para fusionar expresiones y evitar temporales.
  Confirmar con `@allocated`; no asumir.
- Para álgebra lineal densa, usar `LinearAlgebra` y sus formas mutantes (`mul!`, `ldiv!`,
  `factorize`, factorizaciones reutilizadas) antes de escribir triples bucles.
- No crear `Dict`, `Set`, tuplas grandes, closures, strings, logs o excepciones dentro de millones
  de iteraciones. Registrar contadores numéricos y convertir a texto al final.
- No llamar `gc()` por reflejo. Primero eliminar asignaciones; configurar memoria/GC solo tras
  medir un cuello real.

### 3.3 Anotaciones que pueden cambiar la semántica

| Herramienta | Política Veritas |
|---|---|
| `@inbounds` | Permitida solo después de un test que cubra dimensiones/índices. Añadir comentario que pruebe por qué el índice está en rango. Correr también CI con comprobación de límites. |
| `@simd` | Solo para iteraciones independientes y sin reducción de coma flotante no controlada. Medir; no prometer determinismo de bits. |
| `@fastmath` | **Prohibida por defecto** en auditorías, pruebas o umbrales. Puede romper NaN, infinitos, asociatividad y redondeo. Solo con autorización explícita, análisis de error y equivalencia contra un modo estricto. |
| `@turbo` / vectorización agresiva | Opcional y posterior a la referencia. Requiere prueba contra el kernel base, benchmark y explicación de supuestos. |
| `@threads` | Solo si cada iteración escribe una región disjunta o la reducción usa estado local por tarea. Nunca actualizar un `Dict`, `Set`, contador normal o RNG compartido desde varios hilos. |

---

## 4. Elegir datos antes de elegir librería

La estructura de datos es parte del algoritmo. Elegirla según la operación dominante, no por
comodidad sintáctica.

| Situación dominante | Elección inicial | Evitar / advertencia |
|---|---|---|
| Vector o matriz numérica densa, tamaño grande | `Vector{T}`, `Matrix{T}`, `LinearAlgebra` | `Vector{Vector{T}}` si el cálculo es rectangular; objetos por celda. |
| Vector/matriz muy pequeña de tamaño conocido en compilación (2–16, a veces hasta ~100 elementos) | `StaticArrays.jl`: `SVector`, `SMatrix`, `MVector` | `StaticArrays` grandes: aumenta compilación y puede ser más lento. |
| Millones de nodos/eventos; se procesa un campo cada vez | **SoA**: vectores paralelos o `StructArrays.jl` | Array de `mutable struct` heterogéneos: pobre localidad y GC. |
| Estado booleano denso | `BitVector` / `BitMatrix`; `Vector{Bool}` si se necesita acceso simple medido | `Set{Int}` para universo fijo y denso. |
| Conjunto de enteros disperso | `BitSet` si el universo entero es razonable; `Set{Int}` si es realmente disperso | Construir/unionar Sets en el núcleo sin medir. |
| Grafo estático y recorrido repetido | CSR/CSC como offsets + vecinos contiguos; `SparseArrays` para álgebra dispersa | `Graphs.jl` como kernel crítico sin perfil: es excelente para prototipar, no una garantía de máximo rendimiento. |
| DAG pequeño para el oráculo | `Graphs.jl` y tipos claros | Reusar su representación general en el motor de millones de casos si el perfil muestra overhead. |
| Cola/prioridades | `DataStructures.jl` para corrección inicial; heap/arrays especializados si perf lo exige | Reordenar todo con `sort!` en cada paso. |
| Tabla con claves simples fijas | arrays indexados, `NTuple`, `SVector` o codificación entera de clave | `Dict` cuando hay dominio pequeño o índices naturales. |
| Mapa realmente disperso/dinámico | `Dict{K,V}` con `K` y `V` concretos e `isbits` si es posible | claves String/tuplas asignadas repetidamente; `Dict{Any,...}`. |
| Histograma o conteo | `Vector{Int64}`/`UInt64` preasignado y reducción local | contador atómico por evento salvo que el perfil justifique su coste. |
| Estado de tamaño fijo por simulación | `struct` isbits, `NTuple` o `StaticArrays` pequeños | diccionarios/objetos por réplica. |

**Regla SoA:** si el algoritmo examina `slot`, `peso` y `padres` de un millón de bloques por
separado, usar `slots::Vector{UInt64}`, `pesos::Vector{UInt128}`, `offsets::Vector{Int32}` y
`padres::Vector{Int32}`. No `Vector{Bloque}` salvo que el perfil pruebe que el acceso conjunto es
mejor.

---

## 5. Conjunto de herramientas aprobado (Julia en CPU; C++/CUDA en GPU)

No instalar todas las bibliotecas en todos los proyectos. Cada dependencia añade superficie,
compilación y riesgo de versiones. Usar la mínima que cubra una necesidad medible.

### 5.1 Base obligatoria: rendimiento, pruebas y reproducibilidad

| Herramienta | Uso en Veritas | Regla |
|---|---|---|
| `Test` (stdlib) | pruebas unitarias, propiedades y regresión | Obligatoria para referencia, bordes y contraejemplos. |
| `Random` (stdlib) | RNG base | Semillas explícitas, nunca `default_rng()` implícito en resultados. |
| `StableRNGs.jl` | secuencias reproducibles entre versiones para fixtures | Usar para fixtures y regresión; no asumir que es el RNG más rápido. |
| `Random123.jl` | RNG contracontador/Philox para réplicas paralelas reproducibles | Preferido si cada réplica necesita flujo independiente reproducible sin estado compartido. |
| `BenchmarkTools.jl` | microbenchmarks robustos con `@btime`, `@benchmark` | Obligatorio antes/después de optimizar; interpolar variables con `$`. No usar `@time` como único benchmark. |
| `Profile` (stdlib) | perfil estadístico de CPU y tareas | Primer perfilador para un job que tarda más de segundos; calentar JIT antes. |
| `JET.jl` | análisis estático de errores de compilación/tipos | Ejecutar sobre kernels y usar sus diagnósticos para investigar, no como sustituto de tests. |
| `Cthulhu.jl` | inspección interactiva de inferencia y llamadas | Usar solo cuando `@code_warntype`/JET indiquen inestabilidad difícil. |
| `TimerOutputs.jl` | instrumentación jerárquica de fases | Útil para informe de coste por fase; desactivar o minimizar en el bucle más caliente. |
| `Aqua.jl` | higiene de paquetes locales Julia | Recomendado si la auditoría se convierte en paquete reutilizable. |

Plantilla mínima de benchmark:

```julia
using BenchmarkTools

# Primero compila y valida; después mide el kernel aislado.
resultado = kernel!(salida, entrada, parametros)
@assert resultado == esperado

trial = @benchmark kernel!($salida, $entrada, $parametros)
display(trial)
@show minimum(trial).time minimum(trial).memory minimum(trial).allocs
```

### 5.2 Matemática numérica y álgebra lineal

| Herramienta | Cuándo usarla | Precaución de veracidad |
|---|---|---|
| `LinearAlgebra` (stdlib) | matrices densas, factorizaciones, BLAS/LAPACK | Usar `mul!` y factorizaciones reutilizadas. Controlar hilos BLAS. |
| `SparseArrays` (stdlib) | matrices dispersas y operaciones lineales dispersas | Es CSC; diseñar el acceso alrededor de columnas o usar CSR explícito si el recorrido manda. |
| `SpecialFunctions.jl` | funciones especiales maduras | Comparar umbrales sensibles con precisión/intervalos, no asumir redondeo idéntico en plataformas. |
| `StatsBase.jl` | histogramas, conteos, muestreo y estadística elemental | Para el núcleo, comparar con arrays manuales si la sobrecarga domina. |
| `Distributions.jl` | distribuciones y muestreo de referencia | Bien para modelo claro; un muestreador especializado puede ser necesario en cientos de millones de draws. |
| `StaticArrays.jl` | álgebra y estados pequeños de dimensión fija | Muy rápida en tamaños pequeños; no usarla por defecto en matrices grandes. |
| `LoopVectorization.jl` | kernel numérico regular cuya referencia ya pasa y el perfil domina | Usar `@turbo` solo tras benchmark y equivalencia; no con aliasing, efectos, ramas complejas o aritmética de prueba sin analizar. |
| `Tullio.jl` | contracciones/reducciones tensoriales claras que puedan fusionarse/paralelizarse | Validar orden de reducción y memoria; no es licencia para ignorar complejidad. |

### 5.3 Aritmética exacta y numérica validada

La vía rápida no puede falsificar una conclusión matemática. Elegir el régimen de números antes de
programar:

| Necesidad | Elección | Patrón correcto |
|---|---|---|
| Contadores, índices, codificación y reglas de consenso | `UInt*`/`Int*` con `checked_*`, `BigInt` solo si el rango lo exige | Probar desbordamientos en bordes; no usar `Float64` para decidir una regla discreta. |
| Fracciones exactas pequeñas | `Rational{BigInt}` o enteros escalados | Vigilar crecimiento de numerador/denominador; no meterlo en Monte Carlo masivo. |
| Cálculo rápido aproximado | `Float64` por defecto | Estimar estabilidad y comparar puntos de frontera con modo riguroso. |
| Precisión arbitraria no rigurosa | `BigFloat` | Establecer `setprecision` localmente; documentar bits, redondeo y coste. |
| Cota rigurosa de un resultado real/complejo | `Arblib.jl` (`Arb`/`Acb`, aritmética de bolas) | Preferido para certificar una desigualdad numérica tras encontrar el caso con `Float64`. |
| Inclusión rigurosa, restricciones e intervalos | `IntervalArithmetic.jl` | Usar intervalos para demostrar signo/rango; tratar intervalos anchos como resultado inconcluso. |
| Álgebra computacional, enteros/polinomios/campos | `Nemo.jl` | Usar para el oráculo o teorema discreto, no como reemplazo automático de un kernel numérico masivo. |

Patrón Veritas de dos velocidades:

1. Explorar con `Float64`/enteros nativos y el kernel rápido.
2. Repetir todos los casos que cambian el veredicto, y una muestra adversarial, con `Arblib`,
   `IntervalArithmetic`, `BigFloat` o aritmética exacta según corresponda.
3. Si el intervalo contiene el umbral o el resultado cambia con precisión, declarar **inconcluso**;
   no redondear a favor de la hipótesis.

### 5.4 Grafos, DAG y combinatoria

| Herramienta | Uso | Política |
|---|---|---|
| `Graphs.jl` | prototipo legible, generadores, algoritmos convencionales y oráculo | Punto de partida correcto; perfilar antes de usarlo en millones de DAGs. |
| `SimpleWeightedGraphs.jl` | grafos ponderados en prototipo | No usar para el núcleo si el peso/camino se recalcula masivamente sin perfil. |
| `Combinatorics.jl` | iteradores de combinaciones/permutaciones en espacios pequeños | Prohibido materializar el conjunto completo si basta iterar/podar; calcular crecimiento antes. |
| `DataStructures.jl` | colas, heaps, deques y contenedores de referencia | Adecuado para corrección; sustituir por arrays especializados solo si el perfil lo exige. |

Para un motor DAG de auditoría intensiva, la opción por defecto tras el oráculo es una
representación compacta: IDs densos `Int32/Int64`, arrays SoA, lista de padres plana con offsets,
bitsets para conjuntos pequeños/frecuentes y cachés explícitas con regla de invalidación. Mantener
la implementación `Graphs.jl` como comparación semántica en instancias pequeñas.

### 5.5 Paralelismo local, distribuido y aceleradores

| Nivel | Herramientas | Cuándo sí | Restricción Veritas |
|---|---|---|---|
| CPU simple | `Base.Threads`, `Threads.@threads`, `Threads.@spawn` | réplicas, chunks o escritura disjunta | Reducciones con orden fijo; no buffers indexados por `threadid()` si una tarea puede migrar. |
| Bucles/reducciones altos | `FLoops.jl` / `Folds.jl` | patrones map/reduce que deban expresar reducción segura | Fijar scheduler/chunks y comprobar reproducibilidad; comparar con serial. |
| Procesos locales | `Distributed` (stdlib) | memoria aislada o tareas pesadas independientes | Enviar parámetros compactos, no clonar grafos gigantes por mensaje. |
| Varios nodos | `MPI.jl` | barridos enormes que justifican clúster | Semillas/chunks deterministas; reducción explícita y tolerancia a fallo documentada. |
| GPU NVIDIA (GTX 1070, Pascal/CC 6.1) | **C++/CUDA** — Julia **no** se usa en GPU | kernel regular, aritmética intensa, gran paralelismo | Ver §5.7: oráculo CPU estricto, transferencias medidas, `compute-sanitizer` y comparación de resultados. |

**GPU no es automática.** Es favorable para Monte Carlo masivo, kernels regulares, arrays grandes y
pocas transferencias. Suele ser mala para búsquedas ramificadas, `Dict`/grafos irregulares, precisión
arbitraria, estructuras dinámicas, un problema pequeño o datos que van y vuelven al host. Cuando se
justifique, el kernel se escribe en **C++/CUDA** (§5.7), nunca en Julia: el perfilador es `ncu`/`nsys`,
no una estimación visual. La política es CPU/referencia estricta → kernel GPU → comparación de
distribuciones, invariantes y casos de borde.

### 5.6 Latencia de arranque y artefactos

| Herramienta | Uso |
|---|---|
| `PrecompileTools.jl` | precompilar rutas representativas de un paquete de auditoría. |
| `PackageCompiler.jl` | imagen de sistema si muchas ejecuciones cortas pagan compilación repetida. |
| `Serialization` (stdlib), `JLD2.jl` | checkpoints locales tipados; validar formato/versión. |
| `Arrow.jl` | resultados tabulares columnarios interoperables y rápidos. |

No confundir **tiempo a primera ejecución** con tiempo de cómputo. Publicar ambos por separado y
calentar la función antes de `@benchmark` o `@profile`.

### 5.7 GPU: C++/CUDA (Julia no se usa en GPU)

**Regla.** Julia es **CPU-only** en Veritas. Todo cálculo que se lleve a GPU se escribe en
**C++/CUDA**, con el mismo contrato que la vía Julia: oráculo CPU estricto → kernel GPU →
comparación. No se publica un número de GPU sin referencia CPU, benchmark extremo a extremo y
medición de transferencias.

**Cuándo GPU.** Igual que en §5.5: kernel regular, aritmética intensa, gran paralelismo y pocas
transferencias. Mala idea para búsquedas ramificadas, grafos irregulares, precisión arbitraria,
estructuras dinámicas o problemas pequeños.

**Toolchain (máxima compatibilidad).**
- `nvcc` de un toolkit que soporte la GPU objetivo. Para Pascal (GTX 1070, CC 6.1) usar **CUDA 12.x**
  (CUDA 13 retiró Pascal); compilar con `-arch=sm_61` y verificar `nvcc --version`.
  **Verificado en la máquina de referencia:** el CUDA 13.1 instalado en `/usr/local/cuda` no lista
  `sm_61`; instalar 12.x en paralelo y usar `/usr/local/cuda-12.x/bin/nvcc` explícitamente.
- `g++`/`clang++`, `cmake`, `ninja`; `compute-sanitizer`; `nsight-compute`/`nsight-systems` para perfil.
- Flags: `-O3 -DNDEBUG -arch=sm_61 --ptxas-options=-v`; `-march=native` solo en la parte CPU.
- Registrar y fijar: versión de nvcc, driver, modelo y CC de la GPU, flags, semilla y hash Git.

**Estructuras de datos en C++ (elegirlas antes de escribir el kernel).**
- Contiguo primero: `std::vector<T>` con `reserve`, `std::span` para vistas y `std::array` para
  tamaño fijo. Evitar `std::list`, `std::map` y punteros por nodo en el camino caliente.
- SoA frente a AoS: si el algoritmo examina un campo por vez sobre millones de elementos, separar
  vectores paralelos; AoS solo si el perfil demuestra que el acceso conjunto gana.
- Grafos/DAG: CSR (offsets + destinos contiguos) o CSC según el recorrido; IDs densos de 32 bits si
  el universo lo permite.
- Estados booleanos densos: bitsets (`std::vector<uint64_t>`); colas/heaps en arrays si el perfil lo
  pide; arena o `std::pmr` para reducir asignaciones cuando se mida la ganancia.
- Rendimiento: sin `virtual` ni `std::function`/`std::shared_ptr` en el bucle, sin `new/delete` por
  iteración, `std::move` para evitar copias, `constexpr` para tablas, `__restrict__` y alineación
  para vectorizar. Medir con `perf`, `-ftime-report` y `nm`/`size` antes de suponer.
- Equivalente a la prohibición de `@fastmath`: `-ffast-math` y `-Ofast` están **prohibidos por
  defecto**, igual que `Float32` como única fuente de un veredicto. Solo con autorización explícita,
  análisis de error y equivalencia contra el modo estricto.

**Reglas CUDA.**
- Transferencias: medirlas y minimizarlas; kernels grandes en lote, memoria fijada
  (`cudaMallocHost`) y streams cuando haya solape. Nunca `cudaMemcpy` por elemento.
- Accesos coalescidos, `__shared__` para reutilización, evitar divergencia de warp, medir ocupación
  (no suponerla) y colocar `__syncthreads` correctamente.
- Reducciones deterministas y de orden fijo; si se usan atómicos, fijar el orden o declarar la no
  reproducibilidad en el informe.
- Comprobar siempre el retorno de las llamadas CUDA y pasar `compute-sanitizer` antes de publicar.
- Perfil con `ncu`/`nsys`; publicar tiempos de kernel y de transferencia por separado.

**Presupuesto y fallos.** Mismo contrato: presupuesto de RAM host, memoria de GPU, tiempo y disco;
al agotarse, checkpoint y **inconcluso**; cada fallo guarda semilla, parámetros, versión de nvcc,
driver, configuración de bloques/hilos y una entrada mínima que lo reproduce. Para varios nodos con
GPU, MPI *CUDA-aware* en C++ y reducción explícita.

---

## 6. Protocolo de perfilado y optimización

### Antes de modificar rendimiento

1. Escribir el modelo de coste: por ejemplo, `O(replicas × pasos × padres)` y el tamaño esperado.
2. Ejecutar la referencia sobre tamaño pequeño y registrar salida/propiedades.
3. Ejecutar el caso real una vez con `@time` para separar compilación, tiempo, asignaciones y GC.
4. Calentar el kernel y medirlo con `BenchmarkTools`.
5. Perfilar con `Profile.@profile`; para un proceso externo largo en Linux, usar también `perf`
   con JIT profiling si hace falta atribuir tiempo en LLVM/BLAS/C.
6. Medir asignaciones con `@allocated` y revisar `@code_warntype`/JET.

### Durante la optimización

- Cambiar **una** hipótesis por vez y guardar benchmark antes/después sobre la misma entrada.
- Optimizar la región que acumula más tiempo, no una función llamativa que representa < 1 %.
- Si hay mucha memoria asignada, arreglar tipos, temporales y buffers antes de probar más hilos.
- Si el cuello es combinatorio, reducir el espacio de estados antes de reescribir el mismo algoritmo
  en GPU o Rust.
- Medir escalado serial, 2, 4, 8… hilos. Si escala mal, investigar contención, falso compartido,
  ancho de banda, BLAS anidado o imbalance; no aumentar ciegamente hilos.

### Al publicar

El informe incluye una tabla así:

| Variante | Tiempo mediano | Asignaciones | Hilos/backend | Resultado frente a referencia |
|---|---:|---:|---|---|
| Oráculo | … | … | 1 CPU | fuente de verdad en `n ≤ …` |
| Base tipada | … | … | 1 CPU | igual |
| Optimizada | … | … | … | igual en todos los vectores |
| Acelerada | … | … | GPU/MPI | igual/incluida dentro de tolerancia certificada |

No publicar solo «X veces más rápido». Publicar tamaño, trabajo total, semilla, métrica y el
resultado comprobado.

---

## 7. Reproducibilidad, aleatoriedad y paralelismo correcto

### Política de hilos: tope, no objetivo

Paralelizar es la política por defecto de los cálculos largos, con **24 hilos como tope, no como
objetivo**, pero no basta con arrancar Julia con más hilos: un algoritmo secuencial seguirá usando
uno. El agente debe partir el trabajo por su eje naturalmente independiente:

- semillas/réplicas Monte Carlo;
- puntos de una rejilla de parámetros;
- bloques disjuntos de un espacio de búsqueda;
- subárboles independientes tras una frontera ya validada;
- lotes de datos con escritura en rangos de salida disjuntos.

La primera implementación paralela debe comparar `1, 2, 4, 8, 16, 24` hilos, donde `24` es el
**tope** de cómputo de la máquina de referencia (de 32 hilos lógicos), e informar *speedup* y
eficiencia. Se conserva la configuración que gane, **aunque use menos de 24**. El objetivo no es
afirmar que se usan todos los núcleos: es que el caso real termine antes. Hyperthreading, ancho de
banda de memoria, caché, contención o BLAS anidado pueden hacer que `N/2` gane a `N`.

Plantilla segura para una barrida independiente:

```julia
using Base.Threads
using StableRNGs

function ejecutar_replicas(semilla_maestra::UInt64, n::Int, parametros)
    resultados = Vector{Resultado}(undef, n)  # una posición exclusiva por réplica

    @threads for replica in 1:n
        rng = StableRNG(semilla_maestra + UInt64(replica))
        resultados[replica] = simular_una!(rng, parametros)
    end

    # Reducción determinista, posterior y en orden de ID.
    return reducir_resultados(resultados)
end
```

La API exacta del RNG puede variar según su paquete/versiones fijadas; el principio no: un flujo
derivado por ID de réplica, ninguna mutación compartida y una reducción final ordenada. No usar
`threadid()` para repartir buffers o semillas: una tarea puede migrar entre hilos.

### RNG

- La semilla es un argumento obligatorio de CLI y aparece en el informe.
- Derivar un RNG independiente por `(semilla_maestra, id_de_replica)`; no compartir un RNG mutable
  entre tareas. `Random123.jl` es una buena elección contracontador para esto.
- Guardar los casos adversariales, no solo el promedio. Una semilla que rompe una hipótesis es un
  vector de regresión permanente.
- Si el modelo requiere aleatoriedad criptográfica, `Random` de simulación no es evidencia
  criptográfica. Definir la fuente y el juego de seguridad aparte.

### Reducciones

El orden de suma `Float64` cambia bajo hilos/GPU. Para un veredicto sensible:

- preferir contadores enteros y sumar al final;
- usar chunks fijos, resultados por chunk y reducción final en orden de ID;
- si corresponde, usar compensación (Kahan/Neumaier) y medir su coste;
- corroborar el signo/umbral con intervalos o bolas cuando el margen sea pequeño.

### Recursos, afinidad y fallos reproducibles

**Perfil de la máquina de referencia (verificado 2026-09-10).**

| Recurso | Valor |
|---|---|
| CPU | AMD Ryzen 9 9950X3D, 16 núcleos físicos / 32 hilos lógicos, 1 nodo NUMA |
| RAM | 123 GiB visibles (128 GB instalados), swap 0 |
| Presupuesto de auditoría (tope) | **máximo 64 GiB de RAM y 24 hilos de cómputo** (8 lógicos quedan para el sistema) |

Declaración mínima al abrir una auditoría: «Esta auditoría puede usar como máximo 64 GiB de RAM,
24 hilos y N GiB de disco temporal; si se agota, checkpoint y estado **inconcluso**.» El presupuesto
es un **techo**: usar menos hilos o menos memoria es correcto si el benchmark lo justifica. Al ser un
único nodo NUMA, `numactl` no aplica en esta máquina; la regla se conserva para máquinas
multi-socket.

- Declarar un presupuesto de tiempo, memoria y almacenamiento para cada auditoría. Si se agota,
  terminar con estado **inconcluso** y conservar el último checkpoint; nunca convertir un timeout
  en un resultado negativo.
- No anidar paralelismo sin medirlo: elegir una sola capa dueña de los núcleos (Threads, BLAS,
  `Distributed`, MPI o GPU). Para trabajos CPU fijar `OPENBLAS_NUM_THREADS=1` cuando los hilos
  Julia son la capa externa.
- En máquinas NUMA o con varios sockets, medir afinidad y primera colocación de memoria (`numactl`,
  afinidad del scheduler o equivalente). Registrar CPU lógica, socket/NUMA y frecuencia; una prueba
  que migra entre sockets no es comparable con otra fijada.
- Separar siempre el tiempo de compilación/JIT, el calentamiento y el tiempo estable. Para muchas
  réplicas, amortizar JIT en un proceso persistente o generar un sysimage solo después de validar.
- Cada fallo debe guardar semilla, parámetros, versión, hash Git, configuración de hilos, entrada
  mínima que reproduce el error y un checksum de los artefactos. El caso reducido pasa a regresión.
- Ejecutar dos perfiles en CI: referencia (un hilo, comprobaciones activas, límites activados) y
  rendimiento (hasta los 24 hilos permitidos, datos representativos). La optimización no puede sustituir al
  perfil de referencia.

Nunca usar una carrera de datos como «optimización». Julia advierte que las colecciones Base
requieren sincronización si una tarea modifica una colección compartida, y las tareas pueden migrar
entre hilos.[^threads]

---

## 8. Prompt obligatorio para agentes Veritas

Copiar este bloque al encargo de cualquier agente que escriba cálculo Julia (CPU) o C++/CUDA (GPU):

> Eres especialista senior en Julia para cómputo científico reproducible, teoría de protocolos y
> optimización de alto rendimiento. Antes de escribir o modificar código, lee por completo
> `veritas/LINEO.md` y cumple todas sus reglas.
>
> Tu prioridad conjunta es: **(1) resultado matemáticamente verdadero y reproducible; (2) el máximo
> rendimiento medido compatible con esa verdad.** No aceptes un programa lento sin un perfil, ni una
> aceleración sin una prueba contra un oráculo independiente.
>
> Procedimiento obligatorio:
>
> 1. Formula el modelo matemático, la complejidad temporal/espacial y el adversario/caso de borde
>    relevante antes de elegir la estructura de datos.
> 2. Diseña la representación para la operación dominante: tipos concretos, arrays contiguos,
>    SoA frente a AoS, IDs densos, `BitVector`/CSR/`StaticArrays`/`Dict` solo cuando el caso lo
>    justifique. Explica brevemente la elección.
> 3. Escribe primero una referencia pequeña, transparente y preferiblemente exacta; crea tests de
>    bordes, invariantes, contraejemplos previos y semillas fijas.
> 4. Implementa el kernel rápido dentro de funciones tipoestables, sin globals dinámicos ni `Any`.
>    Preasigna memoria, usa versiones mutantes (`!`), evita asignaciones y respeta el orden de
>    columnas. No materialices combinaciones, grafos o temporales innecesarios.
> 5. Valida el kernel rápido contra la referencia en instancias pequeñas, propiedades aleatorias y
>    todos los vectores de regresión. Para umbrales numéricos, certifica con exactitud, intervalos o
>    aritmética de bolas; si el margen no se puede certificar, declara el resultado inconcluso.
> 6. Mide el caso representativo tras calentar JIT con `BenchmarkTools`; perfila CPU/memoria con
>    `Profile`, `@allocated`, `@code_warntype` y JET. Optimiza el cuello real, no el supuesto.
> 7. Paraleliza solo trabajo independiente y usa RNG por réplica/chunk, reducción determinista y
>    ausencia demostrada de carreras. Arranca batch CPU-bound dentro del tope de 24 hilos (8 lógicos
>    quedan para el sistema), mide el escalado `1…24` y conserva la configuración que gane
>    realmente, aunque use menos hilos; evita BLAS anidado.
> 8. Considera `LoopVectorization` o MPI únicamente si el perfil demuestra un kernel regular
>    dominante y el coste no lo anula. Para GPU **no uses Julia**: escribe el kernel en C++/CUDA
>    (§5.7), con oráculo CPU estricto, transferencias medidas y `compute-sanitizer`. Compara siempre
>    con CPU estricta.
> 9. No uses `@fastmath`. `@inbounds`, `@simd`, `@turbo` o precisión `Float32` requieren prueba de
>    equivalencia, comentario de supuestos y benchmark. Nunca dejes que una optimización cambie un
>    veredicto sin declararlo.
> 10. Entrega `Project.toml`, `Manifest.toml`, comando exacto, semilla, versión/hardware, tabla de
>     rendimiento, número de asignaciones y resultado de la validación. Distingue con claridad lo
>     demostrado, medido, estimado y no demostrado.
>
> 11. Declara antes de ejecutar el presupuesto de tiempo, memoria y disco (en la máquina de
>     referencia: máximo 64 GiB de RAM y 24 hilos). Si se agota, conserva el checkpoint y reporta
>     **inconcluso**; guarda semilla, parámetros, configuración y una entrada mínima reproducible
>     para cada fallo. No confundas timeout con evidencia de falsedad.
>
> Si una corrida supera el presupuesto declarado, detente antes de ampliar la exploración y produce
> un perfil más una hipótesis de cuello de botella. Propón la mejora algorítmica o de datos de mayor
> impacto y verifica que conserva resultados antes de lanzar otra corrida larga.

---

## 9. Antipatrones que bloquean una auditoría

- Portar Python línea por línea con `Vector{Any}`, diccionarios anidados y bucles globales.
- Confundir la compilación inicial de Julia con la velocidad del kernel.
- Lanzar 64 hilos sobre una operación BLAS que ya usa todos los núcleos.
- Repetir Monte Carlo sin guardar semillas, intervalos de confianza ni casos extremos.
- Usar `Float64` para igualdades, dinero, altura, conteo o decisión discreta de consenso.
- Usar `@fastmath` para «arreglar» un benchmark.
- Reescribir un cálculo exponencial en GPU sin haber buscado poda, simetría, DP o una cota.
- Medir una microfunción y concluir que el programa completo es rápido.
- Declarar una cifra a partir de una sola réplica, media o semilla favorable.
- Sustituir un oráculo claro por un kernel opaco antes de tener pruebas de equivalencia.

---

## 10. Criterio de terminación

Una auditoría está lista para informar cuando:

- su proyecto está congelado y se ejecuta con un comando documentado;
- la referencia y el kernel rápido coinciden en el dominio que la referencia alcanza;
- los límites/umbrales tienen el régimen numérico adecuado y una comprobación rigurosa cuando
  afecta al veredicto;
- hay perfil y benchmark del caso real, no solo de un juguete;
- no quedan asignaciones, inestabilidades o estructuras de datos inadecuadas en el cuello conocido
  sin una justificación explícita;
- la paralelización/GPU, si existe, conserva resultados y supera al modo simple extremo a extremo;
- el informe permite reproducir tanto el resultado como el coste.

La meta no es que cada script use muchas librerías. La meta es que ningún resultado importante
espere 40 minutos por un algoritmo, representación o ejecución que podía medirse y mejorarse.

---

## Fuentes de selección

[^perf]: JuliaLang, [Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/). Funciones, inferencia, asignaciones, arrays, SIMD, BLAS y latencia de compilación.
[^profile]: JuliaLang, [Profiling](https://docs.julialang.org/en/v1/manual/profile/). Perfilador estadístico integrado y perfil externo.
[^threads]: JuliaLang, [Multi-Threading](https://docs.julialang.org/en/v1/manual/multi-threading/). Hilos, migración de tareas y ausencia de carreras.
[^bench]: JuliaCI, [BenchmarkTools manual](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/). Medición robusta de rendimiento.
[^static]: JuliaArrays, [StaticArrays.jl](https://juliaarrays.github.io/StaticArrays.jl/stable/). Arrays pequeños de tamaño conocido y límites de aplicabilidad.
[^arb]: Arblib.jl, [Documentation](https://kalmarek.github.io/Arblib.jl/stable/), e [IntervalArithmetic.jl](https://juliaintervals.github.io/IntervalArithmetic.jl/stable/). Aritmética de bolas e intervalos validados.
[^gpu]: NVIDIA, [CUDA C++ Programming Guide](https://docs.nvidia.com/cuda/cuda-c-programming-guide/) y [Nsight Compute](https://docs.nvidia.com/nsight-compute/). Kernels, transferencias, ocupación, perfilado y `compute-sanitizer`.
[^mpi]: JuliaParallel, [MPI.jl usage](https://github.com/JuliaParallel/MPI.jl/blob/master/docs/src/usage.md). Ejecución distribuida y buffers GPU.

Las fuentes establecen capacidades y precauciones de las herramientas; cada auditoría debe medir
su propio hardware, datos y versión fijada antes de reclamar una aceleración.
