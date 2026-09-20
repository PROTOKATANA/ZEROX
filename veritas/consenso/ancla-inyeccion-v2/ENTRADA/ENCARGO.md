# P-2.1 v3 — ¿Es viable el flujo único de PoT? Nacimiento, permanencia y precio de una partición de flujo

**Ejecutor:** DeepSeek. **Zona de trabajo: `P-2.1/`** (decisión de Katana, 2026-09-18).
**Diseñado por:** Claude, 2026-09-18, tras barrer la investigación previa con ocho revisores.
**Sustituye a:** los encargos v1 y v2 (`P-2.1/historico/`). **No los sigas: los dos estaban mal.**
**Categoría Veritas propuesta:** `consenso` (dominante); `seguridad` y `finalidad` secundarias.
**Ruta del instrumento:** `P-2.1/veritas/consenso/ancla-inyeccion-v2/` (**ANCLA-v0.2**).
**Destino, solo si se valida:** `veritas/consenso/ancla-inyeccion-v2/`.

**El objetivo es cerrar `TAREAS.md` §2.1, no producir un informe.** Tiene que salir de aquí lo que
Katana necesita para decidir `L`, `I`, `ρ_max` y `F`, y lo que hace falta para escribir la regla de
flujo. **Si lo que sale es que el diseño candidato no es viable, ese es el resultado y vale lo mismo.**

---

## 0 · Antes de escribir una línea

**Lee íntegro `veritas/LINEO.md`** (obligatorio por `AGENTS.md` y C-SPEC-03; su §8 te aplica entero).

**Aviso de nomenclatura, o perderás horas:** los archivos `research/dag-poas-ancla-de-orden-auditoria-9a/9b/9c.md`
auditan las **rondas 10a/10b/10c**, no las rondas 9. La medición histórica de `W_dec` está en
**`…-auditoria-8c.md`**, que audita la **ronda 9c**. El mapa completo archivo→ronda:
`auditoria.md`=8, `-2`=8b, `-3`=8c, `-4`=8d, `-5`=8e, `-6`=8f, `-7`=8g(D8), `-8a/8b/8c`=9a/9b/9c,
`-9a/9b/9c`=10a/10b/10c.

Lectura obligatoria, en este orden. **Todo `research/` es evidencia histórica** (`research/README.md`):
da vocabulario, trampas y cotas de método, **nunca cifras heredables**.

1. `research/dag-poas-ancla-de-orden.md`: **§2 entero** (l. 161-390: R-FIN-1, 1a, 2, 3, 4, 5, 7, 12,
   13′, 14 con su «Corrección a (h)» y las **correcciones de alcance del 2026-09-10**), y **§4, §5 y §7**
   (l. 408-529: lo que cuesta, lo que **no** está demostrado, y lo que D9/D8 tenían que refutar).
2. `research/dag-poas-inyeccion-auditoria.md` **entero**. Es de 2026-09-07 y es el documento más
   importante para ti: audita la primera versión de esta misma ancla y contiene E1, la refutación por
   circularidad, además de casi todas las cotas que vas a contrastar.
3. `research/dag-poas-recursion-flujos.md` **entero** (es corto). Es el único texto del repositorio
   que mira de frente la permanencia de una partición de flujo.
4. `research/dag-poas-candidatos-auditoria.md`, **§0 y §1** (l. 14-45) y la medición del *balance
   attack* (l. 520-545). Contiene el argumento de **cobertura racional** y el único control con fusión.
5. `research/dag-poas-ancla-de-orden-auditoria-8c.md` §0-§2: qué es `W_dec`, cómo se midió y con qué
   resolución.
6. `research/dag-poas-auditoria.md` l. 337-360: **ATAQUE 1** y **ATAQUE 2**. Son el origen, y son
   **anteriores** a R-FIN-1…14: léelos sabiendo que el repositorio ya les respondió en parte.
7. `SPEC.md` §7.1 y §7.3 (l. 1278-1473): el **contrato de unidades**. Y **C-NET-31/32** (l. 2976-3010).
8. `veritas/consenso/ghostdag-rank-v1/` (GDR-v0.2) y `veritas/finalidad/delta-medido-v1/` (DMS-v0.1).
9. `TAREAS.md` §2.1 y §3.3.

---

## 1 · El problema, re-diagnosticado dos veces

`TAREAS.md` §2.1 dice que el multistream de PoT baja el umbral a `α_mín = 1/(S+1)` — **0,040 con
`S = 24`**. **Ese titular es más ancho que la evidencia**, y lo escribió quien diseña este encargo:
la `PROPUESTA.md` del instrumento validado (`veritas/seguridad/coste-rama-privada-v1/`, §P5) ya lo
etiquetaba bien — *«el multistream, **si** el diseño lo permite, sí baja el umbral; está
**condicionado** al diseño del flujo, **no demostrado**»*.

- `1/(S+1)` es la regla **aditiva**: el atacante **suma** el `blue_work` de sus `S` flujos. Solo ocurre
  si un bloque puede fusionar pasados de flujos distintos (validez **relativa**, la del ATAQUE 2).
- El diseño candidato **ya no es ese**: con **R-FIN-4** (validez absoluta) y **R-FIN-5** (pasado
  consistente de flujo) los flujos **no se fusionan**; el atacante **elige la mejor** de sus ramas.
- El repositorio ya lo había identificado: `candidatos-auditoria.md:210` dice que `1/(1+m)` es
  exactamente el régimen «flujo comparado por último inyector», y que el **linaje acumulativo**
  (R-FIN-3) es la corrección que lo evita. **No lo presentes como hallazgo nuevo.**

### Lo que el repositorio sabe y nunca midió — el verdadero encargo

1. **Una partición de flujo no se cura.** `recursion-flujos.md:20-21`, literal: *«con R-FIN-5 los
   bloques de otro flujo **no entran nunca**, y con R-FIN-7 nadie vuelve atrás pasadas `F`. **Una
   partición de flujo no se cura.** La pregunta correcta es por tanto: ¿con qué probabilidad **nace**
   una partición de flujo?»*. Es decir: **el diseño no responde a la recuperación, la sustituye por la
   probabilidad de nacimiento**, y esa sustitución descansa en una inducción por épocas etiquetada
   **PLAUSIBLE**, sobre una Prop. 7 que el propio paper deja abierta (hueco L571).
2. **Y hay un argumento, nunca reexaminado, de que además se auto-sostiene sin atacante.**
   `candidatos-auditoria.md:20-22` y la tabla de `:33`, **cuya primera fila es el diseño vigente**:
   *«se colorean por linaje (rojos los no canónicos) | cobertura racional ⟹ deriva cero ⟹ **no
   converge**; con linajes, **partición permanente sin atacante**»*. R-FIN-5 impide **fusionar**, no
   impide **producir** en los dos flujos. Y la salida obvia está cerrada por teorema: la exclusividad
   entre relojes en PoAS permissionless es **siempre derrotable**, porque las identidades son gratis
   (`balizas-auditoria.md:71`). Comprobado por el revisor: ese argumento **no reaparece en ninguna
   ronda posterior a la 6**.
3. **El coste de cubrir dos flujos es casi cero, y está medido.** El mismo sector se audita contra los
   desafíos de los dos flujos: razón **plotear/auditar = 1 517 730×**
   (`dag-poas-ancla-de-finalidad-metaauditoria.md:145`). El pago de «cubrir ambos» no es 0,5: es
   `1−ε`. **Cubrir `S` flujos racionalmente es exactamente el multistream** —los mismos `S` núcleos e
   IOPS, cero espacio— así que el techo de IOPS acota cuántos flujos se pueden cubrir, y las preguntas
   de permanencia y de umbral son **el mismo mecanismo visto desde dos lados**.

### Las cuatro preguntas

| # | Pregunta | Qué decide |
|---|---|---|
| **0** | Una vez nacida una partición de flujo, ¿**se sostiene sola**, sin atacante, por cobertura racional? | si el diseño candidato es viable tal cual |
| **A** | ¿Con qué probabilidad **nace**? `G(d)` y de ahí `L_mín(ε, α, Δ)` | `L`, y con ella todo lo demás |
| **B** | Si nace, ¿qué **cuesta**? ¿Puede un adversario provocarla o sostenerla? | si «no se cura» es vivible |
| **C** | Bajo R-FIN-5, ¿cuánto compra **elegir la mejor de `S` ramas**? | el umbral que sustituye al 4 % |
| **D** | ¿Se cruzan las restricciones sobre `(ρ, L, I, F)`? | el mapa para que Katana decida |

---

## 2 · Lo que estaba mal en v1 y en v2 — los dos los escribió quien firma este encargo

No lo heredes. Si algo de esto reaparece en tu trabajo, se rechaza.

**Del v1 (superado):** medía «la posición `N` de la cadena seleccionada a profundidad `D`», que es el
**ancla nº 2**, descartada en D9-c porque «cuenta saltos». Inventó una magnitud `D` en posiciones de
cadena cuando el repositorio ya tenía `L_slots` en slots de PoT. Solo red honesta. Y afirmaba que
R-FIN-14(h) «lleva el steering a 0 para cualquier `ρ`», que es **falso** (corrección 10a,
`ancla-de-orden.md:281-288`: lo divide por **279** en `ρ ≤ 2,5` y lo anula solo hasta
`ρ* = (L+I)/(I+W_dec)`; **protección y coste son el mismo número**, `≈ 1 + L/I`).

**Del v2 (este lo corrige):**

1. **No fijaba el orden de evaluación del ancla, y sin él la definición es circular.** Ver §3.1.
2. **Trataba la recuperación como una incógnita abierta** cuando el repositorio ya había decidido que
   no la hay, y **no conocía el argumento de cobertura racional**, que es la pregunta 0.
3. **Metía la «regla de selección entre flujos rivales» como si fuera gratis.** No lo es: destruye la
   virtud declarada de R-FIN-5 —*«un nodo honesto **jamás** verifica el PoT de un flujo ajeno»*,
   `ancla-de-orden.md:223-225`— con la que se cerraron tres refutaciones anteriores, y **reabre un DoS
   ya cuantificado**: 77 kB → **60,1 core-s**, ~781 core-µs/byte por replay
   (`inyeccion-auditoria.md:323-347`); spam de candidatos **1,25 núcleos (α=0,10) a 4,1 (α=0,33)**, es
   decir **12,5×–41×** el flujo canónico (`candidatos-auditoria.md:352-365`). Además **choca con
   R-FIN-7**, que prohíbe reorganizar por debajo de `F`. Pasa a ser una **variante con precio**, §4.B.3.
3. **Confundía dos magnitudes bajo el nombre `W_dec`.** Ver §3.2.
4. **Sus escalones de estrés (`Δ ≈ 2` y `4 s`) no estresan nada:** con `k = 30`, `δ₀ = 0,0000` en todo
   `Δ ≤ 6 s`. El acantilado está en 12-20 s (`δ₀` = 0,0219 / 0,0828 / 0,2858 / 0,4428 a `Δ` = 10/12/16/20 s;
   frontera 44,65 → 38,33 → **32,38 %**, donde el 33 % ya cae). Corregido en §4.A.
5. **No sabía que existe una medición casi idéntica a `G(d)`**, sin verificar: §4.A, control positivo 2.
6. **Su hipótesis de cota de unión en 4.C está en entredicho ya con `S = 2`**, y su fórmula de ganancia
   choca con la del repositorio. Ver §4.C.
7. **Le faltaban restricciones sobre `L` y sobre `F`.** Ver §4.D.
8. **Colisión de nombres:** el repositorio usa `g` para la fracción de steering; el v2 usaba `g` para
   una ganancia de tasa. Aquí se llaman `g_steer` y `v_gain`.

---

## 3 · El diseño candidato, con las dos aclaraciones que le faltaban

Es el del repositorio. **No lo mejores mientras lo mides**; las mejoras van a `PROPUESTA.md`.

**Perfil A″:** `λ = 1 bloque/s`, `τ_nom = 1 s/slot`, `k = 30`, 15 padres, `mergeset ≤ 180`,
`S_max_slots = 150`, **R-FIN-1a no estricta** (`slot(sp(B)) ≤ slot(B)`; los empates son el caso normal
con 1 slot por bloque, y hay que tratarlos explícitamente).

**R-FIN-1 · Ancla.** `I_j(B)` = el bloque de la cadena seleccionada de `B` con menor `blue_work` entre
los de `slot ≥ T_j`, con `T_j = j·I_slots`. **DEMOSTRADO equivalente al primer cruce de `T_j`**
(ronda 11c Prop. 1, `research/scripts/d9-ronda11c/informe.md:39-65`, apoyado en R-FIN-1a y en el Lema
A4b: `blue_work` estrictamente creciente por la cadena seleccionada, 141 967/141 967). **Cítalo, no lo
supongas.** Si la cadena aún no alcanza `T_j`, **no hay ancla**: es un estado que se cuenta, no una
muestra que se descarta.

**R-FIN-2 · Activación retardada.** `t_j = slot(I_j) + L_slots`. Hasta `t_j` todos siguen en el flujo
anterior: candidatos distintos a `I_j` **no crean loterías distintas antes de tiempo**.

**R-FIN-3 · Flujo acumulativo, derivado del pasado, nunca declarado.**
`flujo(B, s) = H(flujo(B, t_{j−1}) ‖ entropía_j ‖ t_j)`.

**R-FIN-4 · Validez absoluta.** Función de `past(B)` y de nada más.

**R-FIN-5 · Sin fusión entre flujos.** Para todo `X ∈ past(B)`: `flujo(X, slot(X)) = flujo(B, slot(X))`.
Comprobación **estructural, antes de tocar ningún PoT**.

**R-FIN-7 · Finalidad.** Ningún nodo reorganiza por debajo de `F` segundos de slot.

### 3.1 · El orden de evaluación, que es condición de buena definición

`dag-poas-inyeccion-auditoria.md:83` refutó por **circularidad** la primera versión de esta misma
ancla: `I_j = f(cadena(past(B)))`, `cadena = g(bloques válidos)`, `validez = h(I_j)`. **No hay orden de
evaluación bien fundado, y no se demuestra que el punto fijo exista ni sea único.** La reparación está
escrita ahí mismo y **R-FIN-1 nunca la incorporó** (su «cierre pendiente» habla de bootstrap, primer
cruce y poda, no de esto):

> `I_j :=` primer bloque con `slot ≥ T_j` de la cadena seleccionada del bloque virtual
> **sobre `past(B) ∩ {slot < t_j}`** — bien fundado por inducción sobre `j`: para decidir la época `j`
> solo se usan flujos de épocas `< j`.

**Esta es la definición que mides.** Si calculas el ancla sobre la vista completa, o sin la restricción
de época, **mides un artefacto** y el encargo se rechaza. Escríbelo en `MODELO.md` con esta cita, y di
si al implementarla aparece algún caso en que el punto fijo no sea único.

Consecuencia que también hay que modelar (`inyeccion-auditoria.md:112`): **la discrepancia no reordena,
invalida**, y hay **cascada** — si la cadena cambia por debajo de `T_j`, cambia `I_j` y con él todos los
`I_{j'}` posteriores. El coste de recuperación es *todo lo posterior a `t_j`* en el lado minoritario,
más la reconstrucción del PoT desde `t_j`.

### 3.2 · Dos magnitudes distintas, dos nombres

El repositorio llama `W_dec` a **la ventana de influencia del atacante**: *«el último instante en que
una acción suya cambia el ancla»*, medida como el `d` donde el menú de anclas alcanzables cae a 1,
leída **sobre una sola vista canónica al final del horizonte**. A `α = 0` le sale `−1` por construcción.
Es la que entra en `n_eval = ρ·W_dec`, en `I ≥ ρ_max·W_dec` y en `ρ* = (L+I)/(I+W_dec)`.

Lo que hace falta para decidir `L` es otra cosa: **la dispersión entre observadores honestos**.

- **`W_steer`** = la del repositorio. Capacidad del atacante.
- **`W_obs`** = la nueva: el mayor `d` (en slots tras `T_j`) en el que **algún observador honesto tiene
  un ancla distinta de la que acaba siendo definitiva, o dos honestos discrepan entre sí**.

**Mide las dos.** No las mezcles: `W_obs` decide `L`; `W_steer` alimenta las fórmulas de §4.D. Sustituir
una por otra cambia el significado de R-FIN-14(f) y (h).

---

## 4 · Las mediciones

**Orden estricto: 0 → A → B → C → D.** La 0 es barata y puede cerrar el encargo; hazla primero.

### 4.0 · PUERTA · ¿Se sostiene sola una partición de flujo? — sin atacante

Instrumento pequeño, casi analítico. **No necesita GDR ni red.**

Bajo flujos distintos, el mismo sector en el mismo slot da chunks distintos: **son billetes distintos y
ambos pueden existir**. Publicar es gratis, la validez es absoluta, y auditar el segundo flujo cuesta
`1/1 517 730` de lo que costó plotear. Luego el pago de un granjero es `Σ_i P(gana el flujo i)·(billetes en i)`
y **cubrir todos los flujos vivos es estrategia estrictamente dominante**. Si todos cubren, cada flujo
recibe bloques a tasa `λ`, la diferencia de peso entre dos flujos es un **Skellam de deriva nula**,
recurrente, y el líder cambia indefinidamente.

**Entrega:**

1. **La condición exacta bajo la que cubrir un segundo flujo es racional**, como función del coste
   marginal (IOPS, núcleos de AES, ancho de banda) y de `P(gana)`. El límite físico está medido: 4 TiB =
   4 161 lecturas/slot por flujo; un SSD de 100 k IOPS da `S ≈ 24` **para un granjero de 4 TiB**, y con
   20 TiB son 20 807 lecturas/slot por flujo ⇒ **`S ≈ 4-5`** (`dag-nativo-poas-propuesta.md:1360`). Da
   la curva `S_max_racional(capacidad)`, no un número.
2. **La deriva y el tiempo de absorción** de la diferencia de peso entre dos flujos, con una fracción
   `c` de granjeros que cubren ambos y `1−c` que siguen solo uno. Barre `c ∈ [0, 1]`. ¿A partir de qué
   `c` la deriva deja de ser suficiente para que un flujo muera en un tiempo razonable?
3. **El contraste histórico:** en el diseño de la ronda 3, con cobertura total y sin atacante, el flujo
   canónico seguía cambiando a los **203,6 s** de una época de 205,7 s, y `P(cambia tras 600 s) = 0,82`
   (`candidatos-auditoria.md:20-33`). **Recalcula bajo R-FIN-4/5**, no lo heredes: allí los flujos se
   fusionaban y aquí no, lo que cambia la dinámica en una dirección que hay que determinar, no suponer.
4. **Si la respuesta es que se sostiene:** dilo en la primera línea del `INFORME.md`, sigue con A —que
   entonces es lo único que separa al diseño del fallo— y **anota en `PROPUESTA.md`** que el único
   mecanismo de recuperación que funcionó en todo el repositorio fue el **reset del flujo en vez del
   plegado** (`relojes-efimeros.md:18-19`: *«cuando sus conos coinciden en la ventana siguiente, sus
   semillas coinciden y los relojes colapsan en uno»*), incompatible con R-FIN-3 acumulativo, y
   descartado por motivos **ajenos** a la recuperación (`relojes-auditoria.md:56-61`).

⚠️ **Si `MODELO.md` supone que cada honesto elige un flujo y se queda, ese supuesto codifica la
conclusión.** Va obligatoriamente a `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

### 4.A · La cola de `W_obs` y el suelo de `L` — PRIORIDAD MÁXIMA

Es lo que nadie ha medido, lo pidió la ronda 10c y su propio agente declaró **dos veces** que no lo
había hecho (`research/scripts/d9-ronda10c/informe.md:620-624` y `:863-865`).

Entrega la **función de supervivencia `G(d) = P(W_obs > d)`**, con `d` en slots y **rejilla de 1 slot**:

- **(A1) red honesta**, modelo DMS-v0.1, más escalones de estrés **`Δ ∈ {4, 10, 16 s}`** —los que de
  verdad discriminan— además de la Δ nominal sub-segundo.
- **(A2) adversario de espacio**, `α ∈ {0,10; 0,25; 0,33; 0,40; 0,45}`, latencia cero, que retiene,
  elige padres libremente dentro de la validez y **quiere maximizar `W_obs`**. Vías mínimas:
  - **V1** retener candidatos propios y soltar uno en `T_j + d`. **Obligatoria la clausura de
    publicación** (publicar un bloque publica todo su pasado): sin ella el instrumento permite retener
    un bloque y publicar un hijo suyo, que es imposible en la red real, y las `m` históricas con
    retención quedaron **infladas, sin cuantificar** (`auditoria-8c.md:62-65`).
  - **V2** cadena privada desde `T_j − P`, barriendo `P`.
  - **V3** la mejor que encuentres. **Declárala «la más fuerte que encontré, no demostrada óptima».**
- **(A3) adversario de red — y esto es lo que más importa:** no basta retrasar a todos por igual. El
  ataque que maximiza el desacuerdo honesto es la **entrega selectiva**: dar un bloque a **un solo**
  observador. Es lo que hace el instrumento histórico (`d9-ronda11c/r11c_c14_dosvistas.py:5-8`). **Si
  solo retrasas simétricamente, mides una cota inferior.**

**De `G` sale `L_mín(ε, α, Δ)`** = el menor `d` con `G(d) ≤ ε`, para `ε ∈ {10⁻³, 10⁻⁶, 10⁻⁹}`.

**Exigencias estadísticas:**

- **La unidad independiente es la época/réplica**, no el par (observador, corte).
- **La vista de un observador MUST estar cerrada bajo ancestros**: `recv(b) = max(llega(b), max recv(padres))`.
  Medir sobre la vista completa del simulador —que incluye bloques del atacante aún no publicados—
  **invirtió resultados** en la ronda 14 (`d14-dagknight/informe3.md:30-39`).
- **`0/n` no es una frontera.** La cota es `p ≤ 3/n` al 95 %; para `10⁻⁹` harían falta `3·10⁹` unidades
  independientes (`ancla-de-finalidad-metaauditoria.md:71-81`). Clopper–Pearson simultáneo.
- **Por debajo de lo medible, extrapolación declarada** y etiquetada `estimado`. La hipótesis natural es
  exponencial —es una carrera— y **ya está calibrada**: `r = (√((1−α)λ) − √(αλ))²` por slot = **0,0572**
  a `α = 1/3, λ = 1`, empírica 0,0588 (`voto-auditoria.md:163`). Contrasta tu ajuste contra ella.
- **Censurados, rezagados y observadores sin ancla se informan**, nunca se descartan. `G_vacío(d)` aparte.
- **Criterio de aceptación obligatorio** (`ancla-de-orden.md:508-513`): *«el resultado debe cambiar al
  cambiar `α`; si con `α = 0` y con `α = 1` sale lo mismo, no es una simulación: es una tautología»*.
  Ese criterio habría cazado los cinco defectos de la ronda 7, donde el test que debía medir el acuerdo
  honesto comparaba **una variable consigo misma** (`metaauditoria:100-113`). Reimplementa el criterio
  en Julia —el detector original es Python— y declara el resultado.

**Controles positivos — los dos, y di en qué difieres:**

1. **Ronda 9c** (`auditoria-8c.md` §2): `W_steer` máx **−1 / 10 / 20 / 20 / 45 s** para
   `α` = 0 / 0,10 / 0,25 / 0,33 / 0,40; 12 semillas, rejilla `{0,10,20,45,80,…}`, **tope de 10
   candidatos**, `Δ = 4 s` constante. **Es `W_steer`, no `W_obs`.** «45 s» es un máximo observado con el
   siguiente escalón en 80: cualquier cola entre medias es invisible.
2. **Ronda 11c C.1/C.4** (`research/scripts/d9-ronda11c/salida_c14.txt`), **sin verificar, murió por
   cuota**: mide `P(dos honestos leen I_j distinto en T_j + d)` con entrega selectiva, `Δ = 4 s`,
   `k = 30`, 12 semillas, rejilla diádica. Es **tu misma magnitud**:

   | `α` | d=4 | 8 | 16 | 32 | 64 | 128 | 256 |
   |---|---|---|---|---|---|---|---|
   | 0,00 | 1,000 | 0,886 | 0,644 | 0,348 | 0,0833 | 0,0076 | 0 |
   | 0,25 | 1,000 | 0,608 | 0,220 | 0,0379 | 0 | 0 | 0 |
   | 0,40 | 1,000 | 0,504 | 0,106 | 0,0152 | 0 | 0 | 0 |

   **Léelo con cuidado:** la cola **más larga es la de `α = 0`**, y las de adversario se apagan antes.
   Es contraintuitivo y probablemente un artefacto (el máximo se toma sobre una familia cuya cobertura
   varía con `α`). Los ceros son `0/n` con `n ≈ 132`: la resolución es ~0,0076, y el «0,0076» de la
   primera fila es literalmente `1/132`. **Explica la anomalía o repórtala como discrepancia.**

**Cotas analíticas independientes contra las que contrastar la cola** (porta el modelo, **re-deriva las
constantes**, y no ejecutes su Python):

- `L` necesaria con atacante, misma ancla, carrera de score con handicap de *freeloading*:
  **189 / 287 / 377 / 682 s** para `α` = 0,10/0,20/0,25/0,33 (`inyeccion-auditoria.md:102-106`; `k=18`, `q=1`).
- `V` para `P ≤ 10⁻⁹` por inyección: **372 slots** (`α=1/3`, `F=0`), 847 (`F=100`) (`voto-auditoria.md:161`).
- Reorganización de cadena a profundidad, Skellam + alcance de Nakamoto con `k=30` y handicap `3k=90`
  bloques: `ε=10⁻⁶` a **608,4 s** y `ε=10⁻¹²` a **870,5 s** con `α=0,33`; 1 320,6 / 2 044,3 s con
  `α=0,40` (`d16-gate/informe.md:21-28`). **Mide otro objeto** (reorg de cadena lineal, no cambio de
  ancla) y su `δ` viene de una fuente **superada por R-FIN-13′**: úsala como forma, no como constante.
- Suelo honesto con forma analítica: `Λ ≥ D` basta; `P(discrepancia honesta) = 0` en 200 000 réplicas a
  `Λ = D = 4 s`, y `1,5·10⁻⁵` a `Λ = 3,9 s` (`balizas-auditoria.md:129`).
- Estabilidad honesta con esta misma ancla: p99 = **57 s**, `0/48` épocas cambian tras 60 s
  (`inyeccion-auditoria.md:209-213`, `k=18`, 48 épocas).

### 4.B · El precio de una partición de flujo

Provoca el split a propósito —aquí se mide el **coste**, no la frecuencia, que es 4.A— con partición de
red de duración `P_dur` que cruce la activación, barriendo `P_dur` frente a `L` y `F`, **y también el
reparto de espacio entre los dos lados** (la tolerancia medida es «hasta `F` **si el lado conserva
≥ 9 %** del espacio», `ancla-de-orden.md:303-307`).

1. **Contabilidad del daño.** Trabajo honesto huérfano, distinguiendo dos categorías que no son la
   misma: un bloque de **otro flujo** se pierde entero; un **rojo** cobra su coinbase por R-FIN-8′ y sus
   transacciones son reincluibles (`ancla-de-orden.md:426`). Profundidad máxima de reorganización contra
   `F`. Coste de reconstruir el PoT desde `t_j`.
2. **Control obligatorio: la misma partición sin divergencia de flujo**, donde GHOSTDAG sí fusiona. Ya
   está medido y te da el brazo de comparación: no-convergencia media **17,3 / 20,9 / 24,4 s** para
   `α` = 0,10/0,20/0,33, máx 60,6 s; huérfanos **1,81 %** sin atacante y **2,33 %** a `α=0,33`, p90 5,7 %,
   máx 12,2 %, 200 semillas (`candidatos-auditoria.md:527`). **La diferencia entre los dos brazos es el
   precio de no fusionar.**
3. **La regla de selección entre flujos, como VARIANTE con precio.** No está escrita en ningún sitio, y
   el motivo escrito de R-FIN-5 dice lo contrario: *«un nodo honesto jamás verifica el PoT de un flujo
   ajeno»*. Modela las dos ramas y entrega su coste:
   - **(i) sin adopción** (R-FIN-5 + R-FIN-7 literales): la partición es permanente por construcción.
   - **(ii) con adopción** (el nodo verifica la rama rival y se reorganiza si pesa más y `F` lo
     permite): cuenta **cuántas verificaciones de PoT ajeno se le pueden imponer a un nodo honesto y a
     qué coste para el atacante**, con `verify = 96,1 ms/slot` y `prove = 1,561 s/slot`, asimetría 16×
     (`ancla-de-orden.md:342`). Punto de partida histórico: **60,1 core-s por 77 kB** y **1,25-4,1
     núcleos** permanentes. **Esta cuenta decide si la regla es escribible**, no es un apéndice.
   - Y declara que (ii) **es incompatible con R-FIN-7 tal como está escrita**, que prohíbe reorganizar
     por debajo de `F`.
4. **¿Puede un adversario sostener el split** equilibrando los dos flujos? Entre flujos no hay fusión:
   la carrera deja de ser GHOSTDAG y pasa a ser de cadena más pesada. Ojo al precedente: con retarget
   por rama, una rama minoritaria sube su `SR` hasta producir al mismo ritmo y **el déficit pasa a ser
   un paseo sin deriva, recurrente** (`fork-choice-poas.md:41-51`). Comprueba si la cancelación del `SR`
   sobrevive cuando cada flujo tiene su propio retarget sobre su propio conjunto pagable (R-FIN-13′).
5. **Consistencia con 4.A, pero sin forzarla:** `P(split) ≤ G(L)`, con desigualdad **posiblemente
   estricta** — dos candidatos del mismo billete dan la misma entropía y el mismo `t_j`, luego el mismo
   flujo (`inyeccion-auditoria.md:24`, `:477`). Reprodúcelo como **control negativo**. Exigir igualdad
   llevaría a «arreglar» un instrumento correcto.

### 4.C · Lo que compra elegir la mejor de `S` ramas

Instrumento pequeño y aparte: proceso de ramificación con selección.

**Hipótesis del diseñador, y las dos están en entredicho. Tu trabajo es resolverlo, no asumirlo:**

1. **Cota de unión:** `P ≤ S·p₁` ⇒ con `S` fijo el umbral asintótico no se mueve y el precio son
   `≈ ln S / ln((1−α)/α)` confirmaciones (4,5 con `S=24`, `α=0,33`).
   ⚠️ **Contradicha por BDK ec. 39** con `c = j+1` opciones (`relojes-auditoria.md:128-131`, verificada
   contra `φ₁₆=1,4678` y `φ₅₀=1,2815` a cuatro decimales): `φ_c` = 1,00 / **2,23** / 2,01 / 1,80 / 1,61 /
   1,47 para `j` = 0/1/2/4/8/15, y el umbral cae a **0,31 con una sola rama extra**, «empeora con `j`
   pequeño, no con `j` grande», e independiente de `v`. **Decide cuál de las dos familias describe el
   objeto, con argumento.**
2. **Ganancia por ramificación adaptativa:** `v_gain ≈ √(2α·ln S / I_slots)` → 0,050 con `I=851`, 0,021
   con `I=4 725` (`α=0,33`, `S=24`).
   ⚠️ **El repositorio ya tiene una fórmula de la misma forma con `α` en otro sitio**:
   `g_steer = c_m/√(α·λ·I)` con `c_m ≃ √(2 ln m)`, `c_2 = 0,564`, `c_4 = 1,029`
   (`ancla-de-orden.md:103-118`, `voto-auditoria.md:199`), y su conclusión fue «continua en `n`, **sin
   umbral**». **Reconciliar o refutar ese desacuerdo es barato y decide `I` y `F`**, porque si
   `c_m ≃ √(2 ln m)` es correcta entonces `I ∝ 2 ln m` y `F ∝ ln m`.

**Entrega:** la tasa de crecimiento de la mejor rama privada y el `α*(S, m, I, L)` en que iguala a la
honesta. Barre `S ∈ {1,2,4,8,16,24}`, `I_slots ∈ [300, 5 000]`, `α ∈ [0,25; 0,49]`, y **`m` hasta
`1 + λ·S_max = 151`**, no hasta 5: ese es el menú físicamente disponible con el perfil A″, y a `m = 151`
el resultado histórico **cambia de naturaleza** (`d12-quorum/informe.md:119`). Modela el desfase `L`:
con `L > I` hay varias anclas en vuelo.

- Distingue **`P_terminal ≤ P_primer_paso ≤ P_eventual`**; al pago le importa el primer paso.
- **No compares `α*` contra `1/2` ni contra `1/(1+φ_c)`.** El umbral del diseño es ~40,7 % y el
  `1/(1+φ_c) = 47,6 %` es el valor **con `Δ = 0`** (`metaauditoria:164-194`); la forma con el retardo
  propio de GHOSTDAG es `α* = (1−δ)/(φ_c + 1−δ)`. Y arrastra **±1,2 puntos** de laguna abierta por
  `c_a = c_h` en unidades de índice (`ancla-de-orden.md:440-443`).
- **No dupliques el `α`**: el mismo `α` no puede estar a la vez en `δ` y en la carrera —`δ` se provoca
  con bloques **publicados**, la carrera necesita bloques **privados**, y son presupuestos disjuntos—.
  Ese error costó tres puntos de frontera y seis rondas (`tras-d8-palancas.md:6-14`).
- **`S` es escenario, no capacidad**, y su techo depende de la capacidad del granjero: ver 4.0.1.
- Comprueba que tu R-FIN-5 usa el flujo **derivado del pasado**, no un booleano del constructor del
  bloque. (CRP-v0.3, en `deepseek/` y **sin validar**, usa un campo `autenticado` del fixture, y su
  `horizonte_justificacion_ok` no comprueba lo que su docstring promete. No lo heredes.)

### 4.D · El mapa — analítico, sin simulación nueva

Con `W_obs` y `W_steer` en la mano, tabula **como funciones**, para `ρ ∈ [1, 4]`:

- **R-FIN-14(f)** con la cola medida en lugar del «máximo observado 45 s»: `I_slots ≥ ρ · W_steer(ε)`.
- **(h)** con su corrección: `ρ*(L, I) = (L+I)/(I+W_steer)` y su coste `≈ 1 + L/I`, que **son el mismo
  número**. Si se adopta, un lado de partición sin `q+1 = ⌈L/I⌉+1` líneas de AES **no produce bloques
  válidos aunque conserve todo su espacio**, lo que **contradice la letra de R-FIN-7**
  (`auditoria-9a.md:67,91`).
- **`S_max_slots < I_slots`** (condición **suficiente** del perfil, no necesaria demostrada) **y
  `S_max_slots < L_slots`**, que es **condición de corrección** y faltaba: sin ella, un bloque retenido
  con `slot ∈ [T_j, T_j+ε]` publicado tras `t_j` cambia `I_j` para los posteriores ⇒ invalidez mutua
  (`inyeccion-auditoria.md:110`).
- **Presupuesto de *lookahead* sobre `L`**: `lead ≈ L + I(1−1/ρ)`, que con `ρ→1⁺` sigue siendo `L−D`
  (`inyeccion-auditoria.md:124`). Es la restricción que mató a la ronda 2. El factor «95×» **no se
  hereda** (9c corrigió el lookahead de Autonomys de 11 s a ≈615 s), la restricción sí.
- **`W_RETARGET ≥ 3 083 slots` con `γ ≤ 0,25`** pone un suelo a `I_slots` si la ventana debe caber en la
  época — **con su rectificación de alcance del 2026-09-10**: esa derivación no demuestra error uniforme
  `< 1 %` y su recalibración está pendiente.
- **`W/κ`**: usa la forma corregida (`ancla-de-orden.md:418-421`), no el `1,22`, que «no es umbral de
  nadie»: BDK marca ≤ 1,00; la pinza real es **1 198 s** (`ρ=1,5`) / **2 488 s** (`ρ=3`), no 3 868.
- **`F` tiene dos valores y dos semánticas en el repositorio**, y no te toca resolverlo, sí declararlo:
  `F = 2 h` provisional bajo R-FIN-7 (no reorganizar) frente a `C-REORG-07 = 11 999 bloques = 3,33 h`
  con semántica **fail-stop** en el SPEC vivo. Y hay un tercer techo, hoy dormido:
  `MAX_REORG_LENGTH ≤ PROFUNDIDAD_ARCHIVADO`, porque un reorg más profundo que el archivado **invalida
  parcelas de toda la red** (`fork-choice-poas.md:118-125`).
- **La relación `L` vs `F`:** si `L < F`, una reorganización más profunda que `L` y menos que `F` está
  **permitida** y cambia un ancla ya activada, con probabilidad `G(L)`. Si `L ≥ F`, el ancla es final al
  activarse. **Las dos ramas, con su coste.** Y comprueba la condición que la ronda 10c puso a su propia
  recomendación: que `L < F` **no reabra** «conocer `entropía_j` antes de elegir `I_{j+1}`»
  (`auditoria-9c.md:81-86`).

Salida: la región de `(ρ, L_slots, I_slots, F)` conjuntamente admisible, **o la constatación de que está
vacía**. `ρ` en rango físico (`pot-aes-asic-chacha.md` §3: ~1,5-2,5×; un 19× exigiría 25 ps por ronda de
AES) más margen. Si consumes `m`, **di cuál**: el diseño está calibrado con `m = 2,548`, y la ronda 11c
midió **3,14 / 4,02 / 5,28** (`α` = 0,10/0,25/0,40) con la clausura de publicación — **sin verificar, y
en dirección insegura**.

---

## 5 · Trampas

1. **`1/(S+1)` es aditivo.** Bajo R-FIN-5 no aplica.
2. **Con adversario, estabilidad del ancla = reorganización a esa profundidad.** No las separes.
3. **Las unidades son slots de PoT.** Ni posiciones de cadena ni `blue_score`.
4. **Un cero observado no es una frontera; un máximo observado no es una cota.**
5. **No rompas R-FIN-14(e):** ningún reto derivable saltándose slots. Y **no reinventes la cadena de PoT
   «ciega»** que mezcla entropía en cada slot: ya se analizó y se descartó
   (`informe-52-problemas.md:318-321`, «se deja escrito para no repetirlo»).
6. **C-NET-31/32 cachean el PoT por `slot`** y declaran inválida toda salida distinta (`SPEC.md:3001-3002`).
   Con dos flujos candidatos eso hace depender la validez **de lo que llegó primero**, contra R-FIN-4, y
   repite el defecto que la ronda 10a tuvo que retirar en (h.3). **No lo modeles así:** la clave incluye
   el prefijo de flujo. Lo mismo vale para **C-TIMELORD-01**, propuesta en
   `timelord-redundancia-informe.md` §3.3 y nunca llevada al SPEC, que dice que el nodo acepta el PoT
   que verifique «sobre el flujo derivado de **su** cadena seleccionada» — validez relativa.
7. **Toda magnitud del ancla derivada de un sucesor es fabricable**, porque el atacante puede usar un
   bloque propio como sucesor de cadena (ronda 11c C.5). Aplícalo como test a cualquier regla que
   propongas en `PROPUESTA.md`.
8. **Un retardo uniforme iguala las vistas honestas por construcción** y produce un falso positivo
   (`voto-auditoria.md:133`). Y **contar bloques por etiqueta en vez de por estructura** infló un menú a
   14,3 por renombrado (`solucion-ancla.md:60-64`).
9. **No descartes muestras incómodas:** rezagados, épocas censuradas, observadores sin ancla.
10. **Si tu selección de padres no baraja**, fabricas discrepancia artificial: el `shuffle` de
    `pick_virtual_parents` es **obligatorio** (R-FIN-12); sin él, 14-21 bloques honestos quedan fuera del
    DAG para siempre.
11. **El desempate importa:** con `blue_work` el Lema A4-slot vale; con `solution_distance` **se rompe**
    y hay que repararlo (`d9-ronda11c/informe.md:142-175`). Si desempatas de otro modo, sales de la
    cobertura de Prop. 7. Declara cuál usas.

---

## 6 · Prohibiciones

1. **No fijes `ρ_max`, `F`, `I`, `L` ni `S`.** Todo como función o región. `F = 2 h` y `L = 1 h` son
   candidatos provisionales: bárrelos. Son decisiones de Katana y este encargo las **informa**.
2. **No edites `SPEC.md`, `TAREAS.md`, código del nodo ni nada fuera de `P-2.1/`.**
3. **No toques `deepseek/`.** Puedes **copiar** (no incluir por ruta) tu código v1 de
   `deepseek/P-2.1/…/ancla-inyeccion-v1/src/` —`red.jl` es aprovechable— con sus defectos corregidos.
   **Sus resultados no son evidencia**, y midió el ancla equivocada.
4. **Nada de Python, ni nuevo ni histórico.** Julia en CPU.
5. **GDR-v0.2 se reutiliza sin modificar** (por `include`). Si le falta algo, envuélvelo; si no se
   puede, **dilo antes de seguir**.
6. **No heredes cifras** de `research/`, de CRP-v0.1/0.2/0.3 ni de tus v1: **compárate** con ellas. Un
   contraejemplo conserva sus condiciones (adversario, retardo, pesos, reglas de padres, reloj, criterio
   de aceptación); nada se traslada automáticamente a otro conjunto de reglas.
7. **No cites un archivo sin comprobar que existe**, con ruta desde la raíz.
8. **Recorta el `Project.toml`** a lo que uses.

---

## 7 · Lo que este encargo NO puede cerrar — decláralo en `CONTRATO.md` desde el principio

De las ocho lagunas de `research/dag-poas-ancla-de-orden.md` §5, **este encargo no cierra ninguna
entera**. Las que condicionan tus resultados:

- **Prop. 7 bajo U3″ + R-FIN-5 + R-FIN-8′** — la «deuda principal»: la convergencia del orden está
  probada sobre **GHOSTDAG puro**. Si supones que Prop. 7 se aplica **dentro de cada flujo**, ese
  supuesto **codifica la conclusión de 4.B** y va al archivo de hipótesis.
- **`c_a = c_h` en unidades de índice**: ±1,2 puntos sobre cualquier umbral que entregue 4.C.
- **Empalme `φ_c` ⊗ `δ`** (conteo frente a peso) y **`3k` como ventaja real y no solo cota**.
- **`Δ` real**: DMS-v0.1 es **simulada con latencias supuestas** (lognormal, mediana 80 ms, p99 500 ms),
  no una medición de red. Y `δ₀` se midió con `Δ` **constante**, no con la distribución completa.
- **`ρ_max` real**: 1,5-2,5× es estimación; el estudio de Supranational no está localizado.

Y **fuera de alcance explícito**, porque tu adversario no los modela y existen catalogados:

- **Soborno del ancla**: `m = b+1` candidatos **incluso con `α = 0`**; el porte de BDK con coste de
  oportunidad es laguna abierta.
- **Sembrador**: plotea para ganar el slot `T_j`; convierte la retención unidireccional en colocación.
- **`ρ > 1` como adversario simulado** (aquí solo entra como eje de 4.D) y la retención selectiva con
  oráculo de victorias propias.
- **Cadena parásita + copias de billete**, que mueven `blue_work` y por tanto quién cruza `T_j` primero.
- **Retención del propio PoT** a un subconjunto de la red, que desplaza `T_j` y `t_j` percibidos.
- **Régimen > 15 puntas** del `shuffle`.

---

## 8 · Zona de trabajo y entregables

- **Escribes solo dentro de `P-2.1/veritas/consenso/ancla-inyeccion-v2/`.**
- **Solo lectura:** `P-2.1/ENCARGO.md`, `PROMPT.md`, `CONTEXTO.md`, `ENTRADA.sha256` y `historico/`. Al
  empezar y al terminar, desde la raíz: `LC_ALL=C sha256sum -c P-2.1/ENTRADA.sha256`, a `PROGRESO.md`.
- `P-2.1/` **no está en `.gitignore`** y ya figura como `?? P-2.1/`: tus archivos **no cambian** el
  `git status --short`. Regístralo al empezar y al terminar; **debe ser idéntico**.

| Archivo | Contenido |
|---|---|
| `CONTRATO.md` | qué calcula, qué **no** acredita (§7 entero), presupuesto declarado **antes** de ejecutar |
| `MODELO.md` | orden de evaluación del ancla (§3.1), `W_obs` y `W_steer` (§3.2), vista cerrada bajo ancestros, red, adversario (V1-V3, A3), desempate elegido, proceso de ramificación de 4.C, modelo de cobertura de 4.0 |
| `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` | los supuestos que, fijados por definición, vuelven tautológico un resultado. Obligatorios: «cada honesto sigue un solo flujo», «Prop. 7 vale dentro de cada flujo», y la `Δ` simulada |
| `INFORME.md` | **4.0 primero**, luego 4.A, 4.B, 4.C, 4.D. Cada afirmación con etiqueta (`demostrado`/`medido`/`estimado`/`no demostrado`/`inconcluso`), **condición** y evidencia |
| `PROPUESTA.md` | propiedades que debe cumplir la regla de flujo, la de selección entre flujos y la clave de la caché PoT; el reset de flujo como alternativa a `PROPUESTA`; qué queda abierto. **Propuesta, no SPEC** |
| `PROGRESO.md` | bitácora con la salida de `date`, no horas estimadas |
| `METODO.md` | comandos exactos, reproducibles **desde la raíz del repo** |
| `HUELLAS.sha256` | rutas desde la raíz del repo |
| `Project.toml`, `Manifest.toml`, `julia-version.toml`, `src/`, `test/`, `bench/`, `run.jl`, `resultados/` | LINEO §1. Ejecuta siempre con `./veritas/julia.sh` |

---

## 9 · Criterio de terminación

LINEO §10, y además:

**Si solo te da tiempo a dos cosas, que sean 4.0 y 4.A con adversario.** La primera es barata y puede
decidir la viabilidad del diseño; la segunda da `L_mín`, y sin `L_mín` no hay regla que escribir.

**Se rechaza:** calcular el ancla sin el orden de evaluación de §3.1; medir otra ancla que la de
R-FIN-1; unidades que no sean slots; una vista de observador no cerrada bajo ancestros; confundir
`W_obs` con `W_steer`; V1 sin clausura de publicación; leer `0/n` como frontera; usar `1/(S+1)` como
umbral del diseño con R-FIN-5; repetir que (h) anula el steering para todo `ρ`; duplicar el `α`; un
«verificador» que compruebe menos de lo que su nombre o su docstring prometen; y fijar cualquier
constante.

**Si agotas el presupuesto:** para, checkpoint, **inconcluso**, con entrada mínima reproducible.

---

## 10 · Después

Claude valida **reejecutando y leyendo el código** —docstring por docstring—, no leyendo tus
`resultados/`. Solo entonces se migra. Luego Katana decide, Claude escribe la `PROPUESTA-SPEC.md`, y
solo entonces se toca el SPEC.

**El patrón que este repositorio lleva repitiendo:** resultado correcto de alcance estrecho, presentado
con etiqueta ancha. Pasó en los encargos 05, 06 y 07, en el v1 de este, en el v2, y en el titular del
«4 %» que el diseñador escribió en `TAREAS.md`. **Etiqueta el alcance de cada afirmación tan
estrechamente como sea verdad.** Un «no lo sé» explícito vale más que un veredicto que haya que retirar.

**Si algo de este encargo te parece equivocado —en particular las dos hipótesis en disputa de 4.C, el
orden de evaluación de §3.1 o la definición de `W_obs`— dilo ANTES de ejecutarlo**, en tu primera
respuesta y en `PROGRESO.md`. No lo descubras al final.
