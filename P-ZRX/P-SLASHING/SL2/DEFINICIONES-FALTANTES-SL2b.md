# SL-2b · Falta de definición detectada antes de editar código

**Fecha:** 2026-09-26. **Ejecutor:** DeepSeek (`deepseek-flash`). **Entrada congelada:**
`P-ZRX/P-SLASHING/ENTRADA-SL2b.sha256` (5 entradas; **5/5 al inicio**). **Nota de integridad:**
durante la ejecución, Katana actualizó `DECISIONES.md` (18:40:32) llenando DS-L04; **DS-L03 — la
decisión que gobierna SL-2b — no cambió**, y el archivo está fuera de la zona escribible. **Orden:**
`ORDEN-SL2b-RECOMPENSA.md`.
Leídos íntegros, además: `DECISIONES.md` (DS-L03), `REVISION-SL2.md`, `PROGRAMA.md`,
`ORDEN-SL2-CALIBRACION.md`, `resultados-SL1/CONTRATO-EVIDENCIA-v0.md` (EV-17…EV-23),
`resultados-SL1/INFORME.md` (Decisión 2), `P-ZRX/P-DISUASION/REVISION-DS5.md` y `V-ZRX/LINEO.md`.

La orden manda: «Si detectas una falta de definición, infórmala antes de editar.» Nada de lo que
sigue **bloquea** la ejecución: cada punto se resuelve con una **decisión declarada** que viaja con
las tablas (columnas `s`, `atacante`, `censura`, y `escenarios.tsv`). Se distingue lo que es
colisión de notación (se resuelve renombrando) de lo que cambia el resultado (se publican las dos
lecturas). Nada se inventa: cada resolución cita su fuente.

---

## G1 · El `V` del enunciado NO es el `V` de SL-2 (colisión de símbolo, cambia el resultado)

- **Qué falta.** La orden §1 escribe la pérdida del infractor como `(1−s)·f·V` y el premio del
  incluidor como `s·f·V`. `ORDEN-SL1` §4.5 y `CONTRATO-EVIDENCIA-v0` (EV-19) usan
  `V(P, incidente)` = **saldo congelado del infractor**, y lo confiscado es `f·V(P, incidente)`.
  Pero el `V` de SL-2 (`escenarios.tsv`, resolución F6) es el **valor total del ataque**, que en la
  condición de disuasión aparece como `N_paid·κ·q_ev·L > V` y **no** como base de la confiscación.
  Leer la orden con el `V` de SL-2 daría un premio proporcional al valor del ataque, que contradice
  EV-23 (el premio es una fracción **de lo confiscado**) y el propio `min(V, techo(f·V))` de EV-19.
- **Resolución SL-2b (declarada).** En la orden, `f·V` = **parte confiscable** de la pérdida de
  SL-2: `C = f·(retenido + q_g)`, donde `retenido` es el saldo retenido según la vía P1/P2 (F5) y
  `q_g` la garantía por identidad (M1). El `V` de SL-2 (valor del ataque) **no** se toca. El premio
  al incluidor es `s·C`; la pérdida del no confabulado es `C`; la del confabulado es `(1−s)·C`.
  Todo el código nombra `C` como `parte_confiscable` para que la colisión no se repita.

## G2 · ¿El recargo fijo `c_r` entra en la rebaja `s`? (cambia un término, no el veredicto)

- **Qué falta.** La orden escribe la pérdida no confabulada como exactamente `f·V`, omitiendo el
  recargo `c_r` que SL-2 sí suma (`L = f·(retenido+q_g) + c_r`, resolución F1). EV-19 no tiene
  recargo: `pérdida = min(V, techo(f·V))`. El recargo no se reparte entre incluidor y quema.
- **Resolución SL-2b.** La rebaja `s` se aplica **solo** a la parte confiscable: 
  `L_conf = (1−s)·C + c_r`, `L_no = C + c_r`. Con `s=0` se reproduce SL-2 bit a bit. La lectura
  alternativa (rebajar todo `L`) solo difiere en `s·c_r ≤ 3,75 u.e.` con `s=3/8`,`c_r=10`; se
  documenta y no se implementa por separado (no puede invertir ningún veredicto de la rejilla).

## G3 · «Ambos atacantes»: cómo se parametriza la confabulación (cambia el resultado)

- **Qué falta.** La orden §1–§2 habla del infractor «confabulado con quien incluye» y del «no
  confabulado», y pide la región «para ambos atacantes», pero no dice qué magnitud cambia exactamente.
- **Resolución SL-2b.** Se añade `colude::Bool` a la calibración. `colude=false` = SL-2 (la
  disuasión usa `L_no`; con `s` arbitrario la pérdida del no confabulado no depende de `s`).
  `colude=true` = la disuasión usa `L_conf`. La **condición de honestidad** (borde superior
  `Tv_max`) usa siempre `L_no`: el honesto que firma dos veces por accidente **no** es un
  confabulado, así que no recibe la parte `s`. Consecuencia: el borde superior no cambia; el borde
  inferior `A` sube, y la región del confabulado es **subconjunto** de la del no confabulado.
  Además, el umbral de saldo «gratis» (F7) pasa a `x = ε/((1−s)·f·λ·T_v^eff)`: una clave con saldo
  casi nulo es aún más barata de reclutar si el confabulado recupera `s`. Se publica también la
  lectura que **no** toca `x` (solo la pérdida) y se comprueba que no cambia el signo.

## G4 · Modelo de inclusión y forma del barrido de censura `c` (cambia el resultado)

- **Qué falta.** La orden §3 pide «modelar la inclusión como segura en cuanto un honesto la ve» y
  barrer la fracción `c` de producción que censura la evidencia, pero no fija la forma funcional de
  `q_ev(c)`, ni el número de oportunidades, ni relaciona `c` con `Plazo_slots` (que SL-1 dejó
  simbólico y SL-2 no recibe).
- **Resolución SL-2b.** Se declara `q_inclusión(c, n) = 1 − c^n`, con `n` = nº de oportunidades
  independientes en que la prueba puede incluirse. **Lectura primaria y conservadora:** `n = 1`, es
  decir `q_ev = 1 − c` (una sola oportunidad; si el productor que ve la prueba es censor, se pierde).
  **Sensibilidad:** `n = F_slots` (la ventana de admisión efectiva, ≈1019 bloques) ⇒ `q_ev(c) ≈ 1`
  para todo `c<1`. `c=0` reproduce la hipótesis de la orden (`q_ev=1`, inclusión segura); `c=1` es
  censura total (`q_ev=0`). **Hipótesis declarada:** el premio `s·C` basta para que el productor
  honesto incluya; se advierte que si `C` es diminuto (`C < coste fijo de tx`) la hipótesis falla, y
  se marca como límite.

## G5 · Valores de `s` y control de reproducción (no cambia el resultado, lo fija)

- **Resolución SL-2b.** `s = 2/8 = 0,25` es el valor **ratificado** (DS-L03, Katana 2026-09-26).
  `s = 3/8 = 0,375` se publica **solo como sensibilidad** (valor descartado). `s = 0` es el
  **control** que debe reproducir SL-2 exactamente (tanto para `colude=false` como `colude=true`,
  porque con `s=0` no hay rebaja). Se comprueba contra `resultados/HUELLAS.sha256` de SL-2.

## G6 · Presupuesto y `Plazo_slots`

- La orden fija 1 h y 4 hilos; SL-2 ya declaró 8 GiB de RAM. `Plazo_slots` sigue sin valor: se usa
  `F_slots` como proxy **solo** en la sensibilidad `n=F_slots` de G4 y se declara que no es una
  decisión de contrato (esa es de SL-1).

---

## Lo que SL-2b **no** decide

- No fija `Plazo_slots` ni `M_margen_slots` (SL-1).
- No decide el destino de los fondos: **lo recibe** (DS-L03: 2/8 al incluidor, 6/8 quemado).
- No recalibra la viabilidad `R_slots > Plazo_slots + M_margen_slots` (EV-15/EV-15b).
- No modela el coste fijo de una transacción ni el mercado de comisiones (no hay mercado en ZEROX);
  solo advierte el límite de G4.
