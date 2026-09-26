# INFORME — SL-1: contrato de evidencia y castigo v0 y especificación del firmante seguro

**Orden:** `P-ZRX/P-SLASHING/ORDEN-SL1-CONTRATO.md`. **Ejecutor:** subagente Sonnet. **Fecha:**
2026-09-26. **Entregable hermano:** `deepseek/SL1/CONTRATO-EVIDENCIA-v0.md` (reglas `EV-*` y `FIR-*`).

---

## 1 · Respuesta a la pregunta falsable

> «Existe un conjunto de reglas de evidencia y castigo que (a) castiga toda doble firma demostrable
> una sola vez por incidente, (b) no castiga nunca a un productor que usa el firmante seguro, ni
> siquiera tras reiniciar o reorganizar, y (c) no deja a un infractor retirar su garantía antes de
> que la evidencia pueda llegar. Se refuta con un contraejemplo concreto a (a), (b) o (c).»

**Refutada. Hay contraejemplo concreto a (a) y a (b); (c) se sostiene, pero solo de forma
condicional a un parámetro (`R_slots`) y a una regla adicional que este informe tuvo que añadir
(`EV-15b`) porque el diseño heredado no la tenía.**

### 1.1 · Contraejemplo a (a)

El contrato **tiene que** tener una ventana de admisión finita para poder satisfacer (c) (si la
ventana fuera infinita, ninguna garantía podría liberarse nunca sin riesgo). Esa ventana finita
implica, por construcción, que una doble firma real y demostrable puede quedar **sin castigo** si la
evidencia llega tarde:

- `P` firma `H1` en `sf = 10 000` y, en una rama que censura o retiene la segunda cabecera (o que
  simplemente tarda en propagarse — `C-EVP-05` ya lo declara: «no garantiza que una prueba difundida
  entre en una historia aceptada»), `H2` solo se hace pública en el slot `12 000`.
- Con cualquier `Plazo_slots < 2 000` (un valor razonable: el propio `SPEC.md` usa `S_max = 150`
  slots como orden de magnitud para ventanas de producción), la `EvidenceTx(H1, H2)` llega con
  `slot_aplicacion ≥ sf + Plazo_slots`, cae en `EV-14` y se descarta como tardía.
- `H1` y `H2` son, en cualquier momento posterior, cabeceras perfectamente verificables: mismo
  `TicketId`, `pre_hash` distintos, dos sellos Ed25519 válidos bajo la misma clave. La doble firma
  **es demostrable**. No se castiga **ninguna** vez.

Esto no es un defecto de esta orden: está ya en `D-ZRX/SPEC.md` §5 `C-EVP-05` (que esta orden no
podía reabrir) y es la misma tensión que `C-BON-05` documenta al exigir `R_slots` finito. Es,
además, la misma limitación que la síntesis de disuasión ya declara en otra forma: censura de la
prueba, partición, o una rama privada que solo se revela tarde escapan al castigo por diseño
(`P-ZRX/P-DISUASION/SINTESIS.md` §2, «censura, eclipse... Ninguna por C-SLA», tabla de
`D-ZRX/SPEC.md` §7). **No es un hallazgo nuevo** que (a) sea imposible en sentido absoluto; sí es
importante decirlo explícitamente como respuesta a la pregunta falsable, porque la pregunta pide
exactamente eso.

### 1.2 · Contraejemplo a (b)

`P` opera con disciplina perfecta: instala el firmante seguro (`FIR-01…FIR-10`), nunca firma dos
veces la misma oportunidad desde su máquina, y sobrevive incluso a un corte de energía a mitad de
escritura (`FIR-03`, demostrado por test con `SIGABRT`). Un tercero obtiene la clave privada de `P`
—robo, copia de una copia de seguridad de la clave (no del registro), o un custodio de pool
negligente— y la usa en una **segunda** máquina, sin acceso al registro de `P` (`FP6`,
`FALSOS-POSITIVOS.md`). Esa segunda máquina firma `H2` para la misma identidad y slot que `H1`
(firmada legítimamente por `P`). `pre_hash(H1) ≠ pre_hash(H2)` (padres o cuerpo distintos), ambos
sellos verifican bajo `sol.public_key = P` (es literalmente la misma clave). `EV-06` y `EV-07` se
cumplen: hay evidencia. `EV-17`/`EV-19` congelan y confiscan el saldo de `P`.

`P` usó el firmante seguro exactamente como se especifica, en la única máquina que controla, y
nunca autorizó una segunda firma. Aun así, su garantía se pierde. **Es exactamente lo que
`FIR-13` declara sin suavizar** («el castigo cae sobre el saldo de la clave, no sobre quién
firmó») y lo que `ESPECIFICACION.md` §3.4 y `CANDIDATA.md` §«Corrección C3» ya anticipaban como
límite estructural: el firmante seguro es un filtro de **accidentes honestos con un único operador
y un único registro**, no una defensa contra una clave que deja de ser exclusiva de su titular. No
hay forma de evitarlo sin una identidad económica distinta de «la clave que firma» (fuera del
alcance de esta orden — es justo el punto que `DEFINICION-PROPUESTA.md` deja para «otra decisión»).

### 1.3 · (c) se sostiene, condicionalmente — y solo tras una corrección

La orden pide exactamente la desigualdad `R_slots > plazo + margen`, y el contrato la escribe como
`EV-15`. Al derivarla contra el resto de las reglas (retiro parcial + producción continuada,
`FORMATO-v0.md` F-07 tipo 2 permite un `importe` parcial), encontré que **`EV-15` sola no basta**:
un atacante con una retirada parcial en curso puede seguir produciendo con el saldo activo restante
y cronometrar su doble firma cerca del final de la ventana de retención, de modo que la ventana de
admisión de **esa** falta (`sf + Plazo_slots + M_margen_slots`) se cierre **después** de que la
liberación ya se haya completado (`t0 + R_slots`). Ninguna de las fuentes leídas —`CONTRATO-v0.md`
(`C-BON-05`), `P-PRESTAMO`, `P-CLAVE`, la síntesis de `P-DISUASION`— señala este caso: es un
**hallazgo de esta orden**, no una repetición.

He añadido `EV-15b`/`EV-24(ii)` para cerrarlo: la liberación exige, además de `R_slots` desde el
retiro, que hayan pasado `Plazo_slots + M_margen_slots` desde el **último** slot en que `P` produjo
cualquier bloque. Con esa regla, (c) se sostiene **estructuralmente**: ninguna liberación de `P`
puede completarse mientras exista una ventana de evidencia todavía abierta para algo que `P` firmó.

**Pero (c) sigue siendo condicional a un hecho que esta orden no controla:** nada en el motor de
consenso obliga, por sí solo, a que quien fije `R_slots`, `Plazo_slots` y `M_margen_slots` respete
la desigualdad. Es una restricción **declarada**, no una comprobación en tiempo de activación. Si
SL-2 (o quien ratifique después) elige valores que la violan, (c) deja de sostenerse sin que ningún
mecanismo lo impida. **Recomendación de este informe** (no una decisión que yo pueda tomar: cambia
el trabajo de SL-2/SL-4): que la activación del mecanismo compruebe `R_slots > Plazo_slots +
M_margen_slots` como una puerta más, del mismo tipo que `Φ` en `CONTRATO-v0.md` D-T04, y rechace
activarse si no se cumple — así (c) deja de depender de que nadie se equivoque calibrando.

---

## 2 · Decisiones que el director tiene que tomar

Estas dos son bifurcaciones reales: cualquiera de las opciones es coherente con el contrato tal
como está escrito (§2 y §6 de `CONTRATO-EVIDENCIA-v0.md` no cambian de forma, solo de contenido), y
llevan a trabajo materialmente distinto en SL-2/SL-3/SL-4. Las decisiones ya fijadas por la orden
§3 (única falta, sin correlación, formato v4, congelación≠confiscación) no se reabren aquí.

### Decisión 1 · Identidad de oportunidad: la vigente (`C-GD-07`) o con dominio de red (IDV-01)

| Opción | Qué implica de verdad | Coste |
|---|---|---|
| **A. Mantener la vigente, `(public_key, sector_index, history_size, chunk, slot)`, sin dominio de red** | Es la que ya usa todo el consenso (`C-GD-07`) y la coinbase (`C-BON-03`); no exige tocar nada más. **Deja abierta FP8**: el mismo billete en dos redes (mainnet/testnet, o dos redes de prueba paralelas) colisiona y produciría evidencia falsa entre redes distintas si alguna vez coexisten | Cero coste de implementación adicional; el coste es un riesgo latente que solo se materializa si de verdad hay más de una red activa con las mismas claves — algo que hoy (una sola red dev) no ocurre, pero que sí puede ocurrir en cuanto exista testnet + mainnet |
| **B. Adoptar la variante con dominio (IDV-01/`TicketConRed`)** | Cierra FP8 de forma permanente; el prototipo ya la implementa y prueba que no comparte espacio de claves con la vigente (`el_punto_de_extension_funciona_con_dos_implementaciones`) | Exige fijar **qué es** el dominio de red/era (un valor más que decidir y congelar, con su propio riesgo de error de codificación) y decidir si esa identidad **económica** (para el castigo) diverge de la identidad de **billete** que usa `C-GD-07` para el pago — si divergen, hay que analizar si eso abre un hueco nuevo (dos identidades distintas para la misma solución PoAS es exactamente lo que `C-EVP-01` advierte que no se puede hacer sin cambiar a la vez el pago) |

**Mi recomendación: A por ahora, con un candado explícito.** El coste de B no es solo técnico: exige
decidir la semántica de «dominio de red» en un momento en que ZEROX **todavía no tiene una segunda
red real** (todo es red dev, `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`) — decidirlo ahora es decidir sin el
caso concreto delante. La vigente ya es la identidad de todo lo demás (pago, admisión); usarla
también aquí evita mantener dos definiciones de «la misma oportunidad» en el sistema mientras no
hace falta. El candado: si se activa una segunda red con las mismas claves posibles (un puente entre
redes, o una migración con continuidad de clave) **antes** de resolver esto, hay que migrar a B
primero — dejarlo para entonces es aceptable porque el prototipo ya demuestra que el cambio es
«añadir una variante al `enum`», no reescribir el registro.

### Decisión 2 · Destino de los fondos confiscados

| Opción | Qué implica de verdad | Coste / incentivos |
|---|---|---|
| **A. Quemar** | Reduce `Emitido − Quemado` (ya contemplado en la invariante `I-1` de `CONTRATO-v0.md`); no crea ningún beneficiario | **Sin incentivo a incluir la evidencia.** Nadie gana nada por gastar peso de bloque en una `EvidenceTx`; un productor que preferiría no denunciar a un colega (o a sí mismo, si comparte pool) simplemente no la incluye. `C-EVP-03` ya prohíbe un campo de denunciante con recompensa, así que esta opción es la más simple de justificar frente a esa regla, pero **hereda su problema**: sin incentivo, no hay razón para suponer una probabilidad positiva de inclusión (`C-SLA-03`, último párrafo, ya lo dice: «sin incentivo ni obligación verificable no se presume una probabilidad positiva suficiente») |
| **B. Recompensar a quien incluye el bloque que aplica la `EvidenceTx`** (una fracción de `f·V` va a la coinbase de ese bloque, el resto se quema) | Da a **cualquier** productor —no solo a quien descubrió la evidencia— un motivo para incluirla en cuanto la vea en su mempool; no exige un campo de denunciante (la recompensa es para quien produce el bloque, un rol que ya existe y ya cobra coinbase, `C-BON-03`) | **Riesgo de autodenuncia rentable**: si `f·(recompensa) > `pérdida marginal para el propio infractor» en algún caso degenerado (saldo casi agotado, por ejemplo), un productor podría autoincluir su propia evidencia para cobrar la fracción — hay que acotar la recompensa para que nunca sea mayor que lo que el infractor pierde, cosa que `mín(V, techo_exacto(f·V))` ya impone como techo, pero falta decidir la fracción exacta que se lleva el incluidor (parámetro nuevo para SL-2, no cubierto por `f`) |
| **C. Mezcla (parte se quema, parte a un fondo de red no atado a quien incluye)** | Evita el riesgo de autodenuncia de B sin perder toda la señal económica de A | Añade una tercera cuenta agregada al estado de consenso (`Estado(h)`, `CONTRATO-v0.md` §3) que hoy no existe — más superficie de código y de invariantes que probar, para un beneficio que ninguna fuente leída cuantifica |

**Mi recomendación: A para v0, con B como candidato explícito para cuando exista una calibración de
SL-2 que acote la fracción del incluidor.** Razón: `C-EVP-03` ya fija «no hay campo de denunciante
sin recompensa» como decisión previa del propio documento base (no de esta orden), y quemar es la
única opción de las tres que no necesita decidir **ningún** parámetro nuevo ni analizar el riesgo de
autodenuncia antes de poder ratificarse. El coste de A —que nadie tenga incentivo económico directo
a incluir la prueba— ya está parcialmente mitigado por algo que ninguna de las tres opciones cambia:
el **productor mismo** que ve dos cabeceras contradictorias de un rival tiene un incentivo
**competitivo** (no monetario) a incluir la evidencia si el infractor es alguien que le compite por
espacio de bloque o por posición en el DAG; eso no está medido y no debería presentarse como
garantía, pero es la razón por la que no creo que A deje la inclusión en cero. Si SL-2 mide que la
tasa de inclusión bajo A es insuficiente, B es la vía más simple para revisarlo sin tocar el resto
del contrato: `EV-23` ya está escrita para admitir cualquiera de las tres sin cambiar EV-01…EV-22.

---

## 3 · Lo que este informe encontró y no estaba en ninguna fuente leída

- **El hueco de retiro parcial + producción continuada** (§1.3, `EV-15b`): la desigualdad
  `R_slots > Q_corr + T_reporte + M_estab` de `CONTRATO-v0.md` (y su reescritura `R_slots > Plazo +
  margen` que pide esta orden) cierra el caso «falta, luego retiro», pero no el caso «retiro, luego
  falta, cronometrada contra el propio retiro». Ninguna de `CONTRATO-v0.md`, `P-PRESTAMO`,
  `P-CLAVE`, `P-DISUASION/SINTESIS.md` lo señala. Se cierra con una segunda condición sobre
  `último_slot_producido(P)`, no con un valor distinto de `R_slots`.
- **La simplificación de C-SLA-01 al quitar la correlación** (§0 de `CONTRATO-EVIDENCIA-v0.md`): con
  `f` fija por incidente, toda la maquinaria de cohortes (`Q_corr_slots`, `e`, `n_e`, cierre de
  cohorte) deja de tener función. Esto no estaba dicho explícitamente en la orden ni en `SPEC.md`
  (que describe `C-SLA-01` como si siguiera haciendo falta): es una consecuencia de la decisión §3.2
  del director que hay que declarar para no arrastrar una regla vacía a SL-3.

## 4 · Lo que NO se cierra en este contrato (ya declarado en las fuentes, no un hallazgo nuevo)

- La grieta de `DS-3`/`P-CLAVE`: un atacante que recluta claves de saldo cero cruza la deriva a
  soborno cero; `EV-22` lo hereda explícitamente («la clave sin saldo no se inventa una
  confiscación») porque `C-EVP-04` ya lo decide así.
- El atacante grande autosuficiente que nunca publica su rama perdedora: no hay `EvidenceTx` posible
  porque no hay segunda cabecera pública (`D-ZRX/SPEC.md` §0, R-1/R-6; `P-DISUASION/SINTESIS.md`).
- La censura de la prueba una vez existe: cubierta parcialmente por §1.1 de este informe.

---

## 5 · Rutas

- Contrato: `/home/katana/zeo/ZEROX/deepseek/SL1/CONTRATO-EVIDENCIA-v0.md`.
- Este informe: `/home/katana/zeo/ZEROX/deepseek/SL1/INFORME.md`.
- Entradas principales leídas: `P-ZRX/P-SLASHING/PROGRAMA.md`, `P-ZRX/P-SLASHING/ORDEN-SL1-CONTRATO.md`,
  `D-ZRX/SPEC.md` §§0–10, `D-ZRX/IPA-ZRX.md`, `D-ZRX/SPEC-0.0.1.md`,
  `P-ZRX/P-DISUASION/{SINTESIS,REVISION-DS2,REVISION-DS3,REVISION-DS5,REVISION-DS6,CORRECCION-DS6-A}.md`,
  `P-ZRX/P-TRANSICION/CONTRATO-v0.md`, `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`,
  `P-ZRX/P-FORMATO/FORMATO-v0.md`,
  `.trash/zerox/P-ZRX/P-EQUIVOCACION/investigacion/{FALSOS-POSITIVOS,DEFINICION-PROPUESTA}.md`,
  `.trash/zerox/P-ZRX/P-FIRMANTE/{PROMPT.md,informe/{INFORME,INTEGRACION}.md,prototipo/src/*.rs}`,
  `.trash/zerox/P-ZRX/P-PRESTAMO/{CANDIDATA,ADENDA-1,investigacion/INFORME}.md`,
  `.trash/zerox/P-ZRX/P-CLAVE/{CANDIDATA,investigacion/INFORME}.md`,
  `git show 9681061:crates/zx-consensus/src/firmante/{mod,alta,identidad,registro}.rs`.

**Aviso de fuente:** `P-ZRX/P-FIRMANTE/ESPECIFICACION.md` está, byte a byte, duplicado de
`P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md` (mismo `sha256`, comprobado). Es la copia
congelada que el propio `PROMPT.md` de P-FIRMANTE describe («copia congelada… ya validado»), no un
error de esta orden; se cita indistintamente por cualquiera de las dos rutas.
