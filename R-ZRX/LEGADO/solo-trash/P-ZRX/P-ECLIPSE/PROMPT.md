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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: el peso es **simulación de eventos discretos** sobre
un DAG con adversario de red, más **dos modelos pequeños y exactos** (captura de salientes por
prefijos, y colas de Poisson para los sensores). El bloque te aplica entero. **Máximo 8 hilos**,
corridas de minutos a una hora; declara el presupuesto antes de ejecutar. Julia en CPU con
`./veritas/julia.sh`; **nada de Python** — y esto no es una formalidad en este encargo: la evidencia
histórica que tienes que transferir **está escrita en Python** y hay que rehacerla, no reejecutarla.
Anota `uptime` antes de cada benchmark.

# ENCARGO P-ECLIPSE — El adversario de red contra las reglas vigentes (agujero D2)

## 0 · EL CONTEXTO: por qué este encargo, y por qué ahora

**Lee `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §1.4 y `P-ZRX/T-ZRX/INVENTARIO-ABIERTO.md` §A antes que
nada.** D2 está catalogado allí, con estas palabras textuales:

> Según la propia investigación del repositorio, **son las palancas de un Estado, no el reloj**
> (`research/pot-aes-asic-chacha.md` §3). […] **Sigue siendo el hueco más serio frente al adversario
> de Katana.**

**El modelo de amenaza de este proyecto** (no es una hipótesis tuya, es la premisa del encargo): se
asume que **un ente con recursos de Estado SÍ atacará**. «No compensa» no es seguridad. Hay que
distinguir *imposible* de *caro*, y dar el coste **absoluto**, no relativo.

**Por qué D2 y no otro agujero.** Es el único de la lista donde **el atacante no necesita disco**.
La ronda 11b lo midió y lo dejó escrito: en la variante (i) —retener el PoT— la víctima pasa de 192
bloques a **0**, y *«coste para el atacante: cero espacio. Es un ataque de red puro (α=0 da lo mismo
que α=0,33)»* (`research/scripts/d8-ronda11b/informe.md` §A.1). Todos los demás agujeros abiertos
—doble farmeo incluido— exigen comprar o tomar prestado espacio.

### 0.1 · Lo que ya existe, y por qué NO basta

Hay trabajo histórico serio, y **hay que aprovecharlo, no repetirlo**. Pero tiene **cuatro defectos
que lo inhabilitan como estado del arte**, y los cuatro son el encargo:

1. **La ronda 11b NUNCA SE TERMINÓ.** Su informe acaba con la línea literal
   *«(secciones D a F, pendientes)»*. Lo que falta es precisamente lo operativo: **D** (eclipse
   clásico contra el gestor de direcciones: cuántas IP en cuántos prefijos capturan las 8 salientes
   al 50 % y al 90 %), **E** (el borrador de reglas C-NET) y **F** (la tabla de entrega). Están
   especificados en `research/scripts/d8-ronda11b/ENCARGO.md` §D-F. **Nadie los hizo.**
2. **Está en Python**, y `veritas/LINEO.md` prohíbe auditorías nuevas en Python. `r11b_*.py` cuelga
   además de `d9-ronda8c/r8c_sim.py`, que es la misma familia de instrumentos donde P-CRP encontró
   defectos. **No se reejecuta: se rehace en Julia**, y ya existe base — `GDR-v0.2` en
   `veritas/consenso/ghostdag-rank-v1/` implementa GHOSTDAG, coloreo, orden y `rank` con la regla C.
3. **Sus constantes ya no son las del diseño.** Usa `Δ = 4 s` nominal; hoy `DMS-v0.1` mide
   **0,26-0,60 s** (§3.1 de `TAREAS.md`). Usa un peso por conteo; hoy `C-GD-01` pesa por `SR`. Un
   resultado medido a `Δ = 4 s` **no se extrapola** a un régimen 7-15 veces más rápido: el propio
   repositorio ya se quemó con esa extrapolación en `C-FLU-02`.
4. **Es anterior a las reglas que gobiernan hoy.** La ronda 11b es de la era D8. Las **31 reglas de
   flujo** (`C-POT-01`…`08`, `C-FLU-01`…`22`, `C-FIN-01`, `C-NET-33`) se redactaron el **2026-09-20**,
   y las nueve de transporte (`C-NET-25`…`33`) el **2026-09-17**. **Ninguna existía cuando se midió
   el eclipse.** Nadie ha comprobado qué le hacen esas reglas al ataque, ni el ataque a esas reglas.

### 0.2 · Y los sensores que la ronda 11b propuso NO están en el SPEC

Comprobado: `grep -niE "eclipse|sensor|n_min|falsa alarma" SPEC.md` **no devuelve ninguna regla**.
E1 (reloj de PoT contra reloj de pared) y E2 (bloques por ventana) viven **solo** en un informe de
`research/scripts/`. La familia `C-NET` llega a `C-NET-33` y **ninguna** de las 32 vigentes los
menciona. Es decir: el repositorio tiene un sensor medido que convierte el eclipse en caro, y **no
lo ha escrito como regla**.

Lo que ese sensor midió, y que conviene que tengas delante para calibrar la importancia del hueco:

> Para sostener un eclipse-filtro de 2 horas sin una sola alarma de E2, el atacante necesita el
> **92,5 %** del espacio de la red. Para 24 horas, el **95,6 %**.
> (`research/scripts/d8-ronda11b/informe.md` §C.5, etiquetado allí `DEMOSTRADO` a partir de la cola
> de Poisson.)

**Y su contrapartida, que el mismo informe declara con honestidad:** el atacante **no necesita
evadir E2 para robarle los bloques** al granjero —la variante (ii) con `α = 0` le cuesta el 100 % de
la recompensa—. E2 no impide el robo; lo hace **visible en 25-38 s**. **No confundas las dos cosas
en tu informe.**

## 1 · LA PREGUNTA CENTRAL

> **Con las reglas `C-NET` y `C-FLU` vigentes, ¿qué puede conseguir un adversario que controla la
> red de una víctima o de un subconjunto de la red, cuánto le cuesta en IP/prefijos/ancho de banda
> (no en espacio), y qué reglas cerrarían la diferencia?**

## 2 · LA HIPÓTESIS QUE ABRE ESTE ENCARGO, Y QUE TIENES QUE ATACAR PRIMERO

`[lectura de Claude, NO validada. Si la rompes, ése es el resultado y es un entregable completo.]`

> **El eclipse no es solo un ataque contra un nodo: es el MODO DE PRODUCCIÓN de la partición de
> flujo (agujero D3).**
>
> D3 está catalogado como «se **previene** con `L_slots` frente a `Δ`». Esa prevención supone que
> `Δ` es una **propiedad natural de la red**. Pero **un adversario de red elige `Δ`**. Si puede
> sostener un retraso `E > L_slots` contra un subconjunto de nodos, **fabrica** una partición de
> flujo — y `C-FLU-22` **solo cura el nacimiento espontáneo**.
>
> Peor: `C-FLU-22` exige `d < F_slots` para adoptar la rama rival (`C-FIN-01`). Un eclipse que dure
> más de `F_slots` deja a la víctima **permanentemente incapaz de volver**, sin que nadie haya roto
> una sola regla de consenso.
>
> Y hay un tercer filo: `C-NET-33` acota la verificación de flujo ajeno con `PRESUP_PAR` y
> `PRESUP_NODO`, y agotarlos da `Pendiente`. `TAREAS.md` §2.9(a)4 ya declara que esa rendija está
> **parcialmente bajo control del atacante**, que puede gastar presupuesto ajeno con tráfico barato
> del paso 1b. **Un atacante de red no necesita ganar la carrera de `blue_work`: le basta con que la
> víctima no pueda pagar la verificación dentro de la ventana.**

**Si esto se sostiene, D2 y D3 no son dos agujeros: son uno, y su coste se paga en IP, no en disco.**
**Si no se sostiene, dilo con la misma claridad y explica qué regla lo impide.**

## 3 · ENTRADAS CONGELADAS: no se re-miden ni se rehacen

- **`Δ` natural:** `DMS-v0.1` (`veritas/finalidad/delta-medido-v1/`), revisión 2 migrada. `Δ_99` p99
  de **0,26-0,45 s** con la cabecera de 812 B y **0,26-0,60 s** en toda la rejilla. **Es simulada, no
  medida en red desplegada**; úsala con esa etiqueta y **no la presentes como cota de red real**.
- **Coste por salto:** `veritas/rendimiento/coste-salto-v1/`, medido en hardware: 1,33-9,86 ms según
  escenario; **PoT por slot 92 ms** con AVX-512/VAES.
- **GHOSTDAG, coloreo, orden y `rank`:** `GDR-v0.2`. **Se reutiliza, no se reimplementa.**
- **`α* = (1 − β_d − 2β_x)/2`** (`P-ZRX/P-PRESTAMO/…` F1, `demostrado`). No la rederives.
- **El tiempo no es rival** (R-8 del libro de restricciones). No la reabras.

**Antes de proponer cualquier defensa, pásala por las doce restricciones de
`P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md`.** Si choca con una, está refutada antes de nacer y el
encargo quiere saber con cuál.

## 4 · LO QUE HAY QUE HACER

### 4.1 · Transferir la ronda 11b al protocolo vigente (no reejecutarla)

Reconstruye en Julia, sobre `GDR-v0.2`, las tres variantes de `ENCARGO.md` §A: **(i)** retener el
PoT, **(ii)** dejar pasar el PoT y filtrar bloques honestos, **(iii)** dejar pasar todo con retraso
`E`. **Control positivo obligatorio:** reproduce primero la fila publicada de D8 A3b que la propia
ronda 11b usó como control (`salida_a3b.txt`, `E = 200 s`, `f = 5 %`: 0,8218 / 0,6513 / 0,5920 /
0,5460 para `S = 4/20/30/150`). Si tu puerto no la reproduce, **el puerto está mal y se para ahí**.

Después, y esto es lo nuevo: **repite el barrido con la `Δ` de hoy** (0,26-0,60 s) además de con la
de entonces (4 s), **y con el peso por `SR` de `C-GD-01`**, no por conteo. Declara qué conclusiones
de 11b **sobreviven al cambio de régimen y cuáles no**. Una que no sobreviva es un resultado, no un
fallo.

### 4.2 · Hacer la sección D, que nunca se hizo

Cuántas IP, en cuántos prefijos `/16` (o el agrupamiento que use el gestor de direcciones real),
necesita el atacante para capturar **las 8 salientes** de una víctima con probabilidad **50 %** y
**90 %**. Reproduce la cuenta de **Heilman et al.** para Bitcoin como **control con fuente**, y
aplícala al esquema de Kaspa (`PrefixBucket` y tabla de direcciones). Después, el efecto de cada
contramedida de Bitcoin Core —*feeler*, *test-before-evict*, *anchors*, *block-relay-only*, límite de
`ADDR`— sobre esa probabilidad, **con fuente por cada una**; donde no haya número, hipótesis
declarada y etiquetada.

**Atención al destino:** ZEROX no corre sobre la pila de Kaspa ni la de Bitcoin, sino sobre
**libp2p** (`crates/zx-p2p/`). Lee el código antes de suponer el modelo de conexiones, y **declara
explícitamente qué parte de la cuenta de Heilman sobrevive al cambio de pila y cuál no.** Si el
gestor de direcciones de ZEROX no existe todavía, dilo: entonces la cuenta es sobre un diseño
**propuesto**, no sobre el vigente, y eso cambia la etiqueta de todo el punto.

### 4.3 · La interacción con las reglas de flujo — el núcleo del encargo

Esto es lo que **no existe en ninguna parte** y es la razón de ser de P-ECLIPSE. Ataca §2 con
números:

- **¿Puede un adversario de red fabricar una partición de flujo?** Determina el `E` y la duración
  necesarios para que la vista de época de la víctima (`C-FLU-03`) diverja de la de la red lo
  bastante para que elija otro flujo. Relaciónalo con `L_slots := máx(F_slots, L_suelo_slots,
  S_max_slots+1)` (`C-FLU-01`, perfil 1a). **`L_suelo_slots` es un símbolo sin valor: trátalo como
  entrada y da el resultado como función de él, no inventes un número.**
- **¿Cuánto cuesta dejar a una víctima fuera más de `F_slots`?** Si lo consigue, `C-FIN-01` y
  `C-FLU-22` le impiden volver. Da el coste en IP y ancho de banda, no en espacio.
- **El agotamiento de `PRESUP_NODO`/`PRESUP_PAR` como ataque de denegación de adopción.** Ambos son
  `<<PENDIENTE>>`; trátalos como parámetros libres y **da la región donde el ataque funciona**. Cruza
  con la mordaza inferior ya declarada: `PRESUP_NODO` debe bastar para verificar una rama rival
  completa, del orden de **`F_slots × 92 ms` ≈ 11 min de CPU**. Si esa cota inferior y la resistencia
  al agotamiento son incompatibles, **eso es un hallazgo de primer orden y va en la primera línea**.
- **`C-FLU-20` y el colateral honesto.** Un bloque tardío que cambiaría un ancla ya activada queda
  **infusionable para siempre**. Un eclipse retrasa bloques honestos **a voluntad**. ¿Cuántos bloques
  honestos puede condenar un atacante de red, y a qué coste?

### 4.4 · Redactar la sección E — los borradores de regla

Borradores `C-NET` nuevos, numerados a partir de **`C-NET-34`** (las 33 anteriores están tomadas, y
**`C-NET-10` está retirada con tombstone: su número NO se reutiliza**). Cubre: E1 y E2 como conducta
obligatoria del nodo (cuándo **MUST NOT** producir, cuándo **MUST** alertar, cuándo **MUST** renovar
pares), la conducta del comerciante bajo alarma, y las contramedidas del gestor de direcciones que
4.2 acredite.

**Son borradores, no reglas.** No tocan consenso, no se trasladan al SPEC, y **no fijas ni un solo
valor**: `B`, `W`, `n_min`, los presupuestos y los umbrales son **entradas**, y su calibración exige
`Δ` medida en red real, que no existe. Escribe explícitamente **qué hay que medir en red real antes
de fijar cada uno** — ése es el punto F del encargo original y sigue sin hacerse.

### 4.5 · Riesgos que tienes que vigilar en todo el encargo

- **El error característico de esta serie es el alcance estrecho con etiqueta ancha.** Tres
  auditorías seguidas (05, 06, 07) produjeron resultados correctos presentados como si probaran más
  de lo que probaban, y la validación no lo detectó hasta que una revisión externa lo señaló. En el
  06, los dos defectos que invalidan su §1 **estaban escritos en los docstrings del código que se
  reejecutó**. Reproducir un experimento no comprueba que el experimento pruebe lo que dice.
- **Tres de las últimas seis entregas declararon conteos de test que no cuadran con sus artefactos.**
  El conteo que declares tiene que salir de un artefacto de salida que entregues. Si no hay
  artefacto, no hay número.
- **Un test que compara una fórmula consigo misma no es un test.** Ya han aparecido varios en esta
  serie. Separa en una tabla las rutas **genuinamente independientes** de las que no lo son.
- **`research/pot-aes-asic-chacha.md` §3 dice «eclipse (no modelado, LAGUNA)» y eso es FALSO desde el
  2026-09-21:** sí se modeló en la ronda 11b. La fila de `AGUJEROS-Y-SOLUCIONES.md` lo corrige. Es un
  aviso de método: **en este repositorio hay documentos que se contradicen entre sí, y la fecha
  manda.** Cuando encuentres una contradicción, **anótala**, no la resuelvas en silencio.

## 5 · LAS PREGUNTAS

**F1** · **¿Se sostiene §2 — el eclipse fabrica la partición de flujo?** Demuéstralo o rómpelo.
**Primera línea del informe.**
**F2** · ¿Qué conclusiones de la ronda 11b sobreviven al régimen de hoy (`Δ` medida, peso por `SR`,
31 reglas de flujo) y cuáles no?
**F3** · Sección D: IP y prefijos para capturar las 8 salientes al 50 % y al 90 %, sobre la pila real
de ZEROX, con el control de Heilman y el efecto de cada contramedida.
**F4** · El coste **absoluto** del adversario de red, en IP, prefijos, ancho de banda y tiempo —
**no** en fracción de espacio. Y si existe un `α` que lo abarate, cuál.
**F5** · ¿Son compatibles la cota inferior de `PRESUP_NODO` (~11 min de CPU) y la resistencia a su
agotamiento? Si no, dilo en la primera línea junto a F1.
**F6** · Los borradores `C-NET-34+` y **qué hay que medir en red real antes de fijar cada valor**.
**F7** · **Veredicto:** qué queda cerrado, qué queda acotado, qué queda abierto, y qué decide Katana.

## 6 · EL INSTRUMENTO

`P-ZRX/P-ECLIPSE/investigacion/veritas/consenso/eclipse-red-v1/`, estructura de LINEO §1
(`CONTRATO.md`, `MODELO.md`, `METODO.md`, `HIPOTESIS.md`, `PROCEDENCIA.md`, `HUELLAS.sha256`,
`BITACORA.md`, `Project.toml`, `Manifest.toml`, `run.jl`, `src/`, `test/`, `resultados/`).

- **Referencia transparente + kernel rápido**, comparados entre sí, como exige LINEO.
- **Aritmética exacta** (`Rational{BigInt}` o intervalos) para las colas de Poisson de los sensores
  y para la captura de salientes: son colas, y ahí es donde el flotante falla.
- **Monte Carlo:** RNG por réplica con semillas **NO consecutivas** — semillas consecutivas de
  `StableRNG` sesgan el MC, hallazgo de `P-ZRX/P-PUERTA/`. Réplicas e intervalos de confianza
  declarados.
- **`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`** obligatorio: qué supuestos, de haberse elegido de
  otro modo, cambiarían el veredicto. En esta serie ya hubo un control que **codificaba su propia
  conclusión** y solo lo cazó la verificación independiente.
- **Escribe los resultados dentro de la carpeta del instrumento, no en el CWD.** `ANCLA-v0.2` tiene
  ese defecto (`run.jl:49` y otras cuatro líneas) y el riesgo es **comparar una copia consigo misma
  sin darse cuenta**.

## 7 · ZONA DE TRABAJO Y HUELLAS

**Escribes SOLO en `P-ZRX/P-ECLIPSE/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-ECLIPSE/` es de solo lectura `PROMPT.md`. Al empezar y al terminar, desde la
raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-ECLIPSE/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. **Aviso:** hay otro encargo trabajando en `crates/`, `ci/`,
`Cargo.*` y `SPEC.md`; lo que ya aparezca `M` o `??` en tu entrada **no es tuyo**. Y por esa misma
razón **cita las reglas del SPEC por ID, nunca por número de línea**: las líneas se desplazan.

## 8 · LECTURAS (ábrelas ENTERAS)

**Empieza por aquí:** `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §1.4 (la ficha D2) ·
`research/scripts/d8-ronda11b/informe.md` **entero** · `research/scripts/d8-ronda11b/ENCARGO.md`
**entero** (los puntos D, E y F que faltan) · `P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md` (las doce, y
el Apéndice).

**Después:** `veritas/LINEO.md` · `SPEC.md` §7.1 (`C-POT-*`, `C-FLU-*`), §12 (`C-FIN-01`) y §16
(`C-NET-*`, en especial `C-NET-25`…`C-NET-33`) · `TAREAS.md` §2.7, §2.9 y §2.11 ·
`veritas/finalidad/delta-medido-v1/INFORME.md` y su `ENMIENDA-R2.md` ·
`veritas/consenso/ghostdag-rank-v1/` (el instrumento que reutilizas) ·
`research/dag-poas-informe-52-problemas.md` §2 y §12 (**`TAREAS.md` §2.10(3) declara que falta
contrastarlas con las `C-NET`/`C-FLU` vigentes: hazlo**) · `research/pot-aes-asic-chacha.md` §3 ·
`research/timelord-redundancia-informe.md` (`C-TIMELORD-01…04`, **propuestas, no en el SPEC**) ·
`crates/zx-p2p/` (la pila real) · `AGENTS.md` · `research/README.md`.

**Advertencia de método:** en este repositorio, dos errores del mismo día salieron de leer una línea
citada en vez del documento entero.

## 9 · ENTREGABLES (`P-ZRX/P-ECLIPSE/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F1**, y a F5 si sale incompatible. Después F2-F7.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana, con el coste de cada rama. Si no
  hay nada que decidir, una línea; **no inventes decisiones**.
- `BORRADORES-C-NET.md` — los textos de 4.4, numerados desde `C-NET-34`, marcados **PROPUESTA**.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 10 · REGLAS DE VALIDEZ

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **«No se ha encontrado» y «no puede existir» son distintas.** Di cuál afirmas, cada vez.
- **La premisa no tiene privilegio.** La hipótesis de §2 es **de Claude y no está validada**; si la
  refutas, ése es el resultado y es un entregable completo.
- **No revoques `AGENTS.md`** ni propongas hacerlo. En particular: **nada de comités de decisión**, y
  el ancla externa es **ayuda al operador, nunca regla de consenso**. Analiza y cuantifica; decide
  Katana.
- **No presentes un encarecimiento como un cierre**, ni uses palabras de cobertura. Un sensor que
  hace visible un ataque **no lo impide**, y el informe tiene que decirlo con esas palabras.
- **No fijes** ningún parámetro: `B`, `W`, `n_min`, `L_suelo_slots`, `PRESUP_PAR`, `PRESUP_NODO`,
  `E`, `α` y los umbrales son **entradas**.
- **No conviertas una simulación en una medición de red.** `Δ` es sintética. Dilo en cada tabla que
  la use.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
