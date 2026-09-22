# DEPENDIENTES — quién cita cifras de CRP-v0.1, y qué redacción proponen estos resultados

**Nada de este documento se ha editado en su origen.** Se listan las citas localizadas con
`grep -n` (verificación por lectura del contexto) y, para cada una, la redacción que **propongo** a
partir de `INFORME.md` y `CIFRAS.md`. Los ficheros citados son de solo lectura para esta auditoría.

**Etiquetas de estado de la cifra:** `S` = se sostiene · `C` = cambia · `X` = cae ·
`ND` = no determinable · `CC` = sostenida con la etiqueta corregida.

---

## 1 · `SPEC.md`

### 1.1 `SPEC.md:1709-1716` (§7.1.5, nota de C-FLU-13)

> «Si la validez del PoT fuese **relativa a la cadena seleccionada**, se abriría el
> **multistream** —`α_mínimo = 1/(S+1)`, medido en `veritas/seguridad/coste-rama-privada-v1/`—.»

- **Cifra:** `α_mínimo = 1/(S+1)`. **Estado: `CC`.**
- **Problema:** la palabra «medido». No se midió ningún flujo: se evaluó una fórmula aditiva
  (`copia/test/runtests.jl:72-76` compara la fórmula consigo misma, D7).
- **Redacción propuesta:**
  > «…se abriría el **multistream** —cuota aditiva `S·α/(1−α+S·α)`, que igualada a `1/2` da
  > `α_mínimo = 1/(S+1)`; es una **identidad condicional** al diseño del flujo, no una medición
  > (`veritas/seguridad/coste-rama-privada-v1/`, PROPUESTA.md P5)—.»

### 1.2 `SPEC.md:3782` (§17, fila «Prueba de espacio/tiempo»)

> «`veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1, 2026-09-18) mide `α_mínimo = 1/2` —el
> mismo que PoW y que GHOSTDAG sobre PoW— para el diseño con **un solo flujo**: la tasa de
> soluciones es `∝ SR` y el peso `∝ 1/SR`, así que el rango endógeno **se cancela** y no es
> explotable en media. Pero con `S` flujos de PoT simultáneos la cuota efectiva es
> `S·α/(1−α+S·α)` y el umbral cae a `α = 1/(S+1)`: **0,040 con `S = 24`**, que es el límite de
> IOPS de un SSD de 100 k, **sin espacio adicional**.»

- **Cifras:** `α_mínimo = 1/2` (`CC`), cancelación `∝SR`×`∝1/SR` (`C`, D4), cuota `S·α/(1−α+S·α)`
  (`S`), `0,040` con `S = 24` (`S` como aritmética, `X` la justificación de `S`, D9), «límite de
  IOPS de un SSD de 100 k» (`X`), «sin espacio adicional» (`S`).
- **Redacción propuesta:**
  > «…mide `α_mínimo = 1/2` **de media** para el diseño con **un solo flujo**: la tasa de
  > soluciones es `∝ SR` **bajo el supuesto declarado** de que el predicado PoAS sea
  > `solution_distance ≤ SR/2` con distancia uniforme (no es una identidad derivada en ese
  > instrumento; el residuo de paridad `1/(SR+1)` de PCO-v0.1 no está contado). Con `S` flujos de
  > PoT simultáneos, **si** la cuota fuese aditiva, `S·α/(1−α+S·α)` da `α = 1/(S+1)`: `0,040` con
  > `S = 24`. **`S = 24` es una cota aritmética citada (`⌊100000/4161⌋`), no una medición de IOPS
  > del instrumento.** El coste en CPU/PoT/IOPS, energía y recompensas renunciadas no está
  > contabilizado.»

### 1.3 `SPEC.md:3785` (§17, fila «Poda»)

> «…y, sobre todo, **el coste real de construir una rama privada con más `blue_work`**, que
> **ninguna auditoría ha medido** y que decide si esto es un problema de ingeniería o de consenso.»

- **Estado: `X`.** Contradice a `SPEC.md:3782`, dos líneas más arriba, y a `TAREAS.md` §2.1.
- **Redacción propuesta:**
  > «…y el **coste económico** de construir una rama privada con más `blue_work` (el **umbral**
  > medio sí está medido: `α_mínimo = 1/2`; el **coste** no: sólo el espacio está modelado, y la
  > duración, la energía y la recompensa renunciada no).»

### 1.4 `SPEC.md:2695-2697` (§13) — **no es dependencia**

> «La carrera histórica `prev(α,1,t,90,1)` … `7,071·10⁻³⁶` para `α = 0,33` y `1,148·10⁻¹⁰` para
> `α = 0,40` (`research/scripts/d12-quorum/salida_b.txt`).»

Fuente `research/scripts/d12-quorum/`, no CRP-v0.1. **Sin cambio.**

---

## 2 · `TAREAS.md`

### 2.1 `TAREAS.md:126-137` (§2.1, «Corrección del titular»)

> «…`1/(S+1)` —el **4 %** con `S ≈ 24`— se leyó como el umbral del diseño. **No lo es.** […] El
> propio instrumento ya lo etiquetaba así: CRP-v0.1 declaró su resultado «condicionado al diseño
> del flujo, no demostrado». El umbral que CRP-v0.1 midió con **un solo flujo** es
> `α_mínimo = 1/2`, el mismo que PoW…»

- **Estado:** `CC` + `X`. La corrección del titular (el 4 % es la regla aditiva) es **correcta y se
  sostiene**; «midió» es un sobre-enunciado en la misma dirección que D4/D5.
- **Redacción propuesta:** añadir tras «el mismo que PoW»:
  > «— **de media**, como frontera de deriva del modelo contable; el residuo de paridad del
  > predicado PoAS (≤ 4,9e-4 con `SR ≥ 2^11`) y la varianza de `SR` no la mueven, pero la curva
  > corta sí depende de ellos.»

### 2.2 `TAREAS.md:173-178`

> «`veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1) midió el coste de construir una rama
> privada con más `blue_work` … El diseño base aguanta. `α_mínimo = 1/2`, el mismo umbral que PoW
> y que GHOSTDAG sobre PoW, en los dos regímenes (reorg corta y *long-range*). El DAG aporta
> **menos varianza**, no menos umbral.»

- **Estado:** `X` en la primera frase («midió el coste»: sólo midió el umbral medio, y el coste
  económico no está contabilizado, D10); `CC` en la segunda; `S` en la tercera (reforzada).
- **Redacción propuesta:**
  > «…midió **la frontera de deriva de media** de construir una rama privada con más `blue_work`,
  > no su coste económico. […] El DAG aporta **menos varianza**, no menos umbral — con la tabla de
  > granularidad corregida, bastante **más** menos varianza de lo publicado (la publicada usaba un
  > déficit sin reescalar a la retícula).»

### 2.3 `TAREAS.md:179-183`

> «La tasa de soluciones válidas es `∝ SR` y el peso es `w(B) = ⌊2^128/(SR+1)⌋ ∝ 1/SR`: **el
> producto se cancela** … Lo que sí queda es un riesgo de **varianza** (fijar `sr` bajo compra cola
> con el mismo trabajo medio)…»

- **Estado:** `C` en la identidad (falta el residuo de paridad, D4); `C` en la cifra de varianza
  (D5: `2,2 %→30,8 %` es en realidad `2,13 %→31,50 %`).
- **Redacción propuesta:**
  > «La tasa de soluciones válidas es `A(SR) = 2⌊SR/2⌋+1` (que vale `SR+1` si `SR` es par y `SR` si
  > es impar) y el peso es `w(B) = ⌊2^128/(SR+1)⌋`: el producto **se cancela salvo un residuo de
  > paridad `1/(SR+1)`** y el residuo del suelo (`< 2^-64`). Lo que sí queda es un riesgo de
  > **varianza** (fijar `sr` bajo compra cola con el mismo trabajo medio: `P(adv>hon)` pasa de
  > `2,13 %` a `31,50 %` con `sr = sr0/64`, valor **exacto**, no muestreado).»

### 2.4 `TAREAS.md:184-186` y `2.5 TAREAS.md:196-199`

> «**El único vector medido que baja el umbral es el multistream de PoT** …»
> «Lo que CRP-v0.1 añade es el **número** y el haber comprobado que es el **único** vector medido
> que mueve el umbral.»

- **Estado:** `X` en «medido» y «comprobado» (D7).
- **Redacción propuesta:**
  > «El único vector **paramétrico** que baja el umbral es el multistream de PoT, **condicionado** a
  > que la cuota sea aditiva. Lo que CRP-v0.1 añade es el **número** `1/(S+1)`, no una comprobación
  > de que los flujos se sumen: su test compara la fórmula consigo misma.»

### 2.6 `TAREAS.md:187-194` (tabla multistream)

> «Cuota efectiva `S·α/(1−α+S·α)` ⟹ `α_mínimo = 1/(S+1)` … `S ≈ 24` es el techo de IOPS de un SSD
> de 100 k. **Coste: `S` núcleos e IOPS, cero espacio adicional.**»

- **Estado:** `S` la aritmética; `X` «S ≈ 24 es el techo de IOPS» (D9) y `X` «cero espacio
  adicional» como coste completo (D10).
- **Redacción propuesta:**
  > «…`S ≈ 24` es una **cota aritmética citada** (`⌊100000/4161⌋`), no una capacidad medida. Coste
  > modelado: **cero espacio plotteado adicional**. CPU/PoT/IOPS, energía y recompensas renunciadas
  > **no** están contabilizados.»

### 2.7 `TAREAS.md:207-210` («Lo que Claude acotó al validar»)

> «…el efecto de «rojos asimétricos» … queda **no medido** por el instrumento, pero con la **Δ
> medida** (0,26–0,60 s, 25× por debajo del primer escalón de la ronda 11a) la fracción roja
> honesta es 0,0000 y **el umbral no se mueve**.»

- **Estado:** `C` (D6). La conclusión se sostiene; la etiqueta «Δ medida» y el «25×» no.
- **Redacción propuesta:**
  > «…con la **Δ simulada** de `veritas/finalidad/delta-medido-v1/` (0,26–0,60 s, Δ_99 en su p99;
  > `MR` = medida en red ZEROX: ninguna disponible) — entre **6,7× y 15,4×** por debajo del primer
  > escalón de 4 s — la fracción roja honesta es 0,0000 y **el umbral no se mueve**. El hueco queda
  > acotado, no cerrado por medición directa.»

### 2.8 `TAREAS.md:469-474` (§2.9a)

> «El **umbral** está medido (`α_mínimo = 1/2`, CRP-v0.1); **la cola a `L = F_slots`, no**.»

- **Estado:** `CC`. «Medido» → «recalculado».
- **Redacción propuesta:**
  > «El **umbral de media** está recalculado (`α_mínimo = 1/2`, CRP-v0.1); **la cola a
  > `L = F_slots`, no**.»

### 2.9 `TAREAS.md:715-726` (§ ronda 11a)

> «La ronda 11a lo muestra con `k=30`: 0,0000 / 0,0020 / 0,0828 / 0,2858 a Δ = 4 / 8 / 12 / 16 s.»

- **Estado:** `C` (origen). Las fracciones están en `research/scripts/d9-ronda9a/r9a_a6_frontera_delta.py:31`
  (`DELTA0_MEDIDO`) y las reproduce `d9-ronda11a`; son simulaciones históricas con Δ fijada a mano.
- **Redacción propuesta:** citar `d9-ronda9a` (origen) y `d9-ronda11a` (reproducción), y añadir
  «simulación con Δ fijada a mano, no medida de red».

### 2.10 `TAREAS.md:902-906` (registro de reordenación)

> «…la regla de dependencias por flujo del PoT, que es el único punto medido que degrada el umbral
> (`α = 0,040` con `S = 24`).»

- **Estado:** `X` («medido», «degradación del umbral»). Sin cita del instrumento.
- **Redacción propuesta:** «…el único punto **paramétrico** que desplaza el umbral **si la cuota es
  aditiva** (`α = 1/(S+1)`; `0,040` con `S = 24`, cota aritmética).» Añadir la cita a
  `veritas/seguridad/coste-rama-privada-v1/`.

### 2.11 `TAREAS.md:552-558` (§2.9e) — **sin cambio**

> «CRP-v0.2 y CRP-v0.3 existen en `deepseek/` y NO están validadas ni migradas… §2.1 y `SPEC.md`
> §17 citan CRP-v0.1.»

Correcto y vigente. Esta auditoría lo confirma y añade que la v0.1 citada tiene los defectos aquí
documentados.

### 2.12 `TAREAS.md:237-242` — **no es dependencia de CRP-v0.1**

> «PCO-v0.1 demostró en `Rational{BigInt}` que el `SR` se cancela en todo instante … con una
> excepción: con `SR` impar queda un déficit de `1/(SR+1)`.»

Fuente = PCO-v0.1 (`veritas/consenso/puerta-cobertura-v1/`). **Sin cambio**, pero esta auditoría
usa precisamente ese resultado como contraste de D4.

---

## 3 · `veritas/seguridad/coste-rama-privada-v1/PROCEDENCIA.md` (del propio instrumento)

| línea | texto | estado | redacción propuesta |
|---|---|---|---|
| 6-7 | «el único cuyo veredicto principal sobrevive a la validación sin recortes» | `X` | «sobrevive **una** frase: la frontera de deriva de media es `1/2`. El paquete de cifras, etiquetas y el respaldo del fixture no sobreviven.» |
| 16 | «Curva corta `α_mín = 1/(1+ε^{−1/d})`, d = 3…50 — exacta ✓» | `C` | «exacta **para el evento de empate**; el contrato exige superación estricta: `1/(1+ε^{−1/(d+1)})`.» |
| 17 | «Cancelación `SR`: tasa `∝ SR`, peso `∝ 1/SR` — verificada ✓» | `C` | «la cancelación se sostiene en el orden dominante **bajo el supuesto** `λ ∝ SR`; el predicado exacto deja un residuo de paridad `1/(SR+1)`.» |
| 36 | «`α_mínimo = 1/2` exacto… en ambos regímenes» | `CC` | «`1/2` **de media**; la curva corta depende del residuo de paridad y de la varianza de `SR`.» |
| 45 | «`P(adv > hon)` sube de 0,022 a 0,308 con `K = 64`» | `C` | «`0,021302 → 0,314998` (exacto, sin Monte Carlo).» |
| 64 | «La Δ **medida** … es 0,26–0,60 s» | `X` | «La Δ **simulada** en `delta-medido-v1` es 0,26–0,60 s (`MR`: ninguna medida de red disponible).» |
| 64-65 | «unas 25 veces por debajo del primer escalón» | `X` | «entre 6,7× y 15,4× por debajo del primer escalón (4 s).» |
| 79 | «`S ≈ 24` es el límite de IOPS de un SSD de 100 k» | `X` | «`S ≈ 24` es la cota aritmética `⌊100000/4161⌋`; el instrumento **no** la mide.» |
| 79-80 | «Coste: `S` núcleos más IOPS, cero espacio adicional» | `X` | «Coste modelado: **cero espacio plotteado adicional**. CPU/PoT/IOPS, energía y recompensas renunciadas no están contabilizados.» |

---

## 4 · `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`

### 4.1 `T-ZRX/AGUJEROS-Y-SOLUCIONES.md:47`

> «Con `α = 0,45`, 400 slots: `P(gana)` **2,2 % → 30,8 %** con `sr0/64` | CRP-v0.1 §3»

- **Estado:** `C` (D5).
- **Redacción propuesta:**
  > «Con `α = 0,45`, 400 slots: `P(gana)` **2,13 % → 31,50 %** con `sr0/64` (valor **exacto**, sin
  > Monte Carlo) | CRP-v0.1 §3, recalculado en `P-ZRX/P-CRP1/auditoria/`»

### 4.2 `T-ZRX/AGUJEROS-Y-SOLUCIONES.md:46`

> «…con `S` flujos simultáneos la cuota efectiva es `Sα/(1−α+Sα)` y el umbral cae a `1/(S+1)` —
> **0,040 con `S = 24`** … | CRP-v0.1 §5»

- **Estado:** `CC` en la aritmética, `X` en `S = 24` como medición (D9).
- **Redacción propuesta:** añadir «(cuota **aditiva**, condicional; `S = 24` es cota aritmética
  `⌊100000/4161⌋`, no medida)».

### 4.3 `T-ZRX/AGUJEROS-Y-SOLUCIONES.md:35-42` y `:355`

> «…la frontera de deriva es `α_drift = 1/2` … (`veritas/seguridad/coste-rama-privada-v1/`,
> CRP-v0.1). **Pero eso NO es «el umbral de ZEROX es el 50 %»** …»
> «Declaran **sustituir la evidencia protocolaria de CRP-v0.1**, que es la que sostiene el
> `α = 1/2`»

- **Estado:** `S`. Es la lectura correcta y coincide con el veredicto de esta auditoría. **Sin
  cambio**; esta auditoría la refuerza.

### 4.4 `T-ZRX/AGUJEROS-Y-SOLUCIONES.md:38`

> «su DP de granularidad perdía casi toda la masa»

- **Estado:** `S` (es el cargo D2, confirmado). **Sin cambio.**

---

## 5 · `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md`

### 5.1 `SOLUCION-CANDIDATA-REUTILIZACION.md:174` (y sus tres copias congeladas en
`P-PRESTAMO/CANDIDATA.md:174`, `P-EQUIVOCACION/CANDIDATA.md:174`,
`P-PERMANENCIA/CANDIDATA.md:174`)

> «El `α* = 1/2` de CRP-v0.1 (`veritas/seguridad/coste-rama-privada-v1/`) es el caso `β = 0`»

- **Estado:** `CC`.
- **Redacción propuesta:** «El `α* = 1/2` de CRP-v0.1 … es el caso `β = 0` **de media** (frontera
  de deriva del modelo contable; no incluye el residuo de paridad del predicado ni la varianza de
  `SR`).»

### 5.2 `SOLUCION-CANDIDATA-REUTILIZACION.md:179`

> «una cota de IOPS, no el coste completo»

- **Estado:** `S`. Coincide con D9 y D10. **Sin cambio.**

---

## 6 · `P-ZRX/P-2.1/SINTESIS.md`

### 6.1 `P-2.1/SINTESIS.md:18-20`

> «**`1/(S+1)` (el «4 %») es la regla aditiva y no aplica bajo R-FIN-4/5**»

- **Estado:** `S`. **Sin cambio.**
- **Nota:** `SINTESIS.md` **no nombra CRP-v0.1**, pero es la fuente que esta auditoría usa en D6.

### 6.2 `P-2.1/SINTESIS.md:28`

> «**La Δ es simulada (DMS-v0.1), no medida en red.**»

- **Estado:** `S`. Es exactamente el contraste de D6 contra `PROCEDENCIA.md:64`. **Sin cambio.**

### 6.3 `P-2.1/SINTESIS.md:20-21`

> «Residuo: con `SR` impar hay un déficit `1/(SR+1)`, elegible; ≤ 4,9·10⁻⁴ con `SR_MIN = 2^11`,
> despreciable con rangos realistas.»

- **Estado:** `S`. Verificado exactamente (D4): `1/2050 = 4,878e-4`. **Sin cambio.**

---

## 7 · `PROMPT.md` de `P-ZRX/` que citan una cifra afectada

| fichero:línea | cita | estado | nota |
|---|---|---|---|
| `P-PRESTAMO/PROMPT.md:146` | «la **compra de varianza** con `sr` bajo que midió CRP-v0.1 §3 (`P` de 2,2 % a 30,8 % con `sr0/64`)» | `C` | usar `2,13 % → 31,50 %` (exacto) |
| `P-PRESTAMO/PROMPT.md:210-212` | lecturas obligatorias: `…/INFORME.md` §3, §4 y §6 | `C` | §4 («ataque gratis») y §6 (fila de color) caen; §3 cambia |
| `P-CRP/PROMPT.md:76` | «el «`α = 1/2`, igual que Bitcoin» de CRP-v0.1 se ha usado como titular» | `S` | es la formulación de la prohibición |
| `P-CRP/PROMPT.md:80-82` | «multistream era una identidad tautológica» | `S` | es D7, confirmado |
| `P-CRP1/PROMPT.md:80-82` | «la compra de varianza con `sr` bajo (`P` de 2,2 % a 30,8 %)» | `C` | idem |
| `P-CRP1/PROMPT.md:140-144` | tabla D5 con `0,022 / 0,097 / 0,244 / 0,308` | `C` | idem |
| `P-Y*` | sin citas | — | `P-POT`, `P-INTENTO`, `P-SEMBRADOR`, `P-ADELANTO`, `P-REVELACION`, `P-PARAMETROS`, `P-PROTOTIPO`, `P-PUERTA` no citan cifras de CRP-v0.1 |
| `P-2.1/historico/v1/CONTEXTO.md:17-27, 216-219` | `α_mínimo = 1/2`, `1/(S+1)`, `(1−f)/(2−f)` | `CC`/`X` | histórico; si se conserva, anotar la corrección |
| `P-FLUJO/propuesta/PROPUESTA-SPEC.md:356-363, 397, 1397, 2006` | «umbral `α = 1/2` por CRP-v0.1, **cola sin medir**» | `CC` | la lectura «cola sin medir» es correcta; el umbral es de media |
| `P-CIERRE/ejecucion/PLAN-SPEC.md:721-723` | «`α_mínimo = 1/(S+1)`, hasta 0,040 con `S ≈ 24`, **medido en** `veritas/seguridad/coste-rama-privada-v1/`» | `X` | «medido» → «identidad condicional»; `S ≈ 24` no medido |
| `P-CIERRE/ejecucion/PLAN-SPEC.md:1614` | «esa cifra no está cerrada: CRP-v0.2 declara…» | `S` | correcto |

---

## 8 · Ficheros que **no** requieren cambio

- `P-ZRX/P-CRP1/PROMPT.md` y `ENTRADA.sha256`: solo lectura, verificados 37/37.
- `P-ZRX/rescate-deepseek/encargos/ENCARGO-07-coste-rama-privada.md`: es el encargo original; su
  §4.1 ya está corregido en `PROCEDENCIA.md` §4.1.
- `P-ZRX/rescate-deepseek/encargos/ENCARGO-07v2-coste-rama-privada.md`: es la lista de cargos;
  esta auditoría confirma 9 de 10 y añade D11–D15.
- `veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1) y `veritas/consenso/ghostdag-rank-v1/`
  (GDR-v0.2): usados como contraste independiente; sus cifras no se ven afectadas.

---

## 9 · Nota de método

Todas las localizaciones se hicieron con `grep -n` sobre el árbol y se **verificaron leyendo el
contexto** (el encargo prohíbe citar un archivo o una línea sin abrirlos). Los falsos positivos
descartados están listados: `P-PUERTA/.../INFORME.md:210` (0,02267 de PCO-v0.1),
`P-2.1/.../ancla-inyeccion-v2/INFORME.md:57` (0,097 de ANCLA-v0.2),
`rescate-deepseek/.../curva-lambda3.txt:9` (0.0226472) y `SPEC.md:2695-2697` (d12-quorum).
