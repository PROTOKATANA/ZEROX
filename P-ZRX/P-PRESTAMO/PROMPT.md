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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es un **modelo** —identidades exactas, carreras de
horizonte finito y un juego económico pequeño—, no una campaña larga. **Máximo 8 hilos** (hay otros
encargos en la misma máquina; el tope conjunto es 24) y corridas de minutos; declara el presupuesto antes
de ejecutar. Julia en CPU con `./veritas/julia.sh`; **nada de Python**. Anota `uptime` antes de cada
benchmark: tus resultados son deterministas, pero **todo tiempo publicado se etiqueta «medido con carga
ajena»** si la carga supera tus hilos.

# ENCARGO P-PRESTAMO — El espacio honesto prestado a una rama privada: cuánto baja el umbral y cuánto castigo hace falta

## 0 · Por qué existe este encargo

En Proof of Work, un minero que ayuda a un atacante **abandona** la cadena honesta: se ve y le cuesta.
En ZEROX una parcela puede farmear **a la vez** la rama pública y una rama privada: es invisible y casi
gratis (seguir una segunda rama le cuesta al granjero verificar su PoT, `0,092–0,190` núcleos; producirlo
cuesta `1,56` núcleos y lo pone el atacante: `veritas/consenso/puerta-cobertura-v1/INFORME.md`).

Con el espacio total normalizado a 1, `α` = espacio propio del atacante (retirado de la pública) y
`β_d` = espacio honesto que trabaja en **ambas** ramas:

```text
rama pública ≈ 1 − α        rama privada ≈ α + β_d        la privada crece más  ⟺  β_d > 1 − 2α
```

Con `α = 0` es imposible (como mucho se empata). Leído como umbral: **`α* = (1 − β_d)/2`** — 0,50 si
nadie farmea doble, 0,33 si lo hace un tercio, 0,25 si lo hace la mitad. **No está demostrado que el
umbral baje: lo que la fórmula dice es que baja en proporción a `β_d`, y `β_d` es lo desconocido.** Si
farmear doble es gratis y sin riesgo, es la estrategia clásica de *nothing-at-stake*.

La solución candidata está en **`P-ZRX/P-PRESTAMO/CANDIDATA.md`** (copia congelada; léela entera,
anexo incluido): registro de parcelas por lote, maduración, **recompensas propias retenidas** y castigo
de una **infracción estrecha** (misma oportunidad firmada dos veces). Su frase clave es un **requisito,
no un hecho**: *«el consenso base debe seguir siendo seguro suponiendo que el doble farming es barato»*.
Y su criterio de éxito: *pérdida esperada del granjero reclutado > soborno necesario*, **incluyendo**
censura, fragmentación y fallos honestos.

**Tu trabajo:** (1) decir cuánto baja de verdad el umbral con espacio prestado, en deriva y en horizonte
finito; (2) resolver el juego del granjero; (3) decir **cuánta recompensa hay que retener y durante
cuánto tiempo** para que el criterio se cumpla, y frente a qué atacante **no se cumple nunca**.

**Modelo de amenaza (de Katana, obligatorio):** se asume que un ente con mucha capacidad atacará. «No
compensa» **no es un argumento de seguridad**: para cada resultado económico entrega también el **coste
absoluto** del ataque y di qué parte del mecanismo lo vuelve **imposible** y cuál solo **caro**.

## 1 · Lo que está decidido o medido, y manda

- **Baseline.** Si `P-ZRX/P-CRP/auditoria/BASELINE.md` existe cuando empieces, **léelo y úsalo**: dice qué
  identidad de deriva y qué eficiencias `η_h`, `η_a` puedes tomar y qué no. Si no existe, **parametriza**:
  `η_h`, `η_a` como símbolos, con `η_h = η_a = 1` como caso idealizado **etiquetado así**. En ningún caso
  escribas «el umbral de ZEROX es el 50 %»: CRP-v0.2/0.3 lo declaran **inconcluso** a nivel de protocolo.
- **`C-FLU-13/14`** (validez absoluta, pasado consistente de flujo) y **perfil 1a**
  `L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)` (`C-FLU-01`). **`C-FIN-01`**: un nodo con
  cadena seleccionada no reorganiza por debajo de `F_slots`. La carrera que importa dura, como mucho, `F`.
- **Unicidad de billete** `C-GD-07` (U2/U3″): dentro de una historia, las copias de un mismo billete no
  pesan ni cobran dos veces; **entre ramas disjuntas sí son válidas y azules cada una en la suya**
  (`veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6). Tras un reorg el billete de la historia
  abandonada vuelve a estar disponible (`SPEC.md` §7.2, búsquese «vuelve a estar disponible»): **hoy el
  doble uso entre ramas no es fraude**.
- **`COINBASE_MATURITY = 12 000`** bloques solo retrasa el gasto: no autoriza a confiscar (`SPEC.md`,
  C-EMIT-05). Pagan los azules y los `rojo_k` (R-FIN-8′).
- **Cobertura de la infracción.** Qué fracción `κ ∈ [0,1]` del doble farmeo deja evidencia castigable lo
  determina `P-ZRX/P-EQUIVOCACION/`. Para ti **`κ` es un símbolo**: barre `κ ∈ {0; 0,25; 0,5; 0,9; 1}`.

## 2 · El modelo mínimo obligatorio

**Actores.** Atacante con `α` propio. El resto, `1 − α`, se reparte en: leales (solo pública),
**`β_d`** (farmeo doble: trabajan en las dos) y **`β_x`** (alquiler exclusivo: abandonan la pública).

**Deriva.** `g = η_a·(α + β_d + β_x) − η_h·(1 − α − β_x)` por unidad de tiempo, en unidades de peso.
Publica la **superficie** `α*(β_d, β_x, η_h, η_a)` y comprueba que contiene, como casos particulares
exactos, `β_d > 1 − 2α` (`β_x = 0`, `η = 1`) y el umbral ordinario del alquiler exclusivo
(`α + β_x > 1/2`).

**Horizonte finito.** La deriva no basta: con deriva adversa hay probabilidad positiva en ventana
corta. Define, como CRP-v0.3, **tres eventos distintos y no los mezcles**: `P_terminal` (superar en `T`),
`P_first_passage` (superar en algún instante `≤ T`) y `P_eventual`; con déficit inicial `d ≥ 0` y
**«superar» estricto** (`P(empate) = (q/p)^d` no es `P(superar) = (q/p)^(d+1)`). Unidades de peso
explícitas: si un bloque pesa `1/g`, el déficit es `d·g`. **Referencia exacta** (ruina del jugador en
`Rational{BigInt}`, DP con **conservación de masa comprobada**) antes de cualquier Monte Carlo; RNG por
réplica con semillas **no consecutivas** (`P-ZRX/P-PUERTA/` encontró que las consecutivas de `StableRNG`
sesgan el MC); intervalos de confianza propagados a intervalos de `α`, no a un cruce interpolado.

**Estrategias del atacante que el modelo MUST cubrir**, cada una por separado y etiquetada:

1. doble publicación (`β_d`) frente a alquiler exclusivo (`β_x`);
2. **retención selectiva**: publicar parte de su rama para que la pública contenga trabajo suyo;
3. **soborno condicionado al éxito**: solo paga si la privada gana;
4. **censura de la prueba**: si gana, la evidencia entra con probabilidad `q_gana`; si pierde, `q_pierde`;
5. **fragmentación**: el reclutado reparte su espacio en muchos lotes y arriesga solo los que usa;
6. **parcelas de reserva**: lotes ya maduros que no teme perder;
7. *(escenario aparte, etiquetado «condicionado a R-FIN-13′ sin especificar»)* la **compra de varianza**
   con `sr` bajo que midió CRP-v0.1 §3 (`P` de 2,2 % a 30,8 % con `sr0/64`), combinada con `β_d`.

**El juego del granjero.** Pagos en **unidades de la emisión de la red**, no en moneda: `R` = recompensa
por bloque, `λ` = bloques por segundo, ingreso de un granjero `∝` su espacio. Pérdida si lo castigan:

```text
pérdida = retenido (ρ_ret · ingreso · T_v)  +  coste de replotear (c_r)  +  ingreso perdido durante M
acepta el soborno b   ⟺   b  >  κ · q_inclusión(resultado) · pérdida   [+ la ganancia esperada de farmear doble]
```

con `ρ_ret` = fracción retenida, `T_v` = duración del vesting, `M` = maduración, `c_r` y `M` como
símbolos (`c_r` tiene una medición de referencia: 83,6 s por GiB de ploteo en 32 hilos,
`research/coste-ploteo-medido.md`, **histórica**). Resuelve: **¿es farmear doble la estrategia dominante
sin castigo?** ¿Con castigo, para qué región de `(κ, q, ρ_ret, T_v)` deja de serlo? ¿Cuál es el `β_d` de
equilibrio en función del presupuesto de soborno?

## 3 · Las preguntas

**F1 · Deriva.** La superficie `α*(β_d, β_x, η_h, η_a)` y sus casos particulares. `demostrado`.

**F2 · Ventana `F`.** `P_win` para los tres eventos, `α ∈ {0,10; 0,20; 0,33; 0,40}`, rejilla de `β_d` y
`β_x`, `d` en un rango declarado, y `T = F_slots ∈ {1 019; 3 547; 3 600; 7 200}` (**símbolos con valores
de ejemplo**: `F` no está fijada en el SPEC). Di a partir de qué `β_d` un atacante del 33 % gana con
probabilidad no despreciable **dentro de `F`**.

**F3 · El juego.** Equilibrio de `β_d` sin castigo y con él. ¿Se cumple el requisito de `CANDIDATA.md`
—consenso base seguro con doble farmeo barato—, o el castigo es **imprescindible** para sostener el
umbral? Dilo sin rodeos: es la pregunta central.

**F4 · Coste del ataque, relativo y absoluto.** Coste total de reclutar el `β_d` necesario, como función,
**en unidades de emisión de la red** (p. ej. «`x` semanas de emisión»); con soborno condicionado al éxito
(¿le sale gratis al atacante si fracasa?) y con censura. Y el **coste absoluto** para un ente con
recursos: qué necesita además del soborno (PoT propio, `α` propio) y qué **no** puede comprar.

**F5 · Lo que el diseño necesita.** Región mínima de `(ρ_ret, T_v)` para que *pérdida esperada > soborno*
frente a un valor de ataque `V` expresado en semanas de emisión; sensibilidad a `κ`, a `q_gana` y a la
fragmentación. `T_v` **MUST** superar la ventana en que la evidencia puede aparecer (del orden de `F`
más margen): cuantifícalo. **Di frente a qué atacante no hay `(ρ_ret, T_v)` que valga** (`V` sin cota,
censura total, espacio propio).

**F6 · El coste para el honesto.** Si un granjero honesto firma doble por accidente con tasa `ε_h` por
año (nodos redundantes, reinicio con estado perdido), su pérdida esperada con cada `(ρ_ret, T_v)`.
Tabla del compromiso entre disuasión y castigo a honestos.

## 4 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-PRESTAMO/investigacion/`.** Instrumento en
`P-ZRX/P-PRESTAMO/investigacion/veritas/seguridad/espacio-prestado-v1/`, con la estructura de LINEO §1
(parte de `veritas/plantilla/`). No edites ni muevas nada de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`,
`prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`. En `P-ZRX/P-PRESTAMO/` son de
solo lectura `PROMPT.md`, `CANDIDATA.md` y `ENTRADA.sha256`. Al empezar y al terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-PRESTAMO/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 5 · Lecturas (ábrelas antes de citarlas)

`veritas/LINEO.md` entero · `P-ZRX/P-PRESTAMO/CANDIDATA.md` entero ·
`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` (mapa general; sus etiquetas de evidencia importan) ·
`veritas/seguridad/coste-rama-privada-v1/INFORME.md` §3, §4 y §6 ·
`P-ZRX/rescate-deepseek/veritas/seguridad/coste-rama-privada-v3/INFORME.md` (los tres eventos y las
eficiencias) y `P-ZRX/rescate-deepseek/encargos/ENCARGO-07v2-coste-rama-privada.md` §1 y §2 (D2, D3,
D10: **no los repitas**) · `P-ZRX/P-CRP/auditoria/BASELINE.md` si existe ·
`veritas/consenso/puerta-cobertura-v1/INFORME.md` (coste fijo y variable de cubrir un flujo) ·
`SPEC.md` §7.1 (`C-FLU-*`), §7.2 (copias de billete), §11 (`C-GD-07/08`), §12 (`C-FIN-01`) y C-EMIT-05 ·
`P-ZRX/P-RNG/investigacion/INFORME.md` §1 (la métrica `C_irr = C_inevitable + q_f·D_f`: **reutilízala**) ·
`research/README.md` (todo `research/` es evidencia histórica: **nunca cifras heredables**).
Literatura sobre sobornos y *nothing-at-stake*: solo fuentes primarias que **abras**; lo que no puedas
verificar se marca «no verificada».

## 6 · Entregables (`P-ZRX/P-PRESTAMO/investigacion/`)

- `INFORME.md` — **su primera línea es la respuesta**: cuánto baja el umbral con espacio prestado; si el
  consenso base aguanta el doble farmeo barato o necesita el castigo; y qué `(ρ_ret, T_v)` hace falta.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana: qué gana, qué paga y qué cierra
  cada opción.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 7 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz. **No
  inventes citas.**
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido` (instrumento, semilla,
  réplicas, IC), `derivado`, `estimado`, `propuesto`, `no determinado`.
- **No fijes** ningún parámetro de consenso **ni ningún precio**: `F`, `M`, `ρ_ret`, `T_v`, `κ`, `q`,
  `η`, `V`, `c_r` son entradas. **Ningún resultado es una constante escrita a mano.**
- **Un test que compara una fórmula consigo misma no es un test.** Cada control compara la simulación o
  la DP con una referencia que no salga de ella.
- **No presentes una mitigación con palabras de cobertura.** Esto es «responsabilidad económica y
  mitigación del alquiler», no exclusividad física del espacio ni garantía nueva de finalidad.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado —en particular el modelo del §2 o la forma de la pérdida
del granjero— dilo ANTES de empezar**, en tu primera respuesta y en `PROGRESO.md`. Después Claude lee tu
trabajo cita por cita y repite las comprobaciones clave, y Katana decide.
