# DECISIONES-PENDIENTES — P-PRESTAMO

Las bifurcaciones **reales** para Katana. Cada fila: qué decide, qué gana con cada opción, qué paga
y qué cierra. Ninguna fila es una regla propuesta. Las rutas son completas desde la raíz
`/home/katana/zeo/ZEROX`.

Las cinco primeras son las que **cambian la conclusión**; las siguientes son las que la acotan.

---

## D1 · Qué identidad de billete: `C-GD-07` (con `chunk`) o `IDV-01`/`CANDIDATA` (sin `chunk`)

**Es la decisión que decide si el castigo es imprescindible o accesorio.**

| opción | qué gana | qué paga | qué cierra |
|---|---|---|---|
| **`C-GD-07` vigente** (`public_key, sector_index, history_size, chunk, slot`) | nada nuevo: es lo que hay | el doble farmeo **sí** aporta peso neto (`β_d`), el umbral de deriva baja a `(1−β_d−2β_x)/2` y **sólo el castigo lo sostiene** | — |
| **`IDV-01`/`CANDIDATA`** (con `piece_offset`, sin `chunk`) | el doble uso de una misma oportunidad **deja evidencia** y el castigo estrecho lo alcanza; `β_d` **no** baja el umbral y el requisito de `CANDIDATA.md` §A.2 C1 se cumple **por construcción** | hay que **cambiar la regla vigente** y verificar que `piece_offset` no deja escapar otro caso (`PROPOSICIONES.md` P7.4) | el escape por `chunk` (`κ` de 1,000 a 0,000 medido en `P-EQUIVOCACION`) |

**Lo que este trabajo aporta a la decisión.** Con `C-GD-07`, el umbral de deriva depende de `β_d`
(que es gratis sin castigo: F3) y el castigo es la única defensa. Con `IDV-01`, `β_d` no aporta
peso neto y el resultado **no depende de que el castigo sea creíble**. Los números de las dos ramas
están en el `INFORME.md` §3.3.

**Quién decide:** Katana (consenso). **Bloqueante hoy:** `IDV-01` está marcada «condicionada»
(`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md` §1).

---

## D2 · `V`: cuánto vale el ataque. Sin `V` no hay región de `(ρ_ret, T_v)`

**Qué falta:** el valor de ataque `V` en unidades de emisión, y contra qué adversario. La región de
F5 (`INFORME.md` §5.1) es una **familia** parametrizada por `V`; este trabajo publica `V = 400`
u.e. por reclutado (4 semanas de emisión) porque el PROMPT §3 F5 pide un ejemplo, no porque sea el
valor.

**Qué gana/cierra cada opción.** Si `V` es acotado, la región `(ρ_ret, T_v)` existe y se puede
elegir. Si `V` es **ilimitado**, **no hay `(ρ_ret, T_v)` que valga** (`INFORME.md` §5.2). Lo que
cierra la decisión: declarar un techo de `V` (por ejemplo, el daño máximo de un doble gasto), o
aceptar que el mecanismo no cubre ese adversario.

**Quién decide:** Katana (economía + amenaza).

---

## D3 · [CERRADA] `BASELINE.md` escenario 0 no se toca

Este informe propuso una «corrección» a `BASELINE.md:18`. **La propuesta era errónea y se retira.**
La fórmula de `BASELINE.md` es correcta en su convención (`p` = tasa del honesto, `q` = tasa del
adversario, de modo que `q < p` es adversario en minoría y `(q/p)^(d+1) < 1`). La corrección
propuesta daba valores mayores que 1. **No hay nada que decidir aquí**: `BASELINE.md` queda como
está y el detalle de la verificación está en `PROGRESO.md` O1 y en `INFORME.md` §2.4.

Lo único que sí quedó de este episodio es una mejora de claridad: las funciones de
`espacio-prestado-v1` declaran en su firma si la tasa que reciben es la del honesto o la del
adversario, y los tests incluyen la reconciliación numérica con `BASELINE.md`.

## D4 · El puente espacio → tasa (H1): ¿se mide o se declara limitación permanente?

**Qué falta:** la derivación `espacio → tasa` (distancia circular, `sd ≤ SR/2`, chunks ganadores)
que `DEFECTOS.md` C1 declara **no implementada en ningún instrumento**. Todo F2 y F3 están
condicionados a H1.

**Opciones.** (a) Implementarla en un instrumento nuevo (coste: campaña de cálculo; cierra el
defecto D4, que sigue abierto desde CRP-v0.2/v0.3). (b) Declararla **limitación permanente** y
publicar F2/F3 como condicionados (lo que hace este informe).

**Qué gana/paga.** (a) convierte los números de F2 en medidos; (b) los deja como condicionados
pero no bloquea la decisión de D1/D2, porque F1 (deriva) **no** depende del puente.

**Quién decide:** Katana (consenso) + quien ejecute el instrumento.

---

## D5 · `F`: ¿se elige ya, o se mantiene como símbolo?

**Qué falta:** `F_slots` no está fijada (`SPEC.md` §7.3, `C-FIN-01` es símbolo). F2 usa
`{1.019; 3.547; 3.600; 7.200}` como **valores de ejemplo**, como manda el PROMPT.

**Por qué importa aquí.** `T_v MUST > F` (`INFORME.md` §5.1): la región de retención **depende
directamente de `F`**. Con `F = 7.200`, `ρ_ret = 0,25` **no cumple** el requisito temporal aunque
cumpla el económico; con `F = 1.019`, sí. **Elegir `F` es elegir `T_v`.**

**Quién decide:** Katana (consenso).

---

## D6 · Primer castigo: leve, gradual o máximo (interacción con F6)

**Qué falta:** decidir si el primer castigo es leve o gradual (`CANDIDATA.md` §A.2 C3;
`P-EQUIVOCACION` D11). F6 muestra que el coste del honesto accidental es **lineal** en
`ε_h·ρ_ret·T_v`: no hay separación económica posible entre honesto accidental y atacante.

**Qué cierra cada opción.** Un primer castigo máximo **sin** protección en el productor es una
trampa para el honesto (FP1–FP5 de `P-EQUIVOCACION`); un primer castigo leve reduce la disuasión
en `ρ_ret` o exige alargar `T_v`, que ya está restringido por `F` (D5).

**Quién decide:** Katana (diseño de producción + consenso).

---

## D7 · La asimetría de la carrera del ancla (`P5`): ¿se mide `κ(α, δ, L)`?

**Qué falta:** `κ` no es independiente de `α` (`PROPOSICIONES.md` P5/P6: los slots divergentes son
`≤ δ`, con `δ = s₀ − T_j`), y la distribución de `δ` no existe (`P-EQUIVOCACION` D4). Este
informe barre `κ` como símbolo constante y **declara** que con `κ` decreciente la región de F5 se
estrecha proporcionalmente, sin cambiar la conclusión cualitativa.

**Qué gana medirlo:** una cifra de `κ` en vez de una región; y saber si el atacante puede llegar a
`κ ≈ 0` ganando la carrera del ancla. **Qué cuesta:** un instrumento nuevo sobre
`veritas/consenso/ancla-inyeccion-v2/` (lo pide `P-EQUIVOCACION` D2/D3).

**Quién decide:** Katana (prioridad) + instrumento Julia.

---

## D8 · La estrategia de «publicar sólo la rama ganadora» (`κ = 0`)

**Qué falta:** la rentabilidad de retener la rama y publicar sólo si gana
(`P-EQUIVOCACION` D14). Es el escape que **ninguna identidad de billete** alcanza: sin los dos
bloques no hay evidencia.

**Qué significa para este encargo.** Con `κ = 0`, `b* = 0` y **no hay `(ρ_ret, T_v)` que disuada**
(`INFORME.md` §5.2). Lo que este trabajo **no** hace es cuantificar cuánto cuesta retener: eso
depende de la carrera de la rama retenida, que es el mismo objeto que `P5` y que `C-GD-11`
(D1 de `P-EQUIVOCACION`). **Si el saldo fuese favorable, el castigo de `CANDIDATA.md` cubriría una
parte del doble farmeo, no el fenómeno.**

**Quién decide:** instrumento (Julia) + revisión de Katana.

---

## D9 · Soborno condicionado al éxito y censura: ¿se tratan como un parámetro o como un adversario aparte?

**Qué falta:** decidir si `q_gana` (probabilidad de que la evidencia entre si la privada gana) es
un parámetro del modelo o el adversario que lo rompe. Con `q_gana = 0` y soborno condicionado al
éxito, **el atacante no paga nada si fracasa** y el mecanismo no disuade.

**Qué cierra cada opción.** Tratarlo como parámetro da una región; tratarlo como adversario
obliga a decir que **frente a censura total no hay región** (lo que hace el informe, §5.2).

**Quién decide:** Katana (modelo de amenaza).

---

## D10 · El esquema de permanencia que se supone

**Qué falta:** `P-PERMANENCIA` (F1/F2) demuestra que el muestreo de piezas **no prueba
almacenamiento** y que las parciales **no añaden coste sobre farmear**. El `c_r` de la pérdida del
granjero sólo vale si el castigo **inhabilita el lote** y obliga a replotear; si el granjero borra
y regenera dentro de la ventana, paga `c/(r·w)` CPU, no `c_r`.

**Qué cierra cada opción.** Declarar el esquema supuesto en cada fila (lo que hace `INFORME.md`
§4–§6) o medir el coste real de regeneración (E5/`P-INTENTO`). Sin eso, `c_r` es un símbolo más y
la región de F5 se desplaza.

**Quién decide:** Katana + `P-PERMANENCIA`.

---

## Lo que este encargo **no** deja pendiente

F1 (superficie de deriva) y la cota de F2 (`P ≤ (1−p)^F`) están **cerradas**: son aritmética
exacta y no dependen de ninguna decisión. La reconciliación con la fórmula de `BASELINE.md`
escenario 0 está **demostrada** (y la acusación de que estaba invertida quedó retirada). La respuesta a «¿es el castigo imprescindible?» es **sí en el régimen `C-GD-07`** y
**no en el régimen `IDV-01`**, y esa bifurcación es D1.
