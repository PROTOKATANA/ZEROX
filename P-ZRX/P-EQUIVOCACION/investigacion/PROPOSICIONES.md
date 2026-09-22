# PROPOSICIONES — P-EQUIVOCACION

Cada proposición lleva **premisas**, **demostración o contraejemplo** y **etiqueta**:
`demostrado` · `verificado en fuente` · `enumerado` (con su rejilla) · `derivado` · `propuesto`
· `no determinado`. Convención del encargo §8: *una enumeración finita no es una demostración*, y
se dice en cada caso.

Todas las rutas son completas desde la raíz `/home/katana/zeo/ZEROX`. Las reglas se citan por
**identificador** (`C-…`), nunca por número de línea.

---

## 0 · Notación y premisas comunes

Se fijan las siguientes **entradas** (ninguna se propone como valor):

```text
I := I_slots      umbral de época            T_j := j·I
L := L_slots      activación (C-FLU-01)      L := máx(F, L_suelo, S_max + 1)
F := F_slots      finalidad (C-FIN-01)       S_max := S_max_slots
k                 parámetro del k-cluster (C-GD-06)
```

**Perfil 1a** (`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md`, revisión 6; `SPEC.md` C-FLU-01):
`L ≥ F`. **Premisa de todo el documento salvo donde se diga lo contrario.**

Para una punta `B`:
`V_j(B) := (past(B) ∪ {B}) ∩ {X : slot(X) < T_j + L}` (`C-FLU-03`);
`I_j(B)` := primer bloque de `Chn(V_j(B))` con `slot ≥ T_j` (`C-FLU-04`), y `0` si la época se salta
(`C-FLU-05`); `t_j(B) := slot(I_j(B)) + L` (`C-FLU-07`);
`entropía_j(B) := blake3(chunk(I_j(B)) ‖ pot_output(I_j(B)))` (`C-FLU-12`);
`flujo(B, s)` := `C-FLU-10`, que depende **exclusivamente** de las parejas `(entropía_{j'}, t_{j'})`
de las inyecciones con `t_{j'} ≤ s`, en orden de `j'`.

**Dos ramas.** `A` = punta de la rama honesta/pública; `B` = punta de la rama privada/retenida.
`P` := su último ancestro común; `s₀ := slot(P)`; `d := slot(punta) − s₀`.
**Ventana de reorganización:** `d < F` en las dos puntas (`C-FIN-01`).
**Ventana de doble farmeo** `W` := los slots en los que **las dos** ramas llevan bloque propio,
`(past(tip) ∪ {tip}) \ (past(P) ∪ {P})` — es donde el agricultor usó su parcela dos veces.

> **Aviso de método.** `Chn(V_j(B))` **no** es la cadena seleccionada del nodo
> (`SPEC.md` C-FLU-04, nota «⛔ `Chn(V_j(B))` NO es la cadena seleccionada del nodo»). Y
> `V_j` es una vista **truncada en `T_j + L`**, no la cadena. Todo lo que sigue se apoya en eso.

---

## P1 · El ancla cae en una franja de anchura `S_max` por encima de `T_j` — `demostrado`

**Enunciado.** Para toda punta `B`, toda época `j` con `I_j(B) ≠ 0`:

```text
T_j  ≤  slot(I_j(B))  <  T_j + S_max_slots
```

**Demostración.** Sea `q := I_j(B)`, el primer bloque de `Chn(V_j(B))` con `slot ≥ T_j`. Sea
`p := sp(q)` el bloque anterior en esa cadena. `p` existe: si no existiera, `q` sería el génesis de
la vista y tendría `slot = 0 < T_j` (`j ≥ 1`), contra la definición. Por ser `p` anterior a `q` en la
cadena y no cruzar, `slot(p) < T_j`. Por `C-GD-04`, `slot(q) − slot(sp(q)) ≤ S_max_slots`, es decir
`slot(q) − slot(p) ≤ S_max_slots`. Luego `slot(q) < T_j + S_max_slots`. La otra desigualdad es la
definición de cruce. ∎

**Comprobado además en el enumerador** (`src/validacion.jl`, `propiedad_P1`), sobre las
configuraciones de regresión y sobre la rejilla. `demostrado` + `enumerado`.

---

## P2 · La primera mitad de la hipótesis: el ancla es anterior a la bifurcación — `demostrado`

**Enunciado.** Sea `j` una inyección **activa** en un slot `s` de la ventana de reorganización, es
decir `t_j ≤ s` y `s₀ ≤ s < s₀ + F`. Entonces:

```text
slot(I_j)  <  s₀        y, por P1,   T_j < s₀
```

**Demostración.** `slot(I_j) = t_j − L ≤ s − L < (s₀ + F) − L ≤ s₀`, donde la última desigualdad es
el perfil 1a (`L ≥ F`, `C-FLU-01`). ∎

**Observación que decide el resto.** `P2` sólo dice que el **slot** del ancla es anterior a la
bifurcación. **No dice que el ancla sea el mismo bloque en las dos ramas.** La hipótesis del §0 del
encargo da el paso de «anterior a la bifurcación» a «luego comparten flujo» sin justificarlo, y ese
paso es exactamente lo que falla en `P4`.

---

## P3 · Si las anclas activas coinciden, los flujos coinciden en toda la ventana — `demostrado`

**Enunciado.** Si para toda época `j` activa en la ventana `[s₀, s₀+F)` se tiene
`I_j(A) = I_j(B)` (el **mismo bloque**, no sólo el mismo slot), entonces
`flujo(A, s) = flujo(B, s)` para todo `s` de la ventana.

**Demostración.** Por `C-FLU-12`, la entropía es función de campos de cabecera de `I_j`; con el
mismo bloque, `entropía_j(A) = entropía_j(B)`. Por `C-FLU-07`, `t_j = slot(I_j) + L` coincide
también. `flujo(·, s)` (`C-FLU-10`) es la composición ordenada de `(entropía_{j'}, t_{j'})` para
`j'` con `t_{j'} ≤ s`, y el conjunto de inyecciones activas y sus valores coinciden en las dos
ramas. ∎

**Consecuencia para el reto.** `reto(f, s) = blake3(blake3(salida(f,s)) ‖ LE64(s))` (`C-POT-03`)
con la misma `f` y el mismo `s` es el mismo valor en las dos ramas. **No se ha necesitado ninguna
propiedad estadística.**

`demostrado`.

---

## P4 · La hipótesis, tal como está escrita, es **FALSA** — `enumerado` + contraejemplo explícito

**Enunciado que se refuta.** «Bajo el perfil 1a, dentro de la ventana en que una reorganización es
posible las anclas de las inyecciones activas son anteriores a la bifurcación, **luego las dos
ramas comparten flujo y tienen los mismos retos**.»

**Por qué falla la inferencia.** «Anterior a la bifurcación» es una afirmación sobre `slot(I_j)`;
«comparten flujo» es una afirmación sobre el **bloque** `I_j` y su `t_j`. Entre las dos hay un
escalón: que `Chn(V_j(A))` y `Chn(V_j(B))` crucen `T_j` en el **mismo** bloque. `V_j` es una vista
truncada que **crece sin reorganización** cuando se fusiona un bloque retenido con
`slot < T_j + L` (`SPEC.md` C-FLU-04, nota (1): «Fusionar no es reorganizar; ninguna regla de
finalidad lo toca»). Ese es el caso **A2** que
`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` §0.4 ya etiqueta «PROBABILÍSTICO, no
demostrado, y NO medido».

**Contraejemplo mínimo** (verificado por el enumerador, `test/runtests.jl` y
`resultados/kappa-flujo.csv`). Con `I = 20`, `L = F = 20`, `S_max = 15`:

```text
común   : 0, 5, 10, 15, 25          (P = 25, s0 = 25, T_1 = 20)
pública : 28, 32, 36, 40, 44        (A = 44;  d = 19 < F)
privada : 8, 12, 16, 20, 24, 28, 32, 36, 40, y un bloque que fusiona P
```

La rama privada bifurca en el bloque común de slot `5 < T_1` y lleva **más bloques dentro de
`V_1`** que la común en el intervalo `(5, 25]`. Entonces `Chn(V_1(B))` sigue la sub-rama privada y
cruza `T_1 = 20` en el bloque privado de slot 20, mientras `Chn(V_1(A))` cruza en el bloque común de
slot 25. Las anclas son **bloques distintos**, ambas con `slot < s₀ = 25` (P2 se cumple), y
`t_1(priv) = 40 < t_1(pub) = 45`: **las dos ramas tienen retos distintos desde el slot 40**.

**Lo que dice la rejilla** (`resultados/kappa-flujo.csv`, 480 configuraciones, todas con
`dentro_de_ventana = true`):

| Observación | Número |
|---|---|
| Anclas iguales ⟹ `κ_flujo = 1.0000` | **54 / 54** |
| Anclas distintas | 426 |
| `n_priv > n_com` ⟹ anclas distintas | 418 / 418 |
| `n_priv < n_com` ⟹ anclas iguales | 36 / 36 |
| Empates `n_priv = n_com` | 26, resueltos por el desempate de `C-GD-03` (18 iguales, 8 distintas) |

donde `n_priv` = bloques propios de la rama privada dentro del corte `T_1 + L`, y `n_com` = bloques
comunes con `slot ∈ (slot(W), s₀]`. **La enumeración no demuestra P2 ni P3**, pero exhibe el
contraejemplo y mide con qué frecuencia aparece en la rejilla declarada.

**Conclusión de P4.** La hipótesis del validador es **verdadera sólo bajo una premisa añadida**
(que la sub-rama privada no se lleve `Chn(V_j)`), y **falsa en general** sin ella.
`enumerado` (contraejemplo explícito, reproducible).

---

## P5 · La condición exacta del escape: `n_priv > n_com` dentro de `V_j` — `demostrado` + `enumerado`

**Enunciado.** Dentro de `V_j(B)`, la cadena del virtual toma la sub-rama privada (y con ello
cambia el ancla) **si y sólo si** el `blue_work` de la punta privada supera al de `P`; con pesos
uniformes (`SR` constante, el caso de la rejilla) eso es

```text
n_priv  >  n_com        (empates: C-GD-03, menor dist y luego menor id)
```

**Demostración.** `C-GD-03` elige la punta del virtual por `(blue_work, −solution_distance, −id)`.
Toda dependencia del `blue_work` respecto de bloques **fuera** de `V_j(B)` es imposible: `V_j(B)`
está truncada y `blue_work` es función de `past(·)` (`SPEC.md` C-GD-09; y
`veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md:68-70`, leído en la fuente: «`rank` es una
función GLOBAL de `B` — depende solo de `past(B)` … nunca de la cadena seleccionada ni del
observador»). Dentro de `V_j(B)` los candidatos a punta son la punta privada `z_m` y los bloques
comunes; el prefijo común hasta el punto de bifurcación retenida `W` lo comparten ambos, así que la
comparación se reduce a `n_priv` frente a `n_com`. ∎

**Enumerado:** 418/418 y 36/36 sobre la rejilla declarada. Los 8 empates que se resuelven en contra
de lo que sugiere el conteo lo hacen por `solution_distance`, que es exactamente lo que dice
`C-GD-03`.

**Consecuencia económica, dicha con su alcance.** El `blue_work` que la rama honesta aporta dentro
de `V_j(B)` **se detiene en `P`**: los bloques honestos posteriores **no están en `past(B)`** y por
tanto no existen en esa vista. En cambio los bloques que el atacante produzca en
`(s₀, T_j + L)` **sí** cuentan. La carrera, dentro de `V_j`, **no es simétrica**: el atacante tiene
`L − δ` slots de presupuesto extra, con `δ := s₀ − T_j`. Esto **no contradice** CRP-v0.1
(`veritas/seguridad/coste-rama-privada-v1/INFORME.md`), que mide el umbral `α_mínimo = 1/2` para una
rama privada frente a la cadena **completa**; mide **otro** objeto. `derivado`, y la asimetría
**no está medida** — ver `DECISIONES-PENDIENTES.md`.

---

## P6 · La divergencia sólo cubre la cola de la ventana — `derivado` + `enumerado`

**Enunciado.** Sean `t_min := mín(t_j(A), t_j(B))` sobre las inyecciones con anclas distintas. Los
slots de la ventana con flujo **coincidente** son exactamente `{s ∈ W : s < t_min}`. Por tanto

```text
κ_flujo  =  |{s ∈ W : s < t_min}| / |W|
```

**Demostración.** Antes de `t_min` ninguna inyección divergente está activa (`C-FLU-07`: el flujo lo
fija la última inyección con `t_j ≤ s`), luego las dos ramas usan la misma lista de inyecciones y por
`C-FLU-10` el mismo flujo. Desde `t_min` la inyección divergente está activa en al menos una rama y
las listas difieren. ∎

**Corolario (`derivado`).** Como `t_min = slot(I_j) + L` y `slot(I_j) < s₀`, la divergencia empieza a
lo sumo `δ` slots después de `s₀`; si la ventana termina en `s₀ + d`, el número de slots divergentes
es `≤ d + δ − L + 1 ≤ δ`. En la rejilla: con `δ = 1` son 1 de 19 slots; con `δ = 4`, 4 de 19
(`resultados/kappa-identidad.csv`, columnas `slots_comun` / `slots_div`). `derivado` + `enumerado`.

---

## P7 · Ninguna de las tres identidades contiene el reto ni la rama — `demostrado` (definicional)

**Enunciado.** Las tres identidades del §1 del encargo son funciones de
`(solución, slot, dominio)` y **no** de `pre_hash`, padres, rama, flujo ni reto:

```text
C-GD-07 / R-FIN-11  (public_key, sector_index, history_size, chunk, slot)
IDV-01              (dominio, slot, public_key, sector_index, history_size, piece_offset)
CANDIDATA.md        H(dominio, slot, PlotBatchId, sector_index, piece_offset)
```

**Consecuencias, y son el eje del informe.**

1. **La evidencia no necesita que los flujos coincidan.** Lo que necesita es que exista **una misma
   identidad elegible en las dos ramas**. La coincidencia de flujo es una vía **suficiente** para
   que la misma solución gane en las dos; **no** es necesaria para que la infracción dispare.
2. **El escape por el ancla es más estrecho de lo que parece.** Con una identidad basada en la
   pieza (`IDV-01`, `CANDIDATA.md`), que las dos ramas tengan **retos distintos** no salva al
   atacante: para evitar la evidencia necesita que **gane otra pieza distinta** en cada reto, porque
   cualquier par de soluciones **de la misma pieza** comparte `TicketId`. Medido: en el escenario
   `misma-parcela` (1 pieza, 8 `chunk`) `κ_comun(IDV-01) = κ_comun(CANDIDATA) = 1.000` en toda la
   columna, también en el régimen divergente.
3. **La identidad de `C-GD-07` es estrictamente más fina** al incluir `chunk`: dos soluciones de la
   misma pieza con `chunk` distinto son `TicketId` distintos y **escapan**. Medido en el mismo
   escenario: `κ_comun(C-GD-07)` = 1.000, 0.750, 0.833, 0.583, 0.286, 0.278, 0.000 para
   `m = 0.05 … 4.0`. Esto **no** es una opinión: `chunk` es el escalar que codifica el plot y la
   distancia depende de `masked_chunk = chunk XOR blake3(proof_of_space)`; una misma pieza admite
   **varias pruebas ganadoras** con `chunk` distinto (verificado en fuente:
   `veritas/consenso/identidad-disponibilidad-v1/IDENTIDAD.md` §4 e `INFORME.md` §1, con el fixture
   real `subspace_verification::verify_solution`).
4. `piece_offset` **no** se puede quitar: dos offsets con el mismo `chunk` son declaraciones
   distintas (`IDENTIDAD.md` §3, medido en el prototipo PoAS). `C-GD-07` no lo incluye.

`demostrado` en lo definicional; lo cuantitativo, `enumerado`.

---

## P8 · Región de κ — `enumerado` sobre rejilla declarada + `derivado`

**Enunciado.** Partiendo `W` en los slots con flujo común (`W_c`) y divergente (`W_d`):

```text
κ(identidad)  =  (|W_c|/|W|) · κ_comun(identidad)  +  (|W_d|/|W|) · κ_div(identidad)
κ_comun(id)   =  1 − P(∃ dos ganadoras con identidad distinta | flujo común)
κ_div(id)     =  1 − P(∃ par (rama A, rama B) con identidad distinta | flujo divergente)
```

**Medido** en `resultados/kappa-identidad.csv` (32 piezas × 4 `chunk` = 128 candidatos; y el
escenario `misma-parcela` con 1 pieza × 8 `chunk`):

| Régimen | `κ` medida |
|---|---|
| Flujo común, `m ≤ 0.05` | **1.000** en las tres identidades |
| Flujo común, `m = 1` | 0.455 (piezas distintas) · `misma-parcela`: 0.286 (C-GD-07) frente a **1.000** (IDV-01/CANDIDATA) |
| Flujo común, `m = 4` | 0.000 · `misma-parcela`: 0.000 (C-GD-07) frente a **1.000** (IDV-01/CANDIDATA) |
| Flujo divergente, con oportunidad | **0.000** en las tres identidades con varias piezas |
| Flujo divergente, `misma-parcela` | C-GD-07 0.000 · IDV-01/CANDIDATA **1.000** |

donde `m` = número esperado de soluciones ganadoras del atacante **por slot** en su parcela
(`m ≈ α·(número de ganadoras de la red por slot)`). `enumerado` (universo finito declarado,
exacto, sin muestreo).

**Región, en palabras y con su etiqueta.** Para un atacante pequeño (`m ≪ 1`, el caso realista de
`P-ZRX/P-EQUIVOCACION/CANDIDATA.md` §A.1) y con identidad basada en la pieza:

```text
κ  ≈  κ_flujo        (porque κ_comun ≈ 1 y κ_div ≈ 0 cuando hay oportunidad)
```

y `κ_flujo ≈ 1 − (slots divergentes)/|W|`, con `slots divergentes ≲ δ`. `derivado` a partir de la
enumeración; **la distribución real de `δ`, `d` y `α` no está medida** y por eso esto es una
**región**, no una cifra.

**Advertencia sobre una cifra que NO hay que usar.** `bench/escalado.jl` imprime
`kappa_flujo_global = 0.764` sobre 5 256 slots: es el **agregado de la rejilla declarada**, que
sobre-representa las configuraciones con escape. **No es una estimación de κ del sistema** y no debe
entrar en `P-ZRX/P-PRESTAMO/` como si lo fuera.

---

## P9 · `κ` para el modelo económico — `propuesto`

**Propuesta, no resultado.** Lo que el modelo de `P-ZRX/P-PRESTAMO/` puede usar hoy:

```text
κ(identidad)  ≈  fracción de la ventana con flujo compartido · 1
              +  fracción con flujo divergente · P(otra pieza gane el otro reto)
```

con la **condición de escape** de `P5` (`n_priv > n_com` dentro de `V_j`) y la **región** de `P8`.
La segunda fracción exige (a) ganar la carrera de `blue_work` dentro de `V_j` y (b) tener una
**segunda** solución ganadora de **otra pieza** en el mismo slot. `propuesto`.

---

## P10 · Las otras fugas de `CANDIDATA.md` — `derivado`, con una `no determinado`

**Enunciado.** De las siete fugas listadas en `P-ZRX/P-EQUIVOCACION/CANDIDATA.md` §«Lo que no debe
prometer» más el catálogo del encargo §2.3:

| Fuga | Clasificación | Fundamento |
|---|---|---|
| Slots alternos | **no es fuga**: es repartir el espacio | un uso de la parcela por slot; sin par de bloques no hay nada que castigar ni doble uso |
| Retos distintos de flujos distintos | **fuga real** = A2 | `P4`/`P5`; la misma parcela dos veces en el mismo slot con dos soluciones |
| Parcelas preparadas con antelación | **no es fuga distinta**: es el insumo de la anterior | bifurcar por debajo de `T_j`; sin ganar `P5` no cambia el ancla |
| Rama privada nunca revelada | **fuga real, fuera del alcance de cualquier identidad** | la evidencia exige los **dos** bloques; su coste (retener la rama pierde `blue_work` durante la carrera) **no está medido** |
| Censura temporal de la prueba | **fuga real, de viveza** | el castigo de `CANDIDATA.md` §6 es prospectivo: exige que la prueba entre en la historia seleccionada |
| Beneficio > confiscable | **fuga real, económica** | la pérdida está topada por las recompensas retenidas más el lote |
| Clave robada o *pool* custodial | **no es fuga: es falso positivo con *griefing*** | `FALSOS-POSITIVOS.md` FP6 |

**Consecuencia que hay que aceptar y no maquillar.** `κ` es la fracción del doble farmeo **publicado**
que deja evidencia. Un atacante que sólo publique la rama ganadora no produce el par y **no hay regla
de identidad que lo alcance**. `derivado`, salvo la rentabilidad de retener, que es `no determinado`
(depende de `C-GD-11`, hoy `<<PENDIENTE>>`).

---

## P11 · Lo que queda sin determinar — `no determinado`

1. **La probabilidad de `P5`.** `α`, la varianza de carrera corta y la cola de A2 **no están
   medidas** en este trabajo ni, según su propia nota, en
   `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` §0.4 (P2b: «NO medido»).
   `veritas/seguridad/coste-rama-privada-v1/INFORME.md` mide el **umbral** (`α_mínimo = 1/2`) para
   una rama privada frente a la cadena completa, que es **otro** objeto que la carrera truncada de
   `P5`. No se traslada.
2. **La distribución de `δ`, `I`, `F`, `L_suelo`, `S_max`.** Son símbolos
   (`SPEC.md` §7.3; C-FLU-01; `<<PENDIENTE>>`).
3. **`C-GD-11`.** El contraejemplo fusiona bloques con `slot` muy anterior al de la punta. El valor
   de *bounded merge depth* **no está fijado** (`SPEC.md` C-GD-11, cinco `<<PENDIENTE>>`), así que
   **no se puede afirmar que el contraejemplo sea alcanzable en el consenso destino**: puede que
   `C-GD-11` lo rechace en cuanto tenga valor. Se dice aquí y en `DECISIONES-PENDIENTES.md`.
4. **El número de piezas/candidatas por slot** (la `m` del modelo) depende del retarget y del tamaño
   de parcela; **no se fija**.
5. **La unicidad de la prueba PoS.** `IDENTIDAD.md` §4 y `INFORME.md` §1 miden que **dos pruebas
   distintas del mismo `offset/seed/bucket` son aceptadas**. Que eso se pueda conseguir *a tiempo*
   y con qué coste **no está medido** allí y **no se mide aquí**.
