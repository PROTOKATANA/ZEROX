# DS-5 — Castigo correlacionado (M4) contra el doble farmeo y la equivocación

**Ejecutor:** subagente Sonnet (análisis; aritmética de comprobación en Julia, sin Python).
**Fecha:** 2026-09-26. **Orden:** `P-ZRX/P-DISUASION/ORDEN-DS5-CORRELACIONADO.md`. **Marco:**
`P-ZRX/P-DISUASION/MARCO.md`. **Leído íntegro antes de escribir:** `MARCO.md`,
`ORDEN-DS5-CORRELACIONADO.md`, `SINTESIS.md`, `REVISION-DS1.md`…`REVISION-DS4.md`,
`resultados-DS1/INFORME.md`, `resultados-DS2/MODELO.md`, `DS3/INFORME.md`,
`DS3/escenarios.tsv`, y — porque resultó ser el objeto real de la orden — `D-ZRX/SPEC.md` §5
(familia `C-SLA`, ya especificada) y `D-ZRX/IPA-ZRX.md` fila `C-05`.

**Hallazgo de encuadre, antes de responder nada:** M4 (castigo correlacionado) **ya está
especificado** en ZEROX, no es hipotético: `D-ZRX/SPEC.md` §5, familia `C-SLA` (`C-SLA-01` a
`C-SLA-04`), con fórmula exacta. `D-ZRX/IPA-ZRX.md` fila `C-05` lo marca **abierto** — «SPEC lo
declara "no implementable" hasta cerrar codificación y presupuesto» — con el riesgo ya anotado
por el propio director: **«castigo catastrófico por error compartido»**. Esta orden formaliza y
cuantifica exactamente ese riesgo, y comprueba si cierra la grieta de DS-3.

---

## 1. Veredicto de la pregunta falsable

> «¿Existe una forma de castigo correlacionado que encarece de forma **exigible** A1 o A2 frente
> al atacante grande de DS-3, sin elevar el castigo esperado de un honesto con fallos
> correlacionados por encima de su ingreso?»

**REFUTADA**, para toda forma de M4 que — como la ya especificada en `C-SLA-03` — calcule la
pérdida como `perdida(P,e) = min(V(P,e), techo_exacto(f_e·V(P,e)))`, es decir, que **multiplique
o escale el saldo confiscable ya existente** en vez de crear una obligación nueva independiente
de él. La cota `perdida ≤ V(P,e)` es **algebraica**, no depende de `f_e`: si `V(P,e)` es
pequeño (la grieta de DS-3: el atacante recluta claves con saldo `< ε = 0,01` u.e.), ninguna
función de correlación, por agresiva que sea (`f_e = 1`, confiscación total), puede extraer más
de lo que hay. Comprobado numéricamente en `resultados-comprobacion.txt` §1: con `N_recl = 279`
(escenario DS-3, `α=0,33, P*=10⁻³`) y `ε_saldo = 0,01`, la pérdida máxima **agregada** bajo `f_e=1`
es `2,79` u.e., frente a un soborno nominal total de `279 × 1830 ≈ 510.570` u.e. — una razón de
`5,46·10⁻⁶`. **El atacante grande no lo nota.**

**Lo que sí alcanza** (acotado, como pide la orden): la intersección de tres condiciones — (a)
la falta llega a la cadena seleccionada (`κ·q > 0`, RFT-01/RFT-09 no violadas), (b) la clave
tiene saldo confiscable positivo (`V(P,e) > ε`, es decir el atacante **no** laundó por el hueco
de P-CLAVE), y (c) coincide en la misma cohorte con otras faltas. Esa intersección es un
**subconjunto estricto** de lo que ya cubre M3 sin correlación (DS-2/DS-3: «disuade solo al
atacante pequeño»); M4 no amplía esa frontera, solo puede **multiplicar** el castigo dentro de
ella. Fuera de ella (atacante grande que recluta por debajo de `ε`, o que no publica), M4 es
matemáticamente inerte.

---

## 2. ¿M4 elimina la premisa de RFT-01 o la grieta de DS-3?

**No, ninguna de las dos.** Con demostración, no solo con la respuesta:

- **RFT-01** («la rama privada no deja evidencia; ningún depósito la castiga»). M4 solo
  **reescala** un castigo que ya presupone que existe una `EvidenceTx` admitida (`C-EVP-02` a
  `C-EVP-05`) dentro del plazo `cierre_e` (`C-SLA-01`). No crea ningún mecanismo nuevo para
  *forzar* la publicación de la segunda cabecera. `D-ZRX/SPEC.md` §7 lo dice literalmente en su
  propia tabla: «Rama privada que nunca revela una segunda firma → No. Ninguna por C-SLA.» M4
  hereda intacta la premisa de RFT-01: **sin evidencia, cero castigo, correlacionado o no.**
- **La grieta de DS-3** (`β_d ≤ B(ε)=0,675 < 1`: el atacante recluta claves con saldo `< ε` y
  paga soborno **0**). Demostrado en §1: `perdida(P,e) ≤ V(P,e)` es un techo algebraico de
  `C-SLA-03` — correlacionar no inventa saldo. El propio `C-SLA-04` de SPEC ya lo admite sin
  cuantificarlo: «C solo incrementa el castigo **respecto a una base positiva**... Un atacante
  puede espaciar faltas, censurar pruebas o repartir claves» — exactamente la estrategia que
  cruza la grieta. DS-5 lo cuantifica: incluso en el caso más punitivo (`f_e=1` para las 279
  claves), la pérdida agregada es `2,79` u.e. sobre un ataque que vale `510.570` u.e. de soborno
  evitado.
- Añadido no pedido pero relevante para no repetir el error del director en DS-2 (ratificar sin
  rehacer la cuenta): **tampoco hay ninguna vía en sistemas de prueba de espacio** que preceda a
  M4. Ni Chia, ni SpaceMint, ni Autonomys tienen *ningún* castigo (§3), correlacionado o no
  (`resultados-DS1/INFORME.md` §1.2, §1.3, §2). M4 es un trasplante puro de Ethereum PoS
  (`eth2book.info`) a un PoSpace, sin precedente en la familia que DS-1 investigó.

---

## 3. Fuentes: penalización correlacionada de Ethereum

**Verificado por mí (no solo heredado de DS-1):** descargué y leí
`https://eth2book.info/latest/part2/incentives/slashing/` el 2026-09-26
(`deepseek/DS5/eth2book-slashing.html`, sha256 `901ab55a…4928cb`). Fórmula exacta, ventana y
multiplicador coinciden con `resultados-DS1/INFORME.md` línea 81 (dado por DS-1 como `[P]`):

> `Correlation penalty = min(B, 3SB/T)`, con `S` = suma de saldos efectivos de todos los
> validadores sancionados en los 36 días alrededor (18 antes / 18 después,
> `EPOCHS_PER_SLASHINGS_VECTOR = 8192` épocas), `T` = saldo activo total, multiplicador `3` desde
> la mejora Bellatrix (era 1 en génesis, 2 en Altair).

**Hallazgo que DS-1 no reportó y que es directamente relevante para el efecto adverso (§5):** la
misma fuente primaria dice, textualmente, que en la historia real de Ethereum **la penalización
correlacionada nunca ha superado cero**: *"as it happened, no correlated slashings occurred that
incurred a penalty greater than zero under this mechanism"*. Es decir: incluso los dos incidentes
de *slashing* masivo documentados por DS-1 (2021-02-04, 75 validadores de Staked Inc.; 2025-09-10,
39 validadores de SSV Network) — ambos fallos **honestos** de infraestructura compartida, no
ataques — no alcanzaron a activar el término de correlación, porque `3S/T` se quedó por debajo de
1 en una red de ~1 millón de validadores. **Esto es evidencia empírica de que el mecanismo, tal
como está calibrado en Ethereum, solo muerde cuando `S` es una fracción sustancial de `T`** — y
que una red pequeña o concentrada (como ZEROX en su arranque, sin `H-PUENTE` medido y sin
distribución de tamaños de clave medida, H3) corre más riesgo de que un incidente honesto sí la
alcance, precisamente porque su `T` es chico. Ninguna propuesta análoga existe en un sistema de
espacio (§2, confirmado con DS-1).

---

## 4. Modelo: dos formas de M4

### Forma M4-1 — la ya especificada (`C-SLA-03`, cuenta de claves)

Literal de `D-ZRX/SPEC.md` §5, no una construcción mía:

```
n_e   = número de claves P distintas con caso admisible (P,e)
f_e   = min(1, b + c·max(0, n_e−1))          0 < b ≤ 1, c ≥ 0   [b, c PENDIENTES en SPEC]
V(P,e)= saldo congelado remanente de P antes de liquidar e
perdida(P,e) = min(V(P,e), techo_exacto(f_e·V(P,e)))
```

Escala con el **número de claves distintas** en la cohorte, no con cuánto saldo mueven.

### Forma M4-2 — réplica funcional de Ethereum (fracción de saldo, no especificada en ZEROX)

Construida por DS-5 para comparar, mismo molde `perdida = min(V, f_e·V)`:

```
S_e   = suma de saldo confiscable de todas las claves sancionadas en la cohorte e
T     = saldo activo total de la red
f_e   = min(1, γ·S_e/T)                       γ = 3 (valor de Ethereum) u otro
```

Escala con la **fracción de garantía total** que falla junta, como pide literalmente la pregunta
falsable de la orden («la sanción crece con la fracción de garantía que comete la misma falta»);
`C-SLA-03` en cambio escala con la **cuenta de identidades**, no con la garantía — una diferencia
de diseño con consecuencias distintas (§5).

### Comprobación aritmética (Julia, `deepseek/DS5/comprobacion.jl`)

Script de comprobación (no una auditoría LINEO completa — no hay kernel de rendimiento que
optimizar aquí, es álgebra de una fórmula ya cerrada; declarado así para no inflar el género del
entregable). Ejecutado con `julia 1.13.0` (`torio/.juliaup`), sin hilos ni GPU, `Float64` para
exploración cualitativa (no certifica un umbral de consenso; donde el signo importa —§1— el
resultado es una desigualdad algebraica exacta, no del redondeo). Salida completa en
`resultados-comprobacion.txt` (sha256 `33fb2949…5aa392`; script sha256 `2ab29ffe…6620768e0`).

Resultados relevantes (véanse también §1 y §5):

| # | Pregunta | Resultado |
|---|---|---|
| 1 | Pérdida máxima agregada bajo la grieta (`f_e=1`, 279 claves, `ε=0,01`) | `2,79` u.e. frente a `510.570` u.e. de soborno evitado (razón `5,46·10⁻⁶`) |
| 2 | M4-1 con `b=0,1, c=0,01`: ¿satura `f_e=1` antes de `n_e=100`? | Sí (`n_e=100 → f_e=1,0`; `n_e=10 → f_e=0,19`) |
| 3 | M4-2 con `γ=3`, `T=10⁶`: ¿satura con `S_e≈T/3`? | Sí (`S_e=334.000 → f_e=1,0`), igual que el diseño de Ethereum (cap en `1/3`) |
| 4 | Umbral de `c` para que un fallo honesto compartido (`p_share` de `N_activos`) no sature `f_e=1` | Cae como `1/(p_share·N_activos)`: con `N_activos=10.000` y `p_share=0,05` (500 claves), `c` debe ser `< 0,0018` para no saturar con `b=0,1` |

---

## 5. Tabla de celdas (ataque × forma de M4), veredictos del marco (`I`/`E`/`N`/`W`)

| Ataque | M4-1 (`C-SLA-03`, cuenta `n_e`) | M4-2 (fracción de saldo `S_e/T`) |
|---|---|---|
| **A1 — doble farmeo, atacante grande (laundering por debajo de `ε`)** | **N** (no exigible): `perdida ≤ V ≈ 0`, `f_e` es irrelevante. Δ = 0 frente a B0, igual que M3+M5 solo (DS-3 §4.1). No cierra la grieta. | **N**, mismo argumento: `perdida ≤ V`. Además `S_e` también es pequeño (suma de saldos casi nulos), así que ni siquiera dispara `f_e` alto. |
| **A1 — doble farmeo, atacante que NO laundea (`V>ε`)** | **E condicionado**: si además se detecta (`κ·q>0`) y coincide con otras faltas, `f_e>b` añade un múltiplo sobre lo que M3 ya cobraría. No es una celda nueva: sigue dependiendo de publicación (RFT-01) y es un subconjunto de lo que M3 solo ya alcanza. | **E condicionado**, mismo alcance; además requiere que `S_e/T` sea no trivial, lo que en una red concentrada (pocos operadores grandes) es más fácil de alcanzar que en una fragmentada — **incentiva partir el ataque en más operadores pequeños para diluir `S_e/T`**, el efecto inverso al de M4-1. |
| **A2 — equivocación publicada, `m≤0,05` (atacante pequeño, `κ=1`)** | **E condicionado**, igual que M3 (DS-3 §4.1b: soborno nominal se compra a coste 0 salvo que `V>ε`); M4-1 solo sube el múltiplo si además hay más claves en la cohorte. | **E condicionado**, igual, escala con `S_e/T` de la cohorte. |
| **A2 — equivocación, `m≥4` (atacante grande)** | **N**: `κ(m=4)=0` (P-EQUIVOCACION, tabla exacta de `MODELO.md` §2.6) — la evidencia no llega a la cadena seleccionada. `f_e` nunca se evalúa. | **N**, mismo motivo. |
| **Honesto con fallo correlacionado (software/proveedor común), C-05** | **W** — empeora: `f_e` depende solo de **cuántas** claves fallan juntas, sin distinguir malicia (`C-SLA-04` ya lo admite). Con `N_activos` grandes, basta una fracción pequeña (`p_share`) de fallo compartido para saturar `f_e=1` salvo que `c` sea muy pequeño (tabla §4.4). Es el riesgo que `IPA C-05` ya anota: «castigo catastrófico por error compartido». | **W**, pero **menos severo a igualdad de red grande**: escala con saldo agregado, no con cuenta de claves, así que muchas claves pequeñas fallando juntas (el caso típico de un bug de software entre operadores pequeños) mueve poco `S_e/T` salvo que esas claves controlen una fracción real de la garantía total — el propio historial de Ethereum (§3) muestra que esto nunca ha bastado para activar el término, ni en los dos incidentes reales documentados. |
| **Denuncias falsas / *griefing*** | **W**: quien controla varias claves propias sin saldo puede fallar deliberadamente **junto a un tercero honesto** en la misma cohorte para inflar `n_e` y así el `f_e` que le cae al tercero (que sí tiene saldo). Vector nuevo, introducido por la correlación misma; no existe bajo M3 sin correlación. | Mismo vector, pero requiere inflar `S_e` (saldo, no cuenta): más caro para el atacante (necesita mover saldo real, no solo abrir claves), **mitiga parcialmente el *griefing*** frente a M4-1. |
| **Incentivos a la concentración** | **W**: `f_e` depende de `n_e` (número de identidades), no del tamaño; consolidar en **menos claves más grandes** reduce `n_e` y por tanto `f_e` para un mismo volumen de espacio atacante — tensión directa con la resistencia a Sybil que se busca en otras partes (M1, `C-07`; ver memoria «P-IDENTIDAD refuta la mejora de identidad»). | **N/leve**: `f_e` depende del saldo agregado, no de cuántas identidades lo portan; consolidar no reduce `S_e`. No repite el incentivo perverso de M4-1. |

**Lectura de la tabla:** ninguna celda de A1/A2 contra el atacante grande pasa de **N**; las
únicas celdas **E** son **condicionadas** y **subconjunto** de lo que M3 sin correlación ya
alcanzaba; las únicas celdas **nuevas y ciertas** que aporta M4 son **W** (empeora): castigo a
honestos correlacionados, un vector de *griefing* que no existía sin correlación, y — solo en la
forma ya especificada en SPEC (M4-1) — un incentivo a concentrar identidades que contradice el
objetivo de M1/`C-07`. **M4-2 (fracción de saldo) dominaría a M4-1 (cuenta de claves) en las
celdas W**, si se decide construir M4 en algún momento — pero ninguna de las dos cierra A1/A2.

---

## 6. Efectos adversos (detalle, con la cuantificación pedida en la orden)

1. **Castigo a honestos correlacionados (fallo de software o proveedor común).** Es el riesgo que
   `IPA-ZRX.md` fila `C-05` ya tiene anotado como razón de que SPEC declare `C-SLA-03` «no
   implementable». DS-5 lo cuantifica por primera vez con una desigualdad simple: con M4-1 y
   `b=0,1`, un fallo compartido que alcanza una fracción `p_share` de `N_activos` claves activas
   satura el castigo máximo (`f_e=1`, confiscación total de `V(P,e)` para **cada** clave
   afectada, sin distinguir intención) en cuanto `c > 1/(p_share·N_activos − 1)` — con
   `N_activos=10.000` y un bug que afecte al `5 %` de la red (500 claves, un escenario realista
   para "misma versión de software"), eso es `c > 0,0018`. Como `c` es un parámetro de consenso
   sin calibrar (`PENDIENTE` en SPEC), **hoy no hay ninguna garantía de que quede por debajo de
   ese umbral**. Con M4-2 el riesgo es menor a igual tamaño de red (escala con saldo, no con
   cuenta), pero no desaparece si la red es pequeña o concentrada — que es exactamente el estado
   actual de ZEROX (sin `H-PUENTE`, sin distribución de tamaños de clave medida).
2. **Denuncias falsas / *griefing* nuevo, que no existe sin correlación.** Bajo M3 solo, cada
   clave responde por su propio saldo; bajo M4-1, un atacante que ya tiene claves sin saldo puede
   fallar **deliberadamente junto a un tercero honesto** en la misma ventana `Q_corr_slots` para
   inflar `n_e` y así el `f_e` — y por tanto la pérdida en u.e. — que le cae **al tercero**, sin
   coste real para el atacante (sus propias claves no tienen nada que perder). Esto es un
   mecanismo de daño dirigido que **no existía** antes de introducir la correlación. M4-2 lo
   mitiga parcialmente porque inflar `S_e` exige mover saldo real, no solo abrir claves.
3. **Incentivo a concentrar identidades (solo M4-1).** Como `f_e` depende de `n_e` (cuenta de
   claves), un mismo volumen de espacio atacado paga menos castigo correlacionado si se opera
   desde **menos** identidades más grandes. Esto **contradice** el objetivo de M1/`C-07`
   (barrera de entrada por identidad contra Sybil) y la conclusión ya cerrada en la memoria
   «P-IDENTIDAD refuta la mejora de identidad»: cualquier partición de identidad ya aporta poco
   (`≈0,6 %`), y M4-1 encima **premia** no particionar. No se detectó este efecto en ningún
   documento previo del proyecto; es un hallazgo de DS-5.

---

## 7. Reservas

- **`b`, `c`, `Q_corr_slots`, `γ` son PENDIENTES/hipotéticos.** `SPEC.md` no fija `b`/`c`; DS-5
  usa valores ilustrativos (`b∈{0,05;0,1}`, `c∈{10⁻⁴;10⁻³;10⁻²}`) solo para mostrar el orden de
  magnitud del umbral de saturación, no como recomendación de calibración.
- **`H-PUENTE` no existe** (recordado ya en DS-3 y `resultados-DS2/MODELO.md` §5): toda cifra en
  u.e. de este informe hereda esa condición; los **cocientes** (razón `5,46·10⁻⁶`, razón `1/32`
  de Ethereum, etc.) son robustos a esa falta de puente porque son adimensionales, las cifras
  absolutas en u.e. no lo son.
- **`f_e_saldo` (M4-2) es una construcción de DS-5**, no una propuesta con precedente en un
  sistema de espacio ni especificada en `D-ZRX/SPEC.md`; se ofrece como comparación de diseño,
  no como candidata lista para adoptar.
- **No se modeló el espaciamiento temporal de faltas** (`C-SLA-04`: «un atacante puede espaciar
  faltas... o repartir claves») de forma cuantitativa: `MODELO.md` no da una función que ligue
  `Q_corr_slots` con la probabilidad de que dos faltas del mismo atacante caigan en cohortes
  distintas a propósito. Queda **no cuantificado**, declarado como tal (convención DS-3).
- La comprobación de §4 es aritmética de apoyo, no una auditoría LINEO completa (no hay
  rendimiento que perfilar en una fórmula `min`/lineal evaluada unas pocas veces); se declara así
  para no simular un rigor de auditoría que el problema no requiere.

---

## 8. Ruta del informe y archivos

- `deepseek/DS5/INFORME.md` — este documento.
- `deepseek/DS5/comprobacion.jl` — script de comprobación (sha256 `2ab29ffee676a4ee174ce7abb07e1115f8db11081a3edd507cddf526620768e0`).
- `deepseek/DS5/resultados-comprobacion.txt` — salida completa, con versión de Julia y máquina (sha256 `33fb2949cfdc0dc005ba1e1216bd4ec96b8bb90226b5aff09ce48f5a125aa392`).
- `deepseek/DS5/eth2book-slashing.html` — fuente primaria descargada y leída (sha256 `901ab55a7b43c6195e0e8e12f31a85376d2f58bfaaf85b1daa47e5a2144928cb`), verificación directa de la fórmula de penalización correlacionada de Ethereum citada en `resultados-DS1/INFORME.md`.
- Fuentes internas citadas: `D-ZRX/SPEC.md` §5 (`C-SLA`), `D-ZRX/IPA-ZRX.md` fila `C-05`,
  `D-ZRX/RFT-ZRX.md` RFT-01/RFT-09, `resultados-DS2/MODELO.md` §1–§2.6, `DS3/INFORME.md` §4.1–§4.1b.
