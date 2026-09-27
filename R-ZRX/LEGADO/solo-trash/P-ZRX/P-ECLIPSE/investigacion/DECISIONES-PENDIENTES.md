# Decisiones pendientes para Katana — P-ECLIPSE

**Esto no decide. Enumera las bifurcaciones reales, con el coste de cada rama.** Si una rama no
tiene coste declarable, se dice. No se inventan decisiones.

Las tres primeras son **de diseño** y no exigen ninguna medida nueva. Las tres últimas **sí**, y sin
esa medida cualquier valor que se fijara sería provisional (`SPEC.md` §0.3).

---

## D-1 · ¿Se acepta que la partición de flujo **deliberada** es un fallo de modelo, y no un estado que el protocolo gestione?

**Contexto.** `C-FLU-22` cura el nacimiento espontáneo (latencia). Un adversario de red que
**retiene** el pasado durante más de `F_slots` fabrica el nacimiento deliberado, y entonces la
ventana es **vacía** y `C-FIN-01` impide volver: permanente. — `derivado`, `INFORME.md` §F1.

- **Rama A — aceptarlo como fallo de modelo (como ya hace `C-FLU-15`).** Coste: **cero** en reglas y
  en código. Lo que se pierde: la partición deliberada queda, explícitamente, fuera de lo que el
  protocolo promete. Es lo que el SPEC ya escribe, dicho con más precisión.
- **Rama B — intentar curarla.** Coste: **alto y no acotado**. Exigiría una regla que permitiera
  reorganizar más allá de `F_slots` bajo alguna evidencia, y eso **choca de frente con `C-FIN-01`**,
  que es la regla de finalidad. No se ha encontrado ningún mecanismo compatible
  (`no se ha encontrado`, no «no puede existir»): cualquier candidato tendría que distinguir «corte
  de red» de «reorganización profunda legítima» **desde el propio nodo aislado**, que es
  exactamente lo que `C-FLU-18` declara **no** resoluble por regla.

**Recomendación del analista:** rama A. La partición deliberada se convierte en **coste de red**
(IP + tiempo), que es la moneda del adversario de este encargo, y se documenta como tal.

---

## D-2 · ¿Se cablea la renovación obligatoria de pares (`C-NET-40`)?

**Contexto.** El coste real del atacante no es ancho de banda (retiene, gasta ≈0 bits): es
**sostener** la ocupación de las salientes. — `derivado`, `INFORME.md` §F4.

- **Rama A — sí, con `T_par` como símbolo.** Coste: una regla de conducta, sin consenso, y **un
  valor que hoy no se puede fijar** (`T_par` exige medir reconexión honesta frente a recaptura
  adversaria). Beneficio: multiplica por el número de renovaciones el coste de un ataque que dura
  horas. Es la palanca **más barata** de todo el encargo.
- **Rama B — no.** Coste: cero ahora; el atacante que entra **se queda**, y `C-NET-34/35` sólo
  consiguen que suene la alarma mientras sigue dentro.

**Recomendación del analista:** rama A. Es la única medida de este encargo cuyo beneficio no
depende de ninguna cantidad no medida.

---

## D-3 · ¿Se corrige el defecto de contabilidad por prefijo de las salientes (`C-NET-41`)?

**Contexto, y es `verificado en fuente`, no un modelo:**
`crates/zx-p2p/src/limites_ip.rs:288-298` — `handle_established_outbound_connection` **no registra
nada**. Consecuencias: (a) `MAX_POR_PREFIJO = 3` **no limita las salientes**; (b) al desconectar por
consenso, `prefijos_de(peer)` está **vacío** para un peer marcado por nosotros y **no se banea
prefijo alguno**. La defensa de `C-NET-20` **no funciona para los pares que elegimos nosotros**,
que son justo los que hay que capturar para eclipsar.

- **Rama A — corregirlo.** Coste: **pequeño y local** (registrar el prefijo también en la ruta
  saliente y usarlo al puntuar/banear). No requiere ninguna medida nueva ni ninguna decisión de
  consenso. Riesgo: hay que comprobar que no se banea un prefijo propio por una desconexión legítima.
- **Rama B — dejarlo.** Coste: el baneo por prefijo sigue siendo **medio sistema** (sólo entrantes),
  y `C-NET-20` sigue leyéndose como si cubriera ambos.

**Recomendación del analista:** rama A. Es un defecto, no una decisión de diseño, y hoy no está
anotado en `ci/reglas-sin-cablear.txt` como tal.

---

## D-4 · ¿Se mide el coste del paso 1b de `C-POT-08` antes de intentar fijar `PRESUP_NODO`?

**Contexto.** `PRESUP_NODO` tiene cota inferior **derivada** (11,04 min de CPU con `F_slots = 7200`)
y cota superior **no derivada**. La compatibilidad de F5 depende de **una** medida que no existe:
los milisegundos del paso 1b por bloque ajeno. — `derivado`, `INFORME.md` §F5.

- **Rama A — medir primero.** Coste: un encargo de medición **pequeño y sin red** (bancos de
  verificación estructural de un sub-DAG ajeno). Es la medida **más barata** de las que bloquean
  algo en este informe, y desbloquea a la vez `PRESUP_NODO` y `PRESUP_PAR`.
- **Rama B — fijar un valor sin medir.** **No es una opción**: `SPEC.md` §0.3 lo prohíbe y el
  resultado sería una regla de consenso con apariencia de cerrada y cimiento móvil.

**Recomendación del analista:** rama A. No hay rama B legítima.

---

## D-5 · ¿Se adopta E1 y E2 como conducta obligatoria **antes** de poder calibrar `B` y `n_min`?

**Contexto.** `B` y `n_min` exigen `Δ` **medida en red real**, que no existe. Pero E1 detecta la
variante (i) en decenas de segundos **con cualquier `B` razonable**, y su conducta asociada (no
autorizar + alertar + rotar pares) **no depende de la calibración**.

- **Rama A — cablear la conducta con umbrales provisionales declarados.** Coste: riesgo de falsas
  alarmas mientras `B` no esté calibrado; a cambio, la rotación de pares empieza a funcionar ya.
- **Rama B — esperar a medir `Δ`.** Coste: cero riesgo de falsa alarma; el hueco D2 sigue abierto
  entretanto, **y es el que el propio repositorio llama «el más serio frente al adversario de
  Katana»**.

**Recomendación del analista:** no la da. Es una decisión de **apetito de riesgo operativo**, y
depende de si hay red desplegada contra la que alarmar. Se enumeran las dos ramas porque el coste de
cada una es real y de naturaleza distinta.

---

## D-6 · ¿Se construye un gestor de direcciones, sabiendo que la cuenta de la sección D no aplica a lo que hay?

**Contexto.** Hoy **no hay** gestor (`verificado en fuente`): no hay tabla, ni selección, ni
diversidad por prefijo para elegir pares. La sección D da el modelo de captura sobre un **diseño
propuesto** y una cota superior (`0,9716` de los grupos para 50 % con `ω = 24`), pero la cota
inferior real **no existe** porque no hay diseño que medir.

- **Rama A — construirlo con las contramedidas de `C-NET-39/40` desde el principio.** Coste: es
  trabajo de red, no de consenso; y hay que admitir que **el coste real del atacante seguirá sin
  poder afirmarse** hasta que exista y se mida.
- **Rama B — no construirlo.** Coste: el nodo no descubre pares por sí mismo (hoy no lo hace: **no
  se ha encontrado** bootstrap de Kademlia ni suscripción a gossipsub) y la red depende de `--peer`
  manual. Eso **no es un eclipse**: es que no hay red P2P que eclipsar.

**Recomendación del analista:** rama A, y **antes** de citar cualquier cifra de la sección D como
coste del adversario: hoy no lo son.

---

## Lo que NO es una decisión (y por eso no aparece arriba)

- **`F_slots`, `L_suelo_slots`, `I_slots`, `B`, `W`, `n_min`, `PRESUP_PAR`, `PRESUP_NODO`, `T_par`:
  no se decide su valor aquí ni conviene decidirlo todavía.** Son símbolos y su calibración exige
  medidas que no existen (`BORRADORES-C-NET.md` §F).
- **El umbral protocolario global** sigue **inconcluso** (`P-ZRX/P-CRP/`): este encargo no lo mueve
  y no debe leerse como si lo moviera.
- **El ancla externa** no es una decisión de consenso: es ayuda al operador (`AGENTS.md`).
