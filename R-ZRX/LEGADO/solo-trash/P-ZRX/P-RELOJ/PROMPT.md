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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: el peso es **análisis de reglas** más **tres modelos
pequeños y exactos** (frontera del presupuesto de verificación, superficie de manipulación por
timestamps, y dinámica del adaptador). El bloque te aplica entero. **Máximo 4 hilos**, corridas de
minutos; declara el presupuesto antes de ejecutar. Julia en CPU con `./veritas/julia.sh`; **nada de
Python**. Anota `uptime` antes de cada benchmark.

**Desviación autorizada, y hay que argumentarla:** el punto §4.1 exige medir **latencia de
instrucción AES**, y eso no se mide bien desde Julia. Puedes usar C o Rust con intrínsecos —hay un
programa de partida en `P-ZRX/P-RELOJ/medicion-previa/aeslat.c`—, pero **MUST** quedar argumentado
como desviación de LINEO en tu `METODO.md` **y** en tu `CONTRATO.md`. Es exactamente el defecto que
`P-ZRX/P-PUENTE-ESPACIO-TASA/` dejó sin cerrar; no lo repitas.

# ENCARGO P-RELOJ — ¿Puede `N` adaptarse solo, sin regalar el reloj ni el coste de verificar?

## 0 · EL CONTEXTO

**`N` es `pot_slot_iterations`: cuántas iteraciones de AES-128 encadenadas componen un slot de PoT.**
Es lo que hace que un slot dure lo que dura.

**ZEROX no lo fija en ninguna parte.** `C-POT-04` lo deja en `<<PENDIENTE: §7.3>>` —«su valor
inicial, sus límites y **quién autoriza** un cambio»— y §7.3, adonde remite, no lo menciona.
Comprobado: `grep "206557520\|206_557_520" SPEC.md crates/ ci/` no devuelve nada.

### 0.1 · Lo que sí está decidido y acota este encargo

- **`C-POT-04`** fija el dominio: `N ≠ 0`, `N ≤ u32::MAX`, **`N % 16 == 0`**. Ese 16 sale de
  `NUM_CHECKPOINTS (8) × 2` de Autonomys (verificado en
  `PDF/autonomys-subspace/crates/pallet-subspace/src/lib.rs:640-644`). Fuera de dominio el estado es
  **`Pendiente`, nunca `Inválido`**.
- **`C-FLU-16`** fija el **calendario** de un cambio de `N`: entra en vigor en la inyección de
  entropía. Es el `target_slot: None` del extrínseco de Autonomys.
- **`C-SLOT-01`** separa las dos magnitudes: «la tasa de producción y la duración del slot son
  **magnitudes distintas**». `λ` no queda atado a lo que decidas para `τ`.
- **`C-TS-04`** prohíbe la hora de red: «**ninguna** regla de consenso usa la mediana de relojes de
  pares ni hora ajustada por pares. La referencia temporal local no se convierte en voto de red.»
- **`C-UPG-01`** prohíbe señalización, votación por supermayoría y detección de versión: todo cambio
  de consenso es **hard fork por altura**. **`C-UPG-08`** enumera los parámetros declarados
  ajustables por hard fork, y **`N` NO está en esa lista.**
- **`C-CHK-01`/`C-CHK-03`**: el único checkpoint firmado se emite una vez, su clave **se destruye** y
  la autorización **caduca**. **ZEROX no tiene una llave de gobernanza.**

> **De ahí sale el problema que motiva el encargo:** Autonomys cambia `N` con
> `set_pot_slot_iterations`, que exige `ensure_root(origin)` —una llave de gobernanza— y además es un
> **trinquete**: `PotSlotIterationsMustIncrease`, `N` solo puede subir. **ZEROX no tiene ninguna de
> las dos cosas.** Tal como está escrito hoy, `N` se elige una vez y moverlo es un hard fork.

### 0.2 · Lo medido, y lo que solo está citado

**Medido por Claude el 2026-09-24** (`P-ZRX/P-RELOJ/medicion-previa/MEDICION.md`, con su programa):
la cadena dependiente de AES-128 en la máquina de referencia (Ryzen 9 9950X3D) cuesta
**7,7716 ns por bloque**. Concuerda al **0,4 %** con el `prove = 1,561 s/slot` que
`research/dag-poas-ancla-de-orden.md:342` midió con Criterion sobre 200 032 000 iteraciones, por dos
caminos independientes. **Esa cifra queda confirmada.**

**Lo que NO está medido, y el encargo no puede tratarlo como si lo estuviera:** los **4,841 ns** del
14900KS salen de dividir 1 s entre 206 557 520, y ese «1 s» es un **comentario de código**
(`subspace-node/src/chain_spec.rs:129`, *«About 1s on 6.2 GHz Raptor Lake CPU (14900KS)»*), con un
**`TODO: Adjust once we bench PoT on faster hardware`** en la línea de encima. **Los propios autores
lo dan por provisional.** Y `N` allí es un parámetro **de génesis por red**: mainnet 206 557 520,
devnet 150 000 000, dev local 100 000 000.

**Coste de verificar un slot, medido** (`veritas/rendimiento/coste-salto-v1/`, a `N ≈ 2·10⁸`):
AVX-512/VAES **92 ms** · AVX2/VAES **101 ms** · AES-NI+SSE4.1 **190 ms** · **AES por software 8,3 s**.
Verificar es **paralelizable** (8 tramos a la vez, 16 carriles); producir es **estrictamente
secuencial**. De ahí la asimetría `prove/verify ≈ 17×`.

### 0.3 · El arte previo: Chia ya lo hace, y publica su factura

**No inventes lo que existe.** Chia autoajusta `sub_slot_iters` para que el sub-slot dure ~600 s
(`research/chia-documentacion-oficial.md:50-56`). Y su documentación de consenso escribe el umbral
así: *«under the **< 42.7 % (\* vdf advantage)** colluding assumption»* (íd. §3.2). **La ventaja de
VDF está dentro del número, restándolo.** Su documentación oficial vigente tiene además **tres
cifras distintas** —54 %, 42,7 %, 40,5 %— según el supuesto. **Léelo antes de diseñar nada**, y di
qué parte de su mecanismo se traslada a ZEROX y qué parte no.

### 0.4 · POR QUÉ CHIA PUEDE Y ZEROX NO — y es la clave de todo el encargo

**Chia no es más listo: está en el otro extremo del mismo balancín, y el intercambio fue
deliberado.** `research/dag-poas-informe-52-problemas.md` §29 lo tiene escrito desde el 2026-09-08:

> **Causa.** La cadena AES **no tiene prueba corta**; verificar **recomputa** en paralelo.
> **(b) VDF con prueba corta:** Wesolowski sobre **grupos de clase**, verificación **en
> milisegundos**; **qué cuesta:** C++/GMP, el problema de interoperabilidad H-001, y un reloj donde
> **el ASIC de Chia demostró 3-4×**. **No.**

| | Primitiva | Verificar | `N` dinámico | ASIC |
|---|---|---|---|---|
| **Chia** | Grupos de clase + Wesolowski | **ms, independiente de `N`** | **barato** | **3,1–3,8× `[demostrado]`** |
| **ZEROX** | Cadena AES-128 | **recomputa, O(N)** | **caro** | 1,5–2,5× `[estimado, sin paper]` |

**Chia puede permitirse `N` dinámico porque subir `N` le cuesta al probador, no a los verificadores.**
En ZEROX le cuesta a **todos los nodos, linealmente, para siempre**. Chia compró verificación
sucinta y pagó en `ρ`; ZEROX compró `ρ` pequeño —«con AES la CPU **ya es** el ASIC»— y pagó en coste
de verificación.

> **La trampa que el encargo debe tener delante todo el rato:** adoptar `N` dinámico **manteniendo
> AES** da **el coste de Chia sin su beneficio** — pagas el impuesto de verificación creciente y no
> recuperas nada en `ρ`, porque `ρ` lo sigue fijando el techo del ASIC.

**Salvedad sobre la calidad de la evidencia, y no es menor:** el 3-4× de Chia está **demostrado con
silicio**; el 1,5-2,5× de ZEROX es una **estimación sin paper**, y el estudio de Supranational que la
sostiene **nadie lo ha localizado**. No compares las dos cifras como si tuvieran el mismo respaldo.

## 1 · LA PREGUNTA CENTRAL

> **¿Existe un mecanismo que adapte `N` al hardware real de la red, sin hard fork, sin llave de
> gobernanza, sin reabrir el timewarp más de lo tolerable, y sin que el nodo más rápido fije el coste
> de verificación que pagan todos los demás?**

**Y si no existe en su forma plena, ¿existe acotado — y dónde está exactamente el corte?**

**Reformulada tras §0.4, que es como hay que atacarla:** Chia demuestra que un adaptador **es
construible**. Lo que no está resuelto para ZEROX es su precio. Así que la pregunta operativa es:

> **¿Puede desacoplarse el coste de verificación de `N`?**

Y solo hay **tres familias de respuesta**. El encargo **MUST** evaluar las tres y decir cuál sobrevive:

1. **Techo `N_max`** — adaptación parcial dentro del presupuesto de verificación. **No desacopla:
   acota.** Y si la hipótesis de §3 es cierta, ese techo **es** `ρ_max`.
2. **Prueba corta para la cadena AES** — un SNARK sobre ~2·10⁸ rondas. **Ponle número antes de
   descartarla:** `veritas/consenso/prueba-recursiva-v1/` §2 midió que probar **GHOSTDAG**, mucho más
   barato, sale a **288 s/bloque** con Halo2 realista. Descártala con aritmética, no de memoria.
3. **Cambiar la primitiva a grupos de clase** — la vía de Chia, con su factura. **El repo ya dijo
   «No» (§29), pero lo dijo ANTES de que existiera el objetivo de `N` dinámico.** La comparación
   merece rehacerse con ese peso encima, y el resultado puede volver a ser «No»: eso es un
   entregable completo.

## 2 · LAS TRES OBJECIONES QUE HAY QUE ATACAR PRIMERO

`[lectura de Claude, NO validada. Si rompes cualquiera de las tres, ése es el resultado.]`

**(A) Circularidad: el reloj no puede medirse a sí mismo.** El PoT **es** el reloj. Para saber si un
slot duró un segundo real hace falta una referencia **fuera** de la cadena de PoT, y solo hay tres
candidatas: los relojes de los participantes (**prohibida** por `C-TS-04`), **una cadena externa** o
el tiempo físico (que es lo que el VDF existe para medir). **Determina si esto es un teorema o si hay
una cuarta fuente.**

> **Corrección del 2026-09-24, y léela antes de descartar la cadena externa.** En otros documentos de
> `P-ZRX/` el ancla externa aparece como «ayuda al operador, **nunca** regla de consenso». **Eso es
> una lectura de Claude, marcada `[NO VERIFICADO]` en el propio catálogo, no una regla del
> proyecto.** Comprobado: **`AGENTS.md` prohíbe *staking* y *comités de decisión*, y no dice nada de
> anclas externas.** La vía **está abierta a estudio** y este encargo **MUST** evaluarla en vez de
> darla por cerrada.
>
> **Pero evalúala por lo que resuelve, no por lo que parece:** una cadena externa arregla **(A)** y
> **(B)** —la circularidad y la fuente manipulable— y **NO arregla (C)**. El impuesto de verificación
> no depende de *cómo* midas el tiempo: depende de que `N` suba y de que verificar sea `O(N)`. Si
> concluyes otra cosa, demuéstralo. Y si la evalúas, cuantifica lo que arrastra: dependencia de la
> viveza ajena, manipulabilidad de los timestamps de esa cadena, y el sub-consenso de «qué cadena y a
> qué profundidad» dentro de ZEROX.

**(B) Reabre el timewarp, que es de lo poco que ZEROX tiene cerrado.** El cierre vigente dice
literalmente: *«el slot es el índice del reloj, no el sello de la cabecera, así que no se puede
falsificar»*. Si `N` pasa a depender de timestamps, esa frase deja de ser cierta. **`C-TS-02` ya
avisa:** «MTP **no sustituye** el índice PoT del retarget de rango.» **Cuantifica cuánto se reabre**,
no si se reabre.

**(C) La objeción decisiva: el adaptador le da al más rápido una palanca para cobrarle a la red.**
Verificar cuesta **O(N)**. Si `N` se indexa al hardware del más rápido, **el más rápido fija el coste
que pagan todos, en el hardware de todos, para siempre**:

| Más rápido en la red | `N` para τ = 1 s | Verificar | % del slot |
|---|---:|---:|---:|
| 14900KS (referencia) | 206 M | 92 ms | 9,2 % |
| ASIC 2,5× | 516 M | 230 ms | 23 % |
| ASIC 4× | 826 M | 368 ms | 37 % |
| ASIC 10× | 2 066 M | 920 ms | **92 %** |

*(Cifras `[derivado]` por escalado lineal desde los 92 ms medidos; **compruébalas, no las copies**.)*

**La asimetría es esta: `N` se indexa al hardware del atacante, pero la verificación se paga en el
hardware del honesto.** Y el caso de desconexión —que `N` baje— añade **oscilación**: conectar y
desconectar haría respirar el calendario, la emisión y el coste de verificación de toda la red. Es
justo lo que el trinquete de Autonomys existe para impedir.

**Objetivo declarado de Katana, que este encargo NO puede perder de vista:** que un timelord pueda
correr en **cualquier CPU de gama media-alta, Intel o AMD**. Un adaptador que expulse a los nodos
modestos **falla el objetivo aunque funcione**.

## 3 · LA HIPÓTESIS QUE HAY QUE DEMOSTRAR O ROMPER

`[lectura de Claude, NO validada. Es el corazón del encargo.]`

> **`N_max` y `ρ_max` son la misma magnitud escrita de dos formas.**
>
> Si fijas un presupuesto de verificación —«todo nodo admitido verifica en ≤ `X` % del slot»—, de ahí
> sale un techo `N_max`. Y si `N` no puede pasar de `N_max`, el hardware más rápido que supere ese
> techo **no acelera `N`: acelera la cadena**, que es exactamente `ρ`. Luego
> `ρ = τ / (N_max · t_iter(el más rápido))`, y **decidir el presupuesto de verificación ES decidir
> `ρ_max`**.

**Si esto es cierto, el adaptador no ahorra la decisión de `ρ_max`: la reformula**, y el entregable
es la correspondencia exacta entre las dos. **Si es falso, di por qué**, porque entonces hay un grado
de libertad que nadie ha visto.

## 4 · LO QUE HAY QUE HACER

### 4.1 · La frontera del presupuesto de verificación — y cerrar la brecha de latencia

Primero **mide**, reproduciendo y extendiendo `P-ZRX/P-RELOJ/medicion-previa/`:

- Reproduce los **7,7716 ns/bloque** en la máquina de referencia. Si no lo reproduces, **para y
  dilo**: toda la cadena de razonamiento del encargo descansa ahí.
- **Confirma o rompe la descomposición** «40 ciclos aquí frente a 30 en Raptor Cove». Es
  `[derivado]`, no medido: sale de que los ciclos salgan enteros a las frecuencias nominales. Mide la
  latencia de `AESENC` aislada y contrástala con **documentación de arquitectura citada** (Agner Fog,
  uops.info o el manual del fabricante; **abre la fuente, no la cites de memoria**).
- **Si el tercio de latencia es arquitectural**, es independiente de la frecuencia y **no se compra
  con un AMD mejor**: sería un **suelo de `ρ` por fabricante**. Dilo con esas palabras y con su
  número, o refútalo.
- Mide `t_iter` en **todo el hardware al que tengas acceso real**. Lo que no midas, **decláralo
  derivado** y da la fórmula. No presentes una tabla derivada como si fuera un barrido.

Después **deriva la frontera**: `N_max(hardware mínimo admitido, presupuesto X %)`, con el
presupuesto como **entrada libre**, no como un número que elijas. Da la curva, no un punto.

### 4.2 · La fuente de tiempo, y cuánto timewarp reabre

Ataca (A) y (B) de §2 con una respuesta cuantitativa:

- Enumera las fuentes de tiempo **realmente disponibles** a una regla de consenso de ZEROX, con la
  regla que las permite o prohíbe **citada por ID**. Si concluyes que solo quedan los timestamps,
  **demuéstralo**; no lo supongas.
- Con los timestamps como fuente: **cuánto puede mover `N` un atacante** que controla una fracción
  `α` de los bloques, dentro de los límites de `C-TS-01` (monotonía) y `C-TS-03` (FTL, cuyo valor
  **sigue pendiente** — trátalo como entrada). Da la región, no un ejemplo.
- **Compara con Bitcoin**, que vive con esto: qué acota allí la manipulación, y qué de eso existe o
  no existe en ZEROX. **Abre la fuente**; no cites el timewarp de memoria.

### 4.3 · La dinámica del adaptador: convergencia, oscilación y el caso de desconexión

Modela el lazo de realimentación como lo que es —un controlador— y **no supongas que converge**:

- ¿Converge, oscila o diverge, según la ganancia y el retardo de `C-FLU-16` (una inyección de
  entropía)?
- **El caso que Katana pide explícitamente:** que `N` **baje** cuando el más rápido se desconecta.
  Modela conectar/desconectar como entrada adversaria y **mide la amplitud de la oscilación** en el
  calendario, en la emisión y en el coste de verificación.
- ¿Un **trinquete** (solo sube, como Autonomys) elimina la oscilación? ¿A cambio de qué? **Cuidado:
  con hard forks por altura, accionar un trinquete tarda meses, no días** — el trinquete protege
  menos de lo que parece si el mecanismo de accionarlo es lento.
- ¿Y un adaptador **sin memoria de bajada pero con caducidad**?

### 4.4 · La equivalencia `N_max` ↔ `ρ_max` (§3)

Demuéstrala o rómpela, y si es cierta **entrega la correspondencia numérica**: dado un presupuesto de
verificación, qué `ρ` queda; dado un `ρ_max`, qué presupuesto exige. Es lo que Katana necesita para
decidir **una** cosa en vez de dos.

### 4.5 · Riesgos que tienes que vigilar

- **El error característico de esta serie es el alcance estrecho con etiqueta ancha.** Tres
  auditorías seguidas presentaron resultados correctos como si probaran más de lo que probaban.
- **Tres de las últimas seis entregas declararon conteos de test que no cuadran con sus artefactos.**
  El conteo que declares **MUST** salir de un artefacto que entregues.
- **Un test que compara una fórmula consigo misma no es un test.** Separa en una tabla las rutas
  genuinamente independientes de las que no lo son.
- **A ~20,8× sobre un 14900KS, `N` desbordaría `u32::MAX`** y chocaría con el dominio de `C-POT-04`.
  Hay un techo duro en el tipo: compruébalo y dilo si aparece en tu región de interés.
- **No confundas «el adaptador funciona» con «el adaptador sirve».** Si el techo se alcanza enseguida,
  el adaptador es **cosmético** y la decisión real vuelve a ser `ρ_max` a secas. **Ése es un
  resultado completo y publicable.**

## 5 · LAS PREGUNTAS

**F1** · ¿Es (A) un teorema —el reloj no puede medirse a sí mismo— o existe una cuarta fuente de
tiempo? **Primera línea del informe.**
**F2** · `N_max(hardware mínimo, presupuesto)`: la curva, con la medición de §4.1 detrás.
**F3** · ¿Es arquitectural el tercio de latencia? Si lo es, ¿cuál es el suelo de `ρ` por fabricante?
**F4** · Con timestamps como fuente: región de manipulación de `N` en función de `α` y del FTL.
**F5** · ¿Converge el adaptador? Amplitud de la oscilación en el caso conectar/desconectar.
**F6** · ¿`N_max ≡ ρ_max`? La correspondencia numérica en las dos direcciones.
**F7** · **Veredicto:** ¿existe un adaptador que cumpla el objetivo de Katana —cualquier CPU de gama
media-alta corre un timelord— sin expulsar a los nodos modestos por el coste de verificar? Si no
existe, **dónde está el corte exacto**.

## 6 · EL INSTRUMENTO

`P-ZRX/P-RELOJ/investigacion/veritas/consenso/reloj-adaptativo-v1/`, estructura de LINEO §1
(`CONTRATO.md`, `MODELO.md`, `METODO.md`, `HIPOTESIS.md`, `PROCEDENCIA.md`, `HUELLAS.sha256`,
`BITACORA.md`, `Project.toml`, `Manifest.toml`, `run.jl`, `src/`, `test/`, `resultados/`).

- **Referencia transparente + kernel rápido**, comparados entre sí.
- **Aritmética exacta** (`Rational{BigInt}` o intervalos) en la frontera de `N_max` y en la región de
  manipulación: son fronteras, y ahí es donde el flotante decide mal.
- **Monte Carlo:** RNG por réplica con semillas **NO consecutivas** —semillas consecutivas de
  `StableRNG` sesgan el MC, hallazgo de `P-ZRX/P-PUERTA/`—, réplicas e IC declarados.
- **`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`** obligatorio.
- **Escribe los resultados dentro de la carpeta del instrumento, no en el CWD.** `ANCLA-v0.2` tiene
  ese defecto y el riesgo es comparar una copia consigo misma sin darte cuenta.
- La parte de latencia en C o Rust: **argumenta la desviación de LINEO en `METODO.md` y
  `CONTRATO.md`** (ver la cabecera de este encargo).

## 7 · ZONA DE TRABAJO Y HUELLAS

**Escribes SOLO en `P-ZRX/P-RELOJ/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/` — incluida `P-ZRX/P-RELOJ/medicion-previa/`, que es **entrada de solo lectura**. En
`P-ZRX/P-RELOJ/` es de solo lectura `PROMPT.md`. Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-RELOJ/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. **Aviso:** hay otros encargos trabajando en `crates/`, `ci/`,
`Cargo.*` y `SPEC.md`; lo que ya aparezca `M` o `??` en tu entrada **no es tuyo**. Y por esa misma
razón **cita las reglas del SPEC por ID, nunca por número de línea**.

## 8 · LECTURAS (ábrelas ENTERAS)

**Empieza por aquí:** `P-ZRX/P-RELOJ/medicion-previa/MEDICION.md` (lo único medido) ·
`P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md` (las doce, y el Apéndice; **filtra ahí toda idea nueva**) ·
`research/chia-documentacion-oficial.md` **entero** (el arte previo y su factura).

**Después:** `veritas/LINEO.md` · `SPEC.md` §7.1 (`C-POT-01`…`08`, en especial `C-POT-04`), §7.3,
§7.4 (`C-TS-01`…`05`), §7.5 (`C-SLOT-01`…`03`) y §14 (`C-UPG-01`…`08`) ·
`research/dag-poas-ancla-de-orden.md` (la medición de `prove`/`verify` en §342 y su contexto) ·
`veritas/rendimiento/coste-salto-v1/` (el coste de verificar, medido) ·
`research/pot-aes-asic-chacha.md` §3 y §4 (el techo del ASIC, y por qué AES y no ChaCha) ·
`research/timelord-redundancia-informe.md` (`C-TIMELORD-01…04`, **propuestas, no en el SPEC**) ·
`PDF/autonomys-subspace/crates/pallet-subspace/src/lib.rs:630-670` (el extrínseco real, con su
`ensure_root` y su trinquete) · `PDF/autonomys-subspace/crates/subspace-node/src/chain_spec.rs`
(los tres valores por red y el `TODO`) ·
`PDF/autonomys-subspace/crates/subspace-proof-of-time/src/aes.rs` (qué es una iteración) ·
`AGENTS.md` · `research/README.md`.

**Advertencia de método:** en este repositorio, dos errores del mismo día salieron de leer una línea
citada en vez del documento entero.

## 9 · ENTREGABLES (`P-ZRX/P-RELOJ/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F1**, y si F7 sale «no existe», también ahí.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana con el coste de cada rama. Si no
  hay nada que decidir, una línea; **no inventes decisiones**.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
- **Solo si F7 sale afirmativo:** `BORRADOR-REGLA.md` con el mecanismo redactado, marcado
  **PROPUESTA**, y con **todos** sus valores como símbolos.

## 10 · REGLAS DE VALIDEZ

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **«No se ha encontrado» y «no puede existir» son distintas.** Di cuál afirmas, cada vez.
- **La premisa no tiene privilegio.** Las tres objeciones de §2 y la hipótesis de §3 son **de Claude
  y no están validadas**; refutar cualquiera es un entregable completo.
- **No fijes NINGÚN valor:** `N`, `N_max`, `τ`, `ρ_max`, el presupuesto de verificación, el FTL y la
  ganancia del controlador son **entradas**. `AGENTS.md`: una regla pendiente no se implementa
  inventando un número.
- **No revoques `C-TS-04` ni propongas revocarla.** Si tu mecanismo la necesita, **dilo y cuantifica
  el precio**; la calificación la hace Katana.
- **No propongas el ancla externa como regla de consenso.** Está catalogada como ayuda al operador.
- **No presentes un encarecimiento como un cierre**, ni uses palabras de cobertura.
- **No conviertas una derivación en una medición.** Si escalas los 92 ms linealmente, dilo en la
  tabla.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
