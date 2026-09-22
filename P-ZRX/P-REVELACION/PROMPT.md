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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es una **simulación por eventos** pequeña más barridos
analíticos. **Máximo 16 hilos**, corridas de minutos (una hora como mucho para las colas de tasa baja);
declara el presupuesto antes de ejecutar. Julia en CPU con `./veritas/julia.sh`; **nada de Python**, ni
nuevo ni el histórico de `research/scripts/`, que `research/README.md` prohíbe ejecutar. Responde en
español.

# ENCARGO P-REVELACION — Qué compra de verdad la revelación retardada, y quién tiene razón sobre el adelanto

## 0 · Por qué existe este encargo

Hay **tres documentos del repositorio que no dicen lo mismo** sobre cuántos slots conoce por adelantado
un atacante con reloj `ρ` veces más rápido, y sobre qué le hace a esa ventana la **revelación retardada
R-FIN-14(h)** (el «segundo VDF»):

1. **Ronda 7** (`research/dag-poas-ancla-de-finalidad.md:319-322`): (h) *«reduce el lookahead de
   `L + I(1−1/v)` a `(L + I)(1−1/v)` para `v` finito, sin cambiar la cota con `v → ∞`»*.
2. **Ronda 10a** (`research/scripts/d8-ronda10a/informe.md`, §A y §B.1): una **recursión de la frontera
   de PoT** (instrumento Python, **no re-ejecutable**) que reproduce las dos formas de la ronda 7
   (control C2, razón 1,000), el tope `L + I − W_dec` como límite (control C1), el umbral
   `ρ* = (Lrev + I)/(I + W_dec)` **como umbral de *steering***, y un residuo por debajo de `ρ*`: las
   **rachas de anclas propias**, con ventaja `(L + (r+1)·I)(1 − 1/ρ)` y tasa `α^(n*−1)`.
3. **P-ADELANTO** (`P-ZRX/P-ADELANTO/investigacion/`, instrumento ADL-v1.0, 2026-09-21): afirma que
   `A = L + I − W_dec − D` **no depende de `ρ`**, que el histórico `A_core` **subestima**, y que con (h)
   y `ρ_max ≤ ρ*` es **`sup A = 0`**, de modo que la edad `M` de un compromiso previo de parcela
   «colapsa al margen» y el sellado secuencial «deja de ser necesario».

**Lectura del validador (Claude), que tú debes CONFIRMAR o REFUTAR por simulación, no por autoridad:**

- La «identidad 1» de ADL-v1.0, `a(t) = mín(ρ·t, Γ(t) − D)` con `Γ(t) = t + I + L − W_dec` **continua**,
  omite que la cadena de PoT es **secuencial a través de las barreras**: la entropía de la época `j` se
  conoce en un instante discreto, y a partir de ahí el atacante todavía tiene que **computar** los `I`
  slots hasta la barrera siguiente a velocidad `ρ`. Con el horizonte en **escalera**, el máximo exacto
  de la ventaja con `ρ` finito sería `A_core = (L − 1 − W_dec) + I(1 − 1/ρ)`, y el valor de ADL sería su
  **envolvente `ρ → ∞`**: una cota superior conservadora, no «el valor», y entonces ni «`A` no depende
  de `ρ`» ni «`A_core` subestima» se sostendrían como enunciados exactos.
- ADL-v1.0 usa `A_con_h = máx(0, (I + W_dec − 1) − (L + I)/ρ)` como si fuera la **ventana que explota
  el sembrador**. En la ronda 10a esa expresión es la **holgura de la carrera de *steering*** (de ahí
  sale `ρ*`), que es **otro objeto**. Si la ronda 7 tiene razón, con (h) la ventana es
  `(L + I)(1 − 1/ρ) > 0` —`0,6·(L+I)` con `ρ = 2,5`— y «`sup A = 0`» sería falso.

**Si esa lectura es correcta caen dos conclusiones de P-ADELANTO sobre las que Katana iba a decidir. Si
es incorrecta, dilo con el contraejemplo.** Cualquiera de los dos resultados vale lo mismo.

## 1 · Los dos objetos, que no se mezclan nunca más

Todo el informe **MUST** separar, con nombre distinto y tabla distinta:

- **`V` — la ventana de adelanto:** ventaja, en slots, de la frontera de PoT del atacante sobre la
  frontera honesta. Es lo que explota el **sembrador**, y lo que gobierna la edad `M` de un compromiso
  previo (`P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`, candidata A1+C1) y el tiempo de sellado
  `T_seal`. Oscila dentro de cada época: publica **máximo, mínimo y distribución**, no un número.
- **El *steering* del ancla:** si el atacante llega a evaluar la época de un candidato a ancla antes
  del plazo de decisión. Su umbral es `ρ*`; su residuo por debajo de `ρ*`, las rachas.

## 2 · Lo decidido, que manda sobre todo modelo histórico

- **Perfil 1a:** `L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)` (`C-FLU-01`,
  `SPEC.md` l. 1507-1540). `L` no es palanca libre. `L_suelo_slots` sigue `<<PENDIENTE>>`: símbolo.
- **D-2 = A:** `pot_output(B) = salida(f, slot(B) + D)` (`C-POT-05`). El reto de `s` usa `salida(f, s)`
  y **no** `pot_output` (`C-POT-03`, `SPEC.md` l. 1376-1390).
- **`S_max_slots < I_slots`** (`C-FLU-09`) e `I ≥ ρ_max·W_dec` (R-FIN-14(f)).
- **Validez absoluta y pasado consistente de flujo** (`C-FLU-13/14`); **adopción con presupuesto**
  (`C-FLU-22`). No se reabren.
- **La entropía de la inyección hoy** es la de D-F1 = A (`chunk ‖ pot_output`; ábrela en `SPEC.md`
  §7.1.4). **(h) la sustituiría**: di exactamente **qué regla `C-FLU-*` cambiaría** y cómo, sin
  redactarla como SPEC.
- **Primitiva:** AES-128 + `blake3` como Autonomys (D-1 = A). No se cambia
  (`research/pot-aes-asic-chacha.md`).

## 3 · La regla (h) que se evalúa: la de la ronda 10a, con sus seis piezas

Texto en `research/scripts/d8-ronda10a/informe.md` §A.6 (l. 199-231), etiquetado allí **PLAUSIBLE** por
su propio autor. Lo esencial: `entropía_j = blake3(AES128_chain^{Lrev·N}(blake3(chunk(I_j) ‖
salida(f, slot(I_j)))[0..16)))`, aplicada en `t_j = slot(I_j) + L`; **se calcula, no se publica**; con
**`Lrev < L`** —recomendación (h.1b): `Lrev = L − S_max`— porque con `Lrev = L` **el timekeeper honesto
no llega** (holgura 1,000×; tabla de §A.1). **P-ADELANTO usó `Lrev = L`**: corrígelo. Calibración
(h.6): `I ≤ (L − ρ_max·W_dec)/(ρ_max − 1)`.

## 4 · El instrumento: la recursión de la frontera, por eventos

**No evalúes una forma cerrada y la llames simulación.** Las formas cerradas son *comprobaciones*; la
fuente de verdad es una simulación por eventos escrita desde las reglas:

- Épocas `j` con ancla en `s_j = T_j + off_j` (`T_j = j·I`; `off`: cero, geométrico y uniforme en
  `[0, S_max)`, como variantes); barrera `t_j = s_j + L`.
- El atacante avanza `ρ` slots por segundo de pared **solo mientras tiene la entropía que necesita**;
  al llegar a `t_j − 1` sin `entropía_j`, **espera**. Cuando la obtiene, **reanuda desde la barrera**.
- **Cuándo obtiene `entropía_j`** es lo único que cambia entre variantes, y se barren todas:
  ancla **ajena** / **propia** (con probabilidad `α` por época) × **sin (h)** / **con (h)** (suma
  `Lrev/ρ`) × adversario que **espera a la decisión** (`+ W_dec`, modelo 9c) / que **especula sobre
  todos los candidatos** (modelo 10a, más fuerte).
- La frontera honesta avanza a 1 slot/s con las mismas barreras, y con (h) debe **llegar a tiempo**:
  comprueba la condición `Lrev ≤ L − W_dec` (disciplina «esperar al ancla») como invariante del
  simulador, no como supuesto.
- `+D`: incorpóralo donde las reglas lo ponen (`C-POT-05`), y mide si cambia `V` o el *steering*.
  P-ADELANTO concluyó que resta `D` slots en el estacionario bajo una premisa no escrita (su premisa 6);
  con la recursión por eventos esa premisa **se puede comprobar en vez de suponer**: hazlo.
- RNG por réplica, reducción determinista, semilla publicada. Oráculo pequeño en `Rational`/enteros
  para casos de pocas épocas, contra el que se valida el kernel rápido.

**Escribe tu recursión y tus predicciones en `PROGRESO.md` ANTES de abrir `r10a_lib.py`.** Después puedes
leer ese Python **como evidencia** (nunca ejecutarlo) para entender discrepancias.

**Vectores de regresión obligatorios** (son cifras *publicadas por un instrumento histórico*: si no las
reproduces, di cuál de los dos está mal y por qué; ábrelas en la fuente para fijar los parámetros
exactos de cada una):

| Control | Fuente (`d8-ronda10a/informe.md`) | Cifra publicada |
|---|---|---|
| C1 tope sin (h) | §B.1.1 | `L + I − W_dec = 23 130` (`L = 19 080`, `I = 4 200`, `W_dec = 150`); *bootstrap* 477,00 h a `ρ = 1,01` |
| C2 formas de la ronda 7 | §B.1.1 | `L + I(1−1/ρ)` sin (h) y `(L+I)(1−1/ρ)` con (h), razón 1,000 |
| C3 | §B.1.1 | `ρ ≤ 1 ⇒ 0` exacto |
| `ρ*` | titular y §B.1.2 | 9,24 (`2 h`, 851, `W_dec = 20`); 8,99 (`W_dec = 45`); 5,13 (`1 h`, 851) |
| `Lrev` | §A.1 | `Lrev/L = 0,979 → ρ* = 9,07`; `0,50 → 5,11` |
| rachas | §B.1.3 | `α = 0,33`: `ρ = 2,5 → n* = 6`, tasa `3,914·10⁻³`; `ρ = 3 → n* = 5`, `1,186·10⁻²` |

Y **un control más, contra ADL-v1.0**: evalúa `A_frontera` de
`P-ZRX/P-ADELANTO/investigacion/veritas/seguridad/adelanto-v1/src/modelo.jl` en tu misma rejilla y
publica la diferencia con tu `V_max` simulada, fila a fila.

## 5 · Las preguntas

**F1 · Sin (h): ¿quién tiene razón?** `V_max(ρ)`, `V_min(ρ)` y el tiempo de *bootstrap*, frente a
`A_core`, frente a `L + I(1−1/ρ)` y frente al `L + I − W_dec − D` de ADL. Di cuál es exacta, cuál es
envolvente, bajo qué adversario (espera / especula), y si «`A_core` subestima» se sostiene. **Lo que sí
parece sobrevivir de ADL —que sin (h) la ventana es `≈ L` para cualquier `ρ > 1` tras el *bootstrap*, de
modo que acotar `ρ_max` solo no la reduce— confírmalo o refútalo también.**

**F2 · Con (h): ¿qué le pasa a `V`, y qué al *steering*?** Por separado. `V(ρ)` con `Lrev < L` y con
`+D`; ¿es `≈ (Lrev + I)(1 − 1/ρ)` o es `0` por debajo de `ρ*`? El umbral `ρ*` simulado frente al
cerrado. Y las **rachas**: `V` crece durante una racha de anclas propias, así que publica la
**distribución de `V` en el tiempo** para `α ∈ {0,10; 0,25; 0,33; 0,40}` —cuantiles y tasa de
excedencia—, no solo el caso sin rachas.

**F3 · `C-FLU-01` con `I` recalibrado.** P-ADELANTO concluyó que bajar `F` a `F_carrera` deja `ρ*` en
2,147 «al borde del techo físico»; **esa tabla mantenía `I = 851` fijo mientras bajaba `F`**. Rehazla
recalibrando `I` por (h.6) en cada fila, con `Lrev = L − S_max`: `ρ*`, líneas `q + 1`, núcleos por nodo
y `V`. ¿Queda alguna realimentación `F → L → ρ*` una vez recalibrado `I`? ¿Qué acota `I` por abajo
(`C-FLU-09`, R-FIN-14(f), ¿algo más?) y qué **más** cambia al encoger `I`? Como mínimo, **cuenta** los
instantes `t_j` por unidad de tiempo (cada uno es un punto donde puede nacer una partición de flujo);
**no estimes** la probabilidad de partición, que depende de `Δ` y no está medida.

**F4 · Las cotas que necesitan las otras candidatas.** Edad `M` y tiempo de sellado `T_seal,adv`:
`M > (cuantil de V sobre ρ ∈ [1, ρ_max]) + margen`, **con y sin (h), con rachas dentro**. Como `V` no
está acotada durante una racha, la cota **MUST** darse como cuantil con su tasa de excedencia, no como
«sup». Tabla para `F ∈ {F_carrera δ=0 (1 019 s), F_carrera δ D8 (3 547 s), 1 h, 2 h}` y
`ρ_max ∈ {1,2; 1,5; 2,5; 3}`. Di con claridad **cuánto reduce (h) la edad exigida** —factor, no
adjetivo— y si «colapsa al margen» es verdadero o falso.

**F5 · Lo que (h) le cuesta al honesto.** Líneas simultáneas del timekeeper (`q = ⌈L/I⌉`, o `m·q` si
especula), núcleos de verificación por nodo, y la condición de puntualidad. **No midas AES**: usa como
entradas `prove = 1,561 s/slot` y `verify = 96,1 ms/slot` (`research/dag-poas-ancla-de-orden.md:342`,
medidos), etiquetados.

## 6 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-REVELACION/investigacion/`.** El instrumento va en
`P-ZRX/P-REVELACION/investigacion/veritas/seguridad/revelacion-v1/` con la estructura de LINEO §1.
**No edites ni muevas nada** de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`,
`veritas/` ni del resto de `P-ZRX/` (incluido `P-ZRX/P-ADELANTO/`, que lees pero no tocas). En
`P-ZRX/P-REVELACION/` son de **solo lectura** `PROMPT.md` y `ENTRADA.sha256`.

Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-REVELACION/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. Si algo cambia entre las dos que no sea tuyo, primera línea del
informe.

## 7 · Lecturas (ábrelas antes de citarlas)

`veritas/LINEO.md` entero · `research/scripts/d8-ronda10a/informe.md` §A y §B.1 · 
`research/dag-poas-ancla-de-finalidad.md` l. 310-325 · `research/dag-poas-ancla-de-orden.md` l. 270-295
(R-FIN-14 y la corrección de 10a a 9c) · `research/scripts/d9-ronda9c/informe.md` l. 250-275 (la cota de
conocimiento y la de velocidad) · `P-ZRX/P-ADELANTO/investigacion/INFORME.md` y
`…/adelanto-v1/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` · `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`
(fichas A, B y D) · `SPEC.md` §7.1 · `TAREAS.md` §2.9 (c) · `research/pot-aes-asic-chacha.md` ·
`research/README.md` (todo `research/` es evidencia histórica: vocabulario y trampas, **nunca cifras
heredables**; los vectores de la tabla de §4 son *controles*, no resultados tuyos).

## 8 · Entregables (`P-ZRX/P-REVELACION/investigacion/`)

- `INFORME.md` — **su primera línea es la respuesta**: quién tiene razón sobre `V` sin (h); qué vale `V`
  con (h); si «con (h) la edad `M` colapsa al margen» es verdadero o falso; y cuánto compra (h) de
  verdad, en factor. Después: el modelo por eventos, los controles, F1-F5.
- `CORRECCIONES-A-P-ADELANTO.md` — lista precisa de qué afirmaciones de ADL-v1.0 quedan **confirmadas**,
  **corregidas** o **refutadas**, con la fila de evidencia de cada una. Si ninguna cae, dilo igual.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana (la primera sigue siendo `ρ_max`
  y si se adopta (h)): qué gana, qué paga y qué cierra cada opción.
- `PROGRESO.md` — bitácora con `date`, las comprobaciones de entrada y salida, y tu recursión y
  predicciones **escritas antes** de leer el instrumento histórico.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 9 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz. Una
  referencia que no puedas verificar se marca «no verificada»; **no inventes citas**. Aviso:
  `research/dag-poas-ancla-de-orden-auditoria-9a/9b/9c.md` auditan las rondas **10a/10b/10c**.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido` (instrumento, semilla,
  réplicas, IC), `derivado`, `reproducido`, `estimado`, `propuesto`, `no determinado`.
- **No fijes** ningún parámetro de consenso: `F`, `L_suelo_slots`, `I_slots`, `Lrev`, `D`, `S_max`,
  `W_dec`, `ρ_max` y `α` son entradas. **Ningún resultado es una constante escrita a mano.**
- **Un test que compara una fórmula consigo misma no es un test.** En ADL-v1.0 la «regresión» comparaba
  dos transcripciones internas y dos funciones con etiquetas opuestas tenían el mismo cuerpo
  (`adelanto_D` y `adelanto_sub`). Cada control tuyo debe comparar **la simulación** con algo que no
  salga de ella.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado —en particular la lectura del validador en §0— dilo ANTES
de empezar**, en tu primera respuesta y en `PROGRESO.md`. Después Claude lee tu trabajo cita por cita y
reejecuta tu instrumento, y Katana decide.
