# DECISIONES-PENDIENTES — P-FLUJO

**Revisión 6 (2026-09-20), tras las ADENDAS 1, 2 y 3, la objeción del validador a la Prop. A y la decisión de D-F10.** Decisiones que **no
me tocaban** (encargo §5): cada una con **lo que gana**, **lo que paga** y **lo que cierra** cada
opción, y mi recomendación **marcada como tal**.

## Estado, de un vistazo

| # | Qué decide | Estado |
|---|---|---|
| Perfil | 1a (`L ≥ F`) | **RECONFIRMADO 2026-09-20.** Y en la revisión 5 gana un argumento nuevo: con `L < F` habría vía barata de forzar PoT ajeno (C-FLU-22 §5) |
| Suelo | `L_suelo_slots` en la atadura de `L` | **DECIDIDA 2026-09-20: sí, como símbolo** |
| **D-F1** | Contenido de la entropía de la inyección | **DECIDIDA 2026-09-20: A** |
| **D-F2** | Qué hash usa el identificador de flujo | **DECIDIDA 2026-09-20: A** (`H_d`, amplía C-HASH-06) |
| **D-F3** | De qué regla de finalidad cuelga la propuesta | **DECIDIDA 2026-09-20: C, acotada al enunciado** → C-FIN-01 |
| **D-F4** | Sentido de la desigualdad de la finalidad | **DECIDIDA 2026-09-20: A**, y son **dos** desigualdades |
| **D-F5** | Qué hace un nodo que sincroniza desde cero | **DECIDIDA 2026-09-20: mejorada** → C-FLU-18 + C-FLU-17 |
| **D-F6** | Cota de slot ampliada a todos los padres | **DECIDIDA 2026-09-20: A** |
| **D-F7** | Familia de IDs de la regla de finalidad | **DECIDIDA 2026-09-20: B** → `C-FIN-01` |
| **D-F8** | ¿Congelar la vista de época? | **DECIDIDA 2026-09-20: C**, no se congela → C-FLU-21 firme |
| **D-F9** | ¿Se adopta el flujo rival dentro de la ventana? | **DECIDIDA 2026-09-20: C**, con presupuesto → **C-FLU-22**; sustituye a DF-2 |
| **D-F10** | El presupuesto es **por par** y las identidades son gratis | **DECIDIDA 2026-09-20: B** → **C-FLU-23**, dos cotas y modo de fallo |

**Revisión 5 (2026-09-20), `ADENDA-3.md`.** La respuesta a la objeción queda **aceptada entera**,
incluida la retirada de la conclusión (c) (`ADENDA-3.md:4-5`).

**Revisión 6 (2026-09-20).** Katana decide también **D-F10 = B**. **D-F1…D-F10 están todas
decididas y NO queda ninguna decisión abierta.** Si al trasladar apareciera otra bifurcación, le
correspondería el número **D-F11**.

**Historia de la revisión 4, que conviene no perder:** la objeción del validador a la Prop. A era
correcta y alcanzaba además a la conclusión (c), que él no señaló. **La ventana de adopción no es
vacía.** Como DF-2 se había decidido con esa conclusión como motivo
(`/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:71-73`), volvió a la mesa como D-F9 y Katana la
sustituyó.

---

# PARTE I · DECIDIDAS

## Suelo de `L` — DECIDIDA por Katana el 2026-09-20

**Qué decidía:** si `L` queda atada a `F` **a secas** (`L_slots ≥ F_slots`) o con un **suelo**
independiente.

**La bifurcación la encontré yo al redactar la revisión 1** y la dejé como defecto anotado, no como
decisión; la adenda la convirtió en decisión y Katana la tomó (`ADENDA-1.md:19`).

**Decisión: sí, suelo.** `L_slots ≥ máx(F_slots, L_suelo_slots)`, combinado con la desigualdad de
D-F4. `L_suelo_slots` es un **parámetro de consenso simbólico**: **no lleva valor** en esta
propuesta.

- **Qué gana:** que la obligación de bajar `F` en producción (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:163`) no arrastre a `L` por debajo de
  lo medido. Sin suelo, `F = 1 h` daba `L_slots = 3 600`, por debajo de la extrapolación a `10⁻⁹`
  para `Δ` = 10-16 s (≈3 600-5 000, **estimado**, `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:28`).
- **Qué paga:** un parámetro de consenso más, que hay que calibrar y que **no se puede calibrar
  hoy**: su criterio exige una cota de `Δ` **medida en red real**, que no existe. Mientras tanto,
  `L` queda con un término que nadie puede fijar sin abrir la puerta a ponerle un número supuesto.
- **Qué cierra:** la lectura «`L` es simplemente `F`», que era la de DF-1 tal como se escribió el
  2026-09-19.

**Escrito en:** C-FLU-01, con el criterio de calibración y las cifras de referencia etiquetadas
`medido en simulación` / `estimado`, y con el aviso de que **ninguna de ellas es el valor**.

---

## D-F1 · Contenido de la entropía — DECIDIDA: opción A

**DECIDIDA por Katana el 2026-09-20 (`ADENDA-1.md:20`): opción A,**
`entropía_j = blake3(chunk(I_j) ‖ pot_output(I_j))`. **Coincide con mi recomendación.** El análisis
completo se conserva abajo como registro.

**Motivo añadido por Katana, y es más fuerte que el mío:** no atar §2.1 a la identidad del billete
(§2.2), **que además puede cambiar** si algún día se adopta un registro de parcelas contra el
sembrador. Eso convierte el acoplamiento de la opción B de hipotético en concreto: la investigación
del sembrador concluye que la única vía que cierra el ataque es **A1+C1**, «registrar antes del reto
una raíz/versionado/cardinalidad de la parcela exacta» (**verificado en fuente:**
`/home/katana/zeo/ZEROX/P-SEMBRADOR/investigacion/INFORME.md:13`) — es decir, precisamente un cambio
en lo que identifica una oportunidad.

**Opción A — `blake3(chunk(I_j) ‖ pot_output(I_j))`,** como Autonomys y R-FIN-2
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:212`;
la forma de Autonomys, en `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md:104-107`).

- **Gana:** coherencia con D-1 = A (`blake3` byte a byte, `SINTESIS.md:78`); se escribe hoy sin
  esperar a §2.2; y el invariante de no-equivocación (C-FLU-12.1) **queda demostrado** con lo que ya
  hay (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:218, 477`).
- **Paga:** **dos billetes distintos con el mismo `chunk` en el mismo slot y flujo dan la misma
  entropía.** No es el vector de equivocación, pero la entropía no distingue *quién* ancló, solo
  *qué chunk* ganó. **No he encontrado el ataque, y no encontrarlo no es cerrarlo.** Queda escrito
  en C-FLU-12.
- **Cierra:** atar §2.1 a la identidad del billete sin volver a tocar esta regla.

**Opción B — `blake3` sobre la identidad completa del billete** `(public_key, sector_index,
history_size, chunk, slot)` (R-FIN-11, `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:228`)
**más** `pot_output`.

- **Gana:** dos billetes distintos nunca dan la misma entropía; ata §2.2 con §2.1.
- **Paga:** obliga a cerrar §2.2 antes o a la vez, y §2.2 **puede cambiar** (el motivo de Katana).
  Además se separa de Autonomys donde hoy hay equivalencia byte a byte.
- **Cierra:** escribir §2.1 sin esperar a §2.2.

---

## D-F6 · Cierre de ancestros por slot — DECIDIDA: opción A

**DECIDIDA por Katana el 2026-09-20 (`ADENDA-1.md:21`): opción A,** ampliar la cota de slot a
**todos** los padres, `slot(p) ≤ slot(B)`, **no estricta**. **Coincide con mi recomendación.**

**Tres cosas que la decisión exige y que están escritas en C-FLU-02:**

1. **Consecuencia para la selección de padres (afecta a C-GD-10).** El productor descarta de la cola
   de candidatos toda punta de slot mayor que el suyo — mismo patrón que C-GD-10 ya usa para
   C-GD-11 (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1727-1729`). **Y C-FLU-02 hay
   que añadirla a la enumeración cerrada de C-GD-10** («mientras cumpla C-GD-04, C-GD-11 y
   C-HDR-05», `/home/katana/zeo/ZEROX/SPEC.md:1731-1733`), o la regla deja de ser materia de validez
   y el corte por slot vuelve a no ser cerrado por ancestros.
2. **Coste para el productor honesto: `estimado ≈ 0`, A CONFIRMAR con ANCLA-v0.2 antes de pasar al
   SPEC.** Magnitud a medir: fracción de bloques honestos que referenciarían un padre de slot mayor,
   con `Δ` = 0,5 / 4 / 16 s. El argumento por el que se estima ≈0 está en C-FLU-02; **es un
   argumento, no una medición**, y el régimen candidato `τ ≈ 0,1-0,17 s` no lo hereda solo.
3. **Qué toca:** C-HDR-05 en §6.1, C-GD-04/C-GD-10 en §11, `comprobar_diferencia_slots_del_bloque`
   en `/home/katana/zeo/ZEROX/crates/zx-core/src/wire_dag.rs:283-288`, y el trait `ContextoDag` de
   `/home/katana/zeo/ZEROX/crates/zx-consensus/src/bloque_dag.rs:141-170`, **que hoy no tiene forma
   de pedir el `slot` de un padre arbitrario**. Tabla completa en C-FLU-02.

**Lo que se descartó (opción B):** definir la vista por clausura de ancestros en vez de por corte de
slot. Ganaba no tocar C-HDR-05; pagaba una definición más cara y mucho más fácil de implementar mal,
y dejaba viva la anomalía de fondo en cualquier otra regla que corte por slot.

---

# PARTE II · DECIDIDAS POR LA ADENDA 2 (2026-09-20)

Las cuatro que la ADENDA 1 dejaba provisionales. La marca «PROVISIONAL» se ha retirado de las
reglas. El análisis de opciones se conserva íntegro como **registro de la decisión**.

## D-F3 · De qué regla de finalidad cuelga toda la propuesta — LA DECISIVA

> **DECIDIDA por Katana el 2026-09-20: opción C, ACOTADA AL ENUNCIADO**
> (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:10`). **Coincide con mi recomendación.** Una regla de
> finalidad **nueva en el SPEC**, en slots, con la semántica de R-FIN-7 —la punta incompatible **se
> ignora**, el proceso **no se detiene**—, con `F_slots` como **símbolo**. Escrita como **C-FIN-01**
> en §10.4 de `PROPUESTA-SPEC.md`.
>
> **El alcance es estricto y forma parte de la decisión: solo el enunciado.** NO entran, y quedan
> declarados pendientes en §10.4 y en el cierre de la propuesta: la reconciliación con el código que
> hoy **se detiene**, con `COINBASE_MATURITY` y con el **techo de archivado**. **`C-REORG-07` no se
> toca: es transitoria y sigue siéndolo.**
>
> **Bifurcación nueva que esto destapó: D-F7** (en qué familia de IDs vive una regla que no es de
> flujo). Abierta abajo, no resuelta.

**Qué decide:** si la ventana de adopción entre flujos es vacía (afirmación (c) del encargo §2) o
mide ≈1,33 h. Y, con ella, si DF-2 («no se añade regla de adopción») es una descripción de la
realidad o una laguna.

**El estado de partida — no determinado por el SPEC.** Existen dos reglas y el SPEC dice que no
están reconciliadas: «La regla temporal R-FIN-7 del diseño DAG y el límite transitorio `C-REORG-07`
deben reconciliarse al integrar consenso» (**verificado en fuente:**
`/home/katana/zeo/ZEROX/SPEC.md:2052-2053`) y «No se publican ambas reglas como simultáneamente
activas» (`/home/katana/zeo/ZEROX/SPEC.md:1903`).

**Opción A — colgar de R-FIN-7** (`F` segundos de slot; la punta incompatible **se ignora**;
`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:301-303`).

- **Gana:** la afirmación (c) queda **demostrada** y con un slot de margen (§0.2 y §10.2 de la
  propuesta); la magnitud es el **slot**, que es la misma en la que están `L`, `T_j`, `t_j` y
  `S_max`, así que la comparación no necesita `λ` ni ningún reloj físico; y la semántica «ignorar,
  no apagar» es la única compatible con un nodo que ve la punta rival de otro flujo todos los días
  durante una partición.
- **Paga:** R-FIN-7 vive en `research/`, que es **evidencia histórica, no texto normativo**
  (**verificado en fuente:** `/home/katana/zeo/ZEROX/research/README.md:7-10`). Elegir A obliga a
  **redactarla en el SPEC** antes de que `C-FLU-*` pueda apoyarse en ella, y a retirar o subordinar
  `C-REORG-07`, que hoy **sí** tiene código (`MAX_REORG_LENGTH` en
  `/home/katana/zeo/ZEROX/crates/zx-consensus/src/lib.rs:33` y usado en
  `/home/katana/zeo/ZEROX/crates/zx-node/src/cadena.rs:319-320`). Y `F = 2 h` sigue **provisional**
  (`/home/katana/zeo/ZEROX/SPEC.md:1436`), así que se estaría atando `L` a un número que va a
  cambiar.
- **Cierra:** la lectura en bloques. Una vez la finalidad está en slots, volver a bloques exige
  meter `λ` en el consenso.

**Opción B — colgar de `C-REORG-07`** (`MAX_REORG_LENGTH = 11 999` bloques, fail-stop;
`/home/katana/zeo/ZEROX/SPEC.md:1891-1903`).

- **Gana:** es la regla del **SPEC vivo** y la única con código hoy. Cero trabajo de redacción para
  empezar.
- **Paga (y es caro): la afirmación (c) del encargo pasa a ser FALSA.** Con `λ` nominal, 11 999
  bloques ≈ **3,33 h** (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:1902`) frente a
  `L ≈ F = 2 h`: la ventana de adopción mide ≈1,33 h y DF-2 deja un hueco en vez de describir un
  vacío. Además la semántica es **fail-stop** —«Quien lo reciba **MUST** detener el nodo y avisar al
  operador, no reintentar», **verificado en fuente:**
  `/home/katana/zeo/ZEROX/crates/zx-node/src/cadena.rs:318-320`—, es decir que una partición de
  flujo **apaga la mitad de la red** en vez de dejarla funcionando en su rama. Y mezcla unidades:
  bloques contra slots, conversión por `λ`, que es lo que estima el retarget.
- **Cierra:** la demostración de §0.2 tal como está escrita, y con ella el argumento de DF-2.

**Opción C — escribir una regla nueva en el SPEC, en slots, con la semántica de R-FIN-7 y el número
por decidir.**

- **Gana:** la reconciliación que el SPEC pide, hecha una vez y bien; `F_slots` como símbolo
  explícito; `C-REORG-07` se retira a lo que dice ser, «límite heredado … para identificar el estado
  transitorio del código» (`/home/katana/zeo/ZEROX/SPEC.md:1891, 1897`).
- **Paga:** es una regla de §7/§13 que **no es mía** y que arrastra la calibración de `F`, hoy
  abierta (`/home/katana/zeo/ZEROX/SPEC.md:1436-1438`).
- **Cierra:** nada que no estuviera ya abierto.

**Recomendación (mía): C**, con la semántica y la magnitud de A. **Motivo:** A es correcta pero
apoya reglas del SPEC en un documento que el propio repositorio declara no normativo; B es
utilizable hoy pero rompe la conclusión que DF-2 da por buena y, peor, convierte una partición de
flujo en una parada de nodo. Si Katana prefiere no abrir §13 ahora, **A es aceptable como interina**,
con la condición de que `C-FLU-01` deje `F_slots` como símbolo y no se publique ninguna cifra de
ventana de adopción.

---

## D-F2 · Qué hash usa el identificador de flujo (`H_flujo`)

> **DECIDIDA por Katana el 2026-09-20: opción A** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:9`).
> **Coincide con mi recomendación.** `H_flujo := H_d = SHA3-256(etiqueta ‖ m)` con **etiqueta nueva
> de 16 bytes**. Propuestas: `ZZKFlowId_______` (C-FLU-10) y `ZZKFlowGenesis__` (C-FLU-06); los
> nombres se pueden cambiar en el traslado sin tocar ninguna demostración.
>
> **Consecuencia que hay que ejecutar: AMPLIAR C-HASH-06**, hoy declarada lista **cerrada** de 14
> etiquetas (**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:560-561, 569-584`). Eso es
> una edición de §4.5 que **esta propuesta no ha hecho** (fuera de zona).
>
> **Y dos cosas que NO cambian, para que el traslado no las «uniforme»:** el resto del dominio PoT
> sigue en `blake3` (D-1 = A), y `semilla(f_0, 0)` de C-FLU-06 **también** sigue en `blake3`, porque
> ahí sí hay oráculo externo —es la derivación de Autonomys, verificada en fuente—. Las dos líneas
> de C-FLU-06 usan hashes distintos **a propósito**.

**Qué decide:** `H_flujo` en C-FLU-10 y `ETIQUETA_GENESIS` en C-FLU-06. Es un objeto **propio de
ZEROX**, no de Autonomys: no existe oráculo externo que conservar.

**Opción A — `H_d = SHA3-256(etiqueta ‖ m)` con etiquetas nuevas de 16 bytes.**

- **Gana:** separación de dominio explícita y coherencia con la convención del SPEC. El
  identificador de flujo es un valor que se compara byte a byte en toda la validación estructural
  (C-FLU-14); tener su dominio separado del de los txid, sellos y cuerpos es exactamente para lo que
  existe C-HASH-06.
- **Paga:** **C-HASH-06 declara una lista CERRADA** — «Estas son **todas** las etiquetas de dominio
  de ZEROX v1.0. Cada una mide exactamente 16 bytes» (**verificado en fuente:**
  `/home/katana/zeo/ZEROX/SPEC.md:560-561`), con 14 entradas hoy
  (`/home/katana/zeo/ZEROX/SPEC.md:569-584`). Añadir `ZZKFlowId______` y `ZZKFlowGenesis__`
  **obliga a ampliar esa lista**, que es una regla que no es mía.
- **Cierra:** reutilizar sin más las primitivas del PoT.

**Opción B — `blake3`,** como el resto del dominio PoT tras D-1 = A.

- **Gana:** un solo hash en todo el dominio PoT/flujo; ninguna regla ajena que ampliar; el nodo ya
  tiene `blake3` en la ruta caliente por C-POT-01/02/03.
- **Paga:** el identificador de flujo queda **sin etiqueta de separación de dominio**. Las entradas
  tienen longitudes fijas (`32 ‖ 32 ‖ 8` bytes), así que no hay ambigüedad de concatenación, pero sí
  se pierde el tag. Es la misma factura que D-1 = A ya aceptó para el PoT
  (`/home/katana/zeo/ZEROX/P-POT/propuesta/DECISIONES-PENDIENTES.md:27-30`), extendida a un objeto
  que **no** tiene la excusa del oráculo diferencial.
- **Cierra:** nada irreversible; cambiar después solo invalida vectores propios.

**Recomendación (mía): A.** **Motivo:** el argumento que ganó D-1 = A fue conservar la validación
externa byte a byte contra Autonomys. **Aquí ese argumento no existe**: el identificador de flujo no
tiene contraparte en Autonomys. Sin oráculo que proteger, la razón para romper C-HASH-06 desaparece
y queda solo la comodidad. El coste real de A es una sola cosa —ampliar una lista declarada
cerrada—, y esa ampliación es una decisión de Katana que hay que tomar igualmente en algún momento
para cualquier objeto nuevo de v1.0.

---

## D-F4 · El sentido de la desigualdad de la finalidad (borde `L = F`)

> **DECIDIDA por Katana el 2026-09-20: opción A** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:11`).
> **Coincide con mi recomendación.** Y al escribirla explícita salieron **dos** desigualdades, no
> una, porque este diseño tiene dos bordes y solo uno estaba en la pregunta:
>
> - **(α)** reorganización prohibida ⟺ `d ≥ F_slots` — **C-FIN-01**;
> - **(β)** inyección `j` en vigor ⟺ `s ≥ t_j`, borde **inclusivo** en `t_j` — **C-FLU-07**.
>
> Las dos quedan escritas en §10.2 de `PROPUESTA-SPEC.md`, con la fuente de (β) verificada
> (R-FIN-14(a) aplica la re-siembra «si `s = t_j`»; R-FIN-2 dice que «antes de `t_j` la entropía no
> se mezcla»). **La demostración del borde se conserva intacta** y con (α) sobra un slot: el Lema 1
> da `d ≥ L+1`, así que el borde no llega a morder con **ninguna** de las dos lecturas.

**Qué decide:** si «no reorganizar **por debajo de `F`**» prohíbe `d > F_slots` o `d ≥ F_slots`.

**El estado de partida:** R-FIN-7 dice «por debajo de `F` segundos de slot»
(**verificado en fuente:** `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:301-302`) y
**no fija el sentido**. **No determinado por el SPEC.**

**Para esta propuesta, el borde no muerde: está cerrado sin margen.** Por el Lema 1 la bifurcación
está estrictamente por debajo de `T_j`, luego en `t_j` la profundidad es `d ≥ L_slots + 1`, y con
`L = F` eso es `≥ F_slots + 1 > F_slots`: **prohibido con cualquiera de las dos lecturas**
(demostrado, §10.2 de la propuesta). **No hace falta `L ≥ F + algo`.**

**Aun así hay que elegir**, porque R-FIN-7 se usa en otros sitios donde no hay un Lema 1 regalando
un slot.

- **Opción A — prohibir `d ≥ F_slots`** (la lectura conservadora). **Gana:** el caso exacto queda
  del lado seguro sin discusión. **Paga:** un slot de finalidad efectiva. **Cierra:** nada.
- **Opción B — prohibir `d > F_slots`.** **Gana:** literalidad («por debajo de `F`» = «más hondo que
  `F`»). **Paga:** hay que comprobar, regla por regla, que ningún otro uso de R-FIN-7 dependa del
  caso exacto. **Cierra:** nada.

**Recomendación (mía): A.** **Motivo:** cuesta un slot sobre `F_slots = 7 200` y elimina para
siempre una clase de discusión de borde. Es el mismo criterio con el que el repositorio ya cerró la
monotonía de slot: R-FIN-1a se fijó **no estricta** y se dijo explícitamente que «la frase anterior
"mayor o igual" era un residuo superado» (**verificado en fuente:**
`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:203-205`) — los bordes se escriben, no
se deducen.

---

## D-F5 · Qué hace un nodo que sincroniza desde cero ante dos flujos

> **DECIDIDA por Katana el 2026-09-20, y MEJORADA respecto de mi recomendación**
> (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:12`). Yo recomendaba «no legislar ahora»; Katana
> decide **escribir explícitamente la conducta**, que es mejor, y tiene razón en el motivo: **no es
> un mecanismo nuevo, es cerrar un hueco de redacción** para que dos clientes no lo implementen
> distinto. Se cierra con **dos** reglas:
>
> - **C-FLU-18 (nueva):** un nodo **sin cadena previa aplica la selección ordinaria de GHOSTDAG**
>   (mayor `blue_work`, reglas C-GD vigentes), y la regla de finalidad **solo obliga a quien ya
>   tiene una cadena que reorganizar**. Demostrado que ya se sigue de las reglas vigentes; lo que
>   aporta la regla es **decirlo**.
> - **C-FLU-17 (de la ADENDA 1, se mantiene):** el nodo **detecta** que ha quedado fuera del flujo
>   mayoritario y **lo señala**. Comportamiento de nodo, no validez de bloque.
>
> **Alcance escrito en C-FLU-18, con lo que acota y lo que no:** en el caso realista (minoría
> aislada) el recién llegado cae en el lado **mayoritario**; el largo alcance está acotado por la
> **secuencialidad del PoT** (C-POT-03/R-FIN-14(e)); y en el arranque, por los checkpoints
> **C-CHK**, que se **citan y no se amplían**. **Lo que no acota:** tras `ALTURA_CADUCIDAD` y con
> una partición viva, el nodo nuevo va al más pesado del momento, que puede ser el minoritario.
> **La conducta queda determinista y única; no queda acertada.**
>
> **Lo que sigue siendo encargo aparte:** la regla objetiva «el flujo canónico es el que lideraba en
> `t_j + F_slots`» (opción C de abajo), con su resistencia a bloques con slots antiguos por
> estudiar.

**Qué decide:** la mitad del canal dominante según la medición. DF-3 lo redujo a «declarar», pero
**la declaración no le da ninguna regla al recién llegado**: R-FIN-7 acota cambios de *su* cadena
seleccionada, y él no tiene ninguna que cambiar (§8 de la propuesta).

**Por qué vuelve a la mesa, pese a DF-3.** `P-2.1` lo clasifica como uno de «dos huecos de redacción
[que] dominan el resultado, y son texto, no cálculo … Cerrar cualquiera de los dos apaga el canal
dominante» (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:41-43`), y mide la
rendija: «el que sincroniza después: toma el líder del momento; con deriva nula discrepa de los
veteranos con probabilidad → 1 mientras el flujo perdedor siga vivo»
(**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:35-36`). **Lo elevo porque es
una bifurcación real que encontré (encargo §5, último punto), no para reabrir DF-3.**

**Opción A — no legislar** (estado actual de DF-3). **Gana:** cero reglas nuevas; coherente con
«una partición es un fallo, no un estado que el protocolo gestione». **Paga:** durante una partición
**todo** nodo nuevo es una moneda al aire, y con reparto simétrico la probabilidad de discrepar de
los veteranos tiende a 1. **Cierra:** nada.

**Opción B — extender el mecanismo de checkpoint que el SPEC ya tiene** (C-CHK-01…07,
`/home/katana/zeo/ZEROX/SPEC.md:1987-2014`). **Gana:** el mecanismo existe y «fija la rama canónica»
(`:2000-2002`). **Paga:** hoy hay **un único** checkpoint en la vida de la cadena (`:1987-1988`) y
**caduca** en `ALTURA_CADUCIDAD` (`:1997-1998`); usarlo aquí obliga a romper una de las dos
propiedades, y eso es subjetividad débil recurrente, no el compromiso que C-CHK-01 describe.
**Cierra:** la promesa de «un solo checkpoint».

**Opción C — regla objetiva: el flujo canónico es el que lideraba en el slot `t_j + F_slots`.**
Es la que `SINTESIS.md:58` propone estudiar. **Gana:** computable por cualquiera **después** del
hecho, sin autoridad ni subjetividad; y `t_j + F_slots` es justo el instante en que R-FIN-7 congela
a todos a la vez. **Paga:** «hay que estudiar su resistencia a bloques fabricados con slots
antiguos» (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:58`); y bajo 1a el
instante `t_j + F_slots` cae **después** de que la ventana de adopción ya esté cerrada, así que la
regla solo sirve al recién llegado, no a los veteranos — hay que comprobar que eso no crea una
tercera clase de nodo. **Cierra:** nada hasta que se estudie.

**Recomendación (mía): dejar A como está para la v1 del texto y encargar C por separado**, con la
resistencia a slots antiguos como objeto del encargo. **Motivo:** A es lo que Katana decidió y no
bloquea la redacción de `C-FLU-*`; pero la medición dice que es el canal dominante, así que dejarlo
sin plan es aceptar el número más grande de la tabla sin contrapartida. B no sirve: el checkpoint es
un mecanismo de lanzamiento, no de partición.


**Actualización de la revisión 2:** el validador acepta «no legislar ahora, estudio aparte»
(`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md:35-37`) y añade la **regla operativa mínima**, que
queda escrita como **C-FLU-17**.

**Actualización de la revisión 3 — SUPERA a la anterior.** Katana no se queda en «no legislar»:
decide **escribir la conducta** (C-FLU-18). Mi recomendación de la revisión 1 («dejar A como está»)
queda **superada por una opción mejor**, y lo digo como lo que es: la opción A que yo recomendaba
dejaba la conducta **implícita**, y una conducta implícita en dos clientes es un fork latente. La
opción C (el flujo canónico es el que lideraba en `t_j + F_slots`) **sigue** siendo mi
recomendación para el **encargo separado**; C-FLU-18 no la sustituye —una fija qué hace el nodo hoy,
la otra sería una regla objetiva de selección— y la resistencia a bloques con slots antiguos sigue
sin estudiar.

---

## D-F7 · registro de opciones — DECIDIDA: B, familia `C-FIN` (arriba)

**Bifurcación nueva**, aparecida al redactar C-FIN-01. La abro en vez de resolverla, como manda
`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:19-20`.

**Qué decide:** con qué ID entra en el SPEC la regla de finalidad de D-F3. La he escrito como
`C-FIN-01` **por comodidad de este documento**, y probablemente esté mal: `C-FLU-NN` es la familia
del **flujo**, y una regla de finalidad **no es una regla de flujo** — es una regla que el flujo
*usa*, y que gobierna reorganizaciones con o sin flujos de por medio.

**Opción A — dejarla en `C-FIN-01`.** **Gana:** cero trabajo; la regla viaja con el resto de la
propuesta y su dependencia con §0.2 queda visible. **Paga:** un ID que miente sobre el alcance de la
regla; cualquiera que busque la finalidad no la encontrará en la familia del flujo, y cualquiera que
retire la familia del flujo se llevará la finalidad por delante. **Cierra:** nada técnico, pero fija
un nombre que luego cuesta cambiar — `TAREAS.md` §4.2 exige IDs **estables** y prohíbe reutilizar
retirados (**verificado en fuente:** `/home/katana/zeo/ZEROX/TAREAS.md:653-654`), así que renombrar
después **gasta un ID**.

**Opción B — familia propia, p. ej. `C-FIN-01`.** **Gana:** el ID dice lo que la regla es; la
finalidad queda donde se la buscará (§7/§13, junto a `C-REORG-07` y a la reconciliación pendiente de
`/home/katana/zeo/ZEROX/SPEC.md:2050-2053`). **Paga:** abrir una familia nueva es una decisión de
nomenclatura que **no es mía**, y hay que declararla en `ci/reglas-sin-codigo.txt` igual que
cualquier otra (`/home/katana/zeo/ZEROX/TAREAS.md:655-656`). **Cierra:** nada.

**Opción C — reutilizar el hueco de `C-REORG`,** p. ej. `C-REORG-08`. **Gana:** queda pegada a la
regla que sustituye, que es donde el SPEC ya dirige al lector. **Paga:** `C-REORG-07` es
explícitamente **transitoria** y la decisión de D-F3 dice **no reconciliarla**; meter la regla nueva
en su familia sugiere una reconciliación que no se ha hecho. **Cierra:** la separación limpia entre
«lo heredado» y «lo del DAG».

**Recomendación (mía): B.** **Motivo:** es el único ID que no miente, y el coste es una decisión de
nomenclatura que hay que tomar una vez. A es cómoda hoy y cara luego, porque renombrar un ID
estable gasta uno. C acerca la regla nueva a la transitoria justo cuando la decisión ha sido
mantenerlas separadas.

---

# PARTE IIbis · DECIDIDAS POR LA ADENDA 3 (2026-09-20)

Las tres que la revisión 4 dejó abiertas. **La respuesta a la objeción queda aceptada entera,
incluida la retirada de la conclusión (c)** (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-3.md:4-5`). El
análisis de opciones se conserva íntegro como registro.

## D-F7 · Familia de IDs de la regla de finalidad — DECIDIDA: opción B

**DECIDIDA por Katana el 2026-09-20 (`ADENDA-3.md:9`): opción B, familia propia `C-FIN`.**
**Coincide con mi recomendación.** `C-FLU-19` → **`C-FIN-01`**, renombrada en los tres entregables
(16 apariciones en `PROPUESTA-SPEC.md`, 7 en este archivo, 3 en `PROGRESO.md`). Familia declarada en
el índice de §11, con el mismo régimen que `C-FLU`: IDs nuevos y estables
(`/home/katana/zeo/ZEROX/TAREAS.md:653-654`) y declaración en `ci/reglas-sin-codigo.txt` al
trasladar (`:655-656`), que esta propuesta **no ha tocado**.

**Lo que se descartó:** A (dejarla en `C-FLU-19`, un ID que miente sobre el alcance y que renombrar
después gasta un ID estable) y C (`C-REORG-08`, que la pegaría a la regla transitoria justo cuando
la decisión ha sido mantenerlas separadas).

---

## D-F8 · ¿Congelar la vista de época? — DECIDIDA: opción C, no se congela

**DECIDIDA por Katana el 2026-09-20 (`ADENDA-3.md:10`): opción C.** **Coincide con mi
recomendación.** `C-FLU-03` queda como está y **C-FLU-21 pasa a regla propuesta firme**.

**El motivo queda escrito en C-FLU-21 para que no se vuelva a proponer sin verlo:** congelar la
vista en el bloque que cruza el corte **reabre E1**. Determinar el bloque puerta exige la cadena
seleccionada hasta `slot(G) ∈ [T_j + L_slots, T_j + L_slots + S_max_slots)` y por tanto el flujo de
bloques que pueden tener `slot ≥ t_j`, porque `t_j < T_j + L_slots + S_max_slots`: **para decidir la
inyección `j` haría falta la inyección `j`**, en una franja de anchura `≤ S_max_slots`. Es E1 otra
vez (`/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md:83`), más estrecha y de la
misma clase. Y compraba poco: adelantaba la congelación `≤ 150` slots sobre una carrera de `≥ 7 200`.

---

## D-F9 · La adopción dentro de la ventana — DECIDIDA: opción C; **DF-2 queda sustituida**

**DECIDIDA por Katana el 2026-09-20 (`ADENDA-3.md:11`): opción C, adopción con presupuesto.**
**Coincide con mi recomendación**, que era lo contrario de la que yo mismo di el 2026-09-19 — porque
mi motivo entonces era un teorema que no se sostiene.

**Escrita como C-FLU-22**, con los siete puntos que la adenda exige. Lo que salió al redactarla y no
estaba previsto:

- **La anchura de la ventana depende de cómo nació la partición** (demostrado): `[t_j, slot(P) +
  F_slots)`, máxima (`F_slots − 1`) en el nacimiento espontáneo y **vacía** en un corte de red más
  largo que `L`. Eso une el punto 1 con el punto 6 de la adenda: **la regla cura el caso improbable
  y no cura el grave.**
- **El DoS queda DEMOSTRADO, no supuesto** (C-FLU-22 §5): forzar AES ajeno exige la vía (a), que es
  A2; la vía (b) —omitir el ancla honesta— es **imposible dentro de la ventana**, y la prueba usa
  `L_slots ≥ F_slots`. **Es un argumento nuevo a favor del perfil 1a**, independiente de los de
  `P-2.1`: con `L < F` la vía (b) cabría y habría un camino barato de forzar verificación ajena.
- **R-FIN-5 cambia de motivo**, con la frase exacta escrita (C-FLU-22 §4).
- **Corrección en cadena:** C-FLU-15 y §0.4 decían «una partición no tiene cura en el protocolo».
  Ya no es exacto. **(b) de §0.5 queda retirada a la letra.**

---


# REGISTRO DE OPCIONES — las tres decisiones de arriba, con su análisis completo

Se conserva tal como se escribió antes de que Katana decidiera, porque es el registro de por qué se
decidió así. **Ninguna de las tres sigue abierta.**

## D-F9 · registro de opciones — DECIDIDA: C (arriba)

**Qué pasó.** DF-2 («no se añade ninguna regla de adopción entre flujos») se decidió el 2026-09-19
con este motivo escrito: «Bajo 1a la ventana de adopción es `F − L ≤ 0`: flujos distintos implican
una divergencia de cadena de profundidad `≥ L ≥ F`, que la finalidad ya manda ignorar»
(**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:71-73`). La misma nota decía
que era «razonamiento de Claude, sin revisar: va como afirmación a demostrar o refutar en
`P-FLUJO/`» y declaraba **superado** el análisis de PCO-v0.1 (`:74-76`).

**La afirmación era falsa.** La demostré mal (cambio de objeto entre `Chn(V_j)` y la cadena del
nodo, §0.2). **La ventana de adopción mide ≈ `F_slots`, no cero**, que es lo que PCO-v0.1 ya había
establecido y `SINTESIS.md:30-31` ya decía. **El análisis de PCO no estaba superado.**

**Qué hay que decidir ahora.**

**Opción A — mantener DF-2 tal cual (ninguna regla de adopción).** **Gana:** ninguna regla nueva;
R-FIN-5 conserva su virtud y no se paga verificación de PoT ajeno. **Paga:** la ventana existe y
**nadie ha escrito qué hace el nodo dentro de ella**. Por defecto actúa la selección de cadena
ordinaria, que ante una punta rival más pesada a profundidad `< F_slots` **la adopta** — es decir,
DF-2 no describe lo que pasa, solo se abstiene de legislarlo. Dos implementaciones pueden diferir:
es un **fork latente** del tipo que persigue el Nivel 1 de `TAREAS.md`. **Cierra:** la resolución de
la partición en `t_j + F` que PCO-v0.1 medía.

**Opción B — prohibir explícitamente cruzar de flujo dentro de la ventana.** **Gana:** DF-2 pasa de
abstención a regla; conducta única; cero verificación de PoT ajeno; (b) de §0.5 se sostiene otra
vez, ahora por regla y no por un teorema falso. **Paga:** la partición pasa a ser **permanente de
verdad** (hoy solo lo es después de `t_j + F`), y se renuncia a la resolución que PCO medía con
rendija ≤ ~1 %. Es una regla de flujo que altera la selección de cadena ordinaria: hay que escribir
qué hace un nodo ante una punta más pesada que no puede adoptar, y encaja con C-FIN-01 («se
ignora»). **Cierra:** cualquier recuperación automática.

**Opción C — permitir la adopción dentro de la ventana, con presupuesto.** Es la opción que la tabla
original de DF-2 recomendaba antes de mi razonamiento: «**Sí:** la partición entre veteranos se
resuelve en `t_j + F` (rendija ≤ ~1 %); paga verificar PoT ajeno durante esa ventana — acotado por
presupuesto, que da `Pendiente` y nunca `Inválido` (C-POT-07) — y obliga a reescribir el motivo de
R-FIN-5» (**verificado en fuente:** `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md:57`). **Gana:** la
partición **se cura** a las `F` con las dos rendijas medidas (desfase de vista 0,27-1,5 %; el que
sincroniza después), en vez de quedarse para siempre. **Paga:** verificación de PoT de flujo ajeno
durante la ventana, con su superficie de DoS; reescribir el motivo de R-FIN-5; y §0.4, C-FLU-15 y
«prevención, no recuperación» dejan de ser ciertos tal como están escritos. **Cierra:** la
afirmación (b).

**Recomendación (mía): C**, y digo por qué cambiando lo que yo mismo recomendé. Mi argumento para
DF-2 fue que la ventana no existía; **existe**. Con la ventana abierta, A no es «no legislar»: es
dejar sin escribir la conducta por defecto, que es la peor de las tres porque no elige nada y
permite que dos clientes difieran. Entre B y C: B compra simplicidad al precio de convertir cada
partición en permanente, y la partición **puede nacer sin que nadie se porte mal** (§0.3), así que
el precio lo paga la red honesta. C recupera el único mecanismo de recuperación que este diseño ha
tenido nunca, y su coste —PoT ajeno con presupuesto— ya está acotado por `C-POT-07`, que garantiza
`Pendiente` y nunca `Inválido`. **Si Katana elige B**, hay que reescribir §0.4 y C-FLU-15 para que
digan que la permanencia la produce **la regla nueva**, no la finalidad.

---

## D-F8 · registro de opciones — DECIDIDA: C, no se congela (arriba)

**Qué decide.** Si `V_j` se calcula sobre `past(B)` —que **crece** cuando `B` fusiona bloques
viejos— o sobre el pasado de un bloque fijo.

**Opción A — dejar C-FLU-03 como está** (`V_j(B) = (past(B) ∪ {B}) ∩ {slot < T_j + L_slots}`).
**Gana:** bien fundada por inducción sobre `j`, con la prueba ya escrita y sin ninguna
circularidad; corte que depende solo de `j` y de las constantes. **Paga:** `V_j` **crece sin
reorganización** al fusionar bloques retenidos, que es la vía A2 de §0.4 — y la única defensa antes
de `t_j` es la carrera de `blue_work`, **no medida**. **Cierra:** nada.

**Opción B — congelar: `G_j(B)` := el primer bloque de la cadena seleccionada de `B` con
`slot ≥ T_j + L_slots`, y `V_j(B) := past(G_j(B)) ∩ {slot < T_j + L_slots}`.**
**Gana:** `past(G)` es **inmutable**, así que la vista deja de crecer y **la vía A2 por fusión
desaparece por completo**: cambiar el ancla pasa a exigir cambiar `G`, que es una reorganización
real de la cadena y sí la toca la finalidad. Además el ancla queda como función de **un solo
bloque**, que ayuda al cliente ligero y a la disponibilidad tras poda (hoy declarada pendiente).
**Paga — y esto es lo caro: reabre E1, en versión acotada.** Determinar `G` exige la cadena
seleccionada de `B` hasta `slot(G) ∈ [T_j + L_slots, T_j + L_slots + S_max_slots)`, y por tanto la
validez —y el flujo— de bloques que pueden tener `slot ≥ t_j`, porque
`t_j < T_j + L_slots + S_max_slots`. Es decir: **para decidir la inyección `j` haría falta la
inyección `j`**, en una franja de anchura `≤ S_max_slots`. No he encontrado forma de colocar la
puerta que evite esa franja: por debajo de `T_j + L_slots` no cubre la ventana, y por encima entra
en territorio de `t_j`. **Cierra:** la buena fundamentación tal como está demostrada en C-FLU-04, que
es lo que E1 llevaba pidiendo desde 2026-09-07 y que esta propuesta acaba de cerrar.

**Opción C — no congelar, y escribir la herencia explícita (C-FLU-21).** **Gana:** desde `t_j` el
ancla deja de recalcularse y se transporta, así que la deriva por fusión se detiene **en el mismo
punto en que B la detendría**, sin tocar la buena fundamentación y sin circularidad. Abarata el
paso 1b de §7. **Paga:** **no arregla nada antes de `t_j`** — la carrera A2 sigue íntegra, porque
B tampoco la arregla del todo (B mueve el punto de congelación de `t_j` a `slot(G)`, que está como
mucho `S_max` slots antes). **Cierra:** nada.

**Recomendación (mía): C, ya escrita como C-FLU-21; B solo si alguien encuentra una puerta sin
franja.** **Motivo:** B parece comprar mucho y compra poco: adelanta la congelación en `≤ S_max`
slots —150 frente a los `L ≥ 7 200` que dura la carrera— y a cambio devuelve la circularidad que
costó dos rondas cerrar. La diferencia real entre B y C es de `S_max` slots de una carrera de `L`;
la diferencia en riesgo de diseño es entre «bien fundada, demostrado» y «circular en una franja».
**No es un intercambio que yo tomaría, pero la decisión es de Katana**, y si elige B hay que
rehacer C-FLU-03, C-FLU-04 y su demostración de buena fundamentación enteras.


---

# PARTE IV · DECIDIDA POR KATANA (2026-09-20, revisión 6)

## D-F10 · El presupuesto de verificación — DECIDIDA: opción B

**DECIDIDA por Katana el 2026-09-20: opción B** — presupuesto **por par Y cota global por nodo e
intervalo**, con el **modo de fallo escrito** y el valor **como símbolo**. **Coincide con mi
recomendación, incluida la insistencia en escribir el modo de fallo.** Redactada como **C-FLU-23**.

**Lo que salió al redactarla y no estaba en la decisión:**

- **La calibración es una pinza, no un número.** Si `PRESUP_NODO` es demasiado pequeño, **deroga
  D-F9 en la práctica**: la adopción no llega a completarse nunca y la decisión queda anulada sin
  que nadie la revoque. La cota inferior sale del peor caso, `F_slots × 92 ms` ≈ 11 min de CPU. La
  superior no está derivada.
- **Una tercera rendija, no medida.** Dos nodos con el mismo DAG pueden acabar en flujos distintos
  porque uno pudo pagar la verificación dentro de la ventana y el otro no — y **está parcialmente
  bajo control del atacante**, que gasta presupuesto ajeno con tráfico barato del paso 1b.
- **Nota de numeración, sin abrir decisión:** `C-FLU-23` es una **enmienda a C-NET-32.3**, no una
  regla de flujo; por el criterio que Katana fijó en **D-F7**, el traslado debería numerarla en
  `C-NET`. El criterio ya está decidido: lo señalo y no abro D-F11.

**El análisis de opciones se conserva abajo como registro de la decisión.**

### Registro de opciones

**Bifurcación nueva**, aparecida al demostrar el DoS de C-FLU-22 §5. La abro sin resolverla, como
manda `/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-3.md:42-43`.

**Qué decide.** Si el presupuesto que acota la verificación bajo demanda —y ahora también el paso 1b
y la adopción de C-FLU-22— se cuenta **solo por par** o **también globalmente por nodo**.

**El estado de partida.** C-NET-32.3 lo acota «por par y por intervalo, en el espíritu de C-NET-04»
(**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:3005-3006`), y su valor es un
`<<PENDIENTE>>` declarado (`:3007-3009`). El repositorio tiene **demostrado** que **las identidades
son gratis por diseño** (**verificado en fuente:**
`/home/katana/zeo/ZEROX/research/dag-poas-balizas-auditoria.md:68-75`). Un atacante con `N`
conexiones obtiene `N` presupuestos.

**Lo que NO cambia, y hay que decirlo para no exagerar el hallazgo:** esto **no abarata el disparo**.
Para que se gaste un solo ciclo de AES ajeno sigue haciendo falta la vía (a) de C-FLU-22 §5, es
decir ganar la carrera A2. Lo que `N` multiplica es **el techo**: el trabajo del paso 1b, que no
depende de ganar nada, y el AES una vez disparado.

**Opción A — dejarlo por par (estado actual).** **Gana:** cero cambios; es el espíritu de C-NET-04 y
el mismo criterio que el resto de la capa de red. **Paga:** el techo de trabajo por nodo es
`N × presupuesto`, con `N` bajo control del atacante y sin coste para él. **Cierra:** nada.

**Opción B — mantener el presupuesto por par Y añadir una cota global por nodo e intervalo.**
**Gana:** el techo deja de depender de `N`; la asimetría atacante/defensor se acota por
construcción, que es el criterio declarado de C-NET-06
(**verificado en fuente:** `/home/katana/zeo/ZEROX/SPEC.md:2530-2531`). **Paga:** un parámetro más
que calibrar, y un modo de fallo nuevo: agotada la cota global, un nodo honesto puede quedarse sin
poder adoptar durante el intervalo — lo que con C-FLU-22 significa **quedarse en su flujo**. Eso
**MUST** dar `Pendiente` y reintento, nunca `Inválido` (C-POT-07); si no, un atacante que agote la
cota global de una mitad de la red la deja anclada en el flujo perdedor. **Cierra:** nada.

**Opción C — cota global, y prioridad por profundidad de la reorganización candidata.** **Gana:** lo
de B, y además el gasto se dedica primero a la rama que más importa (la más cercana a cerrar su
ventana). **Paga:** una política de prioridad es superficie nueva; mal hecha, es un vector para que
el atacante decida en qué gasta el defensor. **Cierra:** nada.

**Recomendación (mía): B, con el modo de fallo escrito.** **Motivo:** el hallazgo es de techo, no de
probabilidad, y una cota global es la respuesta proporcionada. C es prematura: sin el valor de B
calibrado —que es un `<<PENDIENTE>>` del SPEC— una política de prioridad optimiza algo que todavía
no está dimensionado. **Y el modo de fallo de B no es menor:** hay que escribir explícitamente que
agotar la cota deja al nodo **donde está**, con `Pendiente`, porque bajo C-FLU-22 «no adoptar» ya
no es neutro.

---

# PARTE V · ABIERTO Y NO ES DECISIÓN DE KATANA HOY

**D-F7 (arriba) es la única decisión abierta.** Lo siguiente **no** son bifurcaciones que Katana
pueda resolver eligiendo: son cosas que **faltan por medir o por demostrar**, y están en «Lo que
esta propuesta NO resuelve» de `PROPUESTA-SPEC.md`. Se listan aquí solo para que no se confundan con
decisiones pendientes:

- **`L_suelo_slots` no se puede fijar hoy:** su criterio exige `Δ` **medida en red real**. Decidir
  su existencia era la decisión (tomada); decidir su valor necesita una medición que no existe.
- **El coste de C-FLU-02 para el productor honesto** está `estimado ≈ 0`: la confirmación con
  ANCLA-v0.2 es **condición para pasar al SPEC**, no una decisión.
- **La aritmética del adelanto con `pot_output` = salida futura (D-2 = A) está sin rehacer.** Hasta
  que se rehaga, ninguna cifra de `ρ_max`, adelanto o margen frente al sembrador es utilizable.
- **El margen real de 1a frente al sembrador no está medido**, y la defensa por «maduración de la
  parcela» no funciona tal como estaba escrita
  (`/home/katana/zeo/ZEROX/P-SEMBRADOR/investigacion/INFORME.md:9, 27`).
- **La deuda principal:** Prop. 7 bajo U3″ + R-FIN-5 + R-FIN-8′
  (`/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md:436-439`). (F1) y (F2), de las que
  cuelga toda la §2 de la propuesta, son medidas, no teoremas.
- **La reconciliación de la finalidad** con el código que hoy se detiene, con `COINBASE_MATURITY` y
  con el techo de archivado: **queda fuera por alcance decidido** de D-F3, no por falta de decisión
  (`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md:10`). Es trabajo, no bifurcación.
- **Ampliar C-HASH-06** con las dos etiquetas nuevas de D-F2: es una edición de `SPEC.md` §4.5 que
  esta propuesta no puede hacer (fuera de zona). Los nombres concretos son propuestas.
- **El estudio de la regla objetiva del recién llegado** («el flujo canónico es el que lideraba en
  `t_j + F_slots`»), con su resistencia a bloques con slots antiguos: encargo aparte.
