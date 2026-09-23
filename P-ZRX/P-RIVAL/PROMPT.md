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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es un **modelo pequeño y exacto** sobre umbrales de
consenso, más análisis de reglas. El bloque te aplica entero para el modelo. **Máximo 4 hilos**,
corridas de minutos; declara el presupuesto antes de ejecutar. Julia en CPU con `./veritas/julia.sh`;
**nada de Python**. Anota `uptime` antes de cada benchmark. **No plotees ni ejecutes
`ab-proof-of-space`**: no hace falta y su ruta no paralela tiene un SIGSEGV reproducible.

# ENCARGO P-RIVAL — ¿Cuánto trabajo rival hace falta, y queda ZEROX en pie con esa cantidad?

## 0 · Por qué existe este encargo

El doble farmeo —el mismo espacio produciendo peso en dos ramas— **no tiene ninguna defensa viva**.
Han caído, con números: la identidad de billete por pieza (`P-ZRX/P-IDENTIDAD/`), el castigo por clave
(`P-ZRX/P-CLAVE/`), la maduración por registro (`P-ZRX/P-COBERTURA/`, **imposibilidad demostrada**), el
anclaje del reto a la ancestría (`P-ZRX/P-ANCESTRIA/`) y la tasa por identidad (`P-ZRX/P-TASA/`).

La razón de fondo es que **el espacio no es rival entre ramas**: leer el disco una vez produce una
prueba que vale para cualquier historia. En PoW no ocurre porque **cada hash que se tira a una
historia no se tira a la otra**: el recurso es rival por construcción.

**La propuesta que este encargo evalúa:** añadir al peso de consenso una componente de **trabajo
rival ligado a los padres** —una «pata» de PoW— de modo que convertir las lecturas de disco en peso
para dos ramas exija gastar el recurso dos veces.

**Y la pregunta no es si funciona: es cuánta hace falta.** Porque hay una dicotomía obvia que este
encargo tiene que resolver con números, no con prosa:

> **O la pata es pequeña y el atacante la absorbe —y entonces no cierra nada—, o es grande y
> entonces el trabajo es el consenso y el espacio es decorativo.** ¿Existe un punto intermedio útil?

**Si la respuesta es que no existe, ése es el resultado del encargo** y se enuncia en la primera
línea. No hay que proponer adoptarlo ni descartarlo: hay que dar la cifra y su consecuencia.

**Modelo de amenaza (de Katana, obligatorio):** se asume que un ente con mucha capacidad atacará.
«No compensa económicamente» **no es un argumento de seguridad**. Coste **absoluto**, no solo
relativo, y separar lo **imposible** de lo **caro**.

## 1 · Entradas congeladas: NO se re-miden ni se rehacen

| Hecho | Fuente |
|---|---|
| **`α* = (η_h − η_a·β_d − (η_h+η_a)·β_x)/(η_h+η_a)`; con `η=1`, `(1 − β_d − 2β_x)/2`.** `β_d` = espacio que farmea **las dos** ramas; `β_x` = espacio que **abandona** la pública y baja el umbral **el doble** | `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` F1, **`demostrado`** |
| **Un coste que no domina el beneficio no cierra nada.** El beneficio de evadir es **lineal** en el espacio; un coste **fijo** solo domina por debajo de un tamaño. «Coste no proporcional al espacio» es **necesario y NO suficiente** | `P-ZRX/P-TASA/investigacion/INFORME.md` §2.3 (hallazgo R2) |
| **Teorema de exclusividad:** toda regla por identidad se evade partiendo el espacio, porque el ploteo es lineal en bytes y las identidades son gratis | `research/dag-poas-balizas-auditoria.md:30-38,66-78` |
| **«Trunks por bloque» (un VDF por bloque desde el padre seleccionado) está descartado**, con umbral **26,8941 %** (`φ₁ = e`) por grinding de padres | `research/dag-poas-ancla-de-finalidad.md:313-319`; `P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` F2 |
| `Δ` simulada **0,26-0,60 s**; `τ = 1 s`; `λ ≈ 1 bloque/s`; `S_max = 150 s` | `veritas/finalidad/delta-medido-v1/` (DMS-v0.1); `SPEC.md` |
| Ploteo **83,608 s/GiB** en CPU de 32 hilos (**cita histórica, no heredable**) | `research/coste-ploteo-medido.md` |

## 2 · Lo que hay que hacer

### 2.1 · Formalizar «rival», que es el concepto central y hoy está implícito

**Ésta es la parte que decide si el encargo vale algo.** Distingue con precisión:

- **Un VDF por rama NO es rival**: con dos núcleos se corren dos líneas y se farmean dos ramas. El
  coste crece con el número de **ramas**, no con el de **intentos**.
- **Un PoW por rama SÍ es rival**: la tasa de hash se **reparte** entre las historias.

Define «rival» de forma que la distinción sea comprobable, y **di explícitamente si el descarte del
26,8941 % de «trunks» aplica o no a la pata de PoW.** Mi lectura —de Claude, **no validada**— es que
**no aplica**, porque aquel era un VDF y el grinding venía de que el *reto* dependía del padre. Si
crees que sí aplica, dilo y demuéstralo: sería el resultado del encargo.

### 2.2 · El modelo del peso híbrido

Hay que decidir y declarar **cómo se componen** espacio y trabajo en el peso de un bloque. Al menos:

- **aditiva**: `w = (1−θ)·w_esp + θ·w_pow`;
- **multiplicativa**: `w = w_esp^(1−θ) · w_pow^θ`;
- **de umbral**: el PoW como condición de validez con dificultad fija, sin entrar en el peso.

`θ` es **la fracción del peso que aporta el trabajo rival**, y es el símbolo central del encargo.
Elige la composición que analizas, justifícala, y di qué cambia con las otras. **No fijes `θ`.**

### 2.3 · La pregunta cuantitativa

Con el reparto de `P-PRESTAMO` (`α` propio, `β_d` doble, `β_x` exclusivo) y la pata dentro:

1. **`θ*(β_d)`** — la fracción mínima de peso en trabajo rival para que farmear dos ramas **deje de
   dar ventaja**, es decir para que el atacante prefiera concentrar a duplicar.
2. **`α*(θ)`** — cómo se mueve el umbral con `θ`. Recupera `θ = 0` como control: **debe dar
   `(1 − β_d − 2β_x)/2`**; si no, el modelo está mal y no sigas.
3. **El efecto perverso que hay que vigilar:** al encarecer el doble farmeo, ¿empuja al atacante a
   `β_x` (abandonar la pública), que baja el umbral **el doble**? Cuantifícalo. Es la trampa en la
   que cayeron las propuestas anteriores.
4. **La dicotomía:** ¿existe un `θ` que cierre el doble farmeo y deje al espacio como recurso
   dominante (`θ < 1/2`, digamos)? **Si no existe, ése es el resultado.**

### 2.4 · El precio, que es la mitad del encargo

- **Energía y hardware.** Un PoW con `θ` del peso implica una tasa de hash de red. Da el **coste
  absoluto** (vatios, y en qué se traduce) y compáralo con el coste de almacenar el mismo peso en
  disco. No hace falta precisión de mercado: hace falta el **orden de magnitud** y su fuente.
- **El granjero doméstico.** ¿Tiene que minar para producir? ¿Con qué hardware? Si la respuesta es
  que necesita una GPU además del disco, **eso cambia el proyecto** y hay que decirlo.
- **ASIC y centralización.** Un PoW pequeño es el más vulnerable a un ASIC, porque el mercado no lo
  justifica para nadie honesto pero sí para un atacante dedicado. Trátalo.
- **Interacción con el DAG.** El PoW por bloque a `λ = 1 b/s` con 15 padres: ¿se mina contra el padre
  seleccionado, contra el mergeset, contra qué? ¿Reaparece el grinding de padres que mató a
  «trunks»? **Es la objeción más seria y hay que atacarla de frente.**
- **Identidad del proyecto.** `research/` y `MIGRACION.md` registran el PoW como **retirado**. Di a
  partir de qué `θ` ZEROX deja de ser PoST en cualquier sentido defendible. Es una lectura, y se
  etiqueta como tal.

## 3 · Las preguntas

**F1** · «Rival» formalizado, y **si el descarte del 26,8941 % aplica o no** a una pata de PoW.
**F2** · El modelo de peso híbrido elegido y justificado, con el control `θ = 0`.
**F3** · **`θ*(β_d)`**: cuánta pata hace falta para que el doble farmeo deje de dar ventaja.
**F4** · **`α*(θ)`**, y si encarecer `β_d` empuja a `β_x` y empeora el umbral.
**F5** · El precio: energía absoluta, granjero doméstico, ASIC, y el grinding de padres en el DAG.
**F6** · **La dicotomía: ¿existe un `θ` útil que deje el espacio como recurso dominante?** Si no
existe, dilo en la primera línea del informe, con la cifra que lo sostiene.

## 4 · El instrumento

`P-ZRX/P-RIVAL/investigacion/veritas/consenso/trabajo-rival-v1/`, estructura de LINEO §1. Aritmética
**exacta** (`Rational{BigInt}` o intervalos) para los umbrales: son fronteras y una aproximación
flotante no basta para certificarlas. **Control obligatorio:** `θ = 0` reproduce
`α* = (1 − β_d − 2β_x)/2`. Si usas Monte Carlo: RNG por réplica con semillas **no consecutivas**
(hallazgo de `P-ZRX/P-PUERTA/`). **Un test que compara una fórmula consigo misma no es un test**, y
en esta serie ya se han encontrado varios: evítalos y declara cómo lo has comprobado.

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-RIVAL/investigacion/`.** No edites ni muevas nada de `SPEC.md`,
`TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de
`P-ZRX/`. En `P-ZRX/P-RIVAL/` es de solo lectura `PROMPT.md`. Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-RIVAL/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. **Aviso:** hay otro encargo trabajando en `crates/`, `ci/`,
`SPEC.md` y `TAREAS.md`. Los ficheros ya marcados `M` o `??` en tu entrada **no son tuyos**:
regístralos y no los toques.

## 6 · Lecturas (ábrelas ENTERAS)

`veritas/LINEO.md` · **`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` entero** (la superficie `α*`: es
el esqueleto del modelo) · **`P-ZRX/P-TASA/investigacion/INFORME.md` §2.3 y §4** (por qué un coste
que no domina no cierra; **no repitas ese error**) · `P-ZRX/P-ANCESTRIA/investigacion/INFORME.md`
(el 26,8941 % y su alcance real) · `research/dag-poas-ancla-de-finalidad.md` §10 (el descarte de
«trunks») · `research/dag-poas-balizas-auditoria.md` (el teorema) · `SPEC.md` §11 (`C-GD-*`, cómo se
compone `blue_work` hoy) y §7.2 (`C-ORD-*`) · `MIGRACION.md` y `research/README.md` (qué se retiró
del PoW y por qué).

**Advertencia de método:** en este repositorio, dos errores del mismo día salieron de leer una línea
citada en vez del documento entero.

## 7 · Entregables (`P-ZRX/P-RIVAL/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta a F6**: si existe un `θ` útil o no, con la cifra.
  Después F1-F5.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana con el coste de cada rama. Si no
  hay `θ` útil, dilo en una línea y no inventes decisiones.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`,
  `estimado`, `propuesto`, `no determinado`, `no verificado`.
- **La premisa del encargo no tiene privilegio.** Si la pata de PoW no cierra nada, ése es el
  resultado y se dice en la primera línea.
- **No fijes** ningún parámetro: `θ`, `β_d`, `β_x`, `α` y la dificultad son **entradas**.
- **No presentes un encarecimiento como un cierre**, ni uses palabras de cobertura.
- **No recomiendes adoptar ni retirar PoW.** Da la cifra y su consecuencia; decide Katana.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
