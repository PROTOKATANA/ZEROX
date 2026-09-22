# PROPUESTA-SPEC — P-RANGO: el controlador de rango que cierra la compra de varianza

**Esto es una PROPUESTA. No se ha editado `SPEC.md` ni ningún otro documento del repositorio.
Nada de aquí es normativo hasta que Katana lo traslade formalmente.** Redactada el 2026-09-22 por el
agente DeepSeek del encargo `P-ZRX/P-RANGO/PROMPT.md` (solo lectura fuera de
`P-ZRX/P-RANGO/propuesta/`). Forma: plantilla de `P-ZRX/P-POT/propuesta/PROPUESTA-SPEC.md` y
`P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md`.

**Dónde encaja.** `C-HDR-06` (§6.1) exige
`rango_solucion(B) == rango_esperado(B) = controlador(past(B), flujo(B, slot(B)))` y declara que
«el algoritmo del controlador —ventana, bootstrap, redondeos y fusiones fuera de ventana— sigue en
`TAREAS.md` §2.3; no se define aquí». `TAREAS.md` §2.3, a su vez, enumera cinco pendientes y deja
abierto uno de los dos vectores medidos que mueven el umbral. Esta propuesta **redacta ese
controlador** como reglas `C-RET-xx` con la forma del SPEC.

**Etiquetas de afirmación** (reglas de validez del encargo §8):
- **`verificado en fuente`** — leído en el archivo citado (ruta desde la raíz) o en el
  identificador de regla citado; en particular, toda regla del SPEC se cita por su identificador y
  se abrió su sección completa, no una línea citada por otro informe.
- **`propuesto`** — texto nuevo de esta propuesta.
- **`derivado`** — consecuencia de definiciones ya escritas, con el paso intermedio escrito.
- **`medido`** — con el instrumento nombrado; aquí, `RNG-v0.1`
  (`P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1/`) o los instrumentos de `veritas/` que se
  citan con su nombre.
- **`no determinado por el SPEC`** — el SPEC vigente no lo fija.

**Vocabulario de símbolos.** `W_slots` (anchura de cohorte), `G_slots` (gracia causal), `Q`
(conteo objetivo por cohorte), `γ` (cota de deriva por cohorte), `p_lo/q_lo` y `p_hi/q_hi`
(clamps multiplicativos), `SR_MIN`, `SR_MAX`, `R_inicial`, `δ` (cota de `ρ`) y `D`/`retardos`
(activación diferida). **Ninguno recibe valor en esta propuesta**: todos van con su criterio de
elección escrito. **Excepción derivada, no elegida:** `SR_MIN ≥ 2`, porque `SR = 0` da
`w = 2^128`, que no cabe en `u128` (C-GD-01). No es un número inventado: es el borde del dominio
que C-GD-01 ya declara.

---

## 0 · Lo que manda el encargo, y una corrección de lectura que conviene decir antes

### 0.1 · Lo que no se reabre

Se conservan tal cual, y ninguna regla de esta propuesta los toca:

- **`C-HDR-06`**: el rango esperado es función **exclusiva** de `past(B)`. **MUST NOT** depender del
  orden de llegada, la punta local, el reloj, `timestamp`, `height` ni del propio `rango_solucion`
  del candidato; **la circularidad MUST ser imposible, no desaconsejada.**
- **`C-FLU-10`/`C-FLU-11`**: `flujo(B, s)` se **deriva** de `past(B)` y **MUST NOT** declararse.
- **`R-FIN-8′`/`R-FIN-13′`**: el conjunto que el retarget cuenta y el que la emisión paga son el
  mismo (azules y `rojo_k`; los `rojo_U3` no cuentan). Es un acoplamiento, no un parámetro.
- **`C-GD-08`**: `blue_work(B) = blue_work(sp(B)) + Σ w(x)` sobre los azules. El peso vive ahí.
- **El perfil 1a** (`C-FLU-01`) y **`C-FIN-01`**.

### 0.2 · Una lectura de P2 que hay que corregir para que no contradiga a `C-HDR-06`

`veritas/seguridad/coste-rama-privada-v1/PROPUESTA.md` P2 pide «anclar el conjunto de referencia del
retarget al **flujo canónico**, no al pasado privado». **Leído al pie de la letra —«que el controlador
mire la cadena honesta»— contradice a `C-HDR-06`**: el rango esperado **MUST** ser función exclusiva
de `past(B)`, y para una rama privada `past(B)` **es** el pasado privado. Un verificador no puede
leer bloques que no están en `past(B)`: no los tiene, y si los tuviera dejaría de ser función del
pasado del candidato. Etiqueta: **`derivado`** de `C-HDR-06` + `C-FLU-14`.

Lo que P2 **sí** puede exigir por regla, y es lo que esta propuesta redacta, son tres cosas
operativas:

1. **La ventana se mide en índices de slot absolutos del reloj de PoT**, no en bloques ni en
   posiciones de la rama. Una rama privada no puede estirar ni encoger el intervalo temporal que
   el controlador observa (`C-RET-01`, `C-RET-02`).
2. **El conjunto de referencia es exactamente el conjunto pagable de `R-FIN-13′`**: ni un bloque de
   más (contar `rojo_U3` o copias infla `λ_real` y regala peso), ni uno de menos
   (`C-RET-03`, `C-RET-07`).
3. **El flujo se deriva y nunca se declara**, y el controlador no lee nada que el candidato
   afirme (`C-RET-09`).

Lo que P2 **no** puede cerrar por regla —que una rama privada no obtenga un rango distinto del que
su espacio-tiempo acumulado justifica— es exactamente **P3**, y depende del **pinning** del
controlador (`C-RET-10`) y de la validación de ramas candidatas con pesos reales
(`C-RET-11`), que sigue **inconclusa** (CRP-v0.1, `INFORME.md` §9). Decirlo al revés —presentar
P2 como cerrada— sería repetir el patrón de etiqueta ancha sobre resultado estrecho.

### 0.3 · Lo que sí se puede demostrar hoy, y conviene decirlo primero

Con **P1** (mismo rango para validar y para pesar, `C-RET-08`) se tiene, **exacto**:

```text
tasa_peso(P, SR) = P · A(SR)/2^64 · ⌊2^128/(SR+1)⌋ = P · razón(SR)
razón(SR) = 1 − O(2^−64)                       (SR par; residuo = suelo)
razón(SR) = SR/(SR+1) − O(2^−64)               (SR impar; residuo = paridad)
```

**`verificado en fuente`**: PCO-v0.1 `MODELO.md` §1.1, con el predicado de aceptación leído del
código de Autonomys y `ρ(SR) = 2^128 mod (SR+1)`. **`medido`**: `RNG-v0.1` reproduce la identidad
por dos caminos independientes (producto y forma cerrada) con `Rational{BigInt}` y sin
discrepancias sobre 94 valores de `SR`.

Consecuencia, y es la clave de P3 en la media: **el trabajo de peso por slot no depende del `SR`
ni del historial del controlador**. `SR` entra como `(SR+1)` en la tasa de bloques y como
`1/(SR+1)` en el peso; el producto se cancela **en todo instante**, con retarget convergido o no,
con cualquier ventana y cualquier redondeo, porque `SR` es la misma variable en los dos factores.
Lo que el controlador tiene que acotar es la **segunda capa**: la varianza y la opcionalidad. Las
cifras medidas de esa capa, con el modelo idealizado de CRP-v0.1, son:

| `K = sr0/sr` | 1 | 4 | 16 | 64 |
|---|---:|---:|---:|---:|
| `P(adv > hon)`, `α = 0,45`, `T = 400` | **0,021302** | **0,095029** | **0,227470** | **0,314998** |
| `E[trabajo_adv]` | 180,0 | 180,0 | 180,0 | 180,0 |

**`medido`** (convolución exacta de dos Poisson compuestos, validada contra Monte Carlo de 40 000
réplicas con semillas no consecutivas; IC 99,9 % Hoeffding de una corrida de 4 000 réplicas
±0,052). Fuente: `P-ZRX/P-CRP1/auditoria/CIFRAS.md` filas A12 y A11, que **recalculan** las cifras
de CRP-v0.1 (0,022 / 0,097 / 0,244 / 0,308) y las sustituyen. **Se usan las recalculadas.**

**Salvedad obligatoria, sin la cual la tabla se leería de más:** esos números viven en un modelo
**idealizado** en el que el controlador es una **familia** y el adversario **puede fijar `sr` bajo**
(CIFRAS, defecto D5). Bajo `C-HDR-06` el productor **no elige** el rango: lo calcula el contexto.
La tabla **no predice** el comportamiento del controlador propuesto; mide **cuánto daño cabe** si el
controlador es permisivo. El encargo de esta propuesta es hacerlo no permisivo, y `C-RET-10`
es donde eso se escribe.

### 0.4 · Símbolos, unidades y el contrato de comparación

| Símbolo | Definición | Unidad | Estado |
|---|---|---|---|
| `SR(B)` | `rango_solucion(B)` = `rango_esperado(B)` (C-HDR-06) | entero, `u64` | campo de cabecera |
| `slot(B)` | índice de PoT (no el `timestamp` de cabecera; R-FIN-13) | entero, `u64` | campo de cabecera |
| `W_slots` | anchura de cohorte | índices de slot | **símbolo** |
| `G_slots` | gracia causal del corte | índices de slot | **símbolo** |
| `J_j`, `c_j` | cohorte y corte: `[jW, (j+1)W)`, `c_j=(j+1)W+G` | índices de slot | derivados |
| `N_j` | snapshot sellado del conjunto contado | bloques contados | derivado |
| `Q` | conteo objetivo por cohorte | bloques contados | **símbolo** |
| `a/d` | ganancia amortiguada (`0 < a ≤ d`) | racional entero | **símbolo** |
| `p_lo/q_lo`, `p_hi/q_hi` | clamps multiplicativos por cohorte | racional entero | **símbolo** |
| `γ` | `máx(p_hi/q_hi − 1, 1 − p_lo/q_lo)` | relativo por cohorte | derivado de los clamps |
| `SR_MIN`, `SR_MAX` | dominio global del rango | entero par | **símbolos con `SR_MIN ≥ 2`** |
| `R_inicial` | rango del arranque (Bootstrap B0) | entero par | **símbolo por red** |
| `ρ(B)` | espacio-tiempo justificado / atribuido por el controlador | adimensional | **símbolo `δ`** |

**Reglas de unidad, todas `verificado en fuente`:**
- Todo lo del flujo y de la finalidad se mide en **índices de slot** (`C-FLU-01`), nunca en bloques:
  convertir bloques en slots exige `λ`, que es una magnitud **estimada por el propio retarget**
  (nota de `C-FIN-01` en §12). **Meter `λ` en el consenso sería circular**, y es la razón por la que
  la ventana de `C-RET-01` no puede medirse en bloques.
- `w(B) = ⌊2^128/(SR+1)⌋` con división entera exacta; coma flotante **prohibida** (C-GD-01).
- `blue_work` es `u256` y toda suma es comprobada; desbordar es **fallo de consenso explícito**,
  nunca envoltura (C-GD-02, C-ENC-03).

---

## 1 · Reglas propuestas

### C-RET-01 · La ventana del retarget se mide en índices de slot y es absoluta — propuesto

El controlador de rango **MUST** observar una **cohorte** que es un intervalo fijo de índices de
slot del reloj de PoT:

```text
J_j := [ j · W_slots , (j+1) · W_slots )        j ≥ 0 entero
```

`W_slots` es un símbolo entero `> 0`. La cohorte **MUST NOT** medirse en número de bloques, en
`blue_score`, en posiciones de la cadena seleccionada, ni en ninguna magnitud que dependa de
cuántos bloques produjo la rama.

- **De dónde sale.** `C-FLU-01` fija que todo lo del flujo se mide en índices de slot de PoT; la
  nota de `C-FIN-01` (§12) demuestra que convertir bloques en slots exige `λ`, que el retarget
  estima: la conversión sería circular. `R-FIN-13` (`research/dag-poas-ancla-de-orden.md`) ya
  advierte que `slot` es el **índice de PoT**, no el sello de tiempo de la cabecera; con el sello el
  retarget es falsificable por *timewarp*. **`verificado en fuente`**; la forma de cohorte es
  **`propuesto`** siguiendo a RCE-v0.1/VRC-v0.1.
- **Qué la refuta.** Exhibir una rama legal en la que una ventana contada en bloques y esta ventana
  contada en slots den `N_j` distintos para el **mismo** espacio-tiempo acumulado y, con ello,
  rangos distintos. Alternativamente, mostrar que la versión en bloques es calculable sin `λ`.
  Ninguna de las dos cosas está hoy medida.
- **Por qué es «no manipulable por un pasado privado».** El intervalo es una función del `slot` del
  bloque y de `W_slots`, no de lo que la rama produjo. Una rama privada que produce poco **no
  ensancha** su ventana temporal: simplemente tiene menos bloques dentro.

### C-RET-02 · Cohorte, corte, sello inmutable y `Pending` — propuesto

```text
c_j := (j+1) · W_slots + G_slots                corte de la cohorte j
```

Al alcanzar la cadena seleccionada de `past(B)` el corte `c_j`, la cohorte `j` **MUST** sellarse una
sola vez y su snapshot `N_j` **MUST** ser inmutable. Consultar una cohorte sellada **MUST** devolver
el snapshot sellado, nunca un recálculo. `G_slots` es un símbolo entero `≥ 0`.

- Si al llegar al corte falta contexto (cuerpo, cabecera o pasado incompleto), el estado es
  **`Pending`**, y `Pending` **MUST NOT** contarse como cero: **cero no se sustituye por épsilon**.
  `Pending` bloquea el cierre de cohortes posteriores.
- El sellado **MUST** ser función del pasado validado (por composición con `C-GD-09`, que hace la
  cadena seleccionada función exclusiva de `past(B)`), y **MUST NOT** depender del orden de llegada,
  de la punta local ni del reloj.
- **De dónde sale.** Es el contrato de `veritas/consenso/retarget-causal-endogeno-v1/CONTRATO.md`
  (RCE-v0.1) y de `veritas/consenso/ventana-retarget-causal-v1/CONTRATO.md` (VRC-v0.1): cohortes
  `J_j`, corte `c_j`, snapshot sellado, `Pending` que no se vuelve cero, activación diferida.
  **`verificado en fuente`**; su validación estructural está medida por esos instrumentos (VRC:
  7 fixtures / 85 comprobaciones en referencia y kernel; RCE: 12 800 comparaciones exactas y
  coincidencia referencia/kernel). **`propuesto`** trasladarlo al SPEC como regla de consenso.
- **Qué la refuta.** Dos nodos con el **mismo** `past(B)` que obtengan `N_j` distinto; o un reorg
  que cambie un snapshot ya sellado (retroactividad); o un cierre que trate `Pending` como `0`.
  VRC-v0.1 conserva precisamente el contraejemplo L0 (`l0_postcierre_diverge`) para que nadie
  reintroduzca la segunda cosa por descuido.

### C-RET-03 · El conjunto contado es exactamente el conjunto pagable (`R-FIN-13′`) — propuesto

`N_j` **MUST** contar **exactamente** los bloques que cobran por `R-FIN-8′` dentro de la cohorte:
azules y `rojo_k`. En particular:

1. **MUST NOT** contar los `rojo_U3`.
2. **MUST NOT** contar dos copias del mismo billete: la identidad pagable es el billete y la
   selección es la de `C-ORD-02` (P1); a lo sumo una copia por billete.
3. **MUST NOT** contar un bloque que no cobre (copia con ventana de origen fuera de la historia:
   **inerte**, §7.2).
4. **MUST NOT** contar un bloque por el hecho de existir en `past(B)` sin ser azul ni `rojo_k`.

- **De dónde sale.** El invariante de `R-FIN-13′`: *«el conjunto que el retarget cuenta y el que la
  emisión paga son el mismo»*; `R-FIN-8′(1)` (cobran azules y `rojo_k`; un `rojo_U3` no cobra
  nada); `C-ORD-02` (una copia pagable por billete); §7.2 (copia inerte). **`verificado en fuente`.**
- **Qué la refuta, y por qué importa.** Exhibir una cohorte con `contado ≠ pagado`. El coste de
  contar de más está medido en la propia `R-FIN-13′`: contar solo azules sin selección por billete
  daba una **inflación del retarget ×1,452**; con el conjunto pagable, **×1,005**
  (`research/dag-poas-ancla-de-orden.md`, R-FIN-13′). Contar bloques que no cobran **ablanda** el
  rango y con ello **endurece** el peso de los que sí cobran: peso regalado sin espacio pagado.

### C-RET-04 · El controlador entero — propuesto

Con `R_j` el rango activo de la cohorte `j`, `N_j` el snapshot sellado y `Q` el conteo objetivo:

```text
num    = R_j · ( (d − a) · N_j + a · Q )          con 0 < a ≤ d
den    = d · N_j
R_raw  = redondeo_al_entero_mas_cercano(num, den)   (empates al cociente par)

R_par  = R_raw              si R_raw es par
         R_raw − 1          si R_raw es impar      (rejilla par, ver C-RET-05)

R_step = min( max( R_par , mayor_par( R_j·p_lo/q_lo ) ) ,
                  menor_par( R_j·p_hi/q_hi ) )

R_next = min( max( R_step , SR_MIN ) , SR_MAX )

Si N_j = 0:  R_next := R_j , no se agenda ninguna propuesta   (política Z0)
```

- La cohorte se cierra y la propuesta **MUST** agendarse con **activación diferida**: la primera
  frontera estrictamente posterior al corte, `b_j = (⌊c_j/W_slots⌋ + 1)·W_slots`, más
  `(retardos − 1)·W_slots`, con `retardos ≥ 1`. Si el sello llega en o después de esa frontera, el
  estado es `MissedUpdate` y **el rango se mantiene**: **MUST NOT** activarse retroactivamente.
- `N_j = 0` es **Z0: un no-op explícito.** Agendar una propuesta con el rango del sello y activación
  diferida **no es mantener, es revertir** (reimpone un valor obsoleto sobre evidencia real
  posterior). La cohorte vacía **sí** se sella y **sí** se registra.
- **De dónde sale.** La forma es la de RCE-v0.1 `CONTRATO.md` («controlador entero mínimo») y su
  `src/controlador.jl` — **`verificado en fuente`**, con `RoundFloor`/`RoundNearestEven` comparados
  y con la enmienda Z0 decidida por Katana el 2026-09-12 tras el hallazgo H1. Los clamps y la
  rejilla par son **`propuesto`** para ZEROX (la rejilla, por `C-RET-05`).
- **Qué la refuta.** Una configuración de ensayo en la que la fórmula salga del dominio y el
  controlador lo oculte (saturación silenciosa); o una variante de Z0 que revierta; o dos
  implementaciones que redondeen distinto en un empate. `RNG-v0.1` compara kernel `u128` contra
  referencia `BigInt` en 2 040 casos (rejilla de regresión + 2 000 aleatorios con semilla fija) y **no encontró
  discrepancias**; eso refuta la equivalencia de **una** implementación, no la corrección de la
  regla.

### C-RET-05 · Redondeos, residuo de paridad y dominio — propuesto

1. **Aritmética entera y comprobada.** Todo el cálculo **MUST** ser entero; usar coma flotante está
   **prohibido** (C-GD-01, C-ENC-04). Un desbordamiento es **fallo de consenso explícito**, nunca
   envoltura ni saturación (C-GD-02, C-ENC-03).
2. **Rejilla par: `SR` esperado MUST ser par.** El controlador devuelve el mayor entero par `≤` el
   valor redondeado (`R_par`), y `SR_MIN`/`SR_MAX` son pares.
3. **El residuo de paridad se elimina por construcción.** Con `SR` par, `A(SR) = SR+1` y
   `1 − razón(SR) = (2^128 mod (SR+1))/2^128 < 2^−64`, porque `SR+1 ≤ 2^64`. El controlador
   **MUST NOT** devolver nunca un `SR` impar: hacerlo reintroduce el déficit `1/(SR+1)`
   **elegible** que `TAREAS.md` §2.3 anota.
4. **Dominio.** `SR_MIN ≥ 2`, par. `SR = 0` da `w = 2^128`, que **no cabe en `u128`** (C-GD-01);
   no es un valor representable y **MUST NOT** ser alcanzable. `SR_MAX ≤ 2^64 − 1`, par.
5. **Anchura.** El cálculo **MUST** declarar la anchura entera `w` con la que opera y **MUST**
   verificar `SR_MAX · d · N_max < 2^w` **antes** de usarla. Con entradas `u64`, `u256` basta
   **sin precondición**: `SR_MAX·d·N_max < 2^64·2^64·2^64 = 2^192`. Si una implementación usa
   `u128`, **MUST** verificar la precondición de RCE-v0.1
   (`SR_MAX·d·typemax(u64) ≤ typemax(u128)`) o rechazar la configuración.
6. El resultado **MUST** caber en `u64`; fuera de dominio, **fallo explícito**.

- **De dónde sale.** `SR = 0 → 2^128` y `w ≥ 2^64` son C-GD-01; `u256` es C-GD-02; la aritmética
  comprobada es C-ENC-03. El **residuo de paridad** está **`verificado en fuente`** en PCO-v0.1
  `MODELO.md` §1.1 y anotado en `TAREAS.md` §2.3; el **`A(SR)`** en `MODELO.md` §1.1. La
  afirmación «la rejilla par lo elimina y solo queda el suelo» está **`medido`** en `RNG-v0.1`:
  déficit par máximo observado `< 2^−64` (identidad exacta `ρ/2^128` comprobada término a término) y
  déficit impar `1/2048 = 4,88·10^−4` en `SR = 2047`, exactamente la cifra de `TAREAS.md` §2.3.
  La suficiencia incondicional de `u256` y la **necesidad** de la precondición en `u128` están
  **`medidas`** en `RNG-v0.1` (`(2^64−1)^3 < 2^192 < 2^256`, `UInt128` desborda de verdad, y una
  configuración fuera de precondición es **rechazada**, no saturada).
- **Qué la refuta.** Exhibir un `SR` par con déficit `≥ 2^−64`; o una configuración `u64` en la que
  `u256` desborde; o un redondeo propuesto que haga que dos implementaciones correctas devuelvan
  paridades distintas para el mismo `past(B)`.
- **Lo que este punto decide y lo que deja como símbolo.** Decidido: **modo de redondeo**
  (entero más cercano, empates al cociente par) y **paridad par**. Símbolos: `W_slots`, `G_slots`,
  `Q`, `a/d`, `p_lo/q_lo`, `p_hi/q_hi`, `SR_MIN`, `SR_MAX`, `R_inicial`, `retardos`.

### C-RET-06 · Arranque por red (Bootstrap B0) — propuesto

1. **Mientras no se haya cerrado la primera cohorte completa**, el rango activo **MUST** ser
   `R_inicial`, un **parámetro de lanzamiento por red** (§15.2), par y en `[SR_MIN, SR_MAX]`.
2. `R_inicial` **MUST NOT** poder declararlo un bloque: vive en los parámetros de la red y el
   candidato no lo aporta (misma exigencia que `C-HDR-06`).
3. **El arranque no es fabricable por un atacante.** Como las cohortes se indexan por **índices de
   slot absolutos**, el número de cohortes transcurridas es función de `slot`, no de cuántos
   bloques produjo la rama. Retener bloques **no acorta, no reinicia y no salta** el arranque; una
   cohorte sin bloques es Z0: el rango se mantiene y la ventana se sella y se registra.
4. **Relación con `C-CHK` (§12.1), declarada y no resuelta.** `C-CHK-02` admite un checkpoint solo
   si el `rango_solucion` de su bloque es `≤ UMBRAL_CHECKPOINT`, y el rango **estrecha al crecer la
   red**: durante el arranque, con `R_inicial`, no hay checkpoint admisible. El controlador
   **MUST NOT** ser función del checkpoint y el checkpoint **MUST NOT** fijar el controlador. La
   recalibración rango/espacio que §12.1 exige sigue pendiente y **no se hace aquí**.
5. `<<PENDIENTE>>` **`R_inicial` por red** (criterio: el rango del génesis, fijado en los
   parámetros de lanzamiento de §15.2, par y dentro del dominio) y **`UMBRAL_CHECKPOINT`** (no se
   deriva de este controlador; §12.1 prohíbe la conversión antigua con denominador 120).

- **De dónde sale.** El Bootstrap B0 (mantener `R_inicial` hasta cerrar la primera ventana) es de
  RCE-v0.1 `CONTRATO.md` — **`verificado en fuente`**. `C-CHK-01`…`C-CHK-07` y la advertencia de
  recalibración de §12.1 — **`verificado en fuente`**. La no-fabricabilidad por índices de slot es
  **`derivado`** de `C-RET-01` + Z0.
- **Qué la refuta.** Exhibir un `past(B)` legal que obtenga un rango distinto de `R_inicial` antes de
  la primera cohorte sellada; o un checkpoint cuyo bloque tenga un rango que el controlador no
  produce; o un mecanismo por el que retener bloques cambie el número de cohortes transcurridas.

### C-RET-07 · Fusiones fuera de ventana — propuesto

1. **No hay retroactividad.** Un bloque cuyo `slot` cae fuera de `J_j` **MUST NOT** entrar en la
   cohorte `j`, ni antes ni después de su sello, y un bloque fusionado **después** del cierre de la
   cohorte de su `slot` **MUST NOT** alterar el snapshot sellado. No se cuenta en ninguna cohorte:
   su ventana ya pasó.
2. **Condición de corrección `contado = pagado`.** Para que ningún bloque pagable quede sin contar,
   la gracia **MUST** cubrir la profundidad máxima de fusión de `C-GD-11`:

   ```text
   merge_depth_slots ≤ G_slots          (condición de CORRECCIÓN, no de rendimiento)
   ```

   **Derivación, para que la condición no parezca arbitraria.** Sea `X` con `slot(X)` en `J_j` y
   sea `B` el bloque de cadena que lo fusiona, con `slot(B) = s_B`; `X` cobra en `B`. Para que `X`
   cuente, tiene que estar en la cadena sellada antes del corte `c_j = (j+1)·W_slots + G_slots`.
   El peor caso es el último slot de la cohorte, `slot(X) = (j+1)·W_slots − 1`. Si la profundidad
   de fusión está acotada en **slots** por `merge_depth_slots`, entonces
   `s_B ≤ slot(X) + merge_depth_slots ≤ (j+1)·W_slots − 1 + merge_depth_slots`, y basta
   `merge_depth_slots ≤ G_slots` para que `X` esté incorporado **estrictamente antes** del corte.
   `merge_depth_slots` es la métrica de `C-GD-11` **todavía pendiente** (slots / `blue_score` /
   posiciones) y su valor también lo está; si su métrica no es el slot, la conversión exige el
   mismo cuidado que `C-RET-01` prohíbe en la ventana. La condición se escribe en símbolos.
   **Nota:** el retardo por **cuerpo retenido** (DA0) no lo cubre `G_slots` ni debe cubrirlo: eso
   es `Pending`, y `C-RET-02` ya impide cerrar la cohorte mientras falte contexto.
3. Una copia cuya ventana de origen no es la ventana de la historia que la fusiona **MUST** ser
   **inerte**: no cobra, no cuenta y no aplica sus transacciones (§7.2). Es una de las dos guardas
   independientes de la inercia por fusión posterior.
4. Un bloque tardío que **cambiaría un ancla ya activada** sigue la política de `C-FLU-20` y queda
   **infusionable para siempre** en ese flujo; el controlador **MUST NOT** abrir una vía de rescate
   por la vía del rango. El colateral honesto de `C-FLU-20` **no está medido** (`TAREAS.md` §2.9)
   y esta propuesta no lo mide.

- **De dónde sale.** El contraejemplo **L0** de VRC-v0.1 —una cohorte que paga después de sellarse,
  con `counted_ids != payable_ids`— y su condición suficiente entera `G ≥ W_adm`
  (`ventana-retarget-causal-v1/CONTRATO.md`) — **`verificado en fuente`**. `C-GD-11` (*bounded merge
  depth*) es el único límite que acota la profundidad de fusión: `mergeset_size_limit` acota el
  tamaño y `S_max` la distancia al padre seleccionado, y ninguno toca un bloque viejo que entra
  sumando 1 — **`verificado en fuente`** en la propia regla y en su comentario. §7.2 fija la copia
  inerte — **`verificado en fuente`**.
- **Qué la refuta.** Exhibir un bloque pagable cuyo `slot` quede fuera de la cohorte de **todos** los
  bloques de cadena que podrían fusionarlo (es decir, `merge_depth_slots > G_slots`); o un reorg que
  cambie un `N_j` sellado; o un mecanismo por el que una fusión tardía cuente dos veces.
- **Nota de dependencia, dicha en voz alta.** Esta regla **hereda el pendiente de `C-GD-11`**: sin
  métrica ni valor de `merge_depth`, `G_slots` no se puede cerrar. Se declara aquí para que nadie
  fije `G_slots` «a ojo» y dé por buena una igualdad contado/pagado que no lo es.

### C-RET-08 · Acoplamiento rango-validez / rango-peso (P1) — propuesto como invariante explícito

1. El rango que pondera `w(B)` **MUST** ser **el mismo** campo `rango_solucion(B)` que se compara
   con `solution_distance(B)` en `C-HDR-06`. **MUST NOT** existir un segundo rango de cómputo de
   peso: ni una re-derivación, ni un clamp distinto, ni una caché con semántica propia.
2. La comprobación **MUST** ocurrir **antes** de que el peso se use: `w(B)` **MUST NOT** calcularse
   a partir de un `rango_solucion` no validado.
3. El retarget **MUST NOT** leer ningún rango declarado por un candidato; y ningún productor
   **MUST** sustituir el cálculo contextual por su propio valor.
4. La regla se escribe **aunque `C-GD-01` + §7.1 ya la impliquen**: es exactamente el tipo de
   acoplamiento que una implementación rompe «optimizando» (calcular el peso con un rango cacheado
   o con el de otra cohorte).

- **De dónde sale.** P1 de `veritas/seguridad/coste-rama-privada-v1/PROPUESTA.md`
  (**`verificado en fuente`**) y `C-GD-01` + `C-GD-08` (`w(B)` y `blue_work`) — **`verificado en
  fuente`**. Es también la condición bajo la que rige la cancelación de §0.3.
- **Qué la refuta, con la cifra.** Exhibir una ruta en la que el rango que pesa (`sr_peso`) difiera
  del que valida (`sr_val`). Entonces el trabajo por slot se multiplica por `sr_val/sr_peso` **sin
  pagar espacio**: exacto `s·(sr_val/sr_peso)`; con `s = 0,3` y `sr_val/sr_peso = 16` da **4,8×**
  (CIFRAS fila B1, recalculada por aritmética exacta sobre el instrumento CRP-v0.1). Ese es el
  listón que una refutación de P1 tiene que batir.

### C-RET-09 · Anclaje al flujo canónico y circularidad imposible (P2, piezas operativas) — propuesto

1. `rango_esperado(B)` **MUST** calcularse como `controlador(past(B), flujo(B, slot(B)))`, con
   `flujo` el de `C-FLU-10`, **derivado** del pasado y **MUST NOT** declarado (`C-FLU-11`).
2. El controlador **MUST NOT** depender del orden de llegada, de la punta local, del reloj local,
   del `timestamp`, del `height` declarado, ni del `rango_solucion` que declara el candidato. **La
   circularidad MUST ser imposible, no desaconsejada** (`C-HDR-06`).
3. La pertenencia a la cohorte **MUST** ser función de `slot(X)` y de `slot(B)`, nunca de cuándo
   llegó `X` ni de dónde lo colocó la rama. Esto es lo que hace la ventana **no manipulable por un
   pasado privado** en el único sentido que `C-HDR-06` permite (ver §0.2).
4. La coherencia de flujo del pasado la exige `C-FLU-14` como **validez estructural**, anterior a
   cualquier PoT; el controlador **MUST NOT** re-verificarla por su cuenta ni aceptar un flujo del
   candidato.

- **De dónde sale.** `C-HDR-06`, `C-FLU-10`, `C-FLU-11`, `C-FLU-14` — **`verificado en fuente`**.
  La lectura operativa de P2 está argumentada en §0.2 — **`derivado`**.
- **Qué la refuta.** Exhibir dos nodos con el mismo `past(B)` que calculen rangos distintos; o una
  ruta en la que el valor declarado por el candidato influya en el controlador; o una rama legal que
  cambie la ventana observada sin cambiar su espacio-tiempo (p. ej. contando por bloques).

### C-RET-10 · *Pinning* de la tasa de la rama (P3) — propuesto

1. **Deriva acotada por cohorte.** El cociente entre rangos activos consecutivos **MUST** estar
   acotado:

   ```text
   R_{j+1} / R_j ∈ [ p_lo/q_lo , p_hi/q_hi ]        con p_lo ≤ q_lo, p_hi ≥ q_hi
   γ := máx( p_hi/q_hi − 1 , 1 − p_lo/q_lo )        cota de deriva por cohorte
   ```

2. **Invariante de atribución.** Sea `ρ(B)` la razón entre el espacio-tiempo que la rama de `B`
   justifica y el que el controlador le atribuye. El controlador **MUST** mantener
   `ρ ∈ [1−δ, 1+δ]` con `δ` acotado y declarado, y **MUST NOT** permitir `ρ` grande.
3. **Equivalente operativo, y lo que ya está demostrado:** el trabajo acumulado por slot
   `d·blue_work/d slot ≈ s·λ0·w(sr0)` **MUST** depender solo de la fracción de espacio `s`, no del
   historial de `sr`. **En la media esto es un teorema**, no un objetivo: es la cancelación de
   §0.3, exacta y válida con cualquier retarget, ventana y redondeo, **siempre que se cumpla P1
   (`C-RET-08`)**. La salvedad está en `MODELO.md` §1.2 de PCO-v0.1: `razón(SR) ≈ 1` da
   `tasa_blue_work ∝ β·W`, y `∝ W` exacto **si y solo si `β₁ = β₂`**; la fracción azul `β` depende
   de la estructura del DAG, no del historial de rango.
4. **Lo que el controlador tiene que acotar es la segunda capa:** `δ`, la varianza y la
   opcionalidad. `γ` es el instrumento; `δ` es el contrato.
5. `<<PENDIENTE>>` **`W_slots`, `G_slots`, `Q`, `a/d`, `p_lo/q_lo`, `p_hi/q_hi`, `δ`**, cada uno con
   su criterio: `W_slots` y `Q` de la varianza admitida y del coste de reacción; `a/d` del
   compromiso entre velocidad de convergencia y estabilidad; los clamps de `γ` frente a la cola
   medida; `δ` de la cola de `ρ` que se declare aceptable. **No se fijan aquí.** Los candidatos
   históricos `W ≥ 3 083` con `γ ≤ 0,25` y `W ≥ 12 331` con `γ ≤ 1` se citan **solo como
   candidatos**: proceden de otra tasa y otra `F`, y el propio SPEC avisa de que **no certifican
   este controlador**.

- **De dónde sale.** P3 de `PROPUESTA.md` — **`verificado en fuente`**. La cancelación exacta y la
  salvedad de `β`: PCO-v0.1 `MODELO.md` §1.1–§1.2 — **`verificado en fuente`** y **`medido`** por
  `RNG-v0.1` (dos caminos independientes, `Rational{BigInt}`). Los clamps por cohorte son de
  RCE-v0.1 — **`verificado en fuente`**. La cita de los candidatos históricos, con su etiqueta, es
  del propio encargo §2 y de §7.2 del SPEC — **`verificado en fuente`**.
- **Qué la refuta, con la cifra.** Exhibir una rama privada completa, con el controlador **real**
  en el bucle, cuyo `ρ` salga de `[1−δ, 1+δ]`; o una configuración de `γ`/`W`/`Q` que reproduzca la
  compra de cola. La magnitud a batir, en el modelo **idealizado** de CRP-v0.1 (donde el adversario
  sí puede fijar `sr`), es `P(adv>hon)`: **0,021302 → 0,314998** al dividir el rango por 64, con
  `α = 0,45`, `T = 400` y **el mismo trabajo medio** (`E[trabajo_adv] = 180,0` en los cuatro `K`).
  Si el controlador propuesto deja que `ρ` se salga, esa tabla es el daño que cabe.

### C-RET-11 · Validación de ramas candidatas con pesos reales — **PENDIENTE declarado**

1. **Lo que ya es exigible por regla.** Al validar una cadena candidata, el nodo **MUST** recalcular
   el controlador sobre el pasado **de esa candidata** y comprobar `rango_solucion == rango_esperado`
   bloque a bloque (C-HDR-06), y **MUST** recalcular `blue_work` con **pesos reales**
   `w = ⌊2^128/(SR+1)⌋` (C-GD-08), no con etiquetas ni con pesos suministrados. Las ventanas de §6.5
   y §7.3 **MUST** recorrerse hacia atrás siguiendo `prev_hash` desde el candidato, nunca desde
   estructuras indexadas por altura de la cadena activa (`C-REORG-06`).
2. **Lo que sigue abierto, y se declara en vez de fingirse cerrado.** Comprobar que una rama privada
   **no** obtiene más `blue_work` del que su espacio-tiempo justifica exige un instrumento que
   construya una rama privada completa con el controlador **real** (no una familia), recalcule su
   historial de rangos cohorte a cohorte, y mida la distribución de `ρ` y la cola `P(adv > hon)`
   bajo el **mismo** riesgo y escenario. Hoy **no existe**.

   ```text
   <<PENDIENTE: instrumento de validación de ramas candidatas con pesos reales>>
   Criterio de cierre: (a) rama privada con el controlador de C-RET-04 en el bucle;
   (b) rango recalculado desde el pasado de la rama, no declarado;
   (c) pesos reales C-GD-01/C-GD-08; (d) reporte de la distribución de ρ y de P(adv>hon)
       con α y T declarados, contra la rama honesta bajo el mismo escenario;
   (e) referencia independiente y semilla fija.
   Mientras no exista: P2/P3 quedan PROPIEDADES REDACTADAS, no veredictos.
   ```

3. **El escenario que hay que meter en ese instrumento, y que `TAREAS.md` §2.9 ya nombra.** El
   pendiente no es solo «una rama privada»: el ataque que va **directamente contra P2** es el
   **equilibrio adaptativo** —partir a los honestos en dos mitades y sostener el empate—, que
   `TAREAS.md` §2.9 (a) declara **no medido** («el equilibrio adaptativo no está medido, y es el
   ataque que va directamente contra (P2), que es donde descansa toda la seguridad del perfil 1a»;
   lo medido es A3 **estática**). El instrumento de cierre **MUST** incluir esa variante
   adversarial, no solo una rama privada pasiva. Además, la `Δ` de todo lo anterior es
   **simulada** (DMS-v0.1), no medida en red (§2.9 (a).6), así que el resultado hereda esa
   etiqueta.

- **De dónde sale.** `TAREAS.md` §2.3 enumera este pendiente como uno de los cinco; CRP-v0.1
  `INFORME.md` §9 lo declara **inconcluso** («la curva corta de ZEROX con controlador **real** (no
  una familia) no puede cerrarse hasta especificar ventana, arranque, redondeos y validación de
  ramas candidatas con pesos reales»). CIFRAS lo confirma por la vía del defecto **D5**: las cifras
  de la tabla de §0.3 son de un modelo con el controlador como familia. `C-REORG-06` es del SPEC —
  **`verificado en fuente`**.
- **Qué la refutaría.** El instrumento del bloque de arriba, con `ρ` dentro de `[1−δ,1+δ]` y una cola
  no peor que la honesta para el mismo `α` y `T`. Hasta entonces, **P2 y P3 no están comprobadas
  sobre una rama privada completa**, y decir lo contrario sería exactamente el defecto que
  `P-ZRX/P-CRP1/auditoria/CIFRAS.md` documenta (filas B2, A29: etiquetas anchas sobre resultados
  estrechos).

---

## 2 · Trazabilidad: qué cierra cada regla

### 2.1 · Las tres propiedades MUST de `PROPUESTA.md`

| Propiedad | Dónde se redacta | Estado |
|---|---|---|
| **P1** acoplamiento rango-validez / rango-peso | `C-RET-08` (+ `C-RET-09.2`) | **redactada**; refutable con la cifra de CIFRAS B1 |
| **P2** anclaje al flujo canónico, ventana no manipulable | `C-RET-01`, `C-RET-02`, `C-RET-03`, `C-RET-09` | **redactada**; la parte «ρ acotado» es P3 y sigue **pendiente** |
| **P3** *pinning* de la tasa de la rama | `C-RET-10` (+ `C-RET-04` clamps) | **redactada** en la media (**demostrada** vía PCO §1.1); la varianza (`δ`) **`<<PENDIENTE>>`** |

### 2.2 · Los cinco pendientes de `TAREAS.md` §2.3

| Pendiente | Regla | Cómo se cierra o se declara |
|---|---|---|
| Ventana (`W`) | `C-RET-01`, `C-RET-02` | magnitud **decidida** (índices de slot, cohorte); valor **símbolo** |
| Arranque por red | `C-RET-06` | forma **decidida** (B0, no fabricable, relación con `C-CHK`); valores **símbolos** |
| Límites y redondeos | `C-RET-04`, `C-RET-05` | redondeo y paridad **decididos**; dominio **acotado**; valores **símbolos** |
| Fusiones fuera de ventana | `C-RET-07` | no retroactividad **decidida**; condición `merge_depth ≤ G` **declarada pendiente de `C-GD-11`** |
| Validación de ramas candidatas con pesos reales | `C-RET-11` | **`<<PENDIENTE>>` declarado**, con criterio de cierre; era el pendiente inconcluso de CRP-v0.1 |

### 2.3 · Lo que la propuesta **no** reabre (comprobación de alcance)

- No se edita `SPEC.md` ni `TAREAS.md` ni ningún otro documento fuera de
  `P-ZRX/P-RANGO/propuesta/`.
- No se fija `W`, `G`, `Q`, `a/d`, `p_lo/q_lo`, `p_hi/q_hi`, `SR_MIN`, `SR_MAX`, `R_inicial`,
  `γ`, `δ` ni `retardos`.
- No se reutiliza ningún identificador retirado. **La familia `C-RET` está libre**: se ha
  comprobado que `C-RET-*` no aparece en `SPEC.md` ni en `TAREAS.md`; `C-DIFF-*` es el retarget
  lineal LWMA-1 —**de otra cosa**, y no se copia sin decir qué cambia— y `C-FORK-01`…`C-FORK-04`
  están retirados y no se reciclan.

---

## 3 · Lo que esta propuesta NO resuelve

- **Los valores.** `W_slots`, `G_slots`, `Q`, `a/d`, los clamps, `SR_MIN`, `SR_MAX`, `R_inicial`,
  `γ`, `δ` y `retardos` van como símbolos con su criterio de elección escrito. Fijarlos exige las
  mediciones de §7.3 y de `TAREAS.md` §3, que no existen.
- **La validación de ramas candidatas con pesos reales** (`C-RET-11`). Sin ella, P2 y P3 son
  **propiedades redactadas**, no veredictos.
- **La calibración de `G_slots` frente a `C-GD-11`.** Depende de la métrica y del valor del *bounded
  merge depth*, ambos pendientes. Sin `merge_depth_slots ≤ G_slots`, la igualdad contado = pagado
  puede romperse por una fusión tardía.
- **La recalibración rango/espacio de `C-CHK`** (§12.1) y la relación de `UMBRAL_CHECKPOINT` con el
  controlador. Aquí solo se declara la compatibilidad; no se deriva ningún valor.
- **El multistream de PoT.** No lo toca esta propuesta: `C-FLU-13` (validez absoluta) y `C-FLU-14`
  (pasado consistente de flujo) son anteriores y ajenos. El único vector medido que bajaba el umbral
  sigue siendo un escenario condicionado al diseño del flujo, no un resultado de este controlador.
- **El colateral honesto de `C-FLU-20`** y la **viveza bajo retención de cuerpos** (RCE-v0.1 la
  declara `MetricPending`): el controlador no las arregla.
- **La reconciliación de la finalidad** (`C-FIN-01` vs `C-REORG-07`), el **estado UTXO** sobre el
  orden, y el **pruning**: fuera de alcance.
- **Toda afirmación sobre el umbral.** Esta propuesta no publica un `α_mínimo` nuevo ni mejora el
  `1/2` de media. Acota una vía de **varianza**; no promete un umbral mejor.
