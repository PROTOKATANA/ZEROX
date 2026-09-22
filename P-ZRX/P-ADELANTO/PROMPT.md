Eres especialista senior en Julia para cómputo científico reproducible, teoría de protocolos y
optimización de alto rendimiento. Trabajas en el repositorio ZEROX, en /home/katana/zeo/ZEROX.

Antes de escribir o modificar código, lee por completo `veritas/LINEO.md` y cumple todas sus reglas.

Tu prioridad conjunta es: (1) resultado matemáticamente verdadero y reproducible; (2) el máximo
rendimiento medido compatible con esa verdad. No aceptes un programa lento sin un perfil, ni una
aceleración sin una prueba contra un oráculo independiente.

Procedimiento obligatorio:

1. Formula el modelo matemático, la complejidad temporal/espacial y el adversario/caso de borde
   relevante antes de elegir la estructura de datos.
2. Diseña la representación para la operación dominante: tipos concretos, arrays contiguos,
   SoA frente a AoS, IDs densos, BitVector/CSR/StaticArrays/Dict solo cuando el caso lo justifique.
   Explica brevemente la elección.
3. Escribe primero una referencia pequeña, transparente y preferiblemente exacta; crea tests de
   bordes, invariantes, contraejemplos previos y semillas fijas.
4. Implementa el kernel rápido dentro de funciones tipoestables, sin globals dinámicos ni Any.
   Preasigna memoria, usa versiones mutantes (!), evita asignaciones y respeta el orden de
   columnas. No materialices combinaciones, grafos o temporales innecesarios.
5. Valida el kernel rápido contra la referencia en instancias pequeñas, propiedades aleatorias y
   todos los vectores de regresión. Para umbrales numéricos, certifica con exactitud, intervalos o
   aritmética de bolas; si el margen no se puede certificar, declara el resultado inconcluso.
6. Mide el caso representativo tras calentar JIT con BenchmarkTools; perfila CPU/memoria con
   Profile, @allocated, @code_warntype y JET. Optimiza el cuello real, no el supuesto.
7. Paraleliza solo trabajo independiente y usa RNG por réplica/chunk, reducción determinista y
   ausencia demostrada de carreras. Mide el escalado y conserva la configuración que gane
   realmente, aunque use menos hilos; evita BLAS anidado.
8. Considera LoopVectorization o MPI únicamente si el perfil demuestra un kernel regular dominante
   y el coste no lo anula. Para GPU no uses Julia: escribe el kernel en C++/CUDA (LINEO §5.7), con
   oráculo CPU estricto, transferencias medidas y compute-sanitizer. Compara siempre con CPU.
9. No uses @fastmath. @inbounds, @simd, @turbo o precisión Float32 requieren prueba de
   equivalencia, comentario de supuestos y benchmark. Nunca dejes que una optimización cambie un
   veredicto sin declararlo.
10. Entrega Project.toml, Manifest.toml, comando exacto, semilla, versión/hardware, tabla de
    rendimiento, número de asignaciones y resultado de la validación. Distingue con claridad lo
    demostrado, medido, estimado y no demostrado.
11. Declara antes de ejecutar el presupuesto de tiempo, memoria y disco. Si se agota, conserva el
    checkpoint y reporta inconcluso; guarda semilla, parámetros, configuración y una entrada mínima
    reproducible para cada fallo. No confundas timeout con evidencia de falsedad.

Si una corrida supera el presupuesto declarado, detente antes de ampliar la exploración y produce
un perfil más una hipótesis de cuello de botella. Propón la mejora algorítmica o de datos de mayor
impacto y verifica que conserva resultados antes de lanzar otra corrida larga.

---

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es un cálculo **analítico y pequeño**, con barridos
de parámetros, no una campaña de simulación. **Máximo 8 hilos** y corridas de minutos. Julia en CPU
con `./veritas/julia.sh`; **nada de Python**, ni nuevo ni el histórico de `research/scripts/`, que
`research/README.md` prohíbe ejecutar. Responde en español.

# ENCARGO P-ADELANTO — Cuánto ve por delante el atacante, y qué cuesta cegarlo

## 0 · Por qué existe este encargo

`TAREAS.md` §2.9 (c) punto 11 dice, literalmente:

> **La aritmética del adelanto está SIN REHACER tras D-2 = A.** El argumento de R-FIN-14(f)/(h)
> —`I ≥ ρ_max·W_dec`, `lead_max`, `ρ* ≈ 1 + L/I`— está escrito sobre la salida **del propio slot**;
> con `pot_output = salida(f, slot+D)` **no se ha rehecho**. **Ninguna cifra de adelanto, de
> `ρ_max` ni de margen frente al sembrador debe darse por válida hasta que se rehaga.**

Ese número —llamémosle `A`, la ventana de slots que un atacante con reloj `ρ` veces más rápido
conoce por adelantado— gobierna a la vez **tres** decisiones de diseño abiertas:

1. **`ρ_max`**: qué ventaja de reloj admite ZEROX. Decisión de Katana pendiente desde el
   2026-09-08, entre `3×` sin segundo VDF y adoptar la **revelación retardada** R-FIN-14(h).
2. **La edad mínima `M`** de un compromiso previo de parcela: `P-SEMBRADOR` concluye que la
   candidata A1+C1 elimina el sembrador **solo si** `M > sup A`. Con `A` sin determinar, esa
   candidata no se puede evaluar.
3. **La viabilidad del sellado secuencial por sector**: solo sirve si el tiempo de sellado
   adversarial supera `A`. Si `A` es de horas, un sellado de horas por sector castiga al honesto
   en la misma medida y la candidata se cae sola.

**Sin `A` bajo las reglas vigentes, ninguna de las tres es evaluable.** Ese es tu encargo: no
decides ninguna de las tres, produces el número y sus regiones.

## 1 · Qué está decidido y manda sobre el modelo histórico

Las cifras de las rondas 9a/10a/10c (`research/`) son **anteriores** a dos decisiones de Katana y
**no son heredables**. Lo que manda hoy:

- **Perfil 1a, y `L` deja de ser un parámetro libre.** `C-FLU-01` (`SPEC.md` l. 1507-1540) define
  `L_slots := máx( F_slots , L_suelo_slots , S_max_slots + 1 )`. El modelo histórico trataba `L`
  como palanca independiente de `F`; **ya no lo es**. `L_suelo_slots` sigue `<<PENDIENTE>>` y va
  como símbolo.
- **D-2 = A: `pot_output = salida(f, s + D)`**, la salida futura, con `D` = retardo de autoría
  (`P-ZRX/P-POT/propuesta/DECISIONES-PENDIENTES.md`, D-2). El argumento histórico de (f)/(h) está
  escrito sobre la salida del propio slot. **Rehacerlo con `+D` es el núcleo de este encargo.**
- **Validez absoluta y pasado consistente de flujo** (`C-FLU-13`, `C-FLU-14`): el multistream queda
  cerrado por validez, no por tarifa. No lo reabras.
- **Adopción del flujo rival con presupuesto** (`C-FLU-22`, D-F9 = C, D-F10 = B): existe una
  ventana de adopción de orden `F_slots`, con presupuesto por par y cota global, que devuelve
  `Pendiente` y nunca `Inválido`.
- **PoT `blake3` + AES-128 como Autonomys** (D-1 = A). La primitiva **no se cambia**;
  `research/pot-aes-asic-chacha.md` ya cerró con fuente que sustituirla empeora el hueco CPU↔ASIC.

## 2 · El modelo histórico, que es tu punto de partida y no tu resultado

`P-ZRX/P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/` (instrumento **SEM-v1**, válido
dentro de su alcance) codifica el núcleo histórico:

```text
A_core(ρ, L, I, W_dec) = max(0, (L − 1 − W_dec) + I·(1 − 1/ρ))    [slots],  ρ > 1
A_core = 0                                                        para ρ ≤ 1
w = floor(A_core)  = número de retos futuros completos que el atacante conoce
```

y el histórico de (h) —`research/dag-poas-ancla-de-orden.md` l. 277-287, con la **corrección de la
ronda 10a**, que refutó a 9c— añade:

```text
ρ* = (L + I) / (I + W_dec)          [hasta dónde (h) anula el steering]
ρ* ≈ 1 + L/I                        [y ES TAMBIÉN el multiplicador de verificación por nodo]
```

**Puedes y debes leer SEM-v1**: es el punto de partida declarado, no una implementación rival. Pero
su modelo **no lleva `D`** y **trata `L` como libre**. Tu instrumento debe:

- **(a)** reducirse **exactamente** a `A_core` cuando `D = 0`, como test de regresión contra SEM-v1.
  Si tu modelo con `D = 0` no reproduce SEM-v1 bit a bit en la rejilla que compartáis, uno de los
  dos está mal y tienes que decir cuál y por qué;
- **(b)** exponer `A(ρ, L, I, W_dec, D, S_max)` como **función**, con `L` derivada por `C-FLU-01` y
  no como entrada libre.

## 3 · Fase 1 — Rehacer `A` con `pot_output = salida(f, s + D)`

Esto es trabajo matemático, y es la parte que decide el encargo. Antes de tocar el teclado,
escribe en `PROGRESO.md` **qué cambia conceptualmente** al mover el ancla del slot `s` al slot
`s + D`, y defiéndelo:

- ¿`D` **suma** al adelanto (el atacante ve `D` slots más allá porque la cabecera ya compromete una
  salida futura), lo **resta** (porque el productor honesto también publica con `D` de antelación y
  la ventaja relativa no crece), o el efecto **depende del régimen** de `ρ`, `I` y `W_dec`?
- ¿Qué le pasa a la calibración `I ≥ ρ_max·W_dec` de R-FIN-14(f) cuando el ancla es futura?
- ¿Cambia el punto de bifurcación, es decir, el instante en que el atacante debe **comprometerse**
  a un candidato frente al instante en que **conoce** el reto?

**Las tres respuestas pueden ser distintas de las históricas. Si tu conclusión es que `D` no cambia
`A`, demuéstralo; no lo asumas.** Y si concluyes que el modelo histórico era correcto tal cual, ese
resultado vale exactamente lo mismo y cierra el punto 11 de §2.9.

Entrega `A` como función y como **región**, no como constante. Barre `ρ` a ambos lados de 1,
incluyendo el borde `ρ = 1` y valores apenas por encima (`1,001`), donde el histórico ya mostraba
que el adelanto **no degrada suavemente**: es un acantilado.

## 4 · Fase 2 — La revelación retardada (h), rehecha

Con el mismo modelo, y **solo después** de cerrar la Fase 1:

1. **Protección.** Rehaz `ρ*` con `+D` y con `L` derivada por `C-FLU-01`. Bajo 1a, `L ≥ F_slots`;
   con `F` del orden de horas y `I` del orden de cientos o miles de segundos, la razón `L/I` que
   gobierna `ρ*` **cambia de escala** respecto al histórico. Di en qué dirección y cuánto.
2. **Coste por nodo.** El histórico afirmaba que **protección y coste son el mismo número**
   (`ρ* ≈ 1 + L/I` = multiplicador de verificación por nodo, con `q + 1` líneas de AES y
   0,15–0,81 núcleos/nodo según calibración). Compruébalo bajo las reglas vigentes: ¿sigue siendo
   la misma cantidad, o `+D` y `C-FLU-01` las separan? Expresa el coste en **núcleos por nodo** y
   en **líneas `q + 1`**, como función.
3. **El vector C4.** Si se adopta (h), «un lado de partición sin `q + 1` líneas de AES no produce
   bloques válidos aunque conserve su espacio». Reevalúalo sabiendo que **hoy existe** `C-FLU-22`
   (adopción con presupuesto) y que una partición más larga que `L` **no tiene cura**. ¿Agrava (h)
   el escenario ya aceptado, o queda subsumido en él? Es una pregunta de razonamiento sobre las
   reglas escritas, no de simulación.
4. **El suelo de `F`.** La bitácora del 2026-09-08 registra que (h) **no baja `F` por debajo de
   `F_carrera`** (0,28 h con δ=0; 0,99 h con el δ de D8). Comprueba si eso sigue siendo cierto bajo
   1a, donde `L` está atada a `F` y por tanto hay **realimentación**: bajar `F` baja `L`, que baja
   `ρ*`, que reduce la protección. **Esa realimentación no existía en el modelo histórico y puede
   ser el hallazgo principal de este encargo.** Trátala explícitamente.

## 5 · Fase 3 — Consecuencias para las tres herramientas

Cierra con las cotas que las otras candidatas necesitan, **como funciones y regiones**:

- **`ρ_max` admisible**, con y sin (h), y el coste por nodo de cada opción.
- **Cota inferior de la edad `M`** de un compromiso previo de parcela: `M > sup A` sobre la región
  de `ρ` que se decida admitir, más el margen de red/finalidad que declares.
- **Cota inferior del tiempo de sellado** adversarial para que un sellado secuencial sirva de algo,
  y si ese tiempo es compatible con que un granjero doméstico siembre su parcela.

Para cada una: qué haría falta **medir** para fiarse, y qué queda sin determinar.

## 6 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-ADELANTO/investigacion/`.** El instrumento va en
`P-ZRX/P-ADELANTO/investigacion/veritas/seguridad/adelanto-v1/` con la estructura de LINEO §1.

**No edites ni muevas nada** de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`,
`veritas/`, `deepseek/`, ni de `P-ZRX/P-2.1/`, `P-ZRX/P-POT/`, `P-ZRX/P-PUERTA/`, `P-ZRX/P-FLUJO/`,
`P-ZRX/P-SEMBRADOR/`, `P-ZRX/P-RNG/`, `P-ZRX/P-CIERRE/`. En `P-ZRX/P-ADELANTO/` son de **solo
lectura** `PROMPT.md` y `ENTRADA.sha256`.

Al empezar y al terminar, desde la raíz del repositorio:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-ADELANTO/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las **tres** salidas pegadas en `PROGRESO.md`. Si la comprobación de huellas falla al terminar y
no fallaba al empezar, dilo en la primera línea del informe.

## 7 · Lecturas (ábrelas antes de citarlas)

- `veritas/LINEO.md` **entero**.
- `SPEC.md`: §7.1 (C-POT y C-FLU), `C-FLU-01` en l. 1507-1540, `C-FLU-13`/`C-FLU-14`, `C-FLU-22`,
  y §17 para el estado general.
- `TAREAS.md` §2.9, **en especial (c) puntos 11 y 12**, y §3.3.
- `research/dag-poas-ancla-de-orden.md` l. 270-295: R-FIN-14 (a)-(h) y la corrección de 10a a 9c.
- `research/pot-aes-asic-chacha.md` **entero**: por qué la primitiva no se cambia y qué se sabe de
  `ρ` real (1,5-2,5× es **estimación**; el estudio de Supranational **no está localizado**).
- `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md` y su instrumento SEM-v1.
- `P-ZRX/P-POT/propuesta/DECISIONES-PENDIENTES.md`: D-1 y D-2 con su motivo registrado.
- `P-ZRX/P-2.1/SINTESIS.md`: qué decidió Katana y cuándo.
- `research/README.md`: todo `research/` es evidencia histórica. Da vocabulario y trampas,
  **nunca cifras heredables**.

## 8 · Entregables (`P-ZRX/P-ADELANTO/investigacion/`)

- `INFORME.md` — **su primera línea es la respuesta**: qué vale `A` bajo las reglas vigentes, si
  `+D` la cambia, y si (h) sigue comprando lo que decía comprar. Después: el modelo, la regresión
  contra SEM-v1 con `D = 0`, las regiones, la realimentación `F`↔`L`↔`ρ*`, el coste por nodo, C4, y
  las tres cotas de la Fase 3.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana: qué gana, qué paga y qué cierra
  cada opción. `ρ_max` es la primera.
- `PROGRESO.md` — bitácora con `date`, las dos comprobaciones de entrada y salida, y tu razonamiento
  de la Fase 1 **escrito antes de codificarlo**.
- El instrumento en `investigacion/veritas/seguridad/adelanto-v1/`, con la estructura de LINEO §1 y
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 9 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz,
  también al repetirlas. Una referencia externa que no puedas verificar se marca «no verificada»;
  **no inventes citas** (ya pasó una vez en este repositorio, con un «Dembo et al.» que no existía).
  Aviso concreto: `research/dag-poas-ancla-de-orden-auditoria-9a/9b/9c.md` auditan las rondas
  **10a/10b/10c**. Los nombres engañan.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido` (con instrumento y
  alcance), `derivado`, `estimado`, `propuesto`, `no determinado`. El patrón que este repositorio
  lleva repitiendo es el resultado de alcance estrecho presentado con etiqueta ancha. Un «no lo sé»
  explícito vale más que un número que haya que retirar.
- **No fijes** ningún parámetro de consenso. Todo como función o región. `L_suelo_slots`, `I_slots`,
  `F`, `D`, `S_max` y `ρ_max` van como **símbolos**.
- **Ningún resultado numérico puede ser una constante escrita a mano**: sale de una función y cambia
  al barrer sus parámetros.
- **No heredes ninguna cifra** de las rondas 9a/10a/10b/10c ni de `P-SEMBRADOR` como resultado. Como
  punto de comparación, sí, siempre etiquetado.
- Cierra el informe con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado —en particular el planteamiento del §3 sobre `+D` o
la realimentación del §4.4— dilo ANTES de empezar**, en tu primera respuesta y en `PROGRESO.md`.
Después Claude lee tu trabajo cita por cita y reejecuta tu instrumento, y Katana decide.
