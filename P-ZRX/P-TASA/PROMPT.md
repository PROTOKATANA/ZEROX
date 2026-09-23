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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es un **modelo económico pequeño** sobre costes de
identidad y reparto de espacio, más análisis de reglas. El bloque te aplica entero para el modelo.
**Máximo 4 hilos**, corridas de minutos; declara el presupuesto antes de ejecutar. Julia en CPU con
`./veritas/julia.sh`; **nada de Python**. Anota `uptime` antes de cada benchmark.

# ENCARGO P-TASA — Una tasa fija por identidad: ¿cierra algo, o solo mueve el problema?

## 0 · Por qué existe este encargo, y una advertencia sobre su premisa

Tres encargos han cerrado por separado las tres vías que quedaban contra el doble farmeo:

- **`P-ZRX/P-CLAVE/`**: el castigo ligado a la clave **no disuade**. El atacante reúne el `β_d` que
  cruza la deriva con claves de saldo casi nulo (67,5 % del espacio) y **soborno cero**; y las claves
  nuevas **no se pueden encarecer sin registro ni moneda previa** (F4).
- **`P-ZRX/P-ANCESTRIA/`**: no existe una profundidad de anclaje del reto útil. `d = 0` devuelve el
  26,8941 % ya descartado.
- **`P-ZRX/P-COBERTURA/`**: la preexistencia de los bytes **no puede acreditarse** sobre el formato
  fijado. Es **demostración**, no «no se ha encontrado».

El teorema de exclusividad (`research/dag-poas-balizas-auditoria.md:30-38,66-78`) explica por qué, y
señala **una sola salida**: que crear una identidad cueste algo **no proporcional al espacio que
representa** — *«un depósito, una tasa fija por clave»*. El proyecto descartó esa salida al elegir
PoST, leyéndola como «importar PoS» (`AGENTS.md`: «No hay staking ni comités de decisión»).

**Este encargo pregunta si esa lectura era correcta**, porque una **tasa fija por identidad** no es
stake proporcional: no escala con el disco, así que el granjero doméstico seguiría pudiendo entrar.

> ⚠️ **ADVERTENCIA SOBRE LA PREMISA, y es importante que la leas antes de empezar.** La idea de este
> encargo **es de Claude, surgió en conversación y NO está validada por nadie**. Tiene al menos una
> objeción obvia que podría matarla entera, y está escrita abajo en **F2**. **No trates la premisa
> con deferencia: el encargo se considera bien ejecutado si la refuta con argumento.** Un «no sirve,
> y aquí está por qué» es el entregable completo.

**Modelo de amenaza (de Katana, obligatorio):** se asume que un ente con mucha capacidad atacará.
«No compensa económicamente» **no es un argumento de seguridad**. Da el coste **absoluto**, no solo
el relativo, y separa lo que vuelve el ataque **imposible** de lo que solo lo vuelve **caro**.

## 1 · Entradas congeladas: NO se re-miden ni se rehacen

| Hecho | Fuente |
|---|---|
| **El teorema de exclusividad.** Toda regla «una identidad-X bajo un solo reloj» es derrotable **partiendo el espacio** entre identidades, mientras crear una identidad cueste lo mismo por byte. Escapar exige coste **no proporcional al espacio** | `research/dag-poas-balizas-auditoria.md:30-38,66-78` |
| **Las identidades son gratis, medido:** repartir `S` bytes en `N` claves cuesta **el mismo** trabajo que dejarlos en una. **Coste extra de identidad = 0** | `P-ZRX/P-CLAVE/investigacion/INFORME.md` F4 |
| **Coste de la rotación de claves:** mantener `β` con rotaciones cada `T_rot` exige `1 + T_v/T_rot` veces el ploteo (**×11** con `T_v=3.600`, `T_rot=360`). Es **precio de bytes, no de saldo** | íd. §F4 |
| **`α* = (η_h − η_a·β_d − (η_h+η_a)·β_x)/(η_h+η_a)`; con `η=1`, `(1 − β_d − 2β_x)/2`. Cada unidad de espacio alquilado en EXCLUSIVA baja el umbral el DOBLE que una de doble farmeo**, porque `β_x` quita 1 a la pública y `β_d` no | `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` F1, **`demostrado`** |
| **No hay región frente a `κ = 0`** (publicar solo la rama ganadora), censura total o `V` sin cota | `P-ZRX/P-CLAVE/` F6 |
| Ploteo: **83,608 s/GiB** en CPU de 32 hilos (**cita histórica, no heredable**); GPU **5 s/GiB** (**documentada, NO medida**) | `research/coste-ploteo-medido.md`; `P-ZRX/P-CLAVE/` |
| La preexistencia **no es acreditable** para este formato; la **cobertura** del objeto caro sí es construible | `P-ZRX/P-COBERTURA/` F2, F6 |

**`AGENTS.md` es una línea roja declarada, y este encargo NO la revoca.** Tu trabajo no es proponer
staking: es determinar si una tasa fija **cae dentro o fuera** de esa prohibición, y decirlo con
argumento. Esa lectura la decide Katana, no tú.

## 2 · Lo que hay que hacer

### 2.1 · Separar tres cosas que se confunden

Formaliza y mantén separadas durante todo el informe:

- **(a) Stake proporcional al espacio** — el depósito escala con el disco. Es PoS. Rechazado.
- **(b) Depósito fijo por identidad, confiscable** — no escala con el disco, pero **es confiscable**,
  luego **necesita evidencia**, luego **depende de `κ`**.
- **(c) Tasa fija por identidad, NO recuperable** — se paga (o se quema) por **existir**, no por
  portarse mal. **No necesita evidencia ni slashing, luego NO depende de `κ`.**

**(c) es la variante que motiva el encargo**, y su propiedad interesante es justamente que esquiva
la pared contra la que murieron (7) y (7b). Analiza las tres; no las mezcles.

### 2.2 · Contra qué evasiones actúa, con números

Rehaz, **con la tasa dentro**, las evasiones ya medidas:

- **Partición de identidades.** Con tasa `τ` por identidad, repartir `S` bytes en `N` claves cuesta
  `N·τ`. Publica el `τ` mínimo que hace que partir deje de compensar, **en función de lo que el
  atacante gana partiendo** — que no es una constante y hay que modelarlo.
- **Rotación de claves** (`P-ZRX/P-CLAVE/` F4): rotar cada `T_rot` pasa a costar ploteo **y** tasas.
  ¿Cambia la conclusión de que la rotación sale gratis?
- **Sybil para cuotas o para detección estadística**: ¿revive alguna defensa que hoy está descartada
  **solo** porque las identidades son gratis? Si revive alguna, **nómbrala**: es el resultado más
  valioso que puede dar este encargo.

### 2.3 · La regresividad, que es el problema de diseño central

Una tasa **fija por identidad** la paga igual quien tiene 1 TiB bajo una clave que quien tiene
100 TiB bajo una clave. **Tal cual, es regresiva: favorece al grande**, que es lo contrario de lo
que el proyecto quiere.

- Cuantifícalo: coste de la tasa como fracción del ingreso esperado, por tamaño de granja, con la
  distribución de tamaños que declares (**hipótesis**, como en `P-ZRX/P-CLAVE/` H3).
- Y contesta la pregunta de diseño: **¿existe alguna forma en que partir cueste y acumular no?**
  Examina al menos la combinación **tasa fija + tope de espacio por identidad**, y di con franqueza
  si ese tope no convierte la tasa en un coste proporcional a saltos —es decir, en (a) disfrazado—.

### 2.4 · La objeción que puede matar el encargo entero

**Atácala primero, antes que nada.** Si cae aquí, el resto del encargo sobra y lo dices.

> **El doble farmeo no necesita partir identidades: es la MISMA clave produciendo en dos ramas.**
> Una tasa que encarece *crear* identidades encarece *partir*, no *reusar*. Entonces, ¿toca la tasa
> el doble farmeo, o no lo toca en absoluto?

Si la respuesta es «no lo toca directamente», entonces la tasa **no es una defensa**: es
**habilitante** — hace no-evadible una regla de exclusividad del tipo «una identidad, una rama»,
que hoy se evade partiendo. Y entonces aparece la segunda objeción, que es peor:

> **Una regla de exclusividad obliga al atacante a ELEGIR rama.** Elegir convierte `β_d` en `β_x`.
> Y por la fórmula **demostrada** de `P-ZRX/P-PRESTAMO/`, `β_x` **baja el umbral el doble** que
> `β_d`. Con `β = 0,2`: doble farmeo ⟹ `α* = 0,40`; exclusivo ⟹ `α* = 0,30`.
> **¿Es el remedio peor que la enfermedad?**

**Cuantifica esa comparación.** Es la pregunta que decide si esta vía merece existir, y si sale que
el remedio es peor, **ése es el resultado del encargo** y hay que enunciarlo así de claro.

### 2.5 · La unidad de la tasa y el arranque

- **¿En qué se paga?** Si es en moneda, hay problema de **bootstrap**: al arrancar no hay moneda
  distribuida, y exigirla es una barrera de entrada y una dependencia circular.
- **¿Se puede pagar en cómputo** —un trabajo fijo por identidad, no por byte— en vez de en moneda?
  Eso no exige moneda previa y no escala con el disco. Evalúa si esa variante conserva la propiedad
  que el teorema pide y qué abre (ventaja ASIC, granjero doméstico, verificación).
- **¿Es recurrente o de una vez?** Una tasa única se amortiza y deja de disuadir con el tiempo; una
  recurrente es un impuesto permanente al honesto. Di cuál analizas y por qué.

## 3 · Las preguntas

**F1** · Las tres variantes de §2.1 formalizadas, y **cuál de ellas no depende de `κ`**.
**F2** · **La objeción de §2.4: ¿toca la tasa el doble farmeo, o solo habilita reglas de
exclusividad?** Y si solo habilita: **¿el remedio es peor que la enfermedad** por la vía `β_d → β_x`?
Con números.
**F3** · Contra qué evasiones actúa (§2.2), con el `τ` mínimo de cada una. **¿Revive alguna defensa
hoy descartada solo por la gratuidad de las identidades?**
**F4** · La regresividad (§2.3), y si existe un diseño donde **partir cueste y acumular no**.
**F5** · Unidad, recurrencia y arranque (§2.5), incluida la variante **pagada en cómputo**.
**F6** · **Veredicto:** ¿cae dentro o fuera de la línea roja de `AGENTS.md`? ¿Qué decidiría Katana,
y con qué coste cada rama? Si la respuesta es que esta vía no merece existir, **dilo en la primera
línea**.

## 4 · El instrumento

`P-ZRX/P-TASA/investigacion/veritas/economia/tasa-identidad-v1/`, estructura de LINEO §1.
Aritmética exacta (`Rational{BigInt}` o intervalos) antes de cualquier aproximación: las colas de
la distribución de tamaños deciden la regresividad y **la normal falla justo donde importa**
(lección de `P-ZRX/P-CLAVE/`). Si usas Monte Carlo: RNG por réplica con semillas **no consecutivas**
—las consecutivas de `StableRNG` sesgan el MC, hallazgo de `P-ZRX/P-PUERTA/`—, réplicas e IC
declarados. **Un test que compara una fórmula consigo misma no es un test.**

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-TASA/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-TASA/` es de solo lectura `PROMPT.md`. Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-TASA/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. **Aviso:** puede haber otro encargo trabajando a la vez en
`crates/`, `ci/`, `SPEC.md` y `TAREAS.md`. Ficheros ya marcados `M` en tu entrada **no son tuyos**;
regístralos y no los toques.

## 6 · Lecturas (ábrelas ENTERAS)

`veritas/LINEO.md` · **`research/dag-poas-balizas-auditoria.md` entero** (el teorema: es el eje del
encargo, y su §2 explica por qué PoW no tiene este problema) ·
**`P-ZRX/P-CLAVE/investigacion/INFORME.md` entero** (F3, F4, F6 y el coste de rotación) ·
**`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` entero** (la superficie `α*`; es lo que sostiene la
segunda objeción) · `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §7 y su `DECISIONES-PENDIENTES.md`
(qué queda en pie tras la imposibilidad) · `P-ZRX/PROPUESTAS-VIABLES.md` (el tablero: filas 6, 7, 7b
y 10) · `AGENTS.md` y `SPEC.md` §8 (emisión y coinbase, `C-EMIT-*`) · `research/README.md`.

Fuentes externas si puedes abrirlas: mecanismos anti-sybil con coste de identidad, y el colateral de
Filecoin frente al stake de Ethereum. **Lo que no abras, `no verificado`. No inventes citas.**

## 7 · Entregables (`P-ZRX/P-TASA/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F2**: si la tasa toca el doble farmeo o solo
  habilita exclusividad, y si el remedio es peor que la enfermedad. Después F1-F6.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana, con el coste de cada rama. Si
  la vía no merece existir, dilo en una línea y no inventes decisiones.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. **La distribución de tamaños de
  granja que elijas es una hipótesis: dilo.**

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **La premisa del encargo no tiene privilegio.** Si la refutas, ése es el resultado.
- **No presentes un encarecimiento como un cierre**, ni una mitigación con palabras de cobertura.
  `κ = 0` no lo cierra nada de lo que hay aquí: no lo insinúes.
- **No fijes** ningún parámetro: `τ`, `N`, `T_rot`, el tope por identidad y la distribución de
  tamaños son **entradas**.
- **No propongas revocar `AGENTS.md`.** Determina si la tasa cae dentro o fuera; decide Katana.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
