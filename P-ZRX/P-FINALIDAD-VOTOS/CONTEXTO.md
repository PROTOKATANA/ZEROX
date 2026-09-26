# P-FINALIDAD-VOTOS — Contexto: la conversación del 2026-09-26 con Katana

**Fecha:** 2026-09-26. **Autor:** Claude (director). **Qué es:** el razonamiento que llevó a R1–R5 y a este
programa, tal como se habló con Katana. **Qué no es:** un conjunto de resultados. Lo marcado **[lectura del
director]** es hipótesis que FV-1 tiene que confirmar o refutar; cada dato externo lleva entre corchetes de dónde sale y si es fuente primaria o secundaria;
lo que viene de documentos del repositorio cita su ruta.

---

## 1. La pregunta de partida

Tras P-DISUASION quedó abierta esta decisión: *«Doble farmeo: ningún mecanismo lo encarece frente al atacante
grande. ¿Se acepta como riesgo declarado de 0.0.1 o se investiga un cambio de familia?»*

La pregunta, tal como el director la formuló, añadía: *«según Baig y Pietrzak, solo lo cerraría algo como
registro + BFT (Filecoin)»*. **Eso era falso, y se corrigió en la propia conversación.** Baig y Pietrzak
(FC 2025, arXiv:2505.14891) dicen que Filecoin escapa a *su* imposibilidad —el ataque por *replotting*— usando
BFT en vez de cadena más larga. El doble farmeo de ZEROX es otro vector: la refutación de A1 en ZEROX «no
depende del resultado de Baig-Pietrzak… son dos vectores distintos» (`P-ZRX/P-DISUASION/resultados-DS2/INFORME.md`
§2.5). Y tampoco un BFT lo cierra (§4).

---

## 2. El doble farmeo: no tiene cierre, pero sí se puede mitigar

### 2.1 Por qué no hay cierre (lo establecido)

- **La rama privada no deja rastro.** Ninguna condición de validez sobre `past(B)` obliga a publicar; es un
  teorema de P-SECRETO (`D-ZRX/RFT-ZRX.md` RFT-01). «Firmar solo lo visto» es conducta, no consenso.
- **Nueve vías cayeron** (`ESTADO-DOBLE-FARMEO.md`): identidad por pieza, castigo por clave, castigo por
  parcela, maduración por registro, anclaje a la ancestría, tasa por identidad, trabajo rival, sellado
  asimétrico y secreto.
- **El atacante grande no deja evidencia ni publicando.** Con `m ≥ 4` soluciones ganadoras por slot usa
  billetes distintos en cada rama y `κ = 0` (RFT-02).
- **Ningún registro, PoRep ni auditoría separa las ramas** de un objeto determinista y público (RFT-06).
  **Un VDF por rama se paraleliza** entre ramas (RFT-09).
- **Ningún mecanismo de PoStake ni de Filecoin lo encarece** de forma exigible frente al atacante grande con
  espacio propio: ni la garantía, ni el castigo con evidencia, ni el castigo correlacionado
  (`P-ZRX/P-DISUASION/SINTESIS.md`, DS-1…DS-6).

### 2.2 Lo que NO está establecido

- **«No tiene cura» en absoluto.** RFT-01 se declaró **no exhaustivo** (R-6), y hay una vía **aparcada, no
  refutada**: la rivalidad del recurso, con el ancho de banda como mejor candidato (apéndice de
  `LIBRO-DE-RESTRICCIONES.md`, conjetura sin validar). Lo honesto es decir **«no hay cierre conocido»** y que
  la mitigación de este programa es **lo mejor que conocemos**, no lo mejor posible.
- **La magnitud del daño.** No es medible hasta cablear el nodo (IPA B-04).

### 2.3 La mitigación: tres piezas que se suman

| Pieza | Qué parte del doble farmeo arrincona | Estado |
|---|---|---|
| **O4**: la coinbase paga solo a la clave de la solución (`C-BON-03`) | Quita el espacio prestado gratis (pools que firman a ciegas) | En `SPEC.md` |
| **Castigo con evidencia y retención** | Encarece al que recluta espacio ajeno, si el espacio está concentrado como en un pool real de Chia (DS-6) | `P-SLASHING` (SL-1 y SL-2 revisados) |
| **Capa de finalidad por votos bajo R1–R5** | Lo reduce en el tiempo: de `F` de historia a la franja aún no sellada | Este programa |

**El residuo, a declarar como riesgo:** el atacante grande con espacio propio suficiente, dentro de la franja
aún no sellada. Ninguna de las tres piezas lo alcanza.

**Conclusión de Katana:** *«El doble farmeo no se soluciona pero sí se arrincona, es decir se mitiga su impacto,
y supongo que es lo mejor a lo que podemos aspirar ya que visto lo visto el doble farmeo no tiene cura.»* El
director la matizó con §2.2: es lo mejor **conocido**.

---

## 3. Los comités: del «no» a R1–R5

### 3.1 La regla antigua y el problema

- Katana, 2026-09-10: *«Descarta todas aquellas opciones que impliquen un comité central que tome decisiones;
  busco descentralización y seguridad.»* La ronda 14C definió comité como *«conjunto de participantes, fijo o
  muestreado, cuyos votos/firmas deciden el resultado de consenso»*, incluidos los conjuntos de validadores con
  stake (`R-ZRX/LEGADO/stake/MAPA.md` §3).
- Por esa regla, `SPEC.md` §0 excluye la votación de finalidad, y el mecanismo más fuerte del mapa de stake
  —finalidad tipo Casper— quedó sin evaluar.
- Katana, en esta conversación: *«¿existe algún mecanismo de comités que no sea centralizado? Quizás si
  existiera un comité descentralizado donde se elija a los miembros del comité en base a x métricas. Lo que no
  me gusta de los comités es que centralizan el poder/decisión y yo quiero que zerox sobreviva sin una entidad
  o sujeto de respaldo… nadie es indispensable, si alguien sale o desaparece el zerox sigue adelante.»*

El rechazo apunta a **dos propiedades**, no a la palabra: que **alguien decida** y que **alguien sea
indispensable**.

### 3.2 Lo que centraliza: elegir miembros por métricas

Es el modelo DPoS. EOS elige por votación a los 21 productores más votados, y acabó en cárteles y compra de
votos **[fuentes secundarias consultadas hoy]**. No es mala suerte, sino estructura:

- **Una métrica medida fuera de la cadena** necesita a alguien que la mida, que es la entidad que se quería
  evitar.
- **Una elección** trae campaña, alianzas y compra de votos.
- **Un grupo pequeño y conocido** es sobornable y es un blanco de denegación de servicio.

La única «métrica» sin árbitro es **el propio recurso, verificado en la cadena**.

### 3.3 Lo que no centraliza: el comité es todo el mundo

- **F3 de Filecoin** **[FIP-0086: citas literales recogidas en `research/dag-poas-capa-finalidad.md`; el
  umbral de 1/3, de la documentación de Filecoin vía buscador]**: participan todos los proveedores, ponderados por su poder de
  almacenamiento. Un tipset queda finalizado cuando lo firman más de 2/3 de ese poder, y el protocolo tolera
  menos de 1/3 bizantino. Nadie elige a nadie. Es el mismo reparto de poder que ya tiene la producción de
  bloques.
- Si hay demasiadas firmas, se puede usar un **sorteo secreto** por ronda, ponderado por el recurso.
- **Dos libros** (*ebb-and-flow*): la cadena de siempre nunca espera a los votantes; los votos solo sellan un
  prefijo de lo ya producido. F3 funciona así sobre el consenso de base de Filecoin, que sigue operando si F3
  se detiene **[cita literal de FIP-0086 recogida en la propuesta antigua]**.

### 3.4 ¿Es un comité?

Katana preguntó: *«¿esta mitigación usa un comité? Creo recordar que dijiste que todos eran el comité.»*

Respuesta del director: **sí, el comité son todos, y técnicamente sigue siendo un comité, pero no del tipo que
Katana rechazaba.**

**Por qué técnicamente es un comité.** La ronda 14C (2026-09-10) define comité como *«conjunto de
participantes, fijo o muestreado, cuyos votos/firmas deciden el resultado de consenso»*. Un grupo que vota
para sellar la finalidad entra en esa definición. Por eso R1–R5 **sustituyen** a la regla «sin comités» en
lugar de encajar en ella, y hay que decirlo así, sin rodeos.

**Por qué no es el comité que Katana no quería:**
- **No hay un grupo aparte.** Votan los mismos cultivadores que producen bloques, cada uno con el peso de su
  espacio, igual que en la producción de bloques.
- **Nadie elige a nadie:** no hay candidatos, ni campañas, ni cargos.
- **Nadie es indispensable.** La cadena no espera a los votos; si los votantes desaparecen, solo se pausa el
  sello.
- **No deciden el contenido.** Solo pueden sellar lo que la cadena ya produjo (R4).

**Solo una de las tres piezas de la mitigación usa votos.** La recompensa atada a la clave que firma (O4) y el
castigo con evidencia funcionan sin ningún comité.
- **Dos puntos donde «todos» puede dejar de ser verdad**, y que FV-1 tiene que resolver:
  - **Sorteo por ronda.** La propuesta antigua no hacía votar a todos: sorteaba 4 000 plazas por ronda, y solo
    entre quienes habían ganado un bloque en los últimos 30 minutos. Es aleatorio y rota, pero es un
    subconjunto, y ese filtro puede violar R1.
  - **Delegación del voto.** Si los granjeros ceden su clave de voto a un servicio, aparece un comité **de
    hecho**, como pasó con los pools. Es el ataque 7 de la orden.

### 3.5 Otros comités, y la elección de Katana

Katana preguntó qué otros comités existen y cuáles darían mejores resultados.

| Tipo | Ejemplo | ¿Pasa R1–R5? | Por qué no, o qué cuesta |
|---|---|---|---|
| Fijo o con permiso | BFT clásico, cadenas de consorcio | No (R1, R2) | Es el más rápido y simple, precisamente porque centraliza |
| Elegido por votación | DPoS (EOS, 21 productores) | No (R2) | Cárteles y compra de votos |
| Los N más grandes | Conjuntos activos de algunas cadenas PoS | No (R1) | El pequeño nunca vota (con Zipf, 400 de 10.000 cubren el 67 %, según la propuesta antigua) |
| Federación o anclaje externo | Federaciones de puentes; puntos de control en Bitcoin | No | Depende de alguien o de algo externo |
| Confianza subjetiva | Stellar, Ripple | No (R2) | La seguridad depende de a quién elige confiar cada nodo, y tiende a concentrarse |
| Muestreo repetido sin firmas | Avalanche | No (R5) | Sin firmas contradictorias que castigar ni certificados |
| Todos, ponderados por el recurso | Casper, F3 | Sí | Muchas firmas; 2/3 del peso total encendido en cada momento |
| Sorteo secreto ponderado | Algorand | Sí, en esperanza | El pequeño vota con probabilidad proporcional a su espacio |
| Productores recientes | Hybrid consensus (Pass y Shi), ByzCoin, propuesta antigua | Sí, en esperanza | Peso con ruido y sesgable reteniendo bloques |

Los comités que mejor rinden en velocidad y sencillez son justo los que centralizan: renunciar a ellos tiene un
coste real, y es el que Katana eligió pagar. Límite de principio: ningún diseño puede a la vez seguir
funcionando con participación fluctuante y dar un sello que deje culpables identificados cuando se rompe (el
dilema entre disponibilidad y responsabilidad de Neu, Tas y Tse). La respuesta son los dos libros de R3.

**Primera elección de Katana**, sobre la recomendación del director: una mezcla. **La sustituyó después el
diseño de §3.6**; se conserva porque su riesgo es el extremo `b → ∞` de ese diseño.
- **Peso:** sectores registrados con garantía, para que R5 tenga algo que castigar.
- **Votantes:** sorteo con probabilidad proporcional al espacio, entre quienes han demostrado buena
  disponibilidad estando encendidos. Así no se depende de que el 89–95 % de los honestos tenga el PC
  encendido.
- **Katana preguntó si quien ha ganado bloques hace poco también debe estar.** Respuesta: sí, como **prueba de
  disponibilidad alternativa**, pero no la única ni con peso extra. Si fuera la única, el pequeño quedaría
  filtrado dos veces por su espacio (para ser elegible y en el sorteo).

**Riesgo que el director no dijo al recomendarla y declaró después:** sortear entre los disponibles hace que la
seguridad dependa de cuántos honestos estén encendidos. La cuota del atacante entre los elegibles es
`a / (a + (1−a)·p)`:

| Atacante `a` | `p = 1,0` | `p = 0,8` | `p = 0,6` | `p = 0,4` | `p` con la que llega a 2/3 |
|---:|---:|---:|---:|---:|---:|
| 0,20 | 0,200 | 0,238 | 0,294 | 0,385 | ≤ 0,125 |
| 0,25 | 0,250 | 0,294 | **0,357** | **0,455** | ≤ 0,167 |
| 0,30 | 0,300 | **0,349** | **0,417** | **0,517** | ≤ 0,214 |

En negrita, cuando supera el tercio. La propuesta antigua ya había descartado este efecto con el nombre «⅔ de
los presentes». Además, el atacante puede expulsar a honestos censurando sus pruebas de disponibilidad.
**Defensa propuesta, a medir por FV-1:** un suelo de representatividad `E` (solo se sella si el peso elegible es
al menos `E` del total). Con él, el sello aguanta si `a < E/3`: con `E = 0,75`, hasta un 25 %; con `E = 0,9`,
hasta un 30 %. `E` es el dial entre viveza y seguridad; «votan todos, 2/3 del total» aguanta hasta un tercio,
pero exige 2/3 del peso encendido en cada momento.

### 3.6 ¿Votan todos? El diseño final de Katana

Katana preguntó si todos seguirían votando, dado que antes se dijo que «todos eran el comité».

- **Aclaración.** En F3 y en Casper sí votan todos: en F3 cada participante vota en cada ronda; en Ethereum
  cada validador vota una vez por época, repartidos en turnos. Con sorteo (Algorand, la propuesta antigua y la
  mezcla) **solo vota la muestra de cada ronda**, y «todos son el comité» pasa a significar que **todos entran
  en el sorteo**, como un jurado popular sacado del censo. El director cambió de diseño sin decirlo con
  claridad.
- **Matiz de palabras.** Los votantes no se eligen «por métricas»; salen de un sorteo ponderado por el
  recurso. Elegir por métricas es lo que R2 prohíbe.

**Diseño que quiere Katana:**
1. Entran en el sorteo **todos los registrados**, no solo los encendidos.
2. **Sorteo secreto** en cada ronda, como en Algorand (**AGR1**): nadie sabe quién vota hasta que ya ha votado.
3. **Probabilidad proporcional al espacio registrado.**
4. Quien ha **demostrado estar encendido** (o ha ganado un bloque hace poco) tiene **más probabilidad** de
   salir: multiplica por una prima `b`.

**Opinión del director.** Es mejor que «solo los encendidos», por dos razones:
- R1 se cumple exactamente, porque nadie queda fuera.
- La fracción de plazas del atacante tiene techo aunque censure todas las pruebas de los honestos:
  `a·b / (a·b + 1 − a)`.

El precio es que **el atacante siempre está encendido y siempre cobra la prima**, así que `b` es un dial.
Cifras con `a = 0,25` (esperanzas, sin la varianza del sorteo):

| Prima `b` | Atacante, con 80 % de honestos encendidos | ¿Sella con 80 %? | Atacante si censura todas las pruebas honestas |
|---:|---:|:---:|---:|
| 1 (sin prima) | 0,250 | No (necesita 88,9 %) | 0,250 |
| 2 | 0,270 | No | 0,400 |
| 4 | 0,282 | Sí | 0,571 |
| 10 | 0,289 | Sí | 0,769 |
| ∞ (solo encendidos) | 0,294 | Sí (necesita 66,7 %) | 1,000 |

- Con una prima moderada (alrededor de 4), sella con el 80 % de honestos encendidos, y ni censurándolo todo
  el atacante llega a 2/3 de las plazas (no llega mientras `b < 6`).
- Con censura total sí supera el tercio, así que puede pausar el sello, o romperlo si además controla la red,
  siempre dejando firmas.
- La prueba de disponibilidad tiene que ser de sí o no y verificable en la cadena, no una puntuación: una
  puntuación premia al granjero profesional y choca con R2.

Con sorteo, solo se puede castigar lo sorteado. FV-1 lo cuantifica.

### 3.7 R1–R5

De ahí salen las cinco reglas de `PROGRAMA.md`. Descartan DPoS, los comités fijos, las fundaciones y cualquier
multifirma de puntos de control; admiten un diseño tipo F3. Katana las aceptó como criterio para este
programa y pidió el encargo. Su ratificación como sustituto de «sin comités» en `SPEC.md` §0 queda para
después de FV-1.

---

## 4. Qué haría la capa y qué no [lectura del director]

### 4.1 Frente a hoy

| | Hoy (`C-FIN-01`) | Con la capa (R1–R5) |
|---|---|---|
| Deshacer bloques recientes (doble farmeo, sin rastro) | Hasta `F` de antigüedad (2 h provisionales en el diseño anterior; en 0.0.1, parámetro de la red dev) | Solo lo aún no sellado |
| Deshacer lo ya finalizado | Un nodo en línea no lo acepta, pero cada nodo finaliza por su cuenta | Exige que al menos un tercio del peso firme dos veces: prueba y pérdida de garantía; todos los nodos coinciden |
| Engañar a un nodo eclipsado sobre lo final | Sí; por eso `F` no puede bajar | No, salvo 2/3 de las firmas, o un tercio propio más aislar a otro tercio de los votantes |
| Partir la red | Cada lado puede finalizar lo suyo, sin cura (P-FLUJO) | Como mucho sella un lado; el otro se pausa (sin comprobar contra el modelo de P-FLUJO) |
| Pausar la finalidad | No aplica | Con un tercio del peso, contando a los honestos apagados |

Referencia de velocidad: F3 bajó la finalidad de Filecoin de 7,5 h a decenas de segundos según su diseño
**[blog de Filecoin, vía buscador; cifra también citada en la propuesta antigua]**, y a minutos según los
informes de su puesta en marcha **[fuentes secundarias]**. En ZEROX está sin medir: depende de `Δ` (B-05) y del número de votantes.

### 4.2 Por qué ayuda aunque el doble farmeo siga

- **En la cadena, reutilizar espacio es invisible** (§2.1).
- **En la capa de votos cambian dos cosas.** El espacio cuenta una sola vez, porque el peso sale de la tabla y
  no de ganar sorteos. Y sellar exige firmas públicas: votar por dos ramas son dos firmas, y eso es prueba.
  «Casper no atrapa la rama privada; la vuelve irrelevante para la historia ya finalizada»
  (`R-ZRX/LEGADO/stake/MAPA.md` §1.3).

### 4.3 Qué mejora

1. **La ventana útil del doble farmeo pasa de `F` a la franja sin sellar,** mientras el atacante no llegue a un
   tercio del peso.
2. **Se puede tener finalidad rápida sin dar ventaja al eclipse.** Es el frente de «bajar `F`», que estaba
   atascado por eso.
3. **Reescribir lo sellado tiene un coste exigible y deja firmas.** Es la única pieza revisada que cobra al
   atacante grande por revertir historia.

### 4.4 Qué no mejora

- **El doble farmeo sigue ahí.** Con espacio suficiente, el atacante reordena o censura lo aún no sellado.
- **Con el modelo de amenaza de Katana no hay imposibilidad.** Un Estado con un tercio del peso pausa la
  finalidad indefinidamente, y ZEROX vuelve a la situación de hoy mientras dure. Con un tercio más control de
  la red, o con 2/3, rompe el sello y paga su garantía.
- **Condición sin diseñar:** qué protege durante una pausa. Si `C-FIN-01` sigue de red de seguridad, el peor
  caso es el de hoy; si la convivencia se diseña mal, es peor.
- **Costes para el honesto:**
  - registro con garantía;
  - 2/3 del peso total en línea para sellar;
  - posible pérdida de garantía por error, por ejemplo con la misma clave en dos máquinas;
  - quien no tenga garantía cultiva pero no vota.

### 4.5 Umbrales

Todos se miden **sobre el peso total de la red, no sobre el del atacante**. Ejemplo con 300 PiB registrados:

| El atacante quiere | Necesita | ¿Castigado? |
|---|---|---|
| Pausar la finalidad | Un tercio (100 PiB), **menos lo que esté apagado**: con el 10 % apagado le bastan 70 PiB | No: no firmar no es falta |
| Sellar dos historias contradictorias | Un tercio **y** control de la red para aislar a parte de los honestos | Sí: al menos un tercio del registro firmado |
| Sellar lo que quiera sin tocar la red | 2/3 (200 PiB) | Sí |

- **Repartirse en muchas claves no cambia nada:** el peso se suma.
- **Si registrarse es opcional,** el denominador son solo los registrados y el tercio del atacante baja (con
  150 de 300 PiB registrados, le bastan 50 PiB). Por eso la garantía debe poder pagarse con lo ya farmeado.

### 4.6 Correcciones del director durante la conversación

1. Baig y Pietrzak no dicen que un BFT cierre el doble farmeo (§1).
2. «Con 2/3 reescribe lo sellado» era impreciso: **con un tercio y control de la red** ya se consiguen dos
   sellos contradictorios, siempre dejando firmas.
3. **La capa no baja `F`:** añade una finalidad rápida al lado. `C-FIN-01` queda de red de seguridad con su
   `F` igual de atrapada. En marcha normal, quien cobra espera el sello y no `F`.
4. «No tiene cura» pasa a «no hay cierre conocido» (§2.2).

---

## 5. La mala noticia: el quórum frente a los granjeros domésticos

Para sellar hace falta más de 2/3 del peso **total**. Si el atacante tiene una fracción `a` del peso y no firma,
la fracción `p` de honestos encendidos tiene que cumplir `(1 − a)·p ≥ 2/3`:

| `a` | `p` mínima |
|---:|---:|
| 0,25 | 88,9 % |
| 0,30 | 95,2 % |

La propuesta antigua (`research/dag-poas-capa-finalidad.md` §4.C, sin auditar, cálculo en Python) ya lo
advertía y concluía que la finalidad rápida es **«una mejora del caso normal, no una garantía del umbral»**.
Frente a un atacante del 25–30 % y con PCs domésticos que se apagan, la capa puede pasar mucho tiempo en
pausa. FV-1 tiene que calcularlo con ausencias realistas, en las que una clave grande se apaga entera.

---

## 6. Arquitectura resultante

| Capa | Qué es | De dónde viene | Estado |
|---|---|---|---|
| Arranque | PoW temporal hasta el corte (`C-BOT-04`) | Propio | En 0.0.1 |
| Producción | PoAS + PoT | Propio; el PoT, como Chia | En 0.0.1 |
| Orden | DAG (GHOSTDAG) | Propio | En 0.0.1 |
| PoStake | Garantía por clave (`C-BON`), O4 (`C-BON-03`), evidencia (`C-EVP`), castigo sin correlación | SPEC POS2T, P-SLASHING | Garantía activa en 0.0.1; evidencia y castigo, no |
| Registro de sectores | Sectores registrados, auditorías y garantía | Filecoin | Fuera de 0.0.1 |
| Finalidad por votos | Votos ponderados bajo R1–R5 | F3 de Filecoin, Casper | Este programa |
| Red de seguridad | `C-FIN-01` | Propio | En 0.0.1 |

De Filecoin se toman dos piezas —el registro y la capa de votos—, no su consenso de base ni su sellado lento
(PoRep). **Nombres:** en P-DISUASION, «F3» es el sellado lento del catálogo; en este programa, «F3» es la
finalidad rápida de Filecoin.

**Qué cambia en PoStake al añadir la capa:**
1. **Nace una segunda falta:** el doble voto. `C-EVP` necesita un tipo de evidencia nuevo.
2. **La garantía tiene que crecer con el peso del voto.** Si respalda el voto solo el mínimo por clave, quien
   tiene un tercio del peso arriesga una miseria y R5 no muerde. Queda por decidir si hay una garantía por
   sector, que sirva también contra Sybil, o dos (mínimo por clave y garantía de sector).
3. **Sin castigo correlacionado** (ya decidido en P-SLASHING). Con votos, un fallo común del cliente hundiría a
   muchos honestos a la vez.
4. **`SPEC.md` §0 se mantiene si el peso es espacio.** Si el peso fuera stake, §0 cambia y la finalidad pasa a
   quien tiene moneda.

---

## 7. Lo que decide Katana

1. ~~Fuente del peso~~ **Decidido (provisional hasta FV-1):** sectores registrados con garantía; sorteo
   secreto entre todos los registrados, proporcional al espacio, con prima `b` para quien demostró
   disponibilidad (§3.6). Queda para después de FV-1 elegir `b` y `E` sobre las curvas que entregue.
2. **Ratificar R1–R5** como sustituto de «sin comités» en `SPEC.md` §0, después de FV-1.
3. **Lanzar FV-1.**

---

## Fuentes externas consultadas en la conversación (2026-09-26)

- [FIP-0086 — Fast Finality in Filecoin (F3)](https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0086.md)
- [Filecoin Docs — Consensus](https://docs.filecoin.io/basics/the-blockchain/consensus)
- [Filecoin — How F3 is Transforming the Filecoin Network](https://filecoin.io/blog/posts/how-f3-is-transforming-the-filecoin-network/)
- [Filecoin Foundation — F3: Accelerating Filecoin Finality by 450X](https://fil.org/blog/how-f3-is-transforming-the-filecoin-network)
- [eth2book — Inactivity leak](https://eth2book.info/latest/part2/incentives/inactivity/)
- [arXiv:2404.16363 — fuga de inactividad y finalización contradictoria](https://www.arxiv.org/abs/2404.16363)
- [CryptoSlate — EOS voting structure encourages centralization](https://cryptoslate.com/eos-voting-structure-encourages-centralization/)
- [Crypto Briefing — compra de votos en EOS](https://cryptobriefing.com/pay-people-not-to-vote-dan-larimers-radical-solution-to-eos-vote-buying/)
