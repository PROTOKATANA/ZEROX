# Agujeros explotables de ZEROX y sus posibles soluciones

**Fecha:** 2026-09-21 · **Autor:** Claude, a petición de Katana · **Estado:** apuntes de trabajo.
**No es SPEC, no fija ningún parámetro y no decide nada.** Recoge lo hablado y comprobado en la sesión
del 2026-09-21 sobre el segundo VDF, el atacante con muchos recursos, el compromiso previo de parcela y
el resto de huecos conocidos, con lo que cada solución **cierra**, lo que solo **encarece** y lo que le
**falta** para poder entrar en el SPEC.

## 0 · Cómo leer este documento

Cada afirmación lleva una de estas etiquetas. **La etiqueta importa más que la cifra.**

| Etiqueta | Significa |
|---|---|
| **[VALIDADO]** | Medido o demostrado por un instrumento **y** revisado por Claude (documentos, citas y, donde se indica, reejecución) |
| **[MEDIDO, sin revalidar]** | Sale de un instrumento entregado; Claude revisó documentos y aritmética, **no** reejecutó |
| **[HISTÓRICO]** | Cifra de las rondas de `research/` (instrumentos Python que ya no se ejecutan). Orienta; **no es heredable** |
| **[LECTURA DE CLAUDE]** | Razonamiento propio sobre reglas y fuentes. No medido |
| **[NO VERIFICADO]** | Conocimiento general citado de memoria, sin abrir la fuente en esta sesión |

**El modelo de amenaza es el de Katana:** se asume que un ente con mucha capacidad —dinero, CPU, GPU,
discos; un Estado, una agencia, un grupo— **atacará tarde o temprano**. Que un ataque «no compense
económicamente» descarta al atacante que busca lucro y a nadie más. Por eso, para cada hueco, este
documento separa lo que lo vuelve **imposible** de lo que solo lo vuelve **caro**, y da el coste
**absoluto** en hardware, no solo el relativo.

---

## 1 · El mapa: agujeros y soluciones

### 1.1 Los que bajan el umbral de seguridad (los más graves)

En el **baseline simétrico idealizado** (un flujo compatible, eficiencia azul simétrica, controlador
acoplado) la frontera de deriva es `α_drift = 1/2`, la misma que en PoW: ahí **reutilizar el espacio abarata
el ataque, no lo hace más fácil** (`veritas/seguridad/coste-rama-privada-v1/`, CRP-v0.1). **Pero eso NO es
«el umbral de ZEROX es el 50 %»**: el encargo que dio origen a CRP-v0.2
(`P-ZRX/rescate-deepseek/encargos/ENCARGO-07v2-coste-rama-privada.md`) enumera **diez defectos de CRP-v0.1**
—su «DAG» era una cadena, su DP de granularidad perdía casi toda la masa, su multistream era una
identidad tautológica, «ataque gratis» estaba sobre-enunciado— y **prohíbe expresamente** decir «en la
liga de PoW» o «seguro al 50 %»; CRP-v0.2 y v0.3 concluyen **«umbral protocolario global INCONCLUSO»**.
*(Corregido el 2026-09-21: esta frase decía «[VALIDADO en su día]»; Claude usó ese 50 % como titular todo
el día con más firmeza de la debida. Lo zanja `P-ZRX/P-CRP/`.)*

| # | Agujero | Evidencia | Solución | Estado |
|---|---|---|---|---|
| **A1** | **Multistream de PoT**: con `S` flujos simultáneos la cuota efectiva es `Sα/(1−α+Sα)` y el umbral cae a `1/(S+1)` — **0,040 con `S = 24`**, sin espacio adicional | CRP-v0.1 §5 | **`C-FLU-13/14`**: validez absoluta y prohibición de referenciar bloques de otro flujo. **Lo cierra por regla, no por tarifa** | **Decidido** por Katana (2026-09-19/20) y redactado en `SPEC.md` §7.1. **Sin código**: `SPEC.md` §17 dice que ninguna de las 31 reglas nuevas tiene una línea |
| **A2** | **Varianza del rango elegible**: una rama privada fija `sr` bajo (bloques escasos y pesados) y, con el **mismo** trabajo medio, compra cola. Con `α = 0,45`, 400 slots: `P(gana)` **2,2 % → 30,8 %** con `sr0/64` | CRP-v0.1 §3 | **P1–P3** de `coste-rama-privada-v1/PROPUESTA.md`: mismo rango para validez y peso; **anclar el retarget de R-FIN-13′ al flujo canónico**, no al pasado de la propia rama | **NO está en el SPEC.** `TAREAS.md` §2.3 sigue pendiente. P1–P3 son **requisitos candidatos**: el controlador completo sigue sin definir ni validar, así que **todavía no es un cierre** |

El precio ya aceptado de A1: una **partición de flujo** más larga que `L` **no tiene cura** (§1.4, D3).

### 1.2 Los que nacen de un reloj más rápido que el honesto

Con `ρ ≤ 1` (nadie más rápido que los timekeepers honestos) los dos valen **cero**
(`research/dag-poas-catalogo-problemas-ataques.md`, A3 y A5). Todo este bloque existe porque `ρ > 1`
es posible.

| # | Agujero | Qué se sabe | Soluciones, de la más estructural a la más paramétrica |
|---|---|---|---|
| **B1** | **Ventana de adelanto**: el atacante conoce retos futuros | **Sin segundo VDF la ventana es `≈ L` para CUALQUIER `ρ > 1`** tras un *bootstrap* (180 h a `ρ = 1,01`; 3,65 h a 1,5; 0,9 h a 3,0). Máximo exacto `A_core − D`, con `A_core = (L−1−W_dec) + I(1−1/ρ)`. Con `L = 7 200`: entre 7 175 y 8 030 slots. **Acotar `ρ_max` por sí solo no la reduce** — `P-ZRX/P-REVELACION/` **[MEDIDO, sin revalidar]** | (a) **paridad de reloj** (§3.4); (b) **segundo VDF** (§2): la vuelve proporcional a la ventaja; (c) **acortar `L`**: perfil 1b o bajar `F` (§5) — exige `Δ` medida |
| **B2** | **Sembrador**: fabrica parcelas a medida del reto y las tira; nunca almacena | Válido contra el formato Autonomys; la unidad es **una pieza**, no un sector; ni `history_size` ni `altura_ploteo` fechan los bytes (`P-ZRX/P-SEMBRADOR/`). Coste **[MEDIDO, sin revalidar]** en §4 | (a) **compromiso previo de parcela + edad** (§3): **el único que lo ELIMINA**; (b) sellado secuencial: elimina condicionalmente, caro (§3.5); (c) segundo VDF: encoge la ventana, no cierra |
| **B3** | ***Steering* del ancla**: elegir, entre sus candidatos a ancla, el que más le conviene | Hoy **ACOTADO** por la calibración `I ≥ ρ_max·W_dec` de R-FIN-14(f): `n_eval = ρ·W_dec` tras el *bootstrap*; ganancia histórica de un 4–5 % **[HISTÓRICO]** | (a) paridad de reloj; (b) **segundo VDF**: exige `ρ ≥ ρ* ≈ 9` sistemático (`L = 2 h`, `I = 851`), por encima del techo físico estimado; residuo por **rachas de anclas propias** (§2.3); (c) la calibración que ya existe |

### 1.3 Los que nacen de que el recurso no se gasta

| # | Agujero | Qué se sabe | Solución candidata | Le falta |
|---|---|---|---|---|
| **C1** | **Alquiler corto / capacidad relámpago** | No hay mercado medido; «alquilar es barato» es plausible, **no medido** | Compromiso previo + edad: el coste pasa de `B·r·T` a `B·r·(M+T)`. **Solo frena la capacidad creada justo a tiempo: NO encarece alquilar una parcela ya madura, su clave o su servicio remoto** (ese caso es el del espacio prestado, `SOLUCION-CANDIDATA-REUTILIZACION.md`) | Lo mismo que B2(a) |
| **C2** | **Cobrar y borrar** | Sin medir | **Vesting de recompensas propias condicionado a permanencia** (retos posteriores impredecibles). No exige comprar moneda. **No retroinvalida el bloque**: solo deja sin consolidar la recompensa pendiente. **Encarece descartar la parcela ganadora, no los miles de intentos fallidos del sembrador** | Necesita la misma raíz que el compromiso previo; **falsos fallos domésticos sin medir** (apagón, corte de red); no protege el arranque (garantía inicial cero) |
| **C3** | **Mismo billete en ramas distintas** | **Hoy NO es fraude**: tras un reorg el billete de la historia abandonada vuelve a estar disponible (`SPEC.md` §7.2, l. ≈ 1900-1908; búsquese «vuelve a estar disponible»). U3″ bloquea el doble uso **dentro** de una rama, no entre ramas disjuntas (CRP-v0.1 §6) | Un castigo (*slashing* de recompensa retenida) exigiría **definir primero una infracción más estrecha** | No aplicable tal como está |

### 1.4 Los que ninguna herramienta de hoy toca

| # | Agujero | Qué se sabe | Qué hay |
|---|---|---|---|
| **D1** | **Mayoría comprando el recurso** | Inevitable en cualquier red abierta, Bitcoin incluido. Por cada PiB honesto, el 33 % son **28 discos de 20 TB** **[LECTURA DE CLAUDE, aritmética]** | Tamaño de red. El checkpoint del periodo frágil `C-CHK` y la finalidad `F` **solo limitan ciertas reorganizaciones y el periodo inicial: no protegen contra una mayoría sostenida de espacio** |
| **D2** | **Red: retardo `Δ` y eclipse** | Según la propia investigación del repositorio, **son las palancas de un Estado, no el reloj** (`research/pot-aes-asic-chacha.md` §3). `Δ` de 4 a 16 s multiplica por 3,5 el suelo de `F` **[HISTÓRICO]**. El eclipse **sí se modeló históricamente** (ronda 11b: variantes del ataque y sensores, `research/scripts/d8-ronda11b/informe.md`) **[HISTÓRICO]**; **falta un modelo integrado y validado para el protocolo vigente**. *(Corregido el 2026-09-21: esta fila decía, por error de Claude, que nadie lo había modelado.)* | Sensores y reglas de red de la ronda 11b, **sin integrar ni validar**. Sigue siendo el hueco más serio frente al adversario de Katana |
| **D3** | **Partición de flujo sin cura** (corte de red más largo que `L`) | Demostrado en `P-ZRX/P-FLUJO/`. Se **previene** con `L` frente a `Δ`; `C-FLU-22` cura solo el nacimiento espontáneo | `L_suelo_slots` sigue `<<PENDIENTE>>`: exige `Δ` medida en red real |
| **D4** | **Nodo nuevo: sincronización SUCINTA** | Una prueba recursiva **no decide** la selección GHOSTDAG (`veritas/consenso/prueba-recursiva-v1/`); no existe prueba de poda para un nodo nuevo (`veritas/consenso/poda-post-v1/`) | **Un nodo nuevo siempre puede descargar y validar toda la historia desde el génesis sin confiar en nadie** (`SPEC.md` §17, fila de poda); lo que falta es el arranque **sucinto** desde estado podado y una elección objetiva durante una partición persistente. *(Corregido el 2026-09-21: antes decía «depende de un checkpoint».)* Idea sin estudiar: anclaje externo (p. ej. en Bitcoin) como **ayuda al operador, nunca regla de consenso** **[LECTURA DE CLAUDE, NO VERIFICADO]** |
| **D5** | **El reloj principal** | Producir una línea de PoT ocupa **un núcleo entero y no se reparte**. En el Ryzen 9 9950X3D: `prove = 1,561 s/slot`, **no llega** a `τ = 1 s` (`research/dag-poas-ancla-de-orden.md:342`). Centralización del timekeeper: issue `autonomys/subspace#2141`, cerrada *not planned* | Varios timekeepers pueden calcular la misma línea: el benchmark muestra un problema de **rendimiento** en esa configuración, no una centralización inevitable. Redundancia `C-TIMELORD-01…04` (**propuesta** en `research/timelord-redundancia-informe.md`; **no está en el SPEC**); bajar iteraciones por slot o exigir CPU de mejor latencia AES. Abierto |
| **D6** | **Fallo en código de Autonomys** | `ab-proof-of-space @ f8842d0` da **SIGSEGV** con ciertas semillas por la ruta **no** paralela (semilla `fc5317b0…85bcbc`, 3/3). La ruta del plotter honesto no falla. Causa raíz sin determinar (`P-ZRX/P-INTENTO/investigacion/`) | Tenerlo presente **antes de portar** ese código |

---

## 2 · El segundo VDF (revelación retardada, R-FIN-14(h))

### 2.1 Qué es

`entropía_j = blake3(AES128_chain^{Lrev·N}(blake3(chunk(I_j) ‖ salida(f, slot(I_j)))[0..16)))`, aplicada
en `t_j = slot(I_j) + L`. Seis piezas (h.1)–(h.6) en `research/scripts/d8-ronda10a/informe.md` §A.6,
etiquetadas **PLAUSIBLE** por su propio autor. Lo esencial:

- **Un VDF no oculta nada: cobra tiempo.** Las entradas son públicas y el atacante lo calcula él; (h)
  le cobra `Lrev/ρ` de reloj **por candidato**. Por eso reduce por `(1 − 1/ρ)` y **no cambia la cota con
  `ρ → ∞`** (ronda 7, confirmada por 10a y por P-REVELACION).
- **Se calcula, no se publica**: nadie puede retenerla y no crea ninguna rama de validez que dependa de
  la vista de cada nodo.
- Cambiaría **una sola regla: `C-FLU-12`** (la entropía de la inyección). `t_j`, el identificador de
  flujo y la validez **no cambian**. No reabre `C-FLU-13/14` ni la primitiva (AES-128 + `blake3`).
- `Lrev < L` obligatorio: con `Lrev = L` **el timekeeper honesto no llega**. Recomendación (h.1b):
  `Lrev = L − S_max`. Puntualidad honesta corregida por P-REVELACION: **`Lrev ≤ L − W_dec − D`**.

### 2.2 Qué compra — `P-ZRX/P-REVELACION/` **[MEDIDO, sin revalidar]**, `L = 7 200`, `I = 851`

| Ventaja de reloj `ρ` | Ventana sin segundo VDF | Ventana con segundo VDF `(L+I)(1−1/ρ)` |
|---:|---:|---:|
| 1,01 | ≈ 7 187 | **80** |
| 1,5 | ≈ 7 463 | **2 684** |
| 2,0 | ≈ 7 605 | **4 026** |
| 2,5 | ≈ 7 690 | **4 831** |

- **Quita el acantilado de `ρ = 1`**: hoy un 1 % de ventaja sostenida da la ventana entera; con él, la
  ventana es **proporcional a la ventaja**. **Protege mejor contra la amenaza pequeña que contra la
  grande.**
- **NO anula la ventana.** La tesis de `P-ZRX/P-ADELANTO/` («con (h) `sup A = 0`, la edad colapsa al
  margen») quedó **refutada**: confundía la holgura de la carrera de *steering* (de donde sale `ρ*`) con
  la ventana que explota el sembrador.
- **Edad exigida a un compromiso previo** (q99 con rachas, `α = 0,33`): la reduce por un **factor 1,2 a
  4,6**. En `F = 2 h`, `ρ_max = 2,5`: **8 800 → 5 712 slots** (factor 1,54). Más tabla en
  `P-ZRX/P-REVELACION/investigacion/INFORME.md` §1.5.
- ***Steering***: exige `ρ ≥ ρ* ≈ 9,2`. El cerrado `(Lrev+I)/(I+W_dec)` es **optimista** en torno a un
  5 % frente a la simulación con offset uniforme.
- **`F`**: elimina el término de *steering* de `F = máx(F_carrera, I/(W/κ−1))`. Solo ayuda si `Δ ≲ 12 s`,
  que es cuando manda ese término (§5).

### 2.3 Lo que no cubre: las rachas

Si el ancla de una época es del atacante, la barrera no lo frena; en una racha de anclas propias su
ventaja **crece sin tope**: `(L + (r+1)·I)(1 − 1/ρ)`, con tasa `α^(n*−1)`. **[HISTÓRICO, reproducido por
P-REVELACION]**: a `ρ = 2,5`, `α = 0,33`, *steering* en **145 épocas al año**; a `ρ = 1,5`, `7·10⁻⁴`.
Consecuencia: **ninguna cota del tipo «`M > sup`» sirve**; debe escribirse como **cuantil con su tasa de
excedencia**, y depende de `α`, que no está medida en red.

### 2.4 Qué cuesta

| Concepto | Cifra | Etiqueta |
|---|---|---|
| Verificar, nodo normal, **`I` calibrado por (h.6)** (`ρ_max = 2,5`, `F = 2 h` ⇒ `I = 4 767`) | **0,24 núcleos + 3 líneas de AES** | MEDIDO, sin revalidar |
| Lo mismo con `I = 851` sin recalibrar | 0,909 núcleos + 10 líneas | ídem |
| En el Ryzen 9 9950X3D (16 núcleos) | 1,5 % de la máquina calibrado; 5,7 % sin calibrar | LECTURA DE CLAUDE, con `verify = 96,1 ms/slot` medido |
| Ponerse al día con una ventana `F = 2 h` (adopción de flujo rival), 16 núcleos | **6,7 min frente a 43 s** sin segundo VDF; con `F = 1 h` recalibrado, 54 s frente a 22 s | ídem |
| Quien **no reciba** los checkpoints y deba recalcular | ×16 sobre verificar | HISTÓRICO (asimetría `prove/verify`) |
| **Timekeeper** | **un núcleo entero por línea, sin reparto** | VALIDADO en código (`PDF/autonomys-subspace/crates/subspace-proof-of-time/src/aes/x86_64.rs`) |
| Red | bloque **no crece** (compromiso de 16 B); propagación +0; ≈ 1 kB/s de gossip | HISTÓRICO (h.2b) |

Calibrar bien exige `I` **grande**, no pequeño (`I* = (L − ρ_max·W_dec)/(ρ_max − 1)`): de 4,2 inyecciones
por hora a 0,76, es decir **menos** instantes `t_j` donde puede nacer una partición. Con `I` recalibrado
en cada `F`, la «realimentación `F → L → ρ*`» que P-ADELANTO presentaba como decisiva **se traslada a
`I`** y el coste queda ≈ constante (0,24–0,26 núcleos para `F` de 2 h, 1 h o 0,28 h).

### 2.5 Riesgos abiertos

1. **`ρ_max` sin medir.** De él sale la calibración de `I`. Techo físico estimado del reloj AES:
   **1,5–2,5×** (`research/pot-aes-asic-chacha.md`, **estimación**; el estudio de Supranational **no está
   localizado**). Calibrar mal es tirar CPU o quedarse sin protección.
2. **Vector C4**: en una partición, el lado sin `q+1` líneas **deja de producir** aunque conserve su
   espacio, y ni siquiera puede verificar al otro sin recalcular.
3. **`PRESUP_NODO` nunca se derivó con (h) dentro**; su cota superior ya estaba sin derivar
   (`TAREAS.md` §2.9 (c) 12).
4. Mecanismo **propio**, sin implementación de referencia ajena. La cadena infundida de Chia avala el
   mecanismo, **no la escala** (una cadena viva de 600 s frente a varias simultáneas).

### 2.6 Lo que NO es una salida

- **Más VDF (3, 4…).** Alargar la revelación choca con un techo duro: **el honesto tiene que llegar a
  tiempo**. Más líneas en paralelo no son protección, son las necesarias para épocas solapadas. Y
  **protección y coste son el mismo número** (`1 + L/I ≈ ρ_max`): más VDF es moverse por la misma curva
  pagando CPU, subiendo el suelo de hardware y agravando C4 y la centralización del reloj
  **[LECTURA DE CLAUDE sobre 10a]**.
- **Cambiar la primitiva del reloj** (grupos de clase, ChaCha): empeora el hueco CPU↔ASIC. Con AES la
  CPU ya es casi el ASIC; el ASIC de grupos de clase de Chia dio 3,1–3,8×
  (`research/pot-aes-asic-chacha.md`).
- **PoW en lugar del VDF** **[LECTURA DE CLAUDE]**: (1) el VDF es secuencial y la ventaja del atacante la
  limita la **física**; PoW es paralelizable y la limita el **presupuesto** — justo al revés de lo que
  conviene contra un ente con recursos; (2) la salida del VDF es única, la de PoW se puede elegir o
  callar, lo que reintroduce el sesgo; (3) una pata de PoW pequeña la domina un Estado y entonces
  **controla la entropía del ancla**, y una grande es una cadena PoW entera — el motivo por el que
  Katana descartó el híbrido el 2026-09-09; (4) su tiempo es aleatorio y el diseño necesita `t_j`
  determinista.
- **Compromiso-revelación con secreto / balizas de umbral**: exigen custodios (un comité) o permiten
  retener. Descartados (`P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`, ficha D; rondas de balizas).

### 2.7 Recomendación de Claude (la decisión es de Katana)

**Adoptarlo como dirección de diseño; todavía NO en el SPEC; y nunca solo.** No cierra ningún ataque por
sí mismo: es el **complemento** del compromiso previo de parcela (le rebaja la edad) y la protección del
ancla frente a un reloj mejor. Antes del SPEC: (1) decidir `ρ_max`; (2) derivar `PRESUP_NODO` con (h)
dentro y tratar C4; (3) reejecutar P-REVELACION. Entra **como paquete** con el compromiso previo.

---

## 3 · El compromiso previo de parcela

### 3.1 Por qué es la pieza de fondo

**Hoy nada en ZEROX ata unos bytes a un momento.** De ahí salen el sembrador, el alquiler corto y la
capacidad relámpago. **Los bytes no envejecen**: ninguna primitiva demuestra «estos bytes tienen un año»
por sí sola. La antigüedad se **construye** con dos mitades **[NO VERIFICADO en fuente esta sesión]**:

- **«no después de `T`»**: un compromiso publicado en la cadena (la cadena es el reloj);
- **«y sigue ahí»**: retos impredecibles posteriores que solo responde quien conserva los bytes.

Es el patrón de Spacemesh (ATX + NIPoST) y de Filecoin (PoRep + WindowPoSt). Chia no lo tiene.

### 3.2 El mecanismo (candidata A1+C1 de `P-ZRX/P-SEMBRADOR/`)

Registrar **antes del reto** raíz, versión, cardinalidad, identidad e historia de la parcela **completa**;
activarla tras una **edad `M`** mayor que la ventana de adelanto; cada solución abre la pieza contra esa
raíz. **Es la única candidata estudiada que ELIMINA el sembrador en vez de encarecerlo**: una parcela
fabricada tras ver el reto no puede estar registrada antes de ese reto.

- **Sobrevive al teorema de identidades gratis** (`research/dag-poas-balizas-auditoria.md:66-75`): ese
  teorema refuta la *exclusividad* entre identidades, no el *fechado*. La edad va en el **compromiso de
  bytes**, nunca en la identidad del granjero.
- **Edad `M`**: como cuantil de la ventana (§2.3). En `F = 2 h`, `ρ_max = 2,5`: q99 de **8 800 slots sin
  segundo VDF, 5 712 con él**. **Esperar horas al registrar una parcela es aceptable** para quien la
  registra una vez y farmea meses: **la edad no es la barrera** **[LECTURA DE CLAUDE]**.

### 3.3 Lo que lo bloquea de verdad

**No existe una prueba sucinta de que el compromiso abarca TODOS los bytes de una parcela Autonomys**
(«C1»). Una raíz sola no basta: se puede comprometer una raíz sin haber calculado las hojas. Es
**criptografía nueva**, y sin ella la herramienta no se puede construir. El verificador actual solo ve
una pieza (`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:228-350`, cita de `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`).

### 3.4 Otras preguntas de diseño abiertas

- **Revoca «sin registro de sectores»**: estado nuevo (acumulador), poda, altas por segundo, y migración
  de la solución. Coste en bytes y CPU **sin determinar**.
- **Unidad de coste por lote y byte, no por identidad**, para no ser regresivo con el granjero doméstico.
- **¿Quién paga el alta de quien entra sin monedas?** Si el registro es una transacción con tarifa, choca
  con «entrar no exige tener monedas». Salida natural: que el alta se pague con una prueba de espacio,
  no con tarifa ni PoW **[LECTURA DE CLAUDE; nadie lo ha estudiado]**.
- **Paridad de reloj como palanca complementaria**: si los timekeepers honestos corren AES en el límite
  físico, `ρ → 1`. Sin segundo VDF hace falta paridad **exacta**; con él basta la **aproximada**.

### 3.5 La alternativa cara: sellado secuencial por sector

Elimina el sembrador **si** el sellado adversarial tarda más que la ventana. Como la ventana es de horas,
el sellado sería de **horas por sector, y lo paga igual el honesto**. Exige parcela y prueba sucinta
nuevas, con riesgo de ventaja ASIC. P-REVELACION corrige a P-ADELANTO: **sigue siendo necesario mientras
la ventana no se anule**. Queda como línea de reserva.

---

## 4 · El atacante con muchos recursos: qué puede hacer hoy

### 4.1 El coste medido del sembrador — `P-ZRX/P-INTENTO/` **[MEDIDO, sin revalidar]**

Ryzen 9 9950X3D, `subspace @ f8842d0`, gobernador `powersave`.

| Magnitud | Cifra |
|---|---|
| Un intento dirigido (generar la tabla de una semilla), 1 núcleo | **809 ms** |
| Reto adicional contra una tabla ya generada | 0,49 µs (1,4 ns en lote) — **la amortización sobre `w` retos es casi gratis: ese es el ataque** |
| Camino que solo paga el intento ganador | 23,0 ms |
| Mejor agregado de la CPU (forma anidada, 8 concurrentes) | **25,03 tablas/s** |
| Lo que queda vivo por tabla | 5 MiB (`Proofs<20>`), no las siete tablas |
| Atajo en el cono de tablas | **no se ha encontrado** (podable ≤ 9,2 %) |
| Control contra los 83,6 s/sector históricos | 90,6 s (1,083×) |
| **GPU** | **NO medida** (GTX 1070 sin `/dev/nvidia*`, sin root) |

### 4.2 El cruce con la ventana real **[LECTURA DE CLAUDE, aritmética sobre los dos instrumentos]**

`N_eq = r · w` piezas de ≈ 1 MiB. `F = 2 h`, reloj atacante 2,5×.

| | `w` | Disco honesto que emula una CPU de 16 núcleos | CPUs para igualar un disco de 20 TB |
|---|---:|---:|---:|
| Sin segundo VDF | 7 686 | 0,18 TiB | **99** |
| Con segundo VDF | 4 866 | 0,12 TiB | **157** |

**Coste ABSOLUTO, por cada PiB de espacio honesto, para el 33 % del total:**

| Ruta | Hardware |
|---|---|
| Comprar discos | **28 discos de 20 TB** |
| Sembrador con CPU (medido) | **≈ 44 000 núcleos** (≈ 69 500 con segundo VDF) |
| Sembrador con GPU (**cifra de la documentación de Autonomys, 17× el ploteo en CPU, NUNCA medida**) | ≈ 160 GPUs |

### 4.3 Lectura

- En **relativo**, el sembrador es ≈ 100× peor que comprar disco. **Eso solo descarta al atacante que
  busca lucro.**
- En **absoluto**, para una red joven **44 000 núcleos es poco**: se alquilan por horas, y un Estado o un
  laboratorio grande los tiene parados. Y el sembrador da dos cosas que los discos no dan: **velocidad**
  (nada que comprar ni plotear antes) y **sigilo** (el espacio de la red no crece antes del ataque y no
  quedan parcelas después). Es el **ataque relámpago sin poseer el recurso**.
- Necesita además un reloj más rápido que el honesto (un ASIC de AES, 1,5–2,5× estimado) y sostenerlo
  durante el *bootstrap*.
- **La cifra medida es una cota SUPERIOR del coste del atacante**: mejor kernel, GPU real o ASIC la bajan.
- **Cómputo gratis (botnet, nube robada) cambia toda la cuenta**: el argumento es económico, no
  criptográfico.

**Conclusión bajo el modelo de amenaza de Katana:** el hueco existe y es alcanzable. **Lo que lo cierra
estructuralmente es el compromiso previo de parcela (§3), no el segundo VDF.**

---

## 5 · La finalidad `F`

- **`F` no es lo que espera un usuario.** Es la regla por la que un nodo **se niega a reorganizar** por
  debajo de esa profundidad (`C-FIN-01`). La espera de un pago la decide cada comercio según importe y
  riesgo (`SPEC.md` §13). Un café se cobra casi al instante: el ataque cuesta órdenes de magnitud más que
  el café. `F` importa a quien mueve cantidades donde atacar sí compensaría.
- **No hay tabla validada de espera de pago** para el diseño destino. Las cifras que existen son de un
  modelo histórico (10 min → ≈ 10⁻⁶; 30 min → astronómicamente pequeño, con `α = 0,33`).
- **Bajar `F` por decreto no acelera nada: degrada la garantía.** Colchón sobre el 33 % **[HISTÓRICO,
  auditoría 9b]**: `F = 2 h` → +11,6 (red buena) / **+2,1** (red mala); `F = 1 h` → +9,0 / **+0,1**.
  `F = 2 h` es la más corta que sobrevive a los seis modelos; `F = 1 h` en producción está condicionada a
  `Δ_p99 ≤ 14,9 s`; `F = 20 min` está por debajo del suelo en todos.
- **Para bajarla de verdad hay que bajar su suelo**, `F = máx(F_carrera, I/(W/κ−1))` **[HISTÓRICO]**:

| Palanca | Efecto |
|---|---|
| **`Δ` de red** (4 → 16 s) | **domina**: ×3,5 (0,28 h → 0,98 h). No se elige: se mide y se mejora |
| `I` por la vía del *steering* (851 → 491 s) | 1,07 h → 0,62 h. La segunda que más pesa |
| Segundo VDF | elimina el término de *steering* entero |
| Aceptar más riesgo (`10⁻¹² → 10⁻⁶`) | −4 a −17 min |
| Ventaja inicial `3k → 1,68k` | −3 a −8 min; diseñar con la medida «no es legítimo» |
| `k` | sin signo propio: **no es palanca** |

  Con `Δ ≲ 12 s` manda el *steering* (y el segundo VDF es la palanca); con `Δ ≳ 14 s` manda la carrera (y
  el problema es la red). **Como `Δ` no está medida, hoy no se sabe en cuál de los dos casos está ZEROX.**

---

## 6 · Lo que falta medir

| Número | Por qué importa | Se puede medir sin red |
|---|---|---|
| **`Δ` real** | Decide `L_suelo_slots`, el suelo de `F`, cuál de sus dos frenos manda y si nace una partición | **No**: exige nodos corriendo. Es lo que obligará a cablear algo antes de cerrar el diseño |
| **`ρ` real** (ventaja de reloj alcanzable) | Decide `ρ_max`, la calibración del segundo VDF y si basta la paridad aproximada | Sí (estudio / estimación de ASIC AES) |
| **`α` de anclas** | Fija la cola de la ventana (rachas) y por tanto la edad `M` | No |
| **Coste del intento dirigido en GPU** | La cifra de P-INTENTO es solo CPU | Sí, con acceso a la GPU |
| **`π_DAG`** (de solución válida a bloque pagado) | Escala todo el margen del sembrador; fijarlo a 1 favorece al atacante | Parcialmente |
| **Falsos fallos domésticos** | Decide si el vesting por permanencia es aceptable o regresivo | No |
| **Mercado de alquiler de parcelas** | Convierte C1 de «plausible» en «medido» | Sí |
| **`PRESUP_PAR` / `PRESUP_NODO`** (cota superior) | Sin ella vuelve el DoS; con (h) hay una partida más | Sí |
| **Estado/bytes/altas del registro de parcelas** | Decide si el compromiso previo es asumible por un nodo | Sí, con prototipo |

El `SPEC.md` declara hoy **13 `<<PENDIENTE>>`** propios; `F_slots` es un **símbolo** (las 2 h son
provisionales de investigación, no del SPEC). `ZEROX-EN-NUMEROS.md` está desactualizado (2026-09-17) y
movido a `.trash/`.

---

## 7 · Estado de la evidencia

| Encargo | Qué dice | Validación |
|---|---|---|
| `P-ZRX/P-RNG/` | No hay coste universal tipo PoW compatible con los valores; tarifar por ataque; recomienda compromiso + edad + vesting | **Sin validar.** No cita CRP-v0.1, el único instrumento medido sobre su misma pregunta; sus citas a `SPEC.md` están desplazadas cientos de líneas |
| `P-ZRX/P-SEMBRADOR/` | El sembrador es válido; la unidad es la pieza; eliminarlo exige compromiso previo completo | Validación parcial previa |
| `P-ZRX/P-ADELANTO/` | **Tesis central REFUTADA** («`A` no depende de `ρ`», «con (h) `A = 0`»). Vale su aritmética y sus avisos sobre C4/`PRESUP_NODO`; no su modelo | Claude lo validó por la mañana **sin contrastar el modelo con la ronda 10a**; rectificado por la tarde. Defectos sin corregir: una cita falsa; `adelanto_D` y `adelanto_sub` con cuerpo idéntico y etiquetas opuestas; test de regresión circular |
| `P-ZRX/P-REVELACION/` | Todo el §2 de este documento | **Documental hecha; reejecución PENDIENTE.** Lo único comprobado en código: su oráculo `Rational{BigInt}` es un algoritmo genuinamente distinto del kernel |
| `P-ZRX/P-INTENTO/` | Todo el §4.1 | **Documental y aritmética; SIN re-medición.** Su informe afirma que ninguna medición se tomó con otra carga pesada: **falso respecto de la máquina** (P-REVELACION corrió en paralelo hasta las 13:27, y una reejecución indebida de Claude hasta las 13:35). La corrida decisiva de escalado es posterior (13:36–13:44) y el mono-núcleo coincide entre corrida contaminada y limpia |
| **CRP-v0.2 y CRP-v0.3** | Declaran **sustituir la evidencia protocolaria de CRP-v0.1**, que es la que sostiene el `α = 1/2` | **Sin validar ni migrar** (`TAREAS.md` §2.9 (e) 15). Rescatadas de `deepseek/` en `P-ZRX/rescate-deepseek/`. **Si desmienten a v0.1, el §1.1 de este documento hay que rehacerlo** |

---

## 8 · Decisiones que tiene Katana delante

1. **`ρ_max`**: qué ventaja de reloj admite ZEROX. Pendiente desde el 2026-09-08. «`3×` sin segundo VDF»
   acota el *steering* pero **no reduce la ventana**.
2. **¿Segundo VDF como dirección de diseño?** (§2.7).
3. **¿Se acepta un registro de parcelas?** Revoca «sin registro de sectores»; es lo que habilita el único
   cierre estructural del sembrador, del alquiler corto y de la permanencia.
4. **`L_suelo_slots`**: no se puede fijar sin `Δ` real.
5. **Forma de la cota de edad**: cuantil con tasa de excedencia explícita, no «sup».
6. **Qué hacer con CRP-v0.2/0.3**: validarlas o declarar por qué no aplican.

## 9 · Encargos siguientes que propone Claude, por orden

1. **Criptografía — prueba de cobertura completa de una parcela Autonomys (C1).** Es lo que bloquea el
   único cierre estructural. Investigación, no medición: ¿existe una prueba sucinta?, ¿a qué coste?,
   ¿qué cambia del formato?
2. **R-FIN-13′ con P2/P3** (agujero A2): especificar el controlador de rango anclado al flujo canónico.
   Es el otro vector medido que mueve el umbral y sigue fuera del SPEC.
3. **`PRESUP_NODO` y el vector C4 con el segundo VDF dentro.** Condición para que (h) entre en el SPEC.
4. **Red y eclipse (D2).** Modelado históricamente en la ronda 11b, **sin integrar ni validar para el protocolo
   vigente**; según el propio repositorio, la palanca real de un Estado.
5. **Validar CRP-v0.2 y v0.3.**
6. **Re-medir P-INTENTO con la máquina en reposo y con acceso a la GPU; reejecutar P-REVELACION.**
7. **`ρ` real**: localizar el estudio de Supranational o estimar el ASIC de AES con fuente.

Y, fuera de los encargos: **escribir en código lo ya decidido** (`C-FLU-*`), cuando Katana dé por cerrada
la fase de diseño. Katana ha fijado ese orden: primero cerrar el diseño, después cablear.

---

## 10 · Rectificaciones de Claude durante la sesión (para que nadie herede el error)

1. Resumió P-RNG con más certeza de la debida: dijo que compromiso + vesting cubría el *grinding* (el
   informe dice lo contrario) y que el castigo por doble billete estaba listo (hoy no es fraude).
2. **Validó P-ADELANTO sin contrastar su modelo central** con la ronda 10a y transmitió dos conclusiones
   falsas («el adelanto no depende del reloj», «con el segundo VDF la edad colapsa al margen»). Lo
   detectó al preparar P-REVELACION y lo dijo antes de entregar ese encargo.
3. Sobre el segundo VDF osciló: «no prioritario» → «prerrequisito» → «optimización» → «dirección de
   diseño, como paquete». La posición que queda es la del §2.7.
4. Lanzó por su cuenta una reejecución mientras P-INTENTO medía tiempos en la misma máquina.
5. Escribió «un ataque que nadie va a montar» a partir de un argumento de rentabilidad. **No es un
   argumento de seguridad** bajo el modelo de amenaza de Katana (§0).
6. Afirmó que, con doble farmeo, «el atacante no necesita discos propios». **Falso** (corrección de Codex):
   con `α` propio y `β` honesto trabajando en ambas ramas, la privada solo gana si `β > 1 − 2α`; con
   `α = 0` es imposible. Detalle, umbral `α* = (1 − β)/2` y otras tres frases retiradas en
   `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md`, anexo §A.1.
7. Escribió que el eclipse «no está modelado por nadie» y que el nodo nuevo «depende de un checkpoint».
   **Las dos cosas eran falsas** (corrección de Codex, verificada): el eclipse se modeló en la ronda 11b
   —falta integrarlo y validarlo para el protocolo vigente— y un nodo nuevo siempre puede validar desde el
   génesis —falta el arranque sucinto—. Claude se apoyó en una nota del 2026-09-08 anterior a la ronda 11b
   sin buscar antes. Además, al recapitular comprimió salvedades y presentó mitigaciones con palabras de
   cobertura («lo elimina», «cierre», «protege el ancla»): **todo lo de este documento son propuestas o
   candidatas, no cobertura demostrada.**

---

## Ver también

- `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md` — la solución candidata al problema de la
  reutilización del espacio entre ramas (texto de Codex, 2026-09-21): registro de parcelas por lote,
  maduración, recompensas retenidas y castigo de la doble firma estrecha. Posterior a este documento:
  el hueco C3 de §1.3 debe leerse junto con ella.
- `P-ZRX/T-ZRX/MEJORA-IDENTIDAD-DE-BILLETE.md` — **cambiar la identidad de billete** (2026-09-21, de
  `P-ZRX/P-PRESTAMO/`): un **cambio de definición**, no un mecanismo nuevo, que convertiría el doble
  farmeo en la infracción **por construcción** y **haría innecesario el mecanismo de castigo**. Afecta a
  los huecos C1–C3 de §1.3 y a la candidata de `SOLUCION-CANDIDATA-REUTILIZACION.md`. **Candidata por
  comprobar:** lo verifica `P-ZRX/P-IDENTIDAD/`.
