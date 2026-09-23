Trabajas en el repositorio ZEROX, en /home/katana/zeo/ZEROX. Lee `AGENTS.md` antes de empezar. Responde en español.

**Bloque obligatorio de `veritas/LINEO.md` §8, copiado literalmente:**

Eres especialista senior en Julia para cómputo científico reproducible, teoría de protocolos y
optimización de alto rendimiento. Antes de escribir o modificar código, lee por completo
`veritas/LINEO.md` y cumple todas sus reglas.

Tu prioridad conjunta es: **(1) resultado matemáticamente verdadero y reproducible; (2) el máximo
rendimiento medido compatible con esa verdad.** No aceptes un programa lento sin un perfil, ni una
aceleración sin una prueba contra un oráculo independiente.

Procedimiento obligatorio:

1. Formula el modelo matemático, la complejidad temporal/espacial y el adversario/caso de borde
   relevante antes de elegir la estructura de datos.
2. Diseña la representación para la operación dominante: tipos concretos, arrays contiguos,
   SoA frente a AoS, IDs densos, `BitVector`/CSR/`StaticArrays`/`Dict` solo cuando el caso lo
   justifique. Explica brevemente la elección.
3. Escribe primero una referencia pequeña, transparente y preferiblemente exacta; crea tests de
   bordes, invariantes, contraejemplos previos y semillas fijas.
4. Implementa el kernel rápido dentro de funciones tipoestables, sin globals dinámicos ni `Any`.
   Preasigna memoria, usa versiones mutantes (`!`), evita asignaciones y respeta el orden de
   columnas. No materialices combinaciones, grafos o temporales innecesarios.
5. Valida el kernel rápido contra la referencia en instancias pequeñas, propiedades aleatorias y
   todos los vectores de regresión. Para umbrales numéricos, certifica con exactitud, intervalos o
   aritmética de bolas; si el margen no se puede certificar, declara el resultado inconcluso.
6. Mide el caso representativo tras calentar JIT con `BenchmarkTools`; perfila CPU/memoria con
   `Profile`, `@allocated`, `@code_warntype` y JET. Optimiza el cuello real, no el supuesto.
7. Paraleliza solo trabajo independiente y usa RNG por réplica/chunk, reducción determinista y
   ausencia demostrada de carreras. Arranca batch CPU-bound dentro del tope de 24 hilos (8 lógicos
   quedan para el sistema), mide el escalado `1…24` y conserva la configuración que gane
   realmente, aunque use menos hilos; evita BLAS anidado.
8. Considera `LoopVectorization` o MPI únicamente si el perfil demuestra un kernel regular
   dominante y el coste no lo anula. Para GPU **no uses Julia**: escribe el kernel en C++/CUDA
   (§5.7), con oráculo CPU estricto, transferencias medidas y `compute-sanitizer`. Compara siempre
   con CPU estricta.
9. No uses `@fastmath`. `@inbounds`, `@simd`, `@turbo` o precisión `Float32` requieren prueba de
   equivalencia, comentario de supuestos y benchmark. Nunca dejes que una optimización cambie un
   veredicto sin declararlo.
10. Entrega `Project.toml`, `Manifest.toml`, comando exacto, semilla, versión/hardware, tabla de
    rendimiento, número de asignaciones y resultado de la validación. Distingue con claridad lo
    demostrado, medido, estimado y no demostrado.

11. Declara antes de ejecutar el presupuesto de tiempo, memoria y disco (en la máquina de
    referencia: máximo 64 GiB de RAM y 24 hilos). Si se agota, conserva el checkpoint y reporta
    **inconcluso**; guarda semilla, parámetros, configuración y una entrada mínima reproducible
    para cada fallo. No confundas timeout con evidencia de falsedad.

Si una corrida supera el presupuesto declarado, detente antes de ampliar la exploración y produce
un perfil más una hipótesis de cuello de botella. Propón la mejora algorítmica o de datos de mayor
impacto y verifica que conserva resultados antes de lanzar otra corrida larga.

---

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: el peso es **análisis criptográfico y lectura de
fuente**, con un **modelo pequeño** que cuantifica un presupuesto temporal. El bloque te aplica entero
para ese modelo. **Máximo 4 hilos**, corridas de minutos; declara el presupuesto antes de ejecutar.
Julia en CPU con `./veritas/julia.sh`; **nada de Python**. **No plotees ni ejecutes
`ab-proof-of-space`**: su ruta no paralela tiene un SIGSEGV reproducible y no hace falta aquí.

# ENCARGO P-SELLO — ¿Existe un sellado asimétrico: caro de crear, barato de re-ligar a una rama?

## 0 · Por qué existe este encargo

Tras cinco refutaciones —identidad por pieza, castigo por clave, maduración por registro
(**imposibilidad demostrada**), anclaje a la ancestría y tasa por identidad—, la única familia con
salida estructural es **cambiar el objeto ploteado**. `P-ZRX/P-COBERTURA/` lo dejó dicho: solo las
vías **(ii) coste secuencial no paralelizable** y **(iv) contenido no públicamente regenerable**
rompen el argumento de simulación.

Pero un sellado **estático** (estilo PoRep de Filecoin) cierra el **sembrador**, no el doble farmeo:
una parcela sellada sigue sirviendo para dos ramas, porque el sellado ata los bytes a una identidad
y a un momento, **no a una historia**.

**La propuesta que este encargo evalúa** es un sellado **dinámico ligado a la rama**: que producir
peso pleno en dos ramas exija **dos objetos almacenados distintos**, o volver a ligar uno de ellos
dentro de un plazo que el atacante no pueda aprovechar.

> ⚠️ **La tensión que hay que resolver, y es el encargo entero.** El sellado es útil **porque es
> lento** —eso es lo que impide fabricar a demanda—. Para ligar a una rama hay que sellar **después**
> de conocer la rama. Pero en un DAG a `λ ≈ 1 bloque/s` con `Δ = 0,26-0,60 s` las bifurcaciones son
> continuas: el granjero honesto tendría que re-ligar cada pocos segundos, y sellar cuesta **horas**
> por diseño. Si se sella **antes** de la bifurcación, sirve a las dos ramas.
>
> **O la construcción resuelve esa tensión, o la vía está muerta.** Las dos respuestas valen.

**Modelo de amenaza (de Katana, obligatorio):** se asume que un ente con mucha capacidad atacará.
«No compensa económicamente» **no es argumento de seguridad**. Coste **absoluto**, y separar lo
**imposible** de lo **caro**.

## 1 · Entradas congeladas: NO se re-miden ni se rehacen

| Hecho | Fuente |
|---|---|
| **Imposibilidad por simulación:** para un objeto que es función **determinista y pública** de `(clave, índice, historia)` y cuyo cómputo es **paralelizable por unidad**, ningún esquema sucinto distingue «almacenado» de «regenerado dentro del plazo». **Y el Corolario 4 es incondicional:** todo predicado sobre el **valor** del objeto es invariante en el tiempo, luego **ningún compromiso puede fechar nada** | `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §3 |
| Las únicas vías que rompen esa simulación son **(ii)** coste secuencial no paralelizable y **(iv)** contenido no públicamente regenerable. (i) latencia y (iii) materializar `N` a la vez son **desigualdades cuantitativas**, no separaciones | íd. §4 |
| `B = r·(w·τ + D_a) = 181.092` unidades por TiB: una auditoría con `k ≤ B` **no detecta nada**. **El adelanto `w` multiplica por ≈120** la capacidad del tramposo | íd. §5 |
| **`α* = (1 − β_d − 2β_x)/2`:** el espacio que **abandona** la pública baja el umbral **el doble** que el que farmea doble | `P-ZRX/P-PRESTAMO/…/INFORME.md` F1, `demostrado` |
| `Δ` simulada **0,26-0,60 s**; `τ = 1 s`; `λ ≈ 1 b/s`; padres típicos **1,14-1,39**; `S_max = 150 s` | `veritas/finalidad/delta-medido-v1/` (DMS-v0.1); `SPEC.md` |
| `t_tabla` = **809,13 ms/núcleo**; `r` = **25,03 tablas/s** (24 hilos, **cota superior del código**, luego **cota inferior del coste del atacante**); ploteo **83,608 s/GiB** (histórica) | `P-ZRX/P-INTENTO/`; `research/coste-ploteo-medido.md` |
| El formato actual: ploteo **determinista** desde datos públicos (`generate_parallel(pos_seed)`), y el verificador **enmascara él** el chunk, luego **la forma almacenada no se prueba ni para un chunk** | `PDF/autonomys-subspace`: `plotting.rs:626-627,659-665`; `subspace-verification/src/lib.rs:248-249` |

## 2 · Lo que hay que hacer

### 2.1 · Formalizar la propiedad, y reformular la pregunta correctamente

La formulación ingenua —«re-ligar debe ser barato para el honesto y caro para el atacante»— **es
imposible**: honesto y atacante ejecutan el mismo algoritmo. **La asimetría útil no es entre partes,
es entre operaciones y entre ramas.** Formaliza:

- `Sellar(datos, rama) → objeto`, con coste `T_alto` desde cero.
- `Religar(objeto, rama') → objeto'`, con coste `T_bajo`.
- **Requisito de rivalidad:** tener `objeto` para la rama `A` **no debe permitir producir peso pleno
  en `B`** sin poseer `objeto'`, y `objeto'` **debe ocupar espacio propio**.

Y aquí está la trampa que hay que mirar de frente: **si `Religar` es barato en cómputo, el objeto es
regenerable al vuelo, y entonces `P-ZRX/P-COBERTURA/` §3 se aplica tal cual** —transcriptos
idénticos, nada que distinga—. Luego la propiedad que hace falta no es que re-ligar sea *caro*, sino
que **obligue a materializar un objeto distinto por rama**. Contesta si eso es siquiera coherente:
un objeto barato de computar que, aun así, haya que almacenar.

### 2.2 · El presupuesto temporal del honesto (esto es el instrumento)

Cuantifica cuánto tiempo tiene realmente el granjero honesto para re-ligar:

- Con `λ ≈ 1 b/s`, `Δ = 0,26-0,60 s` y padres típicos 1,14-1,39, **¿con qué frecuencia cambia la
  punta sobre la que produciría?** Ésa es la tasa de re-ligadura exigida.
- **¿Cuántas ramas tiene que mantener ligadas a la vez** un honesto para no perder producción? Si son
  más de una, el honesto paga el mismo precio que el atacante y la defensa se cae por ahí.
- **El presupuesto que resulta**: `T_bajo` **MUST** ser mucho menor que el intervalo entre cambios de
  punta. Da el número, y compáralo con lo que cuesta hoy la operación más barata del ploteo
  (`t_tabla` = 809,13 ms por tabla, `r` = 25,03 tablas/s agregado).
- **Y el reverso, que es lo que decide:** si `T_bajo` es tan pequeño que el honesto llega, **el
  atacante también llega** para cada una de sus ramas. Entonces el coste del doble farmeo es
  `2·T_bajo`, no `2·T_alto`. **¿Basta eso para disuadir?** Mételo en la superficie `α*` y dilo con
  números.

### 2.3 · Qué construcciones existen, y cuáles no

Con fuentes **abiertas**, no de memoria:

- **PoRep / SDR de Filecoin** (`PDF/` y web si puedes): ¿ofrece alguna operación de *actualización*
  que no sea re-sellar entero? ¿A qué coste? El otro análisis disponible afirma que la propia
  investigación de Filecoin identifica **minar varias ramas con el mismo almacenamiento** como
  problema abierto y que el sellado compromete una rama **solo desde ese sellado**. **Ábrelo y
  verifícalo**: si la fuente no dice eso, dilo.
- **Cifrado actualizable / pruebas incrementales** (*updatable encryption*, IVC, *incrementally
  verifiable computation*): ¿dan la asimetría crear/actualizar? ¿Qué cuesta verificar?
- **La vía (iv) de `P-ZRX/P-COBERTURA/`** —semilla secreta— ¿puede ligarse a una rama, o el secreto
  es del granjero y por tanto neutral entre ramas? Contesta; es la vía más ligera y conviene saber
  si sirve aquí.

**Lo que no puedas abrir, etiquétalo `no verificado` y no lo uses para decidir.**

### 2.4 · El efecto perverso que ya hundió a otras propuestas

Si la construcción encarece farmear dos ramas, **empuja al atacante a abandonar la pública** —a
`β_x`—, y `β_x` baja el umbral **el doble** que `β_d` (`demostrado`). Cuantifícalo antes de
recomendar nada. Es la trampa en la que cayeron el compromiso de intención y la tasa por identidad.

## 3 · Las preguntas

**F1** · La propiedad formalizada (§2.1), y si «barato de re-ligar pero obligatorio de almacenar» es
coherente o contradictorio.
**F2** · **El presupuesto temporal del honesto** y la tasa de re-ligadura exigida por el DAG real.
**F3** · **¿Existe la construcción?** Sí con referencia abierta y coste, o no con argumento. Si la
respuesta es que `T_bajo` suficiente para el honesto implica `T_bajo` suficiente para el atacante,
**ésa es la refutación** y va en la primera línea.
**F4** · Qué cuesta al honesto: espacio extra por rama mantenida, CPU por re-ligadura, y qué pasa con
la expiración pseudoaleatoria de sectores que ya existe.
**F5** · El efecto `β_d → β_x` (§2.4), con números sobre la superficie `α*`.
**F6** · **Veredicto:** ¿vía viva, vía muerta, o vía condicionada a una primitiva que no existe? Y
qué cambiaría del formato (`plotting.rs`, `sectors.rs`, `subspace-verification`), con el coste de
replotear la red.

## 4 · El instrumento

`P-ZRX/P-SELLO/investigacion/veritas/criptografia/sellado-rama-v1/`, estructura de LINEO §1. Lo
cuantitativo es **§2.2**: la tasa de cambio de punta y el presupuesto `T_bajo`, más el efecto sobre
`α*`. Aritmética exacta antes de aproximar; RNG por réplica con semillas **no consecutivas** si hay
Monte Carlo. **Un test que compara una fórmula consigo misma no es un test**, y en esta serie ya han
aparecido varios: declara cómo lo has evitado.

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-SELLO/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-SELLO/` es de solo lectura `PROMPT.md`. Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-SELLO/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. **Aviso:** hay otro encargo trabajando en `crates/`, `ci/`,
`SPEC.md` y `TAREAS.md`. Lo ya marcado `M` o `??` en tu entrada **no es tuyo**.

## 6 · Lecturas (ábrelas ENTERAS)

`veritas/LINEO.md` · **`P-ZRX/P-COBERTURA/investigacion/INFORME.md` entero** (la imposibilidad, sus
cuatro vías y el §7.3 de lo que sí es construible: es la restricción que tu propuesta no puede
violar) · **`P-ZRX/P-PERMANENCIA/investigacion/INFORME.md`** fichas E1-E4 (el sellado ya evaluado
como referencia estática) · `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` F1 · `P-ZRX/P-SEMBRADOR/`
(A1+C1 y por qué la unidad es la pieza) · `veritas/finalidad/delta-medido-v1/INFORME.md` (Δ y padres
típicos) · `PDF/autonomys-subspace` para el formato (abre los ficheros citados en §1 uno a uno) ·
`PDF/time-memory-tre-off-proof-space.pdf` · `research/README.md`.

## 7 · Entregables (`P-ZRX/P-SELLO/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F3**: si la construcción puede existir o por qué
  no. Después F1-F6.
- `DECISIONES-PENDIENTES.md` — bifurcaciones reales para Katana con su coste. Si la vía está muerta,
  una línea y sin inventar decisiones.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **«No se ha encontrado» y «no puede existir» son distintas.** Di cuál estás afirmando, cada vez.
- **No presentes un encarecimiento como un cierre**, ni uses palabras de cobertura.
- **No fijes** ningún parámetro: `T_alto`, `T_bajo`, la tasa de re-ligadura y el espacio por rama son
  entradas.
- **La premisa no tiene privilegio.** Si la vía está muerta, ése es el resultado.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
