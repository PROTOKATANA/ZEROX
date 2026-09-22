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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: **este encargo es de REDACCIÓN de reglas, no de cálculo.**
El bloque anterior te aplica **solo si necesitas comprobar algo con números** —y entonces: Julia con
`./veritas/julia.sh`, **máximo 4 hilos**, nada de Python—. Lo que se entrega es una `PROPUESTA-SPEC.md`,
no un instrumento. Responde en español.

# ENCARGO P-RANGO — Redactar el controlador de rango que cierra la compra de varianza

## 0 · Por qué existe este encargo

`C-HDR-06` (`SPEC.md`, l. ≈902-928) exige que el rango de solución de un bloque sea **exactamente** el
que dicta el contexto:

```text
rango_esperado(B) = controlador(past(B), flujo(B, slot(B)))
B.rango_solucion == rango_esperado(B)
```

…y **no define el controlador**. Lo dice el propio SPEC: *«El algoritmo del controlador —ventana,
bootstrap, redondeos y fusiones fuera de ventana— sigue en `TAREAS.md` §2.3; no se define aquí.»*

**Mientras no esté definido, queda abierto uno de los dos vectores medidos que mueven el umbral.**
`veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1) midió que una rama privada que fija un rango bajo
—bloques escasos y pesados— compra **cola** con el **mismo trabajo medio**: con `α = 0,45` y 400 slots,
`P(adv > hon)` sube de `0,022` a `0,308` al dividir el rango por 64. **Esas cifras fueron recalculadas**
por `P-ZRX/P-CRP1/auditoria/CIFRAS.md` con convolución exacta y quedan en
**`0,021302 / 0,095029 / 0,227470 / 0,314998`**: el fenómeno se confirma y el salto es del **2,1 % al
31,5 %**. **Usa esas cifras, no las originales.**

La cura ya está escrita como **propiedad**, no como regla, en
`veritas/seguridad/coste-rama-privada-v1/PROPUESTA.md` (P1, P2, P3). **Tu encargo es convertir esas tres
propiedades en texto de regla redactado**, con la forma y el rigor de las reglas que ya están en el SPEC.

**No editas `SPEC.md`.** Entregas una `PROPUESTA-SPEC.md`, como hicieron `P-ZRX/P-POT/propuesta/` y
`P-ZRX/P-FLUJO/propuesta/`. Katana la traslada, o no.

## 1 · Lo que hay que redactar

Lee `veritas/seguridad/coste-rama-privada-v1/PROPUESTA.md` **entera**. Sus tres propiedades MUST:

- **P1 · Acoplamiento rango-validez / rango-peso.** El peso `w(B)` **MUST** calcularse con el **mismo**
  rango que gobernó la validez de la solución de `B`; **MUST NOT** existir un segundo rango de cómputo
  de peso. Medido: desacoplados, el trabajo por slot se multiplica por `sr_val/sr_peso` **sin pagar
  espacio** (amplificación 16× con razón 16).
- **P2 · Anclaje al flujo canónico, no al pasado privado.** El conjunto de referencia del retarget
  **MUST** anclarse a los bloques que cobran por R-FIN-8′ —que es lo que ya dice R-FIN-13′— con una
  ventana **no manipulable por un pasado privado**, de modo que una rama privada no pueda obtener un
  rango distinto del que le corresponde por su espacio-tiempo acumulado.
- **P3 · *Pinning* de la tasa de la rama.** El trabajo acumulado por slot **MUST** depender solo de la
  fracción de espacio, no del historial de rango. Equivalente operativo en `PROPUESTA.md`.

Y los cinco pendientes que `TAREAS.md` §2.3 enumera y que tu redacción **MUST** cerrar o declarar:
**ventana, arranque por red, límites y redondeos, fusiones fuera de ventana, y validación de ramas
candidatas con pesos reales**.

## 2 · Lo que manda y no se reabre

- **`C-HDR-06` tal como está**: el rango esperado es función **exclusiva** de `past(B)`; **MUST NOT**
  depender del orden de llegada, la punta local, el reloj, `timestamp`, `height` ni del propio
  `rango_solucion` del candidato. **La circularidad MUST ser imposible, no desaconsejada.** Tu regla
  **MUST** conservar eso: es el punto donde es más fácil equivocarse.
- **`C-FLU-10`/`C-FLU-11`**: `flujo(B,s)` se **deriva** del pasado y **MUST NOT** declararse.
- **R-FIN-8′ y R-FIN-13′**: el conjunto que el retarget cuenta y el que la emisión paga son **el mismo**
  (azules y `rojo_k`; los `rojo_U3` no cuentan). Ese acoplamiento **no cambia**.
- **`C-GD-08`**: `blue_work(B) = blue_work(sp(B)) + Σ w(x)` sobre los azules. El peso vive ahí.
- **El perfil 1a** (`C-FLU-01`) y `C-FIN-01`.
- **No fijes ningún número.** `W` (ventana), `γ` (amortiguación), `SR_MIN`, `SR_MAX`, los redondeos y el
  arranque van como **símbolos con su criterio de elección escrito**. El SPEC avisa: los valores
  históricos `W≥3 083, γ≤0,25` y `W≥12 331, γ≤1` **no certifican este controlador** (proceden de otra
  tasa y otra `F`). **Citarlos como candidatos con esa etiqueta es correcto; fijarlos, no.**

## 3 · Lo que la redacción tiene que resolver, y son decisiones de diseño

Cada una: qué opciones hay, qué gana y qué paga cada una, cuál propones y por qué. Si una no se puede
cerrar sin una medición, **dilo y déjala como `<<PENDIENTE>>` con su criterio**, que es lo que el SPEC ya
hace en otras reglas.

1. **La ventana.** ¿Cuántos bloques o slots? ¿Se mide en **índices de slot** (como todo lo de flujo y
   `C-FIN-01`) o en **bloques** (como `C-REORG-07`)? El SPEC avisa de que convertir una en otra exige
   `λ`, que es **estimada por el retarget**: meterla en el consenso sería circular.
2. **Qué conjunto entra en la ventana**, con P2: bloques que cobran por R-FIN-8′ del **flujo canónico**.
   ¿Qué pasa con un bloque que entra tarde al mergeset? ¿Y con los `rojo_U3`?
3. **Arranque por red.** Qué rango rige antes de que haya ventana completa, sin abrir una vía por la que
   un atacante fabrique el arranque. Relaciónalo con `C-CHK` (§12.1), que ya cubre el periodo frágil.
4. **Redondeos y límites.** Aritmética **entera y comprobada** (`AGENTS.md`). Cuidado con el residuo de
   paridad ya conocido: **con `SR` impar queda un déficit de `1/(SR+1)`**, elegible y pequeño —≤ 4,9·10⁻⁴
   con `SR_MIN = 2^11`— pero **existe**, y el controlador puede evitarlo o no según cómo redondee
   (`TAREAS.md` §2.3, de `veritas/consenso/puerta-cobertura-v1/PROCEDENCIA.md` §3). **Tu redacción MUST
   decir qué hace con él.** Y `SR = 0` da `2^128`, fuera de `u128`: el dominio hay que acotarlo.
5. **Fusiones fuera de ventana.** Un bloque cuyo pasado ya estaba íntegro puede entrar al mergeset mucho
   después. ¿Entra en el retarget? ¿Con qué posición?
6. **Validación de ramas candidatas con pesos reales.** Es el pendiente que CRP-v0.1 declaró inconcluso:
   sin él, P2 no se puede comprobar sobre una rama privada completa.
7. **P1 en la práctica.** ¿Dónde vive el rango que pondera? ¿Basta con que `w(B)` use
   `B.rango_solucion` ya validado, o hace falta escribirlo como invariante aparte?

## 4 · Comprobación mínima (solo si la necesitas)

Si alguna decisión depende de un número, compruébalo con un cálculo pequeño y exacto en
`P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1/` (estructura de LINEO §1). **No repitas CRP-v0.1**:
sus cifras están recalculadas en `P-ZRX/P-CRP1/auditoria/CIFRAS.md` y las tomas de ahí. Lo que sí puede
hacer falta: comprobar el residuo de paridad con tu redondeo propuesto, y que el dominio de `SR` no se
desborda. Aritmética entera o `Rational`.

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-RANGO/propuesta/`.** No edites ni muevas nada de `SPEC.md`, `TAREAS.md`,
`ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`. En
`P-ZRX/P-RANGO/` son de solo lectura `PROMPT.md` y `ENTRADA.sha256`. Al empezar y al terminar, desde la
raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-RANGO/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 6 · Lecturas (ábrelas ENTERAS, no por la línea que otro informe cita)

`veritas/LINEO.md` (si calculas algo) · **`veritas/seguridad/coste-rama-privada-v1/PROPUESTA.md` entera**
y su `INFORME.md` §3 · `P-ZRX/P-CRP1/auditoria/CIFRAS.md` (las cifras recalculadas) ·
**`SPEC.md` §6.1 (`C-HDR-06` entero), §7.2 (peso, rango, R-FIN-8′/13′, unicidad pagable), §7.3, §11
(`C-GD-05`…`C-GD-11`) y §12.1 (`C-CHK`)** · **`TAREAS.md` §2.3 entero** y §2.9 ·
`veritas/consenso/puerta-cobertura-v1/PROCEDENCIA.md` §3 (el residuo de paridad) ·
`veritas/consenso/retarget-causal-endogeno-v1/` si existe · `crates/zx-consensus/src/bloque_dag.rs`
(`ContextoRangoDag`: cómo se hace imposible la circularidad hoy) y `crates/zx-consensus/src/dificultad.rs`
(el retarget lineal existente: **es de otra cosa**, no lo copies sin decir qué cambia) ·
`P-ZRX/P-POT/propuesta/PROPUESTA-SPEC.md` y `P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md` **como plantilla
de forma** · `research/README.md` (evidencia histórica: **nunca cifras heredables**).

**Advertencia de método, lección del 2026-09-21 en este repositorio:** dos errores el mismo día salieron
de leer una línea citada en vez del documento entero. **No cites una regla sin abrir su sección completa.**

## 7 · Entregables (`P-ZRX/P-RANGO/propuesta/`)

- `PROPUESTA-SPEC.md` — **el entregable principal**: las reglas redactadas, con identificador propuesto
  (`C-RET-xx` o el que argumentes), en la forma del SPEC, con sus `MUST`/`MUST NOT`, sus
  `<<PENDIENTE>>` declarados y, debajo de cada una, **de dónde sale** y **qué la refuta si alguien la
  quiere atacar**.
- `DECISIONES-PENDIENTES.md` — las siete decisiones del §3 que no cierres, con lo que gana, paga y cierra
  cada opción.
- `INFORME.md` — por qué esta redacción cierra la compra de varianza y **qué deja abierto**; primera
  línea = la respuesta.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni una regla sin abrirla.** Rutas completas desde la raíz. Los números
  de línea del SPEC se mueven: **cita por identificador de regla**.
- **Etiqueta cada afirmación:** `verificado en fuente`, `propuesto`, `derivado`, `medido` (con su
  instrumento), `no determinado por el SPEC`.
- **No fijes ningún parámetro de consenso.** Ni `W`, ni `γ`, ni `SR_MIN/MAX`, ni la ventana.
- **No inventes un número para cerrar una regla**: `AGENTS.md` lo prohíbe expresamente.
- **Conserva los identificadores estables** y no reutilices los retirados.
- Cierra el informe con **«Lo que esta propuesta NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
