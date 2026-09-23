# INFORME — P-SEGUNDO-VDF · SDV-v1

> **Revisión independiente, 2026-09-23: conclusión principal no validada.** El modo
> `revelacion_paralela` elimina la latencia secuencial después de conocer la semilla. Por ello,
> el 0,00 % y el veredicto «dos líneas anulan la mejora» son un contrafáctico de revelación
> inmediata, no un ataque causal demostrado. Las tablas originales se conservan como salida del
> instrumento; véase [REVISION-CODEX.md](REVISION-CODEX.md) antes de usarlas.

**Pregunta.** Para cada escenario de adversario y red declarado, ¿cuánto reduce una segunda cadena
secuencial AES de revelación retardada (`R-FIN-14(h)`) la ventana de adelanto `V` (en slots) y el
sesgo del ancla, y qué coste exige al timekeeper, al nodo que verifica, al que se incorpora tarde y
a quien adopta un flujo rival? ¿Hay una región de parámetros **realizable** donde la mejora sigue en
pie bajo el mismo riesgo y escenario?

**Instrumento.** `veritas/seguridad/segundo-vdf-v1` (SDV-v1), Julia 1.13.0 en CPU (`znver5`,
Ryzen 9 9950X3D, 16 núcleos / 32 hilos). Categoría `seguridad`; secundarias `consenso`, `red`,
`rendimiento`. Presupuesto: 24 hilos, 64 GiB RAM, 8 GiB disco; consumido ≈3,3 s de pared (más
≈45 s de JIT), <1 GiB, <1 MiB. Control externo: REV-v1.0 y ADL-v1.0, conservados sin reescribir.

**Ningún parámetro se adopta.** `ρ_max`, `I`, `Lrev`, `F`, `L_suelo`, `D`, `N(s)`, `W_dec` y `α`
siguen siendo símbolos. No se modifica el SPEC.

---

## 1 · Beneficio y hardware, bajo el mismo escenario

Escenario único para todas las filas: `L = 7 200` slots, `S_max = 150`, `W_dec = 20 s = 20` slots
(`τ_nom = 1 s/slot`), `Lrev = L − S_max = 7 050`, `D = 4`, `ρ = 2,5`, `α = 0,33`, `J = 1 500`
épocas, 64 réplicas, offset geométrico truncado (λ = 0,2), `verify = 96,1 ms/slot`,
`prove = 1 561 ms/slot`. Cada fila usa **un solo `I`** para la ventana, la edad y el coste.

| Fila | `I` (slots) | `ρ*` | `V_sin` (slots) | `V_con` (slots) | `ΔV/V_sin` | q99 sin → con | factor edad | líneas timekeeper | núcleos/nodo verificador | iny/h | Estado |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Publicada, ventana (`F1/F2`) | 851 | 9,071 | 7 685,6 | 4 865,6 | **36,69 %** | 8 800 → 5 712 (F4) | 1,54× | — | — | — | escenario, **no** parámetro |
| Publicada, coste (`F3/D2`) | 4 766,7 | 2,469 | — | — | — | — | — | 3 | 0,241 | 0,76 | **no cumple `ρ* ≥ 2,5`** |
| **Consistente, `I = 851`** | 851 | 9,071 | 7 685,6 | 4 865,6 | **36,69 %** | 9 280 → 6 528 | 1,42× | **10** | **0,8927** | 4,23 | medido |
| **Consistente, `I` calibrado** | **4 666** | 2,5002 | 9 974,6 | 7 154,6 | **28,27 %** | 19 072 → 16 256 | 1,17× | **3** | **0,2414** | 0,77 | medido |
| **Consistente, régimen paralelo** | 4 666 | 2,5002 | 9 974,6 | 9 974,6 | **0,00 %** | — | — | 3 | 0,2414 | 0,77 | medido |

Lectura de la tabla:

1. **La fila publicada mezcla dos `I`** (defecto 2): la ventana `7 685,6 → 4 865,6` y la edad
   `8 800 → 5 712` usan `I = 851`; el coste `0,241 núcleos + 3 líneas` usa `I ≈ 4 766,7`. Al
   unificar, el beneficio baja de **36,69 %** a **28,27 %** y el coste pasa a ser el calibrado
   (0,2414 núcleos, 3 líneas) — que es más barato, pero para **otro `I`**.
2. **La fila de coste publicada no cumple el criterio con el que se calibró** (defecto 1, §3).
3. **El beneficio se anula si el adversario dedica `⌈Lrev/I⌉` líneas a precomputar la revelación**
   (§5): 9 líneas con `I = 851`, **2 líneas con `I = 4 666`**, frente a las 10/3 líneas del
   timekeeper.
4. Comparar `V` entre filas con distinto `I` no es comparar escenarios: `V_sin` **crece** con `I`
   (7 685,6 → 9 974,6), luego el cociente `ΔV/V_sin` mejora al calibrar, pero la ventana absoluta
   con `(h)` empeora (4 865,6 → 7 154,6). Publicar el cociente sin la ventana absoluta induce a
   error.

## 2 · Veredicto por alcance

| Alcance | Veredicto | Base |
|---|---|---|
| Frontera de calibración `I ≤ (Lrev − ρ_max·W_dec)/(ρ_max−1)` con `I` entero | **VALIDADO EN EL MODELO** | derivación exacta + control (16 tests) |
| `(h)` reduce `V` bajo adversario **monolineal** | **VALIDADO EN EL MODELO** | `ΔV/V_sin` 28,27 % a `I` calibrado; 36,69 % a `I = 851` |
| Par beneficio+coste tal como se publicó (`F1/F2` con `F3/D2`) | **REFUTADO** | mezcla `I = 851` (ventana) con `I ≈ 4 767` (coste) |
| Calibración (h.6) tal como se publicó | **REFUTADO** | `ρ*(4 767) = 2,4686 < 2,5`: no cumple su criterio |
| La segunda cadena fortalece ZEROX frente a un adversario con `≥ ⌈Lrev/I⌉` líneas libres | **REFUTADO** | reducción medida **0,00 %**; precio 2 líneas (vs 3 del honesto) |
| La elección de semilla (h.1 vs `C-FLU-12`) como palanca de ventana | **REFUTADO (en el modelo)** | diferencia 0,0000 en los tres patrones de ancla |
| «Basta cambiar `C-FLU-12`» | **REFUTADO** | 22 IDs afectados (§7) |
| Coste real de la segunda cadena en la primitiva auditada | **INCONCLUSO / PENDIENTE** | `T = 339,1× u32::MAX`; segmentar cambia la clave (§6) |
| `ρ_max` real, `W_dec` y `α` en red, traducción a finalidad económica, `PRESUP_NODO` | **INCONCLUSO** | sin medición |

**Ninguno de estos veredictos significa «regla lista para producción».**

## 3 · Defecto 1 — calibración (h.6), derivada de nuevo

La candidata fija `Lrev = L − S_max` y usa `ρ* = (Lrev + I)/(I + W_dec)`, pero calibra `I` con `L`
en el numerador. Derivación correcta, con unidades (todo en slots) y enteros:

```
ρ* ≥ ρ_max  ⇔  (Lrev + I)/(I + W_dec) ≥ ρ_max
            ⇔  Lrev − ρ_max·W_dec ≥ (ρ_max − 1)·I          (ρ_max > 1)
            ⇔  I ≤ (Lrev − ρ_max·W_dec)/(ρ_max − 1)
I entero  ⇒  I_max = ⌊(Lrev − ρ_max·W_dec)/(ρ_max − 1)⌋
```

**Control obligatorio** (`L = 7 200`, `S_max = 150`, `W_dec = 20 s = 20` slots, `ρ_max = 2,5`):

| Cantidad | Fila histórica | Frontera corregida |
|---|---:|---:|
| numerador | `L − ρ_max·W_dec = 7 150` | `Lrev − ρ_max·W_dec = 7 000` |
| frontera | `4 766,67` | `14 000/3 = 4 666,67` |
| `I` publicado / entero | **4 767** | **4 666** |
| `ρ*` | `11 817/4 787 = 2,4686` | `5 858/2 343 = 2,500213` |
| `ρ* ≥ 2,5` | **NO** | **SÍ** |

La fila histórica **no cumple su propio criterio**: usa 100 slots de más (exactamente
`S_max/(ρ_max−1) = 100`). Otras restricciones vigentes: `I ≥ ρ_max·W_dec = 50` (R-FIN-14(f)),
`I > S_max = 150` (C-FLU-09) ⇒ `I_min = 151`; puntualidad honesta discreta
`Lrev ≤ L − W_dec − D − 1 = 7 175` ⇒ holgura **125** slots (se cumple); `I` se cuenta en slots
enteros y el documento no fijaba la regla de redondeo, que aquí es `⌊·⌋`.

**Sensibilidad a `ρ_max` (frontera correcta, ninguna fila se adopta):**

| `ρ_max` | frontera | `I_max` | `I_min` | admisible | `ρ*` en la frontera | líneas | núcleos | iny/h |
|---:|---:|---:|---:|---|---:|---:|---:|---:|
| 1,2 | 35 130,00 | 35 130 | 151 | sí | 1,2000 | 2 | 0,1154 | 0,10 |
| 1,5 | 14 040,00 | 14 040 | 151 | sí | 1,5000 | 2 | 0,1444 | 0,26 |
| 2,0 | 7 010,00 | 7 010 | 151 | sí | 2,0000 | 3 | 0,1928 | 0,51 |
| 2,5 | 4 666,67 | 4 666 | 151 | sí | 2,5002 | 3 | 0,2414 | 0,77 |
| 3,0 | 3 495,00 | 3 495 | 151 | sí | 3,0000 | 4 | 0,2901 | 1,03 |
| 5,0 | 1 737,50 | 1 737 | 151 | sí | 5,0011 | 6 | 0,4864 | 2,07 |
| 9,0 | 858,75 | 858 | 180 | sí | 9,0068 | 10 | 0,8862 | 4,20 |
| 12,0 | 619,09 | 619 | 240 | sí | 12,0016 | 13 | 1,1912 | 5,82 |
| 18,0 | 393,53 | 393 | 360 | sí | 18,0218 | 20 | 1,8209 | 9,16 |
| 18,77 | 375,61 | 375 | 376 | **NO** | — | — | — | — |
| 19,0 | 370,56 | 370 | 380 | **NO** | — | — | — | — |

**Resultado derivado, nuevo:** la propia calibración impone un **techo superior** a `ρ_max`, porque
`I ≥ ρ_max·W_dec` exige `ρ_max ≤ √(Lrev/W_dec) = 18,775` (con `L = 7 200`, `W_dec = 20`). La otra
cota (`C-FLU-09`: `ρ_max < 42,111`) no manda aquí. Por encima de `√(Lrev/W_dec)` **no hay región
realizable**: el intervalo `[I_min, I_max]` se vacía. Esto amplía el rango estudiado (1,5–2,5×)
hasta 18,8× sin que la calibración deje de tener solución, a costa de `I ≈ 375` slots (una
inyección cada ≈4,6 h... 9,16/h) y 20 líneas. Como el `ρ*` simulado es mayor que el cerrado
(REV-v1.0: 9,250 simulado vs 9,243 cerrado), la cota es **conservadora**.

## 4 · Defecto 2 — reconstrucción con un solo `I`

Reproducidas primero las filas viejas como control (§8): ventana `7 685,6 → 4 865,6` a `ρ = 2,5`
(I = 851) y coste `0,241 núcleos + 3 líneas` (I ≈ 4 766,7). Después, recalculadas con el mismo
`(I, L, Lrev, F, D, W_dec, α, ρ)`, adversario (`espera`), riesgo y hardware en ambas alternativas:

| `I` | `ρ*` | `V_sin` | `V_con` | `ΔV/V_sin` | q99 sin → con | factor | líneas | núcleos | iny/h |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 851 | 9,0712 | 7 685,60 | 4 865,60 | 36,69 % | 9 280 → 6 528 | 1,422 | 10 | 0,8927 | 4,23 |
| 4 666 | 2,5002 | 9 974,60 | 7 154,60 | 28,27 % | 19 072 → 16 256 | 1,173 | 3 | 0,2414 | 0,77 |

El `q99` se publica como **extremo inferior de bin** (bins de 64 slots), con `α = 0,33` y 64
réplicas a `ρ = 2,5`; no reproduce el `q99` de `F4.txt` (que barre `ρ ∈ [1, ρ_max]` con `J = 1 200`),
porque es otra medida. Las cifras históricas quedan etiquetadas como **escenarios, no parámetros
elegidos**.

## 5 · Defecto 3 y el régimen de líneas — la región realizable

**Semilla causal (defecto 3).** Misma comparación para las dos variantes, en tres patrones de ancla
(ajena, propia, mixta `α = 0,33`): `V_con` es **idéntico** en las dos y `dif_entre_semillas = 0,0000`
en los seis casos (`I ∈ {851, 4 666}`). En el modelo, **la elección de semilla no compra ventana**.
Los datos causales que sí difieren:

| | `C-FLU-12` (vigente, `pot_output = salida(f, s_j+D)`) | h.1 (candidata, `salida(f, slot(I_j))`) |
|---|---|---|
| ancla ajena | al recibir el bloque `I_j` (≥ `s_j`); su cabecera ancla `pot_output` (`C-POT-05`) | igual |
| ancla propia | cuando la frontera alcanza `s_j + D` | cuando alcanza `s_j` (`D/ρ` antes) |
| grinding | cerrado: ni hash, ni timestamp, ni padres, ni raíz entran en la entropía | mismo cierre mientras el ingrediente sea función de `(f, slot)` y del chunk |
| unicidad de billete | **no distingue billete**: dos copias del mismo chunk dan la misma entropía (coste declarado en `C-FLU-12`) | igual |
| circularidad | salida futura con `D < L`: bien fundada; el contexto aporta la semilla, nunca el candidato | sin salida futura; el argumento de *lookahead* de R-FIN-14(f) está escrito sobre esta variante y **no se rehízo con `+D`** |

Por eso **no se elige una semilla por comodidad de implementación**: se entregan las dos y la
decisión queda **condicionada** a Katana (§9). Lo único que el instrumento puede afirmar es que la
ventana no las distingue.

**Régimen de líneas (encargo §4).** REV-v1.0 suma `Lrev/ρ` al camino crítico del atacante
(«el VDF corre en paralelo, en su propia línea», pero el ancla no existe hasta `s_j`, así que la
revelación no se puede empezar antes). Un adversario con **líneas AES dedicadas** sí puede
precomputarla. Como una línea a tasa `ρ` cubre `ρ·Δt = I` slots de trabajo por época, el número de
líneas necesarias es `⌈Lrev/I⌉`, **independiente de `ρ`**:

| `I` | `V_sin` | `V` monolineal | `V` paralelo | reducción monolineal | reducción paralelo | líneas para ocultar | líneas para todos los candidatos | líneas del timekeeper |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 851 | 7 685,60 | 4 865,60 | 7 685,60 | 36,69 % | **0,00 %** | 9 | 1 251 | 10 |
| 4 666 | 9 974,60 | 7 154,60 | 9 974,60 | 28,27 % | **0,00 %** | **2** | 229 | 3 |

**Región realizable, respuesta a la pregunta del encargo:** el beneficio de `(h)` vive **solo** bajo
la hipótesis de que el adversario no puede dedicar líneas a precomputar. En el escenario calibrado,
**dos líneas** bastan para anularlo — menos que las tres del timekeeper honesto. Un adversario con
recursos de laboratorio o estatales, que es el declarado en el encargo, no es monolineal por
necesidad. Con el techo medido de 25 líneas sin degradación apreciable (1,7 %) y 1 360 líneas
teóricas, 2–9 líneas **no** son un obstáculo. Precomputar *todos* los candidatos de ancla
(`S_max + 1 = 151` slots) costaría 229–1 251 líneas, que ya no es trivial y depende de cuántos
candidatos el adversario considere vivos.

## 6 · Defecto 5 — primitiva y coste real (`PENDIENTE`)

`zx-pot` expone `prove(seed, iterations: NonZeroU32)` y `verify(seed, iterations, &checkpoints)`;
la clave AES del tramo es `blake3(seed)[0..16)`, **derivada del argumento en cada llamada**, y
`verify` exige los 8 checkpoints (128 B). La candidata escribe una cadena **de clave única** de
`T = Lrev·N(slot(I_j))` iteraciones con `N` congelado en el ancla.

| `Lrev` | `T` | `T / u32::MAX` | ¿una llamada? |
|---:|---:|---:|---|
| 21 | 4,338·10⁹ | 1,0× | **NO** |
| 300 | 6,197·10¹⁰ | 14,4× | **NO** |
| 7 050 | 1,456·10¹² | **339,1×** | **NO** |

Mayor `Lrev` expresable en una sola llamada con `N` nominal (206 557 520): **20 slots**.

**Segmentar por slots no conserva la cadena:** cada llamada redefine `K = blake3(estado)[0..16)`,
de modo que `prove(salida_k, m)` encadenado produce **otra clave y otra cadena** — exactamente el
error que el encargo prohíbe. El único camino que no reimplementa AES ni cambia `prove`/`verify` es
**exponer** `aes::create` / `aes::verify_sequential` (ya parametrizadas por clave, hoy `pub(crate)`).
Sin esa ampliación, **el coste de producir y verificar la segunda cadena queda `Pendiente`** y la
decisión de adopción **inconclusa** por este eje. Se conservan los 32 vectores diferenciales del
upstream `subspace-proof-of-time @ f8842d0`.

## 7 · Defecto 4 — orden de consenso, estados y mapa de reglas

La segunda cadena **no** se resuelve cambiando `C-FLU-12`. El mapa completo (`src/consenso.jl`,
22 reglas con su motivo) incluye: `C-FLU-12` (entropía), `C-POT-01` (la entropía es entrada del
encadenado), `C-POT-02` (salida de un slot; `N % 16 == 0`), `C-POT-04` (`NonZeroU32`),
`C-POT-05` (`pot_output` futuro), `C-POT-06` (tres estados y no circularidad), `C-POT-07` (clave de
caché), `C-POT-08` (orden: estructural/flujo → caché → AES), `C-FLU-01`, `C-FLU-07`, `C-FLU-09`,
`C-FLU-10` (la entropía entra en el flujo), `C-FLU-13`, `C-FLU-14`, `C-FLU-15`, `C-FLU-16`
(`N(s)` cambia en `t_j`), `C-FLU-21`, `C-FLU-22`, `C-NET-31`, `C-NET-32`, `C-NET-33`, `C-FIN-01`
y `C-HDR-07`.

El orden vigente exige que la comprobación de flujo (`C-FLU-14`) sea **estructural y previa a
cualquier PoT** (paso 1b de `C-POT-08`), y la caché va **antes** de AES (paso 3). Con una segunda
cadena, el paso 4 («AES secuencial del rango») pasa a incluir la revelación, y el coste de
recomputarla si faltan checkpoints entra en `C-NET-32`/`C-NET-33`; el modo de fallo correcto sigue
siendo **`Pendiente`, nunca `Inválido`** (verificado en la máquina de estados: presupuesto agotado y
`N` fuera de dominio dan `Pendiente`; solo un fallo AES o una discrepancia de caché bajo la misma
clave dan `Inválido`). El calendario `N(s)` congelado en `slot(I_j)` (h.5) interactúa con
`C-FLU-16`. Nada de esto está cableado hoy (`zx-node` sigue con cabecera lineal;
`verificar_justificacion_pot` devuelve `IntegracionPotPendiente`).

## 8 · Controles (§3 del encargo)

**Contra lo publicado** (`resultados/CONTROLES.txt`):

| Control | Fuente | error máximo |
|---|---|---:|
| `ADL.txt` (sin `(h)`, `J = 1400`) | `ADL.txt` | **0,0044** slots |
| `F1.txt` bloque C (especula) | `F1.txt` | 0,0444 |
| `F2.txt` con `Lrev = L` | `F2.txt` | 0,0444 |
| `F2.txt` con `Lrev = L − S_max` | `F2.txt` | 0,0381 |

**Independientes:**

| Control | Medido | Veredicto |
|---|---:|---|
| C1 sin segunda cadena se recupera el PoT vigente | 0,0044 | OK |
| C2 `ρ = 1` no crea adelanto por velocidad | 0,0000 | OK |
| C3 con `(h)` y `ρ = 19` la ventana sigue ≫ 0 | 7 622,53 | OK |
| C4 `ρ → ∞`: el límite es el transitorio `L+I−lead_h = 8 047`, **no** el tope ADL 8 027 | 8 037,95 | OK |
| C4b `ρ → ∞` sin transitorio (`j_ini = 3`) recupera `A_core − D` | 8 025,149 | OK |
| C5 la tasa de rachas medida (`α^(n*−1)`) no se sustituye por una media | razón 1,009 | OK |
| C6 `Lrev = L − 1` ⇒ el honesto se estanca | 1 estancamiento | OK |
| C7 presupuesto agotado ⇒ `Pendiente`, nunca `Inválido` | — | OK |
| C8 revelación precomputada ⇒ `V` vuelve a `V_sin` | 7 685,60 | OK |

**Oráculo y numérica.** Forma cerrada max-plus vs kernel por puntos de ruptura, en
`Rational{BigInt}`: **192 casos, `Δτ = 0`** exacto (con/sin `(h)`, espera/especula, cruce con
coste/gratis, semilla presente/futura). Cuantil exacto por integración de tramos vs muestreo denso
(δ = 1/64 slot): `q50 = 41,160` vs `41,156`, `Δ = 0,00375`. Sin `@fastmath`.

**Control negativo (doble farmeo).** El modelo tiene **una** frontera por actor: un segundo reloj
paralelo no demuestra exclusividad de espacio entre ramas. En el patrón «todas las anclas propias»
`V` crece sin cota (770 217 slots a `I = 851`), lo que confirma que la cota de edad debe ser un
**cuantil con su tasa de excedencia**, no un `sup`.

## 9 · Decisiones pendientes para Katana

1. **`ρ_max`**: sin medida. Con `ρ_max > 18,775` (L = 7 200, `W_dec = 20`) la calibración (h.6) no
   tiene solución realizable; con `ρ_max = 1,5` exige `I = 14 040` y 2 líneas.
2. **Adoptar `(h)` o no**: el beneficio medido (28,27 % de `V`, factor 1,17 en q99, 0,2414
   núcleos/nodo y 3 líneas) **solo** sobrevive bajo adversario monolineal. Un adversario con 2
   líneas libres lo anula. La decisión depende de qué adversario se declare.
3. **Semilla**: `C-FLU-12` (`pot_output`) frente a h.1 (`salida(f, slot(I_j))`). La ventana no las
   distingue; la diferencia es causal (fecha del ingrediente, *lookahead*, circularidad). **No se
   elige aquí.**
4. **`I`, `Lrev`, `F`, `L_suelo`, `D`, `N(s)`**: siguen símbolos. Si se adopta `(h)`, la
   calibración liga `I` a `ρ_max` y `Lrev = L − S_max`; no al contrario.
5. **Presupuesto de adopción** (`PRESUP_NODO`, `PRESUP_PAR`): `C-NET-33` deja la cota superior sin
   derivar; `(h)` añade una partida.
6. **Coste de la segunda cadena**: requiere exponer la primitiva parametrizada por clave (decisión
   de implementación, no de este informe) o dejar el coste `Pendiente`.
7. **Cota de edad `M`**: cuantil con tasa de excedencia explícita, no `sup` (el patrón de anclas
   propias lo muestra).

## 10 · Archivos, pruebas y límites

**Archivos de la auditoría** (todos nuevos, en `veritas/seguridad/segundo-vdf-v1/`):
`Project.toml`, `Manifest.toml`, `julia-version.toml`, `run.jl`, `src/{SegundoVdfV1,modelo,referencia,rapido,escenarios,coste,consenso,validacion}.jl`,
`test/runtests.jl`, `bench/benchmarks.jl`, `CONTRATO.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`,
`INFORME.md`, `resultados/*.txt` (incluye `BENCH-Y-RUN.txt`). **No se modificó** `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, los
P-ZRX históricos ni el vault externo; no hubo commit, push, stash ni cambio de rama.


### Rendimiento del kernel (medido, `bench/benchmarks.jl`)

| Variante | Mediana | Asignaciones | Memoria | Hilos | Resultado frente a la referencia |
|---|---:|---:|---:|---:|---|
| `simular_replica!`, `J = 1 500` | **0,143 ms** | **0** | **0 B** | 1 | igual al oráculo exacto |
| Barrido `R=256 × ρ=12` | 314,26 ms | — | — | 1 | checksum base |
| ídem | 53,88 ms | — | — | 8 | checksum **idéntico** (5,76×) |
| ídem | 58,41 ms | — | — | 16 | checksum idéntico (5,35×) |

Los *checksums* `(Σvmax, Σhist, Σbajo, Σsobre)` son idénticos con 1, 2, 4, 8 y 16 hilos: la
reducción es determinista y sin carreras (los acumuladores son **por réplica** y se reducen después
en orden de id). El trabajo por barrido es de milisegundos, así que el escalado está dominado por el
arranque de tareas; se conserva 8 hilos, que gana en tiempo absoluto. `@code_warntype` y JET se
ejecutan sin diagnósticos sobre el camino caliente. Detalle completo en
`resultados/BENCH-Y-RUN.txt`.

**Pruebas ejecutadas:** `test/runtests.jl` **64/64 en verde**; `run.jl --modo todo --replicas 64`
(6 artefactos); `bench/benchmarks.jl`; equivalencia oráculo↔kernel (192 casos) y cuantil exacto.

**Límites que impiden afirmar una mejora global de seguridad:** `V` es ventana de conocimiento de
frontera, no probabilidad de doble gasto ni finalidad; no hay red, partición, GHOSTDAG,
reorganizaciones ni economía; el adversario se modela como una sola frontera; la condición inicial
de REV infla `V_max` a `ρ` grande (cuantificado en C4/C4b); la segunda cadena no se ha medido. Bajo
el mismo riesgo y escenario, **el beneficio está refutado para el adversario con líneas libres y
validado en el modelo solo para el monolineal**; el coste real del mecanismo queda **pendiente**.
