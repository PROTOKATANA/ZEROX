# PROPUESTA-SPEC — P-FLUJO: la regla de flujo del PoT (perfil 1a, `L ≥ F`)

**Esto es una PROPUESTA. No se ha editado `SPEC.md`. Ningún texto de aquí es normativo hasta que
Katana lo traslade formalmente.** Redactada el 2026-09-19 por el agente del encargo
`/home/katana/zeo/ZEROX/P-FLUJO/ENCARGO.md` (solo lectura). Forma: plantilla de
`/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md`; estilo de etiquetado
e interfaz: `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md`.

**Alcance.** Define lo que `P-POT` dejó como «entradas que aporta el contexto»
(`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:48-51, 54-60, 176-181`): qué es el
**flujo**, quién es el **ancla**, cuándo se **activa** la entropía, de dónde sale `semilla(f, 0)`, y
qué pasa con flujos distintos. **Fuera de alcance y sin tocar:** el PoT como primitiva, el
verificador, la caché y el orden de validación (`C-POT-01…08`); los **valores** de `I`, `F`,
`ρ_max`, `D` y `N(s)`, que van como símbolos; la revelación retardada R-FIN-14(h); el perfil 1b;
cualquier regla de adopción entre flujos.

**Etiquetas de afirmación** (§8.5 del encargo). Cada afirmación de este documento lleva una:

- **demostrado** — con la prueba escrita aquí, y con sus hipótesis explícitas.
- **verificado en fuente** — leído en el archivo citado, con ruta completa desde
  `/home/katana/zeo/ZEROX` y número de línea.
- **propuesto** — texto nuevo que introduce esta propuesta.
- **medido en simulación** — con su instrumento y el alcance que ese instrumento declara.
- **no determinado por el SPEC** — el SPEC vigente no lo fija, y se dice.

Las reglas `R-FIN-*` de `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md` son
**evidencia histórica**: dan el diseño candidato, no texto normativo
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/README.md:7-10`).

**Decisiones de Katana del 2026-09-19 incorporadas** (**verificado en fuente:**
`/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:68-79`): **DF-1** perfil 1a con `L` atada a `F`;
**DF-2** ninguna regla de adopción; **DF-3/DF-4** reducidas a declarar; **D-1 = A** (`blake3`) y
**D-2 = A** (`pot_output` = salida futura).

## Revisión 2 — ADENDA 1 incorporada (2026-09-20)

`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md` (solo lectura, huella comprobada). La adenda
**prevalece** sobre el `ENCARGO.md` en lo que dice (`ADENDA-1.md:4`). Qué cambia en este documento:

- **La refutación de §0 queda aceptada por el validador** (`ADENDA-1.md:8-12`). La estructura
  (P1)/(P2)/(P3) se conserva porque es la correcta. **§0 no se ha suavizado.**
- **DECIDIDO por Katana el 2026-09-20** (`ADENDA-1.md:16-21`), y aquí escrito sin condicionalidad:
  - **Perfil 1a reconfirmado**, sabiendo que una partición de flujo **no tiene cura en el
    protocolo**: es **prevención, no recuperación** (§0.4, C-FLU-15).
  - **Suelo de `L`:** `L_slots ≥ máx(F_slots, L_suelo_slots)`, con `L_suelo_slots` **parámetro de
    consenso simbólico** (C-FLU-01).
  - **D-F1 = A:** entropía `= blake3(chunk(I_j) ‖ pot_output(I_j))` (C-FLU-12).
  - **D-F6 = A:** cota de slot ampliada a **todos** los padres (C-FLU-02).
- **Dos citas arregladas:** `research/dag-poas-balizas-auditoria.md` (el nombre corto no existía) y
  el `pot.rs` de Autonomys, **ahora abierto de primera mano**. Ninguna cita de este documento queda
  ya de segunda mano.

## Revisión 3 — ADENDA 2 incorporada (2026-09-20)

`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md` (solo lectura, huella comprobada). **Prevalece sobre el
§2 de la ADENDA 1** (`ADENDA-2.md:4-5`): **lo que era provisional pasa a decidido y la marca se
retira.** **Ya no queda ninguna regla provisional en este documento.**

- **D-F2 = A DECIDIDA.** `H_flujo := H_d = SHA3-256(etiqueta ‖ m)` con etiqueta nueva de 16 bytes;
  hay que **ampliar C-HASH-06** (C-FLU-10, C-FLU-06).
- **D-F3 = C DECIDIDA, ACOTADA AL ENUNCIADO.** Regla de finalidad **nueva**, en slots, con la
  semántica de R-FIN-7: **C-FIN-01** (§10.4). **La reconciliación con el código que hoy se detiene,
  con `COINBASE_MATURITY` y con el techo de archivado NO entra** y queda declarada como pendiente.
- **D-F4 = A DECIDIDA.** Las **dos** desigualdades del borde, escritas explícitas: la que prohíbe
  reorganizar (C-FIN-01) y la que activa la inyección (C-FLU-07). §10.2.
- **D-F5 MEJORADA — ya no es «sin legislar».** **C-FLU-18** (§8): un nodo **sin cadena previa
  aplica la selección ordinaria de GHOSTDAG**, y la regla de finalidad **solo obliga a quien ya
  tiene una cadena que reorganizar**. Es cerrar un hueco de redacción, no un mecanismo nuevo.
  C-FLU-17 se mantiene.
- **Bifurcación nueva abierta, no resuelta aquí** (`ADENDA-2.md:19-20`): **D-F7**, en qué familia de
  IDs entra la regla de finalidad, que **no es una regla de flujo**. Va en
  `DECISIONES-PENDIENTES.md`.

## Revisión 4 — objeción del validador a la Prop. A (2026-09-20)

**La objeción es correcta, y al verificarla encontré que alcanza más lejos: también rompe la
conclusión (c) de §0.2, que el validador no señaló.** Lo digo yo primero porque es un error mío y
porque hay una decisión de Katana (DF-2) apoyada en él.

- **§0.4 · La Prop. A se RETIRA** y se sustituye por **A1** (demostrado, mecanismo C-FLU-14, no
  finalidad) y **A2** (**probabilístico y NO medido**: carrera de `blue_work` de longitud `L` dentro
  del corte). Desaparece la afirmación «cierra **sin estadística** el vector 2».
- **§0.2 · La conclusión (c) se RETIRA.** La ventana de adopción **no es vacía**: mide
  ≈ `F_slots`, que es exactamente lo que `P-2.1/SINTESIS.md:30-31` decía y yo contradije. Se
  sustituye por **(c′)**, demostrada.
- **§0.5 · (b) queda condicionada** a que DF-2 se confirme sabiendo que la ventana existe.
- **§10.2 · el borde `L = F` se re-acota** al mecanismo de nacimiento por latencia.
- **Reglas nuevas: C-FLU-20** (regla del productor ante un bloque tardío que cambiaría el ancla; y
  que ese bloque queda **infusionable para siempre**) y **C-FLU-21** (la inyección activada se
  hereda, no se recalcula).
- **Dos decisiones nuevas, que no tomo:** **D-F8** (congelar la vista en el bloque que cruza el
  corte, y qué reabre) y **D-F9** (**DF-2 se decidió sobre una premisa falsa**: ¿se mantiene?).
- **(a) sigue refutada:** esa parte no dependía del error.

## Revisión 5 — ADENDA 3 incorporada (2026-09-20)

`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-3.md` (solo lectura, huella comprobada). **La respuesta a la
objeción queda aceptada entera, incluida la retirada de la conclusión (c)**
(`ADENDA-3.md:4-5`). **D-F7, D-F8 y D-F9 decididas; no queda ninguna decisión abierta salvo la nueva
D-F10.**

- **D-F7 = B:** la regla de finalidad pasa a familia propia. **`C-FLU-19` → `C-FIN-01`**, renombrada
  en los tres entregables (16 apariciones en este documento). Familia nueva **`C-FIN`** declarada en
  el índice de §11.
- **D-F8 = C:** **no se congela la vista.** `C-FLU-03` queda como está y **C-FLU-21 pasa a regla
  firme**, con el motivo escrito: congelar reabre **E1** en una franja de anchura `≤ S_max_slots`.
- **D-F9 = C:** **se permite adoptar el flujo rival dentro de la ventana, con presupuesto.** DF-2
  queda **sustituida** por **C-FLU-22**, nueva, con los siete puntos que la adenda exige — incluida
  la demostración de que **no hay vía barata de forzar AES ajeno** (§5 de la regla), que resultó
  apoyarse en `L ≥ F` y es **un argumento nuevo a favor del perfil 1a**.
- **Corregido en cadena:** C-FLU-15 y §0.4 decían «una partición no tiene cura en el protocolo».
  **Ya no es exacto:** cura el nacimiento espontáneo y **no** cura el corte de red más largo que
  `L`. **(b) de §0.5 queda retirada a la letra** y sustituida por su versión exacta.
- **Bifurcación nueva, abierta y no resuelta (`ADENDA-3.md:42-43`): D-F10** — el presupuesto de
  C-NET-32.3 es **por par**, y las identidades son gratis.

## Revisión 6 — D-F10 decidida (2026-09-20)

**D-F10 = B, decidida por Katana:** presupuesto **por par Y cota global por nodo e intervalo**, con
el modo de fallo escrito, y el valor **como símbolo**. **Coincide con mi recomendación.**

- **Regla nueva: `C-FLU-23`**, con las dos cotas, las cuatro obligaciones del estado `Pendiente`
  —conservar la cadena, no declarar inválido, **seguir reenviando**, reintentar— y la pinza de
  calibración: **si `PRESUP_NODO` es demasiado pequeño, deroga D-F9 en la práctica** (la adopción
  nunca llega a completarse); si es demasiado grande, devuelve el DoS.
- **Hallazgo al redactarla, que no estaba en la decisión:** el presupuesto añade una **tercera
  rendija** a las dos que PCO-v0.1 enumera —dos nodos con el mismo DAG pueden acabar en flujos
  distintos porque uno pudo pagar la verificación dentro de la ventana y el otro no—, y **a
  diferencia de las otras dos está parcialmente bajo control del atacante**. **No está medida.**
- **Nota de numeración, sin abrir decisión:** `C-FLU-23` es una **enmienda a C-NET-32.3**, no una
  regla de flujo. Por el mismo criterio que Katana fijó en **D-F7**, el traslado debería numerarla
  en `C-NET`. El criterio ya está decidido, así que lo señalo y no abro D-F11.

**Con esto, D-F1…D-F10 están todas decididas y no queda ninguna decisión abierta.**

---

## 0 · La afirmación central del encargo §2: (a) REFUTADA, (b) sobrevive por otra razón, (c) DEMOSTRADA

El encargo §2 avisa de que esto es razonamiento del diseñador sin revisar y pide demostración o
contraejemplo. **Es lo primero que se hizo, antes de redactar ninguna regla.** El resultado cambia
el motivo por el que el perfil 1a es seguro, no la elección del perfil.

### 0.1 · Dos lemas previos — demostrados

Notación en §1. `Chn(V)` es la cadena seleccionada del bloque virtual sobre una vista `V`;
`T_j = j·I_slots`; `I_j` es el primer bloque de `Chn` con `slot ≥ T_j`; `t_j = slot(I_j) + L_slots`.

> **Lema 1 (la bifurcación está estrictamente por debajo de `T_j`) — demostrado.**
> Sean dos cadenas seleccionadas `C_A` y `C_B` del mismo DAG, ambas desde el génesis, y sea `P` su
> último bloque común. Si `I_j(C_A) ≠ I_j(C_B)`, entonces `slot(P) < T_j`.
>
> *Prueba.* Supóngase `slot(P) ≥ T_j`. El prefijo común de `C_A` y `C_B` hasta `P` es **la misma
> secuencia de bloques**, y contiene a `P`, que cumple `slot(P) ≥ T_j`. El «primer bloque con
> `slot ≥ T_j`» de una cadena es una función del prefijo hasta el primer cruce; como el cruce ocurre
> dentro del prefijo común en ambas, las dos cadenas devuelven **el mismo** bloque, es decir
> `I_j(C_A) = I_j(C_B)`. Contradicción. Luego `slot(P) < T_j`, y como los slots son enteros,
> `slot(P) ≤ T_j − 1`. ∎

> **Lema 2 (profundidad en el instante de activación) — demostrado.**
> En las condiciones del Lema 1, en el slot `t = t_j` la profundidad de la bifurcación,
> `d := t − slot(P)`, cumple `d ≥ L_slots + 1`.
>
> *Prueba.* `t_j = slot(I_j) + L_slots` y `slot(I_j) ≥ T_j` por definición del cruce, luego
> `t_j ≥ T_j + L_slots`. Con `slot(P) ≤ T_j − 1` del Lema 1:
> `d = t_j − slot(P) ≥ (T_j + L_slots) − (T_j − 1) = L_slots + 1`. ∎

El Lema 2 es la pieza que el encargo enunciaba como «profundidad `≥ L`». Es **`≥ L + 1`**, y esa
unidad de más es exactamente lo que cierra el borde `L = F` sin pedir margen (§10.2).

### 0.2 · (c) La ventana de adopción — **RETIRADA en la revisión 4: mi demostración era falsa**

> ## ⛔ CORRECCIÓN (revisión 4, 2026-09-20) — leer antes que el resto de §0
>
> **La demostración de (c) que había aquí es incorrecta, y la conclusión es falsa.** La objeción del
> validador a la Prop. A (§0.4) es correcta y **alcanza también a esta sección**, cosa que el
> validador no dijo y que encontré al verificarla. Lo digo yo antes de que se use: **cualquier texto
> que cite «la ventana de adopción es vacía» está citando un error mío.**
>
> **El error, en una frase.** El Lema 1 habla de **las cadenas que determinan el ancla** —
> `Chn(V_j)`, la cadena del virtual sobre la vista truncada de C-FLU-04 — y yo lo apliqué a **las
> cadenas seleccionadas de los nodos**, que son otro objeto. Las dos coinciden bajo la R-FIN-1
> literal (el ancla como primer cruce de la **propia** cadena del bloque), pero esa definición es
> justo la que E1 refuta por circular y que C-FLU-04 **repara cambiando de objeto**. Reparé la
> circularidad y no propagué el cambio a la demostración de profundidad. Es el mismo cambio de
> objeto que yo le reprocho al encargo en §0.3.
>
> **Lo correcto.** Dos flujos nacidos en `t_j` comparten **todo el DAG con `slot < t_j`**: su último
> bloque común `P` puede tener `slot(P) = t_j − 1`. La profundidad de cruzar de flujo en el instante
> `t` es `d = t − slot(P) ≈ t − t_j`, **no** `t − T_j`. Luego, con la regla de finalidad C-FIN-01:
>
> ```text
> adopción prohibida  ⟺  d ≥ F_slots  ⟺  t ≳ t_j + F_slots
> ventana de adopción ≈ [t_j, t_j + F_slots)      — de anchura ≈ F, NO vacía
> ```
>
> **Y el repositorio ya lo decía.** `P-2.1/SINTESIS.md:30-31`: «R-FIN-7 congela a **todos** los nodos
> a la vez en `t_j + F` (la profundidad de cruzar de flujo es `t − t_j`)» (**verificado en fuente**).
> Cité esa línea en §0.4 mientras afirmaba lo contrario en §0.2. **El análisis de PCO-v0.1 que
> `SINTESIS.md:74-76` declaró «superado» por mi razonamiento no estaba superado: mi razonamiento era
> el que estaba mal.**
>
> **Qué arrastra.** (i) **DF-2** se decidió sobre esta conclusión
> (`/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:71-73`): la premisa es falsa, así que la decisión hay
> que revisitarla — va como **D-F9**, no la tomo yo. (ii) **(b)** queda afectada (§0.5). (iii) El
> borde `L = F` de §10.2 hay que re-acotarlo: vale para el mecanismo de nacimiento por latencia, no
> para el de fusión. (iv) **(a) sigue refutada**: esa parte no dependía de este error.
>
> **Lo único que sobrevive de esta sección** es el Lema 1 y el Lema 2 **sobre `Chn(V_j)`**, que se
> conservan abajo porque otras piezas los usan. **No** dicen nada sobre la profundidad de una
> reorganización del nodo.

**Enunciado que había aquí, y que NO se sostiene.** Bajo `L_slots ≥ F_slots`, en todo instante
`t ≥ t_j` un nodo que quisiera pasar del flujo `f_A` al flujo rival `f_B` tendría que sustituir su
cadena seleccionada en un punto de bifurcación de profundidad `d ≥ L_slots + 1 > F_slots`. R-FIN-7
lo prohíbe
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:301-303`,
«Un nodo **MUST NOT** reorganizar su cadena seleccionada por debajo de `F` segundos de slot; una
punta que lo exigiera se **ignora**, nunca apaga el proceso»). **La ventana es vacía ya en el propio
instante de activación, no solo después.** *Prueba:* Lema 2 más `d` no decreciente en `t` (el punto
de bifurcación `P` está fijado y `t` crece). ∎

**Dónde falla exactamente, para que no se repita.** El Lema 2 acota `t_j − slot(P)` **con `P` el
último bloque común de `Chn(V_j(C_A))` y `Chn(V_j(C_B))`**. La prueba de arriba lo usa como si `P`
fuese el último bloque común de **las cadenas seleccionadas de los dos nodos**. Son distintos: dos
nodos pueden tener la **misma** cadena seleccionada hasta `t_j − 1` y anclas distintas, porque sus
`V_j` difieren en qué bloques **del anticono** con `slot < T_j + L_slots` ha fusionado cada uno. La
fusión de un bloque viejo **no es una reorganización** y no la toca ninguna regla de finalidad.

**El enunciado corregido, que es el que hay que usar:**

> **(c′) — demostrado.** Dos bloques `B`, `B″` con anclas de la época `j` distintas no tienen
> ningún ancestro común con `slot ≥ t_j`. *Prueba:* si `Q` fuese uno, `Q ∈ past(B)` y `Q ∈ past(B″)`
> con `slot(Q) ≥ t_j`; por C-FLU-14 ambos cumplen `flujo(·, slot(Q)) = flujo(Q, slot(Q))`, lo que
> fija la inyección `j` —su entropía y su `t_j`— para los dos, luego sus anclas dan la misma
> entropía. ∎
>
> **Corolario.** El punto de bifurcación cumple `slot(P) < t_j`, y solo eso: `d(t) > t − t_j`. La
> ventana de adopción es `[t_j, t_j + F_slots)`, de anchura ≈ `F_slots`. **No es vacía.**

**Hipótesis explícitas de (c′):** (i) la profundidad de una reorganización se mide como diferencia
de índices de slot entre la punta y el punto de bifurcación (§1, borde 2); (ii) la regla de finalidad
es **C-FIN-01** —slots, semántica de R-FIN-7—, **no `C-REORG-07`**: **D-F3 = C, DECIDIDA por Katana
el 2026-09-20** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:10`); (iii) `H_flujo` resistente a
colisiones (C-FLU-10). **`L_slots ≥ F_slots` ya no interviene aquí**: el perfil 1a no compra la
ventana vacía. Lo que compra está en §0.4, y es menos.

### 0.3 · (a) «Una partición de flujo solo nace de una violación de finalidad» — REFUTADA

**El paso inválido** es exactamente éste: de «la divergencia tiene profundidad `≥ L ≥ F`» se
concluye «la regla de finalidad ya manda ignorar la rama rival» y de ahí «luego nadie pudo llegar
aquí sin violar la finalidad». R-FIN-7 acota **cómo evoluciona en el tiempo la cadena seleccionada
de UN nodo**. No dice, ni puede decir, que dos nodos no sostengan cadenas distintas en el mismo
instante. Una regla prohíbe un **acto**; no vuelve imposible un **estado** al que se llega sin
ejecutar ese acto nunca.

**Contraejemplo (honesto, sin atacante, sin ninguna violación de finalidad) — demostrado como
construcción; su probabilidad es lo único que está medido, no demostrado.**

1. En el slot `T_j` dos bloques honestos `X` e `Y`, ambos con `slot ≥ T_j`, se producen en mitades
   distintas de la red dentro de una ventana `Δ` y quedan en anticono mutuo. Los dos son
   **válidos para todos**: hasta `t_j` rige el flujo anterior, así que no hay ninguna asimetría de
   validez entre ellos (**verificado en fuente:**
   `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:212-214`, R-FIN-2, «durante
   `[slot(I_j), t_j)` todos los candidatos a `I_j` producen el mismo flujo: **una sola lotería**»).
2. La cadena seleccionada del nodo `A` pasa por `X`; la de `B`, por `Y`. **Profundidad 0.** Nadie ha
   reorganizado nada: cada uno **construyó** sobre lo que vio, y la cadena seleccionada de GHOSTDAG
   es función de `blue_work`, que en ese instante está empatado o casi.
3. Entre `T_j` y `t_j` cada nodo puede cambiar de rama cuantas veces quiera: **todos esos cambios
   son de profundidad muy inferior a `F`**, así que R-FIN-7 no se viola ni una sola vez. Lo normal
   es que converjan — ése es todo el trabajo que hace `L`. Con probabilidad `p > 0`, no convergen.
4. En `t_j`, `A` inyecta la entropía de `X` y `B` la de `Y`. Los flujos divergen; desde ese slot los
   dos sub-DAG son mutuamente irreferenciables por R-FIN-5 (**verificado en fuente:**
   `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:223-225`).
5. **Ningún nodo reorganizó jamás por debajo de `F`.** La partición nació de una discrepancia de
   **vista** que persistió `L` slots, no de un acto que la finalidad prohíba.

**Por qué esto no es una objeción de matiz.** La probabilidad `p` del paso 3 es *precisamente* la
magnitud que `P-2.1` midió y contra la que se calibra `L`: `L_mín(10⁻³)` ≈ 0 con `Δ` nominal,
**119** slots con `Δ = 4 s`, **1 198** con `Δ = 10 s`, **1 682** con `Δ = 16 s`; A3 con `α = 0,45`:
**177** (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:26-28`). Si (a) fuese
cierta, `p` sería idénticamente cero y `L` sería un parámetro libre. La propia síntesis afirma lo
contrario: «Toda la seguridad descansa en que la partición **no nazca** (lo gobierna `L` frente a
`Δ`)» (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:47-48`). **La afirmación
(a) y la medición que motivó DF-1 no pueden ser ambas ciertas.**

Hay además evidencia directa de que la cadena seleccionada discrepa sin atacante:
«la cadena seleccionada del bloque virtual difiere de la final **el 41 % del tiempo**;
`P(profundidad de cambio > 64 s) = 3,7·10⁻³`; máximo observado 101,5 s»
(**medido en simulación**, instrumento `chain_agree.py`, modelo «todo azul», `λ=1/s`, `D=4 s`,
24 semillas × 1 200 s, 5 448 muestras; **verificado en fuente:**
`/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:98`. *Alcance:* es una simulación
de eventos sin atacante y con `Δ` supuesta, no una medición de red).

### 0.4 · Lo que sí es cierto, y es mejor que (a): el ancla ya es final cuando se usa

> ## ⛔ La Prop. A de las revisiones 1-3 era FALSA. Se retira y se sustituye por A1 y A2.
>
> **Texto retirado:** «Cambiar `I_j` exige sustituir su cadena seleccionada en un punto de
> bifurcación con `slot < T_j` (Lema 1) … Luego, desde el instante de activación en adelante, ningún
> nodo puede cambiar su `I_j` — ni por un bloque retenido publicado tarde, ni por nada», y la
> afirmación de que eso **cerraba sin estadística** el vector 2 de retención.
>
> **Por qué era falsa (objeción del validador, correcta).** C-FLU-04 define el ancla sobre
> `Chn(V_j(B))`, la cadena del virtual de la **vista truncada**, que **no** es la cadena seleccionada
> del nodo. `V_j(B)` **crece sin ninguna reorganización** cuando un bloque nuevo fusiona un bloque
> retenido con `slot < T_j + L_slots`. Si ese bloque encabeza una rama privada más pesada que la
> honesta **dentro del corte**, `Chn(V_j)` cambia y con ella `I_j`, sin que nadie haya violado la
> finalidad y sin que ninguna cadena seleccionada se haya movido. **Fusionar no es reorganizar, y
> ninguna regla de finalidad habla de fusiones.**

**Lo que sí es cierto, separado en dos piezas con etiquetas distintas.**

> **A1 (inmutabilidad por herencia) — DEMOSTRADO, y el mecanismo es C-FLU-14, no la finalidad.**
> Sea `B` un bloque válido con `slot(B) ≥ t_j` y sea `B′` cualquier descendiente válido de `B`.
> Entonces la inyección `j` de `B′` tiene **la misma entropía y el mismo `t_j`** que la de `B`.
>
> *Prueba.* `B′` válido ⟹ C-FLU-14 ⟹ para todo `X ∈ past(B′)`, `flujo(X, slot(X)) = flujo(B′, slot(X))`.
> Tómese `X = B`, con `slot(B) ≥ t_j`. Por C-FLU-07, `flujo(B, slot(B))` incorpora la inyección `j`;
> por C-FLU-10 esa incorporación es `H_flujo(flujo(B, t_j−1) ‖ entropía_j ‖ LE64(t_j))`. La igualdad
> de los dos valores fuerza, salvo colisión de `H_flujo`, la igualdad de `entropía_j` y de `t_j`. ∎
>
> **Consecuencias.** (i) **El vector 2 de retención publicado DESPUÉS de `t_j` queda cerrado de
> forma determinista**: un bloque que fusione el retenido y con ello cambie `I_j` es **inválido**,
> no «improbable» (`/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:479`). (ii) La
> cascada de la auditoría (`:112`) queda cerrada por lo mismo. (iii) El precio es que ese bloque
> queda **infusionable para siempre** en ese flujo: véase C-FLU-20.
>
> **Lo que A1 NO dice:** nada sobre reorganizaciones. Un nodo que abandone todos sus bloques de
> `slot ≥ t_j` puede llegar a otro ancla; eso es (c′) de §0.2, y solo la finalidad lo acota, desde
> `t_j + F_slots`.

> **A2 (determinación del ancla antes de `t_j`) — PROBABILÍSTICO, no demostrado, y NO medido.**
> Mientras `t < t_j`, fusionar un bloque retenido con `slot < T_j + L_slots` es **legal** (la
> inyección `j` aún no está en vigor, así que C-FLU-14 no impone nada sobre ella). Luego el ancla
> **sigue en disputa** hasta `t_j`, y quién la gana es el resultado de una **carrera de `blue_work`
> dentro del corte**:
>
> - los bloques que cuentan en `V_j` tienen `slot < T_j + L_slots`, así que una rama privada que
>   quiera desplazar el ancla debe bifurcar por debajo de `T_j` (Lema 1 sobre `Chn(V_j)`) y acumular
>   más `blue_work` que la honesta **en una ventana de `≥ L_slots` slots**. Retrasar la publicación
>   **no da bloques de más**: cada bloque necesita su billete en su slot. Es, exactamente, **la cola
>   de una carrera de longitud `L`**.
> - **El k-cluster NO protege aquí, y esto corrige lo que yo suponía en C-FLU-08.** El argumento de
>   la auditoría —«un bloque con slot antiguo llega **rojo** y GHOSTDAG nunca elige un rojo como
>   padre seleccionado» (**verificado en fuente:**
>   `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:110`)— vale para la cadena
>   seleccionada real, donde el retenido tendría que ser padre seleccionado de un bloque honesto.
>   **No vale para `Chn(V_j)`:** ahí el virtual se construye sobre el conjunto truncado y la punta
>   de la rama retenida compite **directamente por `blue_work`**, que es **intrínseco** al bloque y
>   no depende del observador (**verificado en fuente:**
>   `/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md:68-70`, «`rank` es
>   una función GLOBAL de `B` — depende solo de `past(B)` … nunca de la cadena seleccionada ni del
>   observador»). El color no entra en la elección del virtual.
>
> **Con qué probabilidad: lo que se puede decir y lo que no.** Es el objeto que `CRP-v0.1` midió —el
> coste de construir una **rama privada con más `blue_work`**— y su resultado es `α_mínimo = 1/2`,
> «el mismo umbral que PoW y que GHOSTDAG sobre PoW», en los dos regímenes
> (**verificado en fuente:** `/home/katana/zeo/ZEROX/TAREAS.md:129-134`). Por debajo de ese umbral
> la cola decae exponencialmente con la longitud de la carrera, que aquí es `L_slots ≥ F_slots`
> (`7 200` con los valores nominales de hoy), de modo que el margen es enorme. **Pero la magnitud
> concreta —`P(la rama privada gana dentro de `V_j`)` a `L = F_slots`— NO está medida:** CRP-v0.1
> midió el **umbral**, no esta cola; y lo que `P-2.1` midió (`L_mín`) es **otra cosa**, el desacuerdo
> **honesto** por latencia. **Etiqueta correcta: `no medido`.** Instrumento que podría medirlo:
> ANCLA-v0.2 (`/home/katana/zeo/ZEROX/P-2.1/veritas/consenso/ancla-inyeccion-v2/`).

**Lo que el perfil 1a compra de verdad, después de la corrección.** Menos de lo que yo dije: compra
**A1**, que es determinista pero cuelga de C-FLU-14 y no de `L ≥ F`; y compra que la carrera de
**A2** dure `L_slots` en vez de menos, que es donde `L ≥ F` sí trabaja. **No compra la ventana de
adopción vacía** (§0.2) ni «cierra el vector 2 sin estadística»: lo cierra después de `t_j`, y antes
de `t_j` lo deja en una carrera.

**Y su reverso — reescrito en la revisión 5, porque DF-2 quedó sustituida.** Las revisiones 1-4
decían aquí que la partición no tiene cura. Con **D-F9 = C** y **C-FLU-22** eso ya no es exacto:

- si la partición nace **espontáneamente** (latencia, vía A2), hay **ventana de adopción**
  `[t_j, slot(P) + F_slots)` y la red **converge al flujo más pesado** dentro de ella, con las dos
  rendijas que PCO-v0.1 mide (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:29-36`);
- si nace de un **corte de red más largo que `L`**, la ventana es **vacía** ya en `t_j` y la
  partición **sí** es permanente: la selección de cadena queda desactivada entre flujos y la punta
  rival, aunque pese más, se ignora (`ancla-de-orden.md:301-303`);
- **luego «permanente por construcción» (`SINTESIS.md:29-30`) describe el caso sin adopción, que ya
  no es el nuestro.** Lo que queda es: **cura el caso improbable, no cura el grave.**

**El enunciado que sustituye a (a), y que esta propuesta usa como cimiento:**

> **Bajo 1a** (enunciado de la revisión 4; el de las revisiones 1-3 daba (P1) y (P3) por más
> fuertes de lo que son):
>
> - **(P1′) demostrado, por C-FLU-14 y no por la finalidad** — el flujo es inmutable **a lo largo de
>   un linaje**: ningún descendiente válido de un bloque con `slot ≥ t_j` puede cambiar la inyección
>   `j` (A1). Cierra el vector 2 publicado después de `t_j`, al precio de C-FLU-20.
> - **(P2a) medido en simulación** — la probabilidad de que dos honestos lleguen a `t_j` con anclas
>   distintas **por latencia** es pequeña, gobernada por `L` frente a `Δ` (`L_mín`, `P-2.1`).
> - **(P2b) NO medido** — la probabilidad de que una **rama privada** desplace el ancla dentro de
>   `V_j` antes de `t_j`: carrera de longitud `L`, umbral `α = 1/2` por CRP-v0.1, **cola sin medir**
>   (A2). **Esto es nuevo en la revisión 4 y no estaba contemplado en ninguna parte del encargo.**
> - **(P3″) demostrado, y en la revisión 5 con regla escrita** — si la partición nace, cruzar de
>   flujo exige una reorganización de profundidad `> t − t_j`; C-FIN-01 la prohíbe desde
>   `slot(P) + F_slots`. Entre medias **hay ventana**, y **C-FLU-22** dice qué hacer en ella:
>   selección ordinaria de GHOSTDAG, con verificación de PoT ajeno solo para adoptar y bajo
>   presupuesto. **La anchura de la ventana depende de cómo nació la partición:** máxima
>   (`F_slots − 1`) en el nacimiento espontáneo, **vacía** en un corte de red más largo que `L`.

La seguridad del perfil descansa en (P2), que es una **cola medida en simulación** con el alcance
que `P-2.1` declara, no en un teorema. Con `L = F = 2 h = 7 200` slots (`τ_nom = 1 s/slot`) frente a
los ≈360 / ≈3 600 / ≈5 000 slots extrapolados a `10⁻⁹` (**medido en simulación + extrapolado**,
etiqueta `estimado` en la fuente, **verificado en fuente:**
`/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:28`) el margen es holgado. El número no cambia; **cambia
qué es lo que lo sostiene**.

### 0.5 · (b) «Un nodo honesto nunca verifica el PoT de un flujo ajeno» — sobrevive, por DF-2

La conclusión es correcta y esta propuesta la conserva (C-FLU-14), pero **no se sigue del argumento
de finalidad**:

- **Lo que sí se demuestra:** ver un ancla distinta es evidencia **estructural** de una bifurcación
  de cadena con `slot < T_j` (Lema 1). Eso es una propiedad del DAG, comprobable sin AES.
- **Lo que no se sigue:** que alguien haya violado la finalidad (§0.3).
- **De dónde sale de verdad:** de **DF-2**. Sin regla de adopción no existe ningún procedimiento que
  obligue a evaluar el PoT del flujo rival. Es una consecuencia de una decisión, no de un teorema.
- **⛔ Y en la revisión 5 (b) queda RETIRADA a la letra.** DF-2 se decidió sobre la ventana vacía de
  §0.2, que es **falsa**; Katana decidió **D-F9 = C** el 2026-09-20 y **C-FLU-22** permite adoptar
  dentro de la ventana, lo que **sí** exige verificar el PoT de un flujo ajeno. La versión exacta
  que sustituye a (b), y que es la que hay que citar:

  > **Un nodo honesto nunca verifica el PoT de un flujo ajeno para FUSIONAR** —C-FLU-14 es
  > estructural y no toca AES— **; solo lo verifica para ADOPTAR, dentro de la ventana de C-FLU-22
  > y bajo presupuesto.**

  Y lo que sí queda demostrado, y es lo que importaba: **forzar ese gasto exige ganar la carrera A2**
  (C-FLU-22 §5, demostrado), **no hay vía barata**, y el camino normal —validar y fusionar el propio
  flujo— **nunca paga AES ajeno**.
- **Lo que la virtud de R-FIN-5 no cubre, y la auditoría ya avisó:** rechazar un sub-DAG de flujo
  ajeno **sigue costando recomputar cadena y flujo** antes de decidir — superficie de DoS
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:116`).
  Lo que no cuesta es AES: los 92 ms/slot (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:2987-2988`)
  no se pagan nunca por un flujo ajeno. Esa es la virtud que se conserva, dicha con su alcance.

---

## 1 · Símbolos, unidades y el contrato de comparación (borde 2 del encargo)

**C-FLU-01 · Todo lo del flujo se mide en índices de slot de PoT; `L` va atada a `F`. — propuesto**

```text
T_j         = j · I_slots                     umbral de época j (índice de slot)
I_j         = ancla de la época j             (C-FLU-04)
t_j         = slot(I_j) + L_slots             instante de activación (índice de slot)
profundidad(t, P) = t − slot(P)               en slots, con P el punto de bifurcación
F_slots                                       finalidad expresada en índices de slot
L_suelo_slots                                 suelo de L, parámetro de consenso (símbolo)
L_slots ≥ máx(F_slots, L_suelo_slots, S_max_slots + 1)      perfil 1a (DF-1) con suelo
S_max_slots < L_slots      (C-FLU-08)   y     S_max_slots < I_slots      (C-FLU-09)
```

- **Verificado en fuente — por qué en slots y no en segundos.** El contrato de unidades del SPEC
  declara `slot(B)`, `I_slots`, `L_slots`, `S_max_slots` y `D_aut_slots` como «índices o cantidades
  enteras de slots PoT», y `τ_nom·I_slots` como duración **nominal**
  (`/home/katana/zeo/ZEROX/SPEC.md:1449-1452, 1459-1462`). R-FIN-7 está escrita en «`F` segundos de
  slot» (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:301-302`) y su enmienda D9-f B0
  insiste en que «`F` se expresa en **segundos**, **no en slots**», señalando que «slot» aparecía en
  R-FIN-1a, R-FIN-7 y R-FIN-13 «con tres escalas incompatibles»
  (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:308-309`).
- **Propuesto — la conversión, y por qué la comparación tiene que ser en slots.** `F` es un
  parámetro de diseño en segundos de slot; la **regla de consenso** compara enteros:
  `F_slots := ⌈F / τ_nom⌉`. Una comparación de consenso **MUST NOT** depender de `τ_nom` en tiempo
  de ejecución ni de ningún reloj físico: el `slot` es el índice del PoT, la única magnitud que el
  atacante no puede fabricar a coste cero (**verificado en fuente, evidencia histórica:**
  `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:187-190`, el historial de anclas y su
  lección). Con `τ_nom = 1 s/slot` y `F = 2 h` provisional, `F_slots = 7 200`
  (**verificado en fuente:** `F = 2 h` provisional en `/home/katana/zeo/ZEROX/SPEC.md:1436`).
- **DECIDIDO por Katana el 2026-09-20 — la atadura de DF-1 lleva SUELO, y ésa es la forma final.**
  (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:19`.) `L_slots` **MUST** derivarse y no declararse
  aparte:

  ```text
  L_slots := máx( F_slots , L_suelo_slots , S_max_slots + 1 )
  ```

  - **El primer término** es la atadura de DF-1: «si `F` baja en producción, `L` baja con ella» es
    una identidad, no una nota de operación.
  - **El segundo término es el suelo, y existe justamente porque el primero no basta.** Atar `L` a
    `F` **a secas** significa que bajar `F` baja `L`, y `L` responde a una magnitud distinta —la
    cola de desacuerdo honesto frente a `Δ`—, que no baja cuando baja `F`. **`L_suelo_slots` es un
    parámetro de consenso y va como símbolo: esta propuesta no le pone valor** (encargo §6).
  - **El tercer término** hace que C-FLU-08 (`S_max < L`) se cumpla por construcción para cualquier
    `F`. Con los valores nominales de hoy no muerde: `S_max_slots = 150` frente a `F_slots = 7 200`
    (**verificado en fuente:** `S_max = 150` nominal, `/home/katana/zeo/ZEROX/SPEC.md:1429-1430`).

- **Propuesto — criterio de calibración de `L_suelo_slots`, sin cifra.** `L_suelo_slots` **MUST**
  fijarse a partir de **(a)** la cola medida `G(d)` de desacuerdo de cadena seleccionada a
  profundidad `d`, evaluada a un `ε` elegido explícitamente, y **(b)** una cota de `Δ` **medida en
  red real**, no simulada. Mientras no exista (b), cualquier valor de `L_suelo_slots` es
  provisional y debe decirlo.

  **Referencia de orden de magnitud, con su etiqueta y nada más** (**medido en simulación**,
  instrumento y alcance en `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:22-28`): `L_mín(10⁻³)` ≈ 0 con
  `Δ` nominal, **119** slots con `Δ = 4 s`, **1 198** con `Δ = 10 s`, **1 682** con `Δ = 16 s`; A3
  estática con `α = 0,45`: **177**. Su extrapolación a `10⁻⁹` es ≈**360** / ≈**3 600** / ≈**5 000**
  slots, etiquetada **`estimado`** en la propia fuente (cola exponencial ajustada, no medida a ese
  nivel). **Y la `Δ` de todas esas cifras es simulada (DMS-v0.1), no medida en red**
  (`/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:28`). **Ninguno de estos números es el valor de
  `L_suelo_slots`:** son la referencia contra la que habrá que calibrarlo cuando exista `Δ` medida.

  **Lo que el suelo compra, en una línea:** que la obligación de bajar `F` en producción
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:163`, «es
  obligación bajarla en producción») no arrastre a `L` por debajo de lo medido. Sin suelo, `F = 1 h`
  daría `L_slots = 3 600`, por debajo del ≈3 600-5 000 extrapolado para `Δ` = 10-16 s — el defecto
  que esta propuesta había anotado como pendiente en su revisión 1 y que el suelo cierra.
- **No determinado por el SPEC:** los valores de `I_slots`, `F` y `ρ_max` siguen abiertos
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1436-1438`, «`I`, `L`, `ρ_max`, la
  configuración final de `F` y la calibración frente a `Δ` siguen abiertos»). Esta propuesta no fija
  ninguno: van como símbolos.
- **Propuesto — la magnitud de la profundidad.** «Profundidad de una reorganización» **MUST**
  significar `slot(punta) − slot(último ancestro común)`, en índices de slot. **No** en bloques: a
  `λ = 1 bloque/s` y `τ_nom = 1 s/slot` coinciden nominalmente, pero R-FIN-1a admite saltos de hasta
  `S_max_slots` en la cadena (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1689`,
  C-GD-04: «Siguen vigentes `slot(sp(B)) ≤ slot(B)` (C-HDR-05) y `slot(B) − slot(sp(B)) ≤ S_max`»),
  así que las dos cuentas se separan y solo una de ellas es infalsificable.

> **Una observación de coherencia.** `SPEC.md:1436` advierte que `F` «no se iguala por defecto a
> `L`». DF-1 ata la dependencia en el **sentido contrario** (`L` se deriva de `F`), que es el que
> C-FLU-01 escribe. No hay conflicto, pero conviene que el traslado al SPEC lo diga, porque las dos
> frases se parecen mucho y significan cosas opuestas.

---

## 2 · El ancla, bien fundada: la reparación de E1, escrita

R-FIN-1, **tal como está escrita hoy, es circular**: «el ancla depende de la cadena, la cadena de la
validez, la validez del ancla» (**verificado en fuente:**
`/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:83`, clasificación **REFUTADA**).
Su reparación se propuso el mismo día y **nunca se incorporó**:
«`I_j :=` primer bloque con `slot ≥ E_j` de la cadena seleccionada del bloque virtual sobre
`past(B) ∩ {slot < t_j}`. Eso sí es bien fundado por inducción sobre `j`»
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:84`).
El propio SPEC registra el hueco: «Origen/bootstrap, existencia del ancla, desempates y
disponibilidad después de poda aún deben cerrarse» (**verificado en fuente:**
`/home/katana/zeo/ZEROX/SPEC.md:1453-1455`), y R-FIN-1 lleva su «Cierre pendiente» explícito
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:172-174`).

Esta propuesta la redacta reparada, con **un cambio sobre la reparación de la auditoría**: el corte
de la vista se fija en `T_j + L_slots`, que **no depende del ancla**, en vez de en `t_j`, que sí.

### C-FLU-02 · Cierre de ancestros por slot — propuesto, con **D-F6 = A DECIDIDA por Katana (2026-09-20)**

Para todo bloque `B` y **todo** padre `p` de `B`: `slot(p) ≤ slot(B)`, **desigualdad no estricta**
(el empate de slot está permitido, como en C-HDR-05).

> **DECIDIDO** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:21`): se amplía la cota a todos los
> padres. Lo que sigue ya no es condicional.

- **Por qué hace falta.** La vista de época de C-FLU-03 es un corte por `slot`. Para que ese corte
  sea un sub-DAG bien formado tiene que ser **cerrado por ancestros**: si `X` está en la vista, sus
  ancestros también. Eso exige que ningún padre tenga un `slot` mayor que su hijo. Sin esta regla, un
  bloque dentro del corte puede tener un padre fuera, el sub-DAG queda incompleto y GHOSTDAG no está
  definido sobre él.
- **Verificado en fuente — el SPEC hoy solo lo exige del padre seleccionado.** C-HDR-05 dice
  `slot(sp(B)) ≤ slot(B)` y nada de los demás padres
  (`/home/katana/zeo/ZEROX/SPEC.md:879-881`); C-GD-04 repite exactamente esa cota y la de `S_max`,
  también solo sobre `sp` (`/home/katana/zeo/ZEROX/SPEC.md:1689`). **No determinado por el SPEC:**
  el slot de los padres no seleccionados.
- **Demostrado (dado C-FLU-02):** para cualquier cota `c`, el conjunto `{X ∈ past(B) ∪ {B} : slot(X) < c}`
  es cerrado por ancestros. *Prueba:* si `X` está en el conjunto e `Y` es padre de `X`, entonces
  `slot(Y) ≤ slot(X) < c`; por inducción sobre la longitud del camino, todo ancestro de `X` cumple lo
  mismo. ∎

**(i) Consecuencia para la selección de padres — propuesto; afecta a C-GD-10.** El productor de un
bloque **MUST NOT** referenciar puntas con `slot` mayor que el suyo: debe **descartarlas de la cola
de candidatos** antes de barajarla. C-GD-10 ya tiene ese patrón exacto para C-GD-11 —«el productor
**MUST** descartar de la cola de candidatos toda punta cuya inclusión produciría un bloque que viola
C-GD-11. Un productor no puede emitir un bloque inválido por una elección de padres que él mismo
controla» (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1727-1729`)— y C-FLU-02 se
añade a esa lista. **Y hay un segundo punto que el traslado no puede olvidar:** C-GD-10 cierra
diciendo que un verificador «**MUST NOT** rechazar un bloque por el conjunto de padres que eligió su
autor **mientras cumpla C-GD-04, C-GD-11 y C-HDR-05**» (**verificado en fuente:**
`/home/katana/zeo/ZEROX/SPEC.md:1731-1733`). Esa enumeración es **cerrada**: si C-FLU-02 es materia
de validez —y lo es, porque la buena fundamentación del ancla depende de ella—, **C-FLU-02 tiene que
entrar en esa lista**. Dejarla fuera haría que la regla fuese política de producción y no validez, y
entonces el corte por slot volvería a no ser cerrado por ancestros.

**(ii) Coste para el productor honesto: `estimado ≈ 0`, A CONFIRMAR antes de pasar al SPEC.** La
magnitud que hay que medir es la **fracción de bloques honestos que referenciarían hoy un padre de
`slot` mayor que el suyo**, bajo `Δ` = 0,5 / 4 / 16 s. El razonamiento por el que se estima ≈0: un
padre con `slot` mayor es una punta producida **después**, en índice de PoT, que el bloque que la
referencia; con `τ_nom = 1 s/slot` y `λ_obj = 1 bloque/s` (**verificado en fuente:**
`/home/katana/zeo/ZEROX/SPEC.md:1429`) eso exige que el productor incorpore una punta de un slot que
su propio reloj PoT aún no ha alcanzado, y C-NET-32.2 ya obliga a **retener**, no verificar, lo que
va por delante del reloj PoT del nodo (**verificado en fuente:**
`/home/katana/zeo/ZEROX/SPEC.md:3003-3004`). **Pero esto es un argumento, no una medición**, y el
régimen candidato `τ ≈ 0,1-0,17 s` (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:317-318`)
multiplica por 6-10 los empates y cruces de slot, así que la estimación **no se extrapola sola**.
**Instrumento propuesto:** ANCLA-v0.2 (`/home/katana/zeo/ZEROX/P-2.1/veritas/consenso/ancla-inyeccion-v2/`),
que ya tiene el DAG y las réplicas con `Δ` parametrizable. **Etiqueta: `estimado`, a confirmar con
ANCLA-v0.2 antes de pasar al SPEC** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:21`).

**(iii) Qué toca este cambio, en concreto.**

| Dónde | Qué hay hoy | Qué habría que hacer |
|---|---|---|
| `SPEC.md` §6.1, **C-HDR-05** | `slot(sp(B)) ≤ slot(B)` y nada de los demás padres (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:879-881`) | ampliar la cota a todos los padres, o añadir C-FLU-02 al lado |
| `SPEC.md` §11, **C-GD-04** y **C-GD-10** | C-GD-04 repite la cota solo sobre `sp` (`/home/katana/zeo/ZEROX/SPEC.md:1689`); C-GD-10 enumera C-GD-04/C-GD-11/C-HDR-05 (`:1731-1733`) | añadir C-FLU-02 a la enumeración y al descarte de la cola |
| `crates/zx-core` | `comprobar_diferencia_slots_del_bloque(...)` recibe **solo** `slot_sp` (**verificado en fuente:** `/home/katana/zeo/ZEROX/crates/zx-core/src/wire_dag.rs:283-288`) y el error `C-HDR-05` es `slot(B) < slot(sp)` (`:319-320`) | una comprobación nueva sobre **todos** los padres, con su error propio |
| `crates/zx-consensus` | `ContextoDag` expone `es_bloque_validado`, `esta_en_el_pasado_de`, `padre_seleccionado` y `es_genesis` — **no hay forma de pedir el `slot` de un padre arbitrario** (**verificado en fuente:** `/home/katana/zeo/ZEROX/crates/zx-consensus/src/bloque_dag.rs:141-170`) | añadir un accesor de `slot` al trait; sin él la regla no es comprobable en ese crate |

Esta propuesta **no ha tocado ninguno de esos archivos** (encargo §8.1): la tabla es el trabajo que
el traslado tendrá que hacer.

### C-FLU-03 · Vista de época: el corte no puede depender del ancla — propuesto

```text
V_j(B) := ( past(B) ∪ {B} ) ∩ { X : slot(X) < T_j + L_slots }
```

- **Propuesto — por qué `T_j + L_slots` y no `t_j`.** La reparación de la auditoría corta en
  `{slot < t_j}`, pero `t_j = slot(I_j) + L_slots` **depende del ancla que se está definiendo**. Es
  una circularidad más leve que E1 (se resuelve porque `t_j ≥ T_j + L_slots`), pero innecesaria: el
  corte `T_j + L_slots` es función de `j` y de las constantes, y solo de eso. Consecuencia dicha en
  voz alta: la vista `V_j` es **más pequeña** que la de la auditoría (`{slot < t_j} ⊇ {slot < T_j+L}`),
  así que un bloque con `slot ∈ [T_j + L_slots, t_j)` **no** participa en elegir el ancla. Es
  deliberado: esos bloques son posteriores al primer instante en que la época pudo activarse.
- **Demostrado — el ancla cae dentro de la vista (requiere C-FLU-08, `S_max_slots < L_slots`).**
  El bloque de `Chn(V_j)` inmediatamente anterior al primer cruce tiene `slot < T_j`; por R-FIN-1a,
  `slot(I_j) − slot(anterior) ≤ S_max_slots`, luego `slot(I_j) < T_j + S_max_slots < T_j + L_slots`.
  ∎ Es el argumento de la «Corrección de alcance (2026-09-10)» de R-FIN-1, aplicado al corte
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:181-183`:
  «el intervalo semiabierto se obtiene si el ancla es el primer cruce, con padre `p<T_j` y salto
  `≤S_max_slots`: entonces `b<T_j+S_max_slots`»). **Sin `S_max_slots ≤ L_slots` la definición se
  queda sin sentido**, porque el ancla podría caer fuera de la vista que la define.

### C-FLU-04 · El ancla: primer cruce de `T_j` por la cadena seleccionada de la vista — propuesto

```text
I_j(B) := el primer bloque de Chn(V_j(B)) con slot ≥ T_j,
          donde Chn(V_j(B)) es la cadena seleccionada del bloque virtual sobre V_j(B),
          calculada con las reglas de §11 (C-GD-01…C-GD-07) restringidas a V_j(B)
```

**Equivalencia con R-FIN-1 tal como está escrita — verificado en fuente, demostrado en la fuente.**
R-FIN-1 dice «menor `blue_work` entre los de `slot ≥ T_j`»
(`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:170-171`). La Prop. 1 de la ronda 11c
demuestra que **las dos formulaciones devuelven el mismo bloque**, apoyándose en (F1) `slot` no
decreciente por la cadena seleccionada y (F2) `blue_work` estrictamente creciente por ella
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c/informe.md:31-37`
para F1/F2 y `:39-51` para la Prop. 1, etiquetada **DEMOSTRADO** allí; su consecuencia, `:53-58`).
**Alcance declarado en la propia fuente:** esa ronda «murió por cuota»; la proposición está
demostrada en el texto, **sus mediciones no están verificadas** (encargo §3.5). Aquí se usa solo la
proposición, no sus números.

(F2) tiene además respaldo independiente en el repositorio: la compatibilidad causal de `rank`
—si `A` es ancestro de `B`, `blue_work(A) < blue_work(B)`— está demostrada en
`/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md:38-66`
(**verificado en fuente**).

> **Unicidad — demostrado.** `Chn(V_j(B))` es una **secuencia** de bloques (cada uno es el padre
> seleccionado del siguiente; C-GD-03 elige `sp` de forma total y determinista: mayor `blue_work`,
> luego menor `solution_distance`, luego menor id por bytes — **verificado en fuente:**
> `/home/katana/zeo/ZEROX/SPEC.md:1682-1685`). «El primer elemento de una secuencia que cumple un
> predicado» es único si existe. Por (F1) el conjunto `{B ∈ Chn : slot(B) ≥ T_j}` es un **tramo
> final contiguo** de la cadena, y su primer elemento es el único candidato. ∎

> **Existencia — demostrado condicionalmente, y la condición se nombra.** `I_j(B)` existe **si y
> solo si** `Chn(V_j(B))` contiene algún bloque con `slot ≥ T_j`, lo que equivale a que la **punta**
> de esa cadena tenga `slot ≥ T_j` (por (F1), si la punta cruza, el conjunto de cruces es no vacío;
> si no cruza, ningún elemento de la cadena lo hace).
>
> **Condición suficiente, demostrada:** si `slot(B) ≥ T_j + L_slots` y la cadena seleccionada de `B`
> coincide con `Chn(V_j(B))` por debajo del corte, entonces `I_j(B)` existe. *Prueba:* la cadena de
> `B` va del génesis (`slot = 0`, **verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:881`)
> hasta `slot(B) ≥ T_j + L_slots` con saltos `≤ S_max_slots < L_slots` (R-FIN-1a, C-GD-04); sea `p`
> el último bloque de la cadena con `slot < T_j` (existe, el génesis lo cumple para `j ≥ 1`) y `q` su
> sucesor en la cadena: `T_j ≤ slot(q) ≤ slot(p) + S_max_slots < T_j + L_slots`, luego `q ∈ V_j(B)`
> y cruza. ∎
>
> **Cuándo puede fallar, dicho sin adornos:** falla exactamente cuando `Chn(V_j(B))` **diverge** de
> la cadena de `B` por debajo de `T_j`. Eso es un suceso de la misma clase que la partición de flujo
> de §0.3, y no está excluido por ningún teorema: no hay ninguna proposición que ate `blue_work` con
> `slot`, así que un bloque de `slot` pequeño con mucho `blue_work` podría ser la punta de `V_j`. En
> un régimen con `λ` controlada por el retarget es un suceso de cola; **no está medido**. Se declara
> en «Lo que esta propuesta NO resuelve» y la regla de cierre es C-FLU-05.

> **Buena fundamentación — demostrado, por inducción sobre `j`.** Es lo que E1 pedía y no había.
>
> *Hipótesis de inducción:* para todo `j' < j`, la inyección `j'` (su existencia, su `I_{j'}`, su
> `t_{j'}` y su entropía) está determinada.
>
> *Paso:* para calcular `I_j(B)` hace falta `Chn(V_j(B))`, es decir el color y el `blue_work` de los
> bloques de `V_j(B)`, es decir su **validez**, es decir su **flujo**. Un bloque `X ∈ V_j(B)` tiene
> `slot(X) < T_j + L_slots`. Su flujo depende (C-FLU-10) de las inyecciones `j'` con
> `t_{j'} ≤ slot(X)`. Por C-FLU-07, `t_{j'} = slot(I_{j'}) + L_slots ≥ T_{j'} + L_slots`. Luego
>
> ```text
> j'·I_slots + L_slots  ≤  t_{j'}  ≤  slot(X)  <  T_j + L_slots  =  j·I_slots + L_slots
> ⟹  j'·I_slots < j·I_slots  ⟹  j' < j
> ```
>
> Toda dependencia es de épocas **estrictamente anteriores**. El caso base `j = 1` se cierra con
> C-FLU-06 (flujo del génesis), que no depende de ninguna inyección. **No hay punto fijo que
> postular: la recursión termina.** ∎

> **⛔ `Chn(V_j(B))` NO es la cadena seleccionada del nodo — añadido en la revisión 4.** Es la
> propiedad que hace bien fundada la definición, y es también la que rompió mi Prop. A y mi
> conclusión (c). Dos consecuencias que hay que leer junto a esta regla:
>
> 1. **`V_j(B)` crece sin reorganización.** Basta que un bloque nuevo **fusione** un bloque retenido
>    con `slot < T_j + L_slots`. Fusionar no es reorganizar; ninguna regla de finalidad lo toca.
>    Mientras `slot(B) < t_j`, eso puede cambiar `I_j` legalmente: es la carrera **A2** de §0.4.
> 2. **La elección dentro de `V_j` es `blue_work` puro, sin color.** El virtual toma la punta de
>    mayor `blue_work` de `V_j` (C-GD-03), y `blue_work` es **intrínseco** al bloque
>    (`/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md:68-70`). Que un
>    bloque retenido llegue **rojo** no lo excluye de `V_j`: el argumento del k-cluster de
>    `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:110` protege la cadena
>    seleccionada real, **no esta**.
>
> Desde `t_j` la deriva se detiene por C-FLU-14/A1 y C-FLU-21, y el productor la evita con C-FLU-20.
> **Antes de `t_j` no hay regla: hay carrera.** Congelar la vista en el bloque que cruza el corte
> eliminaría (1), y lo que eso reabre está en **D-F8**.

- **Lo que esto NO arregla, y hay que decirlo:** el ancla queda bien fundada, pero la **convergencia
  del orden** bajo las reglas añadidas sigue sin demostrarse. Prop. 7 y Def. 2 de GHOSTDAG están
  probadas sobre GHOSTDAG **puro**; U3″, R-FIN-5 y R-FIN-8 se añaden encima y «que el orden total
  siga convergiendo bajo las tres **no está comprobado**. Es la deuda principal»
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:436-439`).
  (F1) y (F2), de las que cuelga toda esta sección, son propiedades del simulador y de un lema
  medido, no del teorema del paper.

---

## 3 · Arranque: la época sin ancla, el flujo del génesis y `semilla(f, 0)`

### C-FLU-05 · Época sin ancla: la época se salta, y saltarla es definitivo — propuesto

```text
Si Chn(V_j(B)) no cruza T_j, la época j NO produce inyección para B:
el flujo de B sigue siendo el de la última inyección realizada.
Además, un bloque B con slot(B) ≥ T_j + L_slots para el que I_j(B) no exista es INVÁLIDO.
```

- **Propuesto — por qué la segunda frase.** Sin ella la regla no es monótona y la cadena se atasca:
  si `B` salta la época `j` y un descendiente `B'` no la salta (su vista `V_j(B')` es mayor y sí
  cruza), entonces `B'` tiene un flujo distinto del de `B` en slots donde `B` ya está fijado, y
  R-FIN-5 invalida `B'` (C-FLU-14). El resultado sería una cadena que no puede extenderse. Declarar
  inválido al bloque que llega a `T_j + L_slots` sin ancla convierte el caso patológico en un
  rechazo local en lugar de en un bloqueo global.
- **Demostrado:** con la condición suficiente de C-FLU-04, un bloque honesto cuya cadena
  seleccionada coincide con la de su vista de época **nunca** cae en este caso. El rechazo solo
  alcanza a bloques cuya vista de época diverge por debajo de `T_j`.
- **Propuesto — nunca hay inyección retroactiva.** Una época saltada **MUST NOT** recuperarse
  después. Si se permitiera, un bloque tardío cambiaría el flujo de slots ya transcurridos, que es
  exactamente el defecto que la caché por slot de C-NET-31 ya sufre y que `C-POT-07` corrige
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:227-234`).

### C-FLU-06 · El flujo del génesis y el origen de `semilla(f, 0)` — propuesto

```text
f_0        := H_flujo( ETIQUETA_GENESIS ‖ block_hash(génesis) )        32 B
semilla(f_0, 0) := blake3( block_hash(génesis) ‖ entropía_externa )[0..16)
```

y `flujo(B, s) = f_0` para todo `s < t_1`, donde `T_1 = I_slots` es el primer umbral (la época se
indexa desde `j = 1`; no hay época 0 y el génesis **no** es ancla de nada).

- **Verificado en fuente — el hueco que se cierra.** `P-POT` declara explícitamente que
  `semilla(f, 0)` «la aporta el contexto» y que «de dónde sale … queda fuera de este alcance»
  (`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:54-58`, y de nuevo en su cierre,
  `:356-357`). Esta regla es la respuesta.
- **Verificado en fuente — el diseño candidato, no normativo. Archivo abierto de primera mano
  (revisión 2, por `ADENDA-1.md:56`).** Autonomys deriva la semilla inicial en
  `PotSeed::from_genesis(genesis_block_hash, external_entropy)`, que es
  `blake3_hash_list(&[genesis_block_hash, external_entropy])` truncado a `Self::SIZE = 16` bytes
  (`/home/katana/zeo/ZEROX/PDF/autonomys-subspace/crates/subspace-core-primitives/src/pot.rs:178-187`).
  Y `blake3_hash_list` es **exactamente** el hash de la concatenación: crea un `blake3::Hasher` y
  hace `update` de cada elemento en orden
  (`/home/katana/zeo/ZEROX/PDF/autonomys-subspace/crates/subspace-core-primitives/src/hashes.rs:151-157`).
  Luego `blake3(block_hash(génesis) ‖ entropía_externa)[0..16)` es la transcripción fiel, y la cita
  que `P-POT` daba (`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:59-60`) es correcta.
  **Deja de ser cita de segunda mano.**
- **Propuesto — `entropía_externa` es parámetro de lanzamiento**, no algo que derive el nodo. Su
  sitio natural es `SPEC.md` §15.2, que hoy tiene el hueco abierto: «**Pendiente:** mensaje,
  timestamp, **estado inicial de espacio y PoT**, rango inicial, parámetros DAG y hashes de
  mainnet/testnet» (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:2193-2194`). Debe ser
  pública, verificable e **imposible de elegir después** de conocer el génesis; esta propuesta no
  fija cuál es (fuera de alcance: es un parámetro de lanzamiento, no una regla de flujo).
- **Propuesto — el génesis no lleva justificación ni es ancla.** Coherente con
  `pot_bundle_count = 0` en el génesis (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/SPEC.md:921-922`, «`d = 0` tiene lista vacía canónica; el génesis usa cero
  portadores») y con `slot = 0` (`/home/katana/zeo/ZEROX/SPEC.md:881`). El génesis **no tiene
  solución PoAS real**, así que no tiene `chunk` con el que alimentar C-FLU-12: por eso la época se
  indexa desde 1 y el flujo inicial es una constante, no una inyección.
- **`ETIQUETA_GENESIS` — D-F2 = A DECIDIDA (2026-09-20).** `ETIQUETA_GENESIS := "ZZKFlowGenesis__"`
  (16 bytes ASCII, **propuesta**), etiqueta de dominio **nueva** que hay que **añadir a C-HASH-06**,
  cuya lista está declarada **cerrada** (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/SPEC.md:560-561`). Detalle y justificación en C-FLU-10.
  **Obsérvese que `semilla(f_0, 0)` NO usa `H_flujo`:** conserva `blake3` porque ahí sí hay oráculo
  —es la derivación de Autonomys, verificada en fuente arriba— y porque alimenta la primitiva PoT,
  que D-1 = A dejó entera en `blake3`. **Las dos líneas de C-FLU-06 usan hashes distintos a
  propósito**, y el traslado al SPEC no debe «uniformarlas».

---

## 4 · Activación retardada: una sola lotería, y las dos condiciones sobre `S_max_slots`

### C-FLU-07 · `t_j = slot(I_j) + L_slots`; hasta `t_j` rige el flujo anterior — propuesto

```text
t_j := slot(I_j) + L_slots
Para todo slot s:  flujo(B, s) lo fija la ÚLTIMA inyección j con t_j ≤ s
                   (si no hay ninguna, f_0; C-FLU-06)
```

- **Verificado en fuente, evidencia histórica:** es R-FIN-2,
  `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:212-214`, y el contrato de unidades del
  SPEC ya registra `t_j = slot(I_j) + L_slots` como «índice de inyección»
  (`/home/katana/zeo/ZEROX/SPEC.md:1452`).
- **Demostrado — una sola lotería.** Para todo `s ∈ [slot(I_j), t_j)`, `flujo(B, s)` no depende de
  `I_j`: por la regla de arriba, `flujo(B, s)` lo fija la última inyección con `t_{j'} ≤ s < t_j`, y
  ésa es `j−1` o anterior. Luego dos nodos que **discrepen** del ancla `I_j` producen y verifican
  **exactamente el mismo** `reto(f, s)` en todo ese intervalo, y la lotería de PoAS es una sola. ∎
  Es la afirmación de R-FIN-2 y aquí queda con prueba en vez de por enunciado.
- **Propuesto — y es la razón de ser de todo el retardo:** el intervalo `[slot(I_j), t_j)` es donde
  la red tiene `L_slots` para converger sobre `I_j` **sin que la discrepancia tenga consecuencias**.
  Lo que ocurre en `t_j` es que la discrepancia, si sobrevive, **se vuelve irreversible** (§0.4).

### C-FLU-08 · `S_max_slots < L_slots` — condición de CORRECCIÓN — propuesto

- **Demostrado (contenido 1, el que hace falta para que la definición exista):** con
  `S_max_slots ≤ L_slots`, `slot(I_j) < T_j + S_max_slots ≤ T_j + L_slots`, luego **el ancla cae
  dentro de su propia vista de época `V_j`** (C-FLU-03). Sin esta condición, la definición reparada
  del ancla no está bien puesta: el ancla podría quedar fuera del corte que la define. ∎
- **Demostrado (contenido 2, el entierro):** con `S_max_slots < L_slots`, en el instante `t_j` la
  cadena contiene **al menos un bloque estrictamente entre `I_j` y `t_j`**: el sucesor de `I_j` en la
  cadena tiene `slot ≤ slot(I_j) + S_max_slots < slot(I_j) + L_slots = t_j`. El ancla nunca es la
  punta en el momento de usarse; está enterrada bajo `≥ ⌈L_slots/S_max_slots⌉ ≥ 2` bloques de
  cadena. ∎
- **Propuesto, con una corrección de atribución que hay que hacer.** El encargo presenta esta
  condición como la de la auditoría: «`X < L` es condición de corrección, no una opción»
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:110`).
  **Pero la `X` de esa frase no es `S_max`:** es el parámetro de **antigüedad de publicación** de
  R-INJ-5, y el mecanismo que la auditoría invoca es que «un bloque con slot antiguo llega **rojo** y
  GHOSTDAG nunca elige un rojo como padre seleccionado» (misma línea). Son dos objetos distintos:
  `S_max_slots` acota el **salto de slot en la cadena** (R-FIN-1a / C-GD-04,
  `/home/katana/zeo/ZEROX/SPEC.md:1689`), no la antigüedad de publicación. Trasladar la condición de
  uno al otro es legítimo pero **no es la misma demostración**, y se etiqueta como propuesta.
- **Y el ataque que esa condición buscaba cerrar ya lo cierra otra cosa.** «Un bloque retenido con
  slot junto a `T_j` cambia el ancla tras la activación» queda cerrado por la **Prop. A** de §0.4:
  con `L_slots ≥ F_slots`, cambiar `I_j` después de `t_j` exige una reorganización de profundidad
  `≥ F_slots + 1`, que R-FIN-7 prohíbe. **La condición de corrección de C-FLU-08 no es la que cierra
  el ataque; es la que hace que la definición del ancla tenga sentido.** Decirlo al revés sería
  repetir el patrón de etiqueta ancha sobre resultado estrecho.
- **Coste: ninguno con los valores de hoy.** `S_max_slots = 150` frente a `L_slots ≥ F_slots = 7 200`
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1429-1430, 1436`). C-FLU-01 la hace
  además automática con el tercer término de `L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`.

### C-FLU-09 · `S_max_slots < I_slots`; los `t_j` son distintos dos a dos — propuesto

- **Demostrado.** `t_j = slot(I_j) + L_slots` con `slot(I_j) ∈ [T_j, T_j + S_max_slots)`, luego
  `t_j ∈ [T_j + L_slots, T_j + S_max_slots + L_slots)`. Con `S_max_slots < I_slots`:

  ```text
  t_j  <  T_j + S_max_slots + L_slots  <  T_j + I_slots + L_slots  =  T_{j+1} + L_slots  ≤  t_{j+1}
  ```

  luego `t_j < t_{j+1}` **estrictamente**, y por transitividad los `t_j` son distintos dos a dos y
  además están **ordenados como las épocas**. Corolario inmediato: **a lo sumo una inyección por
  slot**, que es lo que `C-POT-01` exige del contexto y cuya violación deja el estado en `Pendiente`
  por error de contexto (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:52-53`). ∎
- **Verificado en fuente, evidencia histórica:** es R-FIN-14(g), «Los `t_j` son distintos dos a dos
  (dado `S_max < I`)» (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:276-277`). Allí va
  sin prueba; aquí la lleva.
- **Verificado en fuente — su estatuto.** El SPEC la conserva «como **condición suficiente del
  perfil propuesto**, no como necesidad universal demostrada»
  (`/home/katana/zeo/ZEROX/SPEC.md:1464-1466`). Esta propuesta no la eleva a necesidad: demuestra
  que **es suficiente** para lo que se usa (orden estricto de los `t_j` y una inyección por slot).
- **Verificado en fuente — lo que la condición NO da.** El mismo párrafo del SPEC avisa de que «`I`
  separa umbrales, no necesariamente los instantes realizados de inyección»
  (`/home/katana/zeo/ZEROX/SPEC.md:1454-1455`): con épocas saltadas (C-FLU-05) el número de
  inyecciones realizadas puede ser menor que el de umbrales cruzados.

---

## 5 · El identificador de flujo: acumulativo, derivado del pasado, nunca declarado

### C-FLU-10 · Derivación del identificador de flujo — propuesto

```text
flujo(B, s) := f_0                                                          si no hay inyección con t_j ≤ s
flujo(B, s) := H_flujo( flujo(B, t_j − 1) ‖ entropía_j(B) ‖ LE64(t_j) )     con j la última inyección con t_j ≤ s
```

donde `entropía_j(B)` es la de C-FLU-12 e `I_j(B)` la de C-FLU-04. El resultado son **32 bytes**,
que es exactamente lo que el contexto del verificador entrega hoy:
`fn flujo(&self, slot: u64) -> [u8; 32]` (**verificado en fuente:**
`/home/katana/zeo/ZEROX/crates/zx-core/src/wire_dag.rs:356-357`), y lo que `P-POT` trata como
**valor opaco** (`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:176-179, 217-219`).

- **Verificado en fuente, evidencia histórica:** es R-FIN-3,
  `flujo(B, s) = H(flujo(B, t_{j−1}) ‖ entropía_j ‖ t_j)`
  (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:216-217`). **Tres cambios de
  redacción, y los tres importan:**
  1. `flujo(B, t_{j−1})` se sustituye por `flujo(B, t_j − 1)`: «el valor vigente justo antes de esta
     inyección». Con épocas saltadas (C-FLU-05) `t_{j−1}` puede no existir, y con el índice literal
     la fórmula se queda sin primer argumento. `t_j − 1` siempre existe.
  2. `t_j` entra como `LE64(t_j)`, **codificación fija y explícita**. Concatenar un entero sin
     longitud fija es una invitación a la ambigüedad de concatenación; `LE64` es la convención que ya
     usa la derivación del reto (**verificado en fuente:**
     `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:92, 95-97`).
  3. `H` pasa a llamarse `H_flujo`. **D-F2 = A, DECIDIDA por Katana el 2026-09-20**
     (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:9`):

     ```text
     H_flujo(m) := H_d(ETIQUETA_FLUJO ‖ m) = SHA3-256( ETIQUETA_FLUJO ‖ m )
     ETIQUETA_FLUJO   := "ZZKFlowId_______"     16 bytes ASCII  (propuesta)
     ETIQUETA_GENESIS := "ZZKFlowGenesis__"     16 bytes ASCII  (propuesta, C-FLU-06)
     ```

     **Las dos etiquetas son nuevas y hay que AMPLIAR C-HASH-06**, que hoy se declara lista
     **cerrada**: «Estas son **todas** las etiquetas de dominio de ZEROX v1.0. Cada una mide
     exactamente 16 bytes» (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:560-561`), con
     14 entradas (`:569-584`). Las dos propuestas son ASCII puro de 16 bytes, como todas menos la
     del txid (`:563-567`); el traslado puede cambiarles el nombre sin tocar ninguna demostración.

     **Por qué aquí no aplica el argumento que ganó D-1 = A, en una línea:** D-1 conservó `blake3`
     para no perder el **oráculo diferencial** contra Autonomys —los 32 vectores byte a byte del
     port (`/home/katana/zeo/ZEROX/P-POT/propuesta/DECISIONES-PENDIENTES.md:22-26`)—, y **el
     identificador de flujo no tiene contraparte en Autonomys**: no hay oráculo que perder, así que
     solo quedaba la comodidad frente a la separación de dominio, y gana la separación. El resto del
     dominio PoT sigue en `blake3` (C-POT-01/02/03), sin cambios.
- **Demostrado — acumulativo y sin fusión.** Por construcción es una cadena de hash: el valor de la
  época `j` contiene el de `j−1`. Luego «dos linajes con las mismas parejas `(entropía, t)` son el
  mismo flujo» (R-FIN-3, misma línea) se cumple, y **el recíproco también** salvo colisión de
  `H_flujo`: dos linajes con una sola pareja distinta dan identificadores distintos. Esto es lo que
  convierte la comparación de flujos en una comparación de 32 bytes. ∎
- **Demostrado — es función exclusiva de `past(B)`.** Cada ingrediente lo es: `f_0` es constante
  (C-FLU-06); `I_j(B)` se calcula sobre `V_j(B) ⊆ past(B) ∪ {B}` (C-FLU-03/04); `entropía_j(B)` sale
  de campos de cabecera de `I_j(B)` (C-FLU-12); `t_j` sale de `slot(I_j)` y de una constante. Por
  inducción sobre `j` (la de C-FLU-04), todo el encadenado lo es. ∎ **Nada depende del orden de
  llegada, del reloj local ni de la punta local** — que es la exigencia literal de C-HDR-06
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:891-894`).

### C-FLU-11 · El flujo NUNCA se declara: la circularidad MUST ser imposible — propuesto

- **Propuesto:** ningún campo de la cabecera ni del cuerpo **MUST** contener el identificador de
  flujo, ni ningún valor del que se derive. El flujo de un bloque lo calcula el verificador a partir
  de `past(B)` y **MUST NOT** existir vía alguna que acepte un valor del candidato como si fuese el
  esperado. Es el principio literal de C-HDR-06 sobre `rango_solucion`: «la circularidad **MUST** ser
  imposible, no solo desaconsejada» (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/SPEC.md:896-898`), y el mismo que `C-POT-06` impone al verificador
  (`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:207-219`).
- **Encaje con C-HDR-06, que hoy usa `flow(B, slot(B))` sin definirlo.** C-HDR-06 escribe
  `rango_esperado(B) = controlador(past(B), flow(B, slot(B)))` (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/SPEC.md:886-889`) y no dice qué es `flow`. **C-FLU-10 es esa definición**,
  con `flow(B, slot(B)) := flujo(B, slot(B))`. Como C-FLU-10 demuestra que el flujo es función
  exclusiva de `past(B)`, la exigencia de C-HDR-06 de que el rango esperado sea «función
  **exclusiva** de ese pasado» queda satisfecha por composición, sin añadir ninguna dependencia
  nueva. **Propuesto:** el traslado al SPEC debe sustituir `flow` por `flujo` o fijar uno de los dos
  nombres; hoy conviven `flow` (C-HDR-06) y `flujo` (`wire_dag.rs:356-357`).
- **Consecuencia de orden, ya cubierta:** el identificador es **opaco** para el verificador de PoT,
  que lo usa para indexar contexto y caché y **MUST NOT** interpretarlo ni validarlo
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:217-219`).
  Esta propuesta no cambia eso: define quién lo produce, no quién lo consume.

---

## 6 · La entropía de la inyección que recibe `P-POT`

### C-FLU-12 · Entropía de la inyección, y el invariante que hoy se sostiene por accidente — propuesto, con **D-F1 = A DECIDIDA por Katana (2026-09-20)**

```text
entropía_j(B) := blake3( chunk(I_j(B)) ‖ pot_output(I_j(B)) )
```

y se entrega a `C-POT-01` como la entrada `entropía(f, t_j)`, que aplica
`semilla(f, t_j) = blake3(entropía(f, t_j) ‖ salida(f, t_j − 1))[0..16)`
(**verificado en fuente:** `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:33-36`).

- **Verificado en fuente, evidencia histórica:** es R-FIN-2,
  `entropía_j = blake3(chunk(I_j) ‖ pot_output(I_j))`
  (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:212`), y la forma de Autonomys que
  `P-POT` cita como diseño candidato, `blake3(chunk ‖ pot_output)`
  (`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:104-107`).
- **Coherente con D-1 = A** (conservar `blake3` byte a byte), decidida por Katana
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:78`).
- **DECIDIDO por Katana el 2026-09-20: D-F1 = A** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:20`).
  Ya no es condicional. **Motivo añadido por Katana, y es el que más pesa:** no atar §2.1 a la
  identidad del billete (§2.2), **que además puede cambiar** si algún día se adopta un registro de
  parcelas contra el sembrador. Es exactamente el acoplamiento que la opción B introducía; la
  investigación del sembrador lo vuelve concreto en vez de hipotético —su conclusión propuesta es
  **A1+C1**, «registrar antes del reto una raíz/versionado/cardinalidad de la parcela exacta»
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-SEMBRADOR/investigacion/INFORME.md:13`)—, y
  un registro de parcelas cambiaría qué identifica de verdad una oportunidad.
- **El coste de A sigue en pie y queda escrito:** dos billetes distintos con el mismo `chunk` en el
  mismo slot y flujo dan la misma entropía. No es el vector de equivocación (ése lo cierra
  C-FLU-12.1), pero la entropía no distingue *quién* ancló, solo *qué chunk* ganó. **No he
  encontrado el ataque, y no encontrarlo no es cerrarlo.** El registro completo de la decisión está
  en `DECISIONES-PENDIENTES.md`.

> **C-FLU-12.1 · Invariante de no-equivocación del inyector — propuesto, y por fin escrito.**
>
> **Dos copias del mismo billete MUST producir la misma entropía y el mismo `t_j`.**
>
> - **Demostrado bajo la opción A de D-F1.** La identidad del billete es
>   `(public_key, sector_index, history_size, chunk, slot)` (**verificado en fuente:**
>   `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:228`, R-FIN-11). Dos copias
>   comparten `chunk` y `slot`. Comparten flujo, porque antes de `t_j` la lotería es una sola
>   (C-FLU-07). Luego comparten `pot_output`, que es función de `(f, slot)` únicamente
>   —con D-2 = A, `pot_output(B) = salida(f, slot(B) + D)`, **verificado en fuente:**
>   `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:140-141`—, luego comparten
>   `entropía_j`. Y `t_j = slot(I_j) + L_slots` depende solo de `slot`, que es parte de la
>   identidad: comparten también el instante. **El hash del bloque, que sí es moldeable
>   refirmando, no entra en la entropía.** ∎
> - **Verificado en fuente — es el vector 1 del encargo de la auditoría, y NO funciona:**
>   `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:218` y `:477`. La propia
>   auditoría pide escribirlo: «Conviene escribirlo como invariante explícito, **porque hoy se
>   sostiene por accidente**» (`:218`). Esta regla es ese invariante.
> - **Propuesto — y por eso es una regla y no una nota:** cualquier cambio futuro que meta en la
>   entropía un campo **moldeable por el constructor del bloque** (el hash del bloque, el
>   `timestamp`, el conjunto de padres, la raíz de Merkle) **reabre** el grinding de la entropía por
>   contenido del bloque, hoy cerrado por el mismo motivo
>   (`/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:482`). La regla convierte esa
>   propiedad en una obligación comprobable en revisión.
> - **Aviso sobre D-2 = A, para quien valide.** Con la salida **futura** en la cabecera, la entropía
>   de la inyección pasa a derivarse de `salida(f, slot(I_j) + D)` en lugar de `salida(f, slot(I_j))`.
>   El invariante de arriba **se conserva** (ambas son función de `(f, slot)` y de nada más), pero el
>   argumento de *lookahead* de R-FIN-14(f) está escrito sobre la salida del propio slot
>   (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:275-280`) y **no se ha rehecho con
>   `+D`**. No lo rehago aquí: es aritmética de `P-POT`/§2.1 y queda declarado en «Lo que esta
>   propuesta NO resuelve».

---

## 7 · Validez absoluta y pasado consistente de flujo: estructural, y antes de cualquier PoT

### C-FLU-13 · Validez absoluta — propuesto

`B` es **válido** si y solo si:

1. su solución PoAS verifica bajo `reto(flujo(B, slot(B)), slot(B))`;
2. su justificación de PoT cubre el rango exigido por C-HDR-07 **bajo ese mismo flujo**;
3. todos los bloques de `past(B)` son válidos;
4. cumple C-FLU-14 (pasado consistente de flujo).

Es función de `past(B)` y de nada más.

- **Verificado en fuente, evidencia histórica:** es R-FIN-4,
  `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:219-221`.
- **Propuesto — el punto que decide todo §2.1, escrito como lo que es.** «Absoluta» significa: la
  validez de `B` **MUST NOT** depender de la cadena seleccionada del observador, de su punta, de su
  reloj ni del orden de llegada. `TAREAS.md` §2.1 avisa de que las dos salidas obvias fallan: «si la
  validez del PoT es **relativa a la cadena seleccionada**, se abre el multistream; si es
  **absoluta**, se abre el split de cadena (ATAQUE 1)» (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/TAREAS.md:155-158`). **Esta propuesta toma la rama absoluta y paga su
  precio explícitamente:** el «split de cadena» es la partición de flujo de §0, y lo que la contiene
  no es una regla sino el parámetro `L` frente a `Δ`, con la probabilidad medida en simulación de
  `P-2.1`. El multistream (`α_mínimo = 1/(S+1)`, hasta 4 % con `S ≈ 24`, **verificado en fuente:**
  `/home/katana/zeo/ZEROX/TAREAS.md:140-148`) queda cerrado porque un flujo fabricado por el
  atacante no es el flujo de ningún bloque honesto y sus bloques no se pueden referenciar
  (C-FLU-14).
- **Encaje con `P-POT`:** el paso 5 de `C-POT-08` («solo con `Válido` de PoT: derivar
  `aleatoriedad`/`reto` del slot y verificar la solución PoAS contra ese reto») es el punto 1 de esta
  regla (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:295`). No se reescribe.

### C-FLU-14 · Pasado consistente de flujo: comprobación estructural anterior a cualquier PoT — propuesto

```text
Para todo X ∈ past(B):   flujo(X, slot(X)) == flujo(B, slot(X))
```

Un bloque **MUST NOT** referenciar un bloque de otro flujo. La comprobación es **estructural** y va
**antes** de tocar ningún PoT: **un nodo honesto jamás verifica el PoT de un flujo ajeno.**

- **Verificado en fuente, evidencia histórica:** es R-FIN-5,
  `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:223-225`, y R-FIN-14(d) ya decía que
  «la comprobación de flujo es **anterior** a la de PoT (R-FIN-5)»
  (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:271-272`).
- **Demostrado — la comprobación no necesita AES.** Los ingredientes de `flujo(·)` (C-FLU-10) son:
  una constante, el `chunk` y el `pot_output` de cada ancla (dos campos de **cabecera**:
  `sol.chunk` en `[252, 284)` y `pot_output` en `[88, 104)`, **verificado en fuente:**
  `/home/katana/zeo/ZEROX/SPEC.md:834, 842`), los `slot(I_j)` (campo de cabecera, `[80, 88)`,
  `/home/katana/zeo/ZEROX/SPEC.md:833`) y el orden GHOSTDAG restringido a `V_j`. **Ninguno exige
  evaluar la cadena AES del PoT.** Luego el rechazo de un bloque de flujo ajeno se hace sin pagar
  los 92 ms/slot de `C-NET-31` (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:2987-2988`). ∎
- **Lo que esto NO dice, y la auditoría ya lo avisó:** el rechazo sigue costando **recomputar cadena
  y flujo** del sub-DAG ajeno, que es una superficie de DoS abierta
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:116`).
  R-FIN-5 ahorra AES, no ahorra GHOSTDAG.

**Encaje con el orden de validación de `C-POT-08` — propuesto.** `C-POT-08` fija cinco pasos
(**verificado en fuente:** `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:289-296`). Esta
propuesta inserta **un paso, y no toca ninguno de los cinco**:

| Paso | Comprobación | Coste | Estado si falla |
|---|---|---|---|
| 1 | Estructural sin AES: decode acotado, `slot(B) ≥ slot(sp(B))`, `pot_bundle_count` (C-POT-08 paso 1) | O(1) | `Inválido` |
| **1b** | **Flujo (C-FLU-14).** Derivar `flujo(B, ·)` del pasado validado (C-FLU-10) y comprobar la igualdad con la de cada `X ∈ past(B)`. **Sin AES.** | orden GHOSTDAG sobre `V_j` + hashes | **`Inválido`** si discrepa; **`Pendiente`** si falta pasado |
| 2 | Cabecera y sello (C-POT-08 paso 2) | µs | `Inválido` |
| 3 | Caché por clave `(f, s, semilla(f,s), N(s))` (C-POT-07) | ~memcmp 128 B | `Inválido` / `Pendiente` |
| 4 | AES secuencial del rango (C-POT-08 paso 4) | 92 ms/slot | `Inválido` / `Pendiente` |
| 5 | Solución PoAS contra el reto del flujo (C-POT-08 paso 5) | — | según §7.1 |

- **Propuesto — por qué 1b va donde va, y no más tarde.** La clave de caché de `C-POT-07` **empieza
  por `f`** (`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:238-241`): sin el flujo
  resuelto no hay clave que consultar. 1b es, literalmente, el productor de la primera componente de
  esa clave. Y `C-POT-06` exige que el flujo lo aporte **el contexto**, nunca el candidato
  (`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:209-216`): C-FLU-10 y C-FLU-11 son quien
  cumple esa exigencia.
- **Propuesto — `Pendiente` y no `Inválido` cuando falta pasado.** Si el nodo no tiene todo
  `past(B)`, no puede derivar el flujo: el estado es `Pendiente` por contexto incompleto, **nunca**
  `Inválido`. Es la misma disciplina de `C-POT-06`/`C-POT-07` («validez ≠ recursos/estado interno»,
  `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:250-253`) y el mismo motivo por el que
  C-HDR-07 obliga a «distinguir datos pendientes de pruebas verificadas como inválidas»
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:908-909`).
- **Propuesto — el paso 1b necesita presupuesto, y desde la revisión 6 son DOS cotas.** Por el aviso
  de la auditoría sobre el coste de rechazar, el trabajo de 1b **MUST** estar acotado **por par**
  (`C-NET-32.3`, **verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:3005-3006`) **y también
  globalmente por nodo e intervalo** — porque las identidades son gratis y `N` pares dan `N`
  presupuestos. Agotar cualquiera de las dos **MUST** dar `Pendiente`, nunca `Inválido`. La regla
  completa, con su modo de fallo, es **C-FLU-23** (D-F10 = B). Los valores no se fijan aquí: van
  como símbolos.

### C-FLU-20 · Qué hace el productor con un bloque tardío que cambiaría su ancla — propuesto (revisión 4)

**El problema, que hasta la revisión 4 no estaba escrito.** Un bloque retenido `W` con
`slot(W) < T_j + L_slots` puede, al fusionarse, cambiar `I_j` (A2 de §0.4). Si el productor lo
fusiona en un bloque cuyo pasado ya contiene un bloque de `slot ≥ t_j`, **el bloque que produce es
inválido por C-FLU-14** — y lo descubre después de construirlo. C-GD-10 ya tiene el patrón para esto
y hay que extenderlo.

```text
Al construir un bloque B, el productor MUST descartar de su cola de candidatos
(C-GD-10) toda punta cuya inclusión cambiaría entropía_j o t_j de ALGUNA época j
ya activada en el pasado de B —es decir, con t_j ≤ slot(X) para algún X ∈ past(B)—.

Un productor NO PUEDE emitir un bloque inválido por una elección de padres que él
mismo controla.
```

- **Propuesto — es la misma autoridad y la misma forma que C-GD-10 usa para C-GD-11**
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1727-1729`), y por tanto **política de
  producción**, no verificación: un verificador no rechaza por el conjunto de padres, rechaza por
  C-FLU-14, que es validez objetiva. Con C-FLU-02 y C-FLU-20 la enumeración cerrada de C-GD-10
  (`:1731-1733`) pasa a ser **C-GD-04, C-GD-11, C-HDR-05, C-FLU-02 y C-FLU-14**.
- **Demostrado — el bloque tardío queda INFUSIONABLE PARA SIEMPRE en ese flujo, y hay que decirlo
  así.** Por A1, todo bloque válido cuyo pasado contenga un bloque de `slot ≥ t_j` tiene la
  inyección `j` fijada. Como el pasado solo crece, ningún descendiente futuro podrá fusionar `W` si
  hacerlo cambiaría `I_j`. **No hay caducidad ni ventana de rescate:** en el flujo `f` ese bloque y
  todo su subárbol quedan huérfanos de forma permanente. Es coherente con C-FLU-15 (lo producido
  fuera del flujo seleccionado queda sin valor económico), pero **es una consecuencia nueva y más
  fuerte**: no es que no cobre, es que **no se puede referenciar nunca**. ∎
- **Quién paga.** Normalmente el atacante, que es quien retiene. **Colateral honesto no medido:** un
  bloque honesto muy retrasado solo queda atrapado si encabeza una rama que desplazaría el ancla,
  lo que un bloque suelto no consigue; pero **no está medido** con qué frecuencia ocurre, y en el
  régimen candidato `τ ≈ 0,1-0,17 s` habría muchos más bloques en el corte.
- **⚠️ Y la trampa que esta regla NO debe cruzar.** Sería tentador extender la política al intervalo
  **anterior** a `t_j` («no fusiones nada que cambie mi ancla candidata»). **MUST NOT hacerse.**
  Antes de `t_j` fusionar es legal, así que la política no se apoyaría en ninguna invalidez: sería
  un «lo primero que vi manda», y **haría el flujo dependiente del orden de llegada de los
  mensajes** — exactamente el defecto que la ronda 10a tuvo que retirar, «la regla (h.3)
  «continuidad por defecto» … hacía `flujo` depender de cuándo llega un mensaje y **rompía
  R-FIN-5**», sustituida por (h.3′) validez incondicional (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden-auditoria-9a.md:18-21, 50-52`).
  **C-FLU-20 solo actúa donde la invalidez es objetiva: después de la activación.** Antes de `t_j`
  no hay regla que valga; hay carrera (A2).

### C-FLU-21 · La inyección ya activada se hereda, no se recalcula — propuesto; **D-F8 = C DECIDIDA por Katana (2026-09-20)**

> **DECIDIDO: NO se congela la vista** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-3.md:10`). `C-FLU-03`
> queda **como está** y esta regla pasa de alternativa a **regla propuesta firme**.
>
> **Por qué congelar reabre E1, escrito para que no se vuelva a proponer sin verlo.** La opción era
> definir `G_j(B)` := el primer bloque de la **cadena seleccionada de `B`** con
> `slot ≥ T_j + L_slots`, y `V_j(B) := past(G_j(B)) ∩ {slot < T_j + L_slots}`. Gana que `past(G)` es
> inmutable y la vista deja de crecer. **Pero determinar `G` exige conocer la cadena seleccionada de
> `B` hasta `slot(G) ∈ [T_j + L_slots, T_j + L_slots + S_max_slots)`, y por tanto la validez —y el
> flujo— de bloques que pueden tener `slot ≥ t_j`, porque `t_j < T_j + L_slots + S_max_slots`.** Es
> decir: **para decidir la inyección `j` haría falta la inyección `j`**, en una franja de anchura
> `≤ S_max_slots`. Es E1 otra vez —«el ancla depende de la cadena, la cadena de la validez, la
> validez del ancla», `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:83`—, más
> estrecha pero de la misma clase. **No encontré dónde colocar la puerta sin esa franja:** por
> debajo de `T_j + L_slots` no cubre la ventana; por encima entra en territorio de `t_j`.
>
> **Y compraba poco:** adelantar la congelación en `≤ S_max_slots` slots (150 nominales) sobre una
> carrera que dura `L_slots ≥ F_slots` (7 200 nominales). Ese era el intercambio, y la decisión es
> no hacerlo.

```text
Si past(B) contiene algún bloque X con t_j ≤ slot(X), entonces la inyección j de B
(su entropía_j y su t_j) es la de X y NO se recalcula a partir de V_j(B).
Solo se calcula I_j con C-FLU-04 cuando ningún bloque del pasado la tiene activada.
```

- **Demostrado equivalente a C-FLU-14 en lo que decide, y distinto en lo que cuesta.** Por A1, todo
  bloque válido cumple ya esta igualdad; C-FLU-21 no cambia qué bloques son válidos. Lo que cambia
  es que **la vuelve constructiva**: el verificador deja de recalcular `Chn(V_j(B))` para cada
  bloque y la hereda, y el productor sabe qué comprobar sin construir el bloque primero. ∎
- **Propuesto — por qué conviene escribirla aunque sea redundante.** Sin ella, dos implementaciones
  pueden calcular la misma cosa por caminos distintos —una recalculando la vista, otra heredando— y
  discrepar en un borde que nadie ha enumerado. Con ella, **el ancla se calcula una vez por época y
  se transporta**, que es además lo que abarata el paso 1b de §7.
- **Lo que NO arregla:** nada de A2. La herencia empieza en el primer bloque de `slot ≥ t_j`; qué
  ancla trae ese bloque es el resultado de la carrera. Es la alternativa barata a congelar la vista
  (D-F8), no un sustituto.

---

## 8 · La declaración DF-3/DF-4

### C-FLU-15 · Una partición de flujo tiene el estatuto de un fallo de finalidad — propuesto

**Declaración (DF-3/DF-4, Katana 2026-09-19; perfil 1a reconfirmado el 2026-09-20).** Una partición
de flujo **se trata como** una violación de finalidad: es un fallo del modelo de seguridad, no un
estado que el protocolo gestione. **No se añade ninguna regla de adopción entre flujos** (DF-2). No
se legisla el nodo recién llegado ni la producción en un flujo no seleccionado más allá de esta
declaración.

> **⛔ CORREGIDO en la revisión 5 — D-F9 = C sustituye a DF-2.** Las revisiones 1-4 decían aquí que
> una partición **no tiene cura en el protocolo**. Eso era consecuencia de DF-2, y DF-2 se apoyaba
> en la conclusión (c) de §0.2, que resultó **falsa**. Con **C-FLU-22** la frase correcta es más
> fina, y hay que decirla entera porque es fácil leerla de más:
>
> - **El nacimiento espontáneo (latencia, vía A2) SÍ se cura**, por adopción dentro de la ventana
>   `[t_j, slot(P) + F_slots)`, con las dos rendijas que PCO-v0.1 mide (desfase de vista
>   0,27-1,5 %; el que sincroniza después).
> - **El nacimiento realista —un corte de red más largo que `L`— NO se cura.** Ahí la ventana es
>   **vacía** desde el propio `t_j`, y la partición es permanente.
> - Es decir: **el diseño cura el caso improbable y no cura el grave.** Sigue siendo, sobre todo,
>   **prevención** —`L` frente a `Δ`, con el suelo de C-FLU-01—; la recuperación es un añadido real
>   pero acotado, no una garantía de reconciliación.
>
> **Ningún texto derivado de esta propuesta debe decir «las particiones se curan», ni tampoco «no
> tienen cura».** Las dos son falsas: depende de cómo nació.

- **Verificado en fuente:** DF-2, DF-3 y DF-4 en `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:71-77`.
- **Corrección obligatoria de la letra, por §0.3.** La declaración es una **equiparación de
  estatuto**, no una **equivalencia causal**. Escribirla como «una partición de flujo **es** una
  violación de finalidad» sería falso: §0.3 exhibe una partición sin ninguna violación de R-FIN-7.
  Lo que sí es cierto y demostrado (§0.4, P3): **si la partición nace, la finalidad es lo que impide
  curarla.** El traslado al SPEC debe usar la forma «se trata como», no «es».
- **Demostrado (P3):** bajo 1a + DF-2 la partición es permanente. Sanarla exige una reorganización
  de profundidad `≥ L_slots + 1 > F_slots` (Lema 2), que R-FIN-7 prohíbe. Además la red **no**
  converge al flujo más pesado: la punta rival, aunque pese más, se ignora
  (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:301-303`). ∎
- **DF-4, con su fundamento citado y su límite. Cita corregida y archivo abierto (revisión 2).**
  Producir en un flujo no seleccionado **no se puede prohibir criptográficamente**. El archivo no es
  `research/balizas-auditoria.md` —**ese nombre no existe en el repositorio**, la abreviatura venía
  de `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:59`— sino
  `/home/katana/zeo/ZEROX/research/dag-poas-balizas-auditoria.md`, **ahora abierto**. El teorema
  está en sus líneas 68-75 y dice más de lo que la abreviatura sugería
  (**verificado en fuente**, `:69-71`): «cualquier mecanismo de exclusividad entre relojes en PoAS
  permisionless es derrotable por partición de identidad, porque el coste de producir espacio es
  lineal en bytes e independiente de cuántas identidades lo reclamen, y **las identidades son gratis
  por diseño**». Y añade la razón estructural (`:72-75`): un sector plotado sí se puede subdividir
  en dos loterías al mismo coste marginal, «mientras nada ate el sector a un reloj concreto en el
  momento de crearlo — y atarlo exige que el reloj exista *antes* de plotear, que es circular con el
  problema que se quiere resolver». **Esto es más fuerte que «no se puede prohibir»: dice que
  ninguna regla de exclusividad entre flujos puede funcionar en este modelo**, lo que confirma DF-4
  como declaración y no como laguna. Lo que sí se puede es dejar sin valor económico lo producido en
  el flujo perdedor, y eso ya lo hace C-FLU-14 sin regla nueva: esos bloques no son referenciables
  desde el flujo ganador, luego su coinbase nunca entra en la historia seleccionada.
- **Qué implica para el nodo que sincroniza desde cero — y aquí la declaración no alcanza.** Un
  nodo sin cadena previa **no tiene ninguna reorganización que prohibirse**: R-FIN-7 acota cambios
  de *su* cadena seleccionada y él no tiene ninguna. La declaración «se trata como violación de
  finalidad» **no le da ninguna regla**. Los mecanismos que el SPEC ya tiene, sin inventar otros:
  - **C-CHK-01…C-CHK-07** (checkpoint firmado): fija la rama canónica y toda cadena que no lo
    contenga es inválida (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:2000-2002`).
    **Pero no sirve para esto:** hay **un único** checkpoint en la vida de la cadena
    (`/home/katana/zeo/ZEROX/SPEC.md:1987-1988`) y su autorización **caduca** en
    `ALTURA_CADUCIDAD` (`/home/katana/zeo/ZEROX/SPEC.md:1997-1998`). Cubre el periodo frágil de
    lanzamiento, no una partición posterior.
  - **C-REORG-06** (las ventanas se leen sobre la cadena candidata,
    `/home/katana/zeo/ZEROX/SPEC.md:1886-1889`): es correcto y necesario, pero no elige entre flujos.
  - **El hueco, y por qué había que cerrarlo aunque no se añada mecanismo.** `P-2.1` lo identifica
    como uno de los «dos huecos de redacción que dominan el resultado»: «qué hace un nodo **sin
    cadena previa** ante dos flujos … Cerrar cualquiera de los dos apaga el canal dominante»
    (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:41-43`), y mide su efecto:
    «el que sincroniza después: toma el líder del momento; con deriva nula discrepa de los veteranos
    con probabilidad → 1 mientras el flujo perdedor siga vivo»
    (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:35-36`). **D-F5 se cierra
    con C-FLU-18, que no inventa mecanismo: escribe lo que ya se sigue de las reglas vigentes.**

### C-FLU-22 · Adopción del flujo rival dentro de la ventana, con presupuesto — propuesto; **D-F9 = C DECIDIDA por Katana (2026-09-20)**

**Sustituye a DF-2.** DF-2 («no se añade ninguna regla de adopción») se decidió sobre la conclusión
(c) de §0.2, que era **falsa**. Katana decide la opción C
(`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-3.md:11`): **se permite adoptar, dentro de la ventana y con
presupuesto.**

```text
Adoptar = seleccionar. Una rama de otro flujo es VÁLIDA en términos absolutos
(C-FLU-13): NO se puede FUSIONAR (C-FLU-14) pero SÍ se puede SELECCIONAR.

Un nodo MUST elegir entre ramas válidas por la selección ordinaria de GHOSTDAG
(mayor blue_work; desempates de C-GD-03), sin excepción por flujo, LIMITADA por
C-FIN-01: solo mientras la profundidad de la reorganización sea < F_slots.

d(t) := slot(punta seleccionada actual) − slot(P),
        con P el ÚLTIMO ANCESTRO COMÚN de la cadena actual y la rama candidata.
```

#### 1 · Desde qué punto se mide, y cuánto mide la ventana — demostrado

- **El punto es `P`, el último ancestro común**, y la profundidad se cuenta en **índices de slot**
  (C-FLU-01) desde la **punta propia**, no desde la candidata: lo que la finalidad protege es lo que
  el nodo **descarta**.
- **Demostrado.** C-FIN-01 prohíbe `d ≥ F_slots`, luego se adopta mientras
  `slot(punta) < slot(P) + F_slots`. Por **(c′)** de §0.2, dos ramas con inyecciones `j` distintas no
  comparten ningún ancestro con `slot ≥ t_j`, luego `slot(P) ≤ t_j − 1`. Y para que haya dos flujos
  la punta propia ya tiene `slot ≥ t_j`. Por tanto:

  ```text
  ventana = [ t_j , slot(P) + F_slots )        no vacía  ⟺  slot(P) > t_j − F_slots
  anchura máxima = F_slots − 1 slots           (se alcanza con slot(P) = t_j − 1)
  ```
  ∎
- **La anchura depende de cómo nació la partición, y eso une el punto 6 con el 1:**

  | Nacimiento | `slot(P)` | Ventana |
  |---|---|---|
  | **Espontáneo** (latencia; vía A2 de §0.4) | `t_j − 1` | **máxima**, `F_slots − 1` |
  | Corte de red que empezó en `s₀` | `s₀` | `[t_j, s₀ + F_slots)` |
  | **Corte de red más largo que `L`** | `s₀ ≤ t_j − L_slots ≤ t_j − F_slots` | **VACÍA** |

#### 2 · La congelación es simultánea — demostrado, y con su riesgo residual citado

- **Demostrado.** El instante de cierre es `slot(P) + F_slots`, **función exclusiva de `P`**: no
  depende de cuándo cada nodo se enteró de la rama rival, ni de su reloj local, ni del orden de
  llegada. Todos los nodos **con cadena** cruzan el umbral **en el mismo índice de slot**. ∎ Es la
  forma exacta del «R-FIN-7 congela a **todos** los nodos a la vez en `t_j + F`» de
  `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:30-31`.
- **Riesgo residual — resultado de `P-PUERTA/veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1,
  validado), con su alcance.** Aun con congelación simultánea quedan **dos rendijas**
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:29-36`):
  - **desfase de vista** en ese instante: `arcsin(√(τ/F))/π` → **0,27 %** (`F = 2 h`, `τ = 0,5 s`),
    **0,75 %** (`τ = 4 s`), **1,5 %** (`τ = 16 s`). **Alcance declarado en la fuente:**
    *condicionado a que la partición haya nacido* y a *reparto simétrico*; va como `√(τ/F)`, así que
    **cuadruplicar `F` solo la divide por dos**.
  - **el que sincroniza después:** «toma el líder del momento; con deriva nula discrepa de los
    veteranos con probabilidad → 1 mientras el flujo perdedor siga vivo». Ese canal **no lo cierra
    C-FLU-22**: lo gobiernan **C-FLU-18** (el nodo sin cadena aplica la selección ordinaria, y la
    finalidad no le obliga porque no tiene nada que reorganizar) y **C-FLU-17** (se entera y lo
    señala). La adopción resuelve entre **veteranos**; el recién llegado sigue como estaba.

#### 3 · Orden y coste — propuesto

1. **La comprobación estructural va SIEMPRE primero** (paso 1b de §7): derivar el flujo de la rama
   candidata y su `blue_work`. **Sin AES.**
2. **El PoT del flujo rival se verifica SOLO si hace falta para adoptar**, es decir solo si la rama
   rival **va por delante** en `blue_work` y `d < F_slots`. Si no va por delante, o está fuera de la
   ventana, **no se verifica nada**: la punta se ignora (C-FIN-01).
3. **Bajo presupuesto por par e intervalo** (C-NET-32.3, **verificado en fuente:**
   `/home/katana/zeo/ZEROX/SPEC.md:3005-3006`). **Agotarlo da `Pendiente`, nunca `Inválido`**
   (C-POT-07, `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:250-253`).
4. **Sin validez comprobada no se adopta.** `Pendiente` **MUST NOT** contar como válido ni como
   inválido: el nodo se queda donde está y reintenta cuando tenga presupuesto.

#### 4 · R-FIN-5 cambia de motivo — la frase exacta

> **Antes:** «un nodo honesto **jamás** verifica el PoT de un flujo ajeno»
> (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:225`). **Deja de ser cierta a la
> letra.**
>
> **Ahora:** un nodo honesto **nunca verifica el PoT de un flujo ajeno para FUSIONAR** —la
> comprobación de C-FLU-14 es estructural y no toca AES, y eso no cambia—; **solo lo verifica para
> ADOPTAR, dentro de la ventana de C-FLU-22 y bajo presupuesto.**

La virtud que se conserva es la que importaba: **el camino normal —validar y fusionar bloques del
propio flujo— nunca paga AES ajeno**, y el rechazo de un bloque de flujo ajeno sigue siendo
estructural (§7, paso 1b).

#### 5 · El DoS de verificación — DEMOSTRADO, no supuesto, y con tres avisos

**Afirmación a comprobar** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-3.md:30-33`): forzar gasto de AES
ajeno exige la misma rama privada más pesada dentro del corte que la vía A2.

> **Demostrado.** Para que un nodo gaste AES en un flujo ajeno tienen que darse a la vez: **(i)** la
> rama es de otro flujo, **(ii)** va por delante en `blue_work`, **(iii)** `d < F_slots`.
>
> De **(i)**, las anclas de la época `j` difieren, y hay solo dos formas:
>
> - **(a) añadir**: la rama rival contiene bloques con `slot < T_j + L_slots` que el nodo no tiene y
>   que **desplazan el primer cruce de `T_j`** en `Chn(V_j)`. Por el Lema 1, esos bloques encabezan
>   una rama que bifurca por debajo de `T_j` y que debe pesar **más que la honesta dentro del
>   corte**. **Es exactamente A2.**
> - **(b) omitir**: la rama rival **no contiene** el ancla honesta. Como el pasado es cerrado por
>   ancestros (C-FLU-02), omitirla exige bifurcar por debajo de ella, luego
>   `slot(P) < T_j + S_max_slots`, y en particular `slot(P) < T_j + L_slots`. Con **(iii)**,
>   `slot(punta) < slot(P) + F_slots < T_j + L_slots + F_slots`… y más finamente, si se omite el
>   cruce hay que bifurcar por debajo de `T_j`, luego `slot(P) < T_j` y
>   `slot(punta) < T_j + F_slots ≤ T_j + L_slots ≤ t_j`. Pero **(i)** exige que la inyección `j` esté
>   activada en la cadena propia, es decir `slot(punta) ≥ t_j`. **Contradicción: (b) es imposible
>   dentro de la ventana.** ∎
>
> **Luego solo queda (a), que es A2.** El coste de forzar AES ajeno es el de ganar una carrera de
> `blue_work` de longitud `L` — umbral `α = 1/2` (CRP-v0.1,
> `/home/katana/zeo/ZEROX/TAREAS.md:129-134`), cola **no medida**. **No encontré ninguna vía más
> barata.**
>
> **Y esto es algo que el perfil 1a SÍ compra, y no lo había dicho:** el paso (b) se cierra usando
> `L_slots ≥ F_slots`. Con `L < F` la rama (b) **cabría** dentro de la ventana y habría una vía
> barata de forzar AES ajeno. **Es un argumento nuevo a favor de 1a**, independiente de los de
> `P-2.1`.

**Aviso 1 — lo que NO cubre la demostración: el DoS que queda es el paso 1b, no el AES.** Rechazar
un sub-DAG de flujo ajeno sigue costando **recomputar cadena y flujo**
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:116`).
Eso es barato por bloque pero no es gratis, y **no depende de ganar ninguna carrera**. Por eso el
paso 1b lleva su propio presupuesto (§7).

**Aviso 2 — HALLAZGO NUEVO: el presupuesto es POR PAR y las identidades son gratis.**
C-NET-32.3 acota el gasto «por par y por intervalo» (`/home/katana/zeo/ZEROX/SPEC.md:3005`), y el
repositorio tiene demostrado que **las identidades son gratis por diseño**
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-balizas-auditoria.md:68-75`).
Un atacante que abra `N` conexiones obtiene `N` presupuestos. **Esto no abarata el disparo** —sigue
haciendo falta (a)— **pero sí multiplica por `N` el trabajo del paso 1b y el techo de AES una vez
disparado.** El presupuesto debería estar acotado **también globalmente por nodo**, no solo por par.
**Va como D-F10; no lo decido yo.**

**Aviso 3 — el peor caso, aunque sea improbable, es grande.** Si la carrera llega a ganarse, la rama
rival puede abarcar hasta `F_slots` slots, y verificar su PoT cuesta hasta
`F_slots × 92 ms` ≈ **11 minutos de CPU** con los valores nominales (92 ms/slot en AVX-512/VAES,
**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:2987-2988`). **Probabilidad ínfima,
consecuencia grande:** el presupuesto tiene que ser una cota dura, no una recomendación.

#### 6 · Lo que la adopción NO cura — y hay que leerlo antes que el resto

> **Esta regla NO hace que «las particiones se curen».** El nacimiento **realista** de una partición
> es un **corte de red más largo que `L`**: ahí las cadenas divergen **antes** de `t_j`, la
> profundidad ya supera `F_slots` en el propio instante de activación y **la ventana es vacía**
> (tabla del punto 1). **No hay adopción posible y la partición es permanente.**
>
> Lo que C-FLU-22 cura es el nacimiento **espontáneo** —por latencia, la vía A2—, que es
> precisamente **el improbable**. Es una mejora real y acotada: convierte el caso raro en
> recuperable; **no convierte el caso grave en recuperable.**

#### 7 · El presupuesto lleva dos cotas — véase **C-FLU-23**

El punto 3 de arriba dice «bajo presupuesto». **Desde la revisión 6 ese presupuesto son dos cotas,
no una** (D-F10 = B, decidida por Katana el 2026-09-20): la de C-NET-32.3 por par, y una **cota
global por nodo e intervalo**. Está escrita aparte porque gobierna también el paso 1b de §7.

#### 8 · C-FLU-20 no se extiende

C-FLU-20 sigue actuando **solo después de `t_j`**, donde la invalidez es objetiva. Extenderla al
periodo anterior reintroduciría la dependencia del orden de llegada de la regla (h.3) retirada en la
ronda 10a (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden-auditoria-9a.md:18-21, 50-52`).
**Sin cambios.**

### C-FLU-23 · Presupuesto de verificación de flujo ajeno: dos cotas, y qué pasa al agotarlas — propuesto; **D-F10 = B DECIDIDA por Katana (2026-09-20)**

```text
El trabajo que un nodo dedica a ramas de OTRO flujo —el paso 1b estructural de §7 y
la verificación de PoT de C-FLU-22— MUST estar acotado por DOS presupuestos a la vez:

  PRESUP_PAR    por par y por intervalo    (C-NET-32.3, ya existente)
  PRESUP_NODO   por NODO y por intervalo   (nuevo; SÍMBOLO, sin valor aquí)

Agotar CUALQUIERA de los dos produce Pendiente, NUNCA Inválido. Con Pendiente el nodo:
  · MUST conservar su cadena seleccionada actual — no adopta;
  · MUST NOT tratar la rama como inválida;
  · MUST NOT dejar de reenviarla por este motivo;
  · MUST reintentar cuando vuelva a tener presupuesto, mientras la ventana siga abierta.
```

- **Por qué hacía falta la segunda cota.** C-NET-32.3 acota «por par y por intervalo»
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:3005-3006`) y el repositorio tiene
  **demostrado** que **las identidades son gratis por diseño** (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/research/dag-poas-balizas-auditoria.md:68-75`). Un atacante con `N`
  conexiones obtiene `N` presupuestos, así que el techo de trabajo por nodo lo fija él. Con
  `PRESUP_NODO` el techo **deja de depender de `N`**, que es el criterio declarado de C-NET-06 —el
  coste por salto acotado **por construcción** (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/SPEC.md:2530-2531`).
- **Lo que esto NO arregla, para no exagerar el hallazgo:** no abarata ni encarece el **disparo** de
  AES ajeno, que sigue exigiendo ganar la carrera A2 (C-FLU-22 §5, demostrado). Lo que acota es el
  **techo**: el trabajo del paso 1b, que no depende de ganar nada, y el AES una vez disparado.
- **El modo de fallo, escrito porque bajo C-FLU-22 «no adoptar» ya NO es neutro.** Antes de D-F9 un
  nodo sin presupuesto simplemente retenía. Ahora, quedarse sin presupuesto durante la ventana
  significa **quedarse en el flujo en el que está** — y cuando la ventana se cierra
  (`slot(P) + F_slots`, C-FLU-22 §1), quedarse ahí **para siempre**. De ahí las cuatro obligaciones
  del bloque: `Pendiente` y reintento, nunca `Inválido`, y **seguir reenviando**, para que un nodo
  sin presupuesto no se convierta además en un amplificador de la partición cortando la propagación
  a sus pares.
- **⚠️ Y hay que decir la consecuencia que esto tiene, porque es una rendija nueva.** `P-2.1`
  enumera dos rendijas al congelar: el desfase de vista `arcsin(√(τ/F))/π` y el nodo que sincroniza
  después (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:31-36`).
  **El presupuesto añade una tercera:** dos nodos con el mismo DAG pueden acabar en flujos distintos
  porque uno pudo pagar la verificación dentro de la ventana y el otro no. **Es local,
  y a diferencia de las otras dos está parcialmente bajo control del atacante**, que puede gastar el
  presupuesto ajeno con tráfico barato del paso 1b. La validez no se mueve —sigue siendo función de
  `past(B)`—; lo que se mueve es la **selección**, que bajo C-FLU-22 decide el flujo. **Esta
  rendija no está medida**, y va a «Lo que esta propuesta NO resuelve».
- **`PRESUP_NODO` va como símbolo** (encargo §6; el propio valor de C-NET-32.3 es un `<<PENDIENTE>>`
  declarado, **verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:3007-3009`). **Criterio de
  calibración, propuesto, con las dos direcciones de la pinza:**
  1. **Cota inferior — si es demasiado pequeño, deroga D-F9 en la práctica.** Integrado sobre la
     ventana de C-FLU-22, `PRESUP_NODO` **MUST** bastar para verificar **una** rama rival completa,
     que en el peor caso abarca `F_slots` slots ≈ `F_slots × 92 ms` ≈ **11 min de CPU** con los
     valores nominales (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:2987-2988`). Con
     menos, la adopción **nunca** se completa y la decisión D-F9 quedaría anulada sin que nadie la
     revocara.
  2. **Cota superior — si es demasiado grande, devuelve el DoS** que la segunda cota existe para
     acotar.
  **Esa pinza es la calibración, y no es mía.** Va con el resto de los símbolos abiertos.
- **Dónde vive esta regla en el SPEC, aplicando el criterio que Katana ya fijó en D-F7.** Esto **no
  es una regla de flujo**: es una **enmienda a C-NET-32.3**, de la capa de red. Por el mismo
  criterio con el que la regla de finalidad salió de `C-FLU` a `C-FIN`, el traslado debería
  escribirla como **`C-NET-33`** (o como un tercer punto de C-NET-32), no como `C-FLU-23`. Uso
  `C-FLU-23` solo por comodidad de este documento y **lo señalo para que el traslado lo corrija**;
  no abro decisión, porque el criterio ya está decidido.

### C-FLU-18 · El nodo sin cadena previa aplica la selección ordinaria — propuesto; **D-F5 DECIDIDA por Katana (2026-09-20)**

```text
Un nodo sin cadena previa selecciona la rama de mayor blue_work, por las reglas
C-GD vigentes, sin excepción por flujo.

La regla de finalidad (C-FIN-01) obliga ÚNICAMENTE a quien ya tiene una cadena
seleccionada que reorganizar. No impone nada a quien no tiene ninguna.
```

- **Esto no es un mecanismo nuevo: es cerrar un hueco de redacción**
  (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:12`). Sin escribirlo, dos clientes pueden
  implementarlo distinto, y eso es exactamente la clase de fork latente que el Nivel 1 de `TAREAS.md`
  persigue. **Demostrado — ya se sigue de las reglas vigentes:** C-FIN-01 está enunciada sobre «su
  cadena seleccionada»; un nodo que no tiene ninguna no puede violarla, porque no hay reorganización
  que prohibir. Y la selección ordinaria es la de §11 (C-GD-03 para la punta virtual, **verificado
  en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1682-1685`), que no conoce los flujos: solo
  `blue_work`, `solution_distance` e `id`. ∎ Lo único que aporta C-FLU-18 es **decirlo**.
- **Alcance, con las tres cosas que lo acotan y una que no.**
  1. **Caso realista (una minoría aislada):** el recién llegado cae en el lado **mayoritario**,
     porque es el de mayor `blue_work` — que es el mismo criterio que los veteranos del lado
     mayoritario ya aplican. El desacuerdo solo aparece frente a los veteranos del lado
     **minoritario**, que son los que C-FLU-17 hace que se enteren.
  2. **Largo alcance:** está acotado por la **secuencialidad del PoT**. Fabricar una historia
     alternativa exige evaluar la cadena AES slot a slot; es la propiedad que C-POT-03 eleva a
     prohibición explícita —ningún reto puede derivarse de una función que permita saltarse slots—
     (**verificado en fuente:**
     `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:98-103`) y cuyo origen es
     R-FIN-14(e) (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:272-275`).
  3. **En el arranque:** los checkpoints **C-CHK-01…C-CHK-07** ya fijan la rama canónica y hacen
     inválida toda cadena que no los contenga (**verificado en fuente:**
     `/home/katana/zeo/ZEROX/SPEC.md:2000-2002`). **Se citan, no se amplían**
     (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:12`): siguen siendo **uno solo** en la vida de la
     cadena (`:1987-1988`) y **caducan** en `ALTURA_CADUCIDAD` (`:1997-1998`).
  4. **Lo que NO acota:** después de `ALTURA_CADUCIDAD`, durante una partición viva, un nodo nuevo
     sigue yendo al flujo más pesado **del momento**. Si el flujo minoritario es el más pesado en
     ese instante, el nodo nuevo entra en él. **C-FLU-18 hace la conducta determinista y única; no
     la hace acertada.** Eso sigue en «Lo que esta propuesta NO resuelve».
- **Y no reabre DF-2.** C-FLU-18 habla de un nodo **sin cadena**; un nodo **con** cadena sigue
  atado por C-FIN-01 y no puede cruzar de flujo (§0.2). No hay adopción por esta vía.

### C-FLU-17 · El nodo detecta que ha quedado fuera del flujo mayoritario y lo señala — propuesto; **comportamiento de nodo, NO validez de bloque**

> **Esto no es una regla de consenso.** No cambia la validez de ningún bloque, no cambia la
> selección de cadena y **no es una regla de adopción** (DF-2 sigue intacta: el nodo **MUST NOT**
> cambiar de flujo por este indicador). Es la regla operativa mínima que pide
> `/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:35-37`: que un nodo no siga funcionando **en
> silencio** dentro de un flujo minoritario.

**Condición detectable, y es objetiva.** Un nodo **MUST** señalar el estado «flujo posiblemente
minoritario» cuando, de forma sostenida, se cumpla:

```text
existe una punta P conocida, con flujo(P, slot(P)) ≠ flujo(mi punta, slot(mi punta)),
tal que blue_work(P) > blue_work(mi punta seleccionada)
y que la regla de finalidad me obliga a ignorar (profundidad ≥ L_slots + 1, Lema 2)
```

- **Demostrado — es computable con lo que el nodo ya calcula, y sin AES.** El flujo de `P` sale del
  paso 1b de C-FLU-14 (estructural, sin AES); `blue_work` es lo que GHOSTDAG ya produce (C-GD-01/02,
  **verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1669-1681`); y que la punta sea de otro
  flujo implica, por el Lema 1, bifurcación con `slot < T_j`, luego profundidad `≥ L_slots + 1` en
  `t_j` o después. **No hace falta verificar el PoT del flujo ajeno** (C-FLU-14), así que la virtud
  de R-FIN-5 se conserva. ∎
- **Propuesto — «de forma sostenida», y por qué no basta un instante.** Una punta rival más pesada
  puede ser transitoria o fabricada. La señal **MUST** exigir persistencia durante una ventana, y
  **MUST NOT** dispararse con una sola observación. `<<PENDIENTE: la ventana de persistencia y el
  margen de `blue_work`>>` — no lo fijo aquí: es calibración, y ninguna implementación puede
  fijarlo por su cuenta (§0.3 del SPEC).
- **Propuesto — coste y presupuesto.** Calcular `blue_work` de una punta ajena cuesta recomputar
  cadena y flujo de su sub-DAG, que es la superficie de DoS que la auditoría señaló
  (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:116`). Ese trabajo **MUST** caer
  dentro del mismo presupuesto por par e intervalo del paso 1b (§7), y agotarlo **MUST** dejar la
  señal como «no determinada», nunca como «estoy en el mayoritario».
- **Propuesto — qué hace el nodo con la señal: nada automático.** La expone (registro, métrica,
  estado consultable) y **para de producir bloques si el operador lo ha configurado así**. Cambiar
  de flujo por su cuenta sería la regla de adopción que DF-2 descarta, y además sería **imposible**
  bajo 1a: la reorganización necesaria está prohibida desde `t_j` (§0.2). **La señal existe
  precisamente porque el protocolo no puede hacer nada más.**
- **Dónde va en el SPEC:** con las reglas de comportamiento de nodo (§14.3 / §16), **no** en §7 ni
  §11. Si se traslada a una sección de consenso, deja de ser lo que es.

---

## 9 · El cambio de `N(s)` coincide con `t_j`

### C-FLU-16 · `N(s)` cambia exactamente en `t_j` — propuesto

Cualquier cambio de `N(s) = slot_iterations` **MUST** aplicarse en el mismo slot `t_j` en que se
aplica la entropía de la inyección `j`, y en ningún otro. Entre dos activaciones, `N(s)` es
constante.

- **Verificado en fuente, evidencia histórica:** R-FIN-9, «Los cambios de `N(s)=slot_iterations` se
  aplican en el mismo `t_j` que la entropía (R-FIN-14)»
  (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:377-379`), y R-FIN-14(a), «con `N(s)`
  el `slot_iterations` vigente (R-FIN-9), aplicado en el mismo `t_j` que la entropía»
  (`:263-264`). El SPEC lo recoge: «Su eventual cambio coincide con la inyección»
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1456`).
- **Propuesto — por qué es una regla y no una coincidencia.** `N(s)` entra en la clave de caché de
  `C-POT-07` (`/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:238-241`). Si `N` pudiera
  cambiar en un slot distinto de `t_j`, existirían dos puntos de discontinuidad por época en vez de
  uno, y la clave tendría que rastrear un calendario propio. Con C-FLU-16 el calendario de `N` es
  **el mismo objeto** que el de las inyecciones, que C-FLU-09 ya demuestra bien ordenado y con a lo
  sumo un cambio por slot.
- **No determinado por el SPEC — y va como símbolo, por encargo.** Quién **autoriza** un cambio de
  `N(s)`, su valor inicial, sus límites y su anuncio siguen pendientes: R-FIN-9 lo dice
  («**Pendiente:** origen de épocas, N inicial, regla que determina/autentica actualizaciones,
  límites y anuncio; esta corrección no los inventa»,
  `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:379-381`), y el SPEC también («su regla
  de actualización y su valor inicial no están definidos. El `ensure_root` del actualizador de
  Autonomys **no se adopta** como autoridad de ZEROX»,
  `/home/katana/zeo/ZEROX/SPEC.md:1456-1458`). `P-POT` fija solo su dominio y la proyección
  `u64 → NonZeroU32` (`C-POT-04`,
  `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:109-125`). **Esta propuesta no inventa la
  autoridad:** fija *cuándo* se aplica el cambio, no *quién* lo decide.

---

## 10 · Los tres bordes del encargo §2, resueltos

### 10.1 · Borde 2 — unidades: en qué magnitud se compara la profundidad

**Resuelto en C-FLU-01: en índices de slot de PoT.** `L_slots` es un número de slots;
`F` está escrita en segundos de slot y entra en la regla como `F_slots = ⌈F/τ_nom⌉`;
`slot(I_j) ∈ [T_j, T_j + S_max_slots)` y la profundidad de una reorganización es
`slot(punta) − slot(último ancestro común)`, una diferencia de enteros. La comparación
`d ≥ L_slots + 1 > F_slots` de §0.2 es, por tanto, entre enteros del mismo dominio.

**Lo que esto cuesta, dicho en voz alta:** `F_slots` depende de `τ_nom`, y `τ_nom = 1 s/slot` es
«perfil de estudio», no una constante cerrada (**verificado en fuente:**
`/home/katana/zeo/ZEROX/SPEC.md:1429-1430`; y `ancla-de-orden.md:317-318` llega a proponer
`τ ≈ 0,1-0,17 s`). Si `τ_nom` cambia, `F_slots` cambia y **`L_slots` cambia con ella por C-FLU-01**:
la atadura de DF-1 absorbe el cambio. Lo que **no** absorbe es una comparación escrita en bloques
(§10.3).

### 10.2 · Borde 1 — el caso `L = F` exacto: cerrado, y sin margen

**Pregunta del encargo:** ¿la finalidad prohíbe reorganizar «por debajo de `F`» con desigualdad
estricta o no? Un caso con profundidad exactamente `F` en el instante de activación, ¿cae dentro o
fuera? ¿Hace falta `L ≥ F + algo`?

> **⛔ RE-ACOTADO en la revisión 4.** Lo que sigue vale **solo** para el mecanismo de nacimiento por
> **latencia** de §0.3 —dos nodos cuyas cadenas seleccionadas pasan por bloques distintos en el
> cruce de `T_j`—, donde el último ancestro común de las **cadenas de los nodos** sí queda por
> debajo de `T_j`. **No vale para el mecanismo por fusión** (§0.4, A2): ahí las dos cadenas pueden
> ser idénticas hasta `t_j − 1` y la profundidad de cruzar es `≈ t − t_j`, no `≥ L+1`. Para ese
> mecanismo el borde relevante **no es `L = F`**: es (c′) de §0.2, y ahí la desigualdad que muerde es
> la de `t_j + F_slots`. La conclusión práctica **no cambia** —con (α) la desigualdad se escribe
> explícita y el caso exacto cae del lado prohibido— pero el alcance de la prueba sí.

**Respuesta: en el mecanismo por latencia no hace falta margen, y la ambigüedad no llega a morder.**
Por el Lema 1, el último ancestro común está **estrictamente** por debajo de `T_j`, luego
`slot(P) ≤ T_j − 1`; por el Lema 2, en `t_j` la profundidad es `d ≥ L_slots + 1`. Con
`L_slots = F_slots` exacto:

```text
d ≥ F_slots + 1 > F_slots
```

El caso «profundidad exactamente `F`» **no se da nunca** en el instante de activación: la
construcción del ancla mete un slot de sobra. Por tanto la prohibición se dispara con **cualquiera**
de las dos lecturas de R-FIN-7 (`d > F_slots` prohibido, o `d ≥ F_slots` prohibido). **demostrado.**

**Aun así, la desigualdad hay que escribirla.** No porque este borde lo necesite, sino porque
R-FIN-7 la usa en otros sitios donde no hay Lema 1 que regale un slot, y hoy «por debajo de `F`» es
**no determinado por el SPEC** (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:301-302`
dice «por debajo de `F` segundos de slot» sin fijar el sentido de la desigualdad).

> **D-F4 = A, DECIDIDA por Katana el 2026-09-20**
> (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:11`): la desigualdad se escribe **explícita**, y son
> **dos**, porque en este diseño hay dos bordes y no uno. Quedan así, para que dos implementaciones
> no puedan discrepar:
>
> ```text
> (α)  Reorganización PROHIBIDA   ⟺   d ≥ F_slots          (C-FIN-01)
>      con d = slot(punta) − slot(último ancestro común), enteros
>
> (β)  Inyección j EN VIGOR       ⟺   s ≥ t_j              (C-FLU-07)
>      el flujo de un slot s lo fija la última inyección con t_j ≤ s;
>      en s = t_j la entropía YA está mezclada — el borde es INCLUSIVO
> ```
>
> **(α) es la lectura conservadora:** profundidad exactamente `F_slots` **cae dentro** de lo
> prohibido. **(β) es inclusivo y coincide con la fuente:** R-FIN-14(a) aplica la re-siembra «si
> `s = t_j`» (**verificado en fuente:**
> `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:261-264`) y R-FIN-2 dice que «antes de
> `t_j` la entropía no se mezcla» (`:213`) — es decir, `[slot(I_j), t_j)` semiabierto por abajo y
> vigor desde `t_j` inclusive. Las dos son las que `P-POT` ya supone en `C-POT-01` («el cambio de
> semilla se aplica exactamente en el slot de inyección»,
> `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:38-44`).
>
> **La demostración del borde se conserva intacta**, y con (α) queda con margen: el punto de
> bifurcación está **estrictamente** por debajo de `T_j` (Lema 1), luego `d ≥ L_slots + 1`, luego
> con `L = F` se cumple `d ≥ F_slots + 1 ≥ F_slots` y (α) prohíbe. Con la lectura descartada
> (`d > F_slots`) también prohibiría: **el Lema 1 regala un slot y el borde nunca llega a morder.**

**Y el margen que sí puede hacer falta es otro.** `L ≥ F` protege contra la **reversión** del ancla;
no protege contra que dos honestos **nunca hayan estado de acuerdo**. Ese margen no se mide en
slots de finalidad sino en `Δ`: `L_mín(10⁻³)` = 119 / 1 198 / 1 682 slots para `Δ` = 4 / 10 / 16 s
(**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:26-28`). Con `F_slots = 7 200`
hay holgura frente a esos números y frente a la extrapolación a `10⁻⁹` (≈360 / ≈3 600 / ≈5 000,
etiquetada `estimado` en la fuente). **Si `F` bajase a 1 h** —y el propio diseño dice que «es
obligación bajarla en producción», **verificado en fuente:**
`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:163`— entonces `L_slots = 3 600`, que ya
está **por debajo** del ≈3 600-5 000 extrapolado para `Δ` = 10-16 s. La atadura de DF-1 es correcta
como regla, pero **no es neutra**: bajar `F` baja `L` y empeora (P2). Va anotado en «Lo que esta
propuesta NO resuelve».

### 10.3 · Borde 3 — de qué regla de finalidad cuelga: NO DETERMINADO, y cambia el resultado

**Las dos reglas existen y dicen cosas distintas.**

| | R-FIN-7 | `C-REORG-07` |
|---|---|---|
| Dónde | `research/dag-poas-ancla-de-orden.md:301-303` (**evidencia histórica**) | `SPEC.md:1891-1903` (**SPEC vivo**) |
| Magnitud | `F` **segundos de slot** | `MAX_REORG_LENGTH = 11 999` **bloques** |
| Semántica | la punta incompatible **se ignora**, «nunca apaga el proceso» | el nodo **se detiene**: «Quien lo reciba **MUST** detener el nodo y avisar al operador, no reintentar» (**verificado en fuente:** `/home/katana/zeo/ZEROX/crates/zx-node/src/cadena.rs:318-320`) |
| Estatuto | «Sustituye a C-REORG-07 en el DAG» (`:303`) | «no fija la finalidad del consenso DAG … Su integración está pendiente» (`SPEC.md:1897-1899`) |

**El SPEC dice explícitamente que no están reconciliadas:** «La regla temporal R-FIN-7 del diseño
DAG y el límite transitorio `C-REORG-07` deben reconciliarse al integrar consenso»
(**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:2052-2053`) y «No se publican ambas
reglas como simultáneamente activas» (`/home/katana/zeo/ZEROX/SPEC.md:1903`).
**No determinado por el SPEC.**

> **D-F3 = C, DECIDIDA por Katana el 2026-09-20, ACOTADA AL ENUNCIADO**
> (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:10`): **una regla de finalidad NUEVA en el SPEC,
> escrita en slots y con la semántica de R-FIN-7** —la punta incompatible **se ignora**, el proceso
> **no se detiene**—, con `F_slots` como **símbolo**. Es **C-FIN-01**, §10.4. El apoyo para
> escribirla ya está en el propio SPEC: él mismo declara `C-REORG-07` «límite heredado … pendiente
> de sustituir en el DAG», que «no fija la finalidad del consenso DAG» y cuya «integración está
> pendiente» (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1891-1899`), y pide la
> reconciliación en §13 (`:2050-2054`).
>
> **Alcance estricto, y lo que queda fuera se dice aquí:** esta propuesta escribe **solo el
> enunciado**. **NO entran** —y quedan declarados pendientes— la reconciliación con el código que
> hoy **se detiene** (`/home/katana/zeo/ZEROX/crates/zx-node/src/cadena.rs:318-320`), con
> `COINBASE_MATURITY` (de la que `MAX_REORG_LENGTH` deriva,
> `/home/katana/zeo/ZEROX/SPEC.md:1894`) y con el techo de archivado. **No se intenta reconciliar
> `C-REORG-07`: es transitoria y sigue siéndolo**, exactamente como el SPEC la describe.

**La regla queda escrita en §10.4**; el análisis de por qué la elección importaba se conserva abajo
como registro de la decisión. **Esta propuesta cuelga de la semántica y la magnitud de R-FIN-7**
—ahora en C-FIN-01—, y lo declara como hipótesis en
§0.2(ii). **Y la elección no es cosmética: cambia la conclusión (c).** Con los valores nominales:

```text
R-FIN-7      : F = 2 h = 7 200 slots.  d(t_j) ≥ L+1 = 7 201 > 7 200  ⟹ ventana VACÍA
C-REORG-07   : 11 999 bloques ≈ 3,33 h a tasa nominal
               (verificado en fuente: SPEC.md:1902)
               d(t_j) ≈ 7 201 bloques < 11 999  ⟹ ventana NO vacía: ≈ 4 798 bloques ≈ 1,33 h
```

Es decir: **bajo `C-REORG-07` la afirmación (c) del encargo es falsa** y existiría una ventana de
adopción de ≈1,33 h — precisamente el régimen que DF-2 da por inexistente. Y hay un segundo problema,
independiente del número: `C-REORG-07` cuenta **bloques** y toda esta propuesta cuenta **slots**;
convertir una en otra exige `λ`, que es una magnitud **estimada por el retarget**, no una constante
de consenso. Una regla de finalidad medida en bloques no se puede comparar con una profundidad
medida en slots sin introducir `λ` en el consenso. **Ésa fue la decisión de mayor consecuencia de
esta propuesta, y Katana la tomó el 2026-09-20: opción C.**

### 10.4 · La regla de finalidad que D-F3 decide, escrita — solo el enunciado

#### C-FIN-01 · Finalidad en índices de slot, sin `exit` — propuesto; **D-F3 = C DECIDIDA (2026-09-20)**

```text
Sea d = slot(punta actual) − slot(último ancestro común con la punta candidata),
en índices de slot de PoT (C-FLU-01).

Un nodo MUST NOT sustituir su cadena seleccionada por una candidata con d ≥ F_slots.
Una punta que lo exigiera se IGNORA.
El nodo MUST seguir operando: MUST NOT detenerse, MUST NOT abortar y MUST NOT
exigir intervención del operador por este motivo.

F_slots es un SÍMBOLO. Esta regla no le da valor.
```

- **Propuesto — de dónde sale cada pieza.** El enunciado es el de R-FIN-7 (**verificado en fuente,
  evidencia histórica:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:301-303`), con
  tres precisiones que R-FIN-7 no tenía: la magnitud es el **índice de slot** y no «segundos de
  slot» (C-FLU-01, borde 2 del encargo); la desigualdad es **explícita** y es la (α) de §10.2 (D-F4
  = A); y el «nunca apaga el proceso» pasa de nota a **MUST NOT** enumerado, porque es precisamente
  lo que la diferencia del comportamiento vigente en el código.
- **Verificado en fuente — `F_slots` como símbolo tiene precedente en el SPEC.** §7.3 ya trata `F`
  así: «`F = 2 h` sigue provisional; no es la espera de Cortex ni se iguala por defecto a `L`»
  (`/home/katana/zeo/ZEROX/SPEC.md:1436`) y «`I`, `L`, `ρ_max`, la configuración final de `F` y la
  calibración frente a `Δ` siguen abiertos» (`:1437-1438`). Esta regla **no cierra** esa
  calibración.
- **Demostrado — es lo que las demostraciones de §0 necesitan, y nada más.** §0.2 usa exactamente
  dos cosas: que la profundidad se mida en slots y que `d ≥ F_slots` esté prohibido. C-FIN-01 las da.
  El «se ignora, no se detiene» no entra en ninguna demostración: entra porque sin él una partición
  de flujo **apagaría** la mitad de la red (§10.3), que es el resultado que la opción B producía.
- **Relación con `C-REORG-07` — se declara, no se resuelve.** `C-REORG-07` es «límite heredado de la
  implementación, pendiente de sustituir en el DAG», «se conserva para identificar el estado
  transitorio del código» y «no fija la finalidad del consenso DAG» (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/SPEC.md:1891-1899`). **Sigue siendo transitoria y esta propuesta no la
  toca.** El SPEC ya pide la reconciliación (`:2050-2053`) y **no se hace aquí**, por alcance
  explícito de la decisión (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:10`). Lo que queda
  pendiente, nombrado:
  1. El código que **se detiene** hoy: `ReorgDemasiadoProfunda` obliga a «detener el nodo y avisar
     al operador, no reintentar» (**verificado en fuente:**
     `/home/katana/zeo/ZEROX/crates/zx-node/src/cadena.rs:318-320`). C-FIN-01 dice lo contrario;
     alguien tendrá que decidir cuándo y cómo migra.
  2. **`COINBASE_MATURITY`**, de la que `MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 11 999` deriva
     (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1894`): si la finalidad pasa a
     `F_slots`, la relación entre madurez de coinbase y profundidad de reorg deja de ser la que el
     código supone.
  3. **El techo de archivado.** No lo he estudiado y **no lo toco**; queda nombrado como pendiente.
- **En qué familia de IDs debe vivir esta regla: no lo decido yo.** `C-FLU-NN` es la familia del
  **flujo**, y ésta **no es una regla de flujo**: es una regla de finalidad que el flujo usa.
  Llamarla `C-FIN-01` es cómodo para esta propuesta y **probablemente equivocado para el SPEC**.
  **Va como D-F7** en `DECISIONES-PENDIENTES.md`, por la instrucción de abrir las bifurcaciones
  nuevas en vez de resolverlas (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:19-20`).

---

## 11 · Índice de las reglas propuestas

Familia `C-FLU-NN`, **nueva**: comprobado que ningún `C-FLU` existe hoy en el repositorio. Los IDs
son nuevos y estables y no reutilizan ninguno retirado, según `TAREAS.md` §4.2
(**verificado en fuente:** `/home/katana/zeo/ZEROX/TAREAS.md:653-654`). Mientras no exista código,
al trasladarlas habría que declararlas en `ci/reglas-sin-codigo.txt`
(**verificado en fuente:** `/home/katana/zeo/ZEROX/TAREAS.md:655-656`); **esta propuesta no ha
tocado `ci/`**.

| ID | Qué fija | § | Estado |
|---|---|---|---|
| C-FLU-01 | Unidades en slots; `L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)` | 1 | **suelo DECIDIDO 2026-09-20**; `L_suelo_slots` sin valor (símbolo) |
| C-FLU-02 | Cierre de ancestros por slot: **todo** padre cumple `slot(p) ≤ slot(B)` | 2 | **D-F6 = A DECIDIDA 2026-09-20**; coste `estimado`, a confirmar con ANCLA-v0.2 |
| C-FLU-03 | Vista de época `V_j(B)`, con corte en `T_j + L_slots` (no en `t_j`) | 2 | propuesta |
| C-FLU-04 | El ancla: primer cruce de `T_j` por `Chn(V_j(B))`. Existencia, unicidad, buena fundamentación | 2 | propuesta |
| C-FLU-05 | Época sin ancla: se salta, sin recuperación retroactiva; bloque sin ancla a `T_j+L` es inválido | 3 | propuesta |
| C-FLU-06 | Flujo del génesis `f_0` y origen de `semilla(f_0, 0)` | 3 | propuesta; etiqueta nueva por **D-F2 = A DECIDIDA** |
| C-FLU-07 | `t_j = slot(I_j) + L_slots`; una sola lotería hasta `t_j` | 4 | propuesta |
| C-FLU-08 | `S_max_slots < L_slots` (corrección: el ancla dentro de su vista; entierro) | 4 | propuesta |
| C-FLU-09 | `S_max_slots < I_slots`; `t_j` distintos dos a dos; ≤ 1 inyección por slot | 4 | propuesta |
| C-FLU-10 | Derivación del identificador de flujo, acumulativa y función de `past(B)` | 5 | propuesta; `H_flujo = H_d` por **D-F2 = A DECIDIDA**; **amplía C-HASH-06** |
| C-FLU-11 | El flujo nunca se declara; encaje con `flow(B, slot(B))` de C-HDR-06 | 5 | propuesta |
| C-FLU-12 | Entropía de la inyección + **C-FLU-12.1**, invariante de no-equivocación | 6 | **D-F1 = A DECIDIDA 2026-09-20** |
| C-FLU-13 | Validez absoluta | 7 | propuesta |
| C-FLU-14 | Pasado consistente de flujo; paso **1b** del orden de validación | 7 | propuesta |
| C-FLU-15 | Declaración DF-3/DF-4 («se trata como», no «es») | 8 | **corregida en revisión 5**: cura el nacimiento espontáneo, **no** el corte de red > `L` |
| C-FLU-16 | `N(s)` cambia exactamente en `t_j`; su autoridad va como símbolo | 9 | propuesta |
| **C-FLU-17** | **El nodo detecta y señala que está en un flujo minoritario.** Comportamiento de nodo, **no** validez | 8 | nueva en revisión 2; regla operativa de **D-F5 DECIDIDA** |
| **C-FLU-18** | **El nodo sin cadena previa aplica la selección ordinaria de GHOSTDAG**; la finalidad solo obliga a quien tiene cadena | 8 | **nueva en revisión 3**; **D-F5 DECIDIDA** — cierra un hueco de redacción, no añade mecanismo |
| **C-FLU-20** | **El productor descarta las puntas cuya fusión cambiaría un ancla ya activada**; ese bloque queda **infusionable para siempre** | 7 | nueva en revisión 4, tras la objeción del validador a la Prop. A |
| **C-FLU-21** | **La inyección ya activada se hereda, no se recalcula** | 7 | nueva en revisión 4; **D-F8 = C DECIDIDA: regla firme**, no se congela la vista |
| **C-FLU-22** | **Adopción del flujo rival dentro de la ventana, con presupuesto.** Sustituye a DF-2 | 8 | nueva en revisión 5; **D-F9 = C DECIDIDA** |
| **C-FLU-23** | **Presupuesto de flujo ajeno: por par Y global por nodo**; agotarlo deja al nodo donde está, con `Pendiente` | 8 | **nueva en revisión 6**; **D-F10 = B DECIDIDA**. Es enmienda a C-NET-32.3: el traslado debería numerarla en **`C-NET`** |

**Familia `C-FIN`, nueva — D-F7 = B, decidida por Katana el 2026-09-20**
(`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-3.md:9`). La regla de finalidad **no es una regla de flujo**
y sale de `C-FLU`. Comprobado que ningún `C-FIN` existe hoy en el repositorio. Mismo régimen que
`C-FLU`: IDs nuevos y estables (`/home/katana/zeo/ZEROX/TAREAS.md:653-654`), y al trasladarla habría
que declararla en `ci/reglas-sin-codigo.txt` (`:655-656`), que **esta propuesta no ha tocado**.

| ID | Qué fija | § | Estado |
|---|---|---|---|
| **C-FIN-01** | **Finalidad en índices de slot, sin `exit`.** `d ≥ F_slots` prohibido; la punta se ignora; el proceso no se detiene | 10.4 | nueva en revisión 3; **D-F3 = C DECIDIDA, solo el enunciado**; **renombrada desde `C-FLU-19` en la revisión 5** |

---

## Lo que esta propuesta NO resuelve

**Lo primero de todo, revisión 4: dos resultados míos de las revisiones 1-3 eran FALSOS.** La
Prop. A de §0.4 y la conclusión (c) de §0.2. Los dos venían del mismo cambio de objeto: apliqué a
**las cadenas seleccionadas de los nodos** un lema que solo vale para **`Chn(V_j)`**, la cadena de la
vista truncada con la que C-FLU-04 repara la circularidad E1. Están retirados y sustituidos por A1,
A2 y (c′). **Consecuencia para quien traslade:** ni «la ventana de adopción es vacía» ni «el vector 2
queda cerrado sin estadística» son afirmaciones de este documento. Y **DF-2 se decidió sobre la
primera** (D-F9).

**Lo segundo:** la afirmación central del encargo §2 está **refutada en
su parte (a)** (§0.3), **y el validador lo ha aceptado**
(`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:8-12`). El perfil 1a queda **reconfirmado por Katana el
2026-09-20 sabiendo que una partición no tiene cura en el protocolo**, pero **por otra razón** que
la del encargo: no porque
una partición exija violar la finalidad, sino porque `L ≥ F` congela el ancla antes de usarla (P1,
demostrado) y porque la probabilidad de que la partición nazca es pequeña (P2, **medida en
simulación**). Si la partición nace, es permanente (P3, demostrado). Cualquier texto que se traslade
al SPEC citando (a) como justificación estaría citando un argumento que no se sostiene.

1. **La evidencia de medición es simulada.** La `Δ` de DMS-v0.1 **no es una medición de red**
   (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:28`). Todos los `L_mín` y la
   cola exponencial de `W_obs` cuelgan de una `Δ` supuesta. `Δ` sigue siendo «la primera medición
   que el diseño necesita» (**verificado en fuente:**
   `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:163`).
2. **Las vías de ataque medidas son las simples.** V1 con tope de 8 candidatos y ventana
   `[T, T+45]`; **A3 estática** (todos los bloques al mismo observador toda la réplica)
   (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:22-25`). **No están medidos**
   el **equilibrio adaptativo** (partir a los honestos en dos mitades y sostener el empate), el
   **soborno del ancla**, el **sembrador**, ni un adversario con **VDF más rápido** (`ρ > 1`)
   (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:61-65`). El equilibrio
   adaptativo es el que ataca directamente a (P2), que es donde ahora descansa toda la seguridad.
3. **La convergencia del orden no está probada para este diseño.** Prop. 7 y Def. 2 están probadas
   sobre GHOSTDAG **puro**; con U3″ + R-FIN-5 + R-FIN-8′ «no está comprobado. Es la deuda principal»
   (**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:436-439`).
   **Esto toca a esta propuesta de lleno:** (F1) y (F2), de las que cuelgan la Prop. 1 y toda la
   sección §2, son propiedades medidas en el simulador y un lema, no consecuencias del teorema.
4. **Existencia del ancla en el caso patológico.** C-FLU-04 demuestra la existencia bajo una
   condición suficiente, y C-FLU-05 cierra el caso contrario con un rechazo. **No está demostrado ni
   medido** con qué probabilidad `Chn(V_j(B))` diverge de la cadena de `B` por debajo de `T_j`: no
   existe ninguna proposición que ate `blue_work` con `slot`.
5. **El coste del perfil 1a frente al sembrador — y con `L ≥ F` esa puerta queda cerrada.**
   (Declaración añadida en la revisión 2 por `/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:41-47`.)
   La entropía se conoce con `L` de adelanto (2 h con `F = 2 h`); el margen histórico frente al
   sembrador es **1,91×**, **con precios supuestos** (**verificado en fuente:**
   `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:56`, y `ancla-de-orden.md:449` declara «El presupuesto
   económico: precios supuestos»). **Lo nuevo es que bajo 1a no se puede aliviar bajando `L`:** la
   mejora histórica «desatar `L` de `F`» **queda cerrada** por DF-1, y el suelo de C-FLU-01 la cierra
   todavía más. Y la defensa alternativa **no funciona tal como estaba escrita:**
   - «Ni `history_size` ni `altura_ploteo` demuestran antigüedad física. Identifican el prefijo
     histórico que determina la parcela y su caducidad. Un atacante puede escoger hoy una referencia
     antigua que aún sea válida» (**verificado en fuente:**
     `/home/katana/zeo/ZEROX/P-SEMBRADOR/investigacion/INFORME.md:9`, etiquetado allí **[Demostrado
     respecto de las reglas escritas]**).
   - Y al atacante **le basta una pieza, no un sector**: «Basta un registro/pieza, no un sector
     entero» (**verificado en fuente:**
     `/home/katana/zeo/ZEROX/P-SEMBRADOR/investigacion/INFORME.md:27`, **[Demostrado por inspección
     de dependencias]**).
   - Cerrar el mecanismo exigiría **A1+C1** —registrar antes del reto una raíz/versionado/
     cardinalidad de la parcela exacta, y una edad mayor que una cota explícita del adelanto—, es
     decir **un cambio de consenso** (`.../INFORME.md:13`).

   **Estado de esa fuente:** el validador declara **validación parcial** —integridad, tests y las
   dos citas clave de la fuente de Autonomys comprobadas; **el informe completo está sin leer**
   (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:45-47`). **El margen real de 1a frente al sembrador
   NO está medido.** Yo he abierto y citado las tres líneas de arriba; no he leído el informe entero
   ni he revisado su aritmética.
6. **El suelo de `L` cierra el defecto que la atadura tenía, pero no le pone número.** En la
   revisión 1 este punto decía que bajar `F` arrastraba `L` por debajo de lo medido (`F = 1 h` ⟹
   `L_slots = 3 600`, contra ≈3 600-5 000 extrapolado para `Δ` = 10-16 s). **La decisión de Katana
   del 2026-09-20 lo corrige** con `L_suelo_slots` (C-FLU-01). Lo que **sigue abierto** es el propio
   valor: su criterio de calibración exige una cota de `Δ` **medida en red real**, que no existe. Sin
   ella, `L_suelo_slots` no se puede fijar, y cualquier cifra provisional hereda la etiqueta de la
   simulación.
7. **El camino a 1b, y sus condiciones.** `L < F` da margen **3,6×** frente al sembrador, pero exige
   `Δ ≤ ~4 s` **medida en red real** y el equilibrio adaptativo medido
   (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:49-50, 56`). Bajo 1b la
   ventana de adopción **sí** existe (`F − L > 0`) y haría falta la regla de adopción que DF-2
   descarta hoy, más los dos huecos de redacción de `SINTESIS.md:41-43`. Esta propuesta **no** lo
   prepara: si se adopta 1b, C-FLU-15 y §0.2 hay que reescribirlos enteros.
8. **El nodo que sincroniza desde cero: la conducta ya está escrita; el riesgo no desaparece.**
   C-FLU-18 (D-F5 decidida) hace la conducta **determinista y única** —selección ordinaria— y
   C-FLU-17 hace que el nodo se entere si cae fuera del mayoritario. **Ninguna de las dos hace que
   elija bien.** Después de `ALTURA_CADUCIDAD` del checkpoint y con una partición viva, un nodo
   nuevo va al flujo más pesado **del momento**, que puede ser el minoritario. Sigue siendo, según
   la medición, uno de los dos canales dominantes
   (`/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:35-36, 41-43`). La regla objetiva que podría cerrarlo
   —«el flujo canónico es el que lideraba en `t_j + F_slots`»— queda como **encargo aparte**, con su
   resistencia a bloques con slots antiguos por estudiar (`/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:58`).
9. **Un granjero puede producir en un flujo que no ha seleccionado, y eso sigue declarado y no
   legislado.** No se puede prohibir criptográficamente: las identidades son gratis por diseño, y el
   teorema dice algo más fuerte —«cualquier mecanismo de exclusividad entre relojes en PoAS
   permisionless es derrotable por partición de identidad»— (**verificado en fuente:**
   `/home/katana/zeo/ZEROX/research/dag-poas-balizas-auditoria.md:68-75`). Lo único que el diseño
   hace es dejarlo **sin valor económico** (C-FLU-15), y eso no es lo mismo que impedirlo.
10. **La reconciliación de la finalidad no entra en esta propuesta, por alcance decidido.**
    C-FIN-01 escribe **solo el enunciado**. Quedan pendientes, nombrados en §10.4: el código que hoy
    **se detiene** (`/home/katana/zeo/ZEROX/crates/zx-node/src/cadena.rs:318-320`),
    `COINBASE_MATURITY` y su relación con `MAX_REORG_LENGTH`
    (`/home/katana/zeo/ZEROX/SPEC.md:1894`), y **el techo de archivado, que no he estudiado**.
    `C-REORG-07` sigue siendo transitoria y no se ha tocado.
11. **La aritmética del adelanto está SIN REHACER tras fijar `pot_output` como salida futura.**
    (Declaración reforzada en la revisión 2 por `/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:48-49`.)
    El argumento de R-FIN-14(f)/(h) —`I ≥ ρ_max·W_dec`, `lead_max`, `ρ* ≈ 1 + L/I`— está escrito
    sobre la salida **del propio slot**
    (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:275-288`); con **D-2 = A**,
    `pot_output = salida(f, slot+D)` y esa aritmética **no se ha rehecho**. Lo anoté en §6
    (C-FLU-12.1) y queda aquí como **pendiente explícito**: no lo toco porque es de `P-POT`/§2.1,
    pero **ninguna cifra de adelanto, de `ρ_max` ni de margen frente al sembrador debe darse por
    válida hasta que se rehaga**. La investigación del sembrador llega a la misma conclusión y
    apunta a esta propuesta al decirlo (**verificado en fuente:**
    `/home/katana/zeo/ZEROX/P-SEMBRADOR/investigacion/INFORME.md:11`, **[No determinado]**).
12. **La disponibilidad del ancla tras la poda.** R-FIN-1 lo deja como cierre pendiente
     (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:172-174`) y el SPEC lo repite
     (`/home/katana/zeo/ZEROX/SPEC.md:1453-1455`). C-FLU-04 necesita `V_j(B)` para **todas** las
     épocas del pasado; qué pasa cuando esos bloques están podados **no se resuelve aquí**. La poda
     «sin niveles de PoW … sigue sin resolver» (`ancla-de-orden.md:430`).
13. **Las dos citas de segunda mano de la revisión 1 están resueltas.** El `pot.rs` de Autonomys
     está **abierto y verificado de primera mano** (`…/pot.rs:178-187` más `…/hashes.rs:151-157`,
     §3); y la cita de DF-4 estaba **mal**: el archivo es
     `/home/katana/zeo/ZEROX/research/dag-poas-balizas-auditoria.md`, no `balizas-auditoria.md`, y
     ahora está abierto y citado por línea (§8). **Ya no queda ninguna cita de segunda mano en este
     documento**, con una excepción declarada: de
     `/home/katana/zeo/ZEROX/P-SEMBRADOR/investigacion/INFORME.md` he abierto y citado las líneas 9,
     11, 13 y 27, **no el informe entero** (punto 5).
14. **El coste de C-FLU-02 para el productor honesto está `estimado`, no medido.** La confirmación
     con ANCLA-v0.2 —fracción de bloques honestos que referenciarían un padre de slot mayor, con
     `Δ` = 0,5 / 4 / 16 s— es **condición para pasar al SPEC**, no trabajo opcional (§2, punto (ii)).
15. **La carrera A2 no está medida, y es un hueco nuevo.** `P(una rama privada desplaza el ancla
    dentro de `V_j` antes de `t_j`)` es la cola de una carrera de `blue_work` de longitud `L`. El
    **umbral** está medido —`α_mínimo = 1/2`, CRP-v0.1,
    `/home/katana/zeo/ZEROX/TAREAS.md:129-134`— pero **la cola a `L = F_slots` no**, y lo que
    `P-2.1` midió (`L_mín`) es otra magnitud (desacuerdo honesto por latencia). **Ni el encargo ni
    ninguna adenda contemplaban este vector.** Instrumento que podría medirlo: ANCLA-v0.2.
16. **El colateral honesto de C-FLU-20 no está medido.** Un bloque tardío que cambiaría un ancla ya
    activada queda **infusionable para siempre**. Lo normal es que sea del atacante; con qué
    frecuencia atrapa bloques honestos —y cuánto empeora en el régimen candidato `τ ≈ 0,1-0,17 s`—
    **no se ha medido**.
17. **La ventana ya tiene regla (C-FLU-22), pero lo que la regla cura es el caso improbable.** El
    nacimiento **realista** de una partición —un corte de red más largo que `L`— deja la ventana
    **vacía** y la partición **permanente**. C-FLU-22 cura el nacimiento **espontáneo**. **Ningún
    texto derivado debe decir «las particiones se curan».**
18. **Las dos rendijas de PCO-v0.1 siguen abiertas y son suyas, no mías.** Desfase de vista en el
    instante de congelación, `arcsin(√(τ/F))/π` → 0,27 % / 0,75 % / 1,5 % para `τ` = 0,5 / 4 / 16 s
    con `F = 2 h`, **condicionado a que la partición haya nacido y a reparto simétrico**; y el nodo
    que sincroniza después (**verificado en fuente:**
    `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:29-36`). Van como `√(τ/F)`: **cuadruplicar `F` solo
    las divide por dos.**
19. **El presupuesto añade una TERCERA rendija a las dos de PCO-v0.1, y no está medida.** Con
    C-FLU-23, dos nodos con el mismo DAG pueden acabar en flujos distintos porque uno pudo pagar la
    verificación dentro de la ventana y el otro no. A diferencia del desfase de vista y del nodo que
    sincroniza después, **esta está parcialmente bajo control del atacante**, que puede gastar
    presupuesto ajeno con tráfico barato del paso 1b. La validez no se mueve; se mueve la
    **selección**, que bajo C-FLU-22 decide el flujo. **Sin medir.**
20. **Los dos presupuestos van como símbolos y su calibración es una pinza, no un número suelto.**
    Demasiado pequeño, `PRESUP_NODO` **deroga D-F9 en la práctica**: la adopción nunca se completa y
    la decisión queda anulada sin que nadie la revoque. Demasiado grande, devuelve el DoS. La cota
    inferior sale del peor caso, `F_slots × 92 ms` ≈ **11 min de CPU**
    (`/home/katana/zeo/ZEROX/SPEC.md:2987-2988`); la superior **no está derivada**. El valor de
    C-NET-32.3 sigue siendo un `<<PENDIENTE>>` declarado (`:3007-3009`).
21. **Ninguna de estas reglas tiene código**, y esta propuesta no lo escribe (fuera de alcance). El
     verificador PoT tampoco existe todavía (**verificado en fuente:**
     `/home/katana/zeo/ZEROX/TAREAS.md:174-178`). C-FLU-17, además, necesita puntos de enganche en el
     nodo (§14.3/§16) que hoy no existen.
