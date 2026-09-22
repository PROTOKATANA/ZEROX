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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es **análisis de reglas** con un **enumerador pequeño y
exacto** sobre DAGs de juguete (el bloque te aplica entero para el enumerador). **Máximo 8 hilos**,
corridas de minutos. Julia en CPU con `./veritas/julia.sh`; **nada de Python**. Anota `uptime` antes de
cada benchmark.

# ENCARGO P-ANCLA-TEMPRANA — ¿Puede comprometerse el ancla temprano, de forma causal, y cerrar la carrera del ancla?

## 0 · Por qué existe este encargo, y una advertencia

`P-ZRX/P-EQUIVOCACION/investigacion/` dejó **una sola fuga** en la defensa contra el espacio prestado, y
la demostró con contraejemplo: **dos ramas pueden derivar anclas distintas**, y con ellas retos distintos,
y entonces el doble farmeo **no deja evidencia**. Su condición exacta es `n_priv > n_com` dentro de la
vista truncada `V_j` (`PROPOSICIONES.md` P4 y P5). Es el caso **A2** que
`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` ya marcaba «PROBABILÍSTICO, no demostrado y **NO
medido**».

La candidata que hay que evaluar **no es la congelación de la vista**, que Katana ya descartó (D-F8 = C,
2026-09-20). Es distinta y conviene no confundirlas:

1. Un bloque temprano `Q` **fija** una inyección de entropía futura.
2. `Q` se valida con el estado **anterior**, sin depender de la inyección que crea.
3. Los descendientes **heredan** ese compromiso por su **cadena de padres seleccionados**.
4. La inyección **se activa** tras un retraso.
5. Fusionar después bloques laterales **no reelige** aquel compromiso.

**La diferencia con lo descartado:** no se busca el ancla **retrospectivamente** atravesando bloques cuya
validez depende de ella; se construye una **transición causal** desde padres ya validados.

**⚠️ ADVERTENCIA, y es la razón por la que este encargo es el más delicado de los abiertos.** Esto
**reabre el área que Katana cerró el 2026-09-19/20** tras cuatro tandas de decisiones: `C-FLU-01`
(perfil 1a), `C-FLU-04` (el ancla sobre la vista restringida), `C-FLU-20/21` (la inyección activada se
hereda y el productor evita las puntas que la cambiarían), `C-FLU-22` (adopción con presupuesto),
`C-FIN-01`. **Léete `P-ZRX/P-2.1/SINTESIS.md` entera antes de proponer nada**: ahí está qué se decidió,
en qué orden, y —importante— **qué argumentos se dieron por buenos y luego resultaron falsos**. Si tu
propuesta repite uno de ellos, lo estás repitiendo.

**Tu encargo no es defender la candidata: es intentar romperla.** Un contraejemplo bien construido vale
más que una confirmación floja. Si sobrevive, entonces sí: di exactamente bajo qué condiciones.

## 1 · La condición que hay que verificar o refutar

El análisis previo propone como **condición suficiente**:

```text
L ≥ F + D          (todo en índices de slot)
```

con `L` el retraso de activación, `F` la ventana de reorganización y `D` el desplazamiento de la salida
futura del PoT. **Ojo: bajo el perfil 1a ya se tiene `L ≥ F`** (`C-FLU-01`:
`L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)`), y `D` es de pocos slots, así que la condición
sería **casi gratis**. Si eso es cierto, es el punto fuerte de la candidata. **Compruébalo o refútalo**:
no lo des por bueno porque suene bien.

Y estos cinco límites, que el análisis previo ya declaró. Para cada uno: ¿es real?, ¿lo cierra la
candidata?, ¿a qué precio?

1. Una **candidata adelantada** puede contener slots futuros que la cadena local todavía no alcanzó.
2. ZEROX compromete también una **salida PoT futura** desplazada `D` slots (`C-POT-05`, D-2 = A): no
   basta con analizar el reto del slot presente.
3. El **controlador de rango** debe impedir que las ramas valoren de forma manipulable esas mismas
   oportunidades (cruza con `P-ZRX/P-RANGO/` si ya existe).
4. Sigue existiendo una **carrera entre compromisos hermanos** antes de su activación. **Esta es la
   clave: ¿la candidata elimina la carrera, o solo la mueve de sitio?** Respóndelo con precisión.
5. **No resuelve** nodos nuevos ni particiones prolongadas.

## 2 · Lo que hay que establecer

**F1 · El mecanismo, escrito con precisión.** Qué campo lleva `Q`, cómo se hereda por la cadena de padres
seleccionados, qué pasa si `Q` queda huérfano, qué pasa si dos hermanos comprometen inyecciones distintas,
y **cómo se evita la circularidad** (un compromiso cuya validez dependa de la inyección que crea es
exactamente lo que hay que impedir; el mismo principio que `C-HDR-06` exige para el rango).

**F2 · ¿Cierra la fuga?** Toma el contraejemplo concreto de `P-ZRX/P-EQUIVOCACION/` —`I = 20`,
`L = F = 20`, `S_max = 15`, bifurcación en el slot 5— y **enuméralo bajo la candidata**. ¿Las dos ramas
comparten ahora el mismo compromiso? ¿Bajo qué condición sobre `(L, F, I, D, S_max)`? Da la condición
**necesaria y suficiente** si puedes, o la suficiente con su holgura.

**F3 · ¿Qué carrera queda?** Si la candidata mueve la carrera del ancla a una carrera entre compromisos
hermanos, **mídela**: ¿con qué probabilidad dos hermanos comprometen cosas distintas?, ¿durante cuánto
tiempo?, ¿qué la resuelve? Compara con la situación actual: ¿es mejor, igual o peor?

**F4 · Qué se rompe de lo decidido.** Una fila por cada regla vigente que la candidata tocaría
(`C-FLU-01`, `C-FLU-04`, `C-FLU-07`, `C-FLU-10/11`, `C-FLU-12`, `C-FLU-20/21/22`, `C-FIN-01`,
`C-HDR-06`, `C-POT-05`): qué propiedad necesita esa regla, si se conserva, y qué habría que reescribir.
**El invariante de no-equivocación del inyector de `C-FLU-12` merece mirada propia**: bajo la identidad
vigente es un teorema (`P-ZRX/P-IDENTIDAD/` lo midió), y cualquier cambio en cómo se elige la entropía
puede romperlo. El SPEC avisa además de que meter en la entropía un campo **moldeable por el constructor
del bloque** reabre el grinding por contenido.

**F5 · Nodos nuevos y particiones.** Confirmar que no las resuelve, y **si las empeora**.

**F6 · Comparación honesta.** Frente a **no hacer nada** (la fuga es probabilística y no está medida) y
frente a las otras defensas del tablero. ¿Cuánto vale cerrar esta fuga, dado que `P-ZRX/P-EQUIVOCACION/`
midió que `κ = 1` **salvo** que el atacante gane esta carrera?

## 3 · El enumerador

`P-ZRX/P-ANCLA-TEMPRANA/investigacion/veritas/consenso/ancla-temprana-v1/`, estructura de LINEO §1. DAGs
de juguete con **GDR-v0.2 sin modificar** (`veritas/consenso/ghostdag-rank-v1/`: es el oráculo, **no
reimplementes GHOSTDAG**). Aritmética entera o `Rational`. Barre `(L, F, I, D, S_max, punto de
bifurcación, patrón de retención)`. **Cada control compara contra el oráculo o contra una enumeración
exhaustiva**: un test que compara una fórmula consigo misma no es un test. Si usas Monte Carlo: RNG por
réplica con semillas **no consecutivas**, réplicas e IC declarados.

## 4 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-ANCLA-TEMPRANA/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`.
En `P-ZRX/P-ANCLA-TEMPRANA/` son de solo lectura `PROMPT.md` y `ENTRADA.sha256`. Al empezar y al
terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-ANCLA-TEMPRANA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 5 · Lecturas (ábrelas ENTERAS, no por la línea que otro informe cita)

**`P-ZRX/P-2.1/SINTESIS.md` entera** (qué decidió Katana, en qué orden, y qué argumentos resultaron
falsos) · **`SPEC.md` §7.1 entera** (`C-FLU-01`…`C-FLU-22`), §6.1 (`C-HDR-06`, `C-HDR-07`), §12
(`C-FIN-01`) · **`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md`** (la demostración de buena
fundamentación del ancla, y el caso A2) · `P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md` y sus tres adendas ·
**`P-ZRX/P-EQUIVOCACION/investigacion/PROPOSICIONES.md` P2–P6** y su `INFORME.md` ·
`P-ZRX/P-IDENTIDAD/investigacion/INFORME.md` §10 (el invariante de `C-FLU-12`) ·
`P-ZRX/P-REVELACION/investigacion/INFORME.md` (la ventana de adelanto y el papel de `D`) ·
`P-ZRX/P-POT/propuesta/DECISIONES-PENDIENTES.md` (D-2) · `veritas/LINEO.md` · `research/README.md`.

**Advertencia de método, lección del 2026-09-21 en este repositorio:** dos errores el mismo día salieron
de leer una línea citada en vez del documento entero. **No cites una regla sin abrir su sección completa.**

## 6 · Entregables (`P-ZRX/P-ANCLA-TEMPRANA/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta**: si la candidata cierra la carrera del ancla, bajo qué
  condición, y qué cuesta. Después F1–F6.
- `PROPOSICIONES.md` — cada proposición con premisas, demostración o contraejemplo, y etiqueta.
- `IMPACTO.md` — la tabla del F4: qué regla vigente se toca y qué habría que reescribir. **Como
  análisis, no como texto de SPEC.**
- `DECISIONES-PENDIENTES.md` — las bifurcaciones para Katana, empezando por **si merece la pena reabrir
  el ancla**.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El enumerador, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 7 · Reglas de validez

- **No cites un archivo, una línea ni una regla sin abrirla.** Cita por **identificador de regla**, no por
  número de línea.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `enumerado` (con su rejilla),
  `derivado`, `propuesto`, `no determinado`. **Una enumeración finita no es una demostración.**
- **No fijes** ningún parámetro de consenso y **no redactes texto de SPEC**.
- **No defiendas la candidata por deferencia.** Viene de un análisis externo; intenta romperla primero.
- **Si la candidata no sobrevive, ese es el resultado y vale lo mismo.**
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
