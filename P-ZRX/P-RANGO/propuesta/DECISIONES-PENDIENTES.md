# DECISIONES-PENDIENTES — P-RANGO

Las siete decisiones de diseño que el encargo §3 pide resolver. Cada una se presenta con **lo que
gana, lo que paga y lo que cierra** cada opción, y con mi recomendación marcada. **Ninguna fija un
valor de consenso**: las que se cierran lo hacen en **forma** (magnitud, conjunto, redondeo,
invariancia); las que no se pueden cerrar sin una medición quedan **`<<PENDIENTE>>` con su
criterio**.

**Lo que ya está decidido por el encargo y no se reabre** (encargo §2): `C-HDR-06` tal cual,
`C-FLU-10`/`C-FLU-11`, `R-FIN-8′`/`R-FIN-13′`, `C-GD-08`, el perfil 1a y `C-FIN-01`.

---

## D-1 · La ventana: unidad y forma

**Qué decide.** En qué magnitud se mide la ventana del retarget y si es deslizante o una cohorte
sellada. Decide también si hace falta `λ` dentro del consenso.

**Subdecisión 1a — unidad: índices de slot (A) frente a bloques (B).**

- **A — índices de slot del reloj de PoT.**
  - **Gana:** coherencia con todo lo que ya cuenta en slots (`C-FLU-01`, `C-FIN-01`); el intervalo
    es absoluto, así que **una rama privada no puede estirarlo ni encogerlo**; el `slot` es
    infalsificable, mientras que el `timestamp` de cabecera no lo es (R-FIN-13: con el sello de
    tiempo el retarget es falsificable por *timewarp*).
  - **Paga:** hay que definir la cohorte sobre un reloj que puede tener **más slots que bloques**
    (a `τ = 1 s` y `λ = 1 bloque/s` nominales coinciden, pero `C-GD-04` admite saltos de hasta
    `S_max_slots`; `TAREAS.md` §2.9 y §3.3 dejan `τ` y `λ` como decisión de diseño).
  - **Cierra:** la posibilidad de que la rama elija su propia ventana produciendo más o menos
    bloques.
- **B — bloques.**
  - **Gana:** ninguna ventaja de corrección; cuenta lo que ya está en `past(B)` sin hablar de reloj.
  - **Paga:** convertir bloques en slots —o al revés— exige `λ`, que es una magnitud **estimada por
    el propio retarget**: meterla en el consenso es **circular** (nota de `C-FIN-01` en §12). Y una
    ventana contada en bloques **sí** la controla la rama: producir poco la alarga en el tiempo.
  - **Cierra:** la independencia de la ventana respecto de la producción de la rama.

**Recomendación: A.** Cierra la decisión (la unidad queda fijada en `C-RET-01`). `W_slots` queda
como símbolo.

**Subdecisión 1b — forma: cohorte sellada (A) frente a ventana deslizante (B).**

- **A — cohorte `J_j = [jW, (j+1)W)` con corte, sello y activación diferida.**
  - **Gana:** **snapshot inmutable** y por tanto una función limpia de `past(B)`; `Pending` y
    `MissedUpdate` bien definidos; Z0 (cohorte vacía) como no-op explícito; y la igualdad
    contado = pagado se puede **verificar por cohorte** con la condición `G ≥ W_adm` (VRC-v0.1).
    Ya está implementada y validada **estructuralmente** en VRC-v0.1 (7 fixtures, 85
    comprobaciones referencia+kernel, test Rust) y en RCE-v0.1 (12 800 comparaciones exactas,
    referencia == kernel).
  - **Paga:** **retardo de reacción** de hasta ~`W + retardos·W` slots; y si `Pending` bloquea
    cierres posteriores, una retención de cuerpos puede **congelar** el controlador — RCE-v0.1 lo
    declara `MetricPending` y **no** lo convierte en cero.
  - **Cierra:** la reacción rápida dentro de la misma cohorte y la posibilidad de recalcular sin
    sello.
- **B — ventana deslizante de `W` slots terminando en `slot(B)`.**
  - **Gana:** reacciona antes y usa toda la información hasta `slot(B)`.
  - **Paga:** cada bloque recalcula `N_obs` sobre su ventana (coste `O(W)` por bloque si no se
    indexa incrementalmente); **no hay snapshot** que sellar, así que no hay un punto único en el
    que declarar la ventana cerrada, ni `Pending`, ni `MissedUpdate`; y la igualdad
    contado = pagado pasa a depender de la posición del bloque en la cadena, que es justo lo que
    VRC-v0.1 encontró roto en su contraejemplo **L0** (`l0_postcierre_diverge`).
  - **Cierra:** la inmutabilidad y la verificación por cohorte.

**Recomendación: A.** La forma queda fijada en `C-RET-02`. Los valores `W_slots`, `G_slots` y
`retardos` siguen siendo símbolos.

**Detalle de A que hay que decidir aparte y se deja pendiente:** si `Pending` bloquea cierres
posteriores (como en RCE/VRC) o si se permite cerrar saltándose la cohorte incompleta. Bloquear es
conservador y conserva la inmutabilidad; saltar abre una vía de viveza a costa de un hueco. **No lo
cierro aquí**: exige medir la racha de `Pending` bajo retención de cuerpos.
`<<PENDIENTE: política de Pending frente a cierres posteriores>>`.

---

## D-2 · Qué conjunto entra en la ventana

**Qué decide.** Qué bloques de `past(B)` con `slot` en la cohorte cuentan en `N_j`.

- **Opción A — exactamente el conjunto pagable de `R-FIN-13′`:** azules y `rojo_k`, una copia
  pagable por billete (`C-ORD-02`), sin `rojo_U3`, sin copias inertes.
  - **Gana:** es el invariante que `R-FIN-13′` ya exige (contado = pagado). **Medido** en el
    propio documento de la regla: contar azules sin la selección por billete da una **inflación del
    retarget ×1,452**; con el conjunto pagable, **×1,005**.
  - **Paga:** el controlador necesita la clasificación de color y la selección por billete de la
    cohorte, que son datos del DAG ya calculados por `C-GD-06`/`C-GD-07`/`C-ORD-02`; no es coste
    nuevo, pero ata el retarget a que esas reglas estén implementadas.
  - **Cierra:** el vector de contar bloques que no cobran.
- **Opción B — todos los bloques de `past(B)` con `slot` en la cohorte.**
  - **Gana:** trivial de contar.
  - **Paga:** cuenta `rojo_U3` y copias, que **no cobran**: sobrecuenta, ablanda el rango y con ello
    **endurece el peso de los que sí cobran** —peso regalado sin espacio pagado—, además de inflar
    `λ_real` (R-FIN-13′: ×1,452 en el caso medido).
  - **Cierra:** la igualdad contado = pagado.
- **Opción C — solo azules.**
  - **Gana:** más simple que A.
  - **Paga:** excluye los `rojo_k`, que **sí cobran** por `R-FIN-8′(1)`; contado ≠ pagado por
    defecto. Es exactamente lo que `R-FIN-13′` corrige.

**Recomendación: A**, redactada en `C-RET-03`. Lo que pasa con un bloque que entra **tarde** al
mergeset se decide en D-5, no aquí; el `rojo_U3` **no cuenta** y una copia con ventana de origen
fuera de la historia es **inerte** (§7.2).

---

## D-3 · Arranque por red

**Qué decide.** Qué rango rige antes de que exista una cohorte completa y cómo se impide que un
atacante fabrique el arranque.

- **Opción A — Bootstrap B0: `R_inicial` constante hasta cerrar la primera cohorte.**
  - **Gana:** es el bootstrap de RCE-v0.1; `R_inicial` vive en los parámetros de lanzamiento
    (§15.2) y **no lo declara ningún bloque**; como las cohortes se indexan por slots **absolutos**,
    retener bloques **no** acorta, reinicia ni salta el arranque; una cohorte vacía es Z0 (rango
    mantenido, ventana sellada y registrada).
  - **Paga:** durante el arranque el controlador no adapta; el rango del génesis hay que elegirlo
    por red y sostenerlo.
  - **Cierra:** que un atacante fabrique el arranque produciendo (o reteniendo) bloques.
- **Opción B — arrancar ya con la primera cohorte adaptando desde un valor de lanzamiento.**
  - **Gana:** converge antes.
  - **Paga:** la primera cohorte puede estar dominada por el atacante si la red es diminuta; es
    precisamente el periodo que `C-CHK` cubre.
  - **Cierra:** la simplicidad de un único punto de entrada.
- **Opción C — curva de arranque explícita (rangos prefijados por época).**
  - **Gana:** control total de la velocidad inicial.
  - **Paga:** convierte el arranque en una tabla de consenso más que hay que mantener y auditar, y
    no aporta nada que B0 + adaptación no dé.
  - **Cierra:** la necesidad de que el retarget converja por sí solo.

**Recomendación: A**, redactada en `C-RET-06`. **Relación con `C-CHK` (§12.1) declarada y no
resuelta:** `C-CHK-02` solo admite un checkpoint cuando el `rango_solucion` es
`≤ UMBRAL_CHECKPOINT`, y el rango **estrecha al crecer la red**; durante el arranque, con
`R_inicial`, no hay checkpoint admisible; el controlador **MUST NOT** depender del checkpoint y el
checkpoint **MUST NOT** fijar el controlador. **No se deriva `UMBRAL_CHECKPOINT`**: §12.1 prohíbe
la conversión antigua con denominador 120 y exige recalibrar rango/espacio.
`<<PENDIENTE: R_inicial por red y UMBRAL_CHECKPOINT>>`.

---

## D-4 · Redondeos y límites

**Qué decide.** El modo de redondeo, qué se hace con el residuo de paridad del `SR` (`TAREAS.md`
§2.3) y el dominio de `SR`.

**Subdecisión 4a — modo de redondeo del cociente `num/den`.**

- **A — entero más cercano, empates al cociente par (`NearestEven`).** Es el modo que RCE-v0.1
  compara contra `Floor` y el que evita sesgo sistemático.
  - **Gana:** sin sesgo direccional; empates resueltos por una regla exacta y comprobable.
  - **Paga:** hay que escribir la regla de empate (dos líneas) y probarla.
- **B — truncamiento (`Floor`).**
  - **Gana:** la operación más simple y la de menor coste.
  - **Paga:** sesga el rango hacia abajo en menos de una unidad por cohorte; el sesgo es
    despreciable frente al tamaño del rango, pero **existe** y hay que declararlo.
- **C — redondeo en coma flotante.**
  - **Prohibido.** C-GD-01 prohíbe la coma flotante en el peso y C-ENC-04 en toda ruta de consenso;
    además el residuo que se decide está por debajo del bit 64.

**Recomendación: A** (`C-RET-04`/`C-RET-05`), con `Floor` aceptado como alternativa declarada.

**Subdecisión 4b — residuo de paridad: rejilla par (A) frente a paridad declarada (B).**

- **A — el controlador devuelve siempre `SR` par.**
  - **Gana:** con `SR` par, `A(SR) = SR+1` y `1 − razón(SR) = ρ/2^128 < 2^−64`: **el déficit de
    paridad desaparece por construcción** y solo queda el suelo, que está 64 bits por debajo del
    último bit del peso. Además **mata la elegibilidad**: para la misma tasa hay dos `SR` (`2m` y
    `2m+1`) con pesos distintos, y con la rejilla par el controlador nunca devuelve el impar.
  - **Paga:** la rejilla del rango pasa a tener paso 2 en vez de 1; la resolución efectiva se
    reduce a la mitad, lo que es irrelevante frente a un dominio `SR ≥ 2` y órdenes de magnitud
    por encima.
  - **Cierra:** el residuo elegible de `1/(SR+1)` y la ambigüedad de paridad.
- **B — admitir `SR` impar con una regla de desempate declarada.**
  - **Gana:** resolución de paso 1.
  - **Paga:** conserva el déficit `1/(SR+1)` —hasta `4,88·10^−4` con `SR = 2047`, la cifra de
    `TAREAS.md` §2.3— y obliga a demostrar que ninguna implementación puede elegir la paridad.
  - **Cierra:** la necesidad de la rejilla par.

**Recomendación: A.** **`medido`** en `RNG-v0.1`: déficit par con la identidad exacta `ρ/2^128` y
cota `< 2^−64` comprobada; déficit impar `1/2048` reproducido; kernel == referencia en 2 040 casos.

**Subdecisión 4c — dominio y anchura.**

- `SR = 0` da `w = 2^128`, **fuera de `u128`** (C-GD-01): **hay que excluirlo**, y con la rejilla par
  eso significa `SR_MIN ≥ 2` (borde derivado, no número inventado). `SR_MAX ≤ 2^64 − 1`, par.
- **Anchura:** con entradas `u64`, `u256` basta **sin precondición**
  (`SR_MAX·d·N_max < 2^192`); una implementación en `u128` **MUST** verificar la precondición de
  RCE-v0.1 o rechazar la configuración. **`medido`** en `RNG-v0.1`: `(2^64−1)^3` cabe en `2^192` y
  en `2^256` y **no** en `u128`; `UInt128` desborda de verdad; una configuración fuera de
  precondición es **rechazada**, no saturada.

**Recomendación:** cerrar así (`C-RET-05`). Los valores `SR_MIN`, `SR_MAX` son símbolos; su
**borde inferior** no lo es.

---

## D-5 · Fusiones fuera de ventana

**Qué decide.** Un bloque cuyo pasado ya estaba íntegro entra al mergeset mucho después. ¿Cuenta? ¿En
qué cohorte? ¿Con qué posición?

- **Opción A — no cuenta en ninguna cohorte; sin retroactividad; condición `merge_depth ≤ G`.**
  - **Gana:** los snapshots sellados **no se tocan** (inmutabilidad, que es lo que VRC-v0.1 exige);
    la pertenencia es función de `slot(X)`, no de cuándo llegó; y la igualdad contado = pagado se
    mantiene por la **condición de corrección** `merge_depth_slots ≤ G_slots`, que cubre la
    profundidad máxima de fusión de `C-GD-11`.
  - **Paga:** `G_slots` queda atado a `C-GD-11`, cuya **métrica y valor están pendientes**; sin esa
    cota, un bloque pagable puede cobrar sin haber contado nunca.
  - **Cierra:** la retroactividad y la manipulación por fusión tardía.
- **Opción B — contarlo retroactivamente en la cohorte de su `slot`, recalculando el snapshot.**
  - **Gana:** contado = pagado sin condición sobre `G`.
  - **Paga:** **rompe la inmutabilidad** y reabre exactamente la divergencia que VRC-v0.1 aisló en
    su contraejemplo L0 (`counted_ids != payable_ids`): un pago incorporado después del cierre
    cambia un snapshot que ya activó un rango.
  - **Cierra:** la causalidad del retarget.
- **Opción C — contarlo en la cohorte del bloque de cadena que lo fusiona.**
  - **Gana:** contado = pagado sin condición.
  - **Paga:** mete en la cohorte `j` un bloque cuyo `slot` no está en `J_j`, así que `N_j` deja de
    ser una medida de la producción en ese intervalo temporal; el retarget mide entonces una mezcla
    de tiempos y el adversario puede desplazar bloques entre cohortes.
  - **Cierra:** el anclaje de la ventana a índices de slot (`C-RET-01`).

**Recomendación: A**, redactada en `C-RET-07`, **con el pendiente heredado declarado**:
`merge_depth_slots ≤ G_slots` no se puede cerrar hasta que `C-GD-11` fije su métrica y su valor.
`<<PENDIENTE: métrica y valor de merge_depth (C-GD-11) y, con ellos, la calibración de G_slots>>`.
Se declara también que el **colateral honesto de `C-FLU-20`** (bloque tardío que cambiaría un ancla
ya activada) **no se mide aquí** y el controlador no lo cura.

---

## D-6 · Validación de ramas candidatas con pesos reales

**Qué decide.** Cómo se comprueba que una rama privada no obtiene más `blue_work` del que su
espacio-tiempo justifica. Es el pendiente que CRP-v0.1 declaró **inconcluso**.

- **Opción A — declararlo `<<PENDIENTE>>` con criterio de cierre y proponer el instrumento.**
  - **Gana:** honestidad de etiqueta: P2 y P3 quedan como **propiedades redactadas**, no como
    veredictos, que es lo que son. Y deja escrito el criterio para que el instrumento se pueda
    encargar sin rehacer el análisis.
  - **Paga:** el encargo no entrega un veredicto sobre la cola de la rama privada.
  - **Cierra:** el pendiente sigue abierto, pero deja de ser vago.
- **Opción B — aproximarlo con el modelo idealizado de CRP-v0.1.**
  - **Gana:** hay cifras (las de §0.3).
  - **Paga:** el modelo tiene el controlador como **familia** y el `sr` **elegible por el
    adversario** (defecto D5 de la auditoría); esas cifras **no** describen el controlador
    propuesto, y presentarlas como veredicto sería el defecto que `CIFRAS.md` ya documentó.
  - **Cierra:** la posibilidad de reclamar que P2 está comprobada.
- **Opción C — restringir el alcance: no reclamar nada sobre ramas privadas y no medirlo.**
  - **Gana:** nada que mantener.
  - **Paga:** deja sin cerrar el vector que motivó el encargo.

**Recomendación: A** (`C-RET-11`). El instrumento que cierra el pendiente, con su criterio exacto:
rama privada completa con el controlador de `C-RET-04` en el bucle; rango **recalculado** desde el
pasado de la rama; pesos reales `C-GD-01`/`C-GD-08`; distribución de `ρ` y cola `P(adv>hon)` con
`α` y `T` declarados; referencia independiente y semilla fija. Es **trabajo de encargo aparte**:
esta propuesta es de redacción, y el encargo §4 pide explícitamente **no repetir CRP-v0.1**.

---

## D-7 · P1 en la práctica: ¿dónde vive el rango que pondera?

**Qué decide.** Si basta con que `w(B)` use `B.rango_solucion` ya validado, o hace falta escribirlo
como invariante aparte.

- **Opción A — confiar en que `C-GD-01` + `C-HDR-06` ya lo implican.**
  - **Gana:** no añade texto.
  - **Paga:** el acoplamiento queda **implícito**. Es exactamente el tipo de relación que una
    implementación rompe sin querer: calcular el peso con un rango cacheado, con el de la cohorte
    anterior, o con el valor declarado antes de validarlo. Y la consecuencia está medida: el trabajo
    por slot se multiplica por `sr_val/sr_peso` **sin pagar espacio** (CIFRAS B1: exacto
    `s·(sr_val/sr_peso)`; con `s = 0,3` y razón 16, **4,8×**).
  - **Cierra:** la posibilidad de auditar la propiedad por grep de una regla.
- **Opción B — escribirlo como invariante explícito con sus tres cláusulas.**
  - **Gana:** el acoplamiento pasa a ser una regla comprobable: (i) el rango que pesa **es** el
    campo validado; (ii) la validación ocurre **antes** de pesar; (iii) no existe una segunda vía de
    cómputo de rango para el peso.
  - **Paga:** una regla más que mantener y que un validador tendrá que contrastar con el código.
  - **Cierra:** el vector de desacoplamiento.

**Recomendación: B** (`C-RET-08`). La propiedad es de una línea, el fallo que previene está medido,
y `PROPUESTA.md` P1 la pide como MUST. Se redacta **aunque sea redundante con `C-GD-01`** por el
mismo motivo por el que `C-ORD-03` se escribió aunque `R-FIN-8′(4)` ya existiera: dos
implementaciones pueden calcular lo mismo por caminos distintos y discrepar en un borde que nadie
enumeró.

---

## Resumen

| # | Decisión | Estado | Quién decide |
|---|---|---|---|
| D-1 | Unidad y forma de la ventana | **cerrada** (slots + cohorte sellada); `Pending`/cierres y valores `<<PENDIENTE>>` | Katana para los símbolos |
| D-2 | Conjunto que entra | **cerrada** (conjunto pagable `R-FIN-13′`) | — |
| D-3 | Arranque por red | **forma cerrada** (B0 + `C-CHK`); `R_inicial` y `UMBRAL_CHECKPOINT` `<<PENDIENTE>>` | Katana |
| D-4 | Redondeos y límites | **cerrada** (nearest-even + rejilla par + dominio); valores `<<PENDIENTE>>` | Katana para `SR_MIN`/`SR_MAX` |
| D-5 | Fusiones fuera de ventana | **cerrada** (sin retroactividad); `merge_depth ≤ G` `<<PENDIENTE>>` de `C-GD-11` | Katana + pendiente de `C-GD-11` |
| D-6 | Validación de ramas candidatas | **`<<PENDIENTE>>` declarada** con criterio; trabajo de encargo aparte | Katana (encargar instrumento) |
| D-7 | P1 en la práctica | **cerrada** (invariante explícito `C-RET-08`) | — |
