# Borradores `C-NET-34` y siguientes — conducta de red frente al eclipse

**PROPUESTA. No son reglas.** No tocan consenso, no se trasladan al `SPEC.md` y **no fijan ni un
solo valor**. Todo símbolo (`B`, `W`, `n_min`, `E`, `α`, los presupuestos, `F_slots`,
`I_slots`, el tamaño de la cola, los umbrales) es una **ENTRADA**: su calibración exige medidas en
red real que **no existen**. La tabla §F dice, para cada uno, **qué hay que medir** antes de fijarlo.

**Numeración.** Se empieza en **`C-NET-34`**. Las 33 anteriores están tomadas y **`C-NET-10` está
retirada con tombstone: su número NO se reutiliza** (`SPEC.md`: «Su número no se reutiliza ni se
recycle»).

**Ánimo de estos borradores, dicho antes de los textos.** El encargo pide «qué reglas cerrarían la
diferencia». Ninguna de estas reglas **cierra** la partición de flujo: `C-FLU-22` no la cura y
`C-FIN-01` la congela. Lo que estas reglas hacen es (a) **hacer visible** el ataque en segundos,
(b) **obligar a la conducta** que convierte la visibilidad en acción, y (c) **subir el coste** de
sostener la captura de pares. Escribirlas como «cierre» sería el patrón que el encargo §4.5 llama
*alcance estrecho con etiqueta ancha*.

**Convención normativa:** `MUST` / `MUST NOT` / `MAY`/`SHOULD` con el sentido del `SPEC.md` §0.1.

---

## A · Lo que el ataque consigue, en una tabla, porque las reglas salen de aquí

Medido con el instrumento verificado (`run.jl --variantes`, `--regimen`), 12 semillas, 900 s:

| | (i) retiene el PoT | (ii) filtra los bloques | (iii) retrasa `E` |
|---|---|---|---|
| Bloques de la víctima | **0** | todos, válidos | todos, válidos si `E` no crece |
| Recompensa perdida | **100 %** | **100 %** (`rojo_V = 1,0000`) | **100 %** si `E ≥ 60 s` |
| Tasa que ve la víctima | 0 | ≈ 0 | **≈ λ (indistinguible)** |
| PoT que ve la víctima | se congela | correcto | retrasado `E` |
| Espacio del atacante | **0** | **0** | **0** |
| Lo ve | **E1** | **E2** | **E1** |
| Partición de flujo permanente | **sí** si dura `> F_slots` | **sí** si dura `> F_slots` | **sí** si retiene el bloque que cruza `T_j` |

**Ninguna variante es visible a los dos sensores: hacen falta E1 y E2.** Y **ninguno de los dos
impide el robo**; lo hacen visible. `E1` detecta (i) en el orden de `B_paro − L`, es decir decenas
de segundos, y (iii) en ~1 s si `E > B_paro`. `E2` detecta (ii) en decenas de segundos.

---

## B · Sensores como conducta obligatoria del nodo

**C-NET-34 · Sensor de reloj de PoT (E1) y sensor de tasa (E2): el nodo MUST evaluarlos.**

Todo nodo **MUST** evaluar de forma continua dos sensores independientes sobre su propia vista, y
**MUST** distinguir tres estados: `Normal`, `Aviso` y `Alarma`.

```text
E1 (reloj)  la frontera de PoT verificada va por detrás del reloj de pared más de B_aviso / B_paro
E2 (tasa)   la ventana deslizante (t−W, t] trae estrictamente menos de n_min bloques válidos,
            contando los bloques PRODUCIDOS POR EL PROPIO NODO
```

`E1` **MUST** medirse sobre la **frontera secuencial** verificada —la que solo avanza cuando llega
el **siguiente** slot—, **MUST NOT** medirse como una muestra suelta del retardo de un slot, porque
un solo slot retrasado atasca la frontera y la cola de la frontera es **estrictamente más pesada**
que la marginal (comprobado: `P(D>8) = 0,0100` frente a `P(L>8) = 0,014760`).

`E2` **MUST** contar los bloques propios. Un granjero con fracción `f_v` del espacio produce
`f_v·λ` bloques por segundo: no contarlos hace que **un granjero grande se alarma solo**.

**C-NET-35 · Bajo `Alarma`, el nodo MUST NOT autorizar, MUST alertar y MUST renovar pares.**

```text
MUST NOT autorizar      Bajo Alarma de E1 no se emite bloque. Sin PoT fresco el bloque es inválido
                        por la atadura sello-slot; no emitirlo no cuesta nada.
MUST alertar            Al operador, nombrando LAS DOS causas posibles: eclipse y caída del
                        timelord. E1 NO distingue una de otra y no puede.
MUST renovar pares      Rotar a pares de prefijos de red DISTINTOS a los actuales, sin esperar
                        a que la conexión actual se cierre.
MUST NOT puntuar        Ningún par MUST ser penalizado por esto (C-NET-05: lento ≠ malicioso).
                        Renovar no es castigar; es cambiar de vecinos.
```

**Por qué la rotación es el discriminador y por eso va en la regla:** es lo único que separa las
dos causas. Si tras rotar a prefijos distintos el PoT sigue sin llegar, es caída de la red; si
llega, era eclipse. Sin la rotación obligatoria, las dos causas se ven idénticas **para siempre** y
el operador no puede decidir nada.

**C-NET-36 · La conducta del comerciante bajo alarma: MUST NOT confirmar.**

```text
Un comerciante bajo Alarma MUST NOT dar por confirmado un pago, y MUST NOT tratar su vista
congelada como confirmación.
MUST declarar explícitamente al operador que su horizonte de confirmación es inseguro mientras
dure la alarma, en vez de seguir aplicando su regla ordinaria de profundidad.
```

**El motivo, medido, y hay que decirlo con estas palabras:** en la variante (i) la víctima deja de
producir y **deja de recibir**; su vista **se congela**. Lo que vio confirmado hace una hora sigue
pareciendo confirmado, y el comerciante no tiene forma de saber que su reloj de datos está parado.
Ése es el daño específico contra un comerciante, y separarlo del daño contra un granjero es el
punto entero de esta regla. **Un sensor no impide el ataque: lo hace visible.** El comerciante que
sigue cobrando bajo alarma **no está protegido por E1 ni por E2**.

**C-NET-37 · `B` del sensor y `B` de la atadura sello-slot son el MISMO número, y el del sensor
MUST NOT superarlo.**

```text
B_sensor (paro de autoría, alerta, rotación)  MUST NOT ser mayor que  B_consenso (atadura sello-slot)
```

**Por qué:** un nodo honesto pone en `timestamp` su reloj de pared y en `slot` el último slot de PoT
**que ha verificado**; la diferencia es exactamente `L + ε`. Si `B_consenso < B_sensor`, el nodo
**emite bloques que la red rechaza sin que suene ninguna alarma** — el peor de los dos mundos. Si
`B_consenso ≥ B_sensor`, la alarma llega **antes** de perder bloques. Este acoplamiento **no estaba
escrito en ninguna parte** y es la primera consecuencia de la ronda 11b sobre una decisión ya
tomada.

**C-NET-38 · E2 MUST NOT ser la única condición de paro, y su umbral MUST re-derivarse si la tasa
de la red no es estable.**

`n_min` se deriva de una `Poisson(λW)` con **menos de una falsa alarma al año**. Si la tasa real de
la red fluctúa una fracción `s_λ` dentro de la ventana, el margen cae y el sensor puede dejar de
existir. Por eso `E2` es **condición necesaria de aviso, no suficiente de paro**: el paro lo
dispara `E1`, que mide un reloj y no una tasa. `<<POR MEDIR: s_λ en red real>>`.

---

## C · Contramedidas del gestor de direcciones (lo que la sección D acredita)

**ADVERTENCIA DE ALCANCE, y es la etiqueta del bloque entero.** **El gestor de direcciones de ZEROX
NO EXISTE** (verificado: no hay `addrman`, ni tablas `tried`/`new`, ni `PrefixBucket`, ni
selección de salientes de ningún tipo; `crates/zx-p2p/src/limites_ip.rs:288-298`). Las reglas `C`
de este bloque son, por tanto, **condiciones de diseño para un gestor que se construya**, no
descripciones de lo que hay. Se etiquetan **`propuesto`**, y su cumplimiento **no se puede
verificar hoy** porque no hay nada que verificar.

**C-NET-39 · La selección de pares salientes MUST ser aleatoria sobre una tabla diversificada por
prefijo, y MUST NOT ser «la primera que llegue».**

```text
MUST  elegir cada saliente al azar de una tabla de direcciones, no en orden de llegada
MUST  agrupar por prefijo de red para el SORTEO (IPv4 /16 ; IPv6 el prefijo que fije el diseño)
MUST  exigir prefijos DISTINTOS entre salientes simultáneas, salvo que no haya alternativa
MUST  limitar cuántas salientes puede ocupar un mismo prefijo
MUST NOT aceptar direcciones no solicitadas hacia la tabla de candidatos sin coste
```

**Lo que esto compra, con número y con fuente.** En el modelo de elección uniforme sin reemplazo
(producto hipergeométrico exacto), la fracción de prefijos que el atacante necesita para capturar
`ω` salientes con probabilidad `p` es `p^(1/ω)`:

| `ω` | 50 % | 90 % |
|---:|---:|---:|
| 8 (Bitcoin 0.9.3, Kaspa) | 0,9170 | 0,9869 |
| **24 (`limites.rs:174`)** | **0,9716** | **0,9956** |

**Y lo que NO compra:** el atacante no necesita **poseer** el prefijo, le basta con que la víctima
lo **elija**. La cota es superior, no inferior. **Sin la parte «MUST NOT aceptar direcciones no
solicitadas sin coste», las otras tres no se sostienen**: el ataque de Heilman vive precisamente de
llenar la tabla con `ADDR` no solicitado y esperar al reinicio. En `libp2p` la identidad es un
`PeerId` (clave pública), **no una IP**, y generar `PeerId` es casi gratis: **la parte de Heilman
que NO sobrevive al cambio de pila es todo el mecanismo de llenado y evicción**; lo que sobrevive es
la cuenta `p^(1/ω)`.

**C-NET-40 · Renovación de pares por antigüedad: ninguna saliente MUST permanecer ocupada
indefinidamente.**

```text
MUST  renovar una fracción de las salientes tras un tiempo de permanencia T_par
MUST NOT renovarlas todas a la vez (evita que un atacante espere el turno)
MUST NOT penalizar al par que se deja por antigüedad (C-NET-05)
```

**Por qué es la regla que más pesa contra el ataque de este encargo.** El coste real del atacante
**no es ancho de banda**: es **sostener** la ocupación de las salientes. Un atacante que retiene
gasta ≈ 0 bits. Si las salientes se renuevan, tiene que **volver a capturarlas** cada `T_par`, y el
coste se multiplica por el número de renovaciones que dure el ataque. Sin esta regla, `C-NET-34/35`
detectan el eclipse pero el atacante sigue dentro, y la rotación de `C-NET-35` sólo ocurre **después**
de que la alarma suene.

**C-NET-41 · Contabilidad de salientes por prefijo: el límite por prefijo MUST contar también las
SALIENTES.**

```text
El cupo por prefijo de C-NET-20 MUST aplicarse a las conexiones salientes, no sólo a las entrantes.
```

**Esto nace de un defecto de código verificado, no de un modelo:**
`crates/zx-p2p/src/limites_ip.rs:288-298`, `handle_established_outbound_connection` devuelve
`Ok(dummy::ConnectionHandler)` **sin registrar nada**, y `de_peer` sólo se rellena en la ruta
entrante (`limites_ip.rs:281-284`). Consecuencia doble: (a) `MAX_POR_PREFIJO = 3` **no limita las
salientes**; y (b) al desconectar por consenso, `prefijos_de(peer)` está **vacío** para un peer
marcado por nosotros **y no se banea prefijo alguno** — la defensa de baneo por prefijo de
`C-NET-20` **no funciona para los pares que elegimos nosotros**, que son justamente los que un
atacante necesita capturar. Es `verificado en fuente` y es corregible sin ninguna medida nueva.

**C-NET-42 · El gestor MUST NOT depender de un descubrimiento que hoy no existe.**

Hoy **no se ha encontrado** bootstrap de Kademlia, ni suscripción a temas de gossipsub, ni manejo
de eventos de descubrimiento (`servicio.rs:267-284` sólo despacha cinco variantes). Un gestor de
direcciones sobre una pila que no descubre pares no tiene de dónde llenar la tabla. **Esta regla no
propone un mecanismo**: declara la dependencia para que el orden de construcción sea explícito.

---

## D · Lo que estas reglas NO hacen

- **No cierran la partición de flujo.** La partición deliberada (retención `> F_slots`) es
  permanente por `C-FLU-22` + `C-FIN-01` y **ninguna regla `C-NET` la cura**. Estas reglas la hacen
  **visible y cara de sostener**, no imposible.
- **No impiden el robo de recompensa.** La variante (ii) con `α = 0` cuesta el `100 %` de la
  recompensa de la víctima **aunque E2 la detecte en 25–38 s**. Lo dicen el propio informe de 11b y
  este puerto: **un sensor que hace visible un ataque no lo impide.**
- **No fijan `B`, `W`, `n_min`, `T_par`, ni los presupuestos.** Ver §F.
- **No proponen comités ni anclas de consenso.** El ancla externa es ayuda al operador, nunca regla
  de consenso (`AGENTS.md`, `LIBRO-DE-RESTRICCIONES.md`).
- **No convierten la detección en permiso para desobedecer `C-FIN-01`.** Bajo alarma el nodo deja
  de **autorizar**; no reorganiza fuera de la ventana de `C-FLU-22`.

---

## E · Paso por las doce restricciones (`LIBRO-DE-RESTRICCIONES.md`)

| Restricción | ¿Choca? | Por qué |
|---|---|---|
| R-1 (recurso no rival) | No | Estas reglas no tocan la naturaleza del recurso; viven en la capa de red. |
| R-2 (compromiso al valor no fecha) | No | No se compromete nada. |
| R-3 (determinista + público ⟹ regenerable) | No | Ajeno. |
| R-4 (exclusividad por identidad) | No | `C-NET-39` **no** se apoya en identidad: agrupa por **prefijo de red**, que cuesta dinero. Pero se anota: si el diseño migrara a identidad `PeerId`, R-4 lo mataría. |
| R-5 (coste no proporcional) | No | No hay tasas por identidad. |
| R-6 (validez sobre `past(B)` no obliga a publicar) | **No choca, pero delimita** | Estas reglas son **conducta del nodo**, no validez. Es exactamente donde R-6 exige que estén: no se puede cerrar por validez, sólo por conducta observable. |
| R-7 (anclar el reto al padre) | No | Ajeno. |
| R-8 (el tiempo no es rival) | No | No se usa tiempo como coste rival. |
| R-9 (partir cuesta ⟺ regresiva) | No | No hay cuota por identidad. |
| R-10 (una firma no prueba que se vio) | **No choca, y es la restricción que más importa aquí** | `C-NET-36` **no** exige atestiguación de terceros: exige que **el propio comerciante** deje de confirmar. Depender de que un tercero «sólo firme lo que ha visto» sería R-10. |
| R-11 (la cuota de peso no está acotada por bytes) | No | Ajeno. |
| R-12 (ocupación de s-buckets no constante) | No | Ajeno. |

**Ninguna regla de este bloque queda refutada antes de nacer.**

---

## F · Qué hay que medir en red real antes de fijar cada valor

Éste es el punto F del encargo original de 11b, que **sigue sin hacerse**. Ningún valor de esta
tabla puede fijarse sin su medida; fijarlo por intuición sería una regla de consenso con apariencia
de cerrada y cimiento móvil (`SPEC.md` §0.3).

| Símbolo | Qué es | Qué hay que medir, exactamente, antes de fijarlo |
|---|---|---|
| `Δ` real | retardo de propagación honesto | Red desplegada con nodos corriendo. `DMS-v0.1` es **simulada**: decide `L_suelo_slots`, el suelo de `F` y la viabilidad de E1/E2. **Es la medida que bloquea las demás.** |
| `L_suelo_slots` | suelo de `C-FLU-01` | (a) la cola medida de desacuerdo de cadena seleccionada a una `ε` elegida explícitamente; (b) una cota de `Δ` **medida**. Sin (b) cualquier valor es provisional y **MUST** decirlo. |
| `B` (consenso y sensor) | atadura sello-slot y umbral de E1 | La **forma de la cola** del retardo honesto, no sólo su p99: `B` va de 20 s a 1 422 s según la familia. Y `B_sensor ≤ B_consenso` debe comprobarse **junto**, no por separado. |
| `W`, `n_min` | ventana y umbral de E2 | **`s_λ`**: la inestabilidad real de la tasa dentro de la ventana. Nuestro propio artefacto muestra que la columna `s_λ` de 11b no es reproducible desde su texto, así que no sirve como sustituto. |
| `T_par` (C-NET-40) | permanencia máxima de una saliente | Cuánto tarda un nodo honesto en reconectar y cuánto tarda un atacante en recapturar. Se mide con la red viva. |
| grupo de prefijo | unidad de diversidad | Para **ZEROX**, no para Bitcoin: cuántos prefijos posee un host típico y cuántos puede alquilar un atacante. En `libp2p` **`PeerId` no es la unidad** (R-4). |
| `PRESUP_NODO` | presupuesto de verificación de flujo ajeno | **Los milisegundos del paso 1b de `C-POT-08` por bloque ajeno.** Es la única medida que falta para decidir F5; sin ella la compatibilidad de la cota inferior (11,04 min con `F_slots = 7200`) con la resistencia al agotamiento queda **inconclusa**. |
| `PRESUP_PAR` | ídem por par | El coste medido de una petición estructural maliciosa frente a una legítima. El atacante con `N` conexiones obtiene `N` presupuestos: `PRESUP_PAR` **solo** no acota nada. |
| `F_slots`, `I_slots` | finalidad y periodo de inyección | `Δ` medida y el suelo de finalidad. Fijan `E_min = F_slots` de la partición deliberada. |
| colateral de `C-FLU-20` | bloques honestos infusibles | Cuántos bloques honestos caen en la banda de la vista de época y quedan infusibles. `TAREAS.md` §2.9 lo declara pendiente; aquí sólo se da la forma (`≈ E/I_slots` épocas). |
