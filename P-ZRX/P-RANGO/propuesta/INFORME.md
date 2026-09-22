# INFORME — P-RANGO: la compra de varianza se cierra **en forma**, no en valores; y P2/P3 siguen sin veredicto sobre una rama privada completa

**Respuesta.** El controlador de rango que `C-HDR-06` dejaba indefinido queda **redactado como
reglas** (`C-RET-01`…`C-RET-11`): ventana en índices de slot con cohorte sellada, conjunto de
referencia igual al conjunto pagable de `R-FIN-13′`, controlador entero con rejilla par que
**elimina el residuo de paridad**, arranque no fabricable y sin retroactividad para fusiones fuera
de ventana. Eso **cierra la vía por la que se compraba cola** con el mismo trabajo medio
(`P(adv>hon)` de `0,021302` a `0,314998` al dividir el rango por 64, cifras recalculadas de
CRP-v0.1). Lo que **no** cierra —y no puede cerrar por redacción— es el **veredicto** sobre una
rama privada completa: `ρ ∈ [1−δ,1+δ]` y la validación con pesos reales siguen **`<<PENDIENTE>>`**,
y ningún valor de consenso (`W`, `G`, `Q`, `γ`, `SR_MIN/MAX`, `R_inicial`, `δ`) se fija aquí.

---

## 1 · Por qué esta redacción cierra la compra de varianza

### 1.1 · El vector no era el umbral: era la varianza, y era una variable libre

CRP-v0.1 midió dos cosas distintas y conviene no mezclarlas:

- **La media no se mueve.** `α_mínimo = 1/2`, el mismo que PoW. La razón es exacta y está
  **verificada en fuente** en PCO-v0.1 `MODELO.md` §1.1: `SR` entra como `(SR+1)` en la tasa de
  bloques y como `1/(SR+1)` en el peso, y **el producto se cancela en todo instante**, con retarget
  convergido o no, con cualquier ventana y cualquier redondeo. La ventaja de fijar un rango bajo
  **no** aparece en el trabajo medio.
- **La cola sí.** Con el **mismo** trabajo medio (`E[trabajo_adv] = 180,0` en los cuatro `K`), fijar
  el rango bajo compra cola. Las cifras recalculadas —**las que manda usar el encargo**— son
  `P(adv > hon) = 0,021302 / 0,095029 / 0,227470 / 0,314998` para `K = 1 / 4 / 16 / 64`, con
  `α = 0,45` y `T = 400` (CIFRAS filas A11 y A12; convolución exacta validada contra Monte Carlo).

El problema de fondo era que **`R-FIN-13′` no estaba especificado**: el modelo trataba el
controlador como una **familia** y dejaba el `sr` **elegible** (CIFRAS, defecto D5). Mientras el
rango sea una variable libre, la cola es una variable libre. Eso es lo que la redacción ataca.

### 1.2 · Las cuatro piezas que la propuesta cierra

1. **La ventana deja de ser manipulable.** Se mide en **índices de slot absolutos** y en forma de
   **cohorte sellada** (`C-RET-01`, `C-RET-02`). Una rama privada ya no puede estirar ni encoger el
   intervalo que el controlador observa produciendo más o menos bloques, y el snapshot no se
   recalcula (sin retroactividad). Medir en bloques exigiría `λ` —estimada por el retarget— dentro
   del consenso, que es circular por la nota de `C-FIN-01`.
2. **El conjunto contado es el pagable y nada más** (`C-RET-03`). Contar de más no es inocuo:
   `R-FIN-13′` **mide** inflación del retarget **×1,452** contando azules sin selección por billete,
   frente a **×1,005** con el conjunto pagable. Contar bloques que no cobran ablanda el rango y
   **regala peso** a los que sí cobran.
3. **La aritmética deja de tener una elección escondida** (`C-RET-04`, `C-RET-05`). El redondeo es
   entero y explícito (más cercano, empates al cociente par), la salida vive en la **rejilla par** —
   con `SR` par, `A(SR) = SR+1` y el déficit de paridad `1/(SR+1)` **desaparece**, quedando solo el
   suelo `< 2^−64`— y el dominio queda acotado (`SR_MIN ≥ 2`, porque `SR = 0` da `w = 2^128`, fuera
   de `u128`, C-GD-01). **`medido`** en `RNG-v0.1`: identidad exacta, cota `< 2^−64` y el `1/2048`
   impar reproducido como ancla.
4. **El acoplamiento rango-validez / rango-peso se escribe** (`C-RET-08`). Sin él, el trabajo por
   slot se multiplica por `sr_val/sr_peso` **sin pagar espacio** (CIFRAS B1, exacto). Con él, la
   cancelación de §1.1 aplica, y **P3 en la media es un teorema**, no un objetivo.

Y encima, dos reglas que evitan que la cura abra un agujero nuevo: el **arranque no es fabricable**
(`C-RET-06`: cohortes indexadas por slot, Z0 como no-op, `R_inicial` de lanzamiento y no del
bloque) y la **fusión fuera de ventana no es retroactiva** (`C-RET-07`), con su condición de
corrección declarada en vez de supuesta.

### 1.3 · Por qué «en forma» y no «en valores» es la entrega correcta

El encargo §2 prohíbe fijar `W`, `γ`, `SR_MIN`, `SR_MAX`, los redondeos y el arranque, y `AGENTS.md`
prohíbe inventar un número para cerrar una regla. La **forma** del controlador es lo que elimina la
opcionalidad: la rejilla par mata la elección de paridad, la ventana absoluta mata la elección de
horizonte, el conjunto pagable mata la elección de qué cuenta y la deriva acotada por cohorte
(`C-RET-10`) es la que impide que el rango se vaya. Los valores que quedan son de **calibración**,
no de **vía de ataque**, y cada uno lleva escrito su criterio.

---

## 2 · Qué deja abierto

**Lo que queda abierto y bloquea un veredicto:**

1. **La validación de ramas candidatas con pesos reales** (`C-RET-11`). Es el pendiente que CRP-v0.1
   declaró **inconcluso** y sigue siéndolo. Mientras no exista el instrumento, P2 y P3 son
   **propiedades redactadas**, no veredictos. Criterio de cierre: rama privada completa con el
   controlador real en el bucle, rango recalculado (no declarado), pesos reales, distribución de
   `ρ` y cola `P(adv>hon)` con `α` y `T` declarados, referencia independiente y semilla fija.
2. **`δ`** (la cota de `ρ`). Sin el instrumento anterior no se puede calibrar.
3. **`G_slots` frente a `C-GD-11`.** Con la fusión fuera de ventana, la igualdad contado = pagado
   exige `merge_depth_slots ≤ G_slots`; la **métrica** del *bounded merge depth* (slots /
   `blue_score` / posiciones) y su **valor** siguen pendientes. Si se fija `G_slots` antes que
   `C-GD-11`, la condición se cumple o no por casualidad.
4. **La política de `Pending` frente a cierres posteriores.** Bloquear conserva la inmutabilidad y
   arriesga viveza (RCE-v0.1 declara la racha de `Pending` como `MetricPending`); saltar abre un
   hueco. No se cierra sin medir la racha bajo retención de cuerpos.
5. **Los valores:** `W_slots`, `G_slots`, `Q`, `a/d`, `p_lo/q_lo`, `p_hi/q_hi`, `SR_MIN`, `SR_MAX`,
   `R_inicial`, `retardos`, `δ`, `γ`. Candidatos históricos citados **solo como candidatos**:
   `W ≥ 3 083` con `γ ≤ 0,25` y `W ≥ 12 331` con `γ ≤ 1`; proceden de otra tasa y otra `F` y **no
   certifican este controlador** (aviso del propio SPEC).
6. **`UMBRAL_CHECKPOINT`** y la recalibración rango/espacio de `C-CHK` §12.1. No se derivan aquí.

**Lo que este trabajo no ha medido, y no debía:** no se repitió CRP-v0.1 (encargo §4). El
instrumento nuevo, `RNG-v0.1`, es de **aritmética de dominio y redondeo**: `A(SR)` contra un
oráculo independiente por enumeración, la identidad de la tasa por dos caminos exactos, el residuo
de paridad con la rejilla par, el dominio de `SR`, la anchura de la aritmética y la equivalencia
kernel/referencia del controlador. Nada de eso es una medida de seguridad.

---

## 3 · Trazabilidad de las cifras

| Cifra | Valor | Origen | Etiqueta |
|---|---|---|---|
| `P(adv>hon)`, `α=0,45`, `T=400`, `K=1/4/16/64` | 0,021302 / 0,095029 / 0,227470 / 0,314998 | CIFRAS A12 y B2 (convolución exacta; sustituyen a 0,022/0,097/0,244/0,308) | **medido** (modelo idealizado, controlador como familia) |
| `E[trabajo_adv]` en los cuatro `K` | 180,0 | CIFRAS A11 | **medido** |
| Amplificación por desacoplar `sr_val`/`sr_peso` | `s·(sr_val/sr_peso)`; 4,8 con `s=0,3`, razón 16 | CIFRAS B1 | **derivado/medido** |
| Inflación del retarget contando azules vs conjunto pagable | ×1,452 → ×1,005 | `research/dag-poas-ancla-de-orden.md`, `R-FIN-13′` | **medido en el instrumento de la regla** |
| `razón(SR) = 1 − O(2^−64)` (par); déficit `1/(SR+1)` (impar) | — | PCO-v0.1 `MODELO.md` §1.1 + `TAREAS.md` §2.3 | **verificado en fuente** |
| Déficit par máximo y `1/2048` impar | `< 2^−64`; `4,88·10^−4` | `RNG-v0.1` | **medido** |
| `w(0)=2^128 ∉ u128`; `w(2^64−1) ≥ 2^64` | — | C-GD-01 + `RNG-v0.1` | **verificado en fuente / medido** |
| `u256` basta sin precondición con entradas `u64`; `u128` no | `(2^64−1)^3 < 2^192 < 2^256` | `RNG-v0.1` | **medido/derivado** |

---

## Lo que esta propuesta NO resuelve

- **No fija ningún parámetro de consenso.** `W_slots`, `G_slots`, `Q`, `a/d`, los clamps, `SR_MIN`,
  `SR_MAX`, `R_inicial`, `retardos`, `γ` y `δ` quedan como símbolos con su criterio. Lo único que se
  fija por necesidad es `SR_MIN ≥ 2`, que es el borde del dominio que C-GD-01 ya declara.
- **No entrega el veredicto sobre P2/P3.** Sin el instrumento de validación de ramas candidatas con
  pesos reales, una rama privada completa no se puede comprobar; la propuesta lo declara
  `<<PENDIENTE>>` con criterio en lugar de reclamarlo.
- **No calibra `G_slots`**, porque depende de la métrica y del valor de `C-GD-11`, ambos pendientes.
- **No recalibra `C-CHK`** ni deriva `UMBRAL_CHECKPOINT`; solo declara la compatibilidad y la
  prohibición de que el checkpoint fije el controlador.
- **No toca el multistream de PoT**, ni `C-FLU-13`/`C-FLU-14`, ni la partición de flujo. El único
  vector medido que bajaba el umbral sigue siendo un escenario condicionado al diseño del flujo.
- **No arregla la viveza** bajo retención de cuerpos, ni el colateral honesto de `C-FLU-20`, ni la
  finalidad, ni el UTXO, ni el pruning.
- **No mejora el umbral.** Acota una vía de varianza; el `α_mínimo = 1/2` de media sigue donde
  estaba.
