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

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es un **modelo económico pequeño** sobre distribuciones,
más análisis de reglas. El bloque te aplica entero para el modelo. **Máximo 8 hilos**, corridas de
minutos; declara el presupuesto antes de ejecutar. Julia en CPU con `./veritas/julia.sh`; **nada de
Python**. Anota `uptime` antes de cada benchmark.

# ENCARGO P-CLAVE — Retención por clave: a quién no disuade, y cuánto cuesta reclutarlo

## 0 · Por qué existe este encargo

El paquete económico contra el espacio prestado (`P-ZRX/P-CLAVE/CANDIDATA.md`, copia congelada: léela
entera, anexo incluido) ataba las recompensas retenidas al **lote de parcelas registrado**. Eso lo dejaba
**bloqueado**: registrar un lote exige una prueba de que el compromiso cubre todos sus bytes, y esa
prueba **no existe** para el formato de Autonomys (`P-ZRX/P-SEMBRADOR/` la llama C1;
`P-ZRX/P-PERMANENCIA/` confirmó que tampoco la dan las aperturas por muestreo ni las parciales).

**El desbloqueo es ligar la retención a la CLAVE PoAS, no al lote.** Para confiscar un saldo retenido
**no hace falta demostrar que la parcela existía entera**: basta con que el saldo esté asociado a la
clave que firmó, y con una infracción demostrable. La variante ya estaba escrita en
`P-ZRX/P-RNG/investigacion/INFORME.md`, ficha D: *«un lock asociado a la clave **o**, mejor, al
compromiso de parcela»* — lo nuevo es **invertir esa preferencia**, porque la segunda opción está parada.

**Pero abre una grieta, y es tu encargo medirla:** un granjero pequeño puede tener **saldo confiscable
cero**, y el atacante reclutaría precisamente esas claves. `P-ZRX/P-PRESTAMO/` resolvió el juego con una
pérdida **media**; con retención por clave lo que decide es la **distribución** y **a quién elige el
atacante**.

**Modelo de amenaza (de Katana, obligatorio):** se asume que un ente con mucha capacidad atacará. «No
compensa» **no es un argumento de seguridad**: entrega el **coste absoluto** de reclutar el espacio
necesario, además del relativo, y di qué parte del mecanismo lo vuelve **imposible** y cuál solo **caro**.

## 1 · Lo que ya está resuelto y NO se rehace

De `P-ZRX/P-PRESTAMO/investigacion/` (entregado, validado, y con su propia corrección ya aplicada):

- La superficie del umbral: `α* = (η_h − η_a·β_d − (η_h+η_a)·β_x)/(η_h+η_a)`; con `η = 1`,
  `α* = (1 − β_d − 2β_x)/2`. **Cada unidad de alquiler exclusivo baja el umbral el doble que una de
  doble farmeo.**
- **Dentro de la ventana de finalidad el ataque no prospera** salvo que se cruce la deriva; el mínimo
  medido es `8,53·10⁻²⁷⁷` y el salto a orden 1 ocurre **solo** al cruzar `g = 0`, que con `α = 0,33`
  exige `β_d > 0,5075`.
- La condición del castigo: `κ·q·(ρ_ret·ingreso·T_v + c_r + ingreso·M) > V/N`, y `T_v > F + margen`;
  desde `F ≈ 3.700` manda la restricción temporal.
- **No hay `(ρ_ret, T_v)` que valga** frente a `κ = 0` (publicar solo la rama ganadora), censura total o
  `V` sin cota.

**Tómalo como entrada.** Lo que cambia es que `ρ_ret · ingreso · T_v` deja de ser un número por granjero
y pasa a ser una **variable aleatoria** que depende de su tamaño y de su historia.

## 2 · Lo que hay que modelar

### 2.1 · El saldo confiscable como distribución

Un granjero con fracción `f` del espacio gana bloques a una tasa `∝ f`. Su saldo retenido en un instante
depende de `f`, de `ρ_ret`, de `T_v` y de **cuánto lleva farmeando**. Modela y publica:

- La distribución de saldo retenido en régimen, en función de `f`, y **la cola de los pequeños**: qué
  fracción del espacio total está en manos de claves con saldo confiscable por debajo de un umbral `b`.
- El **arranque**: un granjero nuevo tiene saldo cero durante `T_v`. ¿Qué fracción del espacio está
  siempre en ese estado, dado un churn `c` (entradas y salidas por unidad de tiempo)?
- La **varianza de los pequeños**: con `f` muy pequeño, ganar un bloque es un evento raro. Un granjero
  puede llevar meses sin ganar nada y tener saldo cero **sin ser nuevo**. Cuantifícalo: es la diferencia
  entre un modelo de flujo medio y la realidad.
- `f`, `ρ_ret`, `T_v`, `c` y la distribución de tamaños son **símbolos**: barre al menos una distribución
  de tamaños realista (declara cuál y por qué; si usas una ley de potencias, di su exponente y de dónde
  sale, y **marca la elección como hipótesis**).

### 2.2 · La estrategia del atacante: reclutar por el saldo

El atacante no recluta al azar: **elige**. Modela que ordena las claves por saldo confiscable creciente y
recluta hasta juntar el `β` que necesita. Publica:

- El **coste total** de reclutar un `β` dado, en unidades de **emisión de la red** (no en moneda), con y
  sin el filtro del saldo.
- **Cuánto abarata** elegir frente a reclutar al azar. Es el número que decide si la retención por clave
  sirve.
- Si existe un `β` **objetivo** (el que cruza la deriva, `β_d > 1 − 2α`) alcanzable **solo con claves de
  saldo cero**. Si existe, **la retención por clave no defiende ese caso** y hay que decirlo así.

### 2.3 · Identidades nuevas y fragmentación

Cambiar de clave **no rescata** el saldo ya bloqueado, pero permite empezar sin historial. Modela:

- Un atacante que **crea claves nuevas** y farmea con ellas desde el principio: nunca tiene saldo que
  perder. ¿Qué le cuesta, y en qué se diferencia de un granjero nuevo honesto? (Recuerda: las identidades
  son gratis por diseño — `research/dag-poas-balizas-auditoria.md`, teorema de identidad; **ábrelo**.)
- Un granjero que **fragmenta** su espacio entre muchas claves y arriesga solo las que usa para el
  atacante.
- Si alguna de las dos cosas se puede encarecer **sin** exigir registro de parcelas ni moneda previa. Si
  no se puede, **ese es el resultado**.

### 2.4 · El coste para el honesto

La regla cambiaría una conducta **hoy permitida**: tras un reorg, reutilizar el billete de la historia
abandonada (`SPEC.md` §7.2 — **ábrelo entero**: es contabilidad de reorg y **no** contradice la
infracción; el firmante seguro es lo que separa un caso del otro,
`P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md` §3). Cuantifica **qué pierde un granjero honesto
al abstenerse** en esos slots, como función de la tasa de reorg. Es el precio de la regla y tiene que
estar en la tabla.

## 3 · Las preguntas

**F1** · La distribución del saldo confiscable, y qué fracción del espacio tiene saldo por debajo de `b`.
**F2** · El coste de reclutar `β` eligiendo por saldo, en unidades de emisión, frente a reclutar al azar.
**F3** · ¿Existe un `β` que cruce la deriva alcanzable solo con claves de saldo cero o casi cero?
**F4** · ¿Se puede encarecer la creación de claves nuevas sin registro ni moneda previa? Si no, dilo.
**F5** · El coste para el honesto (§2.4), y la región `(ρ_ret, T_v)` que sobrevive **a la vez** a la
condición de `P-ZRX/P-PRESTAMO/` y a la grieta de los pequeños.
**F6** · **Frente a qué atacante no hay `(ρ_ret, T_v)` que valga.** Con el coste absoluto en hardware y
en emisión, no solo el relativo.

## 4 · El instrumento

`P-ZRX/P-CLAVE/investigacion/veritas/economia/retencion-clave-v1/`, estructura de LINEO §1. Referencia
exacta (`Rational{BigInt}` o intervalos) para las colas antes de cualquier aproximación normal: **con
granjeros pequeños la normal falla justo donde importa.** Si usas Monte Carlo: RNG por réplica con
semillas **no consecutivas** (las consecutivas de `StableRNG` sesgan el MC, hallazgo de
`P-ZRX/P-PUERTA/`), réplicas e IC declarados. **Un test que compara una fórmula consigo misma no es un
test.**

## 5 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-CLAVE/investigacion/`.** No edites ni muevas nada de `SPEC.md`, `TAREAS.md`,
`ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/`. En
`P-ZRX/P-CLAVE/` son de solo lectura `PROMPT.md`, `CANDIDATA.md` y `ENTRADA.sha256`. Al empezar y al
terminar, desde la raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-CLAVE/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`.

## 6 · Lecturas (ábrelas ENTERAS)

`veritas/LINEO.md` entero · `P-ZRX/P-CLAVE/CANDIDATA.md` entero ·
**`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` entero** y su `DECISIONES-PENDIENTES.md` ·
`P-ZRX/P-RNG/investigacion/INFORME.md` ficha D y §1 (la métrica `C_irr = C_inevitable + q_f·D_f`:
**reutilízala**) · `P-ZRX/P-EQUIVOCACION/investigacion/` (qué infracción es demostrable, `κ` y su
alcance: cubre el doble farmeo **publicado**) · `SPEC.md` §7.2 entero y `C-EMIT-05` (la madurez de
coinbase **solo retrasa el gasto**: no autoriza a confiscar) ·
`research/dag-poas-balizas-auditoria.md` (identidades gratis) · `research/README.md`.
Fuentes externas —SpaceMint §4 (penalización de recompensas diferidas **sin depósito previo**, y sus
límites declarados)—: **ábrela**; lo que no puedas verificar, «no verificada». **No inventes citas.**

**Advertencia de método, lección del 2026-09-21 en este repositorio:** dos errores el mismo día salieron
de leer una línea citada en vez del documento entero.

## 7 · Entregables (`P-ZRX/P-CLAVE/investigacion/`)

- `INFORME.md` — **primera línea = la respuesta**: si la retención por clave disuade, a quién no, y qué
  `(ρ_ret, T_v)` sobrevive. Después F1–F6.
- `DECISIONES-PENDIENTES.md` — las bifurcaciones reales para Katana.
- `PROGRESO.md` — bitácora con `date`, `uptime` y las comprobaciones de entrada y salida.
- El instrumento, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 8 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `medido`, `derivado`, `estimado`,
  `propuesto`, `no determinado`. **La distribución de tamaños que elijas es una hipótesis: dilo.**
- **No fijes** ningún parámetro de consenso ni precio: `ρ_ret`, `T_v`, `M`, `κ`, `V`, `c`, `f` son
  entradas. **Ningún resultado es una constante escrita a mano.**
- **No presentes una garantía económica como criptográfica**, ni una mitigación con palabras de cobertura.
- Cierra con **«Lo que esta investigación NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita, y Katana decide.
